[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Power', 'Delivery', 'Widgets', 'Drive')][string]$Action,
    [switch]$ElevatedChild
)
. "$PSScriptRoot\Common.ps1"
Assert-Windows

function Set-DesktopPowerPlan {
    $previous = Get-PackActivePowerGuid
    if (Test-Path -LiteralPath $script:Backups) {
        foreach ($file in Get-ChildItem -LiteralPath $script:Backups -Filter 'snapshot-*-Power-*.json' -File) {
            try {
                $backup = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
                $profile = $backup.Payload.PSObject.Properties['Profile']
                if ($backup.Host -eq $env:COMPUTERNAME -and $null -ne $profile -and
                    $profile.Value -eq 'Desktop-EPP' -and $backup.Payload.NewGuid -eq $previous.ToString()) {
                    Write-Host 'The pack AC power plan is already active.'
                    return
                }
            } catch {
                continue
            }
        }
    }

    $aliases = (Invoke-PackPowerCfg @('/aliases')) -join [Environment]::NewLine
    if ($aliases -notmatch '\bPERFEPP\b') { throw 'Processor Energy Performance Preference is unavailable.' }
    Write-Host "Current power plan: $previous"
    Write-Host 'Clone the current plan and favor CPU performance on AC power (EPP = 0).'
    Write-Warning 'This can increase power consumption and temperature. Benefit depends on the processor and firmware.'
    if ((Read-Host 'Activate the new AC power plan? Type POWER') -cne 'POWER') { return }
    if ((Get-PackActivePowerGuid) -ne $previous) { throw 'The active plan changed. Retry with the desired base plan.' }

    $new = [guid]::NewGuid()
    $snapshot = Write-Backup -Kind Power -Payload ([ordered]@{
        Profile = 'Desktop-EPP'
        PreviousGuid = $previous.ToString()
        NewGuid = $new.ToString()
    })
    try {
        Invoke-PackPowerCfg @('/duplicatescheme', $previous.ToString(), $new.ToString()) | Out-Null
        Invoke-PackPowerCfg @('/changename', $new.ToString(), 'Mapbke Responsive AC') | Out-Null
        Invoke-PackPowerCfg @('/setacvalueindex', $new.ToString(), 'SUB_PROCESSOR', 'PERFEPP', '0') | Out-Null
        if ($aliases -match '\bPERFEPP1\b') {
            Invoke-PackPowerCfg @('/setacvalueindex', $new.ToString(), 'SUB_PROCESSOR', 'PERFEPP1', '0') | Out-Null
        }
        if ((Get-PackActivePowerGuid) -ne $previous) { throw 'The active power plan changed while preparing the clone.' }
        Invoke-PackPowerCfg @('/setactive', $new.ToString()) | Out-Null
        if ((Get-PackActivePowerGuid) -ne $new) { throw 'Windows did not activate the new plan.' }
    } catch {
        $failure = $_
        try {
            Restore-PackPowerClone -PreviousGuid $previous -NewGuid $new
            Rename-Item -LiteralPath $snapshot -NewName ((Split-Path -Leaf $snapshot) + '.restored')
        } catch {
            Write-Warning "Power rollback incomplete. Keep the snapshot and run RESTORE.cmd. $_"
        }
        throw $failure
    }
    Write-Host 'Mapbke Responsive AC is active. RESTORE.cmd removes the clone.'
}

function Set-DesktopDeliveryPolicy {
    $path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'
    $specs = @(@{ Path = $path; Name = 'DODownloadMode'; Value = 0; Kind = 'DWord' })
    Write-Host 'Use HTTP sources for Delivery Optimization instead of peer sharing.'
    $answer = (Read-Host 'Optional background limit in KB/s (256-102400, e.g. 2048), or Enter to leave it alone').Trim()
    if ($answer) {
        $limit = 0
        if (-not [int]::TryParse($answer, [ref]$limit) -or $limit -lt 256 -or $limit -gt 102400) {
            throw 'Invalid background bandwidth limit.'
        }
        $specs += @{ Path = $path; Name = 'DOMaxBackgroundDownloadBandwidth'; Value = $limit; Kind = 'DWord' }
        Write-Host "Background Delivery Optimization downloads will be capped at $limit KB/s."
    }
    if ((Read-Host 'Apply Delivery Optimization settings? Type DELIVERY') -cne 'DELIVERY') { return }
    Invoke-RegistryProfile -Profile 'Desktop delivery' -Specs $specs
    Write-Host 'Use RESTORE.cmd to restore the previous policies.'
}

function Disable-DesktopWidgets {
    $windows = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    if ([int]$windows.CurrentBuildNumber -lt 22000 -or $windows.EditionID -notmatch '^(Professional|Enterprise|Education|IoTEnterprise)') {
        Write-Warning 'The device-wide Widgets policy is supported on Windows 11 Pro, Enterprise and Education editions.'
        return
    }
    Write-Host 'Disable the Windows Widgets feature for this device.'
    if ((Read-Host 'Apply Widgets policy? Type WIDGETS') -cne 'WIDGETS') { return }
    $spec = @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'; Name = 'AllowNewsAndInterests'; Value = 0; Kind = 'DWord' }
    Invoke-RegistryProfile -Profile 'Desktop widgets' -Specs @($spec)
    Write-Host 'Sign out and back in. Use RESTORE.cmd to restore the original policy.'
}

function Invoke-DesktopDriveMaintenance {
    $volumes = @(Get-Volume | Where-Object {
        $_.DriveLetter -and $_.DriveType -eq 'Fixed' -and $_.HealthStatus -eq 'Healthy' -and $_.FileSystem -eq 'NTFS'
    })
    if ($volumes.Count -eq 0) { Write-Host 'No healthy fixed NTFS volumes found.'; return }
    $volumes | Select-Object DriveLetter, FileSystemLabel, SizeRemaining, Size | Format-Table -AutoSize | Out-Host
    $letter = (Read-Host 'Select one drive letter, or Enter to cancel').Trim().ToUpperInvariant()
    if (-not $letter) { return }
    if ($letter -notmatch '^[A-Z]$' -or $letter -notin $volumes.DriveLetter) { throw 'Select a volume shown above.' }
    Write-Warning 'Run when the computer is idle. Windows chooses the operation based on the storage type.'
    if ((Read-Host "Optimize drive $($letter):? Type OPTIMIZE") -cne 'OPTIMIZE') { return }
    Optimize-Volume -DriveLetter $letter -Verbose -ErrorAction Stop
}

if (-not (Test-Administrator)) {
    if ($ElevatedChild) { throw 'Administrator privileges are required.' }
    Invoke-PackElevated -Path $PSCommandPath -Arguments @('-Action', $Action, '-ElevatedChild')
    return
}

try {
    switch ($Action) {
        'Power' { Set-DesktopPowerPlan }
        'Delivery' { Set-DesktopDeliveryPolicy }
        'Widgets' { Disable-DesktopWidgets }
        'Drive' { Invoke-DesktopDriveMaintenance }
    }
} catch {
    Write-Warning $_
    exit 1
} finally {
    if ($ElevatedChild) { [void](Read-Host 'Press Enter to return') }
}
