// jest.preset.cjs
const { pathsToModuleNameMapper } = require('ts-jest');
// Correction pour le chemin du tsconfig.base.json. On suppose qu'il est bien à la racine.
const { compilerOptions } = require('./tsconfig.base.json');

/** @type {import('ts-jest').JestConfigWithTsJest} */
module.exports = {
  preset: 'ts-jest/presets/default-esm',
  testEnvironment: 'node',
  transform: {
    '^.+\\.tsx?$': ['ts-jest', { useESM: true }],
  },
  moduleNameMapper: {
    // CORRECTION APPLIQUÉE: Le préfixe remonte depuis le sous-projet vers la racine.
    ...pathsToModuleNameMapper(compilerOptions.paths, { prefix: '<rootDir>/../../../../' }),
    '^(\\.{1,2}/.*)\\.js$': '$1',
  },
  extensionsToTreatAsEsm: ['.ts'],
  testPathIgnorePatterns: ['/node_modules/', '/dist/'],
  coverageDirectory: './coverage',
  collectCoverageFrom: ['src/**/*.ts', '!src/**/*.d.ts'],
};