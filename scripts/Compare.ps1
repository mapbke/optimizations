[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Before,
  [Parameter(Mandatory)][string]$After
)
. "$PSScriptRoot\Common.ps1"

function Read-Samples([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { throw "File not found: $Path" }
    $rows = @(Import-Csv -LiteralPath $Path)
    if ($rows.Count -lt 3) { throw 'Use at least 3 runs per file.' }
    $result = @()
    foreach ($r in $rows) {
        $avg = [double]::Parse([string]$r.AvgFPS, [Globalization.CultureInfo]::InvariantCulture)
        $p1 = [double]::Parse([string]$r.P1FPS, [Globalization.CultureInfo]::InvariantCulture)
        if ($avg -le 0 -or $p1 -le 0) { throw 'FPS values must be positive.' }
        $result += [pscustomobject]@{ AvgFPS = $avg; P1FPS = $p1 }
    }
    return ,$result
}
$b = Read-Samples $Before
$a = Read-Samples $After
$metrics = @('AvgFPS', 'P1FPS')
Write-Host 'Median of runs (robust against a single outlier):' -ForegroundColor Cyan
foreach ($metric in $metrics) {
    $bSort = @($b | ForEach-Object { $_.$metric } | Sort-Object)
    $aSort = @($a | ForEach-Object { $_.$metric } | Sort-Object)
    $bm = $bSort[[int][math]::Floor(($bSort.Count - 1) / 2)]
    $am = $aSort[[int][math]::Floor(($aSort.Count - 1) / 2)]
    if (($bSort.Count % 2) -eq 0) { $bm = ($bSort[([int]($bSort.Count / 2) - 1)] + $bSort[[int]($bSort.Count / 2)]) / 2 }
    if (($aSort.Count % 2) -eq 0) { $am = ($aSort[([int]($aSort.Count / 2) - 1)] + $aSort[[int]($aSort.Count / 2)]) / 2 }
    $delta = 100 * ($am - $bm) / $bm
    Write-Host ('{0}: before {1:N1}, after {2:N1}, change {3:+0.0;-0.0;0.0}%' -f $metric, $bm, $am, $delta)
}
Write-Host 'Comparisons only mean something with identical map, scene, resolution, FPS cap and GPU settings.'
