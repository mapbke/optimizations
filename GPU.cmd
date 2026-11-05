@echo off
cd /d "%~dp0"
title GPU / HAGS / GAME MODE
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\GPU-Options.ps1"
echo.
pause
