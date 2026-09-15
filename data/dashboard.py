#!/usr/bin/env python3
"""Read-only VPS dashboard, styled after the supplied terminal reference."""
import datetime as dt
import json
import os
from pathlib import Path
import pwd
import re
import shlex
import shutil
import subprocess
import unicodedata


ROOT = Path(os.environ.get("KATSU_DASHBOARD_ROOT", "/"))


def read(path):
    try:
        return (ROOT / path.lstrip("/")).read_text().strip()
    except (OSError, UnicodeError):
        return ""


def command(*args):
    try:
        result = subprocess.run(args, capture_output=True, text=True, timeout=3)
        return result.stdout.strip() if result.returncode == 0 else ""
    except (OSError, subprocess.TimeoutExpired, UnicodeError):
        return ""


def clean(value):
    return "".join(c for c in str(value) if not unicodedata.category(c).startswith("C"))


def cells(text):
    return sum(0 if unicodedata.combining(c) else
               2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in text)


def fit(text, width):
    text = clean(text)
    if cells(text) <= width:
        return text
    result = ""
    for c in text:
        if cells(result + c) > width - 1:
            break
        result += c
    return result + "~"


def accounts(text, marker=None):
    if not text:
        return "N/A"
    if marker:
        return str(len(set(re.findall(r"^" + re.escape(marker) + r"\s+(\S+)\s+", text, re.M))))
    return str(len(set(line.split()[0] for line in text.splitlines() if line.strip())))


def traffic(raw, interface, today):
    result = {key: "N/A" for key in ("today", "yesterday", "month")}
    try:
        data = json.loads(raw)
        # vnStat JSON v2 stores bytes. Older schemas are not guessed as bytes.
        if str(data.get("jsonversion")) != "2":
            return result
        interfaces = data.get("interfaces", [])
        selected = next((item for item in interfaces if item.get("name") == interface), None)
        if selected is None and len(interfaces) == 1:
            selected = interfaces[0]
        if selected is None:
            return result
        for key, period, date in (("today", "day", today),
                                  ("yesterday", "day", today - dt.timedelta(days=1)),
                                  ("month", "month", today)):
            for item in selected["traffic"].get(period, []):
                stamp = item["date"]
                matches = stamp["year"] == date.year and stamp["month"] == date.month
                if period == "day":
                    matches = matches and stamp["day"] == date.day
                if matches:
                    amount = (float(item["rx"]) + float(item["tx"])) / 1048576
                    result[key] = f"{amount:.2f}M"
                    break
    except (ValueError, TypeError, KeyError, AttributeError):
        pass
    return result


def collect():
    settings = {}
    try:
        loaded = json.loads(read("/etc/katsutun/dashboard.json"))
        if isinstance(loaded, dict):
            settings = loaded
    except ValueError:
        pass
    system = "N/A"
    for line in read("/etc/os-release").splitlines():
        if line.startswith("PRETTY_NAME="):
            try:
                system = shlex.split(line.split("=", 1)[1])[0]
            except (ValueError, IndexError):
                pass
    ram = "N/A"
    memory = command("free", "-m").splitlines()
    if len(memory) > 1 and len(memory[1].split()) >= 3:
        row = memory[1].split()
        ram = f"{row[2]} / {row[1]} MB"
    states = {}
    for label, service in (("PROXY", "xray"), ("NGINX", "nginx"), ("SSHWS", "ws-stunnel")):
        state = command("systemctl", "show", service, "--property=ActiveState", "--value")
        states[label] = "ON" if state == "active" else "OFF" if state else "N/A"
    config = read("/etc/xray/config.json")
    ssh_path = ROOT / "etc/xray/ssh.txt"
    ssh_users = read("/etc/xray/ssh.txt")
    counts = [accounts(ssh_users) if ssh_users else "0" if ssh_path.exists() else "N/A"]
    counts += [accounts(config, marker) for marker in ("###", "#&", "#!")]
    interface = settings.get("interface", "")
    if not interface:
        route = command("ip", "-o", "route", "show", "default").split()
        if "dev" in route:
            interface = route[route.index("dev") + 1]
    usage = traffic(command("vnstat", "--json"), interface, dt.date.today())
    expiry = "N/A [NOT CONFIGURED]"
    try:
        date = dt.date.fromisoformat(settings.get("expires", ""))
        expiry = f"{date.isoformat()} [{(date - dt.date.today()).days} DAYS]"
    except (TypeError, ValueError):
        pass
    update = command("katsu-update", "status")
    update_label = "UPDATE AVAILABLE" if "STATE=available" in update else "LAST UPDATE"
    if not update:
        update_label = "STATUS UNKNOWN"
    return dict(title=settings.get("title", "GEMILANG KINASIH STORE"),
                system=system, ram=ram, uptime=re.sub(r"^up ", "", command("uptime", "-p")) or "N/A",
                ip=read("/etc/lukman/ip") or "N/A", isp=read("/etc/lukman/isp") or "N/A",
                domain=read("/etc/xray/domain") or "N/A", states=states, counts=counts,
                version=read("/opt/.ver") or "N/A", update=update_label,
                username=settings.get("username", pwd.getpwuid(os.getuid()).pw_name),
                expiry=expiry, traffic=usage)


class Panel:
    def __init__(self, width=60, color=True, ascii_mode=False):
        self.width = max(32, min(60, width))
        self.color = color
        self.ascii = ascii_mode
        self.lines = []

    def paint(self, text, color):
        if not self.color:
            return text
        codes = {"blue": "38;5;39", "gold": "38;5;222", "green": "38;5;80",
                 "white": "38;5;252", "red": "38;5;203", "banner": "1;37;48;5;25"}
        return f"\033[{codes[color]}m{text}\033[0m"

    def edge(self, width, indent, bottom=False):
        left, right, rule = ("+", "+", "-") if self.ascii else (
            ("└", "┘", "─") if bottom else ("┌", "┐", "─"))
        self.lines.append(" " * indent + self.paint(left + rule * (width - 2) + right, "blue"))

    def row(self, segments, width, indent):
        remaining = width - 4
        output = ""
        for text, color in segments:
            text = fit(text, remaining)
            output += self.paint(text, color)
            remaining -= cells(text)
            if remaining <= 0:
                break
        vertical = "|" if self.ascii else "│"
        self.lines.append(" " * indent + self.paint(vertical, "blue") + " " + output +
                          " " * (remaining + 1) + self.paint(vertical, "blue"))

    def box(self, rows, inset=0):
        width = self.width - inset * 2
        self.edge(width, inset)
        for row in rows:
            self.row(row, width, inset)
        self.edge(width, inset, True)
        self.lines.append("")

    def render(self, data):
        title = fit(data["title"], self.width - 4)
        self.box([[(title.center(self.width - 4), "banner")]])
        self.box([[(f"{label:<8} : {data[key]}", "white")]
                  for label, key in (("SYSTEM", "system"), ("RAM", "ram"), ("UPTIME", "uptime"),
                                     ("IP VPS", "ip"), ("ISP", "isp"), ("DOMAIN", "domain"))])
        status = []
        for label, value in data["states"].items():
            status += [(label + " : ", "gold"), (value, "green" if value == "ON" else "red"),
                       (" | ", "green")]
        status += [("GOOD" if all(v == "ON" for v in data["states"].values()) else "CHECK", "green")]
        if self.width >= 58:
            self.box([status])
        else:
            self.box([[(label + " : ", "gold"), (value, "green" if value == "ON" else "red")]
                      for label, value in data["states"].items()])
        inset = 8 if self.width >= 58 else 2
        self.box([[((f"{label:<12} : {count}").center(self.width - inset * 2 - 4), "white")]
                  for label, count in zip(("SSHWS OVPN", "XRAY VMESS", "XRAY VLESS", "XRAY TROJN"),
                                          data["counts"])], inset)
        details = [[("VERSION SC : ", "blue"), (data["version"], "gold"),
                    (" [" + data["update"] + "]", "white")],
                   [("USERNAME   : ", "blue"), (data["username"], "gold"), (" [LOCAL]", "green")],
                   [("EXPIRED SC : ", "blue"), (data["expiry"], "gold")]]
        self.box(details, 3 if self.width >= 58 else 0)
        usage = []
        for key in ("today", "yesterday", "month"):
            usage += [(key.upper() + " ", "blue"), (data["traffic"][key] + " ", "green")]
        if sum(cells(text) for text, _ in usage) <= self.width - 4:
            self.box([usage])
        else:
            self.box([[(key.upper() + " ", "blue"), (data["traffic"][key], "green")]
                      for key in ("today", "yesterday", "month")])
        self.edge(self.width, 0)
        self.row([("access all features ", "gold"), ("menu", "green"), (" command", "white")], self.width, 0)
        self.edge(self.width, 0, True)
        return "\n".join(self.lines) + "\n"


if __name__ == "__main__":
    width = shutil.get_terminal_size((60, 24)).columns
    panel = Panel(width, not bool(os.environ.get("NO_COLOR")), os.environ.get("KATSU_ASCII") == "1")
    print(panel.render(collect()), end="")
