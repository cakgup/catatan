# Cheat Sheet Oracle Day 4 — Security, Auditing, Monitoring, Performance

**Topik silabus:** *Database Security, Monitoring, and Performance Management*  
**Fokus belajar:** security fundamentals, least privilege, user/account control, audit, compliance, monitoring session/transaction/storage/temp/undo/redo/archive/FRA/listener/backup, wait event, top SQL, execution plan, AWR/ADDM, serta praktik operasional PDB yang mendukung administrasi harian.


> **Catatan penggunaan:** contoh output pada file ini bersifat realistis untuk lab Oracle 19c, tetapi nilai seperti hostname, path, ukuran file, `SID`, `SERVICE_NAME`, `CON_ID`, `SQL_ID`, dan status dapat berbeda sesuai environment. Jalankan command berurutan, baca output-nya, lalu cocokkan dengan bagian *cara membaca output*.

> **Asumsi lab umum:** CDB `ORADB`, PDB `PDB1`, OS Oracle Linux, user OS `oracle`, Oracle Database 19c, path umum `/u01/app/oracle/oradata/ORADB`.


---

## 1. Peta Belajar Day 4

| Modul | Materi | Target praktik |
|---|---|---|
| Security Fundamentals | Least privilege, secure account, quota/profile | Membuat user aman dan membatasi akses |
| Auditing & Compliance | Unified audit, audit policy, audit trail | Mencatat aktivitas penting |
| Database Monitoring | Session, blocking, transaction, storage, alert log | Membuat health check operasional |
| Performance Fundamentals | Wait event, SQL monitoring, execution plan, AWR/ADDM | Mencari indikasi bottleneck dasar |

---

## 2. Security Fundamentals

### 2.1 Prinsip least privilege

```text
Berikan hanya privilege yang diperlukan.
Hindari memberikan DBA/RESOURCE/CONNECT secara luas di production.
Gunakan role untuk paket akses.
Pisahkan user owner schema, user read-only, user aplikasi, dan user administrasi.
Gunakan quota dan profile.
```

### 2.2 Cek user dan account status

```sql
ALTER SESSION SET CONTAINER=PDB1;

SELECT username, account_status, default_tablespace, temporary_tablespace, profile
FROM dba_users
ORDER BY username;
```

**Contoh output:**

```text
USERNAME   ACCOUNT_STATUS  DEFAULT_TABLESPACE TEMPORARY_TABLESPACE PROFILE
---------- --------------- ------------------ -------------------- ----------
APP_OWNER  OPEN            TS_USER_LAB        TEMP                 DEFAULT
APP_READ   OPEN            TS_USER_LAB        TEMP                 DEFAULT
```

### 2.3 Lock/unlock user

```sql
ALTER USER app_read ACCOUNT LOCK;
ALTER USER app_read ACCOUNT UNLOCK;
ALTER USER app_read IDENTIFIED BY oracle;
```

### 2.4 Quota user

```sql
ALTER USER app_owner QUOTA 100M ON TS_USER_LAB;

SELECT username, tablespace_name,
       bytes/1024/1024 AS used_mb,
       max_bytes/1024/1024 AS max_mb
FROM dba_ts_quotas
WHERE username='APP_OWNER';
```

### 2.5 Profile password dan resource

```sql
ALTER SYSTEM SET resource_limit=TRUE SCOPE=BOTH;

CREATE PROFILE profile_secure_app LIMIT
  SESSIONS_PER_USER 3
  IDLE_TIME 15
  CONNECT_TIME 240
  FAILED_LOGIN_ATTEMPTS 3
  PASSWORD_LOCK_TIME 1
  PASSWORD_LIFE_TIME 90;

ALTER USER app_owner PROFILE profile_secure_app;
```

**Contoh error saat limit session terlampaui:**

```text
ORA-02391: exceeded simultaneous SESSIONS_PER_USER limit
```

---

## 3. Temporary Tablespace dan User Assignment

Topik ini muncul pada praktik kelas Day 4 dan relevan untuk security/resource management karena berhubungan dengan isolasi resource user.

### 3.1 Cek temporary tablespace

```sql
SELECT tablespace_name, file_name, bytes/1024/1024 AS size_mb, autoextensible
FROM dba_temp_files;
```

### 3.2 Buat temporary tablespace

```sql
CREATE TEMPORARY TABLESPACE temp_baru
TEMPFILE '/u01/app/oracle/oradata/ORADB/pdb1/temp_baru01.dbf'
SIZE 10M AUTOEXTEND ON NEXT 10M MAXSIZE 1G;
```

### 3.3 Assign user ke default/temp tablespace

```sql
CREATE USER candra IDENTIFIED BY candra
DEFAULT TABLESPACE ts_gede
QUOTA 20M ON ts_gede
TEMPORARY TABLESPACE temp_baru;

SELECT username, default_tablespace, temporary_tablespace
FROM dba_users
WHERE username='CANDRA';
```

### 3.4 Ubah default temporary tablespace PDB

```sql
SELECT property_value
FROM database_properties
WHERE property_name='DEFAULT_TEMP_TABLESPACE';

ALTER DATABASE DEFAULT TEMPORARY TABLESPACE TEMP_BARU;
ALTER DATABASE DEFAULT TEMPORARY TABLESPACE TEMP;
```

---

## 4. Unified Auditing dan Compliance

### 4.1 Cek Unified Auditing

```sql
SELECT value
FROM v$option
WHERE parameter='Unified Auditing';
```

**Contoh output:**

```text
VALUE
-----
TRUE
```

### 4.2 Lihat audit policy aktif

```sql
SELECT policy_name, enabled_option, entity_name
FROM audit_unified_enabled_policies;
```

### 4.3 Buat audit policy sederhana

```sql
CREATE AUDIT POLICY audit_user_management
ACTIONS CREATE USER, ALTER USER, DROP USER;

AUDIT POLICY audit_user_management;
```

### 4.4 Audit login gagal

```sql
AUDIT CREATE SESSION WHENEVER NOT SUCCESSFUL;
```

### 4.5 Lihat audit trail

```sql
SELECT event_timestamp,
       dbusername,
       action_name,
       return_code,
       unified_audit_policies
FROM unified_audit_trail
ORDER BY event_timestamp DESC
FETCH FIRST 20 ROWS ONLY;
```

**Contoh output:**

```text
EVENT_TIMESTAMP          DBUSERNAME ACTION_NAME RETURN_CODE UNIFIED_AUDIT_POLICIES
------------------------ ---------- ----------- ----------- ----------------------
11-JUL-26 10.30.12      APP_READ   LOGON       1017        ORA_LOGON_FAILURES
11-JUL-26 10.28.45      SYS        CREATE USER 0           AUDIT_USER_MANAGEMENT
```

| Return code | Arti |
|---|---|
| `0` | Berhasil |
| `1017` | Password/user salah |

---

## 5. Monitoring Status CDB dan PDB

```sql
CONN / AS SYSDBA
SET LINESIZE 200
COL name FORMAT A25
COL open_mode FORMAT A15

SELECT con_id, name, open_mode, restricted
FROM v$pdbs
ORDER BY con_id;
```

**Contoh output:**

```text
CON_ID NAME      OPEN_MODE  RES
------ --------- ---------- ---
2      PDB$SEED  READ ONLY  NO
3      PDB1      READ WRITE NO
```

---

## 6. Monitoring Session, Wait Event, Blocking, Transaction

### 6.1 Session aktif

```sql
ALTER SESSION SET CONTAINER=PDB1;

SELECT sid, serial#, username, status, machine, program
FROM v$session
WHERE username IS NOT NULL
ORDER BY username, sid;
```

### 6.2 Ringkasan status session

```sql
SELECT status, COUNT(*) AS jumlah_session
FROM v$session
WHERE username IS NOT NULL
GROUP BY status
ORDER BY status;
```

### 6.3 Wait event session

```sql
SELECT sid, serial#, username, status, event, wait_class, seconds_in_wait
FROM v$session
WHERE username IS NOT NULL
ORDER BY seconds_in_wait DESC;
```

**Cara membaca wait class:**

| Wait class | Makna umum |
|---|---|
| `Idle` | Biasanya menunggu client, tidak selalu masalah |
| `User I/O` | Menunggu baca/tulis storage |
| `Concurrency` | Potensi lock/latch/contention |
| `Commit` | Menunggu redo write saat commit |

### 6.4 Blocking session

```sql
SELECT sid, serial#, username, blocking_session, event, seconds_in_wait
FROM v$session
WHERE username IS NOT NULL
AND (blocking_session IS NOT NULL OR event LIKE 'enq: TX%');
```

**Contoh output:**

```text
SID SERIAL# USERNAME BLOCKING_SESSION EVENT                         SECONDS_IN_WAIT
--- ------- -------- ---------------- ----------------------------- ---------------
91  44210   MONUSER  85               enq: TX - row lock contention 30
```

### 6.5 Transaction aktif

```sql
SELECT s.sid, s.serial#, s.username,
       t.start_time, t.used_ublk, t.used_urec
FROM v$transaction t
JOIN v$session s ON t.ses_addr = s.saddr;
```

**Fungsi:** melihat transaksi yang belum commit/rollback dan pemakaian undo-nya.

---

## 7. Monitoring SQL dan Execution Plan

### 7.1 SQL yang sedang aktif

```sql
SELECT s.sid, s.serial#, s.username, s.status,
       s.sql_id, SUBSTR(q.sql_text,1,80) AS sql_text
FROM v$session s
JOIN v$sql q ON s.sql_id=q.sql_id
WHERE s.username IS NOT NULL
AND s.status='ACTIVE';
```

### 7.2 Top SQL berdasarkan elapsed time

```sql
SELECT sql_id, executions, buffer_gets, disk_reads, rows_processed,
       ROUND(elapsed_time/1000000,2) AS elapsed_sec,
       SUBSTR(sql_text,1,80) AS sql_text
FROM v$sql
WHERE parsing_schema_name IS NOT NULL
ORDER BY elapsed_time DESC
FETCH FIRST 10 ROWS ONLY;
```

### 7.3 Top SQL berdasarkan buffer gets

```sql
SELECT sql_id, executions, buffer_gets,
       ROUND(buffer_gets / NULLIF(executions,0),2) AS buffer_gets_per_exec,
       SUBSTR(sql_text,1,80) AS sql_text
FROM v$sql
WHERE parsing_schema_name IS NOT NULL
ORDER BY buffer_gets DESC
FETCH FIRST 10 ROWS ONLY;
```

### 7.4 Execution plan dari cursor

```sql
SELECT *
FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR('isi_sql_id', NULL, 'ALLSTATS LAST'));
```

**Contoh indikasi masalah:**

```text
TABLE ACCESS FULL dengan Buffers sangat tinggi
HASH JOIN besar menggunakan TEMP
INDEX tidak digunakan padahal filter selektif
```

---

## 8. Monitoring Storage, TEMP, UNDO, Redo, Archive, FRA

### 8.1 Tablespace usage

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
) fs ON df.tablespace_name=fs.tablespace_name
ORDER BY used_pct DESC;
```

### 8.2 Datafile dan autoextend

```sql
SELECT tablespace_name, file_name,
       bytes/1024/1024 AS size_mb,
       autoextensible,
       maxbytes/1024/1024 AS max_mb
FROM dba_data_files
ORDER BY tablespace_name, file_name;
```

### 8.3 TEMP usage

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
JOIN v$session s ON u.session_addr=s.saddr
ORDER BY used_mb DESC;
```

### 8.4 UNDO usage

```sql
SELECT TO_CHAR(begin_time,'YYYY-MM-DD HH24:MI:SS') AS begin_time,
       undoblks, txncount, maxquerylen
FROM v$undostat
ORDER BY begin_time DESC
FETCH FIRST 10 ROWS ONLY;
```

### 8.5 Redo log

```sql
SELECT group#, sequence#, bytes/1024/1024 AS size_mb, members, archived, status
FROM v$log
ORDER BY group#;
```

### 8.6 Archive log

```sql
ARCHIVE LOG LIST;

SELECT name, sequence#, first_time, next_time, applied, deleted
FROM v$archived_log
ORDER BY sequence# DESC
FETCH FIRST 20 ROWS ONLY;
```

### 8.7 FRA usage

```sql
SELECT name,
       space_limit/1024/1024 AS limit_mb,
       space_used/1024/1024 AS used_mb,
       space_reclaimable/1024/1024 AS reclaimable_mb,
       number_of_files
FROM v$recovery_file_dest;
```

---

## 9. Monitoring Alert Log dan Listener

### 9.1 Alert log dari OS

```bash
cd $ORACLE_BASE/diag/rdbms/oradb/ORADB/trace
tail -f alert_ORADB.log
```

### 9.2 Lokasi alert log dari SQL

```sql
SELECT name, value
FROM v$diag_info
WHERE name IN ('Diag Trace','Default Trace File');
```

### 9.3 Listener

```bash
lsnrctl status
lsnrctl services
tail -f $ORACLE_BASE/diag/tnslsnr/$(hostname)/listener/trace/listener.log
```

---

## 10. AWR dan ADDM Dasar

### 10.1 Snapshot AWR

```sql
SELECT snap_id, begin_interval_time, end_interval_time
FROM dba_hist_snapshot
ORDER BY snap_id DESC
FETCH FIRST 10 ROWS ONLY;
```

### 10.2 Generate AWR report

```sql
@$ORACLE_HOME/rdbms/admin/awrrpt.sql
```

**Alur:** pilih format HTML/text, jumlah hari snapshot, begin snap, end snap, nama file.

### 10.3 Generate ADDM report

```sql
@$ORACLE_HOME/rdbms/admin/addmrpt.sql
```

**Yang dicari:** top finding, impact percentage, recommendation, SQL ID, wait event dominan.

---

## 11. PDB Management Practice

Bagian ini memperkuat praktik administrasi multitenant yang muncul pada Day 4.

### 11.1 Create PDB dari seed

```bash
mkdir -p /u01/app/oracle/oradata/ORADB/PDBLAB1
```

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=CDB$ROOT;

CREATE PLUGGABLE DATABASE PDBLAB1
ADMIN USER pdbadmin IDENTIFIED BY oracle
FILE_NAME_CONVERT = (
'/u01/app/oracle/oradata/ORADB/pdbseed/',
'/u01/app/oracle/oradata/ORADB/PDBLAB1/'
);

ALTER PLUGGABLE DATABASE PDBLAB1 OPEN;
ALTER PLUGGABLE DATABASE PDBLAB1 SAVE STATE;
SHOW PDBS;
```

### 11.2 Clone PDB

```bash
mkdir -p /u01/app/oracle/oradata/ORADB/PDBLAB2
```

```sql
CREATE PLUGGABLE DATABASE PDBLAB2
FROM PDBLAB1
FILE_NAME_CONVERT = (
'/u01/app/oracle/oradata/ORADB/PDBLAB1/',
'/u01/app/oracle/oradata/ORADB/PDBLAB2/'
);

ALTER PLUGGABLE DATABASE PDBLAB2 OPEN;
```

### 11.3 Rename PDB

```sql
ALTER SESSION SET CONTAINER=CDB$ROOT;
ALTER PLUGGABLE DATABASE PDBLAB2 CLOSE IMMEDIATE;
ALTER PLUGGABLE DATABASE PDBLAB2 OPEN RESTRICTED;
ALTER SESSION SET CONTAINER=PDBLAB2;
ALTER PLUGGABLE DATABASE PDBLAB2 RENAME GLOBAL_NAME TO PDBLAB2_RENAME;
ALTER SESSION SET CONTAINER=CDB$ROOT;
ALTER PLUGGABLE DATABASE PDBLAB2_RENAME CLOSE IMMEDIATE;
ALTER PLUGGABLE DATABASE PDBLAB2_RENAME OPEN;
```

### 11.4 Unplug/plug PDB

```sql
ALTER SESSION SET CONTAINER=CDB$ROOT;
ALTER PLUGGABLE DATABASE PDBLAB1 CLOSE IMMEDIATE;
ALTER PLUGGABLE DATABASE PDBLAB1 UNPLUG INTO '/home/oracle/pdblab1.xml';
DROP PLUGGABLE DATABASE PDBLAB1 KEEP DATAFILES;

CREATE PLUGGABLE DATABASE PDBLAB1
USING '/home/oracle/pdblab1.xml'
NOCOPY;

ALTER PLUGGABLE DATABASE PDBLAB1 OPEN;
```

| Opsi | Makna |
|---|---|
| `COPY` | Salin datafile ke lokasi baru |
| `NOCOPY` | Pakai datafile existing |
| `KEEP DATAFILES` | Drop metadata PDB, file fisik tetap |
| `INCLUDING DATAFILES` | Drop metadata dan file fisik |

---

## 12. Health Check Harian DBA

```sql
-- status instance/database/PDB
SELECT instance_name, status, database_status, startup_time FROM v$instance;
SELECT name, open_mode, log_mode FROM v$database;
SHOW PDBS;

-- session/wait/blocking
SELECT sid, serial#, username, status, event, wait_class FROM v$session WHERE username IS NOT NULL;
SELECT sid, serial#, username, blocking_session, event FROM v$session WHERE blocking_session IS NOT NULL;

-- storage
SELECT tablespace_name, file_name, bytes/1024/1024 AS mb, autoextensible FROM dba_data_files;

-- backup
-- jalankan di RMAN: LIST BACKUP SUMMARY;
```

```bash
lsnrctl status
tail -n 100 $ORACLE_BASE/diag/rdbms/oradb/ORADB/trace/alert_ORADB.log
```

---

## 13. Troubleshooting Day 4

| Gejala | Kemungkinan | Solusi |
|---|---|---|
| User tidak bisa login | Locked / expired / kurang privilege | Cek `dba_users`, unlock, grant `CREATE SESSION` |
| User tidak bisa create table | Tidak punya quota / privilege | Grant `CREATE TABLE`, set quota |
| Profile tidak terasa | `resource_limit=FALSE` | `ALTER SYSTEM SET resource_limit=TRUE` |
| Session saling tunggu | Blocking row lock | Cek `blocking_session`, koordinasikan commit/rollback/kill |
| TEMP penuh | Sort/hash besar | Monitor `v$tempseg_usage`, tambah tempfile, tuning query |
| FRA penuh | Archive/backup menumpuk | Cek `v$recovery_file_dest`, backup/delete obsolete via RMAN |
| PDB tidak auto open | Belum save state | `ALTER PLUGGABLE DATABASE ... SAVE STATE` |

---

## 14. Checklist Kompetensi Day 4

```text
[ ] Saya bisa menerapkan prinsip least privilege.
[ ] Saya bisa lock/unlock user dan mengatur profile.
[ ] Saya bisa membuat audit policy dan membaca unified_audit_trail.
[ ] Saya bisa monitoring session, wait event, blocking, dan transaction.
[ ] Saya bisa monitoring top SQL dan execution plan.
[ ] Saya bisa monitoring tablespace, datafile, temp, undo, redo, archive, FRA.
[ ] Saya bisa membaca alert log dan listener service.
[ ] Saya bisa menjalankan AWR/ADDM report dasar.
[ ] Saya bisa membuat, clone, rename, unplug/plug, dan drop PDB.
[ ] Saya bisa menyusun query health check harian.
```

---

## 15. Mini Latihan Ujian Lisan

1. Apa itu least privilege?
2. Apa fungsi profile?
3. Apa fungsi audit trail?
4. Apa beda `v$session` dan `v$transaction`?
5. Apa arti wait event `enq: TX - row lock contention`?
6. Apa beda `Idle` wait dan `User I/O` wait?
7. Apa fungsi AWR dan ADDM?
8. Bagaimana mengecek SQL yang sedang aktif?
9. Apa risiko FRA penuh?
10. Apa beda clone PDB dan unplug/plug PDB?

### Jawaban singkat

1. Memberikan hak akses minimum sesuai kebutuhan.
2. Membatasi password policy dan resource user.
3. Mencatat aktivitas database untuk keamanan/compliance/forensic.
4. `v$session` berisi session; `v$transaction` berisi transaksi aktif.
5. Session menunggu row lock karena transaksi lain belum commit/rollback.
6. Idle biasanya menunggu client; User I/O menunggu storage.
7. AWR memberi laporan performa; ADDM memberi analisis dan rekomendasi.
8. Join `v$session` ke `v$sql` berdasarkan `sql_id`.
9. Archive/backup gagal, recovery terhambat, database bisa terganggu.
10. Clone membuat salinan PDB; unplug/plug melepas dan mendaftarkan kembali PDB.
