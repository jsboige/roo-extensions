# Worktree Cleanup Protocol

**Version:** 1.0.0
**Created:** 2026-03-25
**Issue:** #856

---

## Vue d'ensemble

Les worktrees Git orphelins (dossiers `.claude/worktrees/` sans entrée dans `git worktree list`) s'accumulent et consomment de l'espace disque. Ce protocole définit la procédure de détection et de nettoyage automatique.

---

## Phase 1: Detection & Alerting (Implémenté)

### Check automatique

Le script `scripts/worktree/check-worktrees.ps1` détecte:
1. **Worktrees orphelins**: Dossiers dans `.claude/worktrees/` non enregistrés dans `git worktree list`
2. **Worktrees expirés**: Worktrees dont la branche est mergée ou fermée
3. **Seuil d'alerte**: Si >2 worktrees actifs, alerter dans INTERCOM

### Commandes de détection

```powershell
# Lister les worktrees Git enregistrés
git worktree list

# Lister les dossiers worktrees physiques
Get-ChildItem -Path ".claude/worktrees" -Directory | Select-Object Name, LastWriteTime

# Détecter les orphelins (dossiers sans entrée git)
$gitWorktrees = git worktree list --porcelain | Where-Object { $_ -match "^worktree " } | ForEach-Object { $_ -replace "worktree ", "" }
$physicalWorktrees = Get-ChildItem -Path ".claude/worktrees" -Directory | ForEach-Object { $_.FullName }
$orphans = $physicalWorktrees | Where-Object { $_ -notin $gitWorktrees }
```

---

## Phase 2: Auto-Cleanup (Planifié)

### Critères de suppression automatique

Un worktree peut être supprimé automatiquement si:
1. Il est orphelin (non enregistré dans git)
2. ET son `LastWriteTime` > 7 jours
3. ET aucune modification non commitée

### Procédure de cleanup manuelle

```powershell
# 1. Identifier le worktree à nettoyer
$wtName = "wt-feature-xyz"
$wtPath = ".claude/worktrees/$wtName"

# 2. Vérifier s'il est enregistré dans git
git worktree list | Select-String $wtName

# 3a. Si enregistré: retirer proprement
git worktree remove $wtPath --force

# 3b. Si orphelin: supprimer le dossier directement
Remove-Item -Path $wtPath -Recurse -Force
```

---

## Gestion des erreurs Windows

### Problème: Long paths (>260 caractères)

Windows limite les chemins à 260 caractères par défaut. Les worktrees profonds peuvent dépasser.

**Solution:**
```powershell
# Activer long paths dans le registre (admin requis)
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1

# Ou utiliser le préfixe \\?\ pour les chemins longs
Remove-Item -Path "\\?\$fullPath" -Recurse -Force
```

### Problème: Fichiers verrouillés

Un processus peut verrouiller un fichier dans le worktree.

**Solution:**
```powershell
# Identifier le processus verrouillant
$lockedFiles = openfiles /query /fo csv 2>$null | ConvertFrom-Csv | Where-Object { $_.OpenFile -match $wtPath }

# Forcer la fermeture (admin requis)
# Ou redémarrer VS Code / les terminaux avant cleanup
```

### Problème: Permissions insuffisantes

Certains fichiers générés peuvent avoir des permissions restrictives.

**Solution:**
```powershell
# Prendre possession
takeown /f $wtPath /r /d y
icacls $wtPath /grant administrators:F /t
Remove-Item -Path $wtPath -Recurse -Force
```

---

## Intégration Scheduler

### Check périodique

Le scheduler exécute le check à chaque cycle:

```powershell
# Dans le workflow scheduler
$worktreeCount = (Get-ChildItem -Path ".claude/worktrees" -Directory -ErrorAction SilentlyContinue).Count
if ($worktreeCount -gt 2) {
    Write-Warning "WORKTREE ALERT: $worktreeCount worktrees detected (threshold: 2)"
    # Écrire dans INTERCOM
}
```

### Alerte INTERCOM

```markdown
## [DATE] scheduler -> all [WARN]
### Worktree Cleanup Required
- Worktrees actifs: X (seuil: 2)
- Orphelins détectés: Y
- Action: Exécuter `scripts/worktree/cleanup-worktrees.ps1`
---
```

---

## Scripts de référence

| Script | Usage |
|--------|-------|
| `scripts/worktree/check-worktrees.ps1` | Détection et alerting |
| `scripts/worktree/cleanup-worktrees.ps1` | Auto-cleanup (Phase 2) |

---

## Checklist de validation

- [x] Phase 1: Détection des orphelins
- [x] Phase 1: Alerte si >2 worktrees
- [ ] Phase 2: Auto-cleanup des orphelins >7 jours
- [ ] Phase 2: Intégration garbage collection git

---

**Référence:** Issue #856
**Dernière mise à jour:** 2026-03-25
