/**
 * Module de validation de formulaire avec support des formats internationaux
 * 
 * Ce module fournit des fonctions pour valider les formats d'email, 
 * de téléphone et d'adresse selon les standards internationaux.
 */

/**
 * Valide un email selon le format standard RFC 5322
 * @param {string} email - L'email à valider
 * @returns {boolean} - true si l'email est valide, false sinon
 */
function validateEmail(email) {
  // Regex complexe pour validation d'email selon RFC 5322
  const emailRegex = /^(([^<>()\[\]\\.,;:\s@"]+(\.[^<>()\[\]\\.,;:\s@"]+)*)|(".+"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/;
  return emailRegex.test(String(email).toLowerCase());
}

/**
 * Valide un numéro de téléphone international
 * Supporte les formats:
 * - International: +33612345678
 * - Avec espaces: +33 6 12 34 56 78
 * - Avec tirets: +33-6-12-34-56-78
 * - Avec parenthèses: +33(6)12345678
 * 
 * @param {string} phone - Le numéro de téléphone à valider
 * @returns {boolean} - true si le numéro est valide, false sinon
 */
function validatePhone(phone) {
  // Supprime tous les caractères non numériques sauf le +
  const cleanedPhone = phone.replace(/[^\d+]/g, '');
  
  // Vérifie le format international (commence par + suivi d'au moins 7 chiffres)
  if (/^\+\d{7,15}$/.test(cleanedPhone)) {
    return true;
  }
  
  // Vérifie le format national (au moins 7 chiffres)
  if (/^\d{7,15}$/.test(cleanedPhone)) {
    return true;
  }
  
  return false;
}

/**
 * Valide une adresse postale selon un format générique international
 * Cette validation est simplifiée car les formats d'adresse varient considérablement
 * selon les pays.
 * 
 * @param {Object} address - L'objet adresse à valider
 * @param {string} address.street - Rue
 * @param {string} address.city - Ville
 * @param {string} address.postalCode - Code postal
 * @param {string} address.country - Pays
 * @returns {Object} - Objet contenant le résultat de validation et les erreurs
 */
function validateAddress(address) {
  const errors = {};
  let isValid = true;
  
  // Validation de la rue (non vide et au moins 3 caractères)
  if (!address.street || address.street.trim().length < 3) {
    errors.street = "L'adresse doit contenir au moins 3 caractères";
    isValid = false;
  }
  
  // Validation de la ville (non vide et au moins 2 caractères)
  if (!address.city || address.city.trim().length < 2) {
    errors.city = "La ville doit contenir au moins 2 caractères";
    isValid = false;
  }
  
  // Validation du code postal selon le pays
  if (!validatePostalCodeByCountry(address.postalCode, address.country)) {
    errors.postalCode = "Le code postal n'est pas valide pour ce pays";
    isValid = false;
  }
  
  // Validation du pays (doit être non vide)
  if (!address.country || address.country.trim().length === 0) {
    errors.country = "Le pays est requis";
    isValid = false;
  }
  
  return {
    isValid,
    errors
  };
}

/**
 * Valide un code postal selon le format du pays spécifié
 * 
 * @param {string} postalCode - Le code postal à valider
 * @param {string} country - Le pays pour lequel valider le format
 * @returns {boolean} - true si le code postal est valide pour le pays, false sinon
 */
function validatePostalCodeByCountry(postalCode, country) {
  if (!postalCode || !country) return false;
  
  // Normalisation du pays (minuscules)
  const normalizedCountry = country.toLowerCase().trim();
  
  // Formats de code postal par pays
  const postalCodeFormats = {
    'france': /^\d{5}$/,
    'fr': /^\d{5}$/,
    'usa': /^\d{5}(-\d{4})?$/,
    'us': /^\d{5}(-\d{4})?$/,
    'united states': /^\d{5}(-\d{4})?$/,
    'canada': /^[A-Za-z]\d[A-Za-z][ -]?\d[A-Za-z]\d$/,
    'ca': /^[A-Za-z]\d[A-Za-z][ -]?\d[A-Za-z]\d$/,
    'uk': /^[A-Z]{1,2}[0-9][A-Z0-9]? ?[0-9][A-Z]{2}$/i,
    'united kingdom': /^[A-Z]{1,2}[0-9][A-Z0-9]? ?[0-9][A-Z]{2}$/i,
    'germany': /^\d{5}$/,
    'de': /^\d{5}$/,
    'japan': /^\d{3}-\d{4}$/,
    'jp': /^\d{3}-\d{4}$/,
    'australia': /^\d{4}$/,
    'au': /^\d{4}$/,
    'italy': /^\d{5}$/,
    'it': /^\d{5}$/,
    'spain': /^\d{5}$/,
    'es': /^\d{5}$/,
    'netherlands': /^\d{4}[ ]?[A-Z]{2}$/,
    'nl': /^\d{4}[ ]?[A-Z]{2}$/,
    'belgium': /^\d{4}$/,
    'be': /^\d{4}$/,
    'switzerland': /^\d{4}$/,
    'ch': /^\d{4}$/,
  };
  
  // Si le pays est dans la liste des formats connus
  if (postalCodeFormats[normalizedCountry]) {
    return postalCodeFormats[normalizedCountry].test(postalCode);
  }
  
  // Format générique pour les autres pays (au moins 3 caractères alphanumériques)
  return /^[A-Za-z0-9]{3,10}$/.test(postalCode);
}

/**
 * Valide un formulaire complet avec email, téléphone et adresse
 * 
 * @param {Object} formData - Les données du formulaire à valider
 * @param {string} formData.email - Email
 * @param {string} formData.phone - Numéro de téléphone
 * @param {Object} formData.address - Objet adresse
 * @returns {Object} - Résultat de la validation avec les erreurs éventuelles
 */
function validateForm(formData) {
  const result = {
    isValid: true,
    errors: {}
  };
  
  // Validation de l'email
  if (!validateEmail(formData.email)) {
    result.errors.email = "L'email n'est pas valide";
    result.isValid = false;
  }
  
  // Validation du téléphone
  if (!validatePhone(formData.phone)) {
    result.errors.phone = "Le numéro de téléphone n'est pas valide";
    result.isValid = false;
  }
  
  // Validation de l'adresse
  const addressValidation = validateAddress(formData.address);
  if (!addressValidation.isValid) {
    result.errors.address = addressValidation.errors;
    result.isValid = false;
  }
  
  return result;
}

// Exporte les fonctions pour utilisation dans d'autres modules
module.exports = {
  validateEmail,
  validatePhone,
  validateAddress,
  validateForm
};