// Test du mécanisme de désescalade pour les modes personnalisés
// Ce script teste le mécanisme de désescalade systématique

console.log("=== Test du mécanisme de désescalade ===");

// Simulation d'une tâche initialement complexe qui devient simple
const simplifiableTask = {
  description: "Analyser une architecture complexe puis documenter un composant simple",
  initialComplexity: "complex",
  finalComplexity: "simple",
  initialMode: "code-complex",
  finalMode: "code-simple",
  shouldDesescalate: true
};

// Simulation d'une tâche qui reste complexe
const persistentlyComplexTask = {
  description: "Optimiser les performances d'une application distribuée",
  initialComplexity: "complex",
  finalComplexity: "complex",
  initialMode: "code-complex",
  finalMode: "code-complex",
  shouldDesescalate: false
};

// Simulation d'une tâche qui commence simple et reste simple
const simpleTask = {
  description: "Corriger une erreur de syntaxe dans un fichier CSS",
  initialComplexity: "simple",
  finalComplexity: "simple",
  initialMode: "code-simple",
  finalMode: "code-simple",
  shouldDesescalate: false
};

// Fonction de test
function testDesescalation(task) {
  console.log(`\nTest de la tâche: ${task.description}`);
  console.log(`Complexité initiale: ${task.initialComplexity}`);
  console.log(`Mode initial: ${task.initialMode}`);
  console.log(`Complexité finale: ${task.finalComplexity}`);
  console.log(`Mode final attendu: ${task.finalMode}`);
  
  if (task.shouldDesescalate) {
    console.log("Cette tâche devrait déclencher une désescalade");
  } else {
    console.log("Cette tâche ne devrait pas déclencher de désescalade");
  }
}

// Exécution des tests
console.log("\n=== Exécution des tests de désescalade ===");
testDesescalation(simplifiableTask);
testDesescalation(persistentlyComplexTask);
testDesescalation(simpleTask);

console.log("\n=== Tests terminés ===");
console.log("Pour des tests complets, utilisez ces scénarios avec l'extension Roo dans VS Code");