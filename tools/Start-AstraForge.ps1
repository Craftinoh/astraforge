[CmdletBinding()]
param(
    [string]$GameDir = $env:VICTORY_GAME_DIR,
    [string]$GameExecutableName = 'game.exe',
    [string]$RuntimeExe,
    [string]$SourceRoot,
    [string]$GpuProfile = 'nvidia-rtx3070',
    [ValidateSet('Stability', 'Balanced', 'Performance', 'Quality')][string]$Profile = 'Balanced',
    [ValidateSet('series-s', 'series-x')][string]$Console,
    [string]$OutputRoot = "$env:LOCALAPPDATA\AstraForge\gpu",
    [ValidateRange(12, 256)][int]$MinimumAvailableCommitGiB = 12,
    [switch]$AllowSeriesX
)

$ErrorActionPreference = 'Stop'
Import-Module -Name (Join-Path $PSScriptRoot 'AstraForge-Preflight.psm1') -Force

if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    $SourceRoot = Join-Path $PSScriptRoot '..\third_party\nvidia-3070-VI'
}

function Get-CanonicalPath([string]$Path) {
    return [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
}

function Test-WithinPath([string]$Path, [string]$Parent) {
    $childFull = Get-CanonicalPath $Path
    $parentFull = Get-CanonicalPath $Parent
    return $childFull.Equals($parentFull, [System.StringComparison]::OrdinalIgnoreCase) -or
        $childFull.StartsWith($parentFull + '\', [System.StringComparison]::OrdinalIgnoreCase)
}

$repo = (Resolve-Path -LiteralPath $SourceRoot).Path
$repoFull = Get-CanonicalPath $repo
$workspaceFull = Get-CanonicalPath (Join-Path $PSScriptRoot '..')
$profilesRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\profiles')).Path
$gpuManifestPath = Join-Path $profilesRoot 'gpu-profiles.json'
if (-not (Test-Path -LiteralPath $gpuManifestPath -PathType Leaf)) { throw "GPU profile manifest not found: $gpuManifestPath" }
$gpuManifest = Get-Content -LiteralPath $gpuManifestPath -Raw | ConvertFrom-Json
$gpuProfileConfig = $gpuManifest.profiles.PSObject.Properties[$GpuProfile].Value
if ($null -eq $gpuProfileConfig) {
    $availableProfiles = $gpuManifest.profiles.PSObject.Properties.Name -join ', '
    throw "GPU profile '$GpuProfile' is not defined. Available profiles: $availableProfiles"
}
if ([string]::IsNullOrWhiteSpace($Console)) { $Console = [string]$gpuProfileConfig.runtime.consoleDefault }
if ($gpuProfileConfig.runtime.adapterSelection -ne 'first-dxgi-adapter') {
    throw "Renderer does not support adapter-selection mode '$($gpuProfileConfig.runtime.adapterSelection)'."
}
$profileFile = Join-Path $profilesRoot ([string]$gpuProfileConfig.runtime.tuningConfig)
$profilesRootWithSlash = [System.IO.Path]::GetFullPath($profilesRoot).TrimEnd('\') + '\'
if (-not [System.IO.Path]::GetFullPath($profileFile).StartsWith($profilesRootWithSlash, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'GPU tuning config must remain inside the workspace profiles directory.'
}
if (-not (Test-Path -LiteralPath $profileFile -PathType Leaf)) { throw "GPU tuning config not found: $profileFile" }
$config = Get-Content -LiteralPath $profileFile -Raw | ConvertFrom-Json
$sourceManifest = Get-Content -LiteralPath (Join-Path $repo '.source-manifest.json') -Raw | ConvertFrom-Json
$expectedSource = '{0}@{1}' -f $sourceManifest.repository, $sourceManifest.commit
if ([string]$config.source -cne $expectedSource) {
    throw "Tuning config source '$($config.source)' does not match the source checkout '$expectedSource'."
}
if ([string]::IsNullOrWhiteSpace($GameDir)) {
    throw 'Indica -GameDir con la cartella dei file di gioco personali, oppure imposta VICTORY_GAME_DIR.'
}
$gameRoot = (Resolve-Path -LiteralPath $GameDir).Path
if (Test-WithinPath $gameRoot $workspaceFull) {
    throw 'I file di gioco devono restare fuori dal repository.'
}
if ([string]::IsNullOrWhiteSpace($GameExecutableName) -or
    [System.IO.Path]::GetFileName($GameExecutableName) -cne $GameExecutableName -or
    $GameExecutableName.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -ge 0 -or
    -not $GameExecutableName.EndsWith('.exe', [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'GameExecutableName must be a plain .exe file name without a directory.'
}
$gameExe = Join-Path $gameRoot $GameExecutableName
if (-not (Test-Path -LiteralPath $gameExe -PathType Leaf)) {
    throw "Game executable '$GameExecutableName' not found in the selected game folder."
}

$selectedProfile = $config.profiles.PSObject.Properties[$Profile].Value
if ($null -eq $selectedProfile) { throw "Profilo '$Profile' non definito in $profileFile" }

if ($Console -eq 'series-x' -and -not $AllowSeriesX) {
    throw "Series X richiede una prova esplicita sul profilo '$GpuProfile'; aggiungi -AllowSeriesX dopo avere controllato il budget di memoria."
}
if ($Console -eq 'series-x') {
    Write-Warning "Series X è sperimentale con '$GpuProfile'; monitora paging, texture in attesa e perdita del device."
}

# Profiles are tied to this source's documented dynamic texture admission knob.
$resourceSource = Join-Path $repo 'crates\victory-gpu\src\resource.rs'
if (-not (Test-Path -LiteralPath $resourceSource -PathType Leaf)) {
    throw 'Sorgente crates/victory-gpu/src/resource.rs non trovato; non posso verificare che il profilo sia compatibile.'
}
$resourceText = Get-Content -LiteralPath $resourceSource -Raw
if ($resourceText -notmatch 'VICTORY_TEXTURE_ROOM_PERCENT' -or
    $resourceText -notmatch 'map_or\(90,\s*\|percent\|\s*percent\.clamp\(50,\s*97\)\)') {
    throw 'La semantica/range di VICTORY_TEXTURE_ROOM_PERCENT non corrisponde alla revisione verificata; non lancio un profilo non auditato.'
}

if ($RuntimeExe) {
    if (-not (Test-Path -LiteralPath $RuntimeExe -PathType Leaf)) { throw "Eseguibile runtime AstraForge non trovato: $RuntimeExe" }
    $runner = (Resolve-Path -LiteralPath $RuntimeExe).Path
} else {
    $runnerCandidates = @(
        (Join-Path $repo 'victory-3d-rtx-pareto-residency.exe'),
        (Join-Path $repo 'target\release\victory.exe')
    )
    $runner = $runnerCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
}
if (-not $runner) {
    throw 'Eseguibile runtime AstraForge assente. Prima servono il checkout sorgente e una build Release; tools/Build-AstraForge.ps1 documenta i controlli.'
}
$runner = (Resolve-Path -LiteralPath $runner).Path

$outputFull = Get-CanonicalPath $OutputRoot
if (Test-WithinPath $outputFull $workspaceFull -or Test-WithinPath $outputFull $gameRoot) {
    throw 'Log, cache e dati AstraForge devono restare fuori dal repository e dai file di gioco.'
}
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$runDir = Join-Path $outputFull "$stamp-$GpuProfile-$Profile-$Console"
$cacheDir = Join-Path $env:LOCALAPPDATA "VIctory\$GpuProfile\cache"
$dataDir = Join-Path $env:LOCALAPPDATA "VIctory\$GpuProfile\data"
foreach ($managedPath in @($cacheDir, $dataDir)) {
    if (Test-WithinPath $managedPath $workspaceFull -or Test-WithinPath $managedPath $gameRoot -or Test-WithinPath $managedPath $repoFull) {
        throw 'Cache e dati AstraForge devono restare fuori dal workspace e dai file di gioco.'
    }
}
New-Item -ItemType Directory -Force -Path $runDir, $cacheDir, $dataDir | Out-Null

# The inspected fork calls D3D12CreateDevice(NULL), so the first DXGI adapter matters.
$probeScript = Join-Path $PSScriptRoot 'Collect-AstraForgeHardware.ps1'
$windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
if (-not (Test-Path -LiteralPath $probeScript -PathType Leaf) -or -not (Test-Path -LiteralPath $windowsPowerShell -PathType Leaf)) {
    throw 'Probe hardware o Windows PowerShell non disponibile: non posso verificare l adapter DXGI predefinito.'
}
$hardwarePath = Join-Path $runDir 'hardware.json'
$dxdiagPath = Join-Path $runDir 'dxdiag.txt'
& $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $probeScript -OutputPath $hardwarePath -DxDiagReportPath $dxdiagPath | Out-Null
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $hardwarePath -PathType Leaf)) {
    throw 'La rilevazione hardware è fallita; il runtime AstraForge non è stato avviato.'
}
$hardware = Get-Content -LiteralPath $hardwarePath -Raw | ConvertFrom-Json
$expectedDeviceIds = @($gpuProfileConfig.adapter.deviceIds | ForEach-Object { ([string]$_).ToUpperInvariant() })
$targetAdapter = @($hardware.GPU.DxgiAdapters | Where-Object {
    ([string]$_.VendorId).ToUpperInvariant() -eq ([string]$gpuProfileConfig.adapter.vendorId).ToUpperInvariant() -and
    ([string]$_.DeviceId).ToUpperInvariant() -in $expectedDeviceIds -and
    ([string]$_.Name) -match [string]$gpuProfileConfig.adapter.nameRegex
}) | Select-Object -First 1
if (-not $targetAdapter) {
    throw "GPU profile '$GpuProfile' expected $($gpuProfileConfig.displayName), but no matching DXGI adapter was detected."
}
$firstAdapter = $hardware.GPU.DxgiAdapters | Select-Object -First 1
if ([string]$targetAdapter.AdapterLuid -cne [string]$firstAdapter.AdapterLuid) {
    throw "Renderer uses the first DXGI adapter ($($firstAdapter.Name)); profile adapter $($targetAdapter.Name) is not first and this source has no explicit adapter override."
}
$d3d = $hardware.GPU.D3D12
if (-not $d3d) { throw "D3D12 feature data unavailable for '$($targetAdapter.Name)'." }
if ([version][string]$d3d.ShaderModel -lt [version][string]$gpuProfileConfig.adapter.shaderModelMinimum) {
    throw "GPU shader model $($d3d.ShaderModel) is below profile minimum $($gpuProfileConfig.adapter.shaderModelMinimum)."
}
if ($gpuProfileConfig.adapter.waveOpsRequired -and -not $d3d.WaveOps) {
    throw "GPU profile '$GpuProfile' requires D3D12 WaveOps."
}
if ([int]$d3d.WaveLaneCountMin -lt [int]$gpuProfileConfig.adapter.waveLaneCountMinimum -or
    [int]$d3d.WaveLaneCountMax -gt [int]$gpuProfileConfig.adapter.waveLaneCountMaximum) {
    throw "GPU wave lanes $($d3d.WaveLaneCountMin)-$($d3d.WaveLaneCountMax) exceed the profile's validated range."
}
switch ([string]$gpuProfileConfig.runtime.telemetryProvider) {
    'nvidia-smi' {
        $telemetry = $hardware.GPU.NvidiaSmi
        if (-not $telemetry) { throw 'The NVIDIA profile requires nvidia-smi telemetry, which is unavailable.' }
        $dedicatedMemoryMiB = [int]$telemetry.DedicatedMemoryMiB
        if ([string]$telemetry.ComputeCapability -cne [string]$gpuProfileConfig.adapter.computeCapability) {
            throw "GPU compute capability $($telemetry.ComputeCapability) does not match profile $($gpuProfileConfig.adapter.computeCapability)."
        }
    }
    default { throw "Unsupported telemetry provider '$($gpuProfileConfig.runtime.telemetryProvider)' for this launcher build." }
}
if ($dedicatedMemoryMiB -lt [int]$gpuProfileConfig.adapter.dedicatedMemoryMiB) {
    throw "GPU has $dedicatedMemoryMiB MiB dedicated memory; profile expects at least $($gpuProfileConfig.adapter.dedicatedMemoryMiB) MiB."
}
$availableCommit = [double]$hardware.RAM.AvailableCommitGiB
Assert-AstraForgeCommitHeadroom -AvailableGiB $availableCommit -MinimumGiB $MinimumAvailableCommitGiB
if ($availableCommit -lt [int]$gpuProfileConfig.runtime.warnBelowAvailableCommitGiB) {
    Write-Warning ("Commit disponibile {0:N1} GiB, sotto il margine indicativo di {1} GiB del profilo {2}; un host diverso può richiedere più spazio per evitare paging." -f $availableCommit, $gpuProfileConfig.runtime.warnBelowAvailableCommitGiB, $GpuProfile)
}

$environment = @{}
foreach ($property in $config.baselineEnvironment.PSObject.Properties) {
    $environment[$property.Name] = [string]$property.Value
}
$environment['VICTORY_TEXTURE_ROOM_PERCENT'] = [string]$selectedProfile.textureRoomPercent
$environment['VICTORY_CACHE_DIR'] = $cacheDir
$environment['VICTORY_DATA_DIR'] = $dataDir

$previousEnvironment = @{}
Get-ChildItem Env: | Where-Object Name -Like 'VICTORY_*' | ForEach-Object {
    $previousEnvironment[$_.Name] = $_.Value
    Remove-Item "Env:$($_.Name)"
}
foreach ($name in $environment.Keys) { Set-Item "Env:$name" $environment[$name] }

$stdoutPath = Join-Path $runDir 'victory.stdout.log'
$stderrPath = Join-Path $runDir 'victory.stderr.log'
$memoryCsv = Join-Path $runDir 'memory.csv'
$counterCsv = Join-Path $runDir 'gpu-process-memory.csv'
$argumentLine = 'run "{0}" --console {1} --execute' -f $gameExe, $Console
$process = $null
try {
    Write-Host "GPU profile: $GpuProfile ($($gpuProfileConfig.displayName); $($gpuProfileConfig.adapter.architecture)); not benchmarked on this PC."
    Write-Host "Tuning profile: $Profile ($($selectedProfile.textureRoomPercent)% texture-room admission)."
    Write-Host "First DXGI adapter: $($firstAdapter.Name) [$($firstAdapter.AdapterLuid)]"
    Write-Host "Commit disponibile: $('{0:N1}' -f $availableCommit) GiB"
    Write-Host "Log esterni al repository: $runDir"
    Write-Host "Intento: $($selectedProfile.intent)"
    $process = Start-Process -FilePath $runner -ArgumentList $argumentLine -WorkingDirectory $repo -NoNewWindow -PassThru `
        -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    'utc,private_gib,available_physical_gib,available_commit_gib,commit_limit_gib' | Set-Content -LiteralPath $memoryCsv -Encoding utf8
    'utc,counter_path,dedicated_bytes' | Set-Content -LiteralPath $counterCsv -Encoding utf8
    while ($true) {
        $process.Refresh()
        if ($process.HasExited) { break }
        $utc = (Get-Date).ToUniversalTime().ToString('o')
        $privateGiB = $process.PrivateMemorySize64 / 1GB
        $freePhysicalGiB = $null
        $freeCommitGiB = $null
        $commitLimitGiB = $null
        try {
            $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
            $freePhysicalGiB = [double]$os.FreePhysicalMemory / 1MB
        } catch { }
        try {
            $mem = Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory -ErrorAction Stop
            $commitLimitGiB = [double]$mem.CommitLimit / 1GB
            $freeCommitGiB = ([double]$mem.CommitLimit - [double]$mem.CommittedBytes) / 1GB
        } catch { }
        [pscustomobject]@{
            utc = $utc; private_gib = $privateGiB; available_physical_gib = $freePhysicalGiB
            available_commit_gib = $freeCommitGiB; commit_limit_gib = $commitLimitGiB
        } | Export-Csv -LiteralPath $memoryCsv -NoTypeInformation -Append
        try {
            $samples = (Get-Counter "\GPU Process Memory(pid_$($process.Id)*)\Dedicated Usage" -ErrorAction Stop).CounterSamples
            foreach ($sample in $samples) {
                [pscustomobject]@{ utc = $utc; counter_path = $sample.Path; dedicated_bytes = $sample.CookedValue } |
                    Export-Csv -LiteralPath $counterCsv -NoTypeInformation -Append
            }
        } catch { }
        Start-Sleep -Seconds 5
    }
    $process.WaitForExit()
    $process.Refresh()
    $exitCode = $process.ExitCode
    if ($null -eq $exitCode) { throw 'Runtime AstraForge terminato senza rendere disponibile un exit code.' }
    Write-Host "Runtime AstraForge terminato con exit code $exitCode."
    Write-Host "Output: $stdoutPath"
    Write-Host "Errori: $stderrPath"
    Write-Host "Telemetria: $memoryCsv, $counterCsv"
    if ($exitCode -ne 0) { throw "Runtime AstraForge terminato con exit code $exitCode." }
} finally {
    foreach ($entry in $previousEnvironment.GetEnumerator()) { Set-Item "Env:$($entry.Key)" $entry.Value }
    Get-ChildItem Env: | Where-Object { $_.Name -like 'VICTORY_*' -and -not $previousEnvironment.ContainsKey($_.Name) } |
        ForEach-Object { Remove-Item "Env:$($_.Name)" -ErrorAction SilentlyContinue }
}
