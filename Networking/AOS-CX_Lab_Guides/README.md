# AOS-CX Lab Guides

Panduan ini merupakan rangkaian latihan untuk mempelajari **dasar hingga menengah jaringan enterprise dan data center menggunakan Aruba AOS-CX**.

Materi disusun bertahap agar pembaca pemula tidak hanya menyalin perintah, tetapi juga memahami:

- perangkat apa yang sedang dikonfigurasi;
- masalah jaringan apa yang ingin diselesaikan;
- alasan sebuah perintah diperlukan;
- cara memastikan konfigurasi berhasil;
- langkah mencari penyebab ketika hasilnya tidak sesuai.

> **Tujuan utama:** memahami perjalanan sebuah jaringan dari switching dasar, redundansi, dan routing, hingga membangun jaringan overlay menggunakan VXLAN EVPN.

---

## 1. Gambaran sederhana: apa yang akan dipelajari?

Bayangkan sebuah kantor atau data center memiliki banyak komputer, server, dan switch. Agar semuanya dapat berkomunikasi dengan aman dan tetap tersedia ketika terjadi gangguan, jaringan memerlukan beberapa kemampuan berikut:

```text
Komputer atau server terhubung ke switch
        ↓
Switch mengenali perangkat dan menempatkannya ke VLAN
        ↓
STP mencegah loop pada jalur Layer 2 yang redundan
        ↓
VSX menjaga layanan tetap berjalan jika link atau switch gagal
        ↓
OSPF membuat perangkat Layer 3 saling mempelajari rute
        ↓
VXLAN membawa jaringan Layer 2 melewati jaringan Layer 3
        ↓
BGP EVPN menyebarkan informasi endpoint secara dinamis
```

Dengan demikian, tujuh lab dalam repositori ini sebenarnya membentuk satu cerita besar:

> **Bagaimana membangun jaringan Aruba AOS-CX yang terhubung, redundan, dapat dirutekan, mudah dikembangkan, dan dapat di-troubleshoot.**

---

## 2. Istilah dasar sebelum mulai

Pembaca tidak harus sudah mahir networking, tetapi sebaiknya mengenal istilah berikut.

| Istilah | Penjelasan sederhana |
|---|---|
| **Switch** | Perangkat yang menghubungkan komputer, server, atau perangkat jaringan dalam satu lingkungan. |
| **Port/interface** | Titik koneksi pada switch, misalnya `1/1/1`. |
| **Layer 2** | Komunikasi berdasarkan MAC address, biasanya berkaitan dengan VLAN dan switching. |
| **Layer 3** | Komunikasi berdasarkan IP address dan routing antarjaringan. |
| **VLAN** | Pemisahan jaringan secara logis dalam satu atau beberapa switch. |
| **MAC address** | Identitas Layer 2 suatu perangkat jaringan. |
| **IP address** | Alamat Layer 3 yang digunakan untuk komunikasi antarjaringan. |
| **Routing** | Proses memilih jalur menuju jaringan tujuan. |
| **Redundansi** | Menyediakan jalur atau perangkat cadangan agar layanan tetap berjalan saat terjadi kegagalan. |
| **Underlay** | Jaringan IP dasar yang menjadi jalur transportasi. |
| **Overlay** | Jaringan virtual yang dibangun di atas underlay, misalnya VXLAN. |

Jika istilah tersebut masih terasa asing, tetap lanjutkan. Setiap lab akan menjelaskannya melalui praktik.

---

## 3. Tentang Aruba AOS-CX

**AOS-CX** adalah sistem operasi jaringan yang digunakan pada switch Aruba CX. Dalam panduan ini, konfigurasi dilakukan melalui Command Line Interface atau CLI.

Contoh sederhana:

```text
switch# configure terminal
switch(config)# hostname SwitchA
SwitchA(config)# interface 1/1/1
SwitchA(config-if)# no shutdown
```

Arti urutannya:

1. masuk ke mode konfigurasi;
2. mengganti nama switch menjadi `SwitchA`;
3. memilih interface `1/1/1`;
4. mengaktifkan interface tersebut.

> Sintaks perintah tetap menggunakan bahasa asli perangkat. Penjelasan konsep, tujuan, validasi, dan troubleshooting ditulis dalam bahasa Indonesia.

---

## 4. Persiapan lingkungan lab

Lab dapat dijalankan menggunakan **PNETLab** sebagai emulator jaringan.

### Unduh PNETLab

[Download PNETLab](https://pnetlab.com/pages/download)

### Komponen yang perlu disiapkan

- PNETLab yang sudah terpasang dan dapat diakses;
- image atau OVA **Aruba AOS-CX Switch Simulator** yang sesuai;
- VPCS untuk mensimulasikan komputer atau host pada beberapa lab;
- web browser dan console terminal untuk membuka setiap node;
- sumber daya CPU dan RAM yang cukup sesuai jumlah switch dalam topologi.

Sebelum memulai lab pertama, pastikan:

```text
Node AOS-CX dapat menyala
→ console dapat dibuka
→ login admin berhasil
→ interface dapat diaktifkan
→ perangkat yang terhubung muncul melalui LLDP
```

---

## 5. Urutan belajar yang disarankan

Kerjakan lab secara berurutan karena konsep pada bagian akhir menggunakan dasar dari bagian sebelumnya.

| Urutan | Panduan | Pertanyaan yang dijawab |
|---:|---|---|
| 1 | [Deploying basic STP](<AOS-CX Simulator Lab - Spanning Tree Basics Lab Guide.md>) | Bagaimana menyediakan jalur cadangan antar-switch tanpa menimbulkan loop? |
| 2 | [Local MAC Match Authentication](<AOS-CX Simulator - Local Mac Authentication Lab Guide.md>) | Bagaimana switch mengenali perangkat berdasarkan MAC address dan memberikan role atau VLAN? |
| 3 | [VSX Lab1 - Layer2](<AOS-CX Simulator - VSX Part 1 Lab Guide.md>) | Bagaimana dua switch bekerja sebagai pasangan redundan? |
| 4 | [Configuring OSPF on Aruba CX Switches](<AOS-CX Simulator - Deploying OSPF Lab Guide.md>) | Bagaimana switch Layer 3 saling mempelajari rute secara otomatis? |
| 5 | [Deploying OSPFv2 Areas](<AOS-CX Switch Simulator - OSPFv2 Areas Basics Lab Guide.md>) | Bagaimana OSPF dibagi menjadi beberapa area untuk jaringan yang lebih besar? |
| 6 | [Static VXLAN](<AOS-CX Simulator - Static VXLAN Lab Guide.md>) | Bagaimana VLAN diperluas melewati jaringan Layer 3 menggunakan VXLAN statis? |
| 7 | [VXLAN EVPN](<AOS-CX Switch Simulator - VXLAN EVPN Lab Guide.md>) | Bagaimana BGP EVPN mengelola informasi VXLAN secara dinamis? |

### Jalur tercepat menuju VXLAN EVPN

Pembaca yang ingin fokus ke data center fabric dapat menggunakan urutan berikut:

```text
STP
  ↓
OSPF Dasar
  ↓
OSPF Areas
  ↓
Static VXLAN
  ↓
VXLAN EVPN
```

Local MAC Match Authentication dan VSX tetap penting, tetapi fokus utamanya berbeda:

- **Local MAC Match Authentication**: keamanan dan pengenalan endpoint;
- **VSX**: ketersediaan tinggi dan redundansi switch.

---

## 6. Penjelasan setiap lab dengan bahasa sederhana

### 6.1 Spanning Tree Protocol — mencegah loop

Pada jaringan Layer 2, link cadangan diperlukan untuk mengantisipasi kegagalan. Namun, link yang membentuk lingkaran dapat menyebabkan broadcast berputar terus-menerus.

```text
SwitchA ───── SwitchB
   \             /
    \           /
       SwitchC
```

STP akan:

- memilih satu switch sebagai **root bridge**;
- menentukan jalur utama;
- memblokir salah satu jalur cadangan;
- membuka jalur cadangan ketika jalur utama gagal.

Setelah lab ini, Anda diharapkan memahami root bridge, root port, designated port, alternate port, priority, dan path cost.

### 6.2 Local MAC Match Authentication — mengenali endpoint

Switch dapat mengenali perangkat berdasarkan MAC address dan menerapkan role tertentu.

Contoh pemanfaatan:

```text
IP Phone → role voice → VLAN voice
Printer  → role printer → VLAN printer
Laptop   → role user → VLAN user
```

Lab ini memperkenalkan konsep `mac-group`, `port-access role`, dan `device-profile`.

### 6.3 VSX — redundansi dua switch

VSX membuat dua switch Aruba bekerja sebagai pasangan. Perangkat di bawahnya dapat terhubung ke kedua switch secara bersamaan.

```text
                 ┌── VSX Primary
Access Switch ───┤
                 └── VSX Secondary
```

Jika salah satu link atau switch mengalami gangguan, trafik dapat menggunakan jalur lainnya. Konsep yang dipelajari antara lain LAG, LACP, ISL, keepalive, configuration synchronization, dan multi-chassis LAG.

### 6.4 OSPF Dasar — mempelajari rute secara otomatis

Tanpa routing dinamis, switch hanya mengenal jaringan yang terhubung langsung. Administrator harus menambahkan static route secara manual.

Dengan OSPF:

```text
SwitchA ── SwitchB ── SwitchC ── SwitchD
```

setiap switch saling bertukar informasi jaringan dan menentukan jalur secara otomatis.

Anda akan mempelajari routed interface, loopback, router ID, neighbor, route OSPF, dan end-to-end ping.

### 6.5 OSPF Areas — mengelola routing yang lebih besar

Ketika jaringan membesar, OSPF dapat dibagi menjadi beberapa area agar informasi routing lebih terstruktur.

```text
SwitchA ── SwitchB ── SwitchC ── SwitchD
       Area 0      Area 1
```

Materi yang dipelajari meliputi Area 0, ABR, ASBR, intra-area route, inter-area route, redistribution, external route, stub area, dan NSSA.

### 6.6 Static VXLAN — membawa VLAN melalui jaringan IP

VXLAN memungkinkan dua host pada VLAN yang sama tetap berkomunikasi meskipun berada di lokasi switch yang berbeda dan dipisahkan jaringan Layer 3.

```text
Host1 ─ Leaf1 ═══ jaringan IP ═══ Leaf2 ─ Host2
        VLAN 110       VXLAN       VLAN 110
```

Pada lab statis, alamat VTEP lawan dikonfigurasi secara manual. Anda akan mempelajari underlay OSPF, VTEP, VNI, VLAN-to-VNI mapping, dan VXLAN tunnel.

### 6.7 VXLAN EVPN — VXLAN yang lebih dinamis

VXLAN EVPN menggunakan BGP EVPN sebagai control plane untuk mendistribusikan informasi endpoint.

```text
             Spine1 / Spine2
          BGP EVPN Route Reflector
             /             \
          Leaf1           Leaf2
            │               │
          Host1           Host2
```

OSPF menyediakan konektivitas underlay. BGP EVPN mendistribusikan informasi MAC dan VNI. VXLAN membawa trafik sebagai data plane.

---

## 7. Cara belajar dari setiap modul

Gunakan pola berikut agar tidak sekadar melakukan copy-paste.

### Tahap 1 — Pahami tujuan

Sebelum mengetik perintah, jawab tiga pertanyaan:

1. topologi apa yang sedang dibuat;
2. perangkat mana yang saling terhubung;
3. hasil akhir apa yang diharapkan.

### Tahap 2 — Konfigurasi sedikit demi sedikit

Jangan menempel seluruh konfigurasi sekaligus. Selesaikan satu bagian, lalu lakukan validasi.

Contoh:

```text
Aktifkan interface
→ cek interface
→ pasang IP address
→ lakukan ping langsung
→ aktifkan protokol
→ cek neighbor
→ cek route
→ lakukan ping ujung ke ujung
```

### Tahap 3 — Baca output

Perintah `show` bukan hanya formalitas. Output tersebut digunakan untuk memastikan kondisi jaringan.

Contoh:

```text
show interface brief
show lldp neighbor-info
show vlan
show mac-address-table
show ip route
show ip ospf neighbors
```

### Tahap 4 — Buat kesalahan dengan sengaja

Setelah lab berhasil, coba salah satu skenario berikut:

- shutdown satu interface;
- ubah IP menjadi salah subnet;
- bedakan area OSPF pada kedua sisi;
- hapus VLAN dari salah satu switch;
- gunakan VNI yang berbeda;
- putus salah satu link redundan.

Kemudian cari penyebabnya menggunakan perintah validasi.

### Tahap 5 — Ulangi tanpa konfigurasi lengkap

Gunakan hanya gambar topologi dan tabel alamat. Jika berhasil membangun ulang lab, berarti Anda mulai memahami konsepnya.

---

## 8. Memahami mode CLI AOS-CX

Perintah AOS-CX harus dijalankan pada mode yang sesuai.

| Prompt | Sedang berada di mana? | Contoh perintah |
|---|---|---|
| `Switch#` | Mode operasional/privileged | `show`, `ping`, `configure terminal` |
| `Switch(config)#` | Konfigurasi global | `hostname`, `vlan`, `router ospf` |
| `Switch(config-if)#` | Konfigurasi interface fisik | `ip address`, `no routing`, `vlan access` |
| `Switch(config-loopback-if)#` | Konfigurasi interface loopback | `ip address`, `ip ospf` |
| `Switch(config-ospf-1)#` | Konfigurasi OSPF process 1 | `router-id`, `area` |
| `Switch(config-bgp)#` | Konfigurasi BGP | `neighbor`, `address-family` |

Contoh kesalahan umum:

```text
switch# hostname SwitchA
Invalid input: hostname
```

Penyebabnya: perintah `hostname` dijalankan dari mode yang salah.

Perbaikan:

```text
switch# configure terminal
switch(config)# hostname SwitchA
```

Gunakan `exit` untuk kembali satu tingkat dan `end` untuk kembali ke mode `Switch#`.

---

## 9. Pola validasi dasar

Setelah konfigurasi, jangan langsung menganggap jaringan sudah benar. Gunakan urutan berikut.

### Pemeriksaan Layer 1 dan topologi

```text
show interface brief
show lldp neighbor-info
```

Pertanyaan yang perlu dijawab:

- apakah interface sudah `up`;
- apakah port terhubung ke perangkat yang benar;
- apakah kabel virtual berada pada interface yang sesuai.

### Pemeriksaan Layer 2

```text
show vlan
show mac-address-table
show spanning-tree
show lacp interfaces
```

Pertanyaan yang perlu dijawab:

- apakah VLAN sudah dibuat;
- apakah port menjadi access atau trunk yang benar;
- apakah MAC address dipelajari;
- apakah ada port yang diblokir STP;
- apakah LAG sudah aktif.

### Pemeriksaan Layer 3

```text
show ip interface brief
show ip route
ping <alamat-tujuan>
```

Pertanyaan yang perlu dijawab:

- apakah IP dan prefix sudah benar;
- apakah jaringan tujuan ada di routing table;
- apakah next-hop dapat dijangkau.

### Pemeriksaan protokol

```text
show ip ospf neighbors
show bgp l2vpn evpn summary
show vsx status
show interface vxlan
```

Pertanyaan yang perlu dijawab:

- apakah neighbor sudah terbentuk;
- apakah status OSPF `FULL`;
- apakah status BGP `Established`;
- apakah VSX `In-Sync`;
- apakah VXLAN interface `up`.

---

## 10. Urutan troubleshooting untuk pemula

Ketika ping gagal atau neighbor tidak muncul, periksa dari lapisan paling bawah.

```text
1. Topologi dan kabel virtual benar?
        ↓
2. Interface sudah no shutdown dan berstatus up?
        ↓
3. Interface menggunakan mode L2 atau L3 yang sesuai?
        ↓
4. VLAN, IP address, dan prefix sudah benar?
        ↓
5. Perangkat yang terhubung langsung dapat saling ping?
        ↓
6. Konfigurasi protokol sama pada kedua sisi?
        ↓
7. Neighbor sudah terbentuk?
        ↓
8. Route atau MAC tujuan sudah masuk ke tabel?
        ↓
9. Ping ujung ke ujung berhasil?
```

Prinsip penting:

> **Jangan memeriksa OSPF jika interface dan ping ke perangkat yang terhubung langsung saja belum berhasil.**

---

## 11. Tanda bahwa sebuah lab berhasil

Gunakan indikator berikut sebagai target.

| Lab | Indikator keberhasilan |
|---|---|
| STP | Satu jalur redundan menjadi blocking dan jaringan tetap bebas loop. |
| Local MAC Match | Client terdeteksi dan role berhasil diterapkan. |
| VSX | ISL `In-Sync`, keepalive `Established`, dan MCLAG aktif. |
| OSPF Dasar | Neighbor berstatus `FULL` dan host ujung ke ujung dapat ping. |
| OSPF Areas | Route intra-area, inter-area, dan external dapat dibedakan. |
| Static VXLAN | VTEP peer aktif dan host pada VLAN yang sama dapat ping melalui VXLAN. |
| VXLAN EVPN | BGP EVPN `Established`, remote MAC dipelajari melalui EVPN, dan host dapat ping. |

---

## 12. Struktur paket

Repositori ini terdiri atas:

- satu file README sebagai peta belajar;
- tujuh file Markdown dengan nama yang mempertahankan judul PDF asal;
- folder `assets/` yang berisi gambar topologi;
- penjelasan berbahasa Indonesia;
- konfigurasi CLI asli AOS-CX;
- bagian validasi, troubleshooting, dan latihan pada setiap modul.

---

## 13. Ringkasan akhir

Materi ini tidak hanya mengajarkan perintah Aruba AOS-CX. Rangkaian lab dirancang agar pembaca memahami hubungan antarkonsep:

```text
Switching Layer 2
→ keamanan endpoint
→ redundansi
→ routing Layer 3
→ desain multi-area
→ overlay VXLAN
→ control plane BGP EVPN
```

Mulailah dari konsep yang paling dasar, kerjakan konfigurasi secara bertahap, dan selalu lakukan validasi sebelum melanjutkan ke tahap berikutnya.
