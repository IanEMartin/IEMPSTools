function Out-Log {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory, HelpMessage = 'Enter a string of information you want entered in the log.')]
    [string]$LogData,
    [string]$Path,
    [string]$FileName,
    [switch]$ErrorData,
    [switch]$Screen,
    [switch]$LogUser,
    [switch]$New
  )

  Begin {
    #Set variables
    New-Variable -Name userName -Value ''
  }
  
  Process {
    New-Variable -Name LogFilePathAndName -Value ('{0}{1}' -f $Path, $FileName)
    #TODO Check if $Path has a '\' on the end and if not - add it.
    #  Write-Verbose ('Logging to file - {0}' -f $LogFilePathAndName)
    if (!(Test-Path -Path $Path)) {
      New-Item -ItemType Directory -Path $Path -Force
    }
    if ($LogUser) {
      $userName = ' ({0}\{1})' -f $env:USERDOMAIN, $env:USERNAME
    }
    if ($ErrorData) {
      $LogData = 'ERROR - ' + $LogData
    }
    $LogData = '{0}{1}: {2}' -f ($(Get-Date -Format 'yyyy-MM-dd HHmm')), $userName, $LogData
    if ($Screen -or ($VerbosePreference -eq 'Continue') -or ($LogData -match 'VERBOSE:') -or ($LogData -match 'WARNING:')) {
      if ($LogData -match 'WARNING:') {
        Write-Warning $LogData
      } elseif (($VerbosePreference -eq 'Continue') -or ($LogData -match 'VERBOSE:')) {
        Write-Verbose $LogData
      }
      if ($Screen) {
        Write-Output -InputObject $LogData
      }
    }
    if ($new) {
      $LogData | Out-File -FilePath $LogFilePathAndName
    } else {
      $LogData | Out-File -FilePath $LogFilePathAndName -Append
    }
  }

  End {
  }

}
