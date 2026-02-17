# Plan de Consolidation scripts/ - #481

**Date:** 2026-02-16
**Machine:** myia-po-2026
**Objectif:** Réduire 65 fichiers racine + 28 sous-répertoires

---

## État Actuel

- **65 fichiers** à la racine (PS1/JS/MJS)
- **28 sous-répertoires**

---

## Phase 1: Archivage Scripts Obsolètes (Quick Wins)

### 1.1 FFmpeg (obsolète, myia-po-2026 n'a pas FFmpeg)
**À archiver dans `scripts/_archive/ffmpeg/` :**
- `diagnose-ffmpeg.ps1`
- `fix-ffmpeg-path.ps1`
- `install-ffmpeg-windows.ps1`
- `refresh-path-ffmpeg.ps1`
- `test-complete-ffmpeg.ps1`
- `test-ffmpeg-markitdown.ps1`
- **7 fichiers**

### 1.2 GitHub Projects MCP (déprécié #368)
**À archiver dans `scripts/_archive/github-projects-mcp/` :**
- `diagnose-github-projects-mcp.ps1`
- `test-github-projects-complete.ps1`
- `validation-github-projects-mcp-stdio-complete.ps1`
- **3 fichiers**

### 1.3 Consolidate Docs (terminé, scripts à usage unique)
**À archiver dans `scripts/_archive/consolidate-docs/` :**
- `consolidate_docs_cleanup.ps1`
- `consolidate_docs_dryrun.ps1`
- `consolidate_docs_final_cleanup.ps1`
- `consolidate_docs_real.ps1`
- **4 fichiers**

**Total Phase 1:** 14 fichiers archivés → **51 fichiers restants**

---

## Phase 2: Ventilation Scripts Racin

### 2.1 Encoding/UTF8 → `scripts/encoding/`
**À déplacer :**
- `diagnostic-encodage-complet.ps1`
- `diagnostic-encoding-consolide.ps1`
- `test-encodage-utf8.ps1`
- `test-diagnostic-encoding.ps1`
- `test-emoji-encoding-reproduction.ps1`
- `test-emoji-fix-validation.ps1`
- `fix-emoji-encoding-issues.ps1`
- `check-bom-in-file.js`
- `test-bom-fix-validation.js`
- `test-bom-fix-validation.ps1`
- **10 fichiers** → `scripts/encoding/` (existe déjà)

### 2.2 Git Workflow → `scripts/git-workflow/`
**À déplacer :**
- `git-commit-phase.ps1`
- `git-commit-submodule.ps1`
- `git-safe-operations.ps1`
- `git-safety-check.ps1`
- `return-to-main-phase2-submodule.ps1`
- `return-to-main-submodule-simple.ps1`
- `cleanup-rollbacks.ps1`
- **7 fichiers** → `scripts/git-workflow/` (existe déjà)

### 2.3 Hierarchy/Task Debug → `scripts/diagnostic/hierarchy/`
**À déplacer :**
- `analyze-task-matching.js`
- `analyze-task-matching.ps1`
- `debug-hierarchy-matching.js`
- `debug-hierarchy-matching.mjs`
- `diagnose-parent-file.ps1`
- `extract-child-parent-snippets.ps1`
- `extract-new-task-tags-safe.ps1`
- `extract-parent-tail.ps1`
- `generate-hierarchy-tree.ps1`
- **9 fichiers** → créer `scripts/diagnostic/hierarchy/`

### 2.4 Tests → `scripts/testing/`
**À déplacer :**
- `test-jupyter-mcp-e2e.ps1`
- `test-playwright-mcp.ps1`
- `test-roo-state-manager-build.ps1`
- `roo-tests.ps1`
- `run-unit-tests-tools.ps1`
- **5 fichiers** → `scripts/testing/` (existe déjà)

### 2.5 Setup/Config → `scripts/setup/`
**À déplacer :**
- `configure-vscode-pwsh.ps1`
- `setup-workspace.ps1`
- `setup-git-hooks.js`
- `pre-commit-hook.js`
- **4 fichiers** → `scripts/setup/` (existe déjà)

### 2.6 MCP → `scripts/mcp/`
**À déplacer :**
- `mcp-monitor.ps1`
- `validate-mcp-implementations.js`
- **2 fichiers** → `scripts/mcp/` (existe déjà)

### 2.7 RooSync → `scripts/roosync/`
**À déplacer :**
- `migrate-roosync-storage.ps1`
- `validate-roosync-identity-protection.ps1`
- **2 fichiers** → `scripts/roosync/` (existe déjà)

### 2.8 Analysis → `scripts/analysis/`
**À déplacer :**
- `analyze-commits.ps1`
- `analyze-complexity.js`
- `analyze-stashs.ps1`
- `backup-all-stashs.ps1`
- `extract-ui-snippets.ps1`
- **5 fichiers** → `scripts/analysis/` (existe déjà)

### 2.9 Ventilation → `scripts/messaging/`
**À déplacer :**
- `ventilation-rapports.ps1`
- `ventilation-rapports-complement.ps1`
- `send-urgent-broadcast.ps1`
- **3 fichiers** → `scripts/messaging/` (existe déjà)

**Total Phase 2:** 47 fichiers ventilés → **4 fichiers restants**

---

## Phase 3: Scripts Racine Restants

Après ventilation, restent à la racine :

1. `analyze-commits.ps1` → **scripts/analysis/**
2. `analyze-complexity.js` → **scripts/analysis/**
3. `analyze-stashs.ps1` → **scripts/analysis/**
4. `backup-all-stashs.ps1` → **scripts/analysis/**

**Résultat attendu : 0 fichiers à la racine**

---

## Sous-répertoires à Consolider

### À fusionner (similaires) :
- `demo-scripts` → contenu à archiver (demos obsolètes)
- `transients` → contenu à archiver (scripts temporaires)

### À vérifier utilité :
- `audit` - vs `diagnostic` ?
- `benchmarks` - encore utile ?
- `claude-md` - spécifique, garder

---

## Execution

### Commande PowerShell pour Phase 1 (archivage) :

```powershell
# Créer répertoire _archive
New-Item -Path "scripts/_archive" -ItemType Directory -Force | Out-Null

# Archiver FFmpeg
$ffmpegFiles = @(
    "diagnose-ffmpeg.ps1",
    "fix-ffmpeg-path.ps1",
    "install-ffmpeg-windows.ps1",
    "refresh-path-ffmpeg.ps1",
    "test-complete-ffmpeg.ps1",
    "test-ffmpeg-markitdown.ps1"
)
New-Item -Path "scripts/_archive/ffmpeg" -ItemType Directory -Force | Out-Null
foreach ($file in $ffmpegFiles) {
    Move-Item -Path "scripts/$file" -Destination "scripts/_archive/ffmpeg/$file" -Force
}

# ... etc pour autres catégories
```

---

## Critères de Validation

- [ ] Phase 1: 14 fichiers archivés
- [ ] Phase 2: 47 fichiers ventilés
- [ ] Phase 3: 0 fichiers à la racine
- [ ] Tous les scripts qui importent d'autres scripts mis à jour
- [ ] README.md scripts/ mis à jour
- [ ] Tests passent (`npx vitest run`)

---

**Prochaine action :** Exécuter Phase 1 (archivage)
