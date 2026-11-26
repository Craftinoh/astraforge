[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RuntimeExe,
    [Parameter(Mandatory = $true)][string[]]$ShaderArchives,
    [string]$GpuProfile = 'nvidia-rtx3070',
    [switch]$WarmUsedPipelines,
    [string]$SourceRoot,
    [string]$CacheDirectory,
    [string]$LogRoot
)

$ErrorActionPreference = 'Stop'
Import-Module -Name (Join-Path $PSScriptRoot 'AstraForge-BenchmarkCommon.psm1') -Force

function Test-PathOverlap([string]$Left, [string]$Right) {
    $leftFull = [System.IO.Path]::GetFullPath($Left).TrimEnd('\')
    $rightFull = [System.IO.Path]::GetFullPath($Right).TrimEnd('\')
    return $leftFull.Equals($rightFull, [System.StringComparison]::OrdinalIgnoreCase) -or
        $leftFull.StartsWith($rightFull + '\', [System.StringComparison]::OrdinalIgnoreCase) -or
        $rightFull.StartsWith($leftFull + '\', [System.StringComparison]::OrdinalIgnoreCase)
}

$exe = (Resolve-Path -LiteralPath $RuntimeExe).Path
$archives = @($ShaderArchives | ForEach-Object { (Resolve-Path -LiteralPath $_).Path })
$gpuManifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\profiles\gpu-profiles.json') -Raw | ConvertFrom-Json
$gpuProfileConfig = $gpuManifest.profiles.PSObject.Properties[$GpuProfile].Value
if ($null -eq $gpuProfileConfig) { throw "GPU profile '$GpuProfile' is not present in the workspace manifest." }
if ([string]::IsNullOrWhiteSpace($CacheDirectory)) {
    $CacheDirectory = Join-Path $env:LOCALAPPDATA ("VIctory\$GpuProfile\shader-cache-seed-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
if ([string]::IsNullOrWhiteSpace($LogRoot)) { $LogRoot = Join-Path $env:LOCALAPPDATA "VIctory\$GpuProfile\builds\logs" }
$executableRoot = if ($SourceRoot) { (Resolve-Path -LiteralPath $SourceRoot).Path } else { Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $exe)) }
$cachePath = [System.IO.Path]::GetFullPath($CacheDirectory)
$logFullPath = [System.IO.Path]::GetFullPath($LogRoot)
$workspaceRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if ((Test-PathOverlap $logFullPath $executableRoot) -or (Test-PathOverlap $logFullPath $workspaceRoot)) {
    throw 'LogRoot deve restare fuori dal repository.'
}
foreach ($archive in $archives) {
    $archivePath = [System.IO.Path]::GetFullPath($archive)
    if ((Test-PathOverlap $archivePath $executableRoot) -or (Test-PathOverlap $archivePath $workspaceRoot) -or (Test-PathOverlap $archivePath $cachePath)) {
        throw 'Gli archivi del gioco devono restare separati da repository e cache seed.'
    }
}
$help = (& $exe --help 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0 -and -not $help) { throw "Impossibile leggere l'help di $exe" }
if ($help -notmatch '(?m)^\s*shaders\b') {
    throw 'Questa build non pubblicizza il sottocomando `shaders`; non assumo una CLI di precompilazione incompatibile.'
}
if ($WarmUsedPipelines -and $help -notmatch '(?m)^\s*warm\b') {
    throw 'Questa build non pubblicizza il sottocomando `warm`; non avvio il prewarm PSO.'
}

if ((Test-PathOverlap $cachePath $executableRoot) -or (Test-PathOverlap $cachePath $workspaceRoot)) {
    throw 'CacheDirectory deve restare fuori dal repository.'
}
if (Test-PathOverlap $cachePath $logFullPath) {
    throw 'CacheDirectory e LogRoot devono restare separati.'
}
if ((Test-Path -LiteralPath $cachePath) -and -not (Test-Path -LiteralPath $cachePath -PathType Container)) {
    throw "CacheDirectory non è una cartella: $cachePath"
}
New-Item -ItemType Directory -Force -Path $cachePath | Out-Null

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
New-Item -ItemType Directory -Force -Path $LogRoot | Out-Null
$transcriptPath = Join-Path $LogRoot "$timestamp-prewarm.log"
$previousCache = $env:VICTORY_CACHE_DIR
try {
    $env:VICTORY_CACHE_DIR = $cachePath
    Start-Transcript -LiteralPath $transcriptPath -Force | Out-Null
    Write-Host "Build: $exe"
    Write-Host "Shader archives: $($archives.Count)"
    Write-Host "Persistent cache seed: $cachePath"
    & $exe shaders @archives
    if ($LASTEXITCODE -ne 0) { throw "Shader precompile fallita con exit code $LASTEXITCODE" }
    if ($WarmUsedPipelines) {
        & $exe warm --used
        if ($LASTEXITCODE -ne 0) { throw "PSO warm-up fallito con exit code $LASTEXITCODE" }
    }
    $cacheFingerprint = Get-AstraForgeDirectoryFingerprint -Directory $cachePath
    if ($cacheFingerprint.Files -eq 0) { throw "Prewarm terminato senza file nella cache seed: $cachePath" }
    $git = Get-Command git.exe -ErrorAction SilentlyContinue
    $sourceCommit = if ($git) { (& $git.Source -C $executableRoot rev-parse HEAD 2>$null | Out-String).Trim() } else { $null }
    $manifest = [ordered]@{
        CapturedAt = (Get-Date).ToString('o')
        GpuProfile = $GpuProfile
        RuntimeExecutable = $exe
        RuntimeExecutableSha256 = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash
        SourceRoot = $executableRoot
        SourceCommit = $sourceCommit
        ShaderArchives = $archives
        WarmUsedPipelines = [bool]$WarmUsedPipelines
        CacheDirectory = $cachePath
        CacheFingerprint = $cacheFingerprint
    }
    $manifestPath = "$transcriptPath.manifest.json"
    [System.IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "Warm cache seed SHA-256: $($cacheFingerprint.Sha256)"
    Write-Host "Prewarm manifest: $manifestPath"
} finally {
    Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
    if ($null -eq $previousCache) { Remove-Item Env:VICTORY_CACHE_DIR -ErrorAction SilentlyContinue }
    else { $env:VICTORY_CACHE_DIR = $previousCache }
}
Write-Host "Prewarm completato. Log: $transcriptPath"
