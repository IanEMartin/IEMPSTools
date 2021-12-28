function Get-OSVersion {
  [CmdletBinding(
    DefaultParameterSetName = "ByComputerName"
  )]
  [OutputType(
    [PSCustomObject]
  )]

  param (
    [Parameter(
      ParameterSetName = "ByComputerName",
      ValueFromPipeline = $true,
      ValueFromPipelineByPropertyName = $true
    )]
    [ValidateScript( {
        if (Test-Connection -ComputerName $_ -Count 1 -Quiet) {
          return $true
        } else {
          throw "Failed to contact '$_'."
        }
      })]
    [Alias(
      "ComputerName"
    )]
    [String[]]
    $Name = $env:COMPUTERNAME,

    [Parameter(
      ParameterSetName = "ByComputerName"
    )]
    [System.Management.Automation.PSCredential]
    $Credential = [PSCredential]::Empty,

    [Parameter(
      ParameterSetName = "ByCimSession",
      ValueFromPipeline = $true,
      ValueFromPipelineByPropertyName = $true
    )]
    [Microsoft.Management.Infrastructure.CimSession[]]
    $CimSession
  )

  #TODO: Add functionality for *nix and MasOS versions

  Begin {

    $WinClientVersions = [ordered]@{
      '6.1.760' = 'Base'
      '6.1.7601' = 'Service Pack 1'
      '6.2.9200' = 'Base'
      '6.2.9300' = 'Base'
      '6.3.9600' = 'Update 1'
      '10.0.10240' = '1507'
      '10.0.10586' = '1511'
      '10.0.14393' = '1607'
      '10.0.15063' = '1703'
      '10.0.16299' = '1709'
      '10.0.17134' = '1803'
    }
    $output = $null
  }

  Process {
    switch ($PSCmdlet.ParameterSetName) {
      "ByComputerName" {
        if ($IsWindows) {

        }
        $ByMethod = 'WMI'
        foreach ($nameValue in $Name) {
          if ($nameValue -eq 'localhost') {
            $nameValue = $env:COMPUTERNAME
          }
          $OSVersion = $null
          if (Test-WSMan -ComputerName $nameValue -ErrorAction SilentlyContinue) {
            $ByMethod = 'CIM'
            $osInformation = Get-CimInstance -ComputerName $nameValue -ClassName Win32_OperatingSystem -Property Caption, LastBootUpTime, Version
          } else {
            try {
              $osInformation = Get-WmiObject -ComputerName $nameValue -Class Win32_OperatingSystem -Property Caption, LastBootUpTime, Version -Credential $Credential -ErrorAction Stop
            } catch {
              Write-Error -Message "Failed to query WMI on '$nameValue'." -RecommendedAction "Verify WMI access is not being blocked by the firewall."
              continue
            }
          }
          if ($env:COMPUTERNAME -match $nameValue) {
            $OSVersion = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name ReleaseId -ErrorAction SilentlyContinue).ReleaseId
          } else {
            $OSVersion = Invoke-Command -ComputerName $nameValue -ScriptBlock {(Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name ReleaseId -ErrorAction SilentlyContinue).ReleaseId} #DevSkim: ignore DS104456
          }
          if ($null -eq $OSVersion) {
            if ($osInformation.Caption -match 'Server') {
              $OSVersion = 'Base'
            } else {
              $OSVersion = $WinClientVersions.Get_Item($osInformation.Version)
            }
          }
          $output = [PSCustomObject]@{
            PSComputerName     = $nameValue
            Caption            = $osInformation.Caption
            Version            = $OSVersion
            Build              = $osInformation.Version
            DeterminedByMethod = $ByMethod
          }
          Write-Output -InputObject $output
        }
      }
      "ByCimSession" {
        $ByMethod = 'CIMSession'
        foreach ($cimSessionValue in $CimSession) {
          $OSVersion = $null
          $osInformation = Get-CimInstance -CimSession $cimSessionValue -ClassName Win32_OperatingSystem -Property Caption, LastBootUpTime, Version
          $OSVersion = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name ReleaseId -ErrorAction SilentlyContinue).ReleaseId
          if ($null -eq $OSVersion) {
            if ($osInformation.Caption -match 'Server') {
              $OSVersion = 'Base'
            } else {
              $OSVersion = $WinClientVersions.Get_Item($osInformation.Version)
            }
          }
          $output = [PSCustomObject]@{
            PSComputerName     = $cimSessionValue.ComputerName
            Caption            = $osInformation.Caption
            Version            = $OSVersion
            Build              = $osInformation.Version
            DeterminedByMethod = $ByMethod
          }
          Write-Output -InputObject $output
        }
      }
    }
  }

  End {
  }
}
