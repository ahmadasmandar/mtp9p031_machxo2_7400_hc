[CmdletBinding()]
param(
    [string]$ProjectRoot
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}
$impl = Join-Path $ProjectRoot 'impl1'
$required = @(
    'KAMERA_TEST_impl1.jed',
    'KAMERA_TEST_impl1.par',
    'KAMERA_TEST_impl1.twr',
    'KAMERA_TEST_impl1.mrp'
)

foreach ($name in $required) {
    $path = Join-Path $impl $name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required build output is missing: $path"
    }
}
$xcf = Join-Path $ProjectRoot 'program_xcf.xcf'
if (-not (Test-Path -LiteralPath $xcf -PathType Leaf)) { throw "Programming XCF is missing: $xcf" }

$par = Get-Content -Raw (Join-Path $impl 'KAMERA_TEST_impl1.par')
$twr = Get-Content -Raw (Join-Path $impl 'KAMERA_TEST_impl1.twr')
$mrp = Get-Content -Raw (Join-Path $impl 'KAMERA_TEST_impl1.mrp')

if ($par -notmatch 'PAR_SUMMARY::Run status\s*=\s*Completed') { throw 'PAR did not complete.' }
if ($par -notmatch 'PAR_SUMMARY::Number of unrouted conns\s*=\s*0') { throw 'PAR has unrouted connections.' }
if ($par -notmatch 'PAR_SUMMARY::Number of errors\s*=\s*0') { throw 'PAR has errors.' }
if ($twr -notmatch 'Timing errors: 0 \(setup\), 0 \(hold\)') { throw 'Timing errors were reported.' }
if ($twr -notmatch 'Cumulative negative slack: 0 \(0\+0\)') { throw 'Negative slack was reported.' }
if ($mrp -notmatch 'Number of errors:\s*0') { throw 'Map reported errors.' }

Write-Output 'BUILD_OUTPUT_CHECK=PASS'
Write-Output "JEDEC=$([IO.Path]::GetFullPath((Join-Path $impl 'KAMERA_TEST_impl1.jed')) )"
Write-Output "XCF=$([IO.Path]::GetFullPath($xcf))"
