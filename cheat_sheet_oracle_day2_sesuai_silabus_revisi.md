# Cheat Sheet Oracle Day 2 - Sesuai Silabus

**Topik Silabus:** *Oracle Database Administration Fundamentals*  
**Fokus:** administrasi instance, startup/shutdown, parameter, OMF, user dan privilege, role, profile/resource limit, session management, listener, TNS, dan troubleshooting konektivitas.  
**Tujuan belajar:** setelah menyelesaikan Day 2, Anda mampu menjalankan tugas dasar DBA harian: menghidupkan/mematikan database, mengelola parameter, membuat user/role, memberi hak akses, mengatur profile, memantau session, serta mengelola koneksi Oracle Net.

> Catatan penyelarasan: catatan praktik 7 Juli memuat juga controlfile, redo log, archive log, dan penambahan redo log group. Dalam silabus resmi, materi tersebut lebih tepat masuk Day 3 - Storage and Data Management. Di file ini tetap disertakan sebagai **Appendix - Preview Day 3** agar catatan Bapak tidak hilang, tetapi materi inti Day 2 tetap mengikuti silabus.

---

## 0. Peta Silabus Day 2

| Modul Silabus | Materi Inti | Fokus Cheat Sheet |
|---|---|---|
| Module 5 - Database Instance Administration | Startup/shutdown, state NOMOUNT/MOUNT/OPEN, initialization parameters, OMF | Praktik `STARTUP`, `SHUTDOWN`, `SHOW PARAMETER`, `ALTER SYSTEM`, OMF |
| Module 6 - User and Privilege Management | User/schema, authentication, system privilege, object privilege, roles | Praktik create user, grant/revoke, role, lock/unlock |
| Module 7 - Resource Management | Profiles, password policy, resource limits, session management | Praktik profile, limit session, monitoring session, kill/disconnect session |
| Module 8 - Database Connectivity | Oracle Net, listener, TNS, troubleshooting client connectivity | Praktik listener, `tnsnames.ora`, `tnsping`, Easy Connect, password file, port listener |
| Hands-on Lab | Creating users/roles, managing privileges, profiles, listener/connectivity | Lab berurutan + contoh output |

---

## 1. Informasi Lab dan Prinsip Awal

Contoh environment dari catatan pelatihan:

```text
User Linux Oracle : oracle/oracle
User Linux root   : root/oracle
IP server         : 192.168.56.22
Oracle SID        : oradb
PDB               : PDB1
Oracle Home       : /u01/app/oracle/product/19.0.0/db_1
Oracle Base       : /u01/app/oracle
Default listener  : 1521
Contoh listener baru: KUPING pada port 1522
```

Sebelum melakukan administrasi, pastikan 3 hal:

```bash
env | grep ORACLE
cat /etc/oratab
ps -ef | grep pmon
```

### Contoh output `env | grep ORACLE`

```text
ORACLE_SID=oradb
ORACLE_BASE=/u01/app/oracle
ORACLE_HOME=/u01/app/oracle/product/19.0.0/db_1
```

### Contoh output `cat /etc/oratab`

```text
oradb:/u01/app/oracle/product/19.0.0/db_1:Y
```

### Contoh output `ps -ef | grep pmon`

```text
oracle    2234     1  0 08:00 ?        00:00:00 ora_pmon_oradb
oracle    3321  3100  0 08:12 pts/0    00:00:00 grep --color=auto pmon
```

**Cara membaca:** `ora_pmon_oradb` menandakan instance `oradb` sedang hidup.

---

## 2. Login Administrasi

### 2.1 Login lokal sebagai SYSDBA

```bash
sqlplus / as sysdba
```

**Fungsi:** login lokal menggunakan OS authentication. Biasanya dilakukan dari user OS `oracle`.

**Contoh output:**

```text
SQL*Plus: Release 19.0.0.0.0 - Production

Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production

SQL>
```

### 2.2 Connect ulang dari dalam SQL\*Plus

```sql
CONN / AS SYSDBA
```

**Fungsi:** menghubungkan ulang session yang sedang berada di SQL\*Plus sebagai SYSDBA.

**Contoh output:**

```text
Connected.
```

### 2.3 Menjalankan command OS dari SQL\*Plus

```sql
HOST pwd
```

atau di Linux SQL\*Plus dapat memakai:

```sql
!pwd
```

**Fungsi:** menjalankan command OS tanpa keluar dari SQL\*Plus.

**Contoh output:**

```text
/home/oracle
```

---

## 3. Database Instance Administration

### 3.1 Cek status instance dan database

```sql
SELECT instance_name, status FROM v$instance;
SELECT name, open_mode FROM v$database;
```

**Fungsi:** memastikan database berada pada state yang benar sebelum administrasi.

**Contoh output:**

```text
INSTANCE_NAME    STATUS
---------------  ------------
oradb            OPEN

NAME   OPEN_MODE
-----  ----------
ORADB  READ WRITE
```

---

## 4. Startup Database: NOMOUNT, MOUNT, OPEN

Urutan startup:

```text
STARTUP NOMOUNT -> ALTER DATABASE MOUNT -> ALTER DATABASE OPEN
```

### 4.1 STARTUP NOMOUNT

```sql
STARTUP NOMOUNT;
```

**Fungsi:** menghidupkan instance saja. Oracle membaca parameter file, membuat SGA, dan menjalankan background process. Controlfile belum dibuka.

**Contoh output:**

```text
ORACLE instance started.

Total System Global Area 1610612736 bytes
Fixed Size                  8896704 bytes
Variable Size             956301312 bytes
Database Buffers          637534208 bytes
Redo Buffers                7880704 bytes
```

**Verifikasi:**

```sql
SELECT status FROM v$instance;
```

**Contoh output:**

```text
STATUS
------------
STARTED
```

### 4.2 ALTER DATABASE MOUNT

```sql
ALTER DATABASE MOUNT;
```

**Fungsi:** membuka controlfile. Database mengetahui lokasi datafile dan redo log, tetapi belum dapat digunakan user umum.

**Contoh output:**

```text
Database altered.
```

**Verifikasi:**

```sql
SELECT status FROM v$instance;
SELECT name, open_mode FROM v$database;
```

**Contoh output:**

```text
STATUS
------------
MOUNTED

NAME   OPEN_MODE
-----  ----------
ORADB  MOUNTED
```

### 4.3 ALTER DATABASE OPEN

```sql
ALTER DATABASE OPEN;
```

**Fungsi:** membuka datafile dan redo log sehingga database siap digunakan.

**Contoh output:**

```text
Database altered.
```

**Verifikasi:**

```sql
SELECT name, open_mode FROM v$database;
```

**Contoh output:**

```text
NAME   OPEN_MODE
-----  ----------
ORADB  READ WRITE
```

### 4.4 Startup langsung sampai OPEN

```sql
STARTUP;
```

**Fungsi:** menjalankan startup sampai database `OPEN`.

**Contoh output:**

```text
ORACLE instance started.
Database mounted.
Database opened.
```

---

## 5. Shutdown Database

| Command | Perilaku | Kapan digunakan |
|---|---|---|
| `SHUTDOWN NORMAL;` | Menunggu semua user logout | Jarang, karena bisa lama |
| `SHUTDOWN TRANSACTIONAL;` | Tidak menerima transaksi baru, menunggu transaksi aktif selesai | Saat ingin menjaga transaksi berjalan selesai |
| `SHUTDOWN IMMEDIATE;` | Menghentikan session, rollback transaksi belum commit, checkpoint normal | Paling umum untuk administrasi harian |
| `SHUTDOWN ABORT;` | Mematikan paksa, instance recovery saat startup berikutnya | Darurat/lab, bukan default produksi |

### 5.1 Shutdown immediate

```sql
SHUTDOWN IMMEDIATE;
```

**Fungsi:** mematikan database dengan aman dan relatif cepat.

**Contoh output:**

```text
Database closed.
Database dismounted.
ORACLE instance shut down.
```

### 5.2 Shutdown abort

```sql
SHUTDOWN ABORT;
```

**Fungsi:** mematikan instance secara paksa. Digunakan untuk simulasi/lab atau kondisi darurat.

**Contoh output:**

```text
ORACLE instance shut down.
```

**Catatan:** setelah `SHUTDOWN ABORT`, startup berikutnya dapat menampilkan proses recovery internal.

---

## 6. Initialization Parameters dan Parameter File

Oracle memakai parameter untuk menentukan perilaku instance, memory, file, proses, dan konfigurasi lain.

### 6.1 Cek SPFILE

```sql
SHOW PARAMETER spfile;
```

**Fungsi:** melihat apakah database memakai SPFILE dan lokasinya.

**Contoh output:**

```text
NAME    TYPE    VALUE
------- ------- ----------------------------------------------
spfile  string  /u01/app/oracle/product/19.0.0/db_1/dbs/spfileoradb.ora
```

### 6.2 Cek parameter penting

```sql
SHOW PARAMETER db_name;
SHOW PARAMETER db_domain;
SHOW PARAMETER service_names;
SHOW PARAMETER control_files;
SHOW PARAMETER processes;
SHOW PARAMETER memory_target;
SHOW PARAMETER sga_target;
SHOW PARAMETER pga_aggregate_target;
```

**Fungsi:** mengecek parameter dasar instance dan database.

**Contoh output `SHOW PARAMETER processes`:**

```text
NAME       TYPE     VALUE
---------- -------- -----
processes  integer  300
```

### 6.3 Membuat PFILE dari SPFILE

```sql
CREATE PFILE FROM SPFILE;
```

**Fungsi:** membuat parameter file teks dari SPFILE.

**Contoh output:**

```text
File created.
```

**Lokasi umum:**

```text
$ORACLE_HOME/dbs/init<SID>.ora
```

Contoh:

```text
/u01/app/oracle/product/19.0.0/db_1/dbs/initoradb.ora
```

### 6.4 Membuat SPFILE dari PFILE

```sql
CREATE SPFILE FROM PFILE;
```

**Fungsi:** membuat SPFILE binary dari PFILE teks.

**Contoh output:**

```text
File created.
```

### 6.5 Mengubah parameter dinamis

```sql
ALTER SYSTEM SET open_cursors = 500 SCOPE=BOTH;
```

**Fungsi:** mengubah parameter di memory dan SPFILE sekaligus jika parameter mendukung.

**Contoh output:**

```text
System altered.
```

### 6.6 Mengubah parameter yang perlu restart

```sql
ALTER SYSTEM SET processes = 400 SCOPE=SPFILE;
```

**Fungsi:** mengubah nilai di SPFILE, berlaku setelah restart.

**Contoh output:**

```text
System altered.
```

Restart:

```sql
SHUTDOWN IMMEDIATE;
STARTUP;
```

### 6.7 Arti `SCOPE`

| Scope | Arti | Berlaku sampai kapan |
|---|---|---|
| `MEMORY` | Ubah hanya di memory | Hilang setelah restart |
| `SPFILE` | Ubah hanya di SPFILE | Berlaku setelah restart |
| `BOTH` | Ubah memory dan SPFILE | Langsung berlaku dan tetap setelah restart |

---

## 7. Oracle Managed Files (OMF)

OMF membuat Oracle otomatis menentukan nama dan lokasi file database jika parameter destination diset.

### 7.1 Cek parameter OMF

```sql
SHOW PARAMETER db_create_file_dest;
SHOW PARAMETER db_create_online_log_dest;
SHOW PARAMETER db_recovery_file_dest;
```

**Fungsi:** melihat apakah OMF/FRA dikonfigurasi.

**Contoh output:**

```text
NAME                         TYPE    VALUE
---------------------------- ------- -------------------------------
db_create_file_dest          string  /u01/app/oracle/oradata

db_recovery_file_dest        string  /u01/app/oracle/fra
```

### 7.2 Contoh membuat tablespace dengan OMF

```sql
CREATE TABLESPACE app_data DATAFILE SIZE 100M AUTOEXTEND ON NEXT 50M MAXSIZE 1G;
```

**Fungsi:** membuat tablespace tanpa menentukan path file. Oracle membuat nama file otomatis jika OMF aktif.

**Contoh output:**

```text
Tablespace created.
```

**Verifikasi:**

```sql
SELECT tablespace_name, file_name, bytes/1024/1024 AS mb
FROM dba_data_files
WHERE tablespace_name = 'APP_DATA';
```

**Contoh output:**

```text
TABLESPACE_NAME  FILE_NAME                                                        MB
---------------  ---------------------------------------------------------------  ---
APP_DATA          /u01/app/oracle/oradata/ORADB/datafile/o1_mf_app_data_xxx.dbf    100
```

---

## 8. User, Schema, dan Authentication

### 8.1 Konsep penting

| Istilah | Arti |
|---|---|
| User | Akun database untuk login dan memiliki object. |
| Schema | Kumpulan object milik user. Nama schema sama dengan nama user. |
| Authentication | Cara membuktikan identitas user. Contoh: password database, OS authentication, password file untuk SYSDBA remote. |
| Privilege | Hak melakukan tindakan tertentu. |
| Role | Paket privilege yang dapat diberikan ke user. |

### 8.2 Pindah ke PDB sebelum membuat user aplikasi

```sql
SHOW CON_NAME;
ALTER SESSION SET CONTAINER = PDB1;
SHOW CON_NAME;
```

**Fungsi:** memastikan administrasi user dilakukan di PDB yang benar.

**Contoh output:**

```text
CON_NAME
------------------------------
CDB$ROOT

Session altered.

CON_NAME
------------------------------
PDB1
```

### 8.3 Cek user HR

```sql
SELECT username, account_status, default_tablespace, profile
FROM dba_users
WHERE username = 'HR';
```

**Fungsi:** melihat status user HR.

**Contoh output:**

```text
USERNAME  ACCOUNT_STATUS  DEFAULT_TABLESPACE  PROFILE
--------  --------------  ------------------  -------
HR        EXPIRED & LOCKED USERS              DEFAULT
```

### 8.4 Unlock HR dan set password

```sql
ALTER USER hr IDENTIFIED BY hr ACCOUNT UNLOCK;
```

**Fungsi:** mengubah password HR menjadi `hr` dan membuka account.

**Contoh output:**

```text
User altered.
```

### 8.5 Beri privilege login

```sql
GRANT CREATE SESSION TO hr;
```

**Fungsi:** memberi hak login ke database.

**Contoh output:**

```text
Grant succeeded.
```

### 8.6 Tes login ke PDB

```bash
sqlplus hr/hr@pdb1
```

**Fungsi:** login sebagai HR melalui alias/service `pdb1`.

**Contoh output:**

```text
Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production

SQL>
```

---

## 9. Membuat User dan Memberi Privilege

### 9.1 Buat user aplikasi

```sql
CREATE USER app_user IDENTIFIED BY AppUser#2026 DEFAULT TABLESPACE users TEMPORARY TABLESPACE temp;
```

**Fungsi:** membuat user `APP_USER` dengan tablespace default `USERS` dan temporary tablespace `TEMP`.

**Contoh output:**

```text
User created.
```

### 9.2 Beri hak login

```sql
GRANT CREATE SESSION TO app_user;
```

**Fungsi:** mengizinkan `APP_USER` login ke database.

**Contoh output:**

```text
Grant succeeded.
```

### 9.3 Beri hak membuat object dasar

```sql
GRANT CREATE TABLE, CREATE VIEW, CREATE SEQUENCE, CREATE PROCEDURE TO app_user;
```

**Fungsi:** memberi hak membuat object aplikasi dasar.

**Contoh output:**

```text
Grant succeeded.
```

### 9.4 Beri quota tablespace

```sql
ALTER USER app_user QUOTA 500M ON users;
```

**Fungsi:** memberi batas ruang 500 MB pada tablespace `USERS`.

**Contoh output:**

```text
User altered.
```

### 9.5 Cek system privilege user

```sql
SELECT grantee, privilege
FROM dba_sys_privs
WHERE grantee = 'APP_USER'
ORDER BY privilege;
```

**Fungsi:** memverifikasi privilege sistem user.

**Contoh output:**

```text
GRANTEE   PRIVILEGE
--------  ----------------
APP_USER  CREATE PROCEDURE
APP_USER  CREATE SEQUENCE
APP_USER  CREATE SESSION
APP_USER  CREATE TABLE
APP_USER  CREATE VIEW
```

---

## 10. Object Privilege

Object privilege adalah hak terhadap object tertentu, misalnya table/view milik schema lain.

### 10.1 Beri hak SELECT pada tabel tertentu

```sql
GRANT SELECT ON hr.regions TO app_user;
```

**Fungsi:** memberi `APP_USER` hak membaca tabel `HR.REGIONS`.

**Contoh output:**

```text
Grant succeeded.
```

### 10.2 Cek object privilege

```sql
SELECT grantee, owner, table_name, privilege
FROM dba_tab_privs
WHERE grantee = 'APP_USER'
ORDER BY owner, table_name, privilege;
```

**Contoh output:**

```text
GRANTEE   OWNER  TABLE_NAME  PRIVILEGE
--------  -----  ----------  ---------
APP_USER  HR     REGIONS     SELECT
```

### 10.3 Cabut privilege

```sql
REVOKE SELECT ON hr.regions FROM app_user;
```

**Fungsi:** mencabut hak membaca tabel `HR.REGIONS`.

**Contoh output:**

```text
Revoke succeeded.
```

---

## 11. Role Administration

Role memudahkan pemberian privilege secara kelompok.

### 11.1 Buat role

```sql
CREATE ROLE app_readonly;
```

**Fungsi:** membuat role `APP_READONLY`.

**Contoh output:**

```text
Role created.
```

### 11.2 Grant privilege ke role

```sql
GRANT CREATE SESSION TO app_readonly;
GRANT SELECT ON hr.regions TO app_readonly;
```

**Fungsi:** memasukkan privilege ke role.

**Contoh output:**

```text
Grant succeeded.
Grant succeeded.
```

### 11.3 Grant role ke user

```sql
GRANT app_readonly TO app_user;
```

**Fungsi:** memberi role kepada user.

**Contoh output:**

```text
Grant succeeded.
```

### 11.4 Cek role user

```sql
SELECT grantee, granted_role
FROM dba_role_privs
WHERE grantee = 'APP_USER';
```

**Contoh output:**

```text
GRANTEE   GRANTED_ROLE
--------  ------------
APP_USER  APP_READONLY
```

---

## 12. Profile dan Password Policy

Profile digunakan untuk mengatur kebijakan password dan resource limit.

### 12.1 Cek profile default

```sql
SELECT profile, resource_name, limit
FROM dba_profiles
WHERE profile = 'DEFAULT'
ORDER BY resource_name;
```

**Fungsi:** melihat limit default user.

**Contoh output ringkas:**

```text
PROFILE  RESOURCE_NAME          LIMIT
-------  ---------------------  ---------
DEFAULT  FAILED_LOGIN_ATTEMPTS  10
DEFAULT  PASSWORD_LIFE_TIME     180
DEFAULT  SESSIONS_PER_USER      UNLIMITED
```

### 12.2 Buat profile baru

```sql
CREATE PROFILE app_profile LIMIT
  FAILED_LOGIN_ATTEMPTS 5
  PASSWORD_LIFE_TIME 90
  PASSWORD_REUSE_TIME 365
  SESSIONS_PER_USER 3
  IDLE_TIME 30;
```

**Fungsi:** membuat profile dengan batas password dan session.

**Contoh output:**

```text
Profile created.
```

### 12.3 Pasang profile ke user

```sql
ALTER USER app_user PROFILE app_profile;
```

**Fungsi:** menerapkan profile ke user.

**Contoh output:**

```text
User altered.
```

### 12.4 Verifikasi profile user

```sql
SELECT username, profile
FROM dba_users
WHERE username = 'APP_USER';
```

**Contoh output:**

```text
USERNAME  PROFILE
--------  -----------
APP_USER  APP_PROFILE
```

### 12.5 Catatan resource limit

Agar beberapa resource limit berjalan, parameter berikut harus aktif:

```sql
SHOW PARAMETER resource_limit;
```

**Contoh output:**

```text
NAME            TYPE     VALUE
--------------- -------- -----
resource_limit  boolean  TRUE
```

Jika belum aktif:

```sql
ALTER SYSTEM SET resource_limit = TRUE SCOPE=BOTH;
```

---

## 13. Session Management

### 13.1 Cek session aktif

```sql
SELECT sid, serial#, username, status, machine, program
FROM v$session
WHERE username IS NOT NULL
ORDER BY username, sid;
```

**Fungsi:** melihat user database yang sedang terkoneksi.

**Contoh output:**

```text
SID  SERIAL#  USERNAME  STATUS    MACHINE  PROGRAM
---  -------  --------  --------  -------  ----------------
35   4281     HR        ACTIVE    srv1     sqlplus@srv1
48   1152     APP_USER  INACTIVE  srv1     JDBC Thin Client
```

### 13.2 Kill session

```sql
ALTER SYSTEM KILL SESSION '48,1152' IMMEDIATE;
```

**Fungsi:** menghentikan session tertentu berdasarkan `SID,SERIAL#`.

**Contoh output:**

```text
System altered.
```

### 13.3 Disconnect session

```sql
ALTER SYSTEM DISCONNECT SESSION '48,1152' POST_TRANSACTION;
```

**Fungsi:** memutus session setelah transaksi berjalan selesai.

**Contoh output:**

```text
System altered.
```

**Catatan keamanan:** jangan kill session production tanpa memastikan dampak transaksi/aplikasi.

---

## 14. Oracle Net Services dan Listener

Alur koneksi dasar:

```text
Client -> Listener -> Server Process -> Instance -> Database/PDB
```

Listener dibutuhkan untuk koneksi awal. Setelah session terbentuk, komunikasi client berjalan dengan server process.

### 14.1 Cek status listener

```bash
lsnrctl status
```

**Fungsi:** melihat apakah listener aktif, port yang dipakai, service yang terdaftar, dan lokasi file log.

**Contoh output ringkas:**

```text
STATUS of the LISTENER
------------------------
Alias                     LISTENER
Version                   TNSLSNR for Linux: Version 19.0.0.0.0
Start Date                07-JUL-2026 08:00:10
Listener Parameter File   /u01/app/oracle/product/19.0.0/db_1/network/admin/listener.ora
Listener Log File         /u01/app/oracle/diag/tnslsnr/srv1/listener/alert/log.xml
Listening Endpoints Summary...
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=srv1.localdomain)(PORT=1521)))
Services Summary...
Service "oradb.localdomain" has 1 instance(s).
  Instance "oradb", status READY, has 1 handler(s) for this service...
Service "pdb1.localdomain" has 1 instance(s).
  Instance "oradb", status READY, has 1 handler(s) for this service...
```

### 14.2 Start, stop, reload listener

```bash
lsnrctl start
lsnrctl stop
lsnrctl reload
```

**Fungsi:**

| Command | Fungsi |
|---|---|
| `lsnrctl start` | Menjalankan listener default. |
| `lsnrctl stop` | Menghentikan listener default. |
| `lsnrctl reload` | Membaca ulang konfigurasi listener tanpa stop/start penuh. |

### 14.3 Monitor listener log

```bash
tail -f /u01/app/oracle/diag/tnslsnr/srv1/listener/trace/listener.log
```

**Fungsi:** memantau koneksi client secara real-time.

**Contoh output:**

```text
07-JUL-2026 09:21:03 * (CONNECT_DATA=(SERVICE_NAME=pdb1.localdomain)) * (ADDRESS=(PROTOCOL=tcp)(HOST=192.168.56.1)(PORT=53012)) * establish * pdb1.localdomain * 0
```

**Cara membaca:** ada client dari host `192.168.56.1` mencoba connect ke service `pdb1.localdomain`.

---

## 15. Network File Oracle

Lokasi umum:

```bash
cd $ORACLE_HOME/network/admin
ls -l
```

**Contoh output:**

```text
-rw-r--r-- 1 oracle oinstall  812 Jul  7 09:00 listener.ora
-rw-r--r-- 1 oracle oinstall 1320 Jul  7 09:05 tnsnames.ora
-rw-r--r-- 1 oracle oinstall  220 Jul  7 08:59 sqlnet.ora
```

| File | Fungsi |
|---|---|
| `listener.ora` | Konfigurasi listener di server. |
| `tnsnames.ora` | Alias koneksi database. |
| `sqlnet.ora` | Konfigurasi tambahan Oracle Net. |

### 15.1 Contoh alias PDB di tnsnames.ora

```text
PDB1 =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = srv1.localdomain)(PORT = 1521))
    (CONNECT_DATA =
      (SERVICE_NAME = pdb1.localdomain)
    )
  )
```

**Fungsi:** membuat alias `PDB1`, sehingga user dapat login dengan:

```bash
sqlplus hr/hr@PDB1
```

---

## 16. Easy Connect dan TNS Alias

### 16.1 Login dengan Easy Connect

```bash
sqlplus hr/hr@localhost:1521/pdb1.localdomain
```

**Fungsi:** login tanpa alias `tnsnames.ora`, langsung dengan format host:port/service.

**Contoh output:**

```text
Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
```

### 16.2 Login dengan alias TNS

```bash
sqlplus hr/hr@pdb1
```

**Fungsi:** login menggunakan alias yang didefinisikan di `tnsnames.ora`.

### 16.3 Test alias dengan tnsping

```bash
tnsping pdb1
```

**Fungsi:** mengecek apakah alias bisa di-resolve dan listener dapat dijangkau.

**Contoh output:**

```text
TNS Ping Utility for Linux: Version 19.0.0.0.0 - Production

Used parameter files:
/u01/app/oracle/product/19.0.0/db_1/network/admin/sqlnet.ora

Used TNSNAMES adapter to resolve the alias
Attempting to contact (DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=srv1.localdomain)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=pdb1.localdomain)))
OK (10 msec)
```

**Catatan penting:** `tnsping OK` belum tentu username/password benar. `tnsping` hanya membuktikan alias dan listener dapat dijangkau.

---

## 17. Password File dan Remote SYSDBA Login

Remote login sebagai `SYSDBA` membutuhkan password file.

### 17.1 Cek parameter password file

```sql
SHOW PARAMETER remote_login_passwordfile;
```

**Fungsi:** melihat apakah password file digunakan.

**Contoh output:**

```text
NAME                       TYPE    VALUE
-------------------------- ------- ---------
remote_login_passwordfile  string  EXCLUSIVE
```

### 17.2 Cek lokasi password file

```bash
cd $ORACLE_HOME/dbs
ls -l orapw*
```

**Fungsi:** melihat password file Oracle.

**Contoh output:**

```text
-rw-r----- 1 oracle oinstall 2048 Jul  7 09:30 orapworadb
```

**Pola nama:**

```text
orapw<SID>
```

Untuk SID `oradb`, file-nya `orapworadb`.

### 17.3 Login remote sebagai SYSDBA

```bash
sqlplus sys/oracle@localhost:1521/oradb.localdomain as sysdba
```

**Fungsi:** login SYSDBA melalui listener.

**Contoh output berhasil:**

```text
Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
```

### 17.4 Simulasi password file tidak tersedia

```bash
cd $ORACLE_HOME/dbs
mv orapworadb orapworadb.bak
```

Coba login remote:

```bash
sqlplus sys/oracle@localhost:1521/oradb.localdomain as sysdba
```

**Contoh output gagal:**

```text
ERROR:
ORA-01017: invalid username/password; logon denied
```

Kembalikan:

```bash
mv orapworadb.bak orapworadb
```

### 17.5 Membuat ulang password file

```bash
orapwd file=orapworadb password='Cakgup2026*' force=y
```

**Fungsi:** membuat password file baru dan overwrite file existing.

**Catatan:** gunakan tanda kutip jika password mengandung karakter khusus seperti `*`.

---

## 18. Membuat Alias dengan NETCA

```bash
netca
```

**Fungsi:** membuka Oracle Net Configuration Assistant untuk membuat alias koneksi secara wizard.

Urutan umum:

```text
Local Net Service Name configuration
-> Add
-> Service Name: pdb1.localdomain
-> Protocol: TCP
-> Host: srv1.localdomain atau localhost
-> Port: 1521
-> Test connection
-> Net Service Name: pdb1
-> Finish
```

Verifikasi:

```bash
tnsping pdb1
sqlplus hr/hr@pdb1
```

---

## 19. Membuat Listener Baru di Port Berbeda dengan NETMGR

Contoh dari catatan: listener baru bernama `KUPING` pada port `1522`.

### 19.1 Cek port lama dan port baru

```bash
netstat -an | grep 1521
netstat -an | grep 1522
```

Alternatif modern:

```bash
ss -ltnp | grep 1521
ss -ltnp | grep 1522
```

**Fungsi:** memastikan port listener aktif atau belum dipakai.

**Contoh output port 1521 aktif:**

```text
tcp6       0      0 :::1521                 :::*                    LISTEN
```

**Contoh jika port 1522 belum dipakai:** tidak ada output.

### 19.2 Jalankan Net Manager

```bash
netmgr
```

**Fungsi:** membuka Oracle Net Manager.

Langkah di GUI:

```text
Oracle Net Configuration
-> Local
-> Listeners
-> Add listener: KUPING
-> Listening Locations
-> Add Address
   Protocol : TCP/IP
   Host     : localhost
   Port     : 1522
-> Database Services
   Global Database Name : pdb1.localdomain
   Oracle Home Directory: /u01/app/oracle/product/19.0.0/db_1
   SID                  : oradb
-> File -> Save Network Configuration
```

**Catatan penting:** untuk PDB, service name dapat `pdb1.localdomain`, tetapi SID instance tetap `oradb`.

### 19.3 Start listener baru

```bash
lsnrctl start kuping
```

**Fungsi:** menjalankan listener bernama `kuping`.

**Contoh output ringkas:**

```text
Starting /u01/app/oracle/product/19.0.0/db_1/bin/tnslsnr: please wait...

TNSLSNR for Linux: Version 19.0.0.0.0 - Production
System parameter file is /u01/app/oracle/product/19.0.0/db_1/network/admin/listener.ora
Log messages written to /u01/app/oracle/diag/tnslsnr/srv1/kuping/alert/log.xml
Listening on: (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=localhost)(PORT=1522)))

The command completed successfully
```

### 19.4 Cek listener baru

```bash
lsnrctl status kuping
```

**Fungsi:** memastikan listener `kuping` aktif dan melayani port 1522.

**Contoh output ringkas:**

```text
Alias                     kuping
Listening Endpoints Summary...
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=localhost)(PORT=1522)))
Services Summary...
Service "pdb1.localdomain" has 1 instance(s).
  Instance "oradb", status READY, has 1 handler(s) for this service...
```

### 19.5 Login lewat port baru

```bash
sqlplus hr/hr@localhost:1522/pdb1.localdomain
```

**Fungsi:** menguji koneksi ke PDB melalui listener baru.

**Contoh output:**

```text
Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
```

---

## 20. Membuat Alias ke Port Baru

Tambahkan di `tnsnames.ora`:

```text
TETANGGAKU =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = 1522))
    (CONNECT_DATA =
      (SERVICE_NAME = pdb1.localdomain)
    )
  )
```

Tes alias:

```bash
tnsping tetanggaku
sqlplus hr/hr@tetanggaku
```

**Contoh output `tnsping`:**

```text
Attempting to contact (DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=localhost)(PORT=1522))(CONNECT_DATA=(SERVICE_NAME=pdb1.localdomain)))
OK (0 msec)
```

---

## 21. Memahami Listener Setelah Session Terbentuk

### 21.1 Stop listener baru

```bash
lsnrctl stop kuping
```

**Fungsi:** menghentikan listener `kuping`.

**Contoh output:**

```text
Connecting to (DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=localhost)(PORT=1522)))
The command completed successfully
```

### 21.2 Tes konsep

Jika SQL\*Plus sudah login sebelum listener dimatikan:

```sql
SELECT * FROM regions;
```

**Contoh output:**

```text
REGION_ID REGION_NAME
--------- -------------------------
        1 Europe
        2 Americas
        3 Asia
        4 Middle East and Africa
```

**Makna:** session lama masih bisa query karena listener hanya diperlukan saat koneksi awal. Jika session keluar lalu login lagi, koneksi akan gagal selama listener mati.

---

## 22. Troubleshooting Konektivitas

### 22.1 `ORA-12154: TNS:could not resolve the connect identifier specified`

**Makna:** alias tidak ditemukan atau salah di `tnsnames.ora`.

Cek:

```bash
cat $ORACLE_HOME/network/admin/tnsnames.ora
tnsping alias_yang_dipakai
```

### 22.2 `ORA-12514: TNS:listener does not currently know of service requested`

**Makna:** listener aktif, tetapi service name tidak terdaftar.

Cek:

```bash
lsnrctl status
```

Cek service dari database:

```sql
SHOW PARAMETER service_names;
SELECT name FROM v$services ORDER BY name;
```

### 22.3 `ORA-12541: TNS:no listener`

**Makna:** tidak ada listener di host/port tujuan.

Cek:

```bash
lsnrctl status
netstat -an | grep 1521
```

Solusi:

```bash
lsnrctl start
```

### 22.4 `ORA-01017: invalid username/password; logon denied`

**Makna:** username/password salah, account locked, atau password file bermasalah untuk SYSDBA remote.

Cek user biasa:

```sql
SELECT username, account_status FROM dba_users WHERE username = 'HR';
```

Cek password file:

```bash
cd $ORACLE_HOME/dbs
ls -l orapw*
```

---

# Appendix A - Preview Day 3 dari Catatan Praktik

Bagian ini berasal dari catatan pelatihan yang sudah Bapak susun, tetapi menurut silabus resmi lebih tepat dipelajari pada Day 3 - Storage and Data Management.

---

## A1. Controlfile

### A1.1 Cek controlfile

```sql
SHOW PARAMETER control_files;
SELECT name FROM v$controlfile;
```

**Fungsi:** melihat lokasi controlfile yang digunakan database.

**Contoh output:**

```text
NAME
----------------------------------------------------------
/u01/app/oracle/oradata/ORADB/control01.ctl
/u01/app/oracle/fra/ORADB/control02.ctl
```

**Catatan:** controlfile menyimpan metadata penting seperti DBID, lokasi datafile, lokasi redo log, checkpoint SCN, dan informasi recovery.

### A1.2 Alur aman menambah controlfile di lab

```sql
CREATE PFILE FROM SPFILE;
SHUTDOWN IMMEDIATE;
```

Dari OS:

```bash
mkdir -p /home/oracle/cfbaru
cp /u01/app/oracle/fra/ORADB/control02.ctl /home/oracle/cfbaru/control03.ctl
```

Edit PFILE:

```bash
vi $ORACLE_HOME/dbs/initoradb.ora
```

Tambahkan path controlfile baru pada parameter `control_files`, lalu:

```sql
CREATE SPFILE FROM PFILE;
STARTUP;
SELECT name FROM v$controlfile;
```

**Peringatan:** jangan lakukan penghapusan/controlfile experiment di production.

---

## A2. Redo Log File

### A2.1 Cek redo log member

```sql
SELECT group#, member
FROM v$logfile
ORDER BY group#;
```

**Fungsi:** melihat lokasi file redo log.

**Contoh output:**

```text
GROUP# MEMBER
------ --------------------------------------------------
1      /u01/app/oracle/oradata/ORADB/redo01.log
2      /u01/app/oracle/oradata/ORADB/redo02.log
3      /u01/app/oracle/oradata/ORADB/redo03.log
```

### A2.2 Cek ukuran dan status redo log

```sql
SELECT group#, bytes/1024/1024 AS mb, status
FROM v$log
ORDER BY group#;
```

**Contoh output:**

```text
GROUP#   MB  STATUS
------ ---- --------
1       200 INACTIVE
2       200 CURRENT
3       200 ACTIVE
```

**Makna status:**

| Status | Makna |
|---|---|
| `CURRENT` | Group sedang ditulis LGWR. |
| `ACTIVE` | Tidak sedang ditulis, tetapi masih diperlukan untuk recovery. |
| `INACTIVE` | Tidak sedang ditulis dan sudah tidak diperlukan untuk instance recovery. |
| `UNUSED` | Baru dibuat dan belum pernah digunakan. |

---

## A3. Mengaktifkan ARCHIVELOG Mode

```sql
ARCHIVE LOG LIST;
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;
ARCHIVE LOG LIST;
```

**Fungsi:** mengubah database dari `NOARCHIVELOG` ke `ARCHIVELOG`.

**Contoh output akhir:**

```text
Database log mode              Archive Mode
Automatic archival             Enabled
Archive destination            USE_DB_RECOVERY_FILE_DEST
Oldest online log sequence     12
Next log sequence to archive   14
Current log sequence           14
```

---

## A4. Switch Logfile dan Checkpoint

```sql
ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM CHECKPOINT;
SELECT group#, status FROM v$log ORDER BY group#;
```

**Fungsi:** memaksa perpindahan redo log dan melakukan checkpoint agar status redo log lebih mudah diamati.

**Contoh output:**

```text
GROUP# STATUS
------ --------
1      ACTIVE
2      CURRENT
3      INACTIVE
```

---

## A5. Menambah Redo Log Group

```sql
ALTER DATABASE ADD LOGFILE GROUP 4 SIZE 200M;
```

**Fungsi:** menambah redo log group baru dengan ukuran 200 MB.

**Contoh output:**

```text
Database altered.
```

Verifikasi:

```sql
SELECT group#, bytes/1024/1024 AS mb, status
FROM v$log
ORDER BY group#;

SELECT group#, member
FROM v$logfile
ORDER BY group#;
```

**Contoh output:**

```text
GROUP#   MB  STATUS
------ ---- --------
1       200 INACTIVE
2       200 CURRENT
3       200 ACTIVE
4       200 UNUSED
```

---

## 23. Lab Day 2 - Alur Praktik Sistematis

### A. Cek environment

```bash
env | grep ORACLE
cat /etc/oratab
ps -ef | grep pmon
```

### B. Login SYSDBA

```bash
sqlplus / as sysdba
```

### C. Latihan startup/shutdown

```sql
SELECT instance_name, status FROM v$instance;
SHUTDOWN IMMEDIATE;
STARTUP NOMOUNT;
ALTER DATABASE MOUNT;
ALTER DATABASE OPEN;
```

### D. Cek dan ubah parameter

```sql
SHOW PARAMETER spfile;
SHOW PARAMETER processes;
CREATE PFILE FROM SPFILE;
ALTER SYSTEM SET open_cursors = 500 SCOPE=BOTH;
```

### E. Kelola user dan privilege di PDB

```sql
ALTER SESSION SET CONTAINER = PDB1;
ALTER USER hr IDENTIFIED BY hr ACCOUNT UNLOCK;
GRANT CREATE SESSION TO hr;
CREATE USER app_user IDENTIFIED BY AppUser#2026 DEFAULT TABLESPACE users TEMPORARY TABLESPACE temp;
GRANT CREATE SESSION, CREATE TABLE TO app_user;
ALTER USER app_user QUOTA 500M ON users;
```

### F. Kelola role

```sql
CREATE ROLE app_readonly;
GRANT SELECT ON hr.regions TO app_readonly;
GRANT app_readonly TO app_user;
```

### G. Kelola profile

```sql
CREATE PROFILE app_profile LIMIT FAILED_LOGIN_ATTEMPTS 5 PASSWORD_LIFE_TIME 90 SESSIONS_PER_USER 3 IDLE_TIME 30;
ALTER USER app_user PROFILE app_profile;
SELECT username, profile FROM dba_users WHERE username = 'APP_USER';
```

### H. Monitoring session

```sql
SELECT sid, serial#, username, status, machine, program
FROM v$session
WHERE username IS NOT NULL
ORDER BY username, sid;
```

### I. Listener dan alias

```bash
lsnrctl status
cd $ORACLE_HOME/network/admin
cat tnsnames.ora
tnsping pdb1
sqlplus hr/hr@pdb1
```

### J. Remote SYSDBA dan password file

```bash
cd $ORACLE_HOME/dbs
ls -l orapw*
sqlplus sys/oracle@localhost:1521/oradb.localdomain as sysdba
```

### K. Listener port baru

```bash
netmgr
lsnrctl start kuping
lsnrctl status kuping
sqlplus hr/hr@localhost:1522/pdb1.localdomain
```

---

## 24. Checklist Kompetensi Day 2

```text
[ ] Saya bisa menjelaskan state NOMOUNT, MOUNT, dan OPEN.
[ ] Saya bisa melakukan startup bertahap dan startup langsung.
[ ] Saya bisa membedakan SHUTDOWN NORMAL, TRANSACTIONAL, IMMEDIATE, dan ABORT.
[ ] Saya bisa mengecek SPFILE/PFILE dan membuat PFILE dari SPFILE.
[ ] Saya paham arti SCOPE=MEMORY, SPFILE, dan BOTH.
[ ] Saya bisa mengecek parameter OMF/FRA.
[ ] Saya bisa membuat user di PDB yang benar.
[ ] Saya bisa memberi CREATE SESSION dan privilege lain kepada user.
[ ] Saya bisa membedakan system privilege dan object privilege.
[ ] Saya bisa membuat role dan memberikan role kepada user.
[ ] Saya bisa membuat profile dan memasangkannya ke user.
[ ] Saya bisa memonitor session dari v$session.
[ ] Saya bisa menjelaskan fungsi listener.
[ ] Saya bisa membaca tnsnames.ora.
[ ] Saya bisa membedakan tnsping dan sqlplus.
[ ] Saya bisa melakukan remote SYSDBA login dan memahami password file.
[ ] Saya bisa membuat/menguji listener port baru.
[ ] Saya bisa troubleshooting ORA-12154, ORA-12514, ORA-12541, dan ORA-01017.
```

---

## 25. Mini Latihan Ujian Lisan Day 2

1. Apa yang terjadi pada tahap `STARTUP NOMOUNT`?
2. Mengapa perubahan ARCHIVELOG harus dilakukan saat database `MOUNT`, bukan `OPEN`?
3. Apa beda `SHUTDOWN IMMEDIATE` dan `SHUTDOWN ABORT`?
4. Apa beda PFILE dan SPFILE?
5. Apa arti `SCOPE=BOTH` pada `ALTER SYSTEM SET`?
6. Mengapa user aplikasi sebaiknya dibuat di PDB, bukan CDB root?
7. Apa beda system privilege dan object privilege?
8. Mengapa role memudahkan administrasi privilege?
9. Apa fungsi profile?
10. Mengapa `tnsping OK` belum tentu `sqlplus` berhasil?
11. Apa fungsi password file?
12. Mengapa session lama masih bisa query setelah listener dimatikan?
13. Apa perbedaan SID dan service name?
14. Bagaimana cara mengecek service yang dikenal listener?
15. Apa yang harus dicek saat muncul `ORA-12514`?

---

## 26. Jawaban Singkat Mini Latihan

1. Instance hidup, SGA dibuat, background process berjalan, tetapi controlfile belum dibuka.
2. Karena perubahan mode archive dilakukan saat database belum open. Detail ini masuk materi storage/recovery.
3. `IMMEDIATE` melakukan proses shutdown lebih aman dengan rollback dan checkpoint; `ABORT` mematikan paksa dan butuh instance recovery saat startup berikutnya.
4. PFILE adalah text file yang bisa diedit manual; SPFILE adalah binary file yang umum dipakai Oracle saat startup.
5. Parameter diubah di memory dan SPFILE sekaligus.
6. Karena PDB adalah tempat database aplikasi berada; root dipakai untuk administrasi container.
7. System privilege adalah hak melakukan aksi database, object privilege adalah hak terhadap object tertentu.
8. Karena privilege bisa dikelompokkan dan diberikan/dicabut sebagai satu paket.
9. Mengatur password policy dan resource limit user.
10. Karena `tnsping` hanya mengecek alias/listener, bukan validasi user/password/privilege.
11. Untuk autentikasi remote user dengan privilege administrasi seperti SYSDBA/SYSOPER.
12. Karena listener hanya diperlukan untuk koneksi awal; session aktif berjalan melalui server process.
13. SID menunjuk instance, service name menunjuk layanan database/PDB yang didaftarkan ke listener.
14. Gunakan `lsnrctl status` atau query `SELECT name FROM v$services` dari database.
15. Cek service name di alias, `lsnrctl status`, `SHOW PARAMETER service_names`, dan daftar `v$services`.

---

## 27. Command Paling Penting Day 2

```bash
env | grep ORACLE
cat /etc/oratab
ps -ef | grep pmon
sqlplus / as sysdba
lsnrctl status
lsnrctl start
lsnrctl stop
lsnrctl reload
tnsping pdb1
cd $ORACLE_HOME/network/admin
cat tnsnames.ora
cd $ORACLE_HOME/dbs
ls -l orapw*
orapwd file=orapworadb password='PasswordBaru' force=y
netca
netmgr
lsnrctl start kuping
lsnrctl status kuping
```

```sql
CONN / AS SYSDBA
SHOW USER;
SHOW CON_NAME;
SHOW PDBS;
SELECT instance_name, status FROM v$instance;
SELECT name, open_mode FROM v$database;
STARTUP NOMOUNT;
ALTER DATABASE MOUNT;
ALTER DATABASE OPEN;
STARTUP;
SHUTDOWN IMMEDIATE;
SHUTDOWN ABORT;
SHOW PARAMETER spfile;
CREATE PFILE FROM SPFILE;
CREATE SPFILE FROM PFILE;
SHOW PARAMETER processes;
ALTER SYSTEM SET open_cursors = 500 SCOPE=BOTH;
ALTER SESSION SET CONTAINER = PDB1;
ALTER USER hr IDENTIFIED BY hr ACCOUNT UNLOCK;
GRANT CREATE SESSION TO hr;
CREATE USER app_user IDENTIFIED BY AppUser#2026 DEFAULT TABLESPACE users TEMPORARY TABLESPACE temp;
GRANT CREATE SESSION, CREATE TABLE TO app_user;
ALTER USER app_user QUOTA 500M ON users;
CREATE ROLE app_readonly;
GRANT SELECT ON hr.regions TO app_readonly;
GRANT app_readonly TO app_user;
CREATE PROFILE app_profile LIMIT FAILED_LOGIN_ATTEMPTS 5 PASSWORD_LIFE_TIME 90 SESSIONS_PER_USER 3 IDLE_TIME 30;
ALTER USER app_user PROFILE app_profile;
SELECT sid, serial#, username, status FROM v$session WHERE username IS NOT NULL;
SHOW PARAMETER remote_login_passwordfile;
SHOW PARAMETER service_names;
SELECT name FROM v$services ORDER BY name;
```

---

## 28. Catatan Keamanan Day 2

Command berikut aman untuk lab tetapi berisiko pada production:

```sql
SHUTDOWN ABORT;
ALTER SYSTEM SET processes = 400 SCOPE=SPFILE;
ALTER SYSTEM KILL SESSION 'sid,serial#' IMMEDIATE;
```

```bash
mv orapworadb orapworadb.bak
orapwd file=orapworadb password='PasswordBaru' force=y
lsnrctl stop
```

Praktik terbaik:

- Backup file konfigurasi sebelum edit.
- Jangan mengubah password file production tanpa koordinasi.
- Jangan stop listener production tanpa maintenance window.
- Jangan membuat user dengan privilege berlebihan.
- Terapkan prinsip least privilege.
- Selalu pastikan `SHOW CON_NAME` sebelum membuat user/role di environment multitenant.

Contoh backup file network:

```bash
cd $ORACLE_HOME/network/admin
cp listener.ora listener.ora.bak_$(date +%Y%m%d_%H%M%S)
cp tnsnames.ora tnsnames.ora.bak_$(date +%Y%m%d_%H%M%S)
cp sqlnet.ora sqlnet.ora.bak_$(date +%Y%m%d_%H%M%S)
```
