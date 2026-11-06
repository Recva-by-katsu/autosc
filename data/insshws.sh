#!/bin/bash
# Identitas repo hanya ada di /etc/katsutun/repo.conf (lihat data/repo.conf).
# katsu-update menulis ulang file itu bila hilang, jadi $RAW selalu terisi.
[ -r /etc/katsutun/repo.conf ] || katsu-update status >/dev/null 2>&1
# shellcheck source=data/repo.conf
. /etc/katsutun/repo.conf
cd
# Unduh berkas websocket dan unit systemd; gagal keras jika salah satu berkas
# tidak terbentuk dengan lengkap, agar service tidak mati dalam diam.
dl() { # dl <url> <dest> <label>
    if ! wget -q -O "$2" "$1" || [ ! -s "$2" ]; then
        echo -e "[ ${red}ERROR${NC} ] Gagal mengunduh $3 ($1)" >&2
        return 1
    fi
}

dl "$RAW/data/dropbear-ws.py" /usr/local/bin/ws-dropbear ws-dropbear || exit 1
dl "$RAW/data/ws-stunnel" /usr/local/bin/ws-stunnel ws-stunnel || exit 1
dl "$RAW/data/ws-ovpn.py" /usr/local/bin/ws-ovpn ws-ovpn || exit 1

chmod +x /usr/local/bin/ws-dropbear
chmod +x /usr/local/bin/ws-stunnel
chmod +x /usr/local/bin/ws-ovpn

dl "$RAW/data/service-wsdropbear" /etc/systemd/system/ws-dropbear.service service-wsdropbear || exit 1
dl "$RAW/data/ws-stunnel.service" /etc/systemd/system/ws-stunnel.service ws-stunnel.service || exit 1
dl "$RAW/data/ws-ovpn.service" /etc/systemd/system/ws-ovpn.service ws-ovpn.service || exit 1
chmod +x /etc/systemd/system/ws-dropbear.service
chmod +x /etc/systemd/system/ws-stunnel.service
chmod +x /etc/systemd/system/ws-ovpn.service

systemctl daemon-reload
systemctl enable ws-dropbear.service
systemctl start ws-dropbear.service
systemctl restart ws-dropbear.service
systemctl enable ws-stunnel.service
systemctl start ws-stunnel.service
systemctl restart ws-stunnel.service
systemctl enable ws-ovpn.service
systemctl start ws-ovpn.service
systemctl restart ws-ovpn.service
