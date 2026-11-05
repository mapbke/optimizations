[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Hard', 'Power', 'Background', 'DesktopFast', 'Delivery', 'AppBackground')]
    [string]$Profile,
    [string]$ExpectedSid
)
. "$PSScriptRoot\Common.ps1"
. "$PSScriptRoot\Power.ps1"
Assert-Windows

try {
    $sid = Get-PackUserSid
    if ($ExpectedSid -and $ExpectedSid -ne $sid) {
        throw 'UAC switched to another account. Run the script from your administrator account.'
    }

    $usesPower = $Profile -in @('Hard', 'Power')
    $partialMessage = '(PARTIAL) Desktop and background settings saved. The CPU power plan was skipped. Restart Windows.'
    $usesMachinePolicy = $Profile -in @('Delivery', 'AppBackground')
    if ($usesMachinePolicy) {
        $version = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
        if ($version.EditionID -notmatch '^(Professional|Enterprise|Education|IoTEnterprise)') {
            throw 'This policy requires Windows Pro, Enterprise or Education.'
        }
    }

    if (-not $ExpectedSid) {
        Write-Host "optimizations / $Profile" -ForegroundColor Cyan
        if ($usesPower) {
            Write-Warning 'The AC power plan favors performance and keeps CPU cores available. Power use and heat can rise.'
        }
        if ($Profile -in @('Hard', 'Background')) {
            Write-Host 'Turns off Game Bar capture and browser background mode for Edge and Chrome.'
            Write-Host 'Browser extensions may stop sending notifications when their browser is closed.'
        }
        if ($Profile -in @('Hard', 'DesktopFast')) {
            Write-Host 'Reduces desktop animations and transparency and removes the submenu delay.'
        }
        if ($Profile -eq 'Delivery') {
            Write-Host 'Turns off update peer sharing and caps Delivery Optimization background downloads at 2048 KB/s.'
        }
        if ($Profile -eq 'AppBackground') {
            Write-Warning 'Blocks background activity for supported Windows apps. Notifications and sync can stop.'
        }
        if ((Read-Host 'Apply? [Y / Enter to cancel]') -notmatch '^y(es)?$') { return }
    }

    if (($usesPower -or $usesMachinePolicy) -and -not (Test-PackAdministrator)) {
        if ($ExpectedSid) { throw 'Administrator privileges are required.' }
        $commandLine = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -Profile {1} -ExpectedSid {2}' -f $PSCommandPath, $Profile, $sid
        $child = Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -Verb RunAs -ArgumentList $commandLine -Wait -PassThru
        if ($child.ExitCode -eq 2 -and $Profile -eq 'Hard') {
            Write-Warning $partialMessage
            return
        }
        if ($child.ExitCode -ne 0) { throw 'The administrator process could not complete the profile.' }
        Write-Host '(ACTIVATED) Restart Windows. Run RESTORE.cmd as administrator to undo.' -ForegroundColor Green
        return
    }

    $lock = Enter-BackupLock
    $powerChange = $null
    $powerSkipped = $false
    try {
        if ($usesPower) {
            try {
                $powerChange = Enable-PackPowerMax
            } catch [System.PlatformNotSupportedException] {
                if ($Profile -ne 'Hard') { throw }
                $powerSkipped = $true
                Write-Warning $_.Exception.Message
            }
        }
        if ($Profile -ne 'Power') {
            $specs = @(Get-ProfileSpecs -Profile $Profile)
            Invoke-RegistryProfile -Profile $Profile -Specs $specs
        }
    } catch {
        $failure = $_
        if ($null -ne $powerChange) {
            try {
                Restore-PackPowerBackup -Backup $powerChange.Backup -File $powerChange.File
            } catch {
                Write-Warning "Power rollback incomplete. Run RESTORE.cmd as administrator. $_"
            }
        }
        throw $failure
    } finally {
        $lock.Dispose()
    }
    if ($powerSkipped) {
        if ($ExpectedSid) { exit 2 }
        Write-Warning $partialMessage
        return
    }
    Write-Host '(ACTIVATED) Restart Windows. Run RESTORE.cmd to undo.' -ForegroundColor Green
} catch {
    if (-not $ExpectedSid) { throw }
    Write-Warning $_.Exception.Message
    [void](Read-Host 'Press Enter to close this window')
    exit 1
}
