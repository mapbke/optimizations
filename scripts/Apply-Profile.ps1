[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Capture', 'Desktop', 'Mouse')][string]$Profile,
    [switch]$PassThru
)
. "$PSScriptRoot\Common.ps1"
Assert-Windows

$specs = @(Get-ProfileSpecs -Profile $Profile)
switch ($Profile) {
    'Capture' { Write-Warning 'This turns off Windows game capture. Keep it enabled if you use Game Bar recordings or clips.' }
    'Desktop' { Write-Host 'Reduces animations for windows and the taskbar and turns off transparency.' }
    'Mouse'   { Write-Host 'Turns off Windows pointer acceleration and keeps your pointer speed.' }
}
$specs | ForEach-Object { Write-Verbose ("  {0}\{1} = {2}" -f $_.Path, $_.Name, $_.Value) }
if ((Read-Host 'Apply? [Y / Enter to cancel]') -notmatch '^y(es)?$') {
    if ($PassThru) { return $false }
    return
}

$lock = Enter-BackupLock
try {
    Invoke-RegistryProfile -Profile $Profile -Specs $specs
} finally {
    $lock.Dispose()
}
if ($PassThru) { return $true }
Write-Host 'Sign out and back in to refresh user settings.'
