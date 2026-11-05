Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:Root = Split-Path -Parent $PSScriptRoot
$script:Backups = Join-Path $script:Root 'backups'
$script:PackGuidPattern = '[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}'

function Assert-Windows {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
        throw 'Windows is required.'
    }
}

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-PackUserSid {
    return [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
}

function Invoke-PackElevated {
    param([string]$Path, [string[]]$Arguments)
    $commandLine = '-NoProfile -ExecutionPolicy Bypass -File "' + $Path + '" ' + ($Arguments -join ' ')
    $child = Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList $commandLine -Verb RunAs -PassThru -Wait
    if ($child.ExitCode -ne 0) { throw "Administrator command failed (exit code $($child.ExitCode))." }
}

function Get-RegistryState {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Name)
    $state = [ordered]@{ Path = $Path; Name = $Name; Exists = $false; Value = $null; Kind = $null }
    if (Test-Path -LiteralPath $Path) {
        $key = Get-Item -LiteralPath $Path
        if (@($key.GetValueNames()) -contains $Name) {
            $state.Exists = $true
            $state.Value = $key.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            $state.Kind = [string]$key.GetValueKind($Name)
        }
    }
    return $state
}

function Write-Backup {
    param([Parameter(Mandatory)][string]$Kind, [Parameter(Mandatory)][object]$Payload)
    New-Item -ItemType Directory -Path $script:Backups -Force | Out-Null
    $name = 'snapshot-{0}-{1}-{2}.json' -f (Get-Date -Format 'yyyyMMdd-HHmmss-fff'), $Kind, ([guid]::NewGuid().ToString('N').Substring(0, 8))
    $file = Join-Path $script:Backups $name
    $data = [ordered]@{
        Schema = 1
        Kind = $Kind
        Date = (Get-Date).ToString('o')
        Host = $env:COMPUTERNAME
        UserSid = Get-PackUserSid
        Payload = $Payload
    }
    $temporaryFile = $file + '.tmp'
    try {
        $data | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $temporaryFile -Encoding UTF8
        Move-Item -LiteralPath $temporaryFile -Destination $file
    } finally {
        if (Test-Path -LiteralPath $temporaryFile) {
            Remove-Item -LiteralPath $temporaryFile -ErrorAction SilentlyContinue
        }
    }
    Write-Host "Backup: $file" -ForegroundColor Cyan
    return $file
}

function Set-RegistrySpec {
    param([Parameter(Mandatory)][object]$Spec)
    if (-not (Test-Path -LiteralPath $Spec.Path)) {
        New-Item -Path $Spec.Path -Force | Out-Null
    }
    New-ItemProperty -Path $Spec.Path -Name $Spec.Name -Value $Spec.Value -PropertyType $Spec.Kind -Force | Out-Null
}

function Restore-RegistryState {
    param([Parameter(Mandatory)][object]$State)
    if ($State.Exists) {
        if (-not (Test-Path -LiteralPath $State.Path)) {
            New-Item -Path $State.Path -Force | Out-Null
        }
        New-ItemProperty -Path $State.Path -Name $State.Name -Value $State.Value -PropertyType $State.Kind -Force | Out-Null
    } elseif ((Get-RegistryState -Path $State.Path -Name $State.Name).Exists) {
        Remove-ItemProperty -LiteralPath $State.Path -Name $State.Name -ErrorAction Stop
    }
}

function Invoke-RegistryProfile {
    param([string]$Profile, [object[]]$Specs)
    $changes = @(
        foreach ($spec in $Specs) {
            $old = Get-RegistryState -Path $spec.Path -Name $spec.Name
            if (-not $old.Exists -or $old.Kind -ne $spec.Kind -or $old.Value -cne $spec.Value) {
                [pscustomobject]@{ Spec = $spec; Previous = $old }
            }
        }
    )
    if ($changes.Count -eq 0) {
        Write-Host 'All selected values already match this profile.'
        return
    }

    $snapshot = Write-Backup -Kind Registry -Payload ([ordered]@{ Profile = $Profile; Values = @($changes.Previous) })
    $attempted = [Collections.Generic.List[object]]::new()
    try {
        foreach ($change in $changes) {
            $attempted.Add($change.Previous)
            Set-RegistrySpec -Spec $change.Spec
        }
    } catch {
        $failure = $_
        try {
            for ($index = $attempted.Count - 1; $index -ge 0; $index--) {
                Restore-RegistryState -State $attempted[$index]
            }
            Rename-Item -LiteralPath $snapshot -NewName ((Split-Path -Leaf $snapshot) + '.restored')
        } catch {
            Write-Warning "Rollback incomplete. Keep the backup and run RESTORE.cmd. $_"
        }
        throw $failure
    }
    Write-Host "Changed $($changes.Count) value(s)." -ForegroundColor Green
}

function Invoke-PackPowerCfg {
    param([string[]]$Arguments)
    $output = & (Join-Path $env:SystemRoot 'System32\powercfg.exe') @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw "powercfg $($Arguments -join ' ') failed. $($output -join ' ')" }
    return $output
}

function Get-PackActivePowerGuid {
    $output = (Invoke-PackPowerCfg @('/getactivescheme')) -join ' '
    $match = [regex]::Match($output, $script:PackGuidPattern)
    if (-not $match.Success) { throw "Could not identify the active power scheme. $output" }
    return [guid]$match.Value
}

function Restore-PackPowerClone {
    param([guid]$PreviousGuid, [guid]$NewGuid)
    if ($NewGuid -eq $PreviousGuid -or $NewGuid -eq [guid]::Empty -or $PreviousGuid -eq [guid]::Empty) {
        throw 'Invalid power scheme backup.'
    }
    $plans = @(
        foreach ($line in Invoke-PackPowerCfg @('/list')) {
            $match = [regex]::Match([string]$line, $script:PackGuidPattern)
            if ($match.Success) { [guid]$match.Value }
        }
    )
    if ($plans.Count -eq 0) { throw 'Could not read the list of power schemes.' }
    if ($NewGuid -notin $plans) { return }

    if ((Get-PackActivePowerGuid) -eq $NewGuid) {
        Invoke-PackPowerCfg @('/setactive', $PreviousGuid.ToString()) | Out-Null
    }
    Invoke-PackPowerCfg @('/delete', $NewGuid.ToString()) | Out-Null
}
