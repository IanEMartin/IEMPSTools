function Split-Username {
  param(
    [ValidateScript( {
      if ($_ -match '\.+\\[\dA-Z-_]+|[\dA-Z-]+\\[\dA-Z-_]+|[\dA-Z-_]+@[\.\dA-Z-]+') {
        $true
      } else {
        Throw 'User name needs to be in UserName@Domain.tld (preferred), DOMAIN\UserName or .\UserName (local non-domain) format'
      }
    })]
    [string]
    $User
  )
  switch -regex ($User) {
    # .\UserName
    '\.+\\[\dA-Z-_]+' {
      $returnInfo = [PSCustomObject][ordered]@{
        Domain         = 'localhost'
        Username       = $User.Split('\')[1]
      }
    }
    # DOMAIN\UserName
    '[\dA-Z-_]+\\[\dA-Z-_]+' {
      $DomainPrefix = $User.Split('\')[0]
      $returnInfo = [PSCustomObject][ordered]@{
        Domain         = $DomainPrefixTlds[$DomainPrefix]
        Username       = $User.Split('\')[1]
      }
    }
    # UserName@domain.tld
    '[\dA-Z-_]+@[\dA-Z-_]+[\.\dA-Z-_]+' {
      $returnInfo = [PSCustomObject][ordered]@{
        Domain         = $User.Split('@')[1]
        Username       = $User.Split('@')[0]
      }
    }
  }
  Write-Verbose ('{0}{1}' -f "`r`n" , (Out-String -InputObject (Out-String -InputObject $returnInfo).Trim()))
  $returnInfo
}
