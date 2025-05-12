/**
 * Fonction de calcul du prix total avec taxes
 * @param {number} prixHT - Prix hors taxes
 * @param {number} tauxTVA - Taux de TVA (par défaut: 0.20 pour 20%)
 * @returns {number} - Prix total TTC arrondi à 2 décimales
 */
function calculerPrixTTC(prixHT, tauxTVA = 0.20) {
    // Validation des entrées
    if (typeof prixHT !== 'number' || prixHT < 0) {
        throw new Error('Le prix HT doit être un nombre positif');
    }
    
    if (typeof tauxTVA !== 'number' || tauxTVA < 0) {
        throw new Error('Le taux de TVA doit être un nombre positif');
    }
    
    // Calcul du prix TTC
    const prixTTC = prixHT * (1 + tauxTVA);
    
    // Arrondi à 2 décimales
    return Math.round(prixTTC * 100) / 100;
}

/**
 * Fonction pour appliquer une remise sur un prix
 * @param {number} prix - Prix initial
 * @param {number} pourcentageRemise - Pourcentage de remise (entre 0 et 100)
 * @returns {number} - Prix après remise
 */
function appliquerRemise(prix, pourcentageRemise) {
    // Validation des entrées
    if (typeof prix !== 'number' || prix < 0) {
        throw new Error('Le prix doit être un nombre positif');
    }
    
    if (typeof pourcentageRemise !== 'number' || pourcentageRemise < 0 || pourcentageRemise > 100) {
        throw new Error('Le pourcentage de remise doit être un nombre entre 0 et 100');
    }
    
    // Conversion du pourcentage en décimal
    const remiseDecimal = pourcentageRemise / 100;
    
    // Calcul du prix après remise
    return prix * (1 - remiseDecimal);
}

// Exemple d'utilisation
const prixArticle = 49.99;
const prixAvecRemise = appliquerRemise(prixArticle, 10);
const prixFinal = calculerPrixTTC(prixAvecRemise);

console.log(`Prix initial: ${prixArticle}€`);
console.log(`Prix avec remise: ${prixAvecRemise}€`);
console.log(`Prix final TTC: ${prixFinal}€`);