#!/bin/bash
# Identitas repo hanya ada di /etc/katsutun/repo.conf (lihat data/repo.conf).
# katsu-update menulis ulang file itu bila hilang, jadi $RAW selalu terisi.
[ -r /etc/katsutun/repo.conf ] || katsu-update status >/dev/null 2>&1
# shellcheck source=data/repo.conf
. /etc/katsutun/repo.conf

wget -q -O /usr/bin/bwMonitor "$RAW/data/bwMonitor"  && chmod +x /usr/bin/bwMonitor

cat <<EOF > "/etc/cron.d/bwMonitor"
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
0 */6 * * * root bwMonitor
EOF

rm bwMonitor.sh
rm bwMonitor
