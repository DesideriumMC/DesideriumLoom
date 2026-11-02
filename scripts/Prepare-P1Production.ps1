param(
    [ValidateSet('Server','Client')][string]$Side,
    [string]$MixinVersion = '0.8.7',
    [string]$Directory
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (!$Directory) { $Directory = ".work/p1/production-$($Side.ToLowerInvariant())-$MixinVersion" }
$target = if ([IO.Path]::IsPathRooted($Directory)) { $Directory } else { Join-Path $root $Directory }
if (Test-Path -LiteralPath $target) { throw "Use a new directory to prevent stale mods or evidence: $target" }
$source = Join-Path $root $(if ($Side -eq 'Client') { '.work/production-client' } else { '.work/production' })
$bootstrap = Join-Path $root "runtime/mixin-bootstrap/build/libs/desiderium-mixin-bootstrap-$MixinVersion-0.1.0-p1.jar"
$probe = Join-Path $root 'samples/mixin-probe/build/libs/mixin-probe-0.1.0-p1.jar'
& "$PSScriptRoot/Test-P1Artifacts.ps1" -MixinVersion $MixinVersion -BootstrapJar $bootstrap -ProbeJar $probe
$lock = Get-Content (Join-Path $root 'gradle/p0-inputs.lock.json') -Raw | ConvertFrom-Json
$forgeName = if ($Side -eq 'Client') { 'forge.jar' } else { 'minecraftforge-universal-1.6.4-9.11.1.1345.jar' }
$gameName = if ($Side -eq 'Client') { 'minecraft.jar' } else { 'minecraft_server.1.6.4.jar' }
$gameKey = if ($Side -eq 'Client') { 'minecraft-client' } else { 'minecraft-server' }
foreach ($pair in @(@($forgeName,'forge-1.6.4-9.11.1.1345-universal.jar'), @($gameName,$gameKey))) {
    $expected = ($lock.artifacts | Where-Object name -eq $pair[1]).sha256
    if (!$expected -or (Get-FileHash (Join-Path $source $pair[0])).Hash.ToLowerInvariant() -ne $expected) { throw "Original game checksum mismatch: $($pair[0])" }
}
New-Item -ItemType Directory -Path $target,"$target/mods" | Out-Null
Copy-Item -LiteralPath "$source/$forgeName","$source/$gameName" -Destination $target
Copy-Item -LiteralPath "$source/libraries" -Destination $target -Recurse
Copy-Item -LiteralPath $bootstrap,$probe -Destination "$target/mods"
$launch = [ordered]@{ side=$Side; mixinVersion=$MixinVersion; directory=$target; artifacts=@() }
foreach ($file in @($forgeName,$gameName,"mods/$(Split-Path $bootstrap -Leaf)","mods/$(Split-Path $probe -Leaf)")) {
    $launch.artifacts += @{ name=$file; sha256=(Get-FileHash "$target/$file").Hash.ToLowerInvariant() }
}
if ($Side -eq 'Client') {
    Copy-Item -LiteralPath "$source/natives" -Destination $target -Recurse
    $p0 = Get-Content "$source/launch.json" -Raw | ConvertFrom-Json
    $launch.classpath = $p0.classpath.Replace($source,$target)
    $launch.natives = "$target/natives"
    $launch.assets = $p0.assets
    $launch.mainClass = $p0.mainClass
} else {
    Set-Content "$target/server.properties" "server-ip=127.0.0.1`nserver-port=25575`nonline-mode=false`nlevel-name=p1-world`nview-distance=3"
}
$launch | ConvertTo-Json -Depth 5 | Set-Content "$target/p1-launch.json"
Write-Output "Prepared P1 $Side installation: $target"
