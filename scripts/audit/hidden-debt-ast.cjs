#!/usr/bin/env node
/**
 * hidden-debt-ast.cjs — Phase 1 AST Hidden-Debt Audit Tooling (#1751)
 *
 * Parses all production *.ts files (parent + submod) to produce:
 * 1. Call graph: exports → importers (flag orphan exports)
 * 2. Static/pre-wired methods without callers
 * 3. Stub patterns (STUB, NOT IMPLEMENTED, TODO, FIXME, empty returns)
 *
 * Output: phase1-call-graph.json + phase1-report.md
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Resolve typescript from submodule's node_modules
const ROOT = path.resolve(__dirname, '..', '..');
const SUBMOD_ROOT = path.join(ROOT, 'mcps', 'internal', 'servers', 'roo-state-manager');
const ts = require(path.join(SUBMOD_ROOT, 'node_modules', 'typescript'));

// ─── Configuration ───

const SUBMOD_SRC = path.join(SUBMOD_ROOT, 'src');
const PARENT_PATTERNS = [path.join(ROOT, 'modules')];

const OUTPUT_DIR = path.join(ROOT, 'outputs', 'audits', 'hidden-debt');

const EXCLUDE_DIRS = new Set([
  '__tests__', 'tests', 'test', 'build', 'node_modules',
  '.git', '.claude', 'archive', 'examples', 'dist',
]);

const STUB_PATTERNS = [
  { regex: /logInfo\(\s*['"]STUB:/g, label: 'STUB' },
  { regex: /logWarn\(\s*['"]NOT IMPLEMENTED/g, label: 'NOT IMPLEMENTED' },
  { regex: /throw new Error\(\s*['"]TODO/g, label: 'THROW TODO' },
  { regex: /\/\/\s*FIXME\b/gi, label: 'FIXME' },
  { regex: /\/\/\s*TODO\b/gi, label: 'TODO' },
  { regex: /return null;\s*\/\/.*to be implemented/gi, label: 'NULL RETURN (not implemented)' },
  { regex: /return\s*\[\];?\s*\/\/.*to be implemented/gi, label: 'EMPTY RETURN (not implemented)' },
  { regex: /throw new Error\(['"]Not implemented/gi, label: 'NOT IMPLEMENTED ERROR' },
  { regex: /\/\/\s*HACK\b/gi, label: 'HACK' },
];

// ─── File Discovery ───

function discoverTsFiles(rootDir) {
  const files = [];
  function walk(dir) {
    try {
      const entries = fs.readdirSync(dir, { withFileTypes: true });
      for (const entry of entries) {
        if (EXCLUDE_DIRS.has(entry.name)) continue;
        const full = path.join(dir, entry.name);
        if (entry.isDirectory()) walk(full);
        else if (entry.name.endsWith('.ts') && !entry.name.endsWith('.d.ts')) files.push(full);
      }
    } catch { /* skip */ }
  }
  walk(rootDir);
  return files;
}

// ─── AST Parsing ───

function parseFile(filePath) {
  const content = fs.readFileSync(filePath, 'utf-8');
  const sourceFile = ts.createSourceFile(filePath, content, ts.ScriptTarget.Latest, true, ts.ScriptKind.TS);
  return { sourceFile, content };
}

// ─── Modifier Helpers ───

function hasModifier(node, kind) {
  const modifiers = ts.canHaveModifiers(node) ? ts.getModifiers(node) : undefined;
  return modifiers?.some(m => m.kind === kind) ?? false;
}

// ─── Export Collection ───

function collectExports(sourceFile, relPath) {
  const exports = [];

  function visit(node) {
    if (ts.isFunctionDeclaration(node) && node.name && hasModifier(node, ts.SyntaxKind.ExportKeyword)) {
      exports.push({ name: node.name.text, kind: 'function', file: relPath,
        line: sourceFile.getLineAndCharacterOfPosition(node.getStart()).line + 1,
        isDefault: hasModifier(node, ts.SyntaxKind.DefaultKeyword) });
    }

    if ((ts.isClassDeclaration(node) || ts.isInterfaceDeclaration(node) || ts.isTypeAliasDeclaration(node)) && node.name) {
      if (hasModifier(node, ts.SyntaxKind.ExportKeyword)) {
        let kind = 'class';
        if (ts.isInterfaceDeclaration(node)) kind = 'interface';
        if (ts.isTypeAliasDeclaration(node)) kind = 'type';

        const methods = [];
        if (ts.isClassDeclaration(node)) {
          for (const member of node.members) {
            if (ts.isMethodDeclaration(member) && member.name) {
              methods.push({
                name: member.name.getText(sourceFile),
                isStatic: hasModifier(member, ts.SyntaxKind.StaticKeyword),
                isPrivate: hasModifier(member, ts.SyntaxKind.PrivateKeyword),
                line: sourceFile.getLineAndCharacterOfPosition(member.getStart()).line + 1,
              });
            }
          }
        }

        exports.push({ name: node.name.text, kind, file: relPath,
          line: sourceFile.getLineAndCharacterOfPosition(node.getStart()).line + 1,
          isDefault: hasModifier(node, ts.SyntaxKind.DefaultKeyword), methods });
      }
    }

    if (ts.isVariableStatement(node) && hasModifier(node, ts.SyntaxKind.ExportKeyword)) {
      for (const decl of node.declarationList.declarations) {
        if (decl.name && ts.isIdentifier(decl.name)) {
          exports.push({ name: decl.name.text, kind: 'const', file: relPath,
            line: sourceFile.getLineAndCharacterOfPosition(node.getStart()).line + 1 });
        }
      }
    }

    if (ts.isExportDeclaration(node)) {
      if (node.exportClause && ts.isNamedExports(node.exportClause)) {
        for (const el of node.exportClause.elements) {
          exports.push({ name: el.name.text, kind: 're-export', file: relPath,
            line: sourceFile.getLineAndCharacterOfPosition(node.getStart()).line + 1 });
        }
      }
      if (node.moduleSpecifier && ts.isStringLiteral(node.moduleSpecifier)) {
        exports.push({ name: '*', kind: 're-export-all', file: relPath,
          line: sourceFile.getLineAndCharacterOfPosition(node.getStart()).line + 1,
          moduleSpecifier: node.moduleSpecifier.text });
      }
    }

    if (ts.isExportAssignment(node)) {
      const name = node.expression && ts.isIdentifier(node.expression) ? node.expression.text : '<default>';
      exports.push({ name, kind: 'default-export', file: relPath,
        line: sourceFile.getLineAndCharacterOfPosition(node.getStart()).line + 1, isDefault: true });
    }

    ts.forEachChild(node, visit);
  }
  visit(sourceFile);
  return exports;
}

// ─── Import Collection ───

function collectImports(sourceFile, relPath) {
  const imports = [];

  function visit(node) {
    if (ts.isImportDeclaration(node) && node.importClause) {
      const modSpec = node.moduleSpecifier && ts.isStringLiteral(node.moduleSpecifier) ? node.moduleSpecifier.text : null;

      if (node.importClause.namedBindings && ts.isNamedImports(node.importClause.namedBindings)) {
        for (const el of node.importClause.namedBindings.elements) {
          imports.push({ name: el.name.text, from: modSpec, file: relPath,
            line: sourceFile.getLineAndCharacterOfPosition(node.getStart()).line + 1 });
        }
      }
      if (node.importClause.namedBindings && ts.isNamespaceImport(node.importClause.namedBindings)) {
        imports.push({ name: `* as ${node.importClause.namedBindings.name.text}`, from: modSpec, file: relPath,
          line: sourceFile.getLineAndCharacterOfPosition(node.getStart()).line + 1 });
      }
      if (node.importClause.name) {
        imports.push({ name: node.importClause.name.text, from: modSpec, file: relPath,
          line: sourceFile.getLineAndCharacterOfPosition(node.getStart()).line + 1, isDefault: true });
      }
    }
    ts.forEachChild(node, visit);
  }
  visit(sourceFile);
  return imports;
}

// ─── Method Call Collection ───

function collectMethodCalls(sourceFile, relPath) {
  const calls = [];

  function visit(node) {
    if (ts.isCallExpression(node)) {
      const expr = node.expression;
      if (ts.isPropertyAccessExpression(expr)) {
        const methodName = expr.name.text;
        if (/^(configure|init|register|setup|initialize|bootstrap)$/i.test(methodName)) {
          const objectName = ts.isIdentifier(expr.expression) ? expr.expression.text : null;
          if (objectName) {
            calls.push({ method: methodName, object: objectName, file: relPath,
              line: sourceFile.getLineAndCharacterOfPosition(node.getStart()).line + 1 });
          }
        }
      }
    }
    ts.forEachChild(node, visit);
  }
  visit(sourceFile);
  return calls;
}

// ─── Stub Detection ───

function collectStubs(content, relPath) {
  const stubs = [];
  const lines = content.split('\n');
  for (let i = 0; i < lines.length; i++) {
    for (const pattern of STUB_PATTERNS) {
      pattern.regex.lastIndex = 0;
      if (pattern.regex.test(lines[i])) {
        stubs.push({ file: relPath, line: i + 1, pattern: pattern.label, context: lines[i].trim() });
      }
    }
  }
  return stubs;
}

// ─── Barrel Re-export Resolution ───

function buildBarrelMap(allExports) {
  // Map: file → Set of names re-exported FROM that file
  // When file A has `export { Foo } from './B'`, we record that file A re-exports Foo
  // So if file C imports { Foo } from '../A', we know Foo comes from B via A

  const fileToReExportedNames = new Map(); // file → Map(name → sourceModule)
  const fileToWildcardSources = new Map(); // file → Set<sourceModule>

  for (const exp of allExports) {
    if (exp.kind === 're-export' && exp.moduleSpecifier) {
      if (!fileToReExportedNames.has(exp.file)) fileToReExportedNames.set(exp.file, new Map());
      fileToReExportedNames.get(exp.file).set(exp.name, exp.moduleSpecifier);
    }
    if (exp.kind === 're-export-all' && exp.moduleSpecifier) {
      if (!fileToWildcardSources.has(exp.file)) fileToWildcardSources.set(exp.file, new Set());
      fileToWildcardSources.get(exp.file).add(exp.moduleSpecifier);
    }
  }

  return { fileToReExportedNames, fileToWildcardSources };
}

function resolveModulePath(fromFile, moduleSpecifier) {
  if (!moduleSpecifier) return null;
  const dir = path.dirname(fromFile);
  // ESM .js → .ts conversion
  let spec = moduleSpecifier.replace(/\.js$/, '.ts');
  let resolved = path.normalize(path.join(dir, spec)).replace(/\\/g, '/');
  // Direct file
  if (fs.existsSync(path.join(ROOT, resolved))) return resolved;
  // Try /index.ts
  const indexPath = resolved.replace(/\.ts$/, '/index.ts');
  if (fs.existsSync(path.join(ROOT, indexPath))) return indexPath;
  return resolved; // Return even if not found (for barrel resolution)
}

// ─── Git Blame ───

function getBlameInfo(filePath, line) {
  try {
    const result = execSync(
      `git blame -L ${line},${line} --porcelain "${filePath}"`,
      { cwd: ROOT, encoding: 'utf-8', timeout: 5000 }
    );
    const hash = result.split('\n')[0]?.substring(0, 8) || 'unknown';
    const authorLine = result.split('\n').find(l => l.startsWith('author '));
    const timeLine = result.split('\n').find(l => l.startsWith('author-time '));
    const author = authorLine?.substring(7) || 'unknown';
    const timestamp = timeLine ? new Date(parseInt(timeLine.substring(12)) * 1000).toISOString().split('T')[0] : 'unknown';
    return { hash, author, date: timestamp };
  } catch {
    return { hash: 'unknown', author: 'unknown', date: 'unknown' };
  }
}

// ─── Main ───

function main() {
  const startTime = Date.now();
  console.log('=== Phase 1 AST Hidden-Debt Audit ===\n');

  let allFiles = [];

  if (fs.existsSync(SUBMOD_SRC)) {
    const submodFiles = discoverTsFiles(SUBMOD_SRC);
    console.log(`Submod TS files: ${submodFiles.length}`);
    allFiles.push(...submodFiles);
  }

  for (const p of PARENT_PATTERNS) {
    if (fs.existsSync(p)) {
      const parentFiles = discoverTsFiles(p);
      console.log(`Parent TS files (${path.basename(p)}): ${parentFiles.length}`);
      allFiles.push(...parentFiles);
    }
  }

  const scriptsDir = path.join(ROOT, 'scripts');
  if (fs.existsSync(scriptsDir)) {
    const scriptFiles = discoverTsFiles(scriptsDir);
    if (scriptFiles.length) { console.log(`Parent scripts TS files: ${scriptFiles.length}`); allFiles.push(...scriptFiles); }
  }

  console.log(`\nTotal files to analyze: ${allFiles.length}`);

  // Build file path → relative path map
  const filePathToRel = new Map();
  for (const fp of allFiles) {
    filePathToRel.set(fp, path.relative(ROOT, fp).replace(/\\/g, '/'));
  }

  // Parse all files
  const allExports = [];
  const allImports = [];
  const allMethodCalls = [];
  const allStubs = [];
  let parseErrors = 0;

  for (const filePath of allFiles) {
    try {
      const { sourceFile, content } = parseFile(filePath);
      const relPath = filePathToRel.get(filePath);
      allExports.push(...collectExports(sourceFile, relPath));
      allImports.push(...collectImports(sourceFile, relPath));
      allMethodCalls.push(...collectMethodCalls(sourceFile, relPath));
      allStubs.push(...collectStubs(content, relPath));
    } catch (err) {
      parseErrors++;
      console.error(`Parse error: ${filePathToRel.get(filePath) || filePath}: ${err.message}`);
    }
  }

  console.log(`Parsed: ${allFiles.length - parseErrors} OK, ${parseErrors} errors`);
  console.log(`Exports: ${allExports.length} | Imports: ${allImports.length} | Method calls: ${allMethodCalls.length} | Stubs: ${allStubs.length}`);

  // ─── Build importers map (resolving barrel re-exports) ───

  // Direct importers: name → Set<file>
  const directImporters = new Map();
  for (const imp of allImports) {
    if (imp.name.startsWith('* as ')) continue;
    if (!directImporters.has(imp.name)) directImporters.set(imp.name, new Set());
    directImporters.get(imp.name).add(imp.file);
  }

  // Build barrel map
  const { fileToReExportedNames, fileToWildcardSources } = buildBarrelMap(allExports);

  // Build file → Set<exported name> for all files
  const fileToExports = new Map();
  for (const exp of allExports) {
    if (exp.kind === 're-export' || exp.kind === 're-export-all') continue;
    if (!fileToExports.has(exp.file)) fileToExports.set(exp.file, new Set());
    fileToExports.get(exp.file).add(exp.name);
  }

  // Resolve transitive importers through barrel files
  // For each re-export in barrel file B (export { Foo } from './A'):
  //   If file C imports { Foo } from B, then Foo's real source is A.
  //   We add C as an importer of A's Foo.
  const effectiveImporters = new Map(); // name → Map<sourceFile, Set<importerFile>>

  for (const imp of allImports) {
    if (imp.name.startsWith('* as ') || !imp.from) continue;

    // Resolve where the import comes from
    const resolvedFrom = resolveModulePath(imp.file, imp.from);
    if (!resolvedFrom) continue;

    // Check if resolvedFrom is a barrel that re-exports this name
    const reExports = fileToReExportedNames.get(resolvedFrom);
    if (reExports && reExports.has(imp.name)) {
      // This import goes through a barrel — trace to original
      const sourceModule = reExports.get(imp.name);
      const originalFile = resolveModulePath(resolvedFrom, sourceModule);
      if (originalFile) {
        if (!effectiveImporters.has(imp.name)) effectiveImporters.set(imp.name, new Map());
        if (!effectiveImporters.get(imp.name).has(originalFile)) effectiveImporters.get(imp.name).set(originalFile, new Set());
        effectiveImporters.get(imp.name).get(originalFile).add(imp.file);
      }
    }

    // Also check wildcard re-exports
    const wildcards = fileToWildcardSources.get(resolvedFrom);
    if (wildcards) {
      for (const sourceModule of wildcards) {
        const originalFile = resolveModulePath(resolvedFrom, sourceModule);
        if (originalFile && fileToExports.has(originalFile) && fileToExports.get(originalFile).has(imp.name)) {
          if (!effectiveImporters.has(imp.name)) effectiveImporters.set(imp.name, new Map());
          if (!effectiveImporters.get(imp.name).has(originalFile)) effectiveImporters.get(imp.name).set(originalFile, new Set());
          effectiveImporters.get(imp.name).get(originalFile).add(imp.file);
        }
      }
    }
  }

  // ─── Annotate exports ───

  // Known dynamic dispatch contexts — these classes/services are instantiated by DI
  const DYNAMIC_DISPATCH_CLASSES = new Set([
    'ServiceRegistry', 'StateManager', 'MCPServer', 'RooStateManagerServer',
    'ConfigService', 'InventoryService', 'RooSyncService',
  ]);

  const exportRecords = allExports.map(exp => {
    if (exp.kind === 're-export' || exp.kind === 're-export-all') {
      return { ...exp, importers: [], importerCount: 0, isOrphan: false, isDynamic: false };
    }

    // Direct importers (importing from this exact file)
    const direct = directImporters.get(exp.name) || new Set();
    const directFiltered = [...direct].filter(f => f !== exp.file);

    // Transitive importers (importing through barrel files)
    const transMap = effectiveImporters.get(exp.name);
    const transitive = transMap?.get(exp.file) || new Set();

    const allImporterFiles = new Set([...directFiltered, ...transitive]);
    const importerCount = allImporterFiles.size;

    const isDynamic = DYNAMIC_DISPATCH_CLASSES.has(exp.name) ||
      (exp.kind === 'class' && exp.name.endsWith('Service') && importerCount === 0);

    return {
      ...exp,
      importers: [...allImporterFiles],
      importerCount,
      isOrphan: importerCount === 0,
      isDynamic,
    };
  });

  // ─── Pre-wired methods ───

  const methodDefinitions = [];
  for (const exp of exportRecords) {
    if (exp.kind === 'class' && exp.methods) {
      for (const method of exp.methods) {
        if (/(configure|init|register|setup|initialize|bootstrap)/i.test(method.name) && !method.isPrivate) {
          methodDefinitions.push({
            class: exp.name, name: method.name, isStatic: method.isStatic,
            file: exp.file, line: method.line,
          });
        }
      }
    }
  }

  const preWiredRecords = methodDefinitions.map(def => {
    const callers = allMethodCalls.filter(c => c.method === def.name && c.object === def.class);
    return {
      ...def,
      callers: callers.map(c => ({ file: c.file, line: c.line, object: c.object })),
      callerCount: callers.length,
      isOrphan: callers.length === 0,
    };
  });

  // ─── Build JSON ───

  const durationMs = Date.now() - startTime;

  const trueOrphans = exportRecords.filter(e => e.isOrphan && !e.isDynamic && e.kind !== 're-export' && e.kind !== 're-export-all');

  // Add git blame for stubs (top 50 only to limit time)
  const stubsWithBlame = allStubs.map((s, i) => {
    if (i < 50) {
      const blame = getBlameInfo(s.file, s.line);
      return { ...s, blame };
    }
    return { ...s, blame: null };
  });

  const jsonOutput = {
    metadata: {
      scanDate: new Date().toISOString(),
      filesAnalyzed: allFiles.length,
      parseErrors,
      duration_ms: durationMs,
      exportCount: allExports.length,
      orphanCount: trueOrphans.length,
      importCount: allImports.length,
      stubCount: allStubs.length,
    },
    exports: exportRecords.map(e => ({
      file: e.file, name: e.name, kind: e.kind, line: e.line,
      importers: e.importers, importerCount: e.importerCount,
      isOrphan: e.isOrphan, isDynamic: e.isDynamic,
    })),
    preWiredMethods: preWiredRecords,
    stubs: stubsWithBlame,
  };

  // ─── Write outputs ───

  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  const jsonPath = path.join(OUTPUT_DIR, 'phase1-call-graph.json');
  fs.writeFileSync(jsonPath, JSON.stringify(jsonOutput, null, 2));
  console.log(`\nJSON output: ${jsonPath}`);

  const md = generateReport(jsonOutput, durationMs);
  const mdPath = path.join(OUTPUT_DIR, 'phase1-report.md');
  fs.writeFileSync(mdPath, md);
  console.log(`Markdown report: ${mdPath}`);
  console.log(`\n=== Complete in ${durationMs}ms ===`);
}

// ─── Report Generation ───

function generateReport(data, durationMs) {
  const lines = [];
  lines.push('# Phase 1 AST Hidden-Debt Audit Report');
  lines.push('');
  lines.push(`**Scan Date:** ${data.metadata.scanDate}`);
  lines.push(`**Files Analyzed:** ${data.metadata.filesAnalyzed}`);
  lines.push(`**Duration:** ${(durationMs / 1000).toFixed(1)}s`);
  lines.push(`**Parse Errors:** ${data.metadata.parseErrors}`);
  lines.push('');

  const orphanExports = data.exports.filter(e => e.isOrphan && !e.isDynamic && e.kind !== 're-export' && e.kind !== 're-export-all');
  const dynamicExports = data.exports.filter(e => e.isOrphan && e.isDynamic);
  const nonOrphanExports = data.exports.filter(e => !e.isOrphan && e.kind !== 're-export' && e.kind !== 're-export-all');
  const orphanMethods = data.preWiredMethods.filter(m => m.isOrphan);
  const todoCount = data.stubs.filter(s => s.pattern === 'TODO').length;
  const fixmeCount = data.stubs.filter(s => s.pattern === 'FIXME').length;
  const hackCount = data.stubs.filter(s => s.pattern === 'HACK').length;
  const stubCount = data.stubs.filter(s => s.pattern === 'STUB' || s.pattern === 'NOT IMPLEMENTED' || s.pattern === 'NOT IMPLEMENTED ERROR').length;

  lines.push('## Summary');
  lines.push('');
  lines.push('| Category | Count |');
  lines.push('|----------|-------|');
  lines.push(`| Total exports (excl. re-exports) | ${data.exports.filter(e => e.kind !== 're-export' && e.kind !== 're-export-all').length} |`);
  lines.push(`| Exports with importers | ${nonOrphanExports.length} |`);
  lines.push(`| Orphan exports (no importers, not dynamic) | **${orphanExports.length}** |`);
  lines.push(`| Dynamic/registry (orphan but expected) | ${dynamicExports.length} |`);
  lines.push(`| Pre-wired methods without callers | **${orphanMethods.length}** |`);
  lines.push(`| TODO comments | ${todoCount} |`);
  lines.push(`| FIXME comments | ${fixmeCount} |`);
  lines.push(`| HACK comments | ${hackCount} |`);
  lines.push(`| STUB/NOT IMPLEMENTED | ${stubCount} |`);
  lines.push('');

  // ─── Orphan Exports by Category ───

  if (orphanExports.length > 0) {
    lines.push('## Orphan Exports by Category');
    lines.push('');
    const byKind = {};
    for (const exp of orphanExports) {
      byKind[exp.kind] = (byKind[exp.kind] || 0) + 1;
    }
    lines.push('| Kind | Count |');
    lines.push('|------|-------|');
    for (const [kind, count] of Object.entries(byKind).sort((a, b) => b[1] - a[1])) {
      lines.push(`| ${kind} | ${count} |`);
    }
    lines.push('');
  }

  // ─── Top 30 Orphan Exports ───

  lines.push('## Top 30 Orphan Exports');
  lines.push('');
  lines.push('| # | Name | Kind | File | Likely Reason |');
  lines.push('|---|------|------|------|----------------|');
  orphanExports.slice(0, 30).forEach((exp, i) => {
    lines.push(`| ${i + 1} | \`${exp.name}\` | ${exp.kind} | ${exp.file}:${exp.line} | ${guessOrphanReason(exp)} |`);
  });
  lines.push('');

  // ─── Dynamic/Registry Exports ───

  if (dynamicExports.length > 0) {
    lines.push(`## Dynamic/Registry Exports (${dynamicExports.length} total, showing first 20)`);
    lines.push('');
    lines.push('| # | Name | Kind | File |');
    lines.push('|---|------|------|------|');
    dynamicExports.slice(0, 20).forEach((exp, i) => {
      lines.push(`| ${i + 1} | \`${exp.name}\` | ${exp.kind} | ${exp.file}:${exp.line} |`);
    });
    lines.push('');
  }

  // ─── Pre-wired Methods ───

  if (orphanMethods.length > 0) {
    lines.push('## Pre-wired Methods Without Callers');
    lines.push('');
    lines.push('| # | Class | Method | Static | File |');
    lines.push('|---|-------|--------|--------|------|');
    orphanMethods.forEach((m, i) => {
      lines.push(`| ${i + 1} | \`${m.class}\` | \`${m.name}\` | ${m.isStatic ? 'Yes' : 'No'} | ${m.file}:${m.line} |`);
    });
    lines.push('');
  }

  // ─── Stubs with blame ───

  if (data.stubs.length > 0) {
    lines.push('## Stubs & TODO/FIXME');
    lines.push('');
    lines.push('| # | Pattern | File:Line | Age | Context |');
    lines.push('|---|---------|-----------|-----|---------|');

    const sorted = [...data.stubs].sort((a, b) => {
      const order = { 'STUB': 0, 'NOT IMPLEMENTED': 1, 'NOT IMPLEMENTED ERROR': 2, 'THROW TODO': 3, 'FIXME': 4, 'HACK': 5, 'TODO': 6 };
      return (order[a.pattern] ?? 7) - (order[b.pattern] ?? 7);
    });

    sorted.slice(0, 50).forEach((s, i) => {
      const ctx = s.context.length > 80 ? s.context.substring(0, 77) + '...' : s.context;
      const age = s.blame ? `${s.blame.date}` : '';
      lines.push(`| ${i + 1} | ${s.pattern} | ${s.file}:${s.line} | ${age} | \`${ctx.replace(/`/g, "'")}\` |`);
    });
    lines.push('');
  }

  // ─── Recommendations ───

  lines.push('## Preliminary Recommendations');
  lines.push('');

  if (orphanExports.length > 0) {
    lines.push('### To Investigate (Orphan Exports)');
    lines.push('');
    lines.push(`- **${orphanExports.length} exports** have zero importers and no dynamic dispatch evidence`);
    lines.push('- Verify each against: tool registration, DI container, test-only usage, or genuine dead code');
    lines.push('');
  }

  if (orphanMethods.length > 0) {
    lines.push('### Pre-wired Methods');
    lines.push('');
    lines.push(`- **${orphanMethods.length} methods** matching init/configure/register patterns have zero callers in production code`);
    lines.push('- Check if called via DI, reflection, or external entry points before removal');
    lines.push('');
  }

  if (todoCount + fixmeCount > 0) {
    lines.push('### Technical Debt Markers');
    lines.push('');
    lines.push(`- ${todoCount} TODO + ${fixmeCount} FIXME — candidates for issue creation`);
    lines.push('');
  }

  lines.push('---');
  lines.push(`*Generated by hidden-debt-ast.cjs — Phase 1 #1751*`);
  return lines.join('\n');
}

function guessOrphanReason(exp) {
  const name = exp.name.toLowerCase();
  const file = exp.file.toLowerCase();

  if (name.includes('service') && exp.kind === 'class') return 'Likely DI/service registry';
  if (name.includes('handler') || name.includes('tool')) return 'Likely tool/handler registration';
  if (name.includes('config')) return 'Config export';
  if (exp.kind === 'type' || exp.kind === 'interface') return 'Type export (TS-only)';
  if (name.includes('error') && exp.kind === 'class') return 'Error class (thrown dynamically)';
  if (name.startsWith('i') && exp.kind === 'interface') return 'Interface (type-only)';
  if (name.includes('model') && (exp.kind === 'interface' || exp.kind === 'type')) return 'Model/type definition';
  if (name.includes('factory') || name.includes('builder')) return 'Factory/builder pattern';
  if (name.includes('strategy') || name.includes('provider')) return 'Strategy/provider pattern';
  if (name.includes('constant') || name.includes('config') || name.includes('default')) return 'Constant/config value';
  if (file.includes('/config/')) return 'Config module export';
  if (file.includes('/interfaces/')) return 'Interface module export';
  if (file.includes('/models/')) return 'Model module export';
  if (file.includes('/types/')) return 'Type module export';
  if (file.includes('/utils/')) return 'Utility export';
  return 'Unknown — verify manually';
}

main();
