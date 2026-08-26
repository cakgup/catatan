# AI Design: Panduan Praktis Desain Grafis dengan AI

> **Versi 2.3 (2026)** — Modul praktik berbasis proyek untuk menyusun brief, menulis prompt, membuat gambar/video, dan melakukan quality control (QC).

Panduan ini dirancang agar dapat langsung dipraktikkan. Setiap proyek mengikuti alur yang sama:

**Referensi → analisis → brief → ide/cerita → script → storyboard → generate → QC → finalisasi.**

## Mulai Cepat

1. Baca [fondasi universal](#bagian-a--fondasi-universal-sebelum-memulai-proyek) satu kali.
2. Pilih proyek pada [peta proyek](#peta-proyek) sesuai output yang ingin dibuat.
3. Siapkan aset referensi yang diminta, misalnya foto produk, karakter, logo, atau data acara.
4. Salin prompt dari blok kode menggunakan tombol **Copy** di pojok kanan blok.
5. Ganti semua placeholder bertanda `[GANTI: ...]` dengan data Anda.
6. Unggah aset referensi, tempel prompt, lalu generate.
7. Lanjutkan ke langkah berikutnya hanya setelah hasil lolos checklist QC.

> [!IMPORTANT]
> Jangan menghapus bagian **LOCK**, **NEGATIVE**, atau **QC**. Ketiganya membantu menjaga identitas karakter/produk, mencegah kesalahan visual, dan memastikan output layak dipakai.

## Cara Menggunakan Prompt

Placeholder selalu memakai format `[GANTI: keterangan]`. Contoh:

```text
Target audiens: [GANTI: remaja usia 15–18 tahun]
Rasio: [GANTI: 4:5]
```

Menjadi:

```text
Target audiens: remaja usia 15–18 tahun
Rasio: 4:5
```

Urutan penggunaan prompt:

1. **Isi placeholder** — jangan kirim teks `[GANTI: ...]` apa adanya.
2. **Lampirkan referensi** — beri nama yang jelas, misalnya `Image 1 = produk`, `Image 2 = logo`.
3. **Generate satu tahap** — brief dahulu, baru storyboard; storyboard dahulu, baru video.
4. **Periksa fakta dan visual** — AI tidak boleh menjadi sumber kebenaran untuk harga, tanggal, alamat, spesifikasi, atau logo.
5. **Revisi terarah** — sebutkan bagian yang salah dan bagian yang harus tetap dikunci.

## Template Prompt Universal — Siap Salin

Gunakan template ini jika studi kasus Anda tidak sama persis dengan proyek yang tersedia.

```text
BERTINDAK SEBAGAI AI CREATIVE DIRECTOR DAN DESIGN ENGINEER PROFESIONAL.

[OBJECTIVE]
Buat [GANTI: jenis output] untuk [GANTI: tujuan bisnis/komunikasi].

[REFERENCE]
- Image 1: [GANTI: fungsi gambar, misalnya master produk/karakter].
- Image 2: [GANTI: fungsi gambar, misalnya logo/brand].
- Data resmi: [GANTI: fakta, spesifikasi, tanggal, harga, atau CTA yang sudah diverifikasi].

[AUDIENCE]
Target audiens: [GANTI: siapa, rentang usia, kebutuhan, dan platform].

[LOCK]
Pertahankan persis: [GANTI: wajah, warna, bentuk, proporsi, pakaian, logo, label, atau ciri produk].
Jangan menambah fitur, klaim, teks, atau identitas yang tidak tersedia pada referensi.

[STYLE]
Gaya visual: [GANTI: cinematic/realistic/minimalist/modern/flat/elegant/professional/premium].
Mood dan lighting: [GANTI: deskripsi].
Palet warna: [GANTI: nama warna dan kode HEX].

[COMPOSITION]
Rasio: [GANTI: 1:1/4:5/9:16/16:9].
Susunan elemen: [GANTI: framing, hierarchy, negative space, dan safe area].

[CONTENT / ACTION]
[GANTI: objek, pose, aksi, urutan shot, atau timeline yang harus dibuat].

[TEXT / VO]
Teks yang harus persis: "[GANTI: teks final]".
Voice-over: "[GANTI: naskah final atau tulis 'tidak ada']".

[NEGATIVE]
No identity drift, no product deformation, no logo changes, no extra limbs,
no malformed hands, no typo, no random text, no flicker, no watermark.

[OUTPUT]
[GANTI: resolusi, durasi, fps, format file, dan kebutuhan teknis lain].

Sebelum membuat output, rangkum asumsi dan tandai data yang masih perlu dikonfirmasi.
```

## Peta Proyek

| **PROYEK** | **HASIL YANG DIBUAT**                            | **RINGKASAN ALUR**                                                                     |
|------------|--------------------------------------------------|----------------------------------------------------------------------------------------|
| 01         | [Iklan Sepatu — PVN Taehyung Blue](#membuat-iklan-sepatu--pvn-taehyung-blue)                 | Creative brief, 10 angle, flyer, script 10 detik, storyboard 9:16, JSON video, QC.     |
| 02         | [Iklan Mainan Interaktif — Doll Catcher](#membuat-iklan-mainan-interaktif--doll-catcher-1140)           | Brief → angle → script → storyboard → JSON → Google Flow → QC.                         |
| 03         | [Iklan Squishy — NeeDoh Nice Cube](#membuat-iklan-squishy--sensory-toy--needoh-nice-cube)   | Brief → satisfying angle → script → storyboard → slow-rise video → foley → QC.         |
| 04         | [Konten Marketplace — POP SAN Water Slime](#membuat-konten-produk-marketplace--pop-san-water-slime)  | Screenshot → fakta/klaim → brief → angle foto/video → shot list → video 10 detik → QC. |
| 05         | [Iklan Produk Tanpa Model](#membuat-iklan-produk-10-detik-tanpa-model)                         | Product lock → hero/detail/motion → storyboard → video 10 detik → VO → QC.             |
| 06         | [Flyer Event → Header Google Form](#membuat-flyer-event-dan-turunannya-ke-header-google-form)                 | Brief acara → key visual → flyer → final text → adaptasi header 1600×400.              |
| 07         | [Video Edukasi Sains Anak](#membuat-video-edukasi-sains-anak--mimi-dan-rahasia-pelangi)     | Ide → script → character sheet → storyboard → video Scene 1–3 → QC.                    |
| 08         | [Video Keselamatan — Gempa Claymation](#membuat-video-edukasi-keselamatan--gempa-bumi-claymation)     | Pesan keselamatan → script → storyboard → JSON 3 scene → QC.                           |
| 09         | [Berita Viral Claymation](#membuat-konten-berita-viral-dengan-claymation--upah-kupas-bawang)      | Fact framing → script → storyboard → video 3 scene → caption → QC editorial.           |
| 10         | [Animasi Persahabatan — Nara & Kiko](#membuat-animasi-persahabatan-anak--nara--kiko)               | Ide → script → character sheet → storyboard → JSON 3 scene → caption.                  |
| 11         | [Storytelling / Biografi Kartun 2D](#membuat-video-storytelling--biografi-kartun-2d)                | Naskah → character sheet 2D → storyboard 9:16 → prompt video per scene → QC.           |
| 12         | [AI Influencer & Character Sheet](#membuat-ai-influencer-dan-character-sheet)                  | Foto referensi → identity lock → reference sheet → variasi konten → QC.                |
| 13         | [Video Event Berseri](#membuat-video-event-berseri-dengan-character-lock--google-flow) | Character sheet → keyframe → scene JSON → continuity → revisi drift → QC.              |
| 14         | [Komik / Manga dari Brief Event](#membuat-komik--manga-dari-brief-event)                   | Hook → identity lock → panel story → prompt komik/manga → typography final → QC.       |

# BAGIAN A — Fondasi Universal Sebelum Memulai Proyek

Mulai dari aset referensi yang jelas. Sebelum menulis prompt, tentukan gambar mana yang menjadi referensi karakter, logo, pakaian, storyboard, atau lingkungan. Semakin banyak fungsi gambar tercampur tanpa penjelasan, semakin tinggi risiko AI salah menafsirkan.

| **DIKUNCI**                         | **BOLEH BERVARIASI**          |
|-------------------------------------|-------------------------------|
| Struktur wajah, mata, hidung, bibir | Ekspresi dan arah pandang     |
| Warna kulit / fur, proporsi tubuh   | Pose dan aktivitas            |
| Logo, warna logo, penempatan logo   | Sudut kamera                  |
| Model topi, kacamata, pakaian khas  | Lokasi dan background         |
| Ciri khas karakter                  | Pencahayaan dan mood          |
| Data acara dan kontak               | Gaya framing / depth of field |

Jangan menjejalkan terlalu banyak informasi dalam satu scene. Untuk video 30 detik, pola yang efektif adalah: Scene 1 membangun hook/emosi, Scene 2 menyampaikan informasi inti, Scene 3 menutup dengan motivasi dan CTA.

Rumus cepat: TUJUAN → REFERENSI → LOCK → STYLE → STRUKTUR → TEKS/DATA → LARANGAN

Untuk pemula, mulai dari tujuh blok berikut. Setelah kebutuhan makin kompleks, tambahkan camera, lighting, audio, timeline, dan technical output.

- A. Objective: Apa yang ingin dibuat: character sheet, poster, scene video, komik, manga, dsb.

- B. Reference: Jelaskan fungsi setiap gambar: karakter, logo, outfit, storyboard, lingkungan.

- C. Character Lock: Daftar atribut identitas yang tidak boleh berubah.

- D. Brand Lock: Logo, warna, placement, font, pola pakaian, label produk.

- E. Visual Style: 3D stylized, semi-realistis, webtoon, manga, editorial, hyper-realistic, dll.

- F. Composition: Rasio, orientasi, jumlah panel, framing, hierarchy.

- G. Camera & Lighting: Angle, lens feel, movement, depth of field, lighting.

- H. Action & Expression: Gerakan, gesture, emotion, body language.

- I. Text & VO: Teks visual dan kalimat voice-over yang harus persis.

- J. Negative Prompt: Error yang harus dihindari: face morphing, logo berubah, extra limbs, typo, flicker, dsb.

- K. Technical Output: Rasio, durasi, fps, resolusi, orientation, safe area.

### Struktur Minimum Prompt

Template lengkap tersedia pada [Template Prompt Universal](#template-prompt-universal--siap-salin). Untuk prompt singkat, minimal sertakan tujuh blok berikut:

```text
[OBJECTIVE] Apa yang harus dibuat dan untuk tujuan apa.
[REFERENCE] Fungsi setiap gambar atau data yang dilampirkan.
[LOCK] Identitas, bentuk, warna, logo, dan atribut yang tidak boleh berubah.
[STYLE] Gaya visual, pencahayaan, mood, dan palet warna.
[COMPOSITION] Rasio, framing, hierarchy, safe area, atau jumlah panel.
[CONTENT] Aksi, timeline, teks, voice-over, dan audio.
[NEGATIVE] Kesalahan yang harus dihindari.
```

Model generatif sering mengubah geometri logo, huruf, gradien, dan alignment. Karena itu, logo yang digenerate AI sebaiknya dianggap placeholder visual. Pada final artwork, gunakan file logo asli (PNG transparan/SVG/AI) dan tempel ulang secara manual.

> **Aturan brand lock**
Prompt harus menyebutkan: bentuk logo, warna, orientasi, posisi, skala, area placement, dan larangan mengubah logo. Namun QC final tetap wajib dilakukan dengan membandingkan terhadap master logo.

Untuk nomor telepon, harga, tanggal, alamat, dan judul kampanye: gunakan teks pendek dalam generasi AI, tetapi lakukan compositing ulang pada final layout. Jangan menjadikan kemampuan AI merender teks sebagai sumber kebenaran.

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th><p><strong>ATURAN KELAS</strong></p>
<p>Peserta hanya pindah ke tahap berikutnya setelah output tahap sebelumnya lolos QC. Jika brief belum benar, jangan membuat storyboard. Jika character/product lock belum stabil, jangan membuat video.</p></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

# BAGIAN A.1 — Fondasi Konten, Prompt, Warna, Canva, dan Video AI

Materi tambahan V2.2 diringkas dari “Gen Z Desain Konten Tanpa Jago”, “Gen Z Prompt Engineering Poster”, “Videografi Tanpa Jago”, serta lima infografis warna, kombinasi palet, gaya visual, kualitas prompt gambar, dan ringkasan workflow desain yang dilampirkan peserta.

FONDASI 01

## Pahami Peran Tools: ChatGPT → Canva → Google Flow

Gunakan tools berdasarkan fungsi, bukan karena semua pekerjaan harus diselesaikan dalam satu aplikasi. Materi pelatihan membagi peran utama sebagai berikut:

| **TOOLS**   | **FUNGSI UTAMA**                     | **CONTOH PEKERJAAN**                                                                         | **OUTPUT ANTARA / FINAL**             |
|-------------|--------------------------------------|----------------------------------------------------------------------------------------------|---------------------------------------|
| ChatGPT     | Ide, hook, script, prompt            | Mencari ide konten, membuat 30–100 hook, menyusun script, prompt desain dan prompt video     | Brief, hook, copy, script, prompt     |
| Canva       | Finalisasi desain                    | Mengganti font/warna, menambah logo, merapikan layout, membuat desain editable, export/unduh | Poster/flyer/social post final        |
| Google Flow | Implementasi prompt menjadi video AI | Generate footage/video dari prompt atau reference, memilih rasio/durasi/model yang tersedia  | Footage AI / klip video untuk editing |

Prinsip kerja: ChatGPT menguatkan konsep dan instruksi; Canva menguatkan presisi desain; Flow menguatkan produksi gerak. Nama menu, model, dan posisi tombol dapat berubah mengikuti pembaruan antarmuka.

FONDASI 02

## Susun Konten dengan Urutan: Judul → Hook → Isi → Caption → CTA

Materi desain konten menekankan bahwa setiap elemen memiliki fungsi berbeda. Memisahkan fungsi ini membantu desain tidak penuh, pesan lebih jelas, dan CTA tidak tenggelam.

| **URUTAN** | **ELEMEN** | **FUNGSI**                                                                            | **PERTANYAAN PRAKTIK**                               |
|------------|------------|---------------------------------------------------------------------------------------|------------------------------------------------------|
| 1          | Judul      | Memberi konteks/topik utama.                                                          | Apa yang sedang dibahas?                             |
| 2          | Hook       | Menghentikan scroll dan memancing rasa penasaran pada 3–5 detik pertama.              | Mengapa audiens harus berhenti sekarang?             |
| 3          | Isi Konten | Membuat audiens memahami pesan inti poster/video.                                     | Apa satu pesan utama yang harus dipahami?            |
| 4          | Caption    | Memperluas penjelasan agar audiens makin paham, yakin, atau tergerak.                 | Konteks apa yang belum muat di visual?               |
| 5          | CTA        | Mengarahkan tindakan: daftar, hubungi, klik, simpan, bagikan, komentar, atau membeli. | Tindakan apa yang diharapkan setelah melihat konten? |

Contoh dari materi sumber: pada konten UPA, isi konten menjelaskan manfaat belajar dan lingkungan yang baik; caption memperluas pesannya; CTA mengajak bergabung dan menghubungi pengurus. Untuk produk, pola yang sama dapat diubah menjadi Judul produk → Hook masalah/keinginan → benefit visual → caption → “Cek varian / beli sekarang”.

<img src="media/image19.jpeg" style="width:6.15in;height:9.225in" />

Infografis ringkas workflow membuat desain konten: tools, hook, struktur konten, prompt desain, Canva, dan finalisasi.

FONDASI 03

## Membuat Hook yang Menghentikan Scroll

Hook adalah kalimat pembuka yang menarik perhatian agar orang mau membaca atau menonton lebih lanjut. Pada materi sumber, hook biasanya 1–3 kalimat pendek dan ditujukan untuk membuat penasaran, menggugah emosi, memancing pertanyaan, serta menarik perhatian pada 3–5 detik pertama.

- Gunakan bahasa yang sesuai audiens: profesional, keluarga, Gen Z, edukatif, atau premium.

- Satu hook = satu rasa penasaran. Hindari dua atau tiga ide besar dalam pembuka yang sama.

- Untuk video 10 detik, hook sebaiknya sudah terlihat atau terdengar pada 0–2 detik.

- Setelah memilih hook, jangan terus mengganti arah cerita; turunkan hook menjadi script dan visual yang konsisten.

### Prompt Latihan — Hook

```text
Buatkan 30 hook untuk konten Instagram tentang [GANTI: tema].

Target audiens: [GANTI: target audiens].
Gaya bahasa: [GANTI: lucu/relate/emosional/profesional/Gen Z].

Ketentuan:
- Setiap hook maksimal 1–2 kalimat pendek.
- Pesan utama harus kuat dalam 3 detik pertama.
- Jangan gunakan clickbait yang tidak sesuai isi konten.

Setelah membuat 30 hook, pilih 5 yang paling kuat dan jelaskan alasannya secara singkat.
```

Untuk menghasilkan variasi yang lebih banyak:

```text
Buatkan 100 hook untuk konten "[GANTI: tema]" dengan target audiens
[GANTI: target audiens]. Kelompokkan hasilnya menjadi: relate, pertanyaan,
problem-solution, curiosity gap, emosional, dan promosi.

Pilih 10 hook paling kuat berdasarkan kejelasan, relevansi, dan daya tarik
pada 3 detik pertama. Jelaskan alasan singkat untuk setiap pilihan.
```

Contoh hook pada materi: “Kalau bukan sekarang, mau nunggu kapan mulai memperbaiki diri?” dan “Mungkin yang kurang dari hidupmu bukan motivasi, tapi arah.” Gunakan sebagai pola, bukan kalimat wajib untuk semua tema.

FONDASI 04

## Formula Prompt Poster AI yang Lebih Lengkap

Materi “Prompt Poster AI” membandingkan prompt sangat pendek dengan prompt terstruktur. Intinya, prompt yang hanya berbunyi “buat poster tentang …” membuat AI menebak tujuan, target, gaya, warna, isi, dan komposisi.

Formula yang digunakan dalam materi: TEMA → TUJUAN → TARGET → GAYA → OBJEK → WARNA → KOMPOSISI → TEKS → RASIO → KUALITAS.

| **BLOK**  | **YANG DITENTUKAN** | **CONTOH PERTANYAAN**                               |
|-----------|---------------------|-----------------------------------------------------|
| Tema      | Topik yang dibahas  | Apa tema posternya?                                 |
| Tujuan    | Hasil komunikasi    | Mengedukasi, mengajak, menjual, mengingatkan?       |
| Target    | Pembaca/audiens     | Siapa yang akan melihat?                            |
| Gaya      | Bahasa visual       | Cinematic, realistic, minimalist, modern, dll.      |
| Objek     | Fokus visual        | Produk, manusia, masjid, karakter, landscape?       |
| Warna     | Palet dominan       | Warna utama, aksen, teks, CTA?                      |
| Komposisi | Susunan elemen      | Center, rule of thirds, clean/spacious layout?      |
| Teks      | Copy penting        | Judul, hook, kutipan, CTA apa yang wajib?           |
| Rasio     | Format output       | 1:1, 4:5, 9:16, 16:9?                               |
| Kualitas  | Karakter output     | High resolution, sharp detail, photorealistic, dll. |

### Perbandingan Prompt

Prompt terlalu umum:

```text
Buat poster dakwah tentang shalat.
```

Prompt yang lebih terstruktur dan siap salin:

```text
Buat poster bertema "Keutamaan Shalat Berjamaah" untuk masyarakat umum.

Tujuan: mengingatkan pentingnya shalat berjamaah.
Gaya: cinematic realistis.
Objek utama: masjid dan jamaah dalam suasana khusyuk.
Lighting: cahaya hangat saat matahari terbit.
Palet: emas, putih, dan hijau.
Komposisi: simetris dengan ruang kosong yang cukup untuk teks.
Judul yang harus persis: "Jangan Tinggalkan Jamaah".
Tipografi: modern dan mudah dibaca.
Rasio: 4:5.
Kualitas: high resolution, sharp detail.
Negative: no watermark, no random text, no malformed hands, no duplicated people.
```

Kesalahan yang perlu dihindari menurut materi: prompt terlalu pendek; tidak menentukan target; tidak menjelaskan gaya; tidak menentukan warna/ukuran/kualitas; atau memberi terlalu banyak instruksi yang saling bertentangan.

FONDASI 05

## Pilih Gaya Visual Sebelum Menulis Prompt Detail

Delapan gaya visual pada infografis dapat dipakai sebagai “bahasa singkat” untuk mengarahkan look & feel. Pilih satu gaya utama, lalu tambahkan 1–2 modifier bila perlu. Jangan mencampur terlalu banyak gaya yang saling bertentangan.

| **GAYA**     | **CIRI RINGKAS**                                                        | **COCOK UNTUK**                                              | **KATA KUNCI PROMPT**                                          |
|--------------|-------------------------------------------------------------------------|--------------------------------------------------------------|----------------------------------------------------------------|
| Cinematic    | Dramatis, pencahayaan kuat, komposisi seperti film, emosional           | Poster dakwah, motivasi, event, cover, thumbnail             | cinematic lighting, dramatic composition, movie scene          |
| Realistic    | Wajah/alur cahaya alami, tekstur terlihat, proporsi akurat              | Poster manusia, produk, promosi                              | ultra realistic, highly detailed, natural lighting, lifelike   |
| Minimalist   | Sedikit elemen, ruang kosong, warna sedikit, fokus pesan                | Quote, poster edukasi, presentasi, branding                  | minimalist design, clean layout, lots of white space           |
| Modern       | Layout rapi, tipografi besar, warna segar, bentuk geometris             | Instagram, startup, komunitas, event                         | modern graphic design, clean typography, contemporary style    |
| Flat Design  | Ilustrasi 2D sederhana, warna solid, ikon mudah dipahami                | Infografis, presentasi, website, aplikasi                    | flat illustration, simple vector style, colorful               |
| Elegant      | Warna lembut, tipografi rapi, ornament sedikit, seimbang                | Undangan, seminar, pernikahan, branding premium              | elegant design, refined typography, luxurious simplicity       |
| Professional | Tata letak teratur, mudah dibaca, formal dan terpercaya                 | Proposal, poster kantor, pelatihan, laporan                  | professional corporate design, clean layout, business style    |
| Premium      | Detail rapi, material visual berkualitas, warna mewah, finishing bersih | Produk eksklusif, hotel, properti, fashion, brand kelas atas | premium luxury design, sophisticated, high-end, elegant finish |

<img src="media/image20.jpeg" style="width:6.15in;height:9.225in" />

Referensi visual: 8 gaya visual yang sering digunakan pada poster, social media, presentasi, dan desain AI.

FONDASI 06

## Gunakan Kata Kunci Kualitas dengan Tepat

Kata kunci kualitas membantu menjelaskan karakter hasil yang diinginkan. Namun istilah seperti “Ultra HD” atau “Professional Printing Quality” tidak otomatis menjamin file benar-benar 4K, 300 DPI, atau siap cetak; ukuran pixel, resolusi export, dan pemeriksaan cetak tetap dilakukan pada tahap finalisasi.

| **ISTILAH**                   | **FOKUS**                              | **CONTOH PROMPT**                                              | **CATATAN PRAKTIK**                                                     |
|-------------------------------|----------------------------------------|----------------------------------------------------------------|-------------------------------------------------------------------------|
| Ultra HD                      | Detail visual sangat tinggi            | Ultra HD, ultra high quality, extremely detailed               | Gunakan untuk hero image/poster besar; tetap set ukuran output nyata.   |
| High Resolution               | Ketajaman dan jumlah pixel tinggi      | High resolution, high quality image                            | Cocok untuk digital/cetak setelah resolusi final diverifikasi.          |
| Professional Printing Quality | Kesan bersih dan siap produksi         | Professional printing quality, print-ready, high resolution    | Final print tetap perlu CMYK/bleed/DPI sesuai vendor cetak.             |
| Sharp Detail                  | Ketajaman detail, tekstur, wajah/objek | Sharp detail, crisp focus, highly detailed                     | Baik untuk produk, arsitektur, portrait, material.                      |
| Photorealistic                | Tampak seperti foto hasil kamera       | Photorealistic, lifelike, natural lighting, realistic textures | Gunakan jika target memang foto realistis, bukan ilustrasi/flat design. |

Kata kunci pendukung dari materi prompt poster: lighting = Golden Hour, Soft Light, Dramatic Lighting, Natural Light; composition = Center Composition, Rule of Thirds, Clean Layout, Spacious Layout.

<img src="media/image21.jpeg" style="width:6.15in;height:9.225in" />

Referensi visual kata kunci kualitas: Ultra HD, High Resolution, Professional Printing Quality, Sharp Detail, dan Photorealistic.

FONDASI 07

## Gunakan Warna dan Kode HEX sebagai Instruksi yang Konsisten

Kode HEX membantu tim menyebut warna secara konsisten di prompt, Canva, dan final artwork. Tetapkan peran warna: background, aksen, judul/teks utama, isi teks, dan CTA. Warna yang sama harus ditulis ulang pada prompt turunan agar tidak terjadi color drift.

WARNA PREMIUM YANG SERING DIPAKAI

| **PALET**            | **BACKGROUND** | **AKSEN** | **TEKS/JUDUL** | **KESAN / CATATAN**                                         |
|----------------------|----------------|-----------|----------------|-------------------------------------------------------------|
| Background Minimalis | \#EFF0F0       | \#830B08  | \#111827       | Bersih, elegan, nyaman dilihat; aksen marun kuat dan tegas. |
| Putih Bersih         | \#FFFFFF       | \#D4AF37  | \#111827       | Cerah, netral, fleksibel; gold memberi kesan premium.       |
| Navy Premium         | \#1E3A8A       | \#D4AF37  | \#FFFFFF       | Kokoh, terpercaya, elegan.                                  |
| Hijau Emerald        | \#065F46       | \#D4AF37  | \#FFFFFF       | Islami, segar, menenangkan.                                 |

- Panduan umum pada infografis: gunakan maksimal 3–5 warna utama agar desain tetap terkendali.

- Untuk poster dakwah pada infografis kombinasi warna, panduan dibuat lebih ketat: 2–3 warna utama agar nyaman dibaca.

- Pastikan kontras teks dan background cukup kuat.

- Gunakan warna aksen untuk menonjolkan pesan penting atau CTA.

- Selalu uji desain pada layar smartphone sebelum dipublikasikan.

<img src="media/image22.jpeg" style="width:6.15in;height:9.225in" />

Referensi kode HEX: kelompok warna dasar, warna premium yang sering dipakai, tips penggunaan warna, dan contoh palet favorit.

FONDASI 08

## Pilih Palet Berdasarkan Pesan dan Audiens

Warna bukan hiasan tambahan. Palet memengaruhi kesan: formal, segar, energik, premium, islami, atau Gen Z. Pilih palet sebelum generate agar visual dan tipografi bergerak dalam satu arah.

5 KOMBINASI UNTUK POSTER DAKWAH

| **PALET**        | **BACKGROUND** | **AKSEN** | **TEKS/JUDUL** | **KESAN / CATATAN**            |
|------------------|----------------|-----------|----------------|--------------------------------|
| Minimalis Modern | \#EFF0F0       | \#830B08  | \#111827       | Minimalis, elegan, profesional |
| Elegant          | \#FFFFFF       | \#D4AF37  | \#1C1C1C       | Anggun, mewah, berkelas        |
| Islamic Green    | \#F8F9FA       | \#065F46  | \#111827       | Sejuk, islami, menenangkan     |
| Corporate        | \#FFFFFF       | \#1E3A8A  | \#374151       | Profesional, terpercaya, rapi  |
| Luxury Dark      | \#111827       | \#D4AF37  | \#FFFFFF       | Mewah, eksklusif, premium      |

10 PALET KONTEN GEN Z

PALET GEN Z

| **PALET**      | **BACKGROUND** | **AKSEN** | **TEKS/JUDUL** | **KESAN / CATATAN**         |
|----------------|----------------|-----------|----------------|-----------------------------|
| Clean Modern   | \#EFF0F0       | \#830B08  | \#111827       | Isi \#4B5563 • CTA \#830B08 |
| Gen Z Blue     | \#F8FAFC       | \#2563EB  | \#0F172A       | Isi \#475569 • CTA \#2563EB |
| Gen Z Orange   | \#FFF7ED       | \#F97316  | \#1F2937       | Isi \#4B5563 • CTA \#EA580C |
| Islamic Modern | \#F8FAFC       | \#0F766E  | \#111827       | Isi \#475569 • CTA \#0F766E |
| Youth Green    | \#F0FDF4       | \#16A34A  | \#14532D       | Isi \#4B5563 • CTA \#16A34A |
| Bold Red       | \#FAFAFA       | \#DC2626  | \#111827       | Isi \#4B5563 • CTA \#DC2626 |
| Purple Gen Z   | \#FAF5FF       | \#7C3AED  | \#312E81       | Isi \#4B5563 • CTA \#7C3AED |
| Dark Premium   | \#111827       | \#D4AF37  | \#FFFFFF       | Isi \#E5E7EB • CTA \#DAAF77 |
| Cyan Future    | \#ECFEFF       | \#06B6D4  | \#0F172A       | Isi \#475569 • CTA \#0891B2 |
| Pink Creative  | \#FDF2F8       | \#EC4899  | \#1F2937       | Isi \#4B5563 • CTA \#DB2777 |

Tiga palet yang ditonjolkan pada materi dakwah Gen Z: Minimalis Premium, Fresh Islami, dan Enerjik Gen Z. Gunakan palet sebagai starting point; tetap sesuaikan dengan identitas brand/event.

<img src="media/image23.jpeg" style="width:6.15in;height:9.225in" />

Referensi kombinasi warna untuk poster dakwah dan konten remaja Gen Z, termasuk tips memilih warna.

FONDASI 09

## Workflow Desain Editable: ChatGPT → Canva → Final Artwork

Materi “Desain Konten Tanpa Jago” menempatkan ChatGPT sebagai tempat mencari ide, hook, dan prompt; Canva digunakan untuk mengganti font/warna, menambah logo, merapikan layout, dan export. Workflow ini cocok ketika AI sudah menghasilkan konsep tetapi teks, logo, dan layout perlu presisi.

ALUR PRAKTIK

- 1\. Siapkan judul/hook dan prompt desain di ChatGPT.

- 2\. Bila Canva tersedia sebagai connected app/tool, lakukan otorisasi akun. Pada materi sumber, alur ditunjukkan melalui menu Plugins → Canva → masuk dengan Canva → Allow; label menu dapat berbeda pada versi antarmuka lain.

- 3\. Jika mengedit gambar yang sudah ada, upload gambar ke chat lalu tulis instruksi perubahan.

- 4\. Gunakan perintah seperti “Ubah menjadi editable di Canva” atau “Generate dalam format yang mudah dikonversi menjadi desain Canva”.

- 5\. Jika opsi “Customize this design” tersedia, buka desain di Canva.

- 6\. Finalisasi: font, warna, logo, nomor, harga, tanggal, QR, alignment, dan safe area.

- 7\. Export sesuai platform: misalnya 1080×1350 untuk 4:5 atau 1080×1920 untuk 9:16.

### Format Prompt Desain Sederhana

Rumus: **judul/hook + ukuran + ilustrasi + warna + posisi tulisan**.

```text
Buat desain untuk konten Instagram berukuran 1080×1350 px (rasio 4:5).

Hook: "[GANTI: hook final]".
Ilustrasi: [GANTI: realistic/flat/cinematic/minimalist].
Warna background: [GANTI: nama warna dan HEX].
Warna aksen: [GANTI: nama warna dan HEX].
Komposisi: tempatkan hook di bagian atas ilustrasi dan sisakan ruang aman
untuk CTA di bagian bawah.
CTA: "[GANTI: CTA final]".

Negative: no random text, no typo, no watermark, no clutter.
```

Prinsip finalisasi: AI mempercepat proses, tetapi logo, teks kritikal, warna brand, dan quality control tetap ditangani manusia.

FONDASI 10

## Workflow Video Sederhana: Hook → Script → Prompt → Flow → QC

Materi “Videografi Tanpa Jago” menggunakan ChatGPT untuk ide, hook, dan script, lalu Google Flow untuk mengimplementasikan prompt menjadi video AI. Workflow dasar ini menjadi pintu masuk sebelum peserta memakai JSON yang lebih detail pada proyek-proyek video di bagian berikutnya.

### Prompt Script Video — Siap Salin

```text
Buat script video berdurasi [GANTI: durasi] detik dengan hook:
"[GANTI: hook final]".

Tujuan: [GANTI: awareness/edukasi/konversi].
Target audiens: [GANTI: target audiens].
Platform: [GANTI: Instagram Reels/TikTok/YouTube Shorts].

Susun output dalam tabel: waktu, fungsi beat, visual, aksi, camera,
teks/voice-over, dan audio. Pastikan CTA muncul pada bagian akhir.
```

### Prompt Video — Siap Salin

```text
Buat video [GANTI: durasi] detik, rasio [GANTI: rasio], terdiri dari
[GANTI: jumlah] shot.

Tujuan: [GANTI: tujuan].
Hook 0–2 detik: "[GANTI: hook]".
Gaya visual: [GANTI: gaya].
Camera: tentukan framing dan camera movement untuk setiap shot.
Action: satu aksi utama yang jelas pada setiap shot.
Teks/VO: [GANTI: teks atau voice-over final].
Audio: [GANTI: musik, ambience, dan sound effect].

Pertahankan identitas karakter/produk dari gambar referensi pada semua shot.
Negative: no identity drift, no product deformation, no extra limbs,
no flicker, no typo, no random text, no camera jitter, no watermark.
```

CONTOH KONFIGURASI FLOW PADA MATERI SUMBER

- Buat New Project lalu ubah output menjadi Video.

- Pilih rasio 9:16 / Portrait untuk Reels, TikTok, atau Shorts.

- Pada materi sumber digunakan contoh model “Omni Flash”; gunakan model yang tersedia pada akun/versi Flow saat praktik.

- Pilih durasi 10 detik dan 1× generate untuk uji awal.

- Tempel prompt dari ChatGPT pada bar prompt, generate, lalu tunggu proses selesai.

- Review hasil: apakah hook terbaca, karakter/produk stabil, kamera sesuai, dan tidak ada flicker/deformasi.

- Jika satu video 10 detik terlalu kompleks, pecah menjadi 2–5 klip pendek dan edit kembali di tahap final.

Jangan menyalin contoh akun/login dari screenshot materi ke manual publik. Gunakan akun Google milik peserta masing-masing. Model, durasi maksimum, dan pilihan UI dapat berubah; fokus manual adalah logika workflow.

FONDASI 11

## Latihan Fondasi Sebelum Masuk ke Proyek End-to-End

| **TAHAP** | **TUGAS PESERTA**                                           | **OUTPUT**            |
|-----------|-------------------------------------------------------------|-----------------------|
| 1         | Pilih 1 tema dan tulis target audiens + tujuan.             | Mini brief 3–5 baris  |
| 2         | Generate 30 hook, lalu pilih 3 dan pilih 1 final.           | Hook final            |
| 3         | Pilih 1 gaya visual dari 8 gaya.                            | Visual direction      |
| 4         | Pilih 1 palet warna dan tentukan background/aksen/teks/CTA. | Color lock            |
| 5         | Tulis prompt poster dengan 10 blok formula.                 | Prompt poster         |
| 6         | Generate desain dan finalisasi di Canva.                    | Poster editable/final |
| 7         | Turunkan hook menjadi script video 10 detik.                | Script 10 detik       |
| 8         | Generate video 9:16 di Flow/model video.                    | Video draft           |
| 9         | Lakukan QC dan revisi terbatas.                             | Output approved       |

Setelah fondasi ini dikuasai, peserta memilih proyek sesuai kebutuhan: iklan sepatu, mainan interaktif, squishy, marketplace, flyer event, video edukasi, claymation, animasi anak, AI influencer, video event berseri, atau komik/manga.

## Sumber Materi Tambahan V2.2

- Gen Z Desain Konten Tanpa Jago — materi tools ChatGPT/Canva, urutan konten, hook, prompt desain, koneksi Canva, dan before/after.

- Gen Z Prompt Engineering Poster — prinsip prompt rinci, formula 10 blok, kata kunci gaya/kualitas/lighting/komposisi, dan kesalahan umum.

- Videografi Tanpa Jago — alur hook → script → Google Flow → konfigurasi video → generate.

- Infografis “Daftar Warna dan Kodenya” — kode HEX, warna premium, tips warna.

- Infografis “Kombinasi Warna Terbaik” — palet poster dakwah dan konten Gen Z.

- Infografis “8 Gaya Visual” — cinematic, realistic, minimalist, modern, flat design, elegant, professional, premium.

- Infografis “Prompt AI untuk Menentukan Kualitas Hasil Gambar” — Ultra HD, High Resolution, Professional Printing Quality, Sharp Detail, Photorealistic.

- Infografis ringkasan “Membuat Desain Konten, Tanpa Harus Jago Desain” — tools, hook, struktur konten, prompt, Canva, finalisasi.

# BAGIAN B — Proyek End-to-End

Mulai dari Proyek 01 jika Anda baru pertama kali menggunakan panduan ini. Proyek 01 menjadi contoh paling lengkap dan menunjukkan format prompt siap salin. Setelah memahami polanya, pilih proyek lain sesuai kebutuhan dan ikuti seluruh langkah dalam satu tema hingga output final.

> **Cara membaca setiap proyek:** `LANGKAH` menjelaskan urutan kerja, `PROMPT SIAP COPY` atau `CONTOH / TEMPLATE` berisi instruksi untuk AI, sedangkan `QC` berisi syarat kelulusan output.

PROYEK 01

# Membuat Iklan Sepatu — PVN “Taehyung Blue”

Contoh utama pengelompokan baru: seluruh proses iklan sepatu berada di satu proyek, mulai dari foto produk sampai flyer dan video final.

| **HASIL AKHIR**                                                                                                           | **URUTAN PRAKTIK**                                                                           |
|---------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------|
| 1 creative brief • 10 creative angle • 1 flyer 4:5 • 1 script 10 detik • storyboard 9:16 • JSON image-to-video • QC final | Reference → fakta produk → brief → angle → jalur flyer → jalur video → generate → QC → final |

<img src="media/image1.png" style="width:5.70866in;height:5.70866in" />

LANGKAH 1

## Baca Foto Produk dan Kunci Fakta Visual

Sumber proyek menggambarkan sneaker low-top retro-casual dengan dominasi soft/baby blue, side stripes putih, flat laces senada, serta outsole gum cokelat. Material upper, kenyamanan, bobot, durability, anti-slip, fit, dan benefit teknis lain tidak boleh dijadikan klaim tanpa data produk resmi.

Contoh product reference: PVN “Taehyung Blue” — soft blue tonal, white stripes, gum sole.

| **Elemen**   | **Temuan visual**                            | **Implikasi prompt**                                                |
|--------------|----------------------------------------------|---------------------------------------------------------------------|
| Silhouette   | Sneaker low-top / low-profile retro-casual   | Pertahankan shape dan proporsi rendah di semua shot.                |
| Warna utama  | Soft/baby blue tonal                         | Gunakan sebagai color anchor dan stopping power.                    |
| Aksen        | Dua stripe putih + branding minimal          | Jangan menambah/mengurangi stripe atau logo.                        |
| Outsole      | Gum sole cokelat                             | Wajib konsisten; jangan berubah menjadi white sole.                 |
| Tekstur      | Panel smooth + area bertekstur yang terlihat | Gunakan macro/detail tanpa menyimpulkan material pasti.             |
| Visual world | Clean retro, soft street, denim-friendly     | Background putih/cream/denim/light blue; lighting soft directional. |

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th><p><strong>OUTPUT LANGKAH 1</strong></p>
<p>Daftar fakta visual yang aman dipakai sebagai product lock: soft/baby blue, dua white side stripes, blue laces, gum sole cokelat, low-profile retro silhouette, branding minimal. Klaim material/kenyamanan/grip tidak boleh dibuat tanpa data resmi.</p></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

LANGKAH 2

## Susun Creative Brief Produk

### Prompt Creative Brief — Siap Salin

```text
BERTINDAK SEBAGAI ANALIS PRODUK DAN CREATIVE STRATEGIST PROFESIONAL.

Gunakan foto PVN “Taehyung Blue” sebagai sumber visual utama. Pisahkan: (1) fakta yang terlihat, (2) asumsi kreatif, (3) hal yang perlu dikonfirmasi. Susun creative brief untuk konten gambar dan video sosial media yang mencakup: kategori, silhouette, warna, detail visual, target audiens visual, consumer insight, positioning, single-minded message, tone, visual world, product lock, shot list awal, dan batas klaim. Jangan mengarang material, kenyamanan, durability, anti-slip, endorsement, atau spesifikasi teknis yang tidak terlihat.
```

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th><p><strong>HASIL YANG DIHARAPKAN</strong></p>
<p>Brief menjadi “kontrak kreatif” untuk seluruh output berikutnya. Semua prompt flyer, storyboard, dan video harus mengulang product lock dari brief ini.</p></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

LANGKAH 3

## Buat 10 Creative Angle dan Pilih 1 Angle Utama

Angle dipilih berdasarkan fungsi komunikasi, bukan sekadar variasi kamera.

| **\#** | **Angle**                        | **Funnel**              | **Core Idea**                                        | **Format**             |
|--------|----------------------------------|-------------------------|------------------------------------------------------|------------------------|
| 1      | Blue Is the Outfit               | Awareness               | Warna sepatu sebagai pusat outfit.                   | Fashion / styling      |
| 2      | 3 Looks, 1 Sneaker               | Consideration           | Buktikan fleksibilitas styling.                      | Transition / OOTD      |
| 3      | Details You Missed               | Consideration           | Zoom tekstur, stitching, stripe, gum sole.           | Macro / detail         |
| 4      | Denim Match Test                 | Engagement              | Bandingkan kecocokan dengan berbagai wash denim.     | Challenge / comparison |
| 5      | From Flatlay to On-Feet          | Awareness               | Transformasi produk diam ke real-life look.          | Transition             |
| 6      | Retro Mood in 15 Seconds         | Branding                | Bangun dunia visual retro modern.                    | Editorial / cinematic  |
| 7      | POV: You Found Your Blue Sneaker | Conversion              | Simulasikan moment discovery & desire.               | POV / UGC-style        |
| 8      | Color Pairing Guide              | Saveability             | Panduan warna outfit yang cocok.                     | Educational reel       |
| 9      | The Gum Sole Effect              | Differentiation         | Jelaskan kontras outsole yang membuat look grounded. | Detail-led             |
| 10     | Choose Your Vibe                 | Engagement + Conversion | Satu sneaker, tiga persona/gaya.                     | Interactive / poll     |

Prioritas produksi dari brief: Angle 1, 2, 3, 7, dan 8. Untuk iklan 10 detik pada studi kasus ini dipilih Angle 7 karena paling dekat dengan objective conversion dan format discovery/UGC.

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th><p><strong>PILIHAN STUDI KASUS</strong></p>
<p>Untuk video 10 detik dipilih Angle 7 — “POV: You Found Your Blue Sneaker” karena cocok untuk discovery/conversion. Untuk flyer dipilih Angle 1 — “Blue Is the Outfit” karena warna menjadi stopping power.</p></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

LANGKAH 4

## Jalur A — Buat Flyer Iklan Sepatu 4:5

1.  Tetapkan tujuan flyer: awareness / launch / conversion.

2.  Gunakan satu hero product dan hierarchy: headline → produk → subheadline → CTA → brand.

3.  Generate clean composition lebih dulu; jangan meminta AI merender banyak teks kritikal.

4.  Finalisasi logo, headline, CTA, harga/promo di Canva/Photoshop/Figma.

### Prompt Key Visual — Siap Salin

```text
Buat key visual flyer iklan sneaker PVN “Taehyung Blue” untuk social media.

PRODUCT MASTER
Gunakan gambar produk yang diunggah. Pertahankan persis soft blue upper, dua white side stripes, blue laces, brown gum outsole, low-profile retro silhouette, dan branding minimal.

FORMAT
Rasio 4:5 portrait, premium fashion commercial. Sisakan area aman untuk headline di kiri atas dan CTA di bagian bawah.

CONCEPT
“BLUE IS THE OUTFIT” — sneaker menjadi pusat visual. Gunakan denim folds / light-blue textile sebagai environment, soft directional studio lighting, subtle shadows, clean retro mood, editorial fashion composition.

TEXT PLACEHOLDER
Headline: “BLUE IS THE OUTFIT”
Subheadline: “PVN TAEHYUNG BLUE”
CTA placeholder: “Temukan gayamu.”

IMPORTANT
Generate clean composition. Logo dan tipografi final akan ditempel ulang manual.

NEGATIVE
No shoe deformation, no extra stripes, no white outsole, no logo mutation, no random text, no clutter, no watermark.
```

LANGKAH 5

## Jalur B — Tulis Script Video Iklan 10 Detik

<table style="width:100%;">
<colgroup>
<col style="width: 16%" />
<col style="width: 16%" />
<col style="width: 16%" />
<col style="width: 16%" />
<col style="width: 16%" />
<col style="width: 16%" />
</colgroup>
<thead>
<tr class="header">
<th><strong>Time</strong></th>
<th><strong>Beat</strong></th>
<th><strong>Visual</strong></th>
<th><strong>Camera</strong></th>
<th><strong>Copy / VO</strong></th>
<th><strong>Audio</strong></th>
</tr>
</thead>
<tbody>
<tr class="odd">
<td>0–2s</td>
<td>HOOK</td>
<td>POV tangan membuka shoebox dan memperlihatkan sneaker biru.</td>
<td>Close-up, quick push-in</td>
<td>Teks: “POV: akhirnya nemu sneaker biru yang…”</td>
<td>Beat mulai + SFX box</td>
</tr>
<tr class="even">
<td>2–4s</td>
<td>DISCOVERY</td>
<td>Angkat sepatu; sweep upper biru → stripe putih → gum sole.</td>
<td>Quick detail sweep</td>
<td>Teks: “…ternyata gampang dipaduin 👀”<br />
VO: “Kirain biru bakal susah dipaduin…”</td>
<td>Beat berlanjut</td>
</tr>
<tr class="odd">
<td>4–6s</td>
<td>TRY ON</td>
<td>Snap transition ke on-feet; cream trousers; satu langkah maju.</td>
<td>On-feet medium close</td>
<td>Teks: “Clean look ✓”<br />
VO: “…ternyata clean banget.”</td>
<td>Step SFX + beat</td>
</tr>
<tr class="even">
<td>6–8s</td>
<td>HERO</td>
<td>Low-angle walking lalu side-profile close-up.</td>
<td>Tracking → close-up</td>
<td>Teks: “Soft Blue. Retro Mood.”</td>
<td>Beat drop saat side profile</td>
</tr>
<tr class="odd">
<td>8–10s</td>
<td>CTA</td>
<td>Pair hero 3/4 pada light-blue/denim background.</td>
<td>Slow push-in</td>
<td>“PVN ‘TAEHYUNG BLUE’”<br />
“Would you wear this blue? 💙”</td>
<td>Beat resolve / stop clean</td>
</tr>
</tbody>
</table>

LANGKAH 6

## Ubah Script Menjadi Storyboard 9:16

### Prompt Storyboard — Siap Salin

```text
Buat storyboard production sheet untuk iklan sneaker PVN “Taehyung Blue” berdurasi 10 detik.

FORMAT
- Rasio 9:16 portrait.
- 5 beat/scene sesuai timeline: 0–2s, 2–4s, 4–6s, 6–8s, 8–10s.
- Setiap beat menampilkan reference frame + ARAH KAMERA + AKSI + TEKS DI LAYAR + VO + AUDIO/SOUND.
- Layout harus mudah dibaca tim motion designer.

PRODUCT LOCK — MAXIMUM
Gunakan produk referensi sebagai master. Pertahankan persis: soft muted blue upper, dua white side stripes, brown gum outsole, blue laces, low-profile retro silhouette, minimal PVN branding. Jangan redesign produk.

BEAT 1 — HOOK
POV membuka shoebox, quick push-in. Teks: “POV: akhirnya nemu sneaker biru yang…”

BEAT 2 — DISCOVERY
Tangan mengangkat sepatu; detail sweep upper → stripe → gum sole. Teks: “…ternyata gampang dipaduin 👀”. VO: “Kirain biru bakal susah dipaduin…”

BEAT 3 — TRY ON
Snap transition ke on-feet dengan celana putih/cream; satu langkah maju. Teks: “Clean look ✓”. VO: “…ternyata clean banget.”

BEAT 4 — HERO PRODUCT
Low-angle walking + close-up side profile. Teks: “Soft Blue. Retro Mood.” Beat drop saat side profile muncul.

BEAT 5 — CTA
Hero 3/4 pair shot, light blue/denim background, slow push-in. Teks: “PVN ‘TAEHYUNG BLUE’” + “Would you wear this blue? 💙”.

STYLE
Premium fashion social ad, POV/UGC aesthetic, clean, youthful, realistic product photography, soft directional lighting, denim-friendly palette.

NEGATIVE
No product deformation, no extra stripes, no wrong outsole color, no logo mutation, no deformed hands/feet, no random text, no clutter, no watermark.
```

<img src="media/image2.png" style="width:3.46457in;height:6.15596in" />

Contoh storyboard iklan PVN “Taehyung Blue” — 5 beat, vertical 9:16.

LANGKAH 7

## Siapkan Storyboard sebagai Shot Reference, Bukan Objek yang Dianimasikan

Ketika gambar input berupa lembar storyboard/production sheet, model video dapat salah memahami input dan hanya menggerakkan lembar storyboard. Tambahkan instruksi eksplisit berikut pada prompt:

```text
Use the attached image as storyboard and visual-direction reference only.
Do NOT animate the storyboard sheet, text boxes, grids, labels, panel borders, or infographic layout.
Recreate the actual commercial scenes shown inside the storyboard panels as a seamless vertical advertisement.
```

- Jika platform mendukung beberapa reference: gunakan product master sebagai referensi utama dan storyboard sebagai shot reference.

- Jika hanya satu reference diperbolehkan: pertimbangkan membuat keyframe bersih per beat daripada memakai full storyboard sheet.

- Untuk logo/CTA yang harus 100% benar, gunakan clean hero footage dari AI lalu compositing teks/logo di editor.

LANGKAH 8

## Buat JSON Image-to-Video 10 Detik

### Template JSON Video — Siap Salin

```json
{
"task": "image_to_video",
"duration_seconds": 10,
"aspect_ratio": "9:16",
"fps": 24,
"resolution": "1080x1920",
"reference_instruction": {
"use_attached_image_as": "storyboard and visual direction reference",
"important": "Do not animate the storyboard sheet, text boxes, grids, or infographic layout. Recreate the actual commercial scenes shown inside the storyboard panels as a seamless vertical sneaker advertisement.",
"product_consistency": "Keep exactly the same sneaker design throughout all scenes: soft muted blue upper, white side stripes, brown gum outsole, low-profile retro silhouette, blue laces, minimal PVN branding.",
"style": "premium social media fashion commercial, POV UGC aesthetic mixed with polished product cinematography, clean, youthful, realistic lighting and realistic product proportions"
},
"master_prompt": "Create a fast-paced 10-second vertical social media advertisement. Follow the attached storyboard from scene 1 through scene 5. Start with POV discovery, move into product details, transition into on-feet styling, then show a dynamic low-angle hero sequence and finish with a clean premium product beauty shot. Keep the sneaker identical in every shot.",
"scenes": [
{
"scene": 1,
"time": "0.0-2.0",
"name": "HOOK",
"visual": "First-person POV. Two hands open a simple cardboard shoebox and reveal the soft blue retro sneaker.",
"camera": "close-up POV, subtle handheld realism, quick push-in",
"on_screen_text": "POV: akhirnya nemu sneaker biru yang…",
"audio": "modern fashion beat starts + subtle box/tissue sound"
},
{
"scene": 2,
"time": "2.0-4.0",
"name": "DISCOVERY",
"visual": "Hand lifts sneaker; rapid premium details: blue upper/laces, white side stripes, brown gum outsole.",
"camera": "fast controlled macro sweep",
"on_screen_text": "…ternyata gampang dipaduin 👀",
"voice_over": "Kirain biru bakal susah dipaduin…"
},
{
"scene": 3,
"time": "4.0-6.0",
"name": "TRY ON",
"visual": "Snap transition to on-feet. Loose white/cream trousers, white socks, one confident forward step.",
"camera": "low on-feet medium close shot",
"on_screen_text": "Clean look ✓",
"voice_over": "…ternyata clean banget."
},
{
"scene": 4,
"time": "6.0-8.0",
"name": "HERO PRODUCT",
"visual": "Low-angle walking shot, then cinematic side-profile close-up emphasizing blue upper, white stripes and gum sole.",
"camera": "ground-level tracking -> close side-profile hero",
"on_screen_text": "Soft Blue. Retro Mood.",
"audio": "beat drop exactly on side-profile reveal"
},
{
"scene": 5,
"time": "8.0-10.0",
"name": "CTA",
"visual": "Premium three-quarter hero shot of the pair on a light-blue/denim-inspired background.",
"camera": "stable hero composition with slow push-in",
"on_screen_text": ["PVN 'TAEHYUNG BLUE'", "Would you wear this blue? 💙"],
"audio": "music resolves cleanly on final frame"
}
],
"editing": {
"pace": "fast, energetic and premium",
"transition_style": "snap transitions, match cuts, subtle speed ramps, beat-synchronized cuts",
"motion_blur": "natural cinematic motion blur only",
"color_grade": "clean cool-neutral grade with soft-blue emphasis and warm gum-sole contrast",
"final_frame_hold": "0.5 seconds"
},
"product_rules": [
"Do not change sneaker color between scenes.",
"Do not change brown gum outsole.",
"Keep the same white side stripe design.",
"Keep the same sneaker proportions and silhouette.",
"Do not invent extra logos.",
"Show realistic human hands, feet and anatomy."
],
"negative_prompt": [
"storyboard sheet moving on screen",
"infographic animation",
"split-screen storyboard panels",
"deformed sneaker",
"changing shoe design",
"extra stripes",
"wrong shoe color",
"white outsole",
"mismatched pair",
"deformed hands",
"extra fingers",
"deformed feet",
"unnatural walking",
"floating shoe",
"flickering product",
"logo mutation",
"random text",
"misspelled text",
"excessive camera shake",
"low resolution"
]
}
```

LANGKAH 9

## Generate di Google Flow / Model Video dan Pecah Klip Bila Perlu

5.  Upload product reference yang paling bersih bila tersedia; gunakan sebagai product master.

6.  Upload storyboard sebagai visual-direction reference. Jelaskan bahwa storyboard hanya mengatur urutan, framing, action, dan camera.

7.  Jika hasil produk berubah, pecah generasi menjadi 2–5 klip/keyframe pendek lalu edit menjadi satu video 10 detik.

8.  Untuk shot on-feet, gunakan keyframe khusus dengan produk sudah terpasang di kaki agar model tidak perlu melakukan transformasi sepatu yang kompleks.

9.  Tambahkan teks/CTA di editor bila model menghasilkan tulisan yang salah. AI video sebaiknya fokus pada footage dan motion.

10. Bandingkan frame awal–akhir terhadap product master: silhouette, warna, stripe, outsole, logo, dan laces.

LANGKAH 10

## QC dan Finalisasi

- Produk identik pada Scene 1–5: shape, warna soft blue, dua stripe putih, gum sole cokelat, blue laces.

- Tidak ada outsole berubah putih, stripe bertambah, logo mutasi, atau pair yang berbeda.

- POV tangan terlihat natural dan tidak ada extra fingers/deformasi.

- Transisi box → detail → on-feet → walking → hero terasa logis dan tidak membingungkan.

- Low-angle walking tidak membuat sepatu melengkung/mencair atau ukuran kaki berubah.

- Tempo cukup cepat untuk 10 detik, tetapi hero product masih terbaca.

- Copy tidak membuat klaim material/kenyamanan/grip/fit yang belum diverifikasi.

- Nama “Taehyung” tidak dipresentasikan sebagai endorsement atau kolaborasi figur publik tanpa bukti resmi.

- CTA dan logo final diperiksa/ditambahkan ulang secara manual jika perlu.

- File final benar-benar 9:16, 1080×1920 atau resolusi ekuivalen, dengan safe area platform.

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th><p><strong>OUTPUT FINAL PROYEK 01</strong></p>
<p>Folder akhir minimal berisi: PVN_BRIEF.docx • PVN_10_ANGLES.docx • PVN_FLYER_4x5.png • PVN_SCRIPT_10S.docx • PVN_STORYBOARD_9x16.png • PVN_VIDEO_PROMPT.json • PVN_VIDEO_FINAL.mp4 • aset logo/teks final.</p></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

PROYEK 02

# Membuat Iklan Mainan Interaktif — Doll Catcher 1140

Proyek latihan untuk produk yang nilai jualnya muncul dari mekanisme permainan: target → claw → suspense → hadiah.

| **HASIL AKHIR**                                                                         | **URUTAN PRAKTIK**                                                                   |
|-----------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------|
| Product facts • 10 creative angle • script 10 detik • storyboard 9:16 • JSON video • QC | Listing/packshot → product lock → angle → script → storyboard → JSON → generate → QC |

LANGKAH 1

## Baca Product Reference dan Tetapkan Product Lock

| **Elemen**            | **Temuan**                                                 | **Implikasi Prompt**                                                            |
|-----------------------|------------------------------------------------------------|---------------------------------------------------------------------------------|
| Kategori              | Mainan mesin capit mini / mini claw machine                | Bangun cerita interaksi ala arcade mini di rumah.                               |
| Silhouette            | Mini arcade / candy kiosk                                  | Pertahankan bentuk utama agar mudah dikenali di thumbnail kecil.                |
| Warna                 | Biru pastel, pink-putih, kuning                            | Gunakan sebagai palet visual utama seluruh iklan.                               |
| Ruang hadiah          | Kompartemen transparan dengan bola/benda kecil warna-warni | Jadikan claw movement dan target hadiah sebagai visual hook.                    |
| Kontrol               | Tuas/tombol hijau-kuning di area depan                     | Gunakan close-up tangan saat demo; fungsi aktual tetap perlu diverifikasi.      |
| Prize chute           | Ruang keluaran di sisi depan/kanan                         | Gunakan sebagai payoff visual saat bola berhasil jatuh.                         |
| Dimensi terlihat      | ±26 × 26 × 20 cm berdasarkan listing                       | Boleh digunakan untuk size-check dengan label sumber; verifikasi sebelum final. |
| Harga/rating snapshot | Rp267.750; rating 4,9/5 dari 38 penilaian pada snapshot    | Data dinamis; cek ulang pada hari publikasi.                                    |

LANGKAH 2

## Buat 10 Creative Angle

| **\#** | **Angle**                          | **Hook / Big Idea**                                     | **Tujuan Utama**                                |
|--------|------------------------------------|---------------------------------------------------------|-------------------------------------------------|
| 1      | POV: Punya Arcade Mini di Rumah    | “Nggak perlu keluar rumah buat main mesin capit.”       | Awareness + conversion                          |
| 2      | Challenge: 3 Kali Coba Bisa Dapat? | “Kasih aku 3 kesempatan. Bisa menang nggak?”            | Engagement                                      |
| 3      | Kado yang Langsung Bikin Main      | “Kalau kado biasa cuma dibuka. Ini langsung dimainkan.” | Conversion / gifting                            |
| 4      | Satisfying Claw & Drop             | “Tunggu sampai bolanya jatuh…”                          | Awareness / ASMR visual                         |
| 5      | Cute Desk / Playroom Upgrade       | “Mainan atau dekor? Kenapa nggak dua-duanya?”           | Awareness / aesthetic                           |
| 6      | Reaction Anak / Family Play        | “Ekspresi pas akhirnya berhasil…”                       | Engagement                                      |
| 7      | Mini Review: 3 Hal yang Menarik    | “3 hal yang bikin mainan ini beda.”                     | Consideration                                   |
| 8      | Size Check: Sebesar Apa Sih?       | “Di foto kelihatan gede. Aslinya segini.”               | Consideration                                   |
| 9      | Isi Sendiri, Main Berkali-kali     | “Kalau hadiahnya bisa kamu atur sendiri…”               | Consideration; hanya setelah verifikasi fitur   |
| 10     | Worth It di Harga Segini?          | “Rp200 ribuan buat mini claw machine—worth it?”         | Consideration / conversion; harga wajib terbaru |

Prioritas workflow proyek ini: Angle 1 — “POV: Punya Arcade Mini di Rumah” karena paling mudah menampilkan bentuk produk, cara interaksi, suspense, dan payoff dalam satu video 10 detik.

LANGKAH 3

## Pilih Angle dan Tulis Script 10 Detik

<table style="width:100%;">
<colgroup>
<col style="width: 16%" />
<col style="width: 16%" />
<col style="width: 16%" />
<col style="width: 16%" />
<col style="width: 16%" />
<col style="width: 16%" />
</colgroup>
<thead>
<tr class="header">
<th><strong>Time</strong></th>
<th><strong>Beat</strong></th>
<th><strong>Visual</strong></th>
<th><strong>Camera</strong></th>
<th><strong>Copy / VO</strong></th>
<th><strong>Audio</strong></th>
</tr>
</thead>
<tbody>
<tr class="odd">
<td>0–2s</td>
<td>HOOK</td>
<td>Macro claw turun hampir menangkap bola, lalu zoom-out reveal produk utuh.</td>
<td>Macro close-up → quick zoom-out</td>
<td>Overlay: “POV: PUNYA MESIN CAPIT SENDIRI 😍”<br />
VO: “Bayangin punya arcade mini sendiri!”</td>
<td>Upbeat music + whoosh</td>
</tr>
<tr class="even">
<td>2–4s</td>
<td>PLAY</td>
<td>Tangan mengoperasikan kontrol; claw bergerak ke target.</td>
<td>Close-up control → interior claw</td>
<td>Overlay: “PILIH TARGET 🎯”<br />
VO: “Arahkan…”</td>
<td>Click-click mechanical SFX</td>
</tr>
<tr class="odd">
<td>4–7s</td>
<td>SUSPENSE</td>
<td>Claw turun, menjepit bola pink, lalu mengangkatnya.</td>
<td>Extreme macro + subtle push-in</td>
<td>Overlay: “DAPAT NGGAK NIH? 👀”<br />
VO: “Capit… dan…”</td>
<td>Beat ditahan + suspense riser</td>
</tr>
<tr class="even">
<td>7–9s</td>
<td>WIN MOMENT</td>
<td>Bola jatuh ke chute; tangan mengambil hadiah.</td>
<td>Tracking close-up → chute close-up</td>
<td>Overlay: “YES! DAPAT! 🎉”<br />
VO: “YES! Dapat!”</td>
<td>TING! + celebratory pop</td>
</tr>
<tr class="odd">
<td>9–10s</td>
<td>CTA</td>
<td>Hero shot produk 3/4 di set pastel candy-shop.</td>
<td>Fast subtle push-in</td>
<td>Headline: “ARCADE MINI DI RUMAH!”<br />
CTA: “CEK SEKARANG 🛒”<br />
VO: “Siap coba?”</td>
<td>Beat resolve / pop ending</td>
</tr>
</tbody>
</table>

LANGKAH 4

## Buat Storyboard 9:16

CONTOH / TEMPLATE

Buat storyboard production sheet untuk iklan Doll Catcher 1140 berdurasi 10 detik.

FORMAT
- Rasio 9:16 portrait.
- 5 beat: 0–2s, 2–4s, 4–7s, 7–9s, 9–10s.
- Setiap beat menampilkan reference frame, timecode, shot/camera, action, text overlay, voice-over, dan audio/SFX.
- Layout clean, pastel, mudah dibaca tim motion designer.

PRODUCT LOCK — MAXIMUM
Gunakan Doll Catcher 1140 sebagai product master. Pertahankan persis: bodi biru pastel, kanopi pink-putih, ruang display transparan, kontrol hijau-kuning, claw metal tiga jari, bola pastel warna-warni, prize chute, proporsi produk, dan gaya candy-shop mini. Jangan redesign produk.

BEAT 1 — HOOK
Extreme macro claw hampir menangkap bola; quick zoom-out reveal produk. Overlay: “POV: PUNYA MESIN CAPIT SENDIRI 😍”.

BEAT 2 — PLAY
Close-up tangan mengoperasikan kontrol; claw bergerak menuju target. Overlay: “PILIH TARGET 🎯”.

BEAT 3 — SUSPENSE
Macro claw turun, menjepit bola pink, lalu mengangkatnya. Overlay: “DAPAT NGGAK NIH? 👀”.

BEAT 4 — WIN MOMENT
Bola dijatuhkan ke chute lalu diambil tangan. Overlay: “YES! DAPAT! 🎉”.

BEAT 5 — CTA
Hero product 3/4 di background pastel candy-shop. Headline: “ARCADE MINI DI RUMAH!” CTA: “CEK SEKARANG 🛒”.

STYLE
Premium toy commercial, cute pastel candy aesthetic, bright soft studio lighting, realistic product materials, playful social-media energy.

NEGATIVE
No product deformation, no wrong colors, no extra controls, no claw mutation, no deformed hands, no unreadable text, no watermark.

Contoh output storyboard iklan 10 detik — Doll Catcher 1140, 5 beat, ratio 9:16.

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th><p><strong>CATATAN PRAKTIK</strong></p>
<p>QC cepat storyboard: urutan 5 beat mengikuti script; produk konsisten; claw dan bola target tidak berubah; overlay singkat; hero shot akhir memberi ruang yang bersih untuk CTA.</p></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

LANGKAH 5

## Siapkan Storyboard untuk Image-to-Video

- Use the attached storyboard as storyboard and visual-direction reference only.

- Do NOT animate the storyboard sheet, text boxes, grids, labels, arrows, panel borders, or infographic layout.

- Recreate the actual commercial scenes shown inside the storyboard panels as one seamless vertical advertisement.

- Jika platform mendukung beberapa reference, gunakan product master sebagai referensi utama dan storyboard sebagai shot/timing reference.

- Jika hasil tulisan AI tidak stabil, generate clean footage tanpa teks lalu tambahkan overlay dan CTA di editor.

LANGKAH 6

## Buat JSON Video

CONTOH / TEMPLATE

{
"project": {
"title": "Doll Catcher 1140 - POV Arcade Mini di Rumah",
"type": "social_media_product_ad",
"duration_seconds": 10,
"aspect_ratio": "9:16",
"resolution": "1080x1920",
"fps": 30,
"visual_style": "hyper-realistic commercial product video, cute pastel aesthetic, premium toy advertisement, soft cinematic lighting"
},
"reference_instruction": "Use the attached storyboard as the primary shot and sequencing reference. Do not animate the storyboard sheet itself. Recreate the actual scenes inside the panels as one seamless vertical commercial. Maintain the Doll Catcher 1140 product design throughout all shots.",
"product_lock": {
"priority": "MAXIMUM",
"must_preserve": [
"pastel blue body",
"pink and white striped canopy",
"transparent prize chamber",
"green and yellow controls",
"same three-prong metal claw",
"same prize chute",
"same overall product proportions"
]
},
"timeline": [
{
"scene": 1,
"time": "0.0-2.0",
"purpose": "HOOK",
"visual": "Extreme macro shot inside the machine. The claw descends toward colorful pastel balls and almost catches a pink ball, followed by a fast smooth zoom-out revealing the complete Doll Catcher 1140.",
"camera": "macro close-up -> quick smooth zoom-out",
"text_overlay": "POV: PUNYA MESIN CAPIT SENDIRI 😍",
"voice_over": "Bayangin punya arcade mini sendiri!",
"audio": "upbeat playful music + mechanical claw sound + soft whoosh"
},
{
"scene": 2,
"time": "2.0-4.0",
"purpose": "PLAY",
"visual": "Close-up of a hand operating the green and yellow controls. Cut to the claw moving toward the target pink ball.",
"camera": "tight product close-up -> interior claw POV",
"text_overlay": "PILIH TARGET 🎯",
"voice_over": "Arahkan...",
"audio": "rhythmic click-click mechanical SFX"
},
{
"scene": 3,
"time": "4.0-7.0",
"purpose": "SUSPENSE",
"visual": "Cinematic macro view of the claw descending around the same glossy pink ball, closing firmly and lifting it.",
"camera": "extreme macro + shallow depth of field + subtle push-in",
"speed_effect": "subtle slow motion at the exact grip moment",
"text_overlay": "DAPAT NGGAK NIH? 👀",
"voice_over": "Capit... dan...",
"audio": "music briefly reduces intensity + suspense riser"
},
{
"scene": 4,
"time": "7.0-9.0",
"purpose": "WIN_MOMENT",
"visual": "The claw carries the same pink ball over the prize chute and releases it. The ball drops naturally, then a hand takes it from the prize opening.",
"camera": "tracking close-up -> quick chute close-up",
"text_overlay": "YES! DAPAT! 🎉",
"voice_over": "YES! Dapat!",
"audio": "bright TING + celebratory pop"
},
{
"scene": 5,
"time": "9.0-10.0",
"purpose": "PRODUCT_HERO_CTA",
"visual": "Premium three-quarter hero shot of the complete Doll Catcher 1140 on a clean tabletop with a soft pastel candy-shop environment.",
"camera": "fast subtle cinematic push-in",
"headline": "ARCADE MINI DI RUMAH!",
"cta": "CEK SEKARANG 🛒",
"voice_over": "Siap coba?",
"audio": "upbeat music resolves with cheerful pop ending"
}
],
"editing": {
"pace": "fast, energetic and optimized for TikTok, Reels and Shorts",
"average_shot_length": "0.5-1.5 seconds",
"transitions": "quick cuts, match cuts, subtle whip transitions and light speed ramps",
"retention_strategy": "open immediately with the claw almost catching a ball; do not start with a static packshot"
},
"continuity": {
"product": "Keep exactly the same product design, proportions, colors and controls in every scene.",
"claw": "Maintain identical three-prong metal claw geometry throughout the video.",
"target_ball": "Use the same glossy pink ball from suspense through the winning sequence.",
"environment": "Maintain the same pastel visual world and lighting direction throughout."
},
"negative_prompt": [
"storyboard sheet animation",
"product shape changing between shots",
"incorrect product colors",
"extra joysticks",
"extra buttons",
"deformed hands",
"extra fingers",
"floating objects",
"ball passing through claw",
"unrealistic physics",
"warped claw",
"duplicated balls",
"random text",
"misspelled text",
"flickering",
"camera jitter",
"low resolution",
"watermark"
]
}

LANGKAH 7

## Generate dan Jaga Mekanisme Produk

11. Jika tersedia, upload packshot/product reference yang paling bersih sebagai product master dan storyboard sebagai shot reference.

12. Untuk konsistensi paling tinggi, pecah 10 detik menjadi beberapa keyframe/klip pendek bila model mulai mengubah bentuk claw, kontrol, chute, atau proporsi produk.

13. Gunakan satu bola target yang sama dari Scene 3 sampai Scene 4 agar payoff terasa kontinu dan tidak terjadi object swap.

14. Jangan meminta terlalu banyak teks generatif. Overlay “PILIH TARGET”, “YES! DAPAT!”, headline, dan CTA lebih aman ditambahkan di editor.

15. Gerakan tangan harus sederhana dan terkontrol. Shot kontrol dan shot mengambil bola lebih stabil jika menggunakan keyframe khusus.

16. Bandingkan frame awal, frame kemenangan, dan hero closing terhadap product master: warna bodi, kanopi, control layout, claw, prize chute, dan silhouette.

LANGKAH 8

## QC dan Finalisasi

- Doll Catcher identik pada semua beat: bodi biru pastel, kanopi pink-putih, ruang transparan, kontrol hijau-kuning, claw, dan prize chute.

- Tidak ada joystick/tombol tambahan, claw berubah bentuk, produk membesar/mengecil ekstrem, atau warna produk drift.

- Bola pink yang ditargetkan pada suspense adalah bola yang sama pada win moment.

- Tangan terlihat natural, tidak ada extra fingers, deformasi, atau tangan menembus produk.

- Fisika bola masuk akal: dijepit, diangkat, dipindahkan, dilepas, lalu jatuh ke chute dengan gravity natural.

- Hook sudah muncul dalam 0–2 detik dan tidak diawali penjelasan panjang.

- Pacing cukup cepat untuk 10 detik tetapi momen grip dan prize drop tetap terbaca.

- Copy tidak menggunakan klaim sumber daya, usia, keamanan, musik/lampu, isi paket, atau fitur isi ulang sebelum diverifikasi.

- Harga/rating/promo, bila dipakai, diperiksa ulang pada hari publikasi.

- File final 9:16, 1080×1920 atau ekuivalen, CTA berada di safe area, dan teks/logo final diperiksa manual.

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th><p><strong>OUTPUT FINAL PROYEK 02</strong></p>
<p>Iklan 10 detik harus memperlihatkan satu bola target yang konsisten dari suspense sampai win moment, claw tidak berubah bentuk, kontrol produk tidak bertambah, dan CTA final berada di safe area.</p></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

PROYEK 03

# Membuat Iklan Squishy / Sensory Toy — NeeDoh Nice Cube

Proyek latihan untuk produk tactile/satisfying. Fokus utama bukan spesifikasi, tetapi pengalaman visual press → squeeze → release → recovery.

| **HASIL AKHIR**                                                                                  | **URUTAN PRAKTIK**                                                                                      |
|--------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------|
| Product/claim lock • 10 angle • script 10 detik • storyboard 9:16 • JSON video • foley plan • QC | Reference → klaim aman → satisfying angle → script → storyboard → JSON → slow-rise footage → audio → QC |

<img src="media/image3.png" style="width:5.70866in;height:2.96726in" />

LANGKAH 1

## Pisahkan Fakta, Klaim Listing, dan Hal yang Belum Pasti

Sumber proyek merupakan product & content brief yang disusun dari screenshot listing marketplace. Data dinamis seperti harga, rating, jumlah penilaian, stok, dan varian harus diverifikasi kembali pada hari publikasi.

| **Elemen**                    | **Temuan dari brief**                                            | **Implikasi prompt / produksi**                                                                                   |
|-------------------------------|------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------|
| Nama listing                  | NeeDoh Nice Cube / Cube Squishy Stress Ball / fidget toy         | Gunakan sebagai identitas kerja; penggunaan nama merek resmi tetap perlu dicocokkan dengan kemasan/listing aktif. |
| Bentuk                        | Kubus dengan sudut membulat, permukaan tampak lembut/translucent | Product lock: bentuk cube dan rounded corners harus tetap sama di semua shot.                                     |
| Warna utama                   | Biru/cyan, pink, ungu                                            | Gunakan sebagai color story dan CTA interaktif; jangan melakukan color drift di tengah shot.                      |
| Hero interaction              | Press, pinch, full squeeze, release, slow-rise/recovery          | Jadikan deformation dan recovery sebagai pusat visual video.                                                      |
| Klaim listing                 | “Super solid squishy”, “slow rising”, “squeeze ball”             | Perlakukan sebagai klaim listing; demonstrasikan perilaku aktual dan hindari angka durasi bila belum diuji.       |
| Harga & social proof snapshot | Rp88.000; rating 4,7/5; 432 penilaian pada brief                 | Data dinamis; jangan hard-code pada evergreen creative tanpa verifikasi terbaru.                                  |
| Hal belum pasti               | Material, ukuran, berat, usia, sertifikasi, isi box, durability  | Jangan dijadikan klaim iklan sebelum diverifikasi dari produk fisik/kemasan/seller.                               |

Contoh source reference: visual listing yang menjadi basis product brief.

LANGKAH 2

## Buat 10 Creative Angle

| **\#** | **Angle**                           | **Tujuan**              | **Hook / Core Idea**                                                       |
|--------|-------------------------------------|-------------------------|----------------------------------------------------------------------------|
| 1      | The Satisfying Squish Test          | Awareness / stop-scroll | “Seberapa satisfying kalau kubus ini dipencet sampai gepeng?”              |
| 2      | POV: Tangan Butuh Kesibukan         | Relatability            | Desk break singkat: tangan pindah dari mouse ke cube lalu kembali bekerja. |
| 3      | Pick Your Color / Color Personality | Engagement              | “Pilih warna tanpa mikir.” Blue vs Pink vs Purple.                         |
| 4      | Expectation vs Reality              | Trust / conversion      | Bandingkan visual listing dengan produk fisik dan first squeeze.           |
| 5      | ASMR No Talking                     | Retention / rewatch     | Macro squeeze + foley tanpa narasi panjang.                                |
| 6      | One Product, 5 Ways to Squish       | Product education       | Finger press, corner pinch, palm squeeze, two-hand crush, flat press.      |
| 7      | Gift Idea Under 100K                | Conversion              | Small colorful gift; harga harus diverifikasi saat tayang.                 |
| 8      | What’s in My Bag: Tiny Fun Edition  | Lifestyle / portability | Cube sebagai benda kecil yang ikut di pouch/tas.                           |
| 9      | 3-Color Squish Race                 | Entertainment / replay  | Tiga warna dilepas bersamaan; hasil harus berupa uji nyata.                |
| 10     | Review in 15 Seconds                | Lower-funnel            | Look, Squish, Slow-rise, Giftability; skor hanya setelah produk diuji.     |

Prioritas workflow proyek ini: Angle 1 — “The Satisfying Squish Test”, karena paling langsung memperlihatkan hero experience produk dan paling cocok untuk hook 1 detik pertama.

LANGKAH 3

## Pilih Angle “The Satisfying Squish Test” dan Tulis Script

| **Time**  | **Beat** | **Visual**                                                      | **Camera**                             | **Copy / VO**                                                                    | **Audio**                           |
|-----------|----------|-----------------------------------------------------------------|----------------------------------------|----------------------------------------------------------------------------------|-------------------------------------|
| 0.0–1.0s  | HOOK     | Cube biru normal; dua jari mulai menekan sisi cube.             | Extreme macro close-up; subtle push-in | Teks: “SE-SATISFYING INI?”                                                       | Soft squish + beat mulai            |
| 1.0–2.5s  | PENCET   | Cube pink ditekan lebih dalam hingga terlihat deformasi.        | Macro push-in                          | Teks: “PENCET.” \| VO: “Pencet...”                                               | Clear soft squish                   |
| 2.5–4.5s  | REMAS    | Cube ungu diremas penuh dalam satu tangan sampai gepeng.        | Tight close-up                         | Teks: “REMAS.” \| VO: “Remas...”                                                 | Deep satisfying squish              |
| 4.5–7.0s  | LEPAS    | Tekanan dilepas; cube mulai kembali ke bentuk awal.             | Macro static / locked                  | Teks: “LEPAS.” \| VO: “Lepas...”                                                 | Release squish; musik sedikit turun |
| 7.0–8.5s  | PAYOFF   | Cube hampir kembali normal; glossy highlight menegaskan bentuk. | Macro beauty close-up                  | Teks: “BALIK LAGI...”                                                            | Soft pop + music rise               |
| 8.5–10.0s | CTA      | Blue, Pink, Purple berjajar; subtle bounce lalu settle.         | Medium close-up / top-front            | “BLUE 💙 PINK 🩷 PURPLE 💜” + “Kamu pilih mana?” \| VO: “Pilih warna favoritmu!” | Three soft pops + beat resolve      |

Voice-over ringkas: “Pencet... remas... lepas... terus lihat dia balik lagi. Kamu pilih warna yang mana?”

Versi super singkat: “Pencet. Remas. Lepas. Pilih warna favoritmu.”

LANGKAH 4

## Buat Storyboard 9:16

CONTOH / TEMPLATE

Buat storyboard production sheet untuk iklan NeeDoh Nice Cube berdurasi 10 detik berdasarkan Angle “The Satisfying Squish Test”.

FORMAT
- Rasio 9:16 portrait.
- Durasi total 10 detik.
- 6 beat: 0–1s, 1–2.5s, 2.5–4.5s, 4.5–7s, 7–8.5s, 8.5–10s.
- Setiap beat menampilkan reference frame, timecode, fungsi shot, camera/shot, action, text layer, VO, dan audio/SFX.
- Layout clean, colorful, mudah dibaca tim motion designer.

PRODUCT LOCK — MAXIMUM
Gunakan produk referensi sebagai product master. Pertahankan bentuk cube dengan rounded corners, translucent/glossy appearance, proporsi, dan warna blue/pink/purple. Jangan mengubah cube menjadi benda cair, crystal solid, candy, atau bentuk lain.

BEAT 1 — HOOK
Extreme macro cube biru; dua jari menekan sisi produk. Quick subtle push-in. Text: “SE-SATISFYING INI?”.

BEAT 2 — PENCET
Macro cube pink; dua ibu jari menekan dalam. Text: “PENCET.”. VO: “Pencet...”.

BEAT 3 — REMAS
Cube ungu diremas penuh dalam satu tangan. Tight close-up. Text: “REMAS.”. VO: “Remas...”.

BEAT 4 — LEPAS
Kembali ke cube biru; jari melepas tekanan dan slow-rise terlihat jelas. Macro static. Text: “LEPAS.”. VO: “Lepas...”.

BEAT 5 — PAYOFF
Hero macro cube pink hampir kembali sempurna, glossy highlight dan subtle sparkle. Text: “BALIK LAGI...”.

BEAT 6 — CTA
Blue, Pink, Purple berjajar pada studio pastel clean. Medium close-up / top-front. Text: “BLUE 💙 PINK 🩷 PURPLE 💜” + “Kamu pilih mana?”. VO: “Pilih warna favoritmu!”.

STYLE
Bright, clean, colorful, tactile, glossy, premium social-media product commercial; pastel studio background; softbox lighting + subtle backlight; shallow depth of field; realistic hands; macro product photography.

AUDIO
Foley squeeze menjadi hero; musik playful modern tetapi tidak menutupi suara tactile.

NEGATIVE
No product redesign, no melting/leaking, no hard-crystal material, no extra fingers, no malformed hands, no wrong cube colors, no random logos, no unreadable text, no watermark.

<img src="media/image4.png" style="width:3.46457in;height:6.15596in" />

Contoh storyboard vertical NeeDoh — squeeze, release, slow-rise, CTA warna.

LANGKAH 5

## Persiapkan Storyboard sebagai Reference

- Use the attached image as storyboard and visual reference only.

- Do NOT animate the storyboard poster, text boxes, labels, grids, panel borders, arrows, or infographic layout.

- Recreate the actual commercial scenes shown inside the storyboard panels as one seamless vertical product advertisement.

- Jika platform mendukung beberapa reference, gunakan packshot/product master sebagai referensi utama dan storyboard sebagai shot/timing reference.

- Jika hanya satu reference diperbolehkan dan model terus menganimasikan lembar storyboard, buat clean keyframe per beat lalu generate klip pendek satu per satu.

- Untuk teks seperti “PENCET”, “REMAS”, “LEPAS”, pilihan warna, harga, atau CTA, footage tanpa teks biasanya lebih stabil; tambahkan overlay di editor.

LANGKAH 6

## Buat JSON Image-to-Video

CONTOH / TEMPLATE

{
"project": {
"title": "NeeDoh Nice Cube - The Satisfying Squish Test",
"type": "image_to_video_ad",
"duration_seconds": 10,
"aspect_ratio": "9:16",
"resolution": "1080x1920",
"fps": 30,
"platform": [
"TikTok",
"Instagram Reels",
"YouTube Shorts"
]
},
"reference_image_instruction": {
"use_uploaded_image_as": "storyboard and visual reference",
"important": "Do not animate the storyboard poster itself. Recreate the final commercial video described by the storyboard panels.",
"product_consistency": "Keep the squishy cube appearance consistent with the storyboard: translucent glossy cube, rounded corners, soft gel-like visual body, vivid blue, pink and purple variants.",
"hand_consistency": "Use clean realistic adult hands with natural anatomy and consistent skin tone throughout the video."
},
"creative_direction": {
"style": "premium social media product commercial",
"mood": [
"satisfying",
"playful",
"colorful",
"tactile",
"clean",
"energetic"
],
"visual_style": "hyper-realistic macro product photography",
"background": "minimal soft pastel studio background",
"lighting": "large softbox lighting with subtle backlight and glossy highlights",
"color_palette": [
"cyan blue",
"hot pink",
"purple",
"soft white"
],
"editing_style": "fast hook, smooth macro cuts, satisfying slow-rise payoff, clean commercial finish",
"depth_of_field": "shallow depth of field with sharp focus on the squishy cube"
},
"scenes": [
{
"scene": 1,
"time": "0.0-1.0",
"purpose": "HOOK",
"visual": "Extreme macro close-up of a glossy translucent blue squishy cube in its normal cube shape. Two fingers enter from left and right and begin pressing both sides inward.",
"camera": {
"shot": "extreme macro close-up",
"movement": "very subtle cinematic push-in",
"focus": "sharp focus on the cube deformation"
},
"motion": "The cube immediately starts compressing between the fingers with realistic elastic deformation.",
"on_screen_text": "SE-SATISFYING INI?",
"audio": {
"sfx": "soft wet squish",
"music": "playful upbeat beat begins immediately"
}
},
{
"scene": 2,
"time": "1.0-2.5",
"purpose": "PENCET",
"visual": "Cut to a translucent bright pink cube. Two thumbs press deeply into the soft cube from both sides, creating exaggerated but believable deformation.",
"camera": {
"shot": "macro close-up",
"movement": "slow push-in",
"focus": "thumb pressure and cube texture"
},
"motion": "The cube bends and bulges naturally around the fingers.",
"on_screen_text": "PENCET.",
"voice_over": "Pencet...",
"audio": {
"sfx": "clear soft squish synchronized with finger pressure"
}
},
{
"scene": 3,
"time": "2.5-4.5",
"purpose": "REMAS",
"visual": "A translucent purple cube is fully squeezed inside one hand. The cube becomes heavily compressed while maintaining a believable soft consistency.",
"camera": {
"shot": "tight close-up of hand and product",
"movement": "almost static with tiny cinematic motion",
"focus": "compressed cube"
},
"motion": "The hand slowly increases pressure until the cube becomes almost completely compressed.",
"on_screen_text": "REMAS.",
"voice_over": "Remas...",
"audio": {
"sfx": "deeper satisfying squish"
}
},
{
"scene": 4,
"time": "4.5-7.0",
"purpose": "LEPAS",
"visual": "Return to a translucent blue cube. The fingers gradually release pressure. The flattened cube starts expanding and slowly recovering its original rounded cube form.",
"camera": {
"shot": "macro static close-up",
"movement": "locked camera",
"focus": "slow-rise transformation"
},
"motion": "Show the slow-rise recovery clearly in real time. Make the elastic expansion smooth and physically believable.",
"speed": "slightly slower cinematic motion without looking artificially slowed",
"on_screen_text": "LEPAS.",
"voice_over": "Lepas...",
"audio": {
"sfx": "gentle release squish",
"music": "beat temporarily softens to emphasize the recovery"
}
},
{
"scene": 5,
"time": "7.0-8.5",
"purpose": "PAYOFF",
"visual": "Beautiful hero macro shot of a bright pink cube almost completely restored to its original shape. Glossy reflections travel across the translucent surface with a subtle sparkle highlight.",
"camera": {
"shot": "macro beauty close-up",
"movement": "slow cinematic push-in",
"focus": "restored cube shape and glossy texture"
},
"motion": "The final corners gently return into shape.",
"on_screen_text": "BALIK LAGI...",
"audio": {
"sfx": "soft glossy pop",
"music": "small uplifting musical rise"
}
},
{
"scene": 6,
"time": "8.5-10.0",
"purpose": "CTA",
"visual": "Final clean studio hero shot showing three identical squishy cubes standing side by side: blue on the left, pink in the center and purple on the right. Each cube makes one subtle playful bounce.",
"camera": {
"shot": "medium close-up front three-quarter view",
"movement": "very subtle push-in",
"focus": "all three products sharp"
},
"motion": "Blue, pink and purple cubes perform a tiny sequential bounce, then settle perfectly aligned.",
"on_screen_text": [
"BLUE 💙",
"PINK 🩷",
"PURPLE 💜",
"Kamu pilih mana?"
],
"voice_over": "Pilih warna favoritmu!",
"audio": {
"sfx": "three subtle soft pops synchronized with the cubes",
"music": "finish with a bright playful beat"
}
}
],
"voice_over": {
"language": "Indonesian",
"voice_style": "young adult, cheerful, energetic, friendly, conversational",
"script": "Pencet... remas... lepas... terus lihat dia balik lagi. Kamu pilih warna yang mana?",
"delivery": "short punchy phrases synchronized with each squeeze action"
},
"sound_design": {
"priority": "The real squish sound is one of the hero elements of the advertisement.",
"music": "modern playful light electronic beat",
"foley": [
"soft squeeze",
"deep squish",
"elastic release",
"subtle pop"
],
"mixing": "Keep foley clearly audible above the background music."
},
"text_style": {
"font_style": "bold rounded playful sans serif",
"text_position": "centered within mobile safe zones",
"appearance": "white text with cyan, pink or purple outline depending on the scene",
"animation": "quick pop-in with subtle scale bounce",
"important": "Keep text large and readable; for production reliability, final typography can be composited in the editor."
},
"camera_rules": {
"orientation": "vertical portrait",
"product_centered": true,
"mobile_safe_area": true,
"macro_detail": true,
"avoid_excessive_camera_motion": true,
"transitions": [
"clean hard cuts",
"macro match cuts"
]
},
"quality_requirements": [
"photorealistic product",
"realistic soft-body physics",
"natural hand anatomy",
"consistent cube size and geometry",
"consistent translucent glossy appearance",
"premium studio lighting",
"sharp macro detail",
"commercial advertising quality",
"smooth 30fps movement",
"no visual flicker"
],
"negative_prompt": [
"do not animate the storyboard sheet",
"no infographic visible in final video",
"no split screen storyboard layout",
"no extra fingers",
"no malformed hands",
"no fused fingers",
"no deformed anatomy",
"no melting cube",
"no liquid leaking",
"no torn product",
"no cracked product",
"no inconsistent cube shape",
"no unexpected color changes",
"no disappearing objects",
"no floating hands",
"no warped background",
"no camera shake",
"no excessive motion blur",
"no flickering",
"no duplicated products except the intentional three cubes in the final scene",
"no random logos",
"no watermark",
"no unreadable text",
"no misspelled text"
],
"final_instruction": "Create one seamless 10-second vertical commercial. The first second must immediately stop the scroll with an extreme macro squeeze. Build visual satisfaction through press, full squeeze and slow release, then end with a clean blue-pink-purple product lineup and an interactive CTA. Prioritize believable squishy physics, glossy translucent appearance and satisfying synchronized sound."
}

LANGKAH 7

## Generate, Pecah Klip, dan Rekam Foley

17. Jika tersedia, upload product reference paling bersih sebagai product master dan storyboard sebagai visual-direction reference.

18. Untuk hasil paling konsisten, generate footage tanpa teks terlebih dahulu. Overlay “PENCET”, “REMAS”, “LEPAS”, warna, harga, dan CTA ditambahkan di CapCut/Premiere/After Effects.

19. Jika bentuk cube berubah atau terlihat mencair, pecah 10 detik menjadi 3–6 klip pendek sesuai beat. Gunakan frame akhir klip sebelumnya sebagai continuity reference bila platform mendukung.

20. Shot release/slow-rise sebaiknya menggunakan kamera locked atau sangat stabil; terlalu banyak movement membuat deformasi sulit dibaca dan meningkatkan risiko object morphing.

21. Gunakan satu jenis gerakan tangan per shot. Hindari transformasi tangan kompleks, crossing fingers, atau grip yang terlalu cepat.

22. Foley squeeze dapat direkam terpisah dan di-mix pada tahap editing. Ini lebih dapat dikontrol daripada mengandalkan audio generatif sebagai satu-satunya sumber.

23. Bandingkan frame sebelum squeeze, saat squeeze, dan sesudah recovery terhadap product master: rounded corners, proporsi, warna, translucency, dan ukuran tidak boleh berubah tanpa alasan.

LANGKAH 8

## QC dan Finalisasi

- Bentuk cube konsisten: rounded corners, proporsi, warna, dan tampilan translucent/glossy tidak drift antar-shot.

- Deformasi terlihat elastis dan masuk akal; cube tidak terlihat meleleh, bocor, pecah, atau berubah menjadi material lain.

- Recovery/slow-rise ditampilkan sebagai perilaku visual aktual; jangan memberi angka detik yang tidak diuji.

- Tangan dan jari natural: tidak ada extra fingers, fused fingers, deformasi, atau tangan menembus produk.

- Foley squeeze sinkron dengan momen press, full squeeze, release, dan bounce akhir.

- Copy menggunakan bahasa ringan seperti “pencet”, “remas”, “satisfying”, “break/jeda”; tidak membuat klaim medis seperti menghilangkan anxiety/stres atau terapi klinis.

- Harga, rating, review count, stok, dan varian—jika ditampilkan—diperiksa ulang pada hari publikasi.

- Tidak ada klaim “non-toxic”, “food grade”, “aman untuk semua umur”, sertifikasi, durability, atau material bila belum diverifikasi.

- Overlay dan CTA berada di mobile safe area dan tetap terbaca pada Reels/TikTok/Shorts.

- File final benar-benar 9:16, 1080×1920 atau ekuivalen, dan tidak mengandung storyboard grid/label sebagai bagian video.

PROYEK 04

# Membuat Konten Produk Marketplace — POP SAN Water Slime

Proyek latihan dari screenshot/listing: peserta belajar membedakan fakta visual, klaim listing, asumsi kreatif, lalu mengubahnya menjadi konten foto dan video.

| **HASIL AKHIR**                                                                                         | **URUTAN PRAKTIK**                                                              |
|---------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------|
| Creative brief • product/claim lock • 10 angle • shot list foto • storyboard video 10 detik • JSON • QC | Screenshot → fact/claim → brief → angle → shot list → storyboard → JSON → final |

<img src="media/image5.png" style="width:5.70866in;height:2.91894in" />

LANGKAH 1

## Tentukan Aturan Analisis Listing

- Pisahkan tiga kategori informasi: (1) fakta visual yang terlihat, (2) teks/klaim yang tertulis pada listing, dan (3) asumsi kreatif yang masih harus dikonfirmasi.

- Jangan mengubah harga marketplace menjadi klaim permanen pada materi iklan karena harga, voucher, dan promo dapat berubah.

- Jangan menambahkan klaim keamanan, komposisi, sertifikasi, usia penggunaan, atau manfaat yang tidak tampak/tertulis pada sumber.

- Detail produk yang menjadi identitas visual—warna slime, bentuk cup, label, cube/jelly pieces, tekstur, dan varian—harus diperlakukan sebagai product lock.

- Untuk konten foto/video, susun shot berdasarkan fungsi komunikasi: hero, texture, interaction, variant, benefit visual, dan CTA.

- Jika teks pada kemasan/listing kurang jelas, tandai sebagai 'perlu konfirmasi' daripada menebak.

LANGKAH 2

## Ekstrak Fakta Visual dan Data yang Terlihat

| **Elemen**            | **Temuan dari gambar**                                                        | **Status penggunaan**                                                                     |
|-----------------------|-------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------|
| Nama produk           | POP SAN Water Slime / Water Slime Jelly Cube                                  | Dapat digunakan sebagai identitas produk.                                                 |
| Berat                 | 380 gr                                                                        | Terlihat pada judul listing; verifikasi kembali sebelum final artwork.                    |
| Bentuk kemasan        | Cup transparan bertutup dengan label karakter/varian                          | Product lock visual.                                                                      |
| Karakter produk       | Slime berwarna dengan potongan jelly/cube kecil                               | Dapat menjadi fokus texture/macro shot.                                                   |
| Varian terlihat       | Happy Yellow, Pinky Blue, Pinky Pink, Lovely Purple, Charming Red, Sweet Blue | Gunakan sebagai color/variant story; ejaan perlu dipertahankan sesuai master.             |
| Klaim visual listing  | Wangi, tahan lama, bubble, tidak lengket                                      | Boleh dipakai hanya sebagai klaim listing; verifikasi pemilik produk sebelum iklan final. |
| Harga saat screenshot | Rp17.900                                                                      | Informasi dinamis; jangan hard-code ke evergreen creative tanpa approval.                 |
| Positioning visual    | Ceria, playful, colorful, kawaii/character-led                                | Arah kreatif yang aman untuk dikembangkan.                                                |

LANGKAH 3

## Gunakan Prompt untuk Membuat Creative Brief

CONTOH / TEMPLATE

BERTINDAK SEBAGAI ANALIS PRODUK DAN CREATIVE STRATEGIST PROFESIONAL.

SOURCE
Gunakan screenshot/listing produk yang diunggah sebagai sumber utama. Jangan mengarang spesifikasi yang tidak terlihat atau tidak tertulis.

TUGAS
Buat creative brief lengkap untuk produksi foto dan video promo produk.

WAJIB DIPISAHKAN
1. FAKTA VISUAL — hanya yang benar-benar terlihat.
2. KLAIM LISTING — teks/claim yang tertulis pada gambar.
3. ASUMSI KREATIF — ide positioning/visual yang masih perlu approval.
4. PERLU KONFIRMASI — hal yang tidak dapat dipastikan dari gambar.

ANALISIS
- nama dan kategori produk
- bentuk kemasan dan silhouette
- warna dan varian
- material/tekstur yang terlihat
- detail produk yang dapat dijadikan visual hook
- target audiens visual
- consumer insight
- key message
- USP/benefit yang aman digunakan
- tone & visual direction

CREATIVE PRODUCTION
- 8–10 konsep foto
- hero shot, macro texture, interaction, variant lineup, lifestyle/tabletop
- background dan lighting
- 10–15 detik video structure
- shot list + camera movement
- hook, VO/copy, CTA
- deliverables 9:16, 1:1, 4:5, dan 16:9 bila diperlukan

PRODUCT LOCK
Pertahankan bentuk cup, warna slime, label/branding, ukuran relatif, jelly cube, dan identitas tiap varian. Jangan mengubah logo/label menjadi bentuk baru.

NEGATIVE / QC
No product deformation, no label mutation, no wrong color variant, no fake certification, no unverified safety claim, no random text, no extra product parts, no misleading scale.

OUTPUT
Susun dalam format creative brief yang siap dipakai fotografer, graphic designer, dan motion designer.

LANGKAH 4

## Review Creative Brief Hasil Analisis

Tujuan komunikasi: Membangun ketertarikan terhadap pengalaman bermain yang colorful, satisfying, dan playful dengan menonjolkan tekstur water slime, jelly cube, pilihan warna, serta visual interaction.

Target audiens visual: Anak dan keluarga sebagai pengguna/pendamping, pembeli hadiah kecil, serta pengguna social media yang tertarik pada konten satisfying/ASMR. Penargetan akhir wajib disesuaikan dengan kebijakan platform dan arahan pemilik produk.

Consumer insight: Produk slime lebih menarik ketika calon pembeli dapat 'merasakan' teksturnya secara visual: ditarik, ditekan, dibentuk bubble, dan memperlihatkan cube yang bergerak di dalam slime.

Single-minded message: Main slime jadi lebih seru dengan warna ceria, tekstur water slime, dan jelly cube yang satisfying.

Tone: Ceria, playful, kawaii, energetic, bersih, modern, candy-colored, tidak terlalu ramai.

Visual world: Pastel candy background, glossy translucent slime, soft studio reflection, macro texture, clean tabletop, playful character accents.

LANGKAH 5

## Kunci Produk dan Klaim

| **LOCK**     | **Instruksi**                                                                                                                                    |
|--------------|--------------------------------------------------------------------------------------------------------------------------------------------------|
| Kemasan      | Cup transparan, bentuk tutup, proporsi dan volume visual tidak boleh berubah antar-shot.                                                         |
| Warna varian | Happy Yellow / Pinky Blue / Pinky Pink / Lovely Purple / Charming Red / Sweet Blue harus konsisten dengan referensi.                             |
| Isi          | Water slime dengan jelly cube; jangan berubah menjadi clay slime, foam slime, makanan, minuman, atau gel kosmetik.                               |
| Brand/label  | Label pada cup dianggap aset presisi; AI hanya placeholder bila teks/logo tidak terbaca sempurna, lalu diganti dengan aset asli saat finalisasi. |
| Klaim        | Wangi, tahan lama, bubble, tidak lengket hanya boleh digunakan jika disetujui pemilik produk dan sesuai kondisi produk aktual.                   |
| Harga/promo  | Harga Rp17.900 dan voucher pada screenshot bersifat dinamis; gunakan hanya untuk materi kampanye yang telah diverifikasi pada tanggal publikasi. |

LANGKAH 6

## Buat Creative Angle

- Satisfying Texture — Macro stretch, poke, press, jelly cube movement.

- Choose Your Color — Variant lineup / carousel berdasarkan enam warna.

- What’s Inside the Cup? — Reveal texture dan cube setelah tutup dibuka.

- Bubble Challenge — Konten eksperimen bubble jika produk aktual mendukung.

- ASMR Play — Suara lembut poke, stretch, squish; visual clean dan close-up.

- Color Match — Pasangkan warna slime dengan props/background yang senada.

- Before / After Play — Cup tertutup → texture reveal → kembali ke hero packshot.

- Mini Gift Idea — Positioning sebagai small playful gift tanpa membuat klaim usia yang belum diverifikasi.

- Desk / Playtable Moment — Lifestyle tabletop yang rapi dan aman, dengan adult-supervised context bila diperlukan.

- Fast Variant Montage — Enam warna berpindah cepat untuk hook 2–3 detik pertama.

LANGKAH 7

## Susun Shot List Foto

- 1\. Hero Lineup — Enam cup tersusun seperti key visual, angle 3/4 front, background pastel gradient, fokus pada variasi warna.

- 2\. Single Hero — Satu varian pada pedestal kecil, label menghadap kamera, soft rim light, clean negative space untuk copy.

- 3\. Macro Cube — Close-up jelly cube di dalam slime, shallow depth of field, detail translucency.

- 4\. Stretch Texture — Slime ditarik perlahan membentuk ribbon transparan; hindari tangan cacat atau scale yang menyesatkan.

- 5\. Poke / Press — Top-down interaction untuk menonjolkan tekstur dan respons slime.

- 6\. Bubble Moment — Bubble dome dari slime sebagai satisfying visual; hanya jika karakteristik aktual produk mendukung.

- 7\. Color Pairing — Dua varian dengan warna kontras untuk carousel comparison.

- 8\. Cup + Spill — Cup di samping slime yang keluar secara terkontrol; bentuk isi tetap realistis dan tidak berubah material.

- 9\. Variant Grid — Flat lay 2×3 untuk katalog/social post.

- 10\. Packaging Detail — Label, tutup, dan isi ditampilkan jelas untuk kebutuhan e-commerce/retargeting.

LANGKAH 8

## Susun Storyboard Video 10 Detik

| **Time**  | **Shot**      | **Camera**               | **Action**                                                          | **Message**                 |
|-----------|---------------|--------------------------|---------------------------------------------------------------------|-----------------------------|
| 0.0–2.0s  | Hero lineup   | Quick push-in            | Enam varian tampil sebagai colorful lineup; satu cup maju ke depan. | “Pilih warna favoritmu!”    |
| 2.0–4.5s  | Macro texture | Macro dolly + rack focus | Slime ditarik; jelly cube bergerak di dalam tekstur transparan.     | Texture / satisfying        |
| 4.5–7.0s  | Interaction   | Top-down + short orbit   | Poke, press, atau bubble visual yang natural.                       | “Mainnya makin seru”        |
| 7.0–10.0s | Hero closing  | Smooth pull-back         | Tiga–enam varian kembali tampil; sisakan safe area untuk logo/CTA.  | “POP SAN Water Slime” + CTA |

LANGKAH 9

## Buat JSON Video

CONTOH / TEMPLATE

{
"title": "POP SAN Water Slime - Colorful Satisfying Promo",
"duration_seconds": 10,
"aspect_ratio": "9:16",
"style": "premium colorful toy commercial, pastel candy palette, clean studio, glossy macro texture, playful and family-friendly",
"product_lock": {
"priority": "MAXIMUM",
"instruction": "Use the uploaded POP SAN product image as the product master. Preserve cup shape, lid, label placement, slime color, jelly cube appearance and relative scale.",
"variants": ["Happy Yellow", "Pinky Blue", "Pinky Pink", "Lovely Purple", "Charming Red", "Sweet Blue"]
},
"timeline": [
{
"time": "0.0-2.0s",
"shot": "hero lineup",
"camera": "quick smooth push-in",
"action": "Six colorful POP SAN cups appear in a clean pastel studio; one cup subtly slides forward."
},
{
"time": "2.0-4.5s",
"shot": "macro texture",
"camera": "macro dolly + rack focus",
"action": "Show translucent water slime stretching slowly while jelly cubes move naturally inside."
},
{
"time": "4.5-7.0s",
"shot": "top-down interaction",
"camera": "controlled top-down orbit",
"action": "Show satisfying poke/press movement and a small bubble only if physically plausible for the product."
},
{
"time": "7.0-10.0s",
"shot": "hero closing",
"camera": "smooth pull-back",
"action": "Return to a colorful product lineup with clean negative space for final logo and CTA."
}
],
"on_screen_copy": [
"Water Slime + Jelly Cube",
"Pilih warna favoritmu!"
],
"negative_prompt": [
"product deformation",
"wrong cup shape",
"label mutation",
"wrong variant color",
"slime turning into food or drink",
"extra product parts",
"deformed hands",
"unverified safety claims",
"random text",
"watermark",
"camera jitter",
"flicker"
]
}

LANGKAH 10

## Siapkan Hook, Copy, dan CTA

- Hook: “Yang satisfying bukan cuma warnanya…”

- Hook: “Pilih warna slime yang paling kamu banget!”

- Hook: “Water slime + jelly cube = combo main yang bikin penasaran.”

- Copy pendek: “Stretch. Poke. Squish. Repeat.”

- CTA: “Pilih varian favoritmu.”

- CTA marketplace: “Cek varian dan promo terbaru di toko.”

LANGKAH 11

## QC dan Finalisasi

- Bentuk cup, tutup, label, dan warna varian tidak berubah antar-frame.

- Slime tetap terbaca sebagai slime, bukan minuman, makanan, kosmetik, atau benda cair berbahaya.

- Jelly cube tidak berubah menjadi candy/edible cube secara visual.

- Tidak ada klaim keamanan, non-toxic, edible, hypoallergenic, atau sertifikasi jika tidak ada sumber yang mendukung.

- Klaim “wangi”, “tahan lama”, “bubble”, dan “tidak lengket” sudah mendapat approval produk sebelum masuk final copy.

- Harga dan voucher diperiksa ulang pada hari publikasi.

- Jika ada tangan, anatomi jari natural dan interaksi tidak menutupi label utama.

- Teks kritikal, logo, harga, dan CTA ditempel ulang dengan aset desain asli pada final artwork.

- Format final memiliki safe area yang benar untuk 9:16, 4:5, 1:1, atau 16:9.

- Prompt, reference image, dan hasil approved diarsipkan dengan versioning.

PROYEK 05

# Membuat Iklan Produk 10 Detik Tanpa Model

Workflow ringkas untuk helm, gadget, aksesoris, atau produk yang ingin ditampilkan tanpa manusia di visual.

| **HASIL AKHIR**                                                                      | **URUTAN PRAKTIK**                                                                 |
|--------------------------------------------------------------------------------------|------------------------------------------------------------------------------------|
| Storyboard 10 detik • hero/detail/motion/CTA • JSON video • voice-over opsional • QC | Foto produk → product lock → script 4 beat → storyboard/keyframe → video → VO → QC |

LANGKAH 1

## Tetapkan Product Lock dari Foto

- Bentuk/silhouette produk

- Warna utama dan aksen

- Logo/marking yang terlihat

- Material/tekstur visual yang tampak

- Detail fisik yang tidak boleh berubah

- Area untuk CTA/brand pada hero closing

LANGKAH 2

## Susun Struktur 10 Detik

CONTOH / TEMPLATE

Buat storyboard dan video iklan produk berdurasi 10 detik tanpa menampilkan model/manusia.

REFERENCE
Gunakan gambar produk sebagai product master. Pertahankan bentuk, warna, material, logo, ventilasi, jahitan, tekstur, atau detail fisik lain yang terlihat.

STRUKTUR 10 DETIK
0–2.5s — Hero reveal: produk muncul dengan dramatic push-in.
2.5–5.0s — Detail: macro/close-up material dan fitur visual.
5.0–7.5s — Dynamic product motion: orbit atau turntable halus.
7.5–10.0s — Hero closing: produk berhenti pada angle terbaik, sisakan ruang untuk logo dan CTA.

VISUAL
Premium commercial product photography, controlled studio lighting, clean reflections, high contrast separation, realistic material response.

AUDIO
Jika menggunakan voice-over anak laki-laki, gunakan suara ceria, jelas, singkat, dan sesuai naskah iklan; suara hanya sebagai pengisi iklan, tanpa menghadirkan anak di visual.

NEGATIVE
No human model, no hands, no product deformation, no logo mutation, no material flicker, no floating parts, no random text, no camera shake.

LANGKAH 3

## Buat Storyboard 4 Beat

PROMPT SIAP COPY

Buat storyboard iklan produk tanpa model berdurasi 10 detik, rasio 9:16.
0–2.5s: HERO REVEAL — dramatic push-in.
2.5–5.0s: DETAIL — macro material/fitur visual yang benar-benar terlihat.
5.0–7.5s: PRODUCT MOTION — orbit/turntable halus dengan bentuk produk tetap stabil.
7.5–10.0s: HERO CLOSING — angle terbaik, negative space untuk logo/CTA.
Gunakan product reference sebagai master. Jangan tampilkan manusia/tangan. No product deformation, logo mutation, floating parts, random text, camera shake.

LANGKAH 4

## Generate Video dan Tambahkan Voice-Over Bila Diperlukan

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th><p><strong>CATATAN VO</strong></p>
<p>Voice-over boleh menggunakan karakter suara yang sesuai konsep iklan, tetapi visual tetap tanpa model. Tulis VO singkat dan jangan mengandalkan TTS untuk membaca singkatan/angka yang berpotensi salah.</p></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

LANGKAH 5

## QC

- Produk tidak berubah bentuk antar-shot.

- Logo/marking tidak bermutasi.

- Lighting konsisten.

- Tidak ada tangan/manusia jika brief melarang model.

- Teks akhir difinalisasi di editor.

PROYEK 06

# Membuat Flyer Event dan Turunannya ke Header Google Form

Workflow end-to-end untuk materi acara: key visual → flyer vertikal → compositing data → header horizontal.

| **HASIL AKHIR**                                                              | **URUTAN PRAKTIK**                                                                   |
|------------------------------------------------------------------------------|--------------------------------------------------------------------------------------|
| Key visual • flyer 9:16/4:5 • final data event • header Google Form 1600×400 | Brief acara → aset brand → key visual → flyer → verifikasi data → resize/header → QC |

<img src="media/image6.png" style="width:5.70866in;height:8.56299in" />

LANGKAH 1

## Kumpulkan Brief dan Aset Resmi

- Judul acara

- Tema/tagline

- Tanggal dan lokasi

- Biaya/pendaftaran

- Kontak

- Logo resmi

- Foto/karakter referensi

- Rasio output

LANGKAH 2

## Generate Key Visual dengan Negative Space

PROMPT SIAP COPY

Buat key visual flyer social media 9:16 untuk acara keluarga.
FORMASI: ayah sekitar 30 tahun, ibu sekitar 25 tahun memakai jilbab putih, dua anak sekitar 8 tahun.
WARDROBE: kaos merah, celana putih.
AKTIVITAS: lomba balap karung, suasana 17 Agustus yang ceria dan aman.
VISUAL: siang cerah, dekorasi merah-putih, low/front camera angle, ekspresi gembira, energetic motion, negative space untuk judul dan informasi acara.
NEGATIVE: no extra limbs, no duplicated family members, no malformed hands, no wrong clothing colors, no random text.

LANGKAH 3

## Tempel Ulang Data Event dengan Aset Presisi

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th><p><strong>WAJIB MANUAL</strong></p>
<p>Tanggal, harga, kontak, QR, logo, dan teks panjang harus diperiksa lalu ditempel ulang di editor. AI digunakan untuk visual; manusia bertanggung jawab atas kebenaran informasi.</p></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

LANGKAH 4

## Adaptasi Flyer menjadi Header Google Form 1600×400

Buat header image untuk Google Form berdasarkan flyer/event reference yang diunggah.

REFERENCE LOCK
Pertahankan identitas warna, ilustrasi utama, motif, dan suasana visual kampanye. Jangan menyalin semua informasi flyer ke header.

COMPOSITION
Ukuran 1600 × 400 piksel. Fokus pada judul singkat + hero visual. Gunakan safe area tengah agar tidak terpotong pada berbagai ukuran layar. Background lebih sederhana daripada flyer agar tetap terbaca pada bidang horizontal sempit.

TEXT
Gunakan hanya teks yang benar-benar dibutuhkan sebagai identitas acara. Data detail tetap berada pada Google Form, bukan di header.

QC
No stretched character, no cropped face, no distorted logo, no tiny unreadable text, no clutter.

LANGKAH 5

## QC Multi-format

- Wajah/hero tidak terpotong.

- Judul tetap terbaca pada bidang horizontal sempit.

- Logo tidak terdistorsi.

- Tidak memindahkan semua informasi flyer ke header.

- Safe area tengah aman pada desktop/mobile.

PROYEK 07

# Membuat Video Edukasi Sains Anak — “Mimi dan Rahasia Pelangi”

Workflow 30 detik: ide sains sederhana → script → character sheet → storyboard → video 3 scene.

| **HASIL AKHIR**                                                                 | **URUTAN PRAKTIK**                                                      |
|---------------------------------------------------------------------------------|-------------------------------------------------------------------------|
| Script 30 detik • 3 character sheet • storyboard 12 panel • JSON Scene 1–3 • QC | Konsep sains → script → character lock → storyboard → JSON → video → QC |

<img src="media/image7.png" style="width:5.70866in;height:3.21283in" />

LANGKAH 1

## Tentukan Satu Konsep Sains dan Struktur 3 Scene

Untuk animasi edukasi anak, gunakan satu konsep sains per episode pendek. Struktur 30 detik yang paling mudah dibaca adalah pertanyaan → penemuan → jawaban visual.

- Scene 1 (0–10 detik): rasa ingin tahu / pertanyaan terhadap fenomena alam.

- Scene 2 (10–20 detik): karakter atau kejadian menjelaskan satu konsep inti.

- Scene 3 (20–30 detik): konsep divisualisasikan lalu ditutup dengan kesimpulan positif.

- Gunakan kalimat pendek, ekspresi besar, warna cerah, dan gerakan yang jelas untuk anak usia 5–8 tahun.

LANGKAH 2

## Tulis Script 30 Detik

SCENE 1 — PELANGI MUNCUL
Taman hijau setelah hujan. Mimi si kelinci dan Axel si rubah melihat pelangi.
Mimi: “Waaah, Axel! Lihat, ada pelangi cantik!”
Mimi: “Siapa ya yang mewarnai langit?”
Axel: “Ayo kita cari tahu!”

SCENE 2 — BERTEMU TETES
Mimi dan Axel mendekati genangan air. Tetes, tetesan air lucu, muncul.
Tetes: “Halo! Pelangi muncul saat sinar matahari bertemu tetesan air seperti aku!”
Axel: “Jadi air dan matahari bekerja bersama?”
Tetes: “Betul sekali!”

SCENE 3 — RAHASIA PELANGI
Cahaya matahari melewati Tetes dan terurai menjadi warna pelangi.
Narator: “Saat cahaya matahari melewati tetesan air, muncullah warna-warna indah pelangi.”
Mimi: “Asyik! Sekarang aku tahu rahasia pelangi!”
Narator: “Belajar alam itu seru!”

LANGKAH 3

## Buat Character Sheet

Buat character sheet detail karakter anak/mascot untuk serial animasi.

OUTPUT
9 angle: front, 3/4 front left, left profile, 3/4 back left, back, 3/4 back right, right profile, 3/4 front right, elevated/front view.

CHARACTER LOCK
Pertahankan spesies, bentuk kepala, mata, telinga/muzzle, warna tubuh/fur, proporsi, outfit, aksesori, dan material.

EXPRESSIONS
Happy, curious, surprised, laughing, thinking, worried, excited, proud.

PROPERTIES
Tampilkan 4–6 properti yang mendukung cerita dan aktivitas karakter.

STYLE
Premium 3D animated feature-film style, soft cinematic studio light, professional reference-sheet layout, child-friendly, ratio 16:9.

NEGATIVE
No character drift, no outfit changes, no extra limbs, no inconsistent eye color, no random text, no watermark.

Contoh output: character sheet Mimi — 9 angle, properti, ekspresi, dan color palette.

Contoh output: character sheet Axel — identitas rubah, outfit explorer, properti, dan ekspresi.

Contoh output: character sheet Tetes — material transparan, ekspresi, properti, dan variasi sudut.

<img src="media/image8.png" style="width:5.90551in;height:3.32362in" />

Character sheet Mimi.

<img src="media/image9.png" style="width:5.90551in;height:3.32362in" />

Character sheet Axel.

<img src="media/image10.png" style="width:5.90551in;height:3.32362in" />

Character sheet Tetes.

LANGKAH 4

## Buat Storyboard 3 Scene × 4 Panel

Buat storyboard “Mimi dan Rahasia Pelangi” dari character reference yang diunggah.

REFERENCE
Image 1 = Mimi; Image 2 = Axel; Image 3 = Tetes. Gunakan ketiganya sebagai identity master.

FORMAT
30 detik, 3 scene × 10 detik, tiap scene 4 panel, rasio 16:9, premium 3D animated feature-film style, bright, soft, expressive.

SCENE 1 — PELANGI MUNCUL
P1 wide establishing shot; P2 medium two-shot Mimi menunjuk pelangi; P3 close-up Axel berkata “Ayo kita cari tahu!”; P4 tracking shot mereka berlari.

SCENE 2 — BERTEMU TETES
P1 wide shot di genangan; P2 medium shot Tetes muncul dan menjelaskan; P3 three-character shot Axel bertanya; P4 close-up Tetes menjawab.

SCENE 3 — RAHASIA PELANGI
P1 close-up cahaya melewati Tetes dan terurai; P2 wide shot pelangi penuh; P3 medium shot tiga karakter merayakan penemuan; P4 hero wide shot + penutup “Belajar alam itu seru!”.

QC
Character lock maksimum, urutan warna pelangi benar, tidak ada extra limbs, tidak ada karakter duplikat, ekspresi jelas, continuity lingkungan konsisten.

Contoh output: storyboard 30 detik — 3 scene × 4 panel dengan variasi framing dan continuity.

<img src="media/image7.png" style="width:5.90551in;height:3.32362in" />

Contoh storyboard “Mimi dan Rahasia Pelangi”.

LANGKAH 5

## Buat JSON Video Scene 1–3

{
"title": "Scene 1 - Pelangi Muncul",
"duration_seconds": 10,
"aspect_ratio": "16:9",
"timeline": [
{"time":"0.0-2.5s","shot":"wide establishing","camera":"slow push-in from behind","action":"Mimi dan Axel melihat pelangi setelah hujan."},
{"time":"2.5-5.5s","shot":"medium two-shot","camera":"front 3/4","action":"Mimi menunjuk pelangi.","dialogue":"Waaah, Axel! Lihat, ada pelangi cantik! Siapa ya yang mewarnai langit?"},
{"time":"5.5-7.5s","shot":"medium close-up Axel","camera":"gentle push-in","dialogue":"Ayo kita cari tahu!"},
{"time":"7.5-10.0s","shot":"tracking wide","camera":"low side tracking","action":"Mimi dan Axel berlari melalui genangan kecil."}
],
"negative_prompt":["no Tetes in scene 1","no face drift","no outfit changes","no duplicate characters","no rainbow flicker","no camera shake"]
}

{
"title": "Scene 2 - Bertemu Tetes",
"duration_seconds": 10,
"aspect_ratio": "16:9",
"timeline": [
{"time":"0.0-2.5s","shot":"wide","camera":"slow dolly-in","action":"Mimi dan Axel mendekati genangan; Tetes muncul dengan ripple kecil."},
{"time":"2.5-5.5s","shot":"medium Tetes","camera":"gentle push-in","dialogue":"Halo! Pelangi muncul saat sinar matahari bertemu tetesan air seperti aku!"},
{"time":"5.5-8.0s","shot":"three-character medium","camera":"smooth arc","dialogue":"Axel: Jadi air dan matahari bekerja bersama?"},
{"time":"8.0-10.0s","shot":"close-up Tetes","camera":"small push-in","dialogue":"Betul sekali!","action":"muncul refleksi warna kecil di permukaan air."}
],
"material_note":"Tetes translucent light-blue, soft internal refraction, subtle water jiggle, stable droplet silhouette.",
"negative_prompt":["no melting Tetes","no opaque Tetes","no full rainbow yet","no character flicker","no extra limbs"]
}

{
"title": "Scene 3 - Rahasia Pelangi",
"duration_seconds": 10,
"aspect_ratio": "16:9",
"timeline": [
{"time":"0.0-2.5s","shot":"close-up Tetes","camera":"slow push-in","action":"Sinar matahari melewati tubuh Tetes dan terurai menjadi spektrum warna.","narration":"Saat cahaya matahari melewati tetesan air, muncullah warna-warna indah pelangi."},
{"time":"2.5-5.0s","shot":"wide","camera":"pull-back + tilt up","action":"Spektrum berkembang menjadi pelangi penuh di langit."},
{"time":"5.0-7.5s","shot":"medium three-character","camera":"gentle arc","dialogue":"Mimi: Asyik! Sekarang aku tahu rahasia pelangi!"},
{"time":"7.5-10.0s","shot":"hero wide","camera":"slow crane-back","action":"Mimi, Axel, Tetes merayakan di bawah pelangi.","narration":"Belajar alam itu seru!"}
],
"science_lock":"Urutan warna pelangi harus konsisten dan mudah dipahami secara visual.",
"negative_prompt":["no incorrect rainbow order","no duplicate rainbow","no character drift","no text overlay","no watermark"]
}

LANGKAH 6

## QC

- Mimi, Axel, Tetes identik dengan character sheet.

- Urutan warna pelangi konsisten.

- Dialog pendek dan sesuai durasi.

- Tidak ada duplicate character/extra limbs.

- Scene 1 → 2 → 3 memiliki continuity lokasi dan emosi.

PROYEK 08

# Membuat Video Edukasi Keselamatan — Gempa Bumi Claymation

Workflow edukasi keselamatan harus memprioritaskan urutan tindakan yang benar, baru kemudian gaya visual.

| **HASIL AKHIR**                                              | **URUTAN PRAKTIK**                                   |
|--------------------------------------------------------------|------------------------------------------------------|
| Script 30 detik • storyboard 9:16 • JSON 3 scene • safety QC | Pesan keselamatan → script → storyboard → video → QC |

LANGKAH 1

## Tetapkan Prinsip Edukasi dan Visual

- Satu video pendek sebaiknya hanya mengajarkan satu prosedur inti. Untuk gempa bumi, pesan utama adalah tetap tenang, lakukan Drop–Cover–Hold On saat guncangan, lalu evakuasi secara tertib setelah guncangan berhenti.

- Gunakan visual claymation yang ramah anak: bentuk karakter sederhana, ekspresi jelas, tekstur plastisin terlihat, gerakan stop-motion sedikit bertahap, dan warna hangat tanpa atmosfer horor.

- Efek gempa sebaiknya terutama berasal dari gerakan benda dan lingkungan—lampu bergoyang, air bergetar, buku bergeser—bukan camera shake berlebihan.

- Urutan tindakan keselamatan harus terlihat jelas dan benar secara visual. Jangan menampilkan karakter berlari keluar ketika guncangan masih berlangsung.

- Teks di layar harus singkat. Narasi atau voice-over menjelaskan tindakan dengan kalimat pendek dan mudah dipahami.

LANGKAH 2

## Tulis Script 3 Scene

CONTOH / TEMPLATE

FORMAT
Durasi total 30 detik; 3 scene × 10 detik; rasio 9:16; gaya handcrafted claymation stop-motion; target edukasi keluarga/anak.

SCENE 1 — GEMPA TERJADI (0–10 detik)
Visual: Ibu membaca buku di sofa, anak bermain di lantai. Lampu gantung mulai bergoyang, air di gelas bergetar, benda kecil bergerak. Anak panik dan hendak berlari; ibu memberi gestur berhenti dan menenangkan.
Narasi: “Kalau gempa terjadi, jangan panik dan jangan langsung berlari!”
Teks layar: “GEMPA! Tetap Tenang.”

SCENE 2 — DROP, COVER, HOLD ON (10–20 detik)
Visual: Ibu dan anak merunduk, bergerak ke bawah meja yang kokoh, melindungi kepala dan leher, lalu memegang kaki meja.
Narasi: “Segera lakukan: merunduk, berlindung, dan berpegangan!”
Teks layar: “1. MERUNDUK” → “2. BERLINDUNG” → “3. BERPEGANGAN”.

SCENE 3 — SETELAH GEMPA BERHENTI (20–30 detik)
Visual: Guncangan berhenti. Ibu mengecek situasi, lalu membimbing anak keluar dengan tertib menuju area terbuka. Mereka berdiri jauh dari bangunan, tiang listrik, dan pohon besar.
Narasi: “Setelah gempa berhenti, keluar dengan tertib menuju tempat terbuka dan tetap waspada terhadap gempa susulan.”
Teks layar: “Tetap tenang. Lindungi diri. Menuju tempat aman.”
Ending: Anak memberi jempol; visual ditahan singkat sebagai frame penutup.

LANGKAH 3

## Buat Storyboard 9:16

CONTOH / TEMPLATE

Buat storyboard produksi untuk video edukasi gempa bumi berdurasi 30 detik dengan gaya handcrafted claymation stop-motion.

FORMAT
- Rasio 9:16 portrait.
- 3 scene × 10 detik.
- 2 shot utama per scene (total 6 shot) agar mudah diproduksi.
- Tampilkan timecode, jenis shot, catatan produksi, narasi, dan teks layar.

CHARACTER LOCK
Ibu: karakter clay yang sama di seluruh panel, hijab mauve-ungu, atasan peach lengan panjang, rok beige, ekspresi protektif dan tenang.
Anak: anak laki-laki clay yang sama, rambut hitam sedikit berantakan, kaos kuning, celana pendek biru, ekspresi besar dan mudah dibaca.
Jangan mengubah wajah, warna pakaian, proporsi, atau style karakter antar-panel.

SCENE 1 — GEMPA TERJADI
Shot 1 (0–5s): wide establishing ruang keluarga. Anak bermain, ibu membaca. Lampu, air di gelas, dan benda kecil mulai bergetar.
Shot 2 (5–10s): medium shot. Anak panik dan hendak berlari; ibu mengangkat telapak tangan untuk menenangkan dan menunjuk menjauh dari lemari. Teks: “GEMPA! Tetap Tenang.”
Narasi: “Kalau gempa terjadi, jangan panik dan jangan langsung berlari!”

SCENE 2 — DROP, COVER, HOLD ON
Shot 3 (10–15s): medium shot. Ibu dan anak merunduk dan melindungi kepala/leher. Teks: “1. MERUNDUK”.
Shot 4 (15–20s): low angle di bawah meja. Mereka berlindung di bawah meja kokoh dan memegang kaki meja. Teks: “2. BERLINDUNG” dan “3. BERPEGANGAN”.
Narasi: “Segera lakukan: merunduk, berlindung, dan berpegangan!”

SCENE 3 — SETELAH GEMPA BERHENTI
Shot 5 (20–25s): medium shot. Guncangan telah berhenti; ibu mengecek sekitar lalu membimbing anak ke pintu.
Shot 6 (25–30s): wide outdoor hero shot. Ibu dan anak berada di area terbuka; anak memberi jempol. Tambahkan checklist: “Jauhi bangunan”, “Jauhi tiang listrik”, “Jauhi pohon besar”.
Narasi: “Setelah gempa berhenti, keluar dengan tertib menuju tempat terbuka dan tetap waspada terhadap gempa susulan.”

STYLE
Warm handcrafted miniature clay set, visible plasticine texture, subtle fingerprints, soft cinematic lighting, child-friendly, educational, clear silhouettes, authentic stop-motion feel.

NEGATIVE
No photorealistic humans, no 2D cartoon, no character drift, no wardrobe changes, no extra limbs, no severe destruction, no injuries, no fire, no horror mood, no excessive camera shake, no unreadable text.

Contoh output storyboard produksi:

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th><p><strong>CATATAN PRAKTIK</strong></p>
<p>QC cepat — Pastikan aksi keselamatan terbaca benar, urutan scene logis, karakter tidak berubah, dan efek gempa berasal dari lingkungan tanpa membuat visual terlalu menakutkan.</p></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

<img src="media/image11.png" style="width:3.54331in;height:6.29587in" />

Contoh storyboard edukasi gempa bumi claymation.

LANGKAH 4

## Buat JSON Scene 1

CONTOH / TEMPLATE

{
"scene": 1,
"title": "Gempa Terjadi",
"duration": "10 seconds",
"aspect_ratio": "9:16",
"reference_image": "Use the attached storyboard as the primary visual reference. Preserve the exact claymation characters, clothing, room layout, props, colors, textures and lighting.",
"visual_style": {
"style": "high-quality cinematic claymation stop-motion",
"materials": "handmade plasticine clay, visible clay texture, subtle fingerprints, miniature set",
"lighting": "warm soft indoor lighting",
"mood": "educational, slightly tense, safe and reassuring"
},
"timeline": [
{"time":"0-2s","shot":"wide establishing","camera":"subtle push-in","action":"Child plays on the floor while mother reads on the sofa; room is peaceful."},
{"time":"2-5s","shot":"wide to medium-wide","camera":"slow controlled push-in","action":"Lamp swings, water ripples in the glass, wall picture tilts slightly, books and props tremble; child pauses and mother notices the earthquake."},
{"time":"5-7.5s","shot":"medium","camera":"smooth cut closer","action":"Child looks frightened and starts to move as if he wants to run; shaking becomes slightly stronger."},
{"time":"7.5-10s","shot":"medium two-shot","camera":"stable","action":"Mother raises one open palm to stop and calm the child, then points away from the tall shelf; child stops and listens.","on_screen_text":"GEMPA! TETAP TENANG."}
],
"voice_over": {"language":"Indonesian","script":"Kalau gempa terjadi, jangan panik dan jangan langsung berlari!"},
"sound_design": ["soft room ambience","subtle low earthquake rumble","gentle furniture rattling","glass vibration","small object rattles"],
"negative_prompt": ["photorealistic humans","2D cartoon","character redesign","extra characters","severe destruction","injuries","fire","horror atmosphere","excessive camera shake","warped faces","deformed hands","unreadable text"],
"ending_frame": "Mother stands protectively beside the child while the room still gently shakes, ready to transition into Drop, Cover, Hold On."
}

LANGKAH 5

## Buat JSON Scene 2

CONTOH / TEMPLATE

{
"scene": 2,
"title": "Drop, Cover, Hold On",
"duration": "10 seconds",
"aspect_ratio": "9:16",
"reference_image": "Use the attached storyboard as visual master. Maintain the exact mother, child, furniture, clothing and handcrafted clay style from Scene 1.",
"timeline": [
{"time":"0-2.5s","shot":"medium","camera":"stable subtle push-in","action":"Mother guides child downward beside the sturdy table. Both crouch and protect head and neck.","on_screen_text":"1. MERUNDUK"},
{"time":"2.5-5s","shot":"medium-low angle","camera":"slightly lower angle","action":"Mother gestures under the sturdy table; both crawl underneath while staying low.","on_screen_text":"2. BERLINDUNG"},
{"time":"5-7.5s","shot":"low-angle under table","camera":"table-level","action":"Both are fully under the table. Mother reaches for one table leg; child stays low with head protected."},
{"time":"7.5-10s","shot":"low-angle two-shot","camera":"locked","action":"Mother and child each hold a table leg and remain protected while the room gently vibrates.","on_screen_text":"3. BERPEGANGAN"}
],
"voice_over": {"language":"Indonesian","script":"Segera lakukan: merunduk, berlindung, dan berpegangan!"},
"camera_direction": ["lower the camera as the characters move toward the floor","use low angle beneath the table","avoid excessive camera shake"],
"negative_prompt": ["standing during main shaking","running outside during active shaking","unsafe hiding position","character drift","extra limbs","severe destruction","horror mood","frame flicker","unreadable text"],
"ending_frame": "Mother and child remain safely beneath the sturdy table, holding the table legs with heads protected."
}

LANGKAH 6

## Buat JSON Scene 3

CONTOH / TEMPLATE

{
"scene": 3,
"title": "Setelah Gempa Berhenti",
"duration": "10 seconds",
"aspect_ratio": "9:16",
"reference_image": "Use the attached storyboard as visual master. Preserve the same characters, clothing, room design and claymation style from previous scenes.",
"timeline": [
{"time":"0-2.5s","shot":"medium indoor","camera":"stable slight push-in","action":"The shaking has stopped. Mother and child carefully come out from under the table and check the room."},
{"time":"2.5-5s","shot":"medium toward doorway","camera":"gentle pan/reframe","action":"Mother calmly guides the child toward the open door in an orderly manner.","on_screen_text":"Setelah gempa berhenti..."},
{"time":"5-7.5s","shot":"outdoor wide-medium","camera":"smooth cut to exterior","action":"They arrive in a safe open area away from buildings, utility poles and large trees."},
{"time":"7.5-10s","shot":"wide hero shot","camera":"stable","action":"Mother stands beside child; child smiles and gives thumbs up. Show safety checklist.","on_screen_text":"Tetap tenang. Lindungi diri. Menuju tempat aman."}
],
"checklist_sign": ["Jauhi bangunan","Jauhi tiang listrik","Jauhi pohon besar"],
"voice_over": {"language":"Indonesian","script":"Setelah gempa berhenti, keluar dengan tertib menuju tempat terbuka dan tetap waspada terhadap gempa susulan."},
"sound_design": ["earthquake rumble fades out","soft indoor ambience","gentle footsteps","light outdoor breeze","calm birds"],
"negative_prompt": ["leaving before shaking stops","unsafe position near buildings","severe destruction","injuries","panic running","dark scary ending","character drift","extra limbs","unreadable text"],
"ending_frame": "Bright open safe area; mother stands calmly beside smiling child giving a thumbs up, with readable safety checklist."
}

LANGKAH 7

## QC Keselamatan dan Visual

- Pesan tindakan keselamatan benar dan tidak kontradiktif antar-scene.

- Karakter, pakaian, ukuran tubuh, dan properti konsisten dari awal sampai akhir.

- Efek gempa terlihat melalui lingkungan dan tidak bergantung pada camera shake ekstrem.

- Drop–Cover–Hold On terlihat jelas: merunduk, berlindung di bawah meja kokoh, melindungi kepala/leher, dan berpegangan.

- Evakuasi baru dimulai setelah guncangan berhenti.

- Area aman ditampilkan jauh dari bangunan, tiang listrik, dan pohon besar.

- Teks layar singkat, terbaca dalam 9:16, dan berada di safe area.

- Voice-over tidak terlalu panjang untuk 10 detik dan dibaca dengan tempo natural.

- Tidak ada deformasi karakter, extra limbs, flicker, object popping, atau continuity error.

- Final video tetap ramah anak: tidak ada luka, darah, kepanikan berlebihan, atau visual kehancuran yang menakutkan.

PROYEK 09

# Membuat Konten Berita Viral dengan Claymation — “Upah Kupas Bawang”

Proyek ini mengajarkan bahwa produksi visual tidak boleh mendahului verifikasi editorial. Struktur: klaim viral → klarifikasi → takeaway.

| **HASIL AKHIR**                                                                        | **URUTAN PRAKTIK**                                                     |
|----------------------------------------------------------------------------------------|------------------------------------------------------------------------|
| Script 30 detik • storyboard 12 panel • JSON Scene 1–3 • caption TikTok • QC editorial | Fact framing → script → storyboard → JSON → caption → fact-check akhir |

<img src="media/image12.png" style="width:5.70866in;height:10.14334in" />

LANGKAH 1

## Tetapkan Aturan Editorial

- Pisahkan dengan jelas antara klaim yang viral, informasi klarifikasi, dan pesan edukasi. Jangan menampilkan klaim viral sebagai fakta final.

- Gunakan struktur 3 tahap: HOOK → KLARIFIKASI → TAKEAWAY. Pola ini efektif untuk video 20–40 detik.

- Sebelum publikasi, verifikasi kembali nama, angka, konteks, sumber, dan perkembangan terbaru. Prompt produksi tidak menggantikan proses fact-check editorial.

- Satire dan humor dipakai untuk menarik perhatian, bukan untuk mempermalukan subjek berita.

- Untuk teks angka yang rawan salah baca, tulis bentuk visual dan bentuk voice-over secara terpisah. Contoh visual “Rp700.000” tetapi V.O. “tujuh ratus ribu rupiah”.

- Jika menggunakan figur yang merepresentasikan orang nyata, gunakan representasi generik atau karakter clay tanpa meniru wajah secara berlebihan kecuali memang ada izin/referensi yang sah.

LANGKAH 2

## Tulis Script Hook → Klarifikasi → Takeaway

FORMAT
Durasi total 30 detik; 3 scene × 10 detik; rasio 9:16; gaya handcrafted claymation; tone komedi-informatif.

SCENE 1 — “LOWONGAN IMPIAN?” (0–10 detik)
Visual: Karakter utama melihat HP di pasar claymation. Di layar muncul “KUPAS BAWANG 1 KG = Rp700.000?!”. Ia kaget, langsung memakai apron, mengambil keranjang, lalu berlari membawa bawang. Warga ikut antre membawa karung bawang.
Dialog: “TUJUH RATUS RIBU SEKILO?!”
V.O.: “Jagat media sosial mendadak heboh! Upah kupas bawang disebut sampai tujuh ratus ribu rupiah per kilogram!”
Teks: “NETIZEN: DAFTARNYA DI MANA?!”

SCENE 2 — “TERNYATA...” (10–20 detik)
Visual: Record scratch, semua freeze. Reporter clay muncul membawa kertas klarifikasi. Bawang bertransisi menjadi tumpukan kain majun dan mesin jahit. Papan informasi membandingkan “Rp700.000” dengan “Rp700/kg kain majun”.
Dialog karakter: “Lho... bukan tujuh ratus RIBU?”
Reporter: “Bukan...”
V.O.: “Tapi setelah ramai dibahas, muncul klarifikasi. Pekerjaannya disebut bukan mengupas bawang, melainkan menjahit kain majun dengan upah sekitar tujuh ratus rupiah per kilogram.”

SCENE 3 — “JANGAN CUMA BACA YANG VIRAL” (20–30 detik)
Visual: Karakter menatap kalkulator dan 1 kg bawang. Angka Rp700.000 pecah menjadi tulisan “CEK KONTEKS!”. Karakter menatap kamera sambil memberi pesan cek fakta. Karakter lain bertanya, “Terus... lowongannya jadi nggak ada?” Semua menjawab, “NGGAK ADAAA!”
V.O.: “Sebelum buru-buru percaya sama informasi yang viral, cek fakta dan konteksnya dulu. Karena satu angka yang keliru bisa bikin satu Indonesia siap kupas bawang!”
Ending text: “VIRAL BOLEH, CEK FAKTA JANGAN LUPA!”

LANGKAH 3

## Buat Storyboard 12 Panel

Buat storyboard siap produksi untuk video claymation berita viral “Upah Kupas Bawang” berdurasi 30 detik.

FORMAT
- Rasio 9:16 portrait.
- 3 scene × 10 detik.
- Setiap scene terdiri dari 4 panel/shot, total 12 panel.
- Gaya handcrafted claymation stop-motion, ekspresi besar, hangat, lucu, detail plastisin terlihat.
- Setiap panel wajib memiliki nomor, catatan produksi, shot, action/dialogue, dan bridge ke panel berikutnya.

CHARACTER LOCK
Karakter utama: laki-laki clay, rambut hitam keriting, mata besar ekspresif, kemeja hijau; identitas, wajah, proporsi, warna pakaian, dan clay texture harus sama di seluruh panel.
Reporter: laki-laki clay berkacamata dengan vest berita dan mikrofon; desain harus konsisten pada Scene 2–3.

SCENE 1 — LOWONGAN IMPIAN?
P1 close-up karakter melihat HP bertuliskan “KUPAS BAWANG 1 KG = Rp700.000?!”.
P2 medium shot karakter semangat memakai apron dan bergegas.
P3 wide shot berlari membawa keranjang bawang besar di pasar.
P4 wide group shot warga ikut antre dengan karung bawang; teks “NETIZEN: DAFTARNYA DI MANA?!”.

SCENE 2 — TERNYATA...
P5 wide freeze frame + papan “EH... TUNGGU DULU!”.
P6 medium reporter membawa gulungan kertas klarifikasi.
P7 medium explanatory shot: bawang berubah menjadi kain majun; pekerja menjahit.
P8 medium infographic: “Rp700.000” diberi X, “Rp700/kg kain majun” diberi centang.

SCENE 3 — JANGAN CUMA BACA YANG VIRAL
P9 medium karakter bingung dengan kalkulator dan keranjang 1 KG.
P10 close-up transformasi angka menjadi “CEK KONTEKS!”.
P11 medium hero shot: karakter mengangkat bawang dan mengajak cek fakta.
P12 wide group ending: “Terus... lowongannya jadi nggak ada?” → “NGGAK ADAAA!”.

NEGATIVE
No photorealistic human, no 2D cartoon, no character drift, no extra limbs, no text gibberish, no wardrobe change, no flicker, no random background, no duplicate main character.

OUTPUT
Storyboard production sheet yang mudah dipakai motion designer: 12 panel, informasi shot/action jelas, warna scene berbeda, dan technical notes 1080×1920, 25 fps, 30 detik.

<img src="media/image12.png" style="width:3.54331in;height:6.29587in" />

Contoh storyboard claymation berita viral.

LANGKAH 4

## Buat JSON Scene 1

{
"title": "Scene 1 - Lowongan Impian",
"duration_seconds": 10,
"aspect_ratio": "9:16",
"resolution": "1080x1920",
"fps": 25,
"reference_lock": {
"source": "uploaded storyboard Scene 1 panels 1-4",
"priority": "MAXIMUM",
"instruction": "Keep the same male clay character: curly black hair, large expressive eyes, green shirt, body proportions and handcrafted clay texture in every shot."
},
"visual_style": "cinematic handcrafted claymation stop-motion, warm miniature Indonesian market, tactile plasticine, playful comedy",
"timeline": [
{
"time": "0.0-2.5s",
"shot": "close-up",
"camera": "slow push-in",
"action": "Character reads smartphone, eyes widen and jaw drops.",
"screen_text": "KUPAS BAWANG 1 KG = Rp700.000?!",
"dialogue": "TUJUH RATUS RIBU SEKILO?!"
},
{
"time": "2.5-5.0s",
"shot": "medium",
"camera": "fast tracking",
"action": "He quickly puts on a blue apron, grabs a woven basket and runs excitedly."
},
{
"time": "5.0-7.5s",
"shot": "wide tracking",
"camera": "track backward",
"action": "He runs through the market carrying a huge basket of red-purple onions; vendors react in surprise."
},
{
"time": "7.5-10.0s",
"shot": "wide group",
"camera": "quick pull-back",
"action": "A crowd appears carrying onion sacks as if applying for the job.",
"overlay_text": "NETIZEN: DAFTARNYA DI MANA?!"
}
],
"voice_over": "Jagat media sosial mendadak heboh! Upah kupas bawang disebut sampai tujuh ratus ribu rupiah per kilogram!",
"negative_prompt": [
"character drift",
"face morphing",
"wrong green shirt",
"extra limbs",
"random text",
"misspelled Indonesian text",
"camera flicker",
"lighting flicker"
]
}

LANGKAH 5

## Buat JSON Scene 2

{
"title": "Scene 2 - Ternyata...",
"duration_seconds": 10,
"aspect_ratio": "9:16",
"resolution": "1080x1920",
"fps": 25,
"reference_lock": {
"source": "uploaded storyboard Scene 2 panels 5-8",
"priority": "MAXIMUM",
"instruction": "Continue directly from Scene 1; preserve the exact main character, reporter design, market palette and clay material."
},
"visual_style": "premium handcrafted claymation stop-motion, comedic clarification, warm cinematic miniature lighting",
"timeline": [
{
"time": "0.0-2.2s",
"shot": "wide freeze-frame",
"camera": "slight push-in",
"action": "Everything freezes; a clay sign pops up.",
"on_screen_text": "EH... TUNGGU DULU!",
"sfx": "record scratch"
},
{
"time": "2.2-4.5s",
"shot": "medium",
"camera": "whip-pan",
"action": "Reporter with glasses and NEWS microphone enters and unrolls a clarification paper; question marks appear."
},
{
"time": "4.5-7.2s",
"shot": "medium explanatory",
"camera": "smooth transition",
"action": "Onions transform into folded kain majun; reveal a sewing workspace and worker sewing cloth.",
"on_screen_text": "KAIN MAJUN"
},
{
"time": "7.2-10.0s",
"shot": "medium infographic",
"camera": "subtle push-in",
"action": "Reporter points to board: Rp700.000 with red X, Rp700/kg kain majun with green check.",
"dialogue": "Karakter: Lho... bukan tujuh ratus ribu? Reporter: Bukan..."
}
],
"voice_over": "Tapi setelah ramai dibahas, muncul klarifikasi. Pekerjaannya disebut bukan mengupas bawang, melainkan menjahit kain majun dengan upah sekitar tujuh ratus rupiah per kilogram.",
"negative_prompt": [
"character drift",
"reporter redesign",
"photorealistic human",
"unreadable numbers",
"random text",
"extra limbs",
"background warping",
"flicker"
]
}

LANGKAH 6

## Buat JSON Scene 3

{
"title": "Scene 3 - Jangan Cuma Baca yang Viral",
"duration_seconds": 10,
"aspect_ratio": "9:16",
"resolution": "1080x1920",
"fps": 25,
"reference_lock": {
"source": "uploaded storyboard Scene 3 panels 9-12",
"priority": "MAXIMUM",
"instruction": "Preserve the exact same main character, reporter, market crowd, onions and handcrafted clay visual language from Scenes 1-2."
},
"visual_style": "premium handcrafted claymation stop-motion, funny educational fact-checking ending",
"timeline": [
{
"time": "0.0-2.4s",
"shot": "medium",
"camera": "slow push-in",
"action": "Character looks doubtful at a 1 KG onion basket and calculator showing Rp700.000?.",
"background_text": "VIRAL ITU BELUM TENTU BENAR!"
},
{
"time": "2.4-4.5s",
"shot": "extreme close-up",
"camera": "fast punch-in",
"action": "The calculator value cracks into clay fragments and reforms as bold text.",
"on_screen_text": "CEK KONTEKS!"
},
{
"time": "4.5-7.4s",
"shot": "medium hero",
"camera": "smooth pull-back",
"action": "Character faces camera holding an onion and raises one finger.",
"dialogue": "Sebelum percaya, cek fakta dulu, yuk!"
},
{
"time": "7.4-10.0s",
"shot": "wide ensemble",
"camera": "quick pull-back",
"action": "Supporting character asks about the job; crowd answers together and laughs.",
"dialogue": "Terus... lowongannya jadi nggak ada? — NGGAK ADAAA!",
"ending_text": "VIRAL BOLEH, CEK FAKTA JANGAN LUPA!"
}
],
"voice_over": "Sebelum buru-buru percaya sama informasi yang viral, cek fakta dan konteksnya dulu. Karena satu angka yang keliru bisa bikin satu Indonesia siap kupas bawang!",
"negative_prompt": [
"character drift",
"face morphing",
"duplicate main character",
"extra limbs",
"incorrect calculator numbers",
"unreadable text",
"random subtitles",
"camera flicker",
"lighting flicker"
]
}

LANGKAH 7

## Siapkan Caption Distribusi

Viral katanya kupas bawang 1 kg bisa dapat Rp700 ribu?! 😱🧅

Eits… jangan buru-buru pindah profesi dulu 😆
Ternyata ada konteks yang perlu diluruskan.

Pelajaran hari ini: viral boleh, tapi cek fakta dan konteks jangan lupa! 🔍✨

Kalau benar Rp700 ribu/kg, siapa yang langsung daftar kupas bawang? 😂

\#Claymation \#AnimasiIndonesia \#BeritaViral \#ViralTikTok \#CekFakta \#KupasBawang \#FYPIndonesia \#AnimasiLucu \#StopMotion

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th><p><strong>CATATAN PRAKTIK</strong></p>
<p>Catatan editorial — Caption final harus disesuaikan dengan hasil verifikasi fakta terbaru sebelum upload. Hindari wording yang membuat klaim awal terlihat sebagai fakta final.</p></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

LANGKAH 8

## QC Editorial dan Visual

- Scene 1 jelas diposisikan sebagai klaim/reaksi viral, bukan kesimpulan fakta.

- Scene 2 memberi klarifikasi secara visual dan verbal tanpa membingungkan angka Rp700.000 dan Rp700/kg.

- Scene 3 menutup dengan pesan cek fakta, bukan hanya punchline komedi.

- Karakter utama konsisten: rambut hitam keriting, mata besar, kemeja hijau, proporsi dan tekstur clay sama.

- Reporter, kain majun, mesin jahit, keranjang, bawang, dan kalkulator tidak berubah bentuk tanpa alasan.

- Teks singkat berada di safe area 9:16 dan angka mudah dibaca.

- Tidak ada typo/gibberish, face morphing, extra limbs, object popping, flicker, atau continuity error.

- Voice-over cukup pendek untuk 10 detik per scene dan tidak bertabrakan dengan dialog punchline.

- Fakta, sumber, nama, dan angka diperiksa ulang oleh reviewer konten sebelum publikasi.

PROYEK 10

# Membuat Animasi Persahabatan Anak — Nara & Kiko

Workflow dari ide moral sederhana sampai video 30 detik dan caption publikasi.

| **HASIL AKHIR**                                                                                       | **URUTAN PRAKTIK**                                                              |
|-------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------|
| Bank ide • script 30 detik • character sheet Nara/Kiko • storyboard 12 panel • JSON 3 scene • caption | Nilai karakter → script → character sheets → storyboard → videos → caption → QC |

<img src="media/image13.png" style="width:5.70866in;height:3.21283in" />

LANGKAH 1

## Tentukan Prinsip dan Nilai Cerita

- Gunakan konflik kecil yang mudah dipahami: takut salah, berbeda kemampuan, salah meminjam barang, atau kesulitan menyelesaikan tugas bersama.

- Tunjukkan emosi melalui tindakan dan ekspresi, bukan ceramah panjang. Anak harus bisa memahami perasaan karakter walau tanpa banyak dialog.

- Sahabat tidak perlu “menyelamatkan” tokoh utama. Peran sahabat adalah mendengar, menemani, membantu, dan memberi ruang agar tokoh utama berani bertindak sendiri.

- Satu episode pendek membawa satu pesan utama. Untuk studi kasus ini: dukungan sahabat membantu kita kembali percaya pada diri sendiri.

- Dialog dibuat singkat, hangat, dan mudah diucapkan. Hindari penghinaan, bullying berlebihan, atau penyelesaian yang terasa menggurui.

- Gunakan visual cerah, bentuk karakter imut, ekspresi besar, serta ending hangat yang memberi rasa aman dan optimistis.

LANGKAH 2

## Pilih Premis Cerita

| **Judul**                                   | **Nilai Utama**             | **Premis Singkat**                                                                                                                           |
|---------------------------------------------|-----------------------------|----------------------------------------------------------------------------------------------------------------------------------------------|
| Lilo dan Bubu: Kita Punya Kelebihan Berbeda | Saling menguatkan           | Kelinci yang cepat dan kura-kura yang teliti belajar bahwa kemampuan berbeda justru membuat perjalanan mereka lebih mudah saat bekerja sama. |
| Piko dan Pohon Apel Terakhir                | Saling menguntungkan        | Tupai dan burung saling menukar bantuan untuk mengumpulkan makanan, lalu belajar berbagi dengan teman lain yang membutuhkan.                 |
| Ketika Nara Kehilangan Suaranya             | Dukungan & kepercayaan diri | Nara takut bernyanyi setelah salah nada. Kiko tidak menertawakan, tetapi menemani dan mendorongnya mencoba lagi.                             |
| Kotak Harta Karun Rara dan Jojo             | Menghargai batas teman      | Jojo membuka barang milik Rara tanpa izin dan merusaknya. Ia belajar mengaku salah, meminta maaf, dan bertanya sebelum meminjam.             |
| Jembatan Pelangi Empat Sahabat              | Menghargai kontribusi       | Empat sahabat dengan kekuatan berbeda memperbaiki jembatan bersama dan belajar bahwa setiap kontribusi penting.                              |

LANGKAH 3

## Tulis Script 3 Scene

FORMAT
Durasi total 30 detik; 3 scene × 10 detik; rasio 16:9; target usia 5–8 tahun; premium stylized 3D family animation.

SCENE 1 — NARA KEHILANGAN KEPERCAYAAN DIRI (0–10 detik)
Lokasi: panggung latihan kecil di taman hutan.
Visual: Nara bernyanyi dengan gembira. Saat mencoba nada tinggi, suaranya fals. Dua burung kecil tertawa ringan. Nara berhenti, sayapnya turun, matanya berkaca-kaca, lalu terbang ke dahan dan menyendiri.
Nara: “Laaa… laaa… la—!”
Narator: “Nara suka bernyanyi… sampai suatu hari ia takut suaranya tidak cukup bagus.”

SCENE 2 — KIKO MENGUATKAN NARA (10–20 detik)
Lokasi: di bawah pohon besar saat sore hari.
Visual: Kiko datang membawa bunga, melihat Nara murung, lalu mengajaknya mencoba lagi tanpa memaksa.
Kiko: “Nara… mau coba bernyanyi sekali lagi?”
Nara: “Aku takut salah lagi.”
Kiko: “Tidak apa-apa kalau salah. Aku akan mendengarkan.”
Nara mulai menyanyi pelan: “Laaa…”
Kiko: “Bagus! Coba lagi!”

SCENE 3 — NARA BERANI BERNYANYI (20–30 detik)
Lokasi: Festival Pelangi pada malam hari.
Visual: Nara gugup di panggung. Kiko berada di penonton dan mengangkat dua jempol. Nara menarik napas, bernyanyi lebih percaya diri, lalu penonton bertepuk tangan.
Kiko: “Kamu bisa, Nara!”
Nara: “Laaa… la-la-laaa!”
Nara: “Terima kasih, Kiko!”
Kiko: “Selalu!”
Ending message: “Sahabat membuat kita lebih berani.”

LANGKAH 4

## Buat Character Sheet Nara

Buat character sheet detail Nara, seekor burung kenari kecil yang lucu dan suka bernyanyi, untuk serial animasi anak usia 5–8 tahun.

CHARACTER DESIGN
- spesies: young canary / burung kenari muda
- tubuh kecil, bulat, fluffy, child-friendly
- bulu utama kuning cerah
- bulu sayap, jambul, dan ekor berlapis warna coral, pink, orange, yellow, mint, dan teal
- mata cokelat besar, ekspresif, bulu mata lembut
- paruh kecil warna orange
- aksesori konsisten: pita leher teal, liontin not musik emas, flower festival badge
- properti utama: microphone berbentuk bunga warna pink dengan gagang emas

9 ANGLE
1. front
2. front 3/4 left
3. left side
4. back 3/4 left
5. back
6. back 3/4 right
7. right side
8. front 3/4 right
9. dynamic singing pose

DETAIL PROPERTIES
Flower microphone, music-note charm, festival ribbon badge, feet/claws close-up, beak close-up, wing feather close-up, tail feather pattern, color/material reference.

EXPRESSIONS
Happy singing, shy/nervous, sad, determined, surprised, laughing/joyful.

STYLE & OUTPUT
Premium stylized 3D animated feature-film character sheet, soft detailed feathers, warm clean studio light, professional infographic layout, child-friendly, high resolution, ratio 16:9.

CHARACTER LOCK
Keep Nara exactly the same in every angle: face shape, eye shape/color, crest, beak, body proportion, feather palette, accessories, badge, and microphone.

NEGATIVE
No character drift, no extra wings/legs, no photorealistic bird anatomy, no color changes, no accessory changes, no deformed beak, no random text, no watermark.

Contoh output: character sheet Nara — 9 angle, detail properti, pola bulu, dan ekspresi.

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th><p><strong>CATATAN PRAKTIK</strong></p>
<p>QC cepat — Pastikan urutan warna bulu, bentuk mata, jambul, pita teal, liontin not musik, flower badge, dan microphone tidak berubah antar-angle.</p></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

<img src="media/image14.png" style="width:5.90551in;height:3.32362in" />

Character sheet Nara.

LANGKAH 5

## Buat Character Sheet Kiko

Buat character sheet detail Kiko, anak beruang yang tidak pandai bernyanyi tetapi sangat suportif, hangat, dan selalu menyemangati Nara.

CHARACTER DESIGN
- spesies: cute young bear cub
- tubuh kecil, chubby, rounded, child-friendly
- plush medium-brown fur dengan muzzle dan belly beige
- mata cokelat besar, pipi kemerahan, hidung kecil cokelat gelap
- telinga bulat dan jambul rambut kecil
- aksesori konsisten: teal neckerchief dan friendship badge berbentuk bintang
- properti pendukung: bouquet bunga pink/kuning sebagai simbol dukungan

9 ANGLE
1. front
2. front 3/4 left
3. left side
4. back 3/4 left
5. back
6. back 3/4 right
7. right side
8. front 3/4 right
9. dynamic cheering pose

DETAIL PROPERTIES
Flower gift, friendship badge, neckerchief/scarf, paws/claws, nose close-up, tail/fur close-up.

EXPRESSIONS
Supportive smile, shy/embarrassed, worried for friend, determined, surprised, laughing/cheering.

STYLE & OUTPUT
Premium stylized 3D animated feature-film character sheet, plush detailed fur, warm clean studio lighting, professional infographic layout, ratio 16:9.

CHARACTER LOCK
Keep Kiko exactly identical across all angles: head/body proportion, fur color, muzzle, eyes, nose, ear shape, hair tuft, teal neckerchief, and friendship badge.

NEGATIVE
No character drift, no fur-color shift, no wardrobe change, no extra limbs, no deformed paws, no aggressive expression, no photorealistic bear anatomy, no random text, no watermark.

Contoh output: character sheet Kiko — 9 angle, properti dukungan, detail fur, dan ekspresi.

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th><p><strong>CATATAN PRAKTIK</strong></p>
<p>QC cepat — Kiko harus terbaca sebagai karakter yang hangat dan suportif; hindari ekspresi mengejek, terlalu agresif, atau proporsi yang berubah.</p></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

<img src="media/image15.png" style="width:5.90551in;height:3.32362in" />

Character sheet Kiko.

LANGKAH 6

## Buat Storyboard 12 Panel

Buat storyboard “Ketika Nara Kehilangan Suaranya” berdasarkan script approved.

REFERENCE
Image 1 = character sheet Nara.
Image 2 = character sheet Kiko.
Gunakan keduanya sebagai identity master.

FORMAT
Durasi 30 detik; 3 scene × 10 detik; setiap scene 4 panel; total 12 panel; rasio 16:9; premium stylized 3D family animation; warm, expressive, cinematic, child-friendly.

SCENE 1 — NARA KEHILANGAN KEPERCAYAAN DIRI
P1 wide/medium: Nara latihan bernyanyi di panggung hutan.
P2 medium close-up: nada Nara fals; dua burung kecil tertawa ringan.
P3 close-up emosional: Nara malu dan sedih.
P4 wide: Nara memilih menyendiri di dahan pohon.

SCENE 2 — KIKO MENGUATKAN NARA
P5 wide: Kiko datang menghampiri Nara di bawah pohon.
P6 medium two-shot: Kiko bertanya “Mau coba lagi?”; Nara menjawab “Aku takut salah lagi.”
P7 close-up Kiko: “Tidak apa-apa kalau salah. Aku akan mendengarkan.”
P8 medium two-shot: Nara mencoba bernyanyi lagi; Kiko memberi semangat.

SCENE 3 — NARA BERANI TAMPIL
P9 wide establishing: Festival Pelangi malam hari.
P10 over-shoulder: Kiko di penonton memberi dua jempol dan berkata “Kamu bisa, Nara!”
P11 hero performance: Nara membuka sayap dan bernyanyi dengan berani.
P12 warm two-shot: Nara dan Kiko tersenyum; pesan akhir “Sahabat membuat kita lebih berani.”

CONTINUITY LOCK
Nara dan Kiko harus sama dengan character sheet pada semua panel. Jaga aksesori, warna, body scale, arah pandang, lighting world, serta lokasi yang konsisten.

NEGATIVE
No character redesign, no duplicate Nara/Kiko, no extra limbs/wings, no inconsistent accessories, no scary expressions, no bullying visual, no text gibberish, no watermark.

Contoh output: storyboard 30 detik — 3 scene × 4 panel, lengkap dengan emotional arc dan continuity.

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th><p><strong>CATATAN PRAKTIK</strong></p>
<p>QC cepat — Cek bahwa panel 4 mengantar ke Scene 2, panel 8 menjadi titik balik kepercayaan diri, dan panel 12 menyelesaikan pesan persahabatan tanpa terasa menggurui.</p></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

<img src="media/image13.png" style="width:5.90551in;height:3.32362in" />

Storyboard “Ketika Nara Kehilangan Suaranya”.

LANGKAH 7

## Buat JSON Scene 1

{
"title": "Ketika Nara Kehilangan Suaranya - Scene 1",
"scene": 1,
"duration_seconds": 10,
"aspect_ratio": "16:9",
"fps": 24,
"style": "premium stylized 3D family animation, cinematic feature-film quality, soft detailed feathers, warm forest lighting",
"reference_lock": "Use storyboard panels 1-4 as shot reference and Nara character sheet as strict identity master. Preserve face, eye shape, crest, rainbow feather palette, teal ribbon, music-note pendant, flower badge and flower microphone.",
"timeline": [
{
"time": "0.0-2.5s",
"shot": "wide to medium-wide",
"camera": "gentle dolly-in",
"action": "Nara sings happily on a small wooden forest stage, swaying and opening her wings slightly.",
"voice": "Nara sings: 'Laaa... la-la-laaa...'"
},
{
"time": "2.5-5.0s",
"shot": "medium close-up",
"camera": "subtle push-in + rack focus",
"action": "Nara attempts a high note that becomes slightly off-key; two little birds in the background giggle softly.",
"dialogue": "Birds: 'Hihihi!'"
},
{
"time": "5.0-7.5s",
"shot": "emotional close-up",
"camera": "slow dolly-in",
"action": "Nara lowers the microphone; eyes become watery, wings droop, expression shifts from confident to embarrassed and sad."
},
{
"time": "7.5-10.0s",
"shot": "wide cinematic",
"camera": "smooth tracking then slow pull-back",
"action": "Nara flies to a nearby branch and sits alone with head lowered.",
"narration": "Nara suka bernyanyi... sampai suatu hari ia takut suaranya tidak cukup bagus."
}
],
"audio": "playful orchestral opening -> awkward soft pause -> gentle emotional piano and strings",
"negative_prompt": [
"character redesign",
"Nara color change",
"accessory change",
"duplicate Nara",
"extra wings",
"deformed beak",
"scary bullying",
"text overlay",
"watermark",
"camera shake",
"flicker",
"temporal morphing"
],
"ending_frame": "Nara sits alone on the branch in warm golden forest light, ready for Kiko to approach in Scene 2."
}

LANGKAH 8

## Buat JSON Scene 2

{
"title": "Ketika Nara Kehilangan Suaranya - Scene 2",
"scene": 2,
"duration_seconds": 10,
"aspect_ratio": "16:9",
"fps": 24,
"style": "premium stylized 3D family animation, warm late-afternoon light, emotionally gentle and hopeful",
"reference_lock": "Use storyboard panels 5-8 plus Nara and Kiko character sheets. Keep both characters exactly consistent in face, body proportion, feather/fur color and accessories.",
"timeline": [
{
"time": "0.0-2.2s",
"shot": "wide establishing",
"camera": "slow dolly-in",
"action": "Nara sits sadly on a low branch. Kiko walks in below carrying a small bouquet and looks up with concern."
},
{
"time": "2.2-4.7s",
"shot": "medium two-shot",
"camera": "gentle upward framing",
"action": "Kiko invites Nara to try again; Nara hugs the microphone close and hesitates.",
"dialogue": "Kiko: 'Nara... mau coba bernyanyi sekali lagi?' Nara: 'Aku takut salah lagi.'"
},
{
"time": "4.7-7.2s",
"shot": "medium close-up Kiko",
"camera": "slow emotional push-in",
"action": "Kiko places one paw on his chest and reassures Nara.",
"dialogue": "Kiko: 'Tidak apa-apa kalau salah. Aku akan mendengarkan.'"
},
{
"time": "7.2-10.0s",
"shot": "medium two-shot",
"camera": "slow arc + push-in",
"action": "Nara breathes and sings one soft note. Kiko waits until she finishes, then claps gently.",
"dialogue": "Nara: 'Laaa...' Kiko: 'Bagus! Coba lagi!'"
}
],
"performance": "Nara progresses from withdrawn -> hesitant eye contact -> careful attempt -> small smile. Kiko remains patient, open and never forces her.",
"negative_prompt": [
"character drift",
"fur or feather color shift",
"extra limbs",
"wrong accessories",
"aggressive behavior",
"exaggerated crying",
"random background characters",
"speech bubbles",
"subtitles",
"watermark",
"flicker"
],
"ending_frame": "Nara gives Kiko a small grateful smile after successfully singing a note; warm light becomes slightly brighter."
}

LANGKAH 9

## Buat JSON Scene 3

{
"title": "Ketika Nara Kehilangan Suaranya - Scene 3",
"scene": 3,
"duration_seconds": 10,
"aspect_ratio": "16:9",
"fps": 24,
"style": "premium stylized 3D family animation, magical Festival Pelangi at night, warm lanterns and rainbow lighting",
"reference_lock": "Use storyboard panels 9-12 plus approved Nara and Kiko character sheets. Keep all signature features and accessories unchanged.",
"timeline": [
{
"time": "0.0-2.3s",
"shot": "wide establishing",
"camera": "slow crane-down + dolly-in",
"action": "Festival Pelangi glows at night. Nara stands alone at center stage, nervous but determined."
},
{
"time": "2.3-4.5s",
"shot": "over-the-shoulder from Nara",
"camera": "rack focus to Kiko",
"action": "Kiko in the front audience raises both thumbs and smiles.",
"dialogue": "Kiko: 'Kamu bisa, Nara!'"
},
{
"time": "4.5-7.8s",
"shot": "hero medium-wide",
"camera": "smooth push-in + gentle arc",
"action": "Nara takes a breath, opens her colorful wings and sings with growing confidence; audience begins clapping.",
"dialogue": "Nara: 'Laaa... la-la-laaa!'"
},
{
"time": "7.8-10.0s",
"shot": "warm emotional two-shot",
"camera": "gentle dolly-in",
"action": "Nara smiles gratefully at Kiko; Kiko claps proudly under warm festival bokeh.",
"dialogue": "Nara: 'Terima kasih, Kiko!' Kiko: 'Selalu!'"
}
],
"audio": "magical orchestral anticipation -> hopeful rise -> uplifting performance -> warm emotional resolution",
"negative_prompt": [
"character redesign",
"wrong feather or fur colors",
"duplicate Nara/Kiko",
"extra limbs or wings",
"photorealistic anatomy",
"scary audience",
"chaotic crowd",
"random text",
"subtitles",
"watermark",
"camera shake",
"flicker"
],
"ending_frame": "Nara and Kiko exchange a warm happy look while the audience applauds; hold briefly for end title."
}

LANGKAH 10

## Buat Caption Distribusi

Kadang kita cuma butuh satu sahabat yang bilang, “Kamu bisa.” 🥹💛

Nara sempat kehilangan keberanian untuk bernyanyi setelah melakukan kesalahan. Tapi Kiko tetap ada di sampingnya, mendengarkan, menyemangati, dan membantu Nara berani mencoba lagi. 🐥🐻✨

Karena sahabat yang baik bukan yang menertawakan kesalahan kita, tapi yang membantu kita bangkit dan percaya pada diri sendiri. 🌈🎶

Kalau kamu punya sahabat seperti Kiko, tag dia di komentar! 💕👇

\#AnimasiAnak \#CeritaAnak \#Persahabatan \#SahabatBaik \#BelajarBersama \#CeritaMoral \#Animasi3D \#KidsAnimation \#CeritaInspiratif \#NaraDanKiko \#DongengAnak \#KontenAnak

LANGKAH 11

## QC Emotional Continuity

- Nara konsisten di semua output: wajah, mata, jambul, pola bulu warna-warni, pita teal, liontin not musik, flower badge, dan microphone.

- Kiko konsisten: bentuk kepala/tubuh, warna fur, muzzle beige, mata, jambul kecil, neckerchief teal, dan friendship badge.

- Skala Nara dan Kiko masuk akal dan tidak berubah antar-shot.

- Scene 1 menunjukkan rasa malu tanpa bullying yang terlalu keras atau menakutkan.

- Scene 2 memperlihatkan dukungan yang sehat: Kiko mendengar, tidak memaksa, dan menunggu Nara selesai sebelum bertepuk tangan.

- Scene 3 menampilkan keberanian sebagai hasil latihan dan dukungan, bukan perubahan ajaib yang tiba-tiba.

- Dialog cukup pendek untuk 10 detik per scene; lip-sync Bahasa Indonesia jelas dan tidak bertabrakan dengan musik.

- Camera movement halus; tidak ada jitter, flicker, face/feather/fur morphing, duplicate character, extra limbs, atau object popping.

- Pesan akhir mudah dipahami anak 5–8 tahun dan disampaikan melalui tindakan karakter, bukan ceramah panjang.

- Caption dan hashtag sesuai platform; tidak memasukkan informasi pribadi anak atau klaim yang tidak relevan.

PROYEK 11

# Membuat Video Storytelling / Biografi Kartun 2D

Workflow untuk tokoh sejarah, atlet, atau cerita biografi pendek: naskah → character sheet → storyboard → video per scene.

| **HASIL AKHIR**                                                     | **URUTAN PRAKTIK**                                 |
|---------------------------------------------------------------------|----------------------------------------------------|
| Naskah • character sheet 2D • storyboard vertical • JSON scene • QC | Story → karakter → storyboard → video → continuity |

LANGKAH 1

## Tulis Naskah dan Bagi Menjadi Scene

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th><p><strong>CONTOH POLA</strong></p>
<p>Untuk kisah Pelé usia 17 tahun: pilih satu momen emosional utama, bukan seluruh biografi. Setiap scene membawa satu beat: tekanan → dukungan/keputusan → keberanian/hasil.</p></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

LANGKAH 2

## Buat Character Sheet Kartun 2D

CONTOH / TEMPLATE

Buat character sheet kartun 2D untuk karakter yang akan digunakan dalam storyboard animasi.

REFERENCE
Gunakan foto/gambar referensi sebagai sumber identitas utama. Jika tokoh merupakan figur sejarah atau atlet, pertahankan ciri visual yang relevan dengan periode cerita tanpa mengubahnya menjadi potret fotorealistis.

OUTPUT
- front view
- side view
- 3/4 view
- back view
- full-body neutral pose
- ekspresi: tenang, gugup, fokus, berani, bahagia, terkejut
- pose aksi yang sesuai cerita

STYLE
Professional 2D animation character design, clean line art, flat-to-soft cel shading, expressive eyes, readable silhouette, production-ready turnaround sheet.

CHARACTER LOCK
Keep the same face shape, hairstyle, skin tone, height impression, body proportions, costume language, and signature features in every pose.

NEGATIVE
No photorealism, no 3D render, no face drift, no inconsistent age, no costume mutation, no extra limbs, no random text.

LANGKAH 3

## Buat Storyboard 9:16 — 3 Scene × 4 Panel

CONTOH / TEMPLATE

Buat storyboard animasi kartun 2D dari naskah yang telah disetujui.

FORMAT
3 scene, setiap scene terdiri dari 4 panel, rasio 9:16. Setiap scene dirancang untuk durasi sekitar 10 detik.

REFERENCE
Image 1 = karakter utama.
Image 2 = karakter pendamping/orang tua/pelatih.
Gunakan character sheet sebagai identity master.

PANEL LOGIC
Panel 1 = establishing / situasi.
Panel 2 = reaksi emosional.
Panel 3 = aksi atau dialog inti.
Panel 4 = bridge menuju scene berikutnya.

VISUAL
Professional 2D animation storyboard, cinematic composition, clear silhouette, expressive acting, varied shot size: wide, medium, close-up, low angle, over-shoulder.

CONTINUITY LOCK
Wajah, usia, pakaian, warna, lokasi, arah gerak, dan posisi properti harus logis dari panel ke panel.

NEGATIVE
No character drift, no duplicated character, no inconsistent wardrobe, no random background change, no extra limbs, no unreadable composition.

LANGKAH 4

## Buat JSON Video per Scene

CONTOH / TEMPLATE

{
"title": "[Scene]",
"duration_seconds": 10,
"aspect_ratio": "9:16",
"visual_style": "professional 2D cartoon animation, clean line art, cinematic cel shading",
"reference_lock": {
"priority": "MAXIMUM",
"instruction": "Use the attached storyboard and character sheet as the visual master. Keep face, age, hairstyle, outfit and body proportions consistent."
},
"timeline": [
{
"time": "0.0-2.5s",
"shot": "wide establishing",
"camera": "slow push-in",
"action": "Establish the location and emotional situation."
},
{
"time": "2.5-5.0s",
"shot": "medium close-up",
"camera": "gentle dolly-in",
"action": "Character reacts naturally; subtle blink and breathing."
},
{
"time": "5.0-7.5s",
"shot": "close-up / action",
"camera": "controlled tracking",
"action": "Main dialogue or decisive action."
},
{
"time": "7.5-10.0s",
"shot": "hero / transition",
"camera": "smooth pull-back",
"action": "End with a visual bridge to the next scene."
}
],
"animation_notes": [
"natural blink",
"subtle breathing",
"clean hand motion",
"stable line art",
"consistent character proportions"
],
"negative_prompt": [
"face morphing",
"age change",
"costume change",
"extra limbs",
"frame flicker",
"warped line art",
"camera jitter"
]
}

LANGKAH 5

## QC

- Usia visual tokoh tidak berubah.

- Kostum sesuai periode/brief dan konsisten.

- Line art tidak flicker atau berubah gaya antar-frame.

- Wajah tetap dikenali namun tidak dipaksa menjadi fotorealistik.

- Storyboard panel terakhir menjadi bridge ke scene berikutnya.

PROYEK 12

# Membuat AI Influencer dan Character Sheet

Workflow identity-first: sebelum membuat banyak konten, kunci identitas di reference sheet.

| **HASIL AKHIR**                                                                    | **URUTAN PRAKTIK**                                                 |
|------------------------------------------------------------------------------------|--------------------------------------------------------------------|
| Identity sheet • 5–9 angle • ekspresi • outfit variations • lifestyle content • QC | Foto referensi → identity lock → character sheet → variations → QC |

<img src="media/image16.png" style="width:5.70866in;height:6.43372in" />

LANGKAH 1

## Tentukan Reference dan Identity Lock

TUJUAN
Buat AI Influencer [pria/wanita] dari gambar referensi dengan gaya hiper-realistis untuk Instagram dan TikTok.

IDENTITY LOCK
Pertahankan struktur wajah, bentuk mata, hidung, bibir, rahang, warna kulit, gaya rambut, proporsi kepala dan tubuh. Tambahkan tekstur kulit alami, pori-pori, sedikit asimetri, dan ketidaksempurnaan kecil yang realistis tanpa mengubah identitas.

TAHAP 1 — CHARACTER REFERENCE SHEET
Front view, side view, 3/4 view, neutral expression, neutral lighting. Gunakan pencahayaan studio netral untuk mengunci identitas.

TAHAP 2 — VARIASI KONTEN
Buat turunan dengan variasi camera angle, pose, outfit, lighting, lokasi, aktivitas, dan lingkungan.

STYLE
Hyper-realistic, premium, modern, elegant, aspirational lifestyle, detailed hair strands, realistic skin shading, cinematic photography.

NEGATIVE
No face morphing, no age change, no eye-color shift, no distorted anatomy, no plastic skin, no inconsistent hairstyle, no random accessories.

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th><p><strong>CATATAN PRAKTIK</strong></p>
<p>Praktik terbaik: jangan langsung memproduksi banyak pose dari satu foto. Character reference sheet digunakan sebagai identity master untuk menjaga konsistensi antar-konten.</p></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

LANGKAH 2

## Jika Karakter Anak, Terapkan Kesesuaian Usia

CONTOH / TEMPLATE

TUJUAN
Buat seorang AI Influencer anak Islami dari gambar referensi dengan gaya hiper-realistis untuk Instagram dan TikTok.

REFERENCE
Gunakan foto anak yang diunggah sebagai identity master. Pertahankan kemiripan wajah dan usia visual. Jangan mengubah karakter menjadi orang dewasa.

IDENTITY LOCK — MAXIMUM
Pertahankan secara konsisten:
- struktur wajah dan bentuk rahang
- bentuk mata, alis, hidung, dan bibir
- warna kulit dan proporsi tubuh
- bentuk rambut dan garis rambut
- ciri khas ekspresi
- usia visual anak

REALISM
Gunakan tekstur kulit alami yang sesuai usia, detail rambut realistis, sedikit asimetri wajah, pencahayaan fotografis natural, dan anatomi tubuh yang proporsional. Hindari skin texture yang terlalu dewasa atau efek beauty filter berlebihan.

TAHAP 1 — CHARACTER REFERENCE SHEET
Tampilkan:
1. tampak depan
2. tampak samping
3. sudut 3/4
4. ekspresi netral
5. pencahayaan netral
6. full-body neutral pose
7. beberapa ekspresi ringan: senyum, serius, percaya diri, tertawa

TAHAP 2 — VARIASI KONTEN
Buat variasi yang tetap sesuai usia:
- outfit casual sopan
- baju koko / busana Islami
- aktivitas membaca Al-Qur'an atau buku
- olahraga ringan
- kegiatan outdoor
- membuat konten edukatif
- lingkungan masjid, taman, rumah, sekolah, atau ruang kreatif yang wajar

STYLE
Hyper-realistic, premium, modern, elegant, aspirational but age-appropriate, natural photography, cinematic lighting.

NEGATIVE
No age progression, no adult styling, no face morphing, no body exaggeration, no sexualized pose or wardrobe, no heavy makeup, no distorted anatomy, no extra fingers, no inconsistent hairstyle, no random accessories, no watermark.

Contoh output character reference sheet:

Contoh: identity sheet anak Islami dengan front/side/3⁄4, pencahayaan netral, variasi outfit, aktivitas, dan ekspresi.

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th><p><strong>CATATAN PRAKTIK</strong></p>
<p>QC cepat — wajah harus tetap orang yang sama, usia visual konsisten, wardrobe sopan dan sesuai usia, anatomi natural, serta tidak ada perubahan bentuk rambut, warna kulit, atau proporsi tubuh.</p></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

- Gunakan pose, wardrobe, aktivitas, dan ekspresi yang sesuai usia.

- Hindari styling dewasa, sensualisasi, body exaggeration, atau beauty treatment yang mengubah karakter anak.

- Untuk konten Islami, gunakan konteks ibadah/edukasi secara wajar dan hormat; jangan menjadikan simbol keagamaan sekadar dekorasi acak.

- Jangan menambahkan data pribadi, nama lengkap, sekolah, alamat, atau lokasi spesifik anak pada artwork publik tanpa kebutuhan dan izin.

- Jika karakter berasal dari foto referensi, character sheet dipakai untuk konsistensi visual, bukan untuk mengubah usia atau identitas.

LANGKAH 3

## Buat Character Reference Sheet

<img src="media/image16.png" style="width:5.90551in;height:6.65558in" />

Contoh character sheet AI influencer — identitas, angle, ekspresi, outfit, aktivitas.

LANGKAH 4

## Buat Variasi Konten Setelah Identity Stable

- Camera angle

- Pose

- Outfit

- Lighting

- Lokasi

- Aktivitas

- Environment

LANGKAH 5

## QC

- Struktur wajah sama.

- Usia visual konsisten.

- Warna kulit/rambut tidak drift.

- Body proportions konsisten.

- Tidak ada aksesori acak.

- Untuk anak: styling dan pose tetap age-appropriate.

PROYEK 13

# Membuat Video Event Berseri dengan Character Lock — Google Flow

Workflow troubleshooting untuk scene berseri ketika wajah/karakter berubah walaupun storyboard sudah benar.

| **HASIL AKHIR**                                                                                  | **URUTAN PRAKTIK**                                                                  |
|--------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------|
| Master reference • keyframe per scene • JSON character lock • continuity QC • limited correction | Character sheet → keyframe → scene prompt → generate → compare → limited correction |

<img src="media/image17.png" style="width:5.70866in;height:3.21283in" />

LANGKAH 1

## Tetapkan Hierarki Reference

- Primary character image — gambar karakter utama yang paling representatif; dipakai sebagai jangkar identitas visual.

- Character sheet — front/side/3⁄4/ekspresi netral; digunakan sebagai identity master untuk mempertahankan struktur wajah dan proporsi.

- Storyboard — dipakai untuk komposisi, blocking, urutan aksi, dan kamera; bukan sebagai sumber identitas utama jika wajah karakter di panel kecil.

- Setiap scene mengulang reference yang sama. Jangan hanya mengandalkan scene sebelumnya sebagai memori visual.

- Jika platform hanya mengizinkan sedikit reference, prioritaskan character sheet + keyframe scene, lalu jelaskan fungsi masing-masing reference di prompt.

LANGKAH 2

## Buat Master JSON Character Lock

{
"project": {
"title": "Kemah Bakti untuk Negeri 2026",
"scene": "[1/2/3]",
"duration_seconds": 10,
"aspect_ratio": "9:16",
"style": "premium stylized 3D animation, cinematic, warm, detailed, family-friendly",
"language": "Indonesian"
},
"references": {
"primary_character_image": "karakter rohiyat.png",
"character_sheet_image": "karaktersheet rohiyat.png",
"storyboard_image": "STORYBOARD"
},
"character_lock": {
"enabled": true,
"priority": "MAXIMUM",
"identity_reference": "Use karakter rohiyat.png and karaktersheet rohiyat.png as strict identity references for the main character across every shot.",
"must_preserve": [
"same facial structure",
"same eye shape and eye color",
"same nose and mouth proportions",
"same hairstyle",
"same skin tone",
"same body proportions",
"same outfit and accessories"
],
"forbidden": [
"face morphing",
"age change",
"hairstyle change",
"body proportion drift",
"wardrobe redesign",
"random accessories"
]
},
"storyboard_lock": {
"instruction": "Use the storyboard only for shot composition, action, camera direction and environment. Never let storyboard panel variation override the character identity reference."
},
"timeline": [
{
"time": "0.0-2.5s",
"shot": "[shot 1]",
"camera": "[movement]",
"action": "[action based on approved storyboard]"
},
{
"time": "2.5-5.0s",
"shot": "[shot 2]",
"camera": "[movement]",
"action": "[action]"
},
{
"time": "5.0-7.5s",
"shot": "[shot 3]",
"camera": "[movement]",
"action": "[action]"
},
{
"time": "7.5-10.0s",
"shot": "[shot 4 / bridge]",
"camera": "[movement]",
"action": "[ending that bridges to next scene]"
}
],
"negative_prompt": [
"character redesign",
"face drift",
"face morphing",
"wrong hairstyle",
"wrong clothing",
"extra limbs",
"deformed hands",
"duplicate main character",
"camera jitter",
"lighting flicker",
"random text"
]
}

LANGKAH 3

## Generate Scene per Scene

1\. Lock identity lebih dahulu — Pilih satu character sheet approved. Jika wajah belum stabil dalam still image, jangan masuk ke video.

2\. Buat keyframe tiap scene — Generate/siapkan satu keyframe yang sudah cocok dengan storyboard namun tetap memakai character sheet sebagai identity master.

3\. Gunakan reference yang sama — Untuk Scene 1, 2, dan 3, attach ulang primary character image + character sheet. Storyboard hanya mengatur pose/kamera.

4\. Ulangi character_lock — Jangan menganggap model mengingat karakter. Blok identity lock harus muncul kembali pada setiap JSON/prompt scene.

5\. Batasi perubahan per shot — Dalam 10 detik, gunakan 3–4 shot yang jelas. Terlalu banyak transformasi/outfit/angle ekstrem meningkatkan risiko drift.

6\. QC frame awal dan akhir — Bandingkan frame pertama dan terakhir dengan character sheet: wajah, rambut, outfit, tinggi, aksesori, skin tone, dan proporsi.

7\. Revisi terbatas — Jika hanya wajah yang berubah, revisi wajah/identity lock saja; jangan regenerate total scene yang sudah benar.

LANGKAH 4

## Perbaiki Character Drift Tanpa Merusak Scene

PERBAIKAN TERBATAS — CHARACTER IDENTITY ONLY.

SOURCE
Gunakan video/keyframe terakhir dan character sheet Rohiyat sebagai master.

MASALAH
Wajah karakter berubah dibanding character sheet pada [shot/timecode].

PERBAIKI HANYA
- struktur wajah
- bentuk mata/alis/hidung/bibir
- hairstyle
- proporsi kepala dan tubuh jika drift

PERTAHANKAN PERSIS
- kamera dan framing
- gerakan yang sudah benar
- outfit dan aksesori
- lighting dan environment
- props dan background
- durasi serta timing

NEGATIVE
Do not redesign. Do not beautify into a different person. No age change, no hairstyle change, no new accessories, no outfit change, no scene recomposition.

LANGKAH 5

## QC Continuity

- Primary character image dan character sheet benar-benar karakter yang sama.

- Scene 1, 2, dan 3 menggunakan reference identity yang sama.

- Wajah tidak berubah ketika shot berpindah close-up → medium → wide.

- Rambut, outfit, aksesori, dan warna kulit tidak berubah antar-shot.

- Storyboard tidak mengoverride identity ketika gambar panel menampilkan versi wajah yang kurang konsisten.

- Gerak tubuh natural dan tidak menghasilkan extra fingers/limbs atau tangan mencair.

- Ending Scene 1 menjadi bridge ke Scene 2; ending Scene 2 menjadi bridge ke Scene 3.

- Prompt scene disimpan sebagai file JSON terpisah dengan versioning, misalnya KBN26_SC01_v03.json.

- Setelah video approved, arsipkan reference image, character sheet, storyboard, prompt final, dan output final dalam folder proyek yang sama.

<img src="media/image17.png" style="width:5.90551in;height:3.32362in" />

Contoh master character sheet yang digunakan sebagai identity reference.

PROYEK 14

# Membuat Komik / Manga dari Brief Event

Workflow adaptasi satu brief menjadi visual storytelling panel tanpa kehilangan hook, identitas, dan data acara.

| **HASIL AKHIR**                                              | **URUTAN PRAKTIK**                                                                  |
|--------------------------------------------------------------|-------------------------------------------------------------------------------------|
| Komik semi-realistis • manga 6 panel • final typography • QC | Brief/hook → identity lock → panel flow → prompt → generate → typography final → QC |

<img src="media/image18.png" style="width:5.70866in;height:8.56299in" />

LANGKAH 1

## Kunci Hook, Data Event, dan Identitas Tokoh

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th><p><strong>HOOK LOCK</strong></p>
<p>Jika klien memberi hook yang harus persis, masukkan instruksi “copy exactly” dan larangan mengubah kata. Hook tidak boleh dijadikan bahan improvisasi. CTA dapat mengacu pada materi referensi bila diminta. Data event dan identitas karakter juga harus dikunci sebelum masuk ke layout panel.</p></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

LANGKAH 2

## Pilih Gaya: Komik Semi-Realistis atau Manga

Format ini cocok untuk event, kampanye, edukasi, atau inspirational storytelling. Pertahankan wajah asli dari foto, tetapi render sebagai digital painting/webtoon/editorial illustration. Gunakan 6–8 panel, dialog pendek, dan CTA di bagian bawah.

Gunakan ketika target visual menginginkan energi shonen/seinen: line art tajam, screentone, speed line, impact frame, dynamic perspective, dan panel asymmetrical. Walau style berubah, identitas wajah tetap dikunci.

LANGKAH 3

## Generate Komik Semi-Realistis

BERTINDAK SEBAGAI KOMIKUS PROFESIONAL.
Buat satu halaman komik poster semi-realistis portrait berdasarkan “Kemah Bhakti Untuk Negeri 2026”. Gunakan foto manusia yang diunggah sebagai referensi utama tokoh. Pertahankan bentuk wajah, kacamata, warna kulit, hidung, senyum, rahang, rambut/kumis, proporsi tubuh, topi, pakaian, tas, dan aksesori secara konsisten.

FORMAT
Inspirational Storytelling, 7 panel, arah baca kiri ke kanan lalu atas ke bawah, rasio 2:3 portrait, minimum 2048×3072, 300 DPI. Headline besar di atas dan CTA kuat di bawah.

ALUR
P1 hero opening di campsite: “Siap beraksi untuk negeri!”
P2 direct invitation: “Yuk, ikut Kemah Bhakti Untuk Negeri 2026!”
P3 tanggal/lokasi: Jumat–Ahad, 2–4 Oktober 2026; Bumi Kepanduan Sentul, Bojong Koneng, Babakan Madang, Sentul–Bogor.
P4 triptych aksi Camping, Training, Tracking.
P5 biaya: Putra Rp200.000; Putri Rp150.000.
P6 persiapan: “Siapkan kondisi fisik, perlengkapan pribadi, dan semangat terbaik.”
P7 closing hero shot dengan bendera Indonesia; “Berbakti, Berkarya, Menginspirasi untuk Negeri!”; informasi pendaftaran Coach Budianto 0812-8054-0854, Coach Ated 0812-8766-8157, Coach Fahmi 0852-1807-0870; CTA “Satu Tekad, Satu Bhakti, untuk Indonesia! Ayo daftar sekarang.”

STYLE
Premium semi-realistic digital comic: modern webtoon + editorial illustration + social-media comic + premium digital painting. Cinematic warm lighting, detailed campsite, expressive face, dynamic perspective, global illumination, ambient occlusion, soft shadow, depth of field. Balon dialog seluruhnya di dalam panel; semua teks jelas; tidak typo; tidak watermark; tidak ada extra limbs atau perubahan identitas.

OUTPUT CONTOH

QC CEPAT — Prioritaskan kemiripan wajah, hierarki headline, keterbacaan data, konsistensi outfit, dan balon dialog. Aset presisi tetap difinalisasi manual.

<img src="media/image6.png" style="width:3.54331in;height:5.31496in" />

Contoh komik poster / storytelling event.

LANGKAH 4

## Generate Manga Jepang Modern

BERTINDAK SEBAGAI KOMIKUS MANGA JEPANG PROFESIONAL.

HOOK — COPY EXACTLY, JANGAN DIUBAH:
Kemah Bhakti untuk Negeri 2026
Proda Kota Bekasi

Gunakan foto referensi yang diunggah sebagai master identity tokoh utama. Walaupun dirender sebagai manga, pertahankan bentuk wajah, kacamata, rahang, hidung, senyum, kumis/janggut, topi, pakaian, tas, tinggi, dan proporsi agar tetap dikenali di semua panel.

OUTPUT
Satu halaman manga Jepang modern, 6 panel dinamis, arah baca kiri ke kanan, rasio 2:3 portrait, minimum 2048×3072, 300 DPI. Shonen/seinen modern, black-and-white ink, sharp line art, professional screentone, dramatic shadows, detailed background, dynamic composition, speed lines, impact frame, dust/smoke effect secukupnya.

STORY ARC
P1 hook/pembuka: low-angle hero shot di area kemah, headline hook persis.
P2 masalah: Gen Z ingin bergerak tetapi belum tahu mulai dari mana; “Kita butuh ruang untuk tumbuh bareng.”
P3 konflik: medan/latihan terasa berat, keraguan meningkat, tokoh tetap maju.
P4 pemahaman: event adalah ruang berbakti dan berkembang; tampilkan Jumat–Ahad, 2–4 Oktober 2026 dan lokasi Bumi Kepanduan Sentul, Bojong Koneng, Babakan Madang, Sentul–Bogor.
P5 solusi: montage Camping, Training, Tracking; biaya Putra Rp200.000, Putri Rp150.000.
P6 ending/CTA: hero shot dengan bendera Indonesia; “Berbakti, Berkarya, Menginspirasi untuk Negeri!”; Coach Budianto 0812-8054-0854, Coach Ated 0812-8766-8157, Coach Fahmi 0852-1807-0870; CTA “Satu Tekad, Satu Bhakti, untuk Indonesia! Ayo daftar sekarang.”

QC
Balon dialog proporsional dan di dalam panel. Font manga jelas. Tidak ada typo, teks terpotong, wajah berubah, objek cacat, extra limbs, karakter bertambah tanpa alasan, watermark, atau style drift.

OUTPUT CONTOH

QC CEPAT — Hook harus persis, identitas tokoh tetap dikenali, urutan baca jelas, screentone tidak menutup teks, dan CTA terbaca penuh.

<img src="media/image18.png" style="width:3.54331in;height:5.31496in" />

Contoh manga event — hook dan CTA tetap dikunci.

LANGKAH 5

## Finalisasi Tipografi dan QC

- Hook persis.

- Wajah/karakter tetap dikenali.

- Urutan panel jelas.

- Speech balloon tidak memotong panel.

- Data event dan CTA diperiksa manual.

- Teks kritikal dapat ditempel ulang di editor.

# BAGIAN C — QC Universal, Revisi, dan Arsip

## Checklist QC Universal

- [ ] Wajah/karakter sama di semua panel?

- [ ] Proporsi tubuh konsisten?

- [ ] Tangan, jari, telinga, kaki tidak cacat?

- [ ] Pakaian, tas, topi, kacamata konsisten?

- [ ] Logo tidak berubah bentuk/warna?

- [ ] Lighting dan rendering berada di dunia visual yang sama?

- [ ] Background tidak tiba-tiba berubah?

- [ ] Gerakan antar shot logis?

- [ ] Hook/judul persis?

- [ ] Tanggal benar?

- [ ] Lokasi benar?

- [ ] Harga benar?

- [ ] Nama dan nomor kontak benar?

- [ ] Tidak ada typo?

- [ ] V.O. mengucapkan angka dengan benar?

- [ ] CTA sesuai brief?

- [ ] Rasio sesuai platform?

- [ ] Resolusi cukup?

- [ ] Orientasi benar?

- [ ] Text safe area aman?

- [ ] Durasi tiap scene tepat?

- [ ] Frame tidak flicker/jitter?

- [ ] Audio tidak menutupi VO?

- [ ] File naming dan versi benar?

## Prompt Revisi Terbatas — Siap Salin

Gunakan satu prompt untuk satu masalah agar AI tidak mengubah bagian yang sudah benar.

```text
PERBAIKAN TERBATAS — jangan ubah bagian lain.

Masalah yang terlihat: [GANTI: satu error spesifik dan lokasinya].
Perbaiki hanya: [GANTI: elemen yang salah].
Pertahankan persis: [GANTI: wajah/karakter/logo/outfit/background/komposisi
yang sudah benar].

Do not redesign the character or product. Do not change approved elements.
Tampilkan ringkasan perubahan sebelum melakukan generate ulang.
```

## Struktur Folder dan Naming Convention

Contoh struktur folder:

```text
PROJECT_NAME/
├── 00_BRIEF/
├── 01_REFERENCE/
│   ├── CHARACTER/
│   ├── LOGO/
│   ├── WARDROBE/
│   └── LOCATION/
├── 02_CHARACTER_SHEET/
├── 03_STORYBOARD/
├── 04_PROMPTS/
│   ├── MASTER/
│   ├── IMAGE/
│   ├── VIDEO/
│   └── COMIC/
├── 05_GENERATIONS/
├── 06_APPROVED/
├── 07_FINAL_ARTWORK/
└── 08_ARCHIVE/
```

Contoh file: KBN26_SC02_VIDEO_PROMPT_v04.json, KBN26_CHAR_COACH_MASTER_v03.png, KBN26_STORYBOARD_30S_v07.png.

# Lembar Praktik Peserta

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th><p><strong>1 — BRIEF</strong></p>
<p>Tuliskan: tujuan, audience, platform, rasio, durasi, hook, CTA, reference, product/character lock, dan data yang perlu diverifikasi.</p></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th><p><strong>2 — MASTER PROMPT</strong></p>
<p>Tulis prompt dengan urutan: OBJECTIVE → REFERENCE → LOCK → STYLE → STRUCTURE → ACTION/TIMELINE → TEXT/VO → NEGATIVE → TECHNICAL OUTPUT.</p></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th><p><strong>3 — QC HASIL PERTAMA</strong></p>
<p>Catat hanya error yang benar-benar terlihat: identitas, anatomi, produk, logo, teks, continuity, kamera, atau physics.</p></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th><p><strong>4 — REVISI TERBATAS</strong></p>
<p>Perbaiki satu jenis error per iterasi. Pertahankan elemen yang sudah approved. Hindari regenerate total tanpa alasan.</p></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

## Checklist Lulus Praktik

| **STATUS** | **ITEM**  | **KRITERIA**                                                         |
|------------|-----------|----------------------------------------------------------------------|
| ☐          | BRIEF     | Tujuan, audience, hook, CTA, rasio, durasi jelas.                    |
| ☐          | REFERENCE | Fungsi setiap foto/logo/reference jelas.                             |
| ☐          | LOCK      | Elemen yang tidak boleh berubah tertulis eksplisit.                  |
| ☐          | STORY     | Urutan beat/scene logis.                                             |
| ☐          | PROMPT    | Prompt modular dan tidak berisi klaim yang tidak terverifikasi.      |
| ☐          | VIDEO     | Timeline, kamera, action, VO, negative prompt jelas.                 |
| ☐          | QC        | Visual + informasi + teknis diperiksa.                               |
| ☐          | FINAL     | Logo/teks/harga/QR kritikal difinalisasi manual.                     |
| ☐          | ARCHIVE   | Prompt final, reference, output approved disimpan dengan versioning. |

## Catatan Pembaruan Versi 2.2

Versi 2.2 menambahkan fondasi praktik dari materi pelatihan yang dilampirkan: struktur konten Judul–Hook–Isi–Caption–CTA, formula prompt poster 10 blok, bank gaya visual, istilah kualitas gambar, kode HEX dan palet warna, workflow ChatGPT–Canva, serta workflow Hook–Script–Google Flow. Struktur proyek end-to-end pada versi 2.1 tetap dipertahankan sehingga peserta dapat membaca fondasi sekali lalu mempraktikkan satu proyek dari awal sampai final.

# Penutup

Versi 2.2 mempertahankan pola belajar berbasis proyek end-to-end dari versi sebelumnya, lalu menambahkan fondasi yang dapat dibaca sekali: struktur konten, hook, formula prompt poster, gaya visual, warna/HEX, workflow Canva, dan workflow video AI. Peserta tidak perlu menggabungkan bab “creative brief”, “flyer”, “storyboard”, dan “video” secara manual; setelah memahami fondasi, setiap proyek sudah menyediakan perjalanan lengkap dari input awal sampai output final. Fondasi universal tetap disimpan di awal, sedangkan QC universal dan revisi terbatas ditempatkan di akhir agar dapat dipakai untuk semua tema.

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th><p><strong>PRINSIP TERAKHIR</strong></p>
<p>AI mempercepat eksplorasi dan produksi, tetapi kebenaran data, konsistensi brand/karakter, serta kualitas final tetap ditentukan oleh proses brief, lock, QC, dan final compositing yang disiplin.</p></th>
</tr>
</thead>
<tbody>
</tbody>
</table>
