#!/bin/bash
# Identitas repo hanya ada di /etc/katsutun/repo.conf (lihat data/repo.conf).
# katsu-update menulis ulang file itu bila hilang, jadi $RAW selalu terisi.
[ -r /etc/katsutun/repo.conf ] || katsu-update status >/dev/null 2>&1
# shellcheck source=data/repo.conf
. /etc/katsutun/repo.conf
# ===================KatsuTun Premium====================
# initializing var
export DEBIAN_FRONTEND=noninteractive
MYIP=$(wget -qO- ipinfo.io/ip);
MYIP2="s/xxxxxxxxx/$MYIP/g";
NET=$(ip -o $ANU -4 route show to default | awk '{print $5}');
source /etc/os-release
ver=$VERSION_ID

# warna & helper output dipakai di seluruh log di bawah
red='\e[1;31m'
green='\e[0;32m'
yell='\e[1;33m'
NC='\e[0m'

#detail nama perusahaan
# WAJIB di-quote: tanpa tanda kutip, "organization=KatsuTun Premium" membuat
# bash menyimpan organization="KatsuTun" lalu menjalankan "Premium" sebagai
# perintah -> "Premium: command not found".
country=ID
state=Jawa-Tengah 
locality=Pati
organization="KatsuTun Premium"
organizationalunit="KatsuTun Premium"
commonname="KatsuTun Premium"
email=plukman123@gmail.com

# simple password minimal
curl -sS "$RAW/data/password" | openssl aes-256-cbc -d -a -pass pass:scvps07gg -pbkdf2 > /etc/pam.d/common-password
chmod +x /etc/pam.d/common-password

# go to root
cd

# Edit file /etc/systemd/system/rc-local.service
cat > /etc/systemd/system/rc-local.service <<-END
[Unit]
Description=/etc/rc.local
ConditionPathExists=/etc/rc.local
[Service]
Type=forking
ExecStart=/etc/rc.local start
TimeoutSec=0
StandardOutput=tty
RemainAfterExit=yes
SysVStartPriority=99
[Install]
WantedBy=multi-user.target
END

# nano /etc/rc.local
cat > /etc/rc.local <<-END
#!/bin/sh -e
# rc.local
# By default this script does nothing.
exit 0
END


# Ubah izin akses
chmod +x /etc/rc.local

# enable rc local
systemctl enable rc-local
systemctl start rc-local.service

# disable ipv6
#echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
#sed -i '$ i\echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6' /etc/rc.local

#update
apt update -y
apt upgrade -y
apt dist-upgrade -y
apt-get remove --purge ufw firewalld -y
apt-get remove --purge exim4 -y

#install jq
apt -y install jq

#install shc
apt -y install shc

# install wget and curl
apt -y install wget curl

#figlet
apt-get install figlet -y
apt-get install ruby -y
gem install lolcat

# set time GMT +7
ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime

# set locale
sed -i 's/AcceptEnv/#AcceptEnv/g' /etc/ssh/sshd_config


install_ssl(){
    if [ -f "/usr/bin/apt-get" ];then
            isDebian=`cat /etc/issue|grep Debian`
            if [ "$isDebian" != "" ];then
                    apt-get install -y nginx certbot
                    apt install -y nginx certbot
                    sleep 3s
            else
                    apt-get install -y nginx certbot
                    apt install -y nginx certbot
                    sleep 3s
            fi
    else
        yum install -y nginx certbot
        sleep 3s
    fi

    systemctl stop nginx.service

    if [ -f "/usr/bin/apt-get" ];then
            isDebian=`cat /etc/issue|grep Debian`
            if [ "$isDebian" != "" ];then
                    echo "A" | certbot certonly --renew-by-default --register-unsafely-without-email --standalone -d $domain
                    sleep 3s
            else
                    echo "A" | certbot certonly --renew-by-default --register-unsafely-without-email --standalone -d $domain
                    sleep 3s
            fi
    else
        echo "Y" | certbot certonly --renew-by-default --register-unsafely-without-email --standalone -d $domain
        sleep 3s
    fi
}

# install webserver
apt -y install nginx
cd
rm /etc/nginx/sites-enabled/default
rm /etc/nginx/sites-available/default
wget -O /etc/nginx/nginx.conf "$RAW/data/nginx.conf"
rm /etc/nginx/conf.d/vps.conf
wget -O /etc/nginx/conf.d/vps.conf "$RAW/data/vps.conf"
/etc/init.d/nginx restart

mkdir /etc/systemd/system/nginx.service.d
printf "[Service]\nExecStartPost=/bin/sleep 0.1\n" > /etc/systemd/system/nginx.service.d/override.conf
rm /etc/nginx/conf.d/default.conf
systemctl daemon-reload
service nginx restart

cd
mkdir /home/vps
mkdir /home/vps/public_html
wget -O /home/vps/public_html/index.html "$RAW/data/index"
mkdir /home/vps/public_html/ss-ws
mkdir /home/vps/public_html/clash-ws

# install badvpn udpgw
# UDP game dikirim sebagai UDP-over-TCP lewat port ini. Sebelumnya dijalankan
# dengan `screen` dari rc.local sehingga port 7400-7900 tidak pernah hidup lagi
# setelah reboot dan proses mati tidak dihidupkan ulang. Unit systemd template
# memberi auto-restart dan port yang konsisten.
cd
wget -O /usr/bin/badvpn-udpgw "$RAW/data/newudpgw"
chmod +x /usr/bin/badvpn-udpgw
cat > /etc/systemd/system/badvpn-udpgw@.service <<'UNIT'
[Unit]
Description=badvpn udpgw UDP-over-TCP on port %i
After=network.target
[Service]
ExecStart=/usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:%i --max-clients 500
Restart=always
RestartSec=2
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
for port in 7100 7200 7300 7400 7500 7600 7700 7800 7900; do
    systemctl enable --now "badvpn-udpgw@$port" >/dev/null 2>&1
done
# bersihkan sisa baris lama di rc.local supaya port tidak dobel
sed -i '/badvpn-udpgw/d' /etc/rc.local 2>/dev/null

# setting port ssh
cd
#sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g'
# /etc/ssh/sshd_config
#echo "Want to change the VPS login port? (y/n)"
#read login
#if [ "$login" != "${login#[Yy]}" ]; then
#read -rp "Input your new VPS login port : " -e port
#sed -i 's/#Port 22/Port ${port}/g' /etc/ssh/sshd_config
#sed -i '/Port 22/a Port $port' /etc/ssh/sshd_config
#/etc/init.d/ssh restart
#service ssh restart
#service sshd restart
#fi
clear

echo "=== Install Dropbear ==="
# install dropbear
#apt -y install dropbear
sed -i 's/NO_START=1/NO_START=0/g' /etc/default/dropbear
sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT=143/g' /etc/default/dropbear
sed -i 's/DROPBEAR_EXTRA_ARGS=/DROPBEAR_EXTRA_ARGS="-p 50000 -p 109 -p 110 -p 69"/g' /etc/default/dropbear
echo "/bin/false" >> /etc/shells
echo "/usr/sbin/nologin" >> /etc/shells
/etc/init.d/ssh restart
/etc/init.d/dropbear restart

# install squid
cd
apt -y install squid || apt -y install squid3
wget -q -O /etc/squid/squid.conf "$RAW/data/squid.conf" || { echo -e "[ ${red}ERROR${NC} ] Gagal unduh squid.conf" >&2; exit 1; }
[ -s /etc/squid/squid.conf ] || { echo -e "[ ${red}ERROR${NC} ] squid.conf kosong" >&2; exit 1; }
sed -i $MYIP2 /etc/squid/squid.conf
systemctl restart squid >/dev/null 2>&1 || service squid restart >/dev/null 2>&1

cd
# install stunnel
#apt install stunnel4 -y
cat > /etc/stunnel/stunnel.conf <<-END
cert = /etc/stunnel/stunnel.pem
client = no
socket = a:SO_REUSEADDR=1
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1

[dropbear]
accept = 222
connect = 127.0.0.1:22

# Nama section stunnel harus unik; dua "[dropbear]" membuat stunnel4 menolak
# config dan service mati. Port 777 = dropbear untuk websocket SSH.
[dropbear-ws]
accept = 777
connect = 127.0.0.1:109

[ws-stunnel]
accept = 2096
connect = 700

[openvpn]
accept = 442
connect = 127.0.0.1:1194

END

# make a certificate
openssl genrsa -out key.pem 2048
openssl req -new -x509 -key key.pem -out cert.pem -days 1095 \
-subj "/C=$country/ST=$state/L=$locality/O=$organization/OU=$organizationalunit/CN=$commonname/emailAddress=$email"
cat key.pem cert.pem >> /etc/stunnel/stunnel.pem

# konfigurasi stunnel
sed -i 's/ENABLED=0/ENABLED=1/g' /etc/default/stunnel4
# enable supaya stunnel4 hidup lagi setelah reboot (ENABLED=1 saja tidak cukup
# kalau unit-nya belum pernah di-enable).
systemctl enable stunnel4 >/dev/null 2>&1 || true
/etc/init.d/stunnel4 restart

#OpenVPN
#echo "Want to install OpenVPN? (y/n)"; read answer
#if [ "$answer" != "$(answer#[Yy])" ]; then
wget -q "$RAW/data/vpn.sh" || { echo -e "[ ${red}ERROR${NC} ] Gagal unduh vpn.sh" >&2; exit 1; }
chmod +x vpn.sh && ./vpn.sh
#fi

# install fail2ban
apt -y install fail2ban

# Instal DDOS Flate
if [ -d '/usr/local/ddos' ]; then
	echo; echo; echo "Please un-install the previous version first"
	exit 0
else
	mkdir /usr/local/ddos
fi
clear
echo; echo 'Installing DOS-Deflate 0.6'; echo
echo; echo -n 'Downloading source files...'
wget -q -O /usr/local/ddos/ddos.conf http://www.inetbase.com/scripts/ddos/ddos.conf
echo -n '.'
wget -q -O /usr/local/ddos/LICENSE http://www.inetbase.com/scripts/ddos/LICENSE
echo -n '.'
wget -q -O /usr/local/ddos/ignore.ip.list http://www.inetbase.com/scripts/ddos/ignore.ip.list
echo -n '.'
wget -q -O /usr/local/ddos/ddos.sh http://www.inetbase.com/scripts/ddos/ddos.sh
chmod 0755 /usr/local/ddos/ddos.sh
cp -s /usr/local/ddos/ddos.sh /usr/local/sbin/ddos
echo '...done'
echo; echo -n 'Creating cron to run script every minute.....(Default setting)'
/usr/local/ddos/ddos.sh --cron > /dev/null 2>&1
echo '.....done'
echo; echo 'Installation has completed.'
echo 'Config file is at /usr/local/ddos/ddos.conf'
echo 'Please send in your comments and/or suggestions to zaf@vsnl.com'
sleep 1

# banner /etc/issue.net
echo -e "[ ${green}INFO$NC ] Settings banner"
wget -q -O /etc/issue.net "$RAW/data/issue.net"
# Banner is a template; fill in the repo's own branding/contact.
sed -i -e "s|__BRAND__|${BRAND:-KatsuTun Premium}|g" -e "s|__CONTACT__|${REPO_URL#https://}|g" /etc/issue.net
chmod +x /etc/issue.net
echo "Banner /etc/issue.net" >> /etc/ssh/sshd_config
sed -i 's@DROPBEAR_BANNER=""@DROPBEAR_BANNER="/etc/issue.net"@g' /etc/default/dropbear

# download script
cd /usr/bin
wget -O speedtest "$RAW/data/speedtest_cli.py"
wget -O xp "$RAW/data/xp.sh"
wget -O auto-set "$RAW/data/auto-set.sh"
chmod +x speedtest
chmod +x xp
chmod +x auto-set
cd

cat > /etc/cron.d/re_otm <<-END
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
0 3 * * * root /sbin/reboot
END

cat > /etc/cron.d/xp_otm <<-END
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
2 0 * * * root /usr/bin/xp
END

cat > /home/re_otm <<-END
7
END

service cron restart >/dev/null 2>&1
service cron reload >/dev/null 2>&1

# remove unnecessary files
sleep 1
echo -e "[ ${green}INFO$NC ] Clearing trash"
apt autoclean -y >/dev/null 2>&1

if dpkg -s unscd >/dev/null 2>&1; then
apt -y remove --purge unscd >/dev/null 2>&1
fi

# apt-get -y --purge remove samba* >/dev/null 2>&1
# apt-get -y --purge remove apache2* >/dev/null 2>&1
# apt-get -y --purge remove bind9* >/dev/null 2>&1
# apt-get -y remove sendmail* >/dev/null 2>&1
# apt autoremove -y >/dev/null 2>&1
# finishing

cd
chown -R www-data:www-data /home/vps/public_html
sleep 1
echo -e "${yell}[SERVICE]${NC} Restart All service SSH & OVPN"
/etc/init.d/nginx restart >/dev/null 2>&1
sleep 1
echo -e "[ ${green}ok${NC} ] Restarting nginx"
/etc/init.d/openvpn restart >/dev/null 2>&1
sleep 1
echo -e "[ ${green}ok${NC} ] Restarting cron "
/etc/init.d/ssh restart >/dev/null 2>&1
sleep 1
echo -e "[ ${green}ok${NC} ] Restarting ssh "
/etc/init.d/dropbear restart >/dev/null 2>&1
sleep 1
echo -e "[ ${green}ok${NC} ] Restarting dropbear "
/etc/init.d/fail2ban restart >/dev/null 2>&1
sleep 1
echo -e "[ ${green}ok${NC} ] Restarting fail2ban "
/etc/init.d/stunnel4 restart >/dev/null 2>&1
sleep 1
echo -e "[ ${green}ok${NC} ] Restarting stunnel4 "
/etc/init.d/vnstat restart >/dev/null 2>&1
sleep 1
echo -e "[ ${green}ok${NC} ] Restarting vnstat "
/etc/init.d/squid restart >/dev/null 2>&1

screen -dmS badvpn badvpn-udpgw --listen-addr 127.0.0.1:7100 --max-clients 500
screen -dmS badvpn badvpn-udpgw --listen-addr 127.0.0.1:7200 --max-clients 500
screen -dmS badvpn badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 500
screen -dmS badvpn badvpn-udpgw --listen-addr 127.0.0.1:7400 --max-clients 500
screen -dmS badvpn badvpn-udpgw --listen-addr 127.0.0.1:7500 --max-clients 500
screen -dmS badvpn badvpn-udpgw --listen-addr 127.0.0.1:7600 --max-clients 500
screen -dmS badvpn badvpn-udpgw --listen-addr 127.0.0.1:7700 --max-clients 500
screen -dmS badvpn badvpn-udpgw --listen-addr 127.0.0.1:7800 --max-clients 500
screen -dmS badvpn badvpn-udpgw --listen-addr 127.0.0.1:7900 --max-clients 500
history -c
echo "unset HISTFILE" >> /etc/profile


rm -f /root/key.pem
rm -f /root/cert.pem
rm -f /root/ssh-vpn.sh
rm -f /root/bbr.sh

# finihsing
clear
