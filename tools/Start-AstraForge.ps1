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
    [string]$CacheDir,
    [string]$DataDir,
    [string]$PresentMonExe,
    [hashtable]$RuntimeOverride = @{},
    [ValidateRange(12, 256)][int]$MinimumAvailableCommitGiB = 12,
    [switch]$DebugConsole,
    [switch]$PreRunWindow,
    [switch]$AllowSeriesX
)

$ErrorActionPreference = 'Stop'
Import-Module -Name (Join-Path $PSScriptRoot 'AstraForge-Preflight.psm1') -Force
if ($PreRunWindow) {
    Import-Module -Name (Join-Path $PSScriptRoot 'AstraForge-PreRunWindow.psm1') -Force
    $preRunConsole = if ([string]::IsNullOrWhiteSpace($Console)) { 'profilo predefinito' } else { $Console }
    New-AstraForgePreRunWindow -GpuProfile $GpuProfile -Profile $Profile -Console $preRunConsole
    trap {
        $preRunError = $_
        try { Show-AstraForgePreRunFailure -Message $preRunError.Exception.Message } catch { }
        throw $preRunError
    }
}

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
if ($PreRunWindow) {
    Set-AstraForgePreRunStatus -Check 'Profilo' -Status 'OK' -Details "$GpuProfile · $Profile · Xbox $Console"
    Set-AstraForgePreRunStatus -Check 'Input locale' -Status 'OK' -Details 'Eseguibile trovato; log, cache e dati AstraForge restano separati.'
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
$rustSourcePaths = @(Get-ChildItem -LiteralPath (Join-Path $repo 'crates') -Recurse -File -Filter '*.rs' | ForEach-Object FullName)
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
if ($PreRunWindow) {
    $runtimeHash = (Get-FileHash -LiteralPath $runner -Algorithm SHA256).Hash.Substring(0, 12)
    $runtimeBuildNote = 'Build diagnostica corrente'
    $manifestCursor = Split-Path -Parent $runner
    while ($manifestCursor -and -not (Test-Path -LiteralPath (Join-Path $manifestCursor 'build-manifest.json') -PathType Leaf)) {
        $manifestCursor = Split-Path -Parent $manifestCursor
    }
    if ($manifestCursor) {
        try {
            $buildManifest = Get-Content -LiteralPath (Join-Path $manifestCursor 'build-manifest.json') -Raw | ConvertFrom-Json
            if ($buildManifest.SourceDirty -eq $true) { $runtimeBuildNote = 'Build diagnostica da sorgente modificato' }
        } catch { }
    }
    Set-AstraForgePreRunStatus -Check 'Build' -Status 'OK' -Details "$runtimeBuildNote · SHA-256 $runtimeHash"
}
$presentMonPath = $null
if (-not [string]::IsNullOrWhiteSpace($PresentMonExe)) {
    if (-not (Test-Path -LiteralPath $PresentMonExe -PathType Leaf)) { throw "PresentMon executable not found: $PresentMonExe" }
    $presentMonPath = (Resolve-Path -LiteralPath $PresentMonExe).Path
} else {
    $presentMonCommand = Get-Command PresentMon_x64.exe, PresentMon.exe, presentmon.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($presentMonCommand) { $presentMonPath = $presentMonCommand.Source }
    if (-not $presentMonPath) {
        $nvidiaFrameViewPresentMon = Join-Path $env:ProgramFiles 'NVIDIA Corporation\FrameViewSDK\bin\PresentMon_x64.exe'
        if (Test-Path -LiteralPath $nvidiaFrameViewPresentMon -PathType Leaf) { $presentMonPath = $nvidiaFrameViewPresentMon }
    }
}
if ($PreRunWindow) {
    if ($presentMonPath) {
        Set-AstraForgePreRunStatus -Check 'Frame capture' -Status 'OK' -Details 'PresentMon pronto · ALT+MAIUSC+F11 avvia/ferma il CSV dei frame.'
    } else {
        Set-AstraForgePreRunStatus -Check 'Frame capture' -Status 'ATTENZIONE' -Details 'PresentMon non trovato; i log diagnostici restano attivi, ma non si crea il CSV per-frame.'
    }
}

$outputFull = Get-CanonicalPath $OutputRoot
if (Test-WithinPath $outputFull $workspaceFull -or Test-WithinPath $outputFull $gameRoot) {
    throw 'Log, cache e dati AstraForge devono restare fuori dal repository e dai file di gioco.'
}
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$runDir = Join-Path $outputFull "$stamp-$GpuProfile-$Profile-$Console"
$cacheDir = if ([string]::IsNullOrWhiteSpace($CacheDir)) {
    Join-Path $env:LOCALAPPDATA "VIctory\$GpuProfile\cache"
} else {
    Get-CanonicalPath $CacheDir
}
$dataDir = if ([string]::IsNullOrWhiteSpace($DataDir)) {
    Join-Path $env:LOCALAPPDATA "VIctory\$GpuProfile\data"
} else {
    Get-CanonicalPath $DataDir
}
foreach ($managedPath in @($cacheDir, $dataDir)) {
    if (Test-WithinPath $managedPath $workspaceFull -or Test-WithinPath $managedPath $gameRoot -or Test-WithinPath $managedPath $repoFull) {
        throw 'Cache e dati AstraForge devono restare fuori dal workspace e dai file di gioco.'
    }
}
New-Item -ItemType Directory -Force -Path $runDir, $cacheDir, $dataDir | Out-Null
if ($PreRunWindow) {
    $cacheFiles = @(Get-ChildItem -LiteralPath $cacheDir -File -Recurse -ErrorAction SilentlyContinue)
    $cacheBytes = ($cacheFiles | Measure-Object -Property Length -Sum).Sum
    if ($null -eq $cacheBytes) { $cacheBytes = 0 }
    $cacheStatus = if ($cacheFiles.Count -gt 0) { 'OK' } else { 'ATTENZIONE' }
    $cacheDetails = if ($cacheFiles.Count -gt 0) {
        ('Cache riutilizzata: {0:N0} file · {1:N0} MiB' -f $cacheFiles.Count, ($cacheBytes / 1MB))
    } else {
        'Cache shader vuota; la compilazione avverrà durante il primo avvio.'
    }
    Set-AstraForgePreRunStatus -Check 'Cache e percorsi' -Status $cacheStatus -Details $cacheDetails
}

# The inspected fork calls D3D12CreateDevice(NULL), so the first DXGI adapter matters.
$probeScript = Join-Path $PSScriptRoot 'Collect-AstraForgeHardware.ps1'
$windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
if (-not (Test-Path -LiteralPath $probeScript -PathType Leaf) -or -not (Test-Path -LiteralPath $windowsPowerShell -PathType Leaf)) {
    throw 'Probe hardware o Windows PowerShell non disponibile: non posso verificare l adapter DXGI predefinito.'
}
$hardwarePath = Join-Path $runDir 'hardware.json'
$dxdiagPath = Join-Path $runDir 'dxdiag.txt'
if ($PreRunWindow) { Set-AstraForgePreRunStatus -Check 'GPU e DirectX 12' -Status 'IN CORSO' -Details 'Controllo adapter DXGI, WaveOps, modello shader e telemetria NVIDIA.' }
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
if ($PreRunWindow) {
    $gpuDetails = '{0} · driver {1} · {2:N1}/{3:N1} GiB VRAM liberi al campionamento · PCIe Gen{4} x{5} · SM {6} · Wave{7}-{8}' -f `
        $targetAdapter.Name, $telemetry.DriverVersion, ([double]$telemetry.FreeMemoryMiB / 1024), ([double]$dedicatedMemoryMiB / 1024), `
        $telemetry.PcieGenerationCurrent, $telemetry.PcieWidthCurrent, $d3d.ShaderModel, $d3d.WaveLaneCountMin, $d3d.WaveLaneCountMax
    Set-AstraForgePreRunStatus -Check 'GPU e DirectX 12' -Status 'OK' -Details $gpuDetails
}
$availableCommit = [double]$hardware.RAM.AvailableCommitGiB
Assert-AstraForgeCommitHeadroom -AvailableGiB $availableCommit -MinimumGiB $MinimumAvailableCommitGiB
if ($availableCommit -lt [int]$gpuProfileConfig.runtime.warnBelowAvailableCommitGiB) {
    Write-Warning ("Commit disponibile {0:N1} GiB, sotto il margine indicativo di {1} GiB del profilo {2}; un host diverso può richiedere più spazio per evitare paging." -f $availableCommit, $gpuProfileConfig.runtime.warnBelowAvailableCommitGiB, $GpuProfile)
}
if ($PreRunWindow) {
    $ramDetails = 'RAM fisica libera {0:N1} GiB · memoria commit libera {1:N1} GiB (minimo launcher {2} GiB)' -f `
        [double]$hardware.RAM.AvailableGiB, $availableCommit, $MinimumAvailableCommitGiB
    Set-AstraForgePreRunStatus -Check 'RAM e commit' -Status 'OK' -Details $ramDetails
}

$environment = @{}
foreach ($property in $config.baselineEnvironment.PSObject.Properties) {
    $environment[$property.Name] = [string]$property.Value
}
$environment['VICTORY_TEXTURE_ROOM_PERCENT'] = [string]$selectedProfile.textureRoomPercent
foreach ($entry in $RuntimeOverride.GetEnumerator()) {
    $environment[[string]$entry.Key] = [string]$entry.Value
}
$environment['VICTORY_CACHE_DIR'] = $cacheDir
$environment['VICTORY_DATA_DIR'] = $dataDir

$previousEnvironment = @{}
Get-ChildItem Env: | Where-Object Name -Like 'VICTORY_*' | ForEach-Object {
    $previousEnvironment[$_.Name] = $_.Value
    Remove-Item "Env:$($_.Name)"
}
foreach ($name in $environment.Keys) { Set-Item "Env:$name" $environment[$name] }
if ($PreRunWindow) {
    Set-AstraForgePreRunStatus -Check 'Ambiente runtime' -Status 'OK' -Details ("{0} variabili validate · dati e cache esterni al progetto e all’installazione" -f $environment.Count)
    Set-AstraForgePreRunStatus -Check 'Preflight' -Status 'PRONTO' -Details 'Controlli superati; avvio automatico in corso.'
    Set-AstraForgePreRunFooter -Text 'Tutto pronto. Se chiudi questa finestra prima dell’avvio, la sessione viene annullata.'
    for ($countdown = 2; $countdown -gt 0; $countdown--) {
        [System.Windows.Forms.Application]::DoEvents()
        if (Test-AstraForgePreRunCancelled) { throw 'Avvio annullato dalla finestra di pre-run.' }
        Start-Sleep -Milliseconds 500
    }
    if (Test-AstraForgePreRunCancelled) { throw 'Avvio annullato dalla finestra di pre-run.' }
}

$stdoutPath = Join-Path $runDir 'victory.stdout.log'
$stderrPath = Join-Path $runDir 'victory.stderr.log'
$memoryCsv = Join-Path $runDir 'memory.csv'
$counterCsv = Join-Path $runDir 'gpu-process-counters.csv'
$threadCsv = Join-Path $runDir 'process-threads.csv'
$nvidiaCsv = Join-Path $runDir 'nvidia-smi.csv'
$nvidiaStderr = Join-Path $runDir 'nvidia-smi.stderr.log'
$frameCsv = Join-Path $runDir 'presentmon-frames.csv'
$presentMonStdout = Join-Path $runDir 'presentmon.stdout.log'
$presentMonStderr = Join-Path $runDir 'presentmon.stderr.log'
$graphicsEventsCsv = Join-Path $runDir 'system-graphics-events.csv'
$argumentLine = 'run "{0}" --console {1} --execute' -f $gameExe, $Console
$process = $null
$debugProcess = $null
$nvidiaProcess = $null
$presentMonProcess = $null
$runStartedAt = $null
$threadCpuPrevious = @{}
$lastThreadSampleAt = Get-Date
try {
    Write-Host "GPU profile: $GpuProfile ($($gpuProfileConfig.displayName); $($gpuProfileConfig.adapter.architecture)); not benchmarked on this PC."
    Write-Host "Tuning profile: $Profile ($($selectedProfile.textureRoomPercent)% texture-room admission)."
    Write-Host "First DXGI adapter: $($firstAdapter.Name) [$($firstAdapter.AdapterLuid)]"
    Write-Host "Commit disponibile: $('{0:N1}' -f $availableCommit) GiB"
    Write-Host "Log esterni al repository: $runDir"
    Write-Host "Intento: $($selectedProfile.intent)"
    if ($PreRunWindow) {
        Set-AstraForgePreRunStatus -Check 'Runtime' -Status 'IN CORSO' -Details 'Avvio della build diagnostica; input controller lasciato all’utente.'
        Start-AstraForgePreRunLaunch
    }
    $process = Start-Process -FilePath $runner -ArgumentList $argumentLine -WorkingDirectory $repo -NoNewWindow -PassThru `
        -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    if ($PreRunWindow) { Complete-AstraForgePreRunLaunch -ProcessId $process.Id }
    $runStartedAt = Get-Date
    if ($presentMonPath) {
        $presentMonArguments = "--process_id $($process.Id) --output_file `"$frameCsv`" --date_time --exclude_dropped --track_frame_type --hotkey ALT+SHIFT+F11 --terminate_on_proc_exit --session_name AstraForge-$($process.Id)"
        $presentMonProcess = Start-Process -FilePath $presentMonPath -ArgumentList $presentMonArguments -PassThru -WindowStyle Hidden `
            -RedirectStandardOutput $presentMonStdout -RedirectStandardError $presentMonStderr
        Start-Sleep -Milliseconds 500
        $presentMonProcess.Refresh()
        if ($presentMonProcess.HasExited -and $presentMonProcess.ExitCode -ne 0) {
            Write-Warning 'PresentMon non si è agganciato al runtime; il lancio continua e i log engine/memoria restano attivi.'
            $presentMonProcess = $null
        } elseif ($PreRunWindow) {
            Set-AstraForgePreRunStatus -Check 'Frame capture' -Status 'ATTIVO' -Details 'Pronto. Premi ALT+MAIUSC+F11 dopo aver raggiunto la scena; ripremi per fermare la cattura.'
        }
    }
    $nvidiaSmi = Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue
    if ($nvidiaSmi) {
        $nvidiaArguments = '--query-gpu=timestamp,utilization.gpu,utilization.memory,memory.total,memory.used,memory.free,clocks.current.graphics,clocks.current.memory,power.draw,temperature.gpu,pstate --format=csv,nounits --loop-ms=1000'
        $nvidiaProcess = Start-Process -FilePath $nvidiaSmi.Source -ArgumentList $nvidiaArguments -PassThru -WindowStyle Hidden `
            -RedirectStandardOutput $nvidiaCsv -RedirectStandardError $nvidiaStderr
    }
    if ($DebugConsole) {
        $debugTitle = "AstraForge Debug | $GpuProfile | $Profile"
        $escapedTitle = $debugTitle.Replace("'", "''")
        $escapedRunDir = $runDir.Replace("'", "''")
        $escapedStdout = $stdoutPath.Replace("'", "''")
        $escapedStderr = $stderrPath.Replace("'", "''")
        $debugPayload = @"
`$ErrorActionPreference = 'Continue'
`$Host.UI.RawUI.WindowTitle = '$escapedTitle'
Write-Host 'AstraForge diagnostic stream' -ForegroundColor Cyan
Write-Host 'Runtime PID: $($process.Id)'
Write-Host 'Run directory: $escapedRunDir'
Write-Host 'The render window remains separate. Closing this console does not stop the runtime.'
if ('$([bool]$presentMonPath)' -eq 'True') {
    Write-Host 'PresentMon capture is ready: press ALT+SHIFT+F11 after reaching a gameplay scene; press again to stop.' -ForegroundColor Yellow
    Write-Host 'Captured per-frame CSV: $frameCsv'
}
`$paths = @('$escapedStdout', '$escapedStderr')
`$jobs = foreach (`$path in `$paths) {
    Start-Job -ArgumentList `$path -ScriptBlock {
        param([string]`$LogPath)
        while (-not (Test-Path -LiteralPath `$LogPath -PathType Leaf)) { Start-Sleep -Milliseconds 100 }
        Get-Content -LiteralPath `$LogPath -Tail 40 -Wait
    }
}
try { `$jobs | Receive-Job -Wait }
finally { `$jobs | Stop-Job -ErrorAction SilentlyContinue; `$jobs | Remove-Job -Force -ErrorAction SilentlyContinue }
"@
        $debugCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($debugPayload))
        $debugProcess = Start-Process -FilePath $windowsPowerShell -ArgumentList @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-NoExit', '-EncodedCommand', $debugCommand
        ) -WindowStyle Normal -PassThru
        Write-Host "Console diagnostica AstraForge aperta (PID $($debugProcess.Id))."
    }
    'utc,private_gib,working_set_gib,thread_count,cpu_seconds,available_physical_gib,available_commit_gib,commit_limit_gib' | Set-Content -LiteralPath $memoryCsv -Encoding utf8
    'utc,process_id,metric,value,unit,counter_path' | Set-Content -LiteralPath $counterCsv -Encoding utf8
    'utc,process_id,thread_id,cpu_seconds_delta,one_core_utilization_percent,logical_cpu_utilization_percent' | Set-Content -LiteralPath $threadCsv -Encoding utf8
    while ($true) {
        $process.Refresh()
        if ($process.HasExited) { break }
        $utc = (Get-Date).ToUniversalTime().ToString('o')
        $privateGiB = $process.PrivateMemorySize64 / 1GB
        $workingSetGiB = $process.WorkingSet64 / 1GB
        $threadCount = $process.Threads.Count
        $cpuSeconds = $process.TotalProcessorTime.TotalSeconds
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
            utc = $utc; private_gib = $privateGiB; working_set_gib = $workingSetGiB
            thread_count = $threadCount; cpu_seconds = $cpuSeconds; available_physical_gib = $freePhysicalGiB
            available_commit_gib = $freeCommitGiB; commit_limit_gib = $commitLimitGiB
        } | Export-Csv -LiteralPath $memoryCsv -NoTypeInformation -Append
        try {
            $samples = (Get-Counter -Counter @(
                "\GPU Process Memory(pid_$($process.Id)*)\Dedicated Usage",
                "\GPU Process Memory(pid_$($process.Id)*)\Shared Usage",
                "\GPU Engine(pid_$($process.Id)*)\Utilization Percentage"
            ) -ErrorAction Stop).CounterSamples
            foreach ($sample in $samples) {
                $counterPath = [string]$sample.Path
                $metric = ($counterPath -split '\\')[-1]
                [pscustomobject]@{
                    utc = $utc; process_id = $process.Id; metric = $metric; value = [double]$sample.CookedValue
                    unit = if ($metric -match 'Usage$') { 'bytes' } else { 'percent' }; counter_path = $counterPath
                } |
                    Export-Csv -LiteralPath $counterCsv -NoTypeInformation -Append
            }
        } catch { }
        $threadSampleAt = Get-Date
        $threadElapsedSeconds = [Math]::Max(0.001, ($threadSampleAt - $lastThreadSampleAt).TotalSeconds)
        try {
            foreach ($thread in $process.Threads) {
                $threadId = [int]$thread.Id
                $threadCpu = [double]$thread.TotalProcessorTime.TotalSeconds
                if ($threadCpuPrevious.ContainsKey($threadId)) {
                    $deltaCpu = [Math]::Max(0.0, $threadCpu - [double]$threadCpuPrevious[$threadId])
                    $oneCorePercent = 100.0 * $deltaCpu / $threadElapsedSeconds
                    [pscustomobject]@{
                        utc = $utc; process_id = $process.Id; thread_id = $threadId; cpu_seconds_delta = $deltaCpu
                        one_core_utilization_percent = $oneCorePercent
                        logical_cpu_utilization_percent = $oneCorePercent / [Math]::Max(1, [Environment]::ProcessorCount)
                    } | Export-Csv -LiteralPath $threadCsv -NoTypeInformation -Append
                }
                $threadCpuPrevious[$threadId] = $threadCpu
            }
        } catch { }
        $lastThreadSampleAt = $threadSampleAt
        Start-Sleep -Seconds 5
    }
    $process.WaitForExit()
    $process.Refresh()
    $exitCode = $process.ExitCode
    if ($null -eq $exitCode) { throw 'Runtime AstraForge terminato senza rendere disponibile un exit code.' }
    Write-Host "Runtime AstraForge terminato con exit code $exitCode."
    Write-Host "Output: $stdoutPath"
    Write-Host "Errori: $stderrPath"
    Write-Host "Telemetria: $memoryCsv, $counterCsv, $threadCsv, $nvidiaCsv"
    if ($presentMonPath) { Write-Host "Frame PresentMon: $frameCsv" }
    Write-Host "Log eventi grafici: $graphicsEventsCsv"
    if ($exitCode -ne 0) { throw "Runtime AstraForge terminato con exit code $exitCode." }
} finally {
    if ($nvidiaProcess) {
        try {
            $nvidiaProcess.Refresh()
            if (-not $nvidiaProcess.HasExited) { Stop-Process -Id $nvidiaProcess.Id -Force -ErrorAction SilentlyContinue }
        } catch { }
    }
    if ($presentMonProcess) {
        try {
            $presentMonProcess.Refresh()
            if (-not $presentMonProcess.HasExited) { Stop-Process -Id $presentMonProcess.Id -Force -ErrorAction SilentlyContinue }
        } catch { }
    }
    if ($runStartedAt) {
        try {
            $graphicsEvents = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; StartTime = $runStartedAt } -ErrorAction Stop |
                Where-Object { $_.ProviderName -match 'Display|nvlddmkm|DxgKrnl|WHEA-Logger' } |
                Select-Object TimeCreated, ProviderName, Id, LevelDisplayName, Message)
            if ($graphicsEvents.Count -gt 0) {
                $graphicsEvents | Export-Csv -LiteralPath $graphicsEventsCsv -NoTypeInformation -Encoding UTF8
            } else {
                'TimeCreated,ProviderName,Id,LevelDisplayName,Message' | Set-Content -LiteralPath $graphicsEventsCsv -Encoding UTF8
            }
        } catch {
            "System event query unavailable: $($_.Exception.Message)" | Set-Content -LiteralPath $graphicsEventsCsv -Encoding UTF8
        }
    }
    foreach ($entry in $previousEnvironment.GetEnumerator()) { Set-Item "Env:$($entry.Key)" $entry.Value }
    Get-ChildItem Env: | Where-Object { $_.Name -like 'VICTORY_*' -and -not $previousEnvironment.ContainsKey($_.Name) } |
        ForEach-Object { Remove-Item "Env:$($_.Name)" -ErrorAction SilentlyContinue }
}
