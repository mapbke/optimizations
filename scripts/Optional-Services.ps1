[CmdletBinding()]
param()
. "$PSScriptRoot\Common.ps1"
Assert-Windows
$id = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($id)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $args = '-NoProfile -ExecutionPolicy Bypass -File "' + $PSCommandPath + '"'
    try { Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -Verb RunAs -ArgumentList $args -Wait }
    catch { Write-Warning "Elevation cancelled: $_" }
    exit
}

Write-Host 'OPTIONAL DEEP DEBLOAT — DISABLING SERVICES CAN REDUCE FUNCTIONALITY' -ForegroundColor Yellow
Write-Host '1) Diagnostics telemetry service + CEIP tasks'
Write-Host '2) Windows Search indexing (search may become slow/incomplete)'
Write-Host '3) SysMain (prefetch optimization may stop working)'
Write-Host '4) Downloaded offline maps service'
Write-Host '5) All of the above (AGGRESSIVE)'
Write-Host '0) Cancel'
$answer = Read-Host 'Choose number'
if ($answer -notin @('1','2','3','4','5')) { exit }
$services = @()
if ($answer -in @('1','5')) { $services += 'DiagTrack' }
if ($answer -in @('2','5')) { $services += 'WSearch' }
if ($answer -in @('3','5')) { $services += 'SysMain' }
if ($answer -in @('4','5')) { $services += 'MapsBroker' }

Write-Host 'Will set these services to Disabled:' -ForegroundColor Yellow
$services | ForEach-Object { Write-Host "  $_" }
Write-Host 'This can reduce functionality. Some updates might restore the defaults.'
if ((Read-Host 'Confirm these services? Type DEEP') -cne 'DEEP') { exit }

$states = @()
foreach ($name in $services) {
    $svc = Get-CimInstance Win32_Service -Filter "Name='$name'" -ErrorAction SilentlyContinue
    if ($null -eq $svc) { Write-Warning "Not installed: $name"; continue }
    $path = 'HKLM:\SYSTEM\CurrentControlSet\Services\' + $name
    $start = (Get-ItemProperty -LiteralPath $path -Name Start).Start
    $delay = 0
    $delayExists = $false
    try { $delay = (Get-ItemProperty -LiteralPath $path -Name DelayedAutoStart -ErrorAction Stop).DelayedAutoStart; $delayExists = $true } catch {}
    $states += [pscustomobject]@{
        Name = $name; StartValue = [int]$start; DelayValue = [int]$delay
        DelayExists = $delayExists; WasRunning = ($svc.State -eq 'Running')
    }
}
if ($states.Count -gt 0) {
    Write-Backup -Kind Services -Payload ([ordered]@{ Values = $states }) | Out-Null
    foreach ($s in $states) {
        try {
            Set-Service -Name $s.Name -StartupType Disabled -ErrorAction Stop
            Stop-Service -Name $s.Name -ErrorAction SilentlyContinue
            Write-Host "Disabled: $($s.Name)" -ForegroundColor Green
        } catch { Write-Warning "Could not disable $($s.Name): $_" }
    }
}
if ($answer -in @('1','5')) {
    $taskPaths = @(
       @{ Path='\Microsoft\Windows\Customer Experience Improvement Program\'; Name='Consolidator' },
       @{ Path='\Microsoft\Windows\Customer Experience Improvement Program\'; Name='UsbCeip' }
    )
    $states = @()
    foreach ($t in $taskPaths) {
        try {
            $task = Get-ScheduledTask -TaskPath $t.Path -TaskName $t.Name -ErrorAction Stop
            $states += [pscustomobject]@{
                Path=$t.Path; Name=$t.Name; WasEnabled=[bool]$task.Settings.Enabled
            }
        } catch { Write-Host "Absent task: $($t.Name)" }
    }
    if ($states.Count -gt 0) {
        Write-Backup -Kind Tasks -Payload ([ordered]@{ Values=$states }) | Out-Null
        foreach ($t in $states) {
            try {
                Disable-ScheduledTask -TaskPath $t.Path -TaskName $t.Name -ErrorAction Stop | Out-Null
                Write-Host "Disabled task: $($t.Name)" -ForegroundColor Green
            } catch { Write-Warning "Failed task $($t.Name): $_" }
        }
    }
}
Write-Host 'Done. RESTORE.cmd reverts services and tasks saved by this tool.' -ForegroundColor Green
