# MyIA MCP Infrastructure

Container unique exposant tous les serveurs MCP via Streamable HTTP pour integration avec des LLM providers (Anthropic, OpenAI) et des applications (AI Engine Pro, Open WebUI).

## Architecture

```
Internet (Anthropic/OpenAI APIs, AI Engine Pro, Open WebUI)
    |
    | HTTPS + Bearer token
    v
IIS Reverse Proxy (myia-po-2023)
    mcp-tools.myia.io:443 -> myia-ai-01:9090
    |
    v
myia-mcp-proxy container (port 9090) --- token auth ---
    |-- /searxng/    -> npx mcp-searxng (stdio) -> search.myia.io
    |-- /sk-agent/   -> relais HTTP -> conteneur sk-agent :8100/mcp (depuis 22/09) -> LLM providers
    |-- /future-mcp/ -> (extensible)
```

## Image custom

L'image `myia-mcp-proxy:latest` etend `ghcr.io/tbxark/mcp-proxy:latest` avec :
- Dependances Python sk-agent (semantic-kernel, openai, mcp, etc.)
- Code source sk-agent (`/opt/sk-agent/`)

searxng tourne en subprocess stdio dans le container. /sk-agent/ est un relais HTTP vers le conteneur sk-agent dedie :8100 (depuis le 22/09, cf. docs/harness/reference/sk-agent-usage-guide.md) ; /roo-state-manager/ relaye vers le service host (mcp-proxy-host.md).

## Setup rapide (myia-ai-01)

```bash
cd d:/roo-extensions/docker

# 1. Configurer mcp-proxy
cp mcp-proxy/config.template.json mcp-proxy/config.json
# Editer config.json : remplacer REPLACE_WITH_TOKEN par un vrai token
python -c "import secrets; print(secrets.token_hex(32))"

# 2. Build et lancer
docker compose build --no-cache
docker compose up -d
```

## Commandes utiles

```bash
# Logs
docker compose logs -f

# Rebuild (apres MAJ code sk-agent ou requirements)
docker compose build --no-cache
docker compose up -d --force-recreate

# Restart (apres modification de config.json seulement)
docker compose restart mcp-proxy

# Status
docker compose ps
```

## Configuration mcp-proxy

### config.json

Le fichier `mcp-proxy/config.json` contient la configuration du proxy. Il est gitignore (contient le token).

- `mcp-proxy/config.template.json` : template sans secrets (commitable)
- `mcp-proxy/config.json` : config reelle avec token (gitignore)

### Ajouter un nouveau MCP

Editer `mcp-proxy/config.json` et ajouter une entree dans `mcpServers` :

```json
{
  "mcpServers": {
    "nouveau-mcp-node": {
      "command": "npx",
      "args": ["-y", "nom-du-package-mcp"],
      "env": { "VAR": "valeur" }
    },
    "nouveau-mcp-python": {
      "command": "python",
      "args": ["/opt/mon-mcp/server.py"],
      "env": { "CONFIG": "/opt/mon-mcp/config.json" }
    }
  }
}
```

Pour les MCPs Python, ajouter les dependances dans le Dockerfile et rebuild.
Puis redemarrer : `docker compose restart`

### Endpoints exposes

| MCP Server | Endpoint (Streamable HTTP) | Outils |
|------------|---------------------------|--------|
| searxng | `POST /searxng/mcp` | `searxng_web_search`, `web_url_read` |
| sk-agent | `POST /sk-agent/mcp` | `call_agent`, `list_agents`, `run_conversation`, `list_conversations`, etc. |
| roo-state-manager | `POST /roo-state-manager/mcp` | 17 outils (conversation_browser, codebase_search, roosync_*, etc. post all CONS) — upstream HTTP vers service host (voir `docs/harness/reference/mcp-proxy-host.md`) |

**Transport :** Streamable HTTP (POST avec JSON-RPC). Compatible MCP SDK v1.26+.

### Authentification

Le proxy requiert un Bearer token dans le header `Authorization` :

```
Authorization: Bearer <token>
```

Alternative (clients sans support headers) : token dans l'URL :
```
/searxng/<token>/mcp
```

## Securite

- **Token unique mcp-proxy** : Protege l'acces a TOUS les MCPs (searxng + sk-agent)
- **HTTPS** : Chiffrement via reverse proxy IIS
- /sk-agent/ relaye vers le conteneur sk-agent :8100 (bearer SK_AGENT_API_KEY), pas expose directement sur Internet

## Reverse Proxy IIS

| Domaine | Port local | Service | Machine IIS | Notes |
|---------|-----------|---------|-------------|-------|
| `mcp-tools.myia.io` | 9090 | mcp-proxy (tous MCPs) | myia-po-2023 | Desactiver buffering ARR |

**Note :** le domaine `skagents.myia.io` n'est plus necessaire. OWUI utilise `mcp-tools.myia.io/sk-agent/mcp` ; le port 8100 reste le port interne du conteneur sk-agent (cible du relais).

### Configuration IIS (mcp-tools.myia.io)

```xml
<system.webServer>
  <rewrite>
    <rules>
      <rule name="ReverseProxy" stopProcessing="true">
        <match url="(.*)" />
        <action type="Rewrite" url="http://myia-ai-01:9090/{R:1}" />
      </rule>
    </rules>
  </rewrite>
  <httpProtocol>
    <customHeaders>
      <add name="Access-Control-Allow-Origin" value="*" />
      <add name="Access-Control-Allow-Headers" value="Authorization, Content-Type, Accept, Mcp-Session-Id" />
    </customHeaders>
  </httpProtocol>
</system.webServer>
```

**Important :** Desactiver le buffering de reponse dans ARR (IIS Manager > Server Farms > Proxy > Decocher "Enable buffer"). Timeout minimum : **900 secondes (15 minutes)** — au-dessus du hop TBXark le plus long (`sk-agent`, 15 min ; `roo-state-manager`, 13 min), echelle #1357.

## Stack technique

- **Proxy** : [tbxark/mcp-proxy](https://github.com/tbxark/mcp-proxy) (Go, base image)
- **sk-agent** : conteneur dedie (docker-compose.sk-agent.yml du submodule) en streamable-http :8100, relaye par /sk-agent/
- **SearXNG** : mcp-searxng (Node.js, via npx, subprocess stdio)
- **Transport** : Streamable HTTP (POST JSON-RPC) vers les clients
- **SearXNG backend** : https://search.myia.io/ (self-hosted)
