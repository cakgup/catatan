# Panduan Praktis Stress Test dengan Apache JMeter untuk Pemula

> **Klasifikasi:** Internal/Restricted  
> Panduan ini menggunakan nama generik. Jangan memasukkan nama aplikasi asli, IP internal, hostname, token, akun, endpoint, atau data transaksi ke versi yang dibagikan di luar tim berwenang.

---

# 1. Apa Tujuan Stress Test?

Stress test digunakan untuk mengetahui kemampuan aplikasi ketika diakses oleh banyak pengguna pada waktu yang hampir bersamaan.

Hal yang ingin diketahui:

1. berapa banyak pengguna yang masih dapat dilayani dengan stabil;
2. apakah waktu respons masih wajar;
3. apakah muncul error ketika beban bertambah;
4. endpoint mana yang paling lambat atau paling sering gagal;
5. apakah aplikasi, database, atau server mulai mengalami antrean atau timeout;
6. apakah hasil optimalisasi membuat performa menjadi lebih baik.

Stress test bukan hanya melihat aplikasi “masih hidup” atau “masih bisa dibuka”. Fungsi utama harus tetap berjalan dengan waktu respons yang wajar dan error rate yang dapat diterima.

---

# 2. Apa Itu Concurrent User?

**Concurrent user atau CCU** adalah jumlah pengguna yang masih aktif pada waktu yang sama.

Pengguna dianggap aktif ketika sedang:

- mengirim request;
- menunggu respons;
- membaca atau mengisi data;
- menjalani think time;
- melanjutkan proses berikutnya.

CCU berbeda dengan jumlah request.

Contoh:

```text
100 concurrent users
Setiap user menjalankan 8 endpoint
Total request dapat mencapai 800 request
```

Jumlah concurrent user tetap **100**, bukan 800.

---

# 3. Cara Menentukan Target CCU

## 3.1 Dari data penggunaan nyata

Metode terbaik adalah menggunakan data production, misalnya:

- jumlah session aktif pada jam sibuk;
- jumlah login baru per menit;
- rata-rata durasi session;
- pola penggunaan pada tanggal atau periode puncak.

Contoh:

```text
Peak active session : 500 user
Cadangan kapasitas  : 30%
Target pengujian    : 500 × 130% = 650 CCU
```

## 3.2 Dari proyeksi bisnis

Gunakan rumus:

```text
Session per jam = Pengguna aktif per hari ÷ Jam operasional
```

Kemudian:

```text
CCU = Session masuk per menit × Rata-rata durasi session
```

Contoh:

```text
Pengguna aktif per hari : 6.000
Jam operasional         : 8 jam
Durasi session          : 60 menit
```

Perhitungan:

```text
Session per jam   = 6.000 ÷ 8 = 750
Session per menit = 750 ÷ 60 = 12,5
CCU                = 12,5 × 60 = 750
```

Jika durasi session hanya 15 menit:

```text
CCU = 12,5 × 15 = 187,5
```

Target dapat dibulatkan menjadi **188 CCU**.

## 3.3 Jika baru tersedia jumlah pengguna terdaftar

Gunakan asumsi yang disepakati bersama pemilik proses bisnis.

Contoh:

```text
Total pengguna terdaftar       : 10.000
Aktif pada hari sibuk          : 40%
Aktif bersamaan                : 20% dari pengguna harian
```

Perhitungan:

```text
Pengguna harian = 10.000 × 40% = 4.000
Target CCU      = 4.000 × 20%  = 800
```

Asumsi ini harus dikonfirmasi karena bukan data aktual.

---

# 4. Skenario Development yang Digunakan

Karena environment development belum menggambarkan infrastruktur production, pengujian awal dilakukan secara bertahap:

| Skenario | Total User | Approver | Operator Transaksi | Operator Data | Ramp-up |
|---|---:|---:|---:|---:|---:|
| S1 | 40 | 32 | 6 | 2 | 8 detik |
| S2 | 60 | 48 | 9 | 3 | 12 detik |
| S3 | 80 | 64 | 12 | 4 | 16 detik |
| S4 | 100 | 80 | 15 | 5 | 20 detik |

Model pengujian:

```text
Loop Count : 1
Scheduler  : nonaktif
Duration   : tidak digunakan
```

Setiap virtual user menjalankan satu alur aktivitas, kemudian berhenti.

Tujuan pengujian development:

- memastikan test plan benar;
- menemukan endpoint dengan error rate tinggi;
- menemukan bottleneck awal;
- menentukan titik awal penurunan performa;
- menjadi bahan optimalisasi sebelum pengujian production-like.

---

# 5. Mengenal File yang Digunakan

Bagian ini penting agar tidak bingung antara file bawaan JMeter dan file buatan penguji.

## 5.1 `jmeter.bat`

Lokasinya:

```text
C:\Tools\apache-jmeter-<VERSI>\bin\jmeter.bat
```

File ini **bawaan resmi Apache JMeter**. Fungsinya menjalankan JMeter pada Windows.

## 5.2 `test-plan.jmx`

File ini **dibuat oleh penguji** menggunakan aplikasi JMeter GUI.

Isinya antara lain:

- daftar endpoint;
- urutan aktivitas pengguna;
- HTTP Header Manager;
- token;
- file upload;
- jumlah thread;
- ramp-up;
- timeout;
- assertion.

## 5.3 `scenario-40.properties`

File ini berisi parameter yang dapat diubah tanpa mengedit JMX.

Contohnya:

- jumlah user;
- ramp-up;
- token;
- target server;
- data ID;
- lokasi payload;
- timeout.

## 5.4 `run-loadtest-windows.bat`

File ini **bukan bawaan JMeter**.

File ini dibuat oleh penguji agar eksekusi menjadi lebih mudah. Dengan runner ini, pengguna cukup menjalankan:

```bat
run-loadtest-windows.bat 40
```

Runner akan:

1. memilih profil 40 user;
2. membaca properties;
3. menjalankan JMeter;
4. menyimpan JTL dan log;
5. membuat HTML Dashboard;
6. membuka laporan di browser.

---

# 6. Persiapan yang Dibutuhkan

Siapkan:

- komputer Windows 64-bit;
- Java;
- Apache JMeter;
- file `test-plan.jmx`;
- properties template;
- payload uji;
- token akun uji;
- akses jaringan ke target;
- izin dari pemilik aplikasi.

Spesifikasi awal load generator:

```text
CPU   : minimal 4 core
RAM   : minimal 8 GB, disarankan 16 GB
Disk  : minimal 5 GB kosong
OS    : Windows 10/11 atau Windows Server 64-bit
```

---

# 7. Instal Java

Unduh Java 17 LTS dari:

```text
https://adoptium.net/temurin/releases/
```

Pilih:

```text
Operating System : Windows
Architecture     : x64
Package          : JDK
Installer        : MSI
```

Setelah instalasi, buka Command Prompt baru.

Jalankan:

```bat
java -version
```

Jika versi Java tampil, instalasi berhasil.

Contoh:

```text
openjdk version "17.x.x"
```

---

# 8. Instal Apache JMeter

Unduh dari:

```text
https://jmeter.apache.org/download_jmeter.cgi
```

Pilih **binary ZIP**, bukan source code.

Ekstrak ke:

```text
C:\Tools\apache-jmeter-5.6.3
```

Buka Command Prompt, lalu atur:

```bat
set "JMETER_HOME=C:\Tools\apache-jmeter-5.6.3"
```

Periksa:

```bat
dir "%JMETER_HOME%\bin\jmeter.bat"
```

Cek versi:

```bat
"%JMETER_HOME%\bin\jmeter.bat" -v
```

Pesan `WARN` dapat diabaikan selama versi JMeter tampil dan Command Prompt kembali normal.

---

# 9. Membuat Folder Kerja

Buat folder:

```text
C:\LoadTest-Internal
```

Cara mudah:

1. buka File Explorer;
2. masuk ke drive `C:`;
3. klik kanan;
4. pilih **New > Folder**;
5. beri nama `LoadTest-Internal`.

Struktur akhirnya:

```text
C:\LoadTest-Internal
├── test-plan.jmx
├── run-loadtest-windows.bat
├── scenario-40.properties.template
├── scenario-60.properties.template
├── scenario-80.properties.template
├── scenario-100.properties.template
└── payloads
    ├── payload-1.bin
    └── payload-2.bin
```

> Salin file JMX aktual ke folder ini dan ubah namanya menjadi `test-plan.jmx`.  
> Jika tidak ingin mengganti nama JMX, ubah variabel `TEST_PLAN` di file BAT.

---

# 10. Cara Membuat File `run-loadtest-windows.bat`

## 10.1 Aktifkan tampilan ekstensi file

Agar file tidak tersimpan sebagai `.bat.txt`:

1. buka File Explorer;
2. pilih menu **View**;
3. aktifkan **File name extensions**.

## 10.2 Buat file BAT

1. buka Notepad;
2. salin script di bawah;
3. pilih **File > Save As**;
4. lokasi: `C:\LoadTest-Internal`;
5. nama: `run-loadtest-windows.bat`;
6. `Save as type`: **All Files**;
7. `Encoding`: **UTF-8** atau **ANSI**;
8. klik **Save**.

Isi file:

```bat
@echo off
setlocal EnableExtensions
cd /d "%~dp0"

rem ==========================================================
rem 1. PROFIL YANG DIPILIH DARI COMMAND PROMPT
rem ==========================================================
if "%~1"=="" goto :usage
set "PROFILE=%~1"

rem ==========================================================
rem 2. DAFTAR PROFIL YANG DIIJINKAN
rem ==========================================================
if not "%PROFILE%"=="40" if not "%PROFILE%"=="60" if not "%PROFILE%"=="80" if not "%PROFILE%"=="100" (
    echo [ERROR] Profil %PROFILE% tidak tersedia.
    echo Pilihan: 40, 60, 80, 100
    exit /b 1
)

rem ==========================================================
rem 3. PERIKSA JMETER_HOME
rem ==========================================================
if not defined JMETER_HOME (
    echo [ERROR] JMETER_HOME belum diatur.
    echo Contoh:
    echo set "JMETER_HOME=C:\Tools\apache-jmeter-5.6.3"
    exit /b 1
)

rem ==========================================================
rem 4. NAMA FILE YANG DIGUNAKAN
rem ==========================================================
set "JMETER=%JMETER_HOME%\bin\jmeter.bat"
set "TEST_PLAN=test-plan.jmx"
set "TEMPLATE=scenario-%PROFILE%.properties.template"
set "PROPERTIES=scenario-%PROFILE%.properties"

rem ==========================================================
rem 5. VALIDASI FILE
rem ==========================================================
if not exist "%JMETER%" (
    echo [ERROR] jmeter.bat tidak ditemukan:
    echo %JMETER%
    exit /b 1
)

if not exist "%TEST_PLAN%" (
    echo [ERROR] File JMX tidak ditemukan:
    echo %TEST_PLAN%
    exit /b 1
)

if not exist "%TEMPLATE%" (
    echo [ERROR] Template properties tidak ditemukan:
    echo %TEMPLATE%
    exit /b 1
)

rem ==========================================================
rem 6. BUAT PROPERTIES AKTUAL DARI TEMPLATE
rem ==========================================================
if not exist "%PROPERTIES%" (
    copy /Y "%TEMPLATE%" "%PROPERTIES%" >nul
    echo [INFO] File %PROPERTIES% telah dibuat.
    echo [ACTION] Isi token dan data uji, lalu jalankan kembali.
    start "" notepad "%PROPERTIES%"
    exit /b 0
)

rem ==========================================================
rem 7. PERIKSA APAKAH TOKEN MASIH PLACEHOLDER
rem ==========================================================
findstr /C:"<TOKEN_MASKED>" "%PROPERTIES%" >nul
if not errorlevel 1 (
    echo [ERROR] Token pada %PROPERTIES% masih berupa placeholder.
    start "" notepad "%PROPERTIES%"
    exit /b 1
)

rem ==========================================================
rem 8. MEMBUAT TIMESTAMP DAN FOLDER HASIL
rem ==========================================================
for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "TIMESTAMP=%%I"

set "RESULT_DIR=results\scenario-%PROFILE%-%TIMESTAMP%"
set "REPORT_DIR=reports\scenario-%PROFILE%-%TIMESTAMP%"
set "JTL=%RESULT_DIR%\scenario-%PROFILE%.jtl"
set "LOG=%RESULT_DIR%\scenario-%PROFILE%-jmeter.log"

mkdir "%RESULT_DIR%" >nul 2>&1

rem ==========================================================
rem 9. MENAMPILKAN INFORMASI UJI
rem ==========================================================
echo =============================================
echo LOAD TEST APLIKASI INTERNAL
echo Profil     : %PROFILE% virtual users
echo Test plan  : %TEST_PLAN%
echo Properties : %PROPERTIES%
echo Result     : %RESULT_DIR%
echo Report     : %REPORT_DIR%
echo =============================================

rem ==========================================================
rem 10. MENJALANKAN JMETER
rem ==========================================================
call "%JMETER%" -n ^
  -t "%TEST_PLAN%" ^
  -q "%PROPERTIES%" ^
  -l "%JTL%" ^
  -j "%LOG%" ^
  -e -o "%REPORT_DIR%"

rem ==========================================================
rem 11. MEMERIKSA HASIL EKSEKUSI
rem ==========================================================
if errorlevel 1 (
    echo [ERROR] Pengujian gagal.
    echo Periksa log:
    echo %LOG%
    exit /b 1
)

echo [OK] Pengujian selesai.
echo [OK] Report:
echo %REPORT_DIR%\index.html

start "" "%REPORT_DIR%\index.html"
exit /b 0

:usage
echo Cara menggunakan:
echo run-loadtest-windows.bat 40
echo run-loadtest-windows.bat 60
echo run-loadtest-windows.bat 80
echo run-loadtest-windows.bat 100
exit /b 1
```

---

# 11. Bagian BAT yang Paling Sering Diubah

## 11.1 Mengubah nama file JMX

Cari:

```bat
set "TEST_PLAN=test-plan.jmx"
```

Misalnya file Anda bernama:

```text
uji-aplikasi.jmx
```

Ubah menjadi:

```bat
set "TEST_PLAN=uji-aplikasi.jmx"
```

## 11.2 Menambah profil baru

Misalnya ingin menambah profil 50 user.

### Langkah 1 — ubah validasi profil

Semula:

```bat
if not "%PROFILE%"=="40" if not "%PROFILE%"=="60" if not "%PROFILE%"=="80" if not "%PROFILE%"=="100" (
```

Menjadi:

```bat
if not "%PROFILE%"=="40" if not "%PROFILE%"=="50" if not "%PROFILE%"=="60" if not "%PROFILE%"=="80" if not "%PROFILE%"=="100" (
```

Ubah juga:

```bat
echo Pilihan: 40, 50, 60, 80, 100
```

### Langkah 2 — buat template baru

Salin:

```text
scenario-40.properties.template
```

Menjadi:

```text
scenario-50.properties.template
```

### Langkah 3 — ubah jumlah user

Contoh:

```properties
APPROVER_THREADS=40
OPERATOR_TRANSAKSI_THREADS=8
OPERATOR_DATA_THREADS=2
RAMP_UP=10
```

Total:

```text
40 + 8 + 2 = 50 user
```

### Langkah 4 — tambahkan pada bagian bantuan

Tambahkan:

```bat
echo run-loadtest-windows.bat 50
```

## 11.3 Mengubah folder hasil

Cari:

```bat
set "RESULT_DIR=results\scenario-%PROFILE%-%TIMESTAMP%"
set "REPORT_DIR=reports\scenario-%PROFILE%-%TIMESTAMP%"
```

Misalnya ingin menyimpan ke drive D:

```bat
set "RESULT_DIR=D:\Hasil-Uji\results\scenario-%PROFILE%-%TIMESTAMP%"
set "REPORT_DIR=D:\Hasil-Uji\reports\scenario-%PROFILE%-%TIMESTAMP%"
```

## 11.4 Menonaktifkan pembukaan browser otomatis

Cari:

```bat
start "" "%REPORT_DIR%\index.html"
```

Tambahkan `rem` di depannya:

```bat
rem start "" "%REPORT_DIR%\index.html"
```

---

# 12. Cara Membuat File Properties Template

Buka Notepad dan salin:

```properties
# ============================================================
# TARGET
# ============================================================
IP=<TARGET_IP_MASKED>
PROTOCOL=http
PORT=0

# ============================================================
# TOKEN AKUN UJI
# ============================================================
TOKEN_APPROVER=Bearer <TOKEN_MASKED>
TOKEN_OPERATOR_TRANSAKSI=Bearer <TOKEN_MASKED>
TOKEN_OPERATOR_DATA=Bearer <TOKEN_MASKED>

# ============================================================
# DATA UJI
# ============================================================
DATA_ID=<DATA_ID_MASKED>
DATA_DATE=2026-07-30

# ============================================================
# PAYLOAD
# ============================================================
PAYLOAD_FILE_1=payloads/payload-1.bin
PAYLOAD_FILE_2=payloads/payload-2.bin

# ============================================================
# JUMLAH USER
# ============================================================
APPROVER_THREADS=32
OPERATOR_TRANSAKSI_THREADS=6
OPERATOR_DATA_THREADS=2

# ============================================================
# RAMP-UP
# ============================================================
RAMP_UP=8

# ============================================================
# THINK TIME
# ============================================================
APPROVER_THINK_TIME_MS=3000
OPERATOR_TRANSAKSI_THINK_TIME_MS=3000
OPERATOR_DATA_THINK_TIME_MS=3000

# ============================================================
# TIMEOUT
# ============================================================
CONNECT_TIMEOUT_MS=10000
RESPONSE_TIMEOUT_MS=60000
```

Simpan sebagai:

```text
scenario-40.properties.template
```

Gunakan:

```text
Save as type : All Files
```

Buat template lain dengan komposisi:

| Profil | Approver | Operator Transaksi | Operator Data | Ramp-up |
|---:|---:|---:|---:|---:|
| 40 | 32 | 6 | 2 | 8 |
| 60 | 48 | 9 | 3 | 12 |
| 80 | 64 | 12 | 4 | 16 |
| 100 | 80 | 15 | 5 | 20 |

---

# 13. Menjalankan Pengujian Pertama Kali

## 13.1 Buka Command Prompt

Tekan:

```text
Windows + R
```

Ketik:

```text
cmd
```

Tekan Enter.

## 13.2 Atur JMeter

```bat
set "JMETER_HOME=C:\Tools\apache-jmeter-5.6.3"
```

## 13.3 Masuk ke folder kerja

```bat
cd /d C:\LoadTest-Internal
```

## 13.4 Jalankan profil 40

```bat
run-loadtest-windows.bat 40
```

Pada eksekusi pertama:

1. runner membuat `scenario-40.properties`;
2. Notepad terbuka;
3. isi token dan data uji;
4. simpan;
5. tutup Notepad;
6. jalankan kembali:

```bat
run-loadtest-windows.bat 40
```

---

# 14. Lakukan Smoke Test Terlebih Dahulu

Sebelum 40 user, disarankan membuat profil kecil 1–3 user.

Contoh `scenario-smoke.properties`:

```properties
APPROVER_THREADS=1
OPERATOR_TRANSAKSI_THREADS=1
OPERATOR_DATA_THREADS=1
RAMP_UP=1
```

Tujuan smoke test:

- memastikan token valid;
- memastikan endpoint dapat diakses;
- memastikan file upload ditemukan;
- memastikan assertion benar;
- memastikan test selesai;
- memastikan laporan HTML terbentuk.

Jangan langsung menjalankan 100 user sebelum smoke test berhasil.

---

# 15. Menjalankan Skenario Bertahap

Setelah smoke test berhasil:

```bat
run-loadtest-windows.bat 40
```

Tunggu sampai:

```text
... end of run
```

Pastikan server kembali normal, lalu lanjutkan:

```bat
run-loadtest-windows.bat 60
```

Kemudian:

```bat
run-loadtest-windows.bat 80
```

Terakhir:

```bat
run-loadtest-windows.bat 100
```

Jangan menjalankan semua skenario bersamaan.

---

# 16. Menjalankan Tanpa Runner BAT

Runner hanya alat bantu.

JMeter dapat dijalankan langsung:

```bat
set "JMETER_HOME=C:\Tools\apache-jmeter-5.6.3"

cd /d C:\LoadTest-Internal
```

Jalankan:

```bat
"%JMETER_HOME%\bin\jmeter.bat" -n ^
  -t "test-plan.jmx" ^
  -q "scenario-40.properties" ^
  -l "hasil-40.jtl" ^
  -j "jmeter-40.log" ^
  -e -o "report-40"
```

Arti parameter:

| Parameter | Arti |
|---|---|
| `-n` | mode non-GUI |
| `-t` | file JMX |
| `-q` | file properties |
| `-l` | hasil JTL |
| `-j` | log JMeter |
| `-e` | membuat HTML Dashboard |
| `-o` | folder laporan HTML |

Folder `report-40` harus belum ada atau masih kosong.

---

# 17. Membaca Output Command Prompt

Contoh:

```text
summary + 243 in 00:00:30 = 8.2/s Avg: 1435 Min: 24 Max: 6251 Err: 0 (0.00%)
Active: 83 Started: 100 Finished: 17
```

Arti:

| Bagian | Arti |
|---|---|
| `243` | request selesai pada interval tersebut |
| `8.2/s` | throughput per detik |
| `Avg` | rata-rata response time |
| `Min` | response time tercepat |
| `Max` | response time terlama |
| `Err` | jumlah dan persentase error |
| `Active` | thread masih aktif |
| `Started` | thread sudah dimulai |
| `Finished` | thread sudah selesai |

`summary +` adalah hasil interval terakhir.  
`summary =` adalah hasil kumulatif.

---

# 18. Lokasi Hasil

Runner membuat:

```text
results\scenario-40-<TIMESTAMP>
reports\scenario-40-<TIMESTAMP>
```

File penting:

```text
results\...\scenario-40.jtl
results\...\scenario-40-jmeter.log
reports\...\index.html
```

Buka laporan:

```bat
start "" "reports\scenario-40-<TIMESTAMP>\index.html"
```

---

# 19. Apa yang Harus Dilihat?

Fokus pada:

- total sample;
- error rate;
- average response time;
- median;
- p90;
- p95;
- p99;
- maximum response time;
- throughput;
- endpoint dengan error tertinggi;
- endpoint dengan response time tertinggi;
- grafik Active Threads Over Time.

Jangan hanya melihat average response time. Request gagal yang dikembalikan cepat dapat membuat rata-rata terlihat lebih rendah.

---

# 20. Monitoring Server

Selama pengujian, minta tim teknis memantau:

```text
CPU
Memory
Disk I/O
Network
Application thread
Database connection pool
Query lambat
HTTP 4xx/5xx
Timeout
```

Catat waktu mulai dan selesai agar hasil JMeter dapat dicocokkan dengan log aplikasi dan database.

---

# 21. Masalah yang Sering Terjadi

## 21.1 File BAT terbuka di Notepad, bukan berjalan

Kemungkinan file tersimpan sebagai:

```text
run-loadtest-windows.bat.txt
```

Solusi:

1. aktifkan **File name extensions**;
2. hapus `.txt`;
3. pastikan nama berakhir dengan `.bat`.

## 21.2 `JMETER_HOME belum diatur`

Jalankan:

```bat
set "JMETER_HOME=C:\Tools\apache-jmeter-5.6.3"
```

## 21.3 `jmeter.bat tidak ditemukan`

Periksa:

```bat
dir "%JMETER_HOME%\bin\jmeter.bat"
```

## 21.4 File JMX tidak ditemukan

Periksa:

```bat
dir test-plan.jmx
```

Jika nama berbeda, ubah:

```bat
set "TEST_PLAN=test-plan.jmx"
```

di file BAT.

## 21.5 Token masih placeholder

Buka:

```bat
notepad scenario-40.properties
```

Ganti `<TOKEN_MASKED>` dengan token akun uji.

## 21.6 Payload tidak ditemukan

Periksa:

```bat
dir payloads
```

Pastikan nama file sesuai properties.

## 21.7 HTML Dashboard tidak terbentuk

Periksa log:

```bat
notepad results\<FOLDER_HASIL>\scenario-40-jmeter.log
```

Buat ulang:

```bat
"%JMETER_HOME%\bin\jmeter.bat" -g "results\<FOLDER_HASIL>\scenario-40.jtl" -o "reports\scenario-40-regenerate"
```

## 21.8 Folder report sudah ada

Hapus atau gunakan nama baru:

```bat
rmdir /S /Q report-40
```

Hati-hati memastikan folder yang dihapus benar.

## 21.9 Pengujian tidak selesai

Periksa:

- response timeout;
- endpoint menggantung;
- konektivitas;
- log JMeter;
- log aplikasi;
- apakah Loop Count masih `-1`.

Untuk model one-pass:

```text
Loop Count = 1
Scheduler  = nonaktif
```

---

# 22. Cara Menghentikan Pengujian

Penghentian normal:

```bat
"%JMETER_HOME%\bin\shutdown.cmd"
```

Penghentian segera:

```bat
"%JMETER_HOME%\bin\stoptest.cmd"
```

Gunakan penghentian segera hanya jika sistem mengalami gangguan serius.

---

# 23. Setelah Pengujian

Lakukan:

1. simpan JTL, log, dan HTML Dashboard;
2. bersihkan data transaksi uji;
3. hapus token dari properties;
4. mask IP, hostname, endpoint, akun, dan ID data;
5. cocokkan hasil dengan log aplikasi dan database;
6. catat endpoint dengan error rate tinggi;
7. lakukan retest setelah optimalisasi;
8. gunakan environment yang mendekati production untuk validasi kapasitas nyata.

Contoh masking:

```properties
TOKEN_APPROVER=Bearer <MASKED>
TOKEN_OPERATOR_TRANSAKSI=Bearer <MASKED>
TOKEN_OPERATOR_DATA=Bearer <MASKED>
```

---

# 24. Checklist Singkat

Sebelum test:

```text
[ ] Java sudah terinstal
[ ] JMeter dapat dijalankan
[ ] JMETER_HOME sudah diatur
[ ] test-plan.jmx tersedia
[ ] properties tersedia
[ ] token valid
[ ] payload tersedia
[ ] target dapat diakses
[ ] monitoring server aktif
[ ] izin pengujian sudah ada
```

Sesudah test:

```text
[ ] Pengujian selesai
[ ] JTL tersimpan
[ ] Log tersimpan
[ ] HTML Dashboard terbentuk
[ ] Data uji dibersihkan
[ ] Token dimasking
[ ] Endpoint bermasalah dicatat
```

---

# 25. Ringkasan Perintah

```bat
java -version

set "JMETER_HOME=C:\Tools\apache-jmeter-5.6.3"

"%JMETER_HOME%\bin\jmeter.bat" -v

cd /d C:\LoadTest-Internal

run-loadtest-windows.bat 40
run-loadtest-windows.bat 60
run-loadtest-windows.bat 80
run-loadtest-windows.bat 100
```

---

> **Ingat:**  
> `jmeter.bat` adalah file bawaan Apache JMeter.  
> `run-loadtest-windows.bat` adalah file yang dibuat oleh penguji untuk mempermudah eksekusi.
