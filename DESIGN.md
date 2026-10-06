# Street Coffee — Design Spec v2 (Revamp + Social + Monetisasi)

> **Tagline:** "Temukan kopi di skenamu."
> **Platform:** Flutter (Android & iOS), portrait, frame acuan **390 × 844**
> **Bahasa UI:** Indonesia santai/gaul khas Gen Z (campur Inggris seperlunya: "Drop", "Feed", "Featured")
> **Tema:** Dark only
> **File desain:** [`design/street_coffee.pen`](design/street_coffee.pen) (pen.dev)

v1 adalah direktori kedai + order via WhatsApp. v2 menambah **lapisan sosial** (Drop, Feed, Coffee Passport, badge, share ke IG Story) dan **dua sumber pendapatan**: **Street Pass** (user) dan **Kedai Pro** (pemilik kedai).

---

## 1. Konsep & Strategi

### 1.1 Positioning
Bukan "sosmed baru", tapi **identitas pemburu kopi**. Gen Z flexing "aku nemu hidden gem duluan" → app menyediakan bukti (stempel Passport, badge, share card) yang **dipamerkan di Instagram/TikTok**. Flexing terjadi di luar app; app adalah pabrik kontennya.

### 1.2 Loop utama
```
Temukan kedai (Home/Explore) → Datang & pesan (WA) → Drop (foto + check-in)
   → Stempel Passport + badge → Share card ke IG Story → teman lihat → install
```

### 1.3 Prinsip monetisasi
- **Semua fitur sosial gratis selamanya** (Drop, like, komentar, follow). Paywall di fitur sosial membunuh network effect.
- **Kedai Pro = sumber uang utama.** Kedai bayar untuk menjangkau user.
- **Street Pass = nilai nyata**, bukan sekadar kosmetik: promo di kedai partner membuat langganan "balik modal".
- Street Pass digital wajib lewat **Google Play Billing / Apple IAP** (potongan 15–30%). Kedai Pro ditagih via **web (transfer/QRIS)** agar tidak kena potongan store.

---

## 2. Design Tokens

Semua tersimpan sebagai **variabel** di file `.pen` (referensi `$nama`).

### 2.1 Warna
| Token | Hex | Pemakaian |
|---|---|---|
| `primary` | `#9FE444` | Satu-satunya aksen: CTA, state aktif, status buka, harga, link |
| `primary-pressed` | `#7BC419` | Pressed |
| `primary-soft` | `#9FE444` @ 12% | Latar chip/tile aktif, badge status |
| `on-primary` | `#0E0E0E` | Teks/ikon di atas lime |
| `bg` | `#0E0E0E` | Latar layar |
| `surface` | `#181818` | Card, sheet |
| `surface-alt` | `#222222` | Card di dalam card, placeholder |
| `input` | `#262626` | Field input |
| `text-primary` | `#FFFFFF` | Judul, isi |
| `text-secondary` | `#B3B3B3` | Deskripsi, meta |
| `text-muted` | `#8A8A8A` | Placeholder, caption (dinaikkan dari #666 → lolos WCAG AA) |
| `divider` | `#2C2C2C` | Border, garis |
| `closed` | `#FF6B5E` | Tutup, like (heart), error, destruktif |
| `closed-soft` | `#FF6B5E` @ 12% | Latar badge tutup / tombol keluar |
| `star` | `#FFC107` | Rating |
| `whatsapp` | `#25D366` | **Hanya** ikon WA & bubble preview (bukan tombol) |
| `overlay` | `#000000` @ 55% | Tombol bulat di atas foto |

**Aturan hijau:** v1 punya 3 hijau yang bersaing (lime, open, WA). v2: status buka = lime, CTA WA = lime + ikon chat. Hijau WA hanya aksen kecil.

**Gradien khusus sosial:** ring avatar/drop baru = angular `#9FE444 → #E4F76A → #9FE444`. Pass card = linear `#C8F56A → #9FE444 → #5E9A1C`.

### 2.2 Tipografi
| Style | Font | Size / Weight | Pemakaian |
|---|---|---|---|
| Display | Syne | 30 / 800, ls −0.5 | Headline Home, paywall |
| Title | Syne | 24 / 800 | Judul semua layar (seragam) |
| Section | Syne | 18 / 700 | Judul section |
| Card title | Syne | 16 / 700 | Nama kedai di card |
| Body | Inter | 14 / 400 | Isi, caption |
| Meta | Inter | 12 / 400 | Rating · jarak · harga |
| Badge | Inter | 11 / 600 | Status, tag |
| Overline | Inter | 11 / 700, ls 1.2, UPPERCASE | Label grup (ADMIN, UMUM) |
| Receipt | **Space Mono** | 9–12 / 400–700, UPPERCASE | Isi struk Drop Ticket, field paspor, stempel, label "LAGI DI KEDAI" |

> Syne sangat lebar: "STREET COFFEE" ≥ 30px tidak muat 1 baris di 390px → selalu dipecah 2 baris.

### 2.3 Radius · Spacing · Lainnya
- Radius: `8` badge kecil · `12` input/icon box · `16` card · `20` featured/post photo · `24–28` sheet & pass card · pill.
- Spacing: skala 4 → `4 8 12 16 20 24 32`. Padding halaman **20**. Gap antar section **20–24**.
- Touch target ≥ 44px. Transisi halaman: fade 280ms ease-in-out.
- Ikon: **Lucide** (outline, 1.5–2px).

### 2.4 Bahasa visual sosial — "Struk · Stempel · Paspor"
Sisi sosial sengaja **tidak meniru pola visual Instagram** (ring story gradien, post header-foto-❤️💬✈️🔖, profil avatar bulat + 3 angka + grid 3 kolom). Pola interaksinya tetap familiar (scroll feed, reaksi, komentar), tapi tampilannya diambil dari dunia kedai kopi:

| Pola umum (dihindari) | Versi Street Coffee |
|---|---|
| Post: header user → foto → baris ikon | **Drop Ticket**: foto → sobekan struk berlubang → isi struk mono (kedai, item & harga, rating, vibe) → caption user → pill reaksi. **Kedai lebih dulu, user belakangan** |
| ❤️ Like | **☕ Cheers** (bersulang kopi), pill lime |
| 🔖 Simpan | **📍 Mau ke sini** (wishlist kedai) |
| Ring story avatar bulat | **"Lagi di kedai sekarang"**: kartu kedai + tumpukan avatar teman yang sedang check-in |
| Tab underline | Segmented pill (Sekitar / Teman / Trending) |
| Profil avatar bulat + 3 angka + grid | **Halaman paspor**: kartu ID (foto persegi, NAMA / NO. PASPOR / LEVEL, baris MRZ) · strip statistik bergaris · **halaman stempel** (stempel bulat miring + tanggal) |
| Emoji cepat di komentar | **Balasan cepat** kontekstual: "Parkir aman?", "Rame jam berapa?" |
| Avatar selalu bulat | Avatar user **kotak membulat** (radius 8–12); bulat hanya untuk stempel |

---

## 3. Navigasi

### 3.1 Tab bar (floating capsule, 5 slot)
**Home · Explore · ＋ Drop · Feed · Profil**
- Kapsul 358×60, radius 30, `#1E1E1E` @ 90% + background blur, inset 16px dari tepi, 12px dari bawah.
- Item 64×48: ikon 22 + label 10. Aktif: pil `primary-soft`, ikon & label lime bold.
- **Drop** = tombol bulat lime 48 dengan glow, bukan tab (membuka layar Buat Drop).
- Peta **bukan tab lagi**; dibuka lewat toggle List/Peta di Explore.

### 3.2 Peta alur
```
Splash → Home ─┬─ header lokasi → Pilih Lokasi
               ├─ search / vibe → Explore (List ⇄ Peta) → Filter sheet
               ├─ card → Detail ─┬─ WA CTA → Konfirmasi WA → WhatsApp
               │                 ├─ tab Drops / Regulars
               │                 └─ (admin) toggle buka + edit → Form Kedai
               ├─ Lagi rame di-Drop → Feed
               └─ banner → Street Pass
＋ Drop → Buat Drop → Drop Terposting → Share (IG Story/TikTok/WA/link/simpan)
Feed ─┬─ post → Komentar sheet · ⋯ → Laporkan
      └─ 🔔 → Notifikasi
Profil ─┬─ guest → Login
        ├─ user → Profil Sosial (halaman paspor, badge, stempel)
        └─ admin → Profil Admin (tools)
Detail/Profil → "Punya kedai?" → Kedai Pro (landing) → Dashboard
```

---

## 4. Komponen (reusable di `.pen`)

| Komponen | Isi / catatan |
|---|---|
| **Status Bar** | 390×62, jam + sinyal/wifi/baterai |
| **Tab Bar / Tab Item** | Lihat 3.1; override state aktif per layar |
| **Shop Card** | Foto 96 · nama · tombol WA bulat · ⭐ rating · jarak · harga · Status Badge · vibe. Tutup → tombol WA redup |
| **Featured Card** | 220×260, foto full-bleed + scrim, badge status & jarak di atas, nama + rating + vibe di bawah |
| **Status Badge** | Titik + teks. Buka = lime; Tutup = `closed` |
| **Vibe Chip** | Pill: emoji dalam lingkaran + label. Aktif = soft + border lime. Scroll horizontal |
| **Filter Chip** | Pill label + chevron. Aktif = lime solid + ikon ✕ |
| **Search Bar** | Input 48 + tombol filter 36 |
| **Button Primary / Secondary** | 52 tinggi, radius 16, Syne 15/700 |
| **Icon Button** | Lingkaran 40, `overlay` + blur (di atas foto) |
| **Section Header** | Judul Syne 18 + link lime |
| **Menu Tile** | Icon box 36 · judul · subjudul · chevron |
| **Facility Item** | Kotak ikon 52 + label |
| **Drop Ticket** *(baru)* | Kartu 350, radius 24. Foto 360 (pil waktu mono + stempel "KEDAI KE 32" miring) · perforasi (takik kiri-kanan + garis putus-putus) · nama kedai Syne 19 + "VIBE · JARAK" mono + tombol ↗ · 3 baris struk mono dengan titik-titik (item/harga, rating, vibe) · avatar kotak + handle + PASS + caption · pill **☕ Cheers** (lime), 💬 jumlah, bagikan, **📍 Mau ke sini** |
| **Pro Tag** *(baru)* | Pil gradien lime "⚡ PASS" di samping username member |
| **Achievement Badge** *(baru)* | Medali 60 (gradien + border lime + ikon) + label. Terkunci = abu + ikon gembok |
| **Share Card · IG Story** *(baru)* | 270×480 (9:16, export 4× = 1080×1920): brand, stempel bulat miring "KEDAI KE 32 + tanggal", "@user ngopi di", nama kedai besar, pil lokasi/rating/menu, footer badge + streetcoffee.id |

---

## 5. Layar (di `.pen`)

### Inti (revamp v1)
| # | Layar | Poin |
|---|---|---|
| 00 | Splash | Logo lime + glow, wordmark 2 baris, loader "Mencari kedai di sekitarmu…" |
| 01 | Home | Lokasi + avatar · headline "Ngopi di mana malam ini?" · search · vibe chips · Featured · **Lagi rame di-Drop 🔥** · **banner Street Pass** · Terdekat dari kamu |
| 02 | Explore | Toggle List/Peta · search · filter chip aktif · jumlah hasil + urutkan · list Shop Card |
| 03 | Peta | Peta gelap full · pin rating · titik user · card kedai terpilih · tombol recenter |
| 04 | Detail Kedai | Hero 320 (back/share/simpan, galeri 1/8) · nama + status + jam · alamat · stats (rating/jarak/harga) · deskripsi · vibe · fasilitas · menu favorit (＋ order) · link IG/TikTok/Maps · ringkasan & daftar review · CTA sticky: arah + "Chat & Pesan via WhatsApp" |
| 04b | Detail (Admin) | + toggle Buka di hero, tombol edit, banner "Mode admin" |
| 05 | Konfirmasi WhatsApp | Sheet: item + stepper qty · preview pesan (bisa diubah) · "Buka WhatsApp" / Batal (menggantikan auto-redirect) |
| 06 | Filter | Urutkan (segmented) · harga · vibe · fasilitas · switch Buka sekarang · "Tampilkan N kedai" |
| 07 | Pilih Lokasi | Lokasi saat ini · pilih di peta · tersimpan (+ tambah) · terakhir dicari (judul ≠ subjudul) |
| 08 | Login | Foto full + scrim · logo · wordmark · 3 benefit · Google (putih) · lanjut tanpa login · legal |
| 09 | Profil (Guest) | Card login gradien + tombol Google · menu umum |
| 10 | Profil (Admin) | Avatar + badge Admin · stats · tools admin · aktivitas · keluar |
| 11 | Tambah Kedai (Admin) | Progress 5/8 · section bernomor: foto, info, lokasi (peta+pin), kontak & harga (+62, Rp), jam & status, vibe & fasilitas, menu (drag/hapus), sosmed · CTA Simpan |
| 12–15 | State | Loading (skeleton) · Empty filter · Error offline · Izin lokasi |

### Sosial (baru)
| # | Layar | Poin |
|---|---|---|
| 16 | Feed | Segmented Sekitar/Teman/Trending · **Lagi di kedai sekarang** (kartu Check-in + kartu kedai dengan tumpukan avatar teman) · **Drop Ticket** · 🔔 dengan dot |
| 17 | Komentar | Sheet 680: komentar kedai terverifikasi + disematkan (dengan link promo) · balasan ter-indent · ☕ per komentar · **balasan cepat** kontekstual · input + kirim · avatar kotak membulat |
| 18 | Buat Drop | Foto 400 + filter (Asli/Senja/Film/Mono/Neon) · multi foto · caption · **kedai terdeteksi otomatis** · menu yang dipesan · rating cepat · audiens · **Tunda lokasi** · Bagikan ke IG Story |
| 19 | Drop Terposting | Glow lime · "Drop terposting! 🎉" · preview share card · toast badge baru · share target (IG Story utama, TikTok, WA, salin link, simpan) |
| 21 | Profil Sosial | Username + PASS · **kartu ID paspor** (band "REPUBLIK NGOPI", foto persegi, NAMA / NO. PASPOR / LEVEL, progress ke Lv.5, baris MRZ) · strip statistik (Drops/Pengikut/Mengikuti/Area) · bio · Edit profil / Bagikan paspor · badge 12/30 · segmented Stempel/Drops/Mau ke sini · **halaman stempel** 4 kolom |
| 22 | Detail · Drops & Regulars | Header ringkas + Ikuti · tab Info/Menu/Drops/Regulars · promo resmi kedai (khusus Pass) · masonry drop · **leaderboard Regulars bulanan** (emas/perak/perunggu + posisi "Kamu") · CTA Drop + Pesan via WA |
| 26 | Notifikasi | Filter chip (Semua/Cheers/Komentar/Promo) · Hari ini / Minggu ini · Cheers, promo kedai, komentar, follow (Ikuti balik), badge, naik peringkat Regulars · unread = tint lime |
| 27 | Laporkan Konten | Sheet: salin link/simpan/sembunyikan · alasan (radio) · blokir akun · "Kirim laporan" (merah) |

### Monetisasi (baru)
| # | Layar | Poin |
|---|---|---|
| 23 | Street Pass | Pass card miring (nama member + jumlah kedai) · "Ngopi lebih hemat, flexing lebih keren." · 5 benefit · plan Bulanan Rp19rb / **Tahunan Rp149rb (hemat 35%)** · "Coba gratis 7 hari" · catatan "Drop, like & komentar tetap gratis selamanya" |
| 24 | Kedai Pro (Landing) | Hero foto · "Bikin kedaimu jadi tongkrongan berikutnya." · preview chart klik WA (ditandai ilustrasi) · 5 fitur · tier **Basic Gratis / Pro Rp99rb / Pro+ Rp249rb** · "Klaim kedaimu" · bayar via web |
| 25 | Kedai Pro (Dashboard) | Header kedai + PRO · periode 7/30/90 hari · **kartu bukti pelanggan** (redeem + lead WA ditandai, estimasi omzet, input "Jadi beli" untuk kode SC-XXXX) · KPI (dilihat, lead WA berkode, drop, pengikut) · bagi hasil Street Pass · chart jam ramai + insight · menu paling sering di-Drop · review belum dibalas · Boost / Buat promo |
| 28 | Pakai Promo (member) | Voucher bergaya struk · QR + **kode 6 karakter berganti tiap 30 dtk** · countdown · jam live + nama member (anti-screenshot) · 3 langkah · syarat |
| 29 | Mode Kasir (kedai) | Input kode 6 kotak · hasil **Kode valid** (promo, member, kuota tersisa, redeem ke-N) · status gagal: kedaluwarsa / sudah dipakai hari ini / kuota habis / bukan member |
| 30 | Buat Promo (kedai) | Jenis (bundling/potongan/gratis item) · menu · harga promo + % hemat · kuota/hari · periode · khusus member · penjelasan **diskon ditanggung kedai + poin bagi hasil** |

---

## 6. Gamifikasi

| Elemen | Aturan (usulan) |
|---|---|
| **Stempel Passport** | 1 stempel per kedai unik, dari Drop yang lokasinya terverifikasi GPS (radius ±100 m) |
| **Level** | Lv.1 Pendatang (0) · Lv.2 Penikmat (5) · Lv.3 Pencari (15) · Lv.4 Kopi Nomad (25) · Lv.5 Skena Legend (40) |
| **Badge** | Night Owl (5× check-in > 22.00) · Manual Brew Hunter (10 kedai manual brew) · First Drop (drop pertama di kedai baru) · Kopi Hemat (10 kedai < 20k) · Skena Legend (Lv.5) — total ±30 |
| **Regulars** | Peringkat check-in per kedai, reset tiap tanggal 1. Top 3 tampil di Detail |
| **Streak** *(opsional)* | Minggu berturut-turut dengan ≥ 1 Drop |

Anti-curang: 1 stempel per kedai per hari, wajib foto baru (bukan dari galeri lama; cek EXIF/waktu), GPS dalam radius.

---

## 7. Monetisasi — detail

### Street Pass (user)
| | Gratis | Street Pass |
|---|---|---|
| Drop, like, komentar, follow | ✅ | ✅ |
| Passport & badge dasar | ✅ | ✅ |
| Promo eksklusif kedai partner | — | ✅ |
| Frame share card & badge eksklusif, tag ⚡ PASS | — | ✅ |
| Coffee Wrapped + statistik Passport lengkap | — | ✅ |
| Koleksi tanpa batas | 3 koleksi | ✅ |
| Akses awal kedai baru | — | ✅ |

Harga usulan: **Rp19.000/bulan** atau **Rp149.000/tahun**, trial 7 hari.

### Kedai Pro (bisnis)
| | Basic (gratis) | Pro Rp99rb/bln | Pro+ Rp249rb/bln |
|---|---|---|---|
| Klaim & edit info, balas review | ✅ | ✅ | ✅ |
| Badge verified + akun resmi | — | ✅ | ✅ |
| Promo post ke follower & Feed Sekitar | — | 4/bln | Tanpa batas + boost |
| Analytics | Ringkas | Lengkap | Lengkap + export |
| Slot Featured (Home & pin Peta) | — | — | 7 hari/bln |
| Partner Street Pass | — | ✅ | ✅ |
| Multi cabang | — | — | ✅ |

---

## 8. Kebutuhan Non-Desain (harus disiapkan sebelum rilis sosial)

1. **Moderasi** — report, blokir, sembunyikan, filter kata kasar, antrean review admin ≤ 24 jam. Wajib untuk lolos Play Store/App Store (UGC policy).
2. **Privasi (UU PDP)** — Tunda lokasi (default ON), akun privat, hapus akun & data, audiens per Drop.
3. **Cold start** — Feed "Sekitar" aktif sejak hari 1 + konten kurator/admin; seed Drop dari kedai partner.
4. **Biaya storage** — kompres foto di client (maks ±1080px, WebP/JPEG 80%), thumbnail terpisah; perhatikan kuota Firebase Storage.
5. **Pembayaran** — Play Billing/IAP untuk Street Pass; web + QRIS untuk Kedai Pro.
6. **Model data baru (Firestore)** — `users/{uid}` (handle, bio, level, stats, isPass) · `drops/{id}` (uid, shopId, photos[], caption, menu, rating, likeCount, commentCount, visibility, publishAt) · `drops/{id}/comments` · `likes` · `follows` · `badges` · `passport/{uid}/stamps/{shopId}` · `reports` · `shops/{id}.pro` (tier, until) · `promos`.

---

## 9. Perubahan dari v1 (ringkas)

- Nav: Map/List/Profil (label salah) → Home · Explore · ＋Drop · Feed · Profil.
- Card: + rating, jarak, status buka, tombol WA sungguhan.
- Satu aksen hijau; `text-muted` lebih terang (kontras AA).
- Overlay auto-redirect WA → sheet konfirmasi dengan qty & pesan yang bisa diubah.
- Vibe chip pill horizontal (tanpa line break manual).
- Detail: galeri, link sosmed, ringkasan rating, tab Drops & Regulars.
- Tombol Google konsisten (putih); teks full Bahasa Indonesia.
- Baru: Feed, Drop, Komentar, Share card, Profil Sosial, Passport, Badge, Notifikasi, Laporkan, Street Pass, Kedai Pro.
- Sosial memakai bahasa visual sendiri (struk · stempel · paspor), bukan pola visual Instagram — lihat 2.4.

---

## 10. Landing Page (web)

> **File:** [`docs/landing/index.html`](docs/landing/index.html) — mockup HTML statis, satu file, memakai screenshot asli dari `docs/screenshots/`.
> Preview: [`desktop`](docs/landing/preview_desktop.png) · [`mobile 360`](docs/landing/preview_mobile.png).
> Belum ada frame di `design/street_coffee.pen`: sesi pembuatan tidak punya akses Pencil MCP. Saat dipindah ke `.pen`, pakai frame **1280** (desktop) dan **360** (mobile) dengan urutan section di bawah.

Token yang dipakai sama dengan aplikasi (§2): latar `#0E0E0E`, satu aksen lime `#9FE444`, Syne 800 untuk headline, Inter untuk isi, Space Mono uppercase untuk label/eyebrow, kartu `#181818` radius 20.

| # | Section | Isi | Catatan desain |
|---|---|---|---|
| 1 | Nav sticky | Logo · Kenapa / Fitur / Street Pass / Untuk Kedai · CTA "Gabung waitlist" | Blur + border `divider`. Di ≤900 px link disembunyikan, CTA jadi "Gabung" |
| 2 | Hero | Pill "Beta Jakarta Selatan · Android" · **"Temukan kopi di skenamu."** (kata *skenamu* lime) · lead · CTA primer "Coba versi beta" + sekunder "Punya kedai? Daftar gratis" · 3 angka (Rp5rb, 0, 1 tap) | Dua mockup HP (Home tegak, Explore miring 6°) + chip stempel "KEDAI KE-32". Glow radial lime di belakang |
| 3 | Masalah | "Ngopi enak itu gampang. Nyarinya yang susah." · 3 kartu: jam buka tak tercatat · tidak terlihat online · order WA tercecer | Ikon emoji di kotak `surface-alt` 44 |
| 4 | Fitur (zig-zag) | 01 Temukan (Explore) · 02 Pesan (Detail + struk mono berkode SC-XXXX) · 03 Drop (Feed) · 04 Koleksi (Passport) | Eyebrow mono lime bernomor; checklist ✓ lime |
| 5 | Street Pass | "Langganannya balik modal dari 2 gelas." · plan Gratis vs **Street Pass** (gradien pass card §2.1) | Kalimat "fitur sosial gratis selamanya" wajib ada |
| 6 | Kedai Pro | "Bikin kedaimu jadi tongkrongan berikutnya." · 4 langkah · tier Basic / **Pro** (border lime) / Pro+ | Catatan: dibayar via web (QRIS), bukan store |
| 7 | Penutup | "Ngopi di mana malam ini?" (headline Home) · form email waitlist | Form mockup saja, belum terhubung backend |
| 8 | Footer | © · atribusi "Peta © OpenStreetMap contributors" | Atribusi OSM wajib |

**Responsif:** 1 kolom di ≤900 px; di ≤560 px gutter 16 px, judul section 30 px (kata panjang Syne seperti *Langganannya* tidak muat di 360 px pada ukuran lebih besar), tombol full-width. Diuji di 1280 dan 360 px tanpa scroll horizontal.
