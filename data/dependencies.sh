#!/bin/bash
clear
red='\e[1;31m'
green='\e[1;32m'
yell='\e[1;33m'
NC='\e[0m'
green() { echo -e "\\033[32;1m${*}\\033[0m"; }
red() { echo -e "\\033[31;1m${*}\\033[0m"; }

if [[ -e /etc/debian_version ]]; then
	source /etc/os-release
	OS=$ID # debian or ubuntu
elif [[ -e /etc/centos-release ]]; then
	source /etc/os-release
	OS=centos
fi

# Default interface used by vnstat when not already exported by the caller
if [[ -z "$NET" ]]; then
	NET=$(ip -4 route show default | awk '/default/ {print $5}' | head -n1)
	[[ -z "$NET" ]] && NET=eth0
fi

echo "Tools install...!"
echo "Progress..."
sleep 2

apt update -y
apt update -y
apt dist-upgrade -y
apt install sudo -y
apt-get remove --purge ufw firewalld -y 
apt-get remove --purge exim4 -y 

#Fixing sshws and nginx not running (websocket proxies run on python3)
apt install -y python3 python3-pip

apt install -y screen curl jq bzip2 gzip coreutils rsyslog iftop \
htop zip unzip net-tools sed gnupg gnupg1 \
bc sudo apt-transport-https build-essential dirmngr libxml-parser-perl neofetch screenfetch git lsof \
openssl openvpn easy-rsa fail2ban tmux \
stunnel4 vnstat \
dropbear  libsqlite3-dev \
socat cron bash-completion ntpdate xz-utils sudo apt-transport-https \
gnupg2 dnsutils lsb-release chrony

# squid3 is a transitional package that no longer exists on newer releases
apt install -y squid || apt install -y squid3

curl -sSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install nodejs -y

# Build a newer vnstat only when the packaged one is older than 2.x
vnstat_major=$(vnstat --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -n1 | cut -d. -f1)
if [[ -z "$vnstat_major" || "$vnstat_major" -lt 2 ]]; then
	cd /root || cd
	wget -q https://humdi.net/vnstat/vnstat-2.6.tar.gz
	tar zxf vnstat-2.6.tar.gz
	cd vnstat-2.6 || exit 1
	./configure --prefix=/usr --sysconfdir=/etc >/dev/null 2>&1 && make >/dev/null 2>&1 && make install >/dev/null 2>&1
	cd /root || cd
	rm -f /root/vnstat-2.6.tar.gz >/dev/null 2>&1
	rm -rf /root/vnstat-2.6 >/dev/null 2>&1
fi

sed -i "s/Interface \"eth0\"/Interface \"$NET\"/g" /etc/vnstat.conf
vnstat -u -i "$NET" >/dev/null 2>&1
chown vnstat:vnstat /var/lib/vnstat -R
systemctl enable vnstat
systemctl restart vnstat

apt install -y libnss3-dev libnspr4-dev pkg-config libpam0g-dev libcap-ng-dev libcap-ng-utils libselinux1-dev libcurl4-nss-dev flex bison make libnss3-tools libevent-dev xl2tpd pptpd

yellow() { echo -e "\\033[33;1m${*}\\033[0m"; }
yellow "Dependencies successfully installed..."
sleep 5
clear
