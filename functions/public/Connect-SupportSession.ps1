<# 
.DESCRIPTION 
 Connect to a ScreenConnect remote support session from PowerShell. Note that
 you must have the Guest Session starter extension enabled.

 See: https://docs.connectwise.com/ConnectWise_Control_Documentation/Supported_extensions/Productivity/Guest_Session_Starter
 
.PARAMETER ScreenConnectUri
 URI for ScreenConnect instance
 
.PARAMETER SessionName
 What should your session be named
 
.PARAMETER ScreenConnectPath
 Path to ScreenConnect files
#>
function Connect-SupportSession {

    param(

        [Parameter(Mandatory=$true)]
        [ValidatePattern('(?# must include http/https )^https?://.+')]
        [ValidateNotNullOrEmpty()]
        [string]
        $ScreenConnectUri,

        [ValidateNotNullOrEmpty()]
        [string]
        $SessionName = "PowerShell Session - $env:COMPUTERNAME",

        [ValidateNotNullOrEmpty()]
        [string]
        $ScreenConnectPath = ( Join-Path $env:TEMP 'ScreenConnectClient' )

    )

    $ErrorActionPreference = 'Stop'

    if ( $PSVersionTable.PSVersion.Major -lt 3 ) {

        throw 'Minimum supported version of PowerShell is 3.0'

    }

    $ScreenConnectPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ScreenConnectPath)

    if ( -not( Test-Path -Path $ScreenConnectPath -PathType Container ) ) {

        New-Item -Path $ScreenConnectPath -ItemType Directory -Force > $null

    }

    $ConnectionParams = @{
        y = 'Guest'
        h = $null
        p = $null
        s = $null
        k = $null
        i = $SessionName
    }

    $InvokeWebRequestSplat = @{
        Uri             = '{0}/Script.ashx' -f $ScreenConnectUri.Trim('/')
        UseBasicParsing = $true
    }
    $ScreenConnectJS = Invoke-WebRequest @InvokeWebRequestSplat

    if ( $ScreenConnectJS.RawContent -match '"h":"(?<h>[^"]+)","p":(?<p>\d+),"k":"(?<k>[^"]+)"' ) {

        $ConnectionParams.h = $Matches.h
        $ConnectionParams.p = $Matches.p
        $ConnectionParams.k = [uri]::EscapeDataString($Matches.k)

    } else {

        Write-Error 'Could not parse connection params!'

    }

    $InvokeRestMethodSplat = @{
        Method      = 'Post'
        Uri         = '{0}/App_Extensions/2d4e908b-8471-431d-b4e0-2390f43bfe67/Service.ashx/CreateGuestSupportSession' -f $ScreenConnectUri.Trim('/')
        Body        = (ConvertTo-Json @($SessionName) -Compress)
        ContentType = 'application/json'
    }
    $ConnectionParams.s = Invoke-RestMethod @InvokeRestMethodSplat

    $ScreenConnectArguments = ( $ConnectionParams.Keys | %{ '{0}={1}' -f $_, $ConnectionParams.$_ } ) -join '&' -replace '^', '"?' -replace '$', '"'

    $ScreenConnectExe = Join-Path $ScreenConnectPath 'ScreenConnect.WindowsClient.exe'

    if ( -not (Test-Path -Path $ScreenConnectExe ) ) {

        $URIs = @(
            '{0}/Bin/ConnectWiseControl.ClientBootstrap.jnlp{1}' -f $ScreenConnectUri.Trim('/'), $ScreenConnectArguments.Trim('"')
            '{0}/Bin/ScreenConnect.Client.exe.jar' -f $ScreenConnectUri.Trim('/')
        )

        $URIs |
            ForEach-Object {@{ Uri = $_ ; OutFile = Join-Path $ScreenConnectPath ( Split-Path -Path ( $_ -replace '\?.*' ) -Leaf ) }} |
            ForEach-Object { Invoke-WebRequest @_ }

        Add-Type -Assembly System.IO.Compression.Filesystem

        [System.IO.Compression.ZipFile]::ExtractToDirectory( "$ScreenConnectPath\ScreenConnect.Client.exe.jar", "$ScreenConnectPath" )

        Expand-JnlpAttachments -Path "$ScreenConnectPath\ConnectWiseControl.ClientBootstrap.jnlp"
    
    }

    if ( Test-Path -Path $ScreenConnectExe ) {

        Start-Process -FilePath $ScreenConnectExe -ArgumentList $ScreenConnectArguments

    } else {

        Write-Error 'Could not locate ScreenConnect.WindowsClient.exe'

    }

}
