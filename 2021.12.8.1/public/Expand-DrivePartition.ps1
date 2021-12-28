function Expand-DrivePartition {
  function Get-Disks {
    'list disk' | diskpart |
      Where-Object { $_ -match 'disk (\d+)\s+online\s+\d+ .?b\s+\d+ [gm]b' } |
      ForEach-Object { $matches[1] }
  }
  function Get-DiskPartitions($disk) {
    "select disk $disk", "list partition" | diskpart |
      Where-Object { $_ -match 'partition (\d+)' } |
      ForEach-Object { $matches[1] }
  }
  function Get-RecoveryDiskPartitions($disk) {
    "select disk $disk", "list partition" | diskpart |
      Where-Object { $_ -match 'partition (\d+)(\s+recovery)' } |
      ForEach-Object { $matches[1] }
  }
  function Expand-DiskPartition($disk, $part) {
    "select disk $disk", "select partition $part", "extend" | diskpart | Out-Null
  }
  function Remove-RecoveryDiskPartition($disk, $part) {
    "select disk $disk", "select partition $part", "delete partition override" | diskpart | Out-Null
  }
  function Get-Volumes {
    'list volume' | diskpart |
      Where-Object { $_ -match 'Volume (\d+)\s+[C-Z]' } |
      ForEach-Object { $matches[1] }
  }
  function Expand-Volume($volume) {
    "select volume $volume", "extend filesystem" | diskpart | Out-Null
  }

  'rescan' | diskpart | Out-Null
  Get-Disks | ForEach-Object {
    $disk = $_
    $system = $null
    if (Test-WSMan -ComputerName $env:COMPUTERNAME) {
      if ($PSVersionTable.PSVersion.Major -ge 3) {
      $System = Get-CimInstance -Class Win32_ComputerSystem
      }
    }
    if ($null -eq $system) {
      $System = Get-WMIObject -Class Win32_ComputerSystem
    }
    if ($System.Model -match 'vmware') {
      Get-RecoveryDiskPartitions $disk | ForEach-Object {
        $recoverypartition = $_
        Remove-RecoveryDiskPartition $disk $recoverypartition
      }
    }
    Get-DiskPartitions $disk | ForEach-Object {
      $partition = $_
      Expand-DiskPartition $disk $partition
    }
  }
  Get-Volumes | ForEach-Object {
    $volume = $_
    Expand-Volume $volume
  }
  'rescan' | diskpart | Out-Null
}
