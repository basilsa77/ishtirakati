# Firebase configuration for GitHub Actions

Firebase client configuration must not be committed to the repository. The iOS build workflow restores it from two repository secrets.

Create these secrets in GitHub: `Settings` > `Secrets and variables` > `Actions`.

| Secret | Local source |
| --- | --- |
| `GOOGLE_SERVICE_INFO_PLIST_B64` | `GoogleService-Info.plist` |
| `FIREBASE_OPTIONS_DART_B64` | `lib/firebase_options.dart` |

Run these commands in PowerShell from the project folder. Copy each entire output into its matching GitHub secret.

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('GoogleService-Info.plist'))
[Convert]::ToBase64String([IO.File]::ReadAllBytes('lib/firebase_options.dart'))
```

After the secrets are saved, run `push_to_github.bat`. The workflow will restore the files only inside the temporary GitHub runner used for the build.

Important: Removing the files from Git does not remove a key from the existing Git history. Restrict or rotate the exposed Google API key in Google Cloud Console before closing the GitHub secret-scanning alert.

## Deploy Firestore rules to production

The `Deploy Firestore Rules` workflow is manual (`workflow_dispatch`) and is pinned to project `ishtirakati-260f7`.

1. Open Google Cloud Console for `ishtirakati-260f7`.
2. Go to `IAM & Admin` > `Service Accounts` and create a service account named `github-firestore-deployer`.
3. Grant only `Firebase Rules Admin` and `Cloud Datastore Index Admin` on this project.
4. Open the service account, choose `Keys` > `Add key` > `Create new key` > `JSON`.
5. In GitHub open `Settings` > `Secrets and variables` > `Actions` > `New repository secret`.
6. Name it `FIREBASE_SERVICE_ACCOUNT_ISHTIRAKATI_260F7` and paste the complete JSON file contents.
7. Delete the downloaded JSON file from the computer after saving the secret.
8. Open `Actions` > `Deploy Firestore Rules` > `Run workflow` > `Run workflow`.
9. The run must show `Deploy complete!` and `Project Console: https://console.firebase.google.com/project/ishtirakati-260f7/overview` before the rules are considered deployed.

The workflow validates that the service account JSON contains `project_id=ishtirakati-260f7` and refuses to deploy to any other project. Never commit this JSON file.
