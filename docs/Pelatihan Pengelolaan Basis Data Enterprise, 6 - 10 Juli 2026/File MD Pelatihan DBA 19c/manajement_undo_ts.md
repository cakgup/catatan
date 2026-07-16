

---

# HANDS-ON LAB

# Manajemen UNDO Tablespace dan Datafile Oracle 19c

Asumsi:

```text
CDB  : ORADB
PDB  : PDB1
OS   : Oracle Linux
DB   : Oracle Database 19c
```

## 0. Persiapan Awal

Login sebagai user `oracle`.

```bash
su - oracle
```

Masuk ke SQL*Plus.

```bash
sqlplus / as sysdba
```

Verifikasi database.

```sql
SELECT name, cdb FROM v$database;
```

Contoh output:

```text
NAME      CDB
--------- ---
ORADB     YES
```

Verifikasi container aktif.

```sql
SHOW CON_NAME
```

Contoh output:

```text
CON_NAME
------------------------------
CDB$ROOT
```

Lihat daftar PDB.

```sql
SHOW PDBS
```

Contoh output:

```text
    CON_ID CON_NAME                       OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
         2 PDB$SEED                       READ ONLY  NO
         3 PDB1                           READ WRITE NO
```

Masuk ke PDB.

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

Verifikasi.

```sql
SHOW CON_NAME
```

Contoh output:

```text
CON_NAME
------------------------------
PDB1
```

---

# LAB 1 — Mengecek Local Undo pada CDB

## 1.1 Cek apakah database menggunakan local undo

```sql
CONN / AS SYSDBA

SELECT property_name, property_value
FROM database_properties
WHERE property_name = 'LOCAL_UNDO_ENABLED';
```

Contoh output:

```text
PROPERTY_NAME           PROPERTY_VALUE
----------------------- --------------
LOCAL_UNDO_ENABLED      TRUE
```

Jika hasilnya `TRUE`, maka setiap PDB dapat memiliki UNDO tablespace sendiri.

---

# LAB 2 — Melihat UNDO Tablespace Existing

## 2.1 Masuk ke PDB

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

## 2.2 Lihat tablespace bertipe UNDO

```sql
SET LINESIZE 200
COLUMN tablespace_name FORMAT A20
COLUMN contents FORMAT A12
COLUMN status FORMAT A10
COLUMN retention FORMAT A15

SELECT tablespace_name,
       contents,
       status,
       retention
FROM dba_tablespaces
WHERE contents = 'UNDO';
```

Contoh output:

```text
TABLESPACE_NAME      CONTENTS     STATUS     RETENTION
-------------------- ------------ ---------- ---------------
UNDOTBS1             UNDO         ONLINE     NOGUARANTEE
```

## 2.3 Lihat datafile UNDO

```sql
COLUMN file_name FORMAT A80
COLUMN tablespace_name FORMAT A20
COLUMN size_mb FORMAT 999999

SELECT tablespace_name,
       file_name,
       bytes/1024/1024 AS size_mb,
       autoextensible
FROM dba_data_files
WHERE tablespace_name IN (
    SELECT tablespace_name
    FROM dba_tablespaces
    WHERE contents = 'UNDO'
)
ORDER BY tablespace_name, file_name;
```

Contoh output:

```text
TABLESPACE_NAME      FILE_NAME                                                        SIZE_MB AUTOEXTENSIBLE
-------------------- ---------------------------------------------------------------- ------- --------------
UNDOTBS1             /u01/app/oracle/oradata/ORADB/pdb1/undotbs01.dbf                    100 YES
```

---

# LAB 3 — Mengecek Parameter UNDO

## 3.1 Cek undo_tablespace

```sql
SHOW PARAMETER undo_tablespace
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
undo_tablespace                      string      UNDOTBS1
```

## 3.2 Cek undo_retention

```sql
SHOW PARAMETER undo_retention
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
undo_retention                       integer     900
```

Artinya Oracle berusaha mempertahankan undo selama sekitar 900 detik.

---

# LAB 4 — Membuat UNDO Tablespace Baru

## 4.1 Buat UNDO tablespace baru

```sql
CREATE UNDO TABLESPACE UNDOTBS_LAB
DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/undotbs_lab01.dbf'
SIZE 100M
AUTOEXTEND OFF;
```

Contoh output:

```text
Tablespace created.
```

## 4.2 Verifikasi UNDO tablespace

```sql
SELECT tablespace_name,
       contents,
       status,
       retention
FROM dba_tablespaces
WHERE tablespace_name = 'UNDOTBS_LAB';
```

Contoh output:

```text
TABLESPACE_NAME      CONTENTS     STATUS     RETENTION
-------------------- ------------ ---------- ---------------
UNDOTBS_LAB          UNDO         ONLINE     NOGUARANTEE
```

## 4.3 Verifikasi datafile

```sql
SELECT tablespace_name,
       file_name,
       bytes/1024/1024 AS size_mb,
       autoextensible
FROM dba_data_files
WHERE tablespace_name = 'UNDOTBS_LAB';
```

Contoh output:

```text
TABLESPACE_NAME      FILE_NAME                                                     SIZE_MB AUTOEXTENSIBLE
-------------------- ------------------------------------------------------------- ------- --------------
UNDOTBS_LAB          /u01/app/oracle/oradata/ORADB/pdb1/undotbs_lab01.dbf              100 NO
```

---

# LAB 5 — Mengaktifkan UNDO Tablespace Baru

## 5.1 Ubah parameter undo_tablespace

```sql
ALTER SYSTEM SET undo_tablespace = UNDOTBS_LAB;
```

Contoh output:

```text
System altered.
```

## 5.2 Verifikasi parameter aktif

```sql
SHOW PARAMETER undo_tablespace
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
undo_tablespace                      string      UNDOTBS_LAB
```

## 5.3 Verifikasi semua UNDO tablespace

```sql
SELECT tablespace_name,
       contents,
       status
FROM dba_tablespaces
WHERE contents = 'UNDO'
ORDER BY tablespace_name;
```

Contoh output:

```text
TABLESPACE_NAME      CONTENTS     STATUS
-------------------- ------------ ----------
UNDOTBS1             UNDO         ONLINE
UNDOTBS_LAB          UNDO         ONLINE
```

Catatan: `UNDOTBS1` masih ada, tetapi UNDO aktif sudah berpindah ke `UNDOTBS_LAB`.

---

# LAB 6 — Menambah Datafile ke UNDO Tablespace

## 6.1 Tambahkan datafile kedua

```sql
ALTER TABLESPACE UNDOTBS_LAB
ADD DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/undotbs_lab02.dbf'
SIZE 50M
AUTOEXTEND OFF;
```

Contoh output:

```text
Tablespace altered.
```

## 6.2 Verifikasi datafile

```sql
SELECT tablespace_name,
       file_name,
       bytes/1024/1024 AS size_mb,
       autoextensible
FROM dba_data_files
WHERE tablespace_name = 'UNDOTBS_LAB'
ORDER BY file_name;
```

Contoh output:

```text
TABLESPACE_NAME      FILE_NAME                                                     SIZE_MB AUTOEXTENSIBLE
-------------------- ------------------------------------------------------------- ------- --------------
UNDOTBS_LAB          /u01/app/oracle/oradata/ORADB/pdb1/undotbs_lab01.dbf              100 NO
UNDOTBS_LAB          /u01/app/oracle/oradata/ORADB/pdb1/undotbs_lab02.dbf               50 NO
```

---

# LAB 7 — Resize Manual Datafile UNDO

## 7.1 Perbesar datafile pertama

```sql
ALTER DATABASE DATAFILE
'/u01/app/oracle/oradata/ORADB/pdb1/undotbs_lab01.dbf'
RESIZE 150M;
```

Contoh output:

```text
Database altered.
```

## 7.2 Verifikasi ukuran

```sql
SELECT file_name,
       bytes/1024/1024 AS size_mb
FROM dba_data_files
WHERE tablespace_name = 'UNDOTBS_LAB'
ORDER BY file_name;
```

Contoh output:

```text
FILE_NAME                                                     SIZE_MB
------------------------------------------------------------- -------
/u01/app/oracle/oradata/ORADB/pdb1/undotbs_lab01.dbf              150
/u01/app/oracle/oradata/ORADB/pdb1/undotbs_lab02.dbf               50
```

## 7.3 Perkecil datafile

```sql
ALTER DATABASE DATAFILE
'/u01/app/oracle/oradata/ORADB/pdb1/undotbs_lab01.dbf'
RESIZE 120M;
```

Contoh output jika berhasil:

```text
Database altered.
```

Contoh error jika masih ada extent UNDO di bagian akhir file:

```text
ORA-03297: file contains used data beyond requested RESIZE value
```

---

# LAB 8 — Mengaktifkan Autoextend pada UNDO Datafile

## 8.1 Aktifkan autoextend

```sql
ALTER DATABASE DATAFILE
'/u01/app/oracle/oradata/ORADB/pdb1/undotbs_lab01.dbf'
AUTOEXTEND ON
NEXT 10M
MAXSIZE 300M;
```

Contoh output:

```text
Database altered.
```

## 8.2 Verifikasi autoextend

```sql
SELECT file_name,
       bytes/1024/1024 AS size_mb,
       autoextensible,
       increment_by * 8 / 1024 AS next_mb,
       maxbytes/1024/1024 AS max_mb
FROM dba_data_files
WHERE file_name LIKE '%undotbs_lab01.dbf';
```

Contoh output:

```text
FILE_NAME                                                     SIZE_MB AUTOEXTENSIBLE NEXT_MB MAX_MB
------------------------------------------------------------- ------- -------------- ------- ------
/u01/app/oracle/oradata/ORADB/pdb1/undotbs_lab01.dbf              120 YES                 10    300
```

Catatan: perhitungan `increment_by * 8 / 1024` mengasumsikan block size 8 KB.

---

# LAB 9 — Menonaktifkan Autoextend

## 9.1 Matikan autoextend

```sql
ALTER DATABASE DATAFILE
'/u01/app/oracle/oradata/ORADB/pdb1/undotbs_lab01.dbf'
AUTOEXTEND OFF;
```

Contoh output:

```text
Database altered.
```

## 9.2 Verifikasi

```sql
SELECT file_name,
       bytes/1024/1024 AS size_mb,
       autoextensible
FROM dba_data_files
WHERE file_name LIKE '%undotbs_lab01.dbf';
```

Contoh output:

```text
FILE_NAME                                                     SIZE_MB AUTOEXTENSIBLE
------------------------------------------------------------- ------- --------------
/u01/app/oracle/oradata/ORADB/pdb1/undotbs_lab01.dbf              120 NO
```

---

# LAB 10 — Monitoring Penggunaan UNDO

## 10.1 Cek total ukuran UNDO

```sql
SELECT tablespace_name,
       SUM(bytes)/1024/1024 AS total_mb
FROM dba_data_files
WHERE tablespace_name = 'UNDOTBS_LAB'
GROUP BY tablespace_name;
```

Contoh output:

```text
TABLESPACE_NAME        TOTAL_MB
-------------------- ----------
UNDOTBS_LAB                 170
```

## 10.2 Cek free space UNDO

```sql
SELECT tablespace_name,
       SUM(bytes)/1024/1024 AS free_mb
FROM dba_free_space
WHERE tablespace_name = 'UNDOTBS_LAB'
GROUP BY tablespace_name;
```

Contoh output:

```text
TABLESPACE_NAME         FREE_MB
-------------------- ----------
UNDOTBS_LAB             168.875
```

## 10.3 Cek used percentage

```sql
SELECT df.tablespace_name,
       df.total_mb,
       NVL(fs.free_mb,0) AS free_mb,
       df.total_mb - NVL(fs.free_mb,0) AS used_mb,
       ROUND(((df.total_mb - NVL(fs.free_mb,0)) / df.total_mb) * 100, 2) AS used_pct
FROM (
    SELECT tablespace_name,
           SUM(bytes)/1024/1024 AS total_mb
    FROM dba_data_files
    GROUP BY tablespace_name
) df
LEFT JOIN (
    SELECT tablespace_name,
           SUM(bytes)/1024/1024 AS free_mb
    FROM dba_free_space
    GROUP BY tablespace_name
) fs
ON df.tablespace_name = fs.tablespace_name
WHERE df.tablespace_name = 'UNDOTBS_LAB';
```

Contoh output:

```text
TABLESPACE_NAME        TOTAL_MB    FREE_MB    USED_MB   USED_PCT
-------------------- ---------- ---------- ---------- ----------
UNDOTBS_LAB                 170    168.875      1.125        .66
```

---

# LAB 11 — Melihat Statistik UNDO

## 11.1 Query V$UNDOSTAT

```sql
COLUMN begin_time FORMAT A20
COLUMN end_time FORMAT A20

SELECT TO_CHAR(begin_time, 'YYYY-MM-DD HH24:MI:SS') AS begin_time,
       TO_CHAR(end_time, 'YYYY-MM-DD HH24:MI:SS') AS end_time,
       undoblks,
       txncount,
       maxquerylen
FROM v$undostat
ORDER BY begin_time DESC
FETCH FIRST 10 ROWS ONLY;
```

Contoh output:

```text
BEGIN_TIME           END_TIME               UNDOBLKS   TXNCOUNT MAXQUERYLEN
-------------------- -------------------- ---------- ---------- -----------
2026-07-03 10:50:22  2026-07-03 11:00:22          12         35           0
2026-07-03 10:40:22  2026-07-03 10:50:22           8         27           0
2026-07-03 10:30:22  2026-07-03 10:40:22          15         41           3
```

## 11.2 Cek penggunaan undo oleh session aktif

```sql
COLUMN username FORMAT A15
COLUMN status FORMAT A10

SELECT s.sid,
       s.serial#,
       s.username,
       t.used_ublk,
       t.used_urec,
       s.status
FROM v$transaction t
JOIN v$session s
ON t.ses_addr = s.saddr;
```

Contoh output jika tidak ada transaksi aktif:

```text
no rows selected
```

Contoh output jika ada transaksi aktif:

```text
       SID    SERIAL# USERNAME         USED_UBLK  USED_UREC STATUS
---------- ---------- --------------- ---------- ---------- ----------
        74      31892 APPUSER                 12        512 ACTIVE
```

---

# LAB 12 — Simulasi Penggunaan UNDO

## 12.1 Buat tablespace aplikasi kecil

```sql
CREATE TABLESPACE TS_UNDO_TEST
DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/ts_undo_test01.dbf'
SIZE 50M
AUTOEXTEND ON
NEXT 10M
MAXSIZE 200M;
```

Contoh output:

```text
Tablespace created.
```

## 12.2 Buat user testing

```sql
CREATE USER undouser IDENTIFIED BY oracle
DEFAULT TABLESPACE TS_UNDO_TEST
TEMPORARY TABLESPACE TEMP
QUOTA UNLIMITED ON TS_UNDO_TEST;
```

Contoh output:

```text
User created.
```

## 12.3 Grant privilege

```sql
GRANT CREATE SESSION, CREATE TABLE TO undouser;
```

Contoh output:

```text
Grant succeeded.
```

## 12.4 Login sebagai user testing

```sql
CONN undouser/oracle@localhost:1521/pdb1.localdomain
```

Contoh output:

```text
Connected.
```

## 12.5 Buat tabel besar

```sql
CREATE TABLE transaksi_undo AS
SELECT LEVEL AS id,
       RPAD('DATA UNDO TEST', 100, 'X') AS keterangan
FROM dual
CONNECT BY LEVEL <= 100000;
```

Contoh output:

```text
Table created.
```

## 12.6 Jalankan update tanpa commit

```sql
UPDATE transaksi_undo
SET keterangan = RPAD('DATA SUDAH DIUPDATE', 100, 'Y');
```

Contoh output:

```text
100000 rows updated.
```

Jangan lakukan `COMMIT` dulu.

---

# LAB 13 — Verifikasi Transaksi UNDO dari Session Lain

Buka terminal kedua, lalu masuk ke SQL*Plus.

```bash
sqlplus / as sysdba
```

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

## 13.1 Lihat transaksi aktif

```sql
COLUMN username FORMAT A15

SELECT s.sid,
       s.serial#,
       s.username,
       t.used_ublk,
       t.used_urec
FROM v$transaction t
JOIN v$session s
ON t.ses_addr = s.saddr
WHERE s.username = 'UNDOUSER';
```

Contoh output:

```text
       SID    SERIAL# USERNAME         USED_UBLK  USED_UREC
---------- ---------- --------------- ---------- ----------
        82      14521 UNDOUSER                382     100000
```

## 13.2 Lihat statistik undo terbaru

```sql
SELECT TO_CHAR(begin_time, 'YYYY-MM-DD HH24:MI:SS') AS begin_time,
       undoblks,
       txncount
FROM v$undostat
ORDER BY begin_time DESC
FETCH FIRST 5 ROWS ONLY;
```

Contoh output:

```text
BEGIN_TIME              UNDOBLKS   TXNCOUNT
-------------------- ---------- ----------
2026-07-03 11:10:22         395          8
2026-07-03 11:00:22          12         35
```

Kembali ke session `undouser`, lalu rollback.

```sql
ROLLBACK;
```

Contoh output:

```text
Rollback complete.
```

---

# LAB 14 — Mengubah UNDO Retention

## 14.1 Cek nilai saat ini

```sql
SHOW PARAMETER undo_retention
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
undo_retention                       integer     900
```

## 14.2 Ubah menjadi 1800 detik

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

ALTER SYSTEM SET undo_retention = 1800;
```

Contoh output:

```text
System altered.
```

## 14.3 Verifikasi

```sql
SHOW PARAMETER undo_retention
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
undo_retention                       integer     1800
```

---

# LAB 15 — Mengaktifkan RETENTION GUARANTEE

## 15.1 Aktifkan retention guarantee

```sql
ALTER TABLESPACE UNDOTBS_LAB RETENTION GUARANTEE;
```

Contoh output:

```text
Tablespace altered.
```

## 15.2 Verifikasi

```sql
SELECT tablespace_name,
       retention
FROM dba_tablespaces
WHERE tablespace_name = 'UNDOTBS_LAB';
```

Contoh output:

```text
TABLESPACE_NAME      RETENTION
-------------------- ---------------
UNDOTBS_LAB          GUARANTEE
```

Catatan: mode ini menjaga undo agar tidak cepat ditimpa, tetapi dapat menyebabkan DML gagal jika UNDO penuh.

## 15.3 Kembalikan ke NOGUARANTEE

```sql
ALTER TABLESPACE UNDOTBS_LAB RETENTION NOGUARANTEE;
```

Contoh output:

```text
Tablespace altered.
```

## 15.4 Verifikasi

```sql
SELECT tablespace_name,
       retention
FROM dba_tablespaces
WHERE tablespace_name = 'UNDOTBS_LAB';
```

Contoh output:

```text
TABLESPACE_NAME      RETENTION
-------------------- ---------------
UNDOTBS_LAB          NOGUARANTEE
```

---

# LAB 16 — Memindahkan Lokasi Datafile UNDO Secara Online

## 16.1 Buat folder tujuan di OS

Jalankan dari terminal Linux.

```bash
mkdir -p /u01/app/oracle/oradata/ORADB/pdb1/moved_undo
```

Verifikasi.

```bash
ls -ld /u01/app/oracle/oradata/ORADB/pdb1/moved_undo
```

Contoh output:

```text
drwxr-xr-x. 2 oracle oinstall 6 Jul  3 11:30 /u01/app/oracle/oradata/ORADB/pdb1/moved_undo
```

## 16.2 Jalankan move datafile

Masuk ke SQL*Plus.

```bash
sqlplus / as sysdba
```

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

Pindahkan datafile kedua.

```sql
ALTER DATABASE MOVE DATAFILE
'/u01/app/oracle/oradata/ORADB/pdb1/undotbs_lab02.dbf'
TO
'/u01/app/oracle/oradata/ORADB/pdb1/moved_undo/undotbs_lab02.dbf';
```

Contoh output:

```text
Database altered.
```

## 16.3 Verifikasi lokasi baru

```sql
SELECT tablespace_name,
       file_name
FROM dba_data_files
WHERE tablespace_name = 'UNDOTBS_LAB'
ORDER BY file_name;
```

Contoh output:

```text
TABLESPACE_NAME      FILE_NAME
-------------------- -------------------------------------------------------------
UNDOTBS_LAB          /u01/app/oracle/oradata/ORADB/pdb1/moved_undo/undotbs_lab02.dbf
UNDOTBS_LAB          /u01/app/oracle/oradata/ORADB/pdb1/undotbs_lab01.dbf
```

## 16.4 Verifikasi dari OS

```bash
ls -lh /u01/app/oracle/oradata/ORADB/pdb1/moved_undo/undotbs_lab02.dbf
```

Contoh output:

```text
-rw-r-----. 1 oracle oinstall 51M Jul  3 11:35 /u01/app/oracle/oradata/ORADB/pdb1/moved_undo/undotbs_lab02.dbf
```

---

# LAB 17 — Menghapus Datafile UNDO Kosong

Catatan: datafile UNDO hanya dapat dihapus jika kosong dan bukan satu-satunya datafile dalam tablespace.

## 17.1 Tambahkan datafile kosong

```sql
ALTER TABLESPACE UNDOTBS_LAB
ADD DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/undotbs_lab_empty.dbf'
SIZE 10M;
```

Contoh output:

```text
Tablespace altered.
```

## 17.2 Verifikasi datafile

```sql
SELECT file_name,
       bytes/1024/1024 AS size_mb
FROM dba_data_files
WHERE tablespace_name = 'UNDOTBS_LAB'
AND file_name LIKE '%empty%';
```

Contoh output:

```text
FILE_NAME                                                     SIZE_MB
------------------------------------------------------------- -------
/u01/app/oracle/oradata/ORADB/pdb1/undotbs_lab_empty.dbf            10
```

## 17.3 Drop datafile kosong

```sql
ALTER TABLESPACE UNDOTBS_LAB
DROP DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/undotbs_lab_empty.dbf';
```

Contoh output:

```text
Tablespace altered.
```

## 17.4 Verifikasi

```sql
SELECT file_name
FROM dba_data_files
WHERE tablespace_name = 'UNDOTBS_LAB'
AND file_name LIKE '%empty%';
```

Contoh output:

```text
no rows selected
```

---

# LAB 18 — Percobaan Drop UNDO Aktif

## 18.1 Coba drop UNDO aktif

```sql
DROP TABLESPACE UNDOTBS_LAB INCLUDING CONTENTS AND DATAFILES;
```

Contoh error:

```text
ORA-30013: undo tablespace 'UNDOTBS_LAB' is currently in use
```

Artinya UNDO aktif tidak boleh langsung dihapus.

---

# LAB 19 — Mengganti Kembali ke UNDOTBS1

## 19.1 Ubah undo_tablespace kembali ke UNDOTBS1

```sql
ALTER SYSTEM SET undo_tablespace = UNDOTBS1;
```

Contoh output:

```text
System altered.
```

## 19.2 Verifikasi

```sql
SHOW PARAMETER undo_tablespace
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
undo_tablespace                      string      UNDOTBS1
```

## 19.3 Pastikan tidak ada transaksi aktif memakai UNDOTBS_LAB

```sql
SELECT s.sid,
       s.serial#,
       s.username,
       t.used_ublk,
       t.used_urec
FROM v$transaction t
JOIN v$session s
ON t.ses_addr = s.saddr;
```

Contoh output:

```text
no rows selected
```

Jika masih ada transaksi aktif, lakukan `COMMIT` atau `ROLLBACK` dari session terkait.

---

# LAB 20 — Menghapus UNDO Tablespace Lama

## 20.1 Drop UNDOTBS_LAB

```sql
DROP TABLESPACE UNDOTBS_LAB INCLUDING CONTENTS AND DATAFILES;
```

Contoh output:

```text
Tablespace dropped.
```

## 20.2 Verifikasi tablespace sudah hilang

```sql
SELECT tablespace_name,
       contents
FROM dba_tablespaces
WHERE tablespace_name = 'UNDOTBS_LAB';
```

Contoh output:

```text
no rows selected
```

## 20.3 Verifikasi datafile sudah tidak tercatat

```sql
SELECT file_name
FROM dba_data_files
WHERE file_name LIKE '%undotbs_lab%';
```

Contoh output:

```text
no rows selected
```

---

# LAB 21 — Cleanup Object Testing

## 21.1 Drop user testing

```sql
DROP USER undouser CASCADE;
```

Contoh output:

```text
User dropped.
```

## 21.2 Drop tablespace testing

```sql
DROP TABLESPACE TS_UNDO_TEST INCLUDING CONTENTS AND DATAFILES;
```

Contoh output:

```text
Tablespace dropped.
```

## 21.3 Verifikasi cleanup

```sql
SELECT username
FROM dba_users
WHERE username = 'UNDOUSER';
```

Contoh output:

```text
no rows selected
```

```sql
SELECT tablespace_name
FROM dba_tablespaces
WHERE tablespace_name = 'TS_UNDO_TEST';
```

Contoh output:

```text
no rows selected
```

---

# Ringkasan Command Penting UNDO

Membuat UNDO tablespace:

```sql
CREATE UNDO TABLESPACE UNDOTBS_LAB
DATAFILE '/path/undotbs_lab01.dbf'
SIZE 100M;
```

Mengaktifkan UNDO tablespace:

```sql
ALTER SYSTEM SET undo_tablespace = UNDOTBS_LAB;
```

Menambah datafile:

```sql
ALTER TABLESPACE UNDOTBS_LAB
ADD DATAFILE '/path/undotbs_lab02.dbf'
SIZE 50M;
```

Resize manual:

```sql
ALTER DATABASE DATAFILE '/path/undotbs_lab01.dbf'
RESIZE 150M;
```

Autoextend ON:

```sql
ALTER DATABASE DATAFILE '/path/undotbs_lab01.dbf'
AUTOEXTEND ON NEXT 10M MAXSIZE 300M;
```

Autoextend OFF:

```sql
ALTER DATABASE DATAFILE '/path/undotbs_lab01.dbf'
AUTOEXTEND OFF;
```

Move datafile online:

```sql
ALTER DATABASE MOVE DATAFILE
'/path_lama/undotbs_lab02.dbf'
TO
'/path_baru/undotbs_lab02.dbf';
```

Retention guarantee:

```sql
ALTER TABLESPACE UNDOTBS_LAB RETENTION GUARANTEE;
```

Retention noguarantee:

```sql
ALTER TABLESPACE UNDOTBS_LAB RETENTION NOGUARANTEE;
```

Drop datafile kosong:

```sql
ALTER TABLESPACE UNDOTBS_LAB
DROP DATAFILE '/path/undotbs_lab_empty.dbf';
```

Drop UNDO tablespace tidak aktif:

```sql
DROP TABLESPACE UNDOTBS_LAB INCLUDING CONTENTS AND DATAFILES;
```

---

# Catatan Penting

Di Oracle 19c Multitenant, praktik yang disarankan adalah membuat dan mengelola UNDO pada level **PDB** jika `LOCAL_UNDO_ENABLED = TRUE`. Jangan menghapus UNDO tablespace yang sedang aktif. Selalu pindahkan dulu parameter `undo_tablespace` ke UNDO lain, pastikan tidak ada transaksi aktif, baru lakukan `DROP TABLESPACE`.
