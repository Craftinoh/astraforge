[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ComparisonPath,
    [string]$OutputPath = (Join-Path $PSScriptRoot '..\out\public-benchmark.json')
)

$ErrorActionPreference = 'Stop'
$comparisonFile = (Resolve-Path -LiteralPath $ComparisonPath).Path
$comparison = Get-Content -LiteralPath $comparisonFile -Raw | ConvertFrom-Json

function Assert-PublicCohort([object]$Cohort, [string]$Label) {
    if ([string]$Cohort.Scenario -notmatch '^scene-[A-Za-z0-9_-]+$') {
        throw "$Label has a non-anonymous scene alias; expected scene-01 style labels."
    }
    if ([string]$Cohort.AnonymousGameTarget -cne 'anonymous-game') {
        throw "$Label does not use the required anonymous target label."
    }
    if ([string]$Cohort.BuildLabel -notmatch '^[A-Za-z0-9._+-]{1,80}$') {
        throw "$Label BuildLabel must be a short path-free identifier."
    }
    if ([string]$Cohort.SourceCommit -notmatch '^[A-Fa-f0-9]{7,64}$' -or
        [string]$Cohort.ExecutableSha256 -notmatch '^[A-Fa-f0-9]{64}$') {
        throw "$Label lacks a valid source commit or executable SHA-256."
    }
}

Assert-PublicCohort $comparison.Baseline 'Baseline'
Assert-PublicCohort $comparison.Candidate 'Candidate'

function Convert-PublicCohort([object]$Cohort) {
    [ordered]@{
        BuildLabel = $Cohort.BuildLabel
        SourceCommit = $Cohort.SourceCommit
        ExecutableSha256 = $Cohort.ExecutableSha256
        GpuProfile = $Cohort.GpuProfile
        TuningProfile = $Cohort.TuningProfile
        RuntimeOverrideNames = @($Cohort.RuntimeOverrideNames)
        Scenario = $Cohort.Scenario
        AnonymousGameTarget = 'anonymous-game'
        CacheState = $Cohort.CacheState
        ConsoleProfile = $Cohort.ConsoleProfile
        Resolution = [ordered]@{
            InternalLabel = $Cohort.Resolution.InternalLabel
            OutputLabel = $Cohort.Resolution.OutputLabel
        }
        RunCount = $Cohort.RunCount
        FrameClassification = [ordered]@{
            FrameTypeClassified = $Cohort.FrameClassification.FrameTypeClassified
            CountRule = $Cohort.FrameClassification.CountRule
            ApplicationFramesPerRun = @($Cohort.FrameClassification.ApplicationFramesPerRun)
            GeneratedFramesPerRun = @($Cohort.FrameClassification.GeneratedFramesPerRun)
        }
    }
}

$hardware = [ordered]@{}
foreach ($name in @('GPUName', 'DriverVersion', 'CPUName', 'PhysicalCores', 'LogicalProcessors', 'InstalledRAMGiB', 'WindowsBuild')) {
    $property = $comparison.Hardware.PSObject.Properties[$name]
    if ($null -ne $property) { $hardware[$name] = $property.Value }
}

$targetRuns = foreach ($run in $comparison.TargetAssessment.Runs) {
    [ordered]@{
        MedianFps = $run.MedianFps
        OnePercentLowFps = $run.OnePercentLowFps
        FrametimeP99Ms = $run.FrametimeP99Ms
        Meets30FpsStabilityTarget = $run.Meets30FpsStabilityTarget
    }
}
$metrics = foreach ($metric in $comparison.Metrics) {
    [ordered]@{
        Metric = $metric.Metric
        Direction = $metric.Direction
        BaselineMedianAcrossRuns = $metric.BaselineMedianAcrossRuns
        CandidateMedianAcrossRuns = $metric.CandidateMedianAcrossRuns
        BaselineRunValues = @($metric.BaselineRunValues)
        CandidateRunValues = @($metric.CandidateRunValues)
        Delta = $metric.Delta
        DeltaPercent = $metric.DeltaPercent
    }
}

$publicReport = [ordered]@{
    SchemaVersion = 1
    ReportGeneratedUtc = (Get-Date).ToUniversalTime().ToString('o')
    Privacy = 'Anonymous scene aliases only; local file paths, executable names, cache paths, summary paths, raw logs, and save identifiers are omitted.'
    Baseline = Convert-PublicCohort $comparison.Baseline
    Candidate = Convert-PublicCohort $comparison.Candidate
    Hardware = $hardware
    ChangedRuntimeSettingNames = @($comparison.EnvironmentDifferences | ForEach-Object Name)
    Metrics = @($metrics)
    TargetAssessment = [ordered]@{
        TargetFps = $comparison.TargetAssessment.TargetFps
        StabilityDefinition = $comparison.TargetAssessment.StabilityDefinition
        PassingRuns = $comparison.TargetAssessment.PassingRuns
        CandidateRuns = $comparison.TargetAssessment.CandidateRuns
        Passed = $comparison.TargetAssessment.Passed
        Runs = @($targetRuns)
    }
    Caveat = $comparison.Caveat
}

$destination = [System.IO.Path]::GetFullPath($OutputPath)
$parent = Split-Path -Parent $destination
if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
$json = $publicReport | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($destination, $json, (New-Object System.Text.UTF8Encoding($false)))
$json
