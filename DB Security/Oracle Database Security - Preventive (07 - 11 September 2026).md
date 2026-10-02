# ORACLE DATABASE SECURITY — COMPLETE LAB DAY 1–5

Dokumen gabungan seluruh materi preventive/lab Oracle Database Security,
disusun berurutan dari Day 1 sampai Day 5.

## Daftar Isi

1. [Day 1 — Authentication, Authorization & User Security](#day-1)
2. [Day 2 — Encryption, TDE, Keystore, Backup & Data Pump](#day-2)
   - [Day 2B — Extended Lab: Data Pump, RMAN, dan TDE](#day-2b-extended)
   - [Day 2B — Hands-on Copy-Paste](#day-2b-hands-on)
3. [Day 3 — Oracle Key Vault & Sensitive Data Discovery](#day-3)
4. [Day 4 — Data Masking, Subsetting & Data Redaction](#day-4)
   - [Day 4 — Hands-on Only](#day-4-hands-on)
5. [Day 5 — Database Vault & Privilege Analysis](#day-5)
   - [Original](#day-5-original)
   - [Version 2](#day-5-v2)
   - [Version 3 / Pemulihan Akses TDE](#day-5-v3)

> Catatan: Semua file sumber dipertahankan agar tidak ada materi yang hilang.
> Beberapa hari memiliki versi/revisi tambahan sehingga isinya dapat saling
> overlap. Versi-versi tersebut tetap ditempatkan berurutan di dalam hari yang sama.

---


<!-- ============================================================ -->
<!-- SOURCE: preventive_day1.md -->
<!-- ============================================================ -->

<a id="day-1"></a>

# DAY 1 — Authentication, Authorization & User Security

> **Sumber file:** `preventive_day1.md`

# DAY 1 — Authentication, Authorization & User Security

## Target pembelajaran

Setelah menyelesaikan Day 1, peserta diharapkan mampu:

1. Membuat dan mengelola database user.
2. Memahami **database authentication**.
3. Memahami password verifier/version pada Oracle 19c.
4. Mengimplementasikan password policy.
5. Memahami dan menggunakan **roles**.
6. Membuat role dengan prinsip least privilege.
7. Menggunakan password-protected role.
8. Memahami database link dan security concern-nya.
9. Mengimplementasikan **proxy authentication**.
10. Membatasi role yang dapat digunakan oleh proxy.
11. Memahami konsep strong authentication.
12. Memahami konsep SSL/TLS/TCPS.
13. Memahami Global User, EUS, dan LDAP.
14. Memahami security problem pada three-tier application.
15. Memahami pola yang lebih aman menggunakan proxy authentication.

---

# 0. LAB ENVIRONMENT

## 0.1 Environment yang digunakan

```text
OS          : Oracle Linux 7.8
Oracle      : 19.8.0.0.0
ORACLE_HOME : /u01/app/oracle/product/19.0.0/db_1
ORACLE_BASE : /u01/app/oracle
ORACLE_SID  : oradb
CDB         : ORADB
PDB         : PDB1
SYS         : oracle
```

Target seluruh hands-on:

```text
PDB1
```

Kita **tidak melakukan eksperimen user aplikasi di CDB$ROOT** agar lab lebih aman dan sesuai dengan konsep multitenant Oracle.

---

# LAB 1 — Verify Oracle Environment

## Tujuan

Memastikan environment peserta sesuai dengan environment training.

## Step 1 — Login OS

```bash
su - oracle
```

## Step 2 — Set environment

```bash
export ORACLE_SID=oradb
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/db_1
export ORACLE_BASE=/u01/app/oracle
export PATH=$ORACLE_HOME/bin:$PATH
```

## Step 3 — Verify

```bash
echo $ORACLE_SID
echo $ORACLE_HOME
echo $ORACLE_BASE
which sqlplus
sqlplus -version
```

### Expected output

```text
oradb
/u01/app/oracle/product/19.0.0/db_1
/u01/app/oracle
/u01/app/oracle/product/19.0.0/db_1/bin/sqlplus

SQL*Plus: Release 19.0.0.0.0 - Production
Version 19.8.0.0.0
```

---

# LAB 2 — Connect as SYS and Verify CDB/PDB

## Step 1

```bash
sqlplus / as sysdba
```

Expected:

```text
SQL*Plus: Release 19.0.0.0.0 - Production
...
Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0
Version 19.8.0.0.0
```

## Step 2 — Check database

```sql
SELECT
    name,
    db_unique_name,
    cdb,
    open_mode
FROM v$database;
```

Expected:

```text
NAME      DB_UNIQUE_NAME  CDB  OPEN_MODE
--------- --------------- ---- ----------
ORADB     ORADB           YES  READ WRITE
```

## Step 3 — Check PDB

```sql
SHOW CON_NAME;

SELECT
    con_id,
    name,
    open_mode,
    restricted
FROM v$pdbs
ORDER BY con_id;
```

Expected:

```text
CON_NAME
------------------------------
CDB$ROOT

    CON_ID NAME       OPEN_MODE  RES
---------- ---------- ---------- ---
         2 PDB$SEED   READ ONLY  NO
         3 PDB1       READ WRITE NO
```

## Step 4 — Switch ke PDB1

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

Verify:

```sql
SHOW CON_NAME;
```

Expected:

```text
CON_NAME
------------------------------
PDB1
```

> Mulai dari sini, hampir seluruh lab Day 1 dijalankan di **PDB1**.

---

# LAB 3 — Basic Database Authentication

Ini merupakan lab pertama yang paling penting.

Oracle database authentication menggunakan informasi yang tersimpan di database, termasuk password user. Oracle menyimpan password verifier dan menyediakan `PASSWORD_VERSIONS` untuk melihat versi verifier yang tersedia. ([Oracle Docs][1])

## Tujuan

Peserta memahami:

```text
Username
   ↓
Password
   ↓
Oracle authentication
   ↓
CREATE SESSION
   ↓
Database session
```

---

## Step 1 — Create training user

Sebagai SYS di PDB1:

```sql
CREATE USER lab_user
IDENTIFIED BY "OracleLab#2026";
```

Expected:

```text
User created.
```

---

## Step 2 — Grant CREATE SESSION

```sql
GRANT CREATE SESSION TO lab_user;
```

Expected:

```text
Grant succeeded.
```

---

## Step 3 — Check user

```sql
SELECT
    username,
    account_status,
    authentication_type,
    password_versions,
    default_tablespace,
    profile
FROM dba_users
WHERE username = 'LAB_USER';
```

Expected kurang lebih:

```text
USERNAME   ACCOUNT_STATUS  AUTHENTICATION_TYPE  PASSWORD_VERSIONS
---------- --------------- -------------------- -----------------
LAB_USER   OPEN            PASSWORD             11G 12C
```

**Catatan:** tampilan `PASSWORD_VERSIONS` dapat berbeda tergantung konfigurasi password verifier pada database.

---

# LAB 4 — Login menggunakan Database User

Sekarang kita buktikan bahwa authentication benar-benar dilakukan oleh database.

Keluar dari SYS:

```sql
EXIT
```

Kemudian:

```bash
sqlplus lab_user/"OracleLab#2026"@localhost:1521/pdb1.localdomain
```

Expected:

```text
Connected to:
Oracle Database 19c Enterprise Edition ...
```

Verify:

```sql
SELECT
    USER,
    SYS_CONTEXT('USERENV','SESSION_USER') AS SESSION_USER,
    SYS_CONTEXT('USERENV','CURRENT_USER') AS CURRENT_USER,
    SYS_CONTEXT('USERENV','AUTHENTICATION_METHOD') AS AUTH_METHOD
FROM dual;
```

Expected:

```text
USER       SESSION_USER  CURRENT_USER  AUTH_TYPE
---------- ------------ -------------  ------------
LAB_USER   LAB_USER     LAB_USER      PASSWORD
```

### Point penting

Peserta harus memahami perbedaan:

```text
SESSION_USER
     ↓
Siapa yang melakukan login

CURRENT_USER
     ↓
User yang privilege-nya sedang digunakan
```

Pada login normal keduanya sama.

---

# LAB 5 — Authentication Failure

Kita sengaja memasukkan password salah.

```bash
sqlplus lab_user/"WrongPassword#2026"@localhost:1521/pdb1.localdomain
```

Expected:

```text
ERROR:
ORA-01017: invalid credential; logon denied
```

Ini menunjukkan database melakukan verifikasi credential.

---

# LAB 6 — Password Version & Authentication Security

## Step 1

Login kembali sebagai SYS.

```bash
sqlplus sys/oracle@localhost:1521/pdb1.localdomain as sysdba
```

Kemudian:

```sql
SELECT
    username,
    password_versions
FROM dba_users
WHERE username = 'LAB_USER';
```

Expected:

```text
USERNAME   PASSWORD_VERSIONS
---------- -----------------
LAB_USER   11G 12C
```

Oracle 19c mengenal password verifier seperti `10G`, `11G`, dan `12C`; Oracle merekomendasikan konfigurasi modern dan password management yang baik. ([Oracle Docs][1])

---

# LAB 7 — Password Policy dengan PROFILE

Sekarang kita membuat policy khusus untuk user aplikasi.

## Step 1 — Create profile

```sql
CREATE PROFILE training_profile LIMIT
    FAILED_LOGIN_ATTEMPTS 5
    PASSWORD_LIFE_TIME 90
    PASSWORD_REUSE_TIME 365
    PASSWORD_REUSE_MAX 10
    PASSWORD_LOCK_TIME 1/24
    PASSWORD_GRACE_TIME 7;
```

Expected:

```text
Profile created.
```

## Step 2 — Apply profile

```sql
ALTER USER lab_user PROFILE training_profile;
```

Expected:

```text
User altered.
```

## Step 3 — Verify

```sql
SELECT
    username,
    profile,
    account_status
FROM dba_users
WHERE username='LAB_USER';
```

Expected:

```text
USERNAME   PROFILE            ACCOUNT_STATUS
---------- ------------------ --------------
LAB_USER   TRAINING_PROFILE   OPEN
```

## Step 4 — Examine policy

```sql
SELECT
    profile,
    resource_name,
    limit
FROM dba_profiles
WHERE profile='TRAINING_PROFILE'
ORDER BY resource_name;
```

Expected antara lain:

```text
PROFILE            RESOURCE_NAME             LIMIT
------------------ ------------------------- -------
TRAINING_PROFILE   FAILED_LOGIN_ATTEMPTS     5
TRAINING_PROFILE   PASSWORD_GRACE_TIME       7
TRAINING_PROFILE   PASSWORD_LIFE_TIME       90
PASSWORD_LOCK_TIME 1/24
...
```

---

# LAB 8 — User Privilege vs Role

Sekarang kita masuk ke **authorization**.

Authentication:

```text
Who are you?
```

Authorization:

```text
What are you allowed to do?
```

---

## Step 1 — Create test schema

```sql
CREATE USER app_owner
IDENTIFIED BY "Owner#2026";
```

```sql
GRANT CREATE SESSION, CREATE TABLE, UNLIMITED TABLESPACE TO app_owner;
```

Expected:

```text
User created.

Grant succeeded.
```

---

## Step 2 — Create application table

Connect sebagai APP_OWNER:

```sql
CONNECT app_owner/"Owner#2026"@localhost:1521/pdb1.localdomain
```

Create table:

```sql
CREATE TABLE customer_data (
    customer_id NUMBER PRIMARY KEY,
    customer_name VARCHAR2(100),
    credit_limit NUMBER(15,2)
);
```

Expected:

```text
Table created.
```

Insert data:

```sql
INSERT INTO customer_data
VALUES (1,'JOHN DOE',100000);

INSERT INTO customer_data
VALUES (2,'JANE DOE',150000);

COMMIT;
```

Expected:

```text
1 row created.

1 row created.

Commit complete.
```

Verify:

```sql
SELECT * FROM customer_data;
```

Expected:

```text
CUSTOMER_ID CUSTOMER_NAME CREDIT_LIMIT
----------- ------------- ------------
          1 JOHN DOE           100000
          2 JANE DOE           150000
```

---

# LAB 9 — Create Read-Only Application Role

Sekarang kita ingin membuat user yang hanya boleh membaca data.

## Step 1 — Login SYS

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA
```

## Step 2 — Create role

```sql
CREATE ROLE customer_read_role;
```

Expected:

```text
Role created.
```

## Step 3 — Grant SELECT

```sql
GRANT SELECT ON app_owner.customer_data
TO customer_read_role;
```

Expected:

```text
Grant succeeded.
```

## Step 4 — Create application user

```sql
CREATE USER app_reader
IDENTIFIED BY "Reader#2026";
```

```sql
GRANT CREATE SESSION TO app_reader;
```

```sql
GRANT customer_read_role TO app_reader;
```

---

# LAB 10 — Test Role-Based Access

Login:

```sql
CONNECT app_reader/"Reader#2026"@localhost:1521/pdb1.localdomain
```

Test SELECT:

```sql
SELECT *
FROM app_owner.customer_data;
```

Expected:

```text
CUSTOMER_ID CUSTOMER_NAME CREDIT_LIMIT
----------- ------------- ------------
          1 JOHN DOE           100000
          2 JANE DOE           150000
```

Sekarang coba INSERT:

```sql
INSERT INTO app_owner.customer_data
VALUES (3,'HACKER',999999);
```

Expected:

```text
ORA-01031: insufficient privileges
```

### Learning point

User:

```text
APP_READER
     |
     +-- CUSTOMER_READ_ROLE
             |
             +-- SELECT customer_data
```

User tidak mendapatkan privilege INSERT.

Ini merupakan implementasi **least privilege**.

Oracle juga merekomendasikan agar role hanya berisi privilege yang benar-benar diperlukan sesuai job responsibility. ([Oracle Docs][2])

---

# LAB 11 — Role Hierarchy

Sekarang kita buat role yang lebih besar.

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA
```

Create:

```sql
CREATE ROLE customer_write_role;
```

Grant:

```sql
GRANT INSERT, UPDATE
ON app_owner.customer_data
TO customer_write_role;
```

Kemudian kita buat role application:

```sql
CREATE ROLE customer_app_role;
```

Masukkan role:

```sql
GRANT customer_read_role TO customer_app_role;
GRANT customer_write_role TO customer_app_role;
```

Sekarang:

```text
CUSTOMER_APP_ROLE
       |
       +---- CUSTOMER_READ_ROLE
       |
       +---- CUSTOMER_WRITE_ROLE
```

Buat user:

```sql
CREATE USER app_operator
IDENTIFIED BY "Operator#2026";
```

```sql
GRANT CREATE SESSION TO app_operator;
```

```sql
GRANT customer_app_role TO app_operator;
```

---

# LAB 12 — Test Role Hierarchy

Login:

```sql
CONNECT app_operator/"Operator#2026"@localhost:1521/pdb1.localdomain
```

SELECT:

```sql
SELECT *
FROM app_owner.customer_data;
```

Expected:

```text
CUSTOMER_ID CUSTOMER_NAME CREDIT_LIMIT
----------- ------------- ------------
1           JOHN DOE      100000
2           JANE DOE      150000
```

INSERT:

```sql
INSERT INTO app_owner.customer_data
VALUES (3,'ALICE',200000);

COMMIT;
```

Expected:

```text
1 row created.

Commit complete.
```

UPDATE:

```sql
UPDATE app_owner.customer_data
SET credit_limit=250000
WHERE customer_id=3;

COMMIT;
```

Expected:

```text
1 row updated.

Commit complete.
```

---

# LAB 13 — Password Protected Role

Silabus Day 1 secara khusus memasukkan **Security of Roles**. Oracle mendukung role yang diotorisasi menggunakan password. ([Oracle Docs][3])

## Step 1

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA
```

Create:

```sql
CREATE ROLE sensitive_role
IDENTIFIED BY "SensitiveRole#2026";
```

Expected:

```text
Role created.
```

Grant:

```sql
GRANT SELECT ON app_owner.customer_data
TO sensitive_role;
```

Grant role:

```sql
GRANT sensitive_role TO app_reader;
```

---

# LAB 14 — Test Password-Protected Role

Login:

```sql
CONNECT app_reader/"Reader#2026"@localhost:1521/pdb1.localdomain
```

Check roles:

```sql
SELECT
    username,
    granted_role,
    default_role
FROM user_role_privs;
```

Expected bahwa role password-protected tidak otomatis aktif sebagai normal default role.

Sekarang:

```sql
SET ROLE sensitive_role IDENTIFIED BY "SensitiveRole#2026";
```

Expected:

```text
Role set.
```

Test:

```sql
SELECT *
FROM app_owner.customer_data;
```

Expected:

```text
CUSTOMER_ID CUSTOMER_NAME CREDIT_LIMIT
----------- ------------- ------------
1           JOHN DOE      100000
2           JANE DOE     150000
3           ALICE         250000
```

---

# LAB 15 — Database Link Security

Ini bagian penting dari silabus:

> Database Link Passwords Protection

Kita membuat dua PDB user sebagai simulasi dua database/schema endpoint.

Untuk lab ini, kita menggunakan PDB1 sebagai database target yang sama melalui Oracle Net service. Tujuannya adalah memahami mekanisme dan security implication database link.

---

## Step 1 — Create DB link user

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA
```

Create:

```sql
CREATE USER link_user
IDENTIFIED BY "LinkUser#2026";
```

```sql
GRANT CREATE SESSION TO link_user;
```

`LINK_USER` adalah identitas yang dipakai pada sisi remote. Karena itu ia juga
harus diberi privilege object yang akan dibaca melalui database link:

```sql
GRANT SELECT ON app_owner.customer_data TO link_user;
```

---

## Step 2 — Create database link

Login sebagai APP_READER:

```sql
CONNECT app_reader/"Reader#2026"@localhost:1521/pdb1.localdomain
```

Grant:

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA
```

```sql
GRANT CREATE DATABASE LINK TO app_reader;
```

Connect kembali:

```sql
CONNECT app_reader/"Reader#2026"@localhost:1521/pdb1.localdomain
```

Create DB link:

```sql
CREATE DATABASE LINK training_link
CONNECT TO link_user
IDENTIFIED BY "LinkUser#2026"
USING 'localhost:1521/pdb1.localdomain';
```

Expected:

```text
Database link created.
```

---

# LAB 16 — Test Database Link

```sql
SELECT
    username
FROM user_users@training_link;
```

Expected:

```text
USERNAME
---------
LINK_USER
```

> Jangan gunakan `USER` atau `SYS_CONTEXT('USERENV','SESSION_USER')` pada
> `DUAL@training_link` untuk membuktikan identitas remote. Pada Oracle 19.8
> ekspresi tersebut dapat dievaluasi pada sesi lokal. `USER_USERS@training_link`
> membuktikan bahwa query benar-benar berjalan sebagai `LINK_USER` pada sisi
> remote.

Test database table:

```sql
SELECT *
FROM app_owner.customer_data@training_link;
```

Expected:

```text
CUSTOMER_ID CUSTOMER_NAME CREDIT_LIMIT
----------- ------------- ------------
1           JOHN DOE      100000
2           JANE DOE      150000
3           ALICE         250000
```

---

# LAB 17 — Examine Database Link

```sql
SELECT
    db_link,
    username,
    host,
    created
FROM user_db_links;
```

Expected:

```text
DB_LINK       USERNAME    HOST
------------- ----------- ----------------
TRAINING_LINK LINK_USER   localhost:1521/pdb1.localdomain
```

### Security discussion

Peserta perlu memahami bahwa:

```text
Application
     |
     | DB Link
     v
Database B
```

berarti credential untuk koneksi remote harus dikelola dengan benar.

Untuk production architecture, jangan menjadikan database link sebagai mekanisme umum untuk menyebarkan credential secara bebas.

---

# LAB 18 — Proxy Authentication

Ini salah satu **hands-on terpenting Day 1**.

Oracle mendukung proxy user sehingga aplikasi/middle tier dapat melakukan koneksi melalui account proxy atas nama user database tertentu. Oracle 19c menyediakan `GRANT CONNECT THROUGH` dan opsi pembatasan role. ([Oracle Docs][4])

Arsitektur:

```text
                    +----------------+
                    |  APP_PROXY     |
                    |  Middle Tier   |
                    +-------+--------+
                            |
                            | proxy
                            v
                    +----------------+
                    | APP_USER       |
                    | Real Identity  |
                    +----------------+
```

---

# LAB 19 — Create Business User

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA
```

Create:

```sql
CREATE USER business_user
IDENTIFIED BY "Business#2026";
```

Grant:

```sql
GRANT CREATE SESSION TO business_user;
```

Create role:

```sql
CREATE ROLE business_read_role;
```

Grant:

```sql
GRANT SELECT ON app_owner.customer_data
TO business_read_role;
```

Grant role:

```sql
GRANT business_read_role TO business_user;
```

---

# LAB 20 — Create Proxy User

Create:

```sql
CREATE USER app_proxy
IDENTIFIED BY "Proxy#2026";
```

Grant:

```sql
GRANT CREATE SESSION TO app_proxy;
```

Expected:

```text
User created.

Grant succeeded.
```

---

# LAB 21 — Allow Proxy Connection

```sql
ALTER USER business_user
GRANT CONNECT THROUGH app_proxy;
```

Expected:

```text
User altered.
```

---

# LAB 22 — Connect Through Proxy

Exit SQL*Plus and execute:

```bash
sqlplus app_proxy[business_user]/"Proxy#2026"@localhost:1521/pdb1.localdomain
```

Expected:

```text
Connected to:
Oracle Database 19c Enterprise Edition ...
```

Sekarang:

```sql
SELECT
    USER,
    SYS_CONTEXT('USERENV','SESSION_USER') AS SESSION_USER,
    SYS_CONTEXT('USERENV','CURRENT_USER') AS CURRENT_USER,
    SYS_CONTEXT('USERENV','PROXY_USER') AS PROXY_USER
FROM dual;
```

Expected konsep output:

```text
USER           SESSION_USER   CURRENT_USER   PROXY_USER
-------------- -------------- -------------- -----------
BUSINESS_USER  BUSINESS_USER  BUSINESS_USER  APP_PROXY
```

### Ini sangat penting.

Walaupun koneksi menggunakan:

```text
APP_PROXY
```

database mengetahui bahwa identity yang sedang digunakan adalah:

```text
BUSINESS_USER
```

dan proxy-nya:

```text
APP_PROXY
```

---

# LAB 23 — Verify Proxy Identity

Jalankan:

```sql
SELECT
    SYS_CONTEXT('USERENV','PROXY_USER') AS proxy_user,
    SYS_CONTEXT('USERENV','SESSION_USER') AS session_user,
    SYS_CONTEXT('USERENV','CURRENT_USER') AS current_user
FROM dual;
```

Expected:

```text
PROXY_USER  SESSION_USER   CURRENT_USER
----------- -------------- -------------
APP_PROXY   BUSINESS_USER  BUSINESS_USER
```

---

# LAB 24 — Restrict Proxy to Specific Role

Sekarang kita buat scenario lebih secure.

Misalnya `BUSINESS_USER` mempunyai beberapa role:

```text
BUSINESS_USER
     |
     +--- BUSINESS_READ_ROLE
     |
     +--- SENSITIVE_ROLE
```

Tetapi ketika koneksi melalui application server, kita hanya ingin:

```text
BUSINESS_READ_ROLE
```

yang tersedia.

## Step 1

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA
```

## Step 2

Tambahkan role:

```sql
GRANT sensitive_role TO business_user;
```

## Step 3 — Restrict proxy

```sql
ALTER USER business_user
GRANT CONNECT THROUGH app_proxy
WITH ROLE business_read_role;
```

Expected:

```text
User altered.
```

Oracle 19c memang menyediakan `WITH ROLE` pada proxy authorization untuk membatasi role yang boleh diaktifkan melalui proxy. ([Oracle Docs][5])

---

# LAB 25 — Test Restricted Proxy

Login:

```bash
sqlplus 'app_proxy[BUSINESS_USER]/Proxy#2026@localhost:1521/pdb1.localdomain'
```

> Pada SQL*Plus 19.8, bagian `[BUSINESS_USER]` harus melekat pada nama proxy,
> bukan ditempatkan setelah password. Format
> `app_proxy/"Proxy#2026"[business_user]@...` tidak diparse oleh SQL*Plus.

Kemudian:

```sql
SELECT
    SYS_CONTEXT('USERENV','PROXY_USER') AS proxy_user,
    SYS_CONTEXT('USERENV','SESSION_USER') AS session_user
FROM dual;
```

Expected:

```text
PROXY_USER  SESSION_USER
----------- -------------
APP_PROXY   BUSINESS_USER
```

Check roles:

```sql
SELECT
    granted_role,
    default_role
FROM user_role_privs;
```

Expected role yang diperbolehkan melalui proxy:

```text
GRANTED_ROLE
--------------------
BUSINESS_READ_ROLE
```

---

# LAB 26 — Batasan Proxy dengan AUTHENTICATION REQUIRED

`AUTHENTICATION REQUIRED` tidak dijadikan langkah eksekusi pada lab ini.
Perintah `ALTER USER ... GRANT CONNECT THROUGH ... AUTHENTICATION REQUIRED`
memang diterima oleh database, tetapi koneksi proxy berikutnya dengan SQL*Plus
19.8 (`app_proxy[business_user]/...`) ditolak dengan `ORA-28150`. Skenario ini
memerlukan client yang dapat mengirim credential client/proxy sesuai API Oracle,
bukan sintaks login SQL*Plus yang digunakan oleh lab ini.

Karena host lab hanya menyediakan SQL*Plus, gunakan Lab 24--25 sebagai skenario
proxy yang dapat diuji end-to-end. Jangan jalankan perintah ini pada environment
lab karena akan menggantikan konfigurasi `WITH ROLE` yang sudah berfungsi.

---

# LAB 27 — Three-Tier Application Security Simulation

Ini merupakan lab integrasi.

Arsitektur:

```text
+-------------+
| End User    |
+------+------+
       |
       v
+-------------+
| Web / App   |
| Server      |
| APP_PROXY   |
+------+------+
       |
       | Proxy
       v
+-------------+
| Oracle DB   |
|             |
| BUSINESS    |
| USER        |
+-------------+
```

## Scenario

Tanpa proxy:

```text
Application
     |
     +---- APP_USER1/password
     +---- APP_USER2/password
     +---- APP_USER3/password
```

Problem:

```text
Banyak password
Credential management
Audit identity sulit
Connection pooling
```

Dengan proxy:

```text
Application
     |
     | APP_PROXY
     |
     +---- BUSINESS_USER
     +---- SALES_USER
     +---- HR_USER
```

Database tetap dapat membedakan:

```text
PROXY_USER
SESSION_USER
CURRENT_USER
```

Ini merupakan alasan proxy authentication sangat relevan untuk three-tier computing.

---

# LAB 28 — Demonstrasi Connection Pool Identity

Login melalui proxy:

```bash
sqlplus app_proxy/"Proxy#2026"[business_user]@localhost:1521/pdb1.localdomain
```

Jalankan:

```sql
SELECT
    SYS_CONTEXT('USERENV','SESSION_USER') AS session_user,
    SYS_CONTEXT('USERENV','CURRENT_USER') AS current_user,
    SYS_CONTEXT('USERENV','PROXY_USER') AS proxy_user,
    SYS_CONTEXT('USERENV','MODULE') AS module_name,
    SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER') AS client_identifier
FROM dual;
```

Expected:

```text
SESSION_USER    CURRENT_USER    PROXY_USER
--------------- --------------- -----------
BUSINESS_USER   BUSINESS_USER   APP_PROXY
```

`MODULE` dan `CLIENT_IDENTIFIER` dapat kita gunakan untuk memperkenalkan konsep **application identity/auditing** pada tahap berikutnya.

---

# LAB 29 — Strong Authentication: Network Protocol

Sekarang kita masuk ke bagian:

> Strong Authentication

Di environment Anda, **Kerberos dan RADIUS belum tersedia**, sehingga kita tidak akan membuat lab palsu yang seolah-olah berhasil.

Kita akan melakukan dua hal:

1. Verify konfigurasi authentication saat ini.
2. Demonstrate konsep TLS/TCPS.

---

## Step 1 — Check sqlnet.ora

```bash
cat $ORACLE_HOME/network/admin/sqlnet.ora
```

Contoh output bisa berupa:

```text
NAMES.DIRECTORY_PATH= (TNSNAMES, EZCONNECT)
```

Isi aktual dapat berbeda.

---

## Step 2 — Check listener

```bash
lsnrctl status
```

Cari:

```text
(ADDRESS=(PROTOCOL=tcp)
```

Jika hanya terdapat:

```text
PROTOCOL=tcp
```

maka listener saat ini belum menyediakan TCPS.

---

# LAB 30 — Verify Current Connection Protocol

Login sebagai application user:

```bash
sqlplus app_reader/"Reader#2026"@localhost:1521/pdb1.localdomain
```

Kemudian:

```sql
SELECT
    SYS_CONTEXT('USERENV','NETWORK_PROTOCOL') AS network_protocol,
    SYS_CONTEXT('USERENV','AUTHENTICATION_METHOD') AS authentication_method
FROM dual;
```

Expected pada koneksi normal:

```text
NETWORK_PROTOCOL  AUTHENTICATION_METHOD
----------------  ---------------------
tcp               PASSWORD
```

Ini memberikan baseline:

```text
TCP
+
Database Password
```

---

# LAB 33 — Compare Authentication Models

Gunakan tabel berikut sebagai exercise diskusi.

| Model                | Credential Source | Environment kita                         |
| -------------------- | ----------------- | ---------------------------------------- |
| Database Password    | Oracle Database   | ✅ Bisa                                   |
| OS Authentication    | Linux OS          | ⚠️ Bisa untuk CDB administrative context |
| Proxy Authentication | Oracle Database   | ✅ Bisa                                   |
| TLS/TCPS             | PKI/Wallet        | ⚠️ Perlu setup                           |
| Kerberos             | Kerberos KDC      | ❌ Belum tersedia                         |
| RADIUS               | RADIUS server     | ❌ Belum tersedia                         |
| Global User/EUS      | LDAP/Directory    | ❌ Belum tersedia                         |

Untuk OS authentication, Oracle 19c mencatat bahwa dalam multitenant environment OS authentication untuk DBA digunakan pada CDB root, bukan PDB. ([Oracle Docs][10])

---

# LAB 34 — Security Review: Who Can Do What?

Sekarang kita membuat assessment.

## Query 1 — Users

```sql
SELECT
    username,
    account_status,
    authentication_type,
    profile
FROM dba_users
WHERE username IN
(
    'LAB_USER',
    'APP_OWNER',
    'APP_READER',
    'APP_OPERATOR',
    'APP_PROXY',
    'BUSINESS_USER',
    'LINK_USER'
)
ORDER BY username;
```

Expected:

```text
USERNAME        ACCOUNT_STATUS  AUTHENTICATION_TYPE
--------------- --------------  --------------------
APP_OPERATOR    OPEN            PASSWORD
APP_OWNER       OPEN            PASSWORD
APP_PROXY       OPEN            PASSWORD
APP_READER      OPEN            PASSWORD
BUSINESS_USER   OPEN            PASSWORD
LAB_USER        OPEN            PASSWORD
LINK_USER       OPEN            PASSWORD
```

---

# LAB 35 — Review System Privileges

```sql
SELECT
    grantee,
    privilege,
    admin_option
FROM dba_sys_privs
WHERE grantee IN
(
    'LAB_USER',
    'APP_OWNER',
    'APP_READER',
    'APP_OPERATOR',
    'APP_PROXY',
    'BUSINESS_USER',
    'LINK_USER'
)
ORDER BY grantee, privilege;
```

Contoh output:

```text
GRANTEE       PRIVILEGE              ADMIN_OPTION
------------- ---------------------- ------------
APP_OWNER     CREATE SESSION         NO
APP_OWNER     CREATE TABLE           NO
APP_READER    CREATE SESSION         NO
APP_OPERATOR  CREATE SESSION         NO
APP_PROXY     CREATE SESSION         NO
BUSINESS_USER CREATE SESSION         NO
LAB_USER      CREATE SESSION         NO
LINK_USER     CREATE SESSION         NO
```

---

# LAB 36 — Review Role Assignment

```sql
SELECT
    grantee,
    granted_role,
    default_role
FROM dba_role_privs
WHERE grantee IN
(
    'APP_READER',
    'APP_OPERATOR',
    'BUSINESS_USER'
)
ORDER BY grantee, granted_role;
```

Expected konsep:

```text
GRANTEE        GRANTED_ROLE
-------------- ---------------------
APP_OPERATOR   CUSTOMER_APP_ROLE
APP_READER     CUSTOMER_READ_ROLE
BUSINESS_USER  BUSINESS_READ_ROLE
BUSINESS_USER  SENSITIVE_ROLE
```

---

# LAB 37 — Review Object Privileges

```sql
SELECT
    grantee,
    owner,
    table_name,
    privilege
FROM dba_tab_privs
WHERE grantee IN
(
    'CUSTOMER_READ_ROLE',
    'CUSTOMER_WRITE_ROLE',
    'BUSINESS_READ_ROLE',
    'SENSITIVE_ROLE'
)
ORDER BY grantee, owner, table_name, privilege;
```

Expected:

```text
GRANTEE              OWNER       TABLE_NAME       PRIVILEGE
-------------------- ----------- ----------------  ----------
BUSINESS_READ_ROLE   APP_OWNER   CUSTOMER_DATA    SELECT
CUSTOMER_READ_ROLE   APP_OWNER   CUSTOMER_DATA    SELECT
CUSTOMER_WRITE_ROLE  APP_OWNER   CUSTOMER_DATA    INSERT
CUSTOMER_WRITE_ROLE  APP_OWNER   CUSTOMER_DATA    UPDATE
SENSITIVE_ROLE       APP_OWNER   CUSTOMER_DATA    SELECT
```

---

# LAB 38 — Build Security Matrix

Sekarang peserta mengisi matrix:

| User          |     Login | SELECT | INSERT | UPDATE |  Proxy |
| ------------- | --------: | -----: | -----: | -----: | -----: |
| LAB_USER      |         ✅ |      ❌ |      ❌ |      ❌ |      ❌ |
| APP_READER    |         ✅ |      ✅ |      ❌ |      ❌ |      ❌ |
| APP_OPERATOR  |         ✅ |      ✅ |      ✅ |      ✅ |      ❌ |
| APP_PROXY     |         ✅ |      ❌ |      ❌ |      ❌ |      ✅ |
| BUSINESS_USER | via proxy |      ✅ |      ❌ |      ❌ | target |

Tujuan exercise:

> **Authentication menentukan siapa Anda; authorization menentukan apa yang boleh Anda lakukan.**

---

# LAB 39 — Security Challenge: Excessive Privilege

Sekarang buat intentionally insecure user.

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA
```

```sql
CREATE USER bad_app
IDENTIFIED BY "BadApp#2026";
```

```sql
GRANT CREATE SESSION TO bad_app;
```

```sql
GRANT SELECT, INSERT, UPDATE, DELETE
ON app_owner.customer_data
TO bad_app;
```

Diskusikan:

```text
Apakah BAD_APP benar-benar membutuhkan DELETE?
```

Jawaban security:

> Tidak boleh diasumsikan.

Privilege harus diberikan berdasarkan kebutuhan aplikasi.

---

# LAB 40 — Remediate Excessive Privilege

Cabut DELETE:

```sql
REVOKE DELETE
ON app_owner.customer_data
FROM bad_app;
```

Expected:

```text
Revoke succeeded.
```

Verify:

```sql
SELECT
    grantee,
    privilege
FROM dba_tab_privs
WHERE grantee='BAD_APP';
```

Expected:

```text
GRANTEE  PRIVILEGE
-------- ----------
BAD_APP  INSERT
BAD_APP  SELECT
BAD_APP  UPDATE
```

---

# LAB 41 — End-to-End Security Scenario

Sekarang peserta menjalankan scenario lengkap.

## Scenario

```text
User
 |
 v
Application Server
 |
 | APP_PROXY
 v
Oracle Database
 |
 +-- BUSINESS_USER
       |
       +-- BUSINESS_READ_ROLE
               |
               +-- SELECT CUSTOMER_DATA
```

### Step 1

Login:

```bash
sqlplus app_proxy/"Proxy#2026"[business_user]@localhost:1521/pdb1.localdomain
```

### Step 2

Check identity:

```sql
SELECT
    SYS_CONTEXT('USERENV','PROXY_USER') AS proxy_user,
    SYS_CONTEXT('USERENV','SESSION_USER') AS session_user,
    SYS_CONTEXT('USERENV','CURRENT_USER') AS current_user
FROM dual;
```

Expected:

```text
PROXY_USER  SESSION_USER   CURRENT_USER
----------- -------------  -------------
APP_PROXY   BUSINESS_USER  BUSINESS_USER
```

### Step 3

Read data:

```sql
SELECT *
FROM app_owner.customer_data;
```

Expected:

```text
CUSTOMER_ID CUSTOMER_NAME CREDIT_LIMIT
----------- ------------- ------------
1           JOHN DOE      100000
2           JANE DOE      150000
3           ALICE         250000
```

### Step 4

Attempt unauthorized operation:

```sql
DELETE FROM app_owner.customer_data;
```

Expected:

```text
ORA-01031: insufficient privileges
```

### Kesimpulan

Kita berhasil mendapatkan:

```text
Authentication
      +
Authorization
      +
Role
      +
Proxy Identity
      +
Least Privilege
```

---

# LAB 42 — Final Assessment

Peserta harus dapat menjawab pertanyaan berikut tanpa melihat catatan.

### Question 1

Apa perbedaan:

```text
Authentication
```

dan

```text
Authorization
```

### Question 2

Apa fungsi:

```sql
GRANT CREATE SESSION
```

### Question 3

Mengapa lebih baik:

```text
User
  ↓
Role
  ↓
Object Privileges
```

daripada memberikan semua object privilege langsung ke user?

### Question 4

Apa fungsi:

```sql
ALTER USER business_user
GRANT CONNECT THROUGH app_proxy;
```

### Question 5

Apa arti:

```text
PROXY_USER = APP_PROXY
SESSION_USER = BUSINESS_USER
```

### Question 6

Apa keuntungan proxy authentication untuk three-tier application?

### Question 7

Apa perbedaan:

```text
TCP
```

dan

```text
TCPS
```

### Question 8

Apa yang diperlukan agar Global User Authentication/EUS dapat berjalan secara end-to-end?

Jawaban yang diharapkan:

```text
Oracle Database
+
Enterprise Directory / LDAP
+
EUS configuration
+
Directory integration
```

---


---



<!-- ============================================================ -->
<!-- SOURCE: preventive_day2.md -->
<!-- ============================================================ -->

<a id="day-2"></a>

# DAY 2 — Encryption, TDE, Keystore, Backup & Data Pump

> **Sumber file:** `preventive_day2.md`

# DAY 2 — Encryption, TDE, Keystore, Backup & Data Pump

> Diuji langsung pada VM `192.168.56.22`, Oracle 19.8 Enterprise Edition,
> tanggal 7 September 2026. Script dan log tersedia di direktori `testing`.
> Jalankan berurutan. Blok `bash` dijalankan di shell Linux VM, blok `sql`
> di SQL*Plus, dan blok `rman` di RMAN. Gunakan `EXIT` sebelum berpindah program.
> Output tabel di bawah adalah ringkasan nilai hasil uji; timestamp, key ID,
> nama backup, ukuran, dan spasi alignment dapat berubah.
>
> Prasyarat awal: PDB1 terbuka READ WRITE, objek TDE_OWNER/TDE_IMPORT,
> TS_SECURE/TS_EXAM_SECURE dan DAY2_DUMP belum ada. Jangan mengulang CREATE
> di tengah lab. Cleanup dilakukan **setelah Final Practical Test**.
> Password dalam dokumen adalah kredensial khusus VM latihan.

---

# 1. Target Pembelajaran

Setelah Day 2, peserta mampu:

1. Menjelaskan konsep encryption.
2. Membedakan:

   * encryption at rest
   * encryption in transit
   * application-level encryption
3. Memahami TDE.
4. Memahami:

   * master encryption key
   * keystore
   * wallet
   * encrypted data
5. Membuat software keystore.
6. Membuka/menutup keystore.
7. Membuat TDE master key.
8. Menggunakan TDE pada:

   * column
   * tablespace
9. Memeriksa status encryption.
10. Memahami database storage security.
11. Melakukan RMAN backup.
12. Memahami batasan RMAN backup pada mode archive log.
13. Memahami perbedaan:

* transparent encryption
* password encryption

14. Melakukan Data Pump export/import encrypted data.
15. Melakukan verification bahwa data tetap dapat digunakan setelah encryption.

---

# 2. Arsitektur Lab

Environment:

```text
OS              Oracle Linux 7.8
Oracle Version  19.8.0.0.0
ORACLE_SID      oradb
ORACLE_HOME     /u01/app/oracle/product/19.0.0/db_1
ORACLE_BASE     /u01/app/oracle
CDB             ORADB
PDB             PDB1
SYS Password    oracle
Host            192.168.56.22 / srv1.localdomain
Service         pdb1.localdomain
Awal LOG_MODE   NOARCHIVELOG
```

Kita akan membuat direktori khusus:

```text
/u01/app/oracle/admin/oradb/wallet
/u01/app/oracle/admin/oradb/rman
/u01/app/oracle/admin/oradb/dpump
```

---

# LAB 1 — Prepare Environment dan Format SQL*Plus

Login dari komputer host:

```bash
ssh oracle@192.168.56.22
```

Password OS: `oracle`. Jika sudah login sebagai oracle, tidak perlu `su - oracle`.

```bash
export ORACLE_SID=oradb
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/db_1
export ORACLE_BASE=/u01/app/oracle
export PATH=$ORACLE_HOME/bin:$PATH
echo "ORACLE_SID=$ORACLE_SID"
echo "ORACLE_HOME=$ORACLE_HOME"
echo "ORACLE_BASE=$ORACLE_BASE"
sqlplus -version
lsnrctl status
```

Hasil uji: SQL*Plus 19.8.0.0.0; listener menerima service
`pdb1.localdomain`. Nama internal `pdb1` dari V$SERVICES tidak cukup untuk
menentukan connect string: koneksi `localhost:1521/pdb1` pada VM ini gagal
`ORA-12514`. Gunakan service listener yang terverifikasi.

Buat file format satu kali:

```bash
mkdir -p /home/oracle/day2_lab
cat > /home/oracle/day2_lab/format.sql <<'SQL'
SET LINESIZE 220
SET PAGESIZE 100
SET TAB OFF
SET TRIMSPOOL ON
SET WRAP ON
SET FEEDBACK ON
SET VERIFY OFF
SET NUMWIDTH 12
ALTER SESSION SET NLS_DATE_FORMAT='YYYY-MM-DD HH24:MI:SS';
ALTER SESSION SET NLS_TIMESTAMP_TZ_FORMAT='YYYY-MM-DD HH24:MI:SS TZH:TZM';
COLUMN con_id FORMAT 999999
COLUMN name FORMAT A22
COLUMN db_unique_name FORMAT A16
COLUMN cdb FORMAT A3
COLUMN open_mode FORMAT A12
COLUMN log_mode FORMAT A14
COLUMN wrl_type FORMAT A8
COLUMN wrl_parameter FORMAT A55
COLUMN status FORMAT A20
COLUMN wallet_type FORMAT A12
COLUMN wallet_order FORMAT A12
COLUMN key_id FORMAT A55
COLUMN tag FORMAT A24
COLUMN creation_time FORMAT A32
COLUMN activation_time FORMAT A32
COLUMN owner FORMAT A12
COLUMN table_name FORMAT A22
COLUMN column_name FORMAT A16
COLUMN encryption_alg FORMAT A20
COLUMN salt FORMAT A4
COLUMN encrypted FORMAT A9
COLUMN tablespace_name FORMAT A20
COLUMN file_name FORMAT A75
COLUMN customer_id FORMAT 9999999999
COLUMN customer_name FORMAT A20
COLUMN credit_card FORMAT A20
COLUMN salary FORMAT 999,999,990.00
COLUMN account_balance FORMAT 999,999,990.00
COLUMN created_date FORMAT A19
COLUMN description FORMAT A25
SQL
```

Setiap membuka SQL*Plus baru atau menjalankan `CONNECT`, jalankan:

```sql
@/home/oracle/day2_lab/format.sql
SHOW USER
SHOW CON_NAME
```

Langkah ini mengatur ulang format tanggal dan timestamp yang bersifat session-local.
Jangan mengetik prompt `SQL>` atau `RMAN>` sebagai bagian command.

---

# LAB 2 — Create Lab Directories

Jalankan sebagai user `oracle`:

```bash
umask 077
mkdir -p /u01/app/oracle/admin/oradb/wallet
mkdir -p /u01/app/oracle/admin/oradb/rman
mkdir -p /u01/app/oracle/admin/oradb/dpump
```

Verify:

```bash
ls -ld \
/u01/app/oracle/admin/oradb/wallet \
/u01/app/oracle/admin/oradb/rman \
/u01/app/oracle/admin/oradb/dpump
```

Expected:

```text
drwx------ oracle oinstall ... /u01/app/oracle/admin/oradb/wallet
drwx------ oracle oinstall ... /u01/app/oracle/admin/oradb/rman
drwx------ oracle oinstall ... /u01/app/oracle/admin/oradb/dpump
```

---

# LAB 3 — Baseline Database

Login:

```bash
sqlplus sys/oracle@localhost:1521/pdb1.localdomain as sysdba
```

Check:

```sql
SELECT
    name,
    db_unique_name,
    cdb,
    open_mode
FROM v$database;
```

Expected:

```text
NAME   DB_UNIQUE_NAME  CDB  OPEN_MODE
------ --------------- ---- ----------
ORADB  oradb           YES  READ WRITE
```

Check PDB:

```sql
SHOW CON_NAME;
```

Expected:

```text
CON_NAME
------------------------------
PDB1
```

---

# LAB 4 — Understand Encryption

Sebelum hands-on TDE, peserta perlu memahami:

```text
PLAINTEXT
   |
   | Encryption
   v
CIPHERTEXT
   |
   | Decryption
   v
PLAINTEXT
```

Contoh sederhana:

```text
Credit Card:

4111111111111111
       |
       | encryption
       v
A8F3C91D7...
```

Database user tetap melakukan:

```sql
SELECT credit_card
FROM customer;
```

dan Oracle melakukan dekripsi transparan apabila user mempunyai privilege yang sesuai, keystore terbuka, serta master key yang diperlukan tersedia. Query di atas merupakan ilustrasi; tabel CUSTOMER tidak dibuat dalam lab.

Inilah alasan disebut:

> **Transparent Data Encryption**

---

# LAB 5 — Encryption at Rest vs In Transit

Peserta harus membedakan tiga konsep:

### Encryption at Rest

```text
Database
   |
   +--- Datafile
   +--- Tablespace
   +--- Backup
   +--- Disk
```

TDE melindungi data yang tersimpan.

### Encryption in Transit

```text
Client
   |
   | TLS / TCPS
   v
Database
```

Melindungi data selama perjalanan melalui network.

### Application Encryption

```text
Application
     |
     | encrypt()
     v
Database
```

Encryption dilakukan oleh application.

### Fokus Day 2

```text
                 Day 2
                   |
          +--------+--------+
          |                 |
       TDE               Backup
          |                 |
       At Rest          RMAN/Data Pump
```

---

# LAB 6 — Check Existing TDE Configuration

Sebagai SYS, periksa root sebelum membuat wallet:

```sql
ALTER SESSION SET CONTAINER=CDB$ROOT;
SHOW PARAMETER wallet_root
SHOW PARAMETER tde_configuration
SELECT con_id,wrl_type,wrl_parameter,status,wallet_type,wallet_order
FROM v$encryption_wallet ORDER BY con_id;
```

Hasil awal VM: WALLET_ROOT dan TDE_CONFIGURATION kosong; CON_ID 1, 2, 3
berstatus `NOT_AVAILABLE`, WALLET_TYPE `UNKNOWN`. WRL_PARAMETER root:
`/u01/app/oracle/admin/oradb/wallet`; baris PDB tidak menampilkan path sendiri.
VM ini memakai lokasi wallet default tersebut; CREATE KEYSTORE tidak otomatis
mengubah lokasi pencarian wallet pada host lain.

Jika wallet sudah tersedia, jangan overwrite, hapus, atau membuat key baru
sebagai pengganti key existing. Pastikan lokasi, password, dan key yang ada
sebelum memilih langkah open/verify yang sesuai. CLOSED tidak berarti wallet
belum ada.

Kembali ke PDB untuk Lab 7–8:

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

---

# LAB 7 — Check Existing Encryption

```sql
SELECT
    TABLESPACE_NAME,
    ENCRYPTED
FROM DBA_TABLESPACES
ORDER BY TABLESPACE_NAME;
```

Contoh:

```text
TABLESPACE_NAME  ENCRYPTED
---------------- ---------
SYSAUX           NO
SYSTEM           NO
TEMP             NO
UNDOTBS1         NO
USERS            NO
```

Jika ada tablespace `YES`, berarti sudah encrypted.

---

# LAB 8 — Check Encrypted Columns

```sql
SELECT
    OWNER,
    TABLE_NAME,
    COLUMN_NAME,
    ENCRYPTION_ALG,
    SALT
FROM DBA_ENCRYPTED_COLUMNS
ORDER BY OWNER, TABLE_NAME, COLUMN_NAME;
```

Jika belum ada encrypted column:

```text
no rows selected
```

---

# LAB 9 — Create TDE Software Keystore

> 🟢 CORE LAB
> Jalankan hanya apabila LAB 6 menunjukkan belum ada keystore yang digunakan.

Kita akan menggunakan:

```text
/u01/app/oracle/admin/oradb/wallet
```

Masuk CDB root:

```sql
ALTER SESSION SET CONTAINER=CDB$ROOT;
```

Verify:

```sql
SHOW CON_NAME;
```

Expected:

```text
CON_NAME
------------------------------
CDB$ROOT
```

Create keystore:

```sql
ADMINISTER KEY MANAGEMENT
CREATE KEYSTORE
'/u01/app/oracle/admin/oradb/wallet'
IDENTIFIED BY "TDEWallet#2026";
```

Expected:

```text
keystore altered.
```

---

# LAB 10 — Verify Keystore

Tetap sebagai SYS di CDB$ROOT:

```sql
SELECT con_id,wrl_parameter,status,wallet_type
FROM v$encryption_wallet ORDER BY con_id;
```

Hasil setelah CREATE: CON_ID 1, 2, 3 = `CLOSED`, WALLET_TYPE `UNKNOWN`.
Path root `/u01/app/oracle/admin/oradb/wallet`; path baris PDB kosong.

---

# LAB 11 — Open Keystore

SYS di CDB$ROOT:

```sql
ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN
IDENTIFIED BY "TDEWallet#2026" CONTAINER=ALL;
SELECT con_id,status,wallet_type FROM v$encryption_wallet ORDER BY con_id;
```

Hasil uji sebelum master key dibuat:

```text
CON_ID STATUS               WALLET_TYPE
1      OPEN_NO_MASTER_KEY   PASSWORD
2      OPEN_NO_MASTER_KEY   PASSWORD
3      OPEN_NO_MASTER_KEY   PASSWORD
```

`OPEN_NO_MASTER_KEY` berbeda dengan `OPEN`: lanjutkan pembuatan master key.

---

# LAB 12 — Understand Master Encryption Key

Sekarang:

```sql
SELECT
    CON_ID,
    KEY_ID,
    CREATION_TIME,
    ACTIVATION_TIME,
    TAG
FROM V$ENCRYPTION_KEYS
ORDER BY CON_ID, CREATION_TIME;
```

Jika master key belum dibuat, bisa belum ada active key.

---

# LAB 13 — Create TDE Master Key

Pastikan di CDB root:

```sql
SHOW CON_NAME;
```

Kemudian:

```sql
ADMINISTER KEY MANAGEMENT
SET KEY USING TAG 'DAY2_INITIAL_KEY'
IDENTIFIED BY "TDEWallet#2026"
WITH BACKUP
USING 'DAY2_INITIAL_KEY'
CONTAINER=ALL;
```

Expected:

```text
keystore altered.
```

### Kenapa `WITH BACKUP`?

Karena master encryption key merupakan komponen sangat penting.

Secara konsep:

```text
Master Key
     |
     +--- Encryption keys
     |
     +--- Encrypted data
```

Kehilangan master key dapat menyebabkan data encrypted tidak dapat didecrypt.

---

# LAB 14 — Verify Master Key

```sql
SELECT
    CON_ID,
    KEY_ID,
    CREATION_TIME,
    ACTIVATION_TIME,
    TAG
FROM V$ENCRYPTION_KEYS
ORDER BY CON_ID, CREATION_TIME;
```

Expected akan terdapat key:

```text
CON_ID  KEY_ID                     CREATION_TIME
------  -------------------------  -------------------
1       ...                        <waktu pembuatan key>
3       ...                        <waktu pembuatan key>
```

`KEY_ID` adalah identifier key, bukan password.

---

# LAB 15 — Verify Keystore Again

```sql
SELECT
    CON_ID,
    STATUS,
    WALLET_TYPE,
    WALLET_ORDER
FROM V$ENCRYPTION_WALLET
ORDER BY CON_ID;
```

Expected:

```text
CON_ID  STATUS  WALLET_TYPE
------  ------  -----------
1       OPEN    PASSWORD
2       OPEN    PASSWORD
3       OPEN    PASSWORD
```

---

# LAB 16 — Create TDE Training Schema

Switch ke PDB1:

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

Create owner:

```sql
CREATE USER tde_owner
IDENTIFIED BY "TDEOwner#2026" DEFAULT TABLESPACE users;
```

Grant:

```sql
GRANT CREATE SESSION, CREATE TABLE
TO tde_owner;
```

Berikan quota pada default tablespace. Tanpa quota, `CREATE TABLE` dapat
berhasil karena deferred segment creation, tetapi `INSERT` pertama gagal dengan
`ORA-01950: no privileges on tablespace 'USERS'`.

```sql
ALTER USER tde_owner QUOTA 100M ON users;
```

Expected:

```text
User created.

Grant succeeded.

User altered.
```

---

# LAB 17 — Create Sensitive Data Table

Login:

```sql
CONNECT tde_owner/"TDEOwner#2026"@localhost:1521/pdb1.localdomain
@/home/oracle/day2_lab/format.sql
```

Create:

```sql
CREATE TABLE customer_secure (
    customer_id NUMBER PRIMARY KEY,
    customer_name VARCHAR2(100),
    credit_card VARCHAR2(32),
    salary NUMBER(15,2),
    created_date DATE
) TABLESPACE users;
```

Expected:

```text
Table created.
```

---

# LAB 18 — Insert Training Data

```sql
INSERT INTO customer_secure
VALUES (
    1,
    'JOHN DOE',
    '4111111111111111',
    15000000,
    SYSDATE
);

INSERT INTO customer_secure
VALUES (
    2,
    'JANE DOE',
    '5555555555554444',
    17500000,
    SYSDATE
);

INSERT INTO customer_secure
VALUES (
    3,
    'ALICE',
    '378282246310005',
    22000000,
    SYSDATE
);

COMMIT;
```

Expected:

```text
1 row created.
1 row created.
1 row created.

Commit complete.
```

Verify:

```sql
SELECT
    customer_id,
    customer_name,
    credit_card,
    salary
FROM customer_secure
ORDER BY customer_id;
```

Expected:

```text
CUSTOMER_ID CUSTOMER_NAME CREDIT_CARD       SALARY
----------- ------------- ----------------- ----------
1           JOHN DOE      4111111111111111  15,000,000.00
2           JANE DOE     5555555555554444  17,500,000.00
3           ALICE        378282246310005    22,000,000.00
```

---

# LAB 19 — Column-Level TDE

Sekarang kita encrypt hanya kolom sensitif:

```text
credit_card
```

Login SYS:

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA
@/home/oracle/day2_lab/format.sql
```

Execute:

```sql
ALTER TABLE tde_owner.customer_secure
MODIFY (
    credit_card ENCRYPT USING 'AES256'
);
```

Expected:

```text
Table altered.
```

---

# LAB 20 — Verify Encrypted Column

```sql
SELECT
    OWNER,
    TABLE_NAME,
    COLUMN_NAME,
    ENCRYPTION_ALG,
    SALT
FROM DBA_ENCRYPTED_COLUMNS
WHERE OWNER='TDE_OWNER'
AND TABLE_NAME='CUSTOMER_SECURE';
```

Expected:

```text
OWNER      TABLE_NAME       COLUMN_NAME  ENCRYPTION_ALG  SALT
---------- ---------------  ------------ --------------- ---
TDE_OWNER  CUSTOMER_SECURE  CREDIT_CARD  AES 256 bits key YES
```

Nilai `ENCRYPTION_ALG` adalah display value dan dapat berbeda antar patchset;
pada host lab Oracle 19.8 nilainya adalah `AES 256 bits key`.

---

# LAB 21 — Query Encrypted Data

Login kembali:

```sql
CONNECT tde_owner/"TDEOwner#2026"@localhost:1521/pdb1.localdomain
@/home/oracle/day2_lab/format.sql
```

Query:

```sql
SELECT
    customer_id,
    customer_name,
    credit_card
FROM customer_secure
ORDER BY customer_id;
```

Expected:

```text
CUSTOMER_ID CUSTOMER_NAME CREDIT_CARD
----------- ------------- -----------------
1           JOHN DOE      4111111111111111
2           JANE DOE      5555555555554444
3           ALICE        378282246310005
```

### Perhatikan

User tidak perlu:

```text
decrypt()
```

atau:

```text
encrypt()
```

pada SQL.

Inilah konsep:

> **Transparent Data Encryption**

---

# LAB 22 — Verify Datafile/Tablespace Encryption

Sekarang kita buat tablespace encrypted.

Pertama login SYS:

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA
@/home/oracle/day2_lab/format.sql
```

Check datafile location:

```sql
SELECT
    file_name,
    tablespace_name
FROM dba_data_files
ORDER BY file_name;
```

Expected environment Anda kurang lebih:

```text
/u01/app/oracle/oradata/ORADB/...
```

---

# LAB 23 — Create Dedicated Encrypted Tablespace

Kita tidak akan mengubah USERS/SYSTEM/SYSAUX.

Create:

```sql
CREATE TABLESPACE ts_secure
DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/ts_secure01.dbf'
SIZE 100M
AUTOEXTEND ON
NEXT 10M
MAXSIZE 500M
ENCRYPTION USING 'AES256'
DEFAULT STORAGE (ENCRYPT);
```

Expected:

```text
Tablespace created.
```

Sebelum Lab 26, berikan quota pada tablespace baru:

```sql
ALTER USER tde_owner QUOTA 100M ON ts_secure;
```

---

# LAB 24 — Verify Tablespace Encryption

```sql
SELECT
    TABLESPACE_NAME,
    ENCRYPTED
FROM DBA_TABLESPACES
WHERE TABLESPACE_NAME='TS_SECURE';
```

Expected:

```text
TABLESPACE_NAME  ENCRYPTED
---------------- ---------
TS_SECURE        YES
```

---

# LAB 25 — Verify Encrypted Datafile

Sebagai SYS di PDB1:

```sql
SELECT file_name,tablespace_name FROM dba_data_files
WHERE tablespace_name='TS_SECURE';
SELECT tablespace_name,encrypted FROM dba_tablespaces
WHERE tablespace_name='TS_SECURE';
```

Hasil query pertama: FILE_NAME
`/u01/app/oracle/oradata/ORADB/pdb1/ts_secure01.dbf`, TABLESPACE_NAME `TS_SECURE`.
Query kedua: `TS_SECURE`, ENCRYPTED `YES`.
V$DATAFILE tidak menyediakan kombinasi kolom FILE_NAME/TABLESPACE_NAME/ENCRYPTED
yang digunakan dalam query dictionary di atas.

---

# LAB 26 — Create Table Inside Encrypted Tablespace

Login:

```sql
CONNECT tde_owner/"TDEOwner#2026"@localhost:1521/pdb1.localdomain
@/home/oracle/day2_lab/format.sql
```

Create:

```sql
CREATE TABLE encrypted_customer (
    id NUMBER PRIMARY KEY,
    name VARCHAR2(100),
    account_balance NUMBER(15,2)
)
TABLESPACE ts_secure;
```

Expected:

```text
Table created.
```

Insert:

```sql
INSERT INTO encrypted_customer
VALUES (1,'CUSTOMER A',5000000);

INSERT INTO encrypted_customer
VALUES (2,'CUSTOMER B',7500000);

COMMIT;
```

Verify:

```sql
SELECT *
FROM encrypted_customer ORDER BY id;
```

Expected:

```text
ID  NAME          ACCOUNT_BALANCE
--  ------------  ---------------
1   CUSTOMER A          5,000,000.00
2   CUSTOMER B          7,500,000.00
```

---

# LAB 27 — Compare Column Encryption vs Tablespace Encryption

Sekarang:

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA
@/home/oracle/day2_lab/format.sql
```

Run:

```sql
SELECT
    tablespace_name,
    encrypted
FROM dba_tablespaces
WHERE tablespace_name IN ('USERS','TS_SECURE')
ORDER BY tablespace_name;
```

Expected:

```text
TABLESPACE_NAME  ENCRYPTED
---------------- ---------
TS_SECURE        YES
USERS            NO
```

Dan:

```sql
SELECT
    owner,
    table_name,
    column_name,
    encryption_alg
FROM dba_encrypted_columns
WHERE owner='TDE_OWNER';
```

Expected:

```text
OWNER      TABLE_NAME       COLUMN_NAME  ENCRYPTION_ALG
---------- ---------------  ------------ --------------
TDE_OWNER  CUSTOMER_SECURE  CREDIT_CARD  AES 256 bits key
```

### Kesimpulan

Ada dua pendekatan:

```text
Column-Level TDE
       ↓
Encrypt specific sensitive column
```

dan:

```text
Tablespace TDE
       ↓
Encrypt data stored in tablespace
```

---

# LAB 28 — Create New TDE Master Key

Rotasi satu kali sebagai SYS di PDB1:

```sql
ALTER SESSION SET CONTAINER=PDB1;
ADMINISTER KEY MANAGEMENT SET KEY USING TAG 'DAY2_KEY_ROTATION'
IDENTIFIED BY "TDEWallet#2026"
WITH BACKUP USING 'DAY2_KEY_ROTATION' CONTAINER=CURRENT;
SELECT con_id,key_id,tag FROM v$encryption_keys ORDER BY creation_time;
SELECT customer_id,credit_card FROM tde_owner.customer_secure ORDER BY customer_id;
```

Hasil: `keystore altered.`, dua key PDB1 dengan TAG `DAY2_INITIAL_KEY` dan
`DAY2_KEY_ROTATION`; ketiga kartu kredit tetap terbaca.
`CONTAINER=PDB1` bukan sintaks valid; gunakan CURRENT setelah pindah container.
`USING TAG` memberi label pada key, sedangkan `WITH BACKUP USING` memberi
identifier nama file backup. Keduanya berbeda.
Rotasi master key tidak menghapus key lama dan bukan pemulihan key yang hilang.

---

# LAB 29 — Check Keystore Backup Files

Backup keystore **setelah** rotasi untuk menyimpan key aktif terbaru.
WITH BACKUP pada SET KEY membackup kondisi sebelum perubahan.

```sql
ALTER SESSION SET CONTAINER=CDB$ROOT;
ADMINISTER KEY MANAGEMENT BACKUP KEYSTORE USING 'DAY2_POST_ROTATION'
IDENTIFIED BY "TDEWallet#2026";
```

Dari OS:

```bash
find /u01/app/oracle/admin/oradb/wallet \
-maxdepth 1 \
-type f \
-ls
```

Expected akan terdapat file keystore dan/atau backup key.

Contoh:

```text
... ewallet.p12
... ewallet_....p12
```

**Nama file dapat berbeda.**

Jangan menghapus file tersebut.

---

# LAB 30 — Understand Auto Login Keystore

Bagian konsep dan pemeriksaan, tanpa membuat auto-login wallet:

```sql
SELECT status,wallet_type,wallet_order FROM v$encryption_wallet;
```

Wallet lab menggunakan `PASSWORD`. Auto-login memakai `cwallet.sso` dan dapat
membuka wallet otomatis. Lab ini mempertahankan password wallet agar skenario
wallet CLOSED → akses gagal → OPEN → akses pulih dapat dipraktikkan.

---

# LAB 31 — RMAN Baseline Backup

Sekarang masuk ke:

> Database Storage Security
> RMAN disk backups

Buat backup directory:

```bash
mkdir -p /u01/app/oracle/admin/oradb/rman
```

Login RMAN:

```bash
rman target /
```

Expected:

```text
Recovery Manager: Release 19.0.0.0.0

connected to target database:
ORADB
```

---

# LAB 32 — Check RMAN Configuration

```rman
SHOW ALL;
```

Perhatikan terutama:

```text
CONFIGURE RETENTION POLICY
CONFIGURE BACKUP OPTIMIZATION
CONFIGURE DEFAULT DEVICE TYPE
CONFIGURE CHANNEL DEVICE TYPE
```

---

# LAB 33 — Configure Backup Destination

Kita gunakan disk backup untuk training.

```rman
CONFIGURE CHANNEL DEVICE TYPE DISK
FORMAT '/u01/app/oracle/admin/oradb/rman/%U.bkp';
```

Expected:

```text
new RMAN configuration parameters:
CONFIGURE CHANNEL DEVICE TYPE DISK FORMAT
'/u01/app/oracle/admin/oradb/rman/%U.bkp';
new RMAN configuration parameters are successfully stored
```

---

# LAB 34 — Enable ARCHIVELOG

Keluar RMAN dengan `EXIT`, kemudian login lokal sebagai SYS ke CDB root:

```bash
sqlplus / as sysdba
```

```sql
@/home/oracle/day2_lab/format.sql
SHOW CON_NAME
ARCHIVE LOG LIST;
```

Jika sudah Archive Mode, lewati restart berikut. Pada kondisi awal VM hasilnya
No Archive Mode. Langkah berikut me-restart seluruh CDB:

```sql
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;
ALTER PLUGGABLE DATABASE ALL OPEN;
ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN
IDENTIFIED BY "TDEWallet#2026" CONTAINER=ALL;
ALTER SYSTEM REGISTER;
ARCHIVE LOG LIST;
SELECT con_id,status,wallet_type FROM v$encryption_wallet ORDER BY con_id;
EXIT
```

Hasil uji: Archive Mode, Automatic archival Enabled; wallet CON_ID 1, 2, 3
OPEN / PASSWORD. Buka sesi RMAN baru untuk Lab 35:

```bash
rman target /
```

---

# LAB 35 — RMAN Online Backup

Baseline awal VM memiliki konfigurasi enkripsi RMAN OFF. Gunakan SET berikut
agar backup pembanding tetap tanpa lapisan enkripsi RMAN jika lab diulang;
pengaturan ini hanya berlaku untuk sesi RMAN saat ini.

```rman
SET ENCRYPTION OFF;
BACKUP DATABASE TAG 'DAY2_BASELINE';
LIST BACKUP SUMMARY;
```

Expected: backup set bertipe `DISK` dan control-file/SPFILE autobackup.

---

# LAB 36 — Verify Physical Backup Files

Keluar RMAN dengan `EXIT`, kemudian jalankan di shell:

```bash
ls -lh /u01/app/oracle/admin/oradb/rman
```

---

# LAB 37 — RMAN Encryption Concept

Ada tiga konsep yang perlu dibedakan:

### 1. No RMAN encryption

```text
Database
   |
   v
Backup
   |
   v
Tidak ada lapisan enkripsi RMAN tambahan
```

Data TDE dalam backup tetap terlindungi oleh TDE; RMAN encryption OFF
tidak berarti seluruh isi backup menjadi plaintext.

### 2. Transparent encryption

```text
Database
   |
   v
RMAN
   |
   v
Encryption using configured wallet
```

### 3. Password-based encryption

```text
Database
   |
   v
RMAN
   |
   v
Password
   |
   v
Encrypted backup
```

---

# LAB 38 — RMAN Transparent Encryption

Pastikan keystore root dan seluruh PDB yang dibackup OPEN (hasil Lab 34).
Pemeriksaan berikut menampilkan PDB1.

```bash
sqlplus / as sysdba
```

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

```sql
SELECT
    STATUS,
    WALLET_TYPE
FROM V$ENCRYPTION_WALLET;
```

Expected:

```text
STATUS  WALLET_TYPE
------- -----------
OPEN    PASSWORD
```

Keluar:

```sql
EXIT
```

Masuk RMAN:

```bash
rman target /
```

Configure:

```rman
CONFIGURE ENCRYPTION FOR DATABASE ON;
```

Expected:

```text
new RMAN configuration parameters:
CONFIGURE ENCRYPTION FOR DATABASE ON;
new RMAN configuration parameters are successfully stored
```

---

# LAB 39 — Encrypted RMAN Backup

Pastikan keystore masih `OPEN`, lalu jalankan:

```rman
BACKUP DATABASE TAG 'DAY2_TRANSPARENT';
LIST BACKUP SUMMARY;
```

Pada host lab, backup transparan berhasil setelah `ARCHIVELOG` diaktifkan dan
keystore dibuka ulang setelah restart.

---

# LAB 40 — Verify RMAN Encryption

Di RMAN:

```rman
SHOW ALL;
SHOW ENCRYPTION ALGORITHM;
```

Hasil VM: CONFIGURE ENCRYPTION FOR DATABASE ON dan algoritma default AES128.
Ini terpisah dari AES256 pada kolom/tablespace TDE.
Untuk memeriksa backup piece aktual, ketik `EXIT` di RMAN dan masuk SQL*Plus root:

```bash
sqlplus / as sysdba
```

```sql
@/home/oracle/day2_lab/format.sql
SELECT recid,tag,encrypted FROM v$backup_piece
WHERE tag IN ('DAY2_BASELINE','DAY2_TRANSPARENT','DAY2_PASSWORD')
ORDER BY recid;
EXIT
```

Hasil: tiga piece DAY2_BASELINE = NO, tiga piece DAY2_TRANSPARENT = YES.
DAY2_PASSWORD muncul setelah Lab 41. LIST BACKUP SUMMARY saja tidak
membuktikan enkripsi piece.

```bash
rman target /
```

---

# LAB 41 — Password-Based RMAN Backup PDB1

Jalankan `SET ENCRYPTION` di luar blok `RUN`, seperti pengujian ini. Karena
`TS_SECURE` adalah tablespace PDB, gunakan backup PDB, bukan
`BACKUP TABLESPACE TS_SECURE` dari CDB root.

```rman
SET ENCRYPTION ON IDENTIFIED BY "RMANBackup#2026" ONLY;
BACKUP PLUGGABLE DATABASE pdb1
  FORMAT '/u01/app/oracle/admin/oradb/rman/password_%U.bkp'
  TAG 'DAY2_PASSWORD';
LIST BACKUP SUMMARY;
```

Expected: piece `password_...bkp` tercatat di backup summary.

---

# LAB 42 — Backup RMAN Tidak Dapat Didekripsi, Lalu Dipulihkan

Keluar RMAN dengan EXIT, lalu buka sesi baru agar tidak membawa SET sesi lama:

```bash
rman target /
```

```rman
LIST BACKUP TAG 'DAY2_PASSWORD';
```

Catat **BS Key** hasil LIST. Pada pengujian pertama nilainya 9. Ganti angka 9
di bawah jika nilai pada VM Anda berbeda. Wallet database tetap OPEN.

```rman
VALIDATE BACKUPSET 9;
```

Hasil uji: ORA-19870 dan `ORA-19913: unable to decrypt backup`.
Password-only backup memerlukan password backup meskipun wallet terbuka.

```rman
SET DECRYPTION IDENTIFIED BY "RMANBackup#2026";
VALIDATE BACKUPSET 9;
```

Hasil: `validation complete`. Untuk backup transparan, gunakan BS Key dari
`LIST BACKUP TAG 'DAY2_TRANSPARENT';` saat wallet OPEN. Hasil pengujian ketiga
backup set transparan juga `validation complete`.
VALIDATE membaca dan memvalidasi backup tanpa menimpa datafile aktif;
ini belum merupakan simulasi restore/recovery penuh database.

---

# LAB 43 — Lengkapi Backup Online dengan Archived Redo

Keluar RMAN dan buka sesi RMAN baru. Konfigurasi persisten encryption ON
dari Lab 38 berlaku; wallet root/PDB harus OPEN.

```bash
rman target /
```

```rman
SQL 'ALTER SYSTEM ARCHIVE LOG CURRENT';
BACKUP ARCHIVELOG ALL TAG 'DAY2_ARCHIVELOG';
BACKUP CURRENT CONTROLFILE TAG 'DAY2_CONTROLFILE';
LIST BACKUP SUMMARY;
EXIT
```

Backup datafile online perlu redo yang sesuai untuk recovery. Simpan backup
archived redo, controlfile/SPFILE, dan wallet yang berisi key yang diperlukan.
Lab ini tidak menghapus archived redo. Backup file wallet Lab 29 harus turut
disalin ke tempat backup terpisah jika backup dipindahkan keluar VM.

---

# LAB 44 — Data Pump Encrypted Data

Sekarang kita masuk ke:

> Data Pump Export and Import of Encrypted Data

Kita akan menggunakan table:

```text
TDE_OWNER.CUSTOMER_SECURE
```

---

# LAB 45 — Prepare Data Pump Directory

Login SYS:

```bash
sqlplus sys/oracle@localhost:1521/pdb1.localdomain as sysdba
```

Create Oracle directory:

```sql
CREATE OR REPLACE DIRECTORY DAY2_DUMP
AS '/u01/app/oracle/admin/oradb/dpump';
```

Grant:

```sql
GRANT READ, WRITE
ON DIRECTORY DAY2_DUMP
TO tde_owner;
```

Expected:

```text
Directory created.

Grant succeeded.
```

---

# LAB 46 — Data Pump Export

Keluar SQL*Plus dengan EXIT. Jalankan di shell:

```bash
expdp 'tde_owner/TDEOwner#2026@localhost:1521/pdb1.localdomain' \
DIRECTORY=DAY2_DUMP \
DUMPFILE=tde_customer.dmp \
LOGFILE=tde_customer_exp.log \
TABLES=TDE_OWNER.CUSTOMER_SECURE \
ENCRYPTION=ALL \
ENCRYPTION_MODE=PASSWORD \
ENCRYPTION_ALGORITHM=AES256 \
ENCRYPTION_PASSWORD=DataPump#2026
```

Backslash harus merupakan karakter terakhir di baris, tanpa spasi setelahnya.
Mode PASSWORD membuat dump memerlukan password meskipun wallet database terbuka.
Dump file harus belum ada; gunakan nama dump/log baru untuk pengulangan export.
Hasil uji: CUSTOMER_SECURE diekspor 3 rows dan job successfully completed.
TDE tabel tidak otomatis mengenkripsi dump; ENCRYPTION=ALL melindungi data
dan metadata dump pada skenario ini.

---

# LAB 47 — Verify Dump File

```bash
ls -lh /u01/app/oracle/admin/oradb/dpump
```

Expected:

```text
-rw-r----- oracle oinstall ... tde_customer.dmp
-rw-r--r-- oracle oinstall ... tde_customer_exp.log
```

---

# LAB 48 — Import: Akses Dump Gagal dan Dipulihkan

Login SYS PDB1 dari shell:

```bash
sqlplus sys/oracle@localhost:1521/pdb1.localdomain as sysdba
```

```sql
@/home/oracle/day2_lab/format.sql
CREATE USER tde_import IDENTIFIED BY "TDEImport#2026"
DEFAULT TABLESPACE users QUOTA 100M ON users;
GRANT CREATE SESSION,CREATE TABLE TO tde_import;
GRANT READ,WRITE ON DIRECTORY day2_dump TO tde_import;
EXIT
```

Percobaan tanpa password dump (sengaja gagal):

```bash
impdp 'tde_import/TDEImport#2026@localhost:1521/pdb1.localdomain' \
DIRECTORY=DAY2_DUMP \
DUMPFILE=tde_customer.dmp \
LOGFILE=tde_customer_nopassword.log \
REMAP_SCHEMA=TDE_OWNER:TDE_IMPORT
```

Hasil uji:

```text
ORA-39002: invalid operation
ORA-39174: Encryption password must be supplied.
```

Jalankan ulang dengan password yang digunakan saat export:

```bash
impdp 'tde_import/TDEImport#2026@localhost:1521/pdb1.localdomain' \
DIRECTORY=DAY2_DUMP \
DUMPFILE=tde_customer.dmp \
LOGFILE=tde_customer_imp.log \
REMAP_SCHEMA=TDE_OWNER:TDE_IMPORT \
ENCRYPTION_PASSWORD=DataPump#2026
```

Hasil uji: CUSTOMER_SECURE diimpor 3 rows dan job successfully completed.
Wallet tujuan juga harus terbuka untuk membuat kolom TDE. Password dump
berbeda dari password user database maupun password wallet.

---

# LAB 49 — Verify Imported Data

```bash
sqlplus tde_import/"TDEImport#2026"@localhost:1521/pdb1.localdomain
```

Run:

```sql
SELECT
    customer_id,
    customer_name,
    credit_card,
    salary
FROM customer_secure
ORDER BY customer_id;
```

Expected:

```text
CUSTOMER_ID CUSTOMER_NAME CREDIT_CARD       SALARY
----------- ------------- ----------------- ----------
1           JOHN DOE      4111111111111111  15,000,000.00
2           JANE DOE      5555555555554444  17,500,000.00
3           ALICE        378282246310005    22,000,000.00
```

---

# LAB 50 — Verify Imported Table Encryption Status

Keluar sesi TDE_IMPORT, login SYS ke PDB1:

```bash
sqlplus sys/oracle@localhost:1521/pdb1.localdomain as sysdba
```

```sql
@/home/oracle/day2_lab/format.sql
SELECT owner,table_name,column_name,encryption_alg,salt
FROM dba_encrypted_columns WHERE owner='TDE_IMPORT';
```

Hasil aktual:

```text
OWNER       TABLE_NAME       COLUMN_NAME  ENCRYPTION_ALG       SALT
TDE_IMPORT  CUSTOMER_SECURE  CREDIT_CARD  AES 256 bits key     YES
```

Jadi column encryption dipertahankan oleh export/import yang diuji ini.

---

# LAB 51 — Check TDE Key History

Lihat history seluruh container sebagai SYS, bukan hanya PDB saat ini.

```sql
ALTER SESSION SET CONTAINER=CDB$ROOT;
SELECT
    CON_ID,
    KEY_ID,
    CREATION_TIME,
    ACTIVATION_TIME,
    TAG
FROM V$ENCRYPTION_KEYS
ORDER BY CON_ID, CREATION_TIME;
```

Expected konsep:

```text
CON_ID KEY_ID      CREATION_TIME       TAG
------ ----------- ------------------  -------------------
1      ...         ...                DAY2_INITIAL_KEY
3      ...         ...                DAY2_INITIAL_KEY
3      ...         ...                DAY2_KEY_ROTATION
```

---

# LAB 52 — Check Encryption Algorithm

```sql
ALTER SESSION SET CONTAINER=PDB1;
SELECT
    OWNER,
    TABLE_NAME,
    COLUMN_NAME,
    ENCRYPTION_ALG,
    SALT
FROM DBA_ENCRYPTED_COLUMNS
WHERE OWNER IN ('TDE_OWNER','TDE_IMPORT')
ORDER BY OWNER, TABLE_NAME;
```

Expected:

```text
OWNER       TABLE_NAME       COLUMN_NAME  ENCRYPTION_ALG
----------- ---------------  ------------ --------------
TDE_IMPORT  CUSTOMER_SECURE  CREDIT_CARD  AES 256 bits key
TDE_OWNER   CUSTOMER_SECURE  CREDIT_CARD  AES 256 bits key
```

---

# LAB 53 — Test Application Behavior

Sekarang kita buktikan bahwa aplikasi tidak perlu mengubah SQL.

Login:

```bash
sqlplus tde_owner/"TDEOwner#2026"@localhost:1521/pdb1.localdomain
```

Query:

```sql
SELECT
    customer_id,
    customer_name,
    credit_card
FROM customer_secure
WHERE customer_id=1;
```

Expected:

```text
CUSTOMER_ID CUSTOMER_NAME CREDIT_CARD
----------- ------------- ----------------
1           JOHN DOE      4111111111111111
```

Insert data baru:

```sql
INSERT INTO customer_secure
VALUES (
    4,
    'BOB',
    '6011111111111117',
    12000000,
    SYSDATE
);

COMMIT;
```

Expected:

```text
1 row created.

Commit complete.
```

Query:

```sql
SELECT customer_id,customer_name,credit_card,salary,
       TO_CHAR(created_date,'YYYY-MM-DD HH24:MI:SS') AS created_date
FROM customer_secure
WHERE customer_id=4;
```

Expected:

```text
CUSTOMER_ID CUSTOMER_NAME CREDIT_CARD       SALARY         CREATED_DATE
----------- ------------- ----------------- -------------- -------------------
4           BOB           6011111111111117  12,000,000.00  <waktu insert>
```

### Point pembelajaran

Application SQL:

```sql
INSERT
SELECT
UPDATE
```

tidak perlu mengetahui mekanisme TDE.

---

# LAB 54 — Verify Non-Encrypted Table

Bandingkan dengan table biasa.

```sql
CREATE TABLE normal_data (
    id NUMBER,
    description VARCHAR2(100)
) TABLESPACE users;
```

Insert:

```sql
INSERT INTO normal_data
VALUES (1,'NON ENCRYPTED DATA');

COMMIT;
```

Check:

```sql
SELECT table_name,column_name,encryption_alg
FROM user_encrypted_columns
WHERE table_name='NORMAL_DATA';
```

Expected:

```text
no rows selected
```

Bandingkan:

```text
CUSTOMER_SECURE
      |
      +-- CREDIT_CARD --> AES256

NORMAL_DATA
      |
      +-- DESCRIPTION --> plaintext storage
```

---

# LAB 55 — Security Verification

Kembali menjadi SYS di PDB1:

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA
@/home/oracle/day2_lab/format.sql
```

## Check all encrypted tablespaces

```sql
SELECT
    tablespace_name,
    encrypted
FROM dba_tablespaces
WHERE encrypted='YES';
```

Expected:

```text
TABLESPACE_NAME  ENCRYPTED
---------------- ---------
TS_SECURE        YES
```

## Check all encrypted columns

```sql
SELECT
    owner,
    table_name,
    column_name,
    encryption_alg,
    salt
FROM dba_encrypted_columns
ORDER BY owner, table_name, column_name;
```

## Check wallet seluruh container

```sql
ALTER SESSION SET CONTAINER=CDB$ROOT;
SELECT
    con_id,
    status,
    wallet_type,
    wallet_order
FROM v$encryption_wallet
ORDER BY con_id;
```

Expected:

```text
CON_ID STATUS WALLET_TYPE
------ ------ -----------
1      OPEN   PASSWORD
3      OPEN   PASSWORD
```

---

# LAB 56 — Security Architecture

Pada akhir lab, peserta harus bisa menggambarkan architecture seperti ini:

```text
                 +----------------------+
                 |    Oracle Database   |
                 |       ORADB/PDB1     |
                 +----------+-----------+
                            |
                  +---------+---------+
                  |                   |
                  v                   v
          +---------------+   +---------------+
          | Column TDE    |   | Tablespace TDE|
          | AES256        |   | AES256        |
          +-------+-------+   +-------+-------+
                  |                   |
                  +---------+---------+
                            |
                            v
                    +---------------+
                    | TDE Master Key|
                    +-------+-------+
                            |
                            v
                    +---------------+
                    |   Keystore    |
                    |  ewallet.p12  |
                    +---------------+
                            |
                            v
                    +---------------+
                    | RMAN Backup   |
                    | Encryption    |
                    +---------------+
```

---

# LAB 57 — Data Terenkripsi Tidak Bisa Diakses, Lalu Dipulihkan

Prasyarat: password wallet lab, tanpa cwallet.sso; data Lab 18–19 masih ada.
Skenario menutup wallet PDB1 sementara sehingga akses TDE di PDB ini terhenti.
Gunakan tabel column TDE sebagai pembuktian yang telah diuji; jangan menghapus
file wallet atau key.

Sebagai SYS di SQL*Plus:

```sql
ALTER SESSION SET CONTAINER=PDB1;
SELECT customer_id,credit_card FROM tde_owner.customer_secure ORDER BY customer_id;
ADMINISTER KEY MANAGEMENT SET KEYSTORE CLOSE
IDENTIFIED BY "TDEWallet#2026" CONTAINER=CURRENT;
SELECT status,wallet_type FROM v$encryption_wallet;
```

Hasil: CLOSED / UNKNOWN. Login sebagai aplikasi:

```sql
CONNECT tde_owner/"TDEOwner#2026"@localhost:1521/pdb1.localdomain
@/home/oracle/day2_lab/format.sql
WHENEVER SQLERROR CONTINUE
SELECT customer_id,credit_card FROM customer_secure ORDER BY customer_id;
```

Hasil aktual:

```text
ORA-28365: wallet is not open
```

Bandingkan dengan kolom yang tidak terenkripsi pada tabel yang sama:

```sql
SELECT customer_id,customer_name FROM customer_secure ORDER BY customer_id;
```

Nama customer tetap terbaca. Pulihkan segera dengan wallet dan key yang sama:

```sql
CONNECT / AS SYSDBA
@/home/oracle/day2_lab/format.sql
ALTER SESSION SET CONTAINER=PDB1;
ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN
IDENTIFIED BY "TDEWallet#2026" CONTAINER=CURRENT;
SELECT status,wallet_type FROM v$encryption_wallet;
CONNECT tde_owner/"TDEOwner#2026"@localhost:1521/pdb1.localdomain
@/home/oracle/day2_lab/format.sql
SELECT customer_id,credit_card FROM customer_secure ORDER BY customer_id;
```

Hasil: OPEN / PASSWORD; kartu kredit kembali terbaca tanpa mengubah data
atau SQL aplikasi. Pada pengujian khusus skenario ini ada 3 row; jika mengikuti
urutan dokumen sampai Lab 53, hasilnya 4 row termasuk BOB.
Jika sesi terputus setelah CLOSE, login lokal SYS dan lakukan langkah OPEN
di atas sebelum melanjutkan.

---

# LAB 58 — Troubleshooting: Master Key Belum Dibuat vs Key Hilang

Sebagai SYS:

```sql
CONNECT / AS SYSDBA
@/home/oracle/day2_lab/format.sql
ALTER SESSION SET CONTAINER=PDB1;
@/home/oracle/day2_lab/format.sql
SELECT con_id,key_id,creation_time,activation_time FROM v$encryption_keys;
SELECT status,wallet_type FROM v$encryption_wallet;
```

Keystore baru dengan OPEN_NO_MASTER_KEY memerlukan inisialisasi key, seperti
yang sudah diuji di Lab 11–14. Jangan menjalankan SET KEY lagi hanya karena
query data encrypted gagal.

Jika **key lama hilang**, membuat master key baru tidak dapat mendekripsi data
yang bergantung pada key lama. Pulihkan keystore backup yang berisi key yang
benar sesuai prosedur recovery, kemudian buka keystore tersebut. Simulasi
penghapusan atau kehilangan wallet tidak dijalankan dalam lab ini.

---

# LAB 59 — Troubleshooting: Tablespace Tidak Bisa Dibuat

Check:

```sql
SELECT
    status,
    wallet_type
FROM v$encryption_wallet;
```

Kemudian:

```sql
SELECT
    con_id,
    key_id,
    creation_time
FROM v$encryption_keys
ORDER BY con_id;
```

Pastikan:

```text
wallet = OPEN
master key = available
PDB = READ WRITE
```

Check:

```sql
SELECT
    name,
    open_mode
FROM v$pdbs
WHERE name='PDB1';
```

Expected:

```text
NAME  OPEN_MODE
----- ----------
PDB1  READ WRITE
```

---

# LAB 60 — Cleanup — Jalankan Setelah Final Practical Test

Lewati bagian ini hingga ujian praktik di bawah selesai. Perintah berikut
menghapus data latihan; jalankan sebagai SYS di PDB1:

```sql
CONNECT / AS SYSDBA
@/home/oracle/day2_lab/format.sql
ALTER SESSION SET CONTAINER=PDB1;
DROP USER tde_import CASCADE;
DROP USER tde_owner CASCADE;
DROP TABLESPACE ts_exam_secure INCLUDING CONTENTS AND DATAFILES;
DROP TABLESPACE ts_secure INCLUDING CONTENTS AND DATAFILES;
DROP DIRECTORY day2_dump;
```

Hasil yang diharapkan: dua User dropped, dua Tablespace dropped,
Directory dropped. Jika ujian belum dijalankan, TS_EXAM_SECURE belum ada;
jangan jalankan DROP untuk objek tersebut.
Simpan wallet dan backup RMAN/Data Pump. Cleanup objek tidak memulihkan
mode ARCHIVELOG atau konfigurasi RMAN secara otomatis.

---

# ⚠️ Jangan lakukan ini

Jangan menghapus wallet menggunakan:

```bash
rm -rf /u01/app/oracle/admin/oradb/wallet/*
```

Jangan menghapus:

```text
ewallet.p12
```

secara manual.

Jangan melakukan:

```sql
DROP TABLESPACE SYSTEM;
```

atau mencoba encrypt SYSTEM/SYSAUX untuk kebutuhan lab.

Jangan mengubah existing `USERS` tablespace hanya untuk demo.

Dan **jangan menghapus master key** hanya untuk mencoba-coba.

---

# DAY 2 — Final Practical Test

Jalankan sebelum cleanup Lab 60. Mulai sebagai SYS di PDB1:

```sql
CONNECT / AS SYSDBA
@/home/oracle/day2_lab/format.sql
ALTER SESSION SET CONTAINER=PDB1;
@/home/oracle/day2_lab/format.sql
```

Di akhir Day 2, peserta diberikan scenario:

> "Perusahaan memiliki tabel customer yang berisi data kartu kredit. Data harus terlindungi ketika tersimpan di database. Database juga harus mempunyai backup yang encrypted."

Peserta diminta melakukan dari awal:

### Task 1

Check wallet:

```sql
SELECT
    STATUS,
    WALLET_TYPE
FROM V$ENCRYPTION_WALLET;
```

### Task 2

Create encrypted tablespace:

```sql
CREATE TABLESPACE ts_exam_secure
DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/ts_exam_secure01.dbf'
SIZE 100M
AUTOEXTEND ON
NEXT 10M
MAXSIZE 500M
ENCRYPTION USING 'AES256'
DEFAULT STORAGE (ENCRYPT);
```

### Task 3

Berikan quota, lalu buat tabel sebagai owner:

```sql
ALTER USER tde_owner QUOTA 100M ON ts_exam_secure;
CONNECT tde_owner/"TDEOwner#2026"@localhost:1521/pdb1.localdomain
@/home/oracle/day2_lab/format.sql
```

Create table:

```sql
CREATE TABLE tde_owner.exam_customer (
    customer_id NUMBER PRIMARY KEY,
    customer_name VARCHAR2(100),
    credit_card VARCHAR2(32)
)
TABLESPACE ts_exam_secure;
```

### Task 4

Insert:

```sql
INSERT INTO tde_owner.exam_customer
VALUES (1,'CUSTOMER ONE','4111111111111111');

COMMIT;
```

### Task 5

Verify:

```sql
SELECT * FROM tde_owner.exam_customer;
CONNECT / AS SYSDBA
@/home/oracle/day2_lab/format.sql
ALTER SESSION SET CONTAINER=PDB1;
@/home/oracle/day2_lab/format.sql
SELECT
    tablespace_name,
    encrypted
FROM dba_tablespaces
WHERE tablespace_name='TS_EXAM_SECURE';
```

Expected:

```text
TABLESPACE_NAME  ENCRYPTED
---------------- ---------
TS_EXAM_SECURE   YES
```

### Task 6

Perlihatkan backup piece DAY2_TRANSPARENT / DAY2_PASSWORD dengan ENCRYPTED=YES
melalui query Lab 40, serta tunjukkan akses gagal dan pulih pada Lab 57.
Setelah semua selesai, jalankan cleanup Lab 60.

Peserta dianggap **lulus Day 2** apabila dapat menjelaskan dan mendemonstrasikan:

```text
                 AUTHENTICATION
                       |
                 [Day 1]
                       |
                       v
                  USER/ROLE
                       |
                       v
              +----------------+
              | Oracle Database|
              +-------+--------+
                      |
                      v
              +---------------+
              |      TDE      |
              +-------+-------+
                      |
             +--------+--------+
             |                 |
             v                 v
       Column Encryption  Tablespace
             |             Encryption
             +--------+--------+
                      |
                      v
                Master Key
                      |
                      v
                  Keystore
                      |
                      v
                RMAN Backup
                  Encryption
```


---



<!-- ============================================================ -->
<!-- SOURCE: preventive_day2b.md -->
<!-- ============================================================ -->

<a id="day-2b-extended"></a>

# DAY 2B — Data Pump, RMAN, dan TDE (Extended Lab)

> **Sumber file:** `preventive_day2b.md`

# Data Pump, RMAN, dan TDE: kunci mana yang kita perlukan?

Mari kita bedah tiga jenis enkripsi yang sering terlihat mirip, padahal tugasnya berbeda. Kita akan mencoba akses yang berhasil, sengaja membuatnya gagal, lalu memperbaikinya. Jadi peserta bisa melihat sendiri kapan perlu password Data Pump, password RMAN, atau TDE master key.

Naskah ini disesuaikan dengan pengujian langsung pada VM `192.168.56.22` dan `192.168.56.23`, tanggal 8 September 2026. Output di bawah adalah cuplikan hasil uji; banner, waktu, durasi, ukuran spasi, nomor sesi, nama piece, dan ID key dapat berbeda. Error yang sengaja dibuat diberi penjelasan. Command tetap dijalankan satu per satu, bukan sebagai satu script otomatis.

# 1. Environment dan alur lab

| Komponen | SOURCE | TARGET |
|---|---|---|
| IP | 192.168.56.22 | 192.168.56.23 |
| User SSH / password | oracle / oracle | oracle / oracle |
| Hostname aktual | srv1.localdomain | srv1.localdomain |
| Oracle | 19.8 Enterprise Edition | 19.8 Enterprise Edition |
| CDB / SID | ORADB / oradb | ORADB / oradb |
| PDB / network service | PDB1 / pdb1.localdomain | PDB1 / pdb1.localdomain |
| Log mode | NOARCHIVELOG | NOARCHIVELOG |
| DBID saat uji | 2803372975 | 2803372975 |
| Schema lab | LAB2B_SRC | LAB2B_DST |

Kedua VM merupakan clone dengan hostname dan DBID yang sama. Bedakan terminal berdasarkan IP. Kesamaan DBID memungkinkan katalog backup sumber pada controlfile target dalam lab ini; jangan menganggap langkah tersebut berlaku untuk database lain yang memiliki DBID berbeda.

```text
ORACLE_BASE  /u01/app/oracle
ORACLE_HOME  /u01/app/oracle/product/19.0.0/db_1
Wallet       /u01/app/oracle/admin/oradb/wallet
Dump         /u01/app/oracle/admin/oradb/day2b/dpump
Backup RMAN  /u01/app/oracle/admin/oradb/day2b/rman
Export key   /u01/app/oracle/admin/oradb/day2b/key_export

Wallet source       TDEWallet#2026
Wallet target       TargetWallet#2026
User database lab   Lab2b#2026
Data Pump           DataPump#2026
RMAN                RMANBackup#2026
Secret export key   KeyTransport#2026
```

Password di atas khusus VM training. Pada awal uji, source sudah memiliki wallet PASSWORD yang OPEN dengan key root dan PDB1. Target belum memiliki wallet. Tabel lama `TDE_OWNER.CUSTOMER_SECURE` ada tetapi tidak memiliki kolom TDE; karena itu kita memakai schema tersendiri agar hasil lab tidak bergantung pada latihan sebelumnya.

Urutannya penting: siapkan objek → uji Data Pump tanpa key sumber → uji RMAN tanpa key sumber → baru import key sumber. Setelah key diimpor, kegagalan “master key not found” memang tidak bisa diulang pada target yang sama. Gunakan snapshot awal VM untuk mengulang keseluruhan latihan, karena CREATE USER dan CREATE TABLE di sini adalah langkah sekali jalan. VM hasil pengujian sudah berisi objek dan key lab.

# 2. Gambaran besarnya terlebih dahulu

```text
TDE        → melindungi data di datafile → membutuhkan TDE master key
Data Pump  → melindungi dump .dmp       → PASSWORD / TRANSPARENT / DUAL
RMAN       → melindungi backup piece   → PASSWORD / TRANSPARENT / DUAL
```

Password wallet membuka keystore yang menyimpan key. Password Data Pump membuka dump. Password RMAN membuka lapisan enkripsi backup. Ketiganya tidak saling menggantikan. Bayangkan datafile sebagai lemari, dump sebagai paket kiriman, dan backup RMAN sebagai salinan fisik: masing-masing dapat memiliki kuncinya sendiri.

| Pertanyaan | Jawaban |
|---|---|
| PASSWORD dump dipindah ke mesin lain, perlu source wallet? | Tidak untuk membuka dump. Jika hasil import tetap memakai TDE, target perlu wallet dan key target yang tersedia. |
| TRANSPARENT dump atau backup perlu apa? | Key sumber yang digunakan untuk melindunginya. Wallet target yang sekadar OPEN belum cukup. |
| RMAN PASSWORD ONLY cukup dengan password? | Cukup untuk lapisan backup; data TDE di dalam datafile tetap bergantung pada key asal. |
| Wallet baru dengan password sama cukup? | Tidak. Password yang sama tidak membuat master key yang sama. |
| Perlu REGISTER WALLET? | Tidak ada langkah REGISTER WALLET dalam alur ini. Oracle harus menemukan keystore yang benar dan key yang diperlukan. |

# 3. Persiapan terminal dan SQL*Plus — kedua VM

Buka terminal SOURCE, lalu masukkan password SSH `oracle`:

```bash
ssh oracle@192.168.56.22
```

Contoh output:

```text
oracle@192.168.56.22's password:
```

Di terminal terpisah, buka TARGET dan masukkan password `oracle`:

```bash
ssh oracle@192.168.56.23
```

Contoh output:

```text
oracle@192.168.56.23's password:
```

Di masing-masing terminal, muat environment Oracle:

```bash
source ~/.bash_profile
```

Contoh output:

```text
Tidak ada output.
```

Jalankan di terminal Linux:

```bash
printf "%s\n" "$ORACLE_BASE" "$ORACLE_HOME" "$ORACLE_SID"
```

Contoh output (bagian penting):

```text
/u01/app/oracle
/u01/app/oracle/product/19.0.0/db_1
oradb
```

Jangan melewatkan ORACLE_BASE. Saat variabel itu tidak dimuat, sesi pengujian mencari wallet di bawah ORACLE_HOME/admin/oradb/wallet dan operasi keystore gagal. Dengan environment yang benar, lokasi wallet kembali sesuai naskah.

Jalankan di terminal Linux:

```bash
lsnrctl status
```

Contoh output (bagian penting):

```text
Service "pdb1.localdomain" has 1 instance(s).
  Instance "oradb", status READY, has 1 handler(s) for this service...
The command completed successfully
```

Gunakan nama network service di atas untuk expdp/impdp. Percobaan memakai `/pdb1` pada VM ini menghasilkan ORA-12514.

Jalankan di terminal Linux:

```bash
sqlplus / as sysdba
```

Contoh output (bagian penting):

```text
Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
```

Rapikan tampilan setiap kali membuka sesi SQL*Plus baru. Pengaturan tampilan ini boleh ditempel bersama:

```sql
SET LINESIZE 180
SET PAGESIZE 100
SET TAB OFF
SET TRIMSPOOL ON
SET FEEDBACK ON
SET VERIFY OFF
COLUMN owner FORMAT A12
COLUMN table_name FORMAT A22
COLUMN column_name FORMAT A15
COLUMN encryption_alg FORMAT A20
COLUMN customer_name FORMAT A20
COLUMN credit_card FORMAT A19
COLUMN status FORMAT A20
COLUMN wallet_type FORMAT A12
COLUMN wrl_parameter FORMAT A65
COLUMN key_id FORMAT A55
COLUMN tag FORMAT A25
```

Contoh output:

```text
Tidak ada output; format berlaku untuk sesi SQL*Plus ini.
```

Jalankan di SQL*Plus:

```sql
SELECT name, open_mode, log_mode, dbid FROM v$database;
```

Contoh output (bagian penting):

```text
NAME      OPEN_MODE            LOG_MODE           DBID
--------- -------------------- ------------ ----------
ORADB     READ WRITE           NOARCHIVELOG 2803372975
```

Jalankan di SQL*Plus:

```sql
SHOW PDBS
```

Contoh output (bagian penting):

```text
CON_ID CON_NAME                       OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
         2 PDB$SEED                       READ ONLY  NO
         3 PDB1                           READ WRITE NO
```

Cek wallet. Contoh berikut adalah SOURCE pada awal lab; TARGET awalnya NOT_AVAILABLE:

```sql
SELECT con_id, status, wallet_type, wrl_parameter
FROM v$encryption_wallet ORDER BY con_id;
```

Contoh output (bagian penting):

```text
CON_ID STATUS               WALLET_TYPE  WRL_PARAMETER
------ -------------------- ------------ -------------------------------------------------
     1 OPEN                 PASSWORD     /u01/app/oracle/admin/oradb/wallet
     2 OPEN                 PASSWORD
     3 OPEN                 PASSWORD
```

Jalankan di SQL*Plus:

```sql
EXIT
```

Contoh output:

```text
Disconnected from Oracle Database 19c Enterprise Edition
```

Buat folder kerja di SOURCE dan TARGET:

```bash
mkdir -p /u01/app/oracle/admin/oradb/day2b/{dpump,rman,key_export}
```

Contoh output:

```text
Tidak ada output.
```

Jalankan di terminal Linux:

```bash
chmod 700 /u01/app/oracle/admin/oradb/day2b /u01/app/oracle/admin/oradb/day2b/dpump /u01/app/oracle/admin/oradb/day2b/rman /u01/app/oracle/admin/oradb/day2b/key_export
```

Contoh output:

```text
Tidak ada output.
```

# 4. SOURCE — siapkan data contoh yang benar-benar TDE

Jalankan di terminal Linux:

```bash
sqlplus / as sysdba
```

Contoh output (bagian penting):

```text
Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
```

Jalankan di SQL*Plus:

```sql
ADMINISTER KEY MANAGEMENT BACKUP KEYSTORE
USING 'BEFORE_DAY2B_TEST' IDENTIFIED BY "TDEWallet#2026";
```

Contoh output:

```text
keystore altered.
```

Jalankan di SQL*Plus:

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

Contoh output:

```text
Session altered.
```

Jalankan di SQL*Plus:

```sql
CREATE TABLESPACE DAY2B_DATA
DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/day2b_data01.dbf' SIZE 10M;
```

Contoh output:

```text
Tablespace created.
```

Jalankan di SQL*Plus:

```sql
CREATE USER LAB2B_SRC IDENTIFIED BY "Lab2b#2026"
DEFAULT TABLESPACE DAY2B_DATA QUOTA 5M ON DAY2B_DATA;
```

Contoh output:

```text
User created.
```

Jalankan di SQL*Plus:

```sql
GRANT CREATE SESSION, CREATE TABLE TO LAB2B_SRC;
```

Contoh output:

```text
Grant succeeded.
```

Jalankan di SQL*Plus:

```sql
CREATE DIRECTORY DAY2B_DUMP AS '/u01/app/oracle/admin/oradb/day2b/dpump';
```

Contoh output:

```text
Directory created.
```

Jalankan di SQL*Plus:

```sql
GRANT READ, WRITE ON DIRECTORY DAY2B_DUMP TO LAB2B_SRC;
```

Contoh output:

```text
Grant succeeded.
```

Jalankan di SQL*Plus:

```sql
CREATE TABLE LAB2B_SRC.CUSTOMER_SECURE (
  customer_id NUMBER,
  customer_name VARCHAR2(20),
  credit_card VARCHAR2(19) ENCRYPT USING 'AES256'
) TABLESPACE DAY2B_DATA;
```

Contoh output:

```text
Table created.
```

Jalankan di SQL*Plus:

```sql
INSERT INTO LAB2B_SRC.CUSTOMER_SECURE VALUES (1,'Andi','4111-1111-1111-1111');
```

Contoh output:

```text
1 row created.
```

Jalankan di SQL*Plus:

```sql
INSERT INTO LAB2B_SRC.CUSTOMER_SECURE VALUES (2,'Sari','5555-5555-5555-4444');
```

Contoh output:

```text
1 row created.
```

Jalankan di SQL*Plus:

```sql
CREATE TABLE LAB2B_SRC.CUSTOMER_PLAIN TABLESPACE DAY2B_DATA
AS SELECT * FROM LAB2B_SRC.CUSTOMER_SECURE;
```

Contoh output:

```text
Table created.
```

Jalankan di SQL*Plus:

```sql
COMMIT;
```

Contoh output:

```text
Commit complete.
```

Rapikan tampilan setiap kali membuka sesi SQL*Plus baru. Pengaturan tampilan ini boleh ditempel bersama:

```sql
SET LINESIZE 180
SET PAGESIZE 100
SET TAB OFF
SET TRIMSPOOL ON
SET FEEDBACK ON
SET VERIFY OFF
COLUMN owner FORMAT A12
COLUMN table_name FORMAT A22
COLUMN column_name FORMAT A15
COLUMN encryption_alg FORMAT A20
COLUMN customer_name FORMAT A20
COLUMN credit_card FORMAT A19
COLUMN status FORMAT A20
COLUMN wallet_type FORMAT A12
COLUMN wrl_parameter FORMAT A65
COLUMN key_id FORMAT A55
COLUMN tag FORMAT A25
```

Contoh output:

```text
Tidak ada output; format berlaku untuk sesi SQL*Plus ini.
```

Jalankan di SQL*Plus:

```sql
SELECT owner, table_name, column_name, encryption_alg
FROM dba_encrypted_columns WHERE owner='LAB2B_SRC';
```

Contoh output (bagian penting):

```text
OWNER        TABLE_NAME             COLUMN_NAME     ENCRYPTION_ALG
------------ ---------------------- --------------- --------------------
LAB2B_SRC    CUSTOMER_SECURE        CREDIT_CARD     AES 256 bits key

1 row selected.
```

CUSTOMER_PLAIN dibuat tanpa atribut ENCRYPT. CTAS di atas menyalin nilai yang bisa dibaca sesi, sehingga atribut enkripsi kolom tidak ikut. Inilah pembanding kita untuk memisahkan enkripsi dump dari TDE.

Jalankan di SQL*Plus:

```sql
EXIT
```

Contoh output:

```text
Disconnected from Oracle Database 19c Enterprise Edition
```

# 5. TARGET — wallet dan schema sendiri

Bagian CREATE KEYSTORE ini hanya untuk target awal yang belum memiliki wallet. Pada VM hasil pengujian, wallet sudah ada; jangan membuat ulang atau menimpa ewallet.p12. Pada target yang sudah siap, cukup periksa status OPEN dan key-nya.

Jalankan di terminal Linux:

```bash
mkdir -p /u01/app/oracle/admin/oradb/wallet
```

Contoh output:

```text
Tidak ada output.
```

Jalankan di terminal Linux:

```bash
chmod 700 /u01/app/oracle/admin/oradb/wallet
```

Contoh output:

```text
Tidak ada output.
```

Jalankan di terminal Linux:

```bash
sqlplus / as sysdba
```

Contoh output (bagian penting):

```text
Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
```

Jalankan di SQL*Plus:

```sql
ADMINISTER KEY MANAGEMENT CREATE KEYSTORE
'/u01/app/oracle/admin/oradb/wallet' IDENTIFIED BY "TargetWallet#2026";
```

Contoh output:

```text
keystore altered.
```

Jalankan di SQL*Plus:

```sql
ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN
IDENTIFIED BY "TargetWallet#2026" CONTAINER=ALL;
```

Contoh output:

```text
keystore altered.
```

Jalankan di SQL*Plus:

```sql
ADMINISTER KEY MANAGEMENT SET KEY USING TAG 'DAY2B_TARGET_INITIAL'
IDENTIFIED BY "TargetWallet#2026"
WITH BACKUP USING 'DAY2B_TARGET_INITIAL' CONTAINER=ALL;
```

Contoh output:

```text
keystore altered.
```

Rapikan tampilan setiap kali membuka sesi SQL*Plus baru. Pengaturan tampilan ini boleh ditempel bersama:

```sql
SET LINESIZE 180
SET PAGESIZE 100
SET TAB OFF
SET TRIMSPOOL ON
SET FEEDBACK ON
SET VERIFY OFF
COLUMN owner FORMAT A12
COLUMN table_name FORMAT A22
COLUMN column_name FORMAT A15
COLUMN encryption_alg FORMAT A20
COLUMN customer_name FORMAT A20
COLUMN credit_card FORMAT A19
COLUMN status FORMAT A20
COLUMN wallet_type FORMAT A12
COLUMN wrl_parameter FORMAT A65
COLUMN key_id FORMAT A55
COLUMN tag FORMAT A25
```

Contoh output:

```text
Tidak ada output; format berlaku untuk sesi SQL*Plus ini.
```

Jalankan di SQL*Plus:

```sql
SELECT con_id, status, wallet_type FROM v$encryption_wallet ORDER BY con_id;
```

Contoh output (bagian penting):

```text
CON_ID STATUS               WALLET_TYPE
---------- -------------------- ------------
         1 OPEN                 PASSWORD
         2 OPEN                 PASSWORD
         3 OPEN                 PASSWORD
```

Jalankan di SQL*Plus:

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

Contoh output:

```text
Session altered.
```

Jalankan di SQL*Plus:

```sql
CREATE USER LAB2B_DST IDENTIFIED BY "Lab2b#2026"
DEFAULT TABLESPACE USERS QUOTA 20M ON USERS;
```

Contoh output:

```text
User created.
```

Jalankan di SQL*Plus:

```sql
GRANT CREATE SESSION, CREATE TABLE TO LAB2B_DST;
```

Contoh output:

```text
Grant succeeded.
```

Jalankan di SQL*Plus:

```sql
CREATE DIRECTORY DAY2B_DUMP AS '/u01/app/oracle/admin/oradb/day2b/dpump';
```

Contoh output:

```text
Directory created.
```

Jalankan di SQL*Plus:

```sql
GRANT READ, WRITE ON DIRECTORY DAY2B_DUMP TO LAB2B_DST;
```

Contoh output:

```text
Grant succeeded.
```

Jalankan di SQL*Plus:

```sql
EXIT
```

Contoh output:

```text
Disconnected from Oracle Database 19c Enterprise Edition
```

# 6. SOURCE — export PASSWORD, TRANSPARENT, dan DUAL

Kita buat beberapa dump kecil. Setiap blok expdp adalah satu command; backslash hanya menyambung baris. Tunggu job selesai sebelum lanjut. Nama dump harus belum ada agar hasil uji sebelumnya tidak tertimpa.

## 6.1 Tabel TDE, dump PASSWORD

Jalankan di terminal Linux:

```bash
expdp 'LAB2B_SRC/Lab2b#2026@localhost:1521/pdb1.localdomain' \
DIRECTORY=DAY2B_DUMP \
DUMPFILE=password.dmp \
LOGFILE=password_exp.log \
TABLES=LAB2B_SRC.CUSTOMER_SECURE \
ENCRYPTION=ALL \
ENCRYPTION_MODE=PASSWORD \
ENCRYPTION_ALGORITHM=AES256 \
ENCRYPTION_PASSWORD=DataPump#2026
```

Contoh output (bagian penting):

```text
. . exported "LAB2B_SRC"."CUSTOMER_SECURE"               5.992 KB       2 rows
Job "LAB2B_SRC"."SYS_EXPORT_TABLE_01" successfully completed
```

## 6.2 Tabel biasa, dump tetap terenkripsi

Jalankan di terminal Linux:

```bash
expdp 'LAB2B_SRC/Lab2b#2026@localhost:1521/pdb1.localdomain' \
DIRECTORY=DAY2B_DUMP \
DUMPFILE=plain_password.dmp \
LOGFILE=plain_password_exp.log \
TABLES=LAB2B_SRC.CUSTOMER_PLAIN \
ENCRYPTION=ALL \
ENCRYPTION_MODE=PASSWORD \
ENCRYPTION_ALGORITHM=AES256 \
ENCRYPTION_PASSWORD=DataPump#2026
```

Contoh output (bagian penting):

```text
. . exported "LAB2B_SRC"."CUSTOMER_PLAIN"               5.992 KB       2 rows
Job "LAB2B_SRC"."SYS_EXPORT_TABLE_01" successfully completed
```

## 6.3 Dump TRANSPARENT

Jalankan di terminal Linux:

```bash
expdp 'LAB2B_SRC/Lab2b#2026@localhost:1521/pdb1.localdomain' \
DIRECTORY=DAY2B_DUMP \
DUMPFILE=transparent.dmp \
LOGFILE=transparent_exp.log \
TABLES=LAB2B_SRC.CUSTOMER_SECURE \
ENCRYPTION=ALL \
ENCRYPTION_MODE=TRANSPARENT \
ENCRYPTION_ALGORITHM=AES256
```

Contoh output (bagian penting):

```text
. . exported "LAB2B_SRC"."CUSTOMER_SECURE"               5.992 KB       2 rows
Job "LAB2B_SRC"."SYS_EXPORT_TABLE_01" successfully completed
```

## 6.4 Dump DUAL

Jalankan di terminal Linux:

```bash
expdp 'LAB2B_SRC/Lab2b#2026@localhost:1521/pdb1.localdomain' \
DIRECTORY=DAY2B_DUMP \
DUMPFILE=dual.dmp \
LOGFILE=dual_exp.log \
TABLES=LAB2B_SRC.CUSTOMER_SECURE \
ENCRYPTION=ALL \
ENCRYPTION_MODE=DUAL \
ENCRYPTION_ALGORITHM=AES256 \
ENCRYPTION_PASSWORD=DataPump#2026
```

Contoh output (bagian penting):

```text
. . exported "LAB2B_SRC"."CUSTOMER_SECURE"               5.992 KB       2 rows
Job "LAB2B_SRC"."SYS_EXPORT_TABLE_01" successfully completed
```

## 6.5 Buktikan TDE tidak otomatis mengamankan dump

Jalankan di terminal Linux:

```bash
expdp 'LAB2B_SRC/Lab2b#2026@localhost:1521/pdb1.localdomain' \
DIRECTORY=DAY2B_DUMP \
DUMPFILE=unencrypted.dmp \
LOGFILE=unencrypted_exp.log \
TABLES=LAB2B_SRC.CUSTOMER_SECURE \
ENCRYPTION=NONE
```

Contoh output (bagian penting):

```text
. . exported "LAB2B_SRC"."CUSTOMER_SECURE"               5.984 KB       2 rows
ORA-39173: Encrypted data has been stored unencrypted in dump file set.
Job "LAB2B_SRC"."SYS_EXPORT_TABLE_01" successfully completed
```

Perhatikan ORA-39173. Export selesai, tetapi Oracle memperingatkan bahwa data terenkripsi di tabel telah ditulis tanpa enkripsi ke dump. Jangan menyamakan “tabel TDE” dengan “dump pasti aman”. Dump ini hanya untuk demonstrasi.

# 7. SOURCE → TARGET — kirim dump, tanpa source wallet

Jalankan di terminal Linux:

```bash
scp /u01/app/oracle/admin/oradb/day2b/dpump/password.dmp /u01/app/oracle/admin/oradb/day2b/dpump/plain_password.dmp \
/u01/app/oracle/admin/oradb/day2b/dpump/transparent.dmp /u01/app/oracle/admin/oradb/day2b/dpump/dual.dmp \
oracle@192.168.56.23:/u01/app/oracle/admin/oradb/day2b/dpump/
```

Contoh output (bagian penting):

```text
oracle@192.168.56.23's password:
password.dmp          100% 176KB
plain_password.dmp    100% 176KB
transparent.dmp       100% 176KB
dual.dmp              100% 176KB
```

Masukkan password SSH oracle. Pada koneksi pertama, SSH dapat meminta konfirmasi host key. Source wallet belum disalin atau diimpor. Keystore target tetap milik target.

# 8. TARGET — PASSWORD: gagal dahulu, lalu berhasil

## 8.1 Tanpa password dump

Jalankan di terminal Linux:

```bash
impdp 'LAB2B_DST/Lab2b#2026@localhost:1521/pdb1.localdomain' \
DIRECTORY=DAY2B_DUMP \
DUMPFILE=password.dmp \
LOGFILE=no_password.log \
REMAP_SCHEMA=LAB2B_SRC:LAB2B_DST \
REMAP_TABLESPACE=DAY2B_DATA:USERS
```

Contoh output (bagian penting):

```text
ORA-39002: invalid operation
ORA-39174: Encryption password must be supplied.
```

## 8.2 Password dump salah

Jalankan di terminal Linux:

```bash
impdp 'LAB2B_DST/Lab2b#2026@localhost:1521/pdb1.localdomain' \
DIRECTORY=DAY2B_DUMP \
DUMPFILE=password.dmp \
LOGFILE=wrong_password.log \
REMAP_SCHEMA=LAB2B_SRC:LAB2B_DST \
REMAP_TABLESPACE=DAY2B_DATA:USERS \
ENCRYPTION_PASSWORD=Wrong#2026
```

Contoh output (bagian penting):

```text
ORA-39002: invalid operation
ORA-39176: Encryption password is incorrect.
```

## 8.3 Password benar

Jalankan di terminal Linux:

```bash
impdp 'LAB2B_DST/Lab2b#2026@localhost:1521/pdb1.localdomain' \
DIRECTORY=DAY2B_DUMP \
DUMPFILE=password.dmp \
LOGFILE=password_imp.log \
REMAP_SCHEMA=LAB2B_SRC:LAB2B_DST \
REMAP_TABLESPACE=DAY2B_DATA:USERS \
ENCRYPTION_PASSWORD=DataPump#2026
```

Contoh output (bagian penting):

```text
. . imported "LAB2B_DST"."CUSTOMER_SECURE"               5.992 KB       2 rows
Job "LAB2B_DST"."SYS_IMPORT_FULL_01" successfully completed
```

REMAP_SCHEMA memindahkan tabel ke schema lab target. REMAP_TABLESPACE mengarahkan penyimpanan dari DAY2B_DATA sumber ke USERS target. Tanpa langkah terakhir, target membutuhkan tablespace sumber yang belum ada.

Jalankan di terminal Linux:

```bash
sqlplus / as sysdba
```

Contoh output (bagian penting):

```text
Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
```

Jalankan di SQL*Plus:

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

Contoh output:

```text
Session altered.
```

Rapikan tampilan setiap kali membuka sesi SQL*Plus baru. Pengaturan tampilan ini boleh ditempel bersama:

```sql
SET LINESIZE 180
SET PAGESIZE 100
SET TAB OFF
SET TRIMSPOOL ON
SET FEEDBACK ON
SET VERIFY OFF
COLUMN owner FORMAT A12
COLUMN table_name FORMAT A22
COLUMN column_name FORMAT A15
COLUMN encryption_alg FORMAT A20
COLUMN customer_name FORMAT A20
COLUMN credit_card FORMAT A19
COLUMN status FORMAT A20
COLUMN wallet_type FORMAT A12
COLUMN wrl_parameter FORMAT A65
COLUMN key_id FORMAT A55
COLUMN tag FORMAT A25
```

Contoh output:

```text
Tidak ada output; format berlaku untuk sesi SQL*Plus ini.
```

Jalankan di SQL*Plus:

```sql
SELECT * FROM LAB2B_DST.CUSTOMER_SECURE ORDER BY customer_id;
```

Contoh output (bagian penting):

```text
CUSTOMER_ID CUSTOMER_NAME        CREDIT_CARD
----------- -------------------- -------------------
          1 Andi                 4111-1111-1111-1111
          2 Sari                 5555-5555-5555-4444

2 rows selected.
```

Jalankan di SQL*Plus:

```sql
SELECT owner, table_name, column_name, encryption_alg
FROM dba_encrypted_columns WHERE owner='LAB2B_DST'
AND table_name='CUSTOMER_SECURE';
```

Contoh output (bagian penting):

```text
OWNER        TABLE_NAME             COLUMN_NAME     ENCRYPTION_ALG
------------ ---------------------- --------------- --------------------
LAB2B_DST    CUSTOMER_SECURE        CREDIT_CARD     AES 256 bits key
```

Jalankan di SQL*Plus:

```sql
EXIT
```

Contoh output:

```text
Disconnected from Oracle Database 19c Enterprise Edition
```

Data sudah terbaca dan kolom target tetap TDE, walaupun source key belum dibawa. Data Pump melakukan migrasi logis: membuka dump dengan password, lalu membuat enkripsi kolom memakai key target.

# 9. TARGET — TRANSPARENT dan DUAL sebelum source key diimpor

Jalankan di terminal Linux:

```bash
impdp 'LAB2B_DST/Lab2b#2026@localhost:1521/pdb1.localdomain' \
DIRECTORY=DAY2B_DUMP \
DUMPFILE=transparent.dmp \
LOGFILE=transparent_missing_key.log \
REMAP_SCHEMA=LAB2B_SRC:LAB2B_DST \
REMAP_TABLESPACE=DAY2B_DATA:USERS \
REMAP_TABLE=CUSTOMER_SECURE:CUSTOMER_TRANS
```

Contoh output (bagian penting):

```text
ORA-39002: invalid operation
ORA-39189: unable to decrypt dump file set
ORA-28362: master key not found
```

Wallet target OPEN, tetapi key yang diperlukan dump TRANSPARENT adalah key sumber. Kita akan memperbaikinya pada bagian import key, setelah pengujian RMAN tanpa source key selesai.

Jalankan di terminal Linux:

```bash
impdp 'LAB2B_DST/Lab2b#2026@localhost:1521/pdb1.localdomain' \
DIRECTORY=DAY2B_DUMP \
DUMPFILE=dual.dmp \
LOGFILE=dual_password.log \
REMAP_SCHEMA=LAB2B_SRC:LAB2B_DST \
REMAP_TABLESPACE=DAY2B_DATA:USERS \
REMAP_TABLE=CUSTOMER_SECURE:CUSTOMER_DUAL \
ENCRYPTION_PASSWORD=DataPump#2026
```

Contoh output (bagian penting):

```text
. . imported "LAB2B_DST"."CUSTOMER_DUAL"               5.992 KB       2 rows
Job "LAB2B_DST"."SYS_IMPORT_FULL_01" successfully completed
```

DUAL berhasil melalui jalur password. Nanti kita ulangi menggunakan key saja, tanpa password Data Pump.

# 10. TARGET — data terenkripsi tidak bisa diakses, lalu dipulihkan

Latihan ini memakai password wallet, bukan auto-login wallet. Menutup keystore PDB memengaruhi akses TDE di PDB tersebut; lakukan berurutan dan buka kembali pada akhir latihan.

Jalankan di terminal Linux:

```bash
sqlplus / as sysdba
```

Contoh output (bagian penting):

```text
Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
```

Jalankan di SQL*Plus:

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

Contoh output:

```text
Session altered.
```

Rapikan tampilan setiap kali membuka sesi SQL*Plus baru. Pengaturan tampilan ini boleh ditempel bersama:

```sql
SET LINESIZE 180
SET PAGESIZE 100
SET TAB OFF
SET TRIMSPOOL ON
SET FEEDBACK ON
SET VERIFY OFF
COLUMN owner FORMAT A12
COLUMN table_name FORMAT A22
COLUMN column_name FORMAT A15
COLUMN encryption_alg FORMAT A20
COLUMN customer_name FORMAT A20
COLUMN credit_card FORMAT A19
COLUMN status FORMAT A20
COLUMN wallet_type FORMAT A12
COLUMN wrl_parameter FORMAT A65
COLUMN key_id FORMAT A55
COLUMN tag FORMAT A25
```

Contoh output:

```text
Tidak ada output; format berlaku untuk sesi SQL*Plus ini.
```

Jalankan di SQL*Plus:

```sql
SELECT * FROM LAB2B_DST.CUSTOMER_SECURE ORDER BY customer_id;
```

Contoh output (bagian penting):

```text
CUSTOMER_ID CUSTOMER_NAME        CREDIT_CARD
----------- -------------------- -------------------
          1 Andi                 4111-1111-1111-1111
          2 Sari                 5555-5555-5555-4444

2 rows selected.
```

Jalankan di SQL*Plus:

```sql
ADMINISTER KEY MANAGEMENT SET KEYSTORE CLOSE
IDENTIFIED BY "TargetWallet#2026";
```

Contoh output:

```text
keystore altered.
```

Jalankan di SQL*Plus:

```sql
SELECT * FROM LAB2B_DST.CUSTOMER_SECURE ORDER BY customer_id;
```

Contoh output (bagian penting):

```text
ERROR at line 1:
ORA-28365: wallet is not open
```

Tabel dan datanya masih ada. Yang hilang sementara adalah akses ke key untuk membuka kolom terenkripsi.

Sekarang pilih hanya kolom yang tidak terenkripsi:

```sql
SELECT customer_id, customer_name FROM LAB2B_DST.CUSTOMER_SECURE
ORDER BY customer_id;
```

Contoh output (bagian penting):

```text
CUSTOMER_ID CUSTOMER_NAME
----------- --------------------
          1 Andi
          2 Sari

2 rows selected.
```

Query ini tetap berhasil. Pada contoh column encryption di tablespace USERS yang tidak terenkripsi, kolom biasa masih bisa dibaca. Jangan menggeneralisasikan hasil ini ke TDE tablespace encryption, karena lapisan penyimpanannya berbeda.

Jalankan di SQL*Plus:

```sql
EXIT
```

Contoh output:

```text
Disconnected from Oracle Database 19c Enterprise Edition
```

## 10.1 Dump PASSWORD berisi tabel non-TDE tetap bisa diimpor

Jalankan di terminal Linux:

```bash
impdp 'LAB2B_DST/Lab2b#2026@localhost:1521/pdb1.localdomain' \
DIRECTORY=DAY2B_DUMP \
DUMPFILE=plain_password.dmp \
LOGFILE=plain_closed_wallet.log \
REMAP_SCHEMA=LAB2B_SRC:LAB2B_DST \
REMAP_TABLESPACE=DAY2B_DATA:USERS \
ENCRYPTION_PASSWORD=DataPump#2026
```

Contoh output (bagian penting):

```text
. . imported "LAB2B_DST"."CUSTOMER_PLAIN"               5.992 KB       2 rows
Job "LAB2B_DST"."SYS_IMPORT_FULL_01" successfully completed
```

Password dump cukup untuk contoh non-TDE ini karena USERS target tidak terenkripsi dan tabel tidak meminta kolom TDE.

## 10.2 Password dump benar, tetapi tabel TDE gagal dibuat

Jalankan di terminal Linux:

```bash
impdp 'LAB2B_DST/Lab2b#2026@localhost:1521/pdb1.localdomain' \
DIRECTORY=DAY2B_DUMP \
DUMPFILE=password.dmp \
LOGFILE=secure_closed_wallet.log \
REMAP_SCHEMA=LAB2B_SRC:LAB2B_DST \
REMAP_TABLESPACE=DAY2B_DATA:USERS \
REMAP_TABLE=CUSTOMER_SECURE:CUSTOMER_RETRY \
ENCRYPTION_PASSWORD=DataPump#2026
```

Contoh output (bagian penting):

```text
ORA-39083: Object type TABLE:"LAB2B_DST"."CUSTOMER_RETRY" failed to create with error:
ORA-28365: wallet is not open
Job "LAB2B_DST"."SYS_IMPORT_FULL_01" completed with 1 error(s)
```

Dump berhasil dibuka, tetapi target belum bisa membuat kolom TDE. Dua lapisan ini sekarang terlihat jelas.

## 10.3 Buka keystore dengan password yang benar

Jalankan di terminal Linux:

```bash
sqlplus / as sysdba
```

Contoh output (bagian penting):

```text
Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
```

Jalankan di SQL*Plus:

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

Contoh output:

```text
Session altered.
```

Jalankan di SQL*Plus:

```sql
ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN
IDENTIFIED BY "Wrong#2026";
```

Contoh output:

```text
ORA-46627: keystore password mismatch
```

Jalankan di SQL*Plus:

```sql
ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN
IDENTIFIED BY "TargetWallet#2026";
```

Contoh output:

```text
keystore altered.
```

Rapikan tampilan setiap kali membuka sesi SQL*Plus baru. Pengaturan tampilan ini boleh ditempel bersama:

```sql
SET LINESIZE 180
SET PAGESIZE 100
SET TAB OFF
SET TRIMSPOOL ON
SET FEEDBACK ON
SET VERIFY OFF
COLUMN owner FORMAT A12
COLUMN table_name FORMAT A22
COLUMN column_name FORMAT A15
COLUMN encryption_alg FORMAT A20
COLUMN customer_name FORMAT A20
COLUMN credit_card FORMAT A19
COLUMN status FORMAT A20
COLUMN wallet_type FORMAT A12
COLUMN wrl_parameter FORMAT A65
COLUMN key_id FORMAT A55
COLUMN tag FORMAT A25
```

Contoh output:

```text
Tidak ada output; format berlaku untuk sesi SQL*Plus ini.
```

Jalankan di SQL*Plus:

```sql
SELECT * FROM LAB2B_DST.CUSTOMER_SECURE ORDER BY customer_id;
```

Contoh output (bagian penting):

```text
CUSTOMER_ID CUSTOMER_NAME        CREDIT_CARD
----------- -------------------- -------------------
          1 Andi                 4111-1111-1111-1111
          2 Sari                 5555-5555-5555-4444

2 rows selected.
```

Jalankan di SQL*Plus:

```sql
EXIT
```

Contoh output:

```text
Disconnected from Oracle Database 19c Enterprise Edition
```

Jalankan di terminal Linux:

```bash
impdp 'LAB2B_DST/Lab2b#2026@localhost:1521/pdb1.localdomain' \
DIRECTORY=DAY2B_DUMP \
DUMPFILE=password.dmp \
LOGFILE=secure_reopened_wallet.log \
REMAP_SCHEMA=LAB2B_SRC:LAB2B_DST \
REMAP_TABLESPACE=DAY2B_DATA:USERS \
REMAP_TABLE=CUSTOMER_SECURE:CUSTOMER_RETRY \
ENCRYPTION_PASSWORD=DataPump#2026
```

Contoh output (bagian penting):

```text
. . imported "LAB2B_DST"."CUSTOMER_RETRY"               5.992 KB       2 rows
Job "LAB2B_DST"."SYS_IMPORT_FULL_01" successfully completed
```

Akses pulih tanpa menghapus data, mengganti password user, atau membuat key baru. Penyebabnya wallet tertutup, sehingga perbaikannya membuka wallet yang benar.

# 11. SOURCE — RMAN pada NOARCHIVELOG

Tujuan bagian ini adalah membuktikan dekripsi backup piece. Kita membackup satu datafile lab berukuran 10 MB, bukan seluruh database. Backup ini tidak cukup untuk full disaster recovery. Pada NOARCHIVELOG, backup dilakukan setelah shutdown bersih dengan database MOUNT. Database sumber tidak tersedia sementara sampai dibuka kembali.

Dalam uji awal, BACKUP TABLESPACE PDB1:DAY2B_DATA saat database OPEN tetap ditolak dengan RMAN-06817, termasuk ketika tablespace read-only. Karena itu alur kerja di bawah memakai cold backup. Perintah BACKUP DATABASE PLUS ARCHIVELOG dari naskah awal tidak dipakai pada VM ini.

Jalankan di terminal Linux:

```bash
sqlplus / as sysdba
```

Contoh output (bagian penting):

```text
Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
```

Jalankan di SQL*Plus:

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

Contoh output:

```text
Session altered.
```

Jalankan di SQL*Plus:

```sql
ALTER TABLESPACE DAY2B_DATA READ ONLY;
```

Contoh output:

```text
Tablespace altered.
```

Read-only menjaga contoh data lab tetap selama latihan; langkah ini sendiri tidak mengatasi batas NOARCHIVELOG. Tetap lakukan shutdown bersih berikut.

Jalankan di SQL*Plus:

```sql
ALTER SESSION SET CONTAINER=CDB$ROOT;
```

Contoh output:

```text
Session altered.
```

Jalankan di SQL*Plus:

```sql
SHUTDOWN IMMEDIATE;
```

Contoh output (bagian penting):

```text
Database closed.
Database dismounted.
ORACLE instance shut down.
```

Jalankan di SQL*Plus:

```sql
STARTUP MOUNT;
```

Contoh output (bagian penting):

```text
ORACLE instance started.
Total System Global Area 1073738888 bytes
Database mounted.
```

Jalankan di SQL*Plus:

```sql
ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN
IDENTIFIED BY "TDEWallet#2026";
```

Contoh output:

```text
keystore altered.
```

Jalankan di SQL*Plus:

```sql
EXIT
```

Contoh output:

```text
Disconnected from Oracle Database 19c Enterprise Edition
```

Jalankan di terminal Linux:

```bash
rman target /
```

Contoh output:

```text
connected to target database: ORADB (DBID=2803372975, not open)
```

Jalankan di prompt RMAN:

```rman
SET ENCRYPTION ALGORITHM 'AES256';
```

Contoh output:

```text
executing command: SET encryption
```

SET hanya berlaku di sesi RMAN ini. Kita tidak perlu mengubah konfigurasi enkripsi permanen database. Jalankan tiga backup berikut di sesi yang sama.

## 11.1 TRANSPARENT

Jalankan di prompt RMAN:

```rman
SET ENCRYPTION ON;
```

Contoh output:

```text
executing command: SET encryption
```

Jalankan di prompt RMAN:

```rman
BACKUP DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/day2b_data01.dbf'
FORMAT '/u01/app/oracle/admin/oradb/day2b/rman/trans_%U.bkp' TAG 'DAY2B_TRANS';
```

Contoh output (bagian penting):

```text
input datafile file number=00014 name=/u01/app/oracle/oradata/ORADB/pdb1/day2b_data01.dbf
piece handle=/u01/app/oracle/admin/oradb/day2b/rman/trans_0151qtu0_1_1.bkp tag=DAY2B_TRANS comment=NONE
channel ORA_DISK_1: backup set complete, elapsed time: 00:00:01
Finished backup
```

## 11.2 PASSWORD ONLY

Jalankan di prompt RMAN:

```rman
SET ENCRYPTION ON IDENTIFIED BY "RMANBackup#2026" ONLY;
```

Contoh output:

```text
executing command: SET encryption
```

Jalankan di prompt RMAN:

```rman
BACKUP DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/day2b_data01.dbf'
FORMAT '/u01/app/oracle/admin/oradb/day2b/rman/pass_%U.bkp' TAG 'DAY2B_PASS';
```

Contoh output (bagian penting):

```text
input datafile file number=00014 name=/u01/app/oracle/oradata/ORADB/pdb1/day2b_data01.dbf
piece handle=/u01/app/oracle/admin/oradb/day2b/rman/pass_0351qtu4_1_1.bkp tag=DAY2B_PASS comment=NONE
channel ORA_DISK_1: backup set complete, elapsed time: 00:00:01
Finished backup
```

## 11.3 DUAL

Jalankan di prompt RMAN:

```rman
SET ENCRYPTION ON IDENTIFIED BY "RMANBackup#2026";
```

Contoh output:

```text
executing command: SET encryption
```

Jalankan di prompt RMAN:

```rman
BACKUP DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/day2b_data01.dbf'
FORMAT '/u01/app/oracle/admin/oradb/day2b/rman/dual_%U.bkp' TAG 'DAY2B_DUAL';
```

Contoh output (bagian penting):

```text
input datafile file number=00014 name=/u01/app/oracle/oradata/ORADB/pdb1/day2b_data01.dbf
piece handle=/u01/app/oracle/admin/oradb/day2b/rman/dual_0551qtu7_1_1.bkp tag=DAY2B_DUAL comment=NONE
channel ORA_DISK_1: backup set complete, elapsed time: 00:00:01
Finished backup
```

ONLY membedakan PASSWORD dari DUAL. Pada VM ini RMAN juga membuat controlfile/SPFILE autobackup di FRA; cuplikan di atas menampilkan piece datafile yang kita uji. Nomor datafile 14 dan nama hasil %U adalah hasil run ini, bukan nilai yang harus sama di setiap VM.

Jalankan di prompt RMAN:

```rman
EXIT
```

Contoh output:

```text
Recovery Manager complete.
```

## 11.4 Buka kembali database dan wallet PDB1

Jalankan di terminal Linux:

```bash
sqlplus / as sysdba
```

Contoh output (bagian penting):

```text
Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
```

Jalankan di SQL*Plus:

```sql
ALTER DATABASE OPEN;
```

Contoh output:

```text
Database altered.
```

Jalankan di SQL*Plus:

```sql
SHOW PDBS
```

Contoh output (bagian penting):

```text
CON_ID CON_NAME                       OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
         2 PDB$SEED                       READ ONLY  NO
         3 PDB1                           READ WRITE NO
```

Pada VM ini PDB1 otomatis terbuka setelah ALTER DATABASE OPEN. Jangan menjalankan OPEN sekali lagi bila sudah READ WRITE; percobaan tersebut menghasilkan ORA-65019. Jika snapshot Anda menunjukkan MOUNTED, jalankan ALTER PLUGGABLE DATABASE PDB1 OPEN sebelum berpindah ke PDB1; jalur MOUNTED tersebut tidak terjadi pada pengujian ini.

Jalankan di SQL*Plus:

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

Contoh output:

```text
Session altered.
```

Rapikan tampilan setiap kali membuka sesi SQL*Plus baru. Pengaturan tampilan ini boleh ditempel bersama:

```sql
SET LINESIZE 180
SET PAGESIZE 100
SET TAB OFF
SET TRIMSPOOL ON
SET FEEDBACK ON
SET VERIFY OFF
COLUMN owner FORMAT A12
COLUMN table_name FORMAT A22
COLUMN column_name FORMAT A15
COLUMN encryption_alg FORMAT A20
COLUMN customer_name FORMAT A20
COLUMN credit_card FORMAT A19
COLUMN status FORMAT A20
COLUMN wallet_type FORMAT A12
COLUMN wrl_parameter FORMAT A65
COLUMN key_id FORMAT A55
COLUMN tag FORMAT A25
```

Contoh output:

```text
Tidak ada output; format berlaku untuk sesi SQL*Plus ini.
```

Jalankan di SQL*Plus:

```sql
SELECT con_id, status, wallet_type FROM v$encryption_wallet;
```

Contoh output (bagian penting):

```text
CON_ID STATUS               WALLET_TYPE
---------- -------------------- ------------
         3 CLOSED               UNKNOWN
```

Jalankan di SQL*Plus:

```sql
SELECT * FROM LAB2B_SRC.CUSTOMER_SECURE ORDER BY customer_id;
```

Contoh output (bagian penting):

```text
ERROR at line 1:
ORA-28365: wallet is not open
```

Jalankan di SQL*Plus:

```sql
ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN
IDENTIFIED BY "TDEWallet#2026";
```

Contoh output:

```text
keystore altered.
```

Jalankan di SQL*Plus:

```sql
SELECT * FROM LAB2B_SRC.CUSTOMER_SECURE ORDER BY customer_id;
```

Contoh output (bagian penting):

```text
CUSTOMER_ID CUSTOMER_NAME        CREDIT_CARD
----------- -------------------- -------------------
          1 Andi                 4111-1111-1111-1111
          2 Sari                 5555-5555-5555-4444

2 rows selected.
```

Jalankan di SQL*Plus:

```sql
ALTER TABLESPACE DAY2B_DATA READ WRITE;
```

Contoh output:

```text
Tablespace altered.
```

Database OPEN tidak berarti wallet PDB ikut OPEN. Membuka CONTAINER=ALL saat wallet root sudah OPEN menghasilkan ORA-28354 dalam pengujian; membuka wallet langsung dari PDB1 menyelesaikan masalahnya.

Jalankan di SQL*Plus:

```sql
ALTER SESSION SET CONTAINER=CDB$ROOT;
```

Contoh output:

```text
Session altered.
```

Jalankan di SQL*Plus:

```sql
SELECT p.tag, p.encrypted, s.recid AS bs_key
FROM v$backup_piece p JOIN v$backup_set s
ON p.set_stamp=s.set_stamp AND p.set_count=s.set_count
WHERE p.tag IN ('DAY2B_TRANS','DAY2B_PASS','DAY2B_DUAL')
ORDER BY s.recid;
```

Contoh output (bagian penting):

```text
TAG                       ENC     BS_KEY
------------------------- --- ----------
DAY2B_TRANS               YES          1
DAY2B_PASS                YES          3
DAY2B_DUAL                YES          5
```

ENCRYPTED=YES membuktikan piece terenkripsi, tetapi tidak membedakan PASSWORD, TRANSPARENT, dan DUAL. Kita membedakannya lewat SET saat pembuatan serta hasil pengujian akses.

Jalankan di SQL*Plus:

```sql
EXIT
```

Contoh output:

```text
Disconnected from Oracle Database 19c Enterprise Edition
```

# 12. SOURCE → TARGET — copy backup dan tentukan backup-set key

Jalankan di terminal Linux:

```bash
scp /u01/app/oracle/admin/oradb/day2b/rman/*.bkp \
oracle@192.168.56.23:/u01/app/oracle/admin/oradb/day2b/rman/
```

Contoh output (bagian penting):

```text
oracle@192.168.56.23's password:
trans_0151qtu0_1_1.bkp    100% 1496KB
pass_0351qtu4_1_1.bkp     100% 1496KB
dual_0551qtu7_1_1.bkp     100% 1496KB
```

Sekarang pindah ke terminal TARGET. Sampai bagian ini, source key belum diimpor. Jangan melompat ke bagian 14 dahulu.

Jalankan di terminal Linux:

```bash
rman target /
```

Contoh output:

```text
connected to target database: ORADB (DBID=2803372975)
```

Jalankan di prompt RMAN:

```rman
CATALOG START WITH '/u01/app/oracle/admin/oradb/day2b/rman/' NOPROMPT;
```

Contoh output (bagian penting):

```text
cataloging files...
cataloging done
List of Cataloged Files
/u01/app/oracle/admin/oradb/day2b/rman/trans_0151qtu0_1_1.bkp
/u01/app/oracle/admin/oradb/day2b/rman/pass_0351qtu4_1_1.bkp
/u01/app/oracle/admin/oradb/day2b/rman/dual_0551qtu7_1_1.bkp
```

Jalankan di prompt RMAN:

```rman
LIST BACKUP SUMMARY;
```

Contoh output (bagian penting):

```text
Key     TY LV S Device Type #Pieces #Copies Compressed Tag
------- -- -- - ----------- ------- ------- ---------- -----------
1       B  F  A DISK        1       1       NO         DAY2B_TRANS
2       B  F  A DISK        1       1       NO         DAY2B_PASS
3       B  F  A DISK        1       1       NO         DAY2B_DUAL
```

Kolom waktu dipendekkan pada contoh agar mudah dibaca. Key target adalah 1, 2, 3 pada run ini, berbeda dari source 1, 3, 5. Untuk command berikut, gunakan Key dari LIST di TARGET Anda sesuai tag. Angka tersebut bukan nomor backup piece. Folder katalog sengaja hanya berisi tiga backup lab.

# 13. TARGET — RMAN gagal tanpa kunci, pulih dengan password

Lanjutkan di sesi RMAN target tadi. VALIDATE BACKUPSET membaca backup set yang dipilih; tidak menulis ulang datafile target. Ini menghindari RESTORE DATABASE VALIDATE yang bisa memilih backup lain dan mengaburkan hasil demo.

Coba TRANSPARENT tanpa password dan tanpa source key:

```rman
VALIDATE BACKUPSET 1;
```

Contoh output (bagian penting):

```text
ORA-19870: error while restoring backup piece
ORA-19913: unable to decrypt backup
```

Coba PASSWORD tanpa password dan tanpa source key:

```rman
VALIDATE BACKUPSET 2;
```

Contoh output (bagian penting):

```text
ORA-19870: error while restoring backup piece
ORA-19913: unable to decrypt backup
```

Coba DUAL tanpa password dan tanpa source key:

```rman
VALIDATE BACKUPSET 3;
```

Contoh output (bagian penting):

```text
ORA-19870: error while restoring backup piece
ORA-19913: unable to decrypt backup
```

Jalankan di prompt RMAN:

```rman
SET DECRYPTION IDENTIFIED BY "Wrong#2026";
```

Contoh output:

```text
executing command: SET decryption
```

Jalankan di prompt RMAN:

```rman
VALIDATE BACKUPSET 2;
```

Contoh output (bagian penting):

```text
ORA-19870: error while restoring backup piece
ORA-19913: unable to decrypt backup
```

SET DECRYPTION menerima password untuk dicoba; kecocokannya baru diketahui ketika backup dibaca.

Jalankan di prompt RMAN:

```rman
SET DECRYPTION IDENTIFIED BY "RMANBackup#2026";
```

Contoh output:

```text
executing command: SET decryption
```

Jalankan di prompt RMAN:

```rman
VALIDATE BACKUPSET 2;
```

Contoh output (bagian penting):

```text
channel ORA_DISK_1: restored backup piece 1
channel ORA_DISK_1: validation complete, elapsed time: 00:00:01
Finished validate
```

Jalankan di prompt RMAN:

```rman
VALIDATE BACKUPSET 3;
```

Contoh output (bagian penting):

```text
channel ORA_DISK_1: restored backup piece 1
channel ORA_DISK_1: validation complete, elapsed time: 00:00:01
Finished validate
```

PASSWORD dan DUAL sekarang lolos lewat password RMAN. Frasa “restored backup piece” adalah pesan internal VALIDATE; ini bukan bukti bahwa database target sudah direstore atau dapat menjalankan datafile sumber.

Jalankan di prompt RMAN:

```rman
EXIT
```

Contoh output:

```text
Recovery Manager complete.
```

# 14. Source key belum ada: bagaimana membuatnya tersedia?

Target sudah memiliki wallet dan data terenkripsi sendiri. Karena itu kita import source keys ke wallet target, bukan menimpa ewallet.p12. Kunci target tetap tersimpan. Untuk lab ini, root keys diperlukan oleh backup RMAN yang dibuat dari root, dan PDB1 keys diperlukan oleh dump TRANSPARENT PDB1. Export PDB saja tidak cukup untuk membuktikan seluruh alur RMAN root.

## 14.1 SOURCE — export key root

Jalankan di terminal Linux:

```bash
sqlplus / as sysdba
```

Contoh output (bagian penting):

```text
Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
```

Jalankan di SQL*Plus:

```sql
ADMINISTER KEY MANAGEMENT EXPORT ENCRYPTION KEYS
WITH SECRET "KeyTransport#2026"
TO '/u01/app/oracle/admin/oradb/day2b/key_export/root_keys.exp'
IDENTIFIED BY "TDEWallet#2026";
```

Contoh output:

```text
keystore altered.
```

## 14.2 SOURCE — export key PDB1

Jalankan di SQL*Plus:

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

Contoh output:

```text
Session altered.
```

Jalankan di SQL*Plus:

```sql
ADMINISTER KEY MANAGEMENT EXPORT ENCRYPTION KEYS
WITH SECRET "KeyTransport#2026"
TO '/u01/app/oracle/admin/oradb/day2b/key_export/pdb1_keys.exp'
IDENTIFIED BY "TDEWallet#2026";
```

Contoh output:

```text
keystore altered.
```

Tanpa daftar identifier, export mengambil key history pada lingkup container tersebut. Secret melindungi file export; secret ini berbeda dari password wallet. Menjaga history penting karena data atau backup lama mungkin memakai key lama.

Jalankan di SQL*Plus:

```sql
EXIT
```

Contoh output:

```text
Disconnected from Oracle Database 19c Enterprise Edition
```

## 14.3 SOURCE — kirim file export key

Jalankan di terminal Linux:

```bash
scp /u01/app/oracle/admin/oradb/day2b/key_export/root_keys.exp /u01/app/oracle/admin/oradb/day2b/key_export/pdb1_keys.exp \
oracle@192.168.56.23:/u01/app/oracle/admin/oradb/day2b/key_export/
```

Contoh output (bagian penting):

```text
oracle@192.168.56.23's password:
root_keys.exp    100% 2708
pdb1_keys.exp    100% 2708
```

## 14.4 TARGET — secret salah, lalu benar

Jalankan di terminal Linux:

```bash
sqlplus / as sysdba
```

Contoh output (bagian penting):

```text
Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
```

Jalankan di SQL*Plus:

```sql
ADMINISTER KEY MANAGEMENT IMPORT ENCRYPTION KEYS
WITH SECRET "Wrong#2026"
FROM '/u01/app/oracle/admin/oradb/day2b/key_export/root_keys.exp'
IDENTIFIED BY "TargetWallet#2026"
WITH BACKUP USING 'DAY2B_WRONG_SECRET';
```

Contoh output:

```text
ORA-46609: export or import secret is invalid or missing
```

Jalankan di SQL*Plus:

```sql
ADMINISTER KEY MANAGEMENT IMPORT ENCRYPTION KEYS
WITH SECRET "KeyTransport#2026"
FROM '/u01/app/oracle/admin/oradb/day2b/key_export/root_keys.exp'
IDENTIFIED BY "TargetWallet#2026"
WITH BACKUP USING 'DAY2B_ROOT_IMPORT';
```

Contoh output:

```text
keystore altered.
```

Jalankan di SQL*Plus:

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

Contoh output:

```text
Session altered.
```

Jalankan di SQL*Plus:

```sql
ADMINISTER KEY MANAGEMENT IMPORT ENCRYPTION KEYS
WITH SECRET "KeyTransport#2026"
FROM '/u01/app/oracle/admin/oradb/day2b/key_export/pdb1_keys.exp'
IDENTIFIED BY "TargetWallet#2026"
WITH BACKUP USING 'DAY2B_PDB_IMPORT';
```

Contoh output:

```text
keystore altered.
```

Rapikan tampilan setiap kali membuka sesi SQL*Plus baru. Pengaturan tampilan ini boleh ditempel bersama:

```sql
SET LINESIZE 180
SET PAGESIZE 100
SET TAB OFF
SET TRIMSPOOL ON
SET FEEDBACK ON
SET VERIFY OFF
COLUMN owner FORMAT A12
COLUMN table_name FORMAT A22
COLUMN column_name FORMAT A15
COLUMN encryption_alg FORMAT A20
COLUMN customer_name FORMAT A20
COLUMN credit_card FORMAT A19
COLUMN status FORMAT A20
COLUMN wallet_type FORMAT A12
COLUMN wrl_parameter FORMAT A65
COLUMN key_id FORMAT A55
COLUMN tag FORMAT A25
```

Contoh output:

```text
Tidak ada output; format berlaku untuk sesi SQL*Plus ini.
```

Jalankan di SQL*Plus:

```sql
SELECT con_id, key_id, tag FROM v$encryption_keys ORDER BY tag;
```

Contoh output (bagian penting):

```text
CON_ID KEY_ID                                                  TAG
---------- ------------------------------------------------------- -------------------------
         3 AT8xVJ5fRE/uv2k1eW3VovsAAAAAAAAAAAAAAAAAAAAAAAAAAAAA    DAY2B_TARGET_INITIAL
         3 AXC445M9ak+iv6Vl9+9lz6IAAAAAAAAAAAAAAAAAAAAAAAAAAAAA    DAY2_INITIAL_KEY
```

Target kini menyimpan key miliknya sendiri dan key sumber. Bandingkan KEY_ID, bukan hanya TAG: tag adalah label yang bisa sama. Import key tidak otomatis berarti mengganti active key target atau mengenkripsi ulang semua data.

Jalankan di SQL*Plus:

```sql
EXIT
```

Contoh output:

```text
Disconnected from Oracle Database 19c Enterprise Edition
```

# 15. TARGET — coba lagi menggunakan source key

## 15.1 RMAN TRANSPARENT dan DUAL, tanpa password RMAN

Jalankan di terminal Linux:

```bash
rman target /
```

Contoh output:

```text
connected to target database: ORADB (DBID=2803372975)
```

Buka sesi RMAN baru agar SET DECRYPTION dari bagian 13 tidak terbawa.

Jalankan di prompt RMAN:

```rman
VALIDATE BACKUPSET 1;
```

Contoh output (bagian penting):

```text
channel ORA_DISK_1: restored backup piece 1
channel ORA_DISK_1: validation complete, elapsed time: 00:00:01
Finished validate
```

Jalankan di prompt RMAN:

```rman
VALIDATE BACKUPSET 3;
```

Contoh output (bagian penting):

```text
channel ORA_DISK_1: restored backup piece 1
channel ORA_DISK_1: validation complete, elapsed time: 00:00:01
Finished validate
```

Jalankan di prompt RMAN:

```rman
VALIDATE BACKUPSET 2;
```

Contoh output (bagian penting):

```text
ORA-19870: error while restoring backup piece
ORA-19913: unable to decrypt backup
```

Hasil terakhir memang harus gagal: password-only backup tidak bisa dibuka memakai wallet, sekalipun source key sudah ada. Pemulihannya adalah SET DECRYPTION dengan RMANBackup#2026 seperti bagian 13. Dengan demikian kedua jalur DUAL telah diuji secara terpisah.

Jalankan di prompt RMAN:

```rman
EXIT
```

Contoh output:

```text
Recovery Manager complete.
```

## 15.2 Data Pump TRANSPARENT, sekarang berhasil

Jalankan di terminal Linux:

```bash
impdp 'LAB2B_DST/Lab2b#2026@localhost:1521/pdb1.localdomain' \
DIRECTORY=DAY2B_DUMP \
DUMPFILE=transparent.dmp \
LOGFILE=transparent_with_key.log \
REMAP_SCHEMA=LAB2B_SRC:LAB2B_DST \
REMAP_TABLESPACE=DAY2B_DATA:USERS \
REMAP_TABLE=CUSTOMER_SECURE:CUSTOMER_TRANS
```

Contoh output (bagian penting):

```text
. . imported "LAB2B_DST"."CUSTOMER_TRANS"               5.992 KB       2 rows
Job "LAB2B_DST"."SYS_IMPORT_FULL_01" successfully completed
```

## 15.3 Data Pump DUAL, kali ini tanpa password dump

Jalankan di terminal Linux:

```bash
impdp 'LAB2B_DST/Lab2b#2026@localhost:1521/pdb1.localdomain' \
DIRECTORY=DAY2B_DUMP \
DUMPFILE=dual.dmp \
LOGFILE=dual_with_key.log \
REMAP_SCHEMA=LAB2B_SRC:LAB2B_DST \
REMAP_TABLESPACE=DAY2B_DATA:USERS \
REMAP_TABLE=CUSTOMER_SECURE:CUSTOMER_DUAL_KEY
```

Contoh output (bagian penting):

```text
. . imported "LAB2B_DST"."CUSTOMER_DUAL_KEY"               5.992 KB       2 rows
Job "LAB2B_DST"."SYS_IMPORT_FULL_01" successfully completed
```

Jalankan di terminal Linux:

```bash
sqlplus / as sysdba
```

Contoh output (bagian penting):

```text
Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
```

Jalankan di SQL*Plus:

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

Contoh output:

```text
Session altered.
```

Rapikan tampilan setiap kali membuka sesi SQL*Plus baru. Pengaturan tampilan ini boleh ditempel bersama:

```sql
SET LINESIZE 180
SET PAGESIZE 100
SET TAB OFF
SET TRIMSPOOL ON
SET FEEDBACK ON
SET VERIFY OFF
COLUMN owner FORMAT A12
COLUMN table_name FORMAT A22
COLUMN column_name FORMAT A15
COLUMN encryption_alg FORMAT A20
COLUMN customer_name FORMAT A20
COLUMN credit_card FORMAT A19
COLUMN status FORMAT A20
COLUMN wallet_type FORMAT A12
COLUMN wrl_parameter FORMAT A65
COLUMN key_id FORMAT A55
COLUMN tag FORMAT A25
```

Contoh output:

```text
Tidak ada output; format berlaku untuk sesi SQL*Plus ini.
```

Jalankan di SQL*Plus:

```sql
SELECT * FROM LAB2B_DST.CUSTOMER_TRANS ORDER BY customer_id;
```

Contoh output (bagian penting):

```text
CUSTOMER_ID CUSTOMER_NAME        CREDIT_CARD
----------- -------------------- -------------------
          1 Andi                 4111-1111-1111-1111
          2 Sari                 5555-5555-5555-4444

2 rows selected.
```

Jalankan di SQL*Plus:

```sql
SELECT * FROM LAB2B_DST.CUSTOMER_DUAL_KEY ORDER BY customer_id;
```

Contoh output (bagian penting):

```text
CUSTOMER_ID CUSTOMER_NAME        CREDIT_CARD
----------- -------------------- -------------------
          1 Andi                 4111-1111-1111-1111
          2 Sari                 5555-5555-5555-4444

2 rows selected.
```

Jalankan di SQL*Plus:

```sql
SELECT owner, table_name, column_name, encryption_alg
FROM dba_encrypted_columns WHERE owner='LAB2B_DST'
ORDER BY table_name;
```

Contoh output (bagian penting):

```text
OWNER        TABLE_NAME             COLUMN_NAME     ENCRYPTION_ALG
------------ ---------------------- --------------- --------------------
LAB2B_DST    CUSTOMER_DUAL          CREDIT_CARD     AES 256 bits key
LAB2B_DST    CUSTOMER_DUAL_KEY      CREDIT_CARD     AES 256 bits key
LAB2B_DST    CUSTOMER_RETRY         CREDIT_CARD     AES 256 bits key
LAB2B_DST    CUSTOMER_SECURE        CREDIT_CARD     AES 256 bits key
LAB2B_DST    CUSTOMER_TRANS         CREDIT_CARD     AES 256 bits key
```

Jalankan di SQL*Plus:

```sql
EXIT
```

Contoh output:

```text
Disconnected from Oracle Database 19c Enterprise Edition
```

# 16. Apa yang sudah terbukti?

| Skenario | Hasil pengujian | Cara mendapatkan akses |
|---|---|---|
| Data Pump PASSWORD tanpa password | ORA-39174 | Berikan password dump |
| Password dump salah | ORA-39176 | Gunakan DataPump#2026 |
| Data Pump PASSWORD, target wallet OPEN | Import 2 baris berhasil | Tidak perlu source key |
| Query kolom TDE, target wallet CLOSED | ORA-28365 | Buka wallet PDB1 target |
| Password wallet target salah | ORA-46627 | Gunakan TargetWallet#2026 |
| Import tabel non-TDE, wallet CLOSED | Berhasil | Password dump cukup pada USERS non-TDE |
| Import kolom TDE, wallet CLOSED | ORA-39083 / ORA-28365 | Buka wallet lalu ulangi import |
| Data Pump TRANSPARENT, key sumber belum ada | ORA-39189 / ORA-28362 | Import key PDB sumber |
| Data Pump DUAL | Berhasil lewat password dan lewat key | Salah satu jalur tersedia |
| Export TDE dengan ENCRYPTION=NONE | ORA-39173, dump tidak terenkripsi | Pakai ENCRYPTION=ALL untuk dump aman |
| Backup PDB OPEN pada NOARCHIVELOG | RMAN-06817 | Cold backup pada MOUNT setelah shutdown bersih |
| RMAN TRANSPARENT tanpa source key | ORA-19913 | Import key root sumber |
| RMAN PASSWORD tanpa password / password salah | ORA-19913 | SET DECRYPTION dengan password benar |
| RMAN DUAL | Kedua jalur validasi berhasil | Password atau source key |
| RMAN PASSWORD ONLY dengan wallet saja | Tetap ORA-19913 | Tetap perlu password RMAN |
| Secret import key salah | ORA-46609 | Gunakan KeyTransport#2026 |
| Query TDE setelah restart sumber | ORA-28365 | Buka wallet PDB1, bukan hanya root |

# 17. Data Pump vs RMAN vs TDE — kalimat untuk dibawa pulang

Data Pump adalah migrasi logis. Dalam lab PASSWORD, dump dibuka memakai password lalu kolom TDE dibuat menggunakan key target. RMAN adalah backup fisik: meskipun lapisan backup berhasil dibuka, data TDE di dalam datafile tetap memakai key asal.

| Isi database | Lapisan backup RMAN | Membuka backup | Mengakses data TDE setelah pemulihan fisik |
|---|---|---|---|
| Non-TDE | PASSWORD ONLY | Password RMAN | Tidak membutuhkan key TDE untuk data non-TDE |
| TDE | PASSWORD ONLY | Password RMAN | Tetap membutuhkan key TDE asal |
| TDE | TRANSPARENT | Key sumber yang sesuai | Key TDE asal tetap diperlukan |
| TDE | DUAL | Password RMAN atau key sumber | Key TDE asal tetap diperlukan |

Tabel ini menjelaskan konsep dua lapisan. Pengujian fisik pada latihan ini sampai VALIDATE BACKUPSET, bukan restore dan open seluruh database. Keberhasilan akses SQL dibuktikan lewat tabel Data Pump dan latihan wallet tertutup, bukan diklaim sebagai hasil full RMAN recovery.

Untuk pemulihan penuh, desain backup harus mencakup seluruh datafile yang diperlukan, controlfile/SPFILE, keystore beserta key history, dan archived redo sesuai mode serta target recovery. Keystore baru dengan password sama tidak akan menciptakan ulang key yang hilang. Pada NOARCHIVELOG, batas pemulihan berbeda dari latihan media recovery berbasis archived redo.

# 18. Penyesuaian terhadap naskah awal dan batas latihan

Alur yang meng-copy ewallet.p12 sumber di atas wallet target existing dihapus dari langkah praktikum: target lab ini sudah menyimpan key dan data miliknya sendiri. Penggantinya adalah export/import key root dan PDB yang sudah berhasil diuji. Konsep copy wallet masih relevan untuk server pemulihan yang memang belum memiliki keystore, tetapi itu bukan kondisi target latihan ini.

Perintah lepas RESTORE DATABASE dan RECOVER DATABASE juga dihapus dari langkah praktikum karena naskah awal tidak menyiapkan target DR beserta controlfile, incarnation, dan backup lengkap. Lab ini mempertahankan fokus dekripsi dengan VALIDATE BACKUPSET yang memilih backup secara eksplisit. Ini pembatasan cakupan pengujian, bukan klaim bahwa Oracle 19.8 tidak mendukung full restore.

Backup online PLUS ARCHIVELOG diganti cold backup datafile lab agar kompatibel dengan NOARCHIVELOG. Kasus PASSWORD, TRANSPARENT, DUAL, non-TDE, key transport, dan gagal/pulih tetap dipertahankan. Tidak ada skenario yang dinyatakan berhasil hanya berdasarkan perkiraan output.

Untuk mengulang dari awal, kembalikan snapshot persiapan yang sesuai. Jangan menghapus key dari wallet hanya demi mengulang error: data atau backup yang sudah dibuat mungkin masih membutuhkannya. Hasil run ini sengaja tetap tersedia untuk diperiksa peserta atau instruktur.

# 19. Referensi Oracle 19c

Penjelasan mode dump mengacu pada [Oracle Data Pump Export](https://docs.oracle.com/en/database/oracle/oracle-database/19/sutil/oracle-data-pump-export-utility.html) dan [Data Pump Import](https://docs.oracle.com/en/database/oracle/oracle-database/19/sutil/datapump-import-utility.html). Output praktikum berasal dari log VM, bukan disalin dari dokumentasi.

Hubungan TDE dengan dump dan backup dijelaskan dalam [Using TDE with Other Oracle Features](https://docs.oracle.com/en/database/oracle/oracle-database/19/asoag/using-transparent-data-encryption-with-other-oracle-features.html). Pengelolaan key merujuk [Managing the Keystore and TDE Master Encryption Key](https://docs.oracle.com/en/database/oracle/oracle-database/19/asoag/managing-keystore-and-tde-master-encryption-key.html).

Mode enkripsi RMAN merujuk [Configuring the RMAN Environment: Advanced Topics](https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/configuring-rman-client-advanced.html). Batas validasi merujuk [VALIDATE](https://docs.oracle.com/en/database/oracle/oracle-database/19/rcmrf/VALIDATE.html), dan backup konsisten merujuk [Backing Up the Database](https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/backing-up-database.html).


---



<!-- ============================================================ -->
<!-- SOURCE: tde_and_backup_operation.md -->
<!-- ============================================================ -->

<a id="day-2b-hands-on"></a>

# DAY 2B — Data Pump, RMAN, dan TDE (Hands-on Copy-Paste)

> **Sumber file:** `tde_and_backup_operation.md`

# Data Pump, RMAN, dan TDE

> **Versi hands-on siap copy-paste.** Jalankan command satu per satu
> sesuai urutan. Perhatikan label **SOURCE**, **TARGET**, atau **SOURCE
> & TARGET** sebelum menjalankan command.

# 1. Environment dan alur lab

  | Komponen | SOURCE | TARGET |
|---|---|---|
| IP | 192.168.56.22 | 192.168.56.23 |
| User SSH / password | oracle / oracle | oracle / oracle |
| Hostname aktual | srv1.localdomain | srv1.localdomain |
| Oracle | 19.8 Enterprise Edition | 19.8 Enterprise Edition |
| CDB / SID | ORADB / oradb | ORADB / oradb |
| PDB / network service | PDB1 / pdb1.localdomain | PDB1 / pdb1.localdomain |
| Log mode | NOARCHIVELOG | NOARCHIVELOG |
| DBID saat uji | 2803372975 | 2803372975 |
| Schema lab | LAB2B_SRC | LAB2B_DST |


``` text
ORACLE_BASE  /u01/app/oracle
ORACLE_HOME  /u01/app/oracle/product/19.0.0/db_1
Wallet       /u01/app/oracle/admin/oradb/wallet
Dump         /u01/app/oracle/admin/oradb/day2b/dpump
Backup RMAN  /u01/app/oracle/admin/oradb/day2b/rman
Export key   /u01/app/oracle/admin/oradb/day2b/key_export

Wallet source       TDEWallet#2026
Wallet target       TargetWallet#2026
User database lab   Lab2b#2026
Data Pump           DataPump#2026
RMAN                RMANBackup#2026
Secret export key   KeyTransport#2026
```

# 3. Persiapan terminal dan SQL\*Plus --- kedua VM

**TARGET --- Terminal lokal**
``` bash
su -
nmcli con show
nmcli con mod enp0s3 ipv4.addresses 192.168.56.23/24
nmcli con mod enp0s3 ipv4.method manual
nmcli con up enp0s3
```

**SOURCE --- Terminal lokal / SSH**

``` bash
ssh oracle@192.168.56.22
```

**TARGET --- Terminal lokal / SSH**

``` bash
ssh oracle@192.168.56.23
```

Di masing-masing terminal, muat environment Oracle:

``` bash
source ~/.bash_profile
```

**SOURCE & TARGET — Terminal Linux**

``` bash
printf "%s\n" "$ORACLE_BASE" "$ORACLE_HOME" "$ORACLE_SID"
```

``` bash
lsnrctl status
```

``` bash
sqlplus / as sysdba
```

**SOURCE & TARGET — SQL*Plus**

``` sql
SELECT name, open_mode, log_mode, dbid FROM v$database;
```

``` sql
SHOW PDBS
```

Cek wallet. Contoh berikut adalah SOURCE pada awal lab; TARGET awalnya
NOT_AVAILABLE:

``` sql
SELECT con_id, status, wallet_type, wrl_parameter
FROM v$encryption_wallet ORDER BY con_id;
```

``` sql
EXIT
```

Buat folder kerja di SOURCE dan TARGET:

``` bash
mkdir -p /u01/app/oracle/admin/oradb/day2b/{dpump,rman,key_export}
```

**SOURCE & TARGET — Terminal Linux**

``` bash
chmod 700 /u01/app/oracle/admin/oradb/day2b /u01/app/oracle/admin/oradb/day2b/dpump /u01/app/oracle/admin/oradb/day2b/rman /u01/app/oracle/admin/oradb/day2b/key_export
```

# 4. SOURCE --- siapkan data contoh yang benar-benar TDE

**SOURCE — Terminal Linux**

``` bash
sqlplus / as sysdba
```

**SOURCE — SQL*Plus**

``` sql
ADMINISTER KEY MANAGEMENT BACKUP KEYSTORE
USING 'BEFORE_DAY2B_TEST' IDENTIFIED BY "TDEWallet#2026";
```

``` sql
ALTER SESSION SET CONTAINER=PDB1;
```

``` sql
CREATE TABLESPACE DAY2B_DATA
DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/day2b_data01.dbf' SIZE 10M;
```

``` sql
CREATE USER LAB2B_SRC IDENTIFIED BY "Lab2b#2026"
DEFAULT TABLESPACE DAY2B_DATA QUOTA 5M ON DAY2B_DATA;
```

``` sql
GRANT CREATE SESSION, CREATE TABLE TO LAB2B_SRC;
```

``` sql
CREATE DIRECTORY DAY2B_DUMP AS '/u01/app/oracle/admin/oradb/day2b/dpump';
```

``` sql
GRANT READ, WRITE ON DIRECTORY DAY2B_DUMP TO LAB2B_SRC;
```

``` sql
CREATE TABLE LAB2B_SRC.CUSTOMER_SECURE (
  customer_id NUMBER,
  customer_name VARCHAR2(20),
  credit_card VARCHAR2(19) ENCRYPT USING 'AES256'
) TABLESPACE DAY2B_DATA;
```

``` sql
INSERT INTO LAB2B_SRC.CUSTOMER_SECURE VALUES (1,'Andi','4111-1111-1111-1111');
```

``` sql
INSERT INTO LAB2B_SRC.CUSTOMER_SECURE VALUES (2,'Sari','5555-5555-5555-4444');
```

``` sql
CREATE TABLE LAB2B_SRC.CUSTOMER_PLAIN TABLESPACE DAY2B_DATA
AS SELECT * FROM LAB2B_SRC.CUSTOMER_SECURE;
```

``` sql
COMMIT;
```

``` sql
SELECT owner, table_name, column_name, encryption_alg
FROM dba_encrypted_columns WHERE owner='LAB2B_SRC';
```

``` sql
EXIT
```

# 5. TARGET --- wallet dan schema sendiri

> Jika wallet TARGET sudah ada dari run sebelumnya, jangan ulangi
> `CREATE KEYSTORE` dan jangan menimpa `ewallet.p12`.

**TARGET — Terminal Linux**

``` bash
mkdir -p /u01/app/oracle/admin/oradb/wallet
```

``` bash
chmod 700 /u01/app/oracle/admin/oradb/wallet
```

``` bash
sqlplus / as sysdba
```

**TARGET — SQL*Plus**

``` sql
ADMINISTER KEY MANAGEMENT CREATE KEYSTORE
'/u01/app/oracle/admin/oradb/wallet' IDENTIFIED BY "TargetWallet#2026";
```

``` sql
ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN
IDENTIFIED BY "TargetWallet#2026" CONTAINER=ALL;
```

``` sql
ADMINISTER KEY MANAGEMENT SET KEY USING TAG 'DAY2B_TARGET_INITIAL'
IDENTIFIED BY "TargetWallet#2026"
WITH BACKUP USING 'DAY2B_TARGET_INITIAL' CONTAINER=ALL;
```

``` sql
SELECT con_id, status, wallet_type FROM v$encryption_wallet ORDER BY con_id;
```

``` sql
ALTER SESSION SET CONTAINER=PDB1;
```

``` sql
CREATE USER LAB2B_DST IDENTIFIED BY "Lab2b#2026"
DEFAULT TABLESPACE USERS QUOTA 20M ON USERS;
```

``` sql
GRANT CREATE SESSION, CREATE TABLE TO LAB2B_DST;
```

``` sql
CREATE DIRECTORY DAY2B_DUMP AS '/u01/app/oracle/admin/oradb/day2b/dpump';
```

``` sql
GRANT READ, WRITE ON DIRECTORY DAY2B_DUMP TO LAB2B_DST;
```

``` sql
EXIT
```

# 6. SOURCE --- export PASSWORD, TRANSPARENT, dan DUAL

Kita buat beberapa dump kecil. Setiap blok expdp adalah satu command;
backslash hanya menyambung baris. Tunggu job selesai sebelum lanjut.
Nama dump harus belum ada agar hasil uji sebelumnya tidak tertimpa.

## 6.1 Tabel TDE, dump PASSWORD

**SOURCE — Terminal Linux**

``` bash
expdp 'LAB2B_SRC/Lab2b#2026@localhost:1521/pdb1.localdomain' \
DIRECTORY=DAY2B_DUMP \
DUMPFILE=password.dmp \
LOGFILE=password_exp.log \
TABLES=LAB2B_SRC.CUSTOMER_SECURE \
ENCRYPTION=ALL \
ENCRYPTION_MODE=PASSWORD \
ENCRYPTION_ALGORITHM=AES256 \
ENCRYPTION_PASSWORD=DataPump#2026
```

## 6.2 Tabel biasa, dump tetap terenkripsi

**SOURCE — Terminal Linux**

``` bash
expdp 'LAB2B_SRC/Lab2b#2026@localhost:1521/pdb1.localdomain' \
DIRECTORY=DAY2B_DUMP \
DUMPFILE=plain_password.dmp \
LOGFILE=plain_password_exp.log \
TABLES=LAB2B_SRC.CUSTOMER_PLAIN \
ENCRYPTION=ALL \
ENCRYPTION_MODE=PASSWORD \
ENCRYPTION_ALGORITHM=AES256 \
ENCRYPTION_PASSWORD=DataPump#2026
```

## 6.3 Dump TRANSPARENT

**SOURCE — Terminal Linux**

``` bash
expdp 'LAB2B_SRC/Lab2b#2026@localhost:1521/pdb1.localdomain' \
DIRECTORY=DAY2B_DUMP \
DUMPFILE=transparent.dmp \
LOGFILE=transparent_exp.log \
TABLES=LAB2B_SRC.CUSTOMER_SECURE \
ENCRYPTION=ALL \
ENCRYPTION_MODE=TRANSPARENT \
ENCRYPTION_ALGORITHM=AES256
```

## 6.4 Dump DUAL

**SOURCE — Terminal Linux**

``` bash
expdp 'LAB2B_SRC/Lab2b#2026@localhost:1521/pdb1.localdomain' \
DIRECTORY=DAY2B_DUMP \
DUMPFILE=dual.dmp \
LOGFILE=dual_exp.log \
TABLES=LAB2B_SRC.CUSTOMER_SECURE \
ENCRYPTION=ALL \
ENCRYPTION_MODE=DUAL \
ENCRYPTION_ALGORITHM=AES256 \
ENCRYPTION_PASSWORD=DataPump#2026
```

## 6.5 Buktikan TDE tidak otomatis mengamankan dump

**SOURCE — Terminal Linux**

``` bash
expdp 'LAB2B_SRC/Lab2b#2026@localhost:1521/pdb1.localdomain' \
DIRECTORY=DAY2B_DUMP \
DUMPFILE=unencrypted.dmp \
LOGFILE=unencrypted_exp.log \
TABLES=LAB2B_SRC.CUSTOMER_SECURE \
ENCRYPTION=NONE
```

# 7. SOURCE → TARGET --- kirim dump, tanpa source wallet

**SOURCE — Terminal Linux**

``` bash
scp /u01/app/oracle/admin/oradb/day2b/dpump/password.dmp /u01/app/oracle/admin/oradb/day2b/dpump/plain_password.dmp \
/u01/app/oracle/admin/oradb/day2b/dpump/transparent.dmp /u01/app/oracle/admin/oradb/day2b/dpump/dual.dmp \
oracle@192.168.56.23:/u01/app/oracle/admin/oradb/day2b/dpump/
```

# 8. TARGET --- PASSWORD: gagal dahulu, lalu berhasil

## 8.1 Tanpa password dump

**TARGET — Terminal Linux**

``` bash
impdp 'LAB2B_DST/Lab2b#2026@localhost:1521/pdb1.localdomain' \
DIRECTORY=DAY2B_DUMP \
DUMPFILE=password.dmp \
LOGFILE=no_password.log \
REMAP_SCHEMA=LAB2B_SRC:LAB2B_DST \
REMAP_TABLESPACE=DAY2B_DATA:USERS
```

## 8.2 Password dump salah

**TARGET — Terminal Linux**

``` bash
impdp 'LAB2B_DST/Lab2b#2026@localhost:1521/pdb1.localdomain' \
DIRECTORY=DAY2B_DUMP \
DUMPFILE=password.dmp \
LOGFILE=wrong_password.log \
REMAP_SCHEMA=LAB2B_SRC:LAB2B_DST \
REMAP_TABLESPACE=DAY2B_DATA:USERS \
ENCRYPTION_PASSWORD=Wrong#2026
```

## 8.3 Password benar

**TARGET — Terminal Linux**

``` bash
impdp 'LAB2B_DST/Lab2b#2026@localhost:1521/pdb1.localdomain' \
DIRECTORY=DAY2B_DUMP \
DUMPFILE=password.dmp \
LOGFILE=password_imp.log \
REMAP_SCHEMA=LAB2B_SRC:LAB2B_DST \
REMAP_TABLESPACE=DAY2B_DATA:USERS \
ENCRYPTION_PASSWORD=DataPump#2026
```

``` bash
sqlplus / as sysdba
```

**TARGET — SQL*Plus**

``` sql
ALTER SESSION SET CONTAINER=PDB1;
```

``` sql
SELECT * FROM LAB2B_DST.CUSTOMER_SECURE ORDER BY customer_id;
```

``` sql
SELECT owner, table_name, column_name, encryption_alg
FROM dba_encrypted_columns WHERE owner='LAB2B_DST'
AND table_name='CUSTOMER_SECURE';
```

``` sql
EXIT
```

# 9. TARGET --- TRANSPARENT dan DUAL sebelum source key diimpor

**TARGET — Terminal Linux**

``` bash
impdp 'LAB2B_DST/Lab2b#2026@localhost:1521/pdb1.localdomain' \
DIRECTORY=DAY2B_DUMP \
DUMPFILE=transparent.dmp \
LOGFILE=transparent_missing_key.log \
REMAP_SCHEMA=LAB2B_SRC:LAB2B_DST \
REMAP_TABLESPACE=DAY2B_DATA:USERS \
REMAP_TABLE=CUSTOMER_SECURE:CUSTOMER_TRANS
```

``` bash
impdp 'LAB2B_DST/Lab2b#2026@localhost:1521/pdb1.localdomain' \
DIRECTORY=DAY2B_DUMP \
DUMPFILE=dual.dmp \
LOGFILE=dual_password.log \
REMAP_SCHEMA=LAB2B_SRC:LAB2B_DST \
REMAP_TABLESPACE=DAY2B_DATA:USERS \
REMAP_TABLE=CUSTOMER_SECURE:CUSTOMER_DUAL \
ENCRYPTION_PASSWORD=DataPump#2026
```

# 10. TARGET --- data terenkripsi tidak bisa diakses, lalu dipulihkan

**TARGET — Terminal Linux**

``` bash
sqlplus / as sysdba
```

**TARGET — SQL*Plus**

``` sql
ALTER SESSION SET CONTAINER=PDB1;
```

``` sql
SELECT * FROM LAB2B_DST.CUSTOMER_SECURE ORDER BY customer_id;
```

``` sql
ADMINISTER KEY MANAGEMENT SET KEYSTORE CLOSE
IDENTIFIED BY "TargetWallet#2026";
```

``` sql
SELECT * FROM LAB2B_DST.CUSTOMER_SECURE ORDER BY customer_id;
```

Sekarang pilih hanya kolom yang tidak terenkripsi:

``` sql
SELECT customer_id, customer_name FROM LAB2B_DST.CUSTOMER_SECURE
ORDER BY customer_id;
```

``` sql
EXIT
```

## 10.1 Dump PASSWORD berisi tabel non-TDE tetap bisa diimpor

**TARGET — Terminal Linux**

``` bash
impdp 'LAB2B_DST/Lab2b#2026@localhost:1521/pdb1.localdomain' \
DIRECTORY=DAY2B_DUMP \
DUMPFILE=plain_password.dmp \
LOGFILE=plain_closed_wallet.log \
REMAP_SCHEMA=LAB2B_SRC:LAB2B_DST \
REMAP_TABLESPACE=DAY2B_DATA:USERS \
ENCRYPTION_PASSWORD=DataPump#2026
```

## 10.2 Password dump benar, tetapi tabel TDE gagal dibuat

**TARGET — Terminal Linux**

``` bash
impdp 'LAB2B_DST/Lab2b#2026@localhost:1521/pdb1.localdomain' \
DIRECTORY=DAY2B_DUMP \
DUMPFILE=password.dmp \
LOGFILE=secure_closed_wallet.log \
REMAP_SCHEMA=LAB2B_SRC:LAB2B_DST \
REMAP_TABLESPACE=DAY2B_DATA:USERS \
REMAP_TABLE=CUSTOMER_SECURE:CUSTOMER_RETRY \
ENCRYPTION_PASSWORD=DataPump#2026
```

## 10.3 Buka keystore dengan password yang benar

**TARGET — Terminal Linux**

``` bash
sqlplus / as sysdba
```

**TARGET — SQL*Plus**

``` sql
ALTER SESSION SET CONTAINER=PDB1;
```

``` sql
ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN
IDENTIFIED BY "Wrong#2026";
```

``` sql
ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN
IDENTIFIED BY "TargetWallet#2026";
```

``` sql
SELECT * FROM LAB2B_DST.CUSTOMER_SECURE ORDER BY customer_id;
```

``` sql
EXIT
```

**TARGET — Terminal Linux**

``` bash
impdp 'LAB2B_DST/Lab2b#2026@localhost:1521/pdb1.localdomain' \
DIRECTORY=DAY2B_DUMP \
DUMPFILE=password.dmp \
LOGFILE=secure_reopened_wallet.log \
REMAP_SCHEMA=LAB2B_SRC:LAB2B_DST \
REMAP_TABLESPACE=DAY2B_DATA:USERS \
REMAP_TABLE=CUSTOMER_SECURE:CUSTOMER_RETRY \
ENCRYPTION_PASSWORD=DataPump#2026
```

# 11. SOURCE --- RMAN pada ARCHIVELOG

**SOURCE — Terminal Linux**

``` bash
sqlplus / as sysdba
```

**SOURCE — SQL*Plus**

``` sql
ALTER SESSION SET CONTAINER=PDB1;
```

``` sql
ALTER TABLESPACE DAY2B_DATA READ ONLY;
```

``` sql
ALTER SESSION SET CONTAINER=CDB$ROOT;
```

``` sql
SHUTDOWN IMMEDIATE;
```

``` sql
STARTUP MOUNT;
```

``` sql
ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN
IDENTIFIED BY "TDEWallet#2026";
```

``` sql
EXIT
```

**SOURCE — Terminal Linux**

``` bash
rman target /
```

**SOURCE — RMAN**

``` rman
SET ENCRYPTION ALGORITHM 'AES256';
```

## 11.1 TRANSPARENT

**SOURCE — RMAN**

``` rman
SET ENCRYPTION ON;
```

``` rman
BACKUP DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/day2b_data01.dbf'
FORMAT '/u01/app/oracle/admin/oradb/day2b/rman/trans_%U.bkp' TAG 'DAY2B_TRANS';
```

## 11.2 PASSWORD ONLY

**SOURCE — RMAN**

``` rman
SET ENCRYPTION ON IDENTIFIED BY "RMANBackup#2026" ONLY;
```

``` rman
BACKUP DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/day2b_data01.dbf'
FORMAT '/u01/app/oracle/admin/oradb/day2b/rman/pass_%U.bkp' TAG 'DAY2B_PASS';
```

## 11.3 DUAL

**SOURCE — RMAN**

``` rman
SET ENCRYPTION ON IDENTIFIED BY "RMANBackup#2026";
```

``` rman
BACKUP DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/day2b_data01.dbf'
FORMAT '/u01/app/oracle/admin/oradb/day2b/rman/dual_%U.bkp' TAG 'DAY2B_DUAL';
```

``` rman
EXIT
```

## 11.4 Buka kembali database dan wallet PDB1

**SOURCE — Terminal Linux**

``` bash
sqlplus / as sysdba
```

**SOURCE — SQL*Plus**

``` sql
ALTER DATABASE OPEN;
```

``` sql
SHOW PDBS
```

``` sql
ALTER SESSION SET CONTAINER=PDB1;
```

``` sql
SELECT con_id, status, wallet_type FROM v$encryption_wallet;
```

``` sql
SELECT * FROM LAB2B_SRC.CUSTOMER_SECURE ORDER BY customer_id;
```

``` sql
ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN
IDENTIFIED BY "TDEWallet#2026";
```

``` sql
SELECT * FROM LAB2B_SRC.CUSTOMER_SECURE ORDER BY customer_id;
```

``` sql
ALTER TABLESPACE DAY2B_DATA READ WRITE;
```

``` sql
ALTER SESSION SET CONTAINER=CDB$ROOT;
```

``` sql
SELECT p.tag, p.encrypted, s.recid AS bs_key
FROM v$backup_piece p JOIN v$backup_set s
ON p.set_stamp=s.set_stamp AND p.set_count=s.set_count
WHERE p.tag IN ('DAY2B_TRANS','DAY2B_PASS','DAY2B_DUAL')
ORDER BY s.recid;
```

``` sql
EXIT
```

# 12. SOURCE → TARGET --- copy backup dan tentukan backup-set key

> Setelah `scp` selesai, pindah ke terminal TARGET untuk command RMAN
> berikutnya. Gunakan nomor Key hasil `LIST BACKUP SUMMARY` sesuai tag
> pada VM Anda.

**SOURCE — Terminal Linux**

``` bash
scp /u01/app/oracle/admin/oradb/day2b/rman/*.bkp \
oracle@192.168.56.23:/u01/app/oracle/admin/oradb/day2b/rman/
```

Sekarang pindah ke terminal TARGET. Sampai bagian ini, source key belum
diimpor. Jangan melompat ke bagian 14 dahulu.

**SOURCE — Terminal Linux**

``` bash
rman target /
```

**SOURCE — RMAN**

``` rman
CATALOG START WITH '/u01/app/oracle/admin/oradb/day2b/rman/' NOPROMPT;
```

``` rman
LIST BACKUP SUMMARY;
```

# 13. TARGET --- RMAN gagal tanpa kunci, pulih dengan password

> Command `VALIDATE BACKUPSET 1/2/3` mengikuti Key dari hasil lab
> teruji. Jika nomor Key pada VM Anda berbeda, gunakan Key yang sesuai
> tag.

Coba TRANSPARENT tanpa password dan tanpa source key:

``` rman
VALIDATE BACKUPSET 1;
```

Coba PASSWORD tanpa password dan tanpa source key:

``` rman
VALIDATE BACKUPSET 2;
```

Coba DUAL tanpa password dan tanpa source key:

``` rman
VALIDATE BACKUPSET 3;
```

**TARGET — RMAN**

``` rman
SET DECRYPTION IDENTIFIED BY "Wrong#2026";
```

``` rman
VALIDATE BACKUPSET 2;
```

``` rman
SET DECRYPTION IDENTIFIED BY "RMANBackup#2026";
```

``` rman
VALIDATE BACKUPSET 2;
```

``` rman
VALIDATE BACKUPSET 3;
```

``` rman
EXIT
```

# 14. Source key belum ada: bagaimana membuatnya tersedia?

## 14.1 SOURCE --- export key root

**SOURCE — Terminal Linux**

``` bash
sqlplus / as sysdba
```

**SOURCE — SQL*Plus**

``` sql
ADMINISTER KEY MANAGEMENT EXPORT ENCRYPTION KEYS
WITH SECRET "KeyTransport#2026"
TO '/u01/app/oracle/admin/oradb/day2b/key_export/root_keys.exp'
IDENTIFIED BY "TDEWallet#2026";
```

## 14.2 SOURCE --- export key PDB1

**SOURCE — SQL*Plus**

``` sql
ALTER SESSION SET CONTAINER=PDB1;
```

``` sql
ADMINISTER KEY MANAGEMENT EXPORT ENCRYPTION KEYS
WITH SECRET "KeyTransport#2026"
TO '/u01/app/oracle/admin/oradb/day2b/key_export/pdb1_keys.exp'
IDENTIFIED BY "TDEWallet#2026";
```

``` sql
EXIT
```

## 14.3 SOURCE --- kirim file export key

**SOURCE — Terminal Linux**

``` bash
scp /u01/app/oracle/admin/oradb/day2b/key_export/root_keys.exp /u01/app/oracle/admin/oradb/day2b/key_export/pdb1_keys.exp \
oracle@192.168.56.23:/u01/app/oracle/admin/oradb/day2b/key_export/
```

## 14.4 TARGET --- secret salah, lalu benar

**TARGET — Terminal Linux**

``` bash
sqlplus / as sysdba
```

**TARGET — SQL*Plus**

``` sql
ADMINISTER KEY MANAGEMENT IMPORT ENCRYPTION KEYS
WITH SECRET "Wrong#2026"
FROM '/u01/app/oracle/admin/oradb/day2b/key_export/root_keys.exp'
IDENTIFIED BY "TargetWallet#2026"
WITH BACKUP USING 'DAY2B_WRONG_SECRET';
```

``` sql
ADMINISTER KEY MANAGEMENT IMPORT ENCRYPTION KEYS
WITH SECRET "KeyTransport#2026"
FROM '/u01/app/oracle/admin/oradb/day2b/key_export/root_keys.exp'
IDENTIFIED BY "TargetWallet#2026"
WITH BACKUP USING 'DAY2B_ROOT_IMPORT';
```

``` sql
ALTER SESSION SET CONTAINER=PDB1;
```

``` sql
ADMINISTER KEY MANAGEMENT IMPORT ENCRYPTION KEYS
WITH SECRET "KeyTransport#2026"
FROM '/u01/app/oracle/admin/oradb/day2b/key_export/pdb1_keys.exp'
IDENTIFIED BY "TargetWallet#2026"
WITH BACKUP USING 'DAY2B_PDB_IMPORT';
```

``` sql
SELECT con_id, key_id, tag FROM v$encryption_keys ORDER BY tag;
```

``` sql
EXIT
```

# 15. TARGET --- coba lagi menggunakan source key

## 15.1 RMAN TRANSPARENT dan DUAL, tanpa password RMAN

**TARGET — Terminal Linux**

``` bash
rman target /
```

**TARGET — RMAN**

``` rman
VALIDATE BACKUPSET 1;
```

``` rman
VALIDATE BACKUPSET 3;
```

``` rman
VALIDATE BACKUPSET 2;
```

``` rman
EXIT
```

## 15.2 Data Pump TRANSPARENT, sekarang berhasil

**TARGET — Terminal Linux**

``` bash
impdp 'LAB2B_DST/Lab2b#2026@localhost:1521/pdb1.localdomain' \
DIRECTORY=DAY2B_DUMP \
DUMPFILE=transparent.dmp \
LOGFILE=transparent_with_key.log \
REMAP_SCHEMA=LAB2B_SRC:LAB2B_DST \
REMAP_TABLESPACE=DAY2B_DATA:USERS \
REMAP_TABLE=CUSTOMER_SECURE:CUSTOMER_TRANS
```

## 15.3 Data Pump DUAL, kali ini tanpa password dump

**TARGET — Terminal Linux**

``` bash
impdp 'LAB2B_DST/Lab2b#2026@localhost:1521/pdb1.localdomain' \
DIRECTORY=DAY2B_DUMP \
DUMPFILE=dual.dmp \
LOGFILE=dual_with_key.log \
REMAP_SCHEMA=LAB2B_SRC:LAB2B_DST \
REMAP_TABLESPACE=DAY2B_DATA:USERS \
REMAP_TABLE=CUSTOMER_SECURE:CUSTOMER_DUAL_KEY
```

``` bash
sqlplus / as sysdba
```

**TARGET — SQL*Plus**

``` sql
ALTER SESSION SET CONTAINER=PDB1;
```

``` sql
SELECT * FROM LAB2B_DST.CUSTOMER_TRANS ORDER BY customer_id;
```

``` sql
SELECT * FROM LAB2B_DST.CUSTOMER_DUAL_KEY ORDER BY customer_id;
```

``` sql
SELECT owner, table_name, column_name, encryption_alg
FROM dba_encrypted_columns WHERE owner='LAB2B_DST'
ORDER BY table_name;
```

``` sql
EXIT
```


---



<!-- ============================================================ -->
<!-- SOURCE: preventive_day3.md -->
<!-- ============================================================ -->

<a id="day-3"></a>

# DAY 3 — Oracle Key Vault & Sensitive Data Discovery

> **Sumber file:** `preventive_day3.md`

# DAY 3 — Oracle Key Vault & Sensitive Data Discovery

## Materi silabus

Day 3 mencakup:

1. Introduction to Oracle Key Vault
2. What is Oracle Key Vault?
3. Using Oracle Key Vault
4. Installing Oracle Key Vault
5. Endpoints
6. Oracle Wallet vs OKV Virtual Wallets
7. Administering Oracle Key Vault
8. Roles in detail
9. Best-practice tips
10. Automated Sensitive Data Discovery
11. Application Data Modeling
12. Managing Application Data Models. 

---

# BAGIAN A — Oracle Key Vault

## 1. Tujuan

Peserta memahami perbedaan:

```text
TDE
 |
 +-- Encryption
 |
 +-- Master Key
 |
 +-- Keystore
```

dan:

```text
Oracle Key Vault
 |
 +-- Centralized Key Management
 |
 +-- Endpoint Management
 |
 +-- Virtual Wallet
 |
 +-- Key Lifecycle
```

Oracle Key Vault digunakan untuk mengelola security objects seperti encryption keys dan credentials secara terpusat dan memungkinkan database endpoint menggunakan key management terpusat.

---

# LAB 1 — Review TDE dari Day 2

Karena Day 3 melanjutkan Day 2, kita mulai dengan memastikan TDE masih berfungsi.

Login:

```bash
su - oracle
```

Set environment:

```bash
export ORACLE_SID=oradb
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/db_1
export ORACLE_BASE=/u01/app/oracle
export PATH=$ORACLE_HOME/bin:$PATH
```

Connect:

```bash
sqlplus sys/oracle@localhost:1521/pdb1.localdomain as sysdba
```

---

## Check wallet

```sql
SELECT
    CON_ID,
    STATUS,
    WALLET_TYPE,
    WALLET_ORDER
FROM V$ENCRYPTION_WALLET
ORDER BY CON_ID;
```

Expected:

```text
CON_ID STATUS  WALLET_TYPE
------ ------- -----------
1      OPEN    PASSWORD
3      OPEN    PASSWORD
```

Jika Day 2 menggunakan konfigurasi berbeda, output dapat berbeda.

---

# LAB 2 — Review TDE Master Keys

```sql
SELECT
    CON_ID,
    KEY_ID,
    CREATION_TIME,
    ACTIVATION_TIME,
    TAG
FROM V$ENCRYPTION_KEYS
ORDER BY CON_ID, CREATION_TIME;
```

Expected:

```text
CON_ID KEY_ID                  CREATION_TIME       TAG
------ ----------------------  ------------------  --------------------
1      ...                     ...                 DAY2_INITIAL_KEY
3      ...                     ...                 DAY2_INITIAL_KEY
3      ...                     ...                 DAY2_KEY_ROTATION
```

---

# LAB 3 — Review Encrypted Objects

```sql
SELECT
    TABLESPACE_NAME,
    ENCRYPTED
FROM DBA_TABLESPACES
ORDER BY TABLESPACE_NAME;
```

Expected:

```text
TABLESPACE_NAME  ENCRYPTED
---------------- ---------
SYSTEM           NO
SYSAUX           NO
TEMP             NO
TS_SECURE        YES
USERS            NO
```

Kemudian:

```sql
SELECT
    OWNER,
    TABLE_NAME,
    COLUMN_NAME,
    ENCRYPTION_ALG
FROM DBA_ENCRYPTED_COLUMNS
ORDER BY OWNER, TABLE_NAME, COLUMN_NAME;
```

Expected:

```text
OWNER      TABLE_NAME       COLUMN_NAME  ENCRYPTION_ALG
---------- ---------------  ------------ --------------
TDE_OWNER  CUSTOMER_SECURE  CREDIT_CARD  AES 256
```

---

# LAB 4 — Mengapa Oracle Key Vault?

Bayangkan perusahaan memiliki:

```text
DB01
DB02
DB03
DB04
DB05
```

Tanpa centralized key management:

```text
DB01 → Wallet 01
DB02 → Wallet 02
DB03 → Wallet 03
DB04 → Wallet 04
DB05 → Wallet 05
```

Masalah:

* Banyak wallet.
* Banyak key.
* Key rotation lebih kompleks.
* Backup wallet harus dikelola.
* Separation of Duties lebih sulit.

Dengan OKV:

```text
             +----------------+
             | Oracle Key Vault|
             +--------+-------+
                      |
          +-----------+-----------+
          |           |           |
          v           v           v
        DB01        DB02        DB03
       Endpoint    Endpoint    Endpoint
```

Oracle Key Vault menjadi centralized key management layer.

---

# LAB 5 — OKV Terminology

Peserta harus memahami istilah berikut.

### Endpoint

Database/server/client yang menggunakan OKV.

```text
Oracle DB
    |
    +---- Endpoint
```

### Virtual Wallet

Container/logical collection untuk security objects yang dikelola OKV.

```text
Virtual Wallet
 |
 +-- TDE Key
 +-- Key
 +-- Certificate
 +-- Secret
```

### Security Object

Object yang dikelola oleh OKV.

Contohnya:

```text
Encryption Key
Certificate
Secret
Credential
```

### User

Account yang melakukan administrasi OKV.

### Role

Hak akses administrator.

---

# LAB 6 — Kenapa Environment Anda Belum Bisa Full OKV?

Environment Anda saat ini:

```text
Oracle Linux 7.8
        |
        +-- Oracle Database 19.8
               |
               +-- ORADB
                    |
                    +-- PDB1
```

Belum ada:

```text
Oracle Key Vault Server
```

Jadi command seperti:

```bash
okv admin
```

atau:

```bash
okvutil
```

**tidak boleh diasumsikan tersedia**.

Ini berbeda dengan TDE wallet yang memang berada di server database.

---

# LAB 7 — Architecture Design Exercise

Gambarkan architecture berikut:

```text
                     Enterprise
                         |
                         v
                +------------------+
                | Oracle Key Vault |
                +--------+---------+
                         |
             +-----------+-----------+
             |           |           |
             v           v           v
          ORADB01     ORADB02     ORADB03
            |           |           |
           TDE         TDE         TDE
            |           |           |
         Database    Database    Database
```

Diskusi:

**Apa yang berubah?**

Sebelumnya:

```text
DB
 |
 +-- Local Wallet
```

Dengan OKV:

```text
DB
 |
 +-- OKV Endpoint
       |
       +-- Centralized Key Management
```

---

# LAB 8 — Wallet vs OKV Virtual Wallet

| Local Oracle Wallet          | OKV Virtual Wallet         |
| ---------------------------- | -------------------------- |
| Local database/server        | Centralized                |
| File-based keystore          | Server-managed             |
| Key management per DB        | Centralized management     |
| Backup wallet harus dikelola | Centralized administration |
| Cocok untuk standalone       | Cocok untuk enterprise     |

**Catatan:** Virtual Wallet bukan berarti file `ewallet.p12` biasa. Ini adalah logical container pada OKV.

---

# LAB 9 — OKV Roles Exercise

Konsep role yang perlu dipahami:

```text
OKV Administrator
        |
        +-- User Management
        +-- Endpoint Management
        +-- Security Object Management
```

Security architecture:

```text
Security Admin
      |
      +---- OKV

DBA
 |
 +---- Oracle Database
```

Idealnya DBA tidak otomatis mempunyai seluruh hak administrasi key-management enterprise.

Ini merupakan implementasi **Separation of Duties**.

---

# LAB 10 — OKV Endpoint Lifecycle

Peserta harus memahami lifecycle:

```text
1. Register Endpoint
        |
        v
2. Enroll Endpoint
        |
        v
3. Assign Virtual Wallet
        |
        v
4. Provision Keys
        |
        v
5. Database uses Key
        |
        v
6. Monitor / Rotate / Revoke
```

---

# LAB 12 — Prepare Sensitive Data Schema

Login:

```bash
sqlplus sys/oracle@localhost:1521/pdb1.localdomain as sysdba
```

Pastikan:

```sql
SHOW CON_NAME;
```

Expected:

```text
CON_NAME
------------------------------
PDB1
```

---

# LAB 13 — Create Discovery Schema

```sql
CREATE USER discovery_owner
IDENTIFIED BY "Discovery#2026";
```

Expected:

```text
User created.
```

Grant:

```sql
GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW
TO discovery_owner;
```

```sql
ALTER USER discovery_owner QUOTA 100M ON users;
```

Tanpa quota, insert pertama dapat gagal dengan `ORA-01950` walaupun perintah
`CREATE TABLE` sudah berhasil.

Expected:

```text
Grant succeeded.
```

---

# LAB 14 — Create Customer Table

Connect:

```sql
CONNECT discovery_owner/"Discovery#2026"@localhost:1521/pdb1.localdomain
```

Create:

```sql
CREATE TABLE customer (
    customer_id NUMBER PRIMARY KEY,
    customer_name VARCHAR2(100),
    email_address VARCHAR2(200),
    phone_number VARCHAR2(30),
    credit_card_number VARCHAR2(30),
    social_security_number VARCHAR2(30),
    date_of_birth DATE,
    salary NUMBER(15,2)
);
```

Expected:

```text
Table created.
```

---

# LAB 15 — Insert Sensitive Data

```sql
INSERT INTO customer
VALUES (
    1,
    'JOHN DOE',
    'john.doe@example.com',
    '+628123456789',
    '4111111111111111',
    '123-45-6789',
    DATE '1980-01-15',
    15000000
);
```

```sql
INSERT INTO customer
VALUES (
    2,
    'JANE DOE',
    'jane.doe@example.com',
    '+628987654321',
    '5555555555554444',
    '987-65-4321',
    DATE '1985-06-20',
    17500000
);
```

```sql
INSERT INTO customer
VALUES (
    3,
    'ALICE',
    'alice@example.com',
    '+628111222333',
    '378282246310005',
    '111-22-3333',
    DATE '1990-11-10',
    22000000
);
```

Commit:

```sql
COMMIT;
```

Expected:

```text
Commit complete.
```

---

# LAB 16 — Verify Sensitive Data

```sql
SELECT
    customer_id,
    customer_name,
    email_address,
    phone_number,
    credit_card_number,
    social_security_number
FROM customer
ORDER BY customer_id;
```

Expected:

```text
CUSTOMER_ID CUSTOMER_NAME EMAIL_ADDRESS
----------- ------------- -------------------------
1           JOHN DOE      john.doe@example.com
2           JANE DOE      jane.doe@example.com
3           ALICE         alice@example.com

PHONE_NUMBER       CREDIT_CARD_NUMBER
------------------ ------------------
+628123456789      4111111111111111
+628987654321      5555555555554444
+628111222333      378282246310005

SOCIAL_SECURITY_NUMBER
---------------------
123-45-6789
987-65-4321
111-22-3333
```

---

# LAB 17 — Create Additional Tables

Untuk menunjukkan relationship discovery, buat:

```sql
CREATE TABLE customer_account (
    account_id NUMBER PRIMARY KEY,
    customer_id NUMBER NOT NULL,
    account_number VARCHAR2(30),
    account_type VARCHAR2(30),
    balance NUMBER(15,2),
    CONSTRAINT fk_customer
        FOREIGN KEY (customer_id)
        REFERENCES customer(customer_id)
);
```

Expected:

```text
Table created.
```

---

# LAB 18 — Insert Account Data

```sql
INSERT INTO customer_account
VALUES (
    1001,
    1,
    '1234567890123456',
    'SAVINGS',
    25000000
);
```

```sql
INSERT INTO customer_account
VALUES (
    1002,
    1,
    '1234567890123457',
    'CURRENT',
    15000000
);
```

```sql
INSERT INTO customer_account
VALUES (
    1003,
    2,
    '1234567890123458',
    'SAVINGS',
    35000000
);
```

```sql
COMMIT;
```

---

# LAB 19 — Verify Referential Relationship

```sql
SELECT
    c.customer_id,
    c.customer_name,
    a.account_id,
    a.account_number,
    a.balance
FROM customer c
JOIN customer_account a
    ON a.customer_id = c.customer_id
ORDER BY c.customer_id, a.account_id;
```

Expected:

```text
CUSTOMER_ID CUSTOMER_NAME ACCOUNT_ID ACCOUNT_NUMBER      BALANCE
----------- ------------- ---------- ------------------ --------
1           JOHN DOE      1001       1234567890123456   25000000
1           JOHN DOE      1002       1234567890123457   15000000
2           JANE DOE      1003       1234567890123458   35000000
```

---

# LAB 20 — Manual Sensitive Data Discovery

Sebelum menggunakan ADM, kita lakukan discovery secara manual.

## Find columns berdasarkan nama

```sql
SELECT
    owner,
    table_name,
    column_name,
    data_type
FROM dba_tab_columns
WHERE owner='DISCOVERY_OWNER'
AND (
       UPPER(column_name) LIKE '%CARD%'
    OR UPPER(column_name) LIKE '%EMAIL%'
    OR UPPER(column_name) LIKE '%PHONE%'
    OR UPPER(column_name) LIKE '%SSN%'
    OR UPPER(column_name) LIKE '%SALARY%'
    OR UPPER(column_name) LIKE '%DOB%'
)
ORDER BY table_name, column_id;
```

Expected:

```text
OWNER            TABLE_NAME       COLUMN_NAME
---------------- ---------------- ------------------------
DISCOVERY_OWNER  CUSTOMER         EMAIL_ADDRESS
DISCOVERY_OWNER  CUSTOMER         PHONE_NUMBER
DISCOVERY_OWNER  CUSTOMER         CREDIT_CARD_NUMBER
DISCOVERY_OWNER  CUSTOMER         SOCIAL_SECURITY_NUMBER
DISCOVERY_OWNER  CUSTOMER         DATE_OF_BIRTH
DISCOVERY_OWNER  CUSTOMER         SALARY
```

---

# LAB 21 — Discover Account Number

```sql
SELECT
    owner,
    table_name,
    column_name,
    data_type
FROM dba_tab_columns
WHERE owner='DISCOVERY_OWNER'
AND UPPER(column_name) LIKE '%ACCOUNT%';
```

Expected:

```text
OWNER            TABLE_NAME        COLUMN_NAME
---------------- ----------------- ----------------
DISCOVERY_OWNER  CUSTOMER_ACCOUNT  ACCOUNT_ID
DISCOVERY_OWNER  CUSTOMER_ACCOUNT  ACCOUNT_NUMBER
```

---

# LAB 22 — Sensitive Data Classification

Peserta mengklasifikasikan:

| Column                 | Classification      |
| ---------------------- | ------------------- |
| CUSTOMER_NAME          | PII                 |
| EMAIL_ADDRESS          | PII                 |
| PHONE_NUMBER           | PII                 |
| CREDIT_CARD_NUMBER     | PCI / Sensitive     |
| SOCIAL_SECURITY_NUMBER | Highly Sensitive    |
| DATE_OF_BIRTH          | PII                 |
| SALARY                 | Confidential        |
| ACCOUNT_NUMBER         | Financial Sensitive |
| BALANCE                | Financial Sensitive |

---

# LAB 23 — Why Column Name Alone Is Not Enough

Buat column:

```sql
ALTER TABLE customer
ADD notes VARCHAR2(200);
```

Insert:

```sql
UPDATE customer
SET notes='Credit card ending 1111'
WHERE customer_id=1;

COMMIT;
```

Sekarang:

```sql
SELECT
    column_name,
    data_type
FROM user_tab_columns
WHERE table_name='CUSTOMER'
ORDER BY column_id;
```

Perhatikan:

```text
NOTES
```

nama column tidak menunjukkan:

```text
CREDIT_CARD
```

tetapi isi data mengandung sensitive information.

Inilah mengapa automated discovery menggunakan kombinasi **column names, data patterns, dan metadata**. ([Oracle Docs][1])

---

# LAB 24 — Data Pattern Discovery

Untuk training, kita dapat melakukan simulasi pattern discovery menggunakan SQL.

## Cari kemungkinan credit-card number

```sql
SELECT
    customer_id,
    credit_card_number
FROM customer
WHERE REGEXP_LIKE(
    credit_card_number,
    '^[0-9]{15,16}$'
);
```

Expected:

```text
CUSTOMER_ID CREDIT_CARD_NUMBER
----------- ------------------
1           4111111111111111
2           5555555555554444
3           378282246310005
```

---

# LAB 25 — Discover SSN Pattern

```sql
SELECT
    customer_id,
    social_security_number
FROM customer
WHERE REGEXP_LIKE(
    social_security_number,
    '^[0-9]{3}-[0-9]{2}-[0-9]{4}$'
);
```

Expected:

```text
CUSTOMER_ID SOCIAL_SECURITY_NUMBER
----------- ---------------------
1           123-45-6789
2           987-65-4321
3           111-22-3333
```

---

# LAB 26 — Discover Email Pattern

```sql
SELECT
    customer_id,
    email_address
FROM customer
WHERE REGEXP_LIKE(
    email_address,
    '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
);
```

Expected:

```text
CUSTOMER_ID EMAIL_ADDRESS
----------- -------------------------
1           john.doe@example.com
2           jane.doe@example.com
3           alice@example.com
```

---

# LAB 27 — Discover Phone Pattern

```sql
SELECT
    customer_id,
    phone_number
FROM customer
WHERE REGEXP_LIKE(
    phone_number,
    '^\+?[0-9]{10,15}$'
);
```

Expected:

```text
CUSTOMER_ID PHONE_NUMBER
----------- --------------
1           +628123456789
2           +628987654321
3           +628111222333
```

---

# LAB 28 — Build Discovery Report

Jalankan:

```sql
SELECT
    table_name,
    column_name,
    data_type,
    data_length
FROM user_tab_columns
WHERE table_name IN
(
    'CUSTOMER',
    'CUSTOMER_ACCOUNT'
)
ORDER BY table_name, column_id;
```

Peserta kemudian membuat report:

```text
TABLE               COLUMN                  SENSITIVE
------------------  ----------------------  ---------
CUSTOMER            CUSTOMER_NAME           YES
CUSTOMER            EMAIL_ADDRESS           YES
CUSTOMER            PHONE_NUMBER            YES
CUSTOMER            CREDIT_CARD_NUMBER      YES
CUSTOMER            SOCIAL_SECURITY_NUMBER  YES
CUSTOMER            DATE_OF_BIRTH           YES
CUSTOMER            SALARY                  YES
CUSTOMER_ACCOUNT    ACCOUNT_NUMBER          YES
CUSTOMER_ACCOUNT    BALANCE                 YES
```

---

# BAGIAN C — Application Data Model

## LAB 29 — Pahami ADM

Secara konseptual:

```text
Application Data Model
        |
        +-- Applications
        |
        +-- Tables
        |
        +-- Relationships
        |
        +-- Sensitive Columns
        |
        +-- Sensitive Column Types
```

Oracle menjelaskan bahwa ADM menyimpan application metadata, relationships, dan sensitive data elements. ([Oracle Docs][2])

---

# LAB 30 — ADM Architecture

Oracle Enterprise Manager:

```text
+--------------------------------+
| Enterprise Manager Cloud      |
| Control                       |
|                               |
| Application Data Model        |
+---------------+---------------+
                |
                v
       Oracle Database Target
                |
        +-------+-------+
        |               |
        v               v
     CUSTOMER    CUSTOMER_ACCOUNT
        |               |
        +-------+-------+
                |
                v
        Sensitive Columns
```

ADM kemudian menjadi basis untuk aktivitas Data Masking dan Data Subsetting. Oracle mendokumentasikan workflow tersebut sebagai **ADM → masking definition → subsetting definition**. ([Oracle Docs][1])

---

# LAB 31 — Cloud Control Requirement

Pada environment penuh, ADM dilakukan melalui:

```text
Enterprise
   ↓
Quality
   ↓
Application Data Modeling
```

atau menu yang setara sesuai versi Cloud Control.

Oracle menyatakan prosedur Data Masking/ADM menggunakan **Oracle Enterprise Manager Cloud Control 12.1 atau lebih tinggi**. ([Oracle Docs][3])

---

# LAB 32 — Create ADM Conceptually

Untuk database kita:

```text
ADM Name:
DAY3_CUSTOMER_ADM
```

Application:

```text
CUSTOMER_APPLICATION
```

Tables:

```text
DISCOVERY_OWNER.CUSTOMER
DISCOVERY_OWNER.CUSTOMER_ACCOUNT
```

---

# LAB 33 — Sensitive Column Mapping

Dalam ADM, tandai:

### CUSTOMER

```text
EMAIL_ADDRESS
PHONE_NUMBER
CREDIT_CARD_NUMBER
SOCIAL_SECURITY_NUMBER
DATE_OF_BIRTH
SALARY
```

### CUSTOMER_ACCOUNT

```text
ACCOUNT_NUMBER
BALANCE
```

---

# LAB 34 — Sensitive Column Types

Oracle menyediakan built-in sensitive column types, termasuk:

```text
CREDIT_CARD_NUMBER
SOCIAL_SECURITY_NUMBER
PHONE_NUMBER
```

dan berbagai tipe lain. Custom sensitive column types dapat dibuat berdasarkan regular expression. ([Oracle Docs][1])

Mapping:

```text
CREDIT_CARD_NUMBER
        ↓
CUSTOMER.CREDIT_CARD_NUMBER

SOCIAL_SECURITY_NUMBER
        ↓
CUSTOMER.SOCIAL_SECURITY_NUMBER

PHONE_NUMBER
        ↓
CUSTOMER.PHONE_NUMBER
```

---

# LAB 35 — Custom Sensitive Type

Contoh konsep custom type:

```text
INDONESIA_PHONE_NUMBER
```

Pattern:

```regex
^\+62[0-9]{8,13}$
```

Data:

```text
+628123456789
+628987654321
```

SQL test:

```sql
SELECT
    customer_id,
    phone_number
FROM customer
WHERE REGEXP_LIKE(
    phone_number,
    '^\+62[0-9]{8,13}$'
);
```

Expected:

```text
CUSTOMER_ID PHONE_NUMBER
----------- --------------
1           +628123456789
2           +628987654321
3           +628111222333
```

Ini adalah contoh bagaimana custom sensitive column type dapat dibangun berdasarkan regular expression. Oracle mendokumentasikan custom sensitive types sebagai salah satu kemampuan ADM. ([Oracle Docs][1])

---

# LAB 36 — Referential Relationship

Kita sudah membuat:

```text
CUSTOMER
   |
   | CUSTOMER_ID
   |
   +------< CUSTOMER_ACCOUNT
```

Verify constraint:

```sql
SELECT
    a.constraint_name,
    a.table_name,
    a.constraint_type,
    b.table_name AS referenced_table
FROM user_constraints a
LEFT JOIN user_constraints b
    ON a.r_constraint_name = b.constraint_name
WHERE a.table_name='CUSTOMER_ACCOUNT'
AND a.constraint_type='R';
```

Expected:

```text
CONSTRAINT_NAME  TABLE_NAME        CONSTRAINT_TYPE  REFERENCED_TABLE
---------------  ----------------  ---------------  ----------------
FK_CUSTOMER      CUSTOMER_ACCOUNT  R                CUSTOMER
```

---

# LAB 37 — Why Relationship Discovery Matters

Misalnya:

```text
CUSTOMER
ID = 1
```

memiliki:

```text
CUSTOMER_ACCOUNT
CUSTOMER_ID = 1
```

Jika customer dimasking tetapi account relationship rusak:

```text
CUSTOMER
John → XZQ123

ACCOUNT
customer_id = 1
```

aplikasi bisa rusak.

Karena itu ADM tidak hanya menemukan sensitive columns tetapi juga membantu memodelkan parent-child relationships. ([Oracle Docs][1])

---

# LAB 38 — Simulate Sensitive Data Inventory

Buat inventory:

```text
Application: CUSTOMER_APPLICATION

TABLE: CUSTOMER

+ CUSTOMER_NAME
  Type: PII

+ EMAIL_ADDRESS
  Type: EMAIL

+ PHONE_NUMBER
  Type: PHONE

+ CREDIT_CARD_NUMBER
  Type: CREDIT_CARD

+ SOCIAL_SECURITY_NUMBER
  Type: SOCIAL_SECURITY

+ DATE_OF_BIRTH
  Type: DATE_OF_BIRTH

+ SALARY
  Type: FINANCIAL

TABLE: CUSTOMER_ACCOUNT

+ ACCOUNT_NUMBER
  Type: FINANCIAL_ACCOUNT

+ BALANCE
  Type: FINANCIAL
```

---

# LAB 39 — Sensitive Data Risk Assessment

Buat klasifikasi:

| Data           | Risk     | Reason               |
| -------------- | -------- | -------------------- |
| Customer Name  | Medium   | PII                  |
| Email          | Medium   | Contact information  |
| Phone          | Medium   | Contact information  |
| Credit Card    | Critical | Payment information  |
| SSN            | Critical | Identity information |
| DOB            | High     | PII                  |
| Salary         | High     | Financial            |
| Account Number | Critical | Financial            |
| Balance        | High     | Financial            |

---

# LAB 40 — ADM → Masking Flow

Ini sangat penting untuk Day 3 → Day 4.

```text
Production DB
      |
      v
Application Data Model
      |
      v
Sensitive Data Discovery
      |
      v
Sensitive Columns
      |
      v
Masking Definition
      |
      v
Masking Format
      |
      v
Non-Production DB
```

Oracle mendokumentasikan ADM sebagai tahap awal sebelum Data Masking Definition dibuat. ([Oracle Docs][3])

---

# LAB 41 — ADM → Subsetting Flow

```text
Production
    |
    v
ADM
    |
    +---- Sensitive Data
    |
    +---- Relationships
    |
    v
Subset Definition
    |
    v
Reduced Dataset
```

Tujuannya:

```text
100 GB Production
       |
       v
20 GB Test
```

tetapi tetap mempertahankan data/relationship yang diperlukan.

Oracle menjelaskan bahwa Data Subsetting dapat mengurangi storage test/development sekaligus menjaga referential integrity dan dapat dikombinasikan dengan masking. ([Oracle Docs][4])

---

# LAB 42 — End-to-End Sensitive Data Discovery Exercise

Peserta diberikan database:

```text
DISCOVERY_OWNER
```

dan diminta menemukan semua sensitive information.

### Step 1

Find tables:

```sql
SELECT
    table_name
FROM user_tables
ORDER BY table_name;
```

Expected:

```text
CUSTOMER
CUSTOMER_ACCOUNT
```

### Step 2

Find candidate columns:

```sql
SELECT
    table_name,
    column_name
FROM user_tab_columns
WHERE REGEXP_LIKE(
    UPPER(column_name),
    'CARD|EMAIL|PHONE|SSN|SALARY|ACCOUNT|BALANCE|DOB|BIRTH'
)
ORDER BY table_name, column_id;
```

Expected:

```text
CUSTOMER          EMAIL_ADDRESS
CUSTOMER          PHONE_NUMBER
CUSTOMER          CREDIT_CARD_NUMBER
CUSTOMER          SOCIAL_SECURITY_NUMBER
CUSTOMER          DATE_OF_BIRTH
CUSTOMER          SALARY

CUSTOMER_ACCOUNT  ACCOUNT_NUMBER
CUSTOMER_ACCOUNT  BALANCE
```

### Step 3

Validate actual data.

Credit card:

```sql
SELECT
    customer_id,
    credit_card_number
FROM customer
WHERE REGEXP_LIKE(
    credit_card_number,
    '^[0-9]{15,16}$'
);
```

SSN:

```sql
SELECT
    customer_id,
    social_security_number
FROM customer
WHERE REGEXP_LIKE(
    social_security_number,
    '^[0-9]{3}-[0-9]{2}-[0-9]{4}$'
);
```

Email:

```sql
SELECT
    customer_id,
    email_address
FROM customer
WHERE REGEXP_LIKE(
    email_address,
    '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
);
```

---

# LAB 43 — Create Sensitive Data Discovery Report

Output yang diharapkan:

```text
=========================================================
SENSITIVE DATA DISCOVERY REPORT
=========================================================

APPLICATION
CUSTOMER_APPLICATION

---------------------------------------------------------
TABLE: DISCOVERY_OWNER.CUSTOMER
---------------------------------------------------------

CUSTOMER_NAME
  Classification : PII
  Risk           : MEDIUM

EMAIL_ADDRESS
  Classification : PII
  Sensitive Type : EMAIL
  Risk           : MEDIUM

PHONE_NUMBER
  Classification : PII
  Sensitive Type : PHONE
  Risk           : MEDIUM

CREDIT_CARD_NUMBER
  Classification : PCI
  Sensitive Type : CREDIT_CARD_NUMBER
  Risk           : CRITICAL

SOCIAL_SECURITY_NUMBER
  Classification : Identity
  Sensitive Type : SOCIAL_SECURITY_NUMBER
  Risk           : CRITICAL

DATE_OF_BIRTH
  Classification : PII
  Risk           : HIGH

SALARY
  Classification : Financial
  Risk           : HIGH

---------------------------------------------------------
TABLE: DISCOVERY_OWNER.CUSTOMER_ACCOUNT
---------------------------------------------------------

ACCOUNT_NUMBER
  Classification : Financial
  Risk           : CRITICAL

BALANCE
  Classification : Financial
  Risk           : HIGH
```

---

# LAB 44 — Important Licensing Boundary

Ini sangat penting untuk trainer.

**Application Data Modeling, Data Masking dan Data Subsetting bukan sekadar fitur SQL database biasa.** Oracle mendokumentasikannya sebagai bagian dari **Oracle Data Masking and Subsetting Pack**, dan penggunaan fitur tersebut membutuhkan license yang sesuai. ([Oracle Docs][3])

Jadi:

```text
SQL REGEXP_LIKE
```

yang kita gunakan di lab hanyalah:

> **simulation/manual discovery**

bukan pengganti ADM.

ADM sebenarnya menyediakan:

```text
Automated Discovery
+
Sensitive Types
+
Relationships
+
Application Data Model
```

melalui Enterprise Manager.

---

# LAB 45 — What the Real ADM Job Does

Secara konseptual:

```text
                 ADM
                  |
                  v
        +-------------------+
        | Sensitive Types   |
        +---------+---------+
                  |
                  v
        Scan database columns
                  |
        +---------+---------+
        |                   |
        v                   v
   Column Pattern      Data Pattern
        |                   |
        +---------+---------+
                  |
                  v
          Sensitive Column
                  |
                  v
       Parent/Child Relations
```

Oracle menyatakan automated discovery menggunakan sensitive column types dan melakukan sampling data untuk menemukan informasi sensitif. ([Oracle Docs][1])

---

# LAB 46 — Day 3 Integration with Day 2

Sekarang kita gabungkan:

```text
DAY 2
TDE
 |
 +-- CREDIT_CARD_NUMBER encrypted
```

dengan:

```text
DAY 3
ADM
 |
 +-- CREDIT_CARD_NUMBER discovered
```

Architecture:

```text
             CUSTOMER
                 |
        +--------+--------+
        |                 |
        v                 v
    Discovery            TDE
        |                 |
        v                 v
Sensitive Column      Encrypted
```

Ini menunjukkan bahwa:

> **Discovery dan encryption menyelesaikan problem yang berbeda.**

TDE:

```text
Protect data at rest
```

ADM:

```text
Find and classify sensitive data
```

---

# LAB 47 — Security Gap Analysis

Peserta harus menjawab:

### Scenario A

Column:

```text
CREDIT_CARD_NUMBER
```

tidak encrypted.

Risk?

```text
HIGH / CRITICAL
```

### Scenario B

Column encrypted tetapi developer menerima production dump tanpa masking.

Risk?

```text
HIGH
```

Kenapa?

Karena user di non-production masih dapat memperoleh sensitive information jika dump/import tersebut tetap berisi plaintext yang dapat didecrypt oleh environment target.

### Scenario C

Data sudah masked tetapi tidak ada relationship model.

Risk:

```text
Application integrity risk
```

---

# LAB 48 — Day 3 Architecture

Pada akhir training, peserta harus memahami:

```text
                    Production
                       |
                       v
              +------------------+
              | Application Data |
              | Model            |
              +--------+---------+
                       |
          +------------+-------------+
          |                          |
          v                          v
 Sensitive Discovery          Relationships
          |
          v
 +----------------+
 | Sensitive Data |
 +-------+--------+
         |
         +----------------+
         |                |
         v                v
      Masking          Subsetting
         |                |
         +-------+--------+
                 |
                 v
          Non-Production
```

Dan untuk encryption:

```text
              Oracle Database
                    |
                    v
                   TDE
                    |
              +-----+-----+
              |           |
              v           v
          Local Wallet   OKV
                         |
                         v
                 Centralized Keys
```

---

# LAB 49 — Final Practical Test Day 3

Peserta diberikan database berikut:

```text
DISCOVERY_OWNER
```

Task:

### 1. Identify all tables

```sql
SELECT table_name
FROM user_tables
ORDER BY table_name;
```

### 2. Identify candidate sensitive columns

```sql
SELECT
    table_name,
    column_name
FROM user_tab_columns
WHERE REGEXP_LIKE(
    UPPER(column_name),
    'CARD|EMAIL|PHONE|SSN|SALARY|ACCOUNT|BALANCE|DOB|BIRTH'
)
ORDER BY table_name, column_id;
```

### 3. Validate credit card data

```sql
SELECT
    customer_id,
    credit_card_number
FROM customer
WHERE REGEXP_LIKE(
    credit_card_number,
    '^[0-9]{15,16}$'
);
```

### 4. Validate SSN

```sql
SELECT
    customer_id,
    social_security_number
FROM customer
WHERE REGEXP_LIKE(
    social_security_number,
    '^[0-9]{3}-[0-9]{2}-[0-9]{4}$'
);
```

### 5. Identify relationship

```sql
SELECT
    a.constraint_name,
    a.table_name,
    b.table_name AS referenced_table
FROM user_constraints a
LEFT JOIN user_constraints b
    ON a.r_constraint_name=b.constraint_name
WHERE a.constraint_type='R';
```

### 6. Produce final classification

Peserta harus menghasilkan:

```text
CUSTOMER
 |
 +-- CUSTOMER_NAME             PII
 +-- EMAIL_ADDRESS             PII
 +-- PHONE_NUMBER              PII
 +-- CREDIT_CARD_NUMBER        PCI / CRITICAL
 +-- SOCIAL_SECURITY_NUMBER    IDENTITY / CRITICAL
 +-- DATE_OF_BIRTH             PII
 +-- SALARY                    FINANCIAL

CUSTOMER_ACCOUNT
 |
 +-- ACCOUNT_NUMBER            FINANCIAL / CRITICAL
 +-- BALANCE                   FINANCIAL
```

### 7. Explain architecture

Peserta harus dapat menjelaskan:

```text
TDE
 ↓
Protect data at rest

ADM
 ↓
Discover sensitive data

OKV
 ↓
Centralize key management

Masking
 ↓
Protect non-production

Subsetting
 ↓
Reduce data footprint
```

---


---



<!-- ============================================================ -->
<!-- SOURCE: preventive_day4.md -->
<!-- ============================================================ -->

<a id="day-4"></a>

# DAY 4 — Data Masking, Subsetting & Data Redaction

> **Sumber file:** `preventive_day4.md`

# DAY 4 — DATA MASKING, SUBSETTING, DATA REDACTION

## Learning Objectives

Setelah Day 4, peserta mampu:

* Membedakan data asli, static masking, redaction, dan TDE.
* Melakukan masking manual pada customer dan account tanpa mengubah source.
* Memahami deterministic versus random masking serta keterbatasan transformasi sederhana.
* Membuat subset dengan primary key dan foreign key yang tetap konsisten.
* Menguji full, partial, regular expression, dan conditional redaction.
* Membuktikan data terenkripsi gagal diakses saat wallet tertutup, lalu memulihkan akses menggunakan wallet existing.

* Membuktikan pengaruh expdp/impdp terhadap masking, subsetting, redaction, GRANT, dan constraint.

## Cara Mengikuti Lab

Naskah ini diuji pada VM `192.168.56.22` tanggal **10 September 2026**, menggunakan Oracle Database **19c Enterprise Edition 19.8.0.0.0**, SID `oradb`, PDB `PDB1`, dan service `pdb1.localdomain`.

Ikuti command **satu per satu**. Setiap command disertai contoh output dari pengujian. Blok `BEGIN ... END; /` adalah satu pemanggilan PL/SQL; masukkan seluruh blok tersebut sebelum menjalankan `/`. Penjelasan konsep tidak memerlukan command tambahan.

Contoh hasil memakai data sintetis pada prasyarat Lab 2A. Output acak, metadata environment, dan hasil pada database yang sudah pernah dipakai dapat berbeda. Command pengaturan tampilan tidak menghasilkan teks jika berhasil. Query panjang dibagi menjadi beberapa tampilan agar mudah dibaca.

Untuk mengikuti seluruh alur dari awal, nama objek lab harus belum digunakan. Setelah pengujian ini, objek hasil lab masih ada di VM untuk diperiksa. Jika peserta menggunakan VM yang sama, siapkan kondisi awal terlebih dahulu bersama instruktur; jangan menjalankan ulang CREATE atau transformasi salary/balance di atas hasil latihan sebelumnya.

---

# BAGIAN A — DATA MASKING

## LAB 1 — Login Ke SQLPLUS

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA
```

---

## LAB 2 — Verify PDB dan Rapikan SQL*Plus

Pengaturan tampilan berikut berlaku selama sesi SQL*Plus ini. Jika membuka SQL*Plus baru, ulangi pengaturan ini. `SET` dan `COLUMN` tidak mencetak pesan ketika berhasil.

Hubungkan SQL*Plus sebagai SYS ke PDB lab:

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA
```

Output: tidak ada pesan pada mode `-s` jika koneksi berhasil. Query berikutnya dijalankan dengan koneksi ini.

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

## LAB 2 — Siapkan Sample Data

```sql
CREATE USER discovery_owner IDENTIFIED BY "Discovery#2026"
DEFAULT TABLESPACE users QUOTA 100M ON users;
```

Contoh output:



```sql
GRANT CREATE SESSION, CREATE TABLE TO discovery_owner;
```



```sql
CREATE TABLE discovery_owner.customer (
  customer_id NUMBER PRIMARY KEY,
  customer_name VARCHAR2(100),
  email_address VARCHAR2(200),
  phone_number VARCHAR2(30),
  credit_card_number VARCHAR2(30),
  social_security_number VARCHAR2(30),
  date_of_birth DATE,
  salary NUMBER(15,2)
);
```



```sql
CREATE TABLE discovery_owner.customer_account (
  account_id NUMBER PRIMARY KEY,
  customer_id NUMBER NOT NULL,
  account_number VARCHAR2(30),
  account_type VARCHAR2(30),
  balance NUMBER(15,2),
  CONSTRAINT discovery_fk_customer FOREIGN KEY (customer_id)
    REFERENCES discovery_owner.customer(customer_id)
);


INSERT INTO discovery_owner.customer (customer_id, customer_name, email_address, phone_number, credit_card_number, social_security_number, date_of_birth, salary)
VALUES (1, 'JOHN DOE', 'john.doe@example.com', '+628123456789', '4111111111111111', '123-45-6789', DATE '1980-01-15', 15000000);

INSERT INTO discovery_owner.customer (customer_id, customer_name, email_address, phone_number, credit_card_number, social_security_number, date_of_birth, salary)
VALUES (2, 'JANE DOE', 'jane.doe@example.com', '+628987654321', '5555555555554444', '987-65-4321', DATE '1985-06-20', 17500000);

INSERT INTO discovery_owner.customer (customer_id, customer_name, email_address, phone_number, credit_card_number, social_security_number, date_of_birth, salary)
VALUES (3, 'ALICE', 'alice@example.com', '+628111222333', '378282246310005', '111-22-3333', DATE '1990-11-10', 22000000);

INSERT INTO discovery_owner.customer_account
(account_id, customer_id, account_number, account_type, balance)
VALUES (1001, 1, '1234567890123456', 'SAVINGS', 25000000);

INSERT INTO discovery_owner.customer_account
(account_id, customer_id, account_number, account_type, balance)
VALUES (1002, 1, '1234567890123457', 'CURRENT', 15000000);

INSERT INTO discovery_owner.customer_account
(account_id, customer_id, account_number, account_type, balance)
VALUES (1003, 2, '1234567890123458', 'SAVINGS', 35000000);

COMMIT;
```



---

## LAB 3 — Review Source Data

Kita menggunakan schema `DISCOVERY_OWNER`. Query dipecah menjadi tiga tampilan agar tidak melebar dan setiap baris tetap mudah dibaca.

Cek hasilnya:

```sql
SELECT customer_id, customer_name, email_address
FROM discovery_owner.customer ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID CUSTOMER_NAME      EMAIL_ADDRESS
----------- ------------------ ----------------------------
          1 JOHN DOE           john.doe@example.com
          2 JANE DOE           jane.doe@example.com
          3 ALICE              alice@example.com

3 rows selected.
```

Cek hasilnya:

```sql
SELECT customer_id, phone_number, credit_card_number, social_security_number
FROM discovery_owner.customer ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID PHONE_NUMBER     CREDIT_CARD_NUMBER   SOCIAL_SECURITY_NUMBER
----------- ---------------- -------------------- ----------------------
          1 +628123456789    4111111111111111     123-45-6789
          2 +628987654321    5555555555554444     987-65-4321
          3 +628111222333    378282246310005      111-22-3333

3 rows selected.
```

Cek hasilnya:

```sql
SELECT customer_id, TO_CHAR(date_of_birth, 'YYYY-MM-DD') AS date_of_birth, salary
FROM discovery_owner.customer ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID DATE_OF_BIRTH          SALARY
----------- ------------- ---------------
          1 1980-01-15      15,000,000.00
          2 1985-06-20      17,500,000.00
          3 1990-11-10      22,000,000.00

3 rows selected.
```

---

## LAB 4 — Identify Sensitive Data

Perhatikan nama, email, telepon, kartu, SSN, tanggal lahir, salary, nomor account, dan balance. ID dipakai untuk hubungan antarbaris.

Cek hasilnya:

```sql
SELECT table_name, column_name, data_type FROM dba_tab_columns
WHERE owner='DISCOVERY_OWNER'
AND table_name IN ('CUSTOMER','CUSTOMER_ACCOUNT')
ORDER BY table_name, column_id;
```

Contoh output:

```text
TABLE_NAME               COLUMN_NAME               DATA_TYPE
------------------------ ------------------------- ------------
CUSTOMER                 CUSTOMER_ID               NUMBER
CUSTOMER                 CUSTOMER_NAME             VARCHAR2
CUSTOMER                 EMAIL_ADDRESS             VARCHAR2
CUSTOMER                 PHONE_NUMBER              VARCHAR2
CUSTOMER                 CREDIT_CARD_NUMBER        VARCHAR2
CUSTOMER                 SOCIAL_SECURITY_NUMBER    VARCHAR2
CUSTOMER                 DATE_OF_BIRTH             DATE
CUSTOMER                 SALARY                    NUMBER
CUSTOMER_ACCOUNT         ACCOUNT_ID                NUMBER
CUSTOMER_ACCOUNT         CUSTOMER_ID               NUMBER
CUSTOMER_ACCOUNT         ACCOUNT_NUMBER            VARCHAR2
CUSTOMER_ACCOUNT         ACCOUNT_TYPE              VARCHAR2
CUSTOMER_ACCOUNT         BALANCE                   NUMBER

13 rows selected.
```

---

## LAB 5 — Understand Why Masking Is Required

Bayangkan data production disalin ke development, test, lalu UAT. Tanpa masking, nomor kartu asli ikut tersebar ke semua environment. Dengan static masking, salinan berisi data pengganti sehingga peserta bisa menguji alur aplikasi.

Latihan ini memakai transformasi SQL manual pada data sintetis, bukan menjalankan Oracle Data Masking and Subsetting Pack. Mempertahankan empat digit terakhir dan tahun lahir masih menyisakan informasi; hasil latihan ini belum otomatis memenuhi standar anonimisasi production.

---

## LAB 6 — Create Masked Schema

Kita membuat salinan khusus lab agar source tetap utuh.

```sql
CREATE USER masked_owner IDENTIFIED BY "Masked#2026" DEFAULT TABLESPACE users;
```

Contoh output:



```sql
GRANT CREATE SESSION, CREATE TABLE TO masked_owner;
```



```sql
ALTER USER masked_owner QUOTA 100M ON users;
```

Contoh output:

```text
User altered.
```

---

## LAB 7 — Create Masked Customer Table

```sql
CREATE TABLE masked_owner.customer (
  customer_id NUMBER PRIMARY KEY,
  customer_name VARCHAR2(100),
  email_address VARCHAR2(200),
  phone_number VARCHAR2(30),
  credit_card_number VARCHAR2(30),
  social_security_number VARCHAR2(30),
  date_of_birth DATE,
  salary NUMBER(15,2)
);
```



---

## LAB 8 — Copy Data into Masking Environment

Tulis nama kolom secara eksplisit supaya penyalinan tidak bergantung pada urutan kolom `SELECT *`.

```sql
INSERT INTO masked_owner.customer (customer_id, customer_name, email_address, phone_number, credit_card_number, social_security_number, date_of_birth, salary)
SELECT customer_id, customer_name, email_address, phone_number, credit_card_number, social_security_number, date_of_birth, salary
FROM discovery_owner.customer;
```

Contoh output:

```text
3 rows created.
```

Simpan perubahan:

```sql
COMMIT;
```



Cek hasilnya:

```sql
SELECT COUNT(*) AS customer_count FROM masked_owner.customer;
```

Contoh output:

```text
CUSTOMER_COUNT
--------------
             3

1 row selected.
```

---

## LAB 9 — Baseline Before Masking

Cek hasilnya:

```sql
SELECT customer_id, customer_name, email_address
FROM masked_owner.customer ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID CUSTOMER_NAME      EMAIL_ADDRESS
----------- ------------------ ----------------------------
          1 JOHN DOE           john.doe@example.com
          2 JANE DOE           jane.doe@example.com
          3 ALICE              alice@example.com

3 rows selected.
```

Cek hasilnya:

```sql
SELECT customer_id, phone_number, credit_card_number, social_security_number
FROM masked_owner.customer ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID PHONE_NUMBER     CREDIT_CARD_NUMBER   SOCIAL_SECURITY_NUMBER
----------- ---------------- -------------------- ----------------------
          1 +628123456789    4111111111111111     123-45-6789
          2 +628987654321    5555555555554444     987-65-4321
          3 +628111222333    378282246310005      111-22-3333

3 rows selected.
```

Cek hasilnya:

```sql
SELECT customer_id, TO_CHAR(date_of_birth, 'YYYY-MM-DD') AS date_of_birth, salary
FROM masked_owner.customer ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID DATE_OF_BIRTH          SALARY
----------- ------------- ---------------
          1 1980-01-15      15,000,000.00
          2 1985-06-20      17,500,000.00
          3 1990-11-10      22,000,000.00

3 rows selected.
```

---

## LAB 10 — Mask Customer Name

Transformasi ini deterministik berdasarkan customer ID. Nama yang sama dengan ID berbeda akan menghasilkan label berbeda.

```sql
UPDATE masked_owner.customer
SET customer_name = 'CUSTOMER_' || customer_id;
```

Contoh output:

```text
3 rows updated.
```

Simpan perubahan:

```sql
COMMIT;
```



Cek hasilnya:

```sql
SELECT customer_id, customer_name
FROM masked_owner.customer ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID CUSTOMER_NAME
----------- ------------------
          1 CUSTOMER_1
          2 CUSTOMER_2
          3 CUSTOMER_3

3 rows selected.
```

---

## LAB 11 — Mask Email

Domain `.test` digunakan sebagai alamat contoh.

```sql
UPDATE masked_owner.customer
SET email_address = 'customer' || customer_id || '@example.test';
```

Contoh output:

```text
3 rows updated.
```

Simpan perubahan:

```sql
COMMIT;
```



Cek hasilnya:

```sql
SELECT customer_id, email_address
FROM masked_owner.customer ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID EMAIL_ADDRESS
----------- ----------------------------
          1 customer1@example.test
          2 customer2@example.test
          3 customer3@example.test

3 rows selected.
```

---

## LAB 12 — Mask Phone Number

Nomor pengganti ini hanya data latihan. Sesuaikan panjang dan aturan validasi aplikasi pada penerapan sebenarnya.

```sql
UPDATE masked_owner.customer
SET phone_number = '+620000000000' || customer_id;
```

Contoh output:

```text
3 rows updated.
```

Simpan perubahan:

```sql
COMMIT;
```



Cek hasilnya:

```sql
SELECT customer_id, phone_number
FROM masked_owner.customer ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID PHONE_NUMBER
----------- ----------------
          1 +6200000000001
          2 +6200000000002
          3 +6200000000003

3 rows selected.
```

---

## LAB 13 — Mask Credit Card

Kita pertahankan empat digit terakhir. Kartu ALICE berakhir dengan `0005`. Semua hasil dibuat 16 karakter untuk latihan ini; panjang asli kartu 15 digit berubah dan hasilnya tidak dijamin lolos validasi Luhn.

```sql
UPDATE masked_owner.customer
SET credit_card_number = '000000000000' || SUBSTR(credit_card_number,-4);
```

Contoh output:

```text
3 rows updated.
```

Simpan perubahan:

```sql
COMMIT;
```



Cek hasilnya:

```sql
SELECT customer_id, credit_card_number
FROM masked_owner.customer ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID CREDIT_CARD_NUMBER
----------- --------------------
          1 0000000000001111
          2 0000000000004444
          3 0000000000000005

3 rows selected.
```

---

## LAB 14 — Mask SSN

Empat digit terakhir masih terlihat. Ini masking sebagian pada stored data.

```sql
UPDATE masked_owner.customer
SET social_security_number = '000-00-' || SUBSTR(social_security_number,-4);
```

Contoh output:

```text
3 rows updated.
```

Simpan perubahan:

```sql
COMMIT;
```



Cek hasilnya:

```sql
SELECT customer_id, social_security_number
FROM masked_owner.customer ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID SOCIAL_SECURITY_NUMBER
----------- ----------------------
          1 000-00-6789
          2 000-00-4321
          3 000-00-3333

3 rows selected.
```

---

## LAB 15 — Mask Date of Birth

Tahun tetap, sedangkan tanggal dan bulan menjadi 15 Juli.

```sql
UPDATE masked_owner.customer
SET date_of_birth = ADD_MONTHS(TRUNC(date_of_birth,'YYYY'),6)+14;
```

Contoh output:

```text
3 rows updated.
```

Simpan perubahan:

```sql
COMMIT;
```



Cek hasilnya:

```sql
SELECT customer_id, TO_CHAR(date_of_birth,'YYYY-MM-DD') AS date_of_birth
FROM masked_owner.customer ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID DATE_OF_BIRTH
----------- -------------
          1 1980-07-15
          2 1985-07-15
          3 1990-07-15

3 rows selected.
```

---

## LAB 16 — Mask Salary

Angka tetap valid untuk latihan query. Faktor 0,70 mudah ditebak dan dapat dibalik secara perkiraan, sehingga bukan metode perlindungan salary untuk production.

```sql
UPDATE masked_owner.customer
SET salary = ROUND(salary*0.70,-3);
```

Contoh output:

```text
3 rows updated.
```

Simpan perubahan:

```sql
COMMIT;
```



Cek hasilnya:

```sql
SELECT customer_id, salary
FROM masked_owner.customer ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID          SALARY
----------- ---------------
          1   10,500,000.00
          2   12,250,000.00
          3   15,400,000.00

3 rows selected.
```

---

## LAB 17 — Verify Complete Masking

Cek hasilnya:

```sql
SELECT customer_id, customer_name, email_address
FROM masked_owner.customer ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID CUSTOMER_NAME      EMAIL_ADDRESS
----------- ------------------ ----------------------------
          1 CUSTOMER_1         customer1@example.test
          2 CUSTOMER_2         customer2@example.test
          3 CUSTOMER_3         customer3@example.test

3 rows selected.
```

Cek hasilnya:

```sql
SELECT customer_id, phone_number, credit_card_number, social_security_number
FROM masked_owner.customer ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID PHONE_NUMBER     CREDIT_CARD_NUMBER   SOCIAL_SECURITY_NUMBER
----------- ---------------- -------------------- ----------------------
          1 +6200000000001   0000000000001111     000-00-6789
          2 +6200000000002   0000000000004444     000-00-4321
          3 +6200000000003   0000000000000005     000-00-3333

3 rows selected.
```

Cek hasilnya:

```sql
SELECT customer_id, TO_CHAR(date_of_birth, 'YYYY-MM-DD') AS date_of_birth, salary
FROM masked_owner.customer ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID DATE_OF_BIRTH          SALARY
----------- ------------- ---------------
          1 1980-07-15      10,500,000.00
          2 1985-07-15      12,250,000.00
          3 1990-07-15      15,400,000.00

3 rows selected.
```

---

## LAB 18 — Masking Must Preserve Application Rules

Masking perlu mengikuti kebutuhan aplikasi: tipe data, panjang, format, uniqueness, dan aturan seperti checksum. String angka 16 karakter belum tentu nomor kartu yang valid. Jangan menyebut hasil latihan sebagai kartu valid untuk transaksi. Tentukan juga apakah empat digit terakhir memang perlu dipertahankan.

---

## LAB 19 — Deterministic vs Random Masking

Deterministik berarti input yang sama menghasilkan output yang sama. Di sini inputnya customer ID, bukan nama. Random masking bisa menghasilkan nilai berbeda pada setiap pemanggilan dan tidak boleh langsung dipakai mengganti key relasi tanpa mapping yang konsisten.

Cek hasilnya:

```sql
SELECT customer_id, 'CUSTOMER_' || customer_id AS customer_name
FROM discovery_owner.customer ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID CUSTOMER_NAME
----------- ------------------
          1 CUSTOMER_1
          2 CUSTOMER_2
          3 CUSTOMER_3

3 rows selected.
```

Coba random masking tanpa mengubah tabel. Contoh hasil di bawah berasal dari pengujian; teks acak akan berbeda saat dijalankan ulang:

```sql
SELECT customer_id, CAST(DBMS_RANDOM.STRING('U',8) AS VARCHAR2(12)) AS random_name
FROM discovery_owner.customer ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID RANDOM_NAME
----------- ------------
          1 HVJNLOAI
          2 XFRTTTRF
          3 XECCMZCR

3 rows selected.
```

---

## LAB 20 — Referential Integrity

Foreign key menjaga agar account selalu menunjuk customer yang ada.

```sql
CREATE TABLE masked_owner.customer_account (
  account_id NUMBER PRIMARY KEY,
  customer_id NUMBER NOT NULL,
  account_number VARCHAR2(30),
  account_type VARCHAR2(30),
  balance NUMBER(15,2),
  CONSTRAINT masked_fk_customer FOREIGN KEY (customer_id)
    REFERENCES masked_owner.customer(customer_id)
);
```



---

## LAB 21 — Populate Account Data

```sql
INSERT INTO masked_owner.customer_account
(account_id, customer_id, account_number, account_type, balance)
VALUES (1001, 1, '1234567890123456', 'SAVINGS', 25000000);
```



```sql
INSERT INTO masked_owner.customer_account
(account_id, customer_id, account_number, account_type, balance)
VALUES (1002, 1, '1234567890123457', 'CURRENT', 15000000);
```



```sql
INSERT INTO masked_owner.customer_account
(account_id, customer_id, account_number, account_type, balance)
VALUES (1003, 2, '1234567890123458', 'SAVINGS', 35000000);
```



Simpan perubahan:

```sql
COMMIT;
```



---

## LAB 22 — Verify Relationship

Cek hasilnya:

```sql
SELECT c.customer_id, c.customer_name, a.account_id, a.account_number, a.balance
FROM masked_owner.customer c
JOIN masked_owner.customer_account a ON c.customer_id=a.customer_id
ORDER BY c.customer_id, a.account_id;
```

Contoh output:

```text
CUSTOMER_ID CUSTOMER_NAME      ACCOUNT_ID ACCOUNT_NUMBER               BALANCE
----------- ------------------ ---------- -------------------- ---------------
          1 CUSTOMER_1               1001 1234567890123456       25,000,000.00
          1 CUSTOMER_1               1002 1234567890123457       15,000,000.00
          2 CUSTOMER_2               1003 1234567890123458       35,000,000.00

3 rows selected.
```

---

## LAB 23 — Mask Account Number

```sql
UPDATE masked_owner.customer_account
SET account_number='999999999999' || SUBSTR(account_number,-4);
```

Contoh output:

```text
3 rows updated.
```

Simpan perubahan:

```sql
COMMIT;
```



Cek hasilnya:

```sql
SELECT account_id, account_number
FROM masked_owner.customer_account ORDER BY account_id;
```

Contoh output:

```text
ACCOUNT_ID ACCOUNT_NUMBER
---------- --------------------
      1001 9999999999993456
      1002 9999999999993457
      1003 9999999999993458

3 rows selected.
```

---

## LAB 24 — Mask Balance

Seperti salary, perkalian ini hanya contoh transformasi numerik dan masih mengungkap hubungan dengan nilai asal.

```sql
UPDATE masked_owner.customer_account SET balance=ROUND(balance*0.65,-3);
```

Contoh output:

```text
3 rows updated.
```

Simpan perubahan:

```sql
COMMIT;
```



Cek hasilnya:

```sql
SELECT account_id, balance FROM masked_owner.customer_account ORDER BY account_id;
```

Contoh output:

```text
ACCOUNT_ID         BALANCE
---------- ---------------
      1001   16,250,000.00
      1002    9,750,000.00
      1003   22,750,000.00

3 rows selected.
```

---

## LAB 25 — Verify Referential Integrity

Cek hasilnya:

```sql
SELECT COUNT(*) AS orphan_count
FROM masked_owner.customer_account a
WHERE NOT EXISTS (SELECT 1 FROM masked_owner.customer c WHERE c.customer_id=a.customer_id);
```

Contoh output:

```text
ORPHAN_COUNT
------------
           0

1 row selected.
```

---

## LAB 26 — Test Bad Masking

Sekarang kita sengaja mencoba mengubah parent key. Dengan foreign key aktif, Oracle menolak perubahan; join tidak mendadak kosong. Error berikut adalah hasil yang diharapkan.

```sql
UPDATE masked_owner.customer SET customer_id=customer_id+1000;
```

Hasil error yang memang diharapkan:

```text
UPDATE masked_owner.customer SET customer_id=customer_id+1000
*
ERROR at line 1:
ORA-02292: integrity constraint (MASKED_OWNER.MASKED_FK_CUSTOMER) violated - child record found
```

---

## LAB 27 — Pastikan Customer ID Tetap Utuh

Tidak perlu mengurangi ID dengan 1000 karena UPDATE sebelumnya gagal secara utuh. Lakukan rollback sebagai penutup latihan error, lalu cek relasi kembali.

```sql
ROLLBACK;
```

Contoh output:

```text
Rollback complete.
```

Cek hasilnya:

```sql
SELECT c.customer_id, a.account_id
FROM masked_owner.customer c
JOIN masked_owner.customer_account a ON c.customer_id=a.customer_id
ORDER BY c.customer_id, a.account_id;
```

Contoh output:

```text
CUSTOMER_ID ACCOUNT_ID
----------- ----------
          1       1001
          1       1002
          2       1003

3 rows selected.
```

---

# BAGIAN B — DATA SUBSETTING

## LAB 28 — Apa Itu Data Subsetting?

Subsetting mengambil sebagian data yang dibutuhkan pengujian. Data lebih kecil mempercepat refresh dan mengurangi storage, tetapi relasi harus tetap konsisten. Mengurangi jumlah baris saja tidak menyembunyikan informasi sensitif.

---

## LAB 29 — Manual Subsetting

```sql
CREATE USER subset_owner IDENTIFIED BY "Subset#2026" DEFAULT TABLESPACE users;
```

Contoh output:



```sql
GRANT CREATE SESSION, CREATE TABLE TO subset_owner;
```



```sql
ALTER USER subset_owner QUOTA 100M ON users;
```

Contoh output:

```text
User altered.
```

---

## LAB 30 — Create Subset Customer

Kita pilih dua customer pertama. CTAS tidak menyalin primary key dan foreign key, jadi constraint ditambahkan secara eksplisit.

```sql
CREATE TABLE subset_owner.customer AS
SELECT customer_id, customer_name, email_address, phone_number, credit_card_number, social_security_number, date_of_birth, salary
FROM discovery_owner.customer WHERE customer_id <= 2;
```



```sql
ALTER TABLE subset_owner.customer ADD CONSTRAINT subset_customer_pk PRIMARY KEY (customer_id);
```

Contoh output:

```text
Table altered.
```

Cek hasilnya:

```sql
SELECT customer_id, customer_name FROM subset_owner.customer ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID CUSTOMER_NAME
----------- ------------------
          1 JOHN DOE
          2 JANE DOE

2 rows selected.
```

---

## LAB 31 — Subset Account

Ambil account berdasarkan customer yang benar-benar masuk subset.

```sql
CREATE TABLE subset_owner.customer_account AS
SELECT a.account_id, a.customer_id, a.account_number, a.account_type, a.balance
FROM discovery_owner.customer_account a
WHERE EXISTS (SELECT 1 FROM subset_owner.customer c WHERE c.customer_id=a.customer_id);
```



```sql
ALTER TABLE subset_owner.customer_account ADD CONSTRAINT subset_account_pk PRIMARY KEY (account_id);
```

Contoh output:

```text
Table altered.
```

```sql
ALTER TABLE subset_owner.customer_account ADD CONSTRAINT subset_fk_customer
FOREIGN KEY (customer_id) REFERENCES subset_owner.customer(customer_id);
```

Contoh output:

```text
Table altered.
```

Cek hasilnya:

```sql
SELECT account_id, customer_id, account_number, account_type, balance
FROM subset_owner.customer_account ORDER BY account_id;
```

Contoh output:

```text
ACCOUNT_ID CUSTOMER_ID ACCOUNT_NUMBER       ACCOUNT_TYPE         BALANCE
---------- ----------- -------------------- ------------ ---------------
      1001           1 1234567890123456     SAVINGS        25,000,000.00
      1002           1 1234567890123457     CURRENT        15,000,000.00
      1003           2 1234567890123458     SAVINGS        35,000,000.00

3 rows selected.
```

---

## LAB 32 — Check Referential Integrity of Subset

Cek hasilnya:

```sql
SELECT COUNT(*) AS orphan_count
FROM subset_owner.customer_account a
WHERE NOT EXISTS (SELECT 1 FROM subset_owner.customer c WHERE c.customer_id=a.customer_id);
```

Contoh output:

```text
ORPHAN_COUNT
------------
           0

1 row selected.
```

Cek hasilnya:

```sql
SELECT constraint_name, constraint_type, status FROM dba_constraints
WHERE owner='SUBSET_OWNER' AND constraint_type IN ('P','R') ORDER BY constraint_name;
```

Contoh output:

```text
CONSTRAINT_NAME           CONSTRAINT_TYPE STATUS
------------------------- --------------- --------------------
SUBSET_ACCOUNT_PK         P               ENABLED
SUBSET_CUSTOMER_PK        P               ENABLED
SUBSET_FK_CUSTOMER        R               ENABLED

3 rows selected.
```

---

## LAB 33 — Combine Subsetting + Masking

Alurnya: production → subset → masking → non-production. Tabel subset mentah pada Lab 30–31 masih sensitif. Dataset final berikut dibuat dalam dua tabel masked yang saling berelasi; jangan membagikan tabel subset mentah kepada developer.

---

## LAB 34 — Create Final Test Dataset

Kita masking customer dan account, termasuk balance. Dengan begitu, dataset final tidak berhenti pada customer saja.

```sql
CREATE TABLE subset_owner.customer_masked AS
SELECT customer_id,
  'CUSTOMER_' || customer_id AS customer_name,
  'customer' || customer_id || '@example.test' AS email_address,
  '+620000000000' || customer_id AS phone_number,
  '000000000000' || SUBSTR(credit_card_number,-4) AS credit_card_number,
  '000-00-' || SUBSTR(social_security_number,-4) AS social_security_number,
  ADD_MONTHS(TRUNC(date_of_birth,'YYYY'),6)+14 AS date_of_birth,
  ROUND(salary*0.70,-3) AS salary
FROM subset_owner.customer;
```



```sql
ALTER TABLE subset_owner.customer_masked ADD CONSTRAINT subset_masked_customer_pk PRIMARY KEY (customer_id);
```

Contoh output:

```text
Table altered.
```

```sql
CREATE TABLE subset_owner.customer_account_masked AS
SELECT a.account_id, a.customer_id,
  '999999999999' || SUBSTR(a.account_number,-4) AS account_number,
  a.account_type, ROUND(a.balance*0.65,-3) AS balance
FROM subset_owner.customer_account a
WHERE EXISTS (SELECT 1 FROM subset_owner.customer_masked c WHERE c.customer_id=a.customer_id);
```



```sql
ALTER TABLE subset_owner.customer_account_masked ADD CONSTRAINT subset_masked_account_pk PRIMARY KEY (account_id);
```

Contoh output:

```text
Table altered.
```

```sql
ALTER TABLE subset_owner.customer_account_masked ADD CONSTRAINT subset_masked_fk_customer
FOREIGN KEY (customer_id) REFERENCES subset_owner.customer_masked(customer_id);
```

Contoh output:

```text
Table altered.
```

Cek hasilnya:

```sql
SELECT customer_id, customer_name, email_address
FROM subset_owner.customer_masked ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID CUSTOMER_NAME      EMAIL_ADDRESS
----------- ------------------ ----------------------------
          1 CUSTOMER_1         customer1@example.test
          2 CUSTOMER_2         customer2@example.test

2 rows selected.
```

Cek hasilnya:

```sql
SELECT customer_id, phone_number, TO_CHAR(date_of_birth,'YYYY-MM-DD') AS date_of_birth, salary
FROM subset_owner.customer_masked ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID PHONE_NUMBER     DATE_OF_BIRTH          SALARY
----------- ---------------- ------------- ---------------
          1 +6200000000001   1980-07-15      10,500,000.00
          2 +6200000000002   1985-07-15      12,250,000.00

2 rows selected.
```

Cek hasilnya:

```sql
SELECT account_id, customer_id, account_number, account_type, balance
FROM subset_owner.customer_account_masked ORDER BY account_id;
```

Contoh output:

```text
ACCOUNT_ID CUSTOMER_ID ACCOUNT_NUMBER       ACCOUNT_TYPE         BALANCE
---------- ----------- -------------------- ------------ ---------------
      1001           1 9999999999993456     SAVINGS        16,250,000.00
      1002           1 9999999999993457     CURRENT         9,750,000.00
      1003           2 9999999999993458     SAVINGS        22,750,000.00

3 rows selected.
```

---

## LAB 35 — Validate Final Dataset

Cek hasilnya:

```sql
SELECT COUNT(*) AS customer_count FROM subset_owner.customer_masked;
```

Contoh output:

```text
CUSTOMER_COUNT
--------------
             2

1 row selected.
```

Cek hasilnya:

```sql
SELECT customer_id, credit_card_number, social_security_number, email_address
FROM subset_owner.customer_masked ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID CREDIT_CARD_NUMBER   SOCIAL_SECURITY_NUMBER EMAIL_ADDRESS
----------- -------------------- ---------------------- ----------------------------
          1 0000000000001111     000-00-6789            customer1@example.test
          2 0000000000004444     000-00-4321            customer2@example.test

2 rows selected.
```

Cek hasilnya:

```sql
SELECT COUNT(*) AS orphan_count FROM subset_owner.customer_account_masked a
WHERE NOT EXISTS (SELECT 1 FROM subset_owner.customer_masked c WHERE c.customer_id=a.customer_id);
```

Contoh output:

```text
ORPHAN_COUNT
------------
           0

1 row selected.
```

---

# BAGIAN C — DATA REDACTION

## LAB 36 — Check DBMS_REDACT

Static masking mengubah nilai pada salinan tabel. Data Redaction mengubah tampilan hasil query untuk sesi yang terkena policy, sementara nilai asal tetap tersimpan. Pengujian akses harus memakai user biasa karena SYS melewati redaction.

Rujukan: [Oracle 19c DBMS_REDACT](https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_REDACT.html).

Kembali sebagai SYS di SQL*Plus:

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA
```

Output: tidak ada pesan pada mode `-s` jika koneksi berhasil. Query berikutnya dijalankan dengan koneksi ini.

Cek hasilnya:

```sql
SELECT owner, object_name, object_type, status FROM dba_objects
WHERE owner='SYS' AND object_name='DBMS_REDACT'
ORDER BY object_type;
```

Contoh output:

```text
OWNER              OBJECT_NAME              OBJECT_TYPE    STATUS
------------------ ------------------------ -------------- --------------------
SYS                DBMS_REDACT              PACKAGE        VALID
SYS                DBMS_REDACT              PACKAGE BODY   VALID

2 rows selected.
```

---

## LAB 37 — Create Redaction User

```sql
CREATE USER redact_user IDENTIFIED BY "Redact#2026";
```

Contoh output:



```sql
GRANT CREATE SESSION TO redact_user;
```



```sql
GRANT SELECT ON discovery_owner.customer TO redact_user;
```



---

## LAB 38 — Test Before Redaction

Ganti koneksi menjadi user aplikasi:

```sql
CONNECT redact_user/"Redact#2026"@localhost:1521/pdb1.localdomain
```

Output: tidak ada pesan pada mode `-s` jika koneksi berhasil. Query berikutnya dijalankan dengan koneksi ini.

Cek hasilnya:

```sql
SELECT customer_id, customer_name, credit_card_number
FROM discovery_owner.customer ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID CUSTOMER_NAME      CREDIT_CARD_NUMBER
----------- ------------------ --------------------
          1 JOHN DOE           4111111111111111
          2 JANE DOE           5555555555554444
          3 ALICE              378282246310005

3 rows selected.
```

---

## LAB 39 — Create Full Redaction Policy

Kembali sebagai SYS di SQL*Plus:

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA
```

Output: tidak ada pesan pada mode `-s` jika koneksi berhasil. Query berikutnya dijalankan dengan koneksi ini.

```sql
BEGIN
  DBMS_REDACT.ADD_POLICY(
    object_schema => 'DISCOVERY_OWNER',
    object_name => 'CUSTOMER',
    policy_name => 'REDACT_CC_POLICY',
    column_name => 'CREDIT_CARD_NUMBER',
    function_type => DBMS_REDACT.FULL,
    expression => '1=1'
  );
END;
/
```

Contoh output:

```text
PL/SQL procedure successfully completed.
```

---

## LAB 40 — Test Full Redaction

Pada konfigurasi VM ini, FULL redaction pada VARCHAR2 menghasilkan satu spasi, bukan deretan X. Query kedua memberi pembatas agar spasi tersebut terlihat. Pengaturan `SET NULL` tidak mengubah spasi menjadi `(NULL)`.

Ganti koneksi menjadi user aplikasi:

```sql
CONNECT redact_user/"Redact#2026"@localhost:1521/pdb1.localdomain
```

Output: tidak ada pesan pada mode `-s` jika koneksi berhasil. Query berikutnya dijalankan dengan koneksi ini.

Cek hasilnya:

```sql
SELECT customer_id, customer_name, credit_card_number
FROM discovery_owner.customer ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID CUSTOMER_NAME      CREDIT_CARD_NUMBER
----------- ------------------ --------------------
          1 JOHN DOE
          2 JANE DOE
          3 ALICE

3 rows selected.
```

Cek hasilnya:

```sql
SELECT customer_id, '[' || credit_card_number || ']' AS cc_display
FROM discovery_owner.customer ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID CC_DISPLAY
----------- ----------------------
          1 [ ]
          2 [ ]
          3 [ ]

3 rows selected.
```

---

## LAB 41 — Verify Source Still Original

Kembali sebagai SYS di SQL*Plus:

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA
```

Output: tidak ada pesan pada mode `-s` jika koneksi berhasil. Query berikutnya dijalankan dengan koneksi ini.

Cek hasilnya:

```sql
SELECT customer_id, credit_card_number FROM discovery_owner.customer ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID CREDIT_CARD_NUMBER
----------- --------------------
          1 4111111111111111
          2 5555555555554444
          3 378282246310005

3 rows selected.
```

---

## LAB 42 — Partial Display untuk Kartu 15 dan 16 Digit

Skenario ini tetap bisa dijalankan di Oracle 19.8. Gunakan REGEXP redaction untuk menampilkan empat digit terakhir pada nomor kartu yang panjangnya berbeda. Hasil tampilan memakai 12 bintang dan empat digit terakhir; untuk kartu 15 digit panjang tampilan menjadi 16 karakter. Ini redaction dengan regular expression, bukan parameter numerik `12,4,0`.

```sql
BEGIN
  DBMS_REDACT.ALTER_POLICY(
    object_schema => 'DISCOVERY_OWNER',
    object_name => 'CUSTOMER',
    policy_name => 'REDACT_CC_POLICY',
    action => DBMS_REDACT.MODIFY_COLUMN,
    column_name => 'CREDIT_CARD_NUMBER',
    function_type => DBMS_REDACT.REGEXP,
    regexp_pattern => '^([[:digit:]]+)([[:digit:]]{4})$',
    regexp_replace_string => '************\2',
    regexp_position => 1,
    regexp_occurrence => 0,
    regexp_match_parameter => 'c'
  );
END;
/
```

Contoh output:

```text
PL/SQL procedure successfully completed.
```

---

## LAB 43 — Test Tampilan Empat Digit Terakhir

Ganti koneksi menjadi user aplikasi:

```sql
CONNECT redact_user/"Redact#2026"@localhost:1521/pdb1.localdomain
```

Output: tidak ada pesan pada mode `-s` jika koneksi berhasil. Query berikutnya dijalankan dengan koneksi ini.

Cek hasilnya:

```sql
SELECT customer_id, customer_name, credit_card_number
FROM discovery_owner.customer ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID CUSTOMER_NAME      CREDIT_CARD_NUMBER
----------- ------------------ --------------------
          1 JOHN DOE           ************1111
          2 JANE DOE           ************4444
          3 ALICE              ************0005

3 rows selected.
```

---

## LAB 44 — Create Authorized Application User

Kita buat user pembanding dengan SELECT saja. Nama user pada policy harus merujuk user yang benar-benar ada.

Kembali sebagai SYS di SQL*Plus:

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA
```

Output: tidak ada pesan pada mode `-s` jika koneksi berhasil. Query berikutnya dijalankan dengan koneksi ini.

```sql
CREATE USER security_admin IDENTIFIED BY "Security#2026";
```

Contoh output:



```sql
GRANT CREATE SESSION TO security_admin;
```



```sql
GRANT SELECT ON discovery_owner.customer TO security_admin;
```



---

## LAB 45 — Conditional Redaction

Policy aktif untuk sesi selain SECURITY_ADMIN. Pengecualian berdasarkan identitas database ini harus dikelola sebagai akses sensitif.

```sql
BEGIN
  DBMS_REDACT.ALTER_POLICY(
    object_schema => 'DISCOVERY_OWNER',
    object_name => 'CUSTOMER',
    policy_name => 'REDACT_CC_POLICY',
    action => DBMS_REDACT.MODIFY_EXPRESSION,
    expression => 'SYS_CONTEXT(''USERENV'',''SESSION_USER'') <> ''SECURITY_ADMIN'''
  );
END;
/
```

Contoh output:

```text
PL/SQL procedure successfully completed.
```

---

## LAB 46 — Test User yang Terkena Policy

Ganti koneksi menjadi user aplikasi:

```sql
CONNECT redact_user/"Redact#2026"@localhost:1521/pdb1.localdomain
```

Output: tidak ada pesan pada mode `-s` jika koneksi berhasil. Query berikutnya dijalankan dengan koneksi ini.

Cek hasilnya:

```sql
SELECT customer_id, customer_name, credit_card_number
FROM discovery_owner.customer ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID CUSTOMER_NAME      CREDIT_CARD_NUMBER
----------- ------------------ --------------------
          1 JOHN DOE           ************1111
          2 JANE DOE           ************4444
          3 ALICE              ************0005

3 rows selected.
```

---

## LAB 47 — Test Authorized User

```sql
CONNECT security_admin/"Security#2026"@localhost:1521/pdb1.localdomain
```

Output: tidak ada pesan pada mode `-s` jika koneksi berhasil. Query berikutnya dijalankan dengan koneksi ini.

Cek hasilnya:

```sql
SELECT customer_id, customer_name, credit_card_number
FROM discovery_owner.customer ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID CUSTOMER_NAME      CREDIT_CARD_NUMBER
----------- ------------------ --------------------
          1 JOHN DOE           4111111111111111
          2 JANE DOE           5555555555554444
          3 ALICE              378282246310005

3 rows selected.
```

---

## LAB 48 — Verify Privilege Pembanding

SECURITY_ADMIN tidak memerlukan EXEMPT REDACTION POLICY untuk skenario ini. Perbedaan hasil datang dari expression policy.

Kembali sebagai SYS di SQL*Plus:

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA
```

Output: tidak ada pesan pada mode `-s` jika koneksi berhasil. Query berikutnya dijalankan dengan koneksi ini.

Cek hasilnya:

```sql
SELECT grantee AS username, privilege FROM dba_sys_privs
WHERE grantee IN ('REDACT_USER','SECURITY_ADMIN') ORDER BY grantee, privilege;
```

Contoh output:

```text
USERNAME           PRIVILEGE
------------------ ----------------------------
REDACT_USER        CREATE SESSION
SECURITY_ADMIN     CREATE SESSION

2 rows selected.
```

---

## LAB 49 — Review Policy

```sql
COLUMN expression FORMAT A85
```



Cek hasilnya:

```sql
SELECT object_owner, object_name, policy_name, enable
FROM redaction_policies WHERE object_owner='DISCOVERY_OWNER';
```

Contoh output:

```text
OBJECT_OWNER       OBJECT_NAME              POLICY_NAME              ENABLE
------------------ ------------------------ ------------------------ --------
DISCOVERY_OWNER    CUSTOMER                 REDACT_CC_POLICY         YES

1 row selected.
```

Cek hasilnya:

```sql
SELECT expression FROM redaction_policies WHERE object_owner='DISCOVERY_OWNER';
```

Contoh output:

```text
EXPRESSION
-------------------------------------------------------------------------------------
SYS_CONTEXT('USERENV','SESSION_USER') <> 'SECURITY_ADMIN'

1 row selected.
```

---

## LAB 50 — Review Kolom yang Dilindungi

Cek hasilnya:

```sql
SELECT object_owner, object_name, column_name, function_type
FROM redaction_columns WHERE object_owner='DISCOVERY_OWNER' ORDER BY column_name;
```

Contoh output:

```text
OBJECT_OWNER       OBJECT_NAME              COLUMN_NAME               FUNCTION_TYPE
------------------ ------------------------ ------------------------- ----------------------
DISCOVERY_OWNER    CUSTOMER                 CREDIT_CARD_NUMBER        REGEXP REDACTION

1 row selected.
```

---

# BAGIAN D — INVENTORY & VALIDATION


## LAB 52 — TSDP Concept

Transparent Sensitive Data Protection menggunakan klasifikasi data sensitif dan kebijakan perlindungan. Misalnya, tipe CREDIT_CARD dapat dipetakan ke beberapa kolom pada tabel berbeda. Inventory manual berikut membantu memahami klasifikasi tersebut, tetapi belum menjadi konfigurasi TSDP.

---

## LAB 53 — Sensitive Data Inventory

Pencarian berdasarkan nama kolom adalah petunjuk awal, bukan penemuan otomatis yang lengkap. SSN pada schema ini bernama SOCIAL_SECURITY_NUMBER, jadi pola pencarian perlu mencakup nama tersebut.

Cek hasilnya:

```sql
SELECT owner, table_name, column_name, data_type FROM dba_tab_columns
WHERE owner='DISCOVERY_OWNER'
AND table_name IN ('CUSTOMER','CUSTOMER_ACCOUNT')
AND column_name IN ('CUSTOMER_NAME','EMAIL_ADDRESS','PHONE_NUMBER',
  'CREDIT_CARD_NUMBER','SOCIAL_SECURITY_NUMBER','DATE_OF_BIRTH',
  'SALARY','ACCOUNT_NUMBER','BALANCE')
ORDER BY table_name, column_id;
```

Contoh output:

```text
OWNER              TABLE_NAME               COLUMN_NAME               DATA_TYPE
------------------ ------------------------ ------------------------- ------------
DISCOVERY_OWNER    CUSTOMER                 CUSTOMER_NAME             VARCHAR2
DISCOVERY_OWNER    CUSTOMER                 EMAIL_ADDRESS             VARCHAR2
DISCOVERY_OWNER    CUSTOMER                 PHONE_NUMBER              VARCHAR2
DISCOVERY_OWNER    CUSTOMER                 CREDIT_CARD_NUMBER        VARCHAR2
DISCOVERY_OWNER    CUSTOMER                 SOCIAL_SECURITY_NUMBER    VARCHAR2
DISCOVERY_OWNER    CUSTOMER                 DATE_OF_BIRTH             DATE
DISCOVERY_OWNER    CUSTOMER                 SALARY                    NUMBER
DISCOVERY_OWNER    CUSTOMER_ACCOUNT         ACCOUNT_NUMBER            VARCHAR2
DISCOVERY_OWNER    CUSTOMER_ACCOUNT         BALANCE                   NUMBER

9 rows selected.
```

---

## LAB 54 — Security Control Mapping

Tabel ini adalah rancangan kontrol, bukan bukti semua kolom sudah dilindungi.

| Data | Contoh kontrol |
| --- | --- |
| Credit card | TDE untuk at rest; redaction untuk tampilan; masking pada salinan |
| SSN | TDE, redaction, dan masking sesuai kebutuhan |
| Email dan phone | Masking untuk non-production |
| Salary dan balance | Kontrol akses dan redaction sesuai kebutuhan; masking pada salinan |
| Account number | TDE, redaction, dan masking sesuai kebutuhan |

---

## LAB 55 — End-to-End Security Architecture

Alurnya dapat dibaca sebagai tiga kontrol yang saling melengkapi:

* Discovery/inventory mengenali kolom sensitif.
* Subsetting dan masking menyiapkan dataset pengujian.
* TDE melindungi data at rest, sedangkan redaction mengatur tampilan hasil query.

VM ini memakai software wallet existing. Oracle Key Vault hanya pembahasan pengelolaan key terpusat; tidak dipasang atau diuji pada hands-on ini.

---

## LAB 56 — Security Test Matrix

Kembali sebagai SYS di SQL*Plus:

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA
```

Output: tidak ada pesan pada mode `-s` jika koneksi berhasil. Query berikutnya dijalankan dengan koneksi ini.

Cek hasilnya:

```sql
SELECT credit_card_number FROM discovery_owner.customer WHERE customer_id=1;
```

Contoh output:

```text
CREDIT_CARD_NUMBER
--------------------
4111111111111111

1 row selected.
```

Cek hasilnya:

```sql
SELECT credit_card_number FROM masked_owner.customer WHERE customer_id=1;
```

Contoh output:

```text
CREDIT_CARD_NUMBER
--------------------
0000000000001111

1 row selected.
```

Ganti koneksi menjadi user aplikasi:

```sql
CONNECT redact_user/"Redact#2026"@localhost:1521/pdb1.localdomain
```

Output: tidak ada pesan pada mode `-s` jika koneksi berhasil. Query berikutnya dijalankan dengan koneksi ini.

Cek hasilnya:

```sql
SELECT credit_card_number FROM discovery_owner.customer WHERE customer_id=1;
```

Contoh output:

```text
CREDIT_CARD_NUMBER
--------------------
************1111

1 row selected.
```

```sql
CONNECT security_admin/"Security#2026"@localhost:1521/pdb1.localdomain
```

Output: tidak ada pesan pada mode `-s` jika koneksi berhasil. Query berikutnya dijalankan dengan koneksi ini.

Cek hasilnya:

```sql
SELECT credit_card_number FROM discovery_owner.customer WHERE customer_id=1;
```

Contoh output:

```text
CREDIT_CARD_NUMBER
--------------------
4111111111111111

1 row selected.
```

---

## LAB 57 — Demonstrate Difference

| Kontrol | Nilai tersimpan | Hasil SELECT |
| --- | --- | --- |
| Static masking | Nilai pengganti pada salinan | Nilai masked |
| Data Redaction | Nilai asal tetap | Tergantung policy dan privilege sesi |
| TDE | Terenkripsi at rest | Nilai asli jika key tersedia dan akses SQL diizinkan |
| TDE + redaction | Terenkripsi at rest | Tampilan mengikuti policy |

TDE tidak menggantikan GRANT atau redaction. Wallet terbuka tidak otomatis memberikan SELECT kepada semua user.

---

## LAB 58 — Verify Masking Did Not Affect Source

Kembali sebagai SYS di SQL*Plus:

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA
```

Output: tidak ada pesan pada mode `-s` jika koneksi berhasil. Query berikutnya dijalankan dengan koneksi ini.

Cek hasilnya:

```sql
SELECT customer_id, customer_name, credit_card_number
FROM discovery_owner.customer ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID CUSTOMER_NAME      CREDIT_CARD_NUMBER
----------- ------------------ --------------------
          1 JOHN DOE           4111111111111111
          2 JANE DOE           5555555555554444
          3 ALICE              378282246310005

3 rows selected.
```

Cek hasilnya:

```sql
SELECT customer_id, customer_name, credit_card_number
FROM masked_owner.customer ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID CUSTOMER_NAME      CREDIT_CARD_NUMBER
----------- ------------------ --------------------
          1 CUSTOMER_1         0000000000001111
          2 CUSTOMER_2         0000000000004444
          3 CUSTOMER_3         0000000000000005

3 rows selected.
```

---

## LAB 59 — Sensitive Data Leak Test

Sebagai REDACT_USER, credit card sudah disamarkan tetapi SSN dan email masih terlihat. Ini gap yang sengaja ditunjukkan. Redaction satu kolom tidak melindungi semua kolom otomatis.

Ganti koneksi menjadi user aplikasi:

```sql
CONNECT redact_user/"Redact#2026"@localhost:1521/pdb1.localdomain
```

Output: tidak ada pesan pada mode `-s` jika koneksi berhasil. Query berikutnya dijalankan dengan koneksi ini.

Cek hasilnya:

```sql
SELECT customer_id, credit_card_number, social_security_number, email_address
FROM discovery_owner.customer ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID CREDIT_CARD_NUMBER   SOCIAL_SECURITY_NUMBER EMAIL_ADDRESS
----------- -------------------- ---------------------- ----------------------------
          1 ************1111     123-45-6789            john.doe@example.com
          2 ************4444     987-65-4321            jane.doe@example.com
          3 ************0005     111-22-3333            alice@example.com

3 rows selected.
```

---

## LAB 60 — Remediation Exercise

Satu tabel hanya mempunyai satu redaction policy. Tambahkan SSN ke policy existing menggunakan ALTER_POLICY dan ADD_COLUMN. Untuk SSN berformat tetap, PARTIAL menggunakan format karakter yang lengkap. Expression policy sebelumnya berlaku juga untuk kolom tambahan. Email tetap terlihat karena belum ditambahkan ke policy.

Kembali sebagai SYS di SQL*Plus:

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA
```

Output: tidak ada pesan pada mode `-s` jika koneksi berhasil. Query berikutnya dijalankan dengan koneksi ini.

```sql
BEGIN
  DBMS_REDACT.ALTER_POLICY(
    object_schema => 'DISCOVERY_OWNER',
    object_name => 'CUSTOMER',
    policy_name => 'REDACT_CC_POLICY',
    action => DBMS_REDACT.ADD_COLUMN,
    column_name => 'SOCIAL_SECURITY_NUMBER',
    function_type => DBMS_REDACT.PARTIAL,
    function_parameters => 'VVVFVVFVVVV,VVV-VV-VVVV,*,1,5'
  );
END;
/
```

Contoh output:

```text
PL/SQL procedure successfully completed.
```

Ganti koneksi menjadi user aplikasi:

```sql
CONNECT redact_user/"Redact#2026"@localhost:1521/pdb1.localdomain
```

Output: tidak ada pesan pada mode `-s` jika koneksi berhasil. Query berikutnya dijalankan dengan koneksi ini.

Cek hasilnya:

```sql
SELECT customer_id, credit_card_number, social_security_number, email_address
FROM discovery_owner.customer ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID CREDIT_CARD_NUMBER   SOCIAL_SECURITY_NUMBER EMAIL_ADDRESS
----------- -------------------- ---------------------- ----------------------------
          1 ************1111     ***-**-6789            john.doe@example.com
          2 ************4444     ***-**-4321            jane.doe@example.com
          3 ************0005     ***-**-3333            alice@example.com

3 rows selected.
```

```sql
CONNECT security_admin/"Security#2026"@localhost:1521/pdb1.localdomain
```

Output: tidak ada pesan pada mode `-s` jika koneksi berhasil. Query berikutnya dijalankan dengan koneksi ini.

Cek hasilnya:

```sql
SELECT customer_id, social_security_number FROM discovery_owner.customer ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID SOCIAL_SECURITY_NUMBER
----------- ----------------------
          1 123-45-6789
          2 987-65-4321
          3 111-22-3333

3 rows selected.
```

---

# BAGIAN E — TDE: AKSES GAGAL DAN PEMULIHAN

## LAB 60A — TDE: Gunakan Wallet Existing

Sekarang kita buktikan apa yang terjadi ketika key untuk data terenkripsi tidak tersedia. VM memiliki password wallet yang sudah OPEN dan tablespace TS_SECURE terenkripsi. Kita memakai wallet/key existing dan membuat satu tabel demo baru dengan column encryption di USERS. Tabel TDE yang sudah ada tetap dipertahankan.

Latihan tutup wallet berdampak pada akses data terenkripsi lain di PDB1 selama wallet tertutup, termasuk TS_SECURE. Lakukan di VM lab ini, siapkan command pembuka wallet sebelum melanjutkan, dan selesaikan pemulihan pada Lab 60D.

Rujukan: [Oracle 19c—pengelolaan keystore dalam united mode](https://docs.oracle.com/en/database/oracle/oracle-database/19/asoag/managing-keystores-encryption-keys-in-united-mode.html).

Kembali sebagai SYS di SQL*Plus:

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA
```

Output: tidak ada pesan pada mode `-s` jika koneksi berhasil. Query berikutnya dijalankan dengan koneksi ini.

```sql
SHOW CON_NAME
```

Contoh output:

```text
CON_NAME
------------------------------
PDB1
```

Cek hasilnya:

```sql
SELECT con_id, status, wallet_type, keystore_mode FROM v$encryption_wallet;
```

Contoh output:

```text
    CON_ID STATUS               WALLET_TYPE  KEYSTORE_MODE
---------- -------------------- ------------ -------------
         3 OPEN                 PASSWORD     UNITED

1 row selected.
```

Cek hasilnya:

```sql
SELECT tablespace_name, encrypted FROM dba_tablespaces WHERE tablespace_name IN ('USERS','TS_SECURE') ORDER BY tablespace_name;
```

Contoh output:

```text
TABLESPACE_NAME      ENC
-------------------- ---
TS_SECURE            YES
USERS                NO

2 rows selected.
```

```sql
CREATE TABLE discovery_owner.tde_access_demo (
  demo_id NUMBER PRIMARY KEY,
  secret_text VARCHAR2(40) ENCRYPT USING 'AES256'
) TABLESPACE users;
```



```sql
INSERT INTO discovery_owner.tde_access_demo (demo_id, secret_text) VALUES (1, 'DATA RAHASIA LAB');
```



Simpan perubahan:

```sql
COMMIT;
```



```sql
GRANT SELECT ON discovery_owner.tde_access_demo TO redact_user;
```



Cek hasilnya:

```sql
SELECT owner, table_name, column_name, encryption_alg FROM dba_encrypted_columns
WHERE owner='DISCOVERY_OWNER' AND table_name='TDE_ACCESS_DEMO';
```

Contoh output:

```text
OWNER              TABLE_NAME               COLUMN_NAME               ENCRYPTION_ALG
------------------ ------------------------ ------------------------- --------------------
DISCOVERY_OWNER    TDE_ACCESS_DEMO          SECRET_TEXT               AES 256 bits key

1 row selected.
```

---

## LAB 60B — Baca Data Saat Wallet Terbuka

TDE melakukan dekripsi transparan untuk user yang memiliki SELECT ketika key tersedia.

Ganti koneksi menjadi user aplikasi:

```sql
CONNECT redact_user/"Redact#2026"@localhost:1521/pdb1.localdomain
```

Output: tidak ada pesan pada mode `-s` jika koneksi berhasil. Query berikutnya dijalankan dengan koneksi ini.

Cek hasilnya:

```sql
SELECT demo_id, secret_text FROM discovery_owner.tde_access_demo ORDER BY demo_id;
```

Contoh output:

```text
   DEMO_ID SECRET_TEXT
---------- ------------------------
         1 DATA RAHASIA LAB

1 row selected.
```

---

## LAB 60C — Simulasikan Data Terenkripsi Tidak Bisa Diakses

Tutup hanya wallet pada PDB1 dengan CONTAINER=CURRENT. Jangan menjalankan command ini di CDB$ROOT. Ini simulasi kegagalan yang disengaja; segera lanjutkan pemulihan setelah melihat error.

Kembali sebagai SYS di SQL*Plus:

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA
```

Output: tidak ada pesan pada mode `-s` jika koneksi berhasil. Query berikutnya dijalankan dengan koneksi ini.

```sql
SHOW CON_NAME
```

Contoh output:

```text
CON_NAME
------------------------------
PDB1
```

```sql
ADMINISTER KEY MANAGEMENT SET KEYSTORE CLOSE
IDENTIFIED BY "TDEWallet#2026" CONTAINER=CURRENT;
```

Contoh output:

```text
keystore altered.
```

Cek hasilnya:

```sql
SELECT con_id, status, wallet_type FROM v$encryption_wallet;
```

Contoh output:

```text
    CON_ID STATUS               WALLET_TYPE
---------- -------------------- ------------
         3 CLOSED               UNKNOWN

1 row selected.
```

Ganti koneksi menjadi user aplikasi:

```sql
CONNECT redact_user/"Redact#2026"@localhost:1521/pdb1.localdomain
```

Output: tidak ada pesan pada mode `-s` jika koneksi berhasil. Query berikutnya dijalankan dengan koneksi ini.

Akses data terenkripsi diharapkan gagal:

```sql
SELECT demo_id, secret_text FROM discovery_owner.tde_access_demo ORDER BY demo_id;
```

Hasil error yang memang diharapkan:

```text
SELECT demo_id, secret_text FROM discovery_owner.tde_access_demo ORDER BY demo_id
                                                 *
ERROR at line 1:
ORA-28365: wallet is not open
```

---

## LAB 60D — Pulihkan Akses dengan Membuka Wallet

Gunakan wallet yang sama dan password existing. Tidak perlu membuat wallet baru, mengganti password, atau membuat master key baru. Jika sesi sebelumnya terputus saat wallet tertutup, masuk kembali sebagai SYS ke PDB1 dan jalankan command pembuka ini.

Kembali sebagai SYS di SQL*Plus:

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA
```

Output: tidak ada pesan pada mode `-s` jika koneksi berhasil. Query berikutnya dijalankan dengan koneksi ini.

```sql
ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN
IDENTIFIED BY "TDEWallet#2026" CONTAINER=CURRENT;
```

Contoh output:

```text
keystore altered.
```

Cek hasilnya:

```sql
SELECT con_id, status, wallet_type FROM v$encryption_wallet;
```

Contoh output:

```text
    CON_ID STATUS               WALLET_TYPE
---------- -------------------- ------------
         3 OPEN                 PASSWORD

1 row selected.
```

Ganti koneksi menjadi user aplikasi:

```sql
CONNECT redact_user/"Redact#2026"@localhost:1521/pdb1.localdomain
```

Output: tidak ada pesan pada mode `-s` jika koneksi berhasil. Query berikutnya dijalankan dengan koneksi ini.

Cek hasilnya:

```sql
SELECT demo_id, secret_text FROM discovery_owner.tde_access_demo ORDER BY demo_id;
```

Contoh output:

```text
   DEMO_ID SECRET_TEXT
---------- ------------------------
         1 DATA RAHASIA LAB

1 row selected.
```

---

## LAB 61 — Final Security Audit

ENABLE berada di REDACTION_POLICIES, sedangkan detail fungsi kolom berada di REDACTION_COLUMNS. Audit keduanya. TDE pada demo ini melindungi SECRET_TEXT; tabel CUSTOMER sumber belum dienkripsi oleh latihan ini.

Kembali sebagai SYS di SQL*Plus:

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA
```

Output: tidak ada pesan pada mode `-s` jika koneksi berhasil. Query berikutnya dijalankan dengan koneksi ini.

Cek hasilnya:

```sql
SELECT owner, table_name, column_name, encryption_alg FROM dba_encrypted_columns
WHERE owner='DISCOVERY_OWNER' ORDER BY table_name, column_name;
```

Contoh output:

```text
OWNER              TABLE_NAME               COLUMN_NAME               ENCRYPTION_ALG
------------------ ------------------------ ------------------------- --------------------
DISCOVERY_OWNER    TDE_ACCESS_DEMO          SECRET_TEXT               AES 256 bits key

1 row selected.
```

Cek hasilnya:

```sql
SELECT p.object_owner, p.object_name, c.column_name, c.function_type, p.enable
FROM redaction_policies p JOIN redaction_columns c
ON p.object_owner=c.object_owner AND p.object_name=c.object_name
WHERE p.object_owner='DISCOVERY_OWNER' ORDER BY c.column_name;
```

Contoh output:

```text
OBJECT_OWNER       OBJECT_NAME              COLUMN_NAME               FUNCTION_TYPE          ENABLE
------------------ ------------------------ ------------------------- ---------------------- --------
DISCOVERY_OWNER    CUSTOMER                 CREDIT_CARD_NUMBER        REGEXP REDACTION       YES
DISCOVERY_OWNER    CUSTOMER                 SOCIAL_SECURITY_NUMBER    PARTIAL REDACTION      YES

2 rows selected.
```

Cek hasilnya:

```sql
SELECT tablespace_name, encrypted FROM dba_tablespaces WHERE encrypted='YES' ORDER BY tablespace_name;
```

Contoh output:

```text
TABLESPACE_NAME      ENC
-------------------- ---
TS_SECURE            YES

1 row selected.
```

Cek hasilnya:

```sql
SELECT con_id, status, wallet_type FROM v$encryption_wallet;
```

Contoh output:

```text
    CON_ID STATUS               WALLET_TYPE
---------- -------------------- ------------
         3 OPEN                 PASSWORD

1 row selected.
```

---

## LAB 62 — Day 4 Final Architecture

Peserta sekarang bisa membedakan perubahan stored data, pembatasan tampilan, dan kebutuhan key untuk membaca data terenkripsi. Source customer tetap asli; salinan masked dan subset tersedia; credit card serta SSN terkena redaction untuk REDACT_USER; SECURITY_ADMIN mendapat nilai asli sesuai expression; wallet kembali OPEN.

Oracle Key Vault dan penerapan TSDP otomatis merupakan pengembangan lanjutan, bukan hasil konfigurasi lab ini. Contoh masking manual juga perlu diperkuat sebelum dipakai untuk data production.

## DAY 4 — FINAL PRACTICAL EXAM

Diskusikan kebutuhan berikut dan jelaskan alasan pemilihan kontrol:

1. Data at rest harus terlindungi: TDE.
2. Developer memerlukan data pengganti: masking.
3. Test hanya memerlukan sebagian customer: subsetting dengan relasi utuh.
4. User aplikasi hanya boleh melihat empat digit kartu/SSN: redaction beserta privilege yang sesuai.
5. Data terenkripsi gagal dibaca karena wallet tertutup: buka wallet existing, cek status, lalu ulangi SELECT.
6. Key perlu dikelola terpusat di banyak database: evaluasi Oracle Key Vault sebagai pembahasan lanjutan.

Objek hasil latihan sengaja dipertahankan untuk review. Jika mengulang, gunakan kondisi awal yang sesuai; CREATE USER/TABLE akan gagal jika nama yang sama masih ada. Jangan menghapus source atau wallet existing untuk sekadar mengulang lab.

---

# BAGIAN F — EXPORT & IMPORT: APAKAH PERLINDUNGAN TETAP ADA?

Tambahan ini meneruskan Day 4. Semua command tetap dijalankan satu per satu. Contoh output Data Pump diambil dari pengujian; baris log yang panjang dibungkus agar mudah dibaca. Log mentah disimpan terpisah.

## LAB 63 — Data Pump: Apa yang Sebenarnya Ikut Dipindahkan?

Sekarang kita lanjutkan hasil Day 4 dengan Oracle Data Pump: utility yang digunakan adalah **expdp** dan **impdp**. Tujuannya sederhana: setelah diekspor dan diimpor, apakah kita memperoleh nilai asli, nilai masked, subset yang sama, atau tampilan redacted?

Bedakan dua aspek: **nilai dan jumlah baris**, serta **metadata seperti constraint, policy, dan GRANT**. Kita akan mengimpornya ke schema baru di PDB1 yang sama agar perbandingan terkontrol. Pengujian ini berfokus pada masking, subsetting, dan redaction.

Lanjutkan dari hasil Lab 1–62. Gunakan dua terminal SSH sebagai user OS oracle: terminal A untuk SQL*Plus yang sudah diformat, terminal B untuk expdp/impdp. Set ORACLE_SID, ORACLE_HOME, ORACLE_BASE, dan PATH di terminal B seperti Lab 1. Jalankan setiap blok secara terpisah; tanda backslash menyambung baris untuk **satu** command Data Pump. Password pada contoh adalah password lab.

Dump dalam demo ini memuat data sintetis. Simpan hanya di direktori lab. Nama directory, schema tujuan, dan dump di bagian ini harus belum digunakan ketika memulai. Jangan memakai REUSE_DUMPFILES atau TABLE_EXISTS_ACTION=REPLACE untuk menimpa hasil tanpa pemeriksaan.

Durasi job, timestamp, ukuran file, nama job otomatis, nama constraint SYS_C..., dan urutan beberapa pesan Data Pump dapat berbeda. Contoh di bawah berasal dari job pengujian, termasuk pesan sukses maupun error yang sengaja diuji.

Di SQL*Plus, gunakan SYS untuk pemeriksaan metadata dan nilai tersimpan:

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA
```

 Untuk CONNECT, mode SQL*Plus `-s` tidak menampilkan pesan koneksi.

```sql
SHOW CON_NAME
```

Contoh output:

```text
CON_NAME
------------------------------
PDB1
```

Cek hasilnya:

```sql
SELECT username FROM dba_users WHERE username IN
('DP_LAB','DP_MASK','DP_SUB','DP_RED','DP_NOPOL') ORDER BY username;
```

Contoh output:

```text
no rows selected
```

```sql
COLUMN difference_count FORMAT 999999
```



```sql
COLUMN directory_name FORMAT A18
```



```sql
COLUMN directory_path FORMAT A45
```



```sql
COLUMN grantee FORMAT A18
```



```sql
COLUMN source_count FORMAT 999999
```



```sql
COLUMN imported_count FORMAT 999999
```



Di terminal B, buat folder baru. Command ini sengaja tanpa -p agar keberadaan folder lama terlihat sebagai error:

```bash
mkdir -m 700 /home/oracle/day4_dp_20260910
```



```sql
CREATE DIRECTORY day4_dp AS '/home/oracle/day4_dp_20260910';
```

Contoh output:

```text
Directory created.
```

Cek hasilnya:

```sql
SELECT directory_name, directory_path FROM dba_directories WHERE directory_name='DAY4_DP';
```

Contoh output:

```text
DIRECTORY_NAME     DIRECTORY_PATH
------------------ ---------------------------------------------
DAY4_DP            /home/oracle/day4_dp_20260910

1 row selected.
```

```sql
CREATE USER dp_lab IDENTIFIED BY "DpLab#2026" DEFAULT TABLESPACE users QUOTA 100M ON users;
```

Contoh output:



```sql
GRANT CREATE SESSION, CREATE TABLE TO dp_lab;
```



Role ini dipakai untuk mengekspor tabel milik schema lab lain. Role juga memberi kemampuan melewati redaction; nanti kita buktikan dampaknya.

```sql
GRANT DATAPUMP_EXP_FULL_DATABASE TO dp_lab;
```



Role ini memungkinkan REMAP_SCHEMA ke schema tujuan lab.

```sql
GRANT DATAPUMP_IMP_FULL_DATABASE TO dp_lab;
```



```sql
GRANT READ, WRITE ON DIRECTORY day4_dp TO dp_lab;
```



```sql
CREATE USER dp_mask IDENTIFIED BY "DpTarget#2026" DEFAULT TABLESPACE users QUOTA 100M ON users;
```

Contoh output:



```sql
CREATE USER dp_sub IDENTIFIED BY "DpTarget#2026" DEFAULT TABLESPACE users QUOTA 100M ON users;
```

Contoh output:



```sql
CREATE USER dp_red IDENTIFIED BY "DpTarget#2026" DEFAULT TABLESPACE users QUOTA 100M ON users;
```

Contoh output:



```sql
CREATE USER dp_nopol IDENTIFIED BY "DpTarget#2026" DEFAULT TABLESPACE users QUOTA 100M ON users;
```

Contoh output:



Cek hasilnya:

```sql
SELECT privilege FROM role_sys_privs
WHERE privilege='EXEMPT REDACTION POLICY' AND role IN (
  SELECT 'DATAPUMP_EXP_FULL_DATABASE' FROM dual
  UNION
  SELECT granted_role FROM role_role_privs
  START WITH role='DATAPUMP_EXP_FULL_DATABASE'
  CONNECT BY NOCYCLE PRIOR granted_role=role
);
```

Contoh output:

```text
PRIVILEGE
----------------------------
EXEMPT REDACTION POLICY

1 row selected.
```

---

## LAB 64 — Export dan Import Static Masking

Kita ekspor hanya CUSTOMER dan CUSTOMER_ACCOUNT milik MASKED_OWNER. Karena static masking sudah mengubah stored data, yang perlu dibuktikan adalah apakah hasil impor tetap masked untuk seluruh kolom, bukan hanya empat digit kartu.

Cek hasilnya:

```sql
SELECT customer_id, customer_name, credit_card_number, social_security_number
FROM masked_owner.customer ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID CUSTOMER_NAME      CREDIT_CARD_NUMBER   SOCIAL_SECURITY_NUMBER
----------- ------------------ -------------------- ----------------------
          1 CUSTOMER_1         0000000000001111     000-00-6789
          2 CUSTOMER_2         0000000000004444     000-00-4321
          3 CUSTOMER_3         0000000000000005     000-00-3333

3 rows selected.
```

Di terminal B, jalankan ekspor:

```bash
expdp dp_lab/"DpLab#2026"@localhost:1521/pdb1.localdomain \
  DIRECTORY=DAY4_DP DUMPFILE=day4_mask.dmp \
  LOGFILE=expdp_day4_mask_2.log \
  TABLES=MASKED_OWNER.CUSTOMER,MASKED_OWNER.CUSTOMER_ACCOUNT ENCRYPTION=NONE
```

Contoh output:

```text
Export: Release 19.0.0.0.0 - Production on Thu Sep 10 16:39:49 2026
Version 19.8.0.0.0

Copyright (c) 1982, 2019, Oracle and/or its affiliates.  All rights reserved.

Connected to: Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Starting "DP_LAB"."SYS_EXPORT_TABLE_01":  dp_lab/********@localhost:1521/pdb1.localdomain DIRECTORY=DAY4_DP 
  DUMPFILE=day4_mask.dmp LOGFILE=expdp_day4_mask_2.log 
  TABLES=MASKED_OWNER.CUSTOMER,MASKED_OWNER.CUSTOMER_ACCOUNT ENCRYPTION=NONE
Processing object type TABLE_EXPORT/TABLE/TABLE_DATA
Processing object type TABLE_EXPORT/TABLE/INDEX/STATISTICS/INDEX_STATISTICS
Processing object type TABLE_EXPORT/TABLE/STATISTICS/TABLE_STATISTICS
Processing object type TABLE_EXPORT/TABLE/STATISTICS/MARKER
Processing object type TABLE_EXPORT/TABLE/TABLE
Processing object type TABLE_EXPORT/TABLE/CONSTRAINT/CONSTRAINT
Processing object type TABLE_EXPORT/TABLE/CONSTRAINT/REF_CONSTRAINT
. . exported "MASKED_OWNER"."CUSTOMER"                   8.406 KB       3 rows
. . exported "MASKED_OWNER"."CUSTOMER_ACCOUNT"           6.937 KB       3 rows
Master table "DP_LAB"."SYS_EXPORT_TABLE_01" successfully loaded/unloaded
******************************************************************************
Dump file set for DP_LAB.SYS_EXPORT_TABLE_01 is:
  /home/oracle/day4_dp_20260910/day4_mask.dmp
Job "DP_LAB"."SYS_EXPORT_TABLE_01" successfully completed at Thu Sep 10 16:40:35 2026 elapsed 0 00:00:40
```

Di terminal B, impor ke DP_MASK:

```bash
impdp dp_lab/"DpLab#2026"@localhost:1521/pdb1.localdomain \
  DIRECTORY=DAY4_DP DUMPFILE=day4_mask.dmp \
  LOGFILE=impdp_day4_mask_3.log \
  REMAP_SCHEMA=MASKED_OWNER:DP_MASK
```

Contoh output:

```text
Import: Release 19.0.0.0.0 - Production on Thu Sep 10 16:42:04 2026
Version 19.8.0.0.0

Copyright (c) 1982, 2019, Oracle and/or its affiliates.  All rights reserved.

Connected to: Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Master table "DP_LAB"."SYS_IMPORT_FULL_01" successfully loaded/unloaded
Starting "DP_LAB"."SYS_IMPORT_FULL_01":  dp_lab/********@localhost:1521/pdb1.localdomain DIRECTORY=DAY4_DP 
  DUMPFILE=day4_mask.dmp LOGFILE=impdp_day4_mask_3.log REMAP_SCHEMA=MASKED_OWNER:DP_MASK 
Processing object type TABLE_EXPORT/TABLE/TABLE
Processing object type TABLE_EXPORT/TABLE/TABLE_DATA
. . imported "DP_MASK"."CUSTOMER"                        8.406 KB       3 rows
. . imported "DP_MASK"."CUSTOMER_ACCOUNT"                6.937 KB       3 rows
Processing object type TABLE_EXPORT/TABLE/CONSTRAINT/CONSTRAINT
Processing object type TABLE_EXPORT/TABLE/INDEX/STATISTICS/INDEX_STATISTICS
Processing object type TABLE_EXPORT/TABLE/CONSTRAINT/REF_CONSTRAINT
Processing object type TABLE_EXPORT/TABLE/STATISTICS/TABLE_STATISTICS
Processing object type TABLE_EXPORT/TABLE/STATISTICS/MARKER
Job "DP_LAB"."SYS_IMPORT_FULL_01" successfully completed at Thu Sep 10 16:42:39 2026 elapsed 0 00:00:33
```

Cek hasilnya:

```sql
SELECT customer_id, customer_name, credit_card_number, social_security_number
FROM dp_mask.customer ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID CUSTOMER_NAME      CREDIT_CARD_NUMBER   SOCIAL_SECURITY_NUMBER
----------- ------------------ -------------------- ----------------------
          1 CUSTOMER_1         0000000000001111     000-00-6789
          2 CUSTOMER_2         0000000000004444     000-00-4321
          3 CUSTOMER_3         0000000000000005     000-00-3333

3 rows selected.
```

Cek hasilnya:

```sql
SELECT account_id, customer_id, account_number, balance FROM dp_mask.customer_account ORDER BY account_id;
```

Contoh output:

```text
ACCOUNT_ID CUSTOMER_ID ACCOUNT_NUMBER               BALANCE
---------- ----------- -------------------- ---------------
      1001           1 9999999999993456       16,250,000.00
      1002           1 9999999999993457        9,750,000.00
      1003           2 9999999999993458       22,750,000.00

3 rows selected.
```

Cek hasilnya:

```sql
SELECT COUNT(*) AS difference_count FROM (
  SELECT * FROM (SELECT * FROM masked_owner.customer MINUS SELECT * FROM dp_mask.customer)
  UNION ALL
  SELECT * FROM (SELECT * FROM dp_mask.customer MINUS SELECT * FROM masked_owner.customer)
);
```

Contoh output:

```text
DIFFERENCE_COUNT
----------------
               0

1 row selected.
```

Cek hasilnya:

```sql
SELECT COUNT(*) AS difference_count FROM (
  SELECT * FROM (SELECT * FROM masked_owner.customer_account MINUS SELECT * FROM dp_mask.customer_account)
  UNION ALL
  SELECT * FROM (SELECT * FROM dp_mask.customer_account MINUS SELECT * FROM masked_owner.customer_account)
);
```

Contoh output:

```text
DIFFERENCE_COUNT
----------------
               0

1 row selected.
```

Cek hasilnya:

```sql
SELECT constraint_name, constraint_type, status FROM dba_constraints
WHERE owner='DP_MASK' AND constraint_type IN ('P','R') ORDER BY constraint_name;
```

Contoh output:

```text
CONSTRAINT_NAME           CONSTRAINT_TYPE STATUS
------------------------- --------------- --------------------
MASKED_FK_CUSTOMER        R               ENABLED
SYS_C007750               P               ENABLED
SYS_C007751               P               ENABLED

3 rows selected.
```

---

## LAB 65 — Export dan Import Subset Mentah serta Subset Masked

SUBSET_OWNER memuat dua versi: CUSTOMER/CUSTOMER_ACCOUNT masih bernilai asli, sedangkan CUSTOMER_MASKED/CUSTOMER_ACCOUNT_MASKED sudah di-masking. Kita ekspor keempat tabel agar perbedaannya terlihat jelas. Subsetting mengurangi baris; ia tidak otomatis menyembunyikan nilai asli.

```bash
expdp dp_lab/"DpLab#2026"@localhost:1521/pdb1.localdomain \
  DIRECTORY=DAY4_DP DUMPFILE=day4_subset.dmp \
  LOGFILE=expdp_day4_subset_1.log \
  TABLES=SUBSET_OWNER.CUSTOMER,SUBSET_OWNER.CUSTOMER_ACCOUNT,SUBSET_OWNER.CUSTOMER_MASKED,SUBSET_OWNER.CUSTOMER_ACCOUNT_MASKED ENCRYPTION=NONE
```

Contoh output:

```text
Export: Release 19.0.0.0.0 - Production on Thu Sep 10 16:45:49 2026
Version 19.8.0.0.0

Copyright (c) 1982, 2019, Oracle and/or its affiliates.  All rights reserved.

Connected to: Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Starting "DP_LAB"."SYS_EXPORT_TABLE_01":  dp_lab/********@localhost:1521/pdb1.localdomain DIRECTORY=DAY4_DP 
  DUMPFILE=day4_subset.dmp LOGFILE=expdp_day4_subset_1.log TABLES=SUBSET_OWNER.CUSTOMER,SUBSET_OWNER.CUSTOMER_AC
  COUNT,SUBSET_OWNER.CUSTOMER_MASKED,SUBSET_OWNER.CUSTOMER_ACCOUNT_MASKED ENCRYPTION=NONE 
Processing object type TABLE_EXPORT/TABLE/TABLE_DATA
Processing object type TABLE_EXPORT/TABLE/INDEX/STATISTICS/INDEX_STATISTICS
Processing object type TABLE_EXPORT/TABLE/STATISTICS/TABLE_STATISTICS
Processing object type TABLE_EXPORT/TABLE/STATISTICS/MARKER
Processing object type TABLE_EXPORT/TABLE/TABLE
Processing object type TABLE_EXPORT/TABLE/CONSTRAINT/CONSTRAINT
Processing object type TABLE_EXPORT/TABLE/CONSTRAINT/REF_CONSTRAINT
. . exported "SUBSET_OWNER"."CUSTOMER_MASKED"            8.265 KB       2 rows
. . exported "SUBSET_OWNER"."CUSTOMER"                   8.296 KB       2 rows
. . exported "SUBSET_OWNER"."CUSTOMER_ACCOUNT_MASKED"    6.890 KB       3 rows
. . exported "SUBSET_OWNER"."CUSTOMER_ACCOUNT"           6.937 KB       3 rows
Master table "DP_LAB"."SYS_EXPORT_TABLE_01" successfully loaded/unloaded
******************************************************************************
Dump file set for DP_LAB.SYS_EXPORT_TABLE_01 is:
  /home/oracle/day4_dp_20260910/day4_subset.dmp
Job "DP_LAB"."SYS_EXPORT_TABLE_01" successfully completed at Thu Sep 10 16:46:30 2026 elapsed 0 00:00:39
```

```bash
impdp dp_lab/"DpLab#2026"@localhost:1521/pdb1.localdomain \
  DIRECTORY=DAY4_DP DUMPFILE=day4_subset.dmp \
  LOGFILE=impdp_day4_subset_2.log \
  REMAP_SCHEMA=SUBSET_OWNER:DP_SUB
```

Contoh output:

```text
Import: Release 19.0.0.0.0 - Production on Thu Sep 10 16:46:53 2026
Version 19.8.0.0.0

Copyright (c) 1982, 2019, Oracle and/or its affiliates.  All rights reserved.

Connected to: Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Master table "DP_LAB"."SYS_IMPORT_FULL_01" successfully loaded/unloaded
Starting "DP_LAB"."SYS_IMPORT_FULL_01":  dp_lab/********@localhost:1521/pdb1.localdomain DIRECTORY=DAY4_DP 
  DUMPFILE=day4_subset.dmp LOGFILE=impdp_day4_subset_2.log REMAP_SCHEMA=SUBSET_OWNER:DP_SUB 
Processing object type TABLE_EXPORT/TABLE/TABLE
Processing object type TABLE_EXPORT/TABLE/TABLE_DATA
. . imported "DP_SUB"."CUSTOMER_MASKED"                  8.265 KB       2 rows
. . imported "DP_SUB"."CUSTOMER"                         8.296 KB       2 rows
. . imported "DP_SUB"."CUSTOMER_ACCOUNT_MASKED"          6.890 KB       3 rows
. . imported "DP_SUB"."CUSTOMER_ACCOUNT"                 6.937 KB       3 rows
Processing object type TABLE_EXPORT/TABLE/CONSTRAINT/CONSTRAINT
Processing object type TABLE_EXPORT/TABLE/INDEX/STATISTICS/INDEX_STATISTICS
Processing object type TABLE_EXPORT/TABLE/CONSTRAINT/REF_CONSTRAINT
Processing object type TABLE_EXPORT/TABLE/STATISTICS/TABLE_STATISTICS
Processing object type TABLE_EXPORT/TABLE/STATISTICS/MARKER
Job "DP_LAB"."SYS_IMPORT_FULL_01" successfully completed at Thu Sep 10 16:47:29 2026 elapsed 0 00:00:35
```

Cek hasilnya:

```sql
SELECT (SELECT COUNT(*) FROM discovery_owner.customer) AS source_count,
       (SELECT COUNT(*) FROM dp_sub.customer) AS imported_count FROM dual;
```

Contoh output:

```text
SOURCE_COUNT IMPORTED_COUNT
------------ --------------
           3              2

1 row selected.
```

Cek hasilnya:

```sql
SELECT customer_id, customer_name, credit_card_number, social_security_number
FROM dp_sub.customer ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID CUSTOMER_NAME      CREDIT_CARD_NUMBER   SOCIAL_SECURITY_NUMBER
----------- ------------------ -------------------- ----------------------
          1 JOHN DOE           4111111111111111     123-45-6789
          2 JANE DOE           5555555555554444     987-65-4321

2 rows selected.
```

Cek hasilnya:

```sql
SELECT customer_id, customer_name, credit_card_number, social_security_number
FROM dp_sub.customer_masked ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID CUSTOMER_NAME      CREDIT_CARD_NUMBER   SOCIAL_SECURITY_NUMBER
----------- ------------------ -------------------- ----------------------
          1 CUSTOMER_1         0000000000001111     000-00-6789
          2 CUSTOMER_2         0000000000004444     000-00-4321

2 rows selected.
```

Cek hasilnya:

```sql
SELECT account_id, customer_id, account_number, balance
FROM dp_sub.customer_account_masked ORDER BY account_id;
```

Contoh output:

```text
ACCOUNT_ID CUSTOMER_ID ACCOUNT_NUMBER               BALANCE
---------- ----------- -------------------- ---------------
      1001           1 9999999999993456       16,250,000.00
      1002           1 9999999999993457        9,750,000.00
      1003           2 9999999999993458       22,750,000.00

3 rows selected.
```

Cek hasilnya:

```sql
SELECT COUNT(*) AS difference_count FROM (
  SELECT * FROM (SELECT * FROM subset_owner.customer MINUS SELECT * FROM dp_sub.customer)
  UNION ALL
  SELECT * FROM (SELECT * FROM dp_sub.customer MINUS SELECT * FROM subset_owner.customer)
);
```

Contoh output:

```text
DIFFERENCE_COUNT
----------------
               0

1 row selected.
```

Cek hasilnya:

```sql
SELECT COUNT(*) AS difference_count FROM (
  SELECT * FROM (SELECT * FROM subset_owner.customer_account MINUS SELECT * FROM dp_sub.customer_account)
  UNION ALL
  SELECT * FROM (SELECT * FROM dp_sub.customer_account MINUS SELECT * FROM subset_owner.customer_account)
);
```

Contoh output:

```text
DIFFERENCE_COUNT
----------------
               0

1 row selected.
```

Cek hasilnya:

```sql
SELECT COUNT(*) AS difference_count FROM (
  SELECT * FROM (SELECT * FROM subset_owner.customer_masked MINUS SELECT * FROM dp_sub.customer_masked)
  UNION ALL
  SELECT * FROM (SELECT * FROM dp_sub.customer_masked MINUS SELECT * FROM subset_owner.customer_masked)
);
```

Contoh output:

```text
DIFFERENCE_COUNT
----------------
               0

1 row selected.
```

Cek hasilnya:

```sql
SELECT COUNT(*) AS difference_count FROM (
  SELECT * FROM (SELECT * FROM subset_owner.customer_account_masked MINUS SELECT * FROM dp_sub.customer_account_masked)
  UNION ALL
  SELECT * FROM (SELECT * FROM dp_sub.customer_account_masked MINUS SELECT * FROM subset_owner.customer_account_masked)
);
```

Contoh output:

```text
DIFFERENCE_COUNT
----------------
               0

1 row selected.
```

Cek hasilnya:

```sql
SELECT COUNT(*) AS orphan_count FROM dp_sub.customer_account_masked a
WHERE NOT EXISTS (SELECT 1 FROM dp_sub.customer_masked c WHERE c.customer_id=a.customer_id);
```

Contoh output:

```text
ORPHAN_COUNT
------------
           0

1 row selected.
```

Cek hasilnya:

```sql
SELECT constraint_name, constraint_type, status FROM dba_constraints
WHERE owner='DP_SUB' AND constraint_type IN ('P','R') ORDER BY constraint_name;
```

Contoh output:

```text
CONSTRAINT_NAME           CONSTRAINT_TYPE STATUS
------------------------- --------------- --------------------
SUBSET_ACCOUNT_PK         P               ENABLED
SUBSET_CUSTOMER_PK        P               ENABLED
SUBSET_FK_CUSTOMER        R               ENABLED
SUBSET_MASKED_ACCOUNT_PK  P               ENABLED
SUBSET_MASKED_CUSTOMER_PK P               ENABLED
SUBSET_MASKED_FK_CUSTOMER R               ENABLED

6 rows selected.
```

---

## LAB 66 — Export Redaction dan Periksa REMAP_SCHEMA pada Oracle 19.8

Lihat dulu sebagai user aplikasi. Setelah itu DP_LAB mengekspor tabel dengan privilege ekspor yang dapat melewati redaction. Kita periksa terpisah nilai tersimpan dan metadata policy setelah impor.

Rujukan perilaku: [Oracle 19c—Data Redaction dan Data Pump](https://docs.oracle.com/en/database/oracle/oracle-database/19/asoag/oracle-data-redaction-use-with-oracle-database-features.html).

Ganti koneksi SQL*Plus menjadi user aplikasi:

```sql
CONNECT redact_user/"Redact#2026"@localhost:1521/pdb1.localdomain
```

 Untuk CONNECT, mode SQL*Plus `-s` tidak menampilkan pesan koneksi.

Cek hasilnya:

```sql
SELECT customer_id, customer_name, credit_card_number, social_security_number
FROM discovery_owner.customer ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID CUSTOMER_NAME      CREDIT_CARD_NUMBER   SOCIAL_SECURITY_NUMBER
----------- ------------------ -------------------- ----------------------
          1 JOHN DOE           ************1111     ***-**-6789
          2 JANE DOE           ************4444     ***-**-4321
          3 ALICE              ************0005     ***-**-3333

3 rows selected.
```

Di SQL*Plus, gunakan SYS untuk pemeriksaan metadata dan nilai tersimpan:

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA
```

 Untuk CONNECT, mode SQL*Plus `-s` tidak menampilkan pesan koneksi.

```bash
expdp dp_lab/"DpLab#2026"@localhost:1521/pdb1.localdomain \
  DIRECTORY=DAY4_DP DUMPFILE=day4_redact.dmp \
  LOGFILE=expdp_day4_redact_4.log \
  TABLES=DISCOVERY_OWNER.CUSTOMER ENCRYPTION=NONE
```

Contoh output:

```text
Export: Release 19.0.0.0.0 - Production on Thu Sep 10 16:48:23 2026
Version 19.8.0.0.0

Copyright (c) 1982, 2019, Oracle and/or its affiliates.  All rights reserved.

Connected to: Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Starting "DP_LAB"."SYS_EXPORT_TABLE_01":  dp_lab/********@localhost:1521/pdb1.localdomain DIRECTORY=DAY4_DP 
  DUMPFILE=day4_redact.dmp LOGFILE=expdp_day4_redact_4.log TABLES=DISCOVERY_OWNER.CUSTOMER ENCRYPTION=NONE 
Processing object type TABLE_EXPORT/TABLE/TABLE_DATA
Processing object type TABLE_EXPORT/TABLE/INDEX/STATISTICS/INDEX_STATISTICS
Processing object type TABLE_EXPORT/TABLE/STATISTICS/TABLE_STATISTICS
Processing object type TABLE_EXPORT/TABLE/STATISTICS/MARKER
Processing object type TABLE_EXPORT/TABLE/TABLE
Processing object type TABLE_EXPORT/TABLE/RADM_POLICY
Processing object type TABLE_EXPORT/TABLE/GRANT/OWNER_GRANT/OBJECT_GRANT
Processing object type TABLE_EXPORT/TABLE/CONSTRAINT/CONSTRAINT
. . exported "DISCOVERY_OWNER"."CUSTOMER"                8.382 KB       3 rows
Master table "DP_LAB"."SYS_EXPORT_TABLE_01" successfully loaded/unloaded
******************************************************************************
Dump file set for DP_LAB.SYS_EXPORT_TABLE_01 is:
  /home/oracle/day4_dp_20260910/day4_redact.dmp
Job "DP_LAB"."SYS_EXPORT_TABLE_01" successfully completed at Thu Sep 10 16:49:05 2026 elapsed 0 00:00:39
```

Pada VM 19.8 ini, impor data berhasil tetapi pembuatan policy gagal: PL/SQL metadata policy masih menunjuk DISCOVERY_OWNER. Jangan menghapus policy sumber untuk mengatasi error ini.

```bash
impdp dp_lab/"DpLab#2026"@localhost:1521/pdb1.localdomain \
  DIRECTORY=DAY4_DP DUMPFILE=day4_redact.dmp \
  LOGFILE=impdp_day4_redact_5.log \
  REMAP_SCHEMA=DISCOVERY_OWNER:DP_RED
```

Contoh output (error/warning ini disengaja):

```text
Import: Release 19.0.0.0.0 - Production on Thu Sep 10 16:49:24 2026
Version 19.8.0.0.0

Copyright (c) 1982, 2019, Oracle and/or its affiliates.  All rights reserved.

Connected to: Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Master table "DP_LAB"."SYS_IMPORT_FULL_01" successfully loaded/unloaded
Starting "DP_LAB"."SYS_IMPORT_FULL_01":  dp_lab/********@localhost:1521/pdb1.localdomain DIRECTORY=DAY4_DP 
  DUMPFILE=day4_redact.dmp LOGFILE=impdp_day4_redact_5.log REMAP_SCHEMA=DISCOVERY_OWNER:DP_RED 
Processing object type TABLE_EXPORT/TABLE/TABLE
Processing object type TABLE_EXPORT/TABLE/RADM_POLICY
ORA-39083: Object type RADM_POLICY failed to create with error:
ORA-28069: A data redaction policy already exists on this object.

Failing sql is:
BEGIN DBMS_REDACT.ADD_POLICY(object_schema => '"DISCOVERY_OWNER"', object_name => '"CUSTOMER"', policy_name => 
  'REDACT_CC_POLICY', expression => 'SYS_CONTEXT(''USERENV'',''SESSION_USER'') <> ''SECURITY_ADMIN''', enable =>
   TRUE); 
DBMS_REDACT.ALTER_POLICY (object_schema => '"DISCOVERY_OWNER"', object_name => '"CUSTOMER"', policy_name => 
  'REDACT_CC_POLICY', action => DBMS_REDACT.ADD_COLUMN, column_name => '"CREDIT_CARD_NUMBER"', function_type => 
  DBMS_REDACT.REGEXP, regexp_pattern => '^([[:digit:]]+)([[:digit:]]{4})$', regexp_replace_string => 
  '************\2', regexp_position => '1', regexp_occurrence => '0', regexp_match_parameter => 'c', 
  function_parameters => NULL); 
DBMS_REDACT.ALTER_POLICY (object_schema => '"DISCOVERY_OWNER"', object_name => '"CUSTOMER"', policy_name => 
  'REDACT_CC_POLICY', action => DBMS_REDACT.ADD_COLUMN, column_name => '"SOCIAL_SECURITY_NUMBER"', function_type
   => DBMS_REDACT.PARTIAL, function_parameters => 'VVVFVVFVVVV,VVV-VV-VVVV,*,1,5'); 
END; 

Processing object type TABLE_EXPORT/TABLE/TABLE_DATA
. . imported "DP_RED"."CUSTOMER"                         8.382 KB       3 rows
Processing object type TABLE_EXPORT/TABLE/GRANT/OWNER_GRANT/OBJECT_GRANT
Processing object type TABLE_EXPORT/TABLE/CONSTRAINT/CONSTRAINT
Processing object type TABLE_EXPORT/TABLE/INDEX/STATISTICS/INDEX_STATISTICS
Processing object type TABLE_EXPORT/TABLE/STATISTICS/TABLE_STATISTICS
Processing object type TABLE_EXPORT/TABLE/STATISTICS/MARKER
Job "DP_LAB"."SYS_IMPORT_FULL_01" completed with 1 error(s) at Thu Sep 10 16:49:58 2026 elapsed 0 00:00:33
```

Cek hasilnya:

```sql
SELECT customer_id, customer_name, credit_card_number, social_security_number
FROM dp_red.customer ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID CUSTOMER_NAME      CREDIT_CARD_NUMBER   SOCIAL_SECURITY_NUMBER
----------- ------------------ -------------------- ----------------------
          1 JOHN DOE           4111111111111111     123-45-6789
          2 JANE DOE           5555555555554444     987-65-4321
          3 ALICE              378282246310005      111-22-3333

3 rows selected.
```

Cek hasilnya:

```sql
SELECT COUNT(*) AS difference_count FROM (
  SELECT * FROM (SELECT * FROM discovery_owner.customer MINUS SELECT * FROM dp_red.customer)
  UNION ALL
  SELECT * FROM (SELECT * FROM dp_red.customer MINUS SELECT * FROM discovery_owner.customer)
);
```

Contoh output:

```text
DIFFERENCE_COUNT
----------------
               0

1 row selected.
```

Cek hasilnya:

```sql
SELECT object_owner, object_name, policy_name, enable
FROM redaction_policies WHERE object_owner='DP_RED';
```

Contoh output:

```text
no rows selected
```

Cek hasilnya:

```sql
SELECT column_name, function_type FROM redaction_columns
WHERE object_owner='DP_RED' ORDER BY column_name;
```

Contoh output:

```text
no rows selected
```

Cek hasilnya:

```sql
SELECT grantee, privilege FROM dba_tab_privs
WHERE owner='DP_RED' AND table_name='CUSTOMER' ORDER BY grantee, privilege;
```

Contoh output:

```text
GRANTEE            PRIVILEGE
------------------ ----------------------------
REDACT_USER        SELECT
SECURITY_ADMIN     SELECT

2 rows selected.
```

Ganti koneksi SQL*Plus menjadi user aplikasi:

```sql
CONNECT redact_user/"Redact#2026"@localhost:1521/pdb1.localdomain
```

 Untuk CONNECT, mode SQL*Plus `-s` tidak menampilkan pesan koneksi.

Cek hasilnya:

```sql
SELECT customer_id, customer_name, credit_card_number, social_security_number
FROM dp_red.customer ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID CUSTOMER_NAME      CREDIT_CARD_NUMBER   SOCIAL_SECURITY_NUMBER
----------- ------------------ -------------------- ----------------------
          1 JOHN DOE           4111111111111111     123-45-6789
          2 JANE DOE           5555555555554444     987-65-4321
          3 ALICE              378282246310005      111-22-3333

3 rows selected.
```

Bandingkan sebagai user yang dikecualikan oleh expression policy:

```sql
CONNECT security_admin/"Security#2026"@localhost:1521/pdb1.localdomain
```

 Untuk CONNECT, mode SQL*Plus `-s` tidak menampilkan pesan koneksi.

Cek hasilnya:

```sql
SELECT customer_id, customer_name, credit_card_number, social_security_number
FROM dp_red.customer ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID CUSTOMER_NAME      CREDIT_CARD_NUMBER   SOCIAL_SECURITY_NUMBER
----------- ------------------ -------------------- ----------------------
          1 JOHN DOE           4111111111111111     123-45-6789
          2 JANE DOE           5555555555554444     987-65-4321
          3 ALICE              378282246310005      111-22-3333

3 rows selected.
```

Di SQL*Plus, gunakan SYS untuk pemeriksaan metadata dan nilai tersimpan:

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA
```

 Untuk CONNECT, mode SQL*Plus `-s` tidak menampilkan pesan koneksi.

---

## LAB 66A — Perbaiki Policy pada Schema Tujuan

Pengujian Lab 66 menunjukkan mengapa log job dan metadata perlu diperiksa: data serta GRANT sudah masuk, tetapi policy gagal karena referensi schema dalam PL/SQL tidak ikut berubah. Akibatnya REDACT_USER masih melihat nilai asli pada DP_RED. Sekarang kita terapkan policy yang sama pada target yang benar, tanpa menyentuh policy sumber. Ini koreksi khusus hasil pengujian REMAP_SCHEMA pada VM 19.8, bukan alasan menganggap semua impor lintas-schema otomatis aman.

Rujukan batas remapping: [Oracle 19c Data Pump Import—REMAP_SCHEMA](https://docs.oracle.com/en/database/oracle/oracle-database/19/sutil/datapump-import-utility.html).

```sql
BEGIN
  DBMS_REDACT.ADD_POLICY(
    object_schema => 'DP_RED', object_name => 'CUSTOMER',
    policy_name => 'REDACT_CC_POLICY', column_name => 'CREDIT_CARD_NUMBER',
    function_type => DBMS_REDACT.REGEXP,
    regexp_pattern => '^([[:digit:]]+)([[:digit:]]{4})$',
    regexp_replace_string => '************\2',
    regexp_position => 1, regexp_occurrence => 0, regexp_match_parameter => 'c',
    expression => 'SYS_CONTEXT(''USERENV'',''SESSION_USER'') <> ''SECURITY_ADMIN'''
  );
END;
/
```

Contoh output:

```text
PL/SQL procedure successfully completed.
```

```sql
BEGIN
  DBMS_REDACT.ALTER_POLICY(
    object_schema => 'DP_RED', object_name => 'CUSTOMER',
    policy_name => 'REDACT_CC_POLICY', action => DBMS_REDACT.ADD_COLUMN,
    column_name => 'SOCIAL_SECURITY_NUMBER', function_type => DBMS_REDACT.PARTIAL,
    function_parameters => 'VVVFVVFVVVV,VVV-VV-VVVV,*,1,5'
  );
END;
/
```

Contoh output:

```text
PL/SQL procedure successfully completed.
```

Cek hasilnya:

```sql
SELECT object_owner, object_name, policy_name, enable FROM redaction_policies
WHERE object_owner IN ('DISCOVERY_OWNER','DP_RED') ORDER BY object_owner;
```

Contoh output:

```text
OBJECT_OWNER       OBJECT_NAME              POLICY_NAME              ENABLE
------------------ ------------------------ ------------------------ --------
DISCOVERY_OWNER    CUSTOMER                 REDACT_CC_POLICY         YES
DP_RED             CUSTOMER                 REDACT_CC_POLICY         YES

2 rows selected.
```

Cek hasilnya:

```sql
SELECT column_name, function_type FROM redaction_columns WHERE object_owner='DP_RED' ORDER BY column_name;
```

Contoh output:

```text
COLUMN_NAME               FUNCTION_TYPE
------------------------- ----------------------
CREDIT_CARD_NUMBER        REGEXP REDACTION
SOCIAL_SECURITY_NUMBER    PARTIAL REDACTION

2 rows selected.
```

Ganti koneksi SQL*Plus menjadi user aplikasi:

```sql
CONNECT redact_user/"Redact#2026"@localhost:1521/pdb1.localdomain
```

 Untuk CONNECT, mode SQL*Plus `-s` tidak menampilkan pesan koneksi.

Cek hasilnya:

```sql
SELECT customer_id, customer_name, credit_card_number, social_security_number
FROM dp_red.customer ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID CUSTOMER_NAME      CREDIT_CARD_NUMBER   SOCIAL_SECURITY_NUMBER
----------- ------------------ -------------------- ----------------------
          1 JOHN DOE           ************1111     ***-**-6789
          2 JANE DOE           ************4444     ***-**-4321
          3 ALICE              ************0005     ***-**-3333

3 rows selected.
```

Bandingkan sebagai user yang dikecualikan oleh expression policy:

```sql
CONNECT security_admin/"Security#2026"@localhost:1521/pdb1.localdomain
```

 Untuk CONNECT, mode SQL*Plus `-s` tidak menampilkan pesan koneksi.

Cek hasilnya:

```sql
SELECT customer_id, customer_name, credit_card_number, social_security_number
FROM dp_red.customer ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID CUSTOMER_NAME      CREDIT_CARD_NUMBER   SOCIAL_SECURITY_NUMBER
----------- ------------------ -------------------- ----------------------
          1 JOHN DOE           4111111111111111     123-45-6789
          2 JANE DOE           5555555555554444     987-65-4321
          3 ALICE              378282246310005      111-22-3333

3 rows selected.
```

Di SQL*Plus, gunakan SYS untuk pemeriksaan metadata dan nilai tersimpan:

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA
```

 Untuk CONNECT, mode SQL*Plus `-s` tidak menampilkan pesan koneksi.

---

## LAB 67 — Import dengan Policy Redaction Dikecualikan

Sekarang gunakan dump yang sama, tetapi sengaja jangan impor metadata policy redaction. Ini memperlihatkan bahwa redaction tidak mengganti stored data menjadi bintang. Pengujian dilakukan hanya pada schema tujuan baru DP_NOPOL; policy sumber tetap aktif.

Cek hasilnya:

```sql
SELECT CAST(object_path AS VARCHAR2(40)) AS object_path FROM table_export_objects WHERE object_path LIKE '%RADM%' ORDER BY object_path;
```

Contoh output:

```text
OBJECT_PATH
----------------------------------------
RADM_POLICY
TABLE/RADM_POLICY
TABLE_EXPORT/TABLE/RADM_POLICY

3 rows selected.
```

```bash
impdp dp_lab/"DpLab#2026"@localhost:1521/pdb1.localdomain \
  DIRECTORY=DAY4_DP DUMPFILE=day4_redact.dmp \
  LOGFILE=impdp_day4_redact_2.log \
  REMAP_SCHEMA=DISCOVERY_OWNER:DP_NOPOL EXCLUDE=RADM_POLICY
```

Contoh output:

```text
Import: Release 19.0.0.0.0 - Production on Fri Sep 11 00:58:26 2026
Version 19.8.0.0.0

Copyright (c) 1982, 2019, Oracle and/or its affiliates.  All rights reserved.

Connected to: Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Master table "DP_LAB"."SYS_IMPORT_FULL_01" successfully loaded/unloaded
Starting "DP_LAB"."SYS_IMPORT_FULL_01":  dp_lab/********@localhost:1521/pdb1.localdomain DIRECTORY=DAY4_DP 
  DUMPFILE=day4_redact.dmp LOGFILE=impdp_day4_redact_2.log REMAP_SCHEMA=DISCOVERY_OWNER:DP_NOPOL 
  EXCLUDE=RADM_POLICY 
Processing object type TABLE_EXPORT/TABLE/TABLE
Processing object type TABLE_EXPORT/TABLE/TABLE_DATA
. . imported "DP_NOPOL"."CUSTOMER"                       8.382 KB       3 rows
Processing object type TABLE_EXPORT/TABLE/GRANT/OWNER_GRANT/OBJECT_GRANT
Processing object type TABLE_EXPORT/TABLE/CONSTRAINT/CONSTRAINT
Processing object type TABLE_EXPORT/TABLE/INDEX/STATISTICS/INDEX_STATISTICS
Processing object type TABLE_EXPORT/TABLE/STATISTICS/TABLE_STATISTICS
Processing object type TABLE_EXPORT/TABLE/STATISTICS/MARKER
Job "DP_LAB"."SYS_IMPORT_FULL_01" successfully completed at Fri Sep 11 00:59:11 2026 elapsed 0 00:00:42
```

Cek hasilnya:

```sql
SELECT object_owner, object_name, policy_name FROM redaction_policies WHERE object_owner='DP_NOPOL';
```

Contoh output:

```text
no rows selected
```

Ganti koneksi SQL*Plus menjadi user aplikasi:

```sql
CONNECT redact_user/"Redact#2026"@localhost:1521/pdb1.localdomain
```

 Untuk CONNECT, mode SQL*Plus `-s` tidak menampilkan pesan koneksi.

Cek hasilnya:

```sql
SELECT customer_id, customer_name, credit_card_number, social_security_number
FROM dp_nopol.customer ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID CUSTOMER_NAME      CREDIT_CARD_NUMBER   SOCIAL_SECURITY_NUMBER
----------- ------------------ -------------------- ----------------------
          1 JOHN DOE           4111111111111111     123-45-6789
          2 JANE DOE           5555555555554444     987-65-4321
          3 ALICE              378282246310005      111-22-3333

3 rows selected.
```

Di SQL*Plus, gunakan SYS untuk pemeriksaan metadata dan nilai tersimpan:

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA
```

 Untuk CONNECT, mode SQL*Plus `-s` tidak menampilkan pesan koneksi.

---

## LAB 68 — GRANT dan Data-Only Import: Apa yang Tidak Otomatis Terbawa?

Kita buat tabel target kosong sendiri, lalu impor DATA_ONLY dari dump redaction. Karena hanya data yang dimuat, policy dan GRANT dari dump tidak diterapkan. Tabel ini sengaja hanya memiliki primary key dan struktur kolom sesuai sumber.

```sql
CREATE TABLE dp_nopol.customer_data_only (
  customer_id NUMBER PRIMARY KEY, customer_name VARCHAR2(100),
  email_address VARCHAR2(200), phone_number VARCHAR2(30),
  credit_card_number VARCHAR2(30), social_security_number VARCHAR2(30),
  date_of_birth DATE, salary NUMBER(15,2)
);
```



Tabel target masih kosong. APPEND menambahkan baris; jangan mengulang command ini pada tabel yang sudah berisi data.

```bash
impdp dp_lab/"DpLab#2026"@localhost:1521/pdb1.localdomain \
  DIRECTORY=DAY4_DP DUMPFILE=day4_redact.dmp \
  LOGFILE=impdp_day4_redact_2_dataonly.log \
  REMAP_SCHEMA=DISCOVERY_OWNER:DP_NOPOL REMAP_TABLE=CUSTOMER:CUSTOMER_DATA_ONLY CONTENT=DATA_ONLY TABLE_EXISTS_ACTION=APPEND
```

Contoh output:

```text
Import: Release 19.0.0.0.0 - Production on Fri Sep 11 01:00:55 2026
Version 19.8.0.0.0

Copyright (c) 1982, 2019, Oracle and/or its affiliates.  All rights reserved.

Connected to: Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Master table "DP_LAB"."SYS_IMPORT_FULL_01" successfully loaded/unloaded
Starting "DP_LAB"."SYS_IMPORT_FULL_01":  dp_lab/********@localhost:1521/pdb1.localdomain DIRECTORY=DAY4_DP 
  DUMPFILE=day4_redact.dmp LOGFILE=impdp_day4_redact_2_dataonly.log REMAP_SCHEMA=DISCOVERY_OWNER:DP_NOPOL 
  REMAP_TABLE=CUSTOMER:CUSTOMER_DATA_ONLY CONTENT=DATA_ONLY TABLE_EXISTS_ACTION=APPEND 
Processing object type TABLE_EXPORT/TABLE/TABLE_DATA
. . imported "DP_NOPOL"."CUSTOMER_DATA_ONLY"             8.382 KB       3 rows
Job "DP_LAB"."SYS_IMPORT_FULL_01" successfully completed at Fri Sep 11 01:01:11 2026 elapsed 0 00:00:13
```

Cek hasilnya:

```sql
SELECT COUNT(*) AS imported_count FROM dp_nopol.customer_data_only;
```

Contoh output:

```text
IMPORTED_COUNT
--------------
             3

1 row selected.
```

Cek hasilnya:

```sql
SELECT policy_name FROM redaction_policies WHERE object_owner='DP_NOPOL' AND object_name='CUSTOMER_DATA_ONLY';
```

Contoh output:

```text
no rows selected
```

Ganti koneksi SQL*Plus menjadi user aplikasi:

```sql
CONNECT redact_user/"Redact#2026"@localhost:1521/pdb1.localdomain
```

 Untuk CONNECT, mode SQL*Plus `-s` tidak menampilkan pesan koneksi.

SELECT ditolak karena belum ada GRANT untuk tabel target ini:

```sql
SELECT customer_id, credit_card_number FROM dp_nopol.customer_data_only ORDER BY customer_id;
```

Contoh output (error/warning ini disengaja):

```text
SELECT customer_id, credit_card_number FROM dp_nopol.customer_data_only ORDER BY customer_id
                                                     *
ERROR at line 1:
ORA-00942: table or view does not exist
```

Di SQL*Plus, gunakan SYS untuk pemeriksaan metadata dan nilai tersimpan:

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA
```

 Untuk CONNECT, mode SQL*Plus `-s` tidak menampilkan pesan koneksi.

```sql
GRANT SELECT ON dp_nopol.customer_data_only TO redact_user;
```



Ganti koneksi SQL*Plus menjadi user aplikasi:

```sql
CONNECT redact_user/"Redact#2026"@localhost:1521/pdb1.localdomain
```

 Untuk CONNECT, mode SQL*Plus `-s` tidak menampilkan pesan koneksi.

Cek hasilnya:

```sql
SELECT customer_id, credit_card_number, social_security_number FROM dp_nopol.customer_data_only ORDER BY customer_id;
```

Contoh output:

```text
CUSTOMER_ID CREDIT_CARD_NUMBER   SOCIAL_SECURITY_NUMBER
----------- -------------------- ----------------------
          1 4111111111111111     123-45-6789
          2 5555555555554444     987-65-4321
          3 378282246310005      111-22-3333

3 rows selected.
```

Di SQL*Plus, gunakan SYS untuk pemeriksaan metadata dan nilai tersimpan:

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA
```

 Untuk CONNECT, mode SQL*Plus `-s` tidak menampilkan pesan koneksi.

---

## LAB 69 — Kesimpulan Export dan Import

Bandingkan hasil pengujian berikut.

| Skenario | Hasil setelah impor |
| --- | --- |
| Static masking | Nilai tetap masked; tidak kembali ke source asli. |
| Subsetting mentah | Customer tetap dua baris; nilai tetap asli. |
| Subsetting + masking | Tetap dua customer dan nilai tetap masked. |
| Redaction dengan REMAP_SCHEMA pada VM 19.8 | Stored data asli ikut diimpor. Metadata policy gagal dibuat karena masih menunjuk schema sumber; harus dikoreksi seperti Lab 66A. |
| Setelah koreksi policy target | REDACT_USER melihat kartu/SSN tersamarkan; SECURITY_ADMIN melihat nilai asli. |
| EXCLUDE=RADM_POLICY | Policy tidak diterapkan; user yang memiliki SELECT melihat nilai asli. |
| DATA_ONLY ke tabel yang disiapkan manual | Hanya data dimuat; policy dan GRANT mengikuti konfigurasi target. |

**Masking mengubah nilai, subsetting memilih baris, dan redaction mengubah tampilan.** Periksa ketiganya dengan query yang sesuai. PK/FK dan object grants dapat ikut pada impor tabel normal, tetapi jangan menganggap job yang memuat data sudah berhasil memasang semua policy.

Objek sumber dan hasil impor dipertahankan untuk review. Setelah selesai, cabut role ekspor/impor sementara dari DP_LAB. Jika ingin mengulang demo, instruktur perlu menyiapkan target kosong dan memberikan kembali role sesuai kebutuhan.

```sql
REVOKE DATAPUMP_EXP_FULL_DATABASE FROM dp_lab;
```

Contoh output:

```text
Revoke succeeded.
```

```sql
REVOKE DATAPUMP_IMP_FULL_DATABASE FROM dp_lab;
```

Contoh output:

```text
Revoke succeeded.
```

Cek hasilnya:

```sql
SELECT granted_role FROM dba_role_privs WHERE grantee='DP_LAB'
AND granted_role IN ('DATAPUMP_EXP_FULL_DATABASE','DATAPUMP_IMP_FULL_DATABASE') ORDER BY granted_role;
```

Contoh output:

```text
no rows selected
```

---


---



<!-- ============================================================ -->
<!-- SOURCE: preventive_day4v2.md -->
<!-- ============================================================ -->

<a id="day-4-hands-on"></a>

# DAY 4 — Hands-on Only

> **Sumber file:** `preventive_day4v2.md`

# DAY 4 — HANDS-ON ONLY

> Versi praktik-only. Setiap blok berisi **Kegunaan** dan command siap copas. Teori, contoh output, tabel penjelasan, dan referensi telah dihapus.

# BAGIAN A — DATA MASKING

## LAB 1 — Prepare Day 4 Environment

**Kegunaan:** Menyiapkan environment Oracle pada terminal Linux dan membuka SQL*Plus.

```bash
export ORACLE_SID=oradb

export ORACLE_HOME=/u01/app/oracle/product/19.0.0/db_1

export ORACLE_BASE=/u01/app/oracle

export PATH=$ORACLE_HOME/bin:$PATH

echo "$ORACLE_SID | $ORACLE_HOME | $ORACLE_BASE"

sqlplus -version

sqlplus -s /nolog
```

---

## LAB 2 — Verify PDB dan Rapikan SQL*Plus

**Kegunaan:** Menghubungkan SYS ke PDB1, merapikan format SQL*Plus, dan memverifikasi versi database.

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA

SHOW CON_NAME
SELECT banner_full FROM v$version;
```

---

## LAB 2A — Lengkapi Prasyarat

**Kegunaan:** Menyiapkan schema DISCOVERY_OWNER beserta data customer dan account sintetis sebagai sumber latihan.

```sql
SELECT username FROM dba_users
WHERE username IN ('DISCOVERY_OWNER','MASKED_OWNER','SUBSET_OWNER','REDACT_USER','SECURITY_ADMIN')
ORDER BY username;

CREATE USER discovery_owner IDENTIFIED BY "Discovery#2026"
DEFAULT TABLESPACE users QUOTA 100M ON users;

GRANT CREATE SESSION, CREATE TABLE TO discovery_owner;

CREATE TABLE discovery_owner.customer (
  customer_id NUMBER PRIMARY KEY,
  customer_name VARCHAR2(100),
  email_address VARCHAR2(200),
  phone_number VARCHAR2(30),
  credit_card_number VARCHAR2(30),
  social_security_number VARCHAR2(30),
  date_of_birth DATE,
  salary NUMBER(15,2)
);

CREATE TABLE discovery_owner.customer_account (
  account_id NUMBER PRIMARY KEY,
  customer_id NUMBER NOT NULL,
  account_number VARCHAR2(30),
  account_type VARCHAR2(30),
  balance NUMBER(15,2),
  CONSTRAINT discovery_fk_customer FOREIGN KEY (customer_id)
    REFERENCES discovery_owner.customer(customer_id)
);

INSERT INTO discovery_owner.customer (customer_id, customer_name, email_address, phone_number, credit_card_number, social_security_number, date_of_birth, salary)
VALUES (1, 'JOHN DOE', 'john.doe@example.com', '+628123456789', '4111111111111111', '123-45-6789', DATE '1980-01-15', 15000000);

INSERT INTO discovery_owner.customer (customer_id, customer_name, email_address, phone_number, credit_card_number, social_security_number, date_of_birth, salary)
VALUES (2, 'JANE DOE', 'jane.doe@example.com', '+628987654321', '5555555555554444', '987-65-4321', DATE '1985-06-20', 17500000);

INSERT INTO discovery_owner.customer (customer_id, customer_name, email_address, phone_number, credit_card_number, social_security_number, date_of_birth, salary)
VALUES (3, 'ALICE', 'alice@example.com', '+628111222333', '378282246310005', '111-22-3333', DATE '1990-11-10', 22000000);

INSERT INTO discovery_owner.customer_account
(account_id, customer_id, account_number, account_type, balance)
VALUES (1001, 1, '1234567890123456', 'SAVINGS', 25000000);

INSERT INTO discovery_owner.customer_account
(account_id, customer_id, account_number, account_type, balance)
VALUES (1002, 1, '1234567890123457', 'CURRENT', 15000000);

INSERT INTO discovery_owner.customer_account
(account_id, customer_id, account_number, account_type, balance)
VALUES (1003, 2, '1234567890123458', 'SAVINGS', 35000000);

COMMIT;
```

---

## LAB 3 — Review Source Data

**Kegunaan:** Menampilkan baseline data sumber sebelum masking.

```sql
SELECT customer_id, customer_name, email_address
FROM discovery_owner.customer ORDER BY customer_id;

SELECT customer_id, phone_number, credit_card_number, social_security_number
FROM discovery_owner.customer ORDER BY customer_id;

SELECT customer_id, TO_CHAR(date_of_birth, 'YYYY-MM-DD') AS date_of_birth, salary
FROM discovery_owner.customer ORDER BY customer_id;
```

---

## LAB 4 — Identify Sensitive Data

**Kegunaan:** Menginventarisasi struktur kolom pada tabel customer dan customer_account.

```sql
SELECT table_name, column_name, data_type FROM dba_tab_columns
WHERE owner='DISCOVERY_OWNER'
AND table_name IN ('CUSTOMER','CUSTOMER_ACCOUNT')
ORDER BY table_name, column_id;
```

---

## LAB 6 — Create Masked Schema

**Kegunaan:** Membuat schema MASKED_OWNER sebagai area kerja data masking.

```sql
CREATE USER masked_owner IDENTIFIED BY "Masked#2026" DEFAULT TABLESPACE users;

GRANT CREATE SESSION, CREATE TABLE TO masked_owner;

ALTER USER masked_owner QUOTA 100M ON users;
```

---

## LAB 7 — Create Masked Customer Table

**Kegunaan:** Membuat tabel CUSTOMER pada schema MASKED_OWNER.

```sql
CREATE TABLE masked_owner.customer (
  customer_id NUMBER PRIMARY KEY,
  customer_name VARCHAR2(100),
  email_address VARCHAR2(200),
  phone_number VARCHAR2(30),
  credit_card_number VARCHAR2(30),
  social_security_number VARCHAR2(30),
  date_of_birth DATE,
  salary NUMBER(15,2)
);
```

---

## LAB 8 — Copy Data into Masking Environment

**Kegunaan:** Menyalin data customer sumber ke area masking dan memverifikasi jumlah baris.

```sql
INSERT INTO masked_owner.customer (customer_id, customer_name, email_address, phone_number, credit_card_number, social_security_number, date_of_birth, salary)
SELECT customer_id, customer_name, email_address, phone_number, credit_card_number, social_security_number, date_of_birth, salary
FROM discovery_owner.customer;

COMMIT;

SELECT COUNT(*) AS customer_count FROM masked_owner.customer;
```

---

## LAB 9 — Baseline Before Masking

**Kegunaan:** Memverifikasi baseline data salinan sebelum transformasi masking.

```sql
SELECT customer_id, customer_name, email_address
FROM masked_owner.customer ORDER BY customer_id;

SELECT customer_id, phone_number, credit_card_number, social_security_number
FROM masked_owner.customer ORDER BY customer_id;

SELECT customer_id, TO_CHAR(date_of_birth, 'YYYY-MM-DD') AS date_of_birth, salary
FROM masked_owner.customer ORDER BY customer_id;
```

---

## LAB 10 — Mask Customer Name

**Kegunaan:** Mengganti nama customer dengan nilai deterministik berbasis customer_id.

```sql
UPDATE masked_owner.customer
SET customer_name = 'CUSTOMER_' || customer_id;

COMMIT;

SELECT customer_id, customer_name
FROM masked_owner.customer ORDER BY customer_id;
```

---

## LAB 11 — Mask Email

**Kegunaan:** Mengganti email customer dengan alamat dummy deterministik.

```sql
UPDATE masked_owner.customer
SET email_address = 'customer' || customer_id || '@example.test';

COMMIT;

SELECT customer_id, email_address
FROM masked_owner.customer ORDER BY customer_id;
```

---

## LAB 12 — Mask Phone Number

**Kegunaan:** Mengganti nomor telepon customer dengan nomor dummy.

```sql
UPDATE masked_owner.customer
SET phone_number = '+620000000000' || customer_id;

COMMIT;

SELECT customer_id, phone_number
FROM masked_owner.customer ORDER BY customer_id;
```

---

## LAB 13 — Mask Credit Card

**Kegunaan:** Memasking nomor kartu sambil mempertahankan empat digit terakhir.

```sql
UPDATE masked_owner.customer
SET credit_card_number = '000000000000' || SUBSTR(credit_card_number,-4);

COMMIT;

SELECT customer_id, credit_card_number
FROM masked_owner.customer ORDER BY customer_id;
```

---

## LAB 14 — Mask SSN

**Kegunaan:** Memasking SSN sambil mempertahankan empat digit terakhir.

```sql
UPDATE masked_owner.customer
SET social_security_number = '000-00-' || SUBSTR(social_security_number,-4);

COMMIT;

SELECT customer_id, social_security_number
FROM masked_owner.customer ORDER BY customer_id;
```

---

## LAB 15 — Mask Date of Birth

**Kegunaan:** Memasking tanggal lahir dengan mempertahankan tahun.

```sql
UPDATE masked_owner.customer
SET date_of_birth = ADD_MONTHS(TRUNC(date_of_birth,'YYYY'),6)+14;

COMMIT;

SELECT customer_id, TO_CHAR(date_of_birth,'YYYY-MM-DD') AS date_of_birth
FROM masked_owner.customer ORDER BY customer_id;
```

---

## LAB 16 — Mask Salary

**Kegunaan:** Memasking salary menggunakan transformasi numerik.

```sql
UPDATE masked_owner.customer
SET salary = ROUND(salary*0.70,-3);

COMMIT;

SELECT customer_id, salary
FROM masked_owner.customer ORDER BY customer_id;
```

---

## LAB 17 — Verify Complete Masking

**Kegunaan:** Memverifikasi seluruh hasil masking pada tabel CUSTOMER.

```sql
SELECT customer_id, customer_name, email_address
FROM masked_owner.customer ORDER BY customer_id;

SELECT customer_id, phone_number, credit_card_number, social_security_number
FROM masked_owner.customer ORDER BY customer_id;

SELECT customer_id, TO_CHAR(date_of_birth, 'YYYY-MM-DD') AS date_of_birth, salary
FROM masked_owner.customer ORDER BY customer_id;
```

---

## LAB 19 — Deterministic vs Random Masking

**Kegunaan:** Membandingkan hasil masking deterministik dan nilai acak tanpa mengubah tabel sumber.

```sql
SELECT customer_id, 'CUSTOMER_' || customer_id AS customer_name
FROM discovery_owner.customer ORDER BY customer_id;

SELECT customer_id, CAST(DBMS_RANDOM.STRING('U',8) AS VARCHAR2(12)) AS random_name
FROM discovery_owner.customer ORDER BY customer_id;
```

---

## LAB 20 — Referential Integrity

**Kegunaan:** Membuat tabel CUSTOMER_ACCOUNT dengan foreign key ke CUSTOMER.

```sql
CREATE TABLE masked_owner.customer_account (
  account_id NUMBER PRIMARY KEY,
  customer_id NUMBER NOT NULL,
  account_number VARCHAR2(30),
  account_type VARCHAR2(30),
  balance NUMBER(15,2),
  CONSTRAINT masked_fk_customer FOREIGN KEY (customer_id)
    REFERENCES masked_owner.customer(customer_id)
);
```

---

## LAB 21 — Populate Account Data

**Kegunaan:** Mengisi data account pada schema MASKED_OWNER.

```sql
INSERT INTO masked_owner.customer_account
(account_id, customer_id, account_number, account_type, balance)
VALUES (1001, 1, '1234567890123456', 'SAVINGS', 25000000);

INSERT INTO masked_owner.customer_account
(account_id, customer_id, account_number, account_type, balance)
VALUES (1002, 1, '1234567890123457', 'CURRENT', 15000000);

INSERT INTO masked_owner.customer_account
(account_id, customer_id, account_number, account_type, balance)
VALUES (1003, 2, '1234567890123458', 'SAVINGS', 35000000);

COMMIT;
```

---

## LAB 22 — Verify Relationship

**Kegunaan:** Memverifikasi relasi customer dan account.

```sql
SELECT c.customer_id, c.customer_name, a.account_id, a.account_number, a.balance
FROM masked_owner.customer c
JOIN masked_owner.customer_account a ON c.customer_id=a.customer_id
ORDER BY c.customer_id, a.account_id;
```

---

## LAB 23 — Mask Account Number

**Kegunaan:** Memasking nomor account sambil mempertahankan empat digit terakhir.

```sql
UPDATE masked_owner.customer_account
SET account_number='999999999999' || SUBSTR(account_number,-4);

COMMIT;

SELECT account_id, account_number
FROM masked_owner.customer_account ORDER BY account_id;
```

---

## LAB 24 — Mask Balance

**Kegunaan:** Memasking nilai balance menggunakan transformasi numerik.

```sql
UPDATE masked_owner.customer_account SET balance=ROUND(balance*0.65,-3);

COMMIT;

SELECT account_id, balance FROM masked_owner.customer_account ORDER BY account_id;
```

---

## LAB 25 — Verify Referential Integrity

**Kegunaan:** Memastikan tidak ada orphan row setelah masking.

```sql
SELECT COUNT(*) AS orphan_count
FROM masked_owner.customer_account a
WHERE NOT EXISTS (SELECT 1 FROM masked_owner.customer c WHERE c.customer_id=a.customer_id);
```

---

## LAB 26 — Test Bad Masking

**Kegunaan:** Menguji proteksi foreign key dengan perubahan parent key yang sengaja dibuat gagal.

```sql
UPDATE masked_owner.customer SET customer_id=customer_id+1000;
```

---

## LAB 27 — Pastikan Customer ID Tetap Utuh

**Kegunaan:** Melakukan rollback setelah pengujian error dan memastikan relasi customer-account tetap utuh.

```sql
ROLLBACK;

SELECT c.customer_id, a.account_id
FROM masked_owner.customer c
JOIN masked_owner.customer_account a ON c.customer_id=a.customer_id
ORDER BY c.customer_id, a.account_id;
```

---

# BAGIAN B — DATA SUBSETTING

## LAB 29 — Manual Subsetting

**Kegunaan:** Membuat schema SUBSET_OWNER sebagai area kerja data subsetting.

```sql
CREATE USER subset_owner IDENTIFIED BY "Subset#2026" DEFAULT TABLESPACE users;

GRANT CREATE SESSION, CREATE TABLE TO subset_owner;

ALTER USER subset_owner QUOTA 100M ON users;
```

---

## LAB 30 — Create Subset Customer

**Kegunaan:** Membuat subset dua customer pertama dan menambahkan primary key.

```sql
CREATE TABLE subset_owner.customer AS
SELECT customer_id, customer_name, email_address, phone_number, credit_card_number, social_security_number, date_of_birth, salary
FROM discovery_owner.customer WHERE customer_id <= 2;

ALTER TABLE subset_owner.customer ADD CONSTRAINT subset_customer_pk PRIMARY KEY (customer_id);

SELECT customer_id, customer_name FROM subset_owner.customer ORDER BY customer_id;
```

---

## LAB 31 — Subset Account

**Kegunaan:** Membuat subset account yang hanya merujuk customer terpilih serta menambahkan PK/FK.

```sql
CREATE TABLE subset_owner.customer_account AS
SELECT a.account_id, a.customer_id, a.account_number, a.account_type, a.balance
FROM discovery_owner.customer_account a
WHERE EXISTS (SELECT 1 FROM subset_owner.customer c WHERE c.customer_id=a.customer_id);

ALTER TABLE subset_owner.customer_account ADD CONSTRAINT subset_account_pk PRIMARY KEY (account_id);

ALTER TABLE subset_owner.customer_account ADD CONSTRAINT subset_fk_customer
FOREIGN KEY (customer_id) REFERENCES subset_owner.customer(customer_id);

SELECT account_id, customer_id, account_number, account_type, balance
FROM subset_owner.customer_account ORDER BY account_id;
```

---

## LAB 32 — Check Referential Integrity of Subset

**Kegunaan:** Memverifikasi integritas referensial dan status constraint pada subset.

```sql
SELECT COUNT(*) AS orphan_count
FROM subset_owner.customer_account a
WHERE NOT EXISTS (SELECT 1 FROM subset_owner.customer c WHERE c.customer_id=a.customer_id);

SELECT constraint_name, constraint_type, status FROM dba_constraints
WHERE owner='SUBSET_OWNER' AND constraint_type IN ('P','R') ORDER BY constraint_name;
```

---

## LAB 34 — Create Final Test Dataset

**Kegunaan:** Membuat dataset final hasil kombinasi subsetting dan masking beserta PK/FK.

```sql
CREATE TABLE subset_owner.customer_masked AS
SELECT customer_id,
  'CUSTOMER_' || customer_id AS customer_name,
  'customer' || customer_id || '@example.test' AS email_address,
  '+620000000000' || customer_id AS phone_number,
  '000000000000' || SUBSTR(credit_card_number,-4) AS credit_card_number,
  '000-00-' || SUBSTR(social_security_number,-4) AS social_security_number,
  ADD_MONTHS(TRUNC(date_of_birth,'YYYY'),6)+14 AS date_of_birth,
  ROUND(salary*0.70,-3) AS salary
FROM subset_owner.customer;

ALTER TABLE subset_owner.customer_masked ADD CONSTRAINT subset_masked_customer_pk PRIMARY KEY (customer_id);

CREATE TABLE subset_owner.customer_account_masked AS
SELECT a.account_id, a.customer_id,
  '999999999999' || SUBSTR(a.account_number,-4) AS account_number,
  a.account_type, ROUND(a.balance*0.65,-3) AS balance
FROM subset_owner.customer_account a
WHERE EXISTS (SELECT 1 FROM subset_owner.customer_masked c WHERE c.customer_id=a.customer_id);

ALTER TABLE subset_owner.customer_account_masked ADD CONSTRAINT subset_masked_account_pk PRIMARY KEY (account_id);

ALTER TABLE subset_owner.customer_account_masked ADD CONSTRAINT subset_masked_fk_customer
FOREIGN KEY (customer_id) REFERENCES subset_owner.customer_masked(customer_id);

SELECT customer_id, customer_name, email_address
FROM subset_owner.customer_masked ORDER BY customer_id;

SELECT customer_id, phone_number, TO_CHAR(date_of_birth,'YYYY-MM-DD') AS date_of_birth, salary
FROM subset_owner.customer_masked ORDER BY customer_id;

SELECT account_id, customer_id, account_number, account_type, balance
FROM subset_owner.customer_account_masked ORDER BY account_id;
```

---

## LAB 35 — Validate Final Dataset

**Kegunaan:** Memvalidasi jumlah baris, hasil masking, dan orphan row pada dataset final.

```sql
SELECT COUNT(*) AS customer_count FROM subset_owner.customer_masked;

SELECT customer_id, credit_card_number, social_security_number, email_address
FROM subset_owner.customer_masked ORDER BY customer_id;

SELECT COUNT(*) AS orphan_count FROM subset_owner.customer_account_masked a
WHERE NOT EXISTS (SELECT 1 FROM subset_owner.customer_masked c WHERE c.customer_id=a.customer_id);
```

---

# BAGIAN C — DATA REDACTION

## LAB 36 — Check DBMS_REDACT

**Kegunaan:** Memastikan package DBMS_REDACT tersedia dan valid pada database.

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA

SELECT owner, object_name, object_type, status FROM dba_objects
WHERE owner='SYS' AND object_name='DBMS_REDACT'
ORDER BY object_type;
```

---

## LAB 37 — Create Redaction User

**Kegunaan:** Membuat REDACT_USER dan memberikan hak SELECT ke tabel sumber.

```sql
CREATE USER redact_user IDENTIFIED BY "Redact#2026";

GRANT CREATE SESSION TO redact_user;

GRANT SELECT ON discovery_owner.customer TO redact_user;
```

---

## LAB 38 — Test Before Redaction

**Kegunaan:** Menampilkan data sebagai REDACT_USER sebelum policy redaction diterapkan.

```sql
CONNECT redact_user/"Redact#2026"@localhost:1521/pdb1.localdomain

SELECT customer_id, customer_name, credit_card_number
FROM discovery_owner.customer ORDER BY customer_id;
```

---

## LAB 39 — Create Full Redaction Policy

**Kegunaan:** Membuat full redaction policy pada kolom CREDIT_CARD_NUMBER.

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA

BEGIN
  DBMS_REDACT.ADD_POLICY(
    object_schema => 'DISCOVERY_OWNER',
    object_name => 'CUSTOMER',
    policy_name => 'REDACT_CC_POLICY',
    column_name => 'CREDIT_CARD_NUMBER',
    function_type => DBMS_REDACT.FULL,
    expression => '1=1'
  );
END;
/
```

---

## LAB 40 — Test Full Redaction

**Kegunaan:** Menguji hasil full redaction sebagai REDACT_USER.

```sql
CONNECT redact_user/"Redact#2026"@localhost:1521/pdb1.localdomain

SELECT customer_id, customer_name, credit_card_number
FROM discovery_owner.customer ORDER BY customer_id;

SELECT customer_id, '[' || credit_card_number || ']' AS cc_display
FROM discovery_owner.customer ORDER BY customer_id;
```

---

## LAB 41 — Verify Source Still Original

**Kegunaan:** Memastikan nilai sumber tetap asli ketika diperiksa sebagai SYS.

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA

SELECT customer_id, credit_card_number FROM discovery_owner.customer ORDER BY customer_id;
```

---

## LAB 42 — Partial Display untuk Kartu 15 dan 16 Digit

**Kegunaan:** Mengubah policy kartu menjadi REGEXP redaction yang menampilkan empat digit terakhir.

```sql
BEGIN
  DBMS_REDACT.ALTER_POLICY(
    object_schema => 'DISCOVERY_OWNER',
    object_name => 'CUSTOMER',
    policy_name => 'REDACT_CC_POLICY',
    action => DBMS_REDACT.MODIFY_COLUMN,
    column_name => 'CREDIT_CARD_NUMBER',
    function_type => DBMS_REDACT.REGEXP,
    regexp_pattern => '^([[:digit:]]+)([[:digit:]]{4})$',
    regexp_replace_string => '************\2',
    regexp_position => 1,
    regexp_occurrence => 0,
    regexp_match_parameter => 'c'
  );
END;
/
```

---

## LAB 43 — Test Tampilan Empat Digit Terakhir

**Kegunaan:** Menguji tampilan empat digit terakhir kartu sebagai REDACT_USER.

```sql
CONNECT redact_user/"Redact#2026"@localhost:1521/pdb1.localdomain

SELECT customer_id, customer_name, credit_card_number
FROM discovery_owner.customer ORDER BY customer_id;
```

---

## LAB 44 — Create Authorized Application User

**Kegunaan:** Membuat SECURITY_ADMIN sebagai user pembanding yang diberi akses SELECT.

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA

CREATE USER security_admin IDENTIFIED BY "Security#2026";

GRANT CREATE SESSION TO security_admin;

GRANT SELECT ON discovery_owner.customer TO security_admin;
```

---

## LAB 45 — Conditional Redaction

**Kegunaan:** Mengubah expression policy agar SECURITY_ADMIN dikecualikan dari redaction.

```sql
BEGIN
  DBMS_REDACT.ALTER_POLICY(
    object_schema => 'DISCOVERY_OWNER',
    object_name => 'CUSTOMER',
    policy_name => 'REDACT_CC_POLICY',
    action => DBMS_REDACT.MODIFY_EXPRESSION,
    expression => 'SYS_CONTEXT(''USERENV'',''SESSION_USER'') <> ''SECURITY_ADMIN'''
  );
END;
/
```

---

## LAB 46 — Test User yang Terkena Policy

**Kegunaan:** Menguji bahwa REDACT_USER tetap terkena redaction.

```sql
CONNECT redact_user/"Redact#2026"@localhost:1521/pdb1.localdomain

SELECT customer_id, customer_name, credit_card_number
FROM discovery_owner.customer ORDER BY customer_id;
```

---

## LAB 47 — Test Authorized User

**Kegunaan:** Menguji bahwa SECURITY_ADMIN melihat nilai asli sesuai expression policy.

```sql
CONNECT security_admin/"Security#2026"@localhost:1521/pdb1.localdomain

SELECT customer_id, customer_name, credit_card_number
FROM discovery_owner.customer ORDER BY customer_id;
```

---

## LAB 48 — Verify Privilege Pembanding

**Kegunaan:** Memverifikasi privilege sistem REDACT_USER dan SECURITY_ADMIN.

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA

SELECT grantee AS username, privilege FROM dba_sys_privs
WHERE grantee IN ('REDACT_USER','SECURITY_ADMIN') ORDER BY grantee, privilege;
```

---

## LAB 49 — Review Policy

**Kegunaan:** Memeriksa status dan expression redaction policy.

```sql
COLUMN expression FORMAT A85

SELECT object_owner, object_name, policy_name, enable
FROM redaction_policies WHERE object_owner='DISCOVERY_OWNER';

SELECT expression FROM redaction_policies WHERE object_owner='DISCOVERY_OWNER';
```

---

## LAB 50 — Review Kolom yang Dilindungi

**Kegunaan:** Memeriksa kolom dan tipe fungsi yang dilindungi oleh redaction policy.

```sql
SELECT object_owner, object_name, column_name, function_type
FROM redaction_columns WHERE object_owner='DISCOVERY_OWNER' ORDER BY column_name;
```

---

# BAGIAN D — TSDP, INVENTORY & VALIDATION

## LAB 51 — Check TSDP Components

**Kegunaan:** Memastikan package TSDP tersedia dan valid.

```sql
SELECT owner, object_name, object_type, status FROM dba_objects
WHERE owner='SYS' AND object_name IN ('DBMS_TSDP_MANAGE','DBMS_TSDP_PROTECT')
ORDER BY object_name, object_type;
```

---

## LAB 53 — Sensitive Data Inventory

**Kegunaan:** Membuat inventory kolom sensitif pada schema DISCOVERY_OWNER berdasarkan nama kolom.

```sql
SELECT owner, table_name, column_name, data_type FROM dba_tab_columns
WHERE owner='DISCOVERY_OWNER'
AND table_name IN ('CUSTOMER','CUSTOMER_ACCOUNT')
AND column_name IN ('CUSTOMER_NAME','EMAIL_ADDRESS','PHONE_NUMBER',
  'CREDIT_CARD_NUMBER','SOCIAL_SECURITY_NUMBER','DATE_OF_BIRTH',
  'SALARY','ACCOUNT_NUMBER','BALANCE')
ORDER BY table_name, column_id;
```

---

## LAB 56 — Security Test Matrix

**Kegunaan:** Membandingkan nilai kartu pada source, masked copy, REDACT_USER, dan SECURITY_ADMIN.

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA

SELECT credit_card_number FROM discovery_owner.customer WHERE customer_id=1;

SELECT credit_card_number FROM masked_owner.customer WHERE customer_id=1;

CONNECT redact_user/"Redact#2026"@localhost:1521/pdb1.localdomain

SELECT credit_card_number FROM discovery_owner.customer WHERE customer_id=1;

CONNECT security_admin/"Security#2026"@localhost:1521/pdb1.localdomain

SELECT credit_card_number FROM discovery_owner.customer WHERE customer_id=1;
```

---

## LAB 58 — Verify Masking Did Not Affect Source

**Kegunaan:** Memastikan proses masking tidak mengubah data pada source.

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA

SELECT customer_id, customer_name, credit_card_number
FROM discovery_owner.customer ORDER BY customer_id;

SELECT customer_id, customer_name, credit_card_number
FROM masked_owner.customer ORDER BY customer_id;
```

---

## LAB 59 — Sensitive Data Leak Test

**Kegunaan:** Menguji potensi kebocoran kolom sensitif lain yang belum masuk redaction policy.

```sql
CONNECT redact_user/"Redact#2026"@localhost:1521/pdb1.localdomain

SELECT customer_id, credit_card_number, social_security_number, email_address
FROM discovery_owner.customer ORDER BY customer_id;
```

---

## LAB 60 — Remediation Exercise

**Kegunaan:** Menambahkan SSN ke policy redaction dan memverifikasi hasil untuk user biasa serta user pengecualian.

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA

BEGIN
  DBMS_REDACT.ALTER_POLICY(
    object_schema => 'DISCOVERY_OWNER',
    object_name => 'CUSTOMER',
    policy_name => 'REDACT_CC_POLICY',
    action => DBMS_REDACT.ADD_COLUMN,
    column_name => 'SOCIAL_SECURITY_NUMBER',
    function_type => DBMS_REDACT.PARTIAL,
    function_parameters => 'VVVFVVFVVVV,VVV-VV-VVVV,*,1,5'
  );
END;
/

CONNECT redact_user/"Redact#2026"@localhost:1521/pdb1.localdomain

SELECT customer_id, credit_card_number, social_security_number, email_address
FROM discovery_owner.customer ORDER BY customer_id;

CONNECT security_admin/"Security#2026"@localhost:1521/pdb1.localdomain

SELECT customer_id, social_security_number FROM discovery_owner.customer ORDER BY customer_id;
```

---

# BAGIAN E — TDE: AKSES GAGAL DAN PEMULIHAN

## LAB 60A — TDE: Gunakan Wallet Existing

**Kegunaan:** Memverifikasi wallet existing dan membuat tabel demo dengan column-level TDE.

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA

SHOW CON_NAME

SELECT con_id, status, wallet_type, keystore_mode FROM v$encryption_wallet;

SELECT tablespace_name, encrypted FROM dba_tablespaces WHERE tablespace_name IN ('USERS','TS_SECURE') ORDER BY tablespace_name;

CREATE TABLE discovery_owner.tde_access_demo (
  demo_id NUMBER PRIMARY KEY,
  secret_text VARCHAR2(40) ENCRYPT USING 'AES256'
) TABLESPACE users;

INSERT INTO discovery_owner.tde_access_demo (demo_id, secret_text) VALUES (1, 'DATA RAHASIA LAB');

COMMIT;

GRANT SELECT ON discovery_owner.tde_access_demo TO redact_user;

SELECT owner, table_name, column_name, encryption_alg FROM dba_encrypted_columns
WHERE owner='DISCOVERY_OWNER' AND table_name='TDE_ACCESS_DEMO';
```

---

## LAB 60B — Baca Data Saat Wallet Terbuka

**Kegunaan:** Membuktikan data terenkripsi dapat dibaca ketika wallet terbuka.

```sql
CONNECT redact_user/"Redact#2026"@localhost:1521/pdb1.localdomain

SELECT demo_id, secret_text FROM discovery_owner.tde_access_demo ORDER BY demo_id;
```

---

## LAB 60C — Simulasikan Data Terenkripsi Tidak Bisa Diakses

**Kegunaan:** Menutup wallet PDB1 dan membuktikan akses ke data terenkripsi gagal.

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA

SHOW CON_NAME

ADMINISTER KEY MANAGEMENT SET KEYSTORE CLOSE
IDENTIFIED BY "TDEWallet#2026" CONTAINER=CURRENT;

SELECT con_id, status, wallet_type FROM v$encryption_wallet;

CONNECT redact_user/"Redact#2026"@localhost:1521/pdb1.localdomain

SELECT demo_id, secret_text FROM discovery_owner.tde_access_demo ORDER BY demo_id;
```

---

## LAB 60D — Pulihkan Akses dengan Membuka Wallet

**Kegunaan:** Membuka kembali wallet dan membuktikan akses data terenkripsi pulih.

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA

ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN
IDENTIFIED BY "TDEWallet#2026" CONTAINER=CURRENT;

SELECT con_id, status, wallet_type FROM v$encryption_wallet;

CONNECT redact_user/"Redact#2026"@localhost:1521/pdb1.localdomain

SELECT demo_id, secret_text FROM discovery_owner.tde_access_demo ORDER BY demo_id;
```

---

## LAB 61 — Final Security Audit

**Kegunaan:** Melakukan audit akhir terhadap TDE, redaction policy, encrypted tablespace, dan status wallet.

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA

SELECT owner, table_name, column_name, encryption_alg FROM dba_encrypted_columns
WHERE owner='DISCOVERY_OWNER' ORDER BY table_name, column_name;

SELECT p.object_owner, p.object_name, c.column_name, c.function_type, p.enable
FROM redaction_policies p JOIN redaction_columns c
ON p.object_owner=c.object_owner AND p.object_name=c.object_name
WHERE p.object_owner='DISCOVERY_OWNER' ORDER BY c.column_name;

SELECT tablespace_name, encrypted FROM dba_tablespaces WHERE encrypted='YES' ORDER BY tablespace_name;

SELECT con_id, status, wallet_type FROM v$encryption_wallet;
```

---

# BAGIAN F — EXPORT & IMPORT: APAKAH PERLINDUNGAN TETAP ADA?

## LAB 63 — Data Pump: Apa yang Sebenarnya Ikut Dipindahkan?

**Kegunaan:** Memeriksa kondisi awal PDB1 dan menyiapkan format SQL*Plus untuk validasi Data Pump.

```sql
CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA

SHOW CON_NAME

SELECT username FROM dba_users WHERE username IN
('DP_LAB','DP_MASK','DP_SUB','DP_RED','DP_NOPOL') ORDER BY username;

COLUMN difference_count FORMAT 999999

COLUMN directory_name FORMAT A18

COLUMN directory_path FORMAT A45

COLUMN grantee FORMAT A18

COLUMN source_count FORMAT 999999

COLUMN imported_count FORMAT 999999
```

**Kegunaan:** Membuat folder OS yang akan dipakai sebagai lokasi dump Data Pump.

```bash
mkdir -m 700 /home/oracle/day4_dp_20260910
```

**Kegunaan:** Membuat Oracle DIRECTORY, user Data Pump, target schema, serta privilege yang dibutuhkan.

```sql
CREATE DIRECTORY day4_dp AS '/home/oracle/day4_dp_20260910';

SELECT directory_name, directory_path FROM dba_directories WHERE directory_name='DAY4_DP';

CREATE USER dp_lab IDENTIFIED BY "DpLab#2026" DEFAULT TABLESPACE users QUOTA 100M ON users;

GRANT CREATE SESSION, CREATE TABLE TO dp_lab;

GRANT DATAPUMP_EXP_FULL_DATABASE TO dp_lab;

GRANT DATAPUMP_IMP_FULL_DATABASE TO dp_lab;

GRANT READ, WRITE ON DIRECTORY day4_dp TO dp_lab;

CREATE USER dp_mask IDENTIFIED BY "DpTarget#2026" DEFAULT TABLESPACE users QUOTA 100M ON users;

CREATE USER dp_sub IDENTIFIED BY "DpTarget#2026" DEFAULT TABLESPACE users QUOTA 100M ON users;

CREATE USER dp_red IDENTIFIED BY "DpTarget#2026" DEFAULT TABLESPACE users QUOTA 100M ON users;

CREATE USER dp_nopol IDENTIFIED BY "DpTarget#2026" DEFAULT TABLESPACE users QUOTA 100M ON users;

SELECT privilege FROM role_sys_privs
WHERE privilege='EXEMPT REDACTION POLICY' AND role IN (
  SELECT 'DATAPUMP_EXP_FULL_DATABASE' FROM dual
  UNION
  SELECT granted_role FROM role_role_privs
  START WITH role='DATAPUMP_EXP_FULL_DATABASE'
  CONNECT BY NOCYCLE PRIOR granted_role=role
);
```

---

## LAB 64 — Export dan Import Static Masking

**Kegunaan:** Memeriksa baseline data pada MASKED_OWNER sebelum export.

```sql
SELECT customer_id, customer_name, credit_card_number, social_security_number
FROM masked_owner.customer ORDER BY customer_id;
```

**Kegunaan:** Mengekspor tabel MASKED_OWNER lalu mengimpornya ke DP_MASK.

```bash
expdp dp_lab/"DpLab#2026"@localhost:1521/pdb1.localdomain \
  DIRECTORY=DAY4_DP DUMPFILE=day4_mask.dmp \
  LOGFILE=expdp_day4_mask_2.log \
  TABLES=MASKED_OWNER.CUSTOMER,MASKED_OWNER.CUSTOMER_ACCOUNT ENCRYPTION=NONE

impdp dp_lab/"DpLab#2026"@localhost:1521/pdb1.localdomain \
  DIRECTORY=DAY4_DP DUMPFILE=day4_mask.dmp \
  LOGFILE=impdp_day4_mask_3.log \
  REMAP_SCHEMA=MASKED_OWNER:DP_MASK
```

**Kegunaan:** Memvalidasi bahwa data hasil import tetap masked dan constraint tetap tersedia.

```sql
SELECT customer_id, customer_name, credit_card_number, social_security_number
FROM dp_mask.customer ORDER BY customer_id;

SELECT account_id, customer_id, account_number, balance FROM dp_mask.customer_account ORDER BY account_id;

SELECT COUNT(*) AS difference_count FROM (
  SELECT * FROM (SELECT * FROM masked_owner.customer MINUS SELECT * FROM dp_mask.customer)
  UNION ALL
  SELECT * FROM (SELECT * FROM dp_mask.customer MINUS SELECT * FROM masked_owner.customer)
);

SELECT COUNT(*) AS difference_count FROM (
  SELECT * FROM (SELECT * FROM masked_owner.customer_account MINUS SELECT * FROM dp_mask.customer_account)
  UNION ALL
  SELECT * FROM (SELECT * FROM dp_mask.customer_account MINUS SELECT * FROM masked_owner.customer_account)
);

SELECT constraint_name, constraint_type, status FROM dba_constraints
WHERE owner='DP_MASK' AND constraint_type IN ('P','R') ORDER BY constraint_name;
```

---

## LAB 65 — Export dan Import Subset Mentah serta Subset Masked

**Kegunaan:** Mengekspor subset mentah dan subset masked lalu mengimpornya ke DP_SUB.

```bash
expdp dp_lab/"DpLab#2026"@localhost:1521/pdb1.localdomain \
  DIRECTORY=DAY4_DP DUMPFILE=day4_subset.dmp \
  LOGFILE=expdp_day4_subset_1.log \
  TABLES=SUBSET_OWNER.CUSTOMER,SUBSET_OWNER.CUSTOMER_ACCOUNT,SUBSET_OWNER.CUSTOMER_MASKED,SUBSET_OWNER.CUSTOMER_ACCOUNT_MASKED ENCRYPTION=NONE

impdp dp_lab/"DpLab#2026"@localhost:1521/pdb1.localdomain \
  DIRECTORY=DAY4_DP DUMPFILE=day4_subset.dmp \
  LOGFILE=impdp_day4_subset_2.log \
  REMAP_SCHEMA=SUBSET_OWNER:DP_SUB
```

**Kegunaan:** Memvalidasi jumlah baris, nilai data, perbedaan source-target, orphan row, dan constraint.

```sql
SELECT (SELECT COUNT(*) FROM discovery_owner.customer) AS source_count,
       (SELECT COUNT(*) FROM dp_sub.customer) AS imported_count FROM dual;

SELECT customer_id, customer_name, credit_card_number, social_security_number
FROM dp_sub.customer ORDER BY customer_id;

SELECT customer_id, customer_name, credit_card_number, social_security_number
FROM dp_sub.customer_masked ORDER BY customer_id;

SELECT account_id, customer_id, account_number, balance
FROM dp_sub.customer_account_masked ORDER BY account_id;

SELECT COUNT(*) AS difference_count FROM (
  SELECT * FROM (SELECT * FROM subset_owner.customer MINUS SELECT * FROM dp_sub.customer)
  UNION ALL
  SELECT * FROM (SELECT * FROM dp_sub.customer MINUS SELECT * FROM subset_owner.customer)
);

SELECT COUNT(*) AS difference_count FROM (
  SELECT * FROM (SELECT * FROM subset_owner.customer_account MINUS SELECT * FROM dp_sub.customer_account)
  UNION ALL
  SELECT * FROM (SELECT * FROM dp_sub.customer_account MINUS SELECT * FROM subset_owner.customer_account)
);

SELECT COUNT(*) AS difference_count FROM (
  SELECT * FROM (SELECT * FROM subset_owner.customer_masked MINUS SELECT * FROM dp_sub.customer_masked)
  UNION ALL
  SELECT * FROM (SELECT * FROM dp_sub.customer_masked MINUS SELECT * FROM subset_owner.customer_masked)
);

SELECT COUNT(*) AS difference_count FROM (
  SELECT * FROM (SELECT * FROM subset_owner.customer_account_masked MINUS SELECT * FROM dp_sub.customer_account_masked)
  UNION ALL
  SELECT * FROM (SELECT * FROM dp_sub.customer_account_masked MINUS SELECT * FROM subset_owner.customer_account_masked)
);

SELECT COUNT(*) AS orphan_count FROM dp_sub.customer_account_masked a
WHERE NOT EXISTS (SELECT 1 FROM dp_sub.customer_masked c WHERE c.customer_id=a.customer_id);

SELECT constraint_name, constraint_type, status FROM dba_constraints
WHERE owner='DP_SUB' AND constraint_type IN ('P','R') ORDER BY constraint_name;
```

---

## LAB 66 — Export Redaction dan Periksa REMAP_SCHEMA pada Oracle 19.8

**Kegunaan:** Menguji tampilan redacted sebagai REDACT_USER lalu kembali ke SYS untuk proses Data Pump.

```sql
CONNECT redact_user/"Redact#2026"@localhost:1521/pdb1.localdomain

SELECT customer_id, customer_name, credit_card_number, social_security_number
FROM discovery_owner.customer ORDER BY customer_id;

CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA
```

**Kegunaan:** Mengekspor CUSTOMER dan mengimpornya ke DP_RED dengan REMAP_SCHEMA.

```bash
expdp dp_lab/"DpLab#2026"@localhost:1521/pdb1.localdomain \
  DIRECTORY=DAY4_DP DUMPFILE=day4_redact.dmp \
  LOGFILE=expdp_day4_redact_4.log \
  TABLES=DISCOVERY_OWNER.CUSTOMER ENCRYPTION=NONE

impdp dp_lab/"DpLab#2026"@localhost:1521/pdb1.localdomain \
  DIRECTORY=DAY4_DP DUMPFILE=day4_redact.dmp \
  LOGFILE=impdp_day4_redact_5.log \
  REMAP_SCHEMA=DISCOVERY_OWNER:DP_RED
```

**Kegunaan:** Memeriksa stored data, metadata policy, GRANT, dan hasil akses REDACT_USER/SECURITY_ADMIN setelah import.

```sql
SELECT customer_id, customer_name, credit_card_number, social_security_number
FROM dp_red.customer ORDER BY customer_id;

SELECT COUNT(*) AS difference_count FROM (
  SELECT * FROM (SELECT * FROM discovery_owner.customer MINUS SELECT * FROM dp_red.customer)
  UNION ALL
  SELECT * FROM (SELECT * FROM dp_red.customer MINUS SELECT * FROM discovery_owner.customer)
);

SELECT object_owner, object_name, policy_name, enable
FROM redaction_policies WHERE object_owner='DP_RED';

SELECT column_name, function_type FROM redaction_columns
WHERE object_owner='DP_RED' ORDER BY column_name;

SELECT grantee, privilege FROM dba_tab_privs
WHERE owner='DP_RED' AND table_name='CUSTOMER' ORDER BY grantee, privilege;

CONNECT redact_user/"Redact#2026"@localhost:1521/pdb1.localdomain

SELECT customer_id, customer_name, credit_card_number, social_security_number
FROM dp_red.customer ORDER BY customer_id;

CONNECT security_admin/"Security#2026"@localhost:1521/pdb1.localdomain

SELECT customer_id, customer_name, credit_card_number, social_security_number
FROM dp_red.customer ORDER BY customer_id;

CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA
```

---

## LAB 66A — Perbaiki Policy pada Schema Tujuan

**Kegunaan:** Membuat ulang redaction policy pada schema hasil import dan menguji hasilnya.

```sql
BEGIN
  DBMS_REDACT.ADD_POLICY(
    object_schema => 'DP_RED', object_name => 'CUSTOMER',
    policy_name => 'REDACT_CC_POLICY', column_name => 'CREDIT_CARD_NUMBER',
    function_type => DBMS_REDACT.REGEXP,
    regexp_pattern => '^([[:digit:]]+)([[:digit:]]{4})$',
    regexp_replace_string => '************\2',
    regexp_position => 1, regexp_occurrence => 0, regexp_match_parameter => 'c',
    expression => 'SYS_CONTEXT(''USERENV'',''SESSION_USER'') <> ''SECURITY_ADMIN'''
  );
END;
/

BEGIN
  DBMS_REDACT.ALTER_POLICY(
    object_schema => 'DP_RED', object_name => 'CUSTOMER',
    policy_name => 'REDACT_CC_POLICY', action => DBMS_REDACT.ADD_COLUMN,
    column_name => 'SOCIAL_SECURITY_NUMBER', function_type => DBMS_REDACT.PARTIAL,
    function_parameters => 'VVVFVVFVVVV,VVV-VV-VVVV,*,1,5'
  );
END;
/

SELECT object_owner, object_name, policy_name, enable FROM redaction_policies
WHERE object_owner IN ('DISCOVERY_OWNER','DP_RED') ORDER BY object_owner;

SELECT column_name, function_type FROM redaction_columns WHERE object_owner='DP_RED' ORDER BY column_name;

CONNECT redact_user/"Redact#2026"@localhost:1521/pdb1.localdomain

SELECT customer_id, customer_name, credit_card_number, social_security_number
FROM dp_red.customer ORDER BY customer_id;

CONNECT security_admin/"Security#2026"@localhost:1521/pdb1.localdomain

SELECT customer_id, customer_name, credit_card_number, social_security_number
FROM dp_red.customer ORDER BY customer_id;

CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA
```

---

## LAB 67 — Import dengan Policy Redaction Dikecualikan

**Kegunaan:** Memastikan object path RADM_POLICY tersedia sebelum melakukan import dengan pengecualian policy.

```sql
SELECT CAST(object_path AS VARCHAR2(40)) AS object_path FROM table_export_objects WHERE object_path LIKE '%RADM%' ORDER BY object_path;
```

**Kegunaan:** Mengimpor dump ke DP_NOPOL dengan EXCLUDE=RADM_POLICY.

```bash
impdp dp_lab/"DpLab#2026"@localhost:1521/pdb1.localdomain \
  DIRECTORY=DAY4_DP DUMPFILE=day4_redact.dmp \
  LOGFILE=impdp_day4_redact_2.log \
  REMAP_SCHEMA=DISCOVERY_OWNER:DP_NOPOL EXCLUDE=RADM_POLICY
```

**Kegunaan:** Memverifikasi tidak ada policy pada target dan menguji data yang terlihat oleh REDACT_USER.

```sql
SELECT object_owner, object_name, policy_name FROM redaction_policies WHERE object_owner='DP_NOPOL';

CONNECT redact_user/"Redact#2026"@localhost:1521/pdb1.localdomain

SELECT customer_id, customer_name, credit_card_number, social_security_number
FROM dp_nopol.customer ORDER BY customer_id;

CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA
```

---

## LAB 68 — GRANT dan Data-Only Import: Apa yang Tidak Otomatis Terbawa?

**Kegunaan:** Membuat tabel target manual untuk skenario DATA_ONLY import.

```sql
CREATE TABLE dp_nopol.customer_data_only (
  customer_id NUMBER PRIMARY KEY, customer_name VARCHAR2(100),
  email_address VARCHAR2(200), phone_number VARCHAR2(30),
  credit_card_number VARCHAR2(30), social_security_number VARCHAR2(30),
  date_of_birth DATE, salary NUMBER(15,2)
);
```

**Kegunaan:** Mengimpor hanya data ke CUSTOMER_DATA_ONLY menggunakan APPEND.

```bash
impdp dp_lab/"DpLab#2026"@localhost:1521/pdb1.localdomain \
  DIRECTORY=DAY4_DP DUMPFILE=day4_redact.dmp \
  LOGFILE=impdp_day4_redact_2_dataonly.log \
  REMAP_SCHEMA=DISCOVERY_OWNER:DP_NOPOL REMAP_TABLE=CUSTOMER:CUSTOMER_DATA_ONLY CONTENT=DATA_ONLY TABLE_EXISTS_ACTION=APPEND
```

**Kegunaan:** Memverifikasi isi, policy, kegagalan akses sebelum GRANT, lalu memberikan GRANT dan menguji ulang.

```sql
SELECT COUNT(*) AS imported_count FROM dp_nopol.customer_data_only;

SELECT policy_name FROM redaction_policies WHERE object_owner='DP_NOPOL' AND object_name='CUSTOMER_DATA_ONLY';

CONNECT redact_user/"Redact#2026"@localhost:1521/pdb1.localdomain

SELECT customer_id, credit_card_number FROM dp_nopol.customer_data_only ORDER BY customer_id;

CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA

GRANT SELECT ON dp_nopol.customer_data_only TO redact_user;

CONNECT redact_user/"Redact#2026"@localhost:1521/pdb1.localdomain

SELECT customer_id, credit_card_number, social_security_number FROM dp_nopol.customer_data_only ORDER BY customer_id;

CONNECT sys/oracle@localhost:1521/pdb1.localdomain AS SYSDBA
```

---

## LAB 69 — Kesimpulan Export dan Import

**Kegunaan:** Mencabut role Data Pump sementara dari DP_LAB dan memverifikasi cleanup privilege.

```sql
REVOKE DATAPUMP_EXP_FULL_DATABASE FROM dp_lab;

REVOKE DATAPUMP_IMP_FULL_DATABASE FROM dp_lab;

SELECT granted_role FROM dba_role_privs WHERE grantee='DP_LAB'
AND granted_role IN ('DATAPUMP_EXP_FULL_DATABASE','DATAPUMP_IMP_FULL_DATABASE') ORDER BY granted_role;
```

---


---



<!-- ============================================================ -->
<!-- SOURCE: preventive_day5.md -->
<!-- ============================================================ -->

<a id="day-5"></a>

<a id="day-5-original"></a>

# DAY 5 — Database Vault & Privilege Analysis (Original)

> **Sumber file:** `preventive_day5.md`

# ORACLE DATABASE SECURITY — DAY 5

## Database Vault & Privilege Analysis

### Environment

Kita tetap menggunakan environment training:

```text
OS             : Oracle Linux 7.8
Oracle         : 19.8.0.0.0
ORACLE_SID     : oradb
CDB            : ORADB
PDB            : PDB1
ORACLE_HOME    : /u01/app/oracle/product/19.0.0/db_1
ORACLE_BASE    : /u01/app/oracle
SYS password   : oracle
```

---

# 1. Tujuan Day 5

Setelah menyelesaikan lab ini peserta mampu:

* memahami konsep **Oracle Database Vault**;
* memahami **realm**;
* memahami **rule**;
* memahami **rule set**;
* memahami **command rule**;
* memahami **secure application role**;
* memahami **Database Vault owner** dan **account manager**;
* memahami separation of duties;
* mengaktifkan Database Vault pada PDB;
* membuat realm;
* melindungi tabel menggunakan realm;
* menguji bypass protection;
* membuat command rule;
* membuat rule set;
* memahami simulation/training mode;
* memahami faktor dan identity;
* melakukan privilege analysis;
* membuat privilege capture policy;
* menangkap privilege yang benar-benar digunakan;
* menghasilkan report privilege usage;
* mengidentifikasi privilege yang berlebihan.

Oracle sendiri menjelaskan bahwa Database Vault digunakan untuk mengontrol akses terhadap data/objek bahkan ketika user memiliki privilege administratif tertentu, sehingga membantu menerapkan separation of duties. Syllabus juga menempatkan Database Vault sebagai mekanisme untuk enforcement separation of duties di level DBA. ([Oracle Documentation][1])

---

# 2. Arsitektur Lab

Kita akan membuat environment berikut:

```text
                         ORADB
                           |
                         PDB1
                           |
          +----------------+----------------+
          |                                 |
     DATABASE VAULT                    PRIVILEGE
          |                            ANALYSIS
          |                                 |
     DV_OWNER                         CAPTURE_ADMIN
          |
    +-----+------+
    |            |
  REALM      COMMAND RULE
    |
 CUSTOMER_SECURE
    |
 DISCOVERY_OWNER.CUSTOMER
```

User lab:

```text
DV_OWNER_LAB
DV_ACCTMGR_LAB

DV_APP_USER
DV_DBA_USER

PA_ADMIN
PA_TEST_USER
```

---

# LAB 1 — PREPARATION

## 1.1 Login OS

```bash
su - oracle
```

Set environment:

```bash
export ORACLE_SID=oradb
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/db_1
export ORACLE_BASE=/u01/app/oracle
export PATH=$ORACLE_HOME/bin:$PATH
```

Check:

```bash
echo $ORACLE_SID
echo $ORACLE_HOME
```

Expected:

```text
oradb
/u01/app/oracle/product/19.0.0/db_1
```

---

# LAB 2 — DATABASE BASELINE

Connect:

```bash
sqlplus sys/oracle@localhost:1521/pdb1.localdomain as sysdba
```

Expected:

```text
Connected to:
Oracle Database 19c Enterprise Edition ...
```

Check container:

```sql
SHOW CON_NAME;
```

Expected:

```text
CON_NAME
------------------------------
PDB1
```

Check database:

```sql
SELECT
    name,
    open_mode,
    cdb
FROM v$database;
```

Expected kira-kira:

```text
NAME      OPEN_MODE    CDB
--------- ------------ ---
ORADB     READ WRITE   YES
```

---

# LAB 3 — CHECK DATABASE VAULT

Sebelum melakukan konfigurasi, **jangan langsung enable Database Vault**.

Pertama kita cek apakah sudah tersedia/aktif.

```sql
SELECT
    status,
    status_code,
    description
FROM dba_dv_status
ORDER BY status;
```

Expected pada database yang belum dikonfigurasi dapat berbeda tergantung instalasi.

Contoh:

```text
STATUS
------------------------------
FALSE

DESCRIPTION
------------------------------
Database Vault is not enabled
```

atau status lainnya.

---

## 3.1 Cek role Database Vault

```sql
SELECT
    role
FROM dba_roles
WHERE role LIKE 'DV%'
ORDER BY role;
```

Expected:

```text
ROLE
------------------------------
DV_ACCTMGR
DV_ADMIN
DV_MONITOR
DV_OWNER
```

Jika role tersebut ada, komponen Database Vault tersedia.

---

# LAB 4 — CEK KOMPONEN DATABASE VAULT

Jalankan:

```sql
SELECT
    owner,
    object_name,
    object_type
FROM dba_objects
WHERE owner IN ('DVSYS','DVF')
AND object_name IN (
    'DBMS_MACADM',
    'DBMS_MACSEC_ROLES'
)
ORDER BY owner, object_name;
```

Expected:

```text
OWNER   OBJECT_NAME          OBJECT_TYPE
------- -------------------- ----------------
DVSYS   DBMS_MACADM          PACKAGE
DVSYS   DBMS_MACSEC_ROLES    PACKAGE
```

`DBMS_MACADM` adalah package administrasi utama Database Vault untuk konfigurasi realm, rule set, command rule, secure application role, dan komponen lainnya. Package tersebut hanya dapat digunakan oleh user yang memiliki `DV_OWNER` atau `DV_ADMIN`. ([Oracle Documentation][2])

---

# LAB 5 — MENYIAPKAN USER DATABASE VAULT

> **Penting:** lakukan ini hanya jika user belum ada.

Kita buat dua user khusus:

```text
DV_OWNER_LAB
DV_ACCTMGR_LAB
```

Konsepnya:

```text
DV_OWNER
    |
    +-- mengadministrasikan Database Vault

DV_ACCTMGR
    |
    +-- mengadministrasikan account/user
```

Ini merupakan contoh separation of duties.

---

## 5.1 Create DV owner

```sql
CREATE USER dv_owner_lab
IDENTIFIED BY "DVOwner#2026"
CONTAINER=CURRENT;
```

Expected:

```text
User created.
```

Grant session:

```sql
GRANT CREATE SESSION TO dv_owner_lab;
```

Expected:

```text
Grant succeeded.
```

---

## 5.2 Create account manager

```sql
CREATE USER dv_acctmgr_lab
IDENTIFIED BY "DVAcctMgr#2026"
CONTAINER=CURRENT;
```

Expected:

```text
User created.
```

Grant:

```sql
GRANT CREATE SESSION TO dv_acctmgr_lab;
```

Expected:

```text
Grant succeeded.
```

---

# LAB 6 — CONFIGURE DATABASE VAULT

Oracle menyediakan `CONFIGURE_DV` untuk melakukan initial configuration. Procedure ini mengonfigurasi account yang kemudian memperoleh role `DV_OWNER` dan `DV_ACCTMGR`. Oracle menyatakan procedure ini hanya dapat dijalankan sekali untuk initial configuration. ([Oracle Documentation][3])

Jalankan sebagai SYS:

```sql
BEGIN
    CONFIGURE_DV(
    dvowner_uname   => 'C##DV_OWNER_LAB',
    dvacctmgr_uname => 'C##DV_ACCTMGR_LAB'
    );
END;
/
```

Expected:

```text
PL/SQL procedure successfully completed.
```

---

## 6.1 Verify

```sql
SELECT
    username,
    granted_role
FROM dba_role_privs
WHERE username IN (
    'DV_OWNER_LAB',
    'DV_ACCTMGR_LAB'
)
ORDER BY username, granted_role;
```

Expected kira-kira:

```text
USERNAME         GRANTED_ROLE
---------------- ----------------
C##DV_ACCTMGR_LAB   DV_ACCTMGR
C##DV_OWNER_LAB     DV_OWNER
```

---

# LAB 7 — CEK STATUS DATABASE VAULT

```sql
SELECT
    * 
FROM dba_dv_status;
```

Expected setelah konfigurasi dapat menunjukkan status configuration/enablement sesuai kondisi database.

---

# LAB 8 — ENABLE DATABASE VAULT

Untuk lab ini kita bekerja **di PDB1**, bukan CDB root.

Connect sebagai DV owner:

```bash
sqlplus dv_owner_lab/"DVOwner#2026"@localhost:1521/pdb1.localdomain
```

Kemudian:

```sql
SHOW USER;
```

Expected:

```text
USER is "DV_OWNER_LAB"
```

Enable Database Vault:

```sql
EXEC DVSYS.DBMS_MACADM.ENABLE_DV;
```

Jika pada patch/configuration 19c procedure ini tersedia, expected:

```text
PL/SQL procedure successfully completed.
```

Kemudian keluar:

```sql
EXIT;
```

---

# LAB 9 — RESTART DATABASE

Database Vault membutuhkan restart pada konfigurasi tertentu.

Kembali:

```bash
sqlplus sys/oracle@localhost:1521/pdb1.localdomain as sysdba
```

Restart PDB:

```sql
SHUTDOWN IMMEDIATE;
```

Expected:

```text
Database closed.
Database dismounted.
ORACLE instance shut down.
```

Start:

```sql
STARTUP;
```

Expected:

```text
ORACLE instance started.
Database mounted.
Database opened.
```

Check:

```sql
SHOW CON_NAME;
```

Expected:

```text
PDB1
```

---

# LAB 10 — VERIFY DATABASE VAULT

```sql
SELECT
    status,
    status_code,
    description
FROM dba_dv_status;
```

Kemudian:

```sql
SELECT
    *
FROM dba_dv_status;
```

Tujuan lab ini bukan hanya mendapatkan `TRUE/FALSE`, tetapi memahami bahwa Database Vault memiliki status configuration dan enablement yang dapat diperiksa melalui data dictionary.

---

# LAB 11 — DATABASE VAULT ROLES

Cek:

```sql
SELECT
    grantee,
    granted_role
FROM dba_role_privs
WHERE granted_role IN (
    'DV_OWNER',
    'DV_ACCTMGR',
    'DV_ADMIN',
    'DV_MONITOR'
)
ORDER BY grantee, granted_role;
```

Expected:

```text
GRANTEE          GRANTED_ROLE
---------------- ----------------
DV_OWNER_LAB     DV_OWNER
DV_ACCTMGR_LAB   DV_ACCTMGR
```

---

# LAB 12 — MEMBUAT USER APLIKASI

Sekarang kita siapkan data yang akan dilindungi.

Connect SYS:

```sql
sqlplus sys/oracle@localhost:1521/pdb1.localdomain as sysdba
```

Create application user:

```sql
CREATE USER dv_app_user
IDENTIFIED BY "DVApp#2026"
DEFAULT TABLESPACE users
QUOTA 100M ON users;
```

Expected:

```text
User created.
```

Grant:

```sql
GRANT CREATE SESSION TO dv_app_user;
```

Expected:

```text
Grant succeeded.
```

---

# LAB 13 — MEMBUAT DATA SENSITIF

Kita menggunakan tabel sederhana.

```sql
CREATE TABLE dv_app_user.customer_sensitive (
    customer_id NUMBER PRIMARY KEY,
    customer_name VARCHAR2(100),
    email VARCHAR2(200),
    credit_card VARCHAR2(30),
    salary NUMBER
);
```

Expected:

```text
Table created.
```

Insert:

```sql
INSERT INTO dv_app_user.customer_sensitive
VALUES (
    1,
    'Budi Santoso',
    'budi@example.com',
    '4111111111111111',
    15000000
);

INSERT INTO dv_app_user.customer_sensitive
VALUES (
    2,
    'Siti Aminah',
    'siti@example.com',
    '5555555555554444',
    18000000
);

COMMIT;
```

Expected:

```text
1 row created.

1 row created.

Commit complete.
```

Check:

```sql
SELECT
    customer_id,
    customer_name,
    email,
    credit_card,
    salary
FROM dv_app_user.customer_sensitive
ORDER BY customer_id;
```

Expected:

```text
CUSTOMER_ID CUSTOMER_NAME  EMAIL                 CREDIT_CARD       SALARY
----------- -------------- --------------------- ---------------- ----------
1           Budi Santoso   budi@example.com      4111111111111111 15000000
2           Siti Aminah    siti@example.com      5555555555554444 18000000
```

---

# LAB 14 — BUAT DBA USER

Sekarang kita membuat user yang **sengaja diberi privilege tinggi** untuk mendemonstrasikan masalah Database Vault.

```sql
CREATE USER dv_dba_user
IDENTIFIED BY "DVDba#2026"
DEFAULT TABLESPACE users
QUOTA 100M ON users;
```

Expected:

```text
User created.
```

Grant:

```sql
GRANT CREATE SESSION TO dv_dba_user;
```

Expected:

```text
Grant succeeded.
```

Untuk simulasi DBA:

```sql
GRANT SELECT ANY TABLE TO dv_dba_user;
```

Expected:

```text
Grant succeeded.
```

---

# LAB 15 — TEST WITHOUT REALM

Login sebagai:

```bash
sqlplus dv_dba_user/"DVDba#2026"@localhost:1521/pdb1.localdomain
```

Test:

```sql
SELECT
    customer_id,
    customer_name,
    credit_card,
    salary
FROM dv_app_user.customer_sensitive;
```

Expected:

```text
CUSTOMER_ID CUSTOMER_NAME  CREDIT_CARD       SALARY
----------- -------------- ---------------- ----------
1           Budi Santoso   4111111111111111 15000000
2           Siti Aminah    5555555555554444 18000000
```

Ini adalah security problem.

User memiliki:

```text
SELECT ANY TABLE
```

sehingga dapat membaca data yang seharusnya hanya digunakan oleh application.

---

# LAB 16 — CREATE DATABASE VAULT REALM

Sekarang kita menggunakan `DV_OWNER_LAB`.

```bash
sqlplus dv_owner_lab/"DVOwner#2026"@localhost:1521/pdb1.localdomain
```

Buat realm:

```sql
BEGIN
    DVSYS.DBMS_MACADM.CREATE_REALM(
        realm_name    => 'CUSTOMER_DATA_REALM',
        description   => 'Protect customer sensitive data',
        enabled       => DVSYS.DBMS_MACUTL.G_YES,
        audit_options => DVSYS.DBMS_MACUTL.G_REALM_AUDIT_FAIL
    );
END;
/
```

Expected:

```text
PL/SQL procedure successfully completed.
```

Oracle menyediakan `CREATE_REALM` untuk membuat boundary perlindungan dan `ADD_OBJECT_TO_REALM` untuk mendaftarkan object yang harus dilindungi. ([Oracle Documentation][4])

---

# LAB 17 — ADD TABLE TO REALM

```sql
BEGIN
    DVSYS.DBMS_MACADM.ADD_OBJECT_TO_REALM(
        realm_name    => 'CUSTOMER_DATA_REALM',
        object_owner  => 'DV_APP_USER',
        object_name   => 'CUSTOMER_SENSITIVE',
        object_type   => 'TABLE'
    );
END;
/
```

Expected:

```text
PL/SQL procedure successfully completed.
```

---

# LAB 18 — VERIFY REALM

```sql
SELECT
    realm_name,
    enabled,
    audit_options
FROM dba_dv_realm
WHERE realm_name = 'CUSTOMER_DATA_REALM';
```

Expected:

```text
REALM_NAME             ENABLED
---------------------- -------
CUSTOMER_DATA_REALM    Y
```

Check object:

```sql
SELECT
    realm_name,
    object_owner,
    object_name,
    object_type
FROM dba_dv_realm_object
WHERE realm_name = 'CUSTOMER_DATA_REALM';
```

Expected:

```text
REALM_NAME             OBJECT_OWNER  OBJECT_NAME
---------------------- ------------  ------------------
CUSTOMER_DATA_REALM    DV_APP_USER   CUSTOMER_SENSITIVE
```

---

# LAB 19 — TEST REALM PROTECTION

Login sebagai DBA:

```bash
sqlplus dv_dba_user/"DVDba#2026"@localhost:1521/pdb1.localdomain
```

Execute:

```sql
SELECT
    customer_id,
    customer_name,
    credit_card
FROM dv_app_user.customer_sensitive;
```

Sekarang hasilnya **harus berbeda dari sebelum realm**.

Tergantung status/configuration Database Vault, kita dapat memperoleh error seperti:

```text
ORA-01031: insufficient privileges
```

atau Database Vault violation.

### Konsep penting

Sebelum:

```text
DV_DBA_USER
      |
      | SELECT ANY TABLE
      v
CUSTOMER_SENSITIVE
      |
      v
   ACCESS
```

Setelah Realm:

```text
DV_DBA_USER
      |
      | SELECT ANY TABLE
      v
DATABASE VAULT
      |
      X
CUSTOMER_SENSITIVE
```

Inilah konsep utama Database Vault:

> **Database privilege tidak otomatis berarti unrestricted access terhadap object yang berada dalam protected realm.**

---

# LAB 20 — AUTHORIZE APPLICATION OWNER

Database Vault owner perlu menentukan siapa yang boleh mengakses realm.

Login:

```bash
sqlplus dv_owner_lab/"DVOwner#2026"@localhost:1521/pdb1.localdomain
```

Kemudian:

```sql
BEGIN
    DVSYS.DBMS_MACADM.ADD_AUTH_TO_REALM(
        realm_name  => 'CUSTOMER_DATA_REALM',
        grantee     => 'DV_APP_USER',
        auth_options => DVSYS.DBMS_MACUTL.G_REALM_AUTH_OWNER
    );
END;
/
```

Expected:

```text
PL/SQL procedure successfully completed.
```

---

# LAB 21 — VERIFY REALM AUTHORIZATION

```sql
SELECT
    realm_name,
    grantee,
    auth_options
FROM dba_dv_realm_auth
WHERE realm_name = 'CUSTOMER_DATA_REALM';
```

Expected kira-kira:

```text
REALM_NAME             GRANTEE
---------------------- -------------
CUSTOMER_DATA_REALM    DV_APP_USER
```

---

# LAB 22 — SIMULATION MODE

Ini **sangat penting dalam production**.

Jangan langsung membuat policy enforcement tanpa pengujian.

Oracle menyediakan simulation/training mode untuk mencatat aktivitas yang melanggar realm/command rule tanpa langsung memblokir operasi. Oracle mendokumentasikan penggunaan simulation mode untuk menguji realm dan melihat violation sebelum enforcement. ([Oracle Documentation][5])

Konsep:

```text
Production change
       |
       v
Simulation
       |
       v
Observe violations
       |
       v
Fix authorization
       |
       v
Enforcement
```

---

# LAB 23 — RULE SET

Sekarang kita membuat rule set sederhana.

Rule:

```text
Hanya DV_APP_USER yang boleh mengakses.
```

Create rule:

```sql
BEGIN
    DVSYS.DBMS_MACADM.CREATE_RULE(
        rule_name => 'ALLOW_DV_APP_USER',
        rule_expr =>
            'SYS_CONTEXT(''USERENV'',''SESSION_USER'') = ''DV_APP_USER'''
    );
END;
/
```

Expected:

```text
PL/SQL procedure successfully completed.
```

Create rule set:

```sql
BEGIN
    DVSYS.DBMS_MACADM.CREATE_RULE_SET(
        rule_set_name  => 'CUSTOMER_ACCESS_RULESET',
        description    => 'Allow customer application user',
        enabled        => DVSYS.DBMS_MACUTL.G_YES,
        eval_options   => DVSYS.DBMS_MACUTL.G_RULESET_EVAL_ALL,
        audit_options  => DVSYS.DBMS_MACUTL.G_RULESET_AUDIT_FAIL,
        fail_options   => DVSYS.DBMS_MACUTL.G_RULESET_FAIL_SHOW,
        fail_message   => 'Access denied by CUSTOMER_ACCESS_RULESET',
        fail_code      => 20001,
        handler_options => DVSYS.DBMS_MACUTL.G_RULESET_HANDLER_OFF,
        handler        => NULL
    );
END;
/
```

Expected:

```text
PL/SQL procedure successfully completed.
```

Add rule:

```sql
EXEC DVSYS.DBMS_MACADM.ADD_RULE_TO_RULE_SET(
    'CUSTOMER_ACCESS_RULESET',
    'ALLOW_DV_APP_USER'
);
```

Expected:

```text
PL/SQL procedure successfully completed.
```

Oracle mendefinisikan rule sebagai ekspresi PL/SQL yang menghasilkan `TRUE/FALSE`, sedangkan rule set menggabungkan satu atau beberapa rule untuk menentukan apakah suatu aktivitas diperbolehkan. ([Oracle Documentation][6])

---

# LAB 24 — VERIFY RULE

```sql
SELECT
    name AS rule_name,
    rule_expr
FROM dba_dv_rule
WHERE name = 'ALLOW_DV_APP_USER';
```

Expected:

```text
RULE_NAME
---------------------
ALLOW_DV_APP_USER

RULE_EXPR
---------------------------------------------------
SYS_CONTEXT(...) = 'DV_APP_USER'
```

Rule set:

```sql
SELECT
    rule_set_name,
    enabled,
    eval_options
FROM dba_dv_rule_set
WHERE rule_set_name = 'CUSTOMER_ACCESS_RULESET';
```

Expected:

```text
RULE_SET_NAME
-------------------------
CUSTOMER_ACCESS_RULESET
```

---

# LAB 25 — COMMAND RULE

Sekarang kita masuk ke fitur yang sangat penting.

Misalnya perusahaan ingin melarang user tertentu melakukan:

```sql
DROP TABLE
```

terhadap object tertentu.

Database Vault menyediakan **command rules** untuk memberikan kontrol lebih granular terhadap SQL command. Oracle menyediakan `CREATE_COMMAND_RULE` untuk mengasosiasikan command dengan rule set. ([Oracle Documentation][7])

Contoh konsep:

```text
DROP TABLE
    |
    v
COMMAND RULE
    |
    v
RULE SET
    |
    v
ALLOW / DENY
```

---

# LAB 26 — COMMAND RULE UNTUK DROP TABLE

Buat rule:

```sql
BEGIN
    DVSYS.DBMS_MACADM.CREATE_RULE(
        rule_name => 'DENY_DBA_DROP',
        rule_expr =>
            'SYS_CONTEXT(''USERENV'',''SESSION_USER'') <> ''DV_DBA_USER'''
    );
END;
/
```

Create rule set:

```sql
BEGIN
    DVSYS.DBMS_MACADM.CREATE_RULE_SET(
        rule_set_name   => 'DROP_TABLE_CONTROL',
        description     => 'Control DROP TABLE operations',
        enabled         => DVSYS.DBMS_MACUTL.G_YES,
        eval_options    => DVSYS.DBMS_MACUTL.G_RULESET_EVAL_ALL,
        audit_options   => DVSYS.DBMS_MACUTL.G_RULESET_AUDIT_FAIL,
        fail_options    => DVSYS.DBMS_MACUTL.G_RULESET_FAIL_SHOW,
        fail_message    => 'DROP TABLE is not permitted',
        fail_code       => 20002,
        handler_options => DVSYS.DBMS_MACUTL.G_RULESET_HANDLER_OFF,
        handler         => NULL
    );
END;
/
```

Add rule:

```sql
EXEC DVSYS.DBMS_MACADM.ADD_RULE_TO_RULE_SET(
    'DROP_TABLE_CONTROL',
    'DENY_DBA_DROP'
);
```

---

# LAB 27 — CREATE COMMAND RULE

Contoh:

```sql
BEGIN
    DVSYS.DBMS_MACADM.CREATE_COMMAND_RULE(
        command          => 'DROP TABLE',
        rule_set_name    => 'DROP_TABLE_CONTROL',
        object_owner     => 'DV_APP_USER',
        object_name      => 'CUSTOMER_SENSITIVE',
        enabled          => DVSYS.DBMS_MACUTL.G_YES
    );
END;
/
```

Expected:

```text
PL/SQL procedure successfully completed.
```

---

# LAB 28 — TEST COMMAND RULE (DIHAPUS)

Command rule berhasil dibuat pada host lab, tetapi uji `DROP TABLE` end-to-end
dihapus. Setelah Database Vault enforcement aktif, pemberian `DROP ANY TABLE`
kepada user demonstrasi diblokir oleh realm. Memberikan bypass atau otorisasi
realm hanya untuk memaksa pengujian akan melemahkan kontrol yang sedang diuji.

Verifikasi yang didukung pada host ini adalah pembuatan rule, rule set, dan
command rule pada Lab 26--27.

---
# LAB 29 — DATABASE VAULT SECURE APPLICATION ROLE

Konsep secure application role:

```text
User
 |
 v
DBMS_MACSEC_ROLES.SET_ROLE
 |
 v
Rule Set
 |
 +---- TRUE  --> Role enabled
 |
 +---- FALSE --> Role denied
```

Oracle menjelaskan bahwa secure application role diaktifkan melalui `DBMS_MACSEC_ROLES.SET_ROLE`, kemudian Database Vault mengevaluasi rule set yang terkait. Jika rule set TRUE, role diaktifkan; jika FALSE, role tidak diaktifkan. ([Oracle Documentation][8])

Contoh use case:

```text
Application
    |
    +-- normal session
    |
    +-- privileged function
             |
             v
       secure role
             |
             v
       sensitive data
```

Ini jauh lebih baik daripada memberikan privilege sensitif secara permanen kepada application user.

Pada host lab, secure role berikut berhasil dibuat dan diaktifkan. Jalankan
sebagai `C##DV_OWNER_LAB` di PDB1:

```sql
EXEC DVSYS.DBMS_MACADM.CREATE_ROLE(
    'LAB_SECURE_ROLE',
    DVSYS.DBMS_MACUTL.G_YES,
    'CUSTOMER_ACCESS_RULESET'
);
```

Kemudian login sebagai `DV_APP_USER` dan aktifkan:

```sql
EXEC DVSYS.DBMS_MACSEC_ROLES.SET_ROLE('LAB_SECURE_ROLE');

SELECT role
FROM session_roles
WHERE role = 'LAB_SECURE_ROLE';
```

Expected: `LAB_SECURE_ROLE` muncul di `SESSION_ROLES`.

---

# LAB 31 — DATABASE VAULT MULTITENANT

Environment kita:

```text
CDB
 |
 +-- PDB1
 |
 +-- PDB$SEED
```

Database Vault dapat dikonfigurasi pada PDB.

Check:

```sql
SELECT
    con_id,
    name,
    open_mode
FROM v$pdbs
ORDER BY con_id;
```

Expected:

```text
CON_ID NAME       OPEN_MODE
------ ---------- ----------
2      PDB$SEED   READ ONLY
3      PDB1       READ WRITE
```

Kita **hanya bekerja pada PDB1**.

Jangan melakukan perubahan Database Vault terhadap:

```text
PDB$SEED
```

karena seed digunakan sebagai template PDB.

---

# LAB 32 — PRIVILEGE ANALYSIS (DIHAPUS)

Skenario Privilege Analysis dihapus dari hands-on ini. Setelah Database Vault
diaktifkan pada PDB1 host lab, pemberian `CAPTURE_ADMIN`, `CREATE SESSION`, dan
system privilege yang diperlukan untuk user capture ditolak dengan
`ORA-47410: Realm violation`. Menambahkan otorisasi realm administratif hanya
untuk menjalankan lab ini akan mengubah model separation-of-duties yang sedang
didemonstrasikan.

Gunakan Privilege Analysis pada environment terpisah yang tidak menerapkan
Database Vault enforcement yang sama.

---
# 50. SKENARIO UJIAN PRAKTIKUM

Saya sarankan Day 5 diakhiri dengan **security challenge** berikut.

## Challenge 1 — Realm

Buat:

```text
REALM:
PAYMENT_REALM
```

Lindungi:

```text
DV_APP_USER.CUSTOMER_SENSITIVE
```

Expected:

```text
DV_DBA_USER
      |
      X
CUSTOMER_SENSITIVE
```

---

## Challenge 2 — Rule Set

Buat rule:

```text
Hanya DV_APP_USER yang boleh mengakses.
```

Rule expression:

```sql
SYS_CONTEXT('USERENV','SESSION_USER') = 'DV_APP_USER'
```

---

## Challenge 3 — Command Rule

Buat policy:

```text
DV_DBA_USER tidak boleh DROP TABLE.
```

---


---



<!-- ============================================================ -->
<!-- SOURCE: preventive_day5_v2.md -->
<!-- ============================================================ -->

<a id="day-5-v2"></a>

# DAY 5 — Database Vault, Privilege Analysis & TDE (v2)

> **Sumber file:** `preventive_day5_v2.md`

# ORACLE DATABASE SECURITY — DAY 5

## Database Vault, Privilege Analysis & Transparent Data Encryption

Hari ini kita akan mengikuti perjalanan data customer: mula-mula bisa dibaca oleh
user dengan privilege tinggi, lalu dilindungi dengan Database Vault. Kita juga
akan memeriksa privilege yang benar-benar dipakai dan mencoba membaca data
terenkripsi ketika wallet tertutup.

Setiap langkah berisi **perintah interaktif, contoh output, dan penjelasan hasil**.
Anda bisa membacanya terlebih dahulu untuk membayangkan alur, lalu mempraktikkan
perintah satu per satu saat VM tersedia.

### Environment training

```text
VM host        : 192.168.56.22 / srv1.localdomain
OS             : Oracle Linux 7.8
Oracle         : 19.8.0.0.0 Enterprise Edition
ORACLE_SID     : oradb
CDB            : ORADB
PDB            : PDB1
Service CDB    : oradb.localdomain
Service PDB    : pdb1.localdomain
ORACLE_HOME    : /u01/app/oracle/product/19.0.0/db_1
ORACLE_BASE    : /u01/app/oracle
OS user        : oracle
OS password    : oracle
SYS login      : / as sysdba (autentikasi OS)
```

### Apa yang akan kita pelajari?

- Membedakan pemilik Vault, pengelola akun, pemilik aplikasi, dan user DBA demonstrasi.
- Mengaktifkan Database Vault pada CDB root dan PDB1.
- Melindungi tabel dengan realm dan mengamati akses yang ditolak.
- Membuat rule, rule set, command rule, dan secure application role.
- Mengamati violation pada simulation mode lalu mengaktifkan enforcement kembali.
- Membandingkan privilege yang digunakan dan tidak digunakan.
- Mengenkripsi kolom, menutup wallet, mengamati kegagalan akses, dan memulihkan akses.

### Gambaran alur

```text
                       ORADB / CDB$ROOT
                       Konfigurasi Vault
                              |
                            PDB1
                              |
          +-------------------+--------------------+
          |                   |                    |
    DATABASE VAULT     PRIVILEGE ANALYSIS           TDE
          |                   |                    |
    CUSTOMER REALM       Capture workload      Keystore / wallet
          |                   |                    |
 DV_APP_USER.           PA_TEST_USER.           TDE_LAB.
 CUSTOMER_SENSITIVE     PA_PROBE                ENCRYPTED_CUSTOMER
```

### Cara mengikuti naskah

Perintah berlabel **shell** dijalankan pada terminal Linux VM. Perintah SQL dan
`CONNECT` dijalankan pada prompt `SQL>`. Anda tidak perlu menjalankan file skrip
lab atau membuat `format.sql`; pengaturan tampilan ditulis langsung bersama query.
Satu blok `BEGIN ... END; /` merupakan satu panggilan langkah PL/SQL.

Contoh hasil disusun dari pengujian VM tanggal 9 September 2026. Spasi tampilan
dirapikan; timestamp, ukuran SGA, jumlah log yang berulang, dan footer koneksi
bisa berbeda. Untuk error panjang, bagian utama ditampilkan dan diberi penjelasan.

**Untuk praktik dari awal**, gunakan snapshot awal training: Vault belum
dikonfigurasi, akun lab belum ada, dan wallet TDE existing sudah tersedia beserta master key-nya.
VM yang selesai pengujian sudah berisi objek lab. Jangan mengulang CREATE atau
CONFIGURE_DV pada objek/configuration yang sudah ada. Saat hanya membaca,
ikuti expected output untuk melihat perubahan kondisi pada setiap tahap.

Password yang ditulis pada lab adalah password khusus environment training ini.

---

# LAB 1 — LOGIN DAN PERSIAPAN ENVIRONMENT

Kita mulai dari akses OS. Setelah login sebagai oracle, siapkan environment agar perintah SQL*Plus mengarah ke instance yang benar.

## 1.1 Login ke VM

Jalankan dari terminal komputer peserta.

**Jalankan di shell/terminal**, bukan pada prompt `SQL>`.

```bash
ssh oracle@192.168.56.22
```

**Expected output:**

```text
oracle@192.168.56.22's password:
[oracle@srv1 ~]$
```

Masukkan password `oracle`. Prompt di atas adalah contoh bentuk prompt shell setelah login.

## 1.2 Set ORACLE_SID

**Jalankan di shell/terminal**, bukan pada prompt `SQL>`.

```bash
export ORACLE_SID=oradb
```

**Expected:** tidak ada output jika perintah berhasil; prompt siap menerima perintah berikutnya.

## 1.3 Set ORACLE_HOME

**Jalankan di shell/terminal**, bukan pada prompt `SQL>`.

```bash
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/db_1
```

**Expected:** tidak ada output jika perintah berhasil; prompt siap menerima perintah berikutnya.

## 1.4 Set ORACLE_BASE

**Jalankan di shell/terminal**, bukan pada prompt `SQL>`.

```bash
export ORACLE_BASE=/u01/app/oracle
```

**Expected:** tidak ada output jika perintah berhasil; prompt siap menerima perintah berikutnya.

## 1.5 Tambahkan executable Oracle ke PATH

**Jalankan di shell/terminal**, bukan pada prompt `SQL>`.

```bash
export PATH=$ORACLE_HOME/bin:$PATH
```

**Expected:** tidak ada output jika perintah berhasil; prompt siap menerima perintah berikutnya.

## 1.6 Periksa instance yang dipilih

**Jalankan di shell/terminal**, bukan pada prompt `SQL>`.

```bash
echo $ORACLE_SID
```

**Expected output:**

```text
oradb
```

Nilai inilah yang dipakai koneksi lokal `/ as sysdba`.

## 1.7 Periksa Oracle Home

**Jalankan di shell/terminal**, bukan pada prompt `SQL>`.

```bash
echo $ORACLE_HOME
```

**Expected output:**

```text
/u01/app/oracle/product/19.0.0/db_1
```

---

# LAB 2 — SQL*PLUS DAN DATABASE BASELINE

Kita membuka satu sesi SQL*Plus interaktif. Nanti kita berganti user menggunakan CONNECT, sehingga perubahan identitas terlihat pada setiap lab.

## 2.1 Buka SQL*Plus

**Jalankan di shell/terminal**, bukan pada prompt `SQL>`.

```bash
sqlplus /nolog
```

**Expected output:**

```text
SQL*Plus: Release 19.0.0.0.0 - Production
Version 19.8.0.0.0

SQL>
```

Cuplikan banner ditampilkan tanpa tanggal dan copyright. `/nolog` membuka SQL*Plus sebelum memilih user database.

## 2.2 Atur tampilan dasar

```sql
SET LINESIZE 160
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF
SET FEEDBACK ON
SET SQLBLANKLINES ON
```

**Expected:** tidak ada output jika perintah berhasil; prompt siap menerima perintah berikutnya.

LINESIZE memberi ruang satu baris; PAGESIZE mengurangi pengulangan heading. Pengaturan ini tidak mengubah data. Jalankan lagi bila membuka proses SQL*Plus baru.

## 2.3 Pastikan error latihan tidak menutup sesi

```sql
WHENEVER SQLERROR CONTINUE
```

**Expected:** tidak ada output jika perintah berhasil; prompt siap menerima perintah berikutnya.

Beberapa langkah sengaja menghasilkan error. Tetap baca hasil setiap langkah: lanjutkan hanya bila sesuai expected output.

## 2.4 Kembali sebagai SYS di CDB root

```sql
CONNECT / AS SYSDBA
```

**Expected output:**

```text
Connected.
```

Koneksi lokal ini memakai autentikasi OS user `oracle`. Container awalnya adalah `CDB$ROOT`.

## 2.5 Periksa container root

```sql
SHOW CON_NAME
```

**Expected output:**

```text
CON_NAME
------------------------------
CDB$ROOT
```

ORADB adalah nama database, sedangkan CDB$ROOT adalah nama container root.

## 2.6 Periksa database

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN name FORMAT A10
COLUMN open_mode FORMAT A20

SELECT name, open_mode, cdb
FROM v$database;
```

**Expected output:**

```text
NAME       OPEN_MODE            CDB
---------- -------------------- ---
ORADB      READ WRITE           YES

1 row selected.
```

## 2.7 Lihat PDB yang tersedia

```sql
SHOW PDBS
```

**Expected output:**

```text
    CON_ID CON_NAME                       OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
         2 PDB$SEED                       READ ONLY  NO
         3 PDB1                           READ WRITE NO
```

PDB1 adalah tempat objek aplikasi dibuat. PDB$SEED merupakan template PDB.

---

## 2.8 Pastikan wallet existing siap sebelum memulai

Pada snapshot awal training, wallet existing sudah OPEN. Periksa dari SYS di
CDB root sebelum membuat akun dan mengaktifkan Vault.

```sql
COLUMN status FORMAT A22
COLUMN wallet_type FORMAT A16
COLUMN wrl_parameter FORMAT A75

SELECT con_id, status, wallet_type, wrl_parameter
FROM v$encryption_wallet
ORDER BY con_id;
```

**Expected output:**

```text
    CON_ID STATUS                 WALLET_TYPE      WRL_PARAMETER
---------- ---------------------- ---------------- ---------------------------------------------------------------------------
         1 OPEN                   PASSWORD         /u01/app/oracle/admin/oradb/wallet
         2 OPEN                   PASSWORD
         3 OPEN                   PASSWORD

3 rows selected.
```

Jika wallet root CLOSED setelah VM baru dinyalakan, jalankan pembukaan wallet di
langkah 11.8 sebagai SYS di CDB root, lalu ulangi query ini. Jika lokasi berbeda
atau status NOT_AVAILABLE, periksa ORACLE_BASE dan lokasi wallet existing
bersama instruktur sebelum melanjutkan. Wallet dan master key existing tidak
perlu dibuat ulang.

---


# LAB 3 — CEK KOMPONEN DATABASE VAULT

Sebelum enable, bedakan komponen yang sudah terpasang dengan fitur yang sudah aktif. Di VM awal, komponen tersedia tetapi belum dikonfigurasi.

## 3.1 Periksa status Database Vault

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN name FORMAT A30
COLUMN status FORMAT A24

SELECT name, status
FROM dba_dv_status
ORDER BY name;
```

**Expected output:**

```text
NAME                           STATUS
------------------------------ ------------------------
DV_APP_PROTECTION              NOT CONFIGURED
DV_CONFIGURE_STATUS            FALSE
DV_ENABLE_STATUS               FALSE

3 rows selected.
```

`DV_APP_PROTECTION` adalah pengaturan terpisah. Fokus tahap ini adalah status konfigurasi dan enablement Vault.

## 3.2 Cek instalasi DV dan OLS

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN comp_id FORMAT A8
COLUMN comp_name FORMAT A35
COLUMN status FORMAT A10

SELECT comp_id, comp_name, status
FROM dba_registry
WHERE comp_id IN ('DV', 'OLS')
ORDER BY comp_id;
```

**Expected output:**

```text
COMP_ID  COMP_NAME                           STATUS
-------- ----------------------------------- ----------
DV       Oracle Database Vault               VALID
OLS      Oracle Label Security               VALID

2 rows selected.
```

VALID berarti komponen terpasang dengan baik. FALSE pada status Vault sebelumnya berarti konfigurasi dan enablement belum dilakukan.

**Checkpoint:** kita memiliki CDB dan PDB yang berjalan serta komponen DV/OLS yang siap dikonfigurasi. Berikutnya kita menyiapkan identitas administrator dan user latihan.

---

# LAB 4 — SIAPKAN PEMILIK VAULT DAN ACCOUNT MANAGER

Dua tugas administratif akan dipisahkan:

```text
C##DV_OWNER_LAB       → mengatur kebijakan Database Vault
C##DV_ACCTMGR_LAB     → mengelola akun database
```

Keduanya dibuat sebagai common user di CDB root. Karena itu namanya memakai prefix C##.

## 4.1 Buat C##DV_OWNER_LAB

```sql
CREATE USER c##dv_owner_lab
IDENTIFIED BY "DVOwner#2026"
CONTAINER=ALL;
```

**Expected output:**

```text
User created.
```

## 4.2 Buat C##DV_ACCTMGR_LAB

```sql
CREATE USER c##dv_acctmgr_lab
IDENTIFIED BY "DVAcctMgr#2026"
CONTAINER=ALL;
```

**Expected output:**

```text
User created.
```

## 4.3 Berikan hak login dan pindah container

```sql
GRANT CREATE SESSION, SET CONTAINER
TO c##dv_owner_lab, c##dv_acctmgr_lab
CONTAINER=ALL;
```

**Expected output:**

```text
Grant succeeded.
```

Role DV_OWNER dan DV_ACCTMGR akan diberikan oleh CONFIGURE_DV. Saat ini kedua akun baru disiapkan untuk login.

---

# LAB 5 — SIAPKAN USER APLIKASI DAN USER LATIHAN

Kita membuat user lokal di PDB1 dan memberi privilege yang diperlukan sebelum Vault enforcement aktif. Dengan urutan ini, lab tidak bergantung pada bypass realm administratif.

## 5.1 Pindah ke PDB1

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

**Expected output:**

```text
Session altered.
```

Objek aplikasi pada lab ini berada di PDB1.

## 5.2 Buat DV_APP_USER

```sql
CREATE USER dv_app_user
IDENTIFIED BY "DVApp#2026"
DEFAULT TABLESPACE users
QUOTA 100M ON users;
```

**Expected output:**

```text
User created.
```

Pemilik tabel customer.

## 5.3 Buat DV_DBA_USER

```sql
CREATE USER dv_dba_user
IDENTIFIED BY "DVDba#2026"
DEFAULT TABLESPACE users
QUOTA 10M ON users;
```

**Expected output:**

```text
User created.
```

User demonstrasi dengan SELECT ANY TABLE; bukan pemegang seluruh role DBA.

## 5.4 Buat PA_ADMIN

```sql
CREATE USER pa_admin
IDENTIFIED BY "PAAdmin#2026";
```

**Expected output:**

```text
User created.
```

Administrator privilege capture.

## 5.5 Buat PA_TEST_USER

```sql
CREATE USER pa_test_user
IDENTIFIED BY "PATest#2026"
DEFAULT TABLESPACE users
QUOTA 10M ON users;
```

**Expected output:**

```text
User created.
```

User yang workload-nya akan direkam.

## 5.6 Buat TDE_LAB

```sql
CREATE USER tde_lab
IDENTIFIED BY "TDELab#2026"
DEFAULT TABLESPACE users
QUOTA 10M ON users;
```

**Expected output:**

```text
User created.
```

Pemilik tabel untuk latihan enkripsi.

## 5.7 Berikan hak login dan membuat tabel

```sql
GRANT CREATE SESSION, CREATE TABLE
TO dv_app_user, dv_dba_user, pa_test_user, tde_lab;
```

**Expected output:**

```text
Grant succeeded.
```

Quota pada langkah sebelumnya menyediakan ruang di USERS untuk tabel milik user tersebut.

## 5.8 Berikan privilege pembacaan luas kepada user demonstrasi

```sql
GRANT SELECT ANY TABLE TO dv_dba_user;
```

**Expected output:**

```text
Grant succeeded.
```

Privilege ini yang akan kita uji sebelum dan sesudah perlindungan realm.

## 5.9 Berikan hak capture kepada PA_ADMIN

```sql
GRANT CREATE SESSION, CAPTURE_ADMIN TO pa_admin;
```

**Expected output:**

```text
Grant succeeded.
```

## 5.10 Tambahkan satu privilege untuk dibandingkan

```sql
GRANT CREATE VIEW TO pa_test_user;
```

**Expected output:**

```text
Grant succeeded.
```

Workload kita nanti hanya membuat tabel. Kita ingin melihat apakah CREATE VIEW akan tercatat sebagai privilege yang tidak digunakan.

---

# LAB 6 — MEMBUAT DATA CUSTOMER

Bayangkan aplikasi menyimpan identitas customer, nomor kartu contoh, dan salary. Kita membuat dua baris sederhana agar perubahan akses mudah diamati.

## 6.1 Connect sebagai DV_APP_USER di PDB1

```sql
CONNECT dv_app_user/"DVApp#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `DV_APP_USER` di PDB1.

## 6.2 Buat tabel customer

```sql
CREATE TABLE customer_sensitive (
    customer_id   NUMBER PRIMARY KEY,
    customer_name VARCHAR2(100),
    email         VARCHAR2(200),
    credit_card   VARCHAR2(30),
    salary        NUMBER
);
```

**Expected output:**

```text
Table created.
```

## 6.3 Masukkan customer pertama

```sql
INSERT INTO customer_sensitive
VALUES (
    1, 'Budi Santoso', 'budi@example.com',
    '4111111111111111', 15000000
);
```

**Expected output:**

```text
1 row created.
```

## 6.4 Masukkan customer kedua

```sql
INSERT INTO customer_sensitive
VALUES (
    2, 'Siti Aminah', 'siti@example.com',
    '5555555555554444', 18000000
);
```

**Expected output:**

```text
1 row created.
```

## 6.5 Simpan transaksi

```sql
COMMIT;
```

**Expected output:**

```text
Commit complete.
```

COMMIT memastikan data tersedia bagi session lain yang dipakai dalam pengujian.

## 6.6 Baca data sebagai pemilik aplikasi

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN customer_id FORMAT 999999
COLUMN customer_name FORMAT A16
COLUMN credit_card FORMAT A18
COLUMN salary FORMAT 999,999,999

SELECT customer_id, customer_name, credit_card, salary
FROM customer_sensitive
ORDER BY customer_id;
```

**Expected output:**

```text
CUSTOMER_ID CUSTOMER_NAME    CREDIT_CARD               SALARY
----------- ---------------- ------------------ -------------
          1 Budi Santoso     4111111111111111        15,000,000
          2 Siti Aminah      5555555555554444        18,000,000

2 rows selected.
```

Pemilik tabel dapat melihat kedua baris. Simpan gambaran ini untuk membandingkan hasil user DBA.

---

# LAB 7 — AKSES SEBELUM ADA PERLINDUNGAN

Sekarang kita berganti menjadi user lain. Kita juga menyiapkan tabel kosong DROP_PROBE untuk uji command rule nanti.

## 7.1 Connect sebagai DV_DBA_USER di PDB1

```sql
CONNECT dv_dba_user/"DVDba#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `DV_DBA_USER` di PDB1.

## 7.2 Baca tabel milik aplikasi

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN customer_id FORMAT 999999
COLUMN customer_name FORMAT A16
COLUMN credit_card FORMAT A18
COLUMN salary FORMAT 999,999,999

SELECT customer_id, customer_name, credit_card, salary
FROM dv_app_user.customer_sensitive
ORDER BY customer_id;
```

**Expected output:**

```text
CUSTOMER_ID CUSTOMER_NAME    CREDIT_CARD               SALARY
----------- ---------------- ------------------ -------------
          1 Budi Santoso     4111111111111111        15,000,000
          2 Siti Aminah      5555555555554444        18,000,000

2 rows selected.
```

Walaupun bukan pemilik tabel, DV_DBA_USER dapat membaca karena memiliki SELECT ANY TABLE. Inilah akses yang akan kita batasi dengan realm.

## 7.3 Buat tabel khusus uji DROP

```sql
CREATE TABLE drop_probe (id NUMBER);
```

**Expected output:**

```text
Table created.
```

## 7.4 Buktikan user sudah bisa melakukan DROP

```sql
DROP TABLE drop_probe PURGE;
```

**Expected output:**

```text
Table dropped.
```

Tabel ini milik DV_DBA_USER sendiri, sehingga tidak memerlukan DROP ANY TABLE.

## 7.5 Siapkan kembali tabel probe

```sql
CREATE TABLE drop_probe (id NUMBER);
```

**Expected output:**

```text
Table created.
```

Tabel kosong ini akan menjadi target command rule. Data customer tidak dipakai sebagai target DROP.

---

# LAB 8 — MEMBUAT PRIVILEGE CAPTURE

Privilege Analysis membantu menjawab: dari semua privilege yang sudah diberikan,
mana yang benar-benar dipakai pada suatu workload?

```text
Aktifkan capture → jalankan workload → hentikan capture → generate report
```

## 8.1 Connect sebagai PA_ADMIN di PDB1

```sql
CONNECT pa_admin/"PAAdmin#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `PA_ADMIN` di PDB1.

## 8.2 Buat policy capture

Ketik seluruh blok, termasuk `/` pada baris terakhir, untuk menjalankan satu langkah ini.

```sql
BEGIN
    DBMS_PRIVILEGE_CAPTURE.CREATE_CAPTURE(
        name        => 'DAY5_PA',
        description => 'Day 5 user workload',
        type        => DBMS_PRIVILEGE_CAPTURE.G_CONTEXT,
        condition   =>
          'SYS_CONTEXT(''USERENV'',''SESSION_USER'') = ''PA_TEST_USER'''
    );
END;
/
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

Condition menargetkan session PA_TEST_USER. Pembuatan policy belum mulai merekam workload.

## 8.3 Mulai capture

```sql
EXEC DBMS_PRIVILEGE_CAPTURE.ENABLE_CAPTURE('DAY5_PA');
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

Mulai sekarang jalankan workload dengan koneksi PA_TEST_USER yang baru.

---

# LAB 9 — WORKLOAD DAN HASIL PRIVILEGE ANALYSIS

Kita melakukan kegiatan kecil: membuat tabel, menambah satu baris, dan membaca hasilnya. Tidak ada CREATE VIEW pada workload ini.

## 9.1 Connect sebagai PA_TEST_USER di PDB1

```sql
CONNECT pa_test_user/"PATest#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `PA_TEST_USER` di PDB1.

## 9.2 Buat tabel workload

```sql
CREATE TABLE pa_probe (id NUMBER);
```

**Expected output:**

```text
Table created.
```

## 9.3 Tambahkan data workload

```sql
INSERT INTO pa_probe VALUES (1);
```

**Expected output:**

```text
1 row created.
```

## 9.4 Simpan data workload

```sql
COMMIT;
```

**Expected output:**

```text
Commit complete.
```

## 9.5 Baca hasil workload

```sql
SELECT * FROM pa_probe;
```

**Expected output:**

```text
        ID
----------
         1

1 row selected.
```

## 9.6 Connect sebagai PA_ADMIN di PDB1

```sql
CONNECT pa_admin/"PAAdmin#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `PA_ADMIN` di PDB1.

## 9.7 Hentikan capture

```sql
EXEC DBMS_PRIVILEGE_CAPTURE.DISABLE_CAPTURE('DAY5_PA');
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

## 9.8 Generate hasil capture

```sql
EXEC DBMS_PRIVILEGE_CAPTURE.GENERATE_RESULT('DAY5_PA');
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

Generate dilakukan setelah capture berhenti, agar report dapat dibaca.

## 9.9 Lihat privilege yang benar-benar digunakan

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN username FORMAT A18
COLUMN sys_priv FORMAT A30

SELECT DISTINCT username, sys_priv
FROM dba_used_sysprivs
WHERE capture = 'DAY5_PA'
  AND username = 'PA_TEST_USER'
ORDER BY sys_priv;
```

**Expected output:**

```text
USERNAME           SYS_PRIV
------------------ ------------------------------
PA_TEST_USER       CREATE SESSION
PA_TEST_USER       CREATE TABLE

2 rows selected.
```

CREATE SESSION dipakai untuk login. CREATE TABLE dipakai ketika user membuat tabel workload.

## 9.10 Lihat privilege yang belum digunakan

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN username FORMAT A18
COLUMN sys_priv FORMAT A30

SELECT DISTINCT username, sys_priv
FROM dba_unused_privs
WHERE capture = 'DAY5_PA'
  AND username = 'PA_TEST_USER'
  AND sys_priv IS NOT NULL
ORDER BY sys_priv;
```

**Expected output:**

```text
USERNAME           SYS_PRIV
------------------ ------------------------------
PA_TEST_USER       CREATE VIEW

1 row selected.
```

User tidak membuat view selama capture. CREATE VIEW menjadi kandidat untuk ditinjau. Hasil ini hanya menggambarkan workload yang direkam; evaluasi pekerjaan aplikasi lain sebelum mencabut privilege.

**Checkpoint:** user diberi CREATE SESSION, CREATE TABLE, dan CREATE VIEW. Report membedakan dua privilege yang dipakai dan satu privilege yang belum dipakai. Filter USERNAME menjaga report tetap fokus pada user latihan.

---

# LAB 10 — KONFIGURASI DATABASE VAULT DI ROOT

Kita mulai konfigurasi Vault. Pada environment multitenant ini, root harus siap sebelum konfigurasi PDB. Gunakan common user yang sudah dibuat pada Lab 4.

## 10.1 Kembali sebagai SYS di CDB root

```sql
CONNECT / AS SYSDBA
```

**Expected output:**

```text
Connected.
```

Koneksi lokal ini memakai autentikasi OS user `oracle`. Container awalnya adalah `CDB$ROOT`.

## 10.2 Daftarkan administrator Vault di root

Ketik seluruh blok, termasuk `/` pada baris terakhir, untuk menjalankan satu langkah ini.

```sql
BEGIN
    CONFIGURE_DV(
        dvowner_uname       => 'C##DV_OWNER_LAB',
        dvacctmgr_uname     => 'C##DV_ACCTMGR_LAB',
        force_local_dvowner => FALSE
    );
END;
/
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

CONFIGURE_DV adalah initial configuration. Jangan menjalankannya lagi pada root yang sudah dikonfigurasi.

## 10.3 Kompilasi ulang objek setelah konfigurasi

```sql
@?/rdbms/admin/utlrp.sql
```

**Expected output:**

```text
OBJECTS WITH ERRORS
-------------------
                  0

ERRORS DURING RECOMPILATION
---------------------------
                          0
```

Ini cuplikan bagian pemeriksaan akhir output. UTLRP juga mencetak timestamp dan pesan proses lain. `?` mengacu pada ORACLE_HOME. Ini utilitas bawaan Oracle untuk satu langkah pemeliharaan.

## 10.4 Connect sebagai C##DV_OWNER_LAB di CDB root

```sql
CONNECT c##dv_owner_lab/"DVOwner#2026"@localhost:1521/oradb.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `C##DV_OWNER_LAB` di CDB root.

## 10.5 Enable Database Vault di root

```sql
EXEC DVSYS.DBMS_MACADM.ENABLE_DV;
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

Berikutnya restart instance agar pengaturan root diterapkan.

---

# LAB 11 — RESTART INSTANCE DAN CEK ROOT

Restart kali ini dilakukan pada CDB root, sehingga memang terlihat pesan shutdown dan startup instance. Nanti restart PDB memiliki output yang berbeda.

## 11.1 Kembali sebagai SYS di CDB root

```sql
CONNECT / AS SYSDBA
```

**Expected output:**

```text
Connected.
```

Koneksi lokal ini memakai autentikasi OS user `oracle`. Container awalnya adalah `CDB$ROOT`.

## 11.2 Matikan instance secara normal

```sql
SHUTDOWN IMMEDIATE
```

**Expected output:**

```text
Database closed.
Database dismounted.
ORACLE instance shut down.
```

## 11.3 Nyalakan instance

```sql
STARTUP
```

**Expected output:**

```text
ORACLE instance started.

Total System Global Area 1073738888 bytes
Fixed Size                  9143432 bytes
Variable Size             532676608 bytes
Database Buffers          524288000 bytes
Redo Buffers                7630848 bytes
Database mounted.
Database opened.
```

Ukuran memori di atas berasal dari run VM. Nilainya dapat berbeda bila konfigurasi memori berubah.

## 11.4 Periksa apakah PDB1 sudah terbuka

```sql
SHOW PDBS
```

**Expected output:**

```text
    CON_ID CON_NAME                       OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
         2 PDB$SEED                       READ ONLY  NO
         3 PDB1                           READ WRITE NO
```

Pada VM yang diuji, PDB1 otomatis kembali READ WRITE. Tidak perlu membuka PDB1 lagi pada kondisi ini.

## 11.5 Hanya bila PDB1 berstatus MOUNTED

**Langkah bersyarat:** jalankan hanya jika SHOW PDBS menampilkan MOUNTED untuk PDB1.

```sql
ALTER PLUGGABLE DATABASE PDB1 OPEN;
```

**Expected output:**

```text
Pluggable database altered.
```

Lewati langkah ini jika output sebelumnya sudah READ WRITE. Membuka ulang PDB yang sudah terbuka akan menghasilkan ORA-65019.

## 11.6 Periksa status Database Vault

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN name FORMAT A30
COLUMN status FORMAT A24

SELECT name, status
FROM dba_dv_status
ORDER BY name;
```

**Expected output:**

```text
NAME                           STATUS
------------------------------ ------------------------
DV_APP_PROTECTION              NOT CONFIGURED
DV_CONFIGURE_STATUS            TRUE
DV_ENABLE_STATUS               TRUE

3 rows selected.
```

`DV_APP_PROTECTION` adalah pengaturan terpisah. Fokus tahap ini adalah status konfigurasi dan enablement Vault.

---

## 11.7 Periksa wallet existing setelah restart

Session masih SYS di CDB root. Wallet PASSWORD harus dibuka lagi setelah
restart, sebelum konfigurasi Vault di PDB dan akses ke objek terenkripsi.

```sql
COLUMN status FORMAT A22
COLUMN wallet_type FORMAT A16
COLUMN wrl_parameter FORMAT A75

SELECT con_id, status, wallet_type, wrl_parameter
FROM v$encryption_wallet
ORDER BY con_id;
```

**Expected output:**

```text
    CON_ID STATUS                 WALLET_TYPE      WRL_PARAMETER
---------- ---------------------- ---------------- ---------------------------------------------------------------------------
         1 CLOSED                 UNKNOWN          /u01/app/oracle/admin/oradb/wallet
         2 CLOSED                 UNKNOWN
         3 CLOSED                 UNKNOWN

3 rows selected.
```

Jika lokasi berbeda atau status NOT_AVAILABLE, hentikan langkah berikutnya.
Periksa kembali ORACLE_BASE pada shell yang menjalankan SQL*Plus, sesuai Lab 1.
Jangan membuat wallet baru untuk mengatasi salah lokasi.

## 11.8 Buka wallet yang sama

```sql
ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN
  IDENTIFIED BY "TDEWallet#2026"
  CONTAINER=ALL;
```

**Expected output:**

```text
keystore altered.
```

## 11.9 Pastikan wallet siap sebelum melanjutkan

```sql
SELECT con_id, status, wallet_type
FROM v$encryption_wallet
ORDER BY con_id;
```

**Expected output:**

```text
    CON_ID STATUS                 WALLET_TYPE
---------- ---------------------- ----------------
         1 OPEN                   PASSWORD
         2 OPEN                   PASSWORD
         3 OPEN                   PASSWORD

3 rows selected.
```

Pada VM ini sudah ada tablespace TS_SECURE yang terenkripsi. Wallet tertutup
dapat mengganggu operasi lain sebelum kita mencapai lab TDE. Karena itu,
pembukaan wallet tidak ditunda sampai Lab 26.

---


# LAB 12 — KONFIGURASI DATABASE VAULT DI PDB1

Root sudah aktif. Sekarang kita mendaftarkan administrator Vault pada PDB1, memakai common user yang sama.

## 12.1 Pindah ke PDB1

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

**Expected output:**

```text
Session altered.
```

Objek aplikasi pada lab ini berada di PDB1.

## 12.2 Daftarkan administrator Vault di PDB1

Ketik seluruh blok, termasuk `/` pada baris terakhir, untuk menjalankan satu langkah ini.

```sql
BEGIN
    CONFIGURE_DV(
        dvowner_uname   => 'C##DV_OWNER_LAB',
        dvacctmgr_uname => 'C##DV_ACCTMGR_LAB'
    );
END;
/
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

Panggilan ini berlaku pada PDB1, karena session sudah dipindahkan ke PDB1.

## 12.3 Kompilasi ulang objek PDB1

```sql
@?/rdbms/admin/utlrp.sql
```

**Expected output:**

```text
OBJECTS WITH ERRORS
-------------------
                  0

ERRORS DURING RECOMPILATION
---------------------------
                          0
```

Cuplikan akhir output UTLRP pada PDB1. Pada pengujian tidak ada objek error setelah kompilasi.

## 12.4 Connect sebagai C##DV_OWNER_LAB di PDB1

```sql
CONNECT c##dv_owner_lab/"DVOwner#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `C##DV_OWNER_LAB` di PDB1.

## 12.5 Enable Database Vault di PDB1

```sql
EXEC DVSYS.DBMS_MACADM.ENABLE_DV;
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

---

# LAB 13 — REOPEN PDB DAN VERIFIKASI VAULT

Kali ini kita hanya menutup dan membuka PDB1 dari root. Selalu perhatikan container sebelum menjalankan perintah administratif.

## 13.1 Kembali sebagai SYS di CDB root

```sql
CONNECT / AS SYSDBA
```

**Expected output:**

```text
Connected.
```

Koneksi lokal ini memakai autentikasi OS user `oracle`. Container awalnya adalah `CDB$ROOT`.

## 13.2 Tutup PDB1

```sql
ALTER PLUGGABLE DATABASE PDB1 CLOSE IMMEDIATE;
```

**Expected output:**

```text
Pluggable database altered.
```

## 13.3 Buka kembali PDB1

```sql
ALTER PLUGGABLE DATABASE PDB1 OPEN;
```

**Expected output:**

```text
Pluggable database altered.
```

Tidak ada pesan ORACLE instance started karena kita hanya membuka PDB.

## 13.4 Pindah ke PDB1

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

**Expected output:**

```text
Session altered.
```

Objek aplikasi pada lab ini berada di PDB1.

## 13.5 Periksa status Database Vault

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN name FORMAT A30
COLUMN status FORMAT A24

SELECT name, status
FROM dba_dv_status
ORDER BY name;
```

**Expected output:**

```text
NAME                           STATUS
------------------------------ ------------------------
DV_APP_PROTECTION              NOT CONFIGURED
DV_CONFIGURE_STATUS            TRUE
DV_ENABLE_STATUS               TRUE

3 rows selected.
```

`DV_APP_PROTECTION` adalah pengaturan terpisah. Fokus tahap ini adalah status konfigurasi dan enablement Vault.

## 13.6 Lihat pembagian role administratif

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN grantee FORMAT A24
COLUMN granted_role FORMAT A20

SELECT DISTINCT grantee, granted_role
FROM dba_role_privs
WHERE grantee IN ('C##DV_OWNER_LAB', 'C##DV_ACCTMGR_LAB')
  AND granted_role IN ('DV_OWNER', 'DV_ACCTMGR')
ORDER BY grantee, granted_role;
```

**Expected output:**

```text
GRANTEE                  GRANTED_ROLE
------------------------ --------------------
C##DV_ACCTMGR_LAB        DV_ACCTMGR
C##DV_OWNER_LAB          DV_OWNER

2 rows selected.
```

DISTINCT membuat pembacaan sederhana ketika dictionary mencatat grant common dan lokal untuk role yang sama.

---

## 13.7 Periksa wallet setelah reopen PDB1

Walaupun root tetap terbuka, wallet PDB1 dapat kembali CLOSED setelah PDB
ditutup dan dibuka. Session masih SYS di PDB1.

```sql
COLUMN status FORMAT A22
COLUMN wallet_type FORMAT A16

SELECT con_id, status, wallet_type
FROM v$encryption_wallet;
```

**Expected output:**

```text
    CON_ID STATUS                 WALLET_TYPE
---------- ---------------------- ----------------
         3 CLOSED                 UNKNOWN

1 row selected.
```

## 13.8 Buka kembali wallet PDB1

```sql
ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN
  IDENTIFIED BY "TDEWallet#2026"
  CONTAINER=CURRENT;
```

**Expected output:**

```text
keystore altered.
```

## 13.9 Pastikan wallet PDB1 sudah OPEN

```sql
SELECT con_id, status, wallet_type
FROM v$encryption_wallet;
```

**Expected output:**

```text
    CON_ID STATUS                 WALLET_TYPE
---------- ---------------------- ----------------
         3 OPEN                   PASSWORD

1 row selected.
```

Sekarang konfigurasi Vault dan akses key TDE sudah siap untuk lab berikutnya.

---


# LAB 14 — MEMBUKTIKAN SEPARATION OF DUTIES

Sesudah Vault aktif, SYS tidak otomatis menjadi pengelola semua akun. Kita membandingkan perintah CREATE USER yang sama dengan dua identitas berbeda.

## 14.1 Coba membuat user sebagai SYS di PDB1

```sql
CREATE USER day5_sod_probe
IDENTIFIED BY "SoDProbe#2026";
```

**Expected output:**

```text
ERROR at line 1:
ORA-01031: insufficient privileges
```

**Penolakan ini diharapkan.** Pada VM, SYS tidak bisa menjalankan operasi akun ini setelah Vault aktif. Perhatikan bahwa user belum dibuat.

## 14.2 Connect sebagai C##DV_ACCTMGR_LAB di PDB1

```sql
CONNECT c##dv_acctmgr_lab/"DVAcctMgr#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `C##DV_ACCTMGR_LAB` di PDB1.

## 14.3 Ulangi CREATE USER sebagai account manager

```sql
CREATE USER day5_sod_probe
IDENTIFIED BY "SoDProbe#2026";
```

**Expected output:**

```text
User created.
```

Perintah yang sebelumnya ditolak sekarang berhasil karena dijalankan oleh pengelola akun yang tepat.

## 14.4 Hapus akun probe yang baru dibuat

```sql
DROP USER day5_sod_probe;
```

**Expected output:**

```text
User dropped.
```

Akun probe belum mempunyai objek; keberadaannya hanya diperlukan untuk demonstrasi ini.

---

# LAB 15 — MEMBUAT REALM UNTUK DATA CUSTOMER

Realm adalah batas perlindungan untuk sekumpulan objek. Kita mendaftarkan satu tabel:

```text
CUSTOMER_DATA_REALM
        |
        +-- DV_APP_USER.CUSTOMER_SENSITIVE
```

User dengan SELECT ANY TABLE akan kita uji lagi setelah tabel masuk realm.

## 15.1 Connect sebagai C##DV_OWNER_LAB di PDB1

```sql
CONNECT c##dv_owner_lab/"DVOwner#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `C##DV_OWNER_LAB` di PDB1.

## 15.2 Buat customer realm

Ketik seluruh blok, termasuk `/` pada baris terakhir, untuk menjalankan satu langkah ini.

```sql
BEGIN
    DVSYS.DBMS_MACADM.CREATE_REALM(
        realm_name    => 'CUSTOMER_DATA_REALM',
        description   => 'Day5 customer data',
        enabled       => DVSYS.DBMS_MACUTL.G_YES,
        audit_options => DVSYS.DBMS_MACUTL.G_REALM_AUDIT_FAIL
    );
END;
/
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

Pada tahap ini definisi realm sudah ada. Selanjutnya tentukan objek yang dilindungi.

## 15.3 Masukkan tabel ke realm

Ketik seluruh blok, termasuk `/` pada baris terakhir, untuk menjalankan satu langkah ini.

```sql
BEGIN
    DVSYS.DBMS_MACADM.ADD_OBJECT_TO_REALM(
        realm_name   => 'CUSTOMER_DATA_REALM',
        object_owner => 'DV_APP_USER',
        object_name  => 'CUSTOMER_SENSITIVE',
        object_type  => 'TABLE'
    );
END;
/
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

## 15.4 Periksa realm

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN name FORMAT A30

SELECT name, enabled, audit_options
FROM dba_dv_realm
WHERE name = 'CUSTOMER_DATA_REALM';
```

**Expected output:**

```text
NAME                           E AUDIT_OPTIONS
------------------------------ - -------------
CUSTOMER_DATA_REALM            Y             1

1 row selected.
```

Y berarti realm aktif. Nilai audit_options pada konfigurasi ini adalah 1.

## 15.5 Periksa objek yang dilindungi

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN realm_name FORMAT A28
COLUMN owner FORMAT A20
COLUMN object_name FORMAT A24
COLUMN object_type FORMAT A14

SELECT realm_name, owner, object_name, object_type
FROM dba_dv_realm_object
WHERE realm_name = 'CUSTOMER_DATA_REALM';
```

**Expected output:**

```text
REALM_NAME                   OWNER                OBJECT_NAME              OBJECT_TYPE
---------------------------- -------------------- ------------------------ --------------
CUSTOMER_DATA_REALM          DV_APP_USER          CUSTOMER_SENSITIVE       TABLE

1 row selected.
```

---

# LAB 16 — UJI AKSES SETELAH REALM AKTIF

Ingat hasil Lab 7: DV_DBA_USER bisa membaca dua customer. Kita menjalankan query yang sama setelah ada realm.

## 16.1 Connect sebagai DV_DBA_USER di PDB1

```sql
CONNECT dv_dba_user/"DVDba#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `DV_DBA_USER` di PDB1.

## 16.2 Coba membaca data customer

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN customer_id FORMAT 999999
COLUMN customer_name FORMAT A16
COLUMN credit_card FORMAT A18
COLUMN salary FORMAT 999,999,999

SELECT customer_id, customer_name, credit_card
FROM dv_app_user.customer_sensitive
ORDER BY customer_id;
```

**Expected output:**

```text
ERROR at line 2:
ORA-01031: insufficient privileges
```

**Ini hasil yang diharapkan.** SELECT ANY TABLE masih dimiliki user, tetapi tidak lagi cukup untuk membaca tabel yang dilindungi realm.

## 16.3 Connect sebagai DV_APP_USER di PDB1

```sql
CONNECT dv_app_user/"DVApp#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `DV_APP_USER` di PDB1.

## 16.4 Bandingkan dengan pemilik tabel

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN customer_id FORMAT 999999
COLUMN customer_name FORMAT A16
COLUMN credit_card FORMAT A18
COLUMN salary FORMAT 999,999,999

SELECT customer_id, customer_name, credit_card
FROM customer_sensitive
ORDER BY customer_id;
```

**Expected output:**

```text
CUSTOMER_ID CUSTOMER_NAME    CREDIT_CARD
----------- ---------------- ------------------
          1 Budi Santoso     4111111111111111
          2 Siti Aminah      5555555555554444

2 rows selected.
```

Pemilik objek tetap dapat membaca pada **regular realm** yang dipakai lab ini, walaupun belum diberi otorisasi realm secara eksplisit. Jangan menyimpulkan bahwa regular realm menolak semua pemilik objek; mandatory realm berbeda.

**Apa yang berubah?**

```text
Sebelum realm: DV_DBA_USER + SELECT ANY TABLE → dua baris terbaca
Sesudah realm: DV_DBA_USER + SELECT ANY TABLE → ORA-01031
Pemilik tabel: DV_APP_USER                   → dua baris tetap terbaca
```

---

# LAB 17 — OTORISASI PEMILIK APLIKASI PADA REALM

Kita memberi DV_APP_USER otorisasi Owner pada realm. Selain berpartisipasi dalam realm, Owner dapat mengelola grant/revoke pada objek yang dilindungi sesuai privilege SQL-nya. Ini akan dipakai saat memberi SELECT kepada secure role.

## 17.1 Connect sebagai C##DV_OWNER_LAB di PDB1

```sql
CONNECT c##dv_owner_lab/"DVOwner#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `C##DV_OWNER_LAB` di PDB1.

## 17.2 Tambahkan realm owner

Ketik seluruh blok, termasuk `/` pada baris terakhir, untuk menjalankan satu langkah ini.

```sql
BEGIN
    DVSYS.DBMS_MACADM.ADD_AUTH_TO_REALM(
        realm_name   => 'CUSTOMER_DATA_REALM',
        grantee      => 'DV_APP_USER',
        auth_options => DVSYS.DBMS_MACUTL.G_REALM_AUTH_OWNER
    );
END;
/
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

## 17.3 Periksa otorisasi realm

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN realm_name FORMAT A28
COLUMN grantee FORMAT A20
COLUMN auth_options FORMAT A12

SELECT realm_name, grantee, auth_options
FROM dba_dv_realm_auth
WHERE realm_name = 'CUSTOMER_DATA_REALM';
```

**Expected output:**

```text
REALM_NAME                   GRANTEE              AUTH_OPTIONS
---------------------------- -------------------- ------------
CUSTOMER_DATA_REALM          DV_APP_USER          Owner

1 row selected.
```

Perhatikan hasil AUTH_OPTIONS berupa teks Owner pada view ini.

---

# LAB 18 — RULE DAN RULE SET UNTUK USER APLIKASI

Rule berisi kondisi TRUE/FALSE. Rule set menggabungkan kondisi tersebut untuk dipakai oleh suatu kontrol.

Aturan kita: **hanya session DV_APP_USER yang memenuhi syarat**. Rule set ini nanti dipasang pada secure application role; membuat rule set saja belum membatasi sebuah operasi.

## 18.1 Buat rule identitas aplikasi

Ketik seluruh blok, termasuk `/` pada baris terakhir, untuk menjalankan satu langkah ini.

```sql
BEGIN
    DVSYS.DBMS_MACADM.CREATE_RULE(
        rule_name => 'ALLOW_DV_APP_USER',
        rule_expr =>
          'SYS_CONTEXT(''USERENV'',''SESSION_USER'') = ''DV_APP_USER'''
    );
END;
/
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

## 18.2 Buat customer access rule set

Ketik seluruh blok, termasuk `/` pada baris terakhir, untuk menjalankan satu langkah ini.

```sql
BEGIN
    DVSYS.DBMS_MACADM.CREATE_RULE_SET(
        rule_set_name   => 'CUSTOMER_ACCESS_RULESET',
        description     => 'Allow app user',
        enabled         => DVSYS.DBMS_MACUTL.G_YES,
        eval_options    => DVSYS.DBMS_MACUTL.G_RULESET_EVAL_ALL,
        audit_options   => DVSYS.DBMS_MACUTL.G_RULESET_AUDIT_FAIL,
        fail_options    => DVSYS.DBMS_MACUTL.G_RULESET_FAIL_SHOW,
        fail_message    => 'Access denied by CUSTOMER_ACCESS_RULESET',
        fail_code       => 20001,
        handler_options => DVSYS.DBMS_MACUTL.G_RULESET_HANDLER_OFF,
        handler         => NULL
    );
END;
/
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

G_RULESET_EVAL_ALL mensyaratkan semua rule di dalam rule set bernilai TRUE. Pada latihan ini isinya satu rule.

## 18.3 Hubungkan rule ke rule set

Ketik seluruh blok, termasuk `/` pada baris terakhir, untuk menjalankan satu langkah ini.

```sql
BEGIN
    DVSYS.DBMS_MACADM.ADD_RULE_TO_RULE_SET(
        'CUSTOMER_ACCESS_RULESET',
        'ALLOW_DV_APP_USER'
    );
END;
/
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

## 18.4 Periksa ekspresi rule

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN rule_name FORMAT A25
COLUMN rule_expr FORMAT A70

SELECT name AS rule_name, rule_expr
FROM dba_dv_rule
WHERE name = 'ALLOW_DV_APP_USER';
```

**Expected output:**

```text
RULE_NAME                 RULE_EXPR
------------------------- ----------------------------------------------------------------------
ALLOW_DV_APP_USER         SYS_CONTEXT('USERENV','SESSION_USER') = 'DV_APP_USER'

1 row selected.
```

## 18.5 Periksa rule set

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN rule_set_name FORMAT A30
COLUMN eval_options_meaning FORMAT A20

SELECT rule_set_name, enabled, eval_options_meaning
FROM dba_dv_rule_set
WHERE rule_set_name = 'CUSTOMER_ACCESS_RULESET';
```

**Expected output:**

```text
RULE_SET_NAME                  E EVAL_OPTIONS_MEANING
------------------------------ - --------------------
CUSTOMER_ACCESS_RULESET        Y All True

1 row selected.
```

---

# LAB 19 — COMMAND RULE UNTUK DROP TABLE

Sekarang kita mengatur sebuah perintah, yaitu DROP TABLE. Targetnya adalah tabel kosong DV_DBA_USER.DROP_PROBE yang sudah kita siapkan.

```text
DROP TABLE DROP_PROBE
        |
        v
DROP_TABLE_CONTROL
        |
        +-- session DV_DBA_USER? → tolak
```

Karena user memiliki tabel itu sendiri, penolakan nanti dapat dikaitkan dengan command rule, bukan kekurangan DROP ANY TABLE.

## 19.1 Buat rule penolakan DBA demonstrasi

Ketik seluruh blok, termasuk `/` pada baris terakhir, untuk menjalankan satu langkah ini.

```sql
BEGIN
    DVSYS.DBMS_MACADM.CREATE_RULE(
        rule_name => 'DENY_DBA_DROP',
        rule_expr =>
          'SYS_CONTEXT(''USERENV'',''SESSION_USER'') <> ''DV_DBA_USER'''
    );
END;
/
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

Untuk DV_DBA_USER, ekspresi ini bernilai FALSE.

## 19.2 Buat rule set kontrol DROP

Ketik seluruh blok, termasuk `/` pada baris terakhir, untuk menjalankan satu langkah ini.

```sql
BEGIN
    DVSYS.DBMS_MACADM.CREATE_RULE_SET(
        rule_set_name   => 'DROP_TABLE_CONTROL',
        description     => 'Control DROP on lab probe',
        enabled         => DVSYS.DBMS_MACUTL.G_YES,
        eval_options    => DVSYS.DBMS_MACUTL.G_RULESET_EVAL_ALL,
        audit_options   => DVSYS.DBMS_MACUTL.G_RULESET_AUDIT_FAIL,
        fail_options    => DVSYS.DBMS_MACUTL.G_RULESET_FAIL_SHOW,
        fail_message    => 'DROP TABLE is not permitted',
        fail_code       => 20002,
        handler_options => DVSYS.DBMS_MACUTL.G_RULESET_HANDLER_OFF,
        handler         => NULL
    );
END;
/
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

## 19.3 Masukkan rule ke rule set DROP

Ketik seluruh blok, termasuk `/` pada baris terakhir, untuk menjalankan satu langkah ini.

```sql
BEGIN
    DVSYS.DBMS_MACADM.ADD_RULE_TO_RULE_SET(
        'DROP_TABLE_CONTROL',
        'DENY_DBA_DROP'
    );
END;
/
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

## 19.4 Pasang command rule pada tabel probe

Ketik seluruh blok, termasuk `/` pada baris terakhir, untuk menjalankan satu langkah ini.

```sql
BEGIN
    DVSYS.DBMS_MACADM.CREATE_COMMAND_RULE(
        command       => 'DROP TABLE',
        rule_set_name => 'DROP_TABLE_CONTROL',
        object_owner  => 'DV_DBA_USER',
        object_name   => 'DROP_PROBE',
        enabled       => DVSYS.DBMS_MACUTL.G_YES
    );
END;
/
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

Sekarang rule set sudah dihubungkan ke perintah DROP TABLE untuk satu objek tertentu.

---

# LAB 20 — UJI PENOLAKAN COMMAND RULE

Kita ulangi DROP yang berhasil pada Lab 7. Identitas user dan tabelnya sama, tetapi sekarang command rule sudah aktif.

## 20.1 Connect sebagai DV_DBA_USER di PDB1

```sql
CONNECT dv_dba_user/"DVDba#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `DV_DBA_USER` di PDB1.

## 20.2 Coba DROP tabel milik sendiri

```sql
DROP TABLE drop_probe PURGE;
```

**Expected output:**

```text
ERROR at line 1:
ORA-47306: 20002: DROP TABLE is not permitted
```

**Penolakan ini diharapkan.** Pesan khusus 20002 berasal dari rule set yang baru dibuat.

## 20.3 Pastikan tabel masih ada

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN table_name FORMAT A24

SELECT table_name
FROM user_tables
WHERE table_name = 'DROP_PROBE';
```

**Expected output:**

```text
TABLE_NAME
------------------------
DROP_PROBE

1 row selected.
```

DROP yang ditolak tidak menghapus tabel.

---

# LAB 21 — BANDINGKAN DENGAN COMMAND RULE NONAKTIF

Untuk membuktikan sebab penolakan, nonaktifkan hanya command rule pada tabel probe, lalu ulangi DROP. Setelah pembuktian, siapkan kembali tabel dan perlindungannya.

## 21.1 Connect sebagai C##DV_OWNER_LAB di PDB1

```sql
CONNECT c##dv_owner_lab/"DVOwner#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `C##DV_OWNER_LAB` di PDB1.

## 21.2 Nonaktifkan command rule probe

Ketik seluruh blok, termasuk `/` pada baris terakhir, untuk menjalankan satu langkah ini.

```sql
BEGIN
    DVSYS.DBMS_MACADM.UPDATE_COMMAND_RULE(
        command       => 'DROP TABLE',
        rule_set_name => 'DROP_TABLE_CONTROL',
        object_owner  => 'DV_DBA_USER',
        object_name   => 'DROP_PROBE',
        enabled       => DVSYS.DBMS_MACUTL.G_NO
    );
END;
/
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

## 21.3 Connect sebagai DV_DBA_USER di PDB1

```sql
CONNECT dv_dba_user/"DVDba#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `DV_DBA_USER` di PDB1.

## 21.4 Ulangi DROP

```sql
DROP TABLE drop_probe PURGE;
```

**Expected output:**

```text
Table dropped.
```

Operasi sekarang berhasil. Perbedaan hasil menunjukkan pengaruh command rule.

## 21.5 Buat kembali tabel probe

```sql
CREATE TABLE drop_probe (id NUMBER);
```

**Expected output:**

```text
Table created.
```

## 21.6 Connect sebagai C##DV_OWNER_LAB di PDB1

```sql
CONNECT c##dv_owner_lab/"DVOwner#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `C##DV_OWNER_LAB` di PDB1.

## 21.7 Buat kembali command rule yang aktif

Ketik seluruh blok, termasuk `/` pada baris terakhir, untuk menjalankan satu langkah ini.

```sql
BEGIN
    DVSYS.DBMS_MACADM.CREATE_COMMAND_RULE(
        command       => 'DROP TABLE',
        rule_set_name => 'DROP_TABLE_CONTROL',
        object_owner  => 'DV_DBA_USER',
        object_name   => 'DROP_PROBE',
        enabled       => DVSYS.DBMS_MACUTL.G_YES
    );
END;
/
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

Pada VM ini, DROP tabel yang berhasil menghapus command rule terkait. Karena tabel sudah dibuat ulang, gunakan CREATE_COMMAND_RULE kembali, bukan UPDATE pada rule yang sudah hilang.

---

# LAB 22 — SECURE APPLICATION ROLE

Secure application role diaktifkan melalui prosedur yang mengevaluasi rule set.

```text
DBMS_MACSEC_ROLES.SET_ROLE
            |
    CUSTOMER_ACCESS_RULESET
            |
      +-----+-----+
      |           |
   TRUE         FALSE
 role aktif    ditolak
```

Kita akan mengamati SESSION_ROLES sebelum dan sesudah aktivasi, lalu mencoba user yang tidak memenuhi rule.

## 22.1 Buat secure role

Ketik seluruh blok, termasuk `/` pada baris terakhir, untuk menjalankan satu langkah ini.

```sql
BEGIN
    DVSYS.DBMS_MACADM.CREATE_ROLE(
        'LAB_SECURE_ROLE',
        DVSYS.DBMS_MACUTL.G_YES,
        'CUSTOMER_ACCESS_RULESET'
    );
END;
/
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

## 22.2 Connect sebagai DV_APP_USER di PDB1

```sql
CONNECT dv_app_user/"DVApp#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `DV_APP_USER` di PDB1.

## 22.3 Berikan privilege objek kepada role

```sql
GRANT SELECT ON customer_sensitive TO LAB_SECURE_ROLE;
```

**Expected output:**

```text
Grant succeeded.
```

DV_APP_USER adalah pemilik tabel dan sudah menjadi realm owner.

## 22.4 Nonaktifkan role pada session sebelum pembandingan

```sql
SET ROLE NONE;
```

**Expected output:**

```text
Role set.
```

## 22.5 Periksa role sebelum aktivasi

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN role FORMAT A30

SELECT role
FROM session_roles
WHERE role = 'LAB_SECURE_ROLE';
```

**Expected output:**

```text
no rows selected
```

## 22.6 Aktifkan secure role

```sql
EXEC DVSYS.DBMS_MACSEC_ROLES.SET_ROLE('LAB_SECURE_ROLE');
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

## 22.7 Periksa role setelah aktivasi

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN role FORMAT A30

SELECT role
FROM session_roles
WHERE role = 'LAB_SECURE_ROLE';
```

**Expected output:**

```text
ROLE
------------------------------
LAB_SECURE_ROLE

1 row selected.
```

Rule set menerima session DV_APP_USER. Role sekarang aktif pada session ini.

## 22.8 Connect sebagai DV_DBA_USER di PDB1

```sql
CONNECT dv_dba_user/"DVDba#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `DV_DBA_USER` di PDB1.

## 22.9 Coba aktivasi dengan user yang tidak memenuhi rule

```sql
EXEC DVSYS.DBMS_MACSEC_ROLES.SET_ROLE('LAB_SECURE_ROLE');
```

**Expected output:**

```text
ORA-47306: 20001: Access denied by CUSTOMER_ACCESS_RULESET
```

Cuplikan error utama ditampilkan; Oracle juga menampilkan stack ORA-06512. Session user ini bukan DV_APP_USER, sehingga aktivasi ditolak.

## 22.10 Pastikan role tidak aktif untuk DBA demonstrasi

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN role FORMAT A30

SELECT role
FROM session_roles
WHERE role = 'LAB_SECURE_ROLE';
```

**Expected output:**

```text
no rows selected
```

**Catatan pembelajaran:** DV_APP_USER juga pemilik tabel. Karena itu kemampuan SELECT user tersebut bukan bukti bahwa haknya berasal dari secure role. Bukti yang kita amati di sini adalah perubahan SESSION_ROLES dan penolakan aktivasi bagi user lain.

---

# LAB 23 — SIMULATION MODE

Simulation mode membantu melihat pelanggaran tanpa memblokir query. Kita akan melihat akses berhasil, mencatat pelanggarannya, lalu mengaktifkan enforcement kembali.

## 23.1 Connect sebagai C##DV_OWNER_LAB di PDB1

```sql
CONNECT c##dv_owner_lab/"DVOwner#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `C##DV_OWNER_LAB` di PDB1.

## 23.2 Ubah customer realm menjadi simulation

Ketik seluruh blok, termasuk `/` pada baris terakhir, untuk menjalankan satu langkah ini.

```sql
BEGIN
    DVSYS.DBMS_MACADM.UPDATE_REALM(
        realm_name  => 'CUSTOMER_DATA_REALM',
        description => 'Day5 customer data',
        enabled     => DVSYS.DBMS_MACUTL.G_SIMULATION
    );
END;
/
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

## 23.3 Connect sebagai DV_DBA_USER di PDB1

```sql
CONNECT dv_dba_user/"DVDba#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `DV_DBA_USER` di PDB1.

## 23.4 Ulangi SELECT yang sebelumnya ditolak

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN customer_id FORMAT 999999
COLUMN customer_name FORMAT A16
COLUMN credit_card FORMAT A18
COLUMN salary FORMAT 999,999,999

SELECT customer_id, customer_name, credit_card
FROM dv_app_user.customer_sensitive
ORDER BY customer_id;
```

**Expected output:**

```text
CUSTOMER_ID CUSTOMER_NAME    CREDIT_CARD
----------- ---------------- ------------------
          1 Budi Santoso     4111111111111111
          2 Siti Aminah      5555555555554444

2 rows selected.
```

Dua baris terbaca. Pada mode ini, keberhasilan query tidak berarti user sudah memperoleh otorisasi realm; pelanggarannya dicatat untuk evaluasi.

## 23.5 Connect sebagai C##DV_OWNER_LAB di PDB1

```sql
CONNECT c##dv_owner_lab/"DVOwner#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `C##DV_OWNER_LAB` di PDB1.

## 23.6 Lihat violation pada simulation log

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN username FORMAT A18
COLUMN command FORMAT A12
COLUMN object_owner FORMAT A18
COLUMN object_name FORMAT A22

SELECT username, command, object_owner, object_name, returncode
FROM dba_dv_simulation_log
WHERE object_owner = 'DV_APP_USER'
  AND object_name = 'CUSTOMER_SENSITIVE'
  AND username = 'DV_DBA_USER'
ORDER BY id;
```

**Expected output:**

```text
USERNAME           COMMAND      OBJECT_OWNER       OBJECT_NAME            RETURNCODE
------------------ ------------ ------------------ ---------------------- ----------
DV_DBA_USER        SELECT       DV_APP_USER        CUSTOMER_SENSITIVE           1031
```

Contoh satu entri ditampilkan. Jumlah entri bertambah jika pengujian diulang. RETURNCODE 1031 menunjukkan pelanggaran akses yang akan ditolak ketika enforcement aktif.

## 23.7 Kembalikan enforcement

Ketik seluruh blok, termasuk `/` pada baris terakhir, untuk menjalankan satu langkah ini.

```sql
BEGIN
    DVSYS.DBMS_MACADM.UPDATE_REALM(
        realm_name  => 'CUSTOMER_DATA_REALM',
        description => 'Day5 customer data',
        enabled     => DVSYS.DBMS_MACUTL.G_YES
    );
END;
/
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

## 23.8 Connect sebagai DV_DBA_USER di PDB1

```sql
CONNECT dv_dba_user/"DVDba#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `DV_DBA_USER` di PDB1.

## 23.9 Buktikan query kembali ditolak

```sql
SELECT credit_card
FROM dv_app_user.customer_sensitive;
```

**Expected output:**

```text
ERROR at line 2:
ORA-01031: insufficient privileges
```

Enforcement sudah kembali aktif. Jangan meninggalkan realm pada simulation setelah pembandingan selesai.

---

# LAB 24 — PRIVILEGE ANALYSIS SAAT VAULT SUDAH AKTIF

Apakah Privilege Analysis masih bisa digunakan setelah Vault aktif? Kita mengujinya dengan capture run baru pada policy yang sudah ada. Akun dan privilege sudah disiapkan sebelum enforcement.

## 24.1 Connect sebagai PA_ADMIN di PDB1

```sql
CONNECT pa_admin/"PAAdmin#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `PA_ADMIN` di PDB1.

## 24.2 Mulai capture run POST_DV

Ketik seluruh blok, termasuk `/` pada baris terakhir, untuk menjalankan satu langkah ini.

```sql
BEGIN
    DBMS_PRIVILEGE_CAPTURE.ENABLE_CAPTURE(
        name     => 'DAY5_PA',
        run_name => 'POST_DV'
    );
END;
/
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

## 24.3 Connect sebagai PA_TEST_USER di PDB1

```sql
CONNECT pa_test_user/"PATest#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `PA_TEST_USER` di PDB1.

## 24.4 Buat tabel workload kedua

```sql
CREATE TABLE pa_probe_after_dv (id NUMBER);
```

**Expected output:**

```text
Table created.
```

## 24.5 Masukkan data workload kedua

```sql
INSERT INTO pa_probe_after_dv VALUES (2);
```

**Expected output:**

```text
1 row created.
```

## 24.6 Simpan transaksi

```sql
COMMIT;
```

**Expected output:**

```text
Commit complete.
```

## 24.7 Periksa data workload kedua

```sql
SELECT * FROM pa_probe_after_dv;
```

**Expected output:**

```text
        ID
----------
         2

1 row selected.
```

## 24.8 Connect sebagai PA_ADMIN di PDB1

```sql
CONNECT pa_admin/"PAAdmin#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `PA_ADMIN` di PDB1.

## 24.9 Hentikan capture POST_DV

```sql
EXEC DBMS_PRIVILEGE_CAPTURE.DISABLE_CAPTURE('DAY5_PA');
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

## 24.10 Generate hasil run POST_DV

Ketik seluruh blok, termasuk `/` pada baris terakhir, untuk menjalankan satu langkah ini.

```sql
BEGIN
    DBMS_PRIVILEGE_CAPTURE.GENERATE_RESULT(
        name     => 'DAY5_PA',
        run_name => 'POST_DV'
    );
END;
/
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

## 24.11 Lihat privilege yang benar-benar digunakan

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN username FORMAT A18
COLUMN sys_priv FORMAT A30

SELECT DISTINCT username, sys_priv
FROM dba_used_sysprivs
WHERE capture = 'DAY5_PA'
  AND username = 'PA_TEST_USER'
  AND run_name = 'POST_DV'
ORDER BY sys_priv;
```

**Expected output:**

```text
USERNAME           SYS_PRIV
------------------ ------------------------------
PA_TEST_USER       CREATE SESSION
PA_TEST_USER       CREATE TABLE

2 rows selected.
```

CREATE SESSION dipakai untuk login. CREATE TABLE dipakai ketika user membuat tabel workload.

## 24.12 Lihat privilege yang belum digunakan

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN username FORMAT A18
COLUMN sys_priv FORMAT A30

SELECT DISTINCT username, sys_priv
FROM dba_unused_privs
WHERE capture = 'DAY5_PA'
  AND username = 'PA_TEST_USER'
  AND run_name = 'POST_DV'
  AND sys_priv IS NOT NULL
ORDER BY sys_priv;
```

**Expected output:**

```text
USERNAME           SYS_PRIV
------------------ ------------------------------
PA_TEST_USER       CREATE VIEW

1 row selected.
```

User tidak membuat view selama capture. CREATE VIEW menjadi kandidat untuk ditinjau. Hasil ini hanya menggambarkan workload yang direkam; evaluasi pekerjaan aplikasi lain sebelum mencabut privilege.

**Checkpoint:** Privilege Analysis berhasil sebelum dan sesudah Vault aktif pada VM ini. CREATE VIEW tetap tidak dipakai pada workload kedua. Kita tidak perlu menghapus skenario ini dari training.

---

# LAB 25 — KENALI WALLET TDE YANG SUDAH ADA

Wallet pada VM ini sudah dikonfigurasi oleh instruktur. Kita memakai wallet dan
master encryption key yang sama. Tidak perlu membuat direktori, menulis ulang
`sqlnet.ora`, membuat keystore, atau membuat master key baru.

```text
Hak SELECT + wallet terbuka → data terenkripsi dapat didekripsi
Hak SELECT + wallet tertutup → pembacaan kolom terenkripsi gagal
```

Tabel TDE dibuat di luar customer realm agar hasil percobaan mudah dibedakan
dari penolakan Database Vault.

## 25.1 Kembali sebagai SYS di CDB root

```sql
CONNECT / AS SYSDBA
```

**Expected output:**

```text
Connected.
```

## 25.2 Periksa parameter wallet root

```sql
SHOW PARAMETER wallet_root
```

**Expected output:**

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
wallet_root                          string
```

Nilai kosong bukan berarti wallet belum ada. VM ini memakai lokasi default
di bawah ORACLE_BASE, yaitu /u01/app/oracle/admin/oradb/wallet. File
sqlnet.ora tidak tersedia pada lokasi network/admin yang diperiksa. Karena itu,
ORACLE_BASE pada shell harus sesuai Lab 1. Periksa lokasi aktual melalui query berikut.

## 25.3 Periksa lokasi dan status wallet existing

Baris COLUMN mengatur tampilan tanpa mencetak output.

```sql
SET LINESIZE 160
COLUMN status FORMAT A22
COLUMN wallet_type FORMAT A16
COLUMN wrl_parameter FORMAT A75

SELECT con_id, status, wallet_type, wrl_parameter
FROM v$encryption_wallet
ORDER BY con_id;
```

**Expected output setelah wallet dipulihkan di Lab 11 dan Lab 13:**

```text
    CON_ID STATUS                 WALLET_TYPE      WRL_PARAMETER
---------- ---------------------- ---------------- ---------------------------------------------------------------------------
         1 OPEN                   PASSWORD         /u01/app/oracle/admin/oradb/wallet
         2 OPEN                   PASSWORD
         3 OPEN                   PASSWORD

3 rows selected.
```

Pada alur normal, wallet sudah dibuka pada Lab 11 dan Lab 13. Ketiga container tetap OPEN/PASSWORD. Lab 26 menyediakan langkah pemulihan bersyarat bila wallet Anda ternyata CLOSED.

---

# LAB 26 — BUKA KEMBALI WALLET EXISTING

Gunakan password wallet yang diberikan instruktur. Pada VM training ini
password-nya `TDEWallet#2026`. Password wallet berbeda dari password OS.

## 26.1 Buka wallet yang tertutup dari CDB root

Jalankan jika wallet root (CON_ID 1) CLOSED. Session masih SYS di CDB root.
Jika root sudah OPEN tetapi PDB1 CLOSED, gunakan langkah 29.1, 29.2, dan
29.5 untuk membuka wallet PDB1 saja, kemudian kembali ke SYS di root
sebelum menjalankan verifikasi 26.2.

```sql
ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN
  IDENTIFIED BY "TDEWallet#2026"
  CONTAINER=ALL;
```

**Expected output:**

```text
keystore altered.
```

Perintah ini membuka wallet existing. Tidak ada CREATE KEYSTORE atau SET KEY.
Jika wallet sudah OPEN, lewati langkah ini agar tidak mendapat pesan bahwa
wallet sudah terbuka.

## 26.2 Verifikasi status setiap container

```sql
COLUMN status FORMAT A22
COLUMN wallet_type FORMAT A16

SELECT con_id, status, wallet_type
FROM v$encryption_wallet
ORDER BY con_id;
```

**Expected output:**

```text
    CON_ID STATUS                 WALLET_TYPE
---------- ---------------------- ----------------
         1 OPEN                   PASSWORD
         2 OPEN                   PASSWORD
         3 OPEN                   PASSWORD

3 rows selected.
```

Pastikan PDB1 (CON_ID 3) berstatus OPEN sebelum membuat kolom terenkripsi.
Jika yang muncul OPEN_NO_MASTER_KEY, hentikan bagian TDE dan minta instruktur
memeriksa konfigurasi awal. Jangan membuat key baru sebagai jalan pintas.
Skenario tutup/buka berikut diuji dengan wallet PASSWORD, bukan AUTOLOGIN.

---

# LAB 27 — MEMBUAT KOLOM TERENKRIPSI

Pada tabel berikut, hanya CREDIT_CARD yang dienkripsi. CUSTOMER_NAME dibiarkan plaintext agar nanti kita bisa membandingkan kedua jenis kolom ketika wallet tertutup.

## 27.1 Connect sebagai TDE_LAB di PDB1

```sql
CONNECT tde_lab/"TDELab#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `TDE_LAB` di PDB1.

## 27.2 Buat tabel dengan kolom AES256

```sql
CREATE TABLE encrypted_customer (
    customer_id   NUMBER PRIMARY KEY,
    customer_name VARCHAR2(40),
    credit_card   VARCHAR2(30) ENCRYPT USING 'AES256'
);
```

**Expected output:**

```text
Table created.
```

## 27.3 Masukkan data contoh

```sql
INSERT INTO encrypted_customer
VALUES (1, 'Budi Santoso', '4111111111111111');
```

**Expected output:**

```text
1 row created.
```

## 27.4 Simpan data terenkripsi

```sql
COMMIT;
```

**Expected output:**

```text
Commit complete.
```

## 27.5 Baca data saat wallet terbuka

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN customer_id FORMAT 999999
COLUMN customer_name FORMAT A16
COLUMN credit_card FORMAT A18
COLUMN salary FORMAT 999,999,999

SELECT customer_id, customer_name, credit_card
FROM encrypted_customer
ORDER BY customer_id;
```

**Expected output:**

```text
CUSTOMER_ID CUSTOMER_NAME    CREDIT_CARD
----------- ---------------- ------------------
          1 Budi Santoso     4111111111111111

1 row selected.
```

Hasil query masih berupa nomor kartu yang dapat dibaca. TDE melakukan enkripsi/dekripsi secara transparan; ia tidak mengubah SELECT menjadi tampilan ciphertext untuk user yang berhak.

## 27.6 Buktikan kolom menggunakan enkripsi

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN table_name FORMAT A24
COLUMN column_name FORMAT A20
COLUMN encryption_alg FORMAT A30

SELECT table_name, column_name, encryption_alg, salt
FROM user_encrypted_columns
WHERE table_name = 'ENCRYPTED_CUSTOMER';
```

**Expected output:**

```text
TABLE_NAME               COLUMN_NAME          ENCRYPTION_ALG                 SAL
------------------------ -------------------- ------------------------------ ---
ENCRYPTED_CUSTOMER       CREDIT_CARD          AES 256 bits key               YES

1 row selected.
```

Metadata menunjukkan AES 256 bits key dan SALT=YES. Keberhasilan SELECT tidak berarti kolom tidak dienkripsi.

---

# LAB 28 — WALLET TERTUTUP: DATA TERENKRIPSI TIDAK DAPAT DIBACA

Kita menutup wallet PDB1 saja, lalu membuka koneksi user aplikasi yang baru. Perhatikan perbedaan hasil query pada kolom plaintext dan kolom terenkripsi.

## 28.1 Kembali sebagai SYS di CDB root

```sql
CONNECT / AS SYSDBA
```

**Expected output:**

```text
Connected.
```

Koneksi lokal ini memakai autentikasi OS user `oracle`. Container awalnya adalah `CDB$ROOT`.

## 28.2 Pindah ke PDB1

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

**Expected output:**

```text
Session altered.
```

Objek aplikasi pada lab ini berada di PDB1.

## 28.3 Tutup wallet PDB1

```sql
ADMINISTER KEY MANAGEMENT SET KEYSTORE CLOSE
  IDENTIFIED BY "TDEWallet#2026"
  CONTAINER=CURRENT;
```

**Expected output:**

```text
keystore altered.
```

CURRENT berarti PDB1, sesuai container session. Setelah pengujian, wallet akan dibuka kembali pada lab berikutnya.

## 28.4 Periksa wallet yang tertutup

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN status FORMAT A22
COLUMN wallet_type FORMAT A16

SELECT con_id, status, wallet_type
FROM v$encryption_wallet;
```

**Expected output:**

```text
    CON_ID STATUS                 WALLET_TYPE
---------- ---------------------- ----------------
         3 CLOSED                 UNKNOWN

1 row selected.
```

Pada VM ini, wallet yang tertutup dilaporkan CLOSED dengan WALLET_TYPE UNKNOWN.

## 28.5 Connect sebagai TDE_LAB di PDB1

```sql
CONNECT tde_lab/"TDELab#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `TDE_LAB` di PDB1.

## 28.6 Baca kolom yang tidak dienkripsi

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN customer_id FORMAT 999999
COLUMN customer_name FORMAT A16
COLUMN credit_card FORMAT A18
COLUMN salary FORMAT 999,999,999

SELECT customer_id, customer_name
FROM encrypted_customer
ORDER BY customer_id;
```

**Expected output:**

```text
CUSTOMER_ID CUSTOMER_NAME
----------- ----------------
          1 Budi Santoso

1 row selected.
```

Kolom customer_name tetap dapat dibaca karena tidak dienkripsi.

## 28.7 Sekarang baca kolom terenkripsi

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN customer_id FORMAT 999999
COLUMN customer_name FORMAT A16
COLUMN credit_card FORMAT A18
COLUMN salary FORMAT 999,999,999

SELECT customer_id, credit_card
FROM encrypted_customer
ORDER BY customer_id;
```

**Expected output:**

```text
ERROR at line 2:
ORA-28365: wallet is not open
```

**Inilah kegagalan yang ingin kita amati.** User tetap pemilik tabel, tetapi Oracle tidak dapat mendekripsi kolom saat wallet tertutup. Masalahnya tidak diselesaikan dengan menambahkan SELECT ANY TABLE.

---

# LAB 29 — BUKA WALLET DAN PULIHKAN AKSES

Data dan key tidak dihapus pada percobaan sebelumnya. Kita memulihkan akses dengan membuka keystore yang sama memakai password yang benar.

## 29.1 Kembali sebagai SYS di CDB root

```sql
CONNECT / AS SYSDBA
```

**Expected output:**

```text
Connected.
```

Koneksi lokal ini memakai autentikasi OS user `oracle`. Container awalnya adalah `CDB$ROOT`.

## 29.2 Pindah ke PDB1

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

**Expected output:**

```text
Session altered.
```

Objek aplikasi pada lab ini berada di PDB1.

## 29.3 Coba password yang salah

Untuk memahami penyebab kegagalan, kita sengaja memasukkan password yang salah
satu kali. Session masih SYS di PDB1. Ini tidak mengganti password wallet.

```sql
ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN
  IDENTIFIED BY "WrongWallet#2026"
  CONTAINER=CURRENT;
```

**Expected output:**

```text
ERROR at line 1:
ORA-46627: keystore password mismatch
```

Hak SYSDBA tidak membuat password yang salah menjadi valid. Kita perlu password
wallet existing yang benar untuk membuka key yang sama.

## 29.4 Pastikan percobaan gagal belum membuka wallet

```sql
COLUMN status FORMAT A22
COLUMN wallet_type FORMAT A16

SELECT con_id, status, wallet_type
FROM v$encryption_wallet;
```

**Expected output:**

```text
    CON_ID STATUS                 WALLET_TYPE
---------- ---------------------- ----------------
         3 CLOSED                 UNKNOWN

1 row selected.
```


## 29.5 Buka kembali wallet PDB1

```sql
ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN
  IDENTIFIED BY "TDEWallet#2026"
  CONTAINER=CURRENT;
```

**Expected output:**

```text
keystore altered.
```

Tidak perlu membuat key baru atau mengenkripsi ulang tabel untuk pemulihan wallet yang hanya tertutup.

## 29.6 Pastikan status kembali OPEN

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN status FORMAT A22
COLUMN wallet_type FORMAT A16

SELECT con_id, status, wallet_type
FROM v$encryption_wallet;
```

**Expected output:**

```text
    CON_ID STATUS                 WALLET_TYPE
---------- ---------------------- ----------------
         3 OPEN                   PASSWORD

1 row selected.
```

## 29.7 Connect sebagai TDE_LAB di PDB1

```sql
CONNECT tde_lab/"TDELab#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `TDE_LAB` di PDB1.

## 29.8 Ulangi pembacaan data

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN customer_id FORMAT 999999
COLUMN customer_name FORMAT A16
COLUMN credit_card FORMAT A18
COLUMN salary FORMAT 999,999,999

SELECT customer_id, customer_name, credit_card
FROM encrypted_customer
ORDER BY customer_id;
```

**Expected output:**

```text
CUSTOMER_ID CUSTOMER_NAME    CREDIT_CARD
----------- ---------------- ------------------
          1 Budi Santoso     4111111111111111

1 row selected.
```

Nomor kartu kembali terbaca dan sama dengan nilai sebelum wallet ditutup. Akses data terenkripsi sudah pulih.

**Bandingkan tiga kondisi ini:**

| Kondisi | Query kolom plaintext | Query CREDIT_CARD terenkripsi |
|---|---|---|
| Wallet OPEN sebelum uji | Berhasil | Berhasil |
| Wallet CLOSED | Berhasil | ORA-28365 |
| Wallet OPEN setelah pemulihan | Berhasil | Berhasil, nilai tetap sama |

Jika sesi terputus setelah penutupan wallet, kembali login sebagai SYS dan jalankan
langkah pembukaan wallet di atas. Skenario ini membahas wallet tertutup; kehilangan
file wallet atau key adalah masalah berbeda yang memerlukan backup key yang sesuai.

---

# LAB 30 — VERIFIKASI AKHIR DAN REFLEKSI

Sebelum mengakhiri praktik, pastikan mode simulasi sudah dikembalikan, command rule aktif, capture berhenti, dan wallet terbuka. Kita membaca hasilnya secara langsung.

## 30.1 Kembali sebagai SYS di CDB root

```sql
CONNECT / AS SYSDBA
```

**Expected output:**

```text
Connected.
```

Koneksi lokal ini memakai autentikasi OS user `oracle`. Container awalnya adalah `CDB$ROOT`.

## 30.2 Periksa Vault root dan PDB1

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN name FORMAT A30
COLUMN status FORMAT A24

SELECT con_id, name, status
FROM cdb_dv_status
WHERE con_id IN (1, 3)
  AND name IN ('DV_CONFIGURE_STATUS', 'DV_ENABLE_STATUS')
ORDER BY con_id, name;
```

**Expected output:**

```text
    CON_ID NAME                           STATUS
---------- ------------------------------ ------------------------
         1 DV_CONFIGURE_STATUS            TRUE
         1 DV_ENABLE_STATUS               TRUE
         3 DV_CONFIGURE_STATUS            TRUE
         3 DV_ENABLE_STATUS               TRUE

4 rows selected.
```

## 30.3 Periksa PDB1 tetap terbuka

```sql
SHOW PDBS
```

**Expected output:**

```text
    CON_ID CON_NAME                       OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
         2 PDB$SEED                       READ ONLY  NO
         3 PDB1                           READ WRITE NO
```

## 30.4 Periksa wallet terakhir

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN status FORMAT A22
COLUMN wallet_type FORMAT A16

SELECT con_id, status, wallet_type
FROM v$encryption_wallet
ORDER BY con_id;
```

**Expected output:**

```text
    CON_ID STATUS                 WALLET_TYPE
---------- ---------------------- ----------------
         1 OPEN                   PASSWORD
         2 OPEN                   PASSWORD
         3 OPEN                   PASSWORD

3 rows selected.
```

## 30.5 Connect sebagai C##DV_OWNER_LAB di PDB1

```sql
CONNECT c##dv_owner_lab/"DVOwner#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `C##DV_OWNER_LAB` di PDB1.

## 30.6 Pastikan customer realm aktif

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN name FORMAT A30

SELECT name, enabled
FROM dba_dv_realm
WHERE name = 'CUSTOMER_DATA_REALM';
```

**Expected output:**

```text
NAME                           E
------------------------------ -
CUSTOMER_DATA_REALM            Y

1 row selected.
```

## 30.7 Pastikan command rule aktif

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN command FORMAT A12
COLUMN object_owner FORMAT A20
COLUMN object_name FORMAT A24

SELECT command, object_owner, object_name, enabled
FROM dba_dv_command_rule
WHERE object_owner = 'DV_DBA_USER'
  AND object_name = 'DROP_PROBE';
```

**Expected output:**

```text
COMMAND      OBJECT_OWNER         OBJECT_NAME              E
------------ -------------------- ------------------------ -
DROP TABLE   DV_DBA_USER          DROP_PROBE               Y

1 row selected.
```

## 30.8 Connect sebagai PA_ADMIN di PDB1

```sql
CONNECT pa_admin/"PAAdmin#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `PA_ADMIN` di PDB1.

## 30.9 Pastikan capture sudah berhenti

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN name FORMAT A30

SELECT name, enabled
FROM dba_priv_captures
WHERE name = 'DAY5_PA';
```

**Expected output:**

```text
NAME                           E
------------------------------ -
DAY5_PA                        N
DAY5_PA                        N

2 rows selected.
```

Pada hasil VM dengan dua capture run, view menampilkan dua baris N. Yang diperiksa adalah capture tidak lagi aktif.

## 30.10 Keluar dari SQL*Plus

```sql
EXIT
```

**Expected output:**

```text
Disconnected from Oracle Database 19c Enterprise Edition ...
```

Footer disconnect disingkat. Objek latihan dibiarkan tersedia untuk diperiksa kembali.

### Pertanyaan untuk memastikan pemahaman

1. Mengapa SELECT ANY TABLE berhasil sebelum realm, lalu ditolak sesudahnya?
2. Mengapa pemilik tabel tetap dapat membaca pada regular realm yang kita buat?
3. Bagaimana uji DROP saat rule aktif dan nonaktif membantu membuktikan penyebab penolakan?
4. Apa bukti secure role aktif pada satu session dan ditolak pada session lain?
5. Mengapa CREATE VIEW muncul sebagai privilege yang tidak digunakan?
6. Mengapa CUSTOMER_NAME tetap terbaca saat wallet tertutup, tetapi CREDIT_CARD gagal?

### Arah jawaban

Realm membatasi pemakaian privilege luas terhadap objek terlindungi. Regular realm
pada latihan ini tetap mengizinkan pemilik objek membaca tabelnya. Command rule
dibuktikan dengan operasi yang sama: ditolak ketika rule aktif dan berhasil ketika
nonaktif. Aktivasi secure role terlihat di SESSION_ROLES, dengan uji negatif pada
user yang tidak memenuhi rule. CREATE VIEW tidak dipakai pada workload capture.
Kolom plaintext tidak memerlukan dekripsi, sedangkan CREDIT_CARD memerlukan wallet terbuka.

### Catatan untuk praktik berikutnya

Wallet PASSWORD pada latihan ini tidak auto-login. Jika instance direstart lagi,
buka wallet dari root sebelum membaca data terenkripsi. Setelah masuk SQL*Plus
sebagai OS user oracle, jalankan langkah berikut secara interaktif.

## 30.11 Buka SQL*Plus untuk pemulihan opsional

Bagian ini hanya dipakai pada praktik berikutnya, setelah instance direstart dan wallet tertutup.

**Jalankan di shell/terminal**, bukan pada prompt `SQL>`.

```bash
sqlplus /nolog
```

**Expected output:**

```text
SQL*Plus: Release 19.0.0.0.0 - Production
Version 19.8.0.0.0

SQL>
```

## 30.12 Kembali sebagai SYS di CDB root

```sql
CONNECT / AS SYSDBA
```

**Expected output:**

```text
Connected.
```

Koneksi lokal ini memakai autentikasi OS user `oracle`. Container awalnya adalah `CDB$ROOT`.

## 30.13 Buka wallet sesudah restart instance mendatang

**Pemulihan opsional setelah restart**, bukan lanjutan wajib dari kondisi akhir OPEN.

```sql
ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN
  IDENTIFIED BY "TDEWallet#2026"
  CONTAINER=ALL;
```

**Expected output:**

```text
keystore altered.
```

Langkah ini hanya diperlukan sesudah restart ketika wallet belum terbuka. Pada akhir lab normal wallet sudah OPEN, jadi tidak perlu dijalankan lagi.

### Referensi dan bukti untuk instruktur

Materi ini memakai hasil pengujian VM yang dirangkum pada [TEST_REPORT.md](TEST_REPORT.md).
Log rinci tersimpan di folder `test-results/`. Peserta dapat mengikuti naskah ini
tanpa membaca log maupun menjalankan skrip pengujian.

- [Oracle: Getting Started with Database Vault](https://docs.oracle.com/en/database/oracle/oracle-database/19/dvadm/getting-started-with-oracle-database-vault.html)
- [Oracle: Realm APIs](https://docs.oracle.com/en/database/oracle/oracle-database/19/dvadm/oracle-database-vault-realm-apis.html)
- [Oracle: Secure Application Role APIs](https://docs.oracle.com/en/database/oracle/oracle-database/19/dvadm/oracle-database-vault-secure-application-role-apis.html)
- [Oracle: DBMS_PRIVILEGE_CAPTURE](https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_PRIVILEGE_CAPTURE.html)
- [Oracle: ADMINISTER KEY MANAGEMENT](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/ADMINISTER-KEY-MANAGEMENT.html)


---



<!-- ============================================================ -->
<!-- SOURCE: preventive_day5_v3.md -->
<!-- ============================================================ -->

<a id="day-5-v3"></a>

# DAY 5 — Database Vault, Privilege Analysis & Pemulihan Akses TDE (v3)

> **Sumber file:** `preventive_day5_v3.md`

# ORACLE DATABASE SECURITY — DAY 5

## Database Vault, Privilege Analysis & Pemulihan Akses TDE

Hands-on Day 5 ini memisahkan **Database Vault** dan **Privilege Analysis**
menjadi dua alur yang jelas. User dan workload Privilege Analysis baru
dipersiapkan setelah seluruh rangkaian Database Vault selesai.

Di bagian akhir, kita menambahkan latihan TDE: membuktikan data terenkripsi tidak
bisa dibaca saat wallet tertutup, lalu memulihkan akses dengan membuka existing
wallet. Kita tidak membuat wallet baru dan tidak mengganti master key.

### Environment training

```text
VM host        : 192.168.56.22 / srv1.localdomain
OS             : Oracle Linux 7.8
Oracle         : 19.8.0.0.0 Enterprise Edition
ORACLE_SID     : oradb
CDB            : ORADB
PDB            : PDB1
Service CDB    : oradb.localdomain
Service PDB    : pdb1.localdomain
ORACLE_HOME    : /u01/app/oracle/product/19.0.0/db_1
ORACLE_BASE    : /u01/app/oracle
OS user        : oracle
OS password    : oracle
SYS login      : / as sysdba (autentikasi OS)
```

### Alur hands-on

```text
FOUNDATION
   |
   v
DATABASE VAULT PREPARATION
   |
   v
DATABASE VAULT
   |
   v
PRIVILEGE ANALYSIS PREPARATION
   |
   v
PRIVILEGE ANALYSIS
   |
   v
PA + DATABASE VAULT INTEGRATION
   |
   v
TDE: AKSES GAGAL DAN PEMULIHAN
   |
   v
FINAL VERIFICATION
```

> Kerjakan command secara berurutan, satu langkah setiap kali. Contoh hasil
> mengikuti pengujian pada VM ini; tanggal, durasi, dan ukuran memori dapat berbeda.
> Error yang sengaja dipicu akan dijelaskan pada langkahnya. Blok PL/SQL tetap
> diketik lengkap sampai `/`, karena satu blok merupakan satu operasi.

---


# PART 1 — FOUNDATION & ENVIRONMENT

# LAB 1 — LOGIN DAN PERSIAPAN ENVIRONMENT

Kita mulai dari akses OS. Setelah login sebagai oracle, siapkan environment agar perintah SQL*Plus mengarah ke instance yang benar.

## 1.1 Login ke VM

Jalankan dari terminal komputer peserta.

**Jalankan di shell/terminal**, bukan pada prompt `SQL>`.

```bash
ssh oracle@192.168.56.22
```

**Expected output:**

```text
oracle@192.168.56.22's password:
[oracle@srv1 ~]$
```

Masukkan password `oracle`. Prompt di atas adalah contoh bentuk prompt shell setelah login.

## 1.2 Set ORACLE_SID

**Jalankan di shell/terminal**, bukan pada prompt `SQL>`.

```bash
export ORACLE_SID=oradb
```

**Expected:** tidak ada output jika perintah berhasil; prompt siap menerima perintah berikutnya.

## 1.3 Set ORACLE_HOME

**Jalankan di shell/terminal**, bukan pada prompt `SQL>`.

```bash
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/db_1
```

**Expected:** tidak ada output jika perintah berhasil; prompt siap menerima perintah berikutnya.

## 1.4 Set ORACLE_BASE

**Jalankan di shell/terminal**, bukan pada prompt `SQL>`.

```bash
export ORACLE_BASE=/u01/app/oracle
```

**Expected:** tidak ada output jika perintah berhasil; prompt siap menerima perintah berikutnya.

## 1.5 Tambahkan executable Oracle ke PATH

**Jalankan di shell/terminal**, bukan pada prompt `SQL>`.

```bash
export PATH=$ORACLE_HOME/bin:$PATH
```

**Expected:** tidak ada output jika perintah berhasil; prompt siap menerima perintah berikutnya.

## 1.6 Periksa instance yang dipilih

**Jalankan di shell/terminal**, bukan pada prompt `SQL>`.

```bash
echo $ORACLE_SID
```

**Expected output:**

```text
oradb
```

Nilai inilah yang dipakai koneksi lokal `/ as sysdba`.

## 1.7 Periksa Oracle Home

**Jalankan di shell/terminal**, bukan pada prompt `SQL>`.

```bash
echo $ORACLE_HOME
```

**Expected output:**

```text
/u01/app/oracle/product/19.0.0/db_1
```

---

# LAB 2 — SQL*PLUS DAN DATABASE BASELINE

Kita membuka satu sesi SQL*Plus interaktif. Nanti kita berganti user menggunakan CONNECT, sehingga perubahan identitas terlihat pada setiap lab.

## 2.1 Buka SQL*Plus

**Jalankan di shell/terminal**, bukan pada prompt `SQL>`.

```bash
sqlplus /nolog
```

**Expected output:**

```text
SQL*Plus: Release 19.0.0.0.0 - Production
Version 19.8.0.0.0

SQL>
```

Cuplikan banner ditampilkan tanpa tanggal dan copyright. `/nolog` membuka SQL*Plus sebelum memilih user database.

## 2.2 Atur tampilan dasar

```sql
SET LINESIZE 160
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF
SET FEEDBACK ON
SET SQLBLANKLINES ON
```

**Expected:** tidak ada output jika perintah berhasil; prompt siap menerima perintah berikutnya.

LINESIZE memberi ruang satu baris; PAGESIZE mengurangi pengulangan heading. Pengaturan ini tidak mengubah data. Jalankan lagi bila membuka proses SQL*Plus baru.

## 2.3 Pastikan error latihan tidak menutup sesi

```sql
WHENEVER SQLERROR CONTINUE
```

**Expected:** tidak ada output jika perintah berhasil; prompt siap menerima perintah berikutnya.

Beberapa langkah sengaja menghasilkan error. Tetap baca hasil setiap langkah: lanjutkan hanya bila sesuai expected output.

## 2.4 Kembali sebagai SYS di CDB root

```sql
CONNECT / AS SYSDBA
```

**Expected output:**

```text
Connected.
```

Koneksi lokal ini memakai autentikasi OS user `oracle`. Container awalnya adalah `CDB$ROOT`.

## 2.5 Periksa container root

```sql
SHOW CON_NAME
```

**Expected output:**

```text
CON_NAME
------------------------------
CDB$ROOT
```

ORADB adalah nama database, sedangkan CDB$ROOT adalah nama container root.

## 2.6 Periksa database

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN name FORMAT A10
COLUMN open_mode FORMAT A20

SELECT name, open_mode, cdb
FROM v$database;
```

**Expected output:**

```text
NAME       OPEN_MODE            CDB
---------- -------------------- ---
ORADB      READ WRITE           YES

1 row selected.
```

## 2.7 Lihat PDB yang tersedia

```sql
SHOW PDBS
```

**Expected output:**

```text
    CON_ID CON_NAME                       OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
         2 PDB$SEED                       READ ONLY  NO
         3 PDB1                           READ WRITE NO
```

PDB1 adalah tempat objek aplikasi dibuat. PDB$SEED merupakan template PDB.

---

# LAB 3 — CEK KOMPONEN DATABASE VAULT

Sebelum enable, bedakan komponen yang sudah terpasang dengan fitur yang sudah aktif. Di baseline VM, komponen tersedia tetapi belum dikonfigurasi. Alur Lab 4–11 dimulai dari kondisi ini, dengan nama akun lab belum dipakai. Jika Vault sudah TRUE, jangan mengulang konfigurasi awal; gunakan baseline latihan yang sesuai.

## 3.1 Periksa status Database Vault

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN name FORMAT A30
COLUMN status FORMAT A24

SELECT name, status
FROM dba_dv_status
ORDER BY name;
```

**Expected output:**

```text
NAME                           STATUS
------------------------------ ------------------------
DV_APP_PROTECTION              NOT CONFIGURED
DV_CONFIGURE_STATUS            FALSE
DV_ENABLE_STATUS               FALSE

3 rows selected.
```

`DV_APP_PROTECTION` adalah pengaturan terpisah. Fokus tahap ini adalah status konfigurasi dan enablement Vault.

## 3.2 Cek instalasi DV dan OLS

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN comp_id FORMAT A8
COLUMN comp_name FORMAT A35
COLUMN status FORMAT A10

SELECT comp_id, comp_name, status
FROM dba_registry
WHERE comp_id IN ('DV', 'OLS')
ORDER BY comp_id;
```

**Expected output:**

```text
COMP_ID  COMP_NAME                           STATUS
-------- ----------------------------------- ----------
DV       Oracle Database Vault               VALID
OLS      Oracle Label Security               VALID

2 rows selected.
```

VALID berarti komponen terpasang dengan baik. FALSE pada status Vault sebelumnya berarti konfigurasi dan enablement belum dilakukan.

**Checkpoint:** kita memiliki CDB dan PDB yang berjalan serta komponen DV/OLS yang siap dikonfigurasi. Berikutnya kita menyiapkan identitas administrator dan user latihan.

---

# PART 2 — DATABASE VAULT PREPARATION

# LAB 4 — SIAPKAN PEMILIK VAULT DAN ACCOUNT MANAGER

Dua tugas administratif akan dipisahkan:

```text
C##DV_OWNER_LAB       → mengatur kebijakan Database Vault
C##DV_ACCTMGR_LAB     → mengelola akun database
```

Keduanya dibuat sebagai common user di CDB root. Karena itu namanya memakai prefix C##.

## 4.1 Buat C##DV_OWNER_LAB

```sql
CREATE USER c##dv_owner_lab
IDENTIFIED BY "DVOwner#2026"
CONTAINER=ALL;
```

**Expected output:**

```text
User created.
```

## 4.2 Buat C##DV_ACCTMGR_LAB

```sql
CREATE USER c##dv_acctmgr_lab
IDENTIFIED BY "DVAcctMgr#2026"
CONTAINER=ALL;
```

**Expected output:**

```text
User created.
```

## 4.3 Berikan hak login dan pindah container

```sql
GRANT CREATE SESSION, SET CONTAINER
TO c##dv_owner_lab, c##dv_acctmgr_lab
CONTAINER=ALL;
```

**Expected output:**

```text
Grant succeeded.
```

Role DV_OWNER dan DV_ACCTMGR akan diberikan oleh CONFIGURE_DV. Saat ini kedua akun baru disiapkan untuk login.

---

# LAB 5 — SIAPKAN USER KHUSUS DATABASE VAULT

Bagian ini hanya menyiapkan user yang dipakai pada skenario Database Vault.
User Privilege Analysis belum dibuat pada tahap ini.

## 5.1 Pindah ke PDB1

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

**Expected output:**

```text
Session altered.
```

Objek aplikasi pada lab ini berada di PDB1.

## 5.2 Buat DV_APP_USER

```sql
CREATE USER dv_app_user
IDENTIFIED BY "DVApp#2026"
DEFAULT TABLESPACE users
QUOTA 100M ON users;
```

**Expected output:**

```text
User created.
```

Pemilik tabel customer.

## 5.3 Buat DV_DBA_USER

User ini menjadi pembanding: ia punya hak baca luas, tetapi bukan administrator Vault.

```sql
CREATE USER dv_dba_user
IDENTIFIED BY "DVDba#2026"
DEFAULT TABLESPACE users
QUOTA 10M ON users;
```

**Expected output:**

```text
User created.
```

Quota dipakai untuk tabel kosong DROP_PROBE pada Lab 7.

## 5.4 Berikan hak login dan membuat tabel

```sql
GRANT CREATE SESSION, CREATE TABLE
TO dv_app_user, dv_dba_user;
```

**Expected output:**

```text
Grant succeeded.
```

Quota pada langkah sebelumnya menyediakan ruang di USERS untuk tabel milik user tersebut.

## 5.5 Berikan privilege pembacaan luas kepada user demonstrasi

```sql
GRANT SELECT ANY TABLE TO dv_dba_user;
```

**Expected output:**

```text
Grant succeeded.
```

Privilege ini yang akan kita uji sebelum dan sesudah perlindungan realm.

# LAB 6 — MEMBUAT DATA CUSTOMER KHUSUS DATABASE VAULT

Bayangkan aplikasi menyimpan identitas customer, nomor kartu contoh, dan salary. Kita membuat dua baris sederhana agar perubahan akses mudah diamati.

## 6.1 Connect sebagai DV_APP_USER di PDB1

```sql
CONNECT dv_app_user/"DVApp#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `DV_APP_USER` di PDB1.

## 6.2 Buat tabel customer

```sql
CREATE TABLE customer_sensitive (
    customer_id   NUMBER PRIMARY KEY,
    customer_name VARCHAR2(100),
    email         VARCHAR2(200),
    credit_card   VARCHAR2(30),
    salary        NUMBER
);
```

**Expected output:**

```text
Table created.
```

## 6.3 Masukkan customer pertama

```sql
INSERT INTO customer_sensitive
VALUES (
    1, 'Budi Santoso', 'budi@example.com',
    '4111111111111111', 15000000
);
```

**Expected output:**

```text
1 row created.
```

## 6.4 Masukkan customer kedua

```sql
INSERT INTO customer_sensitive
VALUES (
    2, 'Siti Aminah', 'siti@example.com',
    '5555555555554444', 18000000
);
```

**Expected output:**

```text
1 row created.
```

## 6.5 Simpan transaksi

```sql
COMMIT;
```

**Expected output:**

```text
Commit complete.
```

COMMIT memastikan data tersedia bagi session lain yang dipakai dalam pengujian.

## 6.6 Baca data sebagai pemilik aplikasi

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN customer_id FORMAT 999999
COLUMN customer_name FORMAT A16
COLUMN credit_card FORMAT A18
COLUMN salary FORMAT 999,999,999

SELECT customer_id, customer_name, credit_card, salary
FROM customer_sensitive
ORDER BY customer_id;
```

**Expected output:**

```text
CUSTOMER_ID CUSTOMER_NAME    CREDIT_CARD               SALARY
----------- ---------------- ------------------ -------------
          1 Budi Santoso     4111111111111111        15,000,000
          2 Siti Aminah      5555555555554444        18,000,000

2 rows selected.
```

Pemilik tabel dapat melihat kedua baris. Simpan gambaran ini untuk membandingkan hasil user DBA.

---

# LAB 7 — AKSES BASELINE SEBELUM PERLINDUNGAN DATABASE VAULT

Sekarang kita berganti menjadi user lain. Kita juga menyiapkan tabel kosong DROP_PROBE untuk uji command rule nanti.

## 7.1 Connect sebagai DV_DBA_USER di PDB1

```sql
CONNECT dv_dba_user/"DVDba#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `DV_DBA_USER` di PDB1.

## 7.2 Baca tabel milik aplikasi

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN customer_id FORMAT 999999
COLUMN customer_name FORMAT A16
COLUMN credit_card FORMAT A18
COLUMN salary FORMAT 999,999,999

SELECT customer_id, customer_name, credit_card, salary
FROM dv_app_user.customer_sensitive
ORDER BY customer_id;
```

**Expected output:**

```text
CUSTOMER_ID CUSTOMER_NAME    CREDIT_CARD               SALARY
----------- ---------------- ------------------ -------------
          1 Budi Santoso     4111111111111111        15,000,000
          2 Siti Aminah      5555555555554444        18,000,000

2 rows selected.
```

Walaupun bukan pemilik tabel, DV_DBA_USER dapat membaca karena memiliki SELECT ANY TABLE. Inilah akses yang akan kita batasi dengan realm.

## 7.3 Buat tabel khusus uji DROP

```sql
CREATE TABLE drop_probe (id NUMBER);
```

**Expected output:**

```text
Table created.
```

## 7.4 Buktikan user sudah bisa melakukan DROP

```sql
DROP TABLE drop_probe PURGE;
```

**Expected output:**

```text
Table dropped.
```

Tabel ini milik DV_DBA_USER sendiri, sehingga tidak memerlukan DROP ANY TABLE.

## 7.5 Siapkan kembali tabel probe

```sql
CREATE TABLE drop_probe (id NUMBER);
```

**Expected output:**

```text
Table created.
```

Tabel kosong ini akan menjadi target command rule. Data customer tidak dipakai sebagai target DROP.

---

# PART 3 — DATABASE VAULT

# LAB 8 — KONFIGURASI DATABASE VAULT DI ROOT

Kita mulai konfigurasi Vault. Pada environment multitenant ini, root harus siap sebelum konfigurasi PDB. Gunakan common user yang sudah dibuat pada Lab 4.

## 8.1 Kembali sebagai SYS di CDB root

```sql
CONNECT / AS SYSDBA
```

**Expected output:**

```text
Connected.
```

Koneksi lokal ini memakai autentikasi OS user `oracle`. Container awalnya adalah `CDB$ROOT`.

## 8.2 Daftarkan administrator Vault di root

Ketik seluruh blok, termasuk `/` pada baris terakhir, untuk menjalankan satu langkah ini.

```sql
BEGIN
    CONFIGURE_DV(
        dvowner_uname       => 'C##DV_OWNER_LAB',
        dvacctmgr_uname     => 'C##DV_ACCTMGR_LAB',
        force_local_dvowner => FALSE
    );
END;
/
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

CONFIGURE_DV adalah initial configuration. Jangan menjalankannya lagi pada root yang sudah dikonfigurasi.

## 8.3 Kompilasi ulang objek setelah konfigurasi

```sql
@?/rdbms/admin/utlrp.sql
```

**Expected output:**

```text
OBJECTS WITH ERRORS
-------------------
                  0

ERRORS DURING RECOMPILATION
---------------------------
                          0
```

Ini cuplikan bagian pemeriksaan akhir output. UTLRP juga mencetak timestamp dan pesan proses lain. `?` mengacu pada ORACLE_HOME. Ini utilitas bawaan Oracle untuk satu langkah pemeliharaan.

## 8.4 Connect sebagai C##DV_OWNER_LAB di CDB root

```sql
CONNECT c##dv_owner_lab/"DVOwner#2026"@localhost:1521/oradb.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `C##DV_OWNER_LAB` di CDB root.

## 8.5 Enable Database Vault di root

```sql
EXEC DVSYS.DBMS_MACADM.ENABLE_DV;
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

Berikutnya restart instance agar pengaturan root diterapkan.

---

# LAB 9 — RESTART INSTANCE DAN CEK ROOT

Setelah Database Vault di-enable pada root, restart instance dan verifikasi status root.

## 9.1 Kembali sebagai SYS di CDB root

```sql
CONNECT / AS SYSDBA
```

**Expected output:**

```text
Connected.
```

Koneksi lokal ini memakai autentikasi OS user `oracle`. Container awalnya adalah `CDB$ROOT`.

## 9.2 Matikan instance secara normal

```sql
SHUTDOWN IMMEDIATE
```

**Expected output:**

```text
Database closed.
Database dismounted.
ORACLE instance shut down.
```

## 9.3 Nyalakan instance

```sql
STARTUP
```

**Expected output:**

```text
ORACLE instance started.

Total System Global Area 1073738888 bytes
Fixed Size                  9143432 bytes
Variable Size             532676608 bytes
Database Buffers          524288000 bytes
Redo Buffers                7630848 bytes
Database mounted.
Database opened.
```

Ukuran memori di atas berasal dari run VM. Nilainya dapat berbeda bila konfigurasi memori berubah.

## 9.4 Periksa apakah PDB1 sudah terbuka

```sql
SHOW PDBS
```

**Expected output:**

```text
    CON_ID CON_NAME                       OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
         2 PDB$SEED                       READ ONLY  NO
         3 PDB1                           READ WRITE NO
```

Pada VM yang diuji, PDB1 otomatis kembali READ WRITE. Tidak perlu membuka PDB1 lagi pada kondisi ini.

## 9.5 Hanya bila PDB1 berstatus MOUNTED

**Langkah bersyarat:** jalankan hanya jika SHOW PDBS menampilkan MOUNTED untuk PDB1.

```sql
ALTER PLUGGABLE DATABASE PDB1 OPEN;
```

**Expected output:**

```text
Pluggable database altered.
```

Lewati langkah ini jika output sebelumnya sudah READ WRITE. Membuka ulang PDB yang sudah terbuka akan menghasilkan ORA-65019.

## 9.6 Periksa status Database Vault

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN name FORMAT A30
COLUMN status FORMAT A24

SELECT name, status
FROM dba_dv_status
ORDER BY name;
```

**Expected output:**

```text
NAME                           STATUS
------------------------------ ------------------------
DV_APP_PROTECTION              NOT CONFIGURED
DV_CONFIGURE_STATUS            TRUE
DV_ENABLE_STATUS               TRUE

3 rows selected.
```

`DV_APP_PROTECTION` adalah pengaturan terpisah. Fokus tahap ini adalah status konfigurasi dan enablement Vault.

---

## 9.7 Periksa wallet setelah restart

```sql
COLUMN status FORMAT A24
COLUMN wallet_type FORMAT A12

SELECT con_id, status, wallet_type
FROM v$encryption_wallet
ORDER BY con_id;
```

**Expected output:**

```text
    CON_ID STATUS                   WALLET_TYPE
---------- ------------------------ ------------
         1 CLOSED                   UNKNOWN
         2 CLOSED                   UNKNOWN
         3 CLOSED                   UNKNOWN

3 rows selected.
```

Wallet PASSWORD tidak terbuka otomatis setelah restart. OPEN pada database belum berarti wallet sudah OPEN.

## 9.8 Buka kembali existing wallet

```sql
ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN
IDENTIFIED BY "TDEWallet#2026" CONTAINER=ALL;
```

**Expected output:**

```text
keystore altered.
```

Jalankan sebagai SYS di CDB$ROOT. Kita memakai wallet yang sudah ada; tidak ada CREATE KEYSTORE atau SET KEY.

## 9.9 Pastikan wallet kembali terbuka

```sql
COLUMN status FORMAT A24
COLUMN wallet_type FORMAT A12

SELECT con_id, status, wallet_type
FROM v$encryption_wallet
ORDER BY con_id;
```

**Expected output:**

```text
    CON_ID STATUS                   WALLET_TYPE
---------- ------------------------ ------------
         1 OPEN                     PASSWORD
         2 OPEN                     PASSWORD
         3 OPEN                     PASSWORD

3 rows selected.
```



---

# LAB 10 — KONFIGURASI DATABASE VAULT DI PDB1

Root sudah aktif. Sekarang kita mendaftarkan administrator Vault pada PDB1, memakai common user yang sama.

## 10.1 Pindah ke PDB1

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

**Expected output:**

```text
Session altered.
```

Objek aplikasi pada lab ini berada di PDB1.

## 10.2 Daftarkan administrator Vault di PDB1

Ketik seluruh blok, termasuk `/` pada baris terakhir, untuk menjalankan satu langkah ini.

```sql
BEGIN
    CONFIGURE_DV(
        dvowner_uname   => 'C##DV_OWNER_LAB',
        dvacctmgr_uname => 'C##DV_ACCTMGR_LAB'
    );
END;
/
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

Panggilan ini berlaku pada PDB1, karena session sudah dipindahkan ke PDB1.

## 10.3 Kompilasi ulang objek PDB1

```sql
@?/rdbms/admin/utlrp.sql
```

**Expected output:**

```text
OBJECTS WITH ERRORS
-------------------
                  0

ERRORS DURING RECOMPILATION
---------------------------
                          0
```

Cuplikan akhir output UTLRP pada PDB1. Pada pengujian tidak ada objek error setelah kompilasi.

## 10.4 Connect sebagai C##DV_OWNER_LAB di PDB1

```sql
CONNECT c##dv_owner_lab/"DVOwner#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `C##DV_OWNER_LAB` di PDB1.

## 10.5 Enable Database Vault di PDB1

```sql
EXEC DVSYS.DBMS_MACADM.ENABLE_DV;
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

---

# LAB 11 — REOPEN PDB DAN VERIFIKASI VAULT

Setelah Database Vault di-enable pada PDB1, reopen PDB dan verifikasi status Vault serta role administratif.

## 11.1 Kembali sebagai SYS di CDB root

```sql
CONNECT / AS SYSDBA
```

**Expected output:**

```text
Connected.
```

Koneksi lokal ini memakai autentikasi OS user `oracle`. Container awalnya adalah `CDB$ROOT`.

## 11.2 Tutup PDB1

```sql
ALTER PLUGGABLE DATABASE PDB1 CLOSE IMMEDIATE;
```

**Expected output:**

```text
Pluggable database altered.
```

## 11.3 Buka kembali PDB1

```sql
ALTER PLUGGABLE DATABASE PDB1 OPEN;
```

**Expected output:**

```text
Pluggable database altered.
```

Tidak ada pesan ORACLE instance started karena kita hanya membuka PDB.

## 11.4 Pindah ke PDB1

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

**Expected output:**

```text
Session altered.
```

Objek aplikasi pada lab ini berada di PDB1.

## 11.5 Periksa status Database Vault

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN name FORMAT A30
COLUMN status FORMAT A24

SELECT name, status
FROM dba_dv_status
ORDER BY name;
```

**Expected output:**

```text
NAME                           STATUS
------------------------------ ------------------------
DV_APP_PROTECTION              NOT CONFIGURED
DV_CONFIGURE_STATUS            TRUE
DV_ENABLE_STATUS               TRUE

3 rows selected.
```

`DV_APP_PROTECTION` adalah pengaturan terpisah. Fokus tahap ini adalah status konfigurasi dan enablement Vault.

## 11.6 Lihat pembagian role administratif

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN grantee FORMAT A24
COLUMN granted_role FORMAT A20

SELECT DISTINCT grantee, granted_role
FROM dba_role_privs
WHERE grantee IN ('C##DV_OWNER_LAB', 'C##DV_ACCTMGR_LAB')
  AND granted_role IN ('DV_OWNER', 'DV_ACCTMGR')
ORDER BY grantee, granted_role;
```

**Expected output:**

```text
GRANTEE                  GRANTED_ROLE
------------------------ --------------------
C##DV_ACCTMGR_LAB        DV_ACCTMGR
C##DV_OWNER_LAB          DV_OWNER

2 rows selected.
```

DISTINCT membuat pembacaan sederhana ketika dictionary mencatat grant common dan lokal untuk role yang sama.

---

## 11.7 Periksa wallet PDB setelah reopen

```sql
COLUMN status FORMAT A24
COLUMN wallet_type FORMAT A12

SELECT con_id, status, wallet_type
FROM v$encryption_wallet
ORDER BY con_id;
```

**Expected output:**

```text
    CON_ID STATUS                   WALLET_TYPE
---------- ------------------------ ------------
         3 CLOSED                   UNKNOWN

1 row selected.
```

Pada VM ini, CLOSE/OPEN PDB juga menutup wallet PDB1. Session masih SYS di PDB1; wallet root sudah dibuka pada Lab 9.

## 11.8 Buka kembali wallet PDB1

```sql
ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN
IDENTIFIED BY "TDEWallet#2026" CONTAINER=CURRENT;
```

**Expected output:**

```text
keystore altered.
```



## 11.9 Pastikan wallet PDB1 siap

```sql
COLUMN status FORMAT A24
COLUMN wallet_type FORMAT A12

SELECT con_id, status, wallet_type
FROM v$encryption_wallet
ORDER BY con_id;
```

**Expected output:**

```text
    CON_ID STATUS                   WALLET_TYPE
---------- ------------------------ ------------
         3 OPEN                     PASSWORD

1 row selected.
```



---

# LAB 12 — MEMBUKTIKAN SEPARATION OF DUTIES

Sesudah Vault aktif, SYS tidak otomatis menjadi pengelola semua akun. Kita membandingkan perintah CREATE USER yang sama dengan dua identitas berbeda.

## 12.1 Coba membuat user sebagai SYS di PDB1

```sql
CREATE USER day5_sod_probe
IDENTIFIED BY "SoDProbe#2026";
```

**Expected output:**

```text
ERROR at line 1:
ORA-01031: insufficient privileges
```

**Penolakan ini diharapkan.** Pada VM, SYS tidak bisa menjalankan operasi akun ini setelah Vault aktif. Perhatikan bahwa user belum dibuat.

## 12.2 Connect sebagai C##DV_ACCTMGR_LAB di PDB1

```sql
CONNECT c##dv_acctmgr_lab/"DVAcctMgr#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `C##DV_ACCTMGR_LAB` di PDB1.

## 12.3 Ulangi CREATE USER sebagai account manager

```sql
CREATE USER day5_sod_probe
IDENTIFIED BY "SoDProbe#2026";
```

**Expected output:**

```text
User created.
```

Perintah yang sebelumnya ditolak sekarang berhasil karena dijalankan oleh pengelola akun yang tepat.

## 12.4 Hapus akun probe yang baru dibuat

```sql
DROP USER day5_sod_probe;
```

**Expected output:**

```text
User dropped.
```

Akun probe belum mempunyai objek; keberadaannya hanya diperlukan untuk demonstrasi ini.

---

# LAB 13 — MEMBUAT REALM UNTUK DATA CUSTOMER

Realm adalah batas perlindungan untuk sekumpulan objek. Kita mendaftarkan satu tabel:

```text
CUSTOMER_DATA_REALM
        |
        +-- DV_APP_USER.CUSTOMER_SENSITIVE
```

User dengan SELECT ANY TABLE akan kita uji lagi setelah tabel masuk realm.

## 13.1 Connect sebagai C##DV_OWNER_LAB di PDB1

```sql
CONNECT c##dv_owner_lab/"DVOwner#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `C##DV_OWNER_LAB` di PDB1.

## 13.2 Buat customer realm

Ketik seluruh blok, termasuk `/` pada baris terakhir, untuk menjalankan satu langkah ini.

```sql
BEGIN
    DVSYS.DBMS_MACADM.CREATE_REALM(
        realm_name    => 'CUSTOMER_DATA_REALM',
        description   => 'Day5 customer data',
        enabled       => DVSYS.DBMS_MACUTL.G_YES,
        audit_options => DVSYS.DBMS_MACUTL.G_REALM_AUDIT_FAIL
    );
END;
/
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

Pada tahap ini definisi realm sudah ada. Selanjutnya tentukan objek yang dilindungi.

## 13.3 Masukkan tabel ke realm

Ketik seluruh blok, termasuk `/` pada baris terakhir, untuk menjalankan satu langkah ini.

```sql
BEGIN
    DVSYS.DBMS_MACADM.ADD_OBJECT_TO_REALM(
        realm_name   => 'CUSTOMER_DATA_REALM',
        object_owner => 'DV_APP_USER',
        object_name  => 'CUSTOMER_SENSITIVE',
        object_type  => 'TABLE'
    );
END;
/
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

## 13.4 Periksa realm

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN name FORMAT A30

SELECT name, enabled, audit_options
FROM dba_dv_realm
WHERE name = 'CUSTOMER_DATA_REALM';
```

**Expected output:**

```text
NAME                           E AUDIT_OPTIONS
------------------------------ - -------------
CUSTOMER_DATA_REALM            Y             1

1 row selected.
```

Y berarti realm aktif. Nilai audit_options pada konfigurasi ini adalah 1.

## 13.5 Periksa objek yang dilindungi

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN realm_name FORMAT A28
COLUMN owner FORMAT A20
COLUMN object_name FORMAT A24
COLUMN object_type FORMAT A14

SELECT realm_name, owner, object_name, object_type
FROM dba_dv_realm_object
WHERE realm_name = 'CUSTOMER_DATA_REALM';
```

**Expected output:**

```text
REALM_NAME                   OWNER                OBJECT_NAME              OBJECT_TYPE
---------------------------- -------------------- ------------------------ --------------
CUSTOMER_DATA_REALM          DV_APP_USER          CUSTOMER_SENSITIVE       TABLE

1 row selected.
```

---

# LAB 14 — UJI AKSES SETELAH REALM AKTIF

Ingat hasil Lab 7: DV_DBA_USER bisa membaca dua customer. Kita menjalankan query yang sama setelah ada realm.

## 14.1 Connect sebagai DV_DBA_USER di PDB1

```sql
CONNECT dv_dba_user/"DVDba#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `DV_DBA_USER` di PDB1.

## 14.2 Coba membaca data customer

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN customer_id FORMAT 999999
COLUMN customer_name FORMAT A16
COLUMN credit_card FORMAT A18
COLUMN salary FORMAT 999,999,999

SELECT customer_id, customer_name, credit_card
FROM dv_app_user.customer_sensitive
ORDER BY customer_id;
```

**Expected output:**

```text
ERROR at line 2:
ORA-01031: insufficient privileges
```

**Ini hasil yang diharapkan.** SELECT ANY TABLE masih dimiliki user, tetapi tidak lagi cukup untuk membaca tabel yang dilindungi realm.

## 14.3 Connect sebagai DV_APP_USER di PDB1

```sql
CONNECT dv_app_user/"DVApp#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `DV_APP_USER` di PDB1.

## 14.4 Bandingkan dengan pemilik tabel

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN customer_id FORMAT 999999
COLUMN customer_name FORMAT A16
COLUMN credit_card FORMAT A18
COLUMN salary FORMAT 999,999,999

SELECT customer_id, customer_name, credit_card
FROM customer_sensitive
ORDER BY customer_id;
```

**Expected output:**

```text
CUSTOMER_ID CUSTOMER_NAME    CREDIT_CARD
----------- ---------------- ------------------
          1 Budi Santoso     4111111111111111
          2 Siti Aminah      5555555555554444

2 rows selected.
```

Pemilik objek tetap dapat membaca pada **regular realm** yang dipakai lab ini, walaupun belum diberi otorisasi realm secara eksplisit. Jangan menyimpulkan bahwa regular realm menolak semua pemilik objek; mandatory realm berbeda.

**Apa yang berubah?**

```text
Sebelum realm: DV_DBA_USER + SELECT ANY TABLE → dua baris terbaca
Sesudah realm: DV_DBA_USER + SELECT ANY TABLE → ORA-01031
Pemilik tabel: DV_APP_USER                   → dua baris tetap terbaca
```

---

# LAB 15 — OTORISASI PEMILIK APLIKASI PADA REALM

Kita memberi DV_APP_USER otorisasi Owner pada realm. Selain berpartisipasi dalam realm, Owner dapat mengelola grant/revoke pada objek yang dilindungi sesuai privilege SQL-nya. Ini akan dipakai saat memberi SELECT kepada secure role.

## 15.1 Connect sebagai C##DV_OWNER_LAB di PDB1

```sql
CONNECT c##dv_owner_lab/"DVOwner#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `C##DV_OWNER_LAB` di PDB1.

## 15.2 Tambahkan realm owner

Ketik seluruh blok, termasuk `/` pada baris terakhir, untuk menjalankan satu langkah ini.

```sql
BEGIN
    DVSYS.DBMS_MACADM.ADD_AUTH_TO_REALM(
        realm_name   => 'CUSTOMER_DATA_REALM',
        grantee      => 'DV_APP_USER',
        auth_options => DVSYS.DBMS_MACUTL.G_REALM_AUTH_OWNER
    );
END;
/
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

## 15.3 Periksa otorisasi realm

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN realm_name FORMAT A28
COLUMN grantee FORMAT A20
COLUMN auth_options FORMAT A12

SELECT realm_name, grantee, auth_options
FROM dba_dv_realm_auth
WHERE realm_name = 'CUSTOMER_DATA_REALM';
```

**Expected output:**

```text
REALM_NAME                   GRANTEE              AUTH_OPTIONS
---------------------------- -------------------- ------------
CUSTOMER_DATA_REALM          DV_APP_USER          Owner

1 row selected.
```

Perhatikan hasil AUTH_OPTIONS berupa teks Owner pada view ini.

---

# LAB 16 — RULE DAN RULE SET UNTUK USER APLIKASI

Rule berisi kondisi TRUE/FALSE. Rule set menggabungkan kondisi tersebut untuk dipakai oleh suatu kontrol.

Aturan kita: **hanya session DV_APP_USER yang memenuhi syarat**. Rule set ini nanti dipasang pada secure application role; membuat rule set saja belum membatasi sebuah operasi.

## 16.1 Buat rule identitas aplikasi

Ketik seluruh blok, termasuk `/` pada baris terakhir, untuk menjalankan satu langkah ini.

```sql
BEGIN
    DVSYS.DBMS_MACADM.CREATE_RULE(
        rule_name => 'ALLOW_DV_APP_USER',
        rule_expr =>
          'SYS_CONTEXT(''USERENV'',''SESSION_USER'') = ''DV_APP_USER'''
    );
END;
/
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

## 16.2 Buat customer access rule set

Ketik seluruh blok, termasuk `/` pada baris terakhir, untuk menjalankan satu langkah ini.

```sql
BEGIN
    DVSYS.DBMS_MACADM.CREATE_RULE_SET(
        rule_set_name   => 'CUSTOMER_ACCESS_RULESET',
        description     => 'Allow app user',
        enabled         => DVSYS.DBMS_MACUTL.G_YES,
        eval_options    => DVSYS.DBMS_MACUTL.G_RULESET_EVAL_ALL,
        audit_options   => DVSYS.DBMS_MACUTL.G_RULESET_AUDIT_FAIL,
        fail_options    => DVSYS.DBMS_MACUTL.G_RULESET_FAIL_SHOW,
        fail_message    => 'Access denied by CUSTOMER_ACCESS_RULESET',
        fail_code       => 20001,
        handler_options => DVSYS.DBMS_MACUTL.G_RULESET_HANDLER_OFF,
        handler         => NULL
    );
END;
/
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

G_RULESET_EVAL_ALL mensyaratkan semua rule di dalam rule set bernilai TRUE. Pada latihan ini isinya satu rule.

## 16.3 Hubungkan rule ke rule set

Ketik seluruh blok, termasuk `/` pada baris terakhir, untuk menjalankan satu langkah ini.

```sql
BEGIN
    DVSYS.DBMS_MACADM.ADD_RULE_TO_RULE_SET(
        'CUSTOMER_ACCESS_RULESET',
        'ALLOW_DV_APP_USER'
    );
END;
/
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

## 16.4 Periksa ekspresi rule

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN rule_name FORMAT A25
COLUMN rule_expr FORMAT A70

SELECT name AS rule_name, rule_expr
FROM dba_dv_rule
WHERE name = 'ALLOW_DV_APP_USER';
```

**Expected output:**

```text
RULE_NAME                 RULE_EXPR
------------------------- ----------------------------------------------------------------------
ALLOW_DV_APP_USER         SYS_CONTEXT('USERENV','SESSION_USER') = 'DV_APP_USER'

1 row selected.
```

## 16.5 Periksa rule set

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN rule_set_name FORMAT A30
COLUMN eval_options_meaning FORMAT A20

SELECT rule_set_name, enabled, eval_options_meaning
FROM dba_dv_rule_set
WHERE rule_set_name = 'CUSTOMER_ACCESS_RULESET';
```

**Expected output:**

```text
RULE_SET_NAME                  E EVAL_OPTIONS_MEANING
------------------------------ - --------------------
CUSTOMER_ACCESS_RULESET        Y All True

1 row selected.
```

---

# LAB 17 — COMMAND RULE UNTUK DROP TABLE

Sekarang kita mengatur sebuah perintah, yaitu DROP TABLE. Targetnya adalah tabel kosong DV_DBA_USER.DROP_PROBE yang sudah kita siapkan.

```text
DROP TABLE DROP_PROBE
        |
        v
DROP_TABLE_CONTROL
        |
        +-- session DV_DBA_USER? → tolak
```

Karena user memiliki tabel itu sendiri, penolakan nanti dapat dikaitkan dengan command rule, bukan kekurangan DROP ANY TABLE.

## 17.1 Buat rule penolakan DBA demonstrasi

Ketik seluruh blok, termasuk `/` pada baris terakhir, untuk menjalankan satu langkah ini.

```sql
BEGIN
    DVSYS.DBMS_MACADM.CREATE_RULE(
        rule_name => 'DENY_DBA_DROP',
        rule_expr =>
          'SYS_CONTEXT(''USERENV'',''SESSION_USER'') <> ''DV_DBA_USER'''
    );
END;
/
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

Untuk DV_DBA_USER, ekspresi ini bernilai FALSE.

## 17.2 Buat rule set kontrol DROP

Ketik seluruh blok, termasuk `/` pada baris terakhir, untuk menjalankan satu langkah ini.

```sql
BEGIN
    DVSYS.DBMS_MACADM.CREATE_RULE_SET(
        rule_set_name   => 'DROP_TABLE_CONTROL',
        description     => 'Control DROP on lab probe',
        enabled         => DVSYS.DBMS_MACUTL.G_YES,
        eval_options    => DVSYS.DBMS_MACUTL.G_RULESET_EVAL_ALL,
        audit_options   => DVSYS.DBMS_MACUTL.G_RULESET_AUDIT_FAIL,
        fail_options    => DVSYS.DBMS_MACUTL.G_RULESET_FAIL_SHOW,
        fail_message    => 'DROP TABLE is not permitted',
        fail_code       => 20002,
        handler_options => DVSYS.DBMS_MACUTL.G_RULESET_HANDLER_OFF,
        handler         => NULL
    );
END;
/
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

## 17.3 Masukkan rule ke rule set DROP

Ketik seluruh blok, termasuk `/` pada baris terakhir, untuk menjalankan satu langkah ini.

```sql
BEGIN
    DVSYS.DBMS_MACADM.ADD_RULE_TO_RULE_SET(
        'DROP_TABLE_CONTROL',
        'DENY_DBA_DROP'
    );
END;
/
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

## 17.4 Pasang command rule pada tabel probe

Ketik seluruh blok, termasuk `/` pada baris terakhir, untuk menjalankan satu langkah ini.

```sql
BEGIN
    DVSYS.DBMS_MACADM.CREATE_COMMAND_RULE(
        command       => 'DROP TABLE',
        rule_set_name => 'DROP_TABLE_CONTROL',
        object_owner  => 'DV_DBA_USER',
        object_name   => 'DROP_PROBE',
        enabled       => DVSYS.DBMS_MACUTL.G_YES
    );
END;
/
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

Sekarang rule set sudah dihubungkan ke perintah DROP TABLE untuk satu objek tertentu.

---

# LAB 18 — UJI PENOLAKAN COMMAND RULE

Kita ulangi DROP yang berhasil pada Lab 7. Identitas user dan tabelnya sama, tetapi sekarang command rule sudah aktif.

## 18.1 Connect sebagai DV_DBA_USER di PDB1

```sql
CONNECT dv_dba_user/"DVDba#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `DV_DBA_USER` di PDB1.

## 18.2 Coba DROP tabel milik sendiri

```sql
DROP TABLE drop_probe PURGE;
```

**Expected output:**

```text
ERROR at line 1:
ORA-47306: 20002: DROP TABLE is not permitted
```

**Penolakan ini diharapkan.** Pesan khusus 20002 berasal dari rule set yang baru dibuat.

## 18.3 Pastikan tabel masih ada

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN table_name FORMAT A24

SELECT table_name
FROM user_tables
WHERE table_name = 'DROP_PROBE';
```

**Expected output:**

```text
TABLE_NAME
------------------------
DROP_PROBE

1 row selected.
```

DROP yang ditolak tidak menghapus tabel.

---

# LAB 19 — BANDINGKAN DENGAN COMMAND RULE NONAKTIF

Untuk membuktikan sebab penolakan, nonaktifkan hanya command rule pada tabel probe, lalu ulangi DROP. Setelah pembuktian, siapkan kembali tabel dan perlindungannya.

## 19.1 Connect sebagai C##DV_OWNER_LAB di PDB1

```sql
CONNECT c##dv_owner_lab/"DVOwner#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `C##DV_OWNER_LAB` di PDB1.

## 19.2 Nonaktifkan command rule probe

Ketik seluruh blok, termasuk `/` pada baris terakhir, untuk menjalankan satu langkah ini.

```sql
BEGIN
    DVSYS.DBMS_MACADM.UPDATE_COMMAND_RULE(
        command       => 'DROP TABLE',
        rule_set_name => 'DROP_TABLE_CONTROL',
        object_owner  => 'DV_DBA_USER',
        object_name   => 'DROP_PROBE',
        enabled       => DVSYS.DBMS_MACUTL.G_NO
    );
END;
/
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

## 19.3 Connect sebagai DV_DBA_USER di PDB1

```sql
CONNECT dv_dba_user/"DVDba#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `DV_DBA_USER` di PDB1.

## 19.4 Ulangi DROP

```sql
DROP TABLE drop_probe PURGE;
```

**Expected output:**

```text
Table dropped.
```

Operasi sekarang berhasil. Perbedaan hasil menunjukkan pengaruh command rule.

## 19.5 Buat kembali tabel probe

```sql
CREATE TABLE drop_probe (id NUMBER);
```

**Expected output:**

```text
Table created.
```

## 19.6 Connect sebagai C##DV_OWNER_LAB di PDB1

```sql
CONNECT c##dv_owner_lab/"DVOwner#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `C##DV_OWNER_LAB` di PDB1.

## 19.7 Buat kembali command rule yang aktif

Ketik seluruh blok, termasuk `/` pada baris terakhir, untuk menjalankan satu langkah ini.

```sql
BEGIN
    DVSYS.DBMS_MACADM.CREATE_COMMAND_RULE(
        command       => 'DROP TABLE',
        rule_set_name => 'DROP_TABLE_CONTROL',
        object_owner  => 'DV_DBA_USER',
        object_name   => 'DROP_PROBE',
        enabled       => DVSYS.DBMS_MACUTL.G_YES
    );
END;
/
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

Pada VM ini, DROP tabel yang berhasil menghapus command rule terkait. Karena tabel sudah dibuat ulang, gunakan CREATE_COMMAND_RULE kembali, bukan UPDATE pada rule yang sudah hilang.

---

# LAB 20 — SECURE APPLICATION ROLE

Secure application role diaktifkan melalui prosedur yang mengevaluasi rule set.

```text
DBMS_MACSEC_ROLES.SET_ROLE
            |
    CUSTOMER_ACCESS_RULESET
            |
      +-----+-----+
      |           |
   TRUE         FALSE
 role aktif    ditolak
```

Kita akan mengamati SESSION_ROLES sebelum dan sesudah aktivasi, lalu mencoba user yang tidak memenuhi rule.

## 20.1 Buat secure role

Ketik seluruh blok, termasuk `/` pada baris terakhir, untuk menjalankan satu langkah ini.

```sql
BEGIN
    DVSYS.DBMS_MACADM.CREATE_ROLE(
        'LAB_SECURE_ROLE',
        DVSYS.DBMS_MACUTL.G_YES,
        'CUSTOMER_ACCESS_RULESET'
    );
END;
/
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

## 20.2 Connect sebagai DV_APP_USER di PDB1

```sql
CONNECT dv_app_user/"DVApp#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `DV_APP_USER` di PDB1.

## 20.3 Berikan privilege objek kepada role

```sql
GRANT SELECT ON customer_sensitive TO LAB_SECURE_ROLE;
```

**Expected output:**

```text
Grant succeeded.
```

DV_APP_USER adalah pemilik tabel dan sudah menjadi realm owner.

## 20.4 Nonaktifkan role pada session sebelum pembandingan

```sql
SET ROLE NONE;
```

**Expected output:**

```text
Role set.
```

## 20.5 Periksa role sebelum aktivasi

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN role FORMAT A30

SELECT role
FROM session_roles
WHERE role = 'LAB_SECURE_ROLE';
```

**Expected output:**

```text
no rows selected
```

## 20.6 Aktifkan secure role

```sql
EXEC DVSYS.DBMS_MACSEC_ROLES.SET_ROLE('LAB_SECURE_ROLE');
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

## 20.7 Periksa role setelah aktivasi

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN role FORMAT A30

SELECT role
FROM session_roles
WHERE role = 'LAB_SECURE_ROLE';
```

**Expected output:**

```text
ROLE
------------------------------
LAB_SECURE_ROLE

1 row selected.
```

Rule set menerima session DV_APP_USER. Role sekarang aktif pada session ini.

## 20.8 Connect sebagai DV_DBA_USER di PDB1

```sql
CONNECT dv_dba_user/"DVDba#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `DV_DBA_USER` di PDB1.

## 20.9 Coba aktivasi dengan user yang tidak memenuhi rule

```sql
EXEC DVSYS.DBMS_MACSEC_ROLES.SET_ROLE('LAB_SECURE_ROLE');
```

**Expected output:**

```text
ORA-47306: 20001: Access denied by CUSTOMER_ACCESS_RULESET
```

Cuplikan error utama ditampilkan; Oracle juga menampilkan stack ORA-06512. Session user ini bukan DV_APP_USER, sehingga aktivasi ditolak.

## 20.10 Pastikan role tidak aktif untuk DBA demonstrasi

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN role FORMAT A30

SELECT role
FROM session_roles
WHERE role = 'LAB_SECURE_ROLE';
```

**Expected output:**

```text
no rows selected
```

**Catatan pembelajaran:** DV_APP_USER juga pemilik tabel. Karena itu kemampuan SELECT user tersebut bukan bukti bahwa haknya berasal dari secure role. Bukti yang kita amati di sini adalah perubahan SESSION_ROLES dan penolakan aktivasi bagi user lain.

---

# LAB 21 — SIMULATION MODE

Simulation mode membantu melihat pelanggaran tanpa memblokir query. Kita akan melihat akses berhasil, mencatat pelanggarannya, lalu mengaktifkan enforcement kembali.

## 21.1 Connect sebagai C##DV_OWNER_LAB di PDB1

```sql
CONNECT c##dv_owner_lab/"DVOwner#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `C##DV_OWNER_LAB` di PDB1.

## 21.2 Ubah customer realm menjadi simulation

Ketik seluruh blok, termasuk `/` pada baris terakhir, untuk menjalankan satu langkah ini.

```sql
BEGIN
    DVSYS.DBMS_MACADM.UPDATE_REALM(
        realm_name  => 'CUSTOMER_DATA_REALM',
        description => 'Day5 customer data',
        enabled     => DVSYS.DBMS_MACUTL.G_SIMULATION
    );
END;
/
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

## 21.3 Connect sebagai DV_DBA_USER di PDB1

```sql
CONNECT dv_dba_user/"DVDba#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `DV_DBA_USER` di PDB1.

## 21.4 Ulangi SELECT yang sebelumnya ditolak

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN customer_id FORMAT 999999
COLUMN customer_name FORMAT A16
COLUMN credit_card FORMAT A18
COLUMN salary FORMAT 999,999,999

SELECT customer_id, customer_name, credit_card
FROM dv_app_user.customer_sensitive
ORDER BY customer_id;
```

**Expected output:**

```text
CUSTOMER_ID CUSTOMER_NAME    CREDIT_CARD
----------- ---------------- ------------------
          1 Budi Santoso     4111111111111111
          2 Siti Aminah      5555555555554444

2 rows selected.
```

Dua baris terbaca. Pada mode ini, keberhasilan query tidak berarti user sudah memperoleh otorisasi realm; pelanggarannya dicatat untuk evaluasi.

## 21.5 Connect sebagai C##DV_OWNER_LAB di PDB1

```sql
CONNECT c##dv_owner_lab/"DVOwner#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `C##DV_OWNER_LAB` di PDB1.

## 21.6 Lihat violation pada simulation log

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN username FORMAT A18
COLUMN command FORMAT A12
COLUMN object_owner FORMAT A18
COLUMN object_name FORMAT A22

SELECT username, command, object_owner, object_name, returncode
FROM dba_dv_simulation_log
WHERE object_owner = 'DV_APP_USER'
  AND object_name = 'CUSTOMER_SENSITIVE'
  AND username = 'DV_DBA_USER'
ORDER BY id;
```

**Expected output:**

```text
USERNAME           COMMAND      OBJECT_OWNER       OBJECT_NAME            RETURNCODE
------------------ ------------ ------------------ ---------------------- ----------
DV_DBA_USER        SELECT       DV_APP_USER        CUSTOMER_SENSITIVE           1031
```

Contoh satu entri ditampilkan. Jumlah entri bertambah jika pengujian diulang. RETURNCODE 1031 menunjukkan pelanggaran akses yang akan ditolak ketika enforcement aktif.

## 21.7 Kembalikan enforcement

Ketik seluruh blok, termasuk `/` pada baris terakhir, untuk menjalankan satu langkah ini.

```sql
BEGIN
    DVSYS.DBMS_MACADM.UPDATE_REALM(
        realm_name  => 'CUSTOMER_DATA_REALM',
        description => 'Day5 customer data',
        enabled     => DVSYS.DBMS_MACUTL.G_YES
    );
END;
/
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

## 21.8 Connect sebagai DV_DBA_USER di PDB1

```sql
CONNECT dv_dba_user/"DVDba#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `DV_DBA_USER` di PDB1.

## 21.9 Buktikan query kembali ditolak

```sql
SELECT credit_card
FROM dv_app_user.customer_sensitive;
```

**Expected output:**

```text
ERROR at line 2:
ORA-01031: insufficient privileges
```

Enforcement sudah kembali aktif. Jangan meninggalkan realm pada simulation setelah pembandingan selesai.

---

# PART 4 — PRIVILEGE ANALYSIS PREPARATION

# LAB 22 — SIAPKAN USER KHUSUS PRIVILEGE ANALYSIS

Seluruh preparation Privilege Analysis baru dilakukan setelah rangkaian
Database Vault selesai. Dengan demikian peserta tidak perlu mengingat user PA
selama mengerjakan Realm, Rule Set, Command Rule, Secure Application Role,
dan Simulation Mode.

## 22.1 Login sebagai account manager

```sql
CONNECT c##dv_acctmgr_lab/"DVAcctMgr#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Vault sudah aktif. Pembuatan akun dilakukan oleh DV_ACCTMGR, bukan oleh DV_DBA_USER yang dipakai pada akhir Lab 21.

## 22.2 Buat PA_ADMIN

```sql
CREATE USER pa_admin
IDENTIFIED BY "PAAdmin#2026";
```

**Expected output:**

```text
User created.
```

Administrator privilege capture.

## 22.3 Buat PA_TEST_USER

```sql
CREATE USER pa_test_user
IDENTIFIED BY "PATest#2026"
DEFAULT TABLESPACE users
QUOTA 10M ON users;
```

**Expected output:**

```text
User created.
```

User yang workload-nya akan direkam.

## 22.4 Kembali sebagai SYS

```sql
CONNECT / AS SYSDBA
```

**Expected output:**

```text
Connected.
```



## 22.5 Pindah ke PDB1

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

**Expected output:**

```text
Session altered.
```

SYS memberikan privilege pada akun PA yang sudah dibuat. Tabel PA tidak menjadi anggota customer realm.

## 22.6 Berikan hak login dan membuat tabel kepada PA_TEST_USER

```sql
GRANT CREATE SESSION, CREATE TABLE
TO pa_test_user;
```

**Expected output:**

```text
Grant succeeded.
```

Privilege `CREATE TABLE` sengaja diberikan sebelum capture. Penggunaan privilege
tersebut baru terjadi ketika workload Privilege Analysis dijalankan.

## 22.7 Berikan hak capture kepada PA_ADMIN

```sql
GRANT CREATE SESSION, CAPTURE_ADMIN TO pa_admin;
```

**Expected output:**

```text
Grant succeeded.
```

## 22.8 Tambahkan satu privilege untuk dibandingkan

```sql
GRANT CREATE VIEW TO pa_test_user;
```

**Expected output:**

```text
Grant succeeded.
```

Workload kita nanti hanya membuat tabel. Kita ingin melihat apakah CREATE VIEW akan tercatat sebagai privilege yang tidak digunakan.

---

**Checkpoint:** `PA_ADMIN` dan `PA_TEST_USER` sekarang siap.
Belum ada workload yang dijalankan. `PA_PROBE` akan dibuat setelah capture aktif,
karena operasi `CREATE TABLE` memang ingin direkam oleh Privilege Analysis.

---

# PART 5 — PRIVILEGE ANALYSIS

# LAB 23 — MEMBUAT PRIVILEGE CAPTURE

Privilege Analysis membantu menjawab: dari semua privilege yang sudah diberikan,
mana yang benar-benar dipakai pada suatu workload?

```text
Aktifkan capture → jalankan workload → hentikan capture → generate report
```

## 23.1 Connect sebagai PA_ADMIN di PDB1

```sql
CONNECT pa_admin/"PAAdmin#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `PA_ADMIN` di PDB1.

## 23.2 Buat policy capture

Ketik seluruh blok, termasuk `/` pada baris terakhir, untuk menjalankan satu langkah ini.

```sql
BEGIN
    DBMS_PRIVILEGE_CAPTURE.CREATE_CAPTURE(
        name        => 'DAY5_PA',
        description => 'Day 5 user workload',
        type        => DBMS_PRIVILEGE_CAPTURE.G_CONTEXT,
        condition   =>
          'SYS_CONTEXT(''USERENV'',''SESSION_USER'') = ''PA_TEST_USER'''
    );
END;
/
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

Condition menargetkan session PA_TEST_USER. Pembuatan policy belum mulai merekam workload.

## 23.3 Mulai capture

```sql
EXEC DBMS_PRIVILEGE_CAPTURE.ENABLE_CAPTURE('DAY5_PA');
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

Mulai sekarang jalankan workload dengan koneksi PA_TEST_USER yang baru.

---

# LAB 24 — WORKLOAD DAN HASIL PRIVILEGE ANALYSIS

Kita melakukan kegiatan kecil: membuat tabel, menambah satu baris, dan membaca hasilnya. Tidak ada CREATE VIEW pada workload ini.

## 24.1 Connect sebagai PA_TEST_USER di PDB1

```sql
CONNECT pa_test_user/"PATest#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `PA_TEST_USER` di PDB1.

## 24.2 Buat tabel workload

```sql
CREATE TABLE pa_probe (id NUMBER);
```

**Expected output:**

```text
Table created.
```

## 24.3 Tambahkan data workload

```sql
INSERT INTO pa_probe VALUES (1);
```

**Expected output:**

```text
1 row created.
```

## 24.4 Simpan data workload

```sql
COMMIT;
```

**Expected output:**

```text
Commit complete.
```

## 24.5 Baca hasil workload

```sql
SELECT * FROM pa_probe;
```

**Expected output:**

```text
        ID
----------
         1

1 row selected.
```

## 24.6 Connect sebagai PA_ADMIN di PDB1

```sql
CONNECT pa_admin/"PAAdmin#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `PA_ADMIN` di PDB1.

## 24.7 Hentikan capture

```sql
EXEC DBMS_PRIVILEGE_CAPTURE.DISABLE_CAPTURE('DAY5_PA');
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

## 24.8 Generate hasil capture

```sql
EXEC DBMS_PRIVILEGE_CAPTURE.GENERATE_RESULT('DAY5_PA');
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

Generate dilakukan setelah capture berhenti, agar report dapat dibaca.

## 24.9 Lihat privilege yang benar-benar digunakan

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN username FORMAT A18
COLUMN sys_priv FORMAT A30

SELECT DISTINCT username, sys_priv
FROM dba_used_sysprivs
WHERE capture = 'DAY5_PA'
  AND username = 'PA_TEST_USER'
ORDER BY sys_priv;
```

**Expected output:**

```text
USERNAME           SYS_PRIV
------------------ ------------------------------
PA_TEST_USER       CREATE SESSION
PA_TEST_USER       CREATE TABLE

2 rows selected.
```

CREATE SESSION dipakai untuk login. CREATE TABLE dipakai ketika user membuat tabel workload.

## 24.10 Lihat privilege yang belum digunakan

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN username FORMAT A18
COLUMN sys_priv FORMAT A30

SELECT DISTINCT username, sys_priv
FROM dba_unused_privs
WHERE capture = 'DAY5_PA'
  AND username = 'PA_TEST_USER'
  AND sys_priv IS NOT NULL
ORDER BY sys_priv;
```

**Expected output:**

```text
USERNAME           SYS_PRIV
------------------ ------------------------------
PA_TEST_USER       CREATE VIEW

1 row selected.
```

User tidak membuat view selama capture. CREATE VIEW menjadi kandidat untuk ditinjau. Hasil ini hanya menggambarkan workload yang direkam; evaluasi pekerjaan aplikasi lain sebelum mencabut privilege.

**Checkpoint:** user diberi CREATE SESSION, CREATE TABLE, dan CREATE VIEW. Report membedakan dua privilege yang dipakai dan satu privilege yang belum dipakai. Filter USERNAME menjaga report tetap fokus pada user latihan.

---

# PART 6 — INTEGRASI PRIVILEGE ANALYSIS + DATABASE VAULT

# LAB 25 — PRIVILEGE ANALYSIS SAAT VAULT SUDAH AKTIF

Lab 23–24 sudah berjalan saat Vault aktif. Sekarang kita ulangi workload dalam run bernama POST_DV supaya hasil run kedua bisa dilihat secara terpisah. Akun PA dibuat setelah Vault aktif, melalui account manager.

## 25.1 Connect sebagai PA_ADMIN di PDB1

```sql
CONNECT pa_admin/"PAAdmin#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `PA_ADMIN` di PDB1.

## 25.2 Mulai capture run POST_DV

Ketik seluruh blok, termasuk `/` pada baris terakhir, untuk menjalankan satu langkah ini.

```sql
BEGIN
    DBMS_PRIVILEGE_CAPTURE.ENABLE_CAPTURE(
        name     => 'DAY5_PA',
        run_name => 'POST_DV'
    );
END;
/
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

## 25.3 Connect sebagai PA_TEST_USER di PDB1

```sql
CONNECT pa_test_user/"PATest#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `PA_TEST_USER` di PDB1.

## 25.4 Buat tabel workload kedua

```sql
CREATE TABLE pa_probe_after_dv (id NUMBER);
```

**Expected output:**

```text
Table created.
```

## 25.5 Masukkan data workload kedua

```sql
INSERT INTO pa_probe_after_dv VALUES (2);
```

**Expected output:**

```text
1 row created.
```

## 25.6 Simpan transaksi

```sql
COMMIT;
```

**Expected output:**

```text
Commit complete.
```

## 25.7 Periksa data workload kedua

```sql
SELECT * FROM pa_probe_after_dv;
```

**Expected output:**

```text
        ID
----------
         2

1 row selected.
```

## 25.8 Connect sebagai PA_ADMIN di PDB1

```sql
CONNECT pa_admin/"PAAdmin#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `PA_ADMIN` di PDB1.

## 25.9 Hentikan capture POST_DV

```sql
EXEC DBMS_PRIVILEGE_CAPTURE.DISABLE_CAPTURE('DAY5_PA');
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

## 25.10 Generate hasil run POST_DV

Ketik seluruh blok, termasuk `/` pada baris terakhir, untuk menjalankan satu langkah ini.

```sql
BEGIN
    DBMS_PRIVILEGE_CAPTURE.GENERATE_RESULT(
        name     => 'DAY5_PA',
        run_name => 'POST_DV'
    );
END;
/
```

**Expected output:**

```text
PL/SQL procedure successfully completed.
```

## 25.11 Lihat privilege yang benar-benar digunakan

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN username FORMAT A18
COLUMN sys_priv FORMAT A30

SELECT DISTINCT username, sys_priv
FROM dba_used_sysprivs
WHERE capture = 'DAY5_PA'
  AND username = 'PA_TEST_USER'
  AND run_name = 'POST_DV'
ORDER BY sys_priv;
```

**Expected output:**

```text
USERNAME           SYS_PRIV
------------------ ------------------------------
PA_TEST_USER       CREATE SESSION
PA_TEST_USER       CREATE TABLE

2 rows selected.
```

CREATE SESSION dipakai untuk login. CREATE TABLE dipakai ketika user membuat tabel workload.

## 25.12 Lihat privilege yang belum digunakan

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN username FORMAT A18
COLUMN sys_priv FORMAT A30

SELECT DISTINCT username, sys_priv
FROM dba_unused_privs
WHERE capture = 'DAY5_PA'
  AND username = 'PA_TEST_USER'
  AND run_name = 'POST_DV'
  AND sys_priv IS NOT NULL
ORDER BY sys_priv;
```

**Expected output:**

```text
USERNAME           SYS_PRIV
------------------ ------------------------------
PA_TEST_USER       CREATE VIEW

1 row selected.
```

User tidak membuat view selama capture. CREATE VIEW menjadi kandidat untuk ditinjau. Hasil ini hanya menggambarkan workload yang direkam; evaluasi pekerjaan aplikasi lain sebelum mencabut privilege.

**Checkpoint:** dua run Privilege Analysis berhasil saat Vault aktif. CREATE VIEW tetap tidak dipakai pada workload kedua. Ini membuktikan keduanya dapat berjalan bersama, bukan perbandingan sebelum dan sesudah enable Vault.

---

# PART 7 — TDE: DATA TIDAK TERBACA DAN PEMULIHAN AKSES

# LAB 26 — MEMBUKTIKAN PERAN WALLET TDE

Sekarang kita membedakan penolakan akses oleh Vault dengan kegagalan dekripsi.
Gunakan tabel latihan terpisah, TDE_RECOVERY_PROBE, milik DV_APP_USER di USERS.
Tabel ini tidak dimasukkan ke customer realm. Hanya CREDIT_CARD yang dienkripsi;
CUSTOMER_NAME tetap plaintext. Kita memakai existing wallet dan existing master key.

Penutupan wallet sementara memengaruhi akses data terenkripsi di PDB1, termasuk
objek TDE lain yang sudah ada. Selesaikan sampai langkah membuka wallet kembali
sebelum berpindah ke lab lain. Tidak perlu memindahkan file wallet atau merotasi key.

## 26.1 Kembali sebagai SYS

```sql
CONNECT / AS SYSDBA
```

**Expected output:**

```text
Connected.
```



## 26.2 Pindah ke PDB1

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

**Expected output:**

```text
Session altered.
```



## 26.3 Periksa existing wallet

```sql
COLUMN status FORMAT A24
COLUMN wallet_type FORMAT A12

SELECT con_id, status, wallet_type
FROM v$encryption_wallet
ORDER BY con_id;
```

**Expected output:**

```text
    CON_ID STATUS                   WALLET_TYPE
---------- ------------------------ ------------
         3 OPEN                     PASSWORD

1 row selected.
```

Lanjutkan saat status OPEN dan tipe PASSWORD seperti hasil VM. Jika CLOSED setelah restart atau reopen, ikuti langkah pemulihan wallet di Lab 9 atau Lab 11 terlebih dahulu. OPEN_NO_MASTER_KEY berarti master key belum tersedia; kondisi itu berbeda dari baseline latihan ini.

## 26.4 Pastikan tablespace penopang tidak terenkripsi

```sql
COLUMN tablespace_name FORMAT A20

SELECT tablespace_name, encrypted
FROM dba_tablespaces
WHERE tablespace_name IN ('SYSTEM', 'SYSAUX', 'USERS')
ORDER BY tablespace_name;
```

**Expected output:**

```text
TABLESPACE_NAME      ENC
-------------------- ---
SYSAUX               NO
SYSTEM               NO
USERS                NO

3 rows selected.
```

USERS yang tidak terenkripsi membuat kita bisa membandingkan kolom plaintext dan kolom terenkripsi dalam tabel yang sama. Jangan mengganti target tabel ke TS_SECURE yang sudah terenkripsi.

## 26.5 Login sebagai pemilik tabel

```sql
CONNECT dv_app_user/"DVApp#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```



## 26.6 Buat tabel dengan satu kolom terenkripsi

```sql
CREATE TABLE tde_recovery_probe (
    customer_id   NUMBER,
    customer_name VARCHAR2(30),
    credit_card   VARCHAR2(30) ENCRYPT USING 'AES256'
) TABLESPACE users;
```

**Expected output:**

```text
Table created.
```

Oracle memakai master key yang sudah tersedia di wallet PDB1.

## 26.7 Masukkan satu customer contoh

```sql
INSERT INTO tde_recovery_probe
VALUES (1, 'Budi Santoso', '4111111111111111');
```

**Expected output:**

```text
1 row created.
```



## 26.8 Simpan data

```sql
COMMIT;
```

**Expected output:**

```text
Commit complete.
```



## 26.9 Buktikan kolom benar-benar terenkripsi

```sql
COLUMN table_name FORMAT A22
COLUMN column_name FORMAT A18
COLUMN encryption_alg FORMAT A32

SELECT table_name, column_name, encryption_alg
FROM user_encrypted_columns
WHERE table_name = 'TDE_RECOVERY_PROBE';
```

**Expected output:**

```text
TABLE_NAME             COLUMN_NAME        ENCRYPTION_ALG
---------------------- ------------------ --------------------------------
TDE_RECOVERY_PROBE     CREDIT_CARD        AES 256 bits key

1 row selected.
```



## 26.10 Baca data saat wallet terbuka

```sql
COLUMN customer_id FORMAT 999999
COLUMN customer_name FORMAT A16
COLUMN credit_card FORMAT A18

SELECT customer_id, customer_name, credit_card
FROM tde_recovery_probe
ORDER BY customer_id;
```

**Expected output:**

```text
CUSTOMER_ID CUSTOMER_NAME    CREDIT_CARD
----------- ---------------- ------------------
          1 Budi Santoso     4111111111111111

1 row selected.
```

TDE mendekripsi data secara transparan bagi user yang punya hak akses. Hasil SELECT tetap plaintext.

## 26.11 Kembali sebagai SYS

```sql
CONNECT / AS SYSDBA
```

**Expected output:**

```text
Connected.
```



## 26.12 Pilih PDB1

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

**Expected output:**

```text
Session altered.
```



## 26.13 Tutup wallet PDB1 sementara

```sql
ADMINISTER KEY MANAGEMENT SET KEYSTORE CLOSE
IDENTIFIED BY "TDEWallet#2026" CONTAINER=CURRENT;
```

**Expected output:**

```text
keystore altered.
```

CONTAINER=CURRENT membatasi operasi pada PDB1. Wallet root tetap terbuka.

## 26.14 Pastikan wallet PDB1 tertutup

```sql
COLUMN status FORMAT A24
COLUMN wallet_type FORMAT A12

SELECT con_id, status, wallet_type
FROM v$encryption_wallet
ORDER BY con_id;
```

**Expected output:**

```text
    CON_ID STATUS                   WALLET_TYPE
---------- ------------------------ ------------
         3 CLOSED                   UNKNOWN

1 row selected.
```

UNKNOWN adalah nilai WALLET_TYPE yang terlihat saat wallet tertutup pada VM ini.

## 26.15 Login kembali sebagai user yang sama

```sql
CONNECT dv_app_user/"DVApp#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Hak user tidak diubah; yang berubah hanya status wallet.

## 26.16 Baca kolom plaintext

```sql
COLUMN customer_id FORMAT 999999
COLUMN customer_name FORMAT A16

SELECT customer_id, customer_name
FROM tde_recovery_probe
ORDER BY customer_id;
```

**Expected output:**

```text
CUSTOMER_ID CUSTOMER_NAME
----------- ----------------
          1 Budi Santoso

1 row selected.
```

Query ini tidak meminta kolom terenkripsi.

## 26.17 Coba baca kolom terenkripsi

```sql
SELECT credit_card
FROM tde_recovery_probe;
```

**Expected output:**

```text
ERROR at line 2:
ORA-28365: wallet is not open
```

**Ini kegagalan yang diharapkan.** User tetap pemilik tabel, tetapi Oracle membutuhkan wallet terbuka untuk dekripsi. GRANT SELECT tidak menyelesaikan masalah ini.

## 26.18 Login sebagai SYS untuk memulihkan akses

```sql
CONNECT / AS SYSDBA
```

**Expected output:**

```text
Connected.
```



## 26.19 Pilih kembali PDB1

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

**Expected output:**

```text
Session altered.
```



## 26.20 Buka existing wallet dengan password yang benar

```sql
ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN
IDENTIFIED BY "TDEWallet#2026" CONTAINER=CURRENT;
```

**Expected output:**

```text
keystore altered.
```

Tidak ada perubahan data, wallet, atau master key yang diperlukan untuk pemulihan ini.

## 26.21 Pastikan wallet kembali OPEN

```sql
COLUMN status FORMAT A24
COLUMN wallet_type FORMAT A12

SELECT con_id, status, wallet_type
FROM v$encryption_wallet
ORDER BY con_id;
```

**Expected output:**

```text
    CON_ID STATUS                   WALLET_TYPE
---------- ------------------------ ------------
         3 OPEN                     PASSWORD

1 row selected.
```



## 26.22 Login lagi sebagai DV_APP_USER

```sql
CONNECT dv_app_user/"DVApp#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```



## 26.23 Ulangi pembacaan data

```sql
COLUMN customer_id FORMAT 999999
COLUMN customer_name FORMAT A16
COLUMN credit_card FORMAT A18

SELECT customer_id, customer_name, credit_card
FROM tde_recovery_probe
ORDER BY customer_id;
```

**Expected output:**

```text
CUSTOMER_ID CUSTOMER_NAME    CREDIT_CARD
----------- ---------------- ------------------
          1 Budi Santoso     4111111111111111

1 row selected.
```

Data yang sama kembali terbaca. Penolakan realm ditangani melalui otorisasi yang tepat; ORA-28365 pada latihan ini ditangani dengan membuka wallet. TDE tidak menggantikan kontrol akses Vault.

**Checkpoint:** wallet PDB1 kembali OPEN. Kita tidak meninggalkan peserta berikutnya dengan akses TDE yang terputus.

---

# PART 8 — FINAL VERIFICATION

# LAB 27 — VERIFIKASI AKHIR DAN REFLEKSI

Pastikan konfigurasi Database Vault kembali pada kondisi enforcement yang diharapkan dan Privilege Capture sudah berhenti.

## 27.1 Kembali sebagai SYS di CDB root

```sql
CONNECT / AS SYSDBA
```

**Expected output:**

```text
Connected.
```

Koneksi lokal ini memakai autentikasi OS user `oracle`. Container awalnya adalah `CDB$ROOT`.

## 27.2 Periksa Vault root dan PDB1

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN name FORMAT A30
COLUMN status FORMAT A24

SELECT con_id, name, status
FROM cdb_dv_status
WHERE con_id IN (1, 3)
  AND name IN ('DV_CONFIGURE_STATUS', 'DV_ENABLE_STATUS')
ORDER BY con_id, name;
```

**Expected output:**

```text
    CON_ID NAME                           STATUS
---------- ------------------------------ ------------------------
         1 DV_CONFIGURE_STATUS            TRUE
         1 DV_ENABLE_STATUS               TRUE
         3 DV_CONFIGURE_STATUS            TRUE
         3 DV_ENABLE_STATUS               TRUE

4 rows selected.
```

## 27.3 Periksa PDB1 tetap terbuka

```sql
SHOW PDBS
```

**Expected output:**

```text
    CON_ID CON_NAME                       OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
         2 PDB$SEED                       READ ONLY  NO
         3 PDB1                           READ WRITE NO
```

## 27.4 Connect sebagai C##DV_OWNER_LAB di PDB1

```sql
CONNECT c##dv_owner_lab/"DVOwner#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `C##DV_OWNER_LAB` di PDB1.

## 27.5 Pastikan customer realm aktif

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN name FORMAT A30

SELECT name, enabled
FROM dba_dv_realm
WHERE name = 'CUSTOMER_DATA_REALM';
```

**Expected output:**

```text
NAME                           E
------------------------------ -
CUSTOMER_DATA_REALM            Y

1 row selected.
```

## 27.6 Pastikan command rule aktif

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN command FORMAT A12
COLUMN object_owner FORMAT A20
COLUMN object_name FORMAT A24

SELECT command, object_owner, object_name, enabled
FROM dba_dv_command_rule
WHERE object_owner = 'DV_DBA_USER'
  AND object_name = 'DROP_PROBE';
```

**Expected output:**

```text
COMMAND      OBJECT_OWNER         OBJECT_NAME              E
------------ -------------------- ------------------------ -
DROP TABLE   DV_DBA_USER          DROP_PROBE               Y

1 row selected.
```

## 27.7 Connect sebagai PA_ADMIN di PDB1

```sql
CONNECT pa_admin/"PAAdmin#2026"@localhost:1521/pdb1.localdomain
```

**Expected output:**

```text
Connected.
```

Perintah berikutnya dijalankan dengan hak `PA_ADMIN` di PDB1.

## 27.8 Pastikan capture sudah berhenti

Jalankan di SQL*Plus. Baris `COLUMN` hanya mengatur tampilan dan tidak mencetak output.

```sql
COLUMN name FORMAT A30

COLUMN run_name FORMAT A18

SELECT name, NVL(run_name, '(tanpa nama)') AS run_name, enabled
FROM dba_priv_captures
WHERE name = 'DAY5_PA'
ORDER BY run_name;
```

**Expected output:**

```text
NAME                           RUN_NAME           E
------------------------------ ------------------ -
DAY5_PA                        (tanpa nama)       N
DAY5_PA                        POST_DV            N

2 rows selected.
```

Dua run sama-sama N: capture sudah berhenti. Run pertama dibuat tanpa RUN_NAME, sehingga kita tampilkan sebagai (tanpa nama).

## 27.9 Kembali ke CDB root

```sql
CONNECT / AS SYSDBA
```

**Expected output:**

```text
Connected.
```



## 27.10 Pastikan wallet kembali OPEN

```sql
COLUMN status FORMAT A24
COLUMN wallet_type FORMAT A12

SELECT con_id, status, wallet_type
FROM v$encryption_wallet
ORDER BY con_id;
```

**Expected output:**

```text
    CON_ID STATUS                   WALLET_TYPE
---------- ------------------------ ------------
         1 OPEN                     PASSWORD
         2 OPEN                     PASSWORD
         3 OPEN                     PASSWORD

3 rows selected.
```

Root, seed, dan PDB1 kembali OPEN seperti baseline wallet sebelum pengujian. Realm dan command rule aktif; dua capture run sudah berhenti.

## 27.11 Keluar dari SQL*Plus

```sql
EXIT
```

**Expected output:**

```text
Disconnected from Oracle Database 19c Enterprise Edition ...
```

Footer disconnect disingkat. Objek latihan dibiarkan tersedia untuk diperiksa kembali.

### Pertanyaan untuk memastikan pemahaman

1. Mengapa SELECT ANY TABLE berhasil sebelum realm, lalu ditolak sesudahnya?
2. Mengapa pemilik tabel tetap dapat membaca pada regular realm yang kita buat?
3. Bagaimana uji DROP saat rule aktif dan nonaktif membantu membuktikan penyebab penolakan?
4. Apa bukti secure role aktif pada satu session dan ditolak pada session lain?
5. Mengapa CREATE VIEW muncul sebagai privilege yang tidak digunakan?
6. Mengapa CUSTOMER_NAME tetap terbaca saat wallet tertutup, tetapi CREDIT_CARD gagal?

### Arah jawaban

Realm membatasi pemakaian privilege luas terhadap objek terlindungi. Regular realm
pada latihan ini tetap mengizinkan pemilik objek membaca tabelnya. Command rule
dibuktikan dengan operasi yang sama: ditolak ketika rule aktif dan berhasil ketika
nonaktif. Aktivasi secure role terlihat di SESSION_ROLES, dengan uji negatif pada
user yang tidak memenuhi rule. CREATE VIEW tidak dipakai pada workload capture.
Kolom plaintext tidak memerlukan dekripsi, sedangkan CREDIT_CARD memerlukan wallet terbuka.

### Catatan untuk praktik berikutnya

Wallet PASSWORD tidak auto-login. Setelah restart instance, ikuti langkah 9.7–9.9;
setelah reopen PDB, ikuti langkah 11.7–11.9. Periksa status sebelum menjalankan OPEN
agar tidak mengulang operasi pada wallet yang sudah terbuka.

Objek lab dibiarkan untuk diperiksa kembali. Untuk mengulang seluruh rangkaian dari
Lab 1, gunakan baseline VM sebelum pengujian dengan existing wallet yang sama.
Jangan menjalankan CREATE USER, CREATE TABLE, CREATE_CAPTURE, atau CONFIGURE_DV
berulang pada konfigurasi akhir ini karena objek dan konfigurasi sudah ada.

### Referensi fasilitator

Contoh output utama berasal dari pengujian VM. Penjelasan konsep juga dicocokkan dengan
[Oracle Database Vault 19c](https://docs.oracle.com/en/database/oracle/oracle-database/19/dvadm/introduction-to-oracle-database-vault.html)
dan [pengelolaan wallet TDE dalam united mode](https://docs.oracle.com/en/database/oracle/oracle-database/19/asoag/managing-keystores-encryption-keys-in-united-mode.html).
