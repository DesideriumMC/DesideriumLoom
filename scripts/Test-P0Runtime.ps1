param(
    [Parameter(Mandatory = $true)][string]$Log,
    [Parameter(Mandatory = $true)][ValidateSet('DevelopmentClient','DevelopmentServer','ProductionClient','ProductionServer')][string]$Mode
)
$ErrorActionPreference = 'Stop'
$content = Get-Content -LiteralPath $Log -Raw
if ($content -match 'Unable to launch|Encountered an unexpected exception|A critical problem occurred') { throw "Runtime failure in $Log" }
if ($content -notmatch '\[DESIDERIUM-P0\] initialized; diamond item ID=264') { throw 'Missing observable baseline mod marker' }
if ($Mode -like '*Server' -and $content -notmatch 'Done \([0-9.,]+s\)!') { throw 'Dedicated server did not reach world-ready state' }
if ($Mode -like '*Client' -and $content -notmatch 'logged in with entity id') { throw 'Client did not enter a world' }
if ($Mode -like 'Development*' -and $content -notmatch 'deobfuscated environment') { throw 'Expected development environment was not identified' }
if ($Mode -like 'Production*' -and $content -match 'deobfuscated environment') { throw 'Production test incorrectly used a development game JAR' }
Write-Output "$Mode verified: mod marker and world-ready evidence present."
