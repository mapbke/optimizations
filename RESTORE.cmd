@echo off
cd /d "%~dp0"
title RESTORE OPTIMIZATION BACKUPS
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Undo.ps1"
echo.
pause
