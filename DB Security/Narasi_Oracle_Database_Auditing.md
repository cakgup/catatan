# Narasi Lengkap Fundamental Oracle Database Auditing  
## Panduan Detektif Digital

### Pembukaan — Jembatan dari DBVault ke Database Detective

“Sebelum kita masuk ke materi hari ini, saya ingin menghubungkannya terlebih dahulu dengan materi sebelumnya.

Pada sesi sebelumnya kita sudah belajar mengenai **Oracle Database Vault atau DBVault**. Fokus kita saat itu adalah bagaimana membangun kontrol keamanan pada database. Kita menentukan siapa yang boleh mengakses objek tertentu, siapa yang tidak boleh mengakses, privilege apa yang perlu dibatasi, dan bagaimana kita melindungi data sensitif meskipun seseorang memiliki privilege yang cukup tinggi di database.

Kalau kita menggunakan analogi sebuah gedung, kemarin kita sedang membangun **sistem pengaman gedung**.

Kita memasang pagar.  
Kita menentukan siapa yang mendapatkan kartu akses.  
Kita membatasi ruangan mana yang boleh dimasuki.  
Kita menempatkan petugas keamanan.  
Dan untuk ruangan tertentu yang sangat sensitif, kita memberikan pengamanan tambahan.

Itulah kurang lebih cara berpikir DBVault.

Tetapi sekarang muncul sebuah pertanyaan.

Bagaimana jika seluruh kontrol tersebut sudah kita pasang, tetapi suatu pagi kita menerima laporan:

‘Pak, data customer berubah.’

Misalnya kemarin malam nilai `credit_limit` seorang customer masih 50 juta rupiah, tetapi pagi ini tiba-tiba menjadi 250 juta rupiah.

Sebagai orang yang memahami access control, mungkin pertanyaan pertama kita adalah:

‘Siapa saja yang seharusnya mempunyai hak untuk mengubah data tersebut?’

Pertanyaan itu penting.

Tetapi bagi seorang investigator, pertanyaannya harus dilanjutkan.

**Siapa yang benar-benar melakukan perubahan itu?**

Jam berapa dilakukan?

Menggunakan akun apa?

Koneksinya berasal dari komputer atau host mana?

Menggunakan aplikasi apa?

SQL apa yang dijalankan?

Apakah perintah tersebut berhasil?

Apakah sebelum melakukan perubahan terdapat percobaan login yang gagal?

Apakah user tersebut juga mengakses objek lain?

Dan apakah aktivitas tersebut merupakan aktivitas normal atau merupakan sesuatu yang tidak biasa?

Nah, pertanyaan-pertanyaan seperti inilah yang membawa kita ke materi hari ini.

Kalau kemarin kita bertindak sebagai **security engineer yang memasang pagar**, hari ini kita akan berpindah peran menjadi **database detective yang membaca jejak kejadian**.

Alat utama yang akan kita gunakan adalah **Oracle Unified Auditing**.

Karena itu mindset kita hari ini juga berbeda.

Kita tidak hanya bertanya:

**‘Apakah database sudah dilindungi?’**

Tetapi juga:

**‘Jika sesuatu terjadi pada database, apakah kita memiliki bukti yang cukup untuk mengetahui apa yang sebenarnya terjadi?’**

Itulah tujuan utama pembelajaran kita hari ini.”

---

# Slide 1 — Fundamental Oracle Database Auditing: Panduan Detektif Digital

“Pada slide pertama ini kita mulai dengan satu perubahan sudut pandang.

Pada DBVault, fokus kita berada pada **prevention dan access control**. Kita berusaha mencegah seseorang melakukan tindakan yang tidak diperbolehkan.

Sekarang melalui Database Auditing, fokus kita bergeser kepada **visibility, accountability, evidence, dan investigation**.

Artinya, kita ingin mengetahui aktivitas apa yang benar-benar terjadi di database dan meninggalkan jejak yang dapat diperiksa kembali.

Mari kita gunakan analogi sebuah gedung.

DBVault dapat kita ibaratkan sebagai:

- pagar,
- pintu elektronik,
- access card,
- petugas keamanan,
- dan aturan siapa yang boleh memasuki ruangan tertentu.

Sedangkan auditing dapat kita ibaratkan sebagai:

- CCTV,
- log keluar-masuk,
- rekaman penggunaan kartu akses,
- dan catatan aktivitas di dalam gedung.

Mengapa keduanya dibutuhkan?

Karena sistem kontrol tidak selalu menjawab seluruh pertanyaan setelah sebuah kejadian.

Misalnya kartu akses seorang pegawai memang memiliki hak membuka sebuah ruangan. Tetapi ketika terjadi sesuatu di dalam ruangan tersebut, kita masih perlu mengetahui:

**siapa yang masuk, kapan dia masuk, berapa lama, dan aktivitas apa yang terjadi.**

Database juga seperti itu.

Privilege menjelaskan **apa yang boleh dilakukan seseorang**.

Sedangkan audit trail membantu menjelaskan **apa yang benar-benar dilakukan seseorang**.

Ini adalah perbedaan yang sangat penting.

Sebagai database detective, kita tidak boleh hanya berasumsi berdasarkan privilege.

Kita harus mencari **bukti aktivitas aktual**.

Jadi sepanjang sesi ini saya ingin teman-teman membiasakan satu pola pikir:

> Jangan hanya melihat siapa yang memiliki hak. Lihat siapa yang menggunakan hak tersebut, kapan digunakan, dan untuk melakukan apa.

Itulah fondasi dari database auditing.”

**Transisi:**

“Kalau begitu pertanyaan berikutnya adalah: bagaimana sebuah aktivitas user dapat berubah menjadi sebuah bukti yang bisa kita investigasi?”

---

# Slide 2 — User Activity → Audit Policy → Audit Trail → Investigation

“Slide ini memperlihatkan alur utama bagaimana sebuah aktivitas di database berubah menjadi bukti investigasi.

Semuanya dimulai dari **user activity**.

Seorang user dapat melakukan berbagai aktivitas di database.

Misalnya:

login ke database,

melakukan `SELECT`,

melakukan `INSERT`,

mengubah data menggunakan `UPDATE`,

menghapus data menggunakan `DELETE`,

membuat objek menggunakan `CREATE`,

mengubah struktur objek menggunakan `ALTER`,

atau bahkan mencoba melakukan sesuatu tetapi gagal.

Pertanyaannya:

Apakah setiap aktivitas otomatis kita anggap sebagai bukti yang relevan?

Belum tentu.

Kita perlu menentukan terlebih dahulu aktivitas apa yang ingin kita pantau.

Di sinilah terdapat **Audit Policy**.

Audit Policy dapat kita analogikan sebagai aturan pada sistem CCTV atau alarm.

Kita menentukan:

‘Kalau ada aktivitas seperti ini terhadap objek ini, saya ingin aktivitas tersebut direkam.’

Ketika aktivitas yang sesuai dengan policy terjadi, Oracle Unified Auditing akan menghasilkan rekaman audit.

Rekaman tersebut kemudian dapat kita lihat melalui **`UNIFIED_AUDIT_TRAIL`**.

Jadi alurnya bisa kita sederhanakan:

**User melakukan aktivitas.**

↓  

**Audit Policy menentukan apakah aktivitas tersebut perlu direkam.**

↓  

**Unified Auditing menangkap event tersebut.**

↓  

**Informasi tersimpan dan dapat dilihat melalui audit trail.**

↓  

**Investigator membaca dan menganalisis bukti tersebut.**

Jadi ketika nanti kita melihat `UNIFIED_AUDIT_TRAIL`, jangan menganggapnya hanya sebagai sebuah view Oracle yang penuh kolom.

Bayangkan itu sebagai kumpulan **rekaman CCTV aktivitas database**.

Setiap baris mempunyai cerita.

Ada aktornya.

Ada waktunya.

Ada aktivitasnya.

Ada objeknya.

Ada sumber koneksinya.

Ada hasil berhasil atau gagal.

Dan pada kondisi tertentu ada SQL yang dijalankan.

Tugas kita sebagai investigator adalah mengubah baris-baris tersebut menjadi **kronologi kejadian yang dapat dipahami manusia**.”

**Transisi:**

“Namun sebelum kita mencari rekaman aktivitas, ada satu pertanyaan yang sangat mendasar: kita sedang mencari bukti di database yang mana?”

---

# Slide 3 — Memahami TKP: CDB dan PDB

“Dalam Oracle modern kita mengenal arsitektur **multitenant**, yang terdiri antara lain dari CDB dan PDB.

Untuk mempermudah, kita gunakan analogi apartemen.

Bayangkan **CDB atau Container Database** sebagai sebuah gedung apartemen besar.

Di dalam gedung tersebut terdapat beberapa unit.

Unit-unit itulah yang bisa kita analogikan sebagai **PDB atau Pluggable Database**.

Jadi gedungnya satu, tetapi di dalamnya bisa terdapat beberapa lingkungan database.

Mengapa konsep ini penting dalam investigasi?

Karena seorang investigator harus mengetahui **TKP yang tepat**.

Bayangkan polisi menerima laporan pencurian tetapi mencari rekaman CCTV di gedung sebelah.

CCTV-nya berfungsi.

Petugasnya kompeten.

Tetapi barang bukti tidak ditemukan karena lokasinya salah.

Dalam database juga demikian.

Aktivitas yang sedang kita investigasi mungkin terjadi pada PDB tertentu.

Jika kita memeriksa container yang salah, kita dapat memperoleh hasil kosong atau informasi yang tidak sesuai dengan kasus.

Karena itu sebelum melakukan investigasi, kita perlu memastikan konteks container tempat kita bekerja.

Inilah mindset investigator:

**Sebelum mencari siapa pelakunya, pastikan terlebih dahulu TKP-nya.**

Dalam praktik laboratorium nanti, jangan langsung panik ketika query audit tidak menemukan data.

Periksa dahulu:

Apakah saya terkoneksi ke database yang benar?

Apakah saya berada di PDB yang benar?

Apakah user dan objek yang diperiksa memang berada di container tersebut?

Hal-hal sederhana seperti ini sering menjadi pembeda antara investigasi yang sistematis dengan investigasi yang sekadar mencoba query secara acak.”

**Transisi:**

“Setelah mengetahui TKP, sekarang kita perlu membedakan siapa yang melakukan aktivitas dan siapa yang bertugas memeriksa aktivitas tersebut.”

---

# Slide 4 — The Suspect vs The Detective

“Dalam laboratorium ini kita akan memisahkan dua peran.

Peran pertama adalah **The Suspect**.

Misalnya kita menggunakan user `AUDIT_USER`.

User tersebut akan melakukan sejumlah aktivitas pada database, misalnya membaca data, melakukan perubahan, atau aktivitas lainnya.

Peran kedua adalah **The Detective**.

Misalnya kita menggunakan user `LAB_AUDITOR`.

User ini tidak kita gunakan untuk menjadi pelaku aktivitas. Tugasnya adalah membaca rekaman audit dan melakukan investigasi.

Mengapa perlu dipisahkan?

Karena dalam keamanan informasi terdapat prinsip **segregation of duties**, atau pemisahan fungsi dan tanggung jawab.

Sederhananya, orang yang melakukan sebuah transaksi sebaiknya bukan satu-satunya orang yang memiliki kendali terhadap proses pemeriksaan transaksi tersebut.

Bayangkan sebuah toko.

Kasir menerima pembayaran.

Tetapi apakah sebaiknya kasir itu juga menjadi satu-satunya auditor yang memeriksa seluruh transaksi dirinya sendiri?

Tentu tidak ideal.

Konsep yang sama kita terapkan di database.

User operasional melakukan aktivitas.

Auditor atau investigator membaca bukti aktivitas.

Untuk kepentingan tersebut Oracle menyediakan privilege yang berkaitan dengan auditing, salah satunya `AUDIT_VIEWER`, sehingga investigator dapat memperoleh akses yang diperlukan untuk melihat informasi audit tanpa harus diberikan privilege database yang tidak relevan secara berlebihan.

Ini juga mengajarkan satu prinsip keamanan penting:

**berikan privilege sesuai kebutuhan tugas.**

Tidak semua investigator harus menjadi DBA penuh.

Tidak semua DBA harus mempunyai kewenangan untuk mengubah seluruh mekanisme audit.

Semakin jelas pemisahan perannya, semakin baik kualitas governance dan accountability-nya.

Mulai dari slide ini, bayangkan kita mempunyai dua karakter dalam cerita:

`AUDIT_USER` adalah orang yang meninggalkan jejak.

`LAB_AUDITOR` adalah detektif yang membaca jejak tersebut.”

**Transisi:**

“Sekarang kita sudah mempunyai pelaku dan detektif. Pertanyaan berikutnya: bagaimana kita memasang sensor agar aktivitas tertentu meninggalkan jejak?”

---

# Slide 5 — Audit Policy sebagai Laser Tripwire

“Sekarang bayangkan sebuah museum.

Di museum tersebut ada puluhan ruangan.

Apakah setiap sudut harus diberikan tingkat pengamanan yang sama?

Tidak selalu.

Ada area umum.

Ada ruang penyimpanan.

Ada ruang yang menyimpan benda bernilai tinggi.

Untuk benda yang sangat sensitif, mungkin kita memasang **laser tripwire**.

Kalau seseorang melewati atau menyentuh area tertentu, sistem langsung mencatat kejadian.

Konsep tersebut dapat kita gunakan untuk memahami **Audit Policy**.

Misalnya kita mempunyai tabel:

`AUDIT_USER.CUSTOMERS`

Kita menilai tabel tersebut penting karena berisi informasi customer.

Kemudian kita membuat policy untuk merekam aktivitas seperti:

`SELECT`

`INSERT`

`UPDATE`

dan `DELETE`

terhadap tabel tersebut.

Artinya kita sedang berkata kepada Oracle:

‘Kalau aktivitas-aktivitas tersebut terjadi terhadap objek ini, saya ingin ada jejak auditnya.’

Inilah fungsi `CREATE AUDIT POLICY`.

Kita sedang **mendefinisikan aturan sensor**.

Perhatikan kata ‘mendefinisikan’.

Karena di sinilah nanti terdapat jebakan konsep yang cukup sering terjadi.

Membuat policy belum tentu berarti policy tersebut sedang aktif.

Ini sama seperti kita membeli CCTV, memasangnya di dinding, menghubungkan kabelnya, tetapi belum mengaktifkan perekamannya.

Secara fisik kamera sudah ada.

Tetapi apakah kejadian malam ini pasti terekam?

Belum tentu.

Karena itu dalam auditing kita harus membedakan dua hal:

**policy tersedia**, dan

**policy aktif digunakan.**”

**Transisi:**

“Nah, perbedaan antara ‘sudah dibuat’ dengan ‘sudah aktif’ inilah yang kita bahas berikutnya.”

---

# Slide 6 — Defined Policy vs Enabled Policy

“Ini salah satu bagian yang harus benar-benar dipahami.

Oracle menyediakan informasi mengenai policy yang telah kita definisikan dan policy yang benar-benar sedang diterapkan.

Secara sederhana:

**`AUDIT_UNIFIED_POLICIES`** membantu kita melihat definisi policy yang tersedia.

Sedangkan:

**`AUDIT_UNIFIED_ENABLED_POLICIES`** membantu kita melihat policy yang sedang aktif.

Kita kembali ke analogi CCTV.

`AUDIT_UNIFIED_POLICIES` menjawab:

**‘CCTV apa saja yang sudah dipasang?’**

Sedangkan `AUDIT_UNIFIED_ENABLED_POLICIES` menjawab:

**‘CCTV mana yang saat ini benar-benar aktif melakukan pengawasan?’**

Perbedaan ini sangat penting dalam investigasi.

Misalnya terjadi perubahan data pada pukul 02.00 dini hari.

Kemudian seorang administrator berkata:

‘Tenang, kita punya audit policy untuk tabel tersebut.’

Sebagai investigator, kita belum boleh berhenti di situ.

Pertanyaan berikutnya adalah:

**‘Apakah policy tersebut aktif ketika kejadian berlangsung?’**

Kalau policy baru diaktifkan pukul 08.00 pagi, maka keberadaan policy tersebut tidak membuktikan bahwa aktivitas pukul 02.00 sudah direkam.

Jadi kita perlu memahami **status konfigurasi pada saat kejadian**, bukan sekadar konfigurasi yang terlihat sekarang.

Secara konsep kita menyebut prosesnya sebagai mengaktifkan atau *enable* policy. Dalam Unified Auditing, penerapannya dilakukan melalui mekanisme `AUDIT POLICY ...`; sedangkan `NOAUDIT POLICY ...` digunakan ketika policy tidak lagi diterapkan.

Pesan utamanya bukan menghafal command terlebih dahulu.

Pesan utamanya adalah:

> **Defined tidak sama dengan enabled.**

Sebuah kontrol yang tersedia belum tentu sebuah kontrol yang sedang bekerja.”

**Transisi:**

“Kalau sensor sudah aktif dan aktivitas yang sesuai terjadi, ke mana rekamannya pergi? Sekarang kita masuk ke ruang barang bukti.”

---

# Slide 7 — UNIFIED_AUDIT_TRAIL: The Evidence Room

“Di sinilah kita bertemu dengan salah satu komponen terpenting dalam materi hari ini:

**`UNIFIED_AUDIT_TRAIL`.**

Saya ingin teman-teman membayangkannya sebagai **evidence room atau ruang barang bukti**.

Ketika aktivitas berhasil ditangkap mekanisme audit, informasi tersebut dapat kita lihat dari audit trail.

Di dalamnya terdapat berbagai elemen yang sangat berguna untuk investigasi.

Misalnya:

kapan kejadian berlangsung,

siapa database user-nya,

aktivitas apa yang dilakukan,

objek apa yang menjadi target,

dari host mana aktivitas berasal,

program apa yang digunakan,

SQL apa yang dijalankan apabila informasi tersebut tersedia,

policy apa yang terkait,

dan apakah aktivitas tersebut berhasil atau mengalami error.

Sekarang kita mulai meninggalkan mindset administrator murni.

Administrator biasanya bertanya:

‘Konfigurasinya benar atau tidak?’

Investigator bertanya:

‘Berdasarkan bukti yang tersedia, apa yang sebenarnya terjadi?’

Ini merupakan perubahan cara berpikir yang penting.

Misalnya terdapat laporan:

‘Data customer berubah.’

Kita jangan langsung menyimpulkan:

‘Pasti user A.’

Kita masuk ke evidence room.

Kita mencari aktivitas terkait tabel tersebut.

Kita mempersempit waktu.

Kita melihat user.

Kita melihat action.

Kita melihat SQL.

Kita melihat sumber koneksi.

Baru setelah itu kita mulai menyusun kronologi.

Dengan cara tersebut kesimpulan kita lebih berbasis bukti dibandingkan asumsi.”

**Transisi:**

“Dan jangan lupa: evidence bukan hanya aktivitas yang berhasil. Aktivitas yang gagal juga bisa menjadi potongan puzzle yang sangat penting.”

---

# Slide 8 — Failed Login Is Still Evidence

“Sekarang kita ambil contoh yang sangat sederhana.

Seseorang mencoba login sebagai `AUDIT_USER`, tetapi password yang digunakan salah.

Login tersebut gagal.

Pertanyaannya:

Apakah karena gagal berarti tidak penting?

Tidak.

Bagi investigator, **failed activity tetap merupakan activity**.

Bahkan dalam beberapa kasus, pola aktivitas gagal justru lebih menarik dibandingkan aktivitas berhasil.

Di audit trail kita dapat menemukan action seperti `LOGON` dan informasi `RETURN_CODE`.

Secara umum, return code `0` menunjukkan bahwa operasi berhasil.

Nilai selain `0` menunjukkan adanya kondisi error tertentu.

Misalnya Oracle error `ORA-01017` berkaitan dengan username/password yang tidak valid.

Sekarang bayangkan kita menemukan satu failed login.

Apakah itu serangan?

Belum tentu.

User mungkin salah mengetik password.

Sekarang bayangkan terdapat 50 failed login dalam waktu sangat singkat.

Apakah itu pasti serangan?

Kita juga belum boleh langsung menyimpulkan.

Mungkin terdapat aplikasi dengan credential lama.

Mungkin script otomatis belum diperbarui.

Mungkin terdapat konfigurasi connection pool yang salah.

Atau memang terdapat percobaan unauthorized access.

Di sinilah kita belajar prinsip yang sangat penting:

**Audit memberikan fakta. Investigator memberikan konteks.**

Kita tidak boleh membuat kesimpulan hanya berdasarkan satu event.

Yang kita cari adalah **pola dan korelasi**.

Sebagai contoh:

ada banyak login gagal,

kemudian satu login berhasil,

setelah itu terdapat akses terhadap tabel sensitif,

kemudian terjadi `UPDATE`.

Nah, apabila event-event tersebut terjadi berdekatan dan berasal dari sumber yang sama, ceritanya mulai menjadi jauh lebih menarik.

Artinya database investigation bukan hanya membaca satu baris.

Kita sedang mencoba menyusun **timeline**.”

**Transisi:**

“Agar tidak tenggelam dalam puluhan kolom audit trail, kita membutuhkan kerangka berpikir sederhana. Kita gunakan 5W + 1H.”

---

# Slide 9 — 5W + 1H Synthesis Matrix

“Ketika melihat audit trail untuk pertama kali, jumlah kolomnya bisa membuat kita bingung.

Karena itu jangan mulai dengan menghafal semua kolom.

Mulailah dari pertanyaan investigasi.

Kita gunakan **5W + 1H**.

### Who — Siapa?

Pertama kita ingin mengetahui:

**siapa aktornya?**

Salah satu informasi penting adalah `DBUSERNAME`.

Tetapi sebagai investigator, jangan hanya berhenti pada username.

Username adalah identitas akun database.

Belum tentu otomatis sama dengan identitas manusia di belakang keyboard.

Ini menjadi alasan mengapa konteks tambahan nantinya penting.

### What — Melakukan apa?

Kita melihat `ACTION_NAME`.

Apakah user melakukan:

`LOGON`?

`SELECT`?

`INSERT`?

`UPDATE`?

`DELETE`?

atau aktivitas lainnya?

Ini membantu kita memahami jenis tindakan.

### Where — Terhadap apa?

Kita melihat konteks objek, misalnya:

`OBJECT_SCHEMA`

dan

`OBJECT_NAME`.

Jadi kita dapat mengetahui bukan hanya ‘ada UPDATE’, tetapi UPDATE terhadap objek apa.

### When — Kapan?

Kita melihat informasi seperti `EVENT_TIMESTAMP`.

Timestamp sangat penting karena investigasi pada dasarnya adalah proses merekonstruksi urutan kejadian.

### From Where — Berasal dari mana?

Kita dapat menggunakan informasi seperti `USERHOST` dan informasi client lainnya.

Ini membantu menjawab:

aktivitas berasal dari host mana?

Apakah host tersebut memang biasa digunakan?

### How — Bagaimana dilakukan?

Kita dapat memeriksa `SQL_TEXT`.

Ini salah satu bagian paling menarik karena kita bisa melihat perintah yang berkaitan dengan aktivitas tersebut.

Misalnya sebelumnya kita hanya mengetahui:

`ACTION_NAME = UPDATE`.

Setelah membaca SQL, kita mengetahui:

`UPDATE CUSTOMERS SET CREDIT_LIMIT = ...`

Sekarang informasi teknis tadi sudah mulai berubah menjadi cerita.

Misalnya:

> Pada pukul 02.13, akun `AUDIT_USER` dari host tertentu melakukan UPDATE terhadap tabel `CUSTOMERS` dengan SQL tertentu dan operasi tersebut berhasil.

Itulah hasil sintesis.

**Data mentah berubah menjadi informasi investigatif.**

Dan kemampuan itulah yang sebenarnya ingin kita bangun melalui materi ini.”

**Transisi:**

“Sekarang setelah memahami jenis bukti yang ingin kita cari, kita perlu menentukan seberapa luas sensor audit diterapkan.”

---

# Slide 10 — Audit untuk Semua User atau User Tertentu

“Dalam auditing selalu terdapat pertanyaan mengenai **scope atau cakupan**.

Apakah seluruh aktivitas seluruh user harus kita audit dengan tingkat detail yang sama?

Jawabannya tergantung kebutuhan.

Kita bisa mempunyai policy yang diterapkan secara lebih luas.

Tetapi kita juga dapat menerapkan policy kepada user tertentu, misalnya menggunakan pendekatan `BY audit_user`.

Mengapa scope penting?

Karena auditing juga harus didesain.

Misalnya kita mempunyai beberapa kategori akun:

akun administrator,

akun aplikasi,

akun user biasa,

service account,

dan akun yang memiliki akses kepada objek sensitif.

Tidak seluruh akun selalu mempunyai profil risiko yang sama.

Karena itu desain audit policy sebaiknya mempertimbangkan:

**nilai aset yang dilindungi,**

**jenis aktivitas yang dianggap penting,**

**privilege user,**

dan **kebutuhan monitoring maupun investigasi.**

Misalnya perubahan terhadap tabel customer mungkin dianggap lebih sensitif dibandingkan pembacaan terhadap tabel referensi yang bersifat publik.

Demikian juga aktivitas dari akun privileged mungkin membutuhkan perhatian lebih tinggi dibandingkan user biasa.

Tetapi kita juga harus hati-hati.

Jangan karena ingin memperoleh bukti sebanyak mungkin kemudian seluruh aktivitas direkam tanpa desain.

Data audit yang terlalu besar dapat membuat investigator kesulitan menemukan sinyal penting di tengah noise.

Jadi tujuan kita bukan:

**‘record everything without thinking.’**

Tujuannya adalah:

**‘record what matters based on risk and investigative requirements.’**

Inilah mengapa pembuatan audit policy sebenarnya juga merupakan bagian dari security architecture.”

**Transisi:**

“Setelah policy menangkap aktivitas, sekarang kita mulai melihat bukti yang lebih spesifik. Salah satu bukti yang sangat membantu adalah SQL yang dijalankan.”

---

# Slide 11 — Evidence Report dan SQL_TEXT

“Bayangkan kita membuka audit trail dan menemukan:

`ACTION_NAME = UPDATE`.

Apakah informasi tersebut berguna?

Tentu.

Tetapi apakah sudah cukup?

Belum.

Kita masih ingin mengetahui:

**UPDATE apa?**

Di sinilah `SQL_TEXT` menjadi sangat berharga dalam rekonstruksi aktivitas.

Misalnya kita menemukan perintah seperti:

`UPDATE customers`  
`SET credit_limit = 250000000`  
`WHERE customer_id = 2;`

Sekarang tingkat pemahaman kita meningkat sangat jauh.

Sebelumnya kita hanya tahu:

‘Ada aktivitas UPDATE.’

Sekarang kita dapat mengatakan:

‘Ada perintah yang mengubah `credit_limit` customer dengan ID 2 menjadi 250 juta.’

Kemudian kita gabungkan dengan field lain.

Siapa yang menjalankan?

Kapan?

Dari host mana?

Apakah berhasil?

Objek mana yang ditargetkan?

Setelah digabung, kita mungkin memperoleh kronologi:

> Pada waktu tertentu, akun `AUDIT_USER` terkoneksi dari host tertentu kemudian menjalankan UPDATE terhadap tabel `CUSTOMERS`, mengubah nilai `CREDIT_LIMIT` customer tertentu, dan statement tersebut berhasil dieksekusi.

Inilah perbedaan antara **monitoring** dan **investigation**.

Monitoring mungkin hanya mengatakan:

‘Terjadi 20 UPDATE hari ini.’

Investigation bertanya:

‘UPDATE yang mana, dilakukan siapa, terhadap record apa, pada pukul berapa, dan bagaimana rangkaian kejadiannya?’

Tetapi ada satu prinsip penting.

Keberadaan SQL tidak secara otomatis menjelaskan **motif**.

Audit dapat menunjukkan seseorang melakukan UPDATE.

Audit tidak otomatis mengetahui apakah orang tersebut:

sengaja melakukan fraud,

melakukan maintenance,

mengikuti instruksi resmi,

atau salah memasukkan data.

Karena itu audit trail adalah **technical evidence** yang perlu dikorelasikan dengan konteks lain apabila kasus berkembang menjadi investigasi yang lebih luas.

Ini juga alasan mengapa seorang investigator harus membedakan:

**fakta,**

**indikasi,**

dan **kesimpulan.**

Fakta:

‘SQL tersebut dijalankan oleh akun ini.’

Indikasi:

‘Aktivitas terjadi di luar pola normal.’

Kesimpulan:

baru dapat diberikan setelah bukti yang cukup dianalisis.”

**Transisi:**

“Sekarang kita sudah memahami bagaimana policy menghasilkan bukti. Berikutnya kita melihat bahwa sebuah audit policy juga mempunyai siklus hidup.”

---

# Slide 12 — Lifecycle Audit Policy

“Audit policy bukan sesuatu yang dibuat kemudian dilupakan.

Ia mempunyai **lifecycle**.

Tahap pertama adalah **CREATE**.

Pada tahap ini kita mendefinisikan policy.

Kita menentukan aktivitas apa yang ingin dipantau dan terhadap objek apa.

Kemudian policy perlu **diterapkan atau diaktifkan** sehingga aktivitas yang sesuai mulai menghasilkan rekaman audit.

Setelah policy aktif, event yang memenuhi kriteria dapat menghasilkan **audit records**.

Kalau suatu saat policy tersebut tidak lagi ingin diterapkan sementara, kita dapat menghentikan penerapannya tanpa harus langsung menghapus definisinya.

Secara konsep ini seperti **mematikan CCTV sementara**.

CCTV-nya masih terpasang.

Konfigurasinya masih ada.

Nanti dapat digunakan kembali.

Berbeda dengan **DROP**.

Drop berarti definisi policy tersebut dihapus.

Analoginya bukan sekadar mematikan CCTV.

Kita mencopot perangkatnya dari sistem.

Mengapa lifecycle ini penting?

Karena konfigurasi audit perlu dikelola.

Misalnya organisasi membuat policy sementara untuk investigasi tertentu.

Setelah kebutuhan tersebut selesai, administrator perlu memutuskan:

apakah policy tetap dibutuhkan,

dinonaktifkan,

dimodifikasi,

atau memang dihapus.

Hal lain yang perlu diperhatikan adalah perubahan policy itu sendiri juga merupakan bagian dari governance.

Dalam investigasi nyata, kita perlu memahami:

**policy apa yang berlaku ketika kejadian berlangsung?**

Jangan hanya melihat keadaan sistem saat ini.

Karena konfigurasi hari ini belum tentu sama dengan konfigurasi pada saat insiden terjadi.

Ini kembali kepada prinsip digital investigation:

**context and timeline matter.**”

**Transisi:**

“Setelah data audit mulai banyak, tantangannya berubah. Masalahnya bukan lagi kekurangan data, tetapi bagaimana menemukan aktivitas penting dari data dalam jumlah besar.”

---

# Slide 13 — Detective’s Dashboard: Melihat Pola Aktivitas

“Bayangkan audit trail kita memiliki satu juta baris.

Apakah kita akan membaca dari baris pertama sampai satu juta?

Tentu tidak.

Seorang investigator membutuhkan cara untuk melihat **big picture terlebih dahulu**.

Di sinilah agregasi dan dashboard membantu.

Contohnya kita dapat mengelompokkan aktivitas berdasarkan `ACTION_NAME`.

Kita mungkin menemukan:

berapa banyak `LOGON`,

berapa banyak `SELECT`,

berapa banyak `UPDATE`,

berapa banyak `DELETE`,

dan sebagainya.

Kemudian kita dapat menggabungkannya dengan `RETURN_CODE`.

Dengan begitu kita memperoleh gambaran:

berapa aktivitas yang berhasil,

berapa aktivitas yang gagal.

Dashboard seperti ini bukan akhir investigasi.

Ia adalah **alat navigasi**.

Bayangkan kita melihat:

biasanya failed login hanya 5–10 kali per hari.

Hari ini tiba-tiba menjadi 500 kali.

Apa artinya?

Kita belum langsung menyimpulkan serangan.

Tetapi kita menemukan **anomaly yang layak diperiksa**.

Kita kemudian melakukan drill down.

Akun mana yang mengalami kegagalan?

Waktunya kapan?

Apakah terjadi dalam interval yang sangat rapat?

Dari host mana?

Setelah failed login tersebut, apakah ada successful login?

Setelah successful login, aktivitas apa yang dilakukan?

Inilah cara berpikir investigator.

**Overview → anomaly → drill down → correlation → timeline.**

Jadi dashboard bukan sekadar membuat chart menjadi cantik.

Dashboard berfungsi membantu kita menjawab:

> ‘Di antara sekian banyak aktivitas ini, bagian mana yang layak saya investigasi lebih lanjut?’”

**Transisi:**

“Setelah menemukan aktivitas yang menarik, kita belum selesai. Sekarang kita harus menambahkan konteks.”

---

# Slide 14 — Detective’s Dashboard: Menambahkan Konteks

“Dalam investigasi keamanan, sebuah event hampir tidak pernah cukup kalau berdiri sendiri.

Kita membutuhkan **context**.

Pertama adalah konteks **waktu**.

Misalnya akun pegawai melakukan login pukul 10 pagi.

Apakah itu aneh?

Mungkin tidak.

Sekarang akun yang sama melakukan login pukul 02.13 dini hari.

Apakah itu pasti serangan?

Belum tentu.

Bisa jadi pegawai memang sedang melakukan pekerjaan malam.

Bisa jadi ada proses otomatis.

Bisa jadi ada maintenance.

Tetapi waktu tersebut merupakan konteks yang layak diperiksa.

Kemudian kita tambahkan konteks **host**.

Dari komputer mana aktivitas berasal?

Apakah host tersebut biasa digunakan akun itu?

Kemudian konteks **client program**.

Misalnya selama ini sebuah akun aplikasi hanya terhubung melalui application server.

Tiba-tiba akun yang sama terlihat digunakan melalui tool database client.

Apakah otomatis merupakan pelanggaran?

Belum tentu.

Tetapi kembali lagi: itu adalah **indikator yang perlu dikorelasikan**.

Kemudian kita gabungkan dengan:

user,

action,

timestamp,

object,

SQL text,

return code,

host,

dan client program.

Semakin banyak konteks yang konsisten, semakin jelas rekonstruksi kejadian.

Contohnya:

ada failed login berkali-kali,

dari host yang tidak biasa,

pukul dua pagi,

kemudian ada successful login,

setelah itu terdapat SELECT terhadap tabel sensitif,

kemudian UPDATE,

kemudian aktivitas berhenti.

Sekarang kita sudah tidak lagi melihat baris-baris database secara terpisah.

Kita sudah mulai melihat **storyline**.

Tetapi tetap ingat:

**indikator bukan otomatis bukti motif.**

Tugas investigator adalah menyajikan fakta dan korelasi secara objektif.

Jangan melompat dari:

‘aktivitas terjadi pukul dua pagi’

menjadi:

‘pasti hacker.’

Itu bukan investigasi yang baik.

Investigasi yang baik mengatakan:

‘Aktivitas terjadi pukul 02.13, berasal dari host X, menggunakan akun Y, menggunakan client Z, kemudian menjalankan SQL berikut. Pola ini berbeda dari baseline yang biasanya ditemukan.’

Setelah itu, bukti tersebut dapat dikorelasikan dengan sumber lain apabila diperlukan.”

**Transisi:**

“Sekarang mari kita satukan seluruh konsep dari awal hingga akhir menjadi satu ekosistem investigasi.”

---

# Slide 15 — Kesimpulan: Ekosistem Oracle Database Auditing

“Kalau seluruh materi hari ini kita tarik menjadi satu gambaran besar, alurnya sebenarnya sangat sistematis.

Pertama ada **user activity**.

Seseorang atau sebuah aplikasi melakukan aktivitas di database.

Kemudian ada **Audit Policy**.

Policy menentukan aktivitas apa yang dianggap penting untuk direkam.

Ketika policy diterapkan dan aktivitas yang sesuai terjadi, **Unified Auditing** menghasilkan jejak.

Jejak tersebut kemudian dapat kita lihat melalui **`UNIFIED_AUDIT_TRAIL`**.

Setelah bukti tersedia, kita berpindah ke tahap **investigation**.

Dan untuk melakukan investigasi, kita menggunakan pertanyaan sederhana:

### Who?
Siapa yang melakukan aktivitas?

### What?
Apa yang dilakukan?

### Where?
Objek database mana yang menjadi target?

### When?
Kapan aktivitas terjadi?

### From where?
Dari mana koneksi berasal?

### How?
Perintah apa yang digunakan?

Kemudian kita tambahkan satu dimensi lagi:

### Result?
Apakah aktivitas tersebut berhasil atau gagal?

Setelah itu kita tambahkan konteks.

Apakah waktunya normal?

Apakah host-nya biasa digunakan?

Apakah client program-nya sesuai pola?

Apakah terdapat aktivitas lain sebelum dan sesudahnya?

Dari sinilah kita memperoleh **timeline dan narrative of events**.

Jadi sekarang kita dapat melihat hubungan yang sangat jelas antara DBVault dan Unified Auditing.

**DBVault berorientasi pada kontrol.**

Ia membantu menentukan siapa yang boleh melakukan apa.

**Unified Auditing berorientasi pada visibility dan evidence.**

Ia membantu kita mengetahui aktivitas apa yang benar-benar terjadi dan menyediakan jejak yang dapat diperiksa.

Keduanya tidak saling menggantikan.

Keduanya saling melengkapi.

Saya kembali menggunakan analogi gedung.

**DBVault adalah pagar.**

**DBVault adalah kartu akses.**

**DBVault adalah petugas keamanan yang membatasi siapa yang dapat memasuki sebuah ruangan.**

Sedangkan:

**Unified Auditing adalah CCTV.**

**Unified Auditing adalah log penggunaan access card.**

**Unified Auditing adalah catatan kejadian yang dapat kita putar kembali ketika sesuatu terjadi.**

Dan kita sebagai auditor atau investigator adalah orang yang membaca seluruh bukti itu.

Karena itu, kalau ada satu kalimat yang ingin saya tinggalkan dari materi hari ini, kalimatnya adalah:

> **Security bukan hanya memastikan seseorang tidak boleh melakukan sesuatu. Security juga memastikan bahwa ketika sesuatu terjadi, kita memiliki bukti yang cukup untuk menjelaskan apa yang sebenarnya terjadi.**

Kemarin kita belajar membangun pagar.

Hari ini kita belajar membaca jejak.

Besok ketika menghadapi sebuah kasus, jangan langsung bertanya:

‘Siapa yang salah?’

Mulailah dengan pertanyaan:

**‘Apa yang dikatakan oleh buktinya?’**

Itulah mindset seorang **Database Detective**.”

---

# Penutup Sesi / Jembatan ke Praktikum

“Setelah memahami konsepnya, berikutnya kita tidak akan berhenti pada teori.

Kita akan mencoba sendiri bagaimana sebuah aktivitas menghasilkan jejak.

Kita akan mempunyai user yang berperan sebagai pelaku aktivitas.

Kita akan mempunyai auditor yang berperan sebagai database detective.

Kita akan membuat audit policy.

Kita akan memastikan policy tersebut benar-benar diterapkan.

Kemudian kita akan menghasilkan beberapa aktivitas:

ada aktivitas yang berhasil,

ada aktivitas yang gagal,

ada pembacaan data,

dan ada perubahan data.

Setelah itu kita berpindah ke sisi investigator.

Kita tidak akan diberi cerita lengkap.

Kita akan membaca `UNIFIED_AUDIT_TRAIL` dan mencoba menjawab sendiri:

**Who did it?**

**What did they do?**

**When did it happen?**

**Where did it come from?**

**Which object was affected?**

**What SQL was executed?**

**Did it succeed or fail?**

Dan pada akhirnya tugas kita bukan sekadar menghasilkan output query.

Tugas kita adalah mengubah hasil query tersebut menjadi sebuah **kronologi kejadian yang masuk akal dan berbasis bukti**.

Karena itulah perbedaan antara orang yang sekadar bisa menjalankan SQL dengan seorang **database investigator**.

Sekarang mari kita masuk ke lab dan mulai mencari jejak.”
