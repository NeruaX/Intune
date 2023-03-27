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

    win32 wrap
        Install as: system
        Install Command: powershell.exe -ExecutionPolicy Bypass -NoLogo -noninteractive -File GoogleChrome.ps1
        Detection: File
            FIle Path: C:\Program Files\Google\Chrome\Application\
            File: Chrome.exe
            File or folder exists
    
    #####################
    #       TODO        #
    ##################### 
    Done as of now
#>


#Setup
$IntunePath = $env:HOMEDRIVE + "\ProgramData\Intune\"
$Path = $IntunePath+"Temp\"
$Installer = "GoogleChrome.msi"
$Parameters = "/qn /norestart"

#Detets OS 64 bit or 32 bit to provide correct URL
$OSArchitecture = (Get-WmiObject Win32_OperatingSystem).OSArchitecture
if($OSArchitecture -eq "64-bit") {
    $URL = "http://dl.google.com/edgedl/chrome/install/GoogleChromeStandaloneEnterprise64.msi"
} else {
    $URL = "http://dl.google.com/edgedl/chrome/install/GoogleChromeStandaloneEnterprise.msi"
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