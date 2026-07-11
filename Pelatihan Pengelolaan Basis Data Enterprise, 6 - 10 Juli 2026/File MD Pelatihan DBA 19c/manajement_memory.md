# HANDS-ON LAB

# Memory Management Oracle 19c CDB/PDB

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

Login sebagai user `oracle`.

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

Verifikasi container:

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

# LAB 1 — Melihat Parameter Memory Utama

Jalankan dari `CDB$ROOT`.

```sql
SHOW PARAMETER memory
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
memory_max_target                    big integer 0
memory_target                        big integer 0
```

Cek parameter SGA:

```sql
SHOW PARAMETER sga
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
sga_max_size                         big integer 1600M
sga_target                           big integer 1600M
```

Cek parameter PGA:

```sql
SHOW PARAMETER pga
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
pga_aggregate_limit                  big integer 2G
pga_aggregate_target                 big integer 500M
```

---

# LAB 2 — Melihat Mode Memory Management

## 2.1 Cek apakah menggunakan AMM atau ASMM

```sql
SELECT name, value
FROM v$parameter
WHERE name IN (
  'memory_target',
  'memory_max_target',
  'sga_target',
  'sga_max_size',
  'pga_aggregate_target',
  'pga_aggregate_limit'
)
ORDER BY name;
```

Contoh output:

```text
NAME                    VALUE
----------------------- ----------
memory_max_target       0
memory_target           0
pga_aggregate_limit     2147483648
pga_aggregate_target    524288000
sga_max_size            1677721600
sga_target              1677721600
```

Interpretasi:

```text
memory_target = 0      berarti AMM tidak aktif.
sga_target > 0         berarti ASMM aktif.
pga_aggregate_target > 0 berarti PGA dikelola otomatis.
```

---

# LAB 3 — Melihat Komponen SGA

```sql
COLUMN component FORMAT A35
COLUMN current_size_mb FORMAT 999999
COLUMN min_size_mb FORMAT 999999
COLUMN max_size_mb FORMAT 999999

SELECT component,
       current_size/1024/1024 AS current_size_mb,
       min_size/1024/1024 AS min_size_mb,
       max_size/1024/1024 AS max_size_mb
FROM v$sga_dynamic_components
WHERE current_size > 0
ORDER BY component;
```

Contoh output:

```text
COMPONENT                           CURRENT_SIZE_MB MIN_SIZE_MB MAX_SIZE_MB
----------------------------------- --------------- ----------- -----------
DEFAULT buffer cache                           1104        1104        1104
large pool                                       16          16          16
shared pool                                     416         416         416
java pool                                        16          16          16
streams pool                                     16          16          16
```

---

# LAB 4 — Melihat Ringkasan SGA

```sql
SELECT name,
       bytes/1024/1024 AS size_mb
FROM v$sgainfo
ORDER BY name;
```

Contoh output:

```text
NAME                                      SIZE_MB
---------------------------------------- --------
Buffer Cache Size                            1104
Fixed SGA Size                                  8
Free SGA Memory Available                      64
Granule Size                                   16
Java Pool Size                                 16
Large Pool Size                                16
Maximum SGA Size                             1600
Redo Buffers                                   16
Shared Pool Size                              416
Streams Pool Size                              16
```

---

# LAB 5 — Melihat PGA Usage

```sql
SELECT name,
       value/1024/1024 AS value_mb
FROM v$pgastat
WHERE name IN (
  'aggregate PGA target parameter',
  'aggregate PGA auto target',
  'total PGA allocated',
  'total PGA inuse',
  'maximum PGA allocated'
);
```

Contoh output:

```text
NAME                                      VALUE_MB
---------------------------------------- --------
aggregate PGA target parameter                500
aggregate PGA auto target                     380
total PGA allocated                           120
total PGA inuse                                85
maximum PGA allocated                         310
```

---

# LAB 6 — Membuat Environment Lab di PDB

Masuk ke PDB1:

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

Buat tablespace:

```sql
CREATE TABLESPACE TS_MEM_LAB
DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/ts_mem_lab01.dbf'
SIZE 300M
AUTOEXTEND ON
NEXT 100M
MAXSIZE 2G;
```

Contoh output:

```text
Tablespace created.
```

Buat user:

```sql
CREATE USER memuser IDENTIFIED BY oracle
DEFAULT TABLESPACE TS_MEM_LAB
TEMPORARY TABLESPACE TEMP
QUOTA UNLIMITED ON TS_MEM_LAB;
```

Contoh output:

```text
User created.
```

Grant privilege:

```sql
GRANT CREATE SESSION, CREATE TABLE, CREATE INDEX TO memuser;
```

Contoh output:

```text
Grant succeeded.
```

Login sebagai user lab:

```sql
CONN memuser/oracle@localhost:1521/pdb1.localdomain
```

Buat tabel besar:

```sql
CREATE TABLE transaksi_mem AS
SELECT LEVEL AS id,
       'CBG' || MOD(LEVEL, 20) AS kode_cabang,
       'PRD' || MOD(LEVEL, 100) AS kode_produk,
       TRUNC(SYSDATE) - MOD(LEVEL, 365) AS tanggal_trans,
       MOD(LEVEL, 100000) AS nilai_trans,
       RPAD('DATA MEMORY TEST', 300, 'X') AS keterangan
FROM dual
CONNECT BY LEVEL <= 500000;
```

Contoh output:

```text
Table created.
```

Verifikasi:

```sql
SELECT COUNT(*) FROM transaksi_mem;
```

Contoh output:

```text
  COUNT(*)
----------
    500000
```

Gather statistic:

```sql
BEGIN
  DBMS_STATS.GATHER_TABLE_STATS(
    ownname => 'MEMUSER',
    tabname => 'TRANSAKSI_MEM',
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

# LAB 7 — Monitoring Buffer Cache Sebelum Workload

Masuk sebagai SYS:

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;
```

Cek logical read dan physical read:

```sql
SELECT name, value
FROM v$sysstat
WHERE name IN (
  'session logical reads',
  'physical reads',
  'physical reads cache'
)
ORDER BY name;
```

Contoh output:

```text
NAME                         VALUE
---------------------------- ----------
physical reads               25000
physical reads cache         24000
session logical reads        650000
```

---

# LAB 8 — Simulasi Workload Membaca Banyak Data

Login sebagai `memuser`:

```sql
CONN memuser/oracle@localhost:1521/pdb1.localdomain
```

Jalankan query full scan:

```sql
SET TIMING ON

SELECT COUNT(*)
FROM transaksi_mem
WHERE nilai_trans BETWEEN 1000 AND 90000;
```

Contoh output:

```text
  COUNT(*)
----------
    445000

Elapsed: 00:00:05.20
```

Jalankan lagi query yang sama:

```sql
SELECT COUNT(*)
FROM transaksi_mem
WHERE nilai_trans BETWEEN 1000 AND 90000;
```

Contoh output:

```text
  COUNT(*)
----------
    445000

Elapsed: 00:00:02.10
```

Interpretasi:

```text
Eksekusi kedua biasanya lebih cepat karena sebagian block sudah berada di buffer cache.
```

---

# LAB 9 — Monitoring Buffer Cache Setelah Workload

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

SELECT name, value
FROM v$sysstat
WHERE name IN (
  'session logical reads',
  'physical reads',
  'physical reads cache'
)
ORDER BY name;
```

Contoh output:

```text
NAME                         VALUE
---------------------------- ----------
physical reads               31000
physical reads cache         30000
session logical reads        920000
```

Cek hit ratio sederhana:

```sql
SELECT ROUND(
         (1 - (phy.value / NULLIF(log.value,0))) * 100, 2
       ) AS buffer_cache_hit_ratio_pct
FROM v$sysstat phy,
     v$sysstat log
WHERE phy.name = 'physical reads'
AND log.name = 'session logical reads';
```

Contoh output:

```text
BUFFER_CACHE_HIT_RATIO_PCT
--------------------------
                     96.63
```

---

# LAB 10 — Melihat Advisori Buffer Cache

```sql
CONN / AS SYSDBA

COLUMN size_for_estimate_mb FORMAT 999999
COLUMN estd_physical_read_factor FORMAT 999999.99

SELECT size_for_estimate AS size_for_estimate_mb,
       buffers_for_estimate,
       estd_physical_read_factor,
       estd_physical_reads
FROM v$db_cache_advice
WHERE name = 'DEFAULT'
AND block_size = (SELECT value FROM v$parameter WHERE name = 'db_block_size')
ORDER BY size_for_estimate;
```

Contoh output:

```text
SIZE_FOR_ESTIMATE_MB BUFFERS_FOR_ESTIMATE ESTD_PHYSICAL_READ_FACTOR ESTD_PHYSICAL_READS
-------------------- -------------------- ------------------------- -------------------
                 512                65536                      1.50              45000
                1024               131072                      1.00              30000
                1536               196608                      0.82              24600
```

Interpretasi:

```text
Jika ukuran buffer cache dinaikkan, estimated physical reads bisa turun.
```

---

# LAB 11 — Resize SGA Target Secara Manual

Cek nilai awal:

```sql
SHOW PARAMETER sga_target
SHOW PARAMETER sga_max_size
```

Contoh output:

```text
sga_target     big integer 1600M
sga_max_size   big integer 1600M
```

Jika `sga_max_size` cukup besar, SGA target dapat dinaikkan tanpa restart:

```sql
ALTER SYSTEM SET sga_target = 1800M SCOPE=BOTH;
```

Contoh output:

```text
System altered.
```

Jika muncul error seperti ini:

```text
ORA-02097: parameter cannot be modified because specified value is invalid
ORA-00823: Specified value of sga_target greater than sga_max_size
```

Artinya `sga_target` tidak boleh melebihi `sga_max_size`.

Verifikasi:

```sql
SHOW PARAMETER sga_target
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- --------
sga_target                           big integer 1800M
```

Cek komponen SGA:

```sql
SELECT component,
       current_size/1024/1024 AS current_size_mb
FROM v$sga_dynamic_components
WHERE current_size > 0
ORDER BY component;
```

Contoh output:

```text
COMPONENT                           CURRENT_SIZE_MB
----------------------------------- ---------------
DEFAULT buffer cache                           1280
shared pool                                     416
large pool                                       16
java pool                                        16
streams pool                                     16
```

---

# LAB 12 — Resize Shared Pool Manual

Cek shared pool:

```sql
SHOW PARAMETER shared_pool_size
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- -----
shared_pool_size                     big integer 0
```

Nilai `0` berarti dikelola otomatis oleh ASMM.

Set minimum shared pool:

```sql
ALTER SYSTEM SET shared_pool_size = 300M SCOPE=BOTH;
```

Contoh output:

```text
System altered.
```

Verifikasi:

```sql
SHOW PARAMETER shared_pool_size
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- -----
shared_pool_size                     big integer 304M
```

Cek komponen:

```sql
SELECT component,
       current_size/1024/1024 AS current_size_mb
FROM v$sga_dynamic_components
WHERE component = 'shared pool';
```

Contoh output:

```text
COMPONENT       CURRENT_SIZE_MB
--------------- ---------------
shared pool                 416
```

Catatan:

```text
shared_pool_size pada ASMM berfungsi sebagai batas minimum.
Oracle tetap dapat memberi ukuran lebih besar jika dibutuhkan.
```

---

# LAB 13 — Simulasi Hard Parse dan Shared Pool

Login sebagai `memuser`:

```sql
CONN memuser/oracle@localhost:1521/pdb1.localdomain
```

Jalankan banyak SQL literal:

```sql
BEGIN
  FOR i IN 1..1000 LOOP
    EXECUTE IMMEDIATE
      'SELECT COUNT(*) FROM transaksi_mem WHERE id = ' || i;
  END LOOP;
END;
/
```

Contoh output:

```text
PL/SQL procedure successfully completed.
```

Verifikasi banyak SQL berbeda:

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

SELECT COUNT(*) AS jumlah_sql_literal
FROM v$sql
WHERE sql_text LIKE 'SELECT COUNT(*) FROM transaksi_mem WHERE id =%';
```

Contoh output:

```text
JUMLAH_SQL_LITERAL
------------------
              1000
```

Cek shared pool reload:

```sql
SELECT namespace,
       pins,
       reloads,
       invalidations
FROM v$librarycache
WHERE namespace IN ('SQL AREA', 'TABLE/PROCEDURE');
```

Contoh output:

```text
NAMESPACE        PINS     RELOADS INVALIDATIONS
--------------- ----- ---------- -------------
SQL AREA        15320         12             0
TABLE/PROCEDURE  8200          3             0
```

Tuning dengan bind variable:

```sql
CONN memuser/oracle@localhost:1521/pdb1.localdomain

DECLARE
  v_count NUMBER;
BEGIN
  FOR i IN 1..1000 LOOP
    EXECUTE IMMEDIATE
      'SELECT COUNT(*) FROM transaksi_mem WHERE id = :b1'
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

Verifikasi:

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

SELECT sql_text,
       executions,
       parse_calls
FROM v$sql
WHERE sql_text LIKE 'SELECT COUNT(*) FROM transaksi_mem WHERE id = :b1%';
```

Contoh output:

```text
SQL_TEXT                                             EXECUTIONS PARSE_CALLS
---------------------------------------------------- ---------- -----------
SELECT COUNT(*) FROM transaksi_mem WHERE id = :b1          1000           1
```

---

# LAB 14 — PGA dan Sort Memory

Cek PGA sebelum workload:

```sql
CONN / AS SYSDBA

SELECT name,
       ROUND(value/1024/1024,2) AS value_mb
FROM v$pgastat
WHERE name IN (
  'aggregate PGA target parameter',
  'total PGA allocated',
  'total PGA inuse',
  'maximum PGA allocated',
  'extra bytes read/written',
  'cache hit percentage'
);
```

Contoh output:

```text
NAME                                      VALUE_MB
---------------------------------------- --------
aggregate PGA target parameter             500.00
total PGA allocated                        130.00
total PGA inuse                             90.00
maximum PGA allocated                      320.00
extra bytes read/written                     0.00
cache hit percentage                        98.50
```

Jalankan sort besar:

```sql
CONN memuser/oracle@localhost:1521/pdb1.localdomain

SET TIMING ON

SELECT *
FROM transaksi_mem
ORDER BY keterangan, nilai_trans, tanggal_trans;
```

Contoh output:

```text
Elapsed: 00:00:18.50
```

Cek penggunaan TEMP:

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
        91      31421 MEMUSER         TEMP                     220.00 SORT      9abc123xyz
```

---

# LAB 15 — Tuning PGA Aggregate Target

Cek nilai awal:

```sql
CONN / AS SYSDBA

SHOW PARAMETER pga_aggregate_target
```

Contoh output:

```text
pga_aggregate_target                 big integer 500M
```

Naikkan PGA target:

```sql
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

Jalankan ulang sort:

```sql
CONN memuser/oracle@localhost:1521/pdb1.localdomain

SET TIMING ON

SELECT *
FROM transaksi_mem
ORDER BY keterangan, nilai_trans, tanggal_trans;
```

Contoh output setelah tuning:

```text
Elapsed: 00:00:10.40
```

Cek PGA lagi:

```sql
CONN / AS SYSDBA

SELECT name,
       ROUND(value/1024/1024,2) AS value_mb
FROM v$pgastat
WHERE name IN (
  'aggregate PGA target parameter',
  'total PGA allocated',
  'maximum PGA allocated',
  'extra bytes read/written',
  'cache hit percentage'
);
```

Contoh output:

```text
NAME                                      VALUE_MB
---------------------------------------- --------
aggregate PGA target parameter            1024.00
total PGA allocated                        260.00
maximum PGA allocated                      620.00
extra bytes read/written                     0.00
cache hit percentage                        99.20
```

Improvement contoh:

```text
Sebelum tuning PGA : 18.50 detik
Sesudah tuning PGA : 10.40 detik
```

---

# LAB 16 — PGA Advisor

```sql
SELECT pga_target_for_estimate/1024/1024 AS pga_target_mb,
       pga_target_factor,
       estd_pga_cache_hit_percentage,
       estd_overalloc_count
FROM v$pga_target_advice
ORDER BY pga_target_for_estimate;
```

Contoh output:

```text
PGA_TARGET_MB PGA_TARGET_FACTOR ESTD_PGA_CACHE_HIT_PERCENTAGE ESTD_OVERALLOC_COUNT
------------- ----------------- ----------------------------- --------------------
          256               .25                            82                    3
          512               .50                            95                    1
         1024              1.00                            99                    0
         2048              2.00                           100                    0
```

Interpretasi:

```text
Jika estd_overalloc_count masih tinggi, PGA target mungkin terlalu kecil.
```

---

# LAB 17 — Memory Management di Level PDB

Di Oracle Multitenant, beberapa parameter memory dapat dibatasi per PDB, tetapi tetap berada dalam batas resource CDB.

Masuk ke PDB:

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;
```

Cek parameter memory yang dapat dimodifikasi di PDB:

```sql
SELECT name,
       value,
       ispdb_modifiable
FROM v$parameter
WHERE name IN (
  'sga_target',
  'pga_aggregate_target',
  'db_cache_size',
  'shared_pool_size'
)
ORDER BY name;
```

Contoh output:

```text
NAME                    VALUE       ISPDB_MODIFIABLE
----------------------- ----------- ----------------
db_cache_size           0           TRUE
pga_aggregate_target    1073741824  TRUE
sga_target              0           TRUE
shared_pool_size        0           TRUE
```

Set PGA target khusus PDB:

```sql
ALTER SYSTEM SET pga_aggregate_target = 300M;
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
pga_aggregate_target                 big integer 300M
```

Kembali ke root dan cek parameter per container:

```sql
CONN / AS SYSDBA

COLUMN name FORMAT A25
COLUMN value FORMAT A15

SELECT con_id,
       name,
       value
FROM v$system_parameter
WHERE name = 'pga_aggregate_target'
ORDER BY con_id;
```

Contoh output:

```text
    CON_ID NAME                      VALUE
---------- ------------------------- ---------------
         0 pga_aggregate_target      1073741824
         3 pga_aggregate_target      314572800
```

---

# LAB 18 — Monitoring Memory Per PDB

Jalankan dari root:

```sql
CONN / AS SYSDBA
```

Cek resource metric PDB:

```sql
COLUMN name FORMAT A20

SELECT p.name,
       m.sga_bytes/1024/1024 AS sga_mb,
       m.pga_bytes/1024/1024 AS pga_mb,
       m.buffer_cache_bytes/1024/1024 AS buffer_cache_mb,
       m.shared_pool_bytes/1024/1024 AS shared_pool_mb
FROM v$rsrcpdbmetric m
JOIN v$pdbs p
ON m.con_id = p.con_id
ORDER BY p.name;
```

Contoh output:

```text
NAME                     SGA_MB     PGA_MB BUFFER_CACHE_MB SHARED_POOL_MB
-------------------- ---------- ---------- --------------- --------------
PDB1                        420        120             300            100
```

Jika kolom tertentu tidak tersedia di environment Anda, gunakan query berikut:

```sql
SELECT p.name,
       m.cpu_consumed_time,
       m.io_requests,
       m.memory
FROM v$rsrcpdbmetric m
JOIN v$pdbs p
ON m.con_id = p.con_id
ORDER BY p.name;
```

Contoh output:

```text
NAME                 CPU_CONSUMED_TIME IO_REQUESTS     MEMORY
-------------------- ----------------- ----------- ----------
PDB1                              1520        2050        512
```

---

# LAB 19 — Menurunkan Memory PDB untuk Simulasi Bottleneck

Masuk ke PDB:

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;
```

Set PGA PDB lebih kecil:

```sql
ALTER SYSTEM SET pga_aggregate_target = 100M;
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
pga_aggregate_target                 big integer 100M
```

Jalankan sort besar:

```sql
CONN memuser/oracle@localhost:1521/pdb1.localdomain

SET TIMING ON

SELECT *
FROM transaksi_mem
ORDER BY keterangan, nilai_trans, tanggal_trans;
```

Contoh output:

```text
Elapsed: 00:00:23.70
```

Monitoring TEMP:

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

SELECT s.sid,
       s.username,
       u.tablespace,
       ROUND(u.blocks * 8 / 1024,2) AS used_mb,
       u.segtype
FROM v$tempseg_usage u
JOIN v$session s
ON u.session_addr = s.saddr
ORDER BY used_mb DESC;
```

Contoh output:

```text
       SID USERNAME        TABLESPACE              USED_MB SEGTYPE
---------- --------------- -------------------- ---------- ---------
        91 MEMUSER         TEMP                     380.00 SORT
```

Naikkan kembali PGA PDB:

```sql
ALTER SYSTEM SET pga_aggregate_target = 300M;
```

Contoh output:

```text
System altered.
```

Ulangi query sort dan bandingkan:

```text
PGA PDB 100M : sekitar 23.70 detik
PGA PDB 300M : sekitar 14.20 detik
```

---

# LAB 20 — Melihat Memory Dynamic Resize Operation

```sql
CONN / AS SYSDBA

COLUMN component FORMAT A35
COLUMN oper_type FORMAT A15
COLUMN status FORMAT A12
COLUMN start_time FORMAT A25

SELECT component,
       oper_type,
       parameter,
       initial_size/1024/1024 AS initial_mb,
       target_size/1024/1024 AS target_mb,
       final_size/1024/1024 AS final_mb,
       status
FROM v$sga_resize_ops
ORDER BY start_time DESC
FETCH FIRST 10 ROWS ONLY;
```

Contoh output:

```text
COMPONENT             OPER_TYPE       PARAMETER          INITIAL_MB TARGET_MB FINAL_MB STATUS
-------------------- --------------- ------------------ ---------- --------- -------- --------
DEFAULT buffer cache  GROW            db_cache_size            1104      1280     1280 COMPLETE
shared pool           SHRINK          shared_pool_size          432       416      416 COMPLETE
```

---

# LAB 21 — Flush Shared Pool dan Buffer Cache

Catatan: jangan dilakukan di production tanpa alasan kuat.

Flush shared pool:

```sql
CONN / AS SYSDBA

ALTER SYSTEM FLUSH SHARED_POOL;
```

Contoh output:

```text
System altered.
```

Flush buffer cache:

```sql
ALTER SYSTEM FLUSH BUFFER_CACHE;
```

Contoh output:

```text
System altered.
```

Jalankan query pertama setelah flush:

```sql
CONN memuser/oracle@localhost:1521/pdb1.localdomain

SET TIMING ON

SELECT COUNT(*)
FROM transaksi_mem
WHERE nilai_trans BETWEEN 1000 AND 90000;
```

Contoh output:

```text
Elapsed: 00:00:05.80
```

Jalankan ulang:

```sql
SELECT COUNT(*)
FROM transaksi_mem
WHERE nilai_trans BETWEEN 1000 AND 90000;
```

Contoh output:

```text
Elapsed: 00:00:02.30
```

Kesimpulan:

```text
Setelah buffer cache di-flush, query pertama lebih lambat.
Query berikutnya lebih cepat karena block mulai masuk kembali ke cache.
```

---

# LAB 22 — Melihat Top SQL dari Sisi Memory

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

COLUMN sql_text FORMAT A70

SELECT sql_id,
       executions,
       buffer_gets,
       disk_reads,
       rows_processed,
       ROUND(elapsed_time/1000000,2) AS elapsed_sec,
       SUBSTR(sql_text,1,70) AS sql_text
FROM v$sql
WHERE parsing_schema_name = 'MEMUSER'
ORDER BY buffer_gets DESC
FETCH FIRST 10 ROWS ONLY;
```

Contoh output:

```text
SQL_ID        EXECUTIONS BUFFER_GETS DISK_READS ROWS_PROCESSED ELAPSED_SEC SQL_TEXT
------------- ---------- ----------- ---------- -------------- ----------- ------------------------------
8abcxyz123             2      180000      12000         890000       8.10 SELECT COUNT(*) FROM transaksi_mem...
9defxyz789             1      150000      15000         500000      18.50 SELECT * FROM transaksi_mem ORDER BY...
```

---

# LAB 23 — Cleanup Lab

Masuk sebagai SYS:

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;
```

Drop user dan tablespace:

```sql
DROP USER memuser CASCADE;
DROP TABLESPACE TS_MEM_LAB INCLUDING CONTENTS AND DATAFILES;
```

Contoh output:

```text
User dropped.

Tablespace dropped.
```

Kembalikan parameter PDB jika diubah:

```sql
ALTER SYSTEM RESET pga_aggregate_target;
```

Contoh output:

```text
System altered.
```

Kembali ke root:

```sql
CONN / AS SYSDBA
```

Kembalikan PGA root contoh:

```sql
ALTER SYSTEM SET pga_aggregate_target = 500M SCOPE=BOTH;
```

Contoh output:

```text
System altered.
```

Reset shared pool minimum jika sebelumnya diset:

```sql
ALTER SYSTEM SET shared_pool_size = 0 SCOPE=BOTH;
```

Contoh output:

```text
System altered.
```

Verifikasi akhir:

```sql
SHOW PARAMETER sga_target
SHOW PARAMETER pga_aggregate_target
SHOW PARAMETER shared_pool_size
```

Contoh output:

```text
sga_target             big integer 1600M
pga_aggregate_target   big integer 500M
shared_pool_size       big integer 0
```

---

# Ringkasan Command Penting

Melihat memory:

```sql
SHOW PARAMETER memory
SHOW PARAMETER sga
SHOW PARAMETER pga
```

Melihat komponen SGA:

```sql
SELECT component,
       current_size/1024/1024 AS current_size_mb
FROM v$sga_dynamic_components;
```

Melihat PGA:

```sql
SELECT name, value/1024/1024 AS value_mb
FROM v$pgastat;
```

SGA advisor:

```sql
SELECT size_for_estimate,
       estd_physical_read_factor,
       estd_physical_reads
FROM v$db_cache_advice;
```

PGA advisor:

```sql
SELECT pga_target_for_estimate/1024/1024 AS pga_target_mb,
       estd_pga_cache_hit_percentage,
       estd_overalloc_count
FROM v$pga_target_advice;
```

Resize SGA:

```sql
ALTER SYSTEM SET sga_target = 1800M SCOPE=BOTH;
```

Resize PGA:

```sql
ALTER SYSTEM SET pga_aggregate_target = 1G SCOPE=BOTH;
```

Set PGA khusus PDB:

```sql
ALTER SESSION SET CONTAINER=PDB1;
ALTER SYSTEM SET pga_aggregate_target = 300M;
```

Flush cache:

```sql
ALTER SYSTEM FLUSH SHARED_POOL;
ALTER SYSTEM FLUSH BUFFER_CACHE;
```

Catatan: di Oracle 19c Multitenant, memory utama tetap dikelola pada level CDB/instance. PDB dapat diberi batas tertentu, tetapi tidak memiliki instance memory terpisah seperti database non-CDB.
