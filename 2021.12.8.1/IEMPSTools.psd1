﻿#
# Module manifest for module 'IEMPSTools'
#
# Generated by: "IEM"
#

@{

  # Script module or binary module file associated with this manifest.
  ModuleToProcess = 'IEMPSTools.psm1'
  ModuleVersion = '2021.12.8.01'
  CompatiblePSEditions = 'Core'
  GUID = 'ab0f4708-f097-4cef-9a00-e49dd7056b37'
  Author = 'Ian E. Martin'
  CompanyName = ''
  Copyright = ''
  Description = 'This Windows PowerShell module contains IEMPSTools'
  PowerShellVersion = '5.1'
  # Name of the Windows PowerShell host required by this module
  PowerShellHostName = ''
  # Minimum version of the Windows PowerShell host required by this module
  PowerShellHostVersion = ''
  # Minimum version of the .NET Framework required by this module
  DotNetFrameworkVersion = '4.5'
  # Minimum version of the common language runtime (CLR) required by this module
  CLRVersion = '4.0'
  # Processor architecture (None, X86, Amd64, IA64) required by this module
  ProcessorArchitecture = ''
  # Modules that must be imported into the global environment prior to importing this module
  RequiredModules = @()
  # Assemblies that must be loaded prior to importing this module
  RequiredAssemblies = @()
  # Script files (.ps1) that are run in the caller's environment prior to importing this module
  ScriptsToProcess = @()
  # Type files (.ps1xml) to be loaded when importing this module
  TypesToProcess = @()
  # Format files (.ps1xml) to be loaded when importing this module
  FormatsToProcess = @(
    'Get-WindowsVolume.Format.ps1xml'
    'Get-WindowsOfflineDisk.Format.ps1xml'
  )
  # Modules to import as nested modules of the module specified in ModuleToProcess
  NestedModules= @()
  # Functions to export from this module
  FunctionsToExport = @(
    'Clear-PersistedCredential'
    'Convert-OSVersion'
    'Convert-PrefixLengthToSubnetMask'
    'Copy-WebFile'
    'Copy-WebFolder'
    'Edit-Notes'
    'Expand-DrivePartition'
    'Expand-DriveVolume'
    'Expand-WindowsDiskPartition'
    'Format-StringWithSpace'
    'Get-AzCredentialFromKeyVault'
    'Get-DriveSpaceInfo'
    'Get-InstalledUpdates'
    'Get-LastUpdatedDate'
    'Get-OSVersion'
    'Get-PersistedCredential'
    'Get-SecondTuesday'
    'Get-UpTime'
    'Get-WindowsDisk'
    'Get-WindowsDiskLocation'
    'Get-WindowsOfflineDisk'
    'Get-WindowsVolume'
    'Import-FunctionToHereString'
    'Join-PSObject'
    'New-IsoFile'
    'Out-Log'
    'Ping-HostToLog'
    'Remove-ExtraFiles'
    'Remove-MisMatchedCertificate'
    'Remove-PersistedCredential'
    'Set-PersistedCredential'
    'Show-ImprovedCredentialPrompt'
    'Split-Username'
    'Test-ElevatedMode'
    'Test-PortOpen'
    'Test-WinRM'
    'Update-PathEnvironmentVariable'
    'Update-Sysinternals'
    'Use-ElevatedMode'
    'restart-servers'
  )
  # Cmdlets to export from this module
  CmdletsToExport = @()
  # Variables to export from this module
  VariablesToExport = @()
  # Aliases to export from this module
  AliasesToExport = @()
  # List of all modules packaged with this module
  ModuleList = @()
  # List of all files packaged with this module
  #FileList =	''

  # Private data to pass to the module specified in ModuleToProcess
  #PrivateData = ''
}
