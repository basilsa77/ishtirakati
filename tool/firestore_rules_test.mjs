import { readFile } from 'node:fs/promises';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
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
  backup: '{"subscriptions":[]}',
  updatedAt: serverTimestamp(),
  schemaVersion: 1,
};

try {
  const owner = environment.authenticatedContext('owner-user').firestore();
  const intruder = environment.authenticatedContext('intruder-user').firestore();
  const anonymous = environment.unauthenticatedContext().firestore();
  const ownerRef = doc(owner, 'users/owner-user');

  await assertSucceeds(setDoc(ownerRef, validBackup));
  await assertSucceeds(getDoc(ownerRef));
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
  await assertFails(
    setDoc(doc(owner, 'users/owner-user'), {
      backup: '',
      updatedAt: serverTimestamp(),
      schemaVersion: 1,
    }),
  );
  await assertSucceeds(deleteDoc(ownerRef));
  console.log('Firestore rules isolation tests passed.');
} finally {
  await environment.cleanup();
}

