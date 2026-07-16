# Basis Data & Networking Docs

Portal dokumentasi ini merangkum materi **networking**, **database enterprise**, dan **write-up lab** dalam satu situs yang mudah dijelajahi.

[Buka Networking](Networking/HPE_Aruba_Campus_Access/README.md){ .md-button .md-button--primary }
[Buka Database](<Pelatihan Pengelolaan Basis Data Enterprise, 6 - 10 Juli 2026/cheat_sheet_oracle_day1_command.md>){ .md-button }
[Buka Write-Up](<Write-Up Lab/README.md>){ .md-button }

## Mulai dari sini

<div class="grid cards" markdown>

- :material-router-network:{ .lg .middle } **Networking**

    ---

    Materi Aruba campus, AOS-CX lab, routing, overlay, dan data center.

    - [Overview Aruba Campus Access](Networking/HPE_Aruba_Campus_Access/README.md)
    - [Mulai AOS-CX Labs](Networking/AOS-CX_Lab_Guides/README.md)
    - Jalur belajar: **Layer 2 → Routing → Overlay**

- :material-database:{ .lg .middle } **Database**

    ---

    Cheat sheet harian Oracle dan materi DBA 19c untuk administrasi database enterprise.

    - [Cheat Sheet Day 1](<Pelatihan Pengelolaan Basis Data Enterprise, 6 - 10 Juli 2026/cheat_sheet_oracle_day1_command.md>)
    - [Cheat Sheet Day 5](<Pelatihan Pengelolaan Basis Data Enterprise, 6 - 10 Juli 2026/cheat_sheet_oracle_day5_command.md>)
    - [Materi DBA 19c](<Pelatihan Pengelolaan Basis Data Enterprise, 6 - 10 Juli 2026/File MD Pelatihan DBA 19c/manajement_instance.md>)

- :material-file-document-outline:{ .lg .middle } **Write-Up**

    ---

    Ringkasan cepat, detail eksploitasi, dan cheatsheet untuk kebutuhan lab.

    - [Ringkasan Write-Up](<Write-Up Lab/README.md>)
    - [Cheatsheet](<Write-Up Lab/cheatsheet.md>)
    - Tersedia versi ringkas dan versi detail per lab

</div>

## Rekomendasi jalur belajar

=== "Networking"

    1. Mulai dari `Overview`
    2. Lanjut ke `Fondasi Layer 2`
    3. Masuk ke `Routing & Campus`
    4. Tutup dengan `Overlay & Data Center`

=== "Database"

    1. Baca `Cheat Sheet Harian`
    2. Gunakan `DBA 19c` sebagai referensi konsep
    3. Lompat ke topik spesifik saat troubleshooting

=== "Write-Up"

    1. Baca `Ringkasan`
    2. Buka lab target
    3. Gunakan halaman `Detail` saat perlu langkah lengkap

## Akses di GitHub Pages

Situs ini disiapkan untuk tayang di:

- [https://cakgup.github.io/catatan/](https://cakgup.github.io/catatan/)

Jika perubahan baru saja dipush, GitHub Pages biasanya perlu beberapa menit untuk rebuild.

## Jalankan lokal

```bash
pip install -r requirements-docs.txt
mkdocs serve
```

Lalu buka `http://127.0.0.1:8000`.
