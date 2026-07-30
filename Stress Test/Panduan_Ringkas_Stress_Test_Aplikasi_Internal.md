# Panduan Ringkas Stress Test Aplikasi Internal dengan Apache JMeter

> **Klasifikasi:** Internal/Restricted  
> Nama aplikasi asli, IP, hostname, endpoint, token, akun, dan ID data internal tetap disamarkan. Istilah peran pengguna dibuat generik agar panduan tetap mudah dipahami.

---


## 1. Tujuan Stress Test

Stress test dilakukan untuk mengetahui bagaimana aplikasi merespons ketika digunakan oleh banyak pengguna dalam waktu yang bersamaan.

Tujuan utamanya adalah:

1. mengetahui jumlah pengguna simultan yang masih dapat dilayani dengan stabil;
2. mengukur waktu respons, throughput, dan error rate;
3. menemukan endpoint yang lambat atau sering gagal;
4. mengenali titik ketika sistem mulai mengalami antrean, timeout, atau kegagalan;
5. menyediakan dasar perbaikan aplikasi, database, dan infrastruktur;
6. memvalidasi kembali kapasitas setelah dilakukan optimalisasi.

Stress test tidak hanya melihat apakah aplikasi masih dapat dibuka. Pengujian juga harus melihat apakah fungsi utama tetap berjalan dalam waktu yang wajar dan tanpa tingkat kegagalan yang tinggi.

---

## 2. Pengertian Concurrent User

**Concurrent user atau CCU** adalah jumlah pengguna yang masih aktif pada waktu yang sama.

Seorang pengguna dianggap aktif ketika sedang:

- mengirim request;
- menunggu respons;
- membaca atau mengisi data;
- menjalani think time;
- melanjutkan aktivitas berikutnya.

CCU berbeda dengan jumlah request.

Contoh:

```text
100 concurrent users
Setiap user menjalankan 8 endpoint
Total request yang dihasilkan dapat mencapai 800 request
```

Jumlah concurrent user tetap **100**, bukan 800.

Jumlah request dipengaruhi oleh:

- jumlah endpoint dalam satu alur;
- jumlah loop;
- lama pengujian;
- think time;
- kecepatan respons aplikasi.

---

## 3. Cara Menentukan Target CCU

Penentuan target CCU sebaiknya menggunakan data penggunaan nyata. Urutan metode yang disarankan adalah sebagai berikut.

### 3.1 Menggunakan data monitoring production

Metode terbaik adalah menggunakan data aktual dari sistem yang sudah berjalan.

Data yang diperlukan:

- jumlah session aktif pada jam sibuk;
- jumlah login atau session baru per menit;
- rata-rata lama session;
- pola penggunaan harian;
- puncak penggunaan bulanan atau periode tertentu.

Gunakan nilai puncak aktual, kemudian tambahkan cadangan kapasitas.

Contoh:

```text
Peak active session aktual : 500 user
Cadangan kapasitas         : 30%
Target pengujian           : 500 × 130% = 650 CCU
```

### 3.2 Menggunakan proyeksi bisnis

Jika aplikasi belum production, target dapat dihitung dari proyeksi jumlah pengguna.

Rumus sederhana:

```text
Session per jam = Jumlah pengguna aktif per hari ÷ Jam operasional
```

Kemudian gunakan prinsip:

```text
CCU = Session masuk per menit × Rata-rata durasi session dalam menit
```

Rumus tersebut merupakan penerapan sederhana dari *Little’s Law*.

Contoh:

```text
Pengguna aktif per hari : 6.000 user
Jam operasional         : 8 jam
Durasi session          : 60 menit
```

Perhitungannya:

```text
Session per jam   = 6.000 ÷ 8
                   = 750 session/jam

Session per menit = 750 ÷ 60
                   = 12,5 session/menit

CCU                = 12,5 × 60
                   = 750 concurrent users
```

Jika rata-rata session hanya 15 menit:

```text
CCU = 12,5 × 15
    = 187,5
```

Dibulatkan menjadi sekitar **188 concurrent users**.

### 3.3 Menggunakan jumlah pengguna terdaftar

Metode ini digunakan jika data penggunaan belum tersedia.

Contoh asumsi:

```text
Total pengguna terdaftar       : 10.000
Pengguna aktif pada hari sibuk : 40%
Pengguna aktif bersamaan       : 20% dari pengguna harian
```

Perhitungan:

```text
Pengguna harian = 10.000 × 40%
                = 4.000 user

Target CCU      = 4.000 × 20%
                = 800 concurrent users
```

Metode ini hanya perkiraan. Persentase harus divalidasi dengan pemilik proses bisnis.

### 3.4 Menggunakan pola kejadian khusus

Beberapa aplikasi memiliki beban puncak pada waktu tertentu, misalnya:

- pembukaan periode input;
- batas waktu pelaporan;
- proses persetujuan serentak;
- pengumuman atau instruksi kepada seluruh unit;
- kegiatan tutup buku;
- pencairan atau transaksi massal.

Dalam kondisi tersebut, target CCU harus mengikuti pola kejadian puncak, bukan rata-rata harian.

---

## 4. Menentukan Level Skenario Pengujian

Setelah target bisnis diperoleh, susun beberapa level pengujian.

Contoh target bisnis:

```text
Target operasional : 750 CCU
```

Tahapan pengujian dapat dibuat sebagai berikut:

| Jenis pengujian | Contoh target | Tujuan |
|---|---:|---|
| Smoke test | 5–10 user | memastikan test plan dan data uji benar |
| Baseline | 25–40% target | memperoleh performa awal |
| Load test | 50–100% target | menguji kebutuhan operasional |
| Stress test | 110–150% target | mencari titik penurunan performa |
| Breakpoint test | dinaikkan bertahap | mencari batas kegagalan sistem |

Contoh untuk target 750 CCU:

```text
Baseline    : 200–300 CCU
Load test   : 500–750 CCU
Stress test : 825–1.125 CCU
```

Besaran tersebut bukan aturan mutlak. Penetapannya harus mempertimbangkan:

- spesifikasi environment;
- jumlah load generator;
- kapasitas jaringan;
- risiko terhadap data;
- kesiapan monitoring;
- persetujuan pemilik sistem.

---

## 5. Menentukan Target pada Environment Development

Jika environment development belum menyerupai production, target uji sebaiknya dibatasi.

Contoh:

```text
Target bisnis production : 750 CCU
Skenario awal DEV         : 40, 60, 80, dan 100 CU
```

Tujuan skenario DEV bukan untuk membuktikan bahwa production mampu menangani 750 CCU.

Tujuannya adalah:

- memvalidasi test plan;
- menemukan endpoint dengan error rate tinggi;
- mengenali bottleneck awal;
- melihat pola penurunan performa;
- menyediakan dasar optimalisasi sebelum uji production-like.

Hasil DEV tidak boleh langsung diekstrapolasi ke production karena perbedaan:

- CPU dan RAM;
- jumlah server;
- load balancer;
- database;
- storage;
- jaringan;
- redundansi;
- high availability;
- konfigurasi timeout dan connection pool.

Setelah endpoint bermasalah dioptimalkan, lakukan retest pada environment yang spesifikasi, konfigurasi, dan topologinya mendekati production agar hasilnya lebih representatif terhadap kondisi nyata di lapangan.

---

## 6. Kriteria Keberhasilan

Kriteria harus disepakati sebelum pengujian.

Contoh kriteria awal:

```text
Error rate keseluruhan : < 1%
HTTP 5xx               : < 0,5%
Average response time  : < 3 detik
p95 endpoint utama     : < 5 detik
Tidak ada restart service
Tidak ada connection pool exhaustion
```

Kriteria dapat berbeda berdasarkan karakteristik aplikasi. Untuk endpoint laporan atau proses berat, batas waktu respons dapat dibuat terpisah.

---


## 7. Skenario Pengujian

Panduan ini menggunakan skenario pengujian development sebagai berikut:

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

Setiap virtual user menjalankan satu alur aktivitas, lalu berhenti.

---

## 8. Instal Java

Unduh Java 17 LTS dari:

```text
https://adoptium.net/temurin/releases/
```

Pilih:

```text
Version      : 17 LTS
Operating OS : Windows
Architecture : x64
Package      : JDK
Installer    : MSI
```

Setelah instalasi, buka Command Prompt baru dan jalankan:

```bat
java -version
```

Jika versi Java muncul, instalasi berhasil.

---

## 9. Instal Apache JMeter

Unduh JMeter dari:

```text
https://jmeter.apache.org/download_jmeter.cgi
```

Pilih file binary ZIP, lalu ekstrak misalnya ke:

```text
C:\Tools\apache-jmeter-5.6.3
```

Atur lokasi JMeter:

```bat
set "JMETER_HOME=C:\Tools\apache-jmeter-5.6.3"
```

Periksa:

```bat
"%JMETER_HOME%\bin\jmeter.bat" -v
```

Pesan `WARN` tentang plugin dapat diabaikan selama versi JMeter tampil dan proses kembali ke Command Prompt.

---

## 10. Siapkan Paket Pengujian

Ekstrak paket ke:

```text
C:\LoadTest-Internal
```

Struktur minimal:

```text
C:\LoadTest-Internal
├── <TEST_PLAN>.jmx
├── run-loadtest-windows.bat
├── scenario-40.properties.template
├── scenario-60.properties.template
├── scenario-80.properties.template
├── scenario-100.properties.template
└── payloads
    ├── payload-1.bin
    └── payload-2.bin
```

Masuk ke folder:

```bat
cd /d C:\LoadTest-Internal
```

---

## 11. Isi File Properties

Jalankan skenario pertama:

```bat
run-loadtest-windows.bat 40
```

Pada eksekusi pertama, file berikut akan dibuat:

```text
scenario-40.properties
```

Isi parameter dengan data uji yang valid:

```properties
IP=<TARGET_IP_MASKED>
PROTOCOL=http
PORT=0

TOKEN_APPROVER=Bearer <TOKEN_MASKED>
TOKEN_OPERATOR_TRANSAKSI=Bearer <TOKEN_MASKED>
TOKEN_OPERATOR_DATA=Bearer <TOKEN_MASKED>

DATA_ID=<DATA_ID_MASKED>
DATA_DATE=2026-07-30

PAYLOAD_FILE_1=payloads/payload-1.bin
PAYLOAD_FILE_2=payloads/payload-2.bin

APPROVER_THREADS=32
OPERATOR_TRANSAKSI_THREADS=6
OPERATOR_DATA_THREADS=2

RAMP_UP=8

APPROVER_THINK_TIME_MS=3000
OPERATOR_TRANSAKSI_THINK_TIME_MS=3000
OPERATOR_DATA_THINK_TIME_MS=3000

CONNECT_TIMEOUT_MS=10000
RESPONSE_TIMEOUT_MS=60000
```

Simpan file, tutup Notepad, lalu jalankan kembali perintah yang sama.

> Jangan memasukkan token, IP, hostname, atau endpoint aktual ke laporan atau screenshot yang akan dibagikan.

---

## 12. Jalankan Pengujian

Atur JMeter:

```bat
set "JMETER_HOME=C:\Tools\apache-jmeter-5.6.3"
```

Masuk ke folder paket:

```bat
cd /d C:\LoadTest-Internal
```

Jalankan bertahap:

```bat
run-loadtest-windows.bat 40
run-loadtest-windows.bat 60
run-loadtest-windows.bat 80
run-loadtest-windows.bat 100
```

Jangan menjalankan semua skenario bersamaan.

Tunggu sampai muncul:

```text
... end of run
```

Setelah selesai, laporan HTML akan dibuat otomatis.

---

## 13. Lokasi Hasil

Hasil tersimpan dalam folder:

```text
results\scenario-40-<TIMESTAMP>
reports\scenario-40-<TIMESTAMP>
```

File utama:

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

## 14. Cara Membaca Output CMD

Contoh:

```text
summary + 243 in 00:00:30 = 8.2/s Avg: 1435 Min: 24 Max: 6251 Err: 0 (0.00%)
Active: 83 Started: 100 Finished: 17
```

Artinya:

| Bagian | Arti |
|---|---|
| `243` | request selesai pada interval tersebut |
| `8.2/s` | throughput per detik |
| `Avg` | rata-rata response time |
| `Min` | response time tercepat |
| `Max` | response time terlama |
| `Err` | jumlah dan persentase error |
| `Active` | thread yang masih aktif |
| `Started` | thread yang sudah dimulai |
| `Finished` | thread yang sudah selesai |

`summary +` berarti hasil interval terakhir.  
`summary =` berarti hasil kumulatif sejak awal.

---

## 15. Parameter yang Perlu Dilihat

Fokus pada:

- total sample;
- error rate;
- average response time;
- p90, p95, dan p99;
- maximum response time;
- throughput;
- endpoint dengan error tertinggi;
- grafik **Active Threads Over Time**.

Jangan menilai hasil hanya dari average response time. Request gagal yang dikembalikan cepat dapat membuat rata-rata terlihat lebih rendah.

---

## 16. Monitoring Server

Selama pengujian, pantau:

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

## 17. Menghentikan Pengujian

Hentikan secara normal:

```bat
"%JMETER_HOME%\bin\shutdown.cmd"
```

Hentikan segera:

```bat
"%JMETER_HOME%\bin\stoptest.cmd"
```

Gunakan penghentian segera hanya jika sistem mengalami gangguan serius.

---

## 18. Masalah Umum

### JMeter tidak ditemukan

```bat
set "JMETER_HOME=C:\Tools\apache-jmeter-5.6.3"
dir "%JMETER_HOME%\bin\jmeter.bat"
```

### Token tidak valid

Buka file properties:

```bat
notepad scenario-40.properties
```

Perbarui token akun uji.

### Payload tidak ditemukan

```bat
dir payloads
```

Pastikan nama dan lokasi file sesuai dengan properties.

### HTML tidak terbentuk

Periksa log:

```bat
notepad results\<FOLDER_HASIL>\scenario-40-jmeter.log
```

Buat ulang HTML dari JTL:

```bat
"%JMETER_HOME%\bin\jmeter.bat" -g "results\<FOLDER_HASIL>\scenario-40.jtl" -o "reports\scenario-40-regenerate"
```

### Test terlalu lama

Periksa:

- request yang menggantung;
- koneksi ke target;
- `RESPONSE_TIMEOUT_MS`;
- log JMeter;
- log aplikasi.

---

## 19. Setelah Pengujian

Lakukan hal berikut:

1. simpan file JTL, log, dan HTML Dashboard;
2. mask IP, hostname, endpoint, token, akun, dan ID data;
3. bersihkan data transaksi uji;
4. hapus token dari file properties;
5. cocokkan hasil dengan log aplikasi dan database;
6. catat endpoint dengan error dan response time tertinggi.

Contoh masking token:

```properties
TOKEN_APPROVER=Bearer <MASKED>
TOKEN_OPERATOR_TRANSAKSI=Bearer <MASKED>
TOKEN_OPERATOR_DATA=Bearer <MASKED>
```

---

## 20. Ringkasan Perintah

```bat
set "JMETER_HOME=C:\Tools\apache-jmeter-5.6.3"

java -version
"%JMETER_HOME%\bin\jmeter.bat" -v

cd /d C:\LoadTest-Internal

run-loadtest-windows.bat 40
run-loadtest-windows.bat 60
run-loadtest-windows.bat 80
run-loadtest-windows.bat 100
```

---

> **Penting:** Versi dokumen yang dibagikan tidak boleh memuat nama aplikasi, IP internal, hostname, endpoint aktual, token, cookie, session ID, akun, atau data transaksi.
