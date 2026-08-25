# MyIA MCP Proxy - Custom image
# Extends tbxark/mcp-proxy with sk-agent Python dependencies
# so sk-agent can run as a stdio subprocess alongside mcp-searxng.
#
# Build context must be the repo root (set in docker-compose.yml)
# Build:  cd docker && docker compose build mcp-proxy --no-cache
# Result: Single container serving all MCPs via SSE on port 9090

FROM ghcr.io/tbxark/mcp-proxy:latest

# Pre-install mcp-searxng at build time.
# It used to be launched with `npx -y mcp-searxng`, which installs into the shared
# /root/.npm/_npx cache on every container start. A partial install left behind by an
# interrupted start makes every later install fail with ENOTEMPTY (rename of node_modules/hono),
# the searxng child never starts, and mcp-proxy serves 404 on /searxng/* while the other
# routes stay healthy — a failure that looks like a lost config entry but is not one.
RUN npm install -g mcp-searxng

# Install sk-agent Python dependencies
COPY mcps/internal/servers/sk-agent/requirements.txt /tmp/sk-agent-requirements.txt
RUN pip install --no-cache-dir -r /tmp/sk-agent-requirements.txt && \
    rm /tmp/sk-agent-requirements.txt

# Copy sk-agent source code (only .py files needed for runtime)
COPY mcps/internal/servers/sk-agent/sk_agent.py \
     mcps/internal/servers/sk-agent/sk_agent_config.py \
     mcps/internal/servers/sk-agent/sk_conversations.py \
     mcps/internal/servers/sk-agent/document_processing.py \
     mcps/internal/servers/sk-agent/media_processing.py \
     /opt/sk-agent/
