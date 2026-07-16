# HANDS-ON LAB

# Manajemen Control File Oracle 19c

Asumsi:

```text
Database : ORADB
OS       : Oracle Linux
User OS  : oracle
Oracle   : 19c
Mode     : CDB / Multitenant
```

Catatan penting:

```text
Control file dikelola di level CDB, bukan di PDB.
Control file tidak memiliki autoextend.
Control file tidak di-resize manual seperti datafile.
Istilah archive control file tidak ada seperti archive redo log.
Yang ada adalah backup control file.
Best practice: control file dibuat multiplex, minimal 2 copy di lokasi berbeda.
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
SELECT name, cdb, open_mode, log_mode
FROM v$database;
```

Contoh output:

```text
NAME      CDB OPEN_MODE            LOG_MODE
--------- --- -------------------- ------------
ORADB     YES READ WRITE           ARCHIVELOG
```

Verifikasi lokasi control file:

```sql
SHOW PARAMETER control_files
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- -----------------------------------------------
control_files                        string      /u01/app/oracle/oradata/ORADB/control01.ctl
```

---

# LAB 1 — Melihat Informasi Control File

## 1.1 Cek control file dari parameter

```sql
SHOW PARAMETER control_files
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------------------------
control_files                        string      /u01/app/oracle/oradata/ORADB/control01.ctl
```

## 1.2 Cek control file dari dynamic view

```sql
SET LINESIZE 200
COLUMN name FORMAT A80

SELECT name,
       status,
       is_recovery_dest_file,
       block_size,
       file_size_blks
FROM v$controlfile;
```

Contoh output:

```text
NAME                                                        STATUS  IS_ BLOCK_SIZE FILE_SIZE_BLKS
----------------------------------------------------------- ------- --- ---------- --------------
/u01/app/oracle/oradata/ORADB/control01.ctl                         NO       16384            618
```

## 1.3 Cek ukuran control file dari OS

```bash
ls -lh /u01/app/oracle/oradata/ORADB/control01.ctl
```

Contoh output:

```text
-rw-r-----. 1 oracle oinstall 9.8M Jul  4 10:00 /u01/app/oracle/oradata/ORADB/control01.ctl
```

---

# LAB 2 — Menambahkan Control File Baru / Multiplex Control File

Tujuan lab ini adalah membuat salinan control file kedua agar lebih aman.

## 2.1 Buat direktori baru

```bash
mkdir -p /u01/app/oracle/oradata/ORADB/control_mirror
```

Verifikasi:

```bash
ls -ld /u01/app/oracle/oradata/ORADB/control_mirror
```

Contoh output:

```text
drwxr-xr-x. 2 oracle oinstall 6 Jul  4 10:05 /u01/app/oracle/oradata/ORADB/control_mirror
```

## 2.2 Shutdown database

```sql
SHUTDOWN IMMEDIATE;
```

Contoh output:

```text
Database closed.
Database dismounted.
ORACLE instance shut down.
```

## 2.3 Copy control file existing ke lokasi baru

Jalankan di terminal OS:

```bash
cp /u01/app/oracle/oradata/ORADB/control01.ctl \
/u01/app/oracle/oradata/ORADB/control_mirror/control02.ctl
```

Verifikasi:

```bash
ls -lh /u01/app/oracle/oradata/ORADB/control01.ctl
ls -lh /u01/app/oracle/oradata/ORADB/control_mirror/control02.ctl
```

Contoh output:

```text
-rw-r-----. 1 oracle oinstall 9.8M Jul  4 10:10 /u01/app/oracle/oradata/ORADB/control01.ctl
-rw-r-----. 1 oracle oinstall 9.8M Jul  4 10:10 /u01/app/oracle/oradata/ORADB/control_mirror/control02.ctl
```

## 2.4 Startup nomount

```bash
sqlplus / as sysdba
```

```sql
STARTUP NOMOUNT;
```

Contoh output:

```text
ORACLE instance started.
```

## 2.5 Set parameter control_files

```sql
ALTER SYSTEM SET control_files =
'/u01/app/oracle/oradata/ORADB/control01.ctl',
'/u01/app/oracle/oradata/ORADB/control_mirror/control02.ctl'
SCOPE=SPFILE;
```

Contoh output:

```text
System altered.
```

## 2.6 Restart database

```sql
SHUTDOWN IMMEDIATE;
STARTUP;
ALTER PLUGGABLE DATABASE ALL OPEN;
```

Contoh output:

```text
ORACLE instance shut down.
ORACLE instance started.
Database mounted.
Database opened.
Pluggable database altered.
```

## 2.7 Verifikasi multiplex control file

```sql
SHOW PARAMETER control_files
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- -------------------------------------------------------------
control_files                        string      /u01/app/oracle/oradata/ORADB/control01.ctl,
                                                 /u01/app/oracle/oradata/ORADB/control_mirror/control02.ctl
```

```sql
SELECT name
FROM v$controlfile;
```

Contoh output:

```text
NAME
--------------------------------------------------------------------------------
/u01/app/oracle/oradata/ORADB/control01.ctl
/u01/app/oracle/oradata/ORADB/control_mirror/control02.ctl
```

---

# LAB 3 — Menambahkan Control File Ketiga

## 3.1 Buat direktori baru

```bash
mkdir -p /u01/app/oracle/fast_recovery_area/ORADB/controlfile
```

## 3.2 Shutdown database

```sql
SHUTDOWN IMMEDIATE;
```

## 3.3 Copy control file

```bash
cp /u01/app/oracle/oradata/ORADB/control01.ctl \
/u01/app/oracle/fast_recovery_area/ORADB/controlfile/control03.ctl
```

Verifikasi:

```bash
ls -lh /u01/app/oracle/fast_recovery_area/ORADB/controlfile/control03.ctl
```

Contoh output:

```text
-rw-r-----. 1 oracle oinstall 9.8M Jul  4 10:20 /u01/app/oracle/fast_recovery_area/ORADB/controlfile/control03.ctl
```

## 3.4 Startup nomount

```sql
STARTUP NOMOUNT;
```

## 3.5 Tambahkan ke parameter control_files

```sql
ALTER SYSTEM SET control_files =
'/u01/app/oracle/oradata/ORADB/control01.ctl',
'/u01/app/oracle/oradata/ORADB/control_mirror/control02.ctl',
'/u01/app/oracle/fast_recovery_area/ORADB/controlfile/control03.ctl'
SCOPE=SPFILE;
```

Contoh output:

```text
System altered.
```

## 3.6 Restart database

```sql
SHUTDOWN IMMEDIATE;
STARTUP;
ALTER PLUGGABLE DATABASE ALL OPEN;
```

## 3.7 Verifikasi

```sql
SELECT name
FROM v$controlfile;
```

Contoh output:

```text
NAME
--------------------------------------------------------------------------------
/u01/app/oracle/oradata/ORADB/control01.ctl
/u01/app/oracle/oradata/ORADB/control_mirror/control02.ctl
/u01/app/oracle/fast_recovery_area/ORADB/controlfile/control03.ctl
```

---

# LAB 4 — Menghapus Salah Satu Control File dari Konfigurasi

Catatan: jangan hapus file fisik sebelum parameter `control_files` diubah.

## 4.1 Shutdown database

```sql
SHUTDOWN IMMEDIATE;
```

## 4.2 Startup nomount

```sql
STARTUP NOMOUNT;
```

## 4.3 Hapus control file ketiga dari parameter

```sql
ALTER SYSTEM SET control_files =
'/u01/app/oracle/oradata/ORADB/control01.ctl',
'/u01/app/oracle/oradata/ORADB/control_mirror/control02.ctl'
SCOPE=SPFILE;
```

Contoh output:

```text
System altered.
```

## 4.4 Restart database

```sql
SHUTDOWN IMMEDIATE;
STARTUP;
ALTER PLUGGABLE DATABASE ALL OPEN;
```

## 4.5 Verifikasi

```sql
SELECT name
FROM v$controlfile;
```

Contoh output:

```text
NAME
--------------------------------------------------------------------------------
/u01/app/oracle/oradata/ORADB/control01.ctl
/u01/app/oracle/oradata/ORADB/control_mirror/control02.ctl
```

## 4.6 Hapus file fisik yang sudah tidak digunakan

```bash
rm -f /u01/app/oracle/fast_recovery_area/ORADB/controlfile/control03.ctl
```

Verifikasi:

```bash
ls -lh /u01/app/oracle/fast_recovery_area/ORADB/controlfile/control03.ctl
```

Contoh output:

```text
ls: cannot access '/u01/app/oracle/fast_recovery_area/ORADB/controlfile/control03.ctl': No such file or directory
```

---

# LAB 5 — Memindahkan Lokasi Control File

Skenario: pindahkan `control02.ctl` ke lokasi baru.

## 5.1 Buat lokasi baru

```bash
mkdir -p /u01/app/oracle/oradata/ORADB/control_newloc
```

## 5.2 Shutdown database

```sql
SHUTDOWN IMMEDIATE;
```

## 5.3 Copy control file ke lokasi baru

```bash
cp /u01/app/oracle/oradata/ORADB/control_mirror/control02.ctl \
/u01/app/oracle/oradata/ORADB/control_newloc/control02.ctl
```

Verifikasi:

```bash
ls -lh /u01/app/oracle/oradata/ORADB/control_newloc/control02.ctl
```

Contoh output:

```text
-rw-r-----. 1 oracle oinstall 9.8M Jul  4 10:35 /u01/app/oracle/oradata/ORADB/control_newloc/control02.ctl
```

## 5.4 Startup nomount

```sql
STARTUP NOMOUNT;
```

## 5.5 Update parameter control_files

```sql
ALTER SYSTEM SET control_files =
'/u01/app/oracle/oradata/ORADB/control01.ctl',
'/u01/app/oracle/oradata/ORADB/control_newloc/control02.ctl'
SCOPE=SPFILE;
```

Contoh output:

```text
System altered.
```

## 5.6 Restart database

```sql
SHUTDOWN IMMEDIATE;
STARTUP;
ALTER PLUGGABLE DATABASE ALL OPEN;
```

## 5.7 Verifikasi lokasi baru

```sql
SELECT name
FROM v$controlfile;
```

Contoh output:

```text
NAME
--------------------------------------------------------------------------------
/u01/app/oracle/oradata/ORADB/control01.ctl
/u01/app/oracle/oradata/ORADB/control_newloc/control02.ctl
```

## 5.8 Hapus file lama

```bash
rm -f /u01/app/oracle/oradata/ORADB/control_mirror/control02.ctl
```

---

# LAB 6 — Backup Control File ke Binary File

## 6.1 Backup control file

```sql
ALTER DATABASE BACKUP CONTROLFILE TO
'/u01/app/oracle/oradata/ORADB/controlfile_backup_binary.bkp';
```

Contoh output:

```text
Database altered.
```

## 6.2 Verifikasi file backup

```bash
ls -lh /u01/app/oracle/oradata/ORADB/controlfile_backup_binary.bkp
```

Contoh output:

```text
-rw-r-----. 1 oracle oinstall 9.8M Jul  4 10:45 /u01/app/oracle/oradata/ORADB/controlfile_backup_binary.bkp
```

---

# LAB 7 — Backup Control File ke Trace

Backup ke trace berguna untuk membuat ulang control file menggunakan script SQL.

## 7.1 Backup control file to trace

```sql
ALTER DATABASE BACKUP CONTROLFILE TO TRACE;
```

Contoh output:

```text
Database altered.
```

## 7.2 Cari lokasi trace file

```sql
SELECT value
FROM v$diag_info
WHERE name = 'Default Trace File';
```

Contoh output:

```text
VALUE
--------------------------------------------------------------------------------
/u01/app/oracle/diag/rdbms/oradb/ORADB/trace/ORADB_ora_12345.trc
```

## 7.3 Lihat isi trace dari OS

Ganti nama file sesuai output di atas.

```bash
grep -n "CREATE CONTROLFILE" /u01/app/oracle/diag/rdbms/oradb/ORADB/trace/ORADB_ora_12345.trc
```

Contoh output:

```text
78:CREATE CONTROLFILE REUSE DATABASE "ORADB" RESETLOGS ARCHIVELOG
156:CREATE CONTROLFILE REUSE DATABASE "ORADB" NORESETLOGS ARCHIVELOG
```

---

# LAB 8 — Mengaktifkan Autobackup Control File di RMAN

## 8.1 Masuk RMAN

```bash
rman target /
```

## 8.2 Cek konfigurasi autobackup

```rman
SHOW CONTROLFILE AUTOBACKUP;
```

Contoh output:

```text
RMAN configuration parameters for database with db_unique_name ORADB are:
CONFIGURE CONTROLFILE AUTOBACKUP OFF;
```

## 8.3 Aktifkan autobackup

```rman
CONFIGURE CONTROLFILE AUTOBACKUP ON;
```

Contoh output:

```text
new RMAN configuration parameters:
CONFIGURE CONTROLFILE AUTOBACKUP ON;
new RMAN configuration parameters are successfully stored
```

## 8.4 Verifikasi

```rman
SHOW CONTROLFILE AUTOBACKUP;
```

Contoh output:

```text
RMAN configuration parameters for database with db_unique_name ORADB are:
CONFIGURE CONTROLFILE AUTOBACKUP ON;
```

Keluar RMAN:

```rman
EXIT;
```

---

# LAB 9 — Backup Control File Menggunakan RMAN

## 9.1 Masuk RMAN

```bash
rman target /
```

## 9.2 Backup current control file

```rman
BACKUP CURRENT CONTROLFILE;
```

Contoh output:

```text
Starting backup at 04-JUL-26
piece handle=/u01/app/oracle/fast_recovery_area/ORADB/autobackup/2026_07_04/o1_mf_s_1234567890.bkp
Finished backup at 04-JUL-26
```

## 9.3 List backup control file

```rman
LIST BACKUP OF CONTROLFILE;
```

Contoh output:

```text
BS Key  Type LV Size       Device Type Elapsed Time Completion Time
------- ---- -- ---------- ----------- ------------ ---------------
15      Full    10.00M     DISK        00:00:01     04-JUL-26
        Control File Included: Ckp SCN: 1234567
```

Keluar RMAN:

```rman
EXIT;
```

---

# LAB 10 — Monitoring Informasi Record Section Control File

Control file menyimpan metadata database, seperti datafile, redo log, archived log, backup, dan lain-lain.

```sql
SET LINESIZE 200
COLUMN type FORMAT A30

SELECT type,
       record_size,
       records_total,
       records_used,
       first_index,
       last_index
FROM v$controlfile_record_section
ORDER BY type;
```

Contoh output:

```text
TYPE                           RECORD_SIZE RECORDS_TOTAL RECORDS_USED FIRST_INDEX LAST_INDEX
------------------------------ ----------- ------------- ------------ ----------- ----------
ARCHIVED LOG                           584           280           45          1         45
BACKUP PIECE                           780          1024           12          1         12
DATAFILE                               520          1024            9          0          0
DATABASE                               316             1            1          0          0
REDO LOG                                72            16            3          0          0
TABLESPACE                              68          1024            8          0          0
```

---

# LAB 11 — Mengatur CONTROL_FILE_RECORD_KEEP_TIME

Parameter ini menentukan berapa lama reusable record di control file dipertahankan sebelum dapat ditimpa.

## 11.1 Cek nilai saat ini

```sql
SHOW PARAMETER control_file_record_keep_time
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- -----
control_file_record_keep_time        integer     7
```

## 11.2 Ubah menjadi 14 hari

```sql
ALTER SYSTEM SET control_file_record_keep_time = 14 SCOPE=BOTH;
```

Contoh output:

```text
System altered.
```

## 11.3 Verifikasi

```sql
SHOW PARAMETER control_file_record_keep_time
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- -----
control_file_record_keep_time        integer     14
```

---

# LAB 12 — Simulasi Kehilangan Salah Satu Control File Multiplex

Syarat: database punya minimal 2 control file.

## 12.1 Verifikasi control file

```sql
SELECT name
FROM v$controlfile;
```

Contoh output:

```text
NAME
--------------------------------------------------------------------------------
/u01/app/oracle/oradata/ORADB/control01.ctl
/u01/app/oracle/oradata/ORADB/control_newloc/control02.ctl
```

## 12.2 Shutdown database

```sql
SHUTDOWN IMMEDIATE;
```

## 12.3 Simulasikan salah satu control file hilang

```bash
mv /u01/app/oracle/oradata/ORADB/control_newloc/control02.ctl \
/u01/app/oracle/oradata/ORADB/control_newloc/control02.ctl.bak
```

## 12.4 Coba startup database

```sql
STARTUP;
```

Contoh error:

```text
ORA-00205: error in identifying control file, check alert log for more info
```

## 12.5 Recovery dengan menyalin dari control file yang masih ada

```bash
cp /u01/app/oracle/oradata/ORADB/control01.ctl \
/u01/app/oracle/oradata/ORADB/control_newloc/control02.ctl
```

## 12.6 Startup ulang

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

## 12.7 Verifikasi

```sql
SELECT name
FROM v$controlfile;
```

Contoh output:

```text
NAME
--------------------------------------------------------------------------------
/u01/app/oracle/oradata/ORADB/control01.ctl
/u01/app/oracle/oradata/ORADB/control_newloc/control02.ctl
```

---

# LAB 13 — Restore Control File dari Binary Backup

Lab ini untuk simulasi. Gunakan hati-hati.

## 13.1 Pastikan punya backup binary

```bash
ls -lh /u01/app/oracle/oradata/ORADB/controlfile_backup_binary.bkp
```

Contoh output:

```text
-rw-r-----. 1 oracle oinstall 9.8M Jul  4 10:45 /u01/app/oracle/oradata/ORADB/controlfile_backup_binary.bkp
```

## 13.2 Shutdown database

```sql
SHUTDOWN IMMEDIATE;
```

## 13.3 Backup control file existing sebagai safety

```bash
cp /u01/app/oracle/oradata/ORADB/control01.ctl \
/u01/app/oracle/oradata/ORADB/control01.ctl.before_restore

cp /u01/app/oracle/oradata/ORADB/control_newloc/control02.ctl \
/u01/app/oracle/oradata/ORADB/control_newloc/control02.ctl.before_restore
```

## 13.4 Restore binary backup ke semua lokasi control file

```bash
cp /u01/app/oracle/oradata/ORADB/controlfile_backup_binary.bkp \
/u01/app/oracle/oradata/ORADB/control01.ctl

cp /u01/app/oracle/oradata/ORADB/controlfile_backup_binary.bkp \
/u01/app/oracle/oradata/ORADB/control_newloc/control02.ctl
```

## 13.5 Startup mount

```sql
STARTUP MOUNT;
```

Contoh output:

```text
Database mounted.
```

## 13.6 Recover database

```sql
RECOVER DATABASE USING BACKUP CONTROLFILE;
```

Contoh output bisa meminta archive log:

```text
Specify log: {<RET>=suggested | filename | AUTO | CANCEL}
```

Gunakan:

```text
AUTO
```

## 13.7 Open resetlogs

```sql
ALTER DATABASE OPEN RESETLOGS;
```

Contoh output:

```text
Database altered.
```

## 13.8 Buka PDB

```sql
ALTER PLUGGABLE DATABASE ALL OPEN;
```

Contoh output:

```text
Pluggable database altered.
```

Catatan: `OPEN RESETLOGS` hanya dilakukan pada skenario recovery tertentu. Untuk lab dasar, cukup pahami alurnya. Jangan lakukan di production tanpa backup dan rencana recovery yang jelas.

---

# LAB 14 — Membuat Script CREATE CONTROLFILE dari Trace

Lab ini hanya membuat script, tidak langsung menjalankannya.

## 14.1 Backup control file to trace dengan nama file eksplisit

```sql
ALTER DATABASE BACKUP CONTROLFILE TO TRACE AS
'/u01/app/oracle/oradata/ORADB/create_controlfile_oradb.sql';
```

Contoh output:

```text
Database altered.
```

## 14.2 Verifikasi file script

```bash
ls -lh /u01/app/oracle/oradata/ORADB/create_controlfile_oradb.sql
```

Contoh output:

```text
-rw-r-----. 1 oracle oinstall 12K Jul  4 11:20 /u01/app/oracle/oradata/ORADB/create_controlfile_oradb.sql
```

## 14.3 Lihat bagian CREATE CONTROLFILE

```bash
grep -n "CREATE CONTROLFILE" /u01/app/oracle/oradata/ORADB/create_controlfile_oradb.sql
```

Contoh output:

```text
22:CREATE CONTROLFILE REUSE DATABASE "ORADB" RESETLOGS ARCHIVELOG
96:CREATE CONTROLFILE REUSE DATABASE "ORADB" NORESETLOGS ARCHIVELOG
```

---

# LAB 15 — Mengembalikan Parameter CONTROL_FILE_RECORD_KEEP_TIME

Jika tadi diubah ke 14, kembalikan ke 7.

```sql
ALTER SYSTEM SET control_file_record_keep_time = 7 SCOPE=BOTH;
```

Contoh output:

```text
System altered.
```

Verifikasi:

```sql
SHOW PARAMETER control_file_record_keep_time
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- -----
control_file_record_keep_time        integer     7
```

---

# LAB 16 — Cleanup Backup File Lab

Hapus file backup tambahan jika tidak diperlukan.

```bash
rm -f /u01/app/oracle/oradata/ORADB/controlfile_backup_binary.bkp
rm -f /u01/app/oracle/oradata/ORADB/create_controlfile_oradb.sql
rm -f /u01/app/oracle/oradata/ORADB/control01.ctl.before_restore
rm -f /u01/app/oracle/oradata/ORADB/control_newloc/control02.ctl.before_restore
rm -f /u01/app/oracle/oradata/ORADB/control_newloc/control02.ctl.bak
```

Verifikasi:

```bash
ls -lh /u01/app/oracle/oradata/ORADB/controlfile_backup_binary.bkp
```

Contoh output:

```text
ls: cannot access '/u01/app/oracle/oradata/ORADB/controlfile_backup_binary.bkp': No such file or directory
```

---

# Ringkasan Command Penting

Melihat control file:

```sql
SHOW PARAMETER control_files;
SELECT name FROM v$controlfile;
```

Menambahkan control file:

```sql
SHUTDOWN IMMEDIATE;
```

```bash
cp /u01/app/oracle/oradata/ORADB/control01.ctl \
/u01/app/oracle/oradata/ORADB/control_newloc/control02.ctl
```

```sql
STARTUP NOMOUNT;

ALTER SYSTEM SET control_files =
'/u01/app/oracle/oradata/ORADB/control01.ctl',
'/u01/app/oracle/oradata/ORADB/control_newloc/control02.ctl'
SCOPE=SPFILE;

SHUTDOWN IMMEDIATE;
STARTUP;
```

Backup control file binary:

```sql
ALTER DATABASE BACKUP CONTROLFILE TO
'/u01/app/oracle/oradata/ORADB/controlfile_backup_binary.bkp';
```

Backup control file to trace:

```sql
ALTER DATABASE BACKUP CONTROLFILE TO TRACE;
```

RMAN autobackup:

```rman
CONFIGURE CONTROLFILE AUTOBACKUP ON;
BACKUP CURRENT CONTROLFILE;
LIST BACKUP OF CONTROLFILE;
```

Cek metadata control file:

```sql
SELECT type, records_total, records_used
FROM v$controlfile_record_section;
```

---

Catatan akhir: **control file tidak bisa di-resize manual maupun otomatis**. Ukurannya dikelola otomatis oleh Oracle berdasarkan metadata database. Yang perlu dikelola DBA adalah **multiplexing**, **lokasi file**, **backup control file**, dan **monitoring record section**.
