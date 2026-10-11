[CmdletBinding()]
param(
    [string]$DiamondRoot = $env:LATTICE_DIAMOND_HOME,
    [string]$XcfFile
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($XcfFile)) {
    $XcfFile = Join-Path $PSScriptRoot '..\..\impl1\KAMERA_TEST_impl1.xcf'
}
$pgrcmd = Join-Path $DiamondRoot 'bin\nt64\pgrcmd.exe'
if (-not (Test-Path -LiteralPath $pgrcmd -PathType Leaf)) {
    $pgrcmd = Join-Path $DiamondRoot 'bin\nt\pgrcmd.exe'
}
if (-not (Test-Path -LiteralPath $pgrcmd -PathType Leaf)) {
    throw "Diamond pgrcmd.exe was not found below: $DiamondRoot"
}

$xcfPath = (Resolve-Path -LiteralPath $XcfFile).Path
& $pgrcmd -infile $xcfPath
if ($LASTEXITCODE -ne 0) {
    throw "Programming failed with exit code $LASTEXITCODE."
}
