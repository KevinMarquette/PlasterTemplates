$script:ModuleName = $ENV:BHProjectName

$script:Source = Join-Path $BuildRoot $ModuleName
$script:Output = Join-Path $BuildRoot output
$script:Destination = Join-Path $Output $ModuleName
$script:ModulePath = "$Destination\$ModuleName.psm1"
$script:ManifestPath = "$Destination\$ModuleName.psd1"
$script:Imports = ( 'private', 'public', 'classes' )
$script:TestFile = "$PSScriptRoot\output\TestResults_PS$PSVersion`_$TimeStamp.xml"
$global:SUTPath = $script:ManifestPath

Task Init SetAsLocal, InstallSUT
Task Default Build, Pester, Publish
Task Build InstallSUT, CopyToOutput, BuildPSM1, BuildPSD1
Task Pester Build, UnitTests, FullTests

function CalculateFingerprint {
    param(
        [Parameter(ValueFromPipeline)]
        [System.Management.Automation.FunctionInfo[]] $CommandList
    )

    process {
        $fingerprint = foreach ($command in $CommandList )
        {
            foreach ($parameter in $command.parameters.keys)
            {
                '{0}:{1}' -f $command.name, $command.parameters[$parameter].Name
                $command.parameters[$parameter].aliases | Foreach-Object { '{0}:{1}' -f $command.name, $_}
            }
        }
        $fingerprint
    }
}
function PublishTestResults
{
    param(
        [string]$Path
    )
    if ($ENV:BHBuildSystem -eq 'Unknown')
    {
        return
    }
    Write-Output "Publishing test result file"
    switch ($ENV:BHBuildSystem)
    {
        'AppVeyor'
        { 
            (New-Object 'System.Net.WebClient').UploadFile(
                "https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)",
                $Path )
        }
        'VSTS'
        {
            # Skip; publish logic defined as task in vsts build config (see .vsts-ci.yml)
        }
        Default
        {
            Write-Warning "Publish test result not implemented for build system '$($ENV:BHBuildSystem)'"
        }
    }
}

function Read-Module {
    param (
        [Parameter(Mandatory)]
        [string] $Name,
        [Parameter(Mandatory)]
        [string] $Repository, 
        [Parameter(Mandatory)]
        [string] $Path)
            
    $reader = {
        param (
            [string] $Name,
            [string] $Repository, 
            [string] $Path)
        try {
            
            # we need to ensure $Path is one of the locations that PS will look when resolving
            # dependencies of the module it is being asked to import
            $originalPath = Get-Item -Path Env:\PSModulePath | Select -Exp Value
            $psModulePaths = $originalPath -split ';' | Where {$_ -ne $Path}
            $revisedPath = ( @($Path) + @($psModulePaths) | Select -Unique ) -join ';'
            Set-Item -Path Env:\PSModulePath -Value $revisedPath  -EA Stop

            try {
                Save-Module -Name $Name -Path $Path -Repository $Repository -EA Stop
                Import-Module "$Path\$Name" -PassThru -EA Stop
            }
            finally {
                Set-Item -Path Env:\PSModulePath -Value $originalPath -EA Stop
            }               
        }
        catch {
            if ($_ -match "No match was found for the specified search criteria") {
                @()
            }
            else {
                $_
            }
        }
    }

    $params = @{
        Name       = $Name
        Repository = $Repository
        Path       = $Path
    }

    # Create a runspace and run our $reader script to return the module requested
    # The purpose of using a runspace is to avoid loading old/duplicate versions of modules
    # into the current PS session and thus avoid any potential conflicts
    $PowerShell = [Powershell]::Create()
    [void]$PowerShell.AddScript($reader).AddParameters($params)

    # return module
    $PowerShell.Invoke()
}

Task InstallSUT {
    Invoke-PSDepend -Path "$PSScriptRoot\test.depend.psd1" -Install -Force
}

Task SetAsLocal {
    # ensure source code rather than compiled code in the output directory is being debugged / tested
    $global:SUTPath = $env:BHPSModuleManifest
}

Task Clean {
    $null = Remove-Item $Output -Recurse -ErrorAction Ignore
    $null = New-Item  -Type Directory -Path $Destination
}

Task UnitTests {
    $TestResults = Invoke-Pester -Path Tests\*unit* -PassThru -Tag Build -ExcludeTag Slow
    if ($TestResults.FailedCount -gt 0)
    {
        Write-Error "Failed [$($TestResults.FailedCount)] Pester tests"
    }
}

Task FullTests {
    $TestResults = Invoke-Pester -Path Tests -PassThru -OutputFormat NUnitXml -OutputFile $testFile -Tag Build

    PublishTestResults $testFile
    
    if ($TestResults.FailedCount -gt 0)
    {
        Write-Error "Failed [$($TestResults.FailedCount)] Pester tests"
    }
}

Task Specification {
    
    $TestResults = Invoke-Gherkin $PSScriptRoot\Spec -PassThru
    if ($TestResults.FailedCount -gt 0)
    {
        Write-Error "[$($TestResults.FailedCount)] specification are incomplete"
    }
}

Task CopyToOutput {

    Write-Output "  Create Directory [$Destination]"
    $null = New-Item -Type Directory -Path $Destination -ErrorAction Ignore

    Get-ChildItem $source -File | 
        where name -NotMatch "$ModuleName\.ps[dm]1" | 
        Copy-Item -Destination $Destination -Force -PassThru | 
        ForEach-Object { "  Create [.{0}]" -f $_.fullname.replace($PSScriptRoot, '')}

    Get-ChildItem $source -Directory | 
        where name -NotIn $imports | 
        Copy-Item -Destination $Destination -Recurse -Force -PassThru | 
        ForEach-Object { "  Create [.{0}]" -f $_.fullname.replace($PSScriptRoot, '')}
}

Task BuildPSM1 -Inputs (Get-Item "$source\*\*.ps1") -Outputs $ModulePath {

    [System.Text.StringBuilder]$stringbuilder = [System.Text.StringBuilder]::new()    
    foreach ($folder in $imports )
    {
        [void]$stringbuilder.AppendLine( "Write-Verbose 'Importing from [$Source\$folder]'" )
        if (Test-Path "$source\$folder")
        {
            $fileList = Get-ChildItem "$source\$folder\*.ps1" | Where Name -NotLike '*.Tests.ps1'
            foreach ($file in $fileList)
            {
                $shortName = $file.fullname.replace($PSScriptRoot, '')
                Write-Output "  Importing [.$shortName]"
                [void]$stringbuilder.AppendLine( "# .$shortName" ) 
                [void]$stringbuilder.AppendLine( [System.IO.File]::ReadAllText($file.fullname) )
            }
        }
    }
    
    Write-Output "  Creating module [$ModulePath]"
    Set-Content -Path  $ModulePath -Value $stringbuilder.ToString() 
}

Task PublishedModuleInfo -if (-Not ( Test-Path "$output\previous-module-info.xml" ) ) -Before BuildPSD1 {
    $downloadPath = "$output\previous-vs"
    if (-not(Test-Path $downloadPath)) {
        New-Item $downloadPath -ItemType Directory | Out-Null
    }

    $previousModule = Read-Module -Name $ModuleName -Repository ($env:PublishRepository) -Path $downloadPath

    if ($null -ne $previousModule -and $previousModule.GetType() -eq [System.Management.Automation.ErrorRecord])
    {
        Write-Error $previousModule
        return
    }

    $moduleInfo = if ($null -eq $previousModule) 
    {
        [PsCustomObject] @{
            Version = [System.Version]::new(0, 0, 1)
            Fingerprint = @()
        }
    }
    else 
    {
        [PsCustomObject] @{
            Version = $previousModule.Version
            Fingerprint = $previousModule.ExportedFunctions.Values | CalculateFingerprint
        }
    }
    $moduleInfo | Export-Clixml -Path "$output\previous-module-info.xml"
}

Task BuildPSD1 -inputs (Get-ChildItem $Source -Recurse -File) -Outputs $ManifestPath {
    
    Write-Output "  Update [$ManifestPath]"
    Copy-Item "$source\$ModuleName.psd1" -Destination $ManifestPath
 
 
    $functions = Get-ChildItem "$ModuleName\Public\*.ps1" | Where-Object { $_.name -notmatch 'Tests'} | Select-Object -ExpandProperty basename      
    Set-ModuleFunctions -Name $ManifestPath -FunctionsToExport $functions

    Set-ModuleAliases -Name $ManifestPath

    $previousModuleInfo = Import-Clixml -Path "$output\previous-module-info.xml"
 
    Write-Output "  Detecting semantic versioning"
 
    # avoid error trying to load a module twice
    Unload-SUT
    $commandList = (Import-Module ".\$ModuleName" -PassThru).ExportedFunctions.Values
    # cleanup PS session
    Unload-SUT
 
    Write-Output "    Calculating fingerprint"
    $fingerprint = $commandList | CalculateFingerprint
     
    $oldFingerprint = $previousModuleInfo.Fingerprint
     
    $bumpVersionType = 'Patch'
    '    Detecting new features'
    $fingerprint | Where {$_ -notin $oldFingerprint } | % {$bumpVersionType = 'Minor'; "      $_"}    
    '    Detecting breaking changes'
    $oldFingerprint | Where {$_ -notin $fingerprint } | % {$bumpVersionType = 'Major'; "      $_"}
 
    # Bump the module version
    $version = [version] (Get-Metadata -Path $manifestPath -PropertyName 'ModuleVersion')

    if ( $version -lt ([version]'1.0.0') )
    {
        '    Still in beta, don''t bump major version'
        if ( $bumpVersionType -eq 'Major'  )
        {
            $bumpVersionType = 'Minor'
        }
        else 
        {
            $bumpVersionType = 'Patch'
        }       
    }

    $publishedVersion = $previousModuleInfo.Version
    if ( $version -lt $publishedVersion )
    {
        $version = $publishedVersion
    }
    if ($version -eq $publishedVersion)
    {
        Write-Output "  Stepping [$bumpVersionType] version [$version]"
        $version = [version] (Step-Version $version -Type $bumpVersionType)
        Write-Output "  Using version: $version"
        Update-Metadata -Path $ManifestPath -PropertyName ModuleVersion -Value $version
    }
    else 
    {
        Write-Output "  Using version from $ModuleName.psd1: $version"
    }
} 

Task UpdateSource {
    Copy-Item $ManifestPath -Destination "$source\$ModuleName.psd1"
}

Task Publish {
    # Gate deployment
    if (
        $ENV:BHBuildSystem -ne 'Unknown' -and 
        $ENV:BHBranchName -eq "master" -and 
        $ENV:BHCommitMessage -match '!deploy'
    )
    {
        $Params = @{
            Path  = $BuildRoot
            Force = $true
        }

        Invoke-PSDeploy @Verbose @Params
    }
    else
    {
        "Skipping deployment: To deploy, ensure that...`n" + 
        "`t* You are in a known build system (Current: $ENV:BHBuildSystem)`n" + 
        "`t* You are committing to the master branch (Current: $ENV:BHBranchName) `n" + 
        "`t* Your commit message includes !deploy (Current: $ENV:BHCommitMessage)"
    }
}