@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Game-Session.ps1"
set "sessionExit=%ERRORLEVEL%"
pause
exit /b %sessionExit%
