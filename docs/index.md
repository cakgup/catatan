# Basis Data & Networking Docs

Dokumentasi ini mengumpulkan materi belajar, cheat sheet, dan write-up lab dari repositori ini dalam format yang siap dipublikasikan dengan `Material for MkDocs`.

## Jelajahi Konten

### Networking

- [Overview Aruba Campus Access](Networking/HPE_Aruba_Campus_Access/README.md)
- [Mulai AOS-CX Labs](Networking/AOS-CX_Lab_Guides/README.md)
- Jalur belajar disusun dari **Fondasi Layer 2 → Routing & Campus → Overlay & Data Center**

### Database

- [Cheat Sheet Oracle Day 1](<Pelatihan Pengelolaan Basis Data Enterprise, 6 - 10 Juli 2026/cheat_sheet_oracle_day1_command.md>)
- [Cheat Sheet Oracle Day 2](<Pelatihan Pengelolaan Basis Data Enterprise, 6 - 10 Juli 2026/cheat_sheet_oracle_day2_command.md>)
- [Cheat Sheet Oracle Day 3](<Pelatihan Pengelolaan Basis Data Enterprise, 6 - 10 Juli 2026/cheat_sheet_oracle_day3_command.md>)
- [Cheat Sheet Oracle Day 4](<Pelatihan Pengelolaan Basis Data Enterprise, 6 - 10 Juli 2026/cheat_sheet_oracle_day4_command.md>)
- [Cheat Sheet Oracle Day 5](<Pelatihan Pengelolaan Basis Data Enterprise, 6 - 10 Juli 2026/cheat_sheet_oracle_day5_command.md>)

### Write-Up

- [Ringkasan Write-Up](<Write-Up Lab/README.md>)
- [Cheatsheet](<Write-Up Lab/cheatsheet.md>)
- Tiap lab punya versi ringkas dan versi detail

## Publish ke GitHub Pages

Repositori ini sudah disiapkan agar GitHub Actions dapat membangun dan menerbitkan situs ke GitHub Pages.

### Langkah di GitHub

1. Push perubahan ke branch utama repositori.
2. Di GitHub, buka **Settings → Pages**.
3. Pada **Build and deployment**, pilih **Source: GitHub Actions**.
4. Pastikan workflow `pages.yml` berhasil dijalankan.

### Jalankan lokal

```bash
pip install -r requirements-docs.txt
mkdocs serve
```

Lalu buka `http://127.0.0.1:8000`.
