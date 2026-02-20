#!/usr/bin/env node
/**
 * sync-roo-alwaysallow.js
 *
 * Synchronise les auto-approbations (alwaysAllow) pour tous les outils MCP
 * utilisés par Roo Code.
 *
 * Usage:
 *   node scripts/sync-roo-alwaysallow.js [--dry-run] [--server <name>]
 *
 * Options:
 *   --dry-run    Affiche les changements sans les appliquer
 *   --server     Traite uniquement le serveur spécifié
 *   --verbose    Affiche plus de détails
 *
 * @version 1.0.0
 * @issue #496
 */

const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

// Configuration
const MCP_SETTINGS_PATH = path.join(
    process.env.APPDATA,
    'Code',
    'User',
    'globalStorage',
    'rooveterinaryinc.roo-cline',
    'settings',
    'mcp_settings.json'
);

// Outils connus par serveur (fallback si tools/list échoue)
const KNOWN_TOOLS = {
    'roo-state-manager': [
        'analyze_roosync_problems',
        'codebase_search',
        'conversation_browser',
        'export_config',
        'export_data',
        'get_mcp_best_practices',
        'get_raw_conversation',
        'maintenance',
        'manage_mcp_settings',
        'read_vscode_logs',
        'rebuild_and_restart_mcp',
        'roosync_baseline',
        'roosync_compare_config',
        'roosync_config',
        'roosync_decision',
        'roosync_decision_info',
        'roosync_diagnose',
        'roosync_get_status',
        'roosync_heartbeat',
        'roosync_indexing',
        'roosync_init',
        'roosync_inventory',
        'roosync_list_diffs',
        'roosync_machines',
        'roosync_manage',
        'roosync_mcp_management',
        'roosync_read',
        'roosync_refresh_dashboard',
        'roosync_search',
        'roosync_send',
        'roosync_storage_management',
        'roosync_summarize',
        'roosync_sync_event',
        'storage_info',
        'task_browse',
        'task_export',
        'touch_mcp_settings',
        'view_conversation_tree',
        'view_task_details'
    ],
    'desktop-commander': [
        'create_directory',
        'edit_block',
        'force_terminate',
        'get_config',
        'get_file_info',
        'get_more_search_results',
        'get_prompts',
        'get_recent_tool_calls',
        'get_usage_stats',
        'give_feedback_to_desktop_commander',
        'interact_with_process',
        'kill_process',
        'list_directory',
        'list_processes',
        'list_searches',
        'list_sessions',
        'move_file',
        'read_file',
        'read_multiple_files',
        'read_process_output',
        'set_config_value',
        'start_process',
        'start_search',
        'stop_search',
        'write_file',
        'write_pdf'
    ],
    'win-cli': [
        'create_ssh_connection',
        'delete_ssh_connection',
        'execute_command',
        'get_command_history',
        'get_current_directory',
        'read_ssh_connections',
        'ssh_disconnect',
        'ssh_execute',
        'update_ssh_connection'
    ],
    'playwright': [
        'browser_navigate',
        'browser_click',
        'browser_take_screenshot',
        'browser_close',
        'browser_snapshot',
        'browser_install',
        'browser_wait_for',
        'browser_type',
        'browser_fill_form',
        'browser_console_messages',
        'browser_network_requests',
        'browser_evaluate',
        'browser_run_code',
        'browser_press_key',
        'browser_tabs'
    ],
    'searxng': [
        'web_url_read',
        'searxng_web_search'
    ],
    'markitdown': [
        'convert_to_markdown'
    ],
    'jupyter': [
        'read_notebook',
        'write_notebook',
        'create_notebook',
        'add_cell',
        'remove_cell',
        'update_cell',
        'inspect_notebook',
        'manage_kernel',
        'execute_on_kernel',
        'execute_notebook',
        'list_notebook_files',
        'get_notebook_info',
        'get_kernel_status',
        'cleanup_all_kernels',
        'start_jupyter_server',
        'stop_jupyter_server',
        'manage_async_job',
        'list_kernels',
        'system_info',
        'start_notebook_async',
        'execute_notebook_sync',
        'read_cells'
    ]
};

// Parse arguments
const args = process.argv.slice(2);
const dryRun = args.includes('--dry-run');
const verbose = args.includes('--verbose');
const serverArg = args.find(a => !a.startsWith('--'));
const targetServer = args.includes('--server') ? args[args.indexOf('--server') + 1] : serverArg;

/**
 * Log message if verbose mode
 */
function log(...messages) {
    if (verbose || dryRun) {
        console.log(...messages);
    }
}

/**
 * Read MCP settings file
 */
function readMcpSettings() {
    if (!fs.existsSync(MCP_SETTINGS_PATH)) {
        console.error(`❌ Fichier non trouvé: ${MCP_SETTINGS_PATH}`);
        process.exit(1);
    }

    let content = fs.readFileSync(MCP_SETTINGS_PATH, 'utf-8');

    // Strip BOM if present
    if (content.charCodeAt(0) === 0xFEFF) {
        content = content.slice(1);
    }

    return JSON.parse(content);
}

/**
 * Write MCP settings file
 */
function writeMcpSettings(settings) {
    const content = JSON.stringify(settings, null, '\t');
    fs.writeFileSync(MCP_SETTINGS_PATH, content, 'utf-8');
    console.log(`✅ Fichier mis à jour: ${MCP_SETTINGS_PATH}`);
}

/**
 * Get tools for a server using known tools list
 */
function getKnownTools(serverName) {
    return KNOWN_TOOLS[serverName] || [];
}

/**
 * Sync alwaysAllow for a single server
 */
function syncServer(serverName, serverConfig, settings) {
    // Skip disabled servers
    if (serverConfig.disabled) {
        log(`  ⏭️  ${serverName}: désactivé, ignoré`);
        return { added: 0, skipped: true };
    }

    const currentAllow = serverConfig.alwaysAllow || [];
    const knownTools = getKnownTools(serverName);

    if (knownTools.length === 0) {
        log(`  ⚠️  ${serverName}: aucun outil connu, ignoré`);
        return { added: 0, skipped: true };
    }

    // Find missing tools
    const missing = knownTools.filter(tool => !currentAllow.includes(tool));
    const extra = currentAllow.filter(tool => !knownTools.includes(tool));

    if (missing.length === 0 && extra.length === 0) {
        log(`  ✅ ${serverName}: ${currentAllow.length} outils, déjà complet`);
        return { added: 0, complete: true };
    }

    if (missing.length > 0) {
        console.log(`  📥 ${serverName}: ${missing.length} outils à ajouter`);
        missing.forEach(tool => console.log(`     + ${tool}`));
    }

    if (extra.length > 0 && verbose) {
        console.log(`  📤 ${serverName}: ${extra.length} outils supplémentaires (conservés)`);
        extra.forEach(tool => console.log(`     ? ${tool}`));
    }

    // Apply changes if not dry run
    if (!dryRun) {
        settings.mcpServers[serverName].alwaysAllow = [...new Set([...currentAllow, ...knownTools])].sort();
    }

    return { added: missing.length, complete: false };
}

/**
 * Main sync function
 */
function syncAllServers() {
    console.log('🔄 Synchronisation auto-approbations Roo');
    console.log(`📁 Fichier: ${MCP_SETTINGS_PATH}`);
    if (dryRun) {
        console.log('⚠️  Mode DRY-RUN: aucun changement appliqué');
    }
    console.log('');

    const settings = readMcpSettings();
    const servers = Object.entries(settings.mcpServers);

    let totalAdded = 0;
    let totalComplete = 0;
    let totalSkipped = 0;

    // Filter by target server if specified
    const serversToProcess = targetServer
        ? servers.filter(([name]) => name === targetServer)
        : servers;

    if (targetServer && serversToProcess.length === 0) {
        console.error(`❌ Serveur non trouvé: ${targetServer}`);
        console.log(`Serveurs disponibles: ${servers.map(([n]) => n).join(', ')}`);
        process.exit(1);
    }

    for (const [name, config] of serversToProcess) {
        const result = syncServer(name, config, settings);
        totalAdded += result.added;
        if (result.complete) totalComplete++;
        if (result.skipped) totalSkipped++;
    }

    console.log('');

    if (dryRun) {
        console.log(`📊 Résumé (DRY-RUN): ${totalAdded} outils seraient ajoutés`);
    } else if (totalAdded > 0) {
        writeMcpSettings(settings);
        console.log(`📊 Résumé: ${totalAdded} outils ajoutés, ${totalComplete} serveurs déjà complets, ${totalSkipped} ignorés`);
        console.log('');
        console.log('⚠️  IMPORTANT: Redémarrez VS Code pour charger les nouveaux paramètres!');
    } else {
        console.log(`📊 Résumé: Tous les serveurs actifs sont déjà complets`);
    }
}

// Run
syncAllServers();
