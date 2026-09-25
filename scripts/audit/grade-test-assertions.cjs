#!/usr/bin/env node
/**
 * grade-test-assertions.cjs — Phase 2 test-suite qualitative audit (#833)
 *
 * Grades every test file by ASSERTION STRENGTH (A/B/C/D/F), per the #833
 * scale: weak = existence-only assertions (toBeDefined/toBeTruthy...), which
 * pass even when the behavior is wrong.
 *
 * Heuristic by design: 683 files cannot be read one by one. Every assertion
 * is classified by its MATCHER (regex on the terminal .matcher( call — one
 * per expect chain in Vitest/Jest), which is regular enough that an AST pass
 * buys nothing. Grades are declared heuristic and are meant to be RE-READ by
 * hand for the D/F files before any corrective PR.
 *
 * Usage:
 *   node scripts/audit/grade-test-assertions.cjs [--dir <path>] [--top N] [--json] [--out <file>]
 *
 * Output: console table (worst N by weak%) + outputs/audits/test-quality/phase2-grading.json
 * (or the --out path). Identity matchers (toBeNull/toBeUndefined) NON-negated grade MEDIUM
 * (strict === one value = exact contract); their .not. forms grade WEAK (presence ≈ toBeDefined)
 * — #833 arbitration 2026-09-24, measured on 59 hand-qualified files (~47% false positives).
 */

const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..', '..');
const DEFAULT_DIR = path.join(ROOT, 'mcps', 'internal', 'servers', 'roo-state-manager');
const OUTPUT_DIR = path.join(ROOT, 'outputs', 'audits', 'test-quality');

const EXCLUDE_DIRS = new Set(['node_modules', 'build', 'dist', '.git', 'coverage', 'out']);

// ─── Assertion taxonomy ───
// WEAK: passes when the value merely exists / is truthy — no content check.
// Also .not.toBeNull/.not.toBeUndefined: presence assertions ≈ toBeDefined.
const WEAK = [
  'toBeDefined', 'toBeTruthy', 'toBeFalsy',
  'toBeNaN',
];
// STRONG: compares actual content / exact value / call arguments.
const STRONG = [
  'toBe', 'toEqual', 'toStrictEqual', 'toContain', 'toContainEqual',
  'toHaveLength', 'toMatchObject', 'toMatch',
  'toHaveBeenCalledWith', 'toHaveBeenCalledTimes', 'toHaveBeenLastCalledWith',
  'toHaveBeenNthCalledWith', 'toThrowError', 'toBeGreaterThan', 'toBeLessThan',
  'toBeGreaterThanOrEqual', 'toBeLessThanOrEqual', 'toBeCloseTo',
];
// MEDIUM: more than existence, less than a content comparison.
// toBeNull/toBeUndefined NON-negated: strict === single value = exact contract (#833).
const MEDIUM = [
  'toBeInstanceOf', 'toHaveBeenCalled', 'toHaveProperty', 'toThrow',
  'toMatchSnapshot', 'toMatchInlineSnapshot', 'toThrowErrorMatchingSnapshot',
  'toBeNull', 'toBeUndefined',
];
// Negated identity matchers: presence assertions — the ancre adjacente carries the force.
const NEGATED_IDENTITY = new Set(['toBeNull', 'toBeUndefined']);

// Alt 1 captures `.not.matcher(`, alt 2 plain `.matcher(` — alt 1 first so the
// negated form consumes the whole chain and never double-counts via alt 2.
const MATCHER_RE = /\.\s*not\s*\.\s*([A-Za-z]+)\s*\(|\.([A-Za-z]+)\s*\(/g;

function classifyMatcher(name, negated) {
  if (negated && NEGATED_IDENTITY.has(name)) return 'weak';
  if (WEAK.includes(name)) return 'weak';
  if (STRONG.includes(name)) return 'strong';
  if (MEDIUM.includes(name)) return 'medium';
  return null;
}

function grade(weakPct, total) {
  if (total < 5) return 'N/A';          // too few assertions to grade meaningfully
  if (weakPct <= 5) return 'A';
  if (weakPct <= 15) return 'B';
  if (weakPct <= 30) return 'C';
  if (weakPct <= 50) return 'D';
  return 'F';
}

function analyzeFile(filePath) {
  const source = fs.readFileSync(filePath, 'utf8');
  const counts = { weak: 0, medium: 0, strong: 0, other: 0 };
  const weakSamples = [];

  let m;
  MATCHER_RE.lastIndex = 0;
  while ((m = MATCHER_RE.exec(source)) !== null) {
    const negated = m[1] !== undefined;
    const name = negated ? m[1] : m[2];
    const klass = classifyMatcher(name, negated);
    if (klass) {
      counts[klass]++;
      if (klass === 'weak' && weakSamples.length < 5) {
        const line = source.slice(0, m.index).split('\n').length;
        weakSamples.push(`L${line}: .${negated ? 'not.' : ''}${name}`);
      }
    } else {
      counts.other++;
    }
  }

  const total = counts.weak + counts.medium + counts.strong;
  const weakPct = total > 0 ? (counts.weak / total) * 100 : 0;
  const itCount = (source.match(/\bit\s*\(|\btest\s*\(/g) || []).length;

  return { counts, total, weakPct, itCount, weakSamples };
}

function discoverTestFiles(rootDir) {
  const files = [];
  (function walk(dir) {
    let entries;
    try { entries = fs.readdirSync(dir, { withFileTypes: true }); } catch { return; }
    for (const entry of entries) {
      if (EXCLUDE_DIRS.has(entry.name)) continue;
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) walk(full);
      else if (/\.(test|spec)\.(ts|tsx|js|mjs|cjs)$/.test(entry.name)) files.push(full);
    }
  })(rootDir);
  return files;
}

// ─── Main ───

const args = process.argv.slice(2);
function argValue(flag) { const i = args.indexOf(flag); return i >= 0 ? args[i + 1] : null; }

const scanDir = argValue('--dir') || DEFAULT_DIR;
const topN = parseInt(argValue('--top') || '30', 10);
const asJson = args.includes('--json');

const files = discoverTestFiles(scanDir);
const results = files.map((f) => {
  const a = analyzeFile(f);
  return {
    file: path.relative(ROOT, f).replace(/\\/g, '/'),
    assertions: a.total,
    weak: a.counts.weak,
    medium: a.counts.medium,
    strong: a.counts.strong,
    weakPct: Number(a.weakPct.toFixed(1)),
    itCount: a.itCount,
    grade: grade(a.weakPct, a.total),
    weakSamples: a.weakSamples,
  };
});

const graded = results.filter((r) => r.grade !== 'N/A');
const byGrade = { A: 0, B: 0, C: 0, D: 0, F: 0, 'N/A': 0 };
for (const r of results) byGrade[r.grade]++;

const summary = {
  generatedAt: new Date().toISOString(),
  scanDir: path.relative(ROOT, scanDir).replace(/\\/g, '/'),
  files: results.length,
  gradedFiles: graded.length,
  totalAssertions: results.reduce((s, r) => s + r.assertions, 0),
  weakTotal: results.reduce((s, r) => s + r.weak, 0),
  byGrade,
  thresholds: { A: '<=5% weak', B: '<=15%', C: '<=30%', D: '<=50%', F: '>50%', 'N/A': '<5 assertions' },
  results: results.sort((a, b) => b.weakPct - a.weakPct || b.assertions - a.assertions),
};

const outFile = argValue('--out') || path.join(OUTPUT_DIR, 'phase2-grading.json');
fs.mkdirSync(path.dirname(outFile), { recursive: true });
fs.writeFileSync(outFile, JSON.stringify(summary, null, 2), 'utf8');

if (asJson) {
  console.log(JSON.stringify(summary, null, 2));
} else {
  console.log(`Scanned: ${summary.scanDir}`);
  console.log(`Files: ${summary.files} (${summary.gradedFiles} graded, ${byGrade['N/A']} N/A) | Assertions: ${summary.totalAssertions} (weak: ${summary.weakTotal} = ${(summary.weakTotal / summary.totalAssertions * 100).toFixed(1)}%)`);
  console.log(`Grades: A=${byGrade.A} B=${byGrade.B} C=${byGrade.C} D=${byGrade.D} F=${byGrade.F}`);
  console.log(`\nWorst ${topN} by weak%:`);
  console.log('  weak%  | grade | weak/total | it() | file');
  for (const r of summary.results.slice(0, topN)) {
    if (r.grade === 'N/A') continue;
    console.log(`  ${String(r.weakPct).padStart(5)}% | ${r.grade.padEnd(5)} | ${String(r.weak).padStart(4)}/${String(r.assertions).padEnd(6)} | ${String(r.itCount).padStart(4)} | ${r.file}`);
  }
  console.log(`\nJSON: ${outFile}`);
}