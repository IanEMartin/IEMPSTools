function Get-DriveSpaceInfo {
  [CmdletBinding()]
  param
  (
    [Parameter(
      ValueFromPipeline,
      ValueFromPipelineByPropertyName)]
    [Alias(
      "Name"
    )]
    [string]
    $ComputerName,
    $Drive = 'C'
  )

  Begin {
  }

  Process {
    if ($PSVersionTable.PSVersion.Major -eq 2) {
      return $PSVersionTable
    }
    foreach ($Computer in $ComputerName) {
      if ($Computer -eq '' -or $Computer -eq 'localhost') {
        $Computer = $env:COMPUTERNAME
      }
      $Service = ''
      $ComputerName = ''
      $diskinfo = $null
      $DeviceFilter = "DeviceID='$($Drive):'"
      if ($null -ne (Test-WSMan -ComputerName $Computer -ErrorAction SilentlyContinue)) {
        $Service = 'WSMan (CIMInstance)'
        $ListOfLocalDrives = Get-CimInstance -ComputerName $Computer -ClassName Win32_LogicalDisk -Filter "DriveType = '3'" -ErrorAction Continue | Select-Object -ExpandProperty DeviceID | ForEach-Object { $_ -replace ':', '' }
        if ($Drive -in $ListOfLocalDrives) {
          $diskinfo = Get-CimInstance -ComputerName $Computer -ClassName Win32_LogicalDisk -Filter $DeviceFilter -ErrorAction SilentlyContinue | Select-Object -Property DeviceID, Size, FreeSpace
        } else {
          Write-Error -Message ('Unable to find local drive {0} for {1}' -f $Drive, $Computer) -ErrorAction Continue
        }
      } else {
        $Service = 'WMI'
        $ListOfLocalDrives = Get-WmiObject -ComputerName $Computer -ClassName Win32_LogicalDisk -Filter "DriveType = '3'" -ErrorAction Continue | Select-Object -ExpandProperty DeviceID | ForEach-Object { $_ -replace ':', '' }
        if ($Drive -in $ListOfLocalDrives) {
          $diskinfo = Get-WmiObject -ComputerName $Computer -ClassName Win32_LogicalDisk -Filter $DeviceFilter -ErrorAction SilentlyContinue | Select-Object -Property DeviceID, Size, FreeSpace
        } else {
          Write-Error -Message ('Unable to find local drive {0} for {1}' -f $Drive, $Computer) -ErrorAction Continue
        }
      }
      if ($null -ne $diskinfo) {
        $Value = [pscustomobject][ordered]@{
          'ComputerName'   = $Computer
          'DeviceID'       = $diskinfo.DeviceID #-replace ':', ''
          'SizeGb'         = [math]::round(($diskinfo.Size / 1Gb), 2)
          'FreeSpaceGb'    = [math]::round(($diskinfo.FreeSpace / 1Gb), 2)
          'Service'        = $Service
        }
      }
    }
    return $Value
  }
}
