param(
    [string[]]$Tasks = @(':loader-probe:build', ':loader-probe:exportLoaderLaunches'),
    [string]$LoaderDirectory = '../DesideriumLoader/.work/l1/build',
    [string]$BuildJdk = 'C:/Program Files/Eclipse Adoptium/jdk-17.0.20.8-hotspot',
    [string]$CompileJdk = '',
    [string]$GameJdk = 'C:/Program Files/Eclipse Adoptium/jdk-8.0.492.9-hotspot'
)
$root = Split-Path $PSScriptRoot -Parent
if (!$CompileJdk) { $CompileJdk = Join-Path $root '.work/jdks/jdk-11.0.32.1+1' }
$loader = [IO.Path]::GetFullPath((Join-Path $root $LoaderDirectory))
& "$PSScriptRoot/Invoke-P0.ps1" -BuildJdk $BuildJdk -CompileJdk $CompileJdk -GameJdk $GameJdk -Tasks (@("-PdesideriumLoaderDir=$loader") + $Tasks)
