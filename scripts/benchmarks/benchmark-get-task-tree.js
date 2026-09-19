const { Client } = require("@modelcontextprotocol/sdk/client/index.js");
const { StdioClientTransport } = require("@modelcontextprotocol/sdk/client/stdio.js");
const path = require("path");
const { pathToFileURL } = require("url");

// #3713 W2: resolve the published vintage via the submodule's canonical resolver
// (build-current marker -> build-<sha16>/, legacy build/ fallback). A hardcoded
// build/index.js would benchmark the frozen legacy vintage forever.
const RSM_ROOT = path.resolve(__dirname, "../../mcps/internal/servers/roo-state-manager");
let SERVER_PATH;
const TASK_ID = "0bef7c0b-715a-485e-a74d-958b518652eb"; // Tâche lourde identifiée

async function runBenchmark() {
  const { resolveBuildDir } = await import(
    pathToFileURL(path.join(RSM_ROOT, "scripts/lib/resolve-build-dir.mjs")).href
  );
  SERVER_PATH = path.join(resolveBuildDir(RSM_ROOT), "index.js");
  console.log(`🚀 Démarrage du benchmark sur la tâche ${TASK_ID}...`);
  console.log(`📂 Serveur MCP : ${SERVER_PATH}`);

  const transport = new StdioClientTransport({
    command: "node",
    args: [SERVER_PATH],
  });

  const client = new Client(
    {
      name: "benchmark-client",
      version: "1.0.0",
    },
    {
      capabilities: {},
    }
  );

  try {
    await client.connect(transport);
    console.log("✅ Connecté au serveur MCP.");

    const start = performance.now();
    
    console.log("⏳ Exécution de get_task_tree...");
    const result = await client.callTool({
      name: "get_task_tree",
      arguments: {
        conversation_id: TASK_ID,
        max_depth: 5,
        output_format: "json"
      },
    });

    const end = performance.now();
    const duration = (end - start).toFixed(2);

    console.log(`⏱️ Temps d'exécution : ${duration} ms`);
    
    if (result.isError) {
        console.error("❌ Erreur lors de l'appel de l'outil:", result);
    } else {
        console.log("✅ Appel réussi.");
        // console.log("Résultat (extrait):", JSON.stringify(result.content).substring(0, 200) + "...");
    }

  } catch (error) {
    console.error("❌ Erreur critique:", error);
  } finally {
    await client.close();
  }
}

runBenchmark();