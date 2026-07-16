# Configuring OSPF on Aruba CX Switches

> **Panduan praktik berbahasa Indonesia**  
> Sumber: `AOS-CX Simulator - Deploying OSPF Lab Guide.pdf`  
> Tingkat: **Dasar — Routing OSPFv2**

## 1. Tujuan pembelajaran

Lab membangun jaringan empat switch dalam OSPF Area 0. HostA dan HostB berada pada subnet berbeda dan harus dapat saling berkomunikasi setelah OSPF terbentuk.

Setelah selesai, Anda mampu:

- mengonfigurasi routed interface, loopback, VLAN, dan SVI;
- membuat OSPF process dan router ID;
- membentuk adjacency point-to-point;
- membaca neighbor dan route OSPF;
- melakukan troubleshooting dari direct connectivity hingga end-to-end.

## 2. Topologi

![Topologi Configuring OSPF on Aruba CX Switches](assets/04_configuring_ospf_on_aruba_cx_switches_topology.jpg)

### Tabel alamat

| Perangkat | Interface | Alamat | Keterangan |
|---|---|---|---|
| SwitchA | `1/1/1` | `100.1.1.0/31` | ke SwitchB |
| SwitchB | `1/1/1` | `100.1.1.1/31` | ke SwitchA |
| SwitchA | `1/1/2` | `101.1.1.0/31` | ke SwitchC |
| SwitchC | `1/1/2` | `101.1.1.1/31` | ke SwitchA |
| SwitchB | `1/1/2` | `102.1.1.1/31` | ke SwitchD |
| SwitchD | `1/1/2` | `102.1.1.0/31` | ke SwitchB |
| SwitchC | `1/1/1` | `103.1.1.1/31` | ke SwitchD |
| SwitchD | `1/1/1` | `103.1.1.0/31` | ke SwitchC |
| SwitchA | Loopback0 | `1.1.1.1/32` | Router ID |
| SwitchB | Loopback0 | `2.2.2.2/32` | Router ID |
| SwitchC | Loopback0 | `3.3.3.3/32` | Router ID |
| SwitchD | Loopback0 | `4.4.4.4/32` | Router ID |
| SwitchA | VLAN 8 | `8.1.1.254/24` | gateway HostA |
| SwitchD | VLAN 7 | `7.1.1.254/24` | gateway HostB |
| HostA | eth0 | `8.1.1.1/24` | GW `8.1.1.254` |
| HostB | eth0 | `7.1.1.1/24` | GW `7.1.1.254` |

## 3. Konsep inti

| Konsep | Penjelasan |
|---|---|
| **OSPF** | Link-state IGP yang menghitung jalur menggunakan algoritma SPF. |
| **Router ID** | Identitas 32-bit unik. Lab memakai alamat loopback. |
| **Area 0** | Backbone area. Semua interface OSPF pada lab ini berada di Area 0. |
| **Adjacency FULL** | Dua router telah menyinkronkan LSDB. |
| **Point-to-point** | Network type untuk link langsung antarrouter tanpa pemilihan DR/BDR. |
| **Loopback** | Interface logis stabil yang cocok untuk router ID. |
| **/31** | Subnet dua alamat yang efisien untuk point-to-point link. |
| **ECMP** | Beberapa jalur dengan cost sama dapat masuk ke routing table. |

## 4. Tahap 1 — Konfigurasi host

HostA:

```text
ip 8.1.1.1/24 8.1.1.254
show ip
```

HostB:

```text
ip 7.1.1.1/24 7.1.1.254
show ip
```

Pada tahap ini HostA belum dapat ping HostB karena route antarsubnet belum ada.

## 5. Tahap 2 — Konfigurasi interface Layer 3

### SwitchA

```text
configure terminal
hostname SwitchA
vlan 8
 description HostA VLAN

interface 1/1/1
 no shutdown
 description To SwitchB
 ip address 100.1.1.0/31

interface 1/1/2
 no shutdown
 description To SwitchC
 ip address 101.1.1.0/31

interface 1/1/3
 no shutdown
 description Host Segment
 no routing
 vlan access 8

interface loopback 0
 ip address 1.1.1.1/32

interface vlan 8
 description To Host VLAN
 ip address 8.1.1.254/24
```

### SwitchB

```text
configure terminal
hostname SwitchB
interface 1/1/1
 no shutdown
 description To SwitchA
 ip address 100.1.1.1/31
interface 1/1/2
 no shutdown
 description To SwitchD
 ip address 102.1.1.1/31
interface loopback 0
 ip address 2.2.2.2/32
```

### SwitchC

```text
configure terminal
hostname SwitchC
interface 1/1/1
 no shutdown
 description To SwitchD
 ip address 103.1.1.1/31
interface 1/1/2
 no shutdown
 description To SwitchA
 ip address 101.1.1.1/31
interface loopback 0
 ip address 3.3.3.3/32
```

### SwitchD

```text
configure terminal
hostname SwitchD
vlan 7
 description HostB VLAN

interface 1/1/1
 no shutdown
 description To SwitchC
 ip address 103.1.1.0/31

interface 1/1/2
 no shutdown
 description To SwitchB
 ip address 102.1.1.0/31

interface 1/1/3
 no shutdown
 description HostB Segment
 no routing
 vlan access 7

interface loopback 0
 ip address 4.4.4.4/32

interface vlan 7
 description To Host segment
 ip address 7.1.1.254/24
```

## 6. Validasi direct connectivity

Sebelum OSPF, ping hanya alamat yang langsung terhubung.

Contoh dari SwitchA:

```text
ping 100.1.1.1
ping 101.1.1.1
```

Ping ke `2.2.2.2` atau jaringan di sisi SwitchD seharusnya masih gagal dengan `Network is unreachable`. Ini normal karena belum ada dynamic route.

Periksa:

```text
show interface brief
show ip route
show lldp neighbor-info
```

## 7. Tahap 3 — Mengaktifkan OSPF

### SwitchA

```text
router ospf 1
 router-id 1.1.1.1
 area 0.0.0.0

interface 1/1/1
 ip ospf 1 area 0.0.0.0
 ip ospf network point-to-point
interface 1/1/2
 ip ospf 1 area 0.0.0.0
 ip ospf network point-to-point
interface loopback 0
 ip ospf 1 area 0.0.0.0
interface vlan 8
 ip ospf 1 area 0.0.0.0
 ip ospf network point-to-point
```

### SwitchB

```text
router ospf 1
 router-id 2.2.2.2
 area 0.0.0.0
interface 1/1/1
 ip ospf 1 area 0.0.0.0
 ip ospf network point-to-point
interface 1/1/2
 ip ospf 1 area 0.0.0.0
 ip ospf network point-to-point
interface loopback 0
 ip ospf 1 area 0.0.0.0
```

### SwitchC

```text
router ospf 1
 router-id 3.3.3.3
 area 0.0.0.0
interface 1/1/1
 ip ospf 1 area 0.0.0.0
 ip ospf network point-to-point
interface 1/1/2
 ip ospf 1 area 0.0.0.0
 ip ospf network point-to-point
interface loopback 0
 ip ospf 1 area 0.0.0.0
```

### SwitchD

```text
router ospf 1
 router-id 4.4.4.4
 area 0.0.0.0
interface 1/1/1
 ip ospf 1 area 0.0.0.0
 ip ospf network point-to-point
interface 1/1/2
 ip ospf 1 area 0.0.0.0
 ip ospf network point-to-point
interface loopback 0
 ip ospf 1 area 0.0.0.0
interface vlan 7
 ip ospf 1 area 0.0.0.0
 ip ospf network point-to-point
```

## 8. Memvalidasi neighbor

```text
show ip ospf neighbors
```

Jumlah neighbor yang diharapkan:

| Switch | Neighbor |
|---|---|
| SwitchA | SwitchB dan SwitchC |
| SwitchB | SwitchA dan SwitchD |
| SwitchC | SwitchA dan SwitchD |
| SwitchD | SwitchB dan SwitchC |

Semua neighbor harus berada pada state `FULL`.

## 9. Memvalidasi route

```text
show ip ospf route
show ip route ospf
```

Periksa bahwa:

- loopback remote muncul;
- subnet host remote muncul;
- kemungkinan ada dua jalur cost sama menuju jaringan tertentu;
- next hop dan outgoing interface masuk akal sesuai topology.

## 10. Uji end-to-end

Dari HostA:

```text
ping 7.1.1.1
```

Dari HostB:

```text
ping 8.1.1.1
```

TTL sekitar 61 pada contoh menunjukkan paket melewati beberapa hop router.

## 11. Urutan troubleshooting OSPF

```text
1. show interface brief
2. ping alamat direct neighbor
3. show ip ospf interface <port>
4. show ip ospf neighbors
5. show ip ospf route
6. show ip route
7. ping dari switch
8. ping dari host
```

| Gejala | Penyebab umum |
|---|---|
| Neighbor tidak muncul | IP/subnet salah, interface down, OSPF belum diaktifkan. |
| State tidak FULL | Area, network type, timer, atau MTU tidak cocok. |
| Neighbor FULL tetapi route host tidak ada | SVI host belum dimasukkan ke OSPF. |
| Route ada tetapi host tidak bisa ping | Gateway host salah, access VLAN salah, atau interface host down. |
| `hostname` invalid | Belum masuk `configure terminal`. |

## 12. Checklist keberhasilan

- [ ] Semua direct link dapat saling ping.
- [ ] Router ID unik.
- [ ] Setiap switch memiliki dua neighbor FULL.
- [ ] Loopback dan subnet remote masuk routing table.
- [ ] HostA dan HostB saling ping.

## 13. Pertanyaan latihan

1. Mengapa loopback dipakai sebagai router ID?
2. Mengapa link /31 cocok untuk point-to-point?
3. Apa perbedaan connected route dan OSPF route?
4. Mengapa adjacency FULL belum otomatis menjamin host dapat berkomunikasi?
5. Interface apa yang harus diiklankan agar jaringan HostA terlihat dari SwitchD?

## 14. Ringkasan perintah

```text
router ospf 1
 router-id <alamat-loopback>
 area 0.0.0.0
interface <port>
 ip ospf 1 area 0.0.0.0
 ip ospf network point-to-point
show ip ospf neighbors
show ip ospf route
show ip ospf interface <port>
show ip route ospf
```
