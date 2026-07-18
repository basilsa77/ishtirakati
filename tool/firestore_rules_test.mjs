import { readFile } from 'node:fs/promises';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  disableNetwork,
  doc,
  enableNetwork,
  getDoc,
  getDocFromServer,
  getDocs,
  runTransaction,
  serverTimestamp,
  setDoc,
  Timestamp,
} from 'firebase/firestore';

const projectId = 'demo-ishtirakati';
const rules = await readFile('firestore.rules', 'utf8');
const environment = await initializeTestEnvironment({
  projectId,
  firestore: { rules },
});

function base64UrlWithPadding(value) {
  return Buffer.from(value)
    .toString('base64')
    .replaceAll('+', '-')
    .replaceAll('/', '_');
}

const validNonce = base64UrlWithPadding(
  Uint8Array.from({ length: 12 }, (_, index) => index),
);
const validCiphertext = base64UrlWithPadding('{"subscriptions":[]}');
const validMac = base64UrlWithPadding(
  Uint8Array.from({ length: 16 }, (_, index) => index + 16),
);

function encryptedEnvelope({
  version = 1,
  nonce = validNonce,
  ciphertext = validCiphertext,
  mac = validMac,
  extraFields = {},
} = {}) {
  return JSON.stringify({
    v: version,
    n: nonce,
    c: ciphertext,
    m: mac,
    ...extraFields,
  });
}

function encryptedBackup({
  backup = encryptedEnvelope(),
  revision = 1,
  updatedAt = serverTimestamp(),
  schemaVersion = 2,
  encryption = 'AES-256-GCM',
  extraFields = {},
} = {}) {
  return {
    backup,
    updatedAt,
    schemaVersion,
    revision,
    encryption,
    ...extraFields,
  };
}

async function expectAllowed(label, operation) {
  await assertSucceeds(operation);
  console.log(`ALLOW ${label}`);
}

async function expectDenied(label, operation) {
  await assertFails(operation);
  console.log(`DENY ${label}`);
}

const validBackup = encryptedBackup();

const emptyCiphertextEnvelopeLength = encryptedEnvelope({
  ciphertext: '',
}).length;
const maxCiphertextLength = 850000 - emptyCiphertextEnvelopeLength;
if (maxCiphertextLength <= 0 || maxCiphertextLength % 4 !== 0) {
  throw new Error('The maximum test envelope cannot be valid Base64URL.');
}
const maxBackupEnvelope = encryptedEnvelope({
  ciphertext: 'A'.repeat(maxCiphertextLength),
});
const overLimitBackupEnvelope = encryptedEnvelope({
  ciphertext: 'A'.repeat(maxCiphertextLength + 4),
});
if (
  maxBackupEnvelope.length !== 850000 ||
  overLimitBackupEnvelope.length !== 850004
) {
  throw new Error('The backup size boundary fixtures are incorrect.');
}

const validLegacyBackup = {
  backup: '{"subscriptions":[]}',
  updatedAt: serverTimestamp(),
  schemaVersion: 1,
};

try {
  const owner = environment.authenticatedContext('owner-user').firestore();
  const envelopeOwner =
    environment.authenticatedContext('envelope-user').firestore();
  const maxOwner = environment.authenticatedContext('max-user').firestore();
  const overLimitOwner =
    environment.authenticatedContext('over-limit-user').firestore();
  const legacyOwner = environment.authenticatedContext('legacy-user').firestore();
  const unversionedOwner =
    environment.authenticatedContext('unversioned-user').firestore();
  const versionedLegacyOwner =
    environment.authenticatedContext('versioned-legacy-user').firestore();
  const intruder = environment.authenticatedContext('intruder-user').firestore();
  const anonymous = environment.unauthenticatedContext().firestore();
  const ownerRef = doc(owner, 'users/owner-user');
  const envelopeRef = doc(envelopeOwner, 'users/envelope-user');
  const maxRef = doc(maxOwner, 'users/max-user');
  const overLimitRef = doc(overLimitOwner, 'users/over-limit-user');
  const legacyRef = doc(legacyOwner, 'users/legacy-user');
  const unversionedRef = doc(unversionedOwner, 'users/unversioned-user');
  const versionedLegacyRef =
    doc(versionedLegacyOwner, 'users/versioned-legacy-user');

  await expectDenied(
    'plaintext labeled as AES-256-GCM',
    setDoc(
      envelopeRef,
      encryptedBackup({ backup: '{"subscriptions":[]}' }),
    ),
  );
  await expectDenied(
    'AES-GCM envelope with reordered keys',
    setDoc(
      envelopeRef,
      encryptedBackup({
        backup: JSON.stringify({
          v: 1,
          c: validCiphertext,
          n: validNonce,
          m: validMac,
        }),
      }),
    ),
  );
  await expectDenied(
    'AES-GCM envelope with an extra key',
    setDoc(
      envelopeRef,
      encryptedBackup({
        backup: encryptedEnvelope({ extraFields: { key: 'forbidden' } }),
      }),
    ),
  );
  await expectDenied(
    'AES-GCM envelope with the wrong version',
    setDoc(
      envelopeRef,
      encryptedBackup({ backup: encryptedEnvelope({ version: 2 }) }),
    ),
  );
  await expectDenied(
    'AES-GCM envelope with an empty ciphertext',
    setDoc(
      envelopeRef,
      encryptedBackup({ backup: encryptedEnvelope({ ciphertext: '' }) }),
    ),
  );
  await expectDenied(
    'AES-GCM envelope with an unpadded ciphertext',
    setDoc(
      envelopeRef,
      encryptedBackup({ backup: encryptedEnvelope({ ciphertext: 'YQ' }) }),
    ),
  );
  await expectDenied(
    'AES-GCM envelope with invalid ciphertext characters',
    setDoc(
      envelopeRef,
      encryptedBackup({ backup: encryptedEnvelope({ ciphertext: 'YQ!=' }) }),
    ),
  );
  await expectDenied(
    'AES-GCM envelope with an 11-byte nonce',
    setDoc(
      envelopeRef,
      encryptedBackup({
        backup: encryptedEnvelope({
          nonce: base64UrlWithPadding(Uint8Array.from({ length: 11 })),
        }),
      }),
    ),
  );
  await expectDenied(
    'AES-GCM envelope with invalid nonce characters',
    setDoc(
      envelopeRef,
      encryptedBackup({ backup: encryptedEnvelope({ nonce: '!'.repeat(16) }) }),
    ),
  );
  await expectDenied(
    'AES-GCM envelope with a 15-byte authentication tag',
    setDoc(
      envelopeRef,
      encryptedBackup({
        backup: encryptedEnvelope({
          mac: base64UrlWithPadding(Uint8Array.from({ length: 15 })),
        }),
      }),
    ),
  );
  await expectDenied(
    'AES-GCM envelope with invalid authentication-tag characters',
    setDoc(
      envelopeRef,
      encryptedBackup({
        backup: encryptedEnvelope({ mac: `${'A'.repeat(22)}!!` }),
      }),
    ),
  );
  await expectDenied(
    'AES-GCM envelope with surrounding whitespace',
    setDoc(
      envelopeRef,
      encryptedBackup({ backup: ` ${encryptedEnvelope()}` }),
    ),
  );
  await expectDenied(
    'encrypted document with the wrong schema version',
    setDoc(envelopeRef, encryptedBackup({ schemaVersion: 1 })),
  );
  await expectDenied(
    'encrypted document with the wrong encryption identifier',
    setDoc(envelopeRef, encryptedBackup({ encryption: 'AES-GCM' })),
  );
  await expectDenied(
    'encrypted document with create revision 2',
    setDoc(envelopeRef, encryptedBackup({ revision: 2 })),
  );
  await expectDenied(
    'encrypted document with a client timestamp',
    setDoc(
      envelopeRef,
      encryptedBackup({ updatedAt: Timestamp.fromMillis(0) }),
    ),
  );
  await expectDenied(
    'encrypted document with an extra top-level field',
    setDoc(
      envelopeRef,
      encryptedBackup({ extraFields: { injectedField: true } }),
    ),
  );
  await expectAllowed(
    'exact SecureDataCodec AES-GCM envelope',
    setDoc(envelopeRef, encryptedBackup()),
  );
  await expectAllowed(
    'owner deletion of envelope fixture',
    deleteDoc(envelopeRef),
  );
  await expectAllowed(
    'encrypted backup at the 850000-character limit',
    setDoc(maxRef, encryptedBackup({ backup: maxBackupEnvelope })),
  );
  await expectDenied(
    'encrypted backup over the 850000-character limit',
    setDoc(
      overLimitRef,
      encryptedBackup({ backup: overLimitBackupEnvelope }),
    ),
  );

  const missingCloudCopy = await assertSucceeds(getDocFromServer(ownerRef));
  if (missingCloudCopy.exists()) {
    throw new Error('The first synchronization document already exists.');
  }
  await assertSucceeds(
    setDoc(ownerRef, { ...validBackup, revision: 1 }, { merge: false }),
  );
  if (validBackup.backup.includes('subscriptions')) {
    throw new Error('The cloud payload contains plaintext subscription data.');
  }
  const firstCloudCopy = await assertSucceeds(getDoc(ownerRef));
  if (!firstCloudCopy.exists() || firstCloudCopy.data()?.revision !== 1) {
    throw new Error('The first encrypted cloud synchronization was not created.');
  }
  await expectDenied('stale revision update', setDoc(ownerRef, validBackup));
  await expectAllowed(
    'transaction update to revision 2',
    runTransaction(owner, async (transaction) => {
      const snapshot = await transaction.get(ownerRef);
      const currentRevision = snapshot.data()?.revision;
      if (!snapshot.exists() || currentRevision !== 1) {
        throw new Error('The existing cloud revision could not be read.');
      }
      transaction.set(ownerRef, {
        ...validBackup,
        revision: currentRevision + 1,
      });
      return currentRevision + 1;
    }),
  );
  await expectDenied(
    'non-sequential revision update',
    setDoc(ownerRef, { ...validBackup, revision: 4 }),
  );
  const copyAfterRejectedWrite = await assertSucceeds(getDoc(ownerRef));
  if (copyAfterRejectedWrite.data()?.revision !== 2) {
    throw new Error('A failed synchronization changed the last cloud copy.');
  }
  await expectDenied(
    'cross-user document read',
    getDoc(doc(intruder, 'users/owner-user')),
  );
  await expectDenied(
    'cross-user document write',
    setDoc(doc(intruder, 'users/owner-user'), validBackup),
  );
  await expectDenied(
    'cross-user document delete',
    deleteDoc(doc(intruder, 'users/owner-user')),
  );
  await expectDenied(
    'user collection enumeration',
    getDocs(collection(intruder, 'users')),
  );
  await expectDenied(
    'anonymous document read',
    getDoc(doc(anonymous, 'users/owner-user')),
  );
  await expectDenied(
    'anonymous document write',
    setDoc(doc(anonymous, 'users/owner-user'), validBackup),
  );
  await expectDenied(
    'anonymous document delete',
    deleteDoc(doc(anonymous, 'users/owner-user')),
  );
  await expectDenied(
    'nested collection write',
    setDoc(doc(owner, 'users/owner-user/subscriptions/subscription-1'), {
      name: 'must-be-rejected',
    }),
  );
  await expectDenied(
    'unmatched top-level collection write',
    setDoc(doc(owner, 'admin/config'), { enabled: true }),
  );
  await expectDenied(
    'encrypted document with an injected top-level field on update',
    setDoc(doc(owner, 'users/owner-user'), {
      ...validBackup,
      injectedField: 'must-be-rejected',
    }),
  );
  await expectDenied(
    'new plaintext legacy document',
    setDoc(legacyRef, validLegacyBackup),
  );
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'users/legacy-user'), validLegacyBackup);
    await setDoc(doc(context.firestore(), 'users/unversioned-user'), {
      backup: validLegacyBackup.backup,
      updatedAt: serverTimestamp(),
    });
    await setDoc(doc(context.firestore(), 'users/versioned-legacy-user'), {
      ...validLegacyBackup,
      revision: 7,
    });
  });
  await expectAllowed(
    'encrypted migration of legacy document without revision',
    setDoc(legacyRef, validBackup),
  );
  await expectAllowed(
    'encrypted migration of unversioned legacy document',
    setDoc(unversionedRef, validBackup),
  );
  await expectDenied(
    'plaintext downgrade after encrypted migration',
    setDoc(legacyRef, validLegacyBackup),
  );
  await expectAllowed(
    'sequential encrypted update after legacy migration',
    setDoc(legacyRef, { ...validBackup, revision: 2 }),
  );
  await expectAllowed(
    'encrypted migration preserving stored revision progression',
    setDoc(versionedLegacyRef, { ...validBackup, revision: 8 }),
  );
  await expectDenied(
    'empty backup payload',
    setDoc(doc(owner, 'users/owner-user'), {
      backup: '',
      updatedAt: serverTimestamp(),
      schemaVersion: 2,
      revision: 3,
      encryption: 'AES-256-GCM',
    }),
  );
  await disableNetwork(owner);
  let offlineFailureObserved = false;
  try {
    await getDocFromServer(ownerRef);
  } catch (error) {
    if (error?.code !== 'unavailable' && error?.code !== 'failed-precondition') {
      throw error;
    }
    offlineFailureObserved = true;
  }
  if (!offlineFailureObserved) {
    throw new Error('A server read unexpectedly succeeded while offline.');
  }
  await enableNetwork(owner);
  const recovered = await assertSucceeds(getDocFromServer(ownerRef));
  if (recovered.data()?.revision !== 2) {
    throw new Error('Recovery returned an unexpected cloud revision.');
  }
  await assertSucceeds(deleteDoc(ownerRef));
  await assertSucceeds(deleteDoc(maxRef));
  await assertSucceeds(deleteDoc(legacyRef));
  await assertSucceeds(deleteDoc(unversionedRef));
  await assertSucceeds(deleteDoc(versionedLegacyRef));
  console.log(
    'Firestore rules passed: compact AES-GCM envelope and 850000-character boundary allowed; plaintext, malformed, oversized, unauthorized, and non-sequential writes denied.',
  );
} finally {
  await environment.cleanup();
}
