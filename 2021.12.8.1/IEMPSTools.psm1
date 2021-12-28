#Set-StrictMode -Version Latest

#Get public and private function definition files.
$moduleFiles = @()
$moduleFiles = Get-ChildItem -Path $PSScriptRoot\Public\*.ps1
if (Test-Path -Path $PSScriptRoot\Private\) {
  $moduleFiles += Get-ChildItem -Path $PSScriptRoot\Private\*.ps1
}
if ($PSVersionTable.PSEdition -eq 'Core') {
  $moduleFiles += Get-ChildItem -Path $PSScriptRoot\Public\Core\*.ps1
  if (Test-Path -Path $PSScriptRoot\Private\Core\) {
    $moduleFiles += Get-ChildItem -Path $PSScriptRoot\Private\Core\*.ps1
  }
}

#Dot source the files
Foreach ($import in $moduleFiles) {
    Try {
      . $import.fullname
    } Catch {
      Write-Error -Message "Failed to import function $($import.fullname): $_"
    }
} #foreach
