const fs = require('fs');
const path = require('path');

const coverageDir = path.join(__dirname, 'mcps', 'internal', 'servers', 'roo-state-manager', 'coverage', '.tmp');
const reports = fs.readdirSync(coverageDir).filter(file => file.startsWith('coverage-')).map(file => path.join(coverageDir, file));

console.log('Processing', reports.length, 'coverage files...');

const fileCoverage = new Map();
const allFiles = [];

reports.forEach((file, index) => {
  try {
    const content = JSON.parse(fs.readFileSync(file, 'utf8'));
    if (content.files) {
      content.files.forEach(f => {
        allFiles.push(f.path);
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
    console.log(`Error processing file ${index}:`, e.message);
  }
});

console.log('\nTotal unique files:', fileCoverage.size);
console.log('Sample files with coverage:');
Array.from(fileCoverage.entries()).slice(0, 10).forEach(([file, percent]) => {
  console.log(`${file}: ${percent}%`);
});

console.log('\nCoverage distribution:');
const coverageRanges = {
  '0-20%': 0,
  '21-40%': 0,
  '41-60%': 0,
  '61-80%': 0,
  '81-100%': 0,
  '100%': 0
};

Array.from(fileCoverage.values()).forEach(percent => {
  if (percent === 0) coverageRanges['0-20%']++;
  else if (percent <= 20) coverageRanges['0-20%']++;
  else if (percent <= 40) coverageRanges['21-40%']++;
  else if (percent <= 60) coverageRanges['41-60%']++;
  else if (percent <= 80) coverageRanges['61-80%']++;
  else if (percent < 100) coverageRanges['81-100%']++;
  else coverageRanges['100%']++;
});

Object.entries(coverageRanges).forEach(([range, count]) => {
  console.log(`${range}: ${count} files`);
});