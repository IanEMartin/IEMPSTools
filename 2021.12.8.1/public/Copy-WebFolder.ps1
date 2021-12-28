function Copy-WebFolder {
  param (
    [string]$source,
    [string]$destination,
    [bool]$recurse
  )
  if (!$(Test-Path -Path ($destination))) {
    $null = New-Item -Path $destination -ItemType directory -Force
  }

  # Get the file list from the web page
  $request = Invoke-WebRequest -Uri $source -ErrorAction SilentlyContinue #DevSkim: ignore DS104456
  $files = $request.Links
  # Parse each line, looking for files and folders
  foreach ($file in $files) {
    # File or Folder
    if (!($file.outerText.ToLower() -match [RegEx]::Escape('/[to parent directory/]'))) {
      # Not Parent Folder entry
      if (($file.href -match '/$')) {
        # Folder
        if ($recurse -and ($file.outerText.ToLower() -notmatch [RegEx]::Escape('[to parent directory]'))) {
          # Subfolder copy required
          Copy-WebFolder -source "$source/$($file.outerText)/" -destination "$destination/$($file.outerText)/" -recurse $recurse
        }
      } else {
        # File
        Invoke-WebRequest -Uri "$source/$($file.outerText)" -OutFile "$destination/$($file.outerText)" -ErrorAction SilentlyContinue #DevSkim: ignore DS104456
      }
    }
  }
}
