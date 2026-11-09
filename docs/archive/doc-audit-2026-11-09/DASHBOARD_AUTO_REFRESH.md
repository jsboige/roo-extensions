# Automatisation Dashboard Refresh

**Issue:** #460
**Date:** 2026-02-12
**Objectif:** Dashboard refresh automatique toutes les heures avec retard < 1h

---

## Contexte

Le dashboard RooSync (`DASHBOARD.md`) affiche la comparaison des configurations MCP entre les machines. Actuellement, il est généré manuellement via `roosync_refresh_dashboard` ou le script PowerShell `generate-mcp-dashboard.ps1`.

**Problème actuel :** Dernier refresh manuel (10:38), pas d'automatisation = dashboard stale.

**Objectif :** Refresh automatique toutes les heures, retard < 1h.

---

## Options d'Implémentation

### Option A - Intégration Scheduler Coordinator (RECOMMANDÉ)

**Principe :** Ajouter une étape de refresh dashboard dans le workflow du coordinator (myia-ai-01) après traitement des messages RooSync.

**Avantages :**
- Centralisé sur le coordinator
- Évite les refreshes redondants (6 machines × N fois/jour = surcharge)
- S'intègre naturellement dans le flux de coordination
- Pas besoin de planificateur externe

**Désavantages :**
- Dépend de l'exécution du scheduler coordinator (toutes les 3h actuellement)
- Si le coordinator ne tourne pas, pas de refresh

**Implémentation :**

1. **Modifier le workflow coordinator**

   Fichier : `.claude/skills/sync-tour/SKILL.md` (ou `.roo/scheduler-workflow-coordinator.md`)

   Ajouter une **Phase 7.5 : Refresh Dashboard** (entre Phase 7 et Phase 8) :

   ```markdown
   ## Phase 7.5 : Refresh Dashboard

   **Objectif :** Maintenir le dashboard RooSync à jour.

   ### Actions

   1. Vérifier l'âge du dashboard actuel :
      ```bash
      $dashboardPath = "G:/Mon Drive/Synchronisation/RooSync/.shared-state/dashboards/DASHBOARD.md"
      $lastModified = (Get-Item $dashboardPath).LastWriteTime
      $age = (Get-Date) - $lastModified
      ```

   2. Si âge > 1h, rafraîchir :
      - Via MCP : `roosync_refresh_dashboard()`
      - Via script : `powershell scripts/roosync/generate-mcp-dashboard.ps1`

   3. Vérifier le succès :
      - Dashboard modifié récemment (< 5 min)
      - Contient "Généré: 2026-02-12 HH:MM:SS"
      - Toutes les 6 machines présentes

   ### Output attendu
   ```
   ## Phase 7.5 : Dashboard Refresh

   ✅ Dashboard rafraîchi (âge avant: 2h 15min)
   - Généré: 2026-02-12 13:45:12
   - 6 machines analysées
   - Dashboard à jour
   ```
   ```

2. **Tester localement**

   Exécuter le workflow coordinator manuellement et vérifier que la Phase 7.5 s'exécute correctement.

3. **Déployer sur myia-ai-01**

   Une fois validé, déployer le workflow modifié sur le coordinator.

**Fréquence résultante :** Toutes les 3h (intervalle du scheduler coordinator actuel).

**Pour augmenter la fréquence à 1h :**
- Option 1 : Réduire l'intervalle du scheduler coordinator de 3h à 1h
- Option 2 : Créer une tâche scheduler dédiée sur myia-ai-01 (voir Option B)

---

### Option B - Script PowerShell Scheduled (Windows Task Scheduler)

**Principe :** Créer une tâche Windows Task Scheduler sur myia-ai-01 qui exécute le refresh toutes les heures.

**Avantages :**
- Indépendant du scheduler Roo
- Fréquence configurable (1h, 30min, etc.)
- Toujours actif tant que Windows tourne

**Désavantages :**
- Nécessite configuration Windows Task Scheduler (non versionné)
- Une tâche supplémentaire à maintenir
- Si myia-ai-01 est éteinte, pas de refresh

**Implémentation :**

1. **Créer le script de refresh**

   Fichier : `scripts/roosync/auto-refresh-dashboard.ps1`

   ```powershell
   <#
   .SYNOPSIS
       Refresh automatique du dashboard RooSync
   .DESCRIPTION
       Script exécuté toutes les heures par Windows Task Scheduler
       sur myia-ai-01 pour maintenir le dashboard à jour.
   #>

   [CmdletBinding()]
   param()

   $ErrorActionPreference = "Stop"

   # Chemins
   $repoPath = "c:/dev/roo-extensions"
   $dashboardPath = "G:/Mon Drive/Synchronisation/RooSync/.shared-state/dashboards/DASHBOARD.md"
   $logPath = "$repoPath/logs/dashboard-refresh.log"

   # Logger avec timestamp
   function Write-Log {
       param([string]$Message)
       $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
       $logMessage = "[$timestamp] $Message"
       Write-Host $logMessage
       Add-Content -Path $logPath -Value $logMessage
   }

   Write-Log "🔄 Début refresh dashboard automatique"

   # Vérifier l'âge du dashboard
   if (Test-Path $dashboardPath) {
       $lastModified = (Get-Item $dashboardPath).LastWriteTime
       $age = (Get-Date) - $lastModified
       Write-Log "   Dashboard actuel: âge $($age.TotalHours.ToString('F1'))h"

       if ($age.TotalHours -lt 1) {
           Write-Log "   ⏩ Dashboard récent (< 1h), skip refresh"
           exit 0
       }
   } else {
       Write-Log "   ⚠️  Dashboard non trouvé, création nécessaire"
   }

   # Refresh via script PowerShell
   try {
       Set-Location $repoPath
       Write-Log "   → Exécution generate-mcp-dashboard.ps1"

       & "$repoPath/scripts/roosync/generate-mcp-dashboard.ps1" -Force

       if (Test-Path $dashboardPath) {
           $newModified = (Get-Item $dashboardPath).LastWriteTime
           Write-Log "   ✅ Dashboard refreshed: $newModified"
           exit 0
       } else {
           Write-Log "   ❌ Échec: Dashboard non créé"
           exit 1
       }
   } catch {
       Write-Log "   ❌ Erreur: $($_.Exception.Message)"
       exit 1
   }
   ```

2. **Créer la tâche Windows Task Scheduler**

   Script de configuration : `scripts/roosync/setup-dashboard-refresh-task.ps1`

   ```powershell
   <#
   .SYNOPSIS
       Configure Windows Task Scheduler pour refresh dashboard automatique
   #>

   [CmdletBinding()]
   param()

   $taskName = "RooSync Dashboard Refresh"
   $scriptPath = "c:/dev/roo-extensions/scripts/roosync/auto-refresh-dashboard.ps1"
   $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 1)
   $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
   $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive

   # Créer ou mettre à jour la tâche
   Register-ScheduledTask -TaskName $taskName -Trigger $trigger -Action $action -Principal $principal -Force

   Write-Host "✅ Tâche '$taskName' configurée (toutes les heures)" -ForegroundColor Green
   ```

3. **Déployer sur myia-ai-01**

   ```powershell
   # Sur myia-ai-01
   cd c:/dev/roo-extensions
   powershell scripts/roosync/setup-dashboard-refresh-task.ps1
   ```

4. **Vérifier l'exécution**

   ```powershell
   # Voir les logs
   cat c:/dev/roo-extensions/logs/dashboard-refresh.log

   # Vérifier la tâche
   Get-ScheduledTask -TaskName "RooSync Dashboard Refresh"

   # Exécuter manuellement pour tester
   Start-ScheduledTask -TaskName "RooSync Dashboard Refresh"
   ```

**Fréquence résultante :** Toutes les heures.

---

### Option C - Intégration Scheduler Executor (DÉCONSEILLÉ)

**Principe :** Chaque machine refresh le dashboard après son rapport.

**Désavantages critiques :**
- 6 machines × N fois/jour = surcharge et conflits d'écriture
- Redondance massive (5 refreshes inutiles pour 1 utile)
- Potentiel de conflits git si dashboard versionné

**Recommandation :** ❌ NE PAS UTILISER cette option.

---

## Comparaison des Options

| Critère | Option A (Coordinator) | Option B (Task Scheduler) | Option C (Executor) |
|---------|------------------------|---------------------------|---------------------|
| **Simplicité** | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ |
| **Fréquence** | 3h (config actuelle) | 1h (configurable) | Trop fréquent |
| **Redondance** | ✅ Aucune | ✅ Aucune | ❌ Massive |
| **Dépendances** | Scheduler Roo | Windows Task Scheduler | Scheduler Roo |
| **Maintenance** | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐ |
| **Recommandé** | ✅ **OUI** | ✅ Acceptable | ❌ **NON** |

---

## Recommandation Finale

**Option A (Intégration Coordinator)** est la solution recommandée pour :
- Simplicité d'intégration
- Aucune redondance
- Maintenance centralisée

**Si fréquence 1h requise :**
- Combiner Option A + réduction intervalle coordinator (3h → 1h)
- OU déployer Option B en complément (tâche dédiée 1h)

---

## Critères de Succès

- [ ] Dashboard refresh automatique configuré
- [ ] Fréquence : toutes les heures (ou 3h selon option choisie)
- [ ] Retard < 1h entre dernière modification et timestamp actuel
- [ ] Logs de refresh disponibles pour debugging
- [ ] Pas de conflits d'écriture entre machines

---

## Prochaines Actions

1. **Décision :** Choisir Option A ou B (ou combinaison)
2. **Implémentation :** Suivre la procédure de l'option choisie
3. **Validation :** Tester pendant 24h, vérifier les logs
4. **Documentation :** Mettre à jour #460 avec la solution déployée

---

**Document complet - Prêt pour décision et implémentation**
