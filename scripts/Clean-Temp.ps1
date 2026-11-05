[CmdletBinding()]
param()
. "$PSScriptRoot\Common.ps1"
Assert-Windows

$path = [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')
$profile = [IO.Path]::GetFullPath($env:USERPROFILE).TrimEnd('\')
if (-not $path.StartsWith($profile + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw "Unexpected TEMP directory; refusing cleanup: $path"
}
if (-not (Test-Path -LiteralPath $path)) { throw 'TEMP folder not found' }
Write-Host "Cleaning user TEMP files older than seven days: $path"
Write-Warning 'Not a guaranteed FPS tweak. Recently used or locked files are intentionally skipped.'
if ((Read-Host 'Clean? Type CLEAN') -cne 'CLEAN') { exit }
$cutoff = (Get-Date).AddDays(-7)
$success=0; $skipped=0
foreach ($item in @(Get-ChildItem -LiteralPath $path -Force -ErrorAction SilentlyContinue)) {
    if ($item.LastWriteTime -gt $cutoff -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { $skipped++; continue }
    try {
        Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
        $success++
    } catch { $skipped++ }
}
Write-Host "Removed items: $success. Skipped/protected: $skipped."
Write-Host 'For system cleanup, use Settings > System > Storage > Temporary files.'
