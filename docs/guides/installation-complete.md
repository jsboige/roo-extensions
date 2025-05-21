# Guide d'installation complet de Roo

## Introduction

Ce guide d'installation unifié vous accompagne dans la mise en place complète de l'environnement Roo, incluant l'extension VSCode, les configurations nécessaires, et la préparation de la démo d'initiation. Il est conçu pour s'adapter à différents niveaux d'expertise, vous permettant de commencer avec une configuration simple puis d'évoluer progressivement vers des fonctionnalités plus avancées.

### Objectif du guide

Ce document vise à :
- Fournir des instructions claires et détaillées pour l'installation de Roo
- Unifier les informations d'installation du dépôt principal et de la démo
- Proposer une approche progressive adaptée à différents profils d'utilisateurs
- Faciliter la résolution des problèmes courants d'installation

### Prérequis système

Avant de commencer l'installation, assurez-vous que votre système répond aux exigences minimales suivantes :

- **Système d'exploitation** : Windows 10/11, macOS 10.15+, ou Linux (Ubuntu 20.04+ recommandé)
- **Espace disque** : Minimum 2 Go d'espace libre
- **Mémoire RAM** : Minimum 4 Go (8 Go recommandé)
- **Connexion Internet** : Connexion stable requise pour l'installation et l'utilisation
- **Droits d'administration** : Nécessaires pour certaines étapes d'installation

### Vue d'ensemble du processus d'installation

Le processus d'installation complet comprend les étapes suivantes :

1. Installation de Visual Studio Code
2. Installation de l'extension Roo
3. Configuration des clés API et des paramètres de base
4. Installation des prérequis (Python, Node.js)
5. Configuration des profils de modèles
6. Installation et configuration des MCPs (Model Context Protocol servers)
7. Préparation de l'environnement pour la démo

Selon votre niveau d'expertise et vos besoins, vous pouvez suivre l'installation pour débutants, intermédiaire ou avancée.

## Installation pour débutants

Cette section présente les étapes essentielles pour commencer rapidement avec Roo, sans configuration avancée.

### Installation de Visual Studio Code

1. **Téléchargement** :
   - Rendez-vous sur [le site officiel de Visual Studio Code](https://code.visualstudio.com/)
   - Téléchargez la version correspondant à votre système d'exploitation

2. **Installation** :
   - **Windows** : Exécutez le fichier téléchargé (.exe) et suivez les instructions
   - **macOS** : Ouvrez le fichier .dmg, faites glisser l'application dans le dossier Applications
   - **Linux** : Suivez les instructions spécifiques à votre distribution

3. **Vérification** :
   - Lancez Visual Studio Code
   - Assurez-vous que l'application démarre correctement

### Installation de l'extension Roo

1. **Accès au marketplace** :
   - Dans VS Code, cliquez sur l'icône des extensions dans la barre latérale (ou appuyez sur Ctrl+Shift+X)
   - Dans la barre de recherche, tapez "Roo"

2. **Installation de l'extension** :
   - Localisez l'extension Roo dans les résultats
   - Cliquez sur le bouton "Installer"
   - Attendez que l'installation se termine

3. **Activation de l'extension** :
   - Redémarrez VS Code si nécessaire
   - Vérifiez que l'icône Roo apparaît dans la barre latérale

### Configuration minimale requise

1. **Création d'un compte Roo** :
   - Si vous n'avez pas encore de compte, créez-en un sur [le site officiel de Roo](https://roo.ai/signup)
   - Notez vos identifiants de connexion

2. **Configuration de l'extension** :
   - Cliquez sur l'icône Roo dans la barre latérale
   - Suivez les instructions pour vous connecter à votre compte
   - Acceptez les autorisations demandées

3. **Test initial** :
   - Créez une nouvelle tâche en cliquant sur le bouton "+" dans le panneau Roo
   - Posez une question simple pour vérifier que tout fonctionne correctement

## Installation intermédiaire

Cette section s'adresse aux utilisateurs souhaitant une configuration plus complète avec des fonctionnalités supplémentaires.

### Configuration des clés API

1. **Obtention des clés API** :
   - Connectez-vous à votre compte sur [le portail Roo](https://portal.roo.ai)
   - Naviguez vers la section "API Keys" ou "Developer"
   - Générez une nouvelle clé API si nécessaire

2. **Configuration dans VS Code** :
   - Ouvrez les paramètres de VS Code (Ctrl+,)
   - Recherchez "Roo API"
   - Entrez votre clé API dans le champ approprié

3. **Configuration du fichier .env** :
   - Pour la démo, créez un fichier `.env` dans le répertoire `demo-roo-code` en vous basant sur le modèle `.env.example` :
     ```bash
     cd chemin/vers/demo-roo-code
     cp .env.example .env
     ```
   - Ouvrez le fichier `.env` et ajoutez votre clé API :
     ```
     ROO_API_KEY=votre_clé_api_ici
     ```

### Installation des prérequis

#### Python

1. **Téléchargement** :
   - Rendez-vous sur [le site officiel de Python](https://www.python.org/downloads/)
   - Téléchargez la dernière version stable (3.8 ou supérieure)

2. **Installation** :
   - **Windows** : Exécutez l'installateur et cochez "Add Python to PATH"
   - **macOS** : Exécutez le package d'installation
   - **Linux** : Utilisez le gestionnaire de paquets de votre distribution

3. **Vérification** :
   - Ouvrez un terminal et exécutez :
     ```bash
     python --version
     # ou
     python3 --version
     ```
   - Assurez-vous que la version installée s'affiche correctement

#### Node.js

1. **Téléchargement** :
   - Rendez-vous sur [le site officiel de Node.js](https://nodejs.org/)
   - Téléchargez la version LTS (Long Term Support)

2. **Installation** :
   - Exécutez l'installateur et suivez les instructions
   - Acceptez les options par défaut

3. **Vérification** :
   - Ouvrez un terminal et exécutez :
     ```bash
     node --version
     npm --version
     ```
   - Assurez-vous que les versions installées s'affichent correctement

### Configuration des profils de modèles

1. **Comprendre les profils** :
   - Les profils définissent quels modèles de langage utiliser pour chaque mode
   - Le système utilise une architecture à 5 niveaux de complexité (n5)

2. **Sélection d'un profil** :
   - Ouvrez les paramètres de VS Code (Ctrl+,)
   - Recherchez "Roo Profile"
   - Sélectionnez un profil dans la liste déroulante :
     - "standard" : Utilise principalement Claude 3.5 Sonnet
     - "n5" : Architecture à 5 niveaux avec différents modèles
     - "qwen" : Utilise les modèles Qwen 3
     - "local" : Utilise des modèles locaux lorsque disponibles

3. **Personnalisation des paramètres** :
   - Ajustez les paramètres de température, de contexte et de réponse selon vos préférences
   - Ces paramètres influencent le comportement des modèles

## Installation avancée

Cette section couvre les aspects avancés de l'installation pour les utilisateurs souhaitant exploiter toutes les fonctionnalités de Roo.

### Configuration complète des MCPs

Les MCPs (Model Context Protocol servers) étendent les capacités de Roo en fournissant des fonctionnalités supplémentaires.

#### Installation des MCPs internes

1. **Clonage du dépôt** :
   ```bash
   # Depuis la racine du dépôt principal
   git submodule update --init --recursive mcps/internal
   ```

2. **Installation des dépendances** :
   ```bash
   cd mcps/internal
   npm install
   ```

3. **Configuration des MCPs internes** :
   - QuickFiles : Opérations avancées sur les fichiers
   - JinaNavigator : Conversion de pages web en Markdown
   - Jupyter : Interaction avec des notebooks Jupyter

   Pour chaque MCP, suivez les instructions spécifiques dans le répertoire correspondant.

#### Installation des MCPs externes

1. **SearXNG** :
   ```bash
   # Installation via npm
   npm install -g @modelcontextprotocol/server-searxng
   ```

2. **Win-CLI** :
   ```bash
   # Installation via npm
   npm install -g @simonb97/server-win-cli
   ```

3. **Filesystem** :
   ```bash
   # Installation via npm
   npm install -g @modelcontextprotocol/server-filesystem
   ```

4. **Git et GitHub** :
   ```bash
   # Installation via npm
   npm install -g @modelcontextprotocol/server-github
   ```

### Personnalisation des modes

1. **Exploration des modes disponibles** :
   - Ouvrez le panneau Roo
   - Cliquez sur l'icône de mode en haut du panneau
   - Parcourez les différents modes disponibles

2. **Création de modes personnalisés** :
   - Utilisez le script `create-profile.ps1` dans le répertoire `roo-config` :
     ```powershell
     cd roo-config
     .\create-profile.ps1 -ProfileName "mon-profil" -BaseProfile "standard"
     ```

3. **Déploiement des modes** :
   - Utilisez le script de déploiement approprié :
     ```powershell
     # Pour l'architecture à 5 niveaux avec le profil standard
     cd roo-config
     .\deploy-profile-modes.ps1 -ProfileName "standard" -DeploymentType global
     ```

### Optimisation des performances

1. **Gestion du contexte** :
   - Ajustez la taille du contexte dans les paramètres de Roo
   - Utilisez des outils comme `list_files` et `search_files` pour optimiser l'utilisation du contexte

2. **Configuration des modèles** :
   - Adaptez les modèles utilisés en fonction de la complexité des tâches
   - Utilisez des modèles plus légers pour les tâches simples

3. **Paramètres avancés** :
   - Explorez les paramètres avancés dans le fichier de configuration de Roo
   - Ajustez les paramètres en fonction de vos besoins spécifiques

## Configuration spécifique pour la démo

Cette section détaille les étapes spécifiques pour configurer l'environnement de la démo d'initiation à Roo.

### Préparation de l'environnement

1. **Clonage du dépôt principal** :
   ```bash
   git clone <URL_DU_DEPOT_PRINCIPAL>
   cd <NOM_DU_DEPOT_PRINCIPAL>
   ```

2. **Préparation des espaces de travail** :
   - Sous Windows :
     ```powershell
     # Depuis la racine du dépôt principal
     .\scripts\demo-scripts\prepare-workspaces.ps1
     ```
   - Sous Linux/macOS :
     ```bash
     # Depuis la racine du dépôt principal
     ./scripts/demo-scripts/prepare-workspaces.sh
     ```

3. **Vérification de la structure** :
   - Assurez-vous que les répertoires `workspace` ont été correctement préparés
   - Vérifiez que les fichiers nécessaires ont été copiés depuis les répertoires `ressources`

### Configuration du fichier .env

1. **Création du fichier .env** :
   ```bash
   cd chemin/vers/demo-roo-code
   cp .env.example .env
   ```

2. **Édition du fichier .env** :
   - Ouvrez le fichier `.env` dans un éditeur de texte
   - Ajoutez vos clés API et autres paramètres sensibles :
     ```
     ROO_API_KEY=votre_clé_api_ici
     OPENAI_API_KEY=votre_clé_openai_ici (si nécessaire)
     ANTHROPIC_API_KEY=votre_clé_anthropic_ici (si nécessaire)
     ```

3. **Vérification des paramètres** :
   - Assurez-vous que toutes les variables nécessaires sont définies
   - Vérifiez que le fichier est bien dans `.gitignore` pour éviter de committer des informations sensibles

### Vérification de l'installation

1. **Test des MCPs** :
   - Ouvrez VS Code à la racine du projet
   - Créez une nouvelle tâche Roo
   - Testez l'accès aux différents MCPs avec des commandes simples

2. **Test de la démo** :
   - Naviguez vers une démo spécifique (ex: `01-decouverte/demo-1-conversation/workspace`)
   - Suivez les instructions du README.md
   - Vérifiez que Roo répond correctement

3. **Vérification des scripts** :
   - Testez le script de nettoyage :
     ```powershell
     # Windows
     .\scripts\demo-scripts\clean-workspaces.ps1
     ```
   - Testez à nouveau le script de préparation pour vous assurer que tout fonctionne correctement

## Dépannage

Cette section présente des solutions aux problèmes courants rencontrés lors de l'installation et de la configuration.

### Problèmes d'installation de VS Code

#### VS Code ne démarre pas
- Vérifiez les journaux d'erreurs
- Réinstallez VS Code
- Assurez-vous que votre système répond aux exigences minimales

#### Erreurs lors de l'installation de l'extension Roo
- Vérifiez votre connexion internet
- Essayez d'installer l'extension manuellement en téléchargeant le fichier .vsix
- Redémarrez VS Code et réessayez

### Problèmes de configuration des clés API

#### Clé API non reconnue
- Vérifiez que la clé API est correctement copiée sans espaces supplémentaires
- Assurez-vous que la clé est active dans votre compte
- Vérifiez que vous utilisez la bonne variable d'environnement

#### Erreurs d'authentification
- Déconnectez-vous et reconnectez-vous à votre compte Roo
- Régénérez une nouvelle clé API si nécessaire
- Vérifiez que votre abonnement est actif

### Problèmes avec les MCPs

#### MCP non disponible
- Vérifiez que le MCP est correctement installé
- Assurez-vous que les dépendances sont installées
- Redémarrez le serveur MCP

#### Erreurs lors de l'utilisation des MCPs
- Vérifiez les journaux d'erreurs
- Assurez-vous que les chemins sont correctement configurés
- Vérifiez que les permissions sont correctement définies

### Problèmes spécifiques à la démo

#### Les scripts ne trouvent pas les répertoires workspace
- Vérifiez que vous exécutez les scripts depuis la racine du dépôt principal
- Assurez-vous que la structure des répertoires n'a pas été modifiée
- Vérifiez que les noms des dossiers de démo suivent le format attendu (`demo-X-nom`)

#### Fichiers manquants dans les workspaces
- Exécutez à nouveau le script de préparation
- Vérifiez que les fichiers existent dans les répertoires `ressources`
- Assurez-vous que les permissions sont correctement définies

### Ressources d'aide supplémentaires

- **Documentation en ligne** : Consultez [docs.roo.ai](https://docs.roo.ai) pour des guides détaillés
- **Forum communautaire** : Posez vos questions sur [community.roo.ai](https://community.roo.ai)
- **Support technique** : Contactez l'équipe à [support@roo.ai](mailto:support@roo.ai)
- **Tutoriels vidéo** : Regardez les démonstrations sur [learn.roo.ai/videos](https://learn.roo.ai/videos)

## Conclusion

Félicitations ! Vous avez maintenant configuré votre environnement Roo et êtes prêt à explorer la démo d'initiation. Ce guide vous a fourni les informations nécessaires pour une installation complète, de la configuration de base aux fonctionnalités avancées.

N'hésitez pas à consulter le [Guide d'introduction à la démo](./demo-guide.md) pour découvrir les différentes démonstrations disponibles et commencer votre exploration de Roo.

Si vous rencontrez des difficultés ou avez des questions, n'hésitez pas à consulter les ressources d'aide supplémentaires ou à contacter le support technique.

Bonne découverte de Roo !