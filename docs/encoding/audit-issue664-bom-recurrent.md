# Rapport d'Audit - Issue #664 : BOM UTF-8 Récurrent dans mcp_settings.json

**Date:** 2026-03-13
**Machine:** myia-po-2026
**Agent:** Claude Code (myia-po-2026)
**Issue:** #664 - "[BUG] BOM UTF-8 récurrent dans mcp_settings.json - Reprendre en main l'encodage OS/terminal"

---

## Résumé Exécutif

**⚠️ CULPRIT IDENTIFIÉ :** `scripts/mcp/sync-alwaysallow.ps1` ligne 134

Le script `sync-alwaysallow.ps1` utilise `Set-Content -Encoding UTF8` pour écrire `mcp_settings.json`, ce qui ajoute automatiquement un BOM UTF-8 sous PowerShell 5.1. C'est la cause racine de la réapparition périodique du BOM dans le fichier de configuration MCP de Roo.

**Impact :** Le BOM empêche le MCP roo-state-manager de démarrer, rendant Roo inopérant sur la machine affectée. Incident constaté sur myia-po-2023 (silence pendant plusieurs jours le 13/03/2026).

---

## Phase 1 : Audit des Scripts d'Encodage

### 1.1 Scripts Encoding Identifiés

**Scripts PowerShell (40+) dans `scripts/encoding/` :**

| Script | Purpose | Statut BOM |
|--------|---------|------------|
| `Initialize-EncodingManager.ps1` | Initialisation UTF-8 console | ✅ Safe |
| `check-bom-in-file.js` | Détection BOM UTF-8 | ✅ Safe (Node.js) |
| `fix-file-encoding.ps1` | Correction fichiers corrompus | ✅ Safe |
| `Generate-DeploymentReport.ps1` | Rapport déploiement Phase 1 | ✅ Safe |
| `Configure-PowerShellProfiles.ps1` | Configuration profils PS | ✅ Safe |
| `Configure-EncodingMonitoring.ps1` | Monitoring encodage | ✅ Safe |
| `Test-StandardizedEnvironment.ps1` | Validation environnement | ✅ Safe |
| `Test-TerminalConfiguration.ps1` | Validation terminal | ✅ Safe |
| `Test-PowerShellProfiles.ps1` | Validation profils | ✅ Safe |
| `Test-UTF8Activation.ps1` | Validation UTF-8 | ✅ Safe |
| `Test-UTF8RegistryValidation.ps1` | Validation registre | ✅ Safe |
| `Remove-UTF8BOM.ps1` | Suppression BOM | ✅ Safe |
| `Sync-AlwaysAllow.ps1` (roo-config/scripts/) | Sync alwaysAllow MCP | ✅ Safe (ligne 222) |
| `fix-roo-mcp-settings.ps1` (scripts/deployment/) | Fix settings Roo MCP | ✅ Safe (ligne 145) |

**Scripts JavaScript (2) :**
- `check-bom-in-file.js` : Détection BOM via Node.js ✅

### 1.2 État du Déploiement sur myia-po-2026

| Composant | Statut | Détails |
|-----------|--------|---------|
| Codepage | ✅ 65001 (UTF-8) | `[System.Text.Encoding]::Default.CodePage` |
| Console OutputEncoding | ✅ Unicode (UTF-8) | `[Console]::OutputEncoding` |
| Console InputEncoding | ✅ Unicode (UTF-8) | `[Console]::InputEncoding` |
| PowerShell Version | ✅ 5.1.26100 | Compatible UTF-8 |
| $OutputEncoding | ✅ Unicode (UTF-8) | Variable de sortie |
| mcp_settings.json | ✅ NO BOM | Premier bytes: 7b 0d 0a (JSON + CRLF) |
| RooEncodingMonitor | ❌ NOT DEPLOYED | Service non déployé |
| PowerShell Profile | ⚠️ NOT VERIFIED | Non vérifié dans cet audit |

### 1.3 Lieux d'Écriture de mcp_settings.json

**Cible :** `%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json`

| Script | Ligne | Méthode | Statut BOM |
|--------|------|---------|------------|
| **`scripts/mcp/sync-alwaysallow.ps1`** | **134** | **`Set-Content -Encoding UTF8`** | **❌ CULPRIT** |
| `scripts/deployment/fix-roo-mcp-settings.ps1` | 145 | `[System.IO.File]::WriteAllText(..., UTF8Encoding::new($false))` | ✅ Safe |
| `roo-config/scripts/Sync-AlwaysAllow.ps1` | 222 | `[System.IO.File]::WriteAllText(..., UTF8Encoding::new($false))` | ✅ Safe |

---

## Root Cause Analysis

### Le Coupable : `scripts/mcp/sync-alwaysallow.ps1` ligne 134

```powershell
# ❌ PROBLÈME - Ajoute BOM UTF-8
$settings | ConvertTo-Json -Depth 10 | Set-Content $RooSettingsPath -Encoding UTF8
```

**Pourquoi c'est un problème :**
- Sous PowerShell 5.1, `-Encoding UTF8` avec `Set-Content` ajoute automatiquement un BOM (EF BB BF)
- Le BOM UTF-8 brise le parser JSON du MCP roo-state-manager
- Le MCP ne peut pas démarrer, Roo devient inopérant

**Pattern CORRECT à utiliser :**
```powershell
# ✅ SOLUTION - Sans BOM
[System.IO.File]::WriteAllText($RooSettingsPath, $settingsJson, [System.Text.UTF8Encoding]::new($false))
```

---

## Patterns d'Encodage Sécurisés

### Méthode Safe recommandée

```powershell
# Encodage UTF-8 SANS BOM (PowerShell 5.1+)
[System.IO.File]::WriteAllText($filePath, $content, [System.Text.UTF8Encoding]::new($false))

# Équivalent avec Pipe (nécessite une variable intermédiaire)
$jsonContent = $settings | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($filePath, $jsonContent, [System.Text.UTF8Encoding]::new($false))
```

### Méthodes AVOID

```powershell
# ❌ AVOID - Ajoute BOM en PowerShell 5.1
Set-Content $filePath -Encoding UTF8
Out-File $filePath -Encoding UTF8
Add-Content $filePath -Encoding UTF8

# ⚠️ CONDITIONNEL - UTF8NoBOM existe seulement en PowerShell 7+
Set-Content $filePath -Encoding utf8NoBOM  # PS 7+ seulement
```

---

## Machines à Vérifier (Cross-Machine)

Les 5 autres machines n'ont pas répondu au message RooSync d'audit encodage :

| Machine | Statut Audit | Action Requise |
|---------|--------------|----------------|
| myia-ai-01 | ⏳ Pending | Audit prioritaire (coordinateur) |
| myia-po-2023 | ⏳ Pending | Audit prioritaire (machine incident) |
| myia-po-2024 | ⏳ Pending | À auditer |
| myia-po-2025 | ⏳ Pending | À auditer |
| myia-web1 | ⏳ Pending | À auditer |
| myia-po-2026 | ✅ Done | Audit complet |

---

## Recommandations Phase 2 (Protection)

### 2.1 Corriger `sync-alwaysallow.ps1` (CRITIQUE)

**Fichier :** `scripts/mcp/sync-alwaysallow.ps1`
**Ligne :** 134
**Changement :**
```powershell
# Avant (ligne 134)
$settings | ConvertTo-Json -Depth 10 | Set-Content $RooSettingsPath -Encoding UTF8

# Après
$jsonOutput = $settings | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($RooSettingsPath, $jsonOutput, [System.Text.UTF8Encoding]::new($false))
```

### 2.2 Ajouter strip-BOM dans ConfigService.ts (défense en profondeur)

**Fichier :** `mcps/internal/servers/roo-state-manager/src/services/ConfigService.ts`
**Action :** Ajouter une fonction de nettoyage BOM à la lecture JSON

```typescript
// Nettoyer le BOM UTF-8 si présent avant parsing JSON
private stripBOM(content: string): string {
    if (content.charCodeAt(0) === 0xFEFF) {
        return content.slice(1);
    }
    // Vérifier BOM UTF-8 réel (EF BB BF)
    if (content.startsWith('\uFEFF')) {
        return content.slice(1);
    }
    return content;
}
```

### 2.3 Check BOM dans scheduler pre-flight

Ajouter une vérification BOM avant le démarrage du scheduler Roo :
- Script de pré-vol qui vérifie les BOMs dans les configs critiques
- Échec rapide si BOM détecté avec instructions de correction

### 2.4 Étendre check-bom-in-file.js

Ajouter un mode "batch" pour vérifier plusieurs fichiers de configuration critiques :
- mcp_settings.json
- custom_modes.yaml
- schedules.json
- .env

---

## Plan d'Action Phase 3 (Deployment)

1. **Déployer la correction sync-alwaysallow.ps1** sur les 6 machines
2. **Déployer Configure-PowerShellProfiles.ps1** sur les 6 machines
3. **Activer le monitoring** Configure-EncodingMonitoring.ps1
4. **Valider** que le BOM ne réapparaît pas après 48h

---

## Signatures

**Audit réalisé par :** Claude Code (myia-po-2026)
**Date de fin :** 2026-03-13
**Prochaine action :** Phase 2 - Correction de sync-alwaysallow.ps1

---

**Documents de référence :**
- Issue #664 : https://github.com/jsboige/roo-extensions/issues/664
- Scripts encoding : `scripts/encoding/`
- CULPRIT : `scripts/mcp/sync-alwaysallow.ps1:134`
