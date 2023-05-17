function Convert-PrefixLengthToSubnetMask {
  param(
    [Parameter(ValueFromPipeline = $true)]
    [int]
    $PrefixLength
  )

  Begin {}

  Process {
    foreach ($Length in $PrefixLength) {
      $maskBinary = ('1' * $Length).PadRight(32, '0')
      $dottedMaskBinary = $MaskBinary -replace '(.{8}(?!\z))', '${1}.'
      $subnetMask = ($DottedMaskBinary.Split('.') | ForEach-Object { [Convert]::ToInt32($_, 2) }) -join '.'
      [pscustomobject][ordered]@{
        PrefixLength  = $PrefixLength
        MaskBinary    = $maskBinary
        SubnetMask    = $subnetMask
      }
    }
  }

  End {}
}
