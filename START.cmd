@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title optimizations - Windows 11 26H2
:MENU
cls
echo =========================================================
echo  OPTIMIZATIONS / WINDOWS 11 26H2 / CS2 + FACEIT
echo  Local scripts. Backups saved in backups folder.
echo =========================================================
echo  1  System diagnostic report (read only)
echo  2  SAFE profile: disable background game recording
echo  3  GAMING profile: Safe + transparent UI off
echo  4  MOUSE profile: EPP off + 6/11 pointer speed
echo  5  Stop selected optional running processes
echo  6  Remove selected optional Windows apps (manual)
echo  7  Try High Performance Windows power plan
echo  8  Compare before/after CS2 benchmark CSV
echo  9  UNDO all backed-up registry and power changes
echo  0  Exit
echo =========================================================
set "option="
set /p "option=Select option: "
if "%option%"=="1" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Report.ps1"
if "%option%"=="2" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Apply-Profile.ps1" -Profile Safe
if "%option%"=="3" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Apply-Profile.ps1" -Profile Gaming
if "%option%"=="4" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Apply-Profile.ps1" -Profile Mouse
if "%option%"=="5" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Stop-OptionalProcesses.ps1"
if "%option%"=="6" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Remove-OptionalApps.ps1"
if "%option%"=="7" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\PowerPlan.ps1"
if "%option%"=="8" (
  set "beforeFile="
  set "afterFile="
  set /p "beforeFile=Path to BEFORE CSV: "
  set /p "afterFile=Path to AFTER CSV: "
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Compare.ps1" -Before "%beforeFile%" -After "%afterFile%"
)
if "%option%"=="9" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Undo.ps1"
if "%option%"=="0" exit /b 0
echo.
pause
goto MENU
