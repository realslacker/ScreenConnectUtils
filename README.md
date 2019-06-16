# ScreenConnectUtils
Utilities for connecting and installing ConnectWise Control (formerly ScreenConnect)

## Installing from PSGallery

```PowerShell
PS C:\> Install-Module -Name ScreenConnectUtils -Repository PSGallery
```

## Pushing ScreenConnect Host Client to Remote Machine

You must have a local copy of the Host Client installer downloaded, either the EXE or MSI installer will work. The installation uses SMB to copy the installer to the remote machine, then schedules an immediate task to perform the installation locally.

Example:

```PowerShell
PS C:\> $Installer = Get-Item C:\Users\Example\Downloads\ConnectWiseControl.ClientSetup.exe
PS C:\> Install-ScreenConnectHostClient -Computer RemoteMachine -Installer $Installer -Credential (Get-Credential RemoteMachine\Administrator)
Installing ScreenConnect on remote computer 'RemoteMachine'...
Installation Finished
PS C:\> _
```

## Creating and Connecting to a Support Session

Sometimes you may want create a support session from PowerShell. If your ConnectWise instance has the [Guest Session Starter](https://docs.connectwise.com/ConnectWise_Control_Documentation/Supported_extensions/Productivity/Guest_Session_Starter) enabled you can use this module to start a session. Note that if you have the ScreenConnect binaries downloaded already you can avoid downloading them again by using the -ScreenConnectPath option.

```PowerShell
PS C:\> Connect-ScreenConnectSupportSession -ScreenConnectUri https://yourhost.screenconnect.com/ -SessionName 'Test Session'
```

## Language Support

This module makes use of Data Localization. If you would like to submit translations please create a pull request that includes a language subfolder and .psd1 file.

