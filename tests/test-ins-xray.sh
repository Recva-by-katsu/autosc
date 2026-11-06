#!/bin/bash
# Checks the Xray core install path: pemanggilan installer resmi, fallback zip,
# verifikasi binary, dan setup permission/user. Regresi yang dijaga:
#   bash -c "$(curl ...)" @ install -u www-data --version X
#   -> "@: unknown option -- -" lalu xray tidak terpasang dan xray.service
#      dibuat dengan status=203/EXEC.
set -eu
cd "$(dirname "$0")/.."

xray=data/ins-xray.sh
sshvpn=data/ssh-vpn.sh
fails=0
ok() { echo "  ok   $1"; }
fail() { echo "  FAIL $1"; fails=$((fails + 1)); }

check() { # check <file> <fixed-string> <label>
    grep -Fq "$2" "$1" && ok "$3" || fail "$3"
}
check_not() { # check_not <file> <fixed-string> <label>
    grep -Fq "$2" "$1" && fail "$3" || ok "$3"
}
# Sama seperti check_not, tapi mengabaikan baris komentar (dokumentasi boleh
# menyebut perintah lama yang rusak).
check_not_code() { # check_not_code <file> <fixed-string> <label>
    grep -v '^[[:space:]]*#' "$1" | grep -Fq "$2" && fail "$3" || ok "$3"
}

echo "== ins-xray.sh: pemanggilan installer Xray"
check_not_code "$xray" 'bash -c "$(curl' "installer tidak lagi dipanggil lewat bash -c ... @"
check_not_code "$xray" 'install -u www-data' "opsi -u (tidak ada di install-release.sh) tidak dipakai"
check "$xray" 'bash /tmp/install-release.sh install --version "$VERSION"' \
    "installer resmi dipanggil dengan argumen yang valid"
check "$xray" 'bash -n /tmp/install-release.sh' "installer divalidasi sebelum dijalankan"

echo "== ins-xray.sh: fallback zip rilis"
check "$xray" 'Xray-core/releases/download/v${VERSION}/Xray-linux-64.zip' "fallback memakai zip rilis resmi"
check "$xray" 'curl -fL --retry 3' "unduhan fallback memakai curl -fL --retry 3"
check "$xray" 'install -m 755 "$xray_tmp/xray" /usr/local/bin/xray' "binary di-install 755"
check "$xray" '"/usr/local/share/xray/$dat"' "geoip.dat/geosite.dat disalin ke /usr/local/share/xray"

echo "== ins-xray.sh: satu sumber kebenaran versi"
version_echo=$(grep -c 'Xray core version: \$VERSION' "$xray" || true)
[ "$version_echo" -eq 1 ] && ok "log versi memakai \$VERSION" || fail "log versi tidak konsisten"
check_not "$xray" 'latest_version' "variabel versi ganda (latest_version) dihapus"
check "$xray" 'VERSION="${VERSION:-}"' "versi bisa dipin dari environment"

echo "== ins-xray.sh: verifikasi sebelum membuat service"
check "$xray" '[ ! -x /usr/local/bin/xray ]' "binary dicek sebelum lanjut"
check "$xray" '/usr/local/bin/xray -version' "binary diuji dengan -version"
check "$xray" '/usr/local/bin/xray run -test -config /etc/xray/config.json' \
    "config diuji dengan run -test"
test_line=$(grep -n 'run -test -config' "$xray" | head -n1 | cut -d: -f1)
enable_line=$(grep -n '^systemctl enable xray' "$xray" | head -n1 | cut -d: -f1)
if [ -n "$test_line" ] && [ -n "$enable_line" ] && [ "$test_line" -lt "$enable_line" ]; then
    ok "config test dijalankan sebelum systemctl enable xray"
else
    fail "config test harus sebelum systemctl enable xray"
fi

echo "== ins-xray.sh: permission untuk www-data"
check "$xray" 'chown -R www-data:www-data /var/log/xray' "/var/log/xray milik www-data"
check "$xray" 'chmod 640 /etc/xray/config.json' "config.json bisa dibaca www-data"
check "$xray" 'chmod 644 /etc/xray/xray.crt' "xray.crt bisa dibaca www-data"
check "$xray" 'chmod 640 /etc/xray/xray.key' "xray.key 640 (tidak world-readable)"
check "$xray" 'User=www-data' "service tetap berjalan sebagai www-data"

echo "== bug lain di log"
check_not "$xray" 'systemctl enable chronyd' "tidak lagi memakai alias chronyd.service"
check "$xray" 'systemctl enable --now chrony' "chrony di-enable dengan unit yang benar"
check "$sshvpn" 'organization="KatsuTun Premium"' "teks banner di-quote (bukan perintah)"
check "$sshvpn" 'systemctl enable stunnel4' "stunnel4 di-enable agar hidup setelah reboot"
dropbear_sections=$(grep -c '^\[dropbear\]' "$sshvpn" || true)
[ "$dropbear_sections" -le 1 ] && ok "section stunnel unik" || fail "section [dropbear] duplikat di stunnel.conf"

echo
if [ "$fails" -eq 0 ]; then
    echo "all checks passed"
else
    echo "$fails check(s) failed"
    exit 1
fi
