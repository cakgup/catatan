# Cheat Sheet Oracle Day 2 — Instance Administration, User, Resource, Network

**Topik silabus:** *Oracle Database Administration Fundamentals*  
**Fokus belajar:** startup/shutdown, state `NOMOUNT/MOUNT/OPEN`, parameter instance, PFILE/SPFILE, OMF, user dan privilege, role, profile/resource limit, session management, listener, TNS, dan troubleshooting konektivitas.


> **Catatan penggunaan:** contoh output pada file ini bersifat realistis untuk lab Oracle 19c, tetapi nilai seperti hostname, path, ukuran file, `SID`, `SERVICE_NAME`, `CON_ID`, `SQL_ID`, dan status dapat berbeda sesuai environment. Jalankan command berurutan, baca output-nya, lalu cocokkan dengan bagian *cara membaca output*.

> **Asumsi lab umum:** CDB `ORADB`, PDB `PDB1`, OS Oracle Linux, user OS `oracle`, Oracle Database 19c, path umum `/u01/app/oracle/oradata/ORADB`.


---

## 1. Peta Belajar Day 2

| Modul | Materi | Target praktik |
|---|---|---|
| Instance Administration | Startup/shutdown, parameter, OMF | Menyalakan/mematikan database dan mengelola parameter |
| User & Privilege | User/schema, system privilege, object privilege, role | Membuat user aplikasi dan memberi akses tepat |
| Resource Management | Profile, password policy, quota, session limit | Membatasi resource user dan memonitor session |
| Connectivity | Listener, TNS, Easy Connect, password file | Membuat koneksi client dan troubleshooting ORA network |

---

## 2. Persiapan Environment

```bash
su - oracle
env | grep ORACLE
cat /etc/oratab
ps -ef | grep pmon
sqlplus / as sysdba
```

**Contoh output `ps -ef | grep pmon`:**

```text
oracle 2234 1 0 08:00 ? 00:00:00 ora_pmon_ORADB
```

Makna: instance `ORADB` sedang hidup.

---

## 3. Startup dan Shutdown Database

### 3.1 Cek status awal

```sql
SELECT instance_name, status FROM v$instance;
SELECT name, open_mode FROM v$database;
SHOW PDBS;
```

**Contoh output:**

```text
INSTANCE_NAME STATUS
------------- ------------
ORADB         OPEN

NAME  OPEN_MODE
----- ----------
ORADB READ WRITE
```

### 3.2 Shutdown immediate

```sql
SHUTDOWN IMMEDIATE;
```

**Fungsi:** mematikan database dengan aman, melakukan rollback transaksi belum commit, lalu checkpoint.

**Contoh output:**

```text
Database closed.
Database dismounted.
ORACLE instance shut down.
```

### 3.3 Startup langsung

```sql
STARTUP;
```

**Contoh output:**

```text
ORACLE instance started.
Database mounted.
Database opened.
```

### 3.4 Startup bertahap

```sql
STARTUP NOMOUNT;
ALTER DATABASE MOUNT;
ALTER DATABASE OPEN;
```

| Tahap | Apa yang terjadi | Verifikasi |
|---|---|---|
| `NOMOUNT` | Baca parameter file, buat SGA, start process | `v$instance.status = STARTED` |
| `MOUNT` | Baca control file | `v$database.open_mode = MOUNTED` |
| `OPEN` | Buka datafile dan redo log | `open_mode = READ WRITE` |

### 3.5 Buka PDB setelah startup

```sql
SHOW PDBS;
ALTER PLUGGABLE DATABASE ALL OPEN;
ALTER PLUGGABLE DATABASE PDB1 SAVE STATE;
```

**Fungsi:** membuka PDB dan menyimpan state agar otomatis open setelah restart.

---

## 4. Parameter, PFILE, dan SPFILE

### 4.1 Cek parameter penting

```sql
SHOW PARAMETER spfile;
SHOW PARAMETER db_name;
SHOW PARAMETER instance_name;
SHOW PARAMETER control_files;
SHOW PARAMETER processes;
SHOW PARAMETER sessions;
SHOW PARAMETER open_cursors;
SHOW PARAMETER sga_target;
SHOW PARAMETER pga_aggregate_target;
```

**Contoh output `SHOW PARAMETER spfile`:**

```text
NAME    TYPE    VALUE
------- ------- --------------------------------------------------
spfile  string  /u01/app/oracle/product/19.0.0/dbhome_1/dbs/spfileORADB.ora
```

### 4.2 Lihat parameter dari `v$parameter`

```sql
COL name FORMAT A35
COL value FORMAT A50
COL issys_modifiable FORMAT A15
COL ispdb_modifiable FORMAT A15

SELECT name, value, issys_modifiable, ispdb_modifiable
FROM v$parameter
WHERE name IN ('open_cursors','processes','sessions','sga_target','pga_aggregate_target','undo_retention')
ORDER BY name;
```

**Cara membaca `ISSYS_MODIFIABLE`:**

| Nilai | Makna |
|---|---|
| `IMMEDIATE` | Bisa diubah langsung |
| `DEFERRED` | Berlaku untuk session baru |
| `FALSE` | Perlu restart instance |

### 4.3 Membuat PFILE dari SPFILE

```sql
CREATE PFILE='/u01/backup/parameter_file/initORADB_from_spfile.ora'
FROM SPFILE;
```

**Fungsi:** membuat parameter file text sebagai backup/untuk diedit manual.

**Contoh output:**

```text
File created.
```

### 4.4 Membuat SPFILE dari PFILE

```sql
CREATE SPFILE='/u01/backup/parameter_file/spfileORADB_new.ora'
FROM PFILE='/u01/backup/parameter_file/initORADB_from_spfile.ora';
```

**Fungsi:** membuat SPFILE binary dari PFILE.

### 4.5 Mengubah parameter dengan scope

```sql
ALTER SYSTEM SET open_cursors = 500 SCOPE=MEMORY;
ALTER SYSTEM SET open_cursors = 500 SCOPE=SPFILE;
ALTER SYSTEM SET open_cursors = 400 SCOPE=BOTH;
```

| Scope | Efek | Hilang setelah restart? |
|---|---|---|
| `MEMORY` | Langsung di memory | Ya |
| `SPFILE` | Ditulis ke SPFILE | Tidak, tetapi perlu restart |
| `BOTH` | Memory + SPFILE | Tidak |

### 4.6 Parameter static: `processes`

```sql
SHOW PARAMETER processes;
ALTER SYSTEM SET processes = 400 SCOPE=SPFILE;
SHUTDOWN IMMEDIATE;
STARTUP;
```

**Catatan:** `processes` static, sehingga perubahan berlaku setelah restart.

---

## 5. Oracle Managed Files (OMF)

### 5.1 Cek OMF

```sql
SHOW PARAMETER db_create_file_dest;
SHOW PARAMETER db_recovery_file_dest;
```

**Contoh output:**

```text
db_create_file_dest    string /u01/app/oracle/oradata
db_recovery_file_dest  string /u01/app/oracle/fra
```

### 5.2 Set OMF

```sql
ALTER SYSTEM SET db_create_file_dest='/u01/app/oracle/oradata' SCOPE=BOTH;
```

### 5.3 Buat tablespace tanpa path eksplisit

```sql
ALTER SESSION SET CONTAINER=PDB1;
CREATE TABLESPACE app_data DATAFILE SIZE 100M AUTOEXTEND ON NEXT 50M MAXSIZE 1G;
```

**Fungsi:** Oracle otomatis membuat nama file karena OMF aktif.

---

## 6. User, Schema, Privilege, Role

### 6.1 Prinsip user CDB/PDB

| Jenis user | Dibuat di | Aturan | Contoh |
|---|---|---|---|
| Common user | `CDB$ROOT` | Nama wajib diawali `C##` | `C##ADMIN` |
| Local user | PDB | Nama bebas | `APP_OWNER` |

**Best practice:** user aplikasi dibuat sebagai **local user di PDB**, bukan di CDB root.

### 6.2 Buat tablespace user lab

```sql
ALTER SESSION SET CONTAINER=PDB1;

CREATE TABLESPACE TS_USER_LAB
DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/ts_user_lab01.dbf'
SIZE 100M AUTOEXTEND ON NEXT 50M MAXSIZE 1G;
```

### 6.3 Buat local user

```sql
CREATE USER app_owner IDENTIFIED BY oracle
DEFAULT TABLESPACE TS_USER_LAB
TEMPORARY TABLESPACE TEMP
QUOTA UNLIMITED ON TS_USER_LAB;
```

**Contoh output:**

```text
User created.
```

### 6.4 Test login sebelum privilege

```bash
sqlplus app_owner/oracle@localhost:1521/pdb1.localdomain
```

**Contoh error:**

```text
ORA-01045: user APP_OWNER lacks CREATE SESSION privilege; logon denied
```

### 6.5 Grant system privilege

```sql
GRANT CREATE SESSION TO app_owner;
GRANT CREATE TABLE TO app_owner;
```

**Fungsi:** memberi hak login dan membuat table.

Verifikasi:

```sql
SELECT grantee, privilege
FROM dba_sys_privs
WHERE grantee='APP_OWNER'
ORDER BY privilege;
```

### 6.6 Object privilege

Misal `APP_OWNER` punya tabel `PELANGGAN`, beri user lain hak baca:

```sql
CONN app_owner/oracle@localhost:1521/pdb1.localdomain
GRANT SELECT ON pelanggan TO app_read;
```

Verifikasi dari SYS:

```sql
SELECT owner, table_name, grantee, privilege
FROM dba_tab_privs
WHERE owner='APP_OWNER'
AND table_name='PELANGGAN';
```

### 6.7 Role lokal

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;
CREATE ROLE role_app_read;
CREATE ROLE role_app_dml;

CONN app_owner/oracle@localhost:1521/pdb1.localdomain
GRANT SELECT ON pelanggan TO role_app_read;
GRANT SELECT, INSERT, UPDATE, DELETE ON pelanggan TO role_app_dml;

CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;
GRANT role_app_read TO app_read;
GRANT role_app_dml TO app_dev;
```

**Fungsi:** mengelompokkan privilege agar lebih mudah dikelola.

---

## 7. Profile, Password Policy, Resource Limit, Quota

### 7.1 Aktifkan resource limit

```sql
SHOW PARAMETER resource_limit;
ALTER SYSTEM SET resource_limit = TRUE SCOPE=BOTH;
```

**Contoh output:**

```text
resource_limit boolean TRUE
```

### 7.2 Buat profile

```sql
CREATE PROFILE profile_rsrc_lab LIMIT
  SESSIONS_PER_USER 2
  IDLE_TIME 5
  CONNECT_TIME 60
  FAILED_LOGIN_ATTEMPTS 3
  PASSWORD_LOCK_TIME 1;
```

| Parameter | Fungsi |
|---|---|
| `SESSIONS_PER_USER` | Maksimal session paralel per user |
| `IDLE_TIME` | Maksimal idle dalam menit |
| `CONNECT_TIME` | Maksimal lama koneksi dalam menit |
| `FAILED_LOGIN_ATTEMPTS` | Batas gagal login sebelum lock |
| `PASSWORD_LOCK_TIME` | Lama user terkunci |

### 7.3 Assign profile ke user

```sql
ALTER USER app_owner PROFILE profile_rsrc_lab;

SELECT username, profile
FROM dba_users
WHERE username='APP_OWNER';
```

### 7.4 Quota tablespace

```sql
ALTER USER app_owner QUOTA 100M ON TS_USER_LAB;

SELECT username, tablespace_name,
       bytes/1024/1024 AS used_mb,
       max_bytes/1024/1024 AS max_mb
FROM dba_ts_quotas
WHERE username='APP_OWNER';
```

**Catatan:** `MAX_MB = -1` biasanya berarti unlimited quota.

---

## 8. Session Management

### 8.1 Monitoring session aktif

```sql
SELECT sid, serial#, username, status, machine, program
FROM v$session
WHERE username IS NOT NULL
ORDER BY username, sid;
```

**Contoh output:**

```text
SID SERIAL# USERNAME  STATUS    MACHINE    PROGRAM
--- ------- --------- --------- ---------- ----------------
35  4281    HR        ACTIVE    server01   sqlplus@server01
48  1152    APP_USER  INACTIVE  app01      JDBC Thin Client
```

### 8.2 Kill session

```sql
ALTER SYSTEM KILL SESSION '48,1152' IMMEDIATE;
```

**Fungsi:** menghentikan session berdasarkan `SID,SERIAL#`.

---

## 9. Oracle Net, Listener, TNS

### 9.1 Alur koneksi

```text
Client -> tnsnames/Easy Connect -> Listener -> Server Process -> Instance -> Service/PDB
```

### 9.2 Cek listener

```bash
lsnrctl status
lsnrctl services
```

**Contoh output ringkas:**

```text
Listening Endpoints Summary...
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=localhost)(PORT=1521)))
Services Summary...
Service "ORADB" has 1 instance(s).
Service "PDB1" has 1 instance(s).
```

### 9.3 Start/stop/reload listener

```bash
lsnrctl start
lsnrctl stop
lsnrctl reload
```

### 9.4 File network penting

```bash
cd $ORACLE_HOME/network/admin
ls -l listener.ora tnsnames.ora sqlnet.ora
```

| File | Fungsi |
|---|---|
| `listener.ora` | Konfigurasi listener server |
| `tnsnames.ora` | Alias koneksi client |
| `sqlnet.ora` | Naming method, autentikasi, konfigurasi tambahan |

### 9.5 Contoh alias `tnsnames.ora`

```text
PDB1 =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = PDB1)
    )
  )
```

Test alias:

```bash
tnsping PDB1
sqlplus app_owner/oracle@PDB1
```

### 9.6 Easy Connect

```bash
sqlplus app_owner/oracle@localhost:1521/pdb1.localdomain
```

**Fungsi:** login tanpa alias `tnsnames.ora`.

### 9.7 Register service ke listener

```sql
ALTER SYSTEM SET local_listener='(ADDRESS=(PROTOCOL=TCP)(HOST=localhost)(PORT=1521))' SCOPE=BOTH;
ALTER SYSTEM REGISTER;
```

---

## 10. Password File dan Remote SYSDBA

### 10.1 Cek parameter

```sql
SHOW PARAMETER remote_login_passwordfile;
```

**Contoh output:**

```text
remote_login_passwordfile string EXCLUSIVE
```

### 10.2 Cek file password

```bash
cd $ORACLE_HOME/dbs
ls -l orapw*
```

**Contoh output:**

```text
-rw-r-----. 1 oracle oinstall 2048 Jul 11 09:00 orapwORADB
```

### 10.3 Buat ulang password file

```bash
orapwd file=orapwORADB password='Oracle#2026' force=y
```

### 10.4 Login remote SYSDBA

```bash
sqlplus sys/Oracle#2026@localhost:1521/oradb.localdomain as sysdba
```

---

## 11. Troubleshooting Konektivitas

| Error | Arti | Cek/Solusi |
|---|---|---|
| `ORA-12154` | Alias TNS tidak ditemukan | Cek `tnsnames.ora`, `TNS_ADMIN`, `tnsping alias` |
| `ORA-12541` | Listener tidak aktif di host/port | `lsnrctl status`, `lsnrctl start` |
| `ORA-12514` | Listener tidak mengenal service | `lsnrctl services`, `ALTER SYSTEM REGISTER` |
| `ORA-01017` | Password salah / password file bermasalah | Cek user status, password file |
| `ORA-01045` | User belum punya `CREATE SESSION` | `GRANT CREATE SESSION TO user;` |
| `ORA-02391` | Melebihi `SESSIONS_PER_USER` | Cek profile dan session aktif |

---

## 12. Lab Berurutan Day 2

```sql
-- Instance
CONN / AS SYSDBA
SELECT instance_name, status FROM v$instance;
SHUTDOWN IMMEDIATE;
STARTUP NOMOUNT;
ALTER DATABASE MOUNT;
ALTER DATABASE OPEN;
ALTER PLUGGABLE DATABASE ALL OPEN;

-- Parameter
SHOW PARAMETER spfile;
CREATE PFILE='/u01/backup/parameter_file/initORADB_from_spfile.ora' FROM SPFILE;
SHOW PARAMETER open_cursors;
ALTER SYSTEM SET open_cursors=400 SCOPE=BOTH;

-- User dan role
ALTER SESSION SET CONTAINER=PDB1;
CREATE TABLESPACE TS_USER_LAB DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/ts_user_lab01.dbf' SIZE 100M AUTOEXTEND ON NEXT 50M MAXSIZE 1G;
CREATE USER app_owner IDENTIFIED BY oracle DEFAULT TABLESPACE TS_USER_LAB TEMPORARY TABLESPACE TEMP QUOTA UNLIMITED ON TS_USER_LAB;
GRANT CREATE SESSION, CREATE TABLE TO app_owner;
CREATE ROLE role_app_read;

-- Resource
ALTER SYSTEM SET resource_limit=TRUE SCOPE=BOTH;
CREATE PROFILE profile_rsrc_lab LIMIT SESSIONS_PER_USER 2 IDLE_TIME 5 CONNECT_TIME 60 FAILED_LOGIN_ATTEMPTS 3 PASSWORD_LOCK_TIME 1;
ALTER USER app_owner PROFILE profile_rsrc_lab;

-- Session
SELECT sid, serial#, username, status, machine, program FROM v$session WHERE username IS NOT NULL;
```

```bash
# Network
lsnrctl status
lsnrctl services
cd $ORACLE_HOME/network/admin
cat tnsnames.ora
tnsping PDB1
sqlplus app_owner/oracle@localhost:1521/pdb1.localdomain
```

---

## 13. Checklist Kompetensi Day 2

```text
[ ] Saya bisa menjelaskan NOMOUNT, MOUNT, OPEN.
[ ] Saya bisa menjalankan startup bertahap dan shutdown immediate.
[ ] Saya bisa membedakan PFILE dan SPFILE.
[ ] Saya bisa mengubah parameter dengan MEMORY, SPFILE, BOTH.
[ ] Saya paham OMF dan db_create_file_dest.
[ ] Saya bisa membuat local user di PDB.
[ ] Saya bisa memberi system privilege dan object privilege.
[ ] Saya bisa membuat role dan grant role ke user.
[ ] Saya bisa mengatur profile, quota, dan resource limit.
[ ] Saya bisa memonitor dan kill session.
[ ] Saya bisa membaca listener.ora dan tnsnames.ora.
[ ] Saya bisa troubleshooting ORA-12154, ORA-12514, ORA-12541, ORA-01017.
```

---

## 14. Mini Latihan Ujian Lisan

1. Apa yang terjadi pada `STARTUP NOMOUNT`?
2. Apa beda PFILE dan SPFILE?
3. Kapan memakai `SCOPE=SPFILE`?
4. Mengapa user aplikasi sebaiknya dibuat di PDB?
5. Apa beda system privilege dan object privilege?
6. Apa fungsi role?
7. Apa fungsi profile?
8. Mengapa `tnsping OK` belum tentu `sqlplus` berhasil?
9. Apa fungsi listener?
10. Apa fungsi password file?

### Jawaban singkat

1. Instance hidup, SGA dibuat, background process jalan, controlfile belum dibaca.
2. PFILE text bisa diedit; SPFILE binary dipakai Oracle untuk startup.
3. Untuk parameter static atau perubahan yang ingin berlaku setelah restart.
4. Karena PDB adalah lokasi database aplikasi; root untuk administrasi CDB.
5. System privilege memberi hak aksi database; object privilege memberi hak atas object tertentu.
6. Role mengelompokkan privilege agar mudah diberikan/dicabut.
7. Mengatur password policy dan resource limit.
8. Karena `tnsping` hanya mengecek alias/listener, bukan user/password/privilege.
9. Menerima koneksi awal client dan mengarahkan ke service database.
10. Autentikasi remote SYSDBA/SYSOPER.
