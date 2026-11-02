param(
    [Parameter(Mandatory = $true)][string]$BuildJdk,
    [Parameter(Mandatory = $true)][string]$CompileJdk,
    [Parameter(Mandatory = $true)][string]$GameJdk,
    [string[]]$Tasks = @(':baseline:build'),
    [string]$CacheDirectory = '.work/gradle-home'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$jdkPaths = @($BuildJdk, $CompileJdk, $GameJdk)
$expectedVersions = @(17, 11, 8)
for ($i = 0; $i -lt $jdkPaths.Count; $i++) {
    $release = Join-Path $jdkPaths[$i] 'release'
    if (!(Test-Path -LiteralPath $release)) { throw "Missing JDK release file: $release" }
    $versionLine = Get-Content -LiteralPath $release | Where-Object { $_ -match '^JAVA_VERSION=' }
    $expected = $expectedVersions[$i]
    $pattern = if ($expected -eq 8) { '^JAVA_VERSION="1\.8\.' } else { '^JAVA_VERSION="' + $expected + '\.' }
    if ($versionLine -notmatch $pattern) { throw "Expected JDK $expected at $($jdkPaths[$i]); got $versionLine" }
}
$previousJavaHome = $env:JAVA_HOME
Push-Location $projectRoot
try {
    $env:JAVA_HOME = $BuildJdk
    $toolchains = ($jdkPaths | ForEach-Object { (Resolve-Path -LiteralPath $_).Path }) -join ','
    & .\gradlew.bat --no-daemon --gradle-user-home $CacheDirectory "-Porg.gradle.java.installations.paths=$toolchains" @Tasks
    if ($LASTEXITCODE -ne 0) { throw "Gradle failed with exit code $LASTEXITCODE" }
} finally {
    $env:JAVA_HOME = $previousJavaHome
    Pop-Location
}
