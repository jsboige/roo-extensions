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