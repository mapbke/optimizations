. "$PSScriptRoot\Common.ps1"
Assert-Windows
Write-Host 'DELIVERY OPTIMIZATION P2P SHARING' -ForegroundColor Cyan
Write-Host 'This is NOT a lower-ping tweak. HTTP downloads and Windows Update still work.'
Write-Host 'Set Delivery Optimization download mode to 0 (HTTP-only, peer sharing off).'
Write-Host 'Makes sense if Windows is sending/receiving Windows update content over your LAN.'
$id=[Security.Principal.WindowsIdentity]::GetCurrent()
$p=New-Object Security.Principal.WindowsPrincipal($id)
if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'Requesting administrator permission.'
    $args = '-NoProfile -ExecutionPolicy Bypass -File "' + $PSCommandPath + '"'
    try { Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -Verb RunAs -ArgumentList $args -Wait }
    catch { Write-Warning "UAC cancelled: $_" }
    exit
}
if ((Read-Host 'Disable Windows update peer-to-peer sharing? Type P2P') -cne 'P2P') { exit }
$path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'
$state=Get-RegistryState -Path $path -Name 'DODownloadMode'
Write-Backup -Kind Registry -Payload ([ordered]@{ Profile='DeliveryOptimization'; Values=@($state) }) | Out-Null
Set-RegistrySpec -Spec @{ Path=$path; Name='DODownloadMode'; Value=0; Kind='DWord' }
Write-Host 'P2P sharing disabled via supported policy; downloading updates still enabled.' -ForegroundColor Green
Write-Host 'Restore with RESTORE.cmd.'
