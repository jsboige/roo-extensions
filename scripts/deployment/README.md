# Scripts de Déploiement

Ce dossier contient des scripts PowerShell consolidés pour installer et gérer l'environnement de développement des MCPs (Model Context Protocol).

## install-mcps.ps1

C'est le script principal pour automatiser l'installation et la configuration des MCPs internes et externes.

### Rôle et Logique

Le script `install-mcps.ps1` a été conçu selon les principes du **SDDD (Semantic Doc Driven Design)** pour être robuste, découvrable et facile à maintenir. Son workflow est le suivant :

1.  **Initialisation :**
    *   Vérifie la présence des prérequis indispensables (`git`, `node`).
    *   Initialise et met à jour les submodules Git (`git submodule update --init --recursive`), ce qui est crucial pour récupérer le code des MCPs internes.

2.  **Découverte :**
    *   Scanne les répertoires `mcps/internal/servers` et `mcps/external` pour identifier tous les MCPs disponibles.

3.  **Installation :**
    *   **Pour les MCPs internes** (basés sur Node.js) :
        *   Exécute `npm install` pour télécharger les dépendances.
        *   Exécute `npm run build` si un script de build est défini dans le `package.json`.
    *   **Pour les MCPs externes** :
        *   Recherche un script `install.ps1` à la racine du MCP et l'exécute s'il est trouvé.
        *   S'il n'y a pas de script, il informe l'utilisateur qu'une installation manuelle est probablement requise (en se référant au `README.md` du MCP).

4.  **Configuration :**
    *   Après l'installation réussie d'un MCP interne, le script met automatiquement à jour le fichier `roo-config/settings/servers.json`.
    *   Il ajoute ou met à jour l'entrée du MCP pour qu'il soit reconnu par l'écosystème Roo, en configurant le chemin de démarrage et les arguments.
    *   Une sauvegarde de `servers.json` est créée avant toute modification.

### Paramètres

Le script accepte les paramètres suivants pour plus de flexibilité :

*   `-McpName [string[]]`
    *   **Description :** Permet de cibler l'installation d'un ou plusieurs MCPs spécifiques. Si ce paramètre n'est pas utilisé, le script tentera d'installer tous les MCPs qu'il découvre.
    *   **Exemple :** `-McpName "quickfiles-server", "win-cli"`

*   `-Force [switch]`
    *   **Description :** Force la réinstallation d'un MCP interne, même si ses dépendances (`node_modules`) sont déjà présentes. Utile pour réparer une installation corrompue ou pour forcer une mise à jour.
    *   **Exemple :** `-Force`

### Exemples d'Utilisation

Ouvrez un terminal PowerShell à la racine du projet (`d:/dev/roo-extensions`).

**1. Installer tous les MCPs :**
```powershell
.\scripts\deployment\install-mcps.ps1
```

**2. Installer uniquement des MCPs spécifiques :**
```powershell
.\scripts\deployment\install-mcps.ps1 -McpName "quickfiles-server", "github"
```

**3. Forcer la réinstallation d'un MCP :**
```powershell
.\scripts\deployment\install-mcps.ps1 -McpName "quickfiles-server" -Force