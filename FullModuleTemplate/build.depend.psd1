@{ 
    PSDependOptions  = @{ 
        Target    = '$DependencyPath/_build-cache/'
        AddToPath = $true
    }
    InvokeBuild      = '4.1.0'
    PSDeploy         = '0.2.2'
    BuildHelpers     = '0.0.53'
    PSScriptAnalyzer = '1.16.1'
    Pester           = @{
        Version = '4.1.0'
    }
}