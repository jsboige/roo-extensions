/**
 * Validation tests for skepticism protocol rules
 * Issue #567 - Section 5
 * 
 * Tests structure and presence, not logic.
 */

const fs = require('fs');
const path = require('path');

const PROJECT_ROOT = path.resolve(__dirname, '..');

// Test 1: Files exist
function testFilesExist() {
  const claudeRules = path.join(PROJECT_ROOT, '.claude/rules/skepticism-protocol.md');
  const rooRules = path.join(PROJECT_ROOT, '.roo/rules/skepticism-protocol.md');
  
  const claudeExists = fs.existsSync(claudeRules);
  const rooExists = fs.existsSync(rooRules);
  
  console.log(`✓ Claude rules exist: ${claudeExists}`);
  console.log(`✓ Roo rules exist: ${rooExists}`);
  
  if (!claudeExists || !rooExists) {
    throw new Error('Missing skepticism protocol files');
  }
  
  return { claudeRules, rooRules };
}

// Test 2: Files have proper format (version, sections)
function testFileFormat(filePath, label) {
  const content = fs.readFileSync(filePath, 'utf8');
  
  // Check for version header
  const hasVersion = /\*\*Version:\*\*\s*\d+\.\d+\.\d+/.test(content);
  console.log(`✓ ${label} has version header: ${hasVersion}`);
  
  // Check for principle section
  const hasPrinciple = /##\s*Principe/.test(content);
  console.log(`✓ ${label} has principle section: ${hasPrinciple}`);
  
  // Check for verification triggers (Smell Test)
  const hasSmellTest = /Smell Test|Declencheur|PAUSE/.test(content);
  console.log(`✓ ${label} has smell test section: ${hasSmellTest}`);
  
  if (!hasVersion || !hasPrinciple || !hasSmellTest) {
    throw new Error(`${label} missing required sections`);
  }
  
  return content;
}

// Test 3: Referenced files exist (Claude version references other files)
function testReferencedFiles(claudeContent) {
  const referencedFiles = [
    '.claude/rules/tool-availability.md',
    '.claude/rules/myia-web1-constraints.md',
    'CLAUDE.md'
  ];
  
  let allExist = true;
  for (const refFile of referencedFiles) {
    const fullPath = path.join(PROJECT_ROOT, refFile);
    const exists = fs.existsSync(fullPath);
    // Only fail if the file is explicitly referenced in the content
    if (claudeContent.includes(refFile) && !exists) {
      console.log(`✗ Referenced file missing: ${refFile}`);
      allExist = false;
    } else if (exists) {
      console.log(`✓ Referenced file exists: ${refFile}`);
    }
  }
  
  if (!allExist) {
    throw new Error('Some referenced files are missing');
  }
}

// Test 4: Coherence between Claude and Roo versions
function testCoherence(claudeContent, rooContent) {
  // Both should have the same version
  const claudeVersion = claudeContent.match(/\*\*Version:\*\*\s*(\d+\.\d+\.\d+)/)?.[1];
  const rooVersion = rooContent.match(/\*\*Version:\*\*\s*(\d+\.\d+\.\d+)/)?.[1];
  
  console.log(`✓ Claude version: ${claudeVersion}`);
  console.log(`✓ Roo version: ${rooVersion}`);
  
  if (claudeVersion !== rooVersion) {
    console.log(`⚠ Version mismatch: Claude=${claudeVersion}, Roo=${rooVersion}`);
  }
  
  // Roo version should be simpler (shorter)
  const claudeLines = claudeContent.split('\n').length;
  const rooLines = rooContent.split('\n').length;
  
  console.log(`✓ Claude lines: ${claudeLines}`);
  console.log(`✓ Roo lines: ${rooLines}`);
  
  if (rooLines > claudeLines) {
    console.log(`⚠ Roo version is longer than Claude version (expected shorter)`);
  }
  
  return true;
}

// Main test runner
function runTests() {
  console.log('=== Skepticism Protocol Validation Tests ===\n');
  
  try {
    console.log('--- Test 1: Files Exist ---');
    const { claudeRules, rooRules } = testFilesExist();
    
    console.log('\n--- Test 2: File Format ---');
    const claudeContent = testFileFormat(claudeRules, 'Claude');
    const rooContent = testFileFormat(rooRules, 'Roo');
    
    console.log('\n--- Test 3: Referenced Files ---');
    testReferencedFiles(claudeContent);
    
    console.log('\n--- Test 4: Coherence ---');
    testCoherence(claudeContent, rooContent);
    
    console.log('\n=== ALL TESTS PASSED ===');
    process.exit(0);
  } catch (error) {
    console.error(`\n❌ TEST FAILED: ${error.message}`);
    process.exit(1);
  }
}

runTests();
