function Expand-WindowsDiskPartition {
  <#
  .SYNOPSIS
  Expands the volume partition
  .DESCRIPTION
  Expands the volume partition with available space on the disk
  .EXAMPLE
  Expand-WindowsDiskPartition -driveLetter E

  Runs the command locally and expands the volume E partition with any available space on the disk.
  .EXAMPLE
  Expand-WindowsDiskPartition -driveletter T -ComputerName COMPUTER.domain.com

  Runs the command remotely against COMPUTER.domain.com and expands the volume T partition with any available space on the disk.
  .NOTES
    Version: 21.01.1
    Changelog:
      21.01.1   Initial version
      21.07.06  Update logic for selecting partition to also match it to a partition that also has a disknumber property
  #>
  #Requires -Version 7.0
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [string]
    $driveLetter,
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
    [PSCredential]
    $Credential # To connect to VM Guest OS
  )

  Begin {
    $Scriptblock = {
      Param (
        [string]
        $driveLetter
      )
      $startTime = Get-Date
      $driveLetter = $driveLetter.ToLower()
      $statusMessage = 'Success'
      $systemDomain = Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -ExpandProperty Domain
      $returnInfo = [PSCustomObject][ordered]@{
        Name            = $env:COMPUTERNAME
        FQDN            = ('{0}.{1}' -f $env:COMPUTERNAME, $systemDomain)
        DriveLetter     = $driveLetter.ToUpper()
        OriginalSizeGb  = $null
        SizeGb          = $null
        Status          = $null
        ElapsedTime     = $null
      }
      $null = 'rescan' | diskpart
      $partition = Get-Partition | Where-Object { $_.DriveLetter -match $driveLetter -and $_.DiskNumber -match '\d+' }
      if ($null -eq $partition) {
        $statusMessage = ('Cannot find partition for drive letter ''{0}''' -f $driveLetter)
        $returnInfo.Status = $statusMessage
      } else {
        $startingSizeGb = ($partition | Select-Object -ExpandProperty Size) / 1Gb
        $returnInfo.OriginalSizeGb = $startingSizeGb
        $null = "select disk $($partition.DiskNumber)", "select partition $($partition.PartitionNumber)", "extend" | diskpart
        $null = 'rescan' | diskpart
        $partition = Get-Partition | Where-Object { $_.DriveLetter -match $driveLetter -and $_.DiskNumber -match '\d+' }
        $currentSizeGb = ($partition | Select-Object -ExpandProperty Size) / 1Gb
        $returnInfo.SizeGb = $currentSizeGb
        if ($startingSizeGb -eq $currentSizeGb) {
          $statusMessage = ('Starting size and current size for drive letter ''{0}'' are the same.  ' -f $driveLetter.ToUpper())
        } else {
          $statusMessage = 'Success'
        }
        $returnInfo.Status = $statusMessage
      }
      $elapsedTime = (Get-Date) - $startTime
      $returnInfo.ElapsedTime = $elapsedTime
      $returnInfo
    }
  }

  Process {
    $startTime = Get-Date
    $driveLetter = $driveLetter.ToLower()
    if ($ComputerName.ToLower() -eq 'localhost' -or $ComputerName -match $env:COMPUTERNAME) {
      Write-Verbose ('Expanding drive locally on system [{0}]...' -f $ComputerName) -Verbose
      $statusMessage = 'Success'
      $systemDomain = Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -ExpandProperty Domain
      $returnInfo = [PSCustomObject][ordered]@{
        Name            = $env:COMPUTERNAME
        FQDN            = ('{0}.{1}' -f $env:COMPUTERNAME, $systemDomain)
        DriveLetter     = $driveLetter.ToUpper()
        OriginalSizeGb  = $null
        SizeGb          = $null
        Status          = $null
        ElapsedTime     = $null
      }
      $null = 'rescan' | diskpart
      $partition = Get-Partition | Where-Object { $_.DriveLetter -match $driveLetter -and $_.DiskNumber -match '\d+' }
      if ($null -eq $partition) {
        $statusMessage = ('Cannot find partition for drive letter ''{0}''' -f $driveLetter)
        $returnInfo.Status = $statusMessage
      } else {
        $startingSizeGb = ($partition | Select-Object -ExpandProperty Size) / 1Gb
        $returnInfo.OriginalSizeGb = $startingSizeGb
        $null = "select disk $($partition.DiskNumber)", "select partition $($partition.PartitionNumber)", "extend" | diskpart
        $null = 'rescan' | diskpart
        $partition = Get-Partition | Where-Object { $_.DriveLetter -match $driveLetter -and $_.DiskNumber -match '\d+' }
        $currentSizeGb = ($partition | Select-Object -ExpandProperty Size) / 1Gb
        $returnInfo.SizeGb = $currentSizeGb
        if ($startingSizeGb -eq $currentSizeGb) {
          $statusMessage = ('Starting size and current size for drive letter ''{0}'' are the same.  ' -f $driveLetter.ToUpper())
        } else {
          $statusMessage = 'Success'
        }
        $returnInfo.Status = $statusMessage
      }
      $elapsedTime = (Get-Date) - $startTime
      $returnInfo.ElapsedTime = $elapsedTime
    } else {
      $FQDN = $ComputerName
      $ComputerNameDomain = ($ComputerName -replace "$($ComputerName.Split('.')[0]).", '')
      $Name = ($ComputerName.Split('.')[0])
      if ($null -eq $Credential) {
        # $ExplanationMessage = 'UserName needs to be in UserName@Domain.tld (preferred format), DOMAIN\UserName or .\UserName (for non-domain) format'
        # $Credential = Get-Credential -Message ('Enter a fully qualified username (EXAMPLE: user@domain.com) for [{0}].{1}{2}.' -f $ComputerNameDomain, "`r`n", $ExplanationMessage)
        $Credential = Get-PersistedCredential -Domain $ComputerNameDomain -MaxAge -Interval Hours -Length 2
      }
      $tempSession = New-PSSession -ComputerName $ComputerName -Name ExpandPartition -Credential $Credential -ErrorVariable $createSessionErr -ErrorAction ignore
      if ($null -eq $tempSession) {
        $responseStatus = 'Unable to connect a session to {0}' -f $ComputerName
      } else {
        $invokeResponse = Invoke-Command -Session $tempSession -ScriptBlock $scriptBlock -ArgumentList $driveLetter -ErrorVariable sessionErr -ErrorAction ignore #DevSkim: ignore DS104456
        Write-Verbose ({0} -f $invokeResponse)
        $null = Remove-PSSession -Session $tempSession -ErrorAction SilentlyContinue -Confirm:$false
      }
      if ($null -eq $invokeResponse -or $null -eq $tempSession) {
        if ($sessionErr) {
          $responseStatus = ($sessionErr[0].ToString() -split '\s{2,}')[-1]
        } else {
          $responseStatus = ('{0} returned [null]' -f $ComputerName)
        }
        Write-Verbose ('{0} returned [null]' -f $ComputerName)
        if ($null -ne $driveLetter) { $driveLetter.ToUpper() }
        $elapsedTime = (Get-Date) - $startTime
        $returnInfo = [PSCustomObject][ordered]@{
          Name            = $Name
          FQDN            = $FQDN
          DriveLetter     = $driveLetter
          Status          = $responseStatus
          ElapsedTime     = $elapsedTime
        }
      } else {
        $returnInfo = $invokeResponse
      }
    }
    $returnInfo
  }

  End {
  }

}
