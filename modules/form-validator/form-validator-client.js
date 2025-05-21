/**
 * Script de validation côté client pour le formulaire HTML
 * Utilise les fonctions du module form-validator.js
 */

// Fonction simple de validation d'email
function validateEmail(email) {
    // Expression régulière simple pour valider le format basique d'un email
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(String(email).toLowerCase());
}

// Fonction pour afficher un message d'erreur
function showError(inputElement, errorElement) {
    errorElement.style.display = 'block';
    inputElement.style.borderColor = 'red';
}

// Fonction pour masquer un message d'erreur
function hideError(inputElement, errorElement) {
    errorElement.style.display = 'none';
    inputElement.style.borderColor = '#ddd';
}

// Fonction de validation du formulaire
function validateForm(event) {
    event.preventDefault();
    
    // Récupération des éléments du formulaire
    const emailInput = document.getElementById('email');
    const emailError = document.getElementById('emailError');
    const formSuccess = document.getElementById('formSuccess');
    
    // Validation de l'email
    const isEmailValid = validateEmail(emailInput.value);
    
    if (!isEmailValid) {
        showError(emailInput, emailError);
        formSuccess.style.display = 'none';
        return false;
    } else {
        hideError(emailInput, emailError);
    }
    
    // Si tout est valide, afficher le message de succès
    formSuccess.style.display = 'block';
    return true;
}

// Validation en temps réel de l'email
function validateEmailInput() {
    const emailInput = document.getElementById('email');
    const emailError = document.getElementById('emailError');
    
    if (emailInput.value.trim() === '') {
        // Ne pas afficher d'erreur si le champ est vide
        hideError(emailInput, emailError);
        return;
    }
    
    const isEmailValid = validateEmail(emailInput.value);
    
    if (!isEmailValid) {
        showError(emailInput, emailError);
    } else {
        hideError(emailInput, emailError);
    }
}

// Ajout des écouteurs d'événements une fois que le DOM est chargé
document.addEventListener('DOMContentLoaded', function() {
    const form = document.getElementById('contactForm');
    const emailInput = document.getElementById('email');
    
    // Validation lors de la soumission du formulaire
    form.addEventListener('submit', validateForm);
    
    // Validation en temps réel lors de la saisie
    emailInput.addEventListener('input', validateEmailInput);
    emailInput.addEventListener('blur', validateEmailInput);
});