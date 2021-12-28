<#
    .SYNOPSIS
    Removes extraneous files from remote systems to free up storage space
    .DESCRIPTION
    Removes extraneous files from remote systems to free up storage space.  It can do a single system or a list of systems in a text file.
    It will only work on objects that it has permissions to remove.
    Currently removes from the following folders:
    - '\\<MachineName>\c$\windows\ccmcache'
    - '\\<MachineName>\c$\windows\temp'
    - '\\<MachineName>\c$\MSOCache\All Users'
    - '\\<MachineName>\c$\Windows\Prefetch'
    - '\\<MachineName>\c$\ProgramData\Microsoft\Windows\WER'
    - '\\<MachineName>\c$\ProgramData\Microsoft\Windows\Power Efficiency Diagnostics'
    - '\\<MachineName>\c$\Windows\Minidump'
    - '\\<MachineName>\c$\ProgramData\McAfee\Host Intrusion Prevention'

    .PARAMETER file
    Specifies a text file with a list of systems to process.
    .PARAMETER ComputerName
    Specifies a single system or comma-separated list of systems to processs.
    .PARAMETER ccmcache
    Creates a log file named Remove-ExtraFiles.log
    .PARAMETER log
    Creates a log file named Remove-ExtraFiles.log
    .EXAMPLE
    Remove-ExtraFiles.ps1 -ComputerName testsystem
    Processes a single system.
    .NOTES
    Author: Ian Martin
    Date:   2015-08-30
#>
#Requires -Version 3.0
function Remove-ExtraFiles {
  [CmdletBinding()]
  param (
    [string[]]$ComputerName,
    [switch]$ccmcache,
    [string]$Log = ''
  )

  function Write-Stuff {
    [CmdletBinding()]
    Param
    (
      [Parameter(Mandatory)]
      [ValidateNotNullOrEmpty()]
      [string]
      $Text,
      [switch]
      $Output,
      [string]
      $Log,
      [switch]
      $Append
    )
    Begin {
    }
    Process {
      if ($Output -eq $true) {
        Write-Output -InputObject $Text
      }
      if ($Log -ne '') {
        if ($Append -eq $true) {
          $Text | Out-File -FilePath $Log -Append
        } else {
          $Text | Out-File -FilePath $Log
        }
      }
      if ($PSCmdlet.MyInvocation.BoundParameters['Verbose'].IsPresent -eq $true) {
        Write-Verbose -Message $Text
      }
    }
    End {
    }
  }
  function Remove-FilesInPath {
    [CmdletBinding()]
    Param
    (
      [Parameter(Mandatory)]
      [ValidateNotNullOrEmpty()]
      [string]
      $Path,
      [string]
      $Log
    )
    Begin {
    }
    Process {
      If (Test-Path -Path $Path) {
        If (Test-Path -Path $Path -PathType Container) {
          $Info = ("[{0}] Removing files from '{1}'." -f $machine.ToUpper(), ($Path))
          Write-Stuff -Text $Info -Log $Log -Append -Verbose:($PSCmdlet.MyInvocation.BoundParameters['Verbose'].IsPresent -eq $true)
          $filesinfolder = Get-ChildItem -Path $Path -Exclude $ignorefiletypes -File -Recurse -ErrorAction SilentlyContinue | Select-Object -Property FullName, Name, Length
          foreach ($fileobject in $filesinfolder) {
            if ($Log -ne '' -and ($PSCmdlet.MyInvocation.BoundParameters['Verbose'].IsPresent -eq $true)) {
              $Info = ("[{0}] Removing file '{1}'." -f $machine.ToUpper(), $fileobject.FullName)
              Write-Stuff -Text $Info -Log $Log -Append
            }
              Remove-Item -Path $fileobject.FullName -Force -ErrorAction SilentlyContinue -ErrorVariable $ErrRemoveItem -Verbose:($PSCmdlet.MyInvocation.BoundParameters['Verbose'].IsPresent -eq $true) #-WhatIf
              if ($ErrRemoveItem) {
              # get error record
              [Management.Automation.ErrorRecord]$e = $_
              # retrieve information about runtime error
              $info = [PSCustomObject]@{
                Exception = $e.Exception.Message
                Reason    = $e.CategoryInfo.Reason
                Target    = $e.CategoryInfo.TargetName
                Script    = $e.InvocationInfo.ScriptName
                Line      = $e.InvocationInfo.ScriptLineNumber
                Column    = $e.InvocationInfo.OffsetInLine
              }
              # output information. Post-process collected info, and log info (optional)
              Write-Stuff -Text "$($info.Exception) $($info.Reason) (Line $($info.Line) Column $($info.Column))" -Log $Log -Append -Verbose:($PSCmdlet.MyInvocation.BoundParameters['Verbose'].IsPresent -eq $true)
          }
          }
        } else {
          Remove-Item -Path $Path -Force -ErrorAction SilentlyContinue -ErrorVariable e
          if ($e) {
            $Info = ('Error removing folder {0}.  Error: {1}' -f $fileobject.FullName, $e)
            Out-Log -LogData $Info -Path $LogFilePath -FileName $LogFileName -ErrorData -Verbose:($PSCmdlet.MyInvocation.BoundParameters['Verbose'].IsPresent -eq $true)
          }
        }
      } Else {
        $Info = ("[{0}] Unable to find path '{1}'." -f $machine.ToUpper(), ($Path))
        Write-Stuff -Text $Info -Log $Log -Append -Verbose:($PSCmdlet.MyInvocation.BoundParameters['Verbose'].IsPresent -eq $true)
      }
    }
    End {
    }
  } # end function Remove-FilesInPath

  function Get-CDriveSpaceInfo {
    [CmdletBinding()]
    param
    (
      [Parameter(
        ValueFromPipeline,
        ValueFromPipelineByPropertyName)]
      $ComputerName
    )

    Begin {
      $value = '' | Select-Object -Property ComputerName, SizeGb, FreeSpaceGb, Service
    }

    Process {
      $value.Service = ''
      $value.ComputerName = $ComputerName
      $value.SizeGb = $null
      $value.FreeSpaceGb = $null
      if ($null -ne (Test-WSMan -ComputerName $ComputerName -ErrorAction SilentlyContinue)) {
        $value.Service = 'WSMan (CIMInstance)'
        $diskinfo = Get-CimInstance -ComputerName $ComputerName -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorVariable DiskCheckError -ErrorAction SilentlyContinue | Select-Object -Property Size, FreeSpace
        if ($DiskCheckError) {
          $value.Service = 'WMIFallback'
          try {
            $diskinfo = Get-WmiObject -ComputerName $ComputerName -Class Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorVariable WMIDiskCheckError -ErrorAction SilentlyContinue | Select-Object -Property Size, FreeSpace
            if ($WMIDiskCheckError) {
              # List error info
            }
          } catch {
            # Continue silently
          }
        }
      } else {
        $value.Service = 'WMI'
        $diskinfo = Get-WmiObject -ComputerName $ComputerName -Class Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction SilentlyContinue | Select-Object -Property Size, FreeSpace
      }
      if ($null -ne $diskinfo) {
        $value.SizeGb = [math]::round(($diskinfo.Size / 1Gb), 2)
        $value.FreeSpaceGb = [math]::round(($diskinfo.FreeSpace / 1Gb), 2)
      }
      return $value
    }
  } # end Get-CDriveSpaceInfo

  if ($Log -ne '') {
    $Info = "Started: $(Get-Date)"
    Write-Stuff -Text $Info -Log $Log -Verbose:($PSCmdlet.MyInvocation.BoundParameters['Verbose'].IsPresent -eq $true)
  }

  $listcount = $ComputerName.Count
  $count = 0
  $ignorefiletypes = '*.rnd'

  foreach ($machine in $ComputerName) {
    if ($machine -eq 'localhost') {
      $machine = $env:COMPUTERNAME
    }
    $count++
    $WSManAvailable = Test-WSMan -ComputerName $Machine -ErrorAction SilentlyContinue
    Write-Verbose "WSMan: $WSManAvailable"
    $TestPath = '\\{0}\c$\' -f $machine
    If ((Test-Path -Path $TestPath)) {
      $Info = ('[{0}] Path to system verified.' -f $machine.ToUpper())
      Write-Verbose -Message $Info
      #Check disk free space
      $disk = Get-CDriveSpaceInfo -ComputerName $Machine
      $DiskSizeGb = $disk.SizeGb
      $DiskFreeSpaceGbOriginal = $disk.FreeSpaceGb
      $Info = ('[{0}] Processing... this is system {1} of {2}' -f $machine.ToUpper(), $count, $listcount)
      Write-Verbose -Message $Info
      Write-Stuff -Text $Info -Log $Log -Append
      if ($ccmcache) {
        $CleanupPath = ('\\{0}\c$\windows\ccmcache' -f ($machine))
        Remove-FilesInPath -Path $CleanupPath -Log $Log -Verbose:($PSCmdlet.MyInvocation.BoundParameters['Verbose'].IsPresent -eq $true)
      }
      $CleanupPath = ('\\{0}\c$\windows\temp' -f ($machine))
      Remove-FilesInPath -Path $CleanupPath -Log $Log -Verbose:($PSCmdlet.MyInvocation.BoundParameters['Verbose'].IsPresent -eq $true)
      $CleanupPath = ('\\{0}\c$\MSOCache\All Users' -f ($machine))
      Remove-FilesInPath -Path $CleanupPath -Log $Log -Verbose:($PSCmdlet.MyInvocation.BoundParameters['Verbose'].IsPresent -eq $true)
      $CleanupPath = ('\\{0}\c$\Windows\Prefetch' -f ($machine))
      Remove-FilesInPath -Path $CleanupPath -Log $Log -Verbose:($PSCmdlet.MyInvocation.BoundParameters['Verbose'].IsPresent -eq $true)
      $CleanupPath = ('\\{0}\c$\ProgramData\Microsoft\Windows\WER' -f ($machine))
      Remove-FilesInPath -Path $CleanupPath -Log $Log -Verbose:($PSCmdlet.MyInvocation.BoundParameters['Verbose'].IsPresent -eq $true)
      $CleanupPath = ('\\{0}\c$\ProgramData\Microsoft\Windows\Power Efficiency Diagnostics' -f ($machine))
      Remove-FilesInPath -Path $CleanupPath -Log $Log -Verbose:($PSCmdlet.MyInvocation.BoundParameters['Verbose'].IsPresent -eq $true)
      $CleanupPath = ('\\{0}\c$\Windows\Minidump' -f ($machine))
      Remove-FilesInPath -Path $CleanupPath -Log $Log -Verbose:($PSCmdlet.MyInvocation.BoundParameters['Verbose'].IsPresent -eq $true)
      $CleanupPath = ('\\{0}\c$\ProgramData\McAfee\Host Intrusion Prevention' -f ($machine))
      Remove-FilesInPath -Path $CleanupPath -Log $Log -Verbose:($PSCmdlet.MyInvocation.BoundParameters['Verbose'].IsPresent -eq $true)
      $CleanupPath = ('\\{0}\Windows\System32\FxsTmp' -f ($machine))
      Remove-FilesInPath -Path $CleanupPath -Log $Log -Verbose:($PSCmdlet.MyInvocation.BoundParameters['Verbose'].IsPresent -eq $true)
      # Clean up user profile files
      if ($WSManAvailable) {
        $ComputerSystemInfo = Get-CimInstance -ComputerName $Machine -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
      } else {
        $ComputerSystemInfo = Get-WmiObject -ComputerName $Machine -Class Win32_ComputerSystem -ErrorAction SilentlyContinue
      }
      if ($ComputerSystemInfo.Manufacturer -like '*vmware*') {
        Write-Verbose -Message 'Virtual machine!  Cleaning up things that should not be stored on a virtual machine!'
        $CleanupPath = '\\{0}\c$\' -f ($machine)
        Get-ChildItem -File $CleanupPath -Filter *.iso | Remove-Item -Force -Verbose #:($PSCmdlet.MyInvocation.BoundParameters['Verbose'].IsPresent -eq $true)
      }
      $userdirs = get-childitem -Directory ('\\{0}\c$\Users\' -f $machine) -Exclude '.NET*', 'Public', 'Default*', 'MSSQL*', 'UpdatusUser*'
      foreach ($userdir in $userdirs) {
        # Clean up ThinApp tmp files
        $CleanupPath = '{0}\AppData\Roaming\Thinstall\' -f ($Userdir.FullName)
        if (Test-Path -Path $CleanupPath) {
          $ThinAppPath = $null
          $ThinAppPath = get-childitem -Directory $CleanupPath -filter '*Horizon Client*'
          if ($null -ne $ThinAppPath) {
            if (Test-Path -Path $CleanupPath) {
              $CleanupPath = '{0}\%SystemSystem(x64)%\FxsTmp' -f ($ThinAppPath.FullName)
              Remove-Item -Path ('{0}\*.tmp' -f $CleanupPath) -Verbose:($PSCmdlet.MyInvocation.BoundParameters['Verbose'].IsPresent -eq $true)
            }
          }
        }
        # Clean up huge files that should not be stored on a virtual machine profile
        if ($ComputerSystemInfo.Manufacturer -like '*vmware*') {
          $CleanupPath = '{0}\Desktop' -f ($Userdir.FullName)
          if (Test-Path -Path $CleanupPath) {
            $RemoveISOs = Get-ChildItem -File $CleanupPath -Filter *.iso -Recurse | Remove-Item -Force -Verbose:($PSCmdlet.MyInvocation.BoundParameters['Verbose'].IsPresent -eq $true)
            if ($null -ne $RemoveISOs) {
              Write-Output -InputObject $RemoveISOs.FullName
            }
          }
          $CleanupPath = '{0}\Downloads' -f ($Userdir.FullName)
          if (Test-Path -Path $CleanupPath) {
            $RemoveISOs = Get-ChildItem -File $CleanupPath -Filter *.iso -Recurse | Remove-Item -Force -Verbose:($PSCmdlet.MyInvocation.BoundParameters['Verbose'].IsPresent -eq $true)
            if ($null -ne $RemoveISOs) {
              Write-Output -InputObject $RemoveISOs.FullName
            }
          }
          $CleanupPath = '{0}\Documents' -f ($Userdir.FullName)
          if (Test-Path -Path $CleanupPath) {
            $RemoveISOs = Get-ChildItem -File $CleanupPath -Filter *.iso -Recurse | Remove-Item -Force -Verbose:($PSCmdlet.MyInvocation.BoundParameters['Verbose'].IsPresent -eq $true)
            if ($null -ne $RemoveISOs) {
              Write-Output -InputObject $RemoveISOs.FullName
            }
          }
        }
      }
      $disk = Get-CDriveSpaceInfo -ComputerName $Machine
      $DiskFreeSpaceGbNow = $disk.FreeSpaceGb
      $Info = ('[{0}] Disk size {1}Gb, Free Space Before {2}Gb, After {3}Gb - determined by {4}' -f $machine.ToUpper(), $DiskSizeGb, $DiskFreeSpaceGbOriginal, $DiskFreeSpaceGbNow, $disk.Service)
      Write-Stuff -Text $Info -Log $Log -Append -Verbose:($PSCmdlet.MyInvocation.BoundParameters['Verbose'].IsPresent -eq $true)
      $CleanedUpGb = $DiskFreeSpaceGbNow - $DiskFreeSpaceGbOriginal
      [pscustomobject][ordered]@{
        "PSComputerName" = $machine
        'SizeGb'         = [math]::round($DiskSizeGb, 2)
        "CleanedUpGb"    = [math]::round(($CleanedUpGb), 2)
        "FreeSpaceGb"    = $DiskFreeSpaceGbNow
      }
    } Else {
      $Info = ('[{0}] Unable to connect.' -f $machine.ToUpper())
      Write-Stuff -Text $Info -Output -Log $Log -Append -Verbose:($PSCmdlet.MyInvocation.BoundParameters['Verbose'].IsPresent -eq $true)
    }
  }
}
