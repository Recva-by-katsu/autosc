#!/bin/bash
###########- COLOR CODE -##############
colornow=$(cat /etc/yudhynetwork/theme/color.conf 2>/dev/null)
NC="\e[0m"
RED="\033[0;31m"
GREEN="\033[0;32m"
COLOR1="$(cat /etc/yudhynetwork/theme/$colornow 2>/dev/null | grep -w "TEXT" | cut -d: -f2|sed 's/ //g')"
COLBG1="$(cat /etc/yudhynetwork/theme/$colornow 2>/dev/null | grep -w "BG" | cut -d: -f2|sed 's/ //g')"
WH='\033[1;37m'
###########- LawNET -##########

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
spec = importlib.util.spec_from_file_location("autoscapi", "/usr/local/bin/autosc-api")
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
clear
echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
echo -e "$COLOR1 ${NC} ${COLBG1}               ${WH}• API PANEL MENU •              ${NC} $COLOR1 $NC"
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
}

footer() {
echo -e "$COLOR1┌────────────────────── ${WH}BY${NC} ${COLOR1}───────────────────────┐${NC}"
echo -e "$COLOR1 ${NC}                 ${WH}• LawNetwork •${NC}                 $COLOR1 $NC"
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
}

check_installed() {
if [ ! -f "$API_BIN" ]; then
header
echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
echo -e "$COLOR1 ${NC}  ${RED}[ERROR]${NC} API belum terpasang."
echo -e "$COLOR1 ${NC}  Jalankan ${WH}update${NC} untuk memasang API."
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
footer
echo ""
read -n 1 -s -r -p "  Press any key to back on menu"
menu
exit 0
fi
}

function genkey(){
header
echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
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
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
footer
echo ""
read -n 1 -s -r -p "  Press any key to back on menu"
menu-api
}

function listkey(){
header
echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
echo ""
apicall list
echo ""
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
footer
echo ""
read -n 1 -s -r -p "  Press any key to back on menu"
menu-api
}

function revokekey(){
header
echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
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
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
footer
echo ""
read -n 1 -s -r -p "  Press any key to back on menu"
menu-api
}

function delkey(){
header
echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
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
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
footer
echo ""
read -n 1 -s -r -p "  Press any key to back on menu"
menu-api
}

function apirestart(){
header
echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
echo -e "$COLOR1 ${NC}  ${COLOR1}[INFO]${NC} Restarting API service ..."
systemctl restart autosc-api
sleep 2
if [ "$(systemctl is-active autosc-api)" = "active" ]; then
echo -e "$COLOR1 ${NC}  ${GREEN}[OK]${NC} API service berjalan"
else
echo -e "$COLOR1 ${NC}  ${RED}[ERROR]${NC} API gagal start. Cek: journalctl -u autosc-api -n 50"
fi
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
footer
echo ""
read -n 1 -s -r -p "  Press any key to back on menu"
menu-api
}

function apitest(){
header
echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
echo -e "$COLOR1 ${NC}  ${COLOR1}[INFO]${NC} Menguji endpoint lokal ..."
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
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
footer
echo ""
read -n 1 -s -r -p "  Press any key to back on menu"
menu-api
}

function apiinfo(){
header
echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
echo -e "$COLOR1 ${NC} ${WH}Base URL   ${COLOR1}: ${WH}https://$domain/api${NC}"
echo -e "$COLOR1 ${NC} ${WH}Dokumentasi${COLOR1}: ${WH}https://$domain/docs/${NC}"
echo -e "$COLOR1 ${NC} ${WH}OpenAPI    ${COLOR1}: ${WH}https://$domain/api/openapi.json${NC}"
echo -e "$COLOR1 ${NC} ${WH}Service    ${COLOR1}: ${WH}autosc-api (port lokal 8081)${NC}"
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
echo -e "$COLOR1 ${NC} ${WH}Endpoint utama${NC}"
echo -e "  ${COLOR1}GET   ${NC}/system/info          Info VPS & service"
echo -e "  ${COLOR1}POST  ${NC}/system/services/restart"
echo -e "  ${COLOR1}GET   ${NC}/ssh   /vmess /vless /trojan /ss     Daftar akun"
echo -e "  ${COLOR1}POST  ${NC}/ssh   /vmess /vless /trojan /ss     Buat akun"
echo -e "  ${COLOR1}DELETE${NC}/{protokol}/{username}               Hapus akun"
echo -e "  ${COLOR1}POST  ${NC}/{protokol}/{username}/renew         Perpanjang"
echo -e "  ${COLOR1}GET   ${NC}/ssh/online           User SSH online"
echo -e "  ${COLOR1}GET   ${NC}/keys                 Daftar API key"
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
echo -e "$COLOR1 ${NC} ${WH}Contoh membuat akun VMess${NC}"
echo -e "  ${WH}curl -X POST https://$domain/api/vmess \\"
echo -e "    -H \"X-API-Key: KEY_ANDA\" \\"
echo -e "    -H \"Content-Type: application/json\" \\"
echo -e "    -d '{\"username\":\"budi\",\"expired\":30}'${NC}"
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
footer
echo ""
read -n 1 -s -r -p "  Press any key to back on menu"
menu-api
}

check_installed
keycount=$(apicall count 2>/dev/null)
[ -z "$keycount" ] && keycount=0

header
echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
echo -e "$COLOR1 ${NC} ${WH}Service    ${COLOR1}: ${WH}[${status_api}${WH}]${NC}"
echo -e "$COLOR1 ${NC} ${WH}Active Key ${COLOR1}: ${WH}$keycount${NC}"
echo -e "$COLOR1 ${NC} ${WH}Base URL   ${COLOR1}: ${WH}https://$domain/api${NC}"
echo -e "$COLOR1 ${NC} ${WH}Docs       ${COLOR1}: ${WH}https://$domain/docs/${NC}"
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
echo -e " $COLOR1┌───────────────────────────────────────────────┐${NC}
 $COLOR1 $NC   ${WH}[${COLOR1}01${WH}]${NC} ${COLOR1}• ${WH}GENERATE API KEY   ${WH}[${COLOR1}05${WH}]${NC} ${COLOR1}• ${WH}RESTART API${NC}  $COLOR1 $NC
 $COLOR1 $NC   ${WH}[${COLOR1}02${WH}]${NC} ${COLOR1}• ${WH}LIST API KEY       ${WH}[${COLOR1}06${WH}]${NC} ${COLOR1}• ${WH}TEST API${NC}     $COLOR1 $NC
 $COLOR1 $NC   ${WH}[${COLOR1}03${WH}]${NC} ${COLOR1}• ${WH}REVOKE API KEY     ${WH}[${COLOR1}07${WH}]${NC} ${COLOR1}• ${WH}API INFO${NC}     $COLOR1 $NC
 $COLOR1 $NC   ${WH}[${COLOR1}04${WH}]${NC} ${COLOR1}• ${WH}DELETE API KEY${NC}                       $COLOR1 $NC
 $COLOR1 $NC                                              ${NC} $COLOR1 $NC
 $COLOR1 $NC   ${WH}[${COLOR1}00${WH}]${NC} ${COLOR1}• ${WH}GO BACK${NC}                              $COLOR1 $NC"
echo -e " $COLOR1└───────────────────────────────────────────────┘${NC}"
footer
echo -e ""
echo -ne " ${WH}Select menu ${COLOR1}: ${WH}"; read opt
case $opt in
01 | 1) clear ; genkey ;;
02 | 2) clear ; listkey ;;
03 | 3) clear ; revokekey ;;
04 | 4) clear ; delkey ;;
05 | 5) clear ; apirestart ;;
06 | 6) clear ; apitest ;;
07 | 7) clear ; apiinfo ;;
00 | 0) clear ; menu ;;
*) clear ; menu-api ;;
esac
