# AOS-CX Lab Guides

Download PNETLab https://pnetlab.com/pages/download
Paket ini berisi tujuh panduan praktik Aruba AOS-CX yang sudah ditulis ulang sebagai **modul belajar berbahasa Indonesia**. Judul asli setiap panduan tetap dipertahankan agar mudah dicocokkan dengan PDF sumber.

> **Catatan penting:** sintaks CLI tetap menggunakan bahasa asli perangkat. Yang diterjemahkan adalah tujuan, konsep, langkah kerja, cara membaca output, dan troubleshooting.

## Urutan belajar yang disarankan

| Urutan | Panduan | Fokus |
|---:|---|---|
| 1 | [Deploying basic STP](<AOS-CX Simulator Lab - Spanning Tree Basics Lab Guide.md>) | Dasar switching Layer 2 dan pencegahan loop |
| 2 | [Local MAC Match Authentication](<AOS-CX Simulator - Local Mac Authentication Lab Guide.md>) | Pengenalan endpoint dan pemberian role berdasarkan MAC |
| 3 | [VSX Lab1 - Layer2](<AOS-CX Simulator - VSX Part 1 Lab Guide.md>) | Redundansi dua switch, ISL, keepalive, dan MCLAG |
| 4 | [Configuring OSPF on Aruba CX Switches](<AOS-CX Simulator - Deploying OSPF Lab Guide.md>) | Routing OSPF satu area |
| 5 | [Deploying OSPFv2 Areas](<AOS-CX Switch Simulator - OSPFv2 Areas Basics Lab Guide.md>) | Multi-area, ABR, ASBR, redistribution, stub, NSSA |
| 6 | [Static VXLAN](<AOS-CX Simulator - Static VXLAN Lab Guide.md>) | Underlay OSPF dan overlay VXLAN statis |
| 7 | [VXLAN EVPN](<AOS-CX Switch Simulator - VXLAN EVPN Lab Guide.md>) | BGP EVPN sebagai control plane VXLAN |

### Jalur tercepat menuju VXLAN EVPN

```text
STP → OSPF Dasar → OSPF Areas → Static VXLAN → VXLAN EVPN
```

Local MAC Match Authentication dan VSX tetap penting, tetapi merupakan cabang khusus untuk **network access control** dan **high availability**.

## Cara menggunakan setiap modul

1. Baca bagian **Gambaran Besar** agar memahami apa yang sedang dibangun.
2. Pelajari **Istilah Penting** sebelum mengetik konfigurasi.
3. Salin tabel alamat dan interface ke catatan pribadi.
4. Kerjakan konfigurasi **per tahap**, bukan sekaligus.
5. Jalankan validasi setelah setiap tahap.
6. Bila gagal, ikuti urutan troubleshooting dari lapisan paling bawah.
7. Setelah berhasil, ulangi tanpa melihat konfigurasi lengkap.

## Memahami mode CLI AOS-CX

| Prompt | Arti | Contoh perintah |
|---|---|---|
| `Switch#` | Privileged/enable mode | `show`, `ping`, `configure terminal` |
| `Switch(config)#` | Global configuration | `hostname`, `vlan`, `router ospf` |
| `Switch(config-if)#` | Konfigurasi interface fisik | `ip address`, `no routing`, `vlan access` |
| `Switch(config-loopback-if)#` | Konfigurasi loopback | `ip address` |
| `Switch(config-ospf-1)#` | Konfigurasi proses OSPF | `router-id`, `area` |
| `Switch(config-bgp)#` | Konfigurasi BGP | `neighbor`, `address-family` |

Contoh:

```text
switch# configure terminal
switch(config)# hostname SwitchA
SwitchA(config)# interface 1/1/1
SwitchA(config-if)# no shutdown
```

Jika `hostname` ditolak saat prompt masih `switch#`, penyebabnya adalah perintah dijalankan pada mode yang salah.

## Pola validasi umum

```text
show interface brief
show lldp neighbor-info
show running-config
show vlan
show mac-address-table
show ip route
ping <alamat-tujuan>
```

Urutan troubleshooting yang aman:

```text
Topologi/kabel
→ status interface
→ mode L2/L3
→ VLAN atau alamat IP
→ protokol control plane
→ tabel forwarding/routing
→ konektivitas ujung ke ujung
```

## Struktur paket

- Tujuh file Markdown dengan nama file yang mempertahankan nama PDF asal.
- Folder `assets/` berisi gambar topologi.
- Seluruh materi ditulis ulang sebagai panduan belajar, bukan sekadar transkrip bahasa Inggris.
