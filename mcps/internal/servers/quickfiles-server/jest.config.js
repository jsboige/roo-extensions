/**
 * Configuration Jest pour les tests du serveur QuickFiles MCP
 */

export default {
  // Utiliser ts-jest pour la transformation des fichiers TypeScript
  preset: 'ts-jest',
  
  // Environnement de test Node.js
  testEnvironment: 'node',
  
  // Transformation des fichiers
  transform: {
    '^.+\\.tsx?$': 'ts-jest'
  },
  
  // Extensions à traiter comme des modules ES
  extensionsToTreatAsEsm: ['.ts', '.js'],
  
  // Résolution des modules avec extension .js
  moduleNameMapper: {
    '^(\\.{1,2}/.*)\\.js$': '$1'
  },
  
  // Patterns pour trouver les fichiers de test
  testMatch: [
    '**/__tests__/**/*.test.js'
  ],
  
  // Fichiers à ignorer
  testPathIgnorePatterns: [
    '/node_modules/',
    '/dist/'
  ],
  
  // Collecte de la couverture de code
  collectCoverageFrom: [
    'dist/**/*.js',
    '!dist/**/*.d.ts',
    '!src/**/*.d.ts'
  ],
  
  // Répertoire pour les rapports de couverture
  coverageDirectory: 'coverage',
  
  // Formats des rapports de couverture
  coverageReporters: [
    'text',
    'lcov'
  ],
  
  // Seuil minimal de couverture
  coverageThreshold: {
    global: {
      branches: 70,
      functions: 80,
      lines: 80,
      statements: 80
    }
  },
  
  // Afficher un résumé de la couverture après les tests
  verbose: true
};