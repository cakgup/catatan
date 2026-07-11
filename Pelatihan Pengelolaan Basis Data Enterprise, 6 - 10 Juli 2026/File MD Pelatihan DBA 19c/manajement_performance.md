# HANDS-ON LAB

# Performance Management / Tuning Oracle 19c CDB/PDB

Asumsi:

```text
CDB     : ORADB
PDB     : PDB1
OS      : Oracle Linux
User OS : oracle
Oracle  : 19c
```

---

# 0. Persiapan Awal

Login:

```bash
su - oracle
sqlplus / as sysdba
```

Verifikasi database:

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

Masuk ke PDB:

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

# LAB 1 — Membuat Environment Performance Lab

## 1.1 Buat tablespace lab

```sql
CREATE TABLESPACE TS_PERF_LAB
DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/ts_perf_lab01.dbf'
SIZE 300M
AUTOEXTEND ON
NEXT 100M
MAXSIZE 2G;
```

Contoh output:

```text
Tablespace created.
```

## 1.2 Buat user lab

```sql
CREATE USER perfuser IDENTIFIED BY oracle
DEFAULT TABLESPACE TS_PERF_LAB
TEMPORARY TABLESPACE TEMP
QUOTA UNLIMITED ON TS_PERF_LAB;
```

Contoh output:

```text
User created.
```

## 1.3 Grant privilege

```sql
GRANT CREATE SESSION, CREATE TABLE, CREATE INDEX, CREATE VIEW, CREATE PROCEDURE
TO perfuser;
```

Contoh output:

```text
Grant succeeded.
```

## 1.4 Login sebagai user lab

```sql
CONN perfuser/oracle@localhost:1521/pdb1.localdomain
```

Contoh output:

```text
Connected.
```

---

# LAB 2 — Membuat Data Besar untuk Simulasi Tuning

## 2.1 Buat tabel transaksi

```sql
CREATE TABLE transaksi_perf (
    id              NUMBER,
    kode_cabang     VARCHAR2(10),
    kode_produk     VARCHAR2(20),
    status_trans    VARCHAR2(20),
    tanggal_trans   DATE,
    nilai_trans     NUMBER,
    keterangan      VARCHAR2(200)
);
```

Contoh output:

```text
Table created.
```

## 2.2 Insert data besar

```sql
INSERT INTO transaksi_perf
SELECT LEVEL AS id,
       'CBG' || MOD(LEVEL, 20) AS kode_cabang,
       'PRD' || MOD(LEVEL, 100) AS kode_produk,
       CASE MOD(LEVEL, 4)
            WHEN 0 THEN 'NEW'
            WHEN 1 THEN 'PAID'
            WHEN 2 THEN 'CANCEL'
            ELSE 'FAILED'
       END AS status_trans,
       TRUNC(SYSDATE) - MOD(LEVEL, 365) AS tanggal_trans,
       MOD(LEVEL, 100000) AS nilai_trans,
       RPAD('DATA TRANSAKSI PERFORMANCE TEST', 200, 'X') AS keterangan
FROM dual
CONNECT BY LEVEL <= 500000;

COMMIT;
```

Contoh output:

```text
500000 rows created.

Commit complete.
```

## 2.3 Verifikasi jumlah data

```sql
SELECT COUNT(*) FROM transaksi_perf;
```

Contoh output:

```text
  COUNT(*)
----------
    500000
```

## 2.4 Kumpulkan statistik awal

```sql
BEGIN
  DBMS_STATS.GATHER_TABLE_STATS(
    ownname => 'PERFUSER',
    tabname => 'TRANSAKSI_PERF',
    cascade => TRUE
  );
END;
/
```

Contoh output:

```text
PL/SQL procedure successfully completed.
```

---

# LAB 3 — Baseline Monitoring Session dan SQL

## 3.1 Cek session aktif

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

COLUMN username FORMAT A15
COLUMN event FORMAT A40
COLUMN status FORMAT A10

SELECT sid,
       serial#,
       username,
       status,
       event,
       wait_class
FROM v$session
WHERE username IS NOT NULL
ORDER BY username;
```

Contoh output:

```text
       SID    SERIAL# USERNAME        STATUS     EVENT                                    WAIT_CLASS
---------- ---------- --------------- ---------- ---------------------------------------- ----------
        82      28411 PERFUSER        INACTIVE   SQL*Net message from client              Idle
```

## 3.2 Cek SQL yang menghabiskan resource

```sql
COLUMN sql_text FORMAT A80

SELECT sql_id,
       executions,
       buffer_gets,
       disk_reads,
       rows_processed,
       elapsed_time/1000000 AS elapsed_sec,
       SUBSTR(sql_text,1,80) AS sql_text
FROM v$sql
WHERE parsing_schema_name = 'PERFUSER'
ORDER BY elapsed_time DESC
FETCH FIRST 10 ROWS ONLY;
```

Contoh output:

```text
SQL_ID        EXECUTIONS BUFFER_GETS DISK_READS ROWS_PROCESSED ELAPSED_SEC SQL_TEXT
------------- ---------- ----------- ---------- -------------- ----------- ------------------------------
9f2k3x8abcde1          1      850000      12000         500000       12.31 SELECT COUNT(*) ...
```

---

# LAB 4 — Kasus 1: Query Lambat karena Full Table Scan

## 4.1 Jalankan query tanpa index

Login sebagai `perfuser`.

```sql
CONN perfuser/oracle@localhost:1521/pdb1.localdomain

SET TIMING ON
SET AUTOTRACE TRACEONLY EXPLAIN STATISTICS

SELECT *
FROM transaksi_perf
WHERE kode_produk = 'PRD50'
AND status_trans = 'PAID';
```

Contoh output:

```text
Elapsed: 00:00:04.82

Execution Plan
----------------------------------------------------------
| Id | Operation         | Name           | Rows  |
----------------------------------------------------------
|  0 | SELECT STATEMENT  |                |  1250 |
|  1 | TABLE ACCESS FULL | TRANSAKSI_PERF |  1250 |
----------------------------------------------------------

Statistics
----------------------------------------------------------
  85000 consistent gets
  12000 physical reads
```

Matikan autotrace:

```sql
SET AUTOTRACE OFF
```

## 4.2 Lihat execution plan dari cursor

```sql
SELECT *
FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST'));
```

Contoh output:

```text
--------------------------------------------------------------------------------
| Id | Operation         | Name           | Starts | E-Rows | A-Rows | Buffers |
--------------------------------------------------------------------------------
|  0 | SELECT STATEMENT  |                |      1 |        |   1250 |   85000 |
|  1 | TABLE ACCESS FULL | TRANSAKSI_PERF |      1 |   1250 |   1250 |   85000 |
--------------------------------------------------------------------------------
```

Masalah:

```text
Query menggunakan TABLE ACCESS FULL.
Oracle membaca banyak block untuk mencari data yang sedikit.
```

## 4.3 Tuning: buat index composite

```sql
CREATE INDEX idx_trx_produk_status
ON transaksi_perf(kode_produk, status_trans);
```

Contoh output:

```text
Index created.
```

## 4.4 Gather stats ulang

```sql
BEGIN
  DBMS_STATS.GATHER_TABLE_STATS(
    ownname => 'PERFUSER',
    tabname => 'TRANSAKSI_PERF',
    cascade => TRUE
  );
END;
/
```

Contoh output:

```text
PL/SQL procedure successfully completed.
```

## 4.5 Jalankan ulang query

```sql
SET TIMING ON
SET AUTOTRACE TRACEONLY EXPLAIN STATISTICS

SELECT *
FROM transaksi_perf
WHERE kode_produk = 'PRD50'
AND status_trans = 'PAID';
```

Contoh output setelah tuning:

```text
Elapsed: 00:00:00.18

Execution Plan
---------------------------------------------------------------------------
| Id | Operation                           | Name                  | Rows |
---------------------------------------------------------------------------
|  0 | SELECT STATEMENT                    |                       | 1250 |
|  1 | TABLE ACCESS BY INDEX ROWID BATCHED | TRANSAKSI_PERF        | 1250 |
|  2 | INDEX RANGE SCAN                    | IDX_TRX_PRODUK_STATUS | 1250 |
---------------------------------------------------------------------------

Statistics
----------------------------------------------------------
  3700 consistent gets
  150 physical reads
```

## 4.6 Kesimpulan improvement

```text
Sebelum tuning:
Elapsed time     : sekitar 4.82 detik
Consistent gets  : sekitar 85000
Plan             : TABLE ACCESS FULL

Sesudah tuning:
Elapsed time     : sekitar 0.18 detik
Consistent gets  : sekitar 3700
Plan             : INDEX RANGE SCAN
```

---

# LAB 5 — Kasus 2: Query Lambat karena Function pada Kolom Indexed

## 5.1 Buat index tanggal

```sql
CREATE INDEX idx_trx_tanggal
ON transaksi_perf(tanggal_trans);
```

Contoh output:

```text
Index created.
```

Gather stats:

```sql
BEGIN
  DBMS_STATS.GATHER_TABLE_STATS(
    ownname => 'PERFUSER',
    tabname => 'TRANSAKSI_PERF',
    cascade => TRUE
  );
END;
/
```

## 5.2 Query buruk: menggunakan fungsi pada kolom

```sql
SET AUTOTRACE TRACEONLY EXPLAIN STATISTICS
SET TIMING ON

SELECT COUNT(*)
FROM transaksi_perf
WHERE TO_CHAR(tanggal_trans, 'YYYY-MM-DD') = TO_CHAR(TRUNC(SYSDATE)-10, 'YYYY-MM-DD');
```

Contoh output:

```text
Elapsed: 00:00:03.20

Execution Plan
----------------------------------------------------------
| Id | Operation         | Name           |
----------------------------------------------------------
|  0 | SELECT STATEMENT  |                |
|  1 | SORT AGGREGATE    |                |
|  2 | TABLE ACCESS FULL | TRANSAKSI_PERF |
----------------------------------------------------------

Statistics
----------------------------------------------------------
  82000 consistent gets
```

Masalah:

```text
Kolom tanggal_trans sudah punya index.
Tetapi karena kolom dibungkus fungsi TO_CHAR(), index sulit digunakan.
```

## 5.3 Tuning: ubah predicate menjadi range

```sql
SELECT COUNT(*)
FROM transaksi_perf
WHERE tanggal_trans >= TRUNC(SYSDATE)-10
AND tanggal_trans <  TRUNC(SYSDATE)-9;
```

Contoh output:

```text
Elapsed: 00:00:00.05

Execution Plan
----------------------------------------------------------------------------
| Id | Operation         | Name            |
----------------------------------------------------------------------------
|  0 | SELECT STATEMENT  |                 |
|  1 | SORT AGGREGATE    |                 |
|  2 | INDEX RANGE SCAN  | IDX_TRX_TANGGAL |
----------------------------------------------------------------------------

Statistics
----------------------------------------------------------
  12 consistent gets
```

## 5.4 Alternatif tuning: function-based index

Jika query aplikasi sulit diubah, buat function-based index.

```sql
CREATE INDEX idx_trx_tanggal_char
ON transaksi_perf(TO_CHAR(tanggal_trans, 'YYYY-MM-DD'));
```

Contoh output:

```text
Index created.
```

Gather stats:

```sql
BEGIN
  DBMS_STATS.GATHER_TABLE_STATS(
    ownname => 'PERFUSER',
    tabname => 'TRANSAKSI_PERF',
    cascade => TRUE
  );
END;
/
```

Jalankan query awal lagi:

```sql
SELECT COUNT(*)
FROM transaksi_perf
WHERE TO_CHAR(tanggal_trans, 'YYYY-MM-DD') = TO_CHAR(TRUNC(SYSDATE)-10, 'YYYY-MM-DD');
```

Contoh output:

```text
Execution Plan
--------------------------------------------------------------------------------
| Id | Operation        | Name                 |
--------------------------------------------------------------------------------
|  0 | SELECT STATEMENT |                      |
|  1 | SORT AGGREGATE   |                      |
|  2 | INDEX RANGE SCAN | IDX_TRX_TANGGAL_CHAR |
--------------------------------------------------------------------------------
```

---

# LAB 6 — Kasus 3: Statistik Tidak Akurat

## 6.1 Buat tabel baru

```sql
CREATE TABLE trx_stat_bad AS
SELECT *
FROM transaksi_perf
WHERE id <= 10000;
```

Contoh output:

```text
Table created.
```

## 6.2 Kumpulkan statistik saat data masih kecil

```sql
BEGIN
  DBMS_STATS.GATHER_TABLE_STATS(
    ownname => 'PERFUSER',
    tabname => 'TRX_STAT_BAD'
  );
END;
/
```

Contoh output:

```text
PL/SQL procedure successfully completed.
```

## 6.3 Tambahkan data besar setelah statistik dibuat

```sql
INSERT INTO trx_stat_bad
SELECT *
FROM transaksi_perf
WHERE id > 10000;

COMMIT;
```

Contoh output:

```text
490000 rows created.

Commit complete.
```

## 6.4 Cek jumlah real data

```sql
SELECT COUNT(*) FROM trx_stat_bad;
```

Contoh output:

```text
  COUNT(*)
----------
    500000
```

## 6.5 Cek statistik tabel

```sql
COLUMN table_name FORMAT A20

SELECT table_name,
       num_rows,
       blocks,
       last_analyzed
FROM user_tables
WHERE table_name = 'TRX_STAT_BAD';
```

Contoh output:

```text
TABLE_NAME              NUM_ROWS     BLOCKS LAST_ANALYZED
-------------------- ---------- ---------- ------------------
TRX_STAT_BAD              10000        150  04-JUL-26
```

Masalah:

```text
Data aktual 500000 row.
Statistik Oracle masih mengira 10000 row.
Optimizer dapat memilih execution plan yang kurang tepat.
```

## 6.6 Tuning: gather stats ulang

```sql
BEGIN
  DBMS_STATS.GATHER_TABLE_STATS(
    ownname => 'PERFUSER',
    tabname => 'TRX_STAT_BAD',
    cascade => TRUE
  );
END;
/
```

Contoh output:

```text
PL/SQL procedure successfully completed.
```

## 6.7 Verifikasi statistik membaik

```sql
SELECT table_name,
       num_rows,
       blocks,
       last_analyzed
FROM user_tables
WHERE table_name = 'TRX_STAT_BAD';
```

Contoh output:

```text
TABLE_NAME              NUM_ROWS     BLOCKS LAST_ANALYZED
-------------------- ---------- ---------- ------------------
TRX_STAT_BAD             500000       8500  04-JUL-26
```

---

# LAB 7 — Kasus 4: Sort Besar Menggunakan TEMP

## 7.1 Cek temporary tablespace

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

SELECT tablespace_name,
       file_name,
       bytes/1024/1024 AS size_mb,
       autoextensible
FROM dba_temp_files;
```

Contoh output:

```text
TABLESPACE_NAME FILE_NAME                                      SIZE_MB AUTOEXTENSIBLE
--------------- ---------------------------------------------- ------- --------------
TEMP            /u01/app/oracle/oradata/ORADB/pdb1/temp01.dbf      36 YES
```

## 7.2 Jalankan query sort berat

Session 1:

```sql
CONN perfuser/oracle@localhost:1521/pdb1.localdomain

SET TIMING ON

SELECT *
FROM transaksi_perf
ORDER BY keterangan, nilai_trans, tanggal_trans;
```

Contoh output:

```text
Elapsed: 00:00:18.42
```

## 7.3 Monitoring TEMP dari session lain

Session 2:

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

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

Contoh output:

```text
       SID    SERIAL# USERNAME        TABLESPACE              USED_MB SEGTYPE   SQL_ID
---------- ---------- --------------- -------------------- ---------- --------- -------------
        92      31551 PERFUSER        TEMP                     180.00 SORT      9abcd123xyz
```

## 7.4 Cek PGA policy

```sql
SHOW PARAMETER pga_aggregate_target
SHOW PARAMETER workarea_size_policy
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- --------
pga_aggregate_target                 big integer 300M

NAME                                 TYPE        VALUE
------------------------------------ ----------- --------
workarea_size_policy                 string      AUTO
```

## 7.5 Tuning opsi 1: tambah kapasitas TEMP

```sql
ALTER TABLESPACE TEMP
ADD TEMPFILE '/u01/app/oracle/oradata/ORADB/pdb1/temp02_perf.dbf'
SIZE 300M
AUTOEXTEND ON
NEXT 100M
MAXSIZE 2G;
```

Contoh output:

```text
Tablespace altered.
```

Verifikasi:

```sql
SELECT tablespace_name,
       file_name,
       bytes/1024/1024 AS size_mb,
       autoextensible
FROM dba_temp_files
ORDER BY file_name;
```

Contoh output:

```text
TABLESPACE_NAME FILE_NAME                                             SIZE_MB AUTOEXTENSIBLE
--------------- ----------------------------------------------------- ------- --------------
TEMP            /u01/app/oracle/oradata/ORADB/pdb1/temp01.dbf             36 YES
TEMP            /u01/app/oracle/oradata/ORADB/pdb1/temp02_perf.dbf       300 YES
```

## 7.6 Tuning opsi 2: tambah PGA target

Jalankan dari CDB root:

```sql
CONN / AS SYSDBA

ALTER SYSTEM SET pga_aggregate_target = 1G SCOPE=BOTH;
```

Contoh output:

```text
System altered.
```

Verifikasi:

```sql
SHOW PARAMETER pga_aggregate_target
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- -----
pga_aggregate_target                 big integer 1G
```

## 7.7 Jalankan ulang query sort

```sql
CONN perfuser/oracle@localhost:1521/pdb1.localdomain

SET TIMING ON

SELECT *
FROM transaksi_perf
ORDER BY keterangan, nilai_trans, tanggal_trans;
```

Contoh output setelah tuning:

```text
Elapsed: 00:00:09.80
```

Improvement:

```text
Sebelum tuning : sekitar 18.42 detik
Sesudah tuning : sekitar 9.80 detik

Catatan:
Hasil tergantung ukuran RAM, disk, dan jumlah data.
```

---

# LAB 8 — Kasus 5: Query Lambat karena SELECT Kolom Terlalu Banyak

## 8.1 Query buruk: ambil semua kolom

```sql
SET TIMING ON
SET AUTOTRACE TRACEONLY EXPLAIN STATISTICS

SELECT *
FROM transaksi_perf
WHERE kode_produk = 'PRD10';
```

Contoh output:

```text
Elapsed: 00:00:01.90

Statistics
----------------------------------------------------------
  12500 consistent gets
  5000 rows processed
```

## 8.2 Tuning: ambil kolom yang diperlukan saja

```sql
SELECT id, kode_produk, status_trans, nilai_trans
FROM transaksi_perf
WHERE kode_produk = 'PRD10';
```

Contoh output:

```text
Elapsed: 00:00:00.43

Statistics
----------------------------------------------------------
  5100 consistent gets
  5000 rows processed
```

## 8.3 Tuning lanjut: covering index

```sql
CREATE INDEX idx_trx_cover_produk
ON transaksi_perf(kode_produk, id, status_trans, nilai_trans);
```

Contoh output:

```text
Index created.
```

Gather stats:

```sql
BEGIN
  DBMS_STATS.GATHER_TABLE_STATS(
    ownname => 'PERFUSER',
    tabname => 'TRANSAKSI_PERF',
    cascade => TRUE
  );
END;
/
```

Jalankan ulang:

```sql
SELECT id, kode_produk, status_trans, nilai_trans
FROM transaksi_perf
WHERE kode_produk = 'PRD10';
```

Contoh output:

```text
Execution Plan
----------------------------------------------------------------------------
| Id | Operation        | Name                  |
----------------------------------------------------------------------------
|  0 | SELECT STATEMENT |                       |
|  1 | INDEX RANGE SCAN | IDX_TRX_COVER_PRODUK  |
----------------------------------------------------------------------------

Statistics
----------------------------------------------------------
  210 consistent gets
```

---

# LAB 9 — Kasus 6: Locking dan Blocking Session

## 9.1 Session 1: update tanpa commit

```sql
CONN perfuser/oracle@localhost:1521/pdb1.localdomain

UPDATE transaksi_perf
SET nilai_trans = nilai_trans + 1
WHERE id = 100;
```

Contoh output:

```text
1 row updated.
```

Jangan `COMMIT`.

## 9.2 Session 2: update row yang sama

```sql
CONN perfuser/oracle@localhost:1521/pdb1.localdomain

UPDATE transaksi_perf
SET nilai_trans = nilai_trans + 10
WHERE id = 100;
```

Session ini akan menggantung.

## 9.3 Session 3: monitoring blocking

```sql
CONN / AS SYSDBA
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
WHERE username = 'PERFUSER';
```

Contoh output:

```text
       SID    SERIAL# USERNAME        BLOCKING_SESSION EVENT                               SECONDS_IN_WAIT
---------- ---------- --------------- ---------------- ----------------------------------- ---------------
        91      20210 PERFUSER                         SQL*Net message from client                       35
        94      18542 PERFUSER                       91 enq: TX - row lock contention                    30
```

## 9.4 Tuning / solusi

Di session 1:

```sql
COMMIT;
```

Contoh output:

```text
Commit complete.
```

Session 2 akan lanjut.

## 9.5 Verifikasi tidak ada blocking

```sql
SELECT sid,
       serial#,
       username,
       blocking_session,
       event
FROM v$session
WHERE username = 'PERFUSER';
```

Contoh output:

```text
       SID    SERIAL# USERNAME        BLOCKING_SESSION EVENT
---------- ---------- --------------- ---------------- ------------------------------
        91      20210 PERFUSER                         SQL*Net message from client
        94      18542 PERFUSER                         SQL*Net message from client
```

---

# LAB 10 — Kasus 7: Banyak Hard Parse karena Literal SQL

## 10.1 Jalankan banyak SQL literal

```sql
CONN perfuser/oracle@localhost:1521/pdb1.localdomain

BEGIN
  FOR i IN 1..1000 LOOP
    EXECUTE IMMEDIATE
      'SELECT COUNT(*) FROM transaksi_perf WHERE id = ' || i;
  END LOOP;
END;
/
```

Contoh output:

```text
PL/SQL procedure successfully completed.
```

## 10.2 Monitoring SQL mirip tapi berbeda literal

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

SELECT COUNT(*) AS jumlah_sql_mirip
FROM v$sql
WHERE sql_text LIKE 'SELECT COUNT(*) FROM transaksi_perf WHERE id =%';
```

Contoh output:

```text
JUMLAH_SQL_MIRIP
----------------
            1000
```

Masalah:

```text
Banyak SQL berbeda karena literal value.
Ini dapat meningkatkan hard parse dan shared pool usage.
```

## 10.3 Tuning: gunakan bind variable

```sql
CONN perfuser/oracle@localhost:1521/pdb1.localdomain

DECLARE
  v_count NUMBER;
BEGIN
  FOR i IN 1..1000 LOOP
    EXECUTE IMMEDIATE
      'SELECT COUNT(*) FROM transaksi_perf WHERE id = :b1'
      INTO v_count
      USING i;
  END LOOP;
END;
/
```

Contoh output:

```text
PL/SQL procedure successfully completed.
```

## 10.4 Verifikasi SQL bind lebih sedikit

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

SELECT sql_text,
       executions,
       parse_calls
FROM v$sql
WHERE sql_text LIKE 'SELECT COUNT(*) FROM transaksi_perf WHERE id = :b1%';
```

Contoh output:

```text
SQL_TEXT                                                   EXECUTIONS PARSE_CALLS
---------------------------------------------------------- ---------- -----------
SELECT COUNT(*) FROM transaksi_perf WHERE id = :b1              1000           1
```

---

# LAB 11 — Membaca Top Wait Event di PDB

## 11.1 Cek wait event session

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

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
EVENT                               WAIT_CLASS      JUMLAH_SESSION
----------------------------------- --------------- --------------
SQL*Net message from client         Idle                         3
db file sequential read             User I/O                     1
enq: TX - row lock contention        Application                  1
```

## 11.2 Cek system event

```sql
SELECT event,
       total_waits,
       time_waited/100 AS time_waited_sec
FROM v$system_event
WHERE wait_class <> 'Idle'
ORDER BY time_waited DESC
FETCH FIRST 10 ROWS ONLY;
```

Contoh output:

```text
EVENT                          TOTAL_WAITS TIME_WAITED_SEC
------------------------------ ----------- ---------------
db file sequential read              12500          320.15
db file scattered read                1800          110.30
log file sync                         9000           75.80
```

Interpretasi singkat:

```text
db file sequential read  : biasanya index lookup / single block read
db file scattered read   : biasanya full table scan / multiblock read
log file sync            : commit menunggu redo flush
enq: TX row lock         : blocking antar transaksi
```

---

# LAB 12 — Menggunakan SQL Monitor untuk Query Berat

SQL Monitor biasanya aktif untuk query yang berjalan cukup lama atau parallel.

## 12.1 Jalankan query berat

```sql
CONN perfuser/oracle@localhost:1521/pdb1.localdomain

SELECT COUNT(*)
FROM transaksi_perf a, transaksi_perf b
WHERE a.kode_produk = b.kode_produk
AND a.id <= 2000
AND b.id <= 2000;
```

Contoh output:

```text
  COUNT(*)
----------
     40000
```

## 12.2 Lihat SQL_ID terakhir

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

SELECT sql_id,
       status,
       sql_text
FROM v$sql_monitor
WHERE username = 'PERFUSER'
ORDER BY last_refresh_time DESC
FETCH FIRST 5 ROWS ONLY;
```

Contoh output:

```text
SQL_ID        STATUS     SQL_TEXT
------------- ---------- ------------------------------------------------
8h2xk9abc123  DONE       SELECT COUNT(*) FROM transaksi_perf a, transaksi_perf b ...
```

---

# LAB 13 — Membuat AWR Snapshot

AWR tersedia jika lisensi Diagnostic Pack digunakan.

## 13.1 Cek snapshot existing

```sql
CONN / AS SYSDBA

SELECT snap_id,
       begin_interval_time,
       end_interval_time
FROM dba_hist_snapshot
ORDER BY snap_id DESC
FETCH FIRST 5 ROWS ONLY;
```

Contoh output:

```text
   SNAP_ID BEGIN_INTERVAL_TIME              END_INTERVAL_TIME
---------- -------------------------------- --------------------------------
       101 04-JUL-26 10.00.00.000 AM       04-JUL-26 11.00.00.000 AM
```

## 13.2 Buat snapshot sebelum workload

```sql
EXEC DBMS_WORKLOAD_REPOSITORY.CREATE_SNAPSHOT;
```

Contoh output:

```text
PL/SQL procedure successfully completed.
```

## 13.3 Jalankan workload

```sql
CONN perfuser/oracle@localhost:1521/pdb1.localdomain

BEGIN
  FOR i IN 1..20 LOOP
    FOR r IN (
      SELECT COUNT(*) c
      FROM transaksi_perf
      WHERE kode_produk = 'PRD50'
      AND status_trans = 'PAID'
    ) LOOP
      NULL;
    END LOOP;
  END LOOP;
END;
/
```

Contoh output:

```text
PL/SQL procedure successfully completed.
```

## 13.4 Buat snapshot sesudah workload

```sql
CONN / AS SYSDBA

EXEC DBMS_WORKLOAD_REPOSITORY.CREATE_SNAPSHOT;
```

Contoh output:

```text
PL/SQL procedure successfully completed.
```

## 13.5 Cek snapshot terbaru

```sql
SELECT snap_id,
       begin_interval_time,
       end_interval_time
FROM dba_hist_snapshot
ORDER BY snap_id DESC
FETCH FIRST 2 ROWS ONLY;
```

Contoh output:

```text
   SNAP_ID BEGIN_INTERVAL_TIME              END_INTERVAL_TIME
---------- -------------------------------- --------------------------------
       103 04-JUL-26 11.20.00.000 AM       04-JUL-26 11.30.00.000 AM
       102 04-JUL-26 11.10.00.000 AM       04-JUL-26 11.20.00.000 AM
```

---

# LAB 14 — Generate AWR Report

Dari OS:

```bash
sqlplus / as sysdba
```

Jalankan script AWR:

```sql
@$ORACLE_HOME/rdbms/admin/awrrpt.sql
```

Input contoh:

```text
Enter value for report_type: html
Enter value for num_days: 1
Enter value for begin_snap: 102
Enter value for end_snap: 103
Enter value for report_name: awr_perf_lab.html
```

Verifikasi file:

```bash
ls -lh awr_perf_lab.html
```

Contoh output:

```text
-rw-r--r--. 1 oracle oinstall 420K Jul 4 12:00 awr_perf_lab.html
```

Yang dicari di AWR:

```text
Top SQL by Elapsed Time
Top SQL by Buffer Gets
Top Timed Events
Load Profile
Instance Efficiency Percentages
```

---

# LAB 15 — Menggunakan SQL Tuning Advisor

SQL Tuning Advisor membutuhkan Tuning Pack.

## 15.1 Ambil SQL_ID query berat

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

SELECT sql_id,
       elapsed_time/1000000 AS elapsed_sec,
       buffer_gets,
       SUBSTR(sql_text,1,80) AS sql_text
FROM v$sql
WHERE parsing_schema_name = 'PERFUSER'
ORDER BY elapsed_time DESC
FETCH FIRST 5 ROWS ONLY;
```

Contoh output:

```text
SQL_ID        ELAPSED_SEC BUFFER_GETS SQL_TEXT
------------- ----------- ----------- ----------------------------------------
9f2k3x8abcde1       12.31      850000 SELECT * FROM transaksi_perf WHERE ...
```

## 15.2 Buat tuning task

Ganti SQL_ID sesuai hasil Anda.

```sql
DECLARE
  v_task VARCHAR2(100);
BEGIN
  v_task := DBMS_SQLTUNE.CREATE_TUNING_TASK(
              sql_id      => '9f2k3x8abcde1',
              scope       => DBMS_SQLTUNE.SCOPE_COMPREHENSIVE,
              time_limit  => 60,
              task_name   => 'TASK_TUNE_PERF_LAB'
            );
END;
/
```

Contoh output:

```text
PL/SQL procedure successfully completed.
```

## 15.3 Execute tuning task

```sql
EXEC DBMS_SQLTUNE.EXECUTE_TUNING_TASK(task_name => 'TASK_TUNE_PERF_LAB');
```

Contoh output:

```text
PL/SQL procedure successfully completed.
```

## 15.4 Lihat rekomendasi

```sql
SET LONG 100000
SET LONGCHUNKSIZE 100000
SET LINESIZE 200

SELECT DBMS_SQLTUNE.REPORT_TUNING_TASK('TASK_TUNE_PERF_LAB')
FROM dual;
```

Contoh output:

```text
GENERAL INFORMATION SECTION
-------------------------------------------------------------------------------
Tuning Task Name   : TASK_TUNE_PERF_LAB

FINDINGS SECTION
-------------------------------------------------------------------------------
1- Index Finding
   The execution plan of this statement can be improved by creating one or more
   indices.

RECOMMENDATION
-------------------------------------------------------------------------------
CREATE INDEX PERFUSER.IDX_... ON PERFUSER.TRANSAKSI_PERF(...);
```

---

# LAB 16 — Membandingkan Sebelum dan Sesudah Tuning dari V$SQL

## 16.1 Jalankan query setelah tuning beberapa kali

```sql
CONN perfuser/oracle@localhost:1521/pdb1.localdomain

BEGIN
  FOR i IN 1..10 LOOP
    FOR r IN (
      SELECT COUNT(*) c
      FROM transaksi_perf
      WHERE kode_produk = 'PRD50'
      AND status_trans = 'PAID'
    ) LOOP
      NULL;
    END LOOP;
  END LOOP;
END;
/
```

## 16.2 Cek metrik SQL

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

COLUMN sql_text FORMAT A70

SELECT sql_id,
       executions,
       ROUND(elapsed_time/1000000,2) AS elapsed_sec_total,
       ROUND((elapsed_time/1000000)/NULLIF(executions,0),4) AS elapsed_sec_per_exec,
       buffer_gets,
       ROUND(buffer_gets/NULLIF(executions,0),2) AS buffer_gets_per_exec,
       disk_reads
FROM v$sql
WHERE parsing_schema_name = 'PERFUSER'
AND sql_text LIKE '%kode_produk = ''PRD50''%'
ORDER BY last_active_time DESC
FETCH FIRST 5 ROWS ONLY;
```

Contoh output:

```text
SQL_ID        EXECUTIONS ELAPSED_SEC_TOTAL ELAPSED_SEC_PER_EXEC BUFFER_GETS BUFFER_GETS_PER_EXEC DISK_READS
------------- ---------- ----------------- -------------------- ----------- -------------------- ----------
abc123xyz              10              1.5                0.15       37000                 3700        150
```

---

# LAB 17 — Resource Manager Sederhana di PDB

Resource Manager biasanya dikelola dari CDB root untuk mengatur prioritas antar PDB.

## 17.1 Cek PDB resource plan

```sql
CONN / AS SYSDBA

SHOW PARAMETER resource_manager_plan
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
resource_manager_plan                string
```

## 17.2 Cek resource usage per PDB

```sql
COLUMN name FORMAT A20

SELECT p.name,
       s.cpu_consumed_time,
       s.cpu_wait_time,
       s.io_requests,
       s.io_megabytes
FROM v$rsrcpdbmetric s
JOIN v$pdbs p
ON s.con_id = p.con_id
ORDER BY p.name;
```

Contoh output:

```text
NAME                 CPU_CONSUMED_TIME CPU_WAIT_TIME IO_REQUESTS IO_MEGABYTES
-------------------- ----------------- ------------- ----------- ------------
PDB1                              1520             0        2050          350
```

---

# LAB 18 — Cleanup Object Performance Lab

Jalankan setelah semua lab selesai.

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

DROP USER perfuser CASCADE;
DROP TABLESPACE TS_PERF_LAB INCLUDING CONTENTS AND DATAFILES;
```

Contoh output:

```text
User dropped.

Tablespace dropped.
```

Jika tadi menambahkan tempfile lab:

```sql
ALTER DATABASE TEMPFILE
'/u01/app/oracle/oradata/ORADB/pdb1/temp02_perf.dbf'
DROP INCLUDING DATAFILES;
```

Contoh output:

```text
Database altered.
```

Kembalikan PGA jika sebelumnya dinaikkan:

```sql
CONN / AS SYSDBA

ALTER SYSTEM SET pga_aggregate_target = 300M SCOPE=BOTH;
```

Contoh output:

```text
System altered.
```

---

# Ringkasan Kasus Performance

| Kasus                       | Gejala                           | Penyebab               | Tuning                                   |
| --------------------------- | -------------------------------- | ---------------------- | ---------------------------------------- |
| Full table scan             | Query lambat, buffer gets tinggi | Tidak ada index        | Buat index sesuai predicate              |
| Function pada kolom         | Index tidak digunakan            | Kolom dibungkus fungsi | Rewrite predicate / function-based index |
| Statistik buruk             | Plan tidak optimal               | Stats tidak update     | `DBMS_STATS.GATHER_TABLE_STATS`          |
| Sort berat                  | TEMP tinggi                      | Sort besar / PGA kecil | Tambah TEMP / tuning PGA / ubah query    |
| SELECT terlalu banyak kolom | I/O tinggi                       | Ambil data tidak perlu | Ambil kolom spesifik / covering index    |
| Blocking session            | Session menggantung              | Row lock               | Commit/rollback blocker                  |
| Hard parse tinggi           | Shared pool berat                | Literal SQL            | Bind variable                            |

---

# Command Monitoring Penting

Top SQL:

```sql
SELECT sql_id,
       executions,
       buffer_gets,
       disk_reads,
       elapsed_time/1000000 AS elapsed_sec,
       SUBSTR(sql_text,1,80) AS sql_text
FROM v$sql
ORDER BY elapsed_time DESC
FETCH FIRST 10 ROWS ONLY;
```

Session wait:

```sql
SELECT sid,
       serial#,
       username,
       event,
       wait_class,
       seconds_in_wait
FROM v$session
WHERE username IS NOT NULL;
```

Blocking session:

```sql
SELECT sid,
       serial#,
       username,
       blocking_session,
       event
FROM v$session
WHERE blocking_session IS NOT NULL;
```

TEMP usage:

```sql
SELECT s.sid,
       s.serial#,
       s.username,
       u.tablespace,
       u.blocks * 8 / 1024 AS used_mb,
       u.segtype,
       u.sql_id
FROM v$tempseg_usage u
JOIN v$session s
ON u.session_addr = s.saddr;
```

Execution plan:

```sql
SELECT *
FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST'));
```

AWR snapshot:

```sql
EXEC DBMS_WORKLOAD_REPOSITORY.CREATE_SNAPSHOT;
```

AWR report:

```sql
@$ORACLE_HOME/rdbms/admin/awrrpt.sql
```
