. "$PSScriptRoot\Common.ps1"
Assert-Windows
$paths = @(
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'
)
Write-Host 'Startup registry entries (read only):' -ForegroundColor Cyan
foreach ($path in $paths) {
    Write-Host ("  " + $path) -ForegroundColor Yellow
    if (-not (Test-Path -LiteralPath $path)) { continue }
    $key = Get-Item -LiteralPath $path
    foreach ($name in @($key.GetValueNames())) {
        Write-Host ("    " + $name)
    }
}
Write-Host ''
Write-Host 'Opening Windows Settings > Apps > Startup. Review items such as cloud sync, auto-launch chat apps, launchers and vendor updaters.'
Write-Warning 'Do NOT disable hardware, security, audio, driver or anti-cheat services. This script only opens the official Settings UI.'
try { Start-Process 'ms-settings:startupapps' } catch { Write-Warning "Cannot open Startup settings: $_" }
