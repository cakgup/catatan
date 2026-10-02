# Matriks Pemahaman CVSS v4.0 — Base Metrics

> **Tujuan:** Memahami CVSS v4.0 Base Metrics dengan cara sederhana dan praktis, khususnya untuk kebutuhan penetration testing dan vulnerability assessment.

---

## 1. Gambaran Besar

CVSS v4.0 Base Metrics dapat dipahami sebagai **11 pertanyaan utama**:

- **5 pertanyaan tentang cara menyerang:** `AV`, `AC`, `AT`, `PR`, `UI`
- **6 pertanyaan tentang dampak:** `VC`, `VI`, `VA`, `SC`, `SI`, `SA`

Secara sederhana:

```text
                    CVSS v4.0 BASE
                           |
              +------------+------------+
              |                         |
       EXPLOITABILITY                 IMPACT
     "Bagaimana menyerang?"     "Apa yang terdampak?"
              |                         |
       AV AC AT PR UI         VC VI VA SC SI SA
```

### Cara mengingat

```text
AV = Dari mana attacker menyerang?
AC = Seberapa sulit eksploitasi?
AT = Ada syarat/kondisi khusus?
PR = Perlu privilege/login?
UI = Perlu tindakan korban?

VC = Data sistem rentan bocor?
VI = Data sistem rentan berubah?
VA = Sistem rentan down?

SC = Data sistem lain bocor?
SI = Sistem lain berubah?
SA = Sistem lain down?
```

---

# 2. Exploitability Metrics

## Matriks Exploitability

| Metrik | Nama | Pertanyaan Paling Mudah | Nilai | Bahasa Awam | Contoh |
|---|---|---|---|---|---|
| **AV** | Attack Vector | Penyerang harus berada di mana? | `N / A / L / P` | Network / Adjacent / Local / Physical | SQL Injection lewat web → `AV:N` |
| **AC** | Attack Complexity | Apakah eksploitasi sulit? | `L / H` | Low / High | Payload langsung berhasil → `AC:L` |
| **AT** | Attack Requirements | Ada kondisi khusus agar exploit berhasil? | `N / P` | None / Present | Fitur tertentu harus aktif → `AT:P` |
| **PR** | Privileges Required | Sebelum exploit, attacker harus punya hak akses apa? | `N / L / H` | None / Low / High | IDOR setelah login → `PR:L` |
| **UI** | User Interaction | Perlu tindakan korban atau user lain? | `N / P / A` | None / Passive / Active | Stored XSS dibuka user → `UI:P` |

---

## 2.1 Attack Vector — AV

**Pertanyaan sederhana:**

> Penyerang harus berada di mana agar bisa melakukan serangan?

| Nilai | Arti | Bahasa Awam | Contoh |
|---|---|---|---|
| `AV:N` | Network | Bisa menyerang melalui jaringan/web/API | SQL Injection dari Internet |
| `AV:A` | Adjacent | Harus berada di jaringan yang berdekatan | Serangan pada jaringan lokal tertentu |
| `AV:L` | Local | Harus sudah punya akses lokal ke sistem | Local privilege escalation |
| `AV:P` | Physical | Harus menyentuh perangkat secara fisik | Serangan melalui USB/perangkat fisik |

### Cara cepat memahami

```text
Network
  ↓
Adjacent
  ↓
Local
  ↓
Physical
```

Semakin jauh attacker dapat menyerang, semakin banyak calon attacker yang berpotensi mengeksploitasi vulnerability.

### Contoh

Endpoint:

```http
GET /product?id=10
```

Parameter `id` ternyata vulnerable terhadap SQL Injection dan dapat diserang melalui web.

Maka:

```text
AV:N
```

---

## 2.2 Attack Complexity — AC

**Pertanyaan sederhana:**

> Apakah teknik eksploitasi relatif mudah atau membutuhkan rekayasa yang rumit?

| Nilai | Arti | Bahasa Awam |
|---|---|---|
| `AC:L` | Low | Exploit relatif sederhana dan dapat diulang |
| `AC:H` | High | Exploit membutuhkan teknik/kondisi teknis yang rumit |

### Contoh `AC:L`

```text
?id=1' OR '1'='1
```

Payload dapat langsung dipakai dan hasilnya konsisten.

```text
AC:L
```

### Contoh `AC:H`

Eksploitasi membutuhkan misalnya:

- race condition yang sangat presisi,
- bypass mitigasi keamanan yang kompleks,
- manipulasi memory tertentu,
- rekayasa teknis yang sulit.

Maka:

```text
AC:H
```

> **Catatan:** Payload panjang atau exploit script yang rumit tidak otomatis berarti `AC:H`. Yang dinilai adalah kompleksitas eksploitasi, bukan panjang kode.

---

## 2.3 Attack Requirements — AT

**Pertanyaan sederhana:**

> Apakah harus ada kondisi tertentu pada target sebelum exploit dapat berhasil?

| Nilai | Arti | Bahasa Awam |
|---|---|---|
| `AT:N` | None | Tidak ada kondisi tambahan |
| `AT:P` | Present | Ada kondisi/prasyarat target tertentu |

### Contoh `AT:N`

Endpoint selalu vulnerable ketika dipanggil:

```text
POST /api/search
```

Tidak diperlukan kondisi tertentu.

```text
AT:N
```

### Contoh `AT:P`

Vulnerability hanya bisa dieksploitasi jika:

```text
Feature X aktif
+
Mode Y aktif
+
Service Z sedang berjalan
```

Maka:

```text
AT:P
```

### Bedakan AC dan AT

```text
AC = Seberapa rumit cara mengeksploitasinya?

AT = Apakah target harus berada dalam kondisi tertentu?
```

---

## 2.4 Privileges Required — PR

**Pertanyaan sederhana:**

> Sebelum melakukan exploit, attacker harus memiliki privilege apa?

| Nilai | Arti | Bahasa Awam |
|---|---|---|
| `PR:N` | None | Tidak perlu login |
| `PR:L` | Low | Harus login sebagai user biasa |
| `PR:H` | High | Harus memiliki privilege tinggi/admin |

### Contoh

Public SQL Injection:

```text
PR:N
```

IDOR yang hanya dapat dilakukan setelah login:

```text
PR:L
```

Vulnerability yang hanya dapat dieksploitasi administrator:

```text
PR:H
```

### Kesalahan umum

Jika attacker awalnya tidak login:

```text
Attacker
   ↓
Authentication Bypass
   ↓
Menjadi Admin
```

Maka:

```text
PR:N
```

Bukan:

```text
PR:H
```

Karena `PR` menilai privilege **sebelum exploit dilakukan**.

---

## 2.5 User Interaction — UI

**Pertanyaan sederhana:**

> Apakah exploit membutuhkan tindakan dari korban atau user lain?

| Nilai | Arti | Bahasa Awam |
|---|---|---|
| `UI:N` | None | Tidak membutuhkan user lain |
| `UI:P` | Passive | User cukup melakukan aktivitas normal |
| `UI:A` | Active | User harus melakukan aksi sadar/spesifik |

### Contoh `UI:N`

SQL Injection:

```text
Attacker → Website → Database
```

Tidak ada korban yang perlu melakukan tindakan.

```text
UI:N
```

### Contoh `UI:P`

Stored XSS:

```text
Attacker memasukkan payload
        ↓
Payload tersimpan
        ↓
User membuka halaman secara normal
        ↓
Payload berjalan
```

```text
UI:P
```

### Contoh `UI:A`

Attacker perlu meyakinkan korban untuk:

- mengklik malicious link,
- menjalankan file,
- mengaktifkan fitur tertentu,
- melakukan tindakan spesifik agar exploit berjalan.

```text
UI:A
```

---

# 3. Impact Metrics

CVSS v4.0 membedakan dampak terhadap:

1. **Vulnerable System** — sistem yang memiliki vulnerability.
2. **Subsequent System** — sistem lain yang terdampak sebagai akibat exploit.

```text
VULNERABLE SYSTEM
VC = Confidentiality
VI = Integrity
VA = Availability

SUBSEQUENT SYSTEM
SC = Confidentiality
SI = Integrity
SA = Availability
```

Cara mengingat:

```text
C = Confidentiality = BOCOR
I = Integrity       = BERUBAH
A = Availability    = DOWN

V = Vulnerable System
S = Subsequent System
```

---

## Matriks Impact

| Metrik | Nama | Pertanyaan Paling Mudah | Nilai | Bahasa Awam |
|---|---|---|---|---|
| **VC** | Vulnerable System Confidentiality | Data sistem rentan bocor? | `H / L / N` | Bocor banyak / sedikit / tidak |
| **VI** | Vulnerable System Integrity | Data sistem rentan berubah? | `H / L / N` | Berubah besar / terbatas / tidak |
| **VA** | Vulnerable System Availability | Sistem rentan down? | `H / L / N` | Down besar / gangguan kecil / tidak |
| **SC** | Subsequent System Confidentiality | Data sistem lain ikut bocor? | `H / L / N` | Dampak confidentiality pada sistem lain |
| **SI** | Subsequent System Integrity | Sistem lain ikut berubah? | `H / L / N` | Dampak integrity pada sistem lain |
| **SA** | Subsequent System Availability | Sistem lain ikut down? | `H / L / N` | Dampak availability pada sistem lain |

---

## 3.1 VC — Vulnerable System Confidentiality

**Pertanyaan:**

> Apakah attacker dapat membaca data yang seharusnya tidak boleh dibaca pada sistem yang vulnerable?

### None

```text
VC:N
```

Tidak ada data yang bocor.

### Low

```text
VC:L
```

Attacker hanya bisa membaca informasi terbatas.

Contoh:

```text
username
nama
metadata tertentu
```

### High

```text
VC:H
```

Attacker dapat membaca data sensitif atau dalam jumlah besar.

Contoh:

```text
password hash
credential
database pelanggan
private key
token
data keuangan
```

---

## 3.2 VI — Vulnerable System Integrity

**Pertanyaan:**

> Apakah attacker dapat mengubah data atau konfigurasi pada sistem yang vulnerable?

### None

```text
VI:N
```

Attacker hanya dapat membaca.

### Low

```text
VI:L
```

Perubahan bersifat terbatas.

### High

```text
VI:H
```

Attacker dapat melakukan perubahan besar atau kritis.

Contoh:

```sql
UPDATE users
SET role='ADMIN';
```

atau:

```text
mengubah konfigurasi
mengubah transaksi
menghapus data penting
menanam webshell
```

---

## 3.3 VA — Vulnerable System Availability

**Pertanyaan:**

> Apakah attacker dapat membuat sistem yang vulnerable tidak tersedia?

### None

```text
VA:N
```

Tidak ada gangguan layanan.

### Low

```text
VA:L
```

Gangguan terbatas.

Contoh:

```text
service lambat
beberapa request gagal
restart sementara
```

### High

```text
VA:H
```

Sistem atau layanan utama tidak dapat digunakan.

Contoh:

```text
service crash
database down
resource exhaustion
server tidak dapat melayani user
```

---

# 4. Subsequent System Metrics

## 4.1 SC — Subsequent System Confidentiality

**Pertanyaan:**

> Apakah exploit pada sistem rentan menyebabkan data di sistem lain ikut bocor?

Contoh:

```text
Web Application
      ↓ exploit
Credential cloud diperoleh
      ↓
Storage/Cloud resource lain dapat dibaca
```

Jika dampaknya besar:

```text
SC:H
```

Jika tidak ada:

```text
SC:N
```

---

## 4.2 SI — Subsequent System Integrity

**Pertanyaan:**

> Apakah exploit pada sistem rentan memungkinkan attacker mengubah resource di sistem lain?

Contoh:

```text
Web App
  ↓
credential service account bocor
  ↓
attacker mengubah resource di sistem downstream
```

Maka dapat:

```text
SI:H
```

---

## 4.3 SA — Subsequent System Availability

**Pertanyaan:**

> Apakah exploit pada sistem rentan dapat membuat sistem lain ikut tidak tersedia?

Contoh:

```text
System A vulnerable
       ↓
exploit
       ↓
System B downstream berhenti berfungsi
```

Jika dampak besar:

```text
SA:H
```

Jika tidak ada:

```text
SA:N
```

> **Catatan:** Subsequent System bukan sekadar “ada server kedua”. Harus ada dampak keamanan nyata terhadap sistem lain akibat exploit.

---

# 5. Matriks Keputusan 11 Langkah

Gunakan tabel ini saat menilai temuan penetration testing.

| No | Metrik | Pertanyaan Awam | Pilihan |
|---:|---|---|---|
| 1 | **AV** | Attacker menyerang dari mana? | `N / A / L / P` |
| 2 | **AC** | Apakah eksploitasi sulit? | `L / H` |
| 3 | **AT** | Ada kondisi/prasyarat target tertentu? | `N / P` |
| 4 | **PR** | Harus punya privilege sebelum exploit? | `N / L / H` |
| 5 | **UI** | Perlu tindakan user/korban? | `N / P / A` |
| 6 | **VC** | Data sistem rentan bocor? | `N / L / H` |
| 7 | **VI** | Data sistem rentan bisa diubah? | `N / L / H` |
| 8 | **VA** | Sistem rentan bisa down? | `N / L / H` |
| 9 | **SC** | Data sistem lain ikut bocor? | `N / L / H` |
| 10 | **SI** | Sistem lain ikut berubah? | `N / L / H` |
| 11 | **SA** | Sistem lain ikut down? | `N / L / H` |

---

# 6. Flow Penilaian Praktis

```text
START
  |
  v
Attacker menyerang dari mana?
  |
  +--> AV
  |
  v
Exploit sederhana atau kompleks?
  |
  +--> AC
  |
  v
Ada kondisi target tertentu?
  |
  +--> AT
  |
  v
Harus login / punya privilege?
  |
  +--> PR
  |
  v
Perlu tindakan korban?
  |
  +--> UI
  |
  v
Exploit berhasil
  |
  +--> Data sistem rentan bocor? ------> VC
  +--> Data sistem rentan berubah? ----> VI
  +--> Sistem rentan down? ------------> VA
  |
  +--> Data sistem lain bocor? --------> SC
  +--> Sistem lain berubah? -----------> SI
  +--> Sistem lain down? --------------> SA
```

---

# 7. Contoh Praktis

## Contoh 1 — SQL Injection Read-Only

Skenario:

```http
GET /product?id=10'
```

Attacker dapat membaca seluruh database, tetapi tidak dapat mengubah data atau menyebabkan service down.

### Penilaian

| Metrik | Nilai | Alasan |
|---|---|---|
| AV | `N` | Lewat web |
| AC | `L` | Exploit sederhana |
| AT | `N` | Tidak ada kondisi khusus |
| PR | `N` | Tidak perlu login |
| UI | `N` | Tidak membutuhkan korban |
| VC | `H` | Seluruh data sensitif dapat dibaca |
| VI | `N` | Tidak dapat mengubah data |
| VA | `N` | Tidak membuat service down |
| SC | `N` | Tidak ada dampak ke sistem lain |
| SI | `N` | Tidak ada |
| SA | `N` | Tidak ada |

### Vector

```text
CVSS:4.0/AV:N/AC:L/AT:N/PR:N/UI:N/VC:H/VI:N/VA:N/SC:N/SI:N/SA:N
```

---

## Contoh 2 — IDOR Read-Only

Skenario:

```http
GET /api/profile/1001
```

User biasa mengganti:

```text
1001 → 1002
```

dan dapat melihat data user lain.

### Penilaian

| Metrik | Nilai |
|---|---|
| AV | `N` |
| AC | `L` |
| AT | `N` |
| PR | `L` |
| UI | `N` |
| VC | `H` |
| VI | `N` |
| VA | `N` |
| SC | `N` |
| SI | `N` |
| SA | `N` |

### Vector

```text
CVSS:4.0/AV:N/AC:L/AT:N/PR:L/UI:N/VC:H/VI:N/VA:N/SC:N/SI:N/SA:N
```

---

## Contoh 3 — Command Injection / Remote Code Execution

Skenario:

```http
POST /api/ping

host=google.com;whoami
```

Server menjalankan command OS yang diberikan attacker.

Attacker akhirnya dapat:

```text
membaca file
mengubah file
menanam malware/webshell
menghentikan service
```

### Penilaian

| Metrik | Nilai | Alasan |
|---|---|---|
| AV | `N` | Remote melalui web |
| AC | `L` | Payload relatif sederhana |
| AT | `N` | Tidak membutuhkan kondisi khusus |
| PR | `N` | Tidak perlu login |
| UI | `N` | Tidak perlu user lain |
| VC | `H` | Data server dapat dibaca |
| VI | `H` | Sistem dapat diubah |
| VA | `H` | Service dapat dihentikan |
| SC | `N` | Tidak ada bukti sistem lain terdampak |
| SI | `N` | Tidak ada |
| SA | `N` | Tidak ada |

### Vector

```text
CVSS:4.0/AV:N/AC:L/AT:N/PR:N/UI:N/VC:H/VI:H/VA:H/SC:N/SI:N/SA:N
```

---

## Contoh 4 — Stored XSS

Skenario:

1. Attacker login.
2. Attacker memasukkan payload XSS.
3. Payload tersimpan.
4. Administrator membuka halaman tersebut.
5. Script berjalan pada browser administrator.

### Penilaian contoh

| Metrik | Nilai | Alasan |
|---|---|---|
| AV | `N` | Serangan dilakukan lewat aplikasi web |
| AC | `L` | Payload relatif sederhana |
| AT | `N` | Tidak ada kondisi target tambahan |
| PR | `L` | Attacker harus login untuk posting |
| UI | `P` | Korban cukup membuka halaman secara normal |
| VC | `L/H` | Tergantung data/session yang dapat dicuri |
| VI | `L/H` | Tergantung aksi yang dapat dilakukan |
| VA | `N` | Umumnya tidak mempengaruhi availability |
| SC | `N/H` | Bergantung apakah browser/user context dianggap subsequent system dan dampaknya |
| SI | `N/H` | Bergantung dampak aktual |
| SA | `N` | Biasanya tidak ada |

> Nilai XSS tidak boleh disamaratakan. Dampak aktual harus diuji dan dibuktikan.

---

# 8. Matriks Cepat Contoh Vulnerability Web

> **Penting:** Tabel berikut hanya pola umum untuk belajar, bukan nilai baku.

| Vulnerability | AV | AC | AT | PR | UI | Dampak yang Sering Dominan |
|---|---|---|---|---|---|---|
| SQL Injection | N | L | N | N/L | N | VC, VI, VA |
| Command Injection / RCE | N | L | N | N/L | N | VC, VI, VA |
| IDOR Read | N | L | N | L | N | VC |
| IDOR Write | N | L | N | L | N | VC, VI |
| Authentication Bypass | N | L | N | N | N | VC, VI |
| Stored XSS | N | L | N | N/L | P | VC/VI atau SC/SI |
| Reflected XSS | N | L | N | N/L | A | VC/VI atau SC/SI |
| Path Traversal | N | L | N | N/L | N | VC |
| Unrestricted File Upload → RCE | N | L | N | N/L | N | VC, VI, VA |
| Denial of Service | N | L/H | N/P | N/L | N | VA |

---

# 9. Cara Membaca Vector CVSS v4.0

Contoh:

```text
CVSS:4.0/AV:N/AC:L/AT:N/PR:N/UI:N/VC:H/VI:H/VA:H/SC:N/SI:N/SA:N
```

Baca seperti kalimat:

```text
AV:N → bisa diserang melalui network
AC:L → exploit relatif sederhana
AT:N → tidak ada kondisi khusus
PR:N → tidak perlu login
UI:N → tidak perlu tindakan korban

VC:H → data sistem rentan dapat bocor besar
VI:H → sistem rentan dapat diubah besar
VA:H → sistem rentan dapat dibuat tidak tersedia

SC:N → tidak ada kebocoran pada subsequent system
SI:N → tidak ada perubahan pada subsequent system
SA:N → tidak ada availability impact pada subsequent system
```

Dalam bahasa manusia:

> **“Attacker dapat menyerang dari jaringan tanpa login, tanpa bantuan korban, dan tanpa kondisi khusus. Jika berhasil, attacker dapat membaca, mengubah, dan menghentikan sistem yang vulnerable.”**

---

# 10. Ringkasan Hafalan

```text
==============================
   BAGAIMANA MENYERANG?
==============================

AV = Dari mana?
AC = Sulit?
AT = Ada syarat?
PR = Perlu akses?
UI = Perlu korban?


==============================
   APA YANG TERDAMPAK?
==============================

VULNERABLE SYSTEM

VC = BOCOR?
VI = BERUBAH?
VA = DOWN?


SUBSEQUENT SYSTEM

SC = BOCOR?
SI = BERUBAH?
SA = DOWN?
```

---

# 11. Prinsip Penting

## Jangan menilai dari nama vulnerability

CVSS tidak bertanya:

> “Ini SQL Injection atau bukan?”

CVSS bertanya:

> “Bagaimana vulnerability ini dieksploitasi dan apa dampak nyata setelah berhasil?”

Karena itu:

```text
SQL Injection A
→ hanya membaca satu tabel

SQL Injection B
→ dump seluruh database

SQL Injection C
→ RCE pada server
```

ketiganya dapat memiliki vector CVSS berbeda.

---

# 12. Checklist Assessment

Gunakan checklist berikut untuk setiap temuan:

```markdown
- [ ] AV — attacker menyerang dari mana?
- [ ] AC — exploit mudah atau kompleks?
- [ ] AT — ada kondisi khusus?
- [ ] PR — attacker perlu privilege apa sebelum exploit?
- [ ] UI — perlu tindakan user lain?
- [ ] VC — data vulnerable system bocor?
- [ ] VI — vulnerable system dapat diubah?
- [ ] VA — vulnerable system dapat down?
- [ ] SC — data subsequent system bocor?
- [ ] SI — subsequent system dapat diubah?
- [ ] SA — subsequent system dapat down?
```

---

# 13. Template Penilaian Temuan

```markdown
## [Nama Vulnerability]

### Skenario
Jelaskan bagaimana attacker melakukan exploit.

### Exploitability

| Metric | Nilai | Alasan |
|---|---|---|
| AV |  |  |
| AC |  |  |
| AT |  |  |
| PR |  |  |
| UI |  |  |

### Impact

| Metric | Nilai | Alasan |
|---|---|---|
| VC |  |  |
| VI |  |  |
| VA |  |  |
| SC |  |  |
| SI |  |  |
| SA |  |  |

### CVSS Vector

CVSS:4.0/AV:?/AC:?/AT:?/PR:?/UI:?/VC:?/VI:?/VA:?/SC:?/SI:?/SA:?

### Interpretasi

Tuliskan dalam bahasa sederhana bagaimana vulnerability tersebut dieksploitasi dan apa dampaknya.
```

---

## Referensi Resmi

- FIRST — CVSS v4.0 Specification  
  https://www.first.org/cvss/v4.0/specification-document

- FIRST — CVSS v4.0 Examples  
  https://www.first.org/cvss/v4.0/examples

- FIRST — CVSS v4.0 Calculator  
  https://www.first.org/cvss/calculator/4.0
