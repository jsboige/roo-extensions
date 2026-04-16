// Debug block separation
const content = [
    '## ⏳ Décision',
    '',
    '**ID:** `DEC-001`',
    '**Statut:** `pending`',
    '**Créée le:** `2025-01-15`',
    '',
    '## ✅ Décision',
    '',
    '**ID:** `DEC-002`',
    '**Statut:** `approved`',
    '**Approuvé le:** 2026-02-20',
].join('\n');

console.log('Content with extra blank line:');
console.log(content);

console.log('\n=== SEPARATE BLOCKS APPROACH ===');
// Split into blocks using the headers
const blockRegex = /## (?:⏳|✅|❌) Décision\n\n/g;
const parts = content.split(blockRegex);
console.log('Parts after split:', parts);

// The first part is empty, the rest are blocks
for (let i = 1; i < parts.length; i++) {
    const blockContent = parts[i];
    console.log(`\n--- Block ${i} ---`);
    console.log('Content:', JSON.stringify(blockContent));

    // Extract ID and Status
    const idMatch = blockContent.match(/\*\*ID:\*\* `([^`]+)`/);
    const statusMatch = blockContent.match(/\*\*Statut:\*\* `([^`]+)`/);

    console.log('ID:', idMatch ? idMatch[1] : 'Not found');
    console.log('Status:', statusMatch ? statusMatch[1] : 'Not found');

    if (statusMatch && statusMatch[1] === 'pending') {
        console.log('-> PENDING decision');
    } else if (statusMatch && statusMatch[1] === 'approved') {
        console.log('-> APPROVED decision');
    }
}

console.log('\n=== ALTERNATIVE: Using matchAll with proper boundaries ===');
// Try to capture each block separately
const blockPattern = /## (⏳|✅|❌) Décision\n\n((?:[^\n]|\n(?!## ))+)/g;
let match;
let count = 0;

while ((match = blockPattern.exec(content)) !== null) {
    count++;
    console.log(`\n--- Block Match ${count} ---`);
    console.log('Type:', match[1]);
    console.log('Content:', JSON.stringify(match[2]));

    const idMatch = match[2].match(/\*\*ID:\*\* `([^`]+)`/);
    const statusMatch = match[2].match(/\*\*Statut:\*\* `([^`]+)`/);

    console.log('ID:', idMatch ? idMatch[1] : 'Not found');
    console.log('Status:', statusMatch ? statusMatch[1] : 'Not found');
}
console.log(`\nTotal block matches: ${count}`);