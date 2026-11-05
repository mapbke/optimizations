. "$PSScriptRoot\Common.ps1"
Assert-Windows

Write-Host 'WINDOWS DESKTOP RESPONSIVENESS' -ForegroundColor Cyan
Write-Host '1) Apply desktop effects preset (backed up)'
Write-Host '2) Disable a selected optional app at sign-in (backed up)'
Write-Host '3) Open Windows refresh-rate settings'
Write-Host '4) Open Windows Startup apps settings'
Write-Host '5) Open Windows power settings'
Write-Host '0) Exit'

switch (Read-Host 'Choose') {
    '1' { & "$PSScriptRoot\Apply-Profile.ps1" -Profile Desktop }
    '2' {
        $path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
        $optionalApps = @('Steam', 'Discord', 'Spotify', 'OneDrive', 'EpicGamesLauncher', 'Battle.net')
        $entries = @(
            foreach ($name in $optionalApps) {
                $state = Get-RegistryState -Path $path -Name $name
                if ($state.Exists -and $state.Kind -in @('String', 'ExpandString')) { $state }
            }
        )
        if ($entries.Count -eq 0) {
            Write-Host 'No supported entries found in your Run key. Use option 4 for other startup apps.'
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
        Write-Host 'If the app uses another startup mechanism, check option 4 or the app settings.'
    }
    '3' { Start-Process 'ms-settings:display-advanced' }
    '4' { Start-Process 'ms-settings:startupapps' }
    '5' { Start-Process 'ms-settings:powersleep' }
    '0' { return }
    default { throw 'Unknown option.' }
}
