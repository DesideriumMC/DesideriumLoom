param(
    [Parameter(Mandatory=$true)][string]$Directory,
    [Parameter(Mandatory=$true)][string]$LoaderJar,
    [Parameter(Mandatory=$true)][string]$LoaderMixinJar,
    [string]$CompileJdk,
    [string]$GameJdk,
    [switch]$Portable
)
$ErrorActionPreference = 'Stop'
$loomRoot = Split-Path $PSScriptRoot -Parent
$destination = [IO.Path]::GetFullPath($Directory)
if ((Test-Path -LiteralPath $destination) -and (Get-ChildItem -LiteralPath $destination -Force | Select-Object -First 1)) {
    throw "New project directory must be empty: $destination"
}
$loader = (Resolve-Path -LiteralPath $LoaderJar).Path.Replace('\', '/')
$runtime = (Resolve-Path -LiteralPath $LoaderMixinJar).Path.Replace('\', '/')
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($loader)
try {
    $entry = $archive.GetEntry('META-INF/desiderium-java.properties')
    if (!$entry) { throw 'The default Java 8 template requires the new Java 8 Loader (ASM 5.2), not the historical L1/L2 Loader.' }
    $reader = [IO.StreamReader]::new($entry.Open())
    try { $capability = $reader.ReadToEnd() } finally { $reader.Dispose() }
    if ($capability -notmatch '(?m)^runtime=8\r?$' -or $capability -notmatch '(?m)^modClassMajorMax=52\r?$' -or $capability -notmatch '(?m)^asm=5\.2\r?$') {
        throw 'Unsupported Loader Java capability; expected runtime 8, maximum class major 52, ASM 5.2.'
    }
} finally { $archive.Dispose() }
if ($CompileJdk -and (Get-Content -LiteralPath (Join-Path $CompileJdk 'release') -Raw) -notmatch '(?m)^JAVA_VERSION="17[."]') {
    throw 'The default template compiles with JDK 17 / --release 8. Set -CompileJdk to JDK 17.'
}
New-Item -ItemType Directory -Force -Path $destination | Out-Null
Get-ChildItem -LiteralPath "$loomRoot/templates/mod" -Force | Copy-Item -Destination $destination -Recurse
Copy-Item -LiteralPath "$loomRoot/gradlew", "$loomRoot/gradlew.bat" -Destination $destination
New-Item -ItemType Directory -Force -Path "$destination/gradle" | Out-Null
Copy-Item -LiteralPath "$loomRoot/gradle/wrapper" -Destination "$destination/gradle" -Recurse
$properties = @(
    "loomPluginDir=$($loomRoot.Replace('\','/'))/plugin",
    "loaderJar=$loader",
    "loaderMixinJar=$runtime"
)
if ($Portable) {
    # Copy only plugin build inputs, never local caches or generated game data.
    $pluginDestination = Join-Path $destination 'build-tools/loom'
    New-Item -ItemType Directory -Force -Path $pluginDestination | Out-Null
    foreach ($name in @('src', 'build.gradle', 'settings.gradle', 'gradle.properties', 'LICENSE', 'UPSTREAM.md')) {
        Copy-Item -LiteralPath (Join-Path "$loomRoot/plugin" $name) -Destination $pluginDestination -Recurse
    }
    New-Item -ItemType Directory -Force -Path "$destination/libs" | Out-Null
    Copy-Item -LiteralPath $loader -Destination "$destination/libs/desiderium-loader.jar"
    Copy-Item -LiteralPath $runtime -Destination "$destination/libs/desiderium-loader-mixin.jar"
    $properties = @(
        'loomPluginDir=build-tools/loom',
        'loaderJar=libs/desiderium-loader.jar',
        'loaderMixinJar=libs/desiderium-loader-mixin.jar'
    )
}
$jdkPaths = @()
foreach ($jdk in @($CompileJdk, $GameJdk)) {
    if ($jdk) { $jdkPaths += (Resolve-Path -LiteralPath $jdk).Path.Replace('\', '/') }
}
if ($jdkPaths.Count) { $properties += "org.gradle.java.installations.paths=$($jdkPaths -join ',')" }
if ($CompileJdk -and $GameJdk) {
    $properties += 'org.gradle.java.installations.auto-detect=false'
    $properties += 'org.gradle.java.installations.auto-download=false'
}
$properties | Set-Content -LiteralPath "$destination/gradle.properties" -Encoding utf8
Write-Host "Created project: $destination"
