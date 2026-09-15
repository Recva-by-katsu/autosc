# KatsuTun — Script Autoinstaller for SSHws and Xray
Mendukung Debian 10/11/12 dan Ubuntu 20.04/22.04/24.04. Gunakan Ubuntu 22.04
atau Debian 12 untuk instalasi baru.

NB: These codes are totally free, open source, and all belongs to ©Yudhynet. Me personally just completed some codes

## Dashboard terminal

Login interaktif menampilkan `katsu-dashboard`: header biru, informasi VPS,
status layanan, jumlah akun, metadata script, dan bandwidth, mengikuti contoh
GEMILANG KINASIH STORE. Ketik `menu` untuk membuka pengelolaan akun dan tools;
nomor menu 01–14 tetap sama. Login tidak lagi menunggu tombol atau memutar ASCII art.

Dashboard maksimal 60 kolom (minimum 32); terminal sempit menumpuk status dan
bandwidth agar tidak meluber. Gunakan font monospace UTF-8 dan latar `#111526`
di JuiceSSH untuk mendekati contoh. `KATSU_ASCII=1 katsu-dashboard` memakai garis
ASCII; `NO_COLOR=1 katsu-dashboard` menonaktifkan warna.

Opsional: isi `/etc/katsutun/dashboard.json` (tidak ditimpa updater):

```json
{
  "title": "GEMILANG KINASIH STORE",
  "username": "nama-pengelola",
  "interface": "eth0"
}
```

`username` default adalah user Linux saat ini. Field opsional `expires` memakai
format `YYYY-MM-DD` dan hanya metadata tampilan, **bukan enforcement lisensi**;
tanpa konfigurasi tampil `N/A [NOT CONFIGURED]`, bukan tanggal fiktif. Label
`LOCAL` menandai identitas lokal, bukan hasil pemeriksaan lisensi online.
`PROXY` memeriksa Xray, `NGINX` memeriksa nginx, `SSHWS` memeriksa ws-stunnel.
Jumlah akun Xray dihitung unik per username agar WS/gRPC tidak dihitung ganda;
SSH memakai daftar akun script, bukan seluruh user Linux.

Bandwidth `M` berarti MiB (RX + TX), memakai vnStat JSON v2 pada interface rute
default atau `interface` di konfigurasi. Data yang hilang, vnStat lama, atau
interface yang tidak dapat ditentukan ditampilkan `N/A`, bukan nol palsu.
Semua submenu memakai komponen yang sama (`data/katsu-ui.sh`): frame otomatis 36–60 kolom, opsi dua kolom pada layar lebar dan satu kolom pada layar sempit, `[00] Back` / `[x] Exit` di setiap layar. Tes: `python3 tests/test-dashboard.py`, `python3 tests/test-ui.py`, dan `python3 tests/test-menus.py` (merender semua menu terhadap VPS stub).

## Kompatibilitas Sistem

Installer memvalidasi sistem sebelum mengubah VPS dan memilih profil instalasi
berdasarkan RAM/CPU yang tersedia. Rilis yang didukung adalah Ubuntu 20.04,
22.04, 24.04 dan Debian 10, 11, 12. Dependency dan kesehatan layanan tetap
perlu diverifikasi pada setiap rilis baru sebelum dipromosikan ke pelanggan.

## Konfigurasi Repo (pindah repo / fork)

Identitas repo tidak lagi ditulis ulang di tiap script. Semuanya ada di satu
file, `data/repo.conf`, yang dipasang ke `/etc/katsutun/repo.conf` saat install:

```
GH_USER="${GH_USER:-Recva-by-katsu}"
GH_REPO="${GH_REPO:-autosc}"
GH_BRANCH="${GH_BRANCH:-main}"
BRAND="${BRAND:-KatsuTun}"
```

Dari situ diturunkan `$RAW`, `$REPO_URL`, dan `$ISSUES_URL` yang dipakai semua
script, menu, banner, dan installer. Jadi untuk memakai fork sendiri cukup ubah
satu tempat:

```bash
# saat install
GH_USER=namaku GH_REPO=forkku ./setup.sh

# setelah terpasang
katsu-update repo namaku/forkku    # atau: menu-update -> 10
katsu-update branch dev            # atau: menu-update -> 06
katsu-update apply --force
```

`/etc/katsutun/repo.conf` adalah data milik VPS dan sengaja tidak terdaftar di
`data/manifest.txt`, sehingga auto update tidak pernah mengembalikannya ke repo
asal. Instalasi lama yang masih menyimpan `REPO=`/`BRANCH=` di `update.conf`
dipindahkan otomatis saat `katsu-update` pertama kali jalan.

Tes offline untuk aturan ini: `bash tests/test-repo-conf.sh`.

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
[05] AUTO RESTART ON/OFF [10] SET REPO
```

CLI: `katsu-update check|apply|enable|disable|interval <menit>|branch <nama>|repo <user/repo>|rollback|status|log`.
Konfigurasi update ada di `/etc/katsutun/update.conf`, sumber repo di
`/etc/katsutun/repo.conf`, log di `/etc/katsutun/update.log`.

> Menambah file baru ke script? Daftarkan di `data/manifest.txt`
> (`<path repo> <path install> <mode> [service]`) supaya ikut terpasang otomatis.

## Dashboard Terminal

Perintah `menu` membuka dashboard KatsuTun yang menampilkan domain, penggunaan
memori, status layanan inti, dan pintasan ke seluruh panel. Tampilan menggunakan
accent warna yang dapat dipilih lewat **Appearance** (`menu` → `07`) dan tetap
memakai fungsi menu lama di balik setiap pilihan. Untuk terminal lama yang tidak
mendukung karakter kotak Unicode, jalankan `KATSU_ASCII=1 menu`.

## Installer
### Pilih salah satu dari kedua link di bawah
Link panjang
```
wget https://raw.githubusercontent.com/Recva-by-katsu/autosc/main/setup.sh && chmod +x setup.sh && ./setup.sh
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
wget https://raw.githubusercontent.com/Recva-by-katsu/autosc/main/data/RepoLocal.sh && bash RepoLocal.sh && rm RepoLocal.sh && apt update
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

## Backup terenkripsi

Backup mencakup konfigurasi dan database akun yang sensitif. Sebelum memakai
backup, jalankan `rclone config`, lalu buka `menu-backup` → **Backup Settings**
untuk mengatur remote, email penerima, dan password enkripsi. Arsip diunggah
dalam format `.zip.enc` menggunakan AES-256-CBC dengan PBKDF2; password itu
diperlukan kembali saat restore. Kredensial penyimpanan dan SMTP hanya disimpan
di `/etc/katsutun/backup.conf` (mode `600`), tidak pernah di repository.

