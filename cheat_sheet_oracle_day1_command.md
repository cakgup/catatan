# Cheat Sheet Command Oracle Day 1

Ringkasan command Oracle Day 1 ini disusun secara berurutan untuk memudahkan latihan. Fokus materi meliputi arsitektur Oracle, startup/shutdown database, parameter file, SQL vs SQL\*Plus, listener, dan file penting Oracle.

---

## 1. Masuk ke SQL\*Plus sebagai SYSDBA

| Command | Fungsi |
|---|---|
| `sqlplus / as sysdba` | Masuk ke SQL\*Plus sebagai administrator database tanpa memasukkan password, biasanya dari server Oracle langsung. |
| `CONNECT / AS SYSDBA` | Menghubungkan ulang session SQL\*Plus sebagai SYSDBA. |

```sql
sqlplus / as sysdba
```

```sql
CONNECT / AS SYSDBA
```

---

## 2. Melihat Status Instance dan Database

| Command | Fungsi |
|---|---|
| `SELECT status FROM v$instance;` | Melihat status instance Oracle, misalnya `STARTED`, `MOUNTED`, atau `OPEN`. |
| `SELECT name, open_mode FROM v$database;` | Melihat nama database dan mode database, misalnya `READ WRITE`, `MOUNTED`, atau `READ ONLY`. |

```sql
SELECT status FROM v$instance;
```

```sql
SELECT name, open_mode FROM v$database;
```

---

## 3. Startup Database

Urutan startup Oracle:

```text
NOMOUNT → MOUNT → OPEN
```

| Command | Fungsi |
|---|---|
| `STARTUP NOMOUNT;` | Menyalakan instance saja. Oracle membaca parameter file, membuat SGA, dan menjalankan background process. Controlfile belum dibuka. |
| `ALTER DATABASE MOUNT;` | Membuka controlfile. Database sudah mengetahui lokasi datafile dan redo log, tetapi belum bisa digunakan user umum. |
| `ALTER DATABASE OPEN;` | Membuka datafile dan redo log sehingga database siap digunakan. |
| `STARTUP;` | Menjalankan startup langsung sampai tahap `OPEN`. |

```sql
STARTUP NOMOUNT;
```

```sql
ALTER DATABASE MOUNT;
```

```sql
ALTER DATABASE OPEN;
```

Atau langsung:

```sql
STARTUP;
```

---

## 4. Shutdown Database

| Command | Fungsi |
|---|---|
| `SHUTDOWN NORMAL;` | Mematikan database secara normal. Oracle menunggu semua user logout terlebih dahulu. |
| `SHUTDOWN TRANSACTIONAL;` | Mematikan database setelah transaksi aktif selesai. Tidak menerima transaksi baru. |
| `SHUTDOWN IMMEDIATE;` | Mematikan database segera. Session aktif dihentikan, transaksi yang belum commit akan di-rollback otomatis. Ini paling sering dipakai. |
| `SHUTDOWN ABORT;` | Mematikan database secara paksa. Tidak melakukan checkpoint normal. Saat startup berikutnya Oracle melakukan instance recovery. |

```sql
SHUTDOWN NORMAL;
```

```sql
SHUTDOWN TRANSACTIONAL;
```

```sql
SHUTDOWN IMMEDIATE;
```

```sql
SHUTDOWN ABORT;
```

Command yang paling umum dipakai DBA:

```sql
SHUTDOWN IMMEDIATE;
```

---

## 5. Melakukan Checkpoint Manual

| Command | Fungsi |
|---|---|
| `ALTER SYSTEM CHECKPOINT;` | Meminta Oracle melakukan checkpoint, yaitu memastikan perubahan di buffer cache ditulis ke datafile oleh DBWn. |

```sql
ALTER SYSTEM CHECKPOINT;
```

Catatan penting:

- Yang menulis ke datafile adalah **DBWn**, bukan CKPT.
- CKPT memberi sinyal ke DBWn dan memperbarui informasi checkpoint pada controlfile dan datafile header.

---

## 6. Melihat Parameter Database

| Command | Fungsi |
|---|---|
| `SHOW PARAMETER` | Menampilkan seluruh parameter database. |
| `SHOW PARAMETER sga;` | Melihat parameter terkait SGA, yaitu shared memory Oracle. |
| `SHOW PARAMETER pga;` | Melihat parameter terkait PGA, yaitu memory private server process. |
| `SHOW PARAMETER processes;` | Melihat batas maksimum jumlah process Oracle. |
| `SHOW PARAMETER spfile;` | Melihat apakah database sedang menggunakan SPFILE dan lokasi file-nya. |

```sql
SHOW PARAMETER
```

```sql
SHOW PARAMETER sga;
```

```sql
SHOW PARAMETER pga;
```

```sql
SHOW PARAMETER processes;
```

```sql
SHOW PARAMETER spfile;
```

---

## 7. Membuat PFILE dari SPFILE

| Command | Fungsi |
|---|---|
| `CREATE PFILE FROM SPFILE;` | Membuat file parameter berbentuk teks dari SPFILE. PFILE bisa dibaca dan diedit manual. |

```sql
CREATE PFILE FROM SPFILE;
```

Biasanya digunakan jika ingin melihat atau mengedit parameter database secara manual.

---

## 8. Membuat SPFILE dari PFILE

| Command | Fungsi |
|---|---|
| `CREATE SPFILE FROM PFILE;` | Membuat SPFILE baru dari PFILE. SPFILE adalah parameter file dalam format binary yang biasa digunakan Oracle saat startup. |

```sql
CREATE SPFILE FROM PFILE;
```

Catatan:

Command ini dijalankan di SQL\*Plus sebagai SYSDBA.

---

## 9. Mengubah Parameter Database

| Command | Fungsi |
|---|---|
| `ALTER SYSTEM SET nama_parameter = nilai SCOPE=MEMORY;` | Mengubah parameter hanya di memory. Efeknya langsung berlaku, tetapi hilang setelah database restart. |
| `ALTER SYSTEM SET nama_parameter = nilai SCOPE=SPFILE;` | Mengubah parameter di SPFILE. Efeknya berlaku setelah database restart. |
| `ALTER SYSTEM SET nama_parameter = nilai SCOPE=BOTH;` | Mengubah parameter di memory dan SPFILE sekaligus, jika parameter tersebut mendukung perubahan dinamis. |

```sql
ALTER SYSTEM SET nama_parameter = nilai SCOPE=MEMORY;
```

```sql
ALTER SYSTEM SET nama_parameter = nilai SCOPE=SPFILE;
```

```sql
ALTER SYSTEM SET nama_parameter = nilai SCOPE=BOTH;
```

Contoh:

```sql
ALTER SYSTEM SET processes=400 SCOPE=SPFILE;
```

Fungsi command di atas:

Mengubah jumlah maksimum process Oracle menjadi 400, tetapi baru berlaku setelah database restart.

Restart database:

```sql
SHUTDOWN IMMEDIATE;
STARTUP;
```

| Command | Fungsi |
|---|---|
| `SHUTDOWN IMMEDIATE;` | Mematikan database dengan aman dan cepat. |
| `STARTUP;` | Menyalakan database kembali sampai mode `OPEN`. |

---

## 10. Command SQL Dasar

### SELECT

| Command | Fungsi |
|---|---|
| `SELECT * FROM nama_tabel;` | Menampilkan seluruh data dari tabel. |

```sql
SELECT * FROM nama_tabel;
```

Contoh:

```sql
SELECT * FROM regions;
```

Fungsi:

Menampilkan semua data dari tabel `regions`.

### INSERT

| Command | Fungsi |
|---|---|
| `INSERT INTO ... VALUES ...;` | Menambahkan data baru ke dalam tabel. |

```sql
INSERT INTO nama_tabel (kolom1, kolom2)
VALUES (nilai1, nilai2);
```

### UPDATE

| Command | Fungsi |
|---|---|
| `UPDATE ... SET ... WHERE ...;` | Mengubah data yang sudah ada di tabel berdasarkan kondisi tertentu. |

```sql
UPDATE nama_tabel
SET kolom = nilai
WHERE kondisi;
```

### DELETE

| Command | Fungsi |
|---|---|
| `DELETE FROM ... WHERE ...;` | Menghapus data dari tabel berdasarkan kondisi tertentu. |

```sql
DELETE FROM nama_tabel
WHERE kondisi;
```

Catatan:

Hati-hati jika tidak memakai `WHERE`, karena semua data di tabel bisa terhapus.

### CREATE TABLE

| Command | Fungsi |
|---|---|
| `CREATE TABLE ...` | Membuat tabel baru. |

```sql
CREATE TABLE nama_tabel (
  id NUMBER,
  nama VARCHAR2(100)
);
```

### ALTER TABLE

| Command | Fungsi |
|---|---|
| `ALTER TABLE ... ADD ...` | Mengubah struktur tabel, misalnya menambah kolom baru. |

```sql
ALTER TABLE nama_tabel ADD kolom_baru VARCHAR2(50);
```

### DROP TABLE

| Command | Fungsi |
|---|---|
| `DROP TABLE ...` | Menghapus tabel dari database. |

```sql
DROP TABLE nama_tabel;
```

Catatan:

Command ini menghapus struktur tabel dan datanya.

---

## 11. Command SQL\*Plus Dasar

| Command | Fungsi |
|---|---|
| `SHOW USER;` | Melihat user/schema yang sedang aktif. |
| `CONNECT username/password;` | Login ke user database tertentu. |
| `CONNECT hr/hr;` | Login ke user HR dengan password HR. |
| `CONNECT hr/hr@orclpdb;` | Login ke user HR pada service/PDB tertentu. |
| `EXIT;` | Keluar dari SQL\*Plus. |
| `SET LINESIZE 200;` | Mengatur lebar tampilan output agar tidak mudah terpotong. |
| `SET PAGESIZE 100;` | Mengatur jumlah baris per halaman output. |
| `SPOOL hasil.txt;` | Menyimpan output SQL\*Plus ke file. |
| `SPOOL OFF;` | Menghentikan penyimpanan output ke file. |
| `HOST ls` | Menjalankan command Linux dari dalam SQL\*Plus. |
| `HOST dir` | Menjalankan command Windows dari dalam SQL\*Plus. |

Contoh:

```sql
SHOW USER;
```

```sql
CONNECT hr/hr;
```

```sql
CONNECT hr/hr@orclpdb;
```

```sql
EXIT;
```

```sql
SET LINESIZE 200;
```

```sql
SET PAGESIZE 100;
```

```sql
SPOOL hasil.txt;
SELECT * FROM regions;
SPOOL OFF;
```

```sql
HOST ls
```

Untuk Windows:

```sql
HOST dir
```

---

## 12. Bind Variable untuk Mengurangi Hard Parse

Kurang baik:

```sql
SELECT *
FROM emp
WHERE empno = 100;
```

```sql
SELECT *
FROM emp
WHERE empno = 101;
```

Fungsi:

SQL di atas dianggap berbeda oleh Oracle karena nilainya berubah, sehingga berpotensi menyebabkan hard parse berulang.

Lebih baik:

```sql
SELECT *
FROM emp
WHERE empno = :empno;
```

Fungsi:

Menggunakan bind variable agar bentuk SQL tetap sama. Ini membantu Oracle menggunakan ulang parsed SQL dan execution plan di Shared Pool.

---

## 13. Listener Command

Command ini dijalankan dari terminal Linux/Windows, bukan dari SQL biasa.

| Command | Fungsi |
|---|---|
| `lsnrctl status` | Melihat status listener, port, service yang terdaftar, dan lokasi listener log. |
| `lsnrctl start` | Menjalankan listener. |
| `lsnrctl stop` | Menghentikan listener. |
| `lsnrctl reload` | Membaca ulang konfigurasi listener tanpa mematikan listener. |

```bash
lsnrctl status
```

```bash
lsnrctl start
```

```bash
lsnrctl stop
```

```bash
lsnrctl reload
```

Catatan:

Listener menerima request koneksi dari client, biasanya melalui port default:

```text
1521
```

---

## 14. Mengecek File Network Oracle

File network utama:

```text
listener.ora
tnsnames.ora
sqlnet.ora
```

| File | Fungsi |
|---|---|
| `listener.ora` | Konfigurasi listener Oracle. |
| `tnsnames.ora` | Daftar alias koneksi database dari sisi client/server. |
| `sqlnet.ora` | Konfigurasi tambahan network Oracle, misalnya autentikasi dan naming method. |

Lokasi umum:

```bash
$ORACLE_HOME/network/admin
```

| Command | Fungsi |
|---|---|
| `echo $ORACLE_HOME` | Melihat lokasi Oracle Home yang sedang aktif. |
| `cd $ORACLE_HOME/network/admin` | Masuk ke folder konfigurasi network Oracle. |

```bash
echo $ORACLE_HOME
```

```bash
cd $ORACLE_HOME/network/admin
```

---

## 15. Mengecek Lokasi Oracle Base dan Oracle Home

| Command | Fungsi |
|---|---|
| `echo $ORACLE_BASE` | Melihat lokasi dasar instalasi Oracle. |
| `echo $ORACLE_HOME` | Melihat lokasi software Oracle Database. |

```bash
echo $ORACLE_BASE
```

```bash
echo $ORACLE_HOME
```

Contoh struktur umum:

```bash
/u01/app/oracle
```

```bash
/u01/app/oracle/product/19c/dbhome_1
```

| Lokasi | Fungsi |
|---|---|
| `/u01/app/oracle` | Biasanya menjadi `ORACLE_BASE`. |
| `/u01/app/oracle/product/19c/dbhome_1` | Biasanya menjadi `ORACLE_HOME`. |

---

## 16. Melihat Alert Log dan Diagnostic File

| Command | Fungsi |
|---|---|
| `cd $ORACLE_BASE/diag` | Masuk ke direktori diagnostic Oracle. |
| `tail -f alert.log` | Membaca alert log secara real-time. |

```bash
cd $ORACLE_BASE/diag
```

```bash
tail -f alert.log
```

Catatan:

`alert.log` berisi informasi penting seperti startup, shutdown, error ORA, checkpoint, archivelog, dan masalah database lainnya.

---

# Urutan Latihan Command yang Disarankan

Bagian ini dapat digunakan sebagai alur praktik belajar Oracle Day 1.

## A. Login sebagai SYSDBA

```sql
sqlplus / as sysdba
```

Fungsi:

Masuk ke database sebagai administrator.

## B. Cek Status Instance

```sql
SELECT status FROM v$instance;
```

Fungsi:

Mengetahui apakah instance masih `STARTED`, `MOUNTED`, atau sudah `OPEN`.

## C. Cek Status Database

```sql
SELECT name, open_mode FROM v$database;
```

Fungsi:

Melihat nama database dan apakah database sudah bisa digunakan.

## D. Shutdown Database

```sql
SHUTDOWN IMMEDIATE;
```

Fungsi:

Mematikan database dengan aman dan cepat.

## E. Startup Bertahap

```sql
STARTUP NOMOUNT;
```

Fungsi:

Menyalakan instance saja.

```sql
ALTER DATABASE MOUNT;
```

Fungsi:

Membuka controlfile.

```sql
ALTER DATABASE OPEN;
```

Fungsi:

Membuka database agar bisa digunakan.

## F. Cek Parameter File

```sql
SHOW PARAMETER spfile;
```

Fungsi:

Melihat apakah database menggunakan SPFILE.

## G. Buat PFILE dari SPFILE

```sql
CREATE PFILE FROM SPFILE;
```

Fungsi:

Membuat parameter file berbentuk teks dari SPFILE.

## H. Buat SPFILE dari PFILE

```sql
CREATE SPFILE FROM PFILE;
```

Fungsi:

Membuat ulang SPFILE dari PFILE.

## I. Cek User Aktif

```sql
SHOW USER;
```

Fungsi:

Melihat sedang login sebagai user apa.

## J. Login ke User HR

```sql
CONNECT hr/hr@orclpdb;
```

Fungsi:

Login ke schema HR pada PDB/service tertentu.

## K. Query Tabel

```sql
SELECT * FROM regions;
```

Fungsi:

Menampilkan isi tabel `regions`.

## L. Keluar dari SQL\*Plus

```sql
EXIT;
```

Fungsi:

Menutup session SQL\*Plus.

## M. Cek Listener dari Terminal

```bash
lsnrctl status
```

Fungsi:

Melihat apakah listener aktif dan service database sudah terdaftar.

```bash
lsnrctl start
```

Fungsi:

Menjalankan listener.

```bash
lsnrctl stop
```

Fungsi:

Menghentikan listener.

```bash
lsnrctl reload
```

Fungsi:

Membaca ulang konfigurasi listener.

---

# Versi Super Ringkas untuk Dihafal

| Urutan | Command | Fungsi Singkat |
|---:|---|---|
| 1 | `sqlplus / as sysdba` | Login sebagai DBA. |
| 2 | `SELECT status FROM v$instance;` | Cek status instance. |
| 3 | `SELECT name, open_mode FROM v$database;` | Cek status database. |
| 4 | `SHUTDOWN IMMEDIATE;` | Matikan database dengan aman. |
| 5 | `STARTUP NOMOUNT;` | Nyalakan instance. |
| 6 | `ALTER DATABASE MOUNT;` | Baca controlfile. |
| 7 | `ALTER DATABASE OPEN;` | Buka database. |
| 8 | `SHOW PARAMETER spfile;` | Cek SPFILE. |
| 9 | `CREATE PFILE FROM SPFILE;` | Buat PFILE dari SPFILE. |
| 10 | `CREATE SPFILE FROM PFILE;` | Buat SPFILE dari PFILE. |
| 11 | `SHOW USER;` | Cek user aktif. |
| 12 | `CONNECT hr/hr@orclpdb;` | Login ke HR. |
| 13 | `SELECT * FROM regions;` | Query tabel. |
| 14 | `EXIT;` | Keluar SQL\*Plus. |
| 15 | `lsnrctl status` | Cek listener. |
| 16 | `lsnrctl start` | Jalankan listener. |
| 17 | `lsnrctl stop` | Hentikan listener. |
| 18 | `lsnrctl reload` | Reload konfigurasi listener. |
