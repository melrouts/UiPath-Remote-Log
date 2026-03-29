<#
.SYNOPSIS
    Watch UiPath Bot execution logs remotely in real time.

.DESCRIPTION
    Connects to a remote host via PowerShell Remoting and tails UiPath
    execution log files, displaying entries with colour-coded output based
    on log level.  Supports secure credential prompts, an optional JSON
    configuration file and per-run parameter overrides.

.PARAMETER HostName
    Name or IP address of the remote machine running the UiPath Robot.
    Overrides the value in the configuration file.

.PARAMETER Domain
    Windows domain to use when authenticating against the remote host.
    Overrides the value in the configuration file.

.PARAMETER UserName
    Domain user account to authenticate with.
    Overrides the value in the configuration file.

.PARAMETER LogDate
    Date of the log file to monitor, formatted as yyyy-MM-dd.
    Defaults to today's date.

.PARAMETER TailLines
    Number of existing log lines to display before starting live monitoring.
    Defaults to 5.

.PARAMETER LogLevel
    Minimum log level to display.  Accepted values: Trace, Debug, Info,
    Warn, Error, Fatal.  Defaults to Trace (show everything).

.PARAMETER ConfigPath
    Path to a JSON configuration file.  Defaults to config.json in the
    same directory as this script.

.PARAMETER Credential
    Pre-built PSCredential object.  When provided the script skips the
    interactive credential prompt.

.EXAMPLE
    .\UiPath-Remote-Log.ps1 -HostName "robot-pc" -Domain "CORP" -UserName "svc-uipath"

.EXAMPLE
    .\UiPath-Remote-Log.ps1 -HostName "robot-pc" -Domain "CORP" -UserName "svc-uipath" -LogLevel Warn

.EXAMPLE
    $cred = Get-Credential
    .\UiPath-Remote-Log.ps1 -HostName "robot-pc" -Credential $cred -TailLines 20

.NOTES
    Requires PowerShell Remoting (WinRM) to be enabled on the remote host.
    Author  : Eduard.Garanskij@rpa247.com
    Version : 2.0
#>

[CmdletBinding()]
param (
    [Parameter(HelpMessage = "Remote host name or IP address")]
    [string]$HostName,

    [Parameter(HelpMessage = "Windows domain")]
    [string]$Domain,

    [Parameter(HelpMessage = "Domain user account")]
    [string]$UserName,

    [Parameter(HelpMessage = "Log file date (yyyy-MM-dd). Defaults to today.")]
    [ValidatePattern('^\d{4}-\d{2}-\d{2}$')]
    [string]$LogDate = (Get-Date -Format "yyyy-MM-dd"),

    [Parameter(HelpMessage = "Number of existing lines to show before live monitoring")]
    [ValidateRange(1, 1000)]
    [int]$TailLines = 5,

    [Parameter(HelpMessage = "Minimum log level to display")]
    [ValidateSet("Trace", "Debug", "Info", "Warn", "Error", "Fatal")]
    [string]$LogLevel = "Trace",

    [Parameter(HelpMessage = "Path to JSON configuration file")]
    [string]$ConfigPath = (Join-Path $PSScriptRoot "config.json"),

    [Parameter(HelpMessage = "PSCredential object (skips interactive prompt when provided)")]
    [System.Management.Automation.PSCredential]$Credential
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Load optional configuration file
# ---------------------------------------------------------------------------
function Import-Config {
    param([string]$Path)

    $cfg = @{}
    if (Test-Path -LiteralPath $Path) {
        try {
            $cfg = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable
            Write-Verbose "Configuration loaded from '$Path'."
        } catch {
            Write-Warning "Could not parse configuration file '$Path': $_"
        }
    }
    return $cfg
}

# ---------------------------------------------------------------------------
# Colour mapping for log entries
# ---------------------------------------------------------------------------
function Get-LogColor {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory)]
        [string]$LogEntry
    )

    switch -Regex ($LogEntry) {
        '(?i)(Processing Transaction Number|execution ended|Transaction Successful|success|completed|finished)' { return "Green" }
        '(?i)(WARN|warning)'   { return "Yellow" }
        '(?i)(ERROR|exception|failed|failure)' { return "Red" }
        '(?i)(FATAL|critical)'  { return "Magenta" }
        '(?i)(INFO|information)' { return "Cyan" }
        '(?i)(DEBUG|verbose)'   { return "Gray" }
        '(?i)(TRACE)'           { return "DarkGray" }
        default                 { return "White" }
    }
}

# ---------------------------------------------------------------------------
# Numeric rank for log-level filtering
# ---------------------------------------------------------------------------
function Get-LevelRank {
    param([string]$Level)
    switch ($Level.ToUpper()) {
        "TRACE" { return 0 }
        "DEBUG" { return 1 }
        "INFO"  { return 2 }
        "WARN"  { return 3 }
        "ERROR" { return 4 }
        "FATAL" { return 5 }
        default { return 0 }
    }
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
Clear-Host

# --- Merge config file values with parameter values (params win) -----------
$cfg = Import-Config -Path $ConfigPath

if (-not $HostName) {
    $HostName = if ($cfg.ContainsKey("host")) { $cfg["host"] } else { "" }
}
if (-not $Domain) {
    $Domain = if ($cfg.ContainsKey("domain")) { $cfg["domain"] } else { "" }
}
if (-not $UserName) {
    $UserName = if ($cfg.ContainsKey("user")) { $cfg["user"] } else { "" }
}
if ($cfg.ContainsKey("tailLines") -and $TailLines -eq 5) {
    $TailLines = [int]$cfg["tailLines"]
}
if ($cfg.ContainsKey("logLevel") -and $LogLevel -eq "Trace") {
    $LogLevel = $cfg["logLevel"]
}

# --- Validate required settings --------------------------------------------
if (-not $HostName) {
    throw "HostName is required. Provide it via -HostName parameter or 'host' key in config.json."
}
if (-not $UserName) {
    throw "UserName is required. Provide it via -UserName parameter or 'user' key in config.json."
}

# --- Verify remote host is reachable ---------------------------------------
Write-Host "Checking connectivity to '$HostName'..." -ForegroundColor Cyan
if (-not (Test-Connection -ComputerName $HostName -Count 1 -Quiet -ErrorAction SilentlyContinue)) {
    throw "Remote host '$HostName' is not reachable. Check the host name and network connectivity."
}
Write-Host "Host '$HostName' is reachable." -ForegroundColor Green

# --- Build credential -------------------------------------------------------
if (-not $Credential) {
    $accountName = if ($Domain) { "$Domain\$UserName" } else { $UserName }
    Write-Host "Enter credentials for '$accountName':" -ForegroundColor Cyan
    $Credential = Get-Credential -UserName $accountName -Message "Remote UiPath log monitor – enter your credentials"
}

# --- Remote script block ---------------------------------------------------
$minLevelRank = Get-LevelRank -Level $LogLevel

$remoteBlock = {
    param([string]$Date, [int]$Tail, [int]$MinRank)

    function Get-LogColor {
        param([string]$LogEntry)
        switch -Regex ($LogEntry) {
            '(?i)(Processing Transaction Number|execution ended|Transaction Successful|success|completed|finished)' { return "Green" }
            '(?i)(WARN|warning)'   { return "Yellow" }
            '(?i)(ERROR|exception|failed|failure)' { return "Red" }
            '(?i)(FATAL|critical)'  { return "Magenta" }
            '(?i)(INFO|information)' { return "Cyan" }
            '(?i)(DEBUG|verbose)'   { return "Gray" }
            '(?i)(TRACE)'           { return "DarkGray" }
            default                 { return "White" }
        }
    }

    function Get-LevelRank {
        param([string]$Level)
        switch ($Level.ToUpper()) {
            "TRACE" { return 0 }
            "DEBUG" { return 1 }
            "INFO"  { return 2 }
            "WARN"  { return 3 }
            "ERROR" { return 4 }
            "FATAL" { return 5 }
            default { return 0 }
        }
    }

    $logPath = Join-Path $Env:USERPROFILE "AppData\Local\UiPath\Logs\${Date}_Execution.log"

    if (-not (Test-Path -LiteralPath $logPath)) {
        Write-Warning "Log file not found: $logPath"
        return
    }

    $pattern = 'message":"(?<msg>[^"]*)"[^}]*level":"(?<lvl>[^"]*)"[^}]*timeStamp":"(?<date>\d{4}-\d{2}-\d{2})T(?<time>\d{2}:\d{2}:\d{2})'

    Get-Content -LiteralPath $logPath -Wait -Tail $Tail |
        Select-String -Pattern $pattern -AllMatches |
        ForEach-Object {
            $m   = $_.Matches[0]
            $msg = $m.Groups["msg"].Value
            $lvl = $m.Groups["lvl"].Value
            $ts  = "$($m.Groups['time'].Value)"

            if ((Get-LevelRank -Level $lvl) -ge $MinRank) {
                $line = "$ts [$lvl] $msg"
                Write-Host -ForegroundColor (Get-LogColor $line) $line
            }
        }
}

# --- Invoke remote monitoring ----------------------------------------------
try {
    Write-Host "Connecting to '$HostName' and monitoring log for $LogDate..." -ForegroundColor Cyan
    Write-Host "Log level filter: $LogLevel  |  Tail lines: $TailLines" -ForegroundColor DarkCyan
    Write-Host "Press Ctrl+C to stop.`n" -ForegroundColor DarkCyan

    Invoke-Command `
        -ComputerName $HostName `
        -Credential   $Credential `
        -ArgumentList $LogDate, $TailLines, $minLevelRank `
        -ScriptBlock  $remoteBlock

} catch [System.Management.Automation.Remoting.PSRemotingTransportException] {
    Write-Error "Remote connection failed: $_"
    Write-Host "Ensure WinRM is enabled on '$HostName' and the credentials are correct." -ForegroundColor Yellow
} catch {
    Write-Error "An unexpected error occurred: $_"
}
