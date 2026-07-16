# Paket PNETLab AOS-CX — 11 Topology UNL

Paket ini berisi **11 file topology PNETLab dalam format `.unl`** yang direkonstruksi dari diagram dan panduan praktik Aruba AOS-CX.

Dokumen ini menjelaskan proses lengkap mulai dari:

```text
Menyiapkan komputer
→ mengunduh VirtualBox dan PNETLab
→ memasang PNETLab
→ mengunduh AOS-CX Simulator resmi
→ memasukkan image AOS-CX ke PNETLab
→ menyesuaikan nama image pada file UNL
→ mengimpor topology
→ menguji node
```

> **Penting:** paket ZIP ini hanya berisi topology `.unl`. Image Aruba AOS-CX tidak disertakan dan harus diperoleh secara resmi dari HPE Aruba Networking.

---

## 1. Isi paket

```text
PNETLab_AOS-CX_11_UNL_Topologies/
├── Lab 1a - Spanning Tree Basic.unl
├── Lab 1b - VSX - Virtual Switching Extension.unl
├── Lab 1c - Deploying OSPFv2 on Aruba CX.unl
├── Lab 1d - OSPF Areas Basics on Aruba CX.unl
├── Lab 3a - 2 Tier L2 Access VSX.unl
├── Lab 3b - 3 Tier L2 Access with VSX and OSPF.unl
├── Lab 4a - 2 Tier Layer 3 Access with OSPF.unl
├── Lab 4b - Deploying Basic BGP.unl
├── Lab 4c - Local MAC Match Authentication.unl
├── Lab 5a - Static VXLAN.unl
├── Lab 5b - VXLAN EVPN.unl
├── replace_aoscx_image.py
├── VALIDATION.md
└── README.md
```

---

# BAGIAN A — PERSIAPAN KOMPUTER

## 2. Kebutuhan perangkat keras

### Minimum untuk mencoba lab kecil

```text
CPU        : 4 core / 8 thread
RAM        : 16 GB
Disk kosong: 80–100 GB
Virtualisasi hardware: aktif
```

### Disarankan untuk seluruh lab AOS-CX

```text
CPU host        : 8 core atau lebih
RAM host        : 32 GB atau lebih
RAM VM PNETLab  : 16–24 GB
vCPU PNETLab    : 6–8 vCPU
Disk kosong     : 100–150 GB
```

Lab VSX, Campus 3-Tier, Static VXLAN, dan VXLAN EVPN menjalankan beberapa switch AOS-CX secara bersamaan sehingga membutuhkan RAM yang cukup besar.

## 3. Aktifkan virtualisasi pada BIOS/UEFI

Aktifkan salah satu opsi berikut:

```text
Intel Virtualization Technology / Intel VT-x
AMD-V / SVM Mode
```

Tanpa virtualisasi hardware, node QEMU seperti Aruba AOS-CX tidak dapat berjalan dengan baik.

Untuk memeriksanya di Windows:

```text
Task Manager
→ Performance
→ CPU
→ Virtualization: Enabled
```

---

# BAGIAN B — FILE YANG PERLU DIUNDUH

## 4. Daftar download resmi

| Komponen | Fungsi | Link resmi |
|---|---|---|
| **Oracle VirtualBox** | Menjalankan VM PNETLab | https://www.virtualbox.org/wiki/Downloads |
| **PNETLab OVA** | Platform emulator jaringan | https://pnetlab.com/pages/download |
| **AOS-CX Simulator** | Sistem operasi switch virtual Aruba | https://networkingsupport.hpe.com/downloads |
| **Dokumentasi AOS-CX** | Referensi CLI dan fitur | https://arubanetworking.hpe.com/techdocs/AOS-CX/help_portal/Content/home.htm |
| **7-Zip** | Mengekstrak file OVA Aruba | https://www.7-zip.org/download.html |
| **WinSCP** | Mengunggah image ke PNETLab melalui SFTP/SCP | https://winscp.net/eng/download.php |

## 5. Catatan tentang VirtualBox

Halaman download PNETLab menyebut file OVA dapat dijalankan pada platform virtualisasi seperti VirtualBox dan VMware.

Namun, dokumentasi platform PNETLab lebih menekankan:

```text
VMware Workstation
VMware Player
VMware ESXi
Google Cloud Platform
```

VirtualBox tetap dapat digunakan, tetapi bila node AOS-CX selalu gagal menyala karena masalah nested virtualization, gunakan VMware Workstation/Player sebagai alternatif.

---

# BAGIAN C — INSTALASI PNETLAB DI VIRTUALBOX

## 6. Unduh PNETLab

Buka:

```text
https://pnetlab.com/pages/download
```

Unduh file OVA PNETLab terbaru.

Contoh nama file:

```text
PNETLab-*.ova
```

Ukuran file dapat cukup besar. Pastikan proses download selesai sebelum melakukan import.

## 7. Import PNETLab OVA ke VirtualBox

1. Buka **Oracle VirtualBox**.
2. Pilih:

   ```text
   File
   → Import Appliance
   ```

3. Pilih file PNETLab `.ova`.
4. Lanjutkan proses import.
5. Setelah import selesai, jangan langsung menjalankan VM.
6. Buka:

   ```text
   PNETLab VM
   → Settings
   ```

## 8. Atur resource VM

Rekomendasi awal:

```text
RAM       : 16384 MB
Processor : 6–8 vCPU
Video RAM : default
Disk      : gunakan disk hasil import OVA
```

Jangan memberikan seluruh CPU dan RAM komputer kepada PNETLab. Sisakan resource untuk Windows dan VirtualBox.

## 9. Aktifkan nested virtualization

Buka:

```text
Settings
→ System
→ Processor
→ Enable Nested VT-x/AMD-V
```

Jika opsi tersebut tidak dapat diklik, tutup VirtualBox dan jalankan Command Prompt/PowerShell sebagai Administrator:

```powershell
VBoxManage modifyvm "NAMA-VM-PNETLAB" --nested-hw-virt on
```

Ganti `NAMA-VM-PNETLAB` sesuai nama VM pada VirtualBox.

Contoh:

```powershell
VBoxManage modifyvm "PNETLab" --nested-hw-virt on
```

## 10. Atur jaringan VirtualBox

Cara termudah agar browser komputer dapat mengakses PNETLab:

```text
Adapter 1
→ Enable Network Adapter
→ Attached to: Bridged Adapter
→ pilih kartu jaringan aktif
```

Contoh kartu jaringan:

```text
Intel Ethernet
Realtek Ethernet
Wi-Fi Adapter
```

Jika Bridged Adapter tidak memperoleh IP, gunakan NAT atau Host-only sesuai kondisi jaringan lokal.

## 11. Jalankan PNETLab

Start VM PNETLab dan tunggu proses boot.

Pada console akan terlihat alamat IP, misalnya:

```text
192.168.1.150
```

Jika IP tidak terlihat, login ke console PNETLab dan jalankan:

```bash
ip address
```

atau:

```bash
hostname -I
```

## 12. Login awal

Login console/root biasanya:

```text
Username: root
Password: pnet
```

Ikuti proses initial setup.

Untuk mode offline, login web default biasanya:

```text
Username: admin
Password: pnet
```

Buka dari browser:

```text
https://IP-PNETLAB
```

Contoh:

```text
https://192.168.1.150
```

Browser mungkin menampilkan peringatan sertifikat lokal. Lanjutkan hanya jika alamat tersebut benar-benar IP VM PNETLab milik Anda.

## 13. Periksa nested virtualization dari PNETLab

Login melalui console atau SSH, lalu jalankan:

```bash
egrep -c '(vmx|svm)' /proc/cpuinfo
```

Hasil yang benar harus lebih dari `0`.

Contoh:

```text
8
```

Jika hasilnya `0`, node AOS-CX kemungkinan tidak dapat berjalan.

---

# BAGIAN D — MENGUNDUH AOS-CX SIMULATOR

## 14. Apakah perlu image Aruba?

Ya.

PNETLab hanya menyediakan platform emulator. Untuk menjalankan switch Aruba, Anda memerlukan **AOS-CX Simulation Software/Simulator** resmi.

Satu image AOS-CX Simulator dapat digunakan untuk membuat banyak node:

```text
SwitchA
SwitchB
SwitchC
SwitchD
SwitchX
SwitchY
Spine
Leaf
```

Anda tidak perlu mengunduh image terpisah untuk CX 6100, 6200, 6300, 6400, dan seri lainnya dalam lab ini.

## 15. Unduh dari HPE Aruba Networking

Buka portal resmi:

```text
https://networkingsupport.hpe.com/downloads
```

Login menggunakan akun HPE Networking Support.

Pada kolom pencarian gunakan salah satu kata kunci:

```text
AOS-CX Simulator
AOS-CX Simulation Software
AOS-CX Virtual
```

Pilih paket yang berupa:

```text
Simulation Software
Simulator
Virtual Appliance
OVA
```

Jangan mengunduh file `.swi` karena file tersebut merupakan firmware untuk switch fisik, bukan disk simulator PNETLab.

## 16. Versi yang digunakan

Modul lama menggunakan contoh versi seperti:

```text
AOS-CX Virtual 10.05
AOS-CX Virtual 10.07
```

Namun Anda dapat menggunakan simulator versi lebih baru selama fitur berikut tersedia:

```text
STP
LACP
VSX
OSPF
BGP
VXLAN
EVPN
Local MAC Match
```

Beberapa output atau sintaks dapat sedikit berbeda dari PDF lama.

## 17. Lisensi dan distribusi

Gunakan image yang diperoleh dari portal resmi HPE.

Jangan membagikan ulang file OVA, VMDK, atau QCOW2 AOS-CX kepada pihak lain apabila lisensinya tidak mengizinkan.

Paket UNL ini tidak mengandung image vendor.

---

# BAGIAN E — MEMASUKKAN IMAGE AOS-CX KE PNETLAB

## 18. Ekstrak file OVA AOS-CX

File hasil download biasanya berbentuk:

```text
*.ova
```

Ekstrak menggunakan 7-Zip:

```text
Klik kanan file OVA
→ 7-Zip
→ Extract
```

Di dalamnya biasanya terdapat:

```text
*.ovf
*.vmdk
*.mf
```

File yang diperlukan untuk PNETLab adalah disk `.vmdk`.

## 19. Tentukan nama folder image

Paket UNL ini menggunakan nilai default:

```text
template = arubacx
image    = arubacx-10.07
```

Folder image default:

```text
/opt/unetlab/addons/qemu/arubacx-10.07/
```

Anda boleh menggunakan nama lain sesuai versi, misalnya:

```text
arubacx-10.10
arubacx-10.13
arubacx-10.13.1000
arubacx-10.14
```

Gunakan nama tanpa spasi.

## 20. Hubungkan WinSCP ke PNETLab

Buka WinSCP dan isi:

```text
File protocol : SFTP
Host name     : IP PNETLab
Port          : 22
Username      : root
Password      : password root PNETLab
```

Contoh:

```text
Host: 192.168.1.150
User: root
```

## 21. Buat folder image

Masuk melalui SSH atau console PNETLab:

```bash
mkdir -p /opt/unetlab/addons/qemu/arubacx-10.07
```

Jika menggunakan versi lain:

```bash
mkdir -p /opt/unetlab/addons/qemu/arubacx-10.13.1000
```

## 22. Upload disk VMDK

Upload file `.vmdk` hasil ekstraksi ke folder tersebut.

Contoh:

```text
/opt/unetlab/addons/qemu/arubacx-10.07/ArubaOS-CX.vmdk
```

Periksa:

```bash
ls -lh /opt/unetlab/addons/qemu/arubacx-10.07/
```

## 23. Konversi VMDK menjadi QCOW2

Masuk ke folder image:

```bash
cd /opt/unetlab/addons/qemu/arubacx-10.07/
```

Periksa format sumber:

```bash
qemu-img info ArubaOS-CX.vmdk
```

Konversi:

```bash
qemu-img convert \
  -f vmdk \
  -O qcow2 \
  ArubaOS-CX.vmdk \
  virtioa.qcow2
```

> Nama disk hasil harus `virtioa.qcow2` agar sesuai dengan template QEMU Aruba CX yang umum digunakan.

Periksa hasil:

```bash
qemu-img info virtioa.qcow2
ls -lh
```

Jangan menghapus file VMDK sebelum node AOS-CX berhasil diuji.

## 24. Perbaiki permission

Jalankan:

```bash
/opt/unetlab/wrappers/unl_wrapper -a fixpermissions
```

Periksa kembali:

```bash
ls -lh /opt/unetlab/addons/qemu/arubacx-10.07/
```

## 25. Uji image sebelum import seluruh lab

Dari web PNETLab:

1. Buat satu lab kosong.
2. Tambahkan satu node.
3. Cari template:

   ```text
   Aruba AOS-CX
   Aruba CX
   ```

4. Pastikan image yang baru dipasang muncul.
5. Tambahkan satu node.
6. Start node.
7. Buka console.

Login awal AOS-CX Simulator umumnya:

```text
Username: admin
Password: kosong
```

Uji:

```text
switch# show version
switch# show interface brief
```

Jika satu node berhasil boot, lanjutkan ke import file UNL.

---

# BAGIAN F — MENYESUAIKAN FILE UNL

## 26. Mengapa nama image harus disesuaikan?

Di dalam setiap file `.unl` terdapat atribut:

```text
template="arubacx"
image="arubacx-10.07"
```

Jika image pada server bernama:

```text
arubacx-10.13.1000
```

tetapi file UNL masih menunjuk ke:

```text
arubacx-10.07
```

topology dapat terimpor, tetapi node tidak dapat menemukan image yang benar.

## 27. Cara mengetahui nama image pada PNETLab

Gunakan salah satu cara berikut.

### Cara A — melalui web

1. Buat atau buka lab.
2. Tambahkan/edit node Aruba CX.
3. Catat field:

   ```text
   Template
   Image
   ```

### Cara B — melalui SSH

```bash
ls -1 /opt/unetlab/addons/qemu/ | grep -i aruba
```

Contoh hasil:

```text
arubacx-10.13.1000
```

## 28. Menyesuaikan semua UNL dengan script

Paket ini menyertakan:

```text
replace_aoscx_image.py
```

Jalankan di komputer yang mempunyai Python 3.

Contoh Windows:

```powershell
cd PNETLab_AOS-CX_11_UNL_Topologies
python replace_aoscx_image.py --image arubacx-10.13.1000
```

Contoh Linux/macOS:

```bash
cd PNETLab_AOS-CX_11_UNL_Topologies
python3 replace_aoscx_image.py --image arubacx-10.13.1000
```

Jika nama template juga berbeda:

```bash
python3 replace_aoscx_image.py \
  --template arubacx \
  --image arubacx-10.13.1000
```

Script akan memperbarui seluruh file `.unl` pada folder tersebut.

## 29. Mengubah secara manual

File `.unl` merupakan XML dan dapat dibuka dengan VS Code atau Notepad++.

Cari:

```xml
template="arubacx"
image="arubacx-10.07"
```

Ganti nilai `image` dengan nama folder image yang sebenarnya.

Jangan mengubah struktur XML lain bila tidak diperlukan.

---

# BAGIAN G — IMPORT FILE UNL

## 30. Import melalui web PNETLab

1. Login sebagai admin.
2. Buka **Workspace**.
3. Buat folder, misalnya:

   ```text
   AOS-CX Labs
   ```

4. Masuk ke folder tersebut.
5. Klik ikon:

   ```text
   Upload / Import
   ```

6. Pilih satu file `.unl`.
7. Tunggu sampai upload selesai.
8. Klik **Refresh**.
9. Buka lab yang baru diimpor.

Lakukan satu file terlebih dahulu, misalnya:

```text
Lab 1a - Spanning Tree Basic.unl
```

Jika berhasil, lanjutkan file lainnya.

## 31. Import seluruh UNL melalui WinSCP/SCP

Jika upload melalui web bermasalah, gunakan akun root PNETLab.

Buat folder:

```bash
mkdir -p "/opt/unetlab/labs/AOS-CX Labs"
```

Upload seluruh file `.unl` ke:

```text
/opt/unetlab/labs/AOS-CX Labs/
```

Contoh menggunakan `scp` dari komputer Linux/macOS:

```bash
scp *.unl \
  root@IP-PNETLAB:"/opt/unetlab/labs/AOS-CX Labs/"
```

Setelah upload, jalankan:

```bash
/opt/unetlab/wrappers/unl_wrapper -a fixpermissions
```

Kemudian:

```text
Logout dari web
→ login kembali
→ buka Workspace
→ masuk ke folder AOS-CX Labs
```

## 32. Jika akun bukan admin

Import/upload lab dapat dibatasi oleh role pengguna.

Pilihan yang tersedia:

1. minta admin memberikan hak upload/import;
2. minta admin mengunggah file `.unl`;
3. pada PNETLab milik sendiri, gunakan akun `admin`;
4. gunakan akses root/SSH untuk menaruh file ke `/opt/unetlab/labs/`.

Jangan mencoba melewati pembatasan akun pada PNETLab milik pihak lain tanpa izin administrator.

---

# BAGIAN H — VALIDASI SETELAH IMPORT

## 33. Periksa node sebelum start

Buka topology dan edit satu node AOS-CX.

Pastikan:

```text
Template : Aruba AOS-CX / arubacx
Image    : sama dengan folder yang telah dipasang
RAM      : cukup
CPU      : cukup
```

## 34. Pemetaan interface yang digunakan

Paket ini menggunakan asumsi:

```text
UNL interface id 0 = AOS-CX 1/1/1
UNL interface id 1 = AOS-CX 1/1/2
UNL interface id 2 = AOS-CX 1/1/3
...
UNL interface id 8 = AOS-CX 1/1/9
```

Setelah node boot:

```text
show interface brief
show lldp neighbor-info
```

Cocokkan dengan diagram dan modul Markdown.

## 35. Start satu node terlebih dahulu

Jangan langsung menjalankan semua node.

Urutan yang aman:

```text
Start satu AOS-CX
→ tunggu boot selesai
→ buka console
→ show version
→ stop node
→ start dua node
→ uji koneksi
→ baru start seluruh topology
```

## 36. Simpan konfigurasi

Pada setiap switch AOS-CX:

```text
write memory
```

atau:

```text
copy running-config startup-config
```

Validasi:

```text
show startup-config
```

File UNL dalam paket ini tidak berisi konfigurasi switch. Masukkan konfigurasi dari modul Markdown masing-masing.

---

# BAGIAN I — TROUBLESHOOTING

## 37. Image tidak muncul pada daftar node

Periksa:

```bash
ls -lh /opt/unetlab/addons/qemu/
ls -lh /opt/unetlab/addons/qemu/arubacx-10.07/
```

Pastikan tersedia:

```text
virtioa.qcow2
```

Jalankan lagi:

```bash
/opt/unetlab/wrappers/unl_wrapper -a fixpermissions
```

## 38. Topology berhasil diimpor tetapi node tidak dapat start

Kemungkinan:

- nama image dalam UNL tidak sama dengan folder image;
- file disk bukan `virtioa.qcow2`;
- permission belum diperbaiki;
- nested virtualization tidak aktif;
- RAM PNETLab tidak cukup;
- RAM node terlalu kecil;
- file QCOW2 rusak.

Periksa log dan resource:

```bash
free -h
df -h
egrep -c '(vmx|svm)' /proc/cpuinfo
qemu-img check /opt/unetlab/addons/qemu/arubacx-10.07/virtioa.qcow2
```

## 39. Node start lalu langsung stop

Periksa nested virtualization:

```bash
egrep -c '(vmx|svm)' /proc/cpuinfo
```

Jika `0`:

1. shutdown PNETLab;
2. aktifkan VT-x/AMD-V di BIOS;
3. aktifkan nested virtualization di VirtualBox;
4. start kembali PNETLab.

Jika tetap gagal di VirtualBox, pertimbangkan menggunakan VMware Workstation/Player.

## 40. Console kosong atau sangat lama

AOS-CX dapat membutuhkan waktu boot beberapa menit, terutama saat resource komputer terbatas.

Periksa:

```text
RAM VM PNETLab
CPU VM PNETLab
RAM per node
jumlah node yang berjalan
```

Start satu node saja untuk pengujian.

## 41. Node boot tetapi interface tidak sesuai

Periksa:

```text
show interface brief
show lldp neighbor-info
```

Kemudian edit koneksi topology jika nomor port berbeda dari panduan.

## 42. VPCS tidak dapat ping gateway

Periksa secara berurutan:

```text
VPCS show ip
→ port switch up?
→ port sudah no routing?
→ VLAN access benar?
→ SVI gateway aktif?
→ MAC host muncul?
→ ARP terbentuk?
```

Perintah:

```text
show interface brief
show vlan
show mac-address-table
show arp
```

---

# BAGIAN J — CHECKLIST AKHIR

## 43. Checklist instalasi

```text
[ ] VT-x/AMD-V aktif di BIOS
[ ] VirtualBox terpasang
[ ] PNETLab OVA berhasil di-import
[ ] Nested virtualization aktif
[ ] PNETLab memperoleh IP
[ ] Web PNETLab dapat dibuka
[ ] AOS-CX Simulator diperoleh dari HPE
[ ] OVA Aruba berhasil diekstrak
[ ] VMDK berhasil dikonversi ke virtioa.qcow2
[ ] fixpermissions sudah dijalankan
[ ] Satu node AOS-CX berhasil boot
[ ] Nama image pada UNL sudah sesuai
[ ] File UNL berhasil diimpor
[ ] Interface topology sudah diperiksa
[ ] Konfigurasi perangkat dimasukkan dari modul Markdown
[ ] write memory telah dijalankan
```

---

# BAGIAN K — RINGKASAN CEPAT

## 44. Alur tercepat

```text
1. Download VirtualBox
2. Download PNETLab OVA
3. Import OVA ke VirtualBox
4. Aktifkan nested virtualization
5. Login ke PNETLab
6. Download AOS-CX Simulator dari HPE
7. Extract OVA Aruba
8. Upload VMDK ke /opt/unetlab/addons/qemu/arubacx-<versi>/
9. Convert menjadi virtioa.qcow2
10. Run fixpermissions
11. Test satu node AOS-CX
12. Sesuaikan image pada semua file UNL
13. Upload UNL ke PNETLab
14. Open topology dan periksa interface
15. Masukkan konfigurasi dari modul Markdown
```

## 45. Perintah inti

```bash
# Membuat folder image
mkdir -p /opt/unetlab/addons/qemu/arubacx-10.07

# Masuk folder
cd /opt/unetlab/addons/qemu/arubacx-10.07

# Konversi disk
qemu-img convert -f vmdk -O qcow2 ArubaOS-CX.vmdk virtioa.qcow2

# Perbaiki permission
/opt/unetlab/wrappers/unl_wrapper -a fixpermissions

# Periksa virtualisasi
egrep -c '(vmx|svm)' /proc/cpuinfo

# Periksa folder image
ls -lh /opt/unetlab/addons/qemu/arubacx-10.07/

# Folder lab
mkdir -p "/opt/unetlab/labs/AOS-CX Labs"
```

---

# 46. Batasan paket

- Topology merupakan hasil rekonstruksi berdasarkan diagram dan panduan.
- Paket tidak berisi image AOS-CX.
- Paket tidak berisi running/startup configuration dari kelas.
- Nama image perlu disesuaikan dengan image pada PNETLab Anda.
- Nomor interface perlu diperiksa setelah import.
- Fitur upload/import bergantung pada role akun PNETLab.
- Gunakan image dan perangkat lunak sesuai ketentuan lisensi masing-masing vendor.
