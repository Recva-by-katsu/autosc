#!/bin/bash
# KatsuTun Premium - SlowDNS (SSH over DNS tunnel).
#
# SlowDNS memakai dnstt-server: client menyambung ke server lewat DNS (UDP 53),
# lalu tunnel diteruskan ke OpenSSH di 127.0.0.1:22. Jadi SATU akun SSH yang
# sudah ada langsung bisa dipakai di aplikasi SlowDNS (NS + public key), tanpa
# membuat akun kedua.
#
# Perintah:
#   menu-slowdns                 menu interaktif
#   menu-slowdns install         unduh binary + buat keypair
#   menu-slowdns ns <domain>     set nameserver, mis. slow.domainanda.com
#   menu-slowdns start|stop|restart|status
#   menu-slowdns client          tampilkan konfigurasi untuk aplikasi client
#   menu-slowdns client-block    blok siap-tempel untuk menu SSH
#   menu-slowdns check           cek delegasi NS
#   menu-slowdns uninstall
#
# SLOWDNS_ROOT hanya dipakai tes offline (tests/test-slowdns.sh).

SDROOT="${SLOWDNS_ROOT:-}"
SD_BIN_PREFIX="${SD_BIN_PREFIX:-/usr/local/bin}"
SD_URL="${SLOWDNS_BIN_URL:-}"
UI_LIB="${KATSU_UI_LIB:-/usr/local/lib/katsutun/ui.sh}"

sdp() { printf '%s%s' "$SDROOT" "$1"; }

[ -r "$UI_LIB" ] || UI_LIB="$(dirname "$0")/katsu-ui.sh"
# shellcheck source=data/katsu-ui.sh
[ -r "$UI_LIB" ] && . "$UI_LIB"
declare -F ui_init >/dev/null || { echo "UI library tidak ditemukan (katsu-update apply --force)"; exit 1; }
ui_init

red="$UI_BAD"; green="$UI_GOOD"; yell="$UI_WARN"
NC="$UI_RESET"; WH="$UI_TEXT"; COLOR1="$UI_ACCENT"

sd_load() {
    NS='' ; PORT=5300 ; UPSTREAM='127.0.0.1:22' ; MTU=1232 ; DNSPORT=53
    local f; f=$(sdp /etc/slowdns/config)
    [ -r "$f" ] || return 0
    local k v
    while IFS='=' read -r k v; do
        case "$k" in
            NS)      NS=$v ;;
            PORT)    PORT=$v ;;
            UPSTREAM) UPSTREAM=$v ;;
            MTU)     MTU=$v ;;
            DNSPORT) DNSPORT=$v ;;
        esac
    done <"$f"
}

sd_save() {
    local dir; dir=$(sdp /etc/slowdns)
    mkdir -p "$dir"
    {
        printf '# KatsuTun SlowDNS\n'
        printf 'NS=%s\n' "$NS"
        printf 'PORT=%s\n' "$PORT"
        printf 'UPSTREAM=%s\n' "$UPSTREAM"
        printf 'MTU=%s\n' "$MTU"
        printf 'DNSPORT=%s\n' "$DNSPORT"
    } >"$dir/config"
    chmod 600 "$dir/config"
}

sd_bin() { printf '%s/dnstt-server' "$SD_BIN_PREFIX"; }
sd_key() { printf '%s' "$(sdp /etc/slowdns/server.key)"; }
sd_pub_file() { printf '%s' "$(sdp /etc/slowdns/server.pub)"; }
sd_pub() { cat "$(sd_pub_file)" 2>/dev/null; }
sd_installed() { [ -x "$(sd_bin)" ] && [ -s "$(sd_key)" ] && [ -s "$(sd_pub_file)" ]; }
sd_active() { [ -z "$SDROOT" ] && systemctl is-active slowdns >/dev/null 2>&1; }
sd_state() {
    if [ -n "$SDROOT" ]; then echo "n/a"; return; fi
    systemctl is-active slowdns 2>/dev/null || echo "inactive"
}

sd_arch() {
    case "$(uname -m)" in
        x86_64|amd64)   echo amd64 ;;
        aarch64|arm64)  echo arm64 ;;
        armv7l|armv6l)  echo arm ;;
        i386|i686)      echo 386 ;;
        *)              echo "" ;;
    esac
}

sd_download() {
    local arch url tmp
    arch=$(sd_arch)
    [ -n "$arch" ] || { ui_err "Arsitektur $(uname -m) tidak didukung"; return 1; }
    url=${SD_URL:-https://dnstt.network/dnstt-server-linux-$arch}
    tmp=$(mktemp)
    ui_notice "Mengunduh dnstt-server ($arch)"
    if ! (curl -fsSL "$url" -o "$tmp" 2>/dev/null || wget -qO "$tmp" "$url" 2>/dev/null); then
        rm -f "$tmp"
        ui_err "Unduhan gagal: $url"
        ui_hint "Set SLOWDNS_BIN_URL, atau build sendiri:"
        ui_hint "  apt install golang-go git && go install www.bamsoftware.com/git/dnstt.git/dnstt-server@latest"
        return 1
    fi
    # Tolak halaman error / unduhan terpotong: server dnstt selalu ELF statis.
    local magic; magic=$(head -c 2 "$tmp" 2>/dev/null)
    if [ "$magic" != "#!" ] && ! head -c 4 "$tmp" | grep -q $'\x7fELF'; then
        rm -f "$tmp"; ui_err "File yang diunduh bukan executable (kemungkinan halaman error)"; return 1
    fi
    install -m 755 "$tmp" "$(sd_bin)" || { rm -f "$tmp"; ui_err "Gagal menulis $(sd_bin)"; return 1; }
    rm -f "$tmp"
    ui_ok "Binary terpasang: $(sd_bin)"
}

sd_make_keys() {
    local dir; dir=$(sdp /etc/slowdns)
    mkdir -p "$dir"; chmod 700 "$dir"
    if [ -s "$dir/server.key" ] && [ -s "$dir/server.pub" ]; then
        ui_ok "Keypair sudah ada (tidak ditimpa)"
        return 0
    fi
    "$(sd_bin)" -gen-key -privkey-file "$dir/server.key" -pubkey-file "$dir/server.pub" >/dev/null 2>&1
    if [ ! -s "$dir/server.pub" ]; then
        ui_err "Gagal membuat keypair (binary tidak mendukung -gen-key?)"; return 1
    fi
    chmod 600 "$dir/server.key"; chmod 644 "$dir/server.pub"
    ui_ok "Keypair baru dibuat"
}

sd_write_unit() {
    sd_load
    local unit; unit=$(sdp /etc/systemd/system/slowdns.service)
    mkdir -p "$(dirname "$unit")"
    cat >"$unit" <<EOF
[Unit]
Description=KatsuTun SlowDNS (${NS:-slowdns}) - SSH over DNS tunnel
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=$(sd_bin) -udp :${PORT} -privkey-file $(sd_key) -mtu ${MTU} ${NS} ${UPSTREAM}
AmbientCapabilities=CAP_NET_BIND_SERVICE CAP_NET_ADMIN
NoNewPrivileges=true
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
    ui_ok "Unit systemd ditulis: $unit"
}

sd_redirect() {  # arahkan DNS publik ke port tunnel
    sd_load
    [ -z "$SDROOT" ] || return 0
    command -v iptables >/dev/null 2>&1 || {
        ui_warn "iptables tidak ada, bind langsung ke UDP ${DNSPORT}"; return 0; }
    if iptables -t nat -C PREROUTING -p udp --dport "$DNSPORT" -j REDIRECT --to-ports "$PORT" >/dev/null 2>&1; then
        ui_ok "Redirect UDP ${DNSPORT} -> ${PORT} sudah ada"
    elif iptables -t nat -A PREROUTING -p udp --dport "$DNSPORT" -j REDIRECT --to-ports "$PORT" >/dev/null 2>&1; then
        ui_ok "Redirect UDP ${DNSPORT} -> ${PORT} ditambahkan"
    else
        ui_warn "Gagal menambah redirect iptables (jalankan sebagai root)"
    fi
    command -v netfilter-persistent >/dev/null 2>&1 && netfilter-persistent save >/dev/null 2>&1
    sd_open_firewall
}

sd_open_firewall() {
    sd_load
    [ -z "$SDROOT" ] || return 0
    if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -qi active; then
        ufw allow "$DNSPORT"/udp >/dev/null 2>&1 && ui_ok "ufw: UDP ${DNSPORT} diizinkan"
    elif command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state >/dev/null 2>&1; then
        firewall-cmd --permanent --add-port="${DNSPORT}"/udp >/dev/null 2>&1 && firewall-cmd --reload >/dev/null 2>&1
        ui_ok "firewalld: UDP ${DNSPORT} diizinkan"
    fi
}

sd_restart_svc() {
    [ -z "$SDROOT" ] || return 0
    systemctl daemon-reload >/dev/null 2>&1
    systemctl enable slowdns >/dev/null 2>&1
    systemctl restart slowdns >/dev/null 2>&1 && ui_ok "Service slowdns dijalankan" || ui_err "Service slowdns gagal start (lihat menu-slowdns log)"
}

sd_install() {
    ui_screen "SLOWDNS" "install / repair"
    ui_card_start
    if ! sd_installed; then
        [ -x "$(sd_bin)" ] || sd_download || { ui_card_end; ui_pause; return 1; }
        sd_make_keys || { ui_card_end; ui_pause; return 1; }
    else
        ui_ok "Binary & keypair sudah ada"
    fi
    sd_load
    if [ -z "$NS" ]; then
        ui_card_end
        ui_prompt "Nameserver (mis. slow.domainanda.com):"
        read -r NS || exit 0
        NS=${NS#.}
        if [ -z "$NS" ]; then ui_err "Nameserver tidak boleh kosong"; ui_pause; return 1; fi
        sd_save
        ui_card_start
    fi
    ui_kv "Nameserver" "$NS"
    ui_kv "Port UDP" "$DNSPORT -> $PORT"
    ui_kv "Upstream" "$UPSTREAM (OpenSSH)"
    ui_card_end
    sd_redirect
    sd_write_unit
    sd_restart_svc
    ui_pause
}

sd_client_block() {  # blok SlowDNS siap tempel (dipakai menu-ssh)
    sd_load
    sd_installed || return 1
    local pub domain
    pub=$(sd_pub)
    domain=$(cat "$(sdp /etc/xray/domain)" 2>/dev/null)
    [ -n "$domain" ] || domain=$(cat "$(sdp /root/domain)" 2>/dev/null)
    ui_card_start "SLOWDNS"
    ui_kv "Server" "${domain:--}"
    ui_kv "Nameserver" "${NS:--}"
    ui_kv "Port SSH" "22"
    ui_kv "Service" "$(ui_badge "$(sd_state)")"
    ui_card_end
    ui_copy "Public key (SlowDNS)" "${pub:--}"
}

sd_client() {
    sd_load
    ui_screen "SLOWDNS CLIENT" "isi ke aplikasi SlowDNS / HTTP Custom"
    if ! sd_installed; then
        ui_card_start; ui_warn "SlowDNS belum terpasang. Pilih menu Install."; ui_card_end
        ui_pause; return 1
    fi
    sd_client_block
    ui_card_start
    ui_hint "Username & password = akun SSH yang sudah ada."
    ui_hint "Satu akun SSH langsung aktif di SlowDNS."
    ui_card_end
    ui_pause
}

sd_check() {
    sd_load
    ui_screen "SLOWDNS" "verifikasi delegasi NS"
    ui_card_start
    ui_kv "Nameserver" "${NS:--}"
    if [ -z "$NS" ]; then
        ui_warn "Nameserver belum diset"
    elif command -v dig >/dev/null 2>&1; then
        local out; out=$(dig +short NS "$NS" 2>/dev/null | tr '\n' ' ')
        if [ -z "$out" ]; then
            ui_err "NS $NS belum didelegasikan"
        elif printf '%s' "$out" | grep -qi "$NS"; then
            ui_ok "Delegasi NS aktif: $out"
        else
            ui_warn "NS menjawab: $out"
        fi
        local a; a=$(dig +short A "${NS#*.}" 2>/dev/null | head -n1)
        [ -n "$a" ] && ui_kv "Domain IP" "$a"
    else
        ui_hint "dig tidak tersedia (apt install dnsutils)"
    fi
    ui_hint "Buat NS record di panel domain: ${NS:-<ns>} -> IP VPS ini"
    ui_card_end
    ui_pause
}

sd_setns() {
    sd_load
    NS="$1"
    [ -n "$NS" ] || { ui_err "Nameserver kosong"; return 1; }
    sd_save
    sd_write_unit
    sd_restart_svc
    ui_ok "Nameserver disimpan: $NS"
}

sd_stop() {
    [ -z "$SDROOT" ] || return 0
    systemctl stop slowdns >/dev/null 2>&1 && ui_ok "Service slowdns dihentikan"
}

sd_start() {
    [ -z "$SDROOT" ] || return 0
    systemctl start slowdns >/dev/null 2>&1 && ui_ok "Service slowdns dijalankan" || ui_err "Gagal start"
}

sd_log() {
    ui_screen "SLOWDNS LOG" "journalctl -u slowdns"
    [ -z "$SDROOT" ] && journalctl -u slowdns -n 30 --no-pager 2>/dev/null
    ui_pause
}

sd_uninstall() {
    ui_screen "SLOWDNS" "hapus"
    ui_card_start
    ui_warn "Service, unit, dan redirect iptables akan dihapus."
    ui_warn "Keypair di /etc/slowdns tetap disimpan."
    ui_card_end
    ui_prompt "Lanjut? (y/N):"
    read -r yn
    case "$yn" in
        y|Y)
            [ -z "$SDROOT" ] || return 0
            systemctl disable --now slowdns >/dev/null 2>&1
            rm -f "$(sdp /etc/systemd/system/slowdns.service)"
            sd_load
            if command -v iptables >/dev/null 2>&1; then
                iptables -t nat -D PREROUTING -p udp --dport "$DNSPORT" -j REDIRECT --to-ports "$PORT" >/dev/null 2>&1
                command -v netfilter-persistent >/dev/null 2>&1 && netfilter-persistent save >/dev/null 2>&1
            fi
            systemctl daemon-reload >/dev/null 2>&1
            ui_ok "SlowDNS dihapus (binary & keypair tetap)"
            ;;
    esac
    ui_pause
}

sd_menu() {
    sd_load
    ui_screen "SLOWDNS" "SSH over DNS tunnel - satu akun untuk dua jalur"
    ui_card_start "STATUS"
    ui_status_row "Service" "$(sd_state)"
    ui_kv "Binary" "$( [ -x "$(sd_bin)" ] && echo "ada" || echo "belum ada")"
    ui_kv "Nameserver" "${NS:--}"
    ui_kv "UDP" "${DNSPORT} -> ${PORT}"
    ui_card_end
    if sd_installed; then
        ui_copy "Public key" "$(sd_pub)"
    fi
    ui_card_start "ACTIONS"
    ui_options "01:Install / repair" "05:Show client config" \
               "02:Set nameserver" "06:Check delegation" \
               "03:Start service" "07:View log" \
               "04:Stop service" "08:Restart service" \
               "09:Remove" ""
    ui_card_end
    ui_back_hint
    ui_prompt
    read -r opt || exit 0
    case $opt in
        01|1) sd_install ;;
        02|2) ui_prompt "Nameserver (mis. slow.domain.com):"; read -r ns || exit 0; sd_setns "$ns"; ui_pause ;;
        03|3) sd_start; ui_pause ;;
        04|4) sd_stop; ui_pause ;;
        05|5) sd_client ;;
        06|6) sd_check ;;
        07|7) sd_log ;;
        08|8) sd_restart_svc; ui_pause ;;
        09|9) sd_uninstall ;;
        00|0|x|X|q) exit 0 ;;
        *) : ;;
    esac
    sd_menu
}

case "${1:-menu}" in
    menu)          sd_menu ;;
    install)
        sd_load
        { [ -x "$(sd_bin)" ] || sd_download; } && sd_make_keys ;;
    setup)         # dipakai installer: install + unit + service
        sd_load
        { [ -x "$(sd_bin)" ] || sd_download; } && sd_make_keys && sd_redirect && sd_write_unit && sd_restart_svc ;;
    write-unit)    sd_load; sd_write_unit ;;
    redirect)      sd_redirect ;;
    ns)            sd_setns "${2:-}" ;;
    start)         sd_start ;;
    stop)          sd_stop ;;
    restart)       sd_load; sd_write_unit; sd_redirect; sd_restart_svc ;;
    status)
        sd_load
        printf 'installed=%s\nactive=%s\nns=%s\nport=%s\nupstream=%s\npubkey=%s\n' \
            "$(sd_installed && echo yes || echo no)" "$(sd_state)" "${NS}" "${PORT}" "${UPSTREAM}" "$(sd_pub)"
        ;;
    client)        sd_client ;;
    client-block)  sd_client_block ;;
    check)         sd_check ;;
    log)           sd_log ;;
    uninstall)     sd_uninstall ;;
    *)             sd_menu ;;
esac
