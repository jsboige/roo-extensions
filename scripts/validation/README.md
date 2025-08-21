# Scripts de Validation

Ce dossier contient des scripts dont le but est de valider l'état fonctionnel et métier de la configuration de l'application Roo.

## Contexte de la Refactorisation

Ce dossier a été créé pour héberger des scripts de validation qui étaient auparavant mélangés avec des outils de diagnostic technique dans le dossier `../diagnostic`. Cette séparation clarifie la différence entre :

-   **Diagnostic (dans `../diagnostic`) :** Vérifications techniques et de bas niveau (ex: "le fichier est-il un JSON valide ?", "le chemin X existe-t-il ?").
-   **Validation (ici) :** Vérifications fonctionnelles et de haut niveau (ex: "la configuration des modes déployés est-elle cohérente ?", "la configuration MCP respecte-t-elle les règles métier ?").

## Scripts Principaux

### `validate-deployed-modes.ps1`

Ce script vérifie que les "Modes" MCP ont été correctement déployés et sont fonctionnels. Il se concentre sur l'état final après qu'un script de déploiement a été exécuté.

### `validate-mcp-config.ps1`

Ce script analyse le contenu des fichiers de configuration MCP pour s'assurer qu'ils respectent les règles et les conventions établies (ex: structure correcte, paramètres obligatoires présents, etc.).

### Utilisation

Ces scripts sont généralement appelés après des opérations de déploiement ou de configuration pour s'assurer que tout s'est bien passé. Ils peuvent également faire partie d'un workflow de CI/CD.

**Pour valider l'état des modes actuellement déployés :**
```powershell
.\validate-deployed-modes.ps1
```

**Pour vérifier la cohérence d'un fichier de configuration avant déploiement :**
```powershell
.\validate-mcp-config.ps1 -Path "..\roo-modes\configs\standard-modes.json"