param(
    [string]$MixinVersion = '0.8.7',
    [string]$BootstrapJar,
    [string]$ProbeJar
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (!$BootstrapJar) { $BootstrapJar = Join-Path $root "runtime/mixin-bootstrap/build/libs/desiderium-mixin-bootstrap-$MixinVersion-0.1.0-p1.jar" }
if (!$ProbeJar) { $ProbeJar = Join-Path $root 'samples/mixin-probe/build/libs/mixin-probe-0.1.0-p1.jar' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead((Resolve-Path $BootstrapJar))
try {
    $names = @($zip.Entries.FullName)
    if (@($names | Where-Object { $_ -match '^(org/objectweb/asm|com/google/common|com/google/gson|org/apache/logging/log4j)/.*\.class$' }).Count) {
        throw 'Unrelocated runtime dependencies would collide with Forge'
    }
    $bridge = @($zip.Entries | Where-Object FullName -eq 'org/spongepowered/asm/bridge/RemapperAdapterFML.class')
    if ($bridge.Count -ne 1) { throw 'Expected exactly one FML bridge class' }
    $stream = $bridge[0].Open()
    $memory = New-Object IO.MemoryStream
    try { $stream.CopyTo($memory); $bytes = $memory.ToArray() } finally { $stream.Dispose(); $memory.Dispose() }
    if ([Text.Encoding]::ASCII.GetString($bytes) -notmatch 'isolated FML remapper bridge installed') { throw 'Official ASM cast bridge was not replaced' }
    foreach ($required in @('META-INF/LICENSE-Mixin.txt', 'dev/desiderium/internal/asm/ClassReader.class', 'dev/desiderium/internal/log4j/core/Logger.class')) {
        if ($names -notcontains $required) { throw "Missing bootstrap entry: $required" }
    }
} finally { $zip.Dispose() }
$zip = [IO.Compression.ZipFile]::OpenRead((Resolve-Path $ProbeJar))
try {
    if (!$zip.GetEntry('mixins.desiderium.p1.json')) { throw 'Missing probe Mixin config' }
    foreach ($entry in $zip.Entries | Where-Object FullName -like '*.class') {
        $stream = $entry.Open()
        try {
            $header = New-Object byte[] 8
            if ($stream.Read($header, 0, 8) -ne 8) { throw "Truncated class: $($entry.FullName)" }
            $major = [int]$header[6] * 256 + $header[7]
            if ($major -ne 50) { throw "Probe must remain Java 6: $($entry.FullName), major=$major" }
        } finally { $stream.Dispose() }
    }
} finally { $zip.Dispose() }
Get-FileHash $BootstrapJar,$ProbeJar -Algorithm SHA256 | Select-Object Path,Hash
Write-Output 'P1 artifact isolation, bridge replacement, config and probe bytecode checks passed.'
