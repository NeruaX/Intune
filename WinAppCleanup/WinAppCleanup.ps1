Import-module Microsoft.PowerShell.Management
Import-Module Microsoft.PowerShell.Utility

<#
    #####################
    #       Notes       #
    ##################### 
    Some parts are not necesary or over complicated but allows for template deploy with minimal changes for next script.
    
    Download list of apps from repository and attempt to remove them.

    This version only runs once so does not attempt multiple times
    
    #####################
    #       TODO        #
    ##################### 

    Test 64bit switch required
    Implement intune return codes
    Implement Event Viewer logging
#>

$URL = "https://raw.githubusercontent.com/NeruaX/Intune-Scripts/main/Util/RemoveAppList.txt"

#Get list
$AppListData = Invoke-WebRequest -Uri $URL -UseBasicParsing
#Convert list to array list
$AppList = New-Object System.Collections.ArrayList($null)
$AppList.addRange($AppListData -split "`n")
$AppList.RemoveRange(0,3)

#Get currently installed apps
$CurAppArray = Get-AppxProvisionedPackage -Online | Select-Object -ExpandProperty DisplayName
$CurAppArrayAU = Get-AppxProvisionedPackage | Select-Object -ExpandProperty DisplayName

#Iterate apps in remove list
foreach ($App in $AppList) {
    if( ($App -ne $null) -or ($App -ne "") ) {
        #If requested app is installed
        if (($App -in $CurAppArray)) {
            #Attempt removal
            Try {
                Get-AppxPackage -AllUsers -Name $App | Remove-AppPackage -ErrorAction Stop | Out-Null
            } Catch {
                #Write error to ev
            }
        }
        if (($App -in $CurAppArrayAU)) {
            #Attempt removal
            Try {
                Get-AppxProvisionedPackage -Online | Where-Object DisplayName -Like $App | Remove-AppxProvisionedPackage -Online -ErrorAction Stop
            } Catch {
                #Write error to ev
                #Write error to log file
            }
        }
    }
}
