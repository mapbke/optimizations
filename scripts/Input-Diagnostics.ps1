. "$PSScriptRoot\Common.ps1"
Assert-Windows
$reports = Join-Path $script:Root 'reports'
New-Item -ItemType Directory -Path $reports -Force | Out-Null
$out = Join-Path $reports ('input-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.json')

function Try-Read([scriptblock]$Command) {
    try { return & $Command }
    catch { return ("Unavailable: " + $_.Exception.Message) }
}
$mousePath = 'HKCU:\Control Panel\Mouse'
$mouseSettings = [ordered]@{}
foreach ($name in @('MouseSpeed','MouseThreshold1','MouseThreshold2','MouseSensitivity')) {
    $mouseSettings[$name] = Try-Read { (Get-ItemProperty -Path $mousePath -Name $name -ErrorAction Stop).$name }
}
$report = [ordered]@{
    Timestamp = (Get-Date).ToString('o')
    WindowsMouseSettings = $mouseSettings
    PnpMouseDevices = @(Try-Read { Get-PnpDevice -Class Mouse | Select-Object FriendlyName, Status, InstanceId })
    PnpUsbControllers = @(Try-Read { Get-PnpDevice -Class USB | Select-Object FriendlyName, Status, InstanceId })
    MouseWmi = @(Try-Read { Get-CimInstance Win32_PointingDevice | Select-Object Name, Description, Status, ConfigManagerErrorCode })
    UsbControllers = @(Try-Read { Get-CimInstance Win32_USBController | Select-Object Name, Status })
}
$report | ConvertTo-Json -Depth 9 | Set-Content -LiteralPath $out -Encoding UTF8
Write-Host "Mouse + USB diagnostic saved: $out" -ForegroundColor Green
Write-Host 'No drivers or USB power settings were changed.'
Write-Host 'Check device Status/ErrorCode, try another direct USB port, examine cable/dongle placement, then compare 1000 Hz vs higher polling rates.'
Write-Host 'USB/PnP identifiers are device-specific; review before sharing publicly.'
