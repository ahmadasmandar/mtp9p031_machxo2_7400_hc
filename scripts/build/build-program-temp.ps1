[CmdletBinding()]
param(
    [string]$DiamondRoot = 'C:\lscc\diamond\3.14',
    [string]$TempBuildRoot = 'C:\Temp\FPGA_Build\KAMERA_TEST',
    [switch]$SkipProgram
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$repoImpl = Join-Path $repoRoot 'impl1'
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$tempRoot = Join-Path $TempBuildRoot $stamp
$tempImpl = Join-Path $tempRoot 'impl1'

New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
foreach ($name in @('KAMERA_TEST.ldf', 'KAMERA_TEST1.sty', 'KAMERA_TEST_blinky.lpf', 'top.vhd', 'program_xcf.xcf')) {
    Copy-Item -LiteralPath (Join-Path $repoRoot $name) -Destination (Join-Path $tempRoot $name) -Force
}
Copy-Item -LiteralPath (Join-Path $repoRoot 'modules') -Destination (Join-Path $tempRoot 'modules') -Recurse

& (Join-Path $PSScriptRoot 'build.ps1') `
    -DiamondRoot $DiamondRoot `
    -ProjectFile (Join-Path $tempRoot 'KAMERA_TEST.ldf') `
    -Mode Full `
    -SkipXcfUpdate
if ($LASTEXITCODE -ne 0) { throw "Temporary Diamond build failed with exit code $LASTEXITCODE." }

$artifacts = @(
    'KAMERA_TEST_impl1.jed',
    'KAMERA_TEST_impl1.par',
    'KAMERA_TEST_impl1.twr',
    'KAMERA_TEST_impl1.mrp',
    'KAMERA_TEST_impl1.arearep',
    'KAMERA_TEST_impl1.pad',
    'KAMERA_TEST_impl1.prf',
    'KAMERA_TEST_impl1.ncd',
    'KAMERA_TEST_impl1_map.ncd',
    'synthesis.log',
    'automake.log'
)
New-Item -ItemType Directory -Path $repoImpl -Force | Out-Null
foreach ($name in $artifacts) {
    $source = Join-Path $tempImpl $name
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Expected build artifact is missing: $source"
    }
    Copy-Item -LiteralPath $source -Destination (Join-Path $repoImpl $name) -Force
}

$repoJedec = Join-Path $repoImpl 'KAMERA_TEST_impl1.jed'
& (Join-Path $PSScriptRoot 'update_xcf.ps1') `
    -JedecFile $repoJedec `
    -XcfFile (Join-Path $repoRoot 'program_xcf.xcf')
if ($LASTEXITCODE -ne 0) { throw "Programming XCF update failed with exit code $LASTEXITCODE." }

& (Join-Path $PSScriptRoot 'check_build.ps1') -ProjectRoot $repoRoot
if ($LASTEXITCODE -ne 0) { throw "Copied build output check failed with exit code $LASTEXITCODE." }

if (-not $SkipProgram) {
    & (Join-Path $PSScriptRoot 'program.ps1') -DiamondRoot $DiamondRoot -XcfFile (Join-Path $repoRoot 'program_xcf.xcf')
}

Write-Output "TEMP_BUILD=$tempRoot"
Write-Output "RELEASE_JEDEC=$repoJedec"
Write-Output "PROGRAM_XCF=$(Join-Path $repoRoot 'program_xcf.xcf')"
