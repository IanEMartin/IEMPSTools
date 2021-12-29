function Update-Sysinternals {
  param (
    $Uri = 'https://download.sysinternals.com/files/SysinternalsSuite.zip',
    $OutFile = "$($env:HomeDrive)$($env:HOMEPATH)\Downloads\SysinternalsSuite.zip",
    $Destination = "$env:HomeDrive\SysInternals",
    [switch]
    $RemoveDownloadFile
  )

  try {
    # Download the new zip file of tools
    Invoke-WebRequest -Uri $Uri -OutFile $OutFile -Verbose -ErrorAction Stop
    # Get the list of files before the update
    if (!(Test-Path -Path $Destination)) {
      $null = New-Item -Path $Destination -ItemType Directory -Force
    }
    $Files = Get-ChildItem -Path $Destination
    # Kill any running sysinternals apps processes that may be locked
    $Running = Get-Process zoomit*, desktops*, procexp* -ErrorAction SilentlyContinue
    $Paths = $Running | Where-Object { $_.name -notlike '*64' } | Select-Object -Property Path
    if ($Running) {
      $Running | Stop-Process -Force -Verbose
    }
    Add-Type -AN System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($OutFile)
    $extractedCount = 0
    if ($null -eq $Files) {
      $missingFiles = $zip.Entries
    } else {
      $fileDiff = Compare-Object -ReferenceObject $Files.Name -DifferenceObject $zip.Entries.Name | Where-Object { $_.SideIndicator -eq '=>' } | Select-Object -ExpandProperty InputObject
      $missingFiles = $zip.Entries | Where-Object { $_.Name -in $fileDiff }
    }
    $missingFiles |
    ForEach-Object {
      #Extract the selected item(s)
      Write-Verbose -Message ('Extracting missing file: {0}' -f $_.Name) -Verbose
      $ExtractFileName = $_.Name
      $ExtractFileNamePath = ("$Destination\$ExtractFileName")
      [System.IO.Compression.ZipFileExtensions]::ExtractToFile($_, $ExtractFileNamePath, $true)
      $extractedCount++
    }
    $filter = Get-ChildItem -Path $OutFile | Select-Object LastWriteTime | Sort-Object LastWriteTime | Select-Object -ExpandProperty LastWriteTime -Last 1
    $newFiles = $zip.Entries | Where-Object { $_.LastWriteTime -gt $filter }
    $newFiles |
    ForEach-Object {
      #Extract the selected item(s)
      Write-Verbose -Message ('Extracting updated file: {0}' -f $_.Name) -Verbose
      $ExtractFileName = $_.Name
      $ExtractFileNamePath = ("$Destination\$ExtractFileName")
      [System.IO.Compression.ZipFileExtensions]::ExtractToFile($_, $ExtractFileNamePath, $true)
      $extractedCount++
    }
    Write-Verbose -Message ('Extracted {0} files.' -f $extractedCount) -Verbose
    #Check that destination of files is in the environment Path variable
    Update-PathEnvironmentVariable -NewPath $Destination -UpdateRegistry
    if ($RemoveDownloadFile) {
      Remove-Item -Path $OutFile -Force
    }
  } Catch {
    Write-Warning -Message $_
  } finally {
    $zip.Dispose()
    # Restart any applications that were running previously
    if ($Paths) {
      $Paths | ForEach-Object { Start-Process -FilePath $_.Path }
    }
  }
}#End function Update-Sysinternals
