# MyIA MCP Infrastructure

Container unique exposant tous les serveurs MCP via HTTP/SSE pour integration avec des LLM providers (Anthropic, OpenAI) et des applications (AI Engine Pro, Open WebUI).

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
    |-- /sk-agent/   -> python sk_agent.py (stdio) -> LLM providers
    |-- /future-mcp/ -> (extensible)
```

## Image custom

L'image `myia-mcp-proxy:latest` etend `ghcr.io/tbxark/mcp-proxy:latest` avec :
- Dependances Python sk-agent (semantic-kernel, openai, mcp, etc.)
- Code source sk-agent (`/opt/sk-agent/`)

Tous les MCPs tournent comme subprocesses stdio dans le meme container.

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

| MCP Server | SSE Endpoint | Outils |
|------------|-------------|--------|
| searxng | `/searxng/sse` | `searxng_web_search`, `web_url_read` |
| sk-agent | `/sk-agent/sse` | `ask`, `call_agent`, `list_agents`, `analyze_image`, `analyze_video`, `analyze_document`, `list_models`, etc. |

### Authentification

Le proxy requiert un Bearer token dans le header `Authorization` :

```
Authorization: Bearer <token>
```

Alternative (clients sans support headers) : token dans l'URL :
```
/searxng/<token>/sse
```

## Securite

- **Token unique mcp-proxy** : Protege l'acces a TOUS les MCPs (searxng + sk-agent)
- **HTTPS** : Chiffrement via reverse proxy IIS
- sk-agent tourne en subprocess stdio interne, pas expose directement

## Reverse Proxy IIS

| Domaine | Port local | Service | Machine IIS | Notes |
|---------|-----------|---------|-------------|-------|
| `mcp-tools.myia.io` | 9090 | mcp-proxy (tous MCPs) | myia-po-2023 | SSE: desactiver buffering ARR |

**Note :** `skagents.myia.io` (port 8100) n'est plus necessaire. OWUI utilise `mcp-tools.myia.io/sk-agent/sse`.

### Configuration IIS pour SSE (mcp-tools.myia.io)

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

**Important pour SSE :** Desactiver le buffering de reponse dans ARR (IIS Manager > Server Farms > Proxy > Decocher "Enable buffer"). Timeout minimum : 120 secondes.

## Stack technique

- **Proxy** : [tbxark/mcp-proxy](https://github.com/tbxark/mcp-proxy) (Go, base image)
- **sk-agent** : Python + Semantic Kernel 1.39+ (subprocess stdio)
- **SearXNG** : mcp-searxng (Node.js, via npx, subprocess stdio)
- **Transport** : SSE (Server-Sent Events) vers les clients
- **SearXNG backend** : https://search.myia.io/ (self-hosted)
