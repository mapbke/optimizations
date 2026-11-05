@echo off
cd /d "%~dp0"
title WINDOWS DELIVERY OPTIMIZATION - NETWORK
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Network-Options.ps1"
echo.
pause
