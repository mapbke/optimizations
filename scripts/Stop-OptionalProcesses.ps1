# Stops only explicitly approved user-facing apps for this session.
. "$PSScriptRoot\Common.ps1"
Assert-Windows
$targets = @(
    @{ Process = 'OneDrive'; Label = 'OneDrive sync client' },
    @{ Process = 'ms-teams'; Label = 'Microsoft Teams (new)' },
    @{ Process = 'Teams'; Label = 'Microsoft Teams (classic)' },
    @{ Process = 'Widgets'; Label = 'Windows Widgets' },
    @{ Process = 'PhoneExperienceHost'; Label = 'Phone Link' },
    @{ Process = 'Clipchamp'; Label = 'Clipchamp' }
)
Write-Warning 'Closing apps can lose unsaved work. No service, driver, Windows Security, audio or game process is modified.'
foreach ($target in $targets) {
    $found = @(Get-Process -Name $target.Process -ErrorAction SilentlyContinue)
    if ($found.Count -eq 0) { continue }
    Write-Host "$($target.Label) - $($found.Count) instance(s) active."
    if ((Read-Host "Close $($target.Process)? [y/N]") -ne 'y') { continue }
    foreach ($p in $found) {
        try { Stop-Process -Id $p.Id -ErrorAction Stop; Write-Host "Closed $($p.ProcessName) ($($p.Id))." -ForegroundColor Green }
        catch { Write-Warning "Cannot close $($p.ProcessName): $_" }
    }
}
Write-Host 'Session cleanup complete. Some processes can restart automatically.'
