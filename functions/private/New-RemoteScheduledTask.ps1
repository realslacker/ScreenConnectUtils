function New-RemoteScheduledTask {

    param(

        [Parameter(Mandatory)]
        [string]
        $Execute,

        [string]
        $Argument,

        [string]
        $WorkingDirectory,

        [string]
        $TaskName = ( 'Deployment Task ({0}) - {1}' -f $env:USERNAME, (Get-Date -f 'yyyyMMddHHmmss') ),
    
        [Parameter(Mandatory)]
        [string]
        $ComputerName,

        [pscredential]
        $Credential,

        [switch]
        $Wait

    )

    $CredentialSplat = @{}
    if ( $Credential ) { $CredentialSplat.Credential = $Credential }

    $TaskActionSplat = @{}
    $TaskActionSplat.Execute = $Execute
    if ( $Argument ) { $TaskActionSplat.Argument = $Argument }
    if ( $WorkingDirectory ) { $TaskActionSplat.WorkingDirectory = $WorkingDirectory }

    $TaskStart = (Get-Date).AddSeconds(5)
    
    $TaskSplat = @{
        Action      = New-ScheduledTaskAction @TaskActionSplat
        Trigger     = New-ScheduledTaskTrigger -Once -At $TaskStart
        Description = 'Task created by PowerShell'
        Settings    = New-ScheduledTaskSettingsSet -RunOnlyIfNetworkAvailable -StartWhenAvailable -DeleteExpiredTaskAfter 5
        Principal   = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    }
    $Task = New-ScheduledTask @TaskSplat |
        %{ $_.Triggers[0].EndBoundary = $TaskStart.ToUniversalTime().AddSeconds(5).ToString('u').Replace(' ', 'T'); $_ }

    Invoke-Command -ComputerName $ComputerName @CredentialSplat -ScriptBlock {

        $Using:Task | Register-ScheduledTask -TaskName $Using:TaskName | %{

            Write-Verbose ( $Using:Messages.RegisteredScheduledTaskVerboseMessage -f $Using:TaskName, $env:COMPUTERNAME )

        }

        if ( $Using:Wait ) {

            Start-Sleep -Seconds 5

            while ( Get-ScheduledTask -TaskName $Using:TaskName -ErrorAction SilentlyContinue ) {

                for ( $i = 10; $i -ge 0; $i -- ) {

                    Write-Progress -Activity $Using:Messages.WaitingForScheduledTaskCompletionProgressActivity -Status ( $Using:Messages.WaitingForScheduledTaskCompletionProgressStatus -f $Using:TaskName ) -PercentComplete ( ( 10 - $i ) / 10 * 100 )

                    Start-Sleep -Seconds 1
                
                }
            
            }

        }

    }

}