Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:Root = Split-Path -Parent $PSScriptRoot
$script:Backups = Join-Path $script:Root 'backups\release-v1'
$script:FullscreenFlag = 'DISABLEDXMAXIMIZEDWINDOWEDMODE'
function Assert-Windows {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
        throw 'Windows is required.'
    }
}

function Get-PackUserSid {
    return [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
}

function Test-PackAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
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
    $name = 'snapshot-{0}-{1}-{2}.json' -f ([DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-fffffff')), $Kind, ([guid]::NewGuid().ToString('N').Substring(0, 8))
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

function Initialize-RegistryKey {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) { return }

    $hive = switch ($Path.Substring(0, 6)) {
        'HKCU:\' { [Microsoft.Win32.Registry]::CurrentUser }
        'HKLM:\' { [Microsoft.Win32.Registry]::LocalMachine }
        default { throw "Unsupported registry path: $Path" }
    }
    $key = $hive.CreateSubKey($Path.Substring(6))
    $key.Dispose()
}

function Set-RegistrySpec {
    param([Parameter(Mandatory)][object]$Spec)
    Initialize-RegistryKey -Path $Spec.Path
    New-ItemProperty -LiteralPath $Spec.Path -Name $Spec.Name -Value $Spec.Value -PropertyType $Spec.Kind -Force | Out-Null
}

function Restore-RegistryState {
    param([Parameter(Mandatory)][object]$State)
    if ($State.Exists) {
        Initialize-RegistryKey -Path $State.Path
        New-ItemProperty -LiteralPath $State.Path -Name $State.Name -Value $State.Value -PropertyType $State.Kind -Force | Out-Null
    } elseif ((Get-RegistryState -Path $State.Path -Name $State.Name).Exists) {
        Remove-ItemProperty -LiteralPath $State.Path -Name $State.Name -ErrorAction Stop
    }
}

function Get-PendingRegistryChanges {
    param([object[]]$Specs)
    foreach ($spec in $Specs) {
        $old = Get-RegistryState -Path $spec.Path -Name $spec.Name
        if (-not $old.Exists -or $old.Kind -ne $spec.Kind -or $old.Value -cne $spec.Value) {
            [pscustomobject]@{ Spec = $spec; Previous = $old }
        }
    }
}

function Invoke-RegistryProfile {
    param([string]$Profile, [object[]]$Specs)
    $changes = @(Get-PendingRegistryChanges -Specs $Specs)
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

function Enter-BackupLock {
    New-Item -ItemType Directory -Path $script:Backups -Force | Out-Null
    $lockPath = Join-Path $script:Backups 'settings.lock'
    try {
        return [IO.File]::Open($lockPath, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    } catch [IO.IOException] {
        throw 'Cannot lock the backup folder. Close other copies of the tool and retry.'
    }
}

function Get-ProfileSpecs {
    param(
        [Parameter(Mandatory)][ValidateSet('Capture', 'Desktop', 'Mouse', 'Hard', 'Background', 'DesktopFast', 'Delivery', 'AppBackground', 'Mpo', 'Fullscreen')]
        [string]$Profile,
        [string]$ExePath
    )
    switch ($Profile) {
        'Capture' {
            @{ Path = 'HKCU:\System\GameConfigStore'; Name = 'GameDVR_Enabled'; Value = 0; Kind = 'DWord' }
            @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'AppCaptureEnabled'; Value = 0; Kind = 'DWord' }
        }
        'Desktop' {
            @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name = 'EnableTransparency'; Value = 0; Kind = 'DWord' }
            @{ Path = 'HKCU:\Control Panel\Desktop\WindowMetrics'; Name = 'MinAnimate'; Value = '0'; Kind = 'String' }
            @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'TaskbarAnimations'; Value = 0; Kind = 'DWord' }
        }
        'Hard' {
            Get-ProfileSpecs -Profile Background
            Get-ProfileSpecs -Profile DesktopFast
        }
        'Background' {
            Get-ProfileSpecs -Profile Capture
            @{ Path = 'HKCU:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'BackgroundModeEnabled'; Value = 0; Kind = 'DWord' }
            @{ Path = 'HKCU:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'StartupBoostEnabled'; Value = 0; Kind = 'DWord' }
            @{ Path = 'HKCU:\SOFTWARE\Policies\Google\Chrome'; Name = 'BackgroundModeEnabled'; Value = 0; Kind = 'DWord' }
        }
        'DesktopFast' {
            Get-ProfileSpecs -Profile Desktop
            @{ Path = 'HKCU:\Control Panel\Desktop'; Name = 'MenuShowDelay'; Value = '0'; Kind = 'String' }
        }
        'Delivery' {
            $path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'
            @{ Path = $path; Name = 'DODownloadMode'; Value = 0; Kind = 'DWord' }
            @{ Path = $path; Name = 'DOMaxBackgroundDownloadBandwidth'; Value = 2048; Kind = 'DWord' }
        }
        'AppBackground' {
            @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'; Name = 'LetAppsRunInBackground'; Value = 2; Kind = 'DWord' }
        }
        'Mpo' {
            @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\Dwm'; Name = 'OverlayTestMode'; Value = 5; Kind = 'DWord' }
        }
        'Fullscreen' {
            if ($ExePath -notmatch '^(?:[A-Z]:\\|\\\\)[^\r\n]+\.exe$') { throw 'An absolute executable path is required.' }
            @{
                Path = 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
                Name = $ExePath
                Value = "~ $script:FullscreenFlag"
                Kind = 'String'
            }
        }
        'Mouse' {
            @{ Path = 'HKCU:\Control Panel\Mouse'; Name = 'MouseSpeed'; Value = '0'; Kind = 'String' }
        }
    }
}
