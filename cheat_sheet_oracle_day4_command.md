# Ringkasan / Cheat Sheet Oracle Database - Hari ke-4

> **Pelatihan:** Pengelolaan Basis Data Enterprise - Oracle Database 19c  
> **Tanggal catatan:** 9 Juli 2026  
> **Fokus sesuai silabus Hari 4:** Database Security, Auditing, Monitoring, dan Performance Management  
> **Tambahan praktik dari kelas:** Temporary tablespace, user quota, profile/resource limit, monitoring alert log, dan manajemen PDB.

---

## 0. Peta Materi Hari ke-4

Menurut silabus, Hari ke-4 berfokus pada empat area besar:

```text
1. Oracle Database Security Fundamentals
2. Auditing and Compliance
3. Database Monitoring
4. Performance Management Fundamentals
```

Namun pada praktik kelas, materi juga menyentuh beberapa topik administrasi lanjutan:

```text
1. Temporary tablespace
2. User default tablespace, temporary tablespace, dan quota
3. Profile dan resource limit
4. Alert log monitoring
5. PDB management: create, open, save state, clone, rename, move datafile, unplug/plug, OMF, dan drop PDB
```

Cara memahami Hari ke-4:

```text
Security        -> user, quota, privilege, profile, password policy
Audit           -> mencatat aktivitas user dan kebijakan audit
Monitoring      -> melihat status database, session, storage, alert log, dan PDB
Performance     -> membaca session, wait event, resource usage, AWR/ADDM dasar
PDB Operations  -> operasi lanjutan multitenant untuk kebutuhan administrasi
```

---

## 1. Persiapan SQL*Plus

### 1.1 Login sebagai SYSDBA

```bash
sqlplus / as sysdba
```

**Fungsi:**  
Masuk sebagai administrator database menggunakan OS authentication.

**Contoh output:**

```text
SQL*Plus: Release 19.0.0.0.0 - Production
Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
SQL>
```

---

### 1.2 Cek user dan container aktif

```sql
SHOW USER
SHOW CON_NAME
```

**Fungsi:**  
Memastikan sedang login sebagai user apa dan sedang berada di container mana.

**Contoh output:**

```text
USER is "SYS"

CON_NAME
------------------------------
CDB$ROOT
```

**Catatan penting:**  
Jika command berkaitan dengan PDB, pastikan sudah pindah ke PDB yang benar.

---

### 1.3 Pindah ke PDB1

```sql
ALTER SESSION SET CONTAINER = PDB1;
SHOW CON_NAME;
```

**Fungsi:**  
Mengubah konteks session dari CDB root ke `PDB1`.

**Contoh output:**

```text
Session altered.

CON_NAME
------------------------------
PDB1
```

---

### 1.4 Merapikan tampilan output SQL*Plus

```sql
SET LINESIZE 200
SET PAGESIZE 100
COL USERNAME FORMAT A15
COL TABLESPACE_NAME FORMAT A20
COL FILE_NAME FORMAT A100
```

**Fungsi:**  
Agar hasil query tidak terpotong dan lebih mudah dibaca.

---

### 1.5 Mengatur editor SQL*Plus

```sql
DEFINE _EDITOR='gedit'
ED
```

**Fungsi:**  
Mengatur editor default SQL*Plus menjadi `gedit`, lalu membuka buffer SQL terakhir untuk diedit.

**Contoh penggunaan:**

```sql
SQL> SELECT * FROM dba_users
  2  WHERE username='AMIR';
SQL> ED
```

---

# Bagian A - Security dan Resource Management

---

## 2. Temporary Tablespace

### 2.1 Konsep temporary tablespace

Temporary tablespace digunakan untuk operasi sementara, misalnya:

- `ORDER BY`
- `GROUP BY`
- sort besar
- hash join besar
- operasi index tertentu
- temporary segment saat query membutuhkan ruang kerja

Catatan penting:

```text
PDB tidak wajib memiliki temporary tablespace sendiri.
Namun untuk database transaksi dengan user banyak, lebih baik PDB memiliki temporary tablespace sendiri.
```

Temporary tablespace **tidak otomatis dipakai** hanya karena sudah dibuat. Ia dipakai jika:

```text
1. dijadikan default temporary tablespace database/PDB; atau
2. di-assign secara eksplisit ke user.
```

---

## 3. Mengecek Temporary Tablespace

```sql
ALTER SESSION SET CONTAINER = PDB1;
SELECT tablespace_name, file_name FROM dba_temp_files;
```

**Fungsi:**  
Melihat temporary tablespace dan tempfile yang ada di PDB aktif.

**Contoh output:**

```text
TABLESPACE_NAME      FILE_NAME
-------------------- ------------------------------------------------------------
TEMP                 /u01/app/oracle/oradata/ORADB/pdb1/temp012025-07-09.dbf
```

**Cara membaca:**

| Kolom | Arti |
|---|---|
| `TABLESPACE_NAME` | Nama temporary tablespace. |
| `FILE_NAME` | Lokasi fisik tempfile. |

---

## 4. Membuat Temporary Tablespace Baru

```sql
CREATE TEMPORARY TABLESPACE temp_baru
TEMPFILE
'/u01/app/oracle/oradata/ORADB/pdb1/temp_baru01.dbf'
SIZE 10M AUTOEXTEND ON NEXT 10M MAXSIZE 1G;
```

**Fungsi:**  
Membuat temporary tablespace bernama `TEMP_BARU` dengan satu tempfile.

**Makna parameter:**

| Bagian | Fungsi |
|---|---|
| `CREATE TEMPORARY TABLESPACE temp_baru` | Membuat temporary tablespace. |
| `TEMPFILE` | Menentukan file fisik untuk temporary tablespace. |
| `SIZE 10M` | Ukuran awal tempfile. |
| `AUTOEXTEND ON` | Tempfile boleh bertambah otomatis. |
| `NEXT 10M` | Penambahan tiap kali extend sebesar 10 MB. |
| `MAXSIZE 1G` | Batas maksimum tempfile 1 GB. |

**Contoh output:**

```text
Tablespace created.
```

---

## 5. Mengecek Temporary Tablespace Setelah Dibuat

```sql
SELECT tablespace_name, file_name
FROM dba_temp_files
ORDER BY tablespace_name, file_name;
```

**Fungsi:**  
Memastikan `TEMP_BARU` sudah muncul.

**Contoh output:**

```text
TABLESPACE_NAME      FILE_NAME
-------------------- ------------------------------------------------------------
TEMP                 /u01/app/oracle/oradata/ORADB/pdb1/temp01.dbf
TEMP_BARU            /u01/app/oracle/oradata/ORADB/pdb1/temp_baru01.dbf
```

---

## 6. Menambah Tempfile ke Temporary Tablespace

```sql
ALTER TABLESPACE temp_baru
ADD TEMPFILE
'/u01/app/oracle/oradata/ORADB/pdb1/temp_baru02.dbf'
SIZE 10M AUTOEXTEND ON NEXT 10M MAXSIZE 1G;
```

**Fungsi:**  
Menambahkan tempfile kedua ke `TEMP_BARU`.

**Contoh output:**

```text
Tablespace altered.
```

---

## 7. Membuat Temporary Tablespace dengan Dua Tempfile Sekaligus

```sql
CREATE TEMPORARY TABLESPACE temp_baru
TEMPFILE
'/u01/app/oracle/oradata/ORADB/pdb1/temp_baru01.dbf',
'/u01/app/oracle/oradata/ORADB/pdb1/temp_baru02.dbf';
```

**Fungsi:**  
Membuat temporary tablespace dengan beberapa tempfile langsung.

**Catatan:**  
Jika file sudah ada dan ingin dipakai ulang, gunakan `REUSE`. Namun untuk latihan awal, lebih aman hapus dulu tablespace/file lama agar tidak bentrok.

---

## 8. Mengecek Autoextend Tempfile

```sql
SELECT file_name, autoextensible
FROM dba_temp_files
WHERE tablespace_name='TEMP_BARU';
```

**Fungsi:**  
Melihat apakah tempfile dapat bertambah otomatis.

**Contoh output:**

```text
FILE_NAME                                                    AUT
------------------------------------------------------------ ---
/u01/app/oracle/oradata/ORADB/pdb1/temp_baru01.dbf           YES
/u01/app/oracle/oradata/ORADB/pdb1/temp_baru02.dbf           YES
```

---

## 9. Menghapus Temporary Tablespace

```sql
DROP TABLESPACE temp_baru;
```

**Fungsi:**  
Menghapus definisi tablespace dari dictionary Oracle.

**Catatan penting:**  
Pada beberapa kondisi, file fisik masih bisa tertinggal. Cek dengan:

```sql
!ls -l /u01/app/oracle/oradata/ORADB/pdb1/temp_baru01.dbf
```

Untuk menghapus tablespace beserta file fisiknya, gunakan:

```sql
DROP TABLESPACE temp_baru INCLUDING CONTENTS AND DATAFILES;
```

---

## 10. User, Default Tablespace, Temporary Tablespace, dan Quota

### 10.1 Membuat user biasa

```sql
CREATE USER amir IDENTIFIED BY amir;
```

**Fungsi:**  
Membuat user `AMIR` dengan password `amir`.

**Catatan:**  
User ini belum tentu bisa login jika belum diberi privilege `CREATE SESSION` atau role yang mengandung hak login.

---

### 10.2 Membuat user dengan default tablespace dan quota unlimited

```sql
CREATE USER budi IDENTIFIED BY budi
DEFAULT TABLESPACE ts_gede
QUOTA UNLIMITED ON ts_gede;
```

**Fungsi:**  
Membuat user `BUDI`, menetapkan tablespace utama `TS_GEDE`, dan memberi kuota tidak terbatas pada tablespace tersebut.

**Makna:**

| Bagian | Arti |
|---|---|
| `DEFAULT TABLESPACE ts_gede` | Object milik user default-nya disimpan di `TS_GEDE`. |
| `QUOTA UNLIMITED ON ts_gede` | User boleh memakai ruang tablespace tersebut tanpa batas kuota Oracle. |

---

### 10.3 Membuat user dengan default tablespace, quota, dan temporary tablespace

```sql
CREATE USER candra IDENTIFIED BY candra
DEFAULT TABLESPACE ts_gede
QUOTA 20M ON ts_gede
TEMPORARY TABLESPACE temp_baru;
```

**Fungsi:**  
Membuat user `CANDRA` dengan:

```text
Default tablespace   : TS_GEDE
Quota                : 20 MB
Temporary tablespace : TEMP_BARU
```

**Best practice:**  
Untuk production, user sebaiknya memiliki default tablespace dan temporary tablespace yang jelas.

---

### 10.4 Mengecek default dan temporary tablespace user

```sql
COL USERNAME FORMAT A10
COL DEFAULT_TABLESPACE FORMAT A20
COL TEMPORARY_TABLESPACE FORMAT A20

SELECT username, default_tablespace, temporary_tablespace
FROM dba_users
WHERE username IN ('AMIR', 'BUDI', 'CANDRA');
```

**Fungsi:**  
Memastikan konfigurasi tablespace user.

**Contoh output:**

```text
USERNAME   DEFAULT_TABLESPACE  TEMPORARY_TABLESPACE
---------- ------------------- --------------------
AMIR       USERS               TEMP
BUDI       TS_GEDE             TEMP
CANDRA     TS_GEDE             TEMP_BARU
```

---

## 11. Default Temporary Tablespace Database/PDB

### 11.1 Cek default temporary tablespace

```sql
SELECT property_value
FROM database_properties
WHERE property_name='DEFAULT_TEMP_TABLESPACE';
```

**Fungsi:**  
Melihat temporary tablespace default untuk PDB/database saat ini.

**Contoh output:**

```text
PROPERTY_VALUE
--------------
TEMP
```

---

### 11.2 Mengubah default temporary tablespace

```sql
ALTER DATABASE DEFAULT TEMPORARY TABLESPACE TEMP_BARU;
```

**Fungsi:**  
Menjadikan `TEMP_BARU` sebagai temporary tablespace default.

**Contoh output:**

```text
Database altered.
```

---

### 11.3 Mengembalikan default temporary tablespace ke TEMP

```sql
ALTER DATABASE DEFAULT TEMPORARY TABLESPACE TEMP;
```

**Fungsi:**  
Mengembalikan default temporary tablespace ke `TEMP`.

---

### 11.4 Mengubah temporary tablespace user tertentu

```sql
ALTER USER candra TEMPORARY TABLESPACE temp_baru;
```

**Fungsi:**  
Mengatur user `CANDRA` agar menggunakan `TEMP_BARU` sebagai temporary tablespace.

---

## 12. Quota Tablespace User

### 12.1 Mengecek quota user

```sql
SELECT username,
       tablespace_name,
       bytes/(1024*1024) AS kepake_mb,
       max_bytes/(1024*1024) AS quota_mb
FROM dba_ts_quotas
WHERE username IN ('AMIR', 'BUDI', 'CANDRA');
```

**Fungsi:**  
Mengecek pemakaian dan kuota tablespace user.

**Contoh output:**

```text
USERNAME   TABLESPACE_NAME   KEPAKE_MB   QUOTA_MB
---------- ----------------- ---------- ----------
BUDI       TS_GEDE                    0         -1
CANDRA     TS_GEDE                    0         20
```

**Cara membaca:**

| Nilai | Arti |
|---|---|
| `KEPAKE_MB` | Ruang yang sudah dipakai user. |
| `QUOTA_MB` | Batas kuota user pada tablespace. |
| `-1` | Biasanya menunjukkan unlimited quota. |

---

### 12.2 Mengubah quota user

```sql
ALTER USER budi QUOTA 50M ON ts_gede;
```

**Fungsi:**  
Mengubah kuota user `BUDI` pada `TS_GEDE` menjadi 50 MB.

---

## 13. Profile dan Resource Limit

Profile digunakan untuk membatasi resource dan mengatur kebijakan password user.

### 13.1 Membuat profile resource limit

```sql
CREATE PROFILE profil_user_kantor LIMIT
SESSIONS_PER_USER 2
IDLE_TIME 5
CONNECT_TIME 60
CPU_PER_SESSION 1000000
CPU_PER_CALL 1000
LOGICAL_READS_PER_SESSION 10000
LOGICAL_READS_PER_CALL 100
FAILED_LOGIN_ATTEMPTS 3
PASSWORD_LOCK_TIME 1;
```

**Fungsi:**  
Membuat profile untuk membatasi session, waktu idle, waktu koneksi, CPU, logical reads, dan login gagal.

**Penjelasan parameter:**

| Parameter | Fungsi |
|---|---|
| `SESSIONS_PER_USER 2` | Maksimal 2 session login paralel untuk 1 user. |
| `IDLE_TIME 5` | User yang idle lebih dari 5 menit dapat diputus. |
| `CONNECT_TIME 60` | Total waktu koneksi maksimal 60 menit. |
| `CPU_PER_SESSION 1000000` | Batas CPU per session dalam satuan 1/100 detik. |
| `CPU_PER_CALL 1000` | Batas CPU per call/command. |
| `LOGICAL_READS_PER_SESSION 10000` | Batas logical read selama satu session. |
| `LOGICAL_READS_PER_CALL 100` | Batas logical read per command. |
| `FAILED_LOGIN_ATTEMPTS 3` | Setelah 3 kali gagal login, user dikunci. |
| `PASSWORD_LOCK_TIME 1` | User terkunci selama 1 hari. |

**Contoh output:**

```text
Profile created.
```

---

### 13.2 Mengaktifkan resource limit database

```sql
SHOW PARAMETER resource_limit;
```

**Fungsi:**  
Mengecek apakah limit resource profile diberlakukan.

**Contoh output:**

```text
NAME            TYPE     VALUE
--------------- -------- -----
resource_limit  boolean  FALSE
```

Jika masih `FALSE`, aktifkan:

```sql
ALTER SYSTEM SET resource_limit=TRUE;
```

**Fungsi:**  
Agar limit seperti `IDLE_TIME`, `CPU_PER_SESSION`, dan lainnya benar-benar diberlakukan.

---

### 13.3 Memberi hak login dan memasang profile ke user

```sql
GRANT CONNECT TO amir;
ALTER USER amir PROFILE profil_user_kantor;
SELECT profile FROM dba_users WHERE username='AMIR';
```

**Fungsi:**  
Memberikan role `CONNECT`, memasang profile ke user `AMIR`, dan memverifikasi hasilnya.

**Contoh output:**

```text
Grant succeeded.
User altered.

PROFILE
-------------------------
PROFIL_USER_KANTOR
```

**Catatan:**  
Pada production modern, lebih baik memberi privilege spesifik seperti `CREATE SESSION`, bukan terlalu bergantung pada role lama seperti `CONNECT`.

---

### 13.4 Mengecek isi profile

```sql
COL PROFILE FORMAT A25
COL RESOURCE_NAME FORMAT A30
COL LIMIT FORMAT A20

SELECT profile, resource_name, limit
FROM dba_profiles
WHERE profile='PROFIL_USER_KANTOR';
```

**Fungsi:**  
Melihat semua limit yang berlaku pada profile.

**Contoh output:**

```text
PROFILE                  RESOURCE_NAME                  LIMIT
------------------------ ------------------------------ --------------------
PROFIL_USER_KANTOR       SESSIONS_PER_USER              2
PROFIL_USER_KANTOR       IDLE_TIME                      5
PROFIL_USER_KANTOR       CONNECT_TIME                   60
PROFIL_USER_KANTOR       FAILED_LOGIN_ATTEMPTS          3
PROFIL_USER_KANTOR       PASSWORD_LOCK_TIME             1
```

---

### 13.5 Mengubah resource limit profile

```sql
ALTER PROFILE profil_user_kantor LIMIT IDLE_TIME 1;
```

**Fungsi:**  
Mengubah batas idle user dari 5 menit menjadi 1 menit.

Verifikasi:

```sql
SELECT profile, resource_name, limit
FROM dba_profiles
WHERE profile='PROFIL_USER_KANTOR'
AND resource_name='IDLE_TIME';
```

**Contoh output:**

```text
PROFILE                  RESOURCE_NAME   LIMIT
------------------------ --------------- -----
PROFIL_USER_KANTOR       IDLE_TIME       1
```

---

# Bagian B - Auditing and Compliance

> Bagian ini melengkapi catatan agar sesuai silabus Hari 4. Walaupun command audit tidak dominan di catatan praktik, topik ini masuk modul Auditing and Compliance.

---

## 14. Konsep Unified Auditing

Unified Auditing adalah mekanisme audit modern Oracle untuk mencatat aktivitas database dalam satu audit trail.

Yang biasa diaudit:

```text
1. Login berhasil/gagal
2. Aktivitas user tertentu
3. Akses ke object sensitif
4. Aktivitas administrasi seperti CREATE USER, DROP USER, ALTER SYSTEM
5. Penggunaan privilege tertentu
```

Tujuan audit:

```text
Security      -> mengetahui siapa melakukan apa
Compliance    -> memenuhi kebutuhan pengawasan/kepatuhan
Forensic      -> investigasi saat terjadi insiden
Accountability-> memastikan aktivitas dapat ditelusuri
```

---

## 15. Mengecek Unified Auditing

```sql
SELECT value
FROM v$option
WHERE parameter = 'Unified Auditing';
```

**Fungsi:**  
Melihat apakah fitur Unified Auditing tersedia/aktif.

**Contoh output:**

```text
VALUE
-----
TRUE
```

---

## 16. Melihat Audit Policy yang Ada

```sql
SELECT policy_name, enabled_option, entity_name
FROM audit_unified_enabled_policies;
```

**Fungsi:**  
Melihat audit policy yang sedang aktif.

**Contoh output:**

```text
POLICY_NAME              ENABLED_OPTION   ENTITY_NAME
------------------------ ---------------- ----------------
ORA_LOGON_FAILURES       BY USER          ALL USERS
```

---

## 17. Membuat Audit Policy Sederhana

```sql
CREATE AUDIT POLICY audit_user_management
ACTIONS CREATE USER, ALTER USER, DROP USER;
```

**Fungsi:**  
Membuat kebijakan audit untuk aktivitas pengelolaan user.

Aktifkan policy:

```sql
AUDIT POLICY audit_user_management;
```

**Fungsi:**  
Mengaktifkan policy audit tersebut.

---

## 18. Audit Aktivitas Login Gagal

```sql
AUDIT CREATE SESSION WHENEVER NOT SUCCESSFUL;
```

**Fungsi:**  
Mencatat percobaan login yang gagal.

**Catatan:**  
Berguna untuk mendeteksi brute force, password salah berulang, atau user yang mencoba login tanpa hak.

---

## 19. Melihat Hasil Audit

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

**Fungsi:**  
Melihat 20 aktivitas audit terbaru.

**Contoh output:**

```text
EVENT_TIMESTAMP              DBUSERNAME  ACTION_NAME     RETURN_CODE  UNIFIED_AUDIT_POLICIES
---------------------------- ----------- --------------- ------------ ----------------------
09-JUL-26 10.30.12.123 AM    AMIR        LOGON           1017         ORA_LOGON_FAILURES
09-JUL-26 10.28.45.100 AM    SYS         CREATE USER     0            AUDIT_USER_MANAGEMENT
```

**Cara membaca `RETURN_CODE`:**

| Return code | Arti |
|---|---|
| `0` | Berhasil. |
| `1017` | Login gagal karena username/password salah. |
| kode ORA lain | Aktivitas gagal karena error tertentu. |

---

# Bagian C - Monitoring Database

---

## 20. Monitoring Alert Log

### 20.1 Masuk ke lokasi trace

```bash
cd $ORACLE_BASE/diag/rdbms/oradb/oradb/trace
```

**Fungsi:**  
Masuk ke folder trace database.

---

### 20.2 Monitor alert log real-time

```bash
tail -f alert_oradb.log
```

**Fungsi:**  
Melihat log utama database secara real-time.

Yang perlu diperhatikan di alert log:

```text
ORA- error
Startup/shutdown database
Checkpoint
Archivelog issue
Tablespace/datafile issue
PDB open/close
Background process error
```

**Contoh output:**

```text
Starting ORACLE instance (normal)
ALTER PLUGGABLE DATABASE PDBLAB1 OPEN
Completed: ALTER PLUGGABLE DATABASE PDBLAB1 OPEN
Errors in file /u01/app/oracle/diag/rdbms/oradb/oradb/trace/oradb_ora_12345.trc:
ORA-01017: invalid username/password; logon denied
```

---

## 21. Monitoring Session

```sql
COL USERNAME FORMAT A15
COL STATUS FORMAT A10
COL MACHINE FORMAT A25
COL PROGRAM FORMAT A35

SELECT sid, serial#, username, status, machine, program
FROM v$session
WHERE username IS NOT NULL
ORDER BY username, sid;
```

**Fungsi:**  
Melihat session user yang sedang terhubung.

**Contoh output:**

```text
 SID  SERIAL# USERNAME   STATUS    MACHINE        PROGRAM
---- -------- ---------- --------- -------------- -----------------------------
  42    12345 AMIR       ACTIVE    srv1           sqlplus@linux
  55    23456 BUDI       INACTIVE  client01       JDBC Thin Client
```

**Cara membaca:**

| Kolom | Arti |
|---|---|
| `SID`, `SERIAL#` | Identitas session. Dipakai jika perlu kill session. |
| `USERNAME` | User database. |
| `STATUS` | `ACTIVE` sedang bekerja, `INACTIVE` sedang idle. |
| `MACHINE` | Host client. |
| `PROGRAM` | Program client. |

---

## 22. Kill Session Bermasalah

```sql
ALTER SYSTEM KILL SESSION '42,12345' IMMEDIATE;
```

**Fungsi:**  
Menghentikan session tertentu berdasarkan `SID,SERIAL#`.

**Catatan:**  
Gunakan hati-hati. Pastikan session memang bermasalah atau sudah disetujui untuk dihentikan.

---

## 23. Monitoring Transaction

```sql
SELECT s.sid,
       s.serial#,
       s.username,
       t.start_time,
       t.used_ublk,
       t.used_urec
FROM v$transaction t
JOIN v$session s ON t.ses_addr = s.saddr;
```

**Fungsi:**  
Melihat transaksi aktif dan pemakaian undo.

**Contoh output:**

```text
 SID SERIAL# USERNAME START_TIME           USED_UBLK USED_UREC
---- ------- -------- -------------------- --------- ---------
  42   12345 BUDI     07/09/26 10:15:20          128      5330
```

**Cara membaca:**

| Kolom | Arti |
|---|---|
| `START_TIME` | Waktu transaksi dimulai. |
| `USED_UBLK` | Jumlah undo block yang digunakan. |
| `USED_UREC` | Jumlah undo record yang digunakan. |

---

## 24. Monitoring Tablespace Usage

```sql
SELECT df.tablespace_name,
       ROUND(df.total_mb,2) total_mb,
       ROUND(fs.free_mb,2) free_mb,
       ROUND(df.total_mb - fs.free_mb,2) used_mb,
       ROUND(((df.total_mb - fs.free_mb) / df.total_mb) * 100,2) used_pct
FROM
  (SELECT tablespace_name, SUM(bytes)/(1024*1024) total_mb
   FROM dba_data_files
   GROUP BY tablespace_name) df
JOIN
  (SELECT tablespace_name, SUM(bytes)/(1024*1024) free_mb
   FROM dba_free_space
   GROUP BY tablespace_name) fs
ON df.tablespace_name = fs.tablespace_name
ORDER BY used_pct DESC;
```

**Fungsi:**  
Melihat pemakaian tablespace permanen.

**Contoh output:**

```text
TABLESPACE_NAME   TOTAL_MB   FREE_MB   USED_MB   USED_PCT
---------------- --------- --------- --------- ----------
TS_GEDE             100.00     20.00     80.00      80.00
USERS               200.00    150.00     50.00      25.00
```

---

## 25. Monitoring Temp Usage

```sql
SELECT tablespace_name,
       bytes_used/(1024*1024) used_mb,
       bytes_free/(1024*1024) free_mb
FROM v$temp_space_header;
```

**Fungsi:**  
Melihat penggunaan temporary tablespace.

**Contoh output:**

```text
TABLESPACE_NAME    USED_MB    FREE_MB
---------------- --------- ---------
TEMP                  0.00    512.00
TEMP_BARU             8.00     12.00
```

---

## 26. Monitoring PDB

```sql
SHOW PDBS;
```

**Fungsi:**  
Melihat daftar PDB dan statusnya.

**Contoh output:**

```text
    CON_ID CON_NAME                       OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
         2 PDB$SEED                       READ ONLY  NO
         3 PDB1                           READ WRITE NO
         4 PDBLAB1                        READ WRITE NO
```

---

# Bagian D - Performance Management Fundamentals

---

## 27. Melihat Wait Event Session

```sql
SELECT sid, event, wait_class, seconds_in_wait, state
FROM v$session
WHERE username IS NOT NULL
ORDER BY seconds_in_wait DESC;
```

**Fungsi:**  
Melihat session sedang menunggu apa.

**Contoh output:**

```text
 SID EVENT                         WAIT_CLASS  SECONDS_IN_WAIT STATE
---- ----------------------------- ----------- --------------- -------------------
  55 SQL*Net message from client   Idle                    120 WAITING
  42 db file sequential read       User I/O                   2 WAITING
```

**Cara membaca:**

| Wait class | Makna umum |
|---|---|
| `Idle` | Biasanya session sedang menunggu client, tidak selalu masalah. |
| `User I/O` | Menunggu pembacaan data dari storage. |
| `Concurrency` | Potensi contention/latch/lock. |
| `Commit` | Menunggu proses commit/redo write. |

---

## 28. Melihat SQL yang Aktif

```sql
SELECT s.sid,
       s.serial#,
       s.username,
       q.sql_id,
       q.sql_text
FROM v$session s
JOIN v$sql q ON s.sql_id = q.sql_id
WHERE s.username IS NOT NULL
AND s.status = 'ACTIVE';
```

**Fungsi:**  
Melihat SQL yang sedang aktif dijalankan user.

---

## 29. Melihat SQL Berdasarkan SQL_ID

```sql
SELECT sql_id,
       executions,
       elapsed_time/1000000 elapsed_sec,
       cpu_time/1000000 cpu_sec,
       buffer_gets,
       disk_reads,
       rows_processed,
       sql_text
FROM v$sql
WHERE sql_id = 'isi_sql_id';
```

**Fungsi:**  
Melihat statistik SQL tertentu.

**Cara membaca:**

| Kolom | Arti |
|---|---|
| `EXECUTIONS` | Berapa kali SQL dijalankan. |
| `ELAPSED_SEC` | Total waktu berjalan. |
| `CPU_SEC` | Total waktu CPU. |
| `BUFFER_GETS` | Logical read. Tinggi bisa menunjukkan query berat. |
| `DISK_READS` | Physical read. Tinggi bisa menunjukkan banyak baca storage. |
| `ROWS_PROCESSED` | Jumlah row yang diproses/dihasilkan. |

---

## 30. AWR Report Dasar

AWR digunakan untuk melihat performa database pada rentang waktu tertentu.

### 30.1 Menjalankan AWR report

```sql
@$ORACLE_HOME/rdbms/admin/awrrpt.sql
```

**Fungsi:**  
Membuat laporan AWR secara interaktif.

**Alur umum:**

```text
1. Pilih format report: html atau text
2. Pilih jumlah hari snapshot yang ingin ditampilkan
3. Pilih begin snapshot ID
4. Pilih end snapshot ID
5. Tentukan nama file output
```

---

### 30.2 Melihat snapshot AWR

```sql
SELECT snap_id,
       begin_interval_time,
       end_interval_time
FROM dba_hist_snapshot
ORDER BY snap_id DESC
FETCH FIRST 10 ROWS ONLY;
```

**Fungsi:**  
Melihat daftar snapshot AWR terakhir.

**Contoh output:**

```text
 SNAP_ID BEGIN_INTERVAL_TIME        END_INTERVAL_TIME
-------- -------------------------- --------------------------
    1020 09-JUL-26 09.00.00 AM      09-JUL-26 10.00.00 AM
    1019 09-JUL-26 08.00.00 AM      09-JUL-26 09.00.00 AM
```

---

## 31. ADDM Report Dasar

ADDM membantu memberi rekomendasi berdasarkan data AWR.

```sql
@$ORACLE_HOME/rdbms/admin/addmrpt.sql
```

**Fungsi:**  
Membuat laporan ADDM untuk analisis bottleneck.

Yang dicari di ADDM:

```text
1. Top finding
2. Impact percentage
3. Recommendation
4. SQL ID bermasalah
5. Wait event dominan
```

---

# Bagian E - PDB Management Practice

> Bagian ini berasal dari praktik kelas Hari ke-4. Secara silabus, sebagian konsep PDB sudah diperkenalkan di Hari 1, tetapi praktik pengelolaannya penting untuk DBA operasional.

---

## 32. Membuat PDB Baru dari PDB Seed

### 32.1 Login ke CDB root

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=CDB$ROOT;
SHOW PDBS;
```

**Fungsi:**  
Pastikan berada di root container sebelum membuat PDB.

---

### 32.2 Cek datafile PDB seed

```sql
SELECT file_name FROM dba_data_files WHERE con_id=2;
```

**Fungsi:**  
Melihat lokasi datafile `PDB$SEED` sebagai sumber pembuatan PDB baru.

---

### 32.3 Siapkan folder PDB baru

```sql
!mkdir /u01/app/oracle/oradata/ORADB/PDBLAB1
```

**Fungsi:**  
Membuat folder datafile untuk `PDBLAB1`.

---

### 32.4 Create PDBLAB1

```sql
CREATE PLUGGABLE DATABASE PDBLAB1
ADMIN USER pdbadmin IDENTIFIED BY oracle
FILE_NAME_CONVERT = (
'/u01/app/oracle/oradata/ORADB/pdbseed/',
'/u01/app/oracle/oradata/ORADB/PDBLAB1/'
);
```

**Fungsi:**  
Membuat PDB baru bernama `PDBLAB1` dari `PDB$SEED`.

**Contoh output:**

```text
Pluggable database created.
```

---

### 32.5 Open PDBLAB1

```sql
ALTER PLUGGABLE DATABASE PDBLAB1 OPEN;
SHOW PDBS;
```

**Fungsi:**  
Membuka PDB agar bisa digunakan.

**Contoh output:**

```text
CON_NAME      OPEN MODE
------------  ----------
PDBLAB1       READ WRITE
```

---

### 32.6 Save state agar PDB otomatis open setelah restart

```sql
ALTER PLUGGABLE DATABASE PDBLAB1 OPEN;
ALTER PLUGGABLE DATABASE PDBLAB1 SAVE STATE;
```

**Fungsi:**  
Agar `PDBLAB1` tetap otomatis terbuka setelah database restart.

Verifikasi:

```sql
COL CON_NAME FORMAT A20
COL STATE FORMAT A15

SELECT con_name, state
FROM dba_pdb_saved_states
WHERE con_name='PDBLAB1';
```

**Contoh output:**

```text
CON_NAME             STATE
-------------------- ---------------
PDBLAB1              OPEN
```

---

## 33. Menyiapkan Data Contoh di PDBLAB1

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDBLAB1;
SELECT sys_context('USERENV','CON_NAME') FROM dual;
```

**Fungsi:**  
Masuk ke `PDBLAB1` dan memastikan konteks container.

---

### 33.1 Membuat tablespace untuk user latihan

```sql
CREATE TABLESPACE sentot_ts
DATAFILE '/u01/app/oracle/oradata/ORADB/PDBLAB1/sentot_ts01.dbf'
SIZE 50M AUTOEXTEND ON NEXT 10M MAXSIZE 500M;
```

**Fungsi:**  
Membuat tablespace khusus untuk user `SENTOT`.

---

### 33.2 Membuat user latihan

```sql
CREATE USER sentot IDENTIFIED BY widagdo
DEFAULT TABLESPACE sentot_ts
TEMPORARY TABLESPACE temp
QUOTA UNLIMITED ON sentot_ts;
```

**Fungsi:**  
Membuat user `SENTOT` dengan tablespace default `SENTOT_TS`.

---

### 33.3 Memberi privilege

```sql
GRANT CREATE SESSION, CREATE TABLE TO sentot;
```

**Fungsi:**  
Memberi hak login dan membuat tabel.

---

### 33.4 Login sebagai user sentot dan membuat data

```bash
sqlplus sentot/widagdo@localhost:1521/pdblab1.localdomain
```

```sql
SHOW USER;
CREATE TABLE test (x NUMBER);
INSERT INTO test VALUES (1);
COMMIT;
SELECT * FROM test;
```

**Contoh output:**

```text
USER is "SENTOT"

Table created.
1 row created.
Commit complete.

         X
----------
         1
```

---

### 33.5 Cek segment milik user SENTOT

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDBLAB1;

SELECT owner, segment_name, segment_type, tablespace_name
FROM dba_segments
WHERE owner = 'SENTOT';
```

**Fungsi:**  
Melihat object fisik/segment milik user `SENTOT`.

**Contoh output:**

```text
OWNER    SEGMENT_NAME   SEGMENT_TYPE  TABLESPACE_NAME
-------- -------------- ------------- ---------------
SENTOT   TEST           TABLE         SENTOT_TS
```

---

## 34. Clone PDB

### 34.1 Siapkan folder clone

```sql
!mkdir /u01/app/oracle/oradata/ORADB/PDBLAB2
```

---

### 34.2 Clone PDBLAB1 menjadi PDBLAB2

```sql
CONN / AS SYSDBA

CREATE PLUGGABLE DATABASE PDBLAB2
FROM PDBLAB1
FILE_NAME_CONVERT = (
'/u01/app/oracle/oradata/ORADB/PDBLAB1/',
'/u01/app/oracle/oradata/ORADB/PDBLAB2/'
);
```

**Fungsi:**  
Membuat clone `PDBLAB2` dari `PDBLAB1`.

**Contoh output:**

```text
Pluggable database created.
```

---

### 34.3 Open PDB hasil clone

```sql
ALTER PLUGGABLE DATABASE PDBLAB2 OPEN;
SHOW PDBS;
```

**Fungsi:**  
Membuka `PDBLAB2` agar bisa digunakan.

---

### 34.4 Uji data hasil clone

```bash
sqlplus sentot/widagdo@localhost:1521/pdblab2.localdomain
```

```sql
SELECT * FROM test;
```

**Fungsi:**  
Membuktikan bahwa data dari `PDBLAB1` ikut ter-clone ke `PDBLAB2`.

---

## 35. Rename PDB

### 35.1 Masuk ke CDB root

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=CDB$ROOT;
```

---

### 35.2 Close PDB yang akan di-rename

```sql
ALTER PLUGGABLE DATABASE PDBLAB2 CLOSE IMMEDIATE;
```

---

### 35.3 Open restricted

```sql
ALTER PLUGGABLE DATABASE PDBLAB2 OPEN RESTRICTED;
```

**Fungsi:**  
Membuka PDB dalam mode terbatas agar dapat di-rename.

---

### 35.4 Masuk ke PDB dan rename global name

```sql
ALTER SESSION SET CONTAINER=PDBLAB2;
ALTER PLUGGABLE DATABASE PDBLAB2 RENAME GLOBAL_NAME TO PDBLAB2_RENAME;
```

**Fungsi:**  
Mengubah nama global PDB.

---

### 35.5 Close dan open ulang PDB hasil rename

```sql
ALTER SESSION SET CONTAINER=CDB$ROOT;
ALTER PLUGGABLE DATABASE PDBLAB2_RENAME CLOSE IMMEDIATE;
ALTER PLUGGABLE DATABASE PDBLAB2_RENAME OPEN;
SHOW PDBS;
```

**Fungsi:**  
Membuka ulang PDB dengan nama baru.

---

## 36. Memindahkan Satu Datafile PDB

### 36.1 Masuk ke PDB terkait

```sql
ALTER SESSION SET CONTAINER=PDBLAB1;
SELECT name FROM v$datafile;
```

**Fungsi:**  
Melihat daftar datafile di `PDBLAB1`.

---

### 36.2 Siapkan folder baru

```sql
!mkdir -p /u01/app/oracle/oradata/ORADB/PDBLAB1_MOVED
```

---

### 36.3 Move datafile online

```sql
ALTER DATABASE MOVE DATAFILE
'/u01/app/oracle/oradata/ORADB/PDBLAB1/sentot_ts01.dbf'
TO
'/u01/app/oracle/oradata/ORADB/PDBLAB1_MOVED/sentot_ts01.dbf';
```

**Fungsi:**  
Memindahkan datafile `sentot_ts01.dbf` ke lokasi baru.

**Catatan penting:**  
Command harus ditulis sebagai satu perintah SQL lengkap. Jangan mengetik path sebagai command terpisah di SQL*Plus.

---

### 36.4 Verifikasi lokasi datafile

```sql
SELECT file_name
FROM dba_data_files
WHERE tablespace_name='SENTOT_TS';
```

**Contoh output:**

```text
FILE_NAME
------------------------------------------------------------------
/u01/app/oracle/oradata/ORADB/PDBLAB1_MOVED/sentot_ts01.dbf
```

---

## 37. Unplug dan Plug PDB ke Lokasi Baru

### 37.1 Close PDB

```sql
ALTER SESSION SET CONTAINER=CDB$ROOT;
ALTER PLUGGABLE DATABASE PDBLAB1 CLOSE IMMEDIATE;
```

---

### 37.2 Unplug PDB ke XML

```sql
ALTER PLUGGABLE DATABASE PDBLAB1
UNPLUG INTO '/home/oracle/pdblab1.xml';
```

**Fungsi:**  
Mengekspor metadata PDB ke file XML.

---

### 37.3 Drop PDB tetapi pertahankan datafile

```sql
DROP PLUGGABLE DATABASE PDBLAB1 KEEP DATAFILES;
SHOW PDBS;
```

**Fungsi:**  
Menghapus PDB dari CDB, tetapi file fisiknya tetap ada.

---

### 37.4 Plug kembali dengan COPY ke lokasi baru

```sql
!mkdir /u01/app/oracle/oradata/ORADB/PDBLAB1_NEWLOC

CREATE PLUGGABLE DATABASE PDBLAB1
USING '/home/oracle/pdblab1.xml'
COPY
FILE_NAME_CONVERT = (
'/u01/app/oracle/oradata/ORADB/PDBLAB1/',
'/u01/app/oracle/oradata/ORADB/PDBLAB1_NEWLOC/',
'/u01/app/oracle/oradata/ORADB/PDBLAB1_MOVED/',
'/u01/app/oracle/oradata/ORADB/PDBLAB1_NEWLOC/'
);
```

**Fungsi:**  
Mendaftarkan kembali PDB dan menyalin datafile ke lokasi baru.

**Catatan:**  
Karena menggunakan `COPY`, file lama masih ada.

---

### 37.5 Open dan verifikasi

```sql
ALTER PLUGGABLE DATABASE PDBLAB1 OPEN;
SHOW PDBS;
ALTER SESSION SET CONTAINER=PDBLAB1;
SELECT name FROM v$datafile;
```

---

## 38. Unplug dan Plug di Lokasi yang Sama dengan NOCOPY

### 38.1 Unplug

```sql
CONN / AS SYSDBA
ALTER PLUGGABLE DATABASE PDBLAB1 CLOSE IMMEDIATE;

ALTER PLUGGABLE DATABASE PDBLAB1
UNPLUG INTO '/home/oracle/pdblab1lagi.xml';

DROP PLUGGABLE DATABASE PDBLAB1 KEEP DATAFILES;
SHOW PDBS;
```

---

### 38.2 Plug ulang dengan NOCOPY

```sql
CREATE PLUGGABLE DATABASE PDBLAB1
USING '/home/oracle/pdblab1lagi.xml'
NOCOPY;

ALTER PLUGGABLE DATABASE PDBLAB1 OPEN;
SHOW PDBS;
```

**Fungsi:**  
Mendaftarkan PDB kembali dengan menggunakan file di lokasi yang sama tanpa menyalin datafile.

**Perbedaan `COPY` vs `NOCOPY`:**

| Opsi | Makna | Dampak |
|---|---|---|
| `COPY` | Oracle menyalin datafile ke lokasi baru. | File lama tetap ada. |
| `NOCOPY` | Oracle memakai datafile di lokasi existing. | Tidak ada penyalinan file. |

---

## 39. PDB dengan Oracle Managed Files (OMF)

OMF memudahkan pembuatan file database karena Oracle otomatis menentukan nama dan lokasi file berdasarkan parameter `db_create_file_dest`.

### 39.1 Cek parameter OMF

```sql
SHOW PARAMETER db_create_file_dest;
```

**Fungsi:**  
Melihat lokasi default OMF.

---

### 39.2 Set lokasi OMF

```sql
ALTER SYSTEM SET db_create_file_dest='/u01/app/oracle/oradata';
SHOW PARAMETER db_create_file_dest;
```

**Fungsi:**  
Menentukan lokasi default pembuatan file database.

---

### 39.3 Membuat PDBOMF

```sql
CREATE PLUGGABLE DATABASE PDBOMF
ADMIN USER PDBADMIN IDENTIFIED BY ORACLE;
```

**Fungsi:**  
Membuat PDB tanpa `FILE_NAME_CONVERT`, karena lokasi file dikelola OMF.

---

### 39.4 Open PDBOMF dan cek datafile

```sql
ALTER PLUGGABLE DATABASE PDBOMF OPEN;
ALTER SESSION SET CONTAINER=PDBOMF;
SELECT name FROM v$datafile;
```

**Fungsi:**  
Membuka PDB dan melihat nama file otomatis yang dibuat Oracle.

---

### 39.5 Membuat tablespace dengan OMF

```sql
CREATE TABLESPACE ts_baru DATAFILE SIZE 10M;
ALTER TABLESPACE ts_baru ADD DATAFILE SIZE 10M;
```

**Fungsi:**  
Membuat tablespace/datafile tanpa menentukan path fisik secara manual.

---

## 40. Menghapus PDB

```sql
CONN / AS SYSDBA
ALTER PLUGGABLE DATABASE PDBOMF CLOSE IMMEDIATE;
DROP PLUGGABLE DATABASE PDBOMF INCLUDING DATAFILES;
SHOW PDBS;
```

**Fungsi:**  
Menghapus PDB beserta datafile fisiknya.

**Perbedaan penting:**

| Command | Dampak |
|---|---|
| `DROP PLUGGABLE DATABASE ... KEEP DATAFILES` | PDB dihapus dari CDB, file fisik tetap ada. |
| `DROP PLUGGABLE DATABASE ... INCLUDING DATAFILES` | PDB dan file fisiknya dihapus. |

---

# Bagian F - Ringkasan Command Berurutan untuk Latihan

## 41. Alur Latihan 1 - Temporary Tablespace dan User

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;
SHOW CON_NAME;

SELECT tablespace_name, file_name FROM dba_temp_files;

CREATE TEMPORARY TABLESPACE temp_baru
TEMPFILE '/u01/app/oracle/oradata/ORADB/pdb1/temp_baru01.dbf'
SIZE 10M AUTOEXTEND ON NEXT 10M MAXSIZE 1G;

ALTER TABLESPACE temp_baru
ADD TEMPFILE '/u01/app/oracle/oradata/ORADB/pdb1/temp_baru02.dbf'
SIZE 10M AUTOEXTEND ON NEXT 10M MAXSIZE 1G;

CREATE USER candra IDENTIFIED BY candra
DEFAULT TABLESPACE ts_gede
QUOTA 20M ON ts_gede
TEMPORARY TABLESPACE temp_baru;

SELECT username, default_tablespace, temporary_tablespace
FROM dba_users
WHERE username='CANDRA';
```

---

## 42. Alur Latihan 2 - Profile dan Resource Limit

```sql
CREATE PROFILE profil_user_kantor LIMIT
SESSIONS_PER_USER 2
IDLE_TIME 5
CONNECT_TIME 60
FAILED_LOGIN_ATTEMPTS 3
PASSWORD_LOCK_TIME 1;

ALTER SYSTEM SET resource_limit=TRUE;

GRANT CREATE SESSION TO amir;
ALTER USER amir PROFILE profil_user_kantor;

SELECT profile FROM dba_users WHERE username='AMIR';
SELECT profile, resource_name, limit
FROM dba_profiles
WHERE profile='PROFIL_USER_KANTOR';
```

---

## 43. Alur Latihan 3 - Monitoring

```sql
SHOW PDBS;

SELECT sid, serial#, username, status, machine, program
FROM v$session
WHERE username IS NOT NULL;

SELECT tablespace_name,
       bytes_used/(1024*1024) used_mb,
       bytes_free/(1024*1024) free_mb
FROM v$temp_space_header;
```

```bash
cd $ORACLE_BASE/diag/rdbms/oradb/oradb/trace
tail -f alert_oradb.log
```

---

## 44. Alur Latihan 4 - PDB Create, Clone, dan Drop

```sql
CONN / AS SYSDBA
SHOW PDBS;

!mkdir /u01/app/oracle/oradata/ORADB/PDBLAB1

CREATE PLUGGABLE DATABASE PDBLAB1
ADMIN USER pdbadmin IDENTIFIED BY oracle
FILE_NAME_CONVERT = (
'/u01/app/oracle/oradata/ORADB/pdbseed/',
'/u01/app/oracle/oradata/ORADB/PDBLAB1/'
);

ALTER PLUGGABLE DATABASE PDBLAB1 OPEN;
ALTER PLUGGABLE DATABASE PDBLAB1 SAVE STATE;
SHOW PDBS;

!mkdir /u01/app/oracle/oradata/ORADB/PDBLAB2

CREATE PLUGGABLE DATABASE PDBLAB2
FROM PDBLAB1
FILE_NAME_CONVERT = (
'/u01/app/oracle/oradata/ORADB/PDBLAB1/',
'/u01/app/oracle/oradata/ORADB/PDBLAB2/'
);

ALTER PLUGGABLE DATABASE PDBLAB2 OPEN;
SHOW PDBS;
```

---

# Bagian G - Troubleshooting Ringkas

## 45. Temporary tablespace tidak dipakai

Kemungkinan:

```text
1. Belum menjadi default temporary tablespace.
2. Belum di-assign ke user.
3. Query tidak membutuhkan sort/hash temporary besar.
```

Cek:

```sql
SELECT property_value
FROM database_properties
WHERE property_name='DEFAULT_TEMP_TABLESPACE';

SELECT username, temporary_tablespace
FROM dba_users
WHERE username='CANDRA';
```

---

## 46. User tidak bisa membuat object

Kemungkinan:

```text
1. Belum punya privilege CREATE TABLE.
2. Belum punya quota di tablespace.
3. Default tablespace salah.
```

Solusi:

```sql
GRANT CREATE TABLE TO username;
ALTER USER username QUOTA 100M ON nama_tablespace;
```

---

## 47. Profile tidak terasa efeknya

Kemungkinan:

```text
1. resource_limit masih FALSE.
2. Profile belum dipasang ke user.
3. Yang diuji adalah parameter password, bukan resource, atau sebaliknya.
```

Cek:

```sql
SHOW PARAMETER resource_limit;
SELECT username, profile FROM dba_users WHERE username='AMIR';
```

---

## 48. PDB tidak otomatis open setelah restart

Penyebab:

```text
PDB belum SAVE STATE.
```

Solusi:

```sql
ALTER PLUGGABLE DATABASE PDBLAB1 OPEN;
ALTER PLUGGABLE DATABASE PDBLAB1 SAVE STATE;
```

---

## 49. Clone PDB gagal karena file sudah ada

Kemungkinan:

```text
1. Folder tujuan sudah berisi file lama.
2. FILE_NAME_CONVERT salah.
3. PDB sumber belum dalam state yang valid untuk clone.
```

Solusi:

```text
1. Cek folder tujuan.
2. Pastikan path source dan target benar.
3. Gunakan nama PDB/folder yang belum dipakai.
```

---

## 50. Move datafile error karena command terpecah

Pastikan command ditulis utuh seperti ini:

```sql
ALTER DATABASE MOVE DATAFILE
'/u01/app/oracle/oradata/ORADB/PDBLAB1/sentot_ts01.dbf'
TO
'/u01/app/oracle/oradata/ORADB/PDBLAB1_MOVED/sentot_ts01.dbf';
```

Jangan mengetik path file secara terpisah di prompt SQL*Plus karena akan dianggap command baru dan muncul error `SP2-0734` atau `SP2-0042`.

---

# Bagian H - Checklist Belajar Mandiri

```text
[ ] Saya bisa menjelaskan fungsi temporary tablespace.
[ ] Saya bisa membuat temporary tablespace dan tempfile.
[ ] Saya bisa membedakan default tablespace dan temporary tablespace user.
[ ] Saya bisa memberikan quota user pada tablespace tertentu.
[ ] Saya bisa mengecek quota user melalui DBA_TS_QUOTAS.
[ ] Saya bisa membuat profile untuk membatasi resource user.
[ ] Saya paham arti SESSIONS_PER_USER, IDLE_TIME, CONNECT_TIME, dan FAILED_LOGIN_ATTEMPTS.
[ ] Saya bisa memasang profile ke user.
[ ] Saya bisa membaca alert log database.
[ ] Saya bisa melihat session aktif melalui V$SESSION.
[ ] Saya bisa melihat transaksi aktif melalui V$TRANSACTION.
[ ] Saya bisa melihat penggunaan temp melalui V$TEMP_SPACE_HEADER.
[ ] Saya bisa menjelaskan fungsi audit dan unified audit trail.
[ ] Saya bisa membuat audit policy sederhana.
[ ] Saya bisa menjalankan AWR report dasar.
[ ] Saya bisa membuat PDB baru dari PDB$SEED.
[ ] Saya bisa membuka PDB dan melakukan SAVE STATE.
[ ] Saya bisa clone PDB.
[ ] Saya bisa rename PDB.
[ ] Saya bisa move datafile PDB.
[ ] Saya bisa unplug dan plug PDB dengan COPY atau NOCOPY.
[ ] Saya bisa membuat PDB berbasis OMF.
[ ] Saya bisa drop PDB dengan KEEP DATAFILES atau INCLUDING DATAFILES.
```

---

# Bagian I - Mini Latihan Ujian Lisan

1. Apa fungsi temporary tablespace?
2. Mengapa temporary tablespace baru tidak otomatis dipakai user?
3. Apa beda default tablespace dan temporary tablespace?
4. Apa fungsi quota pada user?
5. Apa arti `QUOTA UNLIMITED ON ts_gede`?
6. Apa fungsi profile di Oracle?
7. Apa fungsi `SESSIONS_PER_USER`?
8. Apa fungsi `IDLE_TIME`?
9. Mengapa `resource_limit` perlu dicek?
10. Apa fungsi alert log?
11. Apa beda `V$SESSION` dan `V$TRANSACTION`?
12. Apa fungsi Unified Auditing?
13. Apa fungsi AWR dan ADDM?
14. Apa fungsi `ALTER PLUGGABLE DATABASE ... SAVE STATE`?
15. Apa beda clone PDB dan unplug/plug PDB?
16. Apa beda `COPY` dan `NOCOPY` saat plug PDB?
17. Apa beda `KEEP DATAFILES` dan `INCLUDING DATAFILES` saat drop PDB?
18. Apa fungsi OMF?
19. Mengapa `ALTER DATABASE MOVE DATAFILE` harus ditulis sebagai satu command utuh?
20. Apa risiko menjalankan `DROP PLUGGABLE DATABASE ... INCLUDING DATAFILES`?

---

# Bagian J - Jawaban Singkat Mini Latihan

1. Temporary tablespace dipakai untuk operasi sementara seperti sort, hash, dan temporary segment.
2. Karena harus dijadikan default temporary tablespace atau di-assign ke user tertentu.
3. Default tablespace menyimpan object permanen user, temporary tablespace menyimpan data sementara saat operasi query.
4. Quota membatasi ruang tablespace yang boleh digunakan user.
5. User boleh menggunakan tablespace `TS_GEDE` tanpa batas kuota Oracle.
6. Profile mengatur resource limit dan kebijakan password user.
7. Membatasi jumlah session paralel per user.
8. Membatasi waktu user boleh idle.
9. Agar resource limit profile benar-benar diberlakukan oleh database.
10. Alert log adalah log utama untuk melihat kejadian penting dan error database.
11. `V$SESSION` menampilkan session, `V$TRANSACTION` menampilkan transaksi aktif.
12. Unified Auditing mencatat aktivitas database untuk keamanan dan compliance.
13. AWR membuat laporan performa berbasis snapshot, ADDM memberi analisis dan rekomendasi.
14. Agar PDB otomatis open lagi setelah restart database.
15. Clone membuat salinan PDB, unplug/plug melepas dan mendaftarkan ulang PDB.
16. `COPY` menyalin datafile, `NOCOPY` memakai datafile existing.
17. `KEEP DATAFILES` mempertahankan file fisik, `INCLUDING DATAFILES` menghapus file fisik.
18. OMF membuat Oracle mengelola nama dan lokasi file otomatis.
19. Jika terpecah, SQL*Plus menganggap path sebagai command terpisah dan menghasilkan error.
20. PDB dan seluruh datafile-nya akan hilang dari storage.

---

# Bagian K - Command Paling Penting untuk Dihafal

```sql
SHOW USER
SHOW CON_NAME
SHOW PDBS
ALTER SESSION SET CONTAINER=PDB1;

SELECT tablespace_name, file_name FROM dba_temp_files;
CREATE TEMPORARY TABLESPACE temp_baru TEMPFILE '/path/temp_baru01.dbf' SIZE 10M AUTOEXTEND ON NEXT 10M MAXSIZE 1G;
ALTER TABLESPACE temp_baru ADD TEMPFILE '/path/temp_baru02.dbf' SIZE 10M AUTOEXTEND ON NEXT 10M MAXSIZE 1G;
ALTER DATABASE DEFAULT TEMPORARY TABLESPACE TEMP_BARU;
ALTER DATABASE DEFAULT TEMPORARY TABLESPACE TEMP;

CREATE USER candra IDENTIFIED BY candra DEFAULT TABLESPACE ts_gede QUOTA 20M ON ts_gede TEMPORARY TABLESPACE temp_baru;
SELECT username, default_tablespace, temporary_tablespace FROM dba_users;
SELECT username, tablespace_name, bytes/(1024*1024), max_bytes/(1024*1024) FROM dba_ts_quotas;

CREATE PROFILE profil_user_kantor LIMIT SESSIONS_PER_USER 2 IDLE_TIME 5 CONNECT_TIME 60 FAILED_LOGIN_ATTEMPTS 3 PASSWORD_LOCK_TIME 1;
ALTER SYSTEM SET resource_limit=TRUE;
ALTER USER amir PROFILE profil_user_kantor;
SELECT profile, resource_name, limit FROM dba_profiles WHERE profile='PROFIL_USER_KANTOR';

SELECT sid, serial#, username, status, machine, program FROM v$session WHERE username IS NOT NULL;
SELECT tablespace_name, bytes_used/(1024*1024), bytes_free/(1024*1024) FROM v$temp_space_header;

CREATE PLUGGABLE DATABASE PDBLAB1 ADMIN USER pdbadmin IDENTIFIED BY oracle FILE_NAME_CONVERT = ('/source/', '/target/');
ALTER PLUGGABLE DATABASE PDBLAB1 OPEN;
ALTER PLUGGABLE DATABASE PDBLAB1 SAVE STATE;
CREATE PLUGGABLE DATABASE PDBLAB2 FROM PDBLAB1 FILE_NAME_CONVERT = ('/source/', '/target/');
ALTER DATABASE MOVE DATAFILE '/old/file.dbf' TO '/new/file.dbf';
ALTER PLUGGABLE DATABASE PDBLAB1 UNPLUG INTO '/home/oracle/pdblab1.xml';
DROP PLUGGABLE DATABASE PDBLAB1 KEEP DATAFILES;
CREATE PLUGGABLE DATABASE PDBLAB1 USING '/home/oracle/pdblab1.xml' NOCOPY;
DROP PLUGGABLE DATABASE PDBOMF INCLUDING DATAFILES;
```

```bash
cd $ORACLE_BASE/diag/rdbms/oradb/oradb/trace
tail -f alert_oradb.log
```

---

# Bagian L - Catatan Keamanan

Command berikut berisiko jika dijalankan di production:

```sql
DROP TABLESPACE ... INCLUDING CONTENTS AND DATAFILES;
DROP PLUGGABLE DATABASE ... INCLUDING DATAFILES;
ALTER SYSTEM KILL SESSION ... IMMEDIATE;
ALTER DATABASE MOVE DATAFILE ...;
ALTER PLUGGABLE DATABASE ... UNPLUG ...;
DROP PLUGGABLE DATABASE ... KEEP DATAFILES;
```

Sebelum melakukan di production:

```text
1. Pastikan ada backup.
2. Pastikan ada approval/change request.
3. Pastikan maintenance window.
4. Pastikan path file benar.
5. Pastikan impact ke aplikasi sudah dianalisis.
6. Dokumentasikan kondisi sebelum dan sesudah perubahan.
```

---

Selesai.
