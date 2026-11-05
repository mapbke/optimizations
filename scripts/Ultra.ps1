[CmdletBinding()]
param([switch]$Elevated)
. "$PSScriptRoot\Common.ps1"
Assert-Windows

$id = [Security.Principal.WindowsIdentity]::GetCurrent()
$p = New-Object Security.Principal.WindowsPrincipal($id)
if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'ULTRA requests administrator privileges (UAC).' -ForegroundColor Yellow
    $args = '-NoProfile -ExecutionPolicy Bypass -File "' + $PSCommandPath + '" -Elevated'
    try {
        Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -Verb RunAs -ArgumentList $args -Wait -ErrorAction Stop
    } catch { Write-Warning "UAC cancelled: $_" }
    exit
}

Write-Host 'MAPBKE / ULTRA - Windows 11 gaming desktop' -ForegroundColor Yellow
Write-Host 'Will apply:'
Write-Host '  MAX registry profile: Game DVR, UI/desktop, ads/suggestions, Edge background, mouse linear 6/11'
Write-Host '  Dedicated AC power plan: USB selective suspend OFF, PCIe ASPM OFF'
Write-Host '  Services: DiagTrack, WSearch, SysMain, MapsBroker = Disabled'
Write-Host '  Scheduled tasks: CEIP Consolidator and UsbCeip = Disabled (if available)'
Write-Host 'Your Windows Search and prefetch can become WORSE; these are NOT FPS guarantees.' -ForegroundColor Red
Write-Host 'Will NOT disable Defender, Firewall, Windows Update, Secure Boot, TPM, VBS, HVCI or IOMMU.'
Write-Host 'RESTORE.cmd stores the previous states of Registry, Power, Services and Tasks.'
if ((Read-Host 'Run aggressive preset? Type ULTRA') -cne 'ULTRA') { Write-Host 'Cancelled.'; exit }
Write-Host 'Applying MAX settings...' -ForegroundColor Cyan
& (Join-Path $PSHOME 'powershell.exe') -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\Pro-Optimize.ps1" -Mode Max -Auto
if ($LASTEXITCODE -ne 0) {
    Write-Warning 'MAX preset signalled failure. Deep service stage skipped.'
    exit 1
}
Write-Host 'Applying optional deep service and scheduled task configuration...' -ForegroundColor Cyan
& (Join-Path $PSHOME 'powershell.exe') -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\Optional-Services.ps1" -Preset All -Auto
if ($LASTEXITCODE -ne 0) { Write-Warning 'Deep stage returned an error. RESTORE.cmd is available.'; exit 1 }
Write-Host 'ULTRA completed. Restart Windows. RESTORE.cmd if functionality or frametime worsens.' -ForegroundColor Green
