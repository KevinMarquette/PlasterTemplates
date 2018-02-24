$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

$currentDirectory = $args[0]

. "$PSScriptRoot\Set-PSModulePath.ps1"

# cache module dependencies and build module
$buildCachePath = Join-Path $PSScriptRoot '..\_build-cache'
$outputPath = Join-Path $PSScriptRoot '..\output'
if (-not(Test-Path $buildCachePath) -or -not(Test-Path $outputPath)) 
{
    Set-Location "$PSScriptRoot\..\"
    & .\build.ps1 'build'
}

# allow PS to see dependencies our module needs from the cache
Set-PSModulePath $buildCachePath

# import module from compiled output code
$moduleName = '<%= $PLASTER_PARAM_ModuleName %>'
$modulePath = Join-Path $outputPath $moduleName -Resolve
Import-Module $modulePath -EA Stop

Set-Location $currentDirectory

# show that module loaded into PS session
Get-Module -Name $moduleName