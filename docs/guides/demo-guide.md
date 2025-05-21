# Guide d'introduction à la démo Roo

## Introduction

Bienvenue dans ce guide d'introduction à la démo d'initiation à Roo ! Ce document vous accompagnera dans la découverte et l'utilisation des différentes démonstrations conçues pour vous familiariser avec Roo, votre assistant personnel intelligent.

### Objectif de la démo

La démo d'initiation à Roo a été conçue pour vous permettre de :
- Découvrir les différentes fonctionnalités et modes de Roo
- Expérimenter des cas d'usage concrets et pratiques
- Apprendre à interagir efficacement avec l'assistant
- Explorer des scénarios adaptés à différents profils d'utilisateurs
- Comprendre comment intégrer Roo dans votre flux de travail quotidien

### Public cible

Cette démo s'adresse à un large éventail d'utilisateurs :
- **Nouveaux utilisateurs** souhaitant découvrir les capacités de Roo
- **Utilisateurs intermédiaires** cherchant à approfondir leurs connaissances
- **Professionnels** voulant explorer des cas d'usage métier
- **Formateurs** préparant des sessions de démonstration
- **Développeurs** intéressés par l'intégration de Roo dans leurs projets

### Bénéfices attendus

En suivant cette démo, vous pourrez :
- Gagner en autonomie dans l'utilisation de Roo
- Découvrir des fonctionnalités que vous ne connaissiez peut-être pas
- Apprendre à formuler des requêtes efficaces
- Comprendre comment choisir le mode le plus adapté à chaque tâche
- Optimiser votre productivité grâce à l'assistant

## Structure de la démo

### Organisation en 5 répertoires thématiques

La démo est organisée en 5 répertoires thématiques, chacun couvrant un aspect spécifique de l'utilisation de Roo :

1. **01-decouverte** : Introduction aux fonctionnalités de base
   - Premiers pas avec Roo
   - Utilisation des capacités de vision
   - Interaction conversationnelle

2. **02-orchestration-taches** : Gestion de projets et organisation de tâches
   - Planification de projets
   - Recherche web
   - Gestion de fichiers
   - Automatisation de tâches

3. **03-assistant-pro** : Utilisation de Roo dans un contexte professionnel
   - Analyse de données
   - Création de présentations
   - Communication professionnelle
   - Aide à la décision

4. **04-creation-contenu** : Création de documents, sites web et contenus multimédias
   - Création de sites web
   - Contenu pour réseaux sociaux
   - Documents et rapports
   - Matériel marketing

5. **05-projets-avances** : Cas d'usage avancés et intégrations complexes
   - Architecture de systèmes
   - Intégration d'outils
   - Développement avancé
   - Projets multi-étapes

### Structure interne de chaque démo

Chaque démo spécifique suit une structure standardisée pour faciliter la navigation et l'utilisation :

- **README.md** : Instructions détaillées pour la démo
- **docs/** : Documentation supplémentaire et guides pour les agents
- **ressources/** : Fichiers nécessaires pour la démo (données, images, etc.)
- **workspace/** : Espace de travail où vous interagirez avec Roo

Cette structure cohérente permet une expérience utilisateur fluide et facilite la maintenance des démos.

### Rôle des différents dossiers

- **docs/** : Contient des guides spécifiques pour les agents Roo, expliquant comment aborder les tâches de la démo et quelles capacités utiliser.

- **ressources/** : Stocke tous les fichiers nécessaires à la démo, comme des jeux de données, des images, des modèles de documents, etc. Ces fichiers sont copiés dans le workspace lors de la préparation.

- **workspace/** : C'est ici que vous travaillerez avec Roo. Ce dossier est initialement vide (à l'exception d'un README.md) et sera peuplé par le script de préparation. Tout le contenu de ce dossier (sauf le README.md) sera supprimé lors du nettoyage.

## Parcours recommandés

Selon votre profil et vos objectifs, nous vous recommandons différents parcours pour explorer les démos. Chaque parcours est conçu pour offrir une expérience progressive et cohérente.

### Pour les débutants (45-60 min)

Ce parcours est idéal pour les personnes qui découvrent Roo pour la première fois :

1. **Premiers contacts** (10-15 min)
   - `01-decouverte/demo-1-conversation`
   - Posez des questions simples à Roo
   - Découvrez les bases de l'interaction

2. **Création de contenu simple** (15-20 min)
   - `04-creation-contenu/demo-1-web`
   - Créez un document ou une page web simple
   - Expérimentez avec des modifications guidées

3. **Organisation personnelle** (15-20 min)
   - `02-orchestration-taches/demo-1-planification`
   - Planifiez un petit événement ou une tâche personnelle
   - Découvrez comment Roo peut vous aider à vous organiser

### Pour les professionnels (45-60 min)

Ce parcours est conçu pour les utilisateurs en contexte professionnel :

1. **Assistant professionnel** (15-20 min)
   - `03-assistant-pro/demo-1-analyse`
   - Analysez des données et créez des rapports
   - Découvrez comment Roo peut vous aider dans vos tâches quotidiennes

2. **Communication professionnelle** (15-20 min)
   - `03-assistant-pro/demo-3-communication`
   - Rédigez des emails et préparez des réunions
   - Améliorez votre communication professionnelle

3. **Projets avancés** (15-20 min)
   - `05-projets-avances/demo-1-architecture`
   - Explorez des cas d'usage plus complexes
   - Découvrez comment Roo peut vous aider dans des projets d'envergure

### Pour les créatifs (45-60 min)

Ce parcours est adapté aux personnes travaillant dans des domaines créatifs :

1. **Vision et analyse d'images** (15-20 min)
   - `01-decouverte/demo-2-vision`
   - Explorez les capacités visuelles de Roo
   - Analysez des images et obtenez des insights

2. **Création de contenu multimédia** (15-20 min)
   - `04-creation-contenu/demo-2-reseaux-sociaux`
   - Créez du contenu pour les réseaux sociaux
   - Expérimentez avec différents formats et styles

3. **Design et présentation** (15-20 min)
   - `04-creation-contenu/site-web-simple`
   - Créez et personnalisez un site web simple
   - Découvrez les principes de design avec Roo

## Utilisation des scripts

Pour faciliter l'utilisation des démos, deux scripts sont disponibles dans le répertoire `scripts/demo-scripts/` du dépôt principal. Ces scripts vous permettent de préparer et de nettoyer les espaces de travail rapidement.

### Script de préparation des workspaces

Le script `prepare-workspaces.ps1` (Windows) ou `prepare-workspaces.sh` (Linux/macOS) copie les fichiers nécessaires depuis les répertoires `ressources` vers les répertoires `workspace` pour chaque démo.

#### Utilisation sous Windows :
```powershell
# Depuis la racine du dépôt principal
.\scripts\demo-scripts\prepare-workspaces.ps1
```

#### Utilisation sous Linux/macOS :
```bash
# Depuis la racine du dépôt principal
./scripts/demo-scripts/prepare-workspaces.sh
```

#### Fonctionnement du script :
1. Le script recherche tous les répertoires de démo dans la structure du projet
2. Pour chaque démo, il vérifie l'existence des répertoires `ressources` et `workspace`
3. Il nettoie d'abord le contenu du répertoire `workspace` (sauf les fichiers README.md)
4. Il copie ensuite tous les fichiers du répertoire `ressources` vers le répertoire `workspace`
5. À la fin, il affiche un résumé des opérations effectuées

#### Bonnes pratiques :
- Exécutez ce script avant de commencer une nouvelle série de démos
- Assurez-vous d'être dans le répertoire racine du dépôt principal
- Vérifiez que les permissions d'exécution sont correctement configurées

### Script de nettoyage des workspaces

Le script `clean-workspaces.ps1` (Windows) ou `clean-workspaces.sh` (Linux/macOS) supprime tout le contenu des répertoires `workspace` (sauf les fichiers README.md) pour vous permettre de repartir de zéro.

#### Utilisation sous Windows :
```powershell
# Depuis la racine du dépôt principal
.\scripts\demo-scripts\clean-workspaces.ps1
```

#### Utilisation sous Linux/macOS :
```bash
# Depuis la racine du dépôt principal
./scripts/demo-scripts/clean-workspaces.sh
```

#### Fonctionnement du script :
1. Le script recherche tous les répertoires `workspace` dans la structure du projet
2. Pour chaque répertoire `workspace`, il supprime tous les fichiers et sous-répertoires, à l'exception des fichiers README.md
3. À la fin, il affiche un résumé des opérations effectuées

#### Bonnes pratiques :
- Exécutez ce script après avoir terminé une série de démos
- Utilisez-le avant de commencer une nouvelle démo pour partir d'un environnement propre
- Sauvegardez tout travail important avant d'exécuter ce script

## Approches d'utilisation

Vous pouvez explorer les démos de deux façons différentes, selon vos préférences et objectifs.

### Approche manuelle (Navigation par répertoire)

Cette approche vous permet d'explorer chaque démo individuellement et d'interagir directement avec chaque exemple :

1. **Navigation dans les répertoires thématiques**
   - Parcourez les dossiers (`01-decouverte`, `02-orchestration-taches`, etc.)
   - Choisissez une démo spécifique (ex: `demo-1-conversation`)
   - Ouvrez le dossier `workspace` correspondant

2. **Ouverture d'instances VSCode dédiées**
   - Pour chaque démo, ouvrez une instance VSCode dédiée :
     ```
     # Windows
     code "chemin/vers/01-decouverte/demo-1-conversation/workspace"
     
     # Mac
     open -a "Visual Studio Code" "chemin/vers/01-decouverte/demo-1-conversation/workspace"
     ```
   - Cela permet de vous concentrer sur une démo à la fois

3. **Suivi des instructions spécifiques**
   - Consultez le fichier README.md dans chaque workspace
   - Suivez les instructions pas à pas propres à chaque démo
   - Utilisez les ressources fournies dans le dossier

4. **Démarrage de tâches Roo dédiées**
   - Dans chaque instance VSCode, ouvrez le panneau Roo
   - Créez une nouvelle tâche en suivant les instructions du README
   - Interagissez avec Roo dans le contexte spécifique de la démo

**Avantages :**
- Exploration approfondie de chaque démo
- Expérience d'apprentissage progressive
- Possibilité d'expérimenter librement dans chaque workspace

**Inconvénients :**
- Nécessite de naviguer entre plusieurs instances VSCode
- Processus plus manuel et potentiellement plus long

### Approche automatisée (Orchestration globale)

Cette approche utilise le mode Orchestrateur de Roo pour exécuter automatiquement plusieurs démos :

1. **Utilisation de l'instance principale de VSCode**
   - Restez dans l'instance VSCode ouverte à la racine du projet
   - Pas besoin d'ouvrir plusieurs fenêtres ou instances

2. **Création d'une tâche d'orchestration**
   - Ouvrez le panneau Roo et créez une nouvelle tâche
   - Sélectionnez le mode "🪃 Orchestrateur"
   - Utilisez un prompt qui spécifie les démos à exécuter

3. **Exemple de prompt pour l'orchestrateur :**
   ```
   Exécute les démos suivantes dans l'ordre :
   1. 01-decouverte/demo-1-conversation
   2. 03-assistant-pro/demo-1-analyse
   
   Pour chaque démo :
   - Concentre-toi uniquement sur le répertoire workspace correspondant
   - Exécute les tâches de manière non interactive
   - Documente toutes les étapes dans le rapport de terminaison
   - Respecte les instructions du README.md de chaque démo
   ```

4. **Exécution d'une démo spécifique**
   - Pour exécuter une seule démo, précisez-la dans votre prompt :
   ```
   Exécute uniquement la démo 02-orchestration-taches/demo-1-planification.
   Suis les instructions du README.md et génère un rapport complet.
   ```

**Avantages :**
- Processus automatisé nécessitant moins d'intervention
- Vue d'ensemble de plusieurs démos en une seule session
- Documentation automatique des résultats
- Idéal pour les présentations ou démonstrations rapides

**Inconvénients :**
- Expérience moins interactive et personnalisée
- Moins adapté à l'apprentissage progressif
- Peut être plus complexe à configurer initialement

## Résolution des problèmes courants

### Problèmes liés aux scripts

#### Les scripts ne trouvent pas les répertoires workspace
- Vérifiez que vous exécutez les scripts depuis la racine du dépôt principal
- Assurez-vous que la structure des répertoires n'a pas été modifiée
- Vérifiez que les noms des dossiers de démo suivent le format attendu (`demo-X-nom`)
- Vérifiez que le chemin vers le répertoire `demo-roo-code` est correct dans les scripts

#### Erreurs de permission sur les scripts bash
```bash
chmod +x *.sh
```

#### Problèmes de fins de ligne
Si vous obtenez des erreurs du type "bad interpreter", convertissez les fins de ligne :
```bash
# Installation de dos2unix si nécessaire
sudo apt-get install dos2unix

# Conversion des fins de ligne
dos2unix *.sh
```

### Problèmes liés à l'environnement

#### L'extension Roo ne se charge pas
- Vérifiez que vous avez la dernière version de VS Code
- Désinstallez et réinstallez l'extension
- Redémarrez VS Code après l'installation

#### Roo ne répond pas comme prévu
- Assurez-vous d'avoir sélectionné le bon mode pour votre tâche
- Essayez de reformuler votre question de manière plus précise
- Vérifiez votre connexion internet

#### Les fichiers ne s'affichent pas dans le workspace
- Exécutez à nouveau le script de préparation
- Vérifiez que vous êtes dans le bon répertoire
- Rafraîchissez l'explorateur de fichiers de VS Code

### Problèmes spécifiques à Windows/Mac

#### Exécution des scripts PowerShell
Si vous ne pouvez pas exécuter les scripts PowerShell en raison de restrictions de sécurité :
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

#### Chemins trop longs sur Windows
Windows peut avoir des problèmes avec les chemins dépassant 260 caractères. Activez la prise en charge des chemins longs :
```powershell
# Nécessite des droits administrateur
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force
```

#### Problèmes d'encodage des caractères spéciaux
Si vous rencontrez des problèmes d'affichage des caractères spéciaux, notamment dans WSL sur Windows :

1. Utilisez l'option `--no-colors` avec les scripts bash :
   ```bash
   ./clean-workspaces.sh --no-colors
   ```

2. Vérifiez l'encodage de vos fichiers. Tous les fichiers devraient être encodés en UTF-8 :
   ```bash
   # Sur Linux/macOS
   file -i nom_du_fichier
   
   # Sur Windows PowerShell
   Get-Content nom_du_fichier | Out-File -Encoding utf8 nom_du_fichier_fixed
   ```

## Conclusion

Ce guide vous a présenté la structure et l'utilisation de la démo d'initiation à Roo. Vous disposez maintenant de toutes les informations nécessaires pour explorer les différentes démos et découvrir les capacités de Roo.

N'hésitez pas à expérimenter avec différentes approches et à adapter les parcours recommandés à vos besoins spécifiques. La démo est conçue pour être flexible et s'adapter à différents profils d'utilisateurs.

Pour aller plus loin, consultez également :
- Le [guide d'installation complet](./installation-complete.md) pour configurer votre environnement
- La [documentation officielle de Roo](https://docs.roo.ai) pour des informations détaillées sur toutes les fonctionnalités
- Le [forum communautaire](https://community.roo.ai) pour échanger avec d'autres utilisateurs

Bonne découverte de Roo !