// Seed a Firestore project (real or emulator) with demo shops so a customer has
// something to scan. Ported from the app's old mockData.ts.
//
// Usage:
//   # against the emulator:
//   FIRESTORE_EMULATOR_HOST=localhost:8080 GCLOUD_PROJECT=<id> OWNER_UID=<uid> \
//     npx ts-node src/seed.ts
//   # against the real project (needs GOOGLE_APPLICATION_CREDENTIALS):
//   OWNER_UID=<uid> node lib/seed.js
//
// OWNER_UID should be the Firebase Auth UID of the owner account you signed in
// with — the owner dashboard shows shops where ownerId == your uid.

import * as admin from 'firebase-admin';
import { RewardTier, Shop } from './types';

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

const OWNER_UID = process.env.OWNER_UID || 'REPLACE_WITH_OWNER_UID';

function tiers(shopId: string): RewardTier[] {
  return [
    { id: `${shopId}_v5`, shopId, type: 'visit_count', threshold: 5, discountPercent: 10, label: 'Regular', description: '10% off your meal', emoji: '🌑' },
    { id: `${shopId}_v10`, shopId, type: 'visit_count', threshold: 10, discountPercent: 20, label: 'Loyal Fan', description: '20% off your meal', emoji: '🌗' },
    { id: `${shopId}_v20`, shopId, type: 'visit_count', threshold: 20, discountPercent: 30, label: 'VIP', description: '30% off your meal', emoji: '🌕' },
    { id: `${shopId}_v50`, shopId, type: 'visit_count', threshold: 50, discountPercent: 50, label: 'Legend', description: '50% off your meal', emoji: '☀️' },
    { id: `${shopId}_s3`, shopId, type: 'streak_days', threshold: 3, discountPercent: 5, label: '3-Day Streak', description: '5% off next visit', emoji: '🌱' },
    { id: `${shopId}_s7`, shopId, type: 'streak_days', threshold: 7, discountPercent: 15, label: '7-Day Streak', description: '15% off next visit', emoji: '🌿' },
    { id: `${shopId}_s14`, shopId, type: 'streak_days', threshold: 14, discountPercent: 25, label: '14-Day Streak', description: '25% off next visit', emoji: '🌲' },
    { id: `${shopId}_s30`, shopId, type: 'streak_days', threshold: 30, discountPercent: 40, label: '30-Day Streak', description: '40% off — legendary!', emoji: '🏔️' },
  ];
}

const SHOPS: Shop[] = [
  { id: 'shop_nonna', name: "Nonna's Kitchen", ownerId: OWNER_UID, category: 'bistro', emoji: '🍝', description: 'Authentic Italian comfort food made with love. Fresh pasta daily.', address: '42 Olive Lane, Downtown', rewardTiers: tiers('shop_nonna'), streakWindowDays: 3, createdAt: '2025-01-15', timeZone: 'Asia/Kuala_Lumpur' },
  { id: 'shop_ramen', name: 'Ramen Bar 88', ownerId: OWNER_UID, category: 'ramen', emoji: '🍜', description: 'Rich tonkotsu broth, handmade noodles. Open late.', address: '88 Noodle St, Eastside', rewardTiers: tiers('shop_ramen'), streakWindowDays: 2, createdAt: '2025-02-01', timeZone: 'Asia/Kuala_Lumpur' },
  { id: 'shop_blueroast', name: 'Blue Roast Coffee', ownerId: OWNER_UID, category: 'coffee', emoji: '☕', description: 'Single-origin pour-overs and seasonal espresso blends.', address: '7 Bean Ave, Midtown', rewardTiers: tiers('shop_blueroast'), streakWindowDays: 3, createdAt: '2025-01-20', timeZone: 'Asia/Kuala_Lumpur' },
  { id: 'shop_masa', name: 'Masa Taqueria', ownerId: OWNER_UID, category: 'mexican', emoji: '🌮', description: 'Street-style tacos, fresh salsas, and house-made horchata.', address: '15 Fiesta Blvd, Westside', rewardTiers: tiers('shop_masa'), streakWindowDays: 4, createdAt: '2025-03-01', timeZone: 'Asia/Kuala_Lumpur' },
  { id: 'shop_sweetrise', name: 'Sweet Rise Bakery', ownerId: OWNER_UID, category: 'bakery', emoji: '🥐', description: 'Artisan pastries, sourdough bread, and weekend brunch specials.', address: '3 Flour Ct, Uptown', rewardTiers: tiers('shop_sweetrise'), streakWindowDays: 3, createdAt: '2025-02-10', timeZone: 'Asia/Kuala_Lumpur' },
];

async function main() {
  if (OWNER_UID === 'REPLACE_WITH_OWNER_UID') {
    throw new Error('Set OWNER_UID env var to the owner account Firebase Auth UID.');
  }
  const batch = db.batch();
  for (const shop of SHOPS) {
    batch.set(db.collection('shops').doc(shop.id), shop);
  }
  await batch.commit();
  // eslint-disable-next-line no-console
  console.log(`Seeded ${SHOPS.length} shops owned by ${OWNER_UID}.`);
}

main().then(() => process.exit(0)).catch((e) => {
  // eslint-disable-next-line no-console
  console.error(e);
  process.exit(1);
});
