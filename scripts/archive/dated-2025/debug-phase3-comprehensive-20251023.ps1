# Script de débogage complet Phase 3
# Capture tous les logs de build_skeleton_cache

Write-Host "=== DEBUG PHASE 3 COMPREHENSIVE ===" -ForegroundColor Cyan
Write-Host ""

# Appeler le MCP avec logging maximal
$result = node -e "
const client = require('@modelcontextprotocol/sdk/client/index.js');
const { StdioClientTransport } = require('@modelcontextprotocol/sdk/client/stdio.js');

async function test() {
  const transport = new StdioClientTransport({
    command: 'node',
    args: ['D:/Dev/roo-extensions/mcps/internal/servers/roo-state-manager/build/index.js']
  });
  
  const mcpClient = new client.Client({ name: 'debug-client', version: '1.0.0' }, { capabilities: {} });
  
  await mcpClient.connect(transport);
  
  const result = await mcpClient.callTool('build_skeleton_cache', {
    force_rebuild: true,
    task_ids: ['cb7e564f-152f-48e3-8eff-f424d7ebc6bd', '18141742-f376-4053-8e1f-804d79daaf6d']
  });
  
  console.log(JSON.stringify(result, null, 2));
  
  await mcpClient.close();
}

test().catch(console.error);
" 2>&1

Write-Host $result
Write-Host ""
Write-Host "=== FIN DEBUG ===" -ForegroundColor Cyan