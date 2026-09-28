// firestore_seed.js — Run ONCE via Node.js to seed dummy data
// Usage: node firestore_seed.js
//
// Requires: npm install firebase-admin
// Ganti serviceAccountKey.json dengan file dari Firebase Console >
// Project Settings > Service Accounts > Generate new private key

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

const dummyShops = [
  {
    name: 'KOPI SKENA',
    address: 'Jl. Senopati No. 12, Jakarta Selatan',
    latitude: -6.2351,
    longitude: 106.8040,
    rating: 4.8,
    reviewCount: 120,
    priceRange: 'Rp 15k-35k',
    minPrice: 15000,
    maxPrice: 35000,
    vibe: 'Nongkrong Skena',
    vibes: ['Nongkrong Skena', 'Manual Brew'],
    facilities: ['WiFi', 'Outdoor', 'Musik'],
    categories: ['Nongkrong', 'Murah', 'Manual Brew'],
    imageUrl: 'https://images.unsplash.com/photo-1554118811-1e0d58224f24?w=800',
    galleryUrls: [
      'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=800',
    ],
    menuFavorites: [
      {
        name: 'Kopi Susu Gula Aren',
        imageUrl: 'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?w=400',
        price: 22000,
      },
      {
        name: 'V60 Flores',
        imageUrl: 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=400',
        price: 35000,
      },
    ],
    whatsappNumber: '6281234567890',
    isOpen: true,
    openFrom: '09:00',
    openUntil: '23:00',
    description: 'Tempat nongkrong asik, kopi manual brew lokal. Vibe sunset mantap.',
    isFeatured: true,
  },
  {
    name: 'GEROBAK KOPI JOSS',
    address: 'Depan Pasar Blok M, Jakarta Selatan',
    latitude: -6.2436,
    longitude: 106.7981,
    rating: 4.5,
    reviewCount: 87,
    priceRange: 'Rp 10k-20k',
    minPrice: 10000,
    maxPrice: 20000,
    vibe: 'Santai',
    vibes: ['Kopi Hemat', 'Santai'],
    facilities: ['Outdoor', 'Parkir'],
    categories: ['Murah', 'Kopi Hemat', 'Street Coffee'],
    imageUrl: 'https://images.unsplash.com/photo-1521017432531-fbd92d768814?w=800',
    galleryUrls: [],
    menuFavorites: [
      {
        name: 'Kopi Joss Hitam',
        imageUrl: 'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?w=400',
        price: 10000,
      },
    ],
    whatsappNumber: '6289876543210',
    isOpen: true,
    openFrom: '06:00',
    openUntil: '14:00',
    description: 'Kopi gerobak legendaris dengan arang. Murah, nendang, dan berkarakter.',
    isFeatured: false,
  },
  {
    name: 'STREET BREW BBG',
    address: 'Jl. Wijaya I No. 5, Kebayoran Baru',
    latitude: -6.2421,
    longitude: 106.8012,
    rating: 4.7,
    reviewCount: 203,
    priceRange: 'Rp 15k-25k',
    minPrice: 15000,
    maxPrice: 25000,
    vibe: 'Deep Talk',
    vibes: ['Deep Talk', 'Manual Brew'],
    facilities: ['WiFi', 'AC', 'Musik', 'Colokan'],
    categories: ['Deep Talk', 'Manual Brew', 'Cozy'],
    imageUrl: 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=800',
    galleryUrls: [],
    menuFavorites: [
      {
        name: 'Oat Latte',
        imageUrl: 'https://images.unsplash.com/photo-1568649929103-28ffbefaca1e?w=400',
        price: 25000,
      },
    ],
    whatsappNumber: '6281122334455',
    isOpen: true,
    openFrom: '10:00',
    openUntil: '22:00',
    description: 'Spot tenang untuk deep conversation. Single origin manual brew terbaik.',
    isFeatured: true,
  },
];

async function seedData() {
  console.log('Seeding Firestore...');
  const batch = db.batch();

  for (const shop of dummyShops) {
    const ref = db.collection('coffee_shops').doc();
    batch.set(ref, shop);
    console.log(`  + ${shop.name}`);
  }

  await batch.commit();
  console.log('✅ Seed complete!');
  process.exit(0);
}

seedData().catch(console.error);
