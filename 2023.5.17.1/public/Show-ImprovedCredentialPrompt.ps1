function Show-ImprovedCredentialPrompt {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory, HelpMessage = 'Enter a domain name')]
    [string]
    $DomainName,
    [Parameter(Mandatory, HelpMessage = 'Enter at least one computer name')]
    [string]
    $ComputerName,
    [string]
    $Message = ''
  )

  if ($IsWindows -or $env:OS -like 'Windows*') {
    $ComputerName = $ComputerName.ToUpper()
    $DomainName = $DomainName.ToUpper()
    $userID = '{0}\' -f $DomainName
    if ('' -eq $Message) {
      $Message = ('Please enter your password for system(s):{0}{1}' -f "`r`n", $ComputerName)
    }
    $usercreds = $Host.ui.PromptForCredential('Credentials', $Message, $userID, '')
    $usercreds
  } else {
    'This requires a Windows GUI'
  }
}
