# Handson 1 — Oracle Database Auditing Fundamentals


## Target Handson 1

Setelah menyelesaikan lab ini Anda akan memahami alur:

```text
User Activity
     │
     ▼
Oracle Database
     │
     ├── Audit Policy
     │
     ▼
Unified Auditing
     │
     ▼
UNIFIED_AUDIT_TRAIL
     │
     ▼
Investigation / Report
```

Hands-on Handson 1 akan mencakup:

1. Persiapan environment
2. Mengenali CDB/PDB
3. Memeriksa Unified Auditing
4. Mengenali Unified Audit Trail
5. Membuat schema lab
6. Generate aktivitas normal
7. Membuat audit policy
8. Enable/disable audit policy
9. Audit `SELECT`
10. Audit `INSERT`
11. Audit `UPDATE`
12. Audit `DELETE`
13. Audit `CREATE TABLE`
14. Audit `DROP TABLE`
15. Audit login berhasil
16. Audit login gagal
17. Investigasi `UNIFIED_AUDIT_TRAIL`
18. Membersihkan environment lab

---

# LAB 1 — Persiapan Environment

## 1.1 Login ke Oracle Linux

Gunakan user OS pemilik Oracle Database, biasanya `oracle`.

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

## 1.2 File format SQL*Plus untuk seluruh rangkaian lab

Buat sekali dari shell sebagai `oracle`. Pengaturan ini sudah disiapkan
hanya setelah login SQL*Plus pertama; setting yang sama tidak ditampilkan lagi
sebelum setiap command SQL di naskah ini.

```bash
cat > /tmp/security_lab_format.sql <<'EOF'
SET SQLBLANKLINES ON
SET LINESIZE 250
SET PAGESIZE 100
SET LONG 5000
SET LONGCHUNKSIZE 5000
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF
COLUMN EVENT_TIMESTAMP FORMAT A29
COLUMN EVENT_TIME FORMAT A29
COLUMN FIRST_EVENT FORMAT A29
COLUMN LAST_EVENT FORMAT A29
COLUMN DBUSERNAME FORMAT A15
COLUMN USERNAME FORMAT A15
COLUMN AUDIT_SOURCE FORMAT A10
COLUMN AUDIT_TYPE FORMAT A16
COLUMN ACTION_NAME FORMAT A20
COLUMN OBJECT_SCHEMA FORMAT A15
COLUMN OBJECT_NAME FORMAT A24
COLUMN POLICY_NAME FORMAT A30
COLUMN FGA_POLICY_NAME FORMAT A26
COLUMN UNIFIED_AUDIT_POLICIES FORMAT A45
COLUMN AUDIT_OPTION FORMAT A24
COLUMN SYSTEM_PRIVILEGE_USED FORMAT A24
COLUMN USERHOST FORMAT A22
COLUMN CLIENT_PROGRAM_NAME FORMAT A35
COLUMN CLIENT_IDENTIFIER FORMAT A24
COLUMN ENTITY_NAME FORMAT A18
COLUMN CUSTOMER_NAME FORMAT A20
COLUMN FULL_NAME FORMAT A20
COLUMN EMAIL FORMAT A25
COLUMN PHONE FORMAT A15
COLUMN SQL_TEXT FORMAT A90
EOF
```

---

# LAB 2 — Verifikasi Database

Login sebagai SYS:

```bash
sqlplus -L "sys/oracle@192.168.56.26:1521/PDB1 as sysdba"
```


Supaya output berikutnya rapi:

```sql
SET LINESIZE 200
SET PAGESIZE 100
SET LONG 5000
SET TRIMSPOOL ON
SET TAB OFF
```

---

## 2.1 Periksa database

Gunakan query berikut untuk memastikan nama database, mode open, role database, dan status multitenant sebelum lab dilanjutkan.

```sql
SELECT name,
       open_mode,
       database_role,
       cdb
FROM v$database;
```

---

## 2.2 Periksa instance

Periksa kesehatan instance untuk memastikan database berada pada kondisi `OPEN` dan siap digunakan.

```sql
SELECT instance_name,
       status,
       database_status
FROM v$instance;
```

---

## 2.3 Periksa container saat ini

Pastikan Anda mengetahui container aktif sebelum membuat object atau policy agar tidak bekerja pada container yang salah.

```sql
SHOW CON_NAME
```

---

## 2.4 Periksa PDB

Tampilkan daftar PDB dan pastikan `PDB1` tersedia serta berada dalam mode yang dapat digunakan untuk training.

```sql
SHOW PDBS
```

Ini penting karena semua schema training kita akan ditempatkan di:

```text
PDB1
```

bukan di `CDB$ROOT`.

---

# LAB 3 — Memahami Unified Auditing

Oracle AI Database 26ai pada VM ini memakai pure unified auditing. Kita tetap
memeriksa statusnya agar Anda memahami konteks environment sebelum lanjut.

Keluar SQL*Plus:

```sql
EXIT
```

---

## 3.1 Periksa mode auditing melalui database

Login kembali dan periksa mode yang dilaporkan database:

```bash
sqlplus  "sys/oracle@192.168.56.26:1521/PDB1 as sysdba"
```


```sql
SELECT parameter, value
FROM v$option
WHERE parameter='Unified Auditing';
```

`TRUE` berarti VM ini menjalankan pure unified auditing. Custom unified policy
dan event login, DML, serta DDL pada Handson 1 dibaca dari `UNIFIED_AUDIT_TRAIL`.
Tidak diperlukan relink binary atau restart database.

---

# LAB 4 — Mengenali Unified Audit Policies

Jalankan:

```sql
SET LINES 200
SET PAGES 100
COLUMN POLICY_NAME FORMAT A30
COLUMN ENABLED_OPTION FORMAT A18
COLUMN ENTITY_NAME FORMAT A20
SELECT policy_name,
       enabled_option,
       entity_name
FROM audit_unified_enabled_policies
ORDER BY policy_name;
```

Policy bawaan yang aktif dapat berbeda berdasarkan konfigurasi database.

---

# LAB 5 — Mengenali UNIFIED_AUDIT_TRAIL

Ini adalah view yang akan sangat sering kita gunakan selama training.

```sql
DESC unified_audit_trail
```

Perintah `DESC` akan menampilkan struktur `UNIFIED_AUDIT_TRAIL`. Saat menjalankannya, fokuskan perhatian pada kolom-kolom berikut karena kolom inilah yang paling sering dipakai saat investigasi:

- `AUDIT_TYPE`
- `SESSIONID`
- `OS_USERNAME`
- `USERHOST`
- `TERMINAL`
- `INSTANCE_ID`
- `DBID`
- `AUTHENTICATION_TYPE`
- `DBUSERNAME`
- `CLIENT_PROGRAM_NAME`
- `EVENT_TIMESTAMP`
- `ACTION_NAME`
- `RETURN_CODE`
- `OBJECT_SCHEMA`
- `OBJECT_NAME`
- `SQL_TEXT`
- `UNIFIED_AUDIT_POLICIES`

Untuk training ini, fokus kita adalah:

```text
EVENT_TIMESTAMP
DBUSERNAME
ACTION_NAME
OBJECT_SCHEMA
OBJECT_NAME
SQL_TEXT
RETURN_CODE
UNIFIED_AUDIT_POLICIES
```

---

# LAB 6 — Melihat Audit Trail yang Sudah Ada

Jalankan:

```sql
SET LINES 220
COLUMN EVENT_TIMESTAMP FORMAT A30
COLUMN DBUSERNAME FORMAT A20
COLUMN ACTION_NAME FORMAT A25
COLUMN OBJECT_SCHEMA FORMAT A20
COLUMN OBJECT_NAME FORMAT A25
SELECT event_timestamp,
       dbusername,
       action_name,
       object_schema,
       object_name,
       return_code
FROM unified_audit_trail
FETCH FIRST 20 ROWS ONLY;
```


Tujuan langkah ini adalah memastikan `UNIFIED_AUDIT_TRAIL` dapat dibaca. Isi audit trail setiap environment bisa berbeda; setelah ini kita akan menghasilkan audit record sendiri.

---

# LAB 7 — Membuat Schema Training

Sekarang kita buat environment yang konsisten untuk semua Anda.

Pindah ke PDB1:

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

Verifikasi:

```sql
SHOW CON_NAME
```

---

## 7.1 Bersihkan user lama jika ada

Block ini aman dicopy walaupun user belum ada:

```sql
BEGIN
   EXECUTE IMMEDIATE 'DROP USER audit_user CASCADE';
EXCEPTION
   WHEN OTHERS THEN
      IF SQLCODE != -1918 THEN
         RAISE;
      END IF;
END;
/
```

Lakukan juga untuk user investigator:

```sql
BEGIN
   EXECUTE IMMEDIATE 'DROP USER lab_auditor CASCADE';
EXCEPTION
   WHEN OTHERS THEN
      IF SQLCODE != -1918 THEN
         RAISE;
      END IF;
END;
/
```

---

# LAB 8 — Membuat AUDIT_USER

Buat `AUDIT_USER` sebagai user aplikasi yang akan menghasilkan aktivitas `SELECT`, DML, DDL, dan login untuk bahan audit.

```sql
CREATE USER audit_user
IDENTIFIED BY Welcome1
DEFAULT TABLESPACE users
TEMPORARY TABLESPACE temp
QUOTA UNLIMITED ON users;
```

Berikan privilege:

```sql
GRANT CREATE SESSION,
      CREATE TABLE,
      CREATE VIEW,
      CREATE PROCEDURE,
      CREATE SEQUENCE
TO audit_user;
```

---

# LAB 9 — Membuat LAB_AUDITOR

Nama `AUDIT_ADMIN` sudah dipakai role bawaan Oracle dan menghasilkan ORA-01920 jika dipakai sebagai nama user. Investigator lab menggunakan `LAB_AUDITOR`; role baca audit yang diberikan tetap `AUDIT_VIEWER`.

```sql
CREATE USER lab_auditor
IDENTIFIED BY Welcome1
DEFAULT TABLESPACE users
TEMPORARY TABLESPACE temp;
```

Berikan login:

```sql
GRANT CREATE SESSION TO lab_auditor;
```

Berikan role untuk membaca unified audit trail:

```sql
GRANT AUDIT_VIEWER TO lab_auditor;
```

Konsepnya sekarang:

```text
AUDIT_USER
    │
    │ melakukan aktivitas
    ▼
Oracle Database
    │
    ▼
Unified Audit Trail
    ▲
    │ membaca
    │
LAB_AUDITOR
```

Ini penting karena **pelaku aktivitas dan investigator sebaiknya kita pisahkan**.

---

# LAB 10 — Membuat Sample Application

Buka koneksi baru dari shell agar mudah:

```sql
EXIT
```

Kemudian:

```bash
sqlplus -L audit_user/Welcome1@192.168.56.26:1521/PDB1
```


Verifikasi:

```sql
SHOW USER
```

---

## 10.1 Membuat tabel CUSTOMER

Buat tabel `CUSTOMERS` sebagai object utama yang akan dipakai untuk menghasilkan dan menginvestigasi event audit.

```sql
CREATE TABLE customers (
    customer_id   NUMBER PRIMARY KEY,
    customer_name VARCHAR2(100),
    email         VARCHAR2(100),
    phone         VARCHAR2(30),
    credit_limit  NUMBER(12,2),
    status        VARCHAR2(20)
);
```

---

## 10.2 Insert sample data

Masukkan data awal agar operasi `SELECT`, `UPDATE`, dan `DELETE` pada langkah berikutnya mempunyai target yang konsisten.

```sql
INSERT INTO customers VALUES
(1,'Budi Santoso','budi@example.com','0811111111',10000000,'ACTIVE');
INSERT INTO customers VALUES
(2,'Siti Aminah','siti@example.com','0822222222',15000000,'ACTIVE');
INSERT INTO customers VALUES
(3,'Andi Wijaya','andi@example.com','0833333333',5000000,'INACTIVE');
INSERT INTO customers VALUES
(4,'Dewi Lestari','dewi@example.com','0844444444',20000000,'ACTIVE');
COMMIT;
```

Pastikan keempat baris sample berhasil dimasukkan dan transaksi sudah di-`COMMIT` sebelum melanjutkan ke langkah verifikasi.

Yang penting empat row berhasil masuk.

Verifikasi:

```sql
SELECT * FROM customers ORDER BY customer_id;
```

---

# LAB 11 — Baseline: Aktivitas Tanpa Custom Audit Policy

Jalankan:

```sql
SELECT customer_id,
       customer_name,
       credit_limit
FROM customers;
```

Kemudian:

```sql
UPDATE customers
SET credit_limit = 12000000
WHERE customer_id = 1;
COMMIT;
```

Kita sengaja melakukan aktivitas sebelum membuat policy sebagai pembanding.

---

# LAB 12 — Membuat Unified Audit Policy Pertama

Keluar:

```sql
EXIT
```

Login SYS langsung ke PDB1:

```bash
sqlplus -L sys/oracle@192.168.56.26:1521/PDB1 as sysdba
```


Verifikasi:

```sql
SHOW CON_NAME
```

---

## 12.1 Membuat policy

Definisikan unified audit policy untuk merekam operasi DML pada `AUDIT_USER.CUSTOMERS`. Pada tahap ini policy baru dibuat, belum diaktifkan.

```sql
CREATE AUDIT POLICY customer_access_policy
ACTIONS
    SELECT ON audit_user.customers,
    INSERT ON audit_user.customers,
    UPDATE ON audit_user.customers,
    DELETE ON audit_user.customers;
```

Perhatikan:

```text
CREATE AUDIT POLICY
```

baru **mendefinisikan policy**.

Belum berarti policy tersebut aktif.

---

# LAB 13 — Melihat Definisi Policy

Gunakan data dictionary untuk memeriksa action dan object yang tercakup dalam policy yang baru dibuat.

```sql
SET LINES 200
COLUMN POLICY_NAME FORMAT A30
COLUMN AUDIT_OPTION FORMAT A20
COLUMN OBJECT_SCHEMA FORMAT A20
COLUMN OBJECT_NAME FORMAT A20
SELECT policy_name,
       audit_option,
       object_schema,
       object_name
FROM audit_unified_policies
WHERE policy_name='CUSTOMER_ACCESS_POLICY'
ORDER BY audit_option;
```

---

# LAB 14 — Memeriksa Apakah Policy Sudah Enabled

Periksa status aktivasi policy secara terpisah dari definisinya. Policy yang sudah dibuat belum tentu aktif.

```sql
SELECT policy_name,
       enabled_option,
       entity_name
FROM audit_unified_enabled_policies
WHERE policy_name='CUSTOMER_ACCESS_POLICY';
```

Ini menunjukkan:

```text
Policy exists
      ≠
Policy enabled
```

---

# LAB 15 — Enable Audit Policy

Aktifkan:

```sql
AUDIT POLICY customer_access_policy;
```

Verifikasi:

```sql
SELECT policy_name,
       enabled_option,
       entity_name
FROM audit_unified_enabled_policies
WHERE policy_name='CUSTOMER_ACCESS_POLICY';
```

---

# LAB 16 — Generate SELECT Audit

Keluar:

```sql
EXIT
```

Login:

```bash
sqlplus -L audit_user/Welcome1@192.168.56.26:1521/PDB1
```


Jalankan:

```sql
SELECT customer_id,
       customer_name,
       credit_limit
FROM customers
WHERE customer_id=1;
```

---

# LAB 17 — Generate INSERT Audit

Tambahkan satu record baru untuk menghasilkan event `INSERT` setelah policy aktif.

```sql
INSERT INTO customers
VALUES
(5,'Rina Putri','rina@example.com','0855555555',8000000,'ACTIVE');
COMMIT;
```

---

# LAB 18 — Generate UPDATE Audit

Ubah salah satu data customer untuk menghasilkan event `UPDATE` yang dapat ditelusuri di audit trail.

```sql
UPDATE customers
SET credit_limit=25000000
WHERE customer_id=2;
COMMIT;
```

---

# LAB 19 — Generate DELETE Audit

Hapus satu record sample untuk menghasilkan event `DELETE` dan kemudian lakukan `COMMIT`.

```sql
DELETE FROM customers
WHERE customer_id=3;
COMMIT;
```

Sekarang kita sudah menghasilkan:

```text
SELECT
INSERT
UPDATE
DELETE
```

---

# LAB 20 — Investigasi Audit Trail

Keluar:

```sql
EXIT
```

Login sebagai investigator:

```bash
sqlplus -L lab_auditor/Welcome1@192.168.56.26:1521/PDB1
```


Atur output:

```sql
SET LINES 250
SET PAGES 100
COLUMN EVENT_TIMESTAMP FORMAT A32
COLUMN DBUSERNAME FORMAT A15
COLUMN ACTION_NAME FORMAT A15
COLUMN OBJECT_SCHEMA FORMAT A15
COLUMN OBJECT_NAME FORMAT A15
COLUMN UNIFIED_AUDIT_POLICIES FORMAT A30
```

Jalankan:

```sql
SELECT event_timestamp,
       dbusername,
       action_name,
       object_schema,
       object_name,
       return_code,
       unified_audit_policies
FROM unified_audit_trail
WHERE dbusername='AUDIT_USER'
AND object_name='CUSTOMERS'
ORDER BY event_timestamp;
```


**Ini salah satu query terpenting Handson 1.**

Kita sekarang mempunyai bukti:

```text
AUDIT_USER
   │
   ├── SELECT
   ├── INSERT
   ├── UPDATE
   └── DELETE
           │
           ▼
CUSTOMER_ACCESS_POLICY
           │
           ▼
UNIFIED_AUDIT_TRAIL
```

---

# LAB 21 — Melihat SQL yang Dilakukan User

Query berikut menampilkan `SQL_TEXT` agar investigator dapat melihat statement yang menghasilkan audit event, bukan hanya nama action-nya.

```sql
SET LONG 2000
SET LINES 250
COLUMN ACTION_NAME FORMAT A12
COLUMN SQL_TEXT FORMAT A100
SELECT event_timestamp,
       action_name,
       sql_text
FROM unified_audit_trail
WHERE dbusername='AUDIT_USER'
AND object_name='CUSTOMERS'
AND unified_audit_policies LIKE '%CUSTOMER_ACCESS_POLICY%'
ORDER BY event_timestamp;
```


Sekarang investigator tidak hanya mengetahui:

> user melakukan UPDATE

tetapi juga dapat melihat SQL yang berkaitan dengan audit event tersebut.

---

# LAB 22 — Memahami RETURN_CODE

Salah satu kolom penting:

```text
RETURN_CODE
```

Secara praktis:

```text
0       → operation berhasil
nonzero → Oracle error
```

Contoh:

```sql
SELECT action_name,
       return_code,
       COUNT(*) total
FROM unified_audit_trail
WHERE dbusername='AUDIT_USER'
GROUP BY action_name, return_code
ORDER BY action_name;
```

Gunakan hasil aktual query ini untuk melihat kombinasi `ACTION_NAME` dan `RETURN_CODE` yang sudah terjadi pada sesi lab.

---

# LAB 23 — Audit CREATE TABLE dan DROP TABLE

Sekarang kita audit aktivitas DDL.

Keluar:

```sql
EXIT
```

Login SYS:

```bash
sqlplus -L sys/oracle@192.168.56.26:1521/PDB1 as sysdba
```


Buat policy:

```sql
CREATE AUDIT POLICY audit_user_ddl_policy
ACTIONS CREATE TABLE, DROP TABLE;
```

Kita tidak ingin mengaudit seluruh user.

Aktifkan hanya untuk `AUDIT_USER`:

```sql
AUDIT POLICY audit_user_ddl_policy BY audit_user;
```

---

# LAB 24 — Memahami BY USER

Periksa:

```sql
COLUMN POLICY_NAME FORMAT A30
COLUMN ENABLED_OPTION FORMAT A20
COLUMN ENTITY_NAME FORMAT A20
SELECT policy_name,
       enabled_option,
       entity_name
FROM audit_unified_enabled_policies
WHERE policy_name='AUDIT_USER_DDL_POLICY';
```

Bandingkan dengan policy pertama:

```sql
SELECT policy_name,
       enabled_option,
       entity_name
FROM audit_unified_enabled_policies
WHERE policy_name IN
(
 'CUSTOMER_ACCESS_POLICY',
 'AUDIT_USER_DDL_POLICY'
)
ORDER BY policy_name;
```

---

# LAB 25 — Generate DDL Activity

Keluar:

```sql
EXIT
```

Login:

```bash
sqlplus -L audit_user/Welcome1@192.168.56.26:1521/PDB1
```


Buat tabel:

```sql
CREATE TABLE secret_notes (
    note_id NUMBER,
    note_text VARCHAR2(200)
);
```

Insert:

```sql
INSERT INTO secret_notes
VALUES (1,'Confidential training data');
COMMIT;
```

Drop:

```sql
DROP TABLE secret_notes PURGE;
```

---

# LAB 26 — Investigasi DDL

Login kembali sebagai investigator:

```sql
EXIT
```

```bash
sqlplus -L lab_auditor/Welcome1@192.168.56.26:1521/PDB1
```


Jalankan:

```sql
SET LINES 220
COLUMN EVENT_TIMESTAMP FORMAT A32
COLUMN ACTION_NAME FORMAT A20
COLUMN OBJECT_NAME FORMAT A25
COLUMN UNIFIED_AUDIT_POLICIES FORMAT A30
SELECT event_timestamp,
       dbusername,
       action_name,
       object_name,
       return_code,
       unified_audit_policies
FROM unified_audit_trail
WHERE dbusername='AUDIT_USER'
AND unified_audit_policies LIKE '%AUDIT_USER_DDL_POLICY%'
ORDER BY event_timestamp;
```

Perhatikan bahwa:

```text
INSERT INTO SECRET_NOTES
```

tidak muncul karena policy kita hanya:

```text
CREATE TABLE
DROP TABLE
```

Ini mendemonstrasikan bahwa audit policy bisa dibuat spesifik.

---

# LAB 27 — Failed Login Auditing

Siapkan policy login yang eksplisit agar keberhasilan dan kegagalan login sama-sama dapat dibuktikan.

```sql
EXIT
```

```bash
sqlplus -L sys/oracle@192.168.56.26:1521/PDB1 as sysdba
```


```sql
CREATE AUDIT POLICY audit_user_logon_pol ACTIONS LOGON;
AUDIT POLICY audit_user_logon_pol BY audit_user;
EXIT
```

Uji login berhasil:

```bash
sqlplus -L audit_user/Welcome1@192.168.56.26:1521/PDB1
```


```sql
SHOW USER
EXIT
```

Pastikan sesi yang aktif adalah `AUDIT_USER`, lalu keluar dari SQL*Plus dan lanjutkan dengan uji password salah dari shell:

```bash
sqlplus -L audit_user/SalahPassword@192.168.56.26:1521/PDB1
```

Perintah sebelumnya sengaja menggunakan password yang salah untuk menghasilkan event login gagal. Opsi `-L` membuat SQL*Plus berhenti setelah percobaan gagal,
sehingga command shell berikutnya tidak masuk ke prompt username.
Lab 28 digunakan untuk membandingkan event login berhasil dan gagal melalui nilai `RETURN_CODE` pada audit trail.

---

# LAB 28 — Investigasi Failed Login

Login SYS:

```bash
sqlplus -L sys/oracle@192.168.56.26:1521/PDB1 as sysdba
```


Query:

```sql
SET LINES 220
COLUMN EVENT_TIMESTAMP FORMAT A32
COLUMN DBUSERNAME FORMAT A20
COLUMN USERHOST FORMAT A25
COLUMN ACTION_NAME FORMAT A15
SELECT event_timestamp,
       dbusername,
       userhost,
       action_name,
       return_code
FROM unified_audit_trail
WHERE dbusername='AUDIT_USER'
AND action_name='LOGON'
ORDER BY event_timestamp DESC
FETCH FIRST 10 ROWS ONLY;
```

Dalam investigasi, `RETURN_CODE = 1017` menunjukkan kegagalan login karena kredensial tidak valid.

Ini contoh detective control yang sangat nyata:

```text
Attacker/User
     │
     │ wrong password
     ▼
Oracle
     │
     ├── DENY
     │
     └── AUDIT
           │
           ▼
   UNIFIED_AUDIT_TRAIL

   RETURN_CODE = 1017
```

---

# LAB 29 — Mencari Semua Failed Login

Sekarang jangan batasi ke `AUDIT_USER`.

```sql
SELECT event_timestamp,
       dbusername,
       userhost,
       return_code
FROM unified_audit_trail
WHERE action_name='LOGON'
AND return_code <> 0
ORDER BY event_timestamp DESC;
```

Jumlah dan urutan record akan mengikuti riwayat aktivitas pada environment masing-masing.

Ini adalah contoh query sederhana untuk mendeteksi percobaan login gagal.

---

# LAB 30 — Failed Login Summary

Kita bisa membuat report:

```sql
COLUMN DBUSERNAME FORMAT A20
SELECT dbusername,
       return_code,
       COUNT(*) AS failed_attempts
FROM unified_audit_trail
WHERE action_name='LOGON'
AND return_code <> 0
GROUP BY dbusername, return_code
ORDER BY failed_attempts DESC;
```

---

# LAB 31 — Disable Audit Policy

Sekarang kita belajar lifecycle policy:

```text
CREATE
  ↓
ENABLE
  ↓
AUDIT
  ↓
DISABLE
  ↓
DROP
```

Disable policy:

```sql
NOAUDIT POLICY customer_access_policy;
```

Periksa:

```sql
SELECT policy_name,
       enabled_option,
       entity_name
FROM audit_unified_enabled_policies
WHERE policy_name='CUSTOMER_ACCESS_POLICY';
```

Tetapi definisi policy masih ada:

```sql
SELECT DISTINCT policy_name
FROM audit_unified_policies
WHERE policy_name='CUSTOMER_ACCESS_POLICY';
```

Jadi:

```text
NOAUDIT
   │
   └── disable policy

DROP AUDIT POLICY
   │
   └── delete policy
```

---

# LAB 32 — Membuktikan NOAUDIT

Login:

```sql
EXIT
```

```bash
sqlplus -L audit_user/Welcome1@192.168.56.26:1521/PDB1
```


Jalankan:

```sql
SELECT *
FROM customers
WHERE customer_id=4;
```

Karena policy sudah disabled, query ini **tidak seharusnya menghasilkan event dari `CUSTOMER_ACCESS_POLICY`**.

---

# LAB 33 — Re-enable Policy

Login SYS:

```sql
EXIT
```

```bash
sqlplus -L sys/oracle@192.168.56.26:1521/PDB1 as sysdba
```


Aktifkan kembali:

```sql
AUDIT POLICY customer_access_policy BY audit_user;
```

Periksa:

```sql
SELECT policy_name,
       enabled_option,
       entity_name
FROM audit_unified_enabled_policies
WHERE policy_name='CUSTOMER_ACCESS_POLICY';
```

Sekarang policy jauh lebih baik daripada sebelumnya karena hanya mengaudit:

```text
AUDIT_USER
```

bukan:

```text
ALL USERS
```

---

# LAB 34 — Security Investigation Challenge

Sekarang anggap Anda seorang security analyst.

Ada laporan:

> Seseorang telah mengubah `CREDIT_LIMIT` customer.

Cari siapa pelakunya.

Login:

Kembali ke shell terlebih dahulu:

```sql
EXIT
```

```bash
sqlplus -L lab_auditor/Welcome1@192.168.56.26:1521/PDB1
```


Jalankan:

```sql
SET LONG 2000
SET LINES 250
COLUMN EVENT_TIMESTAMP FORMAT A32
COLUMN DBUSERNAME FORMAT A15
COLUMN USERHOST FORMAT A20
COLUMN SQL_TEXT FORMAT A100
SELECT event_timestamp,
       dbusername,
       userhost,
       action_name,
       sql_text
FROM unified_audit_trail
WHERE object_schema='AUDIT_USER'
AND object_name='CUSTOMERS'
AND action_name='UPDATE'
ORDER BY event_timestamp DESC;
```


Query investigasi di atas membantu menjawab pertanyaan forensik utama:

- **WHO?** → lihat `DBUSERNAME`
- **WHAT?** → lihat `ACTION_NAME`
- **WHERE?** → lihat `OBJECT_SCHEMA` dan `OBJECT_NAME`
- **WHEN?** → lihat `EVENT_TIMESTAMP`
- **FROM WHERE?** → lihat `USERHOST`
- **HOW?** → lihat `SQL_TEXT`

Inilah esensi **detective control**.

---

# LAB 35 — Membuat Mini Audit Dashboard via SQL

Gunakan:

```sql
SELECT action_name,
       COUNT(*) total_events
FROM unified_audit_trail
WHERE dbusername='AUDIT_USER'
GROUP BY action_name
ORDER BY total_events DESC;
```


---

# LAB 36 — Successful vs Failed Activities

Kelompokkan aktivitas berdasarkan `RETURN_CODE` untuk membedakan operasi yang berhasil dan gagal.

```sql
SELECT
    CASE
       WHEN return_code=0 THEN 'SUCCESS'
       ELSE 'FAILED'
    END AS status,
    COUNT(*) AS total
FROM unified_audit_trail
WHERE dbusername='AUDIT_USER'
GROUP BY
    CASE
       WHEN return_code=0 THEN 'SUCCESS'
       ELSE 'FAILED'
    END;
```

---

# LAB 37 — Top Objects Accessed

Gunakan agregasi berikut untuk mengetahui object database yang paling sering muncul pada aktivitas `AUDIT_USER`.

```sql
SELECT object_schema,
       object_name,
       COUNT(*) total_access
FROM unified_audit_trail
WHERE dbusername='AUDIT_USER'
AND object_name IS NOT NULL
GROUP BY object_schema, object_name
ORDER BY total_access DESC;
```

---

# LAB 38 — Investigasi Berdasarkan Waktu

Aktivitas 30 menit terakhir:

```sql
SELECT event_timestamp,
       dbusername,
       action_name,
       object_schema,
       object_name,
       return_code
FROM unified_audit_trail
WHERE event_timestamp >= SYSTIMESTAMP - INTERVAL '30' MINUTE
ORDER BY event_timestamp DESC;
```

Ini sangat berguna ketika kasusnya:

> "Ada insiden sekitar 20 menit lalu."

---

# LAB 39 — Melihat Client Program

Tambahkan `CLIENT_PROGRAM_NAME` untuk mengetahui program client yang digunakan ketika aktivitas audit terjadi.

```sql
COLUMN CLIENT_PROGRAM_NAME FORMAT A40
SELECT event_timestamp,
       dbusername,
       userhost,
       client_program_name,
       action_name
FROM unified_audit_trail
WHERE dbusername='AUDIT_USER'
ORDER BY event_timestamp DESC
FETCH FIRST 20 ROWS ONLY;
```

Sekarang investigator bisa mengetahui bukan hanya **siapa**, tetapi juga client program yang digunakan.

---

# LAB 40 — Melihat Authentication Information

Periksa informasi autentikasi pada event `LOGON` untuk menambah konteks pada investigasi sesi user.

```sql
COLUMN AUTHENTICATION_TYPE FORMAT A60
SELECT event_timestamp,
       dbusername,
       authentication_type
FROM unified_audit_trail
WHERE dbusername='AUDIT_USER'
AND action_name='LOGON'
ORDER BY event_timestamp DESC;
```


---

# LAB 41 — Audit Policy Inventory

Sebagai DBA, Anda perlu mengetahui policy apa saja yang didefinisikan:

```sql
SELECT DISTINCT policy_name
FROM audit_unified_policies
ORDER BY policy_name;
```

Gunakan hasil query ini untuk membedakan policy bawaan Oracle dengan policy training yang dibuat selama lab.

Daftar persis policy bawaan dapat berbeda.

---

# LAB 42 — Enabled Policy Inventory

Policy yang **ada** belum tentu **enabled**.

Gunakan:

```sql
SET LINES 200
COLUMN POLICY_NAME FORMAT A30
COLUMN ENABLED_OPTION FORMAT A20
COLUMN ENTITY_NAME FORMAT A25
SELECT policy_name,
       enabled_option,
       entity_name
FROM audit_unified_enabled_policies
ORDER BY policy_name, entity_name;
```

Ini adalah query penting untuk assessment:

```text
Apa yang sebenarnya sedang diaudit database ini?
```

---

# LAB 43 — Membandingkan Policy Definition vs Policy State

Definisi:

```sql
SELECT DISTINCT policy_name
FROM audit_unified_policies
WHERE policy_name LIKE '%AUDIT%'
OR policy_name LIKE '%CUSTOMER%'
ORDER BY policy_name;
```

State:

```sql
SELECT policy_name,
       enabled_option,
       entity_name
FROM audit_unified_enabled_policies
WHERE policy_name LIKE '%AUDIT%'
OR policy_name LIKE '%CUSTOMER%'
ORDER BY policy_name;
```

Konsep:

```text
AUDIT_UNIFIED_POLICIES
         │
         └── WHAT IS DEFINED?


AUDIT_UNIFIED_ENABLED_POLICIES
         │
         └── WHAT IS ACTIVE?


UNIFIED_AUDIT_TRAIL
         │
         └── WHAT HAPPENED?
```

Ini tiga view yang wajib diingat.

---

# LAB 44 — Final Investigation Exercise

Sekarang buat beberapa aktivitas "mencurigakan".

Login:

Kembali ke shell terlebih dahulu:

```sql
EXIT
```

```bash
sqlplus -L audit_user/Welcome1@192.168.56.26:1521/PDB1
```


Jalankan:

```sql
SELECT *
FROM customers;
UPDATE customers
SET credit_limit=99999999
WHERE customer_id=4;
DELETE FROM customers
WHERE customer_id=5;
COMMIT;
```

Keluar:

```sql
EXIT
```

Lakukan dua login gagal:

```bash
sqlplus -L audit_user/wrongpassword@192.168.56.26:1521/PDB1
```

Dengan `-L`, SQL*Plus langsung kembali ke shell setelah login gagal. Lanjutkan ke langkah berikutnya.

---

# LAB 45 — Buat Incident Report

Login investigator:

```bash
sqlplus -L lab_auditor/Welcome1@192.168.56.26:1521/PDB1
```


Cari seluruh aktivitas mencurigakan:

```sql
SET LINES 250
SET LONG 2000
COLUMN EVENT_TIMESTAMP FORMAT A32
COLUMN DBUSERNAME FORMAT A15
COLUMN ACTION_NAME FORMAT A15
COLUMN OBJECT_NAME FORMAT A20
COLUMN SQL_TEXT FORMAT A90
SELECT event_timestamp,
       dbusername,
       action_name,
       object_name,
       return_code,
       sql_text
FROM unified_audit_trail
WHERE dbusername='AUDIT_USER'
AND
(
      return_code <> 0
   OR action_name IN ('UPDATE','DELETE')
)
ORDER BY event_timestamp DESC;
```

Gunakan hasil query untuk mengidentifikasi login gagal serta aktivitas `UPDATE`/`DELETE` yang relevan, lengkap dengan timestamp dan SQL yang tercatat.

beserta timestamp dan SQL yang relevan.

---

# LAB 46 — Optional Cleanup

**Jangan jalankan bagian ini kalau Anda ingin melanjutkan ke Handson 2**, karena schema ini akan kita gunakan kembali.

Jika benar-benar ingin reset:

Kembali ke shell terlebih dahulu:

```sql
EXIT
```

```bash
sqlplus -L sys/oracle@192.168.56.26:1521/PDB1 as sysdba
```


Disable:

```sql
NOAUDIT POLICY customer_access_policy BY audit_user;
NOAUDIT POLICY audit_user_ddl_policy BY audit_user;
NOAUDIT POLICY audit_user_logon_pol BY audit_user;
```

Drop policy:

```sql
DROP AUDIT POLICY customer_access_policy;
DROP AUDIT POLICY audit_user_ddl_policy;
DROP AUDIT POLICY audit_user_logon_pol;
```

Drop users:

```sql
DROP USER audit_user CASCADE;
DROP USER lab_auditor CASCADE;
```

---

# Cheat Sheet Handson 1

Bagian ini referensi sintaks; ganti placeholder schema, tabel, policy, dan user sebelum memakai contoh. Bukan langkah lanjutan yang dijalankan berurutan.

### Melihat audit events

```sql
SELECT event_timestamp,
       dbusername,
       action_name,
       object_schema,
       object_name,
       return_code
FROM unified_audit_trail
ORDER BY event_timestamp DESC;
```

### Membuat policy

```sql
CREATE AUDIT POLICY policy_name
ACTIONS SELECT ON schema.table;
```

### Enable untuk semua user

```sql
AUDIT POLICY policy_name;
```

### Enable untuk user tertentu

```sql
AUDIT POLICY policy_name BY username;
```

### Disable

```sql
NOAUDIT POLICY policy_name;
```

### Drop

```sql
DROP AUDIT POLICY policy_name;
```

### Policy definitions

```sql
SELECT *
FROM audit_unified_policies;
```

### Policy yang aktif

```sql
SELECT *
FROM audit_unified_enabled_policies;
```

### Failed login

```sql
SELECT event_timestamp,
       dbusername,
       userhost,
       return_code
FROM unified_audit_trail
WHERE action_name='LOGON'
AND return_code <> 0
ORDER BY event_timestamp DESC;
```

---

# Kesimpulan Handson 1

Setelah Handson 1, Anda seharusnya sudah memahami hubungan berikut:

```text
              ORACLE AI DATABASE 26ai
                           │
          ┌────────────────┴────────────────┐
          │                                 │
   AUDIT POLICY                       USER ACTIVITY
          │                                 │
          └────────────────┬────────────────┘
                           ▼
                    UNIFIED AUDITING
                           │
                           ▼
                 UNIFIED_AUDIT_TRAIL
                           │
          ┌────────────────┼─────────────────┐
          │                │                 │
          ▼                ▼                 ▼
        WHO?             WHAT?             WHEN?
     DBUSERNAME       ACTION_NAME      EVENT_TIMESTAMP
          │                │
          ▼                ▼
        WHERE?            HOW?
       USERHOST         SQL_TEXT
                           │
                           ▼
                     SUCCESS/FAILED
                      RETURN_CODE
```