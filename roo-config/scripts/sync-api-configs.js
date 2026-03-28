#!/usr/bin/env node
/**
 * sync-api-configs.js - Generate Roo Code settings import file from model-configs.json
 *
 * Reads:  roo-config/model-configs.json (apiConfigs + modeApiConfigs definitions)
 * Writes: roo-config/generated/roo-api-configs.json (importable via Roo Settings > Import)
 *
 * Usage:
 *   node roo-config/scripts/sync-api-configs.js [--output <path>]
 *
 * Then import in Roo Code:
 *   Settings > Import > select generated file
 *
 * Issue: #914 - Gap déploiement modes — ApiConfigs VS Code non synchronisées
 */

const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..', '..');
const DEFAULT_MODEL_CONFIGS = path.join(ROOT, 'roo-config', 'model-configs.json');
const DEFAULT_OUTPUT = path.join(ROOT, 'roo-config', 'generated', 'roo-api-configs.json');

// --- CLI Args ---
function parseArgs() {
	const args = process.argv.slice(2);
	const opts = {
		modelConfigs: DEFAULT_MODEL_CONFIGS,
		output: DEFAULT_OUTPUT,
	};
	for (let i = 0; i < args.length; i++) {
		if (args[i] === '--output' && args[i + 1]) {
			opts.output = path.resolve(args[++i]);
		} else if (args[i] === '--model-configs' && args[i + 1]) {
			opts.modelConfigs = path.resolve(args[++i]);
		} else if (args[i] === '--help' || args[i] === '-h') {
			console.log('Usage: node sync-api-configs.js [--output <path>] [--model-configs <path>]');
			console.log('');
			console.log('Generates a Roo Code settings import file from model-configs.json.');
			console.log('Import the output file via: Roo Code Settings > Import');
			process.exit(0);
		}
	}
	return opts;
}

// --- Main ---
function main() {
	const opts = parseArgs();

	// 1. Read model-configs.json
	if (!fs.existsSync(opts.modelConfigs)) {
		console.error('ERROR: model-configs.json not found: ' + opts.modelConfigs);
		process.exit(1);
	}

	const modelConfigs = JSON.parse(fs.readFileSync(opts.modelConfigs, 'utf-8'));

	if (!modelConfigs.apiConfigs || Object.keys(modelConfigs.apiConfigs).length === 0) {
		console.error('ERROR: No apiConfigs defined in model-configs.json');
		process.exit(1);
	}

	// 2. Build provider profiles for Roo import
	// Each apiConfig needs a unique ID. We generate deterministic ones based on the config name.
	const apiConfigs = {};
	for (const [name, config] of Object.entries(modelConfigs.apiConfigs)) {
		// Strip secret placeholders - these will need to be set manually after import
		// or preserved from the existing config
		const cleanConfig = { ...config };

		// Generate a deterministic ID from the config name
		cleanConfig.id = generateId(name);

		// Handle secret placeholders - mark them for user action
		if (cleanConfig.openAiApiKey && cleanConfig.openAiApiKey.startsWith('{{SECRET:')) {
			// Don't include placeholder - user will need to set API key after import
			delete cleanConfig.openAiApiKey;
		}

		apiConfigs[name] = cleanConfig;
	}

	// 3. Build modeApiConfigs from modelConfigs or fall back to profiles
	let modeApiConfigs = modelConfigs.modeApiConfigs || {};
	if (Object.keys(modeApiConfigs).length === 0 && modelConfigs.profiles) {
		// Use the first profile's modeOverrides
		const profile = modelConfigs.profiles[0];
		if (profile && profile.modeOverrides) {
			modeApiConfigs = profile.modeOverrides;
		}
	}

	// 4. Build the Roo settings export format
	const settings = {
		providerProfiles: {
			currentApiConfigName: 'default',
			apiConfigs: apiConfigs,
			modeApiConfigs: modeApiConfigs,
		},
		_metadata: {
			generatedBy: 'sync-api-configs.js',
			generatedAt: new Date().toISOString(),
			source: opts.modelConfigs,
			instructions: [
				'1. Open Roo Code Settings in VS Code',
				'2. Click "Import" button',
				'3. Select this file',
				'4. After import, verify API keys are set for each profile',
				'5. Reload VS Code window (Ctrl+Shift+P > Reload Window)',
			],
			note: 'API keys are NOT included in this file. After import, set API keys in each profile via Roo Settings.',
		},
	};

	// 5. Write output
	const outputDir = path.dirname(opts.output);
	if (!fs.existsSync(outputDir)) {
		fs.mkdirSync(outputDir, { recursive: true });
	}

	fs.writeFileSync(opts.output, JSON.stringify(settings, null, 2), 'utf-8');

	// 6. Summary
	const configNames = Object.keys(apiConfigs);
	console.log('=== sync-api-configs.js ===');
	console.log('');
	console.log('Generated: ' + opts.output);
	console.log('');
	console.log('API Configs (' + configNames.length + '):');
	for (const name of configNames) {
		const c = apiConfigs[name];
		console.log('  ' + name + ': ' + (c.openAiModelId || c.modelId || 'unknown') + ' via ' + (c.openAiBaseUrl || c.apiProvider || 'unknown'));
	}
	console.log('');
	console.log('Mode API Configs (' + Object.keys(modeApiConfigs).length + ' modes):');
	for (const [mode, apiConfig] of Object.entries(modeApiConfigs)) {
		console.log('  ' + mode + ' -> ' + apiConfig);
	}
	console.log('');
	console.log('NEXT STEPS:');
	console.log('  1. Open Roo Code > Settings');
	console.log('  2. Click "Import"');
	console.log('  3. Select: ' + opts.output);
	console.log('  4. Set API keys for each profile');
	console.log('  5. Reload VS Code');
}

/**
 * Generate a deterministic ID from a string.
 * Uses a simple hash to create a consistent ID for the same config name.
 */
function generateId(str) {
	let hash = 0;
	for (let i = 0; i < str.length; i++) {
		const char = str.charCodeAt(i);
		hash = ((hash << 5) - hash) + char;
		hash = hash & hash; // Convert to 32-bit int
	}
	// Convert to hex and pad to make it look like Roo's IDs
	const hex = Math.abs(hash).toString(16).padStart(8, '0');
	return hex + '-0000-0000-0000-' + hex.padStart(12, '0');
}

main();
