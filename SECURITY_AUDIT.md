# Security Audit - 7.1.1

## Implemented Protections

- Subscription records are encrypted locally with AES-256-GCM. The random encryption key is held in iOS Keychain and is accessible only while the device is unlocked; it does not migrate to another device.
- The Gemini API key and remembered email address use iOS Keychain with the same device-only accessibility policy. Email app passwords are never stored and are cleared after an IMAP request.
- The optional app lock uses biometric authentication only and locks again as soon as the application becomes inactive or moves to the background.
- Firestore access is restricted to the authenticated owner of `/users/{uid}`. The included rules also validate the allowed backup fields, type, size, and schema version.
- Cloud requests, Gemini requests, catalog updates, iTunes search, and update checks use HTTPS. User-managed subscription links must now be valid HTTPS URLs before the app opens them.
- Imports are limited to 2 MiB and 5,000 records to prevent oversized clipboard or cloud payloads from exhausting the app.
- GitHub Actions uses read-only repository permissions, does not retain checkout credentials, and obfuscates Dart symbols in release IPA builds. Symbol files are saved as a separate developer artifact.

## Important Limits

- The Firestore backup is protected by TLS, Firebase encryption at rest, Firebase Authentication, and Firestore rules. It is not end-to-end encrypted with a user recovery passphrase. Building true cross-device end-to-end encryption requires a recovery-passphrase experience and must not be simulated by storing the decryption key beside the backup.
- A Firebase API key and OAuth client identifiers are application configuration, not client secrets. They cannot be hidden in a mobile IPA. Restrict the API key to the iOS bundle ID in Google Cloud Console.
- No mobile application can guarantee protection against a jailbroken device, a compromised Apple/Google account, malicious screen recording, or an attacker who knows the device passcode and can unlock the phone.

## Required Console Checks

1. Publish the exact rules in `firestore.rules` to the Firestore Rules tab.
2. In Firebase App Check, register the iOS app and monitor requests. Add App Attest enforcement only after updating the Firebase dependencies and testing a signed build.
3. Restrict the Firebase API key to `com.basil.ishtirakati` in Google Cloud Console.
4. Keep Google Sign-In enabled only in Firebase Authentication and periodically review Firebase Authentication users and Firestore usage.
5. Generate and commit `pubspec.lock` from a trusted Flutter installation before a production release so dependency resolution is reproducible.
