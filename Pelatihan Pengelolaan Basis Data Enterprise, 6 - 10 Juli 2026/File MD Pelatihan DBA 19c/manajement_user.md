# HANDS-ON LAB

# User, Privileges & Role Management Oracle 19c CDB/PDB

Asumsi:

```text
CDB     : ORADB
PDB     : PDB1
OS      : Oracle Linux
Oracle  : 19c
User OS : oracle
```

Catatan penting:

```text
1. Common user dibuat dari CDB$ROOT dan namanya wajib diawali C##.
2. Local user dibuat di dalam PDB.
3. Common role dibuat dari CDB$ROOT dan namanya wajib diawali C##.
4. Local role dibuat di dalam PDB.
5. User aplikasi sebaiknya dibuat sebagai local user di PDB, bukan di CDB$ROOT.
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

Verifikasi container aktif:

```sql
SHOW CON_NAME
```

Contoh output:

```text
CON_NAME
------------------------------
CDB$ROOT
```

Lihat PDB:

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

Jika PDB belum open:

```sql
ALTER PLUGGABLE DATABASE PDB1 OPEN;
```

---

# LAB 1 — Melihat User Existing di CDB dan PDB

## 1.1 Lihat user dari root

```sql
CONN / AS SYSDBA

SET LINESIZE 200
COLUMN username FORMAT A25
COLUMN common FORMAT A8
COLUMN account_status FORMAT A20
COLUMN con_id FORMAT 999

SELECT con_id,
       username,
       common,
       account_status
FROM cdb_users
WHERE username IN ('SYS','SYSTEM')
ORDER BY con_id, username;
```

Contoh output:

```text
CON_ID USERNAME                  COMMON   ACCOUNT_STATUS
------ ------------------------- -------- --------------------
     1 SYS                       YES      OPEN
     1 SYSTEM                    YES      OPEN
     3 SYS                       YES      OPEN
     3 SYSTEM                    YES      OPEN
```

## 1.2 Masuk ke PDB1

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

## 1.3 Lihat user di PDB1

```sql
COLUMN username FORMAT A25
COLUMN account_status FORMAT A20
COLUMN default_tablespace FORMAT A20
COLUMN temporary_tablespace FORMAT A20

SELECT username,
       account_status,
       default_tablespace,
       temporary_tablespace,
       common
FROM dba_users
ORDER BY username;
```

Contoh output:

```text
USERNAME                  ACCOUNT_STATUS       DEFAULT_TABLESPACE   TEMPORARY_TABLESPACE COMMON
------------------------- -------------------- -------------------- -------------------- ------
APPQOSSYS                 EXPIRED & LOCKED     SYSAUX               TEMP                 YES
PDBADMIN                  OPEN                 USERS                TEMP                 NO
SYS                       OPEN                 SYSTEM               TEMP                 YES
SYSTEM                    OPEN                 SYSTEM               TEMP                 YES
```

---

# LAB 2 — Membuat Tablespace untuk User Lab

Jalankan di PDB1.

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;
```

Buat tablespace:

```sql
CREATE TABLESPACE TS_USER_LAB
DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/ts_user_lab01.dbf'
SIZE 100M
AUTOEXTEND ON
NEXT 50M
MAXSIZE 1G;
```

Contoh output:

```text
Tablespace created.
```

Verifikasi:

```sql
SELECT tablespace_name,
       file_name,
       bytes/1024/1024 AS size_mb,
       autoextensible
FROM dba_data_files
WHERE tablespace_name = 'TS_USER_LAB';
```

Contoh output:

```text
TABLESPACE_NAME      FILE_NAME                                                     SIZE_MB AUTOEXTENSIBLE
-------------------- ------------------------------------------------------------- ------- --------------
TS_USER_LAB          /u01/app/oracle/oradata/ORADB/pdb1/ts_user_lab01.dbf              100 YES
```

---

# LAB 3 — Membuat Local User di PDB

## 3.1 Buat user lokal

```sql
CREATE USER app_owner IDENTIFIED BY oracle
DEFAULT TABLESPACE TS_USER_LAB
TEMPORARY TABLESPACE TEMP
QUOTA UNLIMITED ON TS_USER_LAB;
```

Contoh output:

```text
User created.
```

Buat user aplikasi lain:

```sql
CREATE USER app_read IDENTIFIED BY oracle
DEFAULT TABLESPACE TS_USER_LAB
TEMPORARY TABLESPACE TEMP
QUOTA 20M ON TS_USER_LAB;
```

Contoh output:

```text
User created.
```

Buat user developer:

```sql
CREATE USER app_dev IDENTIFIED BY oracle
DEFAULT TABLESPACE TS_USER_LAB
TEMPORARY TABLESPACE TEMP
QUOTA 50M ON TS_USER_LAB;
```

Contoh output:

```text
User created.
```

## 3.2 Verifikasi user

```sql
SELECT username,
       account_status,
       default_tablespace,
       temporary_tablespace,
       common
FROM dba_users
WHERE username IN ('APP_OWNER','APP_READ','APP_DEV')
ORDER BY username;
```

Contoh output:

```text
USERNAME                  ACCOUNT_STATUS       DEFAULT_TABLESPACE   TEMPORARY_TABLESPACE COMMON
------------------------- -------------------- -------------------- -------------------- ------
APP_DEV                   OPEN                 TS_USER_LAB          TEMP                 NO
APP_OWNER                 OPEN                 TS_USER_LAB          TEMP                 NO
APP_READ                  OPEN                 TS_USER_LAB          TEMP                 NO
```

## 3.3 Verifikasi quota user

```sql
COLUMN username FORMAT A20
COLUMN tablespace_name FORMAT A20

SELECT username,
       tablespace_name,
       bytes/1024/1024 AS used_mb,
       max_bytes/1024/1024 AS max_mb
FROM dba_ts_quotas
WHERE username IN ('APP_OWNER','APP_READ','APP_DEV')
ORDER BY username;
```

Contoh output:

```text
USERNAME             TABLESPACE_NAME         USED_MB     MAX_MB
-------------------- -------------------- ---------- ----------
APP_DEV              TS_USER_LAB                  0         50
APP_OWNER            TS_USER_LAB                  0         -1
APP_READ             TS_USER_LAB                  0         20
```

Catatan:

```text
MAX_MB = -1 berarti UNLIMITED quota.
```

---

# LAB 4 — Login Sebelum Diberi Privilege

Coba login sebagai `app_owner`.

```bash
sqlplus app_owner/oracle@localhost:1521/pdb1.localdomain
```

Contoh error:

```text
ERROR:
ORA-01045: user APP_OWNER lacks CREATE SESSION privilege; logon denied
```

Artinya user sudah ada, tetapi belum boleh login karena belum punya privilege `CREATE SESSION`.

---

# LAB 5 — Grant System Privilege

## 5.1 Grant CREATE SESSION

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

GRANT CREATE SESSION TO app_owner;
GRANT CREATE SESSION TO app_read;
GRANT CREATE SESSION TO app_dev;
```

Contoh output:

```text
Grant succeeded.
Grant succeeded.
Grant succeeded.
```

## 5.2 Verifikasi system privilege

```sql
SELECT grantee,
       privilege,
       admin_option
FROM dba_sys_privs
WHERE grantee IN ('APP_OWNER','APP_READ','APP_DEV')
ORDER BY grantee, privilege;
```

Contoh output:

```text
GRANTEE              PRIVILEGE            ADMIN_OPTION
-------------------- -------------------- ------------
APP_DEV              CREATE SESSION       NO
APP_OWNER            CREATE SESSION       NO
APP_READ             CREATE SESSION       NO
```

## 5.3 Test login

```bash
sqlplus app_owner/oracle@localhost:1521/pdb1.localdomain
```

Contoh output:

```text
Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0
```

Verifikasi:

```sql
SHOW USER
SHOW CON_NAME
```

Contoh output:

```text
USER is "APP_OWNER"

CON_NAME
------------------------------
PDB1
```

---

# LAB 6 — Grant Privilege untuk Membuat Object

## 6.1 Coba create table tanpa privilege

```sql
CONN app_owner/oracle@localhost:1521/pdb1.localdomain

CREATE TABLE pelanggan (
    id_pelanggan NUMBER PRIMARY KEY,
    nama         VARCHAR2(100),
    kota         VARCHAR2(50)
);
```

Contoh error:

```text
ORA-01031: insufficient privileges
```

## 6.2 Grant CREATE TABLE

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

GRANT CREATE TABLE TO app_owner;
```

Contoh output:

```text
Grant succeeded.
```

## 6.3 Verifikasi

```sql
SELECT grantee,
       privilege
FROM dba_sys_privs
WHERE grantee = 'APP_OWNER'
ORDER BY privilege;
```

Contoh output:

```text
GRANTEE              PRIVILEGE
-------------------- --------------------
APP_OWNER            CREATE SESSION
APP_OWNER            CREATE TABLE
```

## 6.4 Coba create table ulang

```sql
CONN app_owner/oracle@localhost:1521/pdb1.localdomain

CREATE TABLE pelanggan (
    id_pelanggan NUMBER PRIMARY KEY,
    nama         VARCHAR2(100),
    kota         VARCHAR2(50)
);
```

Contoh output:

```text
Table created.
```

Insert data:

```sql
INSERT INTO pelanggan VALUES (1, 'Andi', 'Jakarta');
INSERT INTO pelanggan VALUES (2, 'Budi', 'Bandung');
INSERT INTO pelanggan VALUES (3, 'Candra', 'Surabaya');
COMMIT;
```

Contoh output:

```text
1 row created.
1 row created.
1 row created.

Commit complete.
```

Verifikasi:

```sql
SELECT * FROM pelanggan;
```

Contoh output:

```text
ID_PELANGGAN NAMA                 KOTA
------------ -------------------- --------------------
           1 Andi                 Jakarta
           2 Budi                 Bandung
           3 Candra               Surabaya
```

---

# LAB 7 — Object Privilege: GRANT SELECT

## 7.1 Coba akses tabel dari user lain

```sql
CONN app_read/oracle@localhost:1521/pdb1.localdomain

SELECT * FROM app_owner.pelanggan;
```

Contoh error:

```text
ORA-00942: table or view does not exist
```

## 7.2 Grant SELECT dari owner

```sql
CONN app_owner/oracle@localhost:1521/pdb1.localdomain

GRANT SELECT ON pelanggan TO app_read;
```

Contoh output:

```text
Grant succeeded.
```

## 7.3 Verifikasi object privilege

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

SELECT owner,
       table_name,
       grantee,
       privilege,
       grantable
FROM dba_tab_privs
WHERE owner = 'APP_OWNER'
AND table_name = 'PELANGGAN'
ORDER BY grantee, privilege;
```

Contoh output:

```text
OWNER       TABLE_NAME      GRANTEE      PRIVILEGE  GRANTABLE
----------- --------------- ------------ ---------- ----------
APP_OWNER   PELANGGAN       APP_READ     SELECT     NO
```

## 7.4 Test SELECT dari app_read

```sql
CONN app_read/oracle@localhost:1521/pdb1.localdomain

SELECT * FROM app_owner.pelanggan;
```

Contoh output:

```text
ID_PELANGGAN NAMA                 KOTA
------------ -------------------- --------------------
           1 Andi                 Jakarta
           2 Budi                 Bandung
           3 Candra               Surabaya
```

---

# LAB 8 — Object Privilege: INSERT, UPDATE, DELETE

## 8.1 Coba insert dari app_read

```sql
CONN app_read/oracle@localhost:1521/pdb1.localdomain

INSERT INTO app_owner.pelanggan
VALUES (4, 'Dedi', 'Medan');
```

Contoh error:

```text
ORA-01031: insufficient privileges
```

## 8.2 Grant INSERT dan UPDATE

```sql
CONN app_owner/oracle@localhost:1521/pdb1.localdomain

GRANT INSERT, UPDATE ON pelanggan TO app_dev;
```

Contoh output:

```text
Grant succeeded.
```

## 8.3 Test insert dari app_dev

```sql
CONN app_dev/oracle@localhost:1521/pdb1.localdomain

INSERT INTO app_owner.pelanggan
VALUES (4, 'Dedi', 'Medan');

COMMIT;
```

Contoh output:

```text
1 row created.

Commit complete.
```

## 8.4 Test update dari app_dev

```sql
UPDATE app_owner.pelanggan
SET kota = 'Yogyakarta'
WHERE id_pelanggan = 4;

COMMIT;
```

Contoh output:

```text
1 row updated.

Commit complete.
```

## 8.5 Verifikasi dari app_owner

```sql
CONN app_owner/oracle@localhost:1521/pdb1.localdomain

SELECT * FROM pelanggan ORDER BY id_pelanggan;
```

Contoh output:

```text
ID_PELANGGAN NAMA                 KOTA
------------ -------------------- --------------------
           1 Andi                 Jakarta
           2 Budi                 Bandung
           3 Candra               Surabaya
           4 Dedi                 Yogyakarta
```

---

# LAB 9 — Revoke Object Privilege

## 9.1 Revoke UPDATE dari app_dev

```sql
CONN app_owner/oracle@localhost:1521/pdb1.localdomain

REVOKE UPDATE ON pelanggan FROM app_dev;
```

Contoh output:

```text
Revoke succeeded.
```

## 9.2 Verifikasi privilege tersisa

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

SELECT grantee,
       privilege
FROM dba_tab_privs
WHERE owner = 'APP_OWNER'
AND table_name = 'PELANGGAN'
ORDER BY grantee, privilege;
```

Contoh output:

```text
GRANTEE              PRIVILEGE
-------------------- ----------
APP_DEV              INSERT
APP_READ             SELECT
```

## 9.3 Test update kembali

```sql
CONN app_dev/oracle@localhost:1521/pdb1.localdomain

UPDATE app_owner.pelanggan
SET kota = 'Solo'
WHERE id_pelanggan = 4;
```

Contoh error:

```text
ORA-01031: insufficient privileges
```

---

# LAB 10 — Membuat Role Lokal di PDB

## 10.1 Buat role

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

CREATE ROLE role_app_read;
CREATE ROLE role_app_dml;
```

Contoh output:

```text
Role created.
Role created.
```

## 10.2 Verifikasi role

```sql
SELECT role,
       common,
       oracle_maintained
FROM dba_roles
WHERE role IN ('ROLE_APP_READ','ROLE_APP_DML');
```

Contoh output:

```text
ROLE                 COMMON   ORACLE_MAINTAINED
-------------------- -------- -----------------
ROLE_APP_DML         NO       N
ROLE_APP_READ        NO       N
```

---

# LAB 11 — Grant Object Privilege ke Role

## 11.1 Grant SELECT ke role read

```sql
CONN app_owner/oracle@localhost:1521/pdb1.localdomain

GRANT SELECT ON pelanggan TO role_app_read;
```

Contoh output:

```text
Grant succeeded.
```

## 11.2 Grant DML ke role dml

```sql
GRANT SELECT, INSERT, UPDATE, DELETE ON pelanggan TO role_app_dml;
```

Contoh output:

```text
Grant succeeded.
```

## 11.3 Verifikasi privilege role

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

SELECT grantee,
       owner,
       table_name,
       privilege
FROM dba_tab_privs
WHERE grantee IN ('ROLE_APP_READ','ROLE_APP_DML')
ORDER BY grantee, privilege;
```

Contoh output:

```text
GRANTEE              OWNER       TABLE_NAME      PRIVILEGE
-------------------- ----------- --------------- ----------
ROLE_APP_DML         APP_OWNER   PELANGGAN       DELETE
ROLE_APP_DML         APP_OWNER   PELANGGAN       INSERT
ROLE_APP_DML         APP_OWNER   PELANGGAN       SELECT
ROLE_APP_DML         APP_OWNER   PELANGGAN       UPDATE
ROLE_APP_READ        APP_OWNER   PELANGGAN       SELECT
```

---

# LAB 12 — Grant Role ke User

## 12.1 Grant role ke user

```sql
GRANT role_app_read TO app_read;
GRANT role_app_dml TO app_dev;
```

Contoh output:

```text
Grant succeeded.
Grant succeeded.
```

## 12.2 Verifikasi role user

```sql
SELECT grantee,
       granted_role,
       admin_option,
       default_role
FROM dba_role_privs
WHERE grantee IN ('APP_READ','APP_DEV')
ORDER BY grantee, granted_role;
```

Contoh output:

```text
GRANTEE              GRANTED_ROLE         ADMIN_OPTION DEFAULT_ROLE
-------------------- -------------------- ------------ ------------
APP_DEV              ROLE_APP_DML         NO           YES
APP_READ             ROLE_APP_READ        NO           YES
```

## 12.3 Test privilege via role

```sql
CONN app_read/oracle@localhost:1521/pdb1.localdomain

SELECT COUNT(*) FROM app_owner.pelanggan;
```

Contoh output:

```text
  COUNT(*)
----------
         4
```

```sql
CONN app_dev/oracle@localhost:1521/pdb1.localdomain

INSERT INTO app_owner.pelanggan
VALUES (5, 'Eka', 'Denpasar');

COMMIT;
```

Contoh output:

```text
1 row created.

Commit complete.
```

Verifikasi:

```sql
SELECT * FROM app_owner.pelanggan ORDER BY id_pelanggan;
```

Contoh output:

```text
ID_PELANGGAN NAMA                 KOTA
------------ -------------------- --------------------
           1 Andi                 Jakarta
           2 Budi                 Bandung
           3 Candra               Surabaya
           4 Dedi                 Yogyakarta
           5 Eka                  Denpasar
```

---

# LAB 13 — Default Role dan SET ROLE

## 13.1 Nonaktifkan role sebagai default

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

ALTER USER app_dev DEFAULT ROLE NONE;
```

Contoh output:

```text
User altered.
```

## 13.2 Verifikasi default role

```sql
SELECT grantee,
       granted_role,
       default_role
FROM dba_role_privs
WHERE grantee = 'APP_DEV';
```

Contoh output:

```text
GRANTEE              GRANTED_ROLE         DEFAULT_ROLE
-------------------- -------------------- ------------
APP_DEV              ROLE_APP_DML         NO
```

## 13.3 Login ulang dan coba akses

```sql
CONN app_dev/oracle@localhost:1521/pdb1.localdomain

SELECT COUNT(*) FROM app_owner.pelanggan;
```

Contoh error:

```text
ORA-00942: table or view does not exist
```

## 13.4 Aktifkan role manual

```sql
SET ROLE role_app_dml;
```

Contoh output:

```text
Role set.
```

Coba akses lagi:

```sql
SELECT COUNT(*) FROM app_owner.pelanggan;
```

Contoh output:

```text
  COUNT(*)
----------
         5
```

## 13.5 Kembalikan default role

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

ALTER USER app_dev DEFAULT ROLE role_app_dml;
```

Contoh output:

```text
User altered.
```

---

# LAB 14 — Role dengan Password

## 14.1 Buat role password

```sql
CREATE ROLE role_sensitive IDENTIFIED BY oracle;
```

Contoh output:

```text
Role created.
```

## 14.2 Grant privilege ke role

```sql
CONN app_owner/oracle@localhost:1521/pdb1.localdomain

GRANT SELECT ON pelanggan TO role_sensitive;
```

Contoh output:

```text
Grant succeeded.
```

## 14.3 Grant role ke user

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

GRANT role_sensitive TO app_read;
ALTER USER app_read DEFAULT ROLE ALL EXCEPT role_sensitive;
```

Contoh output:

```text
Grant succeeded.
User altered.
```

## 14.4 Test role password

```sql
CONN app_read/oracle@localhost:1521/pdb1.localdomain

SET ROLE role_sensitive;
```

Contoh error:

```text
ORA-01979: missing or invalid password for role 'ROLE_SENSITIVE'
```

Aktifkan dengan password:

```sql
SET ROLE role_sensitive IDENTIFIED BY oracle;
```

Contoh output:

```text
Role set.
```

Test akses:

```sql
SELECT COUNT(*) FROM app_owner.pelanggan;
```

Contoh output:

```text
  COUNT(*)
----------
         5
```

---

# LAB 15 — Grant dengan ADMIN OPTION

`ADMIN OPTION` memungkinkan user memberikan role tersebut ke user lain.

## 15.1 Grant role dengan admin option

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

GRANT role_app_read TO app_dev WITH ADMIN OPTION;
```

Contoh output:

```text
Grant succeeded.
```

## 15.2 Verifikasi

```sql
SELECT grantee,
       granted_role,
       admin_option
FROM dba_role_privs
WHERE grantee = 'APP_DEV'
AND granted_role = 'ROLE_APP_READ';
```

Contoh output:

```text
GRANTEE              GRANTED_ROLE         ADMIN_OPTION
-------------------- -------------------- ------------
APP_DEV              ROLE_APP_READ        YES
```

## 15.3 app_dev memberikan role ke user lain

```sql
CONN app_dev/oracle@localhost:1521/pdb1.localdomain

GRANT role_app_read TO app_read;
```

Contoh output:

```text
Grant succeeded.
```

---

# LAB 16 — Grant Object Privilege dengan GRANT OPTION

`GRANT OPTION` memungkinkan penerima privilege meneruskan privilege object ke user lain.

## 16.1 Buat user baru

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

CREATE USER app_report IDENTIFIED BY oracle
DEFAULT TABLESPACE TS_USER_LAB
TEMPORARY TABLESPACE TEMP
QUOTA 10M ON TS_USER_LAB;

GRANT CREATE SESSION TO app_report;
```

Contoh output:

```text
User created.
Grant succeeded.
```

## 16.2 Grant SELECT dengan GRANT OPTION ke app_read

```sql
CONN app_owner/oracle@localhost:1521/pdb1.localdomain

GRANT SELECT ON pelanggan TO app_read WITH GRANT OPTION;
```

Contoh output:

```text
Grant succeeded.
```

## 16.3 app_read meneruskan SELECT ke app_report

```sql
CONN app_read/oracle@localhost:1521/pdb1.localdomain

GRANT SELECT ON app_owner.pelanggan TO app_report;
```

Contoh output:

```text
Grant succeeded.
```

## 16.4 Test dari app_report

```sql
CONN app_report/oracle@localhost:1521/pdb1.localdomain

SELECT COUNT(*) FROM app_owner.pelanggan;
```

Contoh output:

```text
  COUNT(*)
----------
         5
```

## 16.5 Verifikasi grant chain

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

SELECT owner,
       table_name,
       grantor,
       grantee,
       privilege,
       grantable
FROM dba_tab_privs
WHERE owner = 'APP_OWNER'
AND table_name = 'PELANGGAN'
ORDER BY grantee;
```

Contoh output:

```text
OWNER       TABLE_NAME      GRANTOR     GRANTEE      PRIVILEGE  GRANTABLE
----------- --------------- ----------- ------------ ---------- ----------
APP_OWNER   PELANGGAN       APP_OWNER   APP_READ     SELECT     YES
APP_OWNER   PELANGGAN       APP_READ    APP_REPORT   SELECT     NO
```

---

# LAB 17 — Revoke dan Efek Cascade

## 17.1 Revoke SELECT dari app_read

```sql
CONN app_owner/oracle@localhost:1521/pdb1.localdomain

REVOKE SELECT ON pelanggan FROM app_read;
```

Contoh output:

```text
Revoke succeeded.
```

## 17.2 Verifikasi privilege app_report ikut hilang

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

SELECT owner,
       table_name,
       grantor,
       grantee,
       privilege
FROM dba_tab_privs
WHERE owner = 'APP_OWNER'
AND table_name = 'PELANGGAN'
AND grantee IN ('APP_READ','APP_REPORT');
```

Contoh output:

```text
no rows selected
```

Catatan:

```text
Jika object privilege diberikan WITH GRANT OPTION, lalu privilege asal dicabut,
grant turunan dapat ikut tercabut.
```

---

# LAB 18 — Membuat View dan Grant Akses ke View

Praktik aman: user tidak langsung diberi akses ke tabel, tetapi ke view.

## 18.1 Buat view

```sql
CONN app_owner/oracle@localhost:1521/pdb1.localdomain

CREATE OR REPLACE VIEW v_pelanggan_jakarta AS
SELECT id_pelanggan,
       nama,
       kota
FROM pelanggan
WHERE kota = 'Jakarta';
```

Contoh output:

```text
View created.
```

## 18.2 Grant view ke app_report

```sql
GRANT SELECT ON v_pelanggan_jakarta TO app_report;
```

Contoh output:

```text
Grant succeeded.
```

## 18.3 Test akses view

```sql
CONN app_report/oracle@localhost:1521/pdb1.localdomain

SELECT * FROM app_owner.v_pelanggan_jakarta;
```

Contoh output:

```text
ID_PELANGGAN NAMA                 KOTA
------------ -------------------- --------------------
           1 Andi                 Jakarta
```

## 18.4 Test akses tabel langsung

```sql
SELECT * FROM app_owner.pelanggan;
```

Contoh error:

```text
ORA-00942: table or view does not exist
```

---

# LAB 19 — Lock dan Unlock User

## 19.1 Lock user

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

ALTER USER app_report ACCOUNT LOCK;
```

Contoh output:

```text
User altered.
```

## 19.2 Verifikasi status

```sql
SELECT username,
       account_status
FROM dba_users
WHERE username = 'APP_REPORT';
```

Contoh output:

```text
USERNAME                  ACCOUNT_STATUS
------------------------- --------------------
APP_REPORT                LOCKED
```

## 19.3 Test login user terkunci

```bash
sqlplus app_report/oracle@localhost:1521/pdb1.localdomain
```

Contoh error:

```text
ORA-28000: The account is locked.
```

## 19.4 Unlock user

```sql
ALTER USER app_report ACCOUNT UNLOCK;
```

Contoh output:

```text
User altered.
```

Verifikasi:

```sql
SELECT username,
       account_status
FROM dba_users
WHERE username = 'APP_REPORT';
```

Contoh output:

```text
USERNAME                  ACCOUNT_STATUS
------------------------- --------------------
APP_REPORT                OPEN
```

---

# LAB 20 — Expire dan Reset Password User

## 20.1 Expire password

```sql
ALTER USER app_report PASSWORD EXPIRE;
```

Contoh output:

```text
User altered.
```

Verifikasi:

```sql
SELECT username,
       account_status
FROM dba_users
WHERE username = 'APP_REPORT';
```

Contoh output:

```text
USERNAME                  ACCOUNT_STATUS
------------------------- --------------------
APP_REPORT                EXPIRED
```

## 20.2 Reset password

```sql
ALTER USER app_report IDENTIFIED BY oracle ACCOUNT UNLOCK;
```

Contoh output:

```text
User altered.
```

Verifikasi:

```sql
SELECT username,
       account_status
FROM dba_users
WHERE username = 'APP_REPORT';
```

Contoh output:

```text
USERNAME                  ACCOUNT_STATUS
------------------------- --------------------
APP_REPORT                OPEN
```

---

# LAB 21 — Mengubah Quota User

## 21.1 Cek quota awal

```sql
SELECT username,
       tablespace_name,
       max_bytes/1024/1024 AS max_mb
FROM dba_ts_quotas
WHERE username = 'APP_REPORT';
```

Contoh output:

```text
USERNAME             TABLESPACE_NAME          MAX_MB
-------------------- -------------------- ----------
APP_REPORT           TS_USER_LAB                  10
```

## 21.2 Ubah quota

```sql
ALTER USER app_report QUOTA 100M ON TS_USER_LAB;
```

Contoh output:

```text
User altered.
```

## 21.3 Verifikasi

```sql
SELECT username,
       tablespace_name,
       max_bytes/1024/1024 AS max_mb
FROM dba_ts_quotas
WHERE username = 'APP_REPORT';
```

Contoh output:

```text
USERNAME             TABLESPACE_NAME          MAX_MB
-------------------- -------------------- ----------
APP_REPORT           TS_USER_LAB                 100
```

## 21.4 Revoke quota

```sql
ALTER USER app_report QUOTA 0 ON TS_USER_LAB;
```

Contoh output:

```text
User altered.
```

Verifikasi:

```sql
SELECT username,
       tablespace_name,
       max_bytes/1024/1024 AS max_mb
FROM dba_ts_quotas
WHERE username = 'APP_REPORT';
```

Contoh output:

```text
USERNAME             TABLESPACE_NAME          MAX_MB
-------------------- -------------------- ----------
APP_REPORT           TS_USER_LAB                   0
```

---

# LAB 22 — Membuat Profile Password Policy

## 22.1 Buat profile

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

CREATE PROFILE profile_app LIMIT
  FAILED_LOGIN_ATTEMPTS 3
  PASSWORD_LOCK_TIME 1
  PASSWORD_LIFE_TIME 90
  PASSWORD_GRACE_TIME 7
  SESSIONS_PER_USER 3
  IDLE_TIME 30;
```

Contoh output:

```text
Profile created.
```

## 22.2 Assign profile ke user

```sql
ALTER USER app_report PROFILE profile_app;
```

Contoh output:

```text
User altered.
```

## 22.3 Verifikasi profile user

```sql
SELECT username,
       profile
FROM dba_users
WHERE username = 'APP_REPORT';
```

Contoh output:

```text
USERNAME                  PROFILE
------------------------- --------------------
APP_REPORT                PROFILE_APP
```

## 22.4 Verifikasi isi profile

```sql
SELECT profile,
       resource_name,
       limit
FROM dba_profiles
WHERE profile = 'PROFILE_APP'
ORDER BY resource_name;
```

Contoh output:

```text
PROFILE_APP  FAILED_LOGIN_ATTEMPTS  3
PROFILE_APP  IDLE_TIME              30
PROFILE_APP  PASSWORD_GRACE_TIME    7
PROFILE_APP  PASSWORD_LIFE_TIME     90
PROFILE_APP  PASSWORD_LOCK_TIME     1
PROFILE_APP  SESSIONS_PER_USER      3
```

---

# LAB 23 — Common User di CDB$ROOT

## 23.1 Kembali ke root

```sql
CONN / AS SYSDBA
SHOW CON_NAME
```

Contoh output:

```text
CON_NAME
------------------------------
CDB$ROOT
```

## 23.2 Buat common user

```sql
CREATE USER C##ADMIN_LAB IDENTIFIED BY oracle
CONTAINER=ALL;
```

Contoh output:

```text
User created.
```

## 23.3 Grant privilege common user

```sql
GRANT CREATE SESSION TO C##ADMIN_LAB CONTAINER=ALL;
```

Contoh output:

```text
Grant succeeded.
```

## 23.4 Verifikasi common user

```sql
SELECT con_id,
       username,
       common,
       account_status
FROM cdb_users
WHERE username = 'C##ADMIN_LAB'
ORDER BY con_id;
```

Contoh output:

```text
CON_ID USERNAME                  COMMON   ACCOUNT_STATUS
------ ------------------------- -------- --------------------
     1 C##ADMIN_LAB              YES      OPEN
     3 C##ADMIN_LAB              YES      OPEN
```

## 23.5 Test login common user ke root

```bash
sqlplus C##ADMIN_LAB/oracle@localhost:1521/ORADB
```

Contoh output:

```text
Connected.
```

## 23.6 Test login common user ke PDB

```bash
sqlplus C##ADMIN_LAB/oracle@localhost:1521/pdb1.localdomain
```

Contoh output:

```text
Connected.
```

Catatan:

```text
Common user bisa ada di root dan PDB, tetapi privilege harus diberikan sesuai container scope.
```

---

# LAB 24 — Local User Tidak Bisa Dibuat di Root Tanpa Prefix C##

## 24.1 Coba buat user biasa di root

```sql
CONN / AS SYSDBA

CREATE USER local_root_test IDENTIFIED BY oracle;
```

Contoh error:

```text
ORA-65096: invalid common user or role name
```

Artinya pada CDB$ROOT, user umum harus mengikuti aturan common user, yaitu prefix `C##`.

---

# LAB 25 — Common Role

## 25.1 Buat common role

```sql
CONN / AS SYSDBA

CREATE ROLE C##ROLE_CONNECT_LAB CONTAINER=ALL;
```

Contoh output:

```text
Role created.
```

## 25.2 Grant privilege ke common role

```sql
GRANT CREATE SESSION TO C##ROLE_CONNECT_LAB CONTAINER=ALL;
```

Contoh output:

```text
Grant succeeded.
```

## 25.3 Grant common role ke common user

```sql
GRANT C##ROLE_CONNECT_LAB TO C##ADMIN_LAB CONTAINER=ALL;
```

Contoh output:

```text
Grant succeeded.
```

## 25.4 Verifikasi

```sql
SELECT con_id,
       grantee,
       granted_role,
       common
FROM cdb_role_privs
WHERE grantee = 'C##ADMIN_LAB'
AND granted_role = 'C##ROLE_CONNECT_LAB'
ORDER BY con_id;
```

Contoh output:

```text
CON_ID GRANTEE              GRANTED_ROLE           COMMON
------ -------------------- ---------------------- ------
     1 C##ADMIN_LAB         C##ROLE_CONNECT_LAB    YES
     3 C##ADMIN_LAB         C##ROLE_CONNECT_LAB    YES
```

---

# LAB 26 — Revoke System Privilege

## 26.1 Revoke CREATE TABLE dari app_owner

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

REVOKE CREATE TABLE FROM app_owner;
```

Contoh output:

```text
Revoke succeeded.
```

## 26.2 Verifikasi

```sql
SELECT grantee,
       privilege
FROM dba_sys_privs
WHERE grantee = 'APP_OWNER'
AND privilege = 'CREATE TABLE';
```

Contoh output:

```text
no rows selected
```

## 26.3 Test create table baru

```sql
CONN app_owner/oracle@localhost:1521/pdb1.localdomain

CREATE TABLE test_revoke (
    id NUMBER
);
```

Contoh error:

```text
ORA-01031: insufficient privileges
```

Catatan:

```text
Object yang sudah dibuat sebelumnya tidak otomatis hilang.
Privilege CREATE TABLE hanya mempengaruhi kemampuan membuat tabel baru.
```

---

# LAB 27 — Drop Role

## 27.1 Drop role local

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

DROP ROLE role_sensitive;
```

Contoh output:

```text
Role dropped.
```

## 27.2 Verifikasi

```sql
SELECT role
FROM dba_roles
WHERE role = 'ROLE_SENSITIVE';
```

Contoh output:

```text
no rows selected
```

---

# LAB 28 — Drop User

## 28.1 Coba drop user yang masih punya object tanpa CASCADE

```sql
DROP USER app_owner;
```

Contoh error:

```text
ORA-01922: CASCADE must be specified to drop 'APP_OWNER'
```

## 28.2 Drop user dengan CASCADE

```sql
DROP USER app_report CASCADE;
DROP USER app_read CASCADE;
DROP USER app_dev CASCADE;
DROP USER app_owner CASCADE;
```

Contoh output:

```text
User dropped.
User dropped.
User dropped.
User dropped.
```

## 28.3 Verifikasi user hilang

```sql
SELECT username
FROM dba_users
WHERE username IN ('APP_OWNER','APP_READ','APP_DEV','APP_REPORT');
```

Contoh output:

```text
no rows selected
```

---

# LAB 29 — Drop Common User dan Common Role

Jalankan dari root.

```sql
CONN / AS SYSDBA
```

## 29.1 Drop common role

```sql
DROP ROLE C##ROLE_CONNECT_LAB;
```

Contoh output:

```text
Role dropped.
```

## 29.2 Drop common user

```sql
DROP USER C##ADMIN_LAB CASCADE;
```

Contoh output:

```text
User dropped.
```

## 29.3 Verifikasi

```sql
SELECT con_id,
       username
FROM cdb_users
WHERE username = 'C##ADMIN_LAB';
```

Contoh output:

```text
no rows selected
```

```sql
SELECT con_id,
       role
FROM cdb_roles
WHERE role = 'C##ROLE_CONNECT_LAB';
```

Contoh output:

```text
no rows selected
```

---

# LAB 30 — Cleanup Tablespace dan Profile

## 30.1 Drop role local yang tersisa

```sql
ALTER SESSION SET CONTAINER=PDB1;

DROP ROLE role_app_read;
DROP ROLE role_app_dml;
```

Contoh output:

```text
Role dropped.
Role dropped.
```

## 30.2 Drop profile

```sql
DROP PROFILE profile_app;
```

Contoh output:

```text
Profile dropped.
```

Jika muncul error karena masih dipakai user:

```text
ORA-02382: profile PROFILE_APP has users assigned, cannot drop without CASCADE
```

Gunakan:

```sql
DROP PROFILE profile_app CASCADE;
```

## 30.3 Drop tablespace lab

```sql
DROP TABLESPACE TS_USER_LAB INCLUDING CONTENTS AND DATAFILES;
```

Contoh output:

```text
Tablespace dropped.
```

## 30.4 Verifikasi akhir

```sql
SELECT tablespace_name
FROM dba_tablespaces
WHERE tablespace_name = 'TS_USER_LAB';
```

Contoh output:

```text
no rows selected
```

---

# Ringkasan Command Penting

Membuat local user di PDB:

```sql
ALTER SESSION SET CONTAINER=PDB1;

CREATE USER app_owner IDENTIFIED BY oracle
DEFAULT TABLESPACE TS_USER_LAB
TEMPORARY TABLESPACE TEMP
QUOTA UNLIMITED ON TS_USER_LAB;
```

Grant system privilege:

```sql
GRANT CREATE SESSION, CREATE TABLE TO app_owner;
```

Revoke system privilege:

```sql
REVOKE CREATE TABLE FROM app_owner;
```

Grant object privilege:

```sql
GRANT SELECT, INSERT, UPDATE ON pelanggan TO app_dev;
```

Revoke object privilege:

```sql
REVOKE UPDATE ON pelanggan FROM app_dev;
```

Membuat role:

```sql
CREATE ROLE role_app_read;
```

Grant privilege ke role:

```sql
GRANT SELECT ON app_owner.pelanggan TO role_app_read;
```

Grant role ke user:

```sql
GRANT role_app_read TO app_read;
```

Default role:

```sql
ALTER USER app_read DEFAULT ROLE role_app_read;
```

Lock user:

```sql
ALTER USER app_read ACCOUNT LOCK;
```

Unlock user:

```sql
ALTER USER app_read ACCOUNT UNLOCK;
```

Reset password:

```sql
ALTER USER app_read IDENTIFIED BY oracle;
```

Drop user:

```sql
DROP USER app_read CASCADE;
```

Common user:

```sql
CREATE USER C##ADMIN_LAB IDENTIFIED BY oracle CONTAINER=ALL;
GRANT CREATE SESSION TO C##ADMIN_LAB CONTAINER=ALL;
```

Common role:

```sql
CREATE ROLE C##ROLE_CONNECT_LAB CONTAINER=ALL;
GRANT CREATE SESSION TO C##ROLE_CONNECT_LAB CONTAINER=ALL;
```

---

Best practice untuk Oracle 19c Multitenant: **user aplikasi dibuat sebagai local user di PDB**, privilege diberikan secukupnya melalui **role**, dan akses ke tabel utama sebaiknya tidak diberikan langsung bila bisa diganti dengan **view** atau role khusus sesuai kebutuhan aplikasi.
