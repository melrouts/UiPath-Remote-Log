# UiPath-Remote-Log – Usage Examples
#
# This file demonstrates different ways to invoke UiPath-Remote-Log.ps1.
# Run these commands from the root of the repository.

$ScriptPath = Join-Path $PSScriptRoot "..\UiPath-Remote-Log.ps1"

# ---------------------------------------------------------------------------
# Example 1 – Minimal: prompts for credentials, monitors today's log
# ---------------------------------------------------------------------------
& $ScriptPath -HostName "robot-pc" -Domain "CORP" -UserName "svc-uipath"

# ---------------------------------------------------------------------------
# Example 2 – Monitor a specific date's log
# ---------------------------------------------------------------------------
& $ScriptPath -HostName "robot-pc" -Domain "CORP" -UserName "svc-uipath" `
    -LogDate "2024-03-15"

# ---------------------------------------------------------------------------
# Example 3 – Show only warnings and above (Warn, Error, Fatal)
# ---------------------------------------------------------------------------
& $ScriptPath -HostName "robot-pc" -Domain "CORP" -UserName "svc-uipath" `
    -LogLevel Warn

# ---------------------------------------------------------------------------
# Example 4 – Show only errors and critical failures
# ---------------------------------------------------------------------------
& $ScriptPath -HostName "robot-pc" -Domain "CORP" -UserName "svc-uipath" `
    -LogLevel Error

# ---------------------------------------------------------------------------
# Example 5 – Show last 20 lines before starting live monitoring
# ---------------------------------------------------------------------------
& $ScriptPath -HostName "robot-pc" -Domain "CORP" -UserName "svc-uipath" `
    -TailLines 20

# ---------------------------------------------------------------------------
# Example 6 – Use a pre-built credential (useful in automation / CI)
# ---------------------------------------------------------------------------
$securePassword = Read-Host -Prompt "Password" -AsSecureString
$credential = New-Object System.Management.Automation.PSCredential("CORP\svc-uipath", $securePassword)

& $ScriptPath -HostName "robot-pc" -Credential $credential

# ---------------------------------------------------------------------------
# Example 7 – Load settings from a configuration file
# ---------------------------------------------------------------------------
& $ScriptPath -ConfigPath (Join-Path $PSScriptRoot "..\config.json")

# ---------------------------------------------------------------------------
# Example 8 – Config file + parameter override (parameter wins)
# ---------------------------------------------------------------------------
& $ScriptPath `
    -ConfigPath (Join-Path $PSScriptRoot "..\config.json") `
    -LogLevel Error `
    -TailLines 50
