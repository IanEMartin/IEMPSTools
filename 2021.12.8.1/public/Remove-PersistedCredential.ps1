function Remove-PersistedCredential {
  [Cmdletbinding()]
  Param(
    [ValidateScript( {
        if ($_ -imatch '\.+\\[\dA-Z-_]+|[\dA-Z-]+\\[\dA-Z-_]+|[\dA-Z-_]+@[\.\dA-Z-]+') {
          $true
        } else {
          Throw 'UserName parameter needs to be in DOMAIN\UserName, .\UserName or UserName@Domain.tld format.'
        }
      })]
    [string]$UserName = '',
    [string]$Domain = ''
  )

  Begin {
    $Cred = $null
    $filename = $null
  }

  Process {
    if ('' -ne $UserName -and '' -ne $Domain) {
      Throw 'The Username and Domain parameters cannot be used simultaneously.'
    }
    if ('' -ne $Domain) {
      $Files = Get-ChildItem -Path $env:LOCALAPPDATA -Filter "*.Clixml" -File
      $filename = $Files | Where-Object { $_.Name -match "_$Domain.Clixml" } | Select-Object -ExpandProperty FullName
      if ($null -ne $filename) {
        $Cred = Import-Clixml $filename
        Remove-Item -Path $filename -Force
      } else {
        Throw ('Cannot remove persisted credential with domain ''{0}'' because it does not exist.' -f $Domain)
      }
    }
    if ('' -ne $UserName) {
      switch -regex ($UserName) {
        # .\UserName
        '\.+\\[\dA-Z-_]+' {
          $FileDomain = 'local'
          $User = $Username.Split('\')[1]
          $PromptUserName = $Username.Split('\')[1]
        }
        # DOMAIN\UserName
        '[\dA-Z-_]+\\[\dA-Z-_]+' {
          $FileDomain = $Username.Split('\')[0]
          $User = $Username.Split('\')[1]
          $PromptUserName = $UserName
        }
        # UserName@domain.tld
        '[\dA-Z-_]+@[\dA-Z-_]+[\.\dA-Z-_]+' {
          $User = $Username.Split('@')[0]
          $FileDomain = $Username.Split('@')[1]
          $PromptUserName = $UserName
        }
      }
      $filename = '{0}_{1}' -f $User, $FileDomain
      if (Test-Path $env:LOCALAPPDATA\$filename.clixml) {
        $Cred = Import-Clixml $env:LOCALAPPDATA\$filename.clixml
        Remove-Item -Path $env:LOCALAPPDATA\$filename.clixml -Force
      } else {
        Throw ('Cannot remove persisted credential ''{0}'' because it does not exist.' -f $UserName)
      }
    }
    Write-Verbose -Message ('[{0}] persisted credential removed.' -f $Cred.UserName)
  }

  End {
    $Cred = $null
    $Files = $null
    $filename = $null
  }
}
