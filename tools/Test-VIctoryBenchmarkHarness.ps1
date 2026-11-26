[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$comparator = Join-Path $PSScriptRoot 'Compare-VIctoryRuns.ps1'
$publicExporter = Join-Path $PSScriptRoot 'Export-VIctoryPublicReport.ps1'
Import-Module -Name (Join-Path $PSScriptRoot 'Victory-BenchmarkCommon.psm1') -Force
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("victory-benchmark-test-{0}" -f [guid]::NewGuid().ToString('N'))
$tempRootFull = [System.IO.Path]::GetFullPath($tempRoot)
$tempBaseFull = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\') + '\'
if (-not $tempRootFull.StartsWith($tempBaseFull, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to use test path outside the temporary directory: $tempRootFull"
}

function New-SyntheticRun([string]$Cohort, [int]$Index, [string]$CacheState, [bool]$Candidate) {
    $directory = Join-Path $tempRootFull "$Cohort-$Index"
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    $workingCache = Join-Path $tempRootFull "$Cohort-cache-$Index"
    $profilePercent = if ($Candidate) { '85' } else { '90' }
    $frameMetrics = if ($Candidate) {
        [ordered]@{
            PresentRows = 36000; ApplicationFrames = 36000; GeneratedFrames = 0; FrameTypeClassified = $true
            CountRule = 'FrameType=Application'; IntervalColumn = 'MsBetweenPresents'
            AverageFps = 30.4; MedianFps = 30.5; OnePercentLowFps = 30.0; ZeroPointOnePercentLowFps = 28.5
            FrametimeMeanMs = 32.9; FrametimeMedianMs = 32.8; FrametimeP95Ms = 33.1; FrametimeP99Ms = 33.333; FrametimeP999Ms = 35.0
            SimulationStartIntervalMeanMs = 33.0
        }
    } else {
        [ordered]@{
            PresentRows = 24000; ApplicationFrames = 24000; GeneratedFrames = 0; FrameTypeClassified = $true
            CountRule = 'FrameType=Application'; IntervalColumn = 'MsBetweenPresents'
            AverageFps = 20.8; MedianFps = 21.0; OnePercentLowFps = 17.5; ZeroPointOnePercentLowFps = 15.0
            FrametimeMeanMs = 48.0; FrametimeMedianMs = 47.6; FrametimeP95Ms = 54.0; FrametimeP99Ms = 57.143; FrametimeP999Ms = 66.667
            SimulationStartIntervalMeanMs = 48.2
        }
    }
    $cacheFingerprint = if ($Candidate) { 'B' * 64 } else { 'A' * 64 }
    $seedDirectory = if ($CacheState -eq 'warm') { Join-Path $tempRootFull "$Cohort-seed" } else { $null }
    [ordered]@{
        Scenario = 'scene-synthetic'
        GpuProfile = 'nvidia-rtx3070'
        ConsoleProfile = 'series-s'
        TuningProfile = 'Balanced'
        TuningIntent = 'synthetic test only'
        RuntimeOverrideNames = @()
        DurationSeconds = 600
        BuildLabel = if ($Candidate) { 'candidate' } else { 'baseline' }
        CacheState = $CacheState
        CacheDirectory = $workingCache
        CacheWasEmptyAtStart = ($CacheState -eq 'cold')
        CacheSeedDirectory = $seedDirectory
        CacheSeedFingerprint = if ($CacheState -eq 'warm') { [ordered]@{ Files = 100; Bytes = 1048576; Sha256 = $cacheFingerprint } } else { $null }
        Resolution = [ordered]@{ InternalLabel = '1280x720'; OutputLabel = '1920x1080'; Evidence = 'synthetic' }
        SourceCommit = '0123456789abcdef0123456789abcdef01234567'
        SourceDirty = $false
        AnonymousGameTarget = 'anonymous-game'
        FrameTargetKind = 'game-process'
        RuntimeExecutableSha256 = if ($Candidate) { 'B' * 64 } else { 'A' * 64 }
        FrameMetrics = $frameMetrics
        AdapterLuid = '0x00000000_0x0000E63D'
        HardwareIdentity = [ordered]@{
            GPUName = 'NVIDIA GeForce RTX 3070'; DriverVersion = '610.88'; CPUName = 'AMD Ryzen 7 7700X'
            PhysicalCores = 8; LogicalProcessors = 16; InstalledRAMGiB = 32; WindowsBuild = 'Windows 11 Pro 26H2 26300.10075'
        }
        RuntimeEnvironment = @(
            [ordered]@{ Name = 'VICTORY_CACHE_DIR'; Value = $workingCache },
            [ordered]@{ Name = 'VICTORY_DATA_DIR'; Value = 'C:\Synthetic\data' },
            [ordered]@{ Name = 'VICTORY_TEXTURE_ROOM_PERCENT'; Value = $profilePercent }
        )
    }
}

function New-Cohort([string]$Name, [string]$CacheState, [bool]$Candidate) {
    $paths = @()
    for ($index = 1; $index -le 3; $index++) {
        $summary = New-SyntheticRun -Cohort $Name -Index $index -CacheState $CacheState -Candidate $Candidate
        $summaryPath = Join-Path (Join-Path $tempRootFull "$Name-$index") 'summary.json'
        [System.IO.File]::WriteAllText($summaryPath, ($summary | ConvertTo-Json -Depth 10), (New-Object System.Text.UTF8Encoding($false)))
        $paths += $summaryPath
    }
    return ,$paths
}

function Invoke-SyntheticComparison([string[]]$Baseline, [string[]]$Candidate) {
    return (& $comparator -BaselineSummary $Baseline -CandidateSummary $Candidate `
        -AllowedEnvironmentDifference 'VICTORY_TEXTURE_ROOM_PERCENT' -MinimumRuns 3 | ConvertFrom-Json)
}

function Assert-Rejected([string[]]$Baseline, [string[]]$Candidate, [string]$Label) {
    $rejected = $false
    try { $null = Invoke-SyntheticComparison -Baseline $Baseline -Candidate $Candidate }
    catch { $rejected = $true }
    if (-not $rejected) { throw "Comparator did not reject invalid synthetic case: $Label" }
    Write-Host "PASS rejects $Label"
}

try {
    New-Item -ItemType Directory -Force -Path $tempRootFull | Out-Null
    $seedSource = Join-Path $tempRootFull 'cache-fingerprint-seed'
    $seedCopy = Join-Path $tempRootFull 'cache-fingerprint-copy'
    New-Item -ItemType Directory -Force -Path (Join-Path $seedSource 'nested') | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $seedSource 'nested\pipeline.bin'), 'synthetic pipeline cache')
    $cacheCopy = Copy-VictoryCacheSeed -SourceDirectory $seedSource -DestinationDirectory $seedCopy
    if ($cacheCopy.Fingerprint.Files -ne 1 -or
        (Get-VictoryDirectoryFingerprint -Directory $seedCopy).Sha256 -cne $cacheCopy.Fingerprint.Sha256) {
        throw 'Synthetic cache clone did not preserve its content fingerprint.'
    }
    [System.IO.File]::AppendAllText((Join-Path $seedCopy 'nested\pipeline.bin'), 'changed')
    if ((Get-VictoryDirectoryFingerprint -Directory $seedCopy).Sha256 -ceq $cacheCopy.Fingerprint.Sha256) {
        throw 'Synthetic cache mutation was not detected by the fingerprint.'
    }
    Write-Host 'PASS clones a warm cache without mutating the seed and detects content changes'
    foreach ($cacheState in @('warm', 'cold')) {
        $baseline = New-Cohort -Name "baseline-$cacheState" -CacheState $cacheState -Candidate $false
        $candidate = New-Cohort -Name "candidate-$cacheState" -CacheState $cacheState -Candidate $true
        $comparison = Invoke-SyntheticComparison -Baseline $baseline -Candidate $candidate
        if ($comparison.Baseline.RunCount -ne 3 -or $comparison.Candidate.RunCount -ne 3) {
            throw "Incorrect synthetic run count for $cacheState comparison."
        }
        if (-not $comparison.TargetAssessment.Passed) {
            throw "The synthetic candidate should pass the 30 FPS stability rule for $cacheState."
        }
        if ($comparison.TargetAssessment.PassingRuns -ne 3) {
            throw "Expected all synthetic candidate runs to pass for $cacheState."
        }
        Write-Host "PASS compares three $cacheState runs and reports 30 FPS target"
        if ($cacheState -eq 'warm') {
            $comparisonPath = Join-Path $tempRootFull 'synthetic-comparison.json'
            $publicPath = Join-Path $tempRootFull 'synthetic-public.json'
            $null = & $comparator -BaselineSummary $baseline -CandidateSummary $candidate `
                -AllowedEnvironmentDifference 'VICTORY_TEXTURE_ROOM_PERCENT' -MinimumRuns 3 -OutputPath $comparisonPath
            $null = & $publicExporter -ComparisonPath $comparisonPath -OutputPath $publicPath
            $publicJson = Get-Content -LiteralPath $publicPath -Raw
            $publicReport = $publicJson | ConvertFrom-Json
            if ($publicReport.Baseline.Scenario -ne 'scene-synthetic' -or
                $publicReport.TargetAssessment.Passed -ne $true -or
                $publicJson.Contains($tempRootFull) -or
                $publicJson.Contains('Synthetic\data') -or
                $publicJson.Contains('SummaryPaths') -or
                $publicJson.Contains('CacheDirectories')) {
                throw 'Public export failed anonymous-scene validation or retained local paths.'
            }
            Write-Host 'PASS exports anonymous benchmark metrics without local file paths or cache paths'
        }
        if ($cacheState -eq 'warm') {
            $bad = Get-Content -LiteralPath $candidate[2] -Raw | ConvertFrom-Json
            $bad.CacheSeedFingerprint.Sha256 = 'C' * 64
            [System.IO.File]::WriteAllText($candidate[2], ($bad | ConvertTo-Json -Depth 10), (New-Object System.Text.UTF8Encoding($false)))
            Assert-Rejected -Baseline $baseline -Candidate $candidate -Label 'warm seed fingerprint mismatch within cohort'
            $bad.CacheSeedFingerprint.Sha256 = 'B' * 64
            $bad.FrameMetrics.FrameTypeClassified = $false
            [System.IO.File]::WriteAllText($candidate[2], ($bad | ConvertTo-Json -Depth 10), (New-Object System.Text.UTF8Encoding($false)))
            Assert-Rejected -Baseline $baseline -Candidate $candidate -Label 'unclassified application/generated frame type'
        }
    }
} finally {
    if (Test-Path -LiteralPath $tempRootFull) {
        $resolved = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $tempRootFull).Path)
        if (-not $resolved.StartsWith($tempBaseFull, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to clean test path outside the temporary directory: $resolved"
        }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
