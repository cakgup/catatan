# HANDS-ON LAB 5 — ORACLE SQL FIREWALL 26ai

## Policy Engineering, Baseline Tuning, Context Enforcement, Sensitive Data Monitoring, Violation Classification, Reporting & Incident Investigation

## SQL*Plus Presentation Settings

Jalankan satu kali setelah login SQL*Plus sebagai `SYS`, lalu gunakan setting ini sepanjang sesi.

```sql
SET LINESIZE 360
SET PAGESIZE 200
SET LONG 5000
SET LONGCHUNKSIZE 5000
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF
SET FEEDBACK ON
SET SERVEROUTPUT ON SIZE UNLIMITED
```

**Output hasil eksekusi**

```text
SQL*Plus settings updated.
```

---

# 1. Fokus Lab

Handson 4 membangun SQL Firewall sampai tahap:

```text
capture
  ↓
trusted workload
  ↓
normalized SQL signature
  ↓
allow-list
  ↓
detect-only / blocking
  ↓
violation
  ↓
basic tuning dan investigation
```

Handson 5 **tidak membangun ulang** environment tersebut.

Handson 5 melanjutkan state Handson 4 menjadi workflow policy engineering:

```text
TRUSTED BASELINE
      │
      ├── SQL signature
      ├── trusted IP
      ├── trusted OS user
      └── trusted OS program
      │
      ▼
RUNTIME ACTIVITY
      │
      ├── known SQL
      ├── unexpected SQL
      ├── context deviation
      ├── sensitive object access
      └── authentication anomaly
      │
      ▼
CLASSIFY
      │
      ├── legitimate change  → approve selectively
      └── suspicious change  → reject / investigate
      │
      ▼
CORRELATE
      │
      ├── DBA_SQL_FIREWALL_VIOLATIONS
      └── UNIFIED_AUDIT_TRAIL
      │
      ▼
REPORT / CSV / JSON EVIDENCE
```

SQL Firewall yang dipakai tetap **native Oracle SQL Firewall di Oracle AI Database 26ai**.

---

# 2. Important Continuation Rule from Handson 4

Handson 5 mengasumsikan Anda telah menyelesaikan Handson 4 dan **belum menjalankan cleanup Handson 4 Lab 98–102**.

Environment yang harus masih tersedia:

```text
OS          : Oracle Linux Server 9.8
Oracle      : Oracle AI Database 26ai Enterprise Edition 23.26.1.0.0

ORACLE_HOME : /opt/oracle/product/26ai/dbhome_1
ORACLE_BASE : /opt/oracle
ORACLE_SID  : ORCLCDB

CDB         : ORCLCDB
PDB         : PDB1

Listener    : 192.168.56.26:1521
Service     : PDB1

SYS         : oracle
SYSTEM      : oracle
```

Object Handson 4 yang dipakai kembali:

```text
Application owner : UA_D3_APP
Protected user    : UA_D3_READER
Reader password   : Oracle#D3Read26

Sensitive object  : UA_D3_APP.CUSTOMER_SECURE
```

State akhir Handson 4 yang diharapkan:

```text
SQL Firewall                = ENABLED
UA_D3_READER allow-list     = ENABLED
Enforcement                 = ENFORCE_ALL
Block                       = N
Capture object              = exists, stopped
SQL Firewall audit policy   = UA_D3_SQLFW_VIOLATION
```

Jika cleanup Handson 4 sudah dijalankan, ulangi Handson 4 sampai state di atas tercapai sebelum memulai Handson 5.

---

# 3. Important Lab Convention

Gunakan minimal dua terminal.

```text
Terminal A
==========
SYS / SQL Firewall administrator

Terminal B
==========
UA_D3_READER / shell client
```

Versi ini menyertakan output nyata dari environment training pada langkah-langkah penting. Peserta tetap menjalankan command secara interaktif, satu per satu. Nilai yang bersifat dinamis seperti `timestamp`, `SQL_SIGNATURE`, `SESSION_ID`, `CLIENT_PROGRAM`, `IP_ADDRESS`, `OS_PROGRAM`, jumlah audit record, dan allow-list `VERSION` dapat berbeda di setiap environment.

---

# PART A — VALIDATE Handson 4 CONTINUITY

---

# Lab 1 — Login sebagai Oracle OS User

## Tujuan

Memastikan Handson 5 menggunakan Oracle Home dan SID yang sama dengan Handson 4.

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

Verify:

```bash
echo $ORACLE_BASE
echo $ORACLE_HOME
echo $ORACLE_SID
which sqlplus
```

# Lab 2 — Connect SYS dan Switch ke PDB1

## Command

```bash
sqlplus / as sysdba
```

```sql
SHOW CON_NAME
SHOW PDBS

ALTER SESSION SET CONTAINER=PDB1;
SHOW CON_NAME
```

# Lab 3 — Verify Handson 4 Users dan Sensitive Object

## Command

```sql
COLUMN username FORMAT A20
COLUMN account_status FORMAT A20

SELECT username,
       account_status
FROM   dba_users
WHERE  username IN ('UA_D3_APP','UA_D3_READER')
ORDER  BY username;
```

Verify table:

```sql
SELECT COUNT(*) AS customer_rows
FROM   ua_d3_app.customer_secure;
```

Verify reader privilege:

```sql
SELECT grantee,
       owner,
       table_name,
       privilege
FROM   dba_tab_privs
WHERE  grantee='UA_D3_READER'
AND    owner='UA_D3_APP'
AND    table_name='CUSTOMER_SECURE'
ORDER  BY privilege;
```

# Lab 4 — Verify SQL Firewall Final State from Handson 4

## Command

```sql
SELECT status,
       status_updated_on
FROM   dba_sql_firewall_status;
```

Verify protected user:

```sql
SELECT username,
       status,
       enforce,
       block,
       generated_on,
       status_updated_on
FROM   dba_sql_firewall_allow_lists
WHERE  username='UA_D3_READER';
```

Verify capture exists and stopped:

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

Handson 5 dimulai dari policy yang sudah aktif dalam detective mode.

---

# Lab 5 — Inspect Complete Policy Model for Protected User

## Command

Allowed SQL:

```sql
SELECT COUNT(*) AS allowed_sql_count
FROM   dba_sql_firewall_allowed_sql
WHERE  username='UA_D3_READER';
```

Allowed IP:

```sql
SELECT username,
       ip_address
FROM   dba_sql_firewall_allowed_ip_addr
WHERE  username='UA_D3_READER';
```

Allowed OS user:

```sql
SELECT username,
       os_user
FROM   dba_sql_firewall_allowed_os_user
WHERE  username='UA_D3_READER';
```

Allowed OS program:

```sql
SELECT username,
       os_program
FROM   dba_sql_firewall_allowed_os_prog
WHERE  username='UA_D3_READER';
```

## Penjelasan

Mental mapping:

```text
AVDF SQL Cluster        → SQL Firewall SQL signature
AVDF User Set           → protected database user
AVDF IP Set             → allowed IP context
AVDF Client Program Set → allowed OS program
AVDF Default Rule       → SQL outside allow-list = violation
AVDF monitor mode       → block = FALSE
AVDF block mode         → block = TRUE
```

Ini mapping konsep, bukan berarti implementasi kedua produk identik.

---

# Lab 6 — Inspect Allow-List Version History

## Command

```sql
COLUMN version FORMAT 999

SELECT version,
       COUNT(*) AS sql_entries
FROM   dba_sql_firewall_allowed_sql
WHERE  username='UA_D3_READER'
GROUP  BY version
ORDER  BY version;
```

## Penjelasan

Version menunjukkan evolution history dari baseline.

---

# PART B — SQL SIGNATURE AND KNOWN BASELINE

---

# Lab 7 — Inspect Current Allowed SQL Signatures

## Command

```sql
COLUMN allowed_sql_id FORMAT 999999
COLUMN version FORMAT 999
COLUMN sql_signature FORMAT A64
COLUMN sql_text FORMAT A95
COLUMN accessed_objects FORMAT A45

SELECT allowed_sql_id,
       version,
       sql_signature,
       sql_text,
       accessed_objects
FROM   dba_sql_firewall_allowed_sql
WHERE  username='UA_D3_READER'
ORDER  BY version,
          allowed_sql_id;
```

# Lab 8 — Execute Same SQL Shape with Different Literals

Terminal B:

```bash
sqlplus -L 'ua_d3_reader/Oracle#D3Read26@//192.168.56.26:1521/PDB1'
```

Run:

```sql
SELECT customer_name,
       credit_limit
FROM   ua_d3_app.customer_secure
WHERE  customer_id = 1;

SELECT customer_name,
       credit_limit
FROM   ua_d3_app.customer_secure
WHERE  customer_id = 2;

SELECT customer_name,
       credit_limit
FROM   ua_d3_app.customer_secure
WHERE  customer_id = 5;
```

Exit:

```sql
EXIT
```

## Penjelasan

Literal berbeda tetapi struktur SQL sama. SQL Firewall membandingkan normalized signature, bukan setiap literal sebagai baseline terpisah.

---

# Lab 9 — Verify Literal Changes Did Not Become New Violations

Terminal A:

```sql
EXEC DBMS_SQL_FIREWALL.FLUSH_LOGS;
```

Check violation lima menit terakhir untuk shape tersebut:

```sql
SELECT COUNT(*) AS recent_literal_shape_violations
FROM   dba_sql_firewall_violations
WHERE  username='UA_D3_READER'
AND    cause='SQL violation'
AND    occurred_at >= SYSTIMESTAMP - INTERVAL '5' MINUTE
AND    UPPER(sql_text) LIKE '%CUSTOMER_NAME%'
AND    UPPER(sql_text) LIKE '%CREDIT_LIMIT%'
AND    UPPER(sql_text) LIKE '%CUSTOMER_ID%';
```

# PART C — SENSITIVE OBJECT MONITORING WITH UNIFIED AUDITING

---

# Lab 10 — Create Sensitive Object Unified Audit Policy

## Tujuan

Membuat detective channel yang berbeda dari SQL Firewall.

SQL Firewall menjawab:

```text
Apakah SQL sesuai baseline?
```

Unified Auditing menjawab:

```text
Apakah protected user mengakses object sensitif?
```

## Command

Masih sebagai SYS di PDB1:

```sql
CREATE AUDIT POLICY ua_d4_sensitive_access
  ACTIONS
    SELECT ON ua_d3_app.customer_secure,
    UPDATE ON ua_d3_app.customer_secure;
```

**Output hasil eksekusi**

```text
Audit policy created.
```

# Lab 11 — Enable Sensitive Object Policy for Protected User

## Command

```sql
AUDIT POLICY ua_d4_sensitive_access
BY ua_d3_reader;
```

**Output hasil eksekusi**

```text
Audit succeeded.

POLICY_NAME              ENTITY_NAME   ENTITY_TYPE  SUCCESS FAILURE
------------------------ ------------- ------------ ------- -------
UA_D4_SENSITIVE_ACCESS   UA_D3_READER  USER         YES     YES
```

Verify:

```sql
SELECT policy_name,
       entity_name,
       entity_type,
       success,
       failure
FROM   audit_unified_enabled_policies
WHERE  policy_name='UA_D4_SENSITIVE_ACCESS';
```

# Lab 12 — Generate Known SQL that Accesses Sensitive Object

Terminal B:

```bash
sqlplus -L 'ua_d3_reader/Oracle#D3Read26@//192.168.56.26:1521/PDB1'
```

Run SQL yang sudah menjadi baseline Handson 4:

```sql
SELECT customer_id,
       customer_name
FROM   ua_d3_app.customer_secure
WHERE  account_status='ACTIVE'
ORDER  BY customer_id;
```

> **Koreksi hasil uji:** `ORDER BY customer_id` wajib dipertahankan agar SQL shape benar-benar sama dengan baseline Handson 4. Tanpa klausa ini, query menjadi `SQL violation` dan tidak lagi membuktikan skenario “known SQL”.

Exit:

```sql
EXIT
```

## Penjelasan

Ini sengaja **known SQL** namun tetap menyentuh sensitive object.

---

# Lab 13 — Verify Sensitive Object Evidence in Unified Audit

Terminal A:

```sql
COLUMN event_time FORMAT A19
COLUMN dbusername FORMAT A18
COLUMN action_name FORMAT A15
COLUMN object_schema FORMAT A15
COLUMN object_name FORMAT A25
COLUMN policy FORMAT A35
COLUMN sql_text FORMAT A90

SELECT TO_CHAR(event_timestamp,'YYYY-MM-DD HH24:MI:SS') AS event_time,
       dbusername,
       action_name,
       object_schema,
       object_name,
       return_code,
       unified_audit_policies AS policy,
       DBMS_LOB.SUBSTR(sql_text,90,1) AS sql_text
FROM   unified_audit_trail
WHERE  dbusername='UA_D3_READER'
AND    object_schema='UA_D3_APP'
AND    object_name='CUSTOMER_SECURE'
AND    unified_audit_policies LIKE '%UA_D4_SENSITIVE_ACCESS%'
ORDER  BY event_timestamp DESC
FETCH FIRST 10 ROWS ONLY;
```

# Lab 14 — Prove Sensitive Access Is Not the Same as Baseline Deviation

Flush SQL Firewall:

```sql
EXEC DBMS_SQL_FIREWALL.FLUSH_LOGS;
```

Check recent SQL Firewall violation:

```sql
SELECT COUNT(*) AS sqlfw_recent_violation
FROM   dba_sql_firewall_violations
WHERE  username='UA_D3_READER'
AND    occurred_at >= SYSTIMESTAMP - INTERVAL '5' MINUTE
AND    UPPER(sql_text) LIKE '%ACCOUNT_STATUS%ACTIVE%';
```

Check Unified Audit sensitive access:

```sql
SELECT COUNT(*) AS sensitive_audit_events
FROM   unified_audit_trail
WHERE  dbusername='UA_D3_READER'
AND    object_name='CUSTOMER_SECURE'
AND    unified_audit_policies LIKE '%UA_D4_SENSITIVE_ACCESS%'
AND    event_timestamp >= SYSTIMESTAMP - INTERVAL '5' MINUTE;
```

## Penjelasan

```text
known SQL
≠
non-sensitive activity
```

SQL dapat normal menurut baseline tetapi tetap mengakses object yang organisasi anggap sensitif.

---

# PART D — TRUSTED CONNECTION CONTEXT

---

# Lab 15 — Inspect and Save Current Trusted OS Program

## Command

```sql
SELECT username,
       ip_address
FROM   dba_sql_firewall_allowed_ip_addr
WHERE  username='UA_D3_READER';

SELECT username,
       os_user
FROM   dba_sql_firewall_allowed_os_user
WHERE  username='UA_D3_READER';
```

Save current OS program ke SQL*Plus substitution variable:

```sql
COLUMN os_program NEW_VALUE D4_ORIGINAL_OS_PROGRAM NOPRINT

SELECT os_program
FROM   dba_sql_firewall_allowed_os_prog
WHERE  username='UA_D3_READER'
FETCH FIRST 1 ROW ONLY;

DEFINE D4_ORIGINAL_OS_PROGRAM
```

# Lab 16 — Deliberately Create Context Mismatch

Delete current OS-program context:

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

Add dummy value:

```sql
BEGIN
    DBMS_SQL_FIREWALL.ADD_ALLOWED_CONTEXT(
        username     => 'UA_D3_READER',
        context_type => DBMS_SQL_FIREWALL.OS_PROGRAM,
        value        => 'D4_UNTRUSTED_PROGRAM'
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

# Lab 17 — Generate Context Violation with Known SQL

Terminal B:

```bash
sqlplus -L 'ua_d3_reader/Oracle#D3Read26@//192.168.56.26:1521/PDB1'
```

Run known SQL:

```sql
SELECT COUNT(*) AS customer_count
FROM   ua_d3_app.customer_secure;
```

Exit:

```sql
EXIT
```

# Lab 18 — Investigate Context Violation and Restore Context

Flush:

```sql
EXEC DBMS_SQL_FIREWALL.FLUSH_LOGS;
```

Inspect:

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
AND    cause='Context violation'
ORDER  BY occurred_at DESC
FETCH FIRST 5 ROWS ONLY;
```

Local severity interpretation:

```text
Context violation → CRITICAL
```

Restore:

```sql
BEGIN
    DBMS_SQL_FIREWALL.DELETE_ALLOWED_CONTEXT(
        username     => 'UA_D3_READER',
        context_type => DBMS_SQL_FIREWALL.OS_PROGRAM,
        value        => 'D4_UNTRUSTED_PROGRAM'
    );
END;
/
```

```sql
BEGIN
    DBMS_SQL_FIREWALL.ADD_ALLOWED_CONTEXT(
        username     => 'UA_D3_READER',
        context_type => DBMS_SQL_FIREWALL.OS_PROGRAM,
        value        => '&D4_ORIGINAL_OS_PROGRAM'
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

Known SQL dari unexpected context tetap merupakan deviation.

---

# PART E — CONTROLLED LEARNING WINDOW FOR A LEGITIMATE RELEASE

---

# Lab 19 — Record Current Version and Disable Enforcement Temporarily

Record version:

```sql
COLUMN max_version NEW_VALUE D4_VERSION_BEFORE NOPRINT

SELECT MAX(version) AS max_version
FROM   dba_sql_firewall_allowed_sql
WHERE  username='UA_D3_READER';

DEFINE D4_VERSION_BEFORE
```

Disable allow-list enforcement temporarily:

```sql
EXEC DBMS_SQL_FIREWALL.DISABLE_ALLOW_LIST('UA_D3_READER');
```

Verify:

```sql
SELECT username,
       status
FROM   dba_sql_firewall_allow_lists
WHERE  username='UA_D3_READER';
```

## Penjelasan

Ini adalah maintenance window terkontrol, bukan permanent disabling.

---

# Lab 20 — Start Existing Capture

## Command

```sql
EXEC DBMS_SQL_FIREWALL.START_CAPTURE('UA_D3_READER');
```

Verify:

```sql
SELECT username,
       status,
       last_started_on
FROM   dba_sql_firewall_captures
WHERE  username='UA_D3_READER';
```

# Lab 21 — Run Trusted New Release SQL

Scenario:

```text
Developer merilis fitur legitimate:
filter customer berdasarkan CITY.
```

Terminal B:

```bash
sqlplus -L 'ua_d3_reader/Oracle#D3Read26@//192.168.56.26:1521/PDB1'
```

Run:

```sql
SELECT customer_id,
       customer_name,
       city
FROM   ua_d3_app.customer_secure
WHERE  city='Jakarta'
ORDER  BY customer_id;
```

Run representative literal lain:

```sql
SELECT customer_id,
       customer_name,
       city
FROM   ua_d3_app.customer_secure
WHERE  city='Bogor'
ORDER  BY customer_id;
```

Exit:

```sql
EXIT
```

## Penjelasan

Hanya workload yang sudah dinyatakan trusted yang dijalankan selama learning window.

---

# Lab 22 — Stop Capture and Review Candidate SQL

Stop:

```sql
EXEC DBMS_SQL_FIREWALL.STOP_CAPTURE('UA_D3_READER');
```

Review candidate:

```sql
COLUMN sql_signature FORMAT A64
COLUMN sql_text FORMAT A100
COLUMN accessed_objects FORMAT A45

SELECT sql_signature,
       current_user,
       top_level,
       sql_text,
       accessed_objects
FROM   dba_sql_firewall_capture_logs
WHERE  username='UA_D3_READER'
AND    UPPER(sql_text) LIKE '%CUSTOMER_SECURE%'
AND    UPPER(sql_text) LIKE '%WHERE CITY%'
ORDER  BY session_id DESC;
```

## Decision

Untuk lab ini candidate tersebut dinyatakan:

```text
LEGITIMATE
APPROVED FOR BASELINE
```

## Important

Jangan menjalankan:

```text
APPEND semua capture tanpa review
```

jika learning window tidak benar-benar trusted.

---

# Lab 23 — Append Only the Reviewed Capture SQL

## Command

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
        FROM   dba_sql_firewall_capture_logs
        WHERE  username='UA_D3_READER'
        AND    UPPER(sql_text) LIKE '%CUSTOMER_SECURE%'
        AND    UPPER(sql_text) LIKE '%WHERE CITY%'
        ORDER  BY session_id DESC
    )
    WHERE ROWNUM=1;

    DBMS_SQL_FIREWALL.APPEND_ALLOW_LIST_SINGLE_SQL(
        username      => 'UA_D3_READER',
        sql_signature => l_sql_signature,
        current_user  => l_current_user,
        top_level     => l_top_level,
        source        => DBMS_SQL_FIREWALL.CAPTURE_LOG
    );
END;
/
```

## Penjelasan

Yang di-approve hanya satu candidate yang sudah direview.

---

# Lab 24 — Re-enable Detective Policy and Verify Version Increment

Re-enable:

```sql
BEGIN
    DBMS_SQL_FIREWALL.ENABLE_ALLOW_LIST(
        username => 'UA_D3_READER',
        enforce  => DBMS_SQL_FIREWALL.ENFORCE_ALL,
        block    => FALSE
    );
END;
/
```

Verify enforcement:

```sql
SELECT username,
       status,
       enforce,
       block
FROM   dba_sql_firewall_allow_lists
WHERE  username='UA_D3_READER';
```

Verify version increment:

```sql
SELECT &D4_VERSION_BEFORE AS version_before,
       MAX(version) AS version_after,
       MAX(version) - &D4_VERSION_BEFORE AS version_delta
FROM   dba_sql_firewall_allowed_sql
WHERE  username='UA_D3_READER';
```

# Lab 25 — Retest Approved New SQL

Terminal B:

```bash
sqlplus -L 'ua_d3_reader/Oracle#D3Read26@//192.168.56.26:1521/PDB1'
```

```sql
SELECT customer_id,
       customer_name,
       city
FROM   ua_d3_app.customer_secure
WHERE  city='Depok'
ORDER  BY customer_id;

EXIT
```

Terminal A:

```sql
EXEC DBMS_SQL_FIREWALL.FLUSH_LOGS;
```

```sql
SELECT COUNT(*) AS city_query_recent_violations
FROM   dba_sql_firewall_violations
WHERE  username='UA_D3_READER'
AND    occurred_at >= SYSTIMESTAMP - INTERVAL '5' MINUTE
AND    UPPER(sql_text) LIKE '%WHERE CITY%';
```

## Penjelasan

Workflow:

```text
new legitimate SQL
→ controlled capture
→ review
→ approve selectively
→ version update
→ no longer violation
```

---

# PART F — UNEXPECTED SQL AND REJECT WORKFLOW

---

# Lab 26 — Generate Suspicious New SQL Shape

Terminal B:

```bash
sqlplus -L 'ua_d3_reader/Oracle#D3Read26@//192.168.56.26:1521/PDB1'
```

Run:

```sql
SELECT MAX(credit_limit) AS max_credit_limit
FROM   ua_d3_app.customer_secure;
```

**Output hasil eksekusi (detect-only)**

```text
MAX_CREDIT_LIMIT
----------------
        75000000

1 row selected.
```

Setelah `FLUSH_LOGS`, SQL yang dinormalisasi menjadi `SELECT MAX (CREDIT_LIMIT) ...`; ia tercatat sebagai `SQL violation / Allowed`.

Exit:

```sql
EXIT
```

---

# Lab 27 — Investigate Suspicious Violation

Terminal A:

```sql
EXEC DBMS_SQL_FIREWALL.FLUSH_LOGS;
```

```sql
COLUMN occurred_at FORMAT A35
COLUMN cause FORMAT A20
COLUMN firewall_action FORMAT A15
COLUMN accessed_objects FORMAT A50
COLUMN sql_text FORMAT A100

SELECT occurred_at,
       sql_signature,
       cause,
       firewall_action,
       accessed_objects,
       sql_text
FROM   dba_sql_firewall_violations
WHERE  username='UA_D3_READER'
AND    REGEXP_LIKE(UPPER(sql_text), 'MAX[[:space:]]*[(]CREDIT_LIMIT[)]')
ORDER  BY occurred_at DESC
FETCH FIRST 5 ROWS ONLY;
```

Decision untuk lab:

```text
NOT IN APPLICATION REQUIREMENT
SUSPICIOUS
DO NOT APPROVE
```

---

# Lab 28 — Reject by Doing Nothing to the Allow-List

Tidak ada command append pada lab ini.

Verifikasi SQL belum masuk allow-list:

```sql
SELECT COUNT(*) AS suspicious_sql_allowed
FROM   dba_sql_firewall_allowed_sql
WHERE  username='UA_D3_READER'
AND    REGEXP_LIKE(UPPER(sql_text), 'MAX[[:space:]]*[(]CREDIT_LIMIT[)]');
```

## Penjelasan

Reject pada policy governance berarti:

```text
do not approve
```

bukan berarti harus menghapus evidence.

---

# Lab 29 — Retest Rejected SQL and Prove It Remains a Deviation

Count before:

```sql
SELECT COUNT(*) AS violation_before
FROM   dba_sql_firewall_violations
WHERE  username='UA_D3_READER'
AND    REGEXP_LIKE(UPPER(sql_text), 'MAX[[:space:]]*[(]CREDIT_LIMIT[)]');
```

Terminal B:

```bash
sqlplus -L 'ua_d3_reader/Oracle#D3Read26@//192.168.56.26:1521/PDB1'
```

```sql
SELECT MAX(credit_limit) AS max_credit_limit
FROM   ua_d3_app.customer_secure;

EXIT
```

Terminal A:

```sql
EXEC DBMS_SQL_FIREWALL.FLUSH_LOGS;
```

Count after:

```sql
SELECT COUNT(*) AS violation_after
FROM   dba_sql_firewall_violations
WHERE  username='UA_D3_READER'
AND    REGEXP_LIKE(UPPER(sql_text), 'MAX[[:space:]]*[(]CREDIT_LIMIT[)]');
```

## Penjelasan

Rejected SQL tetap menjadi deviation pada eksekusi berikutnya.

---

# PART G — NO ROW COUNT, EXFILTRATION-STYLE AND FREQUENCY DETECTION

---

# Lab 30 — Prove Native Evidence Has No Returned-Row-Count Field

## Command

Cari column yang menyerupai returned-row count pada dua source utama:

```sql
COLUMN table_name FORMAT A35
COLUMN column_name FORMAT A35

SELECT table_name,
       column_name
FROM   all_tab_columns
WHERE  table_name IN ('DBA_SQL_FIREWALL_VIOLATIONS',
                      'UNIFIED_AUDIT_TRAIL')
AND   (UPPER(column_name) LIKE '%ROW%COUNT%'
       OR UPPER(column_name) LIKE '%COUNT%ROW%')
ORDER  BY table_name,
          column_name;
```

## Penjelasan

Lab **tidak membuat fake returned-row count**. Detection menggunakan signal lain.

---

# Lab 31 — Generate Broad Sensitive Read and Repeated Reads

Terminal B:

```bash
sqlplus -L 'ua_d3_reader/Oracle#D3Read26@//192.168.56.26:1521/PDB1'
```

Broad read:

```sql
SELECT *
FROM   ua_d3_app.customer_secure
ORDER  BY customer_id;
```

Repeated enumeration shape — jalankan 5 kali:

```sql
SELECT customer_id,
       credit_limit
FROM   ua_d3_app.customer_secure
WHERE  credit_limit >= 0
ORDER  BY credit_limit DESC;

SELECT customer_id,
       credit_limit
FROM   ua_d3_app.customer_secure
WHERE  credit_limit >= 0
ORDER  BY credit_limit DESC;

SELECT customer_id,
       credit_limit
FROM   ua_d3_app.customer_secure
WHERE  credit_limit >= 0
ORDER  BY credit_limit DESC;

SELECT customer_id,
       credit_limit
FROM   ua_d3_app.customer_secure
WHERE  credit_limit >= 0
ORDER  BY credit_limit DESC;

SELECT customer_id,
       credit_limit
FROM   ua_d3_app.customer_secure
WHERE  credit_limit >= 0
ORDER  BY credit_limit DESC;
```

Exit:

```sql
EXIT
```

---

# Lab 32 — Generate Unexpected Aggregate

Terminal B:

```bash
sqlplus -L 'ua_d3_reader/Oracle#D3Read26@//192.168.56.26:1521/PDB1'
```

```sql
SELECT SUM(credit_limit) AS total_credit_limit
FROM   ua_d3_app.customer_secure;

EXIT
```

Terminal A:

```sql
EXEC DBMS_SQL_FIREWALL.FLUSH_LOGS;
```

---

# Lab 33 — Build 5-Minute Frequency Detector

## Command

```sql
COLUMN sql_signature FORMAT A64
COLUMN cause FORMAT A20

SELECT username,
       cause,
       sql_signature,
       COUNT(*) AS violations_5m
FROM   dba_sql_firewall_violations
WHERE  username='UA_D3_READER'
AND    occurred_at >= SYSTIMESTAMP - INTERVAL '5' MINUTE
GROUP  BY username,
          cause,
          sql_signature
HAVING COUNT(*) >= 3
ORDER  BY violations_5m DESC;
```

## Penjelasan

Ini adalah **local detector**, bukan built-in SQL Firewall alert severity engine.

---

# Lab 34 — Build Exfiltration-Style Detector Without Row Count

## Command

```sql
COLUMN signal FORMAT A25
COLUMN sql_text FORMAT A110
COLUMN accessed_objects FORMAT A45

SELECT occurred_at,
       username,
       CASE
           WHEN UPPER(accessed_objects) LIKE '%CUSTOMER_SECURE%'
            AND UPPER(sql_text) LIKE '%SELECT *%'
               THEN 'BROAD_SENSITIVE_READ'
           WHEN UPPER(accessed_objects) LIKE '%CUSTOMER_SECURE%'
            AND REGEXP_LIKE(UPPER(sql_text), 'SUM[[:space:]]*[(]CREDIT_LIMIT[)]')
               THEN 'UNEXPECTED_AGGREGATE'
           WHEN UPPER(accessed_objects) LIKE '%CUSTOMER_SECURE%'
            AND UPPER(sql_text) LIKE '%ORDER BY CREDIT_LIMIT%'
               THEN 'CREDIT_ENUMERATION'
           ELSE 'OTHER_DEVIATION'
       END AS signal,
       accessed_objects,
       sql_text
FROM   dba_sql_firewall_violations
WHERE  username='UA_D3_READER'
AND    cause='SQL violation'
AND    occurred_at >= SYSTIMESTAMP - INTERVAL '30' MINUTE
ORDER  BY occurred_at DESC;
```

# PART H — AUTHENTICATION ANOMALY AS A SEPARATE CHANNEL

---

# Lab 35 — Create Authentication Unified Audit Policy

## Command

```sql
CREATE AUDIT POLICY ua_d4_authentication
  ACTIONS LOGON, LOGOFF;
```

**Output hasil eksekusi**

```text
Audit policy created.
```

Enable for protected user:

```sql
AUDIT POLICY ua_d4_authentication
BY ua_d3_reader;
```

Verify:

```sql
SELECT policy_name,
       entity_name,
       success,
       failure
FROM   audit_unified_enabled_policies
WHERE  policy_name='UA_D4_AUTHENTICATION';
```

---

# Lab 36 — Generate Three Failed Logins

Terminal B shell:

```bash
for i in 1 2 3
do
  echo "Attempt $i"
  echo exit | sqlplus -L -s 'ua_d3_reader/WrongPassword@//192.168.56.26:1521/PDB1'
done
```

# Lab 37 — Generate Successful Login Immediately After Failures

Terminal B:

```bash
sqlplus -L 'ua_d3_reader/Oracle#D3Read26@//192.168.56.26:1521/PDB1'
```

```sql
SELECT USER AS logged_in_user
FROM dual;

EXIT
```

# Lab 38 — Build Failed Login Detector

Terminal A:

```sql
COLUMN dbusername FORMAT A20

SELECT dbusername,
       COUNT(*) AS failures_5m
FROM   unified_audit_trail
WHERE  dbusername='UA_D3_READER'
AND    action_name='LOGON'
AND    return_code=1017
AND    event_timestamp >= SYSTIMESTAMP - INTERVAL '5' MINUTE
GROUP  BY dbusername
HAVING COUNT(*) >= 3;
```

Local interpretation:

```text
3 failures in 5 minutes → CRITICAL SIGNAL
```

---

# Lab 39 — Authentication Timeline

## Command

```sql
COLUMN event_time FORMAT A19
COLUMN dbusername FORMAT A18
COLUMN action_name FORMAT A12
COLUMN userhost FORMAT A25
COLUMN client_program_name FORMAT A35

SELECT TO_CHAR(event_timestamp,'YYYY-MM-DD HH24:MI:SS') AS event_time,
       dbusername,
       action_name,
       return_code,
       userhost,
       client_program_name,
       unified_audit_policies
FROM   unified_audit_trail
WHERE  dbusername='UA_D3_READER'
AND    action_name IN ('LOGON','LOGOFF')
AND    event_timestamp >= SYSTIMESTAMP - INTERVAL '15' MINUTE
ORDER  BY event_timestamp;
```

# PART I — Handson 5 FULL INCIDENT SIMULATION

---

# Lab 40 — Temporarily Grant UPDATE for Incident Simulation

## Tujuan

Handson 4 reader sengaja hanya memiliki `SELECT`. Untuk menghasilkan successful anomalous `UPDATE` dan mengorelasikannya dengan SQL Firewall + sensitive-object audit, Handson 5 memberi privilege UPDATE **sementara**.

## Command

```sql
GRANT UPDATE
ON ua_d3_app.customer_secure
TO ua_d3_reader;
```

Verify:

```sql
SELECT privilege
FROM   dba_tab_privs
WHERE  grantee='UA_D3_READER'
AND    owner='UA_D3_APP'
AND    table_name='CUSTOMER_SECURE'
ORDER  BY privilege;
```

---

# Lab 41 — Record Incident Start Timestamp

Terminal A:

```sql
COLUMN incident_start NEW_VALUE D4_INCIDENT_START NOPRINT

SELECT TO_CHAR(SYSTIMESTAMP,
               'YYYY-MM-DD HH24:MI:SS.FF3 TZH:TZM') AS incident_start
FROM dual;

DEFINE D4_INCIDENT_START
```

Jangan tutup Terminal A sampai investigation selesai.

---

# Lab 42 — Execute Complete Incident Sequence

## Step 1 — Three Failed Logins
Terminal B shell:

```bash
for i in 1 2 3
do
  echo exit | sqlplus -L -s 'ua_d3_reader/WrongPassword@//192.168.56.26:1521/PDB1'
done
```

## Step 2 — Successful Login

```bash
sqlplus -L 'ua_d3_reader/Oracle#D3Read26@//192.168.56.26:1521/PDB1'
```

## Step 3 — Full Sensitive Read

```sql
SELECT *
FROM   ua_d3_app.customer_secure
ORDER  BY customer_id;
```

## Step 4 — Credit-Limit Enumeration

```sql
SELECT customer_id,
       customer_name,
       credit_limit
FROM   ua_d3_app.customer_secure
ORDER  BY credit_limit DESC;
```

## Step 5 — UPDATE Sensitive Object

```sql
UPDATE ua_d3_app.customer_secure
SET    account_status='REVIEW'
WHERE  customer_id=1;
```

Rollback:

```sql
ROLLBACK;
```

## Step 6 — Unexpected Aggregate

```sql
SELECT AVG(credit_limit) AS avg_credit_limit
FROM   ua_d3_app.customer_secure;
```

Exit:

```sql
EXIT
```

## Incident Pattern

```text
failed login
failed login
failed login
      ↓
successful login
      ↓
full sensitive read
      ↓
credit-limit enumeration
      ↓
UPDATE
      ↓
unexpected aggregate
```

---

# Lab 43 — Build SQL Firewall Incident Timeline

Terminal A:

```sql
EXEC DBMS_SQL_FIREWALL.FLUSH_LOGS;
```

```sql
COLUMN occurred_at FORMAT A35
COLUMN cause FORMAT A20
COLUMN firewall_action FORMAT A15
COLUMN accessed_objects FORMAT A50
COLUMN sql_text FORMAT A110

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
AND    occurred_at >= TO_TIMESTAMP_TZ(
           '&D4_INCIDENT_START',
           'YYYY-MM-DD HH24:MI:SS.FF3 TZH:TZM'
       )
ORDER  BY occurred_at;
```

# Lab 44 — Build Unified Audit Incident Timeline

## Command

```sql
COLUMN event_time FORMAT A35
COLUMN action_name FORMAT A12
COLUMN object_schema FORMAT A15
COLUMN object_name FORMAT A25
COLUMN policy FORMAT A45
COLUMN sql_text FORMAT A100

SELECT event_timestamp AS event_time,
       dbusername,
       action_name,
       return_code,
       object_schema,
       object_name,
       unified_audit_policies AS policy,
       DBMS_LOB.SUBSTR(sql_text,100,1) AS sql_text
FROM   unified_audit_trail
WHERE  dbusername='UA_D3_READER'
AND    event_timestamp >= TO_TIMESTAMP_TZ(
           '&D4_INCIDENT_START',
           'YYYY-MM-DD HH24:MI:SS.FF3 TZH:TZM'
       )
ORDER  BY event_timestamp;
```

# Lab 45 — Correlate the Two Detective Channels

## Command

```sql
COLUMN event_time FORMAT A35
COLUMN source FORMAT A18
COLUMN event_type FORMAT A22
COLUMN status FORMAT A18
COLUMN details FORMAT A120

SELECT event_time,
       source,
       event_type,
       status,
       details
FROM (
    SELECT occurred_at AS event_time,
           'SQL_FIREWALL' AS source,
           cause AS event_type,
           firewall_action AS status,
           SUBSTR(sql_text,1,120) AS details
    FROM   dba_sql_firewall_violations
    WHERE  username='UA_D3_READER'
    AND    occurred_at >= TO_TIMESTAMP_TZ(
               '&D4_INCIDENT_START',
               'YYYY-MM-DD HH24:MI:SS.FF3 TZH:TZM'
           )

    UNION ALL

    SELECT event_timestamp AS event_time,
           'UNIFIED_AUDIT' AS source,
           action_name AS event_type,
           TO_CHAR(return_code) AS status,
           DBMS_LOB.SUBSTR(sql_text,120,1) AS details
    FROM   unified_audit_trail
    WHERE  dbusername='UA_D3_READER'
    AND    event_timestamp >= TO_TIMESTAMP_TZ(
               '&D4_INCIDENT_START',
               'YYYY-MM-DD HH24:MI:SS.FF3 TZH:TZM'
           )
)
ORDER  BY event_time;
```

# Lab 46 — Revoke Temporary UPDATE Privilege

## Command

```sql
REVOKE UPDATE
ON ua_d3_app.customer_secure
FROM ua_d3_reader;
```

Verify:

```sql
SELECT privilege
FROM   dba_tab_privs
WHERE  grantee='UA_D3_READER'
AND    owner='UA_D3_APP'
AND    table_name='CUSTOMER_SECURE'
ORDER  BY privilege;
```

# PART J — LOCAL SEVERITY AND OPERATIONAL REPORTING

---

# Lab 47 — Build Derived Severity Report

## Command

```sql
COLUMN derived_severity FORMAT A18
COLUMN cause FORMAT A20
COLUMN accessed_objects FORMAT A50
COLUMN sql_text FORMAT A100

SELECT occurred_at,
       username,
       CASE
           WHEN cause='Context violation'
               THEN 'CRITICAL'
           WHEN cause='SQL violation'
            AND UPPER(accessed_objects) LIKE '%CUSTOMER_SECURE%'
               THEN 'MAJOR'
           WHEN cause='SQL violation'
               THEN 'MODERATE'
           ELSE 'INFORMATIONAL'
       END AS derived_severity,
       cause,
       firewall_action,
       accessed_objects,
       sql_text
FROM   dba_sql_firewall_violations
WHERE  username='UA_D3_READER'
ORDER  BY occurred_at DESC
FETCH FIRST 30 ROWS ONLY;
```

## Important

`DERIVED_SEVERITY` adalah **local training logic**, bukan native severity field SQL Firewall.

---

# Lab 48 — Report Current Allowed SQL

## Command

```sql
COLUMN sql_text FORMAT A100
COLUMN accessed_objects FORMAT A45

SELECT allowed_sql_id,
       version,
       sql_signature,
       accessed_objects,
       sql_text
FROM   dba_sql_firewall_allowed_sql
WHERE  username='UA_D3_READER'
ORDER  BY version,
          allowed_sql_id;
```

Pertanyaan yang dijawab:

```text
SQL apa yang currently trusted?
Version mana yang menambahkannya?
Object apa yang disentuh?
```

---

# Lab 49 — Report Trusted Context

## Command

```sql
SELECT 'IP_ADDRESS' AS context_type,
       ip_address AS context_value
FROM   dba_sql_firewall_allowed_ip_addr
WHERE  username='UA_D3_READER'

UNION ALL

SELECT 'OS_USER',
       os_user
FROM   dba_sql_firewall_allowed_os_user
WHERE  username='UA_D3_READER'

UNION ALL

SELECT 'OS_PROGRAM',
       os_program
FROM   dba_sql_firewall_allowed_os_prog
WHERE  username='UA_D3_READER';
```

# Lab 50 — Report Recent Sensitive Activity

## Command

```sql
COLUMN event_time FORMAT A19
COLUMN sql_text FORMAT A100

SELECT TO_CHAR(event_timestamp,'YYYY-MM-DD HH24:MI:SS') AS event_time,
       dbusername,
       action_name,
       object_schema,
       object_name,
       return_code,
       DBMS_LOB.SUBSTR(sql_text,100,1) AS sql_text
FROM   unified_audit_trail
WHERE  dbusername='UA_D3_READER'
AND    object_schema='UA_D3_APP'
AND    object_name='CUSTOMER_SECURE'
AND    unified_audit_policies LIKE '%UA_D4_SENSITIVE_ACCESS%'
ORDER  BY event_timestamp DESC
FETCH FIRST 30 ROWS ONLY;
```

---

# PART K — JSON AND CSV EVIDENCE PACKAGE

---

# Lab 51 — Export Current Allow-List to JSON CLOB

## Command

```sql
VARIABLE d4_allowlist_json CLOB
```

Create temporary CLOB:

```sql
BEGIN
    DBMS_LOB.CREATETEMPORARY(
        :d4_allowlist_json,
        TRUE
    );
END;
/
```

Export:

```sql
BEGIN
    DBMS_SQL_FIREWALL.EXPORT_ALLOW_LIST(
        username   => 'UA_D3_READER',
        allow_list => :d4_allowlist_json
    );
END;
/
```

Check size:

```sql
SELECT DBMS_LOB.GETLENGTH(:d4_allowlist_json) AS json_bytes
FROM dual;
```

**Output hasil eksekusi**

```text
JSON_BYTES
----------
      4291

1 row selected.
```

# Lab 52 — Spool JSON Evidence to File

Create evidence directory:

```sql
HOST mkdir -p /tmp/ua_d4_evidence
```

Spool:

```sql
SET LINESIZE 32767
SET LONG 1000000
SET LONGCHUNKSIZE 1000000
SET PAGESIZE 0
SET HEADING OFF
SET FEEDBACK OFF
SET VERIFY OFF
SET ECHO OFF
SET TRIMSPOOL ON

SPOOL /tmp/ua_d4_evidence/ua_d4_allowlist.json
SELECT :d4_allowlist_json FROM dual;
SPOOL OFF

SET PAGESIZE 200
SET HEADING ON
SET FEEDBACK ON
```

> **Koreksi hasil uji:** `SET LINESIZE 32767` membuat CLOB JSON tidak dibungkus pada lebar tampilan kecil. Hasil uji file: `4293 /tmp/ua_d4_evidence/ua_d4_allowlist.json`; file dimulai dengan JSON yang valid, `{ "db_version" : "23.26.1.0.0", ... }`.

Verify from SQL*Plus:

```sql
HOST ls -lh /tmp/ua_d4_evidence/ua_d4_allowlist.json
HOST head -c 300 /tmp/ua_d4_evidence/ua_d4_allowlist.json
HOST echo
```

# Lab 53 — Export SQL Firewall Violations to CSV

## Command

```sql
SET MARKUP CSV ON
SET FEEDBACK OFF

SPOOL /tmp/ua_d4_evidence/ua_d4_sqlfw_violations.csv

SELECT occurred_at,
       username,
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
ORDER  BY occurred_at;

SPOOL OFF

SET MARKUP CSV OFF
SET FEEDBACK ON
```

Verify:

```sql
HOST head -5 /tmp/ua_d4_evidence/ua_d4_sqlfw_violations.csv
```

---

# Lab 54 — Export Unified Audit Evidence to CSV

## Command

```sql
SET MARKUP CSV ON
SET FEEDBACK OFF

SPOOL /tmp/ua_d4_evidence/ua_d4_unified_audit.csv

SELECT event_timestamp,
       dbusername,
       action_name,
       return_code,
       object_schema,
       object_name,
       userhost,
       client_program_name,
       unified_audit_policies,
       DBMS_LOB.SUBSTR(sql_text,500,1) AS sql_text
FROM   unified_audit_trail
WHERE  dbusername='UA_D3_READER'
AND   (unified_audit_policies LIKE '%UA_D4_SENSITIVE_ACCESS%'
       OR unified_audit_policies LIKE '%UA_D4_AUTHENTICATION%'
       OR UPPER(audit_type)='SQL FIREWALL')
ORDER  BY event_timestamp;

SPOOL OFF

SET MARKUP CSV OFF
SET FEEDBACK ON
```

Verify:

```sql
HOST head -5 /tmp/ua_d4_evidence/ua_d4_unified_audit.csv
```

---

# Lab 55 — Verify Evidence Package

## Command

```sql
HOST ls -lh /tmp/ua_d4_evidence
```

**Output hasil eksekusi**

```text
total 68K
-rw-r--r--. 1 oracle oinstall  45K ua_d4_allowlist.json
-rw-r--r--. 1 oracle oinstall 4.1K ua_d4_sqlfw_violations.csv
-rw-r--r--. 1 oracle oinstall  11K ua_d4_unified_audit.csv
```

Mental model:

```text
current policy state → JSON
SQL deviations       → CSV
native audit evidence→ CSV
```

---

# PART L — TROUBLESHOOTING

---

# Lab 56 — Troubleshooting Too Many Violations

## Command

```sql
COLUMN sql_signature FORMAT A64
COLUMN sample_sql FORMAT A100

SELECT cause,
       sql_signature,
       COUNT(*) AS violation_count,
       MIN(SUBSTR(sql_text,1,100)) AS sample_sql
FROM   dba_sql_firewall_violations
WHERE  username='UA_D3_READER'
AND    occurred_at >= SYSTIMESTAMP - INTERVAL '1' HOUR
GROUP  BY cause,
          sql_signature
ORDER  BY violation_count DESC
FETCH FIRST 15 ROWS ONLY;
```

Investigasi:

```text
baseline incomplete?
new application release?
context berubah?
normal SQL belum approved?
one noisy repeated query?
```

Check current mode:

```sql
SELECT username,
       status,
       enforce,
       block
FROM   dba_sql_firewall_allow_lists
WHERE  username='UA_D3_READER';
```

---

# Lab 57 — Troubleshooting Expected SQL Becomes Violation

Allowed side:

```sql
SELECT allowed_sql_id,
       version,
       sql_signature,
       current_user,
       top_level,
       sql_text
FROM   dba_sql_firewall_allowed_sql
WHERE  username='UA_D3_READER'
ORDER  BY version,
          allowed_sql_id;
```

Violation side:

```sql
SELECT occurred_at,
       sql_signature,
       current_user,
       top_level,
       cause,
       ip_address,
       os_user,
       client_program,
       sql_text
FROM   dba_sql_firewall_violations
WHERE  username='UA_D3_READER'
ORDER  BY occurred_at DESC
FETCH FIRST 20 ROWS ONLY;
```

Checklist:

```text
signature sama?
current_user sama?
top_level sama?
allow-list version sudah update?
ENFORCE_SQL atau ENFORCE_ALL?
trusted context berubah?
```

---

# Lab 58 — Troubleshooting Missing Sensitive Audit

## Step 1 — Check Policy Definition

```sql
SELECT policy_name,
       audit_option,
       object_schema,
       object_name
FROM   audit_unified_policies
WHERE  policy_name='UA_D4_SENSITIVE_ACCESS'
ORDER  BY audit_option;
```

## Step 2 — Check Enabled State

```sql
SELECT policy_name,
       entity_name,
       success,
       failure
FROM   audit_unified_enabled_policies
WHERE  policy_name='UA_D4_SENSITIVE_ACCESS';
```

## Step 3 — Check Actual Trail

```sql
SELECT COUNT(*) AS sensitive_records
FROM   unified_audit_trail
WHERE  dbusername='UA_D3_READER'
AND    object_schema='UA_D3_APP'
AND    object_name='CUSTOMER_SECURE';
```

Checklist:

```text
policy definition benar?
policy enabled?
user yang diuji benar?
object schema/name benar?
query benar-benar dieksekusi?
UNIFIED_AUDIT_TRAIL berisi event?
```

---

# PART M — POLICY GOVERNANCE VALIDATION

---

# Lab 59 — Prove Legitimate SQL Was Approved but Suspicious SQL Was Not

## Command

```sql
SELECT
    (SELECT COUNT(*)
     FROM   dba_sql_firewall_allowed_sql
     WHERE  username='UA_D3_READER'
     AND    UPPER(sql_text) LIKE '%WHERE CITY%') AS legitimate_city_allowed,

    (SELECT COUNT(*)
     FROM   dba_sql_firewall_allowed_sql
     WHERE  username='UA_D3_READER'
     AND    REGEXP_LIKE(UPPER(sql_text), 'MAX[[:space:]]*[(]CREDIT_LIMIT[)]')) AS suspicious_max_allowed,

    (SELECT COUNT(*)
     FROM   dba_sql_firewall_violations
     WHERE  username='UA_D3_READER'
     AND    REGEXP_LIKE(UPPER(sql_text), 'MAX[[:space:]]*[(]CREDIT_LIMIT[)]')) AS suspicious_max_violations
FROM dual;
```

## Penjelasan

Inilah inti policy governance:

```text
violation
   ↓
review
  /   \
legit suspicious
  |      |
approve investigate
```

---

# Lab 60 — Set Final Handson 5 Safe State

Pastikan policy kembali detective-first:

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

**Output hasil eksekusi akhir**

```text
USERNAME      STATUS   ENFORCE      BLOCK
------------- -------- ------------ -----
UA_D3_READER  ENABLED  ENFORCE_ALL  N

1 row selected.
```

Verify capture stopped:

```sql
SELECT username,
       status
FROM   dba_sql_firewall_captures
WHERE  username='UA_D3_READER';
```

Verify reader privilege restored:

```sql
SELECT privilege
FROM   dba_tab_privs
WHERE  grantee='UA_D3_READER'
AND    owner='UA_D3_APP'
AND    table_name='CUSTOMER_SECURE'
ORDER  BY privilege;
```

## Final Handson 5 State

```text
SQL Firewall              : ENABLED
Protected User            : UA_D3_READER
Allow-List                : ENABLED
Enforcement               : ENFORCE_ALL
Blocking                  : FALSE
Capture                   : STOPPED
Sensitive Audit Policy    : ENABLED
Authentication Audit      : ENABLED
Temporary UPDATE grant    : REVOKED
Evidence package          : /tmp/ua_d4_evidence
```

State ini sengaja dipertahankan agar dapat dipakai oleh lab lanjutan / Day 5.

---

# PART N — OPTIONAL Handson 5 RESET

> Jalankan hanya jika ingin mengulang Handson 5 dari awal.
>
> **Jangan jalankan bagian ini jika environment akan dipakai oleh Day 5.**

---

# Lab 61 — Disable and Drop Handson 5 Sensitive Audit Policy

```sql
NOAUDIT POLICY ua_d4_sensitive_access BY ua_d3_reader;
```

```sql
DROP AUDIT POLICY ua_d4_sensitive_access;
```

---

# Lab 62 — Disable and Drop Handson 5 Authentication Audit Policy

```sql
NOAUDIT POLICY ua_d4_authentication BY ua_d3_reader;
```

```sql
DROP AUDIT POLICY ua_d4_authentication;
```

---

# Lab 63 — Remove Handson 5 Evidence Files

From SQL*Plus:

```sql
HOST rm -rf /tmp/ua_d4_evidence
```

Verify:

```sql
HOST test ! -d /tmp/ua_d4_evidence && echo "Handson 5 evidence directory removed"
```

## Important

Optional reset ini **tidak** menghapus:

```text
UA_D3_APP
UA_D3_READER
Handson 4 SQL Firewall allow-list
Handson 4 capture object
UA_D3_SQLFW_VIOLATION
```

karena semua itu merupakan state yang berasal dari Handson 4.

---

# PART O — Handson 5 QUICK COMMAND CHEAT SHEET

---
## Current Policy State

```sql
SELECT username,
       status,
       enforce,
       block
FROM   dba_sql_firewall_allow_lists
WHERE  username='UA_D3_READER';
```

## Start Controlled Capture

```sql
EXEC DBMS_SQL_FIREWALL.START_CAPTURE('UA_D3_READER');
```

## Stop Capture

```sql
EXEC DBMS_SQL_FIREWALL.STOP_CAPTURE('UA_D3_READER');
```

## Append One Reviewed Capture SQL

```sql
BEGIN
    DBMS_SQL_FIREWALL.APPEND_ALLOW_LIST_SINGLE_SQL(
        username      => 'UA_D3_READER',
        sql_signature => '<signature>',
        current_user  => 'UA_D3_READER',
        top_level     => 'Y',
        source        => DBMS_SQL_FIREWALL.CAPTURE_LOG
    );
END;
/
```

## Detective Mode

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

## Latest Violations

```sql
SELECT occurred_at,
       cause,
       firewall_action,
       accessed_objects,
       sql_text
FROM   dba_sql_firewall_violations
WHERE  username='UA_D3_READER'
ORDER  BY occurred_at DESC
FETCH FIRST 20 ROWS ONLY;
```

## Sensitive Audit

```sql
SELECT event_timestamp,
       action_name,
       object_schema,
       object_name,
       return_code
FROM   unified_audit_trail
WHERE  dbusername='UA_D3_READER'
AND    object_name='CUSTOMER_SECURE'
ORDER  BY event_timestamp DESC;
```

## Failed Logins

```sql
SELECT event_timestamp,
       dbusername,
       return_code,
       userhost,
       client_program_name
FROM   unified_audit_trail
WHERE  dbusername='UA_D3_READER'
AND    action_name='LOGON'
AND    return_code <> 0
ORDER  BY event_timestamp DESC;
```

---

# PART P — END-TO-END Handson 5 MENTAL MODEL

```text
                         TRUSTED WORKLOAD
                               │
                               ▼
                            CAPTURE
                               │
                               ▼
                     NORMALIZED SIGNATURES
                               │
                               ▼
                           ALLOW-LIST
                   ┌───────────┼───────────┐
                   │           │           │
                   ▼           ▼           ▼
                SQL rules    IP ctx    OS/program ctx
                   │           │           │
                   └───────────┼───────────┘
                               ▼
                         RUNTIME CHECK
                        ┌───────┴────────┐
                        ▼                ▼
                     MATCH            VIOLATION
                        │                │
                        ▼                ▼
                     NORMAL          CLASSIFY
                                         │
                           ┌─────────────┼──────────────┐
                           ▼             ▼              ▼
                     CONTEXT DEV    SENSITIVE SQL    OTHER SQL
                     CRITICAL        MAJOR           MODERATE
                           │             │              │
                           └─────────────┼──────────────┘
                                         ▼
                                    INVESTIGATE
                                         │
                              ┌──────────┴──────────┐
                              ▼                     ▼
                         LEGITIMATE             SUSPICIOUS
                              │                     │
                              ▼                     ▼
                         APPROVE ONE           DO NOT APPROVE
                              │                     │
                              ▼                     ▼
                       VERSION UPDATE          KEEP DEVIATION
                              │                     │
                              └──────────┬──────────┘
                                         ▼
                                      MONITOR
                                         │
                     ┌───────────────────┴───────────────────┐
                     ▼                                       ▼
          DBA_SQL_FIREWALL_VIOLATIONS              UNIFIED_AUDIT_TRAIL
                     │                                       │
                     │                              ┌────────┴────────┐
                     │                              ▼                 ▼
                     │                       sensitive access    failed login
                     │
                     └──────────────────────┬───────────────────────┘
                                            ▼
                                         CORRELATE
                                            │
                                            ▼
                                     INCIDENT TIMELINE
                                            │
                                  ┌─────────┴─────────┐
                                  ▼                   ▼
                                CSV                 JSON
                                  │                   │
                                  └─────────┬─────────┘
                                            ▼
                                      EVIDENCE PACKAGE
```

---
