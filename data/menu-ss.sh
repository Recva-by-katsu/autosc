#!/bin/bash
UI_LIB=/usr/local/lib/katsutun/ui.sh
[ -r "$UI_LIB" ] || { echo "KatsuTun UI library is missing. Run: katsu-update apply --force"; exit 1; }
# shellcheck source=data/katsu-ui.sh
. "$UI_LIB"
ui_init
red="$UI_BAD"; green="$UI_GOOD"; yell="$UI_WARN"; tyblue="$UI_ACCENT"
# Legacy palette names used by the screens below now map onto the shared theme.
NC="$UI_RESET"; RED="$UI_BAD"; GREEN="$UI_GOOD"; YELLOW="$UI_WARN"
COLOR1="$UI_ACCENT"; COLBG1="$UI_BAR"; WH="$UI_TEXT"
###########- Yudhy network -##########

function addssws(){
clear
domain=$(cat /etc/xray/domain)

ui_title "CREATE SSWS USER"
ui_card_start
tls="$(cat ~/log-install.txt | grep -w "Websocket Shadowsocks" | cut -d: -f2|sed 's/ //g')"
until [[ $user =~ ^[a-zA-Z0-9_]+$ && ${CLIENT_EXISTS} == '0' ]]; do
read -rp "   Input Username : " -e user
if [ -z $user ]; then
ui_line "[Error] Username cannot be empty "
ui_card_end
echo ""
ui_pause
menu
fi
CLIENT_EXISTS=$(grep -w $user /etc/xray/config.json | wc -l)

if [[ ${CLIENT_EXISTS} == '1' ]]; then
clear
ui_title "CREATE SSWS USER"
ui_card_start
ui_line "Please choose another name."
ui_card_end
echo ""
ui_pause
menu-ss
		fi
	done

cipher="aes-128-gcm"
uuid=$(cat /proc/sys/kernel/random/uuid)
read -p "   Expired (days): " masaaktif
exp=`date -d "$masaaktif days" +"%Y-%m-%d"`
sed -i '/#ssws$/a\## '"$user $exp"'\
},{"password": "'""$uuid""'","method": "'""$cipher""'","email": "'""$user""'"' /etc/xray/config.json
sed -i '/#ssgrpc$/a\## '"$user $exp"'\
},{"password": "'""$uuid""'","method": "'""$cipher""'","email": "'""$user""'"' /etc/xray/config.json
echo $cipher:$uuid > /tmp/log
shadowsocks_base64=$(cat /tmp/log)
echo -n "${shadowsocks_base64}" | base64 > /tmp/log1
shadowsocks_base64e=$(cat /tmp/log1)
shadowsockslink="ss://${shadowsocks_base64e}@$domain:$tls?plugin=xray-plugin;mux=0;path=/ss-ws;host=$domain;tls#${user}"
shadowsockslink1="ss://${shadowsocks_base64e}@$domain:$tls?plugin=xray-plugin;mux=0;serviceName=ss-grpc;host=$domain;tls#${user}"
systemctl restart xray
rm -rf /tmp/log
rm -rf /tmp/log1
cat > /home/vps/public_html/ss-ws/ss-$user.txt <<-END
# sodosok ws
{
 "dns": {
    "servers": [
      "8.8.8.8",
      "8.8.4.4"
    ]
  },
 "inbounds": [
   {
      "port": 10808,
      "protocol": "socks",
      "settings": {
        "auth": "noauth",
        "udp": true,
        "userLevel": 8
      },
      "sniffing": {
        "destOverride": [
          "http",
          "tls"
        ],
        "enabled": true
      },
      "tag": "socks"
    },
    {
      "port": 10809,
      "protocol": "http",
      "settings": {
        "userLevel": 8
      },
      "tag": "http"
    }
  ],
  "log": {
    "loglevel": "none"
  },
  "outbounds": [
    {
      "mux": {
        "enabled": true
      },
      "protocol": "shadowsocks",
      "settings": {
        "servers": [
          {
            "address": "$domain",
            "level": 8,
            "method": "$cipher",
            "password": "$uuid",
            "port": 443
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": {
          "allowInsecure": true,
          "serverName": "isi_bug_disini"
        },
        "wsSettings": {
          "headers": {
            "Host": "$domain"
          },
          "path": "/ss-ws"
        }
      },
      "tag": "proxy"
    },
    {
      "protocol": "freedom",
      "settings": {},
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "settings": {
        "response": {
          "type": "http"
        }
      },
      "tag": "block"
    }
  ],
  "policy": {
    "levels": {
      "8": {
        "connIdle": 300,
        "downlinkOnly": 1,
        "handshake": 4,
        "uplinkOnly": 1
      }
    },
    "system": {
      "statsOutboundUplink": true,
      "statsOutboundDownlink": true
    }
  },
  "routing": {
    "domainStrategy": "Asls",
"rules": []
  },
  "stats": {}
 }

 # SODOSOK grpc


{
    "dns": {
    "servers": [
      "8.8.8.8",
      "8.8.4.4"
    ]
  },
 "inbounds": [
   {
      "port": 10808,
      "protocol": "socks",
      "settings": {
        "auth": "noauth",
        "udp": true,
        "userLevel": 8
      },
      "sniffing": {
        "destOverride": [
          "http",
          "tls"
        ],
        "enabled": true
      },
      "tag": "socks"
    },
    {
      "port": 10809,
      "protocol": "http",
      "settings": {
        "userLevel": 8
      },
      "tag": "http"
    }
  ],
  "log": {
    "loglevel": "none"
  },
  "outbounds": [
    {
      "mux": {
        "enabled": true
      },
      "protocol": "shadowsocks",
      "settings": {
        "servers": [
          {
            "address": "$domain",
            "level": 8,
            "method": "$cipher",
            "password": "$uuid",
            "port": 443
          }
        ]
      },
      "streamSettings": {
        "grpcSettings": {
          "multiMode": true,
          "serviceName": "ss-grpc"
        },
        "network": "grpc",
        "security": "tls",
        "tlsSettings": {
          "allowInsecure": true,
          "serverName": "isi_bug_disini"
        }
      },
      "tag": "proxy"
    },
    {
      "protocol": "freedom",
      "settings": {},
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "settings": {
        "response": {
          "type": "http"
        }
      },
      "tag": "block"
    }
  ],
  "policy": {
    "levels": {
      "8": {
        "connIdle": 300,
        "downlinkOnly": 1,
        "handshake": 4,
        "uplinkOnly": 1
      }
    },
    "system": {
      "statsOutboundUplink": true,
      "statsOutboundDownlink": true
    }
  },
  "routing": {
    "domainStrategy": "Asls",
"rules": []
  },
  "stats": {}
}
END
systemctl restart xray > /dev/null 2>&1
service cron restart > /dev/null 2>&1
clear
ui_title "CREATE SSWS USER"
ui_card_start
ui_line "${WH}Remarks     ${COLOR1}: ${WH}${user}"
ui_line "${WH}Expired On  ${COLOR1}: ${WH}$exp"
ui_line "${WH}Domain      ${COLOR1}: ${WH}${domain}"
ui_line "${WH}Port TLS    ${COLOR1}: ${WH}${tls}"
ui_line "${WH}Port  GRPC  ${COLOR1}: ${WH}${tls}"
ui_line "${WH}Password    ${COLOR1}: ${WH}${uuid}"
ui_line "${WH}Cipers      ${COLOR1}: ${WH}aes-128-gcm"
ui_line "${WH}Network     ${COLOR1}: ${WH}ws/grpc"
ui_line "${WH}Path        ${COLOR1}: ${WH}/ss-ws"
ui_line "${WH}ServiceName ${COLOR1}: ${WH}ss-grpc"
ui_card_end
ui_copy "Link WebSocket TLS" "$shadowsockslink"
ui_copy "Link gRPC" "$shadowsockslink1"
ui_copy "Link JSON" "http://${domain}:81/ss-ws/ss-$user.txt"
echo ""
ui_pause
menu-ss
}

function renewssws(){
clear
ui_title "RENEW SSWS USER"
ui_card_start
NUMBER_OF_CLIENTS=$(grep -c -E "^## " "/etc/xray/config.json")
if [[ ${NUMBER_OF_CLIENTS} == '0' ]]; then
ui_line "• You have no existing clients!"
ui_card_end
echo ""
ui_pause
menu-ss
fi
clear
ui_title "RENEW SSWS USER"
ui_card_start
grep -E "^## " "/etc/xray/config.json" | cut -d ' ' -f 2-3 | column -t | sort | uniq | nl
ui_blank
ui_line "${COLOR1}• ${WH}[${COLOR1}NOTE${WH}] Press any key to back on menu"
ui_card_end
ui_divider
read -rp "   Input Username : " user
if [ -z $user ]; then
menu-ss
else
read -p "   Expired (days): " masaaktif
if [ -z $masaaktif ]; then
masaaktif="1"
fi
exp=$(grep -E "^## $user" "/etc/xray/config.json" | cut -d ' ' -f 3 | sort | uniq)
now=$(date +%Y-%m-%d)
d1=$(date -d "$exp" +%s)
d2=$(date -d "$now" +%s)
exp2=$(( (d1 - d2) / 86400 ))
exp3=$(($exp2 + $masaaktif))
exp4=`date -d "$exp3 days" +"%Y-%m-%d"`
sed -i "/## $user/c\## $user $exp4" /etc/xray/config.json
systemctl restart xray > /dev/null 2>&1
clear
ui_title "RENEW SSWS USER"
ui_card_start
ui_line "${WH}[${COLOR1}INFO${WH}]${NC}  ${WH}$user Account Renewed Successfully"
ui_blank
ui_line "${WH}Client Name ${COLOR1}: ${WH}$user"
ui_line "${WH}Days Added  ${COLOR1}: ${WH}$masaaktif Days"
ui_line "${WH}Expired On  ${COLOR1}: ${WH}$exp4"
ui_card_end
echo ""
ui_pause
menu-ss
fi
}

function delssws(){
    clear
NUMBER_OF_CLIENTS=$(grep -c -E "^## " "/etc/xray/config.json")
if [[ ${NUMBER_OF_CLIENTS} == '0' ]]; then
ui_title "DELETE TROJAN USER"
ui_card_start
ui_line "${COLOR1}• ${WH}You Dont have any existing clients!${NC}"
ui_card_end
echo ""
ui_pause
menu-ss
fi
clear
ui_title "DELETE TROJAN USER"
ui_card_start
grep -E "^## " "/etc/xray/config.json" | cut -d ' ' -f 2-3 | column -t | sort | uniq | nl
ui_blank
ui_line "${COLOR1}• ${WH}[${COLOR1}NOTE${WH}]${NC} ${WH}Press any key to back on menu${NC}"
ui_card_end
ui_divider
read -rp "   Input Username : " user
if [ -z $user ]; then
menu-ss
else
exp=$(grep -wE "^## $user" "/etc/xray/config.json" | cut -d ' ' -f 3 | sort | uniq)
sed -i "/^## $user $exp/,/^},{/d" /etc/xray/config.json
systemctl restart xray > /dev/null 2>&1
rm /home/vps/public_html/ss-ws/ss-$user.txt
clear
ui_title "DELETE TROJAN USER"
ui_card_start
ui_line "${COLOR1}• ${WH}Accound Delete Successfully"
ui_blank
ui_line "${COLOR1}• ${WH}Client Name ${COLOR1}: ${WH}$user${NC}"
ui_line "${COLOR1}• ${WH}Expired On  ${COLOR1}: ${WH}$exp${NC}"
ui_card_end
echo ""
ui_pause
menu-ss
fi
}

function cekssws(){
clear
echo -n > /tmp/other.txt
data=( `cat /etc/xray/config.json | grep '^##' | cut -d ' ' -f 2 | sort | uniq`);
ui_title "SSWS USER ONLINE"
ui_card_start

for akun in "${data[@]}"
do
if [[ -z "$akun" ]]; then
akun="tidakada"
fi

echo -n > /tmp/ipssws.txt
data2=( `cat /var/log/xray/access.log | tail -n 500 | cut -d " " -f 3 | sed 's/tcp://g' | cut -d ":" -f 1 | sort | uniq`);
for ip in "${data2[@]}"
do

jum=$(cat /var/log/xray/access.log | grep -w "$akun" | tail -n 500 | cut -d " " -f 3 | sed 's/tcp://g' | cut -d ":" -f 1 | grep -w "$ip" | sort | uniq)
if [[ "$jum" = "$ip" ]]; then
echo "$jum" >> /tmp/ipssws.txt
else
echo "$ip" >> /tmp/other.txt
fi
jum2=$(cat /tmp/ipssws.txt)
sed -i "/$jum2/d" /tmp/other.txt > /dev/null 2>&1
done

jum=$(cat /tmp/ipssws.txt)
if [[ -z "$jum" ]]; then
echo > /dev/null
else
jum2=$(cat /tmp/ipssws.txt | nl)
ui_line "user : $akun";
echo -e "$COLOR1${NC}$jum2";
fi
rm -rf /tmp/ipssws.txt
done

rm -rf /tmp/other.txt
ui_card_end
echo ""
ui_pause
menu-ss
}

ui_screen "SHADOWSOCKS" "Xray accounts"
ui_card_start
ui_options "01:Add account" "03:Delete account" "02:Renew account" "04:Online users"
ui_card_end
ui_back_hint
ui_prompt
read -r opt
case $opt in
01 | 1) clear ; addssws ;;
02 | 2) clear ; renewssws ;;
03 | 3) clear ; delssws ;;
04 | 4) clear ; cekssws ;;
00 | 0 | x | X) clear ; menu ;;
*) clear ; menu-ss ;;
esac
