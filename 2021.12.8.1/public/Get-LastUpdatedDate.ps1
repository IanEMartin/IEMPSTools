<#
.SYNOPSIS
    .
.DESCRIPTION
    Gets the Last Logon Info for the users of a computer.
.PARAMETER System
    Specifies a single
.PARAMETER File
    Specifies a file with a list of systems
.EXAMPLE
    C:\PS> Get-LastUpdatedDate.ps1 -system sys1
    Gets the information for sys1
.NOTES
    Author: Ian Martin
    Date:   2013-11-12
#>
function Get-LastUpdatedDate {
  [CmdletBinding()]
  param (
    [Parameter(ValueFromPipeline = $true)]
    [string[]]$system,
    [string]$file
  )

  If ($file -ne '') {
    Write-Verbose $LogInfo
    $ListofMachines = (Get-Content $file) | Sort-Object
  } ElseIf ($null -ne $system) {
    $LogInfo = 'System(s) provided: ' + $system
    Write-Verbose $LogInfo
    $ListofMachines = $system | Sort-Object
  } ELse {
    Exit
  }

  Foreach ($Computer in $ListofMachines) {
    $Updates = Get-CimInstance -Class win32_quickfixengineering -ComputerName $Computer | Select-Object -Property @{Name = "InstalledOn"; Expression = {([DateTime]($_.InstalledOn))}} | Sort-Object InstalledOn | Select-Object -Last 1
    If ($null -ne $Updates) {
      $SystemLastUpdated = New-Object PSObject -Property @{
        Computer  = $Computer.ToUpper()
        UpdatedOn = (get-date $Updates.InstalledOn -uformat '%Y-%m-%d')
      }
      $SystemLastUpdated = $SystemLastUpdated | Select-Object Computer, UpdatedOn
      $SystemLastUpdated
    }
  }
}
