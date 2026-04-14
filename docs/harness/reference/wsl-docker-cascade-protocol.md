# WSL/Docker Cascade Kill Investigation Protocol

**Issue:** #1379 - [ai-01] WSL/Docker cascade kill → all VSCode terminated silently
**Created:** 2026-04-14
**Related:** #1264 (full OS reboot - distinct pattern)

---

## Overview

This protocol documents the investigation and response procedures for WSL/Docker cascade failure incidents on **myia-ai-01**. These incidents manifest as simultaneous termination of all VSCode windows without crash dialogs, often correlated with WSL and Docker Desktop failures.

---

## Incident Detection

### Symptoms

1. **All VSCode windows close simultaneously** without warning or crash dialogs
2. **NanoClaw scheduled cron stops responding** (if active)
3. **Docker Desktop needs manual restart** to function again
4. **WSL distributions are down** (`wsl --list --running` returns empty)
5. **No reboot occurs** (OS stays up, unlike #1264)

### User-Visible Timeline

1. User notices all VSCode windows gone (~10-15 minutes after incident)
2. User restarts VSCode
3. User discovers WSL/Docker not working
4. User manually restarts Docker Desktop and WSL

---

## Immediate Response (Run IMMEDIATELY after discovery)

### 1. Run Diagnostic Script

```powershell
# From roo-extensions root
.\scripts\diagnostic\diagnostic-wsl-docker-cascade.ps1
```

This script collects:
- Windows Event Log data (System, Application) for ±30 min around incident
- Service Control Manager events (7040)
- HTTP Service events (113/114)
- Application Error events (1000)
- BITS service events (Windows Update indicator)
- Windows Defender crash events
- Hyper-V events (WSL backend)
- Current process status (VSCode, WSL, Docker)
- Memory status
- WSL running distributions

**Output:**
- `logs/wsl-docker-cascade/incident-{timestamp}.json` - Full diagnostic data
- `logs/wsl-docker-cascade/incident-{timestamp}-report.md` - Human-readable report

### 2. Manual Data Collection (if script fails)

```powershell
# Collect Windows Event Logs
$incidentTime = "2026-04-14 00:52:22"  # ADJUST TO ACTUAL INCIDENT TIME
$startTime = (Get-Date $incidentTime).AddMinutes(-30)
$endTime = (Get-Date $incidentTime).AddMinutes(60)

# System events
Get-WinEvent -FilterHashtable @{LogName='System'; StartTime=$startTime; EndTime=$endTime} |
    Where-Object { $_.Id -in @(7040, 113, 114) } |
    Select-Object TimeCreated, ProviderName, Id, Message |
    Export-Csv -Path "system-events-$incidentTime.csv" -NoTypeInformation

# Application errors
Get-WinEvent -FilterHashtable @{LogName='Application'; StartTime=$startTime; EndTime=$endTime; Id=1000} |
    Select-Object TimeCreated, ProviderName, Message |
    Export-Csv -Path "app-errors-$incidentTime.csv" -NoTypeInformation

# Check current status
wsl --list --running
Get-Process Code
Get-Process Docker*
```

---

## Investigation Checklist

### Phase 1: Confirm Incident Type

- [ ] Verify no OS reboot occurred: `Get-CimInstance Win32_OperatingSystem | Select-Object LastBootUpTime`
- [ ] Verify no Application Error (1000) for Code.exe/electron/node
- [ ] Verify WSL is down post-incident
- [ ] Verify Docker Desktop needs restart
- [ ] Verify VSCode processes have same StartTime (all restarted post-incident)

### Phase 2: Identify Trigger

- [ ] Check for BITS mode flip (7040 events) around incident time
- [ ] Check for Windows Update activity in WindowsUpdateClient log
- [ ] Check for Defender signature updates (sélection disjointe pattern)
- [ ] Check for Defender crashes (MsMpEng.exe 1000 events with 0xc0000005)
- [ ] Check for driver updates (ASUSTeK, etc.)

### Phase 3: Analyze Cascade

- [ ] Count HTTP Service burst (113/114 events) - indicates kernel reaping
- [ ] Check Hyper-V-Worker / Hyper-V-Compute events
- [ ] Check WSL service log: `%USERPROFILE%\AppData\Local\Temp\wslservice.log`
- [ ] Run Docker Desktop diagnostic: `dd_diag`
- [ ] Check for Resource-Exhaustion events (should be absent)

### Phase 4: Correlate with Timeline

- [ ] Map exact sequence of events (BITS → WSL timeout → VSCode kill)
- [ ] Check if any scheduled tasks ran around incident time
- [ ] Check if any automated updates occurred

---

## Root Cause Analysis

### Hypothesis: WSL/Docker Cascade

1. **Trigger:** Windows Update / Defender refresh (BITS mode flip at 00:52:22)
2. **Failure Point:** Antivirus/firewall driver reload causes WSL VM timeout
3. **Kill:** Hyper-V or Docker service kills WSL VM
4. **Cascade:** All VSCode instances with active Remote-WSL/Dev-Container/Docker connections lose IPC handles
5. **Cleanup:** Unknown watchdog (Docker? shell?) issues `TerminateProcess` on all Code.exe holding broken WSL pipes
6. **Aftermath:** Kernel reaps UPnP URL bindings (HTTP Service 113/114 burst)
7. **Recovery:** WSL never auto-recovers; requires manual `wsl --shutdown` + Docker Desktop restart

### Evidence Supporting Hypothesis

| Evidence | Interpretation |
|----------|----------------|
| No Application Error for Code.exe | `TerminateProcess` kill, not exception crash |
| HTTP Service burst (113/114) | Kernel reaping dying processes |
| WSL down post-incident | WSL VM was killed |
| Node MCP processes survived | Not a node/Electron-wide kill |
| BITS mode flip at 00:52:22 | Windows Update/Defender trigger |
| No OS reboot | Selective process kill, not #1264 pattern |

### Evidence Against Alternative Hypotheses

| Hypothesis | Evidence Against |
|------------|------------------|
| Electron crash | No Application Error (1000) events |
| OS reboot | Uptime preserved, no Kernel-Power 41 |
| Resource exhaustion | No Resource-Exhaustion events, 160GB free |
| VSCode-specific bug | Node MCPs survived, only VSCode killed |

---

## Hardening Strategies

### Immediate (can be done now)

- [ ] Disable automatic Windows Update during active development hours
- [ ] Increase WSL timeout values (if configurable)
- [ ] Add monitoring for WSL service health
- [ ] Create scheduled task to check WSL status every 15 minutes

### Medium-term (requires testing)

- [ ] Consider disabling Defender real-time protection for WSL directories (with proper exclusions)
- [ ] Add WSL/Docker health checks to daily monitoring script
- [ ] Implement automatic WSL restart on failure detection
- [ ] Configure Docker Desktop to auto-restart on service failure

### Long-term (architectural changes)

- [ ] Evaluate alternative WSL configurations (WSL1 vs WSL2)
- [ ] Consider container-based development environment (isolated from host)
- [ ] Evaluate Docker Desktop alternatives ( Rancher Desktop, Podman)
- [ ] Separate development environment from primary workstation

---

## Prevention Checklist

### Before Starting Work Session

- [ ] Check Windows Update status (defer if active)
- [ ] Check WSL status: `wsl --list --running`
- [ ] Check Docker Desktop status
- [ ] Check available memory (>80GB free recommended)

### During Active Development

- [ ] Monitor VSCode windows (if all close, suspect incident)
- [ ] Monitor WSL responsiveness
- [ ] Save work frequently (especially before Windows Update windows)

### After Incident Recovery

- [ ] Run diagnostic script IMMEDIATELY
- [ ] Document incident timestamp
- [ ] Restart WSL: `wsl --shutdown` then relaunch
- [ ] Restart Docker Desktop
- [ ] Verify all services recovered
- [ ] Check for data loss or corruption

---

## Tracking and Reporting

### Incident Log Template

```markdown
## Incident YYYY-MM-DD

**Timestamp:** [Local time of discovery]
**Uptime:** [Days since last boot]
**Trigger:** [BITS, Defender, Unknown]
**Duration:** [Time from trigger to discovery]
**Impact:** [VSCode instances lost, WSL down, Docker restart required]

**Timeline:**
- HH:MM:SS - [First event]
- HH:MM:SS - [Second event]
- ...

**Evidence:**
- Diagnostic script output: `logs/wsl-docker-cascade/incident-...json`
- Event Log exports: [paths]
- WSL service log: [path]

**Recovery:**
- WSL restarted: [Yes/No]
- Docker Desktop restarted: [Yes/No]
- VSCode instances restored: [Count]
- Data loss: [Yes/No]

**Follow-up:**
- [ ] Update incident statistics
- [ ] Implement prevention measures
- [ ] Schedule system maintenance
```

### Metrics to Track

- Incident frequency (per week/month)
- Time between incidents
- Most common triggers
- Average recovery time
- Data loss incidents

---

## Related Issues

- **#1264** - Full OS reboot pattern (StartMenuExperienceHost.exe instability)
- **#1379** - This issue (WSL/Docker cascade, selective process kill)

---

## References

- **Diagnostic Script:** `scripts/diagnostic/diagnostic-wsl-docker-cascade.ps1`
- **Daily Monitoring:** `docs/suivi/monitoring/daily-monitoring-system.md`
- **Incident History:** `docs/harness/reference/incident-history.md`

---

**Last Updated:** 2026-04-14
**Next Review:** After next incident or 2026-05-14 (whichever comes first)
