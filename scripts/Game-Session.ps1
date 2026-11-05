[CmdletBinding()]
param()
. "$PSScriptRoot\Common.ps1"
Assert-Windows

# Match known optional desktop apps in this Windows session only.
$targets = @('chrome', 'msedge', 'firefox', 'Spotify', 'ms-teams', 'Teams',
    'EpicGamesLauncher', 'Battle.net', 'EADesktop', 'UbisoftConnect')
$session = (Get-Process -Id $PID).SessionId
$config = Join-Path $env:LOCALAPPDATA 'mapbke-optimizations'
$list = Join-Path $config 'session-apps.txt'
$selected = @()
if (Test-Path -LiteralPath $list) {
    $selected = @((Get-Content -LiteralPath $list) | Where-Object { $_ -in $targets } | Select-Object -Unique)
}

Write-Host 'CS2 SESSION' -ForegroundColor Cyan
Write-Host "Apps selected for graceful close: $($selected -join ', ')"
Write-Host '1) Prepare for CS2 (launch manually or from FACEIT)'
Write-Host '2) Prepare and launch CS2 through Steam'
Write-Host '3) Edit saved app list'
Write-Host '4) Turn off Windows game capture (backed up)'
Write-Host '5) Review startup apps in Windows'
Write-Host '0) Exit'
$choice = Read-Host 'Choose'
switch ($choice) {
    '0' { return }
    '3' {
        for ($index = 0; $index -lt $targets.Count; $index++) {
            Write-Host ("{0,2}) {1}" -f ($index + 1), $targets[$index])
        }
        $inputText = (Read-Host 'Enter a comma-separated list of numbers, NONE to clear, or Enter to cancel').Trim()
        if (-not $inputText) { return }
        $newSelection = @()
        if ($inputText -ine 'NONE') {
            foreach ($item in ($inputText -split ',')) {
                $number = 0
                if (-not [int]::TryParse($item.Trim(), [ref]$number) -or $number -lt 1 -or $number -gt $targets.Count) {
                    throw "Invalid app number: $item. The saved list was not changed."
                }
                $newSelection += $targets[$number - 1]
            }
        }
        New-Item -Path $config -ItemType Directory -Force | Out-Null
        $newSelection = @($newSelection | Select-Object -Unique)
        Set-Content -LiteralPath $list -Value ($newSelection -join [Environment]::NewLine) -Encoding UTF8
        Write-Host 'List saved.'
        return
    }
    '4' { & "$PSScriptRoot\Apply-Profile.ps1" -Profile Safe; return }
    '5' { & "$PSScriptRoot\Startup-Review.ps1"; return }
    { $_ -in @('1', '2') } { }
    default { throw 'Unknown option.' }
}

$steam = $null
$launchArgs = @('-applaunch', '730')
if ($choice -eq '2') {
    if (Get-Process -Name cs2 -ErrorAction SilentlyContinue | Where-Object { $_.SessionId -eq $session }) {
        throw 'Close CS2 before launching it with this menu.'
    }
    $steamPath = Get-RegistryState -Path 'HKCU:\Software\Valve\Steam' -Name 'SteamExe'
    if (-not $steamPath.Exists -or -not $steamPath.Value) { throw 'Steam installation not found for this user.' }
    $steam = Get-Item -LiteralPath $steamPath.Value
    if ($steam -isnot [System.IO.FileInfo] -or $steam.Name -ine 'steam.exe') { throw 'Invalid Steam executable path.' }
    $capText = (Read-Host 'Optional CS2 FPS cap, 30-1000. Enter leaves the game setting alone').Trim()
    if ($capText) {
        $cap = 0
        if (-not [int]::TryParse($capText, [ref]$cap) -or $cap -lt 30 -or $cap -gt 1000) {
            throw 'Invalid FPS cap.'
        }
        $launchArgs += @('+fps_max', $cap.ToString())
    }
}

$apps = @()
if ($selected.Count -gt 0) {
    $apps = @(Get-Process -Name $selected -ErrorAction SilentlyContinue |
        Where-Object { $_.SessionId -eq $session -and $_.MainWindowHandle -ne [IntPtr]::Zero })
}
if ($apps.Count -gt 0) {
    $apps | Select-Object ProcessName, Id | Format-Table -AutoSize | Out-Host
    Write-Warning 'Save your work. Apps can ask for confirmation or keep running in the tray.'
    if ((Read-Host 'Ask these windows to close? Type CLOSE or press Enter to skip') -ceq 'CLOSE') {
        foreach ($app in $apps) {
            try {
                if ($app.CloseMainWindow()) {
                    Write-Host "Close requested: $($app.ProcessName)"
                } else {
                    Write-Warning "Window could not be closed: $($app.Id)"
                }
            } catch {
                Write-Warning "Could not close PID $($app.Id): $_"
            }
        }
    }
}
if ($choice -eq '2') {
    Start-Process -FilePath $steam.FullName -ArgumentList $launchArgs
} else {
    Write-Host 'Ready. Open CS2 normally. To cap FPS manually, use the in-game FPS limit.'
}
