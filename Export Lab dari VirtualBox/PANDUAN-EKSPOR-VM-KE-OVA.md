# Panduan Ekspor VM VirtualBox ke OVA

Alur kerja: **periksa VM → pilih keadaan yang akan dibagikan → ekspor OVA → verifikasi → uji impor dan aplikasi**.

## 1. Persiapan

1. Matikan sistem operasi VM secara normal sampai status **Powered Off**, bukan **Saved**.
2. Buka **Settings > Storage**. Pastikan hard disk sistem terpasang.
3. Sediakan ruang penyimpanan untuk OVA. Jika membuat full clone, sediakan ruang tambahan untuk salinan disk.
4. Tentukan apakah yang dibagikan adalah keadaan VM saat ini atau snapshot tertentu.

OVA berisi keadaan yang diekspor. Riwayat snapshot VirtualBox tidak ikut disertakan.

## 2. Ekspor melalui antarmuka VirtualBox

Nama menu dapat sedikit berbeda antarversi.

1. Pilih **File > Export Appliance**.
2. Pilih VM yang ingin dibagikan.
3. Tentukan lokasi dan nama file, misalnya `D:\Distribusi\NamaVM.ova`.
4. Pilih format **OVF 1.0**.
5. Aktifkan **Write Manifest** untuk menyertakan checksum komponen paket.
6. Jika tersedia, pilih opsi menghapus alamat MAC sumber agar identitas jaringan dapat dibuat ulang saat impor.
7. Klik **Export** dan tunggu pesan keberhasilan.

File yang sudah terlihat di folder belum tentu selesai ditulis. Bagikan hanya setelah ekspor selesai.

## 3. Ekspor dari snapshot tertentu

1. Pilih VM dan buka tampilan **Snapshots**.
2. Pilih snapshot yang diinginkan.
3. Pilih **Clone** dan beri nama berbeda, misalnya `NamaVM-Distribusi`.
4. Pilih **Full Clone** dan keadaan snapshot terpilih saja jika pilihan tersebut tersedia.
5. Tunggu clone selesai, lalu periksa disk pada **Settings > Storage**.
6. Ekspor VM hasil clone mengikuti bagian 2.

### Kasus PTLabs2026 yang dikerjakan

Konfigurasi aktif PTLabs2026 tidak memiliki hard disk terpasang. OVA lama hanya sekitar 15 KB. Namun, snapshot **Fresh PTLabs 2026** masih menunjuk ke disk dasar yang tersedia.

Karena itu, urutan yang dilakukan adalah:

1. Memeriksa konfigurasi VM dan disk.
2. Membuat full clone dari snapshot **Fresh PTLabs 2026**, bernama **PTLabs2026-Distribusi**.
3. Mengekspor clone menjadi OVA dengan disk virtual dan manifest.
4. Memverifikasi checksum komponen OVF dan VMDK terhadap manifest.
5. Menjalankan simulasi impor VirtualBox.
6. Membuat checksum SHA-256 file OVA dan petunjuk peserta.

Clone merupakan penanganan khusus keadaan VM tersebut. VM lain dengan disk aktif yang valid dapat langsung diekspor.

## 4. Menggunakan PowerShell

Perintah berikut mengacu pada VBoxManage dari VirtualBox 7.1.4 yang digunakan pada komputer sumber. Ganti nama VM dan lokasi tujuan sesuai kebutuhan. Gunakan nama file baru agar tidak menimpa ekspor sebelumnya.

### Periksa VM

```powershell
$vbox = 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'

& $vbox showvminfo 'NamaVM'
```

Pastikan VM mati dan informasi storage menampilkan hard disk sistem.

### Ekspor OVA

```powershell
New-Item -ItemType Directory -Path 'D:\Distribusi' -Force

& $vbox export 'NamaVM' `
  --output 'D:\Distribusi\NamaVM.ova' `
  --ovf10 `
  --options manifest,nomacs
```

Keterangan:

- `--output`: lokasi file OVA.
- `--ovf10`: format OVF 1.0.
- `manifest`: menyertakan manifest checksum komponen arsip.
- `nomacs`: menghilangkan alamat MAC sumber dari ekspor.

Tunggu pesan `Successfully exported 1 machine(s).`.

### Opsional: clone snapshot sebelum ekspor

```powershell
& $vbox clonevm 'NamaVM' `
  --snapshot 'Nama Snapshot' `
  --mode machine `
  --name 'NamaVM-Distribusi' `
  --basefolder 'D:\VM-Export-Build' `
  --register
```

Setelah berhasil, gunakan `NamaVM-Distribusi` sebagai nama VM pada perintah ekspor. Full clone membutuhkan ruang penyimpanan tambahan.

## 5. Verifikasi hasil

### Simulasi impor

```powershell
& $vbox import 'D:\Distribusi\NamaVM.ova' --dry-run
```

Pastikan perintah berhasil dan disk virtual, CPU, serta RAM terdeteksi sesuai konfigurasi.

`--dry-run` membaca paket dan menampilkan rencana impor. Perintah ini tidak benar-benar mengimpor atau menjalankan VM, dan bukan pengganti pengujian boot atau verifikasi checksum seluruh isi arsip.

### Buat checksum SHA-256

```powershell
$ovaPath = 'D:\Distribusi\NamaVM.ova'
$ovaHash = Get-FileHash -LiteralPath $ovaPath -Algorithm SHA256
$ovaName = Split-Path -Path $ovaPath -Leaf

'{0}  {1}' -f $ovaHash.Hash.ToLowerInvariant(), $ovaName |
  Set-Content -LiteralPath ($ovaPath + '.sha256') -Encoding ascii
```

Bagikan file `.ova.sha256` bersama OVA. Setelah transfer, peserta dapat menjalankan:

```powershell
Get-FileHash 'D:\Distribusi\NamaVM.ova' -Algorithm SHA256
Get-Content 'D:\Distribusi\NamaVM.ova.sha256'
```

Nilai hash harus sama. Hash OVA memeriksa keutuhan file setelah transfer; manifest di dalam OVA mencatat checksum komponen arsip.

### Uji sebelum distribusi

1. Impor OVA sebagai VM baru dengan nama berbeda.
2. Buat alamat MAC baru saat impor jika tersedia.
3. Pilih adapter jaringan yang tersedia pada komputer penguji.
4. Jalankan VM.
5. Uji boot, login, alamat IP, dan aplikasi peserta.

Simpan salinan sumber sampai hasil impor dan aplikasi selesai diuji.

## 6. Jaringan PTLabs2026 untuk peserta

1. Gunakan **Host-only Adapter** untuk jaringan lab aplikasi yang sengaja rentan.
2. Pilih adapter host-only yang tersedia pada komputer peserta.
3. Hubungkan Kali Linux ke jaringan host-only yang sama jika digunakan.
4. Periksa IP Ubuntu melalui terminal:

```bash
hostname -I
```

5. Dari browser komputer peserta atau Kali, buka `http://IP-VM:8084`.
6. Halaman latihan: `http://IP-VM:8084/lab.php`.
7. Gunakan `http://localhost:8084` jika browser berjalan di dalam VM lab itu sendiri.

Alamat IP dapat berbeda pada setiap komputer. Alamat layanan di atas berasal dari deskripsi VM sumber; layanan belum diuji pada hasil ekspor ini.

## 7. Hasil ekspor PTLabs2026 sebelumnya

- Sumber: snapshot **Fresh PTLabs 2026**.
- File: `PTLabs2026.ova`.
- Ukuran: **7.874.707.968 byte**, sekitar **7,87 GB** atau **7,33 GiB**.
- Konfigurasi: **2 CPU**, **RAM 4096 MB**.
- Kapasitas virtual disk: **512 GiB**, berbeda dari ukuran aktual OVA.
- Checksum manifest OVF dan VMDK: **lulus**.
- Simulasi impor VirtualBox 7.1.4: **berhasil**.
- Boot dan layanan aplikasi: **belum diuji**.

SHA-256 OVA hasil ekspor:

```text
f7d80738946e0dc4190ec2adb0f912bdcb4e599f21fa1ce08373d638889fd733
```

## 8. Berkas untuk peserta

- File `.ova` yang sudah selesai diekspor.
- File `.ova.sha256` untuk memeriksa keutuhan setelah transfer.
- Petunjuk impor, pengaturan jaringan, akun latihan yang diperlukan, dan alamat layanan.
