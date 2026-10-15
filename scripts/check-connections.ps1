param([string]$JavaHome)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$temporarySuite = Join-Path $projectRoot 'src/test/munit/live-connection-checks.xml'
if (Test-Path $temporarySuite) { throw 'A live-connection-checks.xml suite already exists; remove the temporary suite before running this helper.' }
try {
    Copy-Item (Join-Path $PSScriptRoot 'validation/live-connection-checks.xml') $temporarySuite
    & (Join-Path $PSScriptRoot 'build.ps1') -Goal test -JavaHome $JavaHome -MavenArguments '-Dmunit.test=live-connection-checks.xml'
} finally {
    Remove-Item -LiteralPath $temporarySuite -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path $projectRoot 'target/test-mule/munit/live-connection-checks.xml') -ErrorAction SilentlyContinue
}
