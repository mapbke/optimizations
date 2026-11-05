@echo off
setlocal
title RESTORE OPTIMIZATION BACKUPS
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Undo.ps1"
set "restoreExit=%ERRORLEVEL%"
echo.
pause
exit /b %restoreExit%
