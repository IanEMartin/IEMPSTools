function Expand-DriveVolume {
  function Get-Volumes {
    'list volume' | diskpart |
      Where-Object { $_ -match 'Volume (\d+)\s+C' } |
      ForEach-Object { $matches[1] }
  }
  function Expand-Volume($volume) {
    "select volume $volume", "extend filesystem" | diskpart | Out-Null
  }

  'rescan' | diskpart | Out-Null
  Get-Volumes | ForEach-Object {
    $volume = $_
    Expand-Volume $volume
  }
}
