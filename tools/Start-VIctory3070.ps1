[CmdletBinding()]
param(
    [string]$GameDir = $env:VICTORY_GAME_DIR,
    [string]$GameExecutableName = 'game.exe',
    [string]$VictoryExe,
    [string]$SourceRoot = (Join-Path $PSScriptRoot '..\third_party\nvidia-3070-VI'),
    [ValidateSet('Stability', 'Balanced', 'Performance', 'Quality')][string]$Profile = 'Balanced',
    [ValidateSet('series-s', 'series-x')][string]$Console,
    [string]$OutputRoot = "$env:LOCALAPPDATA\VIctory\gpu",
    [ValidateRange(0, 256)][int]$MinimumAvailableCommitGiB = 12,
    [switch]$AllowLowCommit,
    [switch]$AllowSeriesX
)

$parameters = @{}
foreach ($name in $PSBoundParameters.Keys) { $parameters[$name] = $PSBoundParameters[$name] }
$parameters['GpuProfile'] = 'nvidia-rtx3070'
& (Join-Path $PSScriptRoot 'Start-VIctoryGPU.ps1') @parameters
