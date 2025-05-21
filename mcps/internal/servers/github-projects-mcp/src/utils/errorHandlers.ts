import { McpError, ErrorCode } from '@modelcontextprotocol/sdk/types.js';

/**
 * Configure les gestionnaires d'erreurs pour le serveur MCP
 * @param server Instance du serveur MCP
 */
export function setupErrorHandlers(server: any): void {
  // Gestionnaire d'erreurs pour le serveur
  server.onerror = (error) => {
    console.error('Erreur du serveur MCP:', error);
  };
}

/**
 * Classe d'erreur personnalisée pour les erreurs liées à GitHub Projects
 */
export class GitHubProjectsError extends Error {
  constructor(message: string, public code: string, public details?: any) {
    super(message);
    this.name = 'GitHubProjectsError';
  }
}

/**
 * Fonction utilitaire pour formater les erreurs de l'API GitHub
 * @param error Erreur d'origine
 * @returns Erreur formatée
 */
export function formatGitHubError(error: any): GitHubProjectsError {
  let message = 'Erreur inconnue lors de l\'interaction avec GitHub';
  let code = 'UNKNOWN_ERROR';
  let details = undefined;

  if (error.message) {
    message = error.message;
  }

  if (error.status) {
    code = `HTTP_${error.status}`;
  }

  if (error.errors) {
    details = error.errors;
  }

  return new GitHubProjectsError(message, code, details);
}