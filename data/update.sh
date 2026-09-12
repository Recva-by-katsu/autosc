#!/bin/bash
###########- KatsuTun -##############
# Legacy `update` command. All real work is done by katsu-update, which
# installs every file in data/manifest.txt from the newest GitHub commit.
colornow=$(cat /etc/yudhynetwork/theme/color.conf 2>/dev/null)
NC="\e[0m"
RED="\033[0;31m"
GREEN="\033[0;32m"
COLOR1="$(cat /etc/yudhynetwork/theme/$colornow 2>/dev/null | grep -w "TEXT" | cut -d: -f2|sed 's/ //g')"
COLBG1="$(cat /etc/yudhynetwork/theme/$colornow 2>/dev/null | grep -w "BG" | cut -d: -f2|sed 's/ //g')"
WH='\033[1;37m'
REPO="https://raw.githubusercontent.com/Revaa-Cerza/autosc/main"

clear
echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
echo -e "$COLOR1 ${NC} ${COLBG1}            ${WH}• UPDATE SCRIPT VPS •              ${NC} $COLOR1 $NC"
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"

# Bootstrap the updater itself on installs that predate it.
if [ ! -x /usr/bin/katsu-update ]; then
echo -e "$COLOR1 ${NC}  $COLOR1[INFO]${NC} Installing KatsuTun updater"
wget -q -O /usr/bin/katsu-update "$REPO/data/katsu-update.sh" && chmod +x /usr/bin/katsu-update
fi

echo -e "$COLOR1 ${NC}  $COLOR1[INFO]${NC} Checking GitHub for the newest commit"
katsu-update apply --force 2>&1 | sed 's/^/     /'
rc=${PIPESTATUS[0]}
katsu-update cron

# One-off migrations that older versions ran from here.
mkdir -p /etc/lukman
[ -s /etc/lukman/city ] || {
IPVPS=$(curl -s ipinfo.io/ip ); ISP=$(curl -s ipinfo.io/org | cut -d " " -f 2-10 ); CITY=$(curl -s ipinfo.io/city )
echo "$IPVPS" > /etc/lukman/ip; echo "$ISP" > /etc/lukman/isp; echo "$CITY" > /etc/lukman/city
}
if [ ! -x /usr/local/bin/autosc-api ]; then
wget -q -O /tmp/ins-api.sh "$REPO/data/api/ins-api.sh"
[ -s /tmp/ins-api.sh ] && bash /tmp/ins-api.sh
rm -f /tmp/ins-api.sh
fi
cat <<EOF > /usr/bin/regionchecker
#!/bin/bash
echo "0" | bash <(curl -L -a https://raw.githubusercontent.com/lmc999/RegionRestrictionCheck/main/check.sh) -E en -M 4
read -n 1 -s -r -p "  Press any key to go back"
menu-set
EOF
chmod +x /usr/bin/regionchecker

echo ""
if [ "$rc" = "0" ]; then
echo -e "$COLOR1 ${NC}  ${GREEN}[OK]${NC} Successfully Up To Date! (v$(cat /opt/.ver 2>/dev/null))"
else
echo -e "$COLOR1 ${NC}  ${RED}[ERROR]${NC} Update failed, see: katsu-update log"
fi
echo -e "$COLOR1 ${NC}  $COLOR1[INFO]${NC} Manage auto update with: ${WH}menu-update${NC}"
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
