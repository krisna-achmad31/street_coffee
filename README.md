# Street Coffee ☕

> Flutter + Firebase (Firestore, RTDB, Storage, Auth, Cloud Functions) + OSM

Direktori kedai kopi skena + lapisan sosial (Drop, paspor, Cheers) + monetisasi
(Street Pass untuk user, Kedai Pro untuk pemilik kedai).

- Desain: [`design/street_coffee.pen`](design/street_coffee.pen) (pen.dev) · spec: [`DESIGN.md`](DESIGN.md)
- PRD & roadmap: dokumen "Street Coffee — PRD & Roadmap"
- Pitch: [`docs/PITCH.md`](docs/PITCH.md) · landing page: https://street-coffee.web.app (sumber: [`web/`](web/), `firebase deploy --only hosting`)

## Arsitektur

```
lib/
├── core/
│   ├── constants/  AppColors (token v2), AppTextStyles (Syne/Inter/Space Mono), FirebasePaths
│   ├── router/     GoRouter — StatefulShellRoute 4 tab + tombol Drop
│   └── utils/      RedeemCode, AttributionCode, WhatsAppLauncher, Fmt
├── domain/
│   ├── entities/   CoffeeShop, social.dart (Drop, Stamp, UserProfile, PassportLevel…),
│   │               commerce.dart (Promo, RedeemResult, Membership, ShopInsights)
│   └── repositories/ kontrak (shop, auth, comment, social, commerce)
├── data/
│   ├── repositories/ *_impl — Firestore; SocialRepositoryImpl, CommerceRepositoryImpl
│   └── services/   StreetPassBilling (in_app_purchase → verifyPassPurchase)
└── presentation/
    ├── pages/      home, explore (list ⇄ peta), detail, social/, commerce/, profile, …
    └── widgets/    ui/ (buttons, chips, receipt: Perforation/StampSeal), cards/ (ShopCard,
                    FeaturedCard, DropTicket), sheets/ (konfirmasi WA), app_tab_bar

functions/          Cloud Functions (TypeScript, region asia-southeast2)
├── src/redeem.ts         redeemPromo — validasi kode kasir (kode berputar 30 dtk)
├── src/revenue_share.ts  settleRevenueShare — tiap tgl 1, 20% pool Pass ke kedai partner
├── src/social.ts         verifikasi GPS Drop, stempel paspor, Regulars, counter, notifikasi
├── src/billing.ts        verifyPassPurchase — cek token Google Play sebelum aktifkan member
└── rules-test/           test security rules (emulator)
```

### Tiga mekanisme bisnis inti

| Mekanisme | Klien | Server |
|---|---|---|
| **Redeem promo di kasir** | `UsePromoPage` menampilkan kode 6 karakter (HMAC, berganti tiap 30 dtk) + QR; `CashierPage` untuk staf | `redeemPromo` mencocokkan kode dengan member yang membuka promo di kedai itu ≤ 2 menit terakhir, cek kuota & 1×/hari, catat `redemptions` |
| **Diskon ditanggung kedai + bagi hasil** | `CreatePromoPage` (`fundedBy: 'shop'` wajib oleh rules) | `settleRevenueShare` membagi 20% pendapatan bersih Pass ke kedai sesuai jumlah redeem |
| **Atribusi WA** | Setiap pesan WA diberi `(kode: SC-XXXX)`; lead dicatat di `coffee_shops/{id}/leads`; owner menandai "jadi beli" di dashboard | Counter harian di `coffee_shops/{id}/stats/{hari}` |

Algoritma kode redeem ada di **dua tempat** (`lib/core/utils/redeem_code.dart` dan
`functions/src/codes.ts`) dan dikunci oleh test vector yang sama (`HR8J3H`) di kedua sisi.

## Setup

### 1. Firebase
Aktifkan Authentication (Google), Firestore, Storage, Realtime Database, Cloud Functions
(butuh paket **Blaze**). Config sudah ada di `android/app/google-services.json` dan
`lib/firebase_options.dart`.

### 2. Admin
UID admin ada di `lib/core/constants/admin_config.dart`, `firestore.rules`,
`storage.rules`, `database.rules.json`, dan parameter `ADMIN_UIDS` di Functions — samakan semuanya.

### 3. Deploy rules, index, dan functions
```bash
cd functions && npm install && cd ..
firebase deploy --only firestore:rules,firestore:indexes,storage,database,functions
```
Saat deploy pertama, CLI menanyakan parameter `ADMIN_UIDS` dan `ANDROID_PACKAGE`
(default `com.streetcoffee.app.street_coffees`).

### 4. Street Pass (Google Play)
1. Buat subscription `street_pass_monthly` dan `street_pass_yearly` (dengan trial 7 hari) di Play Console.
2. Beri service account Cloud Functions akses **View financial data** di Play Console → Users & permissions.
3. iOS belum didukung (`verifyPassPurchase` mengembalikan `unimplemented`).

### 5. Kedai Pro
- Klaim masuk ke koleksi `shop_claims`. Setelah verifikasi, admin mengisi `ownerUid` dan
  `pro: { tier: 'pro', until: <Timestamp> }` di dokumen kedai (tagihan via transfer/QRIS di luar app).
- Staf kasir tambahan: isi array `staffUids` di dokumen kedai.
- Bagi hasil tercatat di `revenue_share/{yyyymm}/shops/{shopId}` (`status: pending_transfer`); transfer dilakukan manual.

### 6. Jalankan
```bash
flutter pub get
flutter run
```

**Demo live feed.** Di build debug, Feed otomatis diisi data dummy yang "hidup"
(`lib/data/demo/`): Cheers & komentar bertambah, orang keluar-masuk kedai di
"Lagi di kedai sekarang", dan Drop baru muncul tiap ~20 detik. Data asli dari
Firestore tetap digabung; kalau Firestore gagal, Feed jatuh ke data demo saja.
Interaksi pada konten demo (id `demo_…`) hanya disimpan di memori.

```bash
flutter run --dart-define=DEMO_FEED=false          # matikan di debug
flutter run --release --dart-define=DEMO_FEED=true # nyalakan untuk demo release
```

## Test

```bash
flutter analyze
flutter test                                   # unit test Dart
npm --prefix functions test                    # unit test Functions
firebase emulators:exec --only firestore "node --test functions/rules-test/"   # security rules (JDK 21)
```

## Catatan data

| Koleksi | Ditulis oleh |
|---|---|
| `coffee_shops` | admin; owner hanya field listing |
| `coffee_shops/{id}/stats`, `/leads` | klien (views, lead, konversi) + Functions (drops, redemptions, jam, menu) |
| `drops`, `drops/{id}/cheers`, `/comments` | klien; counter & stempel oleh Functions |
| `users/{uid}` | klien (profil); `stampsCount`, `dropsCount`, `passUntil` oleh Functions |
| `promos` | owner kedai; `usage` oleh Functions |
| `memberships`, `redemptions`, `revenue_share` | hanya Functions |

## Test

```bash
flutter analyze
flutter test        # 116 test, tanpa Firebase (repository in-memory di test/helpers)
```

- `test/presentation/blocs/` — Explore (filter, search, latest-wins), Location, Detail, Comment, Admin, Auth
- `test/presentation/pages/` — Home, Explore, Detail, Feed, Profil, Pakai Promo, form Tambah/Edit Kedai
- `test/flutter_test_config.dart` memuat font dengan lebar realistis (Roboto dari SDK + monospace sistem) di bawah nama google_fonts, supaya pengecekan overflow tidak palsu. Test tidak pernah mengunduh font.
