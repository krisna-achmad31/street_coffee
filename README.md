# Street Coffee ☕
> Flutter + Firebase (Firestore + RTDB + Storage) + OSM

## Architecture

```
lib/
├── core/
│   ├── constants/    AppColors, AppTextStyles, AdminConfig, FirebasePaths
│   ├── theme/        AppTheme (dark)
│   ├── router/       GoRouter (all routes)
│   └── utils/        Failures, UseCase base, WhatsAppLauncher
│
├── domain/           Pure Dart — zero Flutter/Firebase deps
│   ├── entities/     CoffeeShop, UserLocation, AppUser, Comment
│   ├── repositories/ Contracts (auth, shop, location, comment, admin)
│   └── usecases/     GetNearbyShops, SearchShops, GetCurrentLocation...
│
├── data/
│   ├── datasources/  Firebase Auth+Google, Firestore, RTDB, Storage, Geolocator
│   ├── models/       CoffeeShopModel, CommentModel
│   └── repositories/ Impls with Haversine sort + Either<Failure, T>
│
├── presentation/
│   ├── blocs/        AuthBloc, ExploreBloc, DetailBloc, LocationBloc,
│   │                 CommentBloc, AdminBloc
│   ├── pages/        Splash, Home, ExploreList, Detail, PickLocation,
│   │                 Login, AddEditShop (admin form)
│   └── widgets/      FeaturedCard, NearbyCard, VibeChip, CommentSection...
│
├── injection_container.dart   GetIt DI
└── main.dart                  Firebase init + MultiBlocProvider
```

## Firebase Services Used (All Free Tier)

| Service | Usage | Free Limit |
|---|---|---|
| **Firestore** | Shop data + comments | 1GB, 50k reads/day |
| **Firebase Storage** | Shop photos + menu photos | 5GB, 1GB/day download |
| **RTDB** | Real-time isOpen status, comment counter | 1GB, 10GB/month |
| **Firebase Auth** | Google Sign-In | Unlimited |

## Setup Steps

### 1. Firebase Project

```
console.firebase.google.com → New Project
Enable: Authentication (Google), Firestore, Storage, Realtime Database
```

### 2. Download Config Files

```
Android: google-services.json → android/app/
iOS:     GoogleService-Info.plist → ios/Runner/
```

### 3. Set Your Admin UID

Pertama kali login dengan Google di app. Cek Firebase Console →
Authentication → Users → copy UID kamu.

Ganti semua `REPLACE_WITH_YOUR_FIREBASE_UID` di:
- `lib/core/constants/admin_config.dart`
- `firestore.rules`
- `storage.rules`
- `database.rules.json`

### 4. Deploy Rules

Firebase Console atau via CLI:
```bash
npm install -g firebase-tools
firebase login
firebase init
firebase deploy --only firestore:rules,storage,database
```

### 5. Android Permissions (AndroidManifest.xml)

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

### 6. iOS Permissions (Info.plist)

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Butuh lokasi untuk menemukan kedai terdekat</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Butuh akses foto untuk upload gambar kedai</string>
```

### 7. Google Sign-In SHA-1 (Android)

```bash
cd android && ./gradlew signingReport
# Copy SHA-1 → Firebase Console → Project Settings → Android App → Add fingerprint
```

### 8. Run

```bash
flutter pub get
flutter run
```

## Admin Flow

1. Login dengan Google
2. Jika UID match `AdminConfig.adminUid` → `user.isAdmin = true`
3. FAB "+" muncul di Home untuk tambah kedai baru
4. Di detail page: tombol edit + toggle BUKA/TUTUP
5. Toggle isOpen langsung update RTDB → semua user yang buka page melihat perubahan real-time

## Data Flow: isOpen Real-Time

```
Admin tap toggle → AdminBloc → RTDB ref('presence/shops/{id}').set(isOpen: false)
                             → Firestore update (non-blocking, sync)
User di detail page → FirebaseDatabase.instance.ref(...).onValue.listen(...)
                    → setState(_rtdbIsOpen) → UI update instant
```

## Comment Flow

```
User login → CommentSection → CommentBloc.add(CommentAdd)
→ CommentRepository → Firestore 'coffee_shops/{id}/comments' + RTDB counter++
→ Stream auto-updates via CommentBloc._CommentsUpdated
```
