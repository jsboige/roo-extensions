# Instructions pour agents IA — roo-extensions

Objectif: rendre un agent immédiatement productif dans ce monorepo Roo Extensions. Suis ces pratiques spécifiques au dépôt — pas de conseils génériques.

## Vue d’ensemble de l’architecture
- Monorepo centré VS Code/Roo avec 4 piliers:
  - `mcps/` (Model Context Protocol): serveurs outils. Sous-arbres clés: `internal/servers` (quickfiles, jupyter, jinavigator, roo-state-manager, github-projects), `external/` (filesystem, git, github, searxng, win-cli), `forked/` (serveurs tiers modifiés).
  - `roo-modes/`: définitions de modes Roo. Deux architectures: simple/complex (prod) et N5 à 5 niveaux (MICRO→ORACLE) avec mécanismes d’escalade/désescalade; tests dans `roo-modes/n5/tests`.
  - `roo-config/`: scripts PowerShell de déploiement/diagnostic/encoding et templates de config. Point d’entrée: `roo-config/settings/deploy-settings.ps1` (init submodules + déploie settings globaux Roo).
  - `profiles/` et `modules/`: profils de modèles (ex. Qwen3) et modules utilitaires.
- Flux de données: Roo (extension VS Code, sous-dossier `roo-code/`) appelle des MCPs via stdio selon `mcp_settings.json` du stockage global; les modes guident l’orchestration; `roo-state-manager` centralise détection du stockage Roo, gestion des settings et synthèse de conversations.

## Workflows développeur (Windows/PowerShell)
- Préparer l’environnement (obligatoire au premier run):
  - Exécuter `roo-config/settings/deploy-settings.ps1` (initialise submodules Git, déploie `config.json` côté utilisateur; préserve clés API; options: `-Force`, `-NoMerge`).
  - Déployer des modes si besoin: `roo-config/deployment-scripts/deploy-modes-simple-complex.ps1` ou `roo-config/deploy-profile-modes.ps1 -ProfileName "standard"`.
- Lancer la batterie de tests MCP:
  - npm test racine appelle PowerShell: `./mcps/tests/run-all-tests.ps1` (exécute scripts node de test quickfiles/jinavigator/jupyter et la suite roo-state-manager).
- Développer/tester roo-state-manager (TS/Jest, ESM):
  - Dans `mcps/internal/servers/roo-state-manager/`: `npm run build`; `npm test`; `npm run test:detector` pour le détecteur de stockage; tests e2e via `npm run test:e2e`.
  - Important: incrémenter `package.json.version` et refléter la version dans `mcp_settings.json` pour forcer le hot-reload côté Roo.
- Redémarrer MCPs après modification de config: utiliser l’outil MCP `roo-state-manager.touch_mcp_settings` (évite les incohérences VS Code Extension Host).

## Conventions projet utiles à respecter
- Scripts PowerShell par défaut; privilégier des commandes compatibles PowerShell 5.1 (séparateur `;`, éviter features Core-only).
- Encodage: corriger/valider les JSON via `roo-config/encoding-scripts/*` et `diagnostic-scripts/*`. Les fichiers de configuration doivent être UTF-8 sans BOM.
- Sous-modules Git: ce dépôt embarque des submodules (ex. `roo-code/`); toujours lancer `deploy-settings.ps1` avant d’utiliser les modes/MCPs.
- Stratégie de commits: isoler les changements du sous-module `roo-code` et placer les personnalisations dans `roo-code-customization/` (voir `COMMIT_STRATEGY.md`).

## Intégrations externes et points d’attention
- Fichier de config MCP Roo (emplacement VS Code global):
  - Windows: `%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json` (géré via `roo-state-manager`).
- Démarrages MCP spécifiques Windows:
  - Playwright: config recommandée via `npx -y @playwright/mcp --browser chromium` (transport stdio, pas de run-server HTTP).
  - SearXNG: utiliser `cmd /c npx -y mcp-searxng` pour contourner l’inégalité `import.meta.url` vs `process.argv[1]` sous Windows; exiger `SEARXNG_URL`.
  - Win-CLI: fichier `%USERPROFILE%\.win-cli-server\config.json` avec `blockedOperators: []` pour autoriser `; | &` selon shell.
- Roo State Manager expose des outils clés: `detect_roo_storage`, `get_storage_stats`, `diagnose_roo_state`, `repair_workspace_paths`, `generate_trace_summary`, `generate_cluster_summary` — préférer ces outils plutôt que des accès fichiers directs.

## Exemples de patterns concrets
- Ajouter/mettre à jour un MCP interne (ex. roo-state-manager):
  - Builder `mcps/internal/servers/roo-state-manager` puis mettre à jour la clé `version` et relancer via `touch_mcp_settings`.
- Utiliser QuickFiles pour lecture multi-fichiers: appeler l’outil `read_multiple_files` avec `{ paths: ["roo-modes/README.md", "mcps/README.md"], show_line_numbers: true }`.
- Activer modes simples/complexes: déployer via `roo-config/deployment-scripts/deploy-modes-simple-complex.ps1`, vérifier avec `roo-config/diagnostic-scripts/verify-deployed-modes.ps1`.

## Dossiers/fichiers de référence
- `README.md`, `GETTING-STARTED.md`
- `mcps/README.md`, `mcps/tests/run-all-tests.ps1`
- `mcps/internal/servers/roo-state-manager/` (README, package.json, tests/)
- `roo-modes/README.md`, `roo-modes/n5/tests/`
- `roo-config/settings/deploy-settings.ps1`, `roo-config/encoding-scripts/*`, `roo-config/diagnostic-scripts/*`
- `COMMIT_STRATEGY.md`

Notes pour agents: documente dans les PRs les scripts exécutés et les fichiers affectés; lorsque tu modifies la config MCP, préfère passer par `roo-state-manager` plutôt que d’éditer directement le JSON.
