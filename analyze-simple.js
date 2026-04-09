import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const coverageDir = path.join(__dirname, 'coverage/.tmp');

// Read all coverage files
const coverageFiles = fs.readdirSync(coverageDir);

const stats = {};

coverageFiles.forEach(file => {
  if (file.startsWith('coverage-') && file.endsWith('.json')) {
    const filePath = path.join(coverageDir, file);
    const data = fs.readFileSync(filePath, 'utf8');
    const coverage = JSON.parse(data);

    coverage.result.forEach(fileCoverage => {
      if (fileCoverage.url && fileCoverage.url.startsWith('file:///')) {
        // Convert file URL to relative path
        let relativePath = fileCoverage.url.replace('file:///C:/dev/roo-extensions/.claude/worktrees/wt-worker-myia-web1-20260409-080734/mcps/internal/servers/roo-state-manager/', '');
        relativePath = relativePath.replace(/\?.*/, ''); // Remove query parameters

        if (!stats[relativePath]) {
          stats[relativePath] = {
            covered: 0,
            total: 0,
            functions: 0,
            coveredFunctions: 0
          };
        }

        const fileStats = stats[relativePath];

        // Count lines covered
        let coveredLines = 0;
        let totalLines = 0;

        fileCoverage.functions.forEach(func => {
          fileStats.functions++;

          func.ranges.forEach(range => {
            if (range.count > 0) {
              coveredLines += range.endOffset - range.startOffset;
              fileStats.coveredFunctions++;
            }
            totalLines += range.endOffset - range.startOffset;
          });
        });

        // Aggregate across all files
        fileStats.covered += coveredLines;
        fileStats.total += totalLines;
      }
    });
  }
});

// Calculate coverage percentages
const coveragePercentages = Object.entries(stats)
  .filter(([_, stats]) => stats.total > 0)
  .map(([filePath, stats]) => ({
    file: filePath,
    covered: stats.covered,
    total: stats.total,
    percentage: (stats.covered / stats.total) * 100,
    functions: stats.functions,
    coveredFunctions: stats.coveredFunctions,
    functionCoverage: stats.functions > 0 ? (stats.coveredFunctions / stats.functions) * 100 : 0
  }));

// Sort by coverage percentage (ascending)
coveragePercentages.sort((a, b) => a.percentage - b.percentage);

console.log('Test Coverage Analysis Results:');
console.log('==================================\n');

console.log(`Total files analyzed: ${coveragePercentages.length}\n`);

// Find files with <60% coverage
const lowCoverageFiles = coveragePercentages.filter(f => f.percentage < 60 && f.total > 10);

console.log(`Files with <60% coverage: ${lowCoverageFiles.length}\n`);

if (lowCoverageFiles.length > 0) {
  console.log('Top 3 lowest coverage files (<60%):\n');
  lowCoverageFiles.slice(0, 3).forEach((file, index) => {
    console.log(`${index + 1}. ${file.file}`);
    console.log(`   Coverage: ${file.percentage.toFixed(2)}% (${file.covered}/${file.total} lines)`);
    console.log(`   Function coverage: ${file.functionCoverage.toFixed(2)}% (${file.coveredFunctions}/${file.functions} functions)\n`);
  });

  // Show the absolute lowest coverage file for adding tests
  const lowestFile = lowCoverageFiles[0];
  console.log(`\nLowest coverage file: ${lowestFile.file}`);
  console.log(`Current coverage: ${lowestFile.percentage.toFixed(2)}%\n`);
} else {
  console.log('No files with <60% coverage found.\n');
  console.log('Top 3 lowest coverage files:\n');
  coveragePercentages.slice(0, 3).forEach((file, index) => {
    console.log(`${index + 1}. ${file.file}`);
    console.log(`   Coverage: ${file.percentage.toFixed(2)}% (${file.covered}/${file.total} lines)\n`);
  });
}

// Calculate average coverage
const averageCoverage = coveragePercentages.reduce((sum, f) => sum + f.percentage, 0) / coveragePercentages.length;
console.log(`Average coverage: ${averageCoverage.toFixed(2)}%`);

if (averageCoverage > 80) {
  console.log('\nAverage coverage >80% - No need to add tests for exploration phase.');
}