# Guide de déploiement - Correction d'encodage UTF-8

**Version**: 1.0  
**Date**: 26/05/2025  
**Auteur**: Solution automatisée d'encodage UTF-8  

## Vue d'ensemble

Ce guide fournit les instructions complètes pour déployer la solution de correction d'encodage UTF-8 sur des machines Windows avec PowerShell et VSCode.

## Table des matières

1. [Prérequis](#prérequis)
2. [Installation rapide](#installation-rapide)
3. [Installation manuelle](#installation-manuelle)
4. [Validation](#validation)
5. [Dépannage](#dépannage)
6. [Désinstallation](#désinstallation)
7. [FAQ](#faq)

## Prérequis

### Système requis
- **OS**: Windows 10/11
- **PowerShell**: Version 5.0 ou supérieure
- **Droits**: Utilisateur standard (pas d'admin requis)
- **VSCode**: Optionnel mais recommandé

### Vérification des prérequis

```powershell
# Vérifier la version PowerShell
$PSVersionTable.PSVersion

# Vérifier les droits d'écriture dans le profil utilisateur
Test-Path "$env:USERPROFILE\OneDrive\Documents\WindowsPowerShell" -PathType Container
```

## Installation rapide

### Méthode 1: Script automatique (Recommandée)

1. **Télécharger** ou copier le dossier `encoding-fix` sur la machine cible
2. **Ouvrir PowerShell** en tant qu'utilisateur normal
3. **Naviguer** vers le dossier :
   ```powershell
   cd "D:\roo-extensions\encoding-fix"
   ```
4. **Exécuter** le script de déploiement :
   ```powershell
   .\apply-encoding-fix.ps1
   ```
5. **Redémarrer PowerShell** (fermer et rouvrir)
6. **Valider** l'installation :
   ```powershell
   .\validate-deployment.ps1
   ```

### Méthode 2: Avec paramètres

```powershell
# Installation avec sauvegarde forcée
.\apply-encoding-fix.ps1 -Force

# Installation sans sauvegarde (non recommandé)
.\apply-encoding-fix.ps1 -SkipBackup

# Installation avec logs détaillés
.\apply-encoding-fix.ps1 -Verbose
```

## Installation manuelle

### Étape 1: Sauvegarde du profil existant

```powershell
$profilePath = "$env:USERPROFILE\OneDrive\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
$backupPath = "$profilePath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

if (Test-Path $profilePath) {
    Copy-Item $profilePath $backupPath
    Write-Host "Sauvegarde créée: $backupPath"
}
```

### Étape 2: Configuration du profil PowerShell

Ajouter au profil PowerShell (`$PROFILE`) :

```powershell
# Configuration d'encodage UTF-8 pour PowerShell
# Ajouté automatiquement pour corriger les problèmes d'affichage des caractères français

# Forcer l'encodage de sortie en UTF-8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Configurer l'encodage de la console
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

# Définir la code page UTF-8 (65001)
try {
    chcp 65001 | Out-Null
} catch {
    Write-Warning "Impossible de définir la code page 65001"
}
```

### Étape 3: Configuration VSCode (Optionnel)

Créer ou modifier `.vscode/settings.json` :

```json
{
    "files.encoding": "utf8",
    "files.autoGuessEncoding": false,
    "terminal.integrated.shellArgs.windows": ["-NoExit", "-Command", "chcp 65001"],
    "terminal.integrated.profiles.windows": {
        "PowerShell UTF-8": {
            "source": "PowerShell",
            "args": ["-NoExit", "-Command", "chcp 65001"]
        }
    },
    "terminal.integrated.defaultProfile.windows": "PowerShell UTF-8"
}
```

### Étape 4: Création du fichier de test

```powershell
$testContent = @"
# Fichier de test UTF-8 - $(Get-Date)
Caractères français : àéèùç ÀÉÈÙÇ ôîâê
Caractères spéciaux : €£¥©®™§¶•…«»""''
Emojis : 🚀💻📁✅❌⚠️
Phrase : "L'été dernier, j'ai visité un château près de Montréal."
Mots avec accents : café, hôtel, naïf, coïncidence, être, créé, français
"@

$testContent | Out-File -FilePath "test-caracteres-francais.txt" -Encoding UTF8
```

## Validation

### Validation automatique

```powershell
# Validation standard
.\validate-deployment.ps1

# Validation détaillée
.\validate-deployment.ps1 -Detailed

# Validation avec génération de rapport
.\validate-deployment.ps1 -CreateReport
```

### Validation manuelle

1. **Redémarrer PowerShell**
2. **Vérifier l'encodage** :
   ```powershell
   [Console]::OutputEncoding.CodePage  # Doit être 65001
   $OutputEncoding.EncodingName        # Doit contenir "UTF-8"
   ```
3. **Tester l'affichage** :
   ```powershell
   echo "café hôtel naïf être créé français"
   ```
4. **Vérifier le fichier de test** :
   ```powershell
   Get-Content "test-caracteres-francais.txt"
   ```

### Critères de validation

| Test | Critère de réussite |
|------|-------------------|
| **Code Page** | 65001 (UTF-8) |
| **OutputEncoding** | UTF-8 |
| **Console.OutputEncoding** | UTF-8 |
| **Console.InputEncoding** | UTF-8 |
| **Affichage français** | Caractères corrects |
| **Profil PowerShell** | Configuration présente |

## Dépannage

### Problème 1: Caractères toujours mal affichés

**Symptômes** :
- Les caractères français apparaissent comme `ǭǽǜǾǸ`
- La validation échoue

**Solutions** :
1. Vérifier que PowerShell a été redémarré
2. Vérifier le profil PowerShell :
   ```powershell
   Test-Path $PROFILE
   Get-Content $PROFILE
   ```
3. Forcer la configuration manuellement :
   ```powershell
   chcp 65001
   [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
   ```

### Problème 2: Profil PowerShell non chargé

**Symptômes** :
- La configuration UTF-8 ne s'applique pas au démarrage
- `$PROFILE` est vide ou inexistant

**Solutions** :
1. Vérifier l'emplacement du profil :
   ```powershell
   $PROFILE
   ```
2. Créer le répertoire si nécessaire :
   ```powershell
   New-Item -Path (Split-Path $PROFILE) -ItemType Directory -Force
   ```
3. Re-exécuter le script de déploiement

### Problème 3: Erreurs de permissions

**Symptômes** :
- "Accès refusé" lors de la modification du profil
- Impossible de créer des fichiers

**Solutions** :
1. Vérifier les droits sur le répertoire utilisateur
2. Exécuter depuis un répertoire accessible en écriture
3. Utiliser un autre emplacement pour les fichiers temporaires

### Problème 4: VSCode ne respecte pas la configuration

**Symptômes** :
- Le terminal VSCode affiche mal les caractères
- La configuration n'est pas appliquée

**Solutions** :
1. Redémarrer VSCode complètement
2. Vérifier le fichier `.vscode/settings.json`
3. Sélectionner manuellement le profil "PowerShell UTF-8"
4. Vérifier les paramètres utilisateur VSCode

### Problème 5: Configuration perdue après mise à jour

**Symptômes** :
- La configuration disparaît après une mise à jour système
- Le profil PowerShell est réinitialisé

**Solutions** :
1. Restaurer depuis la sauvegarde :
   ```powershell
   .\restore-profile.ps1
   ```
2. Re-exécuter le déploiement :
   ```powershell
   .\apply-encoding-fix.ps1 -Force
   ```

## Désinstallation

### Méthode 1: Restauration automatique

```powershell
.\restore-profile.ps1
```

### Méthode 2: Suppression manuelle

1. **Supprimer la configuration UTF-8** du profil PowerShell
2. **Restaurer depuis la sauvegarde** :
   ```powershell
   $profilePath = "$env:USERPROFILE\OneDrive\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
   $backupPath = "$profilePath.backup-YYYYMMDD-HHMMSS"  # Remplacer par la date
   Copy-Item $backupPath $profilePath -Force
   ```
3. **Supprimer la configuration VSCode** (optionnel)
4. **Redémarrer PowerShell**

## FAQ

### Q: La solution fonctionne-t-elle avec PowerShell Core (7.x) ?

**R**: Oui, mais le chemin du profil est différent. Adaptez le script pour utiliser :
```powershell
$PROFILE.CurrentUserCurrentHost
```

### Q: Puis-je utiliser cette solution sur un serveur ?

**R**: Oui, mais testez d'abord sur un environnement de développement. Certains services peuvent être sensibles aux changements d'encodage.

### Q: La configuration affecte-t-elle les autres utilisateurs ?

**R**: Non, la configuration est spécifique à l'utilisateur courant.

### Q: Que faire si j'ai plusieurs profils PowerShell ?

**R**: Appliquez la configuration à tous les profils pertinents :
- `$PROFILE.CurrentUserCurrentHost`
- `$PROFILE.CurrentUserAllHosts`

### Q: La solution fonctionne-t-elle avec Windows Terminal ?

**R**: Oui, Windows Terminal respecte la configuration PowerShell. Vous pouvez également configurer l'encodage directement dans Windows Terminal.

### Q: Comment vérifier que la solution fonctionne dans un script ?

**R**: Utilisez le script de validation :
```powershell
$result = .\validate-deployment.ps1
if ($LASTEXITCODE -eq 0) {
    Write-Host "Configuration UTF-8 OK"
} else {
    Write-Host "Problème de configuration"
}
```

## Support et maintenance

### Fichiers de logs

Les scripts génèrent des informations de diagnostic. En cas de problème :

1. Exécutez avec `-Verbose`
2. Générez un rapport de validation
3. Consultez les sauvegardes créées

### Mise à jour de la solution

Pour mettre à jour :

1. Sauvegardez la configuration actuelle
2. Téléchargez la nouvelle version
3. Exécutez le nouveau script de déploiement avec `-Force`

### Contact et support

- **Documentation** : Ce guide et les fichiers README
- **Scripts** : Tous les scripts sont commentés et auto-documentés
- **Validation** : Utilisez `validate-deployment.ps1` pour diagnostiquer

---

**Note** : Cette solution a été testée sur Windows 10/11 avec PowerShell 5.1 et VSCode. Pour d'autres environnements, des adaptations peuvent être nécessaires.