#!/usr/bin/env node
// Phase 2: Triple verification of orphan exports from Phase 1 AST audit
// Usage: node verify-orphans-phase2.cjs [--limit N] [--kind function|const|class|interface|type]
//
// Triple check:
//   1. git grep "exportName" → verify zero usage outside source file
//   2. git log -S "exportName" --since="60 days ago" → check recent history
//   3. Check test files (*.test.ts, *.spec.ts) for usage
//   4. Check dynamic dispatch patterns (registries, DI, MCP tool registration)

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
let limit = 100;
let kindFilter = null;
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--limit' && args[i + 1]) limit = parseInt(args[i + 1]);
  if (args[i] === '--kind' && args[i + 1]) kindFilter = args[i + 1];
}

const SUBMODULE_PATH = 'mcps/internal/servers/roo-state-manager';
const callGraphPath = path.join(__dirname, '..', '..', 'outputs', 'audits', 'hidden-debt', 'phase1-call-graph.json');

if (!fs.existsSync(callGraphPath)) {
  console.error('Phase 1 call graph not found:', callGraphPath);
  process.exit(1);
}

const callGraph = JSON.parse(fs.readFileSync(callGraphPath, 'utf-8'));
const orphans = callGraph.exports.filter(e => e.isOrphan && !e.isDynamic);

// Priority: function > const > class > interface > type
const kindPriority = { function: 0, const: 1, class: 2, interface: 3, type: 4, 'default-export': 5 };

let candidates = orphans
  .filter(e => !kindFilter || e.kind === kindFilter)
  .sort((a, b) => (kindPriority[a.kind] ?? 99) - (kindPriority[b.kind] ?? 99));

// Limit to top candidates
candidates = candidates.slice(0, limit);

console.log(`\n=== Phase 2 Orphan Verification ===`);
console.log(`Total orphans: ${orphans.length}`);
console.log(`Candidates to verify: ${candidates.length} (limit=${limit}, kindFilter=${kindFilter || 'all'})`);
console.log(`Kinds: ${JSON.stringify(countByKind(candidates))}\n`);

const results = {
  metadata: {
    scanDate: new Date().toISOString(),
    phase1Date: callGraph.metadata.scanDate,
    totalOrphans: orphans.length,
    candidatesVerified: candidates.length,
    kindFilter: kindFilter || 'all',
    limit: limit,
  },
  safeToDelete: [],
  usedInTests: [],
  usedInCode: [],       // Found via grep but missed by AST (dynamic/indirect)
  recentlyChanged: [],  // git log -S found recent activity
  needsManualReview: [],
  summary: { safe: 0, testOnly: 0, inCode: 0, recent: 0, manual: 0 }
};

// Dynamic dispatch patterns to check
const DYNAMIC_PATTERNS = [
  /register/i, /subscribe/i, /dispatch/i, /handler/i,
  /tool/i, /command/i, /plugin/i, /middleware/i,
  /strategy/i, /factory/i, /builder/i, /adapter/i,
];

for (const candidate of candidates) {
  const { name, kind, file, line } = candidate;
  const relPath = file.replace(/^mcps\/internal\/servers\/roo-state-manager\//, '');

  try {
    // Check 1: git grep in submodule (exclude source file itself)
    const grepCmd = `cd ${SUBMODULE_PATH} && git grep -l "${name}" -- src/ || true`;
    const grepOutput = execSync(grepCmd, { encoding: 'utf-8', timeout: 10000, stdio: ['pipe', 'pipe', 'pipe'] }).trim();
    const grepFiles = grepOutput ? grepOutput.split('\n').filter(f => f.trim()) : [];

    // Separate source file, test files, and other files
    const sourceRelPath = relPath;
    const otherFiles = grepFiles.filter(f => f !== sourceRelPath && !f.includes('.test.') && !f.includes('.spec.'));
    const testFiles = grepFiles.filter(f => f.includes('.test.') || f.includes('.spec.'));

    // Check 2: git log -S for recent changes (60 days)
    const logCmd = `cd ${SUBMODULE_PATH} && git log -S "${name}" --since="60 days ago" --oneline || true`;
    const logOutput = execSync(logCmd, { encoding: 'utf-8', timeout: 10000, stdio: ['pipe', 'pipe', 'pipe'] }).trim();
    const recentCommits = logOutput ? logOutput.split('\n').filter(l => l.trim()) : [];

    // Check 3: Dynamic dispatch pattern check
    const matchesDynamicPattern = DYNAMIC_PATTERNS.some(p => p.test(name));

    // Classification
    const entry = {
      name,
      kind,
      file: relPath,
      line,
      grepMatchesInCode: otherFiles.length,
      grepMatchesInTests: testFiles.length,
      grepFiles: grepFiles.filter(f => f !== sourceRelPath),
      recentCommits: recentCommits.length,
      recentCommitShas: recentCommits.slice(0, 3),
      matchesDynamicPattern,
    };

    if (otherFiles.length > 0) {
      // Found usage in non-test code → NOT orphan (AST missed it)
      results.usedInCode.push(entry);
      results.summary.inCode++;
    } else if (recentCommits.length > 0) {
      // Recently changed → might be in-progress work
      results.recentlyChanged.push(entry);
      results.summary.recent++;
    } else if (testFiles.length > 0) {
      // Only used in tests → test-only export
      results.usedInTests.push(entry);
      results.summary.testOnly++;
    } else if (matchesDynamicPattern) {
      // Name suggests dynamic dispatch → needs manual review
      results.needsManualReview.push(entry);
      results.summary.manual++;
    } else {
      // Truly orphan → safe to delete
      results.safeToDelete.push(entry);
      results.summary.safe++;
    }

    // Progress
    const done = results.summary.safe + results.summary.testOnly + results.summary.inCode + results.summary.recent + results.summary.manual;
    if (done % 10 === 0 || done === candidates.length) {
      process.stdout.write(`\r[${done}/${candidates.length}] safe=${results.summary.safe} testOnly=${results.summary.testOnly} inCode=${results.summary.inCode} recent=${results.summary.recent} manual=${results.summary.manual}`);
    }

  } catch (err) {
    results.needsManualReview.push({
      name, kind, file: relPath, line,
      error: err.message?.substring(0, 200),
      grepMatchesInCode: -1,
      grepMatchesInTests: -1,
      recentCommits: -1,
      matchesDynamicPattern: false,
    });
    results.summary.manual++;
  }
}

console.log('\n\n=== Results Summary ===');
console.log(JSON.stringify(results.summary, null, 2));
console.log(`\nSafe to delete: ${results.safeToDelete.length}`);
console.log(`Test-only: ${results.usedInTests.length}`);
console.log(`In code (AST missed): ${results.usedInCode.length}`);
console.log(`Recently changed: ${results.recentlyChanged.length}`);
console.log(`Needs manual review: ${results.needsManualReview.length}`);

// Output
const outputPath = path.join(__dirname, '..', '..', 'outputs', 'audits', 'hidden-debt', 'phase2-verified.json');
fs.mkdirSync(path.dirname(outputPath), { recursive: true });
fs.writeFileSync(outputPath, JSON.stringify(results, null, 2));
console.log(`\nOutput: ${outputPath}`);

function countByKind(arr) {
  return arr.reduce((acc, e) => { acc[e.kind] = (acc[e.kind] || 0) + 1; return acc; }, {});
}
