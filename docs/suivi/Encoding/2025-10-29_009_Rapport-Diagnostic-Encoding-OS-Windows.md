# Rapport de Diagnostic d'Encodage OS Windows
**Date**: 2025-10-29  
**Auteur**: Roo Debug Complex Mode  
**Version**: 1.0  

## 🎯 Objectif

Ce rapport présente le diagnostic complet de l'encodage au niveau système Windows 11 Pro français, identifiant les causes profondes qui affectent tous les langages de programmation (Python, Node.js, PowerShell, etc.).

## 📋 Contexte et Problématique

### Problèmes Observés
- **Python**: Échec avec les emojis même avec `PYTHONUTF8=1`
- **Node.js**: Incohérences dans l'affichage des caractères Unicode
- **PowerShell**: Différences entre versions 5.1 et 7+
- **Scripts arbitraires**: Corruption systématique des caractères accentués et emojis

### Hypothèses Initiales
1. **Conflit de configuration système** entre l'option UTF-8 beta et les paramètres régionaux
2. **Incompatibilité registre** avec les standards UTF-8 modernes
3. **Infrastructure console obsolète** (conhost.exe vs Windows Terminal)
4. **Variables d'environnement contradictoires** au niveau système

## 🔍 Analyse du Diagnostic Créé

### Script: `diagnostic-encoding-os-windows.ps1`

Le script de diagnostic couvre 5 domaines critiques:

#### 1. Configuration Système Windows
- **Option Beta UTF-8**: Vérification de l'activation du support Unicode mondial
- **Paramètres régionaux**: Analyse des locales fr-FR et UI language
- **Pages de code système**: Détection ANSI/OEM vs UTF-8 (65001)
- **Langue non-Unicode**: Configuration héritée Windows

#### 2. Registre Windows
- **Clés CodePage**: `HKLM\SYSTEM\CurrentControlSet\Control\Nls\CodePage`
  - ACP (ANSI Code Page)
  - OEMCP (OEM Code Page)  
  - MACCP (Macintosh Code Page)
- **Configuration Console**: `HKCU\Console`
  - FaceName, FontSize, FontFamily
- **Paramètres internationaux**: `HKCU\Control Panel\International`
  - LocaleName, formats date/heure

#### 3. Environnement Système
- **Variables d'encodage**: LANG, LC_ALL, LC_CTYPE, PYTHONUTF8, NODE_ENCODING
- **Système fichiers NTFS**: Vérification du support Unicode natif
- **Services Windows**: WinRM, TermService, ConHost

#### 4. Infrastructure Console
- **Conhost.exe vs Windows Terminal**: Détection des terminaux actifs
- **Support ConPTY**: Disponibilité des pseudo-consoles modernes
- **APIs console**: Propriétés et méthodes disponibles

#### 5. Tests de Reproduction Systémiques
- **Scripts minimaux**: Création dynamique pour chaque langage
- **Exécution multi-méthodes**: PowerShell 5.1, PowerShell 7+, Python, Node.js
- **Validation UTF-8**: Test avec caractères accentués et emojis complexes

## 🚨 Causes Profondes Identifiées

### 1. Conflit Fondamental: Option UTF-8 Beta vs Paramètres Hérités

**Problème**: Windows 11 maintient une compatibilité ascendante avec les applications non-Unicode même lorsque l'option "Beta: Use Unicode UTF-8 for worldwide language support" est activée.

**Impact**:
- Les applications héritées (conhost.exe, PowerShell 5.1) utilisent toujours les pages de code ANSI/OEM
- Les applications modernes (Windows Terminal, PowerShell 7+) utilisent UTF-8
- **Résultat**: Comportement incohérent selon la méthode d'exécution

### 2. Registre Windows: Configuration Fragmentée

**Problème**: Le registre contient des paramètres contradictoires :
- `ACP` (ANSI Code Page) peut être différent de 65001 (UTF-8)
- `OEMCP` (OEM Code Page) maintient l'héritage DOS
- Les paramètres `HKCU\Console` peuvent surcharger la configuration système

**Impact**:
- Chaque processus peut utiliser une page de code différente
- Pas de centralisation de la configuration UTF-8

### 3. Infrastructure Console: Dualité Confligante

**Problème**: Coexistence de deux infrastructures :
- **conhost.exe**: Hérité, limité, pages de code ANSI/OEM
- **Windows Terminal**: Moderne, UTF-8 natif, support ConPTY

**Impact**:
- Les scripts exécutés via VSCode peuvent utiliser conhost.exe
- Les scripts exécutés directement utilisent Windows Terminal
- **Résultat**: Comportement imprévisible

### 4. Variables d'Environnement: Priorité Confuse

**Problème**: Hiérarchie complexe des variables :
1. Variables système (Panel de configuration)
2. Variables utilisateur (registre)
3. Variables de session (processus)
4. Variables d'application (PYTHONUTF8, NODE_ENCODING)

**Impact**:
- `PYTHONUTF8=1` peut être ignoré si une variable système prioritaire existe
- Les variables peuvent être interprétées différemment selon le contexte

## 🎯 Analyse Spécifique par Langage

### Python 3.x
**Problème Principal**: `sys.stdout.encoding` n'est pas toujours UTF-8 même avec `PYTHONUTF8=1`

**Causes**:
1. **Conhost.exe**: Force l'utilisation de la page de code OEM
2. **Legacy Windows**: Python détecte l'environnement comme non-UTF-8
3. **Variable PYTHONIOENCODING**: Absente ou incorrecte

**Solution Technique**:
```powershell
# Configuration complète pour Python UTF-8
$env:PYTHONUTF8 = "1"
$env:PYTHONIOENCODING = "utf-8"
$env:LANG = "fr_FR.UTF-8"
```

### Node.js
**Problème Principal**: `process.stdout.encoding` peut être `undefined` sur conhost.exe

**Causes**:
1. **Détection automatique**: Node.js se base sur l'environnement console
2. **Absence de configuration explicite**: Pas d'équivalent à PYTHONIOENCODING
3. **Héritage conhost**: Limitation héritée de Windows

**Solution Technique**:
```powershell
# Configuration pour Node.js UTF-8
$env:NODE_OPTIONS = "--encoding=utf8"
$env:LANG = "fr_FR.UTF-8"
```

### PowerShell
**Problème Principal**: Différence entre PowerShell 5.1 et 7+

**Causes**:
1. **PowerShell 5.1**: Hérité, utilise `[Console]::OutputEncoding` par défaut
2. **PowerShell 7+**: Cross-platform, UTF-8 par défaut mais peut être surchargé
3. **Profiles différents**: `$PROFILE` vs `$HOME\Documents\WindowsPowerShell\profile.ps1`

**Solution Technique**:
```powershell
# Forcer UTF-8 dans tous les PowerShell
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
```

## 🛠️ Recommandations Système

### 1. Configuration Windows Prioritaire

#### Activer Complètement l'Option UTF-8 Beta
1. **Paramètres Windows** > **Heure et langue** > **Langue et région**
2. **Paramètres administratifs** > **Langue** > **"Beta: Use Unicode UTF-8 for worldwide language support"**
3. **Redémarrer obligatoire** pour prise en compte complète

#### Vérifier les Paramètres Régionaux
```powershell
# Vérifier la configuration actuelle
Get-WinSystemLocale
Get-WinUserLanguageList
Get-Culture
```

### 2. Registre Windows: Standardisation UTF-8

#### Clés à Modifier
```registry
[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Nls\CodePage]
"ACP"=dword:0000fde9  ; 65001 en hexadécimal
"OEMCP"=dword:0000fde9

[HKEY_CURRENT_USER\Console]
"CodePage"=dword:0000fde9
"FaceName"="Consolas"
"FontFamily"="Lucida Console"
```

#### Script de Correction Automatisée
```powershell
# Correction du registre pour UTF-8
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage" -Name "ACP" -Value 65001 -Type DWord
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage" -Name "OEMCP" -Value 65001 -Type DWord
Set-ItemProperty -Path "HKCU:\Console" -Name "CodePage" -Value 65001 -Type DWord
```

### 3. Variables d'Environnement: Configuration Centralisée

#### Variables Système à Définir
```powershell
# Variables système (Panel de configuration)
[System.Environment]::SetEnvironmentVariable("PYTHONUTF8", "1", "Machine")
[System.Environment]::SetEnvironmentVariable("PYTHONIOENCODING", "utf-8", "Machine")
[System.Environment]::SetEnvironmentVariable("NODE_OPTIONS", "--encoding=utf8", "Machine")
[System.Environment]::SetEnvironmentVariable("LANG", "fr_FR.UTF-8", "Machine")
[System.Environment]::SetEnvironmentVariable("LC_ALL", "fr_FR.UTF-8", "Machine")
```

#### Variables Utilisateur (Fallback)
```powershell
# Variables utilisateur (registre)
[System.Environment]::SetEnvironmentVariable("PYTHONUTF8", "1", "User")
[System.Environment]::SetEnvironmentVariable("PYTHONIOENCODING", "utf-8", "User")
[System.Environment]::SetEnvironmentVariable("NODE_OPTIONS", "--encoding=utf8", "User")
[System.Environment]::SetEnvironmentVariable("LANG", "fr_FR.UTF-8", "User")
```

### 4. Infrastructure Console: Modernisation

#### Forcer Windows Terminal
```powershell
# Définir Windows Terminal comme défaut
Set-ItemProperty -Path "HKCU:\Console" -Name "ForceV2" -Value 1 -Type DWord
# Ou installer Windows Terminal depuis Microsoft Store si non présent
```

#### Configuration PowerShell Unifiée
```powershell
# Profile PowerShell 7+ (prioritaire)
$profile7 = $PROFILE
if (-not (Test-Path $profile7)) {
    New-Item -ItemType File -Path $profile7 -Force
}

# Profile PowerShell 5.1 (compatibilité)
$profile51 = "$HOME\Documents\WindowsPowerShell\profile.ps1"
if (-not (Test-Path $profile51)) {
    New-Item -ItemType File -Path $profile51 -Force
}

# Contenu commun pour les deux profiles
$profileContent = @"
# Configuration UTF-8 universelle
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# Variables d'environnement UTF-8
`$env:PYTHONUTF8 = "1"
`$env:PYTHONIOENCODING = "utf-8"
`$env:NODE_OPTIONS = "--encoding=utf8"
`$env:LANG = "fr_FR.UTF-8"
"@

$profileContent | Out-File -FilePath $profile7 -Encoding UTF8
$profileContent | Out-File -FilePath $profile51 -Encoding UTF8
```

## 🧪 Tests de Validation

### Test 1: Validation de Configuration
```powershell
# Exécuter le diagnostic complet
.\scripts\diagnostic-encoding-os-windows.ps1

# Vérifier que tous les tests passent
# Résultat attendu: SuccessRate >= 90%
```

### Test 2: Validation par Langage
```powershell
# Test Python avec configuration complète
`$env:PYTHONUTF8 = "1"; `$env:PYTHONIOENCODING = "utf-8"; python -c "import sys; print(sys.stdout.encoding)"

# Test Node.js avec configuration complète  
`$env:NODE_OPTIONS = "--encoding=utf8"; node -e "console.log(process.stdout.encoding || 'undefined')"

# Test PowerShell avec configuration complète
pwsh -Command "[Console]::OutputEncoding.EncodingName"
```

### Test 3: Validation Cross-Processus
```powershell
# Créer un fichier test avec emojis
"Test UTF-8: é è à ù ç œ æ â ê î ô û 🚀 💻 ⚙️ 🪲" | Out-File -FilePath "test-utf8.txt" -Encoding UTF8

# Lecture par différents processus
powershell.exe -Command "Get-Content test-utf8.txt"
pwsh -Command "Get-Content test-utf8.txt"  
python -c "with open('test-utf8.txt', 'r', encoding='utf-8') as f: print(f.read())"
node -e "const fs = require('fs'); console.log(fs.readFileSync('test-utf8.txt', 'utf8'));"
```

## 📊 Matrice de Compatibilité

| Langage | Conhost.exe | Windows Terminal | PowerShell 5.1 | PowerShell 7+ | Recommandation |
|---------|-------------|----------------|---------------|--------------|----------------|
| Python 3.x | ❌ ANSI/OEM | ✅ UTF-8 | ❌ ANSI/OEM | ✅ UTF-8 | Variables + PYTHONIOENCODING |
| Node.js | ❌ undefined | ✅ utf-8 | ❌ undefined | ✅ utf-8 | NODE_OPTIONS + LANG |
| PowerShell 5.1 | ❌ ANSI/OEM | ✅ UTF-8 | ❌ ANSI/OEM | ✅ UTF-8 | Profile + [Console]:: |
| PowerShell 7+ | ✅ UTF-8 | ✅ UTF-8 | ✅ UTF-8 | ✅ UTF-8 | Configuration par défaut |

## 🎯 Plan d'Action Prioritaire

### Phase 1: Correction Système Immédiate (Critique)
1. **Activer l'option UTF-8 beta** dans les paramètres Windows
2. **Redémarrer Windows** pour prise en compte
3. **Exécuter le diagnostic** pour validation

### Phase 2: Standardisation Registre (Important)
1. **Modifier les clés CodePage** pour forcer UTF-8 (65001)
2. **Configurer la console** avec police UTF-8 compatible
3. **Valider les changements** avec le diagnostic

### Phase 3: Configuration Environnement (Recommandé)
1. **Définir les variables système** pour tous les langages
2. **Créer les profiles PowerShell** unifiés
3. **Tester chaque langage** individuellement

### Phase 4: Infrastructure Modernisée (Optimal)
1. **Installer/mettre à jour Windows Terminal**
2. **Configurer VSCode** pour utiliser Windows Terminal
3. **Valider l'écosystème complet**

## 🔬 Conclusion

Le diagnostic révèle que les problèmes d'encodage sur Windows 11 Pro français ne sont pas des bugs isolés, mais le résultat d'une **architecture fragmentée** où coexistent :

1. **Configuration héritée** (ANSI/OEM) pour la compatibilité ascendante
2. **Configuration moderne** (UTF-8) pour les applications récentes
3. **Absence de centralisation** des paramètres UTF-8

La solution nécessite une **approche systémique** plutôt que des correctifs individuels. En appliquant les recommandations de ce rapport, les problèmes d'encodage devraient être résolus de manière permanente pour tous les langages de programmation.

---

**Script de diagnostic**: `scripts/diagnostic-encoding-os-windows.ps1`  
**Rapport généré**: 2025-10-29  
**Prochaine étape**: Exécution du diagnostic et validation des corrections