const fs = require('fs');

const coverageFile = './mcps/internal/servers/roo-state-manager/coverage/coverage-final.json';

try {
  const data = fs.readFileSync(coverageFile, 'utf8');
  const coverageData = JSON.parse(data);

  console.log('Total files in coverage:', Object.keys(coverageData).length);

  let lowCoverageFiles = [];

  for (const [filePath, fileCoverage] of Object.entries(coverageData)) {
    // Skip non-source files
    if (filePath.includes('__tests__') ||
        filePath.includes('node_modules') ||
        filePath.includes('.tmp') ||
        filePath.includes('mcp-wrapper.cjs') ||
        !filePath.match(/\.(ts|js)$/)) {
      continue;
    }

    if (fileCoverage && typeof fileCoverage === 'object') {
      const totalLines = fileCoverage.lines?.total || 0;
      const coveredLines = fileCoverage.lines?.covered || 0;

      if (totalLines > 5) {  // Only consider files with more than 5 lines
        const coveragePercent = Math.round((coveredLines / totalLines) * 100);

        if (coveragePercent < 80) {
          lowCoverageFiles.push({
            path: filePath.split('\\').pop(), // Just filename
            coverage: coveragePercent,
            totalLines,
            coveredLines
          });
        }
      }
    }
  }

  // Sort by coverage percentage (lowest first)
  lowCoverageFiles.sort((a, b) => a.coverage - b.coverage);

  console.log('\nFiles with < 80% coverage:');
  console.log('========================');

  if (lowCoverageFiles.length > 0) {
    lowCoverageFiles.slice(0, 10).forEach((file, index) => {
      console.log(`${index + 1}. ${file.path} - ${file.coverage}% (${file.coveredLines}/${file.totalLines} lines)`);
    });

    console.log(`\nTotal files with < 80% coverage: ${lowCoverageFiles.length}`);

    // Find the absolute lowest coverage file
    const lowestFile = lowCoverageFiles[0];
    console.log(`\nLowest coverage file: ${lowestFile.path} - ${lowestFile.coverage}%`);
    console.log('This file needs additional tests!');
  } else {
    console.log('No files found with < 80% coverage');
  }

} catch (e) {
  console.log('Error:', e.message);
}