# MyIA MCP Infrastructure

Docker infrastructure centralisant les serveurs MCP exposes via HTTP/SSE pour integration avec des LLM providers (Anthropic, OpenAI) et des applications (AI Engine Pro, Open WebUI).

## Architecture

```
Internet (Anthropic/OpenAI APIs, AI Engine Pro)
    |
    | HTTPS + Bearer token
    v
IIS Reverse Proxy (myia-po-2023)
    mcp-tools.myia.io:443 -> myia-ai-01:9090
    |
    v
mcp-proxy container (port 9090) --- token auth ---
    |-- /searxng/     -> npx mcp-searxng (stdio subprocess) -> search.myia.io
    |-- /future-mcp/  -> (extensible, stdio ou SSE backends)

sk-agent container (port 8100) --- separate token ---
    |-- Open WebUI (skagents.myia.io, direct access)
    |-- Claude Code / Roo (stdio, local)

NOTE: sk-agent utilise streamable-http, incompatible avec le mode SSE
de mcp-proxy (v0.43.2). Routage via mcp-proxy prevu quand le proxy
supportera les backends per-server type (streamable-http).
```

## Services

| Service | Image | Port | Description |
|---------|-------|------|-------------|
| mcp-proxy | ghcr.io/tbxark/mcp-proxy | 9090 | Gateway HTTP/SSE pour MCPs stdio et URL |
| sk-agent | sk-agent:latest (build local) | 8100 | Multi-agent orchestration via Semantic Kernel |

## Setup rapide (myia-ai-01)

```bash
cd d:/roo-extensions/docker

# 1. Configurer mcp-proxy
cp mcp-proxy/config.template.json mcp-proxy/config.json
# Editer config.json : remplacer REPLACE_WITH_TOKEN par un vrai token
python -c "import secrets; print(secrets.token_hex(32))"

# 2. Configurer les variables d'environnement
cp .env.example .env
# Editer .env : mettre la cle API sk-agent

# 3. Build et lancer
docker compose build sk-agent --no-cache
docker compose up -d
```

## Commandes utiles

```bash
# Logs de tous les services
docker compose logs -f

# Rebuild sk-agent (apres mise a jour du code)
docker compose build sk-agent --no-cache
docker compose up -d --force-recreate sk-agent

# Restart mcp-proxy (apres modification de config.json)
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
    "searxng": { "..." },
    "nouveau-mcp-stdio": {
      "command": "npx",
      "args": ["-y", "nom-du-package-mcp"],
      "env": { "VAR": "valeur" }
    },
    "nouveau-mcp-sse": {
      "url": "http://host.docker.internal:PORT/sse"
    }
  }
}
```

**Note :** Les backends `url` doivent supporter le transport SSE (type global du proxy).
Les MCPs streamable-http ne sont pas encore supportes comme backends (v0.43.2).

Puis redemarrer : `docker compose restart mcp-proxy`

### Endpoints exposes

| MCP Server | SSE Endpoint | Outils |
|------------|-------------|--------|
| searxng | `/searxng/sse` | `searxng_web_search`, `web_url_read` |

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

- **Token mcp-proxy** : Protege l'acces externe (AI Engine Pro, LLM providers)
- **Token sk-agent** : Protege l'acces direct (Open WebUI via `skagents.myia.io`)
- **Double couche** : HTTPS (IIS) + token proxy + token sk-agent (si acces direct)
- sk-agent n'est PAS expose directement sur internet via mcp-proxy (trafic interne Docker)

## Reverse Proxies IIS

| Domaine | Port local | Service | Machine IIS | Notes |
|---------|-----------|---------|-------------|-------|
| `mcp-tools.myia.io` | 9090 | mcp-proxy (multi-MCP) | myia-po-2023 | SSE: desactiver buffering ARR |
| `skagents.myia.io` | 8100 | sk-agent (direct) | myia-ai-01 | Acces Open WebUI |

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

- **mcp-proxy** : [tbxark/mcp-proxy](https://github.com/tbxark/mcp-proxy) (Go)
- **sk-agent** : Python 3.11 + Semantic Kernel + Node.js 20
- **Transport** : SSE (Server-Sent Events) pour mcp-proxy, streamable-http pour sk-agent
- **MCPs integres** : mcp-searxng (Node.js, via npx dans mcp-proxy)
- **SearXNG** : https://search.myia.io/ (self-hosted)
