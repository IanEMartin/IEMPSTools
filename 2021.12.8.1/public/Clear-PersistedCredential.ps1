function Clear-PersistedCredential {
  [Cmdletbinding()]
  Param(
  )

  Begin {
    $Cred = $null
  }

  Process {
    $Files = Get-ChildItem -Path $env:LOCALAPPDATA -Filter "*.Clixml" -File
    $Files = $Files | Where-Object { $_.Name -match '.Clixml' } | Select-Object -ExpandProperty FullName
    if ($null -ne $Files) {
      foreach ($File in $Files) {
        $Cred = Import-Clixml $File
        Remove-Item -Path $File -Force
        Write-Verbose -Message ('[{0}] persisted credential removed.' -f $Cred.UserName)
      }
    }
  }

  End {
    $Cred = $null
    $File = $null
    $Files = $null
  }
}
