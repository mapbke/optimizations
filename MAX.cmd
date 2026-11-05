@echo off
cd /d "%~dp0"
title MAX OPTIMIZATION - WINDOWS 11 26H2
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Pro-Optimize.ps1" -Mode Max
echo.
pause
