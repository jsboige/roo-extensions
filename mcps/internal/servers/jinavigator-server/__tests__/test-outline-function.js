/**
 * Test unitaire pour la fonction extractMarkdownOutline
 * 
 * Ce script teste directement la fonction extractMarkdownOutline
 * sans passer par le serveur MCP.
 */

// Fonction à tester (copie de l'implémentation)
function extractMarkdownOutline(markdownContent, maxDepth = 3) {
  const lines = markdownContent.split('\n');
  const flatHeadings = [];
  
  // Expression régulière pour détecter les titres markdown (# Titre)
  const headingRegex = /^(#{1,6})\s+(.+)$/;
  
  // Première passe : extraire tous les titres jusqu'au niveau maxDepth
  lines.forEach((line, index) => {
    const match = line.match(headingRegex);
    if (match) {
      const level = match[1].length; // Nombre de # = niveau du titre
      const text = match[2].trim();  // Texte du titre sans les # et espaces
      
      // Ne garder que les titres jusqu'au niveau maxDepth
      if (level <= maxDepth) {
        flatHeadings.push({
          level,
          text,
          line: index + 1 // Les numéros de ligne commencent à 1
        });
      }
    }
  });
  
  // Deuxième passe : construire la structure hiérarchique
  const rootHeadings = [];
  const headingStack = [];
  
  flatHeadings.forEach(heading => {
    // Vider la pile jusqu'à trouver un parent approprié
    while (
      headingStack.length > 0 && 
      headingStack[headingStack.length - 1].level >= heading.level
    ) {
      headingStack.pop();
    }
    
    // Si la pile est vide, c'est un titre racine
    if (headingStack.length === 0) {
      rootHeadings.push(heading);
    } else {
      // Sinon, c'est un enfant du dernier titre dans la pile
      const parent = headingStack[headingStack.length - 1];
      if (!parent.children) {
        parent.children = [];
      }
      parent.children.push(heading);
    }
    
    // Ajouter le titre courant à la pile
    headingStack.push(heading);
  });
  
  return rootHeadings;
}

// Exemple de contenu Markdown pour le test
const testMarkdown = `# Titre principal 1
Contenu du titre principal 1

## Sous-titre 1.1
Contenu du sous-titre 1.1

### Sous-sous-titre 1.1.1
Contenu du sous-sous-titre 1.1.1

## Sous-titre 1.2
Contenu du sous-titre 1.2

# Titre principal 2
Contenu du titre principal 2

## Sous-titre 2.1
Contenu du sous-titre 2.1
`;

// Exécution du test
console.log("Test de la fonction extractMarkdownOutline");
console.log("------------------------------------------");

// Test avec maxDepth = 1 (uniquement les titres H1)
console.log("\nTest avec maxDepth = 1 (uniquement les titres H1):");
const outlineDepth1 = extractMarkdownOutline(testMarkdown, 1);
console.log(JSON.stringify(outlineDepth1, null, 2));

// Test avec maxDepth = 2 (titres H1 et H2)
console.log("\nTest avec maxDepth = 2 (titres H1 et H2):");
const outlineDepth2 = extractMarkdownOutline(testMarkdown, 2);
console.log(JSON.stringify(outlineDepth2, null, 2));

// Test avec maxDepth = 3 (titres H1, H2 et H3)
console.log("\nTest avec maxDepth = 3 (titres H1, H2 et H3):");
const outlineDepth3 = extractMarkdownOutline(testMarkdown, 3);
console.log(JSON.stringify(outlineDepth3, null, 2));

// Vérification de la structure hiérarchique
console.log("\nVérification de la structure hiérarchique:");
if (outlineDepth3.length === 2 && 
    outlineDepth3[0].children && 
    outlineDepth3[0].children.length === 2 &&
    outlineDepth3[0].children[0].children &&
    outlineDepth3[0].children[0].children.length === 1) {
  console.log("✅ La structure hiérarchique est correcte");
} else {
  console.log("❌ La structure hiérarchique est incorrecte");
}

// Vérification des niveaux de titres
console.log("\nVérification des niveaux de titres:");
if (outlineDepth3[0].level === 1 && 
    outlineDepth3[0].children[0].level === 2 &&
    outlineDepth3[0].children[0].children[0].level === 3) {
  console.log("✅ Les niveaux de titres sont corrects");
} else {
  console.log("❌ Les niveaux de titres sont incorrects");
}

// Vérification des numéros de ligne
console.log("\nVérification des numéros de ligne:");
if (outlineDepth3[0].line === 1 && 
    outlineDepth3[0].children[0].line === 4 &&
    outlineDepth3[0].children[0].children[0].line === 7) {
  console.log("✅ Les numéros de ligne sont corrects");
} else {
  console.log("❌ Les numéros de ligne sont incorrects");
  console.log(`Ligne du titre principal: ${outlineDepth3[0].line} (attendu: 1)`);
  console.log(`Ligne du sous-titre: ${outlineDepth3[0].children[0].line} (attendu: 4)`);
  console.log(`Ligne du sous-sous-titre: ${outlineDepth3[0].children[0].children[0].line} (attendu: 7)`);
}

console.log("\nTest terminé");