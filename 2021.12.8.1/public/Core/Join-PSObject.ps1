function Join-PSObject {
  [Cmdletbinding()]
  Param([array]$left,
    [array]$right,
    [string]$leftProperty,
    [string]$rightProperty,
    [string[]]$propertiesToAdd,
    [string]$joinType = 'Inner')
  $groupedRight = $right | Group-Object -Property $rightProperty -AsHashTable
  $groupedLeft = $left | Group-Object -Property $leftProperty -AsHashTable
  $groupedLeft.Keys | ForEach-Object {
    $leftKey = $_
    $leftObjects = $groupedLeft[$leftKey]
    if ($groupedRight.ContainsKey($leftkey)) {
      foreach ($rightMatch in $groupedRight[$leftkey]) {
        [array]$CalculatedExpressions = $propertiesToAdd | ForEach-Object {
          $prop = $_
          @{N = "$prop"; E = { $RightMatch.$prop }.GetNewClosure() }
        }
        $allProperties = [array]'*' + $CalculatedExpressions
        $leftObjects | Select-Object -Property $allProperties
      }
    } elseif ($jointype -eq 'Left') {
      $rightMatch = $null
      $leftObjects | Select-Object -Property ([array]'*' + $propertiesToAdd)
    } else {
      Write-Verbose "Inner join: No match for $($leftkey)"
    }
  }
}
