# Hermes MCP-Remote Bridge Watchdog

**Issue:** #2014
**Version:** 1.0.0
**Date:** 2026-05-06
**Owner:** myia-po-2026

---

## Overview

The Hermes MCP-Remote Bridge Watchdog monitors the `mcp-remote` process running inside Hermes Docker containers and automatically restarts containers when the bridge enters a `ClosedResourceError` state (fails to reconnect after upstream outages).

## Problem Statement

### Incident History

- **2026-05-04**: Docker Desktop crash overnight (01:28→12:15) → Hermes silent for 10h47, required manual container restart
- **2026-05-06 ~10:22-10:32Z**: Wedge `docker info` correlated with Qdrant mount drift → Hermes bridge stuck in `ClosedResourceError`, required manual container restart

### Root Cause

The `mcp-remote` (Node.js) bridge does NOT automatically reconnect when the upstream proxy returns. It remains alive but in a permanent `ClosedResourceError` state, causing all MCP calls to timeout. Only a container restart recycles the bridge.

### Impact

- 8-10 hours of Hermes silence per occurrence (2 incidents in <72h)
- Missing cluster coordination (Hermes is secretary/reporter)
- Operational cost (manual intervention required)
- Credit cost (session re-runs, backlog catchup post-recovery)

---

## Solution

### Watchdog Features

1. **Multi-method Detection**:
   - **Log scraping**: Scans container logs for error patterns (`ClosedResourceError`, `MCP tool.*call failed`, `ReadTimeout`, etc.)
   - **Process health**: Checks if `mcp-remote` process is responsive
   - **Docker health**: Verifies container is running

2. **Smart Thresholds**:
   - Error duration threshold (default: 5 minutes) - prevents restart for transient blips
   - Rate limiting (max 3 restarts/hour) - prevents infinite restart loops

3. **State Tracking**:
   - Persists restart history and error timestamps
   - Resets counters after 1 hour of no restarts
   - Escalates to human alert when rate limit exceeded

4. **Recovery Action**:
   - `docker restart <container>` to recycle the mcp-remote bridge
   - 10-second stabilization wait before health verification
   - Dashboard notification after successful recovery

### Detection Patterns

The watchdog looks for these error patterns in container logs:

```
ClosedResourceError
MCP tool.*call failed
Connection to provider dropped
ReadTimeout
ECONNREFUSED
ETIMEDOUT
```

### Edge Cases Handled

1. **Legitimate downtime for maintenance**: Set `ErrorThresholdMinutes` higher during maintenance windows
2. **Infinite restart loops**: Rate limit (max 3/hour) with human escalation
3. **Bridge stuck WITHOUT visible errors**: Fallback to process health check (kills+respawns if silence >30min)

---

## Installation

### Prerequisites

1. Docker Desktop running on myia-po-2026
2. Hermes containers deployed (`hermes` and `hermes-dashboard`)
3. PowerShell execution policy allows script execution
4. Administrator privileges (for scheduled task creation)

### Quick Install

```powershell
# Navigate to script directory
cd D:\roo-extensions\scripts\hermes-watchdog

# Run as Administrator
.\install-hermes-watchdog.ps1
```

This installs a scheduled task named `Hermes-MCP-Watchdog` that:
- Runs as SYSTEM (no user session required)
- Triggers at startup (2 min delay for Docker)
- Triggers every 5 minutes indefinitely
- Restarts on failure up to 3 times

### Custom Installation

```powershell
# Monitor dashboard container instead
.\install-hermes-watchdog.ps1 -ContainerName hermes-dashboard

# Custom polling interval (10 minutes)
.\install-hermes-watchdog.ps1 -IntervalMinutes 10

# Custom error threshold (10 minutes before restart)
# Edit: D:\roo-extensions\scripts\hermes-watchdog\hermes-mcp-watchdog.ps1
# Change: $ErrorThresholdMinutes = 10
```

---

## Usage

### Manual Testing

```powershell
# Dry-run (probe only, never restart)
.\hermes-mcp-watchdog.ps1 -Mode dry-run

# Test specific container
.\hermes-mcp-watchdog.ps1 -ContainerName hermes-dashboard

# Verbose output
.\hermes-mcp-watchdog.ps1 -Verbose
```

### Viewing Logs

```powershell
# Today's logs
Get-Content D:\roo-extensions\outputs\hermes-watchdog\hermes-watchdog-$(Get-Date -Format yyyyMMdd).log -Tail 50

# Follow logs in real-time
Get-Content D:\roo-extensions\outputs\hermes-watchdog\hermes-watchdog-$(Get-Date -Format yyyyMMdd).log -Wait
```

### Scheduled Task Management

```powershell
# Check task status
Get-ScheduledTask -TaskName 'Hermes-MCP-Watchdog'

# View task history
Get-ScheduledTaskInfo -TaskName 'Hermes-MCP-Watchdog'

# Run immediately (test)
Start-ScheduledTask -TaskName 'Hermes-MCP-Watchdog'

# Disable temporarily
Disable-ScheduledTask -TaskName 'Hermes-MCP-Watchdog'

# Re-enable
Enable-ScheduledTask -TaskName 'Hermes-MCP-Watchdog'

# Uninstall
Unregister-ScheduledTask -TaskName 'Hermes-MCP-Watchdog' -Confirm:$false
```

---

## Configuration

### Script Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `Mode` | `poll` | `poll` = normal, `dry-run` = probe only |
| `ContainerName` | `hermes` | Docker container name to monitor |
| `ErrorThresholdMinutes` | `5` | Minutes of sustained errors before restart |
| `MaxRestartsPerHour` | `3` | Maximum restarts per hour before escalation |
| `LogDir` | `D:\roo-extensions\outputs\hermes-watchdog` | Log directory |
| `HermesEnvFile` | `C:\dev\hermes-agent\.env` | Hermes .env for E2E probing (optional) |
| `LogRetentionDays` | `30` | Days to keep old logs |

### State File

The watchdog maintains state in:
```
D:\roo-extensions\outputs\hermes-watchdog\hermes-watchdog-state.json
```

Contains:
- `LastRestartTime`: Timestamp of last container restart
- `RestartCount`: Number of restarts in current hour window
- `FirstErrorTime`: Timestamp when first error was detected
- `LastUpdate`: Last state update timestamp

---

## Architecture

### Watchdog Flow

```
┌─────────────────────────────────────────────────────────┐
│  Scheduled Task (SYSTEM) every 5 min                    │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│  1. Container Health Check                              │
│     → Is container running?                             │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│  2. Process Health Check                                │
│     → Is mcp-remote process running?                    │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│  3. Log Scraping                                        │
│     → Scan last 10 min for error patterns              │
│     → Check for ClosedResourceError                     │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
                    Errors found?
                           │
            ┌──────────────┴──────────────┐
            │ NO                           │ YES
            ▼                              ▼
      ┌──────────┐              ┌─────────────────────┐
      │ Exit OK  │              │ First error?        │
      └──────────┘              └─────────────────────┘
                                       │
                         ┌─────────────┴─────────────┐
                         │ YES                        │ NO
                         ▼                            ▼
                   ┌───────────┐              ┌──────────────┐
                   │ Record   │              │ Sustained    │
                   │ timestamp│              │ >5 min?      │
                   └───────────┘              └──────────────┘
                                                 │
                                   ┌─────────────┴─────────────┐
                                   │ NO                        │ YES
                                   ▼                            ▼
                             ┌───────────┐              ┌──────────────┐
                             │ Exit OK  │              │ Rate limit   │
                             └───────────┘              │ <3/hour?    │
                                                        └──────────────┘
                                                               │
                                                 ┌─────────────┴─────────────┐
                                                 │ YES                        │ NO
                                                 ▼                            ▼
                                           ┌───────────┐              ┌──────────────┐
                                           │ Docker   │              │ Alert +      │
                                           │ restart  │              │ Exit ERROR   │
                                           └───────────┘              └──────────────┘
```

---

## Troubleshooting

### Watchdog Not Running

```powershell
# Check task status
Get-ScheduledTask -TaskName 'Hermes-MCP-Watchdog' | Format-List *

# Check last run result
Get-ScheduledTaskInfo -TaskName 'Hermes-MCP-Watchdog'

# Check for errors in Task Scheduler
eventvwr.msc → Task Scheduler Operational
```

### False Positives (Too Many Restarts)

Increase the error threshold:
```powershell
# Edit hermes-mcp-watchdog.ps1
$ErrorThresholdMinutes = 10  # Increase from 5 to 10
```

### False Negatives (Bridge Stuck, No Restart)

1. Check if watchdog is detecting errors:
```powershell
# Run manually to see output
.\hermes-mcp-watchdog.ps1
```

2. Check logs for error patterns:
```powershell
docker logs hermes --tail 100 | Select-String -Pattern 'ClosedResourceError|MCP tool.*call failed'
```

3. Verify watchdog state:
```powershell
Get-Content D:\roo-extensions\outputs\hermes-watchdog\hermes-watchdog-state.json | ConvertFrom-Json
```

### Container Won't Start After Restart

1. Check Docker daemon status:
```powershell
docker version
docker info
```

2. Check container logs:
```powershell
docker logs hermes --tail 50
```

3. Manual restart:
```powershell
docker stop hermes
docker start hermes
```

---

## Monitoring and Alerts

### Log Patterns

Successful run:
```
2026-05-06T12:00:00 [INFO ] Hermes MCP watchdog start (mode=poll, container=hermes, errorThreshold=5min)
2026-05-06T12:00:01 [INFO ] Container hermes is running
2026-05-06T12:00:01 [INFO ] mcp-remote process running (PID=123, CPU=0.5%, MEM=2.1%)
2026-05-06T12:00:02 [OK   ] No MCP errors detected in recent logs
```

Restart triggered:
```
2026-05-06T12:05:00 [WARN ] Error threshold exceeded: sustained errors for 6min (threshold=5min)
2026-05-06T12:05:00 [INFO ] Error summary: count=15, ClosedResourceError=True
2026-05-06T12:05:00 [WARN ] Restarting Hermes container hermes to recycle mcp-remote bridge
2026-05-06T12:05:15 [INFO ] Container hermes restarted successfully, waited 10s for stabilization
2026-05-06T12:05:15 [OK   ] Container restarted successfully
```

Rate limit exceeded:
```
2026-05-06T12:10:00 [ERROR] Rate limit exceeded: 4 restarts in last hour (max=3)
2026-05-06T12:10:00 [INFO ] Dashboard alert would be posted: [CRITICAL] Hermes watchdog rate limit: 4 restarts in last hour. Manual intervention required.
```

### Dashboard Integration

The watchdog can post alerts to RooSync dashboards when:
- Container restart fails
- Rate limit is exceeded
- Critical errors are detected

Alert format:
```markdown
## [HERMES-ALERT] Watchdog Event

**Severity:** CRITICAL|WARNING|INFO
**Container:** hermes|hermes-dashboard
**Timestamp:** ISO 8601
**Event:** Description of what happened
**Action:** What the watchdog did
**Next:** Recommended next steps
```

---

## Maintenance

### Log Cleanup

Old logs are automatically deleted after `LogRetentionDays` (default: 30 days).

Manual cleanup:
```powershell
# Delete logs older than 7 days
Get-ChildItem D:\roo-extensions\outputs\hermes-watchdog\*.log |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } |
    Remove-Item -Force
```

### State Reset

To reset the watchdog state (e.g., after manual intervention):
```powershell
Remove-Item D:\roo-extensions\outputs\hermes-watchdog\hermes-watchdog-state.json -Force
```

### Updating the Script

1. Stop the scheduled task:
```powershell
Disable-ScheduledTask -TaskName 'Hermes-MCP-Watchdog'
```

2. Update the script file

3. Re-enable the task:
```powershell
Enable-ScheduledTask -TaskName 'Hermes-MCP-Watchdog'
```

---

## Future Enhancements

### Potential Improvements

1. **Health probe**: Direct TCP/socket ping to mcp-remote instead of log scraping
2. **Telemetry**: If mcp-remote exposes metrics, use connection state instead of error patterns
3. **Maintenance mode**: Config file with maintenance windows to exclude from auto-restart
4. **Multi-container**: Monitor both `hermes` and `hermes-dashboard` in one task
5. **E2E probe**: Actually call an MCP tool to verify end-to-end functionality

### Known Limitations

1. **Log scraping dependency**: Requires Docker logs to contain error patterns
2. **No E2E verification**: Doesn't actually test if MCP tools work
3. **Windows-only**: Uses PowerShell and Windows Scheduled Tasks
4. **Single-machine**: Must run on myia-po-2026 where Docker is hosted

---

## References

- Issue #2014: Hermes MCP-remote bridge watchdog
- Incident 2026-05-04: Docker Desktop crash overnight
- Incident 2026-05-06: Qdrant mount drift causing bridge wedge
- `feedback_mcp_bridge_resilience.md`: Memory file documenting mcp-remote reconnection failure
- Dashboard workspace-nanoclaw 2026-05-06T09:10:49Z: NanoClaw incident-correlation report

---

## License

MIT License - Part of roo-extensions project
