param(
    [string]$CacheDirectory = '.work/gradle-home',
    [switch]$IncludeBuildDependencies
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$lock = Get-Content (Join-Path $projectRoot 'gradle/p0-inputs.lock.json') -Raw | ConvertFrom-Json
$cache = if ([IO.Path]::IsPathRooted($CacheDirectory)) { $CacheDirectory } else { Join-Path $projectRoot $CacheDirectory }
foreach ($artifact in $lock.artifacts) {
    if ($artifact.name -like 'minecraft-*') {
        $side = $artifact.name.Substring('minecraft-'.Length)
        $files = @(Get-ChildItem (Join-Path $cache 'caches/voldeloom') -File -Filter "minecraft-1.6.4-$side-*.jar" |
            Where-Object { $_.Name -match "^minecraft-1\.6\.4-$side-[a-f0-9]+\.jar$" })
    } else {
        $files = @(Get-ChildItem (Join-Path $cache 'caches/modules-2/files-2.1/net.minecraftforge/forge/1.6.4-9.11.1.1345') -Recurse -File -Filter $artifact.name)
    }
    if ($files.Count -eq 0) { throw "Missing $($artifact.name). Origin: $($artifact.url); expected SHA-256: $($artifact.sha256)" }
    foreach ($file in $files) {
        $actual = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -ne $artifact.sha256) { throw "Checksum mismatch: $($file.FullName). Origin: $($artifact.url); expected $($artifact.sha256), got $actual" }
    }
    Write-Output "Verified $($artifact.name)"
}
if ($IncludeBuildDependencies) {
    $dependencies = Get-Content (Join-Path $projectRoot 'gradle/p0-dependencies.lock.json') -Raw | ConvertFrom-Json
    foreach ($dependency in $dependencies.files) {
        $coordinatePath = $dependency.coordinate.Replace(':', '/')
        $directory = Join-Path $cache "caches/modules-2/files-2.1/$coordinatePath"
        $files = @(Get-ChildItem $directory -Recurse -File -Filter $dependency.file)
        if ($files.Count -eq 0) { throw "Missing pinned dependency: $($dependency.coordinate)/$($dependency.file)" }
        foreach ($file in $files) {
            if ((Get-FileHash $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant() -ne $dependency.sha256) {
                throw "Dependency checksum mismatch: $($file.FullName)"
            }
        }
    }
    Write-Output "Verified $($dependencies.files.Count) pinned build dependency files"
}
