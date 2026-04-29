const fs = require('fs');
const path = require('path');

// Combiner tous les fichiers de couverture
const coverageDir = './mcps/internal/servers/roo-state-manager/coverage/.tmp';
const allFiles = [];

// Lire tous les fichiers de couverture
for (let i = 0; i < 27; i++) {
  const filePath = path.join(coverageDir, `coverage-${i}.json`);
  if (fs.existsSync(filePath)) {
    try {
      const content = fs.readFileSync(filePath, 'utf8');
      const data = JSON.parse(content);
      if (data.result && data.result.length > 0) {
        allFiles.push(...data.result);
      }
    } catch (e) {
      console.log(`Erreur de lecture de ${filePath}: ${e.message}`);
    }
  }
}

// Analyser chaque fichier
const files = allFiles.map(script => {
  // Extraire le chemin relatif
  const filePath = script.url.replace('file:///', '').replace(/\/D:\/dev\/[^/]+\//, '');

  // Calculer la couverture
  let totalLines = 0;
  let coveredLines = 0;
  let totalStatements = 0;
  let coveredStatements = 0;

  script.functions.forEach(func => {
    func.ranges.forEach(range => {
      const length = range.endOffset - range.startOffset;
      if (range.count > 0) {
        coveredLines += length;
        coveredStatements += length;
      }
      totalLines += length;
      totalStatements += length;
    });
  });

  const linesPercent = totalLines > 0 ? Math.round((coveredLines / totalLines) * 100) : 0;
  const statementsPercent = totalStatements > 0 ? Math.round((coveredStatements / totalStatements) * 100) : 0;

  return {
    file: filePath,
    lines: linesPercent,
    statements: statementsPercent,
    totalLines,
    coveredLines
  };
});

// Filtrer les fichiers TypeScript/JS qui ont des lignes mais peu de couverture
const tsFiles = files.filter(f =>
  (f.file.includes('.ts') || f.file.includes('.js')) &&
  f.totalLines > 0 &&
  f.lines < 80 &&
  f.lines > 0
);

// Trier par couverture la plus faible
tsFiles.sort((a, b) => a.lines - b.lines);

console.log('=== Top 5 fichiers avec la couverture la plus faible (<80%) ===');
tsFiles.slice(0, 5).forEach((f, i) => {
  console.log(`${i + 1}. ${f.file}`);
  console.log(`   Lines: ${f.lines}% (${f.coveredLines}/${f.totalLines} lines)`);
  console.log(`   Statements: ${f.statements}%`);
  console.log('');
});

console.log(`\nTotal files with <80% coverage: ${tsFiles.length}`);
console.log(`\nTotal files analyzed: ${files.length}`);