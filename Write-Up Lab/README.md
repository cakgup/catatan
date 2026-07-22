# Write-Up Lab — Versi Ujian Close Book

> Folder ini berisi catatan lab privilege escalation untuk **laboratorium/sistem yang telah memberikan izin pengujian**.

Fokus versi ini adalah **cepat sampai root/flag saat ujian close book**. Bagian backup, cleanup, dan enumerasi panjang tidak dijadikan alur utama. Untuk latihan biasa, cleanup tetap baik dilakukan.

## Daftar Lab

| Lab | Target | Jalur Cepat | Catatan Flag |
|---|---:|---|---|
| [Catalina](01_catalina.md) | `192.168.56.122:8081` | Tomcat Manager → WAR → `tomcat` → writable root cron → SUID bash | Sudah terbukti ada `/root/FLAG.txt` |
| [Portrait](02_portrait.md) | `192.168.56.118:8080` | SQLi → admin → upload PHP → Python capability → root | Cari dulu dengan `find / -type f -iname "*flag*" 2>/dev/null` |
| [Gazette](03_gazette.md) | `192.168.56.121:8000` | SQLi → credential → SSH `editor` → Dirty Pipe → UID 0 | Cari dulu dengan `find / -type f -iname "*flag*" 2>/dev/null` |
| [Statute](04_statute.md) | `192.168.56.120:8080` | Path Traversal → `.env` → SSH `operator` → `sudo vim` → root | Cari dulu dengan `find / -type f -iname "*flag*" 2>/dev/null` |
| [SIPADU](05_sipadu.md) | `192.168.56.13:8081` | LFI → Apache access log poisoning → RCE `www-data` → SUID bash → root | User flag ada di `/home/petugas/flag.txt`, root flag di `/root/flag.txt` |
| [SIMON](06_simon.md) | `192.168.56.12:8347/monitor/` | OS command injection → RCE `www-data` → `sudo gawk` NOPASSWD → root | User flag di `/home/monitor/flag.txt`, root flag di `/root/flag.txt` |
| [SIMASET](07_simaset.md) | `192.168.56.14` | SQLi auth bypass → upload PHP → web shell → Python capability `cap_setuid` → root | User flag di `/home/pengelola/flag.txt`, root flag di `/root/flag.txt` |

## Prinsip Ujian

```text
1. Hafalkan alur, bukan semua output.
2. Validasi user awal dengan id/whoami.
3. Langsung jalankan jalur privilege escalation yang sudah diketahui.
4. Kalau user flag sudah diketahui, ambil sebelum privilege escalation.
5. Setelah root, cari flag dengan find apabila path belum diketahui.
6. Cleanup tidak dimasukkan ke alur utama ujian.
```

## Command Cari Flag

```bash
find / -type f -iname "*flag*" 2>/dev/null
```

Kalau sudah ketemu path-nya:

```bash
cat /path/flag
```

## Mnemonic

```text
Catalina = T-W-C-R-F
Tomcat → WAR → Cron → Root → Find FLAG

Gazette = S-S-D-R-F
SQLi → SSH → DirtyPipe → Root → Find FLAG

Portrait = S-U-C-R-F
SQLi → Upload → Capability → Root → Find FLAG

Statute = T-E-S-V-F
Traversal → Env → SSH → Vim → Find FLAG

SIPADU = L-L-R-S-F
LFI → Log poisoning → RCE → SUID bash → Find FLAG

SIMON = C-W-S-R-F
Command injection → Web RCE → Sudo gawk → Root → Find FLAG

SIMASET = S-U-W-C-F
SQLi → Upload → Web shell → Capability → Find FLAG
```

## Catatan Tambahan

Selain write-up VM, folder ini juga memuat [cheatsheet umum](cheatsheet.md) dan [ringkasan materi](Ringkasan_Materi.md) sebagai referensi umum.

## Format Jawaban Singkat

```text
Celah awal:
Foothold:
User awal:
Privilege escalation:
Bukti root:
Lokasi flag:
Isi flag:
```
