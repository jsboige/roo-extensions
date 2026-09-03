# MCP Diagnosis — Procédure Complète

> **Note relocalisation (2026-05-19)** : Procédure technique extraite de `.claude/rules/mcp-diagnosis.md` (split). Les 2 règles absolues universelles (anti-timing-fantasy, anti-"next session" hallucination) restent dans la rule auto-chargée slim. Ici : healthcheck, architecture chain, diagnostic par couche.

---

## Actions quand le MCP ne charge pas

**Premier reflexe — healthcheck automatique :**
```powershell
.\scripts\mcp-watchdog\mcp-chain-healthcheck.ps1
```
Probe les 4 couches (wrapper local, sparfenyuk, TBXark, E2E cloud) et indique exactement laquelle est cassee + la commande de fix.

**Auto-repair complet :**
```powershell
.\scripts\mcp-watchdog\mcp-chain-watchdog.ps1
```
Detecte et repare automatiquement les pannes courantes (sparfenyuk down, TBXark stale).

**Si le healthcheck ne suffit pas, diagnostic manuel par couche :**
1. **Local wrapper** : `node mcps/internal/servers/roo-state-manager/mcp-wrapper.cjs` avec stdin handshake — verifier la reponse JSON-RPC. Le wrapper v4.1+ utilise un cache persiste (`$TMPDIR/.mcp-roo-state-tools-cache.json`) qui repond a `tools/list` instantanement meme si le serveur tarde.
2. **Build** : `npm run build` dans `mcps/internal/servers/roo-state-manager/`
3. **Config** : `~/.claude.json` section mcpServers (command, args, cwd, env)
4. **`.env`** : variables ROOSYNC_SHARED_PATH, QDRANT_URL, QDRANT_API_KEY presentes ?
5. **Processus** : `Get-Process node | Where-Object { $_.CommandLine -like "*roo-state-manager*" }` — un seul processus actif ?
6. **Restart VS Code** : dernier recours, pas un diagnostic.

## Architecture du chain (pour debug)

```
Bot/Agent  -->  https://mcp-tools.myia.io  -->  TBXark proxy (port 9090)  -->  sparfenyuk mcp-proxy (port 9091)  -->  roo-state-manager (stdio via mcp-wrapper.cjs)
```

Le watchdog `mcp-chain-watchdog.ps1` tourne toutes les 2 minutes (scheduled task `MCP-Chain-Watchdog` sur ai-01, intervalle #1942) et repare automatiquement les pannes. Logs : `D:\roo-extensions\outputs\mcp-watchdog\watchdog-YYYYMMDD.log`.

## Verifier le watchdog lui-meme (#3394)

**Symptome #3394** : fenetres `connection refused` sur `host.docker.internal:9091` (sparfenyuk, schtask `MCP-Proxy-RSM`) de 20-55 min qui se referment seules, buses NanoClaw/Hermes coupees. Depuis la flotte, le port 9091 n'est PAS sondable (firewall drop LAN — mesure po-204 : timeout, alors que :9090 repond en 4 ms) : la verification ne peut se faire que sur l'hote.

**Sur l'hote (ai-01), lecture seule :**

```powershell
.\scripts\mcp-watchdog\verify-watchdog-deployment.ps1
# Pour une fenetre d'episode precise (heure LOCALE ; #3394 est en UTC,
# ai-01 = UTC+2 debut septembre : 01:21Z = 03:21 local) :
.\scripts\mcp-watchdog\verify-watchdog-deployment.ps1 -From '2026-09-03 03:15' -To '2026-09-03 03:50'
```

Lecture du verdict :

| Verdict log fenetre | Signification | Action |
|---|---|---|
| 0 ligne dans la fenetre | La schtask watchdog n'a PAS tourne pendant l'episode | Reinstaller `install-watchdog-schtask.ps1` (elevation) — cause premiere |
| Lignes OK uniquement | Watchdog vivant mais sa sonde etait VERTE pendant l'episode | Divergence de chemin sonde (:9090) vs bots (:9091) — instruire |
| Lignes FAIL/repair | Le watchdog a vu la panne et est intervenu | Verifier pourquoi la reparation n'a pas tenu — distinguer la signature : HTTP 404 (backend vivant / instance morte — GDrive, RSM) vs HTTP 0 ou timeouts (couche proxy/reseau) ; les deux n'appellent pas la meme reparation (mesure ai-01 03/09 : 2 fenetres, 2 signatures) |

**Modes de panne connus de `MCP-Proxy-RSM`** (pourquoi « rien ne le relance » est possible) :

1. **Budget de restart epuise** : la schtask a `RestartCount 5` x 1 min. Un crash-loop au-dela de 5 tentatives laisse sparfenyuk MORT jusqu'au prochain logon — seul le chain watchdog le releve.
2. **Session interactive perdue** : trigger `AtLogOn` + `LogonType Interactive` (exige par GDrive). Logoff/reboot sans logon = :9091 down jusqu'a la prochaine session.
3. **Chien de garde mort** : la schtask `MCP-Chain-Watchdog` elle-meme absente/desactivee/trigger mort — les deux episodes de #3394 ne sont pas distinguishables d'un watchdog mort tant que ses logs n'ont pas ete lus sur l'hote.

**Telemetrie flotte (depuis #3394)** : le watchdog poste sur le **machine dashboard** de l'hote (a travers la chaine qu'il surveille, best-effort, budget borne 8 s/requete) :
- `WARN` + tag `mcp-chain-watchdog` a chaque reparation/alerte (verdict final inclus) ;
- `INFO` + tag `mcp-chain-watchdog` en heartbeat toutes les 6 h quand tout est sain.

La note porte une **cle d'idempotence** (#3276) : `watchdog-<hote>-<niveau>-<empreinte>-<bucket 15 min>`. Les 8 ticks de 2 min d'un incident en cooldown et les 2 routes du fallback convergent sur une seule ligne du dashboard.

**Limite structurelle (po-2023 F4)** : la note transite par la chaine qu'elle surveille — le cas « reparation ECHOUEE, final=DOWN » est le seul qui ne peut jamais etre livre (chaine down = append impossible). La telemetrie prouve « le watchdog est vivant » et « une reparation a reussi » ; jamais « une reparation a echoue ». Pour ce cas, le verifier host-side ci-dessus est la seule source.

Silence `mcp-chain-watchdog` > ~12 h sur une chaine saine = watchdog probablement mort (meta-panne) : lancer le verifier ci-dessus sur l'hote.

---

**Règles absolues universelles (anti-timing-fantasy, anti-"next session") :** [`.claude/rules/mcp-diagnosis.md`](../../../.claude/rules/mcp-diagnosis.md)
