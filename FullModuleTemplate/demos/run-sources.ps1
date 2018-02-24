$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

$currentDirectory = $args[0]

. "$PSScriptRoot\Set-PSModulePath.ps1"

# cache module dependencies
$buildCachePath = Join-Path $PSScriptRoot '..\_build-cache'
if (-not(Test-Path $buildCachePath)) 
{
    Set-Location "$PSScriptRoot\..\"
    & .\build.ps1 'init'
}

# allow PS to see dependencies our module needs from the cache
Set-PSModulePath $buildCachePath

# import module from source code
$moduleName = '<%= $PLASTER_PARAM_ModuleName %>'
$modulePath = Join-Path $PSScriptRoot "..\$moduleName" -Resolve
Import-Module $modulePath -EA Stop

Set-Location $currentDirectory

# show that module loaded into PS session
Get-Module -Name $moduleName