@echo off
setlocal
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Stop-OptionalProcesses.ps1"
set "processExit=%ERRORLEVEL%"
pause
exit /b %processExit%
