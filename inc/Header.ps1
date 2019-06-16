
# turn on informational messages
$InformationPreference = 'Continue'

# load localized language
Import-LocalizedData -BindingVariable 'Messages' -FileName 'Messages' -BaseDirectory (Join-Path $ScriptPath 'lang')

# load the config
if ( Test-Path "$ScriptPath\DefaultConfig.psd1" ) {

    # configuration parameters
    # we have to add it in the loader script so that it's available to the dot sourced files
    $ConfigSplat = @{
        Name        = $ModuleName
        CompanyName = 'Brooksworks'
        DefaultPath = "$ScriptPath\DefaultConfig.psd1"
    }

    # create config variable
    # we have to add it in the loader script so that it's available to the dot sourced files
    $Config = Import-Configuration @ConfigSplat

}

# import cached data
if ( Test-Path "$ScriptPath\data\*.json" ) {

    $Data = @{}
    Get-ChildItem -Path "$ScriptPath\data" -Filter '*.json' |
        ForEach-Object { $Data.($_.BaseName) = Get-Content $_.FullName | ConvertFrom-Json }

}
