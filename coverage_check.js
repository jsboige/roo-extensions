const fs = require('fs');

const data = JSON.parse(fs.readFileSync('./mcps/internal/servers/roo-state-manager/coverage/.tmp/coverage-0.json', 'utf8'));
console.log('Total files:', data.files.length);

const filesWithCoverage = data.files.filter(f => f.lineCoverage !== undefined);
filesWithCoverage.sort((a,b) => a.lineCoverage - b.lineCoverage);

console.log('Lowest coverage files:');
const lowCoverageFiles = filesWithCoverage.filter(f => f.lineCoverage < 0.6);
console.log('Files with <60% coverage:', lowCoverageFiles.length);

if (lowCoverageFiles.length > 0) {
    lowCoverageFiles.slice(0, 10).forEach(f => {
        console.log(Math.round(f.lineCoverage * 100) + '% - ' + f.path);
    });
} else {
    filesWithCoverage.slice(0, 10).forEach(f => {
        console.log(Math.round(f.lineCoverage * 100) + '% - ' + f.path);
    });
}