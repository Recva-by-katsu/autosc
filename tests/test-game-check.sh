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
    *list-units*)  echo ""; exit 0 ;;
    *wondershaper*) echo inactive; exit 3 ;;
    *is-active*)   echo active; exit 0 ;;
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


# ---------------------------------------------------------------- skenario 3
# --fix: memastikan semua penyebab game benar-benar diperbaiki dan idempoten.
FIXROOT="$TMP/fixroot"
common_files "$FIXROOT"
mkdir -p "$FIXROOT/etc/fail2ban" "$FIXROOT/etc/sysctl.d" "$FIXROOT/etc/openvpn/server" \
         "$FIXROOT/usr/bin" "$FIXROOT/etc/systemd/system"
printf '#!/bin/sh\nexit 0\n' >"$FIXROOT/usr/bin/badvpn-udpgw"
chmod +x "$FIXROOT/usr/bin/badvpn-udpgw"
printf '#!/bin/sh\nTIMEOUT = 60\n' >"$FIXROOT/usr/local/bin/ws-stunnel"
cat >"$FIXROOT/etc/nginx/conf.d/xray.conf" <<'EOF'
location / {
    proxy_pass http://127.0.0.1:700;
    proxy_http_version 1.1;
}
EOF
cat >"$FIXROOT/etc/squid/squid.conf" <<'EOF'
#	WELCOME TO SQUID 4.6
http_access allow localhost
http_access deny all
EOF
cat >"$FIXROOT/etc/openvpn/server/server-udp-2200.conf" <<'EOF'
port 2200
proto udp
EOF
cat >"$FIXROOT/etc/rc.local" <<'EOF'
#!/bin/sh -e
screen -dmS badvpn badvpn-udpgw --listen-addr 127.0.0.1:7100 --max-clients 500
exit 0
EOF

make_stubs "$TMP/bin-fix" "LISTEN 0 128 127.0.0.1:7100 0.0.0.0:*"
FIXENV="GAMECHECK_ROOT=$FIXROOT PATH=$TMP/bin-fix:$PATH"
OUT_FIX="$TMP/out-fix.txt"
env $FIXENV bash "$SCRIPT" --fix --yes --plain >"$OUT_FIX" 2>&1
CODE_FIX=$?

echo "Skenario 3 (--fix):"
check_contains "nginx mendapat proxy_read_timeout" "$FIXROOT/etc/nginx/conf.d/xray.conf" "proxy_read_timeout 3600s"
check_contains "proxy_buffering dimatikan" "$FIXROOT/etc/nginx/conf.d/xray.conf" "proxy_buffering off"
check_contains "unit udpgw dibuat" "$FIXROOT/etc/systemd/system/badvpn-udpgw@.service" "Restart=always"
check_contains "udpgw memakai port template %i" "$FIXROOT/etc/systemd/system/badvpn-udpgw@.service" "%i"
check_contains "ws-stunnel timeout dinaikkan" "$FIXROOT/usr/local/bin/ws-stunnel" "TIMEOUT = 300"
check_contains "squid membuka akses client" "$FIXROOT/etc/squid/squid.conf" "http_access allow all"
check_contains "squid mengizinkan CONNECT port game" "$FIXROOT/etc/squid/squid.conf" "acl SSL_ports port 1025-65535"
check_contains "fail2ban jail.local dibuat" "$FIXROOT/etc/fail2ban/jail.local" "ignoreip"
check_contains "openvpn mtu 1400" "$FIXROOT/etc/openvpn/server/server-udp-2200.conf" "tun-mtu 1400"
check_contains "openvpn mssfix" "$FIXROOT/etc/openvpn/server/server-udp-2200.conf" "mssfix 1360"
check_contains "ip_forward persisten" "$FIXROOT/etc/sysctl.d/99-katsutun-game.conf" "net.ipv4.ip_forward=1"
check_absent "rc.local dibersihkan dari screen badvpn" "$FIXROOT/etc/rc.local" "badvpn-udpgw"
test -f "$FIXROOT/etc/nginx/conf.d/xray.conf.gamecheck.bak" \
    && echo "  ok   backup file asli dibuat" || { echo "  FAIL backup tidak dibuat"; fail=$((fail + 1)); }

# idempotensi: jalan kedua tidak boleh menduplikasi baris
OUT_FIX2="$TMP/out-fix2.txt"
env $FIXENV bash "$SCRIPT" --fix --yes --plain >"$OUT_FIX2" 2>&1
DUP=$(grep -c 'proxy_read_timeout' "$FIXROOT/etc/nginx/conf.d/xray.conf")
[ "$DUP" = 1 ] && echo "  ok   nginx tidak terduplikasi saat fix diulang" \
    || { echo "  FAIL proxy_read_timeout muncul $DUP kali"; fail=$((fail + 1)); }
DUP2=$(grep -c 'tun-mtu' "$FIXROOT/etc/openvpn/server/server-udp-2200.conf")
[ "$DUP2" = 1 ] && echo "  ok   openvpn tidak terduplikasi" \
    || { echo "  FAIL tun-mtu muncul $DUP2 kali"; fail=$((fail + 1)); }
grep -q "Tidak ada yang perlu diubah" "$OUT_FIX2" \
    && echo "  ok   jalan kedua melaporkan tidak ada perubahan" \
    || { echo "  FAIL jalan kedua masih mengubah sesuatu"; fail=$((fail + 1)); }
if [ "$CODE_FIX" -eq 1 ]; then
    echo "  ok   exit 1 karena masih ada FAIL tersisa"
else
    echo "  FAIL exit $CODE_FIX (diagnosa lanjutan tetap melaporkan FAIL)"; fail=$((fail + 1))
fi


# ---------------------------------------------------------------- skenario 4
# VPS yang sudah migrasi ke systemd: rc.local SUDAH dibersihkan. Ini regresi
# nyata - dulu dilaporkan FAIL "rc.local tidak memuat badvpn-udpgw".
MIG="$TMP/migrated"
common_files "$MIG"
mkdir -p "$MIG/etc/systemd/system" "$MIG/etc/cron.d" "$MIG/home" "$MIG/usr/bin"
printf '#!/bin/sh\nexit 0\n' >"$MIG/usr/bin/badvpn-udpgw"; chmod +x "$MIG/usr/bin/badvpn-udpgw"
printf '[Unit]\nDescription=%s\n' "badvpn %i" >"$MIG/etc/systemd/system/badvpn-udpgw@.service"
cat >"$MIG/etc/rc.local" <<'EOF'
#!/bin/sh -e
exit 0
EOF
printf 'SHELL=/bin/sh\nPATH=/usr/bin:/bin\n0 3 * * * root /sbin/reboot\n' >"$MIG/etc/cron.d/re_otm"
printf 'SHELL=/bin/sh\n*/30 * * * * root /usr/bin/rebootvps\n' >"$MIG/etc/cron.d/auto_reboot"
printf 'start\n' >"$MIG/home/limit"
mkdir -p "$MIG/home/limit.d" 2>/dev/null
rm -rf "$MIG/home/limit.d"
cat >"$MIG/etc/nginx/conf.d/xray.conf" <<'EOF'
location / {
    proxy_pass http://127.0.0.1:700;
    proxy_read_timeout 3600s;
}
EOF
make_stubs "$TMP/bin-mig" "LISTEN 0 128 127.0.0.1:7100 0.0.0.0:*
LISTEN 0 128 127.0.0.1:7200 0.0.0.0:*
LISTEN 0 128 127.0.0.1:7300 0.0.0.0:*"

OUT_MIG="$TMP/out-migrated.txt"
GAMECHECK_ROOT="$MIG" PATH="$TMP/bin-mig:$PATH" bash "$SCRIPT" --plain >"$OUT_MIG" 2>&1
echo "Skenario 4 (sudah migrasi ke systemd):"
check_absent "rc.local tanpa badvpn bukan FAIL" "$OUT_MIG" "rc.local tidak memuat badvpn-udpgw"
check_absent "rc.local tanpa badvpn bukan FAIL (versi baru)" "$OUT_MIG" "UDPGW tidak punya autostart"
check_contains "autostart systemd dikenali" "$OUT_MIG" "autostart UDPGW lewat systemd"
count_frequent=$(grep -c "reboot otomatis terlalu sering" "$OUT_MIG" || true)
[ "$count_frequent" = 1 ] \
    && echo "  ok   hanya reboot tiap 30 menit yang diperingatkan" \
    || { echo "  FAIL jumlah peringatan reboot = $count_frequent (harus 1)"; fail=$((fail + 1)); }
check_contains "reboot harian dilaporkan sebagai normal" "$OUT_MIG" "reboot otomatis: harian 03:00"
check_contains "reboot tiap 30 menit tetap diperingatkan" "$OUT_MIG" "reboot otomatis terlalu sering"
check_absent "penanda /home/limit basi tidak diperingatkan" "$OUT_MIG" "limit bandwidth (wondershaper/tc) aktif"
check_contains "penanda basi dilaporkan aman" "$OUT_MIG" "penanda /home/limit masih ada tapi throttle tidak aktif"

# ---------------------------------------------------------------- skenario 5
# --fix juga memasang ClientAliveInterval sshd, dan mode fix tidak membanjiri
# layar dengan baris OK.
FIX2="$TMP/fix2"
common_files "$FIX2"
cp "$MIG/etc/systemd/system/badvpn-udpgw@.service" "$FIX2/" 2>/dev/null || true
mkdir -p "$FIX2/etc/systemd/system" "$FIX2/usr/bin"
printf '[Unit]\n' >"$FIX2/etc/systemd/system/badvpn-udpgw@.service"
printf '#!/bin/sh\nexit 0\n' >"$FIX2/usr/bin/badvpn-udpgw"; chmod +x "$FIX2/usr/bin/badvpn-udpgw"
printf 'Port 22\n' >"$FIX2/etc/ssh/sshd_config"
OUT_FIX3="$TMP/out-fix3.txt"
GAMECHECK_ROOT="$FIX2" PATH="$TMP/bin-mig:$PATH" bash "$SCRIPT" --fix --yes --plain >"$OUT_FIX3" 2>&1
echo "Skenario 5 (--fix lanjutan):"
check_contains "sshd ClientAliveInterval dipasang" "$FIX2/etc/ssh/sshd_config" "ClientAliveInterval 30"
check_contains "ClientAliveCountMax ikut" "$FIX2/etc/ssh/sshd_config" "ClientAliveCountMax 6"
check_absent "mode fix menyembunyikan baris OK" "$OUT_FIX3" "  OK   nginx: active"
check_contains "mode fix tetap menampilkan ringkasan" "$OUT_FIX3" "OK:"


# ---------------------------------------------------------------- skenario 6
# OpenVPN stuck "activating": error jurnal harus ikut dilaporkan + diterjemahkan.
OVPN="$TMP/ovpn"
common_files "$OVPN"
mkdir -p "$OVPN/etc/openvpn/server" "$OVPN/etc/systemd/system" "$OVPN/usr/bin"
printf 'port 2200\nproto udp\n' >"$OVPN/etc/openvpn/server/server-udp-2200.conf"
printf '#[Unit]\n' >"$OVPN/etc/systemd/system/badvpn-udpgw@.service"
printf '#!/bin/sh\nexit 0\n' >"$OVPN/usr/bin/badvpn-udpgw"; chmod +x "$OVPN/usr/bin/badvpn-udpgw"
make_stubs "$TMP/bin-ovpn" "LISTEN 0 128 127.0.0.1:7100 0.0.0.0:*"
cat >"$TMP/bin-ovpn/systemctl" <<'EOF'
#!/bin/sh
case "$*" in
    *list-units*openvpn*) echo "openvpn-server@server-udp-2200.service loaded activating auto-restart"; exit 0 ;;
    *list-units*) echo ""; exit 0 ;;
    *openvpn*) echo activating; exit 3 ;;
    *wondershaper*) echo inactive; exit 3 ;;
    *is-active*) echo active; exit 0 ;;
esac
exit 0
EOF
chmod +x "$TMP/bin-ovpn/systemctl"
cat >"$TMP/bin-ovpn/journalctl" <<'EOF'
#!/bin/sh
echo "Options error: --comp-lzo is not supported in this version"
EOF
chmod +x "$TMP/bin-ovpn/journalctl"
cat >"$TMP/bin-ovpn/ss" <<'EOF'
#!/bin/sh
echo "LISTEN 0 128 127.0.0.1:7100 0.0.0.0:*"
EOF
chmod +x "$TMP/bin-ovpn/ss"

OUT_OVPN="$TMP/out-ovpn.txt"
GAMECHECK_ROOT="$OVPN" PATH="$TMP/bin-ovpn:$PATH" bash "$SCRIPT" --plain >"$OUT_OVPN" 2>&1
echo "Skenario 6 (OpenVPN stuck activating):"
check_contains "unit yang tidak siap jadi WARN" "$OUT_OVPN" "openvpn-server@server-udp-2200.service: activating"
check_contains "error jurnal ikut ditampilkan" "$OUT_OVPN" "comp-lzo is not supported"
check_contains "error diterjemahkan jadi saran" "$OUT_OVPN" "menolak comp-lzo"
check_contains "sisa temuan dirangkum saat ada masalah" "$OUT_OVPN" "-> proses OpenVPN tidak pernah siap"


# ---------------------------------------------------------------- skenario 7
# OVPN offline: validator harus menemukan sebab sebenarnya lalu memperbaikinya
# (comp-lzo ditolak + path plugin PAM salah), dan client .ovpn ikut disamakan.
OV="$(mktemp -d)"
mkdir -p "$OV/etc/openvpn/server" "$OV/etc/openvpn" "$OV/home/vps/public_html" \
         "$OV/usr/lib/x86_64-linux-gnu/openvpn/plugins" "$OV/etc/systemd/system" "$OV/usr/bin"
: >"$OV/usr/lib/x86_64-linux-gnu/openvpn/plugins/openvpn-plugin-auth-pam.so"
printf 'port 2200\nproto udp\ncomp-lzo\nauth-user-pass-verify x\n' >"$OV/etc/openvpn/server/server-udp-2200.conf"
printf 'port 1194\nproto tcp\nplugin /usr/lib/openvpn/openvpn-plugin-auth-pam.so login\n' >"$OV/etc/openvpn/server/server-tcp-1194.conf"
printf 'client\ncomp-lzo\n' >"$OV/etc/openvpn/client-udp-2200.ovpn"
printf 'client\ncomp-lzo\n' >"$OV/home/vps/public_html/client-udp-2200.ovpn"
printf '[Unit]\n' >"$OV/etc/systemd/system/badvpn-udpgw@.service"
printf '#!/bin/sh\nexit 0\n' >"$OV/usr/bin/badvpn-udpgw"; chmod +x "$OV/usr/bin/badvpn-udpgw"
make_stubs "$TMP/bin-ov" "LISTEN 0 128 127.0.0.1:7100 0.0.0.0:*"
cat >"$TMP/bin-ov/openvpn" <<'STUBEOF'
#!/bin/sh
case "$*" in *--version*) echo "OpenVPN 2.5.9 x86_64-pc-linux-gnu"; exit 0 ;; esac
conf=""; prev=""
for a in "$@"; do [ "$prev" = "--config" ] && conf=$a; prev=$a; done
if grep -q '^comp-lzo' "$conf" 2>/dev/null; then
    echo "Options error: --comp-lzo is not supported in this version"; exit 1
fi
if grep -q 'auth-pam' "$conf" 2>/dev/null; then
    echo "PLUGIN_INIT: could not load plugin"; exit 1
fi
exit 0
STUBEOF
chmod +x "$TMP/bin-ov/openvpn"

OUT_OV="$TMP/out-ov.txt"
GAMECHECK_ROOT="$OV" PATH="$TMP/bin-ov:$PATH" bash "$SCRIPT" --fix --yes --plain >"$OUT_OV" 2>&1
echo "Skenario 7 (OVPN offline: comp-lzo + plugin PAM):"
check_contains "comp-lzo di server dimatikan" "$OV/etc/openvpn/server/server-udp-2200.conf" "#comp-lzo"
check_contains "comp-lzo di client dimatikan" "$OV/etc/openvpn/client-udp-2200.ovpn" "#comp-lzo"
check_contains "client publik ikut disamakan" "$OV/home/vps/public_html/client-udp-2200.ovpn" "#comp-lzo"
check_contains "path plugin PAM diperbaiki" "$OV/etc/openvpn/server/server-tcp-1194.conf" \
    "$OV/usr/lib/x86_64-linux-gnu/openvpn/plugins/openvpn-plugin-auth-pam.so"
check_contains "perbaikan comp-lzo dilaporkan" "$OUT_OV" "comp-lzo dinonaktifkan"
check_contains "perbaikan plugin dilaporkan" "$OUT_OV" "path plugin PAM diperbaiki"
check_absent "tidak ada warning plugin yang salah" "$OUT_OV" "plugin PAM tidak ditemukan"


# ---------------------------------------------------------------- skenario 8
# VPS dengan paket OpenVPN 2.4 (template openvpn@): config di /etc/openvpn/server
# harus disymlink ke /etc/openvpn/<nama>.conf supaya unit-nya bisa jalan.
OV2="$(mktemp -d)"
mkdir -p "$OV2/etc/openvpn/server" "$OV2/etc/openvpn" "$OV2/etc/systemd/system" "$OV2/usr/bin"
printf 'port 2200\nproto udp\n' >"$OV2/etc/openvpn/server/server-udp-2200.conf"
printf '[Unit]\n' >"$OV2/etc/systemd/system/badvpn-udpgw@.service"
printf '#!/bin/sh\nexit 0\n' >"$OV2/usr/bin/badvpn-udpgw"; chmod +x "$OV2/usr/bin/badvpn-udpgw"
make_stubs "$TMP/bin-ov2" "LISTEN 0 128 127.0.0.1:7100 0.0.0.0:*"
cat >"$TMP/bin-ov2/systemctl" <<'STUBEOF'
#!/bin/sh
case "$*" in
    *list-unit-files*openvpn-server@*) exit 0 ;;
    *list-unit-files*openvpn@*)        echo "openvpn@.service enabled"; exit 0 ;;
    *is-active*)                       echo inactive; exit 3 ;;
esac
exit 0
STUBEOF
printf '#!/bin/sh\nexit 0\n' >"$TMP/bin-ov2/openvpn"; chmod +x "$TMP/bin-ov2/openvpn" "$TMP/bin-ov2/systemctl"

OUT_OV2="$TMP/out-ov2.txt"
GAMECHECK_ROOT="$OV2" PATH="$TMP/bin-ov2:$PATH" bash "$SCRIPT" --fix --yes --plain >"$OUT_OV2" 2>&1
echo "Skenario 8 (OpenVPN 2.4, template openvpn@):"
check_contains "template openvpn@ dikenali" "$OUT_OV2" "OpenVPN 2.4 terdeteksi"
check_contains "symlink config dibuat" "$OUT_OV2" "symlink untuk template openvpn@ dibuat"
ls -ld "$OV2/etc/openvpn/server-udp-2200.conf" >/dev/null 2>&1 \
    && printf '  ok   symlink /etc/openvpn/server-udp-2200.conf ada\n' \
    || { printf '  FAIL symlink /etc/openvpn/server-udp-2200.conf tidak dibuat\n'; fail=$((fail + 1)); }

echo
if [ "$fail" -eq 0 ]; then
    echo "Semua tes lolos."
    exit 0
fi
echo "$fail tes gagal."
exit 1
