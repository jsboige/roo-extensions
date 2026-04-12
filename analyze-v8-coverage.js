const fs = require('fs');
const path = require('path');

const coverageDir = path.join(__dirname, 'mcps', 'internal', 'servers', 'roo-state-manager', 'coverage', '.tmp');
const reports = fs.readdirSync(coverageDir).filter(file => file.startsWith('coverage-')).map(file => path.join(coverageDir, file));

console.log('Processing', reports.length, 'coverage files...');

const fileCoverage = new Map();

reports.forEach(file => {
  try {
    const content = JSON.parse(fs.readFileSync(file, 'utf8'));

    // V8 coverage format: result array with script objects
    if (content.result) {
      content.result.forEach(script => {
        // Convert URL to local file path
        const url = script.url;
        const localPath = url.replace('file:///', '').replace(/\//g, path.sep);

        // Calculate coverage for this file
        let totalRanges = 0;
        let coveredRanges = 0;

        script.functions.forEach(func => {
          func.ranges.forEach(range => {
            totalRanges++;
            if (range.count > 0) {
              coveredRanges++;
            }
          });
        });

        const percent = totalRanges > 0 ? Math.round((coveredRanges / totalRanges) * 100) : 0;

        // Store the highest coverage percentage for each file
        if (!fileCoverage.has(localPath) || fileCoverage.get(localPath) < percent) {
          fileCoverage.set(localPath, percent);
        }
      });
    }
  } catch (e) {
    console.log(`Error processing file: ${e.message}`);
  }
});

const sortedFiles = Array.from(fileCoverage.entries()).sort((a, b) => a[1] - b[1]);
console.log('\n=== Files with lowest coverage (< 60%) ===');
const lowCoverage = sortedFiles.filter(([_, percent]) => percent < 60);

if (lowCoverage.length === 0) {
  console.log('All files have 60%+ coverage. Showing files with lowest coverage:');
  lowCoverage.push(...sortedFiles.slice(0, 3));
}

lowCoverage.slice(0, 20).forEach(([file, percent]) => {
  console.log(file + ': ' + percent + '%');
});

console.log('\n=== Top 3 lowest coverage files ===');
const top3Lowest = lowCoverage.slice(0, 3);
top3Lowest.forEach(([file, percent], index) => {
  console.log(`${index + 1}. ${file}: ${percent}%`);
});

// Filter for source files (not test files)
const sourceFiles = top3Lowest.filter(([file, _]) => {
  return !file.includes('__tests__') &&
         !file.includes('tests/setup') &&
         !file.includes('tests/unit') &&
         file.endsWith('.ts');
});

console.log('\n=== Target source files for test improvement ===');
sourceFiles.forEach(([file, percent], index) => {
  console.log(`${index + 1}. ${file}: ${percent}%`);
});

if (sourceFiles.length > 0) {
  console.log(`\nSelected target: ${sourceFiles[0][0]} (${sourceFiles[0][1]}% coverage)`);
}