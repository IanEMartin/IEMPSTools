
function Get-WindowsOfflineDisk {
  <#
  .SYNOPSIS

  .DESCRIPTION

  .OUTPUTS

  .EXAMPLE
  .NOTES
    Version: 21.01.1
    Changelog:
      21.01.1   Initial version
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
    [int]
    $diskNumber = -1,
    [PSCredential]
    $Credential,
    [switch]
    $ShowSystemDisks
  )

  Begin {
    $Scriptblock = {
      $PSType = 'jha.Tools.Get-WindowsOfflineDisk.Default'
      $SBInfo = @()
      $offlineDiskList = Get-Disk | Where-Object { $_.isOffline -eq $true -or $_.PartitionStyle -eq 0 -or $_.PartitionStyle -eq 'RAW' }
      foreach ($disk in $offlineDiskList) {
        $status = 'Success'
        $systemDomain = Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -ExpandProperty Domain
        if ($disk.PartitionStyle -match '^[\d\.]+$') {
          switch ($disk.PartitionStyle) {
            0 { $PartitionStyle = 'RAW' }
            1 { $PartitionStyle = 'MBR' }
            2 { $PartitionStyle = 'GPT' }
            Default { $PartitionStyle = 'Unknown' }
          }
        }
        $SizeGB = ([decimal]("{0:N0}" -f ($disk.Size / 1gb)))
        $offlineDiskInfo = [PSCustomObject]@{
          PSTypeName      = $PSType
          ComputerName    = $env:COMPUTERNAME
          FQDN            = '{0}.{1}' -f $env:COMPUTERNAME, $systemDomain
          DiskNumber      = $disk.DiskNumber
          Size            = $disk.size
          SizeGB          = $SizeGB
          PartitionStyle  = $PartitionStyle
          IsOffline       = $disk.IsOffline
          IsSystem        = $disk.IsSystem
          $FriendlyName   = $disk.FriendlyName
          Status          = $status
        }
        $SBInfo += $offlineDiskInfo
      }
      $SBInfo
    }
  }

  Process {
    $PSType = 'jha.Tools.Get-WindowsOfflineDisk.Default'
    if ($ComputerName.ToLower() -eq 'localhost' -or $ComputerName -match $env:COMPUTERNAME) {
      Write-Host ('Getting information locally on ') -NoNewLine
      Write-Host ('{0}' -f $ComputerName) -ForegroundColor Cyan -NoNewLine
      Write-Host ('...')
      $responseInfo = @()
      $offlineDiskList = Get-Disk | Where-Object { $_.isOffline -eq $true -or $_.PartitionStyle -eq 0 -or $_.PartitionStyle -eq 'RAW' }
      foreach ($disk in $offlineDiskList) {
        Write-Verbose ('Disk {0}...' -f $disk.DiskNumber)
        $status = 'Success'
        $systemDomain = Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -ExpandProperty Domain
        if ($disk.PartitionStyle -match '^[\d\.]+$') {
          switch ($disk.PartitionStyle) {
            0 { $PartitionStyle = 'RAW' }
            1 { $PartitionStyle = 'MBR' }
            2 { $PartitionStyle = 'GPT' }
            Default { $PartitionStyle = 'Unknown' }
          }
        }
        $SizeGB = ([decimal]("{0:N0}" -f ($disk.Size / 1gb)))
        $offlineDiskInfo = [PSCustomObject]@{
          PSTypeName      = $PSType
          ComputerName    = $env:COMPUTERNAME
          FQDN            = '{0}.{1}' -f $env:COMPUTERNAME, $systemDomain
          DiskNumber      = $disk.DiskNumber
          Size            = $disk.size
          SizeGB          = $SizeGB
          PartitionStyle  = $PartitionStyle
          IsOffline       = $disk.IsOffline
          IsSystem        = $disk.IsSystem
          FriendlyName    = $disk.FriendlyName
          Status          = $status
        }
        $responseInfo += $offlineDiskInfo
      }
    } else {
      $FQDN = $ComputerName
      $ComputerNameDomain = ($ComputerName -replace "$($ComputerName.Split('.')[0]).", '')
      $Name = ($ComputerName.Split('.')[0])
      if ($null -eq $Credential) {
        # $ExplanationMessage = 'UserName needs to be in UserName@Domain.tld (preferred format), DOMAIN\UserName or .\UserName (for non-domain) format'
        # $Credential = Get-Credential -Message ('Enter a fully qualified username (EXAMPLE: user@domain.com) for [{0}].{1}{2}.' -f $ComputerNameDomain, "`r`n", $ExplanationMessage)
        $Credential = Get-PersistedCredential -Domain $ComputerNameDomain -MaxAge -Interval Hours -Length 2
      }
      $tempSession = New-PSSession -ComputerName $ComputerName -Name GetDiskInfo -Credential $Credential -ErrorVariable createSessionErr -ErrorAction SilentlyContinue
      if ($null -eq $tempSession) {
        $responseStatus = 'Unable to connect a session to {0}' -f $ComputerName
        if ($createSessionErr) {
          $responseStatus = ($createSessionErr[0].ToString() -split '\s{2,}')[-1]
        }
      } else {
        $invokeResponse = Invoke-Command -Session $tempSession -ScriptBlock $scriptBlock -ErrorVariable sessionErr -ErrorAction ignore #DevSkim: ignore DS104456
        Remove-PSSession -Session $tempSession -ErrorAction SilentlyContinue
      }
      if ($null -eq $invokeResponse -or $null -eq $tempSession) {
        if ($sessionErr) {
          $responseStatus = ($sessionErr[0].ToString() -split '\s{2,}')[-1]
        }
        Write-Verbose ('{0} returned [null]' -f $ComputerName)
        $responseInfo = [PSCustomObject]@{
          PSTypeName      = $PSType
          Name            = $Name
          FQDN            = $FQDN
          DiskNumber      = $null
          Size            = $null
          SizeGB          = $null
          PartitionStyle  = $null
          IsOffline       = $null
          IsSystem        = $null
          FriendlyName    = $null
          Status          = $responseStatus
        }
      } else {
        $responseInfo = $invokeResponse
      }
    }
    if (!($ShowSystemDisks)) {
      $responseInfo = $responseInfo | Where-Object { $_.IsSystem -eq $false }
    }
    if ($diskNumber -eq -1) {
      $responseInfo
    } else {
      $responseInfo | Where-Object { $_.DiskNumber -eq $diskNumber }
    }
  }

  End {
  }

}
