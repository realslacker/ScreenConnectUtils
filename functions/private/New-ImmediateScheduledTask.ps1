<#
.SYNOPSIS
 Creates an Immediate Scheduled Task

.PARAMETER ComputerName
 The computer(s) for the task to be executed.
 
.PARAMETER TaskName
 The name of the task.
 
 Note: Can not be a duplicate name

.PARAMETER Description
 The description for the task.

.PARAMETER Command
 The main command to execute.

.PARAMETER ArgumentList
 The list of parameters to pass to the executable.
 
 Note: A single parameter will not be modified, however
 if an array of parameters is passed any parameter
 containing a space will be wrapped in double quotes.

.PARAMETER WorkingDirectory
 The working directory for the task if applicable.
 
 Note: This variable is interpereted on the local machine.
 
.PARAMETER Credential
 The credential to use when creating the task.
 
.PARAMETER Wait
 Wait for the task to complete before continuing.

#>
function New-ImmediateScheduledTask {

    [CmdletBinding()]
    param(
    
        [string[]]
        $ComputerName,

        [Parameter(Mandatory)]
        [string]
        $TaskName,

        [string]
        $Description,

        [Parameter(Mandatory)]
        [string]
        $Command,

        [string[]]
        $ArgumentList,

        [string]
        $WorkingDirectory,

        [pscredential]
        $Credential,

        [switch]
        $Wait

    )

    # immediate task template
    $TaskXmlTemplate = @'
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Date>2019-09-11T15:07:41.203317</Date>
    <Author>METHODE\sgraybrook</Author>
    <URI>\Test Task</URI>
  </RegistrationInfo>
  <Triggers>
    <RegistrationTrigger>
      <EndBoundary>2020-09-11T15:10:31</EndBoundary>
      <Enabled>true</Enabled>
    </RegistrationTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>S-1-5-18</UserId>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>true</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>true</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>true</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT72H</ExecutionTimeLimit>
    <DeleteExpiredTaskAfter>PT1M</DeleteExpiredTaskAfter>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command></Command>
    </Exec>
  </Actions>
</Task>
'@

    # parse the arguments
    # if there is only one argument we pass as is
    # otherwise we wrap arguments with spaces in double quotes and join together
    $Arguments = if ( $ArgumentList.Count -eq 1 ) {
        
        $ArgumentList[0].Trim()

    } elseif ( $ArgumentList.Count -gt 1 ) {

        ( $Arguments | % Trim | %{ if ( $_.IndexOf(' ') -ne -1 ) { '"{0}"' -f $_ } else { $_ } } ) -join ' '

    }
    
    # set the parameters
    $ParamSplat = @{}
    if ( $Credential ) { $ParamSplat.Credential = $Credential }
    if ( $ComputerName ) { $ParamSplat.ComputerName = $ComputerName }

    # register the task
    Invoke-Command @ParamSplat -ScriptBlock {

        param([xml]$TaskXml, [string]$TaskName, [string]$Description, [string]$Command, [string]$Arguments, [string]$WorkingDirectory, [bool]$Wait)

        # set the task name
        $TaskXml.Task.RegistrationInfo.URI = '\' + $TaskName

        # set the description or remove it
        if ( -not [string]::IsNullOrEmpty( $Description ) ) {

            $DescriptionNode = $TaskXml.CreateElement('Description', $TaskXml.DocumentElement.NamespaceURI)
            $DescriptionNode.InnerText = $Description
            [void]$TaskXml.Task.RegistrationInfo.AppendChild( $DescriptionNode )

        }
    
        # set the author to the executing user
        $TaskXml.Task.RegistrationInfo.Author = $env:USERDOMAIN, $env:USERNAME -join '\'
    
        # registration time is now
        $TaskXml.Task.RegistrationInfo.Date = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffffff')
    
        # set trigger to expire in one minute
        $TaskXml.Task.Triggers.RegistrationTrigger.EndBoundary = (Get-Date).AddMinutes(1).ToString('yyyy-MM-ddTHH:mm:ss')
    
        # task executable
        $TaskXml.Task.Actions.Exec.Command = $Command
    
        # task arguments
        if ( -not [string]::IsNullOrEmpty( $Arguments ) ) {

            $ArgumentsNode = $TaskXml.CreateElement('Arguments', $TaskXml.DocumentElement.NamespaceURI)
            $ArgumentsNode.InnerText = $Arguments
            [void]$TaskXml.Task.Actions.Exec.AppendChild($ArgumentsNode)

        }

        # set the working directory
        if ( -not [string]::IsNullOrEmpty( $WorkingDirectory ) ) {
            
            $WorkingDirectoryNode = $TaskXml.CreateElement('WorkingDirectory', $TaskXml.DocumentElement.NamespaceURI)
            $WorkingDirectoryNode.InnerText = $WorkingDirectory
            [void]$TaskXml.Task.Actions.Exec.AppendChild( $WorkingDirectoryNode )

        }

        # create the temporary task xml file
        $TempXmlPath = Join-Path $env:TEMP 'ImmediateTaskDefinition.xml'
        Set-Content -Path $TempXmlPath -Value $TaskXml.InnerXml -Encoding Unicode -Force -Confirm:$false

        # schedule the task
        if ( (Start-Process -FilePath 'schtasks.exe' -ArgumentList "/Create /XML ""$TempXmlPath"" /tn ""$TaskName""" -Wait -PassThru).ExitCode -eq 0 ) {

            Write-Host ( 'Task ''{0}'' was scheduled successfully on computer {1}' -f $TaskName, $env:COMPUTERNAME )

            # should we wait?
            if ( $Wait ) {

                Start-Sleep -Seconds 5

                while ( (Start-Process -FilePath 'schtasks.exe' -ArgumentList "/Query /tn ""$TaskName""" -Wait -PassThru).ExitCode -eq 0 ) {

                
                    Write-Host ( 'Waiting for task ''{0}'' to finish on {1}' -f $TaskName, $env:COMPUTERNAME )

                    Start-Sleep -Seconds 5
            
                }

            }

        } else {

            Write-Error ( 'Failed to create task ''{0}'' on computer {1}' -f $TaskName, $env:COMPUTERNAME )

        }

    } -ArgumentList $TaskXmlTemplate, $TaskName, $Description, $Command, $Arguments, $WorkingDirectory, $Wait.IsPresent

}
