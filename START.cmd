@echo off
setlocal EnableExtensions EnableDelayedExpansion
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
echo 10  Diagnose mouse and USB devices (read only)
echo 11  Review startup programs in Windows Settings
echo 12  MAX profile (deep Windows + power optimization)
echo 13  Optional advanced services + scheduled tasks
echo 14  Clean 7+ day old user TEMP files
echo 15  GPU options (HAGS + Game Mode Settings)
echo 16  Network (disable Windows update P2P sharing)
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
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Compare.ps1" -Before "!beforeFile!" -After "!afterFile!"
)
if "%option%"=="9" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Undo.ps1"
if "%option%"=="10" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Input-Diagnostics.ps1"
if "%option%"=="11" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Startup-Review.ps1"
if "%option%"=="12" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Pro-Optimize.ps1" -Mode Max
if "%option%"=="13" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Optional-Services.ps1"
if "%option%"=="14" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Clean-Temp.ps1"
if "%option%"=="15" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\GPU-Options.ps1"
if "%option%"=="16" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Network-Options.ps1"
if "%option%"=="0" exit /b 0
echo.
pause
goto MENU
