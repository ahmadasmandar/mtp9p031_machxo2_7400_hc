[CmdletBinding()]
param(
    [ValidateSet('Synthesis', 'Full')]
    [string]$Mode = 'Full',

    [string]$DiamondRoot = $env:LATTICE_DIAMOND_HOME,

    [string]$ProjectFile,

    [switch]$SkipXcfUpdate
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($ProjectFile)) {
    $ProjectFile = Join-Path $PSScriptRoot '..\..\KAMERA_TEST.ldf'
}
$projectFile = (Resolve-Path -LiteralPath $ProjectFile).Path
$projectRoot = Split-Path -Parent $projectFile

if ([string]::IsNullOrWhiteSpace($DiamondRoot)) {
    throw 'Specify -DiamondRoot or set LATTICE_DIAMOND_HOME.'
}

$pnmainc = Join-Path $DiamondRoot 'bin\nt64\pnmainc.exe'
if (-not (Test-Path -LiteralPath $pnmainc -PathType Leaf)) {
    $pnmainc = Join-Path $DiamondRoot 'bin\nt\pnmainc.exe'
}
if (-not (Test-Path -LiteralPath $pnmainc -PathType Leaf)) {
    throw "Diamond pnmainc.exe was not found below: $DiamondRoot"
}

$env:KAMERA_PROJECT = $projectFile
$env:KAMERA_MODE = $Mode
try {
    & $pnmainc (Join-Path $PSScriptRoot 'run_build.tcl')
    if ($LASTEXITCODE -ne 0) {
        throw "Diamond build failed with exit code $LASTEXITCODE."
    }
    if ($Mode -eq 'Full' -and -not $SkipXcfUpdate) {
        $jedec = Join-Path $projectRoot 'impl1\KAMERA_TEST_impl1.jed'
        $xcf = Join-Path $projectRoot 'impl1\KAMERA_TEST_impl1.xcf'
        if (-not (Test-Path -LiteralPath $xcf -PathType Leaf)) {
            Copy-Item -LiteralPath (Join-Path $projectRoot 'program_xcf.xcf') -Destination $xcf
        }
        & (Join-Path $PSScriptRoot 'update_xcf.ps1') -JedecFile $jedec -XcfFile $xcf
    }
}
finally {
    Remove-Item Env:KAMERA_PROJECT -ErrorAction SilentlyContinue
    Remove-Item Env:KAMERA_MODE -ErrorAction SilentlyContinue
}
