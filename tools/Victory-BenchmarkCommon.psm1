Set-StrictMode -Version Latest

function Get-VictoryDirectoryFingerprint {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Directory)

    $root = (Resolve-Path -LiteralPath $Directory).Path.TrimEnd('\')
    $files = @(Get-ChildItem -LiteralPath $root -File -Force -Recurse | Sort-Object FullName)
    $incrementalHash = [System.Security.Cryptography.IncrementalHash]::CreateHash([System.Security.Cryptography.HashAlgorithmName]::SHA256)
    $buffer = New-Object byte[] (1024 * 1024)
    [long]$totalBytes = 0
    try {
        foreach ($file in $files) {
            $relative = $file.FullName.Substring($root.Length).TrimStart('\')
            $metadata = [System.Text.Encoding]::UTF8.GetBytes("$relative`0$($file.Length)`0")
            $incrementalHash.AppendData($metadata)
            $stream = [System.IO.File]::OpenRead($file.FullName)
            try {
                while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                    $incrementalHash.AppendData($buffer, 0, $read)
                }
            } finally { $stream.Dispose() }
            $totalBytes += [long]$file.Length
        }
        $digest = $incrementalHash.GetHashAndReset()
        return [pscustomobject]@{
            Files = $files.Count
            Bytes = $totalBytes
            Sha256 = [BitConverter]::ToString($digest).Replace('-', '')
        }
    } finally { $incrementalHash.Dispose() }
}

function Copy-VictoryCacheSeed {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$SourceDirectory,
        [Parameter(Mandatory = $true)][string]$DestinationDirectory
    )

    $source = (Resolve-Path -LiteralPath $SourceDirectory).Path
    $destination = [System.IO.Path]::GetFullPath($DestinationDirectory)
    if (Test-Path -LiteralPath $destination) {
        throw "Cache copy destination must be new; existing files are preserved: $destination"
    }
    $seedFingerprint = Get-VictoryDirectoryFingerprint -Directory $source
    if ($seedFingerprint.Files -eq 0) { throw "Cache seed contains no files: $source" }
    New-Item -ItemType Directory -Force -Path $destination | Out-Null
    Get-ChildItem -LiteralPath $source -Force | Copy-Item -Destination $destination -Recurse -Force
    $copyFingerprint = Get-VictoryDirectoryFingerprint -Directory $destination
    if ($copyFingerprint.Sha256 -cne $seedFingerprint.Sha256) {
        throw "Copied cache does not match its seed. Seed is preserved at '$source'; copy is isolated at '$destination'."
    }
    return [pscustomobject]@{
        SeedDirectory = $source
        WorkingDirectory = $destination
        Fingerprint = $seedFingerprint
    }
}

Export-ModuleMember -Function Get-VictoryDirectoryFingerprint, Copy-VictoryCacheSeed
