. "$PSScriptRoot\Common.ps1"
Assert-Windows

while ($true) {
    Write-Host ''
    Write-Host 'optimizations / Windows 11' -ForegroundColor Cyan
    Write-Host ' 1  Monitor refresh rate'
    Write-Host ' 2  Windows startup apps'
    Write-Host ' 3  Turn off Windows game capture'
    Write-Host ' 4  Close selected optional app windows'
    Write-Host ' 5  Reduce desktop animations and transparency'
    Write-Host ' 6  Turn off Windows pointer acceleration'
    Write-Host ' 7  Graphics settings (windowed optimizations, GPU, HAGS)'
    Write-Host ' 8  Game Mode settings'
    Write-Host ' 9  Windows Update delivery settings'
    Write-Host '10  Mouse and USB diagnostics'
    Write-Host '11  Restore saved script changes'
    Write-Host ' 0  Exit'
    try {
        switch (Read-Host 'Choose') {
            '1'  { Start-Process 'ms-settings:display-advanced' }
            '2'  { Start-Process 'ms-settings:startupapps' }
            '3'  { & "$PSScriptRoot\Apply-Profile.ps1" -Profile Capture }
            '4'  { & "$PSScriptRoot\Stop-OptionalProcesses.ps1" }
            '5'  { & "$PSScriptRoot\Apply-Profile.ps1" -Profile Desktop }
            '6'  { & "$PSScriptRoot\Apply-Profile.ps1" -Profile Mouse }
            '7'  { Start-Process 'ms-settings:display-advancedgraphics' }
            '8'  { Start-Process 'ms-settings:gaming-gamemode' }
            '9'  { Start-Process 'ms-settings:delivery-optimization' }
            '10' { & "$PSScriptRoot\Input-Diagnostics.ps1" }
            '11' { & "$PSScriptRoot\Undo.ps1" }
            '0'  { return }
            default { Write-Warning 'Choose a listed option.' }
        }
    } catch {
        Write-Warning $_.Exception.Message
    }
}
