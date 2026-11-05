@echo off
cd /d "%~dp0"
title OPTIONAL WINDOWS APP REMOVAL
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Remove-OptionalApps.ps1"
echo.
pause
