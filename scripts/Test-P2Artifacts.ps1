param(
    [string]$ProbeJar = 'samples/mixin-mapping-probe/build/libs/mixin-mapping-probe-0.1.0-p2.jar',
    [string]$Javap = 'javap'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$path = if ([IO.Path]::IsPathRooted($ProbeJar)) { $ProbeJar } else { Join-Path $root $ProbeJar }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($path)
try {
    $entry = $zip.GetEntry('mixins.desiderium.p2.refmap.json')
    if (!$entry) { throw 'Missing generated P2 refmap' }
    $reader = [IO.StreamReader]::new($entry.Open())
    try { $refmap = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
    $stack = $refmap.data.searge.'dev/desiderium/mappingprobe/mixin/StackProbe'
    if ($stack.'getMaxStackSize()I' -ne 'Lnet/minecraft/item/ItemStack;func_77976_d()I') { throw 'Incorrect Inject refmap' }
    if ($stack.'Lnet/minecraft/item/ItemStack;getItem()Lnet/minecraft/item/Item;' -ne 'Lnet/minecraft/item/ItemStack;func_77973_b()Lnet/minecraft/item/Item;') { throw 'Incorrect Redirect descriptor refmap' }
    $access = $refmap.data.searge.'dev/desiderium/mappingprobe/mixin/StackAccess'
    if ($access.itemID -ne 'field_77993_c:I' -or $access.getItem -ne 'func_77973_b()Lnet/minecraft/item/Item;') { throw 'Incorrect Accessor/Invoker refmap' }
    foreach ($entry in $zip.Entries | Where-Object FullName -like '*.class') {
        $stream = $entry.Open()
        try {
            $header = New-Object byte[] 8
            if ($stream.Read($header,0,8) -ne 8 -or ($header[6]*256+$header[7]) -ne 50) { throw "Not Java 6: $($entry.FullName)" }
        } finally { $stream.Dispose() }
    }
    if ($zip.Entries.FullName -match '^org/spongepowered/') { throw 'Probe bundles shared runtime' }
} finally { $zip.Dispose() }
$bytecode = (& $Javap -p -classpath $path dev.desiderium.mappingprobe.mixin.StackProbe) -join "`n"
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect P2 release members with javap' }
foreach ($member in @('field_77993_c', 'func_77976_d', 'func_77985_e')) {
    if (!$bytecode.Contains($member)) { throw "Unmapped release Shadow/Overwrite: $member" }
}
Write-Output "P2 refmap and Java 6 archive checks passed: $path"
