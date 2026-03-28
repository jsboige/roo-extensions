#!/usr/bin/env node
/**
 * sync-api-configs.js - Generate Roo Code providerProfiles import from model-configs.json
 *
 * Reads:  roo-config/model-configs.json (apiConfigs section)
 * Writes: roo-config/generated/roo-api-configs.json (Roo Code import format)
 *
 * Usage:
 *   node roo-config/scripts/sync-api-configs.js
 *
 * Then in VS Code:
 *   Roo Code > Settings > Import > select roo-config/generated/roo-api-configs.json
 *
 * Issue: #914 - Gap déploiement modes — ApiConfigs VS Code non synchronisées
 */

const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..', '..');
const MODEL_CONFIGS_PATH = path.join(ROOT, 'roo-config', 'model-configs.json');
const OUTPUT_PATH = path.join(ROOT, 'roo-config', 'generated', 'roo-api-configs.json');

console.log('Reading model-configs.json...');
const modelConfigs = JSON.parse(fs.readFileSync(MODEL_CONFIGS_PATH, 'utf8'));

console.log('Extracting apiConfigs...');
const apiConfigs = modelConfigs.apiConfigs || {};

// Convert to Roo Code providerProfiles format
const providerProfiles = {};

for (const [id, config] of Object.entries(apiConfigs)) {
  providerProfiles[id] = {
    id: id,
    description: config.description || `API Config: ${id}`,
    apiProvider: config.apiProvider,
    diffEnabled: config.diffEnabled !== undefined ? config.diffEnabled : true,
    fuzzyMatchThreshold: config.fuzzyMatchThreshold || 1,
    modelTemperature: config.modelTemperature || 0.7
  };

  // Add OpenAI-specific fields
  if (config.apiProvider === 'openai') {
    providerProfiles[id].openAiBaseUrl = config.openAiBaseUrl;
    providerProfiles[id].openAiModelId = config.openAiModelId;
    // Note: API key is NOT exported - user must set it manually in Roo Code settings
    providerProfiles[id].openAiApiKey = '{{YOUR_API_KEY_HERE}}';
  }

  // Add any additional fields
  for (const [key, value] of Object.entries(config)) {
    if (!providerProfiles[id][key] && key !== 'id' && key !== 'description') {
      providerProfiles[id][key] = value;
    }
  }
}

// Create Roo Code import format
const importData = {
  providerProfiles: providerProfiles,
  _metadata: {
    generated: new Date().toISOString(),
    source: MODEL_CONFIGS_PATH,
    note: 'Import this file via Roo Code Settings > Import'
  }
};

console.log(`Writing ${OUTPUT_PATH}...`);
fs.mkdirSync(path.dirname(OUTPUT_PATH), { recursive: true });
fs.writeFileSync(OUTPUT_PATH, JSON.stringify(importData, null, 2));

console.log('\n✅ Done!');
console.log(`\nGenerated: ${OUTPUT_PATH}`);
console.log('\nNext steps:');
console.log('1. Open Roo Code settings in VS Code');
console.log('2. Go to API Configs section');
console.log('3. Click "Import" and select the generated file');
console.log('4. Review and save the imported profiles');
console.log('\n⚠️  Note: You will need to set your API keys manually after import.');
