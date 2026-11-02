param([Parameter(Mandatory=$true)][string]$Log, [ValidateSet('Server','Client')][string]$Side)
$ErrorActionPreference = 'Stop'
$text = Get-Content -LiteralPath $Log -Raw
foreach ($marker in @('PASS Accessor', 'PASS Invoker descriptor', 'PASS Inject Redirect Shadow', 'PASS Overwrite extra mapping', 'PASS Inherited member', 'ALL MEMBER CHECKS PASSED')) {
    if (!$text.Contains("[DESIDERIUM-P2] $marker")) { throw "Missing P2 marker: $marker" }
}
if ($text -match 'MixinApplyError|MixinTransformerError|InvalidMixinException|InjectionError|NoSuchMethodError|NoSuchFieldError|DuplicateModsFoundException|\[DESIDERIUM-P2\] FAILED') { throw 'P2 runtime failure detected' }
if ($Side -eq 'Server' -and $text -notmatch 'Done \(') { throw 'Server did not become ready' }
Write-Output "P2 $Side member checks passed: $Log"
