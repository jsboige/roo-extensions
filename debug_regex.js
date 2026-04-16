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

const regex = /## (?:⏳|✅|❌) Décision\n\n([\s\S]*?)(?=\n\n(?:## ⏳ Décision|## ✅ Décision|## ❌ Décision)|---|$)/g;
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

// Test with different patterns
console.log('\n=== TESTING INDIVIDUAL PATTERNS ===');
const patterns = [
    /## ⏳ Décision\n\n([\s\S]*?)(?=\n\n(?:## ⏳ Décision|## ✅ Décision|## ❌ Décision)|---|$)/g,
    /## ✅ Décision\n\n([\s\S]*?)(?=\n\n(?:## ⏳ Décision|## ✅ Décision|## ❌ Décision)|---|$)/g,
    /## (?:⏳|✅|❌) Décision\n\n([\s\S]*?)(?=\n\n(?:## ⏳ Décision|## ✅ Décision|## ❌ Décision)|---|$)/g
];

patterns.forEach((pattern, i) => {
    console.log(`\nPattern ${i + 1}: ${pattern}`);
    regex.lastIndex = 0; // Reset
    count = 0;
    while ((match = pattern.exec(content)) !== null) {
        count++;
        console.log(`  Match ${count}: ${JSON.stringify(match[1]).substring(0, 50)}...`);
    }
    console.log(`  Total: ${count}`);
});