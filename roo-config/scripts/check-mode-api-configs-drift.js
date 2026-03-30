#!/usr/bin/env node

/**
 * Check modeApiConfigs drift between model-configs.json and VS Code state
 *
 * This script compares the modeApiConfigs mapping in model-configs.json
 * (source of truth) with the modeApiConfigs stored in VS Code's state.vscdb.
 *
 * Usage:
 *   node check-mode-api-configs-drift.js
 *   node check-mode-api-configs-drift.js --model-configs path/to/model-configs.json
 */

import { readFileSync, existsSync, copyFileSync, unlinkSync } from 'fs';
import { join, homedir } from 'path';
import sqlite3 from 'sqlite3';
import { hideBin } from 'yargs/helpers';
import yargs from 'yargs';

const VSCDB_KEY = 'RooVeterinaryInc.roo-cline';
const VSCDB_PATH = join(homedir(), 'AppData', 'Roaming', 'Code', 'User', 'globalStorage', 'state.vscdb');

const argv = yargs(hideBin(process.argv))
  .option('model-configs', {
    alias: 'm',
    type: 'string',
    description: 'Path to model-configs.json',
    default: null
  })
  .option('machine', {
    alias: 'M',
    type: 'string',
    description: 'Machine name for reporting',
    default: process.env.COMPUTERNAME || 'unknown'
  })
  .help()
  .argv;

/**
 * Read JSON file safely
 */
function readJsonFile(path) {
  if (!existsSync(path)) {
    throw new Error(`File not found: ${path}`);
  }
  const content = readFileSync(path, 'utf-8');
  return JSON.parse(content);
}

/**
 * Read VS Code state from state.vscdb (using callback-based sqlite3)
 */
function readVsCodeStateSync() {
  if (!existsSync(VSCDB_PATH)) {
    return null;
  }

  // Copy to temp to avoid locking
  const tempPath = join(process.env.TEMP || '/tmp', `state-vscdb-${Date.now()}.db`);
  try {
    copyFileSync(VSCDB_PATH, tempPath);

    const db = new sqlite3.Database(tempPath, sqlite3.OPEN_READONLY, (err) => {
      if (err) {
        throw new Error(`Cannot open state.vscdb: ${err.message}`);
      }
    });

    return new Promise((resolve, reject) => {
      db.get('SELECT value FROM ItemTable WHERE key = ?', [VSCDB_KEY], (err, row) => {
        db.close((closeErr) => {
          // Clean up temp file
          try {
            unlinkSync(tempPath);
          } catch {
            // Ignore cleanup errors
          }

          if (err) {
            reject(err);
          } else if (closeErr) {
            reject(closeErr);
          } else {
            if (!row) {
              resolve(null);
            } else {
              const value = row.value;
              resolve(typeof value === 'string' ? JSON.parse(value) : value);
            }
          }
        });
      });
    });
  } catch (error) {
    // Clean up temp file on error
    try {
      unlinkSync(tempPath);
    } catch {
      // Ignore cleanup errors
    }
    throw error;
  }
}

/**
 * Compare modeApiConfigs
 */
function compareModeApiConfigs(source, vsCode) {
  const drift = {};
  const allModes = new Set([
    ...Object.keys(source || {}),
    ...Object.keys(vsCode || {})
  ]);

  for (const mode of allModes) {
    const sourceProfile = source?.[mode] || 'NOT_DEFINED';
    const vsCodeProfile = vsCode?.[mode] || 'NOT_DEFINED';

    if (sourceProfile !== vsCodeProfile) {
      let driftType;
      if (sourceProfile === 'NOT_DEFINED') {
        driftType = 'EXTRA_IN_VSCODE';
      } else if (vsCodeProfile === 'NOT_DEFINED') {
        driftType = 'MISSING_IN_VSCODE';
      } else {
        driftType = 'MISMATCH';
      }

      drift[mode] = {
        sourceOfTruth: sourceProfile,
        vsCodeState: vsCodeProfile,
        driftType
      };
    }
  }

  return drift;
}

/**
 * Main function
 */
async function main() {
  try {
    // Resolve model-configs.json path
    const repoRoot = process.cwd();
    const modelConfigsPath = argv['model-configs'] ||
      join(repoRoot, 'roo-config', 'model-configs.json');

    console.log(`\nmodeApiConfigs Drift Check for ${argv.machine}`);
    console.log(`Source of truth: ${modelConfigsPath}`);
    console.log(`VS Code state: ${VSCDB_PATH}`);

    // Read model-configs.json
    const modelConfigs = readJsonFile(modelConfigsPath);
    const sourceModeApiConfigs = modelConfigs.modeApiConfigs;

    if (!sourceModeApiConfigs) {
      console.error('\nERROR: No modeApiConfigs found in model-configs.json');
      process.exit(1);
    }

    // Read VS Code state
    const vsCodeState = await readVsCodeStateSync();

    if (!vsCodeState) {
      console.warn('\nWARNING: VS Code state not found (Roo extension not installed?)');
      console.log(JSON.stringify({
        machine: argv.machine,
        status: 'SKIPPED',
        reason: 'Roo extension not installed (state.vscdb not found)',
        sourceOfTruth: sourceModeApiConfigs,
        vsCodeState: null,
        drift: null
      }, null, 2));
      process.exit(0);
    }

    const vsCodeModeApiConfigs = vsCodeState.modeApiConfigs;

    if (!vsCodeModeApiConfigs) {
      console.warn('\nWARNING: modeApiConfigs not found in VS Code state');
      console.log(JSON.stringify({
        machine: argv.machine,
        status: 'NO_VSCONFIGS',
        reason: 'modeApiConfigs not found in VS Code state (fresh installation?)',
        sourceOfTruth: sourceModeApiConfigs,
        vsCodeState: null,
        drift: null
      }, null, 2));
      process.exit(0);
    }

    // Compare
    const drift = compareModeApiConfigs(sourceModeApiConfigs, vsCodeModeApiConfigs);
    const driftCount = Object.keys(drift).length;

    const result = {
      machine: argv.machine,
      status: driftCount > 0 ? 'DRIFT_DETECTED' : 'OK',
      sourceOfTruth: sourceModeApiConfigs,
      vsCodeState: vsCodeModeApiConfigs,
      drift: driftCount > 0 ? drift : null,
      driftCount,
      timestamp: new Date().toISOString()
    };

    // Output human-readable result
    if (result.status === 'OK') {
      console.log('\n\x1b[32mStatus: OK - No drift detected\x1b[0m');
      console.log('\x1b[32mAll modes match the source of truth.\x1b[0m');
    } else {
      console.log(`\n\x1b[31mStatus: DRIFT_DETECTED - ${driftCount} mode(s) affected\x1b[0m`);
      console.log('\nDrift details:');

      const sortedModes = Object.keys(drift).sort();
      for (const mode of sortedModes) {
        const driftInfo = drift[mode];
        console.log(`  \x1b[37m[${mode}]\x1b[0m`);
        console.log(`    \x1b[32mSource of truth: ${driftInfo.sourceOfTruth}\x1b[0m`);
        console.log(`    \x1b[31mVS Code state:    ${driftInfo.vsCodeState}\x1b[0m`);
        console.log(`    Drift type:       ${driftInfo.driftType}`);
      }

      console.log('\nRecommended action:');
      console.log('  1. Review the drift above');
      console.log('  2. If drift is unintended, reset modeApiConfigs in VS Code');
      console.log('  3. Or update model-configs.json if the drift is intentional');
    }

    // Output JSON for programmatic consumption
    console.log('\n' + JSON.stringify(result, null, 2));

    process.exit(result.status === 'OK' ? 0 : 1);
  } catch (error) {
    console.error(`\nERROR: ${error.message}`);
    process.exit(1);
  }
}

main();
