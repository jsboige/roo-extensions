/**
 * test-git.ts - Mocks Git pour tests RooSync
 * 
 * Usage:
 * ```typescript
 * import { mockVerifyGitAvailable, mockSafePull, mockSafeCheckout } from './helpers/test-git';
 * 
 * const gitStatus = mockVerifyGitAvailable();
 * const pullResult = mockSafePull('.', 'success');
 * ```
 */

import { execSync } from 'child_process';
import { TestLogger } from './test-logger';

/**
 * Mock verifyGitAvailable() - Vérifie Git dans PATH
 */
export function mockVerifyGitAvailable(logger?: TestLogger): { 
  available: boolean; 
  version: string | null; 
  cached: boolean 
} {
  try {
    const versionOutput = execSync('git --version', { encoding: 'utf-8', stdio: 'pipe' });
    const version = versionOutput.trim();
    if (logger) logger.log(`[Mock-Git] Git disponible : ${version}`);
    return { available: true, version, cached: false };
  } catch (error) {
    if (logger) logger.log(`[Mock-Git] Git NON disponible : ${error}`);
    return { available: false, version: null, cached: false };
  }
}

/**
 * Mock safePull() - Simule git pull avec vérification SHA
 */
export function mockSafePull(
  repoPath: string, 
  simulate: 'success' | 'failure',
  logger?: TestLogger
): { 
  success: boolean; 
  shaBeforePull: string; 
  shaAfterPull: string; 
  rolledBack: boolean 
} {
  try {
    // Récupérer SHA actuel (réel)
    const shaBeforePull = execSync('git rev-parse HEAD', { 
      cwd: repoPath, 
      encoding: 'utf-8', 
      stdio: 'pipe' 
    }).trim();

    if (logger) logger.log(`[Mock-SafePull] SHA avant pull : ${shaBeforePull}`);

    if (simulate === 'failure') {
      if (logger) {
        logger.log(`[Mock-SafePull] Simulation échec pull...`);
        logger.log(`[Mock-SafePull] Rollback à SHA : ${shaBeforePull}`);
      }
      return { 
        success: false, 
        shaBeforePull, 
        shaAfterPull: shaBeforePull, 
        rolledBack: true 
      };
    }

    // Succès (pas de pull réel, simulation)
    if (logger) logger.log(`[Mock-SafePull] Simulation succès pull (pas de pull réel)`);
    return { 
      success: true, 
      shaBeforePull, 
      shaAfterPull: shaBeforePull, // Même SHA (simulation)
      rolledBack: false 
    };
  } catch (error) {
    if (logger) logger.log(`[Mock-SafePull] Erreur : ${error}`);
    throw error;
  }
}

/**
 * Mock safeCheckout() - Simule git checkout avec vérification SHA
 */
export function mockSafeCheckout(
  repoPath: string, 
  branch: string,
  simulate: 'success' | 'failure',
  logger?: TestLogger
): { 
  success: boolean; 
  shaBeforeCheckout: string; 
  shaAfterCheckout: string; 
  rolledBack: boolean 
} {
  try {
    // Récupérer SHA actuel (réel)
    const shaBeforeCheckout = execSync('git rev-parse HEAD', { 
      cwd: repoPath, 
      encoding: 'utf-8', 
      stdio: 'pipe' 
    }).trim();

    if (logger) logger.log(`[Mock-SafeCheckout] SHA avant checkout : ${shaBeforeCheckout}`);

    if (simulate === 'failure') {
      if (logger) {
        logger.log(`[Mock-SafeCheckout] Simulation échec checkout vers ${branch}...`);
        logger.log(`[Mock-SafeCheckout] Rollback à SHA : ${shaBeforeCheckout}`);
      }
      return { 
        success: false, 
        shaBeforeCheckout, 
        shaAfterCheckout: shaBeforeCheckout, 
        rolledBack: true 
      };
    }

    // Succès (pas de checkout réel, simulation)
    if (logger) logger.log(`[Mock-SafeCheckout] Simulation succès checkout vers ${branch} (pas de checkout réel)`);
    return { 
      success: true, 
      shaBeforeCheckout, 
      shaAfterCheckout: shaBeforeCheckout, // Même SHA (simulation)
      rolledBack: false 
    };
  } catch (error) {
    if (logger) logger.log(`[Mock-SafeCheckout] Erreur : ${error}`);
    throw error;
  }
}

/**
 * Récupère le statut Git actuel d'un repo
 */
export function getGitStatus(repoPath: string, logger?: TestLogger): {
  currentBranch: string;
  currentSHA: string;
  isClean: boolean;
} {
  try {
    const currentBranch = execSync('git rev-parse --abbrev-ref HEAD', { 
      cwd: repoPath, 
      encoding: 'utf-8', 
      stdio: 'pipe' 
    }).trim();

    const currentSHA = execSync('git rev-parse HEAD', { 
      cwd: repoPath, 
      encoding: 'utf-8', 
      stdio: 'pipe' 
    }).trim();

    const statusOutput = execSync('git status --porcelain', { 
      cwd: repoPath, 
      encoding: 'utf-8', 
      stdio: 'pipe' 
    }).trim();

    const isClean = statusOutput === '';

    if (logger) {
      logger.log(`[Git-Status] Branch: ${currentBranch}`);
      logger.log(`[Git-Status] SHA: ${currentSHA}`);
      logger.log(`[Git-Status] Clean: ${isClean}`);
    }

    return { currentBranch, currentSHA, isClean };
  } catch (error) {
    if (logger) logger.log(`[Git-Status] Erreur : ${error}`);
    throw error;
  }
}