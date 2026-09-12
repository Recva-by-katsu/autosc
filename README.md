# KatsuTun — Script Autoinstaller for SSHws and Xray
Mendukung Debian 10 dan Ubuntu 20, silakan yang pakai OS versi lain, rebuild ke versi OS yang didukung (rekomendasi Ubuntu 20)

NB: These codes are totally free, open source, and all belongs to ©Yudhynet. Me personally just completed some codes

## Versi & Auto Update

Installer selalu memasang **commit terbaru** dari branch `main` repo ini, jadi
VPS baru langsung mendapat versi paling baru tanpa perlu `update` manual.

Setelah instalasi, `katsu-update` mengecek GitHub setiap 5 menit (cron di
`/etc/cron.d/katsu-update`). Jika ada commit baru, semua file yang terdaftar di
`data/manifest.txt` dipasang ulang dari commit tersebut — hanya file yang
berubah yang ditulis, dan service terkait (ws-stunnel, ws-dropbear, ws-ovpn,
autosc-api) di-restart hanya bila file-nya berubah.

Kelola lewat `menu` → `14` atau perintah `menu-update`:

```
[01] CHECK UPDATE        [06] SET BRANCH
[02] UPDATE NOW          [07] UPDATE LOG
[03] AUTO UPDATE ON/OFF  [08] ROLLBACK
[04] SET INTERVAL        [09] GITHUB TOKEN
[05] AUTO RESTART ON/OFF
```

CLI: `katsu-update check|apply|enable|disable|interval <menit>|branch <nama>|rollback|status|log`.
Konfigurasi ada di `/etc/katsutun/update.conf`, log di `/etc/katsutun/update.log`.

> Menambah file baru ke script? Daftarkan di `data/manifest.txt`
> (`<path repo> <path install> <mode> [service]`) supaya ikut terpasang otomatis.

## Installer
### Pilih salah satu dari kedua link di bawah
Link panjang
```
wget https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/setup.sh && chmod +x setup.sh && ./setup.sh
```
Link pendek
```
wget s.id/lawsc; bash lawsc
```

Jika sudah menggunakan Debian 10 tetapi masih mendapati error saat install script, silakan copy paste kode di bawah dan install scriptnya lagi.
```
sudo su
```
```
apt update; apt install -y vnstat htop nload; apt upgrade -y; update-grub; reboot
```

### Catatan untuk squid error atau not running
Pastikan edit banner dan buat agar tidak terlalu panjang
```
nano /etc/issue.net
```
### For anyone whos using ISP RUMAHWEB Indonesia or FCCDCI server
If you encounter when installing the script is taking time so long, change the repository to local one (Data Utama Surabaya, Indonesia), copy and paste this code then run the Installer again
```
wget https://raw.githubusercontent.com/Revaa-Cerza/autosc/main/data/RepoLocal.sh && bash RepoLocal.sh && rm RepoLocal.sh && apt update
```

## REST API & Dokumentasi

Sejak v1.2.0 seluruh fitur panel juga tersedia lewat REST API. API dan situs
dokumentasinya dipasang otomatis saat instalasi, memakai domain yang sama
dengan yang Anda masukkan di awal install.

| | URL |
|---|---|
| Dokumentasi interaktif | `https://DOMAIN-ANDA/docs/` |
| Base URL API | `https://DOMAIN-ANDA/api` |
| Spesifikasi OpenAPI | `https://DOMAIN-ANDA/api/openapi.json` |
| Health check (tanpa key) | `https://DOMAIN-ANDA/api/health` |

API key pertama ditampilkan di akhir proses instalasi dan disimpan di
`/etc/autosc-api/first-key.txt`.

### Menu API

Kelola API key lewat `menu` → `13`, atau langsung dengan perintah `menu-api`:

```
[01] GENERATE API KEY     [05] RESTART API
[02] LIST API KEY         [06] TEST API
[03] REVOKE API KEY       [07] API INFO
[04] DELETE API KEY
```

Key disimpan sebagai hash SHA-256 di `/etc/autosc-api/keys.json`; nilai
mentahnya hanya ditampilkan satu kali saat dibuat.

### Endpoint

Autentikasi memakai header `X-API-Key: <key>` atau `Authorization: Bearer <key>`.

| Method | Path | Keterangan |
|---|---|---|
| `GET` | `/system/info` | Info VPS, jumlah akun, status service |
| `GET` | `/system/services` | Status seluruh service |
| `POST` | `/system/services/restart` | Restart service |
| `GET` | `/{protokol}` | Daftar akun |
| `POST` | `/{protokol}` | Buat akun |
| `DELETE` | `/{protokol}/{username}` | Hapus akun |
| `POST` | `/{protokol}/{username}/renew` | Perpanjang akun |
| `GET` | `/ssh/online` | User SSH yang sedang online |
| `GET` `POST` | `/keys` | Daftar / buat API key |
| `POST` | `/keys/{id}/revoke` | Cabut API key |
| `DELETE` | `/keys/{id}` | Hapus API key |

`{protokol}` = `ssh`, `vmess`, `vless`, `trojan`, atau `ss`.

Contoh membuat akun VMess 30 hari:

```bash
curl -X POST https://DOMAIN-ANDA/api/vmess \
  -H "X-API-Key: KEY_ANDA" \
  -H "Content-Type: application/json" \
  -d '{"username":"budi","expired":30}'
```

Response berisi link `vmess://` siap impor untuk WS TLS, WS non-TLS dan gRPC.

Akun yang dibuat lewat API memakai file dan format yang sama persis dengan menu
interaktif, sehingga keduanya bisa dipakai bergantian.

### Catatan keamanan

Service API hanya mendengarkan di `127.0.0.1:8081`; akses publik selalu melewati
nginx pada domain Anda sehingga terlindungi TLS. Cabut key yang bocor dengan
`menu-api` → `03`.

