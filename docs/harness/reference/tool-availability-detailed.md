# Inventaire Outils et Config — Reference Detaillee

**Source :** `.claude/rules/tool-availability.md` (version slim)

---

## Config canonique win-cli (#1666 Phase A3)

```json
"win-cli": {
  "command": "node",
  "args": ["d:/roo-extensions/mcps/external/win-cli/server/dist/index.js"],
  "transportType": "stdio",
  "disabled": false,
  "alwaysAllow": [ "execute_command", "get_active_terminal_cwd", ... ]
}
```

Tout autre chemin dans `args[0]` = **drift critique** (incident #1482 : agents reintroduisent `npx @simonb97/...` apres refactors config).

**Validation automatique :** `powershell -File scripts/validation/validate-wincli-config.ps1`
- Lit `%APPDATA%\...\mcp_settings.json`
- Detecte patterns `npx|@simonb97|@anthropic/win-cli|node_modules` dans `args[0]`
- Verifie binaire cible existe + `package.json` v0.2.0
- Exit 0 = OK, 1 = drift, 2 = config manquante

**Integration `/coordinate` :** le coordinateur DOIT faire tourner ce script en phase initiale et bloquer si drift.

### Robustesse `commandTimeout` (#2333)

**Probleme :** des sessions Roo longues etaient tuees a ~30s/500s par un `commandTimeout` derive dans le `config.json` runtime de win-cli (`~/.win-cli-server/config.json`), regression silencieuse a chaque edition manuelle ou reinstall.

**Mecanisme de protection (`src/utils/config.ts`) :**

1. **Default verrouille** — `DEFAULT_CONFIG.security.commandTimeout = 600`. La fonction `mergeConfigs` **ecrase** systematiquement la valeur du `config.json` utilisateur par le default (`commandTimeout: defaultConfig.security.commandTimeout`). Un `config.json` qui contient `commandTimeout: 180` est donc neutralise → effectif **600**.
2. **Override explicite par env** — apres le merge, si `WIN_CLI_COMMAND_TIMEOUT` est un entier ≥ 1, il prend le pas (`mergedConfig.security.commandTimeout = envTimeout`). C'est le **seul** moyen de monter au-dela de 600 (ex. `WIN_CLI_COMMAND_TIMEOUT=900`).

**CRITIQUE — rebuild `dist/` par machine.** Le fix vit dans `src/`, mais Roo lance `dist/index.js`. Un `dist/` compile **avant** #2333 rend le fix **inerte** : le merge ne verrouille pas, le `config.json` derive reste effectif. Apres tout bump de pointer submodule `mcps/external/win-cli/server`, chaque machine DOIT :

```bash
cd mcps/external/win-cli/server && npm run build   # tsc → dist/
# puis relancer VS Code pour que Roo recharge le MCP
```

**Verification (effectif ≥ 600, survit a une regression config) :**

```js
// charger loadConfig depuis dist/utils/config.js avec un config.json a 180,
// sans WIN_CLI_COMMAND_TIMEOUT → effectif doit valoir 600
// puis poser WIN_CLI_COMMAND_TIMEOUT=900 → effectif doit valoir 900
```

Verifie firsthand sur po-2025 (2026-05-25) : config derive 500→neutralise, dist rebuild, effectif 600, override env 900 OK.

## Config MCP sk-agent

**sk-agent DOIT etre dans `~/.claude.json` (global), JAMAIS dans `.mcp.json` (project root).**

Cause regression #1557 : `.mcp.json` project-level surcharge silencieusement la config globale.
**Verification :** `cat .mcp.json` a la racine ne doit PAS contenir `sk-agent`.

## searxng — drift de version par machine (#2224)

**Fait de version (tarballs npm inspectes le 24/09) :** `mcp-searxng` ≤ **1.4.0** expose **2** outils (`searxng_web_search`, `web_url_read`) ; ≥ **1.5.0** en expose **4** (+ `searxng_search_suggestions`, `searxng_instance_info`). Versions verifiees : 1.3.0 = 2, 1.4.0 = 2, 1.5.0 = 4, 1.16.0 = 4, 2.4.0 = 4 (derniere publiee au 24/09).

La flotte lance `npx -y mcp-searxng` **sans version epinglee** — l'ecart mesure le 24/09 (ai-01 : 2 outils, po-2025 : 2, po-2027 : 4) vient de **deux formes distinctes**, pas d'une difference de config (meme ligne partout ; les inventaires GDrive `inventories/*.json` ne portent pas de champ version) :

1. **Install global perime qui ECLIPSE la ligne npx** (cas ai-01, verifie firsthand). Le cache `_npx` ne contient **aucun** `mcp-searxng` : le serveur 2-outils vient d'un install global `mcp-searxng@0.4.6` sous `%APPDATA%\npm\node_modules` (shims dates 2025-05). `npx -y` prefere le bin global (`libnpmexec/lib/index.js:164-167`) — le debug log npm du jour montre **zero** fetch registre. Sur cette machine, purger le cache npx ne fait **rien**.
   - Leviers : `npm rm -g mcp-searxng` (retombe sur la resolution npx), ou `npm i -g mcp-searxng@latest`.
2. **Sinon : la version resolue au premier spawn dans le cache npx** (`%LOCALAPPDATA%\npm-cache\_npx`), qui ne re-resout pas de lui-meme.
   - Leviers : purger le cache npx de la machine, ou epingler.

**Diagnostic par machine :** `Get-ChildItem "$env:LOCALAPPDATA\npm-cache\_npx" -Recurse -Directory -Filter "mcp-searxng*"` — cache vide alors que le serveur vit = forme 1 (install global).

**Convergence flotte :** epingler la version dans `~/.claude.json` (`npx -y mcp-searxng@2.4.0`) — **fonctionne dans les deux formes**. Compte d'outils par lane : le mesurer sur la session, jamais le deduire du tableau de la regle.

**Autre consommateur non epingle :** `docker/mcp-proxy/Dockerfile:17` fait `npm install -g mcp-searxng` (sans version) — meme classe de drift au prochain rebuild de l'image.

## Protocole STOP & REPAIR — Claude Code

```
1. STOP   : Arreter la tache
2. LOG    : Dashboard [CRITICAL]
3. DIAG   : roosync_mcp_management(action: "manage", subAction: "read")
4. FIX    : roosync_mcp_management(subAction: "update_server_field") ou modifier sources
5. TEST   : Appeler l'outil pour confirmer
6. ESCAL  : RooSync URGENT si non reparable
7. RESUME : Seulement apres confirmation
```

## Protocole STOP & REPAIR — Roo Scheduler

```
1. STOP → 2. WRITE [CRITICAL] → 3. REPORT bilan → 4. WAIT prochain tick
```

## Pre-flight Scheduler (CRITIQUE)

**READ-ONLY.** Ne JAMAIS modifier config, redemarrer serveur, ou utiliser ask_followup_question en scheduler.
Si critique absent : signaler [CRITICAL], terminer proprement.

## Verification Proactive (Coordinateur)

**OBLIGATION apres TOUT changement de config :**
1. Lister 6 machines
2. Verifier Claude (roo-state-manager 17 tools) + Roo (win-cli fork local) + pas de MCP retire
3. Si divergence → directive corrective URGENTE

## MCP désactivés ≠ absents (#3137) — déporté de la règle (#2368)

Des MCP dédiés sont **désactivés** pour réduire la surface exposée — pas désinstallés. Leur config
reste sur disque. L'état se lit à **TROIS emplacements** (finding ai-01 23/08 + vérif live
po-2024 24/08, #3137) :

| # | Emplacement | Champ | Portée |
|---|---|---|---|
| 1 | `~/.claude.json` → `mcpServers` | `disabled` bool par serveur | machine |
| 2 | `<workspace>/.mcp.json` | `disabled` bool par serveur | workspace |
| 3 | `~/.claude.json` → `projects[<workspace>].disabledMcpServers` | **liste de noms** de serveurs | workspace, **prime sur l'activation user-scope** |

**Priorité vérifiée en session** : une entrée dans `disabledMcpServers` (emplacement 3) désactive
le serveur dans CE workspace **même s'il est `disabled:false` en user-scope** — piège mesuré sur
ai-01 et po-2024 : lire les emplacements 1-2 seul conclut « activé » à tort. L'instrument qui ne
ment pas : la **présence effective des outils `mcp__<serveur>__*` en session**.

**Avant de proposer d'installer un nouveau client** (playwright, sk-agent, jupyter-papermill…),
vérifier si le MCP dédié n'est pas simplement désactivé :

1. Lire les **3 emplacements** ci-dessus pour le workspace courant.
2. Si désactivé → réactiver : `"disabled": false` (emplacements 1-2) **ou retirer le nom du
   tableau** `disabledMcpServers` (emplacement 3) ; puis **redémarrer la session** du workspace
   (scope MCP chargé au démarrage).
3. Vérifier que les outils `mcp__<serveur>__*` apparaissent.
4. Re-désactiver après usage si la réduction de surface doit être restaurée.

**Recensement flotte par machine/workspace :** issue #3137. Un MCP désactivé n'est PAS un MCP
retiré (cf. § Retires ci-dessous) — la réactivation est locale et réversible, zéro installation.

## MCP Remote Claude.ai (injectés, pas dans config locale) — déporté de la règle (#2368)

Certains MCP apparaissent dans les sessions sans être dans `~/.claude.json` ni `.mcp.json`. Ils
sont injectés par le **routeur Claudish distant** (`ANTHROPIC_BASE_URL`) ou par le hub Claude.ai
(`claudeAiMcpEverConnected` dans `~/.claude.json`). Ne PAS les traiter comme des anomalies de
config locale :

| MCP | Outil | Source | Note |
|-----|-------|--------|------|
| `4_5v_mcp` | `analyze_image` | Routeur Claudish / Claude.ai remote | Vision, non critique |
| `web_reader` | `webReader` | Routeur Claudish / Claude.ai remote | Retiré du fork claudish (#2210, commit `24ec4da`), peut encore être injecté par le routeur |

**Action si détecté dans un audit :** Documenter la source (remote MCP), NE PAS chercher dans
les configs locales.

## Retires — note détaillée (déportée de la règle, #2368)

**quickfiles + github-projects-mcp : code supprimé (2026-09)** — Epic #2639 tâche C (#3423, PR
submod #1093) : les serveurs sont retirés de `servers/` du submod (quickfiles remplacé par les
capacités natives Claude Code, github-projects-mcp par `gh` CLI). Les **noms** restent dans la
garde `RETIRED_MCP_NAMES` du RSM — les tests qui les référencent testent le validateur, pas les
serveurs. `desktop-commander` : retiré des configs, non concerné par la suppression de code.
