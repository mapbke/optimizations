. "$PSScriptRoot\Common.ps1"
Assert-Windows

# Only apps with a window in the current Windows session are eligible.
$targets = @('chrome', 'msedge', 'firefox', 'Spotify', 'ms-teams', 'Teams',
    'EpicGamesLauncher', 'Battle.net', 'EADesktop', 'UbisoftConnect')
$session = (Get-Process -Id $PID).SessionId
$apps = @(Get-Process -Name $targets -ErrorAction SilentlyContinue |
    Where-Object { $_.SessionId -eq $session -and $_.MainWindowHandle -ne [IntPtr]::Zero } |
    Sort-Object ProcessName, Id)

if ($apps.Count -eq 0) {
    Write-Host 'No supported app windows are open.'
    return
}
for ($index = 0; $index -lt $apps.Count; $index++) {
    Write-Host ('{0,2}) {1} (PID {2})' -f ($index + 1), $apps[$index].ProcessName, $apps[$index].Id)
}
$answer = Read-Host 'Select one window by number, or press Enter to cancel'
if (-not $answer) { return }
$number = 0
if (-not [int]::TryParse($answer, [ref]$number) -or $number -lt 1 -or $number -gt $apps.Count) {
    throw 'Choose a listed number.'
}

$app = $apps[$number - 1]
Write-Warning "Save your work in $($app.ProcessName). The app may stay in the notification area."
if ((Read-Host 'Ask this window to close? Type CLOSE') -cne 'CLOSE') { return }
if ($app.CloseMainWindow()) {
    Write-Host "Close requested: $($app.ProcessName)"
} else {
    Write-Warning 'The window could not be closed.'
}
