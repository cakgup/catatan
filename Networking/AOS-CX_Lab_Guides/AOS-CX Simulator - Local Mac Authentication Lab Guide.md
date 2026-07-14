# Local MAC Match Authentication

> **Versi Markdown untuk belajar**  
> Sumber: `AOS-CX Simulator - Local Mac Authentication Lab Guide.pdf`  
> Tingkat: **Dasar-Menengah - Network Access Control**

## Cara menggunakan dokumen ini

1. Baca bagian **Ringkasan Belajar** dan **Konsep Inti** terlebih dahulu.
2. Buka gambar topologi dan tulis ulang alamat/interface pada catatan Anda.
3. Kerjakan lab mengikuti **Alur Praktik** tanpa langsung menyalin seluruh appendix.
4. Setelah setiap tahap, jalankan perintah pada **Validasi Keberhasilan**.
5. Gunakan bagian **Transkrip Lengkap PDF** ketika membutuhkan instruksi atau output asli.

## Ringkasan Belajar

Lab ini menunjukkan cara mengenali endpoint berdasarkan MAC address tanpa infrastruktur RADIUS, lalu memberikan local role dan atribut seperti VLAN atau MTU melalui device profile.

## Konsep Inti

| Konsep | Arti dalam lab |
|---|---|
| **MAC group** | Daftar MAC, OUI, atau mask yang digunakan sebagai kriteria pencocokan. |
| **Local role** | Kumpulan atribut yang diterapkan kepada client, misalnya VLAN, MTU, dan reauthentication period. |
| **Device profile** | Menghubungkan MAC group dengan role yang akan diberikan. |
| **Block until profile applied** | Port menahan trafik sampai proses profiling berhasil. |
| **Fallback** | Local MAC Match dapat digunakan ketika 802.1X dan MAC authentication tidak berhasil atau tidak digunakan. |

## Topologi Lab

![Topologi Local MAC Match Authentication](assets/02_local_mac_match_authentication_topology.jpg)

> Gambar di atas merupakan halaman 2 dari PDF asli. Perbesar gambar ketika mencatat nomor interface, alamat IP, VLAN, atau hubungan antarperangkat.

## Alur Praktik yang Disarankan

1. Aktifkan tiga port client sebagai access port VLAN 1.
2. Atur IP pada VPCS dan pastikan MAC client dipelajari switch.
3. Buat `mac-group` berisi MAC tiga client.
4. Buat `port-access role` dan tentukan atributnya.
5. Buat `port-access device-profile` yang menghubungkan MAC group dengan role.
6. Terapkan device profile pada port client dan validasi status client.

## Perintah Utama

```text
mac-group localmacmatch
 seq 10 match mac 00:50:79:66:68:05
 seq 20 match mac 00:50:79:66:68:02
 seq 30 match mac 00:50:79:66:68:03

port-access role localrole
 mtu 1600
 reauth-period 100
 vlan access 1

port-access device-profile localdp
 enable
 associate role localrole
 associate mac-group localmacmatch

interface 1/1/1
 no shutdown
 no routing
 vlan access 1
 port-access device-profile
 mode block-until-profile-applied

show mac-address-table detail
show port-access clients
show port-access clients detail
```

## Validasi Keberhasilan

- MAC client muncul pada port yang benar.
- Status onboarding menunjukkan `device-profile Success`.
- Role yang diterapkan adalah `localrole`.
- Atribut role seperti VLAN 1 dan MTU 1600 terlihat pada detail client.

## Catatan Troubleshooting

- MAC VPCS pada lab Anda dapat berbeda; ambil nilai aktual dari `show mac-address-table detail`.
- Konfigurasi ini ditujukan untuk platform yang mendukung fitur port-access terkait; cek dukungan image simulator.
- Jika client tidak terdeteksi, generate trafik dari VPCS dengan ping terlebih dahulu.

## Metode Belajar Aktif

Setelah konfigurasi berhasil, ulangi lab dengan sengaja membuat satu kesalahan, misalnya interface masih shutdown, alamat IP salah, VLAN/VNI tidak sesuai, area OSPF berbeda, atau neighbor belum diaktifkan. Temukan penyebabnya hanya dengan perintah `show`, kemudian catat:

- gejala yang terlihat;
- perintah pemeriksaan yang digunakan;
- akar masalah;
- konfigurasi perbaikan;
- hasil validasi setelah perbaikan.

---

# Transkrip Lengkap PDF

Bagian berikut mempertahankan isi PDF asli per halaman dalam blok teks. Tata letak tabel dan output CLI dipertahankan sebisa mungkin agar mudah dibandingkan dengan dokumen sumber.

<details>
<summary><strong>Halaman 1</strong></summary>

```text
Local MAC Match
Authentication
IMPORTANT! THIS GUIDE ASSUMES THAT THE AOS-CX OVA HAS BEEN INSTALLED AND WORKS IN GNS3
OR EVE-NG. PLEASE REFER TO GNS3/EVE-NG INITIAL SETUP LABS IF REQUIRED.
TABLE OF CONTENTS
Lab Objective................................................................................................................................................. 1
Lab Overview................................................................................................................................................. 1
Lab Network Layout....................................................................................................................................... 2
Lab Tasks ...................................................................................................................................................... 2
Task 1 - Lab setup ......................................................................................................................................... 2
Task 2 - Lab setup: Local mac match............................................................................................................ 3
Task 3 - Lab setup: Validation ....................................................................................................................... 4
Task 4 – Running Configuration .................................................................................................................... 6
LAB OBJECTIVE
At the end of this workshop, you will be able to implement the basic configuration to enable local mac match and also understand
local role and device-profile. The main goal in to ensure a successful deployment of local mac match authentication.
LAB OVERVIEW
Mac-Match provides dynamic attribute assignment (e.g., VLAN and QoS) through the use of locally configured authentication
repository. The most common use model for LMA is to automatically assign VLAN to IP phones.
Mac-Match solves dynamic assignment of per client (mac-address) attributes without having to create RADIUS infrastructure
When aaa dot1x, Mac-Auth fails, MAC match can be used as fallback
– match mac b2:c3:44:12:78:11
– match mac-oui 1a:2b:3c
– match mac-mask 71:14:89:f3/32
```

</details>
<details>
<summary><strong>Halaman 2</strong></summary>

```text
LAB NETWORK LAYOUT
Figure 1. Lab topology and addresses
LAB TASKS
Task 1 - Lab setup
For this lab refer to Figure 1 for topology.
• Configure hostname, note that this feature is applicable to only 6xxx platforms.
• Enable interfaces on client connected ports as below:
CX6000# show running-config interface 1/1/1
interface 1/1/1
no shutdown
no routing
vlan access 1
exit
CX6000#
CX6000# sh running-config interface 1/1/2
interface 1/1/2
no shutdown
no routing
vlan access 1
exit
CX6000# sh running-config interface 1/1/3
interface 1/1/3
no shutdown
no routing
vlan access 1
exit
```

</details>
<details>
<summary><strong>Halaman 3</strong></summary>

```text
CX6000#
• Please make sure to set ip address on connected host as below:
• Verify client mac is learned on connected port.
CX6000# show mac-address-table detail
MAC age-time : 300 seconds
Number of MAC addresses : 3
MAC Address VLAN Type Port Age Denied never_ageout
---------------------------------------------------------------------------------------------
00:50:79:66:68:05 1 port-access-security 1/1/1 300 false false
00:50:79:66:68:02 1 port-access-security 1/1/2 300 false false
00:50:79:66:68:03 1 port-access-security 1/1/3 300 false false
CX6000#
Task 2 - Lab setup: Local mac match
For this lab refer to Figure 1 for topology.
• Configure local mac match, local user role and device profile as below:
Local mac match global configuration
mac-group localmacmatch
seq 10 match mac 00:50:79:66:68:05
seq 20 match mac 00:50:79:66:68:02
seq 30 match mac 00:50:79:66:68:03
port-access role localrole
mtu 1600
reauth-period 100
vlan access 1
port-access device-profile localdp
enable
associate role localrole
associate mac-group localmacmatch
Local mac match apply to client connected interfaces
interface 1/1/1
no shutdown
no routing
```

</details>
<details>
<summary><strong>Halaman 4</strong></summary>

```text
vlan access 1
port-access device-profile
mode block-until-profile-applied
interface 1/1/2
no shutdown
no routing
vlan access 1
port-access device-profile
mode block-until-profile-applied
interface 1/1/3
no shutdown
no routing
vlan access 1
port-access device-profile
mode block-until-profile-applied
Task 3 - Lab setup: Validation
CX6000# show port-access clients detail
Port Access Client Status Details:
Client 00:50:79:66:68:05
============================
Session Details
---------------
Port : 1/1/1
Session Time : 12s
IPv4 Address :
IPv6 Address :
Authentication Details
----------------------
Status : Authenticated
Auth Precedence : dot1x - Not attempted, mac-auth - Not attempted
Authorization Details
----------------------
Role : localrole
Status : Applied
Role Information:
Name : localrole
Type : local
----------------------------------------------
Reauthentication Period : 100 secs
Cached Reauthentication Period :
Authentication Mode :
Session Timeout :
Client Inactivity Timeout :
Description :
Gateway Zone :
UBT Gateway Role :
UBT Gateway Clearpass Role :
Access VLAN : 1
Native VLAN :
```

</details>
<details>
<summary><strong>Halaman 5</strong></summary>

```text
Allowed Trunk VLANs :
Access VLAN Name :
Native VLAN Name :
VLAN Group Name :
MTU : 1600
QOS Trust Mode :
STP Administrative Edge Port :
PoE Priority :
Captive Portal Profile :
Policy :
Port Access Client Status Details:
Client 00:50:79:66:68:02
============================
Session Details
---------------
Port : 1/1/2
Session Time : 7s
IPv4 Address :
IPv6 Address :
Authentication Details
----------------------
Status : Authenticated
Auth Precedence : dot1x - Not attempted, mac-auth - Not attempted
Authorization Details
----------------------
Role : localrole
Status : Applied
Role Information:
Name : localrole
Type : local
----------------------------------------------
Reauthentication Period : 100 secs
Cached Reauthentication Period :
Authentication Mode :
Session Timeout :
Client Inactivity Timeout :
Description :
Gateway Zone :
UBT Gateway Role :
UBT Gateway Clearpass Role :
Access VLAN : 1
Native VLAN :
Allowed Trunk VLANs :
Access VLAN Name :
Native VLAN Name :
Allowed Trunk VLAN Names :
VLAN Group Name :
MTU : 1600
QOS Trust Mode :
STP Administrative Edge Port :
PoE Priority :
Captive Portal Profile :
Policy :
Port Access Client Status Details:
Client 00:50:79:66:68:03
============================
```

</details>
<details>
<summary><strong>Halaman 6</strong></summary>

```text
Session Details
---------------
Port : 1/1/3
Session Time : 10s
IPv4 Address :
IPv6 Address :
Authentication Details
----------------------
Status : Authenticated
Auth Precedence : dot1x - Not attempted, mac-auth - Not attempted
Authorization Details
----------------------
Role : localrole
Status : Applied
Role Information:
Name : localrole
Type : local
----------------------------------------------
Reauthentication Period : 100 secs
Cached Reauthentication Period :
Authentication Mode :
Session Timeout :
Client Inactivity Timeout :
Description :
Gateway Zone :
UBT Gateway Role :
UBT Gateway Clearpass Role :
Access VLAN : 1
Native VLAN :
Allowed Trunk VLANs :
Access VLAN Name :
Native VLAN Name :
Allowed Trunk VLAN Names :
VLAN Group Name :
MTU : 1600
QOS Trust Mode :
STP Administrative Edge Port :
PoE Priority :
Captive Portal Profile :
Policy :
CX6000# show port-access clients
Port Access Clients
Status codes: d device-mode
----------------------------------------------------------------------------------
Port MAC-Address Onboarding Status Role
Method
----------------------------------------------------------------------------------
1/1/1 00:50:79:66:68:05 device-profile Success localrole
1/1/2 00:50:79:66:68:02 device-profile Success localrole
1/1/3 00:50:79:66:68:03 device-profile Success localrole
Task 4 – Running Configuration
CX6000# show running-config
Current configuration:
```

</details>
<details>
<summary><strong>Halaman 7</strong></summary>

```text
!
!Version ArubaOS-CX Virtual.10.06.0001
!export-password: default
hostname CX6000
user admin group administrators password ciphertext
AQBapf/xKnYUClo+U49rs88SOqFdHLWKqsWtYjAkdjZP3OvtYgAAALYkSeFOBPlKBQLnuj5P0sGM4r1d+KCNgy12HDGx
adASxpcRFueUx8+yecstQhPNTGHxAP1YwFzT9ka+sqC
/JGUjdy3BTb0IQbSvwpBpWSBrsLFSPzzyKp/P3TE/N8uP/zy5
led locator on
ntp server pool.ntp.org minpoll 4 maxpoll 4 iburst
ntp enable
!
!
!
!
ssh server vrf mgmt
vlan 1
interface mgmt
no shutdown
ip dhcp
mac-group localmacmatch
seq 10 match mac 00:50:79:66:68:05
seq 20 match mac 00:50:79:66:68:02
seq 30 match mac 00:50:79:66:68:03
port-access role localrole
mtu 1600
reauth-period 100
vlan access 1
port-access device-profile localdp
enable
associate role localrole
associate mac-group localmacmatch
aaa authentication port-access mac-auth
enable
interface 1/1/1
no shutdown
no routing
vlan access 1
port-access device-profile
mode block-until-profile-applied
interface 1/1/2
no shutdown
no routing
vlan access 1
port-access device-profile
mode block-until-profile-applie
interface 1/1/3
no shutdown
no routing
vlan access 1
port-access device-profile
mode block-until-profile-applied
interface vlan 1
ip address 10.10.10.10/24
!
!
!
!
!
https-server vrf mgmt
```

</details>
<details>
<summary><strong>Halaman 8</strong></summary>

```text
www.arubanetworks.com
3333 Scott Blvd. Santa Clara, CA 95054
1.844.472.2782 | T: 1.408.227.4500 | FAX: 1.408.227.4550 | info@arubanetworks.com
```

</details>
