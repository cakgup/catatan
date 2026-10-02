# AOS-CX Lab Guides

Panduan ini merupakan rangkaian **sebelas modul praktik** untuk mempelajari jaringan enterprise, campus, dan data center menggunakan Aruba AOS-CX.

Materi disusun untuk pembaca pemula agar tidak hanya menyalin perintah, tetapi memahami:

- perangkat apa yang sedang dikonfigurasi;
- masalah jaringan apa yang ingin diselesaikan;
- alasan sebuah perintah diperlukan;
- cara memeriksa apakah konfigurasi berhasil;
- langkah troubleshooting ketika hasilnya tidak sesuai;
- bagaimana teknologi switching, routing, BGP, dan overlay digabung menjadi desain jaringan yang utuh.

> **Tujuan utama:** memahami perjalanan jaringan dari switching dasar, pengenalan endpoint, redundansi, routing OSPF, desain campus Layer 2/Layer 3, BGP, sampai overlay VXLAN EVPN.

---

## 1. Gambaran sederhana: apa yang akan dipelajari?

Bayangkan sebuah kantor memiliki komputer, printer, server, access point, access switch, distribution switch, core switch, dan koneksi ke jaringan lain. Agar semuanya dapat berkomunikasi dengan baik, jaringan harus mempunyai beberapa kemampuan:

```text
Endpoint terhubung ke access switch
        ↓
Switch mengenali perangkat dan menempatkannya ke VLAN
        ↓
STP mencegah loop pada jalur Layer 2 yang redundan
        ↓
LACP dan VSX menyediakan link serta switch cadangan
        ↓
Active Gateway menyediakan default gateway yang redundan
        ↓
OSPF membuat perangkat Layer 3 saling mempelajari rute
        ↓
Konsep tersebut digabung menjadi Campus 2-Tier dan 3-Tier
        ↓
BGP bertukar route berdasarkan AS dan kebijakan
        ↓
VXLAN membawa jaringan Layer 2 melewati jaringan Layer 3
        ↓
BGP EVPN menyebarkan informasi endpoint secara dinamis
```

Dengan demikian, seluruh modul membentuk satu cerita besar:

> **Bagaimana membangun jaringan Aruba AOS-CX yang terhubung, redundan, dapat dirutekan, dapat bertukar route antar-domain, mudah dikembangkan, dan dapat di-troubleshoot.**

---

## 2. Istilah dasar sebelum mulai

| Istilah | Penjelasan sederhana |
|---|---|
| **Switch** | Perangkat yang menghubungkan komputer, server, atau perangkat jaringan. |
| **Port/interface** | Titik koneksi pada switch, misalnya `1/1/1`. |
| **Layer 2** | Komunikasi berdasarkan MAC address; berkaitan dengan VLAN dan switching. |
| **Layer 3** | Komunikasi berdasarkan IP address dan routing antarjaringan. |
| **VLAN** | Pemisahan jaringan secara logis. |
| **MAC address** | Identitas Layer 2 suatu perangkat. |
| **IP address** | Alamat Layer 3 untuk komunikasi antarjaringan. |
| **Routing** | Proses memilih jalur menuju jaringan tujuan. |
| **LAG/LACP** | Penggabungan beberapa link fisik menjadi satu link logis. |
| **Redundansi** | Menyediakan jalur atau perangkat cadangan. |
| **Access layer** | Lapisan yang langsung menghubungkan endpoint. |
| **Aggregation/distribution** | Lapisan yang mengumpulkan access switch dan melakukan kebijakan/routing. |
| **Core layer** | Backbone Layer 3 berkecepatan tinggi. |
| **OSPF** | Protokol untuk mempelajari route secara dinamis di dalam domain jaringan. |
| **Autonomous System (AS)** | Sekumpulan router yang memakai kebijakan routing yang sama. |
| **BGP** | Protokol pertukaran route antar-AS atau berdasarkan kebijakan. |
| **Underlay** | Jaringan IP dasar yang menjadi jalur transportasi. |
| **Overlay** | Jaringan virtual yang dibangun di atas underlay, misalnya VXLAN. |

Jika beberapa istilah masih terasa asing, tetap lanjutkan. Setiap modul menjelaskannya melalui praktik.

---

## 3. Tentang Aruba AOS-CX

**AOS-CX** adalah sistem operasi jaringan pada switch Aruba CX. Konfigurasi dilakukan melalui CLI.

```text
switch# configure terminal
switch(config)# hostname SwitchA
SwitchA(config)# interface 1/1/1
SwitchA(config-if)# no shutdown
```

Arti urutannya:

1. masuk ke mode konfigurasi;
2. mengganti nama switch;
3. memilih interface;
4. mengaktifkan interface.

> Sintaks CLI tetap menggunakan bahasa asli perangkat. Penjelasan tujuan, konsep, validasi, dan troubleshooting ditulis dalam bahasa Indonesia.

---

## 4. Persiapan lingkungan lab

Lab dapat dijalankan menggunakan **PNETLab** sebagai emulator jaringan.

### Unduh PNETLab

[Download PNETLab](https://pnetlab.com/pages/download)

### Komponen yang perlu disiapkan

- PNETLab yang sudah terpasang dan dapat diakses;
- image/OVA Aruba AOS-CX Switch Simulator;
- VPCS untuk mensimulasikan host;
- browser dan console terminal;
- CPU dan RAM yang cukup, terutama untuk lab VSX, Campus 3-Tier, dan VXLAN EVPN.

Sebelum memulai:

```text
Node AOS-CX dapat menyala
→ console dapat dibuka
→ login admin berhasil
→ interface dapat diaktifkan
→ neighbor LLDP dapat terlihat
```

---

## 5. Urutan belajar yang disarankan

| Urutan | Panduan | Pertanyaan yang dijawab |
|---:|---|---|
| 1 | [Deploying basic STP](<AOS-CX Simulator Lab - Spanning Tree Basics Lab Guide.md>) | Bagaimana menyediakan jalur cadangan tanpa menimbulkan loop? |
| 2 | [Local MAC Match Authentication](<AOS-CX Simulator - Local Mac Authentication Lab Guide.md>) | Bagaimana switch mengenali endpoint berdasarkan MAC? |
| 3 | [VSX Lab1 - Layer2](<AOS-CX Simulator - VSX Part 1 Lab Guide.md>) | Bagaimana dua switch bekerja sebagai pasangan redundan? |
| 4 | [Campus Series Part I - 2 Tier L2 Access & VSX](<AOS-CX Simulator Lab - Campus 2-Tier IPv4 L2 Access VSX Lab Guide.md>) | Bagaimana VLAN, MCLAG, VSX, dan Active Gateway digabung menjadi campus 2-tier Layer 2? |
| 5 | [Configuring OSPF on Aruba CX Switches](<AOS-CX Simulator - Deploying OSPF Lab Guide.md>) | Bagaimana switch Layer 3 mempelajari rute secara otomatis? |
| 6 | [Part I Campus 2 Tier - Layer 3 Access with OSPF](<AOS-CX Simulator Lab - Campus 2-Tier L3 Access with OSPF Lab Guide.md>) | Bagaimana gateway ditempatkan di access switch dan uplink menggunakan OSPF? |
| 7 | [Deploying OSPFv2 Areas](<AOS-CX Switch Simulator - OSPFv2 Areas Basics Lab Guide.md>) | Bagaimana OSPF dibagi menjadi beberapa area? |
| 8 | [Part II Campus 3 Tier - L2 Access with VSX and OSPF](<AOS-CX Simulator Lab - Campus 3-Tier IPv4 L2 Access with VSX and OSPF Lab Guide.md>) | Bagaimana jaringan 2-tier diperluas menjadi 3-tier dengan core OSPF? |
| 9 | [Static VXLAN](<AOS-CX Simulator - Static VXLAN Lab Guide.md>) | Bagaimana VLAN diperluas melalui jaringan Layer 3 secara manual? |
| 10 | [Deploying basic BGP](<AOS-CX Simulator - Basic BGP Lab Guide.md>) | Bagaimana route dipertukarkan dengan iBGP/eBGP dan dikendalikan dengan policy? |
| 11 | [VXLAN EVPN](<AOS-CX Switch Simulator - VXLAN EVPN Lab Guide.md>) | Bagaimana BGP EVPN mengelola VXLAN secara dinamis? |

### Mengapa urutannya seperti ini?

```text
STP dan VLAN
    ↓
LACP dan VSX
    ↓
Campus 2-Tier Layer 2
    ↓
OSPF Dasar
    ↓
Campus 2-Tier Layer 3
    ↓
OSPF Areas dan Campus 3-Tier
    ↓
Static VXLAN
    ↓
Basic BGP
    ↓
VXLAN EVPN
```

- Campus 2-Tier L2 menggabungkan VLAN, LACP, VSX, MCLAG, dan Active Gateway.
- OSPF dasar menjadi fondasi sebelum mempelajari routed access dan Campus 3-Tier.
- Campus 2-Tier L3 menunjukkan alternatif desain: gateway berada pada access switch dan uplink menggunakan routing.
- Static VXLAN memperkenalkan overlay tanpa control plane BGP.
- Basic BGP perlu dipahami sebelum BGP digunakan sebagai control plane EVPN.

### Jalur tercepat menuju VXLAN EVPN

```text
STP → OSPF Dasar → Static VXLAN → Basic BGP → VXLAN EVPN
```

---

## 6. Penjelasan setiap modul dengan bahasa sederhana

### 6.1 Spanning Tree - mencegah loop

STP memilih root bridge, jalur utama, dan jalur cadangan yang diblokir agar jaringan Layer 2 tetap bebas loop.

### 6.2 Local MAC Match Authentication - mengenali endpoint

Switch mencocokkan MAC address dengan profile lokal dan dapat memberikan role atau VLAN tertentu.

### 6.3 VSX Lab1 - membangun redundansi dasar

Dua switch membentuk pasangan primary-secondary menggunakan ISL, keepalive, sinkronisasi, dan MCLAG.

### 6.4 Campus 2-Tier L2 - menggabungkan VSX dengan access layer

Access switch membawa VLAN 100 dan 200 menuju pasangan VSX. VSX menjadi collapsed core dan menyediakan Active Gateway agar endpoint dapat berkomunikasi antar-VLAN secara redundan.

### 6.5 OSPF Dasar - mempelajari route otomatis

Switch Layer 3 bertukar informasi jaringan dan membentuk neighbor berstatus `FULL`.

### 6.6 Campus 2-Tier L3 - routing dimulai dari access switch

SwitchC menjadi default gateway endpoint dan mempunyai dua uplink routed menuju core. OSPF menggantikan ketergantungan pada trunk Layer 2 untuk uplink.

### 6.7 OSPF Areas - mengelola routing yang lebih besar

OSPF dibagi menjadi Area 0 dan area lain. Modul membahas ABR, ASBR, redistribution, stub, dan NSSA.

### 6.8 Campus 3-Tier - menambahkan core OSPF

Desain 2-tier L2 diperluas dengan SwitchX dan SwitchY sebagai core. Pasangan VSX mengiklankan subnet pengguna ke OSPF dan mempunyai beberapa jalur redundan menuju core.

### 6.9 Static VXLAN - membawa VLAN melalui jaringan IP

VLAN dipetakan ke VNI dan dibawa melalui tunnel VXLAN yang VTEP peer-nya dikonfigurasi manual.

### 6.10 Basic BGP - bertukar route antar-AS

OSPF menyediakan reachability untuk iBGP, kemudian eBGP menghubungkan AS 65000 dan AS 65001. Prefix-list dan route-map digunakan untuk mengendalikan route.

### 6.11 VXLAN EVPN - VXLAN yang lebih dinamis

BGP EVPN menjadi control plane untuk mendistribusikan informasi MAC, VNI, dan VTEP.

---

## 7. Memahami dua pilihan desain campus

### Campus L2 Access

```text
Endpoint
→ access switch Layer 2
→ trunk/MCLAG
→ VSX core sebagai gateway
```

Cocok ketika gateway dan kebijakan ingin dipusatkan pada aggregation/core.

### Campus L3 Access

```text
Endpoint
→ access switch sebagai gateway
→ uplink routed
→ OSPF menuju core
```

Cocok ketika ingin memperkecil domain Layer 2 dan menggunakan routing untuk redundansi uplink.

| Aspek | L2 Access | L3 Access |
|---|---|---|
| Gateway | VSX core | Access switch |
| Uplink | Trunk/MCLAG | Routed point-to-point |
| Protokol utama | VLAN, LACP, VSX | IP dan OSPF |
| Domain Layer 2 | Sampai core | Berhenti di access |
| Redundansi | VSX/MCLAG | OSPF |

---

## 8. Cara belajar dari setiap modul

### Tahap 1 - Pahami tujuan

Sebelum mengetik perintah, jawab:

1. topologi apa yang dibuat;
2. perangkat mana yang saling terhubung;
3. hasil akhir apa yang diharapkan.

### Tahap 2 - Konfigurasi sedikit demi sedikit

```text
Aktifkan interface
→ cek LLDP dan status interface
→ konfigurasi VLAN atau IP
→ uji koneksi langsung
→ aktifkan protokol
→ cek neighbor
→ cek tabel MAC/route
→ ping ujung ke ujung
```

### Tahap 3 - Baca output

```text
show interface brief
show lldp neighbor-info
show vlan
show mac-address-table
show lacp interfaces
show vsx status
show ip route
show ip ospf neighbors
show bgp ipv4 unicast summary
```

### Tahap 4 - Buat kegagalan dengan sengaja

- shutdown satu link;
- ubah IP menjadi salah subnet;
- hapus VLAN dari trunk;
- ubah area OSPF;
- putus salah satu anggota LAG;
- salahkan remote AS BGP;
- gunakan VNI berbeda.

Kemudian cari penyebabnya dengan perintah `show`.

---

## 9. Memahami mode CLI AOS-CX

| Prompt | Sedang berada di mana? | Contoh perintah |
|---|---|---|
| `Switch#` | Mode operasional | `show`, `ping`, `configure terminal` |
| `Switch(config)#` | Konfigurasi global | `hostname`, `vlan`, `router ospf`, `router bgp` |
| `Switch(config-if)#` | Interface fisik | `ip address`, `no routing`, `vlan access` |
| `Switch(config-loopback-if)#` | Loopback | `ip address`, `ip ospf` |
| `Switch(config-ospf-1)#` | Proses OSPF | `router-id`, `area` |
| `Switch(config-bgp)#` | Proses BGP | `neighbor`, `address-family` |

Contoh kesalahan:

```text
switch# hostname SwitchA
Invalid input: hostname
```

Perbaikan:

```text
switch# configure terminal
switch(config)# hostname SwitchA
```

---

## 10. Pola validasi dasar

### Layer 1 dan topologi

```text
show interface brief
show lldp neighbor-info
```

### Layer 2

```text
show vlan
show mac-address-table
show spanning-tree
show lacp interfaces
```

### VSX dan high availability

```text
show vsx status
show vsx brief
show lacp interfaces multi-chassis
```

### Layer 3 dan OSPF

```text
show ip interface brief
show ip route
show ip ospf neighbors
show ip ospf route
ping <alamat-tujuan>
```

### BGP

```text
show bgp ipv4 unicast summary
show bgp ipv4 unicast
show ip route bgp
```

### VXLAN/EVPN

```text
show interface vxlan
show bgp l2vpn evpn summary
show bgp l2vpn evpn
```

---

## 11. Urutan troubleshooting untuk pemula

```text
1. Topologi/kabel benar?
        ↓
2. Interface up dan no shutdown?
        ↓
3. Mode L2/L3 sesuai?
        ↓
4. VLAN, trunk, IP, dan prefix benar?
        ↓
5. Perangkat terhubung langsung dapat ping?
        ↓
6. LAG/VSX sehat?
        ↓
7. OSPF neighbor terbentuk?
        ↓
8. Loopback BGP saling reachable?
        ↓
9. BGP neighbor Established?
        ↓
10. MAC/route tujuan masuk tabel?
        ↓
11. Ping ujung ke ujung berhasil?
```

> Jangan memeriksa BGP jika IP neighbor belum dapat diping. Jangan memeriksa OSPF jika link langsung dan ping next-hop saja belum berhasil.

---

## 12. Tanda bahwa sebuah lab berhasil

| Lab | Indikator keberhasilan |
|---|---|
| STP | Satu jalur redundan blocking dan jaringan bebas loop. |
| Local MAC Match | Client terdeteksi dan role diterapkan. |
| VSX Lab1 | ISL `In-Sync`, keepalive `Established`, MCLAG aktif. |
| Campus 2-Tier L2 | Active Gateway dapat diping dan host antar-VLAN saling terhubung. |
| OSPF Dasar | Neighbor `FULL` dan host ujung ke ujung dapat ping. |
| Campus 2-Tier L3 | SwitchC memiliki dua neighbor `FULL` dan route VLAN terlihat pada core. |
| OSPF Areas | Route intra-area, inter-area, dan external dapat dibedakan. |
| Campus 3-Tier | Empat router OSPF mempunyai neighbor yang benar dan endpoint dapat mencapai core. |
| Static VXLAN | VTEP peer aktif dan host dapat ping melalui VXLAN. |
| Basic BGP | iBGP/eBGP `Established` dan kedua jaringan host masuk BGP table. |
| VXLAN EVPN | BGP EVPN `Established`, remote MAC dipelajari melalui EVPN. |

---

## 13. Struktur paket

Repositori ini terdiri atas:

- satu README sebagai peta belajar;
- sebelas file Markdown;
- folder `assets/` berisi gambar topologi;
- penjelasan berbahasa Indonesia;
- konfigurasi CLI AOS-CX;
- validasi, troubleshooting, checklist, dan latihan pada setiap modul.

---

## 14. Ringkasan akhir

```text
Switching Layer 2
→ pengenalan endpoint
→ redundansi link dan switch
→ Campus 2-Tier L2
→ routing OSPF
→ Campus 2-Tier L3 dan Campus 3-Tier
→ Static VXLAN
→ iBGP dan eBGP
→ control plane BGP EVPN
```

Kerjakan konfigurasi bertahap dan selalu validasi sebelum melanjutkan.
