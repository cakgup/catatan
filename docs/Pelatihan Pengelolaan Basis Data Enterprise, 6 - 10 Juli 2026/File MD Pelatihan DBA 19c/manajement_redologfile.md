# HANDS-ON LAB

# Manajemen Online Redo Log dan Archive Log Oracle 19c

Asumsi:

```text
Database : ORADB
Mode     : CDB / Multitenant
OS       : Oracle Linux
User OS  : oracle
```

Catatan penting:

```text
Online redo log dikelola di level CDB, bukan di PDB.
Archive log juga dikelola di level CDB.
Redo log tidak bisa resize langsung.
Untuk resize redo log, caranya adalah membuat redo log group baru dengan ukuran baru, lalu menghapus group lama.
Redo log tidak memiliki AUTOEXTEND.
```

---

# 0. Persiapan Awal

Login sebagai user oracle.

```bash
su - oracle
sqlplus / as sysdba
```

Verifikasi database.

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

Verifikasi container.

```sql
SHOW CON_NAME
```

Contoh output:

```text
CON_NAME
------------------------------
CDB$ROOT
```

---

# LAB 1 — Melihat Online Redo Log Existing

## 1.1 Melihat redo log group

```sql
SET LINESIZE 200
COLUMN status FORMAT A15
COLUMN member FORMAT A80

SELECT group#,
       thread#,
       sequence#,
       bytes/1024/1024 AS size_mb,
       members,
       archived,
       status
FROM v$log
ORDER BY group#;
```

Contoh output:

```text
    GROUP#    THREAD#  SEQUENCE#    SIZE_MB    MEMBERS ARC STATUS
---------- ---------- ---------- ---------- ---------- --- ---------------
         1          1         21        200          1 YES INACTIVE
         2          1         22        200          1 NO  CURRENT
         3          1         20        200          1 YES INACTIVE
```

## 1.2 Melihat lokasi file redo log

```sql
SELECT group#,
       type,
       member,
       status
FROM v$logfile
ORDER BY group#, member;
```

Contoh output:

```text
    GROUP# TYPE    MEMBER                                                       STATUS
---------- ------- ------------------------------------------------------------ -------
         1 ONLINE  /u01/app/oracle/oradata/ORADB/redo01.log
         2 ONLINE  /u01/app/oracle/oradata/ORADB/redo02.log
         3 ONLINE  /u01/app/oracle/oradata/ORADB/redo03.log
```

---

# LAB 2 — Menambahkan Redo Log Group Baru

## 2.1 Tambah redo log group baru

```sql
ALTER DATABASE ADD LOGFILE GROUP 4
'/u01/app/oracle/oradata/ORADB/redo04.log'
SIZE 200M;
```

Contoh output:

```text
Database altered.
```

## 2.2 Verifikasi group baru

```sql
SELECT group#,
       thread#,
       sequence#,
       bytes/1024/1024 AS size_mb,
       members,
       archived,
       status
FROM v$log
ORDER BY group#;
```

Contoh output:

```text
    GROUP#    THREAD#  SEQUENCE#    SIZE_MB    MEMBERS ARC STATUS
---------- ---------- ---------- ---------- ---------- --- ---------------
         1          1         21        200          1 YES INACTIVE
         2          1         22        200          1 NO  CURRENT
         3          1         20        200          1 YES INACTIVE
         4          1          0        200          1 YES UNUSED
```

## 2.3 Verifikasi file fisik

```bash
ls -lh /u01/app/oracle/oradata/ORADB/redo04.log
```

Contoh output:

```text
-rw-r-----. 1 oracle oinstall 201M Jul  4 09:10 /u01/app/oracle/oradata/ORADB/redo04.log
```

---

# LAB 3 — Menambahkan Redo Log Member untuk Multiplexing

Multiplexing redo log berarti setiap group memiliki lebih dari satu member. Ini best practice agar jika satu file redo rusak, masih ada salinannya.

## 3.1 Buat folder baru untuk salinan redo

```bash
mkdir -p /u01/app/oracle/oradata/ORADB/redo_mirror
```

Verifikasi:

```bash
ls -ld /u01/app/oracle/oradata/ORADB/redo_mirror
```

Contoh output:

```text
drwxr-xr-x. 2 oracle oinstall 6 Jul  4 09:15 /u01/app/oracle/oradata/ORADB/redo_mirror
```

## 3.2 Tambahkan member ke group 4

```sql
ALTER DATABASE ADD LOGFILE MEMBER
'/u01/app/oracle/oradata/ORADB/redo_mirror/redo04b.log'
TO GROUP 4;
```

Contoh output:

```text
Database altered.
```

## 3.3 Verifikasi member group 4

```sql
SELECT group#,
       member,
       status
FROM v$logfile
WHERE group# = 4;
```

Contoh output:

```text
    GROUP# MEMBER                                                       STATUS
---------- ------------------------------------------------------------ -------
         4 /u01/app/oracle/oradata/ORADB/redo04.log
         4 /u01/app/oracle/oradata/ORADB/redo_mirror/redo04b.log
```

## 3.4 Verifikasi jumlah member

```sql
SELECT group#,
       members,
       status
FROM v$log
WHERE group# = 4;
```

Contoh output:

```text
    GROUP#    MEMBERS STATUS
---------- ---------- ---------------
         4          2 UNUSED
```

---

# LAB 4 — Melakukan Log Switch

## 4.1 Lihat group aktif sebelum switch

```sql
SELECT group#,
       sequence#,
       archived,
       status
FROM v$log
ORDER BY group#;
```

Contoh output:

```text
    GROUP#  SEQUENCE# ARC STATUS
---------- ---------- --- ---------------
         1         21 YES INACTIVE
         2         22 NO  CURRENT
         3         20 YES INACTIVE
         4          0 YES UNUSED
```

## 4.2 Jalankan log switch

```sql
ALTER SYSTEM SWITCH LOGFILE;
```

Contoh output:

```text
System altered.
```

## 4.3 Verifikasi setelah switch

```sql
SELECT group#,
       sequence#,
       archived,
       status
FROM v$log
ORDER BY group#;
```

Contoh output:

```text
    GROUP#  SEQUENCE# ARC STATUS
---------- ---------- --- ---------------
         1         21 YES INACTIVE
         2         22 YES ACTIVE
         3         20 YES INACTIVE
         4         23 NO  CURRENT
```

---

# LAB 5 — Melakukan Checkpoint

Checkpoint membantu mempercepat perubahan status redo log dari `ACTIVE` menjadi `INACTIVE`.

```sql
ALTER SYSTEM CHECKPOINT;
```

Contoh output:

```text
System altered.
```

Verifikasi:

```sql
SELECT group#,
       sequence#,
       archived,
       status
FROM v$log
ORDER BY group#;
```

Contoh output:

```text
    GROUP#  SEQUENCE# ARC STATUS
---------- ---------- --- ---------------
         1         21 YES INACTIVE
         2         22 YES INACTIVE
         3         20 YES INACTIVE
         4         23 NO  CURRENT
```

---

# LAB 6 — Menghapus Redo Log Member

Catatan: jangan hapus member terakhir dari sebuah group. Minimal harus ada satu member tersisa.

## 6.1 Hapus member mirror group 4

```sql
ALTER DATABASE DROP LOGFILE MEMBER
'/u01/app/oracle/oradata/ORADB/redo_mirror/redo04b.log';
```

Contoh output:

```text
Database altered.
```

## 6.2 Verifikasi

```sql
SELECT group#,
       member,
       status
FROM v$logfile
WHERE group# = 4;
```

Contoh output:

```text
    GROUP# MEMBER                                      STATUS
---------- ------------------------------------------- -------
         4 /u01/app/oracle/oradata/ORADB/redo04.log
```

---

# LAB 7 — Menghapus Redo Log Group

Redo log group bisa dihapus jika statusnya bukan `CURRENT` dan database masih memiliki minimal 2 group.

## 7.1 Pastikan group 4 bukan CURRENT

```sql
SELECT group#,
       status
FROM v$log
WHERE group# = 4;
```

Contoh output jika masih CURRENT:

```text
    GROUP# STATUS
---------- ---------------
         4 CURRENT
```

Jika masih `CURRENT`, lakukan switch beberapa kali:

```sql
ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM CHECKPOINT;
```

Cek lagi:

```sql
SELECT group#,
       status
FROM v$log
WHERE group# = 4;
```

Contoh output yang aman:

```text
    GROUP# STATUS
---------- ---------------
         4 INACTIVE
```

## 7.2 Drop redo log group

```sql
ALTER DATABASE DROP LOGFILE GROUP 4;
```

Contoh output:

```text
Database altered.
```

## 7.3 Verifikasi group sudah hilang

```sql
SELECT group#,
       status
FROM v$log
ORDER BY group#;
```

Contoh output:

```text
    GROUP# STATUS
---------- ---------------
         1 INACTIVE
         2 CURRENT
         3 INACTIVE
```

## 7.4 Hapus file fisik jika masih ada

```bash
rm -f /u01/app/oracle/oradata/ORADB/redo04.log
ls -lh /u01/app/oracle/oradata/ORADB/redo04.log
```

Contoh output:

```text
ls: cannot access '/u01/app/oracle/oradata/ORADB/redo04.log': No such file or directory
```

---

# LAB 8 — Resize Redo Log Secara Manual

Redo log tidak dapat di-resize langsung. Cara resize adalah:

```text
1. Tambah group baru dengan ukuran baru.
2. Switch logfile sampai group lama tidak CURRENT.
3. Drop group lama.
```

Contoh: resize redo log dari 200M menjadi 300M.

## 8.1 Tambahkan group baru ukuran 300M

```sql
ALTER DATABASE ADD LOGFILE GROUP 4
'/u01/app/oracle/oradata/ORADB/redo04_300m.log'
SIZE 300M;

ALTER DATABASE ADD LOGFILE GROUP 5
'/u01/app/oracle/oradata/ORADB/redo05_300m.log'
SIZE 300M;

ALTER DATABASE ADD LOGFILE GROUP 6
'/u01/app/oracle/oradata/ORADB/redo06_300m.log'
SIZE 300M;
```

Contoh output:

```text
Database altered.
Database altered.
Database altered.
```

## 8.2 Verifikasi group baru

```sql
SELECT group#,
       bytes/1024/1024 AS size_mb,
       status
FROM v$log
ORDER BY group#;
```

Contoh output:

```text
    GROUP#    SIZE_MB STATUS
---------- ---------- ---------------
         1        200 INACTIVE
         2        200 CURRENT
         3        200 INACTIVE
         4        300 UNUSED
         5        300 UNUSED
         6        300 UNUSED
```

## 8.3 Switch sampai group baru digunakan

```sql
ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM CHECKPOINT;
```

Verifikasi:

```sql
SELECT group#,
       bytes/1024/1024 AS size_mb,
       archived,
       status
FROM v$log
ORDER BY group#;
```

Contoh output:

```text
    GROUP#    SIZE_MB ARC STATUS
---------- ---------- --- ---------------
         1        200 YES INACTIVE
         2        200 YES INACTIVE
         3        200 YES INACTIVE
         4        300 YES INACTIVE
         5        300 YES INACTIVE
         6        300 NO  CURRENT
```

## 8.4 Drop group lama

```sql
ALTER DATABASE DROP LOGFILE GROUP 1;
ALTER DATABASE DROP LOGFILE GROUP 2;
ALTER DATABASE DROP LOGFILE GROUP 3;
```

Contoh output:

```text
Database altered.
Database altered.
Database altered.
```

Jika muncul error:

```text
ORA-01623: log 2 is current log for instance ORADB
```

Lakukan:

```sql
ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM CHECKPOINT;
```

Lalu ulangi drop group tersebut.

## 8.5 Verifikasi hasil resize

```sql
SELECT group#,
       bytes/1024/1024 AS size_mb,
       status
FROM v$log
ORDER BY group#;
```

Contoh output:

```text
    GROUP#    SIZE_MB STATUS
---------- ---------- ---------------
         4        300 INACTIVE
         5        300 INACTIVE
         6        300 CURRENT
```

---

# LAB 9 — Membuat Redo Log Multiplexed dengan Ukuran Baru

## 9.1 Buat folder mirror

```bash
mkdir -p /u01/app/oracle/oradata/ORADB/redo_mirror
```

## 9.2 Tambahkan member kedua ke setiap group

```sql
ALTER DATABASE ADD LOGFILE MEMBER
'/u01/app/oracle/oradata/ORADB/redo_mirror/redo04b_300m.log'
TO GROUP 4;

ALTER DATABASE ADD LOGFILE MEMBER
'/u01/app/oracle/oradata/ORADB/redo_mirror/redo05b_300m.log'
TO GROUP 5;

ALTER DATABASE ADD LOGFILE MEMBER
'/u01/app/oracle/oradata/ORADB/redo_mirror/redo06b_300m.log'
TO GROUP 6;
```

Contoh output:

```text
Database altered.
Database altered.
Database altered.
```

## 9.3 Verifikasi multiplexing

```sql
SELECT l.group#,
       l.bytes/1024/1024 AS size_mb,
       l.members,
       f.member
FROM v$log l
JOIN v$logfile f
ON l.group# = f.group#
ORDER BY l.group#, f.member;
```

Contoh output:

```text
    GROUP#    SIZE_MB    MEMBERS MEMBER
---------- ---------- ---------- ------------------------------------------------------------
         4        300          2 /u01/app/oracle/oradata/ORADB/redo04_300m.log
         4        300          2 /u01/app/oracle/oradata/ORADB/redo_mirror/redo04b_300m.log
         5        300          2 /u01/app/oracle/oradata/ORADB/redo05_300m.log
         5        300          2 /u01/app/oracle/oradata/ORADB/redo_mirror/redo05b_300m.log
         6        300          2 /u01/app/oracle/oradata/ORADB/redo06_300m.log
         6        300          2 /u01/app/oracle/oradata/ORADB/redo_mirror/redo06b_300m.log
```

---

# LAB 10 — Memindahkan Lokasi Redo Log

Redo log tidak dipindahkan dengan `ALTER DATABASE MOVE DATAFILE`, karena redo log bukan datafile.

Cara aman:

```text
1. Tambahkan member baru di lokasi baru.
2. Drop member lama.
```

## 10.1 Buat lokasi baru

```bash
mkdir -p /u01/app/oracle/oradata/ORADB/redo_newloc
```

Verifikasi:

```bash
ls -ld /u01/app/oracle/oradata/ORADB/redo_newloc
```

Contoh output:

```text
drwxr-xr-x. 2 oracle oinstall 6 Jul  4 09:45 /u01/app/oracle/oradata/ORADB/redo_newloc
```

## 10.2 Tambahkan member baru ke group 4

```sql
ALTER DATABASE ADD LOGFILE MEMBER
'/u01/app/oracle/oradata/ORADB/redo_newloc/redo04_newloc.log'
TO GROUP 4;
```

Contoh output:

```text
Database altered.
```

## 10.3 Verifikasi group 4

```sql
SELECT group#,
       member,
       status
FROM v$logfile
WHERE group# = 4;
```

Contoh output:

```text
    GROUP# MEMBER
---------- ------------------------------------------------------------
         4 /u01/app/oracle/oradata/ORADB/redo04_300m.log
         4 /u01/app/oracle/oradata/ORADB/redo_mirror/redo04b_300m.log
         4 /u01/app/oracle/oradata/ORADB/redo_newloc/redo04_newloc.log
```

## 10.4 Drop member lama

```sql
ALTER DATABASE DROP LOGFILE MEMBER
'/u01/app/oracle/oradata/ORADB/redo04_300m.log';
```

Contoh output:

```text
Database altered.
```

## 10.5 Verifikasi lokasi baru

```sql
SELECT group#,
       member
FROM v$logfile
WHERE group# = 4
ORDER BY member;
```

Contoh output:

```text
    GROUP# MEMBER
---------- ------------------------------------------------------------
         4 /u01/app/oracle/oradata/ORADB/redo_mirror/redo04b_300m.log
         4 /u01/app/oracle/oradata/ORADB/redo_newloc/redo04_newloc.log
```

## 10.6 Hapus file lama dari OS jika masih ada

```bash
rm -f /u01/app/oracle/oradata/ORADB/redo04_300m.log
```

---

# LAB 11 — Mengecek Mode Archive Log

## 11.1 Cek archive log mode

```sql
ARCHIVE LOG LIST
```

Contoh output:

```text
Database log mode              Archive Mode
Automatic archival             Enabled
Archive destination            USE_DB_RECOVERY_FILE_DEST
Oldest online log sequence     24
Next log sequence to archive   27
Current log sequence           27
```

## 11.2 Cek dari v$database

```sql
SELECT name,
       log_mode
FROM v$database;
```

Contoh output:

```text
NAME      LOG_MODE
--------- ------------
ORADB     ARCHIVELOG
```

---

# LAB 12 — Mengaktifkan Archive Log Mode

Lewati lab ini jika database sudah `ARCHIVELOG`.

## 12.1 Shutdown database

```sql
SHUTDOWN IMMEDIATE;
```

Contoh output:

```text
Database closed.
Database dismounted.
ORACLE instance shut down.
```

## 12.2 Startup mount

```sql
STARTUP MOUNT;
```

Contoh output:

```text
ORACLE instance started.
Database mounted.
```

## 12.3 Aktifkan archive log

```sql
ALTER DATABASE ARCHIVELOG;
```

Contoh output:

```text
Database altered.
```

## 12.4 Open database

```sql
ALTER DATABASE OPEN;
```

Contoh output:

```text
Database altered.
```

## 12.5 Buka semua PDB

```sql
ALTER PLUGGABLE DATABASE ALL OPEN;
```

Contoh output:

```text
Pluggable database altered.
```

## 12.6 Verifikasi

```sql
ARCHIVE LOG LIST
```

Contoh output:

```text
Database log mode              Archive Mode
Automatic archival             Enabled
```

---

# LAB 13 — Menonaktifkan Archive Log Mode

Catatan: ini tidak disarankan di production karena backup recovery menjadi terbatas.

## 13.1 Shutdown database

```sql
SHUTDOWN IMMEDIATE;
```

## 13.2 Startup mount

```sql
STARTUP MOUNT;
```

## 13.3 Nonaktifkan archive log

```sql
ALTER DATABASE NOARCHIVELOG;
```

Contoh output:

```text
Database altered.
```

## 13.4 Open database

```sql
ALTER DATABASE OPEN;
ALTER PLUGGABLE DATABASE ALL OPEN;
```

## 13.5 Verifikasi

```sql
ARCHIVE LOG LIST
```

Contoh output:

```text
Database log mode              No Archive Mode
Automatic archival             Disabled
```

## 13.6 Aktifkan kembali ARCHIVELOG untuk lab berikutnya

```sql
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;
ALTER PLUGGABLE DATABASE ALL OPEN;
```

Verifikasi:

```sql
ARCHIVE LOG LIST
```

Contoh output:

```text
Database log mode              Archive Mode
Automatic archival             Enabled
```

---

# LAB 14 — Mengatur Lokasi Archive Log Manual

## 14.1 Buat folder archive log

```bash
mkdir -p /u01/app/oracle/archivelog/ORADB
```

Verifikasi:

```bash
ls -ld /u01/app/oracle/archivelog/ORADB
```

Contoh output:

```text
drwxr-xr-x. 2 oracle oinstall 6 Jul  4 10:00 /u01/app/oracle/archivelog/ORADB
```

## 14.2 Set archive destination

```sql
ALTER SYSTEM SET log_archive_dest_1 =
'LOCATION=/u01/app/oracle/archivelog/ORADB'
SCOPE=BOTH;
```

Contoh output:

```text
System altered.
```

## 14.3 Set format archive log

```sql
ALTER SYSTEM SET log_archive_format =
'arch_%t_%s_%r.arc'
SCOPE=SPFILE;
```

Contoh output:

```text
System altered.
```

Catatan: perubahan `log_archive_format` biasanya efektif setelah restart instance.

## 14.4 Restart database

```sql
SHUTDOWN IMMEDIATE;
STARTUP;
ALTER PLUGGABLE DATABASE ALL OPEN;
```

## 14.5 Verifikasi archive destination

```sql
ARCHIVE LOG LIST
```

Contoh output:

```text
Database log mode              Archive Mode
Automatic archival             Enabled
Archive destination            /u01/app/oracle/archivelog/ORADB
```

## 14.6 Verifikasi parameter

```sql
SHOW PARAMETER log_archive_dest_1
SHOW PARAMETER log_archive_format
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- --------------------------------------------
log_archive_dest_1                   string      LOCATION=/u01/app/oracle/archivelog/ORADB

NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
log_archive_format                   string      arch_%t_%s_%r.arc
```

---

# LAB 15 — Force Archive Log

## 15.1 Jalankan log switch

```sql
ALTER SYSTEM SWITCH LOGFILE;
```

Contoh output:

```text
System altered.
```

## 15.2 Archive semua redo yang belum diarsipkan

```sql
ALTER SYSTEM ARCHIVE LOG ALL;
```

Contoh output:

```text
System altered.
```

## 15.3 Verifikasi file archive di OS

```bash
ls -lh /u01/app/oracle/archivelog/ORADB
```

Contoh output:

```text
-rw-r-----. 1 oracle oinstall 18M Jul  4 10:15 arch_1_28_1172345678.arc
-rw-r-----. 1 oracle oinstall 12M Jul  4 10:16 arch_1_29_1172345678.arc
```

---

# LAB 16 — Monitoring Archive Log

## 16.1 Lihat archive log dari database

```sql
SET LINESIZE 200
COLUMN name FORMAT A90
COLUMN first_time FORMAT A20

SELECT sequence#,
       name,
       first_time,
       blocks,
       block_size,
       applied,
       deleted,
       status
FROM v$archived_log
WHERE name IS NOT NULL
ORDER BY sequence# DESC
FETCH FIRST 10 ROWS ONLY;
```

Contoh output:

```text
 SEQUENCE# NAME                                                FIRST_TIME           BLOCKS BLOCK_SIZE APP DEL S
---------- --------------------------------------------------- -------------------- ------ ---------- --- --- -
        29 /u01/app/oracle/archivelog/ORADB/arch_1_29_117.arc  04-JUL-26              1536       512 NO  NO  A
        28 /u01/app/oracle/archivelog/ORADB/arch_1_28_117.arc  04-JUL-26              2304       512 NO  NO  A
```

## 16.2 Cek jumlah archive log per hari

```sql
SELECT TO_CHAR(first_time, 'YYYY-MM-DD') AS tanggal,
       COUNT(*) AS jumlah_archivelog
FROM v$archived_log
WHERE name IS NOT NULL
GROUP BY TO_CHAR(first_time, 'YYYY-MM-DD')
ORDER BY tanggal;
```

Contoh output:

```text
TANGGAL     JUMLAH_ARCHIVELOG
---------- ------------------
2026-07-04                  8
```

---

# LAB 17 — Mengatur Fast Recovery Area untuk Archive Log

Selain menggunakan folder manual, archive log dapat diarahkan ke FRA.

## 17.1 Buat folder FRA

```bash
mkdir -p /u01/app/oracle/fast_recovery_area
```

## 17.2 Set FRA

```sql
ALTER SYSTEM SET db_recovery_file_dest_size = 5G SCOPE=BOTH;

ALTER SYSTEM SET db_recovery_file_dest =
'/u01/app/oracle/fast_recovery_area'
SCOPE=BOTH;
```

Contoh output:

```text
System altered.
System altered.
```

## 17.3 Arahkan archive log ke FRA

```sql
ALTER SYSTEM SET log_archive_dest_1 =
'LOCATION=USE_DB_RECOVERY_FILE_DEST'
SCOPE=BOTH;
```

Contoh output:

```text
System altered.
```

## 17.4 Verifikasi

```sql
SHOW PARAMETER db_recovery_file_dest
SHOW PARAMETER log_archive_dest_1
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- ----------------------------------------
db_recovery_file_dest                string      /u01/app/oracle/fast_recovery_area
db_recovery_file_dest_size           big integer 5G

NAME                                 TYPE        VALUE
------------------------------------ ----------- ----------------------------------------
log_archive_dest_1                   string      LOCATION=USE_DB_RECOVERY_FILE_DEST
```

## 17.5 Generate archive log

```sql
ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM ARCHIVE LOG ALL;
```

## 17.6 Verifikasi archive log di FRA

```bash
find /u01/app/oracle/fast_recovery_area -type f | head
```

Contoh output:

```text
/u01/app/oracle/fast_recovery_area/ORADB/archivelog/2026_07_04/o1_mf_1_30_xxxxxx.arc
```

---

# LAB 18 — Monitoring Penggunaan FRA

## 18.1 Cek kapasitas FRA

```sql
SELECT name,
       space_limit/1024/1024 AS limit_mb,
       space_used/1024/1024 AS used_mb,
       space_reclaimable/1024/1024 AS reclaimable_mb,
       number_of_files
FROM v$recovery_file_dest;
```

Contoh output:

```text
NAME                                      LIMIT_MB    USED_MB RECLAIMABLE_MB NUMBER_OF_FILES
---------------------------------------- --------- ---------- -------------- ---------------
/u01/app/oracle/fast_recovery_area            5120        350              0              12
```

## 18.2 Cek jenis file di FRA

```sql
SELECT file_type,
       percent_space_used,
       percent_space_reclaimable,
       number_of_files
FROM v$flash_recovery_area_usage;
```

Contoh output:

```text
FILE_TYPE               PERCENT_SPACE_USED PERCENT_SPACE_RECLAIMABLE NUMBER_OF_FILES
----------------------- ------------------ ------------------------- ---------------
ARCHIVED LOG                          6.20                         0              10
BACKUP PIECE                          0.00                         0               0
IMAGE COPY                            0.00                         0               0
FLASHBACK LOG                         0.00                         0               0
```

---

# LAB 19 — Simulasi Redo dan Archive Log Activity

## 19.1 Masuk ke PDB1

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

## 19.2 Buat tablespace testing

```sql
CREATE TABLESPACE TS_REDO_TEST
DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/ts_redo_test01.dbf'
SIZE 100M
AUTOEXTEND ON
NEXT 50M
MAXSIZE 1G;
```

Contoh output:

```text
Tablespace created.
```

## 19.3 Buat user testing

```sql
CREATE USER redouser IDENTIFIED BY oracle
DEFAULT TABLESPACE TS_REDO_TEST
TEMPORARY TABLESPACE TEMP
QUOTA UNLIMITED ON TS_REDO_TEST;
```

Contoh output:

```text
User created.
```

## 19.4 Grant privilege

```sql
GRANT CREATE SESSION, CREATE TABLE TO redouser;
```

Contoh output:

```text
Grant succeeded.
```

## 19.5 Login sebagai redouser

```sql
CONN redouser/oracle@localhost:1521/pdb1.localdomain
```

Contoh output:

```text
Connected.
```

## 19.6 Buat data besar untuk menghasilkan redo

```sql
CREATE TABLE redo_activity AS
SELECT LEVEL AS id,
       RPAD('DATA REDO TEST', 500, 'X') AS description
FROM dual
CONNECT BY LEVEL <= 100000;

COMMIT;
```

Contoh output:

```text
Table created.

Commit complete.
```

## 19.7 Update data untuk menghasilkan redo tambahan

```sql
UPDATE redo_activity
SET description = RPAD('DATA REDO UPDATED', 500, 'Y');

COMMIT;
```

Contoh output:

```text
100000 rows updated.

Commit complete.
```

## 19.8 Force log switch

```sql
CONN / AS SYSDBA

ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM ARCHIVE LOG ALL;
```

Contoh output:

```text
System altered.
System altered.
```

## 19.9 Verifikasi archive log bertambah

```sql
SELECT sequence#,
       name,
       first_time
FROM v$archived_log
WHERE name IS NOT NULL
ORDER BY sequence# DESC
FETCH FIRST 5 ROWS ONLY;
```

Contoh output:

```text
 SEQUENCE# NAME                                                                  FIRST_TIME
---------- --------------------------------------------------------------------- --------------------
        32 /u01/app/oracle/fast_recovery_area/ORADB/archivelog/.../o1_mf.arc    04-JUL-26
        31 /u01/app/oracle/fast_recovery_area/ORADB/archivelog/.../o1_mf.arc    04-JUL-26
        30 /u01/app/oracle/fast_recovery_area/ORADB/archivelog/.../o1_mf.arc    04-JUL-26
```

---

# LAB 20 — Melihat Redo Size dari Statistik

## 20.1 Cek total redo size

```sql
SELECT name,
       value
FROM v$sysstat
WHERE name = 'redo size';
```

Contoh output:

```text
NAME           VALUE
-------------- ----------
redo size      135892214
```

## 20.2 Cek redo entries

```sql
SELECT name,
       value
FROM v$sysstat
WHERE name IN ('redo size', 'redo entries', 'redo writes');
```

Contoh output:

```text
NAME              VALUE
----------------- ----------
redo entries      215640
redo size         135892214
redo writes       3621
```

---

# LAB 21 — Melihat History Log Switch

```sql
COLUMN first_time FORMAT A20

SELECT sequence#,
       first_time,
       next_time,
       archived,
       status
FROM v$log_history
ORDER BY sequence# DESC
FETCH FIRST 10 ROWS ONLY;
```

Contoh output:

```text
 SEQUENCE# FIRST_TIME           NEXT_TIME            ARC STATUS
---------- -------------------- -------------------- --- ----------
        32 04-JUL-26            04-JUL-26
        31 04-JUL-26            04-JUL-26
        30 04-JUL-26            04-JUL-26
```

---

# LAB 22 — Membersihkan Archive Log Menggunakan RMAN

Jangan hapus archive log manual dengan `rm` di production. Gunakan RMAN agar metadata repository tetap sinkron.

## 22.1 Masuk RMAN

```bash
rman target /
```

## 22.2 Lihat archive log

```rman
LIST ARCHIVELOG ALL;
```

Contoh output:

```text
List of Archived Log Copies for database with db_unique_name ORADB
=====================================================================

Key     Thrd Seq     S Low Time
------- ---- ------- - ---------
12      1    30      A 04-JUL-26
13      1    31      A 04-JUL-26
14      1    32      A 04-JUL-26
```

## 22.3 Crosscheck archive log

```rman
CROSSCHECK ARCHIVELOG ALL;
```

Contoh output:

```text
validation succeeded for archived log
crosschecked archived log: found to be 'AVAILABLE'
```

## 22.4 Delete archive log lama

Contoh hapus archive log yang lebih lama dari 1 hari:

```rman
DELETE NOPROMPT ARCHIVELOG ALL COMPLETED BEFORE 'SYSDATE-1';
```

Contoh output:

```text
deleted archived log
Archived Log records deleted
```

Untuk lab, jika ingin hapus semua archive log yang sudah tidak dibutuhkan:

```rman
DELETE NOPROMPT ARCHIVELOG ALL;
```

Contoh output:

```text
deleted archived log
Archived Log records deleted
```

Keluar RMAN:

```rman
EXIT;
```

---

# LAB 23 — Menghapus Metadata Archive Log yang File-nya Sudah Hilang

Jika file archive log terhapus manual dari OS, lakukan crosscheck dan delete expired.

```bash
rman target /
```

```rman
CROSSCHECK ARCHIVELOG ALL;
DELETE NOPROMPT EXPIRED ARCHIVELOG ALL;
EXIT;
```

Contoh output:

```text
crosschecked archived log: found to be 'EXPIRED'
Deleted expired archived log
```

---

# LAB 24 — Cleanup Object Testing

Masuk SQL*Plus:

```bash
sqlplus / as sysdba
```

Masuk PDB1:

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

Drop user testing:

```sql
DROP USER redouser CASCADE;
```

Contoh output:

```text
User dropped.
```

Drop tablespace testing:

```sql
DROP TABLESPACE TS_REDO_TEST INCLUDING CONTENTS AND DATAFILES;
```

Contoh output:

```text
Tablespace dropped.
```

Verifikasi:

```sql
SELECT username
FROM dba_users
WHERE username = 'REDOUSER';
```

Contoh output:

```text
no rows selected
```

```sql
SELECT tablespace_name
FROM dba_tablespaces
WHERE tablespace_name = 'TS_REDO_TEST';
```

Contoh output:

```text
no rows selected
```

---

# LAB 25 — Cleanup Redo Log Lab ke Kondisi Normal

Jika ingin kembali ke 3 group ukuran 200M:

## 25.1 Tambahkan kembali group 1, 2, 3 ukuran 200M

```sql
CONN / AS SYSDBA

ALTER DATABASE ADD LOGFILE GROUP 1
'/u01/app/oracle/oradata/ORADB/redo01.log'
SIZE 200M;

ALTER DATABASE ADD LOGFILE GROUP 2
'/u01/app/oracle/oradata/ORADB/redo02.log'
SIZE 200M;

ALTER DATABASE ADD LOGFILE GROUP 3
'/u01/app/oracle/oradata/ORADB/redo03.log'
SIZE 200M;
```

Contoh output:

```text
Database altered.
Database altered.
Database altered.
```

## 25.2 Switch sampai group 4, 5, 6 tidak CURRENT

```sql
ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM CHECKPOINT;
```

## 25.3 Verifikasi status

```sql
SELECT group#,
       bytes/1024/1024 AS size_mb,
       status
FROM v$log
ORDER BY group#;
```

Contoh output:

```text
    GROUP#    SIZE_MB STATUS
---------- ---------- ---------------
         1        200 INACTIVE
         2        200 INACTIVE
         3        200 CURRENT
         4        300 INACTIVE
         5        300 INACTIVE
         6        300 INACTIVE
```

## 25.4 Drop group 4, 5, 6

```sql
ALTER DATABASE DROP LOGFILE GROUP 4;
ALTER DATABASE DROP LOGFILE GROUP 5;
ALTER DATABASE DROP LOGFILE GROUP 6;
```

Contoh output:

```text
Database altered.
Database altered.
Database altered.
```

## 25.5 Hapus file redo lab dari OS

```bash
rm -f /u01/app/oracle/oradata/ORADB/redo04_300m.log
rm -f /u01/app/oracle/oradata/ORADB/redo05_300m.log
rm -f /u01/app/oracle/oradata/ORADB/redo06_300m.log
rm -f /u01/app/oracle/oradata/ORADB/redo_mirror/redo04b_300m.log
rm -f /u01/app/oracle/oradata/ORADB/redo_mirror/redo05b_300m.log
rm -f /u01/app/oracle/oradata/ORADB/redo_mirror/redo06b_300m.log
rm -f /u01/app/oracle/oradata/ORADB/redo_newloc/redo04_newloc.log
```

## 25.6 Verifikasi akhir

```sql
SELECT group#,
       bytes/1024/1024 AS size_mb,
       members,
       archived,
       status
FROM v$log
ORDER BY group#;
```

Contoh output:

```text
    GROUP#    SIZE_MB    MEMBERS ARC STATUS
---------- ---------- ---------- --- ---------------
         1        200          1 YES INACTIVE
         2        200          1 YES INACTIVE
         3        200          1 NO  CURRENT
```

---

# Ringkasan Command Penting

Tambah redo log group:

```sql
ALTER DATABASE ADD LOGFILE GROUP 4
'/u01/app/oracle/oradata/ORADB/redo04.log'
SIZE 200M;
```

Tambah redo log member:

```sql
ALTER DATABASE ADD LOGFILE MEMBER
'/u01/app/oracle/oradata/ORADB/redo_mirror/redo04b.log'
TO GROUP 4;
```

Drop redo log member:

```sql
ALTER DATABASE DROP LOGFILE MEMBER
'/u01/app/oracle/oradata/ORADB/redo_mirror/redo04b.log';
```

Drop redo log group:

```sql
ALTER DATABASE DROP LOGFILE GROUP 4;
```

Log switch:

```sql
ALTER SYSTEM SWITCH LOGFILE;
```

Checkpoint:

```sql
ALTER SYSTEM CHECKPOINT;
```

Aktifkan archive log:

```sql
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;
ALTER PLUGGABLE DATABASE ALL OPEN;
```

Cek archive log:

```sql
ARCHIVE LOG LIST;
```

Set archive destination:

```sql
ALTER SYSTEM SET log_archive_dest_1 =
'LOCATION=/u01/app/oracle/archivelog/ORADB'
SCOPE=BOTH;
```

Force archive:

```sql
ALTER SYSTEM ARCHIVE LOG ALL;
```

Hapus archive log via RMAN:

```rman
DELETE NOPROMPT ARCHIVELOG ALL COMPLETED BEFORE 'SYSDATE-1';
```

---

Catatan akhir: **redo log tidak memiliki resize otomatis atau autoextend**. Untuk memperbesar atau memperkecil redo log, DBA harus membuat group baru dengan ukuran yang diinginkan, melakukan log switch, lalu menghapus group lama.
