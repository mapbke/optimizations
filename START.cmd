@echo off
setlocal
title optimizations - Windows 11
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Menu.ps1"
set "menuExit=%ERRORLEVEL%"
if not "%menuExit%"=="0" pause
exit /b %menuExit%
