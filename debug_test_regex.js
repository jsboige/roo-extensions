// Test the regex pattern from analyze_problems.ts
const content = [
    makeDecisionBlock('DEC-001', 'Pending'),
    makeDecisionBlock('DEC-002', 'Approved', '**Approuvé le:** 2025-01-15'),
    makeDecisionBlock('DEC-003', 'Pending'),
    '## ⏳ Décision\n\n**ID:** `DEC-004`\n**Statut:** `Approved`\n**Approuvé le:** 2025-01-16'
].join('\n\n');

console.log('Full content:');
console.log(content);
console.log('\n---\n');

// Regex from the current implementation
const blockRegex = /## ⏳ Décision\n\n([\s\S]*?)(?=\n\n## ⏳ Décision|\n\n## ✅ Décision|\n\n## ❌ Décision|\n\n---|$)/g;

const matches = [...content.matchAll(blockRegex)];
console.log('Number of matches:', matches.length);
matches.forEach((match, i) => {
    console.log(`\nMatch ${i+1}:`);
    console.log('Full match:', JSON.stringify(match[0]));
    console.log('Content:', match[1].trim());
});

// Helper function
function makeDecisionBlock(id, status, extras = '') {
    return `## ⏳ Décision

**ID:** \`${id}\`
**Statut:** \`${status}\`
${extras}`;
}