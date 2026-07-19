/**
 * إحصاءات المزامنة — بيانات وصفية فقط، دون أي فك تشفير.
 * يقرأ مجموعة users من قاعدة Firestore المسماة `default` ويكتب admin/stats.json
 * لعرضه في لوحة التحكم (admin/index.html).
 *
 * الاستخدام:
 *   npm install firebase-admin
 *   node admin/stats.mjs path/to/serviceAccount.json
 *
 * لا يقرأ هذا السكربت محتوى النسخ الاحتياطية (حقل backup مشفّر AES-256-GCM
 * بمفتاح موجود في Keychain الجهاز فقط) — يجمع الحجم والمراجعة والتواريخ فقط.
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import admin from 'firebase-admin';

const saPath = process.argv[2];
if (!saPath) {
  console.error('الاستخدام: node admin/stats.mjs path/to/serviceAccount.json');
  process.exit(1);
}

const serviceAccount = JSON.parse(readFileSync(saPath, 'utf8'));
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

// القاعدة المسماة `default` (وليست القاعدة الافتراضية "(default)")
const db = admin.firestore();
db.settings({ databaseId: 'default' });

const now = Date.now();
const DAY = 86_400_000;

const snap = await db.collection('users').get();

let sizeSum = 0, revSum = 0;
const recencyBuckets = { 'آخر 24 ساعة': 0, 'آخر 7 أيام': 0, 'آخر 30 يومًا': 0, 'أقدم': 0 };
const schemaVersions = {};
let last7d = 0;

for (const doc of snap.docs) {
  const d = doc.data();
  sizeSum += typeof d.backup === 'string' ? d.backup.length : 0;
  revSum += typeof d.revision === 'number' ? d.revision : 0;
  const sv = 'v' + (d.schemaVersion ?? '?');
  schemaVersions[sv] = (schemaVersions[sv] ?? 0) + 1;
  const t = d.updatedAt?.toMillis?.() ?? 0;
  const age = now - t;
  if (age <= DAY) { recencyBuckets['آخر 24 ساعة']++; last7d++; }
  else if (age <= 7 * DAY) { recencyBuckets['آخر 7 أيام']++; last7d++; }
  else if (age <= 30 * DAY) recencyBuckets['آخر 30 يومًا']++;
  else recencyBuckets['أقدم']++;
}

const total = snap.size;
const stats = {
  generatedAt: new Date().toISOString().slice(0, 16).replace('T', ' '),
  totalUsers: total,
  avgBackupKB: total ? sizeSum / total / 1024 : 0,
  avgRevision: total ? revSum / total : 0,
  recency: { '7d_total': last7d },
  recencyBuckets,
  schemaVersions,
};

const out = join(dirname(fileURLToPath(import.meta.url)), 'stats.json');
writeFileSync(out, JSON.stringify(stats, null, 2) + '\n');
console.log(`✅ كُتب ${out} — ${total} مستخدم (بيانات وصفية فقط)`);
process.exit(0);
