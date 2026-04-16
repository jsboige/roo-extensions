const content = `## ⏳ Décision

**ID:** \`DEC-001\`
**Statut:** \`Pending\`

## ⏳ Décision

**ID:** \`DEC-002\`
**Statut:** \`Approved\`
**Approuvé le:** 2025-01-15

## ⏳ Décision

**ID:** \`DEC-003\`
**Statut:** \`Pending\`

## ⏳ Décision

**ID:** \`DEC-004\`
**Statut:** \`Approved\`
**Approuvé le:** 2025-01-16
`;

console.log('Content:');
console.log(content);

console.log('\n---\n');

const regex = /## ⏳ Décision\n\n([\s\S]*?)(?:\n\n## ⏳ Décision|\n\n## ✅ Décision|\n\n## ❌ Décision|\n\n---|$)/g;
const matches = [...content.matchAll(regex)];
console.log('Matches:', matches.length);
matches.forEach((match, i) => {
    console.log(`Match ${i+1}:`, JSON.stringify(match[0]));
    console.log(`Match ${i+1} content:`, match[1].substring(0, 50));
});