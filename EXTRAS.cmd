@echo off
cd /d "%~dp0"
title OPTIONAL DEEP WINDOWS TWEAKS
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Optional-Services.ps1"
echo.
pause
