#!/usr/bin/env node
/**
 * sync-api-configs.js - Generate Roo/Zoo Code providerProfiles import from model-configs.json
 *
 * Reads:  roo-config/model-configs.json (apiConfigs section)
 *         .env (for {{SECRET:xxx}} placeholder resolution)
 * Writes: roo-config/generated/provider-profiles-import.json
 *         (Roo/Zoo Code import format — providerProfilesSchema)
 *
 * Usage:
 *   node roo-config/scripts/sync-api-configs.js [--resolve-secrets]
 *
 *   --resolve-secrets  Resolve {{SECRET:xxx}} from .env (otherwise keep placeholders)
 *
 * Then in VS Code (Roo or Zoo):
 *   Settings > Import > select roo-config/generated/provider-profiles-import.json
 *
 * Issue: #914, #2543 Phase 2(d) — re-automate provider profiles import for Zoo Code
 */

const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..', '..');
const MODEL_CONFIGS_PATH = path.join(ROOT, 'roo-config', 'model-configs.json');
const OUTPUT_PATH = path.join(ROOT, 'roo-config', 'generated', 'provider-profiles-import.json');
const ENV_PATH = path.join(ROOT, '.env');

const resolveSecrets = process.argv.includes('--resolve-secrets');

// Load .env for secret resolution (simple key=value parser)
function loadEnv() {
  const env = {};
  if (!fs.existsSync(ENV_PATH)) return env;
  const content = fs.readFileSync(ENV_PATH, 'utf8');
  for (const line of content.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eqIdx = trimmed.indexOf('=');
    if (eqIdx === -1) continue;
    const key = trimmed.slice(0, eqIdx).trim();
    const value = trimmed.slice(eqIdx + 1).trim().replace(/^["']|["']$/g, '');
    env[key] = value;
  }
  return env;
}

function resolveSecretPlaceholders(value, env) {
  if (typeof value !== 'string') return value;
  return value.replace(/\{\{SECRET:(\w+)\}\}/g, (match, envVar) => {
    if (!resolveSecrets) {
      console.warn(`  ⚠ Placeholder kept: {{SECRET:${envVar}}} (use --resolve-secrets to fill)`);
      return match;
    }
    const resolved = env[envVar];
    if (!resolved) {
      console.error(`  ❌ Missing .env variable: ${envVar}`);
      return match;
    }
    return resolved;
  });
}

console.log('Reading model-configs.json...');
const modelConfigs = JSON.parse(fs.readFileSync(MODEL_CONFIGS_PATH, 'utf8'));

console.log('Extracting apiConfigs...');
const apiConfigs = modelConfigs.apiConfigs || {};
const modeApiConfigs = modelConfigs.modeApiConfigs || {};
const env = loadEnv();

// Convert to providerProfilesSchema format
// Schema: { currentApiConfigName, apiConfigs: { id: providerSettingsWithId }, modeApiConfigs }
const importApiConfigs = {};

for (const [id, config] of Object.entries(apiConfigs)) {
  const entry = {
    id: id,
    apiProvider: config.apiProvider,
    description: config.description || `API Config: ${id}`,
    diffEnabled: config.diffEnabled !== undefined ? config.diffEnabled : true,
    fuzzyMatchThreshold: config.fuzzyMatchThreshold || 1,
    modelTemperature: config.modelTemperature || 0.7
  };

  // OpenAI-specific fields
  if (config.apiProvider === 'openai') {
    entry.openAiBaseUrl = config.openAiBaseUrl || '';
    entry.openAiModelId = config.openAiModelId || '';
    entry.openAiLegacyFormat = config.openAiLegacyFormat !== undefined ? config.openAiLegacyFormat : true;
    // Resolve API key placeholder
    entry.openAiApiKey = resolveSecretPlaceholders(config.openAiApiKey || '', env);
  }

  // Include any additional fields not yet covered
  for (const [key, value] of Object.entries(config)) {
    if (!entry[key] && key !== 'id' && key !== 'description') {
      entry[key] = key.includes('ApiKey') || key.includes('Secret') || key.includes('Token')
        ? resolveSecretPlaceholders(value, env)
        : value;
    }
  }

  importApiConfigs[id] = entry;
}

// Build the providerProfilesSchema-compatible structure
const importData = {
  providerProfiles: {
    currentApiConfigName: 'default',
    apiConfigs: importApiConfigs,
    modeApiConfigs: modeApiConfigs
  },
  _metadata: {
    generated: new Date().toISOString(),
    source: MODEL_CONFIGS_PATH,
    secretsResolved: resolveSecrets,
    note: 'Import this file via Roo/Zoo Code Settings > Import'
  }
};

console.log(`Writing ${OUTPUT_PATH}...`);
fs.mkdirSync(path.dirname(OUTPUT_PATH), { recursive: true });
fs.writeFileSync(OUTPUT_PATH, JSON.stringify(importData, null, 2));

console.log('\n✅ Done!');
console.log(`\nGenerated: ${OUTPUT_PATH}`);
console.log(`Format: providerProfilesSchema (compatible Roo + Zoo Code)`);
console.log(`Profiles: ${Object.keys(importApiConfigs).length}`);
console.log(`Secret resolution: ${resolveSecrets ? 'RESOLVED from .env' : 'PLACEHOLDERS KEPT (--resolve-secrets to fill)'}`);
console.log('\nNext steps:');
console.log('1. Open Roo/Zoo Code settings in VS Code');
console.log('2. Go to API Configs section');
console.log('3. Click "Import" and select the generated file');
console.log('4. Review and save the imported profiles');
if (!resolveSecrets) {
  console.log('\n⚠️  API keys contain placeholders. Re-run with --resolve-secrets to embed real keys from .env');
}
