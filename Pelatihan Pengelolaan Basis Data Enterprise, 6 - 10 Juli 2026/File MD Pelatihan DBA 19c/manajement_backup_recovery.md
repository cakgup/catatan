---

# HANDS-ON LAB

# Backup & Recovery Oracle 19c CDB/PDB

Asumsi:

```text
CDB     : ORADB
PDB     : PDB1
OS      : Oracle Linux
User OS : oracle
Mode    : ARCHIVELOG
```

## 0. Persiapan Awal

```bash
su - oracle
sqlplus / as sysdba
```

Verifikasi database:

```sql
SELECT name, cdb, log_mode, open_mode
FROM v$database;
```

Contoh output:

```text
NAME      CDB LOG_MODE     OPEN_MODE
--------- --- ------------ --------------------
ORADB     YES ARCHIVELOG   READ WRITE
```

Verifikasi PDB:

```sql
SHOW PDBS
```

Contoh output:

```text
    CON_ID CON_NAME                       OPEN MODE
---------- ------------------------------ ----------
         2 PDB$SEED                       READ ONLY
         3 PDB1                           READ WRITE
```

Jika belum `ARCHIVELOG`, aktifkan:

```sql
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;
ALTER PLUGGABLE DATABASE ALL OPEN;
```

Verifikasi:

```sql
ARCHIVE LOG LIST;
```

Contoh output:

```text
Database log mode              Archive Mode
Automatic archival             Enabled
```

---

# BAGIAN A

# Persiapan Data Lab

## A.1 Masuk ke PDB1

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

## A.2 Buat tablespace lab

```sql
CREATE TABLESPACE TS_BKP_LAB
DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/ts_bkp_lab01.dbf'
SIZE 100M
AUTOEXTEND ON
NEXT 50M
MAXSIZE 1G;
```

Contoh output:

```text
Tablespace created.
```

## A.3 Buat user lab

```sql
CREATE USER bkpuser IDENTIFIED BY oracle
DEFAULT TABLESPACE TS_BKP_LAB
TEMPORARY TABLESPACE TEMP
QUOTA UNLIMITED ON TS_BKP_LAB;
```

Contoh output:

```text
User created.
```

## A.4 Grant privilege

```sql
GRANT CREATE SESSION, CREATE TABLE TO bkpuser;
```

Contoh output:

```text
Grant succeeded.
```

## A.5 Buat tabel dan data awal

```sql
CONN bkpuser/oracle@localhost:1521/pdb1.localdomain

CREATE TABLE transaksi_backup (
    id NUMBER PRIMARY KEY,
    keterangan VARCHAR2(200),
    tanggal_input DATE DEFAULT SYSDATE
);

INSERT INTO transaksi_backup (id, keterangan)
SELECT LEVEL, 'DATA AWAL BACKUP KE-' || LEVEL
FROM dual
CONNECT BY LEVEL <= 1000;

COMMIT;
```

Contoh output:

```text
Table created.

1000 rows created.

Commit complete.
```

## A.6 Verifikasi data

```sql
SELECT COUNT(*) FROM transaksi_backup;
```

Contoh output:

```text
  COUNT(*)
----------
      1000
```

---

# BAGIAN B

# User Managed Backup & Recovery

User managed backup adalah backup manual menggunakan perintah OS seperti `cp`. Di Oracle, agar backup konsisten saat database masih online, tablespace dapat dibuat `BEGIN BACKUP` lalu disalin.

---

# LAB 1 — User Managed Backup Level Datafile

## 1.1 Buat folder backup

```bash
mkdir -p /home/oracle/backup/user_managed/datafile
```

Verifikasi:

```bash
ls -ld /home/oracle/backup/user_managed/datafile
```

Contoh output:

```text
drwxr-xr-x. 2 oracle oinstall 6 Jul 4 13:00 /home/oracle/backup/user_managed/datafile
```

## 1.2 Cek lokasi datafile

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

SELECT file_name
FROM dba_data_files
WHERE tablespace_name = 'TS_BKP_LAB';
```

Contoh output:

```text
FILE_NAME
--------------------------------------------------------------------------------
/u01/app/oracle/oradata/ORADB/pdb1/ts_bkp_lab01.dbf
```

## 1.3 Backup online datafile dengan BEGIN BACKUP

```sql
ALTER TABLESPACE TS_BKP_LAB BEGIN BACKUP;
```

Contoh output:

```text
Tablespace altered.
```

Copy file dari OS:

```bash
cp /u01/app/oracle/oradata/ORADB/pdb1/ts_bkp_lab01.dbf \
/home/oracle/backup/user_managed/datafile/ts_bkp_lab01.dbf.bak
```

Selesai backup mode:

```sql
ALTER TABLESPACE TS_BKP_LAB END BACKUP;
```

Contoh output:

```text
Tablespace altered.
```

## 1.4 Archive current redo

```sql
ALTER SYSTEM ARCHIVE LOG CURRENT;
```

Contoh output:

```text
System altered.
```

## 1.5 Verifikasi file backup

```bash
ls -lh /home/oracle/backup/user_managed/datafile/ts_bkp_lab01.dbf.bak
```

Contoh output:

```text
-rw-r-----. 1 oracle oinstall 101M Jul 4 13:05 /home/oracle/backup/user_managed/datafile/ts_bkp_lab01.dbf.bak
```

---

# LAB 2 — Simulasi Failure Datafile

## 2.1 Tambahkan data setelah backup

```sql
CONN bkpuser/oracle@localhost:1521/pdb1.localdomain

INSERT INTO transaksi_backup (id, keterangan)
SELECT LEVEL + 1000, 'DATA SETELAH BACKUP KE-' || LEVEL
FROM dual
CONNECT BY LEVEL <= 500;

COMMIT;
```

Contoh output:

```text
500 rows created.

Commit complete.
```

Verifikasi:

```sql
SELECT COUNT(*) FROM transaksi_backup;
```

Contoh output:

```text
  COUNT(*)
----------
      1500
```

## 2.2 Simulasikan datafile hilang

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

ALTER TABLESPACE TS_BKP_LAB OFFLINE IMMEDIATE;
```

Contoh output:

```text
Tablespace altered.
```

Hapus file dari OS:

```bash
mv /u01/app/oracle/oradata/ORADB/pdb1/ts_bkp_lab01.dbf \
/u01/app/oracle/oradata/ORADB/pdb1/ts_bkp_lab01.dbf.failed
```

Verifikasi:

```bash
ls -lh /u01/app/oracle/oradata/ORADB/pdb1/ts_bkp_lab01.dbf*
```

Contoh output:

```text
-rw-r-----. 1 oracle oinstall 151M Jul 4 13:15 ts_bkp_lab01.dbf.failed
```

## 2.3 Coba akses tabel

```sql
CONN bkpuser/oracle@localhost:1521/pdb1.localdomain

SELECT COUNT(*) FROM transaksi_backup;
```

Contoh error:

```text
ORA-00376: file cannot be read at this time
ORA-01110: data file ... '/u01/app/oracle/oradata/ORADB/pdb1/ts_bkp_lab01.dbf'
```

---

# LAB 3 — Restore & Recovery User Managed Datafile

## 3.1 Restore file dari backup OS

```bash
cp /home/oracle/backup/user_managed/datafile/ts_bkp_lab01.dbf.bak \
/u01/app/oracle/oradata/ORADB/pdb1/ts_bkp_lab01.dbf
```

Verifikasi:

```bash
ls -lh /u01/app/oracle/oradata/ORADB/pdb1/ts_bkp_lab01.dbf
```

Contoh output:

```text
-rw-r-----. 1 oracle oinstall 101M Jul 4 13:20 /u01/app/oracle/oradata/ORADB/pdb1/ts_bkp_lab01.dbf
```

## 3.2 Recover datafile

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

RECOVER DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/ts_bkp_lab01.dbf';
```

Contoh output:

```text
Media recovery complete.
```

## 3.3 Online-kan tablespace

```sql
ALTER TABLESPACE TS_BKP_LAB ONLINE;
```

Contoh output:

```text
Tablespace altered.
```

## 3.4 Verifikasi data kembali

```sql
CONN bkpuser/oracle@localhost:1521/pdb1.localdomain

SELECT COUNT(*) FROM transaksi_backup;
```

Contoh output:

```text
  COUNT(*)
----------
      1500
```

---

# LAB 4 — User Managed Backup Level Tablespace

## 4.1 Buat folder backup tablespace

```bash
mkdir -p /home/oracle/backup/user_managed/tablespace
```

## 4.2 Backup tablespace

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

ALTER TABLESPACE TS_BKP_LAB BEGIN BACKUP;
```

```bash
cp /u01/app/oracle/oradata/ORADB/pdb1/ts_bkp_lab01.dbf \
/home/oracle/backup/user_managed/tablespace/
```

```sql
ALTER TABLESPACE TS_BKP_LAB END BACKUP;
ALTER SYSTEM ARCHIVE LOG CURRENT;
```

Contoh output:

```text
Tablespace altered.
System altered.
```

## 4.3 Verifikasi backup

```bash
ls -lh /home/oracle/backup/user_managed/tablespace/
```

Contoh output:

```text
-rw-r-----. 1 oracle oinstall 151M Jul 4 13:30 ts_bkp_lab01.dbf
```

---

# LAB 5 — User Managed Backup Level Database

Backup level database manual paling sederhana dilakukan saat database shutdown konsisten.

## 5.1 Buat folder full backup

```bash
mkdir -p /home/oracle/backup/user_managed/full_db
```

## 5.2 Shutdown database

```sql
CONN / AS SYSDBA
SHUTDOWN IMMEDIATE;
```

Contoh output:

```text
Database closed.
Database dismounted.
ORACLE instance shut down.
```

## 5.3 Copy seluruh file database

```bash
cp -Rp /u01/app/oracle/oradata/ORADB/* /home/oracle/backup/user_managed/full_db/
```

## 5.4 Startup database

```sql
STARTUP;
ALTER PLUGGABLE DATABASE ALL OPEN;
```

Contoh output:

```text
Database mounted.
Database opened.
Pluggable database altered.
```

## 5.5 Verifikasi backup full database

```bash
find /home/oracle/backup/user_managed/full_db -type f | head
```

Contoh output:

```text
/home/oracle/backup/user_managed/full_db/system01.dbf
/home/oracle/backup/user_managed/full_db/sysaux01.dbf
/home/oracle/backup/user_managed/full_db/undotbs01.dbf
/home/oracle/backup/user_managed/full_db/PDB1/system01.dbf
/home/oracle/backup/user_managed/full_db/PDB1/sysaux01.dbf
```

---

# BAGIAN C

# RMAN Backup & Recovery

RMAN adalah metode backup yang direkomendasikan untuk Oracle.

---

# LAB 6 — Konfigurasi Awal RMAN

## 6.1 Masuk RMAN

```bash
rman target /
```

## 6.2 Cek konfigurasi

```rman
SHOW ALL;
```

Contoh output:

```text
RMAN configuration parameters for database with db_unique_name ORADB are:
CONFIGURE RETENTION POLICY TO REDUNDANCY 1;
CONFIGURE CONTROLFILE AUTOBACKUP OFF;
```

## 6.3 Set konfigurasi dasar

```rman
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE RETENTION POLICY TO REDUNDANCY 2;
CONFIGURE DEVICE TYPE DISK PARALLELISM 1;
```

Contoh output:

```text
new RMAN configuration parameters are successfully stored
```

Keluar:

```rman
EXIT;
```

---

# LAB 7 — RMAN Backup Level Database / CDB Full

## 7.1 Buat folder backup RMAN

```bash
mkdir -p /home/oracle/backup/rman/full_db
```

## 7.2 Backup full database dan archivelog

```bash
rman target /
```

```rman
BACKUP AS COMPRESSED BACKUPSET DATABASE
FORMAT '/home/oracle/backup/rman/full_db/db_full_%U.bkp'
PLUS ARCHIVELOG
FORMAT '/home/oracle/backup/rman/full_db/arch_%U.bkp';
```

Contoh output:

```text
Starting backup at 04-JUL-26
channel ORA_DISK_1: starting compressed full datafile backup set
channel ORA_DISK_1: piece handle=/home/oracle/backup/rman/full_db/db_full_xxxxx.bkp
Finished backup at 04-JUL-26

Starting backup at 04-JUL-26
channel ORA_DISK_1: archived log backup set complete
Finished backup at 04-JUL-26
```

## 7.3 Verifikasi backup

```rman
LIST BACKUP SUMMARY;
```

Contoh output:

```text
BS Key  Type LV Size       Device Type Elapsed Time Completion Time
------- ---- -- ---------- ----------- ------------ ---------------
1       Full    1.20G      DISK        00:02:10     04-JUL-26
2       Full    50.00M     DISK        00:00:08     04-JUL-26
```

Keluar:

```rman
EXIT;
```

Verifikasi dari OS:

```bash
ls -lh /home/oracle/backup/rman/full_db
```

Contoh output:

```text
-rw-r-----. 1 oracle oinstall 900M db_full_0a2b3c.bkp
-rw-r-----. 1 oracle oinstall  50M arch_0d2e3f.bkp
```

---

# LAB 8 — RMAN Backup Level PDB

## 8.1 Buat folder backup PDB

```bash
mkdir -p /home/oracle/backup/rman/pdb
```

## 8.2 Backup PDB1

```bash
rman target /
```

```rman
BACKUP PLUGGABLE DATABASE PDB1
FORMAT '/home/oracle/backup/rman/pdb/pdb1_%U.bkp';
```

Contoh output:

```text
Starting backup at 04-JUL-26
channel ORA_DISK_1: starting full datafile backup set
channel ORA_DISK_1: specifying datafile(s) in backup set
input datafile file number=8 name=/u01/app/oracle/oradata/ORADB/pdb1/system01.dbf
input datafile file number=9 name=/u01/app/oracle/oradata/ORADB/pdb1/sysaux01.dbf
input datafile file number=10 name=/u01/app/oracle/oradata/ORADB/pdb1/undotbs01.dbf
Finished backup at 04-JUL-26
```

## 8.3 Verifikasi backup PDB

```rman
LIST BACKUP OF PLUGGABLE DATABASE PDB1;
```

Contoh output:

```text
List of Backup Sets
===================

BS Key  Type LV Size
------- ---- -- ----------
3       Full    750.00M
```

Keluar:

```rman
EXIT;
```

---

# LAB 9 — RMAN Backup Level Tablespace

## 9.1 Buat folder backup tablespace

```bash
mkdir -p /home/oracle/backup/rman/tablespace
```

## 9.2 Backup tablespace PDB

```bash
rman target /
```

```rman
BACKUP TABLESPACE PDB1:TS_BKP_LAB
FORMAT '/home/oracle/backup/rman/tablespace/ts_bkp_lab_%U.bkp';
```

Contoh output:

```text
Starting backup at 04-JUL-26
channel ORA_DISK_1: starting full datafile backup set
input datafile file number=15 name=/u01/app/oracle/oradata/ORADB/pdb1/ts_bkp_lab01.dbf
Finished backup at 04-JUL-26
```

## 9.3 Verifikasi backup tablespace

```rman
LIST BACKUP OF TABLESPACE PDB1:TS_BKP_LAB;
```

Contoh output:

```text
BS Key  Type LV Size       Device Type
------- ---- -- ---------- -----------
4       Full    120.00M    DISK
```

Keluar:

```rman
EXIT;
```

---

# LAB 10 — RMAN Backup Level Datafile

## 10.1 Cari file number

```sql
sqlplus / as sysdba
```

```sql
ALTER SESSION SET CONTAINER=PDB1;

SELECT file_id, file_name
FROM dba_data_files
WHERE tablespace_name = 'TS_BKP_LAB';
```

Contoh output:

```text
   FILE_ID FILE_NAME
---------- -------------------------------------------------------------
        15 /u01/app/oracle/oradata/ORADB/pdb1/ts_bkp_lab01.dbf
```

## 10.2 Backup datafile dengan RMAN

```bash
mkdir -p /home/oracle/backup/rman/datafile
rman target /
```

```rman
BACKUP DATAFILE 15
FORMAT '/home/oracle/backup/rman/datafile/datafile15_%U.bkp';
```

Contoh output:

```text
Starting backup at 04-JUL-26
input datafile file number=00015 name=/u01/app/oracle/oradata/ORADB/pdb1/ts_bkp_lab01.dbf
Finished backup at 04-JUL-26
```

## 10.3 Verifikasi backup datafile

```rman
LIST BACKUP OF DATAFILE 15;
```

Contoh output:

```text
BS Key  Type LV Size
------- ---- -- ----------
5       Full    120.00M
```

Keluar:

```rman
EXIT;
```

---

# LAB 11 — RMAN Failure Datafile dan Recovery

## 11.1 Tambahkan data setelah backup RMAN

```sql
CONN bkpuser/oracle@localhost:1521/pdb1.localdomain

INSERT INTO transaksi_backup (id, keterangan)
SELECT LEVEL + 2000, 'DATA SETELAH RMAN BACKUP KE-' || LEVEL
FROM dual
CONNECT BY LEVEL <= 300;

COMMIT;

SELECT COUNT(*) FROM transaksi_backup;
```

Contoh output:

```text
300 rows created.

Commit complete.

  COUNT(*)
----------
      1800
```

## 11.2 Simulasikan kehilangan datafile

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

ALTER TABLESPACE TS_BKP_LAB OFFLINE IMMEDIATE;
```

```bash
mv /u01/app/oracle/oradata/ORADB/pdb1/ts_bkp_lab01.dbf \
/u01/app/oracle/oradata/ORADB/pdb1/ts_bkp_lab01.dbf.rman_failed
```

## 11.3 Restore dan recover datafile dengan RMAN

```bash
rman target /
```

```rman
RESTORE DATAFILE 15;
RECOVER DATAFILE 15;
```

Contoh output:

```text
Starting restore at 04-JUL-26
channel ORA_DISK_1: restored backup piece
Finished restore at 04-JUL-26

Starting recover at 04-JUL-26
media recovery complete
Finished recover at 04-JUL-26
```

Keluar:

```rman
EXIT;
```

## 11.4 Online-kan tablespace

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

ALTER TABLESPACE TS_BKP_LAB ONLINE;
```

Contoh output:

```text
Tablespace altered.
```

## 11.5 Verifikasi data

```sql
CONN bkpuser/oracle@localhost:1521/pdb1.localdomain

SELECT COUNT(*) FROM transaksi_backup;
```

Contoh output:

```text
  COUNT(*)
----------
      1800
```

---

# LAB 12 — RMAN Tablespace Recovery

## 12.1 Backup tablespace terbaru

```bash
rman target /
```

```rman
BACKUP TABLESPACE PDB1:TS_BKP_LAB
FORMAT '/home/oracle/backup/rman/tablespace/ts_bkp_lab_latest_%U.bkp';
```

Keluar:

```rman
EXIT;
```

## 12.2 Tambahkan data

```sql
CONN bkpuser/oracle@localhost:1521/pdb1.localdomain

INSERT INTO transaksi_backup (id, keterangan)
SELECT LEVEL + 3000, 'DATA SEBELUM FAILURE TABLESPACE KE-' || LEVEL
FROM dual
CONNECT BY LEVEL <= 200;

COMMIT;

SELECT COUNT(*) FROM transaksi_backup;
```

Contoh output:

```text
200 rows created.

Commit complete.

  COUNT(*)
----------
      2000
```

## 12.3 Simulasikan failure tablespace

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

ALTER TABLESPACE TS_BKP_LAB OFFLINE IMMEDIATE;
```

```bash
mv /u01/app/oracle/oradata/ORADB/pdb1/ts_bkp_lab01.dbf \
/u01/app/oracle/oradata/ORADB/pdb1/ts_bkp_lab01.dbf.ts_failed
```

## 12.4 Restore dan recover tablespace

```bash
rman target /
```

```rman
RESTORE TABLESPACE PDB1:TS_BKP_LAB;
RECOVER TABLESPACE PDB1:TS_BKP_LAB;
```

Contoh output:

```text
Starting restore at 04-JUL-26
restore complete

Starting recover at 04-JUL-26
media recovery complete
```

Keluar:

```rman
EXIT;
```

## 12.5 Online-kan tablespace

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

ALTER TABLESPACE TS_BKP_LAB ONLINE;
```

## 12.6 Verifikasi

```sql
CONN bkpuser/oracle@localhost:1521/pdb1.localdomain

SELECT COUNT(*) FROM transaksi_backup;
```

Contoh output:

```text
  COUNT(*)
----------
      2000
```

---

# LAB 13 — RMAN PDB Recovery

Skenario: restore/recover seluruh PDB1. Ini lebih besar dampaknya, karena PDB akan ditutup selama proses recovery.

## 13.1 Backup PDB1 terbaru

```bash
rman target /
```

```rman
BACKUP PLUGGABLE DATABASE PDB1
FORMAT '/home/oracle/backup/rman/pdb/pdb1_latest_%U.bkp'
PLUS ARCHIVELOG;
```

Keluar:

```rman
EXIT;
```

## 13.2 Simulasi failure pada datafile PDB

```sql
CONN / AS SYSDBA

ALTER PLUGGABLE DATABASE PDB1 CLOSE IMMEDIATE;
```

```bash
mv /u01/app/oracle/oradata/ORADB/pdb1/system01.dbf \
/u01/app/oracle/oradata/ORADB/pdb1/system01.dbf.failed
```

## 13.3 Coba open PDB

```sql
ALTER PLUGGABLE DATABASE PDB1 OPEN;
```

Contoh error:

```text
ORA-01157: cannot identify/lock data file
ORA-01110: data file ... '/u01/app/oracle/oradata/ORADB/pdb1/system01.dbf'
```

## 13.4 Restore dan recover PDB

```bash
rman target /
```

```rman
RESTORE PLUGGABLE DATABASE PDB1;
RECOVER PLUGGABLE DATABASE PDB1;
```

Contoh output:

```text
Starting restore at 04-JUL-26
restore complete

Starting recover at 04-JUL-26
media recovery complete
```

Keluar:

```rman
EXIT;
```

## 13.5 Open PDB

```sql
CONN / AS SYSDBA

ALTER PLUGGABLE DATABASE PDB1 OPEN;
```

Contoh output:

```text
Pluggable database altered.
```

## 13.6 Verifikasi data

```sql
CONN bkpuser/oracle@localhost:1521/pdb1.localdomain

SELECT COUNT(*) FROM transaksi_backup;
```

Contoh output:

```text
  COUNT(*)
----------
      2000
```

---

# LAB 14 — RMAN Full Database Restore & Recovery

Lab ini paling berat. Gunakan hanya di VM lab.

## 14.1 Backup full database terbaru

```bash
rman target /
```

```rman
BACKUP DATABASE PLUS ARCHIVELOG
FORMAT '/home/oracle/backup/rman/full_db/full_before_db_failure_%U.bkp';
```

Keluar:

```rman
EXIT;
```

## 14.2 Simulasi failure database

```sql
sqlplus / as sysdba
```

```sql
SHUTDOWN IMMEDIATE;
```

Rename beberapa datafile CDB:

```bash
mv /u01/app/oracle/oradata/ORADB/system01.dbf \
/u01/app/oracle/oradata/ORADB/system01.dbf.failed

mv /u01/app/oracle/oradata/ORADB/sysaux01.dbf \
/u01/app/oracle/oradata/ORADB/sysaux01.dbf.failed
```

## 14.3 Coba startup

```sql
STARTUP;
```

Contoh error:

```text
ORA-01157: cannot identify/lock data file
ORA-01110: data file 1: '/u01/app/oracle/oradata/ORADB/system01.dbf'
```

## 14.4 Restore dan recover database

```bash
rman target /
```

```rman
STARTUP MOUNT;
RESTORE DATABASE;
RECOVER DATABASE;
ALTER DATABASE OPEN;
```

Contoh output:

```text
database mounted

Starting restore at 04-JUL-26
restore complete

Starting recover at 04-JUL-26
media recovery complete

Statement processed
```

## 14.5 Buka PDB

```rman
SQL 'ALTER PLUGGABLE DATABASE ALL OPEN';
EXIT;
```

## 14.6 Verifikasi

```bash
sqlplus / as sysdba
```

```sql
SELECT name, open_mode FROM v$database;
SHOW PDBS;
```

Contoh output:

```text
NAME      OPEN_MODE
--------- --------------------
ORADB     READ WRITE

    CON_ID CON_NAME                       OPEN MODE
---------- ------------------------------ ----------
         3 PDB1                           READ WRITE
```

---

# BAGIAN D

# Logical Backup & Recovery dengan SQL Dump

Di Oracle, logical backup yang umum adalah **Data Pump**:

```text
expdp = export
impdp = import
```

Ini bukan backup fisik. Logical backup cocok untuk object/schema/table-level recovery.

---

# LAB 15 — Persiapan Directory Object Data Pump

## 15.1 Buat folder dump

```bash
mkdir -p /home/oracle/backup/datapump
```

## 15.2 Buat directory object di PDB1

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

CREATE OR REPLACE DIRECTORY DP_DIR AS '/home/oracle/backup/datapump';

GRANT READ, WRITE ON DIRECTORY DP_DIR TO bkpuser;
```

Contoh output:

```text
Directory created.

Grant succeeded.
```

## 15.3 Verifikasi directory

```sql
SELECT directory_name, directory_path
FROM dba_directories
WHERE directory_name = 'DP_DIR';
```

Contoh output:

```text
DIRECTORY_NAME       DIRECTORY_PATH
-------------------- ------------------------------
DP_DIR               /home/oracle/backup/datapump
```

---

# LAB 16 — Logical Backup Level Schema

## 16.1 Export schema BKPUSER

```bash
expdp bkpuser/oracle@localhost:1521/pdb1.localdomain \
schemas=BKPUSER \
directory=DP_DIR \
dumpfile=bkpuser_schema_%U.dmp \
logfile=bkpuser_schema_export.log
```

Contoh output:

```text
Starting "BKPUSER"."SYS_EXPORT_SCHEMA_01"
Processing object type SCHEMA_EXPORT/TABLE/TABLE_DATA
. . exported "BKPUSER"."TRANSAKSI_BACKUP" 2000 rows
Job "BKPUSER"."SYS_EXPORT_SCHEMA_01" successfully completed
```

## 16.2 Verifikasi file dump

```bash
ls -lh /home/oracle/backup/datapump
```

Contoh output:

```text
-rw-r-----. 1 oracle oinstall 1.2M bkpuser_schema_01.dmp
-rw-r-----. 1 oracle oinstall 5.5K bkpuser_schema_export.log
```

---

# LAB 17 — Logical Backup Level Table

## 17.1 Export satu tabel

```bash
expdp bkpuser/oracle@localhost:1521/pdb1.localdomain \
tables=BKPUSER.TRANSAKSI_BACKUP \
directory=DP_DIR \
dumpfile=transaksi_backup_table.dmp \
logfile=transaksi_backup_table_export.log
```

Contoh output:

```text
. . exported "BKPUSER"."TRANSAKSI_BACKUP" 2000 rows
Job "BKPUSER"."SYS_EXPORT_TABLE_01" successfully completed
```

## 17.2 Verifikasi dump

```bash
ls -lh /home/oracle/backup/datapump/transaksi_backup_table.dmp
```

Contoh output:

```text
-rw-r-----. 1 oracle oinstall 1.1M transaksi_backup_table.dmp
```

---

# LAB 18 — Logical Backup Level PDB Full

## 18.1 Export full PDB

```bash
expdp system/oracle@localhost:1521/pdb1.localdomain \
full=Y \
directory=DP_DIR \
dumpfile=pdb1_full_%U.dmp \
logfile=pdb1_full_export.log
```

Contoh output:

```text
Starting "SYSTEM"."SYS_EXPORT_FULL_01"
Processing object type DATABASE_EXPORT/SCHEMA/TABLE/TABLE_DATA
Job "SYSTEM"."SYS_EXPORT_FULL_01" successfully completed
```

---

# LAB 19 — Logical Recovery Table yang Terhapus

## 19.1 Drop table

```sql
CONN bkpuser/oracle@localhost:1521/pdb1.localdomain

DROP TABLE transaksi_backup PURGE;
```

Contoh output:

```text
Table dropped.
```

## 19.2 Verifikasi gagal akses

```sql
SELECT COUNT(*) FROM transaksi_backup;
```

Contoh error:

```text
ORA-00942: table or view does not exist
```

## 19.3 Import table dari dump

```bash
impdp bkpuser/oracle@localhost:1521/pdb1.localdomain \
tables=BKPUSER.TRANSAKSI_BACKUP \
directory=DP_DIR \
dumpfile=transaksi_backup_table.dmp \
logfile=transaksi_backup_table_import.log
```

Contoh output:

```text
Processing object type TABLE_EXPORT/TABLE/TABLE
Processing object type TABLE_EXPORT/TABLE/TABLE_DATA
. . imported "BKPUSER"."TRANSAKSI_BACKUP" 2000 rows
Job "BKPUSER"."SYS_IMPORT_TABLE_01" successfully completed
```

## 19.4 Verifikasi data kembali

```sql
CONN bkpuser/oracle@localhost:1521/pdb1.localdomain

SELECT COUNT(*) FROM transaksi_backup;
```

Contoh output:

```text
  COUNT(*)
----------
      2000
```

---

# LAB 20 — Logical Recovery Schema yang Terhapus

## 20.1 Drop user/schema

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

DROP USER bkpuser CASCADE;
```

Contoh output:

```text
User dropped.
```

Verifikasi:

```sql
SELECT username
FROM dba_users
WHERE username = 'BKPUSER';
```

Contoh output:

```text
no rows selected
```

## 20.2 Import schema kembali

Import dilakukan sebagai user yang punya privilege DBA, misalnya `system`.

```bash
impdp system/oracle@localhost:1521/pdb1.localdomain \
schemas=BKPUSER \
directory=DP_DIR \
dumpfile=bkpuser_schema_01.dmp \
logfile=bkpuser_schema_import.log
```

Contoh output:

```text
Processing object type SCHEMA_EXPORT/USER
Processing object type SCHEMA_EXPORT/TABLE/TABLE
Processing object type SCHEMA_EXPORT/TABLE/TABLE_DATA
. . imported "BKPUSER"."TRANSAKSI_BACKUP" 2000 rows
Job "SYSTEM"."SYS_IMPORT_SCHEMA_01" successfully completed
```

## 20.3 Unlock dan reset password jika perlu

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

ALTER USER bkpuser IDENTIFIED BY oracle ACCOUNT UNLOCK;
```

Contoh output:

```text
User altered.
```

## 20.4 Verifikasi schema dan data

```sql
CONN bkpuser/oracle@localhost:1521/pdb1.localdomain

SELECT COUNT(*) FROM transaksi_backup;
```

Contoh output:

```text
  COUNT(*)
----------
      2000
```

---

# LAB 21 — Logical Recovery dengan REMAP_SCHEMA

Skenario: restore data ke schema baru tanpa menimpa schema lama.

## 21.1 Buat schema target

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

CREATE USER bkpuser_restore IDENTIFIED BY oracle
DEFAULT TABLESPACE TS_BKP_LAB
TEMPORARY TABLESPACE TEMP
QUOTA UNLIMITED ON TS_BKP_LAB;

GRANT CREATE SESSION, CREATE TABLE TO bkpuser_restore;
```

Contoh output:

```text
User created.
Grant succeeded.
```

## 21.2 Import dengan remap schema

```bash
impdp system/oracle@localhost:1521/pdb1.localdomain \
schemas=BKPUSER \
directory=DP_DIR \
dumpfile=bkpuser_schema_01.dmp \
logfile=bkpuser_remap_import.log \
remap_schema=BKPUSER:BKPUSER_RESTORE
```

Contoh output:

```text
Processing object type SCHEMA_EXPORT/TABLE/TABLE
. . imported "BKPUSER_RESTORE"."TRANSAKSI_BACKUP" 2000 rows
Job "SYSTEM"."SYS_IMPORT_SCHEMA_01" successfully completed
```

## 21.3 Verifikasi schema restore

```sql
CONN bkpuser_restore/oracle@localhost:1521/pdb1.localdomain

SELECT COUNT(*) FROM transaksi_backup;
```

Contoh output:

```text
  COUNT(*)
----------
      2000
```

---

# BAGIAN E

# Verifikasi dan Monitoring Backup

## E.1 RMAN report schema

```bash
rman target /
```

```rman
REPORT SCHEMA;
```

Contoh output:

```text
Report of database schema for database with db_unique_name ORADB

File Size(MB) Tablespace        RB segs Datafile Name
---- -------- ----------------- ------- ------------------------------
1    910      SYSTEM            YES     /u01/app/oracle/oradata/ORADB/system01.dbf
...
15   150      TS_BKP_LAB        NO      /u01/app/oracle/oradata/ORADB/pdb1/ts_bkp_lab01.dbf
```

## E.2 RMAN validate database

```rman
VALIDATE DATABASE;
```

Contoh output:

```text
Starting validate at 04-JUL-26
validation complete
Finished validate at 04-JUL-26
```

## E.3 Crosscheck backup

```rman
CROSSCHECK BACKUP;
LIST EXPIRED BACKUP;
```

Contoh output:

```text
crosschecked backup piece: found to be 'AVAILABLE'
specification does not match any backup in the repository
```

Keluar:

```rman
EXIT;
```

---

# BAGIAN F

# Cleanup Lab

Jalankan hanya jika lab selesai dan ingin membersihkan object.

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

DROP USER bkpuser CASCADE;
DROP USER bkpuser_restore CASCADE;
DROP TABLESPACE TS_BKP_LAB INCLUDING CONTENTS AND DATAFILES;
DROP DIRECTORY DP_DIR;
```

Contoh output:

```text
User dropped.
User dropped.
Tablespace dropped.
Directory dropped.
```

Hapus file backup lab:

```bash
rm -rf /home/oracle/backup/user_managed
rm -rf /home/oracle/backup/rman
rm -rf /home/oracle/backup/datapump
```

Verifikasi:

```bash
ls -ld /home/oracle/backup/user_managed /home/oracle/backup/rman /home/oracle/backup/datapump
```

Contoh output:

```text
ls: cannot access '/home/oracle/backup/user_managed': No such file or directory
ls: cannot access '/home/oracle/backup/rman': No such file or directory
ls: cannot access '/home/oracle/backup/datapump': No such file or directory
```

---

# Ringkasan Command Penting

User managed online backup:

```sql
ALTER TABLESPACE TS_BKP_LAB BEGIN BACKUP;
```

```bash
cp datafile.dbf /backup/location/
```

```sql
ALTER TABLESPACE TS_BKP_LAB END BACKUP;
ALTER SYSTEM ARCHIVE LOG CURRENT;
```

User managed recovery:

```bash
cp backup_file.dbf original_location.dbf
```

```sql
RECOVER DATAFILE 'original_location.dbf';
ALTER TABLESPACE TS_BKP_LAB ONLINE;
```

RMAN full backup:

```rman
BACKUP DATABASE PLUS ARCHIVELOG;
```

RMAN PDB backup:

```rman
BACKUP PLUGGABLE DATABASE PDB1;
```

RMAN tablespace backup:

```rman
BACKUP TABLESPACE PDB1:TS_BKP_LAB;
```

RMAN datafile backup:

```rman
BACKUP DATAFILE 15;
```

RMAN recovery:

```rman
RESTORE DATAFILE 15;
RECOVER DATAFILE 15;
```

Logical export:

```bash
expdp bkpuser/oracle@localhost:1521/pdb1.localdomain schemas=BKPUSER directory=DP_DIR dumpfile=bkpuser_schema.dmp logfile=export.log
```

Logical import:

```bash
impdp system/oracle@localhost:1521/pdb1.localdomain schemas=BKPUSER directory=DP_DIR dumpfile=bkpuser_schema.dmp logfile=import.log
```

Catatan: untuk **backup fisik dan recovery media failure**, gunakan RMAN. Untuk **restore object/schema/table**, gunakan Data Pump.
