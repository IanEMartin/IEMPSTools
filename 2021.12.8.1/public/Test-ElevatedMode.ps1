function Test-ElevatedMode {
  [CmdletBinding()]
  param (
  )
  if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
    $ElevatedMode = $false
  } else {
    $ElevatedMode = $true
  }
  $ElevatedMode
}
