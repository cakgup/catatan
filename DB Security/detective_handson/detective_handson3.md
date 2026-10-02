# Handson 3 —  Fine-Grained Auditing



Jalankan berurutan setelah Day 2. Formatting SQL*Plus cukup diambil dari Day 1
Lab 1.2 dan tidak ditampilkan ulang sebelum setiap query.


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

Alur Day 3:

```text
DAY 1
Basic Unified Auditing
        │
        ▼
DAY 2
Advanced Unified Auditing
        │
        ▼
DAY 3
Fine-Grained Auditing
        │
        ├── DBMS_FGA
        ├── audit_condition
        ├── audit_column
        ├── statement_types
        ├── ANY_COLUMNS
        ├── ALL_COLUMNS
        ├── enable / disable
        ├── handler_module
        ├── SQL_TEXT
        ├── SQL_BINDS
        └── Security Investigation
```

---

# LAB 1 — Persiapan Environment

Login sebagai user OS `oracle`.

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

# LAB 2 — Login Database

```bash
sqlplus -L "sys/oracle@192.168.56.26:1521/PDB1 as sysdba"
```


Muat kembali format SQL*Plus yang sudah dibuat pada Day 1 agar kolom audit lebih mudah dibaca:

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

# LAB 3 — Verifikasi Environment Day 1–2

Periksa user:

```sql
SELECT username,
       account_status
FROM dba_users
WHERE username IN
(
 'AUDIT_USER',
 'LAB_AUDITOR',
 'APP_USER',
 'SECURITY_OPS'
)
ORDER BY username;
```


---

# LAB 4 — Verifikasi CUSTOMERS

```sql
SELECT customer_id,
       customer_name,
       credit_limit,
       status
FROM audit_user.customers
ORDER BY customer_id;
```


---

## 4.1 Sumber audit untuk pure unified auditing — wajib sebelum Lab 5

Pada VM pure unified ini, FGA dan custom unified policies berada langsung di
`UNIFIED_AUDIT_TRAIL`. Tidak ada compatibility view tambahan yang perlu dibuat.

`LAB_AUDITOR` yang sudah memiliki role `AUDIT_VIEWER` dapat membaca
`UNIFIED_AUDIT_TRAIL` secara langsung.
`AUDIT_SOURCE` bernilai `UNIFIED`; `FGA_POLICY_NAME` membedakan event FGA dari
custom unified policy biasa. SQL_TEXT dibatasi 4.000 karakter dan NUL dibuang
agar tampilan mudah dibaca.



---

# LAB 5 — Unified Auditing vs FGA

Unified audit policy cocok untuk pertanyaan:

```text
Apakah user SELECT tabel CUSTOMERS?
Apakah user melakukan UPDATE?
Apakah user menggunakan CREATE TABLE?
```

FGA lebih cocok untuk:

```text
Apakah user membaca CREDIT_LIMIT?

Apakah user membaca customer
dengan CREDIT_LIMIT > 20 juta?

Apakah user melakukan UPDATE
terhadap kolom sensitif?

Apakah SQL tertentu memenuhi
kondisi security tertentu?
```

Oracle menyarankan FGA ketika Anda ingin audit berdasarkan **kolom tertentu**, **row/value tertentu**, atau menggunakan **event handler**. ([Oracle Documentation][1])

---

# LAB 6 — Mengenal DBMS_FGA

Oracle menyediakan package:

```text
DBMS_FGA
```

Subprogram utama:

```text
DBMS_FGA.ADD_POLICY
DBMS_FGA.ENABLE_POLICY
DBMS_FGA.DISABLE_POLICY
DBMS_FGA.DROP_POLICY
```

([Oracle Documentation][1])

Lihat package:

```sql
DESC DBMS_FGA
```

Daftar subprogram package cukup panjang. Untuk lab ini, fokus pada procedure berikut:

```text
PROCEDURE ADD_POLICY
PROCEDURE DROP_POLICY
PROCEDURE ENABLE_POLICY
PROCEDURE DISABLE_POLICY
```

---

# LAB 7 — Struktur ADD_POLICY

Struktur dasar:

```sql
BEGIN
  DBMS_FGA.ADD_POLICY(
      object_schema   => 'SCHEMA',
      object_name     => 'TABLE',
      policy_name     => 'POLICY_NAME',
      audit_condition => 'CONDITION',
      audit_column    => 'COLUMN',
      statement_types => 'SELECT'
  );
END;
/
```

Parameter yang akan sering digunakan:

```text
OBJECT_SCHEMA
OBJECT_NAME
POLICY_NAME
AUDIT_CONDITION
AUDIT_COLUMN
STATEMENT_TYPES
AUDIT_COLUMN_OPTS
HANDLER_SCHEMA
HANDLER_MODULE
ENABLE
```

Oracle mendukung `SELECT`, `INSERT`, `UPDATE`, dan `DELETE` pada `statement_types`. ([Oracle Documentation][1])

---

# LAB 8 — Policy FGA Pertama

Scenario:

> Audit setiap kali user membaca kolom `CREDIT_LIMIT`.

Cleanup jika policy pernah dibuat:

```sql
BEGIN
  DBMS_FGA.DROP_POLICY(
      object_schema => 'AUDIT_USER',
      object_name   => 'CUSTOMERS',
      policy_name   => 'FGA_CREDIT_LIMIT'
  );
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -28102 THEN
      RAISE;
    END IF;
END;
/
```

Buat policy:

```sql
BEGIN
  DBMS_FGA.ADD_POLICY(
      object_schema   => 'AUDIT_USER',
      object_name     => 'CUSTOMERS',
      policy_name     => 'FGA_CREDIT_LIMIT',
      audit_condition => NULL,
      audit_column    => 'CREDIT_LIMIT',
      statement_types => 'SELECT'
  );
END;
/
```


Policy otomatis enabled karena default `enable => TRUE`. ([Oracle Documentation][1])

---

# LAB 9 — Melihat FGA Policy

Gunakan:

```sql
SELECT object_schema,
       object_name,
       policy_name,
       policy_text,
       policy_column,
       enabled
FROM dba_audit_policies
WHERE object_schema='AUDIT_USER'
AND object_name='CUSTOMERS';
```


---

# LAB 10 — Test SELECT Tanpa CREDIT_LIMIT

Keluar:

```sql
EXIT
```

Login:

```bash
sqlplus -L app_user/Welcome1@192.168.56.26:1521/PDB1
```


Query:

```sql
SELECT customer_id,
       customer_name
FROM audit_user.customers;
```


Karena query tidak mereferensikan `CREDIT_LIMIT`, policy FGA ini seharusnya **tidak triggered**.

---

# LAB 11 — Test SELECT CREDIT_LIMIT

```sql
SELECT customer_id,
       customer_name,
       credit_limit
FROM audit_user.customers;
```


Policy sekarang triggered.

Keluar:

```sql
EXIT
```

---

# LAB 12 — Investigasi FGA

Login:

```bash
sqlplus -L lab_auditor/Welcome1@192.168.56.26:1521/PDB1
```


Muat format SQL*Plus Day 1 sebelum menjalankan query investigasi agar kolom audit tetap rapi:

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
       fga_policy_name,
       return_code
FROM unified_audit_trail
WHERE fga_policy_name='FGA_CREDIT_LIMIT'
ORDER BY event_timestamp;
```


Pada VM pure unified auditing ini, record FGA dibaca langsung dari `UNIFIED_AUDIT_TRAIL`. Kolom `FGA_POLICY_NAME` digunakan untuk mengidentifikasi event yang berasal dari Fine-Grained Auditing. ([Oracle Documentation][2])

---

# LAB 13 — Melihat SQL_TEXT

```sql
SELECT event_timestamp,
       dbusername,
       fga_policy_name,
       sql_text
FROM unified_audit_trail
WHERE fga_policy_name='FGA_CREDIT_LIMIT'
ORDER BY event_timestamp DESC;
```


---

# LAB 14 — Value-Based Auditing

Sekarang requirement:

> Audit hanya jika user membaca customer yang mempunyai `CREDIT_LIMIT > 20000000`.

Policy lama kita disable terlebih dahulu:

```sql
EXIT
```

```bash
sqlplus -L sys/oracle@192.168.56.26:1521/PDB1 as sysdba
```


```sql
BEGIN
  DBMS_FGA.DISABLE_POLICY(
      object_schema => 'AUDIT_USER',
      object_name   => 'CUSTOMERS',
      policy_name   => 'FGA_CREDIT_LIMIT'
  );
END;
/
```


---

# LAB 15 — Membuat High Credit Policy

```sql
BEGIN
  DBMS_FGA.ADD_POLICY(
      object_schema   => 'AUDIT_USER',
      object_name     => 'CUSTOMERS',
      policy_name     => 'FGA_HIGH_CREDIT',
      audit_condition => 'CREDIT_LIMIT > 20000000',
      audit_column    => 'CREDIT_LIMIT',
      statement_types => 'SELECT'
  );
END;
/
```


---

# LAB 16 — Verifikasi Policy

```sql
SELECT policy_name,
       policy_text,
       policy_column,
       enabled
FROM dba_audit_policies
WHERE object_schema='AUDIT_USER'
AND object_name='CUSTOMERS'
ORDER BY policy_name;
```


---

# LAB 17 — Query yang Tidak Memenuhi Condition

Login:

```sql
EXIT
```

```bash
sqlplus -L app_user/Welcome1@192.168.56.26:1521/PDB1
```


Query:

```sql
SELECT customer_id,
       customer_name,
       credit_limit
FROM audit_user.customers
WHERE customer_id=1;
```


Karena:

```text
12000000 < 20000000
```

maka tidak seharusnya ada event `FGA_HIGH_CREDIT`.

---

# LAB 18 — Query yang Memenuhi Condition

```sql
SELECT customer_id,
       customer_name,
       credit_limit
FROM audit_user.customers
WHERE customer_id=2;
```


Policy triggered.

Test customer lain:

```sql
SELECT customer_id,
       customer_name,
       credit_limit
FROM audit_user.customers
WHERE customer_id=4;
```


Policy juga triggered.

---

# LAB 19 — Investigasi Value-Based Audit

```sql
EXIT
```

```bash
sqlplus -L lab_auditor/Welcome1@192.168.56.26:1521/PDB1
```


```sql
SELECT event_timestamp,
       dbusername,
       action_name,
       fga_policy_name,
       object_name,
       sql_text
FROM unified_audit_trail
WHERE fga_policy_name='FGA_HIGH_CREDIT'
ORDER BY event_timestamp;
```

Query terhadap customer 1 seharusnya tidak menghasilkan event policy tersebut.

---

# LAB 20 — FGA Berdasarkan Kolom EMAIL

Sekarang requirement:

> EMAIL merupakan PII. Audit setiap pembacaan EMAIL.

Login SYS:

```sql
EXIT
```

```bash
sqlplus -L sys/oracle@192.168.56.26:1521/PDB1 as sysdba
```


Create:

```sql
BEGIN
  DBMS_FGA.ADD_POLICY(
      object_schema   => 'AUDIT_USER',
      object_name     => 'CUSTOMERS',
      policy_name     => 'FGA_EMAIL_ACCESS',
      audit_condition => NULL,
      audit_column    => 'EMAIL',
      statement_types => 'SELECT'
  );
END;
/
```


---

# LAB 21 — Test  Access

```sql
EXIT
```

```bash
sqlplus -L app_user/Welcome1@192.168.56.26:1521/PDB1
```


Query biasa:

```sql
SELECT customer_id,
       customer_name
FROM audit_user.customers;
```

Tidak memicu `FGA_EMAIL_ACCESS`.

Sekarang:

```sql
SELECT customer_id,
       customer_name,
       email
FROM audit_user.customers;
```


Policy triggered.

---

# LAB 22 — Multiple Sensitive Columns

Requirement:

> Audit jika user membaca `EMAIL` atau `PHONE`.

Buat policy.

```sql
EXIT
```

```bash
sqlplus -L sys/oracle@192.168.56.26:1521/PDB1 as sysdba
```


```sql
BEGIN
  DBMS_FGA.ADD_POLICY(
      object_schema      => 'AUDIT_USER',
      object_name        => 'CUSTOMERS',
      policy_name        => 'FGA_CONTACT_INFO',
      audit_column       => 'EMAIL,PHONE',
      statement_types    => 'SELECT',
      audit_column_opts  => DBMS_FGA.ANY_COLUMNS
  );
END;
/
```


---

# LAB 23 — ANY_COLUMNS

`ANY_COLUMNS` berarti:

```text
EMAIL accessed
      OR
PHONE accessed
      │
      ▼
AUDIT
```

Test EMAIL:

```sql
EXIT
```

```bash
sqlplus -L app_user/Welcome1@192.168.56.26:1521/PDB1
```


```sql
SELECT email
FROM audit_user.customers;
```

Policy triggered.

Test PHONE:

```sql
SELECT phone
FROM audit_user.customers;
```

Policy juga triggered.

Test bukan keduanya:

```sql
SELECT customer_name
FROM audit_user.customers;
```

Tidak triggered oleh `FGA_CONTACT_INFO`.

---

# LAB 24 — ALL_COLUMNS

Sekarang kita ingin:

> Audit hanya bila **EMAIL dan PHONE** sama-sama diakses.

Login SYS:

```sql
EXIT
```

```bash
sqlplus -L sys/oracle@192.168.56.26:1521/PDB1 as sysdba
```


Buat:

```sql
BEGIN
  DBMS_FGA.ADD_POLICY(
      object_schema      => 'AUDIT_USER',
      object_name        => 'CUSTOMERS',
      policy_name        => 'FGA_ALL_CONTACT',
      audit_column       => 'EMAIL,PHONE',
      statement_types    => 'SELECT',
      audit_column_opts  => DBMS_FGA.ALL_COLUMNS
  );
END;
/
```


Oracle menggunakan `audit_column_opts` untuk menentukan apakah cukup salah satu kolom atau seluruh kolom yang ditentukan harus direferensikan. ([Oracle Documentation][1])

---

# LAB 25 — Test ALL_COLUMNS

Login:

```sql
EXIT
```

```bash
sqlplus -L app_user/Welcome1@192.168.56.26:1521/PDB1
```


Hanya EMAIL:

```sql
SELECT email
FROM audit_user.customers;
```

`FGA_ALL_CONTACT` tidak triggered.

Hanya PHONE:

```sql
SELECT phone
FROM audit_user.customers;
```

Tidak triggered.

EMAIL + PHONE:

```sql
SELECT email,
       phone
FROM audit_user.customers;
```


`FGA_ALL_CONTACT` triggered.

---

# LAB 26 — Membandingkan ANY_COLUMNS dan ALL_COLUMNS

Investigator:

```sql
EXIT
```

```bash
sqlplus -L lab_auditor/Welcome1@192.168.56.26:1521/PDB1
```


```sql
SELECT event_timestamp,
       fga_policy_name,
       dbusername,
       sql_text
FROM unified_audit_trail
WHERE fga_policy_name IN
(
 'FGA_CONTACT_INFO',
 'FGA_ALL_CONTACT'
)
ORDER BY event_timestamp;
```

Anda akan melihat pola:

```text
SELECT EMAIL
    → FGA_CONTACT_INFO

SELECT PHONE
    → FGA_CONTACT_INFO

SELECT EMAIL, PHONE
    → FGA_CONTACT_INFO
    → FGA_ALL_CONTACT
```

---

# LAB 27 — FGA untuk UPDATE

FGA tidak hanya untuk SELECT.

Kita buat policy:

> Audit ketika `CREDIT_LIMIT` di-update.

Login SYS:

```sql
EXIT
```

```bash
sqlplus -L sys/oracle@192.168.56.26:1521/PDB1 as sysdba
```


Create:

```sql
BEGIN
  DBMS_FGA.ADD_POLICY(
      object_schema   => 'AUDIT_USER',
      object_name     => 'CUSTOMERS',
      policy_name     => 'FGA_UPDATE_CREDIT',
      audit_condition => NULL,
      audit_column    => 'CREDIT_LIMIT',
      statement_types => 'UPDATE'
  );
END;
/
```


---

# LAB 28 — Generate UPDATE

Login owner:

```sql
EXIT
```

```bash
sqlplus -L audit_user/Welcome1@192.168.56.26:1521/PDB1
```


Update kolom STATUS:

```sql
UPDATE customers
SET status = 'INACTIVE'
WHERE customer_id=1;
ROLLBACK;
```


Policy `FGA_UPDATE_CREDIT` tidak seharusnya triggered.

Sekarang:

```sql
UPDATE customers
SET credit_limit = 13000000
WHERE customer_id=1;
COMMIT;
```


Policy triggered.

---

# LAB 29 — Investigasi UPDATE

```sql
EXIT
```

```bash
sqlplus -L lab_auditor/Welcome1@192.168.56.26:1521/PDB1
```


```sql
SELECT event_timestamp,
       dbusername,
       action_name,
       object_name,
       fga_policy_name,
       sql_text
FROM unified_audit_trail
WHERE fga_policy_name='FGA_UPDATE_CREDIT'
ORDER BY event_timestamp DESC;
```


---

# LAB 30 — Audit UPDATE Berdasarkan Nilai

Requirement:

> Audit perubahan customer yang memiliki credit limit lebih dari 50 juta.

Login SYS:

```sql
EXIT
```

```bash
sqlplus -L sys/oracle@192.168.56.26:1521/PDB1 as sysdba
```


Create:

```sql
BEGIN
  DBMS_FGA.ADD_POLICY(
      object_schema   => 'AUDIT_USER',
      object_name     => 'CUSTOMERS',
      policy_name     => 'FGA_HIGH_VALUE_UPDATE',
      audit_condition => 'CREDIT_LIMIT > 50000000',
      audit_column    => 'CREDIT_LIMIT',
      statement_types => 'UPDATE'
  );
END;
/
```


---

# LAB 31 — Test High-Value UPDATE

Login:

```sql
EXIT
```

```bash
sqlplus -L audit_user/Welcome1@192.168.56.26:1521/PDB1
```


Customer 1:

```sql
UPDATE customers
SET credit_limit = 14000000
WHERE customer_id=1;
COMMIT;
```

Tidak memenuhi condition.

Customer 4:

```sql
UPDATE customers
SET credit_limit = 95000000
WHERE customer_id=4;
COMMIT;
```


Policy high-value akan triggered pada row yang memenuhi condition.

---

# LAB 32 — Audit DELETE

Buat data test:

```sql
INSERT INTO customers
VALUES
(
  300,
  'Delete Test',
  'delete@example.com',
  '0800300300',
  30000000,
  'ACTIVE'
);
COMMIT;
```


Login SYS:

```sql
EXIT
```

```bash
sqlplus -L sys/oracle@192.168.56.26:1521/PDB1 as sysdba
```


Create policy:

```sql
BEGIN
  DBMS_FGA.ADD_POLICY(
      object_schema   => 'AUDIT_USER',
      object_name     => 'CUSTOMERS',
      policy_name     => 'FGA_DELETE_HIGH_VALUE',
      audit_condition => 'CREDIT_LIMIT >= 20000000',
      statement_types => 'DELETE'
  );
END;
/
```


---

# LAB 33 — Test DELETE

```sql
EXIT
```

```bash
sqlplus -L audit_user/Welcome1@192.168.56.26:1521/PDB1
```


```sql
DELETE FROM customers
WHERE customer_id=300;
COMMIT;
```


Policy triggered karena:

```text
CREDIT_LIMIT = 30000000
```

---

# LAB 34 — Multiple Statement Types

Oracle memungkinkan:

```text
SELECT
INSERT
UPDATE
DELETE
```



Buat tabel khusus.

```sql
CREATE TABLE sensitive_accounts (
    account_id      NUMBER PRIMARY KEY,
    customer_name   VARCHAR2(100),
    account_balance NUMBER(15,2),
    account_status  VARCHAR2(20)
);
```


Data:

```sql
INSERT INTO sensitive_accounts
VALUES (1,'Budi Santoso',100000000,'ACTIVE');
INSERT INTO sensitive_accounts
VALUES (2,'Siti Aminah',250000000,'ACTIVE');
COMMIT;
```


---

# LAB 35 — Policy Multi-Statement

Login SYS:

```sql
EXIT
```

```bash
sqlplus -L sys/oracle@192.168.56.26:1521/PDB1 as sysdba
```


```sql
BEGIN
  DBMS_FGA.ADD_POLICY(
      object_schema   => 'AUDIT_USER',
      object_name     => 'SENSITIVE_ACCOUNTS',
      policy_name     => 'FGA_ACCOUNT_ACTIVITY',
      audit_condition => 'ACCOUNT_BALANCE >= 100000000',
      audit_column    => 'ACCOUNT_BALANCE',
      statement_types => 'SELECT,UPDATE,DELETE'
  );
END;
/
```


---

# LAB 36 — Grant APP_USER Access

```sql
GRANT SELECT ON audit_user.sensitive_accounts TO app_user;
```


---

# LAB 37 — Test SELECT

```sql
EXIT
```

```bash
sqlplus -L app_user/Welcome1@192.168.56.26:1521/PDB1
```


```sql
SELECT account_id,
       customer_name,
       account_balance
FROM audit_user.sensitive_accounts;
```


FGA triggered.

---

# LAB 38 — Test UPDATE

APP_USER tidak mempunyai UPDATE privilege.

Kita lakukan sebagai owner:

```sql
EXIT
```

```bash
sqlplus -L audit_user/Welcome1@192.168.56.26:1521/PDB1
```


```sql
UPDATE sensitive_accounts
WHERE account_id=2;
COMMIT;
```


FGA triggered.

---

# LAB 39 — Melihat Semua FGA Events

```sql
EXIT
```

```bash
sqlplus -L lab_auditor/Welcome1@192.168.56.26:1521/PDB1
```


```sql
SELECT event_timestamp,
       dbusername,
       action_name,
       object_name,
       fga_policy_name,
       return_code
FROM unified_audit_trail
WHERE fga_policy_name IS NOT NULL
ORDER BY event_timestamp DESC;
```


---

# LAB 40 — FGA Audit Inventory

Login SYS:

```sql
EXIT
```

```bash
sqlplus -L sys/oracle@192.168.56.26:1521/PDB1 as sysdba
```


```sql
SELECT object_schema,
       object_name,
       policy_name,
       policy_text,
       policy_column,
       enabled
FROM dba_audit_policies
WHERE object_schema='AUDIT_USER'
ORDER BY object_name, policy_name;
```

Ini merupakan query administrasi FGA yang sangat penting.

---

# LAB 41 — Disable FGA Policy

Disable:

```sql
BEGIN
  DBMS_FGA.DISABLE_POLICY(
      object_schema => 'AUDIT_USER',
      object_name   => 'CUSTOMERS',
      policy_name   => 'FGA_EMAIL_ACCESS'
  );
END;
/
```


Verifikasi:

```sql
SELECT policy_name,
       enabled
FROM dba_audit_policies
WHERE policy_name='FGA_EMAIL_ACCESS';
```


---

# LAB 42 — Enable Kembali

```sql
BEGIN
  DBMS_FGA.ENABLE_POLICY(
      object_schema => 'AUDIT_USER',
      object_name   => 'CUSTOMERS',
      policy_name   => 'FGA_EMAIL_ACCESS'
  );
END;
/
```


Verifikasi:

```sql
SELECT policy_name,
       enabled
FROM dba_audit_policies
WHERE policy_name='FGA_EMAIL_ACCESS';
```


---

# LAB 43 — Drop Policy

Untuk demonstrasi lifecycle, buat policy sementara:

```sql
BEGIN
  DBMS_FGA.ADD_POLICY(
      object_schema   => 'AUDIT_USER',
      object_name     => 'CUSTOMERS',
      policy_name     => 'FGA_TEMP_POLICY',
      statement_types => 'SELECT'
  );
END;
/
```


Drop:

```sql
BEGIN
  DBMS_FGA.DROP_POLICY(
      object_schema => 'AUDIT_USER',
      object_name   => 'CUSTOMERS',
      policy_name   => 'FGA_TEMP_POLICY'
  );
END;
/
```


Lifecycle:

```text
ADD_POLICY
    │
    ▼
ENABLED
    │
    ├── DISABLE_POLICY
    │
    ├── ENABLE_POLICY
    │
    └── DROP_POLICY
```

---

# LAB 44 — Melihat AUDIT_TYPE

Login investigator:

```sql
EXIT
```

```bash
sqlplus -L lab_auditor/Welcome1@192.168.56.26:1521/PDB1
```


```sql
SELECT audit_type,
       dbusername,
       action_name,
       object_name,
       fga_policy_name
FROM unified_audit_trail
WHERE fga_policy_name IS NOT NULL
ORDER BY event_timestamp DESC
FETCH FIRST 20 ROWS ONLY;
```

Pada pure unified auditing, filter `FGA_POLICY_NAME IS NOT NULL` menampilkan event FGA; `UNIFIED_AUDIT_POLICIES` mengidentifikasi unified policy.

---

# LAB 45 — FGA vs Unified Audit Policy

Bandingkan:

```sql
SELECT event_timestamp,
       dbusername,
       audit_type,
       action_name,
       object_name,
       unified_audit_policies,
       fga_policy_name
FROM unified_audit_trail
WHERE object_name='CUSTOMERS'
ORDER BY event_timestamp DESC
FETCH FIRST 30 ROWS ONLY;
```

Konsepnya:

```text
Unified Audit Policy
        │
        ├── UNIFIED_AUDIT_POLICIES
        │
        ▼
UNIFIED_AUDIT_TRAIL


FGA (pure unified auditing)
        │
        ├── POLICY_NAME → FGA_POLICY_NAME
        │
        ▼
UNIFIED_AUDIT_TRAIL
        │
        ▼
LAB_AUDITOR.LAB_AUDIT_TRAIL
```

---

# LAB 46 — Query SQL_TEXT FGA

```sql
SELECT event_timestamp,
       dbusername,
       fga_policy_name,
       sql_text
FROM unified_audit_trail
WHERE fga_policy_name IS NOT NULL
ORDER BY event_timestamp DESC
FETCH FIRST 30 ROWS ONLY;
```

---

# LAB 47 — Investigasi  Access

Scenario:

> Security team ingin mengetahui siapa yang membaca EMAIL customer.

```sql
SELECT event_timestamp,
       dbusername,
       userhost,
       client_program_name,
       sql_text
FROM unified_audit_trail
WHERE fga_policy_name='FGA_EMAIL_ACCESS'
ORDER BY event_timestamp DESC;
```

Ini menjawab:

```text
WHO?
DBUSERNAME

WHEN?
EVENT_TIMESTAMP

WHERE FROM?
USERHOST

CLIENT?
CLIENT_PROGRAM_NAME

HOW?
SQL_TEXT
```

---

# LAB 48 — Investigasi High-Value Customer

```sql
SELECT event_timestamp,
       dbusername,
       action_name,
       object_name,
       sql_text
FROM unified_audit_trail
WHERE fga_policy_name='FGA_HIGH_CREDIT'
ORDER BY event_timestamp DESC;
```

---

# LAB 49 — FGA Event Count per Policy

```sql
SELECT fga_policy_name,
       COUNT(*) total_events
FROM unified_audit_trail
WHERE fga_policy_name IS NOT NULL
GROUP BY fga_policy_name
ORDER BY total_events DESC;
```


---

# LAB 50 — FGA Event per User

```sql
SELECT dbusername,
       fga_policy_name,
       COUNT(*) total_events
FROM unified_audit_trail
WHERE fga_policy_name IS NOT NULL
GROUP BY dbusername,
         fga_policy_name
ORDER BY dbusername,
         total_events DESC;
```

---

# LAB 51 — FGA Event per Action

```sql
SELECT action_name,
       COUNT(*) total
FROM unified_audit_trail
WHERE fga_policy_name IS NOT NULL
GROUP BY action_name
ORDER BY total DESC;
```


---

# LAB 52 — FGA Dalam 30 Menit Terakhir

```sql
SELECT event_timestamp,
       dbusername,
       action_name,
       fga_policy_name,
       object_name
FROM unified_audit_trail
WHERE fga_policy_name IS NOT NULL
AND event_timestamp >=
    SYSTIMESTAMP - INTERVAL '30' MINUTE
ORDER BY event_timestamp DESC;
```

---

# LAB 53 — Membuat FGA Handler Table

FGA juga mendukung `handler_module`. 

Kita buat demo sederhana.

Login SYS:

```sql
EXIT
```

```bash
sqlplus -L sys/oracle@192.168.56.26:1521/PDB1 as sysdba
```


Buat tabel log:

```sql
CREATE TABLE audit_user.fga_handler_log (
    log_id          NUMBER GENERATED ALWAYS AS IDENTITY,
    event_time      TIMESTAMP DEFAULT SYSTIMESTAMP,
    object_schema   VARCHAR2(128),
    object_name     VARCHAR2(128),
    policy_name     VARCHAR2(128)
);
```


---

# LAB 54 — Membuat Handler Procedure

```sql
CREATE OR REPLACE PROCEDURE audit_user.fga_handler (
    object_schema VARCHAR2,
    object_name   VARCHAR2,
    policy_name   VARCHAR2
)
AUTHID DEFINER
AS
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    INSERT INTO audit_user.fga_handler_log
    (
      object_schema,
      object_name,
      policy_name
    )
    VALUES
    (
      object_schema,
      object_name,
      policy_name
    );
    COMMIT;
END;
/
```


---

# LAB 55 — Buat Handler Policy

```sql
BEGIN
  DBMS_FGA.ADD_POLICY(
      object_schema   => 'AUDIT_USER',
      object_name     => 'CUSTOMERS',
      policy_name     => 'FGA_HANDLER_TEST',
      audit_condition => 'CREDIT_LIMIT > 50000000',
      audit_column    => 'CREDIT_LIMIT',
      handler_schema  => 'AUDIT_USER',
      handler_module  => 'FGA_HANDLER',
      statement_types => 'SELECT'
  );
END;
/
```


---

# LAB 56 — Trigger Handler

Login:

```sql
EXIT
```

```bash
sqlplus -L app_user/Welcome1@192.168.56.26:1521/PDB1
```


```sql
SELECT customer_name,
       credit_limit
FROM audit_user.customers
WHERE customer_id=4;
```


---

# LAB 57 — Periksa Handler Log

Login SYS:

```sql
EXIT
```

```bash
sqlplus -L sys/oracle@192.168.56.26:1521/PDB1 as sysdba
```


```sql
SELECT log_id,
       event_time,
       object_schema,
       object_name,
       policy_name
FROM audit_user.fga_handler_log
ORDER BY log_id;
```


Ini menunjukkan FGA tidak hanya mencatat audit tetapi dapat menjalankan **event handler**.

---

# LAB 58 — Penting: Handler Harus Hati-Hati

Jangan membuat handler melakukan statement terhadap object yang memicu policy yang sama.

Contoh desain buruk:

```text
CUSTOMERS
   │
   ▼
FGA policy
   │
   ▼
handler
   │
   ▼
SELECT CUSTOMERS
   │
   ▼
FGA policy lagi
   │
   ▼
recursive loop
```

Oracle memperingatkan handler yang menyebabkan recursive auditing dapat menghasilkan error recursive SQL atau open cursor exhaustion. 

---

# LAB 59 — Simulasi Incident

Scenario:

> Seorang user mencoba membaca data pribadi dan financial customer.

Login:

```sql
EXIT
```

```bash
sqlplus -L app_user/Welcome1@192.168.56.26:1521/PDB1
```


Jalankan:

```sql
SELECT customer_name,
       email,
       phone,
       credit_limit
FROM audit_user.customers
WHERE credit_limit > 20000000;
```


Satu query ini berpotensi memicu beberapa policy:

```text
FGA_HIGH_CREDIT
FGA_EMAIL_ACCESS
FGA_CONTACT_INFO
FGA_ALL_CONTACT
FGA_HANDLER_TEST
```

---

# LAB 60 — Incident Reconstruction

```sql
EXIT
```

```bash
sqlplus -L lab_auditor/Welcome1@192.168.56.26:1521/PDB1
```


```sql
SELECT event_timestamp,
       dbusername,
       fga_policy_name,
       object_name,
       sql_text
FROM unified_audit_trail
WHERE fga_policy_name IS NOT NULL
AND event_timestamp >=
    SYSTIMESTAMP - INTERVAL '15' MINUTE
ORDER BY event_timestamp;
```

Anda akan dapat melihat policy apa saja yang triggered.

---

# LAB 61 — Sensitive Data Access Report

```sql
SELECT dbusername,
       COUNT(*) sensitive_access
FROM unified_audit_trail
WHERE fga_policy_name IN
(
 'FGA_EMAIL_ACCESS',
 'FGA_CONTACT_INFO',
 'FGA_HIGH_CREDIT',
 'FGA_ACCOUNT_ACTIVITY'
)
GROUP BY dbusername
ORDER BY sensitive_access DESC;
```

---

# LAB 62 — High Risk FGA Report

```sql
SELECT event_timestamp,
       dbusername,
       action_name,
       object_name,
       fga_policy_name,
       return_code
FROM unified_audit_trail
WHERE fga_policy_name IS NOT NULL
AND
(
    action_name IN ('UPDATE','DELETE')
    OR fga_policy_name IN
       ('FGA_HIGH_CREDIT',
        'FGA_HIGH_VALUE_UPDATE',
        'FGA_DELETE_HIGH_VALUE')
)
ORDER BY event_timestamp DESC;
```

---

# LAB 63 — Membuat Security Dashboard FGA

```sql
SELECT
    COUNT(*) total_fga_events,
    COUNT(DISTINCT dbusername) unique_users,
    COUNT(DISTINCT fga_policy_name) policies_triggered,
    COUNT(DISTINCT object_name) objects_accessed
FROM unified_audit_trail
WHERE fga_policy_name IS NOT NULL;
```


---

# LAB 64 — User Risk Summary

```sql
SELECT dbusername,
       SUM(
         CASE
           WHEN action_name='SELECT'
           THEN 1 ELSE 0
         END
       ) reads,
       SUM(
         CASE
           WHEN action_name='UPDATE'
           THEN 1 ELSE 0
         END
       ) updates,
       SUM(
         CASE
           WHEN action_name='DELETE'
           THEN 1 ELSE 0
         END
       ) deletes
FROM unified_audit_trail
WHERE fga_policy_name IS NOT NULL
GROUP BY dbusername
ORDER BY deletes DESC,
         updates DESC,
         reads DESC;
```

---

# LAB 65 — Most Triggered FGA Policy

```sql
SELECT fga_policy_name,
       COUNT(*) total_events
FROM unified_audit_trail
WHERE fga_policy_name IS NOT NULL
GROUP BY fga_policy_name
ORDER BY total_events DESC;
```

---

# LAB 66 — Final Challenge Day 3

Security requirement:

```text
CUSTOMERS
│
├── CUSTOMER_NAME   normal
├── EMAIL           sensitive
├── PHONE           sensitive
├── CREDIT_LIMIT    highly sensitive
└── STATUS          normal
```

Anda harus menjawab:

**Siapa membaca EMAIL?**

```sql
SELECT event_timestamp,
       dbusername,
       sql_text
FROM unified_audit_trail
WHERE fga_policy_name='FGA_EMAIL_ACCESS'
ORDER BY event_timestamp DESC;
```

**Siapa membaca customer high-value?**

```sql
SELECT event_timestamp,
       dbusername,
       sql_text
FROM unified_audit_trail
WHERE fga_policy_name='FGA_HIGH_CREDIT'
ORDER BY event_timestamp DESC;
```

**Siapa mengubah CREDIT_LIMIT?**

```sql
SELECT event_timestamp,
       dbusername,
       sql_text
FROM unified_audit_trail
WHERE fga_policy_name='FGA_UPDATE_CREDIT'
ORDER BY event_timestamp DESC;
```

**Siapa melakukan DELETE high-value customer?**

```sql
SELECT event_timestamp,
       dbusername,
       sql_text
FROM unified_audit_trail
WHERE fga_policy_name='FGA_DELETE_HIGH_VALUE'
ORDER BY event_timestamp DESC;
```

---

# LAB 67 — Policy Matrix Day 3

Sekarang kita mempunyai:

| Policy                  | Tujuan                          |
| ----------------------- | ------------------------------- |
| `FGA_CREDIT_LIMIT`      | Audit akses `CREDIT_LIMIT`      |
| `FGA_HIGH_CREDIT`       | Audit customer credit > 20 juta |
| `FGA_EMAIL_ACCESS`      | Audit akses EMAIL               |
| `FGA_CONTACT_INFO`      | EMAIL **atau** PHONE            |
| `FGA_ALL_CONTACT`       | EMAIL **dan** PHONE             |
| `FGA_UPDATE_CREDIT`     | Audit UPDATE credit limit       |
| `FGA_HIGH_VALUE_UPDATE` | Audit update high-value         |
| `FGA_DELETE_HIGH_VALUE` | Audit delete high-value         |
| `FGA_ACCOUNT_ACTIVITY`  | Audit sensitive account         |
| `FGA_HANDLER_TEST`      | Demonstrasi event handler       |

---

# LAB 68 — Query Semua Policy FGA

```sql
SELECT object_schema,
       object_name,
       policy_name,
       policy_text,
       policy_column,
       enabled
FROM dba_audit_policies
WHERE object_schema='AUDIT_USER'
ORDER BY object_name,
         policy_name;
```

---

# LAB 69 — Query Semua Record FGA

```sql
SELECT event_timestamp,
       dbusername,
       action_name,
       object_schema,
       object_name,
       fga_policy_name,
       return_code
FROM unified_audit_trail
WHERE fga_policy_name IS NOT NULL
ORDER BY event_timestamp DESC;
```

---

# LAB 70 — Day 3 Cheat Sheet

Bagian ini referensi sintaks; ganti placeholder schema, tabel, policy, dan user sebelum memakai contoh. Bukan langkah lanjutan yang dijalankan berurutan.

Membuat FGA sederhana:

```sql
BEGIN
 DBMS_FGA.ADD_POLICY(
   object_schema   => 'AUDIT_USER',
   object_name     => 'CUSTOMERS',
   policy_name     => 'MY_FGA',
   audit_column    => 'CREDIT_LIMIT',
   statement_types => 'SELECT'
 );
END;
/
```

FGA dengan condition:

```sql
BEGIN
 DBMS_FGA.ADD_POLICY(
   object_schema   => 'AUDIT_USER',
   object_name     => 'CUSTOMERS',
   policy_name     => 'MY_FGA',
   audit_condition => 'CREDIT_LIMIT > 20000000',
   audit_column    => 'CREDIT_LIMIT',
   statement_types => 'SELECT'
 );
END;
/
```

Multiple columns:

```sql
audit_column => 'EMAIL,PHONE'
```

ANY:

```sql
audit_column_opts => DBMS_FGA.ANY_COLUMNS
```

ALL:

```sql
audit_column_opts => DBMS_FGA.ALL_COLUMNS
```

UPDATE auditing:

```sql
statement_types => 'UPDATE'
```

Multiple operations:

```sql
statement_types => 'SELECT,UPDATE,DELETE'
```

Disable:

```sql
BEGIN
 DBMS_FGA.DISABLE_POLICY(
   object_schema=>'AUDIT_USER',
   object_name=>'CUSTOMERS',
   policy_name=>'MY_FGA'
 );
END;
/
```

Enable:

```sql
BEGIN
 DBMS_FGA.ENABLE_POLICY(
   object_schema=>'AUDIT_USER',
   object_name=>'CUSTOMERS',
   policy_name=>'MY_FGA'
 );
END;
/
```

Drop:

```sql
BEGIN
 DBMS_FGA.DROP_POLICY(
   object_schema=>'AUDIT_USER',
   object_name=>'CUSTOMERS',
   policy_name=>'MY_FGA'
 );
END;
/
```

Inventory:

```sql
SELECT *
FROM dba_audit_policies;
```

Audit records:

```sql
SELECT event_timestamp,
       dbusername,
       action_name,
       object_name,
       fga_policy_name,
       sql_text
FROM unified_audit_trail
WHERE fga_policy_name IS NOT NULL
ORDER BY event_timestamp DESC;
```

---

# Kesimpulan Day 3

Sekarang Anda sudah sampai pada perbedaan penting:

```text
              UNIFIED AUDITING
                      │
                      ▼
         "WHAT ACTION HAPPENED?"
                      │
          SELECT / UPDATE / DDL
                      │
                      │
                      ▼
              ----------------
                      ▲
                      │
                      │
                     FGA
                      │
                      ▼
       "WHAT SENSITIVE DATA
           WAS ACCESSED?"
                      │
          ┌───────────┼───────────┐
          ▼           ▼           ▼
        COLUMN       VALUE       ROW
        EMAIL      >20M credit   condition
          │           │           │
          └───────────┼───────────┘
                      ▼
             DBMS_FGA POLICY
                      │
                      ▼
            UNIFIED_AUDIT_TRAIL
                      │
                      ▼
       LAB_AUDITOR.LAB_AUDIT_TRAIL
                      │
        ┌─────────────┼──────────────┐
        ▼             ▼              ▼
       WHO           WHAT            HOW
   DBUSERNAME    ACTION_NAME       SQL_TEXT
        │
        ▼
   FGA_POLICY_NAME
```



