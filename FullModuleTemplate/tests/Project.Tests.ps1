$script:ModuleName = $env:BHProjectName
$moduleRoot = $env:BHModulePath

Describe "PSScriptAnalyzer rule-sets" -Tag Build {

    $rulesToExclude = @('PSUseToExportFieldsInManifest')
    $Rules = Get-ScriptAnalyzerRule | where RuleName -NotIn $rulesToExclude
    $scripts = Get-ChildItem $moduleRoot -Include *.ps1, *.psm1, *.psd1 -Recurse | where fullname -notmatch 'classes'

    foreach ( $Script in $scripts ) 
    {
        Context "Script '$($script.FullName)'" {

            foreach ( $rule in $rules )
            {
                It "Rule [$rule]" {

                    (Invoke-ScriptAnalyzer -Path $script.FullName -IncludeRule $rule.RuleName ).Count | Should Be 0
                }
            }
        }
    }
}


Describe "General project validation: $moduleName" -Tags Build {

    AfterAll {
        Unload-SUT
    }

    It "Module '$moduleName' can import cleanly" {
        {Import-Module ($global:SUTPath) -force } | Should Not Throw
    }
}