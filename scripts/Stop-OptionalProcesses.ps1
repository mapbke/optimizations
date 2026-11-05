. "$PSScriptRoot\Common.ps1"
Assert-Windows

$targets = @('chrome', 'msedge', 'firefox', 'Spotify', 'ms-teams', 'Teams',
    'EpicGamesLauncher', 'Battle.net', 'EADesktop', 'UbisoftConnect')
$session = (Get-Process -Id $PID).SessionId

function Get-AppCpuSnapshot {
    $samples = @{}
    foreach ($process in Get-Process -Name $targets -ErrorAction SilentlyContinue) {
        try {
            if ($process.SessionId -ne $session) { continue }
            $samples[$process.Id] = [pscustomobject]@{
                Process = $process
                Name = $process.ProcessName
                StartTime = $process.StartTime
                CpuTicks = $process.TotalProcessorTime.Ticks
                SampleTick = [Diagnostics.Stopwatch]::GetTimestamp()
                HasWindow = $process.MainWindowHandle -ne [IntPtr]::Zero
            }
        } catch {
            # A process may exit or become inaccessible during the sample.
            continue
        }
    }
    return $samples
}

Write-Host 'Checking CPU usage for optional apps...'
$before = Get-AppCpuSnapshot
Start-Sleep -Seconds 1
$after = Get-AppCpuSnapshot
$logicalCpuCount = [Environment]::ProcessorCount

$apps = @(
    foreach ($group in $after.Values | Group-Object Name) {
        $windows = @($group.Group | Where-Object HasWindow)
        if ($windows.Count -eq 0) { continue }

        $cpuPercent = $null
        foreach ($current in $group.Group) {
            $previous = $before[$current.Process.Id]
            if ($null -ne $previous -and $current.StartTime -eq $previous.StartTime) {
                $elapsed = ($current.SampleTick - $previous.SampleTick) / [Diagnostics.Stopwatch]::Frequency
                $cpuSeconds = ($current.CpuTicks - $previous.CpuTicks) / [TimeSpan]::TicksPerSecond
                $cpuPercent += 100 * $cpuSeconds / ($elapsed * $logicalCpuCount)
            }
        }
        [pscustomobject]@{ Name = $group.Name; CpuPercent = $cpuPercent; Windows = $windows }
    }
)
if ($apps.Count -eq 0) {
    Write-Host 'No supported app windows are open.'
    return
}
$apps = @($apps | Sort-Object -Property @{ Expression = 'CpuPercent'; Descending = $true }, Name)
Write-Host ''
Write-Host ('     {0,-24} {1,8}' -f 'App', 'CPU')
for ($index = 0; $index -lt $apps.Count; $index++) {
    $app = $apps[$index]
    $cpuLabel = if ($null -eq $app.CpuPercent) { 'n/a' } else { '{0:F1}%' -f $app.CpuPercent }
    Write-Host ('{0,2})  {1,-24} {2,8}' -f ($index + 1), $app.Name, $cpuLabel)
}
$answer = Read-Host 'Select one app by number, or press Enter to cancel'
if (-not $answer) { return }
$number = 0
if (-not [int]::TryParse($answer, [ref]$number) -or $number -lt 1 -or $number -gt $apps.Count) {
    throw 'Choose a listed number.'
}

$app = $apps[$number - 1]
Write-Warning "Save your work in $($app.Name). It may keep running in the notification area."
if ((Read-Host 'Ask this app to close? Type CLOSE') -cne 'CLOSE') { return }
foreach ($window in $app.Windows) {
    $process = $window.Process
    try {
        $process.Refresh()
        if ($process.StartTime -eq $window.StartTime -and $process.CloseMainWindow()) {
            Write-Host "Close requested: $($app.Name) (PID $($process.Id))"
        } else {
            Write-Warning "The window could not be closed (PID $($process.Id))."
        }
    } catch {
        Write-Warning "The window is no longer available (PID $($process.Id))."
    }
}
