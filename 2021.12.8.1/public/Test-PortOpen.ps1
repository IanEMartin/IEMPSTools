<#
.SYNOPSIS
    .
.DESCRIPTION
    Tests ports
.PARAMETER ComputerName
    Specifies ComputerName to test whether port is open at.
.PARAMETER Port
    Specifies the port to test.
.PARAMETER Protocol
    Specifies the protocol to test the port with.
.EXAMPLE
    C:\PS> Test-PortOpen.ps1 -ComputerName System1 -port 3389
    Runs the script against System1 testing port 3389 (RDP).
.NOTES
    Date:   2017-06-22
#>
function Test-PortOpen {
  param(
    [Parameter(Mandatory,HelpMessage='Enter a computer name.')]
    [string]$ComputerName,
    [Parameter(Mandatory,HelpMessage='Enter a port number.')]
    [int]$Port,
    [ValidateSet('tcp', 'udp')]
    [string]$protocol='tcp',
    $path
  )

  function test-tcpconnection {
    param([string]$computername, [int]$port)
    try {
      $c = New-Object -TypeName System.Net.Sockets.TcpClient
      $c.Connect($computername, $port)
      $c.Close()
      return $true
    } catch {
      return $false
    }
  }
  function test-udpconnection {
    param([string]$computername, [int]$port)
    try {
      $c = New-Object -TypeName System.Net.Sockets.udpClient
      $c.Connect($ComputerName, $Port)
      $c.Close()
      return $true
    } catch {
      return $false
    }
  }

  if ($null -ne $path) {
    $configuration = import-csv -Path $path
  } else {
    $configuration = ConvertFrom-Csv -InputObject "Dest,Port`r`n$ComputerName,$Port,$Protocol" -Delimiter ','
  }
  foreach ($config in $configuration) {
    $source = 'localhost ({0})' -f $env:COMPUTERNAME
    $dest = $config.Dest
    $port = $config.Port
    $outputObject = [PSCustomObject]@{
      Source = $Source
      Destination = $Dest
      Port = $Port
      Protocol = $config.Protocol
      PortOpen = 'Unknown'
      State = ''
      Exception = $null
      Comment = $config.Comment
    }
    switch ($protocol) {
      'udp' {
        $outputObject.Protocol = 'udp'
        try {
          $connectResponse = test-udpconnection  -computername $Dest -port $Port
          $outputObject.State = 'Ok'
          $outputObject.PortOpen = $connectResponse
        } catch {
          write-verbose "error connecting $source to $dest : $port : $_"
          $outputObject.State = "error connecting $source to $dest : $port : $($_.FullyQualifiedErrorId)"
          $outputObject.PortOpen = $false
          $outputObject.Exception = $_
        }
      }
      Default {
        $outputObject.Protocol = 'tcp'
        try {
          $connectResponse = test-tcpconnection  -computername $Dest -port $Port
          $outputObject.State = 'Ok'
          $outputObject.PortOpen = $connectResponse
        } catch {
          write-verbose "error connecting $source to $dest : $port : $_"
          $outputObject.State = "error connecting $source to $dest : $port : $($_.FullyQualifiedErrorId)"
          $outputObject.PortOpen = $false
          $outputObject.Exception = $_
        }
      }
    }
    $outputObject
  }
}
