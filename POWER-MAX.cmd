@echo off
setlocal
title optimizations - POWER-MAX
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Apply-Hard.ps1" -Profile Power
set "profileExit=%ERRORLEVEL%"
echo.
pause
exit /b %profileExit%
