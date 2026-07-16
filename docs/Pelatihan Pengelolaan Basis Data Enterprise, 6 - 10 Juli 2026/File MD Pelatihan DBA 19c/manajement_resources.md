# HANDS-ON LAB

# Resource Management Oracle 19c CDB/PDB

Asumsi:

```text
CDB     : ORADB
PDB     : PDB1
OS      : Oracle Linux
Oracle  : 19c
User OS : oracle
```

---

# 0. Persiapan Awal

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

Verifikasi PDB:

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

Masuk ke PDB:

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

---

# LAB 1 — Mengecek Resource Limit Database

## 1.1 Cek parameter resource limit

```sql
SHOW PARAMETER resource_limit
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- -----
resource_limit                       boolean     FALSE
```

## 1.2 Aktifkan resource limit

```sql
CONN / AS SYSDBA

ALTER SYSTEM SET resource_limit = TRUE SCOPE=BOTH;
```

Contoh output:

```text
System altered.
```

## 1.3 Verifikasi

```sql
SHOW PARAMETER resource_limit
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- -----
resource_limit                       boolean     TRUE
```

---

# LAB 2 — Membuat Tablespace dan User Lab

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

## 2.1 Buat tablespace

```sql
CREATE TABLESPACE TS_RSRC_LAB
DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/ts_rsrc_lab01.dbf'
SIZE 100M
AUTOEXTEND ON
NEXT 50M
MAXSIZE 1G;
```

Contoh output:

```text
Tablespace created.
```

## 2.2 Buat user lab

```sql
CREATE USER rsrc_user IDENTIFIED BY oracle
DEFAULT TABLESPACE TS_RSRC_LAB
TEMPORARY TABLESPACE TEMP
QUOTA UNLIMITED ON TS_RSRC_LAB;
```

Contoh output:

```text
User created.
```

## 2.3 Grant privilege

```sql
GRANT CREATE SESSION, CREATE TABLE TO rsrc_user;
```

Contoh output:

```text
Grant succeeded.
```

## 2.4 Verifikasi user

```sql
SELECT username,
       account_status,
       default_tablespace,
       profile
FROM dba_users
WHERE username = 'RSRC_USER';
```

Contoh output:

```text
USERNAME        ACCOUNT_STATUS       DEFAULT_TABLESPACE   PROFILE
--------------- -------------------- -------------------- ----------
RSRC_USER       OPEN                 TS_RSRC_LAB          DEFAULT
```

---

# LAB 3 — Membuat Profile Resource Limit

## 3.1 Buat profile

```sql
CREATE PROFILE profile_rsrc_lab LIMIT
  SESSIONS_PER_USER 2
  IDLE_TIME 5
  CONNECT_TIME 60
  CPU_PER_SESSION UNLIMITED
  CPU_PER_CALL UNLIMITED
  LOGICAL_READS_PER_SESSION UNLIMITED
  LOGICAL_READS_PER_CALL UNLIMITED
  PRIVATE_SGA UNLIMITED
  FAILED_LOGIN_ATTEMPTS 3
  PASSWORD_LOCK_TIME 1;
```

Contoh output:

```text
Profile created.
```

## 3.2 Assign profile ke user

```sql
ALTER USER rsrc_user PROFILE profile_rsrc_lab;
```

Contoh output:

```text
User altered.
```

## 3.3 Verifikasi profile user

```sql
SELECT username,
       profile
FROM dba_users
WHERE username = 'RSRC_USER';
```

Contoh output:

```text
USERNAME        PROFILE
--------------- --------------------
RSRC_USER       PROFILE_RSRC_LAB
```

## 3.4 Verifikasi isi profile

```sql
COLUMN profile FORMAT A20
COLUMN resource_name FORMAT A30
COLUMN limit FORMAT A20

SELECT profile,
       resource_name,
       limit
FROM dba_profiles
WHERE profile = 'PROFILE_RSRC_LAB'
ORDER BY resource_name;
```

Contoh output:

```text
PROFILE              RESOURCE_NAME                  LIMIT
-------------------- ------------------------------ --------------------
PROFILE_RSRC_LAB     CONNECT_TIME                   60
PROFILE_RSRC_LAB     FAILED_LOGIN_ATTEMPTS          3
PROFILE_RSRC_LAB     IDLE_TIME                      5
PROFILE_RSRC_LAB     PASSWORD_LOCK_TIME             1
PROFILE_RSRC_LAB     SESSIONS_PER_USER              2
```

---

# LAB 4 — Test SESSIONS_PER_USER

## 4.1 Buka session pertama

Terminal 1:

```bash
sqlplus rsrc_user/oracle@localhost:1521/pdb1.localdomain
```

Contoh output:

```text
Connected.
```

## 4.2 Buka session kedua

Terminal 2:

```bash
sqlplus rsrc_user/oracle@localhost:1521/pdb1.localdomain
```

Contoh output:

```text
Connected.
```

## 4.3 Buka session ketiga

Terminal 3:

```bash
sqlplus rsrc_user/oracle@localhost:1521/pdb1.localdomain
```

Contoh error:

```text
ORA-02391: exceeded simultaneous SESSIONS_PER_USER limit
```

## 4.4 Verifikasi session aktif

Dari SYS:

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

SELECT username,
       COUNT(*) AS jumlah_session
FROM v$session
WHERE username = 'RSRC_USER'
GROUP BY username;
```

Contoh output:

```text
USERNAME        JUMLAH_SESSION
--------------- --------------
RSRC_USER                    2
```

---

# LAB 5 — Mengubah Resource Limit Profile

## 5.1 Ubah limit session menjadi 3

```sql
ALTER PROFILE profile_rsrc_lab LIMIT
  SESSIONS_PER_USER 3;
```

Contoh output:

```text
Profile altered.
```

## 5.2 Verifikasi

```sql
SELECT profile,
       resource_name,
       limit
FROM dba_profiles
WHERE profile = 'PROFILE_RSRC_LAB'
AND resource_name = 'SESSIONS_PER_USER';
```

Contoh output:

```text
PROFILE              RESOURCE_NAME                  LIMIT
-------------------- ------------------------------ -----
PROFILE_RSRC_LAB     SESSIONS_PER_USER              3
```

## 5.3 Test login session ketiga lagi

```bash
sqlplus rsrc_user/oracle@localhost:1521/pdb1.localdomain
```

Contoh output:

```text
Connected.
```

---

# LAB 6 — Membatasi Idle Time

## 6.1 Ubah idle time menjadi 1 menit

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

ALTER PROFILE profile_rsrc_lab LIMIT IDLE_TIME 1;
```

Contoh output:

```text
Profile altered.
```

## 6.2 Verifikasi

```sql
SELECT profile,
       resource_name,
       limit
FROM dba_profiles
WHERE profile = 'PROFILE_RSRC_LAB'
AND resource_name = 'IDLE_TIME';
```

Contoh output:

```text
PROFILE              RESOURCE_NAME                  LIMIT
-------------------- ------------------------------ -----
PROFILE_RSRC_LAB     IDLE_TIME                      1
```

## 6.3 Test idle

Login sebagai user:

```bash
sqlplus rsrc_user/oracle@localhost:1521/pdb1.localdomain
```

Diamkan lebih dari 1 menit, lalu jalankan:

```sql
SELECT SYSDATE FROM dual;
```

Contoh error:

```text
ORA-02396: exceeded maximum idle time, please connect again
```

---

# LAB 7 — Membatasi Connect Time

## 7.1 Ubah connect time menjadi 2 menit

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

ALTER PROFILE profile_rsrc_lab LIMIT CONNECT_TIME 2;
```

Contoh output:

```text
Profile altered.
```

## 7.2 Verifikasi

```sql
SELECT profile,
       resource_name,
       limit
FROM dba_profiles
WHERE profile = 'PROFILE_RSRC_LAB'
AND resource_name = 'CONNECT_TIME';
```

Contoh output:

```text
PROFILE              RESOURCE_NAME                  LIMIT
-------------------- ------------------------------ -----
PROFILE_RSRC_LAB     CONNECT_TIME                   2
```

## 7.3 Test connect time

Login:

```bash
sqlplus rsrc_user/oracle@localhost:1521/pdb1.localdomain
```

Tunggu lebih dari 2 menit, lalu jalankan:

```sql
SELECT SYSDATE FROM dual;
```

Contoh error:

```text
ORA-02399: exceeded maximum connect time, you are being logged off
```

---

# LAB 8 — Monitoring Session Resource

## 8.1 Lihat session user

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

COLUMN username FORMAT A15
COLUMN status FORMAT A10
COLUMN event FORMAT A35

SELECT sid,
       serial#,
       username,
       status,
       event,
       last_call_et
FROM v$session
WHERE username = 'RSRC_USER';
```

Contoh output:

```text
       SID    SERIAL# USERNAME        STATUS     EVENT                               LAST_CALL_ET
---------- ---------- --------------- ---------- ----------------------------------- ------------
        82      14021 RSRC_USER       INACTIVE   SQL*Net message from client                  65
        91      28211 RSRC_USER       ACTIVE     db file scattered read                         4
```

Keterangan:

```text
LAST_CALL_ET menunjukkan lama session berada pada status saat ini dalam detik.
```

## 8.2 Kill session yang idle terlalu lama

Ganti SID dan SERIAL# sesuai hasil query.

```sql
ALTER SYSTEM KILL SESSION '82,14021' IMMEDIATE;
```

Contoh output:

```text
System altered.
```

## 8.3 Verifikasi session

```sql
SELECT sid,
       serial#,
       username,
       status
FROM v$session
WHERE username = 'RSRC_USER';
```

Contoh output:

```text
       SID    SERIAL# USERNAME        STATUS
---------- ---------- --------------- ----------
        91      28211 RSRC_USER       ACTIVE
```

---

# LAB 9 — Membatasi Quota Tablespace

## 9.1 Set quota kecil

```sql
ALTER USER rsrc_user QUOTA 5M ON TS_RSRC_LAB;
```

Contoh output:

```text
User altered.
```

## 9.2 Verifikasi quota

```sql
SELECT username,
       tablespace_name,
       bytes/1024/1024 AS used_mb,
       max_bytes/1024/1024 AS max_mb
FROM dba_ts_quotas
WHERE username = 'RSRC_USER';
```

Contoh output:

```text
USERNAME        TABLESPACE_NAME         USED_MB     MAX_MB
--------------- -------------------- ---------- ----------
RSRC_USER       TS_RSRC_LAB                  0          5
```

## 9.3 Buat tabel besar sampai quota penuh

```sql
CONN rsrc_user/oracle@localhost:1521/pdb1.localdomain

CREATE TABLE quota_test AS
SELECT LEVEL AS id,
       RPAD('DATA RESOURCE TEST', 1000, 'X') AS data_text
FROM dual
CONNECT BY LEVEL <= 20000;
```

Contoh error jika melebihi quota:

```text
ORA-01536: space quota exceeded for tablespace 'TS_RSRC_LAB'
```

## 9.4 Naikkan quota

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

ALTER USER rsrc_user QUOTA 100M ON TS_RSRC_LAB;
```

Contoh output:

```text
User altered.
```

## 9.5 Coba ulang

```sql
CONN rsrc_user/oracle@localhost:1521/pdb1.localdomain

CREATE TABLE quota_test AS
SELECT LEVEL AS id,
       RPAD('DATA RESOURCE TEST', 1000, 'X') AS data_text
FROM dual
CONNECT BY LEVEL <= 20000;
```

Contoh output:

```text
Table created.
```

---

# LAB 10 — Membuat Resource Consumer Group

Bagian ini menggunakan **Database Resource Manager**.

## 10.1 Masuk ke root

```sql
CONN / AS SYSDBA
```

## 10.2 Cek plan aktif

```sql
SHOW PARAMETER resource_manager_plan
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
resource_manager_plan                string
```

## 10.3 Buat pending area

```sql
BEGIN
  DBMS_RESOURCE_MANAGER.CREATE_PENDING_AREA();
END;
/
```

Contoh output:

```text
PL/SQL procedure successfully completed.
```

## 10.4 Buat consumer group

```sql
BEGIN
  DBMS_RESOURCE_MANAGER.CREATE_CONSUMER_GROUP(
    consumer_group => 'CG_APP_HIGH',
    comment        => 'Consumer group for high priority application users'
  );

  DBMS_RESOURCE_MANAGER.CREATE_CONSUMER_GROUP(
    consumer_group => 'CG_APP_LOW',
    comment        => 'Consumer group for low priority application users'
  );
END;
/
```

Contoh output:

```text
PL/SQL procedure successfully completed.
```

## 10.5 Verifikasi consumer group

```sql
SELECT consumer_group,
       status
FROM dba_rsrc_consumer_groups
WHERE consumer_group IN ('CG_APP_HIGH','CG_APP_LOW');
```

Contoh output:

```text
CONSUMER_GROUP       STATUS
-------------------- ----------
CG_APP_HIGH          PENDING
CG_APP_LOW           PENDING
```

---

# LAB 11 — Membuat Resource Plan

## 11.1 Buat plan

```sql
BEGIN
  DBMS_RESOURCE_MANAGER.CREATE_PLAN(
    plan    => 'PLAN_APP_LAB',
    comment => 'Resource plan for application lab'
  );
END;
/
```

Contoh output:

```text
PL/SQL procedure successfully completed.
```

## 11.2 Buat directive untuk consumer group

```sql
BEGIN
  DBMS_RESOURCE_MANAGER.CREATE_PLAN_DIRECTIVE(
    plan             => 'PLAN_APP_LAB',
    group_or_subplan => 'CG_APP_HIGH',
    comment          => 'High priority users',
    mgmt_p1          => 80
  );

  DBMS_RESOURCE_MANAGER.CREATE_PLAN_DIRECTIVE(
    plan             => 'PLAN_APP_LAB',
    group_or_subplan => 'CG_APP_LOW',
    comment          => 'Low priority users',
    mgmt_p1          => 20
  );

  DBMS_RESOURCE_MANAGER.CREATE_PLAN_DIRECTIVE(
    plan             => 'PLAN_APP_LAB',
    group_or_subplan => 'OTHER_GROUPS',
    comment          => 'Default group',
    mgmt_p1          => 5
  );
END;
/
```

Contoh output:

```text
PL/SQL procedure successfully completed.
```

## 11.3 Validasi pending area

```sql
BEGIN
  DBMS_RESOURCE_MANAGER.VALIDATE_PENDING_AREA();
END;
/
```

Contoh output:

```text
PL/SQL procedure successfully completed.
```

## 11.4 Submit pending area

```sql
BEGIN
  DBMS_RESOURCE_MANAGER.SUBMIT_PENDING_AREA();
END;
/
```

Contoh output:

```text
PL/SQL procedure successfully completed.
```

## 11.5 Verifikasi plan

```sql
SELECT plan,
       comments,
       status
FROM dba_rsrc_plans
WHERE plan = 'PLAN_APP_LAB';
```

Contoh output:

```text
PLAN             COMMENTS                           STATUS
---------------- ---------------------------------- ----------
PLAN_APP_LAB     Resource plan for application lab   ACTIVE
```

## 11.6 Verifikasi directive

```sql
SELECT plan,
       group_or_subplan,
       mgmt_p1
FROM dba_rsrc_plan_directives
WHERE plan = 'PLAN_APP_LAB'
ORDER BY group_or_subplan;
```

Contoh output:

```text
PLAN             GROUP_OR_SUBPLAN       MGMT_P1
---------------- -------------------- ---------
PLAN_APP_LAB     CG_APP_HIGH                80
PLAN_APP_LAB     CG_APP_LOW                 20
PLAN_APP_LAB     OTHER_GROUPS                5
```

---

# LAB 12 — Grant Switch Consumer Group ke User

## 12.1 Grant switch privilege

```sql
BEGIN
  DBMS_RESOURCE_MANAGER_PRIVS.GRANT_SWITCH_CONSUMER_GROUP(
    grantee_name   => 'RSRC_USER',
    consumer_group => 'CG_APP_LOW',
    grant_option   => FALSE
  );

  DBMS_RESOURCE_MANAGER_PRIVS.GRANT_SWITCH_CONSUMER_GROUP(
    grantee_name   => 'RSRC_USER',
    consumer_group => 'CG_APP_HIGH',
    grant_option   => FALSE
  );
END;
/
```

Contoh output:

```text
PL/SQL procedure successfully completed.
```

## 12.2 Verifikasi privilege

```sql
SELECT grantee,
       granted_group,
       grant_option
FROM dba_rsrc_consumer_group_privs
WHERE grantee = 'RSRC_USER';
```

Contoh output:

```text
GRANTEE              GRANTED_GROUP        GRANT_OPTION
-------------------- -------------------- ------------
RSRC_USER            CG_APP_HIGH          NO
RSRC_USER            CG_APP_LOW           NO
```

---

# LAB 13 — Mapping User ke Consumer Group

## 13.1 Buat mapping user ke consumer group

```sql
BEGIN
  DBMS_RESOURCE_MANAGER.CREATE_PENDING_AREA();

  DBMS_RESOURCE_MANAGER.SET_CONSUMER_GROUP_MAPPING(
    attribute      => DBMS_RESOURCE_MANAGER.ORACLE_USER,
    value          => 'RSRC_USER',
    consumer_group => 'CG_APP_LOW'
  );

  DBMS_RESOURCE_MANAGER.VALIDATE_PENDING_AREA();
  DBMS_RESOURCE_MANAGER.SUBMIT_PENDING_AREA();
END;
/
```

Contoh output:

```text
PL/SQL procedure successfully completed.
```

## 13.2 Verifikasi mapping

```sql
SELECT attribute,
       value,
       consumer_group
FROM dba_rsrc_group_mappings
WHERE value = 'RSRC_USER';
```

Contoh output:

```text
ATTRIBUTE            VALUE                CONSUMER_GROUP
-------------------- -------------------- --------------------
ORACLE_USER          RSRC_USER            CG_APP_LOW
```

---

# LAB 14 — Mengaktifkan Resource Manager Plan

## 14.1 Aktifkan plan

```sql
ALTER SYSTEM SET resource_manager_plan = 'PLAN_APP_LAB' SCOPE=BOTH;
```

Contoh output:

```text
System altered.
```

## 14.2 Verifikasi

```sql
SHOW PARAMETER resource_manager_plan
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- ----------------
resource_manager_plan                string      PLAN_APP_LAB
```

---

# LAB 15 — Verifikasi Consumer Group Session

## 15.1 Login sebagai rsrc_user

```bash
sqlplus rsrc_user/oracle@localhost:1521/pdb1.localdomain
```

Contoh output:

```text
Connected.
```

## 15.2 Cek consumer group session

Dari SYS:

```sql
CONN / AS SYSDBA
ALTER SESSION SET CONTAINER=PDB1;

COLUMN username FORMAT A15
COLUMN resource_consumer_group FORMAT A25

SELECT sid,
       serial#,
       username,
       resource_consumer_group
FROM v$session
WHERE username = 'RSRC_USER';
```

Contoh output:

```text
       SID    SERIAL# USERNAME        RESOURCE_CONSUMER_GROUP
---------- ---------- --------------- -------------------------
        82      18421 RSRC_USER       CG_APP_LOW
```

---

# LAB 16 — Switch Consumer Group Manual

## 16.1 Switch session ke CG_APP_HIGH

Ganti SID dan SERIAL# sesuai hasil query.

```sql
BEGIN
  DBMS_RESOURCE_MANAGER.SWITCH_CONSUMER_GROUP_FOR_SESS(
    session_id     => 82,
    session_serial => 18421,
    consumer_group => 'CG_APP_HIGH'
  );
END;
/
```

Contoh output:

```text
PL/SQL procedure successfully completed.
```

## 16.2 Verifikasi

```sql
SELECT sid,
       serial#,
       username,
       resource_consumer_group
FROM v$session
WHERE username = 'RSRC_USER';
```

Contoh output:

```text
       SID    SERIAL# USERNAME        RESOURCE_CONSUMER_GROUP
---------- ---------- --------------- -------------------------
        82      18421 RSRC_USER       CG_APP_HIGH
```

---

# LAB 17 — Membuat Workload CPU

## 17.1 Buat procedure workload

```sql
CONN rsrc_user/oracle@localhost:1521/pdb1.localdomain

CREATE OR REPLACE PROCEDURE cpu_workload AS
  v_num NUMBER := 0;
BEGIN
  FOR i IN 1..5000000 LOOP
    v_num := SQRT(i) * DBMS_RANDOM.VALUE;
  END LOOP;
END;
/
```

Contoh output:

```text
Procedure created.
```

## 17.2 Jalankan workload

```sql
SET TIMING ON

EXEC cpu_workload;
```

Contoh output:

```text
PL/SQL procedure successfully completed.

Elapsed: 00:00:12.40
```

## 17.3 Monitoring resource manager metric

Dari SYS:

```sql
CONN / AS SYSDBA

COLUMN consumer_group_name FORMAT A25

SELECT consumer_group_name,
       cpu_consumed_time,
       cpu_wait_time,
       requests,
       active_sessions
FROM v$rsrc_consumer_group
WHERE consumer_group_name IN ('CG_APP_HIGH','CG_APP_LOW');
```

Contoh output:

```text
CONSUMER_GROUP_NAME       CPU_CONSUMED_TIME CPU_WAIT_TIME   REQUESTS ACTIVE_SESSIONS
------------------------- ----------------- ------------- ---------- ---------------
CG_APP_HIGH                            8200             0         10               1
CG_APP_LOW                             2100          1500          8               1
```

---

# LAB 18 — Resource Management Antar PDB

Resource Manager juga dapat mengatur resource antar PDB dari CDB root.

## 18.1 Cek metric PDB

```sql
CONN / AS SYSDBA

COLUMN name FORMAT A20

SELECT p.name,
       m.cpu_consumed_time,
       m.cpu_wait_time,
       m.io_requests,
       m.io_megabytes
FROM v$rsrcpdbmetric m
JOIN v$pdbs p
ON m.con_id = p.con_id
ORDER BY p.name;
```

Contoh output:

```text
NAME                 CPU_CONSUMED_TIME CPU_WAIT_TIME IO_REQUESTS IO_MEGABYTES
-------------------- ----------------- ------------- ----------- ------------
PDB1                              5200             0        2500          350
```

## 18.2 Cek PDB directive

```sql
SELECT plan,
       pluggable_database,
       shares,
       utilization_limit
FROM dba_cdb_rsrc_plan_directives
ORDER BY plan, pluggable_database;
```

Contoh output:

```text
PLAN             PLUGGABLE_DATABASE   SHARES UTILIZATION_LIMIT
---------------- -------------------- ------ -----------------
DEFAULT_CDB_PLAN PDB1                      1               100
```

---

# LAB 19 — Membatasi Utilization PDB

Contoh membatasi PDB1 agar maksimal memakai 50% CPU instance.

## 19.1 Buat CDB resource plan

```sql
CONN / AS SYSDBA

BEGIN
  DBMS_RESOURCE_MANAGER.CREATE_PENDING_AREA();

  DBMS_RESOURCE_MANAGER.CREATE_CDB_PLAN(
    plan    => 'CDB_PLAN_LAB',
    comment => 'CDB resource plan lab'
  );

  DBMS_RESOURCE_MANAGER.CREATE_CDB_PLAN_DIRECTIVE(
    plan               => 'CDB_PLAN_LAB',
    pluggable_database => 'PDB1',
    shares             => 1,
    utilization_limit  => 50
  );

  DBMS_RESOURCE_MANAGER.CREATE_CDB_PLAN_DIRECTIVE(
    plan               => 'CDB_PLAN_LAB',
    pluggable_database => 'ORA$AUTOTASK',
    shares             => 1,
    utilization_limit  => 100
  );

  DBMS_RESOURCE_MANAGER.VALIDATE_PENDING_AREA();
  DBMS_RESOURCE_MANAGER.SUBMIT_PENDING_AREA();
END;
/
```

Contoh output:

```text
PL/SQL procedure successfully completed.
```

## 19.2 Aktifkan CDB plan

```sql
ALTER SYSTEM SET resource_manager_plan = 'CDB_PLAN_LAB' SCOPE=BOTH;
```

Contoh output:

```text
System altered.
```

## 19.3 Verifikasi

```sql
SHOW PARAMETER resource_manager_plan
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------
resource_manager_plan                string      CDB_PLAN_LAB
```

## 19.4 Verifikasi directive

```sql
SELECT plan,
       pluggable_database,
       shares,
       utilization_limit
FROM dba_cdb_rsrc_plan_directives
WHERE plan = 'CDB_PLAN_LAB';
```

Contoh output:

```text
PLAN             PLUGGABLE_DATABASE   SHARES UTILIZATION_LIMIT
---------------- -------------------- ------ -----------------
CDB_PLAN_LAB     PDB1                      1                50
CDB_PLAN_LAB     ORA$AUTOTASK              1               100
```

---

# LAB 20 — Membatasi PGA di Level PDB

## 20.1 Masuk ke PDB1

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

## 20.2 Cek parameter PGA PDB

```sql
SHOW PARAMETER pga_aggregate_target
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- -----
pga_aggregate_target                 big integer 500M
```

## 20.3 Set PGA PDB

```sql
ALTER SYSTEM SET pga_aggregate_target = 300M;
```

Contoh output:

```text
System altered.
```

## 20.4 Verifikasi

```sql
SHOW PARAMETER pga_aggregate_target
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- -----
pga_aggregate_target                 big integer 300M
```

## 20.5 Cek dari root

```sql
CONN / AS SYSDBA

SELECT con_id,
       name,
       value
FROM v$system_parameter
WHERE name = 'pga_aggregate_target'
ORDER BY con_id;
```

Contoh output:

```text
    CON_ID NAME                      VALUE
---------- ------------------------- ----------
         0 pga_aggregate_target      524288000
         3 pga_aggregate_target      314572800
```

---

# LAB 21 — Membatasi Storage PDB

## 21.1 Set limit storage PDB

```sql
CONN / AS SYSDBA

ALTER PLUGGABLE DATABASE PDB1 STORAGE (MAXSIZE 3G);
```

Contoh output:

```text
Pluggable database altered.
```

## 21.2 Verifikasi

```sql
COLUMN pdb_name FORMAT A20

SELECT pdb_name,
       storage_size/1024/1024 AS storage_mb,
       max_size/1024/1024 AS max_mb
FROM cdb_pdbs
WHERE pdb_name = 'PDB1';
```

Contoh output:

```text
PDB_NAME             STORAGE_MB     MAX_MB
-------------------- ---------- ----------
PDB1                     1200       3072
```

## 21.3 Kembalikan unlimited

```sql
ALTER PLUGGABLE DATABASE PDB1 STORAGE UNLIMITED;
```

Contoh output:

```text
Pluggable database altered.
```

---

# LAB 22 — Monitoring Resource Limit

```sql
CONN / AS SYSDBA

COLUMN resource_name FORMAT A30

SELECT resource_name,
       current_utilization,
       max_utilization,
       initial_allocation,
       limit_value
FROM v$resource_limit
ORDER BY resource_name;
```

Contoh output:

```text
RESOURCE_NAME                  CURRENT_UTILIZATION MAX_UTILIZATION INITIAL_ALLOCATION LIMIT_VALUE
------------------------------ ------------------- --------------- ------------------ -----------
processes                                      92             110                300         300
sessions                                      105             125                472         472
transactions                                    0              10                519   UNLIMITED
```

---

# LAB 23 — Cleanup Resource Manager Plan

## 23.1 Nonaktifkan resource manager plan

```sql
CONN / AS SYSDBA

ALTER SYSTEM SET resource_manager_plan = '' SCOPE=BOTH;
```

Contoh output:

```text
System altered.
```

Verifikasi:

```sql
SHOW PARAMETER resource_manager_plan
```

Contoh output:

```text
NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
resource_manager_plan                string
```

## 23.2 Hapus CDB plan

```sql
BEGIN
  DBMS_RESOURCE_MANAGER.CREATE_PENDING_AREA();

  DBMS_RESOURCE_MANAGER.DELETE_CDB_PLAN_CASCADE(
    plan => 'CDB_PLAN_LAB'
  );

  DBMS_RESOURCE_MANAGER.VALIDATE_PENDING_AREA();
  DBMS_RESOURCE_MANAGER.SUBMIT_PENDING_AREA();
END;
/
```

Contoh output:

```text
PL/SQL procedure successfully completed.
```

## 23.3 Hapus database resource plan

```sql
BEGIN
  DBMS_RESOURCE_MANAGER.CREATE_PENDING_AREA();

  DBMS_RESOURCE_MANAGER.DELETE_PLAN_CASCADE(
    plan => 'PLAN_APP_LAB'
  );

  DBMS_RESOURCE_MANAGER.VALIDATE_PENDING_AREA();
  DBMS_RESOURCE_MANAGER.SUBMIT_PENDING_AREA();
END;
/
```

Contoh output:

```text
PL/SQL procedure successfully completed.
```

---

# LAB 24 — Cleanup User, Profile, Tablespace

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

Drop user:

```sql
DROP USER rsrc_user CASCADE;
```

Contoh output:

```text
User dropped.
```

Drop profile:

```sql
DROP PROFILE profile_rsrc_lab CASCADE;
```

Contoh output:

```text
Profile dropped.
```

Drop tablespace:

```sql
DROP TABLESPACE TS_RSRC_LAB INCLUDING CONTENTS AND DATAFILES;
```

Contoh output:

```text
Tablespace dropped.
```

Reset PGA PDB:

```sql
ALTER SYSTEM RESET pga_aggregate_target;
```

Contoh output:

```text
System altered.
```

Verifikasi cleanup:

```sql
SELECT username
FROM dba_users
WHERE username = 'RSRC_USER';
```

Contoh output:

```text
no rows selected
```

```sql
SELECT tablespace_name
FROM dba_tablespaces
WHERE tablespace_name = 'TS_RSRC_LAB';
```

Contoh output:

```text
no rows selected
```

---

# Ringkasan Command Penting

Aktifkan resource limit:

```sql
ALTER SYSTEM SET resource_limit = TRUE SCOPE=BOTH;
```

Buat profile:

```sql
CREATE PROFILE profile_rsrc_lab LIMIT
  SESSIONS_PER_USER 2
  IDLE_TIME 5
  CONNECT_TIME 60;
```

Assign profile:

```sql
ALTER USER rsrc_user PROFILE profile_rsrc_lab;
```

Ubah profile:

```sql
ALTER PROFILE profile_rsrc_lab LIMIT SESSIONS_PER_USER 3;
```

Kill session:

```sql
ALTER SYSTEM KILL SESSION 'sid,serial#' IMMEDIATE;
```

Buat consumer group:

```sql
BEGIN
  DBMS_RESOURCE_MANAGER.CREATE_PENDING_AREA();
  DBMS_RESOURCE_MANAGER.CREATE_CONSUMER_GROUP(
    consumer_group => 'CG_APP_LOW',
    comment => 'Low priority users'
  );
  DBMS_RESOURCE_MANAGER.SUBMIT_PENDING_AREA();
END;
/
```

Aktifkan resource manager plan:

```sql
ALTER SYSTEM SET resource_manager_plan = 'PLAN_APP_LAB' SCOPE=BOTH;
```

Switch consumer group:

```sql
BEGIN
  DBMS_RESOURCE_MANAGER.SWITCH_CONSUMER_GROUP_FOR_SESS(
    session_id     => 82,
    session_serial => 18421,
    consumer_group => 'CG_APP_HIGH'
  );
END;
/
```

Batasi storage PDB:

```sql
ALTER PLUGGABLE DATABASE PDB1 STORAGE (MAXSIZE 3G);
```

Batasi PGA PDB:

```sql
ALTER SESSION SET CONTAINER=PDB1;
ALTER SYSTEM SET pga_aggregate_target = 300M;
```
