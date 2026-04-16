// Debug the actual regex issue
const block = "**ID:** `DEC-001`\n**Statut:** `Pending`\n**Créée le:** `2025-01-15`\n";

console.log('\n=== RAW BLOCK ===');
console.log(JSON.stringify(block));

console.log('\n=== REGEX TESTS ===');
const regex1 = /\*\*Statut\*\*: `(\w+)`/;
console.log('Regex 1 (\\w+):', regex1.test(block), block.match(regex1));

const regex2 = /\*\*Statut\*\*: `([^`]+)`/;
console.log('Regex 2 ([^`]+):', regex2.test(block), block.match(regex2));

const regex3 = /\*\*Statut:\*\* `([^`]+)`/;
console.log('Regex 3 (single star after Statut):', regex3.test(block), block.match(regex3));

console.log('\n=== CHARACTER ANALYSIS ===');
const str = "**Statut:** `Pending`";
for (let i = 0; i < str.length; i++) {
  console.log(`${i}: "${str[i]}" (${str.charCodeAt(i)})`);
}