# RooScheduler - Orchestration Automatique Quotidienne

## Vue d'ensemble

RooScheduler est un système d'orchestration automatique pour l'environnement Roo avec :
- Synchronisation Git quotidienne
- Tests automatiques MCP
- Validation des configurations
- Nettoyage des logs
- Auto-amélioration basée sur métriques
- **Escalade Level 3** : Invocation directe de Claude Code en cas d'échec critique

## Architecture

```
.roo/
├── schedules.json                       # Configuration machine (généré par deploy)
└── schedules.template.json              # Template pour toutes machines

roo-config/scheduler/
├── orchestration-engine.ps1             # Point d'entrée principal
├── daily-orchestration.json             # Configuration des phases
├── config.json                          # Configuration système
├── README.md                            # Cette documentation
│
├── scripts/                             # Tous les scripts PowerShell
│   ├── core/
│   │   └── scheduler-manager.ps1        # Gestionnaire principal
│   ├── install/
│   │   ├── deploy-scheduler.ps1         # Déploiement par machine
│   │   ├── setup-scheduler.ps1          # Task Scheduler Windows
│   │   ├── install-scheduler.ps1        # Installation complète
│   │   └── deploy-complete-system.ps1   # Déploiement système
│   ├── modules/
│   │   ├── claude-escalation.ps1        # Escalade Level 3 → Claude
│   │   └── self-improvement.ps1         # Auto-optimisation
│   ├── tests/
│   │   ├── test-daily-orchestration.ps1 # Tests complets
│   │   ├── test-complete-system.ps1     # Tests système
│   │   └── test-orchestration-simple.ps1# Tests rapides
│   └── utils/
│       ├── update-system.ps1            # Mises à jour
│       └── validate-sync.ps1            # Validation sync
│
├── logs/                                # Logs d'exécution
├── metrics/                             # Métriques quotidiennes
└── history/                             # Historique améliorations
```

## Installation

### 1. Déployer la configuration (chaque machine)

Après un `git pull`, chaque machine doit exécuter :

```powershell
cd roo-config/scheduler
.\scripts\install\deploy-scheduler.ps1 -Action deploy
```

Cela génère `.roo/schedules.json` à partir du template avec les chemins spécifiques à la machine.

**Autres actions disponibles :**

```powershell
.\scripts\install\deploy-scheduler.ps1 -Action status   # Vérifier l'état
.\scripts\install\deploy-scheduler.ps1 -Action test     # Tester l'orchestration (dry-run)
.\scripts\install\deploy-scheduler.ps1 -Action disable  # Désactiver
```

### 2. Installer la tâche Windows Task Scheduler (optionnel)

**Option A : Installation via script**

1. Ouvrir PowerShell **en tant qu'Administrateur**
2. Naviguer vers le répertoire :
   ```powershell
   cd roo-config/scheduler
   ```
3. Exécuter :
   ```powershell
   .\scripts\install\setup-scheduler.ps1 -Action install
   ```
4. Vérifier l'installation :
   ```powershell
   .\scripts\install\setup-scheduler.ps1 -Action status
   ```

**Option B : Installation via Gestionnaire des Tâches Windows**

1. Ouvrir `Gestionnaire des tâches` (Win+R → `taskschd.msc`)
2. Actions → Créer une tâche de base
3. Nom : `RooEnvironmentSync`
4. Déclencheur : Quotidien à 06:00
5. Action : Démarrer un programme
   - Programme : `PowerShell.exe`
   - Arguments : `-ExecutionPolicy Bypass -File "d:\Dev\roo-extensions\roo-config\scheduler\orchestration-engine.ps1" -ConfigPath "roo-config/scheduler/daily-orchestration.json" -LogLevel "INFO"`
   - Démarrer dans : `d:\Dev\roo-extensions`
6. Paramètres avancés :
   - Exécuter même si utilisateur non connecté : ✅
   - Exécuter avec les privilèges les plus élevés : ✅

### 2. Vérifier la configuration

```powershell
# Afficher les schedules configurés
cat .roo\schedules.json | ConvertFrom-Json

# Tester l'exécution manuelle (DryRun)
.\roo-config\scheduler\orchestration-engine.ps1 -DryRun -Verbose

# Vérifier le statut de la tâche
.\roo-config\scheduler\setup-scheduler.ps1 -Action status
```

## Configuration

### Modifier l'heure d'exécution

Éditer `.roo/schedules.json` :
```json
{
  "schedules": [
    {
      "id": "daily-orchestration",
      "trigger": {
        "type": "daily",
        "time": "06:00",    # <-- Modifier ici
        "timezone": "Europe/Paris"
      }
    }
  ]
}
```

Puis mettre à jour la tâche Windows :
```powershell
.\scripts\install\setup-scheduler.ps1 -Action uninstall
.\scripts\install\setup-scheduler.ps1 -Action install -ScheduleInterval 30
```

### Activer/Désactiver l'orchestration

```powershell
# Désactiver temporairement
Disable-ScheduledTask -TaskName "RooEnvironmentSync"

# Réactiver
Enable-ScheduledTask -TaskName "RooEnvironmentSync"

# Désinstaller complètement
.\scripts\install\setup-scheduler.ps1 -Action uninstall
```

## Escalade Level 3 - Claude Code

### Fonctionnement

Quand l'orchestration automatique échoue de manière critique :

1. **Détection automatique** : `Test-CriticalPhaseFailure` analyse les résultats
2. **Enregistrement** : Événement sauvegardé dans `logs/escalations-{yyyyMM}.json`
3. **Traçabilité INTERCOM** : Message écrit dans `.claude/local/INTERCOM-{machine}.md`
4. **⚡ Invocation directe** : `claude -p "<prompt>"` pour intervention immédiate

### Critères d'escalade

- Statut global = `failure` ou `error`
- Une phase critique a échoué (diagnostic, synchronization)
- Plus de 3 tâches échouées

### Prompt Claude

Le prompt envoyé contient :
- Timestamp et Execution ID
- Statut et durée d'exécution
- Raisons de l'escalade
- Phases échouées
- Actions correctives suggérées

Exemple :
```
🚨 ESCALADE LEVEL 3 - RooScheduler

L'orchestration automatique quotidienne a échoué de manière critique.

**Timestamp:** 2026-01-22 06:15:00
**Execution ID:** a1b2c3d4-e5f6-7890-abcd-ef1234567890
**Durée:** 45.2 secondes
**Statut:** FAILURE

**Raisons de l'escalade:**
Phase critique échouée: diagnostic
Nombre élevé de tâches échouées: 5

**Phases échouées:** diagnostic, synchronization
**Tâches échouées:** 5/12

**Actions requises:**
1. Examiner les logs: roo-config/scheduler/logs/
2. Vérifier l'état Git: git status
3. Consulter INTERCOM: .claude/local/INTERCOM-myia-po-2023.md
4. Corriger les problèmes identifiés
```

### Fallback

Si `claude` CLI n'est pas disponible :
- Message écrit dans INTERCOM pour consultation manuelle
- Log de warning généré
- Événement d'escalation enregistré normalement

## Phases d'orchestration

### 1. Diagnostic (Critique)
- Santé Git
- Connectivité réseau
- Validation fichiers critiques

### 2. Synchronization (Critique)
- Synchronisation Git complète
- Validation post-sync

### 3. Testing (Non-critique)
- Tests MCP
- Validation configurations

### 4. Cleanup (Non-critique)
- Nettoyage logs anciens (>30j)
- Suppression fichiers temporaires

### 5. Improvement (Non-critique)
- Analyse des performances
- Optimisation paramètres

## Métriques et Auto-amélioration

L'orchestrateur collecte des métriques quotidiennes :
- Temps d'exécution
- Taux de succès
- Patterns d'erreurs
- Utilisation ressources

Fichiers :
- `metrics/daily-metrics-{yyyyMMdd}.json`
- `logs/escalations-{yyyyMM}.json`

## Dépannage

### La tâche ne s'exécute pas

```powershell
# Vérifier le statut
.\scripts\install\setup-scheduler.ps1 -Action status

# Consulter les logs Windows
Get-ScheduledTask -TaskName "RooEnvironmentSync" | Get-ScheduledTaskInfo

# Tester manuellement
.\scripts\install\setup-scheduler.ps1 -Action test
```

### Erreur d'escalade Claude

```powershell
# Vérifier que claude CLI est disponible
claude --version

# Vérifier les logs d'escalade
cat roo-config\scheduler\logs\escalations-$(Get-Date -Format 'yyyyMM').json | ConvertFrom-Json
```

### Logs d'exécution

```powershell
# Log principal
cat roo-config\scheduler\daily-orchestration-log.json | ConvertFrom-Json

# Logs détaillés par phase
cat roo-config\scheduler\logs\diagnostic-$(Get-Date -Format 'yyyy-MM-dd').json
cat roo-config\scheduler\logs\sync-$(Get-Date -Format 'yyyy-MM-dd').json
```

## Commandes Utiles

```powershell
# Afficher le statut
.\scripts\install\setup-scheduler.ps1 -Action status

# Tester sans exécuter (dry-run)
.\orchestration-engine.ps1 -DryRun -Verbose

# Exécuter manuellement
.\orchestration-engine.ps1 -ConfigPath "roo-config/scheduler/daily-orchestration.json"

# Voir les métriques récentes
cat "roo-config/scheduler/metrics/daily-metrics-$(Get-Date -Format 'yyyyMMdd').json" | ConvertFrom-Json

# Voir les escalations du mois
cat "roo-config/scheduler/logs/escalations-$(Get-Date -Format 'yyyyMM').json" | ConvertFrom-Json

# Désinstaller
.\scripts\install\setup-scheduler.ps1 -Action uninstall
```

## Sécurité

- La tâche s'exécute avec le compte SYSTEM
- Privilèges élevés requis pour modifications Git
- Invocation Claude Code ne partage pas de données sensibles
- Logs rotation automatique (90 jours)

## Évolutions Futures

- [ ] Intégration notifications Slack/Teams
- [ ] Dashboard métriques temps réel
- [ ] Machine learning pour optimisation
- [ ] Support multi-machine via RooSync
- [ ] Escalade Level 4 : Rollback automatique

---

**Version:** 1.0.0
**Créé:** 2026-01-21
**Machine:** myia-po-2023
