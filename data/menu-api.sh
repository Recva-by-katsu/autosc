#!/bin/bash
# Identitas repo hanya ada di /etc/katsutun/repo.conf (lihat data/repo.conf).
# katsu-update menulis ulang file itu bila hilang, jadi $RAW selalu terisi.
[ -r /etc/katsutun/repo.conf ] || katsu-update status >/dev/null 2>&1
# shellcheck source=data/repo.conf
. /etc/katsutun/repo.conf
UI_LIB=/usr/local/lib/katsutun/ui.sh
[ -r "$UI_LIB" ] || { echo "KatsuTun UI library is missing. Run: katsu-update apply --force"; exit 1; }
# shellcheck source=data/katsu-ui.sh
. "$UI_LIB"
ui_init
red="$UI_BAD"; green="$UI_GOOD"; yell="$UI_WARN"; tyblue="$UI_ACCENT"
NC="$UI_RESET"; RED="$UI_BAD"; GREEN="$UI_GOOD"; COLOR1="$UI_ACCENT"; COLBG1="$UI_BAR"; WH="$UI_TEXT"
###########- KatsuTun -##########

API_DIR="/etc/autosc-api"
KEYS_FILE="$API_DIR/keys.json"
API_BIN="/usr/local/bin/autosc-api"
domain=$(cat /etc/xray/domain 2>/dev/null)

api_status=$(systemctl is-active autosc-api 2>/dev/null)
if [[ "$api_status" == "active" ]]; then
    status_api="${GREEN}ON${NC}"
else
    status_api="${RED}OFF${NC}"
fi

# Run a helper function from the API server module without starting a server.
apicall() {
    python3 - "$@" <<'PY'
import importlib.util, json, sys
from importlib.machinery import SourceFileLoader

# The API server has no .py suffix, so the loader must be named explicitly:
# spec_from_file_location() alone returns a spec with loader=None for it.
_path = "/usr/local/bin/autosc-api"
spec = importlib.util.spec_from_file_location(
    "autoscapi", _path, loader=SourceFileLoader("autoscapi", _path))
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

action = sys.argv[1]
if action == "create":
    print(mod.create_key(sys.argv[2])["key"])
elif action == "list":
    keys = mod.list_keys()
    if not keys:
        print("  (belum ada API key)")
    else:
        print("  %-18s %-16s %-14s %-9s %s" % ("ID", "NAMA", "PREFIX", "STATUS", "TERAKHIR DIPAKAI"))
        for k in keys:
            print("  %-18s %-16s %-14s %-9s %s" % (
                k["id"], k["name"][:16], k["prefix"],
                "revoked" if k["revoked"] else "active",
                k["last_used"] or "-"))
elif action == "revoke":
    print("ok" if mod.revoke_key(sys.argv[2]) else "notfound")
elif action == "delete":
    print("ok" if mod.delete_key(sys.argv[2]) else "notfound")
elif action == "count":
    print(len([k for k in mod.list_keys() if not k["revoked"]]))
PY
}

header() {
ui_screen "REST API" "keys, docs and service control"
}

footer() {
ui_footer
}

check_installed() {
if [ ! -f "$API_BIN" ]; then
header
ui_card_start
ui_line "${RED}[ERROR]${NC} API belum terpasang."
ui_blank
ui_line "Pasang sekarang dengan perintah :"
ui_line "${WH}update${NC}"
ui_blank
ui_line "Atau langsung :"
ui_line "${WH}wget -qO /tmp/i.sh $RAW/data/api/ins-api.sh${NC}"
ui_line "${WH}bash /tmp/i.sh${NC}"
ui_card_end
footer
echo ""
ui_pause
menu
exit 0
fi
}

function genkey(){
header
ui_card_start
echo -ne "  Nama key (misal: bot-telegram) : "; read keyname
[ -z "$keyname" ] && keyname="unnamed"
newkey=$(apicall create "$keyname")
echo ""
if [ -z "$newkey" ]; then
echo -e "  ${RED}[ERROR]${NC} Gagal membuat API key"
else
echo -e "  ${WH}Nama   ${COLOR1}: ${WH}$keyname${NC}"
echo -e "  ${WH}API Key${COLOR1}: ${GREEN}$newkey${NC}"
echo ""
echo -e "  ${COLOR1}[PENTING]${NC} Key hanya ditampilkan sekali."
echo -e "  Simpan sekarang, tidak bisa dilihat lagi."
echo ""
echo -e "  Contoh pemakaian:"
echo -e "  ${WH}curl -H \"X-API-Key: $newkey\" \\
       https://$domain/api/system/info${NC}"
fi
ui_card_end
footer
echo ""
ui_pause
menu-api
}

function listkey(){
header
ui_card_start
echo ""
apicall list
echo ""
ui_card_end
footer
echo ""
ui_pause
menu-api
}

function revokekey(){
header
ui_card_start
echo ""
apicall list
echo ""
echo -ne "  Masukkan ID/nama key yang dicabut : "; read keyid
if [ -z "$keyid" ]; then
echo -e "  ${RED}[ERROR]${NC} ID tidak boleh kosong"
else
result=$(apicall revoke "$keyid")
if [ "$result" = "ok" ]; then
echo -e "  ${GREEN}[OK]${NC} Key ${WH}$keyid${NC} berhasil dicabut"
else
echo -e "  ${RED}[ERROR]${NC} Key ${WH}$keyid${NC} tidak ditemukan"
fi
fi
ui_card_end
footer
echo ""
ui_pause
menu-api
}

function delkey(){
header
ui_card_start
echo ""
apicall list
echo ""
echo -ne "  Masukkan ID/nama key yang dihapus : "; read keyid
if [ -z "$keyid" ]; then
echo -e "  ${RED}[ERROR]${NC} ID tidak boleh kosong"
else
result=$(apicall delete "$keyid")
if [ "$result" = "ok" ]; then
echo -e "  ${GREEN}[OK]${NC} Key ${WH}$keyid${NC} berhasil dihapus"
else
echo -e "  ${RED}[ERROR]${NC} Key ${WH}$keyid${NC} tidak ditemukan"
fi
fi
ui_card_end
footer
echo ""
ui_pause
menu-api
}

function apirestart(){
header
ui_card_start
ui_line "${COLOR1}[INFO]${NC} Restarting API service ..."
systemctl restart autosc-api
sleep 2
if [ "$(systemctl is-active autosc-api)" = "active" ]; then
ui_line "${GREEN}[OK]${NC} API service berjalan"
else
ui_line "${RED}[ERROR]${NC} API gagal start. Cek: journalctl -u autosc-api -n 50"
fi
ui_card_end
footer
echo ""
ui_pause
menu-api
}

function apitest(){
header
ui_card_start
ui_line "${COLOR1}[INFO]${NC} Menguji endpoint lokal ..."
echo ""
health=$(curl -s --max-time 5 http://127.0.0.1:8081/health)
if [ -n "$health" ]; then
echo -e "  ${GREEN}[OK]${NC} Local  : $health"
else
echo -e "  ${RED}[FAIL]${NC} Local  : tidak ada respon di 127.0.0.1:8081"
fi
public=$(curl -sk --max-time 8 "https://$domain/api/health")
if [ -n "$public" ]; then
echo -e "  ${GREEN}[OK]${NC} Public : $public"
else
echo -e "  ${RED}[FAIL]${NC} Public : https://$domain/api/health tidak merespon"
echo -e "         Cek nginx: nginx -t && systemctl reload nginx"
fi
echo ""
ui_card_end
footer
echo ""
ui_pause
menu-api
}

function apiinfo(){
header
ui_card_start
ui_line "${WH}Base URL   ${COLOR1}: ${WH}https://$domain/api${NC}"
ui_line "${WH}Dokumentasi${COLOR1}: ${WH}https://$domain/docs/${NC}"
ui_line "${WH}OpenAPI    ${COLOR1}: ${WH}https://$domain/api/openapi.json${NC}"
ui_line "${WH}Service    ${COLOR1}: ${WH}autosc-api (port lokal 8081)${NC}"
ui_card_end
ui_card_start
ui_line "${WH}Endpoint utama${NC}"
echo -e "  ${COLOR1}GET   ${NC}/system/info          Info VPS & service"
echo -e "  ${COLOR1}POST  ${NC}/system/services/restart"
echo -e "  ${COLOR1}GET   ${NC}/ssh   /vmess /vless /trojan /ss     Daftar akun"
echo -e "  ${COLOR1}POST  ${NC}/ssh   /vmess /vless /trojan /ss     Buat akun"
echo -e "  ${COLOR1}DELETE${NC}/{protokol}/{username}               Hapus akun"
echo -e "  ${COLOR1}POST  ${NC}/{protokol}/{username}/renew         Perpanjang"
echo -e "  ${COLOR1}GET   ${NC}/ssh/online           User SSH online"
echo -e "  ${COLOR1}GET   ${NC}/keys                 Daftar API key"
ui_card_end
ui_card_start
ui_line "${WH}Contoh membuat akun VMess${NC}"
echo -e "  ${WH}curl -X POST https://$domain/api/vmess \\"
echo -e "    -H \"X-API-Key: KEY_ANDA\" \\"
echo -e "    -H \"Content-Type: application/json\" \\"
echo -e "    -d '{\"username\":\"budi\",\"expired\":30}'${NC}"
ui_card_end
footer
echo ""
ui_pause
menu-api
}

check_installed
keycount=$(apicall count 2>/dev/null)
[ -z "$keycount" ] && keycount=0

header
ui_card_start
ui_kv "Service" "[${status_api}${NC}]"
ui_kv "Active keys" "$keycount"
ui_kv "Base URL" "https://$domain/api"
ui_kv "Docs" "https://$domain/docs/"
ui_card_end
ui_card_start
ui_options "01:Generate API key" "05:Restart API" "02:List API keys" "06:Test API" "03:Revoke API key" "07:API info" "04:Delete API key"
ui_card_end
ui_back_hint
ui_prompt
read -r opt
case $opt in
01 | 1) clear ; genkey ;;
02 | 2) clear ; listkey ;;
03 | 3) clear ; revokekey ;;
04 | 4) clear ; delkey ;;
05 | 5) clear ; apirestart ;;
06 | 6) clear ; apitest ;;
07 | 7) clear ; apiinfo ;;
00 | 0 | x | X) clear ; menu ;;
*) clear ; menu-api ;;
esac
