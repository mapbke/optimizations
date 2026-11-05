[CmdletBinding()]
param([ValidateSet('Max','Desktop','Input')][string]$Mode = 'Max')
. "$PSScriptRoot\Common.ps1"
Assert-Windows

function Test-Administrator {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($id)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
# Request UAC automatically instead of silently skipping system-level tweaks.
if ($Mode -eq 'Max' -and -not (Test-Administrator)) {
    Write-Host 'Requesting UAC for Windows power profile. No security protections are disabled.' -ForegroundColor Yellow
    $args = '-NoProfile -ExecutionPolicy Bypass -File "' + $PSCommandPath + '" -Mode Max'
    try {
        Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -Verb RunAs -ArgumentList $args -Wait -ErrorAction Stop
    } catch {
        Write-Warning "Elevation cancelled: $_"
    }
    exit
}

$specs = New-Object 'System.Collections.Generic.List[object]'
function Add-Tweak([string]$Path, [string]$Name, $Value, [string]$Kind, [string]$Reason) {
    $specs.Add([pscustomobject]@{
        Path=$Path; Name=$Name; Value=$Value; Kind=$Kind; Reason=$Reason
    })
}
$game = 'HKCU:\System\GameConfigStore'
$gameDvr = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR'
$visual = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize'
$explorer = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$content = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
$edge = 'HKCU:\SOFTWARE\Policies\Microsoft\Edge'
$search = 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer'
$mouse = 'HKCU:\Control Panel\Mouse'

if ($Mode -in @('Max','Desktop')) {
    Add-Tweak $game 'GameDVR_Enabled' 0 DWord 'Turn off background capture'
    Add-Tweak $gameDvr 'AppCaptureEnabled' 0 DWord 'Turn off background game recording'
    Add-Tweak $visual 'EnableTransparency' 0 DWord 'Reduce desktop compositing effects (small)'
    Add-Tweak $explorer 'TaskbarAnimations' 0 DWord 'Disable taskbar animations'
    Add-Tweak 'HKCU:\Control Panel\Desktop\WindowMetrics' 'MinAnimate' '0' String 'Disable minimize/maximize animations'
    Add-Tweak $explorer 'TaskbarDa' 0 DWord 'Hide Widgets button'
    Add-Tweak $explorer 'ShowSyncProviderNotifications' 0 DWord 'No Explorer sync provider advertising'
    Add-Tweak $explorer 'Start_IrisRecommendations' 0 DWord 'Reduce Windows Start suggestions'
    Add-Tweak $search 'DisableSearchBoxSuggestions' 1 DWord 'Hide web suggestions in Windows Search where supported'
    Add-Tweak $edge 'BackgroundModeEnabled' 0 DWord 'Do not keep Edge background mode running'
    Add-Tweak $edge 'StartupBoostEnabled' 0 DWord 'Disable Edge startup boost'
    Add-Tweak $content 'SilentInstalledAppsEnabled' 0 DWord 'Prevent suggested silent consumer app installs'
    Add-Tweak $content 'SystemPaneSuggestionsEnabled' 0 DWord 'No system pane suggestions'
    Add-Tweak $content 'SoftLandingEnabled' 0 DWord 'Fewer Windows tips'
    Add-Tweak $content 'SubscribedContent-338388Enabled' 0 DWord 'No suggested content'
    Add-Tweak $content 'SubscribedContent-338389Enabled' 0 DWord 'No suggestions in settings'
    Add-Tweak $content 'SubscribedContent-353698Enabled' 0 DWord 'No Windows suggestions'
    Add-Tweak $content 'SubscribedContent-353694Enabled' 0 DWord 'No Windows suggestions'
    Add-Tweak $content 'SubscribedContent-353696Enabled' 0 DWord 'No Windows suggestions'
    Add-Tweak $content 'RotatingLockScreenEnabled' 0 DWord 'No rotating lock screen images'
    Add-Tweak $content 'RotatingLockScreenOverlayEnabled' 0 DWord 'No lock screen tips/overlay'
}
if ($Mode -in @('Max','Input')) {
    Add-Tweak $mouse 'MouseSpeed' '0' String 'Disable Windows mouse acceleration'
    Add-Tweak $mouse 'MouseThreshold1' '0' String 'Mouse 1:1 threshold'
    Add-Tweak $mouse 'MouseThreshold2' '0' String 'Mouse 1:1 threshold'
    Add-Tweak $mouse 'MouseSensitivity' '10' String 'Windows pointer speed 6/11'
}

$all = @($specs.ToArray())
Write-Host "OPTIMIZATION PROFILE: $Mode" -ForegroundColor Green
Write-Host "Registry entries selected: $($all.Count)"
Write-Host 'No Defender / Secure Boot / TPM / VBS / HVCI / IOMMU / FACEIT / Windows Update changes.' -ForegroundColor Yellow
Write-Host 'IMPORTANT: many entries reduce background clutter, not FPS; Windows may ignore obsolete options.'
Write-Host 'Backup is written before any registry values change.'
foreach ($spec in $all) { Write-Host ("  {0}: {1}" -f $spec.Name, $spec.Reason) }
if ((Read-Host 'Apply this profile? Type APPLY') -cne 'APPLY') { Write-Host 'Cancelled.'; exit }

$previous = @($all | ForEach-Object { Get-RegistryState -Path $_.Path -Name $_.Name })
Write-Backup -Kind Registry -Payload ([ordered]@{ Profile="PRO-$Mode"; Values=$previous }) | Out-Null
$errors = 0
foreach ($spec in $all) {
    try { Set-RegistrySpec -Spec $spec }
    catch { $errors++; Write-Warning "Failed $($spec.Name): $_" }
}

if ($Mode -eq 'Max') {
    # The cloned plan leaves existing user plans untouched. All AC-only settings.
    $currentText = ((& powercfg.exe /getactivescheme 2>&1) -join ' ')
    $guidPattern = '[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}'
    $currentMatch = [regex]::Match($currentText, $guidPattern)
    if ($currentMatch.Success) {
        try {
            $previousGuid = $currentMatch.Value
            $copyText = ((& powercfg.exe /duplicatescheme $previousGuid 2>&1) -join ' ')
            $newMatch = [regex]::Match($copyText, $guidPattern)
            if ($LASTEXITCODE -ne 0 -or -not $newMatch.Success) { throw "Cannot clone active power plan: $copyText" }
            $newGuid = $newMatch.Value
            Write-Backup -Kind Power -Payload ([ordered]@{ PreviousGuid=$previousGuid; NewGuid=$newGuid }) | Out-Null
            & powercfg.exe /changename $newGuid 'Mapbke Gaming (AC)' 'USB selective suspend and PCIe link savings off on AC only' | Out-Null
            if ($LASTEXITCODE -ne 0) { throw 'Unable to rename power plan' }
            # SUB_USB / USBSELECTIVE SUSPEND = disabled on AC
            & powercfg.exe /setacvalueindex $newGuid '2a737441-1930-4402-8d77-b2bebba308a3' '48e6b7a6-50f5-4782-a5d4-53bb8f07e226' 0 | Out-Null
            if ($LASTEXITCODE -ne 0) { throw 'USB suspend power setting unavailable' }
            # SUB_PCIEXPRESS / ASPM = off on AC
            & powercfg.exe /setacvalueindex $newGuid '501a4d13-42af-4429-9fd1-a8218c268e20' 'ee12f906-d277-404b-b6da-e5fa1a576df5' 0 | Out-Null
            if ($LASTEXITCODE -ne 0) { throw 'PCIe power setting unavailable' }
            & powercfg.exe /setactive $newGuid | Out-Null
            if ($LASTEXITCODE -ne 0) { throw 'Unable to activate gaming power plan' }
            Write-Host "Created & activated cloned gaming AC power plan: $newGuid" -ForegroundColor Green
        } catch { $errors++; Write-Warning "Power plan partially or fully skipped: $_ (Undo can remove any created plan)" }
    } else { Write-Warning "Power plan skipped: cannot read active scheme" }
}
Write-Host "Applied profile. Registry operation errors: $errors" -ForegroundColor Green
Write-Host 'Restart Windows / sign out for full UI and mouse changes. Use RESTORE.cmd to undo.'
