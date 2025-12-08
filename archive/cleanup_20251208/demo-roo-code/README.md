# 🤖 Roo - Votre Assistant Personnel Intelligent

> **Note d'intégration**: Ce projet est conçu pour être autonome tout en restant intégrable comme sous-dossier dans un dépôt Git existant. Pour plus d'informations sur l'intégration, consultez le fichier [README-integration.md](./README-integration.md).

## 📋 Introduction

Bienvenue dans le monde de Roo, votre assistant personnel intelligent qui simplifie votre quotidien professionnel et personnel. Roo est conçu pour vous aider à accomplir une multitude de tâches sans nécessiter de connaissances techniques particulières.

Roo est comme un collègue virtuel toujours disponible qui:
- Vous aide à rédiger et organiser vos documents
- Recherche des informations pour vous
- Crée du contenu sur mesure selon vos besoins
- Automatise vos tâches répétitives
- Répond à vos questions et vous guide dans vos projets

Ce guide vous présente comment Roo peut transformer votre façon de travailler et vous faire gagner un temps précieux au quotidien.

## 🔄 Les Différents Modes de Roo Expliqués Simplement

Roo s'adapte à vos besoins grâce à différents modes, comme des "personnalités" spécialisées:

### 💬 Mode Conversation (Ask)
**C'est comme avoir un expert à portée de main.**
- Posez des questions en langage naturel
- Obtenez des explications claires sur n'importe quel sujet
- Exemple: "Comment puis-je améliorer l'organisation de mes dossiers?" ou "Explique-moi comment fonctionne la TVA"

### 📝 Mode Création (Code)
**Votre assistant de rédaction et création.**
- Créez ou modifiez tout type de document
- Rédigez des emails, rapports, présentations
- Exemple: "Rédige un email de confirmation pour un rendez-vous client" ou "Crée un planning hebdomadaire pour mon équipe"

### 🏗️ Mode Organisation (Architect)
**Votre planificateur personnel.**
- Structurez vos projets et idées
- Créez des plans d'action détaillés
- Exemple: "Aide-moi à planifier l'organisation d'un séminaire d'entreprise" ou "Crée un plan pour réorganiser mon espace de travail"

### 🔍 Mode Résolution (Debug)
**Votre solutionneur de problèmes.**
- Analysez et résolvez des difficultés
- Trouvez des solutions pratiques
- Exemple: "Mon tableau Excel ne calcule pas correctement les totaux" ou "Comment résoudre un conflit entre deux collègues?"

### 🪃 Mode Chef d'Orchestre (Orchestrator)
**Votre coordinateur pour les projets complexes.**
- Gère des projets multi-facettes
- Coordonne différentes étapes et ressources
- Exemple: "Aide-moi à organiser mon déménagement" ou "Planifie le lancement d'un nouveau service dans mon entreprise"

### 🏢 Mode Gestionnaire de Projet (Project Manager)
**Votre stratège pour les grands projets.**
- Supervise des initiatives complexes
- Décompose les projets en parties gérables
- Exemple: "Aide-moi à planifier la refonte complète de notre site web" ou "Organise le déploiement de notre nouvelle solution logicielle"

## 📂 Structure du Projet et Organisation des Démos

Ce projet est organisé en 5 répertoires thématiques, chacun contenant plusieurs démos spécifiques:

### Structure à deux niveaux

1. **Premier niveau: Répertoires thématiques**
   - `01-decouverte` - Premiers pas avec Roo et fonctionnalités de base
   - `02-orchestration-taches` - Gestion de projets et organisation de tâches
   - `03-assistant-pro` - Utilisation de Roo dans un contexte professionnel
   - `04-creation-contenu` - Création de documents, sites web et contenus multimédias
   - `05-projets-avances` - Cas d'usage avancés et intégrations complexes

2. **Deuxième niveau: Démos spécifiques**
   Chaque répertoire thématique contient plusieurs démos (ex: `demo-1-conversation`, `demo-2-vision`) avec:
   - Un fichier `README.md` contenant les instructions détaillées
   - Un dossier `docs` avec des guides pour les agents
   - Un dossier `ressources` avec les fichiers nécessaires pour la démo
   - Un dossier `workspace` où vous interagirez avec Roo

### Scripts de préparation et de nettoyage

Pour faciliter l'utilisation des démos, deux scripts sont disponibles directement dans le répertoire principal :

- **Scripts de préparation** (`prepare-workspaces.ps1`)
  - Copient les fichiers nécessaires depuis les répertoires `ressources` vers les répertoires `workspace`
  - Préparent l'environnement pour chaque démo
  - À exécuter avant de commencer une nouvelle série de démos

- **Scripts de nettoyage** (`clean-workspaces.ps1`)
  - Suppriment tout le contenu des répertoires `workspace` (sauf les README.md)
  - Permettent de repartir de zéro entre les démos
  - Préservent la structure des répertoires

## 🛠️ Installation et Configuration Détaillées

Pour une installation complète et détaillée de l'environnement Roo, nous avons préparé un guide exhaustif qui couvre:

- **Installation système de VSCode** et personnalisation initiale
- **Installation des prérequis** (Python, Node.js, extensions)
- **Configuration complète de Roo**:
  - Acquisition et configuration des clés API
  - Paramétrage de la langue et des préférences
  - Configuration des profils de modèles économiques
  - Réglage des autorisations et du contexte
- **Installation et configuration des MCPs** (Model Context Protocol servers)
- **Présentation détaillée des modes** et création de modes personnalisés

👉 [Accéder au guide d'installation complet](./docs/installation-complete.md)

##  Guide de Démarrage Rapide (10 min)

### Ce dont vous avez besoin
- Un ordinateur avec Windows ou Mac
- Visual Studio Code (un éditeur gratuit facile à utiliser)
- Une connexion internet

### Installation en 4 étapes simples
1. **Téléchargez ou clonez ce répertoire**
   - Utilisez la commande Git pour cloner ce dépôt
   - Ou téléchargez-le sous forme d'archive ZIP et extrayez-le

2. **Installez Visual Studio Code**
   - Téléchargez-le gratuitement sur [le site officiel](https://code.visualstudio.com/)
   - Suivez les instructions d'installation standard

3. **Ajoutez l'extension Roo**
   - Ouvrez Visual Studio Code
   - Cliquez sur l'icône des extensions dans la barre latérale (ou appuyez sur Ctrl+Shift+X)
   - Recherchez "Roo" et cliquez sur "Installer"

4. **Configurez votre environnement**
   - Exécutez le script d'installation unifié:
     ```
     # Windows
     .\install-demo.ps1
     ```
   - Suivez les instructions à l'écran pour configurer votre environnement

### Comment utiliser les démos
1. **Ouvrir une démo spécifique**
   - Ouvrez VS Code
   - Utilisez `Fichier > Ouvrir le dossier` et naviguez jusqu'au répertoire de la démo souhaitée
   - Par exemple: `01-decouverte/demo-1-conversation/workspace`

2. **Préparer l'environnement**
   - Ouvrez un terminal dans VS Code (`Terminal > Nouveau terminal`)
   - Exécutez le script de préparation depuis la racine du dépôt:
     ```
     # Windows
     .\prepare-workspaces.ps1
     ```

3. **Suivre les instructions**
   - Ouvrez le fichier README.md de la démo
   - Suivez les instructions pas à pas
   - Utilisez le panneau Roo en cliquant sur l'icône Roo dans la barre latérale

4. **Réinitialiser entre les démos**
   - Exécutez le script de nettoyage depuis la racine du dépôt:
     ```
     # Windows
     .\clean-workspaces.ps1
     ```


## 🚀 Deux Approches pour Utiliser les Démos

Vous pouvez explorer les démos de deux façons différentes, selon vos préférences et objectifs:

### 📂 Approche Manuelle (Navigation par Répertoire)

Cette approche vous permet d'explorer chaque démo individuellement et d'interagir directement avec chaque exemple:

1. **Navigation dans les répertoires thématiques**
   - Parcourez les dossiers (`01-decouverte`, `02-orchestration-taches`, etc.)
   - Choisissez une démo spécifique (ex: `demo-1-conversation`)
   - Ouvrez le dossier `workspace` correspondant

2. **Ouverture d'instances VSCode dédiées**
   - Pour chaque démo, ouvrez une instance VSCode dédiée:
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

**Avantages:**
- Exploration approfondie de chaque démo
- Expérience d'apprentissage progressive
- Possibilité d'expérimenter librement dans chaque workspace

**Inconvénients:**
- Nécessite de naviguer entre plusieurs instances VSCode
- Processus plus manuel et potentiellement plus long

### 🔄 Approche Automatisée (Orchestration Globale)

Cette approche utilise le mode Orchestrateur de Roo pour exécuter automatiquement plusieurs démos:

1. **Utilisation de l'instance principale de VSCode**
   - Restez dans l'instance VSCode ouverte à la racine du projet
   - Pas besoin d'ouvrir plusieurs fenêtres ou instances

2. **Création d'une tâche d'orchestration**
   - Ouvrez le panneau Roo et créez une nouvelle tâche
   - Sélectionnez le mode "🪃 Orchestrateur"
   - Utilisez un prompt qui spécifie les démos à exécuter

3. **Exemple de prompt pour l'orchestrateur:**
   ```
   Exécute les démos suivantes dans l'ordre:
   1. 01-decouverte/demo-1-conversation
   2. 03-assistant-pro/demo-1-analyse
   
   Pour chaque démo:
   - Concentre-toi uniquement sur le répertoire workspace correspondant
   - Exécute les tâches de manière non interactive
   - Documente toutes les étapes dans le rapport de terminaison
   - Respecte les instructions du README.md de chaque démo
   ```

4. **Exemples détaillés de prompts d'orchestration**
   - Pour des exemples complets et détaillés de prompts d'orchestration, consultez [le guide d'orchestration des démos](./docs/orchestration_demos.md)
   - Ce document contient des prompts prêts à l'emploi pour différentes démos et des conseils pour une orchestration efficace

5. **Exécution d'une démo spécifique**
   - Pour exécuter une seule démo, précisez-la dans votre prompt:
   ```
   Exécute uniquement la démo 02-orchestration-taches/demo-1-planification.
   Suis les instructions du README.md et génère un rapport complet.
   ```

**Avantages:**
- Processus automatisé nécessitant moins d'intervention
- Vue d'ensemble de plusieurs démos en une seule session
- Documentation automatique des résultats
- Idéal pour les présentations ou démonstrations rapides

**Inconvénients:**
- Expérience moins interactive et personnalisée
- Moins adapté à l'apprentissage progressif
- Peut être plus complexe à configurer initialement

## 🎮 Parcours de Découverte Progressif (30-45 min)

Voici un parcours recommandé pour découvrir Roo pas à pas, adapté à différents profils d'utilisateurs:

### Pour les débutants (45-60 min)
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

## 🛠️ Dépannage et Assistance

### Problèmes courants et solutions

#### L'extension Roo ne se charge pas
- Vérifiez que vous avez la dernière version de VS Code
- Désinstallez et réinstallez l'extension
- Redémarrez VS Code après l'installation

#### Les scripts de préparation/nettoyage ne fonctionnent pas
- **Windows**: Assurez-vous d'exécuter PowerShell en tant qu'administrateur
- **Mac/Linux**: Vérifiez que les scripts ont les permissions d'exécution (`chmod +x *.sh`)
- Vérifiez que vous êtes bien dans le répertoire racine du projet

#### Roo ne répond pas comme prévu
- Assurez-vous d'avoir sélectionné le bon mode pour votre tâche
- Essayez de reformuler votre question de manière plus précise
- Vérifiez votre connexion internet

#### Les fichiers ne s'affichent pas dans le workspace
- Exécutez à nouveau le script de préparation
- Vérifiez que vous êtes dans le bon répertoire
- Rafraîchissez l'explorateur de fichiers de VS Code

### Comment obtenir de l'aide
- **Documentation en ligne**: Consultez [docs.roo.ai](https://docs.roo.ai) pour des guides détaillés
- **Forum communautaire**: Posez vos questions sur [community.roo.ai](https://community.roo.ai)
- **Support technique**: Contactez l'équipe à [support@roo.ai](mailto:support@roo.ai)
- **Tutoriels vidéo**: Regardez les démonstrations sur [learn.roo.ai/videos](https://learn.roo.ai/videos)

## 💻 Compatibilité avec votre ordinateur

### Windows
- Fonctionne parfaitement sur Windows 10 et 11
- Installation simple et rapide
- Aucune configuration technique nécessaire

### Mac
- Compatible avec tous les Mac récents
- Installation identique à Windows
- Performances optimales sur macOS Monterey et versions plus récentes

### Conseils pratiques
- Roo fonctionne mieux avec une connexion internet stable
- Pas besoin d'un ordinateur puissant, il utilise principalement des ressources en ligne
- Vos données restent privées et sécurisées

## 🧹 Réinitialisation des espaces de travail

Pour réinitialiser tous les espaces de travail et recommencer la démo à zéro, utilisez les scripts de nettoyage fournis:

### Windows
```powershell
.\clean-workspaces.ps1
```

Ces scripts suppriment tout le contenu des répertoires workspace tout en préservant les fichiers README.md et les répertoires eux-mêmes.

## 📚 Pour aller plus loin

### Documentation locale
- [Guide de maintenance](./docs/demo-maintenance.md) - Instructions pour maintenir et faire évoluer la démo
- [Guide d'installation complet](./docs/installation-complete.md) - Instructions détaillées pour l'installation

### Guides et tutoriels
- [Guide du débutant](https://docs.roo.ai/guide) - Apprenez les bases pas à pas
- [Exemples d'utilisation](https://docs.roo.ai/examples) - Inspirez-vous de cas concrets
- [Vidéos tutorielles](https://learn.roo.ai/videos) - Apprenez visuellement

### Communauté et aide
- [Forum d'entraide](https://community.roo.ai) - Partagez avec d'autres utilisateurs
- [Centre d'assistance](https://help.roo.ai) - Trouvez des réponses à vos questions
- [Webinaires mensuels](https://roo.ai/webinars) - Participez à des sessions en direct

### Formations
- [Ateliers en ligne](https://learn.roo.ai/workshops) - Perfectionnez-vous avec des experts
- [Certification utilisateur](https://learn.roo.ai/certification) - Validez vos compétences

---

## 🤝 Partagez votre expérience

Nous améliorons constamment Roo grâce à vos retours:
- Partagez vos succès avec Roo
- Suggérez de nouvelles fonctionnalités
- Racontez comment Roo a transformé votre façon de travailler

---

*Roo - Votre assistant intelligent au quotidien* ❤️

---

[Guide de contribution](./CONTRIBUTING.md) | [Guide d'intégration](./README-integration.md)