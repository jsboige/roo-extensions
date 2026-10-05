#!/usr/bin/env node
/**
 * #2191 AC1/AC2 — latency probe for the conversation unified store (PG), seen
 * from the seat that runs it. Measures the code actually served:
 *
 *   read   : header lookup, `view` body (paginated getMessages, as
 *            loadPgConversationSkeleton does), `list` PG tier (fleet-wide and
 *            this machine), search step 2 (joinFromQdrant on 20 task ids)
 *   write  : the writer's exact SQL (upsertConversationRow + upsertMessagesRows)
 *            inside BEGIN ... ROLLBACK — a fresh conversation (every row new)
 *            and a steady-state refresh (stored conversation re-sent whole,
 *            what the 2-min refresh worker does). Nothing is committed; the
 *            only side effect is the `messages.id` sequence advancing.
 *   fresh  : delay between a conversation's first message and its first
 *            appearance in the store, last 7 days, per machine x harness
 *            (SELECT only).
 *
 * ROLLBACK skips the commit flush: write figures are a lower bound by that
 * flush. Run it on a seat that reaches the store through pg.myia.io to get the
 * network-inclusive figure; on ai-01 the store is on loopback.
 *
 * Usage:
 *   node scripts/pg/measure-conversation-store-latency.mjs [--json out.json]
 * RSM_SERVER_DIR overrides the server dir (needed from a worktree: the .env
 * and the served build live in the main checkout).
 *
 * Prints timings and counts only — never the connection string nor content.
 */
import { readFile } from 'node:fs/promises';
import { writeFileSync } from 'node:fs';
import { join, dirname, resolve, basename } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { performance } from 'node:perf_hooks';

const HERE = dirname(fileURLToPath(import.meta.url));
const SERVER_DIR = process.env.RSM_SERVER_DIR
  ?? resolve(HERE, '../../mcps/internal/servers/roo-state-manager');
const jsonOutIdx = process.argv.indexOf('--json');
const jsonOut = jsonOutIdx >= 0 ? process.argv[jsonOutIdx + 1] : null;

// ── server .env (values stay in-process) ──
const envText = await readFile(join(SERVER_DIR, '.env'), 'utf-8');
for (const line of envText.split(/\r?\n/)) {
  const m = line.match(/^([A-Z_][A-Z0-9_]*)=(.*)$/);
  if (m && !process.env[m[1]]) process.env[m[1]] = m[2].replace(/^["']|["']$/g, '');
}
const url = process.env.UNIFIED_STORE_PG_URL;
if (!url) {
  console.error('UNIFIED_STORE_PG_URL absent du .env serveur — rien à mesurer, exit 2.');
  process.exit(2);
}
const host = new URL(url).hostname;
const hostClass = /^(localhost|127\.|::1)/.test(host) ? 'loopback'
  : /^(10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)/.test(host) ? 'private-lan' : 'dns-name';

// ── served build (#3713 marker), like measure-dashboard-divergence.mjs ──
let buildDir = join(SERVER_DIR, 'build');
try {
  const { resolveBuildDir } = await import(
    pathToFileURL(join(SERVER_DIR, 'scripts/lib/resolve-build-dir.mjs')).href
  );
  buildDir = resolveBuildDir(SERVER_DIR);
} catch { /* pre-#3713 checkout: build/ IS the served code there */ }
const buildUrl = (p) => pathToFileURL(join(buildDir, p)).href;
const { PgUnifiedStoreReader } = await import(buildUrl('services/unified-store/PgUnifiedStoreReader.js'));
const { PgUnifiedStoreWriter } = await import(buildUrl('services/unified-store/PgUnifiedStoreWriter.js'));

const cfg = { connectionString: url, poolMax: 5, statementTimeoutMs: 30000, connectionTimeoutMillis: 5000 };
const reader = new PgUnifiedStoreReader(cfg);
const writer = new PgUnifiedStoreWriter(cfg);
for (const m of ['upsertConversationRow', 'upsertMessagesRows']) {
  if (typeof writer[m] !== 'function') {
    console.error(`PgUnifiedStoreWriter.${m} absent du build servi — sonde à réaligner sur le writer, exit 2.`);
    process.exit(2);
  }
}

const stats = (xs) => {
  const s = [...xs].sort((a, b) => a - b);
  const q = (p) => s[Math.min(s.length - 1, Math.floor(p * s.length))];
  const r = (v) => +v.toFixed(1);
  return { n: s.length, min: r(s[0]), med: r(q(0.5)), max: r(s[s.length - 1]) };
};
async function time(fn, reps) {
  const out = [];
  for (let i = 0; i < reps; i++) { const t = performance.now(); await fn(); out.push(performance.now() - t); }
  return stats(out);
}
const iso = (v) => (v instanceof Date ? v.toISOString() : v);
const machineId = (process.env.ROOSYNC_MACHINE_ID ?? process.env.COMPUTERNAME ?? 'unknown').toLowerCase();

const result = { seat: machineId, hostClass, served: basename(buildDir), startedAt: new Date().toISOString() };
let t0 = performance.now();
await reader.init();
result.poolInitMs = +(performance.now() - t0).toFixed(1);
await writer.init();
const pool = reader.pool;

result.corpus = (await pool.query(
  `SELECT harness, COUNT(*)::int AS convs, COUNT(DISTINCT machine_id)::int AS machines
     FROM conversations GROUP BY harness ORDER BY harness`)).rows;

async function pick(lo, hi) {
  const r = await pool.query(
    `SELECT task_id FROM conversations WHERE msg_count BETWEEN $1 AND $2
      ORDER BY last_ts DESC NULLS LAST LIMIT 1`, [lo, hi]);
  return r.rows[0]?.task_id ?? null;
}
const sizes = { small: await pick(40, 80), medium: await pick(800, 1200), large: await pick(4000, 6000) };

// ── read ──
const read = {};
read.list_fleet_limit5000 = await time(() => reader.listConversations({ limit: 5000 }), 5);
read.list_this_machine = await time(() => reader.listConversations({ machineId, limit: 5000 }), 5);
read.view = {};
for (const [label, id] of Object.entries(sizes)) {
  if (!id) { read.view[label] = 'no candidate'; continue; }
  let n = 0;
  const st = await time(async () => {
    await reader.getConversation(id);
    n = 0;
    for (let off = 0; ; off += 1000) {
      const page = await reader.getMessages(id, { limit: 1000, offset: off });
      n += page.length;
      if (page.length < 1000) break;
    }
  }, 5);
  read.view[label] = { messages: n, ...st };
}
const ids = (await pool.query('SELECT task_id FROM conversations ORDER BY random() LIMIT 20')).rows.map(r => r.task_id);
read.header_single = await time(() => reader.getConversation(ids[0]), 20);
const hits = ids.map((task_id, i) => ({ task_id, score: 1 - i / 100 }));
read.search_step2_join_top20 = await time(() => reader.joinFromQdrant(hits, {}), 10);
result.read = read;

// ── write: exact writer SQL, BEGIN ... ROLLBACK ──
const write = {};
const client = await pool.connect();
try {
  for (const [label, id] of Object.entries(sizes)) {
    if (!id) continue;
    const conv = (await client.query('SELECT * FROM conversations WHERE task_id = $1', [id])).rows[0];
    const msgs = (await client.query('SELECT * FROM messages WHERE task_id = $1 ORDER BY seq', [id])).rows;
    const row = {
      task_id: conv.task_id, machine_id: conv.machine_id, harness: conv.harness, workspace: conv.workspace,
      parent_task_id: conv.parent_task_id, title: conv.title, first_ts: iso(conv.first_ts),
      last_ts: iso(conv.last_ts), msg_count: conv.msg_count, metadata: conv.metadata,
    };
    const rowsFor = (taskId) => msgs.map(m => ({
      task_id: taskId, message_id: m.message_id, seq: m.seq, role: m.role,
      content: m.content, tool_calls: m.tool_calls, ts: iso(m.ts),
    }));
    const bytes = msgs.reduce((a, m) => a + Buffer.byteLength(m.content ?? '', 'utf8'), 0);
    const run = async (taskId, reps) => {
      const out = [];
      for (let i = 0; i < reps; i++) {
        const tid = typeof taskId === 'function' ? taskId(i) : taskId;
        await client.query('BEGIN');
        const t = performance.now();
        await writer.upsertConversationRow(client, { ...row, task_id: tid });
        await writer.upsertMessagesRows(client, rowsFor(tid));
        out.push(performance.now() - t);
        await client.query('ROLLBACK');
      }
      return stats(out);
    };
    write[label] = {
      messages: msgs.length,
      contentMB: +(bytes / 1048576).toFixed(2),
      fresh: await run((i) => `probe-2191-rollback-${label}-${i}-${Date.now()}`, 5),
      refresh: await run(id, 5),
    };
  }
} finally {
  await client.query('ROLLBACK').catch(() => {});
  client.release();
}
write.leftoverProbeRows = (await pool.query(
  `SELECT COUNT(*)::int AS n FROM conversations WHERE task_id LIKE 'probe-2191-rollback-%'`)).rows[0].n;
result.write = write;

// ── freshness: first message -> first appearance in the store, last 7 days ──
result.freshness_7d = (await pool.query(`
  SELECT machine_id, harness, COUNT(*)::int AS n,
    ROUND(percentile_cont(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM ingested_at - first_ts))::numeric) AS p50_s,
    ROUND(percentile_cont(0.9) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM ingested_at - first_ts))::numeric) AS p90_s
  FROM conversations
  WHERE first_ts > NOW() - INTERVAL '7 days' AND ingested_at >= first_ts
  GROUP BY machine_id, harness ORDER BY machine_id, harness`)).rows;

await reader.close();
await writer.close();
result.endedAt = new Date().toISOString();
const out = JSON.stringify(result, null, 2);
if (jsonOut) writeFileSync(jsonOut, out);
console.log(out);
if (write.leftoverProbeRows !== 0) {
  console.error(`ALERTE: ${write.leftoverProbeRows} ligne(s) probe-2191-rollback-* présentes — un ROLLBACK n'a pas tenu, exit 1.`);
  process.exit(1);
}
