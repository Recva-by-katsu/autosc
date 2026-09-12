#!/usr/bin/env python3
"""
Autoscript REST API.

Exposes the functionality of the `menu` panel (SSH / VMess / VLESS / Trojan /
Shadowsocks accounts, system information and service control) over HTTP so the
VPS can be driven programmatically.

Design constraints:
  * Python 3 standard library only. The installer runs on freshly provisioned
    Debian/Ubuntu boxes where pip installs are a common failure point.
  * Binds to loopback only. TLS termination and public exposure are handled by
    the nginx vhost that already serves the install domain.
  * Account state lives in exactly the same files the shell menus use
    (/etc/xray/config.json markers, /etc/xray/ssh.txt, system users) so the API
    and the interactive menu stay interchangeable.
"""

import base64
import hashlib
import hmac
import json
import os
import re
import secrets
import shutil
import signal
import subprocess
import sys
import threading
import time
import urllib.parse
from datetime import datetime, timedelta
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

VERSION = "1.0.0"

CONFIG_JSON = "/etc/xray/config.json"
SSH_LIST = "/etc/xray/ssh.txt"
DOMAIN_FILE = "/etc/xray/domain"
LOG_INSTALL = "/root/log-install.txt"
API_DIR = "/etc/autosc-api"
KEYS_FILE = os.path.join(API_DIR, "keys.json")
SETTINGS_FILE = os.path.join(API_DIR, "settings.json")
OPENAPI_FILE = "/usr/local/lib/autosc-api/openapi.json"

USERNAME_RE = re.compile(r"^[a-zA-Z0-9_]{1,32}$")
UUID_RE = re.compile(r"^[A-Za-z0-9._~-]{1,64}$")

# Marker prefix and the anchor comments each protocol is inserted after.
# These mirror data/menu-*.sh exactly; changing them desynchronises the menus.
PROTOCOLS = {
    "vmess": {"marker": "###", "anchors": ["#vmess", "#vmessgrpc"]},
    "vless": {"marker": "#&", "anchors": ["#vless", "#vlessgrpc"]},
    "trojan": {"marker": "#!", "anchors": ["#trojanws", "#trojangrpc"]},
    "ss": {"marker": "##", "anchors": ["#ssws", "#ssgrpc"]},
}

_config_lock = threading.Lock()
_keys_lock = threading.Lock()


# --------------------------------------------------------------------------- #
# helpers
# --------------------------------------------------------------------------- #

class ApiError(Exception):
    def __init__(self, status, message, detail=None):
        super().__init__(message)
        self.status = status
        self.message = message
        self.detail = detail


def read_file(path, default=""):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            return fh.read().strip()
    except OSError:
        return default


def get_domain():
    return read_file(DOMAIN_FILE) or read_file("/root/domain")


def run(cmd, check=True, timeout=60):
    proc = subprocess.run(
        cmd, capture_output=True, text=True, timeout=timeout
    )
    if check and proc.returncode != 0:
        raise ApiError(
            500,
            "command failed: %s" % " ".join(cmd),
            (proc.stderr or proc.stdout or "").strip()[:500],
        )
    return proc


def port_from_log(label, default=""):
    """Read a port out of /root/log-install.txt the way the menus do."""
    for line in read_file(LOG_INSTALL).splitlines():
        if label in line and ":" in line:
            tail = line.split(":", 1)[1].strip()
            match = re.search(r"\d+", tail)
            if match:
                return match.group(0)
    return default


def expiry_date(days):
    return (datetime.now() + timedelta(days=int(days))).strftime("%Y-%m-%d")


def days_left(date_str):
    try:
        target = datetime.strptime(date_str, "%Y-%m-%d")
    except ValueError:
        return None
    return (target - datetime.now()).days + 1


def validate_username(user):
    if not user or not USERNAME_RE.match(user):
        raise ApiError(
            400,
            "invalid username",
            "username must be 1-32 characters of a-z, A-Z, 0-9 or underscore",
        )
    return user


def validate_days(value):
    try:
        days = int(value)
    except (TypeError, ValueError):
        raise ApiError(400, "invalid expired value", "expired must be an integer number of days")
    if days < 1 or days > 3650:
        raise ApiError(400, "invalid expired value", "expired must be between 1 and 3650 days")
    return days


def validate_uuid(value):
    if value is None or value == "":
        return None
    value = str(value)
    if not UUID_RE.match(value):
        raise ApiError(400, "invalid uuid/password", "must be 1-64 characters of A-Za-z0-9 . _ ~ -")
    return value


# --------------------------------------------------------------------------- #
# api keys
# --------------------------------------------------------------------------- #

def _load_keys():
    raw = read_file(KEYS_FILE)
    if not raw:
        return []
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return []
    return data if isinstance(data, list) else []


def _save_keys(keys):
    os.makedirs(API_DIR, exist_ok=True)
    tmp = KEYS_FILE + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(keys, fh, indent=2)
    os.chmod(tmp, 0o600)
    os.replace(tmp, KEYS_FILE)


def hash_key(raw):
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def create_key(name, scopes=None):
    raw = "asc_" + secrets.token_urlsafe(32)
    entry = {
        "id": secrets.token_hex(8),
        "name": name or "unnamed",
        "hash": hash_key(raw),
        "prefix": raw[:12],
        "scopes": scopes or ["*"],
        "created_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "last_used": None,
        "revoked": False,
    }
    with _keys_lock:
        keys = _load_keys()
        keys.append(entry)
        _save_keys(keys)
    public = {k: v for k, v in entry.items() if k != "hash"}
    public["key"] = raw
    return public


def revoke_key(key_id):
    with _keys_lock:
        keys = _load_keys()
        for entry in keys:
            if entry.get("id") == key_id or entry.get("name") == key_id:
                entry["revoked"] = True
                _save_keys(keys)
                return True
    return False


def delete_key(key_id):
    with _keys_lock:
        keys = _load_keys()
        remaining = [e for e in keys if e.get("id") != key_id and e.get("name") != key_id]
        if len(remaining) == len(keys):
            return False
        _save_keys(remaining)
        return True


def list_keys():
    return [{k: v for k, v in e.items() if k != "hash"} for e in _load_keys()]


def authenticate(raw_key):
    """Constant-time lookup of a presented key. Returns the entry or None."""
    if not raw_key:
        return None
    digest = hash_key(raw_key)
    with _keys_lock:
        keys = _load_keys()
        matched = None
        for entry in keys:
            if hmac.compare_digest(entry.get("hash", ""), digest):
                matched = entry
                break
        if matched is None or matched.get("revoked"):
            return None
        matched["last_used"] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        _save_keys(keys)
    return matched


# --------------------------------------------------------------------------- #
# xray config manipulation
# --------------------------------------------------------------------------- #

def _read_config_lines():
    try:
        with open(CONFIG_JSON, "r", encoding="utf-8", errors="replace") as fh:
            return fh.read().split("\n")
    except OSError:
        raise ApiError(500, "xray config not readable", CONFIG_JSON)


def _write_config_lines(lines):
    tmp = CONFIG_JSON + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))
    shutil.copymode(CONFIG_JSON, tmp)
    os.replace(tmp, CONFIG_JSON)


def restart_xray():
    subprocess.run(["systemctl", "restart", "xray"], capture_output=True, text=True)


def list_xray_users(proto):
    """Return [{username, expired, days_left}] for one protocol."""
    marker = PROTOCOLS[proto]["marker"]
    seen = {}
    for line in _read_config_lines():
        if not line.startswith(marker + " "):
            continue
        parts = line.split()
        if len(parts) < 3:
            continue
        user, exp = parts[1], parts[2]
        if user not in seen:
            seen[user] = {"username": user, "expired": exp, "days_left": days_left(exp)}
    return sorted(seen.values(), key=lambda item: item["username"])


def xray_user_exists(proto, user):
    return any(u["username"] == user for u in list_xray_users(proto))


def _client_entry(proto, user, uuid, cipher=None):
    if proto == "vmess":
        return '},{"id": "%s","alterId": 0,"email": "%s"' % (uuid, user)
    if proto == "vless":
        return '},{"id": "%s","email": "%s"' % (uuid, user)
    if proto == "trojan":
        return '},{"password": "%s","email": "%s"' % (uuid, user)
    if proto == "ss":
        return '},{"password": "%s","method": "%s","email": "%s"' % (uuid, cipher, user)
    raise ApiError(400, "unknown protocol", proto)


def add_xray_user(proto, user, uuid, days, cipher="aes-128-gcm"):
    """Insert a client after each protocol anchor, mirroring the menu's sed."""
    spec = PROTOCOLS[proto]
    exp = expiry_date(days)

    with _config_lock:
        if xray_user_exists(proto, user):
            raise ApiError(409, "user already exists", "%s user %s" % (proto, user))

        lines = _read_config_lines()
        out = []
        inserted = 0
        for line in lines:
            out.append(line)
            if line.strip() in spec["anchors"]:
                out.append("%s %s %s" % (spec["marker"], user, exp))
                out.append(_client_entry(proto, user, uuid, cipher))
                inserted += 1

        if inserted == 0:
            raise ApiError(
                500,
                "xray config has no anchor for this protocol",
                "expected one of %s in %s" % (spec["anchors"], CONFIG_JSON),
            )

        _write_config_lines(out)

    restart_xray()
    return exp


def delete_xray_user(proto, user):
    """Delete the marker line and its client object, mirroring the menu's sed."""
    spec = PROTOCOLS[proto]
    marker_prefix = spec["marker"] + " " + user + " "

    with _config_lock:
        lines = _read_config_lines()
        out = []
        removed = 0
        skipping = False
        for line in lines:
            if skipping:
                # The menu deletes through the first line starting with "},{".
                if line.startswith("},{"):
                    skipping = False
                continue
            if line.startswith(marker_prefix):
                skipping = True
                removed += 1
                continue
            out.append(line)

        if removed == 0:
            raise ApiError(404, "user not found", "%s user %s" % (proto, user))

        _write_config_lines(out)

    restart_xray()
    return removed


def renew_xray_user(proto, user, days):
    spec = PROTOCOLS[proto]
    marker_prefix = spec["marker"] + " " + user + " "
    exp = expiry_date(days)

    with _config_lock:
        lines = _read_config_lines()
        found = 0
        for index, line in enumerate(lines):
            if line.startswith(marker_prefix):
                lines[index] = "%s %s %s" % (spec["marker"], user, exp)
                found += 1
        if found == 0:
            raise ApiError(404, "user not found", "%s user %s" % (proto, user))
        _write_config_lines(lines)

    restart_xray()
    return exp


# --------------------------------------------------------------------------- #
# connection link builders (mirror the formats printed by the menus)
# --------------------------------------------------------------------------- #

def build_links(proto, user, uuid, cipher="aes-128-gcm"):
    domain = get_domain()
    tls = port_from_log("Xray Vmess Ws Tls", "443") or "443"
    none = port_from_log("Xray Vmess Ws None Tls", "80") or "80"

    if proto == "vmess":
        def vmess(port, net, path, security):
            payload = {
                "v": "2", "ps": user, "add": domain, "port": str(port),
                "id": uuid, "aid": "0", "net": net, "path": path,
                "type": "none", "host": domain, "tls": security,
            }
            if security == "tls":
                payload["sni"] = domain
            blob = json.dumps(payload, separators=(",", ":")).encode("utf-8")
            return "vmess://" + base64.b64encode(blob).decode("ascii")
        return {
            "ws_tls": vmess(tls, "ws", "/vmess", "tls"),
            "ws_none_tls": vmess(none, "ws", "/vmess", "none"),
            "grpc": vmess(tls, "grpc", "vmess-grpc", "tls"),
        }

    if proto == "vless":
        return {
            "ws_tls": "vless://%s@%s:%s?path=/vlessws&security=tls&encryption=none&type=ws&host=%s&sni=%s#%s"
                      % (uuid, domain, tls, domain, domain, user),
            "ws_none_tls": "vless://%s@%s:%s?path=/vlessws&encryption=none&type=ws&host=%s#%s"
                           % (uuid, domain, none, domain, user),
            "grpc": "vless://%s@%s:%s?mode=gun&security=tls&encryption=none&type=grpc"
                    "&serviceName=vless-grpc&sni=%s#%s" % (uuid, domain, tls, domain, user),
        }

    if proto == "trojan":
        return {
            "ws_tls": "trojan://%s@%s:%s?path=/trojan&security=tls&type=ws&host=%s&sni=%s#%s"
                      % (uuid, domain, tls, domain, domain, user),
            "grpc": "trojan://%s@%s:%s?mode=gun&security=tls&type=grpc"
                    "&serviceName=trojan-grpc&sni=%s#%s" % (uuid, domain, tls, domain, user),
        }

    if proto == "ss":
        blob = base64.b64encode(("%s:%s" % (cipher, uuid)).encode("utf-8")).decode("ascii")
        return {
            "ws_tls": "ss://%s@%s:%s?plugin=xray-plugin;mux=0;path=/ss-ws;host=%s;tls#%s"
                      % (blob, domain, tls, domain, user),
            "grpc": "ss://%s@%s:%s?plugin=xray-plugin;mux=0;serviceName=ss-grpc;host=%s;tls#%s"
                    % (blob, domain, tls, domain, user),
        }

    raise ApiError(400, "unknown protocol", proto)


# --------------------------------------------------------------------------- #
# ssh accounts
# --------------------------------------------------------------------------- #

def ssh_expiry(user):
    proc = subprocess.run(["chage", "-l", user], capture_output=True, text=True)
    if proc.returncode != 0:
        return None
    for line in proc.stdout.splitlines():
        if "Account expires" in line:
            value = line.split(":", 1)[1].strip()
            if value in ("never", "never\n", ""):
                return "never"
            for fmt in ("%b %d, %Y", "%d %b %Y", "%Y-%m-%d"):
                try:
                    return datetime.strptime(value, fmt).strftime("%Y-%m-%d")
                except ValueError:
                    continue
            return value
    return None


def list_ssh_users():
    users = []
    for name in read_file(SSH_LIST).splitlines():
        name = name.strip()
        if not name:
            continue
        if subprocess.run(["id", "-u", name], capture_output=True).returncode != 0:
            continue
        exp = ssh_expiry(name)
        users.append({
            "username": name,
            "expired": exp,
            "days_left": days_left(exp) if exp and exp != "never" else None,
        })
    return sorted(users, key=lambda item: item["username"])


def ssh_user_exists(user):
    return subprocess.run(["id", "-u", user], capture_output=True).returncode == 0


def add_ssh_user(user, password, days):
    if ssh_user_exists(user):
        raise ApiError(409, "user already exists", "ssh user %s" % user)
    if not password:
        raise ApiError(400, "password is required", "ssh accounts need a password")

    exp = expiry_date(days)
    run(["useradd", "-e", exp, "-s", "/bin/false", "-M", user])
    proc = subprocess.run(
        ["chpasswd"], input="%s:%s\n" % (user, password),
        capture_output=True, text=True,
    )
    if proc.returncode != 0:
        subprocess.run(["userdel", "-f", user], capture_output=True)
        raise ApiError(500, "failed to set password", proc.stderr.strip()[:300])

    existing = read_file(SSH_LIST).splitlines()
    if user not in [e.strip() for e in existing]:
        with open(SSH_LIST, "a", encoding="utf-8") as fh:
            fh.write(user + "\n")
    return exp


def delete_ssh_user(user):
    if not ssh_user_exists(user):
        raise ApiError(404, "user not found", "ssh user %s" % user)
    subprocess.run(["pkill", "-u", user], capture_output=True)
    run(["userdel", "-f", user], check=False)

    remaining = [
        line for line in read_file(SSH_LIST).splitlines()
        if line.strip() and line.strip() != user
    ]
    with open(SSH_LIST, "w", encoding="utf-8") as fh:
        fh.write("\n".join(remaining) + ("\n" if remaining else ""))


def renew_ssh_user(user, days):
    if not ssh_user_exists(user):
        raise ApiError(404, "user not found", "ssh user %s" % user)
    exp = expiry_date(days)
    run(["usermod", "-e", exp, user])
    return exp


def ssh_online_users():
    proc = subprocess.run(["who"], capture_output=True, text=True)
    counts = {}
    for line in proc.stdout.splitlines():
        parts = line.split()
        if parts:
            counts[parts[0]] = counts.get(parts[0], 0) + 1
    return [{"username": name, "sessions": total} for name, total in sorted(counts.items())]


def ssh_connection_info(user, password, exp):
    domain = get_domain()
    return {
        "username": user,
        "password": password,
        "expired": exp,
        "host": domain,
        "ip": read_file("/etc/myipvps"),
        "ports": {
            "openssh": port_from_log("OpenSSH", "22"),
            "dropbear": port_from_log("Dropbear", "109"),
            "ssh_websocket": port_from_log("SSH Websocket", "80"),
            "ssh_ssl_websocket": port_from_log("SSH SSL Websocket", "443"),
            "stunnel": port_from_log("Stunnel4", "222"),
            "squid": port_from_log("Squid", "3128"),
            "ohp_ssh": port_from_log("OHP SSH", "8181"),
            "ohp_dropbear": port_from_log("OHP DBear", "8282"),
            "ohp_openvpn": port_from_log("OHP OpenVPN", "8787"),
            "udpgw": "7100-7900",
        },
        "payload": ("GET / HTTP/1.1[crlf]Host: %s[crlf]Upgrade: websocket[crlf][crlf]" % domain),
    }


# --------------------------------------------------------------------------- #
# system
# --------------------------------------------------------------------------- #

MANAGED_SERVICES = [
    "ssh", "dropbear", "stunnel4", "squid", "nginx", "xray",
    "ws-dropbear", "ws-stunnel", "ws-ovpn", "cron", "autosc-api",
]


def service_active(name):
    proc = subprocess.run(
        ["systemctl", "is-active", name], capture_output=True, text=True
    )
    return proc.stdout.strip() == "active"


def system_info():
    mem_total = mem_available = 0
    try:
        with open("/proc/meminfo", "r", encoding="utf-8") as fh:
            for line in fh:
                if line.startswith("MemTotal:"):
                    mem_total = int(line.split()[1]) // 1024
                elif line.startswith("MemAvailable:"):
                    mem_available = int(line.split()[1]) // 1024
    except OSError:
        pass

    uptime_seconds = 0
    try:
        uptime_seconds = int(float(read_file("/proc/uptime", "0").split()[0]))
    except (ValueError, IndexError):
        pass

    counts = {}
    for proto in PROTOCOLS:
        try:
            counts[proto] = len(list_xray_users(proto))
        except ApiError:
            counts[proto] = 0
    counts["ssh"] = len(list_ssh_users())

    return {
        "api_version": VERSION,
        "script_version": read_file("/opt/.ver", "unknown"),
        "domain": get_domain(),
        "ip": read_file("/etc/myipvps"),
        "isp": read_file("/etc/lukman/isp"),
        "city": read_file("/etc/lukman/city"),
        "uptime_seconds": uptime_seconds,
        "memory": {
            "total_mb": mem_total,
            "used_mb": mem_total - mem_available,
            "free_mb": mem_available,
        },
        "accounts": counts,
        "services": {name: service_active(name) for name in MANAGED_SERVICES},
    }


def restart_services(names):
    results = {}
    for name in names:
        if name not in MANAGED_SERVICES:
            results[name] = "refused: not a managed service"
            continue
        if name == "autosc-api":
            results[name] = "refused: cannot restart the API from within itself"
            continue
        proc = subprocess.run(
            ["systemctl", "restart", name], capture_output=True, text=True
        )
        results[name] = "ok" if proc.returncode == 0 else (proc.stderr.strip()[:200] or "failed")
    return results


# --------------------------------------------------------------------------- #
# routing
# --------------------------------------------------------------------------- #

def account_payload(proto, user, uuid, exp, cipher=None):
    payload = {
        "protocol": proto,
        "username": user,
        "expired": exp,
        "domain": get_domain(),
        "links": build_links(proto, user, uuid, cipher or "aes-128-gcm"),
    }
    payload["uuid" if proto in ("vmess", "vless") else "password"] = uuid
    if proto == "ss":
        payload["method"] = cipher
    return payload


def handle_account_create(proto, body):
    user = validate_username(body.get("username"))
    days = validate_days(body.get("expired", body.get("days")))

    if proto == "ssh":
        password = body.get("password")
        if not password or len(str(password)) > 128:
            raise ApiError(400, "invalid password", "password is required, max 128 characters")
        exp = add_ssh_user(user, str(password), days)
        return ssh_connection_info(user, str(password), exp)

    uuid = validate_uuid(body.get("uuid") or body.get("password"))
    if not uuid:
        uuid = read_file("/proc/sys/kernel/random/uuid")
    cipher = body.get("method", "aes-128-gcm")
    if proto == "ss" and cipher not in ("aes-128-gcm", "aes-256-gcm", "chacha20-poly1305"):
        raise ApiError(400, "invalid method", "supported: aes-128-gcm, aes-256-gcm, chacha20-poly1305")

    exp = add_xray_user(proto, user, uuid, days, cipher)
    return account_payload(proto, user, uuid, exp, cipher)


def handle_account_list(proto):
    if proto == "ssh":
        return {"protocol": "ssh", "total": len(list_ssh_users()), "users": list_ssh_users()}
    users = list_xray_users(proto)
    return {"protocol": proto, "total": len(users), "users": users}


def handle_account_delete(proto, user):
    validate_username(user)
    if proto == "ssh":
        delete_ssh_user(user)
    else:
        delete_xray_user(proto, user)
    return {"protocol": proto, "username": user, "deleted": True}


def handle_account_renew(proto, user, body):
    validate_username(user)
    days = validate_days(body.get("expired", body.get("days")))
    if proto == "ssh":
        exp = renew_ssh_user(user, days)
    else:
        exp = renew_xray_user(proto, user, days)
    return {"protocol": proto, "username": user, "expired": exp, "renewed": True}


ALL_PROTOCOLS = ["ssh"] + list(PROTOCOLS.keys())


def dispatch(method, path, body, key_entry):
    parts = [p for p in path.strip("/").split("/") if p]

    # /health and /openapi.json are handled before auth in the request handler.
    if not parts:
        return 200, {"name": "katsutun-api", "version": VERSION, "docs": "/docs/"}

    if parts[0] == "system":
        if len(parts) == 2 and parts[1] == "info" and method == "GET":
            return 200, system_info()
        if len(parts) == 2 and parts[1] == "services" and method == "GET":
            return 200, {name: service_active(name) for name in MANAGED_SERVICES}
        if len(parts) == 3 and parts[1] == "services" and parts[2] == "restart" and method == "POST":
            names = body.get("services") or MANAGED_SERVICES
            if not isinstance(names, list):
                raise ApiError(400, "invalid services", "services must be an array of names")
            return 200, {"results": restart_services(names)}
        raise ApiError(404, "unknown system route", path)

    if parts[0] == "keys":
        if len(parts) == 1 and method == "GET":
            return 200, {"keys": list_keys()}
        if len(parts) == 1 and method == "POST":
            name = str(body.get("name") or "unnamed")[:64]
            return 201, create_key(name)
        if len(parts) == 2 and method == "DELETE":
            if delete_key(parts[1]):
                return 200, {"id": parts[1], "deleted": True}
            raise ApiError(404, "key not found", parts[1])
        if len(parts) == 3 and parts[2] == "revoke" and method == "POST":
            if revoke_key(parts[1]):
                return 200, {"id": parts[1], "revoked": True}
            raise ApiError(404, "key not found", parts[1])
        raise ApiError(404, "unknown keys route", path)

    if parts[0] in ALL_PROTOCOLS:
        proto = parts[0]
        if len(parts) == 1 and method == "GET":
            return 200, handle_account_list(proto)
        if len(parts) == 1 and method == "POST":
            return 201, handle_account_create(proto, body)
        if len(parts) == 2 and parts[1] == "online" and proto == "ssh" and method == "GET":
            return 200, {"online": ssh_online_users()}
        if len(parts) == 2 and method == "DELETE":
            return 200, handle_account_delete(proto, parts[1])
        if len(parts) == 3 and parts[2] == "renew" and method == "POST":
            return 200, handle_account_renew(proto, parts[1], body)
        raise ApiError(404, "unknown account route", path)

    raise ApiError(404, "unknown route", path)


# --------------------------------------------------------------------------- #
# http server
# --------------------------------------------------------------------------- #

class Handler(BaseHTTPRequestHandler):
    server_version = "autosc-api/" + VERSION
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        sys.stdout.write(
            "%s - %s\n" % (self.address_string(), fmt % args)
        )
        sys.stdout.flush()

    def _send(self, status, payload):
        blob = json.dumps(payload, indent=2).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(blob)))
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(blob)

    def _read_body(self):
        try:
            length = int(self.headers.get("Content-Length") or 0)
        except ValueError:
            length = 0
        if length <= 0:
            return {}
        if length > 1_000_000:
            raise ApiError(413, "request body too large", "maximum 1 MB")
        raw = self.rfile.read(length)
        if not raw.strip():
            return {}
        try:
            data = json.loads(raw.decode("utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError):
            raise ApiError(400, "invalid JSON body", "request body must be valid JSON")
        if not isinstance(data, dict):
            raise ApiError(400, "invalid JSON body", "request body must be a JSON object")
        return data

    def _handle(self, method):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        if path in ("/health", "/healthz"):
            self._send(200, {"status": "ok", "version": VERSION})
            return

        if path == "/openapi.json":
            spec = read_file(OPENAPI_FILE)
            if spec:
                blob = spec.encode("utf-8")
                self.send_response(200)
                self.send_header("Content-Type", "application/json; charset=utf-8")
                self.send_header("Content-Length", str(len(blob)))
                self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers()
                self.wfile.write(blob)
            else:
                self._send(404, {"error": "openapi spec not installed"})
            return

        try:
            body = self._read_body() if method in ("POST", "PUT", "PATCH") else {}

            raw_key = self.headers.get("X-API-Key")
            if not raw_key:
                auth = self.headers.get("Authorization", "")
                if auth.lower().startswith("bearer "):
                    raw_key = auth[7:].strip()

            key_entry = authenticate(raw_key)
            if key_entry is None:
                raise ApiError(
                    401, "unauthorized",
                    "supply a valid key via the X-API-Key header or Authorization: Bearer",
                )

            status, payload = dispatch(method, path, body, key_entry)
            self._send(status, payload)

        except ApiError as exc:
            self._send(exc.status, {"error": exc.message, "detail": exc.detail})
        except subprocess.TimeoutExpired:
            self._send(504, {"error": "operation timed out", "detail": None})
        except Exception as exc:  # noqa: BLE001 - never leak a traceback to clients
            sys.stderr.write("unhandled error on %s %s: %r\n" % (method, path, exc))
            sys.stderr.flush()
            self._send(500, {"error": "internal server error", "detail": None})

    def do_GET(self):
        self._handle("GET")

    def do_POST(self):
        self._handle("POST")

    def do_DELETE(self):
        self._handle("DELETE")

    def do_PUT(self):
        self._handle("PUT")


def main():
    host = os.environ.get("AUTOSC_API_HOST", "127.0.0.1")
    port = int(os.environ.get("AUTOSC_API_PORT", "8081"))

    os.makedirs(API_DIR, exist_ok=True)
    os.chmod(API_DIR, 0o700)

    httpd = ThreadingHTTPServer((host, port), Handler)
    httpd.daemon_threads = True

    def shutdown(signum, frame):
        threading.Thread(target=httpd.shutdown, daemon=True).start()

    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)

    print("autosc-api %s listening on %s:%d" % (VERSION, host, port))
    sys.stdout.flush()
    httpd.serve_forever()


if __name__ == "__main__":
    main()
