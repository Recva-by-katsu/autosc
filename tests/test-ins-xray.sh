#!/bin/bash
# Checks the Xray core install path: pemanggilan installer resmi, fallback zip,
# verifikasi binary, dan setup permission/user. Regresi yang dijaga:
#   bash -c "$(curl ...)" @ install -u www-data --version X
#   -> "@: unknown option -- -" lalu xray tidak terpasang dan xray.service
#      dibuat dengan status=203/EXEC.
# Juga dijaga agar skrip mengikuti format rilis Xray yang sekarang (v26.10.31),
# bukan lagi hanya 1.8.x.
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
check "$xray" 'bash /tmp/install-release.sh install --version "$XRAY_VERSION"' \
    "installer resmi dipanggil dengan argumen yang valid"
check "$xray" 'bash -n /tmp/install-release.sh' "installer divalidasi sebelum dijalankan"
check "$xray" '"$xray_installer_log" 2>&1' "output installer disimpan untuk diagnostik"

echo "== ins-xray.sh: versi mengikuti rilis Xray sekarang (v26.x)"
check "$xray" 'XRAY_VERSION_FALLBACK="26.10.31"' "pin fallback memakai format versi baru"
check "$xray" 'xray_version_re=' "format versi divalidasi dengan regex"
check "$xray" '(\.[0-9]+)?' "regex menerima format lama (1.8.7) maupun baru (26.10.31)"
check "$xray" 'github.com/${XRAY_PROJECT}/releases/latest' "versi terbaru dari redirect github.com"
check "$xray" 'api.github.com/repos/${XRAY_PROJECT}/releases/latest' "API GitHub dipakai sebagai cadangan"
check "$xray" 'XRAY_PROJECT="XTLS/Xray-core"' "repo sumber jadi satu variabel"
check_not_code "$xray" 'latest_version="' "variabel versi ganda (latest_version) dihapus"
check "$xray" 'Xray core version: $XRAY_VERSION' "log versi memakai satu sumber kebenaran"
check "$xray" 'XRAY_VERSION="$VERSION"' "versi dikunci setelah normalisasi"

echo "== ins-xray.sh: fallback zip rilis"
check "$xray" 'Xray-linux-${XRAY_ARCH}.zip' "nama zip mengikuti arsitektur mesin"
check "$xray" 'XRAY_ARCH="arm64-v8a"' "arsitektur arm64 dipetakan"
check "$xray" 'XRAY_ARCH="arm32-v7a"' "arsitektur armv7 dipetakan"
check "$xray" 'curl -fL --retry 3' "unduhan fallback memakai curl -fL --retry 3"
check "$xray" 'install -m 755 "$xray_tmp/xray" /usr/local/bin/xray' "binary di-install 755"
check "$xray" 'XRAY_DAT_PATH="/usr/local/share/xray"' "geodata ditaruh di /usr/local/share/xray"
check "$xray" '"$XRAY_DAT_PATH/$dat"' "geoip.dat/geosite.dat disalin ke folder geodata"
check "$xray" '/usr/local/etc/xray/$dat' "geodata dari path installer lama ikut dimigrasi"

echo "== ins-xray.sh: verifikasi sebelum membuat service"
check "$xray" '/usr/local/bin/xray version' "pakai perintah baru 'xray version'"
check "$xray" '/usr/local/bin/xray -version' "fallback ke '-version' gaya lama"
check "$xray" '/usr/local/bin/xray run -test -config /etc/xray/config.json' \
    "config diuji dengan run -test"
test_line=$(grep -n 'run -test -config' "$xray" | head -n1 | cut -d: -f1)
enable_line=$(grep -n '^systemctl enable xray' "$xray" | head -n1 | cut -d: -f1)
if [ -n "$test_line" ] && [ -n "$enable_line" ] && [ "$test_line" -lt "$enable_line" ]; then
    ok "config test dijalankan sebelum systemctl enable xray"
else
    fail "config test harus sebelum systemctl enable xray"
fi
check "$xray" 'Langkah yang gagal: ${xray_step}' "pesan error menyebut langkah yang gagal"
check "$xray" 'Service xray TIDAK dibuat/di-enable' "jelas bahwa service tidak dibuat saat gagal"

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


echo "== nginx: idle timeout hanya di blok SSH-WS (location /)"
# Blok location dibuat lewat rantai `sed -i '$ i ...'`; sisipan yang salah
# anchor pernah mendarat di blok vmess. Uji hasil akhirnya, bukan teks skrip.
ngtmp=$(mktemp -d)
printf 'server {\n    listen 443;\n}\n' >"$ngtmp/xray.conf"
grep -E "^sed -i '\\\$ i.*xray\.conf$" "$xray" | grep -vF "'\$ i'" >"$ngtmp/cmds.sh"
sed -i "s#/etc/nginx/conf.d/xray.conf#$ngtmp/xray.conf#g" "$ngtmp/cmds.sh"
bash "$ngtmp/cmds.sh" 2>/dev/null || true
if [ "$(grep -c 'proxy_read_timeout 3600s' "$ngtmp/xray.conf")" = 1 ]; then
    ok "proxy_read_timeout muncul tepat satu kali"
else
    fail "proxy_read_timeout harus tepat satu kali"
fi
if awk '/^location \/ \{/{flag=1} flag && /proxy_read_timeout 3600s/{found=1} flag && /^\}/{flag=0} END{exit !found}' "$ngtmp/xray.conf"; then
    ok "timeout ada di dalam blok location / (SSH-WS)"
else
    fail "timeout tidak berada di blok SSH-WS"
fi
awk '/^location \/vmess \{/{flag=1} flag && /proxy_read_timeout/{found=1} flag && /^\}/{flag=0} END{exit found}' "$ngtmp/xray.conf" \
    && ok "blok vmess tidak ikut diubah" || fail "blok vmess terkena sisipan"
grep -q 'proxy_buffering off' "$ngtmp/xray.conf" && ok "proxy_buffering off terpasang" \
    || fail "proxy_buffering off hilang"
rm -rf "$ngtmp"

echo
if [ "$fails" -eq 0 ]; then
    echo "all checks passed"
else
    echo "$fails check(s) failed"
    exit 1
fi
