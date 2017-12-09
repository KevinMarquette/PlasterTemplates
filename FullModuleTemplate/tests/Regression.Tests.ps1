Describe "Regression tests" -Tag Build {

    BeforeAll {
        Get-Module ($env:BHProjectName) -All | Remove-Module
        Import-Module ($global:SUTPath)
    }

    Context "Github Issues" {
       
    }
}