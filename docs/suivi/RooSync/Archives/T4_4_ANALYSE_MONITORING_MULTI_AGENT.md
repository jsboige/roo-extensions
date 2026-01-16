# T4.4 - Analyse des Besoins de Monitoring Multi-Agent

**Date :** 2026-01-15
**Auteur :** Claude Code (myia-po-2023)
**Statut :** Analyse complétée

---

## 1. Résumé Exécutif

RooSync dispose de **fondations solides** (logging, dashboard, error handling) mais manque d'**alerting actionnable** et de **visibilité temps réel**.

| Aspect | État | Gap |
|--------|------|-----|
| Logging | ✅ Production-ready | Fichiers locaux |
| Dashboard | ✅ JSON structuré | Pas de refresh auto |
| Errors | ✅ 12+ codes classifiés | Pas d'alertes |
| Metrics | ⚠️ ServiceRegistry | Pas d'export |
| Alerting | ❌ Absent | **CRITIQUE** |

**Gap principal :** Entre "les logs existent" et "les alertes se déclenchent".

---

## 2. Composants Actuels

### 2.1 Système de Logging

| Composant | Fichier | Fonctionnalités |
|-----------|---------|-----------------|
| RooSync Logger | `src/utils/logger.ts` | Fichier + console, rotation |
| Winston Logger | `github-projects-mcp` | Debug conditionnel |

**Caractéristiques :**
- Rotation : 10MB/fichier, 7 jours rétention
- Format : ISO 8601 timestamps
- Niveaux : error, warn, info, debug

### 2.2 Dashboard Status

**Fichier :** `sync-dashboard.json`

```json
{
  "machines": [
    {
      "id": "myia-ai-01",
      "status": "online",
      "lastSync": "2026-01-15T12:00:00Z",
      "diffsCount": 0,
      "pendingDecisions": 0
    }
  ],
  "summary": {
    "totalMachines": 5,
    "onlineCount": 3,
    "pendingDecisions": 2
  }
}
```

**Validation :** Schema JSON défini (`sync-dashboard.schema.json`)

### 2.3 Classification Erreurs (T3.7)

| Service | Codes Erreurs | Type |
|---------|---------------|------|
| ConfigService | 8+ | SCRIPT/SYSTEM |
| IdentityManager | 5+ | SCRIPT |
| BaselineLoader | 6+ | SYSTEM |
| DiffDetector | 4+ | SCRIPT |

### 2.4 Métriques ServiceRegistry

```typescript
interface ServiceMetrics {
  callCount: number;
  averageExecutionTime: number;
  cacheHitRate: number;
  errorCount: number;
  lastCall: string;
}
```

---

## 3. Gaps Identifiés

### 3.1 Pas d'Alerting Centralisé (CRITIQUE)

**Problème :** Erreurs loggées mais pas d'actions automatiques.

| Scénario | Aujourd'hui | Idéal |
|----------|-------------|-------|
| Machine offline >5min | Rien | Alerte RooSync |
| Error rate >10% | Log fichier | Notification |
| Decision timeout | Manuel | Escalation |

### 3.2 Observabilité Temps Réel Limitée

**Manquant :**
- Export Prometheus/StatsD
- Event streaming live
- Requêtes sur logs

### 3.3 Pas de SLO/SLA Tracking

**Absent :**
- Métriques disponibilité service
- Baselines taux erreur
- Latences percentiles (p50, p95, p99)

### 3.4 Pas de Tracing Distribué

**Problème :** Erreurs non corrélées entre machines.

```
Machine A: Error "sync failed"
Machine B: Error "connection timeout"
→ Pas de lien visible entre les deux
```

---

## 4. Recommandations

### 4.1 Priorité 1 : Alerting de Base

| Tâche | Description | Effort |
|-------|-------------|--------|
| **T4.5a** | Règles d'alerte dans dashboard | 2h |
| **T4.5b** | Détection seuils (error_rate, offline) | 3h |
| **T4.5c** | Notifications via RooSync messaging | 2h |

**Exemple règle d'alerte :**
```json
{
  "alerts": [
    {
      "name": "machine_offline",
      "condition": "lastSync > 10min",
      "action": "send_roosync_message",
      "priority": "HIGH"
    }
  ]
}
```

### 4.2 Priorité 2 : Métriques Opérationnelles

| Tâche | Description | Effort |
|-------|-------------|--------|
| **T4.5d** | Export métriques JSON/CSV | 2h |
| **T4.5e** | IDs corrélation opérations | 3h |
| **T4.5f** | Auto-refresh dashboard | 2h |

### 4.3 Priorité 3 : Monitoring Avancé

| Tâche | Description | Effort |
|-------|-------------|--------|
| **T4.5g** | API endpoint métriques | 4h |
| **T4.5h** | Format Prometheus | 3h |
| **T4.5i** | Détection anomalies | 6h |

---

## 5. Architecture Cible

```
┌─────────────────────────────────────────────┐
│              Monitoring Layer               │
├─────────────────────────────────────────────┤
│                                             │
│  ┌─────────┐  ┌─────────┐  ┌─────────────┐ │
│  │ Metrics │  │ Alerts  │  │ Dashboard   │ │
│  │ Export  │  │ Engine  │  │ Visualizer  │ │
│  └────┬────┘  └────┬────┘  └──────┬──────┘ │
│       │            │              │        │
│  ┌────▼────────────▼──────────────▼────┐   │
│  │         sync-dashboard.json          │   │
│  │    (source de vérité centralisée)    │   │
│  └──────────────────────────────────────┘   │
│                                             │
└─────────────────────────────────────────────┘
          ▲            ▲            ▲
          │            │            │
    ┌─────┴─────┐ ┌────┴────┐ ┌────┴────┐
    │ myia-ai-01│ │myia-po- │ │myia-web-│
    │  (logs)   │ │  2023   │ │   01    │
    └───────────┘ └─────────┘ └─────────┘
```

---

## 6. Métriques Recommandées

| Métrique | Type | Seuil Alerte |
|----------|------|--------------|
| `machine.online` | Gauge | < expected |
| `sync.latency_ms` | Histogram | p95 > 5000 |
| `error.rate` | Counter/s | > 0.1 |
| `decision.pending_age_min` | Gauge | > 60 |
| `message.unread_count` | Gauge | > 10 |

---

## 7. Conclusion

Le système a une **bonne base de logging et error handling** mais nécessite :

1. **Court terme :** Alerting basique via RooSync messaging
2. **Moyen terme :** Export métriques + dashboard refresh
3. **Long terme :** Observabilité complète (traces, anomalies)

**Effort total estimé Phase 1 :** ~7h

---

**Rapport généré par Claude Code (myia-po-2023)**
**Date :** 2026-01-15T13:00:00Z
