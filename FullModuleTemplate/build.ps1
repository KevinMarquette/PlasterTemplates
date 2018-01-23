<#
.Description
Installs and loads all the required modules for the build.
Derived from scripts written by Warren F. (RamblingCookieMonster)
#>

[cmdletbinding()]
param ($Task = 'Default')
if ($Task -eq 'init')
{
    Write-Output "Starting build (init only)"
} 
else 
{
    Write-Output "Starting build"
}

if (-not (Get-PackageProvider | ? Name -eq nuget))
{
    Write-Output "  Install Nuget PS package provider"
    Install-PackageProvider -Name NuGet -Force -Confirm:$false | Out-Null
}

$publishRepository = 'PSGallery'

# Grab nuget bits, install modules, set build variables, start build.
Write-Output "  Install And Import Dependent Modules"
Write-Output "    Build Modules"
$psDependVersion = '0.1.62'
if (-not(Get-InstalledModule PSDepend -RequiredVersion $psDependVersion -EA SilentlyContinue))
{
    Install-Module PSDepend -RequiredVersion $psDependVersion -Force -Scope CurrentUser
}
Import-Module PSDepend -RequiredVersion $psDependVersion
Invoke-PSDepend -Path "$PSScriptRoot\build.depend.psd1" -Install -Import -Force

Write-Output "    SUT Modules"
Invoke-PSDepend -Path "$PSScriptRoot\test.depend.psd1" -Install -Import -Force

if (-not (Get-Item env:\BH*)) 
{
    Set-BuildEnvironment
    Set-Item env:\PublishRepository -Value $publishRepository
}
$global:SUTPath = $env:BHPSModuleManifest
. "$PSScriptRoot\tests\Unload-SUT.ps1"

if ($Task -eq 'init') 
{
    Write-Output "Build succeeded (init only)"
    return
}

Write-Output "  InvokeBuild"
Invoke-Build $Task -Result result
if ($Result.Error)
{
    exit 1
}
else 
{
    exit 0
}
