param(
    [Parameter(Mandatory = $true)][string]$ReleaseJar,
    [string]$CacheDirectory = '.work/gradle-home',
    [string]$InstallationDirectory = '.work/production',
    [string]$ClientDirectory = '.work/production-client'
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root = Split-Path $PSScriptRoot -Parent
function AbsolutePath([string]$path) {
    if ([IO.Path]::IsPathRooted($path)) { return $path }
    return Join-Path $root $path
}
$cache = AbsolutePath $CacheDirectory
$installation = AbsolutePath $InstallationDirectory
$client = AbsolutePath $ClientDirectory
$release = AbsolutePath $ReleaseJar
$profile = Get-Content (Join-Path $installation 'install_profile.json') -Raw | ConvertFrom-Json
$manifestFile = Get-ChildItem (Join-Path $cache 'caches/voldeloom') -Filter 'minecraft-1.6.4-info-*.json' | Select-Object -First 1
$manifest = Get-Content $manifestFile.FullName -Raw | ConvertFrom-Json
New-Item -ItemType Directory -Force $client,"$client/mods","$client/libraries","$client/natives" | Out-Null
Copy-Item -LiteralPath $release -Destination "$client/mods/baseline-0.1.0.jar"
$forge = Join-Path $installation 'minecraftforge-universal-1.6.4-9.11.1.1345.jar'
Copy-Item -LiteralPath $forge -Destination "$client/forge.jar"
$vanilla = Get-ChildItem (Join-Path $cache 'caches/voldeloom') -Filter 'minecraft-1.6.4-client-*.jar' |
    Where-Object { $_.Name -match '^minecraft-1\.6\.4-client-[a-f0-9]+\.jar$' } | Select-Object -First 1
if ((Get-FileHash $vanilla.FullName -Algorithm SHA1).Hash.ToLowerInvariant() -ne $manifest.downloads.client.sha1) {
    throw 'Original Minecraft client checksum mismatch'
}
Copy-Item -LiteralPath $vanilla.FullName -Destination "$client/minecraft.jar"
$classpath = @("$client/forge.jar", "$client/minecraft.jar")
foreach ($library in $profile.versionInfo.libraries) {
    if ($library.name -like 'net.minecraftforge:*' -or $library.natives) { continue }
    $allowed = !$library.rules
    foreach ($rule in $library.rules) {
        if (!$rule.os -or ($rule.os.name -eq 'windows' -and (!$rule.os.version -or [Environment]::OSVersion.VersionString -match $rule.os.version))) {
            $allowed = $rule.action -eq 'allow'
        }
    }
    if (!$allowed) { continue }
    $parts = $library.name.Split(':')
    $relative = $parts[0].Replace('.', '/') + '/' + $parts[1] + '/' + $parts[2] + '/' + $parts[1] + '-' + $parts[2] + '.jar'
    $target = Join-Path "$client/libraries" $relative
    New-Item -ItemType Directory -Force (Split-Path $target -Parent) | Out-Null
    $installed = Join-Path "$installation/libraries" $relative
    if (Test-Path $installed) { Copy-Item -LiteralPath $installed -Destination $target }
    elseif (!(Test-Path $target)) {
        $baseUrl = if ($library.url) { $library.url } else { 'https://libraries.minecraft.net/' }
        Invoke-WebRequest ($baseUrl.TrimEnd('/') + '/' + $relative) -OutFile $target
    }
    $official = $manifest.libraries | Where-Object name -eq $library.name | Select-Object -First 1
    $sha1 = (Get-FileHash $target -Algorithm SHA1).Hash.ToLowerInvariant()
    if ($official.downloads.artifact.sha1 -and $sha1 -ne $official.downloads.artifact.sha1) { throw "Library checksum mismatch: $($library.name)" }
    if ($library.checksums -and $sha1 -notin $library.checksums) { throw "Forge library checksum mismatch: $($library.name)" }
    $classpath += $target
}
$nativeDir = Get-ChildItem (Join-Path $cache 'caches/voldeloom/natives') -Directory -Filter '1.6.4-*' | Select-Object -First 1
Get-ChildItem $nativeDir.FullName -Recurse -Filter '*.dll' | Copy-Item -Destination "$client/natives"
$assets = Join-Path $cache 'caches/voldeloom/assets/legacy/legacy'
if (!(Test-Path $assets)) { throw 'Run the development client asset preparation first' }
[ordered]@{
    classpath = $classpath -join ';'
    natives = "$client/natives"
    gameDirectory = $client
    assets = $assets
    mainClass = $profile.versionInfo.mainClass
    releaseSha256 = (Get-FileHash "$client/mods/baseline-0.1.0.jar" -Algorithm SHA256).Hash.ToLowerInvariant()
    minecraftSha256 = (Get-FileHash "$client/minecraft.jar" -Algorithm SHA256).Hash.ToLowerInvariant()
    forgeSha256 = (Get-FileHash "$client/forge.jar" -Algorithm SHA256).Hash.ToLowerInvariant()
} | ConvertTo-Json | Set-Content "$client/launch.json"
Write-Output "Prepared original Forge client in $client"
