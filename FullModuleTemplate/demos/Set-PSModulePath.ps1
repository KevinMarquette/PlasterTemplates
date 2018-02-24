function Set-PSModulePath 
{
    param([string]$Path)

    $Path = Resolve-Path $Path
    $originalPath = Get-Item -Path Env:\PSModulePath | Select-Object -Exp Value
    $psModulePaths = $originalPath -split ';' | Where-Object {$_ -ne $Path}
    $revisedPath = ( @($Path) + @($psModulePaths) | Select-Object -Unique ) -join ';'
    Set-Item -Path Env:\PSModulePath -Value $revisedPath  -EA Stop
}