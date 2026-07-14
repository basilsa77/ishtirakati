import { readFile, readdir, writeFile } from 'node:fs/promises';
import path from 'node:path';

const auditAll = process.argv.includes('--all');
const roots = auditAll ? ['lib'] : ['lib/screens', 'lib/widgets'];
const files = auditAll ? [] : ['lib/main.dart', 'lib/theme.dart'];

async function walk(directory) {
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const target = path.join(directory, entry.name);
    if (auditAll && target.replaceAll('\\', '/').startsWith('lib/l10n/')) {
      continue;
    }
    if (entry.isDirectory()) await walk(target);
    if (entry.isFile() && target.endsWith('.dart')) files.push(target);
  }
}

for (const root of roots) await walk(root);

const values = new Map();
const stringLiteral = /(['"])((?:\\.|(?!\1).)*)\1/g;
const auditLatin = process.argv.includes('--latin');
for (const file of files) {
  const source = await readFile(file, 'utf8');
  for (const match of source.matchAll(stringLiteral)) {
    if (auditLatin) {
      if (!/[A-Za-z]{2,}\s+[A-Za-z]{2,}/u.test(match[2])) continue;
      if (/^(?:\.\.?\/|package:|ui_|https?:\/\/)/u.test(match[2])) continue;
    } else if (!/[\u0600-\u06ff]/u.test(match[2])) {
      continue;
    }
    const value = match[2].replaceAll('\\n', ' ');
    if (!values.has(value)) values.set(value, []);
    values.get(value).push(file);
  }
}

console.log(`unique=${values.size}`);
if (process.argv.includes('--write')) {
  await writeFile(
    auditLatin ? 'tool/ui_strings_latin.json' : 'tool/ui_strings.json',
    `${JSON.stringify([...values.keys()], null, 2)}\n`,
    'utf8',
  );
}
for (const [value, locations] of values) {
  console.log(`${value}\t${locations[0]}`);
}
