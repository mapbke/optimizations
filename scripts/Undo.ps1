. "$PSScriptRoot\Common.ps1"
. "$PSScriptRoot\Power.ps1"
Assert-Windows

if (-not (Test-Path -LiteralPath $script:Backups)) {
    Write-Host 'No release backups found.'
    return
}

$lock = Enter-BackupLock
try {
    $files = @(Get-ChildItem -LiteralPath $script:Backups -Filter 'snapshot-*.json' -File | Sort-Object Name -Descending)
    $sid = Get-PackUserSid
    $needsAdmin = $false
    $pending = @(
        foreach ($file in $files) {
            $backup = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
            if ($backup.Host -ne $env:COMPUTERNAME -or $backup.UserSid -ne $sid) { continue }
            if ($backup.Schema -ne 1) { throw "Unsupported backup: $($file.Name)" }

            switch ($backup.Kind) {
                'Power' {
                    $needsAdmin = $true
                    if ($backup.Payload.Profile -ne 'PowerMax') { throw "Unexpected power plan backup: $($file.Name)" }
                }
                'Registry' {
                    $specs = @(Get-ProfileSpecs -Profile $backup.Payload.Profile)
                    $values = @($backup.Payload.Values)
                    if ($values.Count -eq 0) { throw "Empty backup: $($file.Name)" }
                    foreach ($state in $values) {
                        $allowed = $specs | Where-Object { $_.Path -eq $state.Path -and $_.Name -eq $state.Name }
                        if (-not $allowed) { throw "Unexpected registry target in $($file.Name)" }
                        if ($state.Path -like 'HKLM:\*') { $needsAdmin = $true }
                    }
                }
                default { throw "Unsupported backup: $($file.Name)" }
            }
            [pscustomobject]@{ File = $file; Backup = $backup }
        }
    )

    if ($pending.Count -eq 0) {
        Write-Host 'No saved changes for this account.'
        return
    }
    if ($needsAdmin -and -not (Test-PackAdministrator)) {
        throw 'Right-click RESTORE.cmd and choose Run as administrator using the same Windows account.'
    }
    if ((Read-Host 'Restore all saved release changes for this account? Type RESTORE') -cne 'RESTORE') { return }

    foreach ($entry in $pending) {
        if ($entry.Backup.Kind -eq 'Power') {
            Restore-PackPowerBackup -Backup $entry.Backup -File $entry.File
        } else {
            foreach ($state in $entry.Backup.Payload.Values) { Restore-RegistryState -State $state }
            Rename-Item -LiteralPath $entry.File.FullName -NewName ($entry.File.Name + '.restored')
        }
        Write-Host "Restored: $($entry.File.Name)" -ForegroundColor Green
    }
} finally {
    $lock.Dispose()
}
Write-Host 'Restore finished. Restart Windows to reload settings.'
