@echo off
setlocal
title optimizations - UPDATE-LIMIT
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Apply-Hard.ps1" -Profile Delivery
set "profileExit=%ERRORLEVEL%"
echo.
pause
exit /b %profileExit%
