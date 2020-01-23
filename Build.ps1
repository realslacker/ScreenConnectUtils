[CmdletBinding(DefaultParameterSetName='None')]
param(

    [Parameter(ParameterSetName='Publish')]
    [switch]
    $Publish
    
)

# module variables
$ScriptPath = Split-Path (Get-Variable MyInvocation -Scope Script).Value.Mycommand.Definition -Parent
$ModuleName = (Get-Item $ScriptPath).BaseName

# create build directory
$BuildNumber = Get-Date -Format 'yy.M.d.Hmm'
$BuildDirectory = New-Item -Path "$ScriptPath\build\$BuildNumber\$ModuleName" -ItemType Directory -ErrorAction Stop

# create module file
$ModuleFile = New-Item -Path "$BuildDirectory\$ModuleName.psm1" -ItemType File

# copy needed module files
"$ModuleName.psd1", 'DefaultConfig.psd1', 'Config.psd1' |
    Foreach-Object { Join-Path $ScriptPath $_ } |
    Where-Object { Test-Path $_ } |
    ForEach-Object { Get-Item $_ } |
    Copy-Item -Destination $BuildDirectory

# copy needed module directories
'lang', 'lib', 'tests', 'data' |
    Foreach-Object { Join-Path $ScriptPath $_ } |
    Where-Object { Test-Path $_ } |
    ForEach-Object { Get-Item $_ } |
    Copy-Item -Destination $BuildDirectory -Recurse

# copy all 3rd_party sub-directories to module
Get-ChildItem -Path "$ScriptPath\3rd_party" -Directory |
    Copy-Item -Destination { "$BuildDirectory\3rd_party\$($_.Name)" } -Recurse

# array for exported functions
$ExportModuleMembers = @()

# add common settings
Add-Content -Path $ModuleFile -Value @'

# module variables
$ScriptPath = Split-Path (Get-Variable MyInvocation -Scope Script).Value.Mycommand.Definition -Parent
$ModuleName = (Get-Item (Get-Variable MyInvocation -Scope Script).Value.Mycommand.Definition).BaseName

'@

# include the module header
Get-Content -Path ( Join-Path $ScriptPath 'inc\Header.ps1' ) |
    Add-Content -Path $ModuleFile
 
# import module functions
'transforms', '3rd_party', 'functions\private', 'functions\public' |
    Foreach-Object { Join-Path $ScriptPath $_ } |
    Where-Object { Test-Path $_ } |
    ForEach-Object { Get-ChildItem -Path $_ -Recurse:( -not( $_.FullName -match '3rd_party' ) ) -Filter '*.ps1' -File } |
    ForEach-Object {
    
        if ( $_.FullName -match 'functions\\public' ) {
            
            # Find all the functions defined no deeper than the first level deep and export it.
            # This looks ugly but allows us to not keep any uneeded variables from poluting the module.
            ([System.Management.Automation.Language.Parser]::ParseInput((Get-Content -Path $_.FullName -Raw), [ref]$null, [ref]$null)).FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false) |
                ForEach-Object { $ExportModuleMembers += @( , $_.Name ) }

        }

        $_

    } |
    Get-Content -Raw |
    Add-Content -Path $ModuleFile

# include the module footer
Get-Content -Path ( Join-Path $ScriptPath 'inc\Footer.ps1' ) | Add-Content -Path $ModuleFile

# update the build version
$ModuleManifestSplat = @{
    Path              = "$BuildDirectory\$ModuleName.psd1"
    ModuleVersion     = $BuildNumber
    FunctionsToExport = $ExportModuleMembers
}
Update-ModuleManifest @ModuleManifestSplat

# sign the scripts
Get-ChildItem -Path $BuildDirectory -Filter '*.psm1' |
    ForEach-Object {

        Add-SignatureToScript -Path $_.FullName

    }

# publish
if ( $Publish ) {

    Publish-Module -Path $BuildDirectory @PSGalleryPublishSplat

}