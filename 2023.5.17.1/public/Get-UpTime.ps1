function Get-Uptime {
  [CmdletBinding()]
  param
  (
    [Parameter(
      ValueFromPipeline,
      ValueFromPipelineByPropertyName)]
    $ComputerName = ''
  )

  Begin {
    if ('' -eq $ComputerName) {
      $ComputerName = $env:COMPUTERNAME
    }
    $value = '' | Select-Object -Property ComputerName, LastReboot, Uptime, Days, Hours, Minutes, Seconds, TotalDays, TotalHours, TotalMinutes, TotalSeconds, Service
  }

  Process {
    foreach ($computer in $ComputerName) {
      if ($null -ne (Test-WSMan -ComputerName $computer -ErrorAction SilentlyContinue)) {
        $value.Service = 'WSMan (CIMInstance)'
        $boottime = Get-CimInstance -Class Win32_OperatingSystem -ComputerName $computer | Select-Object -ExpandProperty LastBootUpTime -ErrorVariable QueryError
      } else {
        $value.Service = 'WMI'
        $query = Get-WmiObject -ComputerName $computer -Query 'SELECT LastBootUpTime FROM Win32_OperatingSystem' -ErrorVariable QueryError
        if ($null -eq $query) {
          $boottime = $null
        } else {
          $boottime = $query.ConvertToDateTime($query.LastBootUpTime)
        }
      }
      $now = Get-Date
      $value.ComputerName = $computer
      $value.LastReboot = $boottime
      if ($null -eq $boottime) {
        $value.LastReboot = $QueryError.Exception.Message
        $boottime = Get-Date -Date '01/01/2000'
      }
      $uptime = $now - $boottime
      $value.Uptime = ('{0} Days {1} Hrs {2} Min {3} Sec' -f $uptime.days, $uptime.hours, $uptime.Minutes, $uptime.Seconds)
      $value.Days = $uptime.days
      $value.Hours = $uptime.hours
      $value.Minutes = $uptime.Minutes
      $value.Seconds = $uptime.Seconds
      $value.TotalDays =  [math]::round($uptime.TotalDays,2)
      $value.TotalHours =  [math]::round($uptime.TotalHours,2)
      $value.TotalMinutes =  [math]::round($uptime.TotalMinutes,2)
      $value.TotalSeconds =  [math]::round($uptime.TotalSeconds)
      $value
    }
  }
}
