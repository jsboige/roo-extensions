# Docker/WSL Watchdog - Monitoring and Auto-Recovery

**Issue:** #1380
**Incident:** #1379 - 5h silent hang due to WSL switch port loss
**Target:** ai-01 (myia-ai-01) initially

## Overview

The Docker/WSL Watchdog is a monitoring solution that detects:
1. Docker init control API hang (>5 minutes)
2. WSL Hyper-V switch loss
3. Network adapter issues

When issues are detected, it automatically attempts recovery by:
- Restarting Docker Desktop service
- Restarting Host Networking Service (HNS)
- Attempting WSL shutdown if needed

## Components

### 1. Main Watchdog Script
`scripts/windows/docker-wsl-watchdog.ps1`

**Features:**
- Monitors `C:\Users\MYIA\AppData\Local\Docker\log\host\monitor.log`
- Parses log for "still waiting for init control API to respond after" messages
- Checks WSL switch and adapter health via PowerShell cmdlets
- Auto-recovery with detailed logging
- Dashboard alerts via RooSync (when available)

**Parameters:**
- `-MaxWaitMinutes`: Threshold for detection (default: 5)
- `-LogPath`: Docker log path (auto-detected)
- `-WatchdogLogPath`: Output log path
- `-Verbose`: Detailed output

### 2. Setup Script
`scripts/windows/setup-docker-watchdog.ps1`

Creates scheduled task:
- Name: `Docker-WSL-Watchdog`
- Runs every 5 minutes
- User: SYSTEM (highest privileges)
- Auto-restart on failure (3 attempts)

### 3. Test Script
`scripts/windows/test-docker-watchdog.ps1`

Test scenarios:
- `docker-hang`: Simulates 6-minute API hang
- `wsl-switch-lost`: Simulates switch loss
- `both`: Combines both issues
- `none`: Normal operation
- `-Cleanup`: Removes test artifacts

## Installation

1. **Prerequisites:**
   - Windows 10/11 with Hyper-V enabled
   - Docker Desktop installed
   - Administrator privileges

2. **Deploy:**
   ```powershell
   # Run as Administrator
   cd scripts/windows
   .\setup-docker-watchdog.ps1
   ```

3. **Test:**
   ```powershell
   # Test normal operation
   .\test-docker-watchdog.ps1 -scenario none

   # Test Docker hang scenario
   .\test-docker-watchdog.ps1 -scenario docker-hang
   ```

## Monitoring

### Log Files
- **Watchdog log:** `claude/logs/docker-watchdog.log`
  - Retention: 30 days (auto-cleanup)
  - Format: Timestamp + Level + Message

### Scheduled Task
- View in Task Scheduler: `Docker-WSL-Watchdog`
- Status: Should show "Running" with green checkmark
- Last run time: Verify it runs every 5 minutes

### Dashboard Integration
When issues are detected:
- Alerts sent to workspace dashboard via RooSync
- Severity levels: INFO, WARN, ERROR, CRITICAL
- Includes timestamp, issue details, and actions taken

## Recovery Actions

### 1. Docker Init Control API Hang
- Log detection with duration
- Restart `com.docker.service`
- Wait 60 seconds for Docker to be ready
- Verify with `docker ps`

### 2. WSL Switch Loss
- Check VM Switch and Network Adapter status
- Attempt HNS service restart
- If failed, attempt `wsl --shutdown`
- Restart Docker after WSL shutdown

### 3. Failed Recovery
- Log all attempts
- Send CRITICAL alert to dashboard
- Manual intervention required

## Troubleshooting

### Common Issues

1. **Task doesn't run:**
   - Check Task Scheduler for errors
   - Verify script path is correct
   - Ensure SYSTEM account has permissions

2. **Docker restart fails:**
   - Check if Docker Desktop is running
   - Verify service account permissions
   - Check event logs for errors

3. **WSL commands fail:**
   - Ensure WSL is installed and running
   - Check Hyper-V status
   - Run as Administrator

### Debug Mode

For detailed debugging:
```powershell
.\docker-wsl-watchdog.ps1 -Verbose -MaxWaitMinutes 1
```

### Log Analysis

Sample log entries:
```
[2026-04-14 10:30:15] [ERROR] Docker init control API hang detected: 0 h 6 m (threshold: 5 m)
[2026-04-14 10:30:15] [INFO] Attempting to restart Docker Desktop service...
[2026-04-14 10:31:15] [INFO] Docker is ready: version 24.0.0
[2026-04-14 10:31:15] [ERROR] ACTION TAKEN: Docker service restarted
```

## Configuration

### Custom Thresholds
For different environments, adjust the detection threshold:
```powershell
# Less sensitive (10 minutes)
.\setup-docker-watchdog.ps1 -IntervalMinutes 5 -ScriptPath .\docker-wsl-watchdog.ps1 -MaxWaitMinutes 10
```

### Multiple Machines
The watchdog is currently deployed on ai-01 only. To expand:
1. Copy scripts to target machine
2. Run setup script with admin privileges
3. Update dashboard machine mapping

## Performance Impact

- CPU: Minimal (log parsing only)
- Memory: ~10MB per check
- Disk: Log file with 30-day retention
- Network: None (local monitoring only)

## Related Issues

- #1379: Incident causing 5h cluster hang
- #1234: Orphaned tasks cleanup
- #1225: LongPathsEnabled fix

## Future Enhancements

1. Email/SMS notifications
2. Prometheus metrics endpoint
3. Integration with monitoring systems
4. Health check API endpoint
5. Configuration file support