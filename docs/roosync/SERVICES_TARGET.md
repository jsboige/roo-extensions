# Services Target — roosync_config

**Issue :** #2409 (Epic #2406 VibeSync Phase 2)
**Owner :** po-2023 (IIS mandate)
**Service :** `ServicesConfigService.ts`
**MAJ :** 2026-06-01

---

## Overview

The `services:<name>` target for `roosync_config` enables declarative lifecycle management of critical Windows services across the cluster. Supports three entity kinds: Windows services, processes, and Docker containers.

## Registered Services

| Name | Kind | Owner Machine | Port | Health Endpoint |
|------|------|---------------|------|-----------------|
| `qdrant` | Windows service (`Qdrant`) | `myia-ai-01` | 6333 | `http://localhost:6333/healthz` |
| `iis` | Windows service (`W3SVC`) | `myia-po-2023` | 80/443 | (native) |
| `vllm` | Process (`python -m vllm`) | `myia-ai-01` | 5002 | `http://localhost:5002/health` |
| `sk-agent` | Docker container | `myia-ai-01` | 8765 | `http://localhost:8765/health` |

Registry is static in `ServicesConfigService.SERVICE_REGISTRY`.

## Usage

### Collect (inventory)

```typescript
roosync_config(action: "collect", targets: ["services:vllm", "services:qdrant"])
```

Returns status, PID, listening ports, and health probe result for each requested service.

### Apply (lifecycle)

```typescript
roosync_config(action: "apply", targets: ["services:vllm"], operation: "restart")
```

Supported operations: `start`, `stop`, `restart`.

**Reconciliation mode:** If `desiredStatuses` map is provided in the apply payload, the service auto-determines the effective operation (start if should be running but stopped, stop if should be stopped but running, skip if already desired).

## Safety Mechanisms

### Ownership Enforcement

Each service has an `owner` machine in the registry. Apply operations are **refused** if the current machine is not the owner:

```
Error: Service 'vllm' is owned by myia-ai-01, cannot apply on myia-po-2023
```

### Health Check Post-Apply

After `start` or `restart`, a health probe (HTTP GET with 5s timeout) verifies the service responds. If the health check fails, a **rollback** is performed (best-effort stop of the just-started service).

### Pre/Post State Collection

The apply method captures service state before and after the operation, returning both snapshots for audit.

## Architecture

```
ServicesConfigService
├── SERVICE_REGISTRY (static, 4 entries)
├── collect(names[]) → ServicesCollectResult
│   ├── Dispatch PowerShell by kind (service/process/container)
│   ├── Get-Service / Get-Process / docker inspect
│   └── probeHealth() → HTTP GET
├── apply(names[], operation, desiredStatuses?) → ServicesApplyResult
│   ├── Ownership check (refuse if machine ≠ owner)
│   ├── Bidirectional reconciliation (desiredStatuses map)
│   ├── applySingle() per service
│   │   ├── Service: Start/Stop/Restart-Service
│   │   ├── Process: PID kill → CommandLine kill → name kill → Start-Process
│   │   └── Container: docker start/stop/restart
│   └── Rollback on health check failure
└── Helpers: getRegisteredNames(), parseServiceTarget(), isValidServiceName()
```

## PowerShell Scripts

Three inline PowerShell scripts handle the platform-specific operations:

1. **Service kind**: `Get-Service`, `Start-Service`, `Stop-Service`, `Restart-Service`
2. **Process kind**: Three-tier stop (PID → CommandLine → name), `Start-Process` with argument arrays
3. **Container kind**: `docker start/stop/restart`, `docker inspect` for status

## Testing

Unit tests in `tests/unit/services/ServicesConfigService.test.ts` (325 LOC):
- W1: PID-based process kill
- W2: PowerShell `@()` argument arrays for Start-Process
- W3: Bidirectional reconciliation (desiredStatuses)
- Registry helpers: `parseServiceTarget()`, `isValidServiceName()`

E2E test target: Qdrant bounce on ai-01 (least-risk service).

## ConfigSharingService Integration

### Collect Path

`ConfigSharingService.collectConfig()` handles `services:<name>` targets:
- Filters targets starting with `services:`
- Calls `ServicesConfigService.collect()`
- Writes result to `services/services-state.json` in the manifest

### Apply Path

`ConfigSharingService.applyConfig()` handles services targets:
- Reads `services/services-state.json` from the config package
- Compares local state vs package desired state
- Starts services that are stopped locally but Running in the package
- Reconciliation-style (only starts, does not stop/restart)

## Known Limitations

1. **Apply path** in ConfigSharingService only supports reconciliation (start-if-stopped), not explicit `stop`/`restart` operations
2. **Registry is static** — adding services requires code change + rebuild
3. **vLLM start command** is hardcoded in the registry (model path, port)
4. **Container kind** requires Docker CLI on the host
5. **No E2E tests** yet (requires ai-01 Qdrant bounce, manual verification)

## References

- Service implementation: `src/services/ServicesConfigService.ts`
- Unit tests: `tests/unit/services/ServicesConfigService.test.ts`
- Integration: `src/services/ConfigSharingService.ts` (collect L129-134, apply L352-395)
- Issue: jsboige/roo-extensions#2409
- Epic: jsboige/roo-extensions#2406 (VibeSync Phase 2)
