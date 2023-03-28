Import-module Microsoft.PowerShell.Management
Import-Module Microsoft.PowerShell.Utility

<#
    #####################
    #       Notes       #
    ##################### 
    Some parts are not necesary or over complicated but allows for template deploy with minimal changes for next script.
    
    Creates paths as needed for install
    Requests latest msi installer for google chrome
    Runs silent install

    This can be ran as a script or wraped into a .intunewin file

    win32 wrap
        Install as: system
        Install Command: powershell.exe -ExecutionPolicy Bypass -NoLogo -noninteractive -File GoogleChrome.ps1
        Detection: File
            FIle Path: C:\Program Files\Google\Chrome\Application\
            File: Chrome.exe
            File or folder exists
    NOTE: this only detects 64 bit. may be better to use
    C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Google Chrome.lnk
    
    #####################
    #       TODO        #
    ##################### 
    failure checks
    Better detection for win32 wrap
    Test 64bit switch required
    Implement intune return codes
    Implement Event Viewer logging
#>


#Setup
$IntunePath = $env:HOMEDRIVE + "\ProgramData\Intune\"
$Path = $IntunePath+"Temp\"
$Installer = "GoogleChrome.msi"
$Parameters = "/qn /norestart"

#No Config Below This Point Needed

#Check 64 Bit Script
#$env:PROCESSOR_ARCHITEW6432 Returns AMD64 on 32 bit Powershell and blank on 64 bit if system is 64bit
if($env:PROCESSOR_ARCHITEW6432-eq "AMD64") {
    #Run PS command from 64 bit powershell. on 32 bit powershell sysnative returns path
    &"$ENV:WINDIR\SysNative\WindowsPowershell\v1.0\PowerShell.exe" -File $PSCOMMANDPATH
    #Exit after re-running full script in 64 bit subset
    Exit
}

$64URL = "http://dl.google.com/edgedl/chrome/install/GoogleChromeStandaloneEnterprise64.msi"
$32URL = "http://dl.google.com/edgedl/chrome/install/GoogleChromeStandaloneEnterprise.msi"

#Detets OS 64 bit or 32 bit to provide correct URL
$OSArchitecture = (Get-WmiObject Win32_OperatingSystem).OSArchitecture
if($OSArchitecture -eq "64-bit") {
    $URL = $64URL
} else {
    $URL = $32URL
}

#Creates path if not already there
if(-not(Test-Path -PathType Container $IntunePath)) {
    #Save file to location
    New-Item -item Directory -Force -Path $IntunePath
    #Sets Folder to Hidden
    $Folder= Get-Item -Path $IntunePath -Force
    $Folder.Attributes="Hidden"
}

#Creates path if not already there
if(-not(Test-Path -PathType Container $Path)) {
    #Save file to location
    New-Item -item Directory -Force -Path $Path
    #Sets Folder to Hidden
    $Folder= Get-Item -Path $Path -Force
    $Folder.Attributes="Hidden"
}

#Downloads from given URL
Invoke-WebRequest -Uri $URL -OutFile $Path$Installer 

#Runs installer with parameters
$Arguments = "/i $Path$Installer "+$Parameters
Start-Process -filepath msiexec -argumentlist $Arguments -Wait

#Cleanup
Remove-Item $Path$Installer