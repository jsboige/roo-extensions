# Procédures de Validation - Diagnostic d'Encodage OS Windows

**Date**: 2025-10-29  
**Auteur**: Roo Debug Complex Mode  
**Version**: 1.0  

## 🎯 Objectif

Ce document décrit les procédures de validation complètes pour le diagnostic et la correction de l'encodage au niveau système Windows 11 Pro français.

## 📋 Prérequis

### Environnement Requis
- **Windows 11 Pro** français (fr-FR)
- **PowerShell 7+** installé
- **Privilèges administratifs** pour certaines corrections
- **Python 3.x** et **Node.js** pour les tests de validation

### Fichiers Requis
```
scripts/
├── diagnostic-encoding-os-windows.ps1     # Diagnostic complet
├── correction-encoding-systeme-windows.ps1  # Correction système
├── test-diagnostic-encoding.ps1          # Test de validation
└── validation-encoding.ps1                # Validation complète

results/
├── diagnostic-encoding-os-windows.json    # Rapport diagnostic
├── correction-encoding-systeme-windows.json # Rapport correction
├── registry-backups/                     # Sauvegardes registre
└── diagnostic-tests/                     # Scripts de test
```

## 🔍 Procédures de Validation

### Phase 1: Diagnostic Initial

#### 1.1 Exécution du Diagnostic Complet
```powershell
# Exécuter le diagnostic système complet
.\scripts\diagnostic-encoding-os-windows.ps1

# Points critiques à vérifier:
# - SuccessRate >= 90%
# - Aucun échec critique (Option UTF-8, Registre, Variables)
# - Tests de reproduction réussis
```

#### 1.2 Analyse des Résultats
```powershell
# Lire le rapport de diagnostic
$report = Get-Content "results\diagnostic-encoding-os-windows.json" | ConvertFrom-Json

# Vérifier les points critiques
$failedTests = $report.TestResults | Where-Object { -not $_.Success }
$criticalFailures = $failedTests | Where-Object { 
    $_.TestName -match "Option.*UTF-8|Registre.*CodePage|Variables.*encodage" 
}

if ($criticalFailures.Count -gt 0) {
    Write-Host "⚠️ ÉCHECS CRITIQUES DÉTECTÉS" -ForegroundColor Red
    $criticalFailures | ForEach-Object {
        Write-Host "  • $($_.TestName): $($_.Error)" -ForegroundColor Red
    }
}
```

### Phase 2: Validation des Corrections

#### 2.1 Exécution des Corrections Système
```powershell
# Exécuter le script de correction (nécessite des privilèges admin)
.\scripts\correction-encoding-systeme-windows.ps1

# Vérifier que toutes les corrections sont appliquées:
# - SuccessRate >= 95%
# - Variables système définies
# - Registre modifié correctement
# - Profiles PowerShell créés
```

#### 2.2 Validation Post-Correction
```powershell
# Créer un script de validation post-correction
$validationScript = @"
# Validation post-correction d'encodage
Write-Host "Validation post-correction..." -ForegroundColor Cyan

# Test 1: Variables d'environnement
`$env:PYTHONUTF8 = "1"
`$env:PYTHONIOENCODING = "utf-8"
`$env:NODE_OPTIONS = "--encoding=utf8"
`$env:LANG = "fr_FR.UTF-8"

# Test 2: PowerShell
`$testString = "Test UTF-8: é è à ù ç œ æ â ê î ô û 🚀 💻 ⚙️ 🪲"
Write-Host "PowerShell 7+: `$testString"
Write-Host "PowerShell 5.1: `$testString"

# Test 3: Python
python -c "import sys; print(f'Python: {sys.stdout.encoding}')"

# Test 4: Node.js
node -e "console.log('Node.js:', process.stdout.encoding || 'undefined')"

Write-Host "Validation terminée." -ForegroundColor Green
"@

$validationScript | Out-File -FilePath "scripts/validation-encoding.ps1" -Encoding UTF8

# Exécuter la validation
.\scripts\validation-encoding.ps1
```

### Phase 3: Tests Croisés

#### 3.1 Validation Multi-Processus
```powershell
# Test avec différents terminaux et méthodes d'exécution
$testString = "Validation: é è à ù ç œ æ â ê î ô û 🚀 💻 ⚙️ 🪲"

# Test via VSCode (PowerShell 7+)
pwsh -Command "Write-Host 'VSCode PS7+: `$testString'"

# Test via Terminal direct (PowerShell 7+)
# Ouvrir Windows Terminal et exécuter la même commande

# Test via conhost.exe (PowerShell 5.1)
powershell.exe -Command "Write-Host 'Conhost PS5.1: `$testString'"

# Test Python dans différents contextes
python -c "print('Python direct: `$testString')"
pwsh -Command "python -c `"print('Python via PS7+: `$testString')`""

# Test Node.js dans différents contextes
node -e "console.log('Node.js direct: `$testString')"
pwsh -Command "node -e `"console.log('Node.js via PS7+: `$testString')`""
```

#### 3.2 Validation de Fichiers
```powershell
# Créer des fichiers de test avec différents encodages
$testContent = "Test fichier: é è à ù ç œ æ â ê î ô û 🚀 💻 ⚙️ 🪲"

# Fichier UTF-8 explicite
$testContent | Out-File -FilePath "results\test-utf8-explicite.txt" -Encoding UTF8

# Fichier avec encodage par défaut
$testContent | Out-File -FilePath "results\test-utf8-defaut.txt"

# Lecture et comparaison
$explicitContent = Get-Content "results\test-utf8-explicite.txt" -Encoding UTF8
$defaultContent = Get-Content "results\test-utf8-defaut.txt"

if ($explicitContent -eq $defaultContent) {
    Write-Host "✅ Fichiers: Encodage cohérent" -ForegroundColor Green
} else {
    Write-Host "❌ Fichiers: Encodage incohérent" -ForegroundColor Red
}
```

## 📊 Critères de Validation

### Succès Complet
Tous les critères suivants doivent être remplis pour considérer le diagnostic comme réussi :

#### Configuration Système
- ✅ Option "Beta: Use Unicode UTF-8" activée
- ✅ Pages de code système configurées à 65001
- ✅ Paramètres régionaux cohérents (fr-FR.UTF-8)

#### Registre Windows
- ✅ Clés ACP/OEMCP forcées à 65001
- ✅ Console configurée pour UTF-8
- ✅ Sauvegardes créées avec succès

#### Environnement
- ✅ Variables système définies (Machine)
- ✅ Variables utilisateur définies (User)
- ✅ PYTHONUTF8=1, PYTHONIOENCODING=utf-8
- ✅ NODE_OPTIONS="--encoding=utf8", LANG="fr_FR.UTF-8"

#### Infrastructure
- ✅ Windows Terminal configuré comme défaut
- ✅ Profiles PowerShell 7+ et 5.1 créés
- ✅ Support ConPTY disponible

#### Tests de Reproduction
- ✅ Tous les langages affichent correctement les caractères UTF-8
- ✅ PowerShell 7+ et 5.1 cohérents
- ✅ Python détecte UTF-8
- ✅ Node.js utilise utf-8

### Échecs Critiques
Les situations suivantes nécessitent une intervention manuelle :

#### Échec de Configuration
- ❌ Option UTF-8 beta non activée après correction
- ❌ Pages de code toujours à ANSI/OEM
- ❌ Paramètres régionaux incohérents

#### Échec de Registre
- ❌ Impossible de modifier les clés (privilèges insuffisants)
- ❌ Valeurs incorrectes après modification
- ❌ Sauvegarde échouée

#### Échec d'Environnement
- ❌ Variables non persistantes après redémarrage
- ❌ PYTHONUTF8 ignoré par Python
- ❌ NODE_OPTIONS sans effet sur Node.js

#### Échec de Tests
- ❌ Caractères altérés dans l'affichage
- ❌ Incohérence entre PowerShell 5.1 et 7+
- ❌ Python/Node.js ne détectent pas UTF-8

## 🔄 Procédures de Dépannage

### Problèmes Courants et Solutions

#### 1. Option UTF-8 Beta Non Effective
**Symptôme**: L'option est activée mais les applications utilisent encore ANSI/OEM

**Diagnostic**:
```powershell
# Vérifier l'état réel
Get-WinSystemLocale
&{chcp}
```

**Solution**:
1. Redémarrer Windows complètement
2. Vérifier les paramètres régionaux après redémarrage
3. Exécuter à nouveau le diagnostic

#### 2. Variables d'Environnement Ignorées
**Symptôme**: PYTHONUTF8=1 défini mais Python utilise encore l'encodage par défaut

**Diagnostic**:
```powershell
# Vérifier les variables actuelles
Get-ChildItem Env: | Where-Object { $_.Name -match "PYTHON|NODE|LANG" }
```

**Solution**:
1. Vérifier l'ordre de priorité des variables
2. Redémarrer toutes les applications
3. Créer un script de forçage des variables

#### 3. Profiles PowerShell Non Chargés
**Symptôme**: Les profiles sont créés mais pas chargés automatiquement

**Diagnostic**:
```powershell
# Vérifier les profiles
Test-Path $PROFILE
Test-Path "$HOME\Documents\WindowsPowerShell\profile.ps1"
Get-Content $PROFILE -ErrorAction SilentlyContinue
```

**Solution**:
1. Vérifier les politiques d'exécution PowerShell
2. Recharger manuellement les profiles: `. $PROFILE`
3. Vérifier les permissions sur les fichiers de profile

## 📈 Validation Continue

### Surveillance Régulière
```powershell
# Script de surveillance à exécuter périodiquement
$monitoringScript = @"
# Surveillance de l'encodage système
while (`$true) {
    Start-Sleep -Seconds 300  # 5 minutes
    
    # Test rapide d'encodage
    `$testResult = python -c "import sys; print('OK' if sys.stdout.encoding == 'utf-8' else 'FAIL')" 2>&1
    
    if (`$testResult -eq "OK") {
        Write-Host "[$(Get-Date)] ✅ Encodage OK" -ForegroundColor Green
    } else {
        Write-Host "[$(Get-Date)] ❌ Encodage ÉCHEC" -ForegroundColor Red
        # Envoyer une notification
        # Add-Type -AssemblyName System.Windows.Forms
        # [System.Windows.Forms.MessageBox]::Show("Problème d'encodage détecté", "Alerte Encodage", "OK", "Warning")
    }
}
"@

$monitoringScript | Out-File -FilePath "scripts\surveillance-encoding.ps1" -Encoding UTF8

# Exécuter en arrière-plan
Start-Job -ScriptBlock { & .\scripts\surveillance-encoding.ps1 } -Name "EncodingMonitor"
```

### Tests de Régression
Après chaque correction système, exécuter les tests de régression :

```powershell
# Test de régression complet
.\scripts\diagnostic-encoding-os-windows.ps1

# Comparer avec le résultat précédent
$previousReport = "results\diagnostic-encoding-os-windows-previous.json"
if (Test-Path $previousReport) {
    $previous = Get-Content $previousReport | ConvertFrom-Json
    $current = Get-Content "results\diagnostic-encoding-os-windows.json" | ConvertFrom-Json
    
    # Comparer les taux de succès
    if ($current.Summary.SuccessRate -lt $previous.Summary.SuccessRate) {
        Write-Host "⚠️ RÉGRESSION DÉTECTÉE" -ForegroundColor Red
        Write-Host "Taux précédent: $($previous.Summary.SuccessRate)%" -ForegroundColor Yellow
        Write-Host "Taux actuel: $($current.Summary.SuccessRate)%" -ForegroundColor Red
    }
}
```

## 🎯 Conclusion

Ces procédures de validation assurent une couverture complète des problèmes d'encodage Windows :

1. **Diagnostic systématique** avec identification des causes profondes
2. **Correction ciblée** au niveau système, registre et environnement
3. **Validation rigoureuse** avec tests croisés et de régression
4. **Surveillance continue** pour détecter les régressions futures

L'application systématique de ces procédures devrait résoudre définitivement les problèmes d'encodage qui affectent Python, Node.js et PowerShell sur Windows 11 Pro français.

---

**Documents associés**:
- `scripts/diagnostic-encoding-os-windows.ps1` - Diagnostic complet
- `scripts/correction-encoding-systeme-windows.ps1` - Correction système
- `docs/encoding/rapport-diagnostic-encoding-os-windows-20251029.md` - Analyse complète
- `docs/encoding/procedures-validation-diagnostic-encoding-20251029.md` - Procédures de validation (ce document)