param([switch]$SelfTest)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$portable = Get-ChildItem "$projectRoot/target/jdk17-current" -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
$javaHome = if ($portable) { $portable.FullName } else { $env:JAVA_HOME }
if (!$javaHome -or !(Test-Path "$javaHome/bin/java.exe")) { throw 'Set JAVA_HOME to an installed JDK 17.' }
$java = Join-Path $javaHome 'bin/java.exe'
$repository = Join-Path $projectRoot 'target/verification-cached-repository'
if (!(Test-Path $repository)) { $repository = Join-Path $env:USERPROFILE '.m2/repository' }
$patterns = @('*mule-secure-configuration-property-module-1.2.7-mule-plugin.jar','mule-encryption-1.3.2.jar','commons-lang-2.6.jar','snakeyaml-2*.jar','mysql-connector-j-8.0.33.jar')
$jars = foreach ($pattern in $patterns) {
    $jar = Get-ChildItem $repository -Filter $pattern -Recurse | Select-Object -First 1
    if (!$jar) { throw "Missing dependency: $pattern" }
    $jar.FullName
}
$classPath = $jars -join [IO.Path]::PathSeparator
$sourceFile = Join-Path $PSScriptRoot 'ConfigureAiven.java'
if ($SelfTest) { & $java -cp $classPath $sourceFile $projectRoot --self-test; exit $LASTEXITCODE }
$password = Read-Host 'Paste the Aiven MySQL password (input is hidden)' -AsSecureString
$nativeSecret = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
try {
    $plainSecret = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($nativeSecret)
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $java
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardInput = $true
    foreach ($argument in @('-cp',$classPath,$sourceFile,$projectRoot)) { $startInfo.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::Start($startInfo)
    $process.StandardInput.WriteLine($plainSecret)
    $process.StandardInput.Close()
    $plainSecret = $null
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) { throw 'Aiven setup failed. No new cloud credentials were saved.' }
    $studioResources = Join-Path $env:USERPROFILE 'AnypointStudio/studio-workspace/salesforce/src/main/resources'
    if (Test-Path $studioResources) {
        foreach ($file in @('config-aiven.yaml','secure-properties-aiven.yaml','aiven-truststore.p12')) {
            Copy-Item -LiteralPath (Join-Path $projectRoot "src/main/resources/$file") -Destination (Join-Path $studioResources $file)
        }
        Write-Host 'Cloud configuration copied to the Studio salesforce project.'
    }
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($nativeSecret)
    $password.Dispose()
}
