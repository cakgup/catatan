# Write-Up Lab — Panduan Belajar Ujian Close Book

Folder ini berisi catatan privilege escalation untuk **laboratorium yang telah memberikan izin pengujian**.

Semua write-up menggunakan pola yang sama agar peserta tidak perlu menghafal bentuk dokumen yang berbeda-beda.

## Daftar Lab

| Lab | Jalur Serangan | Mnemonic |
|---|---|---|
| Catalina | Tomcat Manager → WAR → RCE → writable root cron → root | `R-C-W-C-R` |
| Gazette | SQLi → credential → SSH → Dirty Pipe → root | `S-D-S-K-P-R` |
| Portrait | SQLi → admin → upload PHP → capability Python → root | `R-S-U-C-R` |
| Statute | Path Traversal → `.env` → SSH → `sudo vim` → root | `R-D-T-S-V-R` |

## Pola Baku Setiap Write-Up

1. **Cara menggunakan catatan**
2. **Peta serangan**
3. **Mnemonic**
4. **Checkpoint ujian**
5. **Fase serangan secara berurutan**
6. **Troubleshooting inti**
7. **Cleanup**
8. **Cheat sheet 60 detik**
9. **Checklist ujian**
10. **Kalimat hafalan**
11. **Lampiran kode**, apabila ada kode panjang

Di setiap fase, fokus pada empat pertanyaan:

```text
Apa tujuannya?
Command apa yang dijalankan?
Output apa yang dicari?
Mengapa output itu penting?
```

## Metode Belajar Tiga Putaran

### Putaran 1 — Hafalkan Alur

Baca hanya:

- peta serangan;
- mnemonic;
- kalimat hafalan.

Targetnya adalah mampu menceritakan jalur serangan tanpa melihat catatan.

### Putaran 2 — Hafalkan Checkpoint

Untuk setiap fase, ingat satu indikator utama.

Contoh:

```text
401 Tomcat Manager
→ credential valid
→ uid tomcat
→ cron root
→ script group-writable
→ euid 0
```

### Putaran 3 — Latihan Command

Ketik ulang command dari bagian **Cheat Sheet 60 Detik** tanpa menyalin.

Jangan menghafal seluruh output. Hafalkan hanya bagian yang membuktikan bahwa fase tersebut berhasil.

## Aturan Saat Ujian

```text
1. Recon terlebih dahulu.
2. Jangan menebak jalur exploit tanpa bukti.
3. Catat user saat ini dengan id dan whoami.
4. Cari jalur privilege escalation yang paling sederhana.
5. Verifikasi root dengan id dan whoami.
6. Pulihkan perubahan dan hapus artefak pengujian.
```

## Format Ringkasan Jawaban

Gunakan pola berikut ketika diminta menjelaskan hasil pengujian:

```text
Celah awal:
Foothold:
User awal:
Temuan privilege escalation:
Cara memperoleh root:
Bukti root:
Cleanup:
```
