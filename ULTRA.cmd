@echo off
cd /d "%~dp0"
title ULTRA OPTIMIZATION - WINDOWS 11 26H2
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Ultra.ps1"
echo.
pause
