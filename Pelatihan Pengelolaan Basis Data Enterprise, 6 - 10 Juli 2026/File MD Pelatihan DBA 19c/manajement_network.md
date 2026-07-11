
# HANDS-ON LAB

# Manajemen tnsnames.ora dan listener.ora Oracle 19c

Asumsi:

```text
Database      : ORADB
PDB           : PDB1
Port Listener : 1521
Host          : localhost / hostname server
Oracle Home   : /u01/app/oracle/product/19.0.0/dbhome_1
OS User       : oracle
```

---

# 0. Persiapan Awal

Login sebagai user `oracle`.

```bash
su - oracle
```

Cek environment Oracle.

```bash
echo $ORACLE_HOME
echo $ORACLE_SID
echo $TNS_ADMIN
```

Contoh output:

```text
/u01/app/oracle/product/19.0.0/dbhome_1
ORADB

```

Jika `TNS_ADMIN` kosong, Oracle biasanya membaca network file dari:

```bash
$ORACLE_HOME/network/admin
```

Cek folder network admin.

```bash
ls -ld $ORACLE_HOME/network/admin
```

Contoh output:

```text
drwxr-xr-x. 2 oracle oinstall 4096 Jul 4 10:00 /u01/app/oracle/product/19.0.0/dbhome_1/network/admin
```

Masuk ke folder network admin.

```bash
cd $ORACLE_HOME/network/admin
pwd
```

Contoh output:

```text
/u01/app/oracle/product/19.0.0/dbhome_1/network/admin
```

---

# LAB 1 — Backup File Network Existing

## 1.1 Backup file konfigurasi

```bash
cp -p listener.ora listener.ora.bak_$(date +%Y%m%d_%H%M%S) 2>/dev/null
cp -p tnsnames.ora tnsnames.ora.bak_$(date +%Y%m%d_%H%M%S) 2>/dev/null
cp -p sqlnet.ora sqlnet.ora.bak_$(date +%Y%m%d_%H%M%S) 2>/dev/null
```

## 1.2 Verifikasi backup

```bash
ls -lh *.bak_* 2>/dev/null
```

Contoh output:

```text
-rw-r--r--. 1 oracle oinstall 512 Jul 4 10:05 listener.ora.bak_20260704_100501
-rw-r--r--. 1 oracle oinstall 680 Jul 4 10:05 tnsnames.ora.bak_20260704_100501
```

---

# LAB 2 — Melihat Listener Existing

## 2.1 Cek status listener

```bash
lsnrctl status
```

Contoh output:

```text
LSNRCTL for Linux: Version 19.0.0.0.0

Connecting to (DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=localhost)(PORT=1521)))
STATUS of the LISTENER
------------------------
Alias                     LISTENER
Version                   TNSLSNR for Linux: Version 19.0.0.0.0
Start Date                04-JUL-2026 10:00:00
Uptime                    0 days 0 hr. 5 min. 10 sec
Listening Endpoints Summary...
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=localhost)(PORT=1521)))
Services Summary...
Service "ORADB" has 1 instance(s).
Service "PDB1" has 1 instance(s).
The command completed successfully
```

## 2.2 Cek service yang dikenali listener

```bash
lsnrctl services
```

Contoh output:

```text
Services Summary...
Service "ORADB" has 1 instance(s).
  Instance "ORADB", status READY, has 1 handler(s) for this service...
Service "PDB1" has 1 instance(s).
  Instance "ORADB", status READY, has 1 handler(s) for this service...
The command completed successfully
```

---

# LAB 3 — Membuat listener.ora Sederhana

## 3.1 Cek hostname server

```bash
hostname
hostname -f
ip addr show | grep "inet " | grep -v 127.0.0.1
```

Contoh output:

```text
oracle19c
oracle19c.localdomain
inet 192.168.56.10/24 brd 192.168.56.255 scope global enp0s3
```

## 3.2 Buat file listener.ora baru

```bash
cat > $ORACLE_HOME/network/admin/listener.ora <<'EOF'
LISTENER =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = 1521))
      (ADDRESS = (PROTOCOL = TCP)(HOST = 192.168.56.10)(PORT = 1521))
    )
  )

ADR_BASE_LISTENER = /u01/app/oracle
EOF
```

> Ganti `192.168.56.10` sesuai IP server Anda.

## 3.3 Verifikasi isi file

```bash
cat $ORACLE_HOME/network/admin/listener.ora
```

Contoh output:

```text
LISTENER =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = 1521))
      (ADDRESS = (PROTOCOL = TCP)(HOST = 192.168.56.10)(PORT = 1521))
    )
  )

ADR_BASE_LISTENER = /u01/app/oracle
```

---

# LAB 4 — Restart Listener

## 4.1 Stop listener

```bash
lsnrctl stop
```

Contoh output:

```text
Connecting to (DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=localhost)(PORT=1521)))
The command completed successfully
```

## 4.2 Start listener

```bash
lsnrctl start
```

Contoh output:

```text
Starting /u01/app/oracle/product/19.0.0/dbhome_1/bin/tnslsnr: please wait...

TNSLSNR for Linux: Version 19.0.0.0.0
System parameter file is /u01/app/oracle/product/19.0.0/dbhome_1/network/admin/listener.ora
Log messages written to /u01/app/oracle/diag/tnslsnr/oracle19c/listener/alert/log.xml
Listening on: (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=localhost)(PORT=1521)))
Listening on: (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=192.168.56.10)(PORT=1521)))

The command completed successfully
```

## 4.3 Verifikasi status

```bash
lsnrctl status
```

Contoh output:

```text
Listening Endpoints Summary...
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=localhost)(PORT=1521)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=192.168.56.10)(PORT=1521)))
The command completed successfully
```

---

# LAB 5 — Register Database ke Listener

Masuk SQL*Plus.

```bash
sqlplus / as sysdba
```

## 5.1 Cek database dan PDB

```sql
SELECT name, cdb, open_mode FROM v$database;
SHOW PDBS
```

Contoh output:

```text
NAME      CDB OPEN_MODE
--------- --- --------------------
ORADB     YES READ WRITE

    CON_ID CON_NAME                       OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
         2 PDB$SEED                       READ ONLY  NO
         3 PDB1                           READ WRITE NO
```

## 5.2 Set local_listener

```sql
ALTER SYSTEM SET local_listener='(ADDRESS=(PROTOCOL=TCP)(HOST=localhost)(PORT=1521))' SCOPE=BOTH;
```

Contoh output:

```text
System altered.
```

## 5.3 Register ulang service ke listener

```sql
ALTER SYSTEM REGISTER;
```

Contoh output:

```text
System altered.
```

## 5.4 Verifikasi dari OS

```bash
lsnrctl services
```

Contoh output:

```text
Service "ORADB" has 1 instance(s).
  Instance "ORADB", status READY, has 1 handler(s) for this service...
Service "PDB1" has 1 instance(s).
  Instance "ORADB", status READY, has 1 handler(s) for this service...
```

---

# LAB 6 — Membuat tnsnames.ora

## 6.1 Buat file tnsnames.ora

```bash
cat > $ORACLE_HOME/network/admin/tnsnames.ora <<'EOF'
ORADB =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = ORADB)
    )
  )

PDB1 =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = PDB1)
    )
  )

PDB1_IP =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = 192.168.56.10)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = PDB1)
    )
  )
EOF
```

> Ganti `192.168.56.10` sesuai IP server Anda.

## 6.2 Verifikasi isi tnsnames.ora

```bash
cat $ORACLE_HOME/network/admin/tnsnames.ora
```

Contoh output:

```text
ORADB =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = ORADB)
    )
  )

PDB1 =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = PDB1)
    )
  )
```

---

# LAB 7 — Test Koneksi Menggunakan TNS Alias

## 7.1 Test `tnsping`

```bash
tnsping PDB1
```

Contoh output:

```text
Used parameter files:
/u01/app/oracle/product/19.0.0/dbhome_1/network/admin/sqlnet.ora

Used TNSNAMES adapter to resolve the alias
Attempting to contact (DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=localhost)(PORT=1521))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=PDB1)))
OK (10 msec)
```

## 7.2 Test koneksi SYS ke PDB1

```bash
sqlplus sys/oracle@PDB1 as sysdba
```

Contoh output:

```text
Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0
```

Verifikasi container:

```sql
SHOW CON_NAME
```

Contoh output:

```text
CON_NAME
------------------------------
PDB1
```

Keluar:

```sql
EXIT
```

---

# LAB 8 — Membuat User untuk Test Koneksi

```bash
sqlplus / as sysdba
```

```sql
ALTER SESSION SET CONTAINER=PDB1;

CREATE USER netuser IDENTIFIED BY oracle
DEFAULT TABLESPACE USERS
TEMPORARY TABLESPACE TEMP
QUOTA UNLIMITED ON USERS;

GRANT CREATE SESSION TO netuser;
```

Contoh output:

```text
Session altered.
User created.
Grant succeeded.
```

Verifikasi user:

```sql
SELECT username, account_status
FROM dba_users
WHERE username = 'NETUSER';
```

Contoh output:

```text
USERNAME        ACCOUNT_STATUS
--------------- ----------------
NETUSER         OPEN
```

Test koneksi:

```bash
sqlplus netuser/oracle@PDB1
```

Contoh output:

```text
Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0
```

```sql
SHOW USER
SHOW CON_NAME
```

Contoh output:

```text
USER is "NETUSER"

CON_NAME
------------------------------
PDB1
```

---

# LAB 9 — Menambahkan Alias Baru di tnsnames.ora

## 9.1 Tambahkan alias baru

```bash
cat >> $ORACLE_HOME/network/admin/tnsnames.ora <<'EOF'

PDB1_TRAINING =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = PDB1)
    )
  )
EOF
```

## 9.2 Verifikasi alias baru

```bash
grep -A8 "PDB1_TRAINING" $ORACLE_HOME/network/admin/tnsnames.ora
```

Contoh output:

```text
PDB1_TRAINING =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = PDB1)
    )
  )
```

## 9.3 Test alias

```bash
tnsping PDB1_TRAINING
sqlplus netuser/oracle@PDB1_TRAINING
```

Contoh output:

```text
OK (10 msec)

Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0
```

---

# LAB 10 — Menghapus Alias dari tnsnames.ora

Cara paling aman adalah membuat ulang file tanpa alias yang ingin dihapus.

## 10.1 Backup dulu

```bash
cp -p $ORACLE_HOME/network/admin/tnsnames.ora \
$ORACLE_HOME/network/admin/tnsnames.ora.before_delete_alias
```

## 10.2 Hapus alias `PDB1_TRAINING`

```bash
perl -0pi -e 's/\nPDB1_TRAINING\s*=\s*\(DESCRIPTION\s*=\s*\n\s*\(ADDRESS\s*=\s*\(PROTOCOL\s*=\s*TCP\)\(HOST\s*=\s*localhost\)\(PORT\s*=\s*1521\)\)\s*\n\s*\(CONNECT_DATA\s*=\s*\n\s*\(SERVER\s*=\s*DEDICATED\)\s*\n\s*\(SERVICE_NAME\s*=\s*PDB1\)\s*\n\s*\)\s*\n\s*\)\s*\n//s' $ORACLE_HOME/network/admin/tnsnames.ora
```

## 10.3 Verifikasi alias sudah hilang

```bash
grep "PDB1_TRAINING" $ORACLE_HOME/network/admin/tnsnames.ora
```

Contoh output:

```text
```

Test alias yang sudah dihapus:

```bash
tnsping PDB1_TRAINING
```

Contoh output:

```text
TNS-03505: Failed to resolve name
```

---

# LAB 11 — Membuat Listener Tambahan di Port 1522

## 11.1 Tambahkan listener baru ke listener.ora

```bash
cat >> $ORACLE_HOME/network/admin/listener.ora <<'EOF'

LISTENER1522 =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = 1522))
    )
  )
EOF
```

## 11.2 Verifikasi file

```bash
grep -A6 "LISTENER1522" $ORACLE_HOME/network/admin/listener.ora
```

Contoh output:

```text
LISTENER1522 =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = 1522))
    )
  )
```

## 11.3 Start listener baru

```bash
lsnrctl start LISTENER1522
```

Contoh output:

```text
Starting /u01/app/oracle/product/19.0.0/dbhome_1/bin/tnslsnr: please wait...
Listening on: (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=localhost)(PORT=1522)))
The command completed successfully
```

## 11.4 Verifikasi listener baru

```bash
lsnrctl status LISTENER1522
```

Contoh output:

```text
Alias                     LISTENER1522
Listening Endpoints Summary...
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=localhost)(PORT=1522)))
The command completed successfully
```

---

# LAB 12 — Register Database ke Listener Tambahan

## 12.1 Set local_listener dengan dua address

```bash
sqlplus / as sysdba
```

```sql
ALTER SYSTEM SET local_listener =
'(ADDRESS_LIST=
  (ADDRESS=(PROTOCOL=TCP)(HOST=localhost)(PORT=1521))
  (ADDRESS=(PROTOCOL=TCP)(HOST=localhost)(PORT=1522))
)'
SCOPE=BOTH;
```

Contoh output:

```text
System altered.
```

## 12.2 Register ulang

```sql
ALTER SYSTEM REGISTER;
```

Contoh output:

```text
System altered.
```

## 12.3 Verifikasi listener 1522 sudah melihat service

```bash
lsnrctl services LISTENER1522
```

Contoh output:

```text
Service "ORADB" has 1 instance(s).
  Instance "ORADB", status READY, has 1 handler(s) for this service...
Service "PDB1" has 1 instance(s).
  Instance "ORADB", status READY, has 1 handler(s) for this service...
```

---

# LAB 13 — Tambahkan TNS Alias untuk Port 1522

## 13.1 Tambahkan alias

```bash
cat >> $ORACLE_HOME/network/admin/tnsnames.ora <<'EOF'

PDB1_1522 =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = 1522))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = PDB1)
    )
  )
EOF
```

## 13.2 Verifikasi alias

```bash
tnsping PDB1_1522
```

Contoh output:

```text
Attempting to contact (DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=localhost)(PORT=1522))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=PDB1)))
OK (0 msec)
```

## 13.3 Test koneksi

```bash
sqlplus netuser/oracle@PDB1_1522
```

Contoh output:

```text
Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0
```

---

# LAB 14 — Membuat Static Listener Registration

Static registration berguna untuk koneksi tertentu, misalnya RMAN duplicate, Data Guard, atau ketika instance belum dynamic register.

## 14.1 Tambahkan SID_LIST ke listener.ora

```bash
cat >> $ORACLE_HOME/network/admin/listener.ora <<'EOF'

SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = ORADB_STATIC)
      (ORACLE_HOME = /u01/app/oracle/product/19.0.0/dbhome_1)
      (SID_NAME = ORADB)
    )
  )
EOF
```

## 14.2 Reload listener

```bash
lsnrctl reload LISTENER
```

Contoh output:

```text
Connecting to (DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=localhost)(PORT=1521)))
The command completed successfully
```

## 14.3 Verifikasi static service

```bash
lsnrctl services LISTENER | grep -A5 ORADB_STATIC
```

Contoh output:

```text
Service "ORADB_STATIC" has 1 instance(s).
  Instance "ORADB", status UNKNOWN, has 1 handler(s) for this service...
```

Catatan: status `UNKNOWN` normal untuk static registration.

---

# LAB 15 — Membuat Alias TNS untuk Static Service

## 15.1 Tambahkan alias

```bash
cat >> $ORACLE_HOME/network/admin/tnsnames.ora <<'EOF'

ORADB_STATIC =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = ORADB_STATIC)
    )
  )
EOF
```

## 15.2 Test alias

```bash
tnsping ORADB_STATIC
```

Contoh output:

```text
OK (10 msec)
```

## 15.3 Test koneksi

```bash
sqlplus sys/oracle@ORADB_STATIC as sysdba
```

Contoh output:

```text
Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0
```

---

# LAB 16 — Membuat sqlnet.ora Dasar

Walaupun fokus lab ini `tnsnames.ora` dan `listener.ora`, `sqlnet.ora` sering dipakai untuk troubleshooting koneksi.

## 16.1 Buat sqlnet.ora

```bash
cat > $ORACLE_HOME/network/admin/sqlnet.ora <<'EOF'
NAMES.DIRECTORY_PATH = (TNSNAMES, EZCONNECT)

SQLNET.AUTHENTICATION_SERVICES = (BEQ, NONE)

DIAG_ADR_ENABLED = ON
EOF
```

## 16.2 Verifikasi

```bash
cat $ORACLE_HOME/network/admin/sqlnet.ora
```

Contoh output:

```text
NAMES.DIRECTORY_PATH = (TNSNAMES, EZCONNECT)

SQLNET.AUTHENTICATION_SERVICES = (BEQ, NONE)

DIAG_ADR_ENABLED = ON
```

## 16.3 Test EZCONNECT tanpa tnsnames.ora

```bash
sqlplus netuser/oracle@localhost:1521/pdb1.localdomain
```

Contoh output:

```text
Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0
```

---

# LAB 17 — Troubleshooting Error: TNS-03505 Alias Tidak Ditemukan

## 17.1 Simulasi alias salah

```bash
tnsping PDB_SALAH
```

Contoh output:

```text
TNS-03505: Failed to resolve name
```

## 17.2 Verifikasi file yang dibaca

```bash
echo $TNS_ADMIN
ls -lh $ORACLE_HOME/network/admin/tnsnames.ora
grep -n "PDB1" $ORACLE_HOME/network/admin/tnsnames.ora
```

Contoh output:

```text
-rw-r--r--. 1 oracle oinstall 1200 Jul 4 11:00 tnsnames.ora
1:PDB1 =
```

Solusi: pastikan alias ada di `tnsnames.ora` dan tidak salah ketik.

---

# LAB 18 — Troubleshooting Error: Listener Tidak Aktif

## 18.1 Stop listener

```bash
lsnrctl stop LISTENER
```

## 18.2 Test koneksi

```bash
tnsping PDB1
sqlplus netuser/oracle@PDB1
```

Contoh error:

```text
TNS-12541: TNS:no listener
```

## 18.3 Start listener kembali

```bash
lsnrctl start LISTENER
```

## 18.4 Register service kembali

```bash
sqlplus / as sysdba
```

```sql
ALTER SYSTEM REGISTER;
```

## 18.5 Test ulang

```bash
sqlplus netuser/oracle@PDB1
```

Contoh output:

```text
Connected.
```

---

# LAB 19 — Troubleshooting Error: Service Tidak Dikenal Listener

## 19.1 Simulasi service name salah

Tambahkan alias salah:

```bash
cat >> $ORACLE_HOME/network/admin/tnsnames.ora <<'EOF'

PDB_SVC_SALAH =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = SERVICE_TIDAK_ADA)
    )
  )
EOF
```

## 19.2 Test koneksi

```bash
sqlplus netuser/oracle@PDB_SVC_SALAH
```

Contoh error:

```text
ORA-12514: TNS:listener does not currently know of service requested in connect descriptor
```

## 19.3 Verifikasi service valid

```bash
lsnrctl services
```

Contoh output:

```text
Service "PDB1" has 1 instance(s).
Service "ORADB" has 1 instance(s).
```

Solusi: gunakan `SERVICE_NAME = PDB1`.

---

# LAB 20 — Cek Port Listener dari OS

## 20.1 Cek port 1521 dan 1522

```bash
ss -tulnp | grep 152
```

Contoh output:

```text
tcp   LISTEN 0 128 127.0.0.1:1521 0.0.0.0:* users:(("tnslsnr",pid=1234,fd=8))
tcp   LISTEN 0 128 127.0.0.1:1522 0.0.0.0:* users:(("tnslsnr",pid=2234,fd=8))
```

Jika `ss` tidak tersedia:

```bash
netstat -tulnp | grep 152
```

---

# LAB 21 — Melihat Listener Log

## 21.1 Cari lokasi listener log

```bash
lsnrctl status | grep "Listener Log File"
```

Contoh output:

```text
Listener Log File         /u01/app/oracle/diag/tnslsnr/oracle19c/listener/alert/log.xml
```

## 21.2 Lihat log terbaru

```bash
tail -50 /u01/app/oracle/diag/tnslsnr/$(hostname)/listener/alert/log.xml
```

Contoh output:

```text
<msg time='2026-07-04T11:30:00.000+07:00'>
 CONNECT_DATA=(SERVICE_NAME=PDB1)
</msg>
```

---

# LAB 22 — Menghapus Listener Tambahan

## 22.1 Stop listener 1522

```bash
lsnrctl stop LISTENER1522
```

Contoh output:

```text
The command completed successfully
```

## 22.2 Backup listener.ora

```bash
cp -p $ORACLE_HOME/network/admin/listener.ora \
$ORACLE_HOME/network/admin/listener.ora.before_remove_1522
```

## 22.3 Hapus blok LISTENER1522 secara manual dengan editor

```bash
vi $ORACLE_HOME/network/admin/listener.ora
```

Hapus bagian berikut:

```text
LISTENER1522 =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = 1522))
    )
  )
```

## 22.4 Reset local_listener ke port utama

```bash
sqlplus / as sysdba
```

```sql
ALTER SYSTEM SET local_listener='(ADDRESS=(PROTOCOL=TCP)(HOST=localhost)(PORT=1521))' SCOPE=BOTH;
ALTER SYSTEM REGISTER;
```

Contoh output:

```text
System altered.
System altered.
```

## 22.5 Verifikasi listener 1522 sudah tidak aktif

```bash
lsnrctl status LISTENER1522
```

Contoh output:

```text
TNS-01101: Could not find listener name or service name LISTENER1522
```

---

# LAB 23 — Menghapus Alias TNS yang Tidak Digunakan

## 23.1 Backup tnsnames.ora

```bash
cp -p $ORACLE_HOME/network/admin/tnsnames.ora \
$ORACLE_HOME/network/admin/tnsnames.ora.before_cleanup
```

## 23.2 Edit file

```bash
vi $ORACLE_HOME/network/admin/tnsnames.ora
```

Hapus blok alias yang tidak diperlukan, misalnya:

```text
PDB1_1522 =
...
```

dan:

```text
PDB_SVC_SALAH =
...
```

## 23.3 Verifikasi alias sudah tidak bisa dipakai

```bash
tnsping PDB1_1522
```

Contoh output:

```text
TNS-03505: Failed to resolve name
```

---

# LAB 24 — Membuat Service Khusus untuk PDB

## 24.1 Buat service dari CDB/PDB

Masuk SQL*Plus:

```bash
sqlplus / as sysdba
```

Masuk ke PDB1:

```sql
ALTER SESSION SET CONTAINER=PDB1;
```

Buat service:

```sql
BEGIN
  DBMS_SERVICE.CREATE_SERVICE(
    service_name => 'svc_training_pdb1',
    network_name => 'svc_training_pdb1'
  );
END;
/
```

Start service:

```sql
BEGIN
  DBMS_SERVICE.START_SERVICE('svc_training_pdb1');
END;
/
```

Contoh output:

```text
PL/SQL procedure successfully completed.
PL/SQL procedure successfully completed.
```

## 24.2 Register ke listener

```sql
ALTER SYSTEM REGISTER;
```

## 24.3 Verifikasi service

```bash
lsnrctl services | grep -A5 svc_training_pdb1
```

Contoh output:

```text
Service "svc_training_pdb1" has 1 instance(s).
  Instance "ORADB", status READY, has 1 handler(s) for this service...
```

## 24.4 Tambahkan alias TNS untuk service baru

```bash
cat >> $ORACLE_HOME/network/admin/tnsnames.ora <<'EOF'

SVC_TRAINING_PDB1 =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = svc_training_pdb1)
    )
  )
EOF
```

## 24.5 Test koneksi

```bash
sqlplus netuser/oracle@SVC_TRAINING_PDB1
```

Contoh output:

```text
Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0
```

---

# LAB 25 — Cleanup Object Lab

## 25.1 Drop service khusus

```bash
sqlplus / as sysdba
```

```sql
ALTER SESSION SET CONTAINER=PDB1;

BEGIN
  DBMS_SERVICE.STOP_SERVICE('svc_training_pdb1');
END;
/

BEGIN
  DBMS_SERVICE.DELETE_SERVICE('svc_training_pdb1');
END;
/
```

Contoh output:

```text
PL/SQL procedure successfully completed.
PL/SQL procedure successfully completed.
```

## 25.2 Drop user testing

```sql
DROP USER netuser CASCADE;
```

Contoh output:

```text
User dropped.
```

## 25.3 Verifikasi user hilang

```sql
SELECT username
FROM dba_users
WHERE username = 'NETUSER';
```

Contoh output:

```text
no rows selected
```

---

# Ringkasan Command Penting

Cek listener:

```bash
lsnrctl status
lsnrctl services
```

Start/stop listener:

```bash
lsnrctl start
lsnrctl stop
lsnrctl reload
```

Test TNS:

```bash
tnsping PDB1
sqlplus user/password@PDB1
```

Register database ke listener:

```sql
ALTER SYSTEM REGISTER;
```

Set local_listener:

```sql
ALTER SYSTEM SET local_listener='(ADDRESS=(PROTOCOL=TCP)(HOST=localhost)(PORT=1521))' SCOPE=BOTH;
```

Contoh `tnsnames.ora`:

```text
PDB1 =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = PDB1)
    )
  )
```

Contoh `listener.ora`:

```text
LISTENER =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = 1521))
    )
  )
```

---

Catatan akhir: di Oracle 19c Multitenant, koneksi aplikasi sebaiknya diarahkan ke **service PDB**, bukan langsung ke CDB root. Untuk aplikasi, gunakan alias seperti `PDB1` atau service khusus seperti `svc_training_pdb1`.
