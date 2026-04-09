import fs from 'fs';
import path from 'path';

function analyzeCoverage() {
    // Read the coverage data
    const coveragePath = './src/tools/coverage/coverage-final.json';
    const coverageData = JSON.parse(fs.readFileSync(coveragePath, 'utf8'));

    const results = [];

    // Change to the correct directory
    const originalCwd = process.cwd();
    process.chdir('mcps/internal/servers/roo-state-manager');

    try {
        // Process each file in coverage data
        coverageData.result.forEach(fileData => {
            // Skip test files
            if (fileData.url.includes('__tests__') ||
                fileData.url.endsWith('.test.ts') ||
                fileData.url.endsWith('.test.js')) {
                return;
            }

            // Extract file path
            let filePath = fileData.url.replace('file:///D:/dev/roo-extensions/.claude/worktrees/wt-worker-myia-po-2025-20260408-052159/', '');

            // Skip if file doesn't exist
            if (!fs.existsSync(filePath)) {
                return;
            }

            // Calculate coverage
            let totalLines = 0;
            let coveredLines = 0;
            let functionCount = 0;

            fileData.functions.forEach(func => {
                functionCount++;
                func.ranges.forEach(range => {
                    totalLines += (range.endOffset - range.startOffset);
                    if (range.count > 0) {
                        coveredLines += (range.endOffset - range.startOffset);
                    }
                });
            });

            // Calculate percentage
            const coveragePercent = totalLines > 0 ? Math.round((coveredLines / totalLines) * 100) : 0;

            // Only include files with coverage data
            if (totalLines > 0) {
                results.push({
                    filePath: filePath,
                    coveragePercent: coveragePercent,
                    totalLines: totalLines,
                    coveredLines: coveredLines,
                    functions: functionCount
                });
            }
        });

        // Sort by coverage percentage (ascending)
        results.sort((a, b) => a.coveragePercent - b.coveragePercent);

        return results;
    } finally {
        // Restore original working directory
        process.chdir(originalCwd);
    }
}

// Export for testing
export { analyzeCoverage };
export default analyzeCoverage;