[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RuntimeExe,
    [Parameter(Mandatory = $true)][string]$GameExe,
    [Parameter(Mandatory = $true)][ValidatePattern('^scene-[A-Za-z0-9_-]+$')][string]$Scenario,
    [Parameter(Mandatory = $true)][string]$PresentMonExe,
    [string]$GpuProfile = 'nvidia-rtx3070',
    [ValidateSet('series-s', 'series-x')][string]$Console,
    [ValidateSet('Stability', 'Balanced', 'Performance', 'Quality')][string]$Profile = 'Balanced',
    [ValidateRange(60, 3600)][int]$DurationSeconds = 600,
    [string]$BuildLabel = 'unspecified',
    [ValidateSet('cold', 'warm', 'unspecified')][string]$CacheState = 'unspecified',
    [ValidateNotNullOrEmpty()][string]$InternalResolutionLabel = 'unknown',
    [ValidateNotNullOrEmpty()][string]$OutputResolutionLabel = 'unknown',
    [string]$SourceRoot = (Join-Path $PSScriptRoot '..\third_party\nvidia-3070-VI'),
    [hashtable]$RuntimeOverride = @{},
    [ValidateRange(0, 256)][int]$MinimumAvailableCommitGiB = 12,
    [switch]$AllowLowCommit,
    [switch]$AllowSeriesX,
    [string]$CacheDirectory,
    [string]$CacheSeedDirectory,
    [string]$DataDirectory,
    [string]$OutputRoot = "$env:LOCALAPPDATA\AstraForge\benchmarks"
)

$ErrorActionPreference = 'Stop'
Import-Module -Name (Join-Path $PSScriptRoot 'AstraForge-BenchmarkCommon.psm1') -Force

function Get-AbsolutePath([string]$Path) {
    [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Path).Path)
}

function Test-PathWithin([string]$Path, [string]$Root) {
    $fullPath = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
    $rootPath = [System.IO.Path]::GetFullPath($Root).TrimEnd('\')
    return $fullPath.Equals($rootPath, [System.StringComparison]::OrdinalIgnoreCase) -or
        $fullPath.StartsWith($rootPath + '\', [System.StringComparison]::OrdinalIgnoreCase)
}

function ConvertTo-Number([object]$Value) {
    if ($null -eq $Value) { return $null }
    $parsed = 0.0
    $text = ([string]$Value).Trim()
    if ([double]::TryParse($text, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$parsed)) {
        return $parsed
    }
    return $null
}

function Get-Percentile([double[]]$SortedValues, [double]$Percentile) {
    if (-not $SortedValues -or $SortedValues.Count -eq 0) { return $null }
    $index = [int][Math]::Ceiling($Percentile * $SortedValues.Count) - 1
    $index = [Math]::Max(0, [Math]::Min($index, $SortedValues.Count - 1))
    return $SortedValues[$index]
}

function Get-FrameSummary([string]$CsvPath) {
    if (-not (Test-Path -LiteralPath $CsvPath)) { throw "PresentMon non ha creato il CSV: $CsvPath" }
    $rows = @(Import-Csv -LiteralPath $CsvPath)
    if ($rows.Count -eq 0) { throw 'PresentMon ha creato un CSV senza frame.' }

    $frameTypeProperty = $rows[0].PSObject.Properties['FrameType']
    $hasFrameTypes = $null -ne $frameTypeProperty -and @($rows | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.FrameType) }).Count -gt 0
    if ($hasFrameTypes) {
        $applicationRows = @($rows | Where-Object { ([string]$_.FrameType) -match 'Application' })
        $generatedRows = @($rows | Where-Object { ([string]$_.FrameType) -match 'Generated' })
        if ($applicationRows.Count -eq 0) {
            throw 'PresentMon ha classificato FrameType ma non ha trovato frame Application; rifiuto di conteggiare frame non identificati come FPS reali.'
        }
        $countingRule = 'FrameType=Application when PresentMon provides frame types; otherwise all CSV presents.'
    } else {
        $applicationRows = $rows
        $generatedRows = @()
        $countingRule = 'PresentMon did not classify frame types; reported values count captured process presents.'
    }

    # Present intervals measure app frames actually presented; simulation cadence can differ from render cadence.
    $timeColumn = 'MsBetweenPresents'
    $frameTimes = @($applicationRows | ForEach-Object { ConvertTo-Number $_.$timeColumn } | Where-Object { $null -ne $_ -and $_ -gt 0 })
    if ($frameTimes.Count -eq 0) { throw "Nessun intervallo frame valido nella colonna $timeColumn." }
    $simulationValues = @($applicationRows | ForEach-Object { ConvertTo-Number $_.MsBetweenSimulationStart } | Where-Object { $null -ne $_ -and $_ -gt 0 })
    [double[]]$sorted = $frameTimes
    [Array]::Sort($sorted)
    $mean = ($frameTimes | Measure-Object -Average).Average
    $p50 = Get-Percentile $sorted 0.50
    $p95 = Get-Percentile $sorted 0.95
    $p99 = Get-Percentile $sorted 0.99
    $p999 = Get-Percentile $sorted 0.999

    [pscustomobject]@{
        PresentRows = $rows.Count
        ApplicationFrames = $frameTimes.Count
        GeneratedFrames = $generatedRows.Count
        FrameTypeClassified = $hasFrameTypes
        CountRule = $countingRule
        IntervalColumn = $timeColumn
        AverageFps = if ($mean -gt 0) { 1000.0 / $mean } else { $null }
        MedianFps = if ($p50 -gt 0) { 1000.0 / $p50 } else { $null }
        OnePercentLowFps = if ($p99 -gt 0) { 1000.0 / $p99 } else { $null }
        ZeroPointOnePercentLowFps = if ($p999 -gt 0) { 1000.0 / $p999 } else { $null }
        FrametimeMeanMs = $mean
        FrametimeMedianMs = $p50
        FrametimeP95Ms = $p95
        FrametimeP99Ms = $p99
        FrametimeP999Ms = $p999
        SimulationStartIntervalMeanMs = if ($simulationValues.Count -gt 0) { ($simulationValues | Measure-Object -Average).Average } else { $null }
    }
}

function Add-ThreadSamples([int]$ProcessId, [hashtable]$Previous, [double]$ElapsedSeconds, [string]$ThreadCsv, [string]$MemoryCsv, [int]$LogicalProcessors) {
    $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    if (-not $process) { return }
    $timestamp = (Get-Date).ToUniversalTime().ToString('o')
    $memoryRow = [pscustomobject]@{
        TimestampUtc = $timestamp
        ProcessId = $ProcessId
        WorkingSetMiB = [Math]::Round($process.WorkingSet64 / 1MB, 2)
        PrivateBytesMiB = [Math]::Round($process.PrivateMemorySize64 / 1MB, 2)
        ThreadCount = $process.Threads.Count
        TotalCpuSeconds = [Math]::Round($process.TotalProcessorTime.TotalSeconds, 3)
    }
    if (Test-Path -LiteralPath $MemoryCsv) { $memoryRow | Export-Csv -LiteralPath $MemoryCsv -NoTypeInformation -Append -Encoding UTF8 }
    else { $memoryRow | Export-Csv -LiteralPath $MemoryCsv -NoTypeInformation -Encoding UTF8 }

    $threadRows = @()
    foreach ($thread in $process.Threads) {
        $threadId = [int]$thread.Id
        $cpuSeconds = [double]$thread.TotalProcessorTime.TotalSeconds
        if ($Previous.ContainsKey($threadId)) {
            $delta = [Math]::Max(0.0, $cpuSeconds - [double]$Previous[$threadId])
            $oneCorePercent = if ($ElapsedSeconds -gt 0) { 100.0 * $delta / $ElapsedSeconds } else { 0.0 }
            $threadRows += [pscustomobject]@{
                TimestampUtc = $timestamp
                ProcessId = $ProcessId
                ThreadId = $threadId
                CpuSecondsDelta = [Math]::Round($delta, 4)
                OneCoreUtilizationPercent = [Math]::Round($oneCorePercent, 2)
                LogicalCpuUtilizationPercent = [Math]::Round($oneCorePercent / [Math]::Max(1, $LogicalProcessors), 2)
            }
        }
        $Previous[$threadId] = $cpuSeconds
    }
    if ($threadRows.Count -gt 0) {
        if (Test-Path -LiteralPath $ThreadCsv) { $threadRows | Export-Csv -LiteralPath $ThreadCsv -NoTypeInformation -Append -Encoding UTF8 }
        else { $threadRows | Export-Csv -LiteralPath $ThreadCsv -NoTypeInformation -Encoding UTF8 }
    }
}

function Add-GpuProcessSamples([int[]]$ProcessIds, [string]$AdapterLuid, [string]$CsvPath) {
    try {
        $samples = (Get-Counter -Counter @(
            '\GPU Process Memory(*)\Dedicated Usage',
            '\GPU Process Memory(*)\Shared Usage',
            '\GPU Engine(*)\Utilization Percentage'
        ) -ErrorAction Stop).CounterSamples
    } catch {
        return
    }

    $wantedIds = @{};
    foreach ($id in $ProcessIds) { $wantedIds[[int]$id] = $true }
    $timestamp = (Get-Date).ToUniversalTime().ToString('o')
    $rows = @()
    foreach ($sample in $samples) {
        if ([string]$sample.Path -notmatch 'pid_(?<pid>\d+)_') { continue }
        $counterPid = [int]$Matches.pid
        if (-not $wantedIds.ContainsKey($counterPid)) { continue }
        $counter = [string]$sample.Path
        if ($AdapterLuid -and $counter -notmatch [regex]::Escape("luid_$AdapterLuid")) { continue }
        $metric = ($counter -split '\\')[-1]
        $rows += [pscustomobject]@{
            TimestampUtc = $timestamp
            ProcessId = $counterPid
            Metric = $metric
            Value = [Math]::Round([double]$sample.CookedValue, 3)
            Unit = if ($metric -match 'Usage$') { 'bytes' } else { 'percent' }
            CounterPath = $counter
        }
    }
    if ($rows.Count -eq 0) { return }
    if (Test-Path -LiteralPath $CsvPath) { $rows | Export-Csv -LiteralPath $CsvPath -NoTypeInformation -Append -Encoding UTF8 }
    else { $rows | Export-Csv -LiteralPath $CsvPath -NoTypeInformation -Encoding UTF8 }
}

function Add-SystemMemorySample([string]$CsvPath) {
    $status = [VictoryHardwareProbe]::GetMemoryStatus()
    $row = [pscustomobject]@{
        TimestampUtc = (Get-Date).ToUniversalTime().ToString('o')
        MemoryLoadPercent = $status.MemoryLoad
        AvailablePhysicalMiB = [Math]::Round($status.AvailablePhysical / 1MB, 2)
        TotalPhysicalMiB = [Math]::Round($status.TotalPhysical / 1MB, 2)
        AvailableCommitMiB = [Math]::Round($status.AvailablePageFile / 1MB, 2)
        CommitLimitMiB = [Math]::Round($status.TotalPageFile / 1MB, 2)
    }
    if (Test-Path -LiteralPath $CsvPath) { $row | Export-Csv -LiteralPath $CsvPath -NoTypeInformation -Append -Encoding UTF8 }
    else { $row | Export-Csv -LiteralPath $CsvPath -NoTypeInformation -Encoding UTF8 }
}

function Get-SystemMemorySummary([string]$CsvPath) {
    if (-not (Test-Path -LiteralPath $CsvPath)) { return $null }
    $rows = @(Import-Csv -LiteralPath $CsvPath)
    if ($rows.Count -eq 0) { return $null }
    $result = [ordered]@{ Samples = $rows.Count }
    foreach ($metric in @('MemoryLoadPercent', 'AvailablePhysicalMiB', 'AvailableCommitMiB')) {
        $values = @($rows | ForEach-Object { ConvertTo-Number $_.$metric } | Where-Object { $null -ne $_ })
        if ($values.Count -eq 0) { continue }
        [double[]]$sorted = $values
        [Array]::Sort($sorted)
        $result[$metric] = [ordered]@{
            Mean = [Math]::Round((($values | Measure-Object -Average).Average), 2)
            P05 = [Math]::Round((Get-Percentile $sorted 0.05), 2)
            P95 = [Math]::Round((Get-Percentile $sorted 0.95), 2)
            Minimum = [Math]::Round($sorted[0], 2)
            Maximum = [Math]::Round($sorted[-1], 2)
        }
    }
    return $result
}

function Get-CsvMetricSummary([string]$CsvPath, [string[]]$Metrics, [string]$ValueColumn = 'Value') {
    if (-not (Test-Path -LiteralPath $CsvPath)) { return @() }
    $rows = @(Import-Csv -LiteralPath $CsvPath | Where-Object { $_.Metric -in $Metrics })
    foreach ($metric in $Metrics) {
        $values = @($rows | Where-Object Metric -eq $metric | ForEach-Object { ConvertTo-Number $_.$ValueColumn } | Where-Object { $null -ne $_ })
        if ($values.Count -eq 0) { continue }
        [double[]]$sorted = $values
        [Array]::Sort($sorted)
        [pscustomobject]@{
            Metric = $metric
            Samples = $values.Count
            Mean = [Math]::Round((($values | Measure-Object -Average).Average), 3)
            P95 = [Math]::Round((Get-Percentile $sorted 0.95), 3)
            Maximum = [Math]::Round($sorted[-1], 3)
        }
    }
}

function Get-NvidiaTelemetrySummary([string]$CsvPath) {
    if (-not (Test-Path -LiteralPath $CsvPath)) { return @() }
    $rows = @(Import-Csv -LiteralPath $CsvPath -Header @('Timestamp', 'GpuUtilPercent', 'MemoryUtilPercent', 'MemoryTotalMiB', 'MemoryUsedMiB', 'MemoryFreeMiB', 'GraphicsClockMHz', 'MemoryClockMHz', 'PowerWatts', 'TemperatureC', 'PState') | Where-Object { $_.Timestamp -match '^\d{4}/\d{2}/\d{2}' })
    $metrics = @('GpuUtilPercent', 'MemoryUtilPercent', 'MemoryUsedMiB', 'MemoryFreeMiB', 'GraphicsClockMHz', 'MemoryClockMHz', 'PowerWatts', 'TemperatureC')
    $summary = @()
    foreach ($metric in $metrics) {
        $values = @($rows | ForEach-Object { ConvertTo-Number $_.$metric } | Where-Object { $null -ne $_ })
        if ($values.Count -eq 0) { continue }
        [double[]]$sorted = $values
        [Array]::Sort($sorted)
        $summary += [pscustomobject]@{
            Metric = $metric
            Samples = $values.Count
            Mean = [Math]::Round((($values | Measure-Object -Average).Average), 2)
            P95 = [Math]::Round((Get-Percentile $sorted 0.95), 2)
            Maximum = [Math]::Round($sorted[-1], 2)
        }
    }
    return $summary
}

$scriptRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$resolvedSourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$victoryPath = Get-AbsolutePath $RuntimeExe
$gamePath = Get-AbsolutePath $GameExe
$gameRoot = Split-Path -Parent $gamePath
$presentMonPath = Get-AbsolutePath $PresentMonExe
if (Test-PathWithin $gamePath $scriptRoot) {
    throw 'GameExe deve puntare ai file personali fuori dal repository.'
}
if ((Test-PathWithin $gamePath $resolvedSourceRoot) -or (Test-PathWithin $OutputRoot $scriptRoot) -or
    (Test-PathWithin $OutputRoot $resolvedSourceRoot) -or (Test-PathWithin $OutputRoot $gameRoot)) {
    throw 'OutputRoot deve restare fuori dal codice e dai file di gioco.'
}
if ($Console -eq 'series-x' -and -not $AllowSeriesX) {
    throw 'Series X su una GPU da 8 GB richiede una prova esplicita: aggiungi -AllowSeriesX dopo avere verificato la memoria disponibile.'
}
if ($Console -eq 'series-x') {
    Write-Warning 'Series X è sperimentale su 8 GB; monitora paging, texture in attesa e perdita del dispositivo.'
}

$gpuManifestPath = Join-Path $scriptRoot 'profiles\gpu-profiles.json'
$gpuManifest = Get-Content -LiteralPath $gpuManifestPath -Raw | ConvertFrom-Json
$gpuProfileConfig = $gpuManifest.profiles.PSObject.Properties[$GpuProfile].Value
if ($null -eq $gpuProfileConfig) {
    throw "GPU profile '$GpuProfile' is not defined in $gpuManifestPath."
}
if ([string]::IsNullOrWhiteSpace($Console)) { $Console = [string]$gpuProfileConfig.runtime.consoleDefault }
if ([string]$gpuProfileConfig.runtime.adapterSelection -ne 'first-dxgi-adapter') {
    throw "Unsupported adapter-selection mode '$($gpuProfileConfig.runtime.adapterSelection)' for this source."
}
if ([string]$gpuProfileConfig.runtime.telemetryProvider -ne 'nvidia-smi') {
    throw "Unsupported telemetry provider '$($gpuProfileConfig.runtime.telemetryProvider)' for this benchmark build."
}
if ([string]::IsNullOrWhiteSpace($DataDirectory)) { $DataDirectory = Join-Path $env:LOCALAPPDATA "VIctory\$GpuProfile\data" }
$profilesRoot = (Resolve-Path -LiteralPath (Join-Path $scriptRoot 'profiles')).Path
$profileFile = Join-Path $profilesRoot ([string]$gpuProfileConfig.runtime.tuningConfig)
$profilesRootPrefix = [System.IO.Path]::GetFullPath($profilesRoot).TrimEnd('\\') + '\\'
if (-not [System.IO.Path]::GetFullPath($profileFile).StartsWith($profilesRootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'GPU tuning config must remain inside the workspace profiles directory.'
}
$profileConfig = Get-Content -LiteralPath $profileFile -Raw | ConvertFrom-Json
$selectedProfile = $profileConfig.profiles.PSObject.Properties[$Profile].Value
if ($null -eq $selectedProfile) { throw "Profilo '$Profile' non trovato in $profileFile." }
$sourceManifestPath = Join-Path $resolvedSourceRoot '.source-manifest.json'
$sourceManifest = Get-Content -LiteralPath $sourceManifestPath -Raw | ConvertFrom-Json
$expectedSource = '{0}@{1}' -f $sourceManifest.repository, $sourceManifest.commit
if ([string]$profileConfig.source -cne $expectedSource) {
    throw "Il profilo è riferito a '$($profileConfig.source)', ma il source manifest dichiara '$expectedSource'."
}
$resourceSource = Join-Path $resolvedSourceRoot 'crates\victory-gpu\src\resource.rs'
$resourceText = Get-Content -LiteralPath $resourceSource -Raw
if ($resourceText -notmatch 'VICTORY_TEXTURE_ROOM_PERCENT' -or
    $resourceText -notmatch 'map_or\(90,\s*\|percent\|\s*percent\.clamp\(50,\s*97\)\)') {
    throw 'La semantica o l’intervallo del profilo non corrispondono al codice sorgente; acquisizione annullata.'
}
$rustSourcePaths = @(Get-ChildItem -LiteralPath (Join-Path $resolvedSourceRoot 'crates') -Recurse -File -Filter '*.rs' | ForEach-Object FullName)
foreach ($name in $RuntimeOverride.Keys) {
    if ([string]$name -notmatch '^VICTORY_[A-Z0-9_]+$') {
        throw "Override runtime non valido: '$name'. Sono ammessi solo nomi VIctory in maiuscolo."
    }
    if ($name -in @('VICTORY_CACHE_DIR', 'VICTORY_DATA_DIR', 'VICTORY_GAME_DIR')) {
        throw "'$name' è gestito dal launcher per tenere cache, dati e gioco fuori dal repository."
    }
    if (-not (Select-String -Path $rustSourcePaths -SimpleMatch -Pattern ([string]$name) -Quiet)) {
        throw "'$name' non compare nel codice Rust di questa revisione; override rifiutato."
    }
}

$sourceCommit = $null
$sourceDirty = $null
$git = Get-Command git.exe -ErrorAction Stop
$commitOutput = & $git.Source -C $resolvedSourceRoot rev-parse HEAD 2>$null
if ($LASTEXITCODE -ne 0) { throw 'Impossibile rilevare il commit del source checkout.' }
$sourceCommit = ([string]$commitOutput).Trim()
$statusOutput = & $git.Source -C $resolvedSourceRoot status --porcelain 2>$null
if ($LASTEXITCODE -ne 0) { throw 'Impossibile verificare lo stato pulito del source checkout.' }
$sourceDirty = [bool]$statusOutput

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$safeScenario = ($Scenario -replace '[^A-Za-z0-9._-]', '_').Trim('_')
$runDirectory = Join-Path $OutputRoot "$timestamp-$safeScenario-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
$cacheSuffix = [guid]::NewGuid().ToString('N')
$cacheDefault = if ($CacheState -eq 'cold') {
    Join-Path $env:LOCALAPPDATA ("VIctory\$GpuProfile\cache-cold-{0}-{1}" -f $timestamp, $cacheSuffix)
} elseif ($CacheState -eq 'warm') {
    Join-Path $env:LOCALAPPDATA ("VIctory\$GpuProfile\cache-warm-{0}-{1}" -f $timestamp, $cacheSuffix)
} else {
    Join-Path $env:LOCALAPPDATA "VIctory\$GpuProfile\cache"
}
$cacheDir = [System.IO.Path]::GetFullPath($(if ($CacheDirectory) { $CacheDirectory } else { $cacheDefault }))
$dataDir = [System.IO.Path]::GetFullPath($DataDirectory)
$cacheSeedDir = if ($CacheSeedDirectory) { [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $CacheSeedDirectory).Path) } else { $null }
$outputDirectory = [System.IO.Path]::GetFullPath($OutputRoot)
if ((Test-PathWithin $cacheDir $scriptRoot) -or (Test-PathWithin $cacheDir $resolvedSourceRoot) -or (Test-PathWithin $cacheDir $gameRoot) -or
    (Test-PathWithin $dataDir $scriptRoot) -or (Test-PathWithin $dataDir $resolvedSourceRoot) -or (Test-PathWithin $dataDir $gameRoot) -or
    (Test-PathWithin $cacheDir $dataDir) -or (Test-PathWithin $dataDir $cacheDir) -or
    (Test-PathWithin $cacheDir $outputDirectory) -or (Test-PathWithin $outputDirectory $cacheDir) -or
    (Test-PathWithin $dataDir $outputDirectory) -or (Test-PathWithin $outputDirectory $dataDir) -or
    ($cacheSeedDir -and ((Test-PathWithin $cacheSeedDir $scriptRoot) -or (Test-PathWithin $cacheSeedDir $resolvedSourceRoot) -or
        (Test-PathWithin $cacheSeedDir $gameRoot) -or (Test-PathWithin $cacheSeedDir $dataDir) -or (Test-PathWithin $dataDir $cacheSeedDir) -or
        (Test-PathWithin $cacheSeedDir $outputDirectory) -or (Test-PathWithin $outputDirectory $cacheSeedDir) -or
        (Test-PathWithin $cacheSeedDir $cacheDir) -or (Test-PathWithin $cacheDir $cacheSeedDir)))) {
    throw 'Cache e dati AstraForge devono restare distinti, fuori dal repository e fuori dai file di gioco.'
}
$cacheExists = Test-Path -LiteralPath $cacheDir
if ($cacheExists -and -not (Test-Path -LiteralPath $cacheDir -PathType Container)) { throw "CacheDirectory non è una cartella: $cacheDir" }
$cacheWasEmptyAtStart = -not $cacheExists -or @(Get-ChildItem -LiteralPath $cacheDir -Force | Select-Object -First 1).Count -eq 0
if ($CacheState -eq 'cold' -and -not $cacheWasEmptyAtStart) {
    throw "CacheState=cold richiede una cartella di cache vuota; i file esistenti restano intatti: $cacheDir"
}
if ($CacheState -eq 'warm') {
    if (-not $CacheSeedDirectory) { throw 'CacheState=warm richiede -CacheSeedDirectory con una cache preparata e popolata.' }
    if ($cacheExists) { throw "La destinazione warm deve essere nuova per preservare il seed; destinazione già esistente: $cacheDir" }
    if (-not (Test-Path -LiteralPath $cacheSeedDir -PathType Container)) { throw "Cache seed non è una cartella: $cacheSeedDir" }
    $cacheCopy = Copy-AstraForgeCacheSeed -SourceDirectory $cacheSeedDir -DestinationDirectory $cacheDir
    $cacheSeedFingerprint = $cacheCopy.Fingerprint
    $cacheWasEmptyAtStart = $false
} elseif ($CacheSeedDirectory) {
    throw '-CacheSeedDirectory si usa solo con -CacheState warm.'
}
New-Item -ItemType Directory -Force -Path $runDirectory | Out-Null

$hardwarePath = Join-Path $runDirectory 'hardware.json'
$dxDiagPath = Join-Path $runDirectory 'dxdiag.txt'
$dxDiagExe = Join-Path $env:WINDIR 'System32\dxdiag.exe'
try {
    $dxDiag = Start-Process -FilePath $dxDiagExe -ArgumentList "/t `"$dxDiagPath`"" -PassThru -Wait -WindowStyle Hidden
    if ($dxDiag.ExitCode -ne 0) { Write-Warning "dxdiag exit code $($dxDiag.ExitCode)" }
} catch { Write-Warning "dxdiag non disponibile: $($_.Exception.Message)" }
& (Join-Path $PSScriptRoot 'Collect-AstraForgeHardware.ps1') -DxDiagReportPath $dxDiagPath -OutputPath $hardwarePath | Out-Null
$hardwareReport = Get-Content -LiteralPath $hardwarePath -Raw | ConvertFrom-Json
$expectedDeviceIds = @($gpuProfileConfig.adapter.deviceIds | ForEach-Object { ([string]$_).ToUpperInvariant() })
$targetAdapter = @($hardwareReport.GPU.DxgiAdapters | Where-Object {
    ([string]$_.VendorId).ToUpperInvariant() -eq ([string]$gpuProfileConfig.adapter.vendorId).ToUpperInvariant() -and
    ([string]$_.DeviceId).ToUpperInvariant() -in $expectedDeviceIds -and
    ([string]$_.Name) -match [string]$gpuProfileConfig.adapter.nameRegex
}) | Select-Object -First 1
if (-not $targetAdapter) { throw "GPU profile '$GpuProfile' expected $($gpuProfileConfig.displayName), but no matching DXGI adapter was detected." }
$firstAdapter = $hardwareReport.GPU.DxgiAdapters | Select-Object -First 1
if ([string]$targetAdapter.AdapterLuid -cne [string]$firstAdapter.AdapterLuid) {
    throw "Profile adapter $($targetAdapter.Name) is not first in DXGI order; this source has no explicit adapter override."
}
$d3d = $hardwareReport.GPU.D3D12
if (-not $d3d -or [version][string]$d3d.ShaderModel -lt [version][string]$gpuProfileConfig.adapter.shaderModelMinimum) {
    throw "D3D12 shader model is unavailable or below profile minimum $($gpuProfileConfig.adapter.shaderModelMinimum)."
}
if ($gpuProfileConfig.adapter.waveOpsRequired -and -not $d3d.WaveOps) { throw "GPU profile '$GpuProfile' requires D3D12 WaveOps." }
if ([int]$d3d.WaveLaneCountMin -lt [int]$gpuProfileConfig.adapter.waveLaneCountMinimum -or
    [int]$d3d.WaveLaneCountMax -gt [int]$gpuProfileConfig.adapter.waveLaneCountMaximum) {
    throw "GPU wave lanes $($d3d.WaveLaneCountMin)-$($d3d.WaveLaneCountMax) exceed the profile's validated range."
}
$nvidiaTelemetry = $hardwareReport.GPU.NvidiaSmi
if (-not $nvidiaTelemetry -or [string]$nvidiaTelemetry.ComputeCapability -cne [string]$gpuProfileConfig.adapter.computeCapability) {
    throw "GPU compute capability is unavailable or does not match profile '$GpuProfile'."
}
if ([int]$nvidiaTelemetry.DedicatedMemoryMiB -lt [int]$gpuProfileConfig.adapter.dedicatedMemoryMiB) {
    throw "Detected dedicated memory $($nvidiaTelemetry.DedicatedMemoryMiB) MiB is below the profile minimum $($gpuProfileConfig.adapter.dedicatedMemoryMiB) MiB."
}
$adapterLuid = [string]$targetAdapter.AdapterLuid
$availableCommitGiB = [double]$hardwareReport.RAM.AvailableCommitGiB
if ($availableCommitGiB -lt $MinimumAvailableCommitGiB -and -not $AllowLowCommit) {
    throw ("Commit disponibile {0:N1} GiB, sotto la soglia {1} GiB. Libera memoria oppure usa -AllowLowCommit dopo aver valutato il rischio." -f $availableCommitGiB, $MinimumAvailableCommitGiB)
}
if ($availableCommitGiB -lt [int]$gpuProfileConfig.runtime.warnBelowAvailableCommitGiB) {
    Write-Warning ("Commit disponibile {0:N1} GiB, sotto il margine indicativo di {1} GiB per il profilo {2}." -f $availableCommitGiB, $gpuProfileConfig.runtime.warnBelowAvailableCommitGiB, $GpuProfile)
}
$nvidiaSmi = Get-Command nvidia-smi.exe -ErrorAction Stop
$environmentPath = Join-Path $runDirectory 'environment.json'

$victoryStdout = Join-Path $runDirectory 'victory.stdout.log'
$victoryStderr = Join-Path $runDirectory 'victory.stderr.log'
$frameCsv = Join-Path $runDirectory 'presentmon.csv'
$presentMonStdout = Join-Path $runDirectory 'presentmon.stdout.log'
$presentMonStderr = Join-Path $runDirectory 'presentmon.stderr.log'
$gpuCsv = Join-Path $runDirectory 'gpu.csv'
$gpuProcessCsv = Join-Path $runDirectory 'gpu-process.csv'
$gpuStderr = Join-Path $runDirectory 'nvidia-smi.stderr.log'
$threadCsv = Join-Path $runDirectory 'cpu-threads.csv'
$processCsv = Join-Path $runDirectory 'process-memory.csv'
$systemMemoryCsv = Join-Path $runDirectory 'system-memory.csv'
$graphicsEventsCsv = Join-Path $runDirectory 'graphics-events.csv'
$logicalProcessors = [Environment]::ProcessorCount

$victoryProcess = $null
$gpuProcess = $null
$presentMonProcess = $null
$captureSucceeded = $false
$previousVictoryEnvironment = @{}
Get-ChildItem Env: | Where-Object Name -Like 'VICTORY_*' | ForEach-Object {
    $previousVictoryEnvironment[$_.Name] = $_.Value
}
try {
$profileEnvironment = @{}
foreach ($property in $profileConfig.baselineEnvironment.PSObject.Properties) {
    $profileEnvironment[$property.Name] = [string]$property.Value
}
$profileEnvironment['VICTORY_TEXTURE_ROOM_PERCENT'] = [string]$selectedProfile.textureRoomPercent
$profileEnvironment['VICTORY_CACHE_DIR'] = $cacheDir
$profileEnvironment['VICTORY_DATA_DIR'] = $dataDir
foreach ($entry in $RuntimeOverride.GetEnumerator()) { $profileEnvironment[[string]$entry.Key] = [string]$entry.Value }
Get-ChildItem Env: | Where-Object Name -Like 'VICTORY_*' | ForEach-Object { Remove-Item "Env:$($_.Name)" }
foreach ($name in $profileEnvironment.Keys) { Set-Item "Env:$name" $profileEnvironment[$name] }
New-Item -ItemType Directory -Force -Path $cacheDir, $dataDir | Out-Null
$victoryEnvironment = Get-ChildItem Env: | Where-Object { ($_.Name -like 'VICTORY_*' -and $_.Name -notmatch 'KEY|TOKEN|SECRET|PASSWORD|AUTH') -or $_.Name -in @('RUST_LOG', 'RUST_BACKTRACE') } | Sort-Object Name | ForEach-Object {
    [pscustomobject]@{ Name = $_.Name; Value = $_.Value }
}
[System.IO.File]::WriteAllText($environmentPath, ($victoryEnvironment | ConvertTo-Json -Depth 4), (New-Object System.Text.UTF8Encoding($false)))
$victoryArguments = "run `"$gamePath`" --console $Console --execute"
$runtimeExecutableSha256 = (Get-FileHash -LiteralPath $victoryPath -Algorithm SHA256).Hash
Write-Host "Avvio runtime AstraForge. Scena: $Scenario; profilo console: $Console."
$victoryProcess = Start-Process -FilePath $victoryPath -ArgumentList $victoryArguments -PassThru -WindowStyle Normal -RedirectStandardOutput $victoryStdout -RedirectStandardError $victoryStderr
if ($CacheState -eq 'cold') {
    Write-Host 'Questa acquisizione parte da una cache VIctory vuota al lancio; la preparazione manuale della scena avviene prima del timer e può già compilare shader.'
    [void](Read-Host 'Entra nella scena scelta, poi premi Invio per acquisire la route di gameplay')
} else {
    Write-Host 'Entra nel gameplay, raggiungi la scena scelta e attendi che la compilazione iniziale si stabilizzi.'
    [void](Read-Host 'Quando la scena è pronta, premi Invio per iniziare il benchmark')
}

$frameTarget = $victoryProcess
$gameProcessName = [System.IO.Path]::GetFileNameWithoutExtension($gamePath)
try {
    $gameProcess = Get-Process -Name $gameProcessName -ErrorAction Stop | Where-Object {
        try { [System.IO.Path]::GetFullPath($_.Path).Equals($gamePath, [System.StringComparison]::OrdinalIgnoreCase) }
        catch { $false }
    } | Select-Object -First 1
    if ($gameProcess) { $frameTarget = $gameProcess }
} catch { }
$sampleProcessIds = @($victoryProcess.Id, $frameTarget.Id) | Select-Object -Unique
Write-Host "PresentMon PID $($frameTarget.Id) ($($frameTarget.ProcessName)); Runtime PID $($victoryProcess.Id)."

$gpuArguments = '--query-gpu=timestamp,utilization.gpu,utilization.memory,memory.total,memory.used,memory.free,clocks.current.graphics,clocks.current.memory,power.draw,temperature.gpu,pstate --format=csv,noheader,nounits --loop-ms=1000'
$gpuProcess = Start-Process -FilePath $nvidiaSmi.Source -ArgumentList $gpuArguments -PassThru -WindowStyle Hidden -RedirectStandardOutput $gpuCsv -RedirectStandardError $gpuStderr
$presentMonArguments = "--process_id $($frameTarget.Id) --output_file `"$frameCsv`" --timed $DurationSeconds --date_time --exclude_dropped --v2_metrics --track_frame_type --terminate_after_timed"
$presentMonProcess = Start-Process -FilePath $presentMonPath -ArgumentList $presentMonArguments -PassThru -WindowStyle Hidden -RedirectStandardOutput $presentMonStdout -RedirectStandardError $presentMonStderr
Start-Sleep -Seconds 2
if ($presentMonProcess.HasExited -and $presentMonProcess.ExitCode -ne 0) {
    $pmError = if (Test-Path $presentMonStderr) { Get-Content $presentMonStderr -Raw } else { 'PresentMon è terminato subito.' }
    Stop-Process -Id $gpuProcess.Id -Force -ErrorAction SilentlyContinue
    throw "PresentMon non è partito. $pmError"
}

$captureStart = (Get-Date).ToUniversalTime()
$captureEnd = $captureStart.AddSeconds($DurationSeconds + 15)
$previousThreadCpu = @{}
$sampleProcessIds | ForEach-Object { $previousThreadCpu[[int]$_] = @{} }
$lastSample = [System.Diagnostics.Stopwatch]::StartNew()
while (-not $presentMonProcess.HasExited -and (Get-Date).ToUniversalTime() -lt $captureEnd) {
    $elapsed = $lastSample.Elapsed.TotalSeconds
    $lastSample.Restart()
    foreach ($sampleId in $sampleProcessIds) {
        Add-ThreadSamples -ProcessId $sampleId -Previous $previousThreadCpu[[int]$sampleId] -ElapsedSeconds $elapsed -ThreadCsv $threadCsv -MemoryCsv $processCsv -LogicalProcessors $logicalProcessors
    }
    Add-GpuProcessSamples -ProcessIds $sampleProcessIds -AdapterLuid $adapterLuid -CsvPath $gpuProcessCsv
    Add-SystemMemorySample -CsvPath $systemMemoryCsv
    Start-Sleep -Milliseconds 900
    $presentMonProcess.Refresh()
}
$presentMonProcess.Refresh()
if (-not $presentMonProcess.HasExited) {
    Stop-Process -Id $presentMonProcess.Id -Force -ErrorAction SilentlyContinue
    Stop-Process -Id $gpuProcess.Id -Force -ErrorAction SilentlyContinue
    throw 'PresentMon non ha terminato la cattura entro il timeout previsto.'
}
Start-Sleep -Milliseconds 250
Stop-Process -Id $gpuProcess.Id -Force -ErrorAction SilentlyContinue

$graphicsEvents = @()
try {
    $graphicsEvents = @(Get-WinEvent -FilterHashtable @{
        LogName = 'System'
        StartTime = $captureStart.ToLocalTime()
        ProviderName = @('Display', 'nvlddmkm', 'Microsoft-Windows-DxgKrnl')
    } -ErrorAction Stop | Select-Object TimeCreated, Id, ProviderName, LevelDisplayName, Message)
} catch { }
if ($graphicsEvents.Count -gt 0) {
    $graphicsEvents | Export-Csv -LiteralPath $graphicsEventsCsv -NoTypeInformation -Encoding UTF8
} else {
    [System.IO.File]::WriteAllText($graphicsEventsCsv, 'TimeCreated,Id,ProviderName,LevelDisplayName,Message' + [Environment]::NewLine)
}

$frameSummary = Get-FrameSummary -CsvPath $frameCsv
$gpuProcessSummary = Get-CsvMetricSummary -CsvPath $gpuProcessCsv -Metrics @('Dedicated Usage', 'Shared Usage', 'Utilization Percentage')
$nvidiaSummary = Get-NvidiaTelemetrySummary -CsvPath $gpuCsv
$systemMemorySummary = Get-SystemMemorySummary -CsvPath $systemMemoryCsv
$summary = [ordered]@{
    GpuProfile = $GpuProfile
    Scenario = $Scenario
    ConsoleProfile = $Console
    TuningProfile = $Profile
    TuningIntent = $selectedProfile.intent
    RuntimeOverrideNames = @($RuntimeOverride.Keys | Sort-Object)
    DurationSeconds = $DurationSeconds
    BuildLabel = $BuildLabel
    CacheState = $CacheState
    CacheDirectory = $cacheDir
    CacheWasEmptyAtStart = $cacheWasEmptyAtStart
    CacheSeedDirectory = $cacheSeedDir
    CacheSeedFingerprint = $cacheSeedFingerprint
    CacheEvidence = if ($CacheState -eq 'cold') {
        'The VIctory cache directory was empty before process launch. Manual scene preparation occurs before the timed sample and may warm it.'
    } elseif ($CacheState -eq 'warm') {
        'The VIctory cache directory was populated before process launch; its contents are preserved.'
    } else {
        'Cache state was not requested; this run cannot be compared as a cold or warm cache measurement.'
    }
    Resolution = [ordered]@{
        InternalLabel = $InternalResolutionLabel
        OutputLabel = $OutputResolutionLabel
        Evidence = 'Operator-supplied labels; the harness does not measure the internal render dimensions.'
    }
    SourceCommit = $sourceCommit
    SourceDirty = $sourceDirty
    CaptureStartUtc = $captureStart.ToString('o')
    RuntimeProcessId = $victoryProcess.Id
    FrameTargetProcessId = $frameTarget.Id
    AnonymousGameTarget = 'anonymous-game'
    FrameTargetKind = if ($frameTarget.Id -eq $victoryProcess.Id) { 'victory-host-process' } else { 'game-process' }
    RuntimeFileVersion = (Get-Item -LiteralPath $victoryPath).VersionInfo.FileVersion
    RuntimeExecutableSha256 = $runtimeExecutableSha256
    RuntimeExitCode = if ($victoryProcess.HasExited) { $victoryProcess.ExitCode } else { $null }
    PresentMonExitCode = $presentMonProcess.ExitCode
    FrameMetrics = $frameSummary
    NvidiaTelemetry = $nvidiaSummary
    GpuProcessCounters = $gpuProcessSummary
    SystemMemory = $systemMemorySummary
    AdapterLuid = $adapterLuid
    HardwareIdentity = [ordered]@{
        GPUName = $targetAdapter.Name
        DriverVersion = $hardwareReport.GPU.NvidiaSmi.DriverVersion
        CPUName = $hardwareReport.CPU.Name
        PhysicalCores = $hardwareReport.CPU.PhysicalCores
        LogicalProcessors = $hardwareReport.CPU.LogicalProcessors
        InstalledRAMGiB = $hardwareReport.RAM.InstalledGiB
        WindowsBuild = '{0} {1} {2}.{3}' -f $hardwareReport.OperatingSystem.ProductName, $hardwareReport.OperatingSystem.DisplayVersion, $hardwareReport.OperatingSystem.Build, $hardwareReport.OperatingSystem.UBR
    }
    RuntimeEnvironment = @($victoryEnvironment)
    GraphicsEventCount = $graphicsEvents.Count
    Files = [ordered]@{
        Frames = $frameCsv
        GpuTelemetry = $gpuCsv
        GpuProcessTelemetry = $gpuProcessCsv
        ProcessMemory = $processCsv
        SystemMemory = $systemMemoryCsv
        CpuThreads = $threadCsv
        GraphicsEvents = $graphicsEventsCsv
        RuntimeStdout = $victoryStdout
        RuntimeStderr = $victoryStderr
        PresentMonStderr = $presentMonStderr
        Hardware = $hardwarePath
        Environment = $environmentPath
    }
    Notes = @(
        'PresentMon classifies application/generated frames only when the target exposes frame-type instrumentation; check FrameTypeClassified.',
        'GPU memory/utilization is system-wide nvidia-smi telemetry in WDDM, not per-process VRAM usage.',
        'The runtime should log which DXGI adapter it selected; confirm that it is NVIDIA GeForce RTX 3070.',
        'Resolution labels are supplied by the operator; the harness does not verify internal render dimensions.'
    )
}
$summaryPath = Join-Path $runDirectory 'summary.json'
[System.IO.File]::WriteAllText($summaryPath, ($summary | ConvertTo-Json -Depth 8), (New-Object System.Text.UTF8Encoding($false)))
$summary | ConvertTo-Json -Depth 8
$captureSucceeded = $true
} finally {
    foreach ($process in @($presentMonProcess, $gpuProcess)) {
        if ($null -eq $process) { continue }
        try {
            $process.Refresh()
            if (-not $process.HasExited) { Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue }
        } catch { }
    }
    if (-not $captureSucceeded -and $null -ne $victoryProcess) {
        try {
            $victoryProcess.Refresh()
            if (-not $victoryProcess.HasExited) { Stop-Process -Id $victoryProcess.Id -Force -ErrorAction SilentlyContinue }
        } catch { }
    }
    Get-ChildItem Env: | Where-Object { $_.Name -like 'VICTORY_*' -and -not $previousVictoryEnvironment.ContainsKey($_.Name) } |
        ForEach-Object { Remove-Item "Env:$($_.Name)" -ErrorAction SilentlyContinue }
    foreach ($entry in $previousVictoryEnvironment.GetEnumerator()) { Set-Item "Env:$($entry.Key)" $entry.Value }
}
Write-Host "Benchmark completato: $runDirectory"
