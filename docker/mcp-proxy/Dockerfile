# MyIA MCP Proxy - Custom image
# Extends tbxark/mcp-proxy with sk-agent Python dependencies
# so sk-agent can run as a stdio subprocess alongside mcp-searxng.
#
# Build context must be the repo root (set in docker-compose.yml)
# Build:  cd docker && docker compose build mcp-proxy --no-cache
# Result: Single container serving all MCPs via SSE on port 9090

FROM ghcr.io/tbxark/mcp-proxy:latest

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
