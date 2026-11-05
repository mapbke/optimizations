Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:Root = Split-Path -Parent $PSScriptRoot
$script:Backups = Join-Path $script:Root 'backups'

function Assert-Windows {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
        throw 'Windows is required.'
    }
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
        Payload = $Payload
    }
    $data | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $file -Encoding UTF8
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
    } elseif (Test-Path -LiteralPath $State.Path) {
        Remove-ItemProperty -Path $State.Path -Name $State.Name -ErrorAction SilentlyContinue
    }
}
