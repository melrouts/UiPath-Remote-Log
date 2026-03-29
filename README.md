# UiPath-Remote-Log

A PowerShell script to monitor UiPath Robot execution logs on a remote machine in real time, with colour-coded output, log-level filtering and secure credential handling.

---

## Requirements

| Requirement | Details |
|---|---|
| PowerShell | 5.1 or PowerShell 7+ |
| WinRM | Enabled on the **remote** host (`Enable-PSRemoting -Force`) |
| Network | The machine running this script must be able to reach the remote host |
| Permissions | A domain account with permission to connect via PowerShell Remoting |

---

## Quick Start

```powershell
.\UiPath-Remote-Log.ps1 -HostName "robot-pc" -Domain "CORP" -UserName "svc-uipath"
```

You will be prompted to enter the account password securely. The script will then connect to the remote host and start tailing today's UiPath execution log.

---

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `-HostName` | string | *(required)* | Remote host name or IP address |
| `-Domain` | string | *(optional)* | Windows domain (e.g. `CORP`) |
| `-UserName` | string | *(required)* | Domain/local user account |
| `-LogDate` | string | today | Date of the log file (`yyyy-MM-dd`) |
| `-TailLines` | int | `5` | Lines to display before live monitoring starts |
| `-LogLevel` | string | `Trace` | Minimum level to display: `Trace`, `Debug`, `Info`, `Warn`, `Error`, `Fatal` |
| `-ConfigPath` | string | `config.json` | Path to a JSON configuration file |
| `-Credential` | PSCredential | *(prompt)* | Pre-built credential object (skips interactive prompt) |

---

## Configuration File

Instead of passing parameters every time, you can create a `config.json` file in the same directory as the script. Command-line parameters always override the file.

Copy `config.example.json` to `config.json` and fill in your values:

```json
{
    "host": "robot-pc",
    "domain": "CORP",
    "user": "svc-uipath",
    "tailLines": 10,
    "logLevel": "Info"
}
```

> **Never commit `config.json` to source control** – it may contain sensitive information. It is already listed in `.gitignore`.

---

## Usage Examples

### Monitor today's log (interactive credential prompt)
```powershell
.\UiPath-Remote-Log.ps1 -HostName "robot-pc" -Domain "CORP" -UserName "svc-uipath"
```

### Monitor a specific date's log
```powershell
.\UiPath-Remote-Log.ps1 -HostName "robot-pc" -Domain "CORP" -UserName "svc-uipath" -LogDate "2024-03-15"
```

### Show only warnings and errors
```powershell
.\UiPath-Remote-Log.ps1 -HostName "robot-pc" -Domain "CORP" -UserName "svc-uipath" -LogLevel Warn
```

### Use a saved credential object
```powershell
$cred = Get-Credential
.\UiPath-Remote-Log.ps1 -HostName "robot-pc" -Credential $cred -TailLines 20
```

### Use a configuration file
```powershell
.\UiPath-Remote-Log.ps1 -ConfigPath "C:\configs\uipath-monitor.json"
```

See the [`examples/`](examples/) folder for more scenarios.

---

## Colour Scheme

| Colour | Log Level / Keyword |
|---|---|
| 🟢 Green | Success, completed, transaction successful, execution ended |
| 🟡 Yellow | WARN / Warning |
| 🔴 Red | ERROR / Exception / Failed |
| 🟣 Magenta | FATAL / Critical |
| 🔵 Cyan | INFO / Information |
| ⚪ Gray | DEBUG / Verbose |
| 🔘 DarkGray | TRACE |
| ⬜ White | Everything else |

---

## Troubleshooting

**"Remote host is not reachable"**  
- Verify the host name/IP and that the machine is powered on.  
- Check that ICMP (ping) is not blocked by a firewall.

**"Remote connection failed"**  
- Confirm WinRM is enabled on the remote host: `Test-WSMan -ComputerName <host>`  
- Ensure the account has permission to use PowerShell Remoting.

**"Log file not found"**  
- Check the `-LogDate` value – the file name format is `yyyy-MM-dd_Execution.log`.  
- Confirm the UiPath Robot has run on that date.

---

## Security Notes

- Credentials are collected via `Get-Credential` and never stored in plain text.  
- `config.json` is excluded from source control via `.gitignore`.  
- The `config.example.json` file contains no real credentials and is safe to commit.

---

## License

This project does not currently specify a license. Contact the author for usage terms.

*Author: Eduard.Garanskij@rpa247.com*
