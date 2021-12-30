function Update-PathEnvironmentVariable {
  param (
    [string]
    $NewPath = '',
    [switch]
    $UpdateRegistry,
    [switch]
    $Clean
  )
  $newPathExists = $false
  $result = $null
  try {
    $result = REG QUERY 'HKLM\System\CurrentControlSet\Control\Session Manager\Environment' /V PATH
    if ([string]::IsNullOrEmpty($result)) {
      throw 'Unable to retrieve current path variable from registry.'
    }
    $PathRegistryEnvString = $null
    $result |
      ForEach-Object {
        if(!([string]::IsNullOrEmpty($_) -or $_ -match 'HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Control\\Session Manager\\Environment')) {
          $PathRegistryEnvString += $_
        }
      }
    $PathRegistryEnvString = $PathRegistryEnvString -replace '^\s*PATH\s*REG_EXPAND_SZ\s*', ''
    $PathRegistryEnvString = $PathRegistryEnvString -replace ';;', ';'
    $PathRegistryEnvStringSplit = $null
    if ($Clean) {
      $PathRegistryEnvStringSplit = ($PathRegistryEnvString | Select-Object -Unique) -split ';' | Sort-Object
    } else {
      $PathRegistryEnvStringSplit = ($PathRegistryEnvString | Select-Object -Unique) -split ';'
    }
    $NewRegistryEnvString = $null
    $PathRegistryEnvStringSplit | ForEach-Object {
      if ($_ -match '%[A-Za-z]*%') {
        $pathToTest = $_
        do {
          $replaceString = $Matches[0]
          $envVariableName = $replaceString -replace '%', ''
          $newString = [Environment]::GetEnvironmentVariable($envVariableName)
          $pathToTest = $pathToTest -replace $replaceString, $newString
        } until (($pathToTest -match '%[A-Za-z]*%') -eq $false)
      } else {
        $pathToTest = $_
      }
      if ($pathToTest -eq $NewPath -and $NewPath.Length -gt 0) {
        $newPathExists = $true
      }
      if ($Clean) {
        if (Test-Path -Path $pathToTest) {
          $NewRegistryEnvString += "$_;"
        } else {
          Write-Verbose -Message ('Path [{0}] does not exist.  Removing from path.' -f $_) -Verbose
        }
      } else {
        $NewRegistryEnvString += "$_;"
      }
    }
    $NewRegistryEnvStringSplit = $NewRegistryEnvString -split ';'
    if ($newPathExists -eq $false) {
      $NewRegistryEnvStringSplit += $NewPath
    }
    $NewRegistryEnvStringSplit = $NewRegistryEnvStringSplit | Where-Object { $_ -ne '' } | Sort-Object
    $NewRegistryEnvString = $NewRegistryEnvStringSplit -join ';'
    # $NewRegistryEnvString
    if ($UpdateRegistry) {
      if ($newPathExists) {
        Write-Verbose -Message ('Path already in stored environment paths.  No changes made.') -Verbose
      } else {
        # Set the registry key
        Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH -Value $NewRegistryEnvString
        Write-Verbose -Message ('[{0}] added to current environment paths.' -f $NewPath) -Verbose
        $result = REG QUERY 'HKLM\System\CurrentControlSet\Control\Session Manager\Environment' /V PATH
        $PathRegistryEnvString = $null
        $result |
          ForEach-Object {
            if(!([string]::IsNullOrEmpty($_) -or $_ -match 'HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Control\\Session Manager\\Environment')) {
              $PathRegistryEnvString += $_
            }
          }
        $PathRegistryEnvString = $PathRegistryEnvString -replace '^\s*PATH\s*REG_EXPAND_SZ\s*', ''
        $PathRegistryEnvString = $PathRegistryEnvString -replace ';;', ';'
        $PathRegistryEnvString
      }
    }
    # Update current environment
    $currentEnvironmentPath = $env:PATH
    $currentEnvironmentPath = $currentEnvironmentPath | Where-Object { $_ -ne '' } | Sort-Object
    $currentEnvironmentPathSplit = $currentEnvironmentPath -split ';'
    if ($NewPath -in $currentEnvironmentPathSplit) {
      $newPathExists = $true
    }
    if ($newPathExists) {
      Write-Verbose -Message ('Path already in current environment paths.  No changes made.') -Verbose
    } else {
      $env:PATH = "$env:PATH;$NewPath"
      Write-Verbose -Message ('[{0}] added to current environment paths.' -f $NewPath) -Verbose
    }
    $env:PATH
  } catch {
    Write-Warning -Message $_
  }
}
