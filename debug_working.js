// Create working regex test
const block = "**ID:** `DEC-001`\n**Statut:** `Pending`\n";
console.log('Block:', JSON.stringify(block));

// Create simple test - FIXED STRING
const testString = "**Statut:** `Pending`";
console.log('\nTest string:', JSON.stringify(testString));

// Show character codes
console.log('\nCharacter codes for testString:');
for (let i = 0; i < testString.length; i++) {
  console.log(`${i}: "${testString[i]}" (${testString.charCodeAt(i)})`);
}

// Working version - properly escaped
const workingPattern = /\*\*Statut\*\*: `([^`]+)`/;
console.log('\nWorking pattern:', workingPattern.source);
console.log('Working pattern test:', workingPattern.test(testString));
console.log('Working match:', testString.match(workingPattern));

// Test with single character class
const simplePattern = /\*\*Statut\*\*: `(\w+)`/;
console.log('\nSimple pattern test:', simplePattern.test(testString));
console.log('Simple match:', testString.match(simplePattern));

// Test field by field
console.log('\n=== FIELD BY FIELD ===');
const fieldPattern = /\*\*Statut\*\*:/;
console.log('Field pattern:', fieldPattern.test(testString));

const valuePattern = /`(\w+)`/;
console.log('Value pattern:', valuePattern.test(testString));