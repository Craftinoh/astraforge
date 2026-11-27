[CmdletBinding()]
param(
    [string]$GameDir = $env:VICTORY_GAME_DIR,
    [string]$GameExecutableName = 'game.exe',
    [string]$RuntimeExe,
    [string]$SourceRoot,
    [ValidateSet('Stability', 'Balanced', 'Performance', 'Quality')][string]$Profile = 'Balanced',
    [ValidateSet('series-s', 'series-x')][string]$Console,
    [string]$OutputRoot = "$env:LOCALAPPDATA\AstraForge\gpu",
    [string]$CacheDir,
    [string]$DataDir,
    [string]$PresentMonExe,
    [hashtable]$RuntimeOverride = @{},
    [ValidateRange(12, 256)][int]$MinimumAvailableCommitGiB = 12,
    [switch]$DebugConsole,
    [switch]$PreRunWindow,
    [switch]$AllowSeriesX
)

if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    $SourceRoot = Join-Path $PSScriptRoot '..\third_party\nvidia-3070-VI'
}

$parameters = @{}
foreach ($name in $PSBoundParameters.Keys) { $parameters[$name] = $PSBoundParameters[$name] }
$parameters['SourceRoot'] = $SourceRoot
$parameters['GpuProfile'] = 'nvidia-rtx3070'
& (Join-Path $PSScriptRoot 'Start-AstraForge.ps1') @parameters
