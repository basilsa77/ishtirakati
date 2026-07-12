import { readFile, writeFile } from 'node:fs/promises';

const path = 'android/app/build.gradle.kts';
const source = await readFile(path, 'utf8');
const marker = '    compileOptions {';
const blockStart = source.indexOf(marker);
const secondBlock = source.indexOf(marker, blockStart + marker.length);
const blockEnd = source.indexOf('\n    }', blockStart);

if (blockStart < 0 || blockEnd < 0 || secondBlock >= 0) {
  throw new Error('Flutter Android compileOptions template changed; refusing a partial patch.');
}

const compileFlag = '\n        isCoreLibraryDesugaringEnabled = true';
const withDesugaring =
  source.slice(0, blockEnd) + compileFlag + source.slice(blockEnd);
const output = `${withDesugaring.trimEnd()}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
`;

if (!output.includes('isCoreLibraryDesugaringEnabled = true') ||
    !output.includes('coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")')) {
  throw new Error('Android desugaring validation failed.');
}

await writeFile(path, output, 'utf8');
console.log('Android release build configured with Java 17 desugaring.');
