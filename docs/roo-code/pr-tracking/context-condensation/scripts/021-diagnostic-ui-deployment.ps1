# Script de Diagnostic UI - Context Condensation
# Date: 2025-10-07
# Objectif: Diagnostiquer pourquoi les modifications UI ne sont pas visibles

param(
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$reportPath = Join-Path $PSScriptRoot "..\021-diagnostic-report-$timestamp.md"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "DIAGNOSTIC UI - DÉPLOIEMENT" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$report = @"
# Rapport de Diagnostic - UI Non Mise à Jour
**Date**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
**Problème**: Les modifications UI ne sont pas visibles après redémarrage VSCode

---

"@

# ============================================
# ÉTAPE 1: Vérification du Code Source
# ============================================
Write-Host "[1/5] Vérification du code source..." -ForegroundColor Yellow

$sourceFile = "C:\dev\roo-code\webview-ui\src\components\settings\CondensationProviderSettings.tsx"
$sourceInfo = Get-Item $sourceFile
$sourceContent = Get-Content $sourceFile -Raw

$hasAdvancedConfig = $sourceContent -match 'Advanced Config'
$hasNativeDefault = $sourceContent -match 'defaultProviderId.*=.*"native"'
$hasPresetConfigJson = $sourceContent -match 'setCustomConfigText\(presetConfigJson\)'

$report += @"
## 1. Code Source
**Fichier**: ``$sourceFile``
**Date modification**: $($sourceInfo.LastWriteTime)

### Vérifications:
- ✅ Contient "Advanced Config": **$hasAdvancedConfig**
- ✅ defaultProviderId = "native": **$hasNativeDefault**
- ✅ Utilise presetConfigJson: **$hasPresetConfigJson**

"@

if ($hasAdvancedConfig -and $hasNativeDefault -and $hasPresetConfigJson) {
    Write-Host "  ✅ Code source OK - Toutes les modifications présentes" -ForegroundColor Green
} else {
    Write-Host "  ❌ Code source INCOMPLET" -ForegroundColor Red
}

# ============================================
# ÉTAPE 2: Vérification du Build WebView-UI
# ============================================
Write-Host "`n[2/5] Vérification du build webview-ui..." -ForegroundColor Yellow

$buildFile = "C:\dev\roo-code\src\webview-ui\build\assets\index.js"
$buildExists = Test-Path $buildFile

if ($buildExists) {
    $buildInfo = Get-Item $buildFile
    $buildContent = Get-Content $buildFile -Raw
    
    $buildHasAdvancedConfig = $buildContent -match 'Advanced Config'
    
    $timeDiff = ($buildInfo.LastWriteTime - $sourceInfo.LastWriteTime).TotalMinutes
    
    $report += @"
## 2. Build WebView-UI
**Fichier**: ``$buildFile``
**Date build**: $($buildInfo.LastWriteTime)
**Taille**: $([math]::Round($buildInfo.Length / 1MB, 2)) MB

### Chronologie:
- Source modifié: $($sourceInfo.LastWriteTime)
- Build généré: $($buildInfo.LastWriteTime)
- **Écart**: $([math]::Round($timeDiff, 1)) minutes

### Contenu du Bundle:
- ❌ Contient "Advanced Config": **$buildHasAdvancedConfig**

"@

    if ($buildHasAdvancedConfig) {
        Write-Host "  ✅ Build contient les modifications" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Build NE CONTIENT PAS 'Advanced Config'" -ForegroundColor Red
        Write-Host "     Le build est plus récent mais ne contient pas les modifications!" -ForegroundColor Red
    }
} else {
    Write-Host "  ❌ Build NON TROUVÉ" -ForegroundColor Red
    $report += @"
## 2. Build WebView-UI
**Status**: ❌ **FICHIER NON TROUVÉ**
**Chemin attendu**: ``$buildFile``

"@
}

# ============================================
# ÉTAPE 3: Vérification de l'Extension
# ============================================
Write-Host "`n[3/5] Vérification de l'extension déployée..." -ForegroundColor Yellow

$extensionPath = Get-ChildItem "$env:USERPROFILE\.vscode\extensions" -Filter "rooveterinaryinc.roo-cline-*" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if ($extensionPath) {
    $extWebviewPath = Join-Path $extensionPath.FullName "dist\webview-ui"
    $extWebviewExists = Test-Path $extWebviewPath
    
    $report += @"
## 3. Extension Déployée
**Chemin**: ``$($extensionPath.FullName)``
**Date**: $($extensionPath.LastWriteTime)

### Structure:
- dist\webview-ui existe: **$extWebviewExists**

"@

    if ($extWebviewExists) {
        $extIndexPath = Join-Path $extWebviewPath "assets\index.js"
        if (Test-Path $extIndexPath) {
            $extIndexInfo = Get-Item $extIndexPath
            $extIndexContent = Get-Content $extIndexPath -Raw
            $extHasAdvancedConfig = $extIndexContent -match 'Advanced Config'
            
            $report += @"
### Fichier index.js déployé:
- **Chemin**: ``$extIndexPath``
- **Date**: $($extIndexInfo.LastWriteTime)
- **Taille**: $([math]::Round($extIndexInfo.Length / 1MB, 2)) MB
- **Contient "Advanced Config"**: **$extHasAdvancedConfig**

"@

            if ($extHasAdvancedConfig) {
                Write-Host "  ✅ Extension déployée contient les modifications" -ForegroundColor Green
            } else {
                Write-Host "  ❌ Extension déployée NE CONTIENT PAS 'Advanced Config'" -ForegroundColor Red
            }
        } else {
            Write-Host "  ❌ index.js non trouvé dans l'extension" -ForegroundColor Red
            $report += "### ❌ Fichier index.js NON TROUVÉ dans extension`n"
        }
    } else {
        Write-Host "  ❌ dist\webview-ui NON TROUVÉ dans l'extension" -ForegroundColor Red
    }
} else {
    Write-Host "  ❌ Extension Roo Cline NON TROUVÉE" -ForegroundColor Red
    $report += @"
## 3. Extension Déployée
**Status**: ❌ **EXTENSION NON TROUVÉE**

"@
}

# ============================================
# ÉTAPE 4: Comparaison des Hashes
# ============================================
Write-Host "`n[4/5] Comparaison des hashes..." -ForegroundColor Yellow

if ($buildExists -and $extensionPath -and $extWebviewExists) {
    $extIndexPath = Join-Path $extWebviewPath "assets\index.js"
    
    if ((Test-Path $buildFile) -and (Test-Path $extIndexPath)) {
        $sourceHash = (Get-FileHash $buildFile -Algorithm SHA256).Hash
        $deployHash = (Get-FileHash $extIndexPath -Algorithm SHA256).Hash
        
        $hashMatch = $sourceHash -eq $deployHash
        
        $report += @"
## 4. Comparaison des Hashes
**Build source**: ``$($sourceHash.Substring(0, 16))...``
**Extension déployée**: ``$($deployHash.Substring(0, 16))...``
**Fichiers identiques**: **$hashMatch**

"@

        if ($hashMatch) {
            Write-Host "  ✅ Les fichiers sont identiques (hash match)" -ForegroundColor Green
        } else {
            Write-Host "  ❌ Les fichiers sont DIFFÉRENTS" -ForegroundColor Red
            Write-Host "     Le build source n'est pas celui déployé!" -ForegroundColor Red
        }
    } else {
        $report += "## 4. Comparaison des Hashes`n❌ Impossible de comparer (fichiers manquants)`n`n"
        Write-Host "  ⚠️  Impossible de comparer les hashes" -ForegroundColor Yellow
    }
} else {
    $report += "## 4. Comparaison des Hashes`n⚠️ Vérification ignorée (éléments manquants)`n`n"
    Write-Host "  ⚠️  Vérification des hashes ignorée" -ForegroundColor Yellow
}

# ============================================
# ÉTAPE 5: Diagnostic Final
# ============================================
Write-Host "`n[5/5] Diagnostic final..." -ForegroundColor Yellow

$report += @"
## 5. Diagnostic Final

"@

# Analyse du problème
$issues = @()

if (-not $hasAdvancedConfig) {
    $issues += "❌ Code source ne contient pas 'Advanced Config'"
}

if ($buildExists -and -not $buildHasAdvancedConfig) {
    $issues += "❌ **PROBLÈME CRITIQUE**: Build existe mais ne contient pas les modifications"
    $issues += "   → Le build a été généré depuis une version incorrecte du code source"
    $issues += "   → Ou un problème de cache/bundle a corrompu le build"
}

if (-not $buildExists) {
    $issues += "❌ Build webview-ui n'existe pas"
}

if ($extensionPath -and $extWebviewExists -and -not $extHasAdvancedConfig) {
    $issues += "❌ Extension déployée ne contient pas les modifications"
}

if (-not $extWebviewExists) {
    $issues += "❌ webview-ui non déployé dans l'extension"
}

if ($buildExists -and $extWebviewExists -and -not $hashMatch) {
    $issues += "❌ Le build source et l'extension déployée sont différents"
}

if ($issues.Count -eq 0) {
    $report += "### ✅ Aucun problème détecté`n`n"
    $report += "Si l'UI n'est toujours pas à jour, vérifier:`n"
    $report += "- VSCode a bien été redémarré complètement`n"
    $report += "- La webview a été rechargée (F1 → Developer: Reload Webviews)`n"
    Write-Host "`n✅ Diagnostic: Aucun problème technique détecté" -ForegroundColor Green
} else {
    $report += "### Problèmes Identifiés:`n`n"
    foreach ($issue in $issues) {
        $report += "- $issue`n"
    }
    $report += "`n"
    Write-Host "`n❌ Diagnostic: $($issues.Count) problème(s) identifié(s)" -ForegroundColor Red
}

# ============================================
# Actions Recommandées
# ============================================
$report += @"
## Actions Recommandées

### 1. Nettoyer et Rebuilder
``````powershell
# Nettoyer le build existant
Remove-Item -Path "C:\dev\roo-code\src\webview-ui\build" -Recurse -Force -ErrorAction SilentlyContinue

# Rebuilder depuis webview-ui
cd C:\dev\roo-code\webview-ui
npm run build

# Vérifier que le nouveau build contient "Advanced Config"
Select-String -Path "..\src\webview-ui\build\assets\index.js" -Pattern "Advanced Config"
``````

### 2. Rebuilder l'Extension Complète
``````powershell
cd C:\dev\roo-code\src
pnpm run bundle
``````

### 3. Redéployer
``````powershell
cd C:\dev\roo-extensions\roo-code-customization
.\deploy-standalone.ps1
``````

### 4. Vérifier le Déploiement
``````powershell
# Vérifier que webview-ui est bien déployé
Test-Path "$env:USERPROFILE\.vscode\extensions\rooveterinaryinc.roo-cline-*\dist\webview-ui"

# Vérifier le contenu
Select-String -Path "$env:USERPROFILE\.vscode\extensions\rooveterinaryinc.roo-cline-*\dist\webview-ui\assets\index.js" -Pattern "Advanced Config"
``````

### 5. Redémarrer VSCode
- Fermer complètement VSCode (pas juste la fenêtre)
- Relancer VSCode
- Ouvrir les settings Roo

---

**Rapport sauvegardé dans**: ``$reportPath``
"@

# ============================================
# Sauvegarder le Rapport
# ============================================
$report | Out-File -FilePath $reportPath -Encoding UTF8
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "RAPPORT SAUVEGARDÉ" -ForegroundColor Green
Write-Host $reportPath -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Afficher le chemin relatif
$relativePath = $reportPath.Replace("C:\dev\roo-extensions\", "..\roo-extensions\")
Write-Host "Chemin relatif: $relativePath" -ForegroundColor Gray