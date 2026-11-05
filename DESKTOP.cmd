@echo off
setlocal
title optimizations - Windows 11 desktop pack
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Desktop-Options.ps1"
exit /b %ERRORLEVEL%
