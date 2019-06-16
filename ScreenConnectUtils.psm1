
# module variables
$ScriptPath = Split-Path (Get-Variable MyInvocation -Scope Script).Value.Mycommand.Definition -Parent
$ModuleName = (Get-Item (Get-Variable MyInvocation -Scope Script).Value.Mycommand.Definition).BaseName

# include module header
. ( Join-Path $ScriptPath 'inc\Header.ps1' )

# dot sourcing functions
'transforms', '3rd_party', 'functions\private', 'functions\public' |
    Foreach-Object { Join-Path $ScriptPath $_ } |
    Where-Object { Test-Path $_ } |
    ForEach-Object { Get-ChildItem -Path $_ -Recurse:( -not( $_ -match '3rd_party' ) ) -Filter '*.ps1' -File } |
    ForEach-Object {

        . $_.FullName
    
        if ( $_.FullName -match 'functions\\(public|private)' ) {
            
            # Find all the functions defined no deeper than the first level deep and export it.
            # This looks ugly but allows us to not keep any uneeded variables from poluting the module.
            ([System.Management.Automation.Language.Parser]::ParseInput((Get-Content -Path $_.FullName -Raw), [ref]$null, [ref]$null)).FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false) |
                ForEach-Object { $ExportModuleMembers += @( , $_.Name ) }

        }

    }


# include module footer
. ( Join-Path $ScriptPath 'inc\Footer.ps1' )