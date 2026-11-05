. "$PSScriptRoot\Common.ps1"
Assert-Windows
$reports = Join-Path $script:Root 'reports'
New-Item -ItemType Directory -Path $reports -Force | Out-Null
$out = Join-Path $reports ('system-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.json')

function Try-Value { param([scriptblock]$Block) try { & $Block } catch { "Unavailable: $($_.Exception.Message)" } }
$os = Get-CimInstance Win32_OperatingSystem
$cpu = @(Get-CimInstance Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed)
$gpu = @(Get-CimInstance Win32_VideoController | Select-Object Name, DriverVersion, CurrentHorizontalResolution, CurrentVerticalResolution, CurrentRefreshRate)
$memoryBytes = [double]$os.TotalVisibleMemorySize * 1024
$vbs = Try-Value { Get-CimInstance -Namespace 'root\Microsoft\Windows\DeviceGuard' -ClassName Win32_DeviceGuard | Select-Object VirtualizationBasedSecurityStatus, SecurityServicesConfigured, SecurityServicesRunning }
$tpm = Try-Value { Get-Tpm | Select-Object TpmPresent, TpmReady, TpmEnabled }
$secureBoot = Try-Value { Confirm-SecureBootUEFI }
$power = ((& powercfg.exe /getactivescheme 2>&1) -join ' ').Trim()
$top = @(Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 18 Name, Id, @{Name='WorkingSetMiB';Expression={[math]::Round($_.WorkingSet64 / 1MB, 1)}})
$startup = @(Try-Value { Get-CimInstance Win32_StartupCommand | Select-Object Name, Location, User })
$info = [ordered]@{
  Timestamp = (Get-Date).ToString('o')
  OperatingSystem = [ordered]@{ Caption = $os.Caption; Version = $os.Version; BuildNumber = $os.BuildNumber; DisplayVersion = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').DisplayVersion }
  CPU = $cpu
  MemoryGiB = [math]::Round($memoryBytes / 1GB, 2)
  GPU = $gpu
  PowerScheme = $power
  SecureBoot = $secureBoot
  TPM = $tpm
  VBS = $vbs
  TopProcessesByMemory = $top
  StartupPrograms = $startup
}
$info | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $out -Encoding UTF8
Write-Host "Report written: $out" -ForegroundColor Green
Write-Host "OS: $($os.Caption), build $($os.BuildNumber)"
Write-Host "CPU: $($cpu[0].Name)"
Write-Host "GPU: $($gpu[0].Name)"
Write-Host "RAM: $([math]::Round($memoryBytes / 1GB, 2)) GiB"
Write-Host "Power: $power"
Write-Host 'Report contains device/startup information. Do not post it publicly without review.'
Write-Host 'Note: Display refresh from Win32_VideoController is not guaranteed to match active monitor mode.'
