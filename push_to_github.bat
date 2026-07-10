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

git init
git config user.name "basilsa77"
git config user.email "basilsa77@users.noreply.github.com"

git branch -M main
git remote get-url origin >nul 2>&1 || git remote add origin https://github.com/basilsa77/ishtirakati.git

git add .
git diff --cached --quiet
if errorlevel 1 (
  git commit -m "Improve security and subscription import validation"
  if errorlevel 1 goto :failed
) else (
  echo No new changes to commit.
)

git pull --rebase origin main
if errorlevel 1 goto :failed
git push -u origin main
if errorlevel 1 goto :failed

echo.
echo ===== Project pushed successfully =====
echo Open GitHub Actions to run Build iOS IPA.
pause
exit /b 0

:failed
echo.
echo ===== Push failed =====
echo Check GitHub login and resolve any merge conflicts.
pause
exit /b 1
