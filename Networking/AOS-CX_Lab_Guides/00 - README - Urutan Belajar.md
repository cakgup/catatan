# AOS-CX Lab Guides - Versi Markdown

Kumpulan ini berisi tujuh panduan lab AOS-CX yang telah diubah ke Markdown. Setiap file memiliki dua lapisan:

1. **Versi belajar berbahasa Indonesia**: ringkasan konsep, urutan praktik, perintah utama, validasi, dan troubleshooting.
2. **Transkrip lengkap PDF**: isi asli disusun per halaman agar tidak kehilangan detail konfigurasi dan output.

## Urutan Belajar

1. [Deploying basic STP](AOS-CX%20Simulator%20Lab%20-%20Spanning%20Tree%20Basics%20Lab%20Guide.md) - Dasar - Layer 2
2. [Local MAC Match Authentication](AOS-CX%20Simulator%20-%20Local%20Mac%20Authentication%20Lab%20Guide.md) - Dasar-Menengah - Network Access Control
3. [VSX Lab1 - Layer2](AOS-CX%20Simulator%20-%20VSX%20Part%201%20Lab%20Guide.md) - Menengah - High Availability Layer 2
4. [Configuring OSPF on Aruba CX Switches](AOS-CX%20Simulator%20-%20Deploying%20OSPF%20Lab%20Guide.md) - Dasar - Routing OSPFv2
5. [Deploying OSPFv2 Areas](AOS-CX%20Switch%20Simulator%20-%20OSPFv2%20Areas%20Basics%20Lab%20Guide.md) - Menengah - Multi-area OSPF dan Redistribution
6. [Static VXLAN](AOS-CX%20Simulator%20-%20Static%20VXLAN%20Lab%20Guide.md) - Menengah - VXLAN Data Plane
7. [VXLAN EVPN](AOS-CX%20Switch%20Simulator%20-%20VXLAN%20EVPN%20Lab%20Guide.md) - Lanjutan - VXLAN dengan BGP EVPN Control Plane


## Jalur Cepat Menuju VXLAN EVPN

`STP -> OSPF Dasar -> OSPF Areas -> Static VXLAN -> VXLAN EVPN`

Local MAC Match Authentication merupakan cabang network access control, sedangkan VSX merupakan cabang high availability. Keduanya tetap penting, tetapi tidak menjadi prasyarat langsung untuk memahami VXLAN EVPN.

## Struktur Folder

- Tujuh file `.md` dengan nama yang mempertahankan nama PDF asal.
- Folder `assets/` berisi gambar topologi dari setiap PDF.
- File ZIP di luar folder untuk mengunduh seluruh paket sekaligus.
