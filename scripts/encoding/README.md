# Scripts d'Encodage

Ce dossier contient les outils liés à la gestion et à la correction de l'encodage des fichiers texte dans le projet.

## Contexte de la Refactorisation

Auparavant, de nombreux scripts coexistaient pour effectuer deux tâches distinctes :
1.  **Configurer l'environnement** PowerShell pour qu'il utilise UTF-8.
2.  **Corriger le contenu** de fichiers mal encodés.

Cette séparation n'était pas claire. La refactorisation a permis de :
-   Déplacer toute la logique de **configuration de l'environnement** vers le script `../setup/setup-encoding-workflow.ps1`.
-   Consolider tous les scripts de **correction de contenu** en un seul outil.

## Script Principal

### `fix-file-encoding.ps1`

C'est l'outil unique pour réparer le contenu des fichiers texte (JSON, MD, etc.) qui ont été corrompus par des problèmes d'encodage (souvent appelés "mojibake").

#### Fonctionnalités

*   **Correction Intelligente :** Utilise une table de correspondance pour remplacer les séquences de caractères erronées (ex: `Ã©`) par leur équivalent correct (ex: `é`).
*   **Traitement en Masse :** Peut traiter un seul fichier, ou un ensemble de fichiers dans un répertoire de manière récursive en utilisant les paramètres `-Path`, `-Include`, et `-Recurse`.
*   **Sécurité :** Crée automatiquement une sauvegarde (`.bak`) de chaque fichier avant de le modifier.
*   **Mode Simulation :** Inclut un paramètre `-WhatIf` pour voir quels fichiers seraient modifiés sans appliquer les changements.
*   **Validation JSON :** Tente de valider la structure JSON des fichiers `.json` après correction.

#### Utilisation

**Pour corriger un fichier unique :**
```powershell
.\fix-file-encoding.ps1 -Path ".\chemin\vers\fichier-corrompu.json"
```

**Pour simuler la correction de tous les fichiers Markdown dans le dossier `docs` :**
```powershell
.\fix-file-encoding.ps1 -Path "..\..\docs" -Include "*.md" -Recurse -WhatIf