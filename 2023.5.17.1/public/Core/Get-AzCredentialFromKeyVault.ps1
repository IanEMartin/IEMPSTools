
function Get-AzCredentialFromKeyVault {
  <#
  .SYNOPSIS
  .DESCRIPTION
  .OUTPUTS
  .EXAMPLE
  .EXAMPLE
  .NOTES
    Version: 21.4.7.0
    Changelog: 
      21.4.7.0   Initial version
  #>
  #Requires -Version 7.0
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory)]
    [string]
    $userName,
    [Parameter(Mandatory)]
    [ValidateScript( {
      if ($_ -match '[\dA-Z-_]+[\.\dA-Z-_]+') {
        $true
      } else {
        Throw 'DomainName must be in Fully Qualified Domain Name format. Example: domain.tld or subdomain.domain.tld'
      }
    })]
    [string]
    $domainName,
    [Parameter(Mandatory)]
    [string]
    $AzureKeyVaultName
  )

  Begin {
  }

  Process {
    $creds = $null
    switch -regex ($userName) {
      # .\UserName
      '\.+\\[\dA-Z-_]+' {
        $userName = $userName.Split('\')[1]
      }
      # DOMAIN\UserName
      '[\dA-Z-_]+\\[\dA-Z-_]+' {
        $userName = $userName.Split('\')[1]
      }
      # UserName@domain.tld
      '[\dA-Z-_]+@[\dA-Z-_]+[\.\dA-Z-_]+' {
        $userName = $userName -Split('@')[0]
      }
    }
    $domainUserName = '{0}@{1}' -f $userName, $domainName
    $azureKeyDomain = $domainName -replace '\.', '-'
    $azkvUserName = '{0}-User-{1}' -f $userName, $azureKeyDomain
    $azkvPassName = '{0}-Pass-{1}' -f $userName, $azureKeyDomain
    #Retrieve Azure KeyVault Secret Entries
    # Write-Verbose $azkvPassName -Verbose
    $credUser = (Get-AzKeyVaultSecret -VaultName $AzureKeyVaultName -Name $azkvUserName).SecretValue | ConvertFrom-SecureString -AsPlainText
    # $secretUser = Get-AzKeyVaultSecret -VaultName $AzureKeyVaultName -Name $azkvUserName
    # $ssPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secretUser.SecretValue)
    # $credUser = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ssPtr)
    # Write-Verbose $credUser -Verbose
    $credPass = (Get-AzKeyVaultSecret -VaultName $AzureKeyVaultName -Name $azkvPassName).SecretValue
    # Write-Verbose $CredPass -Verbose
    $creds = New-Object System.Management.Automation.PSCredential ($credUser, $credPass)
    return $creds
  }

  End {
  }

}
