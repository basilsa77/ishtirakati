import { readFile } from 'node:fs/promises';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  disableNetwork,
  doc,
  enableNetwork,
  getDoc,
  getDocFromServer,
  serverTimestamp,
  setDoc,
} from 'firebase/firestore';

const projectId = 'demo-ishtirakati';
const rules = await readFile('firestore.rules', 'utf8');
const environment = await initializeTestEnvironment({
  projectId,
  firestore: { rules },
});

const validBackup = {
  backup: '{"v":1,"n":"bm9uY2U","c":"Y2lwaGVydGV4dA","m":"bWFj"}',
  updatedAt: serverTimestamp(),
  schemaVersion: 2,
  revision: 1,
  encryption: 'AES-256-GCM',
};

const validLegacyBackup = {
  backup: '{"subscriptions":[]}',
  updatedAt: serverTimestamp(),
  schemaVersion: 1,
};

try {
  const owner = environment.authenticatedContext('owner-user').firestore();
  const legacyOwner = environment.authenticatedContext('legacy-user').firestore();
  const unversionedOwner =
    environment.authenticatedContext('unversioned-user').firestore();
  const versionedLegacyOwner =
    environment.authenticatedContext('versioned-legacy-user').firestore();
  const intruder = environment.authenticatedContext('intruder-user').firestore();
  const anonymous = environment.unauthenticatedContext().firestore();
  const ownerRef = doc(owner, 'users/owner-user');
  const legacyRef = doc(legacyOwner, 'users/legacy-user');
  const unversionedRef = doc(unversionedOwner, 'users/unversioned-user');
  const versionedLegacyRef =
    doc(versionedLegacyOwner, 'users/versioned-legacy-user');

  await assertSucceeds(setDoc(ownerRef, validBackup));
  if (validBackup.backup.includes('subscriptions')) {
    throw new Error('The cloud payload contains plaintext subscription data.');
  }
  await assertSucceeds(getDoc(ownerRef));
  await assertFails(setDoc(ownerRef, validBackup));
  await assertSucceeds(
    setDoc(ownerRef, { ...validBackup, revision: 2 }),
  );
  await assertFails(
    setDoc(ownerRef, { ...validBackup, revision: 4 }),
  );
  await assertFails(getDoc(doc(intruder, 'users/owner-user')));
  await assertFails(setDoc(doc(intruder, 'users/owner-user'), validBackup));
  await assertFails(getDoc(doc(anonymous, 'users/owner-user')));
  await assertFails(setDoc(doc(anonymous, 'users/owner-user'), validBackup));
  await assertFails(
    setDoc(doc(owner, 'users/owner-user'), {
      ...validBackup,
      injectedField: 'must-be-rejected',
    }),
  );
  await assertFails(setDoc(legacyRef, validLegacyBackup));
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
  await assertSucceeds(
    setDoc(legacyRef, validBackup),
  );
  await assertSucceeds(
    setDoc(unversionedRef, validBackup),
  );
  await assertFails(setDoc(legacyRef, validLegacyBackup));
  await assertSucceeds(
    setDoc(legacyRef, { ...validBackup, revision: 2 }),
  );
  await assertSucceeds(
    setDoc(versionedLegacyRef, { ...validBackup, revision: 8 }),
  );
  await assertFails(
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
  await assertSucceeds(deleteDoc(legacyRef));
  await assertSucceeds(deleteDoc(unversionedRef));
  await assertSucceeds(deleteDoc(versionedLegacyRef));
  console.log('Firestore rules isolation tests passed.');
} finally {
  await environment.cleanup();
}
