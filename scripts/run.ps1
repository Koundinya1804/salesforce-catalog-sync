param([string]$JavaHome, [string]$MuleHome, [switch]$NoDeploy)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
Push-Location $projectRoot
try {
    if (!$JavaHome) {
        $portable = Get-ChildItem 'target/jdk17-current' -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($portable) { $JavaHome = $portable.FullName } else { $JavaHome = $env:JAVA_HOME }
    }
    if (!$JavaHome -or !(Test-Path "$JavaHome/bin/java.exe")) { throw 'Set JAVA_HOME to JDK 17 or pass -JavaHome.' }
    $java = Join-Path $JavaHome 'bin/java.exe'
    if ((& $java -version 2>&1 | Out-String) -notmatch 'version "17\.') { throw 'This application requires JDK 17.' }
    if (!$MuleHome) { $MuleHome = Join-Path $projectRoot 'target/local-mule-runtime' }
    $MuleHome = (Resolve-Path $MuleHome).Path
    foreach ($folder in @('apps','domains','logs','.mule')) { New-Item -ItemType Directory (Join-Path $MuleHome $folder) -Force | Out-Null }
    New-Item -ItemType Directory 'target/java-sockets' -Force | Out-Null
    if (!$NoDeploy) {
        $artifact = Get-ChildItem 'target/*-mule-application.jar' | Select-Object -First 1
        if (!$artifact) { throw 'Build first: ./scripts/build.ps1 -Goal package' }
        Copy-Item $artifact.FullName (Join-Path $MuleHome 'apps/salesforce.jar') -Force
    }
    $optionsFile = Join-Path $projectRoot 'target/local-runtime-options.txt'
    $resolver = Join-Path $MuleHome 'lib/launcher/mule-wrapperless-arguments-resolver.jar'
    & $java -jar $resolver "--OPTIONS_OUT_FILE=$optionsFile" $MuleHome | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Unable to resolve Mule JVM options.' }
    $options = Get-Content $optionsFile | Where-Object { $_ -notmatch 'FlightRecorder|OnOutOfMemoryError|AlwaysPreTouch' }
    $runtimePath = $MuleHome.Replace('\','/')
    $options = $options | ForEach-Object { $_.Replace('MULE_HOME', $runtimePath).Replace('MULE_BASE', $runtimePath) }
    $socketPath = (Resolve-Path 'target/java-sockets').Path.Replace('\','/')
    $options += '"-Djdk.net.unixdomain.tmpdir=' + $socketPath + '"'
    Set-Content $optionsFile $options
    & $java "@$optionsFile" -m 'com.mulesoft.mule.boot/com.mulesoft.mule.runtime.MuleContainerBootstrap'
    if ($LASTEXITCODE -ne 0) { throw "Mule exited with code $LASTEXITCODE." }
} finally { Pop-Location }
