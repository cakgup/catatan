# Pembahasan Detail 4 Lab Pentest

> Untuk pembelajaran pada lab/CTF/sistem yang telah memberikan izin pengujian.

## File

```text
01_catalina_pembahasan_detail_v2.md
02_portrait_pembahasan_detail_v2.md
03_gazette_pembahasan_detail_v2.md
04_statute_pembahasan_detail_v2.md
```

## Cara Belajar Peserta Baru

```text
1. Baca "Gambaran Besar" dulu.
2. Jalankan fase satu per satu.
3. Jangan lanjut sebelum indikator fase muncul.
4. Catat output penting: user awal, path rentan, dan bukti root.
5. Setelah root, cari flag dengan find.
```

## Command Universal Setelah Root

```bash
find / -type f -iname "*flag*" 2>/dev/null
cat /PATH/FLAG
```
