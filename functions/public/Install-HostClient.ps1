<#
.SYNOPSIS
    Attempts to install ScreenConnect Host Client on a remote machine.
.PARAMETER Computer
    Computer(s) to attempt to install.
.PARAMETER Credential
    PSCredential object to use for authentication.
.PARAMETER Username
    The plaintext username to use for authentication. Defaults to 'Administrator'.
.PARAMETER Password
    The plaintext password to use for authentication.
.OUTPUTS
    No output.
#>
function Install-HostClient {

    [CmdletBinding(SupportsShouldProcess)]
    param(

        [parameter(Mandatory=$true, Position=1, ValueFromPipeline=$True)]
        [string[]]
        $Computer,

        [Parameter(Mandatory=$true, Position=2)]
        [ValidatePattern('(?# must be an EXE or MSI )\.(exe|msi)$')]
        [string]
        $Installer,

        [pscredential]
        $Credential = [pscredential]::Empty

    )

    begin {

        if ( $PSBoundParameters.Keys -notcontains 'InformationAction' ) {

            $InformationPreference = 'Continue'

        }

        if ( $PSBoundParameters.Keys -notcontains 'ErrorAction' ) {
            
            $ErrorActionPreference = 'Stop'

        }

        Get-Command -Name PsExec.exe > $null

        $CredentialSplat = @{}
        if ( $Credential -ne [pscredential]::Empty ) { $CredentialSplat.Credential = $Credential }

        $InstallerPath =  Resolve-Path $Installer |
            Get-Item

        $ScheduledTaskSplat = switch ( $InstallerPath.Extension ) {

            '.exe' {@{
                Execute          = Join-Path 'C:\_ScreenConnectDeployment' $InstallerPath.Name
                WorkingDirectory = 'C:\_ScreenConnectDeployment'
            }}

            '.msi' {@{
                Execute          = 'C:\Windows\System32\msiexec.exe'
                Argument         = '/i {0} /qn' -f ( Join-Path 'C:\_ScreenConnectDeployment' $InstallerPath.Name )
                WorkingDirectory = 'C:\_ScreenConnectDeployment'
            }}
        }

    }

    process {

        foreach ( $ComputerItem in $Computer ) {

            if ( -not( Test-HostConnection $ComputerItem ) ) { continue }

            Write-Verbose ( $Messages.MappingTemporaryDriveVerboseMessage -f "\\$ComputerItem\C$" )

            New-PSDrive -Name 'RemoteComputer' -PSProvider FileSystem -Root "\\$ComputerItem\C$" @CredentialSplat > $null

            if ( -not( Test-Path -Path 'RemoteComputer:\_ScreenConnectDeployment' ) ) {

                Write-Verbose ( $Messages.CreatingDeploymentDirectoryVerboseMessage -f 'C:\_ScreenConnectDeployment' )

                New-Item 'RemoteComputer:\_ScreenConnectDeployment' -ItemType Directory > $null

            }

            Write-Verbose $Messages.PushingInstallerFileVerboseMessage

            Copy-Item -Path $InstallerPath -Destination 'RemoteComputer:\_ScreenConnectDeployment\' -Force

            Write-Information ( $Messages.InvokingScreenConnectInstallerMessage -f $ComputerItem )

            New-RemoteScheduledTask @ScheduledTaskSplat -ComputerName $ComputerItem @CredentialSplat -Wait

            Write-Verbose ( $Messages.RemovingDeploymentDirectoryVerboseMessage -f 'C:\_ScreenConnectDeployment' )

            Remove-Item 'RemoteComputer:\_ScreenConnectDeployment' -Recurse -Confirm:$false -ErrorAction Continue

            Write-Verbose $Messages.UnMappingTemporaryDriveVerboseMessage

            Remove-PSDrive -Name 'RemoteComputer'

            Write-Information $Messages.InstallationFinishedMessage

        }

    }

}
