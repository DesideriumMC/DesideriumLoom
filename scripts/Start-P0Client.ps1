param(
    [Parameter(Mandatory = $true)][string]$GameJdk,
    [string]$ClientDirectory = '.work/production-client'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$client = if ([IO.Path]::IsPathRooted($ClientDirectory)) { $ClientDirectory } else { Join-Path $root $ClientDirectory }
$launch = Get-Content "$client/launch.json" -Raw | ConvertFrom-Json
$lock = Get-Content (Join-Path $root 'gradle/p0-inputs.lock.json') -Raw | ConvertFrom-Json
foreach ($pair in @(@('minecraft.jar','minecraft-client'), @('forge.jar','forge-1.6.4-9.11.1.1345-universal.jar'))) {
    $expected = ($lock.artifacts | Where-Object name -eq $pair[1]).sha256
    $actual = (Get-FileHash (Join-Path $client $pair[0]) -Algorithm SHA256).Hash.ToLowerInvariant()
    if (!$expected -or $actual -ne $expected) { throw "Original game input checksum mismatch: $($pair[0])" }
}
$modHash = (Get-FileHash "$client/mods/baseline-0.1.0.jar" -Algorithm SHA256).Hash.ToLowerInvariant()
if ($modHash -ne $launch.releaseSha256) { throw 'Release mod changed after client preparation' }
$java = Join-Path $GameJdk 'bin/java.exe'
Push-Location $client
try {
    # Modern Java 8 disables the original 2013 JAR signature algorithm. Verify
    # the immutable game inputs above, then use FML's process-local legacy option.
    & $java '-Xmx1G' '-Dfml.ignoreInvalidMinecraftCertificates=true' "-Djava.library.path=$($launch.natives)" '-cp' $launch.classpath $launch.mainClass '--username' 'DesideriumP0' '--session' '0' '--version' '1.6.4-Forge9.11.1.1345' '--gameDir' $launch.gameDirectory '--assetsDir' $launch.assets '--tweakClass' 'cpw.mods.fml.common.launcher.FMLTweaker'
    if ($LASTEXITCODE -ne 0) { throw "Client exited with code $LASTEXITCODE" }
} finally { Pop-Location }
