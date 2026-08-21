# PANDUAN HANDS-ON
# Oracle Database Vault 19c dan Data Redaction

> Panduan praktikum langkah demi langkah untuk peserta  
> Basis utama: *Oracle Database Vault Administrator's Guide 19c (E96302-23, June 2024)*  
> Bagian Data Redaction menggunakan `DBMS_REDACT` dan praktik yang telah diuji pada lab.

---

## 1. Tujuan Panduan

Setelah mengikuti panduan ini, peserta diharapkan mampu:

1. memahami fungsi Oracle Database Vault (DV);
2. membedakan peran `DV_OWNER`, `DV_ADMIN`, `DV_ACCTMGR`, dan developer aplikasi;
3. mengecek apakah Database Vault sudah aktif;
4. mengecek user, profile, expiry date, dan role yang dimiliki;
5. memberikan dan mencabut role Database Vault;
6. membuat role custom untuk developer aplikasi;
7. membuat dan mengelola Realm;
8. menambahkan dan menghapus user dari Realm;
9. memahami perbedaan Realm Owner dan Realm Participant;
10. memberikan Realm authorization secara sementara;
11. menerapkan Oracle Data Redaction pada kolom sensitif;
12. menguji hasil redaction dari user aplikasi;
13. melakukan troubleshooting terhadap error yang umum muncul;
14. melakukan monitoring konfigurasi Database Vault;
15. menangani kebutuhan maintenance tanpa sembarangan membuka Realm.

---

# 2. Konsep Dasar

## 2.1 Apa itu Oracle Database Vault?

Oracle Database Vault adalah fitur Oracle Database untuk membatasi akses terhadap data dan object database, termasuk dari akun yang memiliki privilege tinggi.

Tujuan utamanya adalah:

- separation of duties;
- least privilege;
- pembatasan DBA terhadap data aplikasi;
- pengamanan object sensitif;
- pemberian akses berdasarkan konteks;
- audit dan monitoring akses.

Mental model sederhana:

```text
DATABASE
   |
   +-- Realm
   |     |
   |     +-- Object yang dilindungi
   |     +-- User/Role yang diotorisasi
   |
   +-- Rule
   |
   +-- Rule Set
   |
   +-- Command Rule
   |
   +-- Factor
   |
   +-- Policy
```

### Komponen utama

| Komponen | Fungsi sederhana |
|---|---|
| Realm | Pagar untuk schema/object/role |
| Realm Authorization | Menentukan siapa yang boleh melewati pagar |
| Rule | Satu kondisi keamanan |
| Rule Set | Kumpulan rule |
| Command Rule | Membatasi SQL tertentu |
| Factor | Konteks sesi seperti IP, user, host, module |
| Secure Application Role | Role yang aktif jika rule terpenuhi |
| Policy | Pengelompokan konfigurasi DV |
| Simulation Mode | Menguji DV tanpa langsung memblok SQL |

---

# 3. Pembagian Peran Peserta

Untuk praktikum ini digunakan contoh pembagian berikut.

| User Lab | Fungsi | Role utama |
|---|---|---|
| `LATIHAN` | Security Administrator utama | `DV_OWNER` |
| `LATIHAN1` | DBA / DV Configuration Administrator | `DV_ADMIN` |
| `LATIHAN2` | Account Administrator | `DV_ACCTMGR` |
| `LATIHAN3` | Developer aplikasi | `APP_DEV_STANDARD` |

> Catatan: secara fungsi, `DV_ACCTMGR` lebih tepat disebut **Account Administrator**, bukan Security Administrator.

---

# 4. Perbedaan Role Penting

## 4.1 DV_OWNER

`DV_OWNER` adalah role dengan kewenangan paling tinggi dalam administrasi Database Vault.

Fungsi utamanya:

- mengelola konfigurasi Database Vault;
- menggunakan package DV;
- memberikan sebagian besar role DV kepada user lain;
- mengelola administrator DV;
- melakukan monitoring dan reporting DV.

Mental model:

```text
DV_OWNER = pemilik / administrator tertinggi DV
```

## 4.2 DV_ADMIN

`DV_ADMIN` adalah administrator teknis konfigurasi Database Vault.

Fungsi:

- menjalankan package `DBMS_MACADM`;
- menjalankan package `DBMS_MACUTL`;
- mengelola Realm;
- mengelola Rule;
- mengelola Rule Set;
- mengelola Command Rule;
- mengelola Factor;
- melakukan monitoring dan reporting tertentu.

Mental model:

```text
DV_OWNER > DV_ADMIN
```

`DV_OWNER` lebih tinggi daripada `DV_ADMIN`.

## 4.3 DV_ACCTMGR

`DV_ACCTMGR` khusus untuk account management.

Dapat digunakan untuk:

- `CREATE USER`;
- `ALTER USER`;
- `DROP USER`;
- membuat/mengubah profile;
- memberikan `CREATE SESSION`.

Batasan penting:

- tidak dapat mengubah atau menghapus `DVSYS`;
- tidak dapat mengubah atau menghapus user yang memiliki `DV_OWNER`;
- tidak dapat mengubah atau menghapus user yang memiliki `DV_ADMIN`;
- tidak dapat mengganti password pemegang `DV_OWNER`/`DV_ADMIN` tanpa prosedur yang sesuai.

`DV_ACCTMGR` merupakan jalur separation of duties yang terpisah dari `DV_OWNER`.

## 4.4 Developer Aplikasi

Developer aplikasi **tidak perlu** diberi:

```text
DV_OWNER
DV_ADMIN
DV_ACCTMGR
```

Gunakan role aplikasi/custom role dengan privilege minimum.

Contoh dalam lab:

```text
APP_DEV_STANDARD
```

---

# 5. Persiapan Koneksi

Contoh koneksi SQL*Plus:

```sql
sqlplus USER/PASSWORD@DB_HOST:1521/PDB_SERVICE
```

Contoh pola:

```sql
sqlplus latihan/<password>@DB_HOST:1521/pdbxsakti
```

Untuk SYS:

```sql
sqlplus sys/<password>@DB_HOST:1521/pdbxsakti as sysdba
```

> Jangan menuliskan password asli ke dalam script, dokumen, repository, atau chat bersama.

Setelah login, selalu verifikasi:

```sql
SHOW USER;
SHOW CON_NAME;
```

Contoh:

```text
USER is "LATIHAN"

CON_NAME
------------------------------
PDBXSAKTI
```

Ini penting karena Database Vault pada lingkungan multitenant bekerja berdasarkan container.

---

# 6. Setting SQL*Plus Agar Output Rapi

Jalankan:

```sql
SET LINESIZE 250
SET PAGESIZE 100
SET WRAP OFF
SET TRIMSPOOL ON
```

Untuk query user/role:

```sql
COLUMN username       FORMAT A15
COLUMN grantee        FORMAT A20
COLUMN granted_role   FORMAT A22
COLUMN profile        FORMAT A20
COLUMN account_status FORMAT A18
COLUMN expiry_date    FORMAT A12
COLUMN roles          FORMAT A80
```

Untuk tabel `TIM_PJKI`:

```sql
COLUMN ID_PEG         FORMAT 99999
COLUMN NAMA_DEPAN     FORMAT A20
COLUMN NAMA_BELAKANG  FORMAT A20
COLUMN EMAIL          FORMAT A35
COLUMN TGL_MASUK      FORMAT A12
COLUMN TABUNGAN       FORMAT 999,999,999.99
```

---

# 7. LAB 1 — Mengecek Status Database Vault

## Pelaksana

`SYS`, `DV_OWNER`, atau administrator yang memiliki hak monitoring sesuai konfigurasi.

## 7.1 Cek container

```sql
SHOW CON_NAME;
```

## 7.2 Cek status DV pada PDB aktif

```sql
SELECT *
FROM SYS.DBA_DV_STATUS;
```

atau:

```sql
SELECT *
FROM DBA_DV_STATUS;
```

Interpretasi:

```text
DV_CONFIGURE_STATUS = TRUE
```

artinya DV sudah dikonfigurasi.

```text
DV_ENABLE_STATUS = TRUE
```

artinya DV sudah aktif.

```text
DV_APP_PROTECTION = NOT CONFIGURED
```

bukan berarti DV tidak aktif. Ini hanya menunjukkan **Operations Control / App Protection** belum dikonfigurasi.

## 7.3 Cek seluruh PDB

Dari akun yang punya akses ke CDB view:

```sql
SELECT *
FROM CDB_DV_STATUS
ORDER BY CON_ID, NAME;
```

## 7.4 Cek system privilege yang dimiliki SYS

Query ini berasal dari dokumentasi operasional SITP dan berguna untuk mengetahui system privilege yang melekat pada akun `SYS`.

```sql
SELECT *
FROM DBA_SYS_PRIVS
WHERE 1=1
AND GRANTEE = 'SYS'
--AND PRIVILEGE = 'SELECT ANY TABLE'
;
```

Jika ingin mencari privilege tertentu, aktifkan filter dengan menghapus tanda komentar:

```sql
SELECT *
FROM DBA_SYS_PRIVS
WHERE GRANTEE = 'SYS'
AND PRIVILEGE = 'SELECT ANY TABLE';
```

### Kapan query ini digunakan?

Gunakan ketika peserta ingin:

- memastikan privilege tertentu memang dimiliki `SYS`;
- membandingkan privilege native DBA dengan kontrol tambahan dari Database Vault;
- melakukan troubleshooting ketika suatu operasi DBA tetap dibatasi walaupun akun memiliki privilege tinggi.

> Penting: keberadaan system privilege tidak selalu berarti operasi pasti diizinkan ketika Database Vault aktif. Realm dan Command Rule dapat memberikan lapisan kontrol tambahan.

---

## 7.5 Cek seluruh database user

Query dari dokumentasi SITP:

```sql
SELECT *
FROM ALL_USERS
WHERE 1=1
-- AND USERNAME = 'LATIHAN'
;
```

Untuk mencari user tertentu:

```sql
SELECT *
FROM ALL_USERS
WHERE USERNAME = 'LATIHAN';
```

`ALL_USERS` cocok untuk melihat daftar user yang dapat diketahui oleh session saat ini.

Jika memiliki privilege DBA dan memerlukan informasi account yang lebih lengkap, gunakan `DBA_USERS`.

---

## 7.6 Cek status, tanggal dibuat, profile, dan expiry account

Versi asli dokumentasi SITP:

```sql
SELECT username,
       account_status,
       created,
       expiry_date
FROM dba_users
WHERE username LIKE 'LAT%'
ORDER BY username;
```

Untuk praktikum, query dapat diperluas dengan kolom `PROFILE`:

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

### Arti kolom

| Kolom | Arti |
|---|---|
| `USERNAME` | Nama database user |
| `ACCOUNT_STATUS` | Status account, misalnya `OPEN`, `LOCKED`, atau `EXPIRED` |
| `PROFILE` | Profile yang diterapkan ke user |
| `CREATED` | Tanggal user dibuat |
| `EXPIRY_DATE` | Tanggal password/account terkait password akan kedaluwarsa |

Untuk output yang lebih mudah dibaca:

```sql
COLUMN username       FORMAT A15
COLUMN account_status FORMAT A18
COLUMN profile        FORMAT A20
COLUMN created        FORMAT A12
COLUMN expiry_date    FORMAT A12

SELECT username,
       account_status,
       profile,
       TO_CHAR(created,'DD-MON-YY') AS created,
       TO_CHAR(expiry_date,'DD-MON-YY') AS expiry_date
FROM dba_users
WHERE username LIKE 'LAT%'
ORDER BY username;
```

---

## 7.7 Cek audit trail database

Query dari dokumentasi SITP:

```sql
SELECT *
FROM DBA_AUDIT_TRAIL
WHERE 1=1
-- AND USERNAME = 'LATIHAN'
ORDER BY TIMESTAMP DESC
;
```

Untuk melihat aktivitas user tertentu:

```sql
SELECT *
FROM DBA_AUDIT_TRAIL
WHERE USERNAME = 'LATIHAN'
ORDER BY TIMESTAMP DESC;
```

### Penggunaan

Query ini berguna untuk:

- menelusuri aktivitas user;
- melihat waktu eksekusi;
- membantu investigasi setelah terjadi kegagalan akses;
- menghubungkan kejadian aplikasi dengan aktivitas database.

> Catatan: `DBA_AUDIT_TRAIL` adalah view audit tradisional. Jika database menggunakan Unified Auditing, administrator juga perlu memeriksa view audit Unified Auditing sesuai konfigurasi database.

---

## 7.8 Cek seluruh tabel pada schema yang sedang digunakan

Query dari dokumentasi SITP:

```sql
SELECT table_name,
       status,
       last_analyzed
FROM user_tables
ORDER BY table_name;
```

### Arti kolom

| Kolom | Arti |
|---|---|
| `TABLE_NAME` | Nama tabel milik schema yang sedang login |
| `STATUS` | Status object |
| `LAST_ANALYZED` | Waktu terakhir statistik tabel dianalisis |

Query ini menggunakan `USER_TABLES`, sehingga hanya menampilkan tabel milik **schema user yang sedang aktif**.

Sebelum menjalankan, verifikasi user:

```sql
SHOW USER;
```

Contoh:

```text
USER is "LATIHAN"
```

maka query `USER_TABLES` akan menampilkan tabel milik schema `LATIHAN`.

---

# 8. LAB 2 — Mengecek Role Database Vault yang Tersedia

```sql
SELECT role
FROM dba_roles
WHERE role LIKE 'DV_%'
ORDER BY role;
```

Pada multitenant:

```sql
SELECT con_id,
       role
FROM cdb_roles
WHERE role LIKE 'DV_%'
ORDER BY con_id, role;
```

Contoh role yang mungkin ditemukan:

```text
DV_ACCTMGR
DV_ADMIN
DV_AUDIT_CLEANUP
DV_DATAPUMP_NETWORK_LINK
DV_GOLDENGATE_ADMIN
DV_GOLDENGATE_REDO_ACCESS
DV_MONITOR
DV_OWNER
DV_PATCH_ADMIN
DV_POLICY_OWNER
DV_SECANALYST
DV_XSTREAM_ADMIN
```

---

# 9. Catatan Khusus DV_REALM_RESOURCE

Menurut Oracle Database Vault Administrator's Guide, `DV_REALM_RESOURCE` adalah role untuk **application access** dan diberikan kepada Realm Participant.

Namun pada environment lab, role tersebut pernah tidak ditemukan:

```text
ORA-01919: Role 'DV_REALM_RESOURCE' does not exist
```

Verifikasi:

```sql
SELECT role
FROM dba_roles
WHERE role = 'DV_REALM_RESOURCE';
```

atau:

```sql
SELECT con_id, role
FROM cdb_roles
WHERE role = 'DV_REALM_RESOURCE';
```

Jika tidak ada:

**Jangan membuat role bernama `DV_REALM_RESOURCE` secara manual.**

Untuk latihan, gunakan custom role seperti:

```text
APP_DEV_STANDARD
```

Untuk production, ketidakhadiran default role DV perlu diverifikasi oleh DBA/database support terhadap instalasi dan katalog Database Vault.

---

# 10. LAB 3 — Mengecek User Pemegang DV_OWNER

```sql
SELECT grantee,
       granted_role,
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

berarti user tersebut dapat meneruskan grant role sesuai aturan DV.

```text
ADMIN_OPTION = NO
```

berarti user memiliki role tetapi grant tersebut tidak diberikan `WITH ADMIN OPTION`.

```text
DEFAULT_ROLE = YES
```

berarti role otomatis aktif pada saat login.

---

# 11. LAB 4 — Grant DV_OWNER

## Pelaksana

User yang memang sudah mempunyai `DV_OWNER` dan kewenangan grant yang sesuai.

```sql
GRANT DV_OWNER TO LATIHAN;
```

Jika `LATIHAN` juga harus dapat meneruskan grant:

```sql
GRANT DV_OWNER TO LATIHAN WITH ADMIN OPTION;
```

Verifikasi:

```sql
SELECT grantee,
       granted_role,
       admin_option,
       default_role
FROM dba_role_privs
WHERE grantee = 'LATIHAN'
AND granted_role = 'DV_OWNER';
```

---

# 12. LAB 5 — Revoke DV_OWNER

Login dengan akun DV Owner lain.

```sql
REVOKE DV_OWNER FROM LATIHAN;
```

Verifikasi:

```sql
SELECT grantee,
       granted_role
FROM dba_role_privs
WHERE grantee = 'LATIHAN'
AND granted_role = 'DV_OWNER';
```

Jika:

```text
no rows selected
```

maka role sudah berhasil dicabut.

> Jangan sampai seluruh user `DV_OWNER` terhapus. Minimal harus tetap tersedia account DV Owner yang dapat digunakan.

---

# 13. LAB 6 — Grant DV_ADMIN

## Pelaksana

`DV_OWNER`

```sql
GRANT DV_ADMIN TO LATIHAN1;
```

Jika perlu delegation:

```sql
GRANT DV_ADMIN TO LATIHAN1 WITH ADMIN OPTION;
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

# 14. LAB 7 — Grant DV_ACCTMGR

Hal penting:

```text
DV_OWNER tidak digunakan untuk memberikan DV_ACCTMGR.
```

Pemisahan ini memang disengaja oleh Database Vault.

Pada konfigurasi standar, gunakan account `DV_ACCTMGR` yang memang mempunyai kemampuan meneruskan role tersebut, misalnya backup account DV_ACCTMGR.

```sql
GRANT DV_ACCTMGR TO LATIHAN2;
```

Jika account tersebut harus dapat meneruskan role:

```sql
GRANT DV_ACCTMGR TO LATIHAN2 WITH ADMIN OPTION;
```

Error yang pernah muncul jika menggunakan jalur yang tidak sesuai:

```text
ORA-47410: Insufficient realm privileges to GRANT on DV_ACCTMGR
```

Maknanya: grant role tersebut sedang dilindungi oleh mekanisme Database Vault.

---

# 15. LAB 8 — Membuat Role Developer

Karena `DV_REALM_RESOURCE` tidak tersedia pada environment lab, dibuat role custom.

## 15.1 APP_DEV_READONLY

```sql
CREATE ROLE APP_DEV_READONLY;
GRANT CREATE SESSION TO APP_DEV_READONLY;
```

Akses tabel diberikan terpisah:

```sql
GRANT SELECT ON LATIHAN.TIM_PJKI TO APP_DEV_READONLY;
```

## 15.2 APP_DEV_STANDARD

```sql
CREATE ROLE APP_DEV_STANDARD;

GRANT CREATE SESSION   TO APP_DEV_STANDARD;
GRANT CREATE VIEW      TO APP_DEV_STANDARD;
GRANT CREATE PROCEDURE TO APP_DEV_STANDARD;
GRANT CREATE SEQUENCE  TO APP_DEV_STANDARD;
```

Role ini tidak otomatis boleh membuat tabel atau trigger.

## 15.3 APP_DEV_LEAD

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

## 15.4 Grant ke Developer

```sql
GRANT APP_DEV_STANDARD TO LATIHAN3;
```

Verifikasi:

```sql
SELECT grantee,
       granted_role,
       admin_option,
       default_role
FROM dba_role_privs
WHERE grantee = 'LATIHAN3'
ORDER BY granted_role;
```

---

# 16. Troubleshooting ORA-01924 Saat Grant Role Custom

```text
ORA-01924: Role "APP_DEV_STANDARD" not granted or does not exist
```

## 16.1 Apakah role benar-benar ada?

```sql
SELECT role
FROM dba_roles
WHERE role = 'APP_DEV_STANDARD';
```

## 16.2 Apakah grantor berhak meneruskan role?

```sql
SELECT grantee,
       granted_role,
       admin_option
FROM dba_role_privs
WHERE granted_role = 'APP_DEV_STANDARD';
```

Jika hanya `SYS` yang memiliki `ADMIN_OPTION = YES`, lakukan grant sebagai user yang memang berwenang.

Contoh lab:

```sql
CONN sys/<password>@DB_HOST:1521/PDB_SERVICE AS SYSDBA
GRANT APP_DEV_STANDARD TO LATIHAN3;
```

Jika ingin administrator lain meneruskannya:

```sql
GRANT APP_DEV_STANDARD TO <ADMIN_USER> WITH ADMIN OPTION;
```

---

# 17. LAB 9 — Query User, Profile, Expiry dan Role

## 17.1 Satu baris per role

```sql
SELECT u.username,
       u.profile,
       u.expiry_date,
       rp.granted_role,
       rp.admin_option,
       rp.default_role
FROM dba_users u
LEFT JOIN dba_role_privs rp
       ON rp.grantee = u.username
WHERE u.username LIKE 'LAT%'
ORDER BY u.username, rp.granted_role;
```

## 17.2 Semua role dalam satu baris

```sql
SELECT u.username,
       u.profile,
       TO_CHAR(u.expiry_date,'DD-MON-YY') AS expiry_date,
       LISTAGG(rp.granted_role, ', ')
         WITHIN GROUP (ORDER BY rp.granted_role) AS roles
FROM dba_users u
LEFT JOIN dba_role_privs rp
       ON rp.grantee = u.username
WHERE u.username LIKE 'LAT%'
GROUP BY u.username,
         u.profile,
         u.expiry_date
ORDER BY u.username;
```

## 17.3 Versi CDB/PDB

```sql
SELECT u.con_id,
       u.username,
       u.profile,
       TO_CHAR(u.expiry_date,'DD-MON-YY') AS expiry_date,
       LISTAGG(rp.granted_role, ', ')
         WITHIN GROUP (ORDER BY rp.granted_role) AS roles
FROM cdb_users u
LEFT JOIN cdb_role_privs rp
       ON rp.grantee = u.username
      AND rp.con_id  = u.con_id
WHERE u.username LIKE 'LAT%'
GROUP BY u.con_id,
         u.username,
         u.profile,
         u.expiry_date
ORDER BY u.con_id, u.username;
```

---

# 18. LAB 10 — Data Praktikum TIM_PJKI

Contoh struktur tabel:

```sql
CREATE TABLE TIM_PJKI (
    ID_PEG        NUMBER,
    NAMA_DEPAN    VARCHAR2(50),
    NAMA_BELAKANG VARCHAR2(50),
    EMAIL         VARCHAR2(100),
    TGL_MASUK     DATE,
    TABUNGAN      NUMBER(8,2)
);
```

Cek struktur:

```sql
DESC TIM_PJKI;
```

Query lengkap:

```sql
SELECT ID_PEG,
       NAMA_DEPAN,
       NAMA_BELAKANG,
       EMAIL,
       TO_CHAR(TGL_MASUK,'DD-MON-YYYY') AS TGL_MASUK,
       TABUNGAN
FROM TIM_PJKI;
```

Dari user lain:

```sql
SELECT ID_PEG,
       NAMA_DEPAN,
       NAMA_BELAKANG,
       EMAIL,
       TO_CHAR(TGL_MASUK,'DD-MON-YYYY') AS TGL_MASUK,
       TABUNGAN
FROM LATIHAN.TIM_PJKI;
```

---

# 19. LAB 11 — Membuat Realm

## Pelaksana

`DV_OWNER` atau `DV_ADMIN` sesuai otorisasi.

> Lab menggunakan **Mandatory Realm** (`realm_type => 1`) agar efek Realm authorization terlihat jelas. Pada production, pilih regular atau mandatory realm berdasarkan desain keamanan.

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

Verifikasi:

```sql
SELECT realm_name,
       enabled
FROM DVSYS.DBA_DV_REALM
WHERE realm_name = 'LATIHAN Data Realm';
```

---

# 20. LAB 12 — Menambahkan Object ke Realm

Untuk melindungi tabel saja:

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
WHERE realm_name = 'LATIHAN Data Realm'
ORDER BY owner, object_name;
```

---

# 21. LAB 13 — Memberikan Realm Authorization

## 21.1 Menjadikan LATIHAN sebagai Realm Owner

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

## 21.2 Realm Owner vs Participant

```text
Realm Owner
    |
    +-- administrator/pengelola realm
    +-- hak lebih tinggi terhadap resource realm

Realm Participant
    |
    +-- user/role aplikasi yang diotorisasi
    +-- tidak otomatis menjadi admin DV
```

Jangan menjadikan semua developer sebagai Realm Owner.

---

# 22. LAB 14 — Menghapus User dari Realm

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
WHERE realm_name = 'LATIHAN Data Realm'
ORDER BY grantee;
```

---

# 23. LAB 15 — Realm Authorization dengan Batas Waktu

`ADD_AUTH_TO_REALM` **tidak memiliki parameter langsung "expired 30 hari"**.

Gunakan:

```text
Rule + Rule Set + Realm Authorization
```

## 23.1 Tentukan tanggal kedaluwarsa

```sql
SELECT SYSDATE,
       SYSDATE + 30 AS EXPIRY_DATE
FROM dual;
```

Catat tanggal hasilnya.

Contoh rule:

```sql
BEGIN
  DVSYS.DBMS_MACADM.CREATE_RULE(
    rule_name => 'RULE_LATIHAN_VALID_30_HARI',
    rule_expr => q'[SYSDATE < DATE '2026-09-20']'
  );
END;
/
```

> Ganti tanggal contoh dengan tanggal 30 hari dari tanggal pelaksanaan.

## 23.2 Buat Rule Set

```sql
BEGIN
  DVSYS.DBMS_MACADM.CREATE_RULE_SET(
    rule_set_name   => 'RS_LATIHAN_30_HARI',
    description     => 'Realm authorization LATIHAN dengan batas waktu',
    enabled         => DVSYS.DBMS_MACUTL.G_YES,
    eval_options    => DVSYS.DBMS_MACUTL.G_RULESET_EVAL_ALL,
    audit_options   => DVSYS.DBMS_MACUTL.G_RULESET_AUDIT_FAIL,
    fail_options    => DVSYS.DBMS_MACUTL.G_RULESET_FAIL_SHOW,
    fail_message    => 'Realm authorization expired',
    fail_code       => 20461,
    handler_options => DVSYS.DBMS_MACUTL.G_RULESET_HANDLER_OFF,
    handler         => NULL,
    is_static       => FALSE
  );
END;
/
```

## 23.3 Masukkan Rule ke Rule Set

```sql
BEGIN
  DVSYS.DBMS_MACADM.ADD_RULE_TO_RULE_SET(
    rule_set_name => 'RS_LATIHAN_30_HARI',
    rule_name     => 'RULE_LATIHAN_VALID_30_HARI'
  );
END;
/
```

## 23.4 Kaitkan ke Realm Authorization

```sql
BEGIN
  DVSYS.DBMS_MACADM.ADD_AUTH_TO_REALM(
    realm_name    => 'LATIHAN Data Realm',
    grantee       => 'LATIHAN',
    rule_set_name => 'RS_LATIHAN_30_HARI',
    auth_options  => DVSYS.DBMS_MACUTL.G_REALM_AUTH_OWNER,
    auth_scope    => DVSYS.DBMS_MACUTL.G_SCOPE_LOCAL
  );
END;
/
```

Setelah tanggal berakhir, authorization masih tercatat tetapi rule set tidak lagi mengizinkannya. Untuk hard cleanup, jalankan `DELETE_AUTH_FROM_REALM`.

---

# 24. LAB 16 — Menyiapkan Data Redaction

Tujuan:

```text
LATIHAN3 tidak boleh melihat nilai asli TABUNGAN.
```

Data asli tetap tersimpan di tabel. Redaction dilakukan saat hasil query dikembalikan kepada user.

## 24.1 Privilege DBMS_REDACT

Login sebagai `SYS` pada PDB yang sama:

```sql
GRANT EXECUTE ON SYS.DBMS_REDACT TO LATIHAN;
```

Jika privilege tersedia pada release/patch level yang digunakan:

```sql
GRANT ADMINISTER REDACTION POLICY TO LATIHAN;
```

Untuk Oracle 19c, pastikan account pembuat policy juga memiliki privilege yang dibutuhkan terhadap schema/object miliknya, misalnya `CREATE TABLE` untuk policy pada object di schema sendiri sesuai security model `DBMS_REDACT`.

Verifikasi package privilege:

```sql
SELECT grantee,
       owner,
       table_name,
       privilege
FROM dba_tab_privs
WHERE grantee = 'LATIHAN'
AND table_name = 'DBMS_REDACT';
```

Verifikasi system privilege:

```sql
SELECT grantee,
       privilege
FROM dba_sys_privs
WHERE grantee = 'LATIHAN'
ORDER BY privilege;
```

---

# 25. Hubungan Realm dengan Data Redaction

Jika `LATIHAN.TIM_PJKI` sudah masuk `LATIHAN Data Realm`, maka user yang mengelola policy pada object tersebut harus memiliki Realm authorization yang sesuai.

Cek object:

```sql
SELECT realm_name,
       owner,
       object_name,
       object_type
FROM DVSYS.DBA_DV_REALM_OBJECT
WHERE owner = 'LATIHAN'
AND (object_name = 'TIM_PJKI'
     OR object_name = '%')
ORDER BY realm_name;
```

Cek authorization:

```sql
SELECT realm_name,
       grantee,
       auth_options,
       auth_rule_set_name
FROM DVSYS.DBA_DV_REALM_AUTH
WHERE realm_name = 'LATIHAN Data Realm'
ORDER BY grantee;
```

Jika `LATIHAN` tidak muncul, tambahkan:

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

# 26. Troubleshooting DBMS_REDACT

## 26.1 PLS-00201: DBMS_REDACT must be declared

```text
PLS-00201: identifier 'DBMS_REDACT' must be declared
```

Cek package:

```sql
SELECT owner,
       object_name,
       object_type,
       status
FROM dba_objects
WHERE object_name = 'DBMS_REDACT';
```

Cek privilege:

```sql
SELECT grantee,
       owner,
       table_name,
       privilege
FROM dba_tab_privs
WHERE table_name = 'DBMS_REDACT'
AND grantee = 'LATIHAN';
```

Jika belum ada:

```sql
GRANT EXECUTE ON SYS.DBMS_REDACT TO LATIHAN;
```

Gunakan package dengan schema eksplisit:

```text
SYS.DBMS_REDACT
```

## 26.2 ORA-01031 saat ADD_POLICY

```text
ORA-01031: insufficient privileges
ORA-06512: at "SYS.DBMS_REDACT_INT"
```

Checklist:

1. `EXECUTE ON SYS.DBMS_REDACT`;
2. privilege Data Redaction yang dipersyaratkan;
3. privilege object/schema yang dipersyaratkan;
4. apakah object dilindungi Realm;
5. apakah user sudah authorized ke Realm;
6. apakah ada Command Rule yang membatasi operasi.

Pada lab, salah satu penyebab yang ditemukan adalah `TIM_PJKI` sudah dilindungi Realm tetapi `LATIHAN` belum menjadi grantee pada realm.

---

# 27. LAB 17 — Membuat Data Redaction Policy

Karena `TABUNGAN` bertipe `NUMBER`, hasil masking tidak ideal jika ingin literal `*****`.

Untuk NUMBER gunakan `FULL`, `NULLIFY`, atau `PARTIAL` numerik.

## 27.1 Opsi A — FULL

Login sebagai `LATIHAN`:

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

## 27.2 Opsi B — NULLIFY

```sql
BEGIN
  SYS.DBMS_REDACT.ADD_POLICY(
    object_schema      => 'LATIHAN',
    object_name        => 'TIM_PJKI',
    policy_name        => 'RDC_TABUNGAN_LAT3',
    column_name        => 'TABUNGAN',
    function_type      => SYS.DBMS_REDACT.NULLIFY,
    expression         => q'[SYS_CONTEXT('USERENV','SESSION_USER') = 'LATIHAN3']',
    policy_description => 'NULL redaction TABUNGAN untuk LATIHAN3'
  );
END;
/
```

## 27.3 Opsi C — PARTIAL NUMBER

```sql
BEGIN
  SYS.DBMS_REDACT.ADD_POLICY(
    object_schema       => 'LATIHAN',
    object_name         => 'TIM_PJKI',
    policy_name         => 'RDC_TABUNGAN_LAT3',
    column_name         => 'TABUNGAN',
    function_type       => SYS.DBMS_REDACT.PARTIAL,
    function_parameters => '0,1,6',
    expression          => q'[SYS_CONTEXT('USERENV','SESSION_USER') = 'LATIHAN3']',
    policy_description  => 'Partial redaction TABUNGAN untuk LATIHAN3'
  );
END;
/
```

> Untuk production, validasi format partial masking terhadap datatype dan pola data aktual.

---

# 28. LAB 18 — Menguji Data Redaction

## 28.1 Test sebagai LATIHAN3

```sql
CONN latihan3/<password>@DB_HOST:1521/PDB_SERVICE
SHOW USER;
SHOW CON_NAME;
```

Query:

```sql
SELECT ID_PEG,
       NAMA_DEPAN,
       TABUNGAN
FROM LATIHAN.TIM_PJKI;
```

Expected result:

```text
TABUNGAN tidak menampilkan nilai asli
```

Tergantung jenis redaction:

```text
FULL     -> nilai fixed/redacted
NULLIFY  -> NULL
PARTIAL  -> nilai numerik tersamarkan
```

## 28.2 Test sebagai LATIHAN

```sql
CONN latihan/<password>@DB_HOST:1521/PDB_SERVICE
```

```sql
SELECT ID_PEG,
       NAMA_DEPAN,
       TABUNGAN
FROM TIM_PJKI;
```

Expected:

```text
LATIHAN melihat data asli
```

karena expression hanya berlaku untuk `SESSION_USER = LATIHAN3`.

---

# 29. Cek EXEMPT REDACTION POLICY

Jika user mempunyai `EXEMPT REDACTION POLICY`, redaction dapat dilewati.

```sql
SELECT grantee,
       privilege
FROM dba_sys_privs
WHERE grantee = 'LATIHAN3'
AND privilege = 'EXEMPT REDACTION POLICY';
```

Jika tidak dibutuhkan:

```sql
REVOKE EXEMPT REDACTION POLICY FROM LATIHAN3;
```

---

# 30. Mengecek Data Redaction Policy

```sql
SELECT object_owner,
       object_name,
       policy_name,
       expression
FROM redaction_policies
WHERE object_owner = 'LATIHAN'
AND object_name = 'TIM_PJKI';
```

Kolom:

```sql
SELECT object_owner,
       object_name,
       column_name,
       function_type,
       function_parameters
FROM redaction_columns
WHERE object_owner = 'LATIHAN'
AND object_name = 'TIM_PJKI';
```

---

# 31. Disable Data Redaction Policy

```sql
BEGIN
  SYS.DBMS_REDACT.DISABLE_POLICY(
    object_schema => 'LATIHAN',
    object_name   => 'TIM_PJKI',
    policy_name   => 'RDC_TABUNGAN_LAT3'
  );
END;
/
```

# 32. Enable Kembali Data Redaction Policy

```sql
BEGIN
  SYS.DBMS_REDACT.ENABLE_POLICY(
    object_schema => 'LATIHAN',
    object_name   => 'TIM_PJKI',
    policy_name   => 'RDC_TABUNGAN_LAT3'
  );
END;
/
```

# 33. Menghapus Data Redaction Policy

```sql
BEGIN
  SYS.DBMS_REDACT.DROP_POLICY(
    object_schema => 'LATIHAN',
    object_name   => 'TIM_PJKI',
    policy_name   => 'RDC_TABUNGAN_LAT3'
  );
END;
/
```

---

# 34. Jika Ingin Tampil Literal "*****"

Karena `TABUNGAN = NUMBER`, Data Redaction langsung pada kolom tersebut tidak dirancang untuk mengembalikan literal karakter `*****`.

Pilihan:

```text
A. FULL redaction langsung pada NUMBER
B. NULLIFY langsung pada NUMBER
C. Partial numeric redaction
D. View yang mengubah NUMBER menjadi VARCHAR2 lalu redaction pada view
```

Jika harus literal bintang, pendekatan view lebih cocok daripada mengubah datatype tabel asli.

---

# 35. LAB 19 — Mengecek Semua Realm

```sql
SELECT realm_name,
       enabled,
       audit_options
FROM DVSYS.DBA_DV_REALM
ORDER BY realm_name;
```

# 36. Mengecek Object yang Dilindungi Realm

```sql
SELECT realm_name,
       owner,
       object_name,
       object_type
FROM DVSYS.DBA_DV_REALM_OBJECT
ORDER BY realm_name,
         owner,
         object_name;
```

# 37. Mengecek Realm Authorization

```sql
SELECT realm_name,
       grantee,
       auth_options,
       auth_rule_set_name
FROM DVSYS.DBA_DV_REALM_AUTH
ORDER BY realm_name,
         grantee;
```

# 38. Mengecek Command Rule

```sql
SELECT command,
       object_owner,
       object_name,
       enabled,
       rule_set_name
FROM DVSYS.DBA_DV_COMMAND_RULE
ORDER BY command,
         object_owner,
         object_name;
```

# 39. Mengecek Rule Set

```sql
SELECT rule_set_name,
       enabled,
       eval_options
FROM DVSYS.DBA_DV_RULE_SET
ORDER BY rule_set_name;
```

Relasi rule:

```sql
SELECT rule_set_name,
       rule_name
FROM DVSYS.DBA_DV_RULE_SET_RULE
ORDER BY rule_set_name,
         rule_name;
```

Rule:

```sql
SELECT rule_name,
       rule_expr
FROM DVSYS.DBA_DV_RULE
ORDER BY rule_name;
```

# 40. Mengecek Factor

```sql
SELECT factor_name,
       factor_type_name,
       get_expr
FROM DVSYS.DBA_DV_FACTOR
ORDER BY factor_name;
```

# 41. Mengecek Policy DV

```sql
SELECT policy_name,
       enabled,
       description
FROM DVSYS.DBA_DV_POLICY
ORDER BY policy_name;
```

---

# 42. Simulation Mode

Untuk konfigurasi baru, Oracle Database Vault menyediakan simulation mode.

Tujuan:

```text
SQL tetap berjalan
namun violation dicatat.
```

Ini sebaiknya digunakan sebelum enforcement pada aplikasi production.

Cek log:

```sql
SELECT *
FROM DVSYS.DBA_DV_SIMULATION_LOG
ORDER BY timestamp DESC;
```

Mental model:

```text
SIMULATION
    |
    +-- SQL tidak langsung diblok
    +-- pelanggaran dicatat
    +-- DBA/Security Admin review
    +-- policy diperbaiki
    +-- baru ENABLE
```

---

# 43. Menangani Trouble User Aplikasi / DBA

Jangan menjadikan `DISABLE REALM` sebagai langkah pertama.

Urutan penanganan:

```text
1. Identifikasi user
2. Identifikasi SQL yang gagal
3. Cek Realm
4. Cek Realm Authorization
5. Cek Rule Set
6. Cek Command Rule
7. Jika perlu gunakan Simulation Mode
8. Berikan temporary authorization ke named account
9. Lakukan maintenance
10. Hapus authorization setelah selesai
```

---

# 44. Kenapa Jangan Sering Buka/Tutup Realm?

Saat Realm disabled, scope perlindungan yang hilang biasanya lebih luas daripada kebutuhan maintenance.

Risiko:

- DBA lain ikut memperoleh akses;
- user lain dapat menggunakan privilege yang sebelumnya diblok;
- troubleshooting menjadi sulit diaudit;
- separation of duties melemah.

Lebih aman:

```text
temporary named-user authorization
+
rule set
+
audit
```

---

# 45. Runbook Emergency Maintenance

Misalnya DBA `DBA_MAINT` harus mengubah object aplikasi.

## Step 1 — Jangan disable realm

```sql
SELECT realm_name,
       owner,
       object_name,
       object_type
FROM DVSYS.DBA_DV_REALM_OBJECT
WHERE owner = '<APP_SCHEMA>';
```

## Step 2 — Tambahkan named account sementara

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

## Step 3 — Maintenance

Lakukan aktivitas yang telah disetujui.

## Step 4 — Hapus authorization

```sql
BEGIN
  DVSYS.DBMS_MACADM.DELETE_AUTH_FROM_REALM(
    realm_name => '<APP_REALM>',
    grantee    => 'DBA_MAINT'
  );
END;
/
```

## Step 5 — Verifikasi

```sql
SELECT *
FROM DVSYS.DBA_DV_REALM_AUTH
WHERE grantee = 'DBA_MAINT';
```

---

# 46. Troubleshooting Error yang Ditemui Selama Praktik

## ORA-47410

```text
ORA-47410: Insufficient realm privileges to GRANT on DV_ACCTMGR
```

Penyebab: user yang melakukan grant bukan jalur account-management yang diizinkan DV.

Solusi: gunakan akun pemegang `DV_ACCTMGR` yang sah dan mempunyai kemampuan grant.

## ORA-01924

```text
ORA-01924: Role "X" not granted or does not exist
```

Kemungkinan:

- typo;
- role tidak ada;
- role tidak dimiliki grantor dengan admin option;
- role management dilindungi DV.

Cek:

```sql
SELECT role
FROM dba_roles
WHERE role = 'X';
```

```sql
SELECT grantee,
       granted_role,
       admin_option
FROM dba_role_privs
WHERE granted_role = 'X';
```

## ORA-01919

```text
ORA-01919: Role 'DV_REALM_RESOURCE' does not exist
```

Cek:

```sql
SELECT con_id, role
FROM cdb_roles
WHERE role = 'DV_REALM_RESOURCE';
```

Jangan membuat replika default DV role secara manual.

## PLS-00201 DBMS_REDACT

```text
identifier 'DBMS_REDACT' must be declared
```

Cek:

```sql
SELECT owner,
       object_name,
       status
FROM dba_objects
WHERE object_name = 'DBMS_REDACT';
```

```sql
SELECT *
FROM dba_tab_privs
WHERE table_name = 'DBMS_REDACT'
AND grantee = '<USER>';
```

## ORA-01031 pada DBMS_REDACT

Checklist:

```text
[ ] EXECUTE ON SYS.DBMS_REDACT
[ ] privilege redaction yang dipersyaratkan
[ ] privilege object/schema yang dipersyaratkan
[ ] Realm authorization
[ ] Command Rule
```

---

# 47. Query Ringkas Audit Seluruh DV

```sql
SELECT * FROM SYS.DBA_DV_STATUS;

SELECT realm_name, enabled
FROM DVSYS.DBA_DV_REALM
ORDER BY realm_name;

SELECT realm_name, owner, object_name, object_type
FROM DVSYS.DBA_DV_REALM_OBJECT
ORDER BY realm_name, owner, object_name;

SELECT realm_name, grantee, auth_options
FROM DVSYS.DBA_DV_REALM_AUTH
ORDER BY realm_name, grantee;

SELECT command, object_owner, object_name, enabled, rule_set_name
FROM DVSYS.DBA_DV_COMMAND_RULE
ORDER BY command, object_owner, object_name;

SELECT rule_set_name, enabled
FROM DVSYS.DBA_DV_RULE_SET
ORDER BY rule_set_name;

SELECT factor_name
FROM DVSYS.DBA_DV_FACTOR
ORDER BY factor_name;

SELECT policy_name, enabled
FROM DVSYS.DBA_DV_POLICY
ORDER BY policy_name;
```

---

# 48. Checklist Praktikum per Peserta

## Peserta A — Security Admin / DV_OWNER

- [ ] Login sebagai user `DV_OWNER`
- [ ] Verifikasi `SHOW USER`
- [ ] Verifikasi `SHOW CON_NAME`
- [ ] Cek `DBA_DV_STATUS`
- [ ] Cek seluruh role DV
- [ ] Cek pemegang `DV_OWNER`
- [ ] Grant/revoke `DV_ADMIN`
- [ ] Buat Realm
- [ ] Tambahkan object ke Realm
- [ ] Tambahkan Realm Owner/Participant
- [ ] Hapus Realm authorization
- [ ] Cek Rule Set
- [ ] Cek Command Rule
- [ ] Cek simulation log

## Peserta B — DBA / DV_ADMIN

- [ ] Login sebagai `DV_ADMIN`
- [ ] Cek Realm
- [ ] Cek Realm object
- [ ] Cek Realm authorization
- [ ] Menggunakan `DBMS_MACADM` sesuai kewenangan
- [ ] Review Rule/Rule Set
- [ ] Review Command Rule
- [ ] Review Factor
- [ ] Troubleshoot blocked operation
- [ ] Tidak menggunakan `DV_OWNER` jika `DV_ADMIN` sudah cukup

## Peserta C — Account Administrator / DV_ACCTMGR

- [ ] Login sebagai `DV_ACCTMGR`
- [ ] Cek user
- [ ] Cek profile
- [ ] Cek expiry date
- [ ] Create/alter account sesuai kebutuhan lab
- [ ] Memberikan `CREATE SESSION`
- [ ] Memahami bahwa `DV_ACCTMGR` terpisah dari `DV_OWNER`
- [ ] Tidak mencoba mengelola policy/Realm menggunakan role account manager

## Peserta D — Developer / APP_DEV_STANDARD

- [ ] Login sebagai `LATIHAN3`
- [ ] Verifikasi role
- [ ] Cek object yang dapat diakses
- [ ] Query `LATIHAN.TIM_PJKI`
- [ ] Membandingkan data sebelum dan sesudah redaction
- [ ] Memastikan `TABUNGAN` tidak terlihat asli
- [ ] Tidak memiliki role `DV_OWNER`
- [ ] Tidak memiliki role `DV_ADMIN`
- [ ] Tidak memiliki `EXEMPT REDACTION POLICY`

---

# 49. Best Practice Final

1. Gunakan **named account**, bukan akun bersama.
2. Pisahkan fungsi Security Admin, DBA Configuration, Account Admin, dan Developer.
3. Jangan memberikan `DV_OWNER` ke developer.
4. Jangan memberikan `DV_ADMIN` hanya agar DBA "lebih mudah".
5. Jangan menggunakan `SYS` untuk pekerjaan rutin.
6. Gunakan custom role untuk developer jika default role DV tidak sesuai/tersedia.
7. Hindari privilege `ANY` untuk developer.
8. Batasi quota tablespace.
9. Gunakan Realm untuk melindungi object sensitif.
10. Gunakan Realm authorization untuk kebutuhan maintenance.
11. Gunakan Rule Set untuk pembatasan waktu/kondisi.
12. Gunakan Simulation Mode sebelum enforcement production.
13. Jangan membuka/menutup Realm sembarangan saat incident.
14. Review audit/violation setelah perubahan.
15. Hapus temporary authorization setelah maintenance.
16. Pastikan target redaction tidak mempunyai `EXEMPT REDACTION POLICY`.
17. Jangan memasukkan password asli ke dokumen atau script bersama.

---

# 50. Quick Reference

## Status DV

```sql
SELECT * FROM SYS.DBA_DV_STATUS;
```

## Semua role DV

```sql
SELECT role
FROM dba_roles
WHERE role LIKE 'DV_%'
ORDER BY role;
```

## Pemegang DV_OWNER

```sql
SELECT grantee, admin_option, default_role
FROM dba_role_privs
WHERE granted_role = 'DV_OWNER';
```

## Realm

```sql
SELECT realm_name, enabled
FROM DVSYS.DBA_DV_REALM;
```

## Realm Object

```sql
SELECT realm_name, owner, object_name, object_type
FROM DVSYS.DBA_DV_REALM_OBJECT;
```

## Realm Authorization

```sql
SELECT realm_name, grantee, auth_options
FROM DVSYS.DBA_DV_REALM_AUTH;
```

## Add Authorization

```sql
BEGIN
  DVSYS.DBMS_MACADM.ADD_AUTH_TO_REALM(
    realm_name   => '<REALM>',
    grantee      => '<USER>',
    auth_options => DVSYS.DBMS_MACUTL.G_REALM_AUTH_OWNER
  );
END;
/
```

## Delete Authorization

```sql
BEGIN
  DVSYS.DBMS_MACADM.DELETE_AUTH_FROM_REALM(
    realm_name => '<REALM>',
    grantee    => '<USER>'
  );
END;
/
```

## Data Redaction FULL

```sql
BEGIN
  SYS.DBMS_REDACT.ADD_POLICY(
    object_schema => '<SCHEMA>',
    object_name   => '<TABLE>',
    policy_name   => '<POLICY>',
    column_name   => '<COLUMN>',
    function_type => SYS.DBMS_REDACT.FULL,
    expression    => q'[SYS_CONTEXT('USERENV','SESSION_USER') = '<TARGET_USER>']'
  );
END;
/
```

---

# 50A. Query Pack Operasional dari Dokumentasi SITP

Bagian ini mempertahankan query operasional yang terdapat pada file dokumentasi peserta agar dapat langsung digunakan saat praktikum.

## A. Cek privilege SYS

```sql
SELECT *
FROM DBA_SYS_PRIVS
WHERE 1=1
AND GRANTEE = 'SYS'
--AND PRIVILEGE = 'SELECT ANY TABLE'
;
```

## B. Cek seluruh user

```sql
SELECT *
FROM ALL_USERS
WHERE 1=1
-- AND USERNAME = 'LATIHAN'
;
```

## C. Cek status dan expiry account peserta

```sql
SELECT username,
       account_status,
       created,
       expiry_date
FROM dba_users
WHERE username LIKE 'LAT%'
ORDER BY username
;
```

## D. Cek audit trail

```sql
SELECT *
FROM DBA_AUDIT_TRAIL
WHERE 1=1
-- AND USERNAME = 'LATIHAN'
ORDER BY TIMESTAMP DESC
;
```

## E. Cek tabel pada schema aktif

```sql
SELECT table_name,
       status,
       last_analyzed
FROM user_tables
ORDER BY table_name;
```

## F. Cek seluruh role Database Vault pada container

```sql
SHOW CON_NAME;

SELECT *
--SELECT con_id, role
FROM cdb_roles
WHERE role LIKE 'DV_%'
ORDER BY con_id, role;
```

> Query pada bagian ini berasal dari dokumentasi `DB Sec Query v.1-SITP.sql`. File `DB Sec Query v.1.sql` memuat query dasar pengecekan privilege `SYS`, yang sudah tercakup pada bagian A.

---

# 51. Referensi

Sumber utama:

- Oracle Database Vault Administrator's Guide 19c
- Document Number: E96302-23
- Release: 19c
- June 2024

Dokumentasi operasional peserta yang digunakan untuk melengkapi panduan:

- `DB Sec Query v.1-SITP.sql`
- `DB Sec Query v.1.sql`

Bagian yang paling relevan:

- Introduction to Oracle Database Vault
- Getting Started with Oracle Database Vault
- Configuring Realms
- Configuring Rule Sets
- Configuring Command Rules
- Configuring Factors
- Oracle Database Vault Policies
- Simulation Mode
- DBA Operations in an Oracle Database Vault Environment
- Oracle Database Vault Schemas, Roles, and Accounts
- Oracle Database Vault Realm APIs
- Oracle Database Vault Rule Set APIs

Catatan Data Redaction:

- Praktik menggunakan package `SYS.DBMS_REDACT`.
- Requirement privilege dapat berbeda mengikuti release/patch level Oracle.
- Validasi selalu pada dokumentasi Oracle yang sesuai dengan versi database yang digunakan.
- Dalam environment Database Vault, Realm/Command Rule dapat menambah lapisan kontrol terhadap administrasi Data Redaction.

---

# 52. Penutup

Prinsip yang perlu selalu diingat:

```text
DBA privilege != hak melihat seluruh data
```

Database Vault memisahkan administrasi database dari otorisasi terhadap data aplikasi.

Model sederhana:

```text
Security Admin
    |
    +-- DV_OWNER
    |
DBA / DV Configuration Admin
    |
    +-- DV_ADMIN
    |
Account Administrator
    |
    +-- DV_ACCTMGR
    |
Developer
    |
    +-- APP_DEV_STANDARD
```

Kemudian data sensitif dilindungi menggunakan:

```text
Realm
  +
Realm Authorization
  +
Rule / Rule Set
  +
Command Rule jika dibutuhkan
  +
Data Redaction untuk tampilan data sensitif
```

Dengan model tersebut, setiap peserta memiliki tanggung jawab yang jelas dan tidak perlu memegang seluruh kewenangan database.
