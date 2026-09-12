#!/bin/bash
# Identitas repo hanya ada di /etc/katsutun/repo.conf (lihat data/repo.conf).
# katsu-update menulis ulang file itu bila hilang, jadi $RAW selalu terisi.
[ -r /etc/katsutun/repo.conf ] || katsu-update status >/dev/null 2>&1
# shellcheck source=data/repo.conf
. /etc/katsutun/repo.conf
###########- COLOR CODE -##############
colornow=$(cat /etc/yudhynetwork/theme/color.conf 2>/dev/null)
NC="\e[0m"
RED="\033[0;31m"
GREEN="\033[0;32m"
COLOR1="$(cat /etc/yudhynetwork/theme/$colornow 2>/dev/null | grep -w "TEXT" | cut -d: -f2|sed 's/ //g')"
COLBG1="$(cat /etc/yudhynetwork/theme/$colornow 2>/dev/null | grep -w "BG" | cut -d: -f2|sed 's/ //g')"
WH='\033[1;37m'
###########- KatsuTun -##########

if [ ! -x /usr/bin/katsu-update ]; then
wget -q -O /usr/bin/katsu-update "$RAW/data/katsu-update.sh" && chmod +x /usr/bin/katsu-update
fi

header() {
clear
echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
echo -e "$COLOR1 ${NC} ${COLBG1}              ${WH}• UPDATE MANAGER •               ${NC} $COLOR1 $NC"
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
}

footer() {
echo -e "$COLOR1┌────────────────────── ${WH}BY${NC} ${COLOR1}───────────────────────┐${NC}"
echo -e "$COLOR1 ${NC}                 ${WH}•  KatsuTun  •${NC}                 $COLOR1 $NC"
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
}

back() {
echo ""
read -n 1 -s -r -p "  Press any key to back on menu"
menu-update
}

box() { echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"; }
boxend() { echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"; }

function checkupdate(){
header; box
echo -e "$COLOR1 ${NC}  ${COLOR1}[INFO]${NC} Checking GitHub ..."
result=$(katsu-update check)
case "$result" in
uptodate*)  echo -e "$COLOR1 ${NC}  ${GREEN}[OK]${NC} Script sudah versi terbaru (${result#uptodate })" ;;
available*) echo -e "$COLOR1 ${NC}  ${COLOR1}[UPDATE]${NC} Update tersedia: ${WH}${result#available }${NC}"
            echo -e "$COLOR1 ${NC}  Jalankan menu ${WH}02${NC} untuk memasang sekarang" ;;
*)          echo -e "$COLOR1 ${NC}  ${RED}[ERROR]${NC} Tidak bisa menghubungi GitHub" ;;
esac
boxend; footer; back
}

function doupdate(){
header; box
echo -e "$COLOR1 ${NC}  ${COLOR1}[INFO]${NC} Installing newest commit from GitHub ..."
echo ""
katsu-update apply --force 2>&1 | sed 's/^/     /'
rc=${PIPESTATUS[0]}
echo ""
if [ "$rc" = "0" ]; then
echo -e "$COLOR1 ${NC}  ${GREEN}[OK]${NC} Update selesai, versi ${WH}$(cat /opt/.ver 2>/dev/null)${NC}"
else
echo -e "$COLOR1 ${NC}  ${RED}[ERROR]${NC} Update gagal, lihat log (menu 07)"
fi
boxend; footer; back
}

function toggleauto(){
header; box
if [ "$AUTO_UPDATE" = "on" ]; then
katsu-update disable >/dev/null
echo -e "$COLOR1 ${NC}  ${RED}[OFF]${NC} Auto update dimatikan. Cron dihapus."
echo -e "$COLOR1 ${NC}  Update manual tetap bisa lewat menu 02."
else
katsu-update enable >/dev/null
echo -e "$COLOR1 ${NC}  ${GREEN}[ON]${NC} Auto update aktif, cek setiap ${WH}$INTERVAL${NC} menit."
fi
boxend; footer; back
}

function setinterval(){
header; box
echo -e "$COLOR1 ${NC}  Interval saat ini : ${WH}$INTERVAL${NC} menit"
echo -e "$COLOR1 ${NC}  Pilihan cepat: 1, 5, 15, 30, 60, 360, 1440"
echo -e "$COLOR1 ${NC}  ${COLOR1}[NOTE]${NC} Tanpa GitHub token batasnya 60 cek/jam,"
echo -e "$COLOR1 ${NC}  jadi minimal aman adalah 2 menit."
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
echo -e "$COLOR1 ${NC}  ${RED}[OFF]${NC} Service (ws, api) tidak di-restart otomatis"
echo -e "$COLOR1 ${NC}  setelah update. Restart manual lewat menu ${WH}restart${NC}."
else
katsu-update restart-services on >/dev/null
echo -e "$COLOR1 ${NC}  ${GREEN}[ON]${NC} Service yang berubah di-restart otomatis"
fi
boxend; footer; back
}

function setbranch(){
header; box
echo -e "$COLOR1 ${NC}  Branch saat ini : ${WH}$BRANCH${NC}"
echo -e "$COLOR1 ${NC}  Repo            : ${WH}$REPO${NC}"
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
echo -e "$COLOR1 ${NC}  Repo saat ini : ${WH}$REPO${NC}"
echo -e "$COLOR1 ${NC}  Isi dengan ${WH}user/repo${NC} milik Anda untuk mengikuti fork."
echo -e "$COLOR1 ${NC}  Tersimpan di /etc/katsutun/repo.conf."
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
echo -e "$COLOR1 ${NC}  Mengembalikan file dari update sebelumnya ..."
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
echo -e "$COLOR1 ${NC}  Token GitHub (opsional) menaikkan batas cek dari"
echo -e "$COLOR1 ${NC}  60 menjadi 5000 per jam. Kosongkan untuk menghapus."
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
echo -e "$COLOR1 ${NC} ${WH}Version      ${COLOR1}: ${WH}v$VERSION ${NC}[$st_up${NC}]"
echo -e "$COLOR1 ${NC} ${WH}Installed    ${COLOR1}: ${WH}${COMMIT:-unknown}${NC}   ${WH}GitHub: ${LATEST:-?}${NC}"
echo -e "$COLOR1 ${NC} ${WH}Source       ${COLOR1}: ${WH}$REPO @ $BRANCH${NC}"
echo -e "$COLOR1 ${NC} ${WH}Auto Update  ${COLOR1}: ${WH}[$st_auto${WH}]  every ${COLOR1}$INTERVAL${WH} min${NC}"
echo -e "$COLOR1 ${NC} ${WH}Auto Restart ${COLOR1}: ${WH}[$st_rs${WH}]${NC}"
echo -e "$COLOR1 ${NC} ${WH}Last Check   ${COLOR1}: ${WH}${LASTCHECK:-never}${NC}"
boxend
echo -e " $COLOR1┌───────────────────────────────────────────────┐${NC}
 $COLOR1 $NC   ${WH}[${COLOR1}01${WH}]${NC} ${COLOR1}• ${WH}CHECK UPDATE       ${WH}[${COLOR1}06${WH}]${NC} ${COLOR1}• ${WH}SET BRANCH${NC}   $COLOR1 $NC
 $COLOR1 $NC   ${WH}[${COLOR1}02${WH}]${NC} ${COLOR1}• ${WH}UPDATE NOW         ${WH}[${COLOR1}07${WH}]${NC} ${COLOR1}• ${WH}UPDATE LOG${NC}   $COLOR1 $NC
 $COLOR1 $NC   ${WH}[${COLOR1}03${WH}]${NC} ${COLOR1}• ${WH}AUTO UPDATE ON/OFF ${WH}[${COLOR1}08${WH}]${NC} ${COLOR1}• ${WH}ROLLBACK${NC}     $COLOR1 $NC
 $COLOR1 $NC   ${WH}[${COLOR1}04${WH}]${NC} ${COLOR1}• ${WH}SET INTERVAL       ${WH}[${COLOR1}09${WH}]${NC} ${COLOR1}• ${WH}GITHUB TOKEN${NC} $COLOR1 $NC
 $COLOR1 $NC   ${WH}[${COLOR1}05${WH}]${NC} ${COLOR1}• ${WH}AUTO RESTART ON/OFF ${WH}[${COLOR1}10${WH}]${NC} ${COLOR1}• ${WH}SET REPO${NC}     $COLOR1 $NC
 $COLOR1 $NC                                              ${NC} $COLOR1 $NC
 $COLOR1 $NC   ${WH}[${COLOR1}00${WH}]${NC} ${COLOR1}• ${WH}GO BACK${NC}                              $COLOR1 $NC"
echo -e " $COLOR1└───────────────────────────────────────────────┘${NC}"
footer
echo -e ""
echo -ne " ${WH}Select menu ${COLOR1}: ${WH}"; read opt
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
00 | 0) clear ; menu ;;
*) clear ; menu-update ;;
esac
