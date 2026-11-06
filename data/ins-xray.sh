#!/bin/bash
# Identitas repo hanya ada di /etc/katsutun/repo.conf (lihat data/repo.conf).
# katsu-update menulis ulang file itu bila hilang, jadi $RAW selalu terisi.
[ -r /etc/katsutun/repo.conf ] || katsu-update status >/dev/null 2>&1
# shellcheck source=data/repo.conf
. /etc/katsutun/repo.conf
dateFromServer=$(curl -v --insecure --silent https://google.com/ 2>&1 | grep Date | sed -e 's/< Date: //')
biji=`date +"%Y-%m-%d" -d "$dateFromServer"`
############ KatsuTun Premium #############
clear
red='\e[1;31m'
green='\e[0;32m'
yell='\e[1;33m'
NC='\e[0m'
echo "Install XRAY Core Vmess / Vless/ Trojan"
echo "Suport Multi Path"
sleep 2
echo "Progress......"
sleep 3

date
echo ""
domain=$(cat /root/domain)
sleep 1
mkdir -p /etc/xray 
echo -e "[ ${green}INFO${NC} ] Checking... "
apt install iptables iptables-persistent -y
sleep 1
# ntpdate/chronyd tidak selalu ada di Ubuntu 22.04 (defaultnya chrony, tanpa
# alias chronyd.service). Hanya dipanggil bila binary/unit-nya benar-benar ada
# supaya baris "Failed to enable unit: chronyd.service" tidak muncul.
echo -e "[ ${green}INFO$NC ] Setting ntpdate"
if command -v ntpdate >/dev/null 2>&1; then
    ntpdate pool.ntp.org || true
fi
timedatectl set-ntp true || true
sleep 1
echo -e "[ ${green}INFO$NC ] Setting dll"
apt clean all && apt update
apt install curl socat xz-utils wget apt-transport-https gnupg gnupg2 gnupg1 dnsutils lsb-release -y 
apt install socat cron bash-completion ntpdate -y
apt install zip unzip -y
apt install curl pwgen openssl netcat cron -y
echo -e "[ ${green}INFO$NC ] Enable chrony"
apt -y install chrony
# Pakai unit asli (chrony), bukan alias chronyd.service yang tidak ada.
if systemctl enable --now chrony 2>/dev/null; then
    echo -e "[ ${green}ok${NC} ] chrony enabled & running"
else
    echo -e "[ ${yell}WARN${NC} ] chrony tidak bisa di-enable; time sync (NTP) dilewati."
fi
timedatectl set-timezone Asia/Jakarta || true
sleep 1
echo -e "[ ${green}INFO$NC ] Setting chrony tracking"
if command -v chronyc >/dev/null 2>&1; then
    chronyc sourcestats -v || true
    chronyc tracking -v || true
fi


# install xray
sleep 1
echo -e "[ ${green}INFO$NC ] Downloading & Installing xray core"

# --- Satu sumber kebenaran untuk versi Xray core -----------------------------
# VERSION boleh dipaksa dari environment (mis. VERSION=1.8.7 ./ins-xray.sh).
# Kalau tidak, ambil rilis stabil terbaru dari GitHub API; bila API tidak bisa
# dihubungi, pakai pin fallback. Semua langkah di bawah memakai nilai yang sama,
# dan nilai inilah yang ditampilkan di log.
XRAY_VERSION_FALLBACK="1.8.7"
VERSION="${VERSION:-}"
if [ -z "$VERSION" ]; then
    VERSION="$(curl -fsSL --retry 3 https://api.github.com/repos/XTLS/Xray-core/releases/latest 2>/dev/null \
        | grep -oE '"tag_name":[[:space:]]*"v[0-9]+\.[0-9]+\.[0-9]+"' \
        | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)"
fi
# Buang prefix "v" dan spasi/CR (mis. respons HTTP yang tidak terduga).
VERSION="${VERSION#v}"
VERSION="$(printf '%s' "$VERSION" | tr -d '[:space:]')"
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    VERSION="$XRAY_VERSION_FALLBACK"
fi
echo -e "[ ${green}INFO${NC} ] Xray core version: $VERSION"

# --- Direktori & permission (service berjalan sebagai www-data) --------------
domainSock_dir="/run/xray"
mkdir -p "$domainSock_dir"
chown www-data:www-data "$domainSock_dir"

# Make Folder XRay
mkdir -p /var/log/xray
mkdir -p /etc/xray
mkdir -p /usr/local/share/xray
chown -R www-data:www-data /var/log/xray
chmod 755 /var/log/xray
for logfile in access.log error.log access2.log error2.log; do
    touch "/var/log/xray/$logfile"
    chown www-data:www-data "/var/log/xray/$logfile"
done

# --- 1) Installer resmi XTLS/Xray-install -----------------------------------
# CARA LAMA (rusak):  bash -c "$(curl -L ...)" @ install -u www-data --version "$v"
#   * "@" itu placeholder $0 gaya `sh -c`, sehingga argumen yang benar-benar
#     sampai ke installer adalah "@ install -u www-data --version 1.8.7".
#   * install-release.sh TIDAK punya opsi "-u" (user selalu xray) sehingga
#     parsernya jatuh ke cabang default: "@: unknown option -- -" lalu exit 1.
# CARA BARU: simpan installer ke file lalu jalankan dengan argumen yang valid.
# Opsi --version butuh angka (tanpa "v"), dan tidak boleh digabung dgn -u.
XRAY_INSTALL_URL="https://github.com/XTLS/Xray-install/raw/main/install-release.sh"
INSTALLER_OK=0
if curl -fsSL --retry 3 "$XRAY_INSTALL_URL" -o /tmp/install-release.sh \
    && [ -s /tmp/install-release.sh ] \
    && bash -n /tmp/install-release.sh; then
    if bash /tmp/install-release.sh install --version "$VERSION"; then
        INSTALLER_OK=1
    else
        echo -e "[ ${yell}WARN${NC} ] Installer resmi gagal (exit $?). Lanjut ke unduhan zip rilis."
    fi
else
    echo -e "[ ${yell}WARN${NC} ] Gagal mengunduh install-release.sh dari github.com."
fi

# --- 2) Fallback: unduh zip rilis langsung -----------------------------------
if [ "$INSTALLER_OK" -ne 1 ] || [ ! -x /usr/local/bin/xray ]; then
    echo -e "[ ${yell}INFO${NC} ] Fallback: unduh Xray-linux-64.zip v${VERSION} langsung dari GitHub releases"
    apt install -y unzip >/dev/null 2>&1 || true
    xray_tmp="$(mktemp -d)"
    xray_zip="$xray_tmp/Xray-linux-64.zip"
    if curl -fL --retry 3 --retry-delay 2 \
        -o "$xray_zip" \
        "https://github.com/XTLS/Xray-core/releases/download/v${VERSION}/Xray-linux-64.zip"; then
        if unzip -oq "$xray_zip" -d "$xray_tmp"; then
            install -m 755 "$xray_tmp/xray" /usr/local/bin/xray
            mkdir -p /usr/local/share/xray
            # geoip.dat/geosite.dat tidak wajib ada di semua rilis -> jangan fatal.
            for dat in geoip.dat geosite.dat; do
                if [ -f "$xray_tmp/$dat" ]; then
                    install -m 644 "$xray_tmp/$dat" "/usr/local/share/xray/$dat"
                else
                    echo -e "[ ${yell}WARN${NC} ] $dat tidak ada di dalam zip rilis."
                fi
            done
        else
            echo -e "[ ${red}ERROR${NC} ] Gagal mengekstrak $xray_zip (file zip rusak?)."
        fi
    else
        echo -e "[ ${red}ERROR${NC} ] Gagal mengunduh https://github.com/XTLS/Xray-core/releases/download/v${VERSION}/Xray-linux-64.zip"
        echo -e "[ ${red}ERROR${NC} ] Periksa koneksi VPS ke github.com / release-assets.githubusercontent.com."
    fi
    rm -rf "$xray_tmp"
fi
rm -f /tmp/install-release.sh

# --- 3) Verifikasi wajib: binary harus ada dan bisa jalan --------------------
# Jangan pernah lanjut membuat/meng-enable xray.service kalau binary tidak ada,
# karena hasilnya cuma status=203/EXEC dan panel menampilkan XRAY OFFLINE.
if [ ! -x /usr/local/bin/xray ]; then
    echo -e "[ ${red}ERROR${NC} ] Instalasi Xray GAGAL: /usr/local/bin/xray tidak ada atau tidak executable."
    echo -e "[ ${red}ERROR${NC} ] Langkah yang gagal: unduh/install Xray core v${VERSION} (installer resmi maupun zip rilis)."
    echo -e "[ ${red}ERROR${NC} ] Service xray TIDAK dibuat/di-enable. Cek: curl -I https://github.com"
    exit 1
fi
if ! xray_check="$(/usr/local/bin/xray -version 2>&1)"; then
    echo -e "[ ${red}ERROR${NC} ] Instalasi Xray GAGAL: /usr/local/bin/xray -version tidak bisa dijalankan."
    echo -e "[ ${red}ERROR${NC} ] Output: $xray_check"
    echo -e "[ ${red}ERROR${NC} ] Service xray TIDAK dibuat/di-enable."
    exit 1
fi
installed_version="$(printf '%s\n' "$xray_check" | grep -oE 'Xray [0-9]+\.[0-9]+\.[0-9]+' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)"
echo -e "[ ${green}ok${NC} ] Xray core terpasang: ${installed_version:-versi tidak terdeteksi} (/usr/local/bin/xray)"

## crt xray
#systemctl stop nginx
#mkdir /root/.acme.sh
#curl https://acme-install.netlify.app/acme.sh -o /root/.acme.sh/acme.sh
#chmod +x /root/.acme.sh/acme.sh
#/root/.acme.sh/acme.sh --upgrade --auto-upgrade
#/root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
#/root/.acme.sh/acme.sh --issue -d $domain --standalone -k ec-256
#~/.acme.sh/acme.sh --installcert -d $domain --fullchainpath /etc/xray/xray.crt --keypath /etc/xray/xray.key --ecc

# nginx renew ssl
#echo -n '#!/bin/bash
#/etc/init.d/nginx stop
#"/root/.acme.sh"/acme.sh --cron --home "/root/.acme.sh" &> /root/renew_ssl.log
#/etc/init.d/nginx start
#' > /usr/local/bin/ssl_renew.sh
#chmod +x /usr/local/bin/ssl_renew.sh
#if ! grep -q 'ssl_renew.sh' /var/spool/cron/crontabs/root;then (crontab -l;echo "15 03 */3 * * /usr/local/bin/ssl_renew.sh") | crontab;fi

#############################################################################
# Pilihan versi IP: default IPv4. Saat dijalankan non-interaktif (tanpa TTY,
# misal via wget | bash), read akan mendapat EOF — defaultkan ke 4 supaya
# proses install tidak terhenti di tengah jalan.
if [[ -t 0 ]]; then
    read -rp "Install certificate for IPv4 or IPv6? (4/6): " ip_version
fi
ip_version="${ip_version:-4}"

issue_cert() {
    local mode="$1"
    systemctl stop nginx >/dev/null 2>&1
    mkdir -p /root/.acme.sh
    curl -fsSL https://acme-install.netlify.app/acme.sh -o /root/.acme.sh/acme.sh || return 1
    chmod +x /root/.acme.sh/acme.sh
    /root/.acme.sh/acme.sh --upgrade --auto-upgrade >/dev/null 2>&1 || true
    /root/.acme.sh/acme.sh --set-default-ca --server letsencrypt >/dev/null 2>&1 || true
    if [[ "$mode" == "6" ]]; then
        /root/.acme.sh/acme.sh --issue -d "$domain" --standalone -k ec-256 --listen-v6
    else
        /root/.acme.sh/acme.sh --issue -d "$domain" --standalone -k ec-256
    fi
}

if ! issue_cert "$ip_version" || ! ~/.acme.sh/acme.sh --installcert -d "$domain" --fullchainpath /etc/xray/xray.crt --keypath /etc/xray/xray.key --ecc; then
    echo -e "[ ${yell}WARN${NC} ] Gagal menerbitkan sertifikat Let's Encrypt untuk $domain."
    echo -e "[ ${yell}WARN${NC} ] Pastikan domain sudah diarahkan ke IP VPS dan port 80 terbuka."
    echo -e "[ ${yell}WARN${NC} ] Pasang sertifikat self-signed supaya nginx masih bisa nyala."
    mkdir -p /etc/xray
    # Idempotent: sertifikat yang sudah ada (mis. dari crtxray) jangan ditimpa.
    if [ -s /etc/xray/xray.crt ] && [ -s /etc/xray/xray.key ]; then
        echo -e "[ ${green}INFO${NC} ] Sertifikat existing dipertahankan (/etc/xray/xray.crt)."
    else
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout /etc/xray/xray.key -out /etc/xray/xray.crt \
            -subj "/CN=$domain" >/dev/null 2>&1 || true
    fi
fi

if [ ! -s /etc/xray/xray.crt ] || [ ! -s /etc/xray/xray.key ]; then
    echo -e "[ ${red}ERROR${NC} ] Tidak ada sertifikat SSL untuk $domain; nginx dan WS TLS tidak akan bisa berjalan."
fi
# nginx renew ssl
echo -n '#!/bin/bash
/etc/init.d/nginx stop
"/root/.acme.sh"/acme.sh --cron --home "/root/.acme.sh" &> /root/renew_ssl.log
/etc/init.d/nginx start
' > /usr/local/bin/ssl_renew.sh
chmod +x /usr/local/bin/ssl_renew.sh
if ! grep -q 'ssl_renew.sh' /var/spool/cron/crontabs/root; then (crontab -l; echo "15 03 */3 * * /usr/local/bin/ssl_renew.sh") | crontab; fi
###############################################################################





mkdir -p /home/vps/public_html

# set uuid
# Idempotent: saat script dijalankan ulang, pakai kembali UUID dan config yang
# sudah ada supaya akun pelanggan tidak berubah / config hasil edit tidak hilang.
uuid=$(cat /proc/sys/kernel/random/uuid)
if [ -s /etc/xray/config.json ] && grep -q '"inbounds"' /etc/xray/config.json; then
    existing_uuid="$(grep -oE '"id"[[:space:]]*:[[:space:]]*"[0-9a-fA-F-]{36}"' /etc/xray/config.json | head -n 1 | grep -oE '[0-9a-fA-F-]{36}')"
    if [ -n "$existing_uuid" ]; then
        uuid="$existing_uuid"
        echo -e "[ ${green}INFO${NC} ] Config Xray existing dipertahankan (UUID: $uuid)."
        XRAY_CONFIG_EXISTS=1
    fi
fi
XRAY_CONFIG_EXISTS="${XRAY_CONFIG_EXISTS:-0}"
# xray config
if [ "$XRAY_CONFIG_EXISTS" -eq 0 ]; then
cat > /etc/xray/config.json << END
{
  "log" : {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "warning"
  },
  "inbounds": [
      {
      "listen": "127.0.0.1",
      "port": 10000,
      "protocol": "dokodemo-door",
      "settings": {
        "address": "127.0.0.1"
      },
      "tag": "api"
    },
   {
     "listen": "127.0.0.1",
     "port": "10001",
     "protocol": "vless",
      "settings": {
          "decryption":"none",
            "clients": [
               {
                 "id": "${uuid}"
#vless
             }
          ]
       },
       "streamSettings":{
         "network": "ws",
            "wsSettings": {
                "path": "/vlessws"
          }
        }
     },
     {
     "listen": "127.0.0.1",
     "port": "10002",
     "protocol": "vmess",
      "settings": {
            "clients": [
               {
                 "id": "${uuid}",
                 "alterId": 0
#vmess
             }
          ]
       },
       "streamSettings":{
         "network": "ws",
            "wsSettings": {
                "path": "/vmess"
          }
        }
     },
    {
      "listen": "127.0.0.1",
      "port": "10003",
      "protocol": "trojan",
      "settings": {
          "decryption":"none",
           "clients": [
              {
                 "password": "${uuid}"
#trojanws
              }
          ],
         "udp": true
       },
       "streamSettings":{
           "network": "ws",
           "wsSettings": {
               "path": "/trojan"
            }
         }
     },
    {
         "listen": "127.0.0.1",
        "port": "10004",
        "protocol": "shadowsocks",
        "settings": {
           "clients": [
           {
           "method": "aes-128-gcm",
          "password": "${uuid}"
#ssws
           }
          ],
          "network": "tcp,udp"
       },
       "streamSettings":{
          "network": "ws",
             "wsSettings": {
               "path": "/ss-ws"
           }
        }
     },
      {
        "listen": "127.0.0.1",
        "port": "10005",
        "protocol": "vless",
        "settings": {
         "decryption":"none",
           "clients": [
             {
               "id": "${uuid}"
#vlessgrpc
             }
          ]
       },
          "streamSettings":{
             "network": "grpc",
             "grpcSettings": {
                "serviceName": "vless-grpc"
           }
        }
     },
     {
      "listen": "127.0.0.1",
      "port": "10006",
     "protocol": "vmess",
      "settings": {
            "clients": [
               {
                 "id": "${uuid}",
                 "alterId": 0
#vmessgrpc
             }
          ]
       },
       "streamSettings":{
         "network": "grpc",
            "grpcSettings": {
                "serviceName": "vmess-grpc"
          }
        }
     },
     {
        "listen": "127.0.0.1",
        "port": "10007",
        "protocol": "trojan",
        "settings": {
          "decryption":"none",
             "clients": [
               {
                 "password": "${uuid}"
#trojangrpc
               }
           ]
        },
         "streamSettings":{
         "network": "grpc",
           "grpcSettings": {
               "serviceName": "trojan-grpc"
         }
      }
   },
   {
    "listen": "127.0.0.1",
    "port": "10008",
    "protocol": "shadowsocks",
    "settings": {
        "clients": [
          {
             "method": "aes-128-gcm",
             "password": "${uuid}"
#ssgrpc
           }
         ],
           "network": "tcp,udp"
      },
    "streamSettings":{
     "network": "grpc",
        "grpcSettings": {
           "serviceName": "ss-grpc"
          }
       }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "blocked"
    }
  ],
  "routing": {
    "rules": [
      {
        "type": "field",
        "ip": [
          "0.0.0.0/8",
          "10.0.0.0/8",
          "100.64.0.0/10",
          "169.254.0.0/16",
          "172.16.0.0/12",
          "192.0.0.0/24",
          "192.0.2.0/24",
          "192.168.0.0/16",
          "198.18.0.0/15",
          "198.51.100.0/24",
          "203.0.113.0/24",
          "::1/128",
          "fc00::/7",
          "fe80::/10"
        ],
        "outboundTag": "blocked"
      },
      {
        "inboundTag": [
          "api"
        ],
        "outboundTag": "api",
        "type": "field"
      },
      {
        "type": "field",
        "outboundTag": "blocked",
        "protocol": [
          "bittorrent"
        ]
      }
    ]
  },
  "stats": {},
  "api": {
    "services": [
      "StatsService"
    ],
    "tag": "api"
  },
  "policy": {
    "levels": {
      "0": {
        "statsUserDownlink": true,
        "statsUserUplink": true
      }
    },
    "system": {
      "statsInboundUplink": true,
      "statsInboundDownlink": true,
      "statsOutboundUplink" : true,
      "statsOutboundDownlink" : true
    }
  }
}
END
fi # XRAY_CONFIG_EXISTS
# --- Permission file Xray untuk user www-data --------------------------------
# Service jalan sebagai www-data, jadi config & sertifikat harus bisa dibaca
# user tersebut. PrivateKey Xray tidak perlu (dan tidak boleh) world-readable.
# Catatan: install-release.sh bisa mengubah owner /var/log/xray menjadi xray:xray
# (mode 700), jadi kepemilikan www-data diterapkan ULANG di sini.
mkdir -p /var/log/xray /run/xray /usr/local/share/xray
chown -R www-data:www-data /var/log/xray
chmod 755 /var/log/xray
chown www-data:www-data /run/xray
chmod 755 /usr/local/share/xray
[ -d /usr/local/share/xray ] && chmod 644 /usr/local/share/xray/*.dat 2>/dev/null
if [ -f /etc/xray/config.json ]; then
    chown root:www-data /etc/xray/config.json 2>/dev/null || true
    chmod 640 /etc/xray/config.json
fi
if [ -f /etc/xray/xray.crt ]; then
    chown root:www-data /etc/xray/xray.crt 2>/dev/null || true
    chmod 644 /etc/xray/xray.crt
fi
if [ -f /etc/xray/xray.key ]; then
    chown root:www-data /etc/xray/xray.key 2>/dev/null || true
    chmod 640 /etc/xray/xray.key
fi
# Pastikan www-data benar-benar bisa membacanya (dicek dengan sudo -u).
for xray_file in /etc/xray/config.json /etc/xray/xray.crt /etc/xray/xray.key; do
    [ -e "$xray_file" ] || continue
    if ! runuser -u www-data -- test -r "$xray_file" 2>/dev/null; then
        echo -e "[ ${yell}WARN${NC} ] www-data belum bisa membaca $xray_file"
    fi
done

rm -rf /etc/systemd/system/xray.service.d
cat <<EOF> /etc/systemd/system/xray.service
[Unit]
Description=Xray Service
Documentation=https://github.com/xtls
After=network.target nss-lookup.target

[Service]
User=www-data
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE                                 
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/xray run -config /etc/xray/config.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target

EOF
cat > /etc/systemd/system/runn.service <<EOF
[Unit]
Description=Xray
After=network.target

[Service]
Type=simple
ExecStartPre=-/usr/bin/mkdir -p /var/run/xray
ExecStart=/usr/bin/chown www-data:www-data /var/run/xray
Restart=on-abort

[Install]
WantedBy=multi-user.target
EOF

#nginx config
cat >/etc/nginx/conf.d/xray.conf <<EOF
    server {
             listen 80;
             listen [::]:80;
             listen 8080;
             listen [::]:8080;
             listen 443 ssl http2 reuseport;
             listen [::]:443 ssl http2 reuseport;
             server_name $domain;
             ssl_certificate /etc/xray/xray.crt;
             ssl_certificate_key /etc/xray/xray.key;
             ssl_ciphers EECDH+CHACHA20:EECDH+CHACHA20-draft:EECDH+ECDSA+AES128:EECDH+aRSA+AES128:RSA+AES128:EECDH+ECDSA+AES256:EECDH+aRSA+AES256:RSA+AES256:EECDH+ECDSA+3DES:EECDH+aRSA+3DES:RSA+3DES:!MD5;
             ssl_protocols TLSv1.1 TLSv1.2 TLSv1.3;
             root /home/vps/public_html;
        # KatsuTun Premium
        # Important:
        # KatsuTun Premium

        }
EOF
sed -i '$ i# SERVER LISTEN XRAY' /etc/nginx/conf.d/xray.conf
sed -i '$ i# Important:' /etc/nginx/conf.d/xray.conf
sed -i '$ i# This is the proxy Xray For Vless Servers' /etc/nginx/conf.d/xray.conf
sed -i '$ i    location /vlessws {' /etc/nginx/conf.d/xray.conf
sed -i '$ iif ($http_upgrade != "Upgrade") {' /etc/nginx/conf.d/xray.conf
sed -i '$ irewrite /(.*) /vlessws break;' /etc/nginx/conf.d/xray.conf
sed -i '$ i      }' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_redirect off;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_pass http://127.0.0.1:10001;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_http_version 1.1;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header Upgrade $http_upgrade;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header Connection "upgrade";' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header Host $host;' /etc/nginx/conf.d/xray.conf
sed -i '$ i# Show real IP in Xray access.log' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header X-Real-IP $remote_addr;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;' /etc/nginx/conf.d/xray.conf
sed -i '$ i     }' /etc/nginx/conf.d/xray.conf
sed -i '$ i' /etc/nginx/conf.d/xray.conf
sed -i '$ i# Important:' /etc/nginx/conf.d/xray.conf
sed -i '$ i# This is the proxy Xray For Vmess Servers' /etc/nginx/conf.d/xray.conf
sed -i '$ i      location /vmess {' /etc/nginx/conf.d/xray.conf
sed -i '$ i                   if ($http_upgrade != "Upgrade") {' /etc/nginx/conf.d/xray.conf
sed -i '$ i                   rewrite /(.*) /vmess break;' /etc/nginx/conf.d/xray.conf
sed -i '$ i     }' /etc/nginx/conf.d/xray.conf
sed -i '$ i                   proxy_redirect off;' /etc/nginx/conf.d/xray.conf
sed -i '$ i                   proxy_pass http://127.0.0.1:10002;' /etc/nginx/conf.d/xray.conf
sed -i '$ i                   proxy_http_version 1.1;' /etc/nginx/conf.d/xray.conf
sed -i '$ i                   proxy_set_header Upgrade $http_upgrade;' /etc/nginx/conf.d/xray.conf
sed -i '$ i                   proxy_set_header Connection "upgrade";' /etc/nginx/conf.d/xray.conf
sed -i '$ i                   proxy_set_header Host $host;' /etc/nginx/conf.d/xray.conf
sed -i '$ i                   # Show real IP in Xray access.log' /etc/nginx/conf.d/xray.conf
sed -i '$ i                   proxy_set_header X-Real-IP $remote_addr;' /etc/nginx/conf.d/xray.conf
sed -i '$ i                   proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;' /etc/nginx/conf.d/xray.conf
sed -i '$ i     }' /etc/nginx/conf.d/xray.conf
sed -i '$ i' /etc/nginx/conf.d/xray.conf
sed -i '$ i# Important:' /etc/nginx/conf.d/xray.conf
sed -i '$ i# This is the proxy Xray For Trojan Servers' /etc/nginx/conf.d/xray.conf
sed -i '$ ilocation /trojan {' /etc/nginx/conf.d/xray.conf
sed -i '$ iif ($http_upgrade != "Upgrade") {' /etc/nginx/conf.d/xray.conf
sed -i '$ irewrite /(.*) /trojan break;' /etc/nginx/conf.d/xray.conf
sed -i '$ i     }' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_redirect off;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_pass http://127.0.0.1:10003;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_http_version 1.1;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header Upgrade $http_upgrade;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header Connection "upgrade";' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header Host $host;' /etc/nginx/conf.d/xray.conf
sed -i '$ i# Show real IP in Xray access.log' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header X-Real-IP $remote_addr;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;' /etc/nginx/conf.d/xray.conf
sed -i '$ i     }' /etc/nginx/conf.d/xray.conf
sed -i '$ i' /etc/nginx/conf.d/xray.conf
sed -i '$ i                   # Important:' /etc/nginx/conf.d/xray.conf
sed -i '$ i                   # This is the proxy Xray For SS Servers' /etc/nginx/conf.d/xray.conf
sed -i '$ i                   location /ss-ws {' /etc/nginx/conf.d/xray.conf
sed -i '$ i                   if ($http_upgrade != "Upgrade") {' /etc/nginx/conf.d/xray.conf
sed -i '$ i                   rewrite /(.*) /ss-ws break;' /etc/nginx/conf.d/xray.conf
sed -i '$ i     }' /etc/nginx/conf.d/xray.conf
sed -i '$ i                   proxy_redirect off;' /etc/nginx/conf.d/xray.conf
sed -i '$ i                   proxy_pass http://127.0.0.1:10004;' /etc/nginx/conf.d/xray.conf
sed -i '$ i                   proxy_http_version 1.1;' /etc/nginx/conf.d/xray.conf
sed -i '$ i                   proxy_set_header Upgrade $http_upgrade;' /etc/nginx/conf.d/xray.conf
sed -i '$ i                   proxy_set_header Connection "upgrade";' /etc/nginx/conf.d/xray.conf
sed -i '$ i                   proxy_set_header Host $host;' /etc/nginx/conf.d/xray.conf
sed -i '$ i                   # Show real IP in Xray access.log' /etc/nginx/conf.d/xray.conf
sed -i '$ i                   proxy_set_header X-Real-IP $remote_addr;' /etc/nginx/conf.d/xray.conf
sed -i '$ i                   proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;' /etc/nginx/conf.d/xray.conf
sed -i '$ i     }' /etc/nginx/conf.d/xray.conf
sed -i '$ i' /etc/nginx/conf.d/xray.conf
sed -i '$ i     # Setting Server gRPC' /etc/nginx/conf.d/xray.conf
sed -i '$ i     # Important:' /etc/nginx/conf.d/xray.conf
sed -i '$ i     # This is the proxy Xray For GRPC VL Servers' /etc/nginx/conf.d/xray.conf
sed -i '$ i      location ^~ /vless-grpc' /etc/nginx/conf.d/xray.conf
sed -i '$ i     {' /etc/nginx/conf.d/xray.conf
sed -i '$ i                          proxy_redirect off;' /etc/nginx/conf.d/xray.conf
sed -i '$ i                          grpc_set_header X-Real-IP \$remote_addr;' /etc/nginx/conf.d/xray.conf
sed -i '$ i                          grpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;' /etc/nginx/conf.d/xray.conf
sed -i '$ i                          grpc_set_header Host \$http_host;' /etc/nginx/conf.d/xray.conf
sed -i '$ i                          grpc_pass grpc://127.0.0.1:10005;' /etc/nginx/conf.d/xray.conf
sed -i '$ i     }' /etc/nginx/conf.d/xray.conf
sed -i '$ i' /etc/nginx/conf.d/xray.conf
sed -i '$ i     # Important:' /etc/nginx/conf.d/xray.conf
sed -i '$ i     # This is the proxy Xray For GRPC VM Servers' /etc/nginx/conf.d/xray.conf
sed -i '$ i      location ^~ /vmess-grpc' /etc/nginx/conf.d/xray.conf
sed -i '$ i     {' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_redirect off;' /etc/nginx/conf.d/xray.conf
sed -i '$ igrpc_set_header X-Real-IP \$remote_addr;' /etc/nginx/conf.d/xray.conf
sed -i '$ igrpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;' /etc/nginx/conf.d/xray.conf
sed -i '$ igrpc_set_header Host \$http_host;' /etc/nginx/conf.d/xray.conf
sed -i '$ igrpc_pass grpc://127.0.0.1:10006;' /etc/nginx/conf.d/xray.conf
sed -i '$ i     }' /etc/nginx/conf.d/xray.conf
sed -i '$ i' /etc/nginx/conf.d/xray.conf
sed -i '$ i     # Important:' /etc/nginx/conf.d/xray.conf
sed -i '$ i     # This is the proxy Xray For GRPC TR Servers' /etc/nginx/conf.d/xray.conf
sed -i '$ i      location ^~ /trojan-grpc' /etc/nginx/conf.d/xray.conf
sed -i '$ i     {' /etc/nginx/conf.d/xray.conf
sed -i '$ i                          proxy_redirect off;' /etc/nginx/conf.d/xray.conf
sed -i '$ i                          grpc_set_header X-Real-IP \$remote_addr;' /etc/nginx/conf.d/xray.conf
sed -i '$ i                          grpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;' /etc/nginx/conf.d/xray.conf
sed -i '$ i                          grpc_set_header Host \$http_host;' /etc/nginx/conf.d/xray.conf
sed -i '$ i                          grpc_pass grpc://127.0.0.1:10007;' /etc/nginx/conf.d/xray.conf
sed -i '$ i     }' /etc/nginx/conf.d/xray.conf
sed -i '$ i' /etc/nginx/conf.d/xray.conf
sed -i '$ i     # Important:' /etc/nginx/conf.d/xray.conf
sed -i '$ i     # This is the proxy Xray For GRPC SS Servers' /etc/nginx/conf.d/xray.conf
sed -i '$ i      location ^~ /ss-grpc' /etc/nginx/conf.d/xray.conf
sed -i '$ i     {' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_redirect off;' /etc/nginx/conf.d/xray.conf
sed -i '$ igrpc_set_header X-Real-IP \$remote_addr;' /etc/nginx/conf.d/xray.conf
sed -i '$ igrpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;' /etc/nginx/conf.d/xray.conf
sed -i '$ igrpc_set_header Host \$http_host;' /etc/nginx/conf.d/xray.conf
sed -i '$ igrpc_pass grpc://127.0.0.1:10008;' /etc/nginx/conf.d/xray.conf
sed -i '$ i' /etc/nginx/conf.d/xray.conf
sed -i '$ i      }' /etc/nginx/conf.d/xray.conf
sed -i '$ i      # Important:' /etc/nginx/conf.d/xray.conf
sed -i '$ i      # This is the proxy Xray For SSH Servers' /etc/nginx/conf.d/xray.conf
sed -i '$ i      location / {' /etc/nginx/conf.d/xray.conf
sed -i '$ i                   proxy_redirect off;' /etc/nginx/conf.d/xray.conf
sed -i '$ i                   proxy_pass http://127.0.0.1:700;' /etc/nginx/conf.d/xray.conf
sed -i '$ i                   proxy_http_version 1.1;' /etc/nginx/conf.d/xray.conf
sed -i '$ i                   proxy_set_header Upgrade $http_upgrade;' /etc/nginx/conf.d/xray.conf
sed -i '$ i                   proxy_set_header Connection "upgrade";' /etc/nginx/conf.d/xray.conf
sed -i '$ i                   proxy_set_header Host $host;' /etc/nginx/conf.d/xray.conf
sed -i '$ i                   # Show real IP in Xray access.log' /etc/nginx/conf.d/xray.conf
sed -i '$ i                   proxy_set_header X-Real-IP $remote_addr;' /etc/nginx/conf.d/xray.conf
sed -i '$ i                   proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;' /etc/nginx/conf.d/xray.conf
sed -i '$ i     }' /etc/nginx/conf.d/xray.conf



sleep 1
echo -e "[ ${green}INFO$NC ] Installing bbr.."
wget -q -O /usr/bin/bbr "$RAW/data/bbr.sh"
chmod +x /usr/bin/bbr
bbr >/dev/null 2>&1
rm /usr/bin/bbr >/dev/null 2>&1
echo -e "${yell}[SERVICE]${NC} Restart All service"
systemctl daemon-reload
sleep 1

# --- Test config SEBELUM service dibuat/di-enable ---------------------------
# Tanpa ini, config yang salah hanya terlihat sebagai "service gagal start".
if [ ! -x /usr/local/bin/xray ]; then
    echo -e "[ ${red}ERROR${NC} ] /usr/local/bin/xray tidak ada: xray.service TIDAK dibuat/di-enable."
    exit 1
fi
if xray_test_out="$(/usr/local/bin/xray run -test -config /etc/xray/config.json 2>&1)"; then
    echo -e "[ ${green}ok${NC} ] Config /etc/xray/config.json valid"
else
    echo -e "[ ${red}ERROR${NC} ] Config /etc/xray/config.json TIDAK valid. xray.service tidak di-enable."
    echo -e "[ ${red}ERROR${NC} ] Output 'xray run -test -config /etc/xray/config.json':"
    printf '%s\n' "$xray_test_out"
    exit 1
fi

echo -e "[ ${green}ok${NC} ] Enable & restart xray "
systemctl enable xray
if systemctl restart xray; then
    sleep 2
    echo -e "[ ${green}ok${NC} ] systemctl is-active xray: $(systemctl is-active xray)"
else
    echo -e "[ ${red}ERROR${NC} ] xray.service gagal start. 20 baris terakhir journal:"
    journalctl -u xray -n 20 --no-pager 2>/dev/null
fi
systemctl restart nginx
systemctl enable runn
systemctl restart runn

sleep 1
wget -q -O /usr/bin/auto-set "$RAW/data/auto-set.sh" && chmod +x /usr/bin/auto-set 
wget -q -O /usr/bin/crtxray "$RAW/data/crt.sh" && chmod +x /usr/bin/crtxray 
sleep 1
yellow() { echo -e "\\033[33;1m${*}\\033[0m"; }
yellow "xray/Vmess"
yellow "xray/Vless"


mv /root/domain /etc/xray/ 
if [ -f /root/scdomain ];then
rm /root/scdomain > /dev/null 2>&1
fi
clear
rm -f ins-xray.sh  
