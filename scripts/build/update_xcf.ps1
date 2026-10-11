[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$JedecFile,

    [Parameter(Mandatory = $true)]
    [string]$XcfFile
)

$ErrorActionPreference = 'Stop'
$jedecPath = (Resolve-Path -LiteralPath $JedecFile).Path
$xcfPath = (Resolve-Path -LiteralPath $XcfFile).Path
$jedec = Get-Content -LiteralPath $jedecPath -Raw

$checksumMatch = [regex]::Match($jedec, '(?m)^C([0-9A-Fa-f]{4})\*')
if (-not $checksumMatch.Success) {
    throw "JEDEC checksum line was not found in $jedecPath"
}

$checksum = $checksumMatch.Groups[1].Value.ToUpperInvariant()
$fileTime = (Get-Item -LiteralPath $jedecPath).LastWriteTime.ToString('MM/dd/yy HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture)
$content = Get-Content -LiteralPath $xcfPath -Raw
$content = $content -replace '<File>.*?</File>', "<File>$($jedecPath -replace '\\','/')</File>"
$content = $content -replace '<FileTime>.*?</FileTime>', "<FileTime>$fileTime</FileTime>"
$content = $content -replace '<JedecChecksum>.*?</JedecChecksum>', "<JedecChecksum>0x$checksum</JedecChecksum>"
[IO.File]::WriteAllText($xcfPath, $content, [Text.UTF8Encoding]::new($false))
Write-Output "Updated $xcfPath for $jedecPath (checksum 0x$checksum)."
