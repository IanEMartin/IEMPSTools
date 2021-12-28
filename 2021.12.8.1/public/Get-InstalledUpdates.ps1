<#
.SYNOPSIS
    .
.DESCRIPTION
    Gets the installed updates of a computer.
.PARAMETER ComputerName
    Specifies a single
.EXAMPLE
    C:\PS> Get-InstalledUpdates.ps1 -system sys1
    Gets the information for sys1
.NOTES
    Author: Ian Martin
    Date:   2013-11-12
#>
function Get-InstalledUpdates {
  [CmdletBinding()]
  param (
      [Parameter(
          ValueFromPipeline=$true
    )]
    [string[]]$ComputerName
    )


  #Get the name of the script currently executing.
  $ScriptName = $MyInvocation.MyCommand.Name

  $wu = Get-WmiObject -Class "win32_quickfixengineering" -ComputerName $ComputerName | Select-Object -Property "Description", "HotfixID", @{Name="InstalledOn"; Expression={([DateTime]($_.InstalledOn))}} | Sort-Object InstalledOn #| Select -Last 1
  write-output $wu
}
