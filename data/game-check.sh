#!/bin/bash
# katsu-gamecheck - diagnosa kenapa game (Mobile Legends, PUBG, FF, dll) gagal
# lewat VPS ini, padahal browsing/SSH normal.
#
# Skrip ini READ-ONLY: hanya membaca status service, port, sysctl, iptables -S,
# dan file konfigurasi. Tidak ada yang ditulis atau direstart.
#
# Pakai:  katsu-gamecheck [--plain]
# Exit :  0 = tidak ada masalah fatal, 1 = ada temuan FAIL
#
# GAMECHECK_ROOT hanya dipakai oleh tes offline (tests/test-game-check.sh) untuk
# mengarahkan pembacaan file ke direktori sementara.

ROOT="${GAMECHECK_ROOT:-}"
PLAIN=0
[ "${1:-}" = "--plain" ] && PLAIN=1
[ -n "${NO_COLOR:-}" ] && PLAIN=1
[ -t 1 ] || PLAIN=1

if [ "$PLAIN" = 1 ]; then
    C_OK=""; C_WARN=""; C_BAD=""; C_DIM=""; C_END=""
else
    C_OK=$'\033[1;32m'; C_WARN=$'\033[1;33m'; C_BAD=$'\033[1;31m'
    C_DIM=$'\033[2m'; C_END=$'\033[0m'
fi

OK_N=0; WARN_N=0; BAD_N=0
FINDINGS=()

have() { command -v "$1" >/dev/null 2>&1; }
# Path di dalam root (untuk tes) - jalur absolut tetap dihormati.
p() { printf '%s%s' "$ROOT" "$1"; }
fexists() { [ -e "$(p "$1")" ]; }
rd() { cat "$(p "$1")" 2>/dev/null; }

section() {
    printf '\n%s== %s ==%s\n' "$C_DIM" "$1" "$C_END"
}

ok()   { OK_N=$((OK_N + 1));   printf '  %sOK  %s %s\n'   "$C_OK"   "$C_END" "$1"; }
warn() { WARN_N=$((WARN_N + 1)); printf '  %sWARN%s %s\n' "$C_WARN" "$C_END" "$1"; FINDINGS+=("WARN|$1|${2:-}"); }
bad()  { BAD_N=$((BAD_N + 1));   printf '  %sFAIL%s %s\n' "$C_BAD"  "$C_END" "$1"; FINDINGS+=("FAIL|$1|${2:-}"); }
note() { printf '  %s----%s %s\n' "$C_DIM" "$C_END" "$1"; }

svc_active() { systemctl is-active "$1" >/dev/null 2>&1; }
svc_state() {
    if ! have systemctl; then echo "n/a"; return; fi
    local st
    st=$(systemctl is-active "$1" 2>/dev/null)
    [ -n "$st" ] || st="not-found"
    echo "$st"
}

listeners() { # TCP listeners with process names
    if have ss; then ss -lntp 2>/dev/null
    elif have netstat; then netstat -lntp 2>/dev/null
    fi
}

udp_listeners() {
    if have ss; then ss -lnup 2>/dev/null
    elif have netstat; then netstat -lnup 2>/dev/null
    fi
}

printf '%sKatsuTun - Diagnosa Game (read-only)%s\n' "$C_DIM" "$C_END"
printf 'host: %s  |  %s  |  %s\n' "$(hostname 2>/dev/null || echo -)" "$(uname -r 2>/dev/null || echo -)" "$(uname -m 2>/dev/null || echo -)"

########################################################################
section "1. Layanan inti"
########################################################################
for s in nginx ssh dropbear stunnel4; do
    st=$(svc_state "$s")
    case "$st" in
        active)     ok "$s: active" ;;
        n/a)        note "$s: systemd tidak tersedia, status tidak bisa dibaca" ;;
        not-found)  bad "$s: unit tidak ditemukan" "layanan inti belum terpasang - jalankan instalasi/katsu-update apply --force" ;;
        *)          bad "$s: $st" "game lewat jalur ini tidak akan nyambung - jalankan: systemctl restart $s" ;;
    esac
done
for s in xray v2ray; do
    if svc_active "$s"; then ok "$s: active"; fi
done
if have systemctl; then
    ovpn_units=$(systemctl list-units --type=service --all --no-legend 'openvpn*' 2>/dev/null | awk '{print $1}' | grep -v '@$' | head -5)
    if [ -n "$ovpn_units" ]; then
        while read -r u; do
            [ -z "$u" ] && continue
            printf '  %s----%s %s: %s\n' "$C_DIM" "$C_END" "$u" "$(svc_state "$u")"
        done <<<"$ovpn_units"
    else
        note "tidak ada unit openvpn-server@* (OpenVPN tidak terpasang)"
    fi
fi

########################################################################
section "2. Jalur UDP - penyebab #1 game tidak bisa"
########################################################################
UPGWBIN="$(p '/usr/bin/badvpn-udpgw')"
if [ -x "$UPGWBIN" ]; then
    ok "badvpn-udpgw ada dan executable"
    # Arsitektur binary vs kernel: udpgw 32-bit tidak jalan di VPS 64-bit tanpa lib32.
    if have readelf; then
        cls=$(readelf -h "$UPGWBIN" 2>/dev/null | awk -F: '/Class/{print $2}' | tr -d ' ')
        mach=$(readelf -h "$UPGWBIN" 2>/dev/null | awk -F: '/Machine/{print $2}' | sed 's/^ *//')
        case "$mach" in
            *X86-64*|*AArch64*|*ARM*) ok "arsitektur binary: $cls $mach" ;;
            *80386*|*Intel*86*)
                bad "badvpn-udpgw 32-bit ($mach) di sistem $(uname -m)" \
                    "pasang lib32 atau ganti binary 64-bit; tanpa ini UDP/game mati total" ;;
            *) note "arsitektur binary: $cls $mach" ;;
        esac
    fi
else
    bad "badvpn-udpgw tidak ada / tidak executable" \
        "pasang ulang dengan katsu-update apply --force (file data/newudpgw -> /usr/bin/badvpn-udpgw, mode 755)"
fi

LIVE_UPGW=$(listeners | grep -i badvpn | grep -Eo ':(7[1-9]00)\b' | tr -d ':' | sort -un | tr '\n' ' ')
if [ -z "$LIVE_UPGW" ]; then
    # tanpa hak lihat proses: cocokkan port yang lazim dipakai skrip ini
    LIVE_UPGW=$(listeners | grep -Eo '(127\.0\.0\.1|0\.0\.0\.0|\*):(7[1-9]00)\b' | grep -Eo '(7[1-9]00)$' | sort -un | tr '\n' ' ')
fi
if [ -z "$LIVE_UPGW" ]; then
    bad "tidak ada port UDPGW yang listen (7100-7900)" \
        "UDP game tidak punya jalur. Perbaiki: screen -dmS badvpn badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 500"
else
    ok "UDPGW listen di: $LIVE_UPGW"
    case " $LIVE_UPGW " in
        *" 7300 "*) : ;;
        *) bad "port 7300 (yang diumumkan ke user sebagai UDPGW) tidak listen" \
               "akun SSH dibuat dengan UDPGW 7100-7300, jadi app client akan gagal kirim UDP" ;;
    esac
fi

# Port yang hanya hidup sesi ini tapi tidak di rc.local -> hilang setelah reboot.
if fexists /etc/rc.local; then
    RC_UPGW=$(grep -Eo 'listen-addr +(127\.0\.0\.1|0\.0\.0\.0):(7[1-9]00)' "$(p /etc/rc.local)" 2>/dev/null | grep -Eo '(7[1-9]00)$' | sort -un | tr '\n' ' ')
    if [ -z "$RC_UPGW" ]; then
        bad "rc.local tidak memuat badvpn-udpgw" "setelah reboot, UDPGW hilang walau sekarang hidup"
    else
        note "rc.local menghidupkan UDPGW: $RC_UPGW"
        for port in $LIVE_UPGW; do
            case " $RC_UPGW " in
                *" $port "*) : ;;
                *) warn "port UDPGW $port hidup sekarang tapi tidak ada di rc.local" "akan mati setelah reboot" ;;
            esac
        done
        if grep -q 'screen -dmS' "$(p /etc/rc.local)" 2>/dev/null && ! have screen; then
            bad "rc.local memakai 'screen' tapi paket screen tidak terpasang" "badvpn-udpgw tidak akan start setelah reboot: apt install -y screen"
        fi
    fi
    rc_svc=$(svc_state rc-local)
    case "$rc_svc" in
        active|n/a) : ;;
        *) warn "service rc-local: $rc_svc" "rc.local tidak dijalankan saat boot -> UDPGW mati setelah reboot" ;;
    esac
fi

# OpenVPN UDP: satu-satunya jalur UDP native (paling bagus untuk game).
if udp_listeners | grep -qE ':2200\b'; then
    ok "OpenVPN UDP listening di :2200 (jalur terbaik untuk game)"
else
    if fexists /etc/openvpn/server/server-udp-2200.conf; then
        warn "OpenVPN UDP 2200 tidak listening padahal conf ada" "cek: journalctl -u openvpn-server@server-udp-2200 -n 50"
    else
        note "OpenVPN UDP 2200 tidak terpasang (bukan masalah kalau pakai SSH-WS + UDPGW)"
    fi
fi

########################################################################
section "3. Timeout idle (gejala: 'reconnecting' tiap 1-3 menit)"
########################################################################
for f in /usr/local/bin/ws-stunnel /usr/local/bin/ws-dropbear /usr/local/bin/ws-ovpn; do
    [ -f "$(p "$f")" ] || continue
    t=$(grep -m1 -E '^TIMEOUT[[:space:]]*=' "$(p "$f")" 2>/dev/null | grep -Eo '[0-9]+')
    if [ -n "$t" ]; then
        # loop select() memakai timeout 3 detik dan menutup koneksi saat count==TIMEOUT
        sec=$((t * 3))
        if [ "$sec" -lt 300 ]; then
            warn "$(basename "$f"): koneksi ditutup setelah ~${sec}s idle (TIMEOUT=$t x 3s)" \
                "gejala: putus saat loading/pause. Naikkan TIMEOUT jadi 300-1200"
        else
            ok "$(basename "$f"): idle timeout ~${sec}s"
        fi
    fi
done

NGXXRAY="/etc/nginx/conf.d/xray.conf"
if [ -f "$(p "$NGXXRAY")" ]; then
    if grep -q 'proxy_pass http://127.0.0.1:700' "$(p "$NGXXRAY")" 2>/dev/null; then
        if grep -q 'proxy_read_timeout' "$(p "$NGXXRAY")" 2>/dev/null; then
            ok "nginx SSH-WS punya proxy_read_timeout eksplisit"
        else
            bad "nginx SSH-WS (location /) tanpa proxy_read_timeout" \
                "default nginx = 60s idle lalu ditutup -> game 'reconnect'. Tambahkan: proxy_read_timeout 3600s;"
        fi
    fi
else
    note "$NGXXRAY belum ada (SSH-WS lewat nginx belum dikonfigurasi)"
fi

if fexists /etc/ssh/sshd_config; then
    cai=$(awk '/^[[:space:]]*ClientAliveInterval/{print $2}' "$(p /etc/ssh/sshd_config)" 2>/dev/null | tail -1)
    if [ -z "$cai" ] || [ "$cai" = 0 ]; then
        warn "sshd ClientAliveInterval tidak diset" "saran 30 + ClientAliveCountMax 6 supaya WS tidak diputus"
    else
        ok "sshd ClientAliveInterval=$cai"
    fi
fi

########################################################################
section "4. Proxy HTTP (squid) - dipakai sebagian app game"
########################################################################
if svc_active squid; then
    ok "squid: active"
    http_port=$(grep -E '^[[:space:]]*http_port[[:space:]]' "$(p /etc/squid/squid.conf)" 2>/dev/null | awk '{print $2}' | tr '\n' ' ')
    note "http_port: ${http_port:-3128 (default)}"
    if grep -qE '^[[:space:]]*http_access[[:space:]]+deny[[:space:]]+all' "$(p /etc/squid/squid.conf)" 2>/dev/null &&
       ! grep -qE '^[[:space:]]*http_access[[:space:]]+allow[[:space:]]+all' "$(p /etc/squid/squid.conf)" 2>/dev/null; then
        bad "squid hanya mengizinkan localhost (http_access deny all)" \
            "client dari internet dapat 403. Ini perilaku bawaan template yang ikut terpasang"
    else
        ok "squid punya aturan allow untuk client"
    fi
    if ! grep -qE '^[[:space:]]*acl[[:space:]]+SSL_ports[[:space:]]+port[[:space:]]+.*(1025-65535|[0-9]{4,5})' "$(p /etc/squid/squid.conf)" 2>/dev/null; then
        warn "CONNECT hanya diizinkan ke port 443" "tunnel TCP ke port game (mis. 30000+) ditolak squid"
    fi
else
    note "squid tidak aktif (abaikan kalau tidak memakai proxy HTTP)"
fi

########################################################################
section "5. Routing, NAT, MTU"
########################################################################
if have sysctl; then
    fwd=$(sysctl -n net.ipv4.ip_forward 2>/dev/null)
    if [ "$fwd" = 1 ]; then ok "net.ipv4.ip_forward=1"; else
        warn "net.ipv4.ip_forward=${fwd:-?}" "OpenVPN client dapat IP tapi tidak ada internet tanpa ini"
    fi
else
    note "sysctl tidak tersedia, ip_forward tidak bisa dicek"
fi

IFACE=$(ip -o -4 route show to default 2>/dev/null | awk '{print $5; exit}')
IFACE=${IFACE:-eth0}
MTU_IF=$(cat "/sys/class/net/$IFACE/mtu" 2>/dev/null || echo "?")
note "interface default: $IFACE (MTU $MTU_IF)"
if [ -e /sys/class/net/tun0/mtu ]; then
    MTU_TUN=$(cat /sys/class/net/tun0/mtu 2>/dev/null)
    if [ "${MTU_TUN:-0}" -gt 1420 ] 2>/dev/null; then
        warn "tun0 MTU $MTU_TUN terlalu besar untuk jaringan seluler" "saran: tun-mtu 1400 / mssfix 1360 di server OpenVPN"
    else
        ok "tun0 MTU $MTU_TUN"
    fi
fi

if have iptables; then
    nat=$(iptables -t nat -S POSTROUTING 2>/dev/null)
    if grep -q 'MASQUERADE' <<<"$nat"; then
        ok "iptables MASQUERADE ada"
        for net in 10.6.0.0/24 10.7.0.0/24; do
            grep -q -- "$net" <<<"$nat" || warn "tidak ada MASQUERADE untuk $net" "range OpenVPN ini tidak bisa internet"
        done
    else
        warn "tidak ada aturan MASQUERADE" "OpenVPN client tidak akan punya internet"
    fi
    if have systemctl && ! svc_active netfilter-persistent; then
        warn "netfilter-persistent tidak aktif" "aturan NAT hilang setiap reboot"
    fi
else
    note "iptables tidak tersedia"
fi

########################################################################
section "6. Pengganggu: ban, throttle, reboot otomatis"
########################################################################
if svc_active fail2ban; then
    if have fail2ban-client; then
        banned=$(fail2ban-client status 2>/dev/null | awk -F: '/Jail list/{print $2}' | tr ',' '\n' | sed 's/^ *//' | while read -r j; do
            [ -z "$j" ] && continue
            b=$(fail2ban-client status "$j" 2>/dev/null | awk -F: '/Currently banned/{gsub(/ /,"",$2);print $2+0}')
            [ "${b:-0}" -gt 0 ] && echo "$j=$b"
        done | tr '\n' ' ')
        if [ -n "$banned" ]; then
            warn "fail2ban memblokir IP: $banned" "game 'timeout' acak bisa karena IP pelanggan kena ban (CGNAT berbagi IP)"
        else
            ok "fail2ban aktif, tidak ada IP terban"
        fi
        if ! grep -qsE '^[[:space:]]*ignoreip' "$(p /etc/fail2ban/jail.local)" 2>/dev/null; then
            warn "fail2ban tanpa ignoreip" "tambahkan IP server/ISP sendiri di jail.local"
        fi
    fi
else
    note "fail2ban tidak aktif"
fi

if fexists /usr/local/ddos/ddos.conf; then
    n=$(grep -E '^[[:space:]]*NO_OF_CONNECTIONS' "$(p /usr/local/ddos/ddos.conf)" 2>/dev/null | grep -Eo '[0-9]+')
    if [ -n "$n" ] && [ "$n" -lt 300 ]; then
        warn "DDos Deflate aktif dengan NO_OF_CONNECTIONS=$n" "game membuka banyak koneksi -> IP pelanggan bisa diblokir otomatis"
    else
        note "DDos Deflate: NO_OF_CONNECTIONS=${n:-?}"
    fi
fi

for c in /etc/cron.d/re_otm /etc/cron.d/auto_reboot /etc/cron.d/ddos; do
    [ -f "$(p "$c")" ] || continue
    line=$(grep -vE '^[[:space:]]*(#|$)' "$(p "$c")" 2>/dev/null | head -1)
    case "$c" in
        *re_otm*|*auto_reboot*)
            warn "reboot otomatis aktif ($(basename "$c")): $line" "setiap reboot = semua sesi game putus; pakai interval >= 6 jam atau matikan" ;;
        *) note "$(basename "$c"): $line" ;;
    esac
done

if fexists /home/limit && [ -s "$(p /home/limit)" ]; then
    warn "limit bandwidth (wondershaper) aktif" "ping/lag game naik; matikan via menu Bandwidth"
fi
if have wondershaper && systemctl is-active wondershaper >/dev/null 2>&1; then
    warn "wondershaper.service aktif" "throttle global, termasuk trafik game"
fi

for fw in ufw firewalld; do
    if have systemctl && svc_active "$fw"; then
        warn "$fw aktif" "pastikan UDP 2200 / 7300 / TCP 80,443,2096 diizinkan"
    fi
done

qdisc=$(sysctl -n net.core.default_qdisc 2>/dev/null)
cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
if [ -n "$cc" ]; then
    note "qdisc=$qdisc congestion=$cc"
    [ "$cc" = bbr ] && ok "BBR aktif" || warn "congestion control=$cc" "BBR menurunkan lag/drop pada link seluler"
    tl=$(sysctl -n net.ipv4.tcp_low_latency 2>/dev/null)
    [ "$tl" = 1 ] && warn "net.ipv4.tcp_low_latency=1" "dengan BBR, opsi ini bisa menurunkan throughput; coba 0"
else
    note "sysctl tidak tersedia, qdisc/congestion tidak bisa dicek"
fi

########################################################################
section "7. DNS"
########################################################################
if fexists /etc/resolv.conf; then
    ns=$(awk '/^[[:space:]]*nameserver/{print $2}' "$(p /etc/resolv.conf)" 2>/dev/null | tr '\n' ' ')
    note "nameserver: ${ns:-kosong}"
    if [ -z "$ns" ]; then
        bad "/etc/resolv.conf tidak punya nameserver" "squid/nginx/xray gagal resolve -> service error"
    elif have getent && ! getent hosts one.one.one.one >/dev/null 2>&1; then
        bad "DNS tidak bisa resolve (nameserver: $ns)" "ganti DNS: menu -> 06 DNS manager -> restore"
    else
        ok "DNS resolve normal"
    fi
fi

########################################################################
section "Ringkasan"
########################################################################
printf '  OK: %s%d%s   WARN: %s%d%s   FAIL: %s%d%s\n' "$C_OK" "$OK_N" "$C_END" "$C_WARN" "$WARN_N" "$C_END" "$C_BAD" "$BAD_N" "$C_END"

if [ "$BAD_N" -eq 0 ] && [ "$WARN_N" -eq 0 ]; then
    printf '\n  Tidak ada masalah terdeteksi di server. Kalau game masih gagal, cek sisi client:\n'
    printf '  - mode SSH-WS : set UDPGW ke 7300 (atau 7100/7200), path "/", port 80/443/2096\n'
    printf '  - mode OVPN   : pakai client-udp-2200.ovpn (UDP native, paling cocok untuk game)\n'
    printf '  - SlowDNS     : jangan untuk game, latency DNS tunneling terlalu tinggi\n'
elif [ "$BAD_N" -gt 0 ]; then
    printf '\n  Perbaiki dulu item FAIL di atas, lalu jalankan ulang: katsu-gamecheck\n'
    exit 1
else
    printf '\n  Ada %d peringatan. Item ber-tanda "gejala" adalah yang biasanya membuat game putus.\n' "$WARN_N"
fi
exit 0
