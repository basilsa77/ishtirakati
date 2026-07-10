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
