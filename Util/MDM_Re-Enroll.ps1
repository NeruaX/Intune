#Get Enrollment Path for previous enrollments
$EnrollmentsPath = "HKLM:\SOFTWARE\Microsoft\Enrollments\"
$Enrollments = Get-ChildItem -Path $EnrollmentsPath
Foreach ($Enrollment in $Enrollments) {
      $EnrollmentObject = Get-ItemProperty Registry::$Enrollment
      #If Microsoft Enrollment (Intune)
      if ($EnrollmentObject."DiscoveryServiceFullURL" -eq "https://wip.mam.manage.microsoft.com/enroll") {
            #Remove All previous enrollments
            $EnrollmentPath = $EnrollmentsPath + $EnrollmentObject."PSChildName"
            Remove-Item -Path $EnrollmentPath -Recurse

            #Set keys to enroll with account that is azure joining the system
            cmd.exe /c "REG ADD HKLM\Software\Policies\Microsoft\Windows\CurrentVersion\MDM /V AutoEnrollMDM /t REG_DWORD /d 1 /f"
            cmd.exe /c "REG ADD HKLM\Software\Policies\Microsoft\Windows\CurrentVersion\MDM /V UseAADCredentialType /t REG_DWORD /d 1 /f"
            cmd.exe /c "REG ADD HKLM\Software\Policies\Microsoft\Windows\CurrentVersion\MDM /V MDMApplicationId /t REG_SZ /f"

            #Try to enroll
            "C:\Windows\System32\deviceenroller.exe /c /AutoEnrollMDM"

            #May require restart to push. Possibly just signing out and back in
    }
}
