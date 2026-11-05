. "$PSScriptRoot\Common.ps1"
Assert-Windows

$profiles = @{
    '3' = 'Capture'
    '5' = 'Desktop'
    '6' = 'Mouse'
}
$settingsPages = @{
    '1' = 'ms-settings:display-advanced'
    '2' = 'ms-settings:startupapps'
    '7' = 'ms-settings:display-advancedgraphics'
    '8' = 'ms-settings:gaming-gamemode'
    '9' = 'ms-settings:delivery-optimization'
}

function Write-MenuRow {
    param([int]$Number, [string]$Label, [string]$Profile)

    $row = '  {0,2}  {1,-46}' -f $Number, $Label
    if (-not $Profile) {
        Write-Host ($row.TrimEnd())
        return
    }

    Write-Host $row -NoNewline
    try {
        $specs = @(Get-ProfileSpecs -Profile $Profile)
        if (@(Get-PendingRegistryChanges -Specs $specs).Count -eq 0) {
            Write-Host '(ACTIVATED)' -ForegroundColor Green
        } else {
            Write-Host '(INACTIVE)' -ForegroundColor Gray
        }
    } catch {
        Write-Host '(UNKNOWN)' -ForegroundColor Yellow
    }
}

$notice = 'Choose a number and press Enter.'
while ($true) {
    Clear-Host
    Write-Host '  optimizations / Windows 11' -ForegroundColor Cyan
    Write-Host '  -------------------------------------------------------------'
    Write-MenuRow 1  'Monitor refresh rate'
    Write-MenuRow 2  'Windows startup apps'
    Write-MenuRow 3  'Turn off Windows game capture' -Profile ($profiles['3'])
    Write-MenuRow 4  'Close selected app windows'
    Write-MenuRow 5  'Reduce desktop animations and transparency' -Profile ($profiles['5'])
    Write-MenuRow 6  'Turn off Windows pointer acceleration' -Profile ($profiles['6'])
    Write-MenuRow 7  'Graphics settings (GPU and HAGS)'
    Write-MenuRow 8  'Game Mode settings'
    Write-MenuRow 9  'Windows Update delivery settings'
    Write-Host ''
    Write-MenuRow 10 'Mouse and USB diagnostics'
    Write-MenuRow 11 'Restore saved script changes'
    Write-MenuRow 0  'Exit'
    Write-Host '  -------------------------------------------------------------'
    Write-Host "  $notice"
    Write-Host ''

    $choice = ([string](Read-Host '  Select 0-11')).Trim()
    if ($choice -eq '0') { return }

    try {
        if ($settingsPages.ContainsKey($choice)) {
            Start-Process -FilePath ($settingsPages[$choice])
            $notice = 'Opened Windows Settings.'
            continue
        }

        Clear-Host
        if ($profiles.ContainsKey($choice)) {
            $applied = & "$PSScriptRoot\Apply-Profile.ps1" -Profile ($profiles[$choice]) -PassThru
            if ($applied) {
                $notice = 'Settings saved. Sign out and back in to refresh them.'
            } else {
                $notice = 'Cancelled.'
            }
            continue
        }

        if ($choice -notin @('4', '10', '11')) {
            $notice = 'Choose a number from 0 to 11.'
            continue
        }
        switch ($choice) {
            '4'  { & "$PSScriptRoot\Stop-OptionalProcesses.ps1" }
            '10' { & "$PSScriptRoot\Input-Diagnostics.ps1" }
            '11' { & "$PSScriptRoot\Undo.ps1" }
        }
        Write-Host ''
        [void](Read-Host 'Press Enter to return')
        $notice = 'Choose a number and press Enter.'
    } catch {
        $notice = "Error: $($_.Exception.Message)"
    }
}
