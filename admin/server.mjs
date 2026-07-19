/**
 * خادم لوحة تحكم المشرف — اشتراكاتي
 * ==================================
 * خادم محلي آمن يخدم اللوحة (index.html) ويوفر واجهة API محمية:
 *   - تسجيل دخول بكلمة مرور (scrypt + ملح عشوائي) تُنشأ عند أول تشغيل.
 *   - جلسات HttpOnly + SameSite=Strict بانتهاء تلقائي (30 دقيقة خمول).
 *   - حد محاولات الدخول: 5 محاولات ثم قفل 15 دقيقة.
 *   - يستمع على 127.0.0.1 فقط — لا يمكن الوصول إليه من الشبكة إطلاقًا.
 *   - ترويسات أمان: CSP, X-Frame-Options, nosniff, no-store + فحص Origin.
 *   - بيانات المستخدمين: Firebase Auth (آخر دخول) + Firestore (آخر مزامنة،
 *     عدد المراجعات، حجم النسخة) — بيانات وصفية فقط، لا فك تشفير أبدًا.
 *   - الإشعارات: يكتب catalog/announcements.json ليجلبه التطبيق من GitHub
 *     (نفس آلية كتالوج الخدمات وفاحص التحديثات).
 *
 * الاستخدام:
 *   npm install firebase-admin
 *   node admin/server.mjs path/to/serviceAccount.json
 *   ثم افتح http://127.0.0.1:8791
 */
import { createServer } from 'node:http';
import {
  readFileSync, writeFileSync, existsSync, appendFileSync,
  mkdirSync, copyFileSync, readdirSync,
} from 'node:fs';
import { scryptSync, randomBytes, timingSafeEqual } from 'node:crypto';
import { createInterface } from 'node:readline';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

const execFileP = promisify(execFile);

const ADMIN_DIR = dirname(fileURLToPath(import.meta.url));
const ROOT = join(ADMIN_DIR, '..');
const AUTH_FILE = join(ADMIN_DIR, '.admin-auth.json');
const ANN_FILE = join(ROOT, 'catalog', 'announcements.json'); // المنشور (يجلبه التطبيق)
const DRAFT_FILE = join(ADMIN_DIR, 'announcements-draft.json'); // المسودة
const BACKUP_DIR = join(ADMIN_DIR, 'backups');
const AUDIT_FILE = join(ADMIN_DIR, 'audit.log'); // JSONL ملحق فقط — خارج Git
const CAT_FILE = join(ROOT, 'catalog', 'services.json');
const SERVER_STARTED = Date.now();
const PANEL_VERSION = '3.0.0';

async function git(...args) {
  const { stdout, stderr } = await execFileP('git', args, { cwd: ROOT, timeout: 60_000 });
  return (stdout + (stderr ? '\n' + stderr : '')).trim();
}
const PORT = 8791;
const HOST = '127.0.0.1';
const SESSION_TTL = 30 * 60 * 1000; // 30 دقيقة خمول
const MAX_ATTEMPTS = 5;
const LOCKOUT_MS = 15 * 60 * 1000;

/* ---------- Firebase Admin ---------- */
const saPath = process.argv[2];
if (!saPath || !existsSync(saPath)) {
  console.error('❌ الاستخدام: node admin/server.mjs path/to/serviceAccount.json');
  console.error('   احصل على المفتاح من Firebase Console ← إعدادات المشروع ← حسابات الخدمة.');
  process.exit(1);
}
const { initializeApp, cert } = await import('firebase-admin/app');
const { getAuth } = await import('firebase-admin/auth');
const { getFirestore } = await import('firebase-admin/firestore');
const { getMessaging } = await import('firebase-admin/messaging');
initializeApp({ credential: cert(JSON.parse(readFileSync(saPath, 'utf8'))) });
const auth = getAuth();
const db = getFirestore('default'); // قاعدة المشروع المسماة default

/* ---------- كلمة المرور (أول تشغيل) ---------- */
function hashPassword(pw, salt = randomBytes(16)) {
  return { salt: salt.toString('hex'), hash: scryptSync(pw, salt, 64).toString('hex') };
}
function verifyPassword(pw, rec) {
  const h = scryptSync(pw, Buffer.from(rec.salt, 'hex'), 64);
  return timingSafeEqual(h, Buffer.from(rec.hash, 'hex'));
}
async function firstRunSetup() {
  if (existsSync(AUTH_FILE)) return;
  const rl = createInterface({ input: process.stdin, output: process.stdout });
  const ask = q => new Promise(res => rl.question(q, res));
  console.log('🔐 أول تشغيل — أنشئ كلمة مرور للوحة (12 حرفًا على الأقل):');
  let pw = '';
  while (pw.length < 12) pw = (await ask('كلمة المرور: ')).trim();
  const confirm = (await ask('تأكيد كلمة المرور: ')).trim();
  rl.close();
  if (pw !== confirm) { console.error('❌ غير متطابقة.'); process.exit(1); }
  writeFileSync(AUTH_FILE, JSON.stringify(hashPassword(pw)), { mode: 0o600 });
  console.log('✅ حُفظت (scrypt + ملح) في admin/.admin-auth.json — الملف خارج Git.');
}
await firstRunSetup();
const authRecord = JSON.parse(readFileSync(AUTH_FILE, 'utf8'));

/* ---------- سجل التدقيق (ملحق فقط، لا يُعدَّل من الواجهة) ---------- */
function audit(req, action, resource, result, details = {}) {
  try {
    const entry = {
      ts: new Date().toISOString(),
      reqId: req?._reqId ?? '-',
      action, resource, result,
      ip: req?.socket?.remoteAddress ?? '-',
      ua: (req?.headers?.['user-agent'] ?? '-').slice(0, 120),
      details,
    };
    appendFileSync(AUDIT_FILE, JSON.stringify(entry) + '\n');
  } catch (e) { console.error('audit write failed:', e.message); }
}
function readAudit(limit = 200, q = '') {
  try {
    const lines = readFileSync(AUDIT_FILE, 'utf8').trim().split('\n');
    let entries = lines.map(l => { try { return JSON.parse(l); } catch { return null; } }).filter(Boolean);
    if (q) entries = entries.filter(e => JSON.stringify(e).includes(q));
    return entries.slice(-limit).reverse();
  } catch { return []; }
}

/* ---------- الجلسات ومحاولات الدخول ---------- */
const sessions = new Map(); // token -> lastSeen
let failedAttempts = 0, lockedUntil = 0;

/* حد معدل عام: 240 طلبًا في الدقيقة لكل المسارات */
let rlWindow = 0, rlCount = 0;
function rateLimited() {
  const w = Math.floor(Date.now() / 60000);
  if (w !== rlWindow) { rlWindow = w; rlCount = 0; }
  return ++rlCount > 240;
}

/* إعادة مصادقة للعمليات الحساسة */
function reauthOk(password) {
  return typeof password === 'string' && verifyPassword(password, authRecord);
}

function newSession() {
  const token = randomBytes(32).toString('base64url');
  sessions.set(token, Date.now());
  return token;
}
function validSession(req) {
  const m = /(?:^|;\s*)admin_session=([A-Za-z0-9_-]+)/.exec(req.headers.cookie || '');
  if (!m) return false;
  const last = sessions.get(m[1]);
  if (!last || Date.now() - last > SESSION_TTL) { sessions.delete(m[1]); return false; }
  sessions.set(m[1], Date.now());
  return true;
}

/* ---------- أدوات ---------- */
const SEC_HEADERS = {
  'Content-Security-Policy':
    "default-src 'self'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; " +
    "font-src https://fonts.gstatic.com; script-src 'self' 'unsafe-inline'; " +
    "connect-src 'self' https://raw.githubusercontent.com; img-src 'self' data:; " +
    "frame-ancestors 'none'; base-uri 'none'",
  'X-Frame-Options': 'DENY',
  'X-Content-Type-Options': 'nosniff',
  'Referrer-Policy': 'no-referrer',
  'Cache-Control': 'no-store',
};
function send(res, code, body, type = 'application/json; charset=utf-8', extra = {}) {
  res.writeHead(code, { 'Content-Type': type, ...SEC_HEADERS, ...extra });
  res.end(typeof body === 'string' || Buffer.isBuffer(body) ? body : JSON.stringify(body));
}
function readBody(req) {
  return new Promise((resolve, reject) => {
    let data = '';
    req.on('data', c => { data += c; if (data.length > 64 * 1024) reject(new Error('too large')); });
    req.on('end', () => { try { resolve(data ? JSON.parse(data) : {}); } catch (e) { reject(e); } });
  });
}
function sameOrigin(req) {
  const o = req.headers.origin;
  return !o || o === `http://${HOST}:${PORT}` || o === `http://localhost:${PORT}`;
}

/* ---------- بيانات المستخدمين (وصفية فقط) ---------- */
async function fetchUsers() {
  // Firebase Auth: آخر دخول وآخر تحديث للرمز (أقرب مؤشر لآخر استخدام متصل)
  const authUsers = [];
  let pageToken;
  do {
    const page = await auth.listUsers(1000, pageToken);
    authUsers.push(...page.users);
    pageToken = page.pageToken;
  } while (pageToken);

  // Firestore: آخر مزامنة، عدد المراجعات (كل مزامنة ترفع revision)، حجم النسخة
  const snap = await db.collection('users').get();
  const meta = new Map();
  for (const doc of snap.docs) {
    const d = doc.data();
    meta.set(doc.id, {
      lastSync: d.updatedAt?.toDate?.()?.toISOString() ?? null,
      revision: typeof d.revision === 'number' ? d.revision : 0,
      backupKB: typeof d.backup === 'string' ? +(d.backup.length / 1024).toFixed(1) : 0,
      schemaVersion: d.schemaVersion ?? null,
    });
  }

  return authUsers.map(u => ({
    uid: u.uid,
    email: u.email ?? null,
    provider: u.providerData[0]?.providerId ?? 'unknown',
    disabled: u.disabled,
    createdAt: u.metadata.creationTime ? new Date(u.metadata.creationTime).toISOString() : null,
    lastSignIn: u.metadata.lastSignInTime ? new Date(u.metadata.lastSignInTime).toISOString() : null,
    lastRefresh: u.metadata.lastRefreshTime ? new Date(u.metadata.lastRefreshTime).toISOString() : null,
    ...(meta.get(u.uid) ?? { lastSync: null, revision: 0, backupKB: 0, schemaVersion: null }),
  }));
}

/* ---------- الإعلانات: مسودة ← نشر (بنسخة احتياطية) ← استرجاع ---------- */
function readJson(path, fallback) {
  try { return JSON.parse(readFileSync(path, 'utf8')); } catch { return fallback; }
}
const EMPTY_ANN = { version: 0, announcements: [] };
function readPublished() { return readJson(ANN_FILE, EMPTY_ANN); }
function readDraft() {
  if (!existsSync(DRAFT_FILE)) {
    // أول تشغيل: المسودة تبدأ نسخة من المنشور الحالي
    writeFileSync(DRAFT_FILE, JSON.stringify(readPublished(), null, 2) + '\n');
  }
  return readJson(DRAFT_FILE, EMPTY_ANN);
}
function writeDraft(data) {
  writeFileSync(DRAFT_FILE, JSON.stringify(data, null, 2) + '\n');
}
function addDraftAnnouncement({ title, body, link }) {
  if (!title?.trim() || !body?.trim()) throw new Error('العنوان والنص مطلوبان');
  if (link && !/^https:\/\/.+/.test(link)) throw new Error('الرابط يجب أن يبدأ بـ https://');
  const draft = readDraft();
  draft.announcements.unshift({
    id: 'ann-' + Date.now(),
    title: title.trim(),
    body: body.trim(),
    link: link?.trim() || null,
    publishedAt: new Date().toISOString().slice(0, 10),
  });
  draft.announcements = draft.announcements.slice(0, 20);
  writeDraft(draft);
  return draft;
}
function listBackups() {
  try { return readdirSync(BACKUP_DIR).filter(f => f.endsWith('.json')).sort().reverse(); }
  catch { return []; }
}
function publishDraft() {
  mkdirSync(BACKUP_DIR, { recursive: true });
  if (existsSync(ANN_FILE)) {
    copyFileSync(ANN_FILE, join(BACKUP_DIR, 'announcements-' + Date.now() + '.json'));
  }
  const draft = readDraft();
  const out = { version: (readPublished().version || 0) + 1, announcements: draft.announcements };
  writeFileSync(ANN_FILE, JSON.stringify(out, null, 2) + '\n');
  return out;
}
function rollbackPublished() {
  const backups = listBackups();
  if (!backups.length) throw new Error('لا توجد نسخ احتياطية للاسترجاع');
  const restored = readJson(join(BACKUP_DIR, backups[0]), null);
  if (!restored) throw new Error('النسخة الاحتياطية تالفة');
  restored.version = (readPublished().version || 0) + 1; // نسخة أعلى ليجلبها التطبيق
  writeFileSync(ANN_FILE, JSON.stringify(restored, null, 2) + '\n');
  return { restoredFrom: backups[0], data: restored };
}

/* ---------- الخادم ---------- */
const server = createServer(async (req, res) => {
  try {
    req._reqId = randomBytes(4).toString('hex');
    const url = new URL(req.url, `http://${HOST}:${PORT}`);

    if (rateLimited()) return send(res, 429, { error: 'تجاوزت حد الطلبات — انتظر دقيقة', reqId: req._reqId });

    // فحص Origin لكل الطلبات المعدِّلة (حماية CSRF إضافية فوق SameSite=Strict)
    if (req.method !== 'GET' && !sameOrigin(req)) {
      audit(req, 'csrf.blocked', url.pathname, 'denied', { origin: req.headers.origin });
      return send(res, 403, { error: 'origin', reqId: req._reqId });
    }

    /* --- عام --- */
    if (url.pathname === '/' || url.pathname === '/index.html') {
      return send(res, 200, readFileSync(join(ADMIN_DIR, 'index.html')), 'text/html; charset=utf-8');
    }
    if (url.pathname === '/api/session') {
      return send(res, 200, { authed: validSession(req) });
    }
    if (url.pathname === '/api/login' && req.method === 'POST') {
      if (Date.now() < lockedUntil) {
        audit(req, 'login', 'session', 'locked');
        return send(res, 429, { error: 'locked', minutes: Math.ceil((lockedUntil - Date.now()) / 60000) });
      }
      const { password } = await readBody(req);
      if (typeof password === 'string' && verifyPassword(password, authRecord)) {
        failedAttempts = 0;
        const token = newSession();
        audit(req, 'login', 'session', 'success');
        return send(res, 200, { ok: true }, undefined, {
          'Set-Cookie': `admin_session=${token}; HttpOnly; SameSite=Strict; Path=/; Max-Age=${SESSION_TTL / 1000}`,
        });
      }
      failedAttempts++;
      audit(req, 'login', 'session', 'failed', { attempt: failedAttempts });
      if (failedAttempts >= MAX_ATTEMPTS) { lockedUntil = Date.now() + LOCKOUT_MS; failedAttempts = 0; }
      return send(res, 401, { error: 'invalid', remaining: Math.max(0, MAX_ATTEMPTS - failedAttempts) });
    }

    /* --- محمي --- */
    if (!validSession(req)) return send(res, 401, { error: 'unauthorized' });

    if (url.pathname === '/api/logout' && req.method === 'POST') {
      const m = /admin_session=([A-Za-z0-9_-]+)/.exec(req.headers.cookie || '');
      if (m) sessions.delete(m[1]);
      return send(res, 200, { ok: true }, undefined, {
        'Set-Cookie': 'admin_session=; HttpOnly; SameSite=Strict; Path=/; Max-Age=0',
      });
    }
    if (url.pathname === '/api/users') {
      return send(res, 200, { users: await fetchUsers(), generatedAt: new Date().toISOString() });
    }
    /* --- الإعلانات: مسودة/نشر/استرجاع --- */
    if (url.pathname === '/api/announcements') {
      return send(res, 200, { draft: readDraft(), published: readPublished(), backups: listBackups() });
    }
    if (url.pathname === '/api/announce' && req.method === 'POST') {
      const data = addDraftAnnouncement(await readBody(req));
      audit(req, 'announcement.draft.add', data.announcements[0].id, 'success', { title: data.announcements[0].title });
      return send(res, 200, { ok: true, count: data.announcements.length });
    }
    if (url.pathname === '/api/announce/delete' && req.method === 'POST') {
      const { id } = await readBody(req);
      const draft = readDraft();
      draft.announcements = draft.announcements.filter(a => a.id !== id);
      writeDraft(draft);
      audit(req, 'announcement.draft.delete', id, 'success');
      return send(res, 200, { ok: true });
    }
    if (url.pathname === '/api/announce/publish' && req.method === 'POST') {
      const { password } = await readBody(req);
      if (!reauthOk(password)) {
        audit(req, 'announcement.publish', 'catalog/announcements.json', 'denied', { reason: 'reauth' });
        return send(res, 401, { error: 'كلمة المرور غير صحيحة — النشر يتطلب إعادة مصادقة' });
      }
      const out = publishDraft();
      audit(req, 'announcement.publish', 'catalog/announcements.json', 'success', { version: out.version, count: out.announcements.length });
      return send(res, 200, { ok: true, version: out.version });
    }
    if (url.pathname === '/api/announce/rollback' && req.method === 'POST') {
      const { password } = await readBody(req);
      if (!reauthOk(password)) {
        audit(req, 'announcement.rollback', 'catalog/announcements.json', 'denied', { reason: 'reauth' });
        return send(res, 401, { error: 'كلمة المرور غير صحيحة — الاسترجاع يتطلب إعادة مصادقة' });
      }
      const r = rollbackPublished();
      audit(req, 'announcement.rollback', 'catalog/announcements.json', 'success', { restoredFrom: r.restoredFrom });
      return send(res, 200, { ok: true, restoredFrom: r.restoredFrom, version: r.data.version });
    }

    /* --- الإشعار الفوري (مع منع التكرار خلال 60 ثانية) --- */
    if (url.pathname === '/api/push' && req.method === 'POST') {
      const { title, body, link } = await readBody(req);
      if (!title?.trim() || !body?.trim()) return send(res, 400, { error: 'العنوان والنص مطلوبان' });
      if (link && !/^https:\/\/.+/.test(link)) return send(res, 400, { error: 'الرابط يجب أن يبدأ بـ https://' });
      const sig = title.trim() + ' ' + body.trim();
      if (server._lastPush && server._lastPush.sig === sig && Date.now() - server._lastPush.at < 60_000) {
        audit(req, 'push.send', 'topic:all', 'blocked-duplicate', { title: title.trim() });
        return send(res, 409, { error: 'نفس الإشعار أُرسل قبل أقل من دقيقة — منع تكرار' });
      }
      try {
        const id = await getMessaging().send({
          topic: 'all',
          notification: { title: title.trim(), body: body.trim() },
          apns: { payload: { aps: { sound: 'default' } } },
          ...(link ? { data: { link: link.trim() } } : {}),
        });
        server._lastPush = { sig, at: Date.now() };
        audit(req, 'push.send', 'topic:all', 'success', { title: title.trim(), fcmId: id });
        return send(res, 200, { ok: true, id });
      } catch (e) {
        audit(req, 'push.send', 'topic:all', 'failed', { error: String(e.message).slice(0, 200) });
        throw e;
      }
    }

    /* --- إجراءات المستخدمين (كلها مسجلة في التدقيق) --- */
    if (url.pathname === '/api/users/status' && req.method === 'POST') {
      const { uid, disabled } = await readBody(req);
      if (typeof uid !== 'string' || typeof disabled !== 'boolean') return send(res, 400, { error: 'uid وdisabled مطلوبان' });
      await auth.updateUser(uid, { disabled });
      audit(req, disabled ? 'user.disable' : 'user.enable', uid, 'success');
      return send(res, 200, { ok: true });
    }
    if (url.pathname === '/api/users/revoke' && req.method === 'POST') {
      const { uid } = await readBody(req);
      if (typeof uid !== 'string') return send(res, 400, { error: 'uid مطلوب' });
      await auth.revokeRefreshTokens(uid);
      audit(req, 'user.revoke-sessions', uid, 'success');
      return send(res, 200, { ok: true });
    }
    if (url.pathname === '/api/users/delete' && req.method === 'POST') {
      const { uid, confirmEmail, password } = await readBody(req);
      if (!reauthOk(password)) {
        audit(req, 'user.delete', uid ?? '-', 'denied', { reason: 'reauth' });
        return send(res, 401, { error: 'كلمة المرور غير صحيحة — الحذف يتطلب إعادة مصادقة' });
      }
      const user = await auth.getUser(uid);
      if ((user.email ?? user.uid) !== confirmEmail) {
        audit(req, 'user.delete', uid, 'denied', { reason: 'confirm-mismatch' });
        return send(res, 400, { error: 'التأكيد الكتابي لا يطابق بريد الحساب' });
      }
      await auth.deleteUser(uid);
      try { await db.collection('users').doc(uid).delete(); } catch { /* قد لا يوجد مستند */ }
      audit(req, 'user.delete', uid, 'success', { email: user.email ?? null });
      return send(res, 200, { ok: true });
    }

    /* --- الكتالوج: قراءة وحفظ مباشر في المستودع --- */
    if (url.pathname === '/api/catalog') {
      return send(res, 200, readJson(CAT_FILE, { version: 0, updatedAt: '', services: [] }));
    }
    if (url.pathname === '/api/catalog/save' && req.method === 'POST') {
      const { catalog } = await readBody(req);
      if (!catalog || !Array.isArray(catalog.services) || !catalog.services.length) {
        return send(res, 400, { error: 'بنية الكتالوج غير صالحة' });
      }
      for (const s of catalog.services) {
        if (typeof s.name !== 'string' || !s.name.trim()) return send(res, 400, { error: 'توجد خدمة بلا اسم' });
        if (typeof s.manageUrl !== 'string' || !s.manageUrl.startsWith('https://')) {
          return send(res, 400, { error: 'رابط غير آمن في: ' + s.name });
        }
      }
      mkdirSync(BACKUP_DIR, { recursive: true });
      if (existsSync(CAT_FILE)) copyFileSync(CAT_FILE, join(BACKUP_DIR, 'services-' + Date.now() + '.json'));
      const out = {
        version: (readJson(CAT_FILE, { version: 0 }).version || 0) + 1,
        updatedAt: new Date().toISOString().slice(0, 10),
        services: catalog.services,
      };
      writeFileSync(CAT_FILE, JSON.stringify(out, null, 2) + '\n');
      audit(req, 'catalog.save', 'catalog/services.json', 'success', { count: out.services.length, version: out.version });
      return send(res, 200, { ok: true, version: out.version });
    }

    /* --- Git: حالة المحتوى ونشره إلى GitHub من اللوحة --- */
    if (url.pathname === '/api/git/status') {
      try {
        const branch = await git('rev-parse', '--abbrev-ref', 'HEAD');
        const changes = await git('status', '--porcelain', '--', 'catalog');
        return send(res, 200, { branch, changes: changes ? changes.split('\n') : [] });
      } catch (e) {
        return send(res, 200, { branch: null, error: String(e.message).slice(0, 150) });
      }
    }
    if (url.pathname === '/api/git/publish' && req.method === 'POST') {
      const { password, message } = await readBody(req);
      if (!reauthOk(password)) {
        audit(req, 'git.publish', 'catalog', 'denied', { reason: 'reauth' });
        return send(res, 401, { error: 'كلمة المرور غير صحيحة — النشر إلى GitHub يتطلب إعادة مصادقة' });
      }
      try {
        await git('add', '--', 'catalog');
        const staged = await git('status', '--porcelain', '--', 'catalog');
        if (!staged) return send(res, 200, { ok: true, nothing: true });
        await git('commit', '-m', (message?.trim() || 'تحديث المحتوى من لوحة التحكم'));
        const out = await git('push');
        audit(req, 'git.publish', 'catalog', 'success', { message: message?.trim() || null });
        return send(res, 200, { ok: true, out: out.slice(0, 300) });
      } catch (e) {
        audit(req, 'git.publish', 'catalog', 'failed', { error: String(e.message).slice(0, 200) });
        return send(res, 500, { error: 'فشل النشر: ' + String(e.message).slice(0, 200) });
      }
    }

    /* --- تغيير كلمة مرور اللوحة --- */
    if (url.pathname === '/api/password' && req.method === 'POST') {
      const { current, next } = await readBody(req);
      if (!reauthOk(current)) {
        audit(req, 'password.change', 'admin', 'denied');
        return send(res, 401, { error: 'كلمة المرور الحالية غير صحيحة' });
      }
      if (typeof next !== 'string' || next.length < 12) {
        return send(res, 400, { error: 'الكلمة الجديدة يجب أن تكون 12 حرفًا فأكثر' });
      }
      const rec = hashPassword(next);
      writeFileSync(AUTH_FILE, JSON.stringify(rec), { mode: 0o600 });
      Object.assign(authRecord, rec);
      sessions.clear();
      audit(req, 'password.change', 'admin', 'success');
      return send(res, 200, { ok: true, relogin: true });
    }

    /* --- سجل التدقيق --- */
    if (url.pathname === '/api/audit') {
      const q = url.searchParams.get('q') ?? '';
      const limit = Math.min(1000, parseInt(url.searchParams.get('limit') ?? '200', 10) || 200);
      return send(res, 200, { entries: readAudit(limit, q) });
    }

    /* --- صحة النظام --- */
    if (url.pathname === '/api/health') {
      const checks = {};
      const timed = async (name, fn) => {
        const t0 = Date.now();
        try { await fn(); checks[name] = { ok: true, ms: Date.now() - t0 }; }
        catch (e) { checks[name] = { ok: false, ms: Date.now() - t0, error: String(e.message).slice(0, 120) }; }
      };
      await timed('auth', () => auth.listUsers(1));
      await timed('firestore', () => db.collection('users').limit(1).get());
      checks.catalog = { ok: existsSync(join(ROOT, 'catalog', 'services.json')) };
      checks.announcements = { ok: existsSync(ANN_FILE) };
      checks.auditLog = { ok: existsSync(AUDIT_FILE) };
      return send(res, 200, {
        checks,
        uptimeMinutes: Math.round((Date.now() - SERVER_STARTED) / 60000),
        panelVersion: PANEL_VERSION,
        appVersion: '17.0.0+46',
        node: process.version,
        backups: listBackups().length,
        sessions: sessions.size,
      });
    }

    return send(res, 404, { error: 'not found', reqId: req._reqId });
  } catch (e) {
    return send(res, 500, { error: String(e.message || e), reqId: req._reqId });
  }
});

server.listen(PORT, HOST, () => {
  console.log(`\n⚓️ لوحة تحكم اشتراكاتي تعمل على http://${HOST}:${PORT}`);
  console.log('   • الوصول من هذا الجهاز فقط (127.0.0.1) — غير مرئية للشبكة.');
  console.log('   • بيانات المستخدمين وصفية فقط؛ التشفير E2E لا يُمسّ.');
  console.log('   • الإعلانات تُكتب في catalog/announcements.json ثم تُدفع إلى GitHub.\n');
});
