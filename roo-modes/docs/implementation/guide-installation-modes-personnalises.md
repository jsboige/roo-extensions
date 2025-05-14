# Guide d'installation des modes personnalisés pour Roo

Ce guide détaille la procédure pour installer et configurer des modes personnalisés dans l'extension Roo pour Visual Studio Code.

## Prérequis

- Visual Studio Code installé
- Extension Roo installée et configurée
- PowerShell 5.1 ou supérieur (pour Windows) ou PowerShell Core (pour macOS/Linux)

## Structure des fichiers de configuration

Les modes personnalisés sont définis dans un fichier JSON avec la structure suivante :

```json
{
  "modes": [
    {
      "slug": "nom-technique-du-mode",
      "name": "🔧 Nom Affiché du Mode",
      "model": "anthropic/claude-3.7-sonnet",
      "description": "Description du mode personnalisé",
      "system_prompt": "Instructions système pour le mode",
      "allowed_file_patterns": [".*\\.js$", ".*\\.ts$"],
      "restricted_file_patterns": [".*\\.env$"]
    }
  ]
}
```

### Propriétés obligatoires

- `slug` : Identifiant technique unique du mode (sans espaces ni caractères spéciaux)
- `name` : Nom affiché dans l'interface utilisateur (peut inclure des émojis)
- `model` : Modèle d'IA à utiliser (ex: "anthropic/claude-3.7-sonnet")
- `system_prompt` : Instructions système qui définissent le comportement du mode

### Propriétés optionnelles

- `description` : Description détaillée du mode
- `allowed_file_patterns` : Liste des patterns regex pour les fichiers que ce mode peut modifier
- `restricted_file_patterns` : Liste des patterns regex pour les fichiers que ce mode ne peut pas modifier

## Méthodes d'installation

### 1. Installation manuelle

1. Ouvrez le fichier `settings.json` de VS Code :
   - Windows : `%APPDATA%\Code\User\settings.json`
   - macOS : `~/Library/Application Support/Code/User/settings.json`
   - Linux : `~/.config/Code/User/settings.json`

2. Ajoutez ou modifiez la section `roo.modes` :
   ```json
   {
     "roo.modes": [
       {
         "slug": "votre-mode-personnalise",
         "name": "🔧 Votre Mode Personnalisé",
         "model": "anthropic/claude-3.7-sonnet",
         "description": "Description de votre mode",
         "system_prompt": "Instructions système pour votre mode",
         "allowed_file_patterns": [".*\\.js$", ".*\\.ts$"],
         "restricted_file_patterns": [".*\\.env$"]
       }
     ]
   }
   ```

3. Sauvegardez le fichier et redémarrez VS Code

### 2. Installation via le script PowerShell

Nous fournissons un script PowerShell `deploy-roo-modes.ps1` qui automatise l'installation des modes personnalisés.

#### Utilisation de base

```powershell
.\roo-modes\scripts\deploy-roo-modes.ps1 -ConfigPath ".\roo-modes\examples\anonymized-custom-modes.json"
```

#### Options du script

- `-ConfigPath` : Chemin vers le fichier JSON contenant les modes personnalisés
- `-TargetPath` : (Optionnel) Chemin vers le fichier settings.json de VS Code
- `-Backup` : (Optionnel) Crée une sauvegarde du fichier settings.json avant modification (par défaut: $true)
- `-Merge` : (Optionnel) Fusionne les modes avec ceux existants au lieu de les remplacer (par défaut: $false)
- `-Force` : (Optionnel) Force l'opération même en cas d'erreurs non critiques (par défaut: $false)

#### Exemples d'utilisation

Déployer avec fusion des modes existants :
```powershell
.\roo-modes\scripts\deploy-roo-modes.ps1 -ConfigPath ".\roo-modes\examples\anonymized-custom-modes.json" -Merge
```

Déployer sans créer de sauvegarde :
```powershell
.\roo-modes\scripts\deploy-roo-modes.ps1 -ConfigPath ".\roo-modes\examples\anonymized-custom-modes.json" -Backup:$false
```

Spécifier un chemin cible personnalisé :
```powershell
.\roo-modes\scripts\deploy-roo-modes.ps1 -ConfigPath ".\roo-modes\examples\anonymized-custom-modes.json" -TargetPath "C:\chemin\vers\settings.json"
```

## Bonnes pratiques

### Sécurité

- Ne stockez jamais d'informations sensibles (clés API, tokens, etc.) dans les prompts système
- Utilisez `restricted_file_patterns` pour empêcher la modification de fichiers sensibles
- Créez toujours une sauvegarde avant de modifier la configuration

### Performance

- Limitez le nombre de modes personnalisés pour éviter de surcharger l'interface
- Optimisez les prompts système pour être concis mais efficaces
- Choisissez le modèle approprié selon les besoins (les modèles plus puissants consomment plus de ressources)

### Organisation

- Utilisez des émojis cohérents pour faciliter l'identification visuelle des modes
- Groupez les modes par fonction ou domaine d'expertise
- Documentez clairement le but et les capacités de chaque mode

## Dépannage

### Problèmes courants

1. **Les modes ne s'affichent pas dans Roo**
   - Vérifiez que le format JSON est valide
   - Redémarrez VS Code après l'installation
   - Vérifiez que la section `roo.modes` est correctement formatée

2. **Erreurs lors de l'exécution du script**
   - Vérifiez que PowerShell est exécuté avec les droits suffisants
   - Assurez-vous que le chemin vers le fichier de configuration est correct
   - Vérifiez que le fichier settings.json est accessible en écriture

3. **Le mode ne fonctionne pas comme prévu**
   - Vérifiez le prompt système pour vous assurer qu'il est clair et précis
   - Assurez-vous que le modèle spécifié est disponible dans votre installation

## Ressources additionnelles

- [Documentation officielle de Roo](https://docs.roo.ai)
- [Exemples de modes personnalisés](https://github.com/roo-ai/custom-modes-examples)
- [Forum de support Roo](https://community.roo.ai)

---

Pour toute question ou assistance supplémentaire, n'hésitez pas à consulter la documentation ou à contacter l'équipe de support.