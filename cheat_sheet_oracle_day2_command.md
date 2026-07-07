# Cheat Sheet Pelatihan Basis Data - 7 Juli 2026

> Fokus materi: environment Oracle, SQL\*Plus, PDB, listener, password file, alias koneksi, perubahan port listener, redo log, archive log, dan penambahan redo log group.

---

## 0. Gambaran Besar Materi Hari Ini

Pada pelatihan hari ini, alur belajarnya dapat dipahami seperti berikut:

```text
1. Cek environment Oracle
2. Login ke database sebagai SYSDBA
3. Menyiapkan user HR di PDB
4. Memahami file penting Oracle: controlfile, spfile/pfile, password file, network file
5. Remote login menggunakan listener dan password file
6. Membuat alias koneksi dengan tnsnames.ora, netca, dan netmgr
7. Mengubah/membuat listener di port baru
8. Memahami fungsi listener saat koneksi berlangsung
9. Mengecek redo log file
10. Mengubah database ke ARCHIVELOG mode
11. Mengecek status redo log dan menambah redo log group
```

Kunci pemahaman hari ini:

- **Instance** berjalan berdasarkan `ORACLE_SID`.
- **Remote login** membutuhkan listener dan password file jika login sebagai `SYSDBA`.
- **Alias koneksi** disimpan di `tnsnames.ora`.
- **Listener** hanya menerima permintaan koneksi awal; setelah session terbentuk, query ditangani oleh server process.
- **Redo log** menyimpan jejak perubahan data untuk recovery.
- **ARCHIVELOG mode** diperlukan agar redo log lama disalin menjadi archive log untuk media recovery.

---

## 1. Informasi Lab

Contoh informasi lab dari materi:

```text
User Linux Oracle : oracle/oracle
User Linux root   : root/oracle
Oracle SID        : oradb
PDB               : PDB1
Oracle version    : Oracle Database 19c
```

Catatan:

- Informasi di atas adalah contoh lingkungan latihan.
- Pada server lain, nama SID, PDB, IP, dan path bisa berbeda.
- Selalu cek environment terlebih dahulu sebelum menjalankan command administrasi.

---

## 2. Cek Environment Oracle

### 2.1 Cek variabel environment Oracle

```bash
env | grep ORACLE
```

Fungsi:

- Melihat variabel environment Oracle yang aktif.
- Biasanya yang penting adalah `ORACLE_SID`, `ORACLE_BASE`, dan `ORACLE_HOME`.

Contoh hasil:

```text
ORACLE_SID=oradb
ORACLE_BASE=/u01/app/oracle
ORACLE_HOME=/u01/app/oracle/product/19.0.0/db_1
```

Makna:

| Variabel | Fungsi |
|---|---|
| `ORACLE_SID` | Nama instance Oracle yang akan diakses secara lokal. |
| `ORACLE_BASE` | Direktori dasar instalasi Oracle. |
| `ORACLE_HOME` | Direktori software Oracle Database. |

---

### 2.2 Cek daftar database di `/etc/oratab`

```bash
cat /etc/oratab
```

Fungsi:

- Melihat daftar Oracle database/SID yang terdaftar di server.
- Melihat pasangan antara SID dan `ORACLE_HOME`.
- Melihat apakah database diset auto-start (`Y`) atau tidak (`N`).

Contoh hasil:

```text
oradb:/u01/app/oracle/product/19.0.0/db_1:Y
```

Makna:

| Bagian | Arti |
|---|---|
| `oradb` | Nama SID/instance. |
| `/u01/app/oracle/product/19.0.0/db_1` | Lokasi Oracle Home. |
| `Y` | Database dapat ikut auto-start berdasarkan konfigurasi Oracle. |

---

## 3. Login ke SQL\*Plus

### 3.1 Login lokal sebagai SYSDBA

```bash
sqlplus / as sysdba
```

Fungsi:

- Masuk ke database sebagai administrator melalui OS authentication.
- Biasanya dijalankan langsung dari server Oracle menggunakan user OS `oracle`.
- Tidak membutuhkan password database karena menggunakan autentikasi lokal dari operating system.

---

### 3.2 Connect ulang dari dalam SQL\*Plus

```sql
conn / as sysdba
```

Fungsi:

- Menghubungkan session SQL\*Plus ke database sebagai SYSDBA.
- Dipakai jika sudah berada di dalam SQL\*Plus.

---

### 3.3 Login ke PDB dengan user HR

```sql
conn hr/hr@pdb1
```

Fungsi:

- Login sebagai user `HR` ke service/alias `pdb1`.
- Formatnya adalah:

```text
username/password@alias
```

Catatan:

- Alias `pdb1` harus sudah terdaftar di `tnsnames.ora`.
- Listener harus aktif agar koneksi melalui alias bisa dilakukan.

---

## 4. Menyiapkan User HR pada PDB

Pada Oracle Multitenant, user HR biasanya berada di PDB, bukan di root container.

### 4.1 Masuk sebagai SYSDBA

```bash
sqlplus / as sysdba
```

Fungsi:

- Masuk sebagai administrator agar bisa mengelola user dan privilege.

---

### 4.2 Pindah container ke PDB1

```sql
ALTER SESSION SET CONTAINER = PDB1;
```

Fungsi:

- Mengubah konteks session dari CDB root ke PDB1.
- Setelah command ini, perintah administrasi user akan berlaku pada PDB1.

Tambahan command untuk mengecek posisi container:

```sql
SHOW CON_NAME;
```

Fungsi:

- Menampilkan container aktif saat ini.
- Berguna untuk memastikan apakah sedang berada di `CDB$ROOT` atau `PDB1`.

---

### 4.3 Unlock user HR dan set password

```sql
ALTER USER hr IDENTIFIED BY hr ACCOUNT UNLOCK;
```

Fungsi:

- Mengatur password user HR menjadi `hr`.
- Membuka account HR jika sebelumnya terkunci.

---

### 4.4 Beri privilege login ke HR

```sql
GRANT CREATE SESSION TO hr;
```

Fungsi:

- Memberi hak kepada user HR agar bisa login ke database.
- Tanpa privilege ini, user bisa saja ada tetapi tidak dapat membuat session.

---

### 4.5 Tes login HR ke PDB

```bash
sqlplus hr/hr@PDB1
```

Fungsi:

- Menguji apakah user HR sudah bisa login ke PDB1 melalui alias `PDB1`.

Jika berhasil, akan muncul pesan seperti:

```text
Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
```

---

## 5. Monitoring Listener Log

### 5.1 Cek status listener dan lokasi file log

```bash
lsnrctl status
```

Fungsi:

- Mengecek apakah listener aktif.
- Melihat port listener.
- Melihat service database yang terdaftar.
- Melihat lokasi listener parameter file dan listener log file.

Untuk mengambil baris tertentu:

```bash
lsnrctl status | grep Listener
```

Atau lebih fleksibel:

```bash
lsnrctl status | grep -i listener
```

Fungsi:

- Menyaring output agar hanya baris yang mengandung kata `Listener` yang ditampilkan.

---

### 5.2 Monitor listener log secara real-time

Contoh lokasi listener log dari materi:

```text
/u01/app/oracle/diag/tnslsnr/srv1/listener/trace/listener.log
```

Command:

```bash
tail -f /u01/app/oracle/diag/tnslsnr/srv1/listener/trace/listener.log
```

Fungsi:

- Melihat log koneksi listener secara real-time.
- Berguna untuk memantau client yang mencoba connect ke database.
- Jika ada error koneksi seperti service tidak ditemukan atau password salah, indikasinya sering terlihat dari log ini.

Catatan:

- Path listener log bisa berbeda antar server.
- Gunakan `lsnrctl status` untuk memastikan lokasi log yang benar.

---

## 6. Controlfile, PFILE, dan SPFILE

### 6.1 Cek parameter controlfile

```sql
SHOW PARAMETER control_files;
```

Fungsi:

- Melihat lokasi controlfile yang digunakan oleh database.
- Parameter `control_files` biasanya berisi lebih dari satu lokasi untuk redundancy.

Contoh:

```text
/u01/app/oracle/oradata/ORADB/control01.ctl
/u01/app/oracle/fra/ORADB/control02.ctl
```

---

### 6.2 Cek controlfile dari dynamic performance view

```sql
SELECT name FROM v$controlfile;
```

Fungsi:

- Menampilkan daftar controlfile yang sedang dikenali database.
- Cocok untuk verifikasi setelah menambah atau menghapus path controlfile.

---

### 6.3 Membuat PFILE dari SPFILE

```sql
CREATE PFILE FROM SPFILE;
```

Fungsi:

- Membuat file parameter berbentuk teks dari SPFILE.
- PFILE hasilnya biasanya berada di `$ORACLE_HOME/dbs/init<SID>.ora`.
- PFILE bisa diedit manual menggunakan editor teks.

Contoh untuk SID `oradb`:

```text
$ORACLE_HOME/dbs/initoradb.ora
```

---

### 6.4 Shutdown database

```sql
SHUTDOWN ABORT;
```

Fungsi:

- Mematikan database secara paksa.
- Pada startup berikutnya Oracle akan melakukan instance recovery.

Catatan penting:

- Command ini dipakai di latihan untuk simulasi tertentu.
- Untuk administrasi normal, lebih aman memakai:

```sql
SHUTDOWN IMMEDIATE;
```

---

### 6.5 Menjalankan command OS dari SQL\*Plus

```sql
HOST pwd
```

Atau:

```sql
!pwd
```

Fungsi:

- Menjalankan command operating system dari dalam SQL\*Plus.
- Di lingkungan Linux, `!` dapat digunakan untuk menjalankan command shell.

Contoh lain:

```sql
!mkdir /home/oracle/cfbaru
```

Fungsi:

- Membuat direktori `/home/oracle/cfbaru` dari dalam SQL\*Plus.

---

### 6.6 Menyalin controlfile

Contoh dari materi:

```sql
!cp /u01/app/oracle/fra/ORADB/control02.ctl /home/oracle/cfbaru/control03.ctl
```

Fungsi:

- Menyalin controlfile existing menjadi salinan baru.
- Digunakan untuk simulasi menambah controlfile atau backup manual controlfile.

Catatan:

- Controlfile sangat penting untuk database.
- Jangan menghapus controlfile asli pada database produksi.
- Latihan penghapusan controlfile hanya aman dilakukan pada environment lab.

---

## 7. Alur Aman Menambah Controlfile

Bagian ini melengkapi catatan pelatihan agar alurnya lebih sistematis.

### 7.1 Cek controlfile existing

```sql
SHOW PARAMETER control_files;
SELECT name FROM v$controlfile;
```

Fungsi:

- Mengetahui lokasi controlfile yang sedang digunakan.

---

### 7.2 Buat PFILE dari SPFILE

```sql
CREATE PFILE FROM SPFILE;
```

Fungsi:

- Membuat parameter file teks agar parameter `control_files` bisa diedit manual.

---

### 7.3 Shutdown database

```sql
SHUTDOWN IMMEDIATE;
```

Fungsi:

- Mematikan database dengan aman sebelum menyalin controlfile.

---

### 7.4 Copy controlfile ke lokasi baru

Dari terminal Linux:

```bash
mkdir -p /home/oracle/cfbaru
cp /u01/app/oracle/fra/ORADB/control02.ctl /home/oracle/cfbaru/control03.ctl
```

Atau dari SQL\*Plus:

```sql
!mkdir -p /home/oracle/cfbaru
!cp /u01/app/oracle/fra/ORADB/control02.ctl /home/oracle/cfbaru/control03.ctl
```

Fungsi:

- Membuat salinan controlfile di lokasi baru.

---

### 7.5 Edit PFILE

```bash
gedit $ORACLE_HOME/dbs/initoradb.ora
```

Fungsi:

- Membuka PFILE untuk mengedit parameter database.

Contoh isi parameter `control_files` setelah ditambah:

```text
*.control_files='/u01/app/oracle/oradata/ORADB/control01.ctl',
'/u01/app/oracle/fra/ORADB/control02.ctl',
'/home/oracle/cfbaru/control03.ctl'
```

Catatan:

- Pastikan tanda kutip, koma, dan path benar.
- Jika path salah, database dapat gagal startup.

---

### 7.6 Buat ulang SPFILE dari PFILE

```sql
CREATE SPFILE FROM PFILE;
```

Fungsi:

- Membuat SPFILE baru berdasarkan isi PFILE yang sudah diedit.
- Oracle umumnya menggunakan SPFILE saat startup.

---

### 7.7 Startup database

```sql
STARTUP;
```

Fungsi:

- Menyalakan database menggunakan parameter baru.

---

### 7.8 Verifikasi controlfile

```sql
SELECT name FROM v$controlfile;
```

Fungsi:

- Memastikan controlfile tambahan sudah dikenali database.

---

## 8. Simulasi Menghapus Controlfile Tambahan

Bagian ini untuk memahami hubungan antara file fisik controlfile dan parameter `control_files`.

### 8.1 Cek controlfile yang aktif

```sql
SELECT name FROM v$controlfile;
```

Fungsi:

- Melihat controlfile yang masih terdaftar pada database.

---

### 8.2 Buat PFILE dari SPFILE

```sql
CREATE PFILE FROM SPFILE;
```

Fungsi:

- Membuat PFILE agar konfigurasi controlfile bisa diubah.

---

### 8.3 Shutdown paksa untuk latihan

```sql
SHUTDOWN ABORT;
```

Fungsi:

- Mematikan instance secara paksa.
- Pada latihan, ini digunakan untuk simulasi kondisi recovery.

---

### 8.4 Hapus controlfile tambahan

```sql
!rm /home/oracle/cfbaru/control03.ctl
```

Fungsi:

- Menghapus file controlfile tambahan.

Catatan:

- Jangan lakukan ini pada controlfile utama di production.
- Jika file sudah dihapus tetapi path masih ada di parameter `control_files`, database bisa gagal startup.

---

### 8.5 Edit PFILE dan hapus path controlfile yang sudah dihapus

```bash
gedit $ORACLE_HOME/dbs/initoradb.ora
```

Fungsi:

- Menghapus path controlfile yang sudah tidak ada dari parameter `control_files`.

---

### 8.6 Buat ulang SPFILE dan startup

```sql
CREATE SPFILE FROM PFILE;
STARTUP;
```

Fungsi:

- Membuat SPFILE baru dari PFILE yang sudah diperbaiki.
- Menyalakan database kembali.

---

### 8.7 Verifikasi

```sql
SELECT name FROM v$controlfile;
```

Fungsi:

- Memastikan hanya controlfile yang valid yang terdaftar.

---

## 9. Remote Login sebagai SYSDBA

### 9.1 Login remote dengan Easy Connect

```bash
sqlplus sys/oracle@localhost:1521/oradb.localdomain as sysdba
```

Fungsi:

- Login sebagai `SYSDBA` melalui listener menggunakan format Easy Connect.
- Format umum:

```text
sqlplus username/password@host:port/service_name as sysdba
```

Makna bagian command:

| Bagian | Arti |
|---|---|
| `sys` | User administrasi Oracle. |
| `oracle` | Password user SYS pada contoh lab. |
| `localhost` | Host tujuan. |
| `1521` | Port listener. |
| `oradb.localdomain` | Service name database. |
| `as sysdba` | Login dengan privilege SYSDBA. |

Catatan:

- Untuk login remote sebagai SYSDBA, password file harus tersedia dan valid.
- Listener harus aktif.

---

## 10. Password File Oracle

### 10.1 Lokasi password file

```bash
cd $ORACLE_HOME/dbs
ls
```

Fungsi:

- Masuk ke direktori tempat file konfigurasi database disimpan.
- Melihat file seperti `spfileoradb.ora`, `initoradb.ora`, dan `orapworadb`.

Contoh password file:

```text
orapworadb
```

Makna:

```text
orapw<SID>
```

Untuk SID `oradb`, nama password file menjadi:

```text
orapworadb
```

---

### 10.2 Simulasi password file tidak tersedia

```bash
mv orapworadb orapwxxx
```

Fungsi:

- Mengganti nama password file sehingga Oracle tidak dapat menemukannya.
- Digunakan untuk membuktikan bahwa remote login SYSDBA membutuhkan password file.

Kemudian coba login:

```bash
sqlplus sys/oracle@localhost:1521/oradb.localdomain as sysdba
```

Jika password file tidak valid/tidak tersedia, dapat muncul error:

```text
ORA-01017: invalid username/password; logon denied
```

---

### 10.3 Mengembalikan password file

```bash
mv orapwxxx orapworadb
```

Fungsi:

- Mengembalikan nama password file seperti semula.

Tes kembali:

```bash
sqlplus sys/oracle@localhost:1521/oradb.localdomain as sysdba
```

Jika berhasil, berarti password file kembali terbaca.

---

### 10.4 Membuat ulang password file

Contoh dari materi:

```bash
orapwd file=orapworadb password=Cakgup2026*
```

Fungsi:

- Membuat password file baru untuk SID aktif.
- Password `SYS` untuk remote SYSDBA login mengikuti password yang dibuat di password file.

Versi yang lebih aman jika file sudah ada:

```bash
orapwd file=orapworadb password='Cakgup2026*' force=y
```

Fungsi tambahan:

- `force=y` mengizinkan overwrite password file existing.
- Tanda kutip membantu jika password mengandung karakter khusus seperti `*`.

Setelah password file dibuat ulang, login lama bisa gagal:

```bash
sqlplus sys/oracle@localhost:1521/oradb.localdomain as sysdba
```

Login dengan password baru:

```bash
sqlplus sys/'Cakgup2026*'@localhost:1521/oradb.localdomain as sysdba
```

Catatan:

- Jika shell bermasalah dengan karakter khusus, gunakan tanda kutip.
- Pada environment tertentu, penulisan password dengan karakter `*` tanpa kutip bisa diproses oleh shell sebagai wildcard.

---

### 10.5 Cek parameter password file

Tambahan command yang berguna:

```sql
SHOW PARAMETER remote_login_passwordfile;
```

Fungsi:

- Mengecek apakah Oracle menggunakan password file untuk remote login SYSDBA.

Nilai yang umum:

| Nilai | Makna |
|---|---|
| `EXCLUSIVE` | Password file digunakan untuk satu database dan bisa menyimpan beberapa user SYSDBA. |
| `SHARED` | Password file bisa dipakai bersama, tetapi lebih terbatas. |
| `NONE` | Remote SYSDBA login dengan password file tidak digunakan. |

---

## 11. Network File Oracle

Network file digunakan untuk mengatur koneksi Oracle Net.

### 11.1 Masuk ke folder network admin

```bash
cd $ORACLE_HOME/network/admin
```

Fungsi:

- Masuk ke direktori konfigurasi Oracle networking.

---

### 11.2 Cek isi folder

```bash
ls
```

Fungsi:

- Melihat file network Oracle.

File yang umum:

| File | Fungsi |
|---|---|
| `listener.ora` | Konfigurasi listener di sisi server. |
| `tnsnames.ora` | Daftar alias koneksi database. |
| `sqlnet.ora` | Pengaturan tambahan Oracle Net, misalnya metode naming dan autentikasi. |

---

### 11.3 Melihat isi tnsnames.ora

```bash
cat tnsnames.ora
```

Fungsi:

- Melihat daftar alias koneksi database.
- Alias ini bisa dipakai dalam command `sqlplus user/pass@alias`.

Contoh alias:

```text
ORADB =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = srv1.localdomain)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = oradb.localdomain)
    )
  )
```

Fungsi alias `ORADB`:

- Mengarahkan koneksi ke host `srv1.localdomain`.
- Menggunakan port listener `1521`.
- Mengakses service `oradb.localdomain`.

---

### 11.4 Contoh alias PDB

```text
PDB1 =
  (DESCRIPTION =
    (ADDRESS_LIST =
      (ADDRESS = (PROTOCOL = TCP)(HOST = srv1.localdomain)(PORT = 1521))
    )
    (CONNECT_DATA =
      (SERVICE_NAME = pdb1.localdomain)
    )
  )
```

Fungsi:

- Membuat alias `PDB1` yang mengarah ke service PDB `pdb1.localdomain`.
- Setelah alias ini ada, user bisa login dengan:

```bash
sqlplus hr/hr@PDB1
```

---

## 12. Membuat Alias Aman Menggunakan NETCA

`netca` adalah Oracle Net Configuration Assistant. Tool ini membantu membuat alias tanpa mengetik manual `tnsnames.ora`.

### 12.1 Jalankan NETCA

```bash
netca
```

Fungsi:

- Membuka wizard konfigurasi Oracle Net.

---

### 12.2 Pilih menu

Pilih:

```text
Local Net Service Name configuration
```

Fungsi:

- Membuat alias koneksi lokal di `tnsnames.ora`.

---

### 12.3 Pilih Add

```text
Add
```

Fungsi:

- Menambahkan alias koneksi baru.

---

### 12.4 Isi service name

Contoh untuk database utama:

```text
oradb.localdomain
```

Contoh untuk PDB:

```text
pdb1.localdomain
```

Fungsi:

- Service name menunjukkan database/PDB tujuan yang akan dikoneksi.

---

### 12.5 Pilih protocol

```text
TCP
```

Fungsi:

- Menggunakan protokol TCP/IP untuk koneksi database.

---

### 12.6 Isi host dan port

Contoh:

```text
Host : localhost
Port : 1521
```

Atau:

```text
Host : srv1.localdomain
Port : 1521
```

Fungsi:

- Host adalah server database.
- Port adalah port listener.

---

### 12.7 Test koneksi

Pada wizard NETCA, gunakan tombol test koneksi.

Fungsi:

- Memastikan alias yang dibuat benar.
- Jika login test gagal karena user/password default, gunakan `Change Login` dan masukkan user yang valid, misalnya `hr/hr`.

---

### 12.8 Beri nama alias

Contoh alias:

```text
serverku
pdbsatu
```

Fungsi:

- Nama alias ini yang akan dipakai saat login.

Contoh login:

```bash
sqlplus sys/oracle@serverku as sysdba
```

```bash
sqlplus hr/hr@pdbsatu
```

---

## 13. Tes Alias dengan TNSPING

### 13.1 Tes alias database utama

```bash
tnsping serverku
```

Fungsi:

- Mengecek apakah alias `serverku` dapat di-resolve oleh Oracle Net.
- Mengecek apakah format alias di `tnsnames.ora` terbaca.

Jika berhasil, akan muncul:

```text
OK (0 msec)
```

Catatan penting:

- `tnsping` hanya mengetes resolusi alias dan keterjangkauan listener.
- `tnsping` tidak membuktikan username/password benar.
- Untuk membuktikan login berhasil, tetap gunakan `sqlplus`.

---

### 13.2 Login menggunakan alias

```bash
sqlplus sys/oracle@serverku as sysdba
```

Fungsi:

- Login sebagai SYSDBA menggunakan alias `serverku`.

---

### 13.3 Tes alias PDB

```bash
tnsping pdbsatu
```

Fungsi:

- Mengecek alias `pdbsatu` yang mengarah ke service PDB.

Login ke PDB:

```bash
sqlplus hr/hr@pdbsatu
```

Fungsi:

- Login sebagai HR ke PDB melalui alias `pdbsatu`.

---

## 14. Mengecek Service Name Database

### 14.1 Cek parameter nama database

```sql
SHOW PARAMETER db_name;
```

Fungsi:

- Melihat nama database.

---

### 14.2 Cek domain database

```sql
SHOW PARAMETER db_domain;
```

Fungsi:

- Melihat domain database.

---

### 14.3 Cek service name

```sql
SHOW PARAMETER service_names;
```

Fungsi:

- Melihat service name database.
- Service name inilah yang digunakan dalam `tnsnames.ora` dan Easy Connect.

Contoh:

```text
db_name       = ORADB
db_domain     = localdomain
service_names = oradb.localdomain
```

Kesimpulan:

```text
db_name + db_domain = oradb.localdomain
```

---

### 14.4 Tambahan: melihat daftar service aktif

```sql
SELECT name FROM v$services ORDER BY name;
```

Fungsi:

- Melihat semua service yang dikenal oleh database.
- Berguna untuk memastikan service PDB sudah terdaftar.

---

## 15. Mengecek Port Listener

### 15.1 Cek port dari lsnrctl

```bash
lsnrctl status | grep PORT
```

Fungsi:

- Menampilkan endpoint listener beserta port yang digunakan.

Contoh output:

```text
(ADDRESS=(PROTOCOL=tcp)(HOST=srv1.localdomain)(PORT=1521))
```

---

### 15.2 Cek port dari operating system

```bash
netstat -an | grep 1521
```

Fungsi:

- Mengecek apakah port 1521 sedang listening atau sedang memiliki koneksi aktif.

Contoh output:

```text
tcp6   0   0 :::1521   :::*   LISTEN
```

Makna:

- `LISTEN` berarti ada proses yang membuka port tersebut.
- Jika port listener aktif, biasanya port 1521 terlihat sebagai `LISTEN`.

Tambahan command modern:

```bash
ss -ltnp | grep 1521
```

Fungsi:

- Alternatif modern dari `netstat` untuk melihat port TCP yang listening.

---

## 16. Membuat Listener Baru di Port Berbeda dengan NETMGR

Pada materi, listener baru dibuat dengan nama contoh:

```text
KUPING
```

Port baru:

```text
1522
```

### 16.1 Jalankan Oracle Net Manager

```bash
netmgr
```

Fungsi:

- Membuka Oracle Net Manager.
- Digunakan untuk mengelola listener, service naming, dan konfigurasi Oracle Net.

---

### 16.2 Buat listener baru

Langkah umum di GUI:

```text
Oracle Net Configuration
└── Local
    └── Listeners
        └── Add listener
```

Isi nama listener:

```text
KUPING
```

Fungsi:

- Membuat konfigurasi listener baru dengan nama `KUPING`.

---

### 16.3 Tambahkan Listening Location

Pilih:

```text
Listening Locations
Add Address
```

Isi:

```text
Protocol : TCP/IP
Host     : localhost
Port     : 1522
```

Fungsi:

- Menentukan listener `KUPING` akan menerima koneksi pada host `localhost` dan port `1522`.

---

### 16.4 Tambahkan Database Services

Pilih:

```text
Database Services
Add Database
```

Contoh untuk database utama:

```text
Global Database Name : oradb.localdomain
Oracle Home Directory: /u01/app/oracle/product/19.0.0/db_1
SID                  : oradb
```

Contoh untuk PDB:

```text
Global Database Name : pdb1.localdomain
Oracle Home Directory: /u01/app/oracle/product/19.0.0/db_1
SID                  : oradb
```

Catatan penting:

- **SID** adalah nama instance, dalam lab ini `oradb`.
- **Service name** bisa database utama atau PDB, misalnya `oradb.localdomain` atau `pdb1.localdomain`.
- Pada PDB, service name PDB tetap menggunakan SID instance yang sama.

---

### 16.5 Save konfigurasi

Di GUI Net Manager:

```text
File → Save Network Configuration
```

Fungsi:

- Menyimpan perubahan ke file network Oracle, terutama `listener.ora`.

---

### 16.6 Pastikan port baru belum digunakan

```bash
netstat -an | grep 1522
```

Fungsi:

- Mengecek apakah port 1522 sudah dipakai proses lain.
- Jika belum ada output, biasanya port belum digunakan.

Cek port lama:

```bash
netstat -an | grep 1521
```

Fungsi:

- Membandingkan dengan port listener default.

---

### 16.7 Start listener baru

```bash
lsnrctl start kuping
```

Fungsi:

- Menjalankan listener bernama `kuping`.
- Nama listener tidak harus huruf besar saat command, tetapi mengikuti konfigurasi di `listener.ora`.

---

### 16.8 Cek status listener baru

```bash
lsnrctl status kuping
```

Fungsi:

- Melihat apakah listener `kuping` aktif.
- Memastikan port 1522 sudah digunakan.
- Melihat service yang dilayani listener tersebut.

Contoh endpoint:

```text
(ADDRESS=(PROTOCOL=tcp)(HOST=127.0.0.1)(PORT=1522))
```

---

## 17. Login ke Database Melalui Port Baru

### 17.1 Login langsung dengan Easy Connect

```bash
sqlplus hr/hr@localhost:1522/pdb1.localdomain
```

Fungsi:

- Login sebagai HR ke PDB melalui listener baru di port 1522.

Format umum:

```text
sqlplus username/password@host:port/service_name
```

---

### 17.2 Membuat alias untuk port baru di tnsnames.ora

Contoh alias:

```text
TETANGGAKU =
  (DESCRIPTION =
    (ADDRESS_LIST =
      (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = 1522))
    )
    (CONNECT_DATA =
      (SERVICE_NAME = pdb1.localdomain)
    )
  )
```

Fungsi:

- Membuat alias `TETANGGAKU` yang mengarah ke PDB melalui port 1522.

---

### 17.3 Login menggunakan alias port baru

```bash
sqlplus hr/hr@tetanggaku
```

Fungsi:

- Login ke PDB menggunakan alias yang lebih pendek.

---

### 17.4 Tes query setelah login

```sql
SELECT * FROM regions;
```

Fungsi:

- Memastikan koneksi HR berhasil dan schema HR bisa mengakses tabel contoh.

Contoh hasil:

```text
REGION_ID  REGION_NAME
---------  -------------------------
1          Europe
2          Americas
3          Asia
4          Middle East and Africa
```

---

## 18. Memahami Fungsi Listener Setelah Koneksi Terbentuk

### 18.1 Stop listener baru

```bash
lsnrctl stop kuping
```

Fungsi:

- Menghentikan listener bernama `kuping`.

---

### 18.2 Konsep penting

Setelah session SQL\*Plus berhasil connect:

```text
Client → Listener → Server Process → Instance
```

Listener hanya dibutuhkan pada saat awal koneksi.

Setelah koneksi terbentuk:

```text
Client ↔ Server Process ↔ Instance
```

Artinya:

- Jika listener dimatikan setelah session SQL\*Plus berhasil connect, session yang sudah aktif masih bisa menjalankan query.
- Namun, jika session tersebut keluar (`EXIT`) lalu mencoba login lagi, koneksi baru akan gagal jika listener masih mati.

Ringkasnya:

| Kondisi | Hasil |
|---|---|
| Listener hidup, session belum connect | Bisa login. |
| Listener dimatikan setelah session connect | Session lama masih bisa query. |
| Listener mati, user mencoba login baru | Login gagal. |

---

## 19. Redo Log File

Redo log menyimpan catatan perubahan data. Redo log digunakan Oracle untuk recovery jika terjadi crash.

### 19.1 Cek file redo log

```sql
SELECT group#, member FROM v$logfile;
```

Fungsi:

- Menampilkan lokasi file redo log untuk setiap group.

Contoh hasil:

```text
GROUP#  MEMBER
------  -------------------------------------------
3       /u01/app/oracle/oradata/ORADB/redo03.log
2       /u01/app/oracle/oradata/ORADB/redo02.log
1       /u01/app/oracle/oradata/ORADB/redo01.log
```

---

### 19.2 Cek ukuran redo log

```sql
SELECT group#, bytes/(1024*1024) MB FROM v$log;
```

Fungsi:

- Menampilkan ukuran masing-masing redo log group dalam MB.

Contoh hasil:

```text
GROUP#   MB
------   ---
1        200
2        200
3        200
```

---

### 19.3 Cek status redo log

```sql
SELECT group#, status FROM v$log;
```

Fungsi:

- Melihat status masing-masing redo log group.

Makna status:

| Status | Makna |
|---|---|
| `CURRENT` | Group sedang menjadi target penulisan LGWR dan belum penuh. |
| `ACTIVE` | Group tidak sedang ditulis LGWR, tetapi isinya belum sepenuhnya sync dengan datafile atau masih diperlukan untuk recovery. |
| `INACTIVE` | Group tidak sedang ditulis LGWR dan isinya sudah tidak diperlukan untuk instance recovery. |
| `UNUSED` | Group baru dibuat dan belum pernah digunakan. |

---

## 20. Mengubah Database Menjadi ARCHIVELOG Mode

ARCHIVELOG mode membuat Oracle menyalin online redo log yang penuh menjadi archive log.

Kegunaan:

- Mendukung media recovery.
- Mendukung backup online/hot backup.
- Umumnya wajib untuk database production.

---

### 20.1 Cek mode archive log saat ini

```sql
ARCHIVE LOG LIST;
```

Fungsi:

- Melihat apakah database berada pada `Archive Mode` atau `No Archive Mode`.
- Melihat apakah automatic archival aktif.
- Melihat destination archive log.

---

### 20.2 Shutdown database

```sql
SHUTDOWN IMMEDIATE;
```

Fungsi:

- Mematikan database dengan aman sebelum mengubah mode archive log.

---

### 20.3 Startup sampai MOUNT

```sql
STARTUP MOUNT;
```

Fungsi:

- Menyalakan instance dan mount database.
- Database belum open, sehingga mode archive log bisa diubah.

---

### 20.4 Aktifkan ARCHIVELOG mode

```sql
ALTER DATABASE ARCHIVELOG;
```

Fungsi:

- Mengubah database dari `NOARCHIVELOG` menjadi `ARCHIVELOG` mode.

---

### 20.5 Open database

```sql
ALTER DATABASE OPEN;
```

Fungsi:

- Membuka database agar bisa digunakan kembali.

---

### 20.6 Verifikasi archive log mode

```sql
ARCHIVE LOG LIST;
```

Fungsi:

- Memastikan database sudah berada pada `Archive Mode`.

Contoh hasil yang diharapkan:

```text
Database log mode              Archive Mode
Automatic archival             Enabled
Archive destination            USE_DB_RECOVERY_FILE_DEST
```

---

### 20.7 Cek lokasi archive log / FRA

```sql
SHOW PARAMETER db_recovery_file_dest;
```

Fungsi:

- Melihat lokasi Fast Recovery Area/FRA.
- Jika archive destination memakai `USE_DB_RECOVERY_FILE_DEST`, archive log akan disimpan di lokasi ini.

Cek ukuran FRA:

```sql
SHOW PARAMETER db_recovery_file_dest_size;
```

Fungsi:

- Melihat batas ukuran Fast Recovery Area.

---

## 21. Switch Logfile dan Checkpoint

### 21.1 Paksa pindah redo log group

```sql
ALTER SYSTEM SWITCH LOGFILE;
```

Fungsi:

- Memaksa Oracle berpindah dari redo log group saat ini ke group berikutnya.
- Berguna untuk latihan melihat perubahan status redo log.
- Pada ARCHIVELOG mode, group lama akan diarsipkan jika sudah penuh/switch.

---

### 21.2 Paksa checkpoint

```sql
ALTER SYSTEM CHECKPOINT;
```

Fungsi:

- Meminta Oracle melakukan checkpoint.
- DBWn menulis dirty blocks dari buffer cache ke datafile.
- CKPT memperbarui informasi checkpoint di controlfile dan datafile header.

---

### 21.3 Cek ulang status redo log

```sql
SELECT group#, status FROM v$log;
```

Fungsi:

- Melihat perubahan status redo log setelah switch logfile dan checkpoint.

---

## 22. Menambah Redo Log Group

### 22.1 Tambah redo log group tanpa menentukan path

Contoh dari materi:

```sql
ALTER DATABASE ADD LOGFILE GROUP 4 SIZE 200M;
```

Fungsi:

- Menambahkan redo log group baru dengan nomor group 4.
- Ukuran redo log group adalah 200 MB.

Catatan:

- Jika tidak menentukan path file, Oracle akan menggunakan default destination atau Oracle Managed Files jika dikonfigurasi.
- Untuk latihan ini bisa berjalan sesuai konfigurasi lab.

---

### 22.2 Tambah redo log group dengan path eksplisit

Alternatif yang lebih jelas:

```sql
ALTER DATABASE ADD LOGFILE GROUP 4
('/u01/app/oracle/oradata/ORADB/redo04.log') SIZE 200M;
```

Fungsi:

- Menambahkan redo log group 4 dengan lokasi file yang ditentukan secara eksplisit.

---

### 22.3 Verifikasi ukuran redo log

```sql
SELECT group#, bytes/(1024*1024) MB FROM v$log;
```

Fungsi:

- Memastikan group baru muncul dengan ukuran yang sesuai.

---

### 22.4 Verifikasi status redo log

```sql
SELECT group#, status FROM v$log;
```

Fungsi:

- Melihat status group baru.

Jika baru ditambahkan, statusnya biasanya:

```text
UNUSED
```

Makna:

- Group sudah ada tetapi belum pernah digunakan oleh LGWR.

---

### 22.5 Melihat file redo log group baru

```sql
SELECT group#, member FROM v$logfile ORDER BY group#;
```

Fungsi:

- Melihat lokasi file redo log untuk setiap group, termasuk group baru.

---

## 23. Ringkasan Command Berurutan untuk Latihan

Bagian ini bisa digunakan sebagai alur praktik dari awal sampai akhir.

### A. Cek environment

```bash
env | grep ORACLE
cat /etc/oratab
```

Fungsi:

- Memastikan SID, Oracle Base, Oracle Home, dan database terdaftar.

---

### B. Login sebagai SYSDBA

```bash
sqlplus / as sysdba
```

Fungsi:

- Masuk sebagai administrator lokal.

---

### C. Siapkan HR di PDB

```sql
ALTER SESSION SET CONTAINER = PDB1;
ALTER USER hr IDENTIFIED BY hr ACCOUNT UNLOCK;
GRANT CREATE SESSION TO hr;
```

Fungsi:

- Pindah ke PDB1.
- Membuka user HR.
- Memberi privilege login ke HR.

---

### D. Tes HR login

```bash
sqlplus hr/hr@PDB1
```

Fungsi:

- Memastikan user HR bisa login ke PDB.

---

### E. Cek listener

```bash
lsnrctl status
lsnrctl status | grep -i listener
```

Fungsi:

- Mengecek listener, port, service, dan lokasi log.

---

### F. Monitor listener log

```bash
tail -f /u01/app/oracle/diag/tnslsnr/srv1/listener/trace/listener.log
```

Fungsi:

- Memantau aktivitas koneksi listener secara real-time.

---

### G. Cek controlfile

```sql
SHOW PARAMETER control_files;
SELECT name FROM v$controlfile;
```

Fungsi:

- Melihat controlfile yang digunakan database.

---

### H. Buat PFILE dari SPFILE

```sql
CREATE PFILE FROM SPFILE;
```

Fungsi:

- Membuat parameter file teks untuk latihan edit parameter.

---

### I. Cek password file

```bash
cd $ORACLE_HOME/dbs
ls -l orapw*
```

Fungsi:

- Melihat password file Oracle untuk remote SYSDBA login.

---

### J. Tes remote SYSDBA login

```bash
sqlplus sys/oracle@localhost:1521/oradb.localdomain as sysdba
```

Fungsi:

- Menguji login SYSDBA melalui listener.

---

### K. Cek network file

```bash
cd $ORACLE_HOME/network/admin
ls
cat tnsnames.ora
```

Fungsi:

- Melihat konfigurasi alias koneksi Oracle.

---

### L. Membuat alias dengan netca

```bash
netca
```

Fungsi:

- Membuat alias koneksi dengan wizard.

Tes alias:

```bash
tnsping serverku
sqlplus sys/oracle@serverku as sysdba
```

Fungsi:

- Mengecek alias dan login menggunakan alias.

---

### M. Membuat listener port baru dengan netmgr

```bash
netmgr
```

Fungsi:

- Membuat listener baru, misalnya `KUPING` di port 1522.

Cek port:

```bash
netstat -an | grep 1522
```

Start listener:

```bash
lsnrctl start kuping
```

Cek status:

```bash
lsnrctl status kuping
```

---

### N. Login lewat port baru

```bash
sqlplus hr/hr@localhost:1522/pdb1.localdomain
```

Fungsi:

- Login ke PDB melalui listener port 1522.

---

### O. Membuat alias port baru

Tambahkan di `tnsnames.ora`:

```text
TETANGGAKU =
  (DESCRIPTION =
    (ADDRESS_LIST =
      (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = 1522))
    )
    (CONNECT_DATA =
      (SERVICE_NAME = pdb1.localdomain)
    )
  )
```

Tes:

```bash
tnsping tetanggaku
sqlplus hr/hr@tetanggaku
```

Fungsi:

- Menggunakan alias untuk koneksi ke port baru.

---

### P. Stop listener dan pahami dampaknya

```bash
lsnrctl stop kuping
```

Fungsi:

- Menghentikan listener `kuping`.

Konsep:

- Session yang sudah terhubung masih bisa query.
- Koneksi baru gagal karena listener mati.

---

### Q. Cek redo log

```sql
SELECT group#, member FROM v$logfile;
SELECT group#, bytes/(1024*1024) MB FROM v$log;
SELECT group#, status FROM v$log;
```

Fungsi:

- Melihat file redo log, ukuran redo log, dan status redo log.

---

### R. Aktifkan ARCHIVELOG mode

```sql
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;
ARCHIVE LOG LIST;
```

Fungsi:

- Mengubah database ke ARCHIVELOG mode dan memverifikasi hasilnya.

---

### S. Cek FRA/archive destination

```sql
SHOW PARAMETER db_recovery_file_dest;
SHOW PARAMETER db_recovery_file_dest_size;
```

Fungsi:

- Melihat lokasi dan ukuran Fast Recovery Area.

---

### T. Switch logfile dan checkpoint

```sql
ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM CHECKPOINT;
SELECT group#, status FROM v$log;
```

Fungsi:

- Memaksa perpindahan redo log group.
- Memaksa checkpoint.
- Melihat perubahan status redo log.

---

### U. Tambah redo log group

```sql
ALTER DATABASE ADD LOGFILE GROUP 4 SIZE 200M;
SELECT group#, bytes/(1024*1024) MB FROM v$log;
SELECT group#, status FROM v$log;
SELECT group#, member FROM v$logfile ORDER BY group#;
```

Fungsi:

- Menambah redo log group baru.
- Mengecek ukuran, status, dan lokasi file redo log.

---

## 24. Troubleshooting Ringkas

### 24.1 `ORA-01017: invalid username/password; logon denied`

Kemungkinan penyebab:

- Password salah.
- Password file tidak ada atau salah nama.
- Password file baru dibuat dengan password berbeda.
- Login remote SYSDBA tidak membaca password file yang benar.

Cek:

```bash
cd $ORACLE_HOME/dbs
ls -l orapw*
```

```sql
SHOW PARAMETER remote_login_passwordfile;
```

Solusi lab:

```bash
mv orapwxxx orapworadb
```

Atau buat ulang:

```bash
orapwd file=orapworadb password='PasswordBaru' force=y
```

---

### 24.2 `tnsping` OK tetapi `sqlplus` gagal

Kemungkinan penyebab:

- Alias benar, tetapi username/password salah.
- User belum unlock.
- User belum punya `CREATE SESSION`.
- Service mengarah ke database/PDB yang berbeda.

Cek:

```bash
tnsping alias
```

```sql
SHOW PARAMETER service_names;
SELECT name FROM v$services ORDER BY name;
```

Untuk user HR:

```sql
ALTER SESSION SET CONTAINER = PDB1;
ALTER USER hr IDENTIFIED BY hr ACCOUNT UNLOCK;
GRANT CREATE SESSION TO hr;
```

---

### 24.3 Listener mati tetapi session lama masih bisa query

Ini normal.

Penyebab:

- Listener hanya menerima koneksi awal.
- Setelah koneksi terbentuk, komunikasi dilakukan oleh server process.

Dampak:

- Session lama tetap berjalan.
- Login baru gagal sampai listener dinyalakan lagi.

Start listener:

```bash
lsnrctl start kuping
```

Atau listener default:

```bash
lsnrctl start
```

---

### 24.4 Database gagal startup setelah edit controlfile

Kemungkinan penyebab:

- Path controlfile di `control_files` salah.
- File controlfile sudah dihapus tetapi masih tercantum di parameter.
- SPFILE dibuat dari PFILE yang salah.

Cek PFILE:

```bash
cat $ORACLE_HOME/dbs/initoradb.ora
```

Perbaiki parameter:

```bash
gedit $ORACLE_HOME/dbs/initoradb.ora
```

Buat ulang SPFILE:

```sql
CREATE SPFILE FROM PFILE;
STARTUP;
```

---

## 25. Peta Konsep Cepat

### 25.1 Listener vs TNS Alias

| Komponen | Lokasi | Fungsi |
|---|---|---|
| Listener | Server database | Menerima koneksi awal dari client. |
| `listener.ora` | `$ORACLE_HOME/network/admin` | Mengatur listener, host, port, dan service static. |
| `tnsnames.ora` | Client atau server | Menyimpan alias koneksi. |
| `sqlnet.ora` | Client atau server | Mengatur metode Oracle Net tambahan. |
| `tnsping` | Client/server | Mengetes apakah alias dapat di-resolve. |
| `sqlplus` | Client/server | Melakukan koneksi database sebenarnya. |

---

### 25.2 SPFILE vs PFILE

| File | Format | Bisa diedit manual? | Fungsi |
|---|---|---|---|
| PFILE | Text | Ya | Parameter file manual, biasanya `init<SID>.ora`. |
| SPFILE | Binary | Tidak langsung | Parameter file utama yang umum dipakai Oracle saat startup. |

Command penting:

```sql
CREATE PFILE FROM SPFILE;
CREATE SPFILE FROM PFILE;
SHOW PARAMETER spfile;
```

---

### 25.3 Controlfile

Controlfile berisi metadata penting database, misalnya:

- Nama database.
- DBID.
- Lokasi datafile.
- Lokasi redo log.
- Checkpoint SCN.
- Informasi backup/recovery tertentu.

Command penting:

```sql
SHOW PARAMETER control_files;
SELECT name FROM v$controlfile;
```

---

### 25.4 Password File

Password file digunakan untuk:

- Remote login sebagai `SYSDBA`.
- User selain SYS yang diberi privilege SYSDBA/SYSOPER.

Command penting:

```bash
cd $ORACLE_HOME/dbs
ls -l orapw*
orapwd file=orapworadb password='PasswordBaru' force=y
```

```sql
SHOW PARAMETER remote_login_passwordfile;
```

---

### 25.5 Redo Log dan Archive Log

| Komponen | Fungsi |
|---|---|
| Online redo log | Menyimpan perubahan terbaru untuk instance recovery. |
| Archive log | Salinan redo log yang sudah penuh/switch untuk media recovery. |
| LGWR | Menulis redo entries dari redo log buffer ke online redo log. |
| ARCHIVELOG mode | Mengaktifkan penyimpanan redo lama menjadi archive log. |

Command penting:

```sql
SELECT group#, member FROM v$logfile;
SELECT group#, status FROM v$log;
ARCHIVE LOG LIST;
ALTER DATABASE ARCHIVELOG;
ALTER SYSTEM SWITCH LOGFILE;
```

---

## 26. Checklist Belajar Mandiri

Gunakan checklist ini saat mengulang materi.

```text
[ ] Saya bisa menjelaskan fungsi ORACLE_SID, ORACLE_BASE, dan ORACLE_HOME.
[ ] Saya bisa login lokal sebagai SYSDBA.
[ ] Saya bisa pindah container ke PDB1.
[ ] Saya bisa unlock user HR dan memberi CREATE SESSION.
[ ] Saya bisa membaca lokasi controlfile.
[ ] Saya memahami beda PFILE dan SPFILE.
[ ] Saya tahu lokasi password file dan fungsinya.
[ ] Saya bisa login remote SYSDBA menggunakan Easy Connect.
[ ] Saya bisa membaca tnsnames.ora.
[ ] Saya bisa membuat alias dengan netca.
[ ] Saya bisa mengetes alias dengan tnsping.
[ ] Saya tahu bahwa tnsping OK belum tentu login SQL berhasil.
[ ] Saya bisa membuat listener baru di port berbeda menggunakan netmgr.
[ ] Saya bisa start/stop listener tertentu dengan lsnrctl.
[ ] Saya paham listener hanya diperlukan untuk koneksi awal.
[ ] Saya bisa mengecek redo log group, ukuran, dan status.
[ ] Saya bisa mengubah database ke ARCHIVELOG mode.
[ ] Saya bisa melakukan switch logfile dan checkpoint.
[ ] Saya bisa menambah redo log group dan memverifikasi hasilnya.
```

---

## 27. Mini Latihan Ujian Lisan

Coba jawab tanpa melihat catatan.

1. Apa bedanya `ORACLE_SID` dan `SERVICE_NAME`?
2. Mengapa `sqlplus / as sysdba` bisa login tanpa password?
3. Mengapa remote login `sys as sysdba` membutuhkan password file?
4. Apa fungsi `tnsnames.ora`?
5. Apa bedanya `tnsping alias` dan `sqlplus user/pass@alias`?
6. Mengapa session SQL masih bisa query setelah listener dimatikan?
7. Apa beda `CURRENT`, `ACTIVE`, `INACTIVE`, dan `UNUSED` pada redo log?
8. Mengapa database harus dalam kondisi `MOUNT` saat mengaktifkan ARCHIVELOG mode?
9. Apa fungsi `ALTER SYSTEM SWITCH LOGFILE`?
10. Apa risiko menghapus controlfile tanpa mengubah parameter `control_files`?

---

## 28. Jawaban Singkat Mini Latihan

1. `ORACLE_SID` menunjuk instance lokal, sedangkan `SERVICE_NAME` adalah nama layanan koneksi database/PDB melalui listener.
2. Karena memakai OS authentication dari user operating system yang berhak, biasanya user `oracle` dalam group DBA.
3. Karena koneksi remote tidak memakai OS authentication lokal, sehingga Oracle memvalidasi password SYSDBA melalui password file.
4. `tnsnames.ora` menyimpan alias koneksi agar user tidak perlu mengetik host, port, dan service name panjang.
5. `tnsping` hanya mengetes resolusi alias/koneksi listener, sedangkan `sqlplus` benar-benar login ke database.
6. Karena listener hanya menangani koneksi awal; setelah session terbentuk, komunikasi berjalan melalui server process.
7. `CURRENT` sedang ditulis LGWR, `ACTIVE` belum ditulis tetapi masih diperlukan recovery, `INACTIVE` sudah aman tidak diperlukan recovery, `UNUSED` belum pernah dipakai.
8. Karena perubahan mode archive log dilakukan saat database belum open.
9. Memaksa Oracle berpindah ke redo log group berikutnya.
10. Database bisa gagal startup karena Oracle mencari controlfile pada path yang sudah tidak ada.

---

## 29. Command Paling Penting untuk Dihafal

```bash
env | grep ORACLE
cat /etc/oratab
sqlplus / as sysdba
lsnrctl status
lsnrctl start
lsnrctl stop
lsnrctl status kuping
lsnrctl start kuping
lsnrctl stop kuping
tnsping pdbsatu
netca
netmgr
```

```sql
conn / as sysdba
SHOW CON_NAME;
ALTER SESSION SET CONTAINER = PDB1;
ALTER USER hr IDENTIFIED BY hr ACCOUNT UNLOCK;
GRANT CREATE SESSION TO hr;
SHOW PARAMETER control_files;
SELECT name FROM v$controlfile;
CREATE PFILE FROM SPFILE;
CREATE SPFILE FROM PFILE;
SHOW PARAMETER remote_login_passwordfile;
SHOW PARAMETER service_names;
SELECT name FROM v$services ORDER BY name;
SELECT group#, member FROM v$logfile;
SELECT group#, bytes/(1024*1024) MB FROM v$log;
SELECT group#, status FROM v$log;
ARCHIVE LOG LIST;
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;
ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM CHECKPOINT;
ALTER DATABASE ADD LOGFILE GROUP 4 SIZE 200M;
```

---

## 30. Catatan Keamanan Latihan

Beberapa command dalam materi bersifat berisiko jika dijalankan di database production:

```sql
SHUTDOWN ABORT;
```

```bash
rm controlfile
mv orapworadb orapwxxx
orapwd file=orapworadb password='password_baru' force=y
```

Gunakan hanya pada environment lab atau VM latihan.

Pada production:

- Jangan menghapus controlfile tanpa backup dan prosedur recovery resmi.
- Jangan mengganti password file tanpa koordinasi.
- Jangan mengubah port listener tanpa analisis dampak aplikasi.
- Jangan mengaktifkan perubahan besar tanpa maintenance window.
- Selalu backup file konfigurasi sebelum diedit.

Contoh backup sederhana:

```bash
cp listener.ora listener.ora.bak_$(date +%Y%m%d_%H%M%S)
cp tnsnames.ora tnsnames.ora.bak_$(date +%Y%m%d_%H%M%S)
cp sqlnet.ora sqlnet.ora.bak_$(date +%Y%m%d_%H%M%S)
```

---

Selesai.
