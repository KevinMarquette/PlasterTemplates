$moduleName = $env:BHProjectName

Describe "Help tests for $moduleName" -Tags Build {

    BeforeAll {
        Unload-SUT
        Import-Module ($global:SUTPath)
    }

    AfterAll {
        Unload-SUT
    }

    $functions = Get-Command -Module $moduleName
    $help = $functions | % {Get-Help $_.name}
    foreach ($node in $help)
    {
        Context $node.name {

            it "has a description" {
                $node.description | Should Not BeNullOrEmpty
            }
            it "has an example" {
                $node.examples | Should Not BeNullOrEmpty
            }
            foreach ($parameter in $node.parameters.parameter)
            {
                if ($parameter -notmatch 'whatif|confirm')
                {
                    it "parameter $($parameter.name) has a description" {
                        $parameter.Description.text | Should Not BeNullOrEmpty
                    }
                }
            }
        }
    }
}
