[CmdletBinding()]
param([ValidateSet('Safe', 'Gaming', 'Mouse', 'Desktop', 'Background')][string]$Profile = 'Safe')
. "$PSScriptRoot\Common.ps1"
Assert-Windows

$specs = @()
if ($Profile -in @('Safe', 'Gaming', 'Background')) {
    $specs += @{ Path = 'HKCU:\System\GameConfigStore'; Name = 'GameDVR_Enabled'; Value = 0; Kind = 'DWord' }
    $specs += @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'AppCaptureEnabled'; Value = 0; Kind = 'DWord' }
}
if ($Profile -eq 'Background') {
    $edge = 'HKCU:\SOFTWARE\Policies\Microsoft\Edge'
    $chrome = 'HKCU:\SOFTWARE\Policies\Google\Chrome'
    $specs += @{ Path = $edge; Name = 'StartupBoostEnabled'; Value = 0; Kind = 'DWord' }
    $specs += @{ Path = $edge; Name = 'BackgroundModeEnabled'; Value = 0; Kind = 'DWord' }
    $specs += @{ Path = $chrome; Name = 'BackgroundModeEnabled'; Value = 0; Kind = 'DWord' }
}
if ($Profile -in @('Gaming', 'Desktop')) {
    $specs += @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name = 'EnableTransparency'; Value = 0; Kind = 'DWord' }
}
if ($Profile -eq 'Desktop') {
    $specs += @{ Path = 'HKCU:\Control Panel\Desktop\WindowMetrics'; Name = 'MinAnimate'; Value = '0'; Kind = 'String' }
    $specs += @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'TaskbarAnimations'; Value = 0; Kind = 'DWord' }
}
if ($Profile -eq 'Mouse') {
    $path = 'HKCU:\Control Panel\Mouse'
    $specs += @{ Path = $path; Name = 'MouseSpeed'; Value = '0'; Kind = 'String' }
    $specs += @{ Path = $path; Name = 'MouseThreshold1'; Value = '0'; Kind = 'String' }
    $specs += @{ Path = $path; Name = 'MouseThreshold2'; Value = '0'; Kind = 'String' }
    $specs += @{ Path = $path; Name = 'MouseSensitivity'; Value = '10'; Kind = 'String' }
}
Write-Host "Profile: $Profile" -ForegroundColor Yellow
Write-Host 'Exact registry changes:'
$specs | ForEach-Object { Write-Host ("  {0}\{1} = {2} ({3})" -f $_.Path, $_.Name, $_.Value, $_.Kind) }
if ($Profile -eq 'Background') {
    Write-Warning 'Windows game capture will be disabled. Closed browsers may stop background notifications and extensions.'
}
if ((Read-Host 'Apply these changes? Type YES') -cne 'YES') { Write-Host 'Cancelled.'; return }

Invoke-RegistryProfile -Profile $Profile -Specs $specs
if ($Profile -eq 'Background') {
    Write-Host 'Relaunch Edge and Chrome, and sign out and back in for capture changes.'
} else {
    Write-Host 'Sign out and back in to refresh user settings.'
}
