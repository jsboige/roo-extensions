const block = "**ID:** `DEC-001`\n**Statut:** `Pending`\n";
console.log('Block with JSON:', JSON.stringify(block));

console.log('Block:', JSON.stringify(block));

// Test the regex pattern
// Test character code for asterisk
console.log('Asterisk code:', '*'.charCodeAt(0));

// Test regex with exact characters from string
const exactPattern = /\*\*Statut\*\*: `(\w+)`/;
console.log('Exact pattern:', exactPattern.source);
console.log('Exact pattern test:', exactPattern.test(block));

// Show string range
console.log('\n=== STRING RANGE ===');
console.log('Block.slice(18, 35):', JSON.stringify(block.slice(18, 35)));
console.log('Expected range JSON:', JSON.stringify("**Statut:** `Pending`"));

// Test simple parts
console.log('\n=== TESTING SIMPLE PARTS ===');
const statutPattern = /Statut/;
console.log('Statut test:', statutPattern.test(block));

const doubleStarPattern = /\*\*/;
console.log('Double star test:', doubleStarPattern.test(block));

// Test one character at a time
console.log('\n=== TESTING INDIVIDUAL CHARACTERS ===');
const pattern1 = /\*/;
console.log('Pattern * matches:', pattern1.test(block));

const pattern2 = /\*{2}/;
console.log('Pattern ** matches:', pattern2.test(block));

// Try with different patterns
const statusMatch2 = block.match(/\*\*Statut\*\*: `([^`]+)`/);
console.log('Status match (non-greedy):', statusMatch2);

// Test character by character
console.log('\n=== DEBUG CHARACTER BY CHARACTER ===');
for (let i = 0; i < block.length; i++) {
  console.log(`${i}: "${block[i]}" (${block.charCodeAt(i)})`);
}

// Test exact string (already defined above)

// Test Unicode normalization
console.log('\n=== DEBUG UNICODE ===');
const normalizedBlock = block.replace(/\n/g, '\\n').replace(/`/g, '`');
console.log('Normalized block:', normalizedBlock);

// Test with raw string
console.log('\n=== RAW STRING TEST ===');
const rawString = "**ID:** `DEC-001`\n**Statut:** `Pending`";
console.log('Raw string:', JSON.stringify(rawString));
const rawMatch = rawString.match(/\*\*Statut\*\*: `(\w+)`/);
console.log('Raw match:', rawMatch);

// Test field extraction
console.log('\n=== DEBUG FIELD EXTRACTION ===');
const fieldMatch = block.match(/\*\*Statut\*\*: `(.*)`/);
console.log('Field match:', fieldMatch);

// Try with raw content
const rawContent = `**ID:** \`DEC-001\`
**Statut:** \`Pending\`;`;

console.log('\nRaw content:', JSON.stringify(rawContent));
const statusMatch3 = rawContent.match(/\*\*Statut\*\*: `(\w+)`/);
console.log('Status match (raw):', statusMatch3);

const statusMatch4 = rawContent.match(/\*\*Statut\*\*: `([^`]+)`/);
console.log('Status match (raw, non-greedy):', statusMatch4);