# LAPORAN HASIL PENGUJIAN KEAMANAN

**Penetration Testing Report**

| Informasi | Detail |
|---|---|
| Penguji Penetrasi | Tohirin |
| Target | `jobportal.vulnapp.id` |
| Jenis Pengujian | Black Box |
| Waktu Pengujian | Rabu, 09-09-2026 |
| Klasifikasi | **RAHASIA** |

---

## 1. Executive Summary

Telah dilakukan pengujian terhadap aplikasi Portal Kerja yang memiliki alamat domain `jobportal.vulnapp.id` dengan menggunakan metode pengujian **Black Box**. Pengujian berfokus pada kontrol akses, otorisasi antar objek, validasi input, dan penanganan file upload.

Pengujian mengidentifikasi **7 temuan kerentanan**. Dua temuan berada pada tingkat **Critical**, dua temuan pada tingkat **High**, dan tiga temuan pada tingkat **Medium**. Risiko terbesar berasal dari **SQL Injection** yang memungkinkan bypass login dan pembacaan struktur data sensitif, serta kelemahan authorization pada endpoint company.

| Tingkat Keparahan | Jumlah Temuan |
|---|---:|
| Critical | 2 |
| High | 2 |
| Medium | 3 |
| Low | 0 |
| Informational | 0 |

### Rekomendasi Utama

Akar masalah utama yang muncul pada sebagian besar temuan adalah validasi input dan otorisasi server-side yang belum konsisten.

- Prioritaskan perbaikan SQL Injection pada login dan API search dengan prepared statement atau parameterized query.
- Terapkan object-level authorization pada seluruh endpoint yang memakai ID aplikasi, job, atau objek milik company.
- Perketat validasi file upload agar hanya file gambar yang benar-benar valid yang dapat diterima.
- Terapkan output encoding dan sanitasi input untuk seluruh data user-generated content.
- Matikan verbose error SQL pada production dan gunakan pesan error generik.

---

## 2. Tabel Daftar Temuan

Berikut adalah ringkasan seluruh temuan yang diidentifikasi selama pengujian, diurutkan berdasarkan tingkat keparahan.

| No | Judul Temuan | Severity |
|---:|---|---|
| 1 | SQL Injection pada Form Login menyebabkan Authentication Bypass | **Critical** |
| 2 | SQL Injection pada API Search menyebabkan Database Disclosure | **Critical** |
| 3 | IDOR pada Update Status Applicant | **High** |
| 4 | IDOR pada Edit Job | **High** |
| 5 | Unrestricted File Upload pada Profile Image | **Medium** |
| 6 | Stored XSS pada Form Apply Job | **Medium** |
| 7 | Stored XSS pada Field Education Profile | **Medium** |

---

## 3. Detail Temuan

### Temuan 1: SQL Injection pada Form Login menyebabkan Authentication Bypass

**Severity:** Critical

#### Deskripsi

Field username pada proses login tidak memproses input menggunakan query terparameter. Payload SQL comment dapat mengubah logika autentikasi sehingga aplikasi menganggap penyerang sebagai akun yang disebutkan pada input username.

#### Endpoint

```http
POST /login
```

#### URL PoC

`https://jobportal.vulnapp.id/login`

#### Langkah Proof of Concept (PoC)

- Buka halaman login `https://jobportal.vulnapp.id/login`.
- Masukkan payload `admin' -- -` pada field username, lalu submit form login.
- Aplikasi langsung membuat sesi sebagai akun dengan username `admin` tanpa membutuhkan password akun tersebut.
- Ulangi dengan payload `212' -- -`. Aplikasi membuat sesi sebagai akun dengan username `212`.

#### Request atau Payload

```text
Username: admin' -- -
Password: <nilai apa pun atau kosong, sesuai perilaku form>
```

#### Bukti Screenshot

Bukti screenshot tersedia pada **halaman 4 PDF sumber**.

#### Dampak

Penyerang dapat mengambil alih akun pengguna atau admin tanpa kredensial valid. Jika akun privileged berhasil diakses, penyerang dapat membaca atau mengubah data sensitif dan menyalahgunakan fungsi administratif.

#### Skor CVSS

```text
CVSS:4.0/AV:N/AC:L/AT:N/PR:N/UI:N/VC:H/VI:H/VA:N/SC:N/SI:N/SA:N
CVSS-B: 9.3 Critical
```

#### Rekomendasi Perbaikan

- Gunakan prepared statement atau parameterized query pada seluruh query autentikasi.
- Jangan menyusun query SQL dari string input pengguna.
- Tambahkan monitoring dan rate limiting untuk percobaan login yang mengandung karakter SQL metacharacter.

---

### Temuan 2: SQL Injection pada API Search menyebabkan Database Disclosure

**Severity:** Critical

#### Deskripsi

Parameter keyword pada API pencarian job dipakai langsung di query SQL. Ketika karakter kutip tunggal dikirimkan, aplikasi mengembalikan error SQL MySQL. Pengujian lanjutan menunjukkan tabel `users` pada database `job_search_db` dapat diekstraksi.

#### Endpoint

```http
GET /api/jobs/search?keyword={keyword}
```

#### URL PoC

`https://jobportal.vulnapp.id/api/jobs/search?keyword=joni`

#### Langkah Proof of Concept (PoC)

- Buka endpoint pencarian dengan keyword normal.
- Lakukan inspect element pada browser dan pada tab Network lihat URL pencarian kemudian akses.
- Tambahkan karakter kutip tunggal pada parameter `keyword`.
- Aplikasi mengembalikan error SQL MySQL yang menunjukkan input masuk ke query tanpa parameterisasi.
- Pengujian lanjutan terhadap parameter `keyword` berhasil mengidentifikasi struktur tabel `users` pada database `job_search_db`.

#### Request atau Payload

```http
GET /api/jobs/search?keyword=joni' HTTP/1.1
Host: jobportal.vulnapp.id
```

#### Response

```json
{
  "message": "Search error: Error 1064 (42000): You have an error in your SQL syntax; check the manual that corresponds to your MySQL server version for the right syntax to use near '''', '%')' at line 2",
  "success": false
}
```

#### Bukti Tambahan

Kolom yang berhasil teridentifikasi:

`id`, `username`, `email`, `password`, `role`, `full_name`, `phone`, `address`, `profile_image`, `cv_file`, `company_name`, `company_description`, `website`, `created_at`, `updated_at`.

#### Bukti Screenshot

Bukti screenshot tersedia pada **halaman 6 PDF sumber**.

#### Dampak

Penyerang dapat membaca data sensitif pengguna, termasuk email, password, role, nomor telepon, alamat, file CV, dan informasi perusahaan. Kerentanan ini berpotensi menyebabkan kebocoran data massal dan pengambilalihan akun apabila password dapat disalahgunakan.

#### Skor CVSS

```text
CVSS:4.0/AV:N/AC:L/AT:N/PR:N/UI:N/VC:H/VI:H/VA:H/SC:N/SI:N/SA:N
CVSS-B: 9.3 Critical
```

#### Rekomendasi Perbaikan

- Gunakan parameterized query pada endpoint pencarian.
- Matikan verbose SQL error di production dan gunakan pesan error generik untuk klien.
- Batasi privilege user database aplikasi agar tidak memiliki akses berlebihan ke tabel sensitif.

---

### Temuan 3: IDOR pada Update Status Applicant

**Severity:** High

#### Deskripsi

Endpoint update status applicant mempercayai ID aplikasi yang dikirim melalui path tanpa memverifikasi bahwa application tersebut terkait dengan job milik company yang sedang login.

#### Endpoint

```http
PUT /api/applications/{id}
```

#### URL PoC

`https://jobportal.vulnapp.id/applicants`

#### Langkah Proof of Concept (PoC)

- Login sebagai company.
- Buka halaman applicants `https://jobportal.vulnapp.id/applicants`.
- Accept atau reject salah satu applicant, lalu intercept request menggunakan Burp Suite.
- Ubah ID pada path dari `/api/applications/100` menjadi ID lain, misalnya `/api/applications/105`.
- Kirim request. Status applicant pada ID target berubah sesuai nilai status yang dikirim.

#### Request atau Payload

```http
PUT /api/applications/105 HTTP/1.1
Host: jobportal.vulnapp.id
Content-Type: application/json
Cookie: JSESSIONID=<REDACTED>

{"status":"accept"}
```

#### Bukti Screenshot

Bukti screenshot tersedia pada **halaman 7 PDF sumber**.

#### Dampak

Company dapat mengubah status lamaran milik company lain menjadi accept atau reject. Dampaknya adalah manipulasi proses rekrutmen dan hilangnya integritas data lintas tenant.

#### Skor CVSS

```text
CVSS:4.0/AV:N/AC:L/AT:N/PR:L/UI:N/VC:L/VI:H/VA:N/SC:N/SI:N/SA:N
CVSS-B: 7.1 High
```

#### Rekomendasi Perbaikan

- Validasi bahwa application ID yang diubah memang terkait dengan job milik company yang sedang login.
- Ambil identitas company dari session atau token server-side, bukan dari input pengguna.
- Tambahkan test otorisasi untuk akses lintas company pada seluruh endpoint application.

---

### Temuan 4: IDOR pada Edit Job

**Severity:** High

#### Deskripsi

Fitur edit job tidak memvalidasi bahwa job ID yang diedit adalah milik company yang sedang login. Penyerang dengan akun company dapat mengganti ID pada path request untuk mengubah job milik company lain.

#### Endpoint

```http
PUT /api/jobs/{id}
```

#### URL PoC

`https://jobportal.vulnapp.id/post-job`

#### Langkah Proof of Concept (PoC)

- Login sebagai company.
- Buka halaman post job `https://jobportal.vulnapp.id/post-job` dan edit salah satu job.
- Intercept request update job.
- Ubah ID pada path `/api/jobs/15` menjadi ID job lain.
- Kirim request. Data job dengan ID target berubah sesuai payload.

#### Request atau Payload

```http
PUT /api/jobs/15 HTTP/1.1
Host: jobportal.vulnapp.id
Content-Type: application/json
Cookie: JSESSIONID=<REDACTED>

{"companyId":1498,"title":"212","description":"212","requirements":"2121","location":"212","jobType":"full-time","salaryMin":212,"salaryMax":212,"status":"active"}
```

#### Bukti Screenshot

Bukti screenshot tersedia pada **halaman 9 PDF sumber**.

#### Dampak

Company dapat mengubah lowongan kerja milik company lain. Kerentanan ini merusak integritas data lowongan, reputasi perusahaan, dan kepercayaan pengguna terhadap aplikasi.

#### Skor CVSS

```text
CVSS:4.0/AV:N/AC:L/AT:N/PR:L/UI:N/VC:L/VI:H/VA:N/SC:N/SI:N/SA:
CVSS-B: 7.1 High
```

#### Rekomendasi Perbaikan

- Validasi kepemilikan job sebelum menjalankan update.
- Jangan menerima `companyId` dari body sebagai sumber otorisasi. Gunakan `companyId` dari session server-side.
- Terapkan object-level authorization pada seluruh endpoint job management.

---

### Temuan 5: Unrestricted File Upload pada Profile Image

**Severity:** Medium

#### Deskripsi

Fitur upload profile image menerima file dengan ekstensi `.php`. File tersebut disimpan pada direktori publik `/uploads/profile/` dan dapat diakses kembali melalui URL langsung.

#### Endpoint

```http
POST /api/user/upload-profile-image
```

#### URL PoC

`https://jobportal.vulnapp.id/profile`

#### Langkah Proof of Concept (PoC)

- Login ke aplikasi.
- Buka halaman profile `https://jobportal.vulnapp.id/profile`.
- Pada fitur Upload Profile Image, upload file bernama `cmd.php`.
- Aplikasi menerima file tersebut dan menyimpannya pada direktori upload publik.
- Akses `https://jobportal.vulnapp.id/uploads/profile/cmd.php`. File dapat diunduh dari lokasi tersebut.

#### Request atau Payload

```text
File upload: cmd.php
Lokasi hasil upload: https://jobportal.vulnapp.id/uploads/profile/cmd.php
```

#### Bukti Screenshot

Bukti screenshot tersedia pada **halaman 11 PDF sumber**.

#### Dampak

Aplikasi mengizinkan file berbahaya disimpan di direktori publik. Jika konfigurasi server mengeksekusi file PHP pada direktori upload, kerentanan ini dapat berkembang menjadi remote code execution. Walaupun file hanya terunduh, penyimpanan file aktif berbahaya tetap meningkatkan risiko penyalahgunaan.

#### Skor CVSS

```text
CVSS:4.0/AV:N/AC:L/AT:N/PR:L/UI:N/VC:L/VI:L/VA:N/SC:N/SI:N/SA:N
CVSS-B: 6.9 Medium
```

#### Rekomendasi Perbaikan

- Batasi ekstensi file hanya ke format gambar yang dibutuhkan, seperti `jpg`, `jpeg`, `png`, dan `webp`.
- Validasi MIME type dan file signature, bukan hanya ekstensi.
- Simpan file dengan nama acak di lokasi non executable dan nonaktifkan eksekusi script pada direktori upload.

---

### Temuan 6: Stored XSS pada Form Apply Job

**Severity:** Medium

#### Deskripsi

Input pada form *Apply for this job* disimpan dan ditampilkan kembali pada halaman applicants tanpa output encoding yang memadai. Payload berbentuk link JavaScript dapat dieksekusi ketika company membuka detail applicant dan mengklik link tersebut.

#### Endpoint

```http
POST /jobs/{id}/apply
```

atau endpoint apply job terkait.

#### URL PoC

- `https://jobportal.vulnapp.id/jobs/14`
- `https://jobportal.vulnapp.id/applicants`

#### Langkah Proof of Concept (PoC)

- Login sebagai user pencari kerja.
- Buka daftar job `https://jobportal.vulnapp.id/jobs` dan pilih salah satu job, misalnya `https://jobportal.vulnapp.id/jobs/14`.
- Pada form *Apply for this job*, masukkan payload HTML berisi link JavaScript.
- Login sebagai company dan buka `https://jobportal.vulnapp.id/applicants`.
- View detail applicant dan klik link **Saya daftar**. JavaScript tereksekusi di browser company.

#### Request atau Payload

```html
<a href=javascript:alert(document.cookie);>Saya daftar!</a>
```

#### Bukti Screenshot

Bukti screenshot tersedia pada **halaman 12 PDF sumber**.

#### Dampak

Penyerang dapat menjalankan JavaScript pada browser company. Dampak yang mungkin terjadi meliputi pencurian session, aksi atas nama company, dan phishing internal.

#### Skor CVSS

```text
CVSS:4.0/AV:N/AC:L/AT:N/PR:L/UI:A/VC:L/VI:L/VA:N/SC:N/SI:N/SA:N
Skor dasar estimasi: CVSS-B: 4.8 Medium
```

#### Rekomendasi Perbaikan

- Lakukan output encoding pada seluruh data user-generated sebelum ditampilkan.
- Blokir skema URL berbahaya seperti `javascript:` pada atribut `href`.
- Terapkan Content Security Policy yang membatasi eksekusi inline script dan navigasi berbahaya.

---

### Temuan 7: Stored XSS pada Field Education Profile

**Severity:** Medium

#### Deskripsi

Field Education pada halaman profile menerima input HTML berbahaya dan menampilkannya kembali tanpa sanitasi atau output encoding yang memadai.

#### Endpoint

```http
POST /api/education
```

#### URL PoC

`https://jobportal.vulnapp.id/profile`

#### Langkah Proof of Concept (PoC)

- Login sebagai user pencari kerja.
- Buka halaman profile `https://jobportal.vulnapp.id/profile`.
- Pada form Education, tambahkan payload HTML berisi link JavaScript.
- Simpan profile.
- Saat data education ditampilkan dan link diklik, JavaScript tereksekusi.

#### Request atau Payload

```html
<a href=javascript:alert(document.cookie)>Universitas Alam</a>
```

#### Bukti Screenshot

Bukti screenshot tersedia pada **halaman 14 PDF sumber**.

#### Dampak

Stored XSS dapat menyerang user atau company yang melihat profil pelamar. Dampaknya meliputi pencurian session, aksi tidak sah dari browser korban, dan manipulasi tampilan aplikasi.

#### Skor CVSS

```text
CVSS:4.0/AV:N/AC:L/AT:N/PR:L/UI:A/VC:L/VI:L/VA:N/SC:N/SI:N/SA:N
CVSS-B: 4.8 Medium
```

#### Rekomendasi Perbaikan

- Sanitasi field Education menggunakan allowlist ketat atau tampilkan seluruh input sebagai teks biasa.
- Terapkan output encoding konsisten di seluruh halaman profile dan applicants.
- Tambahkan validasi otomatis untuk menolak input HTML dan URL dengan skema `javascript:`.

---

## 4. Lampiran

### A. Ruang Lingkup & Metodologi Pengujian

Pengujian dilakukan pada aplikasi `jobportal.vulnapp.id` dengan metode **Black Box**. Area yang diuji meliputi login, pencarian job, profile, upload file, apply job, applicants, dan fitur edit job. Fokus pengujian mencakup validasi input, SQL Injection, Cross-Site Scripting, file upload, serta kontrol akses/otorisasi antar objek.

### B. Tools yang Digunakan

- **Burp Suite Community** — intercepting proxy dan modifikasi request.
- **Browser DevTools** — observasi request/response dan validasi perilaku aplikasi.
- **sqlmap** — validasi SQL Injection pada endpoint pencarian job.

### C. Batasan Pengujian

Pengujian dilakukan berdasarkan fitur dan endpoint yang berhasil diakses selama periode pengujian. Tidak dilakukan pengujian destruktif seperti penghapusan data massal, eksploitasi lanjutan server-side, brute force skala besar, atau persistence pada server.

---

> **Catatan:** Versi Markdown ini mempertahankan isi teks dan struktur utama laporan. Bukti screenshot tetap dirujuk ke halaman pada PDF sumber agar file `.md` tetap ringkas dan portabel.
