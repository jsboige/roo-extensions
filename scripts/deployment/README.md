# Scripts de Déploiement

Ce dossier contient des scripts PowerShell consolidés pour installer et gérer l'environnement de développement des MCPs (Model Context Protocol).

## sync-claude-settings.ps1

Harmonisation flotte de `~/.claude/settings.json` (structure de référence po-2023). Porté du GDrive (`.shared-state/configs/claude-settings/`) vers ce dépôt le 23/08/2026 après l'incident de blocage DriveFS : 3 machines coupées du script pendant ~2 jours (po-204 a nécessité un reboot, po-2023 a dû relayer via gist). Le dépôt est déjà tiré par chaque machine au pre-flight (`git pull`) — la distribution ne dépend plus de l'état de G:.

```powershell
# dry-run (lecture seule)
pwsh -ExecutionPolicy Bypass -File scripts/deployment/sync-claude-settings.ps1 -MachineName myia-po-2025 -Verify
# application (backup horodaté automatique, garde TCP anti port mort)
pwsh -ExecutionPolicy Bypass -File scripts/deployment/sync-claude-settings.ps1 -MachineName myia-po-2025
```

Le script est idempotent, ne touche pas `permissions`/`model`/`effortLevel`, et n'écrit jamais de secret (le `x-proxy-key` existant est préservé, jamais dupliqué). La fenêtre de compaction (`CLAUDE_CODE_AUTO_COMPACT_WINDOW`) et le pourcentage (`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`) ne s'écrivent que si absents — le `settings.json` de la machine fait foi (garde #3215). Vérification d'intégrité de la v2.2 : sha256 `3bdd9cc9a1417526f709754807f38bcd4ee2f2d034459169d2805f0575da3b4d`.

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