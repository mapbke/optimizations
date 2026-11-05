. "$PSScriptRoot\Common.ps1"
Assert-Windows
if (-not (Test-Path $script:Backups)) { Write-Host 'No backups found.'; exit 0 }
$files = @(Get-ChildItem -LiteralPath $script:Backups -Filter 'snapshot-*.json' -File | Sort-Object LastWriteTime -Descending)
if ($files.Count -eq 0) { Write-Host 'No pending backups.'; exit 0 }
Write-Host "Found $($files.Count) pending backup(s):" -ForegroundColor Yellow
$files | ForEach-Object { Write-Host ('  ' + $_.Name) }
Write-Warning 'This will restore all tracked registry keys and the previous power plan in reverse order. Removed apps are NOT restored.'
if ((Read-Host 'Restore? Type RESTORE') -cne 'RESTORE') { Write-Host 'Cancelled.'; exit 0 }
foreach ($file in $files) {
    try {
        $backup = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
        if ($backup.Host -ne $env:COMPUTERNAME) {
            Write-Warning "Skipping backup from another computer: $($file.Name)"
            continue
        }
        switch ($backup.Kind) {
            'Registry' {
                foreach ($state in @($backup.Payload.Values)) { Restore-RegistryState -State $state }
            }
            'Power' {
                $guid = [string]$backup.Payload.PreviousGuid
                if ($guid -notmatch '^[0-9a-fA-F-]{36}$') { throw "Invalid stored power GUID: $guid" }
                & powercfg.exe /setactive $guid | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "powercfg failed with code $LASTEXITCODE" }
            }
            default { throw "Unknown backup kind: $($backup.Kind)" }
        }
        Rename-Item -LiteralPath $file.FullName -NewName ($file.Name + '.restored')
        Write-Host "Restored: $($file.Name)" -ForegroundColor Green
    } catch {
        Write-Warning "Could not fully restore $($file.Name): $_"
        Write-Warning 'This file remains pending for manual review/retry.'
    }
}
Write-Host 'Done. Restart Windows to apply user-interface and mouse changes.'
