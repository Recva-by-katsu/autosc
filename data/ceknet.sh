#!/bin/bash
# Simple DNS / network reachability check.
# Replaces the upstream ceknet.sh that is no longer published.
NC='\033[0m'
GREEN='\033[0;32m'
RED='\033[0;31m'

echo -e "${GREEN}Active resolver(s)${NC}"
if command -v resolvectl >/dev/null 2>&1; then
    resolvectl status 2>/dev/null | grep -E 'DNS Servers|Current DNS' | sed 's/^ *//'
fi
grep -E '^nameserver' /etc/resolv.conf 2>/dev/null
echo ""

echo -e "${GREEN}Resolution test${NC}"
for host in google.com cloudflare.com github.com; do
    ip=$(getent hosts "$host" 2>/dev/null | awk '{print $1}' | head -n1)
    if [ -n "$ip" ]; then
        echo -e "  $host -> ${GREEN}$ip${NC}"
    else
        echo -e "  $host -> ${RED}FAILED${NC}"
    fi
done
echo ""

echo -e "${GREEN}Connectivity test${NC}"
if curl -s --max-time 8 -o /dev/null -w '  HTTPS to google.com : %{http_code}\n' https://google.com; then
    :
else
    echo -e "  HTTPS to google.com : ${RED}FAILED${NC}"
fi
myip=$(curl -s --max-time 8 ifconfig.me)
[ -n "$myip" ] && echo "  Public IP           : $myip"
echo ""
