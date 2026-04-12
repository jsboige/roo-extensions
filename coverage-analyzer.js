const fs = require('fs');
const path = require('path');

const coverageDir = path.join(__dirname, 'mcps', 'internal', 'servers', 'roo-state-manager', 'coverage', '.tmp');
const reports = fs.readdirSync(coverageDir).filter(file => file.startsWith('coverage-')).map(file => path.join(coverageDir, file));

console.log('Processing', reports.length, 'coverage files...');

const fileCoverage = new Map();

reports.forEach(file => {
  try {
    const content = JSON.parse(fs.readFileSync(file, 'utf8'));
    if (content.files) {
      content.files.forEach(f => {
        if (f.coverageData && f.coverageData.lineCoverage) {
          const lines = Object.keys(f.coverageData.lineCoverage);
          const covered = Object.keys(f.coverageData.lineCoverage).filter(l => f.coverageData.lineCoverage[l] > 0).length;
          const percent = lines.length > 0 ? Math.round((covered / lines.length) * 100) : 0;

          if (!fileCoverage.has(f.path) || fileCoverage.get(f.path) < percent) {
            fileCoverage.set(f.path, percent);
          }
        }
      });
    }
  } catch (e) {
    // Ignore invalid files
  }
});

const sortedFiles = Array.from(fileCoverage.entries()).sort((a, b) => a[1] - b[1]);
console.log('\n=== Files with lowest coverage (< 60%) ===');
const lowCoverage = sortedFiles.filter(([_, percent]) => percent < 60);
lowCoverage.slice(0, 20).forEach(([file, percent]) => {
  console.log(file + ': ' + percent + '%');
});