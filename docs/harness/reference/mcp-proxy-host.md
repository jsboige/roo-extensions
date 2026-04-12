# MCP-Proxy Host (Streamable HTTP exposition)

**Version:** 1.0.0
**Issue:** #1354
**Status:** Deployed on myia-ai-01 (manual install per machine as needed)

---

## Objectif

Exposer `roo-state-manager` (MCP stdio) en Streamable HTTP pour clients distants (NanoClaw Docker Linux containers, agents externes) sans modifier le code du MCP.

Utilise le meme binaire `tbxark/mcp-proxy` que le conteneur Docker `myia-mcp-proxy` (searxng + sk-agent), mais installe directement sur le host Windows via une tache planifiee (Scheduled Task) qui tourne dans la session interactive de l'utilisateur. Contourne le blocage Docker bind-mount vs Google Drive File Stream qui empechait NanoClaw d'acceder a RooSync.

### Pourquoi Scheduled Task et pas Windows Service (NSSM) ?

Google Drive File Stream (`G:\`) est monte **par session utilisateur** : il n'est pas accessible depuis un service Windows tournant sous `LocalSystem` (le subprocess `node mcp-wrapper.cjs` reste bloque en "Connecting"). NSSM configure sous un compte utilisateur necessite un mot de passe texte non-Windows-Hello, ce qui echoue avec "Logon failure" sur les machines avec PIN Windows Hello.

La Scheduled Task avec `LogonType Interactive` + trigger `AtLogOn` resout les deux problemes : elle demarre automatiquement a l'ouverture de session, tourne dans le contexte complet de l'utilisateur (GDrive accessible), et ne necessite aucun stockage de mot de passe.

## Architecture

```
NanoClaw container / Client distant
    |
    | HTTPS + Bearer token
    v
IIS Reverse Proxy (myia-po-2023)
    mcp-tools.myia.io:443 --> myia-ai-01:9090
    |
    v
myia-mcp-proxy container (port 9090) --- token A ---
    |-- /searxng/         -> stdio subprocess (container)
    |-- /sk-agent/        -> stdio subprocess (container)
    |-- /roo-state-manager/ --URL upstream--
                                |
                                v
                        host.docker.internal:9091
                                |
                                v
        MCP-Proxy-RSM task (Scheduled Task, user session) --- token B ---
            |
            v
        node mcp-wrapper.cjs (roo-state-manager, full GDrive access)
```

**Deux tokens distincts :**
- Token A : protege `myia-mcp-proxy` (searxng + sk-agent + roo-state-manager unifies)
- Token B : protege `MCP-Proxy-RSM` (ne sert qu'a l'upstream container->host)

## Installation

Sur une machine Windows avec admin, Node.js, et roo-state-manager deja configure :

```powershell
# Lancer le script (admin requis)
cd D:\roo-extensions\scripts\infra\mcp-proxy-host
.\Install-RooStateManagerProxy.ps1
```

Le script :
- Telecharge `tbxark/mcp-proxy` v0.43.2 dans `D:\Tools\mcp-proxy-rsm\`
- Genere un Bearer token aleatoire (64 hex)
- Ecrit `config.json` referencant `mcp-wrapper.cjs`
- Cree la tache planifiee `MCP-Proxy-RSM` (trigger `AtLogOn` pour l'utilisateur courant, `LogonType Interactive`)
- Demarre la tache immediatement
- Verifie l'endpoint HTTP
- Affiche le token a conserver

### Parametres optionnels

```powershell
.\Install-RooStateManagerProxy.ps1 `
    -Port 9091 `
    -BindAddress "127.0.0.1" `       # "0.0.0.0" pour exposer sur LAN
    -Token "existing-token-here" `   # omit to auto-generate
    -InstallPath "D:\Tools\mcp-proxy-rsm" `
    -TaskName "MCP-Proxy-RSM" `
    -RunAsUser "MACHINE\USERNAME"    # default: current interactive user
```

## Desinstallation

```powershell
.\Uninstall-RooStateManagerProxy.ps1              # task only
.\Uninstall-RooStateManagerProxy.ps1 -RemoveFiles # also delete D:\Tools\mcp-proxy-rsm
```

## Registration dans mcp-proxy Docker

Apres install de la tache host, ajouter l'entree suivante dans `docker/mcp-proxy/config.json` (fichier gitignore, pas dans le repo) :

```json
"roo-state-manager": {
  "transportType": "streamable-http",
  "url": "http://host.docker.internal:9091/roo-state-manager/mcp",
  "headers": {
    "Authorization": "Bearer <TOKEN_B_DU_SERVICE_HOST>"
  }
}
```

**Important** : Le champ `transportType: "streamable-http"` est obligatoire. Sans lui, le proxy Docker reste bloque en "Connecting" car il tente une connexion stdio au lieu d'un upstream HTTP.

Puis :

```bash
cd d:/roo-extensions/docker
docker compose restart mcp-proxy
```

L'endpoint unifie devient :
- **Local** : `http://127.0.0.1:9090/roo-state-manager/mcp` (Bearer token A)
- **Public** : `https://mcp-tools.myia.io/roo-state-manager/mcp` (Bearer token A, via IIS)

## Test manuel

```bash
TOKEN="<token_host_service>"
curl -X POST http://127.0.0.1:9091/roo-state-manager/mcp \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'
```

Reponse attendue : `{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2024-11-05",...,"serverInfo":{"name":"roo-state-manager","version":"1.0.0"}}}`.

## Operations

### Logs

Les logs vont sur stdout/stderr du processus `mcp-proxy.exe`. Pour les capturer durablement, rediriger dans le fichier d'action de la tache ou utiliser `Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-TaskScheduler/Operational'; ID=200}`.

Etat de la tache :
```powershell
Get-ScheduledTask -TaskName MCP-Proxy-RSM | Format-List State
Get-ScheduledTaskInfo -TaskName MCP-Proxy-RSM
```

### Restart apres modification de roo-state-manager

```powershell
# Rebuild roo-state-manager
cd D:\roo-extensions\mcps\internal\servers\roo-state-manager
npm run build

# Redemarrer la tache (kill + start = reconnecte le subprocess stdio)
Stop-ScheduledTask -TaskName MCP-Proxy-RSM
Get-Process mcp-proxy -ErrorAction SilentlyContinue | Stop-Process -Force
Start-ScheduledTask -TaskName MCP-Proxy-RSM
```

### Rotation du token

```powershell
# Generer un nouveau token et reinstaller
.\Install-RooStateManagerProxy.ps1 -Token "<new-token>"
```

Puis mettre a jour `docker/mcp-proxy/config.json` et `docker compose restart mcp-proxy`.

## Sur quelles machines installer ?

- **myia-ai-01** : OUI (machine de reference, GDrive installe, Docker proxy heberge)
- **Autres machines** : seulement si besoin d'exposition HTTP (ex: workspace distinct necessitant son propre endpoint). Sinon `stdio` natif via `mcp-wrapper.cjs` suffit pour Claude Code / VS Code.

## Depannage

| Probleme | Diagnostic |
|----------|------------|
| Tache ne demarre pas | `Get-ScheduledTaskInfo -TaskName MCP-Proxy-RSM` (voir `LastTaskResult`) + `Get-WinEvent -LogName Microsoft-Windows-TaskScheduler/Operational -MaxEvents 20` |
| 401 sur endpoint | Token incorrect dans `Authorization: Bearer ...` |
| Connection refused container -> host | Verifier `host.docker.internal` resolve + firewall Windows (autoriser port 9091 sur interface Docker) |
| Docker proxy bloque en "Connecting" | Oubli de `"transportType": "streamable-http"` dans la config Docker (voir section Registration) |
| Tools/list vide | roo-state-manager stdio crash - verifier `Get-Process mcp-proxy` tourne et relancer la tache |
| GDrive tools echouent | La tache tourne-t-elle bien dans une session utilisateur interactive (pas LocalSystem) ? `Get-ScheduledTask -TaskName MCP-Proxy-RSM \| Select-Object -ExpandProperty Principal` doit montrer `LogonType: Interactive` |

## References

- Binaire upstream : [tbxark/mcp-proxy](https://github.com/TBXark/mcp-proxy)
- Issue origine : [#1354](https://github.com/jsboige/roo-extensions/issues/1354)
- Proxy Docker existant : [docker/README.md](../../../docker/README.md)
- Scripts install : [scripts/infra/mcp-proxy-host/](../../../scripts/infra/mcp-proxy-host/)
