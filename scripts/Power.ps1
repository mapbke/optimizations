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
    try {
        $previous = Get-PackActivePowerGuid
    } catch {
        throw [System.PlatformNotSupportedException]::new("CPU power plan skipped. $($_.Exception.Message)", $_.Exception)
    }
    $sid = Get-PackUserSid
    foreach ($file in Get-ChildItem -LiteralPath $script:Backups -Filter 'snapshot-*-Power-*.json' -File) {
        $backup = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
        if ($backup.Host -eq $env:COMPUTERNAME -and $backup.UserSid -eq $sid -and
            $backup.Payload.Profile -eq 'PowerMax' -and $backup.Payload.NewGuid -eq $previous.ToString()) {
            Write-Host 'The CPU Max power plan is already active.'
            return
        }
    }

    # Known Windows power setting GUIDs also work when aliases are absent.
    $processorSubgroup = '54533251-82be-4824-96c1-47b60b740d00'
    $settings = @(
        @{ Name = 'PERFEPP'; Id = '36687f9e-e3a5-4dbf-b1dc-15eb381c6863'; Value = '0' }
        @{ Name = 'PERFBOOSTMODE'; Id = 'be337238-0d82-4146-a960-4f3749d470c7'; Value = '2' }
        @{ Name = 'CPMINCORES'; Id = '0cc5b647-c1df-4637-891a-dec35c318583'; Value = '100' }
        @{ Name = 'PERFEPP1'; Id = '36687f9e-e3a5-4dbf-b1dc-15eb381c6864'; Value = '0' }
        @{ Name = 'CPMINCORES1'; Id = '0cc5b647-c1df-4637-891a-dec35c318584'; Value = '100' }
    )

    $new = [guid]::NewGuid()
    $payload = [ordered]@{ Profile = 'PowerMax'; PreviousGuid = $previous.ToString(); NewGuid = $new.ToString() }
    $snapshot = Write-Backup -Kind Power -Payload $payload
    $backup = [pscustomobject]@{ Payload = $payload }
    $file = Get-Item -LiteralPath $snapshot
    try {
        Invoke-PackPowerCfg @('/duplicatescheme', $previous.ToString(), $new.ToString()) | Out-Null
        Invoke-PackPowerCfg @('/changename', $new.ToString(), 'optimizations CPU Max (AC)') | Out-Null
        $appliedCount = 0
        foreach ($setting in $settings) {
            try {
                Invoke-PackPowerCfg @('/setacvalueindex', $new.ToString(), $processorSubgroup, $setting.Id, $setting.Value) | Out-Null
                $appliedCount++
            } catch {
                Write-Warning "Could not apply $($setting.Name). $($_.Exception.Message)"
            }
        }
        if ($appliedCount -eq 0) { throw 'Windows rejected all five CPU power settings.' }
        if ((Get-PackActivePowerGuid) -ne $previous) { throw 'The active power plan changed. Run the script again.' }
        Invoke-PackPowerCfg @('/setactive', $new.ToString()) | Out-Null
        if ((Get-PackActivePowerGuid) -ne $new) { throw 'Windows did not activate the new power plan.' }
    } catch {
        $failure = $_
        try {
            Restore-PackPowerBackup -Backup $backup -File $file
        } catch {
            throw "CPU power plan rollback failed. Run RESTORE.cmd as administrator. $($_.Exception.Message)"
        }
        throw [System.PlatformNotSupportedException]::new("CPU power plan skipped. $($failure.Exception.Message)", $failure.Exception)
    }

    Write-Host "CPU Max is active. Applied $appliedCount of $($settings.Count) AC settings." -ForegroundColor Green
    return [pscustomobject]@{ Backup = $backup; File = $file }
}
