# VXLAN EVPN

> **Panduan praktik berbahasa Indonesia**  
> Sumber: `AOS-CX Switch Simulator - VXLAN EVPN Lab Guide.pdf`  
> Tingkat: **Lanjutan — BGP EVPN Control Plane**

## 1. Tujuan pembelajaran

Lab ini menggunakan topologi yang sama dengan Static VXLAN, tetapi peer dan informasi endpoint dipelajari melalui BGP EVPN.

Setelah selesai, Anda mampu:

- membangun OSPF underlay;
- membuat iBGP EVPN session melalui loopback;
- menggunakan spine sebagai route reflector;
- mengonfigurasi RD dan route target;
- memetakan VLAN ke VNI;
- membaca EVPN Type 2 dan Type 3 route;
- membedakan control plane EVPN dengan VXLAN data plane.

## 2. Topologi

![Topologi VXLAN EVPN](assets/07_vxlan_evpn_topology.jpg)

Alamat underlay sama dengan lab Static VXLAN:

| Perangkat | Loopback / Router ID |
|---|---|
| Spine1 | `192.168.2.1/32` |
| Spine2 | `192.168.2.2/32` |
| Leaf1 | `192.168.2.3/32` |
| Leaf2 | `192.168.2.4/32` |

BGP menggunakan AS yang sama pada seluruh perangkat:

```text
AS 65001
```

Spine1 dan Spine2 menjadi route reflector. Leaf1 dan Leaf2 menjadi RR client.

## 3. Mental model

```text
OSPF underlay
  memastikan semua loopback saling reachable
            ↓
iBGP EVPN control plane
  menyebarkan membership VNI dan MAC endpoint
            ↓
VXLAN data plane
  mengirim frame aktual melalui UDP 4789
```

Perbandingan dengan Static VXLAN:

| Static VXLAN | VXLAN EVPN |
|---|---|
| Peer VTEP diketik manual | Peer dipelajari melalui EVPN |
| Flood-and-learn dominan | MAC/IP didistribusikan control plane |
| Sulit diskalakan | Lebih mudah diskalakan |
| Tidak perlu BGP | Memerlukan BGP EVPN |

## 4. Istilah penting

| Istilah | Penjelasan |
|---|---|
| **BGP EVPN** | Address family BGP untuk mendistribusikan informasi Ethernet/VXLAN. |
| **Route Reflector** | Memantulkan route iBGP agar leaf tidak perlu full mesh. |
| **RD** | Membuat route EVPN unik. Bukan kebijakan import/export. |
| **Route Target** | Extended community yang mengatur route mana di-export dan di-import. |
| **Type 2** | MAC/IP Advertisement Route. |
| **Type 3** | Inclusive Multicast Ethernet Tag Route; mengumumkan partisipasi VTEP dalam VNI. |
| **VTEP** | Endpoint tunnel VXLAN pada leaf. |

## 5. Tahap 1 — Membangun OSPF underlay

Gunakan konfigurasi underlay yang sama dengan Static VXLAN.

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

Validasi wajib:

```text
show ip ospf neighbors
show ip route ospf
ping <setiap-loopback-remote>
```

BGP melalui loopback tidak akan terbentuk bila underlay belum sehat.

## 6. Tahap 2 — Konfigurasi spine sebagai route reflector

### Spine1

```text
router bgp 65001
 bgp router-id 192.168.2.1
 neighbor 192.168.2.3 remote-as 65001
 neighbor 192.168.2.3 update-source loopback 0
 neighbor 192.168.2.4 remote-as 65001
 neighbor 192.168.2.4 update-source loopback 0
 address-family l2vpn evpn
  neighbor 192.168.2.3 activate
  neighbor 192.168.2.3 route-reflector-client
  neighbor 192.168.2.3 send-community extended
  neighbor 192.168.2.4 activate
  neighbor 192.168.2.4 route-reflector-client
  neighbor 192.168.2.4 send-community extended
```

### Spine2

```text
router bgp 65001
 bgp router-id 192.168.2.2
 neighbor 192.168.2.3 remote-as 65001
 neighbor 192.168.2.3 update-source loopback 0
 neighbor 192.168.2.4 remote-as 65001
 neighbor 192.168.2.4 update-source loopback 0
 address-family l2vpn evpn
  neighbor 192.168.2.3 activate
  neighbor 192.168.2.3 route-reflector-client
  neighbor 192.168.2.3 send-community extended
  neighbor 192.168.2.4 activate
  neighbor 192.168.2.4 route-reflector-client
  neighbor 192.168.2.4 send-community extended
```

Mengapa `send-community extended` penting? Route target dibawa sebagai BGP extended community. Tanpa itu, kebijakan import/export EVPN tidak bekerja sebagaimana diharapkan.

## 7. Tahap 3 — Konfigurasi leaf sebagai RR client

### Leaf1

```text
router bgp 65001
 bgp router-id 192.168.2.3
 neighbor 192.168.2.1 remote-as 65001
 neighbor 192.168.2.1 update-source loopback 0
 neighbor 192.168.2.2 remote-as 65001
 neighbor 192.168.2.2 update-source loopback 0
 address-family l2vpn evpn
  neighbor 192.168.2.1 activate
  neighbor 192.168.2.1 send-community extended
  neighbor 192.168.2.2 activate
  neighbor 192.168.2.2 send-community extended
```

### Leaf2

```text
router bgp 65001
 bgp router-id 192.168.2.4
 neighbor 192.168.2.1 remote-as 65001
 neighbor 192.168.2.1 update-source loopback 0
 neighbor 192.168.2.2 remote-as 65001
 neighbor 192.168.2.2 update-source loopback 0
 address-family l2vpn evpn
  neighbor 192.168.2.1 activate
  neighbor 192.168.2.1 send-community extended
  neighbor 192.168.2.2 activate
  neighbor 192.168.2.2 send-community extended
```

Validasi:

```text
show bgp l2vpn evpn summary
```

Pada setiap leaf, kedua spine harus berstatus `Established`.

## 8. Tahap 4 — Membuat VLAN dan EVPN instance

Pada Leaf1 dan Leaf2:

```text
vlan 110

evpn
 vlan 110
  rd auto
  route-target export auto
  route-target import auto
```

- `rd auto` membuat RD berdasarkan router/VLAN.
- RT export menandai route yang dikirim.
- RT import menentukan route mana yang diterima.
- Karena seluruh leaf menggunakan pola auto yang kompatibel, VNI/VLAN yang sama dapat saling bertukar route.

## 9. Tahap 5 — Membuat VXLAN interface

Leaf1:

```text
interface 1/1/1
 no routing
 vlan access 110

interface vxlan 1
 source ip 192.168.2.3
 no shutdown
 vni 110
  vlan 110
```

Leaf2:

```text
interface 1/1/1
 no routing
 vlan access 110

interface vxlan 1
 source ip 192.168.2.4
 no shutdown
 vni 110
  vlan 110
```

Perhatikan tidak ada `vtep-peer` statis. Remote VTEP ditemukan melalui EVPN Type 3 route.

Validasi:

```text
show interface vxlan
```

Pada Leaf1 peer `192.168.2.4` seharusnya muncul dengan origin `evpn`.

## 10. Tahap 6 — Konfigurasi host

Host1:

```text
ip 10.0.110.1/24 10.0.110.254
```

Host2:

```text
ip 10.0.110.2/24 10.0.110.254
```

Uji:

```text
ping 10.0.110.2
```

## 11. Membaca hasil EVPN

### BGP summary

```text
show bgp l2vpn evpn summary
```

Pastikan state `Established`, bukan `Active`, `Idle`, atau angka prefix yang kosong karena session belum terbentuk.

### EVPN route table

```text
show bgp l2vpn evpn
```

Cari:

- Type 3 dari Leaf1 dan Leaf2 sebagai tanda keduanya berpartisipasi pada VNI 110;
- Type 2 untuk MAC endpoint setelah host menghasilkan trafik.

### MAC table

```text
show mac-address-table
```

Pada Leaf1:

```text
MAC Host1 → dynamic pada 1/1/1
MAC Host2 → evpn melalui vxlan1(192.168.2.4)
```

Perbedaan penting dengan static VXLAN: MAC remote dapat bertipe `evpn`, karena informasi datang melalui control plane.

## 12. Urutan troubleshooting tiga lapis

### Lapisan 1 — Underlay

```text
show ip ospf neighbors
show ip route ospf
ping <loopback-spine/leaf>
```

### Lapisan 2 — BGP EVPN control plane

```text
show bgp l2vpn evpn summary
show bgp l2vpn evpn
show running-config router bgp
```

### Lapisan 3 — VXLAN data plane dan endpoint

```text
show interface vxlan
show mac-address-table
show vlan
```

| State/gejala | Kemungkinan penyebab |
|---|---|
| BGP `Idle` | Neighbor belum aktif, AS salah, atau konfigurasi incomplete. |
| BGP `Active` | TCP ke neighbor gagal; biasanya underlay/route loopback bermasalah. |
| Established tetapi tidak ada EVPN route | Address family belum aktif, RT/RD/VLAN belum dibuat. |
| Type 3 ada, Type 2 tidak ada | Belum ada trafik dari endpoint atau MAC belum dipelajari. |
| Type 2 ada, host gagal ping | VLAN/VNI/access port atau data-plane VXLAN bermasalah. |
| RT tidak tersebar | `send-community extended` belum dikonfigurasi. |

## 13. Packet capture

Filter Wireshark:

```text
bgp || udp.port == 4789
```

- BGP EVPN control plane berjalan pada TCP 179.
- VXLAN data plane berjalan pada UDP 4789.
- Tidak setiap uplink simulator menunjukkan trafik karena keterbatasan ECMP VM.

## 14. Checklist keberhasilan

- [ ] Semua OSPF neighbor FULL.
- [ ] Semua loopback dapat diping.
- [ ] Dua EVPN neighbor pada setiap leaf Established.
- [ ] VLAN 110 memiliki RD dan RT.
- [ ] VNI 110 dipetakan ke VLAN 110.
- [ ] Remote VTEP muncul dengan origin EVPN.
- [ ] EVPN Type 3 muncul sebelum/ketika VNI aktif.
- [ ] EVPN Type 2 muncul setelah MAC dipelajari.
- [ ] Host1 dan Host2 saling ping.

## 15. Pertanyaan latihan

1. Mengapa route reflector diperlukan pada iBGP skala besar?
2. Apa perbedaan fungsi RD dan route target?
3. Mengapa `send-community extended` penting?
4. Route type apa yang membawa MAC endpoint?
5. Route type apa yang membantu discovery partisipasi VTEP pada VNI?
6. Apa yang tetap dilakukan OSPF meskipun EVPN sudah digunakan?
7. Mengapa EVPN disebut control plane sedangkan VXLAN disebut data plane?

## 16. Ringkasan perintah

```text
show ip ospf neighbors
show ip route ospf
show bgp l2vpn evpn summary
show bgp l2vpn evpn
show interface vxlan
show mac-address-table
```
