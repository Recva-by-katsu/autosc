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

if [ ! -x /usr/bin/katsu-update ]; then
wget -q -O /usr/bin/katsu-update "$RAW/data/katsu-update.sh" && chmod +x /usr/bin/katsu-update
fi

header() {
ui_screen "UPDATE MANAGER" "GitHub release channel"
}

footer() {
ui_footer
}

back() {
echo ""
ui_pause
menu-update
}

box() { ui_card_start; }
boxend() { ui_card_end; }

function checkupdate(){
header; box
ui_line "${COLOR1}[INFO]${NC} Checking GitHub ..."
result=$(katsu-update check)
case "$result" in
uptodate*)  ui_line "${GREEN}[OK]${NC} Script sudah versi terbaru (${result#uptodate })" ;;
available*) ui_line "${COLOR1}[UPDATE]${NC} Update tersedia: ${WH}${result#available }${NC}"
            ui_line "Jalankan menu ${WH}02${NC} untuk memasang sekarang" ;;
*)          ui_line "${RED}[ERROR]${NC} Tidak bisa menghubungi GitHub" ;;
esac
boxend; footer; back
}

function doupdate(){
header; box
ui_line "${COLOR1}[INFO]${NC} Installing newest commit from GitHub ..."
echo ""
katsu-update apply --force 2>&1 | sed 's/^/     /'
rc=${PIPESTATUS[0]}
echo ""
if [ "$rc" = "0" ]; then
ui_line "${GREEN}[OK]${NC} Update selesai, versi ${WH}$(cat /opt/.ver 2>/dev/null)${NC}"
else
ui_line "${RED}[ERROR]${NC} Update gagal, lihat log (menu 07)"
fi
boxend; footer; back
}

function toggleauto(){
header; box
if [ "$AUTO_UPDATE" = "on" ]; then
katsu-update disable >/dev/null
ui_line "${RED}[OFF]${NC} Auto update dimatikan. Cron dihapus."
ui_line "Update manual tetap bisa lewat menu 02."
else
katsu-update enable >/dev/null
ui_line "${GREEN}[ON]${NC} Auto update aktif, cek setiap ${WH}$INTERVAL${NC} menit."
fi
boxend; footer; back
}

function setinterval(){
header; box
ui_line "Interval saat ini : ${WH}$INTERVAL${NC} menit"
ui_line "Pilihan cepat: 1, 5, 15, 30, 60, 360, 1440"
ui_line "${COLOR1}[NOTE]${NC} Tanpa GitHub token batasnya 60 cek/jam,"
ui_line "jadi minimal aman adalah 2 menit."
echo ""
echo -ne "  Interval baru (1-1440 menit) : "; read iv
out=$(katsu-update interval "$iv" 2>&1)
if [ $? -eq 0 ]; then
echo -e "  ${GREEN}[OK]${NC} Interval diubah ke ${WH}$iv${NC} menit"
else
echo -e "  ${RED}[ERROR]${NC} $out"
fi
boxend; footer; back
}

function togglerestart(){
header; box
if [ "$RESTART_SERVICES" = "on" ]; then
katsu-update restart-services off >/dev/null
ui_line "${RED}[OFF]${NC} Service (ws, api) tidak di-restart otomatis"
ui_line "setelah update. Restart manual lewat menu ${WH}restart${NC}."
else
katsu-update restart-services on >/dev/null
ui_line "${GREEN}[ON]${NC} Service yang berubah di-restart otomatis"
fi
boxend; footer; back
}

function setbranch(){
header; box
ui_line "Branch saat ini : ${WH}$BRANCH${NC}"
ui_line "Repo            : ${WH}$REPO${NC}"
echo ""
echo -ne "  Branch baru (kosongkan = main) : "; read br
[ -z "$br" ] && br=main
out=$(katsu-update branch "$br" 2>&1)
if [ $? -eq 0 ]; then
echo -e "  ${GREEN}[OK]${NC} Sekarang mengikuti branch ${WH}$br${NC}"
echo -e "  Jalankan menu 02 untuk menyamakan file."
else
echo -e "  ${RED}[ERROR]${NC} $out"
fi
boxend; footer; back
}

function setrepo(){
header; box
ui_line "Repo saat ini : ${WH}$REPO${NC}"
ui_line "Isi dengan ${WH}user/repo${NC} milik Anda untuk mengikuti fork."
ui_line "Tersimpan di /etc/katsutun/repo.conf."
echo ""
echo -ne "  Repo baru (user/repo) : "; read rp
out=$(katsu-update repo "$rp" 2>&1)
if [ $? -eq 0 ]; then
echo -e "  ${GREEN}[OK]${NC} Sekarang mengikuti ${WH}$rp${NC}"
echo -e "  Jalankan menu 02 untuk menyamakan file."
else
echo -e "  ${RED}[ERROR]${NC} $out"
fi
boxend; footer; back
}

function showlog(){
header; box
katsu-update log 25 | sed 's/^/  /'
boxend; footer; back
}

function dorollback(){
header; box
ui_line "Mengembalikan file dari update sebelumnya ..."
echo -ne "  Lanjutkan? (y/n) : "; read yn
if [[ "$yn" =~ ^[Yy]$ ]]; then
katsu-update rollback 2>&1 | sed 's/^/     /'
else
echo -e "  Dibatalkan."
fi
boxend; footer; back
}

function settoken(){
header; box
ui_line "Token GitHub (opsional) menaikkan batas cek dari"
ui_line "60 menjadi 5000 per jam. Kosongkan untuk menghapus."
echo ""
echo -ne "  Token : "; read -s tok; echo ""
katsu-update token "$tok" >/dev/null
[ -n "$tok" ] && echo -e "  ${GREEN}[OK]${NC} Token disimpan" || echo -e "  ${GREEN}[OK]${NC} Token dihapus"
boxend; footer; back
}

# ------------------------------------------------------------------ main
eval "$(katsu-update status)"
if [ "$AUTO_UPDATE" = "on" ]; then st_auto="${GREEN}ON${NC}"; else st_auto="${RED}OFF${NC}"; fi
if [ "$RESTART_SERVICES" = "on" ]; then st_rs="${GREEN}ON${NC}"; else st_rs="${RED}OFF${NC}"; fi
if [ "$STATE" = "available" ]; then st_up="${COLOR1}Update Available${NC}"; else st_up="${GREEN}Latest${NC}"; fi

header
box
ui_kv "Version" "v$VERSION [$st_up${NC}]"
ui_kv "Installed" "${COMMIT:-unknown}  ${UI_MUTED}GitHub: ${LATEST:-?}${NC}"
ui_kv "Source" "$REPO @ $BRANCH"
ui_kv "Auto update" "[$st_auto${NC}] every $INTERVAL min"
ui_kv "Auto restart" "[$st_rs${NC}]"
ui_kv "Last check" "${LASTCHECK:-never}"
boxend
ui_card_start
ui_options "01:Check update" "06:Set branch" "02:Update now" "07:Update log" "03:Auto update on/off" "08:Rollback" "04:Set interval" "09:GitHub token" "05:Auto restart on/off" "10:Set repo"
ui_card_end
ui_back_hint
ui_prompt
read -r opt
case $opt in
01 | 1) clear ; checkupdate ;;
02 | 2) clear ; doupdate ;;
03 | 3) clear ; toggleauto ;;
04 | 4) clear ; setinterval ;;
05 | 5) clear ; togglerestart ;;
06 | 6) clear ; setbranch ;;
07 | 7) clear ; showlog ;;
08 | 8) clear ; dorollback ;;
09 | 9) clear ; settoken ;;
10) clear ; setrepo ;;
00 | 0 | x | X) clear ; menu ;;
*) clear ; menu-update ;;
esac
