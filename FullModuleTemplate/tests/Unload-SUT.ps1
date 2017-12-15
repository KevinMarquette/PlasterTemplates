function global:Unload-SUT
{
    $modulesToUnload = @(Get-Dependency -Path "$PSScriptRoot\..\test.depend.psd1" |
            Where-Object DependencyType -eq PSGalleryModule | 
            Select-Object -Exp DependencyName)
    $modulesToUnload += $env:BHProjectName
    $modulesToUnload | Get-Module -All | Remove-Module -Force -EA Ignore
}