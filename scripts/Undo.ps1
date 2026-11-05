[CmdletBinding()]
param([switch]$MachineOnly, [switch]$Confirmed)
. "$PSScriptRoot\Common.ps1"
Assert-Windows

if (-not (Test-Path $script:Backups)) { Write-Host 'No backups found.'; exit 0 }
$files = @(Get-ChildItem -LiteralPath $script:Backups -Filter 'snapshot-*.json' -File | Sort-Object Name -Descending)
if ($files.Count -eq 0) { Write-Host 'No pending backups.'; exit 0 }

$isAdmin = Test-Administrator
if ($MachineOnly -and -not $isAdmin) { throw 'Administrator privileges are required.' }
$currentSid = Get-PackUserSid
$pending = @(
    foreach ($file in $files) {
        $backup = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
        if ($backup.Host -ne $env:COMPUTERNAME) {
            Write-Warning "Backup from another computer skipped: $($file.Name)"
            continue
        }
        $hasUser = $false
        $hasMachine = $backup.Kind -in @('Power', 'Services', 'Tasks')
        if ($backup.Kind -eq 'Registry') {
            foreach ($state in @($backup.Payload.Values)) {
                switch -Regex ($state.Path) {
                    '^(HKCU:|Registry::HKEY_CURRENT_USER)\\' { $hasUser = $true }
                    '^(HKLM:|Registry::HKEY_LOCAL_MACHINE)\\' { $hasMachine = $true }
                    default { throw "Unexpected registry path in $($file.Name): $($state.Path)" }
                }
            }
        }
        if ($MachineOnly -and ($hasUser -or -not $hasMachine)) { continue }
        $owner = $backup.PSObject.Properties['UserSid']
        if ($hasUser -and $null -ne $owner -and $owner.Value -ne $currentSid) {
            Write-Warning "Backup belongs to a different Windows user: $($file.Name)"
            continue
        }
        [pscustomobject]@{ File=$file; Backup=$backup; HasUser=$hasUser; HasMachine=$hasMachine }
    }
)
if ($pending.Count -eq 0) { Write-Host 'No backups to restore for this scope.'; exit 0 }

Write-Host "Pending backup files: $($pending.Count)" -ForegroundColor Yellow
$pending | ForEach-Object { Write-Host ('  ' + $_.File.Name) }
if (-not $Confirmed -and (Read-Host 'Restore these snapshots? Type RESTORE') -cne 'RESTORE') { exit 0 }

$needsElevation = $false
if (-not $isAdmin -and @($pending | Where-Object { $_.HasUser -and $_.HasMachine }).Count -gt 0) {
    Write-Warning 'A mixed user and machine snapshot requires an administrator console under the same Windows account.'
    exit 1
}

foreach ($entry in $pending) {
    if ($entry.HasMachine -and -not $isAdmin) {
        $needsElevation = $true
        continue
    }
    $file = $entry.File
    $backup = $entry.Backup
    try {
        switch ([string]$backup.Kind) {
            'Registry' {
                foreach ($state in @($backup.Payload.Values)) { Restore-RegistryState -State $state }
            }
            'Power' {
                $profile = $backup.Payload.PSObject.Properties['Profile']
                if ($null -ne $profile -and $profile.Value -eq 'Desktop-EPP') {
                    Restore-PackPowerClone -PreviousGuid $backup.Payload.PreviousGuid -NewGuid $backup.Payload.NewGuid
                    break
                }
                $previous = [string]$backup.Payload.PreviousGuid
                $regex = '^[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$'
                if ($previous -notmatch $regex) { throw "Invalid power scheme GUID: $previous" }
                & powercfg.exe /setactive $previous | Out-Null
                if ($LASTEXITCODE -ne 0) { throw 'Could not activate old power plan' }
                $cloneProperty = $backup.Payload.PSObject.Properties['NewGuid']
                if ($null -ne $cloneProperty -and -not [string]::IsNullOrWhiteSpace([string]$cloneProperty.Value)) {
                    $newGuid = [string]$backup.Payload.NewGuid
                    if ($newGuid -notmatch $regex -or $newGuid -eq $previous) { throw 'Invalid cloned power GUID' }
                    & powercfg.exe /delete $newGuid | Out-Null
                    if ($LASTEXITCODE -ne 0) { throw "Could not remove cloned power scheme $newGuid" }
                }
            }
            'Services' {
                foreach ($svc in @($backup.Payload.Values)) {
                    $start = switch ([int]$svc.StartValue) {
                        2 { if ([int]$svc.DelayValue -eq 1) { 'delayed-auto' } else { 'auto' } }
                        3 { 'demand' }
                        4 { 'disabled' }
                        default { throw "Unsupported original service start setting $($svc.StartValue) for $($svc.Name)" }
                    }
                    & sc.exe config ([string]$svc.Name) 'start=' $start | Out-Null
                    if ($LASTEXITCODE -ne 0) { throw "Could not restore startup mode for $($svc.Name)" }
                    if ([bool]$svc.WasRunning) {
                        Start-Service -Name $svc.Name -ErrorAction Stop
                    }
                }
            }
            'Tasks' {
                foreach ($task in @($backup.Payload.Values)) {
                    if ([bool]$task.WasEnabled) {
                        Enable-ScheduledTask -TaskPath $task.Path -TaskName $task.Name -ErrorAction Stop | Out-Null
                    } else {
                        Disable-ScheduledTask -TaskPath $task.Path -TaskName $task.Name -ErrorAction Stop | Out-Null
                    }
                }
            }
            default { throw "Unknown backup kind: $($backup.Kind)" }
        }
        Rename-Item -LiteralPath $file.FullName -NewName ($file.Name + '.restored') -ErrorAction Stop
        Write-Host "Restored: $($file.Name)" -ForegroundColor Green
    } catch {
        Write-Warning "Restore error $($file.Name): $_"
        Write-Warning 'This and older backups remain pending. Fix the error before retrying.'
        if ($MachineOnly) { [void](Read-Host 'Press Enter to return') }
        exit 1
    }
}
if ($needsElevation) {
    Write-Host 'Requesting UAC to restore machine-wide settings.'
    Invoke-PackElevated -Path $PSCommandPath -Arguments @('-MachineOnly', '-Confirmed')
}
Write-Host 'Restore finished. Restart Windows or sign out and back in.' -ForegroundColor Green
