# Cheat Sheet Oracle Day 5 — Operational DBA, Backup & Recovery, Best Practices

**Topik silabus:** *Operational Database Management, Backup & Recovery, Recovery Scenario, Enterprise DBA Best Practices*  
**Fokus belajar:** aktivitas operasional harian, health check, index/execution plan review, user-managed backup, RMAN backup, restore, recovery datafile/tablespace/PDB/CDB, controlfile/SPFILE backup, RPO/RTO, dan best practices DBA enterprise.


> **Catatan penggunaan:** contoh output pada file ini bersifat realistis untuk lab Oracle 19c, tetapi nilai seperti hostname, path, ukuran file, `SID`, `SERVICE_NAME`, `CON_ID`, `SQL_ID`, dan status dapat berbeda sesuai environment. Jalankan command berurutan, baca output-nya, lalu cocokkan dengan bagian *cara membaca output*.

> **Asumsi lab umum:** CDB `ORADB`, PDB `PDB1`, OS Oracle Linux, user OS `oracle`, Oracle Database 19c, path umum `/u01/app/oracle/oradata/ORADB`.


---

## 1. Peta Belajar Day 5

| Modul | Materi | Target praktik |
|---|---|---|
| Operational Activities | Health check, alert log, listener, storage, backup | Menyusun rutinitas DBA harian |
| Backup & Recovery | Backup concept, RMAN, user-managed backup | Membuat backup yang dapat di-restore |
| Recovery Scenarios | Datafile loss, tablespace recovery, PDB recovery | Memulihkan object setelah failure |
| Best Practices | RPO/RTO, retention, validation, documentation | Menyiapkan SOP DBA enterprise |

---

## 2. Operational Health Check Harian

### 2.1 Cek status database

```sql
CONN / AS SYSDBA
SELECT instance_name, status, database_status, startup_time FROM v$instance;
SELECT name, cdb, open_mode, log_mode FROM v$database;
SHOW PDBS;
```

**Contoh output:**

```text
INSTANCE_NAME STATUS DATABASE_STATUS STARTUP_TIME
------------- ------ --------------- ------------
ORADB         OPEN   ACTIVE          11-JUL-26

NAME  CDB OPEN_MODE  LOG_MODE
----- --- ---------- ------------
ORADB YES READ WRITE ARCHIVELOG
```

### 2.2 Cek listener dan alert log

```bash
lsnrctl status
lsnrctl services
cd $ORACLE_BASE/diag/rdbms/oradb/ORADB/trace
tail -n 100 alert_ORADB.log
```

### 2.3 Cek tablespace/FRA/backup

```sql
SELECT tablespace_name, file_name, bytes/1024/1024 AS mb, autoextensible
FROM dba_data_files
ORDER BY tablespace_name;

SELECT name, space_limit/1024/1024 AS limit_mb,
       space_used/1024/1024 AS used_mb,
       space_reclaimable/1024/1024 AS reclaimable_mb
FROM v$recovery_file_dest;
```

```bash
rman target /
```

```rman
LIST BACKUP SUMMARY;
REPORT NEED BACKUP;
```

---

## 3. Review Performance: Index dan Execution Plan

Materi index muncul pada praktik Day 5 sebagai penguatan performance management.

### 3.1 Konsep index

```text
Index mempercepat SELECT yang selektif, tetapi dapat memperlambat INSERT/UPDATE/DELETE karena index harus ikut diperbarui.
Index tidak selalu dipakai optimizer.
```

### 3.2 Mengaktifkan autotrace

```sql
SET AUTOTRACE TRACEONLY EXPLAIN;
SELECT * FROM regions WHERE region_id=1;
SET AUTOTRACE OFF;
```

**Contoh plan memakai index:**

```text
Operation                     Name
----------------------------- ----------
TABLE ACCESS BY INDEX ROWID   REGIONS
INDEX UNIQUE SCAN             REG_ID_PK
```

### 3.3 Demo tanpa index vs dengan index

```sql
CREATE TABLE t1(x NUMBER, y NUMBER, z NUMBER);

BEGIN
  FOR i IN 1..10000 LOOP
    INSERT INTO t1 VALUES (i,i,i);
  END LOOP;
  COMMIT;
END;
/

CREATE TABLE t2 AS SELECT * FROM t1;
CREATE INDEX t2idx ON t2(x);

SET AUTOTRACE TRACEONLY EXPLAIN;
SELECT * FROM t1 WHERE x=1000;
SELECT * FROM t2 WHERE x=1000;
SET AUTOTRACE OFF;
```

**Perbandingan umum:**

| Query | Plan | Cost indikatif |
|---|---|---|
| `T1 WHERE x=1000` | Full table scan | Lebih tinggi |
| `T2 WHERE x=1000` | Index range scan | Lebih rendah |

### 3.4 Penyebab index tidak dipakai

| Penyebab | Contoh | Solusi |
|---|---|---|
| Data yang diambil terlalu banyak | `WHERE x < 9000` dari 10000 row | Full scan mungkin memang lebih murah |
| Statistik tidak akurat | `num_rows` lama | `DBMS_STATS.GATHER_TABLE_STATS` |
| Salah tipe data | `VARCHAR2` dibanding angka | Samakan literal: `x='1000'` |
| Composite index tidak memakai kolom depan | index `(x,y,z)`, query hanya `y,z` | Buat index sesuai predicate |
| Kolom dibungkus function | `LOWER(first_name)` | Function-based index atau ubah predicate |

### 3.5 Statistik tabel

```sql
SELECT table_name, num_rows, blocks, last_analyzed
FROM user_tables
WHERE table_name='T2';

BEGIN
  DBMS_STATS.GATHER_TABLE_STATS(
    ownname => USER,
    tabname => 'T2',
    cascade => TRUE
  );
END;
/
```

### 3.6 Function-based index

```sql
CREATE TABLE karyawan AS SELECT first_name, last_name FROM employees;
CREATE INDEX karyawanidx ON karyawan(first_name);

-- index biasa kurang cocok untuk query ini:
SELECT * FROM karyawan WHERE LOWER(first_name)='ellen';

DROP INDEX karyawanidx;
CREATE INDEX karyawanidx ON karyawan(LOWER(first_name));
SELECT * FROM karyawan WHERE LOWER(first_name)='ellen';
```

---

## 4. Konsep Backup, Restore, Recovery

| Istilah | Makna |
|---|---|
| Backup | Membuat salinan file/database |
| Restore | Mengembalikan file dari backup ke lokasi database |
| Recovery | Menerapkan redo/archive log agar data konsisten sampai titik tertentu |

```text
Backup  = membuat cadangan
Restore = mengembalikan file cadangan
Recover = menyinkronkan file hasil restore dengan redo/archive log
```

### 4.1 RPO dan RTO

| Istilah | Pertanyaan | Contoh |
|---|---|---|
| RPO | Berapa banyak data boleh hilang? | Maksimal hilang 15 menit |
| RTO | Berapa lama sistem boleh down? | Pulih maksimal 1 jam |

### 4.2 ARCHIVELOG mode

```sql
ARCHIVE LOG LIST;
```

**Contoh output:**

```text
Database log mode              Archive Mode
Automatic archival             Enabled
```

ARCHIVELOG penting agar recovery dapat menerapkan redo lama setelah restore.

---

## 5. Persiapan Data Lab Backup

```sql
ALTER SESSION SET CONTAINER=PDB1;

CREATE TABLESPACE TS_BKP_LAB
DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/ts_bkp_lab01.dbf'
SIZE 100M
AUTOEXTEND ON NEXT 50M MAXSIZE 1G;

CREATE USER bkpuser IDENTIFIED BY oracle
DEFAULT TABLESPACE TS_BKP_LAB
TEMPORARY TABLESPACE TEMP
QUOTA UNLIMITED ON TS_BKP_LAB;

GRANT CREATE SESSION, CREATE TABLE TO bkpuser;
```

Buat data:

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
SELECT COUNT(*) FROM transaksi_backup;
```

**Contoh output:**

```text
COUNT(*)
--------
1000
```

---

## 6. User-Managed Backup

### 6.1 Backup datafile online

Buat folder:

```bash
mkdir -p /home/oracle/backup/user_managed/datafile
```

Cek datafile:

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

SELECT file_name
FROM dba_data_files
WHERE tablespace_name='TS_BKP_LAB';
```

Masuk mode backup:

```sql
ALTER TABLESPACE TS_BKP_LAB BEGIN BACKUP;
```

Copy OS:

```bash
cp /u01/app/oracle/oradata/ORADB/pdb1/ts_bkp_lab01.dbf /home/oracle/backup/user_managed/datafile/ts_bkp_lab01.dbf.bak
```

Akhiri mode backup dan archive current redo:

```sql
ALTER TABLESPACE TS_BKP_LAB END BACKUP;
ALTER SYSTEM ARCHIVE LOG CURRENT;
```

Verifikasi:

```bash
ls -lh /home/oracle/backup/user_managed/datafile/ts_bkp_lab01.dbf.bak
```

### 6.2 Simulasi failure datafile

Tambahkan data setelah backup:

```sql
CONN bkpuser/oracle@localhost:1521/pdb1.localdomain

INSERT INTO transaksi_backup (id, keterangan)
SELECT LEVEL + 1000, 'DATA SETELAH BACKUP KE-' || LEVEL
FROM dual
CONNECT BY LEVEL <= 500;
COMMIT;
SELECT COUNT(*) FROM transaksi_backup;
```

**Hasil:** 1500 row.

Offline tablespace dan hilangkan file:

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;
ALTER TABLESPACE TS_BKP_LAB OFFLINE IMMEDIATE;
```

```bash
mv /u01/app/oracle/oradata/ORADB/pdb1/ts_bkp_lab01.dbf /u01/app/oracle/oradata/ORADB/pdb1/ts_bkp_lab01.dbf.failed
```

Akses tabel akan gagal:

```text
ORA-00376: file cannot be read at this time
ORA-01110: data file ... ts_bkp_lab01.dbf
```

### 6.3 Restore dan recover manual

```bash
cp /home/oracle/backup/user_managed/datafile/ts_bkp_lab01.dbf.bak /u01/app/oracle/oradata/ORADB/pdb1/ts_bkp_lab01.dbf
```

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;
RECOVER DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/ts_bkp_lab01.dbf';
ALTER TABLESPACE TS_BKP_LAB ONLINE;
```

Verifikasi:

```sql
CONN bkpuser/oracle@localhost:1521/pdb1.localdomain
SELECT COUNT(*) FROM transaksi_backup;
```

**Contoh output:**

```text
COUNT(*)
--------
1500
```

Makna: data setelah backup tetap kembali karena recovery menerapkan redo/archive log.

### 6.4 Full database cold backup manual

```sql
CONN / AS SYSDBA
SHUTDOWN IMMEDIATE;
```

```bash
mkdir -p /home/oracle/backup/user_managed/full_db
cp -Rp /u01/app/oracle/oradata/ORADB/* /home/oracle/backup/user_managed/full_db/
```

```sql
STARTUP;
ALTER PLUGGABLE DATABASE ALL OPEN;
```

---

## 7. RMAN Configuration dan Backup

### 7.1 Masuk RMAN dan cek konfigurasi

```bash
rman target /
```

```rman
SHOW ALL;
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE RETENTION POLICY TO REDUNDANCY 2;
CONFIGURE DEVICE TYPE DISK PARALLELISM 1;
```

### 7.2 Backup full CDB plus archivelog

```bash
mkdir -p /home/oracle/backup/rman/full_db
rman target /
```

```rman
BACKUP AS COMPRESSED BACKUPSET DATABASE
FORMAT '/home/oracle/backup/rman/full_db/db_full_%U.bkp'
PLUS ARCHIVELOG
FORMAT '/home/oracle/backup/rman/full_db/arch_%U.bkp';

LIST BACKUP SUMMARY;
```

### 7.3 Backup PDB

```bash
mkdir -p /home/oracle/backup/rman/pdb
rman target /
```

```rman
BACKUP PLUGGABLE DATABASE PDB1
FORMAT '/home/oracle/backup/rman/pdb/pdb1_%U.bkp';

LIST BACKUP OF PLUGGABLE DATABASE PDB1;
```

### 7.4 Backup tablespace PDB

```bash
mkdir -p /home/oracle/backup/rman/tablespace
rman target /
```

```rman
BACKUP TABLESPACE PDB1:TS_BKP_LAB
FORMAT '/home/oracle/backup/rman/tablespace/ts_bkp_lab_%U.bkp';

LIST BACKUP OF TABLESPACE PDB1:TS_BKP_LAB;
```

### 7.5 Backup datafile tertentu

Cari file number:

```sql
ALTER SESSION SET CONTAINER=PDB1;
SELECT file_id, file_name
FROM dba_data_files
WHERE tablespace_name='TS_BKP_LAB';
```

RMAN:

```rman
BACKUP DATAFILE 15 FORMAT '/home/oracle/backup/rman/datafile/df15_%U.bkp';
LIST BACKUP OF DATAFILE 15;
```

---

## 8. RMAN Recovery Scenario

### 8.1 Restore/recover datafile

```rman
RESTORE DATAFILE 15;
RECOVER DATAFILE 15;
```

Online-kan tablespace dari SQL\*Plus:

```sql
ALTER SESSION SET CONTAINER=PDB1;
ALTER TABLESPACE TS_BKP_LAB ONLINE;
```

### 8.2 Restore/recover tablespace

```rman
RESTORE TABLESPACE PDB1:TS_BKP_LAB;
RECOVER TABLESPACE PDB1:TS_BKP_LAB;
```

```sql
ALTER PLUGGABLE DATABASE PDB1 OPEN;
```

### 8.3 Restore/recover PDB

```rman
RUN {
  RESTORE PLUGGABLE DATABASE PDB1;
  RECOVER PLUGGABLE DATABASE PDB1;
  ALTER PLUGGABLE DATABASE PDB1 OPEN;
}
```

### 8.4 Restore/recover seluruh database

```rman
STARTUP MOUNT;
RESTORE DATABASE;
RECOVER DATABASE;
ALTER DATABASE OPEN;
ALTER PLUGGABLE DATABASE ALL OPEN;
```

Jika menggunakan backup controlfile lama, bisa membutuhkan:

```sql
ALTER DATABASE OPEN RESETLOGS;
```

Gunakan `RESETLOGS` hanya pada skenario yang memang mengharuskan.

---

## 9. Control File dan SPFILE Backup untuk Recovery

### 9.1 Backup control file manual

```sql
ALTER DATABASE BACKUP CONTROLFILE TO '/u01/app/oracle/oradata/ORADB/controlfile_backup_binary.bkp';
ALTER DATABASE BACKUP CONTROLFILE TO TRACE;
```

### 9.2 RMAN controlfile autobackup

```rman
CONFIGURE CONTROLFILE AUTOBACKUP ON;
BACKUP CURRENT CONTROLFILE;
LIST BACKUP OF CONTROLFILE;
```

### 9.3 Backup SPFILE

```rman
BACKUP SPFILE;
LIST BACKUP OF SPFILE;
```

### 9.4 Restore SPFILE dari autobackup

```rman
STARTUP NOMOUNT;
RESTORE SPFILE FROM AUTOBACKUP;
SHUTDOWN IMMEDIATE;
STARTUP;
```

---

## 10. Validasi, Crosscheck, Catalog, Delete Obsolete

```rman
LIST BACKUP;
LIST BACKUP SUMMARY;
CROSSCHECK BACKUP;
DELETE EXPIRED BACKUP;
REPORT OBSOLETE;
DELETE OBSOLETE;
VALIDATE DATABASE;
RESTORE DATABASE VALIDATE;
CATALOG START WITH '/home/oracle/backup/rman/';
```

| Command | Fungsi |
|---|---|
| `CROSSCHECK` | Cocokkan catalog RMAN dengan file di storage |
| `DELETE EXPIRED` | Hapus metadata backup yang file fisiknya hilang |
| `REPORT OBSOLETE` | Lihat backup yang tidak dibutuhkan menurut retention |
| `DELETE OBSOLETE` | Hapus backup obsolete |
| `VALIDATE` | Cek apakah backup/database bisa dibaca |
| `CATALOG START WITH` | Daftarkan backup piece yang belum dikenal RMAN |

---

## 11. Troubleshooting Recovery

| Error/Gejala | Makna | Langkah |
|---|---|---|
| `ORA-01157` / `ORA-01110` | Datafile tidak ditemukan/tidak bisa dibuka | Restore file, recover, online/open |
| `RMAN tidak menemukan backup` | Backup hilang/tidak tercatat | `LIST BACKUP`, `CROSSCHECK`, `CATALOG START WITH` |
| Tablespace masih backup mode | Lupa `END BACKUP` | `SELECT * FROM v$backup`, `ALTER TABLESPACE ... END BACKUP` |
| FRA penuh | Archive/backup memenuhi FRA | Backup archivelog, delete obsolete/expired |
| PDB tetap mounted | Datafile PDB bermasalah | `RESTORE/RECOVER PLUGGABLE DATABASE` |
| Recovery minta archive log | Archive log diperlukan tidak tersedia | Cari backup archivelog atau recovery hanya sampai titik tersedia |

---

## 12. Best Practices DBA Enterprise

### 12.1 Backup

```text
[ ] Gunakan RMAN sebagai standar production.
[ ] Aktifkan ARCHIVELOG untuk database penting.
[ ] Aktifkan CONTROLFILE AUTOBACKUP.
[ ] Backup mencakup database, archivelog, controlfile, dan SPFILE.
[ ] Simpan backup di storage berbeda, bukan hanya di server database.
[ ] Uji restore secara berkala.
[ ] Dokumentasikan RPO/RTO dan prosedur recovery.
[ ] Jalankan crosscheck dan delete obsolete sesuai retention.
```

### 12.2 Performance/index

```text
[ ] Buat index berdasarkan query nyata.
[ ] Hindari index terlalu banyak pada tabel yang sering DML.
[ ] Samakan tipe data predicate dengan kolom.
[ ] Perhatikan leading column composite index.
[ ] Gunakan function-based index hanya jika query memang memakai function.
[ ] Gather stats setelah perubahan data besar.
[ ] Cek execution plan, bukan menebak.
```

### 12.3 Operasional harian

```text
[ ] Cek status database/PDB.
[ ] Cek listener dan service.
[ ] Cek alert log.
[ ] Cek tablespace/TEMP/UNDO/FRA.
[ ] Cek session blocking dan top SQL.
[ ] Cek backup terakhir.
[ ] Cek job penting.
[ ] Catat perubahan konfigurasi.
```

---

## 13. Alur Praktik Day 5

### Alur 1 — Index

```sql
ALTER SESSION SET CONTAINER=PDB1;
CONN hr/hr@PDB1
SET AUTOTRACE TRACEONLY EXPLAIN;
SELECT * FROM regions WHERE region_id=1;
SET AUTOTRACE OFF;
CREATE TABLE t1(x NUMBER, y NUMBER, z NUMBER);
BEGIN
  FOR i IN 1..10000 LOOP
    INSERT INTO t1 VALUES (i,i,i);
  END LOOP;
  COMMIT;
END;
/
CREATE TABLE t2 AS SELECT * FROM t1;
CREATE INDEX t2idx ON t2(x);
SET AUTOTRACE TRACEONLY EXPLAIN;
SELECT * FROM t1 WHERE x=1000;
SELECT * FROM t2 WHERE x=1000;
SET AUTOTRACE OFF;
```

### Alur 2 — User-managed backup

```sql
ARCHIVE LOG LIST;
ALTER SESSION SET CONTAINER=PDB1;
CREATE TABLESPACE TS_BKP_LAB DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/ts_bkp_lab01.dbf' SIZE 100M AUTOEXTEND ON NEXT 50M MAXSIZE 1G;
CREATE USER bkpuser IDENTIFIED BY oracle DEFAULT TABLESPACE TS_BKP_LAB QUOTA UNLIMITED ON TS_BKP_LAB;
GRANT CREATE SESSION, CREATE TABLE TO bkpuser;
ALTER TABLESPACE TS_BKP_LAB BEGIN BACKUP;
```

```bash
mkdir -p /home/oracle/backup/user_managed/datafile
cp /u01/app/oracle/oradata/ORADB/pdb1/ts_bkp_lab01.dbf /home/oracle/backup/user_managed/datafile/ts_bkp_lab01.dbf.bak
```

```sql
ALTER TABLESPACE TS_BKP_LAB END BACKUP;
ALTER SYSTEM ARCHIVE LOG CURRENT;
```

### Alur 3 — RMAN backup/recovery PDB

```bash
mkdir -p /home/oracle/backup/rman/pdb
rman target /
```

```rman
CONFIGURE CONTROLFILE AUTOBACKUP ON;
BACKUP PLUGGABLE DATABASE PDB1 FORMAT '/home/oracle/backup/rman/pdb/pdb1_%U.bkp';
LIST BACKUP OF PLUGGABLE DATABASE PDB1;
RUN {
  RESTORE PLUGGABLE DATABASE PDB1;
  RECOVER PLUGGABLE DATABASE PDB1;
  ALTER PLUGGABLE DATABASE PDB1 OPEN;
}
```

---

## 14. Checklist Kompetensi Day 5

```text
[ ] Saya bisa melakukan health check harian database.
[ ] Saya bisa membaca execution plan dasar dan mengenali index dipakai/tidak.
[ ] Saya paham penyebab index tidak dipakai.
[ ] Saya bisa membedakan backup, restore, dan recovery.
[ ] Saya paham RPO dan RTO.
[ ] Saya bisa melakukan user-managed backup datafile/tablespace.
[ ] Saya bisa restore dan recover datafile manual.
[ ] Saya bisa konfigurasi RMAN dasar.
[ ] Saya bisa backup CDB, PDB, tablespace, datafile dengan RMAN.
[ ] Saya bisa restore/recover datafile, tablespace, dan PDB dengan RMAN.
[ ] Saya bisa backup controlfile dan SPFILE.
[ ] Saya bisa menjalankan crosscheck, validate, report/delete obsolete.
[ ] Saya memahami best practice backup production.
```

---

## 15. Mini Latihan Ujian Lisan

1. Apa beda backup, restore, dan recovery?
2. Mengapa ARCHIVELOG penting?
3. Apa itu RPO dan RTO?
4. Apa risiko user-managed backup?
5. Mengapa RMAN lebih direkomendasikan?
6. Apa fungsi `BEGIN BACKUP` dan `END BACKUP`?
7. Apa fungsi `ALTER SYSTEM ARCHIVE LOG CURRENT` setelah backup manual?
8. Apa beda restore PDB dan restore tablespace?
9. Apa fungsi controlfile autobackup?
10. Mengapa backup harus diuji restore?
11. Mengapa index bisa memperlambat DML?
12. Apa prinsip composite index?

### Jawaban singkat

1. Backup membuat salinan; restore mengembalikan file; recovery menerapkan redo/archive log agar konsisten.
2. Agar redo lama tersedia untuk media recovery.
3. RPO batas kehilangan data; RTO batas waktu pemulihan layanan.
4. Human error: salah copy, lupa end backup, tidak tercatat otomatis.
5. RMAN terintegrasi dengan Oracle, mendukung incremental, catalog, validasi, dan recovery otomatis.
6. Membuat datafile aman disalin saat database online dan mengakhiri mode tersebut.
7. Memastikan redo yang diperlukan untuk recovery segera terarsipkan.
8. Restore PDB memulihkan seluruh datafile PDB; restore tablespace hanya tablespace tertentu.
9. Menjamin controlfile/SPFILE tersedia untuk recovery meskipun controlfile hilang.
10. Backup yang tidak pernah diuji belum tentu bisa dipakai saat insiden.
11. Karena setiap DML juga harus memperbarui index.
12. Leading column sangat penting; index `(x,y,z)` efektif jika predicate dimulai dari `x`.
