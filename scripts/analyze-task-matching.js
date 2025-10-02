const fs = require('fs');
const path = require('path');

// Chemins des fichiers
const parentFile = path.join(__dirname, '..', 'exports', 'ui-snippets', 'ac8aa7b4-319c-4925-a139-4f4adca81921-head.txt');
const childFile = path.join(__dirname, '..', 'exports', 'ui-snippets', 'bc93a6f7-cd2e-4686-a832-46e3cd14d338-head.txt');

console.log('=== ANALYSE MATCHING PARENT-ENFANT ===\n');

// Lire l'enfant
const childContent = fs.readFileSync(childFile, 'utf8');
const childJson = JSON.parse(childContent);

let childInstruction = '';
for (const msg of childJson) {
    if (msg.type === 'say' && msg.say === 'text' && msg.text) {
        childInstruction = msg.text;
        break;
    }
}

console.log('=== INSTRUCTION ENFANT bc93a6f7 (192 premiers chars) ===');
const childPrefix = childInstruction.substring(0, Math.min(192, childInstruction.length));
console.log(childPrefix);
console.log('');

// Lire le parent
const parentContent = fs.readFileSync(parentFile, 'utf8');
const parentJson = JSON.parse(parentContent);

console.log('=== RECHERCHE <new_task> dans PARENT ac8aa7b4 ===');
let newTaskCount = 0;
let matchFound = false;

for (const msg of parentJson) {
    if (msg.text && msg.text.includes('<new_task>')) {
        newTaskCount++;
        
        // Extraire le contenu après <new_task>
        const match = msg.text.match(/<new_task>\s*(.+?)(\s*<|$)/s);
        if (match) {
            const taskContent = match[1].trim();
            const taskPrefix = taskContent.substring(0, Math.min(192, taskContent.length));
            
            console.log(`\nNEW_TASK #${newTaskCount} (192 premiers chars):`);
            console.log(taskPrefix);
            
            // Tester si l'instruction enfant commence par ce préfixe
            if (childInstruction.startsWith(taskContent.substring(0, Math.min(taskContent.length, childInstruction.length)))) {
                console.log('✓ MATCH POTENTIEL!');
                matchFound = true;
            }
        }
    }
}

console.log(`\n=== RÉSULTAT ===`);
console.log(`Total <new_task> trouvés: ${newTaskCount}`);
console.log(`Match trouvé: ${matchFound ? 'OUI' : 'NON'}`);