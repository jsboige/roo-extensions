# Hermes MCP-Remote Bridge Resilience

**Issue:** #2014
**Date:** 2026-05-06
**Machine:** myia-po-2026
**Status:** RESOLVED

---

## Problem Pattern

The `mcp-remote` (Node.js) bridge used by Hermes Agent does NOT automatically reconnect when the upstream MCP proxy returns after an outage. Instead, it remains alive but in a permanent `ClosedResourceError` state where all MCP calls timeout.

### Incidents

1. **2026-05-04** (01:28→12:15): Docker Desktop crash overnight
   - Impact: Hermes silent for 10h47
   - Recovery: Manual container restart

2. **2026-05-06 ~10:22-10:32Z**: Qdrant mount drift correlated with Docker wedge
   - Impact: Hermes bridge stuck, all MCP calls failing
   - Recovery: Manual container restart

### Root Cause

`mcp-remote` maintains a persistent connection to the upstream MCP proxy. When the upstream disappears (network issue, Docker crash, proxy restart), the bridge enters an error state and never attempts reconnection. Only restarting the entire container (which spawns a fresh `mcp-remote` process) resolves the issue.

### Impact per Incident

- 8-10 hours of Hermes silence
- Missing cluster coordination (Hermes = secretary/reporter)
- Operational cost (manual intervention required)
- Credit cost (session re-runs, backlog catchup)

---

## Solution Implemented

### Hermes MCP Watchdog

**Location:** `D:\roo-extensions\scripts\hermes-watchdog\`

**Components:**
1. `hermes-mcp-watchdog.ps1` - Main watchdog script
2. `install-hermes-watchdog.ps1` - Scheduled task installer
3. `test-hermes-watchdog.ps1` - Test suite
4. `README.md` - Complete documentation

### Detection Mechanisms

1. **Log Scraping**: Scans container logs for error patterns
   - `ClosedResourceError`
   - `MCP tool.*call failed`
   - `Connection to provider dropped`
   - `ReadTimeout`, `ECONNREFUSED`, `ETIMEDOUT`

2. **Process Health**: Verifies `mcp-remote` process is running inside container

3. **Docker Health**: Checks container status

### Recovery Action

```powershell
docker restart <container>
```

Followed by 10-second stabilization wait and health verification.

### Smart Thresholds

- **Error Duration**: 5 minutes of sustained errors before restart (prevents false positives)
- **Rate Limiting**: Max 3 restarts/hour then escalate to human (prevents infinite loops)
- **State Tracking**: Persists restart history and error timestamps across runs

### Scheduled Task

**Name:** `Hermes-MCP-Watchdog`
**Account:** NT AUTHORITY\SYSTEM (no user session required)
**Triggers:**
- At startup (2 min delay for Docker)
- Every 5 minutes indefinitely

---

## Deployment

### Installation

```powershell
# Run as Administrator
cd D:\roo-extensions\scripts\hermes-watchdog
.\install-hermes-watchdog.ps1
```

### Testing

```powershell
# Validate environment and watchdog
.\test-hermes-watchdog.ps1

# Dry-run (no actual restarts)
.\hermes-mcp-watchdog.ps1 -Mode dry-run
```

### Monitoring

```powershell
# View logs
Get-Content D:\roo-extensions\outputs\hermes-watchdog\hermes-watchdog-$(Get-Date -Format yyyyMMdd).log -Tail 50

# Check task status
Get-ScheduledTask -TaskName 'Hermes-MCP-Watchdog'
Get-ScheduledTaskInfo -TaskName 'Hermes-MCP-Watchdog'
```

---

## Architecture

### Watchdog Flow

```
Scheduled Task (SYSTEM, every 5 min)
    │
    ▼
Container Health Check (Is container running?)
    │
    ▼
Process Health Check (Is mcp-remote running?)
    │
    ▼
Log Scraping (Scan last 10 min for errors)
    │
    ▼
Errors Found?
    ├─ No → Exit OK
    └─ Yes → First Error?
              ├─ Yes → Record timestamp, Exit OK
              └─ No → Sustained >5 min?
                        ├─ No → Exit OK
                        └─ Yes → Rate Limit <3/hour?
                                  ├─ No → Alert + Exit ERROR
                                  └─ Yes → Docker restart
```

### State Management

State file: `D:\roo-extensions\outputs\hermes-watchdog\hermes-watchdog-state.json`

```json
{
  "LastRestartTime": "2026-05-06T12:00:00.000Z",
  "RestartCount": 2,
  "FirstErrorTime": "2026-05-06T11:55:00.000Z",
  "LastUpdate": "2026-05-06T12:00:15.000Z"
}
```

---

## Lessons Learned

### 1. MCP-Remote Reconnection Failure

**Finding:** `mcp-remote` (Node.js) does NOT auto-reconnect when upstream returns.

**Evidence:**
- Incident 2026-05-04: 10h47 silence after Docker crash
- Incident 2026-05-06: Permanent `ClosedResourceError` after upstream outage

**Mitigation:** Watchdog with container restart recycling the bridge.

### 2. Log Scraping vs Health Probes

**Finding:** Log scraping is sufficient for detection but not ideal.

**Limitations:**
- Requires logs to contain error patterns
- No E2E verification (don't actually test if MCP tools work)

**Future:** Consider adding E2E probe (actual MCP tool call).

### 3. Rate Limiting Critical

**Finding:** Without rate limiting, watchdog could cause infinite restart loops.

**Mitigation:** Max 3 restarts/hour then escalate to human.

### 4. State Tracking Essential

**Finding:** Need to track error duration and restart count across runs.

**Implementation:** JSON state file with timestamps and counters.

---

## Related Documentation

- **Issue:** #2014
- **Watchdog README:** `D:\roo-extensions\scripts\hermes-watchdog\README.md`
- **Test Suite:** `D:\roo-extensions\scripts\hermes-watchdog\test-hermes-watchdog.ps1`
- **Dashboard References:**
  - workspace-nanoclaw 2026-05-06T09:10:49Z (NanoClaw incident report)
  - workspace-roo-extensions 2026-05-06T09:10:34Z (Cross-post)

---

## Future Enhancements

1. **Health Probe**: Direct TCP/socket ping to mcp-remote
2. **E2E Verification**: Actually call an MCP tool to verify functionality
3. **Maintenance Mode**: Config file with maintenance windows
4. **Multi-Container**: Monitor both `hermes` and `hermes-dashboard` in one task
5. **Telemetry Integration**: Use mcp-remote metrics if exposed

---

## References

- `mcp-remote` package: https://www.npmjs.com/package/mcp-remote
- Hermes Agent: https://github.com/hermes-agent/hermes-agent
- Docker restart pattern: Established in `mcp-chain-watchdog.ps1` (NanoClaw)
