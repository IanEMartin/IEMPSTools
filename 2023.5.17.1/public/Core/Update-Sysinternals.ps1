function Update-Sysinternals {
  <#
  .SYNOPSIS
      Updates the Sysinternals tools to the latest version.
  .DESCRIPTION
      Updates the Sysinternals tools to the latest version.
  .PARAMETER Uri
      The Uri to download the Sysinternals tools from.
  .PARAMETER OutFile
      The path to save the downloaded zip file to.
  .PARAMETER Destination
      The path to extract the Sysinternals tools to.
  .PARAMETER RemoveDownloadFile
      Remove the downloaded zip file after extracting the tools.
  .EXAMPLE
      Update-Sysinternals
  .EXAMPLE
      Update-Sysinternals -RemoveDownloadFile

      Files Updated        : 0
      Files Updated List   :
      New Files            : 3
      New Files List       : {hex2dec.exe, pipelist.exe, procexp.chm}
      Extracted Files      : 3
      Extracted Files List : {hex2dec.exe, pipelist.exe, procexp.chm}
  .OUTPUTS
      PSCustomObject
  #>
  [CmdletBinding()]
  param (
      [string]
      $Uri = 'https://download.sysinternals.com/files/SysinternalsSuite.zip',
      [string]
      $OutFile = "$($env:HomeDrive)$($env:HOMEPATH)\Downloads\SysinternalsSuite.zip",
      [string]
      $Destination = "$env:HomeDrive\SysInternals",
      [switch]
      $RemoveDownloadFile
  )

  $obj = [PSCustomObject]@{
      'Files Updated'        = 0
      'Files Updated List'   = @()
      'New Files'            = 0
      'New Files List'       = @()
      'Extracted Files'      = 0
      'Extracted Files List' = @()
  }

  try {
      # Download the new zip file of tools
      Invoke-WebRequest -Uri $Uri -OutFile $OutFile -ErrorAction Stop
      # Get the list of files before the update
      if (!(Test-Path -Path $Destination)) {
          $null = New-Item -Path $Destination -ItemType Directory -Force
      }
      $Files = Get-ChildItem -Path $Destination
      # Kill any running sysinternals apps processes that may be locked
      $Running = Get-Process zoomit*, desktops*, procexp* -ErrorAction SilentlyContinue
      $Paths = $Running | Where-Object { $_.name -notlike '*64' } | Select-Object -Property Path
      if ($Running) {
          $Running | Stop-Process -Force -ErrorAction Stop
      }
      Add-Type -AN System.IO.Compression.FileSystem
      $zip = [IO.Compression.ZipFile]::OpenRead($OutFile)
      $extractedCount = 0
      if ($null -eq $Files) {
          $obj.'New Files' = $zip.Entries
      } else {
          $fileDiff = Compare-Object -ReferenceObject $Files.Name -DifferenceObject $zip.Entries.Name | Where-Object { $_.SideIndicator -eq '=>' } | Select-Object -ExpandProperty InputObject
          $obj.'New Files List' = $zip.Entries | Where-Object { $_.Name -in $fileDiff }
          $obj.'New Files' = $obj.'New Files List'.Count
      }
      if ($obj.'New Files' -gt 0) {
          $obj.'New Files List' |
              ForEach-Object {
                  #Extract the selected item(s)
                  Write-Verbose -Message ('Extracting new file: {0}' -f $_.Name)
                  $ExtractFileName = $_.Name
                  $obj.'Extracted Files List' += $_.Name
                  $ExtractFileNamePath = ("$Destination\$ExtractFileName")
                  [System.IO.Compression.ZipFileExtensions]::ExtractToFile($_, $ExtractFileNamePath, $true)
                  $extractedCount++
              }
      }
      $filter = Get-ChildItem -Path $OutFile | Select-Object LastWriteTime | Sort-Object LastWriteTime | Select-Object -ExpandProperty LastWriteTime -Last 1
      $obj.'Files Updated List' = $zip.Entries | Where-Object { $_.LastWriteTime -gt $filter }
      $obj.'Files Updated' = $obj.'Files Updated List'.Count
      if ($obj.'Files Updated' -gt 0) {
          $obj.'Files Updated List' |
              ForEach-Object {
                  #Extract the selected item(s)
                  Write-Verbose -Message ('Extracting updated file: {0}' -f $_.Name)
                  $ExtractFileName = $_.Name
                  $obj.'Extracted Files List' += $_.Name
                  $ExtractFileNamePath = ("$Destination\$ExtractFileName")
                  [System.IO.Compression.ZipFileExtensions]::ExtractToFile($_, $ExtractFileNamePath, $true)
                  $extractedCount++
              }
      }
      $obj.'Extracted Files' = $extractedCount
      if ($obj.'Extracted Files' -gt 0) {
          Write-Verbose -Message ('Extracted {0} new or updated files.' -f $obj.'Extracted Files')
      } else {
          Write-Verbose -Message 'No new or updated files extracted.'
          $obj.'Extracted Files List' = $null
      }
      if ($RemoveDownloadFile) {
          $zip.Dispose()
          Remove-Item -Path $OutFile -Force
      }
      Write-Output -InputObject $obj
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
