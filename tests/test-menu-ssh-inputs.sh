#!/bin/bash
# Checks the account-creation safeguards in the interactive SSH menu.
set -eu
cd "$(dirname "$0")/.."

menu=data/menu-ssh.sh
fails=0
ok() { echo "  ok   $1"; }
fail() { echo "  FAIL $1"; fails=$((fails + 1)); }

grep -Fq 'read -r -s -p "   Password : " Pass' "$menu" \
    && ok "password input is hidden" || fail "password input is visible"
grep -Fq '[[ "$masaaktif" =~ ^[1-9][0-9]*$ ]]' "$menu" \
    && ok "expiry input must be a positive number" || fail "expiry input is not validated"
grep -Fq 'if ! useradd -e "$(date -d "$masaaktif days" +"%Y-%m-%d")" -s /bin/false -M "$Login"; then' "$menu" \
    && ok "user creation failure is handled" || fail "user creation failure is not handled"

useradd_line=$(grep -n 'if ! useradd' "$menu" | cut -d: -f1)
tracking_line=$(grep -n '>> /etc/xray/ssh.txt' "$menu" | cut -d: -f1)
if [ -n "$useradd_line" ] && [ -n "$tracking_line" ] && [ "$tracking_line" -gt "$useradd_line" ]; then
    ok "tracking metadata is written after user creation"
else
    fail "tracking metadata can be written before user creation"
fi

[ "$fails" -eq 0 ] && echo "all checks passed" || echo "$fails check(s) failed"
exit "$fails"
