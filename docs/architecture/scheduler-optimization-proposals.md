# Optimisations Scheduler Roo - Propositions

**Date:** 2026-02-18
**Basé sur:** Audit myia-po-2026 (#487)
**Objectif:** Améliorer le taux de succès et l'efficacité du scheduler Roo

---

## Résumé Exécutif

Basé sur l'audit du scheduler Roo, 4 catégories d'optimisations sont proposées :

1. **Critères d'escalade affinés** - Meilleure détection des tâches complexes
2. **Nouvelles catégories de tâches** - Classification plus granulaire
3. **Timeouts ajustés** - Valeurs plus réalistes basées sur l'expérience
4. **Mécanismes de monitoring** - Collecte automatique de métriques

---

## 1. Critères d'Escalade Affinés

### État Actuel

Les critères d'escalade dans `modes-config.json` sont généraux :

```json
"escalationCriteria": [
  "La tache necessite des decisions architecturales",
  "Le probleme est plus complexe que prevu apres investigation",
  "Les modifications touchent plus de 3 fichiers interconnectes",
  "Les erreurs persistent apres 2 tentatives de correction"
]
```

### Propositions

#### 1.1. Ajouter Métriques de Temps

**Nouveau critère :** Temps d'exécution dépassant un seuil

```json
{
  "escalationCriteria": [
    "...",
    "Temps d'exécution > 15 min sans progression visible",
    "Nombre d'itérations > 5 sans succès",
    "Utilisation CPU/Memory anormale (> 80% pendant > 5 min)"
  ]
}
```

**Rationale :** Certaines tâches simples peuvent bloquer indéfiniment. Un timeout basé sur le temps est plus fiable que le nombre d'itérations.

#### 1.2. Détecter Patterns d'Échec Répétitifs

**Nouveau mécanisme :** Historique des échecs par type de tâche

```json
{
  "failurePatterns": {
    "git-sync": {
      "threshold": 3,
      "action": "escalate-to-sync-complex"
    },
    "build": {
      "threshold": 2,
      "action": "escalate-to-code-complex"
    },
    "test": {
      "threshold": 2,
      "action": "escalate-to-debug-complex"
    }
  }
}
```

**Rationale :** Si une tâche échoue 3 fois de suite en mode simple, il est probable qu'elle nécessite le mode complex.

#### 1.3. Ajuster Critères par Famille

**Code :**
```json
{
  "escalationCriteria": [
    "La tache nécessite des décisions architecturales",
    "Le problème est plus complexe que prévu après investigation",
    "Les modifications touchent plus de 3 fichiers interconnectés",
    "Les erreurs persistent après 2 tentatives de correction",
    "Refactoring impactant > 5 fichiers",
    "Nouveau pattern architectural requis",
    "Performance critique (O(n²) → O(n log n))"
  ]
}
```

**Debug :**
```json
{
  "escalationCriteria": [
    "La cause racine n'est pas évidente après première analyse",
    "Le bug implique des interactions entre plusieurs composants",
    "Race conditions, memory leaks, ou problèmes de performance",
    "Le problème persiste après 2 tentatives de fix",
    "Bug intermittent (reproduit < 50% du temps)",
    "Stack trace incomplète ou misleading"
  ]
}
```

**Architect :**
```json
{
  "escalationCriteria": [
    "Un nouveau pattern architectural est requis",
    "Impact significatif sur la scalabilité ou la performance",
    "Migration ou refonte majeure nécessaire",
    "Plusieurs composants doivent être restructurés simultanément",
    "Trade-offs complexes (performance vs maintenabilité vs coût)",
    "Impact sur > 3 systèmes ou services"
  ]
}
```

---

## 2. Nouvelles Catégories de Tâches

### État Actuel

Les tâches sont classées par mode (code-simple, debug-complex, etc.) mais pas par type de travail.

### Propositions

#### 2.1. Catégories Principales

```json
{
  "taskCategories": {
    "maintenance": {
      "description": "Tâches de maintenance routine",
      "defaultMode": "code-simple",
      "escalationMode": "code-complex",
      "timeoutMinutes": 15,
      "examples": [
        "Git sync et cleanup",
        "Rotation des logs",
        "Mise à jour des dépendances",
        "Nettoyage des worktrees"
      ]
    },
    "consolidation": {
      "description": "Refactoring et consolidation de code",
      "defaultMode": "code-complex",
      "escalationMode": "architect-complex",
      "timeoutMinutes": 30,
      "examples": [
        "Consolidation d'outils MCP",
        "Refactoring de patterns",
        "Élimination de code dupliqué",
        "Standardisation des interfaces"
      ]
    },
    "feature": {
      "description": "Nouvelles fonctionnalités",
      "defaultMode": "code-complex",
      "escalationMode": "architect-complex",
      "timeoutMinutes": 45,
      "examples": [
        "Implémentation d'un nouveau MCP",
        "Ajout de fonctionnalités RooSync",
        "Création de scripts d'automatisation",
        "Intégration avec services externes"
      ]
    },
    "bugfix": {
      "description": "Corrections de bugs",
      "defaultMode": "debug-simple",
      "escalationMode": "debug-complex",
      "timeoutMinutes": 20,
      "examples": [
        "Correction d'erreur de syntaxe",
        "Fix de bug isolé",
        "Correction de test échouant",
        "Résolution de conflit Git"
      ]
    },
    "investigation": {
      "description": "Analyse et diagnostic",
      "defaultMode": "ask-simple",
      "escalationMode": "ask-complex",
      "timeoutMinutes": 25,
      "examples": [
        "Analyse de performance",
        "Investigation de bug complexe",
        "Recherche de solution technique",
        "Audit de sécurité"
      ]
    }
  }
}
```

#### 2.2. Tags pour Filtrage

```json
{
  "taskTags": {
    "priority": ["critical", "high", "medium", "low"],
    "scope": ["single-file", "multi-file", "cross-system"],
    "risk": ["low", "medium", "high", "critical"],
    "dependencies": ["none", "internal", "external"]
  }
}
```

**Utilisation :**
```json
{
  "taskId": "msg-20260218-abc123",
  "category": "bugfix",
  "tags": {
    "priority": "high",
    "scope": "multi-file",
    "risk": "medium",
    "dependencies": "internal"
  }
}
```

---

## 3. Timeouts Ajustés

### État Actuel

Les timeouts dans `setup-scheduler.ps1` sont :

| Tâche | Timeout Actuel | Observations |
|--------|----------------|--------------|
| prepare-intercom | 10 min | Peut être court pour gros INTERCOM |
| analyze-roo | 10 min | Peut être court pour analyse profonde |
| sync-tour | 20 min | Peut être court pour gros changements |

### Propositions

#### 3.1. Timeouts par Catégorie

```json
{
  "timeouts": {
    "maintenance": {
      "default": 15,
      "max": 30
    },
    "consolidation": {
      "default": 30,
      "max": 60
    },
    "feature": {
      "default": 45,
      "max": 90
    },
    "bugfix": {
      "default": 20,
      "max": 40
    },
    "investigation": {
      "default": 25,
      "max": 50
    }
  }
}
```

#### 3.2. Timeouts Dynamiques

**Mécanisme :** Ajuster le timeout basé sur l'historique

```json
{
  "dynamicTimeouts": {
    "enabled": true,
    "algorithm": "exponential-backoff",
    "baseTimeout": 15,
    "maxTimeout": 90,
    "backoffFactor": 1.5,
    "historyWindow": 5
  }
}
```

**Exemple :**
- Tâche 1 : 15 min (base)
- Tâche 2 : 22.5 min (15 × 1.5)
- Tâche 3 : 33.75 min (22.5 × 1.5)
- Tâche 4 : 50.6 min (33.75 × 1.5)
- Tâche 5 : 75.9 min (50.6 × 1.5)
- Tâche 6 : 90 min (max atteint)

---

## 4. Mécanismes de Monitoring

### 4.1. Collecte de Métriques

**Script à créer :** `scripts/scheduling/collect-metrics.ps1`

```powershell
<#
.SYNOPSIS
    Collecte les métriques du scheduler Roo

.DESCRIPTION
    Analyse les logs récents et génère un rapport JSON
#>

param(
    [int]$Days = 7,
    [string]$OutputPath = ".claude\logs\metrics.json"
)

# Analyser les logs
$Logs = Get-ChildItem ".claude\logs\*.log" | 
    Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-$Days) }

$Metrics = @{
    totalExecutions = $Logs.Count
    successRate = 0
    escalationRate = 0
    avgDuration = 0
    byCategory = @{}
    byMode = @{}
}

# Calculer les métriques...
# (implémentation détaillée dans le script)

$Metrics | ConvertTo-Json -Depth 10 | Out-File $OutputPath
```

**Métriques collectées :**

```json
{
  "period": "2026-02-11 to 2026-02-18",
  "totalExecutions": 42,
  "successRate": 0.85,
  "escalationRate": 0.15,
  "avgDuration": 18.5,
  "byCategory": {
    "maintenance": {
      "total": 15,
      "success": 14,
      "escalated": 1,
      "avgDuration": 12.3
    },
    "bugfix": {
      "total": 12,
      "success": 10,
      "escalated": 2,
      "avgDuration": 22.1
    }
  },
  "byMode": {
    "code-simple": {
      "total": 25,
      "success": 23,
      "escalated": 2
    },
    "code-complex": {
      "total": 5,
      "success": 5,
      "escalated": 0
    }
  }
}
```

### 4.2. Dashboard RooSync

**Intégration :** Ajouter un onglet "Scheduler Metrics" au dashboard RooSync

```json
{
  "schedulerMetrics": {
    "enabled": true,
    "refreshInterval": 300,
    "charts": [
      {
        "type": "line",
        "title": "Taux de Succès",
        "metric": "successRate",
        "period": "7d"
      },
      {
        "type": "bar",
        "title": "Exécutions par Catégorie",
        "metric": "byCategory",
        "period": "7d"
      },
      {
        "type": "pie",
        "title": "Distribution des Modes",
        "metric": "byMode",
        "period": "7d"
      }
    ]
  }
}
```

### 4.3. Alertes Automatiques

**Mécanisme :** Déclencher des alertes sur anomalies

```json
{
  "alerts": {
    "enabled": true,
    "rules": [
      {
        "name": "Low Success Rate",
        "condition": "successRate < 0.7",
        "severity": "warning",
        "action": "send-roosync-message"
      },
      {
        "name": "High Escalation Rate",
        "condition": "escalationRate > 0.3",
        "severity": "warning",
        "action": "send-roosync-message"
      },
      {
        "name": "Critical Failure",
        "condition": "consecutiveFailures > 3",
        "severity": "critical",
        "action": "send-roosync-message + email"
      }
    ]
  }
}
```

---

## 5. Implémentation

### 5.1. Fichiers à Modifier

1. **`.roo/schedules.template.json`**
   - Ajouter `taskCategories`
   - Ajouter `taskTags`
   - Ajouter `timeouts` par catégorie

2. **`roo-config/modes/modes-config.json`**
   - Affiner `escalationCriteria` par famille
   - Ajouter `failurePatterns`
   - Ajouter `dynamicTimeouts`

3. **`scripts/scheduling/setup-scheduler.ps1`**
   - Mettre à jour les timeouts par défaut
   - Ajouter support pour les catégories

4. **Nouveau : `scripts/scheduling/collect-metrics.ps1`**
   - Script de collecte de métriques
   - Génération de rapport JSON

### 5.2. Plan de Tests

**Test 1 : Catégories de Tâches**
```powershell
# Créer une tâche avec catégorie "bugfix"
# Vérifier que le mode par défaut est debug-simple
# Simuler un échec → vérifier escalade vers debug-complex
```

**Test 2 : Timeouts Dynamiques**
```powershell
# Exécuter 5 tâches consécutives
# Vérifier que les timeouts augmentent progressivement
# Vérifier que le max est respecté
```

**Test 3 : Collecte de Métriques**
```powershell
# Exécuter 10 tâches variées
# Lancer collect-metrics.ps1
# Vérifier que le rapport JSON est correct
```

**Test 4 : Alertes Automatiques**
```powershell
# Simuler un taux de succès < 70%
# Vérifier qu'une alerte est envoyée via RooSync
```

---

## 6. Prochaines Étapes

1. **Immédiat :** Implémenter les propositions dans les fichiers de configuration
2. **Court terme :** Créer le script `collect-metrics.ps1`
3. **Moyen terme :** Intégrer le dashboard RooSync
4. **Long terme :** Machine learning pour prédire le mode optimal

---

## Conclusion

Ces optimisations visent à :

- ✅ **Améliorer le taux de succès** : De 50-100% → 80-95%
- ✅ **Réduire le temps d'exécution** : Timeouts dynamiques
- ✅ **Meilleure classification** : Catégories de tâches
- ✅ **Monitoring proactif** : Métriques et alertes
- ✅ **Apprentissage continu** : Patterns d'échec détectés automatiquement

**Recommandation :** Implémenter progressivement, tester sur 2-3 cycles, puis déployer sur toutes les machines.

---

**Rédigé par :** Roo Code (orchestrator-complex)
**Date :** 2026-02-18
**Basé sur :** Audit myia-po-2026 (#487)
