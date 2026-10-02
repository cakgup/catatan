# Static VXLAN

> **Panduan praktik berbahasa Indonesia**  
> Sumber: `AOS-CX Simulator - Static VXLAN Lab Guide.pdf`  
> Tingkat: **Menengah — VXLAN Data Plane**

## 1. Tujuan pembelajaran

Lab membangun konektivitas Layer 2 antara dua host yang berada pada leaf berbeda menggunakan VXLAN statis.

Setelah selesai, Anda mampu:

- membedakan underlay dan overlay;
- membangun underlay OSPF;
- menggunakan loopback sebagai VTEP source;
- memetakan VLAN ke VNI;
- mengonfigurasi static VTEP peer;
- membaca MAC lokal dan MAC remote melalui VXLAN.

## 2. Topologi

![Topologi Static VXLAN](assets/06_static_vxlan_topology.jpg)

### Perangkat dan alamat loopback

| Perangkat | Loopback0 |
|---|---|
| Spine1 | `192.168.2.1/32` |
| Spine2 | `192.168.2.2/32` |
| Leaf1 | `192.168.2.3/32` |
| Leaf2 | `192.168.2.4/32` |

### Link underlay

| Link | Alamat |
|---|---|
| Spine1–Leaf1 | `192.168.4.0/31` dan `192.168.4.1/31` |
| Spine1–Leaf2 | `192.168.4.2/31` dan `192.168.4.3/31` |
| Spine2–Leaf1 | `192.168.4.4/31` dan `192.168.4.5/31` |
| Spine2–Leaf2 | `192.168.4.6/31` dan `192.168.4.7/31` |

### Overlay

| Komponen | Nilai |
|---|---|
| VLAN endpoint | VLAN 110 |
| VNI | 110 |
| Leaf1 VTEP | `192.168.2.3` |
| Leaf2 VTEP | `192.168.2.4` |
| Host1 | `10.0.110.1/24` |
| Host2 | `10.0.110.2/24` |

## 3. Mental model

```text
Host1 mengirim frame Ethernet
        ↓ VLAN 110
Leaf1 menambahkan header VXLAN, VNI 110
        ↓ paket IP/UDP melalui underlay OSPF
Leaf2 membuka encapsulation VXLAN
        ↓ VLAN 110
Host2 menerima frame asli
```

- **Underlay** hanya perlu mampu merutekan alamat VTEP.
- **Overlay** membawa segment Layer 2 di atas jaringan IP.
- Static VXLAN menggunakan konfigurasi peer manual dan flood-and-learn untuk MAC.

## 4. Tahap 1 — Konfigurasi dasar

Pada seluruh switch:

```text
configure terminal
hostname <nama>
interface 1/1/1-1/1/6
 no shutdown
exit
show lldp neighbor-info
```

Pastikan hubungan port sesuai gambar sebelum memberi alamat IP.

## 5. Tahap 2 — Membangun underlay OSPF

### Leaf1

```text
interface loopback 0
 ip address 192.168.2.3/32
 ip ospf 1 area 0
router ospf 1
 router-id 192.168.2.3
interface 1/1/2
 ip address 192.168.4.1/31
 ip ospf 1 area 0
 ip ospf network point-to-point
interface 1/1/3
 ip address 192.168.4.5/31
 ip ospf 1 area 0
 ip ospf network point-to-point
```

### Leaf2

```text
interface loopback 0
 ip address 192.168.2.4/32
 ip ospf 1 area 0
router ospf 1
 router-id 192.168.2.4
interface 1/1/2
 ip address 192.168.4.3/31
 ip ospf 1 area 0
 ip ospf network point-to-point
interface 1/1/3
 ip address 192.168.4.7/31
 ip ospf 1 area 0
 ip ospf network point-to-point
```

### Spine1

```text
interface loopback 0
 ip address 192.168.2.1/32
 ip ospf 1 area 0
router ospf 1
 router-id 192.168.2.1
interface 1/1/2
 ip address 192.168.4.0/31
 ip ospf 1 area 0
 ip ospf network point-to-point
interface 1/1/1
 ip address 192.168.4.2/31
 ip ospf 1 area 0
 ip ospf network point-to-point
```

### Spine2

```text
interface loopback 0
 ip address 192.168.2.2/32
 ip ospf 1 area 0
router ospf 1
 router-id 192.168.2.2
interface 1/1/2
 ip address 192.168.4.4/31
 ip ospf 1 area 0
 ip ospf network point-to-point
interface 1/1/1
 ip address 192.168.4.6/31
 ip ospf 1 area 0
 ip ospf network point-to-point
```

## 6. Validasi underlay

Pada Leaf1:

```text
show ip ospf neighbors
show ip route ospf
ping 192.168.2.4
```

Harus terlihat dua neighbor FULL, yaitu Spine1 dan Spine2. Route ke loopback Leaf2 dapat memiliki dua next hop ECMP. Guide mencatat AOS-CX VM tertentu tidak benar-benar meneruskan ECMP seperti hardware fisik.

> Jangan mengonfigurasi VXLAN sebelum ping antar-VTEP berhasil.

## 7. Tahap 3 — Menyiapkan VLAN endpoint

Leaf1:

```text
vlan 110
interface 1/1/1
 no routing
 vlan access 110
```

Leaf2:

```text
vlan 110
interface 1/1/1
 no routing
 vlan access 110
```

## 8. Tahap 4 — Mengonfigurasi VXLAN statis

Leaf1:

```text
interface vxlan 1
 source ip 192.168.2.3
 no shutdown
 vni 110
  vlan 110
  vtep-peer 192.168.2.4
```

Leaf2:

```text
interface vxlan 1
 source ip 192.168.2.4
 no shutdown
 vni 110
  vlan 110
  vtep-peer 192.168.2.3
```

Arti perintah:

| Perintah | Fungsi |
|---|---|
| `interface vxlan 1` | Membuat interface VXLAN logis. |
| `source ip` | Menentukan alamat VTEP lokal. |
| `vni 110` | Membuat segment overlay VNI 110. |
| `vlan 110` | Memetakan VLAN 110 ke VNI 110. |
| `vtep-peer` | Menentukan VTEP remote secara manual. |

## 9. Validasi VXLAN

```text
show interface vxlan
```

Target pada Leaf1:

```text
Interface vxlan1 is up
VTEP source IPv4 address: 192.168.2.3
VNI 110  VLAN 110  VTEP Peer 192.168.2.4  Origin static
```

Bila interface admin up tetapi peer tidak bekerja, periksa ping ke remote VTEP.

## 10. Tahap 5 — Konfigurasi host

Host1:

```text
ip 10.0.110.1/24 10.0.110.254
```

Host2:

```text
ip 10.0.110.2/24 10.0.110.254
```

Gateway `.254` tidak tersedia pada lab L2 VXLAN; nilai tersebut hanya diisi karena VPCS meminta gateway.

Uji:

```text
# Dari Host1
ping 10.0.110.2
```

## 11. Membaca MAC table

Pada Leaf1:

```text
show mac-address-table
```

Pola yang diharapkan:

```text
MAC Host1  VLAN 110  dynamic  1/1/1
MAC Host2  VLAN 110  dynamic  vxlan1(192.168.2.4)
```

Ini membuktikan:

- MAC lokal dipelajari dari physical access port;
- MAC remote dipelajari melalui VXLAN tunnel.

## 12. Packet capture

Bila EVE-NG/GNS3 mendukung capture, ambil paket pada uplink Leaf1. Filter Wireshark:

```text
udp.port == 4789
```

Yang dapat diamati:

- outer source IP = VTEP Leaf1;
- outer destination IP = VTEP Leaf2;
- UDP destination port = 4789;
- VXLAN VNI = 110;
- inner Ethernet frame tetap membawa MAC Host1 dan Host2.

## 13. Checklist keberhasilan

- [ ] OSPF neighbor FULL.
- [ ] Leaf1 dapat ping loopback Leaf2.
- [ ] VLAN 110 tersedia pada kedua leaf.
- [ ] VTEP source menggunakan loopback masing-masing.
- [ ] VNI 110 dipetakan ke VLAN 110.
- [ ] Static peer muncul pada `show interface vxlan`.
- [ ] Host1 dapat ping Host2.
- [ ] MAC remote muncul melalui `vxlan1`.

## 14. Troubleshooting berlapis

### A. Underlay

```text
show interface brief
show ip ospf neighbors
show ip route ospf
ping <remote-vtep>
```

### B. Overlay

```text
show interface vxlan
show running-config interface vxlan 1
show vlan
```

### C. Endpoint

```text
show mac-address-table
show running-config interface 1/1/1
```

| Gejala | Penyebab umum |
|---|---|
| Remote VTEP tidak bisa diping | OSPF/interface/IP underlay bermasalah. |
| VXLAN up, host gagal ping | VLAN/VNI tidak sama atau access port salah. |
| MAC remote tidak muncul | Tidak ada trafik, peer salah, atau tunnel tidak reachable. |
| Hanya satu uplink membawa trafik | Keterbatasan ECMP pada simulator. |

## 15. Pertanyaan latihan

1. Mengapa alamat loopback cocok sebagai VTEP source?
2. Apa yang terjadi bila VLAN 110 dipetakan ke VNI berbeda pada Leaf2?
3. Apa kekurangan konfigurasi static VTEP peer ketika jumlah leaf bertambah?
4. Apa perbedaan inner Ethernet dan outer IP header?
5. Mengapa OSPF tidak perlu mengetahui subnet `10.0.110.0/24` pada lab L2 VXLAN?

## 16. Ringkasan perintah

```text
show ip ospf neighbors
show ip route ospf
interface vxlan 1
 source ip <loopback>
 vni 110
  vlan 110
  vtep-peer <remote-loopback>
show interface vxlan
show mac-address-table
```
