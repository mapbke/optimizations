. "$PSScriptRoot\Common.ps1"
Assert-Windows
Write-Host 'GPU OPTIONS - Windows 11' -ForegroundColor Cyan
Write-Host '1) Set HAGS ON (optional, driver dependent, reboot required)'
Write-Host '2) Set HAGS OFF (optional, driver dependent, reboot required)'
Write-Host '3) Open official Windows graphics settings'
Write-Host '4) Open official Windows Game Mode settings'
Write-Host '5) Show installed NVIDIA driver version'
Write-Host '0) Exit'
$choice = Read-Host 'Choose'
if ($choice -eq '0') { exit }
switch ($choice) {
    '3' { Start-Process 'ms-settings:display-advancedgraphics'; exit }
    '4' { Start-Process 'ms-settings:gaming-gamemode'; exit }
    '5' {
        Get-CimInstance Win32_VideoController | Select-Object Name, DriverVersion, DriverDate | Format-Table -AutoSize
        exit
    }
    { $_ -in @('1','2') } {
        $id=[Security.Principal.WindowsIdentity]::GetCurrent()
        $p=New-Object Security.Principal.WindowsPrincipal($id)
        if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            Write-Host 'Please run GPU.cmd as Administrator for HAGS policy change.'
            exit 1
        }
        $value = if ($choice -eq '1') { 2 } else { 1 }
        $path = 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'
        Write-Warning 'HAGS behavior depends on the driver and GPU; this is an experimental on/off switch, NOT a universal FPS boost.'
        Write-Warning 'Windows official Graphics Settings UI should take precedence if supported.'
        if ((Read-Host 'Apply HAGS value and reboot later? Type HAGS') -cne 'HAGS') { exit }
        $state = Get-RegistryState -Path $path -Name 'HwSchMode'
        Write-Backup -Kind Registry -Payload ([ordered]@{ Profile='HAGS'; Values=@($state) }) | Out-Null
        Set-RegistrySpec -Spec @{ Path=$path; Name='HwSchMode'; Value=$value; Kind='DWord' }
        Write-Host "HwSchMode = $value; restart Windows. If anything is worse, RESTORE.cmd."
    }
    default { Write-Host 'Unknown option' }
}
