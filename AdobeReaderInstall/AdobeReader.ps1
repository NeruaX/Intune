Import-module Microsoft.PowerShell.Management
Import-Module Microsoft.PowerShell.Utility

<#
    #####################
    #       Notes       #
    ##################### 
    Some parts are not necesary or over complicated but allows for template deploy with minimal changes for next script.
    
    Creates paths as needed for install
    Checks for current version of adobe online
    Downloads current version
    Runs silent install

    This can be ran as a script or wraped into a .intunewin file

    Download can take a few minutes and is about 0.3 to 0.5 GB in size.
    Have noticed computer staggering during install

    win32 wrap
        Install as: system
        Install Command: powershell.exe -ExecutionPolicy Bypass -NoLogo -noninteractive -File AdobeReader.ps1
        Detection: File
            File Path: C:\Program Files\Adobe\Acrobat DC\Acrobat
            File: Acrobat.exe
            File or folder exists
    NOTE: this only detects 64 bit. 
    32 bit uses C:\Program Files (x86)\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe
    
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
$Arguments = "/sAll /slf /re /msi EULA_ACCEPT=YES"
$32BitOverride = $false

#No Config Below This Point Needed

#Check 64 Bit Script
#$env:PROCESSOR_ARCHITEW6432 Returns AMD64 on 32 bit Powershell and blank on 64 bit if system is 64bit
if($env:PROCESSOR_ARCHITEW6432-eq "AMD64") {
    #Run PS command from 64 bit powershell. on 32 bit powershell sysnative returns path
    &"$ENV:WINDIR\SysNative\WindowsPowershell\v1.0\PowerShell.exe" -File $PSCOMMANDPATH
    #Exit after re-running full script in 64 bit subset
    Exit
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

#Checks current version from adobe. Currently checks windows 11 which should also work for windows 10
$VersionURL = "https://rdc.adobe.io/reader/products?lang=mui&site=enterprise&os=Windows%2011&preInstalled=&country=US&nativeOs=Windows%2010&api_key=dc-get-adobereader-cdn"
$Response = Invoke-WebRequest -Uri $VersionURL -Method Get
$Data = (ConvertFrom-Json $Response).products.reader

#Detects OS 64 bit or 32 bit to configure and provide correct URL
$OSArchitecture = (Get-WmiObject Win32_OperatingSystem).OSArchitecture
if(($OSArchitecture -eq "64-bit") -and (-not($32BitOverride)) ) {
    $Versiondata = $Data -cmatch "64bit"
    $Version = ($Versiondata.version).Replace(".","")
    $DownloadURL = "https://ardownload2.adobe.com/pub/adobe/acrobat/win/AcrobatDC/$($Version)/AcroRdrDCx64$($Version)_MUI.exe"  
    $Installer = "AcroRdrDCx64$($Version)_MUI.exe" 
} else {
    $Versiondata = $Data -cmatch "32bit"
    $Version = ($Versiondata.version).Replace(".","")
    $DownloadURL = "https://ardownload2.adobe.com/pub/adobe/reader/win/AcrobatDC/$($Version)/AcroRdrDC$($Version)_MUI.exe"
    $Installer = "AcroRdrDC$($Version)_MUI.exe"
}

#Download current installer
Invoke-WebRequest -Uri $DownloadURL -OutFile $Path$Installer 

#Run installer with aguments
Start-Process -filepath $Path$Installer -argumentlist $Arguments -Wait

#Cleanup
Remove-Item $Path$Installer

#C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe
