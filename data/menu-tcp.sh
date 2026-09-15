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
###########- END COLOR CODE -##########


# COLOR
red='\e[1;31m'
green='\e[0;32m'
NC='\e[0m'

MYIP=$(curl -s https://icanhazip.com)

clear
tcp_status() {
  if [[ $(grep -c "^#PH56" /etc/sysctl.conf) -eq 1 ]]; then
    ui_line " TCP 1 Current status : ${green}Installed${NC}"
  else
    ui_line " TCP 1 Current status : ${red}Not Installed${NC}"
  fi
}

# status tweak
tcp_2_status() {
  if [[ $(grep -c "^##VpsPack" /etc/sysctl.conf) -eq 1 ]]; then
    ui_line " TCP 2 Current status : ${green}Installed${NC}"
  else
    ui_line " TCP 2 Current status : ${red}Not Installed${NC}"
  fi
}

# status bbr
bbr_status() {
  local param=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
  if [[ x"${param}" == x"bbr" ]]; then
    ui_line " BBR status : ${green}Installed${NC}"
  else
    ui_line " BBR status : ${red}Not Installed${NC}"
  fi
}

delete_bbr() {
  clear
ui_screen "TCP TWEAK" "congestion control"
ui_card_start
  read -p "   [INFO] Do you want to remove BBR? [y/n]: " -e answer0
  if [[ "$answer0" = 'y' ]]; then
    grep -v "^#BBR
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr" /etc/sysctl.conf >/tmp/syscl && mv /tmp/syscl /etc/sysctl.conf
sysctl -p /etc/sysctl.conf >/dev/null
echo "cubic" >/proc/sys/net/ipv4/tcp_congestion_control
ui_line "[INFO] BBR settings successfully removed."
ui_card_end
    echo ""
ui_pause
    menu-tcp
  else
    echo ""
    menu-tcp
  fi
}

sysctl_config() {
  sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
  sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
  echo "" >>/etc/sysctl.conf
  echo "#BBR" >>/etc/sysctl.conf
  echo "net.core.default_qdisc = fq" >>/etc/sysctl.conf
  echo "net.ipv4.tcp_congestion_control = bbr" >>/etc/sysctl.conf
  sysctl -p >/dev/null 2>&1
}

check_bbr_status() {
  local param=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
  if [[ x"${param}" == x"bbr" ]]; then
    return 0
  else
    return 1
  fi
}

version_ge() {
  test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" == "$1"
}

check_kernel_version() {
  local kernel_version=$(uname -r | cut -d- -f1)
  if version_ge ${kernel_version} 4.9; then
    return 0
  else
    return 1
  fi
}

install_bbr2() {
  check_bbr_status
  if [ $? -eq 0 ]; then
ui_line "[INFO]  TCP BBR already  installed."
ui_card_end
    echo ""
ui_pause
    menu-tcp
  fi
  check_kernel_version
  if [ $? -eq 0 ]; then
ui_line "[INFO]  Your kernel version is greater than 4.9, directly setting TCP BBR..."
    sysctl_config
ui_line "[INFO]  Setting TCP BBR completed..."
ui_card_end
    echo ""
ui_pause
    menu-tcp
  fi

  if [[ x"${release}" == x"centos" ]]; then
ui_line "[ERROR] Centos not support"
ui_card_end
    echo ""
ui_pause
    menu-tcp
  fi
}

install_bbr() {
  clear
ui_screen "TCP TWEAK" "congestion control"
ui_card_start
  read -p "   [INFO] Proceed with installation? [y/n]: " -e answer
  if [[ "$answer" = 'y' ]]; then
    install_bbr2
  else
ui_card_end
    echo ""
ui_pause
    menu-tcp
  fi
}

delete_Tweaker() {
  clear
ui_screen "TCP TWEAK" "congestion control"
ui_card_start
  read -p "   [INFO] Remove TCP Tweaker settings? [y/n]: " -e answer0
  if [[ "$answer0" = 'y' ]]; then
    grep -v "^#PH56
net.ipv4.tcp_window_scaling = 1
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 16384 16777216
net.ipv4.tcp_low_latency = 1
net.ipv4.tcp_slow_start_after_idle = 0" /etc/sysctl.conf >/tmp/syscl && mv /tmp/syscl /etc/sysctl.conf
    sysctl -p /etc/sysctl.conf >/dev/null
ui_line "[INFO] TCP Tweaker settings successfully removed."
ui_card_end
    echo ""
ui_pause
    menu-tcp
  else
    echo ""
    menu-tcp
  fi
}

install_Tweaker() {
  clear
ui_screen "TCP TWEAK" "congestion control"
ui_card_start
  read -p "   [INFO] Proceed with installation? [y/n]: " -e answer
  if [[ "$answer" = 'y' ]]; then
    echo " " >>/etc/sysctl.conf
    echo "#PH56" >>/etc/sysctl.conf
    echo "net.ipv4.tcp_window_scaling = 1
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 16384 16777216
net.ipv4.tcp_low_latency = 1
net.ipv4.tcp_slow_start_after_idle = 0" >>/etc/sysctl.conf
    sysctl -p /etc/sysctl.conf >/dev/null
ui_line "[INFO] TCP Tweaker settings added successfully."
ui_card_end
    echo ""
ui_pause
    menu-tcp
  else
ui_line "Installation was canceled by the user!"
  fi
}

delete_Tweaker_2() {
  clear
ui_screen "TCP TWEAK" "congestion control"
ui_card_start
  read -p "   [INFO] Remove TCP Tweaker settings? [y/n]: " -e answer0
  if [[ "$answer0" = 'y' ]]; then
    grep -v "^##VpsPack
net.ipv4.tcp_fin_timeout = 2
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_keepalive_time = 600
net.ipv4.ip_local_port_range = 2000 65000
net.ipv4.tcp_max_syn_backlog = 16384
net.ipv4.tcp_max_tw_buckets = 36000
net.ipv4.route.gc_timeout = 100
net.ipv4.tcp_syn_retries = 1
net.ipv4.tcp_synack_retries = 1
net.ipv4.tcp_max_orphans = 16384
net.core.somaxconn = 16384
net.core.netdev_max_backlog = 16384" /etc/sysctl.conf >/tmp/syscl && mv /tmp/syscl /etc/sysctl.conf
    sysctl -p /etc/sysctl.conf >/dev/null
ui_line "TCP Tweaker settings successfully removed."
ui_card_end
    echo ""
ui_pause
    menu-tcp
  else
    echo ""
    menu-tcp
  fi
}

install_Tweaker_2() {
  clear
ui_screen "TCP TWEAK" "congestion control"
ui_card_start
  read -p "   [INFO] Proceed with installation? [y/n]: " -e answer
  if [[ "$answer" = 'y' ]]; then
    echo " " >>/etc/sysctl.conf
    echo "##VpsPack" >>/etc/sysctl.conf
    echo "net.ipv4.tcp_fin_timeout = 2
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_keepalive_time = 600
net.ipv4.ip_local_port_range = 2000 65000
net.ipv4.tcp_max_syn_backlog = 16384
net.ipv4.tcp_max_tw_buckets = 36000
net.ipv4.route.gc_timeout = 100
net.ipv4.tcp_syn_retries = 1
net.ipv4.tcp_synack_retries = 1
net.ipv4.tcp_max_orphans = 16384
net.core.somaxconn = 16384
net.core.netdev_max_backlog = 16384" >>/etc/sysctl.conf
    sysctl -p /etc/sysctl.conf >/dev/null
ui_line "[INFO] TCP Tweaker settings added successfully."
ui_card_end
    echo ""
ui_pause
    menu-tcp
  else

ui_line "Installation was canceled by the user!"

  fi
}

# menu tweaker
ui_screen "TCP TWEAK" "congestion control"
ui_card_start
tcp_status
tcp_2_status
bbr_status
ui_blank
ui_options "01:Install BBR" "04:Delete BBR" "02:Install TCP 1" "05:Delete TCP 1" "03:Install TCP 2" "06:Delete TCP 2" "07:Reboot"
ui_card_end
ui_back_hint
ui_prompt
read -r opt
echo -e "$DF"
case $opt in
01 | 1) clear ; install_bbr ;;
02 | 2) clear ; install_Tweaker ;;
03 | 3) clear ; install_Tweaker_2 ;;
04 | 4) clear ; delete_bbr ;;
05 | 5) clear ; delete_Tweaker ;;
06 | 6) clear ; delete_Tweaker_2 ;;
07 | 7) clear ; reboot ;;
00 | 0) clear ; menu-set ;;
*) clear ; menu-tcp ;;
esac
