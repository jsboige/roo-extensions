#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

// Read the coverage data
const coveragePath = './coverage/coverage-final.json';
const coverageData = JSON.parse(fs.readFileSync(coveragePath, 'utf8'));

// Track files with coverage under 60%
const lowCoverageFiles = [];

// Analyze each file's coverage
Object.entries(coverageData).forEach(([filePath, fileData]) => {
  // Skip if it's not a file or has no coverage data
  if (!fileData || typeof fileData.lines === 'undefined') return;

  const lineCoverage = fileData.lines.pct;
  const fnCoverage = fileData.functions.pct;
  const branchCoverage = fileData.branches.pct;
  const statementCoverage = fileData.statements.pct;

  // Skip if all coverage is 100% or the file has no coverage
  if (lineCoverage === 100 && fnCoverage === 100 && branchCoverage === 100 && statementCoverage === 100) return;

  // Calculate overall coverage (simple average)
  const overallCoverage = (lineCoverage + fnCoverage + branchCoverage + statementCoverage) / 4;

  if (overallCoverage < 60) {
    lowCoverageFiles.push({
      path: filePath,
      lineCoverage,
      fnCoverage,
      branchCoverage,
      statementCoverage,
      overallCoverage: Math.round(overallCoverage)
    });
  }
});

// Sort by lowest coverage first
lowCoverageFiles.sort((a, b) => a.overallCoverage - b.overallCoverage);

// Output results
console.log('\n=== Files with Coverage < 60% ===');
console.log(`Found ${lowCoverageFiles.length} files with coverage < 60%\n`);

if (lowCoverageFiles.length > 0) {
  console.log('Lowest coverage files:');
  lowCoverageFiles.slice(0, 10).forEach((file, index) => {
    console.log(`${index + 1}. ${file.path}`);
    console.log(`   Line: ${file.lineCoverage}% | Function: ${file.fnCoverage}% | Branch: ${file.branchCoverage}% | Statement: ${file.statement}%`);
    console.log(`   Overall: ${file.overallCoverage}%\n`);
  });

  // The lowest coverage file
  const lowestCoverageFile = lowCoverageFiles[0];
  console.log(`\n🎯 TARGET FILE for test improvement:`);
  console.log(`   ${lowestCoverageFile.path}`);
  console.log(`   Overall coverage: ${lowestCoverageFile.overallCoverage}%\n`);

  // Write to a simple output file
  fs.writeFileSync('./coverage-analysis-result.txt', JSON.stringify(lowestCoverageFile, null, 2));
  console.log('✅ Analysis complete. Results saved to coverage-analysis-result.txt');
} else {
  console.log('🎉 No files found with coverage < 60%!');

  // Look for TODO/FIXME comments instead
  console.log('\n🔍 Checking for TODO/FIXME comments in source files...');
  const sourceDir = './src';
  if (fs.existsSync(sourceDir)) {
    const allFiles = [];

    // Recursive function to find all .ts files
    function findFiles(dir) {
      const files = fs.readdirSync(dir);
      files.forEach(file => {
        const fullPath = path.join(dir, file);
        if (fs.statSync(fullPath).isDirectory()) {
          findFiles(fullPath);
        } else if (file.endsWith('.ts')) {
          allFiles.push(fullPath);
        }
      });
    }

    findFiles(sourceDir);

    const todos = [];
    allFiles.forEach(filePath => {
      const content = fs.readFileSync(filePath, 'utf8');
      const lines = content.split('\n');
      lines.forEach((line, index) => {
        if (line.includes('TODO') || line.includes('FIXME')) {
          todos.push({
            file: filePath,
            line: index + 1,
            content: line.trim()
          });
        }
      });
    });

    if (todos.length > 0) {
      console.log(`\nFound ${todos.length} TODO/FIXME comments:`);
      todos.forEach(todo => {
        console.log(`\n${todo.file}:${todo.line}`);
        console.log(`  ${todo.content}`);
      });
    } else {
      console.log('No TODO/FIXME comments found.');
    }
  }
}