[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Task,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]]$InputPath,

    [string]$BaseUrl = $env:ASTRAFORGE_MODEL_BASE_URL,
    [string]$Model = $env:ASTRAFORGE_MODEL_ID,
    [string]$ApiKeyEnvironmentVariable = 'ASTRAFORGE_MODEL_API_KEY',

    [ValidateRange(128, 32768)]
    [int]$MaxTokens = 4096,

    [ValidateRange(65536, 972800)]
    [int]$RequestByteLimit = 460800,

    [ValidateRange(0, 5)]
    [int]$MaxRetries = 3,

    [string]$OutputPath,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
    throw 'Set ASTRAFORGE_MODEL_BASE_URL or pass -BaseUrl.'
}
if ([string]::IsNullOrWhiteSpace($Model)) {
    throw 'Set ASTRAFORGE_MODEL_ID or pass -Model.'
}

$allowedExtensions = @(
    '.c', '.cc', '.cpp', '.h', '.hpp', '.json', '.jsonc', '.md', '.ps1',
    '.psm1', '.rs', '.toml', '.txt', '.wgsl', '.yml', '.yaml'
)
$blockedSegments = @(
    '\.git\', '\out\', '\target\', '\gamefiles\', '\saves\',
    '\cache\', '\.env', '\credentials', '\secrets'
)
$resolvedInputs = [System.Collections.Generic.List[System.IO.FileInfo]]::new()

foreach ($item in $InputPath) {
    $resolved = Get-Item -LiteralPath $item -ErrorAction Stop
    if ($resolved.PSIsContainer) {
        throw "Input must be an explicit file, not a directory: $item"
    }

    $fullName = $resolved.FullName.ToLowerInvariant()
    foreach ($segment in $blockedSegments) {
        if ($fullName.Contains($segment)) {
            throw "Refusing private, generated, or credential-like input: $($resolved.FullName)"
        }
    }

    if ($allowedExtensions -notcontains $resolved.Extension.ToLowerInvariant()) {
        throw "Unsupported model-review input type: $($resolved.FullName)"
    }
    if ($resolved.Length -gt 512KB) {
        throw "Input exceeds the 512 KiB per-file limit: $($resolved.FullName)"
    }
    $resolvedInputs.Add($resolved)
}

$sections = [System.Collections.Generic.List[string]]::new()
foreach ($inputFile in $resolvedInputs) {
    $content = Get-Content -LiteralPath $inputFile.FullName -Raw
    $sections.Add("FILE: $($inputFile.Name)`nBEGIN_FILE`n$content`nEND_FILE")
}

$systemMessage = @'
You are a read-only senior reviewer for AstraForge, an open-source Windows D3D12
compatibility layer. Inspect only the supplied text. Do not invent code, flags,
measurements, line numbers, or runtime results. Focus on concrete Rust/D3D12/DXIL,
NVIDIA Ampere, descriptor lifetime, synchronization, residency, and memory risks.
Every finding must cite a supplied filename and an exact symbol or quoted code fragment.
Classify each finding as confirmed, plausible, or rejected. Explain the call path and
the smallest reversible correction. Model output is a proposal and never evidence of
correctness or performance. Do not request or reproduce credentials, private paths,
game identifiers, saves, binaries, captures, or personal data.
'@

$userMessage = @"
TASK
$Task

REVIEW CONTRACT
- Return findings in descending severity.
- Separate correctness, stability, performance, and missing-evidence findings.
- State when supplied context is insufficient.
- Do not claim FPS gains.
- Do not propose deleting required draws, barriers, synchronization, or resource work.

INPUTS
$($sections -join "`n`n")
"@

$request = @{
    model = $Model
    messages = @(
        @{ role = 'system'; content = $systemMessage }
        @{ role = 'user'; content = $userMessage }
    )
    max_tokens = $MaxTokens
    stream = $false
}
$body = $request | ConvertTo-Json -Depth 8 -Compress
$bodyBytes = [Text.Encoding]::UTF8.GetByteCount($body)
if ($bodyBytes -gt $RequestByteLimit) {
    throw "Request body is $bodyBytes bytes and exceeds the $RequestByteLimit-byte context safety ceiling. Reduce -InputPath."
}

if ($DryRun) {
    [pscustomobject]@{
        Model = $Model
        BaseUrl = $BaseUrl.TrimEnd('/')
        InputFiles = @($resolvedInputs.FullName)
        RequestBytes = $bodyBytes
        MaxTokens = $MaxTokens
    }
    return
}

$apiKey = [Environment]::GetEnvironmentVariable($ApiKeyEnvironmentVariable, 'Process')
if ([string]::IsNullOrWhiteSpace($apiKey)) {
    $apiKey = [Environment]::GetEnvironmentVariable($ApiKeyEnvironmentVariable, 'User')
}
if ([string]::IsNullOrWhiteSpace($apiKey)) {
    throw "API key environment variable is unavailable: $ApiKeyEnvironmentVariable"
}

$headers = @{
    Authorization = "Bearer $apiKey"
    'Content-Type' = 'application/json'
}
$endpoint = "$($BaseUrl.TrimEnd('/'))/chat/completions"
$response = $null

for ($attempt = 0; $attempt -le $MaxRetries; $attempt++) {
    try {
        $response = Invoke-RestMethod -Uri $endpoint -Method Post -Headers $headers -Body $body -TimeoutSec 900
        break
    }
    catch {
        $statusCode = $null
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
        }
        if (($statusCode -notin @(429, 500, 502, 503)) -or $attempt -eq $MaxRetries) {
            $providerDetail = $null
            if ($_.Exception.Response) {
                try {
                    $stream = $_.Exception.Response.GetResponseStream()
                    $reader = [IO.StreamReader]::new($stream)
                    $providerDetail = $reader.ReadToEnd()
                    $reader.Dispose()
                }
                catch {
                    $providerDetail = $null
                }
            }
            if ([string]::IsNullOrWhiteSpace($providerDetail)) {
                throw "Model request failed with HTTP $statusCode."
            }
            throw "Model request failed with HTTP $statusCode. Provider response: $providerDetail"
        }
        Start-Sleep -Seconds ([Math]::Min(30, [Math]::Pow(2, $attempt + 1)))
    }
}

if (-not $response -or -not $response.choices -or -not $response.choices[0].message.content) {
    throw 'The model response did not contain choices[0].message.content.'
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $reviewRoot = Join-Path $env:LOCALAPPDATA 'AstraForge\model-reviews'
    New-Item -ItemType Directory -Force -Path $reviewRoot | Out-Null
    $safeModel = $Model -replace '[^A-Za-z0-9._-]', '_'
    $OutputPath = Join-Path $reviewRoot "$(Get-Date -Format 'yyyyMMdd-HHmmss')-$safeModel.md"
}
else {
    $parent = Split-Path -Parent $OutputPath
    if ($parent) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
}

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).TrimEnd('\')
$outputFullPath = [IO.Path]::GetFullPath($OutputPath)
if ($outputFullPath.StartsWith("$repoRoot\", [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Model-review output must stay outside the repository.'
}
$OutputPath = $outputFullPath

$review = @"
# AstraForge model review

- Model: $Model
- Request ID: $($response.id)
- Created locally: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss K')
- Input files: $($resolvedInputs.Count)
- Request bytes: $bodyBytes

Model output is untrusted review input. Confirm every finding against source and tests.

$($response.choices[0].message.content)
"@

Set-Content -LiteralPath $OutputPath -Value $review -Encoding UTF8

[pscustomobject]@{
    Model = $Model
    RequestId = $response.id
    OutputPath = (Resolve-Path -LiteralPath $OutputPath).Path
    InputFiles = $resolvedInputs.Count
    RequestBytes = $bodyBytes
}

$apiKey = $null
$headers = $null
