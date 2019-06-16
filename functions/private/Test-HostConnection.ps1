<#
.SYNOPSIS
 Utility function to check if host is online.
#>
function Test-HostConnection {

    [CmdletBinding()]
    param(

        [string]
        $ComputerName

    )

    if ( $PSBoundParameters.Keys -notcontains 'ErrorAction' ) {

        $ErrorActionPreference = 'Stop'

    }

    Write-Verbose ( $Messages.CheckingHostConnectionVerboseMessage -f $ComputerName )

    # verify computer is responding

    if ( -not( Test-Connection -ComputerName $ComputerName -Count 1 -Quiet ) ) {

        Write-Error ( $Messages.HostConnectionFailedError -f $ComputerName )

        return $false

    }
    
    # check that port 445 is open

    $Socket= New-Object Net.Sockets.TcpClient
    $IAsyncResult= [IAsyncResult] $Socket.BeginConnect( $ComputerName, 445, $null, $null )
    $IAsyncResult.AsyncWaitHandle.WaitOne( 500, $true ) > $null
    $PortOpen = $Socket.Connected
    $Socket.close()

    if ( -not $PortOpen ) {

        Write-Error ( $Messages.HostPortConnectionFailedError -f $ComputerName )

        return $false

    }
    
    
    return $true

}
