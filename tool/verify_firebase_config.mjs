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

if (!process.exitCode) {
  console.log('Firebase configuration files match (secret values were not printed).');
}
