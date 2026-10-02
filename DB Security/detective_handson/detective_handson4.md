# HANDS-ON LAB — ORACLE SQL FIREWALL 26ai

## SQL Capture, Allow-List, Detect-Only Enforcement, Blocking, Tuning & Investigation



## SQL*Plus Presentation Settings

Jalankan **sekali saja** setelah membuka SQL*Plus sebagai `SYS`. Setting ini membuat hasil query lebih nyaman dibaca sepanjang sesi; tidak perlu menambahkan `SET LINES` atau `SET PAGES` sebelum setiap query.

```sql
SET LINESIZE 320
SET PAGESIZE 200
SET LONG 5000
SET LONGCHUNKSIZE 5000
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF
SET FEEDBACK ON
SET SERVEROUTPUT ON SIZE UNLIMITED
```

# 1. Fokus Lab

Lab ini mengikuti lifecycle teori:

```text
ENABLE SQL FIREWALL
        ↓
CREATE CAPTURE
        ↓
RUN TRUSTED WORKLOAD
        ↓
STOP CAPTURE
        ↓
GENERATE ALLOW-LIST
        ↓
ENABLE DETECT-ONLY
        ↓
MONITOR VIOLATIONS
        ↓
TUNE ALLOW-LIST
        ↓
ENABLE BLOCKING
        ↓
INVESTIGATE
        ↓
OPERATE / MAINTAIN
```

SQL Firewall yang digunakan di sini adalah **native SQL Firewall di dalam database kernel**.

Lab ini **tidak membutuhkan**:

```text
Audit Vault Server
Database Firewall appliance
Host Monitor
Audit Vault Agent
SPAN / TAP
```

---

# 2. Important Lab Convention

Gunakan minimal dua terminal.

```text
Terminal A
==========
SYS / SQL Firewall administrator

Terminal B
==========
UA_D3_READER
Protected database user
```

Versi ini tidak menyertakan output hasil eksekusi. Peserta menjalankan perintah satu per satu dan memverifikasi hasil langsung pada environment masing-masing. Nilai seperti `timestamp`, `SQL_SIGNATURE`, `SESSION_ID`, `CLIENT_PROGRAM`, `IP_ADDRESS`, dan jumlah audit record dapat berbeda antar-environment.

---

# 4. Learning Objectives

Setelah menyelesaikan lab ini peserta mampu:

1. Memvalidasi Oracle AI Database 26ai untuk SQL Firewall.
2. Menjelaskan bahwa SQL Firewall bekerja per database user.
3. Mengaktifkan SQL Firewall di PDB.
4. Membuat protected application account.
5. Membuat SQL Firewall capture.
6. Menjalankan trusted workload.
7. Melihat capture logs.
8. Melihat SQL signature.
9. Memahami literal normalization.
10. Melihat session context.
11. Menghentikan capture.
12. Menghasilkan allow-list.
13. Melihat allowed SQL.
14. Melihat allowed IP, OS user, dan OS program.
15. Mengaktifkan detect-only enforcement.
16. Menghasilkan SQL violation tanpa blocking.
17. Menyelidiki `DBA_SQL_FIREWALL_VIOLATIONS`.
18. Mengintegrasikan violation dengan Unified Auditing.
19. Mengorelasikan SQL Firewall evidence dengan `UNIFIED_AUDIT_TRAIL`.
20. Menggunakan `APPEND_ALLOW_LIST_SINGLE_SQL`.
21. Memahami allow-list versioning.
22. Mengaktifkan blocking.
23. Mendemonstrasikan `ORA-47605`.
24. Menguji context-based enforcement.
25. Menggunakan export/import allow-list.
26. Mengelola log SQL Firewall.
27. Membuat daily operational checks.
28. Melakukan basic incident investigation.
29. Melakukan troubleshooting SQL Firewall.
30. Melakukan cleanup lab.

---

# PART A — VALIDATE ENVIRONMENT

---

# Lab 1 — Login sebagai Oracle OS User

## Tujuan

Menjamin environment variable Oracle sesuai dengan database training.

## Command

```bash
sudo su - oracle
```

Set environment:

```bash
export ORACLE_BASE=/opt/oracle
export ORACLE_HOME=/opt/oracle/product/26ai/dbhome_1
export ORACLE_SID=ORCLCDB
export PATH=$ORACLE_HOME/bin:$PATH
```

Verifikasi:

```bash
echo $ORACLE_BASE
echo $ORACLE_HOME
echo $ORACLE_SID
which sqlplus
```

## Penjelasan

Environment variable memastikan tool seperti `sqlplus`, `lsnrctl`, dan executable Oracle mengarah ke Oracle Home 26ai yang benar.

---

# Lab 2 — Verify Listener

## Command

```bash
lsnrctl status
```

## Penjelasan

SQL Firewall bekerja di kernel database, tetapi workload training kita dikirim melalui Oracle Net. Karena itu listener harus sehat.

---

# Lab 3 — Test PDB Network Connection

## Command

```bash
sqlplus -L system/oracle@//192.168.56.26:1521/PDB1
```

Keluar:

```sql
EXIT
```

## Penjelasan

Koneksi ini memastikan service `PDB1` dapat dicapai menggunakan alamat yang juga akan dipakai user protected.

---

# Lab 4 — Verify Database Version

## Command

```bash
sqlplus / as sysdba
```

Kemudian:

```sql
SELECT banner_full
FROM   v$version;
```

## Penjelasan

Lab ini menggunakan API SQL Firewall Oracle AI Database 26ai. Release patch dapat sedikit berbeda, tetapi target environment Anda adalah `23.26.1.0.0`.

---

# Lab 5 — Verify CDB dan PDB

## Command

```sql
SHOW CON_NAME
SHOW PDBS
```

## Penjelasan

Semua konfigurasi SQL Firewall lab dilakukan di `PDB1`, bukan di root.

---

# Lab 6 — Switch ke PDB1

## Command

```sql
ALTER SESSION SET CONTAINER=PDB1;

SHOW CON_NAME
```

## Penjelasan

SQL Firewall dapat dikonfigurasi pada root maupun individual PDB. Lab ini sengaja menggunakan PDB agar scope sederhana dan aman.

---

# Lab 7 — Verify Sample Schema HR

## Command

```sql
SELECT COUNT(*) AS hr_employee_rows
FROM   hr.employees;
```

## Penjelasan

Ini hanya sanity check bahwa sample schema environment Anda sesuai informasi awal. SQL Firewall utama nanti memakai schema khusus lab agar tidak mengganggu HR.

---

# Lab 8 — Verify SQL Firewall Package

## Command

```sql
COLUMN owner FORMAT A10
COLUMN object_name FORMAT A25
COLUMN object_type FORMAT A15
COLUMN status FORMAT A10

SELECT owner,
       object_name,
       object_type,
       status
FROM   dba_objects
WHERE  owner='SYS'
AND    object_name='DBMS_SQL_FIREWALL';
```

## Penjelasan

`DBMS_SQL_FIREWALL` adalah package utama untuk mengelola capture, allow-list, enforcement, log, export/import, dan maintenance.

---

# Lab 9 — Verify SQL Firewall Dictionary Views

## Command

```sql
COLUMN view_name FORMAT A40

SELECT view_name
FROM   dba_views
WHERE  view_name LIKE 'DBA_SQL_FIREWALL%'
ORDER  BY view_name;
```

## Penjelasan

View `DBA_SQL_FIREWALL_*` merupakan evidence dan operational visibility utama untuk SQL Firewall.

---

# Lab 10 — Check Initial SQL Firewall Status

## Command

```sql
COLUMN status FORMAT A12
COLUMN exclude_jobs FORMAT A12
COLUMN status_updated_on FORMAT A35

SELECT status,
       status_updated_on,
       exclude_jobs
FROM   dba_sql_firewall_status;
```

## Penjelasan

`DBA_SQL_FIREWALL_STATUS` menunjukkan status global SQL Firewall pada container aktif.

---

# PART B — BUILD A STANDALONE PROTECTED APPLICATION

---

# Lab 11 — Create Application Owner

Masih sebagai SYS di `PDB1`.

## Command

```sql
CREATE USER ua_d3_app
IDENTIFIED BY "Oracle#D3App26"
DEFAULT TABLESPACE users
QUOTA 20M ON users;
```

Berikan privilege:

```sql
GRANT CREATE SESSION,
      CREATE TABLE
TO ua_d3_app;
```

## Penjelasan

`UA_D3_APP` adalah owner object aplikasi. Kita pisahkan owner dari user pembaca agar model security lebih realistis.

---

# Lab 12 — Create Protected Reader User

## Command

```sql
CREATE USER ua_d3_reader
IDENTIFIED BY "Oracle#D3Read26";
```

Grant:

```sql
GRANT CREATE SESSION TO ua_d3_reader;
```

## Penjelasan

`UA_D3_READER` adalah user yang nantinya dilindungi oleh SQL Firewall.

---

# Lab 13 — Create Sensitive Application Table

Buka **Terminal B sementara sebagai application owner**:

```bash
sqlplus -L 'ua_d3_app/Oracle#D3App26@//192.168.56.26:1521/PDB1'
```

Create table:

```sql
CREATE TABLE customer_secure
(
    customer_id     NUMBER PRIMARY KEY,
    customer_name   VARCHAR2(100),
    city            VARCHAR2(50),
    credit_limit    NUMBER,
    account_status  VARCHAR2(20)
);
```

## Penjelasan

Table ini menjadi object aplikasi yang dipakai untuk membuat trusted workload dan SQL anomaly.

---

# Lab 14 — Insert Deterministic Test Data

## Command

```sql
INSERT INTO customer_secure
VALUES (1,'Budi Santoso','Jakarta',50000000,'ACTIVE');

INSERT INTO customer_secure
VALUES (2,'Siti Aminah','Bandung',35000000,'ACTIVE');

INSERT INTO customer_secure
VALUES (3,'Andi Wijaya','Surabaya',75000000,'ACTIVE');

INSERT INTO customer_secure
VALUES (4,'Rina Putri','Depok',25000000,'ACTIVE');

INSERT INTO customer_secure
VALUES (5,'Dewi Lestari','Bogor',60000000,'SUSPENDED');

COMMIT;
```

## Penjelasan

Data dibuat kecil dan deterministic agar hasil query mudah diverifikasi.

---

# Lab 15 — Grant Reader Access

Masih sebagai `UA_D3_APP`:

```sql
GRANT SELECT ON customer_secure
TO ua_d3_reader;
```

Keluar:

```sql
EXIT
```

## Penjelasan

Reader hanya diberi akses read. SQL Firewall bukan pengganti privilege model; Firewall bekerja setelah authorization normal Oracle tetap berlaku.

---

# Lab 16 — Verify Users

Kembali ke **Terminal A / SYS**.

```sql
COLUMN username FORMAT A20
COLUMN account_status FORMAT A20

SELECT username,
       account_status
FROM   dba_users
WHERE  username IN ('UA_D3_APP','UA_D3_READER')
ORDER  BY username;
```

## Penjelasan

Pastikan kedua user siap sebelum SQL Firewall diaktifkan.

---

# Lab 17 — Verify Object Privilege

## Command

```sql
COLUMN grantee FORMAT A20
COLUMN owner FORMAT A15
COLUMN table_name FORMAT A25
COLUMN privilege FORMAT A15

SELECT grantee,
       owner,
       table_name,
       privilege
FROM   dba_tab_privs
WHERE  grantee='UA_D3_READER'
ORDER  BY owner, table_name, privilege;
```

## Penjelasan

Jika query anomaly nantinya gagal karena privilege, itu bukan SQL Firewall test yang valid. Karena itu privilege dasar diverifikasi terlebih dahulu.

---

# PART C — ENABLE ORACLE SQL FIREWALL

---

# Lab 18 — Enable SQL Firewall

Masih SYS di PDB1.

## Command

```sql
EXEC DBMS_SQL_FIREWALL.ENABLE;
```

## Penjelasan

`ENABLE` mengaktifkan engine SQL Firewall untuk container ini.

---

# Lab 19 — Verify SQL Firewall Enabled

## Command

```sql
SELECT status,
       status_updated_on,
       exclude_jobs
FROM   dba_sql_firewall_status;
```

## Penjelasan

Jangan lanjut membuat capture sebelum status benar-benar `ENABLED`.

---

# PART D — CREATE CAPTURE / LEARNING PHASE

---

# Lab 20 — Create Capture for UA_D3_READER

## Command

```sql
BEGIN
    DBMS_SQL_FIREWALL.CREATE_CAPTURE(
        username       => 'UA_D3_READER',
        top_level_only => TRUE,
        start_capture  => TRUE
    );
END;
/
```

## Penjelasan

Parameter:

```text
username       = user yang dipelajari
top_level_only = TRUE
start_capture  = TRUE
```

`TRUE` pada `top_level_only` membuat lab fokus pada SQL yang langsung diketik user. SQL dari PL/SQL nested execution tidak dimasukkan.

---

# Lab 21 — Verify Capture Status

## Command

```sql
COLUMN username FORMAT A20
COLUMN top_level_only FORMAT A15
COLUMN status FORMAT A12
COLUMN last_started_on FORMAT A35
COLUMN last_stopped_on FORMAT A35

SELECT username,
       top_level_only,
       status,
       last_started_on,
       last_stopped_on
FROM   dba_sql_firewall_captures
WHERE  username='UA_D3_READER';
```

## Penjelasan

Capture harus `ENABLED` sebelum trusted workload dijalankan.

---

# Lab 22 — Confirm Capture Log Initially Empty / Minimal

## Command

```sql
SELECT COUNT(*) AS captured_sql
FROM   dba_sql_firewall_capture_logs
WHERE  username='UA_D3_READER';
```

## Penjelasan

Ini memberi titik awal yang jelas sebelum learning workload.

---

# PART E — RUN TRUSTED WORKLOAD

---

# Lab 23 — Login as Protected User

Di **Terminal B**:

```bash
sqlplus -L 'ua_d3_reader/Oracle#D3Read26@//192.168.56.26:1521/PDB1'
```

## Penjelasan

Gunakan koneksi TCP ini secara konsisten agar context baseline (IP, OS user, client program) representative.

---

# Lab 24 — Trusted Query 1: Count Rows

## Command

```sql
SELECT COUNT(*) AS customer_count
FROM   ua_d3_app.customer_secure;
```

## Penjelasan

Ini adalah salah satu SQL shape yang sengaja dimasukkan ke baseline.

---

# Lab 25 — Trusted Query 2: List Customers

## Command

```sql
COLUMN customer_name FORMAT A20
COLUMN city FORMAT A15
COLUMN account_status FORMAT A15

SELECT customer_id,
       customer_name,
       city,
       account_status
FROM   ua_d3_app.customer_secure
ORDER  BY customer_id;
```

## Penjelasan

Statement ini membentuk SQL signature tersendiri.

---

# Lab 26 — Trusted Query 3: Parameterized Shape

Jalankan tiga SQL berikut.

```sql
SELECT customer_name,
       credit_limit
FROM   ua_d3_app.customer_secure
WHERE  customer_id = 1;
```

```sql
SELECT customer_name,
       credit_limit
FROM   ua_d3_app.customer_secure
WHERE  customer_id = 2;
```

```sql
SELECT customer_name,
       credit_limit
FROM   ua_d3_app.customer_secure
WHERE  customer_id = 3;
```

## Penjelasan

Tujuan lab ini bukan datanya.

Tujuannya:

```text
customer_id = 1
customer_id = 2
customer_id = 3
        ↓
literal normalization
        ↓
SQL signature yang sama / equivalent structure
```

---

# Lab 27 — Trusted Query 4: Status Query

## Command

```sql
SELECT customer_id,
       customer_name
FROM   ua_d3_app.customer_secure
WHERE  account_status='ACTIVE'
ORDER  BY customer_id;
```

## Penjelasan

Ini menambah satu SQL shape normal lagi ke baseline.

---

# Lab 28 — Repeat Representative Workload

Jalankan ulang beberapa SQL agar workload lebih representative:

```sql
SELECT COUNT(*) AS customer_count
FROM   ua_d3_app.customer_secure;

SELECT customer_name,
       credit_limit
FROM   ua_d3_app.customer_secure
WHERE  customer_id = 4;

SELECT customer_name,
       credit_limit
FROM   ua_d3_app.customer_secure
WHERE  customer_id = 5;

SELECT customer_id,
       customer_name
FROM   ua_d3_app.customer_secure
WHERE  account_status='ACTIVE'
ORDER  BY customer_id;
```

## Penjelasan

Baseline sebaiknya berasal dari workload normal yang cukup representative, bukan satu query sekali jalan.

Keluar:

```sql
EXIT
```

---

# PART F — INSPECT CAPTURE EVIDENCE

---

# Lab 29 — Flush SQL Firewall Logs

Kembali ke **Terminal A / SYS**.

## Command

```sql
EXEC DBMS_SQL_FIREWALL.FLUSH_LOGS;
```

## Penjelasan

SQL Firewall biasanya melakukan flush secara background. `FLUSH_LOGS` dipakai di lab agar evidence segera terlihat.

---

# Lab 30 — Count Capture Logs

## Command

```sql
SELECT COUNT(*) AS capture_log_rows
FROM   dba_sql_firewall_capture_logs
WHERE  username='UA_D3_READER';
```

## Penjelasan

Jika hasil tetap `0`, jangan lanjut. Troubleshoot capture lebih dulu.

---

# Lab 31 — Inspect Capture Logs

## Command

```sql
COLUMN command_type FORMAT A15
COLUMN sql_signature FORMAT A64
COLUMN sql_text FORMAT A90
COLUMN accessed_objects FORMAT A45
COLUMN current_user FORMAT A18
COLUMN top_level FORMAT A10

SELECT command_type,
       sql_signature,
       current_user,
       top_level,
       sql_text,
       accessed_objects
FROM   dba_sql_firewall_capture_logs
WHERE  username='UA_D3_READER'
ORDER  BY session_id,
          sql_signature;
```

## Penjelasan

Field penting:

```text
COMMAND_TYPE
SQL_SIGNATURE
SQL_TEXT
ACCESSED_OBJECTS
CURRENT_USER
TOP_LEVEL
```

---

# Lab 32 — Inspect Captured Session Context

## Command

```sql
COLUMN username FORMAT A20
COLUMN login_time FORMAT A35
COLUMN ip_address FORMAT A20
COLUMN client_program FORMAT A50
COLUMN os_user FORMAT A20

SELECT username,
       login_time,
       ip_address,
       client_program,
       os_user
FROM   dba_sql_firewall_session_logs
WHERE  username='UA_D3_READER'
ORDER  BY login_time;
```

## Penjelasan

SQL Firewall mempelajari bukan hanya SQL, tetapi juga connection context:

```text
IP address
OS user
OS program/client program
```

---

# Lab 33 — Demonstrate SQL Signature Normalization

## Command

```sql
COLUMN sql_signature FORMAT A64
COLUMN samples FORMAT 999

SELECT sql_signature,
       COUNT(*) AS samples
FROM   dba_sql_firewall_capture_logs
WHERE  username='UA_D3_READER'
AND    UPPER(sql_text) LIKE '%CUSTOMER_NAME%'
AND    UPPER(sql_text) LIKE '%CREDIT_LIMIT%'
AND    UPPER(sql_text) LIKE '%CUSTOMER_ID%'
GROUP  BY sql_signature
ORDER  BY samples DESC;
```

## Penjelasan

Konsep:

```text
literal berbeda
     ↓
normalization
     ↓
SQL signature
```

Jika jumlah row/representasi berbeda antar-environment, lihat `SQL_TEXT` dan `SQL_SIGNATURE` secara langsung. Optimizer/parser representation dapat membuat detail hasil berbeda, tetapi prinsipnya tetap bahwa Firewall menggunakan normalized SQL representation.

---

# Lab 34 — See Full SQL Text Repository

## Command

```sql
COLUMN command_type FORMAT A15
COLUMN sql_signature FORMAT A64
COLUMN sql_text FORMAT A100

SELECT command_type,
       sql_signature,
       DBMS_LOB.SUBSTR(sql_text,100,1) AS sql_text
FROM   dba_sql_firewall_sql_logs
ORDER  BY sql_signature;
```

## Penjelasan

`DBA_SQL_FIREWALL_CAPTURE_LOGS.SQL_TEXT` memiliki panjang display terbatas. `DBA_SQL_FIREWALL_SQL_LOGS` menyimpan full SQL text dalam CLOB.

---

# PART G — STOP CAPTURE AND GENERATE ALLOW-LIST

---

# Lab 35 — Stop Capture

## Command

```sql
EXEC DBMS_SQL_FIREWALL.STOP_CAPTURE('UA_D3_READER');
```

## Penjelasan

Allow-list tidak boleh di-generate dari capture yang masih running.

---

# Lab 36 — Verify Capture Disabled

## Command

```sql
SELECT username,
       top_level_only,
       status,
       last_started_on,
       last_stopped_on
FROM   dba_sql_firewall_captures
WHERE  username='UA_D3_READER';
```

## Penjelasan

`DISABLED` di sini artinya learning phase sudah dihentikan/frozen.

---

# Lab 37 — Generate Allow-List

## Command

```sql
EXEC DBMS_SQL_FIREWALL.GENERATE_ALLOW_LIST('UA_D3_READER');
```

## Penjelasan

Oracle membangun policy runtime dari capture logs:

```text
captured SQL
+
captured context
        ↓
allow-list
```

---

# Lab 38 — Verify Generated Allow-List

## Command

```sql
COLUMN username FORMAT A20
COLUMN status FORMAT A12
COLUMN top_level_only FORMAT A15
COLUMN enforce FORMAT A18
COLUMN block FORMAT A10

SELECT username,
       status,
       top_level_only,
       enforce,
       block,
       generated_on
FROM   dba_sql_firewall_allow_lists
WHERE  username='UA_D3_READER';
```

## Penjelasan

Generate allow-list **belum sama** dengan enforcement aktif.

---

# Lab 39 — Inspect Allowed SQL

## Command

```sql
COLUMN allowed_sql_id FORMAT 999999
COLUMN version FORMAT 999
COLUMN sql_signature FORMAT A64
COLUMN sql_text FORMAT A90
COLUMN accessed_objects FORMAT A45

SELECT allowed_sql_id,
       version,
       sql_signature,
       sql_text,
       accessed_objects
FROM   dba_sql_firewall_allowed_sql
WHERE  username='UA_D3_READER'
ORDER  BY allowed_sql_id;
```

## Penjelasan

`VERSION` berguna saat allow-list berkembang kemudian.

---

# Lab 40 — Inspect Allowed IP

## Command

```sql
COLUMN ip_address FORMAT A30

SELECT username,
       ip_address
FROM   dba_sql_firewall_allowed_ip_addr
WHERE  username='UA_D3_READER';
```

## Penjelasan

Nilai berasal dari connection context saat learning.

---

# Lab 41 — Inspect Allowed OS User

## Command

```sql
COLUMN os_user FORMAT A30

SELECT username,
       os_user
FROM   dba_sql_firewall_allowed_os_user
WHERE  username='UA_D3_READER';
```

## Penjelasan

Jika koneksi dilakukan dari client OS lain, hasil dapat berbeda.

---

# Lab 42 — Inspect Allowed OS Program

## Command

```sql
COLUMN os_program FORMAT A80

SELECT username,
       os_program
FROM   dba_sql_firewall_allowed_os_prog
WHERE  username='UA_D3_READER';
```

## Penjelasan

Jangan hard-code nilai ini berdasarkan contoh. Gunakan nilai yang benar-benar dipelajari oleh environment.

---

# PART H — ENABLE UNIFIED AUDIT FOR SQL FIREWALL VIOLATIONS

---

# Lab 43 — Create SQL Firewall Unified Audit Policy

Oracle merekomendasikan auditing violation setelah training/allow-list cukup matang.

## Command

```sql
CREATE AUDIT POLICY ua_d3_sqlfw_violation
ACTIONS COMPONENT = SQL_FIREWALL ALL ON UA_D3_READER;
```

> **Koreksi 26ai:** component action `SQL_FIREWALL` tercatat untuk `ALL USERS`; klausa `ON ua_d3_reader` tidak membatasi policy ini ke satu user pada environment yang diuji. Karena itu pengamatan harus tetap difilter dengan `DBUSERNAME='UA_D3_READER'` saat investigasi.

## Penjelasan

Policy ini khusus untuk SQL Firewall violation user `UA_D3_READER`.

---

# Lab 44 — Enable Audit Policy

## Command

```sql
AUDIT POLICY ua_d3_sqlfw_violation;
```

## Penjelasan

Setelah aktif, violation SQL Firewall dapat dikorelasikan dengan `UNIFIED_AUDIT_TRAIL`.

---

# Lab 45 — Verify Unified Audit Policy

## Command

```sql
COLUMN policy_name FORMAT A30
COLUMN entity_name FORMAT A20
COLUMN entity_type FORMAT A15

SELECT policy_name,
       entity_name,
       entity_type,
       success,
       failure
FROM   audit_unified_enabled_policies
WHERE  policy_name='UA_D3_SQLFW_VIOLATION';
```

---

# PART I — DETECT-ONLY ENFORCEMENT

---

# Lab 46 — Enable Detect-Only for SQL

## Command

```sql
BEGIN
    DBMS_SQL_FIREWALL.ENABLE_ALLOW_LIST(
        username => 'UA_D3_READER',
        enforce  => DBMS_SQL_FIREWALL.ENFORCE_SQL,
        block    => FALSE
    );
END;
/
```

## Penjelasan

Konfigurasi:

```text
ENFORCE_SQL
block = FALSE
```

berarti:

```text
known SQL   → allowed
unknown SQL → violation logged
unknown SQL → tetap dieksekusi
```

Inilah **detect-only**.

---

# Lab 47 — Verify Detect-Only Mode

## Command

```sql
SELECT username,
       status,
       enforce,
       block
FROM   dba_sql_firewall_allow_lists
WHERE  username='UA_D3_READER';
```

## Penjelasan

Tiga indikator harus sesuai:

```text
STATUS  = ENABLED
ENFORCE = ENFORCE_SQL
BLOCK   = N
```

---

# Lab 48 — Test Known SQL

Terminal B:

```bash
sqlplus -L 'ua_d3_reader/Oracle#D3Read26@//192.168.56.26:1521/PDB1'
```

Jalankan SQL yang ada di baseline:

```sql
SELECT COUNT(*) AS customer_count
FROM   ua_d3_app.customer_secure;
```

## Penjelasan

SQL signature dikenal, sehingga tidak menjadi SQL violation.

---

# Lab 49 — Generate an Unknown SQL Shape

Masih sebagai `UA_D3_READER`.

Jalankan SQL yang **sengaja tidak dimasukkan** ke trusted workload:

```sql
SELECT city,
       credit_limit
FROM   ua_d3_app.customer_secure
WHERE  credit_limit > 30000000
ORDER  BY credit_limit DESC;
```

Query tetap berhasil karena `BLOCK = N`; setelah `FLUSH_LOGS`, ia tercatat sebagai `SQL violation / Allowed`.

## Penjelasan

Statement valid menurut privilege Oracle, tetapi SQL shape belum ada di allow-list.

Keluar:

```sql
EXIT
```

---

# Lab 50 — Flush Violation Logs

Terminal A / SYS:

```sql
EXEC DBMS_SQL_FIREWALL.FLUSH_LOGS;
```

---

# Lab 51 — Investigate Detect-Only Violation

## Command

```sql
COLUMN occurred_at FORMAT A35
COLUMN username FORMAT A18
COLUMN command_type FORMAT A15
COLUMN cause FORMAT A20
COLUMN firewall_action FORMAT A15
COLUMN ip_address FORMAT A20
COLUMN client_program FORMAT A45
COLUMN os_user FORMAT A15
COLUMN sql_text FORMAT A90

SELECT occurred_at,
       username,
       command_type,
       cause,
       firewall_action,
       ip_address,
       os_user,
       client_program,
       sql_text
FROM   dba_sql_firewall_violations
WHERE  username='UA_D3_READER'
ORDER  BY occurred_at DESC;
```

## Penjelasan

`FIREWALL_ACTION = Allowed` **tidak berarti bukan violation**.

Artinya:

```text
violation detected
+
detect-only allowed execution
```

---

# Lab 52 — See Violation Signature Needed for Tuning

## Command

```sql
COLUMN sql_signature FORMAT A64
COLUMN current_user FORMAT A20
COLUMN top_level FORMAT A10
COLUMN cause FORMAT A20
COLUMN firewall_action FORMAT A15
COLUMN sql_text FORMAT A90

SELECT sql_signature,
       current_user,
       top_level,
       cause,
       firewall_action,
       sql_text
FROM   dba_sql_firewall_violations
WHERE  username='UA_D3_READER'
AND    cause='SQL violation'
ORDER  BY occurred_at DESC
FETCH FIRST 5 ROWS ONLY;
```

## Penjelasan

Empat data berikut dibutuhkan oleh API selective tuning:

```text
USERNAME
SQL_SIGNATURE
CURRENT_USER
TOP_LEVEL
```

---

# PART J — CORRELATE WITH UNIFIED AUDIT

---

# Lab 53 — Query SQL Firewall Events in Unified Audit Trail

## Command

```sql
COLUMN event_time FORMAT A19
COLUMN audit_type FORMAT A15
COLUMN dbusername FORMAT A18
COLUMN action_name FORMAT A25
COLUMN fw_action_name FORMAT A30
COLUMN client_program_name FORMAT A40

SELECT TO_CHAR(event_timestamp,
               'YYYY-MM-DD HH24:MI:SS') AS event_time,
       audit_type,
       dbusername,
       action_name,
       fw_action_name,
       fw_return_code,
       return_code,
       client_program_name
FROM   unified_audit_trail
WHERE  UPPER(audit_type)='SQL FIREWALL'
AND    dbusername='UA_D3_READER'
ORDER  BY event_timestamp DESC;
```

## Penjelasan

Sekarang investigator mempunyai dua sumber:

```text
DBA_SQL_FIREWALL_VIOLATIONS
+
UNIFIED_AUDIT_TRAIL
```

---

# Lab 54 — Compare Firewall and Audit Timeline

## SQL Firewall Side

```sql
SELECT TO_CHAR(occurred_at,'YYYY-MM-DD HH24:MI:SS') AS event_time,
       username,
       cause,
       firewall_action,
       sql_text
FROM   dba_sql_firewall_violations
WHERE  username='UA_D3_READER'
ORDER  BY occurred_at DESC;
```

## Unified Audit Side

```sql
SELECT TO_CHAR(event_timestamp,'YYYY-MM-DD HH24:MI:SS') AS event_time,
       dbusername,
       audit_type,
       fw_action_name,
       fw_return_code
FROM   unified_audit_trail
WHERE  UPPER(audit_type)='SQL FIREWALL'
AND    dbusername='UA_D3_READER'
ORDER  BY event_timestamp DESC;
```

## Penjelasan

SQL Firewall view menjawab:

```text
Deviation apa?
SQL apa?
Allowed atau blocked?
Context apa?
```

Unified Audit menjawab:

```text
Siapa?
Kapan?
Audit action apa?
Return code apa?
```

---

# PART K — CONTROLLED ALLOW-LIST TUNING

---

# Lab 55 — Review the New SQL Before Approval

Sebelum memasukkan SQL violation ke allow-list, baca statement-nya.

## Command

```sql
SELECT occurred_at,
       sql_signature,
       current_user,
       top_level,
       sql_text,
       accessed_objects
FROM   dba_sql_firewall_violations
WHERE  username='UA_D3_READER'
AND    cause='SQL violation'
ORDER  BY occurred_at DESC
FETCH FIRST 1 ROW ONLY;
```

## Decision

Untuk lab ini kita menyatakan query:

```sql
SELECT city, credit_limit
...
```

sebagai **legitimate application enhancement**.

## Penjelasan

Di produksi, jangan pernah:

```text
violation
→ otomatis approve
```

Harus:

```text
violation
→ review
→ legitimate?
→ baru approve
```

---

# Lab 56 — Append Only the Latest SQL Violation

Command berikut otomatis mengambil SQL violation terbaru lalu menambahkannya ke allow-list.

```sql
DECLARE
    l_sql_signature VARCHAR2(64);
    l_current_user  VARCHAR2(128);
    l_top_level     VARCHAR2(9);
BEGIN
    SELECT sql_signature,
           current_user,
           top_level
    INTO   l_sql_signature,
           l_current_user,
           l_top_level
    FROM (
        SELECT sql_signature,
               current_user,
               top_level
        FROM   dba_sql_firewall_violations
        WHERE  username='UA_D3_READER'
        AND    cause='SQL violation'
        ORDER  BY occurred_at DESC
    )
    WHERE ROWNUM=1;

    DBMS_SQL_FIREWALL.APPEND_ALLOW_LIST_SINGLE_SQL(
        username      => 'UA_D3_READER',
        sql_signature => l_sql_signature,
        current_user  => l_current_user,
        top_level     => l_top_level,
        source        => DBMS_SQL_FIREWALL.VIOLATION_LOG
    );
END;
/
```

## Penjelasan

Ini fitur penting 26ai.

Kita tidak meng-approve seluruh violation log, hanya satu SQL yang sudah direview.

---

# Lab 57 — Verify Allow-List Version Increment

## Command

```sql
COLUMN sql_text FORMAT A90
COLUMN version FORMAT 999

SELECT allowed_sql_id,
       version,
       sql_text
FROM   dba_sql_firewall_allowed_sql
WHERE  username='UA_D3_READER'
ORDER  BY version,
          allowed_sql_id;
```

## Penjelasan

Version membantu mengetahui statement mana yang masuk pada batch perubahan allow-list tertentu.

---

# Lab 58 — Retest Newly Approved SQL

Terminal B:

```bash
sqlplus -L 'ua_d3_reader/Oracle#D3Read26@//192.168.56.26:1521/PDB1'
```

Jalankan:

```sql
SELECT city,
       credit_limit
FROM   ua_d3_app.customer_secure
WHERE  credit_limit > 30000000
ORDER  BY credit_limit DESC;
```

Keluar:

```sql
EXIT
```

---

# PART L — BLOCKING MODE

---

# Lab 59 — Change Enforcement to Blocking

Terminal A / SYS:

```sql
BEGIN
    DBMS_SQL_FIREWALL.UPDATE_ALLOW_LIST_ENFORCEMENT(
        username => 'UA_D3_READER',
        enforce  => DBMS_SQL_FIREWALL.ENFORCE_SQL,
        block    => TRUE
    );
END;
/
```

## Penjelasan

Sekarang:

```text
known SQL   → executes
unknown SQL → blocked
```

---

# Lab 60 — Verify Blocking Mode

## Command

```sql
SELECT username,
       status,
       enforce,
       block
FROM   dba_sql_firewall_allow_lists
WHERE  username='UA_D3_READER';
```

---

# Lab 61 — Known SQL Still Works

Terminal B:

```bash
sqlplus -L 'ua_d3_reader/Oracle#D3Read26@//192.168.56.26:1521/PDB1'
```

Run:

```sql
SELECT COUNT(*) AS customer_count
FROM   ua_d3_app.customer_secure;
```

## Penjelasan

Blocking mode bukan berarti semua SQL ditolak. SQL yang match allow-list tetap berjalan.

---

# Lab 62 — Generate a New Unapproved SQL

Masih sebagai reader:

```sql
SELECT customer_name,
       city,
       account_status
FROM   ua_d3_app.customer_secure
WHERE  city IN ('Jakarta','Depok')
ORDER  BY customer_name;
```

SQL ini valid secara privilege, tetapi tidak ada pada allow-list sehingga diblokir.

## Penjelasan

Ini adalah bukti enforcement aktif:

```text
valid privilege
+
valid SQL
+
not in allow-list
        ↓
blocked by SQL Firewall
```

Keluar:

```sql
EXIT
```

---

# Lab 63 — Investigate Blocked Violation

Terminal A:

```sql
EXEC DBMS_SQL_FIREWALL.FLUSH_LOGS;
```

Kemudian:

```sql
COLUMN occurred_at FORMAT A35
COLUMN cause FORMAT A20
COLUMN firewall_action FORMAT A15
COLUMN sql_text FORMAT A100

SELECT occurred_at,
       cause,
       firewall_action,
       sql_text
FROM   dba_sql_firewall_violations
WHERE  username='UA_D3_READER'
ORDER  BY occurred_at DESC
FETCH FIRST 10 ROWS ONLY;
```

## Penjelasan

Perbandingan utama:

```text
Detect-only → FIREWALL_ACTION = Allowed
Blocking    → FIREWALL_ACTION = Blocked
```

---

# Lab 64 — Verify Blocked Event in Unified Audit

## Command

```sql
SELECT TO_CHAR(event_timestamp,'YYYY-MM-DD HH24:MI:SS') AS event_time,
       dbusername,
       audit_type,
       fw_action_name,
       fw_return_code,
       return_code
FROM   unified_audit_trail
WHERE  UPPER(audit_type)='SQL FIREWALL'
AND    dbusername='UA_D3_READER'
ORDER  BY event_timestamp DESC
FETCH FIRST 10 ROWS ONLY;
```

## Penjelasan

Untuk forensic investigation, bandingkan timestamp kedua source.

---

# PART M — CONTEXT-BASED ENFORCEMENT

---

# Lab 65 — Switch Back to Detect-Only but Enforce SQL + Context

Agar context lab tidak mengunci user, gunakan `block => FALSE`.

```sql
BEGIN
    DBMS_SQL_FIREWALL.UPDATE_ALLOW_LIST_ENFORCEMENT(
        username => 'UA_D3_READER',
        enforce  => DBMS_SQL_FIREWALL.ENFORCE_ALL,
        block    => FALSE
    );
END;
/
```

Verifikasi:

```sql
SELECT username,
       enforce,
       block
FROM   dba_sql_firewall_allow_lists
WHERE  username='UA_D3_READER';
```

## Penjelasan

Sekarang SQL Firewall memeriksa:

```text
SQL
+
connection context
```

---

# Lab 66 — Inspect Trusted Context Before Testing

## Command

```sql
SELECT username, ip_address
FROM   dba_sql_firewall_allowed_ip_addr
WHERE  username='UA_D3_READER';

SELECT username, os_user
FROM   dba_sql_firewall_allowed_os_user
WHERE  username='UA_D3_READER';

SELECT username, os_program
FROM   dba_sql_firewall_allowed_os_prog
WHERE  username='UA_D3_READER';
```

## Penjelasan

Catat nilai real environment.

---

# Lab 67 — Save Current OS Program into SQL*Plus Variable

> Lab ini mengasumsikan capture dilakukan hanya dari satu tipe SQL*Plus client. Jika ada banyak `OS_PROGRAM`, pilih satu nilai yang dipakai untuk test.

```sql
COLUMN os_program NEW_VALUE FW_ORIGINAL_OS_PROGRAM NOPRINT

SELECT os_program
FROM   dba_sql_firewall_allowed_os_prog
WHERE  username='UA_D3_READER'
FETCH FIRST 1 ROW ONLY;

DEFINE FW_ORIGINAL_OS_PROGRAM
```

## Penjelasan

Nilai ini akan dipakai untuk mengembalikan policy setelah context violation test.

---

# Lab 68 — Temporarily Replace Allowed OS Program

Hapus seluruh allowed OS program:

```sql
BEGIN
    DBMS_SQL_FIREWALL.DELETE_ALLOWED_CONTEXT(
        username     => 'UA_D3_READER',
        context_type => DBMS_SQL_FIREWALL.OS_PROGRAM,
        value        => NULL
    );
END;
/
```

Tambah program yang pasti tidak sama dengan SQL*Plus:

```sql
BEGIN
    DBMS_SQL_FIREWALL.ADD_ALLOWED_CONTEXT(
        username     => 'UA_D3_READER',
        context_type => DBMS_SQL_FIREWALL.OS_PROGRAM,
        value        => 'DEFINITELY_NOT_SQLPLUS'
    );
END;
/
```

Cek:

```sql
SELECT username,
       os_program
FROM   dba_sql_firewall_allowed_os_prog
WHERE  username='UA_D3_READER';
```

## Penjelasan

Kita sengaja membuat mismatch context, tetapi karena `block=FALSE`, login tetap diizinkan sehingga aman untuk training.

---

# Lab 69 — Generate Context Violation

Terminal B:

```bash
sqlplus -L 'ua_d3_reader/Oracle#D3Read26@//192.168.56.26:1521/PDB1'
```

Karena detect-only context enforcement, login diharapkan tetap berhasil.

Jalankan known SQL:

```sql
SELECT COUNT(*) AS customer_count
FROM   ua_d3_app.customer_secure;
```

Keluar:

```sql
EXIT
```

## Penjelasan

SQL-nya dikenal, tetapi connection program tidak ada di allowed context.

---

# Lab 70 — Inspect Context Violation

Terminal A:

```sql
EXEC DBMS_SQL_FIREWALL.FLUSH_LOGS;
```

Query:

```sql
SELECT occurred_at,
       username,
       cause,
       firewall_action,
       ip_address,
       os_user,
       client_program,
       sql_text
FROM   dba_sql_firewall_violations
WHERE  username='UA_D3_READER'
ORDER  BY occurred_at DESC
FETCH FIRST 10 ROWS ONLY;
```

## Penjelasan

Ini membuktikan SQL Firewall tidak hanya bertanya:

```text
"Apakah SQL ini dikenal?"
```

tetapi juga:

```text
"Apakah koneksi datang dari context yang dikenal?"
```

---

# Lab 71 — Restore Original OS Program

Hapus dummy context:

```sql
BEGIN
    DBMS_SQL_FIREWALL.DELETE_ALLOWED_CONTEXT(
        username     => 'UA_D3_READER',
        context_type => DBMS_SQL_FIREWALL.OS_PROGRAM,
        value        => 'DEFINITELY_NOT_SQLPLUS'
    );
END;
/
```

Restore captured program:

```sql
BEGIN
    DBMS_SQL_FIREWALL.ADD_ALLOWED_CONTEXT(
        username     => 'UA_D3_READER',
        context_type => DBMS_SQL_FIREWALL.OS_PROGRAM,
        value        => '&FW_ORIGINAL_OS_PROGRAM'
    );
END;
/
```

Verify:

```sql
SELECT username,
       os_program
FROM   dba_sql_firewall_allowed_os_prog
WHERE  username='UA_D3_READER';
```

## Penjelasan

Selalu restore policy setelah deliberately creating context mismatch.

---

# PART N — FINAL SAFE ENFORCEMENT STATE

---

# Lab 72 — Set Final Training Mode to Detect-Only

Untuk mengakhiri kelas dengan aman:

```sql
BEGIN
    DBMS_SQL_FIREWALL.UPDATE_ALLOW_LIST_ENFORCEMENT(
        username => 'UA_D3_READER',
        enforce  => DBMS_SQL_FIREWALL.ENFORCE_ALL,
        block    => FALSE
    );
END;
/
```

Verify:

```sql
SELECT username,
       status,
       enforce,
       block
FROM   dba_sql_firewall_allow_lists
WHERE  username='UA_D3_READER';
```

## Penjelasan

Detect-only adalah state yang lebih aman untuk akhir training daripada meninggalkan blocking aktif.

---

# PART O — EXPORT ALLOW-LIST TO JSON/CLOB

---

# Lab 73 — Create a Temporary CLOB

Masih di SQL*Plus SYS session:

```sql
VARIABLE fw_allowlist_json CLOB
```

Kemudian:

```sql
BEGIN
    DBMS_LOB.CREATETEMPORARY(
        :fw_allowlist_json,
        TRUE
    );
END;
/
```

## Penjelasan

`EXPORT_ALLOW_LIST` membutuhkan CLOB yang sudah dibuat.

---

# Lab 74 — Export Allow-List

## Command

```sql
BEGIN
    DBMS_SQL_FIREWALL.EXPORT_ALLOW_LIST(
        username   => 'UA_D3_READER',
        allow_list => :fw_allowlist_json
    );
END;
/
```

## Penjelasan

Payload JSON mencakup allow-list settings, allowed SQL, allowed contexts, dan referenced SQL logs. Capture logs dan violation logs tidak ikut diekspor.

---

# Lab 75 — Check Export Size

## Command

```sql
SELECT DBMS_LOB.GETLENGTH(:fw_allowlist_json) AS json_bytes
FROM   dual;
```

## Penjelasan

Ini memastikan CLOB export terisi.

---

# Lab 76 — Display Beginning of JSON

## Command

```sql
SET SERVEROUTPUT ON
DECLARE
    l_text VARCHAR2(32767);
BEGIN
    l_text := DBMS_LOB.SUBSTR(
                  :fw_allowlist_json,
                  12000,
                  1
              );

    DBMS_OUTPUT.PUT_LINE(l_text);
END;
/
```

## Penjelasan

Untuk training, cukup melihat payload. Untuk backup operational penuh, gunakan mekanisme file/application/Data Pump yang sesuai prosedur organisasi.

---

# PART P — OPTIONAL IMPORT / RECOVERY DEMONSTRATION

> **Bagian ini optional.**
>
> Jalankan hanya jika ingin membuktikan bahwa allow-list dapat direkonstruksi dari JSON CLOB yang baru diekspor.

---

# Lab 77 — Disable Current Allow-List

```sql
EXEC DBMS_SQL_FIREWALL.DISABLE_ALLOW_LIST('UA_D3_READER');
```

---

# Lab 78 — Drop Allow-List Only

```sql
EXEC DBMS_SQL_FIREWALL.DROP_ALLOW_LIST('UA_D3_READER');
```

Verify:

```sql
SELECT *
FROM   dba_sql_firewall_allow_lists
WHERE  username='UA_D3_READER';
```

## Penjelasan

Capture object tetap merupakan entity terpisah.

---

# Lab 79 — Import Allow-List from CLOB

```sql
BEGIN
    DBMS_SQL_FIREWALL.IMPORT_ALLOW_LIST(
        username   => 'UA_D3_READER',
        allow_list => :fw_allowlist_json
    );
END;
/
```

---

# Lab 80 — Verify Imported Allow-List

```sql
SELECT username,
       status,
       top_level_only,
       enforce,
       block
FROM   dba_sql_firewall_allow_lists
WHERE  username='UA_D3_READER';
```

## Penjelasan

Jika target user sudah ada dan metadata kompatibel, import mengembalikan SQL/context dari JSON payload.

---

# PART Q — LOG MANAGEMENT

---

# Lab 81 — Count Current Logs

```sql
SELECT
    (SELECT COUNT(*)
     FROM   dba_sql_firewall_capture_logs
     WHERE  username='UA_D3_READER') AS capture_logs,
    (SELECT COUNT(*)
     FROM   dba_sql_firewall_violations
     WHERE  username='UA_D3_READER') AS violation_logs
FROM dual;
```

## Penjelasan

Evidence bertambah seiring waktu dan membutuhkan retention strategy.

---

# Lab 82 — Safe Retention Example: Purge Violations Older Than 30 Days

```sql
BEGIN
    DBMS_SQL_FIREWALL.PURGE_LOG(
        username   => 'UA_D3_READER',
        purge_time => SYSTIMESTAMP - INTERVAL '30' DAY,
        log_type   => DBMS_SQL_FIREWALL.VIOLATION_LOG
    );
END;
/
```

Tidak ada log yang lebih tua dari 30 hari pada saat uji.

## Penjelasan

Pada lab baru biasanya tidak ada log >30 hari sehingga evidence hari ini tetap aman.

---

# Lab 83 — Optional Purge All Lab Violation Logs

> Jangan jalankan sebelum peserta selesai melakukan investigation.

```sql
BEGIN
    DBMS_SQL_FIREWALL.PURGE_LOG(
        username   => 'UA_D3_READER',
        purge_time => NULL,
        log_type   => DBMS_SQL_FIREWALL.VIOLATION_LOG
    );
END;
/
```

Jalankan perintah ini **setelah Lab 96** agar evidence capstone tetap dapat dibaca.

## Penjelasan

`purge_time => NULL` menghapus seluruh log sesuai `log_type` untuk user tersebut.

---

# PART R — DAILY OPERATIONS DASHBOARD

---

# Lab 84 — SQL Firewall Global Health

```sql
SELECT status,
       status_updated_on,
       exclude_jobs
FROM   dba_sql_firewall_status;
```

Pertanyaan yang dijawab:

```text
SQL Firewall hidup?
```

---

# Lab 85 — Capture Inventory

```sql
SELECT username,
       top_level_only,
       status,
       last_started_on,
       last_stopped_on
FROM   dba_sql_firewall_captures
ORDER  BY username;
```

Pertanyaan:

```text
User mana sedang learning?
Capture running atau stopped?
```

---

# Lab 86 — Allow-List Inventory

```sql
SELECT username,
       status,
       enforce,
       block,
       generated_on,
       status_updated_on
FROM   dba_sql_firewall_allow_lists
ORDER  BY username;
```

Pertanyaan:

```text
Allow-list user mana aktif?
Detect-only atau blocking?
SQL/context apa yang enforced?
```

---

# Lab 87 — Violation Count by User and Cause

```sql
SELECT username,
       cause,
       firewall_action,
       COUNT(*) AS violations
FROM   dba_sql_firewall_violations
GROUP  BY username,
          cause,
          firewall_action
ORDER  BY username,
          cause,
          firewall_action;
```

## Penjelasan

Ini query operational cepat untuk membedakan:

```text
SQL violation
Context violation
Allowed
Blocked
```

---

# Lab 88 — Latest 20 Violations

```sql
COLUMN occurred_at FORMAT A35
COLUMN username FORMAT A18
COLUMN cause FORMAT A20
COLUMN firewall_action FORMAT A15
COLUMN sql_text FORMAT A100

SELECT occurred_at,
       username,
       cause,
       firewall_action,
       ip_address,
       os_user,
       client_program,
       sql_text
FROM   dba_sql_firewall_violations
ORDER  BY occurred_at DESC
FETCH FIRST 20 ROWS ONLY;
```

---

# Lab 89 — Allow-List Version Summary

```sql
SELECT username,
       version,
       COUNT(*) AS sql_entries
FROM   dba_sql_firewall_allowed_sql
GROUP  BY username,
          version
ORDER  BY username,
          version;
```

## Penjelasan

Membantu melihat evolution history dari allowed SQL.

---

# PART S — TROUBLESHOOTING LAB

---

# Lab 90 — Troubleshooting: Capture Not Populated

Jalankan checklist:

```sql
SELECT status
FROM   dba_sql_firewall_status;
```


Kemudian:

```sql
SELECT username,
       status
FROM   dba_sql_firewall_captures
WHERE  username='UA_D3_READER';
```


Kemudian:

```sql
SELECT COUNT(*)
FROM   dba_sql_firewall_capture_logs
WHERE  username='UA_D3_READER';
```

Jika `0`, check apakah workload benar-benar dijalankan setelah capture start.

Force flush:

```sql
EXEC DBMS_SQL_FIREWALL.FLUSH_LOGS;
```

Check lagi.

---

# Lab 91 — Troubleshooting: Allow-List Cannot Be Generated

Check capture:

```sql
SELECT username,
       status
FROM   dba_sql_firewall_captures
WHERE  username='UA_D3_READER';
```


Jika masih enabled:

```sql
EXEC DBMS_SQL_FIREWALL.STOP_CAPTURE('UA_D3_READER');
```

Kemudian:

```sql
EXEC DBMS_SQL_FIREWALL.GENERATE_ALLOW_LIST('UA_D3_READER');
```

---

# Lab 92 — Troubleshooting: Expected SQL Becomes Violation

Tampilkan allowed SQL:

```sql
SELECT allowed_sql_id,
       sql_signature,
       sql_text,
       current_user,
       top_level,
       version
FROM   dba_sql_firewall_allowed_sql
WHERE  username='UA_D3_READER'
ORDER  BY allowed_sql_id;
```

Bandingkan dengan violation:

```sql
SELECT sql_signature,
       sql_text,
       current_user,
       top_level,
       cause,
       ip_address,
       client_program,
       os_user
FROM   dba_sql_firewall_violations
WHERE  username='UA_D3_READER'
ORDER  BY occurred_at DESC;
```

Investigasi:

```text
SQL signature berbeda?
Current user berbeda?
Top-level status berbeda?
Context berubah?
Allow-list belum di-update?
```

---

# Lab 93 — Troubleshooting: Blocked Unexpectedly

Check mode:

```sql
SELECT username,
       enforce,
       block
FROM   dba_sql_firewall_allow_lists
WHERE  username='UA_D3_READER';
```

Jika:

```text
BLOCK = Y
```

sementara ingin troubleshooting aman, ubah sementara:

```sql
BEGIN
    DBMS_SQL_FIREWALL.UPDATE_ALLOW_LIST_ENFORCEMENT(
        username => 'UA_D3_READER',
        enforce  => DBMS_SQL_FIREWALL.ENFORCE_ALL,
        block    => FALSE
    );
END;
/
```

## Penjelasan

Jangan langsung drop allow-list. Turunkan ke detect-only, kumpulkan evidence, analisis, lalu tune.

---

# PART T — INCIDENT INVESTIGATION CAPSTONE

---

# Lab 94 — Scenario

Asumsikan SOC menerima informasi:

```text
UA_D3_READER menjalankan SQL baru
yang tidak dikenal oleh baseline.
```

Investigator harus menjawab:

```text
1. Kapan terjadi?
2. SQL apa?
3. Object apa?
4. SQL atau context violation?
5. Allowed atau blocked?
6. IP dari mana?
7. OS user siapa?
8. Client program apa?
9. Apakah Unified Audit punya event terkait?
10. Legitimate change atau suspicious activity?
```

---

# Lab 95 — Pull SQL Firewall Evidence

```sql
COLUMN occurred_at FORMAT A35
COLUMN command_type FORMAT A15
COLUMN cause FORMAT A20
COLUMN firewall_action FORMAT A15
COLUMN accessed_objects FORMAT A50
COLUMN sql_text FORMAT A100

SELECT occurred_at,
       command_type,
       cause,
       firewall_action,
       ip_address,
       os_user,
       client_program,
       accessed_objects,
       sql_text
FROM   dba_sql_firewall_violations
WHERE  username='UA_D3_READER'
ORDER  BY occurred_at DESC
FETCH FIRST 20 ROWS ONLY;
```

---

# Lab 96 — Pull Unified Audit Evidence

```sql
COLUMN event_time FORMAT A19
COLUMN audit_type FORMAT A15
COLUMN action_name FORMAT A25
COLUMN fw_action_name FORMAT A30

SELECT TO_CHAR(event_timestamp,'YYYY-MM-DD HH24:MI:SS') AS event_time,
       dbusername,
       audit_type,
       action_name,
       fw_action_name,
       fw_return_code,
       return_code,
       client_program_name,
       userhost
FROM   unified_audit_trail
WHERE  dbusername='UA_D3_READER'
AND    UPPER(audit_type)='SQL FIREWALL'
ORDER  BY event_timestamp DESC
FETCH FIRST 20 ROWS ONLY;
```

---

# Lab 97 — Decision Framework

Gunakan workflow:

```text
Violation detected
        ↓
Read SQL text
        ↓
Check accessed objects
        ↓
Check IP / OS user / program
        ↓
Check firewall action
        ↓
Correlate Unified Audit
        ↓
Known application change?
       / \
     YES  NO
      |    |
      |    └── investigate as suspicious
      |
review / approve
      |
append single SQL if justified
```

## Important

Violation bukan otomatis bukti serangan.

Violation berarti:

```text
runtime behavior
!=
current baseline
```

---
