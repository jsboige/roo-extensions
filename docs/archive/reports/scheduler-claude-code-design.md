# Design Scheduler Claude Code - Architecture et Spécifications

**Date:** 2026-02-20
**Basé sur:** Audit scheduler Roo + Propositions d'ajustements
**Tâche:** #487 - Maturation Roo + Préparation scheduler Claude Code

---

## Résumé Exécutif

Ce document présente l'architecture et les spécifications pour le scheduler Claude Code, conçu pour compléter et améliorer le scheduler Roo existant. Le scheduler Claude Code sera plus robuste, plus traçable et plus facile à maintenir.

---

## 1. Architecture Globale

### 1.1 Vue d'Ensemble

```
┌─────────────────────────────────────────────────────────────────┐
│                    Claude Code Scheduler                      │
├─────────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │ Scheduler    │  │ Metrics      │  │ INTERCOM     │ │
│  │ Service      │  │ Collector    │  │ Writer       │ │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘ │
│         │                  │                  │          │       │
│         │                  │                  │          │       │
│         ▼                  ▼                  ▼          │       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │ Task         │  │ Metrics      │  │ INTERCOM     │ │
│  │ Executor    │  │ Storage     │  │ File        │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
│                                                             │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 Composants Principaux

| Composant | Responsabilité | Dépendances |
|-----------|----------------|---------------|
| **Scheduler Service** | Gère les exécutions planifiées | VS Code Scheduler API |
| **Task Executor** | Exécute les tâches selon le workflow | Claude Code API, GitHub CLI |
| **Metrics Collector** | Collecte et agrège les métriques | Task Executor, INTERCOM Writer |
| **Metrics Storage** | Stocke les métriques historiques | File System |
| **INTERCOM Writer** | Écrit les rapports dans l'INTERCOM | File System |
| **INTERCOM File** | Stocke les communications locales | File System |

---

## 2. Scheduler Service

### 2.1 Responsabilités

- Gérer les exécutions planifiées (intervalle configurable)
- Créer des tâches Claude Code pour chaque exécution
- Logger les événements de création/complétion
- Gérer les erreurs et les retries
- Notifier les autres composants des événements

### 2.2 Configuration

```typescript
interface SchedulerConfig {
  // Configuration de base
  enabled: boolean;
  interval: number;           // en minutes
  timeUnit: 'minute' | 'hour' | 'day';
  
  // Configuration des jours
  selectedDays: {
    sun: boolean;
    mon: boolean;
    tue: boolean;
    wed: boolean;
    thu: boolean;
    fri: boolean;
    sat: boolean;
  };
  
  // Configuration des horaires
  startHour?: string;         // "HH:MM"
  startMinute?: string;
  expirationDate?: string;
  expirationHour?: string;
  expirationMinute?: string;
  
  // Configuration de l'inactivité
  requireActivity: boolean;
  inactivityDelay: number;     // en minutes
  taskInteraction: 'skip' | 'wait';
  
  // Configuration du logging
  logging: {
    enabled: boolean;
    level: 'error' | 'warn' | 'info' | 'debug' | 'verbose';
    logTaskCreation: boolean;
    logTaskCompletion: boolean;
    logTaskFailure: boolean;
    logEscalation: boolean;
    logMCPUsage: boolean;
  };
  
  // Configuration des métriques
  metrics: {
    enabled: boolean;
    storagePath: string;       // "outputs/scheduler-metrics-{MACHINE}.md"
    autoUpdate: boolean;
    updateInterval: number;     // en minutes
  };
  
  // Configuration de l'INTERCOM
  intercom: {
    enabled: boolean;
    filePath: string;           // ".claude/local/INTERCOM-{MACHINE}.md"
    writeMethod: 'direct' | 'delegate';
    fallbackToDelegate: boolean;
  };
}
```

### 2.3 Événements

```typescript
interface SchedulerEvent {
  type: 'task_created' | 'task_started' | 'task_completed' | 'task_failed' | 'escalation';
  timestamp: string;
  taskId: string;
  mode: string;
  data?: any;
}

interface TaskCreatedEvent extends SchedulerEvent {
  type: 'task_created';
  data: {
    scheduleId: string;
    scheduledTime: string;
  };
}

interface TaskStartedEvent extends SchedulerEvent {
  type: 'task_started';
  data: {
    workflow: string;
  };
}

interface TaskCompletedEvent extends SchedulerEvent {
  type: 'task_completed';
  data: {
    duration: number;           // en secondes
    result: 'SUCCESS' | 'PARTIAL' | 'FAIL';
    escalations: Escalation[];
    mcpTools: string[];
    tasksExecuted: TaskExecution[];
  };
}

interface TaskFailedEvent extends SchedulerEvent {
  type: 'task_failed';
  data: {
    error: string;
    stackTrace?: string;
    retryCount: number;
  };
}

interface EscalationEvent extends SchedulerEvent {
  type: 'escalation';
  data: {
    fromMode: string;
    toMode: string;
    reason: string;
  };
}
```

---

## 3. Task Executor

### 3.1 Responsabilités

- Exécuter les tâches selon le workflow défini
- Gérer les escalades entre modes
- Collecter les métriques d'exécution
- Notifier le Metrics Collector des événements

### 3.2 Workflow

Le workflow Claude Code est similaire au workflow Roo mais avec des améliorations:

```markdown
# Workflow Scheduler Claude Code - EXECUTEUR

## PRINCIPES

1. **Claude Code utilise RooSync** (contrairement à Roo)
2. **TOUJOURS déléguer via `new_task`** (jamais faire le travail soi-même)
3. Communication via INTERCOM uniquement (`.claude/local/INTERCOM-{MACHINE}.md`)
4. Peut commit et push (avec validation)
5. Déléguer uniquement aux modes `-simple` ou `-complex`

---

## WORKFLOW EN 3 ÉTAPES

### Étape 1 : Git pull + Lecture INTERCOM

Exécuter ces commandes et rapporter le résultat:

```bash
git pull --no-rebase origin main
git status
```

Puis lire les 5 derniers messages de `.claude/local/INTERCOM-{MACHINE}.md`

Chercher les messages:
- `[TASK]` de claude-code → roo
- `[SCHEDULED]` de claude-code → roo
- `[URGENT]` de claude-code → roo
- `[FEEDBACK]` de roo → claude-code

**Décision:**
- Si `[URGENT]` : escalader vers `orchestrator-complex`
- Si `[TASK]` trouvé : aller à **Étape 2a**
- Si `[FEEDBACK]` récent : noter les ajustements
- Si rien : aller à **Étape 2b**

### Étape 2a : Exécuter les tâches INTERCOM

Pour chaque `[TASK]` trouvé, déléguer selon la difficulté:

| Difficulté | Action |
|-----------|--------|
| 1 action isolée | `code-simple` via `new_task` |
| 2-4 actions liées | Déléguer chaque action séparément à `code-simple` |
| 5+ actions ou dépendances | Escalader vers `orchestrator-complex` |

**Gestion des échecs:**
- 1er échec : relancer avec instructions corrigées
- 2e échec sur même tâche : arrêter et rapporter
- Erreur complexe : escalader vers `-complex`

**Chaîne d'escalade:** `code-simple` → `code-complex` → `orchestrator-complex` → Claude Code (via INTERCOM `[ESCALADE-CLAUDE]`)

Après exécution → **Étape 3**

### Étape 2b : Tâches par défaut (si pas de [TASK])

Déléguer dans cet ordre à `code-simple` via `new_task`:

**1. Build + Tests (validation santé workspace)**

```bash
cd mcps/internal/servers/roo-state-manager
npm run build
npx vitest run
```

Rapporter : build OK/FAIL + nombre tests pass/fail.

> **Note MyIA-Web1 :** Toujours utiliser `npx vitest run --maxWorkers=1` (contrainte RAM 2GB).

**2. Chercher une tâche sur GitHub**

```bash
gh issue list --repo jsboige/roo-extensions --state open --limit 10 --json number,title,labels --jq '.[] | select(.labels[]?.name == "claude-schedulable") | "\(.number)\t\(.title)"'
```

Si une issue est trouvée:
1. Lire le body complet : `gh issue view {NUM} --repo jsboige/roo-extensions`
2. Commenter pour claim : `gh issue comment {NUM} --body "Claimed by {MACHINE} (Claude Code scheduler). Mode: simple."`
3. Exécuter selon difficulté (simple → `code-simple`, complexe → `code-complex`)
4. Commenter le résultat : `gh issue comment {NUM} --body "Result: {PASS/FAIL}. Mode: {simple/complex}."`

Si aucune issue : rapporter `[IDLE]` dans INTERCOM.

Après tout → **Étape 3**

### Étape 3 : Rapporter dans INTERCOM

**MÉTHODE DIRECTE (sans délégation):**

1. Lire le fichier INTERCOM complet avec `read_file`
2. Préparer le nouveau message (format ci-dessous)
3. Ajouter le message À LA FIN du contenu existant
4. Réécrire le fichier complet avec `write_to_file`

**Format du message:**

```markdown
## [{DATE}] claude-code -> roo [{DONE|MAINTENANCE|IDLE}] [SCHEDULER-EXECUTION]
### Bilan scheduler exécuteur

- Git pull : OK/erreur
- Git status : propre/dirty
- Build : OK/FAIL
- Tests : {X} pass / {Y} fail
- Tâches exécutées : {N} (source: INTERCOM/GitHub #{num})
- Erreurs : {liste ou "aucune"}
- Escalades : {aucune ou vers {mode}}

---
```

**Maintenance INTERCOM:** Si le fichier dépasse 1000 lignes, condenser les 600 premières en ~100 lignes de synthèse, garder les 400 dernières intactes.

---

## RÈGLES DE SÉCURITÉ

1. TOUJOURS valider avec Roo avant commit/push
2. Utiliser RooSync pour la synchronisation inter-machines
3. NE JAMAIS faire `git checkout` dans le submodule `mcps/internal/`
4. **TOUJOURS utiliser les outils RooSync** (roosync_send, roosync_read, etc.)
5. Après 2 échecs sur même tâche : arrêter et rapporter

---

## CRITÈRES D'ESCALADE VERS ORCHESTRATOR-COMPLEX

- Message `[URGENT]` dans l'INTERCOM
- Plus de 5 sous-tâches à coordonner
- Dépendances entre sous-tâches
- 2 échecs consécutifs en `-simple`
- Modification de plus de 3 fichiers interconnectés
```

### 3.3 Exécution des Tâches

```typescript
interface TaskExecution {
  id: string;
  type: 'git_pull' | 'git_status' | 'build' | 'tests' | 'github_issue' | 'intercom_read' | 'intercom_write';
  status: 'pending' | 'running' | 'completed' | 'failed';
  startTime?: string;
  endTime?: string;
  duration?: number;           // en secondes
  result?: any;
  error?: string;
  mcpTools?: string[];
}

interface Escalation {
  fromMode: string;
  toMode: string;
  reason: string;
  timestamp: string;
}
```

---

## 4. Metrics Collector

### 4.1 Responsabilités

- Collecter les métriques après chaque exécution
- Agréger les statistiques globales
- Stocker les métriques dans le Metrics Storage
- Calculer les tendances et les patterns

### 4.2 Métriques Collectées

#### Métriques par Exécution

```typescript
interface ExecutionMetrics {
  // Identification
  executionId: string;
  timestamp: string;
  taskId: string;
  scheduleId: string;
  
  // Configuration
  mode: string;
  workflow: string;
  
  // Résultat
  result: 'SUCCESS' | 'PARTIAL' | 'FAIL';
  duration: number;           // en secondes
  
  // Escalades
  escalations: Escalation[];
  escalationCount: number;
  
  // Outils MCP
  mcpToolsUsed: string[];
  mcpToolUsageCount: Record<string, number>;
  
  // Tâches exécutées
  tasksExecuted: TaskExecution[];
  taskCount: number;
  taskSuccessCount: number;
  taskFailureCount: number;
  
  // Git
  gitPullSuccess: boolean;
  gitStatus: 'clean' | 'dirty';
  
  // Build & Tests
  buildSuccess: boolean;
  buildDuration?: number;
  testsPassed?: number;
  testsFailed?: number;
  testsTotal?: number;
  
  // GitHub
  githubIssuesFound?: number;
  githubIssuesClaimed?: number;
  githubIssuesExecuted?: number;
  
  // Erreurs
  errors: string[];
  errorCount: number;
  
  // INTERCOM
  intercomWriteSuccess: boolean;
  intercomWriteMethod: 'direct' | 'delegate';
}
```

#### Métriques Agrégées

```typescript
interface AggregatedMetrics {
  // Période
  period: {
    start: string;
    end: string;
    duration: number;       // en jours
  };
  
  // Exécutions
  totalExecutions: number;
  successCount: number;
  partialCount: number;
  failureCount: number;
  
  // Taux
  successRate: number;        // en %
  partialRate: number;        // en %
  failureRate: number;        // en %
  
  // Escalades
  totalEscalations: number;
  escalationRate: number;      // en %
  escalationsByMode: Record<string, number>;
  
  // Durée
  averageDuration: number;     // en secondes
  minDuration: number;
  maxDuration: number;
  
  // Outils MCP
  mcpToolsUsage: Record<string, number>;
  mostUsedMcpTools: string[];
  
  // Tâches
  totalTasks: number;
  taskSuccessRate: number;    // en %
  tasksByType: Record<string, number>;
  
  // Git
  gitPullSuccessRate: number;  // en %
  dirtyWorkspaceRate: number;   // en %
  
  // Build & Tests
  buildSuccessRate: number;    // en %
  averageTestPassRate: number; // en %
  
  // GitHub
  totalGitHubIssues: number;
  averageGitHubIssuesPerExecution: number;
  
  // Erreurs
  totalErrors: number;
  averageErrorsPerExecution: number;
  mostCommonErrors: string[];
  
  // INTERCOM
  intercomWriteSuccessRate: number; // en %
  intercomWriteMethodUsage: Record<string, number>;
  
  // Tendance
  trends: {
    successRate: 'improving' | 'stable' | 'declining';
    escalationRate: 'improving' | 'stable' | 'declining';
    duration: 'improving' | 'stable' | 'declining';
  };
}
```

### 4.3 Calcul des Tendances

```typescript
function calculateTrend(
  current: number,
  previous: number,
  threshold: number = 0.05
): 'improving' | 'stable' | 'declining' {
  const change = (current - previous) / previous;
  
  if (Math.abs(change) < threshold) {
    return 'stable';
  }
  
  // Pour le taux de succès, une augmentation est une amélioration
  if (change > 0) {
    return 'improving';
  }
  
  // Pour le taux d'escalade, une diminution est une amélioration
  if (change < 0) {
    return 'improving';
  }
  
  return 'declining';
}
```

---

## 5. Metrics Storage

### 5.1 Responsabilités

- Stocker les métriques historiques
- Fournir des méthodes de lecture/écriture
- Gérer la rotation des fichiers (si trop volumineux)

### 5.2 Format de Stockage

Les métriques sont stockées dans un fichier Markdown pour faciliter la lecture et l'analyse:

```markdown
# Scheduler Metrics - {MACHINE}

## Configuration

- Machine: {MACHINE}
- Mode: orchestrator-simple
- Intervalle: 180 minutes
- Dernière mise à jour: {DATE}

## Exécutions

| Date | Task ID | Mode | Résultat | Durée | Escalades | Outils MCP | Tâches exécutées |
|------|----------|------|----------|--------|------------|-------------|-------------------|
| 2026-02-20T10:17:00 | 019c7a8d... | orchestrator-simple | SUCCESS | 15m | 0 | gh, git | Build+Tests |
| 2026-02-20T07:17:00 | 019c6b41... | orchestrator-simple | SUCCESS | 12m | 1 | gh, git | GitHub #487 |
| 2026-02-20T04:17:00 | 019c6dd5... | orchestrator-simple | FAIL | 5m | 0 | git | Build échoue |

## Statistiques Globales

- **Taux de succès:** 66.7% (2/3)
- **Taux d'escalade:** 33.3% (1/3)
- **Durée moyenne:** 10.7m
- **Outils MCP les plus utilisés:** git (100%), gh (66.7%)
- **Types de tâches:** Build+Tests (66.7%), GitHub (33.3%)

## Tendance

- **Succès:** ↗ Amélioration (50% → 66.7%)
- **Escalades:** ↘ Diminution (50% → 33.3%)
- **Durée:** → Stable (10-15m)
```

### 5.3 API de Stockage

```typescript
interface MetricsStorage {
  // Lecture
  getExecutionMetrics(executionId: string): Promise<ExecutionMetrics | null>;
  getExecutionMetricsByDateRange(start: string, end: string): Promise<ExecutionMetrics[]>;
  getAggregatedMetrics(period: { start: string; end: string }): Promise<AggregatedMetrics>;
  
  // Écriture
  addExecutionMetrics(metrics: ExecutionMetrics): Promise<void>;
  updateAggregatedMetrics(metrics: AggregatedMetrics): Promise<void>;
  
  // Maintenance
  rotateOldMetrics(daysToKeep: number): Promise<void>;
  exportMetrics(format: 'json' | 'csv' | 'markdown'): Promise<string>;
}
```

---

## 6. INTERCOM Writer

### 6.1 Responsabilités

- Écrire les rapports dans l'INTERCOM
- Gérer les erreurs d'écriture
- Retry automatique en cas d'échec
- Fallback vers délégation si nécessaire

### 6.2 Format des Messages

```typescript
interface IntercomMessage {
  timestamp: string;
  sender: 'claude-code' | 'roo';
  receiver: 'claude-code' | 'roo' | 'all';
  type: 'DONE' | 'MAINTENANCE' | 'IDLE' | 'INFO' | 'WARN' | 'ERROR';
  title?: string;
  content: string;
  tags?: string[];
}

function formatIntercomMessage(message: IntercomMessage): string {
  const tags = message.tags ? ` [${message.tags.join('][')}]` : '';
  const title = message.title ? `\n### ${message.title}\n` : '';
  
  return `## [${message.timestamp}] ${message.sender} → ${message.receiver} [${message.type}]${tags}${title}\n${message.content}\n---\n`;
}
```

### 6.3 Méthodes d'Écriture

```typescript
interface IntercomWriter {
  // Écriture directe
  writeDirect(message: IntercomMessage): Promise<void>;
  
  // Écriture via délégation
  writeDelegate(message: IntercomMessage): Promise<void>;
  
  // Écriture avec fallback
  writeWithFallback(message: IntercomMessage): Promise<void>;
  
  // Lecture
  readLastMessages(count: number): Promise<IntercomMessage[]>;
  readAllMessages(): Promise<IntercomMessage[]>;
}
```

---

## 7. Comparaison Scheduler Roo vs Claude Code

| Aspect | Scheduler Roo | Scheduler Claude Code |
|--------|---------------|----------------------|
| **Mode d'exécution** | orchestrator-simple | orchestrator-simple |
| **Utilisation RooSync** | ❌ Interdit | ✅ Obligatoire |
| **Commit/Push** | ❌ Interdit | ✅ Avec validation |
| **Écriture INTERCOM** | Via délégation | Directe ou délégation |
| **Métriques** | Non collectées | Collectées automatiquement |
| **Logging** | Basique | Verbeux configurable |
| **Escalades** | Manuelles | Automatiques avec critères |
| **Traçabilité** | Limitée | Complète |
| **Maintenance** | Manuelle | Automatique |

---

## 8. Plan d'Implémentation

### 8.1 Phase 1: Infrastructure (Semaine 1-2)

- [ ] Créer la structure de fichiers
- [ ] Implémenter le Scheduler Service
- [ ] Implémenter le Task Executor
- [ ] Implémenter le Metrics Collector
- [ ] Implémenter le Metrics Storage
- [ ] Implémenter l'INTERCOM Writer

### 8.2 Phase 2: Intégration (Semaine 3-4)

- [ ] Intégrer le Scheduler Service avec VS Code Scheduler API
- [ ] Intégrer le Task Executor avec Claude Code API
- [ ] Intégrer le Metrics Collector avec les autres composants
- [ ] Tester l'intégration complète

### 8.3 Phase 3: Validation (Semaine 5-6)

- [ ] Tester sur myia-po-2025 (machine pilote)
- [ ] Valider que les métriques sont collectées correctement
- [ ] Valider que l'INTERCOM est mis à jour
- [ ] Valider que les escalades fonctionnent correctement

### 8.4 Phase 4: Déploiement (Semaine 7-8)

- [ ] Déployer sur les 6 machines
- [ ] Former les utilisateurs
- [ ] Documenter l'utilisation
- [ ] Monitorer les performances

---

## 9. Critères de Succès

### 9.1 Critères Techniques

- ✅ Le scheduler s'exécute à l'intervalle configuré
- ✅ Les métriques sont collectées après chaque exécution
- ✅ L'INTERCOM est mis à jour après chaque exécution
- ✅ Les escalades fonctionnent correctement
- ✅ Les logs sont verbeux et structurés

### 9.2 Critères Fonctionnels

- ✅ Le scheduler peut exécuter les tâches par défaut (build + tests + GitHub)
- ✅ Le scheduler peut exécuter les tâches INTERCOM
- ✅ Le scheduler peut escalader vers les modes complexes
- ✅ Le scheduler peut utiliser RooSync pour la synchronisation

### 9.3 Critères de Performance

- ✅ Le temps d'exécution moyen est < 15 minutes
- ✅ Le taux de succès est > 80%
- ✅ Le taux d'escalade est < 30%
- ✅ Les métriques sont disponibles en < 5 secondes

---

## 10. Risques et Mitigations

### 10.1 Risques Identifiés

| Risque | Impact | Probabilité | Mitigation |
|--------|---------|--------------|------------|
| Écriture INTERCOM échoue | Élevé | Moyenne | Fallback vers délégation, retry automatique |
| Métriques non collectées | Moyen | Faible | Logging verbeux, alertes automatiques |
| Escalades incorrectes | Moyen | Moyenne | Critères clairs, validation humaine |
| Performance dégradée | Faible | Faible | Monitoring, optimisation progressive |

### 10.2 Plan de Contingence

Si un problème critique survient:

1. **Arrêter le scheduler** immédiatement
2. **Analyser les logs** pour identifier la cause
3. **Appliquer un correctif** temporaire
4. **Redémarrer le scheduler** avec le correctif
5. **Documenter l'incident** pour éviter la récidive

---

## Conclusion

### Résumé

Le scheduler Claude Code est conçu pour être plus robuste, plus traçable et plus facile à maintenir que le scheduler Roo existant. Les améliorations principales sont:

1. **Métriques automatiques** - Collectées et stockées après chaque exécution
2. **Logging verbeux** - Événements détaillés pour faciliter le diagnostic
3. **Écriture INTERCOM robuste** - Méthodes directe et délégation avec fallback
4. **Escalades automatiques** - Critères clairs et validation
5. **Architecture modulaire** - Composants séparés et testables

### Prochaines Étapes

1. Implémenter les composants (Phase 1)
2. Intégrer les composants (Phase 2)
3. Valider sur machine pilote (Phase 3)
4. Déployer sur les 6 machines (Phase 4)

---

**Document généré par:** Roo Code (mode code-complex)
**Date:** 2026-02-20
**Tâche:** #487 - Maturation Roo + Préparation scheduler Claude Code
