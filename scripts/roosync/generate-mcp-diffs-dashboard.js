/**
 * Script pour générer un dashboard HTML des diffs MCP entre machines
 * Utilise GranularDiffDetector pour comparer les configurations MCP
 *
 * IMPORTANT: Requiert la variable d'environnement ROOSYNC_SHARED_PATH
 * pointant vers le répertoire GDrive partagé.
 */

const { GranularDiffDetector } = require('../../mcps/internal/servers/roo-state-manager/build/services/GranularDiffDetector.js');
const fs = require('fs').promises;
const path = require('path');

// Vérifier que ROOSYNC_SHARED_PATH est défini
const SHARED_PATH = process.env.ROOSYNC_SHARED_PATH;
if (!SHARED_PATH) {
  console.error('❌ ERREUR: Variable d\'environnement ROOSYNC_SHARED_PATH non définie.');
  console.error('   Cette variable doit pointer vers le répertoire GDrive partagé.');
  console.error('   Ex: G:/Mon Drive/Synchronisation/RooSync/.shared-state');
  process.exit(1);
}

// Configuration - utilise ROOSYNC_SHARED_PATH pour les chemins partagés
const INVENTORIES_DIR = path.join(SHARED_PATH, 'inventories');
const EXPORTS_DIR = path.join(__dirname, '../../mcps/internal/servers/roo-state-manager/exports');
const OUTPUT_DIR = path.join(SHARED_PATH, 'dashboards');

/**
 * Charge un inventaire depuis un fichier JSON
 */
async function loadInventory(filePath) {
  try {
    const content = await fs.readFile(filePath, 'utf-8');
    return JSON.parse(content);
  } catch (error) {
    console.error(`Erreur lors du chargement de ${filePath}:`, error.message);
    return null;
  }
}

/**
 * Extrait la configuration MCP d'un inventaire
 */
function extractMCPConfig(inventory) {
  if (!inventory) return null;

  // Format InventoryService (nouveau)
  if (inventory.inventory && inventory.inventory.mcpServers) {
    return {
      machineId: inventory.machineId,
      mcpServers: inventory.inventory.mcpServers,
      timestamp: inventory.timestamp
    };
  }

  // Format InventoryCollector (legacy)
  if (inventory.config && inventory.config.roo && inventory.config.roo.mcpServers) {
    return {
      machineId: inventory.machineId,
      mcpServers: inventory.config.roo.mcpServers,
      timestamp: inventory.timestamp
    };
  }

  return null;
}

/**
 * Extrait le contenu pertinent d'un rapport HTML de diff
 */
function extractDiffContent(htmlReport) {
  // Extraire la section des différences du rapport HTML
  const diffSectionMatch = htmlReport.match(/<h2>Differences<\/h2>([\s\S]*?)<div class="performance">/);
  if (diffSectionMatch) {
    return diffSectionMatch[1].trim();
  }

  // Si pas de section différences, vérifier s'il y a des différences
  const totalDiffsMatch = htmlReport.match(/<p><strong>Total differences:<\/strong> (\d+)<\/p>/);
  if (totalDiffsMatch && totalDiffsMatch[1] === '0') {
    return '<div class="no-diffs">Aucune différence détectée</div>';
  }

  return '<div class="warning">Impossible d\'extraire le contenu du diff</div>';
}

/**
 * Génère un rapport de diff HTML
 */
async function generateDiffReport(sourceMachine, targetMachine, sourceConfig, targetConfig) {
  const detector = new GranularDiffDetector();

  const report = await detector.compareGranular(
    sourceConfig,
    targetConfig,
    sourceMachine,
    targetMachine,
    {
      includeUnchanged: false,
      ignoreWhitespace: true,
      arrayDiffMode: 'identity'
    }
  );

  const htmlReport = await detector.exportDiff(report, 'html');
  return {
    html: extractDiffContent(htmlReport),
    totalDiffs: report.summary.total
  };
}

/**
 * Crée le dashboard HTML principal
 */
function createDashboardHTML(diffReports, machines) {
  const timestamp = new Date().toISOString();

  let html = `<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dashboard Diffs MCP - RooSync</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 20px;
            min-height: 100vh;
        }

        .container {
            max-width: 1400px;
            margin: 0 auto;
            background: white;
            border-radius: 10px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            overflow: hidden;
        }

        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }

        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
        }

        .header p {
            font-size: 1.1em;
            opacity: 0.9;
        }

        .summary {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            padding: 30px;
            background: #f8f9fa;
        }

        .summary-card {
            background: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            text-align: center;
        }

        .summary-card h3 {
            color: #667eea;
            font-size: 2em;
            margin-bottom: 5px;
        }

        .summary-card p {
            color: #666;
            font-size: 0.9em;
        }

        .machines-list {
            padding: 30px;
        }

        .machines-list h2 {
            color: #333;
            margin-bottom: 20px;
            border-bottom: 3px solid #667eea;
            padding-bottom: 10px;
        }

        .machine-item {
            background: #f8f9fa;
            padding: 15px;
            margin-bottom: 10px;
            border-radius: 5px;
            border-left: 4px solid #667eea;
        }

        .machine-item strong {
            color: #333;
        }

        .diffs-section {
            padding: 30px;
        }

        .diffs-section h2 {
            color: #333;
            margin-bottom: 20px;
            border-bottom: 3px solid #667eea;
            padding-bottom: 10px;
        }

        .diff-pair {
            margin-bottom: 30px;
            border: 1px solid #e0e0e0;
            border-radius: 8px;
            overflow: hidden;
        }

        .diff-pair-header {
            background: #667eea;
            color: white;
            padding: 15px;
            font-weight: bold;
        }

        .diff-pair-content {
            padding: 20px;
        }

        .no-diffs {
            background: #d4edda;
            color: #155724;
            padding: 20px;
            border-radius: 5px;
            text-align: center;
            margin: 20px 0;
        }

        .warning {
            background: #fff3cd;
            color: #856404;
            padding: 20px;
            border-radius: 5px;
            margin: 20px 0;
            border-left: 4px solid #ffc107;
        }

        .footer {
            background: #333;
            color: white;
            padding: 20px;
            text-align: center;
            font-size: 0.9em;
        }

        .diff-critical { border-left-color: #d32f2f; }
        .diff-important { border-left-color: #f57c00; }
        .diff-warning { border-left-color: #fbc02d; }
        .diff-info { border-left-color: #1976d2; }
        .diff-path { font-family: monospace; background: #f0f0f0; padding: 2px 5px; }
        .diff-values { margin-top: 5px; }
        .old-value { background: #ffebee; padding: 5px; }
        .new-value { background: #e8f5e8; padding: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📊 Dashboard Diffs MCP</h1>
            <p>Généré le ${new Date(timestamp).toLocaleString('fr-FR')}</p>
        </div>

        <div class="summary">
            <div class="summary-card">
                <h3>${machines.length}</h3>
                <p>Machines analysées</p>
            </div>
            <div class="summary-card">
                <h3>${diffReports.length}</h3>
                <p>Comparaisons effectuées</p>
            </div>
            <div class="summary-card">
                <h3>${diffReports.reduce((sum, r) => sum + r.totalDiffs, 0)}</h3>
                <p>Diffs détectés</p>
            </div>
        </div>

        <div class="machines-list">
            <h2>🖥️ Machines analysées</h2>
            ${machines.map(m => `
                <div class="machine-item">
                    <strong>${m.machineId}</strong>
                    <br>
                    <small>Dernière mise à jour: ${m.timestamp ? new Date(m.timestamp).toLocaleString('fr-FR') : 'N/A'}</small>
                </div>
            `).join('')}
        </div>

        <div class="diffs-section">
            <h2>🔍 Comparaisons MCP</h2>
            ${diffReports.length === 0 ? `
                <div class="warning">
                    <strong>⚠️ Attention:</strong> Seul un inventaire est disponible. Impossible de générer des diffs entre machines.
                    <br><br>
                    Veuillez collecter les inventaires des autres machines pour générer un dashboard complet.
                </div>
            ` : diffReports.map(report => `
                <div class="diff-pair">
                    <div class="diff-pair-header">
                        ${report.source} ↔ ${report.target}
                    </div>
                    <div class="diff-pair-content">
                        ${report.html}
                    </div>
                </div>
            `).join('')}
        </div>

        <div class="footer">
            <p>Dashboard généré par RooSync - GranularDiffDetector</p>
            <p>Version 1.0.0 | ${timestamp}</p>
        </div>
    </div>
</body>
</html>`;

  return html;
}

/**
 * Fonction principale
 */
async function main() {
  console.log('🚀 Génération du dashboard HTML des diffs MCP...\n');

  try {
    // Créer le répertoire de sortie
    await fs.mkdir(OUTPUT_DIR, { recursive: true });

    // Charger les inventaires disponibles
    console.log('📂 Chargement des inventaires...');
    const inventoryFiles = await fs.readdir(INVENTORIES_DIR);
    const inventories = [];

    for (const file of inventoryFiles) {
      if (file.endsWith('.json')) {
        const inventory = await loadInventory(path.join(INVENTORIES_DIR, file));
        if (inventory) {
          const mcpConfig = extractMCPConfig(inventory);
          if (mcpConfig) {
            inventories.push(mcpConfig);
            console.log(`  ✅ ${mcpConfig.machineId}: ${mcpConfig.mcpServers.length} serveurs MCP`);
          }
        }
      }
    }

    // Charger les baselines exportées
    console.log('\n📂 Chargement des baselines exportées...');
    const exportFiles = await fs.readdir(EXPORTS_DIR);

    for (const file of exportFiles) {
      if (file.startsWith('baseline-export-') && file.endsWith('.json')) {
        const baseline = await loadInventory(path.join(EXPORTS_DIR, file));
        if (baseline && baseline.metadata && baseline.configuration) {
          const mcpConfig = {
            machineId: baseline.metadata.machineId,
            mcpServers: baseline.configuration.roo?.mcpSettings || {},
            timestamp: baseline.metadata.lastUpdated
          };
          inventories.push(mcpConfig);
          console.log(`  ✅ ${mcpConfig.machineId}: baseline exportée`);
        }
      }
    }

    console.log(`\n📊 Total: ${inventories.length} inventaires chargés`);

    // Générer les diffs entre toutes les paires de machines
    const diffReports = [];

    if (inventories.length < 2) {
      console.log('\n⚠️  Moins de 2 inventaires disponibles, impossible de générer des diffs');
    } else {
      console.log('\n🔍 Génération des diffs...');
      for (let i = 0; i < inventories.length; i++) {
        for (let j = i + 1; j < inventories.length; j++) {
          const source = inventories[i];
          const target = inventories[j];

          console.log(`  📊 Comparaison: ${source.machineId} ↔ ${target.machineId}`);

          try {
            const diffResult = await generateDiffReport(
              source.machineId,
              target.machineId,
              source.mcpServers,
              target.mcpServers
            );

            diffReports.push({
              source: source.machineId,
              target: target.machineId,
              totalDiffs: diffResult.totalDiffs,
              html: diffResult.html
            });

            console.log(`    ✅ ${diffResult.totalDiffs} diffs détectés`);
          } catch (error) {
            console.error(`    ❌ Erreur: ${error.message}`);
          }
        }
      }
    }

    // Créer le dashboard HTML
    console.log('\n📝 Création du dashboard HTML...');
    const dashboardHTML = createDashboardHTML(diffReports, inventories);

    // Sauvegarder le dashboard
    const outputPath = path.join(OUTPUT_DIR, `mcp-diffs-dashboard-${Date.now()}.html`);
    await fs.writeFile(outputPath, dashboardHTML, 'utf-8');

    console.log(`\n✅ Dashboard généré avec succès!`);
    console.log(`📁 Fichier: ${outputPath}`);
    console.log(`📊 ${inventories.length} machines analysées`);
    console.log(`🔍 ${diffReports.length} comparaisons effectuées`);
    console.log(`📈 ${diffReports.reduce((sum, r) => sum + r.totalDiffs, 0)} diffs détectés`);

  } catch (error) {
    console.error('\n❌ Erreur lors de la génération du dashboard:', error);
    process.exit(1);
  }
}

// Exécuter le script
main();
