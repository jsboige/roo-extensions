// Test du mécanisme d'escalade pour les modes personnalisés
// Ce script teste le mécanisme d'escalade interne et externe

console.log("=== Test du mécanisme d'escalade ===");

// Simulation d'une tâche simple qui devrait être traitée par un mode simple
const simpleTask = {
  description: "Corriger une erreur de syntaxe dans un fichier JavaScript",
  complexity: "simple",
  expectedMode: "code-simple"
};

// Simulation d'une tâche complexe qui devrait déclencher une escalade
const complexTask = {
  description: "Refactoriser l'architecture complète d'une application React avec optimisation des performances",
  complexity: "complex",
  expectedMode: "code-complex",
  shouldEscalate: true
};

// Simulation d'une tâche à la limite qui pourrait déclencher une escalade interne
const borderlineTask = {
  description: "Implémenter une fonction de tri personnalisée avec quelques optimisations",
  complexity: "borderline",
  expectedMode: "code-simple",
  mightEscalateInternally: true
};

// Fonction de test
function testEscalation(task) {
  console.log(`\nTest de la tâche: ${task.description}`);
  console.log(`Complexité: ${task.complexity}`);
  console.log(`Mode attendu: ${task.expectedMode}`);
  
  if (task.shouldEscalate) {
    console.log("Cette tâche devrait déclencher une escalade externe");
  } else if (task.mightEscalateInternally) {
    console.log("Cette tâche pourrait déclencher une escalade interne");
  } else {
    console.log("Cette tâche devrait être traitée sans escalade");
  }
}

// Exécution des tests
console.log("\n=== Exécution des tests d'escalade ===");
testEscalation(simpleTask);
testEscalation(complexTask);
testEscalation(borderlineTask);

console.log("\n=== Tests terminés ===");
console.log("Pour des tests complets, utilisez ces scénarios avec l'extension Roo dans VS Code");