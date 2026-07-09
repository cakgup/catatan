# Ringkasan Cheat Sheet Oracle Day 3 - Storage and Data Management

> Disusun dari catatan pelatihan **Hari ke-3 / 8 Juli 2026** dan diselaraskan dengan silabus **Hari 3 - Storage and Data Management**.  
> Fokus: Oracle storage architecture, redo log, archive log, tablespace, datafile/tempfile, segment-space management, storage growth, capacity planning, dan ringkasan memory management.

---

## 0. Target Belajar Hari 3

Setelah mempelajari materi ini, Anda diharapkan memahami dan bisa mempraktikkan:

1. Struktur storage Oracle: datafile, control file, redo log file, archive log file.
2. Perbedaan tablespace logical dengan datafile fisik.
3. Pengelolaan redo log group dan redo log member.
4. Pembuatan dan pengelolaan permanent, temporary, dan undo tablespace.
5. Perbedaan smallfile tablespace dan bigfile tablespace.
6. Resize datafile/tablespace dan konfigurasi autoextend.
7. Memindahkan redo log file dan datafile.
8. Monitoring storage utilization dan pertumbuhan storage.
9. Konsep segment, extent, block, serta hubungan dengan tablespace.
10. Ringkasan memory management: SGA, PGA, AMM, dan ASMM.

---

## 1. Peta Konsep Hari 3

```text
Oracle Database Storage
|
+-- Physical Structure
|   +-- Datafile      -> menyimpan data object: table, index, segment
|   +-- Tempfile      -> temporary operation: sort, hash, temporary segment
|   +-- Control file  -> metadata database, checkpoint, lokasi file penting
|   +-- Redo log file -> catatan perubahan untuk recovery
|   +-- Archive log   -> salinan redo log lama pada ARCHIVELOG mode
|
+-- Logical Structure
|   +-- Tablespace
|       +-- Segment
|           +-- Extent
|               +-- Oracle Block
|
+-- Memory Terkait Storage
    +-- Database Buffer Cache -> cache block data
    +-- Redo Log Buffer       -> cache redo entries sebelum ditulis LGWR
    +-- PGA                   -> sort/hash area per server process
```

Intinya:

- **Tablespace** adalah wadah logical.
- **Datafile/tempfile** adalah file fisik di OS/storage.
- **Segment** adalah object yang memakai space, misalnya table dan index.
- **Extent** adalah alokasi kumpulan block untuk segment.
- **Block** adalah unit terkecil penyimpanan Oracle.
- **Redo log** tidak menyimpan data table secara langsung, tetapi menyimpan jejak perubahan agar database bisa recovery.

---

## 2. Persiapan Tampilan SQL\*Plus

### 2.1 Bersihkan layar

```sql
CLEAR SCREEN
```

Fungsi:

Membersihkan layar SQL\*Plus agar output latihan lebih rapi.

---

### 2.2 Mengatur tampilan kolom MEMBER

```sql
COL MEMBER FORMAT A55
```

Fungsi:

Mengatur lebar tampilan kolom `MEMBER`, biasanya dipakai saat melihat file redo log dari `v$logfile`.

Contoh output setelah format lebih rapi:

```text
GROUP# MEMBER
------ -------------------------------------------------------
     1 /u01/app/oracle/oradata/ORADB/redo01.log
     2 /u01/app/oracle/oradata/ORADB/redo02.log
     3 /u01/app/oracle/oradata/ORADB/redo03.log
```

---

## 3. Redo Log File

### 3.1 Konsep redo log

Redo log file bersifat **sequential write**, karena LGWR menulis redo entries secara berurutan. Untuk praktik terbaik, redo log sebaiknya ditempatkan di disk yang berbeda dari datafile agar I/O tidak saling mengganggu.

Struktur redo log:

```text
Redo Log
|
+-- Group 1
|   +-- member redo01.log
|   +-- member redo01b.log  -> multiplexing
|
+-- Group 2
|   +-- member redo02.log
|   +-- member redo02b.log
|
+-- Group 3
    +-- member redo03.log
    +-- member redo03b.log
```

Istilah penting:

| Istilah | Arti |
|---|---|
| Redo log group | Satu kelompok redo log yang dipakai bergantian oleh LGWR. |
| Redo log member | File fisik redo log di dalam group. |
| Multiplexing | Membuat lebih dari satu member pada group yang sama untuk redundancy. |
| CURRENT | Group yang sedang ditulis oleh LGWR. |
| ACTIVE | Group tidak sedang ditulis, tetapi masih diperlukan untuk recovery. |
| INACTIVE | Group tidak sedang ditulis dan tidak lagi diperlukan untuk instance recovery. |
| UNUSED | Group baru dibuat dan belum pernah dipakai. |

---

### 3.2 Melihat daftar redo log file

```sql
SELECT group#, member
FROM v$logfile
ORDER BY group#;
```

Fungsi:

Melihat lokasi fisik redo log member per group.

Contoh output:

```text
GROUP# MEMBER
------ -------------------------------------------------------
     1 /u01/app/oracle/oradata/ORADB/redo01.log
     2 /u01/app/oracle/oradata/ORADB/redo02.log
     3 /u01/app/oracle/oradata/ORADB/redo03.log
```

---

### 3.3 Melihat status redo log group

```sql
SELECT group#, status
FROM v$log;
```

Fungsi:

Melihat group mana yang sedang aktif/current dan group mana yang sudah inactive.

Contoh output:

```text
GROUP# STATUS
------ ----------------
     1 INACTIVE
     2 CURRENT
     3 INACTIVE
     4 UNUSED
```

Cara membaca:

- `CURRENT` tidak boleh langsung dihapus.
- Jika ingin menghapus member/group yang sedang `CURRENT`, lakukan `ALTER SYSTEM SWITCH LOGFILE;` sampai statusnya bergeser.

---

### 3.4 Menambah redo log group baru

```sql
ALTER DATABASE ADD LOGFILE GROUP 4
('/u01/app/oracle/oradata/ORADB/redo04.log') SIZE 200M;
```

Fungsi:

Menambahkan redo log group baru bernomor `4` dengan ukuran 200 MB.

Cek hasilnya:

```sql
SELECT group#, member FROM v$logfile ORDER BY group#;
SELECT group#, status FROM v$log;
```

Contoh output:

```text
GROUP# STATUS
------ ----------------
     1 INACTIVE
     2 CURRENT
     3 INACTIVE
     4 UNUSED
```

---

### 3.5 Menambah redo log member ke beberapa group

```sql
ALTER DATABASE ADD LOGFILE MEMBER
'/u01/app/oracle/oradata/ORADB/redo02b.log' TO GROUP 2,
'/u01/app/oracle/oradata/ORADB/redo03b.log' TO GROUP 3,
'/u01/app/oracle/oradata/ORADB/redo04b.log' TO GROUP 4;
```

Fungsi:

Menambahkan member kedua ke beberapa redo log group. Ini disebut **multiplexing redo log**.

Manfaat:

Jika satu file redo rusak, Oracle masih punya salinan member lain pada group yang sama.

---

### 3.6 Menghapus redo log member

```sql
ALTER DATABASE DROP LOGFILE MEMBER
'/u01/app/oracle/oradata/ORADB/redo04b.log';
```

Fungsi:

Menghapus salah satu redo log member dari konfigurasi database.

Catatan penting:

- Tidak bisa menghapus member dari group yang sedang `CURRENT`.
- Tidak boleh membuat group tersisa tanpa member yang valid.
- File fisik kadang masih ada di OS, sehingga perlu dicek manual.

Cek file fisik:

```sql
!ls -l /u01/app/oracle/oradata/ORADB/ | grep redo
```

---

### 3.7 Menggeser CURRENT redo log group

```sql
ALTER SYSTEM SWITCH LOGFILE;
```

Fungsi:

Memaksa Oracle berpindah dari redo log group yang sedang `CURRENT` ke group berikutnya.

Dipakai saat:

- Latihan melihat perubahan status redo log.
- Ingin menghapus redo log group/member yang sedang `CURRENT`.
- Ingin mempercepat proses archive log pada ARCHIVELOG mode.

---

### 3.8 Menghapus beberapa redo log member sekaligus

```sql
ALTER DATABASE DROP LOGFILE MEMBER
'/u01/app/oracle/oradata/ORADB/redo01b.log',
'/u01/app/oracle/oradata/ORADB/redo02b.log',
'/u01/app/oracle/oradata/ORADB/redo03b.log';
```

Fungsi:

Menghapus beberapa redo log member sekaligus dari konfigurasi database.

---

### 3.9 Menambah kembali redo log member dengan REUSE

```sql
ALTER DATABASE ADD LOGFILE MEMBER
'/u01/app/oracle/oradata/ORADB/redo01b.log' REUSE TO GROUP 1;
```

Fungsi:

Menambahkan kembali redo log member dengan menggunakan file lama yang mungkin masih ada di OS.

Tambah beberapa sekaligus:

```sql
ALTER DATABASE ADD LOGFILE MEMBER
'/u01/app/oracle/oradata/ORADB/redo02b.log' REUSE TO GROUP 2,
'/u01/app/oracle/oradata/ORADB/redo03b.log' REUSE TO GROUP 3,
'/u01/app/oracle/oradata/ORADB/redo04b.log' REUSE TO GROUP 4;
```

Catatan:

`REUSE` berarti Oracle boleh memakai ulang file fisik yang sudah ada.

---

### 3.10 Menghapus redo log group

```sql
ALTER DATABASE DROP LOGFILE GROUP 5;
```

Fungsi:

Menghapus redo log group dari database.

Syarat umum:

- Group tidak sedang `CURRENT`.
- Group tidak diperlukan untuk recovery.
- Database masih memiliki jumlah redo log group minimum yang aman.

---

## 4. Memindahkan Lokasi Redo Log File

Alur aman saat latihan:

```text
1. Shutdown database
2. Copy file redo log ke lokasi baru
3. Startup mount
4. Rename file di controlfile
5. Open database
6. Verifikasi v$logfile
```

### 4.1 Shutdown database

```sql
SHUTDOWN IMMEDIATE;
```

Fungsi:

Mematikan database dengan aman sebelum memindahkan file.

---

### 4.2 Siapkan folder baru dan copy redo log

```sql
!mkdir /u01/app/oracle/oradata/ORADB/BARU
!cp /u01/app/oracle/oradata/ORADB/redo04.log /u01/app/oracle/oradata/ORADB/BARU/redo04.log
```

Fungsi:

Membuat lokasi baru dan menyalin file redo log ke lokasi tersebut.

---

### 4.3 Startup sampai MOUNT

```sql
STARTUP MOUNT;
```

Fungsi:

Menyalakan instance dan mount database, tetapi database belum dibuka penuh. Pada tahap ini file dapat di-rename di controlfile.

---

### 4.4 Rename redo log file di controlfile

```sql
ALTER DATABASE RENAME FILE
'/u01/app/oracle/oradata/ORADB/redo04.log'
TO
'/u01/app/oracle/oradata/ORADB/BARU/redo04.log';
```

Fungsi:

Mengubah metadata lokasi file redo log di controlfile.

---

### 4.5 Open database dan verifikasi

```sql
ALTER DATABASE OPEN;
SELECT group#, member FROM v$logfile ORDER BY group#;
```

Fungsi:

Membuka database kembali dan memastikan redo log sudah terbaca dari lokasi baru.

---

## 5. Masuk ke PDB untuk Praktik Tablespace

Pada Oracle Multitenant, tablespace aplikasi biasanya dibuat di PDB.

```sql
ALTER SESSION SET CONTAINER=pdb1;
SHOW CON_NAME;
```

Fungsi:

Memastikan session aktif berada di PDB1, bukan CDB$ROOT.

Contoh output:

```text
CON_NAME
------------------------------
PDB1
```

---

## 6. Melihat Tablespace dan Datafile

### 6.1 Melihat daftar tablespace

```sql
SELECT name FROM v$tablespace;
```

Atau:

```sql
SELECT tablespace_name FROM dba_tablespaces;
```

Fungsi:

Melihat daftar tablespace yang ada di PDB.

---

### 6.2 Melihat lokasi datafile

```sql
COL tablespace_name FORMAT A15
COL file_name FORMAT A70

SELECT tablespace_name, file_name
FROM dba_data_files
ORDER BY tablespace_name, file_name;
```

Fungsi:

Melihat hubungan antara tablespace dan file fisiknya.

Contoh output:

```text
TABLESPACE_NAME  FILE_NAME
---------------  --------------------------------------------------------------
SYSAUX           /u01/app/oracle/oradata/ORADB/pdb1/sysaux01.dbf
SYSTEM           /u01/app/oracle/oradata/ORADB/pdb1/system01.dbf
TS_BARU          /u01/app/oracle/oradata/ORADB/pdb1/ts_baru01.dbf
USERS            /u01/app/oracle/oradata/ORADB/pdb1/users01.dbf
```

---

### 6.3 Melihat tempfile

```sql
SELECT tablespace_name, file_name
FROM dba_temp_files;
```

Fungsi:

Melihat file fisik untuk temporary tablespace.

---

## 7. Jenis Tablespace Berdasarkan Isi

```sql
SELECT tablespace_name, contents
FROM dba_tablespaces
ORDER BY tablespace_name;
```

Fungsi:

Mengetahui apakah tablespace berisi data permanen, temporary, atau undo.

Contoh output:

```text
TABLESPACE_NAME  CONTENTS
---------------  ---------
SYSTEM           PERMANENT
SYSAUX           PERMANENT
TEMP             TEMPORARY
UNDOTBS1         UNDO
USERS            PERMANENT
```

Makna:

| CONTENTS | Fungsi |
|---|---|
| PERMANENT | Menyimpan object permanen seperti table dan index. |
| TEMPORARY | Menampung operasi sementara seperti sort, hash, dan temporary segment. |
| UNDO | Menyimpan undo record untuk rollback, read consistency, dan flashback tertentu. |

---

## 8. Smallfile vs Bigfile Tablespace

```sql
SELECT tablespace_name, bigfile
FROM dba_tablespaces
ORDER BY tablespace_name;
```

Fungsi:

Mengetahui apakah tablespace bertipe smallfile atau bigfile.

Contoh output:

```text
TABLESPACE_NAME  BIGFILE
---------------  -------
SYSTEM           NO
SYSAUX           NO
TS_BARU          NO
TS_GEDE          YES
```

Perbedaan utama:

| Jenis | Karakteristik | Analogi |
|---|---|---|
| Smallfile | Satu tablespace bisa punya banyak datafile. | Seperti PVM: banyak file bisa ditambahkan. |
| Bigfile | Satu tablespace hanya punya satu datafile besar. | Seperti LVM: satu wadah besar dikelola sebagai satu unit. |

---

## 9. Membuat Tablespace Baru

### 9.1 Membuat smallfile tablespace

```sql
CREATE TABLESPACE ts_baru
DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/ts_baru01.dbf' SIZE 100M;
```

Fungsi:

Membuat permanent tablespace smallfile bernama `TS_BARU` dengan satu datafile ukuran 100 MB.

---

### 9.2 Membuat bigfile tablespace

```sql
CREATE BIGFILE TABLESPACE ts_gede
DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/ts_gede.dbf' SIZE 100M;
```

Fungsi:

Membuat permanent bigfile tablespace bernama `TS_GEDE` dengan satu datafile ukuran 100 MB.

---

### 9.3 Cek hasil pembuatan tablespace

```sql
SELECT tablespace_name, contents, bigfile
FROM dba_tablespaces
ORDER BY tablespace_name;
```

Fungsi:

Memastikan tablespace baru sudah dibuat dan mengetahui tipenya.

---

## 10. Menambah Datafile

### 10.1 Menambah datafile ke smallfile tablespace - berhasil

```sql
ALTER TABLESPACE ts_baru
ADD DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/ts_baru02.dbf' SIZE 100M;
```

Fungsi:

Menambahkan datafile kedua ke smallfile tablespace.

---

### 10.2 Menambah datafile ke bigfile tablespace - gagal

```sql
ALTER TABLESPACE ts_gede
ADD DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/ts_gede02.dbf' SIZE 100M;
```

Fungsi latihan:

Membuktikan bahwa bigfile tablespace tidak bisa ditambah datafile kedua.

Contoh error yang mungkin muncul:

```text
ORA-32771: cannot add file to bigfile tablespace
```

Kesimpulan:

- Smallfile tablespace bisa memiliki banyak datafile.
- Bigfile tablespace hanya punya satu datafile.

---

## 11. Membuat Smallfile Tablespace dengan Multiple Datafile

```sql
CREATE TABLESPACE ts_kecil
DATAFILE
'/u01/app/oracle/oradata/ORADB/pdb1/ts_kecil01.dbf' SIZE 10M,
'/u01/app/oracle/oradata/ORADB/pdb1/ts_kecil02.dbf' SIZE 10M;
```

Fungsi:

Membuat smallfile tablespace langsung dengan dua datafile.

Cek:

```sql
SELECT tablespace_name, file_name
FROM dba_data_files
WHERE tablespace_name = 'TS_KECIL'
ORDER BY file_name;
```

---

## 12. Resize Tablespace/Datafile

### 12.1 Resize datafile smallfile

```sql
ALTER DATABASE DATAFILE
'/u01/app/oracle/oradata/ORADB/pdb1/ts_kecil01.dbf'
RESIZE 20M;
```

Fungsi:

Mengubah ukuran datafile tertentu menjadi 20 MB.

---

### 12.2 Resize bigfile tablespace

```sql
ALTER TABLESPACE ts_gede RESIZE 110M;
```

Fungsi:

Mengubah ukuran bigfile tablespace menjadi 110 MB.

Catatan:

Pada bigfile tablespace, pengelolaan ukuran bisa dilakukan pada level tablespace karena hanya ada satu datafile.

---

### 12.3 Cek ukuran datafile

```sql
SELECT tablespace_name,
       file_name,
       ROUND(bytes/(1024*1024)) AS mb
FROM dba_data_files
ORDER BY tablespace_name, file_name;
```

Contoh output:

```text
TABLESPACE_NAME  FILE_NAME                                               MB
---------------  ------------------------------------------------------ ---
TS_GEDE          /u01/app/oracle/oradata/ORADB/pdb1/ts_gede.dbf          110
TS_KECIL         /u01/app/oracle/oradata/ORADB/pdb1/ts_kecil01.dbf        20
TS_KECIL         /u01/app/oracle/oradata/ORADB/pdb1/ts_kecil02.dbf        10
```

---

## 13. Autoextend Datafile/Tablespace

### 13.1 Autoextend pada datafile smallfile

```sql
ALTER DATABASE DATAFILE
'/u01/app/oracle/oradata/ORADB/pdb1/ts_kecil01.dbf'
AUTOEXTEND ON NEXT 10M MAXSIZE 1G;
```

Fungsi:

Mengatur datafile agar bertambah otomatis 10 MB setiap kali hampir penuh, dengan batas maksimum 1 GB.

---

### 13.2 Autoextend pada bigfile tablespace

```sql
ALTER TABLESPACE ts_gede
AUTOEXTEND ON NEXT 10M MAXSIZE 20T;
```

Fungsi:

Mengatur bigfile tablespace agar bertambah otomatis 10 MB, dengan batas maksimum 20 TB.

Catatan penting:

Selalu gunakan `MAXSIZE` agar datafile tidak tumbuh tanpa kontrol dan memenuhi disk.

---

### 13.3 Cek status autoextend

```sql
SELECT tablespace_name, file_name, autoextensible
FROM dba_data_files
ORDER BY tablespace_name, file_name;
```

Cek increment:

```sql
SELECT tablespace_name,
       file_name,
       autoextensible,
       increment_by
FROM dba_data_files
ORDER BY tablespace_name, file_name;
```

Catatan:

`INCREMENT_BY` menggunakan satuan block, bukan langsung MB. Untuk konversi akurat, kalikan dengan ukuran block database.

---

## 14. Membuat Tablespace Multiple Datafile Langsung Autoextend

```sql
CREATE TABLESPACE ts_kecil_lagi
DATAFILE
'/u01/app/oracle/oradata/ORADB/pdb1/ts_kecil_lagi01.dbf' SIZE 10M AUTOEXTEND ON NEXT 10M MAXSIZE 100M,
'/u01/app/oracle/oradata/ORADB/pdb1/ts_kecil_lagi02.dbf' SIZE 10M AUTOEXTEND ON NEXT 10M MAXSIZE 100M;
```

Fungsi:

Membuat smallfile tablespace dengan dua datafile, dan masing-masing datafile langsung diberi autoextend.

---

## 15. Menghapus Tablespace

### 15.1 Drop tablespace tanpa menghapus datafile

```sql
DROP TABLESPACE ts_kecil;
```

Fungsi:

Menghapus metadata tablespace dari database, tetapi file fisik datafile bisa masih ada di OS.

Cek file:

```sql
!ls -l /u01/app/oracle/oradata/ORADB/pdb1/ts_kecil01.dbf
```

---

### 15.2 Drop tablespace sekaligus hapus datafile

```sql
DROP TABLESPACE ts_kecil INCLUDING CONTENTS AND DATAFILES;
```

Fungsi:

Menghapus tablespace, seluruh object di dalamnya, dan datafile fisiknya.

Catatan:

Gunakan command ini dengan hati-hati karena data akan hilang.

---

## 16. Menggunakan REUSE pada Datafile Lama

### 16.1 Membuat tablespace dengan file lama

```sql
CREATE TABLESPACE ts_kecil
DATAFILE
'/u01/app/oracle/oradata/ORADB/pdb1/ts_kecil01.dbf' SIZE 10M REUSE;
```

Fungsi:

Membuat tablespace menggunakan ulang file fisik yang sudah ada.

---

### 16.2 Menambah datafile lama ke tablespace

```sql
ALTER TABLESPACE ts_kecil
ADD DATAFILE
'/u01/app/oracle/oradata/ORADB/pdb1/ts_kecil02.dbf' SIZE 10M REUSE;
```

Fungsi:

Menambahkan file fisik lama sebagai datafile baru pada tablespace.

Catatan:

`REUSE` boleh dipakai hanya jika Anda yakin file tersebut memang boleh ditimpa/dipakai ulang.

---

## 17. Status Tablespace: ONLINE, OFFLINE, READ ONLY, READ WRITE

### 17.1 Cek status tablespace

```sql
SELECT tablespace_name, status
FROM dba_tablespaces
ORDER BY tablespace_name;
```

Contoh output:

```text
TABLESPACE_NAME  STATUS
---------------  ---------
SYSTEM           ONLINE
SYSAUX           ONLINE
TS_GEDE          READ ONLY
TS_KECIL         ONLINE
```

Makna status:

| Status | Arti |
|---|---|
| ONLINE | Tablespace bisa dipakai read/write. |
| OFFLINE | Tablespace tidak bisa digunakan. Object di dalamnya tidak bisa diakses. |
| READ ONLY | Object bisa dibaca, tetapi tidak bisa diubah. |
| READ WRITE | Mengembalikan tablespace read only menjadi read/write. |

---

### 17.2 Demo status tablespace

Buat table di tablespace tertentu:

```sql
CREATE TABLE test(x INT) TABLESPACE ts_gede;
INSERT INTO test VALUES(1);
COMMIT;
SELECT * FROM test;
```

Contoh output:

```text
         X
----------
         1
```

Jadikan offline:

```sql
ALTER TABLESPACE ts_gede OFFLINE;
```

Efek:

Query ke object di tablespace tersebut akan gagal.

Kembalikan online:

```sql
ALTER TABLESPACE ts_gede ONLINE;
```

Jadikan read only:

```sql
ALTER TABLESPACE ts_gede READ ONLY;
```

Kembalikan read write:

```sql
ALTER TABLESPACE ts_gede READ WRITE;
```

---

## 18. Memindahkan Datafile Tablespace

Alur aman saat latihan:

```text
1. Cek lokasi datafile
2. Offline-kan tablespace
3. Copy datafile ke lokasi baru
4. Rename file di controlfile
5. Online-kan tablespace
6. Verifikasi
```

### 18.1 Cek lokasi datafile

```sql
SELECT file_name, status
FROM dba_data_files
WHERE tablespace_name='TS_GEDE';
```

---

### 18.2 Offline tablespace

```sql
ALTER TABLESPACE ts_gede OFFLINE;
```

Fungsi:

Melepas tablespace dari akses aktif agar file fisik bisa dipindahkan.

---

### 18.3 Copy datafile ke lokasi baru

```sql
!cp /u01/app/oracle/oradata/ORADB/pdb1/ts_gede.dbf /u01/app/oracle/oradata/ORADB/BARU
```

Fungsi:

Menyalin datafile ke lokasi baru.

---

### 18.4 Rename file di controlfile

```sql
ALTER DATABASE RENAME FILE
'/u01/app/oracle/oradata/ORADB/pdb1/ts_gede.dbf'
TO
'/u01/app/oracle/oradata/ORADB/BARU/ts_gede.dbf';
```

Fungsi:

Mengubah metadata lokasi datafile di controlfile.

---

### 18.5 Online-kan tablespace

```sql
ALTER TABLESPACE ts_gede ONLINE;
```

Fungsi:

Membuka kembali tablespace agar object di dalamnya bisa digunakan.

---

### 18.6 Mengembalikan datafile ke lokasi lama

```sql
ALTER TABLESPACE ts_gede OFFLINE;

ALTER DATABASE RENAME FILE
'/u01/app/oracle/oradata/ORADB/BARU/ts_gede.dbf'
TO
'/u01/app/oracle/oradata/ORADB/pdb1/ts_gede.dbf';

RECOVER TABLESPACE ts_gede;
ALTER TABLESPACE ts_gede ONLINE;
```

Fungsi:

Mengembalikan lokasi datafile ke path awal. `RECOVER TABLESPACE` digunakan jika Oracle membutuhkan recovery sebelum tablespace bisa online kembali.

---

## 19. Membuat dan Mengganti Undo Tablespace

### 19.1 Membuat undo tablespace

```sql
CREATE UNDO TABLESPACE undo_gw
DATAFILE
'/u01/app/oracle/oradata/ORADB/pdb1/undo_gw01.dbf' SIZE 100M
AUTOEXTEND ON NEXT 30M MAXSIZE 1G;
```

Fungsi:

Membuat undo tablespace baru dengan autoextend, tetapi tetap diberi batas maksimum 1 GB.

---

### 19.2 Cek undo tablespace aktif

```sql
SHOW PARAMETER undo_tablespace;
```

Contoh output:

```text
NAME             TYPE   VALUE
---------------- ------ --------
undo_tablespace  string UNDOTBS1
```

---

### 19.3 Mengubah undo tablespace aktif

```sql
ALTER SYSTEM SET undo_tablespace=undo_gw;
```

Fungsi:

Mengalihkan penggunaan undo tablespace aktif ke `UNDO_GW`.

Cek kembali:

```sql
SHOW PARAMETER undo_tablespace;
```

---

## 20. Monitoring Storage Utilization

Bagian ini melengkapi catatan agar sesuai dengan silabus monitoring dan capacity planning.

### 20.1 Total ukuran datafile per tablespace

```sql
SELECT tablespace_name,
       ROUND(SUM(bytes)/1024/1024) AS total_mb
FROM dba_data_files
GROUP BY tablespace_name
ORDER BY tablespace_name;
```

Fungsi:

Melihat total alokasi datafile per tablespace.

---

### 20.2 Free space per tablespace

```sql
SELECT tablespace_name,
       ROUND(SUM(bytes)/1024/1024) AS free_mb
FROM dba_free_space
GROUP BY tablespace_name
ORDER BY tablespace_name;
```

Fungsi:

Melihat sisa ruang kosong dalam tablespace permanent.

---

### 20.3 Laporan penggunaan tablespace

```sql
SELECT df.tablespace_name,
       ROUND(df.total_mb) AS total_mb,
       ROUND(fs.free_mb) AS free_mb,
       ROUND(df.total_mb - NVL(fs.free_mb,0)) AS used_mb,
       ROUND(((df.total_mb - NVL(fs.free_mb,0)) / df.total_mb) * 100, 2) AS used_pct
FROM (
    SELECT tablespace_name, SUM(bytes)/1024/1024 AS total_mb
    FROM dba_data_files
    GROUP BY tablespace_name
) df
LEFT JOIN (
    SELECT tablespace_name, SUM(bytes)/1024/1024 AS free_mb
    FROM dba_free_space
    GROUP BY tablespace_name
) fs
ON df.tablespace_name = fs.tablespace_name
ORDER BY used_pct DESC;
```

Fungsi:

Membuat ringkasan total, free, used, dan persentase penggunaan tablespace.

Contoh output:

```text
TABLESPACE_NAME  TOTAL_MB  FREE_MB  USED_MB  USED_PCT
---------------  --------  -------  -------  --------
SYSTEM               900       120      780     86.67
SYSAUX               700       210      490     70.00
TS_GEDE              110        80       30     27.27
USERS                100        95        5      5.00
```

---

### 20.4 Cek autoextend dan max size

```sql
SELECT tablespace_name,
       file_name,
       autoextensible,
       ROUND(bytes/1024/1024) AS current_mb,
       ROUND(maxbytes/1024/1024) AS max_mb
FROM dba_data_files
ORDER BY tablespace_name, file_name;
```

Fungsi:

Melihat apakah datafile bisa bertambah otomatis dan batas maksimum pertumbuhannya.

---

## 21. Segment, Extent, dan Block

### 21.1 Melihat segment milik user aktif

```sql
SELECT segment_name,
       segment_type,
       tablespace_name,
       ROUND(bytes/1024/1024, 2) AS mb
FROM user_segments
ORDER BY bytes DESC;
```

Fungsi:

Melihat object apa saja yang memakai space pada schema aktif.

Contoh output:

```text
SEGMENT_NAME  SEGMENT_TYPE  TABLESPACE_NAME     MB
------------  ------------  ---------------  -----
TEST          TABLE         TS_GEDE           0.06
```

---

### 21.2 Melihat segment dalam tablespace tertentu

```sql
SELECT owner,
       segment_name,
       segment_type,
       extents,
       blocks,
       ROUND(bytes/1024/1024, 2) AS mb
FROM dba_segments
WHERE tablespace_name = 'TS_GEDE'
ORDER BY bytes DESC;
```

Fungsi:

Melihat object yang menempati tablespace tertentu.

---

### 21.3 Konsep cepat

```text
Tablespace
  -> Datafile
      -> Segment: table, index, undo segment, temporary segment
          -> Extent: alokasi ruang bertahap untuk segment
              -> Block: unit terkecil penyimpanan Oracle
```

---

## 22. Ringkasan Memory Management Sesuai Silabus Day 3

Walaupun catatan praktik hari ini lebih banyak tentang redo log dan tablespace, silabus Day 3 juga memuat memory management: SGA, PGA, AMM, dan ASMM.

### 22.1 Cek parameter memory utama

```sql
SHOW PARAMETER memory_target;
SHOW PARAMETER memory_max_target;
SHOW PARAMETER sga_target;
SHOW PARAMETER pga_aggregate_target;
```

Fungsi:

Melihat konfigurasi memory Oracle.

Makna ringkas:

| Parameter | Fungsi |
|---|---|
| memory_target | Total memory target jika AMM digunakan. |
| memory_max_target | Batas maksimum memory untuk AMM. |
| sga_target | Target SGA jika ASMM digunakan. |
| pga_aggregate_target | Target total PGA untuk server process. |

---

### 22.2 Melihat komponen SGA dinamis

```sql
SELECT component,
       current_size/1024/1024 AS current_mb,
       min_size/1024/1024 AS min_mb,
       max_size/1024/1024 AS max_mb
FROM v$sga_dynamic_components
ORDER BY component;
```

Fungsi:

Melihat alokasi memory SGA seperti shared pool, buffer cache, large pool, dan java pool.

---

### 22.3 Melihat statistik PGA

```sql
SELECT name, value
FROM v$pgastat
ORDER BY name;
```

Fungsi:

Melihat statistik penggunaan PGA, seperti total PGA allocated dan maximum PGA allocated.

---

## 23. Alur Latihan Hari 3 yang Disarankan

Gunakan alur ini saat mengulang materi dari awal.

### A. Login dan masuk PDB

```sql
sqlplus / as sysdba
ALTER SESSION SET CONTAINER=pdb1;
SHOW CON_NAME;
```

### B. Cek redo log

```sql
COL MEMBER FORMAT A55
SELECT group#, member FROM v$logfile ORDER BY group#;
SELECT group#, status FROM v$log;
```

### C. Tambah redo log group/member

```sql
ALTER DATABASE ADD LOGFILE GROUP 4
('/u01/app/oracle/oradata/ORADB/redo04.log') SIZE 200M;

ALTER DATABASE ADD LOGFILE MEMBER
'/u01/app/oracle/oradata/ORADB/redo02b.log' TO GROUP 2,
'/u01/app/oracle/oradata/ORADB/redo03b.log' TO GROUP 3,
'/u01/app/oracle/oradata/ORADB/redo04b.log' TO GROUP 4;
```

### D. Cek tablespace dan datafile

```sql
SELECT tablespace_name, contents, bigfile, status
FROM dba_tablespaces
ORDER BY tablespace_name;

SELECT tablespace_name, file_name
FROM dba_data_files
ORDER BY tablespace_name, file_name;
```

### E. Buat tablespace smallfile dan bigfile

```sql
CREATE TABLESPACE ts_baru
DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/ts_baru01.dbf' SIZE 100M;

CREATE BIGFILE TABLESPACE ts_gede
DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/ts_gede.dbf' SIZE 100M;
```

### F. Tambah datafile smallfile dan uji bigfile

```sql
ALTER TABLESPACE ts_baru
ADD DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/ts_baru02.dbf' SIZE 100M;

ALTER TABLESPACE ts_gede
ADD DATAFILE '/u01/app/oracle/oradata/ORADB/pdb1/ts_gede02.dbf' SIZE 100M;
```

Catatan: command kedua seharusnya gagal karena `TS_GEDE` adalah bigfile tablespace.

### G. Resize dan autoextend

```sql
ALTER DATABASE DATAFILE
'/u01/app/oracle/oradata/ORADB/pdb1/ts_baru01.dbf'
RESIZE 150M;

ALTER DATABASE DATAFILE
'/u01/app/oracle/oradata/ORADB/pdb1/ts_baru01.dbf'
AUTOEXTEND ON NEXT 10M MAXSIZE 1G;
```

### H. Demo status tablespace

```sql
CREATE TABLE test(x INT) TABLESPACE ts_gede;
INSERT INTO test VALUES(1);
COMMIT;
SELECT * FROM test;

ALTER TABLESPACE ts_gede OFFLINE;
ALTER TABLESPACE ts_gede ONLINE;
ALTER TABLESPACE ts_gede READ ONLY;
ALTER TABLESPACE ts_gede READ WRITE;
```

### I. Cek capacity

```sql
SELECT df.tablespace_name,
       ROUND(df.total_mb) AS total_mb,
       ROUND(fs.free_mb) AS free_mb,
       ROUND(df.total_mb - NVL(fs.free_mb,0)) AS used_mb,
       ROUND(((df.total_mb - NVL(fs.free_mb,0)) / df.total_mb) * 100, 2) AS used_pct
FROM (
    SELECT tablespace_name, SUM(bytes)/1024/1024 AS total_mb
    FROM dba_data_files
    GROUP BY tablespace_name
) df
LEFT JOIN (
    SELECT tablespace_name, SUM(bytes)/1024/1024 AS free_mb
    FROM dba_free_space
    GROUP BY tablespace_name
) fs
ON df.tablespace_name = fs.tablespace_name
ORDER BY used_pct DESC;
```

### J. Cek memory

```sql
SHOW PARAMETER sga_target;
SHOW PARAMETER pga_aggregate_target;
SELECT component, current_size/1024/1024 AS current_mb
FROM v$sga_dynamic_components;
```

---

## 24. Kesalahan Umum dan Cara Memahami

| Masalah | Penyebab Umum | Solusi |
|---|---|---|
| Tidak bisa drop redo log member | Group/member sedang `CURRENT`. | Jalankan `ALTER SYSTEM SWITCH LOGFILE;`, lalu cek `v$log`. |
| File redo/datafile masih ada setelah drop | Drop metadata belum tentu menghapus file OS. | Cek dengan `!ls`, hapus manual hanya jika yakin. |
| Tidak bisa tambah datafile ke bigfile | Bigfile hanya boleh punya satu datafile. | Resize bigfile atau aktifkan autoextend. |
| Resize gagal | Ukuran baru lebih kecil dari data yang sudah terpakai. | Cek penggunaan space; resize ke ukuran lebih besar. |
| Tablespace offline tidak bisa di-query | Status tablespace memang tidak tersedia. | `ALTER TABLESPACE ... ONLINE;` |
| Read only tidak bisa insert/update | Tablespace hanya boleh dibaca. | `ALTER TABLESPACE ... READ WRITE;` |
| Disk penuh karena autoextend | Tidak ada `MAXSIZE` atau maxsize terlalu besar. | Selalu set `MAXSIZE`, pantau `dba_data_files`. |

---

## 25. Command Paling Penting untuk Dihafal

```sql
-- Redo log
SELECT group#, member FROM v$logfile ORDER BY group#;
SELECT group#, status FROM v$log;
ALTER DATABASE ADD LOGFILE GROUP 4 ('/path/redo04.log') SIZE 200M;
ALTER DATABASE ADD LOGFILE MEMBER '/path/redo02b.log' TO GROUP 2;
ALTER DATABASE DROP LOGFILE MEMBER '/path/redo02b.log';
ALTER SYSTEM SWITCH LOGFILE;
ALTER DATABASE RENAME FILE '/path/lama.log' TO '/path/baru.log';

-- Tablespace dan datafile
ALTER SESSION SET CONTAINER=pdb1;
SELECT tablespace_name, contents, bigfile, status FROM dba_tablespaces;
SELECT tablespace_name, file_name FROM dba_data_files;
SELECT tablespace_name, file_name FROM dba_temp_files;
CREATE TABLESPACE ts_baru DATAFILE '/path/ts_baru01.dbf' SIZE 100M;
CREATE BIGFILE TABLESPACE ts_gede DATAFILE '/path/ts_gede.dbf' SIZE 100M;
ALTER TABLESPACE ts_baru ADD DATAFILE '/path/ts_baru02.dbf' SIZE 100M;
ALTER DATABASE DATAFILE '/path/file.dbf' RESIZE 200M;
ALTER DATABASE DATAFILE '/path/file.dbf' AUTOEXTEND ON NEXT 10M MAXSIZE 1G;
DROP TABLESPACE ts_baru INCLUDING CONTENTS AND DATAFILES;
ALTER TABLESPACE ts_gede OFFLINE;
ALTER TABLESPACE ts_gede ONLINE;
ALTER TABLESPACE ts_gede READ ONLY;
ALTER TABLESPACE ts_gede READ WRITE;

-- Undo
CREATE UNDO TABLESPACE undo_gw DATAFILE '/path/undo_gw01.dbf' SIZE 100M AUTOEXTEND ON NEXT 30M MAXSIZE 1G;
SHOW PARAMETER undo_tablespace;
ALTER SYSTEM SET undo_tablespace=undo_gw;

-- Segment/space/memory
SELECT segment_name, segment_type, tablespace_name, bytes/1024/1024 AS mb FROM user_segments;
SHOW PARAMETER sga_target;
SHOW PARAMETER pga_aggregate_target;
```

---

## 26. Checklist Belajar Mandiri

```text
[ ] Saya paham fungsi datafile, tempfile, control file, redo log, dan archive log.
[ ] Saya bisa menjelaskan redo log group dan redo log member.
[ ] Saya bisa mengecek status redo log dengan v$log.
[ ] Saya tahu bahwa redo log CURRENT tidak bisa dihapus langsung.
[ ] Saya bisa menambah redo log group.
[ ] Saya bisa menambah dan menghapus redo log member.
[ ] Saya bisa memindahkan lokasi redo log file dengan RENAME FILE.
[ ] Saya bisa masuk ke PDB sebelum membuat tablespace aplikasi.
[ ] Saya bisa melihat daftar tablespace dan datafile.
[ ] Saya paham PERMANENT, TEMPORARY, dan UNDO tablespace.
[ ] Saya paham smallfile vs bigfile tablespace.
[ ] Saya bisa membuat smallfile dan bigfile tablespace.
[ ] Saya bisa resize datafile dan bigfile tablespace.
[ ] Saya bisa mengaktifkan autoextend dengan MAXSIZE.
[ ] Saya paham efek DROP TABLESPACE tanpa INCLUDING DATAFILES.
[ ] Saya bisa memakai REUSE dengan hati-hati.
[ ] Saya bisa mengubah status tablespace menjadi OFFLINE, ONLINE, READ ONLY, READ WRITE.
[ ] Saya bisa memindahkan datafile ke lokasi baru.
[ ] Saya bisa membuat dan mengaktifkan undo tablespace.
[ ] Saya bisa melihat pemakaian tablespace dan segment.
[ ] Saya bisa mengecek parameter memory dasar SGA/PGA.
```

---

## 27. Mini Latihan Ujian Lisan

1. Apa perbedaan tablespace dan datafile?
2. Apa perbedaan redo log group dan redo log member?
3. Mengapa redo log sebaiknya ditempatkan di disk berbeda dari datafile?
4. Apa arti status `CURRENT`, `ACTIVE`, `INACTIVE`, dan `UNUSED` pada redo log?
5. Mengapa redo log member yang sedang `CURRENT` tidak bisa dihapus?
6. Apa fungsi `ALTER SYSTEM SWITCH LOGFILE`?
7. Apa beda smallfile tablespace dan bigfile tablespace?
8. Mengapa bigfile tablespace tidak bisa ditambah datafile kedua?
9. Apa risiko autoextend tanpa `MAXSIZE`?
10. Apa beda `DROP TABLESPACE ts_kecil;` dan `DROP TABLESPACE ts_kecil INCLUDING CONTENTS AND DATAFILES;`?
11. Apa beda status tablespace `OFFLINE` dan `READ ONLY`?
12. Mengapa perlu `ALTER TABLESPACE ... OFFLINE` saat memindahkan datafile?
13. Apa fungsi undo tablespace?
14. Apa hubungan segment, extent, dan block?
15. Parameter apa yang dilihat untuk mengecek SGA dan PGA?

---

## 28. Jawaban Singkat Mini Latihan

1. Tablespace adalah wadah logical, sedangkan datafile adalah file fisik tempat data disimpan.
2. Group adalah kelompok redo yang dipakai bergantian oleh LGWR; member adalah file fisik dalam group tersebut.
3. Untuk mengurangi kontensi I/O dan meningkatkan availability.
4. `CURRENT` sedang ditulis, `ACTIVE` masih diperlukan recovery, `INACTIVE` tidak diperlukan untuk instance recovery, `UNUSED` belum pernah dipakai.
5. Karena masih dipakai LGWR untuk mencatat perubahan.
6. Memaksa perpindahan penulisan redo ke group berikutnya.
7. Smallfile bisa punya banyak datafile; bigfile hanya punya satu datafile besar.
8. Karena desain bigfile adalah satu tablespace satu datafile.
9. Datafile bisa terus membesar sampai disk penuh.
10. Yang pertama menghapus metadata tablespace; yang kedua juga menghapus isi dan file fisik datafile.
11. `OFFLINE` tidak bisa digunakan; `READ ONLY` masih bisa dibaca tetapi tidak bisa ditulis.
12. Agar file tidak sedang aktif digunakan saat dipindahkan.
13. Menyimpan informasi untuk rollback, read consistency, dan recovery transaksi.
14. Segment terdiri dari extent; extent terdiri dari block.
15. `sga_target`, `pga_aggregate_target`, `memory_target`, dan view seperti `v$sga_dynamic_components` serta `v$pgastat`.

---

## 29. Catatan Keamanan Praktik

Command berikut berisiko jika dijalankan di production:

```sql
ALTER DATABASE DROP LOGFILE MEMBER ...;
ALTER DATABASE DROP LOGFILE GROUP ...;
DROP TABLESPACE ... INCLUDING CONTENTS AND DATAFILES;
ALTER DATABASE RENAME FILE ...;
ALTER SYSTEM SET undo_tablespace=...;
```

Praktik terbaik:

- Jalankan hanya di environment lab/VM.
- Backup konfigurasi dan file penting sebelum perubahan.
- Pastikan status redo log bukan `CURRENT` sebelum drop.
- Gunakan `MAXSIZE` saat mengaktifkan autoextend.
- Cek `dba_data_files`, `dba_free_space`, dan kapasitas disk OS sebelum resize/autoextend.

---

Selesai.
