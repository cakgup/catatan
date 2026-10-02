# Cheat Sheet Oracle Day 3 — Storage and Data Management

**Topik silabus:** *Storage and Data Management*  
**Fokus belajar:** control file, datafile, tempfile, online redo log, archive log, tablespace permanent/temp/undo, smallfile vs bigfile, segment-space management, storage monitoring, capacity planning, serta memory management ringkas.


> **Catatan penggunaan:** contoh output pada file ini bersifat realistis untuk lab Oracle 19c, tetapi nilai seperti hostname, path, ukuran file, `SID`, `SERVICE_NAME`, `CON_ID`, `SQL_ID`, dan status dapat berbeda sesuai environment. Jalankan command berurutan, baca output-nya, lalu cocokkan dengan bagian *cara membaca output*.

> **Asumsi lab umum:** CDB `ORADB`, PDB `PDB1`, OS Oracle Linux, user OS `oracle`, Oracle Database 19c, path umum `/u01/app/oracle/oradata/ORADB`.


---

## 1. Peta Belajar Day 3

| Modul | Materi | Target praktik |
|---|---|---|
| Storage Architecture | Datafile, control file, redo log, archive log | Mengidentifikasi dan mengelola file penting Oracle |
| Tablespace Administration | Permanent, temporary, undo | Membuat, resize, autoextend, offline/online, drop |
| Segment & Space | Segment, extent, block, growth | Memantau pemakaian tablespace dan segment |
| Memory Management | SGA, PGA, AMM, ASMM | Membaca parameter dan advisory memory dasar |

---

## 2. Peta Konsep Storage

```text
Physical Structure
├── Datafile       -> menyimpan object permanen
├── Tempfile       -> menyimpan data sementara sort/hash
├── Control file   -> metadata database
├── Online redo log-> catatan perubahan aktif
└── Archive log    -> salinan redo lama untuk recovery

Logical Structure
└── Tablespace -> Segment -> Extent -> Block
```

**Kunci hafalan:** tablespace adalah logis, datafile/tempfile/controlfile/redo adalah fisik.

---

## 3. Control File Management

### 3.1 Catatan penting

```text
Control file dikelola di level CDB, bukan PDB.
Control file tidak memiliki autoextend.
Control file tidak di-resize manual seperti datafile.
Best practice: multiplex control file, minimal 2 copy di lokasi berbeda.
```

### 3.2 Cek control file

```sql
SHOW PARAMETER control_files;

SET LINESIZE 200
COL name FORMAT A90
SELECT name, status, is_recovery_dest_file, block_size, file_size_blks
FROM v$controlfile;
```

**Contoh output:**

```text
NAME                                                       STATUS IS_ BLOCK_SIZE FILE_SIZE_BLKS
---------------------------------------------------------- ------ --- ---------- --------------
/u01/app/oracle/oradata/ORADB/control01.ctl                       NO       16384            618
/u01/app/oracle/oradata/ORADB/control_mirror/control02.ctl         NO       16384            618
```

### 3.3 Multiplex control file

```bash
mkdir -p /u01/app/oracle/oradata/ORADB/control_mirror
```

```sql
SHUTDOWN IMMEDIATE;
```

```bash
cp /u01/app/oracle/oradata/ORADB/control01.ctl /u01/app/oracle/oradata/ORADB/control_mirror/control02.ctl
```

```sql
STARTUP NOMOUNT;
ALTER SYSTEM SET control_files =
'/u01/app/oracle/oradata/ORADB/control01.ctl',
'/u01/app/oracle/oradata/ORADB/control_mirror/control02.ctl'
SCOPE=SPFILE;
SHUTDOWN IMMEDIATE;
STARTUP;
ALTER PLUGGABLE DATABASE ALL OPEN;
SELECT name FROM v$controlfile;
```

### 3.4 Backup control file

Binary backup:

```sql
ALTER DATABASE BACKUP CONTROLFILE TO
'/u01/app/oracle/oradata/ORADB/controlfile_backup_binary.bkp';
```

Trace/script backup:

```sql
ALTER DATABASE BACKUP CONTROLFILE TO TRACE;
SELECT value FROM v$diag_info WHERE name='Default Trace File';
```

**Fungsi trace:** menghasilkan script `CREATE CONTROLFILE` untuk kondisi recovery khusus.

---

## 4. Online Redo Log dan Archive Log

### 4.1 Konsep utama

```text
Redo log dikelola di level CDB.
Redo log ditulis sequential oleh LGWR.
Redo log tidak bisa resize langsung.
Redo log tidak punya AUTOEXTEND.
Untuk resize: buat group baru ukuran baru -> switch -> drop group lama.
```

### 4.2 Cek redo log group

```sql
SET LINESIZE 200
COL member FORMAT A85

SELECT group#, thread#, sequence#, bytes/1024/1024 AS size_mb,
       members, archived, status
FROM v$log
ORDER BY group#;
```

**Contoh output:**

```text
GROUP# THREAD# SEQUENCE# SIZE_MB MEMBERS ARC STATUS
------ ------- --------- ------- ------- --- --------
1      1       21        200     1       YES INACTIVE
2      1       22        200     1       NO  CURRENT
3      1       20        200     1       YES INACTIVE
```

### 4.3 Cek lokasi redo log member

```sql
SELECT group#, type, member, status
FROM v$logfile
ORDER BY group#, member;
```

### 4.4 Status redo log

| Status | Makna |
|---|---|
| `CURRENT` | Sedang ditulis LGWR, tidak boleh dihapus |
| `ACTIVE` | Masih diperlukan untuk recovery |
| `INACTIVE` | Aman untuk di-drop jika syarat lain terpenuhi |
| `UNUSED` | Baru dibuat, belum pernah digunakan |

### 4.5 Tambah redo log group

```sql
ALTER DATABASE ADD LOGFILE GROUP 4
'/u01/app/oracle/oradata/ORADB/redo04.log'
SIZE 200M;
```

**Contoh output:**

```text
Database altered.
```

### 4.6 Multiplex redo log member

```bash
mkdir -p /u01/app/oracle/oradata/ORADB/redo_mirror
```

```sql
ALTER DATABASE ADD LOGFILE MEMBER
'/u01/app/oracle/oradata/ORADB/redo_mirror/redo04b.log'
TO GROUP 4;
```

**Fungsi:** membuat salinan redo log dalam group yang sama untuk redundancy.

### 4.7 Switch logfile dan checkpoint

```sql
ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM CHECKPOINT;
```

**Fungsi:** menggeser `CURRENT` group dan membantu mengubah `ACTIVE` menjadi `INACTIVE`.

### 4.8 Drop redo log member/group

```sql
ALTER DATABASE DROP LOGFILE MEMBER
'/u01/app/oracle/oradata/ORADB/redo_mirror/redo04b.log';

ALTER DATABASE DROP LOGFILE GROUP 4;
```

**Syarat aman:** group bukan `CURRENT`, tidak diperlukan recovery, dan database masih punya jumlah group minimum.

### 4.9 Resize redo log

```sql
ALTER DATABASE ADD LOGFILE GROUP 4 '/u01/app/oracle/oradata/ORADB/redo04_300m.log' SIZE 300M;
ALTER DATABASE ADD LOGFILE GROUP 5 '/u01/app/oracle/oradata/ORADB/redo05_300m.log' SIZE 300M;
ALTER DATABASE ADD LOGFILE GROUP 6 '/u01/app/oracle/oradata/ORADB/redo06_300m.log' SIZE 300M;
ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM CHECKPOINT;
ALTER DATABASE DROP LOGFILE GROUP 1;
ALTER DATABASE DROP LOGFILE GROUP 2;
ALTER DATABASE DROP LOGFILE GROUP 3;
```

### 4.10 Cek archive log mode

```sql
ARCHIVE LOG LIST;
```

**Contoh output:**

```text
Database log mode              Archive Mode
Automatic archival             Enabled
Archive destination            USE_DB_RECOVERY_FILE_DEST
```

Jika belum ARCHIVELOG:

```sql
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;
ALTER PLUGGABLE DATABASE ALL OPEN;
```

---

## 5. Permanent Tablespace dan Datafile

### 5.1 Masuk ke PDB

```sql
ALTER SESSION SET CONTAINER=PDB1;
SHOW CON_NAME;
```

### 5.2 Cek tablespace dan datafile

```sql
SET LINESIZE 200
COL tablespace_name FORMAT A20
COL file_name FORMAT A90

SELECT tablespace_name, status, contents, extent_management, segment_space_management
FROM dba_tablespaces
ORDER BY tablespace_name;

SELECT tablespace_name, file_name, bytes/1024/1024 AS size_mb, autoextensible
FROM dba_data_files
ORDER BY tablespace_name, file_name;
```

### 5.3 Buat permanent tablespace

```sql
CREATE TABLESPACE TS_APPDATA
DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/ts_appdata01.dbf'
SIZE 100M
AUTOEXTEND OFF
EXTENT MANAGEMENT LOCAL
SEGMENT SPACE MANAGEMENT AUTO;
```

### 5.4 Tambah datafile

```sql
ALTER TABLESPACE TS_APPDATA
ADD DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/ts_appdata02.dbf'
SIZE 50M AUTOEXTEND OFF;
```

### 5.5 Resize datafile

```sql
ALTER DATABASE DATAFILE
'/u01/app/oracle/oradata/ORADB/pdb1/ts_appdata01.dbf'
RESIZE 150M;
```

Jika gagal saat memperkecil:

```text
ORA-03297: file contains used data beyond requested RESIZE value
```

Makna: ada extent data di bagian akhir file, sehingga file tidak bisa diperkecil sampai ukuran itu.

### 5.6 Autoextend datafile

```sql
ALTER DATABASE DATAFILE
'/u01/app/oracle/oradata/ORADB/pdb1/ts_appdata01.dbf'
AUTOEXTEND ON NEXT 10M MAXSIZE 300M;
```

Verifikasi:

```sql
SELECT file_name, bytes/1024/1024 AS size_mb, autoextensible,
       increment_by * 8 / 1024 AS next_mb,
       maxbytes/1024/1024 AS max_mb
FROM dba_data_files
WHERE file_name LIKE '%ts_appdata01.dbf';
```

**Catatan:** rumus `increment_by * 8 / 1024` mengasumsikan block size 8 KB.

---

## 6. Smallfile vs Bigfile Tablespace

```sql
SELECT tablespace_name, bigfile
FROM dba_tablespaces
ORDER BY tablespace_name;
```

| Jenis | Karakteristik |
|---|---|
| Smallfile | Satu tablespace dapat memiliki banyak datafile |
| Bigfile | Satu tablespace hanya punya satu datafile besar |

Buat bigfile:

```sql
CREATE BIGFILE TABLESPACE TS_GEDE
DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/ts_gede.dbf'
SIZE 100M;
```

Resize bigfile:

```sql
ALTER TABLESPACE TS_GEDE RESIZE 200M;
```

Command ini akan gagal pada bigfile karena bigfile tidak bisa ditambah datafile kedua:

```sql
ALTER TABLESPACE TS_GEDE
ADD DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/ts_gede02.dbf' SIZE 100M;
```

**Contoh error:**

```text
ORA-32771: cannot add file to bigfile tablespace
```

---

## 7. Tablespace Status: Read Only, Read Write, Offline, Online

### 7.1 Read only/read write

```sql
ALTER TABLESPACE TS_APPDATA READ ONLY;
SELECT tablespace_name, status FROM dba_tablespaces WHERE tablespace_name='TS_APPDATA';
ALTER TABLESPACE TS_APPDATA READ WRITE;
```

Saat read only, insert/update akan gagal.

### 7.2 Offline/online

```sql
ALTER TABLESPACE TS_APPDATA OFFLINE;
ALTER TABLESPACE TS_APPDATA ONLINE;
```

Jika object di tablespace offline diakses, bisa muncul:

```text
ORA-00376: file cannot be read at this time
ORA-01110: data file ...
```

---

## 8. Rename/Move Datafile

### 8.1 Move datafile online

```bash
mkdir -p /u01/app/oracle/oradata/ORADB/PDB1_MOVED
```

```sql
ALTER DATABASE MOVE DATAFILE
'/u01/app/oracle/oradata/ORADB/pdb1/ts_appdata01.dbf'
TO
'/u01/app/oracle/oradata/ORADB/PDB1_MOVED/ts_appdata01.dbf';
```

**Catatan penting:** command harus ditulis utuh. Jangan mengetik path sebagai command terpisah karena bisa muncul `SP2-0734` atau `SP2-0042`.

---

## 9. Temporary Tablespace

### 9.1 Konsep

```text
Temporary tablespace dibuat di level PDB.
Temporary tablespace memakai TEMPFILE, bukan DATAFILE.
Tempfile tidak menghasilkan redo seperti datafile biasa.
Tempfile biasanya tidak dibackup RMAN karena bisa dibuat ulang.
```

### 9.2 Cek temporary tablespace

```sql
SELECT tablespace_name, contents, status
FROM dba_tablespaces
WHERE contents='TEMPORARY';

SELECT tablespace_name, file_name, bytes/1024/1024 AS size_mb, autoextensible
FROM dba_temp_files;
```

### 9.3 Buat temporary tablespace

```sql
CREATE TEMPORARY TABLESPACE TEMP_LAB
TEMPFILE '/u01/app/oracle/oradata/ORADB/pdb1/temp_lab01.dbf'
SIZE 100M
AUTOEXTEND OFF
EXTENT MANAGEMENT LOCAL UNIFORM SIZE 1M;
```

### 9.4 Ubah default temporary tablespace

```sql
SELECT property_name, property_value
FROM database_properties
WHERE property_name='DEFAULT_TEMP_TABLESPACE';

ALTER DATABASE DEFAULT TEMPORARY TABLESPACE TEMP_LAB;
```

### 9.5 Assign temporary tablespace ke user

```sql
ALTER USER appuser TEMPORARY TABLESPACE TEMP_LAB;
```

### 9.6 Tambah/resize/autoextend tempfile

```sql
ALTER TABLESPACE TEMP_LAB
ADD TEMPFILE '/u01/app/oracle/oradata/ORADB/pdb1/temp_lab02.dbf'
SIZE 50M AUTOEXTEND OFF;

ALTER DATABASE TEMPFILE
'/u01/app/oracle/oradata/ORADB/pdb1/temp_lab02.dbf'
RESIZE 100M;

ALTER DATABASE TEMPFILE
'/u01/app/oracle/oradata/ORADB/pdb1/temp_lab02.dbf'
AUTOEXTEND ON NEXT 10M MAXSIZE 300M;
```

### 9.7 Monitoring TEMP

```sql
SELECT tablespace_name,
       used_blocks * 8 / 1024 AS used_mb,
       free_blocks * 8 / 1024 AS free_mb,
       total_blocks * 8 / 1024 AS total_mb
FROM v$sort_segment;

SELECT s.sid, s.serial#, s.username, u.tablespace,
       ROUND(u.blocks * 8 / 1024,2) AS used_mb,
       u.segtype, u.sql_id
FROM v$tempseg_usage u
JOIN v$session s ON u.session_addr = s.saddr
ORDER BY used_mb DESC;
```

---

## 10. UNDO Tablespace

### 10.1 Cek local undo

```sql
CONN / AS SYSDBA
SELECT property_name, property_value
FROM database_properties
WHERE property_name='LOCAL_UNDO_ENABLED';
```

Jika `TRUE`, tiap PDB dapat memiliki undo sendiri.

### 10.2 Cek undo tablespace

```sql
ALTER SESSION SET CONTAINER=PDB1;

SELECT tablespace_name, contents, status, retention
FROM dba_tablespaces
WHERE contents='UNDO';

SHOW PARAMETER undo_tablespace;
SHOW PARAMETER undo_retention;
```

### 10.3 Buat undo tablespace baru

```sql
CREATE UNDO TABLESPACE UNDOTBS_LAB
DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/undotbs_lab01.dbf'
SIZE 100M AUTOEXTEND OFF;
```

### 10.4 Aktifkan undo tablespace

```sql
ALTER SYSTEM SET undo_tablespace = UNDOTBS_LAB;
SHOW PARAMETER undo_tablespace;
```

### 10.5 Monitoring undo

```sql
SELECT TO_CHAR(begin_time, 'YYYY-MM-DD HH24:MI:SS') AS begin_time,
       undoblks, txncount, maxquerylen
FROM v$undostat
ORDER BY begin_time DESC
FETCH FIRST 10 ROWS ONLY;

SELECT s.sid, s.serial#, s.username, t.used_ublk, t.used_urec, s.status
FROM v$transaction t
JOIN v$session s ON t.ses_addr = s.saddr;
```

---

## 11. Segment dan Space Monitoring

### 11.1 Segment user

```sql
SELECT segment_name, segment_type, tablespace_name,
       ROUND(bytes/1024/1024,2) AS mb
FROM user_segments
ORDER BY bytes DESC;
```

### 11.2 Segment di tablespace tertentu

```sql
SELECT owner, segment_name, segment_type, extents, blocks,
       ROUND(bytes/1024/1024,2) AS mb
FROM dba_segments
WHERE tablespace_name='TS_APPDATA'
ORDER BY bytes DESC;
```

### 11.3 Laporan penggunaan tablespace

```sql
SELECT df.tablespace_name,
       ROUND(df.total_mb,2) AS total_mb,
       ROUND(NVL(fs.free_mb,0),2) AS free_mb,
       ROUND(df.total_mb - NVL(fs.free_mb,0),2) AS used_mb,
       ROUND(((df.total_mb - NVL(fs.free_mb,0)) / df.total_mb) * 100,2) AS used_pct
FROM (
    SELECT tablespace_name, SUM(bytes)/1024/1024 AS total_mb
    FROM dba_data_files
    GROUP BY tablespace_name
) df
LEFT JOIN (
    SELECT tablespace_name, SUM(bytes)/1024/1024 AS free_mb
    FROM dba_free_space
    GROUP BY tablespace_name
) fs ON df.tablespace_name = fs.tablespace_name
ORDER BY used_pct DESC;
```

---

## 12. Memory Management Ringkas

```sql
SHOW PARAMETER memory_target;
SHOW PARAMETER sga_target;
SHOW PARAMETER pga_aggregate_target;

SELECT component,
       current_size/1024/1024 AS current_mb
FROM v$sga_dynamic_components
WHERE current_size > 0
ORDER BY component;

SELECT name, value/1024/1024 AS value_mb
FROM v$pgastat
WHERE name IN ('aggregate PGA target parameter','total PGA allocated','total PGA inuse','maximum PGA allocated');
```

---

## 13. Lab Berurutan Day 3

```sql
-- 1. Masuk root dan cek file fisik utama
CONN / AS SYSDBA
SHOW CON_NAME;
SHOW PARAMETER control_files;
SELECT name FROM v$controlfile;
SELECT group#, status FROM v$log ORDER BY group#;
SELECT group#, member FROM v$logfile ORDER BY group#;
ARCHIVE LOG LIST;

-- 2. Masuk PDB untuk tablespace
ALTER SESSION SET CONTAINER=PDB1;
SELECT tablespace_name, contents, bigfile, status FROM dba_tablespaces ORDER BY tablespace_name;
SELECT tablespace_name, file_name FROM dba_data_files ORDER BY tablespace_name, file_name;

-- 3. Buat dan kelola tablespace
CREATE TABLESPACE TS_APPDATA DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/ts_appdata01.dbf' SIZE 100M AUTOEXTEND OFF;
ALTER TABLESPACE TS_APPDATA ADD DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/ts_appdata02.dbf' SIZE 50M;
ALTER DATABASE DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/ts_appdata01.dbf' RESIZE 150M;
ALTER DATABASE DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/ts_appdata01.dbf' AUTOEXTEND ON NEXT 10M MAXSIZE 300M;

-- 4. Temporary dan undo
CREATE TEMPORARY TABLESPACE TEMP_LAB TEMPFILE '/u01/app/oracle/oradata/ORADB/pdb1/temp_lab01.dbf' SIZE 100M;
CREATE UNDO TABLESPACE UNDOTBS_LAB DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/undotbs_lab01.dbf' SIZE 100M;
```

---

## 14. Troubleshooting Day 3

| Masalah | Penyebab umum | Solusi |
|---|---|---|
| Tidak bisa drop redo log | Status masih `CURRENT`/`ACTIVE` | `ALTER SYSTEM SWITCH LOGFILE; ALTER SYSTEM CHECKPOINT;` |
| File masih ada setelah drop | Metadata terhapus, file OS belum | Cek `ls`, hapus manual jika yakin |
| Bigfile gagal tambah datafile | Bigfile hanya satu datafile | Resize atau autoextend |
| Resize mengecil gagal | Ada extent di akhir file | Jangan dipaksa; cek space/segment |
| TEMP tidak dipakai | Belum default atau belum assigned user | Cek `database_properties` dan `dba_users` |
| Drop undo aktif gagal | Undo sedang aktif | Pindah `undo_tablespace` dulu |

---

## 15. Checklist Kompetensi Day 3

```text
[ ] Saya bisa menjelaskan datafile, tempfile, control file, redo log, archive log.
[ ] Saya bisa multiplex control file.
[ ] Saya bisa backup control file ke binary dan trace.
[ ] Saya bisa menambah, multiplex, switch, checkpoint, drop, dan resize redo log.
[ ] Saya paham ARCHIVELOG mode.
[ ] Saya bisa membuat permanent tablespace dan menambah datafile.
[ ] Saya bisa resize dan autoextend datafile dengan MAXSIZE.
[ ] Saya paham smallfile vs bigfile.
[ ] Saya bisa membuat dan mengelola temporary tablespace.
[ ] Saya bisa membuat dan mengganti undo tablespace.
[ ] Saya bisa monitoring tablespace, temp, undo, segment, dan memory dasar.
```

---

## 16. Mini Latihan Ujian Lisan

1. Mengapa control file sebaiknya multiplex?
2. Apa beda redo log group dan member?
3. Mengapa redo log tidak bisa resize langsung?
4. Apa fungsi `ALTER SYSTEM SWITCH LOGFILE`?
5. Apa beda datafile dan tempfile?
6. Apa beda permanent, temporary, dan undo tablespace?
7. Apa beda smallfile dan bigfile?
8. Mengapa autoextend harus diberi `MAXSIZE`?
9. Apa fungsi undo retention?
10. Apa hubungan segment, extent, dan block?

### Jawaban singkat

1. Agar database tetap bisa hidup/recover jika satu control file rusak.
2. Group dipakai bergantian oleh LGWR; member adalah file fisik salinan dalam group.
3. Oracle tidak mendukung resize redo langsung; harus buat group baru dan drop lama.
4. Memaksa perpindahan redo log group.
5. Datafile menyimpan object permanen; tempfile untuk operasi sementara.
6. Permanent untuk object, temporary untuk sort/hash, undo untuk rollback/read consistency.
7. Smallfile banyak datafile; bigfile satu datafile besar.
8. Agar file tidak tumbuh tanpa batas dan memenuhi disk.
9. Menentukan target durasi undo dipertahankan.
10. Segment tersusun dari extent; extent tersusun dari block.
