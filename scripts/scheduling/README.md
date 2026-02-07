# Scheduling Claude Code Workers

Scripts pour l'execution planifiee de Claude Code en mode autonome.

## Scripts

### start-claude-worker.ps1

Worker generique qui lance Claude Code avec un prompt et un timeout.

```powershell
# Sync-tour de 30 minutes
.\start-claude-worker.ps1 -Task "sync-tour" -MaxMinutes 30

# Executor de 60 minutes
.\start-claude-worker.ps1 -Task "executor" -MaxMinutes 60

# Tache personnalisee
.\start-claude-worker.ps1 -Task "Verifie les tests et corrige les erreurs" -MaxMinutes 20

# Dry run
.\start-claude-worker.ps1 -Task "sync-tour" -DryRun
```

Taches predefinies :
- `sync-tour` : Tour de synchronisation complet
- `executor` : Mode executant (prend des taches)
- `tests` : Build + tests + corrections
- `cleanup` : Nettoyage et documentation

### sync-tour-scheduled.ps1

Wrapper optimise pour les sync-tours planifies :
- Git pull avant execution
- Detection intelligente (skip si rien a faire)
- Git push apres modifications
- Log rotation automatique (7 jours par defaut)

```powershell
.\sync-tour-scheduled.ps1 -MaxMinutes 20 -SkipPermissions
```

## Configuration Task Scheduler Windows

### Creer une tache planifiee

```powershell
# Ouvrir Task Scheduler
taskschd.msc

# Ou via PowerShell
$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -File D:\Dev\roo-extensions\scripts\scheduling\sync-tour-scheduled.ps1 -SkipPermissions" `
    -WorkingDirectory "D:\Dev\roo-extensions"

$trigger = New-ScheduledTaskTrigger -Daily -At "09:00"

$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -DontStopOnIdleEnd `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 45)

Register-ScheduledTask `
    -TaskName "RooSync-SyncTour" `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Description "Sync-tour Claude Code quotidien"
```

### Exemples de planification

| Frequence | Tache | Commande |
|-----------|-------|----------|
| Quotidien 9h | Sync-tour | `sync-tour-scheduled.ps1` |
| 2x/jour | Sync-tour | Triggers a 9h et 17h |
| Toutes les 4h | Executor | `start-claude-worker.ps1 -Task executor -MaxMinutes 45` |
| Hebdo lundi | Tests complets | `start-claude-worker.ps1 -Task tests -MaxMinutes 60` |

## Contraintes Credits

### Anthropic Claude (Opus 4.6)
- Couteux en credits
- Utiliser pour taches complexes (executor, debug)
- Limiter les sync-tours a 1-2/jour

### z.ai GLM 4.7 Flash (alternative)
- Moins couteux
- Suffisant pour sync-tours simples
- Utiliser `-Provider z-ai` si disponible

### Optimisation
- `sync-tour-scheduled.ps1` skip automatiquement si rien a faire
- Les logs permettent de verifier l'utilisation
- Commencer avec 1 sync-tour/jour et augmenter si necessaire

## Logs

Les logs sont ecrits dans `logs/scheduling/` :

```
logs/scheduling/
    myia-po-2023-sync-20260207-090000.log
    myia-po-2023-executor-20260207-140000.log
    .last-sync-myia-po-2023    (dernier commit synced)
```

Rotation automatique : les logs de plus de 7 jours sont supprimes.

## Securite

### --dangerously-skip-permissions

**ATTENTION :** Le flag `-SkipPermissions` (qui passe `--dangerously-skip-permissions` a Claude) desactive **toutes** les confirmations utilisateur. En mode autonome (scheduler), cela signifie que :

- Claude executera des commandes shell sans confirmation
- Les messages RooSync recus pourraient contenir du **prompt injection** (un message malveillant pourrait faire executer des commandes arbitraires)
- Les fichiers lus (INTERCOM, issues GitHub) pourraient egalement contenir des instructions malveillantes

**Recommandations :**

- N'utiliser `-SkipPermissions` que sur des machines de confiance
- S'assurer que les sources de messages (RooSync GDrive, GitHub) sont controlees
- Verifier les logs apres chaque execution autonome
- Preferer le mode interactif pour les taches sensibles

## Troubleshooting

### Claude non trouve
```powershell
# Verifier que claude est dans le PATH
claude --version
```

### Permissions
```powershell
# Si erreur de permissions, utiliser -SkipPermissions
.\start-claude-worker.ps1 -Task "sync-tour" -SkipPermissions
```

### Timeout trop court
Augmenter `-MaxMinutes` pour les taches complexes.

### Logs trop volumineux
Reduire `-LogRetentionDays` (defaut: 7).
