# Watch UiPath log remote
#
# @2021 Eduard.Garanskij@walmart.com

#############  Variables #############
$log_host = "Your_Host_Name-Here"
$log_domain = "UK"
$log_user = "XXXX"
$log_date = $(Get-Date -Format "yyyy-MM-dd")  ## Default date=today

############# Constants ##############
$log_domain_user = $log_domain+"\"+$log_user
#############
Clear;

$cmd = { 
        function Get-LogColor {
            Param([Parameter(Position=0)]
            [String]$LogEntry)

            process {
                if ($LogEntry.Contains("Processing Transaction Number")) {Return "Green"}
                elseif ($LogEntry.Contains("execution ended")) {Return "Green"}
                elseif ($LogEntry.Contains("Transaction Successful")) {Return "Green"}
                elseif ($LogEntry.Contains("WARN")) {Return "Yellow"}
                elseif ($LogEntry.Contains("exception")) {Return "Red"}
                else {Return "White"}
            }
        }

       $log_path = "$Env:USERPROFILE\AppData\Local\UiPath\Logs\"+$args[1]+"_Execution.log";
       Get-Content $log_path -Wait -Tail 5 | select-string 'message":"([^,"]*).*?timeStamp.*?\d{4}-\d{2}-\d{2}T(\d{2}:\d{2}:\d{2})' -AllMatches | % {$_.Matches.Groups[2].value, $_.Matches.Groups[1].value -join ' '}  | 
           ForEach {Write-Host -ForegroundColor (Get-LogColor $_) $_};           
       };
Invoke-Command -Credential $log_domain_user -ComputerName $log_host -ArgumentList $log_path,$log_date -ScriptBlock @cmd;