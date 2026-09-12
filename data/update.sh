#!/bin/bash
dateFromServer=$(curl -v --insecure --silent https://google.com/ 2>&1 | grep Date | sed -e 's/< Date: //')
biji=`date +"%Y-%m-%d" -d "$dateFromServer"`
###########- LawNetwork -##############
#clear
echo -e "$COLOR1 ${NC}  $COLOR1[INFO]${NC} Downloading Update File"
sleep 2
#wget -q -O /usr/bin/menu "https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/menu.sh" && chmod +x /usr/bin/menu
wget -q -O /usr/bin/menu-ss "https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/menu-ss.sh" && chmod +x /usr/bin/menu-ss
#wget -q -O /usr/bin/menu-vmess "https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/menu-vmess.sh" && chmod +x /usr/bin/menu-vmess
wget -q -O /usr/bin/menu-vless "https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/menu-vless.sh" && chmod +x /usr/bin/menu-vless
#wget -q -O /usr/bin/menu-trojan "https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/menu-trojan.sh" && chmod +x /usr/bin/menu-trojan
wget -q -O /usr/bin/menu-bot "https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/menu-bot.sh" && chmod +x /usr/bin/menu-bot
#wget -q -O /usr/bin/menu-ssh "https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/menu-ssh.sh" && chmod +x /usr/bin/menu-ssh
#wget -q -O /usr/bin/menu-set "https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/menu-set.sh" && chmod +x /usr/bin/menu-set
wget -q -O /usr/bin/menu-theme "https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/menu-theme.sh" && chmod +x /usr/bin/menu-theme
#wget -q -O /usr/bin/menu-backup "https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/menu-backup.sh" && chmod +x /usr/bin/menu-backup
wget -q -O /usr/bin/menu-ip "https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/menu-ip.sh" && chmod +x /usr/bin/menu-ip
wget -q -O /usr/bin/menu-tor "https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/menu-tor.sh" && chmod +x /usr/bin/menu-tor
wget -q -O /usr/bin/autoboot "https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/autoboot.sh" && chmod +x /usr/bin/autoboot
wget -q -O /usr/bin/menu-tcp "https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/menu-tcp.sh" && chmod +x /usr/bin/menu-tcp
wget -q -O /usr/bin/rebootvps "https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/rebootvps.sh" && chmod +x /usr/bin/rebootvps
wget -q -O /usr/bin/menu-dns "https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/menu-dns.sh" && chmod +x /usr/bin/menu-dns
wget -q -O /usr/bin/info "https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/info.sh" && chmod +x /usr/bin/info
wget -q -O /usr/bin/mspeed "https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/menu-speedtest.sh" && chmod +x /usr/bin/mspeed
wget -q -O /usr/bin/mbandwith "https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/menu-bandwith.sh" && chmod +x /usr/bin/mbandwith
wget -q -O /usr/bin/restart "https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/restart.sh" && chmod +x /usr/bin/restart
wget -q -O /usr/bin/update "https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/update.sh" && chmod +x /usr/bin/update
#echo -e " [INFO] Update Successfully"
wget -q -O /opt/.ver "https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/version"
wget -q -O /usr/bin/autoboot "https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/autoboot.sh" && chmod +x /usr/bin/autoboot
#wget -q -O /usr/bin/hidessh "https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/hidessh" && chmod +x /usr/bin/hidessh
echo ""
#sleep 2;

# 1.0.6
cd; #clear
wget -q https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/speedtest.sh; chmod +x speedtest.sh && ./speedtest.sh && rm speedtest.sh
#wget -q -O /usr/bin/menu-vmess "https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/menu-vmess.sh" && chmod +x /usr/bin/menu-vmess
#wget -q -O /usr/bin/menu-trojan "https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/menu-trojan.sh" && chmod +x /usr/bin/menu-trojan
#wget -q -O /usr/bin/menu "https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/menu.sh" && chmod +x /usr/bin/menu

# 1.0.7
#wget -q -O /usr/bin/menu-ssh "https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/menu-ssh.sh" && chmod +x /usr/bin/menu-ssh

# 1.0.8
cd
#wget "https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/bkp.sh" && chmod +x bkp.sh && ./bkp.sh && rm bkp.sh

# 1.0.9
cd; clear
wget -q -O /root/.profile https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/profile; mkdir -p profile
wget -q -O /root/profile/profile2 https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/profile2; chmod 755 /root/profile/profile2
wget -q -O /root/profile/wc https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/wc; chmod 755 /root/profile/wc
wget -q -O /root/profile/art https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/art; chmod 755 /root/profile/art

# 1.1.0
cd; clear; mkdir -p /etc/lukman
wget -q -O /usr/bin/menu-backup "https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/menu-backup.sh" && chmod +x /usr/bin/menu-backup
wget -q -O /etc/lukman/dependencies.sh https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/v1.1.0/dependencies.sh; bash /etc/lukman/dependencies.sh
#wget -q -O /usr/bin/backup https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/v1.1.0/backup.sh; chmod 755 /usr/bin/backup
wget -q -O /usr/bin/autobackup https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/v1.1.0/autobackup.sh; chmod 755 /usr/bin/autobackup
#wget -q -O /usr/bin/restore https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/v1.1.0/restore.sh; chmod 755 /usr/bin/restore
wget -q -O /usr/bin/backup_setting https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/v1.1.0/bset.sh; chmod 755 /usr/bin/backup_setting

#wget -q -O /usr/bin/menu-vmess "https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/menu-vmess.sh" && chmod +x /usr/bin/menu-vmess
#wget -q -O /usr/bin/menu-trojan "https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/menu-trojan.sh" && chmod +x /usr/bin/menu-trojan
#wget -q -O /usr/bin/menu "https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/menu.sh" && chmod +x /usr/bin/menu

# 1.1.1
cd; clear
wget -q -O city.sh https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/v1.1.1/city.sh; bash city.sh; rm city.sh
wget -q -O /usr/bin/menu "https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/menu.sh" && chmod +x /usr/bin/menu
wget -q -O /usr/bin/menu-ssh "https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/menu-ssh.sh" && chmod +x /usr/bin/menu-ssh
wget -q -O /usr/bin/menu-vmess "https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/menu-vmess.sh" && chmod +x /usr/bin/menu-vmess
wget -q -O /usr/bin/menu-trojan "https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/menu-trojan.sh" && chmod +x /usr/bin/menu-trojan
wget -q -O /usr/bin/menu-set "https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/menu-set.sh" && chmod +x /usr/bin/menu-set
wget -q -O /usr/local/bin/add-ssh-user "https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/addons/hidessh/newhide/add-ssh-user" && chmod +x /usr/local/bin/add-ssh-user
wget -q -O /usr/local/bin/del-ssh-user "https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/addons/hidessh/newhide/del-ssh-user" && chmod +x /usr/local/bin/del-ssh-user
wget -q -O /usr/bin/hidessh "https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/addons/hidessh/hidessh" && chmod +x /usr/bin/hidessh

# 1.1.2
cd; clear
wget -q -O /usr/bin/backup https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/v1.1.0/backup.sh; chmod 755 /usr/bin/backup
wget -q -O /usr/bin/restore https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/v1.1.0/restore.sh; chmod 755 /usr/bin/restore

# 1.1.3
#clear; clear
#cat <<EOF > /usr/bin/regionchecker
##!/bin/bash
#echo "0" | bash <(curl -L -a https://raw.githubusercontent.com/lmc999/RegionRestrictionCheck/main/check.sh) -E -M 4
#read -n 1 -s -r -p "  Press any key to go back"
#menu-set
#EOF
#chmod +x /usr/bin/regionchecker

# 1.1.4
clear
cat <<EOF > /usr/bin/regionchecker
#!/bin/bash
echo "0" | bash <(curl -L -a https://raw.githubusercontent.com/lmc999/RegionRestrictionCheck/main/check.sh) -E en -M 4
read -n 1 -s -r -p "  Press any key to go back"
menu-set
EOF
chmod +x /usr/bin/regionchecker

wget -q -O /usr/bin/crtxray https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/crt.sh; chmod +x /usr/bin/crtxray

# 1.2.0 - REST API + documentation site
cd; clear
# Install menu-api first and unconditionally: menu.sh entry 13 calls it, so a
# failed API install must not leave the main menu pointing at a missing command.
wget -q -O /usr/bin/menu-api "https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/menu-api.sh" && chmod +x /usr/bin/menu-api
wget -q -O /tmp/ins-api.sh https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/api/ins-api.sh
[ -s /tmp/ins-api.sh ] && bash /tmp/ins-api.sh
rm -f /tmp/ins-api.sh



# ============================================================================
rm /opt/.ver
version_up=$( curl -sS https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/version)
echo "$version_up" > /opt/.ver
# ============================================================================

#devonly
wget -q -O /usr/bin/runcheck https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/runcheck && chmod +x /usr/bin/runcheck

clear
echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
echo -e "$COLOR1 ${NC} ${COLBG1}            ${WH}• UPDATE SCRIPT VPS •              ${NC} $COLOR1 $NC"
echo -e "$COLOR1└─────────────────────────────────────────────────┘${NC}"
echo -e "$COLOR1┌─────────────────────────────────────────────────┐${NC}"
echo -e "$COLOR1 ${NC}  $COLOR1[INFO]${NC} Check for Script updates [done]"
echo -e "$COLOR1 ${NC}  $COLOR1[INFO]${NC} Downloading Update File  [done]"
echo -e "   $COLOR1[INFO] ${NC}Changelogs on v1.2.0 :
     ➢ Added REST API for all panel features
     ➢ Added API documentation site at https://<domain>/docs/
     ➢ Added API menu (menu -> 13) to manage API keys
   $COLOR1[INFO] ${NC}Changelogs on v1.1.4 :
     ➢ Fixed region checker error
     ➢ Added option on ssl cert installer (ipv4/6)
$COLOR1[INFO] ${NC}Changelogs on v1.1.3 :
     ➢ Fixed region checker error
   $COLOR1[INFO] ${NC}Changelogs on v1.1.1 :
     ➢ Fixed visual bug on menu (reduced lag)
     ➢ Updated HideSSH plugin to the latest
     ➢ Minor update
   $COLOR1[INFO] ${NC}Changelogs on v1.1.0 :
     ➢ Fixed backup menu
     ➢ Enhancement login page
     ➢ Fixed minor bugs
   $COLOR1[INFO] ${NC}Changelogs on v1.0.9 :
     ➢ There some mistakes on previous update
     so i undid the changes, wait for the next update!
     ➢ We will do the best on v1.1, soon!
   $COLOR1[INFO] ${NC}Changelogs on v1.0.8 :
     ➢ Temp fixing autobackup
   $COLOR1[INFO] ${NC}Changelogs on v1.0.7 :
     ➢ Improved output text when creating ssh
   $COLOR1[INFO] ${NC}Changelogs on v1.0.6 :
     ➢ Fixed speedtest error
     ➢ Fixed other minor bugs
     ➢ Removed bandwidth usage on menu
   $COLOR1[INFO] ${NC}Changelogs on v1.0.5 :
     ➢ Fixed minor bugs
     ➢ Added HideSSH plugins
     ➢ Changed the autoreboot time for every 24hours
     from 00.00 to 05.00 WIB"
echo ""
echo -e "$COLOR1 ${NC}  $COLOR1[INFO]${NC} Successfully Up To Date!"
