#!/bin/bash
# Checks the account-creation safeguards in the interactive SSH menu.
set -eu
cd "$(dirname "$0")/.."

menu=data/menu-ssh.sh
fails=0
ok() { echo "  ok   $1"; }
fail() { echo "  FAIL $1"; fails=$((fails + 1)); }

grep -Fq 'read -r -p "   Password : " Pass' "$menu" \
    && ok "password input is visible so the admin can copy it to the customer" || fail "password prompt changed"
grep -Fq "printf '%s:%s\\n' \"\$Login\" \"\$Pass\" | chpasswd -c SHA512" "$menu" \
    && ok "password is applied with chpasswd" || fail "password is not applied with chpasswd"
grep -Eq 'echo -e "\$Pass\\n\$Pass\\n"\|passwd' "$menu" \
    && fail "legacy passwd pipe still present" || ok "no legacy passwd pipe"
grep -Fq 'userdel "$Login"' "$menu" \
    && ok "account is rolled back when password cannot be set" || fail "no rollback on password failure"
grep -Fq 'date -d "$hari days"' "$menu" \
    && ok "trial account uses its own expiry" || fail "trial account uses undefined expiry"
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
