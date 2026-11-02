param(
    [Parameter(Mandatory = $true)][string]$Log,
    [Parameter(Mandatory = $true)][ValidateSet('Server','Client')][string]$Side
)
$ErrorActionPreference = 'Stop'
$text = Get-Content -LiteralPath $Log -Raw
foreach ($marker in @('[DESIDERIUM-P1] transformer chain=','[DESIDERIUM-P1] probe mod initialized','[DESIDERIUM-P1] COMMON World constructor injected')) {
    if (!$text.Contains($marker)) { throw "Missing runtime evidence: $marker" }
}
if ($text -match 'MixinApplyError|InvalidMixinException|MixinInitialisationError|ClassCastException|DuplicateModsFoundException|Unrecognized format specifier|failed to read properly') {
    throw 'Runtime log contains a Mixin, isolation or scanner failure'
}
if ($Side -eq 'Server') {
    if ($text.Contains('[DESIDERIUM-P1] CLIENT') -or $text -match 'Attempting to load class net/minecraft/client/.+ for invalid side SERVER') { throw 'Client code contaminated dedicated server' }
    if ($text -notmatch 'Done \([\d.,]+s\)!' -or $text -notmatch 'Stopping server') { throw 'Server did not reach ready and stop normally' }
} else {
    if (!$text.Contains('[DESIDERIUM-P1] CLIENT GuiMainMenu constructor injected')) { throw 'Client-only injection not observed' }
    if ($text -notmatch 'logged in with entity id' -or $text -notmatch 'Saving chunks for level') { throw 'Client world entry and save not observed' }
}
Write-Output "P1 $Side runtime evidence passed: $Log"
