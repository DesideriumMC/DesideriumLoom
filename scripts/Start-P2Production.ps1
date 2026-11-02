param(
    [Parameter(Mandatory = $true)][string]$GameJdk,
    [Parameter(Mandatory = $true)][string]$Directory
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$target = if ([IO.Path]::IsPathRooted($Directory)) { $Directory } else { Join-Path $root $Directory }
$launch = Get-Content "$target/p2-launch.json" -Raw | ConvertFrom-Json
foreach ($artifact in $launch.artifacts) {
    if ((Get-FileHash (Join-Path $target $artifact.name)).Hash.ToLowerInvariant() -ne $artifact.sha256) { throw "Frozen P2 artifact changed: $($artifact.name)" }
}
if ((Get-Content (Join-Path $GameJdk 'release') -Raw) -notmatch 'JAVA_VERSION="1\.8\.') { throw 'P2 requires Java 8' }
$java = Join-Path $GameJdk 'bin/java.exe'
Push-Location $target
try {
    if ($launch.side -eq 'Server') {
        & $java '-Xmx1G' '-jar' 'minecraftforge-universal-1.6.4-9.11.1.1345.jar' 'nogui'
    } else {
        & $java '-Xmx1G' '-Dfml.ignoreInvalidMinecraftCertificates=true' "-Djava.library.path=$($launch.natives)" '-cp' $launch.classpath $launch.mainClass '--username' 'DesideriumP2' '--session' '0' '--version' '1.6.4-Forge9.11.1.1345' '--gameDir' $target '--assetsDir' $launch.assets '--tweakClass' 'cpw.mods.fml.common.launcher.FMLTweaker'
    }
    if ($LASTEXITCODE -ne 0) { throw "P2 game exited with code $LASTEXITCODE" }
} finally { Pop-Location }

