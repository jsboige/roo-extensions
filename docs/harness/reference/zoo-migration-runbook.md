# Zoo Migration Fleet Rollout Runbook

**Version:** 1.0.0
**Issue:** #2379, #2381
**MAJ:** 2026-06-12
**Pilote validé:** po-2025 (2026-06-11, #2381 PASS)

---

## Contexte

Migration Roo Code (`rooveterinaryinc.roo-cline`) → Zoo Code (`zoocodeorganization.zoo-code`) sur les 5 machines exécutantes. La machine pilote **po-2025 a été validée** le 2026-06-11 sans aucune régression.

### Prérequis par machine

- [ ] Zoo Code extension installée (`zoocodeorganization.zoo-code`)
- [ ] Zoo Scheduler fork installé (`jsboige.zoo-scheduler`)
- [ ] Roo Code encore installé (source de migration) OU Roo globalStorage backup disponible
- [ ] `migrate-globalstorage.ps1` accessible dans `scripts/zoo-scheduler/`
- [ ] VS Code fermé (sinon race condition sur globalStorage)

### Constats clés (po-2025 pilote)

| Finding | Impact | Action |
|---------|--------|--------|
| `schedules.json` absent du Zoo globalStorage | **Non bloquant** — autonomie via `schtasks` + `claude -p` | Ne pas forcer |
| Zoo Scheduler (`jsboige.zoo-scheduler`) = bonus UI | Opérations critiques indépendantes du scheduler | Installer mais pas bloquant |
| `mcp_settings.json` Zoo = copie directe | Les 7 MCPs fonctionnent à l'identique | Vérifier post-copy |
| `custom_modes.yaml` Zoo = copie directe | 60KB de modes générés | Vérifier post-copy |
| Roo Code peut rester installé | Coexistence possible | Désinstaller après validation |

---

## Ordre de rollout recommandé

| Étape | Machine | Rôle | Statut |
|-------|---------|------|--------|
| 0 | **po-2025** | Pilote | ✅ VALIDÉ (#2381 PASS) |
| 1 | **po-2026** | 2ème machine (Zoo déjà actif, investigation #2543 faite) | ⬜ |
| 2 | **po-2023** | 3ème machine (Roo déjà désinstallé, Zoo installé) | ⬜ |
| 3 | **web1** | 4ème machine | ⬜ |
| 4 | **ai-01** | Coordinateur (dernier, risque minimal) | ⬜ |
| 5 | **po-2024** | Offline (#2540) — en attente redémarrage physique | ⬜ |

---

## Procédure par machine (étape-par-étape)

### Étape 0 : Préparation

```powershell
# Vérifier Zoo Code installé
code --list-extensions | Select-String "zoocodeorganization"
# Attendu: zoocodeorganization.zoo-code

# Vérifier Zoo Scheduler fork installé
code --list-extensions | Select-String "jsboige.zoo-scheduler"
# Attendu: jsboige.zoo-scheduler

# Vérifier Roo globalStorage existe (source)
$rooGS = "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline"
Test-Path $rooGS
# Si FALSE: Roo déjà désinstallé + globalStorage supprimé → utiliser backup ou SKIP migration
```

### Étape 1 : Dry-run (WhatIf)

```powershell
cd D:\dev\roo-extensions
pwsh -ExecutionPolicy Bypass -File scripts\zoo-scheduler\migrate-globalstorage.ps1 -WhatIf
```

**Vérifier la sortie :**
- Nombre de fichiers settings à copier (attendu: 2-3)
- Nombre de répertoires tasks à copier
- Aucune erreur

### Étape 2 : Migration effective

```powershell
pwsh -ExecutionPolicy Bypass -File scripts\zoo-scheduler\migrate-globalstorage.ps1
```

**Vérifier la sortie :**
- `[OK]` pour `mcp_settings.json` et `custom_modes.yaml`
- Nombre de tasks migrés > 0

### Étape 2b : Configurer les provider profiles (#2543 Phase 2)

> **Gap comblé :** `migrate-globalstorage.ps1` copie `mcp_settings.json` + `custom_modes.yaml` + `tasks/`, mais **PAS les provider profiles** (ils vivent en SecretStorage DPAPI, pas en globalStorage). Sans cette étape, Zoo démarre sans provider configuré → pas d'auth LLM. Zoo conserve le mécanisme `autoImportSettings` de Roo (setting `zoo-code.autoImportSettingsPath`, default `""`) : il lit un fichier `providerProfiles` à `activate()` et le `store()` en SecretStorage. C'est la voie native, sans build VSIX ni micro-extension.

```powershell
# 1. Générer le fichier providerProfiles (clés résolues depuis .env)
node roo-config\scripts\sync-api-configs.js --resolve-secrets
# → écrit roo-config\generated\provider-profiles-import.json

# 2. Configurer le setting Zoo (settings.json user) pour pointer vers ce fichier
#    Toutes les machines de la flotte ont le repo à D:\Dev\roo-extensions
$settings = "$env:APPDATA\Code\User\settings.json"
$cfg = Get-Content $settings -Raw | ConvertFrom-Json
if (-not $cfg.PSObject.Properties.Name -contains 'zoo-code.autoImportSettingsPath') {
    $cfg | Add-Member -NotePropertyName 'zoo-code.autoImportSettingsPath' -NotePropertyValue 'D:\Dev\roo-extensions\roo-config\generated\provider-profiles-import.json'
}
[System.IO.File]::WriteAllText($settings, ($cfg | ConvertTo-Json -Depth 50), [System.Text.UTF8Encoding]::new($false))

# 3. Le restart VS Code (Étape 5 limitation #5) déclenche l'auto-import :
#    activate() → lit le setting → resolvePath → fileExists → importSettings → SecretStorage
```

**Vérifier post-restart :** Zoo UI > API Configs affiche les profils importés (default + glm + etc.) avec les clés peuplées.

> **Format du fichier** (sortie de `sync-api-configs.js`, vérifié = schema exact de l'import Zoo) :
> `{ "providerProfiles": { "currentApiConfigName": "default", "apiConfigs": {...}, "modeApiConfigs": {...} }, "_metadata": {...} }`

### Étape 3 : Vérification post-migration

```powershell
# Vérifier fichiers copiés
$zooGS = "$env:APPDATA\Code\User\globalStorage\zoocodeorganization.zoo-code"
Get-ChildItem "$zooGS\settings" -File | ForEach-Object { $_.Name }
# Attendu: mcp_settings.json, custom_modes.yaml (schedules.json optionnel)

# Vérifier MCP settings valides
$mcp = Get-Content "$zooGS\settings\mcp_settings.json" -Raw | ConvertFrom-Json
$mcp.mcpServers.PSObject.Properties.Name
# Attendu: roo-state-manager, win-cli, etc.

# Vérifier custom_modes
(Get-Content "$zooGS\settings\custom_modes.yaml" -Raw).Length
# Attendu: > 1000 chars (modes générés)
```

### Étape 4 : Validation fonctionnelle

```powershell
# Lancer une session Claude Code et vérifier :
# 1. MCP roo-state-manager disponible (15 outils)
# 2. conversation_browser fonctionne
# 3. roosync_dashboard read + append OK
# 4. DashboardListener Running
(Get-ScheduledTask Claude-DashboardListener).State
# Attendu: Running
```

### Étape 5 : Désinstaller Roo Code

```powershell
# UNIQUEMENT après validation fonctionnelle
code --uninstall-extension rooveterinaryinc.roo-cline

# Vérifier
code --list-extensions | Select-String "rooveterinaryinc"
# Attendu: (vide)
```

### Étape 6 : Rapport

Poster sur le dashboard workspace :
```
roosync_dashboard(action: "append", type: "workspace", tags: ["DONE", "claude-interactive"],
  content: "## [DONE] ZOO-MIGRATION {machine} ✅\n\n...checklist...")
```

Et commenter sur #2381 avec les résultats.

---

## Rollback

Si la migration échoue ou provoque des régressions :

```powershell
# Option A : Restaurer Roo Code (si VSIX backup disponible)
code --install-extension rooveterinaryinc.roo-cline-3.54.0.vsix

# Option B : Supprimer le Zoo globalStorage copié (la source Roo est préservée)
$zooGS = "$env:APPDATA\Code\User\globalStorage\zoocodeorganization.zoo-code"
Remove-Item "$zooGS\settings" -Recurse -Force
Remove-Item "$zooGS\tasks" -Recurse -Force
# Les fichiers originaux Roo restent intacts
```

**Note :** Le script `migrate-globalstorage.ps1` ne déplace JAMAIS les fichiers source. La copie Roo reste intacte en permanence.

---

## Limitations connues

1. **`schedules.json` optionnel** — Non migré si absent. L'autonomie repose sur `schtasks`, pas le scheduler interne.
2. **`mcp_settings.json` paths absolus** — Les chemins Windows (D:\, C:\) sont copiés tels quels. Valider que les chemins existent sur la machine cible.
3. **`custom_modes.yaml` mode groups** — Les groupes (`command`, `terminal`) ne sont pas natifs (#1482). Les modes générés utilisent `read,edit,browser,mcp`.
4. **`alwaysAllow` invalidation** — Un changement de schema Roo peut invalider les alwaysAllow (#473). Vérifier après migration.
5. **VS Code restart requis** — Zoo Code ne relit pas les configs à chaud. Fermer et rouvrir VS Code après migration.
6. **Provider profiles = Étape 2b séparée** (#2543) — `migrate-globalstorage.ps1` ne couvre PAS les providers (SecretStorage ≠ globalStorage). L'auto-import `zoo-code.autoImportSettingsPath` ne tourne **qu'au restart** (pas de watch) : toute mise à jour de `model-configs.json` → `sync-api-configs.js --resolve-secrets` + restart VS Code pour re-import.

---

## Checklist machine (template)

```markdown
## ZOO-MIGRATION {MACHINE} — {DATE}

| Check | Status | Detail |
|-------|--------|--------|
| Zoo Code installé | ⬜ | `zoocodeorganization.zoo-code` |
| Zoo Scheduler installé | ⬜ | `jsboige.zoo-scheduler` |
| migrate-globalstorage.ps1 dry-run | ⬜ | 0 erreur |
| Migration effectuée | ⬜ | mcp_settings + custom_modes + tasks |
| Provider profiles configurés (Étape 2b) | ⬜ | `sync-api-configs.js --resolve-secrets` + setting `autoImportSettingsPath` + profils visibles post-restart (#2543) |
| mcp_settings.json valide | ⬜ | `ConvertFrom-Json` OK |
| custom_modes.yaml présent | ⬜ | > 1000 chars |
| MCP roo-state-manager (15 outils) | ⬜ | Dashboard + CB + search |
| DashboardListener Running | ⬜ | PT0S, IgnoreNew, 3 triggers |
| Claude-Worker Ready | ⬜ | `start-claude-worker.ps1` |
| Roo Code désinstallé | ⬜ | 0 résultat `rooveterinaryinc` |
| Dashboard [DONE] posté | ⬜ | |
| Comment #2381 posté | ⬜ | |
```

---

## Références

- **Script :** `scripts/zoo-scheduler/migrate-globalstorage.ps1` (191 lignes, PR #2390 merged)
- **Script rollback :** `scripts/zoo-scheduler/rollback-to-roo-scheduler.ps1`
- **Module paths :** `scripts/common/extension-paths.ps1` (dot-sourcé)
- **Issue validation pilote :** #2381 (po-2025 PASS)
- **Issue migration configs :** #2379 (approved, PR #2390 merged)
- **Issue epic migration :** #2373
- **Issue Zoo scheduler compat :** #2134 (superseded — autonomie via schtasks)
- **Finding Zoo scheduler non-critique :** Validé po-2025, rapporté sur #2381
