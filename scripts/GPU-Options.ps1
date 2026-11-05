. "$PSScriptRoot\Common.ps1"
Assert-Windows
Write-Host 'GPU OPTIONS - Windows 11' -ForegroundColor Cyan
Write-Host '1) Set HAGS ON (optional, driver dependent, reboot required)'
Write-Host '2) Set HAGS OFF (optional, driver dependent, reboot required)'
Write-Host '3) Open official Windows graphics settings'
Write-Host '4) Open official Windows Game Mode settings'
Write-Host '5) Show installed NVIDIA driver version'
Write-Host '6) NVIDIA / CS2 driver profile (manual settings)'
Write-Host '7) NVIDIA display flicker workaround (MPO off)'
Write-Host '8) Disable fullscreen optimizations for one cs2.exe'
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

    '6' {
        Write-Host 'NVIDIA / CS2 - NVIDIA Control Panel > Manage 3D Settings > Program Settings > cs2.exe'
        Write-Host 'Monitor technology: Fixed refresh, where available. Vertical sync: Off.'
        Write-Host 'Low Latency Mode: Off as baseline. Try Ultra separately with Reflex off in DX11.'
        Write-Host 'Max Frame Rate: Off in driver. If GPU stays saturated, try a sustainable in-game fps_max.'
        Write-Host 'Image Scaling: Off at native resolution. Texture filtering: Quality. Power: Normal.'
        Write-Host 'In CS2: fullscreen, native resolution, FSR off, Reflex off for this profile.'
        Write-Host 'Set the monitor to its highest available refresh rate in Windows or NVIDIA Control Panel.'
        Write-Host 'Apply these choices in the game and NVIDIA Control Panel.'
    }
    '7' {
        $nvidia = Get-CimInstance Win32_VideoController |
            Where-Object { $_.PNPDeviceID -like 'PCI\VEN_10DE*' }
        if (-not $nvidia) { throw 'No NVIDIA PCI display adapter found.' }
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($id)
        if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw 'Run GPU.cmd as administrator to change MPO.'
        }

        $path = 'HKLM:\SOFTWARE\Microsoft\Windows\Dwm'
        $state = Get-RegistryState -Path $path -Name 'OverlayTestMode'
        if ($state.Exists -and $state.Kind -eq 'DWord' -and $state.Value -eq 5) {
            Write-Host 'The MPO workaround is already configured.'
            exit
        }
        Write-Warning 'System-wide NVIDIA workaround for display flicker or artifacts. Requires a restart.'
        if ((Read-Host 'Disable MPO? Type MPO') -cne 'MPO') { exit }
        Write-Backup -Kind Registry -Payload ([ordered]@{ Profile='NVIDIA MPO'; Values=@($state) }) | Out-Null
        Set-RegistrySpec -Spec @{ Path=$path; Name='OverlayTestMode'; Value=5; Kind='DWord' }
        Write-Host 'Restart Windows. To undo, run RESTORE.cmd as administrator and restart again.'
    }
    '8' {
        $exe = Get-Item -LiteralPath ((Read-Host 'Full path to cs2.exe').Trim().Trim('"'))
        if ($exe -isnot [System.IO.FileInfo] -or $exe.Name -ne 'cs2.exe') {
            throw 'Select an existing cs2.exe file.'
        }

        $path = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
        $state = Get-RegistryState -Path $path -Name $exe.FullName
        $flag = 'DISABLEDXMAXIMIZEDWINDOWEDMODE'
        $value = "~ $flag"
        if ($state.Exists) {
            if ($state.Kind -ne 'String') { throw 'Unexpected type for the existing compatibility settings.' }
            if (($state.Value -split '\s+') -contains $flag) {
                Write-Host 'Fullscreen optimizations are already disabled for this file.'
                exit
            }
            $value = ($state.Value + ' ' + $flag).Trim()
        }
        Write-Host "Target: $($exe.FullName)"
        Write-Warning 'Use this option to troubleshoot fullscreen issues. Close CS2 before applying.'
        if ((Read-Host 'Disable fullscreen optimizations for this file? Type FSO') -cne 'FSO') { exit }
        Write-Backup -Kind Registry -Payload ([ordered]@{ Profile='CS2 fullscreen'; Values=@($state) }) | Out-Null
        Set-RegistrySpec -Spec @{ Path=$path; Name=$exe.FullName; Value=$value; Kind='String' }
        Write-Host 'Start CS2 again. To undo, run RESTORE.cmd.'
    }
    default { Write-Host 'Unknown option' }
}
