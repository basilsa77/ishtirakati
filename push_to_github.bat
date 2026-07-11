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

set "RELEASE_VERSION=10.0.0"
set "COMMIT_MESSAGE=v10.0.0: fix full-app Dart compilation"

git init
git config user.name "basilsa77"
git config user.email "basilsa77@users.noreply.github.com"

git branch -M main
git remote get-url origin >nul 2>&1 || git remote add origin https://github.com/basilsa77/ishtirakati.git

git add .
git diff --cached --quiet
if errorlevel 1 (
  git commit -m "%COMMIT_MESSAGE%"
  if errorlevel 1 goto :failed
) else (
  echo No new changes to commit.
)

git pull --rebase origin main
if errorlevel 1 goto :failed
git push -u origin main
if errorlevel 1 goto :failed

echo.
echo ===== Ishtirakati %RELEASE_VERSION% pushed successfully =====
echo Firebase build configuration is restored only from encrypted GitHub Actions secrets.
echo Local Firebase configuration files are intentionally excluded from Git.
echo Open GitHub Actions to run Build iOS IPA.
pause
exit /b 0

:failed
echo.
echo ===== Push failed =====
echo Check GitHub login and resolve any merge conflicts.
pause
exit /b 1
