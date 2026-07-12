## Summary

- Reimagines Ishtirakati around a signature renewal orbit and a financial leakage view.
- Replaces the five-tab shell with an adaptive command-first CycleDock/rail for iPhone and iPad.
- Adds an explicit, lossless v11-to-v12 record migration and financial leakage calculations.
- Adds RTL/LTR light/dark visual coverage plus phone/iPad widget tests.
- Adds Firestore Emulator authorization tests and Android release verification to CI.

## Product decisions

- Kept local notifications, family cost splitting, AI consent, account deletion, and cloud sync behavior compatible.
- Did not add manual backup because it reintroduces a sensitive-data export path that the product previously removed.
- Did not add a lock-screen widget because App Groups and a native extension require a separate security/release cycle.
- Uses build `25`, not `12`, because the installed v11 build is `24` and Android version codes must increase.

## Security

- No changes to AES-256-GCM, Keychain-first key storage, or fail-closed storage/auth gates.
- Firestore tests prove owner access and reject cross-user, anonymous, malformed, and oversized-shape writes.
- Firebase production configuration remains sourced from GitHub Secrets.
- App Check enforcement and production rule deployment remain documented console actions.

## Verification

- [x] `flutter analyze lib test`
- [x] `flutter test` (71 test cases)
- [x] v11 migration tests
- [x] RTL/LTR light/dark golden tests
- [x] Firestore Emulator rules tests
- [x] `flutter build apk --release`
- [x] unsigned iOS archive and IPA workflow
- [x] secret-pattern scan

Evidence: [GitHub Actions run #52](https://github.com/basilsa77/ishtirakati/actions/runs/29194989604) completed successfully in 17m 25s for commit `0daf2c0`.

## Manual QA

- [ ] Upgrade a real v11 install and confirm subscriptions, settings, and encryption remain intact.
- [ ] Verify Google and Apple sign-in on a physical iPhone.
- [ ] Verify account deletion removes Auth, Firestore, and local data.
- [ ] Verify App Check metrics in TestFlight before enabling enforcement.
