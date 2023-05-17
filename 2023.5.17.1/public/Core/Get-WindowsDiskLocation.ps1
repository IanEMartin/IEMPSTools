function Get-WindowsDiskLocation {
  <#
  .SYNOPSIS
  Gathers the disk location and target information from a Windows system.
  .DESCRIPTION
  Gathers the disk location and target information from a Windows system.
  .OUTPUTS
  An object with properties
  .EXAMPLE
  Get-WindowsDiskLocation -ComputerName COMPUTERNAME.domain.local

  Name           : COMPUTERNAME
  FQDN           : COMPUTERNAME.domain.local
  DriveLetter    : C
  Location       : 160
  TargetID       : 0
  Status         : Success

  Name           : COMPUTERNAME
  FQDN           : COMPUTERNAME.domain.local
  DriveLetter    : E
  Location       : 224
  TargetID       : 0
  Status         : Success

  Returns all disks with the information.
  .EXAMPLE
  Get-WindowsDiskLocation -ComputerName COMPUTERNAME.domain.local -DriveLetter C

  Name           : COMPUTERNAME
  FQDN           : COMPUTERNAME.domain.local
  DriveLetter    : C
  Location       : 160
  TargetID       : 0
  Status         : Success

  Returns the information on the disk specified by the parameter argument.
  .EXAMPLE
  Get-WindowsDiskLocation -ComputerName COMPUTERNAME.domain.local | Format-Table -Autosize

  Name        FQDN                       DriveLetter Location TargetID Status
  ----        ----                       ----------- -------- -------- ------
  COMPUTERNAME COMPUTERNAME.domain.local C                160        0 Ok
  COMPUTERNAME COMPUTERNAME.domain.local E                224        0 Ok
  COMPUTERNAME COMPUTERNAME.domain.local F                224        1 Ok

  Returns all disks with the information and output is formatted into a table.
  *** NOTE *** Any output piped to a Format-* command becomes text only and is no longer an object that can be piped to another function or cmdlet.
  .NOTES
    Version: 21.01.1
    Changelog:
      21.01.01  Initial version
      21.05.04  Removed trailing whitespaces
                Added additional error handling
                Removed extraneous code for the object output
  #>
  #Requires -Version 7.0
  [CmdletBinding()]
  param
  (
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
    [Parameter(ValueFromPipeline = $true)]
    [string]
    $driveLetter,
    [PSCredential]
    $Credential
  )

  Begin {
    $Scriptblock = {
      $SBInfo = @()
      $volumeList = (Get-CimInstance -ClassName Win32_logicaldisk | Where-Object { $_.DriveType -eq 3 } | Select-Object -ExpandProperty DeviceID).Trim(':')
      foreach ($volumeLetter in $volumeList) {
        $status = 'Success'
        $systemDomain = Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -ExpandProperty Domain
        $systemFQDN = '{0}.{1}' -f $env:COMPUTERNAME, $systemDomain
        $logicalDisk = $null
        $logicalDisk = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { ($_.DeviceID).Trim(':') -like $volumeLetter }
        if ($null -eq $logicalDisk) { $status = "ERROR: no logical disk found" }
        $logicalDiskToPartition = $null
        $logicalDiskToPartition = Get-CimInstance -ClassName Win32_LogicalDiskToPartition | Where-Object { $_.Dependent -match ".*DeviceID\s*=\s*`"$($volumeLetter):`"" }
        if ($null -eq $logicalDiskToPartition) { $status = "partition to logical disk not found" }
        $logicalDiskToPartitionAntecendent = ((($logicalDiskToPartition | Select-Object -ExpandProperty Antecedent) -split 'DeviceID = "')[-1]).Replace('")', '')
        $diskPartition = $null
        $diskPartition = Get-CimInstance -ClassName Win32_DiskPartition | Where-Object { $_.Name -eq $logicalDiskToPartitionAntecendent }
        if ($null -eq $diskPartition) { $status = "partition not found" }
        $partitionToDisk = $null
        $partitionToDisk = Get-CimInstance -ClassName Win32_DiskDriveToDiskPartition | Where-Object { $_.Dependent -match $diskPartition.Name }
        if ($null -eq $partitionToDisk) { $status = "parition to phsycial drive not found" }
        $physicalDisk = $null
        $physicalDisk = Get-CimInstance -ClassName Win32_DiskDrive | Where-Object { $_.DeviceID -eq $partitionToDisk.Antecedent.DeviceID }
        if ($null -eq $physicalDisk) { $status = "physical disk drive not found" }
        $TargetID = $physicalDisk.SCSITargetID
        if ([string]::IsNullOrEmpty($TargetID)) {
          $TargetID = ''
          $status = 'Disk SCSI Target ID returned NULL or Empty'
        }
        $scsiToDrive = $null
        $scsiToDrive = Get-CimInstance -ClassName Win32_SCSIControllerDevice | Where-Object { $_.Dependent.DeviceID -eq $physicalDisk.PNPDeviceID }
        if ($null -eq $scsiToDrive) { $status = "scsi controller relation to disk drive not found" }
        $scsiController = $null
        $scsiController = Get-CimInstance -ClassName Win32_SCSIController | Where-Object { $scsiToDrive.Antecedent.DeviceID -eq $_.PNPDeviceID }
        if ($null -eq $scsiController) { $status = "scsi controller not found" }
        $path = "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum\" + $scsiController.PNPDeviceID
        $item = (Get-Item -Path $path)
        $location = $item.GetValue("UINumber")
        if ([string]::IsNullOrEmpty($location)) {
          $location = ''
          $status = 'Disk location returned NULL or Empty'
        }
        $responseInfo = [PSCustomObject]@{
          Name        = $env:COMPUTERNAME
          FQDN        = $systemFQDN
          DriveLetter = $volumeLetter.ToUpper()
          Location    = $location
          TargetID    = $TargetID
          Status      = $status
        }
        $SBInfo += $responseInfo
      }
      $SBInfo
    }
  }

  Process {
    if ($ComputerName.ToLower() -eq 'localhost' -or $ComputerName -match $env:COMPUTERNAME) {
      Write-Host ('Getting disk information locally on ') -NoNewline
      Write-Host ('{0}' -f $ComputerName) -ForegroundColor Cyan -NoNewline
      Write-Host ('...')
      $responseInfo = @()
      $volumeList = (Get-CimInstance -ClassName Win32_logicaldisk | Where-Object { $_.DriveType -eq 3 } | Select-Object -ExpandProperty DeviceID).Trim(':')
      foreach ($volumeLetter in $volumeList) {
        Write-Verbose ('Volume {0}...' -f $volumeLetter)
        $status = 'Success'
        $systemDomain = Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -ExpandProperty Domain
        $systemFQDN = '{0}.{1}' -f $env:COMPUTERNAME, $systemDomain
        $logicalDisk = $null
        $logicalDisk = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { ($_.DeviceID).Trim(':') -like $volumeLetter }
        if ($null -eq $logicalDisk) { $status = "ERROR: no logical disk found" }
        $logicalDiskToPartition = $null
        $logicalDiskToPartition = Get-CimInstance -ClassName Win32_LogicalDiskToPartition | Where-Object { $_.Dependent -match ".*DeviceID\s*=\s*`"$($volumeLetter):`"" }
        if ($null -eq $logicalDiskToPartition) { $status = "partition to logical disk not found" }
        $logicalDiskToPartitionAntecendent = ((($logicalDiskToPartition | Select-Object -ExpandProperty Antecedent) -split 'DeviceID = "')[-1]).Replace('")', '')
        $diskPartition = $null
        $diskPartition = Get-CimInstance -ClassName Win32_DiskPartition | Where-Object { $_.Name -eq $logicalDiskToPartitionAntecendent }
        if ($null -eq $diskPartition) { $status = "partition not found" }
        $partitionToDisk = $null
        $partitionToDisk = Get-CimInstance -ClassName Win32_DiskDriveToDiskPartition | Where-Object { $_.Dependent -match $diskPartition.Name }
        if ($null -eq $partitionToDisk) { $status = "parition to phsycial drive not found" }
        $physicalDisk = $null
        $physicalDisk = Get-CimInstance -ClassName Win32_DiskDrive | Where-Object { $_.DeviceID -eq $partitionToDisk.Antecedent.DeviceID }
        if ($null -eq $physicalDisk) { $status = "physical disk drive not found" }
        $TargetID = $physicalDisk.SCSITargetID
        if ([string]::IsNullOrEmpty($TargetID)) {
          $TargetID = ''
          $status = 'Disk SCSI Target ID returned NULL or Empty'
        }
        $scsiToDrive = $null
        $scsiToDrive = Get-CimInstance -ClassName Win32_SCSIControllerDevice | Where-Object { $_.Dependent.DeviceID -eq $physicalDisk.PNPDeviceID }
        if ($null -eq $scsiToDrive) { $status = "scsi controller relation to disk drive not found" }
        $scsiController = $null
        $scsiController = Get-CimInstance -ClassName Win32_SCSIController | Where-Object { $scsiToDrive.Antecedent.DeviceID -eq $_.PNPDeviceID }
        if ($null -eq $scsiController) { $status = "scsi controller not found" }
        $path = "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum\" + $scsiController.PNPDeviceID
        $item = (Get-Item -Path $path)
        $location = $item.GetValue("UINumber")
        if ([string]::IsNullOrEmpty($location)) {
          $location = ''
          $status = 'Disk location returned NULL or Empty'
        }
        $diskLocationInfo = [PSCustomObject]@{
          Name        = $env:COMPUTERNAME
          FQDN        = $systemFQDN
          DriveLetter = $volumeLetter.ToUpper()
          Location    = $location
          TargetID    = $TargetID
          Status      = $status
        }
        $responseInfo += $diskLocationInfo
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
      $tempSession = New-PSSession -ComputerName $ComputerName -Name GetDiskInfo -Credential $Credential -ErrorVariable $createSessionErr -ErrorAction ignore
      if ($null -eq $tempSession) {
        $responseStatus = 'Unable to connect a session to {0}' -f $ComputerName
      } else {
        $invokeResponse = Invoke-Command -Session $tempSession -ScriptBlock $scriptBlock -ErrorVariable sessionErr -ErrorAction ignore #DevSkim: ignore DS104456
        Remove-PSSession -Session $tempSession -ErrorAction SilentlyContinue
      }
      if ($null -eq $invokeResponse -or $null -eq $tempSession) {
        if ($sessionErr) {
          $responseStatus = ($sessionErr[0].ToString() -split '\s{2,}')[-1]
        }
        Write-Verbose ('{0} returned [null]' -f $ComputerName)
        if ($null -ne $volumeLetter) { $volumeLetter.ToUpper() }
        $responseInfo = [PSCustomObject]@{
          Name        = $Name
          FQDN        = $FQDN
          DriveLetter = $volumeLetter
          Location    = $null
          TargetID    = $null
          Status      = $responseStatus
        }
      } else {
        $responseInfo = $invokeResponse
      }
    }
    if ('' -eq $driveLetter) {
      $responseInfo
    } else {
      $responseInfo | Where-Object { $_.DriveLetter -eq $driveLetter }
    }
  }

  End {
  }
}
