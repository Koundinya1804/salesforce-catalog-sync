param([switch]$SelfTest)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$portable = Get-ChildItem "$projectRoot/target/jdk17-current" -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
$java = if ($portable) { Join-Path $portable.FullName 'bin/java.exe' } else { Join-Path $env:JAVA_HOME 'bin/java.exe' }
$repository = Join-Path $projectRoot 'target/verification-cached-repository'
if (!(Test-Path $repository)) { $repository = Join-Path $env:USERPROFILE '.m2/repository' }
$patterns = @('*mule-secure-configuration-property-module-1.2.7-mule-plugin.jar','mule-encryption-1.3.2.jar','commons-lang-2.6.jar','snakeyaml-2*.jar','mysql-connector-j-8.0.33.jar')
$jars = foreach ($pattern in $patterns) {
    $jar = Get-ChildItem $repository -Filter $pattern -Recurse | Select-Object -First 1
    if (!$jar) { throw "Missing dependency: $pattern. Build the project first." }
    $jar.FullName
}
$classPath = $jars -join [IO.Path]::PathSeparator
$sourceFile = Join-Path $PSScriptRoot 'UpdateDatabasePassword.java'
if ($SelfTest) { & $java -cp $classPath $sourceFile $projectRoot --self-test; exit $LASTEXITCODE }
$password = Read-Host 'Enter the MySQL password (input is hidden)' -AsSecureString
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
    if ($process.ExitCode -ne 0) { throw 'Password update failed; existing credentials were preserved.' }
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($nativeSecret)
    $password.Dispose()
}
