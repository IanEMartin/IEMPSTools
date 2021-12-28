
function Get-WindowsVolume {
  <#
  .SYNOPSIS
  Gets the drive volume(s) information for a system.
  .DESCRIPTION
  Gets the information for the drive volumes on a system.  The output can be filtered by using the DriveLetter parameter.
  .OUTPUTS
  An object with properties pertaining to the volumes on a system.
  .EXAMPLE
  Get-WindowsVolume -ComputerName COMPUTERNAME.domain.local

  Name          Volume SizeGB FreeSpaceGB PercentFree BlockSizeKB PartitionStyle Status PSComputerName
  ----          ------ ------ ----------- ----------- ----------- -------------- ------ --------------
  COMPUTERNAME    C       100          68          68           4 MBR            Ok     COMPUTERNAME.domain.local
  COMPUTERNAME    E       900         127          14           4 GPT            Ok     COMPUTERNAME.domain.local
  COMPUTERNAME    F      1100         192          17           4 GPT            Ok     COMPUTERNAME.domain.local
  COMPUTERNAME    G       100          89          90           4 GPT            Ok     COMPUTERNAME.domain.local

  Displays information for all the volumes.

  .EXAMPLE
  Get-WindowsVolume -ComputerName COMPUTERNAME.domain.local -DriveLetter C

  Name         Volume SizeGB FreeSpaceGB PercentFree BlockSizeKB PartitionStyle Status PSComputerName
  ----         ------ ------ ----------- ----------- ----------- -------------- ------ --------------
  COMPUTERNAME   C       100          68          68           4 MBR            Ok     COMPUTERNAME.domain.local

  Displays the information on the C volume
  .NOTES
    Version: 21.01.1
    Changelog:
      21.01.1     Initial version
      21.05.02.1  Fix issue where PartitionStyle was returning $null because select/match in statement wasn't concise enough
      21.07.01.1  Improve filter for matching a volumes diskNumber to make sure it matches up with one that contains at least one digit
      21.08.04.1  Add DiskNumber property.  Not included in the PSType.  Just used for additional info.
      21.08.05.1  Add PartitionNumber property.  Not included in the PSType.  Just used for additional info.
      21.08.16.1  Add logic for human readable partitionStyle output when only values are returned depending onversion of Storage module installed.
                  Add VolumeName property
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
    [string]
    $driveLetter,
    [PSCredential]
    $Credential
  )

  Begin {
    $Scriptblock = {
      $PSType = 'jha.Tools.Get-WindowsVolume.Default'
      $SBInfo = @()
      $volumeList = (Get-CimInstance -ClassName Win32_logicaldisk | Where-Object { $_.DriveType -eq 3 } | Select-Object -ExpandProperty DeviceID).Trim(':')
      foreach ($volumeLetter in $volumeList) {
        $status = 'Success'
        $systemDomain = Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -ExpandProperty Domain
        $disk = Get-CimInstance -ClassName Win32_logicaldisk | Where-Object { $_.DriveType -eq 3 -and $_.DeviceID -match $volumeLetter }
        $blockSizes = Get-CimInstance -ClassName Win32_Volume | Where-Object { $_.DriveType -eq 3 -and $_.DriveLetter -match $volumeLetter } | Select-Object Driveletter, BlockSize, DriveType
        $diskNumbers = Get-Partition | Where-Object { $_.DriveLetter -match $volumeLetter -and $_.DiskNumber -match '\d+' } | Select-Object DriveLetter, DiskNumber, PartitionNumber
        $partitionStyle = Get-Disk | Where-Object { $_.Number -eq $diskNumbers.DiskNumber } | Select-Object -ExpandProperty PartitionStyle
        if ($partitionStyle -match '^\d+') {
          switch -regex ($partitionStyle) {
            '0' { $partitionStyle = 'Unknown' }
            '1' { $partitionStyle = 'MBR' }
            '2' { $partitionStyle = 'GPT' }
          }
        }
        if ([string]::IsNullOrEmpty($disk.Size)) {
          $SizeGB = $null
          $FreeSpaceGB = $null
        } else {
          $SizeGB = ([decimal]("{0:N0}" -f ($disk.Size / 1gb)))
          $FreeSpaceGB = ([decimal]("{0:N0}" -f ($disk.FreeSpace / 1gb)))
        }
        if ([string]::IsNullOrEmpty($disk.freespace)) {
          $PercentFree = $null
        } else {
          $PercentFree = ([decimal]("{0:N0}" -f (($disk.freespace / $disk.size) * 100)))
        }
        if ([string]::IsNullOrEmpty($blockSizes.BlockSize)) {
          $blockSizeKB = $null
        } else {
          if ($blockSizes.BlockSize -ge 1024) {
            $blockSizeKB = ([decimal]("{0:N0}" -f ($blockSizes.BlockSize / 1024)))
          } else {
            $blockSizeKB = '512b'
          }
        }
        $volumeInfo = [PSCustomObject]@{
          PSTypeName      = $PSType
          Name            = $env:COMPUTERNAME
          FQDN            = '{0}.{1}' -f $env:COMPUTERNAME, $systemDomain
          Volume          = $disk.DeviceID.Split(':')[0]
          VolumeName      = $disk.VolumeName
          Size            = $disk.size
          FreeSpace       = $disk.freespace
          PercentFree     = $PercentFree
          SizeGB          = $SizeGB
          FreeSpaceGB     = $FreeSpaceGB
          BlockSize       = $blockSizes.BlockSize
          BlockSizeKB     = $blockSizeKB
          PartitionStyle  = $partitionStyle
          DiskNumber      = $diskNumbers.DiskNumber
          PartitionNumber = $diskNumbers.PartitionNumber
          Status          = $status
        }
        $SBInfo += $volumeInfo
      }
      $SBInfo
    }
  }

  Process {
    $PSType = 'jha.Tools.Get-WindowsVolume.Default'
    if ($ComputerName.ToLower() -eq 'localhost' -or $ComputerName -match $env:COMPUTERNAME) {
      Write-Host ('Getting volume information locally on ') -NoNewLine
      Write-Host ('{0}' -f $ComputerName) -ForegroundColor Cyan -NoNewLine
      Write-Host ('...')
      $responseInfo = @()
      $volumeList = (Get-CimInstance -ClassName Win32_logicaldisk | Where-Object { $_.DriveType -eq 3 } | Select-Object -ExpandProperty DeviceID).Trim(':')
      foreach ($volumeLetter in $volumeList) {
        Write-Verbose ('Volume {0}...' -f $volumeLetter)
        $status = 'Success'
        $systemDomain = Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -ExpandProperty Domain
        $disk = Get-CimInstance -ClassName Win32_logicaldisk | Where-Object { $_.DriveType -eq 3 -and $_.DeviceID -match $volumeLetter }
        $blockSizes = Get-CimInstance -ClassName Win32_Volume | Where-Object { $_.DriveType -eq 3 -and $_.DriveLetter -match $volumeLetter } | Select-Object Driveletter, BlockSize, DriveType
        $diskNumbers = Get-Partition | Where-Object { $_.DriveLetter -match $volumeLetter -and $_.DiskNumber -match '\d+' } | Select-Object DriveLetter, DiskNumber, PartitionNumber
        $partitionStyle = Get-Disk | Where-Object { $_.Number -eq $diskNumbers.DiskNumber } | Select-Object -ExpandProperty PartitionStyle
        if ($partitionStyle -match '^\d+') {
          switch -regex ($partitionStyle) {
            '0' { $partitionStyle = 'Unknown' }
            '1' { $partitionStyle = 'MBR' }
            '2' { $partitionStyle = 'GPT' }
          }
        }
        if ([string]::IsNullOrEmpty($disk.Size)) {
          $SizeGB = $null
          $FreeSpaceGB = $null
        } else {
          $SizeGB = ([decimal]("{0:N0}" -f ($disk.Size / 1gb)))
          $FreeSpaceGB = ([decimal]("{0:N0}" -f ($disk.FreeSpace / 1gb)))
        }
        if ([string]::IsNullOrEmpty($disk.freespace)) {
          $PercentFree = $null
        } else {
          $PercentFree = ([decimal]("{0:N0}" -f (($disk.freespace / $disk.size) * 100)))
        }
        if ([string]::IsNullOrEmpty($blockSizes.BlockSize)) {
          $blockSizeKB = $null
        } else {
          if ($blockSizes.BlockSize -ge 1024) {
            $blockSizeKB = ([decimal]("{0:N0}" -f ($blockSizes.BlockSize / 1024)))
          } else {
            $blockSizeKB = '512b'
          }
        }
        $volumeInfo = [PSCustomObject]@{
          PSTypeName      = $PSType
          Name            = $env:COMPUTERNAME
          FQDN            = '{0}.{1}' -f $env:COMPUTERNAME, $systemDomain
          Volume          = $disk.DeviceID.Split(':')[0]
          VolumeName      = $disk.VolumeName
          Size            = $disk.size
          FreeSpace       = $disk.freespace
          PercentFree     = ([decimal]("{0:N0}" -f (($disk.freespace / $disk.size) * 100)))
          SizeGB          = $SizeGB
          FreeSpaceGB     = $FreeSpaceGB
          BlockSize       = $blockSizes.BlockSize
          BlockSizeKB     = $blockSizeKB
          PartitionStyle  = $partitionStyle
          DiskNumber      = $diskNumbers.DiskNumber
          PartitionNumber = $diskNumbers.PartitionNumber
          Status          = $status
        }
        $responseInfo += $volumeInfo
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
          Volume          = $null
          Size            = $null
          FreeSpace       = $null
          PercentFree     = $null
          SizeGB          = $null
          FreeSpaceGB     = $null
          BlockSize       = $null
          BlockSizeKB     = $null
          PartitionStyle  = $null
          DiskNumber      = $null
          PartitionNumber = $null
          Status          = $responseStatus
        }
      } else {
        $responseInfo = $invokeResponse
      }
    }
    if ('' -eq $driveLetter) {
      $responseInfo
    } else {
      $responseInfo | Where-Object { $_.Volume -eq $driveLetter }
    }
  }

  End {
  }

}
