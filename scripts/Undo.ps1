. "$PSScriptRoot\Common.ps1"
Assert-Windows

if (-not (Test-Path $script:Backups)) { Write-Host 'No backups found.'; exit 0 }
$files = @(Get-ChildItem -LiteralPath $script:Backups -Filter 'snapshot-*.json' -File | Sort-Object LastWriteTime -Descending)
if ($files.Count -eq 0) { Write-Host 'No pending backups.'; exit 0 }

$requiresAdmin = $false
foreach ($file in $files) {
    try {
        $info = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
        if ($info.Kind -in @('Power','Services','Tasks')) { $requiresAdmin = $true }
    } catch {}
}
if ($requiresAdmin) {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($id)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host 'Requesting UAC to restore services, tasks and power plans.'
        $args = '-NoProfile -ExecutionPolicy Bypass -File "' + $PSCommandPath + '"'
        try { Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList $args -Verb RunAs -Wait }
        catch { Write-Warning "UAC cancelled: $_" }
        exit
    }
}

Write-Host "Pending backup files: $($files.Count)" -ForegroundColor Yellow
$files | ForEach-Object { Write-Host ('  ' + $_.Name) }
Write-Warning 'Restores tracked Registry, Windows services, scheduled tasks, power plan. Deleted Appx packages are NOT restored.'
if ((Read-Host 'Restore? Type RESTORE') -cne 'RESTORE') { exit 0 }

foreach ($file in $files) {
    try {
        $backup = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
        if ($backup.Host -ne $env:COMPUTERNAME) {
            Write-Warning "Backup from another computer skipped: $($file.Name)"
            continue
        }
        switch ([string]$backup.Kind) {
            'Registry' {
                foreach ($state in @($backup.Payload.Values)) { Restore-RegistryState -State $state }
            }
            'Power' {
                $previous = [string]$backup.Payload.PreviousGuid
                $regex = '^[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$'
                if ($previous -notmatch $regex) { throw "Invalid power scheme GUID: $previous" }
                & powercfg.exe /setactive $previous | Out-Null
                if ($LASTEXITCODE -ne 0) { throw 'Could not activate old power plan' }
                if ($null -ne $backup.Payload.NewGuid) {
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
        Write-Warning 'Backup kept pending so you can inspect and retry manually.'
    }
}
Write-Host 'Restore completed for every successful snapshot. Restart Windows.' -ForegroundColor Green
