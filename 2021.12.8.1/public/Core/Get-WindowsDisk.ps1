
function Get-WindowsDisk {
  <#
  .SYNOPSIS
  Gets the disk(s) information for a system.
  .DESCRIPTION
  Gets the information for the disks on a system.  The output can be filtered by using the DiskNumber parameter.
  .OUTPUTS
  An object with properties pertaining to the disks on a system.

  Displays the information on the C volume
  .NOTES
    Version: 21.08.1
    Changelog:
      21.08.1     Initial version
      #>
  #Requires -Version 7.0
  [CmdletBinding()]
  Param (
    [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
    # [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [ValidateScript( {
      if ($_ -match '(?=^.{4,253}$)(^((?!-)[a-zA-Z0-9-]{1,63}(?<!-)\.)+[a-zA-Z]{2,63}$)') {
        $true
      } elseif ($_ -eq '' -or $_ -eq 'localhost') {
        $true
      } else {
        Throw 'System name must be in Fully Qualified Domain Name format. Example: computername.domain.com'
      }
    })]
    [string]
    $ComputerName = $env:COMPUTERNAME,
    [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [ValidatePattern('^\d*')]
    [string]
    $diskNumber,
    [PSCredential]
    $Credential
  )

  Begin {
    $Scriptblock = {
      Get-Disk
    }
  }

  Process {
    if ($ComputerName.ToLower() -eq 'localhost' -or $ComputerName -match $env:COMPUTERNAME) {
      Write-Host ('Getting volume information locally on ') -NoNewLine
      Write-Host ('{0}' -f $ComputerName) -ForegroundColor Cyan -NoNewLine
      Write-Host ('...')
      $responseInfo = Get-Disk
    } else {
      $ComputerNameDomain = ($ComputerName -replace "$($ComputerName.Split('.')[0]).", '')
      if ($null -eq $Credential) {
        # $ExplanationMessage = 'UserName needs to be in UserName@Domain.tld (preferred format), DOMAIN\UserName or .\UserName (for non-domain) format'
        # $Credential = Get-Credential -Message ('Enter a fully qualified username (EXAMPLE: user@domain.com) for [{0}].{1}{2}.' -f $ComputerNameDomain, "`r`n", $ExplanationMessage)
        $Credential = Get-PersistedCredential -Domain $ComputerNameDomain -MaxAge -Interval Hours -Length 2
      }
      $tempSession = New-PSSession -ComputerName $ComputerName -Name GetDiskInfo -Credential $Credential -ErrorVariable createSessionErr -ErrorAction SilentlyContinue
      if ($null -eq $tempSession) {
       Write-Warning ('Unable to connect a session to {0}' -f $ComputerName)
        if ($createSessionErr) {
         Write-Warning (($createSessionErr[0].ToString() -split '\s{2,}')[-1])
        }
      } else {
        $invokeResponse = Invoke-Command -Session $tempSession -ScriptBlock $scriptBlock -ErrorVariable sessionErr -ErrorAction ignore #DevSkim: ignore DS104456
        Remove-PSSession -Session $tempSession -ErrorAction SilentlyContinue
      }
      if ($null -eq $invokeResponse -or $null -eq $tempSession) {
        if ($sessionErr) {
          Write-Warning (($sessionErr[0].ToString() -split '\s{2,}')[-1])
        }
      } else {
        $responseInfo = $invokeResponse
      }
    }
    if ([string]::IsNullOrEmpty($diskNumber)) {
      $responseInfo
    } else {
      $responseInfo | Where-Object { $_.Number -eq $diskNumber }
    }
  }

  End {
  }

}
