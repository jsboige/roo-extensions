# MCP Timeout Configuration Fix - Issue #1189

## Problem

On myia-web1, the MCP servers (playwright, markitdown, sk-agent) were missing explicit timeout configurations, causing connection issues and timeouts.

## Issues Identified

### 1. markitdown
- **Status**: "Réessayer la connexion" in Roo MCP panel
- **Warning**: `RuntimeWarning: Couldn't find ffmpeg or avconv`
- **Cause**: Missing ffmpeg (optional for audio/video conversion only)
- **Impact**: Server may start but connection fails without proper timeout

### 2. playwright
- **Status**: "MCP Server started" + "Port 5174 is in use, skipping web server"
- **Cause**: Previous instance or another service using port 5174
- **Impact**: Partial connection, web server not started

### 3. Timeout Inconsistency
- **win-cli**: timeout 300s (should be 900s per issue #1189)
- **sk-agent**: NO timeout (should be 600s)
- **playwright**: NO timeout (should be 120s)
- **markitdown**: NO timeout (should be 60s)
- **roo-state-manager**: timeout 300s (OK)

## Solution

Add explicit timeouts to all MCP servers in `mcp_settings.json`:

```json
{
  "mcpServers": {
    "win-cli": {
      "timeout": 900
    },
    "sk-agent": {
      "timeout": 600
    },
    "markitdown": {
      "timeout": 60
    },
    "playwright": {
      "timeout": 120
    },
    "roo-state-manager": {
      "timeout": 300
    }
  }
}
```

## Timeout Rationale

| Server | Timeout | Reason |
|--------|---------|--------|
| win-cli | 900s (15 min) | Long-running command execution |
| sk-agent | 600s (10 min) | LLM operations can take time |
| playwright | 120s (2 min) | Browser automation operations |
| markitdown | 60s (1 min) | Document conversion |
| roo-state-manager | 300s (5 min) | State management operations |

## Additional Fixes

### markitdown ffmpeg Warning
The ffmpeg warning is benign if you don't need audio/video conversion. To fix:

```powershell
# Install ffmpeg via winget
winget install ffmpeg

# Or download from https://ffmpeg.org/download.html
```

### playwright Port Conflict
To resolve port 5174 conflict:

```powershell
# Find process using port 5174
Get-NetTCPConnection -LocalPort 5174

# Kill the process if it's an old playwright instance
taskkill /F /PID <pid>
```

## Application

Apply these changes to myia-web1's `mcp_settings.json` at:
```
C:\Users\Administrator\AppData\Roaming\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json
```

After applying, restart VS Code or reload the MCP servers.

## Verification

Check MCP status in Roo panel:
- All servers should show "Connected" or similar
- No timeout errors
- No port conflict messages

## References

- Issue: #1189
- Machine: myia-web1
- Date: 2026-04-07
