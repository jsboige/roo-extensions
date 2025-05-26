# Roo Scheduler - Documentation Principale

## Vue d'ensemble

Le **Roo Scheduler** est un système de planification et d'orchestration avancé conçu pour gérer les tâches et processus dans l'écosystème Roo Extensions. Il fournit une architecture modulaire, flexible et robuste pour l'exécution de tâches automatisées, la gestion des files d'attente et l'intégration avec les différents composants Roo.

## Caractéristiques Principales

### 🏗️ Architecture Modulaire
- **Modules Core** : Gestionnaire de tâches, moteur d'exécution, gestionnaire de files d'attente
- **Modules Utilitaires** : Logging, métriques, vérifications de santé
- **Modules d'Intégration** : Roo Modes, serveurs MCP, extension VSCode

### 🌍 Multi-Environnements
- **Développement** : Configuration optimisée pour le développement local
- **Test** : Environnement de validation et tests automatisés
- **Production** : Configuration sécurisée et optimisée pour la production

### 📊 Monitoring et Observabilité
- Logging structuré avec rotation automatique
- Métriques de performance en temps réel
- Vérifications de santé automatiques
- Alertes configurables

### 🔒 Sécurité et Performance
- Authentification et autorisation configurables
- Limitation de débit (rate limiting)
- Optimisation mémoire et cache intelligent
- Sauvegarde automatique des données

## Structure du Projet

```
roo-config/scheduler/
├── config/                          # Fichiers de configuration
│   ├── scheduler-config.json        # Configuration principale
│   ├── modules-config.json          # Configuration des modules
│   └── environments.json            # Configuration multi-environnements
├── scripts/                         # Scripts d'exécution
│   ├── core/                        # Scripts principaux
│   │   └── scheduler-manager.ps1    # Gestionnaire principal
│   ├── modules/                     # Scripts des modules
│   ├── utils/                       # Scripts utilitaires
│   └── install/                     # Scripts d'installation
│       └── install-scheduler.ps1    # Script d'installation
├── logs/                            # Fichiers de logs
├── data/                            # Données persistantes
├── docs/                            # Documentation
│   ├── README.md                    # Ce fichier
│   └── architecture.md             # Documentation de l'architecture
├── Guide_Installation_Roo_Scheduler.md
└── Guide_Edition_Directe_Configurations_Roo_Scheduler.md
```

## Installation Rapide

### Prérequis
- PowerShell 5.1 ou supérieur
- Windows 10/11 ou Windows Server 2016+
- Privilèges administrateur (recommandé)

### Installation Automatique

```powershell
# Depuis le répertoire roo-config/scheduler/
.\scripts\install\install-scheduler.ps1 -Environment development
```

### Installation Manuelle

1. **Cloner ou télécharger** le projet Roo Extensions
2. **Naviguer** vers le répertoire `roo-config/scheduler/`
3. **Exécuter** le script d'installation :
   ```powershell
   .\scripts\install\install-scheduler.ps1
   ```

## Utilisation

### Commandes de Base

```powershell
# Démarrer le scheduler
.\scripts\core\scheduler-manager.ps1 -Action start

# Vérifier le statut
.\scripts\core\scheduler-manager.ps1 -Action status

# Arrêter le scheduler
.\scripts\core\scheduler-manager.ps1 -Action stop

# Redémarrer le scheduler
.\scripts\core\scheduler-manager.ps1 -Action restart
```

### Gestion des Environnements

```powershell
# Démarrer en mode développement (par défaut)
.\scripts\core\scheduler-manager.ps1 -Action start -Environment development

# Démarrer en mode test
.\scripts\core\scheduler-manager.ps1 -Action start -Environment testing

# Démarrer en mode production
.\scripts\core\scheduler-manager.ps1 -Action start -Environment production
```

### Mode Debug

```powershell
# Activer le mode debug
.\scripts\core\scheduler-manager.ps1 -Action start -Debug
```

## Configuration

### Configuration Principale (`scheduler-config.json`)

Contient les paramètres globaux du scheduler :
- Paramètres d'exécution (tâches concurrentes, timeouts)
- Configuration du logging
- Paramètres de monitoring
- Configuration du stockage
- Paramètres de sécurité
- Optimisations de performance

### Configuration des Modules (`modules-config.json`)

Définit les modules disponibles et leur configuration :
- Modules core (taskManager, queueManager, executionEngine)
- Modules utilitaires (logger, metrics, healthCheck)
- Modules d'intégration (rooModes, mcpServers, vscodeExtension)
- Ordre de chargement des modules

### Configuration des Environnements (`environments.json`)

Spécifie les paramètres par environnement :
- Développement : Debug activé, logging verbeux
- Test : Configuration intermédiaire avec alertes
- Production : Sécurité renforcée, optimisations maximales

## Modules Disponibles

### Modules Core

| Module | Description | Dépendances |
|--------|-------------|-------------|
| `taskManager` | Gestionnaire principal des tâches | Aucune |
| `queueManager` | Gestionnaire des files d'attente | taskManager |
| `executionEngine` | Moteur d'exécution des tâches | taskManager, queueManager |

### Modules Utilitaires

| Module | Description | Dépendances |
|--------|-------------|-------------|
| `logger` | Système de logging structuré | Aucune |
| `metrics` | Collecte de métriques | logger |
| `healthCheck` | Vérifications de santé | logger |

### Modules d'Intégration

| Module | Description | Dépendances |
|--------|-------------|-------------|
| `rooModes` | Intégration avec Roo Modes | taskManager |
| `mcpServers` | Intégration avec serveurs MCP | taskManager |
| `vscodeExtension` | Intégration VSCode | taskManager |

## Monitoring et Logs

### Fichiers de Logs

- **scheduler-manager.log** : Logs du gestionnaire principal
- **modules/*.log** : Logs spécifiques par module
- **errors.log** : Logs d'erreurs consolidés

### Métriques Disponibles

- Nombre de tâches en cours
- Temps de réponse moyen
- Taux d'erreur
- Utilisation mémoire
- Taille des files d'attente

### Vérifications de Santé

- État des modules
- Connectivité des dépendances
- Utilisation des ressources
- Intégrité des données

## Dépannage

### Problèmes Courants

#### Le scheduler ne démarre pas
1. Vérifier les logs dans `logs/scheduler-manager.log`
2. Valider les fichiers de configuration JSON
3. S'assurer que les dépendances sont installées
4. Vérifier les permissions sur les répertoires

#### Erreurs de configuration
1. Utiliser un validateur JSON pour vérifier la syntaxe
2. Consulter les exemples de configuration
3. Vérifier les chemins de fichiers relatifs

#### Problèmes de performance
1. Ajuster `maxConcurrentTasks` dans la configuration
2. Optimiser la taille du cache
3. Vérifier l'utilisation mémoire
4. Analyser les métriques de performance

### Commandes de Diagnostic

```powershell
# Vérifier la configuration
.\scripts\core\scheduler-manager.ps1 -Action config

# Mode debug complet
.\scripts\core\scheduler-manager.ps1 -Action start -Debug -Environment development

# Forcer la réinstallation
.\scripts\install\install-scheduler.ps1 -Force
```

## Développement et Contribution

### Structure de Développement

Pour contribuer au développement du Roo Scheduler :

1. **Fork** le projet Roo Extensions
2. **Créer** une branche pour votre fonctionnalité
3. **Développer** en suivant les conventions de code
4. **Tester** avec l'environnement de développement
5. **Soumettre** une pull request

### Tests

```powershell
# Environnement de test
.\scripts\core\scheduler-manager.ps1 -Action start -Environment testing

# Tests de validation
.\scripts\install\install-scheduler.ps1 -Environment testing
```

## Support et Documentation

### Ressources Supplémentaires

- **[Architecture](architecture.md)** : Documentation technique détaillée
- **[Guide d'Installation](../Guide_Installation_Roo_Scheduler.md)** : Instructions d'installation complètes
- **[Guide de Configuration](../Guide_Edition_Directe_Configurations_Roo_Scheduler.md)** : Édition des configurations

### Support

Pour obtenir de l'aide :
1. Consulter cette documentation
2. Vérifier les logs d'erreur
3. Consulter les guides spécialisés
4. Créer une issue sur le projet Roo Extensions

## Licence et Crédits

Développé par l'équipe Roo Extensions dans le cadre du projet Roo-Cline.

---

**Version** : 1.0.0  
**Dernière mise à jour** : 26 mai 2025  
**Auteurs** : Équipe Roo Extensions