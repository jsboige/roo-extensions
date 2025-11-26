# Documentation Technique : Configuration Unifiée des Profils PowerShell

## 1. Vue d'ensemble

Ce document décrit la stratégie de configuration unifiée des profils PowerShell pour garantir un environnement d'exécution cohérent et compatible UTF-8 sur toutes les versions de PowerShell (5.1 et 7+).

### 1.1 Objectifs
- Assurer l'encodage UTF-8 par défaut pour toutes les sessions PowerShell.
- Fournir une expérience utilisateur cohérente entre Windows PowerShell (5.1) et PowerShell Core (7+).
- Centraliser la logique d'initialisation pour faciliter la maintenance.

## 2. Architecture

L'architecture repose sur un script d'initialisation central appelé par les profils spécifiques à chaque version.

### 2.1 Composants
1.  **Initialize-EncodingManager.ps1** : Script central qui configure l'encodage (OutputEncoding, Console.OutputEncoding) et les préférences globales.
2.  **Templates de Profils** :
    *   `Microsoft.PowerShell_profile.ps1` : Pour PowerShell 5.1.
    *   `Microsoft.PowerShell_profile_v7.ps1` : Pour PowerShell 7+.
3.  **Scripts de Déploiement** : `Configure-PowerShellProfiles.ps1` installe les profils et gère les sauvegardes.

### 2.2 Flux d'Exécution
1.  L'utilisateur lance PowerShell.
2.  PowerShell charge le profil correspondant (`$PROFILE`).
3.  Le profil source (`.`) le script `Initialize-EncodingManager.ps1`.
4.  `Initialize-EncodingManager.ps1` détecte la version et applique la configuration UTF-8 appropriée.

## 3. Configuration de l'Encodage

### 3.1 PowerShell 5.1 vs 7+
*   **PowerShell 5.1** : Nécessite une configuration explicite de `[Console]::OutputEncoding` et `$OutputEncoding` vers UTF-8 avec BOM pour une compatibilité maximale avec les anciens outils Windows.
*   **PowerShell 7+** : Utilise UTF-8 sans BOM par défaut, mais la configuration est renforcée pour garantir la cohérence (CodePage 65001).

### 3.2 Variables d'Environnement
Le script d'initialisation définit également des variables d'environnement critiques si elles sont absentes :
*   `PYTHONIOENCODING = utf-8`
*   `LANG = fr_FR.UTF-8`

## 4. Déploiement et Maintenance

### 4.1 Installation
Exécuter le script de déploiement :
```powershell
.\scripts\encoding\Configure-PowerShellProfiles.ps1
```
Utiliser le paramètre `-Force` pour écraser les profils existants (une sauvegarde est toujours créée).

### 4.2 Validation
Vérifier la configuration avec :
```powershell
.\scripts\encoding\Test-PowerShellProfiles.ps1
```

### 4.3 Personnalisation
Les utilisateurs peuvent ajouter leurs propres alias et fonctions dans les fichiers de profil installés dans `Documents\WindowsPowerShell\` ou `Documents\PowerShell\`. La section d'initialisation de l'encodage doit être conservée en début de fichier.

## 5. Dépannage

*   **Problème** : Caractères accentués mal affichés.
    *   **Solution** : Vérifier que la police du terminal supporte les caractères (ex: Cascadia Code) et que `[Console]::OutputEncoding.CodePage` est bien 65001.
*   **Problème** : Erreur "EncodingManager introuvable".
    *   **Solution** : Vérifier le chemin dans le profil. Le script tente de localiser `Initialize-EncodingManager.ps1` relativemement au profil ou dans `d:\roo-extensions`.

## 6. Historique des Modifications

| Date | Version | Auteur | Description |
| :--- | :--- | :--- | :--- |
| 2025-10-30 | 1.0 | Roo Architect | Création initiale |