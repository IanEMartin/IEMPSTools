function Ping-HostToLog {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $remoteHost,
        [Parameter(Mandatory = $true)]
        [string]
        $Path,
        [int]
        $Interval = 60,
        [string]
        $Count
    )

    begin {
        $keepGoing = $true
    }

    process {
        $counter = 0
        Write-Host "Testing connection to $remoteHost with $Interval second intervals.  Log file will be created at $Path"
        Do {
            $counter++
            if ($Count -and $counter -eq $Count) {
                $keepGoing = $false
            }
            $logfile = "$Path$($remoteHost)_$(Get-Date -f 'yyyy-MM-dd').log"
            $tc = Test-Connection $remoteHost -Count 1 -ErrorAction SilentlyContinue
            $timeStamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            if ($tc) {
                $tc = $tc | Select-Object -Property @{Name='TimeStamp';Expression={$timeStamp}}, * -ExcludeProperty Reply, DisplayAddress
                if ($counter -eq 1) {
                    $LogInfo = $tc | ConvertTo-Csv -Delimiter "`t"
                    $LogInfo | Out-File -Filepath $logfile -Append
                } else {
                    $LogInfo = $tc | ConvertTo-Csv -Delimiter "`t" | Select-Object -Skip 1
                    $LogInfo | Out-File -Filepath $logfile -Append
                }
            }
            Start-Sleep -Seconds $Interval
        } Until ($keepGoing -eq $false)
    }

    end {
    }
}
