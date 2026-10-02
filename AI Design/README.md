# AI Design: ChatGPT → Desain → Google Flow

> Panduan ringkas untuk membuat brief, gambar, storyboard, dan video AI secara bertahap. Prompt dibuat pendek agar mudah dipahami, disalin, dan direvisi.

## Mulai Cepat

1. Pilih proyek pada [Peta Proyek](#peta-proyek).
2. Siapkan referensi: produk, karakter, logo, dan data resmi.
3. Jalankan prompt ChatGPT secara berurutan: **Brief → Rencana → Prompt Produksi → QC**.
4. Untuk video, lanjutkan ke [Workflow ChatGPT → Google Flow](#workflow-chatgpt--google-flow).
5. Finalkan teks, logo, harga, tanggal, kontak, dan audio di aplikasi editing.

> [!IMPORTANT]
> Ganti semua teks `[GANTI: ...]`. Jangan mengirim placeholder mentah ke ChatGPT atau Flow.

## Prinsip Prompt Ringkas

Prompt yang efektif tidak harus panjang. Gunakan enam bagian ini:

```text
TUJUAN: hasil yang ingin dibuat.
REFERENSI: fungsi setiap gambar atau data.
LOCK: bagian yang tidak boleh berubah.
ARAH KREATIF: audiens, pesan, gaya, dan format.
OUTPUT: bentuk jawaban yang diminta.
LARANGAN: kesalahan yang harus dihindari.
```

Gunakan satu prompt untuk satu keputusan. Jangan meminta brief, script, storyboard, dan video final sekaligus.

## Optimalisasi ChatGPT

### 1. Mulai dengan konteks proyek

```text
Anda adalah creative strategist dan AI design engineer.

Proyek: [GANTI: nama proyek].
Tujuan: [GANTI: awareness/edukasi/penjualan/event].
Audiens: [GANTI: target audiens].
Platform: [GANTI: Instagram/TikTok/YouTube/Form].
Output akhir: [GANTI: poster/video/storyboard/komik].

Gunakan hanya data dan referensi yang saya berikan. Tandai informasi yang
belum pasti; jangan mengarang klaim, harga, tanggal, atau identitas brand.
Jawab ringkas dalam bahasa Indonesia.
```

Lanjutkan dalam percakapan yang sama agar ChatGPT mempertahankan konteks. Buat percakapan baru jika proyek atau brand berubah.

### 2. Beri nama setiap referensi

```text
Image 1 = master produk.
Image 2 = master karakter.
Image 3 = logo resmi.
Image 4 = referensi lokasi atau mood.

Prioritas: identitas produk/karakter > logo > storyboard > mood.
```

### 3. Minta output terstruktur

Gunakan tabel untuk brief dan shot plan. Gunakan blok kode hanya untuk prompt yang akan dipindahkan ke tool lain.

### 4. Kunci hasil yang sudah disetujui

```text
Brief ini disetujui. Jadikan sebagai sumber kebenaran proyek.
Jangan mengubah PRODUCT LOCK, CHARACTER LOCK, data resmi, atau CTA kecuali
saya meminta secara eksplisit.
```

### 5. Revisi satu masalah sekali jalan

```text
Perbaiki hanya: [GANTI: satu masalah].
Lokasi masalah: [GANTI: scene/shot/panel].
Pertahankan: [GANTI: bagian yang sudah benar].
Jangan mendesain ulang elemen lain.
```

## Referensi Visual Fondasi

Gunakan visual berikut sebagai referensi cepat. Klik gambar untuk membukanya dalam ukuran penuh.

| Workflow desain konten | Delapan gaya visual |
|---|---|
| <a href="media/image19.jpeg"><img src="media/image19.jpeg" alt="Infografis workflow desain konten dengan AI" width="320"></a> | <a href="media/image20.jpeg"><img src="media/image20.jpeg" alt="Infografis delapan gaya visual" width="320"></a> |
| **Kata kunci kualitas gambar** | **Kode warna HEX** |
| <a href="media/image21.jpeg"><img src="media/image21.jpeg" alt="Infografis kata kunci kualitas gambar AI" width="320"></a> | <a href="media/image22.jpeg"><img src="media/image22.jpeg" alt="Infografis daftar warna dan kode HEX" width="320"></a> |
| **Kombinasi palet warna** | |
| <a href="media/image23.jpeg"><img src="media/image23.jpeg" alt="Infografis kombinasi palet warna" width="320"></a> | |

### Prompt Menentukan Arah Visual — Siap Salin ke ChatGPT

Unggah `image19.jpeg`–`image23.jpeg`, lalu gunakan:

```text
Analisis lima infografis yang saya unggah sebagai panduan desain, bukan sebagai
layout yang harus ditiru. Untuk proyek [GANTI: nama/tema], tentukan:
1. struktur Judul → Hook → Isi → Caption → CTA;
2. satu gaya utama dari image20;
3. maksimal dua kata kunci kualitas dari image21;
4. satu palet 3–5 warna dari image22/image23 beserta fungsi dan kode HEX;
5. rasio, hierarchy, negative space, dan safe area.

Jelaskan pilihan dalam satu tabel ringkas. Jangan mencampur banyak gaya,
jangan menjanjikan resolusi cetak hanya dari kata “Ultra HD”, dan pastikan
kontras teks cukup kuat.
```

## Prompt Inti ChatGPT

### Aturan Visual Match

Setiap kali memakai gambar referensi, tulis fungsi gambarnya secara eksplisit:

```text
REFERENCE HIERARCHY:
1. MASTER SUBJECT = sumber kebenaran bentuk, wajah, warna, dan atribut.
2. CHARACTER/PRODUCT SHEET = sumber sudut, ekspresi, detail, dan proporsi.
3. STORYBOARD = sumber urutan shot, framing, aksi, dan timing saja.
4. STYLE/MOOD = sumber lighting, palette, texture, dan atmosphere saja.

Jika dua referensi bertentangan, ikuti urutan prioritas di atas.
Jangan menyalin grid, label, panel border, atau teks dari reference sheet dan
storyboard ke output final.
```

### P1 — Analisis dan Brief

```text
Analisis semua gambar referensi sebelum menyusun brief. Sebutkan fungsi setiap
gambar dan jangan mulai produksi pada jawaban ini.

Pisahkan:
1. Fakta yang terlihat atau terverifikasi.
2. Asumsi kreatif yang aman.
3. Data yang harus dikonfirmasi.

Buat VISUAL LOCK terukur: bentuk/silhouette, proporsi, warna, material visual,
wajah, pakaian, aksesori, logo/label, style, lighting, dan elemen terlarang.
Setelah itu buat brief ringkas berisi tujuan, audiens, pesan utama, format,
batas klaim, dan kriteria QC. Output maksimal 2 tabel; tanpa prompt produksi.
```

### P2 — Ide dan Pilihan Arah

```text
Berdasarkan brief yang disetujui, buat 5 creative angle.
Untuk setiap angle tulis: hook, ide visual, manfaat, dan risiko.
Rekomendasikan 1 angle terbaik beserta alasan singkat.
Setiap angle wajib menggunakan MASTER SUBJECT dan VISUAL LOCK yang sama.
Variasikan hanya aksi, kamera, background, lighting, atau mood yang diizinkan.
```

### P3 — Prompt Gambar

```text
Buat satu prompt gambar siap salin berdasarkan brief, VISUAL LOCK, dan angle
terpilih. Sebut nama file serta fungsi reference di dalam prompt.

Wajib memuat: ciri subjek yang terlihat, aksi, framing, komposisi, gaya,
lighting, palet HEX, rasio, negative space, LOCK, dan negative prompt.
Instruksikan model agar tidak menyalin layout/grid/teks dari reference sheet.
Teks/logo final akan ditempel manual.
Output hanya satu blok kode; tanpa penjelasan tambahan.
```

### P4 — Script dan Shot Plan Video

```text
Buat script dan shot plan video [GANTI: durasi] detik, rasio [GANTI: rasio].

Gunakan brief dan angle yang disetujui. Hook harus muncul pada 0–2 detik.
Satu shot hanya memiliki satu aksi utama.
Tampilkan tabel: waktu, tujuan shot, visual, aksi, camera, VO/teks, audio,
continuity lock, first frame, dan end frame. Akhiri dengan CTA.
Setiap deskripsi visual wajib mengulang ciri MASTER SUBJECT yang terlihat;
jangan hanya menulis “karakter/produk yang sama”.
```

### P5 — Storyboard

```text
Ubah shot plan yang disetujui menjadi storyboard production sheet.

Setiap panel harus memuat: timecode, framing, aksi, arah kamera, dialog/VO,
audio, dan continuity. Pertahankan produk/karakter dari master reference.
Rasio [GANTI: rasio]. Jangan menambahkan scene baru. Jangan membuat teks
dekoratif selain label produksi yang diminta. Sebelum generate, tulis ulang
VISUAL LOCK pada bagian atas prompt storyboard.
```

### P6 — Paket Handoff ke Google Flow

```text
Ubah shot plan yang disetujui menjadi paket Google Flow.

Buat:
1. Master continuity lock maksimal 6 baris.
2. Satu prompt natural-language untuk setiap klip/scene.
3. Daftar reference yang harus diunggah pada setiap klip.
4. First frame dan end frame yang diharapkan.
5. Checklist QC per klip.

Setiap prompt scene harus memuat: subject lock, lokasi, satu aksi utama,
camera, lighting, audio cue, ending frame, dan negative prompt.
Ulangi ciri visual subjek secara eksplisit pada setiap scene; jangan memakai
frasa “same character/product” tanpa deskripsi. Storyboard hanya reference
arah visual: jangan animasikan lembar, grid, border, label, atau tulisannya.
Jangan gunakan JSON. Outputkan setiap prompt dalam blok kode terpisah.
```

## Workflow ChatGPT → Google Flow

Gunakan alur ini untuk semua proyek video. Nama menu, model, durasi, dan fitur dapat berubah mengikuti akun serta versi Flow.

### A. Siapkan di ChatGPT

1. Jalankan P1 dan koreksi fakta.
2. Jalankan P2, lalu setujui satu creative angle.
3. Jalankan P4 dan periksa total durasi.
4. Jalankan P5 bila membutuhkan storyboard visual.
5. Jalankan P6 untuk menghasilkan prompt Flow per klip.
6. Simpan paket: brief, master reference, shot plan, VO, prompt scene, dan checklist QC.

### B. Generate di Google Flow

1. Buat project baru dan pilih output video.
2. Atur rasio sesuai shot plan: umumnya `9:16` untuk Reels/Shorts atau `16:9` untuk landscape.
3. Pilih model dan durasi yang tersedia. Mulai dengan satu hasil uji, bukan banyak variasi.
4. Unggah reference sesuai daftar dari ChatGPT. Utamakan master produk/karakter yang bersih.
5. Generate **satu scene atau satu aksi utama per klip**.
6. Tempel prompt scene dari P6. Jangan tempel seluruh brief atau semua scene sekaligus.
7. Jika fitur frame tersedia, gunakan first frame untuk identitas awal dan end frame untuk transisi ke klip berikutnya.
8. Review klip terhadap continuity lock sebelum lanjut ke scene berikutnya.
9. Unduh klip yang lolos QC, lalu susun, beri VO, musik, logo, dan teks di editor.

> [!TIP]
> Prompt natural-language adalah default yang paling mudah dipindahkan ke Flow. JSON pada panduan lama hanya berguna sebagai dokumentasi internal, bukan format wajib untuk kolom prompt Flow.

### Template Prompt Scene untuk Flow

```text
SCENE [GANTI: nomor] — [GANTI: nama scene], [GANTI: durasi] detik, [GANTI: rasio].

REFERENCE: gunakan [GANTI: nama file] sebagai master [produk/karakter].
LOCK: pertahankan [GANTI: identitas, warna, bentuk, pakaian, logo].
SETTING: [GANTI: lokasi, waktu, mood, lighting].
ACTION: [GANTI: satu aksi utama].
CAMERA: [GANTI: framing dan satu camera movement].
AUDIO CUE: [GANTI: ambience/SFX; VO ditambahkan saat editing].
END FRAME: [GANTI: kondisi akhir untuk menyambung scene berikutnya].

NEGATIVE: no identity drift, no product deformation, no extra limbs,
no flicker, no random text, no logo mutation, no camera jitter, no watermark.
```

### Jika Hasil Flow Bermasalah

```text
Bandingkan hasil Flow ini dengan master reference dan continuity lock.
Sebutkan maksimal 3 error paling penting. Setelah itu tulis ulang prompt scene
secara lebih pendek untuk memperbaiki error tersebut tanpa mengubah komposisi,
aksi, dan elemen yang sudah benar.
```

### QC Visual dengan ChatGPT

Setelah generate, unggah master reference dan satu frame hasil. Jangan meminta revisi sebelum perbedaannya teridentifikasi.

```text
Image A = MASTER REFERENCE. Image B = HASIL GENERATE.

Bandingkan keduanya pada: silhouette/proporsi, wajah, warna, material, pakaian,
aksesori, logo/label, jumlah bagian, style, lighting, dan komposisi. Buat tabel
PASS/FAIL dan sebutkan maksimal 3 perbedaan paling merusak kemiripan.

Setelah audit, tulis satu prompt revisi yang memperbaiki hanya tiga perbedaan
tersebut. Ulangi semua detail yang harus dipertahankan. Jangan mengubah camera,
aksi, background, atau bagian yang sudah PASS.
```

## Cara Memakai Prompt Proyek

- Prompt proyek **gambar** dipakai setelah seluruh gambar yang disebutkan diunggah ke ChatGPT. Jika ingin langsung generate, tambahkan: `Generate gambar sekarang; jangan hanya menjelaskan prompt.`
- Prompt proyek **video** meminta ChatGPT membuat prompt per klip. Tempel setiap blok hasilnya satu per satu ke Google Flow.
- Proyek 02, 05, dan 11 belum memiliki master visual khusus di folder `media`; pengguna wajib mengunggah referensi sendiri.
- Jangan menggabungkan prompt dari dua proyek karena visual lock dan hierarchy-nya berbeda.

## Peta Proyek

| No. | Proyek | Output | Template utama |
|---:|---|---|---|
| 01 | Iklan Sepatu — PVN Taehyung Blue | Flyer + video 10 detik | P1–P6 |
| 02 | Iklan Mainan — Doll Catcher | Video 10 detik | P1, P2, P4–P6 |
| 03 | Iklan Squishy — NeeDoh Nice Cube | Video satisfying 10 detik | P1, P2, P4–P6 |
| 04 | Marketplace — POP SAN Water Slime | Foto + video produk | P1–P6 |
| 05 | Iklan Produk Tanpa Model | Video 10 detik | P1, P4–P6 |
| 06 | Flyer Event → Header Google Form | Flyer + header | P1–P3 |
| 07 | Edukasi Sains Anak — Pelangi | Video 3 scene | P1, P4–P6 |
| 08 | Edukasi Keselamatan — Gempa | Video 3 scene | P1, P4–P6 |
| 09 | Berita Viral Claymation | Video 3 scene | P1, P4–P6 |
| 10 | Animasi Nara & Kiko | Video 3 scene | P1, P4–P6 |
| 11 | Storytelling/Biografi Kartun 2D | Video multi-scene | P1, P4–P6 |
| 12 | AI Influencer & Character Sheet | Character reference | P1–P3 |
| 13 | Video Event Berseri | Video multi-scene | P1, P4–P6 |
| 14 | Komik/Manga dari Brief Event | Komik satu halaman | P1–P3 |

## Panduan Per Proyek

### 01 — Iklan Sepatu

- **Lock:** warna upper, stripe, laces, outsole, silhouette, dan logo.
- **ChatGPT:** P1 → P2 → P3 untuk flyer; P4 → P5 → P6 untuk video.
- **Flow:** buat 5 klip: reveal box, detail, on-feet, walking hero, CTA beauty shot.
- **QC:** outsole dan stripe tidak berubah; klaim produk harus terverifikasi.

| Master reference produk | Contoh storyboard 9:16 |
|---|---|
| <a href="media/image1.png"><img src="media/image1.png" alt="Master reference sneaker PVN Taehyung Blue" width="360"></a> | <a href="media/image2.png"><img src="media/image2.png" alt="Storyboard iklan sneaker PVN vertikal" width="220"></a> |

**Prompt siap salin ke ChatGPT — unggah `image1.png` dan `image2.png`:**

```text
Buat paket produksi gambar dan Google Flow untuk sneaker PVN “Taehyung Blue”.
image1.png adalah MASTER PRODUCT sekaligus acuan key visual; image2.png adalah
STORYBOARD dan sumber timing saja—jangan animasikan lembar storyboard.

VISUAL LOCK: sneaker low-top retro warna powder/baby blue; kombinasi panel
smooth dan suede-like; tepat tiga stripe putih bergerigi di sisi; tali biru;
outsole gum cokelat tua; logo PVN kecil; proporsi sepatu tidak berubah.

Keluarkan terlebih dahulu satu IMAGE PROMPT square 1:1: sepasang sneaker di atas
kain satin/denim biru berlipat, satu side profile dan satu sudut 3/4, soft cool
studio light, aksen gem/heart kecil, negative space untuk logo dan judul; jangan
generate tulisan. Setelah itu ikuti 5 klip video 9:16: 0–2s POV membuka box;
2–4s tangan mengangkat dan macro sweep
upper→stripe→gum sole; 4–6s on-feet dengan celana cream dan kaus kaki putih;
6–8s low-angle walking lalu side-profile hero; 8–10s pair beauty shot pada
background denim/light blue. Gaya clean POV/UGC fashion dengan soft daylight.

Keluarkan 5 prompt Flow terpisah. Setiap prompt wajib mengulang VISUAL LOCK,
camera, satu aksi, first/end frame, dan negative prompt. Jangan generate teks;
headline, logo besar, dan CTA ditambahkan saat editing. Hindari extra stripe,
white outsole, bentuk sepatu berubah, kaki/tangan cacat, flicker, dan watermark.
```

### 02 — Doll Catcher

- **Lock:** bentuk mesin, warna, kontrol, claw, chute, hadiah, dan mekanisme.
- **ChatGPT:** P1 → P2 → P4 → P5 → P6.
- **Flow:** pecah menjadi reveal, insert control, claw action, prize drop, hero ending.
- **QC:** mekanisme logis; claw dan tombol tidak bertambah atau berubah posisi.

**Prompt siap salin ke ChatGPT — unggah foto produk Doll Catcher:**

```text
Audit foto Doll Catcher yang saya unggah dan buat VISUAL LOCK dari bentuk mesin,
warna panel, jumlah/posisi tombol, joystick, claw, chute, hadiah, logo, dan skala.
Jangan menebak detail yang tertutup dan jangan mengubah mekanisme.

Setelah audit, buat 5 prompt Google Flow vertical 9:16: hero reveal, close-up
control, claw bergerak menuju hadiah, hadiah jatuh melalui chute, dan final hero.
Satu aksi per klip. Ulangi VISUAL LOCK lengkap pada setiap prompt. Sertakan
camera, lighting pastel studio, first/end frame, serta negative prompt untuk
extra control, claw mutation, hadiah menembus dinding, physics tidak logis,
deformed hands, random text, flicker, dan watermark.
```

### 03 — NeeDoh Nice Cube

- **Lock:** bentuk kubus, warna, material visual, deformasi, dan slow-rise recovery.
- **ChatGPT:** tekankan macro shot, tactile action, dan foley pada P4/P6.
- **Flow:** satu aksi per klip: press, full squeeze, release, recovery, lineup.
- **QC:** produk tidak meleleh, bocor, atau berubah menjadi material keras.

| Master reference produk | Contoh storyboard satisfying |
|---|---|
| <a href="media/image3.png"><img src="media/image3.png" alt="Master reference NeeDoh Nice Cube" width="360"></a> | <a href="media/image4.png"><img src="media/image4.png" alt="Storyboard video satisfying NeeDoh Nice Cube" width="220"></a> |

**Prompt siap salin ke ChatGPT — unggah `image3.png` dan `image4.png`:**

```text
Buat paket Google Flow untuk iklan satisfying 10 detik, vertical 9:16.
image3.png adalah sumber fakta listing; image4.png adalah APPROVED PRODUCT LOOK
dan shot/timing reference. Jangan animasikan layout storyboard atau teksnya.

VISUAL LOCK: cube transparan glossy dengan rounded corners, struktur sel/bubble
bulat terlihat di dalam, material kenyal, warna electric blue/pink/purple,
deformasi elastis dan kembali perlahan ke bentuk kubus. Tangan dewasa natural,
kuku pendek bersih, background studio pastel senada, soft front light dan thin
backlight yang menegaskan transparansi.

Buat 6 prompt Flow: extreme macro blue squeeze (0–1s), pink press (1–2.5s),
purple full squeeze (2.5–4.5s), blue release (4.5–7s), pink slow recovery
(7–8.5s), lineup blue-pink-purple (8.5–10s). Satu aksi per prompt. Sertakan
foley cue, first/end frame, dan negative prompt. Larang melting, leaking,
opaque material, cube keras, extra fingers, warna berubah, random text, dan
watermark. Teks/VO ditambahkan saat editing.
```

### 04 — POP SAN Water Slime

- **Lock:** cup, label, warna varian, jelly cube, dan skala produk.
- **ChatGPT:** pada P1 pisahkan fakta listing, klaim penjual, dan data belum pasti.
- **Flow:** generate varian hero, texture action, detail jelly cube, lalu lineup CTA.
- **QC:** jangan membuat sertifikasi, keamanan, atau manfaat yang tidak terverifikasi.

<p align="center"><a href="media/image5.png"><img src="media/image5.png" alt="Referensi produk POP SAN Water Slime" width="720"></a></p>

*Referensi visual produk dan varian POP SAN Water Slime.*

**Prompt siap salin ke ChatGPT — unggah `image5.png`:**

```text
Gunakan image5.png sebagai MASTER LISTING untuk POP SAN Water Slime. Pisahkan
fakta yang terlihat dari klaim seller. Kunci cup silinder transparan bertutup,
slime glossy dengan jelly cube putih, label karakter pada cup, dan enam varian:
Happy Yellow, Pinky Blue, Pinky Pink, Lovely Purple, Charming Red, Sweet Blue.
Logo/label final akan ditempel manual; jangan mereka ulang tulisannya.

Buat 4 prompt gambar marketplace dan 5 prompt Google Flow vertical 9:16:
lineup enam varian, membuka tutup, menarik slime, macro jelly cube, dan final
lineup CTA. Setiap prompt wajib menyebut warna varian, bentuk cup, consistency,
camera, lighting pastel lavender, dan negative prompt. Larang cup/label berubah,
warna varian tertukar, jelly cube hilang, klaim keamanan/sertifikasi buatan,
tangan cacat, random text, flicker, serta misleading scale.
```

### 05 — Iklan Produk Tanpa Model

- **Lock:** bentuk, bahan visual, warna, label, dan proporsi produk.
- **ChatGPT:** pada P4 larang manusia dan tangan; gunakan hero/detail/motion/CTA.
- **Flow:** buat klip product-only dengan turntable, macro, controlled motion, dan hero shot.
- **QC:** tidak ada manusia, floating parts, perubahan logo, atau material flicker.

**Prompt siap salin ke ChatGPT — unggah satu foto produk bersih:**

```text
Audit foto produk dan tulis VISUAL LOCK: silhouette, dimensi relatif, warna,
material visual, bagian, label/logo, dan detail unik. Setelah saya menyetujui
audit, buat 4 prompt Google Flow vertical 9:16: hero reveal, slow turntable,
macro detail, dan final beauty shot dengan negative space untuk CTA.

Tidak boleh ada manusia, tangan, perubahan bentuk, komponen baru, produk
melayang tanpa penyangga logis, logo mutasi, material flicker, random text,
camera jitter, atau watermark. Ulangi VISUAL LOCK lengkap di setiap prompt;
satu aksi dan satu camera movement per klip.
```

### 06 — Flyer Event dan Header Google Form

- **ChatGPT:** P1 → P2 → P3 untuk key visual dengan negative space.
- **Finalisasi:** tempel ulang judul, tanggal, lokasi, kontak, QR, dan logo secara manual.
- **Adaptasi:** ubah komposisi ke `1600×400`; jangan sekadar crop flyer portrait.
- **QC:** semua data acara terbaca dan sama dengan sumber resmi.

<p align="center"><a href="media/image6.png"><img src="media/image6.png" alt="Contoh flyer dan storytelling event" width="420"></a></p>

*Contoh visual event; data resmi dan tipografi tetap difinalkan manual.*

**Prompt siap salin ke ChatGPT — unggah `image6.png` dan foto tokoh asli:**

```text
Buat prompt image-generation untuk poster komik event “Kemah Bhakti Untuk
Negeri 2026” yang mengikuti image6.png sebagai APPROVED LAYOUT/STYLE dan foto
tokoh sebagai MASTER IDENTITY. Pertahankan wajah, kacamata hitam berbingkai,
kumis/goatee, topi hitam, hoodie/jaket gelap, ransel, dan jam tangan.

IDENTITY LOCK: struktur wajah dan seluruh atribut tokoh berasal dari foto asli;
image6.png hanya menentukan style, pose, panel, warna, dan lokasi. Jika wajah
pada image6 berbeda dari foto asli, ikuti foto asli.

Format portrait 2:3, warm cinematic semi-realistic comic, sunset pegunungan,
camping ground, outline tinta tegas, warna amber-oranye-hijau gelap. Susun tujuh
panel: hero invitation; pointing CTA; tanggal/lokasi; camping-training-tracking;
biaya; preparation; closing registration. Sisakan kotak kosong bersih untuk
semua teks resmi—jangan generate nomor telepon, harga, tanggal, atau paragraf.
Negative: face drift, different person, missing glasses, extra fingers, duplicate
main character, unreadable text, panel disorder, watermark.

Keluarkan dua blok prompt: (A) poster portrait 2:3 sesuai struktur di atas;
(B) header Google Form 1600×400 yang hanya memakai tokoh hero di kiri, panorama
kemah di tengah, dan negative space bersih di kanan. Header bukan hasil crop;
recompose scene secara horizontal dan jangan membawa panel komik ke header.
```

### 07 — Edukasi Sains Anak

- **Lock:** desain, usia, pakaian, warna, skala, dan sifat setiap karakter.
- **ChatGPT:** verifikasi konsep sains; P4 membagi hook, penjelasan, dan takeaway.
- **Flow:** generate satu scene per klip; gunakan end frame sebagai bridge scene berikutnya.
- **QC:** penjelasan sains benar, karakter stabil, dan visual sesuai usia.

| Storyboard tiga scene | Character sheet Mimi |
|---|---|
| <a href="media/image7.png"><img src="media/image7.png" alt="Storyboard Mimi dan Rahasia Pelangi" width="380"></a> | <a href="media/image8.png"><img src="media/image8.png" alt="Character sheet Mimi" width="380"></a> |
| **Character sheet Axel** | **Character sheet Tetes** |
| <a href="media/image9.png"><img src="media/image9.png" alt="Character sheet Axel" width="380"></a> | <a href="media/image10.png"><img src="media/image10.png" alt="Character sheet Tetes" width="380"></a> |

**Prompt siap salin ke ChatGPT — unggah `image7.png`–`image10.png`:**

```text
Buat 12 prompt Google Flow untuk video “Mimi dan Rahasia Pelangi”, total 30
detik, 9:16. image8/9/10 adalah MASTER CHARACTER SHEETS; image7 hanya sumber
storyboard, urutan, framing, dan cerita—jangan animasikan sheet/panel/teks.

CHARACTER LOCK: Mimi = kelinci kecil bulu cream, mata cokelat besar, raincoat
kuning motif kecil, scarf biru muda, boots biru, satchel cokelat. Axel = rubah
kecil oranye dengan muzzle/ujung ekor cream, vest hijau, scarf teal, celana dan
satchel cokelat, boots teal. Tetes = tetes air biru transparan mengilap, ujung
runcing, mata cokelat besar, tangan/kaki kecil, refraction lembut.

Ikuti tepat 12 panel image7: 4 klip pelangi muncul, 4 klip bertemu Tetes, 4 klip
demonstrasi cahaya menjadi spektrum. Gaya 3D animated family film, meadow setelah
hujan, bunga pastel, genangan, warm soft sunlight, child-friendly. Setiap prompt
mengulang karakter yang hadir, satu aksi, camera, dialog/VO terpisah, first/end
frame, dan negative prompt. Larang species/outfit berubah, karakter duplikat,
Tetes opaque/melting, urutan pelangi salah, extra limbs, random text, watermark.
```

### 08 — Edukasi Keselamatan Gempa

- **Lock:** karakter, ruang, meja kokoh, dan gaya claymation.
- **ChatGPT:** validasi urutan keselamatan sebelum P4 dan P6.
- **Flow:** scene 1 tanda gempa, scene 2 merunduk–berlindung–berpegangan, scene 3 menuju area aman setelah guncangan berhenti.
- **QC:** jangan menampilkan tindakan berbahaya, kepanikan, atau keluar saat guncangan aktif.
- **Rujukan keselamatan:** urutan *Drop, Cover, Hold On* dan tetap berada di dalam saat guncangan mengikuti [Ready.gov — Earthquakes](https://www.ready.gov/earthquakes).

<p align="center"><a href="media/image11.png"><img src="media/image11.png" alt="Storyboard edukasi keselamatan gempa gaya claymation" width="300"></a></p>

*Contoh storyboard vertikal edukasi keselamatan gempa.*

**Prompt siap salin ke ChatGPT — unggah `image11.png`:**

```text
Buat 6 prompt Google Flow untuk video edukasi gempa 30 detik, 9:16, mengikuti
enam shot image11.png. Gambar adalah STORYBOARD/STYLE MASTER; jangan animasikan
lembar, panel, judul, atau labelnya.

VISUAL LOCK: handcrafted claymation dengan sidik jari plastisin halus; ibu muda
berhijab mauve, sweater dusty pink, rok beige; anak laki-laki kecil berambut
hitam, kaus kuning, celana biru, sneakers merah-putih; ruang keluarga hangat,
sofa hijau, meja kayu kokoh, rak buku, lampu gantung, gelas air.

Shot: ruang mulai bergetar; ibu menghentikan anak yang panik; keduanya merunduk;
berlindung dan berpegangan pada kaki meja; keluar tertib setelah guncangan
berhenti; berdiri di area terbuka jauh dari bangunan, tiang, dan pohon besar.
Satu shot per prompt, camera stabil, gerakan stop-motion halus. Teks keselamatan
ditambahkan di editor. Larang keluar saat guncangan aktif, berlindung dekat rak,
kehancuran berat, cedera, horror, character drift, extra limbs, dan random text.
```

### 09 — Berita Viral Claymation

- **Lock:** fakta, sumber, angka, status verifikasi, dan identitas visual reporter.
- **ChatGPT:** P1 wajib memisahkan fakta, klaim viral, dan klarifikasi.
- **Flow:** hook viral, klarifikasi, lalu takeaway; teks angka ditempel di editor.
- **QC:** hindari fitnah, angka salah, dan visual yang menyatakan klaim belum terverifikasi sebagai fakta.

<p align="center"><a href="media/image12.png"><img src="media/image12.png" alt="Storyboard berita viral gaya claymation" width="300"></a></p>

*Contoh storyboard berita viral: hook, klarifikasi, dan takeaway editorial.*

**Prompt siap salin ke ChatGPT — unggah `image12.png` dan sumber fakta:**

```text
Pertama, verifikasi naskah terhadap sumber yang saya berikan. Pisahkan klaim
viral, fakta terkonfirmasi, dan hal yang belum pasti. Jangan lanjut jika angka
Rp700.000 atau klarifikasi Rp700/kg kain majun belum didukung sumber.

Setelah fakta disetujui, buat 12 prompt Google Flow mengikuti 12 panel
image12.png. STYLE LOCK: claymation warm earthy, pasar rakyat Indonesia,
plastisin ekspresif dan humoris. CHARACTER LOCK: pria muda rambut hitam ikal,
kemeja hijau dan apron biru; reporter pria berkacamata membawa mikrofon;
penjahit perempuan dengan mesin jahit vintage dan tumpukan kain majun.

Urutan: reaksi ponsel → bergegas → membawa bawang → kerumunan; freeze/stop;
reporter klarifikasi → kain majun → perbandingan angka; karakter ragu → cek
konteks → pesan fact-check → punchline kelompok. Satu panel per klip. Jangan
generate angka/teks di video; overlay dibuat di editor. Larang misinformation,
angka palsu, identity drift, duplikasi karakter utama, extra limbs, dan flicker.
```

### 10 — Animasi Nara & Kiko

- **Lock:** character sheet, aksesori, proporsi, palet, dan emotional arc.
- **ChatGPT:** P4 membagi masalah, dukungan teman, keberanian, dan resolusi.
- **Flow:** satu scene emosional per klip; gunakan reference karakter yang sama setiap kali.
- **QC:** ekspresi berkembang logis dan tidak ada character drift.

| Storyboard cerita | Character sheet Nara |
|---|---|
| <a href="media/image13.png"><img src="media/image13.png" alt="Storyboard Ketika Nara Kehilangan Suaranya" width="380"></a> | <a href="media/image14.png"><img src="media/image14.png" alt="Character sheet Nara" width="380"></a> |
| **Character sheet Kiko** | |
| <a href="media/image15.png"><img src="media/image15.png" alt="Character sheet Kiko" width="380"></a> | |

**Prompt siap salin ke ChatGPT — unggah `image13.png`–`image15.png`:**

```text
Buat 12 prompt Google Flow untuk “Ketika Nara Kehilangan Suaranya”, total 30
detik, 9:16. image14 dan image15 adalah MASTER CHARACTER SHEETS; image13 hanya
storyboard/timing reference. Jangan animasikan layout atau speech bubble.

NARA LOCK: anak burung kenari kuning berbulu lembut, mata cokelat sangat besar,
jambul coral-pink-mint, sayap berlapis coral/pink/mint, paruh oranye, collar teal
dengan liontin not musik, badge bunga, mikrofon bunga pink. KIKO LOCK: anak
beruang cokelat bulat, muzzle beige, mata cokelat besar, tuft rambut kecil,
neckerchief teal, friendship badge bintang.

Ikuti 12 panel: Nara latihan → nada fals → malu → menyendiri; Kiko datang →
mengajak mencoba → memberi dukungan → Nara berani; festival → dukungan Kiko →
Nara bernyanyi → ending hangat. Gaya 3D family animation, enchanted forest,
golden light lalu festival lantern bokeh. Satu aksi per klip, ulangi lock setiap
prompt, gunakan first/end frame. Larang warna bulu/aksesori berubah, duplicate
characters, bullying visual, scary expression, extra wings/limbs, random text.
```

### 11 — Storytelling/Biografi Kartun 2D

- **Lock:** wajah, usia, kostum, era, dan gaya ilustrasi 2D.
- **ChatGPT:** pecah naskah menjadi scene pendek; satu fakta atau beat per scene.
- **Flow:** generate per scene, pertahankan first/end frame, lalu rangkai di editor.
- **QC:** urutan fakta, waktu, dan identitas tokoh konsisten.

**Prompt siap salin ke ChatGPT — unggah foto tokoh dan naskah terverifikasi:**

```text
Audit foto tokoh dan buat IDENTITY LOCK: bentuk wajah, usia, warna kulit,
rambut, atribut khas, pakaian, dan era. Audit naskah dan tandai fakta yang tidak
memiliki sumber. Setelah disetujui, pecah naskah menjadi scene 4–6 detik dengan
satu fakta dan satu aksi visual per scene.

Buat satu prompt Google Flow per scene dalam gaya kartun 2D yang konsisten:
clean line art, cel shading halus, palette dan texture yang sama. Setiap prompt
wajib mengulang IDENTITY LOCK, waktu/lokasi, framing, aksi, first/end frame,
dan negative prompt. Jangan mengubah usia/era/kostum, jangan mencampur 3D atau
photorealism, jangan menambahkan peristiwa, dan jangan generate teks panjang.
```

### 12 — AI Influencer & Character Sheet

- **Lock:** wajah, usia, warna kulit, mata, rambut, proporsi, dan ciri khas.
- **ChatGPT:** P1 menetapkan identity lock; P3 membuat front/side/back, ekspresi, dan detail.
- **QC:** tidak ada age drift, face morphing, atau perubahan ciri identitas.

<p align="center"><a href="media/image16.png"><img src="media/image16.png" alt="Contoh AI influencer character reference sheet" width="460"></a></p>

*Contoh character reference sheet untuk menjaga identity lock.*

**Prompt siap salin ke ChatGPT — unggah `image16.png`:**

```text
Buat prompt image-generation untuk reference sheet yang mempertahankan identitas
anak pada image16.png. MASTER IDENTITY: anak laki-laki Indonesia usia 12 tahun,
wajah oval muda, kulit medium warm, mata gelap almond, hidung kecil, rambut hitam
tebal berponi menyamping, proporsi dan styling sesuai usia, ekspresi tenang.

Layout portrait editorial putih/abu muda: baris reference wajah front, profile,
3/4, neutral; hero half-body memakai baju koko hitam dengan bordir abu; variasi
konten casual hoodie, outfit Islami, cahaya siang/malam, alam, urban, membaca,
olahraga, membuat konten; enam ekspresi natural. Gunakan photorealistic natural
skin texture dan consistent facial geometry. Jangan generate biodata/quote/label;
tambahkan manual. Negative: age progression, adult styling, face morphing,
heavy makeup, sexualized pose, plastic skin, extra fingers, random accessories.
```

### 13 — Video Event Berseri

- **Lock:** master character sheet, logo, outfit, lokasi, dan urutan scene.
- **ChatGPT:** P6 harus menghasilkan continuity lock yang sama untuk semua klip.
- **Flow:** generate scene berurutan; gunakan end frame klip sebelumnya sebagai referensi klip berikutnya bila fitur tersedia.
- **QC:** bandingkan setiap klip dengan master sebelum melanjutkan.

<p align="center"><a href="media/image17.png"><img src="media/image17.png" alt="Master character sheet untuk video event berseri" width="720"></a></p>

*Master character sheet sebagai referensi identitas untuk seluruh scene.*

**Prompt siap salin ke ChatGPT — unggah `image17.png` dan storyboard event:**

```text
Buat paket Google Flow per scene dengan image17.png sebagai MASTER CHARACTER.
Storyboard event hanya menentukan urutan, lokasi, aksi, dan camera.

CHARACTER LOCK: kelinci antropomorfik 3D berbulu putih, tubuh kecil ±85 cm,
mata biru besar, telinga panjang dengan inner ear pink; topi hitam berlogo
geometris teal-oranye; hoodie hitam dengan logo Baghasasi; celana cargo hitam;
boots cokelat; backpack kanvas olive dengan strap cokelat. Palette teal #14C7C7,
orange #FF8C00, charcoal #222222, white #FFFFFF, beige #F7D7A8, green #4CAF50.

Untuk setiap scene, ulangi lock lengkap, sebut properti yang dipakai (map,
kompas, api unggun, mug, kamera, tenda), satu aksi, camera, lighting, dan
first/end frame. Gaya polished 3D family-film, outdoor adventure cinematic.
Larang logo/outfit/backpack berubah, telinga/warna mata berubah, extra limbs,
duplicate hero, props menyatu dengan tangan, random text, flicker, watermark.
```

### 14 — Komik/Manga Event

- **Lock:** identitas tokoh, data acara, hook, CTA, dan arah baca.
- **ChatGPT:** P1 → P2 → P3; minta panel plan sebelum prompt gambar final.
- **Finalisasi:** dialog, tanggal, lokasi, kontak, dan logo ditempel ulang di editor.
- **QC:** wajah dikenali, panel mudah dibaca, dan data acara benar.

<p align="center"><a href="media/image18.png"><img src="media/image18.png" alt="Contoh manga event satu halaman" width="420"></a></p>

*Contoh manga event; hook, CTA, dan data acara harus tetap dikunci.*

**Prompt siap salin ke ChatGPT — unggah `image18.png` dan foto tokoh asli:**

```text
Buat prompt image-generation untuk manga event satu halaman yang mengikuti
image18.png sebagai APPROVED STYLE/LAYOUT dan foto tokoh sebagai MASTER IDENTITY.
Pertahankan bentuk wajah, kacamata, kumis/goatee, topi, jaket outdoor gelap,
backpack, dan jam tangan; tokoh harus tetap mudah dikenali.

Portrait 2:3, black-and-white Japanese seinen manga, crisp ink, screentone,
dramatic speed lines, mountain camp and Indonesian flag. Enam panel: heroic
call; keraguan anak muda urban; persiapan mendaki; transformasi kota→gunung dan
kotak tanggal/lokasi; camping-training-tracking dan biaya; closing group CTA.
Sisakan speech balloon dan information boxes kosong untuk teks manual. Jangan
generate nama, tanggal, harga, alamat, nomor telepon, atau paragraf.
Negative: face drift, missing glasses, wrong outfit, duplicate hero, extra
fingers, broken panel order, gray muddy ink, illegible text, watermark.
```

## Checklist QC Universal

- [ ] Fakta, klaim, angka, tanggal, dan CTA sudah diverifikasi.
- [ ] Produk/karakter sama dengan master reference.
- [ ] Logo, pakaian, warna, dan aksesori tidak berubah.
- [ ] Anatomi, physics, gerakan, dan continuity terlihat logis.
- [ ] Tidak ada typo, random text, flicker, watermark, atau deformasi.
- [ ] Rasio, resolusi, durasi, dan safe area sesuai platform.
- [ ] Teks kritikal dan logo final sudah dipasang manual.
- [ ] Audio tidak menutupi voice-over.

## Struktur Folder

```text
PROJECT_NAME/
├── 00_BRIEF/
├── 01_REFERENCE/
├── 02_SCRIPT_STORYBOARD/
├── 03_PROMPTS/
├── 04_FLOW_GENERATIONS/
├── 05_APPROVED_CLIPS/
├── 06_FINAL_EDIT/
└── 07_ARCHIVE/
```

Gunakan versi file, misalnya `PROJECT_SC02_FLOW_PROMPT_v03.txt` dan `PROJECT_SC02_APPROVED_v02.mp4`.

## Catatan Akhir

ChatGPT membantu berpikir, menyusun, dan memeriksa; generator gambar/video membantu produksi; editor tetap menjadi tempat finalisasi presisi. Simpan brief dan lock yang sudah disetujui sebagai sumber kebenaran sampai proyek selesai.
