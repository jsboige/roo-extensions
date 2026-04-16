// CORRECTED DEBUG - The issue is clear now
const block = "**ID:** `DEC-001`\n**Statut:** `Pending`\n";
console.log('Block:', JSON.stringify(block));

// The issue is with the colon after Statut - let's check
console.log('\n=== COLON DEBUG ===');
const colonTest = /\*\*Statut:/;
console.log('**Statut: test:', colonTest.test(block));

const colonTest2 = /\*\*Statut\*:/;
console.log('**Statut*: test:', colonTest2.test(block));

const colonTest3 = /\*\*Statut\*\*:/;
console.log('**Statut**: test:', colonTest3.test(block));

// Check the character right after Statut
console.log('\nCharacter after "Statut":', JSON.stringify(block[7]));
console.log('Character code:', block.charCodeAt(7));

// The problem is that the pattern expects asterisks after Statut, but there's only one
console.log('\n=== SHOW THE ACTUAL PATTERN ===');
const fieldMatch = block.match(/\*\*Statut[^\n]*/);
console.log('Field match:', fieldMatch);

const correctPattern = /\*\*Statut\*\*: `([^`]+)`/;
console.log('\nCorrect pattern test:', correctPattern.test(block));
console.log('Correct pattern match:', block.match(correctPattern));

// Test with just **Statut (without the extra asterisk)
const actualPattern = /\*\*Statut\*\*: `([^`]+)`/;
console.log('\nActual pattern test:', actualPattern.test(block));
console.log('Actual pattern match:', block.match(actualPattern));

// Wait, let me check what's actually there
const statutMatch = block.match(/\*\*Statut.*\n/);
console.log('\nStatut field with newline:', statutMatch);