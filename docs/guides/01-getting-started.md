# Guide de démarrage Roo Extensions

Ce guide vous accompagne dans la découverte de Roo, de l'installation à la maîtrise des fonctionnalités avancées.

## Table des matières

1. [Prérequis](#prérequis)
2. [Installation complète](#installation-complète)
3. [Parcours d'apprentissage](#parcours-dapprentissage)
4. [Utilisation des scripts](#utilisation-des-scripts)
5. [Troubleshooting](#troubleshooting)
6. [Prochaines étapes](#prochaines-étapes)

## Prérequis

### Logiciels requis
- **VS Code** (version récente)
- **PowerShell** 5.1+ ou **Bash** (selon votre système)
- **Git** pour cloner le dépôt
- **Node.js** (optionnel, pour certains MCPs)

### Accès aux modèles IA
- Compte avec accès à **Claude 3.7 Sonnet** (recommandé)
- Ou accès à **Qwen 3 32B** (alternative économique)
- Configuration API dans Roo

## Installation complète

### Étape 1 : Installer Roo dans VS Code

1. Ouvrez VS Code
2. Allez dans Extensions (Ctrl+Shift+X)
3. Recherchez "Roo" et installez l'extension officielle
4. Redémarrez VS Code

### Étape 2 : Cloner le dépôt d'extensions

```bash
# Cloner dans un répertoire de votre choix
git clone https://github.com/votre-utilisateur/roo-extensions.git
cd roo-extensions
```

### Étape 3 : Déployer les modes personnalisés

```powershell
# Naviguer vers le répertoire de configuration
cd roo-config

# Déployer l'architecture standard (recommandée)
.\deploy-profile-modes.ps1 -ProfileName "standard" -DeploymentType global

# Alternative : déployer l'architecture Qwen (plus économique)
# .\deploy-profile-modes.ps1 -ProfileName "qwen" -DeploymentType global
```

### Étape 4 : Redémarrer Roo

1. Fermez VS Code complètement
2. Rouvrez VS Code
3. Vérifiez que les nouveaux modes apparaissent dans l'interface Roo

## Parcours d'apprentissage

### Niveau 1 : Découverte (15 minutes)

**Objectif** : Premiers pas avec Roo et compréhension des bases

```powershell
# Préparer l'environnement de démo
.\demo-roo-code\prepare-workspaces.ps1

# Ouvrir la première démo
code demo-roo-code\01-decouverte\demo-1-conversation\workspace
```

**Ce que vous apprendrez** :
- Interface de Roo et sélection de modes
- Communication en langage naturel
- Capacités de vision et analyse d'images
- Interaction conversationnelle de base

**Durée estimée** : 15 minutes

### Niveau 2 : Orchestration (30 minutes)

**Objectif** : Gestion de projets et coordination de tâches

```powershell
# Ouvrir la démo d'orchestration
code demo-roo-code\02-orchestration-taches\workspace
```

**Ce que vous apprendrez** :
- Mode Orchestrator pour déléguer des tâches
- Recherche web avec SearXNG
- Gestion de fichiers multiples avec QuickFiles
- Planification de projets structurés

**Durée estimée** : 30 minutes

### Niveau 3 : Assistant professionnel (45 minutes)

**Objectif** : Utilisation de Roo dans un contexte professionnel

```powershell
# Ouvrir la démo assistant pro
code demo-roo-code\03-assistant-pro\workspace
```

**Ce que vous apprendrez** :
- Analyse de données avec Jupyter
- Création de présentations et rapports
- Communication professionnelle
- Intégration avec GitHub

**Durée estimée** : 45 minutes

### Niveau 4 : Création de contenu (45 minutes)

**Objectif** : Développement web et création multimédia

```powershell
# Ouvrir la démo création de contenu
code demo-roo-code\04-creation-contenu\workspace
```

**Ce que vous apprendrez** :
- Création de sites web complets
- Contenu pour réseaux sociaux
- Documents et rapports automatisés
- Conversion web vers Markdown avec JinaNavigator

### Niveau 5 : Projets avancés (60+ minutes)

**Objectif** : Cas d'usage complexes et intégrations

```powershell
# Ouvrir la démo projets avancés
code demo-roo-code\05-projets-avances\workspace
```

**Ce que vous apprendrez** :
- Architecture de systèmes complexes
- Intégration d'outils multiples
- Développement avancé avec MCPs
- Automatisation de workflows

## Utilisation des scripts

### Scripts de préparation

```powershell
# Préparer tous les espaces de travail de démo
.\demo-roo-code\prepare-workspaces.ps1

# Préparer un espace spécifique
.\demo-roo-code\prepare-workspaces.ps1 -DemoPath "01-decouverte"
```

### Scripts de nettoyage

```powershell
# Nettoyer tous les espaces de travail
.\demo-roo-code\clean-workspaces.ps1

# Nettoyer un espace spécifique
.\demo-roo-code\clean-workspaces.ps1 -DemoPath "01-decouverte"
```

### Scripts de configuration

```powershell
# Vérifier la configuration actuelle
.\roo-config\check-configuration.ps1

# Sauvegarder la configuration
.\roo-config\backup-configuration.ps1

# Restaurer une configuration
.\roo-config\restore-configuration.ps1 -BackupName "backup-2024-01-01"
```

## Troubleshooting

### Problèmes courants

#### Les modes personnalisés n'apparaissent pas

**Solution** :
```powershell
# Vérifier le déploiement
.\roo-config\check-configuration.ps1

# Redéployer si nécessaire
.\roo-config\deploy-profile-modes.ps1 -ProfileName "standard" -DeploymentType global -Force
```

#### Erreurs d'encodage de caractères

**Solution** :
```powershell
# Utiliser le script de correction d'encodage
.\encoding-fix\run-encoding-fix.ps1
```

#### MCPs non disponibles

**Solution** :
```powershell
# Vérifier le statut des MCPs
.\mcps\tests\run-all-tests.ps1

# Redémarrer les MCPs si nécessaire
.\mcps\restart-mcps.ps1
```

#### Problèmes de permissions PowerShell

**Solution** :
```powershell
# Autoriser l'exécution de scripts (en tant qu'administrateur)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Diagnostic avancé

```powershell
# Rapport complet de diagnostic
.\roo-config\diagnostic-scripts\full-diagnostic.ps1

# Test de connectivité des modèles IA
.\roo-config\diagnostic-scripts\test-ai-models.ps1

# Vérification de l'intégrité des fichiers
.\roo-config\diagnostic-scripts\verify-integrity.ps1
```

## Prochaines étapes

### Après avoir terminé les démos

1. **Explorez la documentation avancée** :
   - [Architecture du projet](ARCHITECTURE.md)
   - [Guide des modes](docs/guide-complet-modes-roo.md)
   - [Configuration des MCPs](docs/guide-configuration-mcps.md)

2. **Personnalisez votre configuration** :
   - Créez vos propres profils de modes
   - Configurez des MCPs supplémentaires
   - Adaptez les scripts à vos besoins

3. **Contribuez au projet** :
   - Signalez des bugs ou suggestions
   - Partagez vos cas d'usage
   - Contribuez à la documentation

### Ressources supplémentaires

- **Documentation complète** : [`docs/`](docs/)
- **Exemples de configuration** : [`roo-modes/examples/`](roo-modes/examples/)
- **Tests et validation** : [`tests/`](tests/)
- **Scripts utilitaires** : [`roo-config/`](roo-config/)

### Support communautaire

- **Issues GitHub** : Pour signaler des problèmes
- **Discussions** : Pour partager des cas d'usage
- **Wiki** : Pour la documentation collaborative

---

**🎯 Conseil** : Commencez par le Niveau 1 (Découverte) même si vous êtes expérimenté. Cela vous donnera une base solide pour comprendre l'écosystème Roo Extensions.