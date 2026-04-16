// FINAL DEBUG - Understanding the exact regex issue
const block = "**ID:** `DEC-001`\n**Statut:** `Pending`\n";
console.log('Block:', JSON.stringify(block));

// The issue is with the asterisks - let's see what's happening
const testPattern = /\*\*/;
console.log('\nTest of double asterisk:', testPattern.test(block));
console.log('Match positions:', block.match(/\*\*/g));

// Let's try to match step by step
console.log('\n=== STEP BY STEP MATCHING ===');
const starPattern = /\*/;
console.log('Single asterisk test:', starPattern.test(block));

// Now build the pattern incrementally
const part1 = /\*\*/;
console.log('Part 1 (**) test:', part1.test(block));

const part2 = /\*\*S/;
console.log('Part 2 (**S) test:', part2.test(block));

const part3 = /\*\*Statut/;
console.log('Part 3 (**Statut) test:', part3.test(block));

const part4 = /\*\*Statut\*\*:/;
console.log('Part 4 (**Statut:**) test:', part4.test(block));

const part5 = /\*\*Statut\*\*: `P/;
console.log('Part 5 (**Statut:** `P) test:', part5.test(block));

// The issue might be with the backtick - test that
const backtickPattern = /`/;
console.log('\nBacktick test:', backtickPattern.test(block));

// Let's try the full pattern with escaping
const fullPattern = /\*\*Statut\*\*: `(\w+)`/;
console.log('\nFull pattern test:', fullPattern.test(block));