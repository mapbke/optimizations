. "$PSScriptRoot\Common.ps1"
Assert-Windows
$existing = ((& powercfg.exe /getactivescheme 2>&1) -join ' ')
$match = [regex]::Match($existing, '[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}')
if (-not $match.Success) { throw "Cannot read active power scheme: $existing" }
$oldGuid = $match.Value
Write-Host "Current plan: $existing"
Write-Warning 'High Performance can raise idle power consumption/heat. It is NOT guaranteed to improve CS2 fps.'
if ((Read-Host 'Switch to built-in High Performance plan? Type YES') -cne 'YES') { exit 0 }
Write-Backup -Kind 'Power' -Payload ([ordered]@{ PreviousGuid = $oldGuid }) | Out-Null
& powercfg.exe /setactive SCHEME_MIN
if ($LASTEXITCODE -ne 0) {
    Write-Warning 'High Performance plan is absent or could not be activated. No other power tweaks attempted.'
    exit 1
}
Write-Host 'Plan changed. Undo restores the previous GUID.' -ForegroundColor Green
