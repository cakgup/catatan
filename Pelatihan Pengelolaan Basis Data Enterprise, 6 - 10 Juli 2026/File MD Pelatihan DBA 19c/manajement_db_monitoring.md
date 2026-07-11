# HANDS-ON LAB

# Database Monitoring Oracle 19c CDB/PDB

Asumsi:

```text
CDB     : ORADB
PDB     : PDB1
OS      : Oracle Linux
Oracle  : 19c
User OS : oracle
```

---

# 0. Persiapan Awal

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

Verifikasi instance:

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

---

# LAB 1 — Monitoring Status CDB dan PDB

```sql
SET LINESIZE 200
COLUMN name FORMAT A25
COLUMN open_mode FORMAT A15

SELECT con_id,
       name,
       open_mode,
       restricted
FROM v$pdbs
ORDER BY con_id;
```

Contoh output:

```text
    CON_ID NAME                      OPEN_MODE       RES
---------- ------------------------- --------------- ---
         2 PDB$SEED                  READ ONLY       NO
         3 PDB1                      READ WRITE      NO
```

Cek informasi container aktif:

```sql
SHOW CON_NAME
```

Contoh output:

```text
CON_NAME
------------------------------
CDB$ROOT
```

Masuk ke PDB1:

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

# LAB 2 — Monitoring Session Aktif

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

COLUMN username FORMAT A15
COLUMN status FORMAT A10
COLUMN machine FORMAT A25
COLUMN program FORMAT A35

SELECT sid,
       serial#,
       username,
       status,
       machine,
       program
FROM v$session
WHERE username IS NOT NULL
ORDER BY username, sid;
```

Contoh output:

```text
       SID    SERIAL# USERNAME        STATUS     MACHINE                   PROGRAM
---------- ---------- --------------- ---------- ------------------------- ------------------------------
        72      38102 SYS             ACTIVE     oracle19c                 sqlplus@oracle19c
        84      19221 APPUSER         INACTIVE   oracle19c                 sqlplus@oracle19c
```

Monitoring session berdasarkan status:

```sql
SELECT status,
       COUNT(*) AS jumlah_session
FROM v$session
WHERE username IS NOT NULL
GROUP BY status
ORDER BY status;
```

Contoh output:

```text
STATUS     JUMLAH_SESSION
---------- --------------
ACTIVE                  1
INACTIVE                3
```

---

# LAB 3 — Monitoring Session Wait Event

```sql
COLUMN username FORMAT A15
COLUMN event FORMAT A40
COLUMN wait_class FORMAT A20

SELECT sid,
       serial#,
       username,
       status,
       event,
       wait_class,
       seconds_in_wait
FROM v$session
WHERE username IS NOT NULL
ORDER BY seconds_in_wait DESC;
```

Contoh output:

```text
       SID    SERIAL# USERNAME        STATUS     EVENT                                    WAIT_CLASS           SECONDS_IN_WAIT
---------- ---------- --------------- ---------- ---------------------------------------- -------------------- ---------------
        84      19221 APPUSER         INACTIVE   SQL*Net message from client              Idle                             120
        72      38102 SYS             ACTIVE     SQL*Net message to client                Network                            0
```

Ringkasan wait event:

```sql
SELECT event,
       wait_class,
       COUNT(*) AS jumlah_session
FROM v$session
WHERE username IS NOT NULL
GROUP BY event, wait_class
ORDER BY jumlah_session DESC;
```

Contoh output:

```text
EVENT                                    WAIT_CLASS           JUMLAH_SESSION
---------------------------------------- -------------------- --------------
SQL*Net message from client              Idle                              3
db file sequential read                  User I/O                          1
```

---

# LAB 4 — Monitoring Blocking Session

Buka **Session 1**:

```bash
sqlplus / as sysdba
```

```sql
ALTER SESSION SET CONTAINER=PDB1;

CREATE USER monuser IDENTIFIED BY oracle
DEFAULT TABLESPACE USERS
TEMPORARY TABLESPACE TEMP
QUOTA UNLIMITED ON USERS;

GRANT CREATE SESSION, CREATE TABLE TO monuser;
```

Contoh output:

```text
User created.
Grant succeeded.
```

Login sebagai `monuser`:

```sql
CONN monuser/oracle@localhost:1521/pdb1.localdomain

CREATE TABLE lock_test (
    id NUMBER PRIMARY KEY,
    nama VARCHAR2(50)
);

INSERT INTO lock_test VALUES (1, 'DATA AWAL');
COMMIT;
```

Contoh output:

```text
Table created.
1 row created.
Commit complete.
```

Update tanpa commit:

```sql
UPDATE lock_test
SET nama = 'SESSION 1'
WHERE id = 1;
```

Contoh output:

```text
1 row updated.
```

Jangan `COMMIT`.

Buka **Session 2**:

```bash
sqlplus monuser/oracle@localhost:1521/pdb1.localdomain
```

```sql
UPDATE lock_test
SET nama = 'SESSION 2'
WHERE id = 1;
```

Session 2 akan menunggu.

Buka **Session 3** untuk monitoring:

```bash
sqlplus / as sysdba
```

```sql
ALTER SESSION SET CONTAINER=PDB1;

COLUMN username FORMAT A15
COLUMN event FORMAT A35

SELECT sid,
       serial#,
       username,
       blocking_session,
       event,
       seconds_in_wait
FROM v$session
WHERE username = 'MONUSER';
```

Contoh output:

```text
       SID    SERIAL# USERNAME        BLOCKING_SESSION EVENT                               SECONDS_IN_WAIT
---------- ---------- --------------- ---------------- ----------------------------------- ---------------
        85      11221 MONUSER                          SQL*Net message from client                      45
        91      44210 MONUSER                       85 enq: TX - row lock contention                    30
```

Selesaikan blocking dari Session 1:

```sql
COMMIT;
```

Contoh output:

```text
Commit complete.
```

Verifikasi blocking hilang:

```sql
SELECT sid,
       serial#,
       username,
       blocking_session,
       event
FROM v$session
WHERE username = 'MONUSER';
```

Contoh output:

```text
       SID    SERIAL# USERNAME        BLOCKING_SESSION EVENT
---------- ---------- --------------- ---------------- ------------------------------
        85      11221 MONUSER                          SQL*Net message from client
        91      44210 MONUSER                          SQL*Net message from client
```

---

# LAB 5 — Monitoring Transaksi Aktif

Buat transaksi aktif:

```sql
CONN monuser/oracle@localhost:1521/pdb1.localdomain

UPDATE lock_test
SET nama = 'TRANSAKSI AKTIF'
WHERE id = 1;
```

Contoh output:

```text
1 row updated.
```

Jangan commit.

Monitoring dari SYS:

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

COLUMN username FORMAT A15

SELECT s.sid,
       s.serial#,
       s.username,
       t.start_time,
       t.used_ublk,
       t.used_urec
FROM v$transaction t
JOIN v$session s
ON t.ses_addr = s.saddr;
```

Contoh output:

```text
       SID    SERIAL# USERNAME        START_TIME           USED_UBLK  USED_UREC
---------- ---------- --------------- -------------------- ---------- ----------
        85      11221 MONUSER         07/04/26 16:10:31           1          1
```

Rollback transaksi:

```sql
CONN monuser/oracle@localhost:1521/pdb1.localdomain

ROLLBACK;
```

Contoh output:

```text
Rollback complete.
```

Verifikasi:

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

SELECT s.sid,
       s.username,
       t.used_ublk,
       t.used_urec
FROM v$transaction t
JOIN v$session s
ON t.ses_addr = s.saddr;
```

Contoh output:

```text
no rows selected
```

---

# LAB 6 — Monitoring SQL yang Sedang Berjalan

Jalankan workload dari user:

```sql
CONN monuser/oracle@localhost:1521/pdb1.localdomain

CREATE TABLE big_monitor AS
SELECT LEVEL AS id,
       RPAD('DATA MONITORING', 300, 'X') AS keterangan
FROM dual
CONNECT BY LEVEL <= 300000;
```

Contoh output:

```text
Table created.
```

Jalankan query berat:

```sql
SELECT COUNT(*)
FROM big_monitor a, big_monitor b
WHERE a.id = b.id
AND a.id <= 100000;
```

Dari session SYS, monitoring SQL aktif:

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

COLUMN username FORMAT A15
COLUMN sql_text FORMAT A70

SELECT s.sid,
       s.serial#,
       s.username,
       s.status,
       s.sql_id,
       SUBSTR(q.sql_text,1,70) AS sql_text
FROM v$session s
JOIN v$sql q
ON s.sql_id = q.sql_id
WHERE s.username = 'MONUSER'
AND s.status = 'ACTIVE';
```

Contoh output:

```text
       SID    SERIAL# USERNAME        STATUS     SQL_ID        SQL_TEXT
---------- ---------- --------------- ---------- ------------- ------------------------------------------------------
        91      44210 MONUSER         ACTIVE     8n3s9abc123   SELECT COUNT(*) FROM big_monitor a, big_monitor b ...
```

---

# LAB 7 — Monitoring Top SQL

```sql
COLUMN sql_text FORMAT A80

SELECT sql_id,
       executions,
       buffer_gets,
       disk_reads,
       rows_processed,
       ROUND(elapsed_time/1000000,2) AS elapsed_sec,
       SUBSTR(sql_text,1,80) AS sql_text
FROM v$sql
WHERE parsing_schema_name = 'MONUSER'
ORDER BY elapsed_time DESC
FETCH FIRST 10 ROWS ONLY;
```

Contoh output:

```text
SQL_ID        EXECUTIONS BUFFER_GETS DISK_READS ROWS_PROCESSED ELAPSED_SEC SQL_TEXT
------------- ---------- ----------- ---------- -------------- ----------- ----------------------------------------
8n3s9abc123            1      240000      12000              1       12.44 SELECT COUNT(*) FROM big_monitor a...
7x1kabc999             1       85000       5000         300000        6.12 CREATE TABLE big_monitor AS SELECT...
```

Top SQL berdasarkan buffer gets:

```sql
SELECT sql_id,
       executions,
       buffer_gets,
       ROUND(buffer_gets / NULLIF(executions,0),2) AS buffer_gets_per_exec,
       SUBSTR(sql_text,1,80) AS sql_text
FROM v$sql
WHERE parsing_schema_name = 'MONUSER'
ORDER BY buffer_gets DESC
FETCH FIRST 10 ROWS ONLY;
```

Contoh output:

```text
SQL_ID        EXECUTIONS BUFFER_GETS BUFFER_GETS_PER_EXEC SQL_TEXT
------------- ---------- ----------- -------------------- ----------------------------------------
8n3s9abc123            1      240000               240000 SELECT COUNT(*) FROM big_monitor...
```

---

# LAB 8 — Monitoring Execution Plan

Ambil `SQL_ID` dari query sebelumnya, lalu ganti pada command berikut:

```sql
SELECT *
FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR('8n3s9abc123', NULL, 'ALLSTATS LAST'));
```

Contoh output:

```text
--------------------------------------------------------------------------------
| Id | Operation           | Name        | Starts | E-Rows | A-Rows | Buffers |
--------------------------------------------------------------------------------
|  0 | SELECT STATEMENT    |             |      1 |        |      1 |  240000 |
|  1 | SORT AGGREGATE      |             |      1 |      1 |      1 |  240000 |
|  2 | HASH JOIN           |             |      1 | 100000 | 100000 |  240000 |
|  3 | TABLE ACCESS FULL   | BIG_MONITOR |      1 | 100000 | 100000 |  120000 |
|  4 | TABLE ACCESS FULL   | BIG_MONITOR |      1 | 100000 | 100000 |  120000 |
--------------------------------------------------------------------------------
```

---

# LAB 9 — Monitoring Tablespace Usage

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

COLUMN tablespace_name FORMAT A20

SELECT df.tablespace_name,
       ROUND(df.total_mb,2) AS total_mb,
       ROUND(NVL(fs.free_mb,0),2) AS free_mb,
       ROUND(df.total_mb - NVL(fs.free_mb,0),2) AS used_mb,
       ROUND(((df.total_mb - NVL(fs.free_mb,0)) / df.total_mb) * 100,2) AS used_pct
FROM (
    SELECT tablespace_name,
           SUM(bytes)/1024/1024 AS total_mb
    FROM dba_data_files
    GROUP BY tablespace_name
) df
LEFT JOIN (
    SELECT tablespace_name,
           SUM(bytes)/1024/1024 AS free_mb
    FROM dba_free_space
    GROUP BY tablespace_name
) fs
ON df.tablespace_name = fs.tablespace_name
ORDER BY used_pct DESC;
```

Contoh output:

```text
TABLESPACE_NAME        TOTAL_MB    FREE_MB    USED_MB   USED_PCT
-------------------- ---------- ---------- ---------- ----------
SYSAUX                      600        120        480      80.00
USERS                       100         55         45      45.00
SYSTEM                      270         60        210      77.78
```

---

# LAB 10 — Monitoring Datafile

```sql
COLUMN file_name FORMAT A85
COLUMN tablespace_name FORMAT A20

SELECT tablespace_name,
       file_name,
       bytes/1024/1024 AS size_mb,
       autoextensible,
       maxbytes/1024/1024 AS max_mb
FROM dba_data_files
ORDER BY tablespace_name, file_name;
```

Contoh output:

```text
TABLESPACE_NAME      FILE_NAME                                                       SIZE_MB AUTOEXTENSIBLE MAX_MB
-------------------- --------------------------------------------------------------- ------- -------------- ------
SYSTEM               /u01/app/oracle/oradata/ORADB/pdb1/system01.dbf                    270 YES              32767
USERS                /u01/app/oracle/oradata/ORADB/pdb1/users01.dbf                     100 YES              32767
```

---

# LAB 11 — Monitoring TEMP Usage

```sql
COLUMN tablespace_name FORMAT A20

SELECT tablespace_name,
       used_blocks * 8 / 1024 AS used_mb,
       free_blocks * 8 / 1024 AS free_mb,
       total_blocks * 8 / 1024 AS total_mb
FROM v$sort_segment;
```

Contoh output:

```text
TABLESPACE_NAME         USED_MB    FREE_MB   TOTAL_MB
-------------------- ---------- ---------- ----------
TEMP                          0         36         36
```

Session yang memakai TEMP:

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
ORDER BY used_mb DESC;
```

Contoh output jika tidak ada pemakaian TEMP:

```text
no rows selected
```

Simulasi sort besar:

```sql
CONN monuser/oracle@localhost:1521/pdb1.localdomain

SELECT *
FROM big_monitor
ORDER BY keterangan, id;
```

Monitoring ulang dari SYS:

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

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
ORDER BY used_mb DESC;
```

Contoh output:

```text
       SID    SERIAL# USERNAME        TABLESPACE              USED_MB SEGTYPE   SQL_ID
---------- ---------- --------------- -------------------- ---------- --------- -------------
        91      44210 MONUSER         TEMP                      80.00 SORT      3d9abcx777
```

---

# LAB 12 — Monitoring UNDO Usage

```sql
COLUMN tablespace_name FORMAT A20
COLUMN status FORMAT A15

SELECT tablespace_name,
       status,
       SUM(bytes)/1024/1024 AS size_mb
FROM dba_undo_extents
GROUP BY tablespace_name, status
ORDER BY tablespace_name, status;
```

Contoh output:

```text
TABLESPACE_NAME      STATUS              SIZE_MB
-------------------- --------------- ----------
UNDOTBS1             ACTIVE                   8
UNDOTBS1             EXPIRED                 64
UNDOTBS1             UNEXPIRED               32
```

Monitoring statistik undo:

```sql
COLUMN begin_time FORMAT A20
COLUMN end_time FORMAT A20

SELECT TO_CHAR(begin_time,'YYYY-MM-DD HH24:MI:SS') AS begin_time,
       TO_CHAR(end_time,'YYYY-MM-DD HH24:MI:SS') AS end_time,
       undoblks,
       txncount,
       maxquerylen
FROM v$undostat
ORDER BY begin_time DESC
FETCH FIRST 10 ROWS ONLY;
```

Contoh output:

```text
BEGIN_TIME           END_TIME               UNDOBLKS   TXNCOUNT MAXQUERYLEN
-------------------- -------------------- ---------- ---------- -----------
2026-07-04 16:20:00  2026-07-04 16:30:00        120         45           8
```

---

# LAB 13 — Monitoring Redo Log

```sql
CONN / AS SYSDBA

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
         1          1         41        200          1 YES INACTIVE
         2          1         42        200          1 NO  CURRENT
         3          1         40        200          1 YES INACTIVE
```

Lokasi redo log:

```sql
COLUMN member FORMAT A85

SELECT group#,
       type,
       member,
       status
FROM v$logfile
ORDER BY group#, member;
```

Contoh output:

```text
    GROUP# TYPE    MEMBER                                                        STATUS
---------- ------- ------------------------------------------------------------- -------
         1 ONLINE  /u01/app/oracle/oradata/ORADB/redo01.log
         2 ONLINE  /u01/app/oracle/oradata/ORADB/redo02.log
         3 ONLINE  /u01/app/oracle/oradata/ORADB/redo03.log
```

Force log switch:

```sql
ALTER SYSTEM SWITCH LOGFILE;
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
         1         43 NO  CURRENT
         2         42 YES ACTIVE
         3         40 YES INACTIVE
```

---

# LAB 14 — Monitoring Archive Log

```sql
ARCHIVE LOG LIST;
```

Contoh output:

```text
Database log mode              Archive Mode
Automatic archival             Enabled
Archive destination            USE_DB_RECOVERY_FILE_DEST
Current log sequence           43
```

Cek archive log terakhir:

```sql
COLUMN name FORMAT A90
COLUMN first_time FORMAT A20

SELECT sequence#,
       name,
       first_time,
       deleted,
       status
FROM v$archived_log
WHERE name IS NOT NULL
ORDER BY sequence# DESC
FETCH FIRST 10 ROWS ONLY;
```

Contoh output:

```text
 SEQUENCE# NAME                                                   FIRST_TIME           DEL S
---------- ------------------------------------------------------ -------------------- --- -
        42 /u01/app/oracle/fast_recovery_area/.../o1_mf.arc       04-JUL-26            NO  A
        41 /u01/app/oracle/fast_recovery_area/.../o1_mf.arc       04-JUL-26            NO  A
```

---

# LAB 15 — Monitoring FRA

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
/u01/app/oracle/fast_recovery_area            5120        850            200              18
```

Detail penggunaan FRA:

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
ARCHIVED LOG                         12.50                      3.20              12
BACKUP PIECE                          4.10                      0.00               3
CONTROL FILE                          0.20                      0.00               1
```

---

# LAB 16 — Monitoring Memory SGA dan PGA

SGA:

```sql
COLUMN component FORMAT A35

SELECT component,
       current_size/1024/1024 AS current_mb,
       min_size/1024/1024 AS min_mb,
       max_size/1024/1024 AS max_mb
FROM v$sga_dynamic_components
WHERE current_size > 0
ORDER BY component;
```

Contoh output:

```text
COMPONENT                           CURRENT_MB     MIN_MB     MAX_MB
----------------------------------- ---------- ---------- ----------
DEFAULT buffer cache                      1104       1104       1104
shared pool                                416        416        416
large pool                                  16         16         16
```

PGA:

```sql
SELECT name,
       ROUND(value/1024/1024,2) AS value_mb
FROM v$pgastat
WHERE name IN (
  'aggregate PGA target parameter',
  'total PGA allocated',
  'total PGA inuse',
  'maximum PGA allocated',
  'cache hit percentage'
);
```

Contoh output:

```text
NAME                                      VALUE_MB
---------------------------------------- --------
aggregate PGA target parameter             500.00
total PGA allocated                        140.50
total PGA inuse                             88.20
maximum PGA allocated                      310.75
cache hit percentage                        98.90
```

---

# LAB 17 — Monitoring Resource Limit

```sql
COLUMN resource_name FORMAT A30
COLUMN limit_value FORMAT A20

SELECT resource_name,
       current_utilization,
       max_utilization,
       initial_allocation,
       limit_value
FROM v$resource_limit
ORDER BY resource_name;
```

Contoh output:

```text
RESOURCE_NAME                  CURRENT_UTILIZATION MAX_UTILIZATION INITIAL_ALLOCATION LIMIT_VALUE
------------------------------ ------------------- --------------- ------------------ -----------
processes                                      95             120                300         300
sessions                                      110             145                472         472
transactions                                    2              10                519   UNLIMITED
```

---

# LAB 18 — Monitoring Invalid Object

```sql
ALTER SESSION SET CONTAINER=PDB1;

COLUMN owner FORMAT A20
COLUMN object_name FORMAT A30
COLUMN object_type FORMAT A20

SELECT owner,
       object_name,
       object_type,
       status
FROM dba_objects
WHERE status <> 'VALID'
ORDER BY owner, object_type, object_name;
```

Contoh output:

```text
OWNER                OBJECT_NAME                    OBJECT_TYPE          STATUS
-------------------- ------------------------------ -------------------- -------
MONUSER              V_TEST                         VIEW                 INVALID
```

Jika tidak ada:

```text
no rows selected
```

---

# LAB 19 — Monitoring Alert Log dari SQL

```sql
CONN / AS SYSDBA

SELECT originating_timestamp,
       message_text
FROM v$diag_alert_ext
WHERE originating_timestamp > SYSTIMESTAMP - INTERVAL '1' HOUR
ORDER BY originating_timestamp DESC
FETCH FIRST 20 ROWS ONLY;
```

Contoh output:

```text
ORIGINATING_TIMESTAMP              MESSAGE_TEXT
---------------------------------- --------------------------------------------------
04-JUL-26 16.40.10.123000 +07:00   ALTER SYSTEM SWITCH LOGFILE
04-JUL-26 16.38.02.812000 +07:00   Pluggable database PDB1 opened read write
```

Monitoring alert log dari OS:

```bash
tail -100 /u01/app/oracle/diag/rdbms/oradb/ORADB/trace/alert_ORADB.log
```

Contoh output:

```text
ALTER SYSTEM SWITCH LOGFILE
Thread 1 advanced to log sequence 43
Completed: ALTER SYSTEM SWITCH LOGFILE
```

---

# LAB 20 — Monitoring Listener

Dari OS:

```bash
lsnrctl status
```

Contoh output:

```text
STATUS of the LISTENER
------------------------
Alias                     LISTENER
Listening Endpoints Summary...
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=localhost)(PORT=1521)))
Services Summary...
Service "ORADB" has 1 instance(s).
Service "PDB1" has 1 instance(s).
The command completed successfully
```

Cek services:

```bash
lsnrctl services
```

Contoh output:

```text
Service "PDB1" has 1 instance(s).
  Instance "ORADB", status READY, has 1 handler(s) for this service...
```

Cek port listener:

```bash
ss -tulnp | grep 1521
```

Contoh output:

```text
tcp LISTEN 0 128 127.0.0.1:1521 0.0.0.0:* users:(("tnslsnr",pid=1234,fd=8))
```

---

# LAB 21 — Monitoring Backup RMAN

Masuk RMAN:

```bash
rman target /
```

Cek backup summary:

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

Crosscheck backup:

```rman
CROSSCHECK BACKUP;
```

Contoh output:

```text
crosschecked backup piece: found to be 'AVAILABLE'
```

Cek expired backup:

```rman
LIST EXPIRED BACKUP;
```

Contoh output:

```text
specification does not match any backup in the repository
```

Keluar:

```rman
EXIT;
```

---

# LAB 22 — Monitoring dari CDB Root untuk Semua PDB

```sql
CONN / AS SYSDBA

COLUMN pdb_name FORMAT A20

SELECT p.name AS pdb_name,
       COUNT(s.sid) AS jumlah_session
FROM v$pdbs p
LEFT JOIN cdb_users u
ON p.con_id = u.con_id
LEFT JOIN v$session s
ON s.con_id = p.con_id
GROUP BY p.name
ORDER BY p.name;
```

Contoh output:

```text
PDB_NAME             JUMLAH_SESSION
-------------------- --------------
PDB$SEED                          0
PDB1                              5
```

Monitoring tablespace semua PDB:

```sql
COLUMN pdb_name FORMAT A20
COLUMN tablespace_name FORMAT A20

SELECT p.name AS pdb_name,
       df.tablespace_name,
       ROUND(SUM(df.bytes)/1024/1024,2) AS total_mb
FROM cdb_data_files df
JOIN v$pdbs p
ON df.con_id = p.con_id
GROUP BY p.name, df.tablespace_name
ORDER BY p.name, df.tablespace_name;
```

Contoh output:

```text
PDB_NAME             TABLESPACE_NAME        TOTAL_MB
-------------------- -------------------- ----------
PDB1                 SYSTEM                      270
PDB1                 SYSAUX                      600
PDB1                 USERS                       100
```

---

# LAB 23 — Membuat Query Health Check Harian

```sql
CONN / AS SYSDBA

SET LINESIZE 200
COLUMN check_name FORMAT A35
COLUMN result FORMAT A80

SELECT 'DATABASE STATUS' AS check_name,
       name || ' - ' || open_mode || ' - ' || log_mode AS result
FROM v$database
UNION ALL
SELECT 'INSTANCE STATUS',
       instance_name || ' - ' || status || ' - ' || database_status
FROM v$instance
UNION ALL
SELECT 'PDB READ WRITE COUNT',
       TO_CHAR(COUNT(*))
FROM v$pdbs
WHERE open_mode = 'READ WRITE'
UNION ALL
SELECT 'ACTIVE USER SESSION',
       TO_CHAR(COUNT(*))
FROM v$session
WHERE username IS NOT NULL
AND status = 'ACTIVE'
UNION ALL
SELECT 'FRA USED PERCENT',
       TO_CHAR(ROUND((space_used / space_limit) * 100,2)) || '%'
FROM v$recovery_file_dest;
```

Contoh output:

```text
CHECK_NAME                          RESULT
----------------------------------- ------------------------------------------------------------
DATABASE STATUS                     ORADB - READ WRITE - ARCHIVELOG
INSTANCE STATUS                     ORADB - OPEN - ACTIVE
PDB READ WRITE COUNT                1
ACTIVE USER SESSION                 2
FRA USED PERCENT                    16.60%
```

---

# LAB 24 — Cleanup Object Lab

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

DROP USER monuser CASCADE;
```

Contoh output:

```text
User dropped.
```

Verifikasi:

```sql
SELECT username
FROM dba_users
WHERE username = 'MONUSER';
```

Contoh output:

```text
no rows selected
```

---

# Ringkasan Command Monitoring Penting

Status database:

```sql
SELECT name, open_mode, log_mode FROM v$database;
```

Status instance:

```sql
SELECT instance_name, status, database_status FROM v$instance;
```

Status PDB:

```sql
SHOW PDBS;
```

Session aktif:

```sql
SELECT sid, serial#, username, status, event
FROM v$session
WHERE username IS NOT NULL;
```

Blocking session:

```sql
SELECT sid, serial#, username, blocking_session, event
FROM v$session
WHERE blocking_session IS NOT NULL;
```

Transaksi aktif:

```sql
SELECT s.sid, s.username, t.used_ublk, t.used_urec
FROM v$transaction t
JOIN v$session s ON t.ses_addr = s.saddr;
```

Top SQL:

```sql
SELECT sql_id, executions, buffer_gets, disk_reads, elapsed_time/1000000 AS elapsed_sec
FROM v$sql
ORDER BY elapsed_time DESC
FETCH FIRST 10 ROWS ONLY;
```

Tablespace usage:

```sql
SELECT df.tablespace_name,
       df.total_mb,
       fs.free_mb,
       df.total_mb - fs.free_mb AS used_mb
FROM (
  SELECT tablespace_name, SUM(bytes)/1024/1024 total_mb
  FROM dba_data_files
  GROUP BY tablespace_name
) df
JOIN (
  SELECT tablespace_name, SUM(bytes)/1024/1024 free_mb
  FROM dba_free_space
  GROUP BY tablespace_name
) fs
ON df.tablespace_name = fs.tablespace_name;
```

FRA usage:

```sql
SELECT name, space_limit, space_used, space_reclaimable
FROM v$recovery_file_dest;
```

Alert log:

```sql
SELECT originating_timestamp, message_text
FROM v$diag_alert_ext
ORDER BY originating_timestamp DESC
FETCH FIRST 20 ROWS ONLY;
```
