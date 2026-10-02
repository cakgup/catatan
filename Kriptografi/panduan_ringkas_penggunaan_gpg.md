# Panduan Ringkas Membuat dan Menggunakan GPG

Panduan ini mencakup pembuatan key GPG baru, melihat fingerprint dan Key ID, mengekspor public key, enkripsi, dekripsi, tanda tangan digital, dan verifikasi.

---

## 1. Memastikan GPG Sudah Terpasang

Periksa versi GPG:

```bash
gpg --version
```

Jika belum terpasang pada Debian, Ubuntu, atau Kali Linux:

```bash
sudo apt update
sudo apt install gnupg -y
```

---

## 2. Membuat Key GPG Baru

Jalankan:

```bash
gpg --full-generate-key
```

Gunakan pilihan yang disarankan:

```text
Jenis key     : RSA and RSA
Ukuran key    : 4096 bit
Masa berlaku  : 2y atau sesuai kebutuhan
Real name     : Nama lengkap
Email         : alamat@email.com
Comment       : boleh dikosongkan
```

Contoh masa berlaku:

```text
2y
```

Artinya key berlaku selama dua tahun.

Pilihan lain:

```text
0
```

Artinya key tidak memiliki tanggal kedaluwarsa.

Setelah data dikonfirmasi, masukkan passphrase yang kuat. Passphrase digunakan untuk melindungi private key.

---

## 3. Melihat Public Key

```bash
gpg --list-keys
```

Tampilan lebih lengkap:

```bash
gpg --list-keys --with-fingerprint --keyid-format LONG
```

Contoh output:

```text
pub   rsa4096/1234567890ABCDEF 2026-07-20 [SC] [expires: 2028-07-20]
      AABB CCDD EEFF 0011 2233  4455 6677 8899 AABB CCDD
uid                 Nama Lengkap <alamat@email.com>
sub   rsa4096/FFEEDDCCBBAA9988 2026-07-20 [E] [expires: 2028-07-20]
```

Keterangan:

- `pub` adalah primary public key.
- `sub` adalah subkey, biasanya digunakan untuk enkripsi.
- `[SC]` berarti key dapat digunakan untuk signing dan certification.
- `[E]` berarti subkey digunakan untuk encryption.
- Bagian setelah `/` pada baris `pub` adalah Long Key ID.
- Baris 40 karakter heksadesimal adalah fingerprint.

Pada contoh di atas:

```text
Long Key ID : 1234567890ABCDEF
Fingerprint : AABB CCDD EEFF 0011 2233 4455 6677 8899 AABB CCDD
```

Fingerprint lengkap adalah identitas utama key dan lebih aman digunakan dibandingkan Key ID.

---

## 4. Melihat Private atau Secret Key

```bash
gpg --list-secret-keys
```

Tampilan lengkap:

```bash
gpg --list-secret-keys --with-fingerprint --keyid-format LONG
```

Jika key tampil pada daftar ini, berarti private key tersedia pada komputer tersebut.

---

## 5. Menampilkan Fingerprint Berdasarkan Email

```bash
gpg --fingerprint alamat@email.com
```

Atau menggunakan Long Key ID:

```bash
gpg --fingerprint 1234567890ABCDEF
```

Fingerprint boleh dibagikan ke publik untuk membantu orang lain memverifikasi public key Anda.

---

## 6. Ekspor Public Key

### Format teks ASCII

```bash
gpg --armor     --output PublicKey.asc     --export FINGERPRINT_ANDA
```

Contoh:

```bash
gpg --armor     --output PublicKey.asc     --export AABBCCDDEEFF00112233445566778899AABBCCDD
```

### Format biner PGP

```bash
gpg --output PublicKey.pgp     --export FINGERPRINT_ANDA
```

File berikut boleh dibagikan:

```text
PublicKey.asc
PublicKey.pgp
```

Periksa public key hasil ekspor:

```bash
gpg --show-keys --with-fingerprint PublicKey.asc
```

---

## 7. Backup Private Key

Buat backup private key:

```bash
umask 077

gpg --armor     --output PrivateKey-backup.asc     --export-secret-keys FINGERPRINT_ANDA
```

Periksa izin file:

```bash
ls -l PrivateKey-backup.asc
```

Simpan file ini pada media terenkripsi atau penyimpanan offline.

> Jangan pernah membagikan file private key atau passphrase kepada orang lain.

---

## 8. Sertifikat Pencabutan

GnuPG biasanya membuat sertifikat pencabutan secara otomatis di:

```text
~/.gnupg/openpgp-revocs.d/
```

Periksa:

```bash
ls -l ~/.gnupg/openpgp-revocs.d/
```

Sertifikat pencabutan digunakan ketika private key hilang, bocor, atau tidak lagi ingin digunakan.

---

## 9. Impor Public Key

Impor public key milik orang lain:

```bash
gpg --import PublicKey.asc
```

Atau:

```bash
gpg --import PublicKey.pgp
```

Periksa fingerprint setelah impor:

```bash
gpg --fingerprint
```

Cocokkan fingerprint dengan informasi yang diberikan oleh pemilik key melalui saluran tepercaya.

---

## 10. Mengenkripsi File

Untuk mengenkripsi file menggunakan public key penerima:

```bash
gpg --output dokumen-rahasia.pgp     --encrypt     --recipient FINGERPRINT_PENERIMA     dokumen.pdf
```

Contoh singkat:

```bash
gpg -e -r FINGERPRINT_PENERIMA dokumen.pdf
```

Hasil default:

```text
dokumen.pdf.gpg
```

File tersebut hanya dapat dibuka menggunakan private key penerima.

---

## 11. Mengenkripsi untuk Diri Sendiri

```bash
gpg --output backup-rahasia.pgp     --encrypt     --recipient FINGERPRINT_ANDA     backup.zip
```

Gunakan cara ini jika file ingin dibuka kembali menggunakan private key Anda sendiri.

---

## 12. Mendekripsi File

```bash
gpg --output dokumen.pdf     --decrypt dokumen-rahasia.pgp
```

Versi singkat:

```bash
gpg -o dokumen.pdf -d dokumen-rahasia.pgp
```

GPG akan memilih private key yang sesuai dan meminta passphrase jika diperlukan.

---

## 13. Menandatangani File

Buat detached signature dalam format ASCII:

```bash
gpg --armor     --local-user FINGERPRINT_ANDA     --detach-sign dokumen.pdf
```

Hasil:

```text
dokumen.pdf.asc
```

File asli tetap tidak berubah. File `.asc` berisi tanda tangan digital.

---

## 14. Memverifikasi Tanda Tangan

Penerima membutuhkan:

```text
dokumen.pdf
dokumen.pdf.asc
```

Verifikasi:

```bash
gpg --verify dokumen.pdf.asc dokumen.pdf
```

Pastikan fingerprint penandatangan sesuai dengan fingerprint yang dipublikasikan.

---

## 15. Enkripsi Sekaligus Tanda Tangan

```bash
gpg --output dokumen-rahasia.pgp     --encrypt     --sign     --local-user FINGERPRINT_ANDA     --recipient FINGERPRINT_PENERIMA     dokumen.pdf
```

Keterangan:

- `--local-user` memilih private key Anda untuk tanda tangan.
- `--recipient` memilih public key penerima untuk enkripsi.

---

## 16. Informasi yang Boleh Dibagikan

Informasi berikut aman untuk dibagikan:

```text
Nama
Alamat email pada key
PublicKey.asc
PublicKey.pgp
Fingerprint public key
Long Key ID
```

Contoh informasi publik:

```text
Nama        : Nama Lengkap
Email       : alamat@email.com
Key ID      : 1234567890ABCDEF
Fingerprint : AABB CCDD EEFF 0011 2233 4455 6677 8899 AABB CCDD
```

---

## 17. Informasi yang Tidak Boleh Dibagikan

Jangan membagikan:

```text
PrivateKey-backup.asc
Passphrase
Isi ~/.gnupg/private-keys-v1.d/
File secret key
Sertifikat pencabutan sebelum key memang akan dicabut
```

---

## 18. Perintah Cepat

```bash
# Cek versi GPG
gpg --version

# Buat key baru
gpg --full-generate-key

# Lihat public key, Key ID, dan fingerprint
gpg --list-keys --with-fingerprint --keyid-format LONG

# Lihat private key
gpg --list-secret-keys --with-fingerprint --keyid-format LONG

# Tampilkan fingerprint berdasarkan email
gpg --fingerprint alamat@email.com

# Ekspor public key
gpg --armor --export FINGERPRINT_ANDA > PublicKey.asc

# Backup private key
gpg --armor --export-secret-keys FINGERPRINT_ANDA > PrivateKey-backup.asc

# Periksa public key dari file
gpg --show-keys --with-fingerprint PublicKey.asc

# Impor public key
gpg --import PublicKey.asc

# Enkripsi
gpg -e -r FINGERPRINT_PENERIMA file.txt

# Dekripsi
gpg -o file.txt -d file.txt.gpg

# Tanda tangan
gpg -u FINGERPRINT_ANDA --armor --detach-sign file.txt

# Verifikasi
gpg --verify file.txt.asc file.txt
```

---

## Alur Paling Sederhana

### Pemilik key

```bash
gpg --full-generate-key
gpg --list-keys --with-fingerprint --keyid-format LONG
gpg --armor --export FINGERPRINT_ANDA > PublicKey.asc
```

Bagikan:

```text
PublicKey.asc
Fingerprint lengkap
```

### Penerima public key

```bash
gpg --import PublicKey.asc
gpg --fingerprint
gpg -e -r FINGERPRINT_PEMILIK file.txt
```

### Pemilik key membuka file

```bash
gpg -o file.txt -d file.txt.gpg
```
