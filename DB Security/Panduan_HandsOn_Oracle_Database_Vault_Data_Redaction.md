# Panduan Ringkas dan Hands-On Oracle Database Vault 19c

> Ringkasan terstruktur dari **Oracle Database Vault Administrator's Guide 19c, E96302-23, June 2024**, dilengkapi praktik laboratorium dan catatan operasional.  
> Tujuan dokumen ini adalah membuat panduan Oracle yang sangat panjang menjadi lebih mudah dipahami, namun tetap mempertahankan terminologi dan model keamanan Oracle Database Vault.

---

# Cara Menggunakan Panduan Ini

Dokumen ini dibagi menjadi lima bagian:

1. **Bagian I — Memahami Database Vault**  
   Ringkasan konsep Oracle Database Vault dan seluruh kelompok materi dalam Oracle Administrator's Guide.

2. **Bagian II — Komponen Inti Database Vault**  
   Penjelasan lebih dalam mengenai Realm, Rule, Rule Set, Command Rule, Factor, Secure Application Role, Policy, Simulation Mode, dan Operations Control.

3. **Bagian III — Role dan Separation of Duties**  
   Menjelaskan siapa melakukan apa: `DV_OWNER`, `DV_ADMIN`, `DV_ACCTMGR`, monitoring, developer aplikasi, dan role khusus.

4. **Bagian IV — Hands-On Lab**  
   Praktik terurut dari pengecekan Database Vault sampai pembuatan Realm dan pengujian akses.

5. **Bagian V — Operasional, Troubleshooting, dan Data Redaction**  
   Runbook ketika aplikasi/DBA mengalami kendala, monitoring, error umum, dan integrasi praktik Data Redaction.

Jika peserta baru mengenal Database Vault, **jangan langsung menjalankan script**. Baca Bagian I–III terlebih dahulu.

---

# BAGIAN I — MEMAHAMI ORACLE DATABASE VAULT

# 1. Database Vault dalam Satu Kalimat

Oracle Database Vault adalah lapisan kontrol keamanan di atas privilege Oracle Database yang bertujuan untuk:

> **mencegah privileged account menggunakan kewenangannya untuk mengakses data atau mengubah konfigurasi yang tidak menjadi tanggung jawabnya.**

Contoh sederhana:

```text
Sebelum Database Vault

DBA
 |
 +-- SELECT ANY TABLE
 |
 +-- bisa membaca hampir seluruh tabel


Setelah Database Vault

DBA
 |
 +-- SELECT ANY TABLE
 |
 +-- Realm
       |
       +-- HR.EMPLOYEES
       +-- FINANCE.TRANSACTION
       |
       +-- DBA tidak authorized
           -> akses diblok
```

Database Vault **tidak menggantikan** privilege model Oracle.

Database Vault bekerja sebagai **lapisan tambahan** di atas:

- system privilege;
- object privilege;
- role;
- ownership schema.

---

# 2. Masalah yang Diselesaikan Database Vault

Oracle Database Vault terutama menjawab tiga masalah.

## 2.1 Privileged account terlalu kuat

Akun seperti DBA bisa memiliki:

```text
SELECT ANY TABLE
DROP ANY TABLE
ALTER ANY TABLE
EXECUTE ANY PROCEDURE
```

Tanpa kontrol tambahan, privilege ini dapat digunakan pada data aplikasi yang sebenarnya tidak perlu dilihat oleh DBA.

Database Vault dapat membatasi penggunaan privilege tersebut terhadap object yang dilindungi.

---

## 2.2 Separation of Duties

Tanpa Database Vault, satu DBA sering mengerjakan semuanya:

```text
buat user
reset password
ubah schema
akses data
buat security policy
patch database
audit
```

Database Vault memisahkan tanggung jawab.

Contoh:

```text
Security Administrator    -> DV_OWNER / DV_ADMIN
Account Administrator     -> DV_ACCTMGR
Monitoring                -> DV_MONITOR
Security Analyst          -> DV_SECANALYST
Patching                  -> DV_PATCH_ADMIN
Application Developer     -> application role
```

---

## 2.3 Database consolidation dan Multitenant

Dalam arsitektur CDB/PDB:

```text
CDB$ROOT
 |
 +-- PDB A
 +-- PDB B
 +-- PDB C
```

Infrastructure DBA dapat menjadi **common user**.

Oracle Database Vault 19c menyediakan **Operations Control** untuk mencegah common user di root membaca data lokal di PDB.

---

# 3. Peta Seluruh Oracle Database Vault Administrator's Guide

Oracle Database Vault Administrator's Guide 19c terdiri dari materi konsep, konfigurasi, operasi, API, view, monitoring, dan reporting.

Berikut resume seluruh struktur panduan.

| Bab Oracle | Fokus | Yang Harus Dipahami Peserta |
|---|---|---|
| 1 | Introduction | tujuan DV, komponen, privileged accounts, multitenant |
| 2 | What to Expect After Enable | perubahan privilege dan authorization setelah DV aktif |
| 3 | Getting Started | konfigurasi, enable, verifikasi, quick-start Realm |
| 4 | Configuring Realms | perlindungan schema/object/role |
| 5 | Configuring Rule Sets | kondisi keamanan dan evaluasi rule |
| 6 | Configuring Command Rules | pembatasan SQL statement |
| 7 | Configuring Factors | konteks session seperti IP, host, user, module |
| 8 | Secure Application Roles | role yang aktif hanya jika rule set lolos |
| 9 | Database Vault Policies | pengelompokan Realm + Command Rule |
| 10 | Simulation Mode | uji policy tanpa langsung memblok aktivitas |
| 11 | Integration | integrasi dengan Oracle products |
| 12 | DBA Operations | Data Pump, Scheduler, RMAN, Operations Control, maintenance |
| 13 | Schemas, Roles, Accounts | separation of duties dan default DV roles |
| 14 | Realm APIs | API `DBMS_MACADM` untuk Realm |
| 15 | Rule Set APIs | API Rule dan Rule Set |
| 16 | Command Rule APIs | API Command Rule |
| 17 | Factor APIs | API Factor |
| 18 | Secure Application Role APIs | `DBMS_MACSEC_ROLES` |
| 19 | Oracle Label Security APIs | integrasi DV dengan OLS |
| 20 | Utility APIs | `DBMS_MACUTL` |
| 21 | General Administrative APIs | authorization maintenance, Data Pump, Scheduler, DDL, Operations Control |
| 22 | Policy APIs | create/update policy dan anggota policy |
| 23 | API Reference | indeks package DV |
| 24 | Data Dictionary Views | `DBA_DV_*`, `CDB_DV_*`, audit views |
| 25 | Monitoring | violation dan perubahan konfigurasi |
| 26 | Reports | report konfigurasi, audit, privilege, powerful accounts |

Bab 14–23 sebagian besar merupakan **referensi API**. Untuk peserta operasional, yang paling penting adalah memahami Bab 1–13, kemudian menggunakan Bab 14–24 sebagai referensi command.

---

# 4. Apa yang Berubah Setelah Database Vault Aktif?

Setelah Database Vault dikonfigurasi dan di-enable:

- beberapa privilege administratif dipisahkan ke DV roles;
- beberapa privilege yang sebelumnya dimiliki role DBA dapat dicabut atau dibatasi;
- account management dipisahkan dari security administration;
- `SYS`/`SYSTEM` tidak lagi menjadi jawaban otomatis untuk setiap pekerjaan;
- Realm dan Command Rule dapat memblok operasi walaupun user mempunyai system privilege.

Mental model:

```text
Privilege Oracle
      +
Database Vault Authorization
      +
Command Rule / Rule Set
      =
Apakah operasi akhirnya diizinkan?
```

Karena itu:

```text
"Punya privilege"
```

tidak selalu sama dengan:

```text
"Boleh menjalankan operasi"
```

---

# 5. Arsitektur Komponen Database Vault

Gunakan diagram ini sebagai peta mental utama.

```text
                        ORACLE DATABASE VAULT
                               |
        +----------------------+----------------------+
        |                      |                      |
      Realm                 Command Rule            Factor
        |                      |                      |
  Lindungi object         Batasi SQL             Context session
        |                      |                      |
        +------------+---------+----------------------+
                     |
                  Rule Set
                     |
                  Rule(s)
                     |
        kondisi TRUE / FALSE saat runtime
                     |
              +------+------+
              |             |
            Allow          Deny
```

Komponen lain:

```text
Secure Application Role
        |
        +-- Rule Set menentukan apakah role boleh aktif

Policy
        |
        +-- mengelompokkan Realm dan Command Rule

Simulation Mode
        |
        +-- mencatat violation tanpa memblok operasi
```

---

# BAGIAN II — KOMPONEN INTI DATABASE VAULT

# 6. Realm — Komponen Paling Penting

## 6.1 Apa itu Realm?

Realm adalah batas keamanan yang melindungi:

- seluruh schema;
- table;
- view;
- procedure;
- package;
- sequence;
- role;
- dan object Oracle lain yang didukung.

Analogi:

```text
Privilege = kunci gedung

Realm = pintu ruangan khusus

Walaupun DBA punya kunci gedung,
dia tetap tidak bisa masuk ruangan
kalau tidak authorized ke Realm.
```

---

# 7. Regular Realm vs Mandatory Realm

Oracle menyediakan dua jenis Realm.

## 7.1 Regular Realm

Regular Realm terutama mencegah penggunaan **system privilege** terhadap Realm-secured object.

User yang memang:

- memiliki object; atau
- mendapat direct object privilege,

masih dapat melakukan beberapa akses seperti query/DML sesuai privilege yang dimiliki.

Namun untuk operasi yang menggunakan system privilege terhadap protected objects, Realm authorization diperlukan.

---

## 7.2 Mandatory Realm

Mandatory Realm lebih ketat.

Mandatory Realm memblok:

- system privilege access;
- object privilege access;
- bahkan object owner,

jika user belum authorized ke Realm.

Contoh:

```text
LATIHAN adalah owner TIM_PJKI
            |
            +-- TIM_PJKI masuk Mandatory Realm
            |
            +-- LATIHAN tidak authorized
                    |
                    +-- LATIHAN dapat ikut terblok
```

Karena itu Mandatory Realm harus dirancang dengan sangat hati-hati.

---

# 8. Default Realm Oracle

Oracle Database Vault menyediakan beberapa Realm bawaan.

Yang penting diketahui:

| Realm | Fungsi |
|---|---|
| Oracle Database Vault Realm | melindungi konfigurasi DVSYS, DVF, LBACSYS |
| Database Vault Account Management Realm | melindungi account/profile management |
| Oracle Enterprise Manager Realm | kebutuhan monitoring Enterprise Manager |
| Oracle Default Schema Protection Realm | perlindungan schema/role komponen Oracle |
| Oracle System Privilege and Role Management Realm | melindungi Oracle-supplied roles |
| Oracle Default Component Protection Realm | melindungi SYSTEM dan OUTLN |

Jangan mengubah default Realm tanpa memahami dampaknya.

---

# 9. Realm Object

Realm tidak melindungi apa pun sampai object dimasukkan ke dalam Realm.

Contoh:

```text
Realm             : LATIHAN Data Realm
Protected object  : LATIHAN.TIM_PJKI
```

Verifikasi:

```sql
SELECT realm_name,
       owner,
       object_name,
       object_type
FROM DVSYS.DBA_DV_REALM_OBJECT
ORDER BY realm_name, owner, object_name;
```

---

# 10. Realm Authorization

Realm authorization menentukan user/role yang boleh menggunakan privilege-nya terhadap Realm-secured object.

Ada dua tingkat utama.

## Participant

Participant:

- boleh menggunakan system/direct privilege yang memang sudah diberikan;
- tidak otomatis mendapatkan privilege baru.

Realm tidak menggantikan GRANT biasa.

Jadi:

```text
Realm Participant
       +
SELECT privilege
       =
bisa SELECT
```

Participant tanpa privilege SELECT tetap tidak otomatis dapat SELECT.

---

## Owner

Realm Owner mempunyai authorization seperti Participant ditambah kewenangan untuk:

- grant/revoke Realm-secured roles;
- grant/revoke privilege pada Realm-protected object.

Catatan penting:

> Menjadi Realm Owner tidak sama dengan `DV_OWNER`.

`DV_OWNER` adalah role administrasi Database Vault.

Realm Owner adalah **authorization terhadap Realm tertentu**.

---

# 11. Siapa yang Bisa Menambahkan User ke Realm?

Oracle membedakan:

```text
Realm Owner
```

dan:

```text
DV_OWNER / DV_ADMIN
```

Realm Owner **tidak otomatis dapat menambahkan user baru menjadi Realm Owner/Participant**.

Penambahan Realm authorization dilakukan oleh administrator DV seperti `DV_OWNER` atau `DV_ADMIN` sesuai kewenangan.

Contoh:

```sql
BEGIN
  DVSYS.DBMS_MACADM.ADD_AUTH_TO_REALM(
    realm_name   => 'LATIHAN Data Realm',
    grantee      => 'LATIHAN',
    auth_options => DVSYS.DBMS_MACUTL.G_REALM_AUTH_OWNER
  );
END;
/
```

---

# 12. Rule dan Rule Set

## 12.1 Rule

Rule adalah ekspresi PL/SQL yang menghasilkan kondisi:

```text
TRUE
atau
FALSE
```

Contoh kebutuhan:

```text
hanya jam kerja
hanya IP tertentu
hanya user tertentu
hanya module aplikasi tertentu
```

---

## 12.2 Rule Set

Rule Set adalah kumpulan satu atau lebih Rule.

Dua pola evaluasi utama:

```text
ALL
```

Semua rule harus `TRUE`.

```text
ANY
```

Minimal satu rule harus `TRUE`.

Contoh:

```text
RULE 1 : waktu 08:00 - 17:00
RULE 2 : IP berasal dari network internal
RULE 3 : user = APP_ADMIN

Rule Set = ALL

Akses hanya lolos jika:
RULE1 && RULE2 && RULE3 = TRUE
```

---

# 13. Rule Set pada Realm Authorization

Realm authorization dapat dikaitkan dengan Rule Set.

Contoh:

```text
LATIHAN
  |
  +-- Realm Owner
  |
  +-- hanya jika RS_MAINTENANCE = TRUE
```

Ini sangat berguna untuk:

- temporary access;
- maintenance window;
- emergency authorization;
- pembatasan jam;
- pembatasan lokasi.

Contoh:

```sql
BEGIN
  DVSYS.DBMS_MACADM.ADD_AUTH_TO_REALM(
    realm_name    => 'LATIHAN Data Realm',
    grantee       => 'LATIHAN',
    rule_set_name => 'RS_MAINTENANCE',
    auth_options  => DVSYS.DBMS_MACUTL.G_REALM_AUTH_OWNER
  );
END;
/
```

---

# 14. Command Rule

Command Rule digunakan ketika yang ingin dikontrol bukan hanya object, tetapi **SQL command**.

Contoh:

```text
CONNECT
ALTER SYSTEM
ALTER SESSION
CREATE TABLE
DROP TABLE
SELECT
```

Mental model:

```text
Realm
  -> "object mana yang dilindungi?"

Command Rule
  -> "SQL apa yang boleh dilakukan?"
```

Command Rule menggunakan Rule Set untuk mengambil keputusan.

Contoh:

```text
ALTER SYSTEM
     |
     +-- Rule Set "Maintenance Hours"
                |
                +-- TRUE -> boleh
                +-- FALSE -> ditolak
```

---

# 15. Factor

Factor adalah informasi konteks session.

Contoh factor Oracle Database Vault:

```text
Session_User
Client_IP
Database_Hostname
Network_Protocol
Module
Client_Identifier
Domain
```

Factor berguna ketika policy harus membedakan konteks.

Contoh:

```text
User APP_USER
    |
    +-- login dari aplikasi resmi -> allow
    |
    +-- login dari SQL Developer -> deny
```

Kombinasinya:

```text
Factor
  -> Rule
      -> Rule Set
          -> CONNECT Command Rule
```

Oracle bahkan memberikan tutorial untuk mencegah akses menggunakan ad-hoc tools dengan pola ini.

---

# 16. Secure Application Role

Secure Application Role adalah role yang tidak cukup hanya di-GRANT.

Role baru dapat diaktifkan ketika Rule Set yang terkait bernilai `TRUE`.

Flow:

```text
User login
   |
   +-- request SET ROLE
   |
   +-- Database Vault mengevaluasi Rule Set
          |
          +-- TRUE  -> role aktif
          +-- FALSE -> role tidak aktif
```

Package utama:

```text
DBMS_MACSEC_ROLES
```

Contoh pengecekan:

```sql
BEGIN
  IF DVSYS.DBMS_MACSEC_ROLES.CAN_SET_ROLE('APP_SECURE_ROLE') THEN
    DBMS_OUTPUT.PUT_LINE('Role can be enabled');
  END IF;
END;
/
```

Aktivasi:

```sql
EXEC DVSYS.DBMS_MACSEC_ROLES.SET_ROLE('APP_SECURE_ROLE');
```

---

# 17. Database Vault Policy

Database Vault Policy mengelompokkan:

```text
Realm
+
Command Rule
```

menjadi satu unit kebijakan.

Contoh:

```text
SAKTI Security Policy
 |
 +-- SAKTI Realm
 +-- CONNECT Command Rule
 +-- ALTER SYSTEM Command Rule
```

Manfaatnya:

- policy aplikasi mudah dikelola;
- bisa enable/disable bersama;
- bisa simulation mode;
- administrasi tertentu dapat didelegasikan melalui `DV_POLICY_OWNER`.

Status policy utama:

```text
ENABLED
DISABLED
SIMULATION
PARTIAL
```

Mode `PARTIAL` membiarkan masing-masing Realm/Command Rule mempertahankan statusnya sendiri.

---

# 18. Simulation Mode

Simulation Mode adalah salah satu fitur yang paling berguna sebelum enforcement production.

Dalam Simulation Mode:

```text
SQL dijalankan
+
violation dicatat
+
operasi tidak langsung diblok
```

Gunakan ketika:

- membuat Realm baru;
- menambah object ke Realm;
- menghapus object dari Realm;
- menambah Realm authorization;
- menghapus Realm authorization;
- mengubah Command Rule;
- menguji Factor baru.

Query:

```sql
SELECT *
FROM DVSYS.DBA_DV_SIMULATION_LOG
ORDER BY timestamp DESC;
```

Kode violation penting:

| Code | Arti |
|---:|---|
| 1000 | Realm violation |
| 1001 | Command Rule violation |
| 1002 | Data Pump authorization violation |
| 1003 | Simulation violation |
| 1004 | Scheduler authorization violation |
| 1005 | DDL authorization violation |
| 1006 | PARSE_AS_USER violation |

---

# 19. Operations Control

Operations Control adalah fitur penting Database Vault 19c untuk Multitenant.

Tujuan:

> membatasi common user/infrastructure DBA agar tidak otomatis dapat mengakses local PDB data.

Contoh:

```text
CDB Root
 |
 +-- C##INFRA_DBA
 |
 +-- PDB SAKTI
       |
       +-- APP_SCHEMA
       +-- sensitive data
```

Dengan Operations Control:

```text
C##INFRA_DBA
```

dapat mengelola infrastructure tetapi tidak otomatis melihat local application data.

Status:

```sql
SELECT *
FROM DBA_DV_STATUS;
```

Contoh:

```text
DV_APP_PROTECTION   NOT CONFIGURED
DV_CONFIGURE_STATUS TRUE
DV_ENABLE_STATUS    TRUE
```

`NOT CONFIGURED` pada `DV_APP_PROTECTION` berarti **Operations Control belum dikonfigurasi**, bukan berarti Database Vault mati.

Enable:

```sql
EXEC DVSYS.DBMS_MACADM.ENABLE_APP_PROTECTION;
```

Oracle merekomendasikan Operations Control pada production multitenant tetap aktif jika memang dipilih sebagai model keamanan.

Exception list tersedia untuk trusted common user/package yang memang membutuhkan akses.

---

# 20. Integrasi dengan Oracle Products

Oracle Guide juga membahas integrasi dengan:

- Oracle Enterprise Manager;
- Oracle Label Security;
- Oracle Data Guard;
- Oracle APEX;
- Oracle Data Pump;
- Oracle Scheduler;
- Information Lifecycle Management;
- Database Replay;
- RMAN;
- XStream;
- Oracle GoldenGate.

Pesan utamanya:

> aktivitas administratif tertentu yang sebelumnya bekerja karena privilege DBA dapat memerlukan authorization Database Vault khusus setelah DV aktif.

Jangan langsung menyimpulkan:

```text
"fitur Oracle rusak"
```

ketika Data Pump/Scheduler/APEX gagal setelah DV aktif.

Periksa authorization DV yang relevan.

---

# BAGIAN III — ROLE DAN SEPARATION OF DUTIES

# 21. Peta Role Database Vault

Oracle mengelompokkan role menjadi beberapa kategori.

## Security Administrative Roles

```text
DV_OWNER
DV_ADMIN
DV_MONITOR
DV_SECANALYST
DV_PATCH_ADMIN
DV_DATAPUMP_NETWORK_LINK
DV_XSTREAM_ADMIN
DV_GOLDENGATE_ADMIN
DV_GOLDENGATE_REDO_ACCESS
DV_AUDIT_CLEANUP
```

## Resource Management Roles

```text
DV_POLICY_OWNER
DV_REALM_OWNER
DV_REALM_RESOURCE
```

## Account Management Responsibility

```text
DV_ACCTMGR
```

---

# 22. Role Utama yang Wajib Dipahami

| Role | Fungsi | Catatan |
|---|---|---|
| `DV_OWNER` | mengelola role dan konfigurasi DV | role keamanan tertinggi DV |
| `DV_ADMIN` | administrator konfigurasi DV | execute seluruh package DV utama |
| `DV_MONITOR` | monitoring DV | fokus monitoring, bukan konfigurasi |
| `DV_SECANALYST` | analisis/report keamanan | menjalankan report dan membaca view tertentu |
| `DV_ACCTMGR` | user/profile management | jalur SoD terpisah |
| `DV_PATCH_ADMIN` | patching | berikan hanya saat diperlukan |
| `DV_AUDIT_CLEANUP` | purge audit | bukan admin DV umum |
| `DV_POLICY_OWNER` | administrasi policy terbatas | delegation policy |
| `DV_REALM_OWNER` | application/realm management | juga harus terkait authorization Realm |
| `DV_REALM_RESOURCE` | application access | menurut guide diberikan ke Realm Participant |

---

# 23. DV_OWNER vs DV_ADMIN vs DV_ACCTMGR

```text
                    DATABASE VAULT
                         |
          +--------------+--------------+
          |                             |
 Security Administration       Account Administration
          |                             |
     DV_OWNER                          DV_ACCTMGR
          |
      DV_ADMIN
```

Secara sederhana:

```text
DV_OWNER > DV_ADMIN
```

untuk jalur administrasi keamanan DV.

Namun:

```text
DV_ACCTMGR
```

bukan sekadar “role lebih rendah”.

Ia berada pada jalur responsibility yang berbeda.

---

# 24. Siapa Sebaiknya Memegang Role Apa?

Model sederhana:

| Fungsi Organisasi | Role |
|---|---|
| Security Admin utama | `DV_OWNER` |
| DBA yang mengelola konfigurasi DV | `DV_ADMIN` |
| DBA/account administrator | `DV_ACCTMGR` |
| Monitoring | `DV_MONITOR` |
| Security analyst | `DV_SECANALYST` |
| Patch operator | temporary `DV_PATCH_ADMIN` |
| Developer aplikasi | custom application role |
| Application/Realm manager | `DV_REALM_OWNER` jika memang diperlukan |

---

# 25. Developer Jangan Diberi DV_ADMIN

Developer aplikasi normal tidak perlu:

```text
DV_OWNER
DV_ADMIN
DV_ACCTMGR
```

Developer sebaiknya menggunakan:

- system privilege minimal;
- object privilege minimal;
- custom application role;
- Realm authorization bila diperlukan.

---

# 26. DV_REALM_RESOURCE dan Kondisi Environment Lab

Menurut Oracle Guide:

```text
DV_REALM_RESOURCE
```

adalah default Database Vault role untuk **application access** dan diberikan kepada Realm Participants.

Namun pada environment lab, role ini pernah tidak tersedia.

Verifikasi:

```sql
SELECT role
FROM dba_roles
WHERE role = 'DV_REALM_RESOURCE';
```

Jika:

```text
no rows selected
```

jangan membuat role Oracle-supplied tersebut secara manual dengan nama yang sama.

Untuk latihan digunakan workaround lokal:

```text
APP_DEV_STANDARD
```

Catatan:

> `APP_DEV_STANDARD` adalah custom role latihan dan **bukan pengganti resmi `DV_REALM_RESOURCE`**.

Untuk production, ketidakhadiran Oracle-supplied role perlu diperiksa terhadap instalasi/patch/catalog Database Vault.

---

# BAGIAN IV — HANDS-ON LAB

# 27. Pembagian User Lab

Contoh:

| User | Fungsi Lab | Role |
|---|---|---|
| `LATIHAN` | Security Admin | `DV_OWNER` |
| `LATIHAN1` | DV Configuration DBA | `DV_ADMIN` |
| `LATIHAN2` | Account Administrator | `DV_ACCTMGR` |
| `LATIHAN3` | Developer | `APP_DEV_STANDARD` |

Jangan gunakan password produksi pada dokumen latihan.

---

# 28. Setting SQL*Plus

```sql
SET LINESIZE 250
SET PAGESIZE 100
SET WRAP OFF
SET TRIMSPOOL ON

COLUMN username       FORMAT A18
COLUMN grantee        FORMAT A20
COLUMN granted_role   FORMAT A25
COLUMN profile        FORMAT A20
COLUMN account_status FORMAT A18
COLUMN expiry_date    FORMAT A12
```

Selalu cek:

```sql
SHOW USER;
SHOW CON_NAME;
```

---

# 29. Lab 1 — Verifikasi Database Vault

```sql
SELECT *
FROM SYS.DBA_DV_STATUS;
```

Jika login sebagai DBA/SYSDBA:

```sql
SELECT *
FROM DBA_DV_STATUS;
```

Expected:

```text
DV_CONFIGURE_STATUS TRUE
DV_ENABLE_STATUS    TRUE
```

Multitenant:

```sql
SELECT *
FROM CDB_DV_STATUS
ORDER BY CON_ID, NAME;
```

---

# 30. Lab 2 — Lihat Semua Role DV

```sql
SELECT role
FROM dba_roles
WHERE role LIKE 'DV_%'
ORDER BY role;
```

CDB:

```sql
SELECT con_id, role
FROM cdb_roles
WHERE role LIKE 'DV_%'
ORDER BY con_id, role;
```

---

# 31. Lab 3 — Lihat User dan Role

```sql
SELECT u.username,
       u.account_status,
       u.profile,
       TO_CHAR(u.created,'DD-MON-YY') AS created,
       TO_CHAR(u.expiry_date,'DD-MON-YY') AS expiry_date,
       LISTAGG(rp.granted_role, ', ')
         WITHIN GROUP (ORDER BY rp.granted_role) AS roles
FROM dba_users u
LEFT JOIN dba_role_privs rp
       ON rp.grantee = u.username
WHERE u.username LIKE 'LAT%'
GROUP BY u.username,
         u.account_status,
         u.profile,
         u.created,
         u.expiry_date
ORDER BY u.username;
```

---

# 32. Lab 4 — Cek Pemegang DV_OWNER

```sql
SELECT grantee,
       admin_option,
       default_role
FROM dba_role_privs
WHERE granted_role = 'DV_OWNER'
ORDER BY grantee;
```

Interpretasi:

```text
ADMIN_OPTION = YES
```

grant role tersebut membawa kemampuan admin option.

```text
DEFAULT_ROLE = YES
```

role aktif secara default saat login.

---

# 33. Lab 5 — Grant dan Revoke DV_OWNER

Grant:

```sql
GRANT DV_OWNER TO LATIHAN;
```

Dengan admin option:

```sql
GRANT DV_OWNER TO LATIHAN WITH ADMIN OPTION;
```

Revoke:

```sql
REVOKE DV_OWNER FROM LATIHAN;
```

Verifikasi:

```sql
SELECT grantee,
       granted_role,
       admin_option,
       default_role
FROM dba_role_privs
WHERE grantee = 'LATIHAN';
```

Pastikan tetap ada minimal account DV owner yang dapat digunakan untuk administrasi.

---

# 34. Lab 6 — Grant DV_ADMIN

Dilakukan oleh account yang mempunyai kewenangan `DV_OWNER`.

```sql
GRANT DV_ADMIN TO LATIHAN1;
```

Verifikasi:

```sql
SELECT grantee,
       granted_role,
       admin_option
FROM dba_role_privs
WHERE grantee = 'LATIHAN1';
```

---

# 35. Lab 7 — DV_ACCTMGR

`DV_ACCTMGR` sengaja dipisahkan dari `DV_OWNER`.

Jika grant menggunakan jalur yang tidak diizinkan, dapat muncul:

```text
ORA-47410:
Insufficient realm privileges to GRANT on DV_ACCTMGR
```

Gunakan account `DV_ACCTMGR` yang memang mempunyai kewenangan grant sesuai setup Database Vault.

---

# 36. Lab 8 — Custom Developer Role

Role developer standar:

```sql
CREATE ROLE APP_DEV_STANDARD;

GRANT CREATE SESSION   TO APP_DEV_STANDARD;
GRANT CREATE VIEW      TO APP_DEV_STANDARD;
GRANT CREATE PROCEDURE TO APP_DEV_STANDARD;
GRANT CREATE SEQUENCE  TO APP_DEV_STANDARD;
```

Jika developer memang membutuhkan table/trigger, buat role lebih tinggi secara terpisah.

Contoh:

```sql
CREATE ROLE APP_DEV_LEAD;

GRANT CREATE SESSION   TO APP_DEV_LEAD;
GRANT CREATE VIEW      TO APP_DEV_LEAD;
GRANT CREATE PROCEDURE TO APP_DEV_LEAD;
GRANT CREATE SEQUENCE  TO APP_DEV_LEAD;
GRANT CREATE TABLE     TO APP_DEV_LEAD;
GRANT CREATE TRIGGER   TO APP_DEV_LEAD;
GRANT CREATE SYNONYM   TO APP_DEV_LEAD;
```

Hindari:

```text
SELECT ANY TABLE
CREATE ANY TABLE
EXECUTE ANY PROCEDURE
UNLIMITED TABLESPACE
```

kecuali benar-benar dibutuhkan dan disetujui.

---

# 37. Lab 9 — Membuat Realm

Contoh Realm latihan:

```sql
BEGIN
  DVSYS.DBMS_MACADM.CREATE_REALM(
    realm_name    => 'LATIHAN Data Realm',
    description   => 'Realm untuk melindungi data latihan',
    enabled       => DVSYS.DBMS_MACUTL.G_YES,
    audit_options => DVSYS.DBMS_MACUTL.G_REALM_AUDIT_OFF,
    realm_type    => 1,
    realm_scope   => DVSYS.DBMS_MACUTL.G_SCOPE_LOCAL
  );
END;
/
```

`realm_type => 1` digunakan pada contoh lab untuk Mandatory Realm.

Untuk production, pilih Regular/Mandatory berdasarkan desain keamanan, bukan sekadar contoh script.

---

# 38. Lab 10 — Masukkan TIM_PJKI ke Realm

```sql
BEGIN
  DVSYS.DBMS_MACADM.ADD_OBJECT_TO_REALM(
    realm_name   => 'LATIHAN Data Realm',
    object_owner => 'LATIHAN',
    object_name  => 'TIM_PJKI',
    object_type  => 'TABLE'
  );
END;
/
```

Verifikasi:

```sql
SELECT realm_name,
       owner,
       object_name,
       object_type
FROM DVSYS.DBA_DV_REALM_OBJECT
WHERE realm_name = 'LATIHAN Data Realm';
```

---

# 39. Lab 11 — Realm Authorization

Tambahkan `LATIHAN` sebagai Realm Owner:

```sql
BEGIN
  DVSYS.DBMS_MACADM.ADD_AUTH_TO_REALM(
    realm_name   => 'LATIHAN Data Realm',
    grantee      => 'LATIHAN',
    auth_options => DVSYS.DBMS_MACUTL.G_REALM_AUTH_OWNER
  );
END;
/
```

Verifikasi:

```sql
SELECT realm_name,
       grantee,
       auth_options,
       auth_rule_set_name
FROM DVSYS.DBA_DV_REALM_AUTH
WHERE realm_name = 'LATIHAN Data Realm'
ORDER BY grantee;
```

---

# 40. Lab 12 — Hapus User dari Realm

```sql
BEGIN
  DVSYS.DBMS_MACADM.DELETE_AUTH_FROM_REALM(
    realm_name => 'LATIHAN Data Realm',
    grantee    => 'LATIHAN',
    auth_scope => DVSYS.DBMS_MACUTL.G_SCOPE_LOCAL
  );
END;
/
```

Verifikasi:

```sql
SELECT realm_name,
       grantee,
       auth_options
FROM DVSYS.DBA_DV_REALM_AUTH
WHERE realm_name = 'LATIHAN Data Realm';
```

---

# 41. Lab 13 — Temporary Realm Authorization

Tidak ada parameter langsung:

```text
expires_in => 30 days
```

pada `ADD_AUTH_TO_REALM`.

Gunakan Rule Set.

Contoh logika:

```text
SYSDATE < tanggal_expired
```

Contoh Rule:

```sql
BEGIN
  DVSYS.DBMS_MACADM.CREATE_RULE(
    rule_name => 'RULE_TEMP_ACCESS',
    rule_expr => q'[SYSDATE < DATE '2026-09-20']'
  );
END;
/
```

Tanggal harus disesuaikan dengan kebutuhan aktual.

Kemudian kaitkan Rule ke Rule Set dan Rule Set ke Realm Authorization.

Setelah masa akses selesai, untuk cleanup metadata tetap disarankan menghapus authorization jika sudah tidak diperlukan.

---

# 42. Lab 14 — Simulation Mode

Sebelum Realm baru di-enforce pada aplikasi production:

1. tempatkan Realm/policy pada Simulation Mode;
2. lakukan normal application workload;
3. query simulation log;
4. identifikasi violation;
5. perbaiki authorization/rule;
6. baru enforce.

Query:

```sql
SELECT session_user,
       dv$_module,
       dv$_client_identifier,
       violation_type,
       timestamp
FROM DVSYS.DBA_DV_SIMULATION_LOG
ORDER BY timestamp DESC;
```

---

# BAGIAN V — OPERASIONAL DAN TROUBLESHOOTING

# 43. Jangan Buka-Tutup Realm sebagai Solusi Pertama

Jika aplikasi/DBA mengalami error setelah DV aktif:

```text
JANGAN LANGSUNG:
DISABLE REALM
```

Gunakan urutan:

```text
1. Identifikasi user
2. Identifikasi SQL yang gagal
3. Cek Realm object
4. Cek Realm authorization
5. Cek Command Rule
6. Cek Rule Set
7. Cek simulation/audit log
8. Berikan temporary named authorization bila perlu
9. Jalankan maintenance
10. Hapus temporary authorization
```

---

# 44. Runbook Maintenance DBA

Misalnya user:

```text
DBA_MAINT
```

harus melakukan maintenance pada protected object.

## Step 1 — Tambahkan sementara

```sql
BEGIN
  DVSYS.DBMS_MACADM.ADD_AUTH_TO_REALM(
    realm_name   => '<APP_REALM>',
    grantee      => 'DBA_MAINT',
    auth_options => DVSYS.DBMS_MACUTL.G_REALM_AUTH_OWNER
  );
END;
/
```

## Step 2 — Maintenance

Lakukan hanya perubahan yang sudah disetujui.

## Step 3 — Hapus authorization

```sql
BEGIN
  DVSYS.DBMS_MACADM.DELETE_AUTH_FROM_REALM(
    realm_name => '<APP_REALM>',
    grantee    => 'DBA_MAINT'
  );
END;
/
```

## Step 4 — Review audit

Pastikan perubahan tercatat dan account tidak mempunyai authorization tersisa.

---

# 45. Query Monitoring Inti

## Status

```sql
SELECT * FROM SYS.DBA_DV_STATUS;
```

## Realm

```sql
SELECT realm_name, enabled
FROM DVSYS.DBA_DV_REALM
ORDER BY realm_name;
```

## Realm Object

```sql
SELECT realm_name,
       owner,
       object_name,
       object_type
FROM DVSYS.DBA_DV_REALM_OBJECT
ORDER BY realm_name, owner, object_name;
```

## Authorization

```sql
SELECT realm_name,
       grantee,
       auth_options,
       auth_rule_set_name
FROM DVSYS.DBA_DV_REALM_AUTH
ORDER BY realm_name, grantee;
```

## Command Rule

```sql
SELECT command,
       object_owner,
       object_name,
       enabled,
       rule_set_name
FROM DVSYS.DBA_DV_COMMAND_RULE
ORDER BY command, object_owner, object_name;
```

## Rule Set

```sql
SELECT rule_set_name,
       enabled,
       eval_options
FROM DVSYS.DBA_DV_RULE_SET
ORDER BY rule_set_name;
```

## Rule

```sql
SELECT rule_name,
       rule_expr
FROM DVSYS.DBA_DV_RULE
ORDER BY rule_name;
```

## Factor

```sql
SELECT factor_name,
       factor_type_name,
       get_expr
FROM DVSYS.DBA_DV_FACTOR
ORDER BY factor_name;
```

## Policy

```sql
SELECT policy_name,
       enabled,
       description
FROM DVSYS.DBA_DV_POLICY
ORDER BY policy_name;
```

---

# 46. Audit dan Reporting

Oracle Guide membedakan monitoring perubahan konfigurasi dan enforcement.

View penting:

```text
DVSYS.DV$CONFIGURATION_AUDIT
DVSYS.DV$ENFORCEMENT_AUDIT
DBA_DV_SIMULATION_LOG
```

Contoh:

```sql
SELECT *
FROM DVSYS.DV$CONFIGURATION_AUDIT;
```

```sql
SELECT *
FROM DVSYS.DV$ENFORCEMENT_AUDIT;
```

Oracle Database Vault Reports juga menyediakan laporan untuk:

- Command Rule configuration issues;
- Rule Set configuration issues;
- Realm authorization issues;
- Factor issues;
- audit Realm;
- audit Command Rule;
- powerful accounts;
- ANY privileges;
- direct/indirect system privileges;
- sensitive object access.

---

# 47. Query Operasional Tambahan

## Cek privilege SYS

```sql
SELECT *
FROM DBA_SYS_PRIVS
WHERE GRANTEE = 'SYS'
ORDER BY PRIVILEGE;
```

## Cek user

```sql
SELECT username,
       account_status,
       profile,
       created,
       expiry_date
FROM dba_users
WHERE username LIKE 'LAT%'
ORDER BY username;
```

## Audit trail tradisional

```sql
SELECT *
FROM DBA_AUDIT_TRAIL
WHERE USERNAME = 'LATIHAN'
ORDER BY TIMESTAMP DESC;
```

Jika database menggunakan Unified Auditing, gunakan view Unified Auditing sesuai konfigurasi audit database.

---

# 48. Troubleshooting Error Umum

## ORA-47410

```text
Insufficient realm privileges
```

Artinya operasi diblok mekanisme Realm.

Cek:

```text
Realm object
Realm authorization
protected role
grantor
```

---

## ORA-01924

```text
Role not granted or does not exist
```

Cek:

```sql
SELECT role
FROM dba_roles
WHERE role = '<ROLE>';
```

Kemudian:

```sql
SELECT grantee,
       granted_role,
       admin_option
FROM dba_role_privs
WHERE granted_role = '<ROLE>';
```

---

## ORA-01919

```text
Role does not exist
```

Jika role Oracle-supplied DV seperti `DV_REALM_RESOURCE` tidak ditemukan, jangan langsung membuat role dengan nama yang sama.

Verifikasi instalasi/catalog Database Vault.

---

## ORA-01031

```text
insufficient privileges
```

Dalam environment DV, jangan hanya cek Oracle privilege.

Gunakan checklist:

```text
[ ] system privilege
[ ] object privilege
[ ] role
[ ] Realm
[ ] Realm authorization
[ ] Rule Set
[ ] Command Rule
[ ] container/PDB
```

---

# 49. Appendix — Data Redaction

> Bagian ini merupakan **materi tambahan yang terkait praktik Database Security**, bukan komponen inti Oracle Database Vault Administrator's Guide.

Data Redaction digunakan untuk menyamarkan nilai saat query dikembalikan kepada user.

Data asli tetap tersimpan.

Contoh:

```text
TABUNGAN asli : 25000000

LATIHAN       : 25000000
LATIHAN3      : redacted
```

---

# 50. Privilege Data Redaction

Account yang membuat policy harus mempunyai privilege yang diperlukan untuk `DBMS_REDACT` pada release/configuration yang digunakan.

Contoh lab:

```sql
GRANT EXECUTE ON SYS.DBMS_REDACT TO LATIHAN;
```

Verifikasi:

```sql
SELECT grantee,
       owner,
       table_name,
       privilege
FROM dba_tab_privs
WHERE table_name = 'DBMS_REDACT'
AND grantee = 'LATIHAN';
```

Jika object berada dalam Realm, Realm authorization juga harus memenuhi policy DV.

---

# 51. Redaction pada TIM_PJKI.TABUNGAN

Contoh FULL:

```sql
BEGIN
  SYS.DBMS_REDACT.ADD_POLICY(
    object_schema      => 'LATIHAN',
    object_name        => 'TIM_PJKI',
    policy_name        => 'RDC_TABUNGAN_LAT3',
    column_name        => 'TABUNGAN',
    function_type      => SYS.DBMS_REDACT.FULL,
    expression         => q'[SYS_CONTEXT('USERENV','SESSION_USER') = 'LATIHAN3']',
    policy_description => 'Redaction TABUNGAN untuk LATIHAN3'
  );
END;
/
```

Test sebagai `LATIHAN3`:

```sql
SELECT ID_PEG,
       NAMA_DEPAN,
       TABUNGAN
FROM LATIHAN.TIM_PJKI;
```

---

# 52. NUMBER Tidak Sama dengan Literal "*****"

Jika `TABUNGAN` bertipe `NUMBER`, jangan berharap redaction langsung menghasilkan literal:

```text
*****
```

Pilihan yang lebih sesuai:

```text
FULL
NULLIFY
PARTIAL numeric
```

Jika benar-benar membutuhkan karakter `*****`, gunakan layer karakter seperti view dengan `TO_CHAR`, kemudian terapkan masking/redaction sesuai kebutuhan.

---

# 53. Cek EXEMPT REDACTION POLICY

```sql
SELECT grantee,
       privilege
FROM dba_sys_privs
WHERE grantee = 'LATIHAN3'
AND privilege = 'EXEMPT REDACTION POLICY';
```

Jika user target masking mempunyai privilege bypass ini, redaction tidak akan memberikan hasil yang diharapkan.

---

# 54. Checklist Kompetensi Peserta

## Security Admin / DV_OWNER

- [ ] memahami separation of duties
- [ ] dapat menjelaskan Regular vs Mandatory Realm
- [ ] dapat melihat status DV
- [ ] dapat membuat Realm
- [ ] dapat menambah protected object
- [ ] dapat menambah/menghapus Realm authorization
- [ ] memahami Rule dan Rule Set
- [ ] memahami Command Rule
- [ ] memahami Factor
- [ ] memahami Simulation Mode
- [ ] memahami Operations Control
- [ ] tidak menggunakan disable Realm sebagai solusi pertama

## DV_ADMIN

- [ ] dapat menggunakan `DBMS_MACADM`
- [ ] dapat mengecek Realm/Rule/Command Rule/Factor
- [ ] dapat melakukan troubleshooting policy
- [ ] dapat membaca `DBA_DV_*` views
- [ ] memahami batas kewenangannya dibanding `DV_OWNER`

## Account Administrator / DV_ACCTMGR

- [ ] memahami account/profile management
- [ ] dapat create/alter account sesuai kewenangan
- [ ] memahami pemisahan `DV_ACCTMGR` dari `DV_OWNER`
- [ ] tidak menggunakan account management role untuk administrasi security policy

## Developer

- [ ] memahami bahwa DBA privilege dan application privilege berbeda
- [ ] hanya menerima application role
- [ ] tidak menerima `DV_OWNER`
- [ ] tidak menerima `DV_ADMIN`
- [ ] dapat menguji protected object
- [ ] dapat membedakan Realm denial dan privilege denial
- [ ] memahami hasil Data Redaction

---

# 55. Cheat Sheet Keputusan Cepat

## Saya ingin melindungi schema/table

Gunakan:

```text
Realm
```

## Saya ingin membatasi CREATE / ALTER / DROP / CONNECT

Gunakan:

```text
Command Rule + Rule Set
```

## Saya ingin membatasi berdasarkan IP/jam/module

Gunakan:

```text
Factor + Rule + Rule Set
```

## Saya ingin role hanya aktif dalam kondisi tertentu

Gunakan:

```text
Secure Application Role
```

## Saya ingin mengelompokkan semua kontrol satu aplikasi

Gunakan:

```text
Database Vault Policy
```

## Saya belum yakin policy aman untuk production

Gunakan:

```text
Simulation Mode
```

## Saya ingin common DBA tidak membaca local PDB data

Pertimbangkan:

```text
Operations Control
```

## Saya ingin menyamarkan nilai query

Gunakan fitur:

```text
Data Redaction
```

bukan Realm.

---

# 56. Prinsip Operasional Final

Pegang delapan prinsip ini:

1. **Privilege bukan authorization.**
2. **DBA tidak harus dapat membaca semua data aplikasi.**
3. **Gunakan named account.**
4. **Pisahkan security admin dan account admin.**
5. **Realm adalah pagar object; Command Rule adalah pagar SQL.**
6. **Gunakan Rule Set untuk kondisi runtime.**
7. **Gunakan Simulation Mode sebelum enforcement besar.**
8. **Temporary authorization lebih aman daripada membuka Realm secara global.**

Mental model final:

```text
User
 |
 +-- Oracle Privilege
 |
 +-- Database Vault Realm Authorization
 |
 +-- Rule / Rule Set
 |
 +-- Command Rule
 |
 +-- Factor / Session Context
 |
 +-- Policy State
 |
 +----> ALLOW / DENY
```

---

# 57. Referensi Utama

Dokumen utama:

- **Oracle Database Vault Administrator's Guide**
- Release: **19c**
- Document Number: **E96302-23**
- Edition: **June 2024**

Dokumentasi operasional yang digunakan untuk melengkapi hands-on:

- `DB Sec Query v.1-SITP.sql`
- `DB Sec Query v.1.sql`

Catatan:

- Bagian 1–48 terutama merangkum konsep dan terminologi Oracle Database Vault Guide.
- Bagian Data Redaction merupakan materi tambahan dari praktik database security dan harus divalidasi terhadap dokumentasi Data Redaction yang sesuai dengan versi/patch Oracle Database yang digunakan.
- Contoh user, Realm, role custom, dan object `LATIHAN.TIM_PJKI` adalah bagian dari environment latihan, bukan default konfigurasi Oracle.
