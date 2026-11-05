@echo off
cd /d "%~dp0"
title CLEAN OLD TEMP FILES
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Clean-Temp.ps1"
echo.
pause
