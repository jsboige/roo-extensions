#!/usr/bin/env tsx
/**
 * Cross-Machine MCP Configuration Validation Script
 *
 * Issue: #1634
 * Purpose: Detect configuration drift across machine fleet
 * Related Bugs: #1628 (ROOSYNC_SHARED_PATH), #1629 (MCP builds), #1631 (GitHub scopes)
 *
 * Validation Checks:
 * 1. ROOSYNC_SHARED_PATH set and accessible in mcp_settings.json
 * 2. GitHub token has write:project scope (required for Project #67 updates)
 * 3. All MCP servers have dist/index.js builds
 * 4. Post dashboard alert if any check fails
 *
 * Usage:
 *   tsx scripts/validation/cross-machine-config-validation.ts
 *
 * Exit codes:
 *   0 - All checks passed
 *   1 - One or more checks failed
 */

import { execSync } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';

// Extension identifiers — kept in sync with scripts/common/extension-paths.ps1
const ROO_EXTENSION_ID = 'rooveterinaryinc.roo-cline';
const ZOO_EXTENSION_ID = 'zoocodeorganization.zoo-code';

interface ValidationResult {
  check: string;
  passed: boolean;
  failures: string[];
}

/**
 * Check #1: ROOSYNC_SHARED_PATH validation
 * Addresses Bug #1628
 */
function validateRoosyncSharedPath(): ValidationResult {
  try {
    // Locate mcp_settings.json in user directories
    const appDataPath = process.env.APPDATA || path.join(os.homedir(), 'AppData', 'Roaming');
    const mcpSettingsPath = path.join(
      appDataPath,
      'Code',
      'User',
      'globalStorage',
      ROO_EXTENSION_ID,
      'mcp_settings.json'
    );

    if (!fs.existsSync(mcpSettingsPath)) {
      return {
        check: 'ROOSYNC_SHARED_PATH',
        passed: false,
        failures: [`mcp_settings.json not found at ${mcpSettingsPath}`]
      };
    }

    // Parse JSON and extract ROOSYNC_SHARED_PATH
    const settingsContent = fs.readFileSync(mcpSettingsPath, 'utf-8');
    const settings = JSON.parse(settingsContent);
    const roosyncPath = settings?.mcpServers?.['roo-state-manager']?.env?.ROOSYNC_SHARED_PATH;

    if (!roosyncPath) {
      return {
        check: 'ROOSYNC_SHARED_PATH',
        passed: false,
        failures: ['ROOSYNC_SHARED_PATH not set in mcp_settings.json roo-state-manager.env']
      };
    }

    // Verify path exists and is accessible
    if (!fs.existsSync(roosyncPath)) {
      return {
        check: 'ROOSYNC_SHARED_PATH',
        passed: false,
        failures: [`ROOSYNC_SHARED_PATH points to non-existent directory: ${roosyncPath}`]
      };
    }

    // Verify directory is readable
    try {
      fs.readdirSync(roosyncPath);
    } catch (error) {
      return {
        check: 'ROOSYNC_SHARED_PATH',
        passed: false,
        failures: [`ROOSYNC_SHARED_PATH directory not accessible: ${error.message}`]
      };
    }

    return {
      check: 'ROOSYNC_SHARED_PATH',
      passed: true,
      failures: []
    };

  } catch (error) {
    return {
      check: 'ROOSYNC_SHARED_PATH',
      passed: false,
      failures: [`Error validating ROOSYNC_SHARED_PATH: ${error.message}`]
    };
  }
}

/**
 * Check #2: GitHub token scopes validation
 * Addresses Bug #1631
 */
function validateGitHubScopes(): ValidationResult {
  try {
    // Execute gh auth status to retrieve token scopes
    const output = execSync('gh auth status 2>&1', { encoding: 'utf-8' });

    // Split output into account sections (separated by double newlines)
    const sections = output.split('\n\n');

    // Find the active account section
    const activeSection = sections.find(section =>
      section.includes('Active account: true')
    );

    if (!activeSection) {
      return {
        check: 'GitHub Scopes',
        passed: false,
        failures: ['No active GitHub account found']
      };
    }

    // Extract token scopes line
    // Expected format: "  - Token scopes: 'gist', 'project', 'read:org', 'repo', 'workflow'"
    const scopesMatch = activeSection.match(/Token scopes: '(.+)'/);
    if (!scopesMatch) {
      return {
        check: 'GitHub Scopes',
        passed: false,
        failures: ['Could not parse token scopes from gh auth status output']
      };
    }

    // Parse comma-separated scopes
    // The match group contains: "gist', 'project', 'read:org', 'repo', 'workflow"
    const scopesString = scopesMatch[1];
    const scopes = scopesString.split("', '").map(s => s.replace(/'/g, ''));
    // Result: ['gist', 'project', 'read:org', 'repo', 'workflow']

    // Check for required scope
    const requiredScopes = ['write:project'];
    const missingScopes = requiredScopes.filter(scope => !scopes.includes(scope));

    if (missingScopes.length > 0) {
      return {
        check: 'GitHub Scopes',
        passed: false,
        failures: missingScopes.map(scope => `Missing required scope: ${scope}`)
      };
    }

    return {
      check: 'GitHub Scopes',
      passed: true,
      failures: []
    };

  } catch (error) {
    return {
      check: 'GitHub Scopes',
      passed: false,
      failures: [`Error executing gh auth status: ${error.message}`]
    };
  }
}

/**
 * Check #3: MCP builds validation
 * Addresses Bug #1629
 */
function validateMCPBuilds(): ValidationResult {
  const MCP_SERVERS = [
    'github-projects-mcp',
    'jinavigator-server',
    'jupyter-mcp-server',
    'jupyter-papermill-mcp-server',
    'open-terminal-mcp',
    'quickfiles-server',
    'roo-state-manager',
    'sk-agent'
  ];

  const failures: string[] = [];
  const mcpsDir = path.join(process.cwd(), 'mcps', 'internal', 'servers');

  for (const mcp of MCP_SERVERS) {
    const distPath = path.join(mcpsDir, mcp, 'dist', 'index.js');
    if (!fs.existsSync(distPath)) {
      failures.push(`${mcp}: missing dist/index.js`);
    }
  }

  return {
    check: 'MCP Builds',
    passed: failures.length === 0,
    failures
  };
}

/**
 * Check #4: Dashboard alert posting
 * Uses stderr output for now (dashboard MCP integration requires runtime context)
 */
function reportValidationResults(results: ValidationResult[]): void {
  const failedChecks = results.filter(r => !r.passed);

  if (failedChecks.length === 0) return;

  const machineId = os.hostname();
  const failureDetails = failedChecks.map(r =>
    `${r.check}: ${r.failures.join(', ')}`
  ).join(' | ');

  const alertMessage = `[WARN] Config validation failed on ${machineId}: ${failureDetails}`;

  // Output alert to stderr (can be captured by scheduler or dashboard watcher)
  console.error(alertMessage);
  console.error('\nRecommended Actions:');

  for (const result of failedChecks) {
    console.error(`\n${result.check}:`);
    for (const failure of result.failures) {
      console.error(`  - ${failure}`);
    }
  }
}

/**
 * Main validation execution
 */
async function runValidation(): Promise<void> {
  console.log('=== Cross-Machine MCP Config Validation ===');
  console.log(`Machine: ${os.hostname()}`);
  console.log(`Date: ${new Date().toISOString()}`);
  console.log(`Issue: #1634\n`);

  // Run all validation checks
  const results: ValidationResult[] = [
    validateRoosyncSharedPath(),
    validateGitHubScopes(),
    validateMCPBuilds()
  ];

  // Display results
  console.log('=== Validation Results ===\n');
  for (const result of results) {
    const status = result.passed ? '✅ PASS' : '❌ FAIL';
    console.log(`${status} ${result.check}`);
    if (!result.passed) {
      result.failures.forEach(f => console.log(`  - ${f}`));
    }
  }

  console.log('');

  // Report failures
  reportValidationResults(results);

  // Exit with appropriate code
  const allPassed = results.every(r => r.passed);
  process.exit(allPassed ? 0 : 1);
}

// Execute validation
runValidation();
