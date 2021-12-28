function Get-PersistedCredential {
  [Cmdletbinding(DefaultParameterSetName = 'Default')]
  Param(
    [string]
    $UserName = '',
    [string]
    $Domain = '',
    [string]
    $Message = ' ',
    [switch]
    $List,
    [Parameter(
      Mandatory = $false,
      ParameterSetName = 'MaxAge'
    )]
    [switch]
    $MaxAge,
    [Parameter(
      Mandatory = $false,
      ParameterSetName = 'MaxAge'
    )]
    [ValidateSet(
      'Days',
      'Hours'
    )]
    [string]
    $Interval = 'Days',
    [Parameter(
      Mandatory = $false,
      ParameterSetName = 'MaxAge'
    )]
    [int]
    $Length,
    [switch]
    $ShowWindow
  )

  Begin {
    $Cred = $null
    $filename = $null
    $CurrentDomain = $env:USERDNSDOMAIN
  }

  Process {
    function ConvertTo-UsernameDomain {
      param(
        [string]
        $User
      )
      switch -regex ($User) {
        # .\UserName
        '\.+\\[\dA-Z-_]+' {
          $returnInfo = [PSCustomObject][ordered]@{
            FileDomain      = 'local'
            User            = $User.Split('\')[1]
            PromptUserName  = $User.Split('\')[1]
          }
        }
        # DOMAIN\UserName
        '[\dA-Z-_]+\\[\dA-Z-_]+' {
          $DomainPrefix = $User.Split('\')[0]
          $returnInfo = [PSCustomObject][ordered]@{
            FileDomain      = $DomainPrefixTlds[$DomainPrefix]
            User            = $User.Split('\')[1]
            PromptUserName  = $User
          }
        }
        # UserName@domain.tld
        '[\dA-Z-_]+@[\dA-Z-_]+[\.\dA-Z-_]+' {
          $returnInfo = [PSCustomObject][ordered]@{
            FileDomain      = $User.Split('@')[1]
            User            = $User.Split('@')[0]
            PromptUserName  = $User
          }
        }
      }
      Write-Verbose ('{0}{1}' -f "`r`n" , (Out-String -InputObject (Out-String -InputObject $returnInfo).Trim()))
      $returnInfo
    }
 
    function Get-DomainFQDN {
      $promptInput = $null
      Do {
        $promptInput = Read-Host -Prompt 'Enter a domain (domain.tld format)' -ErrorAction Stop
        if ($promptInput -notmatch '[\.\dA-Z-]+\.[\.\dA-Z-]+') {
          Write-Warning -Message 'Domain needs to be in domain@tld format.  Try again... '
        }
      } Until ($promptInput -match '[\.\dA-Z-]+\.[\.\dA-Z-]+')
      return $promptInput
    }

    if ($List) {
      $PersistedCreds = @()
      $Files = Get-ChildItem -Path $env:LOCALAPPDATA -Filter "*.Clixml" -File
      $Files = $Files | Where-Object { $_.Name -match "_*.Clixml" } | Select-Object FullName, LastWriteTime
      if ($null -ne $Files) {
        foreach ($File in $Files) {
          $Cred = Import-Clixml $File.FullName

          $PCred = New-Object PSObject
          Add-Member -InputObject $PCred -MemberType NoteProperty -Name UserName -Value $Cred.UserName
          Add-Member -InputObject $PCred -MemberType NoteProperty -Name LastWriteTime -Value $File.LastWriteTime
          Add-Member -InputObject $PCred -MemberType NoteProperty -Name AgeInDays -Value ([math]::round(((Get-Date) - $File.LastWriteTime).TotalDays, 2))
          Add-Member -InputObject $PCred -MemberType NoteProperty -Name AgeInHours -Value ([math]::round(((Get-Date) - $File.LastWriteTime).TotalHours, 2))

          $PersistedCreds += $PCred
        }
        return $PersistedCreds
      }
    }
    if ($userName -imatch '\.+\\[\dA-Z-_]+|[\dA-Z-]+\\[\dA-Z-_]+|[\dA-Z-_]+@[\.\dA-Z-]+') {
      $converted = ConvertTo-UsernameDomain -User $userName
      $PromptUserName = $converted.PromptUserName
      $Domain = $converted.FileDomain
    } else {
      if ('' -eq $Domain) {
        # Do {
          $Domain = Get-DomainFQDN
        #   if ($Domain -notmatch '[\.\dA-Z-]+\.[\.\dA-Z-]+') {
        #     Write-Warning -Message 'Domain needs to be in domain@tld format.  Try again... '
        #   }
        # } Until ($Domain -match '[\.\dA-Z-]+\.[\.\dA-Z-]+')
        $userName = '{0}@{1}' -f $UserName, $Domain
      }
    }
    if ('' -ne $Domain) {
      if ($Domain -notmatch '[\.\dA-Z-]+\.[\.\dA-Z-]+') {
        $Domain = Get-DomainFQDN
      }
      if ('' -ne $UserName) {
        if ($userName -imatch '\.+\\[\dA-Z-_]+|[\dA-Z-]+\\[\dA-Z-_]+|[\dA-Z-_]+@[\.\dA-Z-]+') {
          $converted = ConvertTo-UsernameDomain -User $userName
          $userName = '{0}@{1}' -f $converted.User, $Domain
        } else {
          $userName = '{0}@{1}' -f $userName, $Domain
        }
      }
      $Files = Get-ChildItem -Path $env:LOCALAPPDATA -Filter "*.Clixml*" -File
      $File = $Files | Where-Object { $_.Name -match "_$Domain.Clixml" } | Select-Object FullName, LastWriteTime
      if ($null -ne $File) {
        if ($File.Count -gt 1) {
          Write-Warning -Message ('More than one item matches that domain [{0}] - using first available.  Use -UserName option instead or clean up extraneous domain credentials using Remove-PersistedCredential.' -f $Domain)
          $File = $Files | Where-Object { $_.Name -match "_$Domain.Clixml" } | Select-Object FullName, LastWriteTime -First 1
        }
        $CurrentAge = ((Get-Date) - $File.LastWriteTime).TotalDays
        if ($CurrentAge -ge 30) {
          Write-Warning -Message ('[{0}] Persisted Credential is {1} days old.  You should remove or update it.' -f $Domain, [math]::Round($CurrentAge,2))
        }
        if ($MaxAge) {
          switch ($Interval) {
            'Days' {
              $CurrentAge = [math]::Round(((Get-Date) - $File.LastWriteTime).TotalDays)
            }
            'Hours' {
              $CurrentAge = [math]::Round(((Get-Date) - $File.LastWriteTime).TotalHours)
            }
          }
          if ($CurrentAge -ge $Length) {
            $OldCred = Import-Clixml $File.FullName
            $UserName = $OldCred.UserName
            Write-Verbose -Message ('[{0}] Persisted Credential age is {1} {2} and exceeds the maximum age requested of {3} {2}' -f $UserName, $CurrentAge, $Interval.ToLower(), $Length)
            Remove-Item -Path $File.FullName -Force -ErrorAction Continue
            $Cred = $null
          } else {
            $Cred = Import-Clixml $File.FullName
            return $Cred
          }
        } else {
          $Cred = Import-Clixml $File.FullName
          return $Cred
        }
      }
    }
    if ('' -eq $UserName) {
      $ExplanationMessage = 'UserName needs to be in UserName@Domain.tld (preferred), DOMAIN\UserName or .\UserName (local non-domain) format'
      $PromptMessage = 'Enter a fully qualified username (EXAMPLE: user@domain.com).{0}{1}.' -f "`r`n", $ExplanationMessage
      if ('' -ne $Domain) {
        $PromptMessage = 'Enter a fully qualified username for [{0}] domain.  (EXAMPLE: Username@{0}){1}{2}.' -f $Domain,"`r`n", $ExplanationMessage
      }
      if ($ShowWindow) {
        Add-Type -AssemblyName System.Windows.Forms
        function Checkfortext
        {
          if ($objTextBox.Text.Length -ne 0)
          {
            $OKButton.Enabled = $true
          }
          else
          {
            $OKButton.Enabled = $false
          }
        }

        $objForm = New-Object System.Windows.Forms.Form
        $objForm.Text = "UserName Entry Form"
        $objForm.Size = New-Object System.Drawing.Size(300, 200)
        $objForm.StartPosition = "CenterScreen"

        $objForm.KeyPreview = $True
        $objForm.Add_KeyDown({
          if ($_.KeyCode -eq "Enter")
          { $Script:x = $objTextBox.Text; $objForm.Close() }
        })
        $objForm.Add_KeyDown({
          if ($_.KeyCode -eq "Escape")
          { $objForm.Close() }
        })

        $OKButton = New-Object System.Windows.Forms.Button
        $OKButton.Location = New-Object System.Drawing.Size(75, 120)
        $OKButton.Size = New-Object System.Drawing.Size(75, 23)
        $OKButton.Text = "OK"
        $OKButton.Enabled = $false
        $OKButton.Add_Click({ $Script:x = $objTextBox.Text; $objForm.Close() })
        $objForm.Controls.Add($OKButton)

        $CancelButton = New-Object System.Windows.Forms.Button
        $CancelButton.Location = New-Object System.Drawing.Size(150, 120)
        $CancelButton.Size = New-Object System.Drawing.Size(75, 23)
        $CancelButton.Text = "Cancel"
        $CancelButton.Add_Click({ $objForm.Close() })
        $objForm.Controls.Add($CancelButton)

        $objLabel = New-Object System.Windows.Forms.Label
        $objLabel.Location = New-Object System.Drawing.Size(10, 20)
        $objLabel.Size = New-Object System.Drawing.Size(280, 20)
        $objLabel.Text = $PromptMessage
        $objForm.Controls.Add($objLabel)

        $objTextBox = New-Object System.Windows.Forms.TextBox
        $objTextBox.Location = New-Object System.Drawing.Size(10, 80)
        $objTextBox.Size = New-Object System.Drawing.Size(260, 20)
        #$objTextBox.add_TextChanged({ $OKButton.Enabled = $true })
        $objForm.Controls.Add($objTextBox)
        $objTextBox.add_TextChanged({ Checkfortext })

        $objForm.Topmost = $True
        $objForm.Add_Shown({ $objForm.Activate() })
        [void] $objForm.ShowDialog()
        $UserName = $Script:x
      } else {
        Write-Host $ExplanationMessage -ForegroundColor White
        $PromptMessage = 'Username'
        if ('' -ne $Domain) {
          Write-Host 'Enter a fully qualified username for ' -NoNewline
          Write-Host $Domain -ForegroundColor Green -NoNewline
          Write-Host '.  (EXAMPLE: ' -NoNewline
          Write-Host '<Username>' -ForegroundColor Yellow -NoNewline
          Write-Host '@' -NoNewline
          Write-Host ('{0})' -f $Domain) -ForegroundColor Green
        }
        $userName = Read-Host -Prompt $PromptMessage
      }
      if ($userName -notmatch '\.+\\[\dA-Z-_]+|[\dA-Z-]+\\[\dA-Z-_]+|[\dA-Z-_]+@[\.\dA-Z-]+') {
        $userName = '{0}@{1}' -f $userName, $Domain
        # Throw 'UserName argument needs to be in DOMAIN\UserName, .\UserName or UserName@Domain.tld format.'
      }
    }
    $converted = ConvertTo-UsernameDomain -User $userName
    $PromptUserName = $converted.PromptUserName
    $filename = '{0}\{1}_{2}.Clixml' -f $env:LOCALAPPDATA, $converted.User, $converted.FileDomain
    if (Test-Path $filename) {
      if ($MaxAge) {
        switch ($Interval) {
          'Days' {
            $CurrentAge = [math]::Round(((Get-Date) - $File.LastWriteTime).TotalDays)
          }
          'Hours' {
            $CurrentAge = [math]::Round(((Get-Date) - $File.LastWriteTime).TotalHours)
          }
        }
        if ($CurrentAge -ge $Length) {
          Write-Warning -Message ('[{0}] Persisted Credential age is {1} {2} and exceeds the maximum age requested of {3} {2}' -f $UserName, $CurrentAge, $Interval.ToLower(), $Length)
          $Cred = $null
        } else {
          $Cred = Import-Clixml $filename
          return $Cred
        }
      } else {
        $Cred = Import-Clixml $filename
        return $Cred
      }
    }
    if ($null -eq $Cred) {
      Write-Verbose -Message ('Username is [{0}]' -f $PromptUserName)
      $Cred = Get-Credential -Message $Message -UserName $PromptUserName
    }
    if ($null -eq $Cred) {
      Write-Warning -Message 'Canceled prompt for credentials.'
    } else {
      Write-Verbose -Message ('[{0}]Saving Credential...' -f $UserName)
      $Cred | Export-Clixml -Path $filename
      return $Cred
    }
  }

  End {
  }
}
