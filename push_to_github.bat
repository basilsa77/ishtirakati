@echo off
chcp 65001 >nul
cd /d "%~dp0"
where git >nul 2>&1 || set "PATH=%ProgramFiles%\Git\cmd;%PATH%"
git init
git config user.name "basilsa77"
git config user.email "basilsa77@users.noreply.github.com"
git add .
git commit -m "v2.0: redesign + budget + backup + insights"
git branch -M main
git remote remove origin 2>nul
git remote add origin https://github.com/basilsa77/ishtirakati.git
git push -u origin main
echo.
echo ===== DONE - يمكنك اغلاق النافذة =====
pause
