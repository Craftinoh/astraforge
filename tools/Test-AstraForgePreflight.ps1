$ErrorActionPreference = 'Stop'
Import-Module -Name (Join-Path $PSScriptRoot 'AstraForge-Preflight.psm1') -Force

function Assert-Rejected([scriptblock]$Action, [string]$Label) {
    $rejected = $false
    try { & $Action } catch { $rejected = $true }
    if (-not $rejected) { throw "Preflight accepted unsafe input: $Label" }
}

Assert-AstraForgeCommitHeadroom -AvailableGiB 12
Assert-AstraForgeCommitHeadroom -AvailableGiB 20 -MinimumGiB 20
Assert-Rejected { Assert-AstraForgeCommitHeadroom -AvailableGiB 11.99 } 'below the 12 GiB default'
Assert-Rejected { Assert-AstraForgeCommitHeadroom -AvailableGiB 10.32 } 'current host sample below the 12 GiB default'
Assert-Rejected { Assert-AstraForgeCommitHeadroom -AvailableGiB 19.99 -MinimumGiB 20 } 'below a raised threshold'
Assert-Rejected { Assert-AstraForgeCommitHeadroom -AvailableGiB 30 -MinimumGiB 11 } 'attempt to lower the hard minimum'
Assert-Rejected { Assert-AstraForgeCommitHeadroom -AvailableGiB [double]::NaN } 'invalid non-finite sample'
Assert-Rejected { Assert-AstraForgeCommitHeadroom -AvailableGiB -1 } 'negative sample'

$powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$entryPoints = @(
    (Join-Path $PSScriptRoot 'Start-AstraForge.ps1'),
    (Join-Path $PSScriptRoot 'Start-AstraForge3070.ps1'),
    (Join-Path $PSScriptRoot 'Measure-AstraForgeGameplay.ps1')
)
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
foreach ($entryPoint in $entryPoints) {
    $arguments = @('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $entryPoint, '-MinimumAvailableCommitGiB', '11')
    if ($entryPoint.EndsWith('Measure-AstraForgeGameplay.ps1')) {
        $arguments += @('-RuntimeExe', 'runtime.exe', '-GameExe', 'game.exe', '-Scenario', 'scene-01', '-PresentMonExe', 'presentmon.exe')
    }
    & $powershell @arguments *> $null
    if ($LASTEXITCODE -eq 0) { throw "Entry point accepted a below-floor minimum: $entryPoint" }
    $arguments = @('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $entryPoint, '-AllowLowCommit')
    if ($entryPoint.EndsWith('Measure-AstraForgeGameplay.ps1')) {
        $arguments += @('-RuntimeExe', 'runtime.exe', '-GameExe', 'game.exe', '-Scenario', 'scene-01', '-PresentMonExe', 'presentmon.exe')
    }
    & $powershell @arguments *> $null
    if ($LASTEXITCODE -eq 0) { throw "Entry point still accepts -AllowLowCommit: $entryPoint" }
}
$ErrorActionPreference = $previousErrorActionPreference

Write-Host 'AstraForge commit preflight tests passed: 14 cases.'
