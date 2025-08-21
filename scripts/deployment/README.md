# Scripts de Déploiement

Ce dossier contient le script PowerShell consolidé pour déployer les configurations des "Modes" MCP.

## Contexte de la Refactorisation

Auparavant, ce dossier contenait de multiples scripts de déploiement avec des fonctionnalités redondantes. Dans le cadre d'une initiative de refactorisation, tous ces scripts ont été fusionnés en un seul outil puissant et paramétrable : `deploy-modes.ps1`.

## Script Principal

### `deploy-modes.ps1`

C'est le point d'entrée unique pour toutes les opérations de déploiement. Il gère le déploiement des modes depuis les fichiers de configuration source (ex: `roo-modes/configs/*.json`) vers les répertoires cibles de l'application.

#### Fonctionnalités

*   **Déploiement Ciblé :** Peut déployer des fichiers de configuration spécifiques.
*   **Types de Déploiement :** Supporte différents types de déploiement (probablement `global` pour l'utilisateur et `local` pour un projet).
*   **Validation Intégrée :** Peut lancer des scripts de validation après le déploiement pour s'assurer de l'intégrité de la configuration.
*   **Gestion des Sauvegardes :** Crée des sauvegardes avant de surécrire les configurations existantes.

#### Utilisation

L'utilisation de base consiste à exécuter le script. Des paramètres permettent de contrôler son comportement.

**Exemple de déploiement standard :**
```powershell
.\deploy-modes.ps1 -SourcePath "..\roo-modes\configs\standard-modes.json"
```

**Exemple de déploiement avec validation post-déploiement :**
```powershell
.\deploy-modes.ps1 -SourcePath "..\roo-modes\configs\standard-modes.json" -Validate