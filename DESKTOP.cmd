@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Desktop-Options.ps1"
set "desktopExit=%ERRORLEVEL%"
pause
exit /b %desktopExit%
