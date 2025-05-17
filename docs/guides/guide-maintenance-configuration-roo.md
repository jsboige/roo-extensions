# Guide de maintenance et mise à jour de la configuration Roo

Ce guide complet explique comment utiliser les différents scripts et outils du projet roo-extensions pour maintenir et mettre à jour la configuration de Roo. Il couvre les workflows complets pour les tâches courantes de maintenance et fournit des exemples concrets de commandes à exécuter.

## Table des matières

1. [Introduction](#introduction)
2. [Structure des outils](#structure-des-outils)
3. [Workflows de maintenance](#workflows-de-maintenance)
   - [Mise à jour des commandes autorisées](#mise-à-jour-des-commandes-autorisées)
   - [Ajout ou modification de modes personnalisés](#ajout-ou-modification-de-modes-personnalisés)
   - [Mise à jour des configurations d'API](#mise-à-jour-des-configurations-dapi)
   - [Correction des problèmes d'encodage](#correction-des-problèmes-dencodage)
   - [Déploiement des mises à jour](#déploiement-des-mises-à-jour)
4. [Dépannage](#dépannage)
5. [Références](#références)

## Introduction

Le projet roo-extensions fournit un ensemble d'outils pour maintenir et mettre à jour la configuration de Roo sur Windows. Ces outils permettent de gérer les modes, corriger les problèmes d'encodage, déployer les configurations et diagnostiquer les problèmes courants.

La maintenance de la configuration Roo implique plusieurs aspects :
- Gestion des modes (standard et personnalisés)
- Correction des problèmes d'encodage (caractères accentués, emojis)
- Déploiement des configurations (global ou local)
- Diagnostic et vérification des configurations

Ce guide vous aidera à comprendre comment utiliser efficacement les différents scripts et outils disponibles pour maintenir votre configuration Roo à jour et fonctionnelle.

## Structure des outils

Les outils de maintenance sont organisés en plusieurs dossiers dans le répertoire `roo-config` :

- **`encoding-scripts/`** - Scripts de correction d'encodage
- **`deployment-scripts/`** - Scripts de déploiement des modes
- **`diagnostic-scripts/`** - Scripts de diagnostic et vérification
- **`config-templates/`** - Modèles de fichiers de configuration
- **`docs/`** - Documentation supplémentaire
- **`modes/`** - Fichiers de modes standards
- **`qwen3-profiles/`** - Profils pour le modèle Qwen3
- **`scheduler/`** - Configuration du planificateur
- **`settings/`** - Paramètres de configuration
- **`backups/`** - Fichiers de sauvegarde

Chaque dossier contient des scripts spécialisés pour des tâches spécifiques, avec une documentation détaillée dans les fichiers README.md correspondants.

## Workflows de maintenance

### Mise à jour des commandes autorisées

Les commandes autorisées pour Roo sont définies dans les fichiers de configuration des modes. Pour les mettre à jour, suivez ces étapes :

1. **Vérifier les fichiers de configuration actuels**

   ```powershell
   # Examiner la configuration actuelle des modes
   Get-Content -Path "roo-config/settings/modes.json"
   ```

2. **Modifier les commandes autorisées**

   Ouvrez le fichier `roo-config/settings/modes.json` dans un éditeur de texte et modifiez la section `allowedCommands` pour chaque mode concerné.

3. **Vérifier l'encodage du fichier modifié**

   ```powershell
   # Vérifier l'encodage après modification
   .\roo-config\diagnostic-scripts\diagnostic-rapide-encodage.ps1 -FilePath "roo-config/settings/modes.json"
   ```

4. **Déployer les modifications**

   ```powershell
   # Déployer les modifications
   .\roo-config\deployment-scripts\simple-deploy.ps1
   ```

5. **Vérifier le déploiement**

   ```powershell
   # Vérifier que les modifications ont été correctement déployées
   .\roo-config\diagnostic-scripts\verify-deployed-modes.ps1
   ```

### Ajout ou modification de modes personnalisés

Pour ajouter ou modifier des modes personnalisés, suivez ces étapes :

1. **Créer ou modifier un fichier de configuration de mode**

   Créez un nouveau fichier JSON dans le dossier `roo-modes/configs/` ou modifiez un fichier existant. Vous pouvez utiliser les modèles disponibles dans `roo-config/config-templates/` comme base.

   ```powershell
   # Copier un modèle existant comme base
   Copy-Item -Path "roo-config/config-templates/modes.json" -Destination "roo-modes/configs/custom-modes.json"
   ```

2. **Éditer le fichier de configuration**

   Modifiez le fichier pour définir vos modes personnalisés. Assurez-vous de respecter la structure JSON et d'utiliser un encodage UTF-8 sans BOM.

3. **Vérifier l'encodage et la validité du JSON**

   ```powershell
   # Vérifier l'encodage et la validité du JSON
   .\roo-config\diagnostic-scripts\diagnostic-rapide-encodage.ps1 -FilePath "roo-modes/configs/custom-modes.json"
   ```

4. **Corriger les problèmes d'encodage si nécessaire**

   ```powershell
   # Corriger les problèmes d'encodage
   .\roo-config\encoding-scripts\fix-encoding-complete.ps1 -SourcePath "roo-modes/configs/custom-modes.json"
   ```

5. **Déployer les modes personnalisés**

   ```powershell
   # Déployer les modes personnalisés
   .\roo-config\deployment-scripts\deploy-modes-simple-complex.ps1 -SourcePath "roo-modes/configs/custom-modes.json" -Force
   ```

6. **Vérifier le déploiement**

   ```powershell
   # Vérifier le déploiement
   .\roo-config\diagnostic-scripts\verify-deployed-modes.ps1
   ```

### Mise à jour des configurations d'API

Pour mettre à jour les configurations d'API et des serveurs MCP, suivez ces étapes :

1. **Examiner la configuration actuelle des serveurs**

   ```powershell
   # Examiner la configuration actuelle des serveurs
   Get-Content -Path "roo-config/settings/servers.json"
   ```

2. **Modifier la configuration des serveurs**

   Ouvrez le fichier `roo-config/settings/servers.json` dans un éditeur de texte et modifiez les paramètres selon vos besoins.

3. **Vérifier l'encodage du fichier modifié**

   ```powershell
   # Vérifier l'encodage après modification
   .\roo-config\diagnostic-scripts\diagnostic-rapide-encodage.ps1 -FilePath "roo-config/settings/servers.json"
   ```

4. **Déployer la configuration mise à jour**

   ```powershell
   # Déployer la configuration mise à jour
   .\roo-config\settings\deploy-settings.ps1
   ```

5. **Vérifier le déploiement**

   ```powershell
   # Vérifier que les modifications ont été correctement déployées
   Get-Content -Path "$env:APPDATA\Roo-Code\servers.json"
   ```

### Correction des problèmes d'encodage

Les problèmes d'encodage sont courants lors de la manipulation des fichiers JSON contenant des caractères accentués ou des emojis. Pour les corriger, suivez ces étapes :

1. **Diagnostiquer les problèmes d'encodage**

   ```powershell
   # Diagnostiquer les problèmes d'encodage dans un fichier
   .\roo-config\diagnostic-scripts\diagnostic-rapide-encodage.ps1 -FilePath "chemin\vers\fichier.json" -Verbose
   ```

2. **Corriger automatiquement les problèmes simples**

   ```powershell
   # Corriger automatiquement les problèmes d'encodage
   .\roo-config\diagnostic-scripts\diagnostic-rapide-encodage.ps1 -FilePath "chemin\vers\fichier.json" -Fix
   ```

3. **Pour les problèmes plus complexes, utiliser les scripts spécialisés**

   ```powershell
   # Correction complète des problèmes d'encodage
   .\roo-config\encoding-scripts\fix-encoding-complete.ps1 -SourcePath "chemin\vers\fichier.json"
   
   # Pour les cas très complexes
   .\roo-config\encoding-scripts\fix-encoding-advanced.ps1 -SourcePath "chemin\vers\fichier.json" -CreateBackup $true
   ```

4. **Vérifier que le fichier est toujours valide après correction**

   ```powershell
   # Vérifier la validité du JSON après correction
   Get-Content -Path "chemin\vers\fichier.json" -Raw | ConvertFrom-Json
   ```

### Déploiement des mises à jour

Pour déployer les mises à jour de configuration, suivez ces étapes :

1. **Déploiement simple et rapide**

   ```powershell
   # Déploiement rapide avec l'option force
   .\roo-config\deployment-scripts\simple-deploy.ps1
   ```

2. **Déploiement avec plus d'options**

   ```powershell
   # Déploiement global avec vérification
   .\roo-config\deployment-scripts\deploy-modes-simple-complex.ps1 -DeploymentType "global" -TestAfterDeploy
   
   # Déploiement local pour un projet spécifique
   .\roo-config\deployment-scripts\deploy-modes-simple-complex.ps1 -DeploymentType "local" -Force
   ```

3. **Déploiement guidé interactif**

   ```powershell
   # Déploiement guidé avec vérification d'encodage
   .\roo-config\deployment-scripts\deploy-guide-interactif.ps1
   ```

4. **Vérifier le déploiement**

   ```powershell
   # Vérifier que les modes ont été correctement déployés
   .\roo-config\diagnostic-scripts\verify-deployed-modes.ps1
   ```

5. **Redémarrer Visual Studio Code**

   Après le déploiement, redémarrez Visual Studio Code pour que les modifications prennent effet.

## Dépannage

Si vous rencontrez des problèmes lors de la maintenance ou du déploiement, voici quelques étapes de dépannage :

1. **Problèmes d'encodage persistants**

   ```powershell
   # Utiliser le script de diagnostic avancé
   .\roo-config\diagnostic-scripts\encoding-diagnostic.ps1 -FilePath "chemin\vers\fichier.json"
   
   # Essayer la correction finale optimisée
   .\roo-config\encoding-scripts\fix-encoding-final.ps1 -SourcePath "chemin\vers\fichier.json"
   ```

2. **Échec du déploiement**

   ```powershell
   # Forcer le déploiement avec correction d'encodage
   .\roo-config\deployment-scripts\force-deploy-with-encoding-fix.ps1
   ```

3. **Restaurer une sauvegarde**

   ```powershell
   # Restaurer une sauvegarde
   Copy-Item -Path "roo-config/backups/modes.json.bak" -Destination "roo-config/settings/modes.json" -Force
   ```

4. **Nettoyer les anciennes sauvegardes**

   ```powershell
   # Supprimer les sauvegardes de plus de 30 jours
   Get-ChildItem -Path "roo-config/backups" -Filter "*.bak" | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } | Remove-Item -Force
   ```

## Références

- [Guide d'encodage pour Windows](../../docs/guides/guide-encodage-windows.md)
- [Rapport final de déploiement](../../docs/rapports/rapport-final-deploiement-modes-windows.md)
- [Guide d'import/export](../../roo-config/docs/guide-import-export.md)
- [Guide de configuration des MCP](../../docs/guide-configuration-mcps.md)
- [Rapport de synthèse des modes Roo](../../docs/rapport-synthese-modes-roo.md)