param(
    [Parameter(Mandatory = $true)][string]$GameJdk,
    [string]$InstallationDirectory = '.work/production'
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root = Split-Path $PSScriptRoot -Parent
$destination = if ([IO.Path]::IsPathRooted($InstallationDirectory)) { $InstallationDirectory } else { Join-Path $root $InstallationDirectory }
$lock = Get-Content (Join-Path $root 'gradle/p0-inputs.lock.json') -Raw | ConvertFrom-Json
New-Item -ItemType Directory -Force $destination,(Join-Path $destination 'mods') | Out-Null
$installer = Join-Path $destination 'forge-installer.jar'
if (!(Test-Path $installer)) { Invoke-WebRequest $lock.forgeInstaller.url -OutFile $installer }
if ((Get-FileHash $installer -Algorithm SHA256).Hash.ToLowerInvariant() -ne $lock.forgeInstaller.sha256) {
    throw "Installer checksum mismatch. Origin: $($lock.forgeInstaller.url); expected: $($lock.forgeInstaller.sha256)"
}
Push-Location $destination
try {
    & (Join-Path $GameJdk 'bin/java.exe') -jar $installer --installServer
    if ($LASTEXITCODE -ne 0) { throw "Forge installer failed: $LASTEXITCODE" }
} finally { Pop-Location }
$zip = [IO.Compression.ZipFile]::OpenRead($installer)
try {
    $reader = [IO.StreamReader]::new($zip.GetEntry('install_profile.json').Open())
    try { $reader.ReadToEnd() | Set-Content (Join-Path $destination 'install_profile.json') }
    finally { $reader.Dispose() }
} finally { $zip.Dispose() }
foreach ($pair in @(@('minecraft_server.1.6.4.jar','minecraft-server'), @('minecraftforge-universal-1.6.4-9.11.1.1345.jar','forge-1.6.4-9.11.1.1345-universal.jar'))) {
    $expected = ($lock.artifacts | Where-Object name -eq $pair[1]).sha256
    if ((Get-FileHash (Join-Path $destination $pair[0]) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected) {
        throw "Installed original game input checksum mismatch: $($pair[0])"
    }
}
Write-Output "Verified original Forge installation at $destination"
