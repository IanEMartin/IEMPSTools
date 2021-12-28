<#
    .SYNOPSIS
    Checks for expired or mismatched cerifitcates in the CurrentUser and LocalMachine Personal Certificate locations
    .DESCRIPTION
    Checks for expired or mismatched cerifitcates in the CurrentUser and LocalMachine Personal Certificate locations.
    Removes any that meet the criteria.  This script must be run on the local system under the user's profile.
    .NOTES
    ===========================================================================
    Created on:   	12/19/2016
    Created by:   	Ian Martin
    Organization: 	Jack Henry and Associates
    ===========================================================================
#>
function Remove-MisMatchedCertificate {
  $hostnotmatch = Get-ChildItem -Path Cert:\LocalMachine\My\ | Where-Object { $_.Subject -notmatch $env:COMPUTERNAME } | Select-Object -Property Thumbprint, Subject, Issuer, NotAfter
  Remove-Item -Path "Cert:\LocalMachine\My\$($hostnotmatch.Thumbprint)"

  $expiredmachinepersonalcert = Get-ChildItem -Path Cert:\LocalMachine\My\ | Where-Object { $_.NotAfter -le (Get-Date).AddDays(-30) } | Select-Object -Property Thumbprint, Subject, Issuer, NotAfter, PSParentPath
  Remove-Item -Path "Cert:\LocalMachine\My\$($expiredmachinepersonalcert.Thumbprint)"

  $expireduserersonalcert = Get-ChildItem -Path Cert:\CurrentUser\My\ | Where-Object { $_.NotAfter -le (Get-Date).AddDays(-30) } | Select-Object -Property Thumbprint, Subject, Issuer, NotAfter, PSParentPath
  Remove-Item -Path "Cert:\CurrentUser\My\$($expireduserersonalcert.Thumbprint)"
}
