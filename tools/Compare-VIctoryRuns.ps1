[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string[]]$BaselineSummary,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string[]]$CandidateSummary,
    [string[]]$AllowedEnvironmentDifference = @(),
    [ValidateRange(1, 100)][int]$MinimumRuns = 3,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

function Read-Run([string]$Path) {
    $resolved = (Resolve-Path -LiteralPath $Path).Path
    $data = Get-Content -LiteralPath $resolved -Raw | ConvertFrom-Json
    [pscustomobject]@{ Path = $resolved; Data = $data }
}

function Get-PropertyPath([object]$Object, [string]$Path) {
    $value = $Object
    foreach ($segment in $Path.Split('.')) {
        if ($null -eq $value) { return $null }
        $property = $value.PSObject.Properties[$segment]
        if ($null -eq $property) { return $null }
        $value = $property.Value
    }
    return $value
}

function Get-EnvironmentMap([object]$Run) {
    $entries = $Run.Data.PSObject.Properties['RuntimeEnvironment']
    if ($null -eq $entries) {
        throw "Run '$($Run.Path)' lacks the recorded RuntimeEnvironment; capture it again with the updated benchmark script."
    }
    $map = @{}
    foreach ($entry in @($entries.Value)) {
        if ($null -eq $entry -or [string]::IsNullOrWhiteSpace([string]$entry.Name)) { continue }
        $map[[string]$entry.Name] = [string]$entry.Value
    }
    return ,$map
}

function Get-ComparableEnvironmentMap([object]$Run) {
    $map = Get-EnvironmentMap $Run
    # Every measured run receives an isolated working cache. Its contents and
    # seed are validated separately, so the per-run path is not a setting delta.
    if ([string]$Run.Data.CacheState -in @('cold', 'warm')) { $map.Remove('VICTORY_CACHE_DIR') }
    return ,$map
}

function Normalize-Directory([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    return [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
}

function Assert-CacheMetadata([object[]]$Runs) {
    $workingDirectories = @{}
    foreach ($run in $Runs) {
        $state = [string]$run.Data.CacheState
        $directoryProperty = $run.Data.PSObject.Properties['CacheDirectory']
        $emptyProperty = $run.Data.PSObject.Properties['CacheWasEmptyAtStart']
        if ($null -eq $directoryProperty -or $null -eq $emptyProperty) {
            throw "Run '$($run.Path)' lacks cache-directory evidence; capture it again with the updated benchmark script."
        }
        $directory = Normalize-Directory ([string]$directoryProperty.Value)
        if (-not $directory) { throw "Run '$($run.Path)' has an empty CacheDirectory." }
        $environment = Get-EnvironmentMap $run
        if (-not $environment.ContainsKey('VICTORY_CACHE_DIR') -or
            -not [string]::Equals((Normalize-Directory $environment['VICTORY_CACHE_DIR']), $directory, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Run '$($run.Path)' CacheDirectory does not match its VICTORY_CACHE_DIR runtime setting."
        }
        $workingKey = $directory.ToUpperInvariant()
        if ($workingDirectories.ContainsKey($workingKey)) {
            throw "Every measured run must use its own working cache directory; '$directory' was reused."
        }
        $workingDirectories[$workingKey] = $true
        if ($state -eq 'cold') {
            if ($emptyProperty.Value -ne $true) {
                throw "Cold run '$($run.Path)' did not record an empty cache at launch."
            }
            if ($null -ne $run.Data.CacheSeedFingerprint -or -not [string]::IsNullOrWhiteSpace([string]$run.Data.CacheSeedDirectory)) {
                throw "Cold run '$($run.Path)' unexpectedly records a warm-cache seed."
            }
        } elseif ($state -eq 'warm') {
            if ($emptyProperty.Value -ne $false) {
                throw "Warm run '$($run.Path)' did not record a populated cache at launch."
            }
            if ([string]::IsNullOrWhiteSpace([string]$run.Data.CacheSeedDirectory) -or
                $null -eq $run.Data.CacheSeedFingerprint -or
                [string]$run.Data.CacheSeedFingerprint.Sha256 -notmatch '^[A-Fa-f0-9]{64}$' -or
                [int]$run.Data.CacheSeedFingerprint.Files -lt 1) {
                throw "Warm run '$($run.Path)' lacks a valid seed path and SHA-256 fingerprint."
            }
        } else {
            throw "Run '$($run.Path)' needs CacheState cold or warm."
        }
    }
}

function Get-EnvironmentDifferences([hashtable]$Left, [hashtable]$Right) {
    $allNames = @{}
    foreach ($name in $Left.Keys) { $allNames[[string]$name] = $true }
    foreach ($name in $Right.Keys) { $allNames[[string]$name] = $true }
    foreach ($name in ($allNames.Keys | Sort-Object)) {
        $leftHas = $Left.ContainsKey($name)
        $rightHas = $Right.ContainsKey($name)
        $leftValue = if ($leftHas) { [string]$Left[$name] } else { $null }
        $rightValue = if ($rightHas) { [string]$Right[$name] } else { $null }
        if (-not $leftHas -or -not $rightHas -or $leftValue -cne $rightValue) {
            [pscustomobject]@{
                Name = $name
                BaselineValue = $leftValue
                CandidateValue = $rightValue
                BaselinePresent = $leftHas
                CandidatePresent = $rightHas
            }
        }
    }
}

function Get-Median([double[]]$Values) {
    if (-not $Values -or $Values.Count -eq 0) { return $null }
    [double[]]$sorted = $Values
    [Array]::Sort($sorted)
    $middle = [int][Math]::Floor($sorted.Count / 2)
    if ($sorted.Count % 2) { return $sorted[$middle] }
    return ($sorted[$middle - 1] + $sorted[$middle]) / 2.0
}

function Get-RunMetrics([object[]]$Runs, [string]$Property) {
    $values = @()
    foreach ($run in $Runs) {
        $value = Get-PropertyPath $run.Data "FrameMetrics.$Property"
        if ($null -eq $value) { throw "Run '$($run.Path)' has no FrameMetrics.$Property value." }
        $values += [double]$value
    }
    return ,([double[]]$values)
}

function Assert-RunCohort([object[]]$Runs) {
    $firstRun = $Runs[0]
    $first = $firstRun.Data
    if ([string]::IsNullOrWhiteSpace([string]$first.BuildLabel) -or [string]$first.BuildLabel -eq 'unspecified') {
        throw "Run '$($firstRun.Path)' needs a concrete BuildLabel."
    }
    if ([string]::IsNullOrWhiteSpace([string]$first.TuningProfile)) {
        throw "Run '$($firstRun.Path)' lacks its RTX 3070 tuning profile."
    }
    if ([string]::IsNullOrWhiteSpace([string]$first.SourceCommit) -or $first.SourceDirty -ne $false) {
        throw "Run '$($firstRun.Path)' must record a clean source commit. Pass -SourceRoot when capturing."
    }
    if ([string]$first.RuntimeExecutableSha256 -notmatch '^[A-Fa-f0-9]{64}$') {
        throw "Run '$($firstRun.Path)' lacks a valid VIctory executable SHA-256. Capture it again with the updated benchmark script."
    }
    $referenceEnvironment = Get-ComparableEnvironmentMap $firstRun
    $referenceOverrides = @($first.RuntimeOverrideNames | Sort-Object) -join '|'
    $referenceCacheFingerprint = if ([string]$first.CacheState -eq 'warm') { [string]$first.CacheSeedFingerprint.Sha256 } else { $null }
    foreach ($run in $Runs | Select-Object -Skip 1) {
        if ([string]$run.Data.BuildLabel -cne [string]$first.BuildLabel -or
            [string]$run.Data.SourceCommit -cne [string]$first.SourceCommit -or
            [string]$run.Data.GpuProfile -cne [string]$first.GpuProfile -or
            [string]$run.Data.TuningProfile -cne [string]$first.TuningProfile -or
            [string]$run.Data.RuntimeExecutableSha256 -cne [string]$first.RuntimeExecutableSha256 -or
            ((@($run.Data.RuntimeOverrideNames | Sort-Object) -join '|') -cne $referenceOverrides) -or
            $run.Data.SourceDirty -ne $false) {
            throw "Runs in one cohort must use the same build label, source commit, GPU/tuning profile, executable hash, and clean tree; mismatch in '$($run.Path)'."
        }
        if ([string]$first.CacheState -eq 'warm' -and
            [string]$run.Data.CacheSeedFingerprint.Sha256 -cne $referenceCacheFingerprint) {
            throw "Warm runs in one cohort must be cloned from the same immutable cache seed; mismatch in '$($run.Path)'."
        }
        $differences = @(Get-EnvironmentDifferences $referenceEnvironment (Get-ComparableEnvironmentMap $run))
        if ($differences.Count -gt 0) {
            throw "Runtime environment differs between repeated runs in the same cohort; mismatch in '$($run.Path)'."
        }
    }
}

$baselineRuns = @($BaselineSummary | ForEach-Object { Read-Run $_ })
$candidateRuns = @($CandidateSummary | ForEach-Object { Read-Run $_ })
$allRuns = @($baselineRuns) + @($candidateRuns)
if ($baselineRuns.Count -lt 1 -or $candidateRuns.Count -lt 1) { throw 'Each cohort needs at least one summary.' }
if ($baselineRuns.Count -lt $MinimumRuns -or $candidateRuns.Count -lt $MinimumRuns) {
    throw "Each cohort needs at least $MinimumRuns completed runs; got baseline=$($baselineRuns.Count), candidate=$($candidateRuns.Count)."
}

$matchFields = @(
    'Scenario', 'ConsoleProfile', 'DurationSeconds', 'CacheState',
    'Resolution.InternalLabel', 'Resolution.OutputLabel',
    'GpuProfile', 'AnonymousGameTarget', 'FrameTargetKind', 'AdapterLuid',
    'HardwareIdentity.GPUName', 'HardwareIdentity.DriverVersion',
    'HardwareIdentity.CPUName', 'HardwareIdentity.PhysicalCores',
    'HardwareIdentity.LogicalProcessors', 'HardwareIdentity.InstalledRAMGiB',
    'HardwareIdentity.WindowsBuild', 'FrameMetrics.FrameTypeClassified',
    'FrameMetrics.CountRule'
)
foreach ($field in $matchFields) {
    $reference = Get-PropertyPath $baselineRuns[0].Data $field
    if ($null -eq $reference -or [string]::IsNullOrWhiteSpace([string]$reference)) {
        throw "Baseline run '$($baselineRuns[0].Path)' lacks required comparison field '$field'."
    }
    foreach ($run in $allRuns) {
        $value = Get-PropertyPath $run.Data $field
        if ($null -eq $value -or [string]$value -cne [string]$reference) {
            throw "Cannot compare runs: '$field' differs or is missing in '$($run.Path)'."
        }
    }
}

$firstData = $baselineRuns[0].Data
if ([string]$firstData.CacheState -eq 'unspecified') { throw 'Set CacheState to cold or warm for every run before comparing.' }
if ([string]$firstData.Resolution.InternalLabel -notmatch '^\d{3,5}x\d{3,5}$' -or
    [string]$firstData.Resolution.OutputLabel -notmatch '^\d{3,5}x\d{3,5}$') {
    throw 'Supply measured internal and output dimensions as WIDTHxHEIGHT for every capture; the harness cannot infer internal render dimensions.'
}
if ($firstData.FrameMetrics.FrameTypeClassified -ne $true) {
    throw 'PresentMon did not classify application frames; real application FPS cannot be separated from generated or duplicated presents.'
}

Assert-RunCohort -Runs $baselineRuns
Assert-RunCohort -Runs $candidateRuns
Assert-CacheMetadata -Runs $allRuns

$baselineEnvironment = Get-ComparableEnvironmentMap $baselineRuns[0]
$candidateEnvironment = Get-ComparableEnvironmentMap $candidateRuns[0]
$environmentDifferences = @(Get-EnvironmentDifferences $baselineEnvironment $candidateEnvironment)
$allowed = @{}
foreach ($name in $AllowedEnvironmentDifference) { $allowed[[string]$name] = $true }
$unexpectedEnvironmentDifferences = @($environmentDifferences | Where-Object { -not $allowed.ContainsKey($_.Name) })
if ($unexpectedEnvironmentDifferences.Count -gt 0) {
    $names = ($unexpectedEnvironmentDifferences.Name | Sort-Object -Unique) -join ', '
    throw "Unexpected runtime environment differences ($names). Pass only the intended A/B variable names through -AllowedEnvironmentDifference."
}

$metrics = @(
    @('Average FPS', 'AverageFps', 'higher'),
    @('Median FPS', 'MedianFps', 'higher'),
    @('1% low FPS', 'OnePercentLowFps', 'higher'),
    @('0.1% low FPS', 'ZeroPointOnePercentLowFps', 'higher'),
    @('Mean frametime ms', 'FrametimeMeanMs', 'lower'),
    @('p95 frametime ms', 'FrametimeP95Ms', 'lower'),
    @('p99 frametime ms', 'FrametimeP99Ms', 'lower'),
    @('p99.9 frametime ms', 'FrametimeP999Ms', 'lower')
)
$rows = foreach ($metric in $metrics) {
    $baselineValues = Get-RunMetrics $baselineRuns ([string]$metric[1])
    $candidateValues = Get-RunMetrics $candidateRuns ([string]$metric[1])
    $base = Get-Median $baselineValues
    $next = Get-Median $candidateValues
    $delta = $next - $base
    $percent = if ($base -ne 0) { 100.0 * $delta / $base } else { $null }
    [pscustomobject]@{
        Metric = $metric[0]
        Direction = $metric[2]
        BaselineMedianAcrossRuns = [Math]::Round($base, 3)
        CandidateMedianAcrossRuns = [Math]::Round($next, 3)
        BaselineRunValues = $baselineValues
        CandidateRunValues = $candidateValues
        Delta = [Math]::Round($delta, 3)
        DeltaPercent = if ($null -ne $percent) { [Math]::Round($percent, 2) } else { $null }
    }
}

$targetFps = 30.0
$targetP99FrametimeMs = 1000.0 / $targetFps
$targetRunResults = foreach ($run in $candidateRuns) {
    $medianFps = [double]$run.Data.FrameMetrics.MedianFps
    $onePercentLowFps = [double]$run.Data.FrameMetrics.OnePercentLowFps
    $p99FrametimeMs = [double]$run.Data.FrameMetrics.FrametimeP99Ms
    [pscustomobject]@{
        Summary = $run.Path
        MedianFps = $medianFps
        OnePercentLowFps = $onePercentLowFps
        FrametimeP99Ms = $p99FrametimeMs
        Meets30FpsStabilityTarget = ($medianFps -ge $targetFps -and
            $onePercentLowFps -ge $targetFps -and $p99FrametimeMs -le $targetP99FrametimeMs)
    }
}
$targetPassCount = @($targetRunResults | Where-Object Meets30FpsStabilityTarget).Count

function Convert-CohortSummary([object[]]$Runs) {
    $data = $Runs[0].Data
    [ordered]@{
        BuildLabel = $data.BuildLabel
        SourceCommit = $data.SourceCommit
        GpuProfile = $data.GpuProfile
        TuningProfile = $data.TuningProfile
        RuntimeOverrideNames = @($data.RuntimeOverrideNames)
        ExecutableSha256 = $data.RuntimeExecutableSha256
        Scenario = $data.Scenario
        AnonymousGameTarget = $data.AnonymousGameTarget
        CacheState = $data.CacheState
        CacheDirectories = @($Runs | ForEach-Object { $_.Data.CacheDirectory })
        CacheWasEmptyAtStart = @($Runs | ForEach-Object { $_.Data.CacheWasEmptyAtStart })
        CacheSeedFingerprints = @($Runs | ForEach-Object { $_.Data.CacheSeedFingerprint.Sha256 })
        ConsoleProfile = $data.ConsoleProfile
        Resolution = $data.Resolution
        RunCount = $Runs.Count
        FrameClassification = [ordered]@{
            ApplicationFramesPerRun = @($Runs | ForEach-Object { $_.Data.FrameMetrics.ApplicationFrames })
            GeneratedFramesPerRun = @($Runs | ForEach-Object { $_.Data.FrameMetrics.GeneratedFrames })
            FrameTypeClassified = $data.FrameMetrics.FrameTypeClassified
            CountRule = $data.FrameMetrics.CountRule
        }
        SummaryPaths = @($Runs | ForEach-Object { $_.Path })
    }
}

$comparison = [ordered]@{
    ComparedAt = (Get-Date).ToString('o')
    Baseline = Convert-CohortSummary $baselineRuns
    Candidate = Convert-CohortSummary $candidateRuns
    Hardware = $firstData.HardwareIdentity
    EnvironmentDifferences = $environmentDifferences
    AllowedEnvironmentDifference = @($AllowedEnvironmentDifference)
    Metrics = @($rows)
    TargetAssessment = [ordered]@{
        TargetFps = $targetFps
        StabilityDefinition = 'Every candidate run must have real application median FPS >= 30 and 1% low FPS >= 30 (p99 frametime <= 33.333 ms).'
        PassingRuns = $targetPassCount
        CandidateRuns = $candidateRuns.Count
        Passed = ($targetPassCount -eq $candidateRuns.Count)
        Runs = @($targetRunResults)
    }
    Caveat = 'Each metric is the median of per-run summaries. Cold captures require distinct directories that were empty at launch; scene setup occurs before timing and may warm the cache. Warm captures require a populated cache. Compare matched scene, duration, cache state, resolution, console profile, adapter, driver, and runtime settings.'
}

$json = $comparison | ConvertTo-Json -Depth 10
if ($OutputPath) {
    $destination = [System.IO.Path]::GetFullPath($OutputPath)
    $parent = Split-Path -Parent $destination
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    [System.IO.File]::WriteAllText($destination, $json, (New-Object System.Text.UTF8Encoding($false)))
}
$json
