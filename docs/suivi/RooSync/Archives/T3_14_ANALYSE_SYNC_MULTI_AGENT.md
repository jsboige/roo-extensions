# T3.14 - Analyse des Besoins de Synchronisation Multi-Agent

**Date :** 2026-01-15
**Auteur :** Claude Code (myia-po-2023)
**Statut :** Analyse complétée

---

## 1. Résumé Exécutif

RooSync v2.3 dispose d'une **architecture baseline-driven solide** avec messagerie fichier et workflow de décisions. Cependant, il **manque des fonctionnalités critiques** pour une coordination multi-agent robuste :

| Gap | Sévérité | Impact |
|-----|----------|--------|
| Pas de heartbeat automatique | CRITICAL | Impossible détecter agents morts |
| Pas de consensus distribué | CRITICAL | Incohérences possibles |
| Résolution conflits non implémentée | HIGH | Configuration ignorée |
| Pas de threading messages | MEDIUM | Difficile tracer conversations |

---

## 2. Mécanismes Actuels

### 2.1 Messagerie RooSync

**Implémentation :** `src/tools/roosync/read_inbox.ts`

| Aspect | Détail |
|--------|--------|
| Format | JSON dans `.shared-state/inbox/` |
| Statuts | `unread`, `read`, `archived` |
| Destinataires | Point-à-point ou broadcast (`all`) |
| Priorités | LOW, MEDIUM, HIGH, URGENT |

**Limitations :**
- Structure plate (pas de chronologie)
- Pas d'expiration automatique
- Pas de threading/reply-to
- Pas d'authentification

### 2.2 Fichiers Partagés

**Structure :**
```
.shared-state/
├── sync-config.ref.json    # Baseline (source de vérité)
├── sync-dashboard.json     # États machines temps réel
├── sync-roadmap.md         # Interface validation humaine
├── inventories/            # Inventaires machines
├── history/                # Historique changements
└── presence/               # Fichiers présence
```

**Synchronisation :** Google Drive (consistance éventuelle)

**Limitations :**
- Pas de validation de schéma
- Pas de transactions atomiques
- Conflits résolus manuellement

### 2.3 Système de Présence

**Implémentation :** `src/services/roosync/PresenceManager.ts`

| Aspect | Détail |
|--------|--------|
| Fichiers | `presence/{machineId}.json` |
| Statuts | `online`, `offline`, `conflict` |
| Tracking | `lastSeen`, `firstSeen`, `version` |
| Protection | Locks fichier + registry |

**Limitations Critiques :**
- **Pas de heartbeat automatique** - nécessite appels explicites
- **Pas de timeout configurable** - dépend timestamps fichiers
- **Pas de détection zombie** - processus morts non détectés

### 2.4 Workflow Décisions

**Cycle de vie (5 phases) :**

```
PENDING → APPROVED → IN_PROGRESS → APPLIED → ARCHIVED
   ↓         ↓           ↓           ↓
Création   Checkbox    Exécution   Rollback
           [x]        PowerShell    30j
```

**Limitations :**
- Parsing regex (fragile)
- Pas de retry automatique
- Rollback all-or-nothing
- Pas de transactions

---

## 3. Gaps Identifiés

### 3.1 Consensus Distribué (CRITIQUE)

**Problème :** Aucune garantie que toutes les machines atteignent le même état.

**Scénario de défaillance :**
```
T1: myia-ai-01 applique décision D1
T2: myia-po-2024 offline, ne voit pas D1
T3: myia-po-2024 crée décision D2 (conflictuelle)
T4: Deux décisions coexistent, pas de résolution
```

**Recommandation :** Implémenter un **commit log ordonné**
```
.shared-state/commit-log/
├── 0000001.json  # Décision D1
├── 0000002.json  # Config C1
└── state-machine.json
```

### 3.2 Heartbeat Automatique (CRITIQUE)

**Problème :** Impossible de détecter de manière fiable les agents morts.

**Solution proposée :**
```typescript
// Heartbeat toutes les 30 secondes
setInterval(async () => {
  await presenceManager.updatePresence(machineId, {
    lastSeen: new Date().toISOString(),
    status: 'online'
  });
}, 30000);

// Offline si lastSeen > 2 minutes
function isOnline(presence: PresenceData): boolean {
  return (Date.now() - new Date(presence.lastSeen).getTime()) < 120000;
}
```

### 3.3 Résolution Conflits (HIGH)

**Problème :** Configuration existe mais pas implémentée.

```typescript
// Dans config: conflictStrategy: 'manual' | 'auto-local' | 'auto-remote'
// Mais aucun code ne l'utilise réellement
```

**Solution :**
```typescript
async function resolveConflict(divergences, strategy) {
  switch (strategy) {
    case 'auto-local': return { action: 'keep-local' };
    case 'auto-remote': return { action: 'pull-remote' };
    default: return { action: 'require-user-input' };
  }
}
```

### 3.4 Threading Messages (MEDIUM)

**Problème :** Conversations impossibles à tracer.

**Solution :** Ajouter métadonnées structurées
```yaml
message_id: "msg-20260115-091530"
in_reply_to: "msg-20260115-090000"
thread_id: "thread-20260115-config-sync"
type: "decision_status" | "error_report" | "sync_request"
```

### 3.5 Validation État (MEDIUM)

**Problème :** Pas de vérification cohérence inter-fichiers.

**Exemple :**
- `sync-dashboard.json` : machine X = "online"
- `presence/machine-x.json` : "offline" (stale)
- Aucun mécanisme ne détecte cette incohérence

---

## 4. Matrice de Maturité

| Mécanisme | Implémenté | Maturité | Priorité Amélioration |
|-----------|------------|----------|----------------------|
| Messagerie | ✅ | 70% | P2 |
| Fichiers partagés | ✅ | 80% | P3 |
| Présence | ⚠️ Partiel | 60% | P1 |
| Heartbeat | ❌ | 0% | **P0** |
| Consensus | ❌ | 0% | **P0** |
| Décisions | ✅ | 75% | P2 |
| Conflits | ⚠️ Config only | 30% | P1 |
| Threading | ❌ | 0% | P2 |
| Validation | ❌ | 0% | P2 |
| Auth/Sécurité | ❌ | 0% | P3 |

---

## 5. Recommandations Prioritaires

### Phase 1 : Fondations (P0)

| Tâche | Description | Effort |
|-------|-------------|--------|
| **T3.15a** | Implémenter heartbeat automatique (30s) | 2-3h |
| **T3.15b** | Ajouter timeout offline (2min) | 1h |
| **T3.15c** | Créer commit log ordonné | 4-6h |

### Phase 2 : Robustesse (P1)

| Tâche | Description | Effort |
|-------|-------------|--------|
| **T3.16a** | Implémenter stratégies de conflits | 3-4h |
| **T3.16b** | Validation cohérence inter-fichiers | 2-3h |
| **T3.16c** | Détection et cleanup zombies | 2h |

### Phase 3 : Traçabilité (P2)

| Tâche | Description | Effort |
|-------|-------------|--------|
| **T3.17a** | Ajouter threading messages | 2-3h |
| **T3.17b** | Archivage automatique (7j actif, 30j archive) | 2h |
| **T3.17c** | Types de messages standardisés | 1-2h |

---

## 6. Architecture Cible

```
.shared-state/
├── commit-log/                    # [NEW] Log ordonné
│   ├── 0000001.json
│   └── state.json
├── messages/
│   ├── 2026-01-15/                # [NEW] Organisation temporelle
│   │   └── 091530-ai01-po24.json
│   └── archive/2026-01/
├── presence/
│   ├── myia-ai-01.json
│   └── heartbeat.json             # [NEW] Agrégat heartbeats
├── sync-config.ref.json
├── sync-dashboard.json
└── sync-roadmap.md
```

---

## 7. Prochaines Étapes

1. **Valider cette analyse** avec l'équipe
2. **Créer sous-tâches T3.15** pour heartbeat + commit log
3. **Estimer effort total** pour Phase 1 (~10h)
4. **Assigner** aux agents appropriés

---

## 8. Fichiers Analysés

- `src/tools/roosync/read_inbox.ts`
- `src/services/roosync/PresenceManager.ts`
- `src/services/MessageManager.ts`
- `docs/architecture/roosync-temporal-messages-architecture.md`
- `.shared-state/` structure

---

**Rapport généré par Claude Code (myia-po-2023)**
**Date :** 2026-01-15T12:30:00Z
