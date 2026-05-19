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

Le watchdog `mcp-chain-watchdog.ps1` tourne toutes les 5 minutes (scheduled task `MCP-Chain-Watchdog` sur ai-01) et repare automatiquement les pannes. Logs : `D:\roo-extensions\outputs\mcp-watchdog\watchdog-YYYYMMDD.log`.

---

**Règles absolues universelles (anti-timing-fantasy, anti-"next session") :** [`.claude/rules/mcp-diagnosis.md`](../../../.claude/rules/mcp-diagnosis.md)
