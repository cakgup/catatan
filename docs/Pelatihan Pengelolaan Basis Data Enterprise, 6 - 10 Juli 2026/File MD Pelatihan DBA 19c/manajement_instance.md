# HANDS-ON LAB

# Instance, PFILE, dan SPFILE Management Oracle 19c CDB/PDB

Asumsi:

```text
Database : ORADB
CDB      : ORADB
PDB      : PDB1
OS       : Oracle Linux
User OS  : oracle
ORACLE_SID : ORADB
```

---

# 0. Persiapan Awal

Login sebagai user `oracle`.

```bash
su - oracle
```

Cek environment.

```bash
echo $ORACLE_SID
echo $ORACLE_HOME
```

Contoh output:

```text
ORADB
/u01/app/oracle/product/19.0.0/dbhome_1
```

Masuk SQL*Plus.

```bash
sqlplus / as sysdba
```

Verifikasi database.

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

Verifikasi instance.

```sql
SELECT instance_name,
       status,
       database_status,
       startup_time
FROM v$instance;
```

Contoh output:

```text
INSTANCE_NAME    STATUS       DATABASE_STATUS   STARTUP_TIME
---------------- ------------ ----------------- ------------------
ORADB            OPEN         ACTIVE            04-JUL-26
```

---

# LAB 1 — Melihat Status CDB dan PDB

```sql
SHOW CON_NAME
```

Contoh output:

```text
CON_NAME
------------------------------
CDB$ROOT
```

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

Verifikasi dari view:

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
```

---

# LAB 2 — Startup dan Shutdown Instance

## 2.1 Shutdown immediate

```sql
SHUTDOWN IMMEDIATE;
```

Contoh output:

```text
Database closed.
Database dismounted.
ORACLE instance shut down.
```

## 2.2 Startup database

```sql
STARTUP;
```

Contoh output:

```text
ORACLE instance started.

Database mounted.
Database opened.
```

## 2.3 Verifikasi status instance

```sql
SELECT instance_name,
       status,
       database_status
FROM v$instance;
```

Contoh output:

```text
INSTANCE_NAME    STATUS       DATABASE_STATUS
---------------- ------------ -----------------
ORADB            OPEN         ACTIVE
```

## 2.4 Verifikasi PDB setelah startup

```sql
SHOW PDBS
```

Contoh output:

```text
    CON_ID CON_NAME                       OPEN MODE
---------- ------------------------------ ----------
         2 PDB$SEED                       READ ONLY
         3 PDB1                           MOUNTED
```

Jika PDB belum open, buka semua PDB:

```sql
ALTER PLUGGABLE DATABASE ALL OPEN;
```

Contoh output:

```text
Pluggable database altered.
```

Verifikasi:

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

---

# LAB 3 — Startup Bertahap: NOMOUNT, MOUNT, OPEN

## 3.1 Shutdown database

```sql
SHUTDOWN IMMEDIATE;
```

## 3.2 Startup NOMOUNT

```sql
STARTUP NOMOUNT;
```

Contoh output:

```text
ORACLE instance started.
```

Verifikasi:

```sql
SELECT instance_name,
       status
FROM v$instance;
```

Contoh output:

```text
INSTANCE_NAME    STATUS
---------------- ------------
ORADB            STARTED
```

Pada tahap ini control file belum dibaca.

## 3.3 Mount database

```sql
ALTER DATABASE MOUNT;
```

Contoh output:

```text
Database altered.
```

Verifikasi:

```sql
SELECT instance_name,
       status
FROM v$instance;
```

Contoh output:

```text
INSTANCE_NAME    STATUS
---------------- ------------
ORADB            MOUNTED
```

Cek database:

```sql
SELECT name,
       open_mode
FROM v$database;
```

Contoh output:

```text
NAME      OPEN_MODE
--------- ----------
ORADB     MOUNTED
```

## 3.4 Open database

```sql
ALTER DATABASE OPEN;
```

Contoh output:

```text
Database altered.
```

Verifikasi:

```sql
SELECT name,
       open_mode
FROM v$database;
```

Contoh output:

```text
NAME      OPEN_MODE
--------- --------------------
ORADB     READ WRITE
```

## 3.5 Open PDB

```sql
ALTER PLUGGABLE DATABASE ALL OPEN;
```

Contoh output:

```text
Pluggable database altered.
```

---

# LAB 4 — Save State PDB agar Otomatis Open

Secara default, setelah startup CDB, PDB bisa berada pada posisi `MOUNTED`.

## 4.1 Buka PDB1

```sql
ALTER PLUGGABLE DATABASE PDB1 OPEN;
```

Jika sudah open, bisa muncul:

```text
ORA-65019: pluggable database PDB1 already open
```

Itu tidak masalah.

## 4.2 Save state PDB1

```sql
ALTER PLUGGABLE DATABASE PDB1 SAVE STATE;
```

Contoh output:

```text
Pluggable database altered.
```

## 4.3 Verifikasi saved state

```sql
COLUMN con_name FORMAT A20
COLUMN state FORMAT A15

SELECT con_name,
       state
FROM dba_pdb_saved_states
WHERE con_name = 'PDB1';
```

Contoh output:

```text
CON_NAME             STATE
-------------------- ---------------
PDB1                 OPEN
```

## 4.4 Test restart

```sql
SHUTDOWN IMMEDIATE;
STARTUP;
```

Verifikasi:

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

---

# LAB 5 — Melihat Parameter Instance

## 5.1 SHOW PARAMETER

```sql
SHOW PARAMETER db_name
SHOW PARAMETER instance_name
SHOW PARAMETER control_files
SHOW PARAMETER memory
SHOW PARAMETER sga
SHOW PARAMETER pga
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- --------
db_name                              string      ORADB

NAME                                 TYPE        VALUE
------------------------------------ ----------- --------
instance_name                        string      ORADB
```

## 5.2 Query v$parameter

```sql
COLUMN name FORMAT A35
COLUMN value FORMAT A60
COLUMN issys_modifiable FORMAT A15
COLUMN ispdb_modifiable FORMAT A15

SELECT name,
       value,
       issys_modifiable,
       ispdb_modifiable
FROM v$parameter
WHERE name IN (
  'db_name',
  'instance_name',
  'open_cursors',
  'processes',
  'sessions',
  'sga_target',
  'pga_aggregate_target',
  'undo_retention'
)
ORDER BY name;
```

Contoh output:

```text
NAME                    VALUE       ISSYS_MODIFIABLE ISPDB_MODIFIABLE
----------------------- ----------- ----------------- ----------------
db_name                 ORADB       FALSE             FALSE
instance_name           ORADB       FALSE             FALSE
open_cursors            300         IMMEDIATE         TRUE
pga_aggregate_target    524288000   IMMEDIATE         TRUE
processes               300         FALSE             FALSE
sessions                472         FALSE             FALSE
sga_target              1677721600  IMMEDIATE         TRUE
undo_retention          900         IMMEDIATE         TRUE
```

Penjelasan singkat:

```text
IMMEDIATE : bisa diubah langsung.
DEFERRED  : berlaku untuk session baru.
FALSE     : perlu restart instance.
```

---

# LAB 6 — Melihat Apakah Database Menggunakan SPFILE atau PFILE

```sql
SHOW PARAMETER spfile
```

Contoh output jika menggunakan SPFILE:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------------------------
spfile                               string      /u01/app/oracle/product/19.0.0/dbhome_1/dbs/spfileORADB.ora
```

Contoh output jika menggunakan PFILE:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- 
spfile                               string
```

Cek file dari OS:

```bash
ls -lh $ORACLE_HOME/dbs/*ORADB*
```

Contoh output:

```text
-rw-r--r--. 1 oracle oinstall  3K Jul 4 10:00 initORADB.ora
-rw-r-----. 1 oracle oinstall  4K Jul 4 10:00 spfileORADB.ora
```

---

# LAB 7 — Membuat PFILE dari SPFILE

## 7.1 Buat folder backup parameter

```bash
mkdir -p /u01/backup/parameter_file
```

## 7.2 Buat PFILE dari SPFILE

```sql
CREATE PFILE='/u01/backup/parameter_file/initORADB_from_spfile.ora'
FROM SPFILE;
```

Contoh output:

```text
File created.
```

## 7.3 Verifikasi dari OS

```bash
ls -lh /u01/backup/parameter_file/initORADB_from_spfile.ora
```

Contoh output:

```text
-rw-r--r--. 1 oracle oinstall 2.5K Jul 4 14:00 /u01/backup/parameter_file/initORADB_from_spfile.ora
```

Lihat isi file:

```bash
cat /u01/backup/parameter_file/initORADB_from_spfile.ora
```

Contoh output:

```text
ORADB.__data_transfer_cache_size=0
ORADB.__db_cache_size=1174405120
ORADB.__java_pool_size=16777216
*.audit_file_dest='/u01/app/oracle/admin/ORADB/adump'
*.compatible='19.0.0'
*.control_files='/u01/app/oracle/oradata/ORADB/control01.ctl'
*.db_name='ORADB'
*.sga_target=1600M
*.pga_aggregate_target=500M
```

---

# LAB 8 — Membuat SPFILE dari PFILE

## 8.1 Backup SPFILE existing

```bash
cp -p $ORACLE_HOME/dbs/spfileORADB.ora \
/u01/backup/parameter_file/spfileORADB.ora.bak_$(date +%Y%m%d_%H%M%S)
```

Verifikasi:

```bash
ls -lh /u01/backup/parameter_file/spfileORADB.ora.bak_*
```

Contoh output:

```text
-rw-r-----. 1 oracle oinstall 4K Jul 4 14:05 spfileORADB.ora.bak_20260704_140501
```

## 8.2 Buat SPFILE baru dari PFILE backup

Karena SPFILE sedang dipakai, buat ke lokasi baru dulu:

```sql
CREATE SPFILE='/u01/backup/parameter_file/spfileORADB_new.ora'
FROM PFILE='/u01/backup/parameter_file/initORADB_from_spfile.ora';
```

Contoh output:

```text
File created.
```

## 8.3 Verifikasi

```bash
ls -lh /u01/backup/parameter_file/spfileORADB_new.ora
```

Contoh output:

```text
-rw-r-----. 1 oracle oinstall 4K Jul 4 14:06 /u01/backup/parameter_file/spfileORADB_new.ora
```

---

# LAB 9 — Mengubah Parameter Dinamis dengan SCOPE=MEMORY

Parameter `open_cursors` dapat diubah secara dinamis.

## 9.1 Cek nilai awal

```sql
SHOW PARAMETER open_cursors
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- -----
open_cursors                         integer     300
```

## 9.2 Ubah hanya di memory

```sql
ALTER SYSTEM SET open_cursors = 500 SCOPE=MEMORY;
```

Contoh output:

```text
System altered.
```

## 9.3 Verifikasi

```sql
SHOW PARAMETER open_cursors
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- -----
open_cursors                         integer     500
```

## 9.4 Restart dan lihat efeknya

```sql
SHUTDOWN IMMEDIATE;
STARTUP;
ALTER PLUGGABLE DATABASE ALL OPEN;
```

Verifikasi:

```sql
SHOW PARAMETER open_cursors
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- -----
open_cursors                         integer     300
```

Karena tadi `SCOPE=MEMORY`, perubahan hilang setelah restart.

---

# LAB 10 — Mengubah Parameter Permanen dengan SCOPE=SPFILE

## 10.1 Ubah open_cursors di SPFILE

```sql
ALTER SYSTEM SET open_cursors = 500 SCOPE=SPFILE;
```

Contoh output:

```text
System altered.
```

## 10.2 Verifikasi sebelum restart

```sql
SHOW PARAMETER open_cursors
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- -----
open_cursors                         integer     300
```

Belum berubah karena hanya ditulis ke SPFILE.

## 10.3 Restart database

```sql
SHUTDOWN IMMEDIATE;
STARTUP;
ALTER PLUGGABLE DATABASE ALL OPEN;
```

## 10.4 Verifikasi setelah restart

```sql
SHOW PARAMETER open_cursors
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- -----
open_cursors                         integer     500
```

---

# LAB 11 — Mengubah Parameter dengan SCOPE=BOTH

`SCOPE=BOTH` mengubah memory aktif dan SPFILE sekaligus.

```sql
ALTER SYSTEM SET open_cursors = 400 SCOPE=BOTH;
```

Contoh output:

```text
System altered.
```

Verifikasi:

```sql
SHOW PARAMETER open_cursors
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- -----
open_cursors                         integer     400
```

Restart untuk memastikan tetap tersimpan:

```sql
SHUTDOWN IMMEDIATE;
STARTUP;
ALTER PLUGGABLE DATABASE ALL OPEN;
```

Verifikasi:

```sql
SHOW PARAMETER open_cursors
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- -----
open_cursors                         integer     400
```

---

# LAB 12 — Parameter Static: PROCESSES

Parameter `processes` adalah parameter static, sehingga perlu restart.

## 12.1 Cek nilai awal

```sql
SHOW PARAMETER processes
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- -----
processes                            integer     300
```

## 12.2 Coba ubah dengan SCOPE=MEMORY

```sql
ALTER SYSTEM SET processes = 400 SCOPE=MEMORY;
```

Contoh error:

```text
ORA-02095: specified initialization parameter cannot be modified
```

## 12.3 Ubah dengan SCOPE=SPFILE

```sql
ALTER SYSTEM SET processes = 400 SCOPE=SPFILE;
```

Contoh output:

```text
System altered.
```

## 12.4 Restart database

```sql
SHUTDOWN IMMEDIATE;
STARTUP;
ALTER PLUGGABLE DATABASE ALL OPEN;
```

## 12.5 Verifikasi

```sql
SHOW PARAMETER processes
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- -----
processes                            integer     400
```

Catatan:

```text
sessions biasanya dihitung berdasarkan processes.
```

Verifikasi sessions:

```sql
SHOW PARAMETER sessions
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- -----
sessions                             integer     624
```

---

# LAB 13 — RESET Parameter ke Default

## 13.1 Reset open_cursors

```sql
ALTER SYSTEM RESET open_cursors SCOPE=SPFILE SID='*';
```

Contoh output:

```text
System altered.
```

## 13.2 Reset processes

```sql
ALTER SYSTEM RESET processes SCOPE=SPFILE SID='*';
```

Contoh output:

```text
System altered.
```

## 13.3 Restart

```sql
SHUTDOWN IMMEDIATE;
STARTUP;
ALTER PLUGGABLE DATABASE ALL OPEN;
```

## 13.4 Verifikasi

```sql
SHOW PARAMETER open_cursors
SHOW PARAMETER processes
```

Contoh output:

```text
open_cursors                         integer     300
processes                            integer     300
```

---

# LAB 14 — Parameter di Level PDB

Beberapa parameter bisa diatur khusus di PDB.

## 14.1 Masuk ke PDB1

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

## 14.2 Cek parameter yang bisa dimodifikasi di PDB

```sql
COLUMN name FORMAT A30
COLUMN value FORMAT A20
COLUMN ispdb_modifiable FORMAT A15

SELECT name,
       value,
       ispdb_modifiable
FROM v$parameter
WHERE name IN (
  'open_cursors',
  'optimizer_mode',
  'pga_aggregate_target',
  'undo_retention'
)
ORDER BY name;
```

Contoh output:

```text
NAME                           VALUE                ISPDB_MODIFIABLE
------------------------------ -------------------- ---------------
open_cursors                   300                  TRUE
optimizer_mode                 ALL_ROWS             TRUE
pga_aggregate_target           524288000            TRUE
undo_retention                 900                  TRUE
```

## 14.3 Ubah parameter di PDB

```sql
ALTER SYSTEM SET open_cursors = 600;
```

Contoh output:

```text
System altered.
```

## 14.4 Verifikasi di PDB

```sql
SHOW PARAMETER open_cursors
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- -----
open_cursors                         integer     600
```

## 14.5 Verifikasi dari root per container

```sql
CONN / AS SYSDBA

SELECT con_id,
       name,
       value
FROM v$system_parameter
WHERE name = 'open_cursors'
ORDER BY con_id;
```

Contoh output:

```text
    CON_ID NAME                 VALUE
---------- -------------------- ----------
         0 open_cursors         300
         3 open_cursors         600
```

---

# LAB 15 — Reset Parameter PDB

## 15.1 Masuk PDB1

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

## 15.2 Reset parameter PDB

```sql
ALTER SYSTEM RESET open_cursors;
```

Contoh output:

```text
System altered.
```

## 15.3 Verifikasi

```sql
SHOW PARAMETER open_cursors
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- -----
open_cursors                         integer     300
```

---

# LAB 16 — Membuat PFILE Manual dan Startup Menggunakan PFILE

## 16.1 Buat PFILE dari SPFILE

```sql
CONN / AS SYSDBA

CREATE PFILE='/u01/backup/parameter_file/initORADB_manual.ora'
FROM SPFILE;
```

Contoh output:

```text
File created.
```

## 16.2 Edit PFILE dari OS

Keluar dari SQL*Plus atau buka terminal baru:

```bash
vi /u01/backup/parameter_file/initORADB_manual.ora
```

Tambahkan atau ubah baris berikut:

```text
*.open_cursors=450
```

Verifikasi:

```bash
grep open_cursors /u01/backup/parameter_file/initORADB_manual.ora
```

Contoh output:

```text
*.open_cursors=450
```

## 16.3 Shutdown database

```sql
SHUTDOWN IMMEDIATE;
```

## 16.4 Startup menggunakan PFILE

```sql
STARTUP PFILE='/u01/backup/parameter_file/initORADB_manual.ora';
```

Contoh output:

```text
ORACLE instance started.
Database mounted.
Database opened.
```

## 16.5 Open PDB

```sql
ALTER PLUGGABLE DATABASE ALL OPEN;
```

## 16.6 Verifikasi parameter

```sql
SHOW PARAMETER spfile
SHOW PARAMETER open_cursors
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- -----
spfile                               string

NAME                                 TYPE        VALUE
------------------------------------ ----------- -----
open_cursors                         integer     450
```

Jika `spfile` kosong, artinya database sedang startup menggunakan PFILE.

---

# LAB 17 — Kembali Menggunakan SPFILE

## 17.1 Buat SPFILE dari PFILE manual

```sql
CREATE SPFILE='$ORACLE_HOME/dbs/spfileORADB.ora'
FROM PFILE='/u01/backup/parameter_file/initORADB_manual.ora';
```

Jika SQL*Plus tidak mengenali `$ORACLE_HOME`, gunakan path lengkap:

```sql
CREATE SPFILE='/u01/app/oracle/product/19.0.0/dbhome_1/dbs/spfileORADB.ora'
FROM PFILE='/u01/backup/parameter_file/initORADB_manual.ora';
```

Contoh output:

```text
File created.
```

## 17.2 Restart normal

```sql
SHUTDOWN IMMEDIATE;
STARTUP;
ALTER PLUGGABLE DATABASE ALL OPEN;
```

## 17.3 Verifikasi kembali menggunakan SPFILE

```sql
SHOW PARAMETER spfile
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------------------------
spfile                               string      /u01/app/oracle/product/19.0.0/dbhome_1/dbs/spfileORADB.ora
```

---

# LAB 18 — Membuat Backup SPFILE via RMAN

## 18.1 Masuk RMAN

```bash
rman target /
```

## 18.2 Backup SPFILE

```rman
BACKUP SPFILE FORMAT '/u01/backup/parameter_file/spfile_rman_%U.bkp';
```

Contoh output:

```text
Starting backup at 04-JUL-26
channel ORA_DISK_1: starting full datafile backup set
channel ORA_DISK_1: piece handle=/u01/backup/parameter_file/spfile_rman_0a2b3c.bkp
Finished backup at 04-JUL-26
```

## 18.3 List backup SPFILE

```rman
LIST BACKUP OF SPFILE;
```

Contoh output:

```text
BS Key  Type LV Size       Device Type Completion Time
------- ---- -- ---------- ----------- ---------------
12      Full    96.00K     DISK        04-JUL-26
        SPFILE Included
```

Keluar RMAN:

```rman
EXIT;
```

Verifikasi dari OS:

```bash
ls -lh /u01/backup/parameter_file/spfile_rman_*.bkp
```

Contoh output:

```text
-rw-r-----. 1 oracle oinstall 96K Jul 4 14:40 spfile_rman_0a2b3c.bkp
```

---

# LAB 19 — Simulasi SPFILE Rusak dan Recovery dari PFILE

## 19.1 Shutdown database

```sql
CONN / AS SYSDBA
SHUTDOWN IMMEDIATE;
```

## 19.2 Simulasikan SPFILE hilang

```bash
mv $ORACLE_HOME/dbs/spfileORADB.ora \
$ORACLE_HOME/dbs/spfileORADB.ora.failed
```

Verifikasi:

```bash
ls -lh $ORACLE_HOME/dbs/spfileORADB.ora*
```

Contoh output:

```text
-rw-r-----. 1 oracle oinstall 4K Jul 4 14:45 spfileORADB.ora.failed
```

## 19.3 Startup normal

```sql
STARTUP;
```

Kemungkinan output jika ada PFILE default `initORADB.ora`:

```text
ORACLE instance started.
Database mounted.
Database opened.
```

Kemungkinan error jika tidak ada PFILE:

```text
ORA-01078: failure in processing system parameters
LRM-00109: could not open parameter file '/u01/app/oracle/product/19.0.0/dbhome_1/dbs/initORADB.ora'
```

## 19.4 Startup menggunakan PFILE backup

```sql
STARTUP PFILE='/u01/backup/parameter_file/initORADB_from_spfile.ora';
```

Contoh output:

```text
ORACLE instance started.
Database mounted.
Database opened.
```

## 19.5 Buat ulang SPFILE

```sql
CREATE SPFILE='/u01/app/oracle/product/19.0.0/dbhome_1/dbs/spfileORADB.ora'
FROM PFILE='/u01/backup/parameter_file/initORADB_from_spfile.ora';
```

Contoh output:

```text
File created.
```

## 19.6 Restart normal

```sql
SHUTDOWN IMMEDIATE;
STARTUP;
ALTER PLUGGABLE DATABASE ALL OPEN;
```

## 19.7 Verifikasi

```sql
SHOW PARAMETER spfile
```

Contoh output:

```text
spfile string /u01/app/oracle/product/19.0.0/dbhome_1/dbs/spfileORADB.ora
```

---

# LAB 20 — Melihat Alert Log Instance

## 20.1 Cek lokasi diagnostic

```sql
SELECT name,
       value
FROM v$diag_info;
```

Contoh output:

```text
NAME                  VALUE
--------------------- ------------------------------------------------------------
Diag Trace            /u01/app/oracle/diag/rdbms/oradb/ORADB/trace
Diag Alert            /u01/app/oracle/diag/rdbms/oradb/ORADB/alert
Default Trace File    /u01/app/oracle/diag/rdbms/oradb/ORADB/trace/ORADB_ora_12345.trc
```

## 20.2 Lihat alert log dari OS

```bash
tail -100 /u01/app/oracle/diag/rdbms/oradb/ORADB/trace/alert_ORADB.log
```

Contoh output:

```text
Starting ORACLE instance (normal)
ALTER DATABASE MOUNT
ALTER DATABASE OPEN
ALTER PLUGGABLE DATABASE ALL OPEN
Completed: ALTER PLUGGABLE DATABASE ALL OPEN
```

---

# LAB 21 — Startup Restricted Mode

Restricted mode membatasi koneksi hanya untuk user yang memiliki privilege `RESTRICTED SESSION`.

## 21.1 Startup restricted

```sql
SHUTDOWN IMMEDIATE;
STARTUP RESTRICT;
```

Contoh output:

```text
ORACLE instance started.
Database mounted.
Database opened.
```

Verifikasi:

```sql
SELECT logins
FROM v$instance;
```

Contoh output:

```text
LOGINS
----------
RESTRICTED
```

## 21.2 Buka PDB restricted

```sql
ALTER PLUGGABLE DATABASE PDB1 OPEN RESTRICTED;
```

Contoh output:

```text
Pluggable database altered.
```

Verifikasi:

```sql
SHOW PDBS
```

Contoh output:

```text
    CON_ID CON_NAME                       OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
         3 PDB1                           READ WRITE YES
```

## 21.3 Disable restricted session

```sql
ALTER SYSTEM DISABLE RESTRICTED SESSION;
```

Contoh output:

```text
System altered.
```

Verifikasi:

```sql
SELECT logins
FROM v$instance;
```

Contoh output:

```text
LOGINS
----------
ALLOWED
```

---

# LAB 22 — Membuat Parameter File Dokumentasi

PFILE sering digunakan sebagai dokumentasi konfigurasi instance.

```sql
CREATE PFILE='/u01/backup/parameter_file/initORADB_documentation.ora'
FROM MEMORY;
```

Contoh output:

```text
File created.
```

Verifikasi:

```bash
ls -lh /u01/backup/parameter_file/initORADB_documentation.ora
```

Contoh output:

```text
-rw-r--r--. 1 oracle oinstall 3.2K Jul 4 15:10 initORADB_documentation.ora
```

Lihat beberapa parameter penting:

```bash
egrep "db_name|control_files|sga_target|pga_aggregate_target|processes|open_cursors" \
/u01/backup/parameter_file/initORADB_documentation.ora
```

Contoh output:

```text
*.control_files='/u01/app/oracle/oradata/ORADB/control01.ctl'
*.db_name='ORADB'
*.open_cursors=450
*.pga_aggregate_target=500M
*.processes=300
*.sga_target=1600M
```

---

# LAB 23 — Cleanup dan Kembalikan Parameter

## 23.1 Reset open_cursors ke default atau nilai standar

```sql
CONN / AS SYSDBA

ALTER SYSTEM RESET open_cursors SCOPE=SPFILE SID='*';
```

Jika muncul error karena parameter tidak ada di SPFILE:

```text
ORA-32010: cannot find entry to delete in SPFILE
```

Itu tidak masalah.

## 23.2 Restart database

```sql
SHUTDOWN IMMEDIATE;
STARTUP;
ALTER PLUGGABLE DATABASE ALL OPEN;
```

## 23.3 Verifikasi akhir

```sql
SHOW PARAMETER spfile
SHOW PARAMETER open_cursors
SHOW PARAMETER processes
```

Contoh output:

```text
spfile        string      /u01/app/oracle/product/19.0.0/dbhome_1/dbs/spfileORADB.ora
open_cursors  integer     300
processes     integer     300
```

---

# Ringkasan Command Penting

Startup normal:

```sql
STARTUP;
```

Shutdown normal:

```sql
SHUTDOWN IMMEDIATE;
```

Startup bertahap:

```sql
STARTUP NOMOUNT;
ALTER DATABASE MOUNT;
ALTER DATABASE OPEN;
```

Open PDB:

```sql
ALTER PLUGGABLE DATABASE ALL OPEN;
```

Save state PDB:

```sql
ALTER PLUGGABLE DATABASE PDB1 SAVE STATE;
```

Cek parameter:

```sql
SHOW PARAMETER nama_parameter;
```

Ubah parameter sementara:

```sql
ALTER SYSTEM SET open_cursors = 500 SCOPE=MEMORY;
```

Ubah parameter permanen:

```sql
ALTER SYSTEM SET open_cursors = 500 SCOPE=SPFILE;
```

Ubah memory dan permanen:

```sql
ALTER SYSTEM SET open_cursors = 500 SCOPE=BOTH;
```

Reset parameter:

```sql
ALTER SYSTEM RESET open_cursors SCOPE=SPFILE SID='*';
```

Buat PFILE dari SPFILE:

```sql
CREATE PFILE='/u01/backup/parameter_file/initORADB.ora' FROM SPFILE;
```

Buat SPFILE dari PFILE:

```sql
CREATE SPFILE='/u01/app/oracle/product/19.0.0/dbhome_1/dbs/spfileORADB.ora'
FROM PFILE='/u01/backup/parameter_file/initORADB.ora';
```

Startup dengan PFILE:

```sql
STARTUP PFILE='/u01/backup/parameter_file/initORADB.ora';
```

Backup SPFILE RMAN:

```rman
BACKUP SPFILE FORMAT '/u01/backup/parameter_file/spfile_%U.bkp';
```

Catatan utama: **instance hanya ada di level CDB**, sedangkan PDB tidak memiliki instance sendiri. Namun beberapa parameter tertentu dapat diatur pada level PDB jika `ISPDB_MODIFIABLE = TRUE`.
