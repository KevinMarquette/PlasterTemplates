$script:ModuleName = $env:BHProjectName
$moduleRoot = $env:BHModulePath

Describe "PSScriptAnalyzer rule-sets" -Tag Build {

    $Rules = Get-ScriptAnalyzerRule
    $scripts = Get-ChildItem $moduleRoot -Include *.ps1, *.psm1, *.psd1 -Recurse | where fullname -notmatch 'classes'

    foreach ( $Script in $scripts )
    {
        Context "Script '$($script.FullName)'" {
            $results = Invoke-ScriptAnalyzer -Path $script.FullName -includeRule $Rules
            if ($results)
            {
                foreach ($rule in $results)
                {
                    It $rule.RuleName {
                        $message = "{0} Line {1}: {2}" -f $rule.Severity, $rule.Line, $rule.message
                        $message | Should Be ""
                    }

                }
            }
            else
            {
                It "Should not fail any rules" {
                    $results | Should BeNullOrEmpty
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