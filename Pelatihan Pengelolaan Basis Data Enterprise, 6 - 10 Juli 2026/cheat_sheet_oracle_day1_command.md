# Cheat Sheet Oracle Day 1 — Enterprise Database & Oracle Architecture

**Topik silabus:** *Introduction to Enterprise Database Management and Oracle Architecture*  
**Fokus belajar:** memahami peran database enterprise, arsitektur Oracle Database, komponen instance/database, struktur memory, background process, file fisik, struktur logis, serta konsep CDB/PDB.


> **Catatan penggunaan:** contoh output pada file ini bersifat realistis untuk lab Oracle 19c, tetapi nilai seperti hostname, path, ukuran file, `SID`, `SERVICE_NAME`, `CON_ID`, `SQL_ID`, dan status dapat berbeda sesuai environment. Jalankan command berurutan, baca output-nya, lalu cocokkan dengan bagian *cara membaca output*.

> **Asumsi lab umum:** CDB `ORADB`, PDB `PDB1`, OS Oracle Linux, user OS `oracle`, Oracle Database 19c, path umum `/u01/app/oracle/oradata/ORADB`.


---

## 1. Peta Belajar Day 1

| Modul | Materi | Yang harus bisa setelah belajar |
|---|---|---|
| Enterprise Database Fundamentals | Peran database dalam core/non-core system, tanggung jawab DBA, lifecycle operasional | Menjelaskan mengapa database harus available, secure, reliable, dan recoverable |
| Introduction to Oracle Database | Produk Oracle, deployment model, tools DBA | Mengenali SQL\*Plus, listener, RMAN, ADRCI, CDB/PDB |
| Oracle Architecture | Instance, SGA/PGA, process, file fisik/logis | Membedakan instance vs database dan membaca komponen Oracle dari dynamic view |
| Multitenant Architecture | CDB, PDB, PDB$SEED | Berpindah dari root ke PDB dan memahami isolasi antar-PDB |

---

## 2. Konsep Besar: Instance vs Database

```text
Oracle Database Server
├── Instance  = memory + background process
│   ├── SGA   = memory bersama
│   ├── PGA   = memory private session/process
│   └── Background process: DBWn, LGWR, CKPT, SMON, PMON, ARCn
└── Database  = file fisik di storage
    ├── Datafile
    ├── Control file
    ├── Online redo log
    ├── Tempfile
    ├── SPFILE/PFILE
    ├── Password file
    └── Archive log / diagnostic files
```

| Istilah | Fungsi singkat | Analogi |
|---|---|---|
| Instance | Mesin aktif yang memproses akses database | Mesin mobil yang menyala |
| Database | File permanen di storage | Muatan/data di bagasi |
| SGA | Memory bersama untuk cache data, SQL, redo | Ruang kerja bersama |
| PGA | Memory private untuk session/sort/hash | Meja kerja personal |
| Control file | Metadata penting database | Daftar isi dan peta file |
| Redo log | Catatan perubahan untuk recovery | CCTV aktivitas perubahan |
| Tablespace | Wadah logis object | Folder logis |
| Datafile | File fisik penyimpan object | File di disk |

---

## 3. Cek Environment Oracle

### 3.1 Cek variabel Oracle

```bash
env | grep ORACLE
```

**Fungsi:** melihat `ORACLE_SID`, `ORACLE_HOME`, dan `ORACLE_BASE` yang aktif.

**Contoh output:**

```text
ORACLE_SID=ORADB
ORACLE_BASE=/u01/app/oracle
ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
```

**Cara membaca:**

| Output | Makna |
|---|---|
| `ORACLE_SID=ORADB` | Instance lokal yang akan diakses adalah `ORADB` |
| `ORACLE_HOME=.../dbhome_1` | Lokasi software Oracle |
| `ORACLE_BASE=/u01/app/oracle` | Lokasi dasar instalasi, diagnostic, admin |

### 3.2 Cek database yang terdaftar

```bash
cat /etc/oratab
```

**Contoh output:**

```text
ORADB:/u01/app/oracle/product/19.0.0/dbhome_1:Y
```

**Format:**

```text
SID:ORACLE_HOME:AUTO_START
```

### 3.3 Cek apakah instance hidup dari OS

```bash
ps -ef | grep pmon
```

**Contoh output:**

```text
oracle   2234     1  0 08:00 ? 00:00:00 ora_pmon_ORADB
```

Jika terlihat `ora_pmon_ORADB`, instance `ORADB` sedang hidup.

---

## 4. Login ke SQL\*Plus

```bash
sqlplus / as sysdba
```

**Fungsi:** login lokal sebagai administrator database menggunakan OS authentication.

**Contoh output:**

```text
SQL*Plus: Release 19.0.0.0.0 - Production
Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
SQL>
```

Cek user aktif:

```sql
SHOW USER;
```

**Contoh output:**

```text
USER is "SYS"
```

Cek container aktif:

```sql
SHOW CON_NAME;
```

**Contoh output:**

```text
CON_NAME
------------------------------
CDB$ROOT
```

---

## 5. Eksplorasi Instance dan Database

### 5.1 Status instance

```sql
SELECT instance_name, status, database_status, startup_time
FROM v$instance;
```

**Fungsi:** melihat nama instance, status, dan waktu startup terakhir.

**Contoh output:**

```text
INSTANCE_NAME  STATUS  DATABASE_STATUS  STARTUP_TIME
-------------- ------- ---------------- ------------------
ORADB          OPEN    ACTIVE           11-JUL-26
```

| Status | Makna |
|---|---|
| `STARTED` | Instance hidup, control file belum dibaca |
| `MOUNTED` | Control file sudah dibaca, database belum open |
| `OPEN` | Database siap digunakan |

### 5.2 Status database

```sql
SELECT name, cdb, open_mode, log_mode
FROM v$database;
```

**Contoh output:**

```text
NAME   CDB  OPEN_MODE   LOG_MODE
------ ---- ----------- ------------
ORADB  YES  READ WRITE  ARCHIVELOG
```

| Kolom | Makna |
|---|---|
| `CDB=YES` | Database memakai arsitektur multitenant |
| `READ WRITE` | Database bisa dibaca dan ditulis |
| `ARCHIVELOG` | Redo lama diarsipkan, mendukung recovery lebih baik |

---

## 6. Memory Architecture: SGA dan PGA

### 6.1 Cek ringkasan SGA

```sql
SHOW SGA;
```

**Contoh output:**

```text
Total System Global Area 1610612736 bytes
Fixed Size                  8896704 bytes
Variable Size             956301312 bytes
Database Buffers          637534208 bytes
Redo Buffers                7880704 bytes
```

**Cara membaca:**

| Komponen | Fungsi |
|---|---|
| Database Buffers | Cache block data dari datafile |
| Redo Buffers | Buffer redo sebelum ditulis LGWR ke online redo log |
| Variable Size | Shared pool, large pool, java pool, dll |

### 6.2 Cek parameter memory

```sql
SHOW PARAMETER sga;
SHOW PARAMETER pga;
SHOW PARAMETER memory;
```

**Contoh output:**

```text
NAME                  TYPE        VALUE
--------------------- ----------- -------
sga_target            big integer 1600M
pga_aggregate_target  big integer 500M
memory_target         big integer 0
```

**Interpretasi cepat:**

```text
memory_target = 0      -> AMM tidak aktif.
sga_target > 0         -> ASMM aktif untuk SGA.
pga_aggregate_target >0-> PGA dikelola otomatis.
```

### 6.3 Cek komponen SGA dinamis

```sql
SELECT component,
       current_size/1024/1024 AS current_mb
FROM v$sga_dynamic_components
WHERE current_size > 0
ORDER BY component;
```

**Contoh output:**

```text
COMPONENT                    CURRENT_MB
---------------------------- ----------
DEFAULT buffer cache               1104
shared pool                         416
large pool                           16
java pool                            16
```

---

## 7. Background Process Penting

```sql
SELECT pname, description
FROM v$bgprocess
WHERE pname IN ('DBW0','LGWR','CKPT','SMON','PMON','ARC0')
ORDER BY pname;
```

**Contoh output:**

```text
PNAME DESCRIPTION
----- --------------------------------------
ARC0  Archival Process 0
CKPT  checkpoint
DBW0  db writer process 0
LGWR  Redo etc.
PMON  process cleanup
SMON  System Monitor Process
```

| Process | Fungsi utama |
|---|---|
| `DBWn` | Menulis dirty block dari buffer cache ke datafile |
| `LGWR` | Menulis redo dari redo buffer ke redo log |
| `CKPT` | Mengatur checkpoint dan update header/control file |
| `SMON` | Instance recovery dan cleanup sistem |
| `PMON` | Cleanup session/process gagal |
| `ARCn` | Mengarsipkan redo log pada ARCHIVELOG mode |

---

## 8. Struktur Fisik Database

### 8.1 Datafile

```sql
SELECT file#, name
FROM v$datafile
ORDER BY file#;
```

**Contoh output:**

```text
FILE# NAME
----- ------------------------------------------------------------
1     /u01/app/oracle/oradata/ORADB/system01.dbf
3     /u01/app/oracle/oradata/ORADB/sysaux01.dbf
4     /u01/app/oracle/oradata/ORADB/undotbs01.dbf
7     /u01/app/oracle/oradata/ORADB/users01.dbf
```

**Fungsi:** datafile menyimpan object permanen seperti table dan index.

### 8.2 Control file

```sql
SELECT name FROM v$controlfile;
```

**Contoh output:**

```text
NAME
------------------------------------------------------------
/u01/app/oracle/oradata/ORADB/control01.ctl
/u01/app/oracle/oradata/ORADB/control_mirror/control02.ctl
```

**Fungsi:** control file menyimpan metadata penting: DBID, lokasi datafile, redo log, checkpoint, dan informasi recovery.

### 8.3 Online redo log

```sql
SELECT group#, member
FROM v$logfile
ORDER BY group#;
```

**Contoh output:**

```text
GROUP# MEMBER
------ ------------------------------------------------------------
1      /u01/app/oracle/oradata/ORADB/redo01.log
2      /u01/app/oracle/oradata/ORADB/redo02.log
3      /u01/app/oracle/oradata/ORADB/redo03.log
```

---

## 9. Struktur Logis Database

```text
Database
└── Tablespace
    └── Segment
        └── Extent
            └── Oracle Block
```

### 9.1 Cek tablespace

```sql
SELECT tablespace_name, contents, status
FROM dba_tablespaces
ORDER BY tablespace_name;
```

**Contoh output:**

```text
TABLESPACE_NAME  CONTENTS   STATUS
---------------- ---------- ----------
SYSTEM           PERMANENT  ONLINE
SYSAUX           PERMANENT  ONLINE
TEMP             TEMPORARY  ONLINE
UNDOTBS1         UNDO       ONLINE
USERS            PERMANENT  ONLINE
```

| Contents | Makna |
|---|---|
| `PERMANENT` | Menyimpan object permanen |
| `TEMPORARY` | Menyimpan data sementara saat sort/hash |
| `UNDO` | Menyimpan undo untuk rollback dan read consistency |

### 9.2 Cek ukuran block database

```sql
SHOW PARAMETER db_block_size;
```

**Contoh output:**

```text
NAME           TYPE     VALUE
-------------- -------- -----
db_block_size  integer  8192
```

`8192` byte berarti block size 8 KB.

---

## 10. Multitenant: CDB dan PDB

### 10.1 Lihat daftar PDB

```sql
SHOW PDBS;
```

**Contoh output:**

```text
CON_ID CON_NAME   OPEN MODE  RESTRICTED
------ ---------- ---------- ----------
2      PDB$SEED   READ ONLY  NO
3      PDB1       READ WRITE NO
```

| PDB | Fungsi |
|---|---|
| `CDB$ROOT` | Root container, tempat metadata umum CDB |
| `PDB$SEED` | Template read-only untuk membuat PDB baru |
| `PDB1` | Pluggable database aplikasi/lab |

### 10.2 Pindah ke PDB

```sql
ALTER SESSION SET CONTAINER=PDB1;
SHOW CON_NAME;
```

**Contoh output:**

```text
Session altered.

CON_NAME
------------------------------
PDB1
```

### 10.3 Kembali ke root

```sql
ALTER SESSION SET CONTAINER=CDB$ROOT;
SHOW CON_NAME;
```

---

## 11. SQL vs SQL\*Plus Command

| Jenis | Contoh | Fungsi |
|---|---|---|
| SQL | `SELECT`, `CREATE`, `ALTER`, `DROP` | Dikirim ke database engine |
| SQL\*Plus | `SHOW`, `SET`, `SPOOL`, `HOST`, `CONNECT`, `EXIT` | Perintah client SQL\*Plus |

Contoh SQL\*Plus untuk merapikan output:

```sql
SET LINESIZE 200
SET PAGESIZE 100
COL NAME FORMAT A80
```

Menyimpan output ke file:

```sql
SPOOL hasil_day1.txt
SELECT name, open_mode FROM v$database;
SPOOL OFF
```

---

## 12. Lab Berurutan Day 1

Jalankan alur berikut untuk mengulang materi secara sistematis:

```bash
env | grep ORACLE
cat /etc/oratab
ps -ef | grep pmon
sqlplus / as sysdba
```

```sql
SHOW USER;
SHOW CON_NAME;
SELECT instance_name, status, database_status FROM v$instance;
SELECT name, cdb, open_mode, log_mode FROM v$database;
SHOW SGA;
SHOW PARAMETER sga;
SHOW PARAMETER pga;
SELECT pname, description FROM v$bgprocess WHERE pname IN ('DBW0','LGWR','CKPT','SMON','PMON','ARC0') ORDER BY pname;
SELECT file#, name FROM v$datafile ORDER BY file#;
SELECT name FROM v$controlfile;
SELECT group#, member FROM v$logfile ORDER BY group#;
SELECT tablespace_name, contents, status FROM dba_tablespaces ORDER BY tablespace_name;
SHOW PDBS;
ALTER SESSION SET CONTAINER=PDB1;
SHOW CON_NAME;
ALTER SESSION SET CONTAINER=CDB$ROOT;
```

---

## 13. Troubleshooting Day 1

| Error/Gejala | Penyebab umum | Solusi cepat |
|---|---|---|
| `sqlplus: command not found` | `ORACLE_HOME/bin` belum masuk `PATH` | `export PATH=$ORACLE_HOME/bin:$PATH` |
| `ORA-01034: ORACLE not available` | Instance belum hidup / `ORACLE_SID` salah | `echo $ORACLE_SID`, `ps -ef | grep pmon` |
| `ORA-65011: PDB does not exist` | Nama PDB salah | `SHOW PDBS` lalu gunakan nama yang benar |
| `ORA-00942` | Object tidak ada atau privilege kurang | Cek `SHOW USER`, `SHOW CON_NAME` |

---

## 14. Checklist Kompetensi Day 1

```text
[ ] Saya bisa menjelaskan peran database dalam sistem enterprise.
[ ] Saya bisa membedakan core system dan non-core system.
[ ] Saya bisa membedakan instance dan database.
[ ] Saya paham SGA, PGA, dan background process utama.
[ ] Saya bisa mengecek datafile, controlfile, redo log, dan tablespace.
[ ] Saya bisa menjelaskan physical vs logical structure.
[ ] Saya bisa menjelaskan CDB, PDB, dan PDB$SEED.
[ ] Saya bisa berpindah container dengan ALTER SESSION SET CONTAINER.
[ ] Saya bisa membaca output dasar v$instance, v$database, v$datafile, dan dba_tablespaces.
```

---

## 15. Mini Latihan Ujian Lisan

1. Apa perbedaan instance dan database?
2. Mengapa SGA disebut shared memory?
3. Apa fungsi DBWn dan LGWR?
4. Mengapa control file penting?
5. Apa fungsi online redo log?
6. Apa beda tablespace dan datafile?
7. Apa beda CDB dan PDB?
8. Mengapa `PDB$SEED` read only?
9. Apa beda SQL dan SQL\*Plus command?
10. Mengapa bind variable membantu shared pool?

### Jawaban singkat

1. Instance adalah memory dan process; database adalah file fisik di storage.
2. Karena dipakai bersama oleh banyak session.
3. DBWn menulis dirty block ke datafile; LGWR menulis redo ke redo log.
4. Control file menyimpan metadata lokasi file, checkpoint, dan informasi recovery.
5. Redo log mencatat perubahan untuk recovery.
6. Tablespace logis; datafile fisik.
7. CDB adalah container; PDB adalah database aplikasi di dalam CDB.
8. Karena menjadi template standar untuk membuat PDB baru.
9. SQL diproses database; SQL\*Plus mengatur client/session/output.
10. Karena SQL dapat digunakan ulang tanpa hard parse berulang.
