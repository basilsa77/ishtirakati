@echo off
cd /d "%~dp0"
where git >nul 2>&1
if errorlevel 1 (
  set "PATH=%ProgramFiles%\Git\cmd;%PATH%"
  where git >nul 2>&1 || (
    echo Git is not installed or not available in PATH.
    pause
    exit /b 1
  )
)

set "RELEASE_VERSION=16.0.0"
set "COMMIT_MESSAGE=v16.0.0+44: publish reviewed changes"

git rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 (
  echo This folder is not a Git worktree.
  goto :failed
)

for /f "delims=" %%B in ('git branch --show-current') do set "CURRENT_BRANCH=%%B"
if not defined CURRENT_BRANCH (
  echo Detached HEAD is not publishable.
  goto :failed
)
if /I "%CURRENT_BRANCH%"=="main" (
  echo Direct publication from main is forbidden. Create a review branch first.
  goto :failed
)
if /I "%CURRENT_BRANCH%"=="master" (
  echo Direct publication from master is forbidden. Create a review branch first.
  goto :failed
)

git remote get-url origin >nul 2>&1
if errorlevel 1 (
  echo The origin remote is not configured.
  goto :failed
)

git diff --cached --quiet
if not errorlevel 1 (
  echo Nothing is explicitly staged. Review files and run git add with exact paths.
  goto :failed
)

git diff --cached --check
if errorlevel 1 goto :failed

git diff --cached --name-only | findstr /R /I /C:"\.env$" /C:"\.p8$" /C:"\.p12$" /C:"\.mobileprovision$" /C:"\.jks$" /C:"\.keystore$" /C:"GoogleService-Info.plist$" /C:"google-services.json$" >nul
if not errorlevel 1 (
  echo Refusing to commit a staged credential or signing file.
  goto :failed
)

git diff --cached --no-ext-diff -U0 | findstr /I /C:"BEGIN PRIVATE KEY" /C:"BEGIN OPENSSH PRIVATE KEY" /C:"private_key_id" >nul
if not errorlevel 1 (
  echo Refusing to commit staged content that resembles private key material.
  goto :failed
)

git commit -m "%COMMIT_MESSAGE%"
if errorlevel 1 goto :failed
git push -u origin "%CURRENT_BRANCH%"
if errorlevel 1 goto :failed

echo.
echo ===== Ishtirakati %RELEASE_VERSION% review branch pushed successfully =====
echo Branch: %CURRENT_BRANCH%
echo Open a pull request into main after CI passes.
echo Firebase build configuration is restored only from encrypted GitHub Actions secrets.
echo Local Firebase configuration files are intentionally excluded from Git.
echo Open GitHub Actions to run Build iOS IPA.
pause
exit /b 0

:failed
echo.
echo ===== Push failed =====
echo Review the messages above, GitHub login, and the staged file list.
pause
exit /b 1
