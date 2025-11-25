# Documentation des Variables d'Environnement UTF-8 Standardisées

**Date**: 2025-10-30  
**Version**: 1.0  
**Auteur**: Roo Architect Complex Mode  
**ID Correction**: SYS-003-ENVIRONMENT  
**Priorité**: CRITIQUE  

## 📋 Table des Matières

1. [Introduction et Objectifs](#introduction-et-objectifs)
2. [Vue d'Ensemble des Standards UTF-8](#vue-densemble-des-standards-utf-8)
3. [Variables Machine (HKLM)](#variables-machine-hklm)
4. [Variables User (HKCU)](#variables-user-hkcu)
5. [Variables Processus](#variables-processus)
6. [Variables Spécifiques aux Applications](#variables-spécifiques-aux-applications)
7. [Procédures de Validation](#procédures-de-validation)
8. [Guide de Dépannage](#guide-de-dépannage)
9. [Références et Ressources Complémentaires](#références-et-ressources-complémentaires)

---

## 🎯 Introduction et Objectifs

### Contexte

Cette documentation décrit l'ensemble des variables d'environnement UTF-8 standardisées pour Windows 11 Pro français. L'objectif est de garantir un support complet et cohérent de l'encodage UTF-8 à tous les niveaux du système d'exploitation et des applications.

### Objectifs Principaux

- **Standardisation**: Établir une configuration UTF-8 cohérente sur tout le système
- **Persistance**: Assurer la persistance des variables après redémarrage
- **Compatibilité**: Maintenir la compatibilité avec les applications existantes
- **Validation**: Fournir des outils de validation et de diagnostic
- **Maintenance**: Faciliter la maintenance et l'évolution de la configuration

### Portée

Cette documentation couvre :
- Les variables d'environnement système (Machine)
- Les variables utilisateur (User)
- Les variables de processus (Process)
- Les variables spécifiques aux applications courantes
- Les procédures de validation et de dépannage

---

## 🌐 Vue d'Ensemble des Standards UTF-8

### Hiérarchie des Variables

```
Machine (HKLM) > User (HKCU) > Processus
```

### Standards d'Encodage

| Type | Standard | Valeur Recommandée | Description |
|------|----------|-------------------|-------------|
| Locale | LANG | fr-FR.UTF-8 | Locale principale pour les applications |
| Locale | LC_ALL | fr_FR.UTF-8 | Override de toutes les locales |
| Console | CodePage | 65001 | Page de code UTF-8 |
| Python | PYTHONIOENCODING | utf-8 | Encodage des entrées/sorties Python |
| Java | JAVA_TOOL_OPTIONS | -Dfile.encoding=UTF-8 | Encodage des fichiers Java |
| Node.js | NODE_OPTIONS | --max-old-space-size=4096 | Options Node.js avec support UTF-8 |

### Configuration Système Requise

- **OS**: Windows 10+ (Windows 11 Pro recommandé)
- **Option Beta**: "Use Unicode UTF-8 for worldwide language support" activée
- **Registre**: Pages de code configurées à 65001
- **PowerShell**: 5.1+ (7+ recommandé)

---

## 🖥️ Variables Machine (HKLM)

Les variables Machine sont définies au niveau système et s'appliquent à tous les utilisateurs. Elles sont stockées dans la registre `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment`.

### Variables Système Essentielles

#### COMSPEC
- **Description**: Interpréteur de commandes par défaut
- **Valeur**: `C:\Windows\system32\cmd.exe`
- **Impact**: Définit l'interpréteur utilisé par les scripts batch
- **Exemple**:
  ```powershell
  # Vérification
  $env:COMSPEC
  # Résultat attendu: C:\Windows\system32\cmd.exe
  ```

#### PATHEXT
- **Description**: Extensions de fichiers exécutables
- **Valeur**: `.COM;.EXE;.BAT;.CMD;.VBS;.VBE;.JS;.JSE;.WSF;.WSH;.MSC`
- **Impact**: Détermine les extensions considérées comme exécutables
- **Exemple**:
  ```powershell
  # Vérification
  $env:PATHEXT
  # Résultat attendu: .COM;.EXE;.BAT;.CMD;.VBS;.VBE;.JS;.JSE;.WSF;.WSH;.MSC
  ```

#### TEMP / TMP
- **Description**: Répertoires temporaires système
- **Valeur**: `C:\Windows\Temp`
- **Impact**: Emplacement des fichiers temporaires système
- **Exemple**:
  ```powershell
  # Vérification
  $env:TEMP
  $env:TMP
  # Résultat attendu: C:\Windows\Temp
  ```

#### SystemRoot
- **Description**: Répertoire d'installation de Windows
- **Valeur**: `C:\Windows`
- **Impact**: Référence pour les chemins système
- **Exemple**:
  ```powershell
  # Vérification
  $env:SystemRoot
  # Résultat attendu: C:\Windows
  ```

#### OS
- **Description**: Nom du système d'exploitation
- **Valeur**: `Windows_NT`
- **Impact**: Identification du système pour les scripts
- **Exemple**:
  ```powershell
  # Vérification
  $env:OS
  # Résultat attendu: Windows_NT
  ```

### Variables de Chemins Système

#### PATH
- **Description**: Chemins de recherche des exécutables
- **Valeur**: 
  ```
  C:\Windows\system32;
  C:\Windows\system32\Wbem;
  C:\Windows\System32\WindowsPowerShell\v1.0;
  C:\Program Files\PowerShell\7;
  C:\Program Files\Common Files\Microsoft Shared\Windows Live;
  C:\Program Files (x86)\Windows Kits\10\bin\10.0.22000.0\x64;
  C:\Program Files\Git\cmd;
  C:\Program Files\Git\mingw64\bin;
  C:\Program Files\Git\usr\bin
  ```
- **Impact**: Recherche des commandes et exécutables
- **Exemple**:
  ```powershell
  # Vérification
  $env:PATH -split ';'
  # Résultat attendu: Liste des chemins ci-dessus
  ```

#### PSModulePath
- **Description**: Chemins de recherche des modules PowerShell
- **Valeur**:
  ```
  C:\Program Files\WindowsPowerShell\Modules;
  C:\Windows\system32\WindowsPowerShell\v1.0\Modules;
  C:\Program Files\PowerShell\7\Modules
  ```
- **Impact**: Importation des modules PowerShell
- **Exemple**:
  ```powershell
  # Vérification
  $env:PSModulePath -split ';'
  # Résultat attendu: Liste des chemins ci-dessus
  ```

### Variables Système Dynamiques

Ces variables sont détectées automatiquement par le script :

| Variable | Description | Valeur Typique |
|----------|-------------|----------------|
| `NUMBER_OF_PROCESSORS` | Nombre de processeurs | 8, 16, etc. |
| `PROCESSOR_ARCHITECTURE` | Architecture processeur | AMD64, x86, etc. |
| `PROCESSOR_IDENTIFIER` | Identifiant processeur | Intel(R) Core(TM) i7-... |
| `COMPUTERNAME` | Nom de l'ordinateur | NOM-POSTE |
| `USERNAME` | Nom d'utilisateur système | SYSTEM |
| `USERDOMAIN` | Domaine utilisateur | WORKGROUP |

### Variables de Répertoires Système

| Variable | Description | Valeur |
|----------|-------------|--------|
| `SystemDrive` | Lecteur système | `C:` |
| `ProgramFiles` | Programmes 64-bit | `C:\Program Files` |
| `ProgramFilesx86` | Programmes 32-bit | `C:\Program Files (x86)` |
| `ProgramData` | Données programmes | `C:\ProgramData` |
| `PUBLIC` | Utilisateurs publics | `C:\Users\Public` |
| `WINDIR` | Répertoire Windows | `C:\Windows` |

### Variables PowerShell

| Variable | Description | Valeur |
|----------|-------------|--------|
| `POWERSHELL_DISTRIBUTION_CHANNEL` | Canal de distribution | `MSI` |
| `POWERSHELL_UPDATECHECK` | Vérification mises à jour | `Default` |
| `POWERSHELL_TELEMETRY_OPTOUT` | Désactiver télémétrie | `1` |

---

## 👤 Variables User (HKCU)

Les variables User sont spécifiques à l'utilisateur actuel et sont stockées dans la registre `HKEY_CURRENT_USER\Environment`.

### Variables de Chemins Utilisateur

#### PATH (User)
- **Description**: Chemins utilisateur ajoutés au PATH système
- **Valeur**:
  ```
  %USERPROFILE%\AppData\Local\Microsoft\WindowsApps;
  %USERPROFILE%\AppData\Local\Programs\Microsoft VS Code\bin;
  %USERPROFILE%\AppData\Local\Programs\Microsoft VS Code Insiders\bin;
  %USERPROFILE%\AppData\Roaming\npm;
  %USERPROFILE%\AppData\Roaming\Git\cmd;
  %USERPROFILE%\AppData\Roaming\GitHub CLI\bin
  ```
- **Impact**: Ajoute les chemins utilisateur au PATH système
- **Exemple**:
  ```powershell
  # Vérification
  [System.Environment]::GetEnvironmentVariable("PATH", "User")
  # Résultat attendu: Chemins ci-dessus
  ```

#### HOME
- **Description**: Répertoire personnel de l'utilisateur
- **Valeur**: `%USERPROFILE%`
- **Impact**: Répertoire de base pour les applications Unix-like
- **Exemple**:
  ```powershell
  # Vérification
  $env:HOME
  # Résultat attendu: C:\Users\NomUtilisateur
  ```

### Variables de Stockage Cloud

| Variable | Description | Valeur |
|----------|-------------|--------|
| `ONEDRIVE` | Répertoire OneDrive personnel | `%USERPROFILE%\OneDrive` |
| `ONEDRIVECOMMERCIAL` | OneDrive Commercial | `%USERPROFILE%\OneDrive - Commercial` |
| `GOOGLE_DRIVE` | Google Drive | `%USERPROFILE%\Google Drive` |
| `DROPBOX` | Dropbox | `%USERPROFILE%\Dropbox` |

### Variables de Dossiers Utilisateur

Ces variables pointent vers les dossiers spéciaux de l'utilisateur :

| Variable | Description | Valeur |
|----------|-------------|--------|
| `DOCUMENTS` | Documents | `[System.Environment]::GetFolderPath("MyDocuments")` |
| `DESKTOP` | Bureau | `[System.Environment]::GetFolderPath("Desktop")` |
| `DOWNLOADS` | Téléchargements | `%USERPROFILE%\Downloads` |
| `MUSIC` | Musique | `[System.Environment]::GetFolderPath("MyMusic")` |
| `PICTURES` | Images | `[System.Environment]::GetFolderPath("MyPictures")` |
| `VIDEOS` | Vidéos | `[System.Environment]::GetFolderPath("MyVideos")` |
| `FAVORITES` | Favoris | `[System.Environment]::GetFolderPath("Favorites")` |
| `RECENT` | Éléments récents | `[System.Environment]::GetFolderPath("Recent")` |

### Variables de Profil Itinérant

| Variable | Description | Valeur |
|----------|-------------|--------|
| `USERDOMAIN_ROAMINGPROFILE` | Domaine profil itinérant | `%USERDOMAIN%` |
| `USERNAME_ROAMINGPROFILE` | Nom utilisateur itinérant | `%USERNAME%` |
| `HOMEPATH_ROAMINGPROFILE` | Chemin profil itinérant | `%HOMEPATH%` |
| `APPDATA_ROAMINGPROFILE` | AppData itinérant | `%APPDATA%` |
| `LOCALAPPDATA_ROAMINGPROFILE` | LocalAppData itinérant | `%LOCALAPPDATA%` |

---

## ⚙️ Variables Processus

Les variables Processus s'appliquent uniquement à la session actuelle et sont prioritaires sur les variables Machine et User.

### Variables Locales UTF-8

#### LANG
- **Description**: Locale principale pour les applications
- **Valeur**: `fr-FR.UTF-8`
- **Impact**: Définit la langue et l'encodage par défaut
- **Exemple**:
  ```powershell
  # Configuration
  $env:LANG = "fr-FR.UTF-8"
  
  # Vérification
  Get-Command date | Select-Object Source
  # Affiche la date au format français
  ```

#### LC_ALL
- **Description**: Override de toutes les locales
- **Valeur**: `fr_FR.UTF-8`
- **Impact**: Force toutes les catégories de locale
- **Exemple**:
  ```powershell
  # Configuration
  $env:LC_ALL = "fr_FR.UTF-8"
  
  # Vérification
  locale
  # Affiche toutes les catégories en français
  ```

#### Catégories de Locale Spécifiques

| Variable | Description | Valeur |
|----------|-------------|--------|
| `LC_CTYPE` | Classification des caractères | `fr_FR.UTF-8` |
| `LC_NUMERIC` | Format des nombres | `fr_FR.UTF-8` |
| `LC_TIME` | Format des dates/heures | `fr_FR.UTF-8` |
| `LC_COLLATE` | Ordre de tri | `fr_FR.UTF-8` |
| `LC_MONETARY` | Format monétaire | `fr_FR.UTF-8` |
| `LC_MESSAGES` | Messages système | `fr_FR.UTF-8` |
| `LC_PAPER` | Format papier | `fr_FR.UTF-8` |
| `LC_NAME` | Format noms | `fr_FR.UTF-8` |
| `LC_ADDRESS` | Format adresses | `fr_FR.UTF-8` |
| `LC_TELEPHONE` | Format téléphones | `fr_FR.UTF-8` |
| `LC_MEASUREMENT` | Système de mesure | `fr_FR.UTF-8` |
| `LC_IDENTIFICATION` | Identification | `fr_FR.UTF-8` |

### Variables d'Encodage Applicatif

#### PYTHONIOENCODING
- **Description**: Encodage des entrées/sorties Python
- **Valeur**: `utf-8`
- **Impact**: Force UTF-8 pour stdin/stdout/stderr Python
- **Exemple**:
  ```python
  # Test Python
  import sys
  print(f"Encodage stdout: {sys.stdout.encoding}")
  print(f"Encodage stdin: {sys.stdin.encoding}")
  print(f"Encodage stderr: {sys.stderr.encoding}")
  # Résultat attendu: utf-8 pour tous
  ```

#### JAVA_TOOL_OPTIONS
- **Description**: Options JVM par défaut
- **Valeur**: `-Dfile.encoding=UTF-8`
- **Impact**: Force l'encodage UTF-8 pour les applications Java
- **Exemple**:
  ```java
  // Test Java
  public class EncodingTest {
      public static void main(String[] args) {
          System.out.println("Encodage par défaut: " + System.getProperty("file.encoding"));
          System.out.println("Test UTF-8: é è à ù ç œ æ");
      }
  }
  // Résultat attendu: UTF-8 et caractères corrects
  ```

#### NODE_OPTIONS
- **Description**: Options Node.js par défaut
- **Valeur**: `--max-old-space-size=4096`
- **Impact**: Configure la mémoire et l'encodage Node.js
- **Exemple**:
  ```javascript
  // Test Node.js
  console.log('Test UTF-8: é è à ù ç œ æ');
  console.log('Mémoire max:', process.execArgv);
  // Résultat attendu: Caractères corrects et mémoire configurée
  ```

---

## 🛠️ Variables Spécifiques aux Applications

### Git

| Variable | Description | Valeur |
|----------|-------------|--------|
| `GIT_CONFIG_NOREPLACEDIRS` | Désactiver remplacement répertoires | `true` |
| `GIT_CONFIG_PAGER` | Pager par défaut | `cat` |
| `GIT_CONFIG_CORE_QUOTE_PATH` | Citation des chemins | `false` |
| `GIT_CONFIG_CORE_PRECOMPOSE_UNICODE` | Unicode précomposé | `true` |
| `GIT_CONFIG_CORE_AUTOCRLF` | Conversion automatique CRLF | `false` |
| `GIT_CONFIG_CORE_SAFE_CRLF` | CRLF sécurisé | `false` |

### Chocolatey

| Variable | Description | Valeur |
|----------|-------------|--------|
| `CHOCO_DEFAULT_TIMEOUT` | Timeout par défaut | `300` |
| `CHOCO_FEATURES` | Fonctionnalités activées | `memory,exit` |

### npm/Node.js

| Variable | Description | Valeur |
|----------|-------------|--------|
| `NPM_CONFIG_PREFIX` | Répertoire d'installation global | `%USERPROFILE%\AppData\Roaming\npm` |
| `YARN_GLOBAL_FOLDER` | Dossier global Yarn | `%USERPROFILE%\AppData\Local\Yarn\Data\global` |
| `YARN_ENABLE_IMMUTABLE_INSTALLS` | Installations immuables | `false` |

### VS Code

| Variable | Description | Valeur |
|----------|-------------|--------|
| `VSCODE_PORTABLE` | Mode portable | `false` |
| `VSCODE_USER_DATA_DIR` | Données utilisateur | `%USERPROFILE%\AppData\Roaming\Code\User` |
| `VSCODE_EXTENSIONS_DIR` | Extensions | `%USERPROFILE%\AppData\Roaming\Code\extensions` |
| `VSCODE_LOGS_DIR` | Logs | `%USERPROFILE%\AppData\Roaming\Code\logs` |

### Éditeurs et Navigateurs

| Variable | Description | Valeur |
|----------|-------------|--------|
| `EDITOR` | Éditeur de texte par défaut | `code --wait` |
| `VISUAL` | Éditeur visuel par défaut | `code --wait` |
| `BROWSER` | Navigateur par défaut | `msedge` |
| `DEFAULT_BROWSER` | Navigateur par défaut (alt) | `msedge` |

---

## ✅ Procédures de Validation

### Script de Configuration

#### Set-StandardizedEnvironment.ps1

**Objectif**: Configurer les variables d'environnement UTF-8 standardisées

**Syntaxe de base**:
```powershell
# Exécution standard
.\Set-StandardizedEnvironment.ps1

# Forcer l'application
.\Set-StandardizedEnvironment.ps1 -Force

# Validation uniquement
.\Set-StandardizedEnvironment.ps1 -ValidateOnly

# Avec logs détaillés
.\Set-StandardizedEnvironment.ps1 -LogLevel DEBUG
```

**Paramètres**:
- `-Force`: Force l'application même si des incohérences sont détectées
- `-ValidateOnly`: Effectue uniquement la validation sans modifier
- `-BackupPath`: Chemin personnalisé pour les backups
- `-LogLevel`: Niveau de détail (INFO, DEBUG, VERBOSE)
- `-RestartRequired`: Indique si un redémarrage est requis

### Script de Validation

#### Test-StandardizedEnvironment.ps1

**Objectif**: Valider la configuration UTF-8 de l'environnement

**Syntaxe de base**:
```powershell
# Validation simple
.\Test-StandardizedEnvironment.ps1

# Validation détaillée
.\Test-StandardizedEnvironment.ps1 -Detailed

# Génération de rapport
.\Test-StandardizedEnvironment.ps1 -GenerateReport -OutputFormat Markdown

# Tests de fichiers
.\Test-StandardizedEnvironment.ps1 -TestFiles

# Comparaison avec backup
.\Test-StandardizedEnvironment.ps1 -CompareWithBackup -BackupPath "backup.json"
```

**Tests effectués**:
1. **EnvironmentHierarchy**: Validation de la hiérarchie Machine > User > Processus
2. **EnvironmentPersistence**: Test de persistance des variables
3. **UTF8EnvironmentSupport**: Validation du support UTF-8
4. **ApplicationCompatibility**: Compatibilité avec les applications
5. **EnvironmentConsistency**: Cohérence globale de l'environnement

### Validation Manuelle

#### Variables Machine
```powershell
# Vérification des variables Machine
Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment"

# Test spécifique
[System.Environment]::GetEnvironmentVariable("COMSPEC", "Machine")
[System.Environment]::GetEnvironmentVariable("PATH", "Machine")
```

#### Variables User
```powershell
# Vérification des variables User
Get-ItemProperty -Path "HKCU:\Environment"

# Test spécifique
[System.Environment]::GetEnvironmentVariable("HOME", "User")
[System.Environment]::GetEnvironmentVariable("PATH", "User")
```

#### Variables Processus
```powershell
# Vérification des variables Processus
Get-ChildItem Env:

# Test spécifique
$env:LANG
$env:LC_ALL
$env:PYTHONIOENCODING
```

### Tests d'Encodage

#### Test Console
```powershell
# Test de la console
chcp
# Résultat attendu: Page de codes active : 65001

# Test d'affichage
Write-Host "Test UTF-8: é è à ù ç œ æ â ê î ô û 🚀"
```

#### Test Fichiers
```powershell
# Test de création de fichier UTF-8
$testContent = "Test UTF-8: é è à ù ç œ æ â ê î ô û 🚀"
$testFile = "$env:TEMP\utf8-test.txt"
$testContent | Out-File -FilePath $testFile -Encoding UTF8

# Vérification
$content = Get-Content -Path $testFile -Raw -Encoding UTF8
$testContent -eq $content  # Doit retourner $true
```

#### Test Applications
```powershell
# Test Python
python -c "import sys; print(f'Python encoding: {sys.stdout.encoding}')"

# Test Node.js
node -e "console.log('Node.js UTF-8 test: é è à ù ç')"

# Test Java
java -Dfile.encoding=UTF-8 -cp . EncodingTest
```

---

## 🔧 Guide de Dépannage

### Problèmes Courants

#### 1. Variables Non Persistantes

**Symptôme**: Les variables disparaissent après redémarrage

**Causes possibles**:
- Permissions insuffisantes
- Registre protégé
- Script exécuté sans droits administrateur

**Solutions**:
```powershell
# Exécuter en tant qu'administrateur
Start-Process PowerShell -Verb RunAs

# Vérifier les permissions
Test-Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment"

# Forcer l'écriture
.\Set-StandardizedEnvironment.ps1 -Force
```

#### 2. Caractères UTF-8 Incorrects

**Symptôme**: Caractères altérés dans la console ou les fichiers

**Causes possibles**:
- Page de code incorrecte
- Variable LANG/LC_ALL non définie
- Application non compatible UTF-8

**Solutions**:
```powershell
# Vérifier la page de code
chcp
# Si différent de 65001:
chcp 65001

# Définir les variables
$env:LANG = "fr-FR.UTF-8"
$env:LC_ALL = "fr_FR.UTF-8"

# Tester avec PowerShell 7+
pwsh -Command "Write-Host 'Test: é è à ù ç'"
```

#### 3. Conflits de Variables

**Symptôme**: Variables différentes entre les niveaux

**Causes possibles**:
- Définitions multiples
- Priorités incorrectes
- Héritage problématique

**Solutions**:
```powershell
# Diagnostic des conflits
.\Test-StandardizedEnvironment.ps1 -Detailed -GenerateReport

# Comparaison des niveaux
$machinePath = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
$userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
$processPath = [System.Environment]::GetEnvironmentVariable("PATH", "Process")

# Réinitialisation propre
.\Set-StandardizedEnvironment.ps1 -Force -BackupPath "backup-before-fix.json"
```

#### 4. Applications Non Compatibles

**Symptôme**: Certaines applications n'affichent pas correctement l'UTF-8

**Causes possibles**:
- Application ancienne
- Configuration spécifique requise
- Encodage hardcodé

**Solutions**:
```powershell
# Test de compatibilité
.\Test-StandardizedEnvironment.ps1 -TestFiles

# Configuration spécifique pour applications problématiques
# Exemple pour Git
git config --global core.quotepath false
git config --global core.precomposeunicode true

# Exemple pour Python
set PYTHONIOENCODING=utf-8
python votre_script.py
```

### Messages d'Erreur Courants

#### "Accès refusé" lors de la configuration
```powershell
# Solution: Exécuter en tant qu'administrateur
Start-Process PowerShell -Verb RunAs -ArgumentList "-File Set-StandardizedEnvironment.ps1"
```

#### "Variable non trouvée" lors de la validation
```powershell
# Solution: Reconfigurer l'environnement
.\Set-StandardizedEnvironment.ps1 -Force

# Ou vérifier manuellement
Get-ChildItem Env: | Where-Object Name -like "*UTF*"
```

#### "Fichier corrompu" lors des tests UTF-8
```powershell
# Solution: Vérifier l'encodage du système
chcp 65001
$env:PYTHONIOENCODING = "utf-8"
$env:JAVA_TOOL_OPTIONS = "-Dfile.encoding=UTF-8"

# Recréer les fichiers de test
.\Test-StandardizedEnvironment.ps1 -TestFiles
```

### Scripts de Diagnostic

#### Diagnostic Complet
```powershell
# Script de diagnostic complet
function Start-UTF8Diagnostic {
    Write-Host "=== DIAGNOSTIC UTF-8 COMPLET ===" -ForegroundColor Cyan
    
    # 1. Page de code
    Write-Host "`n1. Page de code console:" -ForegroundColor Yellow
    chcp
    
    # 2. Variables locales
    Write-Host "`n2. Variables locales:" -ForegroundColor Yellow
    "LANG", "LC_ALL", "LC_CTYPE" | ForEach-Object {
        $value = [System.Environment]::GetEnvironmentVariable($_)
        Write-Host "$_ = $value"
    }
    
    # 3. Variables d'encodage
    Write-Host "`n3. Variables d'encodage:" -ForegroundColor Yellow
    "PYTHONIOENCODING", "JAVA_TOOL_OPTIONS", "NODE_OPTIONS" | ForEach-Object {
        $value = [System.Environment]::GetEnvironmentVariable($_)
        Write-Host "$_ = $value"
    }
    
    # 4. Test de fichier
    Write-Host "`n4. Test de fichier UTF-8:" -ForegroundColor Yellow
    $testFile = "$env:TEMP\utf8-diagnostic.txt"
    "Test: é è à ù ç œ æ 🚀" | Out-File -FilePath $testFile -Encoding UTF8
    $content = Get-Content -Path $testFile -Raw -Encoding UTF8
    Write-Host "Contenu: $content"
    Write-Host "Succès: $(("Test: é è à ù ç œ æ 🚀" -eq $content))"
    
    # 5. Applications
    Write-Host "`n5. Test applications:" -ForegroundColor Yellow
    try {
        $pythonVersion = python --version 2>$null
        Write-Host "Python: $pythonVersion"
    } catch {
        Write-Host "Python: Non disponible"
    }
    
    try {
        $nodeVersion = node --version 2>$null
        Write-Host "Node.js: $nodeVersion"
    } catch {
        Write-Host "Node.js: Non disponible"
    }
    
    Write-Host "`n=== FIN DU DIAGNOSTIC ===" -ForegroundColor Cyan
}

# Exécution
Start-UTF8Diagnostic
```

#### Réparation Automatique
```powershell
# Script de réparation automatique
function Repair-UTF8Environment {
    param([switch]$Force)
    
    Write-Host "=== RÉPARATION ENVIRONNEMENT UTF-8 ===" -ForegroundColor Cyan
    
    # 1. Page de code
    Write-Host "`n1. Configuration page de code..." -ForegroundColor Yellow
    chcp 65001 | Out-Null
    
    # 2. Variables locales
    Write-Host "`n2. Configuration variables locales..." -ForegroundColor Yellow
    $env:LANG = "fr-FR.UTF-8"
    $env:LC_ALL = "fr_FR.UTF-8"
    $env:LC_CTYPE = "fr_FR.UTF-8"
    
    # 3. Variables d'encodage
    Write-Host "`n3. Configuration variables d'encodage..." -ForegroundColor Yellow
    $env:PYTHONIOENCODING = "utf-8"
    $env:JAVA_TOOL_OPTIONS = "-Dfile.encoding=UTF-8"
    $env:NODE_OPTIONS = "--max-old-space-size=4096"
    
    # 4. Validation
    Write-Host "`n4. Validation..." -ForegroundColor Yellow
    $testResult = .\Test-StandardizedEnvironment.ps1 -GenerateReport -OutputFormat JSON
    
    if ($testResult) {
        Write-Host "Réparation terminée. Consultez le rapport pour les détails." -ForegroundColor Green
    } else {
        Write-Host "Réparation incomplète. Exécutez avec -Force pour forcer." -ForegroundColor Red
    }
    
    Write-Host "`n=== FIN DE RÉPARATION ===" -ForegroundColor Cyan
}

# Exécution
Repair-UTF8Environment -Force
```

---

## 📚 Références et Ressources Complémentaires

### Scripts de Référence

#### Scripts Principaux
- **Set-StandardizedEnvironment.ps1**: Configuration des variables UTF-8
- **Test-StandardizedEnvironment.ps1**: Validation de l'environnement UTF-8

#### Scripts Complémentaires
- **Enable-UTF8WorldwideSupport.ps1**: Activation UTF-8 système
- **Test-UTF8Encoding.ps1**: Tests d'encodage avancés

### Documentation Technique

#### Standards UTF-8
- [RFC 3629 - UTF-8, a transformation format of ISO 10646](https://tools.ietf.org/html/rfc3629)
- [Unicode Standard](https://unicode.org/standard/standard.html)
- [Microsoft Unicode Support](https://docs.microsoft.com/en-us/windows/win32/intl/unicode)

#### Windows UTF-8
- [Microsoft Docs - Use Unicode UTF-8 for worldwide language support](https://docs.microsoft.com/en-us/windows/uwp/design/globalizing/use-utf8-code-page)
- [Windows Registry - Environment Variables](https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/set_1)
- [PowerShell Encoding](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_character_encoding)

### Ressources par Application

#### Python
- [Python Unicode HOWTO](https://docs.python.org/3/howto/unicode.html)
- [PYTHONIOENCODING Documentation](https://docs.python.org/3/using/cmdline.html#envvar-PYTHONIOENCODING)

#### Java
- [Java Encoding Documentation](https://docs.oracle.com/javase/8/docs/technotes/guides/intl/encoding.doc.html)
- [JAVA_TOOL_OPTIONS](https://docs.oracle.com/javase/8/docs/technotes/tools/windows/java.html)

#### Node.js
- [Node.js Encoding](https://nodejs.org/api/buffer.html#buffer_buffers_and_character_encodings)
- [NODE_OPTIONS](https://nodejs.org/api/cli.html#cli_node_options_options)

#### Git
- [Git Configuration](https://git-scm.com/book/en/v2/Customizing-Git-Git-Configuration)
- [Git and Unicode](https://git-scm.com/docs/git-config#Documentation/git-config.txt-corequotePath)

### Outils de Diagnostic

#### Outils Système
- **chcp**: Vérification/changement page de code
- **locale**: Affichage configuration locale (Unix-like)
- **PowerShell Get-ChildItem Env**: Liste variables environnement

#### Outils Tiers
- **Notepad++**: Éditeur avec support UTF-8 avancé
- **VSCodium**: VS Code sans télémétrie
- **Windows Terminal**: Terminal moderne avec support UTF-8

### Communautés et Support

#### Forums et Communautés
- [Stack Overflow - UTF-8 Tag](https://stackoverflow.com/questions/tagged/utf-8)
- [Microsoft Q&A - Windows UTF-8](https://docs.microsoft.com/en-us/answers/topics/windows-utf-8.html)
- [Reddit - r/PowerShell](https://www.reddit.com/r/PowerShell/)

#### Projets Connexes
- [Chocolatey](https://chocolatey.org/): Gestionnaire de paquets Windows
- [Scoop](https://scoop.sh/): Gestionnaire de paquets alternatif
- [Windows Terminal](https://github.com/microsoft/terminal): Terminal moderne

### Historique des Versions

#### Version 1.0 (2025-10-30)
- Version initiale complète
- Support Windows 11 Pro français
- Scripts de configuration et validation
- Documentation complète

#### Évolutions Prévues
- Support multi-langues
- Interface graphique de configuration
- Intégration avec Windows Terminal
- Tests automatisés CI/CD

---

## 📝 Conclusion

Cette documentation fournit une référence complète pour la configuration et la maintenance des variables d'environnement UTF-8 sur Windows 11 Pro français. En suivant les procédures décrites et en utilisant les scripts fournis, vous pouvez garantir un support UTF-8 robuste et cohérent sur l'ensemble de votre système.

Pour toute question ou problème, n'hésitez pas à consulter les ressources complémentaires ou à utiliser les scripts de diagnostic fournis.

---

**Statut**: ✅ **DOCUMENTATION COMPLÈTE**  
**Prochaine Étape**: Jour 5-5 - Infrastructure Console Moderne  
**Contact**: Roo Architect Complex Mode  
**ID**: SYS-003-ENVIRONMENT