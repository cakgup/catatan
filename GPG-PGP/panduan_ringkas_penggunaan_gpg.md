# Panduan Ringkas Penggunaan GPG

## 1. Melihat Key ID dan Fingerprint

```bash
gpg --list-keys --with-fingerprint --keyid-format LONG
```

Contoh:

```text
pub   rsa4096/1234567890ABCDEF 2026-07-20 [SC]
      AABB CCDD EEFF 0011 2233  4455 6677 8899 AABB CCDD
```

- **Long Key ID:** `1234567890ABCDEF`
- **Fingerprint:** `AABB CCDD EEFF 0011 2233 4455 6677 8899 AABB CCDD`

Gunakan **fingerprint lengkap** untuk menghindari salah memilih key.

---

## 2. Ekspor Public Key

Format teks:

```bash
gpg --armor --output PublicKey.asc --export FINGERPRINT_ANDA
```

Format biner:

```bash
gpg --output PublicKey.pgp --export FINGERPRINT_ANDA
```

File `PublicKey.asc` atau `PublicKey.pgp` boleh dibagikan kepada orang lain.

---

## 3. Impor Public Key

```bash
gpg --import PublicKey.asc
```

Periksa fingerprint setelah impor:

```bash
gpg --fingerprint
```

---

## 4. Mengenkripsi File

Untuk mengenkripsi file menggunakan public key penerima:

```bash
gpg --output dokumen-rahasia.pgp     --encrypt     --recipient FINGERPRINT_PENERIMA     dokumen.pdf
```

File hasilnya hanya dapat dibuka dengan private key penerima.

---

## 5. Mendekripsi File

```bash
gpg --output dokumen.pdf     --decrypt dokumen-rahasia.pgp
```

GPG akan meminta passphrase private key apabila diperlukan.

---

## 6. Menandatangani File

```bash
gpg --armor     --local-user FINGERPRINT_ANDA     --detach-sign dokumen.pdf
```

Hasil:

```text
dokumen.pdf.asc
```

---

## 7. Memverifikasi Tanda Tangan

```bash
gpg --verify dokumen.pdf.asc dokumen.pdf
```

Pastikan fingerprint penandatangan sesuai dengan fingerprint yang dipublikasikan.

---

## 8. Enkripsi Sekaligus Tanda Tangan

```bash
gpg --output dokumen-rahasia.pgp     --encrypt     --sign     --local-user FINGERPRINT_ANDA     --recipient FINGERPRINT_PENERIMA     dokumen.pdf
```

---

## Informasi yang Boleh Dibagikan

- Public key: `PublicKey.asc` atau `PublicKey.pgp`
- Fingerprint public key
- Long Key ID
- Nama dan alamat email pada key

## Informasi yang Tidak Boleh Dibagikan

- Private key
- Backup private key
- Passphrase
- Isi direktori `~/.gnupg/private-keys-v1.d/`
- Sertifikat pencabutan kecuali memang akan mencabut key

---

## Perintah Cepat

```bash
# Melihat key
gpg --list-keys --with-fingerprint --keyid-format LONG

# Ekspor public key
gpg --armor --export FINGERPRINT_ANDA > PublicKey.asc

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
