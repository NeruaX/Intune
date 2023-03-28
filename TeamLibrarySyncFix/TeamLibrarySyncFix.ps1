Import-module Microsoft.PowerShell.Management
Import-Module Microsoft.PowerShell.Utility
Import-Module ScheduledTasks

<#
    #####################
    #       Notes       #
    ##################### 
    Some parts are not necesary or over complicated but allows for template deploy with minimal changes for next script.
    
    create task to trigger at log in or unlock of any user to call file 2 as user. Admin Locked task. 
    creates user task to trigger at user log in or unlock to update registry key.
    Uses VBS files to stay silent as user to avoid powershell pop up at login.
    Section for 32bit to 64bit change may not be needed.
    Files Admin change only
    Version key for Win32 wrap detection / file updates on update if script only
    
    This can be ran as a script or wraped into a .intunewin file
    
    win32 wrap
        Install as: system
        Install Command: powershell.exe -ExecutionPolicy Bypass -NoLogo -noninteractive -File TeamLibrarySyncFix.ps1
        Detection: Registry
            Key Path: HKLM\SOFTWARE\Intune\TeamLibrarySyncFix
            Value Name: Version
            String Comparison
            Equals
            Value: <version number below>
    
    #####################
    #       TODO        #
    ##################### 
    Add additional failure checks
        Task does not create
        Task with same name exists 
            Replace instead of skip?
    Restart Onedrive after reg change so works on initial push 
        possible diruption but should be minimal
    Test 64bit switch required
    Implement intune return codes
    Implement Event Viewer logging
#>

#File / policy Name
$Name = "TeamLibrarySyncFix"
$Version = "1.4.0.1"

#Setup
$Path = $env:HOMEDRIVE + "\ProgramData\Intune\"
$RegPath = 'HKLM:\SOFTWARE\Intune\'

#No Config Below This Point Needed

#Check 64 Bit Script
#$env:PROCESSOR_ARCHITEW6432 Returns AMD64 on 32 bit Powershell and blank on 64 bit if system is 64bit
if($env:PROCESSOR_ARCHITEW6432-eq "AMD64") {
    #Run PS command from 64 bit powershell. on 32 bit powershell sysnative returns path
    &"$ENV:WINDIR\SysNative\WindowsPowershell\v1.0\PowerShell.exe" -File $PSCOMMANDPATH
    #Exit after re-running full script in 64 bit subset
    Exit
}

$AdminFile = "$($Path)$($Name).ps1"
$UserFile = "$($Path)$($Name)User.ps1"
$AdminTaskFile = "$($Path)$($Name).vbs"
$UserTaskFile = "$($Path)$($Name)User.vbs"
$Install = $true

#Creates path if not already there
if(-not(Test-Path -PathType Container $Path)) {
    #Save file to location
    New-Item -ItemType Directory -Force -Path $Path
    #Sets Folder to Hidden
    $Folder= Get-Item -Path $Path -Force
    $Folder.Attributes="Hidden"
}

#Checks for Version already installed
$RegExist = Test-Path $RegPath$Name
if($RegExist) {
    #Get Current Registry values
    $CurReg = Get-ItemProperty -Path $RegPath$Name
    $CurVersion = $CurReg.Version
    #Compare Versions
    if($CurVersion -lt $Version) {
        #Remove old files
        if(Test-Path -PathType Leaf $AdminFile) {
            Remove-Item -Path $AdminFile -Force
            Start-Sleep -Seconds 3
        }
        if(Test-Path -PathType Leaf $UserFile) {
            Remove-Item -Path $UserFile -Force
            Start-Sleep -Seconds 3
        }
        if(Test-Path -PathType Leaf $AdminTaskFile) {
            Remove-Item -Path $AdminTaskFile -Force
            Start-Sleep -Seconds 3
        }
        if(Test-Path -PathType Leaf $UserTaskFile) {
            Remove-Item -Path $UserTaskFile -Force
            Start-Sleep -Seconds 3
        }
        #Remove old key
        Remove-ItemProperty -Path $RegPath$Name -Name 'Version'
    } else {
        #Version is greater
        #Check if file exists
        if((Test-Path -PathType Leaf $AdminFile) -and (Test-Path -PathType Leaf $UserFile) -and (Test-Path -PathType Leaf $AdminTaskFile) -and (Test-Path -PathType Leaf $UserTaskFile)) {
            $Install = $false
        } else {
            #File was deleted. Re-add file
            $Install = $true
        }
    }
} else {
    #Registry does not exist
    #Create Registry Path
    New-Item -Path $RegPath$Name -Force | Out-Null
}

if($Install) {
    #Remove potential Files
    if(Test-Path -PathType Leaf $AdminFile) {
        Remove-Item -Path $AdminFile -Force
        Start-Sleep -Seconds 3
    }
    if(Test-Path -PathType Leaf $UserFile) {
        Remove-Item -Path $UserFile -Force
        Start-Sleep -Seconds 3
    }
        if(Test-Path -PathType Leaf $AdminTaskFile) {
        Remove-Item -Path $AdminTaskFile -Force
        Start-Sleep -Seconds 3
    }
    if(Test-Path -PathType Leaf $UserTaskFile) {
        Remove-Item -Path $UserTaskFile -Force
        Start-Sleep -Seconds 3
    }
#Create User Script
'
Import-module Microsoft.PowerShell.Management

#Updates key that checks for team sync changes to 1 for pushing check
$Key = "Timerautomount"
$Value = "1"
$RegPath = "HKCU:\Software\Microsoft\OneDrive\Accounts\Business1"

#Update path if found
if((Test-Path $RegPath)){
    New-ItemProperty -Path $RegPath -Name $Key -Value $Value -PropertyType "QWORD" -Force | Out-Null
}
'.Trim() | Out-File -FilePath $UserFile
#End User Script

#Create Admin Script
'
Import-module Microsoft.PowerShell.Management
Import-Module ScheduledTasks

$Name = "'+$Name+'"

#Create Task to run at sign in
$User = "$($env:USERDOMAIN)\$($env:USERNAME)"
$TaskName = "$($Name)_$($User.Replace("\",''''))"
$TaskExist = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

If(-not($TaskExist)) {
    $TaskPath = "Intune"
    $Action = New-ScheduledTaskAction -Execute "'+$UserTaskFile+'"
    $LogonTrigger = New-ScheduledTaskTrigger -AtLogOn -User $User
    $TriggerCim = Get-CimClass -Namespace ROOT\Microsoft\Windows\TaskScheduler -ClassName MSFT_TaskSessionStateChangeTrigger
    $UnlockTrigger = New-CimInstance -CimClass $TriggerCim -Property @{StateChange = 8; UserId = $User} -ClientOnly
    $Settings = New-ScheduledTaskSettingsSet -DontStopIfGoingOnBatteries -DontStopOnIdleEnd -AllowStartIfOnBatteries -Hidden

    Register-ScheduledTask -Action $Action -Trigger @($LogonTrigger; $UnlockTrigger) -TaskPath $TaskPath -TaskName $TaskName -Settings $Settings | Out-Null
    Start-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName | Out-Null
} 
else {
    #Task Already Exists
}
'.Trim() | Out-File -FilePath $AdminFile
#End Admin Script

#Create Admin Task Script
'
Dim shell,command
command = "powershell.exe -WindowStyle Hidden -NonInteractive -ExecutionPolicy Bypass -NoLogo -file '+$AdminFile+'"
Set shell = CreateObject("WScript.Shell")
shell.Run command,0
'.Trim() | Out-File -FilePath $AdminTaskFile
#End Admin Task Script

#Create User Task Script
'
Dim shell,command
command = "powershell.exe -WindowStyle Hidden -NonInteractive -ExecutionPolicy Bypass -NoLogo -file '+$UserFile+'"
Set shell = CreateObject("WScript.Shell")
shell.Run command,0
'.Trim() | Out-File -FilePath $UserTaskFile
#End User Task Script

    #Create Version Key
    New-ItemProperty -Path $RegPath$Name -Name 'Version' -Value $Version -PropertyType String -Force | Out-Null
}

$TaskName = "$($Name)"
$TaskExist = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

If(-not($TaskExist) -or $Install) {
    #Update existing tasks
    if($TaskExist) {
        $Tasks = Get-ScheduledTask -TaskPath "\Intune\"
        Foreach ($Task in $Tasks) {
            #Compare task name
            if($Task.TaskName -match $Name) {
                Unregister-ScheduledTask -TaskPath $Task.TaskPath -TaskName $Task.TaskName -Confirm:$false
            }
        }
    }
    #Create Task to run at any user sign in to create user specific task
    $TaskPath = "Intune"
    $Action = New-ScheduledTaskAction -Execute $AdminTaskFile
    $LogonTrigger = New-ScheduledTaskTrigger -AtLogOn
    $TriggerCim = Get-CimClass -Namespace ROOT\Microsoft\Windows\TaskScheduler -ClassName MSFT_TaskSessionStateChangeTrigger
    $UnlockTrigger = New-CimInstance -CimClass $TriggerCim -Property @{StateChange = 8} -ClientOnly
    $Principal = New-ScheduledTaskPrincipal -GroupID "BUILTIN\Users" -RunLevel Highest
    $Settings = New-ScheduledTaskSettingsSet -DontStopIfGoingOnBatteries -DontStopOnIdleEnd -AllowStartIfOnBatteries -Hidden

    Register-ScheduledTask -Action $Action -Trigger @($LogonTrigger; $UnlockTrigger) -TaskPath $TaskPath -TaskName $Name -Principal $Principal -Settings $Settings | Out-Null
    Start-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName | Out-Null
} 
else {
    #Task Already Exists
}