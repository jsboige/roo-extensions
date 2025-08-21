# Scripts de Configuration (Setup)

Ce dossier contient des scripts conçus pour configurer l'environnement de développement local.

## Contexte de la Refactorisation

Les tâches de configuration de l'environnement étaient auparavant dispersées dans plusieurs scripts à travers le dépôt, notamment dans le dossier `../encoding`. Pour clarifier les intentions, toute la logique liée à la préparation de l'environnement de développement (configuration du profil PowerShell, de Git, etc.) a été centralisée ici.

## Script Principal

### `setup-encoding-workflow.ps1`

C'est l'outil unique pour configurer un environnement de développement afin qu'il respecte les bonnes pratiques d'encodage et les standards du projet. Il est destiné à être exécuté une fois par un développeur qui rejoint le projet.

#### Fonctionnalités

*   **Profil PowerShell :** Configure le profil PowerShell (`$PROFILE`) pour utiliser l'UTF-8 par défaut.
*   **Configuration Git :** Configure les paramètres globaux de Git pour gérer correctement l'encodage des commits et les fins de ligne.
*   **Hooks Git :** (Optionnel) Installe un hook `pre-commit` pour vérifier automatiquement l'encodage des fichiers avant chaque commit.
*   **Configuration VSCode :** (Optionnel) Crée ou met à jour le fichier `.vscode/settings.json` local pour forcer l'UTF-8 et les fins de ligne LF.
*   **Gestion du Profil :** Inclut des fonctions pour sauvegarder (`-BackupProfile`) et restaurer (`-RestoreProfile`) facilement le profil PowerShell.

#### Utilisation

**Pour une configuration complète :**
```powershell
.\setup-encoding-workflow.ps1
```

**Pour sauvegarder votre profil PowerShell avant une modification manuelle :**
```powershell
.\setup-encoding-workflow.ps1 -BackupProfile