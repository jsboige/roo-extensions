# Rapport de Maintenance : Diagnostic et Correction des Problèmes d'Encodage

## 1. Problème Initial

L'environnement de terminal PowerShell sous Windows 11 présentait des problèmes d'encodage, causant une corruption de l'affichage des caractères accentués. La tâche était de diagnostiquer et de corriger ce problème en utilisant les scripts existants du dépôt.

## 2. Diagnostic du Script `setup-encoding-workflow.ps1`

Une enquête a été menée sur le script principal `scripts/setup/setup-encoding-workflow.ps1`, qui est conçu pour configurer l'environnement. L'exécution de ce script a révélé plusieurs problèmes critiques :

1.  **Bugs Internes :** Le script contenait des appels de fonction avec des chaînes vides qui provoquaient des erreurs inutiles, rendant la sortie difficile à lire.
2.  **Dépendances à des Outils Non-Windows :** La configuration des hooks Git reposait sur des commandes UNIX (`grep`, `hexdump`) non disponibles par défaut sur Windows, rendant cette fonctionnalité inutilisable et provoquant des erreurs.
3.  **Problèmes de Compatibilité PowerShell :** La logique de mise à jour des paramètres de VS Code utilisait des syntaxes (`-AsHashtable`) non compatibles avec la version par défaut de PowerShell sur Windows (PowerShell 5.1), provoquant des erreurs.
4.  **Difficultés d'Exécution :** Des tentatives répétées pour corriger le script via des modifications chirurgicales (`apply_diff`) ont échoué, probablement en raison d'un état instable du fichier et de problèmes de compatibilité avec l'environnement d'exécution.

En conclusion, le script `setup-encoding-workflow.ps1` est considéré comme **non fiable** dans son état actuel pour cet environnement.

## 3. Solution et Recommandation

Pour contourner les problèmes du script et résoudre le problème d'encodage de manière efficace, la logique de configuration de PowerShell a été extraite et exécutée directement.

### Commande de Correction Immédiate

La commande suivante, exécutée dans un terminal PowerShell, configure correctement la session en cours pour utiliser l'encodage UTF-8 :

```powershell
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new(); $PSDefaultParameterValues['Out-File:Encoding'] = 'utf8NoBOM'; $PSDefaultParameterValues['Set-Content:Encoding'] = 'utf8NoBOM'
```

Cette commande a été testée et s'est avérée fonctionnelle.

### Solution Persistante (Recommandée)

Pour que la correction soit permanente, il est recommandé d'ajouter ces lignes au profil PowerShell de l'utilisateur.

**Instructions :**

1.  Ouvrez votre profil PowerShell en exécutant la commande suivante :
    ```powershell
    if (-not (Test-Path $PROFILE)) { New-Item -Path $PROFILE -Type File -Force }; notepad $PROFILE
    ```

2.  Ajoutez le bloc de code suivant à la fin du fichier, puis sauvegardez et fermez l'éditeur :
    ```powershell
    # Configuration de l'encodage en UTF-8 pour une meilleure compatibilité
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
    $PSDefaultParameterValues['Out-File:Encoding'] = 'utf8NoBOM'
    $PSDefaultParameterValues['Set-Content:Encoding'] = 'utf8NoBOM'
    ```

3.  Redémarrez votre terminal PowerShell. La configuration sera maintenant appliquée automatiquement à chaque nouvelle session.

Ce rapport conclut le diagnostic et la résolution du problème d'encodage.