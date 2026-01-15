# T4.7 - Analyse des Besoins de Maintenance Multi-Agent

**Date :** 2026-01-15
**Auteurs :** Claude Code (myia-ai-01 + myia-po-2023) - Document fusionné
**Statut :** Analyse complétée

---

## 1. Contexte

Ce document fusionne les analyses de deux agents qui ont travaillé simultanément sur T4.7:
- **myia-ai-01** : Focus opérations (scripts, scheduling, alertes)
- **myia-po-2023** : Focus code (services existants, TypeScript)

---

## 2. Résumé Exécutif

Le système RooSync multi-agent (5 machines) est **partiellement automatisé** :

| Aspect | Automatisé | Manuel |
|--------|------------|--------|
| Cache mémoire | TTL + LRU | - |
| Services lifecycle | Shutdown hooks | - |
| Rollback cleanup | - | 46+ dirs orphelins |
| Messages archive | - | Croissance illimitée |
| Config backups | - | 8+ fichiers |
| Logs | - | Sans rotation |
| Dépendances | - | npm update ad-hoc |
| Tokens | - | Rotation manuelle |

**Risques sans maintenance :**
- Dérive de configuration entre machines
- Dépendances obsolètes avec vulnérabilités
- Tokens expirés rendant les MCPs inaccessibles
- Logs accumulés consommant l'espace disque

---

## 3. Mécanismes Automatisés Existants

### 3.1 Gestion du Cache (CacheManager)

| Paramètre | Valeur | Description |
|-----------|--------|-------------|
| TTL | 2 heures | Expiration automatique |
| Max Size | 100 MB | Éviction LRU |
| Cleanup Interval | 5 min | Nettoyage périodique |
| Smart Invalidation | Oui | Basé sur changements config |

### 3.2 Protection Anti-Fuite (CacheAntiLeakManager)

| Paramètre | Valeur | Action |
|-----------|--------|--------|
| Traffic Limit | 220 GB | Monitoring |
| Warning Threshold | 200 GB | Alerte |
| Cleanup Interval | 5 min | Périodique |
| Consistency Check | 24h | Validation complète |

### 3.3 Lifecycle Services

```
Shutdown → CacheManager.cleanup()
        → LLMService.cleanup()
        → SynthesisOrchestrator.cleanup()
        → ServiceRegistry.cleanup()
```

---

## 4. Catégories de Maintenance

### 4.1 Maintenance Préventive

| Tâche | Description | Fréquence | Automatisable |
|-------|-------------|-----------|---------------|
| **Dépendances** | `npm audit` + `npm update` | Mensuelle | Oui |
| **Tokens** | Rotation GitHub tokens | Trimestrielle | Partiel |
| **Health** | Vérifier MCPs accessibles | Quotidienne | Oui |
| **Disk** | Vérifier espace disque | Hebdomadaire | Oui |
| **Backup** | Sauvegarder configs | Quotidienne | Oui |

### 4.2 Maintenance Corrective

| Incident | Action | Temps | Automatisable |
|----------|--------|-------|---------------|
| **MCP down** | Rebuild + restart | 10-30 min | Partiel |
| **Token expiré** | Nouveau token | 5-10 min | Non |
| **Build échoué** | Fix + rebuild | 30-120 min | Non |
| **Git conflict** | Résolution | 10-60 min | Non |
| **Machine HS** | Reboot manuel | Variable | Non |

### 4.3 Maintenance Évolutive

| Évolution | Description | Priorité |
|-----------|-------------|----------|
| **Automatisation** | Script déploiement batch | HIGH |
| **Monitoring** | Health checks continu | HIGH |
| **CI/CD** | Tests automatisés | MEDIUM |

---

## 5. Inventaire Maintenance Manuelle

### 5.1 Tâches Requises

| Tâche | Localisation | Fréquence | Effort |
|-------|--------------|-----------|--------|
| Cleanup rollback | `.rollback/` | Mensuel | 10 min |
| Archive messages | `.shared-state/messages/` | Mensuel | 15 min |
| Rotation backups | `.shared-state/*.backup` | Mensuel | 5 min |
| Purge logs | `.shared-state/logs/` | Hebdo | 5 min |
| Cleanup checkpoints | `~/roo-cline/tasks/*/checkpoints` | Mensuel | 5 min |

### 5.2 Scripts Existants

| Script | Fonction | Mode |
|--------|----------|------|
| `cleanup_obsolete_checkpoints.ps1` | Purge checkpoints Roo | DryRun/Force |

---

## 6. Architecture Cible

### 6.1 Script PowerShell: `maintain-roosync.ps1`

```powershell
# maintain-roosync.ps1
Param(
    [ValidateSet("health", "update", "cleanup", "all")]
    [string]$Task = "all"
)

function Invoke-HealthCheck {
    Write-Host "=== Health Check ===" -ForegroundColor Cyan

    $checks = @(
        @{Name="MCP Accessible"; Test={Test-MCPConnection}},
        @{Name="Git Synced"; Test={Test-GitSync}},
        @{Name="Tokens Valid"; Test={Test-TokensFresh}},
        @{Name="Disk Space"; Test={Test-DiskSpace}}
    )

    foreach ($check in $checks) {
        $result = & $check.Test
        $status = if ($result) { "OK" } else { "FAIL" }
        Write-Host "$($check.Name): $status"
    }
}

function Invoke-LogCleanup {
    Write-Host "=== Log Cleanup ===" -ForegroundColor Cyan

    $logDirs = @(
        "mcps/internal/servers/roo-state-manager/logs",
        "mcps/internal/servers/roo-state-manager/.roo-logs"
    )

    foreach ($dir in $logDirs) {
        if (Test-Path $dir) {
            Get-ChildItem $dir -Recurse -File |
                Where-Object LastWriteTime -lt (Get-Date).AddDays(-7) |
                Remove-Item -Force
        }
    }
}

# Main
switch ($Task) {
    "health" { Invoke-HealthCheck }
    "cleanup" { Invoke-LogCleanup }
    "all" { Invoke-HealthCheck; Invoke-LogCleanup }
}
```

### 6.2 Service TypeScript: `MaintenanceService.ts`

```typescript
// src/services/MaintenanceService.ts
export class MaintenanceService {
  private config: MaintenanceConfig;

  async runScheduledMaintenance(): Promise<MaintenanceReport> {
    const results = await Promise.all([
      this.cleanupRollbacks(),
      this.archiveOldMessages(),
      this.rotateBackups(),
      this.pruneLogs()
    ]);
    return this.generateReport(results);
  }

  async cleanupRollbacks(olderThanDays = 7): Promise<CleanupResult>;
  async archiveOldMessages(olderThanDays = 30): Promise<ArchiveResult>;
  async rotateBackups(keepCount = 5): Promise<RotationResult>;
  async pruneLogs(keepDays = 7): Promise<PruneResult>;
}
```

### 6.3 Configuration

```json
// .shared-state/.maintenance-config.json
{
  "rollback": {
    "retentionDays": 7,
    "excludePatterns": ["CRITICAL_*"]
  },
  "messages": {
    "archiveAfterDays": 30,
    "deleteAfterDays": 90
  },
  "backups": {
    "keepCount": 5
  },
  "logs": {
    "retentionDays": 7,
    "maxSizeMB": 100
  }
}
```

---

## 7. Alertes et Notifications

### 7.1 Critères d'Alerte

| Critère | Seuil | Action |
|---------|-------|--------|
| MCP inaccessible | 1 échec | Retry 3x + RooSync msg |
| Token expire | < 7 jours | RooSync reminder |
| Disk space | < 1GB | Cleanup + alert |
| Tests fail | > 0 tests | GitHub issue |

### 7.2 Template Message RooSync

```markdown
## Alert Maintenance - [MACHINE]

**Type:** [HEALTH | SECURITY | DISK | BUILD]
**Sévérité:** [HIGH | MEDIUM | LOW]

**Description:**
[Description du problème]

**Action Requise:**
- [ ] [Action 1]
```

---

## 8. Plan d'Implémentation

### Phase 1: Scripts de Base (7h)

| Tâche | Description | Effort |
|-------|-------------|--------|
| T4.8a | Cleanup rollback automatique (>7j) | 2h |
| T4.8b | Archivage messages (>30j) | 3h |
| T4.8c | Rotation logs (7 jours) | 2h |

### Phase 2: Ordonnancement (4h)

| Tâche | Description | Effort |
|-------|-------------|--------|
| Task Scheduler | Tâches planifiées Windows | 2h |
| RooSync notifications | Messages alerte | 2h |

### Phase 3: Service TypeScript (6h)

| Tâche | Description | Effort |
|-------|-------------|--------|
| MaintenanceService.ts | Orchestrateur | 4h |
| Tests unitaires | Couverture | 2h |

---

## 9. Métriques de Succès

| KPI | Cible | Mesure |
|-----|-------|--------|
| Uptime MCP | > 99% | Health checks |
| Rollback dirs | < 10 | `ls .rollback` |
| Messages inbox | < 100 | JSON count |
| MTTR | < 30 min | Incident logs |

---

## 10. Conclusion

**Recommandations prioritaires :**

1. **P0** : Implémenter cleanup rollback (46+ dirs orphelins)
2. **P0** : Activer rotation logs (espace disque)
3. **P1** : Health checks quotidiens automatisés
4. **P2** : MaintenanceService TypeScript complet

**Effort total Phase 1 :** ~7h

---

**Document fusionné par Claude Code**
**Contributions :** myia-ai-01 (opérations) + myia-po-2023 (code)
**Date :** 2026-01-15
