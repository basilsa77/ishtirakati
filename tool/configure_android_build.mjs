import { readFile, writeFile } from 'node:fs/promises';

const path = 'android/app/build.gradle.kts';
const source = await readFile(path, 'utf8');
const compileBlock = `    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }`;
const hardenedCompileBlock = `    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }`;

if (!source.includes(compileBlock)) {
  throw new Error('Flutter Android compileOptions template changed; refusing a partial patch.');
}

const output = `${source.replace(compileBlock, hardenedCompileBlock).trimEnd()}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
`;

await writeFile(path, output, 'utf8');
console.log('Android release build configured with Java 17 desugaring.');

