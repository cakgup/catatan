# HANDS-ON LAB

# Manajemen Tablespace dan Datafile Oracle 19c

---

Asumsi environment:

```sql
CDB  : ORADB
PDB  : PDB1
OS   : Oracle Linux
User : oracle
DB   : Oracle Database 19c
```

---



## 0. Persiapan Environment

Login sebagai user `oracle`.

```bash
su - oracle
```

Masuk ke SQL*Plus.

```bash
sqlplus / as sysdba
```

Verifikasi nama database.

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

# LAB 1 — Melihat Tablespace dan Datafile Existing

## 1.1 Melihat daftar tablespace

```sql
SET LINESIZE 200
COLUMN tablespace_name FORMAT A20
COLUMN status FORMAT A10
COLUMN contents FORMAT A12
COLUMN extent_management FORMAT A18
COLUMN segment_space_management FORMAT A25

SELECT tablespace_name,
       status,
       contents,
       extent_management,
       segment_space_management
FROM dba_tablespaces
ORDER BY tablespace_name;
```

Contoh output:

```text
TABLESPACE_NAME      STATUS     CONTENTS     EXTENT_MANAGEMENT  SEGMENT_SPACE_MANAGEMENT
-------------------- ---------- ------------ ------------------ -------------------------
SYSAUX               ONLINE     PERMANENT    LOCAL              AUTO
SYSTEM               ONLINE     PERMANENT    LOCAL              MANUAL
TEMP                 ONLINE     TEMPORARY    LOCAL              MANUAL
UNDOTBS1             ONLINE     UNDO         LOCAL              MANUAL
USERS                ONLINE     PERMANENT    LOCAL              AUTO
```

## 1.2 Melihat datafile

```sql
COLUMN file_name FORMAT A80
COLUMN tablespace_name FORMAT A20
COLUMN size_mb FORMAT 999999

SELECT tablespace_name,
       file_name,
       bytes/1024/1024 AS size_mb,
       autoextensible
FROM dba_data_files
ORDER BY tablespace_name, file_name;
```

Contoh output:

```text
TABLESPACE_NAME      FILE_NAME                                                        SIZE_MB AUTOEXTENSIBLE
-------------------- ---------------------------------------------------------------- ------- --------------
SYSAUX               /u01/app/oracle/oradata/ORADB/pdb1/sysaux01.dbf                     600 YES
SYSTEM               /u01/app/oracle/oradata/ORADB/pdb1/system01.dbf                     270 YES
UNDOTBS1             /u01/app/oracle/oradata/ORADB/pdb1/undotbs01.dbf                    100 YES
USERS                /u01/app/oracle/oradata/ORADB/pdb1/users01.dbf                        5 YES
```

---

# LAB 2 — Membuat Permanent Tablespace

## 2.1 Buat tablespace baru

```sql
CREATE TABLESPACE TS_APPDATA
DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/ts_appdata01.dbf'
SIZE 100M
AUTOEXTEND OFF
EXTENT MANAGEMENT LOCAL
SEGMENT SPACE MANAGEMENT AUTO;
```

Contoh output:

```text
Tablespace created.
```

## 2.2 Verifikasi tablespace

```sql
SELECT tablespace_name,
       status,
       contents,
       extent_management,
       segment_space_management
FROM dba_tablespaces
WHERE tablespace_name = 'TS_APPDATA';
```

Contoh output:

```text
TABLESPACE_NAME      STATUS     CONTENTS     EXTENT_MANAGEMENT  SEGMENT_SPACE_MANAGEMENT
-------------------- ---------- ------------ ------------------ -------------------------
TS_APPDATA           ONLINE     PERMANENT    LOCAL              AUTO
```

## 2.3 Verifikasi datafile

```sql
SELECT tablespace_name,
       file_name,
       bytes/1024/1024 AS size_mb,
       autoextensible
FROM dba_data_files
WHERE tablespace_name = 'TS_APPDATA';
```

Contoh output:

```text
TABLESPACE_NAME      FILE_NAME                                                     SIZE_MB AUTOEXTENSIBLE
-------------------- ------------------------------------------------------------- ------- --------------
TS_APPDATA           /u01/app/oracle/oradata/ORADB/pdb1/ts_appdata01.dbf               100 NO
```

---

# LAB 3 — Membuat User dan Object di Tablespace

## 3.1 Buat user aplikasi

```sql
CREATE USER appuser IDENTIFIED BY oracle
DEFAULT TABLESPACE TS_APPDATA
TEMPORARY TABLESPACE TEMP
QUOTA UNLIMITED ON TS_APPDATA;
```

Contoh output:

```text
User created.
```

## 3.2 Berikan privilege

```sql
GRANT CREATE SESSION, CREATE TABLE TO appuser;
```

Contoh output:

```text
Grant succeeded.
```

## 3.3 Buat tabel testing

```sql
CONN appuser/oracle@localhost:1521/pdb1.localdomain

CREATE TABLE transaksi_lab (
    id           NUMBER,
    nama_data    VARCHAR2(100),
    tanggal_input DATE DEFAULT SYSDATE
);
```

Contoh output:

```text
Table created.
```

## 3.4 Insert data testing

```sql
INSERT INTO transaksi_lab (id, nama_data)
SELECT LEVEL, 'DATA KE-' || LEVEL
FROM dual
CONNECT BY LEVEL <= 1000;

COMMIT;
```

Contoh output:

```text
1000 rows created.

Commit complete.
```

## 3.5 Verifikasi segment tabel

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

COLUMN owner FORMAT A15
COLUMN segment_name FORMAT A25
COLUMN tablespace_name FORMAT A20

SELECT owner,
       segment_name,
       segment_type,
       tablespace_name,
       bytes/1024/1024 AS size_mb
FROM dba_segments
WHERE owner = 'APPUSER'
AND segment_name = 'TRANSAKSI_LAB';
```

Contoh output:

```text
OWNER           SEGMENT_NAME              SEGMENT_TYPE       TABLESPACE_NAME       SIZE_MB
--------------- ------------------------- ------------------ -------------------- -------
APPUSER         TRANSAKSI_LAB             TABLE              TS_APPDATA                 .1
```

---

# LAB 4 — Menambah Datafile ke Tablespace

## 4.1 Tambahkan datafile kedua

```sql
ALTER TABLESPACE TS_APPDATA
ADD DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/ts_appdata02.dbf'
SIZE 50M
AUTOEXTEND OFF;
```

Contoh output:

```text
Tablespace altered.
```

## 4.2 Verifikasi jumlah datafile

```sql
SELECT tablespace_name,
       file_name,
       bytes/1024/1024 AS size_mb,
       autoextensible
FROM dba_data_files
WHERE tablespace_name = 'TS_APPDATA'
ORDER BY file_name;
```

Contoh output:

```text
TABLESPACE_NAME      FILE_NAME                                                     SIZE_MB AUTOEXTENSIBLE
-------------------- ------------------------------------------------------------- ------- --------------
TS_APPDATA           /u01/app/oracle/oradata/ORADB/pdb1/ts_appdata01.dbf               100 NO
TS_APPDATA           /u01/app/oracle/oradata/ORADB/pdb1/ts_appdata02.dbf                50 NO
```

---

# LAB 5 — Resize Manual Datafile

## 5.1 Perbesar datafile pertama

```sql
ALTER DATABASE DATAFILE
'/u01/app/oracle/oradata/ORADB/pdb1/ts_appdata01.dbf'
RESIZE 150M;
```

Contoh output:

```text
Database altered.
```

## 5.2 Verifikasi ukuran datafile

```sql
SELECT file_name,
       bytes/1024/1024 AS size_mb
FROM dba_data_files
WHERE tablespace_name = 'TS_APPDATA'
ORDER BY file_name;
```

Contoh output:

```text
FILE_NAME                                                     SIZE_MB
------------------------------------------------------------- -------
/u01/app/oracle/oradata/ORADB/pdb1/ts_appdata01.dbf               150
/u01/app/oracle/oradata/ORADB/pdb1/ts_appdata02.dbf                50
```

## 5.3 Coba perkecil datafile

```sql
ALTER DATABASE DATAFILE
'/u01/app/oracle/oradata/ORADB/pdb1/ts_appdata01.dbf'
RESIZE 120M;
```

Contoh output jika masih aman:

```text
Database altered.
```

Jika tidak bisa karena ada data di bagian akhir file, contoh error:

```text
ORA-03297: file contains used data beyond requested RESIZE value
```

---

# LAB 6 — Mengaktifkan Autoextend

## 6.1 Aktifkan autoextend pada datafile

```sql
ALTER DATABASE DATAFILE
'/u01/app/oracle/oradata/ORADB/pdb1/ts_appdata01.dbf'
AUTOEXTEND ON
NEXT 10M
MAXSIZE 300M;
```

Contoh output:

```text
Database altered.
```

## 6.2 Verifikasi autoextend

```sql
SELECT file_name,
       bytes/1024/1024 AS size_mb,
       autoextensible,
       increment_by * 8 / 1024 AS next_mb,
       maxbytes/1024/1024 AS max_mb
FROM dba_data_files
WHERE file_name LIKE '%ts_appdata01.dbf';
```

Contoh output:

```text
FILE_NAME                                                     SIZE_MB AUTOEXTENSIBLE NEXT_MB MAX_MB
------------------------------------------------------------- ------- -------------- ------- ------
/u01/app/oracle/oradata/ORADB/pdb1/ts_appdata01.dbf               120 YES                 10    300
```

Catatan: angka `increment_by * 8 / 1024` mengasumsikan block size 8 KB.

---

# LAB 7 — Menonaktifkan Autoextend

## 7.1 Matikan autoextend

```sql
ALTER DATABASE DATAFILE
'/u01/app/oracle/oradata/ORADB/pdb1/ts_appdata01.dbf'
AUTOEXTEND OFF;
```

Contoh output:

```text
Database altered.
```

## 7.2 Verifikasi

```sql
SELECT file_name,
       bytes/1024/1024 AS size_mb,
       autoextensible
FROM dba_data_files
WHERE file_name LIKE '%ts_appdata01.dbf';
```

Contoh output:

```text
FILE_NAME                                                     SIZE_MB AUTOEXTENSIBLE
------------------------------------------------------------- ------- --------------
/u01/app/oracle/oradata/ORADB/pdb1/ts_appdata01.dbf               120 NO
```

---

# LAB 8 — Monitoring Kapasitas Tablespace

## 8.1 Cek total ukuran tablespace

```sql
SELECT tablespace_name,
       SUM(bytes)/1024/1024 AS total_mb
FROM dba_data_files
WHERE tablespace_name = 'TS_APPDATA'
GROUP BY tablespace_name;
```

Contoh output:

```text
TABLESPACE_NAME        TOTAL_MB
-------------------- ----------
TS_APPDATA                  170
```

## 8.2 Cek free space

```sql
SELECT tablespace_name,
       SUM(bytes)/1024/1024 AS free_mb
FROM dba_free_space
WHERE tablespace_name = 'TS_APPDATA'
GROUP BY tablespace_name;
```

Contoh output:

```text
TABLESPACE_NAME         FREE_MB
-------------------- ----------
TS_APPDATA              168.875
```

## 8.3 Cek used space

```sql
SELECT df.tablespace_name,
       df.total_mb,
       fs.free_mb,
       df.total_mb - fs.free_mb AS used_mb,
       ROUND(((df.total_mb - fs.free_mb) / df.total_mb) * 100, 2) AS used_pct
FROM (
    SELECT tablespace_name,
           SUM(bytes)/1024/1024 AS total_mb
    FROM dba_data_files
    GROUP BY tablespace_name
) df
JOIN (
    SELECT tablespace_name,
           SUM(bytes)/1024/1024 AS free_mb
    FROM dba_free_space
    GROUP BY tablespace_name
) fs
ON df.tablespace_name = fs.tablespace_name
WHERE df.tablespace_name = 'TS_APPDATA';
```

Contoh output:

```text
TABLESPACE_NAME        TOTAL_MB    FREE_MB    USED_MB   USED_PCT
-------------------- ---------- ---------- ---------- ----------
TS_APPDATA                  170    168.875      1.125        .66
```

---

# LAB 9 — Membuat Tablespace Read Only dan Read Write

## 9.1 Ubah tablespace menjadi read only

```sql
ALTER TABLESPACE TS_APPDATA READ ONLY;
```

Contoh output:

```text
Tablespace altered.
```

## 9.2 Verifikasi status

```sql
SELECT tablespace_name,
       status
FROM dba_tablespaces
WHERE tablespace_name = 'TS_APPDATA';
```

Contoh output:

```text
TABLESPACE_NAME      STATUS
-------------------- ----------
TS_APPDATA           READ ONLY
```

## 9.3 Coba insert data

```sql
CONN appuser/oracle@localhost:1521/pdb1.localdomain

INSERT INTO transaksi_lab (id, nama_data)
VALUES (1001, 'TEST READ ONLY');
```

Contoh error:

```text
ORA-01647: tablespace 'TS_APPDATA' is read-only, cannot allocate space in it
```

## 9.4 Kembalikan ke read write

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

ALTER TABLESPACE TS_APPDATA READ WRITE;
```

Contoh output:

```text
Tablespace altered.
```

## 9.5 Verifikasi

```sql
SELECT tablespace_name,
       status
FROM dba_tablespaces
WHERE tablespace_name = 'TS_APPDATA';
```

Contoh output:

```text
TABLESPACE_NAME      STATUS
-------------------- ----------
TS_APPDATA           ONLINE
```

---

# LAB 10 — Membuat Tablespace Offline dan Online

## 10.1 Ubah tablespace menjadi offline

```sql
ALTER TABLESPACE TS_APPDATA OFFLINE;
```

Contoh output:

```text
Tablespace altered.
```

## 10.2 Verifikasi

```sql
SELECT tablespace_name,
       status
FROM dba_tablespaces
WHERE tablespace_name = 'TS_APPDATA';
```

Contoh output:

```text
TABLESPACE_NAME      STATUS
-------------------- ----------
TS_APPDATA           OFFLINE
```

## 10.3 Coba akses tabel

```sql
CONN appuser/oracle@localhost:1521/pdb1.localdomain

SELECT COUNT(*) FROM transaksi_lab;
```

Contoh error:

```text
ORA-00376: file cannot be read at this time
ORA-01110: data file ... 'ts_appdata01.dbf'
```

## 10.4 Online-kan kembali

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

ALTER TABLESPACE TS_APPDATA ONLINE;
```

Contoh output:

```text
Tablespace altered.
```

## 10.5 Verifikasi akses tabel

```sql
CONN appuser/oracle@localhost:1521/pdb1.localdomain

SELECT COUNT(*) FROM transaksi_lab;
```

Contoh output:

```text
  COUNT(*)
----------
      1000
```

---

# LAB 11 — Rename Tablespace

## 11.1 Rename tablespace

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

ALTER TABLESPACE TS_APPDATA RENAME TO TS_APPDATA_NEW;
```

Contoh output:

```text
Tablespace altered.
```

## 11.2 Verifikasi

```sql
SELECT tablespace_name
FROM dba_tablespaces
WHERE tablespace_name LIKE 'TS_APPDATA%';
```

Contoh output:

```text
TABLESPACE_NAME
--------------------
TS_APPDATA_NEW
```

## 11.3 Verifikasi default tablespace user ikut berubah

```sql
SELECT username,
       default_tablespace
FROM dba_users
WHERE username = 'APPUSER';
```

Contoh output:

```text
USERNAME        DEFAULT_TABLESPACE
--------------- --------------------
APPUSER         TS_APPDATA_NEW
```

---

# LAB 12 — Rename Datafile Secara Online

Oracle 12c ke atas mendukung rename/move datafile secara online.

## 12.1 Buat direktori target di OS

Keluar dulu dari SQL*Plus atau buka terminal baru.

```bash
mkdir -p /u01/app/oracle/oradata/ORADB/pdb1/moved
```

Verifikasi:

```bash
ls -ld /u01/app/oracle/oradata/ORADB/pdb1/moved
```

Contoh output:

```text
drwxr-xr-x. 2 oracle oinstall 6 Jul  3 10:00 /u01/app/oracle/oradata/ORADB/pdb1/moved
```

## 12.2 Masuk lagi ke SQL*Plus

```bash
sqlplus / as sysdba
```

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

## 12.3 Move datafile online

```sql
ALTER DATABASE MOVE DATAFILE
'/u01/app/oracle/oradata/ORADB/pdb1/ts_appdata02.dbf'
TO
'/u01/app/oracle/oradata/ORADB/pdb1/moved/ts_appdata02.dbf';
```

Contoh output:

```text
Database altered.
```

## 12.4 Verifikasi lokasi datafile

```sql
SELECT tablespace_name,
       file_name
FROM dba_data_files
WHERE tablespace_name = 'TS_APPDATA_NEW'
ORDER BY file_name;
```

Contoh output:

```text
TABLESPACE_NAME      FILE_NAME
-------------------- -------------------------------------------------------------
TS_APPDATA_NEW       /u01/app/oracle/oradata/ORADB/pdb1/moved/ts_appdata02.dbf
TS_APPDATA_NEW       /u01/app/oracle/oradata/ORADB/pdb1/ts_appdata01.dbf
```

## 12.5 Verifikasi file di OS

```bash
ls -lh /u01/app/oracle/oradata/ORADB/pdb1/moved/ts_appdata02.dbf
```

Contoh output:

```text
-rw-r-----. 1 oracle oinstall 51M Jul  3 10:05 /u01/app/oracle/oradata/ORADB/pdb1/moved/ts_appdata02.dbf
```

---

# LAB 13 — Menambah Datafile dengan Autoextend

## 13.1 Tambahkan datafile ketiga

```sql
ALTER TABLESPACE TS_APPDATA_NEW
ADD DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/ts_appdata03.dbf'
SIZE 20M
AUTOEXTEND ON
NEXT 5M
MAXSIZE 100M;
```

Contoh output:

```text
Tablespace altered.
```

## 13.2 Verifikasi

```sql
SELECT file_name,
       bytes/1024/1024 AS size_mb,
       autoextensible,
       increment_by * 8 / 1024 AS next_mb,
       maxbytes/1024/1024 AS max_mb
FROM dba_data_files
WHERE tablespace_name = 'TS_APPDATA_NEW'
ORDER BY file_name;
```

Contoh output:

```text
FILE_NAME                                                     SIZE_MB AUTOEXTENSIBLE NEXT_MB MAX_MB
------------------------------------------------------------- ------- -------------- ------- ------
/u01/app/oracle/oradata/ORADB/pdb1/moved/ts_appdata02.dbf          50 NO                   0      0
/u01/app/oracle/oradata/ORADB/pdb1/ts_appdata01.dbf               120 NO                   0      0
/u01/app/oracle/oradata/ORADB/pdb1/ts_appdata03.dbf                20 YES                  5    100
```

---

# LAB 14 — Membuat Temporary Tablespace

## 14.1 Buat temporary tablespace

```sql
CREATE TEMPORARY TABLESPACE TEMP_APP
TEMPFILE '/u01/app/oracle/oradata/ORADB/pdb1/temp_app01.dbf'
SIZE 50M
AUTOEXTEND ON
NEXT 10M
MAXSIZE 200M;
```

Contoh output:

```text
Tablespace created.
```

## 14.2 Verifikasi temporary tablespace

```sql
SELECT tablespace_name,
       contents,
       status
FROM dba_tablespaces
WHERE tablespace_name = 'TEMP_APP';
```

Contoh output:

```text
TABLESPACE_NAME      CONTENTS     STATUS
-------------------- ------------ ----------
TEMP_APP             TEMPORARY    ONLINE
```

## 14.3 Verifikasi tempfile

```sql
SELECT tablespace_name,
       file_name,
       bytes/1024/1024 AS size_mb,
       autoextensible
FROM dba_temp_files
WHERE tablespace_name = 'TEMP_APP';
```

Contoh output:

```text
TABLESPACE_NAME      FILE_NAME                                                     SIZE_MB AUTOEXTENSIBLE
-------------------- ------------------------------------------------------------- ------- --------------
TEMP_APP             /u01/app/oracle/oradata/ORADB/pdb1/temp_app01.dbf                 50 YES
```

## 14.4 Ubah temporary tablespace user

```sql
ALTER USER appuser TEMPORARY TABLESPACE TEMP_APP;
```

Contoh output:

```text
User altered.
```

## 14.5 Verifikasi

```sql
SELECT username,
       temporary_tablespace
FROM dba_users
WHERE username = 'APPUSER';
```

Contoh output:

```text
USERNAME        TEMPORARY_TABLESPACE
--------------- --------------------
APPUSER         TEMP_APP
```

---

# LAB 15 — Menambah Tempfile

## 15.1 Tambahkan tempfile

```sql
ALTER TABLESPACE TEMP_APP
ADD TEMPFILE '/u01/app/oracle/oradata/ORADB/pdb1/temp_app02.dbf'
SIZE 30M
AUTOEXTEND ON
NEXT 5M
MAXSIZE 100M;
```

Contoh output:

```text
Tablespace altered.
```

## 15.2 Verifikasi

```sql
SELECT tablespace_name,
       file_name,
       bytes/1024/1024 AS size_mb,
       autoextensible
FROM dba_temp_files
WHERE tablespace_name = 'TEMP_APP'
ORDER BY file_name;
```

Contoh output:

```text
TABLESPACE_NAME      FILE_NAME                                                     SIZE_MB AUTOEXTENSIBLE
-------------------- ------------------------------------------------------------- ------- --------------
TEMP_APP             /u01/app/oracle/oradata/ORADB/pdb1/temp_app01.dbf                 50 YES
TEMP_APP             /u01/app/oracle/oradata/ORADB/pdb1/temp_app02.dbf                 30 YES
```

---

# LAB 16 — Resize Tempfile

## 16.1 Resize tempfile

```sql
ALTER DATABASE TEMPFILE
'/u01/app/oracle/oradata/ORADB/pdb1/temp_app02.dbf'
RESIZE 50M;
```

Contoh output:

```text
Database altered.
```

## 16.2 Verifikasi

```sql
SELECT file_name,
       bytes/1024/1024 AS size_mb
FROM dba_temp_files
WHERE file_name LIKE '%temp_app02.dbf';
```

Contoh output:

```text
FILE_NAME                                                     SIZE_MB
------------------------------------------------------------- -------
/u01/app/oracle/oradata/ORADB/pdb1/temp_app02.dbf                  50
```

---

# LAB 17 — Menghapus Tempfile

## 17.1 Drop tempfile

```sql
ALTER DATABASE TEMPFILE
'/u01/app/oracle/oradata/ORADB/pdb1/temp_app02.dbf'
DROP INCLUDING DATAFILES;
```

Contoh output:

```text
Database altered.
```

## 17.2 Verifikasi

```sql
SELECT tablespace_name,
       file_name
FROM dba_temp_files
WHERE tablespace_name = 'TEMP_APP';
```

Contoh output:

```text
TABLESPACE_NAME      FILE_NAME
-------------------- -------------------------------------------------------------
TEMP_APP             /u01/app/oracle/oradata/ORADB/pdb1/temp_app01.dbf
```

---

# LAB 18 — Menghapus Datafile Kosong dari Tablespace

Catatan penting: datafile permanent hanya dapat dihapus jika kosong dan bukan satu-satunya datafile pada tablespace.

## 18.1 Tambahkan datafile kosong

```sql
ALTER TABLESPACE TS_APPDATA_NEW
ADD DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/ts_appdata_empty.dbf'
SIZE 10M;
```

Contoh output:

```text
Tablespace altered.
```

## 18.2 Verifikasi datafile

```sql
SELECT file_name,
       bytes/1024/1024 AS size_mb
FROM dba_data_files
WHERE tablespace_name = 'TS_APPDATA_NEW'
AND file_name LIKE '%empty%';
```

Contoh output:

```text
FILE_NAME                                                     SIZE_MB
------------------------------------------------------------- -------
/u01/app/oracle/oradata/ORADB/pdb1/ts_appdata_empty.dbf             10
```

## 18.3 Drop datafile kosong

```sql
ALTER TABLESPACE TS_APPDATA_NEW
DROP DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/ts_appdata_empty.dbf';
```

Contoh output:

```text
Tablespace altered.
```

## 18.4 Verifikasi

```sql
SELECT file_name
FROM dba_data_files
WHERE tablespace_name = 'TS_APPDATA_NEW'
AND file_name LIKE '%empty%';
```

Contoh output:

```text
no rows selected
```

---

# LAB 19 — Membuat Bigfile Tablespace

## 19.1 Buat bigfile tablespace

```sql
CREATE BIGFILE TABLESPACE TS_BIGDATA
DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/ts_bigdata01.dbf'
SIZE 100M
AUTOEXTEND ON
NEXT 50M
MAXSIZE 1G;
```

Contoh output:

```text
Tablespace created.
```

## 19.2 Verifikasi bigfile tablespace

```sql
SELECT tablespace_name,
       bigfile,
       contents
FROM dba_tablespaces
WHERE tablespace_name = 'TS_BIGDATA';
```

Contoh output:

```text
TABLESPACE_NAME      BIG CONTENTS
-------------------- --- ------------
TS_BIGDATA           YES PERMANENT
```

## 19.3 Verifikasi datafile

```sql
SELECT tablespace_name,
       file_name,
       bytes/1024/1024 AS size_mb,
       autoextensible,
       maxbytes/1024/1024 AS max_mb
FROM dba_data_files
WHERE tablespace_name = 'TS_BIGDATA';
```

Contoh output:

```text
TABLESPACE_NAME      FILE_NAME                                                     SIZE_MB AUTOEXTENSIBLE MAX_MB
-------------------- ------------------------------------------------------------- ------- -------------- ------
TS_BIGDATA           /u01/app/oracle/oradata/ORADB/pdb1/ts_bigdata01.dbf              100 YES              1024
```

---

# LAB 20 — Membuat Tablespace dengan OMF

Lab ini menggunakan Oracle Managed Files. File akan dibuat otomatis oleh Oracle.

## 20.1 Cek parameter OMF

```sql
SHOW PARAMETER db_create_file_dest
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
db_create_file_dest                  string
```

Jika masih kosong, set di CDB root:

```sql
CONN / AS SYSDBA

ALTER SYSTEM SET db_create_file_dest='/u01/app/oracle/oradata' SCOPE=BOTH;
```

Contoh output:

```text
System altered.
```

Masuk kembali ke PDB.

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

## 20.2 Buat tablespace tanpa menyebut nama datafile

```sql
CREATE TABLESPACE TS_OMF
SIZE 50M
AUTOEXTEND ON
NEXT 10M
MAXSIZE 200M;
```

Contoh output:

```text
Tablespace created.
```

## 20.3 Verifikasi file otomatis

```sql
SELECT tablespace_name,
       file_name,
       bytes/1024/1024 AS size_mb
FROM dba_data_files
WHERE tablespace_name = 'TS_OMF';
```

Contoh output:

```text
TABLESPACE_NAME      FILE_NAME                                                                  SIZE_MB
-------------------- -------------------------------------------------------------------------- -------
TS_OMF               /u01/app/oracle/oradata/ORADB/....../datafile/o1_mf_ts_omf_xxxxxxxx_.dbf        50
```

---

# LAB 21 — Menghapus Tablespace Beserta Datafile

## 21.1 Drop tablespace OMF

```sql
DROP TABLESPACE TS_OMF INCLUDING CONTENTS AND DATAFILES;
```

Contoh output:

```text
Tablespace dropped.
```

## 21.2 Verifikasi

```sql
SELECT tablespace_name
FROM dba_tablespaces
WHERE tablespace_name = 'TS_OMF';
```

Contoh output:

```text
no rows selected
```

---

# LAB 22 — Drop Tablespace yang Masih Berisi Object

## 22.1 Coba drop tablespace tanpa INCLUDING CONTENTS

```sql
DROP TABLESPACE TS_APPDATA_NEW;
```

Contoh error:

```text
ORA-01549: tablespace not empty, use INCLUDING CONTENTS option
```

## 22.2 Drop dengan isi dan datafile

```sql
DROP TABLESPACE TS_APPDATA_NEW
INCLUDING CONTENTS AND DATAFILES;
```

Contoh output:

```text
Tablespace dropped.
```

Catatan: tabel milik `APPUSER` yang berada di tablespace ini akan ikut hilang.

## 22.3 Verifikasi tablespace

```sql
SELECT tablespace_name
FROM dba_tablespaces
WHERE tablespace_name = 'TS_APPDATA_NEW';
```

Contoh output:

```text
no rows selected
```

## 22.4 Verifikasi object user

```sql
SELECT owner,
       object_name,
       object_type
FROM dba_objects
WHERE owner = 'APPUSER';
```

Contoh output:

```text
no rows selected
```

---

# LAB 23 — Cleanup Temporary Tablespace

Sebelum drop `TEMP_APP`, kembalikan temporary tablespace user ke `TEMP`.

```sql
ALTER USER appuser TEMPORARY TABLESPACE TEMP;
```

Contoh output:

```text
User altered.
```

Verifikasi:

```sql
SELECT username,
       temporary_tablespace
FROM dba_users
WHERE username = 'APPUSER';
```

Contoh output:

```text
USERNAME        TEMPORARY_TABLESPACE
--------------- --------------------
APPUSER         TEMP
```

Drop temporary tablespace.

```sql
DROP TABLESPACE TEMP_APP INCLUDING CONTENTS AND DATAFILES;
```

Contoh output:

```text
Tablespace dropped.
```

Verifikasi:

```sql
SELECT tablespace_name
FROM dba_tablespaces
WHERE tablespace_name = 'TEMP_APP';
```

Contoh output:

```text
no rows selected
```

---

# LAB 24 — Cleanup User dan Bigfile Tablespace

## 24.1 Drop user

```sql
DROP USER appuser CASCADE;
```

Contoh output:

```text
User dropped.
```

## 24.2 Drop bigfile tablespace

```sql
DROP TABLESPACE TS_BIGDATA INCLUDING CONTENTS AND DATAFILES;
```

Contoh output:

```text
Tablespace dropped.
```

## 24.3 Verifikasi akhir

```sql
SELECT tablespace_name
FROM dba_tablespaces
WHERE tablespace_name IN ('TS_APPDATA_NEW', 'TEMP_APP', 'TS_BIGDATA');
```

Contoh output:

```text
no rows selected
```

---

# Ringkasan Command Penting

```sql
CREATE TABLESPACE nama_ts DATAFILE 'file.dbf' SIZE 100M;
```

```sql
ALTER TABLESPACE nama_ts ADD DATAFILE 'file02.dbf' SIZE 50M;
```

```sql
ALTER DATABASE DATAFILE 'file.dbf' RESIZE 200M;
```

```sql
ALTER DATABASE DATAFILE 'file.dbf' AUTOEXTEND ON NEXT 10M MAXSIZE 1G;
```

```sql
ALTER DATABASE DATAFILE 'file.dbf' AUTOEXTEND OFF;
```

```sql
ALTER DATABASE MOVE DATAFILE 'file_lama.dbf' TO 'file_baru.dbf';
```

```sql
ALTER TABLESPACE nama_ts READ ONLY;
```

```sql
ALTER TABLESPACE nama_ts READ WRITE;
```

```sql
ALTER TABLESPACE nama_ts OFFLINE;
```

```sql
ALTER TABLESPACE nama_ts ONLINE;
```

```sql
ALTER TABLESPACE nama_ts DROP DATAFILE 'file_kosong.dbf';
```

```sql
DROP TABLESPACE nama_ts INCLUDING CONTENTS AND DATAFILES;
```

---

# Catatan Best Practice

Untuk lingkungan Oracle 19c Multitenant, sebaiknya tablespace aplikasi dibuat di **PDB**, bukan di `CDB$ROOT`. `CDB$ROOT` lebih tepat untuk common user dan metadata Oracle, sedangkan objek aplikasi sebaiknya ditempatkan di tablespace masing-masing PDB.
