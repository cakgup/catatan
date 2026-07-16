# HANDS-ON LAB

# Manajemen Temporary Tablespace Oracle 19c

Asumsi:

```text
CDB  : ORADB
PDB  : PDB1
OS   : Oracle Linux
DB   : Oracle Database 19c
User : oracle
```

Catatan penting:

```text
Temporary tablespace dibuat di level PDB untuk kebutuhan session di PDB tersebut.
Temporary tablespace menggunakan TEMPFILE, bukan DATAFILE.
Tempfile tidak menghasilkan redo seperti datafile biasa.
Tempfile tidak masuk backup RMAN secara normal karena dapat dibuat ulang.
Istilah archive temporary tablespace tidak ada seperti archive redo log.
```

---

# 0. Persiapan Awal

Login sebagai user `oracle`.

```bash
su - oracle
sqlplus / as sysdba
```

Verifikasi database:

```sql
SELECT name, cdb, open_mode
FROM v$database;
```

Contoh output:

```text
NAME      CDB OPEN_MODE
--------- --- --------------------
ORADB     YES READ WRITE
```

Verifikasi PDB:

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

Masuk ke PDB:

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

Verifikasi:

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

# LAB 1 — Melihat Temporary Tablespace Existing

## 1.1 Lihat temporary tablespace

```sql
SET LINESIZE 200
COLUMN tablespace_name FORMAT A20
COLUMN contents FORMAT A12
COLUMN status FORMAT A10
COLUMN extent_management FORMAT A18

SELECT tablespace_name,
       contents,
       status,
       extent_management
FROM dba_tablespaces
WHERE contents = 'TEMPORARY';
```

Contoh output:

```text
TABLESPACE_NAME      CONTENTS     STATUS     EXTENT_MANAGEMENT
-------------------- ------------ ---------- ------------------
TEMP                 TEMPORARY    ONLINE     LOCAL
```

## 1.2 Lihat tempfile

```sql
COLUMN file_name FORMAT A90
COLUMN tablespace_name FORMAT A20

SELECT tablespace_name,
       file_name,
       bytes/1024/1024 AS size_mb,
       autoextensible
FROM dba_temp_files
ORDER BY tablespace_name, file_name;
```

Contoh output:

```text
TABLESPACE_NAME      FILE_NAME                                                        SIZE_MB AUTOEXTENSIBLE
-------------------- ---------------------------------------------------------------- ------- --------------
TEMP                 /u01/app/oracle/oradata/ORADB/pdb1/temp01.dbf                       36 YES
```

## 1.3 Lihat default temporary tablespace database

```sql
SELECT property_name,
       property_value
FROM database_properties
WHERE property_name = 'DEFAULT_TEMP_TABLESPACE';
```

Contoh output:

```text
PROPERTY_NAME                 PROPERTY_VALUE
----------------------------- --------------------
DEFAULT_TEMP_TABLESPACE       TEMP
```

---

# LAB 2 — Membuat Temporary Tablespace Baru

## 2.1 Buat temporary tablespace

```sql
CREATE TEMPORARY TABLESPACE TEMP_LAB
TEMPFILE '/u01/app/oracle/oradata/ORADB/pdb1/temp_lab01.dbf'
SIZE 100M
AUTOEXTEND OFF
EXTENT MANAGEMENT LOCAL UNIFORM SIZE 1M;
```

Contoh output:

```text
Tablespace created.
```

## 2.2 Verifikasi tablespace

```sql
SELECT tablespace_name,
       contents,
       status,
       extent_management
FROM dba_tablespaces
WHERE tablespace_name = 'TEMP_LAB';
```

Contoh output:

```text
TABLESPACE_NAME      CONTENTS     STATUS     EXTENT_MANAGEMENT
-------------------- ------------ ---------- ------------------
TEMP_LAB             TEMPORARY    ONLINE     LOCAL
```

## 2.3 Verifikasi tempfile

```sql
SELECT tablespace_name,
       file_name,
       bytes/1024/1024 AS size_mb,
       autoextensible
FROM dba_temp_files
WHERE tablespace_name = 'TEMP_LAB';
```

Contoh output:

```text
TABLESPACE_NAME      FILE_NAME                                                     SIZE_MB AUTOEXTENSIBLE
-------------------- ------------------------------------------------------------- ------- --------------
TEMP_LAB             /u01/app/oracle/oradata/ORADB/pdb1/temp_lab01.dbf                100 NO
```

---

# LAB 3 — Mengubah Default Temporary Tablespace PDB

## 3.1 Ubah default temporary tablespace

```sql
ALTER DATABASE DEFAULT TEMPORARY TABLESPACE TEMP_LAB;
```

Contoh output:

```text
Database altered.
```

## 3.2 Verifikasi

```sql
SELECT property_name,
       property_value
FROM database_properties
WHERE property_name = 'DEFAULT_TEMP_TABLESPACE';
```

Contoh output:

```text
PROPERTY_NAME                 PROPERTY_VALUE
----------------------------- --------------------
DEFAULT_TEMP_TABLESPACE       TEMP_LAB
```

---

# LAB 4 — Membuat User yang Menggunakan Temporary Tablespace

## 4.1 Buat tablespace permanent untuk user lab

```sql
CREATE TABLESPACE TS_TEMP_TEST
DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/ts_temp_test01.dbf'
SIZE 100M
AUTOEXTEND ON
NEXT 50M
MAXSIZE 500M;
```

Contoh output:

```text
Tablespace created.
```

## 4.2 Buat user

```sql
CREATE USER tempuser IDENTIFIED BY oracle
DEFAULT TABLESPACE TS_TEMP_TEST
TEMPORARY TABLESPACE TEMP_LAB
QUOTA UNLIMITED ON TS_TEMP_TEST;
```

Contoh output:

```text
User created.
```

## 4.3 Grant privilege

```sql
GRANT CREATE SESSION, CREATE TABLE TO tempuser;
```

Contoh output:

```text
Grant succeeded.
```

## 4.4 Verifikasi user

```sql
SELECT username,
       default_tablespace,
       temporary_tablespace
FROM dba_users
WHERE username = 'TEMPUSER';
```

Contoh output:

```text
USERNAME        DEFAULT_TABLESPACE   TEMPORARY_TABLESPACE
--------------- -------------------- --------------------
TEMPUSER        TS_TEMP_TEST         TEMP_LAB
```

---

# LAB 5 — Menambahkan Tempfile

## 5.1 Tambahkan tempfile kedua

```sql
ALTER TABLESPACE TEMP_LAB
ADD TEMPFILE '/u01/app/oracle/oradata/ORADB/pdb1/temp_lab02.dbf'
SIZE 50M
AUTOEXTEND OFF;
```

Contoh output:

```text
Tablespace altered.
```

## 5.2 Verifikasi tempfile

```sql
SELECT tablespace_name,
       file_name,
       bytes/1024/1024 AS size_mb,
       autoextensible
FROM dba_temp_files
WHERE tablespace_name = 'TEMP_LAB'
ORDER BY file_name;
```

Contoh output:

```text
TABLESPACE_NAME      FILE_NAME                                                     SIZE_MB AUTOEXTENSIBLE
-------------------- ------------------------------------------------------------- ------- --------------
TEMP_LAB             /u01/app/oracle/oradata/ORADB/pdb1/temp_lab01.dbf                100 NO
TEMP_LAB             /u01/app/oracle/oradata/ORADB/pdb1/temp_lab02.dbf                 50 NO
```

---

# LAB 6 — Resize Manual Tempfile

## 6.1 Perbesar tempfile

```sql
ALTER DATABASE TEMPFILE
'/u01/app/oracle/oradata/ORADB/pdb1/temp_lab02.dbf'
RESIZE 100M;
```

Contoh output:

```text
Database altered.
```

## 6.2 Verifikasi

```sql
SELECT file_name,
       bytes/1024/1024 AS size_mb
FROM dba_temp_files
WHERE file_name LIKE '%temp_lab02.dbf';
```

Contoh output:

```text
FILE_NAME                                                     SIZE_MB
------------------------------------------------------------- -------
/u01/app/oracle/oradata/ORADB/pdb1/temp_lab02.dbf                 100
```

## 6.3 Perkecil tempfile

```sql
ALTER DATABASE TEMPFILE
'/u01/app/oracle/oradata/ORADB/pdb1/temp_lab02.dbf'
RESIZE 60M;
```

Contoh output:

```text
Database altered.
```

## 6.4 Verifikasi

```sql
SELECT file_name,
       bytes/1024/1024 AS size_mb
FROM dba_temp_files
WHERE file_name LIKE '%temp_lab02.dbf';
```

Contoh output:

```text
FILE_NAME                                                     SIZE_MB
------------------------------------------------------------- -------
/u01/app/oracle/oradata/ORADB/pdb1/temp_lab02.dbf                  60
```

---

# LAB 7 — Mengaktifkan Autoextend Tempfile

## 7.1 Aktifkan autoextend

```sql
ALTER DATABASE TEMPFILE
'/u01/app/oracle/oradata/ORADB/pdb1/temp_lab02.dbf'
AUTOEXTEND ON
NEXT 10M
MAXSIZE 300M;
```

Contoh output:

```text
Database altered.
```

## 7.2 Verifikasi autoextend

```sql
SELECT file_name,
       bytes/1024/1024 AS size_mb,
       autoextensible,
       increment_by * 8 / 1024 AS next_mb,
       maxbytes/1024/1024 AS max_mb
FROM dba_temp_files
WHERE file_name LIKE '%temp_lab02.dbf';
```

Contoh output:

```text
FILE_NAME                                                     SIZE_MB AUTOEXTENSIBLE NEXT_MB MAX_MB
------------------------------------------------------------- ------- -------------- ------- ------
/u01/app/oracle/oradata/ORADB/pdb1/temp_lab02.dbf                  60 YES                 10    300
```

Catatan: rumus `increment_by * 8 / 1024` mengasumsikan block size 8 KB.

---

# LAB 8 — Menonaktifkan Autoextend Tempfile

## 8.1 Matikan autoextend

```sql
ALTER DATABASE TEMPFILE
'/u01/app/oracle/oradata/ORADB/pdb1/temp_lab02.dbf'
AUTOEXTEND OFF;
```

Contoh output:

```text
Database altered.
```

## 8.2 Verifikasi

```sql
SELECT file_name,
       bytes/1024/1024 AS size_mb,
       autoextensible
FROM dba_temp_files
WHERE file_name LIKE '%temp_lab02.dbf';
```

Contoh output:

```text
FILE_NAME                                                     SIZE_MB AUTOEXTENSIBLE
------------------------------------------------------------- ------- --------------
/u01/app/oracle/oradata/ORADB/pdb1/temp_lab02.dbf                  60 NO
```

---

# LAB 9 — Monitoring Penggunaan Temporary Tablespace

## 9.1 Cek total ukuran temporary tablespace

```sql
SELECT tablespace_name,
       SUM(bytes)/1024/1024 AS total_mb
FROM dba_temp_files
WHERE tablespace_name = 'TEMP_LAB'
GROUP BY tablespace_name;
```

Contoh output:

```text
TABLESPACE_NAME        TOTAL_MB
-------------------- ----------
TEMP_LAB                    160
```

## 9.2 Cek penggunaan TEMP saat ini

```sql
SELECT tablespace_name,
       used_blocks * 8 / 1024 AS used_mb,
       free_blocks * 8 / 1024 AS free_mb,
       total_blocks * 8 / 1024 AS total_mb
FROM v$sort_segment
WHERE tablespace_name = 'TEMP_LAB';
```

Contoh output:

```text
TABLESPACE_NAME         USED_MB    FREE_MB   TOTAL_MB
-------------------- ---------- ---------- ----------
TEMP_LAB                     0        160        160
```

## 9.3 Cek session yang menggunakan TEMP

```sql
COLUMN username FORMAT A15
COLUMN tablespace FORMAT A20

SELECT s.sid,
       s.serial#,
       s.username,
       u.tablespace,
       u.blocks * 8 / 1024 AS used_mb,
       u.segtype,
       u.sql_id
FROM v$tempseg_usage u
JOIN v$session s
ON u.session_addr = s.saddr
ORDER BY used_mb DESC;
```

Contoh output jika belum ada penggunaan TEMP:

```text
no rows selected
```

---

# LAB 10 — Simulasi Penggunaan Temporary Tablespace

## 10.1 Login sebagai tempuser

```sql
CONN tempuser/oracle@localhost:1521/pdb1.localdomain
```

Contoh output:

```text
Connected.
```

## 10.2 Buat tabel testing

```sql
CREATE TABLE temp_sort_test AS
SELECT LEVEL AS id,
       DBMS_RANDOM.STRING('A', 100) AS nama,
       RPAD('DATA TEMP TEST', 500, 'X') AS deskripsi
FROM dual
CONNECT BY LEVEL <= 100000;
```

Contoh output:

```text
Table created.
```

## 10.3 Jalankan query sort besar

```sql
SELECT *
FROM temp_sort_test
ORDER BY deskripsi, nama;
```

Contoh output:

```text
... data tampil banyak ...
```

Biarkan query berjalan beberapa saat jika memungkinkan.

---

# LAB 11 — Monitoring TEMP dari Session Lain

Buka terminal kedua:

```bash
su - oracle
sqlplus / as sysdba
```

Masuk ke PDB:

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

Cek penggunaan TEMP:

```sql
COLUMN username FORMAT A15
COLUMN tablespace FORMAT A20

SELECT s.sid,
       s.serial#,
       s.username,
       u.tablespace,
       ROUND(u.blocks * 8 / 1024,2) AS used_mb,
       u.segtype,
       u.sql_id
FROM v$tempseg_usage u
JOIN v$session s
ON u.session_addr = s.saddr
WHERE u.tablespace = 'TEMP_LAB'
ORDER BY used_mb DESC;
```

Contoh output:

```text
       SID    SERIAL# USERNAME        TABLESPACE              USED_MB SEGTYPE   SQL_ID
---------- ---------- --------------- -------------------- ---------- --------- -------------
        82      21837 TEMPUSER        TEMP_LAB                  48.00 SORT      7x2a9m0f1p9dq
```

---

# LAB 12 — Membuat Temporary Tablespace Group

Temporary tablespace group berguna agar user dapat menggunakan beberapa temporary tablespace sebagai satu group.

## 12.1 Buat temporary tablespace kedua

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

CREATE TEMPORARY TABLESPACE TEMP_LAB_B
TEMPFILE '/u01/app/oracle/oradata/ORADB/pdb1/temp_lab_b01.dbf'
SIZE 100M
AUTOEXTEND ON
NEXT 50M
MAXSIZE 500M;
```

Contoh output:

```text
Tablespace created.
```

## 12.2 Tambahkan TEMP_LAB ke group

```sql
ALTER TABLESPACE TEMP_LAB
TABLESPACE GROUP TEMP_GRP_LAB;
```

Contoh output:

```text
Tablespace altered.
```

## 12.3 Tambahkan TEMP_LAB_B ke group

```sql
ALTER TABLESPACE TEMP_LAB_B
TABLESPACE GROUP TEMP_GRP_LAB;
```

Contoh output:

```text
Tablespace altered.
```

## 12.4 Verifikasi group

```sql
SELECT tablespace_name,
       group_name
FROM dba_tablespace_groups
WHERE group_name = 'TEMP_GRP_LAB';
```

Contoh output:

```text
TABLESPACE_NAME      GROUP_NAME
-------------------- --------------------
TEMP_LAB             TEMP_GRP_LAB
TEMP_LAB_B           TEMP_GRP_LAB
```

---

# LAB 13 — Menggunakan Temporary Tablespace Group sebagai Default

## 13.1 Set default temporary tablespace ke group

```sql
ALTER DATABASE DEFAULT TEMPORARY TABLESPACE TEMP_GRP_LAB;
```

Contoh output:

```text
Database altered.
```

## 13.2 Verifikasi default temporary tablespace

```sql
SELECT property_name,
       property_value
FROM database_properties
WHERE property_name = 'DEFAULT_TEMP_TABLESPACE';
```

Contoh output:

```text
PROPERTY_NAME                 PROPERTY_VALUE
----------------------------- --------------------
DEFAULT_TEMP_TABLESPACE       TEMP_GRP_LAB
```

## 13.3 Ubah user agar menggunakan group

```sql
ALTER USER tempuser TEMPORARY TABLESPACE TEMP_GRP_LAB;
```

Contoh output:

```text
User altered.
```

## 13.4 Verifikasi user

```sql
SELECT username,
       temporary_tablespace
FROM dba_users
WHERE username = 'TEMPUSER';
```

Contoh output:

```text
USERNAME        TEMPORARY_TABLESPACE
--------------- --------------------
TEMPUSER        TEMP_GRP_LAB
```

---

# LAB 14 — Mengeluarkan Temporary Tablespace dari Group

## 14.1 Keluarkan TEMP_LAB_B dari group

```sql
ALTER TABLESPACE TEMP_LAB_B
TABLESPACE GROUP '';
```

Contoh output:

```text
Tablespace altered.
```

## 14.2 Verifikasi

```sql
SELECT tablespace_name,
       group_name
FROM dba_tablespace_groups
WHERE tablespace_name IN ('TEMP_LAB', 'TEMP_LAB_B');
```

Contoh output:

```text
TABLESPACE_NAME      GROUP_NAME
-------------------- --------------------
TEMP_LAB             TEMP_GRP_LAB
```

---

# LAB 15 — Memindahkan Lokasi Tempfile

Untuk tempfile, cara paling aman adalah:

```text
1. Tambahkan tempfile baru di lokasi baru.
2. Drop tempfile lama.
```

## 15.1 Buat folder baru

```bash
mkdir -p /u01/app/oracle/oradata/ORADB/pdb1/temp_newloc
```

Verifikasi:

```bash
ls -ld /u01/app/oracle/oradata/ORADB/pdb1/temp_newloc
```

Contoh output:

```text
drwxr-xr-x. 2 oracle oinstall 6 Jul  4 11:00 /u01/app/oracle/oradata/ORADB/pdb1/temp_newloc
```

## 15.2 Tambahkan tempfile baru di lokasi baru

```sql
ALTER TABLESPACE TEMP_LAB
ADD TEMPFILE '/u01/app/oracle/oradata/ORADB/pdb1/temp_newloc/temp_lab03.dbf'
SIZE 100M
AUTOEXTEND ON
NEXT 50M
MAXSIZE 500M;
```

Contoh output:

```text
Tablespace altered.
```

## 15.3 Verifikasi tempfile baru

```sql
SELECT tablespace_name,
       file_name,
       bytes/1024/1024 AS size_mb,
       autoextensible
FROM dba_temp_files
WHERE tablespace_name = 'TEMP_LAB'
ORDER BY file_name;
```

Contoh output:

```text
TABLESPACE_NAME      FILE_NAME                                                         SIZE_MB AUTOEXTENSIBLE
-------------------- ----------------------------------------------------------------- ------- --------------
TEMP_LAB             /u01/app/oracle/oradata/ORADB/pdb1/temp_lab01.dbf                    100 NO
TEMP_LAB             /u01/app/oracle/oradata/ORADB/pdb1/temp_lab02.dbf                     60 NO
TEMP_LAB             /u01/app/oracle/oradata/ORADB/pdb1/temp_newloc/temp_lab03.dbf         100 YES
```

## 15.4 Drop tempfile lama

```sql
ALTER DATABASE TEMPFILE
'/u01/app/oracle/oradata/ORADB/pdb1/temp_lab02.dbf'
DROP INCLUDING DATAFILES;
```

Contoh output:

```text
Database altered.
```

## 15.5 Verifikasi tempfile lama sudah hilang

```sql
SELECT file_name
FROM dba_temp_files
WHERE file_name LIKE '%temp_lab02.dbf';
```

Contoh output:

```text
no rows selected
```

---

# LAB 16 — Drop Temporary Tablespace yang Masih Menjadi Default

## 16.1 Coba drop TEMP_LAB saat masih menjadi default/group

```sql
DROP TABLESPACE TEMP_LAB INCLUDING CONTENTS AND DATAFILES;
```

Contoh kemungkinan error:

```text
ORA-12906: cannot drop default temporary tablespace
```

atau jika masih digunakan dalam temporary tablespace group:

```text
ORA-10927: tablespace belongs to a temporary tablespace group
```

## 16.2 Solusi: kembalikan default temporary tablespace ke TEMP

```sql
ALTER DATABASE DEFAULT TEMPORARY TABLESPACE TEMP;
```

Contoh output:

```text
Database altered.
```

## 16.3 Ubah user kembali ke TEMP

```sql
ALTER USER tempuser TEMPORARY TABLESPACE TEMP;
```

Contoh output:

```text
User altered.
```

## 16.4 Keluarkan TEMP_LAB dari group

```sql
ALTER TABLESPACE TEMP_LAB
TABLESPACE GROUP '';
```

Contoh output:

```text
Tablespace altered.
```

## 16.5 Verifikasi

```sql
SELECT property_name,
       property_value
FROM database_properties
WHERE property_name = 'DEFAULT_TEMP_TABLESPACE';
```

Contoh output:

```text
PROPERTY_NAME                 PROPERTY_VALUE
----------------------------- --------------------
DEFAULT_TEMP_TABLESPACE       TEMP
```

```sql
SELECT username,
       temporary_tablespace
FROM dba_users
WHERE username = 'TEMPUSER';
```

Contoh output:

```text
USERNAME        TEMPORARY_TABLESPACE
--------------- --------------------
TEMPUSER        TEMP
```

---

# LAB 17 — Menghapus Temporary Tablespace

## 17.1 Drop TEMP_LAB

```sql
DROP TABLESPACE TEMP_LAB INCLUDING CONTENTS AND DATAFILES;
```

Contoh output:

```text
Tablespace dropped.
```

## 17.2 Verifikasi

```sql
SELECT tablespace_name
FROM dba_tablespaces
WHERE tablespace_name = 'TEMP_LAB';
```

Contoh output:

```text
no rows selected
```

## 17.3 Drop TEMP_LAB_B

```sql
DROP TABLESPACE TEMP_LAB_B INCLUDING CONTENTS AND DATAFILES;
```

Contoh output:

```text
Tablespace dropped.
```

## 17.4 Verifikasi

```sql
SELECT tablespace_name
FROM dba_tablespaces
WHERE tablespace_name IN ('TEMP_LAB', 'TEMP_LAB_B');
```

Contoh output:

```text
no rows selected
```

---

# LAB 18 — Membuat Temporary Tablespace dengan OMF

## 18.1 Cek parameter OMF

```sql
SHOW PARAMETER db_create_file_dest
```

Contoh output jika belum diset:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
db_create_file_dest                  string
```

## 18.2 Set OMF dari root

```sql
CONN / AS SYSDBA

ALTER SYSTEM SET db_create_file_dest='/u01/app/oracle/oradata' SCOPE=BOTH;
```

Contoh output:

```text
System altered.
```

Masuk kembali ke PDB:

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

## 18.3 Buat temporary tablespace tanpa menyebut tempfile

```sql
CREATE TEMPORARY TABLESPACE TEMP_OMF
TEMPFILE SIZE 100M
AUTOEXTEND ON
NEXT 50M
MAXSIZE 500M;
```

Contoh output:

```text
Tablespace created.
```

## 18.4 Verifikasi file OMF

```sql
SELECT tablespace_name,
       file_name,
       bytes/1024/1024 AS size_mb,
       autoextensible
FROM dba_temp_files
WHERE tablespace_name = 'TEMP_OMF';
```

Contoh output:

```text
TABLESPACE_NAME      FILE_NAME                                                                  SIZE_MB AUTOEXTENSIBLE
-------------------- -------------------------------------------------------------------------- ------- --------------
TEMP_OMF             /u01/app/oracle/oradata/ORADB/....../datafile/o1_mf_temp_omf_xxxxx.tmp        100 YES
```

## 18.5 Drop TEMP_OMF

```sql
DROP TABLESPACE TEMP_OMF INCLUDING CONTENTS AND DATAFILES;
```

Contoh output:

```text
Tablespace dropped.
```

---

# LAB 19 — Recreate Tempfile jika Hilang

Tempfile relatif mudah dibuat ulang karena tidak menyimpan data permanen.

## 19.1 Cek tempfile TEMP existing

```sql
SELECT tablespace_name,
       file_name
FROM dba_temp_files
WHERE tablespace_name = 'TEMP';
```

Contoh output:

```text
TABLESPACE_NAME      FILE_NAME
-------------------- -------------------------------------------------------------
TEMP                 /u01/app/oracle/oradata/ORADB/pdb1/temp01.dbf
```

## 19.2 Simulasi tambah tempfile baru ke TEMP

```sql
ALTER TABLESPACE TEMP
ADD TEMPFILE '/u01/app/oracle/oradata/ORADB/pdb1/temp_recreate01.dbf'
SIZE 50M
AUTOEXTEND ON
NEXT 10M
MAXSIZE 200M;
```

Contoh output:

```text
Tablespace altered.
```

## 19.3 Drop tempfile tersebut

```sql
ALTER DATABASE TEMPFILE
'/u01/app/oracle/oradata/ORADB/pdb1/temp_recreate01.dbf'
DROP INCLUDING DATAFILES;
```

Contoh output:

```text
Database altered.
```

## 19.4 Verifikasi

```sql
SELECT file_name
FROM dba_temp_files
WHERE file_name LIKE '%temp_recreate01.dbf';
```

Contoh output:

```text
no rows selected
```

---

# LAB 20 — Monitoring Temporary Tablespace untuk Semua PDB

Jalankan dari CDB root.

```sql
CONN / AS SYSDBA
```

## 20.1 Lihat tempfile semua PDB

```sql
SET LINESIZE 200
COLUMN pdb_name FORMAT A20
COLUMN file_name FORMAT A90

SELECT p.name AS pdb_name,
       tf.tablespace_name,
       tf.file_name,
       tf.bytes/1024/1024 AS size_mb,
       tf.autoextensible
FROM cdb_temp_files tf
JOIN v$pdbs p
ON tf.con_id = p.con_id
ORDER BY p.name, tf.tablespace_name;
```

Contoh output:

```text
PDB_NAME             TABLESPACE_NAME      FILE_NAME                                                        SIZE_MB AUTOEXTENSIBLE
-------------------- -------------------- ---------------------------------------------------------------- ------- --------------
PDB1                 TEMP                 /u01/app/oracle/oradata/ORADB/pdb1/temp01.dbf                       36 YES
```

## 20.2 Lihat default temporary tablespace setiap PDB

```sql
COLUMN pdb_name FORMAT A20
COLUMN property_value FORMAT A25

SELECT p.name AS pdb_name,
       dp.property_value
FROM cdb_properties dp
JOIN v$pdbs p
ON dp.con_id = p.con_id
WHERE dp.property_name = 'DEFAULT_TEMP_TABLESPACE'
ORDER BY p.name;
```

Contoh output:

```text
PDB_NAME             PROPERTY_VALUE
-------------------- -------------------------
PDB1                 TEMP
```

---

# LAB 21 — Cleanup User dan Tablespace Permanent Lab

Masuk ke PDB1:

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;
```

Drop user:

```sql
DROP USER tempuser CASCADE;
```

Contoh output:

```text
User dropped.
```

Drop tablespace permanent lab:

```sql
DROP TABLESPACE TS_TEMP_TEST INCLUDING CONTENTS AND DATAFILES;
```

Contoh output:

```text
Tablespace dropped.
```

Verifikasi:

```sql
SELECT username
FROM dba_users
WHERE username = 'TEMPUSER';
```

Contoh output:

```text
no rows selected
```

```sql
SELECT tablespace_name
FROM dba_tablespaces
WHERE tablespace_name = 'TS_TEMP_TEST';
```

Contoh output:

```text
no rows selected
```

---

# Ringkasan Command Penting

Membuat temporary tablespace:

```sql
CREATE TEMPORARY TABLESPACE TEMP_LAB
TEMPFILE '/path/temp_lab01.dbf'
SIZE 100M
AUTOEXTEND OFF;
```

Menambahkan tempfile:

```sql
ALTER TABLESPACE TEMP_LAB
ADD TEMPFILE '/path/temp_lab02.dbf'
SIZE 50M;
```

Resize tempfile:

```sql
ALTER DATABASE TEMPFILE '/path/temp_lab02.dbf'
RESIZE 100M;
```

Autoextend ON:

```sql
ALTER DATABASE TEMPFILE '/path/temp_lab02.dbf'
AUTOEXTEND ON NEXT 10M MAXSIZE 300M;
```

Autoextend OFF:

```sql
ALTER DATABASE TEMPFILE '/path/temp_lab02.dbf'
AUTOEXTEND OFF;
```

Drop tempfile:

```sql
ALTER DATABASE TEMPFILE '/path/temp_lab02.dbf'
DROP INCLUDING DATAFILES;
```

Set default temporary tablespace:

```sql
ALTER DATABASE DEFAULT TEMPORARY TABLESPACE TEMP_LAB;
```

Set user temporary tablespace:

```sql
ALTER USER username TEMPORARY TABLESPACE TEMP_LAB;
```

Temporary tablespace group:

```sql
ALTER TABLESPACE TEMP_LAB TABLESPACE GROUP TEMP_GRP_LAB;
```

Keluar dari group:

```sql
ALTER TABLESPACE TEMP_LAB TABLESPACE GROUP '';
```

Drop temporary tablespace:

```sql
DROP TABLESPACE TEMP_LAB INCLUDING CONTENTS AND DATAFILES;
```

Monitoring session pengguna TEMP:

```sql
SELECT s.sid,
       s.serial#,
       s.username,
       u.tablespace,
       u.blocks * 8 / 1024 AS used_mb,
       u.segtype,
       u.sql_id
FROM v$tempseg_usage u
JOIN v$session s
ON u.session_addr = s.saddr;
```

---

Catatan akhir: **temporary tablespace tidak memiliki archive seperti redo log**. Tempfile bersifat sementara dan tidak menyimpan data permanen. Jika tempfile hilang, DBA biasanya cukup membuat ulang tempfile atau menambahkan tempfile baru ke temporary tablespace terkait.
