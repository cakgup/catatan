# Cheat Sheet Oracle Day 1 - Sesuai Silabus

**Topik Silabus:** *Introduction to Enterprise Database Management and Oracle Architecture*  
**Fokus:** konsep database enterprise, ekosistem Oracle, arsitektur instance/database, CDB/PDB, dan eksplorasi komponen Oracle.  
**Tujuan belajar:** setelah menyelesaikan Day 1, Anda mampu membaca peta besar Oracle Database, membedakan instance dan database, mengenali struktur memory/process/file, serta memahami cara masuk ke CDB dan PDB untuk eksplorasi awal.

> Catatan penyelarasan: beberapa command administrasi seperti startup/shutdown, parameter file, user/privilege, listener, dan konektivitas dibahas lebih lengkap pada Day 2 sesuai silabus. Di Day 1, command tersebut hanya dipakai secukupnya untuk eksplorasi arsitektur.

---

## 0. Peta Silabus Day 1

| Modul Silabus | Materi Inti | Fokus Cheat Sheet |
|---|---|---|
| Module 1 - Enterprise Database Fundamentals | Peran database, core/non-core system, tanggung jawab DBA, lifecycle operasional | Memahami konteks kerja DBA enterprise |
| Module 2 - Introduction to Oracle Database | Produk Oracle, edition, deployment model, ekosistem Oracle | Memahami posisi Oracle Database dalam sistem enterprise |
| Module 3 - Oracle Database Architecture | Instance, SGA/PGA, background process, struktur fisik/logis | Query eksplorasi `v$instance`, `v$database`, memory, process, file |
| Module 4 - Oracle Multitenant Architecture | CDB, PDB, manfaat multitenant, pengelolaan CDB/PDB | Query CDB/PDB, pindah container, membuka PDB |
| Hands-on Lab | Exploring architecture, identifying components, tools, connecting to CDB/PDB | Latihan command berurutan dengan contoh output |

---

## 1. Gambaran Besar Oracle Database Server

Oracle Database Server terdiri dari dua kelompok besar:

```text
Oracle Database Server
|
+-- Instance
|   +-- Memory Structure
|   |   +-- SGA
|   |   +-- PGA
|   |
|   +-- Background Process
|       +-- DBWn
|       +-- LGWR
|       +-- CKPT
|       +-- SMON
|       +-- PMON
|       +-- ARCn
|
+-- Database
    +-- Datafile
    +-- Controlfile
    +-- Online Redo Log
    +-- Tempfile
    +-- Parameter File
    +-- Password File
    +-- Archive Log
    +-- Diagnostic Files
```

Pemahaman kunci:

| Istilah | Lokasi | Isi/Fungsi | Analogi |
|---|---|---|---|
| Instance | RAM + process OS | Memory dan background process untuk mengakses database | Mesin yang sedang hidup |
| Database | Disk/storage | File fisik database | Data dan komponen permanen di storage |
| SGA | Shared memory | Memory bersama untuk semua session | Ruang kerja bersama |
| PGA | Private memory | Memory private tiap server process | Meja kerja personal tiap session |
| Background process | OS process | Menulis data, redo, recovery, cleanup | Petugas operasional Oracle |
| Physical files | Disk | Datafile, controlfile, redo log, tempfile, archive log | Berkas database yang tersimpan |

---

## 2. Informasi Lab dan Environment

Contoh environment lab yang digunakan pada catatan:

```text
User Linux Oracle : oracle/oracle
User Linux root   : root/oracle
IP server         : 192.168.56.22
Oracle SID        : oradb
PDB               : PDB1
Oracle Home       : /u01/app/oracle/product/19.0.0/db_1
Oracle Base       : /u01/app/oracle
```

Nilai di atas dapat berbeda pada server lain. Prinsipnya, sebelum praktik DBA, selalu pastikan environment aktif.

### 2.1 Cek environment Oracle

```bash
env | grep ORACLE
```

**Fungsi:** menampilkan variabel environment Oracle yang aktif.

**Contoh output:**

```text
ORACLE_SID=oradb
ORACLE_BASE=/u01/app/oracle
ORACLE_HOME=/u01/app/oracle/product/19.0.0/db_1
```

**Cara membaca:**

| Output | Arti |
|---|---|
| `ORACLE_SID=oradb` | Instance lokal yang akan diakses adalah `oradb`. |
| `ORACLE_BASE=/u01/app/oracle` | Direktori dasar instalasi dan diagnostic Oracle. |
| `ORACLE_HOME=/u01/app/oracle/product/19.0.0/db_1` | Direktori software Oracle Database. |

### 2.2 Cek daftar database pada server

```bash
cat /etc/oratab
```

**Fungsi:** melihat SID yang terdaftar, Oracle Home, dan setting auto-start.

**Contoh output:**

```text
oradb:/u01/app/oracle/product/19.0.0/db_1:Y
```

**Cara membaca:**

```text
SID:ORACLE_HOME:AUTO_START
```

| Bagian | Arti |
|---|---|
| `oradb` | Nama SID/instance. |
| `/u01/app/oracle/product/19.0.0/db_1` | Lokasi Oracle Home. |
| `Y` | Database dapat diikutkan dalam mekanisme auto-start Oracle. |

---

## 3. Masuk ke SQL\*Plus untuk Eksplorasi Arsitektur

### 3.1 Login lokal sebagai SYSDBA

```bash
sqlplus / as sysdba
```

**Fungsi:** login ke database sebagai administrator melalui OS authentication.

**Contoh output:**

```text
SQL*Plus: Release 19.0.0.0.0 - Production on Tue Jul 7 08:10:00 2026

Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production

SQL>
```

**Cara membaca:** jika muncul `Connected to`, session sudah masuk ke database. Prompt berubah menjadi `SQL>`.

### 3.2 Cek user aktif

```sql
SHOW USER;
```

**Fungsi:** memastikan user/schema aktif.

**Contoh output:**

```text
USER is "SYS"
```

**Makna:** Anda sedang login sebagai `SYS`. Karena login dilakukan `as sysdba`, posisi ini sangat kuat dan harus hati-hati.

---

## 4. Eksplorasi Instance dan Database

### 4.1 Cek status instance

```sql
SELECT instance_name, status, database_status
FROM v$instance;
```

**Fungsi:** melihat nama instance dan statusnya.

**Contoh output:**

```text
INSTANCE_NAME    STATUS       DATABASE_STATUS
---------------  -----------  -----------------
oradb            OPEN         ACTIVE
```

**Cara membaca:**

| Kolom | Arti |
|---|---|
| `INSTANCE_NAME` | Nama instance yang aktif. |
| `STATUS` | Status instance: `STARTED`, `MOUNTED`, atau `OPEN`. |
| `DATABASE_STATUS` | Kondisi database dari sisi instance. |

### 4.2 Cek nama database dan mode open

```sql
SELECT name, cdb, open_mode, log_mode
FROM v$database;
```

**Fungsi:** melihat nama database, apakah CDB, mode open, dan mode redo/archive.

**Contoh output:**

```text
NAME   CDB  OPEN_MODE   LOG_MODE
-----  ---  ----------  ------------
ORADB  YES  READ WRITE  ARCHIVELOG
```

**Cara membaca:**

| Kolom | Arti |
|---|---|
| `NAME` | Nama database. |
| `CDB` | `YES` berarti database memakai multitenant CDB/PDB. |
| `OPEN_MODE` | `READ WRITE` berarti database dapat dibaca dan ditulis. |
| `LOG_MODE` | `ARCHIVELOG` atau `NOARCHIVELOG`. Detail recovery dibahas Day 3/5. |

### 4.3 Cek startup time instance

```sql
SELECT instance_name, startup_time
FROM v$instance;
```

**Fungsi:** mengetahui kapan instance terakhir dinyalakan.

**Contoh output:**

```text
INSTANCE_NAME    STARTUP_TIME
---------------  -------------------
oradb            07-JUL-26 07.58.32
```

**Makna:** berguna untuk health check dan investigasi restart tak terencana.

---

## 5. Memory Architecture: SGA dan PGA

### 5.1 Cek ringkasan SGA

```sql
SHOW SGA;
```

**Fungsi:** melihat ukuran komponen utama SGA.

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
| `Total System Global Area` | Total memory shared SGA. |
| `Variable Size` | Termasuk shared pool, large pool, java pool, dan komponen dinamis lain. |
| `Database Buffers` | Database buffer cache untuk block data. |
| `Redo Buffers` | Redo log buffer untuk catatan perubahan sebelum ditulis LGWR. |

### 5.2 Cek parameter SGA dan PGA

```sql
SHOW PARAMETER sga;
SHOW PARAMETER pga;
```

**Fungsi:** melihat parameter memory terkait SGA dan PGA.

**Contoh output `SHOW PARAMETER sga`:**

```text
NAME                      TYPE        VALUE
------------------------- ----------- ----------
allow_group_access_to_sga boolean     FALSE
lock_sga                  boolean     FALSE
pre_page_sga              boolean     TRUE
sga_max_size              big integer 1536M
sga_target                big integer 1536M
```

**Contoh output `SHOW PARAMETER pga`:**

```text
NAME                         TYPE        VALUE
---------------------------- ----------- ----------
pga_aggregate_limit          big integer 2G
pga_aggregate_target         big integer 512M
```

### 5.3 Cek komponen SGA dinamis

```sql
SELECT component, current_size/1024/1024 AS current_mb
FROM v$sga_dynamic_components
WHERE current_size > 0
ORDER BY component;
```

**Fungsi:** melihat alokasi komponen SGA yang aktif.

**Contoh output:**

```text
COMPONENT                  CURRENT_MB
-------------------------  ----------
DEFAULT buffer cache       608
large pool                 16
shared pool                512
java pool                  16
streams pool               0
```

**Cara membaca:** shared pool menyimpan parsed SQL/metadata; buffer cache menyimpan block data; large pool dipakai antara lain RMAN/shared server; java pool untuk JVM Oracle.

### 5.4 Cek statistik PGA

```sql
SELECT name, value
FROM v$pgastat
WHERE name IN ('aggregate PGA target parameter','total PGA allocated','maximum PGA allocated');
```

**Fungsi:** melihat kondisi pemakaian PGA.

**Contoh output:**

```text
NAME                            VALUE
------------------------------- ----------
aggregate PGA target parameter  536870912
total PGA allocated             184549376
maximum PGA allocated           402653184
```

**Makna:** nilai masih dalam bytes; bisa dibagi 1024/1024 untuk MB.

---

## 6. Shared Pool, Parsing, dan Bind Variable

Shared Pool berisi antara lain parsed SQL, PL/SQL, execution plan, dan data dictionary cache. Tujuan utamanya adalah mengurangi **hard parse** dan meningkatkan **soft parse**.

### 6.1 Contoh SQL yang kurang baik

```sql
SELECT * FROM emp WHERE empno = 100;
SELECT * FROM emp WHERE empno = 101;
```

**Masalah:** bentuk SQL berubah karena nilai literal berbeda. Oracle dapat menganggapnya sebagai SQL berbeda sehingga shared pool lebih cepat penuh.

### 6.2 Contoh SQL yang lebih baik dengan bind variable

```sql
VARIABLE v_empno NUMBER
EXEC :v_empno := 100;
SELECT * FROM emp WHERE empno = :v_empno;
```

**Fungsi:** mempertahankan bentuk SQL agar parsed SQL dan execution plan dapat digunakan ulang.

**Contoh output:**

```text
EMPNO ENAME   JOB       MGR HIREDATE   SAL   COMM DEPTNO
----- ------- -------- ---- --------- ----- ----- ------
100   ADAMS   CLERK    7902 12-JAN-21 1000        20
```

**Catatan:** tabel `EMP` mungkin tidak ada di semua lab. Jika tidak ada, gunakan tabel sample lain seperti `HR.EMPLOYEES`.

---

## 7. Background Process Oracle

### 7.1 Cek background process

```sql
SELECT pname, description
FROM v$bgprocess
WHERE pname IN ('DBW0','LGWR','CKPT','SMON','PMON','ARC0')
ORDER BY pname;
```

**Fungsi:** melihat background process utama.

**Contoh output:**

```text
PNAME  DESCRIPTION
-----  ---------------------------------------------------
ARC0   Archival Process 0
CKPT   checkpoint
DBW0   db writer process 0
LGWR   Redo etc.
PMON   process cleanup
SMON   System Monitor Process
```

**Cara mengingat:**

| Process | Fungsi singkat |
|---|---|
| `DBWn` | Menulis dirty block dari buffer cache ke datafile. |
| `LGWR` | Menulis redo entries dari redo log buffer ke online redo log. |
| `CKPT` | Memberi sinyal checkpoint dan update header/controlfile. |
| `SMON` | Instance recovery dan cleanup sistem. |
| `PMON` | Cleanup process/session yang gagal. |
| `ARCn` | Mengarsipkan redo log saat ARCHIVELOG mode. |

---

## 8. Physical Database Structures

### 8.1 Cek datafile

```sql
SELECT file#, name
FROM v$datafile
ORDER BY file#;
```

**Fungsi:** melihat file fisik yang menyimpan data permanen.

**Contoh output:**

```text
FILE#  NAME
-----  --------------------------------------------------
1      /u01/app/oracle/oradata/ORADB/system01.dbf
3      /u01/app/oracle/oradata/ORADB/sysaux01.dbf
4      /u01/app/oracle/oradata/ORADB/undotbs01.dbf
7      /u01/app/oracle/oradata/ORADB/users01.dbf
```

### 8.2 Cek tempfile

```sql
SELECT file#, name
FROM v$tempfile
ORDER BY file#;
```

**Fungsi:** melihat file fisik temporary tablespace.

**Contoh output:**

```text
FILE#  NAME
-----  --------------------------------------------------
1      /u01/app/oracle/oradata/ORADB/temp01.dbf
```

### 8.3 Cek controlfile

```sql
SELECT name
FROM v$controlfile;
```

**Fungsi:** melihat lokasi controlfile.

**Contoh output:**

```text
NAME
----------------------------------------------------------
/u01/app/oracle/oradata/ORADB/control01.ctl
/u01/app/oracle/fra/ORADB/control02.ctl
```

**Makna:** controlfile menyimpan metadata database seperti DBID, lokasi datafile, lokasi redo log, checkpoint SCN, dan informasi recovery.

### 8.4 Cek online redo log file

```sql
SELECT group#, member
FROM v$logfile
ORDER BY group#;
```

**Fungsi:** melihat lokasi file redo log.

**Contoh output:**

```text
GROUP#  MEMBER
------  --------------------------------------------------
1       /u01/app/oracle/oradata/ORADB/redo01.log
2       /u01/app/oracle/oradata/ORADB/redo02.log
3       /u01/app/oracle/oradata/ORADB/redo03.log
```

---

## 9. Logical Database Structures

Struktur logis adalah cara Oracle mengelompokkan data di dalam database.

```text
Database
+-- Tablespace
    +-- Segment
        +-- Extent
            +-- Oracle Block
```

### 9.1 Cek tablespace

```sql
SELECT tablespace_name, contents, status
FROM dba_tablespaces
ORDER BY tablespace_name;
```

**Fungsi:** melihat daftar tablespace dan jenisnya.

**Contoh output:**

```text
TABLESPACE_NAME  CONTENTS    STATUS
---------------  ----------  -------
SYSAUX           PERMANENT   ONLINE
SYSTEM           PERMANENT   ONLINE
TEMP             TEMPORARY   ONLINE
UNDOTBS1         UNDO        ONLINE
USERS            PERMANENT   ONLINE
```

### 9.2 Cek datafile per tablespace

```sql
SELECT tablespace_name, file_name, bytes/1024/1024 AS mb
FROM dba_data_files
ORDER BY tablespace_name, file_name;
```

**Fungsi:** melihat file fisik yang menjadi bagian dari tablespace.

**Contoh output:**

```text
TABLESPACE_NAME  FILE_NAME                                      MB
---------------  ---------------------------------------------  ----
SYSTEM           /u01/app/oracle/oradata/ORADB/system01.dbf      900
SYSAUX           /u01/app/oracle/oradata/ORADB/sysaux01.dbf      700
USERS            /u01/app/oracle/oradata/ORADB/users01.dbf       100
```

### 9.3 Cek ukuran database block

```sql
SHOW PARAMETER db_block_size;
```

**Fungsi:** melihat ukuran Oracle block default.

**Contoh output:**

```text
NAME           TYPE        VALUE
-------------- ----------- -----
db_block_size  integer     8192
```

**Makna:** `8192` bytes = 8 KB, default umum Oracle 19c.

---

## 10. Oracle Multitenant: CDB dan PDB

### 10.1 Cek apakah database adalah CDB

```sql
SELECT name, cdb
FROM v$database;
```

**Fungsi:** memastikan apakah database memakai arsitektur multitenant.

**Contoh output:**

```text
NAME   CDB
-----  ---
ORADB  YES
```

### 10.2 Cek container aktif

```sql
SHOW CON_NAME;
```

**Fungsi:** melihat posisi session saat ini.

**Contoh output:**

```text
CON_NAME
------------------------------
CDB$ROOT
```

**Makna:** session sedang berada di root container.

### 10.3 Cek daftar PDB

```sql
SHOW PDBS;
```

**Fungsi:** menampilkan PDB yang ada dan status open-nya.

**Contoh output:**

```text
    CON_ID CON_NAME                       OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
         2 PDB$SEED                       READ ONLY  NO
         3 PDB1                           READ WRITE NO
```

### 10.4 Cek PDB dengan query

```sql
SELECT con_id, name, open_mode
FROM v$pdbs
ORDER BY con_id;
```

**Fungsi:** alternatif query untuk melihat daftar PDB.

**Contoh output:**

```text
CON_ID  NAME       OPEN_MODE
------  ---------  ----------
2       PDB$SEED   READ ONLY
3       PDB1       READ WRITE
```

### 10.5 Pindah ke PDB1

```sql
ALTER SESSION SET CONTAINER = PDB1;
```

**Fungsi:** memindahkan konteks session dari `CDB$ROOT` ke `PDB1`.

**Contoh output:**

```text
Session altered.
```

Verifikasi:

```sql
SHOW CON_NAME;
```

**Contoh output:**

```text
CON_NAME
------------------------------
PDB1
```

### 10.6 Kembali ke root container

```sql
ALTER SESSION SET CONTAINER = CDB$ROOT;
```

**Fungsi:** kembali ke root container.

**Contoh output:**

```text
Session altered.
```

---

## 11. SQL vs SQL\*Plus Command

| Jenis | Contoh | Fungsi |
|---|---|---|
| SQL | `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `CREATE`, `ALTER`, `DROP` | Perintah ke database engine. |
| SQL\*Plus | `SHOW`, `SET`, `SPOOL`, `HOST`, `CONNECT`, `EXIT` | Perintah client/tool SQL\*Plus. |

### 11.1 Contoh SQL

```sql
SELECT name, open_mode FROM v$database;
```

**Fungsi:** query ke database.

### 11.2 Contoh SQL\*Plus

```sql
SHOW USER;
SET LINESIZE 200;
SPOOL hasil_day1.txt;
SELECT name, open_mode FROM v$database;
SPOOL OFF;
```

**Fungsi:** mengatur tampilan, menjalankan query, dan menyimpan output ke file.

**Contoh output saat `SPOOL`:**

```text
SQL> SPOOL hasil_day1.txt
SQL> SELECT name, open_mode FROM v$database;

NAME   OPEN_MODE
-----  ----------
ORADB  READ WRITE

SQL> SPOOL OFF
```

---

## 12. Oracle Administration Tools yang Perlu Dikenal

| Tool | Command | Fungsi |
|---|---|---|
| SQL\*Plus | `sqlplus` | Tool command-line utama untuk query dan administrasi. |
| Listener Control | `lsnrctl` | Mengelola listener Oracle Net. Detail Day 2. |
| Net Configuration Assistant | `netca` | Wizard konfigurasi alias/listener. Detail Day 2. |
| Net Manager | `netmgr` | GUI konfigurasi network Oracle. Detail Day 2. |
| RMAN | `rman` | Backup dan recovery. Detail Day 5. |
| ADRCI | `adrci` | Diagnostic repository/log. Dipakai untuk troubleshooting. |

### 12.1 Cek versi SQL\*Plus

```bash
sqlplus -v
```

**Fungsi:** melihat versi SQL\*Plus client.

**Contoh output:**

```text
SQL*Plus: Release 19.0.0.0.0 - Production
Version 19.3.0.0.0
```

### 12.2 Cek listener secara ringkas

```bash
lsnrctl status
```

**Fungsi:** melihat listener, endpoint, dan service. Detail konfigurasi masuk Day 2.

**Contoh output ringkas:**

```text
Connecting to (DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=srv1.localdomain)(PORT=1521)))
STATUS of the LISTENER
Alias                     LISTENER
Version                   TNSLSNR for Linux: Version 19.0.0.0.0
Start Date                07-JUL-2026 08:00:10
Services Summary...
Service "oradb.localdomain" has 1 instance(s).
  Instance "oradb", status READY, has 1 handler(s) for this service...
```

---

## 13. Lab Day 1 - Alur Praktik Sistematis

Gunakan alur ini saat mengulang materi Day 1.

### A. Cek environment

```bash
env | grep ORACLE
cat /etc/oratab
```

**Hasil yang diharapkan:** `ORACLE_SID`, `ORACLE_BASE`, `ORACLE_HOME`, dan SID di `/etc/oratab` sesuai lab.

### B. Login sebagai SYSDBA

```bash
sqlplus / as sysdba
```

**Hasil yang diharapkan:** muncul prompt `SQL>`.

### C. Identifikasi instance dan database

```sql
SELECT instance_name, status FROM v$instance;
SELECT name, cdb, open_mode FROM v$database;
```

**Hasil yang diharapkan:** status `OPEN`, `CDB=YES`, dan database `READ WRITE`.

### D. Eksplorasi memory

```sql
SHOW SGA;
SHOW PARAMETER sga;
SHOW PARAMETER pga;
```

**Hasil yang diharapkan:** terlihat ukuran SGA dan PGA.

### E. Eksplorasi file fisik

```sql
SELECT name FROM v$controlfile;
SELECT file#, name FROM v$datafile ORDER BY file#;
SELECT group#, member FROM v$logfile ORDER BY group#;
```

**Hasil yang diharapkan:** terlihat controlfile, datafile, dan redo log file.

### F. Eksplorasi struktur logis

```sql
SELECT tablespace_name, contents, status FROM dba_tablespaces ORDER BY tablespace_name;
```

**Hasil yang diharapkan:** terdapat `SYSTEM`, `SYSAUX`, `TEMP`, `UNDOTBS1`, dan `USERS`.

### G. Eksplorasi CDB/PDB

```sql
SHOW CON_NAME;
SHOW PDBS;
ALTER SESSION SET CONTAINER = PDB1;
SHOW CON_NAME;
ALTER SESSION SET CONTAINER = CDB$ROOT;
```

**Hasil yang diharapkan:** bisa berpindah dari `CDB$ROOT` ke `PDB1` dan kembali lagi.

---

## 14. Troubleshooting Ringkas Day 1

### 14.1 `sqlplus: command not found`

**Kemungkinan penyebab:** `ORACLE_HOME/bin` belum ada di `PATH`.

Cek:

```bash
echo $ORACLE_HOME
echo $PATH
```

Solusi sementara:

```bash
export PATH=$ORACLE_HOME/bin:$PATH
```

### 14.2 `ORA-01034: ORACLE not available`

**Kemungkinan penyebab:** instance belum hidup atau `ORACLE_SID` salah.

Cek:

```bash
echo $ORACLE_SID
ps -ef | grep pmon
```

Jika memang database belum hidup, materi startup ada pada Day 2.

### 14.3 `ORA-65011: Pluggable database PDB1 does not exist`

**Kemungkinan penyebab:** nama PDB berbeda.

Cek:

```sql
SHOW PDBS;
SELECT name FROM v$pdbs;
```

Gunakan nama PDB yang muncul pada output.

### 14.4 `ORA-00942: table or view does not exist`

**Kemungkinan penyebab:** object tidak ada di schema aktif atau privilege kurang.

Cek posisi:

```sql
SHOW USER;
SHOW CON_NAME;
```

---

## 15. Checklist Kompetensi Day 1

```text
[ ] Saya bisa menjelaskan peran database dalam enterprise system.
[ ] Saya bisa membedakan core system dan non-core system dari sisi kebutuhan database.
[ ] Saya bisa menjelaskan tanggung jawab DBA dalam availability, integrity, security, dan sustainability.
[ ] Saya bisa membedakan instance dan database.
[ ] Saya bisa menjelaskan SGA dan PGA.
[ ] Saya bisa menyebutkan fungsi DBWn, LGWR, CKPT, SMON, PMON, dan ARCn.
[ ] Saya bisa mengidentifikasi datafile, controlfile, redo log, dan tempfile.
[ ] Saya bisa menjelaskan struktur logis tablespace, segment, extent, dan block.
[ ] Saya bisa mengecek apakah database adalah CDB.
[ ] Saya bisa melihat daftar PDB dan berpindah container.
[ ] Saya bisa membedakan SQL dan SQL*Plus command.
```

---

## 16. Mini Latihan Ujian Lisan Day 1

1. Apa perbedaan instance dan database?
2. Mengapa SGA disebut shared memory?
3. Apa perbedaan SGA dan PGA?
4. Apa fungsi LGWR dan DBWn?
5. Mengapa controlfile sangat penting?
6. Apa fungsi online redo log?
7. Apa perbedaan physical structure dan logical structure?
8. Apa bedanya CDB dan PDB?
9. Mengapa PDB memudahkan konsolidasi database?
10. Mengapa bind variable dapat mengurangi hard parse?

---

## 17. Jawaban Singkat Mini Latihan

1. Instance adalah memory dan process yang hidup di RAM/OS; database adalah file fisik di storage.
2. Karena SGA dipakai bersama oleh banyak session Oracle.
3. SGA shared untuk instance, sedangkan PGA private untuk server process/session tertentu.
4. LGWR menulis redo entries ke redo log; DBWn menulis dirty block ke datafile.
5. Controlfile menyimpan metadata penting seperti lokasi datafile, redo log, checkpoint, DBID, dan informasi recovery.
6. Online redo log menyimpan catatan perubahan untuk recovery.
7. Physical structure adalah file di disk; logical structure adalah organisasi data seperti tablespace, segment, extent, dan block.
8. CDB adalah container database; PDB adalah pluggable database di dalam CDB.
9. Karena beberapa PDB dapat berbagi instance dan CDB yang sama, sehingga administrasi lebih efisien.
10. Karena bentuk SQL tetap sama sehingga parsed SQL dan execution plan dapat digunakan ulang.

---

## 18. Command Paling Penting Day 1

```bash
env | grep ORACLE
cat /etc/oratab
sqlplus / as sysdba
sqlplus -v
```

```sql
SHOW USER;
SHOW CON_NAME;
SHOW PDBS;
SELECT instance_name, status, database_status FROM v$instance;
SELECT name, cdb, open_mode, log_mode FROM v$database;
SHOW SGA;
SHOW PARAMETER sga;
SHOW PARAMETER pga;
SELECT component, current_size/1024/1024 AS current_mb FROM v$sga_dynamic_components WHERE current_size > 0 ORDER BY component;
SELECT pname, description FROM v$bgprocess WHERE pname IN ('DBW0','LGWR','CKPT','SMON','PMON','ARC0') ORDER BY pname;
SELECT file#, name FROM v$datafile ORDER BY file#;
SELECT name FROM v$controlfile;
SELECT group#, member FROM v$logfile ORDER BY group#;
SELECT tablespace_name, contents, status FROM dba_tablespaces ORDER BY tablespace_name;
ALTER SESSION SET CONTAINER = PDB1;
ALTER SESSION SET CONTAINER = CDB$ROOT;
```

---

## 19. Catatan Keamanan Day 1

- Hindari menjalankan command perubahan struktur pada database production saat masih belajar.
- Gunakan `SELECT` dan `SHOW` untuk eksplorasi awal.
- Jangan menghapus file fisik database, mengubah parameter, atau shutdown database production tanpa prosedur resmi.
- Untuk latihan, gunakan VM/lab seperti environment pelatihan.
