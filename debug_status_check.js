const makeDecisionBlock = (id, status, extras = '') => {
    return `## ⏳ Décision

**ID:** \`${id}\`
**Statut:** \`${status}\`
${extras}`;
};

const content = makeDecisionBlock('DEC-001', 'Approved', '**Créée le:** `2025-01-15`');

console.log('Content:');
console.log(content);

// Regex from the code
const blockRegex = /## ⏳ Décision\n\n([\s\S]*?)(?=\n\n## ⏳ Décision|\n\n## ✅ Décision|\n\n## ❌ Décision|\n\n---|$)/g;

const matches = [...content.matchAll(blockRegex)];
console.log('\nMatches:', matches.length);
matches.forEach((match, i) => {
    console.log(`\nMatch ${i+1}:`, JSON.stringify(match[0]));
    console.log(`Match ${i+1} content:`, match[1]);

    // Check for status
    const statusMatch = match[1].match(/\*\*Statut\*\*: \`(\w+)\`/);
    console.log('Status match:', statusMatch);

    // Check for approval metadata
    const approvalMatch = match[1].match(/\*\*Approuvé le:\*\*/);
    console.log('Approval match:', approvalMatch);

    // Check for creation date
    const creationMatch = match[1].match(/\*\*Créée le:\*\*: \`([^`]+)\`/);
    console.log('Creation match:', creationMatch);
});