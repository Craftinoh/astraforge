[CmdletBinding()]
param(
    [string]$SourceRoot,
    [ValidateSet('Release', 'Diagnostic', 'Both')][string]$Mode = 'Both',
    [switch]$ThinLto,
    [switch]$NativeCpu,
    [string]$LogRoot = "$env:LOCALAPPDATA\AstraForge\builds\logs",
    [string]$ArtifactRoot = "$env:LOCALAPPDATA\AstraForge\builds\artifacts"
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    $SourceRoot = Join-Path $PSScriptRoot '..\third_party\nvidia-3070-VI'
}
$root = (Resolve-Path -LiteralPath $SourceRoot).Path
$manifest = Join-Path $root 'Cargo.toml'
$toolchainFile = Join-Path $root 'rust-toolchain.toml'
if (-not (Test-Path -LiteralPath $manifest)) { throw "Cargo.toml non trovato in $root" }
if (-not (Test-Path -LiteralPath $toolchainFile)) { throw "rust-toolchain.toml non trovato in $root; il toolchain richiesto dal progetto non è verificabile." }
$rootManifestText = Get-Content -LiteralPath $manifest -Raw
if ($Mode -in @('Diagnostic', 'Both') -and $rootManifestText -notmatch '(?m)^\s*\[profile\.diag\]\s*$') {
    throw 'Il manifest non definisce [profile.diag]; non indovino un profilo diagnostico alternativo.'
}

$cargo = Get-Command cargo.exe -ErrorAction Stop
$rustc = Get-Command rustc.exe -ErrorAction Stop
$git = Get-Command git.exe -ErrorAction Stop
$linker = Get-Command link.exe -ErrorAction SilentlyContinue
if (-not $linker) { throw 'link.exe non trovato. Installa/abilita il toolset MSVC richiesto dal target Windows.' }
$compiler = Get-Command cl.exe -ErrorAction SilentlyContinue
if (-not $compiler) { Write-Warning 'cl.exe non trovato nel PATH; alcuni crate nativi potrebbero richiedere il prompt Developer di Visual Studio.' }

Push-Location $root
try {
    # Run the proxy while inside SourceRoot so rustup honors this repository's rust-toolchain.toml.
    $rustVersion = (& $rustc.Source --version).Trim()
    $cargoVersion = (& $cargo.Source --version).Trim()
    $hostTarget = (& $rustc.Source -vV | Where-Object { $_ -like 'host:*' } | Select-Object -First 1) -replace '^host:\s*', ''
    if ($hostTarget -ne 'x86_64-pc-windows-msvc') {
        throw "Target Rust attivo $hostTarget; serve x86_64-pc-windows-msvc per questa build Windows."
    }

    $metadataText = & $cargo.Source metadata --locked --no-deps --format-version 1 --manifest-path $manifest
    if ($LASTEXITCODE -ne 0) { throw 'cargo metadata non è riuscito; controllare toolchain, manifest e lockfile.' }
    $metadata = [string]::Join([Environment]::NewLine, @($metadataText)) | ConvertFrom-Json
    $victoryPackage = $metadata.packages | Where-Object name -eq 'victory' | Select-Object -First 1
    if (-not $victoryPackage) { throw 'Il workspace non dichiara un package Cargo chiamato victory.' }
    $featureNames = @($victoryPackage.features.PSObject.Properties.Name)
    if ($Mode -in @('Diagnostic', 'Both') -and 'diagnostics' -notin $featureNames) {
        throw 'Il package victory non espone la feature diagnostics; non avvio una build diagnostica con una feature ipotizzata.'
    }
} finally {
    Pop-Location
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$workspacePath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$workspaceWithSlash = $workspacePath.TrimEnd('\') + '\'
$logPath = [System.IO.Path]::GetFullPath($LogRoot)
if ($logPath.Equals($workspacePath, [System.StringComparison]::OrdinalIgnoreCase) -or $logPath.StartsWith($workspaceWithSlash, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'LogRoot deve restare fuori dal repository.'
}
$artifactPath = [System.IO.Path]::GetFullPath($ArtifactRoot)
if ($artifactPath.Equals($workspacePath, [System.StringComparison]::OrdinalIgnoreCase) -or $artifactPath.StartsWith($workspaceWithSlash, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'ArtifactRoot deve restare fuori dal repository.'
}
$variant = if ($ThinLto -and $NativeCpu) { 'thinlto-native' }
    elseif ($ThinLto) { 'thinlto' }
    elseif ($NativeCpu) { 'native' }
    else { 'default' }
$buildId = "$timestamp-$Mode-$variant-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
$buildDirectory = Join-Path $ArtifactRoot $buildId
$targetDirectory = Join-Path $buildDirectory 'cargo-target'
New-Item -ItemType Directory -Force -Path $LogRoot, $buildDirectory | Out-Null
$transcriptPath = Join-Path $LogRoot "$buildId.log"
$previousThinLto = $env:CARGO_PROFILE_RELEASE_LTO
$previousCodegenUnits = $env:CARGO_PROFILE_RELEASE_CODEGEN_UNITS
$previousRustFlags = $env:RUSTFLAGS
$previousTargetDirectory = $env:CARGO_TARGET_DIR
if (-not $ThinLto -and ($previousThinLto -or $previousCodegenUnits)) {
    throw 'CARGO_PROFILE_RELEASE_LTO/CODEGEN_UNITS sono già impostati. Rimuovili oppure seleziona -ThinLto per mantenere il build label riproducibile.'
}
if (-not $NativeCpu -and -not [string]::IsNullOrWhiteSpace($previousRustFlags)) {
    throw 'RUSTFLAGS è già impostato. Rimuovilo oppure seleziona -NativeCpu e confronta il flag riportato nel manifest.'
}
try {
    Start-Transcript -LiteralPath $transcriptPath -Force | Out-Null
    $env:CARGO_TARGET_DIR = $targetDirectory
    Write-Host "Root: $root"
    Write-Host "Build ID: $buildId"
    Write-Host "Artifact directory: $buildDirectory"
    Write-Host "Toolchain: $((Get-Content -LiteralPath $toolchainFile -Raw).Trim())"
    Write-Host "Rust: $rustVersion; Cargo: $cargoVersion; target: $hostTarget"
    Write-Host "MSVC linker: $($linker.Source)"
    if (Get-Command dxc.exe -ErrorAction SilentlyContinue) { Write-Host "DXC: $((Get-Command dxc.exe).Source)" }
    else { Write-Warning 'dxc.exe non trovato; il progetto potrebbe usare un DXC distribuito/risolto a runtime.' }

    if ($ThinLto) {
        # Rust Thin LTO build option; unrelated to the VICTORY_THIN runtime shader switch.
        $env:CARGO_PROFILE_RELEASE_LTO = 'thin'
        $env:CARGO_PROFILE_RELEASE_CODEGEN_UNITS = '1'
    }
    if ($NativeCpu) {
        $extra = '-C target-cpu=native'
        $env:RUSTFLAGS = if ([string]::IsNullOrWhiteSpace($previousRustFlags)) { $extra } else { "$previousRustFlags $extra" }
    }

    Push-Location $root
    try {
        if ($Mode -in @('Release', 'Both')) {
            Write-Host 'Building Release...'
            & $cargo.Source build --locked --release --package victory
            if ($LASTEXITCODE -ne 0) { throw "Build Release fallita con exit code $LASTEXITCODE" }
        }
        if ($Mode -in @('Diagnostic', 'Both')) {
            Write-Host 'Building diagnostic...'
            & $cargo.Source build --locked --profile diag --package victory --features diagnostics
            if ($LASTEXITCODE -ne 0) { throw "Build diagnostic fallita con exit code $LASTEXITCODE" }
        }
    } finally {
        Pop-Location
    }
    $artifacts = @()
    if ($Mode -in @('Release', 'Both')) {
        $releaseExe = Join-Path $targetDirectory 'release\victory.exe'
        if (-not (Test-Path -LiteralPath $releaseExe -PathType Leaf)) { throw "Build completata senza eseguibile Release atteso: $releaseExe" }
        $artifacts += [pscustomobject]@{ Profile = 'release'; Path = $releaseExe; Sha256 = (Get-FileHash -LiteralPath $releaseExe -Algorithm SHA256).Hash }
    }
    if ($Mode -in @('Diagnostic', 'Both')) {
        $diagnosticExe = Join-Path $targetDirectory 'diag\victory.exe'
        if (-not (Test-Path -LiteralPath $diagnosticExe -PathType Leaf)) { throw "Build completata senza eseguibile diagnostico atteso: $diagnosticExe" }
        $artifacts += [pscustomobject]@{ Profile = 'diag+diagnostics'; Path = $diagnosticExe; Sha256 = (Get-FileHash -LiteralPath $diagnosticExe -Algorithm SHA256).Hash }
    }
    $sourceCommit = (& $git.Source -C $root rev-parse HEAD 2>$null | Out-String).Trim()
    $sourceStatus = @(& $git.Source -C $root status --porcelain 2>$null)
    $buildManifest = [ordered]@{
        BuildId = $buildId
        SourceRoot = $root
        SourceCommit = $sourceCommit
        SourceDirty = ($sourceStatus.Count -gt 0)
        Toolchain = (Get-Content -LiteralPath $toolchainFile -Raw).Trim()
        RustVersion = $rustVersion
        CargoVersion = $cargoVersion
        HostTarget = $hostTarget
        Mode = $Mode
        ThinLto = [bool]$ThinLto
        NativeCpu = [bool]$NativeCpu
        CARGO_PROFILE_RELEASE_LTO = if ($ThinLto) { 'thin' } else { $null }
        CARGO_PROFILE_RELEASE_CODEGEN_UNITS = if ($ThinLto) { '1' } else { $null }
        RUSTFLAGS = if ($NativeCpu) { "$previousRustFlags -C target-cpu=native".Trim() } else { $previousRustFlags }
        Artifacts = $artifacts
    }
    $manifestPath = Join-Path $buildDirectory 'build-manifest.json'
    [System.IO.File]::WriteAllText($manifestPath, ($buildManifest | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "Release artifact: $(($artifacts | Where-Object Profile -eq 'release' | Select-Object -First 1).Path)"
    Write-Host "Diagnostic artifact: $(($artifacts | Where-Object Profile -eq 'diag+diagnostics' | Select-Object -First 1).Path)"
    Write-Host "Build manifest: $manifestPath"
} finally {
    if ($null -eq $previousThinLto) { Remove-Item Env:CARGO_PROFILE_RELEASE_LTO -ErrorAction SilentlyContinue } else { $env:CARGO_PROFILE_RELEASE_LTO = $previousThinLto }
    if ($null -eq $previousCodegenUnits) { Remove-Item Env:CARGO_PROFILE_RELEASE_CODEGEN_UNITS -ErrorAction SilentlyContinue } else { $env:CARGO_PROFILE_RELEASE_CODEGEN_UNITS = $previousCodegenUnits }
    if ($null -eq $previousRustFlags) { Remove-Item Env:RUSTFLAGS -ErrorAction SilentlyContinue } else { $env:RUSTFLAGS = $previousRustFlags }
    if ($null -eq $previousTargetDirectory) { Remove-Item Env:CARGO_TARGET_DIR -ErrorAction SilentlyContinue } else { $env:CARGO_TARGET_DIR = $previousTargetDirectory }
    Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
}
Write-Host "Build completata. Log: $transcriptPath"
