function Use-ElevatedMode {
  [CmdletBinding()]
  param (
    [string]$Path
  )
  if (Test-ElevatedMode) {
    'Already in elevated mode.'
  } else {
    'Atttempting to restart in elevated mode...'
    try {
      Start-Process -FilePath powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$Path`"" -Verb RunAs
    } catch {
      'Error attempting to restart in elevated mode. {0}' -f $_
    }
  }
}
