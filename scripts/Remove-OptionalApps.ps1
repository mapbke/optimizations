# Deliberately non-reversible by Undo; opt-in per app and current user only.
. "$PSScriptRoot\Common.ps1"
Assert-Windows
$apps = @(
  @{ Name = 'Clipchamp.Clipchamp'; Label = 'Clipchamp video editor' },
  @{ Name = 'Microsoft.BingWeather'; Label = 'Weather' },
  @{ Name = 'Microsoft.MicrosoftSolitaireCollection'; Label = 'Solitaire Collection' },
  @{ Name = 'Microsoft.GetHelp'; Label = 'Get Help' },
  @{ Name = 'Microsoft.Getstarted'; Label = 'Get Started' },
  @{ Name = 'Microsoft.WindowsFeedbackHub'; Label = 'Feedback Hub' }
)
Write-Warning 'App removal is OPTIONAL and NOT restored by Undo. Reinstall via Microsoft Store if available.'
Write-Warning 'Only apps installed for CURRENT user are touched. Xbox, Store, Security, WebView and system packages are protected.'
if ((Read-Host 'Review optional app removal? Type REVIEW') -cne 'REVIEW') { exit 0 }
$removed = @()
foreach ($app in $apps) {
    $packages = @(Get-AppxPackage -Name $app.Name -ErrorAction SilentlyContinue)
    if ($packages.Count -eq 0) { continue }
    Write-Host "$($app.Label): $($packages[0].Name)"
    if ((Read-Host "Remove for current user? Type REMOVE") -cne 'REMOVE') { continue }
    foreach ($pkg in $packages) {
        try {
            Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
            $removed += [ordered]@{ Name = $pkg.Name; Package = $pkg.PackageFullName }
            Write-Host "Removed: $($pkg.Name)" -ForegroundColor Green
        } catch { Write-Warning "Failed: $_" }
    }
}
if ($removed.Count -gt 0) {
    $reports = Join-Path $script:Root 'reports'
    New-Item -ItemType Directory -Path $reports -Force | Out-Null
    $dest = Join-Path $reports ('removed-apps-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.json')
    @($removed) | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $dest -Encoding UTF8
    Write-Host "Removed app log: $dest"
}
Write-Host 'Done. Other accounts and Windows provisioned packages are unchanged.'
