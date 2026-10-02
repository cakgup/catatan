# Deploying basic STP

> **Panduan praktik berbahasa Indonesia**  
> Sumber: `AOS-CX Simulator Lab - Spanning Tree Basics Lab Guide.pdf`  
> Tingkat: **Dasar — Switching Layer 2**

## 1. Tujuan pembelajaran

Setelah menyelesaikan lab ini, Anda diharapkan mampu:

- menjelaskan mengapa loop Layer 2 berbahaya;
- mengaktifkan MSTP pada AOS-CX;
- menentukan root bridge;
- membedakan root port, designated port, dan alternate port;
- mengubah root bridge melalui bridge priority;
- mengubah jalur aktif melalui STP port cost;
- membaca output `show spanning-tree` dengan benar.

## 2. Gambaran besar

Tiga switch dihubungkan membentuk segitiga. Secara fisik terdapat tiga link, tetapi bila seluruh link meneruskan frame Layer 2 tanpa kontrol, akan terbentuk loop. STP membuat topologi logis bebas loop dengan **memblokir salah satu jalur redundan**.

![Topologi Deploying basic STP](assets/01_deploying_basic_stp_topology.jpg)

### Cara membayangkannya

```text
Semua link aktif secara fisik
        ↓
Switch bertukar BPDU
        ↓
Dipilih satu root bridge
        ↓
Setiap switch mencari jalur termurah ke root
        ↓
Satu jalur redundan diblokir
```

## 3. Istilah penting

| Istilah | Penjelasan sederhana |
|---|---|
| **BPDU** | Pesan yang dipertukarkan switch untuk membangun spanning tree. |
| **Root bridge** | Switch pusat referensi STP. Semua switch menghitung jalur menuju switch ini. |
| **Bridge ID** | Gabungan bridge priority dan MAC address. Nilai terendah menang. |
| **Root port** | Port terbaik pada non-root switch untuk menuju root bridge. |
| **Designated port** | Port yang diizinkan meneruskan trafik pada suatu segmen. |
| **Alternate port** | Jalur cadangan yang diblokir agar tidak terjadi loop. |
| **Path cost** | Nilai biaya jalur. STP lebih menyukai akumulasi cost yang lebih rendah. |
| **MSTP** | Mode spanning tree yang digunakan dalam lab. Lab memakai instance default MST0. |

## 4. Tahap 1 — Menyiapkan topologi

Lakukan pada ketiga switch. Sesuaikan hostname menjadi `SwitchA`, `SwitchB`, dan `SwitchC`.

```text
configure terminal
hostname SwitchA
interface 1/1/1-1/1/2
 no shutdown
 no routing
exit
```

`no routing` mengubah port menjadi port Layer 2.

### Validasi LLDP

```text
show lldp neighbor-info
```

Pada setiap switch seharusnya terlihat dua neighbor. Bila tidak:

1. periksa pemetaan port pada GNS3/EVE-NG;
2. pastikan kedua ujung interface sudah `no shutdown`;
3. pastikan node sudah selesai booting.

## 5. Tahap 2 — Mengaktifkan MSTP

Lakukan pada semua switch:

```text
configure terminal
spanning-tree mode mstp
spanning-tree
```

Kemudian periksa:

```text
show spanning-tree
```

### Cara membaca output

Bagian penting:

```text
Root ID Priority
Root ID MAC-Address
Bridge ID Priority
Bridge ID MAC-Address
Port Role State Cost
```

Gunakan logika berikut:

- Jika terdapat kalimat `This bridge is the root`, switch tersebut adalah root bridge.
- Semua port STP pada root bridge biasanya berperan `Designated Forwarding`.
- Non-root switch memiliki satu `Root Forwarding` port.
- Salah satu jalur redundan akan menjadi `Alternate Blocking`.

### Mengapa root bridge awal bisa berbeda?

Secara default seluruh switch menggunakan priority yang sama. Bila priority sama, MAC address terendah menjadi penentu. Karena MAC simulator dapat berbeda, root bridge awal pada lab Anda tidak harus sama dengan contoh PDF.

## 6. Tahap 3 — Menentukan root bridge secara sengaja

Jadikan `SwitchA` sebagai root:

```text
SwitchA(config)# spanning-tree priority 1
```

Pada AOS-CX, nilai `1` dikalikan 4096, sehingga bridge priority menjadi 4096.

| Nilai konfigurasi | Bridge priority aktual |
|---:|---:|
| 0 | 0 |
| 1 | 4096 |
| 8 | 32768 — default |
| 15 | 61440 |

Validasi pada semua switch:

```text
show spanning-tree
```

Hasil yang diharapkan:

- SwitchA menyatakan dirinya root;
- port SwitchA menjadi `Designated Forwarding`;
- SwitchB dan SwitchC memilih satu root port menuju SwitchA;
- salah satu link redundan tetap diblokir.

## 7. Tahap 4 — Mengubah jalur dengan port cost

Misalnya pada SwitchC, port `1/1/1` adalah root port langsung menuju SwitchA. Naikkan cost port tersebut:

```text
SwitchC(config)# interface 1/1/1
SwitchC(config-if)# spanning-tree cost 2000000
```

Periksa kembali:

```text
show spanning-tree
```

Perubahan yang diharapkan:

- `1/1/1` yang cost-nya sangat tinggi berubah menjadi `Alternate Blocking`;
- `1/1/2` menjadi `Root Forwarding` melalui jalur tidak langsung;
- STP memilih jalur dengan total cost paling kecil, bukan sekadar jumlah hop paling sedikit.

Contoh referensi cost:

| Kecepatan link | Cost STP contoh |
|---:|---:|
| 10 Mbps | 2.000.000 |
| 100 Mbps | 200.000 |
| 1 Gbps | 20.000 |
| 10 Gbps | 2.000 |
| 100 Gbps | 200 |
| 1 Tbps | 20 |

Untuk mengembalikan cost otomatis:

```text
interface 1/1/1
 no spanning-tree cost
```

## 8. Checklist keberhasilan

- [ ] Semua switch melihat dua neighbor LLDP.
- [ ] STP berstatus `Enabled` dan protokol `MSTP`.
- [ ] Hanya ada satu root bridge.
- [ ] Tidak semua port dalam segitiga berada pada forwarding state.
- [ ] Setelah priority SwitchA diturunkan, SwitchA menjadi root.
- [ ] Setelah cost SwitchC dinaikkan, root port berpindah.

## 9. Troubleshooting

| Gejala | Pemeriksaan | Kemungkinan penyebab |
|---|---|---|
| `Spanning-tree is disabled` | `show spanning-tree` | Perintah `spanning-tree` belum dijalankan. |
| Semua link seperti forwarding | Periksa status STP di semua switch | Salah satu switch belum mengaktifkan STP atau port masih routed. |
| Root bridge tidak berubah | `show running-config | include spanning-tree` | Priority diterapkan pada switch yang salah atau belum masuk config mode. |
| Port yang diharapkan tidak blocking | Bandingkan bridge ID dan cost | MAC simulator atau cost jalur berbeda dari contoh. |
| LLDP neighbor kosong | `show interface brief` | Port shutdown atau koneksi topology salah. |

## 10. Pertanyaan latihan

1. Mengapa root bridge tidak memiliki root port?
2. Bila seluruh priority sama, parameter apa yang menjadi tie-breaker?
3. Mengapa port dengan cost 2.000.000 tidak dipilih meskipun langsung menuju root?
4. Apa dampaknya bila STP dimatikan pada topology segitiga?
5. Apa perbedaan `Designated Forwarding` dan `Root Forwarding`?

## 11. Ringkasan perintah

```text
spanning-tree mode mstp
spanning-tree
spanning-tree priority 1
interface 1/1/1
 spanning-tree cost 2000000
show spanning-tree
show lldp neighbor-info
```
