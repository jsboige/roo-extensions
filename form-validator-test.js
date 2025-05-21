/**
 * Tests pour le module de validation de formulaire
 */

const validator = require('./form-validator');

// Tests de validation d'email
console.log('=== Tests de validation d\'email ===');
const emailTests = [
  { email: 'test@example.com', expected: true },
  { email: 'test.name@example.co.uk', expected: true },
  { email: 'test+label@example.com', expected: true },
  { email: 'test@localhost', expected: false },
  { email: 'test@example..com', expected: false },
  { email: 'test@.example.com', expected: false },
  { email: 'test', expected: false },
  { email: 'test@', expected: false },
  { email: '@example.com', expected: false },
];

emailTests.forEach(test => {
  const result = validator.validateEmail(test.email);
  console.log(`Email: ${test.email} - Valide: ${result} - Attendu: ${test.expected} - ${result === test.expected ? '✓' : '✗'}`);
});

// Tests de validation de téléphone
console.log('\n=== Tests de validation de téléphone ===');
const phoneTests = [
  { phone: '+33612345678', expected: true },
  { phone: '+33 6 12 34 56 78', expected: true },
  { phone: '+33-6-12-34-56-78', expected: true },
  { phone: '+33(6)12345678', expected: true },
  { phone: '0612345678', expected: true },
  { phone: '06 12 34 56 78', expected: true },
  { phone: '+1234', expected: false },
  { phone: 'abcdefg', expected: false },
  { phone: '+abc123', expected: false },
];

phoneTests.forEach(test => {
  const result = validator.validatePhone(test.phone);
  console.log(`Téléphone: ${test.phone} - Valide: ${result} - Attendu: ${test.expected} - ${result === test.expected ? '✓' : '✗'}`);
});

// Tests de validation d'adresse
console.log('\n=== Tests de validation d\'adresse ===');
const addressTests = [
  { 
    address: {
      street: '123 Rue de la Paix',
      city: 'Paris',
      postalCode: '75001',
      country: 'France'
    },
    expected: true
  },
  { 
    address: {
      street: '1600 Pennsylvania Avenue NW',
      city: 'Washington',
      postalCode: '20500',
      country: 'USA'
    },
    expected: true
  },
  { 
    address: {
      street: '10 Downing Street',
      city: 'London',
      postalCode: 'SW1A 2AA',
      country: 'UK'
    },
    expected: true
  },
  { 
    address: {
      street: '',
      city: 'Berlin',
      postalCode: '10115',
      country: 'Germany'
    },
    expected: false
  },
  { 
    address: {
      street: '123 Main St',
      city: '',
      postalCode: '12345',
      country: 'USA'
    },
    expected: false
  },
  { 
    address: {
      street: '123 Main St',
      city: 'New York',
      postalCode: 'ABC',
      country: 'USA'
    },
    expected: false
  },
];

addressTests.forEach(test => {
  const result = validator.validateAddress(test.address);
  console.log(`Adresse: ${test.address.street}, ${test.address.city}, ${test.address.postalCode}, ${test.address.country}`);
  console.log(`Valide: ${result.isValid} - Attendu: ${test.expected} - ${result.isValid === test.expected ? '✓' : '✗'}`);
  if (!result.isValid) {
    console.log('Erreurs:', result.errors);
  }
  console.log('---');
});

// Test de validation de formulaire complet
console.log('\n=== Test de validation de formulaire complet ===');
const formTests = [
  {
    form: {
      email: 'contact@example.com',
      phone: '+33612345678',
      address: {
        street: '123 Rue de la Paix',
        city: 'Paris',
        postalCode: '75001',
        country: 'France'
      }
    },
    expected: true
  },
  {
    form: {
      email: 'invalid-email',
      phone: '+33612345678',
      address: {
        street: '123 Rue de la Paix',
        city: 'Paris',
        postalCode: '75001',
        country: 'France'
      }
    },
    expected: false
  },
  {
    form: {
      email: 'contact@example.com',
      phone: 'abc',
      address: {
        street: '123 Rue de la Paix',
        city: 'Paris',
        postalCode: '75001',
        country: 'France'
      }
    },
    expected: false
  },
  {
    form: {
      email: 'contact@example.com',
      phone: '+33612345678',
      address: {
        street: '',
        city: 'Paris',
        postalCode: '75001',
        country: 'France'
      }
    },
    expected: false
  }
];

formTests.forEach(test => {
  const result = validator.validateForm(test.form);
  console.log(`Formulaire - Email: ${test.form.email}, Téléphone: ${test.form.phone}`);
  console.log(`Adresse: ${test.form.address.street}, ${test.form.address.city}, ${test.form.address.postalCode}, ${test.form.address.country}`);
  console.log(`Valide: ${result.isValid} - Attendu: ${test.expected} - ${result.isValid === test.expected ? '✓' : '✗'}`);
  if (!result.isValid) {
    console.log('Erreurs:', result.errors);
  }
  console.log('---');
});