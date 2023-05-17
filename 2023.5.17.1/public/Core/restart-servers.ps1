<# 
    .NAME
        Reboot-Servers
    .DESCRIPTION
       Bulk Reboot of servers
    .NOTES
        Written for use by TechOps Server Operations at Jack Henry and Associates   
        Author:             James May
        Email:              jamay@jackhenry.com
        Last Modified:      02/17/21

        Changelog:
            a1.0            Initial Development
            2.0             Rewrite to accomodate either specified list file or just specify a list. Also added the ability to specify running Chef Client
#>
#Requires -Version 7.0
Function restart-servers {
    param (
        [CmdletBinding()]
        [Parameter(Mandatory = $true,ParameterSetName = 'List')]
        [String]
        $ComputerName,
        [Parameter(Mandatory = $true,ParameterSetName = 'FileList')]
        [String]
        $FileList,
        [switch]$ChefClientRun
    )

    if($ComputerName){
        $Servers = $ComputerName.Split(',')
    }elseif($FileList){
        $Servers = Get-Content $FileList
    }

    $Servers | ForEach-Object -Parallel {
        if(Test-WSMan $server -ErrorAction SilentlyContinue){
            if($ChefClientRun){
                Write-Verbose "Running chef-client on $_"
                Invoke-Command -ComputerName $_ -ScriptBlock {
                    Start-ScheduledTask -TaskName 'chef-client'
                    do{
                        $taskstatus = $(Get-ScheduledTask -TaskName 'chef-client').state
                        Start-Sleep -Seconds 5
                    }while($taskstatus -eq 'Running')
                }
            }
            Write-Verbose "Initiating restart of $_. It will restart in 30 seconds."
            shutdown /m \\$_ /r /f /c "This server is being restarted for maintenance" /t 30 /p:0:0
        }else{
            Write-Error "Failed to connect to $_ over WinRM"
        }
    } -ThrottleLimit 10

}
