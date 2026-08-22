# Étude — Partage du serveur RSM (un serveur, N clients) — stdio → HTTP local

**Issue :** #3156 (arbitrage user 2026-08-22 : ordre inversé — instruire le partage RSM avant tout POC devcontainer)
**Auteur :** myia-ai-01 (coordinateur), session du 2026-08-23
**Statut :** étude de faisabilité rendue — décision d'implémentation reste à l'arbitrage user
**Précédent :** `resource-containment-study-2026-08-18.md` (PR #3158) — le présent document instruit le levier identifié en conclusion de cette étude.

---

## 1. Mandat

L'arbitrage du 22/08 demande de trancher : **RSM peut-il être partagé entre clients (un serveur, N clients) au lieu d'un stdio par client ?** La question opérationnelle : le passage stdio → socket/HTTP local est-il praticable, et **qu'est-ce que ça casse** (isolation d'état, cwd par workspace, cycle de vie) ?

Méthode : lecture du code source du serveur (`mcps/internal/servers/roo-state-manager`), du wrapper, du SDK MCP installé, et du client Roo Code (submodule de référence). Aucune modification de code. Chaque affirmation porte sa localisation ; ce qui n'est pas établi par le code est qualifié SUPPOSÉ ou NON-MESURÉ.

## 2. Correction préalable — le « 66 instances » de l'arbitrage incluait les wrappers

La mesure ai-01 du 22/08 11:48Z (commentaire sur #3156) comptait « 66 instances / 44 766 MB ». Re-mesuré ce jour avec la séparation wrapper/serveur (correction méthodologique déjà posée le 18/08 07:15Z) :

| rôle | process | RAM | détail |
|---|---|---|---|
| **serveurs RSM** (`index.js`, hors wrapper) | **34** | **38,57 Go** | moy. ~1,13 Go |
| wrappers (`mcp-wrapper.cjs`) | 34 | 1,31 Go | ~39 Mo pièce, négligeables |
| `Code.exe` (VS Code entier) | 127 | 14,81 Go | |
| `claude.exe` | 22 | 6,55 Go | sessions extension |
| RAM libre | — | 87,6 / 191,8 Go | ai-01 ne souffre pas |

Cohortes : 33 serveurs nés le 22/08 (spawn storm au restart VS Code, pattern po-2026), 1 ce jour.

**Le chiffre « 66 » additionnait serveurs + wrappers.** La population réelle de serveurs est ~34. La conclusion directionnelle tient (34 serveurs / 38,6 Go vs 14,8 Go VS Code = **ratio 2,6×**), mais la magnitude de l'arbitrage était surestimée d'un facteur ~2. La mesure po-204 demandée en priorité doit impérativement utiliser le filtre corrigé (script fourni en annexe).

## 3. Ce que le code établit (VERIFIÉ)

### 3.1 Le transport est stdio, et stdio uniquement

`src/index.ts:694` : `const transport = new StdioServerTransport();` — une seule instance, câblée en dur. Un process = un client = un pipe.

### 3.2 Le SDK embarque déjà les transports alternatifs

`@modelcontextprotocol/sdk@1.19.1` (installé) expose dans `dist/esm/server/` : `sse.js` (SSEServerTransport), `streamableHttp.js` (StreamableHTTPServerTransport, **modes stateful multi-session via `sessionIdGenerator` et stateless**), `mcp.js`. Le passage stdio → HTTP local **ne requiert aucun ajout de dépendance**.

### 3.3 Les deux familles de clients supportent HTTP local

- **Roo Code** : `roo-code/src/services/mcp/McpHub.ts:48` type le transport comme `StdioClientTransport | SSEClientTransport | StreamableHTTPClientTransport` ; ligne 76 : *« Server type must be 'stdio', 'sse', or 'streamable-http' »* ; `headers` optionnel (l.80).
- **Claude Code** : config `~/.claude.json` `mcpServers` supporte `type: "http"` / `"sse"` avec `url` (+ `headers`). C'est une capacité standard du client.

**Il n'existe aucun verrou client qui impose stdio.** Les deux populations qui peuplent les 34 instances peuvent pointer vers `http://localhost:<port>/mcp`.

### 3.4 Le coût dominant des instances est machine-global, pas par client — la duplication est pure

C'est le fait central que l'étude établit, et il renverse la charge de la preuve : **la frontière process par client n'achète aucune isolation pour les postes qui pèsent.**

Chaque instance RSM fait tourner (tous démarrés à l'init, `src/index.ts:312-317`, `initializeNotificationSystem` `index.ts:444-449`) :

| worker | localisation | périmètre | multiplication |
|---|---|---|---|
| Skeleton refresh (Worker A) | `background-services.ts:494-510` | `RooStorageDetector.detectStorageLocations()` = **stockages machine-globaux** (AppData), PAS le workspace du client | 34× le même scan des mêmes répertoires toutes les 2 min |
| Indexation Qdrant | `background-services.ts:1167` | files d'attente + embeddings | 34× les boucles d'embedding (cf. incident 73 orphelins, 2026-05-26) |
| Auto-archive daemon | `MessageManager.ts:1727` | mailbox GDrive **partagée flotte** ; garde anti-doublon **in-process seulement** (`this.autoArchiveTimer`, l.1732) — aucun verrou inter-process | 34 courses sur la même mailbox (boot +30 s chacune, puis 6 h) |
| GDrive health | `index.ts:827-853` | sonde 30 s quand dégradé | 34× |
| Cache conversations | `ServerState.conversationCache` | squelettes machine-globals, bornés `MAX_CACHE_SIZE: 1000` | 34 copies des mêmes données |

Worker A scanne **les mêmes répertoires** dans chaque instance parce que la détection ne dépend PAS du workspace du client (`background-services.ts:510`). Le dual-write PG (`background-services.ts:547`, #692) est lui aussi émis par chaque instance pour les mêmes conversations — la multiplication s'aggraverait avec le store #3151.

**Conséquence : mutualiser ne supprime pas de l'isolation utile — elle supprime de la redondance.** Un serveur partagé ferait 1× le scan, 1× la file Qdrant, 1× l'archive sweep, 1 copy du cache.

### 3.5 Le cwd/workspace est la SEULE valeur réellement par client

Le wrapper capture le cwd du client et l'injecte : `mcp-wrapper.cjs:92-109` (`WORKSPACE_PATH: process.env.WORKSPACE_PATH || originalCwd`). Côté serveur : `CACHE_CONFIG.DEFAULT_WORKSPACE` résolu **au boot du process** (`config/server-config.ts:32`), consommé notamment comme `contextWorkspace` de `conversation_browser` (`tools/registry.ts:218`) pour `action:'current'`.

Le schéma d'outil offre déjà le paramètre par requête : `workspace?: string` — *« [current/view] Chemin du workspace (détection auto si omis) »* (`tools/conversation/conversation-browser.ts:74-75`), et `codebase_search`/`roosync_search` l'exposent aussi (c'est pourquoi la règle SDDD impose déjà `workspace` explicite : l'auto-détection pointe vers le répertoire du serveur, pas du client).

Le chantier « workspace par session » est donc **contenu** : résoudre `DEFAULT_WORKSPACE` par session (query param / header) au lieu du boot process, et le propager sur le chemin `current`. Une constante, un call site principal, un chemin d'outil.

### 3.6 Le cycle de vie actuel est un couplage parent-mort par stdin

Orphan-fix (incident 2026-05-26) : stdin EOF → kill cascade (`index.ts:818-823`), wrapper armé d'un watchdog parent-PID 30 s (`mcp-wrapper.cjs:176-234`). **Ce mécanisme disparaît de facto en mode daemon** — il n'a plus d'objet (plus d'enfant à orphelin), mais son remplacement (supervision du daemon) devient une obligation nouvelle.

## 4. Architecture proposée (cible du POC)

```
┌─ fenêtre VS Code / Roo (workspace A) ── type:http url http://localhost:7801/mcp?ws=A
├─ fenêtre VS Code / Roo (workspace B) ── type:http url http://localhost:7801/mcp?ws=B
├─ claude -p (worker headless)         ── type:http url http://localhost:7801/mcp?ws=C
...                                      │
                       1 process node RSM (daemon)
                       ├─ StreamableHTTPServerTransport (sessions stateful)
                       ├─ 1 StateManager + 1 conversationCache (partagé, borné)
                       ├─ 1× Worker A, 1× Qdrant, 1× auto-archive, 1× GDrive health
                       └─ routage workspace = query param ?ws= par session
```

- **Flag env** `RSM_TRANSPORT=http` + `RSM_HTTP_PORT` ; stdio reste le défaut — zéro changement comportemental pour les sessions existantes tant que le flag n'est pas posé.
- **Routage par query param** (`?ws=<chemin encodé>`) plutôt que par header : supporté par tout client HTTP sans exiger la capacité `headers`, lisible dans les logs, une URL par workspace dans la config client.
- **Daemon** : tâche planifiée au logon avec redémarrage (pattern schtasks #3141), binding localhost uniquement.
- **Rollback** : une ligne de config par client (retour à `command: node .../index.js`).

## 5. Ce que ça casse — inventaire honnête

| # | rupture | sévérité | analyse |
|---|---|---|---|
| 1 | **Blast radius** : un crash du serveur fait perdre les tools RSM à TOUS les clients d'un coup | **le point dur réel** | À distinguer de la cascade #1379 : les sessions Claude Code/Roo **survivent** (elles perdent un MCP, pas la fenêtre). Récupération = restart du daemon (watchdog schtask). Aujourd'hui, un bug serveur ne touche qu'un client — c'est le prix de l'architecture cible, à accepter consciemment ou refuser. |
| 2 | Cycle de vie stdin EOF → supervision daemon obligatoire | moyen | Le kill cascade n'a plus de sens ; il faut un superviseur (redémarrage auto, alerte heartbeat). Pattern existant (#3141). |
| 3 | `DEFAULT_WORKSPACE` par process → par session | **faible, contenu** | §3.5 : une constante + un call site + chemin `current`. Param `workspace` déjà dans les schémas. |
| 4 | Interleaving des appels de N clients dans un event loop unique | faible | Node single-threadé : les outils I/O-bound s'entrelacent déjà entre 34 process aujourd'hui — mais **sans backoff partagé**. Un backoff #2017 unique est plutôt un bénéfice contre la pression G:. Risque résiduel : un stall CPU synchrone gêne tout le monde (code majoritairement async). |
| 5 | `action:'current'` ambigu entre sessions du même workspace | faible | L'ambiguïté existe déjà (le cwd process ne distingue pas 2 sessions du même workspace) ; le query param `?ws=` ne fait pas pire. |
| 6 | Écritures concurrentes (state machine lifecycle, dashboards) | faible | Pré-existant au niveau flotte ; le serveur partagé ne crée pas la classe, il la localise sur une machine. |
| 7 | Perte des features wrapper (cache tools/list <1 ms, filtrage logs) | nul | Serveur toujours chaud = le cache n'a plus d'objet ; logs côté daemon. |
| 8 | Port/firewall | nul | Localhost only, port unique par machine dans le `.env`. |

**Non-affirmé** : latence HTTP local vs stdio (à mesurer au POC — attendue négligeable sur loopback, mais non mesurée) ; comportement de reconnexion des clients en cas de restart du daemon sous charge (à observer au pilote) ; bénéfice causal sur les incidents G: po-204 (corrélation I/O ×34 → à valider par la mesure avant/après, pas affirmable ex ante).

## 6. Gains attendus (projection, à confirmer par le pilote)

| machine | aujourd'hui (serveurs RSM) | cible partagée | gain RAM | gain I/O |
|---|---|---|---|---|
| ai-01 | 34 / 38,6 Go | 1-2 instances / ~2-3 Go | **~36 Go** | scans ÷34, embeddings ÷34 |
| po-204 (référence souffrante) | ~20-25 / 6,4 Go (à re-mesurer, filtre corrigé) | ~1-2 Go | **~5 Go sur 31,7 Go** (0,6 Go libres au 18/08) | idem — hypothèse de décompression DriveFS à valider |
| web1 | 2 / 3,9 Go | ~2 Go | faible (déjà quasi-partagé de fait) | archive race supprimée |

Ordre de grandeur cohérent avec l'arbitrage : un facteur ~10-20 sur le poste dominant, à coût d'infrastructure très inférieur au devcontainer (pas de Docker, pas de WSL, pas de cascade #1379, pas de mount G: cassé — le serveur reste host-side natif).

## 7. Plan proposé

| étape | contenu | gate |
|---|---|---|
| 0 | **Mesure po-204** (dispatch [WAKE-CLAUDE] joint à cette étude, script annexe) — confirme/invalide le ratio 2,6× sur la machine souffrante | ratio comparable → GO étude ; divergent → le nombre de fenêtres domine, re-ranker l'option A |
| 1 | POC code : `RSM_TRANSPORT=http` derrière flag env + routage `?ws=` — zéro changement par défaut ; build + tests CI (`validate-before-push.ps1`) | CI verte |
| 2 | Pilote : 1 worker headless sur po-204 vers le daemon ; mesurer RAM avant/après, latence outils, incidents G: | critères chiffrés (RAM ÷N, latence <2× stdio, 0 régression messagerie) |
| 3 | Extension : tous les headless po-204 → headless flotte → fenêtres interactives (rollback 1 ligne/client à chaque palier) | revue user par palier |

L'étape 0 est parallèle et préemptive : elle peut renverser la recommandation, conformément à l'arbitrage.

## 8. Annexe — script de mesure corrigé (wrappers exclus)

```powershell
$procs = Get-CimInstance Win32_Process -Filter "Name='node.exe'"
$srv  = $procs | Where-Object { $_.CommandLine -like '*roo-state-manager*' -and $_.CommandLine -like '*index.js*' -and $_.CommandLine -notlike '*mcp-wrapper*' }
$wrap = $procs | Where-Object { $_.CommandLine -like '*mcp-wrapper.cjs*' }
$srvMem  = ($srv  | ForEach-Object { Get-Process -Id $_.ProcessId -EA SilentlyContinue } | Measure-Object WorkingSet64 -Sum).Sum
$wrapMem = ($wrap | ForEach-Object { Get-Process -Id $_.ProcessId -EA SilentlyContinue } | Measure-Object WorkingSet64 -Sum).Sum
$code = Get-Process Code -EA SilentlyContinue
"RSM servers : $($srv.Count) — RAM $([math]::Round($srvMem/1GB,2)) GB"
"RSM wrappers: $($wrap.Count) — RAM $([math]::Round($wrapMem/1GB,2)) GB"
"Code.exe    : $($code.Count) — RAM $([math]::Round(($code|Measure-Object WorkingSet64 -Sum).Sum/1GB,2)) GB"
$os = Get-CimInstance Win32_OperatingSystem
"RAM libre   : $([math]::Round($os.FreePhysicalMemory/1MB,1)) / $([math]::Round($os.TotalVisibleMemorySize/1MB,1)) GB"
$srv | ForEach-Object { $_.CreationDate.ToString('yyyy-MM-dd HH:mm') } | Group-Object | Sort-Object Name |
  ForEach-Object { "cohorte $($_.Name) : $($_.Count) instances" }
```

*Note po-204 : sous le sandbox CIM, `Win32_Process` peut retourner WorkingSet64=0 — croiser avec `Get-Process` sur PID (méthode déjà utilisée dans le relevé du 18/08).*

---

*Sources code : `src/index.ts` (transport l.694, workers l.312-317, stdin-EOF l.818-823, health l.827+), `mcp-wrapper.cjs` (cwd l.92-109, kill cascade l.176-234), `src/config/server-config.ts:32`, `src/tools/registry.ts:218`, `src/tools/conversation/conversation-browser.ts:74-75`, `src/services/background-services.ts:494-568,1167`, `src/services/MessageManager.ts:1727-1752`, SDK `@modelcontextprotocol/sdk@1.19.1` `dist/esm/server/{sse,streamableHttp,mcp}.js`, `roo-code/src/services/mcp/McpHub.ts:48,76-86`. Mesures ai-01 du 2026-08-23 ~01:00 local, non destructives.*
