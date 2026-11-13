#!/bin/bash
# Tes offline data/game-check.sh.
#
# Membangun dua VPS palsu di direktori sementara:
#   1. "rusak"  - UDPGW mati, squid menolak semua, nginx tanpa proxy_read_timeout
#   2. "sehat"  - semua jalur hidup
# lalu memastikan diagnostik menandai temuan yang benar. Tidak menyentuh VPS
# sebenarnya: semua path dibaca lewat GAMECHECK_ROOT dan command lewat PATH.
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
SCRIPT="${GAMECHECK_ROOT:-$HERE/..}/data/game-check.sh"
[ -f "$SCRIPT" ] || { echo "game-check.sh tidak ditemukan: $SCRIPT" >&2; exit 1; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fail=0
check_contains() { # <label> <file> <pattern>
    if grep -q -- "$3" "$2"; then
        printf '  ok   %s\n' "$1"
    else
        printf '  FAIL %s (pola "%s" tidak ada)\n' "$1" "$3"
        fail=$((fail + 1))
    fi
}
check_absent() { # <label> <file> <pattern>
    if grep -q -- "$3" "$2"; then
        printf '  FAIL %s (pola "%s" seharusnya tidak ada)\n' "$1" "$3"
        fail=$((fail + 1))
    else
        printf '  ok   %s\n' "$1"
    fi
}

make_stubs() { # <bindir> <ss-output>
    local bin=$1 udpgw_lines=$2
    mkdir -p "$bin"
    cat >"$bin/systemctl" <<'EOF'
#!/bin/sh
case "$*" in
    *list-units*) echo ""; exit 0 ;;
    *is-active*)  echo active; exit 0 ;;
esac
exit 0
EOF
    cat >"$bin/ss" <<EOF
#!/bin/sh
cat <<'LIST'
$udpgw_lines
LIST
EOF
    cat >"$bin/ip" <<'EOF'
#!/bin/sh
echo "default via 192.0.2.1 dev eth0 proto static"
EOF
    cat >"$bin/sysctl" <<'EOF'
#!/bin/sh
case "$*" in
    *ip_forward*) echo 1 ;;
    *default_qdisc*) echo fq ;;
    *congestion_control*) echo bbr ;;
    *tcp_low_latency*) echo 0 ;;
    *) echo 1 ;;
esac
EOF
    cat >"$bin/iptables" <<'EOF'
#!/bin/sh
echo "-A POSTROUTING -s 10.6.0.0/24 -o eth0 -j MASQUERADE"
echo "-A POSTROUTING -s 10.7.0.0/24 -o eth0 -j MASQUERADE"
EOF
    cat >"$bin/getent" <<'EOF'
#!/bin/sh
echo "1.1.1.1 one.one.one.one"
EOF
    cat >"$bin/fail2ban-client" <<'EOF'
#!/bin/sh
case "$*" in
    "status") echo "Jail list:	sshd" ;;
    status*) echo "Currently banned:	0" ;;
esac
exit 0
EOF
    printf '#!/bin/sh\nexit 0\n' >"$bin/screen"
    chmod +x "$bin"/*
}

common_files() { # <root>
    local root=$1
    mkdir -p "$root/etc/nginx/conf.d" "$root/etc/squid" "$root/etc/ssh" \
             "$root/usr/local/bin" "$root/etc/openvpn/server"
    printf 'nameserver 8.8.8.8\n' >"$root/etc/resolv.conf"
    printf 'ClientAliveInterval 30\nClientAliveCountMax 6\n' >"$root/etc/ssh/sshd_config"
    printf '#!/bin/sh\nTIMEOUT = 60\n' >"$root/usr/local/bin/ws-stunnel"
    printf '[Unit]\n' >"$root/etc/rc.local"
}

# ---------------------------------------------------------------- skenario 1
BROKEN="$TMP/broken"
common_files "$BROKEN"
make_stubs "$TMP/bin-broken" "LISTEN 0 128 127.0.0.1:7100 0.0.0.0:*"
# akun diumumkan dengan UDPGW 7100-7300, tapi yang hidup hanya 7100
cat >"$BROKEN/etc/rc.local" <<'EOF'
#!/bin/sh -e
screen -dmS badvpn badvpn-udpgw --listen-addr 127.0.0.1:7100 --max-clients 500
exit 0
EOF
cat >"$BROKEN/etc/nginx/conf.d/xray.conf" <<'EOF'
location / {
    proxy_pass http://127.0.0.1:700;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
}
EOF
cat >"$BROKEN/etc/squid/squid.conf" <<'EOF'
acl SSL_ports port 443
acl Safe_ports port 80
http_access allow localhost
http_access deny all
EOF

OUT_BROKEN="$TMP/out-broken.txt"
GAMECHECK_ROOT="$BROKEN" PATH="$TMP/bin-broken:$PATH" \
    bash "$SCRIPT" --plain >"$OUT_BROKEN" 2>&1
CODE_BROKEN=$?

echo "Skenario 1 (rusak):"
check_contains "UDPGW yang hidup dilaporkan" "$OUT_BROKEN" "UDPGW listen di: 7100"
check_contains "port 7300 hilang terdeteksi" "$OUT_BROKEN" "port 7300"
check_contains "nginx tanpa proxy_read_timeout terdeteksi" "$OUT_BROKEN" "tanpa proxy_read_timeout"
check_contains "squid deny all terdeteksi" "$OUT_BROKEN" "hanya mengizinkan localhost"
check_contains "CONNECT 443 saja diperingatkan" "$OUT_BROKEN" "CONNECT hanya diizinkan ke port 443"
if [ "$CODE_BROKEN" -eq 1 ]; then
    echo "  ok   exit code 1 saat ada FAIL"
else
    echo "  FAIL exit code $CODE_BROKEN (harusnya 1)"; fail=$((fail + 1))
fi

# ---------------------------------------------------------------- skenario 2
HEALTHY="$TMP/healthy"
common_files "$HEALTHY"
make_stubs "$TMP/bin-healthy" "LISTEN 0 128 127.0.0.1:7100 0.0.0.0:*
LISTEN 0 128 127.0.0.1:7200 0.0.0.0:*
LISTEN 0 128 127.0.0.1:7300 0.0.0.0:*"
cat >"$HEALTHY/etc/rc.local" <<'EOF'
#!/bin/sh -e
screen -dmS badvpn badvpn-udpgw --listen-addr 127.0.0.1:7100 --max-clients 500
screen -dmS badvpn badvpn-udpgw --listen-addr 127.0.0.1:7200 --max-clients 500
screen -dmS badvpn badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 500
exit 0
EOF
cat >"$HEALTHY/etc/nginx/conf.d/xray.conf" <<'EOF'
location / {
    proxy_pass http://127.0.0.1:700;
    proxy_read_timeout 3600s;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
}
EOF
cat >"$HEALTHY/etc/squid/squid.conf" <<'EOF'
acl SSL_ports port 443
acl Safe_ports port 80 443
acl Safe_ports port 1025-65535
http_access allow all
http_access deny all
EOF
mkdir -p "$HEALTHY/usr/bin"
printf '#!/bin/sh\necho udpgw\n' >"$HEALTHY/usr/bin/badvpn-udpgw"
chmod +x "$HEALTHY/usr/bin/badvpn-udpgw"

OUT_HEALTHY="$TMP/out-healthy.txt"
GAMECHECK_ROOT="$HEALTHY" PATH="$TMP/bin-healthy:$PATH" \
    bash "$SCRIPT" --plain >"$OUT_HEALTHY" 2>&1
CODE_HEALTHY=$?

echo "Skenario 2 (sehat):"
check_absent "tidak ada FAIL di VPS sehat" "$OUT_HEALTHY" "^  FAIL"
check_contains "UDPGW terdeteksi lengkap" "$OUT_HEALTHY" "UDPGW listen di:"
check_contains "proxy_read_timeout dikenali" "$OUT_HEALTHY" "proxy_read_timeout eksplisit"
if [ "$CODE_HEALTHY" -eq 0 ]; then
    echo "  ok   exit code 0 tanpa FAIL"
else
    echo "  FAIL exit code $CODE_HEALTHY (harusnya 0)"; fail=$((fail + 1))
    cat "$OUT_HEALTHY"
fi

echo
if [ "$fail" -eq 0 ]; then
    echo "Semua tes lolos."
    exit 0
fi
echo "$fail tes gagal."
exit 1
