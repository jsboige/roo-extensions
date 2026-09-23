#!/usr/bin/env node
/**
 * #3230 / RX14 — READ-ONLY per-key divergence probe: dashboard files vs PG
 * active journal. The verification instrument for the READ_PG switchover
 * (T-2j convergence check, T-1j withdrawal check, post-arm audit).
 *
 * Mirrors the daemon guards (roosync-dashboard-reconcile.ts) without writing:
 *   disk→PG gap  = persisted ids in the file, absent from the PG active
 *                  journal (the daemon insert-pass target — heals at 6 h)
 *   PG→disk      = PG active rows whose message_id is absent from the file
 *                  (the daemon archival-pass target), classified fork /
 *                  stale / too-young / archivable exactly like the daemon,
 *                  PLUS the zombie class the daemon cannot heal by design:
 *                  keys whose file is unfingerprintable (persisted=0), where
 *                  the archival pass never runs.
 *   PG-only keys = active journal keys with NO keyed file on disk (case
 *                  variants, born-and-withdrawn forks) — ghost keys in a
 *                  PG-read world.
 *
 * Usage (from anywhere, resolves the server dir from this file's location):
 *   node scripts/pg/measure-dashboard-divergence.mjs [--json out.json] [--expect-files N]
 *
 * --expect-files N : floor on the keyed-file count. A DriveFS mirror that is
 *   cold or partially hydrated understates the listing and falsifies every
 *   per-key metric (ghost keys, disk→PG). Below the floor the probe prints a
 *   warm-mirror banner and exits 1 so gates can fail closed.
 *
 * Requires the RSM server .env (UNIFIED_STORE_PG_URL, ROOSYNC_SHARED_PATH).
 * Strictly read-only: SELECT only, no daemon call, no file mutation.
 */
import { readdir, readFile } from 'node:fs/promises';
import { writeFileSync } from 'node:fs';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { createRequire } from 'node:module';

const HERE = dirname(fileURLToPath(import.meta.url));
// Default resolves inside THIS checkout (populated submodule). Override with
// RSM_SERVER_DIR when running from a worktree whose submodule is not populated.
const SERVER_DIR = process.env.RSM_SERVER_DIR
  ?? resolve(HERE, '../../mcps/internal/servers/roo-state-manager');
const require2 = createRequire(join(SERVER_DIR, 'package.json'));
const pg = require2('pg');

const jsonOutIdx = process.argv.indexOf('--json');
const jsonOut = jsonOutIdx >= 0 ? process.argv[jsonOutIdx + 1] : null;
const expectFilesIdx = process.argv.indexOf('--expect-files');
const expectFiles = expectFilesIdx >= 0 ? parseInt(process.argv[expectFilesIdx + 1], 10) : null;

// ── server .env (values stay in-process) ──
const envText = await readFile(join(SERVER_DIR, '.env'), 'utf-8');
for (const line of envText.split(/\r?\n/)) {
  const m = line.match(/^([A-Z_][A-Z0-9_]*)=(.*)$/);
  if (m && !process.env[m[1]]) process.env[m[1]] = m[2].replace(/^["']|["']$/g, '');
}
const dashboardsDir = join(process.env.ROOSYNC_SHARED_PATH, 'dashboards');

// ── build imports (ESM) — same parsers as the daemon ──
const buildUrl = (p) => pathToFileURL(join(SERVER_DIR, 'build', p)).href;
const { extractPersistedMessageIds, parseDashboardMarkdown } = await import(
  buildUrl('tools/roosync/dashboard-markdown.js')
);
// Fork pattern: use the daemon's own constant when the build exports it
// (#1179+). A vintage that predates the export (stale build/ wrapper) falls
// back to the literal and says so — the warning doubles as a staleness signal.
let FORK_FILE_RE = /\s\(\d+\)\.md$/; // must stay identical to the daemon's constant
try {
  const mod = await import(buildUrl('services/unified-store/roosync-dashboard-reconcile.js'));
  if (mod.FORK_FILE_RE instanceof RegExp) FORK_FILE_RE = mod.FORK_FILE_RE;
  else throw new Error('export absent');
} catch {
  console.error('WARN: FORK_FILE_RE absent du build RSM (vintage pre-#1179 ?) — constante locale utilisée');
}
const isKeyed = (n) =>
  n.endsWith('.md') && (n === 'global.md' || n.startsWith('machine-') || n.startsWith('workspace-'));
const maxMs = (vals) => {
  let mx = null;
  for (const v of vals) {
    if (!v) continue;
    const t = Date.parse(v);
    if (Number.isFinite(t) && (mx === null || t > mx)) mx = t;
  }
  return mx;
};

const client = new pg.Client({
  connectionString: process.env.UNIFIED_STORE_PG_URL,
  statement_timeout: 15000,
});
await client.connect();

const uni = await client.query(
  'SELECT dashboard_key AS k, COUNT(*) AS n, MAX(created_at) AS mx FROM roosync_dashboard_messages WHERE archived_at IS NULL GROUP BY dashboard_key'
);
const pgUniverse = new Map(uni.rows.map((r) => [r.k, { count: +r.n, maxCreated: r.mx }]));

const files = (await readdir(dashboardsDir)).filter(isKeyed);
const now = Date.now();
const rows = [];
const totals = {
  files: files.length, keys: 0, persistedIds: 0, idless: 0,
  diskToPgKeys: 0, diskToPgMsgs: 0,
  pgToDiskArchivable: 0, pgToDiskTooYoung: 0,
  pgToDiskUnfingerprintable: 0, // zombie class: file has persisted=0, daemon skips by design
  staleKeys: 0, forkFiles: 0,
  pgOnlyKeys: 0, pgOnlyRows: 0, errors: 0,
};

for (const file of files) {
  const key = file.replace(/\.md$/, '');
  try {
    let content = await readFile(join(dashboardsDir, file), 'utf-8');
    content = content.replace(/\r\n/g, '\n');
    if (content.charCodeAt(0) === 0xfeff) content = content.slice(1);
    const persisted = extractPersistedMessageIds(content);
    const dashboard = parseDashboardMarkdown(content, key);
    totals.keys++;
    totals.persistedIds += persisted.size;
    totals.idless += Math.max(0, dashboard.intercom.messages.length - persisted.size);

    const pgRows = await client.query(
      'SELECT message_id, created_at FROM roosync_dashboard_messages WHERE dashboard_key=$1 AND archived_at IS NULL',
      [key]
    );
    const pgIds = new Set(pgRows.rows.map((r) => r.message_id).filter(Boolean));
    const gap = [...persisted].filter((id) => !pgIds.has(id));
    const pgOnly = pgRows.rows.filter((r) => r.message_id && !persisted.has(r.message_id));

    const fileMax = maxMs(dashboard.intercom.messages.map((m) => m.timestamp));
    const pgMax = maxMs(pgRows.rows.map((r) => r.created_at));
    const isFork = FORK_FILE_RE.test(file);
    const isStale = fileMax === null || pgMax === null || pgMax > fileMax;
    let archivable = 0, tooYoung = 0, unfingerprintable = 0;
    if (pgOnly.length > 0 && persisted.size === 0) {
      unfingerprintable = pgOnly.length; // daemon can never converge this key
    } else if (!isFork && !isStale) {
      for (const r of pgOnly) {
        const t = Date.parse(r.created_at);
        if (Number.isFinite(t) && t < now - 24 * 3600_000) archivable++;
        else tooYoung++;
      }
    }
    if (gap.length > 0) { totals.diskToPgKeys++; totals.diskToPgMsgs += gap.length; }
    totals.pgToDiskArchivable += archivable;
    totals.pgToDiskTooYoung += tooYoung;
    totals.pgToDiskUnfingerprintable += unfingerprintable;
    if (isStale && pgOnly.length > 0) totals.staleKeys++;
    if (isFork) totals.forkFiles++;

    rows.push({
      key, fileMsgs: dashboard.intercom.messages.length, persisted: persisted.size,
      pgActive: pgRows.rows.length,
      diskToPgGap: gap.length, pgToDisk: pgOnly.length,
      archivable, tooYoung, unfingerprintable,
      stale: isStale && pgOnly.length > 0, fork: isFork,
    });
  } catch (e) {
    totals.errors++;
    rows.push({ key, error: String(e).slice(0, 200) });
  }
}

const pgOnlyKeys = [];
for (const [k, v] of pgUniverse) {
  if (!files.includes(k + '.md')) {
    pgOnlyKeys.push({ key: k, activeRows: v.count, maxCreated: v.maxCreated, forkNamed: /\s\(\d+\)$/.test(k) });
    totals.pgOnlyKeys++;
    totals.pgOnlyRows += v.count;
  }
}
await client.end();

// Warm/cold-mirror floor: an understated listing falsifies everything below.
if (Number.isFinite(expectFiles) && totals.files < expectFiles) {
  console.error(`\n⚠️ MIROIR CHAUD/INCOMPLET : ${totals.files} fichiers keyed < plancher --expect-files ${expectFiles}.`);
  console.error('   Le miroir DriveFS local est probablement froid ou partiel — les clés PG-only et les');
  console.error('   écarts disque→PG ci-dessous NE SONT PAS FIABLES. Ré-hydrater puis re-mesurer.');
  process.exitCode = 1;
}

rows.sort((a, b) => (b.diskToPgGap + b.pgToDisk) - (a.diskToPgGap + a.pgToDisk));
const out = { measuredAt: new Date().toISOString(), dashboardsDir, totals, pgOnlyKeys, rows };
if (jsonOut) writeFileSync(jsonOut, JSON.stringify(out, null, 2));

console.log(`mesuré ${out.measuredAt} — dir: ${dashboardsDir}`);
console.log(`fichiers keyed: ${totals.files} | clés parsées: ${totals.keys} | persisted ids: ${totals.persistedIds} (id-less: ${totals.idless}) | erreurs: ${totals.errors}`);
console.log(`\nDISQUE→PG (cible passe insert)        : ${totals.diskToPgKeys} clé(s), ${totals.diskToPgMsgs} message(s)`);
console.log(`PG→DISQUE archivables ≥24h (daemon)   : ${totals.pgToDiskArchivable}`);
console.log(`PG→DISQUE <24h (vont guérir en vieillissant) : ${totals.pgToDiskTooYoung}`);
console.log(`PG→DISQUE zombies unfingerprintables  : ${totals.pgToDiskUnfingerprintable} (le daemon ne peut JAMAIS les converger — archival ciblé requis)`);
console.log(`clés stale (fichier en retard, indemne) = ${totals.staleKeys} | fichiers fork = ${totals.forkFiles}`);
console.log(`\nCLÉS PG SANS FICHIER : ${totals.pgOnlyKeys} clé(s), ${totals.pgOnlyRows} rows actives`);
for (const k of pgOnlyKeys) console.log(`  - ${k.key} : ${k.activeRows} rows, dernière ${k.maxCreated} (fork=${k.forkNamed})`);
console.log(`\nTOP divergence :`);
let shown = 0;
for (const r of rows) {
  if (r.error) { console.log(`  ${r.key} ERREUR: ${r.error}`); continue; }
  if (r.diskToPgGap + r.pgToDisk === 0) continue;
  if (shown++ >= 15) { console.log('  …'); break; }
  console.log(`  ${r.key} : diskMsgs=${r.fileMsgs} persisted=${r.persisted} pgActive=${r.pgActive} | disque→PG=${r.diskToPgGap} | PG→disque=${r.pgToDisk} (archivable=${r.archivable}, jeune=${r.tooYoung}, zombie=${r.unfingerprintable})${r.stale ? ' [STALE]' : ''}${r.fork ? ' [FORK]' : ''}`);
}
if (jsonOut) console.log(`\nJSON complet: ${jsonOut}`);
