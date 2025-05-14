# Modes Roo

Ce dossier contient tous les modes Roo, y compris:

- **n5/**: Modes Roo avec architecture à 5 niveaux (anciennement roo-modes-n5)
- **custom/**: Modes personnalisés (anciennement custom-modes)
- **optimized/**: Agents optimisés (anciennement optimized-agents)

## Structure

- **configs/**: Fichiers de configuration pour les modes
- **docs/**: Documentation sur les modes
- **examples/**: Exemples d'utilisation
- **scripts/**: Scripts utilitaires pour les modes

## Nouveaux fichiers

- **docs/implementation/guide-installation-modes-personnalises.md**: Guide détaillé pour l'installation et la configuration des modes personnalisés
- **scripts/deploy-roo-modes.ps1**: Script PowerShell pour déployer automatiquement des modes personnalisés
- **examples/anonymized-custom-modes.json**: Exemple de configuration de modes personnalisés anonymisés

## Utilisation

Pour installer des modes personnalisés, vous pouvez utiliser le script de déploiement :

```powershell
.\roo-modes\scripts\deploy-roo-modes.ps1 -ConfigPath ".\roo-modes\examples\anonymized-custom-modes.json"
```

Pour plus de détails, consultez le [guide d'installation des modes personnalisés](docs/implementation/guide-installation-modes-personnalises.md).
