/**
 * Fonction qui calcule la somme de deux nombres
 * @param {number} a - Premier nombre
 * @param {number} b - Deuxième nombre
 * @returns {number} - La somme des deux nombres
 */
function additionner(a, b) {
    return a + b;
}

/**
 * Fonction qui calcule la différence entre deux nombres
 * @param {number} a - Premier nombre
 * @param {number} b - Deuxième nombre
 * @returns {number} - La différence entre les deux nombres
 */
function soustraire(a, b) {
    return a - b;
} // Correction : point-virgule ajouté

/**
 * Fonction qui multiplie deux nombres
 * @param {number} a - Premier nombre
 * @param {number} b - Deuxième nombre
 * @returns {number} - Le produit des deux nombres
 */
function multiplier(a, b) {
    return a * b;
}

// Exemple d'utilisation
const nombre1 = 10;
const nombre2 = 5;

console.log(`Addition: ${additionner(nombre1, nombre2)}`);
console.log(`Soustraction: ${soustraire(nombre1, nombre2)}`);
console.log(`Multiplication: ${multiplier(nombre1, nombre2)}`);