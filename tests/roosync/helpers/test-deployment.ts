/**
 * test-deployment.ts - Mocks PowerShell pour tests RooSync
 * 
 * Usage:
 * ```typescript
 * import { createTimeoutTestScript, createFailureTestScript, createSuccessTestScript } from './helpers/test-deployment';
 * 
 * const timeoutScript = createTimeoutTestScript('./test-scripts');
 * const failureScript = createFailureTestScript('./test-scripts');
 * ```
 */

import * as fs from 'fs';
import * as path from 'path';
import { TestLogger } from './test-logger';

/**
 * Créer script PowerShell test - Timeout (long)
 */
export function createTimeoutTestScript(scriptsDir: string, logger?: TestLogger): string {
  // Créer répertoire si inexistant
  if (!fs.existsSync(scriptsDir)) {
    fs.mkdirSync(scriptsDir, { recursive: true });
  }

  const scriptPath = path.join(scriptsDir, 'test-timeout.ps1');
  const scriptContent = `
# Test script - Timeout (sleep 35s)
Write-Host "[Test-Timeout] Starting long script..."
Start-Sleep -Seconds 35
Write-Host "[Test-Timeout] Script completed (should timeout before this)"
exit 0
`.trim();
  
  fs.writeFileSync(scriptPath, scriptContent, 'utf8');
  if (logger) logger.log(`[Mock-PS] Script timeout créé : ${scriptPath}`);
  return scriptPath;
}

/**
 * Créer script PowerShell test - Échec (exit code 1)
 */
export function createFailureTestScript(scriptsDir: string, logger?: TestLogger): string {
  // Créer répertoire si inexistant
  if (!fs.existsSync(scriptsDir)) {
    fs.mkdirSync(scriptsDir, { recursive: true });
  }

  const scriptPath = path.join(scriptsDir, 'test-failure.ps1');
  const scriptContent = `
# Test script - Failure (exit 1)
Write-Host "[Test-Failure] Script starting..."
Write-Error "Simulated error"
Write-Host "[Test-Failure] Script failed"
exit 1
`.trim();
  
  fs.writeFileSync(scriptPath, scriptContent, 'utf8');
  if (logger) logger.log(`[Mock-PS] Script failure créé : ${scriptPath}`);
  return scriptPath;
}

/**
 * Créer script PowerShell test - Succès (exit code 0)
 */
export function createSuccessTestScript(scriptsDir: string, logger?: TestLogger): string {
  // Créer répertoire si inexistant
  if (!fs.existsSync(scriptsDir)) {
    fs.mkdirSync(scriptsDir, { recursive: true });
  }

  const scriptPath = path.join(scriptsDir, 'test-success.ps1');
  const scriptContent = `
# Test script - Success (exit 0)
Write-Host "[Test-Success] Script starting..."
Write-Host "[Test-Success] Performing test operations..."
Start-Sleep -Seconds 2
Write-Host "[Test-Success] Script completed successfully"
exit 0
`.trim();
  
  fs.writeFileSync(scriptPath, scriptContent, 'utf8');
  if (logger) logger.log(`[Mock-PS] Script success créé : ${scriptPath}`);
  return scriptPath;
}

/**
 * Créer script PowerShell test - Dry-run mode
 */
export function createDryRunTestScript(scriptsDir: string, logger?: TestLogger): string {
  // Créer répertoire si inexistant
  if (!fs.existsSync(scriptsDir)) {
    fs.mkdirSync(scriptsDir, { recursive: true });
  }

  const scriptPath = path.join(scriptsDir, 'test-dryrun.ps1');
  const scriptContent = `
# Test script - Dry-run mode
param(
  [switch]$DryRun = $false
)

Write-Host "[Test-DryRun] Script starting..."

if ($DryRun) {
  Write-Host "[Test-DryRun] DRY-RUN MODE - No changes will be made"
  Write-Host "[Test-DryRun] Would perform operations here..."
} else {
  Write-Host "[Test-DryRun] PRODUCTION MODE - Making changes..."
  Write-Host "[Test-DryRun] Performing operations..."
}

Write-Host "[Test-DryRun] Script completed"
exit 0
`.trim();
  
  fs.writeFileSync(scriptPath, scriptContent, 'utf8');
  if (logger) logger.log(`[Mock-PS] Script dry-run créé : ${scriptPath}`);
  return scriptPath;
}

/**
 * Nettoyer scripts test
 */
export function cleanupTestScripts(scriptsDir: string, logger?: TestLogger): void {
  if (fs.existsSync(scriptsDir)) {
    const files = fs.readdirSync(scriptsDir);
    for (const file of files) {
      fs.unlinkSync(path.join(scriptsDir, file));
    }
    fs.rmdirSync(scriptsDir);
    if (logger) logger.log(`[Mock-PS] Scripts test nettoyés : ${scriptsDir}`);
  }
}

/**
 * Exécuter script PowerShell avec timeout
 */
export function executeScriptWithTimeout(
  scriptPath: string,
  timeoutMs: number,
  args: string[] = [],
  logger?: TestLogger
): { success: boolean; timedOut: boolean; output: string; exitCode: number | null } {
  const { execSync } = require('child_process');
  
  try {
    const argsString = args.join(' ');
    const command = `pwsh -File "${scriptPath}" ${argsString}`;
    
    if (logger) logger.log(`[Mock-PS] Exécution : ${command}`);
    
    const output = execSync(command, {
      encoding: 'utf-8',
      timeout: timeoutMs,
      stdio: 'pipe'
    });

    if (logger) logger.log(`[Mock-PS] Succès - Output : ${output.trim()}`);
    return { success: true, timedOut: false, output: output.trim(), exitCode: 0 };
  } catch (error: any) {
    if (error.killed && error.signal === 'SIGTERM') {
      // Timeout
      if (logger) logger.log(`[Mock-PS] Timeout après ${timeoutMs}ms`);
      return { success: false, timedOut: true, output: '', exitCode: null };
    } else {
      // Échec script (exit code != 0)
      const exitCode = error.status || 1;
      const output = error.stdout ? error.stdout.toString().trim() : '';
      if (logger) logger.log(`[Mock-PS] Échec - Exit code : ${exitCode}, Output : ${output}`);
      return { success: false, timedOut: false, output, exitCode };
    }
  }
}