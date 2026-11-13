#!/bin/bash
# Tes offline data/menu-slowdns.sh.
#
# Memakai SLOWDNS_ROOT (semua path file) + SD_BIN_PREFIX (lokasi binary) +
# KATSU_UI_LIB, jadi tidak menyentuh VPS. Binary dnstt-server diganti skrip
# tiruan yang meniru perilaku -gen-key.
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/.." && pwd)
SCRIPT="$REPO/data/menu-slowdns.sh"
UI="$REPO/data/katsu-ui.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
ROOT="$TMP/root"
BIN="$TMP/bin"
mkdir -p "$ROOT/etc/xray" "$BIN" "$TMP/src"

fail=0
ok()   { printf '  ok   %s\n' "$1"; }
bad()  { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }
check_contains() { if grep -qF -- "$3" "$2"; then ok "$1"; else bad "$1 (tidak ada: $3)"; fi; }
check_missing()  { if grep -qF -- "$3" "$2"; then bad "$1 (seharusnya tidak ada: $3)"; else ok "$1"; fi; }

# --- binary dnstt-server tiruan -------------------------------------------
cat >"$TMP/src/dnstt-server" <<'EOF'
#!/bin/sh
case "$*" in
    *-gen-key*)
        out_priv=""; out_pub=""
        while [ $# -gt 0 ]; do
            case "$1" in
                -privkey-file) out_priv=$2; shift ;;
                -pubkey-file)  out_pub=$2;  shift ;;
            esac
            shift
        done
        printf 'PRIVKEYTEST%s\n' "$(printf '0%.0s' $(seq 1 52))" >"$out_priv"
        printf '7acce4919b277068fe72b5d1f4b73f67cab954cad3ee2dd7e2bf712d340b2d6c\n' >"$out_pub"
        exit 0 ;;
    -h|--help) echo "usage: dnstt-server -udp :5300 -privkey-file K -mtu 1232 NS 127.0.0.1:22"; exit 2 ;;
esac
exit 0
EOF
chmod +x "$TMP/src/dnstt-server"
printf 'domain test\n' >"$ROOT/etc/xray/domain"

run() { SLOWDNS_ROOT="$ROOT" SD_BIN_PREFIX="$BIN" KATSU_UI_LIB="$UI" NO_COLOR=1 \
        SLOWDNS_BIN_URL="file://$TMP/src/dnstt-server" \
        bash "$SCRIPT" "$@" 2>&1; }

echo "== status sebelum install"
OUT="$TMP/status1.txt"; run status >"$OUT" </dev/null
check_contains "melaporkan belum terpasang" "$OUT" "installed=no"

echo "== install (unduh tiruan + keypair)"
OUT="$TMP/install.txt"; run install >"$OUT" </dev/null
[ -x "$BIN/dnstt-server" ] && ok "binary tersalin" || bad "binary tidak tersalin"
[ -s "$ROOT/etc/slowdns/server.pub" ] && ok "public key dibuat" || bad "public key tidak dibuat"
[ "$(stat -c %a "$ROOT/etc/slowdns/server.key" 2>/dev/null)" = "600" ] \
    && ok "private key mode 600" || bad "private key mode bukan 600"

echo "== set nameserver"
run ns slow.example.com >"$TMP/ns.txt" </dev/null
check_contains "config menyimpan NS" "$ROOT/etc/slowdns/config" "NS=slow.example.com"

echo "== write-unit"
run write-unit >"$TMP/unit.txt" </dev/null
UNIT="$ROOT/etc/systemd/system/slowdns.service"
check_contains "ExecStart memakai dnstt-server" "$UNIT" "dnstt-server -udp :5300"
check_contains "privkey dari /etc/slowdns" "$UNIT" "-privkey-file $ROOT/etc/slowdns/server.key"
check_contains "domain dan upstream SSH" "$UNIT" "slow.example.com 127.0.0.1:22"
check_contains "restart otomatis" "$UNIT" "Restart=always"
check_missing "tidak ada placeholder aneh" "$UNIT" "\${"

echo "== status setelah konfigurasi"
OUT="$TMP/status2.txt"; run status >"$OUT" </dev/null
check_contains "melaporkan terpasang" "$OUT" "installed=yes"
check_contains "ns terbaca" "$OUT" "ns=slow.example.com"
check_contains "pubkey 64 hex" "$OUT" "pubkey=7acce4919b277068fe72b5d1f4b73f67cab954cad3ee2dd7e2bf712d340b2d6c"

echo "== client-block (dipakai menu-ssh)"
OUT="$TMP/client.txt"; run client-block >"$OUT" </dev/null
check_contains "judul SLOWDNS" "$OUT" "SLOWDNS"
check_contains "server domain" "$OUT" "domain test"
check_contains "nameserver tampil" "$OUT" "slow.example.com"
check_contains "port SSH 22" "$OUT" "22"
check_contains "public key utuh (tidak dipotong)" "$OUT" \
    "7acce4919b277068fe72b5d1f4b73f67cab954cad3ee2dd7e2bf712d340b2d6c"
if awk '{ if (length($0) > 200) exit 1 }' "$OUT"; then ok "tidak ada baris rusak"; else bad "baris terlalu panjang"; fi

echo "== menu aman saat stdin EOF (tidak menggantung)"
if timeout 10 bash -c "SLOWDNS_ROOT='$ROOT' SD_BIN_PREFIX='$BIN' KATSU_UI_LIB='$UI' NO_COLOR=1 bash '$SCRIPT' </dev/null >/dev/null 2>&1"; then
    ok "menu keluar sendiri pada EOF"
else
    bad "menu menggantung / error pada EOF"
fi

echo
if [ "$fail" -eq 0 ]; then
    echo "Semua tes lolos."
    exit 0
fi
echo "$fail tes gagal."
exit 1
