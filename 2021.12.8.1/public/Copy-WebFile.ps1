function Copy-WebFile {
  param (
    [string]$source,
    [string]$destination
  )
  $file = $source.Substring($source.LastIndexOf('/') + 1)
  if ($destination -match $file) {
    $destinationpath = $destination.Substring(0, $destination.LastIndexOf('\'))
  }
  $destination
  if (!$(Test-Path -Path ($destinationpath))) {
    $null = New-Item -Path $destinationpath -ItemType directory -Force
  }
  # Get the files from the web page
  Invoke-WebRequest -Uri $source -OutFile $destination -ErrorAction SilentlyContinue #DevSkim: ignore DS104456
}
