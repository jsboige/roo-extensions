# Architecture de Référence : Industrialisation de Roo avec Dev Containers

Ce document a pour but de définir une architecture complète et détaillée pour l'utilisation de VS Code Dev Containers dans notre écosystème Roo. Il est conçu pour être enrichi de manière incrémentale.

*(Suivi de taille - Ne pas supprimer : 207 lignes / 1500)*

---

## 1. Vision Cible et Objectifs Stratégiques

L'objectif de cette démarche d'industrialisation est de résoudre les problèmes de stabilité et de maintenabilité actuels en passant à un modèle basé sur des conteneurs de développement. La vision à long terme dépasse la simple résolution de bugs et vise à construire une plateforme de travail robuste et centralisée.

Les objectifs stratégiques sont :

1.  **Stabilité et Reproductibilité Absolues :** Chaque instance de Roo, quel que soit le projet ou la machine hôte, doit s'exécuter dans un environnement identique, isolé et pré-configuré. Cela élimine les conflits et garantit que chaque développeur travaille avec la même pile logicielle.

2.  **Tableau de Bord Centralisé :** Mettre en place une interface (potentiellement web) qui permettra de visualiser l'état de toutes les instances Roo actives. Ce tableau de bord servira de point d'entrée pour lancer de nouvelles sessions, suivre les conversations en cours, et gérer le cycle de vie des environnements de développement.

3.  **Agent Manager (Vision à Long Terme) :** L'architecture doit anticiper une évolution future vers un "Agent Manager". Ce composant serait capable de superviser les sessions Roo, de mettre en pause et de reprendre des tâches complexes, voire de gérer des transferts de contexte entre différentes instances, posant ainsi les bases d'un système multi-agents collaboratif.

## 2. Analyse Technique des Composants Fondamentaux

*Cette section sert de "Deep Dive" sur chaque brique technologique pour comprendre son fonctionnement interne.*

### 2.1. Cycle de Vie d'un Dev Container

Le cycle de vie d'un Dev Container est orchestré par VS Code et son extension Dev Containers. Il suit une séquence d'étapes précises, depuis la lecture de la configuration jusqu'à ce que l'environnement de développement soit pleinement fonctionnel.

#### Phase 1 : Résolution de la Configuration

1.  **Lecture du `devcontainer.json`** : VS Code recherche un fichier `.devcontainer/devcontainer.json` (ou `.devcontainer.json`) à la racine du projet. Ce fichier est le point d'entrée qui définit comment l'environnement doit être construit et configuré.
2.  **Fusion des configurations** : Le système peut fusionner plusieurs couches de configuration (par exemple, depuis les *features* ou les métadonnées de l'image de base) pour obtenir la configuration finale.

#### Phase 2 : Construction de l'Image (Build)

Cette phase n'est exécutée que si l'image Docker spécifiée n'existe pas déjà localement ou si une reconstruction est explicitement demandée.

*   **Dockerfile ou Image ?**
    *   Si le `devcontainer.json` pointe vers un **`Dockerfile`**, VS Code lance un `docker build` pour créer une nouvelle image. C'est ici que les dépendances système (via `apt`, `yum`, etc.) et les outils de base sont installés.
    *   S'il pointe vers une **`image`** déjà existante (sur Docker Hub, GHCR, etc.), Docker la télécharge (`docker pull`).
*   **Application des *Features*** : Les "Dev Container Features" sont ensuite appliquées. Ce sont des scripts d'installation modulaires qui ajoutent des outils (comme `git`, `Azure CLI`, `kubectl`) par-dessus l'image de base.

#### Phase 3 : Création et Démarrage du Conteneur

Une fois l'image prête, Docker crée et démarre un nouveau conteneur à partir de celle-ci.

1.  **Création du Conteneur** : `docker run` est exécuté en utilisant l'image finale. C'est à ce moment que les montages de volumes (pour le code source) et les redirections de ports sont établis.
2.  **`initializeCommand`** : Cette commande (si définie) est exécutée sur la **machine hôte** avant même que le conteneur ne soit complètement créé. Elle est utile pour des préparations qui doivent avoir lieu en dehors du conteneur.
3.  **`onCreateCommand`** : S'exécute **une seule fois, à l'intérieur du conteneur**, juste après sa toute première création. Idéal pour des installations qui ne doivent pas être répétées (par exemple, initialiser une base de données).
4.  **`updateContentCommand`** : S'exécute après la commande précédente, également lors de la création. Son but est de s'assurer que le contenu est à jour, et elle peut être ré-exécutée dans des scénarios de pré-build.
5.  **`postCreateCommand`** : C'est la **dernière étape de la phase de création**. Elle s'exécute une seule fois, après les deux commandes précédentes. C'est ici que l'on peut cloner des dépendances (`npm install`, `pip install`) ou effectuer des configurations qui nécessitent que le code source soit présent. C'est l'équivalent du "one-shot setup".

#### Phase 4 : Démarrages Subséquents

Pour tous les démarrages suivants (après la création initiale), les étapes de build et de `postCreateCommand` sont ignorées.

*   **`postStartCommand`** : Cette commande est exécutée **à chaque fois que le conteneur démarre**. C'est l'endroit parfait pour lancer des services (comme une base de données ou un serveur de développement) qui doivent être actifs pendant la session de développement. La principale différence avec `postCreateCommand` est sa récurrence : `postCreateCommand` est pour l'installation, `postStartCommand` est pour l'exécution.

#### Phase 5 : Connexion de VS Code

1.  **Installation du VS Code Server** : L'extension Dev Containers injecte et installe un petit serveur VS Code à l'intérieur du conteneur. Ce serveur est un agent léger qui agit comme un pont entre l'interface utilisateur de VS Code (qui s'exécute localement) et l'environnement du conteneur.
2.  **Connexion et Activation des Extensions** : VS Code se connecte à ce serveur. Les extensions listées dans `devcontainer.json` sont installées et activées à l'intérieur du conteneur, donnant accès à l'IntelliSense, au débogage, et aux terminaux comme si le développement se faisait en local.
3.  **`postAttachCommand`** : Cette dernière commande s'exécute **chaque fois que VS Code s'attache au conteneur**. Elle est utile pour des actions spécifiques à l'IDE, comme afficher un message de bienvenue ou ouvrir un fichier particulier.
### 2.2. Mécanismes de Persistance Docker

La gestion des données est cruciale dans un environnement conteneurisé. Docker propose deux mécanismes principaux pour persister les données au-delà du cycle de vie d'un conteneur : les **volumes** et les **bind mounts**. Comprendre leurs différences est essentiel pour construire une architecture stable et performante.

#### Définitions

*   **Volumes Docker** : Ce sont des zones de stockage entièrement gérées par Docker. Un volume est un répertoire créé sur la machine hôte, mais dans une partie du système de fichiers gérée par Docker (`/var/lib/docker/volumes/` sur Linux par défaut). Ils sont la méthode recommandée pour persister les données générées par les conteneurs. Les volumes sont indépendants du cycle de vie du conteneur, ce qui signifie qu'un volume n'est pas supprimé lorsqu'un conteneur qui l'utilise est supprimé.

*   **Bind Mounts** : Un bind mount est un lien direct qui mappe un fichier ou un répertoire de la machine hôte vers un conteneur. Le chemin sur l'hôte est arbitraire et n'est pas géré par Docker. Cette méthode donne des performances quasi-natives car elle accède directement au système de fichiers de l'hôte, mais elle crée un couplage fort entre le conteneur et la structure de fichiers de la machine hôte.

#### Tableau Comparatif

| Caractéristique | Volumes Nommés | Bind Mounts |
| :--- | :--- | :--- |
| **Gestion** | Entièrement gérée par l'API et la CLI de Docker (création, inspection, suppression). | Gérée manuellement par l'utilisateur via les chemins du système de fichiers de l'hôte. |
| **Portabilité** | **Élevée**. Agnostique de la structure de l'hôte. Facile à migrer et à sauvegarder. | **Faible**. Dépend d'un chemin spécifique sur la machine hôte. |
| **Performance** | **Haute performance**, mais avec une très légère surcouche sur Linux due au système de fichiers de Docker. | **Performance maximale** (quasi-native), car c'est un accès direct au système de fichiers de l'hôte. |
| **Sécurité** | **Plus sécurisé**. Isolé de la structure de fichiers de l'hôte. | **Moins sécurisé**. Un conteneur peut modifier le système de fichiers de l'hôte, y compris des fichiers critiques. |
| **Initialisation** | Peut être pré-rempli avec le contenu du conteneur si le volume est créé vide. | Le contenu de l'hôte masque toujours le contenu du conteneur. |
| **Cas d'usage typiques**| Bases de données, données d'application, configurations gérées, logs. | Partage de code source pour le développement, partage de fichiers de configuration de l'hôte vers le conteneur. |

#### Avantages et Inconvénients pour le Projet Roo

Dans le contexte de notre projet d'industrialisation de Roo, le choix entre volume et bind mount dépendra du type de données à persister.

*   **Persistance des conversations et des tâches de Roo** :
    *   **Avantages (Volumes)** : La gestion centralisée via Docker simplifie les sauvegardes et les migrations. La portabilité garantit que nos conteneurs fonctionneront sur n'importe quelle machine, sans se soucier de l'emplacement des données.
    *   **Inconvénients (Bind Mounts)** : Lier ces données à un répertoire spécifique sur l'hôte rendrait notre solution fragile et difficile à déployer à grande échelle.

*   **Synchronisation du code source du projet** :
    *   **Avantages (Bind Mounts)** : C'est le cas d'usage par excellence. Le développeur modifie les fichiers sur sa machine hôte avec son IDE, et les modifications sont immédiatement reflétées dans le conteneur. Les performances sont critiques pour une expérience de développement fluide.
    *   **Inconvénients (Volumes)** : Utiliser un volume pour le code source serait contre-productif, car il faudrait des mécanismes supplémentaires pour synchroniser les fichiers entre l'hôte et le volume.

*   **Partage des paramètres VS Code et des extensions** :
    *   **Avantages (Bind Mounts)** : Permet de réutiliser la configuration VS Code de l'utilisateur (paramètres, snippets, etc.) directement dans le conteneur, offrant une expérience transparente.
    *   **Inconvénients (Volumes)** : Moins pertinent, car ces fichiers sont généralement liés à l'environnement de l'utilisateur sur l'hôte.

#### Recommandation Stratégique

Notre stratégie de persistance doit être hybride et guidée par la nature des données :

1.  **Utiliser les Volumes Nommés par défaut pour toutes les données applicatives de Roo.**
    *   **Exemples** : Historiques de conversation, état des tâches, bases de données internes, logs générés par Roo.
    *   **Raison** : Cela garantit la portabilité, la sécurité et la facilité de gestion de notre architecture. Les données sont découplées de la machine hôte, ce qui est un pilier de notre vision d'industrialisation.

2.  **Utiliser les Bind Mounts exclusivement pour le développement et la configuration de l'environnement.**
    *   **Exemples** :
        *   Le répertoire du projet contenant le code source (`/workspaces/mon-projet`).
        *   Les fichiers de configuration de l'utilisateur (ex: `.gitconfig` de l'hôte).
        *   Potentiellement, le cache de dépendances (comme `.m2`, `.npm`) pour accélérer les builds, en acceptant le compromis sur la portabilité.
    *   **Raison** : Les bind mounts sont imbattables pour la synchronisation en temps réel du code, ce qui est essentiel pour une boucle de développement rapide.

Cette approche nous permet de bénéficier du meilleur des deux mondes : la robustesse et la portabilité des volumes pour les données critiques, et la flexibilité et la performance des bind mounts pour l'environnement de développement.
### 2.3. Fonctionnement Approfondi de VS Code

Pour bâtir une architecture Dev Containers véritablement robuste, il ne suffit pas de savoir écrire un `Dockerfile`. Il est impératif de maîtriser les rouages internes de Visual Studio Code lui-même. Cette section plonge au cœur de la mécanique de l'éditeur pour décortiquer les cinq piliers sur lesquels repose une configuration industrialisée : la gestion des contextes via les **Profils**, la cascade de la **Hiérarchie des paramètres**, le modèle client-serveur de la **Gestion des extensions**, la synergie avec **WSL** sur Windows, et enfin, l'intégration de l'IA via le **Model Context Protocol (MCP)**.

#### 2.3.1. Les Profils : Isolation et Standardisation des Contextes

Un **Profil VS Code** est un "instantané" d'une configuration de VS Code, permettant de créer des environnements de travail distincts et de basculer rapidement entre eux. Chaque profil peut encapsuler :
- Les **paramètres** (`settings.json`).
- Les **extensions**.
- La **disposition de l'UI** (vues, panneaux, etc.).
- Les **raccourcis clavier** (`keybindings.json`).
- Les **snippets** utilisateur.

##### Structure et Contenu d'un Profil

Lorsqu'un profil est exporté, il prend la forme d'un fichier `.code-profile`. Ce fichier est une archive `JSON` qui contient la configuration du profil. Voici un exemple de sa structure interne :

```json
{
  "name": "Roo-Base",
  "settings": "{... contenu du settings.json du profil ...}",
  "extensions": [
    {
      "id": "eamodio.gitlens",
      "version": "14.9.0"
    },
    {
      "id": "esbenp.prettier-vscode",
      "version": "10.4.0"
    }
  ],
  "uiState": "{... contenu du storage.json pour l'UI ...}"
}
```
Cette structure nous permet de versionner nos environnements de travail de manière très précise.

##### Cas d'Usage Avancés

-   **Profils Temporaires (`Temporary Profiles`)** : VS Code permet de créer un profil "jetable" pour la session en cours. C'est extrêmement utile pour :
    -   **Isoler un bug :** Démarrer avec un profil vide permet de vérifier si un problème vient de VS Code ou d'une extension/configuration spécifique.
    -   **Revue de code :** Analyser une pull request avec un ensemble minimal d'extensions pour ne pas être distrait.
-   **Profils par Tâche :** Au sein d'un même projet, un développeur peut basculer entre un profil "Développement" (avec linters, débogueur, etc.) et un profil "Rédaction Technique" (avec des outils comme `markdownlint`, `Code Spell Checker`).

##### Stratégie pour Roo

1.  **Profil de Base `Roo-Default` :** Un profil versionné dans notre dépôt principal, contenant les extensions et paramètres transverses (Git, Prettier, Docker, ...). Il sera la fondation de tous nos environnements.
2.  **Profils Spécialisés `Roo-[Stack]` :** Pour chaque stack technique (Python, Web, etc.), nous fournirons un profil qui **copie** le profil `Roo-Default` et y ajoute les extensions et configurations spécifiques (par exemple, les extensions Python/Pylance/Ruff pour le profil `Roo-Python`).
3.  **Intégration au Dev Container :** Le `devcontainer.json` pourra être configuré pour utiliser un profil spécifique au démarrage, garantissant que l'environnement est non seulement conteneurisé mais aussi pré-configuré pour la tâche à accomplir.
4.  **Onboarding :** Les nouveaux arrivants n'auront qu'à importer le profil correspondant à leur projet pour avoir un IDE 100% opérationnel, réduisant le temps de configuration de plusieurs heures à quelques secondes.

#### 2.3.2. La Hiérarchie des Paramètres (`settings.json`) : Un Contrôle Fin

VS Code utilise un système de surcharge puissant pour fusionner les paramètres de différentes sources. La configuration la plus spécifique l'emporte toujours.

**Ordre de Priorité (du plus faible au plus fort) :**
1.  **Paramètres Utilisateur (`User Settings`)** : La base de configuration personnelle.
2.  **Paramètres du Profil (`Profile Settings`)** : Surcharge les paramètres Utilisateur lorsque le profil est actif.
3.  **Paramètres Distants (`Remote [Dev Container]`)** : Définis dans `devcontainer.json`, ils s'appliquent spécifiquement à l'intérieur du conteneur.
4.  **Paramètres du Workspace (`Workspace Folder Settings`)** : Situés dans `.vscode/settings.json`, ils ont la priorité la plus élevée.

##### Exemple Concret de Cascade

Imaginons que nous voulions configurer la taille de la police (`editor.fontSize`).
-   **Niveau 1 : Utilisateur (`settings.json` global)**
    L'utilisateur préfère une grande police par défaut.
    `{ "editor.fontSize": 16 }`
-   **Niveau 2 : Profil (`Roo-Default.code-profile`)**
    Le profil standard de Roo impose une taille plus conventionnelle.
    `{ "editor.fontSize": 14 }`
    *Résultat : La police est de 14 dans ce profil.*
-   **Niveau 3 : Dev Container (`devcontainer.json`)**
    Pour ce type de projet, nous voulons une police légèrement plus petite.
    `"settings": { "editor.fontSize": 13 }`
    *Résultat : La police est de 13 dans le conteneur.*
-   **Niveau 4 : Workspace (`.vscode/settings.json`)**
    Un développeur sur ce projet spécifique a besoin d'une taille plus grande pour une présentation.
    `{ "editor.fontSize": 15 }`
    *Résultat final : La police affichée dans VS Code pour ce projet sera de **15**.*

##### Fusion vs. Remplacement

Il est crucial de comprendre que le comportement de surcharge varie selon le type de donnée :
-   **Valeurs Primitives (string, number, boolean) :** La valeur du niveau le plus prioritaire **remplace** purement et simplement les autres. (`editor.fontSize` est un bon exemple).
-   **Objets JSON :** Les propriétés des objets sont **fusionnées (merged)**. La valeur d'une clé spécifique dans un niveau supérieur remplace celle du niveau inférieur, mais les autres clés sont conservées.

**Exemple de fusion avec `workbench.colorCustomizations` :**
-   **Profil `Roo-Default` :** `{ "workbench.colorCustomizations": { "activityBar.background": "#333333" } }`
-   **Workspace `.vscode/settings.json` :** `{ "workbench.colorCustomizations": { "statusBar.background": "#555555" } }`

**Résultat final :** VS Code appliquera les deux personnalisations.
`{ "activityBar.background": "#333333", "statusBar.background": "#555555" }`

Cette distinction est la clé pour construire une configuration modulaire et non-répétitive, en définissant des bases solides tout en permettant des ajustements chirurgicaux.

#### 2.3.3. Gestion des Extensions : Le Bon Outil au Bon Endroit

La puissance du développement à distance avec VS Code repose sur une architecture client-serveur ingénieuse. Comprendre la distinction entre les extensions locales et distantes est fondamental pour optimiser l'environnement.

**Le "VS Code Server" : Le Cerveau Déporté**

Lorsque vous vous connectez à un environnement distant (conteneur, WSL, SSH), VS Code installe et exécute un composant léger appelé **VS Code Server**. Ce n'est pas une simple connexion ; ce serveur exécute une version "headless" (sans interface graphique) de VS Code directement dans l'environnement distant.

C'est ce serveur qui prend en charge toutes les opérations intensives :
- **Analyse du code** (IntelliSense, complétion)
- **Linting et formatage**
- **Débogage**
- **Exécution des terminaux**

L'instance locale de VS Code (le client) se contente de gérer l'interface utilisateur et de communiquer avec le serveur pour afficher les résultats. Cette séparation garantit une réactivité maximale de l'UI, même si le code et les outils se trouvent sur un serveur distant ou dans un conteneur lourd.

**UI vs. Workspace Extensions : Une Distinction Cruciale**

Cette architecture impose une séparation claire des extensions :

*   **UI Extensions** : Elles s'exécutent sur votre machine locale (le client) et personnalisent l'interface. Elles n'ont pas accès directement aux fichiers du projet distant.
    *   **Exemples typiques :** Thèmes de couleur (`workbench.colorTheme`), packs d'icônes (`workbench.iconTheme`), barres d'outils (`actboy.mqtt-client`), et certaines extensions de productivité qui n'interagissent pas avec le code.
*   **Workspace Extensions** : Elles sont installées et s'exécutent sur le **VS Code Server**, à l'intérieur du conteneur. Elles ont un accès direct au système de fichiers, au terminal et aux processus du conteneur. C'est ici que résident les outils qui travaillent sur votre code.
    *   **Exemples typiques :** Serveurs de langage (Microsoft `python.vscode-pylance`), linters (`dbaeumer.vscode-eslint`), formateurs (`esbenp.prettier-vscode`), outils de test, et tout ce qui doit lire, modifier ou exécuter le code.

**Le Contrôle Manuel avec `remote.extensionKind`**

Bien que VS Code fasse un excellent travail pour deviner où chaque extension doit aller (en se basant sur les métadonnées fournies par le développeur de l'extension), des cas limites existent. Pour ces situations, vous pouvez forcer le comportement via le paramètre `remote.extensionKind` dans votre `settings.json` (au niveau `User` ou `Profile`).

Ce paramètre est un objet où les clés sont les identifiants uniques des extensions (ex: `eamodio.gitlens`) et les valeurs sont un tableau indiquant où elles doivent s'exécuter.

```json
// Dans le settings.json de votre Profil "User"
"remote.extensionKind": {
  // Forcer l'extension "Project Manager" à TOUJOURS s'exécuter sur l'UI locale.
  // Utile si vous voulez gérer tous vos projets depuis une seule interface,
  // même ceux dans des conteneurs.
  "alefragnani.project-manager": [ "ui" ],

  // Forcer l'extension "REST Client" à s'exécuter dans le conteneur.
  // Indispensable si les requêtes doivent partir du réseau du conteneur
  // (ex: pour atteindre un autre service docker-compose sur "localhost").
  "humao.rest-client": [ "workspace" ],

  // Certaines extensions peuvent avoir des composants des deux côtés.
  // Docker est un bon exemple : l'UI s'exécute localement, mais elle pilote
  // le moteur Docker, qui peut être distant.
  "ms-azuretools.vscode-docker": [ "ui", "workspace" ]
}
```

Prendre le temps de classifier correctement les extensions via `devcontainer.json` pour les projets et via `remote.extensionKind` pour les préférences personnelles est un investissement qui garantit un environnement de développement stable, prédictible et performant.

**Stratégie d'Extensions pour Roo**

En complément de la configuration `remote.extensionKind` pour les préférences personnelles, notre `devcontainer.json` standardisera un socle d'extensions de Workspace critiques pour la productivité et la cohérence :
- **`eamodio.gitlens`** : Pour une intégration Git avancée et une navigation aisée dans l'historique du code. Indispensable pour comprendre l'évolution des fichiers.
- **`esbenp.prettier-vscode`** : Garantit un formatage de code uniforme sur toute la base de code, éliminant les débats de style.
- **`ms-azuretools.vscode-docker`** : Permet d'inspecter et de gérer d'autres conteneurs (y compris ceux de la stack Roo) directement depuis l'environnement de développement. Essentiel pour le débogage d'architectures micro-services.
- **`mutantdino.resourcemonitor`** : Offre une visibilité sur la consommation CPU et mémoire du conteneur, aidant à identifier les goulots d'étranglement de performance.
- **`redhat.vscode-yaml`** : Fournit une validation et un IntelliSense pour les nombreux fichiers de configuration YAML que nous utilisons (Docker Compose, etc.).
- **`Codeium.codeium`** (ou `GitHub.copilot`) : Accélère le développement grâce à l'assistance par IA, directement intégrée dans l'éditeur. Leur présence sera standardisée dans tous nos environnements.

#### 2.3.4. Interaction avec WSL 2 : La Fondation d'Acier sur Windows

Sur Windows, pour atteindre un niveau de performance et d'intégration digne d'un environnement natif Linux, le passage par le **Windows Subsystem for Linux 2 (WSL 2)** n'est pas une option, mais une nécessité. Il constitue la fondation sur laquelle repose toute notre architecture Dev Containers sur les postes Windows.

**Architecture : Une Vraie VM Linux, Pas une Émulation**

Contrairement à WSL 1, WSL 2 n'est pas une couche de traduction d'appels système. C'est une **véritable machine virtuelle légère** qui fonctionne grâce à un sous-ensemble de fonctionnalités de Hyper-V. Elle embarque un **noyau Linux complet**, compilé et maintenu par Microsoft. Pour Docker Desktop, cela change tout : le démon Docker ne s'exécute plus dans une VM Hyper-V dédiée et opaque ("Moby"), mais directement au sein de l'intégration WSL 2, partageant ainsi les ressources de manière plus efficace avec le système hôte.

**Le Triptyque Gagnant : Performance, Intégration et Transparence**

Trois aspects de WSL 2 sont déterminants pour notre usage :

1.  **Performance du Système de Fichiers (le Point le plus Critique)**
    Le facteur qui dégrade le plus les performances de Docker sur Windows est l'accès aux fichiers montés depuis le système de fichiers Windows (NTFS) vers le conteneur Linux (ext4). La traduction entre ces deux mondes est extrêmement coûteuse.
    *   **Anti-pattern absolu :** Cloner un projet sur `C:\Users\...\Documents\mon-projet` et le monter dans un conteneur. Les opérations comme `npm install` ou une compilation C++ peuvent être jusqu'à **20 fois plus lentes**.
    *   **Bonne pratique impérative :** Le code source du projet doit **TOUJOURS** résider à l'intérieur du système de fichiers de la distribution WSL (`/home/votre-user/projets/`). Pour y accéder facilement depuis l'Explorateur Windows, il suffit de taper `\\wsl$` dans la barre d'adresse. VS Code facilite cette interaction en permettant de cloner un dépôt directement dans WSL via la commande `Git: Clone`.

2.  **Partage d'Identifiants Git (Git Credential Manager)**
    Un des points de friction majeurs du développement cross-environnement est la gestion des identifiants (SSH, tokens PAT). WSL 2 et VS Code résolvent ce problème de manière élégante.
    *   **Git Credential Manager (GCM) :** Sous Windows, GCM stocke de manière sécurisée les identifiants Git dans le Gestionnaire d'identification Windows.
    *   **Intégration transparente :** Lorsque vous exécutez `git push` ou `git pull` depuis le terminal d'un Dev Container (qui s'exécute lui-même dans WSL), Git à l'intérieur de WSL est configuré pour communiquer avec un helper sur l'hôte Windows. Ce helper fait appel au GCM.
    *   **Résultat :** Vous vous authentifiez une seule fois sur Windows (par exemple, via une pop-up de connexion OAuth à GitHub), et toutes vos sessions Git, que ce soit depuis PowerShell, un terminal WSL ou un terminal de Dev Container, partagent le même identifiant de manière transparente et sécurisée.

3.  **Intégration Réseau (`localhost` unifié)**
    Lorsqu'une application web tourne dans un conteneur et écoute sur le port 3000, WSL 2 mappe automatiquement `localhost:3000` depuis le conteneur vers `localhost:3000` sur l'hôte Windows. Vous pouvez donc ouvrir votre navigateur Chrome sur Windows et accéder directement à l'application tournant dans le conteneur, sans avoir à chercher l'adresse IP interne du conteneur. Cette fonctionnalité simplifie radicalement le débogage et les tests locaux.

En adoptant WSL 2 comme prérequis non négociable sur Windows, nous garantissons à nos développeurs une expérience qui rivalise en fluidité et en performance avec un développement natif sous Linux, tout en bénéficiant de l'écosystème logiciel Windows.

#### 2.3.5. Model Context Protocol (MCP) : Intégrer Roo au Cœur de l'IDE

Le **Model Context Protocol (MCP)** est la technologie qui va nous permettre de passer d'un agent conversationnel externe à un assistant de développement profondément intégré dans VS Code. C'est un standard ouvert qui définit comment un modèle d'IA (le "client") peut découvrir et interagir avec des capacités fournies par l'environnement (le "serveur").

**Les Trois Piliers du MCP**

Un serveur MCP expose trois types de capacités :

1.  **Outils (`Tools`)** : Ce sont des actions ou des fonctions exécutables que l'IA peut appeler. Chaque outil est défini par un nom, une description et un schéma JSON décrivant ses paramètres d'entrée. `L'IA peut décider d'appeler un outil pour accomplir une tâche.`
    *   *Exemple pour Roo : Un outil pour créer un nouveau fichier de test.*

2.  **Ressources (`Resources`)** : Ce sont des sources de données contextuelles que l'IA peut consulter. Elles sont identifiées par une URI et fournissent à l'IA des informations sur l'état actuel de l'environnement. `L'IA utilise les ressources pour s'ancrer dans la réalité du projet.`
    *   *Exemple pour Roo : Une ressource fournissant la liste des fichiers modifiés dans Git.*

3.  **Prompts** : Ce sont des modèles de requêtes pré-configurés qui combinent des instructions textuelles avec des références à des ressources. Ils guident l'IA pour effectuer des tâches complexes et répétitives. `L'IA utilise un prompt comme un "template" pour générer du contenu de haute qualité.`
    *   *Exemple pour Roo : Un prompt pour générer un rapport de bug qui inclut automatiquement le diagnostic du linter et les derniers logs applicatifs.*

**Exemple Concret : Configuration d'un Serveur MCP pour Roo**

Le `devcontainer.json` ou le `settings.json` permet de déclarer les serveurs MCP à utiliser. Voici à quoi pourrait ressembler une déclaration pour un serveur "Roo Assistant" :

```json
// Dans devcontainer.json -> "customizations.vscode.mcp"
// Ou dans settings.json -> "mcp.servers"
{
  "servers": [
    {
      "name": "RooAssistant",
      "command": [
        "node",
        "${workspaceFolder}/.roo/mcp-server.js"
      ],
      "description": "Fournit des outils et contextes spécifiques au projet Roo.",
      "requestFormat": "body",
      
      "tools": [
        {
          "name": "create_test_file",
          "description": "Crée un fichier de test pour un composant spécifié.",
          "input_schema": {
            "type": "object",
            "properties": {
              "component_path": { "type": "string", "description": "Chemin du composant à tester." }
            },
            "required": ["component_path"]
          }
        }
      ],

      "resources": [
        {
          "uri": "roo://git/modified_files",
          "description": "Retourne la liste des fichiers modifiés non commités.",
          "schema": {
            "type": "array",
            "items": { "type": "string" }
          }
        },
        {
          "uri": "roo://logs/latest",
          "description": "Retourne les 50 dernières lignes du fichier de log principal.",
          "schema": { "type": "string" }
        }
      ],

      "prompts": [
        {
          "name": "generate_bug_report",
          "description": "Génère un rapport de bug structuré.",
          "template": [
            { "text": "Rédige un rapport de bug pour le problème suivant. Sois concis et précis.\n\n" },
            { "text": "**Fichiers Modifiés Pertinents:**\n{{modified_files}}\n\n" },
            { "resource": "roo://git/modified_files", "as": "modified_files" },
            { "text": "**Derniers Logs Applicatifs:**\n```\n{{latest_logs}}\n```" },
            { "resource": "roo://logs/latest", "as": "latest_logs" }
          ]
        }
      ]
    }
  ]
}
```

En intégrant un tel serveur MCP dans nos Dev Containers, chaque développeur dispose, dès le démarrage, d'une instance de Roo "context-aware". Roo n'est plus un simple chatbot, il peut "voir" l'état du projet (via les ressources) et "agir" sur celui-ci (via les outils), ce qui constitue un avantage stratégique fondamental pour notre productivité.
#### 2.3.6. Concepts Avancés pour une Gouvernance Complète

Pour finaliser notre maîtrise de l'environnement, trois concepts supplémentaires doivent être intégrés à notre stratégie.

**Workspace Trust : La Sécurité d'Abord**

La fonctionnalité "Workspace Trust" est un mécanisme de sécurité qui protège contre l'exécution de code potentiellement malveillant. Lorsqu'un dossier est ouvert, VS Code peut le faire en "Mode Restreint" : les tâches, le débogage et certaines extensions sont désactivés jusqu'à ce que l'utilisateur déclare explicitement faire confiance ("Trust") à ce dossier.
- **Implication pour les Dev Containers :** La confiance est accordée au niveau du dossier sur la machine hôte. Une fois que vous faites confiance au dossier contenant votre projet et son `devcontainer.json`, cette confiance s'étend au conteneur lui-même.
- **Stratégie Roo :** Nous devons informer les développeurs de ce mécanisme. Nos scripts d'onboarding pourraient inclure une étape pour s'assurer que les dossiers de projets principaux sont ajoutés à la liste des emplacements de confiance de l'utilisateur, afin d'éviter les frictions lors de l'ouverture des Dev Containers.

**Gestion des "Dotfiles" : Personnalisation de l'Environnement Shell**

Les développeurs ont souvent des configurations de shell hautement personnalisées (`.bashrc`, `.zshrc`, alias, etc.) stockées dans des "dotfiles" (fichiers de configuration commençant par un point). L'extension Dev Containers offre une intégration native pour cloner un dépôt Git de dotfiles et appliquer sa configuration à l'intérieur de chaque nouveau conteneur.
- **Configuration :** Dans le `devcontainer.json`, on peut spécifier l'URL du dépôt Git contenant les dotfiles de l'utilisateur.
- **Stratégie Roo :** Nous encouragerons chaque développeur à maintenir son propre dépôt de dotfiles. De plus, nous fournirons un **dépôt de dotfiles "Roo" de référence** contenant des alias et des fonctions shell utiles pour interagir avec notre écosystème. Les développeurs pourront le forker et l'adapter. Cela garantit que chaque conteneur est non seulement configuré par VS Code, mais que l'environnement de ligne de commande est également familier et puissant.

**Interaction avec "Settings Sync"**

Settings Sync est la fonctionnalité intégrée à VS Code qui synchronise les paramètres, extensions et profils via un compte Microsoft ou GitHub. Il est essentiel de comprendre comment elle cohabite avec notre architecture.
- **Le Rôle de chaque Outil :**
    - **Settings Sync :** Assure la portabilité de la configuration **personnelle** d'un utilisateur d'une machine à l'autre. C'est l'état "de base" de l'IDE de l'utilisateur.
    - **Profils (`.code-profile`) :** Gèrent des ensembles de configurations **spécifiques à une tâche ou un contexte**, qui peuvent être partagés et versionnés. Ils modifient temporairement l'état de base.
    - **Dev Containers (`devcontainer.json`) :** Forcent une configuration **spécifique à un projet** et à son environnement d'exécution. C'est le niveau le plus autoritaire.
- **Stratégie Roo :** Settings Sync est un outil personnel que nous encourageons. Notre architecture basée sur les Profils et les Dev Containers ne la remplace pas mais s'y superpose. La hiérarchie des paramètres garantit que la configuration du projet (`devcontainer.json`) aura toujours le dernier mot, assurant la cohérence, tout en laissant à l'utilisateur la liberté de synchroniser sa configuration de base personnelle entre ses différentes machines.

### 2.4. Stockage des Données Roo (Tâches et Conversations)

L'analyse technique du code de l'extension Roo et du MCP `roo-state-manager` révèle une architecture de stockage à deux niveaux. Il n'y a **aucune utilisation de Qdrant** ou de base de données vectorielle dans ce périmètre. Le stockage repose entièrement sur des fichiers au format `JSON`.

Pour garantir la pérennité des données dans un environnement conteneurisé, il est essentiel de comprendre et de persister deux ensembles de données distincts : le **stockage principal** (les données brutes de l'extension) et le **cache secondaire** (les données traitées par le `roo-state-manager`).

#### 2.4.1. Stockage Principal : Les Données de l'Extension VS Code

Il s'agit de la source de vérité contenant toutes les conversations, les tâches, et les métadonnées générées par l'utilisateur via l'extension Roo.

-   **Responsable :** L'extension VS Code `Roo` (ex: `rooveterinaryinc.roo-cline`).
-   **Format :** Fichiers `JSON` (`api_conversation_history.json`, `ui_messages.json`, `task_metadata.json`).
-   **Emplacement :** Le `roo-state-manager` est programmé pour détecter dynamiquement cet emplacement en scannant une liste de chemins standards où VS Code stocke les données globales des extensions. Ces chemins varient selon l'OS :
    -   **Windows :** `%APPDATA%\Code\User\globalStorage`
    -   **macOS :** `~/Library/Application Support/Code/User/globalStorage`
    -   **Linux :** `~/.config/Code/User/globalStorage`

-   **Structure attendue :**
    ```
    <chemin_global_storage>/
    └── rooveterinaryinc.roo-cline-1.0.0/
        ├── settings/
        │   └── ...
        └── tasks/
            ├── <task_id_1>/
            │   ├── api_conversation_history.json
            │   ├── ui_messages.json
            │   └── task_metadata.json
            └── <task_id_2>/
                └── ...
    ```

#### 2.4.2. Stockage Secondaire : Le Cache du `roo-state-manager`

Pour optimiser les performances, le `roo-state-manager` maintient son propre cache persistant sur le disque. Ce cache stocke des données agrégées ou fréquemment consultées, comme les arbres de tâches ou les résultats de recherches.

-   **Responsable :** Le processus MCP `roo-state-manager`.
-   **Format :** Fichiers `JSON` gérés par la bibliothèque de cache.
-   **Emplacement :** L'emplacement est relatif au répertoire de travail (`process.cwd()`) du serveur MCP. Par défaut, il est configuré pour être :
    -   `./.cache/roo-state-manager/`

Le code pertinent dans `cache-manager.ts` confirme cette configuration :
```typescript
this.config = {
  // ... autres options
  persistToDisk: true,
  cacheDir: join(process.cwd(), '.cache', 'roo-state-manager'),
  // ...
};
```

#### 2.4.3. Recommandation : Volumes à Persister

Pour assurer une persistance complète des données de Roo dans un environnement Docker, les deux emplacements de stockage doivent être montés en tant que **volumes nommés**. L'utilisation de bind mounts est déconseillée pour ces données afin de préserver la portabilité de la solution.

**Liste des répertoires à faire persister :**

1.  **Le répertoire `globalStorage` de VS Code :** C'est le point le plus critique. Il contient non seulement les données de Roo, mais aussi celles de nombreuses autres extensions. Il faut donc monter le répertoire parent contenant les données de l'extension Roo. Le chemin exact dépend du nom de l'extension mais suivra ce modèle :
    -   **Chemin source dans le conteneur :** `/home/vscode/.vscode-server/data/User/globalStorage/rooveterinaryinc.roo-cline*`
    -   **Recommandation de Volume :** Créer un volume Docker `roo-data` et le monter sur le `globalStorage`
        - **Exemple `docker-compose.yml`:**
          ```yaml
          services:
            my-dev-container:
              # ...
              volumes:
                - roo-vscode-data:/home/vscode/.vscode-server/data/User/globalStorage
          volumes:
            roo-vscode-data:
          ```

2.  **Le répertoire de cache du `roo-state-manager` :** Ce répertoire est créé par le MCP lui-même. Sa persistance est nécessaire pour conserver les optimisations de performance entre les redémarrages.
    -   **Chemin source dans le conteneur :** `/<chemin_vers_le_workspace>/.cache/roo-state-manager` (Le chemin dépend d'où le MCP est lancé)
    -   **Recommandation de Volume :** Créer un volume Docker séparé `roo-cache`
         - **Exemple `docker-compose.yml`:**
          ```yaml
          services:
            my-dev-container:
              # ...
              volumes:
                 - roo-vscode-data:/home/vscode/.vscode-server/data/User/globalStorage
                 - roo-cache:/workspace/.cache # Monter sur le parent pour capturer tous les caches
          volumes:
            roo-vscode-data:
            roo-cache:
          ```

En montant ces deux emplacements, nous garantissons que l'état complet de Roo (tâches, conversations et cache de performance) est préservé, rendant notre environnement de développement conteneurisé stable et fiable.

## 3. Scénarios d'Intégration et de Migration

*Cette section documentera comment appliquer la technologie Dev Container à nos différents cas d'usage.*

### 3.1. Scénario 1 : Projet Standard (Dépôt Git)
### 3.2. Gestion des Secrets (Clés SSH, Tokens)
### 3.3. Scénario 2 : Dossier "Nu" (Ex: Google Drive)
### 3.4. Scénario 3 : Accès Hardware (GPU) et Communication Inter-Conteneurs

## 4. Stratégies de Provisioning et de Configuration

*Cette section définira comment nous construisons et configurons nos environnements de manière automatisée.*

### 4.1. Blueprints de Dev Containers par Cas d'Usage
### 4.2. Script de Provisioning Avancé
### 4.3. Gestion des Profils d'Extensions VS Code

## 5. Architecture Cible et Points de Décision

*Cette section, qui sera rédigée en dernier, synthétisera les analyses pour proposer une architecture finale et trancher les points de décision.*

### 5.1. Option 1 : Persistance des Conversations
### 5.2. Option 2 : Architecture du "Tableau de Bord"
### 5.3. Proposition d'Architecture Cible consolidée