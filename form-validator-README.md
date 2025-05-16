# Validateur de Formulaire International

Ce module fournit des fonctions pour valider les formats d'email, de téléphone et d'adresse selon les standards internationaux.

## Fonctionnalités

- Validation d'email selon le format standard RFC 5322
- Validation de numéros de téléphone internationaux avec support de différents formats
- Validation d'adresses postales avec support de formats de codes postaux pour différents pays
- Validation de formulaire complète combinant email, téléphone et adresse

## Installation

```bash
# Aucune dépendance externe n'est requise
# Copiez simplement les fichiers dans votre projet
```

## Utilisation

### Validation d'email

```javascript
const validator = require('./form-validator');

// Valider un email
const isValidEmail = validator.validateEmail('contact@example.com');
console.log(isValidEmail); // true
```

### Validation de téléphone

```javascript
const validator = require('./form-validator');

// Valider un numéro de téléphone
const isValidPhone = validator.validatePhone('+33 6 12 34 56 78');
console.log(isValidPhone); // true
```

### Validation d'adresse

```javascript
const validator = require('./form-validator');

// Valider une adresse
const addressValidation = validator.validateAddress({
  street: '123 Rue de la Paix',
  city: 'Paris',
  postalCode: '75001',
  country: 'France'
});

console.log(addressValidation.isValid); // true
console.log(addressValidation.errors); // {}
```

### Validation de formulaire complet

```javascript
const validator = require('./form-validator');

// Valider un formulaire complet
const formValidation = validator.validateForm({
  email: 'contact@example.com',
  phone: '+33612345678',
  address: {
    street: '123 Rue de la Paix',
    city: 'Paris',
    postalCode: '75001',
    country: 'France'
  }
});

console.log(formValidation.isValid); // true
console.log(formValidation.errors); // {}
```

## Formats supportés

### Email
- Format standard RFC 5322
- Supporte les domaines de premier niveau (TLD) de 2 caractères ou plus
- Supporte les caractères spéciaux dans la partie locale (avant @)

### Téléphone
- Format international avec préfixe pays (+33612345678)
- Format avec espaces (+33 6 12 34 56 78)
- Format avec tirets (+33-6-12-34-56-78)
- Format avec parenthèses (+33(6)12345678)
- Format national (0612345678)

### Codes postaux par pays
- France: 5 chiffres
- USA: 5 chiffres ou 5 chiffres + tiret + 4 chiffres
- Canada: Format A1A 1A1
- UK: Format variable (ex: SW1A 2AA)
- Allemagne: 5 chiffres
- Japon: 3 chiffres + tiret + 4 chiffres
- Australie: 4 chiffres
- Italie: 5 chiffres
- Espagne: 5 chiffres
- Pays-Bas: 4 chiffres + 2 lettres
- Belgique: 4 chiffres
- Suisse: 4 chiffres
- Format générique pour les autres pays

## Exécution des tests

```bash
node form-validator-test.js
```

## Limitations

- La validation d'adresse est simplifiée car les formats varient considérablement selon les pays
- Certains formats de numéros de téléphone très spécifiques peuvent ne pas être supportés
- La validation d'email ne vérifie pas l'existence réelle de l'adresse

## Licence

MIT