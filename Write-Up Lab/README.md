# Write-Up Lab — Versi Ujian Close Book

> Folder ini berisi catatan lab privilege escalation untuk **laboratorium/sistem yang telah memberikan izin pengujian**.

Fokus versi ini adalah **cepat sampai root/flag saat ujian close book**. Bagian backup, cleanup, dan enumerasi panjang tidak dijadikan alur utama. Untuk latihan biasa, cleanup tetap baik dilakukan.

## Daftar Lab

| Lab | Target | Jalur Cepat | Catatan Flag |
|---|---:|---|---|
| Catalina | `192.168.56.122:8081` | Tomcat Manager → WAR → `tomcat` → writable root cron → SUID bash | Sudah terbukti ada `/root/FLAG.txt` |
| Gazette | `192.168.56.121:8000` | SQLi → credential → SSH `editor` → Dirty Pipe → UID 0 | Cari dulu dengan `find / -type f -iname "*flag*" 2>/dev/null` |
| Portrait | `192.168.56.118:8080` | SQLi → admin → upload PHP → Python capability → root | Cari dulu dengan `find / -type f -iname "*flag*" 2>/dev/null` |
| Statute | `192.168.56.120:8080` | Path Traversal → `.env` → SSH `operator` → `sudo vim` → root | Cari dulu dengan `find / -type f -iname "*flag*" 2>/dev/null` |

## Prinsip Ujian

```text
1. Hafalkan alur, bukan semua output.
2. Validasi user awal dengan id/whoami.
3. Langsung jalankan jalur privilege escalation yang sudah diketahui.
4. Setelah root, cari flag dengan find apabila path belum diketahui.
5. Cleanup tidak dimasukkan ke alur utama ujian.
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
```

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
