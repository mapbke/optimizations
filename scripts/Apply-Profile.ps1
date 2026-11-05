[CmdletBinding()]
param([ValidateSet('Safe', 'Gaming', 'Mouse')][string]$Profile = 'Safe')
. "$PSScriptRoot\Common.ps1"
Assert-Windows

$specs = @()
if ($Profile -in @('Safe', 'Gaming')) {
    $specs += @{ Path = 'HKCU:\System\GameConfigStore'; Name = 'GameDVR_Enabled'; Value = 0; Kind = 'DWord' }
    $specs += @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'AppCaptureEnabled'; Value = 0; Kind = 'DWord' }
}
if ($Profile -eq 'Gaming') {
    $specs += @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name = 'EnableTransparency'; Value = 0; Kind = 'DWord' }
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
Write-Warning 'Changes may require sign-out/restart. Mouse settings do not fix broken hardware or change CS2 raw input.'
if ((Read-Host 'Apply these changes? Type YES') -cne 'YES') { Write-Host 'Cancelled.'; exit 0 }

$old = @($specs | ForEach-Object { Get-RegistryState -Path $_.Path -Name $_.Name })
Write-Backup -Kind 'Registry' -Payload ([ordered]@{ Profile = $Profile; Values = $old }) | Out-Null
foreach ($entry in $specs) { Set-RegistrySpec -Spec $entry }
Write-Host 'Applied. A sign-out or Windows restart is recommended.' -ForegroundColor Green
