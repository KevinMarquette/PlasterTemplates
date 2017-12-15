Describe "Regression tests" -Tag Build {

    BeforeAll {
        Unload-SUT
        Import-Module ($global:SUTPath)
    }

    AfterAll {
        Unload-SUT
    }

    Context "Github Issues" {
       
    }
}