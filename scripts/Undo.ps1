. "$PSScriptRoot\Common.ps1"
Assert-Windows

if (-not (Test-Path -LiteralPath $script:Backups)) {
    Write-Host 'No release backups found.'
    return
}
if ((Read-Host 'Restore all saved release changes for this account? Type RESTORE') -cne 'RESTORE') { return }

$lock = Enter-BackupLock
try {
    $files = @(Get-ChildItem -LiteralPath $script:Backups -Filter 'snapshot-*.json' -File | Sort-Object Name -Descending)
    $sid = Get-PackUserSid
    foreach ($file in $files) {
        $backup = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
        if ($backup.Host -ne $env:COMPUTERNAME -or $backup.UserSid -ne $sid) { continue }
        if ($backup.Schema -ne 1 -or $backup.Kind -ne 'Registry') {
            throw "Unsupported backup: $($file.Name)"
        }

        $specs = @(Get-ProfileSpecs -Profile $backup.Payload.Profile)
        $values = @($backup.Payload.Values)
        if ($values.Count -eq 0) { throw "Empty backup: $($file.Name)" }
        foreach ($state in $values) {
            $allowed = $specs | Where-Object { $_.Path -eq $state.Path -and $_.Name -eq $state.Name }
            if (-not $allowed) { throw "Unexpected registry target in $($file.Name)" }
        }
        foreach ($state in $values) { Restore-RegistryState -State $state }
        Rename-Item -LiteralPath $file.FullName -NewName ($file.Name + '.restored')
        Write-Host "Restored: $($file.Name)" -ForegroundColor Green
    }
} finally {
    $lock.Dispose()
}
Write-Host 'Restore finished. Sign out and back in if settings were restored.'
