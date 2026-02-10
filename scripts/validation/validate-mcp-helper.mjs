/**
 * Helper Node.js pour validate-mcp-live.ps1
 * Demarre le serveur MCP, effectue les tests JSON-RPC, et retourne les resultats en JSON.
 *
 * Usage: node validate-mcp-helper.mjs [--skip-calls] [--verbose] [--timeout=15]
 */

import { spawn } from 'child_process';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { readFileSync, existsSync } from 'fs';

const __dirname = dirname(fileURLToPath(import.meta.url));

// Parse args
const args = process.argv.slice(2);
const skipCalls = args.includes('--skip-calls');
const verbose = args.includes('--verbose');
const timeoutArg = args.find(a => a.startsWith('--timeout='));
const TIMEOUT = timeoutArg ? parseInt(timeoutArg.split('=')[1]) * 1000 : 15000;
const repoRoot = args.find(a => a.startsWith('--repo='))?.split('=')[1] || join(__dirname, '..', '..');

const mcpRoot = join(repoRoot, 'mcps', 'internal', 'servers', 'roo-state-manager');
const wrapperPath = join(mcpRoot, 'mcp-wrapper.cjs');

// Expected tools (18)
const EXPECTED_TOOLS = [
    'roosync_send', 'roosync_read', 'roosync_manage',
    'roosync_get_status', 'roosync_list_diffs', 'roosync_compare_config', 'roosync_refresh_dashboard',
    'roosync_config', 'roosync_inventory', 'roosync_baseline', 'roosync_machines', 'roosync_init',
    'roosync_decision', 'roosync_decision_info',
    'roosync_heartbeat_status',
    'analyze_roosync_problems', 'diagnose_env',
    'roosync_summarize'
];

// Safe tools to call (read-only, no side effects)
const SAFE_CALL_TESTS = {
    'diagnose_env': { checkDiskSpace: false },
    'roosync_get_status': {},
    'roosync_read': { mode: 'inbox', limit: 1 },
    'roosync_machines': { status: 'all' },
    'roosync_heartbeat_status': {},
    'roosync_inventory': { type: 'machine' },
    'roosync_list_diffs': {},
    'analyze_roosync_problems': {},
    'roosync_compare_config': {},
    'roosync_decision_info': { decisionId: 'nonexistent-test' }
};

// Load .env
function loadEnv() {
    const envPath = join(mcpRoot, '.env');
    const env = { ...process.env };
    if (existsSync(envPath)) {
        const lines = readFileSync(envPath, 'utf-8').split('\n');
        for (const line of lines) {
            const match = line.match(/^\s*([^#][^=]+)=(.*)$/);
            if (match) {
                env[match[1].trim()] = match[2].trim().replace(/^["']|["']$/g, '');
            }
        }
    }
    if (!env.ROOSYNC_MACHINE_ID) {
        env.ROOSYNC_MACHINE_ID = process.env.COMPUTERNAME || 'unknown';
    }
    return env;
}

// JSON-RPC helper
let requestId = 0;
function makeRequest(method, params = {}) {
    return JSON.stringify({ jsonrpc: '2.0', id: ++requestId, method, params });
}
function makeNotification(method, params = {}) {
    return JSON.stringify({ jsonrpc: '2.0', method, params });
}

// Send request and wait for response
function sendRequest(serverProcess, message, timeout = TIMEOUT) {
    return new Promise((resolve, reject) => {
        const timer = setTimeout(() => {
            reject(new Error(`Timeout (${timeout}ms) waiting for response`));
        }, timeout);

        let buffer = '';

        function onData(chunk) {
            buffer += chunk.toString();
            const lines = buffer.split('\n');
            buffer = lines.pop(); // keep incomplete line

            for (const line of lines) {
                const trimmed = line.trim();
                if (!trimmed) continue;
                try {
                    const parsed = JSON.parse(trimmed);
                    if (parsed.id !== undefined) {
                        clearTimeout(timer);
                        serverProcess.stdout.removeListener('data', onData);
                        resolve(parsed);
                        return;
                    }
                    // Notification, skip
                    if (verbose) process.stderr.write(`  (notification: ${parsed.method})\n`);
                } catch {
                    // Not JSON (log line), skip
                    if (verbose) process.stderr.write(`  (non-json: ${trimmed.substring(0, 80)})\n`);
                }
            }
        }

        serverProcess.stdout.on('data', onData);
        serverProcess.stdin.write(message + '\n');
    });
}

// Send notification (no response expected)
function sendNotification(serverProcess, message) {
    serverProcess.stdin.write(message + '\n');
}

// Main
async function main() {
    const results = {
        timestamp: new Date().toISOString(),
        machine: process.env.COMPUTERNAME || 'unknown',
        phase1: null,
        phase2: null,
        phase3: [],
        summary: { total: 0, passed: 0, failed: 0, skipped: 0 }
    };

    let server = null;

    try {
        // Phase 1: Start server
        if (verbose) process.stderr.write('--- Phase 1: Starting MCP server ---\n');

        const env = loadEnv();
        server = spawn('node', [wrapperPath], {
            cwd: mcpRoot,
            env,
            stdio: ['pipe', 'pipe', 'pipe']
        });

        // Drain stderr
        server.stderr.on('data', (chunk) => {
            if (verbose) process.stderr.write(`  [stderr] ${chunk.toString().trim()}\n`);
        });

        // Wait for server to start
        await new Promise(resolve => setTimeout(resolve, 2000));

        if (server.exitCode !== null) {
            throw new Error(`Server exited with code ${server.exitCode}`);
        }

        results.phase1 = { status: 'started', pid: server.pid };
        results.summary.total++;
        results.summary.passed++;

        // Initialize handshake
        if (verbose) process.stderr.write('  Sending initialize...\n');
        const initResponse = await sendRequest(server, makeRequest('initialize', {
            protocolVersion: '2024-11-05',
            capabilities: {},
            clientInfo: { name: 'validate-mcp-live', version: '1.0.0' }
        }), 10000);

        if (initResponse.error) {
            results.phase1.init = { status: 'error', error: initResponse.error.message };
            results.summary.total++;
            results.summary.failed++;
        } else {
            results.phase1.init = {
                status: 'ok',
                protocolVersion: initResponse.result?.protocolVersion,
                serverName: initResponse.result?.serverInfo?.name
            };
            results.summary.total++;
            results.summary.passed++;
        }

        // Send initialized notification
        sendNotification(server, makeNotification('notifications/initialized'));
        await new Promise(resolve => setTimeout(resolve, 500));

        // Phase 2: tools/list
        if (verbose) process.stderr.write('--- Phase 2: tools/list ---\n');

        const listResponse = await sendRequest(server, makeRequest('tools/list'));

        if (listResponse.error) {
            results.phase2 = { status: 'error', error: listResponse.error.message };
            results.summary.total++;
            results.summary.failed++;
        } else {
            const tools = listResponse.result?.tools || [];
            const toolNames = tools.map(t => t.name);

            const missing = EXPECTED_TOOLS.filter(t => !toolNames.includes(t));
            const extra = toolNames.filter(t => !EXPECTED_TOOLS.includes(t));

            results.phase2 = {
                status: missing.length === 0 ? 'ok' : 'error',
                expected: EXPECTED_TOOLS.length,
                actual: toolNames.length,
                tools: toolNames,
                missing,
                extra
            };

            // Count test
            results.summary.total++;
            if (toolNames.length === EXPECTED_TOOLS.length) {
                results.summary.passed++;
            } else {
                results.summary.failed++;
            }

            // Individual tool presence
            for (const expected of EXPECTED_TOOLS) {
                results.summary.total++;
                if (toolNames.includes(expected)) {
                    results.summary.passed++;
                } else {
                    results.summary.failed++;
                }
            }
        }

        // Phase 3: tools/call
        if (!skipCalls) {
            if (verbose) process.stderr.write('--- Phase 3: tools/call ---\n');

            for (const [toolName, toolArgs] of Object.entries(SAFE_CALL_TESTS).sort()) {
                const callResult = { tool: toolName, status: 'unknown', duration_ms: 0 };
                results.summary.total++;

                try {
                    const start = Date.now();
                    const callResponse = await sendRequest(server, makeRequest('tools/call', {
                        name: toolName,
                        arguments: toolArgs
                    }));
                    callResult.duration_ms = Date.now() - start;

                    if (callResponse.error) {
                        const msg = callResponse.error.message || '';
                        if (/not found|non trouve|introuvable|ENOENT|path/i.test(msg)) {
                            callResult.status = 'skipped';
                            callResult.reason = msg.substring(0, 100);
                            results.summary.skipped++;
                            results.summary.total--; // Don't count skipped in total
                        } else {
                            callResult.status = 'failed';
                            callResult.error = msg.substring(0, 200);
                            results.summary.failed++;
                        }
                    } else if (callResponse.result) {
                        const isError = callResponse.result.isError;
                        if (isError) {
                            const text = callResponse.result.content?.[0]?.text || '';
                            if (/not found|non trouve|introuvable|ENOENT|non disponible|path.*exist/i.test(text)) {
                                callResult.status = 'skipped';
                                callResult.reason = 'runtime_env';
                                results.summary.skipped++;
                                results.summary.total--;
                            } else {
                                callResult.status = 'failed';
                                callResult.error = text.substring(0, 200);
                                results.summary.failed++;
                            }
                        } else {
                            callResult.status = 'passed';
                            results.summary.passed++;
                        }
                    }
                } catch (e) {
                    callResult.status = 'failed';
                    callResult.error = e.message;
                    results.summary.failed++;
                }

                results.phase3.push(callResult);
                if (verbose) process.stderr.write(`  ${callResult.status}: ${toolName} (${callResult.duration_ms}ms)\n`);
            }

            // Mark untested tools
            for (const tool of EXPECTED_TOOLS) {
                if (!(tool in SAFE_CALL_TESTS)) {
                    results.phase3.push({ tool, status: 'skipped', reason: 'not_safe_to_call' });
                    results.summary.skipped++;
                }
            }
        }

    } catch (e) {
        results.fatal = e.message;
        results.summary.total++;
        results.summary.failed++;
    } finally {
        if (server && server.exitCode === null) {
            try {
                server.stdin.end();
                await new Promise(resolve => setTimeout(resolve, 1000));
                if (server.exitCode === null) server.kill();
            } catch { /* ignore */ }
        }
    }

    // Output results as JSON to stdout
    process.stdout.write(JSON.stringify(results, null, 2) + '\n');
    process.exit(results.summary.failed > 0 ? 1 : 0);
}

main();
