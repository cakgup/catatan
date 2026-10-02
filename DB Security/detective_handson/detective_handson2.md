# Handson 2 - Advanced Unified Auditing





Environment:

```text
OS              : Oracle Linux Server 9.8
Oracle Database : Oracle AI Database 26ai 23.26.1.0.0
ORACLE_HOME     : /opt/oracle/product/26ai/dbhome_1
ORACLE_BASE     : /opt/oracle
ORACLE_SID      : ORCLCDB
SYS password    : oracle
PDB             : PDB1
```

Target Handson 2:

```text
Handson 1
Basic Unified Auditing
       │
       ▼
Handson 2
Advanced Unified Auditing
       │
       ├── Object Auditing
       ├── System Privilege Auditing
       ├── User-specific Auditing
       ├── Successful-only Auditing
       ├── Failed-only Auditing
       ├── Conditional Auditing
       ├── Role Auditing
       ├── Policy Exceptions
       ├── Session Investigation
       ├── SQL Investigation
       └── Security Incident Analysis
```

---

# LAB 1 — Persiapan Environment

Login ke Linux sebagai user `oracle`.

```bash
whoami
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


---

# LAB 2 — Verifikasi Database Handson 1

Login:

```bash
sqlplus -L "sys/oracle@192.168.56.26:1521/PDB1 as sysdba"
```


Muat kembali format SQL*Plus yang sudah dibuat pada Handson 1 agar kolom audit lebih mudah dibaca:

```sql
@/tmp/security_lab_format.sql
```

Pindah ke PDB1:

```sql
ALTER SESSION SET CONTAINER=PDB1;
```


Verifikasi:

```sql
SHOW CON_NAME
```


---

# LAB 3 — Verifikasi AUDIT_USER

```sql
SELECT username,
       account_status
FROM dba_users
WHERE username IN ('AUDIT_USER','LAB_AUDITOR')
ORDER BY username;
```


---

# LAB 4 — Verifikasi Tabel CUSTOMERS

```sql
SELECT owner,
       table_name
FROM dba_tables
WHERE owner='AUDIT_USER'
AND table_name='CUSTOMERS';
```


Periksa data:

```sql
SELECT customer_id,
       customer_name,
       credit_limit,
       status
FROM audit_user.customers
ORDER BY customer_id;
```


Data bisa sedikit berbeda jika latihan Handson 1 Anda dimodifikasi.

---

# LAB 5 — Inventory Unified Audit Policies

```sql
SELECT policy_name,
       enabled_option,
       entity_name
FROM audit_unified_enabled_policies
ORDER BY policy_name, entity_name;
```


Policy bawaan Oracle juga dapat muncul.

---

# LAB 6 — Konsep Penting: Policy Definition vs Activation

Oracle memisahkan:

```text
CREATE AUDIT POLICY
        │
        ▼
policy definition
        │
        │
        │ AUDIT POLICY
        ▼
policy enabled
        │
        ▼
audit records
```

Lihat definisi policy:

```sql
SELECT policy_name,
       audit_option,
       object_schema,
       object_name
FROM audit_unified_policies
WHERE policy_name='CUSTOMER_ACCESS_POLICY'
ORDER BY audit_option;
```


Oracle secara resmi mensyaratkan policy dibuat lebih dahulu dan kemudian diaktifkan dengan `AUDIT POLICY`. ([Oracle documentation][2])

---

# LAB 7 — Membuat User Tambahan

Prasyarat: jangan jalankan cleanup opsional Handson 1. Handson 2 memakai `AUDIT_USER`, `LAB_AUDITOR`, dan `AUDIT_USER.CUSTOMERS` dari sana. Kita kemudian menambah user berikut untuk membandingkan behavior auditing.

Buat:

```sql
CREATE USER app_user
IDENTIFIED BY Welcome1
DEFAULT TABLESPACE users
TEMPORARY TABLESPACE temp;
```


```sql
GRANT CREATE SESSION TO app_user;
```


Buat user kedua:

```sql
CREATE USER security_ops
IDENTIFIED BY Welcome1
DEFAULT TABLESPACE users
TEMPORARY TABLESPACE temp
QUOTA UNLIMITED ON users;
```


Privilege:

```sql
GRANT CREATE SESSION,
      CREATE TABLE,
      CREATE SEQUENCE
TO security_ops;
```


---

# LAB 8 — Memberikan Access ke CUSTOMERS

Berikan `APP_USER` hak membaca:

```sql
GRANT SELECT ON audit_user.customers TO app_user;
```


Berikan juga kepada `SECURITY_OPS`:

```sql
GRANT SELECT ON audit_user.customers TO security_ops;
```


Topology sekarang:

```text
                 AUDIT_USER.CUSTOMERS
                         ▲
                         │
          ┌──────────────┴──────────────┐
          │                             │
      APP_USER                   SECURITY_OPS
        SELECT                      SELECT
```

---

# LAB 9 — Membuat Object Audit Policy

Kita akan mengaudit siapa pun yang membaca tabel `CUSTOMERS`.

Untuk menghindari conflict jika lab pernah dijalankan sebelumnya:

```sql
BEGIN
   EXECUTE IMMEDIATE 'NOAUDIT POLICY customers_select_pol';
EXCEPTION
   WHEN OTHERS THEN
      NULL;
END;
/
```

Kemudian:

```sql
BEGIN
   EXECUTE IMMEDIATE 'DROP AUDIT POLICY customers_select_pol';
EXCEPTION
   WHEN OTHERS THEN
      NULL;
END;
/
```

Buat policy:

```sql
CREATE AUDIT POLICY customers_select_pol
ACTIONS SELECT ON audit_user.customers;
```


Oracle AI Database 26ai mendukung object action seperti `SELECT`, `UPDATE`, dan action lainnya melalui `ACTIONS ... ON schema.object`. ([Oracle documentation][2])

---

# LAB 10 — Enable Policy untuk Semua User

```sql
AUDIT POLICY customers_select_pol;
```


Verifikasi:

```sql
SELECT policy_name,
       enabled_option,
       entity_name
FROM audit_unified_enabled_policies
WHERE policy_name='CUSTOMERS_SELECT_POL';
```


---

# LAB 11 — Penting: Reconnect Setelah Policy Diaktifkan

Unified audit policy yang baru diaktifkan berlaku pada **session user berikutnya**. Bila user sudah login sebelum policy diaktifkan, logout dan login kembali agar policy berlaku. ([Oracle documentation][3])

Keluar:

```sql
EXIT
```

---

# LAB 12 — Test APP_USER

```bash
sqlplus -L app_user/Welcome1@192.168.56.26:1521/PDB1
```


Verifikasi:

```sql
SHOW USER
```


Query:

```sql
SELECT customer_id,
       customer_name,
       status
FROM audit_user.customers
ORDER BY customer_id;
```


Keluar:

```sql
EXIT
```

---

# LAB 13 — Test SECURITY_OPS

```bash
sqlplus -L security_ops/Welcome1@192.168.56.26:1521/PDB1
```


Jalankan:

```sql
SELECT customer_id,
       customer_name
FROM audit_user.customers
WHERE customer_id=1;
```


Keluar:

```sql
EXIT
```

---

# LAB 14 — Investigasi Object Audit

Login investigator:

```bash
sqlplus -L lab_auditor/Welcome1@192.168.56.26:1521/PDB1
```


Muat format SQL*Plus Handson 1 sebelum menjalankan query investigasi:

```sql
@/tmp/security_lab_format.sql
```

Query:

```sql
SELECT event_timestamp,
       dbusername,
       action_name,
       object_schema,
       object_name,
       return_code,
       unified_audit_policies
FROM unified_audit_trail
WHERE unified_audit_policies LIKE '%CUSTOMERS_SELECT_POL%'
ORDER BY event_timestamp;
```


---

# LAB 15 — User-Specific Auditing

Sekarang kita ubah policy agar hanya mengaudit `APP_USER`.

Login SYS:

```sql
EXIT
```

```bash
sqlplus -L sys/oracle@192.168.56.26:1521/PDB1 as sysdba
```


Disable:

```sql
NOAUDIT POLICY customers_select_pol;
```


Enable hanya untuk `APP_USER`:

```sql
AUDIT POLICY customers_select_pol BY app_user;
```


Verifikasi:

```sql
SELECT policy_name,
       enabled_option,
       entity_name
FROM audit_unified_enabled_policies
WHERE policy_name='CUSTOMERS_SELECT_POL';
```


---

# LAB 16 — Test Per-User Auditing

Reconnect `APP_USER`:

Kembali ke shell terlebih dahulu:

```sql
EXIT
```

```bash
sqlplus -L app_user/Welcome1@192.168.56.26:1521/PDB1
```


```sql
SELECT COUNT(*)
FROM audit_user.customers;
```


Keluar:

```sql
EXIT
```

Login `SECURITY_OPS`:

```bash
sqlplus -L security_ops/Welcome1@192.168.56.26:1521/PDB1
```


```sql
SELECT COUNT(*)
FROM audit_user.customers;
```


Keluar:

```sql
EXIT
```

Pada policy ini:

```text
APP_USER
   │
   └── SELECT → audited

SECURITY_OPS
   │
   └── SELECT → not audited by CUSTOMERS_SELECT_POL
```

---

# LAB 17 — Auditing Successful Operations Only

Oracle dapat mencatat hanya statement yang berhasil dengan:

```text
WHENEVER SUCCESSFUL
```

atau hanya statement gagal dengan:

```text
WHENEVER NOT SUCCESSFUL
```

([Oracle documentation][3])

Buat policy baru.

```bash
sqlplus -L sys/oracle@192.168.56.26:1521/PDB1 as sysdba
```


Cleanup jika sudah ada:

```sql
BEGIN
   EXECUTE IMMEDIATE 'NOAUDIT POLICY successful_select_pol';
EXCEPTION
   WHEN OTHERS THEN NULL;
END;
/
BEGIN
   EXECUTE IMMEDIATE 'DROP AUDIT POLICY successful_select_pol';
EXCEPTION
   WHEN OTHERS THEN NULL;
END;
/
```

Create:

```sql
CREATE AUDIT POLICY successful_select_pol
ACTIONS SELECT ON audit_user.customers;
```


Enable:

```sql
AUDIT POLICY successful_select_pol
BY app_user
WHENEVER SUCCESSFUL;
```


---

# LAB 18 — Generate Successful SELECT

```sql
EXIT
```

```bash
sqlplus -L app_user/Welcome1@192.168.56.26:1521/PDB1
```


```sql
SELECT customer_name
FROM audit_user.customers
WHERE customer_id=1;
```


Keluar:

```sql
EXIT
```

---

# LAB 19 — Melihat Successful Audit Record

```bash
sqlplus -L lab_auditor/Welcome1@192.168.56.26:1521/PDB1
```


```sql
SELECT event_timestamp,
       dbusername,
       action_name,
       return_code,
       unified_audit_policies
FROM unified_audit_trail
WHERE unified_audit_policies LIKE '%SUCCESSFUL_SELECT_POL%'
ORDER BY event_timestamp DESC;
```


`RETURN_CODE = 0` berarti berhasil.

---

# LAB 20 — Failed-Only Policy

Sekarang kita buat policy untuk mendeteksi aksi yang gagal.

Login SYS:

```sql
EXIT
```

```bash
sqlplus -L sys/oracle@192.168.56.26:1521/PDB1 as sysdba
```


Buat policy:

```sql
BEGIN
   EXECUTE IMMEDIATE 'NOAUDIT POLICY failed_ddl_pol';
EXCEPTION
   WHEN OTHERS THEN NULL;
END;
/
BEGIN
   EXECUTE IMMEDIATE 'DROP AUDIT POLICY failed_ddl_pol';
EXCEPTION
   WHEN OTHERS THEN NULL;
END;
/
```

```sql
CREATE AUDIT POLICY failed_ddl_pol
ACTIONS DROP TABLE;
```


Enable hanya failure:

```sql
AUDIT POLICY failed_ddl_pol
BY app_user
WHENEVER NOT SUCCESSFUL;
```


---

# LAB 21 — Generate Failed DROP TABLE

`APP_USER` tidak memiliki table yang akan kita coba drop.

Reconnect:

```sql
EXIT
```

```bash
sqlplus -L app_user/Welcome1@192.168.56.26:1521/PDB1
```


Coba:

```sql
DROP TABLE table_yang_tidak_ada PURGE;
```


Keluar:

```sql
EXIT
```

---

# LAB 22 — Investigasi Failed Action

```bash
sqlplus -L lab_auditor/Welcome1@192.168.56.26:1521/PDB1
```


```sql
SELECT event_timestamp,
       dbusername,
       action_name,
       object_name,
       return_code,
       unified_audit_policies
FROM unified_audit_trail
WHERE unified_audit_policies LIKE '%FAILED_DDL_POL%'
ORDER BY event_timestamp DESC;
```


Perhatikan hubungan:

```text
ORA-00942
     │
     ▼
RETURN_CODE = 942
```

---

# LAB 23 — System Privilege Auditing

Ini salah satu materi penting Handson 2.

Object audit:

```text
Apa yang dilakukan terhadap OBJECT?
```

Privilege audit:

```text
System privilege apa yang digunakan?
```

Oracle AI Database 26ai menggunakan clause:

```sql
PRIVILEGES privilege_name
```

untuk mengaudit penggunaan system privilege. Audit record hanya muncul bila privilege tersebut benar-benar digunakan oleh statement. ([Oracle documentation][4])

---

# LAB 24 — Buat Privilege Audit Policy

Login SYS:

```sql
EXIT
```

```bash
sqlplus -L sys/oracle@192.168.56.26:1521/PDB1 as sysdba
```


Cleanup:

```sql
BEGIN
   EXECUTE IMMEDIATE 'NOAUDIT POLICY security_ops_priv_pol';
EXCEPTION
   WHEN OTHERS THEN NULL;
END;
/
BEGIN
   EXECUTE IMMEDIATE 'DROP AUDIT POLICY security_ops_priv_pol';
EXCEPTION
   WHEN OTHERS THEN NULL;
END;
/
```

Create:

```sql
CREATE AUDIT POLICY security_ops_priv_pol
PRIVILEGES CREATE TABLE, CREATE SEQUENCE;
```


Enable hanya untuk:

```sql
AUDIT POLICY security_ops_priv_pol
BY security_ops;
```


---

# LAB 25 — Generate CREATE TABLE

Reconnect:

```sql
EXIT
```

```bash
sqlplus -L security_ops/Welcome1@192.168.56.26:1521/PDB1
```


Create:

```sql
CREATE TABLE sec_test (
    id          NUMBER,
    description VARCHAR2(100)
);
```


---

# LAB 26 — Generate CREATE SEQUENCE

```sql
CREATE SEQUENCE sec_test_seq
START WITH 1
INCREMENT BY 1;
```


---

# LAB 27 — Insert Data

```sql
INSERT INTO sec_test
VALUES
(
    sec_test_seq.NEXTVAL,
    'Privilege auditing test'
);
```


Commit:

```sql
COMMIT;
```


Keluar:

```sql
EXIT
```

---

# LAB 28 — Investigasi Privilege Usage

```bash
sqlplus -L lab_auditor/Welcome1@192.168.56.26:1521/PDB1
```


Muat format SQL*Plus Handson 1 sebelum menjalankan query investigasi:

```sql
@/tmp/security_lab_format.sql
```

Query:

```sql
SELECT event_timestamp,
       dbusername,
       action_name,
       object_name,
       system_privilege_used,
       return_code,
       unified_audit_policies
FROM unified_audit_trail
WHERE unified_audit_policies LIKE '%SECURITY_OPS_PRIV_POL%'
ORDER BY event_timestamp;
```


Ini adalah bukti bahwa:

```text
SECURITY_OPS
     │
     ├── used CREATE TABLE
     └── used CREATE SEQUENCE
             │
             ▼
UNIFIED_AUDIT_TRAIL
```

---

# LAB 29 — Melihat Semua System Privileges yang Valid

Login SYS bila perlu:

Kembali ke shell terlebih dahulu:

```sql
EXIT
```

```bash
sqlplus -L sys/oracle@192.168.56.26:1521/PDB1 as sysdba
```


Oracle menyediakan:

```sql
SELECT name
FROM system_privilege_map
ORDER BY name;
```


Filter:

```sql
SELECT name
FROM system_privilege_map
WHERE name LIKE 'CREATE%'
ORDER BY name;
```


---

# LAB 30 — Membuat Custom Role

Role auditing juga dapat dilakukan di Unified Auditing.

Buat role:

```sql
CREATE ROLE application_operator;
```


Tambahkan privilege:

```sql
GRANT CREATE TABLE TO application_operator;
```


```sql
GRANT CREATE SEQUENCE TO application_operator;
```


Grant role:

```sql
GRANT application_operator TO app_user;
```


Oracle role auditing mencatat penggunaan system privilege yang diberikan secara langsung kepada role tersebut. ([Oracle documentation][5])

---

# LAB 31 — Berikan Quota APP_USER

Agar bisa create table:

```sql
ALTER USER app_user QUOTA UNLIMITED ON users;
```


---

# LAB 32 — Membuat Role Audit Policy

```sql
BEGIN
   EXECUTE IMMEDIATE 'NOAUDIT POLICY app_role_pol';
EXCEPTION
   WHEN OTHERS THEN NULL;
END;
/
BEGIN
   EXECUTE IMMEDIATE 'DROP AUDIT POLICY app_role_pol';
EXCEPTION
   WHEN OTHERS THEN NULL;
END;
/
```

Create:

```sql
CREATE AUDIT POLICY app_role_pol
ROLES application_operator;
```


Enable:

```sql
AUDIT POLICY app_role_pol BY app_user;
```


---

# LAB 33 — Reconnect dan Gunakan Privilege dari Role

```sql
EXIT
```

```bash
sqlplus -L app_user/Welcome1@192.168.56.26:1521/PDB1
```


Create table:

```sql
CREATE TABLE role_test (
    id NUMBER,
    notes VARCHAR2(100)
);
```


Create sequence:

```sql
CREATE SEQUENCE role_test_seq;
```


Keluar:

```sql
EXIT
```

---

# LAB 34 — Investigasi Role Auditing

```bash
sqlplus -L lab_auditor/Welcome1@192.168.56.26:1521/PDB1
```


```sql
SELECT event_timestamp,
       dbusername,
       action_name,
       object_name,
       system_privilege_used,
       unified_audit_policies
FROM unified_audit_trail
WHERE unified_audit_policies LIKE '%APP_ROLE_POL%'
ORDER BY event_timestamp;
```


---

# LAB 35 — Conditional Unified Auditing

Sekarang masuk ke fitur yang lebih advanced:

```text
Audit event
   │
   ├── action cocok?
   │
   └── condition true?
          │
          ▼
      write audit
```

Oracle AI Database 26ai mendukung:

```text
WHEN ...
EVALUATE PER STATEMENT
EVALUATE PER SESSION
EVALUATE PER INSTANCE
```

([Oracle documentation][6])

---

# LAB 36 — Membuat Conditional Policy untuk SQL*Plus

Kita akan audit login hanya jika client program mengandung `SQLPLUS`.

Login SYS:

```sql
EXIT
```

```bash
sqlplus -L sys/oracle@192.168.56.26:1521/PDB1 as sysdba
```


Cleanup:

```sql
BEGIN
   EXECUTE IMMEDIATE 'NOAUDIT POLICY sqlplus_login_pol';
EXCEPTION
   WHEN OTHERS THEN NULL;
END;
/
BEGIN
   EXECUTE IMMEDIATE 'DROP AUDIT POLICY sqlplus_login_pol';
EXCEPTION
   WHEN OTHERS THEN NULL;
END;
/
```

Create:

```sql
CREATE AUDIT POLICY sqlplus_login_pol
ACTIONS LOGON
WHEN 'INSTR(UPPER(SYS_CONTEXT(''USERENV'',''CLIENT_PROGRAM_NAME'')),''SQLPLUS'') > 0'
EVALUATE PER SESSION;
```


Ini mengikuti pola resmi Oracle untuk conditional auditing berdasarkan client program. ([Oracle documentation][6])

Enable untuk `APP_USER`:

```sql
AUDIT POLICY sqlplus_login_pol BY app_user;
```


---

# LAB 37 — Test Conditional Audit

Keluar:

```sql
EXIT
```

Login via SQL*Plus:

```bash
sqlplus -L app_user/Welcome1@192.168.56.26:1521/PDB1
```


Jalankan:

```sql
SELECT USER FROM dual;
```


Keluar:

```sql
EXIT
```

---

# LAB 38 — Investigasi Conditional Login Policy

```bash
sqlplus -L lab_auditor/Welcome1@192.168.56.26:1521/PDB1
```


```sql
SELECT event_timestamp,
       dbusername,
       action_name,
       client_program_name,
       return_code,
       unified_audit_policies
FROM unified_audit_trail
WHERE unified_audit_policies LIKE '%SQLPLUS_LOGIN_POL%'
ORDER BY event_timestamp DESC;
```


---

# LAB 39 — EVALUATE PER STATEMENT

Sekarang buat conditional audit untuk setiap statement.

Login SYS:

```sql
EXIT
```

```bash
sqlplus -L sys/oracle@192.168.56.26:1521/PDB1 as sysdba
```


Cleanup:

```sql
BEGIN
   EXECUTE IMMEDIATE 'NOAUDIT POLICY client_id_delete_pol';
EXCEPTION
   WHEN OTHERS THEN NULL;
END;
/
BEGIN
   EXECUTE IMMEDIATE 'DROP AUDIT POLICY client_id_delete_pol';
EXCEPTION
   WHEN OTHERS THEN NULL;
END;
/
```

Buat:

```sql
CREATE AUDIT POLICY client_id_delete_pol
ACTIONS DELETE ON audit_user.customers
WHEN 'SYS_CONTEXT(''USERENV'',''CLIENT_IDENTIFIER'') = ''SUSPICIOUS_USER'''
EVALUATE PER STATEMENT;
```


Enable:

```sql
AUDIT POLICY client_id_delete_pol BY audit_user;
```


---

# LAB 40 — Set CLIENT_IDENTIFIER

Reconnect:

```sql
EXIT
```

```bash
sqlplus -L audit_user/Welcome1@192.168.56.26:1521/PDB1
```


Set:

```sql
BEGIN
   DBMS_SESSION.SET_IDENTIFIER('SUSPICIOUS_USER');
END;
/
```


Verifikasi:

```sql
SELECT SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER')
FROM dual;
```


---

# LAB 41 — Generate Conditional DELETE

Tambahkan data sementara:

```sql
INSERT INTO customers
VALUES
(
  100,
  'Temporary Customer',
  'temp@example.com',
  '0800000000',
  1000000,
  'ACTIVE'
);
COMMIT;
```


Delete:

```sql
DELETE FROM customers
WHERE customer_id=100;
```


Commit:

```sql
COMMIT;
```


---

# LAB 42 — Reset Identifier

```sql
BEGIN
   DBMS_SESSION.CLEAR_IDENTIFIER;
END;
/
```


Keluar:

```sql
EXIT
```

---

# LAB 43 — Investigasi Conditional Policy

```bash
sqlplus -L lab_auditor/Welcome1@192.168.56.26:1521/PDB1
```


```sql
SELECT event_timestamp,
       dbusername,
       client_identifier,
       action_name,
       object_name,
       sql_text,
       unified_audit_policies
FROM unified_audit_trail
WHERE unified_audit_policies LIKE '%CLIENT_ID_DELETE_POL%'
ORDER BY event_timestamp DESC;
```


---

# LAB 44 — Policy EXCEPT

Kita bisa mengaudit semua user **kecuali** user tertentu.

Login SYS:

```sql
EXIT
```

```bash
sqlplus -L sys/oracle@192.168.56.26:1521/PDB1 as sysdba
```


Cleanup:

```sql
BEGIN
   EXECUTE IMMEDIATE 'NOAUDIT POLICY global_customer_read_pol';
EXCEPTION
   WHEN OTHERS THEN NULL;
END;
/
BEGIN
   EXECUTE IMMEDIATE 'DROP AUDIT POLICY global_customer_read_pol';
EXCEPTION
   WHEN OTHERS THEN NULL;
END;
/
```

Create:

```sql
CREATE AUDIT POLICY global_customer_read_pol
ACTIONS SELECT ON audit_user.customers;
```


Enable untuk semua kecuali `AUDIT_USER`:

```sql
AUDIT POLICY global_customer_read_pol
EXCEPT audit_user;
```


Oracle mendukung `EXCEPT`, tetapi satu policy tidak dapat sekaligus memakai `BY ...` dan `EXCEPT ...` dalam enablement yang sama. ([Oracle documentation][3])

---

# LAB 45 — Verifikasi EXCEPT

```sql
SELECT policy_name,
       enabled_option,
       entity_name,
       entity_type
FROM audit_unified_enabled_policies
WHERE policy_name='GLOBAL_CUSTOMER_READ_POL';
```

Periksa hasil query dan pastikan policy aktif dengan exclusion untuk `AUDIT_USER` tercermin pada metadata enablement.

---

# LAB 46 — Test EXCEPT

Test `APP_USER`:

```sql
EXIT
```

```bash
sqlplus -L app_user/Welcome1@192.168.56.26:1521/PDB1
```


```sql
SELECT customer_id, customer_name
FROM audit_user.customers;
```

Keluar:

```sql
EXIT
```

Test `AUDIT_USER`:

```bash
sqlplus -L audit_user/Welcome1@192.168.56.26:1521/PDB1
```


```sql
SELECT customer_id, customer_name
FROM customers;
```

Keluar:

```sql
EXIT
```

Secara konsep:

```text
APP_USER
   │
   └── SELECT → GLOBAL_CUSTOMER_READ_POL

AUDIT_USER
   │
   └── SELECT → excluded
```

---

# LAB 47 — Melihat Session ID Audit

Unified audit memiliki session ID sendiri.

Login:

```bash
sqlplus -L app_user/Welcome1@192.168.56.26:1521/PDB1
```


Jalankan:

```sql
SELECT SYS_CONTEXT(
         'USERENV',
         'UNIFIED_AUDIT_SESSIONID'
       ) AS audit_session_id
FROM dual;
```


Simpan nilainya.


---

# LAB 48 — Generate Beberapa Activity Dalam Session yang Sama

```sql
SELECT COUNT(*)
FROM audit_user.customers;
```

```sql
SELECT customer_name
FROM audit_user.customers
WHERE customer_id=1;
```

```sql
SELECT customer_name
FROM audit_user.customers
WHERE customer_id=2;
```

Keluar:

```sql
EXIT
```

---

# LAB 49 — Reconstruct Session

Login investigator:

```bash
sqlplus -L lab_auditor/Welcome1@192.168.56.26:1521/PDB1
```


Ganti nilai session ID sesuai hasil Anda:

```sql
SELECT sessionid AS chosen_sid
FROM unified_audit_trail
WHERE dbusername='APP_USER' AND object_name='CUSTOMERS'
ORDER BY event_timestamp DESC
FETCH FIRST 1 ROW ONLY;
```

Kemudian:

```sql
SELECT event_timestamp,
       dbusername,
       action_name,
       object_name,
       return_code,
       sql_text
FROM unified_audit_trail
WHERE sessionid=&SID_AUDIT
ORDER BY event_timestamp;
```


Sekarang Anda sudah bisa **mereconstruct chronology satu session**.

---

# LAB 50 — Session Investigation Berdasarkan User

```sql
SELECT sessionid,
       MIN(event_timestamp) first_event,
       MAX(event_timestamp) last_event,
       COUNT(*) total_events
FROM unified_audit_trail
WHERE dbusername='APP_USER'
GROUP BY sessionid
ORDER BY last_event DESC;
```


---

# LAB 51 — Mendeteksi User dengan Banyak Error

```sql
SELECT dbusername,
       COUNT(*) total_errors
FROM unified_audit_trail
WHERE return_code <> 0
GROUP BY dbusername
ORDER BY total_errors DESC;
```


---

# LAB 52 — Error Code Distribution

```sql
SELECT return_code,
       COUNT(*) total
FROM unified_audit_trail
WHERE return_code <> 0
GROUP BY return_code
ORDER BY total DESC;
```


Korelasi umum:

```text
1017 → ORA-01017 invalid username/password
942  → ORA-00942 table or view does not exist
1031 → ORA-01031 insufficient privileges
```

---

# LAB 53 — Generate ORA-01031

Policy object SELECT/failed DROP TABLE tidak mencakup CREATE USER. Sebelum simulasi,
buka sesi SYS di PDB1 dan aktifkan coverage kegagalan ini:

```sql
EXIT
```

```bash
sqlplus -L sys/oracle@192.168.56.26:1521/PDB1 as sysdba
```


```sql
CREATE AUDIT POLICY app_account_attempt_pol ACTIONS CREATE USER;
AUDIT POLICY app_account_attempt_pol BY app_user WHENEVER NOT SUCCESSFUL;
```


Login:

```sql
EXIT
```

```bash
sqlplus -L app_user/Welcome1@192.168.56.26:1521/PDB1
```


Coba:

```sql
CREATE USER hacker IDENTIFIED BY hacker;
```


Keluar:

```sql
EXIT
```

---

# LAB 54 — Investigasi Access Violation

```bash
sqlplus -L lab_auditor/Welcome1@192.168.56.26:1521/PDB1
```


```sql
SELECT event_timestamp,
       dbusername,
       action_name,
       return_code,
       sql_text
FROM unified_audit_trail
WHERE dbusername='APP_USER'
AND return_code <> 0
ORDER BY event_timestamp DESC;
```

Tergantung policy yang aktif, Anda dapat menemukan aktivitas failed yang tercapture.

---

# LAB 55 — Siapa Mengakses Object Paling Banyak?

```sql
SELECT dbusername,
       object_schema,
       object_name,
       COUNT(*) total_access
FROM unified_audit_trail
WHERE object_name IS NOT NULL
GROUP BY dbusername,
         object_schema,
         object_name
ORDER BY total_access DESC;
```


---

# LAB 56 — Who Did What?

```sql
SELECT dbusername,
       action_name,
       COUNT(*) total
FROM unified_audit_trail
WHERE dbusername IN
(
 'AUDIT_USER',
 'APP_USER',
 'SECURITY_OPS'
)
GROUP BY dbusername,
         action_name
ORDER BY dbusername,
         total DESC;
```

---

# LAB 57 — Successful vs Failed per User

```sql
SELECT dbusername,
       CASE
          WHEN return_code=0 THEN 'SUCCESS'
          ELSE 'FAILED'
       END status,
       COUNT(*) total
FROM unified_audit_trail
WHERE dbusername IN
(
 'AUDIT_USER',
 'APP_USER',
 'SECURITY_OPS'
)
GROUP BY
       dbusername,
       CASE
          WHEN return_code=0 THEN 'SUCCESS'
          ELSE 'FAILED'
       END
ORDER BY dbusername, status;
```


---

# LAB 58 — Audit Events Dalam 15 Menit Terakhir

```sql
SELECT event_timestamp,
       dbusername,
       action_name,
       object_schema,
       object_name,
       return_code
FROM unified_audit_trail
WHERE event_timestamp >=
      SYSTIMESTAMP - INTERVAL '15' MINUTE
ORDER BY event_timestamp DESC;
```

Ini praktis untuk incident seperti:

> "Ada aktivitas mencurigakan sekitar 10 menit lalu."

---

# LAB 59 — Melihat Source Host

```sql
SELECT dbusername,
       userhost,
       COUNT(*) total_events
FROM unified_audit_trail
WHERE dbusername IS NOT NULL
GROUP BY dbusername,
         userhost
ORDER BY total_events DESC;
```

---

# LAB 60 — Melihat Client Program

```sql
SELECT dbusername,
       client_program_name,
       COUNT(*) total_events
FROM unified_audit_trail
WHERE dbusername IS NOT NULL
GROUP BY dbusername,
         client_program_name
ORDER BY total_events DESC;
```

---

# LAB 61 — Melihat CLIENT_IDENTIFIER

```sql
SELECT event_timestamp,
       dbusername,
       client_identifier,
       action_name,
       object_name
FROM unified_audit_trail
WHERE client_identifier IS NOT NULL
ORDER BY event_timestamp DESC;
```


---

# LAB 62 — Melihat SQL_TEXT

```sql
SELECT event_timestamp,
       dbusername,
       action_name,
       sql_text
FROM unified_audit_trail
WHERE dbusername IN ('AUDIT_USER','APP_USER','SECURITY_OPS')
AND sql_text IS NOT NULL
ORDER BY event_timestamp DESC
FETCH FIRST 30 ROWS ONLY;
```

---

# LAB 63 — Mencari SQL yang Mengandung DELETE

```sql
SELECT event_timestamp,
       dbusername,
       object_schema,
       object_name,
       sql_text
FROM unified_audit_trail
WHERE UPPER(sql_text) LIKE '%DELETE%'
ORDER BY event_timestamp DESC;
```

---

# LAB 64 — Mencari SQL yang Mengandung DROP

```sql
SELECT event_timestamp,
       dbusername,
       action_name,
       object_name,
       return_code,
       sql_text
FROM unified_audit_trail
WHERE UPPER(sql_text) LIKE '%DROP%'
ORDER BY event_timestamp DESC;
```

---

# LAB 65 — Mencari Failed Authentication

```sql
SELECT event_timestamp,
       dbusername,
       userhost,
       client_program_name,
       return_code
FROM unified_audit_trail
WHERE action_name='LOGON'
AND return_code <> 0
ORDER BY event_timestamp DESC;
```

---

# LAB 66 — Mencari Repeated Login Failure

```sql
SELECT dbusername,
       userhost,
       COUNT(*) failed_logins
FROM unified_audit_trail
WHERE action_name='LOGON'
AND return_code <> 0
GROUP BY dbusername,
         userhost
HAVING COUNT(*) >= 2
ORDER BY failed_logins DESC;
```

Ini sudah mulai mendekati sederhana:

```text
Brute-force detection
```

---

# LAB 67 — Audit Policy Health Check

Login SYS:

```sql
EXIT
```

```bash
sqlplus -L sys/oracle@192.168.56.26:1521/PDB1 as sysdba
```


Policy definitions:

```sql
SELECT DISTINCT policy_name
FROM audit_unified_policies
ORDER BY policy_name;
```

Enabled policies:

```sql
SELECT policy_name,
       enabled_option,
       entity_name
FROM audit_unified_enabled_policies
ORDER BY policy_name,
         entity_name;
```

---

# LAB 68 — Menampilkan Semua Policy Handson 2

```sql
SELECT DISTINCT policy_name
FROM audit_unified_policies
WHERE policy_name IN
(
 'CUSTOMERS_SELECT_POL',
 'SUCCESSFUL_SELECT_POL',
 'FAILED_DDL_POL',
 'SECURITY_OPS_PRIV_POL',
 'APP_ROLE_POL',
 'SQLPLUS_LOGIN_POL',
 'CLIENT_ID_DELETE_POL',
 'GLOBAL_CUSTOMER_READ_POL'
)
ORDER BY policy_name;
```


---

# LAB 69 — Melihat Detail Policy Handson 2

```sql
SELECT policy_name,
       audit_option,
       audit_option_type,
       object_schema,
       object_name
FROM audit_unified_policies
WHERE policy_name IN
(
 'CUSTOMERS_SELECT_POL',
 'SUCCESSFUL_SELECT_POL',
 'FAILED_DDL_POL',
 'SECURITY_OPS_PRIV_POL',
 'APP_ROLE_POL',
 'SQLPLUS_LOGIN_POL',
 'CLIENT_ID_DELETE_POL',
 'GLOBAL_CUSTOMER_READ_POL'
)
ORDER BY policy_name,
         audit_option;
```

---

# LAB 70 — Audit Policy Matrix

Secara konseptual sekarang kita mempunyai:

```text
+--------------------------+-----------------------+
| POLICY                   | PURPOSE               |
+--------------------------+-----------------------+
| CUSTOMERS_SELECT_POL     | Object SELECT         |
| SUCCESSFUL_SELECT_POL    | Successful only       |
| FAILED_DDL_POL           | Failed only           |
| SECURITY_OPS_PRIV_POL    | System privileges     |
| APP_ROLE_POL             | Role privileges       |
| SQLPLUS_LOGIN_POL        | Conditional login     |
| CLIENT_ID_DELETE_POL     | Conditional DML       |
| GLOBAL_CUSTOMER_READ_POL | EXCEPT user           |
+--------------------------+-----------------------+
```

---

# LAB 71 — Incident Simulation

Sekarang kita buat mini security incident.

Scenario:

```text
APP_USER
   │
   ├── reads CUSTOMERS
   ├── tries unauthorized operation
   └── creates object through role

AUDIT_USER
   │
   ├── sets suspicious CLIENT_IDENTIFIER
   └── deletes customer

SECURITY_OPS
   │
   ├── creates table
   └── creates sequence
```

---

# LAB 72 — Generate APP_USER Activity

Kembali ke shell terlebih dahulu:

```sql
EXIT
```

```bash
sqlplus -L app_user/Welcome1@192.168.56.26:1521/PDB1
```


```sql
SELECT *
FROM audit_user.customers;
```

```sql
CREATE TABLE incident_table (
    id NUMBER,
    notes VARCHAR2(100)
);
```

```sql
DROP TABLE table_does_not_exist PURGE;
```


Keluar:

```sql
EXIT
```

---

# LAB 73 — Generate AUDIT_USER Activity

```bash
sqlplus -L audit_user/Welcome1@192.168.56.26:1521/PDB1
```


Set identifier:

```sql
BEGIN
  DBMS_SESSION.SET_IDENTIFIER('SUSPICIOUS_USER');
END;
/
```

Insert:

```sql
INSERT INTO customers
VALUES
(
  200,
  'Incident Customer',
  'incident@example.com',
  '0899999999',
  1000000,
  'ACTIVE'
);
COMMIT;
```

Delete:

```sql
DELETE FROM customers
WHERE customer_id=200;
COMMIT;
```

Keluar:

```sql
EXIT
```

---

# LAB 74 — Generate SECURITY_OPS Activity

```bash
sqlplus -L security_ops/Welcome1@192.168.56.26:1521/PDB1
```


```sql
CREATE TABLE incident_security_table (
    id NUMBER
);
```


```sql
CREATE SEQUENCE incident_security_seq;
```


Keluar:

```sql
EXIT
```

---

# LAB 75 — Security Investigator Report

Login:

```bash
sqlplus -L lab_auditor/Welcome1@192.168.56.26:1521/PDB1
```


Jalankan:

```sql
SELECT event_timestamp,
       dbusername,
       action_name,
       object_name,
       client_identifier,
       return_code,
       sql_text
FROM unified_audit_trail
WHERE dbusername IN
(
 'AUDIT_USER',
 'APP_USER',
 'SECURITY_OPS'
)
AND event_timestamp >=
    SYSTIMESTAMP - INTERVAL '30' MINUTE
ORDER BY event_timestamp;
```


---

# LAB 76 — High-Risk Event Report

```sql
SELECT event_timestamp,
       dbusername,
       action_name,
       object_schema,
       object_name,
       return_code
FROM unified_audit_trail
WHERE action_name IN
(
 'DROP TABLE',
 'CREATE USER',
 'ALTER USER',
 'DROP USER',
 'DELETE',
 'CREATE TABLE'
)
ORDER BY event_timestamp DESC;
```

---

# LAB 77 — Suspicious Failed Activity Report

```sql
SELECT event_timestamp,
       dbusername,
       userhost,
       action_name,
       object_name,
       return_code
FROM unified_audit_trail
WHERE return_code <> 0
ORDER BY event_timestamp DESC;
```

---

# LAB 78 — User Risk Summary

```sql
SELECT dbusername,
       COUNT(*) total_events,
       SUM(
         CASE
            WHEN return_code <> 0 THEN 1
            ELSE 0
         END
       ) failed_events,
       SUM(
         CASE
            WHEN action_name IN
                 ('DELETE','DROP TABLE','CREATE USER','DROP USER')
            THEN 1
            ELSE 0
         END
       ) high_risk_events
FROM unified_audit_trail
WHERE dbusername IN
(
 'AUDIT_USER',
 'APP_USER',
 'SECURITY_OPS'
)
GROUP BY dbusername
ORDER BY high_risk_events DESC,
         failed_events DESC;
```


---

# LAB 79 — Mengetahui Policy Penyebab Audit Record

Ini sangat berguna jika satu object mempunyai banyak policy.

```sql
SELECT event_timestamp,
       dbusername,
       action_name,
       object_name,
       unified_audit_policies
FROM unified_audit_trail
WHERE dbusername IN
(
 'AUDIT_USER',
 'APP_USER',
 'SECURITY_OPS'
)
AND unified_audit_policies IS NOT NULL
ORDER BY event_timestamp DESC
FETCH FIRST 50 ROWS ONLY;
```

Satu event bahkan dapat berhubungan dengan beberapa policy.

---

# LAB 80 — Final Challenge Handson 2

Anggap SOC memberikan informasi:

> Antara 15 menit terakhir terdapat user yang mengakses customer data, melakukan DDL, dan ada beberapa operasi gagal.

Tugas investigator:

### Pertanyaan 1 — Siapa user paling aktif?

```sql
SELECT dbusername,
       COUNT(*) total
FROM unified_audit_trail
WHERE event_timestamp >=
      SYSTIMESTAMP - INTERVAL '15' MINUTE
GROUP BY dbusername
ORDER BY total DESC;
```

### Pertanyaan 2 — Siapa mengalami error?

```sql
SELECT dbusername,
       return_code,
       COUNT(*) total
FROM unified_audit_trail
WHERE event_timestamp >=
      SYSTIMESTAMP - INTERVAL '15' MINUTE
AND return_code <> 0
GROUP BY dbusername,
         return_code
ORDER BY total DESC;
```

### Pertanyaan 3 — Siapa mengakses CUSTOMERS?

```sql
SELECT event_timestamp,
       dbusername,
       action_name,
       sql_text
FROM unified_audit_trail
WHERE object_schema='AUDIT_USER'
AND object_name='CUSTOMERS'
AND event_timestamp >=
    SYSTIMESTAMP - INTERVAL '15' MINUTE
ORDER BY event_timestamp;
```

### Pertanyaan 4 — Siapa membuat object?

```sql
SELECT event_timestamp,
       dbusername,
       action_name,
       object_name,
       system_privilege_used
FROM unified_audit_trail
WHERE action_name IN
(
 'CREATE TABLE',
 'CREATE SEQUENCE'
)
AND event_timestamp >=
    SYSTIMESTAMP - INTERVAL '15' MINUTE
ORDER BY event_timestamp;
```

### Pertanyaan 5 — Apakah ada CLIENT_IDENTIFIER mencurigakan?

```sql
SELECT event_timestamp,
       dbusername,
       client_identifier,
       action_name,
       object_name
FROM unified_audit_trail
WHERE client_identifier IS NOT NULL
AND event_timestamp >=
    SYSTIMESTAMP - INTERVAL '15' MINUTE
ORDER BY event_timestamp;
```


---

# LAB 81 — Final Audit Architecture

Setelah Handson 2, Anda seharusnya memahami:

```text
                        USER ACTIVITY
                             │
              ┌──────────────┼──────────────┐
              │              │              │
              ▼              ▼              ▼
          OBJECT          SYSTEM          ROLE
          ACTION         PRIVILEGE      PRIVILEGE
              │              │              │
              └──────────────┼──────────────┘
                             │
                    UNIFIED AUDIT POLICY
                             │
                ┌────────────┼────────────┐
                │            │            │
                ▼            ▼            ▼
              USER        CONDITION     RESULT
                │            │            │
             BY USER      WHEN ...     SUCCESS
             EXCEPT       EVALUATE     FAILURE
                │            │            │
                └────────────┼────────────┘
                             │
                             ▼
                    UNIFIED_AUDIT_TRAIL
                             │
        ┌────────────────────┼─────────────────────┐
        ▼                    ▼                     ▼
      WHO?                 WHAT?                  WHEN?
   DBUSERNAME           ACTION_NAME          EVENT_TIMESTAMP
        │                    │
        ▼                    ▼
      WHERE?               HOW?
     USERHOST            SQL_TEXT
        │                    │
        └──────────┬─────────┘
                   ▼
              SUCCESS/FAIL
              RETURN_CODE
```

---

# Handson 2 Cheat Sheet

Bagian ini referensi sintaks; ganti placeholder schema, tabel, policy, dan user sebelum memakai contoh. Bukan langkah lanjutan yang dijalankan berurutan.

Membuat object policy:

```sql
CREATE AUDIT POLICY my_policy
ACTIONS SELECT ON schema.table_name;
```

Enable semua user:

```sql
AUDIT POLICY my_policy;
```

Enable user tertentu:

```sql
AUDIT POLICY my_policy BY username;
```

Exclude user:

```sql
AUDIT POLICY my_policy EXCEPT username;
```

Successful only:

```sql
AUDIT POLICY my_policy
BY username
WHENEVER SUCCESSFUL;
```

Failed only:

```sql
AUDIT POLICY my_policy
BY username
WHENEVER NOT SUCCESSFUL;
```

System privilege auditing:

```sql
CREATE AUDIT POLICY my_priv_policy
PRIVILEGES CREATE TABLE, CREATE SEQUENCE;
```

Role auditing:

```sql
CREATE AUDIT POLICY my_role_policy
ROLES role_name;
```

Conditional auditing:

```sql
CREATE AUDIT POLICY my_conditional_policy
ACTIONS DELETE ON schema.table_name
WHEN 'SYS_CONTEXT(''USERENV'',''CLIENT_IDENTIFIER'') = ''SUSPICIOUS_USER'''
EVALUATE PER STATEMENT;
```

Disable:

```sql
NOAUDIT POLICY my_policy;
```

Drop:

```sql
DROP AUDIT POLICY my_policy;
```

Policy definition:

```sql
SELECT *
FROM audit_unified_policies;
```

Enabled policies:

```sql
SELECT *
FROM audit_unified_enabled_policies;
```

Audit events:

```sql
SELECT event_timestamp,
       dbusername,
       action_name,
       object_schema,
       object_name,
       return_code,
       unified_audit_policies
FROM unified_audit_trail
ORDER BY event_timestamp DESC;
```

---
