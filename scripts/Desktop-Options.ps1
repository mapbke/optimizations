. "$PSScriptRoot\Common.ps1"
Assert-Windows

function Disable-OptionalStartupApp {
    $path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
    $optionalApps = @('Steam', 'Discord', 'Spotify', 'OneDrive', 'EpicGamesLauncher', 'Battle.net')
    $entries = @(
        foreach ($name in $optionalApps) {
            $state = Get-RegistryState -Path $path -Name $name
            if ($state.Exists -and $state.Kind -in @('String', 'ExpandString')) { $state }
        }
    )
    if ($entries.Count -eq 0) {
        Write-Host 'No supported entries found in your Run key. Use Windows Startup settings for other apps.'
        return
    }

    for ($index = 0; $index -lt $entries.Count; $index++) {
        Write-Host ("{0}) {1}" -f ($index + 1), $entries[$index].Name)
    }
    $number = 0
    $answer = Read-Host 'Select one app by number, or press Enter to cancel'
    if (-not $answer) { return }
    if (-not [int]::TryParse($answer, [ref]$number) -or $number -lt 1 -or $number -gt $entries.Count) {
        throw 'Invalid app number.'
    }

    $entry = $entries[$number - 1]
    Write-Host "Remove this sign-in entry: $($entry.Name)"
    if ((Read-Host 'Type DISABLE to confirm') -cne 'DISABLE') { return }
    $current = Get-RegistryState -Path $path -Name $entry.Name
    if (-not $current.Exists -or $current.Kind -ne $entry.Kind -or $current.Value -cne $entry.Value) {
        throw 'The startup entry changed. Reopen the menu and select it again.'
    }
    Write-Backup -Kind Registry -Payload ([ordered]@{ Profile = 'Desktop startup'; Values = @($current) }) | Out-Null
    Remove-ItemProperty -LiteralPath $path -Name $current.Name -ErrorAction Stop
    Write-Host 'Removed from this user Run key. Use RESTORE.cmd to restore the entry.'
    Write-Host 'If the app uses another startup mechanism, check Windows Startup settings or the app settings.'
}

while ($true) {
    Write-Host ''
    Write-Host 'WINDOWS 11 OPTIMIZATION PACK' -ForegroundColor Cyan
    Write-Host ' 1) Background profile: browser background activity and game capture'
    Write-Host ' 2) Disable a selected app at sign-in'
    Write-Host ' 3) Responsive AC power plan (administrator)'
    Write-Host ' 4) Delivery Optimization: HTTP only and optional bandwidth cap (administrator)'
    Write-Host ' 5) Disable the Widgets feature on supported Windows editions (administrator)'
    Write-Host ' 6) Optimize one drive with the Windows storage tool (administrator)'
    Write-Host ' 7) Desktop effects: less animation and transparency'
    Write-Host ' 8) Mouse: linear desktop pointer, speed 6/11'
    Write-Host ' 9) Display refresh-rate settings'
    Write-Host '10) Windows Startup apps settings'
    Write-Host '11) Restore saved settings'
    Write-Host ' 0) Exit'
    try {
        switch (Read-Host 'Choose') {
            '1' { & "$PSScriptRoot\Apply-Profile.ps1" -Profile Background }
            '2' { Disable-OptionalStartupApp }
            '3' { & "$PSScriptRoot\Desktop-System.ps1" -Action Power }
            '4' { & "$PSScriptRoot\Desktop-System.ps1" -Action Delivery }
            '5' { & "$PSScriptRoot\Desktop-System.ps1" -Action Widgets }
            '6' { & "$PSScriptRoot\Desktop-System.ps1" -Action Drive }
            '7' { & "$PSScriptRoot\Apply-Profile.ps1" -Profile Desktop }
            '8' { & "$PSScriptRoot\Apply-Profile.ps1" -Profile Mouse }
            '9' { Start-Process 'ms-settings:display-advanced' }
            '10' { Start-Process 'ms-settings:startupapps' }
            '11' { & "$PSScriptRoot\Undo.ps1" }
            '0' { return }
            default { Write-Warning 'Choose a listed option.' }
        }
    } catch {
        Write-Warning $_
    }
}
