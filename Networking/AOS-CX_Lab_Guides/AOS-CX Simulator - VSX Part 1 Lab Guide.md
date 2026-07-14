# VSX Lab1 - Layer2

> **Panduan praktik berbahasa Indonesia**  
> Sumber: `AOS-CX Simulator - VSX Part 1 Lab Guide.pdf`  
> Tingkat: **Menengah — High Availability Layer 2**

## 1. Tujuan pembelajaran

Setelah menyelesaikan lab, Anda mampu:

- membentuk pasangan VSX primary dan secondary;
- membedakan ISL dan keepalive;
- membangun downstream multi-chassis LAG;
- melakukan sinkronisasi konfigurasi;
- menguji failover link dan kondisi VSX split;
- membaca status VSX, LACP, dan MCLAG.

## 2. Gambaran besar

![Topologi VSX Lab1 - Layer2](assets/03_vsx_lab1_layer2_topology.jpg)

| Perangkat | Peran |
|---|---|
| SW1 | VSX primary |
| SW2 | VSX secondary |
| SW3 | Access switch untuk HostA |
| SW4 | Access switch untuk HostB |
| HostA | `10.10.100.11/24` |
| HostB | `10.10.100.12/24` |

### Hubungan penting

| Fungsi | Port/link |
|---|---|
| Keepalive SW1–SW2 | `1/1/7`, jaringan `192.168.0.0/31` |
| ISL SW1–SW2 | `1/1/8` dan `1/1/9` dalam `lag 256` |
| MCLAG menuju SW3 | `lag 1` |
| MCLAG menuju SW4 | `lag 2` |
| VLAN endpoint | VLAN 100 |

### Perbedaan ISL dan keepalive

- **ISL** membawa sinkronisasi state dan trafik yang perlu melintasi pasangan VSX.
- **Keepalive** digunakan untuk mendeteksi kondisi peer ketika ISL gagal dan membantu mencegah split-brain.
- Keepalive tidak menggantikan ISL.

## 3. Prasyarat dan catatan simulator

1. SW1 dan SW2 harus menggunakan versi firmware yang sama:

```text
show version
```

2. Simulator dapat memiliki keterbatasan terhadap status link fisik. Untuk failure test, kadang perlu shutdown kedua ujung link atau memakai `lacp rate fast`.
3. Setelah switch virtual dengan VSX LAG direstart, forwarding kadang tidak pulih otomatis. Solusi umum: lepaskan port dari LAG, shutdown/no shutdown, lalu masukkan kembali port ke LAG.

## 4. Tahap 1 — Konfigurasi dasar

Contoh SW1:

```text
configure terminal
hostname SW1
vlan 1
interface 1/1/1
 no shutdown
 description to SW3
interface 1/1/2
 no shutdown
 description to SW4
interface 1/1/7
 no shutdown
 description keepalive link
interface 1/1/8
 no shutdown
 description ISL link
interface 1/1/9
 no shutdown
 description ISL link
```

SW2 menggunakan pola yang sama. Pada SW3 dan SW4, aktifkan port host `1/1/1` dan uplink `1/1/8-1/1/9`.

Validasi:

```text
show lldp neighbor-info
```

SW1 dan SW2 seharusnya melihat lima neighbor entry: tiga link ke peer VSX dan masing-masing satu link ke SW3 serta SW4.

## 5. Tahap 2 — Membuat ISL LAG

Lakukan pada SW1 dan SW2:

```text
interface lag 256
 no shutdown
 description ISL
 no routing
 vlan trunk allowed all
 lacp mode active

interface 1/1/8
 no shutdown
 mtu 9198
 description ISL link
 lag 256

interface 1/1/9
 no shutdown
 mtu 9198
 description ISL link
 lag 256
```

Validasi:

```text
show interface lag 256
show lacp interfaces
```

Kondisi ideal:

- `Aggregate lag256 is up`;
- kedua port menjadi anggota LAG;
- flag LACP memuat `NCD`: InSync, Collecting, Distributing.

## 6. Tahap 3 — Menyiapkan keepalive

Buat VRF khusus pada SW1 dan SW2:

```text
vrf KA
```

SW1:

```text
interface 1/1/7
 no shutdown
 vrf attach KA
 description VSX keepalive
 ip address 192.168.0.0/31
```

SW2:

```text
interface 1/1/7
 no shutdown
 vrf attach KA
 description VSX keepalive
 ip address 192.168.0.1/31
```

Uji sebelum membentuk VSX:

```text
# Dari SW1
ping 192.168.0.1 vrf KA

# Dari SW2
ping 192.168.0.0 vrf KA
```

Jangan lanjut bila ping keepalive belum berhasil.

## 7. Tahap 4 — Membentuk cluster VSX

SW1:

```text
vsx
 system-mac 02:01:00:00:01:00
 inter-switch-link lag 256
 role primary
 vsx-sync vsx-global
```

SW2:

```text
vsx
 inter-switch-link lag 256
 role secondary
```

Setelah sinkronisasi, system MAC dan `vsx-global` akan terlihat pada kedua switch.

Validasi:

```text
show vsx status
show vsx brief
```

Pada tahap ini ISL seharusnya `In-Sync`, tetapi keepalive mungkin masih `Keepalive-Init`.

## 8. Tahap 5 — Mengaktifkan VSX keepalive

SW1:

```text
vsx
 keepalive peer 192.168.0.1 source 192.168.0.0 vrf KA
```

SW2:

```text
vsx
 keepalive peer 192.168.0.0 source 192.168.0.1 vrf KA
```

Validasi:

```text
show vsx brief
show vsx status keepalive
```

Target:

```text
ISL State       : In-Sync
Device State    : Peer-Established
Keepalive State : Keepalive-Established
```

## 9. Tahap 6 — Konfigurasi synchronization

Pada primary, aktifkan kelompok sinkronisasi yang diperlukan. Contoh sesuai guide:

```text
vsx
 vsx-sync aaa acl-log-timer bfd-global bgp control-plane-acls \
 copp-policy dhcp-relay dhcp-server dhcp-snooping dns icmp-tcp \
 lldp loop-protect-global mac-lockout mclag-interfaces neighbor \
 ospf qos-global route-map sflow-global snmp ssh stp-global time \
 vsx-global
```

Pada CLI nyata, masukkan perintah sebagai satu baris; tanda `\` di atas hanya untuk memudahkan pembacaan Markdown.

Validasi:

```text
show vsx status config-sync
show running-config vsx-sync
```

Target `Operational State : Operational` dan `Error State : None`.

## 10. Tahap 7 — Split recovery dan linkup delay

Guide merekomendasikan mempertahankan nilai default:

```text
show vsx configuration split-recovery
show vsx status linkup-delay
```

- Split recovery default: enabled.
- Linkup delay default contoh: 180 detik.

Linkup delay memberi waktu sinkronisasi sebelum MCLAG diaktifkan kembali setelah cluster join.

## 11. Tahap 8 — Membuat VLAN 100

Konfigurasikan pada primary:

```text
vlan 100
 vsx-sync
```

Validasi pada secondary:

```text
show vlan
show running-config vsx-sync
```

VLAN 100 harus muncul otomatis pada SW2.

## 12. Tahap 9 — Membuat downstream MCLAG

SW1:

```text
interface lag 1 multi-chassis
 description SW3 VSX LAG
 no shutdown
 vlan trunk allowed 100

interface 1/1/1
 no shutdown
 mtu 9100
 description to SW3
 lag 1

interface lag 2 multi-chassis
 description SW4 VSX LAG
 no shutdown
 vlan trunk allowed 100

interface 1/1/2
 no shutdown
 mtu 9100
 description to SW4
 lag 2
```

SW2 membuat LAG multi-chassis dengan ID yang sama dan memasukkan port lokal:

```text
interface lag 1 multi-chassis
 no shutdown
interface 1/1/1
 no shutdown
 mtu 9100
 description to SW3
 lag 1

interface lag 2 multi-chassis
 no shutdown
interface 1/1/2
 no shutdown
 mtu 9100
 description to SW4
 lag 2
```

## 13. Tahap 10 — Konfigurasi SW3 dan SW4

Lakukan pada masing-masing access switch:

```text
vlan 100

interface lag 1
 no shutdown
 no routing
 vlan trunk native 1
 vlan trunk allowed 100
 lacp mode active

interface 1/1/8
 no shutdown
 description to SW1
 lag 1

interface 1/1/9
 no shutdown
 description to SW2
 lag 1

interface 1/1/1
 no shutdown
 no routing
 vlan access 100
```

Validasi:

```text
show interface lag 1
show lacp interfaces
show lacp interfaces multi-chassis
```

## 14. Mengonfigurasi host

HostA:

```text
ip 10.10.100.11/24 10.10.100.1
```

HostB:

```text
ip 10.10.100.12/24 10.10.100.1
```

Gateway belum benar-benar tersedia dalam lab Layer 2, tetapi VPCS meminta nilai gateway.

Uji:

```text
ping 10.10.100.12
```

## 15. Uji resiliency

### Uji A — Memutus salah satu member LAG

1. Jalankan continuous ping HostA ke HostB.
2. Shutdown salah satu uplink SW3, misalnya:

```text
interface 1/1/9
 shutdown
```

3. Trafik seharusnya berpindah ke member LAG lainnya.
4. Pulihkan dengan `no shutdown`.

Untuk simulator, gunakan:

```text
interface lag 1
 lacp rate fast
```

pada kedua sisi agar member yang gagal lebih cepat dikeluarkan.

### Uji B — Memutus ISL

1. Pastikan ping berjalan dan keepalive established.
2. Pada SW1:

```text
interface lag 256
 shutdown
```

3. Periksa:

```text
show vsx status
show vsx brief
show vsx status inter-switch-link
show vsx status keepalive
```

4. Amati tindakan split-recovery dan status MCLAG.
5. Pulihkan ISL dengan `no shutdown` dan tunggu linkup delay selesai.

## 16. Checklist keberhasilan

- [ ] Versi SW1 dan SW2 sama.
- [ ] `lag256` up dengan dua member.
- [ ] Ping pada VRF KA berhasil.
- [ ] ISL `In-Sync`.
- [ ] Keepalive `Established`.
- [ ] Config Sync `Operational`.
- [ ] VLAN 100 tersinkron ke secondary.
- [ ] MCLAG 1 dan 2 up.
- [ ] HostA dapat ping HostB.
- [ ] Trafik tetap berjalan saat satu member LAG gagal.

## 17. Troubleshooting

| Gejala | Pemeriksaan | Tindakan |
|---|---|---|
| ISL tidak up | `show lacp interfaces` | Bounce `1/1/8-1/1/9`, pastikan LAG ID dan mode LACP sama. |
| Keepalive Init | `ping ... vrf KA` | Periksa VRF attach, alamat /31, dan source/peer. |
| Config sync error | `show vsx status config-sync` | Cari item yang tidak sinkron dan pastikan dibuat pada primary. |
| MCLAG tidak forwarding | `show lacp interfaces multi-chassis` | Periksa system MAC, VSX state, VLAN allowed, dan port member. |
| Setelah reboot trafik mati | Lepas/masukkan kembali port LAG | Keterbatasan simulator VSX LAG. |
| Failure test tidak terdeteksi | Gunakan `lacp rate fast` | Simulator tidak selalu merefleksikan physical link state. |

## 18. Pertanyaan latihan

1. Mengapa keepalive sebaiknya menggunakan jalur terpisah dari ISL?
2. Apa fungsi system MAC bersama pada VSX?
3. Apa perbedaan LAG biasa dan multi-chassis LAG?
4. Mengapa konfigurasi VLAN sebaiknya dibuat di primary dengan `vsx-sync`?
5. Apa risiko bila ISL gagal dan keepalive juga gagal?

## 19. Ringkasan perintah

```text
show version
show interface lag 256
show lacp interfaces
show vsx status
show vsx brief
show vsx status keepalive
show vsx status config-sync
show lacp interfaces multi-chassis
```
