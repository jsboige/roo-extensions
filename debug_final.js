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
console.log(content);

console.log('\n=== WORKING REGEX ===');
// Working regex that captures full content
const workingRegex = /## (?:⏳|✅|❌) Décision\n\n([\s\S]*?)(?=\n\n##(?: ⏳| ✅| ❌) Décision|\n\n---|$)/g;
let match;
let count = 0;

while ((match = workingRegex.exec(content)) !== null) {
    count++;
    console.log(`\n--- Match ${count} ---`);
    console.log('Full match length:', match[0].length);
    console.log('Captured group:', JSON.stringify(match[1]));
    console.log('Has Statut:', match[1].includes('**Statut:**'));
    console.log('Statut value:', match[1].match(/\*\*Statut:\*\* `(.+?)`/)?.[1] || 'Not found');

    // Test ID extraction
    const idMatch = match[1].match(/\*\*ID:\*\* `([^`]+)`/);
    console.log('ID value:', idMatch ? idMatch[1] : 'Not found');
}
console.log(`\nTotal matches: ${count}`);

console.log('\n=== TESTING ON ACTUAL CODE FORMAT ===');
// Test with the exact format from the test file
const testContent = [
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

const testRegex = /## (?:⏳|✅|❌) Décision\n\n([\s\S]*?)(?=\n\n##(?: ⏳| ✅| ❌) Décision|\n\n---|$)/g;
count = 0;
while ((match = testRegex.exec(testContent)) !== null) {
    count++;
    console.log(`\nTest Match ${count}:`);
    console.log('Captured:', JSON.stringify(match[1]));

    const statusMatch = match[1].match(/\*\*Statut:\*\* `([^`]+)`/);
    if (statusMatch) {
        console.log('Status:', statusMatch[1]);
        if (statusMatch[1] === 'pending') {
            console.log('-> This is a pending decision!');
        } else if (statusMatch[1] === 'approved') {
            console.log('-> This is an approved decision!');
        }
    }
}
console.log(`\nTotal test matches: ${count}`);