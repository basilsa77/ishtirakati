import { readFile } from 'node:fs/promises';

function fail(message) {
  console.error(`Firebase configuration check failed: ${message}`);
  process.exitCode = 1;
}

function plistValue(source, key) {
  const pattern = new RegExp(`<key>${key}</key>\\s*<string>([^<]+)</string>`);
  return source.match(pattern)?.[1]?.trim() ?? '';
}

function dartValue(source, key) {
  const token = source.match(new RegExp(`${key}:\\s*([^,\\n]+)`))?.[1]?.trim();
  if (!token) return '';
  const literal = token.match(/^['"]([^'"]+)['"]$/)?.[1];
  if (literal) return literal;
  const identifier = token.match(/^[A-Za-z_]\w*$/)?.[0];
  if (!identifier) return '';
  const assignment = source.match(
    new RegExp(`(?:static\\s+)?const\\s+String\\s+${identifier}\\s*=([\\s\\S]*?);`),
  )?.[1];
  if (!assignment) return '';
  return assignment.match(/defaultValue:\s*['"]([^'"]+)['"]/)?.[1]
      ?? assignment.match(/['"]([^'"]+)['"]/)?.[1]
      ?? '';
}

const plist = await readFile('GoogleService-Info.plist', 'utf8');
const dart = await readFile('lib/firebase_options.dart', 'utf8');
const expectedBundleId = 'com.basil.ishtirakati';
const expectedProjectId = 'ishtirakati-260f7';
const expectedAppId = '1:49076094328:ios:5d299c3b8960ef52fc748d';
const expectedSenderId = '49076094328';
const expectedStorageBucket = 'ishtirakati-260f7.firebasestorage.app';

const comparisons = [
  ['API key', plistValue(plist, 'API_KEY'), dartValue(dart, 'apiKey')],
  ['app id', plistValue(plist, 'GOOGLE_APP_ID'), dartValue(dart, 'appId')],
  ['project id', plistValue(plist, 'PROJECT_ID'), dartValue(dart, 'projectId')],
];

for (const [label, plistValueText, dartValueText] of comparisons) {
  if (!plistValueText || !dartValueText) fail(`${label} is missing`);
  if (plistValueText !== dartValueText) fail(`${label} does not match`);
}

const plistBundle = plistValue(plist, 'BUNDLE_ID');
const dartBundle = dart.match(/_iosBundleId\s*=\s*['"]([^'"]+)['"]/)?.[1] ?? '';
if (plistBundle !== expectedBundleId || dartBundle !== expectedBundleId) {
  fail('iOS bundle id does not match the production identifier');
}

const expectedValues = [
  ['project id', plistValue(plist, 'PROJECT_ID'), expectedProjectId],
  ['app id', plistValue(plist, 'GOOGLE_APP_ID'), expectedAppId],
  ['sender id', plistValue(plist, 'GCM_SENDER_ID'), expectedSenderId],
  ['storage bucket', plistValue(plist, 'STORAGE_BUCKET'), expectedStorageBucket],
  ['Dart storage bucket', dartValue(dart, 'storageBucket'), expectedStorageBucket],
];

for (const [label, actual, expected] of expectedValues) {
  if (actual !== expected) fail(`${label} is not the production Firebase value`);
}

if (!process.exitCode) {
  console.log('Firebase configuration files match (secret values were not printed).');
}
