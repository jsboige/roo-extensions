#!/usr/bin/env node
/**
 * Smoke stdio du serveur MCP sk-agent (#3411).
 *
 * Le lancement n'est PAS code en dur : il est lu dans la config du client
 * (Claude Code global ou Zoo/Roo), pour eprouver exactement ce que le client
 * demarre. Sondes : initialize -> tools/list -> diagnostics -> list_agents
 * -> (optionnel) call_agent -> (optionnel) run_conversation.
 *
 * Usage :
 *   node probe-sk-agent-stdio.mjs                          # Claude Code global
 *   node probe-sk-agent-stdio.mjs --source=zoo             # Zoo/Roo mcp_settings
 *   node probe-sk-agent-stdio.mjs --call-agent --run-conversation
 *   node probe-sk-agent-stdio.mjs --neutral-cwd            # independance au cwd
 *
 * Sortie : rapport JSON sur stdout. Exit 1 si une sonde obligatoire echoue.
 */
import { spawn } from 'node:child_process';
import { readFileSync, existsSync } from 'node:fs';
import { homedir, tmpdir } from 'node:os';
import { join } from 'node:path';

const argv = process.argv.slice(2);
const flag = (n) => argv.includes(`--${n}`);
const opt = (n, d = '') => {
  const hit = argv.find((a) => a.startsWith(`--${n}=`));
  return hit ? hit.slice(n.length + 3) : d;
};

const SOURCE = opt('source', 'claude');
const TIMEOUT_MS = Number(opt('timeout', '180000'));
const NEUTRAL_CWD = flag('neutral-cwd');
const WITH_AGENT = flag('call-agent');
const WITH_CONVERSATION = flag('run-conversation');
const AGENT = opt('agent', '');
const MODEL = opt('model', '');
const PROMPT = opt('prompt', 'Reply with exactly the word: pong');
const CONVERSATION = opt('conversation', 'deep-search');

function resolveClaude() {
  const path = join(homedir(), '.claude.json');
  if (!existsSync(path)) throw new Error(`absent: ${path}`);
  const entry = JSON.parse(readFileSync(path, 'utf8'))?.mcpServers?.['sk-agent'];
  if (!entry) throw new Error(`pas d'entree mcpServers['sk-agent'] dans ${path}`);
  return { path, ...entry };
}

function resolveZoo() {
  const candidates = [
    join(process.env.APPDATA || '', 'Code', 'User', 'globalStorage', 'zoocodeorganization.zoo-code', 'settings', 'mcp_settings.json'),
    join(process.env.APPDATA || '', 'Code', 'User', 'globalStorage', 'rooveterinaryinc.roo-cline', 'settings', 'mcp_settings.json'),
  ];
  for (const path of candidates) {
    if (!existsSync(path)) continue;
    const entry = JSON.parse(readFileSync(path, 'utf8'))?.mcpServers?.['sk-agent'];
    if (entry) return { path, ...entry };
  }
  const tried = candidates.join(' | ');
  throw new Error(`pas d'entree sk-agent dans une config Zoo/Roo (essaye: ${tried})`);
}

function launchConfig() {
  if (SOURCE === 'claude') return resolveClaude();
  if (SOURCE === 'zoo') return resolveZoo();
  const command = opt('command');
  if (!command) throw new Error('--source=none exige --command=<exe>');
  const args = argv.filter((a) => a.startsWith('--arg=')).map((a) => a.slice(6));
  return { path: 'cli', command, args, cwd: opt('cwd') };
}

function run(cfg) {
  const cwd = NEUTRAL_CWD ? tmpdir() : cfg.cwd;
  const report = {
    source: SOURCE,
    config_path: cfg.path,
    command: cfg.command,
    args: cfg.args || [],
    declared_cwd: cfg.cwd || null,
    used_cwd: cwd || process.cwd(),
    cwd_neutral: NEUTRAL_CWD,
    server_info: null,
    protocol: null,
    tools: [],
    cold_start_ms: null,
    probes: {},
  };
  const t0 = Date.now();
  const child = spawn(cfg.command, cfg.args || [], {
    cwd,
    stdio: ['pipe', 'pipe', 'pipe'],
    env: { ...process.env },
    windowsHide: true,
  });

  let stderr = '';
  child.stderr.on('data', (d) => { stderr += d.toString(); });

  let buf = '';
  const waiters = new Map();
  child.stdout.on('data', (chunk) => {
    buf += chunk.toString();
    let idx;
    while ((idx = buf.indexOf('\n')) >= 0) {
      const line = buf.slice(0, idx).trim();
      buf = buf.slice(idx + 1);
      if (!line) continue;
      let msg;
      try { msg = JSON.parse(line); } catch { report.raw_output = (report.raw_output || '') + line + '\n'; continue; }
      if (msg.id != null && waiters.has(msg.id)) {
        const w = waiters.get(msg.id);
        waiters.delete(msg.id);
        clearTimeout(w.timer);
        w.resolve(msg);
      }
    }
  });

  let nextId = 1;
  const request = (method, params = {}, ms = TIMEOUT_MS) =>
    new Promise((resolve, reject) => {
      const id = nextId++;
      const timer = setTimeout(() => {
        waiters.delete(id);
        reject(new Error(`${method}: timeout apres ${ms} ms`));
      }, ms);
      waiters.set(id, { resolve, timer });
      child.stdin.write(JSON.stringify({ jsonrpc: '2.0', id, method, params }) + '\n');
    });

  const notify = (method, params = {}) =>
    child.stdin.write(JSON.stringify({ jsonrpc: '2.0', method, params }) + '\n');

  const probe = async (name, fn, required = true) => {
    const started = Date.now();
    try {
      const value = await fn();
      report.probes[name] = {
        ok: true,
        ms: Date.now() - started,
        summary: summarize(value),
      };
      return value;
    } catch (err) {
      report.probes[name] = { ok: false, ms: Date.now() - started, error: String(err.message || err), required };
      if (required) report.failed = true;
      return null;
    }
  };

  const summarize = (value) => {
    if (value == null) return null;
    if (Array.isArray(value)) return { count: value.length };
    if (typeof value === 'object') {
      const keys = Object.keys(value);
      const out = { keys: keys.slice(0, 12) };
      for (const k of ['error', 'agents', 'tools', 'serverInfo', 'agent_used', 'model_used', 'conversation_id']) {
        if (value[k] != null) out[k] = Array.isArray(value[k]) ? { count: value[k].length } : value[k];
      }
      if (typeof value.response === 'string') out.response = value.response.slice(0, 500);
      return out;
    }
    return { chars: String(value).length };
  };

  const textOf = (res) => {
    if (!res) return null;
    if (res.error) throw new Error(JSON.stringify(res.error));
    const parts = res.result?.content || [];
    const text = parts.map((p) => p.text ?? '').join('\n');
    try { return JSON.parse(text); } catch { return text; }
  };

  const call = async (name, args = {}, ms = TIMEOUT_MS) =>
    textOf(await request('tools/call', { name, arguments: args }, ms));

  return (async () => {
    try {
      const init = await probe('initialize', () => request('initialize', {
        protocolVersion: '2024-11-05',
        capabilities: {},
        clientInfo: { name: 'probe-sk-agent-stdio', version: '1.0.0' },
      }));
      report.cold_start_ms = Date.now() - t0;
      if (!init) throw new Error('initialize echoue');
      if (init.error) throw new Error(`initialize: ${JSON.stringify(init.error)}`);
      report.server_info = init.result?.serverInfo || null;
      report.protocol = init.result?.protocolVersion || null;
      notify('notifications/initialized');

      const list = await probe('tools/list', () => request('tools/list'));
      report.tools = (list?.result?.tools || []).map((t) => t.name);

      await probe('diagnostics', async () => { const d = await call('diagnostics'); return typeof d === 'string' ? d.length : d; });
      await probe('list_agents', () => call('list_agents'));

      if (WITH_AGENT) {
        await probe('call_agent', () => call('call_agent', { prompt: PROMPT, agent: AGENT, model_override: MODEL, timeout: 180 }, TIMEOUT_MS + 60000));
      }
      if (WITH_CONVERSATION) {
        await probe('run_conversation', () => call('run_conversation', { prompt: PROMPT, conversation: CONVERSATION }, TIMEOUT_MS + 60000));
      }
    } catch (err) {
      report.fatal = String(err.message || err);
      report.failed = true;
    } finally {
      child.stdin.end();
      await new Promise((r) => {
        const kill = setTimeout(() => { try { child.kill(); } catch {} r(); }, 5000);
        child.on('exit', () => { clearTimeout(kill); r(); });
      });
      report.stderr_tail = stderr.slice(-4000);
      report.total_ms = Date.now() - t0;
      console.log(JSON.stringify(report, null, 2));
      process.exit(report.failed ? 1 : 0);
    }
  })();
}

try {
  run(launchConfig());
} catch (err) {
  console.log(JSON.stringify({ source: SOURCE, fatal: String(err.message || err), failed: true }, null, 2));
  process.exit(1);
}
