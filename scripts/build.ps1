param([ValidateSet('test','package')][string]$Goal = 'package', [string]$JavaHome, [string[]]$MavenArguments = @())
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
    $javaVersion = & $java -version 2>&1 | Out-String
    if ($javaVersion -notmatch 'version "17\.') { throw 'This application requires JDK 17.' }
    $env:JAVA_HOME = $JavaHome
    New-Item -ItemType Directory 'target/java-sockets' -Force | Out-Null
    $maven = Get-Command mvn.cmd -ErrorAction SilentlyContinue
    if ($maven) {
        & $maven.Source -B -ntp $Goal @MavenArguments
    } else {
        $mavenLib = Join-Path $projectRoot 'target/verification-tools/lib'
        if (!(Test-Path "$mavenLib/maven-embedder.jar")) {
            $studioMaven = Get-ChildItem 'C:/AnypointStudio/plugins/org.mule.tooling.maven.embedded_*.jar' -ErrorAction SilentlyContinue | Select-Object -First 1
            if (!$studioMaven) { throw 'Install Maven 3.9+ and add mvn to PATH.' }
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::ExtractToDirectory($studioMaven.FullName, (Join-Path $projectRoot 'target/verification-tools'), $true)
        }
        $mavenArgs = @("-Dmaven.multiModuleProjectDirectory=$projectRoot")
        if (Test-Path 'target/verification-cached-repository') { $mavenArgs += '-Dmaven.repo.local=target/verification-cached-repository' }
        & $java @mavenArgs -cp "$mavenLib/*" org.apache.maven.cli.MavenCli -B -ntp $Goal @MavenArguments
    }
    if ($LASTEXITCODE -ne 0) { throw "Maven $Goal failed (exit $LASTEXITCODE)." }
} finally { Pop-Location }
