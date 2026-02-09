#!/usr/bin/env node
/**
 * E2E Validation Script for MCP Tools (#425)
 *
 * Spawns the MCP server via mcp-wrapper.cjs and tests all 18 tools.
 * Generates a JSON report with pass/fail for each tool.
 *
 * Usage:
 *   node scripts/validation/e2e-test-tools.js
 *   node scripts/validation/e2e-test-tools.js --json    # JSON output only
 *   node scripts/validation/e2e-test-tools.js --verbose  # Detailed output
 *
 * @version 1.0.0
 */

const { spawn } = require('child_process');
const path = require('path');

// --- Config ---
const WRAPPER_PATH = path.resolve(__dirname, '../../mcps/internal/servers/roo-state-manager/mcp-wrapper.cjs');
const TIMEOUT_MS = 30000; // 30s per tool call (diagnose_env can be slow)
const ARGS = process.argv.slice(2);
const JSON_ONLY = ARGS.includes('--json');
const VERBOSE = ARGS.includes('--verbose');

// Tools to test with their test parameters
const TOOL_TESTS = [
  // Diagnostic (safe, read-only)
  { name: 'diagnose_env', params: {}, description: 'Environment diagnostic' },
  { name: 'analyze_roosync_problems', params: {}, description: 'Analyze RooSync problems' },

  // Status/Read (safe, read-only)
  { name: 'roosync_get_status', params: {}, description: 'Get sync status' },
  { name: 'roosync_list_diffs', params: { filterType: 'all' }, description: 'List diffs' },
  { name: 'roosync_heartbeat_status', params: { filter: 'all' }, description: 'Heartbeat status' },
  { name: 'roosync_machines', params: { status: 'all' }, description: 'List machines' },

  // Config (dry-run only)
  { name: 'roosync_config', params: { action: 'collect', targets: ['modes'], dryRun: true }, description: 'Config collect dry-run' },

  // Inventory
  { name: 'roosync_inventory', params: { type: 'machine' }, description: 'Machine inventory' },

  // Baseline (export only, safe)
  { name: 'roosync_baseline', params: { action: 'export', format: 'json' }, description: 'Baseline export' },

  // Compare config (read-only)
  { name: 'roosync_compare_config', params: {}, description: 'Compare config' },

  // Dashboard (read-only)
  { name: 'roosync_refresh_dashboard', params: {}, description: 'Refresh dashboard' },

  // Init (safe if already initialized)
  { name: 'roosync_init', params: { force: false }, description: 'Init check (no force)' },

  // Summary (needs a taskId, expected to fail with nonexistent ID)
  { name: 'roosync_summarize', params: { type: 'trace', taskId: 'test-nonexistent' }, description: 'Summarize (expected error: nonexistent taskId)', expectedError: true },

  // Messaging CONS-1 (read-only operations)
  { name: 'roosync_read', params: { mode: 'inbox' }, description: 'Read inbox' },
  { name: 'roosync_send', params: { action: 'send', to: 'test-machine', subject: 'E2E-TEST', body: 'Test message from e2e-test-tools.js', dryRun: true }, description: 'Send message (dry-run)' },

  // Decisions CONS-5 (expected errors with nonexistent IDs)
  { name: 'roosync_decision_info', params: { action: 'history', decisionId: 'test-nonexistent' }, description: 'Decision info (expected error: nonexistent ID)', expectedError: true },
  { name: 'roosync_decision', params: { action: 'approve', decisionId: 'test-nonexistent', reason: 'E2E test' }, description: 'Decision approve (expected error: nonexistent ID)', expectedError: true },

  // Manage (expected error with nonexistent ID)
  { name: 'roosync_manage', params: { action: 'mark_read', messageId: 'test-nonexistent' }, description: 'Manage mark_read (expected error: nonexistent ID)', expectedError: true },
];

// --- MCP JSON-RPC Client ---
class McpClient {
  constructor(wrapperPath) {
    this.wrapperPath = wrapperPath;
    this.server = null;
    this.buffer = '';
    this.pendingRequests = new Map();
    this.nextId = 1;
  }

  async start() {
    return new Promise((resolve, reject) => {
      this.server = spawn('node', [this.wrapperPath], {
        cwd: path.dirname(this.wrapperPath),
        env: { ...process.env, ROO_DEBUG_LOGS: VERBOSE ? '1' : '' },
        stdio: ['pipe', 'pipe', 'pipe']
      });

      this.server.stderr.on('data', (data) => {
        if (VERBOSE) process.stderr.write(`[SERVER] ${data}`);
      });

      this.server.stdout.on('data', (data) => {
        this.buffer += data.toString();
        this._processBuffer();
      });

      this.server.on('error', reject);

      // Send initialize
      const initId = this.nextId++;
      this._send({
        jsonrpc: '2.0',
        id: initId,
        method: 'initialize',
        params: {
          protocolVersion: '2024-11-05',
          capabilities: {},
          clientInfo: { name: 'e2e-test-tools', version: '1.0.0' }
        }
      });

      this.pendingRequests.set(initId, { resolve, reject, timeout: setTimeout(() => {
        reject(new Error('Initialize timeout'));
      }, TIMEOUT_MS) });
    });
  }

  async callTool(name, args) {
    return new Promise((resolve, reject) => {
      const id = this.nextId++;
      const timeout = setTimeout(() => {
        this.pendingRequests.delete(id);
        reject(new Error(`Timeout (${TIMEOUT_MS}ms)`));
      }, TIMEOUT_MS);

      this.pendingRequests.set(id, { resolve, reject, timeout });

      this._send({
        jsonrpc: '2.0',
        id,
        method: 'tools/call',
        params: { name, arguments: args }
      });
    });
  }

  async listTools() {
    return new Promise((resolve, reject) => {
      const id = this.nextId++;
      const timeout = setTimeout(() => {
        this.pendingRequests.delete(id);
        reject(new Error(`Timeout (${TIMEOUT_MS}ms)`));
      }, TIMEOUT_MS);

      this.pendingRequests.set(id, { resolve, reject, timeout });

      this._send({
        jsonrpc: '2.0',
        id,
        method: 'tools/list',
        params: {}
      });
    });
  }

  stop() {
    if (this.server) {
      this.server.stdin.end();
      this.server.kill();
    }
  }

  _send(message) {
    const json = JSON.stringify(message);
    if (VERBOSE) console.error(`[SEND] ${json.substring(0, 200)}`);
    this.server.stdin.write(json + '\n');
  }

  _processBuffer() {
    const lines = this.buffer.split('\n');
    this.buffer = lines.pop() || '';

    for (const line of lines) {
      if (!line.trim()) continue;
      try {
        const msg = JSON.parse(line);
        if (msg.id !== undefined && this.pendingRequests.has(msg.id)) {
          const { resolve, reject, timeout } = this.pendingRequests.get(msg.id);
          clearTimeout(timeout);
          this.pendingRequests.delete(msg.id);

          if (msg.error) {
            reject(new Error(`MCP Error ${msg.error.code}: ${msg.error.message}`));
          } else {
            resolve(msg.result);
          }
        }
      } catch (e) {
        // Skip non-JSON lines (server logs)
        if (VERBOSE) console.error(`[PARSE] Skipping: ${line.substring(0, 100)}`);
      }
    }
  }
}

// --- Main ---
async function main() {
  const report = {
    machine: process.env.COMPUTERNAME || process.env.HOSTNAME || 'unknown',
    timestamp: new Date().toISOString(),
    wrapperPath: WRAPPER_PATH,
    toolsListed: 0,
    toolsTested: 0,
    passed: 0,
    failed: 0,
    expectedErrors: 0,
    unexpectedErrors: 0,
    results: []
  };

  const log = (msg) => { if (!JSON_ONLY) console.log(msg); };

  log(`\n=== E2E MCP Tools Validation ===`);
  log(`Machine: ${report.machine}`);
  log(`Wrapper: ${WRAPPER_PATH}\n`);

  const client = new McpClient(WRAPPER_PATH);

  try {
    // Step 1: Initialize
    log('1. Initializing MCP server...');
    await client.start();
    log('   OK - Server initialized\n');

    // Step 2: List tools
    log('2. Listing tools...');
    const toolsList = await client.listTools();
    const toolNames = toolsList.tools.map(t => t.name);
    report.toolsListed = toolNames.length;
    log(`   OK - ${toolNames.length} tools listed`);

    // Check for expected tools
    const expectedTools = TOOL_TESTS.map(t => t.name);
    const missing = expectedTools.filter(t => !toolNames.includes(t));
    if (missing.length > 0) {
      log(`   WARNING: ${missing.length} expected tools not in tools/list: ${missing.join(', ')}`);
    }
    const extra = toolNames.filter(t => !expectedTools.includes(t));
    if (extra.length > 0) {
      log(`   INFO: ${extra.length} extra tools not being tested: ${extra.join(', ')}`);
    }
    log('');

    // Step 3: Test each tool
    log('3. Testing tools...\n');
    for (const test of TOOL_TESTS) {
      const result = {
        tool: test.name,
        description: test.description,
        inToolsList: toolNames.includes(test.name),
        status: 'unknown',
        duration_ms: 0,
        error: null,
        responsePreview: null
      };

      report.toolsTested++;
      const start = Date.now();

      try {
        if (!result.inToolsList) {
          result.status = 'missing';
          result.error = 'Tool not in tools/list';
          report.failed++;
          log(`   MISS  ${test.name} - Not in tools/list`);
        } else {
          const response = await client.callTool(test.name, test.params);
          result.duration_ms = Date.now() - start;

          // Check response
          if (response && response.content) {
            const textContent = response.content
              .filter(c => c.type === 'text')
              .map(c => c.text)
              .join('');

            result.responsePreview = textContent.substring(0, 200);

            // Check for error indicators in response
            if (response.isError) {
              if (test.expectedError) {
                result.status = 'expected_error';
                result.error = textContent.substring(0, 300);
                report.expectedErrors++;
                log(`   OK*   ${test.name} (${result.duration_ms}ms) - Expected error: ${textContent.substring(0, 60)}`);
              } else {
                result.status = 'error_response';
                result.error = textContent.substring(0, 300);
                report.unexpectedErrors++;
                log(`   ERR   ${test.name} (${result.duration_ms}ms) - ${textContent.substring(0, 80)}`);
              }
            } else {
              result.status = 'pass';
              report.passed++;
              log(`   PASS  ${test.name} (${result.duration_ms}ms)`);
            }
          } else {
            result.status = 'pass';
            result.responsePreview = JSON.stringify(response).substring(0, 200);
            report.passed++;
            log(`   PASS  ${test.name} (${result.duration_ms}ms)`);
          }
        }
      } catch (err) {
        result.duration_ms = Date.now() - start;
        if (test.expectedError) {
          result.status = 'expected_error';
          result.error = err.message;
          report.expectedErrors++;
          log(`   OK*   ${test.name} (${result.duration_ms}ms) - Expected: ${err.message.substring(0, 60)}`);
        } else {
          result.status = 'exception';
          result.error = err.message;
          report.unexpectedErrors++;
          log(`   FAIL  ${test.name} (${result.duration_ms}ms) - ${err.message}`);
        }
      }

      report.results.push(result);
    }

  } catch (err) {
    log(`\nFATAL: ${err.message}`);
    report.fatalError = err.message;
  } finally {
    client.stop();
  }

  // Summary
  const effectivePass = report.passed + report.expectedErrors;
  const effectiveTotal = report.toolsTested;
  log(`\n=== Summary ===`);
  log(`Tools listed: ${report.toolsListed}/18 expected`);
  log(`Tools tested: ${report.toolsTested}`);
  log(`  PASS: ${report.passed}`);
  log(`  OK* (expected errors): ${report.expectedErrors}`);
  log(`  FAIL/MISS: ${report.failed}`);
  log(`  UNEXPECTED ERROR: ${report.unexpectedErrors}`);
  log(`  Effective rate: ${effectiveTotal > 0 ? Math.round(effectivePass / effectiveTotal * 100) : 0}% (${effectivePass}/${effectiveTotal})`);
  log(`  (* OK* = tool responded correctly, error is expected with test data)\n`);

  // JSON output
  if (JSON_ONLY) {
    console.log(JSON.stringify(report, null, 2));
  } else if (VERBOSE) {
    log('Full report:');
    log(JSON.stringify(report, null, 2));
  }

  // Exit code: fail only on missing tools, unexpected errors, or fatal errors
  process.exit(report.failed > 0 || report.unexpectedErrors > 0 || report.fatalError ? 1 : 0);
}

main().catch(err => {
  console.error('Fatal error:', err);
  process.exit(2);
});
