function Set-PersistedCredential {
  [Cmdletbinding()]
  Param(
    [ValidateScript( {
        if ($_ -imatch '\.+\\[\dA-Z-_]+|[\dA-Z-]+\\[\dA-Z-_]+|[\dA-Z-_]+@[\.\dA-Z-]+') {
          $true
        } else {
          Throw 'UserName parameter needs to be in DOMAIN\UserName, .\UserName or UserName@Domain.tld format.'
        }
      })]
    [string]$UserName,
    [string]$Message = 'Enter credentials',
    [switch]$Force
  )

  Begin {
  }

  Process {
    if ('' -eq $UserName) {
      $UserName = Read-Host -Prompt 'Enter a username'
      if ($UserName -notmatch '\.+\\[\dA-Z-_]+|[\dA-Z-]+\\[\dA-Z-_]+|[\dA-Z-_]+@[\.\dA-Z-]+') {
        Throw 'UserName parameter needs to be in DOMAIN\UserName, .\UserName or UserName@Domain.tld format.'
      }
    }
    switch -regex ($UserName) {
      # .\UserName
      '\.+\\[\dA-Z-_]+' {
        $FileDomain = 'local'
        $User = $Username.Split('\')[1]
        $PromptUserName = $Username.Split('\')[1]
      }
      # DOMAIN\UserName
      '[\dA-Z-_]+\\[\dA-Z-_]+' {
        $DomainPrefix = $Username.Split('\')[0]
        $FileDomain = $DomainPrefixTlds[$DomainPrefix]
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
    $filename = '{0}\{1}_{2}.Clixml' -f $env:LOCALAPPDATA, $User, $FileDomain
    if ($null -eq $Cred) {
      $Cred = Get-Credential -Message $Message -UserName $PromptUserName
    }
    if (-not(Test-Path -Path $filename) -or $Force) {
      $Cred | Export-Clixml -Path $filename -Force
    } else {
      Write-Warning -Message 'Persistent credential already exists.  Either use Remove-PersistentCredential command first or Set-PersistentCredential with -Force parameter.'
    }
    return $Cred
  }

  End {
  }
}
