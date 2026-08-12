# MCP Proxy Architecture - mcp-tools.myia.io

**Version:** 1.0.0
**Decision:** 2026-04-13
**Statut:** Migration en cours (Windows bloque sur UAC, container en attente rebuild)

---

## Vue d'ensemble

Le sous-domaine `mcp-tools.myia.io` expose **3 MCPs** avec un bearer token commun via une **architecture 2-etages**.

```
Windows (ai-01, native)
  Proxy #1 : sparfenyuk Python + bearer auth [PR jsboige/mcp-proxy#187]
    roo-state-manager stdio -> 127.0.0.1:9091/servers/roo-state-manager/mcp + bearer
    (port LAN-accessible pour le container)

Container Linux (nanoclaw)
  Proxy #2 : TBXark Go + stdio race fix [PR jsboige/mcp-go#796]
    - searxng              (stdio local container)
    - sk_agent             (stdio local container)
    - roo-state-manager    (HTTP upstream -> Windows ai-01:9091 + bearer)
  -> mcp-tools.myia.io/servers/{name}/mcp + bearer commun
```

## Pourquoi 2 etages

- **roo-state-manager doit tourner sur Windows natif** (acces filesystem `C:\Users\...\globalStorage\`, npm Windows-only) — non containerisable raisonnablement
- **Le container expose le sous-domaine** (nanoclaw, reverse proxy existant)
- **Le container doit joindre Windows via HTTP** — sparfenyuk et TBXark ne supportent que stdio pour les backends locaux

## Pourquoi 2 proxies differents

- **Sparfenyuk (Python) cote Windows** : evite la race Go sur stdio (langage different)
- **TBXark (Go) cote container** : seul des deux a supporter upstream HTTP (necessaire pour joindre Windows)
- Les 2 PR upstream (#187 Python, #796 Go) sont **complementaires, pas redondantes**
- **Fallback** : si sparfenyuk Windows pose probleme, rebuild TBXark Go-patched en drop-in (TBXark a deja bearer auth natif)

## Bug concurrence Go (PR #796)

- Affecte `client/transport/stdio.go` dans mcp-go : Write concurrent sur stdin = entrelacements
- TBXark container l'utilise pour searxng/sk_agent (stdio backends) -> patch requis
- TBXark container N'L'UTILISE PAS pour roo-state-manager (HTTP upstream) -> safe sur ce backend
- Tant que PR #796 pas mergee upstream, TBXark container doit etre buildee depuis fork **`jsboige/mcp-go`** branche **`fix/stdio-concurrent-writes`**

## Bearer token partage

- **Valeur courante** : heritee du TBXark `D:\Tools\mcp-proxy-rsm` precedent (inchangee pour cette migration)
- **Rotation = synchro obligatoire** : Windows env `MCP_PROXY_AUTH_TOKEN` + container env TBXark + clients (Roo, Claude Code, nanoclaw Bot)
- **Partage via RooSync** (GDrive), **jamais git**

## Path clients (BREAKING)

| Avant | Apres |
|-------|-------|
| `https://mcp-tools.myia.io/roo-state-manager/mcp` | `https://mcp-tools.myia.io/servers/roo-state-manager/mcp` |
| `http://127.0.0.1:9091/roo-state-manager/mcp` (TBXark Windows, un MCP) | `http://127.0.0.1:9091/servers/roo-state-manager/mcp` (sparfenyuk Windows, idem) |

Clients concernes : nanoclaw Bot, eventuels scripts Roo/Claude pointant sur l'ancien path.

## Scheduled Task Windows

- **Nom** : `MCP-Proxy-RSM` (reutilise — overwrite TBXark)
- **Actuel** : TBXark `D:\Tools\mcp-proxy-rsm\` (en place tant que UAC pas accordee)
- **Cible** : sparfenyuk via `D:\Tools\mcp-proxy-sparfenyuk\` (`run-proxy.cmd` + `named-servers.json` + `install-schtask.ps1`)
- **Trigger** : at-logon, restart 5x, ExecutionTimeLimit zero, Interactive logon
- **Installation** : `powershell -ExecutionPolicy Bypass -File D:\Tools\mcp-proxy-sparfenyuk\install-schtask.ps1` (admin requis)

## Statut migration (2026-04-13)

- [x] PR sparfenyuk #187 ouverte (Bearer auth, 6 tests)
- [x] PR mcp-go #796 ouverte (stdio race fix + regression test)
- [x] Sparfenyuk installe sur Windows ai-01 (`uv tool install` -> `C:\Users\MYIA\.local\bin\mcp-proxy.exe`)
- [x] Validation ad-hoc port 9094 : 200 OK avec bearer, 401 sans bearer, /status bypass, 34 outils visibles
- [x] Memoire `project_mcp_proxy_architecture.md` (ai-01 only)
- [ ] **Schtask Windows** (BLOQUE UAC) : utilisateur doit relancer `install-schtask.ps1` en admin
- [ ] Validation 3 MCPs via proxy Windows (roo-state-manager seul, les 2 autres sont dans le container)
- [ ] Coordination nanoclaw : rebuild container TBXark depuis fork mcp-go
- [ ] Mise a jour clients (paths, bearer)

## References

- PR sparfenyuk : https://github.com/sparfenyuk/mcp-proxy/pull/187
- PR mcp-go : https://github.com/mark3labs/mcp-go/pull/796
- Memoire complete : `C:\Users\MYIA\.claude\projects\d--roo-extensions\memory\project_mcp_proxy_architecture.md` (ai-01)

---

## Timeouts (issue #1357)

**Verifie upstream 2026-08-11.** La chene 2-etages n'expose pas de timeouts HTTP serveur configurables — c'est un **gap upstream** des deux forks (TBXark Go + sparfenyuk Python).

### Couche par couche

| Couche | Type de timeout | Configurable ? | Valeur courante | Source |
|--------|-----------------|----------------|-----------------|--------|
| **TBXark HTTP serveur (:9090)** | `http.Server{ReadTimeout, WriteTimeout, IdleTimeout, ReadHeaderTimeout}` | **NON** (upstream n'expose rien) | `0` (aucun) | [`http.go`](https://github.com/tbxark/mcp-proxy/blob/master/http.go) (lu sur `master` le 2026-08-11) : `&http.Server{Addr, Handler}` sans aucun champ timeout |
| **TBXark client HTTP -> upstream** | `mcpServers.*.timeout` (time.Duration) | OUI | `5m` (#1357) | `config.go` `StreamableMCPClientConfig.Timeout` ; `client.go` `transport.WithHTTPTimeout(v.Timeout)` (streamable HTTP only, **pas stdio**) |
| **sparfenyuk HTTP serveur (:9091)** | uvicorn `timeout_keep_alive`, etc. | **NON** expose en JSON (uvicorn defaults) | `timeout_keep_alive=5s` (uvicorn default) | [`mcp_server.py`](https://github.com/sparfenyuk/mcp-proxy/blob/main/src/mcp_proxy/mcp_server.py) : `uvicorn.Config(starlette_app, host, port, log_level)` |
| **sparfenyuk client HTTP -> upstream** | `mcpServers.*.timeout` (number) | OUI mais semantique non documentee | n/a (stdio-only dans notre config) | [`config_loader.py`](https://github.com/sparfenyuk/mcp-proxy/blob/main/src/mcp_proxy/config_loader.py) ne charge PAS le champ `timeout` — il l'ignore |
| **IIS / ARR (po-2023, frontend)** | `connectionTimeout`, `activityTimeout` | OUI (IIS Manager + `web.config`) | `120s` minimum documente | [`docker/README.md` ligne 153](../../../docker/README.md) |
| **roo-state-manager CallTool wrapper** | per-tool Promise.race | OUI | default 120s, 5min pour `roosync_indexing`, 12min pour `roosync_dashboard` | [`mcps/internal/servers/roo-state-manager/src/tools/registry.ts` L52-87](../../../mcps/internal/servers/roo-state-manager/src/tools/registry.ts) (#2267) |
| **mcp-wrapper.cjs parent-PID watchdog** | kill cascade T+5s / T+10s / T+12s | NON (compile) | hardcoded | `mcps/internal/servers/roo-state-manager/mcp-wrapper.cjs` |

### Ce que la 5-min fait reellement (#1357)

1. **TBXark container → roo-state-manager HTTP upstream** : `mcpServers.roo-state-manager.timeout = "5m"` dans `docker/mcp-proxy/config.template.json`. Toute requete cote proxy coupe apres 5min — protege contre un hang silencieux de l'upstream (host po-2023 ou ai-01).
2. **sparfenyuk host (stdio)** : `timeout` non applicable (sparfenyuk utilise `command/args`, pas HTTP upstream). Pas de modif.
3. **TBXark HTTP serveur (:9090)** : gap upstream documente. Le seul garde-fou reel est IIS/ARR sur po-2023 (frontend public) — qui doit etre regle a 5min minimum pour matcher.

### Limites connues (a traiter en upstream PR si besoin)

- Aucun `readTimeout` / `writeTimeout` configurable cote TBXark ni sparfenyuk. Un upload de fichier ou un long poll SSE tient jusqu'a ce que le client coupe.
- Si IIS/ARR est laisse a 120s, les requetes >120s echouent meme si le backend TBXark est OK. **Reglage requis cote po-2023**, pas dans ce repo.

### Verification E2E (>60s slow tool)

Voir `scripts/mcp-watchdog/mcp-chain-watchdog.ps1` — probe E2E `NanoClaw → mcp-tools.myia.io → TBXark → sparfenyuk → roo-state-manager` deja 15s. Un test d'un tool volontairement lent (>60s) necessite un script de validation que l'agent `task-worker` peut executer interactivement sur ai-01. **Non livre dans ce patch** (necessite acces runtime aux containers en cours d'execution).
