# Configuration Roo

Ce répertoire centralise toutes les configurations pour l'assistant IA Roo, permettant une gestion unifiée des paramètres, modes, et fonctionnalités avancées. Il fournit les fichiers de configuration et les scripts de déploiement nécessaires pour personnaliser l'expérience Roo selon vos besoins.

## Objectif général

Le répertoire `roo-config/` a pour objectif de :

- Centraliser les configurations de Roo dans un emplacement unique
- Fournir des scripts de déploiement pour faciliter l'installation
- Offrir des exemples et des modèles de configuration
- Permettre la personnalisation des modes, paramètres et comportements de Roo
- Faciliter la migration et la synchronisation des configurations entre différentes machines

## Structure du répertoire

### Sous-répertoires principaux

- **settings/**: Paramètres généraux de Roo (anciennement roo-settings)
  - Configuration globale de l'assistant
  - Paramètres d'autorisation et de sécurité
  - Configuration du terminal et du navigateur
  - Association entre modes et profils d'API

- **modes/**: Configurations des modes personnalisés
  - Définition des modes standard et personnalisés
  - Paramètres spécifiques à chaque mode
  - Instructions personnalisées pour les différents modes

- **scheduler/**: Configuration du planificateur Roo
  - Guides d'installation et de configuration
  - Documentation pour l'automatisation des tâches

- **exemple-config/**: Exemples de configuration
  - Modèles de fichiers config.json, modes.json et servers.json
  - Exemples de configuration pour différents cas d'utilisation

- **qwen3-profiles/**: Profils pour les modèles Qwen 3
  - Paramètres optimisés pour les différents modèles Qwen
  - Documentation sur l'intégration avec l'architecture N5

### Fichiers de configuration importants

- **model-configs.json**: Configuration des modèles d'IA utilisés par Roo
- **settings/settings.json**: Paramètres globaux de Roo
- **settings/modes.json**: Association entre modes et profils d'API
- **settings/servers.json**: Configuration des serveurs MCP
- **modes/standard-modes.json**: Définition des modes standard

### Scripts de déploiement

- **deploy-modes.ps1**: Script PowerShell pour déployer les configurations de modes
  ```powershell
  .\deploy-modes.ps1 [-ConfigFile <chemin>] [-DeploymentType <global|local>] [-Force]
  ```

- **deploy-modes-enhanced.ps1**: Version améliorée avec options supplémentaires
  ```powershell
  .\deploy-modes-enhanced.ps1 [-ConfigFile <chemin>] [-DeploymentType <global|local>] [-Force] [-PrepareGitInstructions] [-TestAfterDeploy]
  ```

- **settings/deploy-settings.ps1**: Script pour déployer les paramètres généraux
  ```powershell
  .\deploy-settings.ps1 [-ConfigFile <chemin>] [-Force]
  ```

### Scripts utilitaires

- **encoding-diagnostic.ps1**: Diagnostic d'encodage des fichiers de configuration
- **fix-encoding.ps1**: Correction des problèmes d'encodage dans les fichiers

### Documentation

- **guide-import-export.md**: Guide pour exporter/importer les configurations entre machines
- **REDIRECTION.md**: Information sur la migration vers le nouveau répertoire `roo-modes`
- **scheduler/Guide_Installation_Roo_Scheduler.md**: Guide d'installation du planificateur
- **scheduler/Guide_Edition_Directe_Configurations_Roo_Scheduler.md**: Guide d'édition des configurations du planificateur

## Utilisation des scripts de déploiement

### Déploiement des modes

Le script `deploy-modes.ps1` permet de déployer une configuration de modes soit globalement (pour toutes les instances de VS Code), soit localement (pour un projet spécifique).

#### Syntaxe

```powershell
.\deploy-modes.ps1 [-ConfigFile <chemin>] [-DeploymentType <global|local>] [-Force]
```

#### Paramètres

- `-ConfigFile` : Chemin du fichier de configuration à déployer (relatif au répertoire `roo-config/`)
  - Par défaut : `modes/standard-modes.json`

- `-DeploymentType` : Type de déploiement
  - `global` : Déploie la configuration pour toutes les instances de VS Code
  - `local` : Déploie la configuration uniquement pour le projet courant
  - Par défaut : `global`

- `-Force` : Force le remplacement du fichier de destination sans demander de confirmation

#### Exemples

1. Déployer la configuration standard globalement :
   ```powershell
   .\deploy-modes.ps1
   ```

2. Déployer une configuration personnalisée localement :
   ```powershell
   .\deploy-modes.ps1 -ConfigFile modes/my-custom-modes.json -DeploymentType local
   ```

### Déploiement des paramètres généraux

Le script `settings/deploy-settings.ps1` permet de déployer la configuration générale de Roo.

#### Syntaxe

```powershell
.\settings\deploy-settings.ps1 [-ConfigFile <chemin>] [-Force]
```

#### Paramètres

- `-ConfigFile` : Chemin du fichier de configuration à déployer (relatif au répertoire `roo-config/settings/`)
  - Par défaut : `settings.json`

- `-Force` : Force le remplacement du fichier de destination sans demander de confirmation

#### Exemples

1. Déployer la configuration générale standard :
   ```powershell
   .\settings\deploy-settings.ps1
   ```

2. Déployer une configuration personnalisée sans confirmation :
   ```powershell
   .\settings\deploy-settings.ps1 -ConfigFile ma-config.json -Force
   ```

## Relations entre les différentes configurations

### Relation entre settings.json et modes.json

- **settings.json** contient les paramètres globaux de Roo et les associations entre modes et profils d'API
- **modes.json** définit les modes disponibles et leurs propriétés spécifiques
- L'association se fait via la section `modeApiConfigs` dans settings.json qui mappe chaque mode à un profil d'API

### Relation avec roo-modes

- Le répertoire `roo-config/settings` gère les configurations générales de Roo
- Le répertoire `roo-modes` se concentre sur la définition des modes personnalisés
- Pour une configuration complète, il faut généralement déployer à la fois :
  1. Une configuration générale (via `roo-config/settings/deploy-settings.ps1`)
  2. Une configuration de modes (via `roo-config/deploy-modes.ps1` ou `roo-modes/deploy-modes.ps1`)

## Bonnes pratiques pour modifier les configurations

### Modification des paramètres généraux

1. **Sauvegardez d'abord** : Exportez votre configuration actuelle avant toute modification
2. **Utilisez les exemples** : Basez-vous sur les exemples fournis dans `exemple-config/`
3. **Testez localement** : Déployez d'abord en mode local pour tester vos modifications
4. **Vérifiez l'encodage** : Assurez-vous que vos fichiers sont en UTF-8 sans BOM
5. **Redémarrez VS Code** : Après chaque déploiement pour appliquer les changements

### Modification des modes

1. **Comprenez la structure** : Familiarisez-vous avec la structure du fichier `modes/standard-modes.json`
2. **Modifiez progressivement** : Faites des modifications incrémentales et testez-les
3. **Respectez le format JSON** : Assurez-vous que votre fichier reste valide
4. **Documentez vos changements** : Ajoutez des commentaires pour expliquer vos modifications
5. **Utilisez le script amélioré** : Préférez `deploy-modes-enhanced.ps1` qui offre plus d'options

### Sécurité

- Ne stockez jamais de clés d'API ou d'informations sensibles dans les fichiers de configuration partagés
- Ajoutez manuellement vos clés d'API après le déploiement
- Utilisez les scripts d'import/export pour sauvegarder vos configurations complètes dans un emplacement sécurisé

## Import et export de configurations

Pour synchroniser vos configurations entre différentes machines, consultez le guide détaillé dans `guide-import-export.md`. Ce guide explique comment :

1. Exporter votre configuration depuis une machine source
2. Importer cette configuration sur une machine cible
3. Utiliser des scripts d'automatisation pour faciliter ce processus
4. Synchroniser via un dépôt Git pour une solution plus avancée

## Résolution des problèmes courants

- **Problèmes d'encodage** : Utilisez `encoding-diagnostic.ps1` pour diagnostiquer et `fix-encoding.ps1` pour corriger
- **Modes non disponibles** : Vérifiez que le déploiement a réussi et redémarrez VS Code
- **Erreurs JSON** : Validez vos fichiers JSON avec un validateur en ligne
- **Chemins incorrects** : Assurez-vous que les chemins relatifs sont corrects dans vos scripts
- **Conflits de configuration** : Vérifiez que vos configurations ne contiennent pas de définitions contradictoires

Pour plus d'informations sur les configurations spécifiques, consultez les README.md dans les sous-répertoires correspondants.
