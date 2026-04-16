// Test status extraction regex
const block = `**ID:** \`DEC-001\`
**Statut:** \`Pending\`;

**ID:** \`DEC-002\`
**Statut:** \`Approved\`
**Approuvé le:** 2025-01-15`;

console.log('Block:', JSON.stringify(block));

const statusMatch = block.match(/\*\*Statut\*\*: `(\w+)`/);
console.log('Status match:', statusMatch);

if (statusMatch) {
    console.log('Status:', statusMatch[1].toLowerCase());
} else {
    console.log('No status match found');
}