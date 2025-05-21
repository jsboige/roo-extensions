# Tests du MCP GitHub Projects

Ce répertoire contient des scripts et de la documentation pour tester le MCP GitHub Projects.

## Configuration requise

- PowerShell 5.1 ou supérieur
- Accès au MCP CLI (généralement installé avec Roo)
- Token GitHub avec les permissions appropriées (déjà configuré dans `mcp_settings.json`)

## Structure des fichiers

- `test-github-projects.ps1` : Script principal de test des fonctionnalités du MCP GitHub Projects
- `README.md` : Documentation du processus de test
- `results.md` : Résultats des tests (généré après exécution)

## Fonctionnalités testées

Le script teste les fonctionnalités suivantes du MCP GitHub Projects :

1. **list_projects** : Liste les projets d'un utilisateur ou d'une organisation
   - Vérifie que la liste des projets est récupérée correctement
   - Affiche les informations de base sur chaque projet

2. **get_project** : Obtient les détails d'un projet spécifique
   - Vérifie que les détails du projet sont récupérés correctement
   - Affiche les informations détaillées du projet, y compris ses champs

## Utilisation

1. Ouvrir PowerShell
2. Naviguer vers le répertoire contenant le script
3. Modifier les paramètres de test dans le script si nécessaire (propriétaire, type de propriétaire)
4. Exécuter le script :

```powershell
.\test-github-projects.ps1
```

## Interprétation des résultats

- Les messages avec le niveau "SUCCESS" indiquent que le test a réussi
- Les messages avec le niveau "WARNING" indiquent un problème potentiel
- Les messages avec le niveau "ERROR" indiquent un échec du test

## Dépannage

Si vous rencontrez des erreurs lors de l'exécution des tests :

1. Vérifiez que le MCP GitHub Projects est correctement configuré dans `mcp_settings.json`
2. Assurez-vous que le token GitHub est valide et dispose des permissions nécessaires
3. Vérifiez que le propriétaire (utilisateur ou organisation) spécifié dans le script existe et possède des projets
4. Vérifiez que le MCP CLI est accessible à l'emplacement spécifié dans le script

## Notes

- Le script utilise le MCP CLI pour communiquer avec le MCP GitHub Projects
- Les résultats des tests sont affichés dans la console et peuvent être redirigés vers un fichier si nécessaire