$ErrorActionPreference = 'Stop'
Import-Module -Name (Join-Path $PSScriptRoot 'AstraForge-Preflight.psm1') -Force

$measureLines = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Measure-AstraForgeGameplay.ps1')
$commitGateLine = [Array]::FindIndex([string[]]$measureLines, [Predicate[string]]{ param($line) $line -match '^Assert-AstraForgeCommitHeadroom\b' })
$cacheCloneLine = [Array]::FindIndex([string[]]$measureLines, [Predicate[string]]{ param($line) $line -match 'Copy-AstraForgeCacheSeed\s+-SourceDirectory' })
if ($commitGateLine -lt 0 -or $cacheCloneLine -lt 0 -or $commitGateLine -ge $cacheCloneLine) {
    throw 'Warm cache cloning must remain after the available-commit preflight.'
}

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
$launchers = $entryPoints | Where-Object { $_ -notmatch 'Measure-AstraForgeGameplay\.ps1$' }
foreach ($launcher in $launchers) {
    $launcherText = Get-Content -LiteralPath $launcher -Raw
    $parameterBlockEnd = $launcherText.IndexOf("`n)`n")
    if ($parameterBlockEnd -lt 0) { $parameterBlockEnd = $launcherText.IndexOf("`r`n)`r`n") }
    if ($parameterBlockEnd -lt 0) { throw "Could not isolate launcher parameter block: $launcher" }
    $parameterBlock = $launcherText.Substring(0, $parameterBlockEnd)
    if ($parameterBlock -match '\$SourceRoot\s*=\s*\(Join-Path\s+\$PSScriptRoot') {
        throw "Launcher evaluates PSScriptRoot while binding SourceRoot: $launcher"
    }
    if ($launcherText -notmatch '(?m)^\s*\$SourceRoot\s*=\s*Join-Path\s+\$PSScriptRoot') {
        throw "Launcher does not resolve its default SourceRoot after parameter binding: $launcher"
    }
}
$startLauncherText = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Start-AstraForge.ps1') -Raw
$waitForExitIndex = $startLauncherText.IndexOf('$process.WaitForExit()')
$readExitCodeIndex = $startLauncherText.IndexOf('$exitCode = $process.ExitCode')
if ($waitForExitIndex -lt 0 -or $readExitCodeIndex -lt 0 -or $waitForExitIndex -ge $readExitCodeIndex) {
    throw 'Launcher must wait for the runtime process before reading its exit code.'
}
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

Write-Host 'AstraForge commit preflight tests passed: 18 cases.'
