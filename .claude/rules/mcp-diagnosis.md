# MCP Diagnosis — Invalid Diagnostic Patterns

**Version:** 2.0.0
**MAJ:** 2026-04-27

---

## Regle Absolue #1 — Pas de timing fantasy

**"La session a demarre avant que le MCP soit pret" n'est JAMAIS un diagnostic valide.**

Le protocole MCP fonctionne ainsi : soit le serveur repond au handshake dans le timeout, soit il ne repond pas. Il n'existe pas d'etat intermediaire "pas encore pret".

## Regle Absolue #2 — Les MCP reviennent dans la session EN COURS

**NE JAMAIS dire "le MCP reviendra a la prochaine session" ou "restart VS Code". C'est une HALLUCINATION.**

Si le MCP est fonctionnel (handshake OK, tools/list repond avec des outils), il PEUT et DOIT revenir dans la session en cours. Les outils reapparaissent automatiquement quand le probleme sous-jacent est corrige.

**Les SEULES actions valides :**
1. Diagnostiquer et corriger le probleme (build, .env, config, processus)
2. Si le fix est applique et le MCP fonctionne en standalone → les outils reapparaissent dans la session
3. Dernier recours : demander a l'utilisateur de relancer la session (jamais suggerer automatiquement)

**Origine :** Incident 2026-04-27 (po-2024) : L'agent a affirme "le MCP reviendra a la prochaine session" alors que le MCP fonctionnait parfaitement en standalone. L'utilisateur a explicitement rejete cette affirmation : "Non alors je ne veux plus jamais qu'aucun agent me parle de retour des MCPs 'a la prochaine session' ou je ne sais quoi, c'est une hallucination."

### Implications

- Si le MCP fonctionne dans un terminal autonome (JSON-RPC handshake OK, tools/list repond) mais pas dans Claude Code → le probleme est dans la configuration ou le processus hote, PAS un timing de demarrage.
- Si le MCP ne repond pas en standalone non plus → le serveur est en panne. Diagnostic: crash, .env manquant, build casse, port conflict.
- Un restart VS Code / Claude Code qui "resout" le probleme signifie que le processus precedent etait dans un etat corrompu ou que la config a ete rechargee — pas que le timing etait en cause.

### Origine (Regle #1)

Incident 2026-04-25 (ai-01 + po-2023) : MCP roo-state-manager ne se chargeait pas dans Claude Code alors qu'il fonctionnait parfaitement en standalone (41 outils, 652 skeletons, Qdrant connecte). Le diagnostic "session started before MCP ready" a ete propose et rejete par l'utilisateur : "Ca n'a jamais ete vrai. Soit le MCP revient dans ta session, soit il ne fonctionne nulle part."

### Actions quand le MCP ne charge pas

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

### Architecture du chain (pour debug)

```
Bot/Agent  -->  https://mcp-tools.myia.io  -->  TBXark proxy (port 9090)  -->  sparfenyuk mcp-proxy (port 9091)  -->  roo-state-manager (stdio via mcp-wrapper.cjs)
```

Le watchdog `mcp-chain-watchdog.ps1` tourne toutes les 5 minutes (scheduled task `MCP-Chain-Watchdog` sur ai-01) et repare automatiquement les pannes. Logs : `D:\roo-extensions\outputs\mcp-watchdog\watchdog-YYYYMMDD.log`.

---

**Principe condense** : *"Pas de timing fantasy. Le MCP repond ou il crash. Pas de demipression. Et il revient dans CETTE session, pas la prochaine. Si tu doutes, lance le healthcheck."*
