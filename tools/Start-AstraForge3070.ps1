[CmdletBinding()]
param(
    [string]$GameDir = $env:VICTORY_GAME_DIR,
    [string]$GameExecutableName = 'game.exe',
    [string]$RuntimeExe,
    [string]$SourceRoot = (Join-Path $PSScriptRoot '..\third_party\nvidia-3070-VI'),
    [ValidateSet('Stability', 'Balanced', 'Performance', 'Quality')][string]$Profile = 'Balanced',
    [ValidateSet('series-s', 'series-x')][string]$Console,
    [string]$OutputRoot = "$env:LOCALAPPDATA\AstraForge\gpu",
    [ValidateRange(12, 256)][int]$MinimumAvailableCommitGiB = 12,
    [switch]$AllowSeriesX
)

$parameters = @{}
foreach ($name in $PSBoundParameters.Keys) { $parameters[$name] = $PSBoundParameters[$name] }
$parameters['GpuProfile'] = 'nvidia-rtx3070'
& (Join-Path $PSScriptRoot 'Start-AstraForge.ps1') @parameters
