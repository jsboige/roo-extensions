# Guide Unifie de Depannage MCP

**Date:** 2026-02-09
**Version:** 2.3.0 (sweep #2639 WS3 29/10/2026, passe 2 : `quickfiles-server` retiré des scripts — serveur supprimé du code, 2026-09, #3423, review #4420 ; **entrée `roo-state-manager` corrigée** — l'entrée servie est le millésime publié `build-<sha16>/` désigné par le marqueur `build-current` (`build-out/` = scratch tsc, `build/` = legacy gelé, jamais réécrit) ; racines de checkout **paramétrées** ; `jinavigator-server` → `dist/` conservé)
**Statut:** ACTIF

---

## Diagnostic Rapide

### Arbre de Decision

```
MCP ne fonctionne pas ?
|
+-- Aucun MCP visible dans Roo ?
|   +-- Verifier BOM dans mcp_settings.json -> Section "Urgence BOM"
|   +-- Verifier que les fichiers build existent -> Section "Build Manquant"
|
+-- MCP detecte mais aucun outil ?
|   +-- Verifier les placeholders -> Section "Placeholders"
|   +-- Verifier les dependances -> Section "Dependances"
|
+-- Erreur fichier introuvable ?
|   +-- Verifier les chemins -> Section "Chemins"
|
+-- Erreur connexion / timeout ?
|   +-- Verifier que le serveur demarre -> Section "Serveur ne demarre pas"
|
+-- Claude Code: MCP roo-state-manager absent ?
|   +-- Verifier ~/.claude.json -> Section "Claude Code MCP"
|   +-- Tester le wrapper -> Section "Claude Code MCP"
```

---

## Procedures d'Urgence

### Urgence BOM - Perte Complete des MCPs Roo

**Symptomes:**
- Aucun MCP dans Roo
- Message "No MCP servers currently connected"

**Cause:** Caractere BOM UTF-8 (`﻿`) au debut du fichier `mcp_settings.json`.

**Reparation:**

```powershell
# Diagnostic
$filePath = "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json"
$bytes = [System.IO.File]::ReadAllBytes($filePath)
if ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    Write-Host "BOM DETECTE - Reparation necessaire" -ForegroundColor Red
} else {
    Write-Host "Pas de BOM - probleme ailleurs" -ForegroundColor Green
}

# Reparation : supprimer le BOM
$content = Get-Content $filePath -Raw
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($filePath, $content, $utf8NoBom)
Write-Host "BOM supprime" -ForegroundColor Green
```

**Validation post-reparation:**

```powershell
# Le fichier doit commencer par { et non par un caractere invisible
Get-Content $filePath -TotalCount 1

# Valider que le JSON est parsable
Get-Content $filePath -Raw | ConvertFrom-Json | Out-Null
Write-Host "JSON valide" -ForegroundColor Green
```

**Apres reparation:** Redemarrer completement VS Code.

**Prevention:** Ne jamais editer mcp_settings.json avec un editeur qui ajoute des BOM.

### Urgence - Echec Complet des MCPs

1. **Diagnostic:** Executer le script de validation ci-dessous
2. **Compilation:** `npm run build` sur tous les MCPs
3. **Validation:** Verifier l'absence de placeholders
4. **Redemarrage:** Fermer et rouvrir VS Code

---

## Problemes Courants

### 1. Placeholders au lieu de fichiers compiles

**Symptomes:**
- MCPs detectes mais aucun outil disponible
- Fichiers `index.js` de petite taille (< 1KB)
- Contenu: `"This file is a placeholder..."`

**Solution:**

```powershell
# Verifier et recompiler chaque MCP
# RACINE DU CHECKOUT : PARAMETREE (ce guide est lu sur plusieurs sieges).
#   Definir une fois par siege : $env:ROO_EXTENSIONS_ROOT = "C:/dev/roo-extensions"
#   (defaut : le repertoire courant)
$RepoRoot = if ($env:ROO_EXTENSIONS_ROOT) { $env:ROO_EXTENSIONS_ROOT } elseif ($env:ROO_EXTENSIONS_PATH) { $env:ROO_EXTENSIONS_PATH } else { (Get-Location).Path }
$serversDir = Join-Path $RepoRoot "mcps/internal/servers"

# ENTREE REELLE de chaque serveur (verifie au code : mcp-wrapper.cjs v5 / resolve-build-dir.mjs) :
#   roo-state-manager  : millesime publie build-<sha16>/ designe par le marqueur `build-current`
#                        (`build-out/` = scratch tsc, JAMAIS l'entree servie ; `build/` = legacy gele)
#   jinavigator-server : tsconfig outDir ./dist
function Get-McpEntry {
    param([string]$ServerDir)
    $marker = Join-Path $ServerDir "build-current"
    if (Test-Path $marker) {
        $vintage = (Get-Content -Raw -LiteralPath $marker).Trim()
        if ($vintage -match '^build-[0-9a-f]{16}$' -and (Test-Path (Join-Path $ServerDir "$vintage/index.js"))) {
            return Join-Path $ServerDir "$vintage/index.js"
        }
    }
    $dist = Join-Path $ServerDir "dist/index.js"
    if (Test-Path $dist) { return $dist }
    return $null
}

foreach ($mcp in @("roo-state-manager", "jinavigator-server")) {
    $serverDir = Join-Path $serversDir $mcp
    $target = Get-McpEntry -ServerDir $serverDir

    if (-not $target) {
        Write-Host "$mcp : MANQUANT - aucune version publiee (marqueur build-current absent) - compilation requise" -ForegroundColor Red
        Set-Location $serverDir
        npm install
        npm run build
    } elseif ((Get-Content $target -First 3) -match "placeholder") {
        Write-Host "$mcp : PLACEHOLDER - recompilation requise" -ForegroundColor Red
        Set-Location $serverDir
        npm run build
    } else {
        Write-Host "$mcp : OK ($target)" -ForegroundColor Green
    }
}
```

### 2. Chemins incorrects

**Symptomes:**
- Erreurs "fichier introuvable", "ENOENT"
- MCPs ne demarrent pas

**Causes:** Anciens chemins (`D:/Dev/`, `C:/dev/`) dans la configuration.

**Solution:** Verifier et corriger les chemins dans la configuration MCP (mcp_settings.json pour Roo, ~/.claude.json pour Claude Code).

```powershell
# Verifier les chemins dans mcp_settings.json
$configPath = "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json"
$config = Get-Content $configPath -Raw

# Detecter les anciens chemins
@("D:/Dev/roo-extensions", "D:\Dev\roo-extensions", "C:/dev/roo-extensions") | ForEach-Object {
    if ($config -match [regex]::Escape($_)) {
        Write-Host "Ancien chemin detecte: $_" -ForegroundColor Yellow
    }
}
```

### 3. Dependances manquantes

**Symptomes:**
- Erreurs "module not found" ou "command not found"
- Echecs de compilation TypeScript

**Solution:**

```powershell
# Reinstaller les dependances pour chaque MCP
# (racine parametree : cf. bloc 1 — $env:ROO_EXTENSIONS_ROOT)
$serversDir = Join-Path $RepoRoot "mcps/internal/servers"

foreach ($mcp in @("jinavigator-server", "roo-state-manager")) {
    Write-Host "Installation dependances: $mcp" -ForegroundColor Yellow
    Set-Location (Join-Path $serversDir $mcp)
    npm install
    npm run build
}
```

### 4. Serveur MCP ne demarre pas

**Symptomes:**
- Timeout de connexion
- Port deja utilise
- Erreur au demarrage

**Diagnostic:**

```powershell
# Verifier les ports utilises
netstat -an | Select-String ":300[0-9]"

# Verifier les processus Node
Get-Process node -ErrorAction SilentlyContinue | Format-Table Id, ProcessName, StartTime

# Tester le demarrage manuel (entree REELLE = millesime publie par le marqueur)
Set-Location (Join-Path $RepoRoot "mcps/internal/servers/roo-state-manager")
$vintage = (Get-Content -Raw "build-current").Trim()
node "$vintage/index.js"
```

### 5. Stubs detectes (fonctions vides)

**Symptomes:**
- Reponses "Not implemented"
- Tests anti-regression echoues
- Fonctions vides apres merge

**Diagnostic:**

```bash
# Rechercher les stubs
grep -r "Not implemented\|TODO.*stub\|throw.*not implemented" src/ --include="*.ts"
```

### 6. SearXNG - Erreur MCP -32000

**Symptomes:**
- Erreur "MCP error -32000: Connection closed"
- Le serveur se lance mais n'expose aucun outil

**Cause:** Incompatibilite `import.meta.url` vs `process.argv[1]` sur Windows.

**Solution:** Modifier le fichier index.js du package searxng pour normaliser les chemins Windows.

---

## Claude Code - MCP roo-state-manager

### Configuration

Le MCP roo-state-manager pour Claude Code utilise un **wrapper** qui filtre les outils (52+ -> 18 outils RooSync).

**Fichier config:** `~/.claude.json`

```json
{
  "mcpServers": {
    "roo-state-manager": {
      "command": "node",
      "args": ["<RACINE_CHECKOUT>/mcps/internal/servers/roo-state-manager/mcp-wrapper.cjs"]
    }
  }
}
```

`<RACINE_CHECKOUT>` = la racine du checkout sur CE siege (`$env:ROO_EXTENSIONS_ROOT`, ex. `C:/dev/roo-extensions`) — le chemin n'est pas fige dans ce guide.

**Wrapper:** mcp-wrapper.cjs (`../../mcps/internal/servers/roo-state-manager/mcp-wrapper.cjs`)

### Depannage Claude Code MCP

**MCP absent au demarrage:**
1. Verifier `~/.claude.json` contient la section `mcpServers`
2. Verifier que le chemin vers `mcp-wrapper.cjs` est correct
3. Tester le wrapper directement:
   ```powershell
   Set-Location (Join-Path $RepoRoot "mcps/internal/servers/roo-state-manager")
   node mcp-wrapper.cjs
   # Attendu: "Roo State Manager Server started - v1.0.14"
   ```
4. Verifier que `.env` existe dans le repertoire roo-state-manager
5. Redemarrer VS Code completement

**Trop d'outils / crash au demarrage:**
- S'assurer que le wrapper est utilise (`mcp-wrapper.cjs`) : il resout le millesime publie via `build-current` ; lancer un `index.js` en dur (scratch `build-out/` ou legacy `build/` gele) contourne cette resolution
- Le wrapper filtre de 52+ outils a 18 outils RooSync

**Debug logs:**
```powershell
$env:ROO_DEBUG_LOGS = "1"
node mcp-wrapper.cjs
# Affiche: "Filtered tools: XX -> 18"
```

### 18 Outils RooSync (apres wrapper, 2026-02-07)

| Categorie | Outils | Nombre |
|-----------|--------|--------|
| Messagerie CONS-1 | roosync_send, roosync_read, roosync_manage | 3 |
| Lecture seule | get_status, list_diffs, compare_config, refresh_dashboard | 4 |
| Consolides | config, inventory, baseline, machines, init | 5 |
| Decisions CONS-5 | roosync_decision, roosync_decision_info | 2 |
| Monitoring | heartbeat_status | 1 |
| Diagnostic | analyze_roosync_problems, diagnose_env | 2 |
| Summary | roosync_summarize | 1 |

---

## Script de Validation Complet

```powershell
# validate-mcps.ps1 - Validation rapide de tous les MCPs
function Test-AllMcps {
    param(
        # Racine du checkout : PARAMETREE (le guide est lu sur plusieurs sieges).
        [string]$RepoRoot = $(if ($env:ROO_EXTENSIONS_ROOT) { $env:ROO_EXTENSIONS_ROOT } elseif ($env:ROO_EXTENSIONS_PATH) { $env:ROO_EXTENSIONS_PATH } else { (Get-Location).Path })
    )
    $serversDir = Join-Path $RepoRoot "mcps/internal/servers"
    $issues = @()

    Write-Host "=== VALIDATION MCPs ===" -ForegroundColor Cyan

    # 1. Verifier les builds
    Write-Host "`n1. Verification des builds..." -ForegroundColor Yellow
    # Entree REELLE (verifie au code : mcp-wrapper.cjs v5 / resolve-build-dir.mjs) :
    #   roo-state-manager  -> millesime build-<sha16>/ designe par le marqueur `build-current`
    #   jinavigator-server -> dist/index.js (tsc outDir)
    # `build-out/` est un scratch tsc : le tester seul crierait "manquant" sur un siege sain.
    foreach ($mcp in @("roo-state-manager", "jinavigator-server")) {
        $serverDir = Join-Path $serversDir $mcp
        $path = $null
        $marker = Join-Path $serverDir "build-current"
        if (Test-Path $marker) {
            $vintage = (Get-Content -Raw -LiteralPath $marker).Trim()
            if ($vintage -match '^build-[0-9a-f]{16}$') { $path = Join-Path $serverDir "$vintage/index.js" }
        }
        if (-not $path -and (Test-Path (Join-Path $serverDir "dist/index.js"))) {
            $path = Join-Path $serverDir "dist/index.js"
        }

        if (-not $path -or -not (Test-Path $path)) {
            $issues += "$mcp : aucune version publiee (marqueur build-current absent)"
            Write-Host "  MANQUANT: $mcp (aucune version publiee)" -ForegroundColor Red
        } elseif ((Get-Item $path).Length -lt 1000) {
            $issues += "$mcp : fichier trop petit (placeholder?)"
            Write-Host "  SUSPECT: $mcp (< 1KB)" -ForegroundColor Yellow
        } else {
            Write-Host "  OK: $mcp ($path)" -ForegroundColor Green
        }
    }

    # 2. Verifier mcp_settings.json (Roo)
    Write-Host "`n2. Verification mcp_settings.json..." -ForegroundColor Yellow
    $rooConfig = "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json"
    if (Test-Path $rooConfig) {
        try {
            Get-Content $rooConfig -Raw | ConvertFrom-Json | Out-Null
            Write-Host "  OK: JSON valide" -ForegroundColor Green
        } catch {
            $issues += "mcp_settings.json: JSON invalide"
            Write-Host "  ERREUR: JSON invalide" -ForegroundColor Red
        }
    } else {
        Write-Host "  N/A: fichier absent" -ForegroundColor Gray
    }

    # 3. Verifier ~/.claude.json (Claude Code)
    Write-Host "`n3. Verification ~/.claude.json..." -ForegroundColor Yellow
    $claudeConfig = "$env:USERPROFILE\.claude.json"
    if (Test-Path $claudeConfig) {
        $config = Get-Content $claudeConfig -Raw | ConvertFrom-Json
        if ($config.mcpServers) {
            Write-Host "  OK: mcpServers configure" -ForegroundColor Green
        } else {
            $issues += "~/.claude.json: mcpServers absent"
            Write-Host "  MANQUANT: section mcpServers" -ForegroundColor Red
        }
    } else {
        $issues += "~/.claude.json: fichier absent"
        Write-Host "  MANQUANT: ~/.claude.json" -ForegroundColor Red
    }

    # 4. Verifier .env pour roo-state-manager
    Write-Host "`n4. Verification .env roo-state-manager..." -ForegroundColor Yellow
    $envPath = "$mcpDir/roo-state-manager/.env"
    if (Test-Path $envPath) {
        Write-Host "  OK: .env present" -ForegroundColor Green
    } else {
        $issues += "roo-state-manager: .env manquant"
        Write-Host "  MANQUANT: .env" -ForegroundColor Red
    }

    # Rapport
    Write-Host "`n=== RAPPORT ===" -ForegroundColor Cyan
    if ($issues.Count -eq 0) {
        Write-Host "Aucun probleme detecte" -ForegroundColor Green
    } else {
        Write-Host "$($issues.Count) probleme(s) detecte(s):" -ForegroundColor Red
        $issues | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    }
}

Test-AllMcps
```

---

## Prevention

### Bonnes Pratiques

1. **Toujours utiliser UTF-8 sans BOM** pour les fichiers JSON
2. **Valider apres chaque modification** avec le script de validation
3. **Utiliser le wrapper** pour Claude Code (jamais `build/index.js` directement)
4. **Variables d'environnement** pour tous les secrets (jamais en dur dans la config)
5. **Redemarrer VS Code** apres toute modification de configuration MCP

### Commandes de Reference

| Action | Commande |
|--------|----------|
| Build MCP | `cd mcps/internal/servers/<mcp> && npm run build` |
| Test wrapper | `cd mcps/internal/servers/roo-state-manager && node mcp-wrapper.cjs` |
| Tests unitaires | `cd mcps/internal/servers/roo-state-manager && npx vitest run` |
| Verifier config Claude | `Get-Content ~/.claude.json \| ConvertFrom-Json \| Select mcpServers` |

---

**Consolide depuis:**
- `guides/MCPS-COMMON-ISSUES-GUIDE.md` (2025-10-28)
- `guides/GUIDE-URGENCE-MCP.md` (2025-05-26)
- `mcp/mcp-troubleshooting.md` (2025-10-30)

**Mise a jour:** 2026-02-09 - Ajout section Claude Code MCP, mise a jour outils (18 post-CONS)
