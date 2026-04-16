// Debug the regex matching
const content = [
    '## ⏳ Décision',
    '',
    '**ID:** `DEC-001`',
    '**Statut:** `pending`',
    '**Créée le:** `2025-01-15`',
    '## ✅ Décision',
    '',
    '**ID:** `DEC-002`',
    '**Statut:** `approved`',
    '**Approuvé le:** 2026-02-20',
].join('\n');

console.log('\n=== CONTENT ===');
console.log(JSON.stringify(content));
console.log('\n=== CONTENT (visible) ===');
console.log(content);
console.log('\n=== REGEX TEST ===');

const regex = /^## (?:⏳|✅|❌) Décision\n\n([\s\S]*?)(?=\n\n^##(?: ⏳| ✅| ❌) Décision|\n\n---|$)/gm;
let match;
let count = 0;

while ((match = regex.exec(content)) !== null) {
    count++;
    console.log(`\n--- Match ${count} ---`);
    console.log('Index:', match.index);
    console.log('Full match:', JSON.stringify(match[0]));
    console.log('Captured group:', JSON.stringify(match[1]));
    console.log('NextIndex:', regex.lastIndex);
}

console.log(`\nTotal matches: ${count}`);

console.log('\n=== TESTING SIMPLER PATTERN ===');
// Even simpler pattern without multiline assertions
const simpleRegex = /## (?:⏳|✅|❌) Décision\n\n([\s\S]*?)(?=\n\n## |---)/gm;
let simpleMatch;
let simpleCount = 0;

while ((simpleMatch = simpleRegex.exec(content)) !== null) {
    simpleCount++;
    console.log(`\nSimple Match ${simpleCount}:`);
    console.log('Full match:', JSON.stringify(simpleMatch[0]));
    console.log('Captured group:', JSON.stringify(simpleMatch[1]));
    console.log('Has Statut:', simpleMatch[1].includes('**Statut:**'));
    console.log('Statut value:', simpleMatch[1].match(/\*\*Statut:\*\* `(.+?)`/)?.[1] || 'Not found');
}
console.log(`\nTotal simple matches: ${simpleCount}`);

console.log('\n=== MANUAL SPLIT APPROACH ===');
// Split approach to understand the structure
const sections = content.split('\n\n## ')[1]; // Remove first part
console.log('Split result:', JSON.stringify(sections));

// Add back the first header
const firstSection = '## ⏳ Décision\n\n' + sections.split('\n\n## ')[0];
console.log('\nFirst section:', JSON.stringify(firstSection));