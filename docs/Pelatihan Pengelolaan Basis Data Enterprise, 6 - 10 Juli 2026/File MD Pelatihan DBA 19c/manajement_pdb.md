---

# HANDS-ON LAB

# Manajemen PDB Oracle 19c

Asumsi:

```text
CDB       : ORADB
PDB awal  : PDB1
OS        : Oracle Linux
Oracle    : 19c
User OS   : oracle
```


## 0. Persiapan Awal

```bash
su - oracle
sqlplus / as sysdba
```

Verifikasi database:

```sql
SELECT name, cdb FROM v$database;
```

Contoh output:

```text
NAME      CDB
--------- ---
ORADB     YES
```

Verifikasi container:

```sql
SHOW CON_NAME
```

Contoh output:

```text
CON_NAME
------------------------------
CDB$ROOT
```

Lihat daftar PDB:

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

---

# LAB 1 — Membuat PDB Baru dari PDB$SEED

## 1.1 Buat folder untuk PDB baru

```bash
mkdir -p /u01/app/oracle/oradata/ORADB/PDBLAB1
```

## 1.2 Buat PDB

```sql
CREATE PLUGGABLE DATABASE PDBLAB1
ADMIN USER pdbadmin IDENTIFIED BY oracle
FILE_NAME_CONVERT = (
'/u01/app/oracle/oradata/ORADB/pdbseed/',
'/u01/app/oracle/oradata/ORADB/PDBLAB1/'
);
```

Contoh output:

```text
Pluggable database created.
```

## 1.3 Verifikasi PDB

```sql
SHOW PDBS
```

Contoh output:

```text
    CON_ID CON_NAME                       OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
         2 PDB$SEED                       READ ONLY  NO
         3 PDB1                           READ WRITE NO
         4 PDBLAB1                        MOUNTED
```

---

# LAB 2 — Membuka dan Menutup PDB

## 2.1 Buka PDB

```sql
ALTER PLUGGABLE DATABASE PDBLAB1 OPEN;
```

Contoh output:

```text
Pluggable database altered.
```

## 2.2 Verifikasi

```sql
SHOW PDBS
```

Contoh output:

```text
    CON_ID CON_NAME                       OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
         4 PDBLAB1                        READ WRITE NO
```

## 2.3 Tutup PDB

```sql
ALTER PLUGGABLE DATABASE PDBLAB1 CLOSE IMMEDIATE;
```

Contoh output:

```text
Pluggable database altered.
```

## 2.4 Verifikasi

```sql
SHOW PDBS
```

Contoh output:

```text
    CON_ID CON_NAME                       OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
         4 PDBLAB1                        MOUNTED
```

## 2.5 Buka kembali

```sql
ALTER PLUGGABLE DATABASE PDBLAB1 OPEN;
```

---

# LAB 3 — Menyimpan State PDB agar Otomatis Open

## 3.1 Save state

```sql
ALTER PLUGGABLE DATABASE PDBLAB1 SAVE STATE;
```

Contoh output:

```text
Pluggable database altered.
```

## 3.2 Verifikasi

```sql
COLUMN con_name FORMAT A20
COLUMN state FORMAT A15

SELECT con_name, state
FROM dba_pdb_saved_states
WHERE con_name = 'PDBLAB1';
```

Contoh output:

```text
CON_NAME             STATE
-------------------- ---------------
PDBLAB1              OPEN
```

---

# LAB 4 — Masuk ke PDB dan Cek Struktur File

## 4.1 Masuk ke PDB

```sql
ALTER SESSION SET CONTAINER=PDBLAB1;
```

Verifikasi:

```sql
SHOW CON_NAME
```

Contoh output:

```text
CON_NAME
------------------------------
PDBLAB1
```

## 4.2 Lihat datafile PDB

```sql
SET LINESIZE 200
COLUMN name FORMAT A90

SELECT file#, name
FROM v$datafile
ORDER BY file#;
```

Contoh output:

```text
     FILE# NAME
---------- ------------------------------------------------------------------------------------------
        12 /u01/app/oracle/oradata/ORADB/PDBLAB1/system01.dbf
        13 /u01/app/oracle/oradata/ORADB/PDBLAB1/sysaux01.dbf
        14 /u01/app/oracle/oradata/ORADB/PDBLAB1/undotbs01.dbf
```

## 4.3 Lihat tempfile

```sql
COLUMN name FORMAT A90

SELECT file#, name
FROM v$tempfile
ORDER BY file#;
```

Contoh output:

```text
     FILE# NAME
---------- ------------------------------------------------------------------------------------------
         3 /u01/app/oracle/oradata/ORADB/PDBLAB1/temp012026-07-03_10-20-15-123-AM.dbf
```

---

# LAB 5 — Membuat Tablespace Aplikasi di PDB

## 5.1 Buat tablespace

```sql
CREATE TABLESPACE TS_APP_PDB
DATAFILE '/u01/app/oracle/oradata/ORADB/PDBLAB1/ts_app_pdb01.dbf'
SIZE 100M
AUTOEXTEND OFF;
```

Contoh output:

```text
Tablespace created.
```

## 5.2 Verifikasi

```sql
SELECT tablespace_name,
       file_name,
       bytes/1024/1024 AS size_mb,
       autoextensible
FROM dba_data_files
WHERE tablespace_name = 'TS_APP_PDB';
```

Contoh output:

```text
TABLESPACE_NAME      FILE_NAME                                                     SIZE_MB AUTOEXTENSIBLE
-------------------- ------------------------------------------------------------- ------- --------------
TS_APP_PDB           /u01/app/oracle/oradata/ORADB/PDBLAB1/ts_app_pdb01.dbf            100 NO
```

---

# LAB 6 — Resize Manual Datafile di Dalam PDB

## 6.1 Perbesar datafile

```sql
ALTER DATABASE DATAFILE
'/u01/app/oracle/oradata/ORADB/PDBLAB1/ts_app_pdb01.dbf'
RESIZE 150M;
```

Contoh output:

```text
Database altered.
```

## 6.2 Verifikasi

```sql
SELECT file_name,
       bytes/1024/1024 AS size_mb
FROM dba_data_files
WHERE tablespace_name = 'TS_APP_PDB';
```

Contoh output:

```text
FILE_NAME                                                     SIZE_MB
------------------------------------------------------------- -------
/u01/app/oracle/oradata/ORADB/PDBLAB1/ts_app_pdb01.dbf            150
```

---

# LAB 7 — Resize Otomatis dengan Autoextend

## 7.1 Aktifkan autoextend

```sql
ALTER DATABASE DATAFILE
'/u01/app/oracle/oradata/ORADB/PDBLAB1/ts_app_pdb01.dbf'
AUTOEXTEND ON
NEXT 10M
MAXSIZE 500M;
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
FROM dba_data_files
WHERE tablespace_name = 'TS_APP_PDB';
```

Contoh output:

```text
FILE_NAME                                                     SIZE_MB AUTOEXTENSIBLE NEXT_MB MAX_MB
------------------------------------------------------------- ------- -------------- ------- ------
/u01/app/oracle/oradata/ORADB/PDBLAB1/ts_app_pdb01.dbf            150 YES                 10    500
```

---

# LAB 8 — Menambahkan Datafile pada PDB

## 8.1 Tambahkan datafile

```sql
ALTER TABLESPACE TS_APP_PDB
ADD DATAFILE '/u01/app/oracle/oradata/ORADB/PDBLAB1/ts_app_pdb02.dbf'
SIZE 50M
AUTOEXTEND ON
NEXT 10M
MAXSIZE 200M;
```

Contoh output:

```text
Tablespace altered.
```

## 8.2 Verifikasi

```sql
SELECT tablespace_name,
       file_name,
       bytes/1024/1024 AS size_mb,
       autoextensible
FROM dba_data_files
WHERE tablespace_name = 'TS_APP_PDB'
ORDER BY file_name;
```

Contoh output:

```text
TABLESPACE_NAME      FILE_NAME                                                     SIZE_MB AUTOEXTENSIBLE
-------------------- ------------------------------------------------------------- ------- --------------
TS_APP_PDB           /u01/app/oracle/oradata/ORADB/PDBLAB1/ts_app_pdb01.dbf            150 YES
TS_APP_PDB           /u01/app/oracle/oradata/ORADB/PDBLAB1/ts_app_pdb02.dbf             50 YES
```

---

# LAB 9 — Membatasi Ukuran Storage PDB

Fitur ini berguna untuk membatasi total storage yang dapat digunakan PDB.

## 9.1 Kembali ke root

```sql
ALTER SESSION SET CONTAINER=CDB$ROOT;
```

## 9.2 Set storage limit PDB

```sql
ALTER PLUGGABLE DATABASE PDBLAB1 STORAGE (MAXSIZE 2G);
```

Contoh output:

```text
Pluggable database altered.
```

## 9.3 Verifikasi storage limit

```sql
COLUMN pdb_name FORMAT A20

SELECT p.name AS pdb_name,
       ROUND(SUM(df.bytes)/1024/1024,2) AS current_mb,
       ROUND(SUM(df.maxbytes)/1024/1024,2) AS max_mb
FROM v$pdbs p
JOIN cdb_data_files df
  ON p.con_id = df.con_id
WHERE p.name = 'PDBLAB1'
GROUP BY p.name;
```

Contoh output:

```text
PDB_NAME             STORAGE_MB     MAX_MB
-------------------- ---------- ----------
PDBLAB1                     520       2048
```

---

# LAB 10 — Membuat User dan Object di PDB

## 10.1 Masuk ke PDB

```sql
ALTER SESSION SET CONTAINER=PDBLAB1;
```

## 10.2 Buat user

```sql
CREATE USER app_pdb IDENTIFIED BY oracle
DEFAULT TABLESPACE TS_APP_PDB
TEMPORARY TABLESPACE TEMP
QUOTA UNLIMITED ON TS_APP_PDB;
```

Contoh output:

```text
User created.
```

## 10.3 Grant privilege

```sql
GRANT CREATE SESSION, CREATE TABLE TO app_pdb;
```

Contoh output:

```text
Grant succeeded.
```

## 10.4 Login sebagai user aplikasi

```sql
CONN app_pdb/oracle@localhost:1521/pdblab1.localdomain
```

Contoh output:

```text
Connected.
```

## 10.5 Buat tabel testing

```sql
CREATE TABLE transaksi_pdb (
    id NUMBER,
    keterangan VARCHAR2(100)
);
```

Contoh output:

```text
Table created.
```

## 10.6 Insert data

```sql
INSERT INTO transaksi_pdb
SELECT LEVEL, 'DATA PDB KE-' || LEVEL
FROM dual
CONNECT BY LEVEL <= 1000;

COMMIT;
```

Contoh output:

```text
1000 rows created.

Commit complete.
```

## 10.7 Verifikasi data

```sql
SELECT COUNT(*) FROM transaksi_pdb;
```

Contoh output:

```text
  COUNT(*)
----------
      1000
```

---

# LAB 11 — Clone PDB Lokal

## 11.1 Kembali ke root

```sql
CONN / AS SYSDBA
```

## 11.2 Pastikan source PDB open read write

```sql
ALTER PLUGGABLE DATABASE PDBLAB1 OPEN;
```

Jika sudah open, bisa muncul:

```text
ORA-65019: pluggable database PDBLAB1 already open
```

Itu tidak masalah.

## 11.3 Buat folder clone

```bash
mkdir -p /u01/app/oracle/oradata/ORADB/PDBLAB2
```

## 11.4 Clone PDB

```sql
CREATE PLUGGABLE DATABASE PDBLAB2
FROM PDBLAB1
FILE_NAME_CONVERT = (
'/u01/app/oracle/oradata/ORADB/PDBLAB1/',
'/u01/app/oracle/oradata/ORADB/PDBLAB2/'
);
```

Contoh output:

```text
Pluggable database created.
```

## 11.5 Buka PDB hasil clone

```sql
ALTER PLUGGABLE DATABASE PDBLAB2 OPEN;
```

Contoh output:

```text
Pluggable database altered.
```

## 11.6 Verifikasi

```sql
SHOW PDBS
```

Contoh output:

```text
    CON_ID CON_NAME                       OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
         4 PDBLAB1                        READ WRITE NO
         5 PDBLAB2                        READ WRITE NO
```

## 11.7 Cek data hasil clone

```sql
ALTER SESSION SET CONTAINER=PDBLAB2;

SELECT COUNT(*) FROM app_pdb.transaksi_pdb;
```

Contoh output:

```text
  COUNT(*)
----------
      1000
```

---

# LAB 12 — Membuat PDB Snapshot Copy

Catatan: snapshot copy memerlukan storage yang mendukung sparse file atau fitur copy-on-write. Jika environment tidak mendukung, command bisa gagal.

## 12.1 Kembali ke root

```sql
ALTER SESSION SET CONTAINER=CDB$ROOT;
```

## 12.2 Buat snapshot copy

```sql
CREATE PLUGGABLE DATABASE PDBLAB_SNAP
FROM PDBLAB1
SNAPSHOT COPY
FILE_NAME_CONVERT = (
'/u01/app/oracle/oradata/ORADB/PDBLAB1/',
'/u01/app/oracle/oradata/ORADB/PDBLAB_SNAP/'
);
```

Contoh output jika berhasil:

```text
Pluggable database created.
```

Contoh error jika storage tidak mendukung:

```text
ORA-17517: Database cloning using storage snapshot failed
```

---

# LAB 13 — Rename PDB

PDB harus dalam kondisi mounted.

## 13.1 Close PDBLAB2

```sql
ALTER SESSION SET CONTAINER=CDB$ROOT;

ALTER PLUGGABLE DATABASE PDBLAB2 CLOSE IMMEDIATE;
```

Contoh output:

```text
Pluggable database altered.
```

## 13.2 Open restricted

```sql
ALTER PLUGGABLE DATABASE PDBLAB2 OPEN RESTRICTED;
```

Contoh output:

```text
Pluggable database altered.
```

## 13.3 Masuk ke PDBLAB2

```sql
ALTER SESSION SET CONTAINER=PDBLAB2;
```

## 13.4 Rename global name

```sql
ALTER PLUGGABLE DATABASE PDBLAB2 RENAME GLOBAL_NAME TO PDBLAB2_RENAME;
```

Contoh output:

```text
Pluggable database altered.
```

## 13.5 Kembali ke root dan buka normal

```sql
ALTER SESSION SET CONTAINER=CDB$ROOT;

ALTER PLUGGABLE DATABASE PDBLAB2_RENAME CLOSE IMMEDIATE;

ALTER PLUGGABLE DATABASE PDBLAB2_RENAME OPEN;
```

Contoh output:

```text
Pluggable database altered.
```

## 13.6 Verifikasi

```sql
SHOW PDBS
```

Contoh output:

```text
    CON_ID CON_NAME                       OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
         5 PDBLAB2_RENAME                 READ WRITE NO
```

---

# LAB 14 — Memindahkan Lokasi Datafile PDB Secara Online

## 14.1 Buat folder tujuan

```bash
mkdir -p /u01/app/oracle/oradata/ORADB/PDBLAB1_MOVED
```

## 14.2 Masuk ke PDB

```sql
CONN / AS SYSDBA

ALTER SESSION SET CONTAINER=PDBLAB1;
```

## 14.3 Cek file sebelum dipindahkan

```sql
SELECT name
FROM v$datafile
ORDER BY file#;
```

Contoh output:

```text
NAME
--------------------------------------------------------------------------------
/u01/app/oracle/oradata/ORADB/PDBLAB1/system01.dbf
/u01/app/oracle/oradata/ORADB/PDBLAB1/sysaux01.dbf
/u01/app/oracle/oradata/ORADB/PDBLAB1/undotbs01.dbf
/u01/app/oracle/oradata/ORADB/PDBLAB1/ts_app_pdb01.dbf
/u01/app/oracle/oradata/ORADB/PDBLAB1/ts_app_pdb02.dbf
```

## 14.4 Move datafile aplikasi

```sql
ALTER DATABASE MOVE DATAFILE
'/u01/app/oracle/oradata/ORADB/PDBLAB1/ts_app_pdb02.dbf'
TO
'/u01/app/oracle/oradata/ORADB/PDBLAB1_MOVED/ts_app_pdb02.dbf';
```

Contoh output:

```text
Database altered.
```

## 14.5 Verifikasi lokasi baru

```sql
SELECT file_name
FROM dba_data_files
WHERE tablespace_name = 'TS_APP_PDB'
ORDER BY file_name;
```

Contoh output:

```text
FILE_NAME
--------------------------------------------------------------------------------
/u01/app/oracle/oradata/ORADB/PDBLAB1/ts_app_pdb01.dbf
/u01/app/oracle/oradata/ORADB/PDBLAB1_MOVED/ts_app_pdb02.dbf
```

---

# LAB 15 — Relocate / Pindah Lokasi Semua File PDB dengan Unplug Plug

Lab ini mensimulasikan pemindahan PDB ke lokasi folder baru.

## 15.1 Kembali ke root

```sql
CONN / AS SYSDBA
```

## 15.2 Close PDB

```sql
ALTER PLUGGABLE DATABASE PDBLAB1 CLOSE IMMEDIATE;
```

Contoh output:

```text
Pluggable database altered.
```

## 15.3 Unplug PDB ke XML

```sql
ALTER PLUGGABLE DATABASE PDBLAB1
UNPLUG INTO '/u01/app/oracle/oradata/ORADB/PDBLAB1.xml';
```

Contoh output:

```text
Pluggable database altered.
```

## 15.4 Drop metadata PDB, datafile tetap disimpan

```sql
DROP PLUGGABLE DATABASE PDBLAB1 KEEP DATAFILES;
```

Contoh output:

```text
Pluggable database dropped.
```

## 15.5 Buat folder lokasi baru

```bash
mkdir -p /u01/app/oracle/oradata/ORADB/PDBLAB1_NEWLOC
```


## 15.6 Plug kembali PDB dengan COPY

```sql
CREATE PLUGGABLE DATABASE PDBLAB1
USING '/u01/app/oracle/oradata/ORADB/PDBLAB1.xml'
COPY
FILE_NAME_CONVERT = (
'/u01/app/oracle/oradata/ORADB/PDBLAB1/',
'/u01/app/oracle/oradata/ORADB/PDBLAB1_NEWLOC/',
'/u01/app/oracle/oradata/ORADB/PDBLAB1_MOVED/',
'/u01/app/oracle/oradata/ORADB/PDBLAB1_NEWLOC/'
);
```

Contoh output:

```text
Pluggable database created.
```

## 15.7 Buka PDB

```sql
ALTER PLUGGABLE DATABASE PDBLAB1 OPEN;
```

Contoh output:

```text
Pluggable database altered.
```

## 15.8 Verifikasi lokasi file

```sql
ALTER SESSION SET CONTAINER=PDBLAB1;

SELECT name
FROM v$datafile
ORDER BY file#;
```

Contoh output:

```text
NAME
--------------------------------------------------------------------------------
/u01/app/oracle/oradata/ORADB/PDBLAB1_NEWLOC/system01.dbf
/u01/app/oracle/oradata/ORADB/PDBLAB1_NEWLOC/sysaux01.dbf
/u01/app/oracle/oradata/ORADB/PDBLAB1_NEWLOC/undotbs01.dbf
/u01/app/oracle/oradata/ORADB/PDBLAB1_NEWLOC/ts_app_pdb01.dbf
/u01/app/oracle/oradata/ORADB/PDBLAB1_NEWLOC/ts_app_pdb02.dbf
```

---

# LAB 16 — Unplug PDB untuk Dipindahkan ke CDB Lain

## 16.1 Kembali ke root

```sql
CONN / AS SYSDBA
```

## 16.2 Close PDB

```sql
ALTER PLUGGABLE DATABASE PDBLAB2_RENAME CLOSE IMMEDIATE;
```

Contoh output:

```text
Pluggable database altered.
```

## 16.3 Unplug ke XML

```sql
ALTER PLUGGABLE DATABASE PDBLAB2_RENAME
UNPLUG INTO '/u01/app/oracle/oradata/ORADB/PDBLAB2_RENAME.xml';
```

Contoh output:

```text
Pluggable database altered.
```

## 16.4 Drop metadata, simpan datafile

```sql
DROP PLUGGABLE DATABASE PDBLAB2_RENAME KEEP DATAFILES;
```

Contoh output:

```text
Pluggable database dropped.
```

## 16.5 Verifikasi PDB hilang dari CDB

```sql
SHOW PDBS
```

Contoh output:

```text
    CON_ID CON_NAME                       OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
         2 PDB$SEED                       READ ONLY  NO
         3 PDB1                           READ WRITE NO
         4 PDBLAB1                        READ WRITE NO
```

---

# LAB 17 — Plug PDB Kembali dari XML

## 17.1 Cek kompatibilitas XML

```sql
SET SERVEROUTPUT ON

DECLARE
  compatible CONSTANT VARCHAR2(3) :=
    CASE DBMS_PDB.CHECK_PLUG_COMPATIBILITY(
      pdb_descr_file => '/u01/app/oracle/oradata/ORADB/PDBLAB2_RENAME.xml',
      pdb_name       => 'PDBLAB2_RENAME'
    )
    WHEN TRUE THEN 'YES'
    ELSE 'NO'
    END;
BEGIN
  DBMS_OUTPUT.PUT_LINE('Compatible: ' || compatible);
END;
/
```

Contoh output:

```text
Compatible: YES

PL/SQL procedure successfully completed.
```

## 17.2 Plug kembali dengan NOCOPY

```sql
CREATE PLUGGABLE DATABASE PDBLAB2_RENAME
USING '/u01/app/oracle/oradata/ORADB/PDBLAB2_RENAME.xml'
NOCOPY;
```

Contoh output:

```text
Pluggable database created.
```

## 17.3 Buka PDB

```sql
ALTER PLUGGABLE DATABASE PDBLAB2_RENAME OPEN;
```

Contoh output:

```text
Pluggable database altered.
```

## 17.4 Verifikasi

```sql
SHOW PDBS
```

Contoh output:

```text
    CON_ID CON_NAME                       OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
         5 PDBLAB2_RENAME                 READ WRITE NO
```

---

# LAB 18 — Membuat PDB dengan OMF

OMF membuat file database otomatis tanpa perlu menulis nama datafile manual.

## 18.1 Set OMF

```sql
CONN / AS SYSDBA

ALTER SYSTEM SET db_create_file_dest='/u01/app/oracle/oradata' SCOPE=BOTH;
```

Contoh output:

```text
System altered.
```

## 18.2 Buat PDB OMF

```sql
CREATE PLUGGABLE DATABASE PDBOMF
ADMIN USER pdbadmin IDENTIFIED BY oracle;
```

Contoh output:

```text
Pluggable database created.
```

## 18.3 Open PDB

```sql
ALTER PLUGGABLE DATABASE PDBOMF OPEN;
```

Contoh output:

```text
Pluggable database altered.
```

## 18.4 Verifikasi file OMF

```sql
ALTER SESSION SET CONTAINER=PDBOMF;

SELECT name
FROM v$datafile
ORDER BY file#;
```

Contoh output:

```text
NAME
--------------------------------------------------------------------------------
/u01/app/oracle/oradata/ORADB/XXXXXXXXXXXX/datafile/o1_mf_system_xxxxx.dbf
/u01/app/oracle/oradata/ORADB/XXXXXXXXXXXX/datafile/o1_mf_sysaux_xxxxx.dbf
/u01/app/oracle/oradata/ORADB/XXXXXXXXXXXX/datafile/o1_mf_undotbs_xxxxx.dbf
```

---



# LAB 20 — Koneksi Langsung ke PDB

## 20.1 Cek listener service

Dari OS:

```bash
lsnrctl status
```

Contoh output:

```text
Service "PDBLAB1" has 1 instance(s).
Service "svc_pdblab1" has 1 instance(s).
```

## 20.2 Test koneksi ke service PDB

```bash
sqlplus app_pdb/oracle@localhost:1521/PDBLAB1
```

Contoh output:

```text
Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0
```

## 20.3 Test query

```sql
SHOW CON_NAME

SELECT COUNT(*) FROM transaksi_pdb;
```

Contoh output:

```text
CON_NAME
------------------------------
PDBLAB1

  COUNT(*)
----------
      1000
```

---

# LAB 21 — Menghapus PDB

## 21.1 Close PDB yang akan dihapus

```sql
CONN / AS SYSDBA

ALTER PLUGGABLE DATABASE PDBOMF CLOSE IMMEDIATE;
```

Contoh output:

```text
Pluggable database altered.
```

## 21.2 Drop PDB beserta datafile

```sql
DROP PLUGGABLE DATABASE PDBOMF INCLUDING DATAFILES;
```

Contoh output:

```text
Pluggable database dropped.
```

## 21.3 Verifikasi

```sql
SHOW PDBS
```

Contoh output:

```text
    CON_ID CON_NAME                       OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
         3 PDB1                           READ WRITE NO
         4 PDBLAB1                        READ WRITE NO
         5 PDBLAB2_RENAME                 READ WRITE NO
```

---

# LAB 22 — Drop PDB dengan KEEP DATAFILES

Gunakan jika ingin hanya menghapus metadata PDB dari CDB, tetapi file fisik tetap disimpan.

## 22.1 Close PDB

```sql
ALTER PLUGGABLE DATABASE PDBLAB2_RENAME CLOSE IMMEDIATE;
```

## 22.2 Drop metadata saja

```sql
--UNPLUG SEBELUM DROP, JIKA TIDAK DILAKUKAN, DROP AKAN GAGAL
ALTER PLUGGABLE DATABASE PDBLAB2_RENAME
UNPLUG INTO '/u01/app/oracle/oradata/ORADB/PDBLAB2_RENAME.xml';

--DROP
DROP PLUGGABLE DATABASE PDBLAB2_RENAME KEEP DATAFILES;
```

Contoh output:

```text
Pluggable database dropped.
```

## 22.3 Verifikasi file masih ada di OS

```bash
find /u01/app/oracle/oradata/ORADB -name "*PDBLAB2*" -o -name "*.dbf" | grep PDBLAB2
```

Contoh output:

```text
/u01/app/oracle/oradata/ORADB/PDBLAB2/system01.dbf
/u01/app/oracle/oradata/ORADB/PDBLAB2/sysaux01.dbf
/u01/app/oracle/oradata/ORADB/PDBLAB2/undotbs01.dbf
```

---

# LAB 23 — Monitoring Ukuran Seluruh PDB

## 23.1 Ukuran datafile per PDB

```sql
CONN / AS SYSDBA

COLUMN pdb_name FORMAT A20

SELECT p.name AS pdb_name,
       ROUND(SUM(df.bytes)/1024/1024,2) AS datafile_mb
FROM v$pdbs p
JOIN cdb_data_files df
ON p.con_id = df.con_id
GROUP BY p.name
ORDER BY p.name;
```

Contoh output:

```text
PDB_NAME             DATAFILE_MB
-------------------- -----------
PDB1                      975.00
PDBLAB1                  1120.00
```

## 23.2 Ukuran tempfile per PDB

```sql
SELECT p.name AS pdb_name,
       ROUND(SUM(tf.bytes)/1024/1024,2) AS tempfile_mb
FROM v$pdbs p
JOIN cdb_temp_files tf
ON p.con_id = tf.con_id
GROUP BY p.name
ORDER BY p.name;
```

Contoh output:

```text
PDB_NAME             TEMPFILE_MB
-------------------- -----------
PDB1                       36.00
PDBLAB1                    36.00
```

## 23.3 Status open mode PDB

```sql
SELECT con_id,
       name,
       open_mode,
       restricted
FROM v$pdbs
ORDER BY con_id;
```

Contoh output:

```text
    CON_ID NAME                           OPEN_MODE  RES
---------- ------------------------------ ---------- ---
         2 PDB$SEED                       READ ONLY  NO
         3 PDB1                           READ WRITE NO
         4 PDBLAB1                        READ WRITE NO
```

---

# LAB 24 — Cleanup PDB Lab

## 24.1 Close PDBLAB1

```sql
CONN / AS SYSDBA

ALTER PLUGGABLE DATABASE PDBLAB1 CLOSE IMMEDIATE;
```

Contoh output:

```text
Pluggable database altered.
```

## 24.2 Drop PDBLAB1 beserta datafile

```sql
DROP PLUGGABLE DATABASE PDBLAB1 INCLUDING DATAFILES;
```

Contoh output:

```text
Pluggable database dropped.
```

## 24.3 Jika PDB snapshot berhasil dibuat, hapus juga

```sql
ALTER PLUGGABLE DATABASE PDBLAB_SNAP CLOSE IMMEDIATE;
DROP PLUGGABLE DATABASE PDBLAB_SNAP INCLUDING DATAFILES;
```

Contoh output:

```text
Pluggable database altered.
Pluggable database dropped.
```

## 24.4 Verifikasi akhir

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

---

# Ringkasan Command Penting

```sql
CREATE PLUGGABLE DATABASE PDBLAB1
ADMIN USER pdbadmin IDENTIFIED BY oracle
FILE_NAME_CONVERT = (
'/u01/app/oracle/oradata/ORADB/pdbseed/',
'/u01/app/oracle/oradata/ORADB/PDBLAB1/'
);
```

```sql
ALTER PLUGGABLE DATABASE PDBLAB1 OPEN;
```

```sql
ALTER PLUGGABLE DATABASE PDBLAB1 CLOSE IMMEDIATE;
```

```sql
ALTER PLUGGABLE DATABASE PDBLAB1 SAVE STATE;
```

```sql
CREATE PLUGGABLE DATABASE PDBLAB2
FROM PDBLAB1
FILE_NAME_CONVERT = (
'/u01/app/oracle/oradata/ORADB/PDBLAB1/',
'/u01/app/oracle/oradata/ORADB/PDBLAB2/'
);
```

```sql
ALTER PLUGGABLE DATABASE PDBLAB1
UNPLUG INTO '/u01/app/oracle/oradata/ORADB/PDBLAB1.xml';
```

```sql
DROP PLUGGABLE DATABASE PDBLAB1 KEEP DATAFILES;
```

```sql
DROP PLUGGABLE DATABASE PDBLAB1 INCLUDING DATAFILES;
```

```sql
CREATE PLUGGABLE DATABASE PDBLAB1
USING '/u01/app/oracle/oradata/ORADB/PDBLAB1.xml'
NOCOPY;
```

```sql
ALTER PLUGGABLE DATABASE PDBLAB1 STORAGE (MAXSIZE 2G);
```

```sql
ALTER DATABASE MOVE DATAFILE
'/lokasi_lama/file.dbf'
TO
'/lokasi_baru/file.dbf';
```

```sql
ALTER DATABASE DATAFILE
'/lokasi/file.dbf'
RESIZE 500M;
```

```sql
ALTER DATABASE DATAFILE
'/lokasi/file.dbf'
AUTOEXTEND ON NEXT 50M MAXSIZE 2G;
```

---

Catatan penting: **PDB sendiri tidak di-resize langsung seperti datafile**. Yang dapat di-resize adalah **datafile/tempfile di dalam PDB**, atau dibatasi kapasitas totalnya menggunakan `ALTER PLUGGABLE DATABASE ... STORAGE (MAXSIZE ...)`.
