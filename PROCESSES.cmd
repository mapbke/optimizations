@echo off
cd /d "%~dp0"
title OPTIONAL BACKGROUND PROCESS CLEANUP
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Stop-OptionalProcesses.ps1"
echo.
pause
