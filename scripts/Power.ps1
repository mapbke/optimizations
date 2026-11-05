$script:PowerGuidPattern = '[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}'

function Invoke-PackPowerCfg {
    param([string[]]$Arguments)
    $output = & (Join-Path $env:SystemRoot 'System32\powercfg.exe') @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw "powercfg $($Arguments -join ' ') failed. $($output -join ' ')" }
    return $output
}

function Get-PackActivePowerGuid {
    $output = (Invoke-PackPowerCfg @('/getactivescheme')) -join ' '
    $match = [regex]::Match($output, $script:PowerGuidPattern)
    if (-not $match.Success) { throw "Could not identify the active power plan. $output" }
    return [guid]$match.Value
}

function Restore-PackPowerBackup {
    param([object]$Backup, [System.IO.FileInfo]$File)
    if ($Backup.Payload.Profile -ne 'PowerMax') { throw 'Unknown power plan backup.' }
    $previous = [guid]$Backup.Payload.PreviousGuid
    $new = [guid]$Backup.Payload.NewGuid
    if ($previous -eq $new -or $previous -eq [guid]::Empty -or $new -eq [guid]::Empty) {
        throw 'Invalid power plan backup.'
    }

    $plans = @(
        foreach ($line in Invoke-PackPowerCfg @('/list')) {
            $match = [regex]::Match([string]$line, $script:PowerGuidPattern)
            if ($match.Success) { [guid]$match.Value }
        }
    )
    if ($plans.Count -eq 0) { throw 'Could not read the list of power plans.' }
    if ($new -in $plans) {
        if ((Get-PackActivePowerGuid) -eq $new) {
            Invoke-PackPowerCfg @('/setactive', $previous.ToString()) | Out-Null
            if ((Get-PackActivePowerGuid) -ne $previous) { throw 'Could not reactivate the previous plan.' }
        }
        Invoke-PackPowerCfg @('/delete', $new.ToString()) | Out-Null
    }
    Rename-Item -LiteralPath $File.FullName -NewName ($File.Name + '.restored')
}

function Enable-PackPowerMax {
    $previous = Get-PackActivePowerGuid
    $sid = Get-PackUserSid
    foreach ($file in Get-ChildItem -LiteralPath $script:Backups -Filter 'snapshot-*-Power-*.json' -File) {
        $backup = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
        if ($backup.Host -eq $env:COMPUTERNAME -and $backup.UserSid -eq $sid -and
            $backup.Payload.Profile -eq 'PowerMax' -and $backup.Payload.NewGuid -eq $previous.ToString()) {
            Write-Host 'The CPU Max power plan is already active.'
            return
        }
    }

    $settings = [ordered]@{ PERFEPP = '0'; PERFBOOSTMODE = '2'; CPMINCORES = '100'; PERFEPP1 = '0'; CPMINCORES1 = '100' }
    $aliases = (Invoke-PackPowerCfg @('/aliases')) -join [Environment]::NewLine
    $available = @($settings.Keys | Where-Object { $aliases -match ('\b' + $_ + '\b') })
    if ($available.Count -eq 0) { throw 'The required CPU power options are unavailable.' }

    $new = [guid]::NewGuid()
    $payload = [ordered]@{ Profile = 'PowerMax'; PreviousGuid = $previous.ToString(); NewGuid = $new.ToString() }
    $snapshot = Write-Backup -Kind Power -Payload $payload
    $backup = [pscustomobject]@{ Payload = $payload }
    $file = Get-Item -LiteralPath $snapshot
    try {
        Invoke-PackPowerCfg @('/duplicatescheme', $previous.ToString(), $new.ToString()) | Out-Null
        Invoke-PackPowerCfg @('/changename', $new.ToString(), 'optimizations CPU Max (AC)') | Out-Null
        foreach ($setting in $available) {
            Invoke-PackPowerCfg @('/setacvalueindex', $new.ToString(), 'SUB_PROCESSOR', $setting, $settings[$setting]) | Out-Null
        }
        if ((Get-PackActivePowerGuid) -ne $previous) { throw 'The active power plan changed. Run the script again.' }
        Invoke-PackPowerCfg @('/setactive', $new.ToString()) | Out-Null
        if ((Get-PackActivePowerGuid) -ne $new) { throw 'Windows did not activate the new power plan.' }
    } catch {
        $failure = $_
        try {
            Restore-PackPowerBackup -Backup $backup -File $file
        } catch {
            Write-Warning "Power rollback incomplete. Run RESTORE.cmd as administrator. $_"
        }
        throw $failure
    }

    Write-Host 'CPU Max is active. AC settings applied.' -ForegroundColor Green
    return [pscustomobject]@{ Backup = $backup; File = $file }
}
