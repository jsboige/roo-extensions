/**
 * Détecteur automatique du stockage Roo
 * Identifie et analyse les emplacements de stockage des conversations Roo
 */

import * as fs from 'fs/promises';
import * as path from 'path';
import * as os from 'os';
import { glob } from 'glob';
import {
  RooStorageLocation,
  ConversationSummary,
  RooStorageDetectionResult,
  TaskMetadata,
  RooStorageError,
  InvalidStoragePathError
} from '../types/conversation.js';

export class RooStorageDetector {
  private static readonly COMMON_ROO_PATHS = [
    // Chemins VSCode typiques
    path.join(os.homedir(), '.vscode', 'extensions'),
    path.join(os.homedir(), '.vscode-insiders', 'extensions'),
    path.join(os.homedir(), 'AppData', 'Roaming', 'Code', 'User', 'globalStorage'),
    path.join(os.homedir(), 'AppData', 'Roaming', 'Code - Insiders', 'User', 'globalStorage'),
    // Chemins Linux/Mac
    path.join(os.homedir(), '.config', 'Code', 'User', 'globalStorage'),
    path.join(os.homedir(), 'Library', 'Application Support', 'Code', 'User', 'globalStorage'),
  ];

  private static readonly ROO_EXTENSION_PATTERNS = [
    '**/saoudrizwan.claude-dev-*',
    '**/claude-dev*',
    '**/roo*',
    '**/cline*'
  ];

  /**
   * Détecte automatiquement les emplacements de stockage Roo
   */
  public static async detectRooStorage(): Promise<RooStorageDetectionResult> {
    const result: RooStorageDetectionResult = {
      found: false,
      locations: [],
      conversations: [],
      totalConversations: 0,
      totalSize: 0,
      errors: []
    };

    try {
      // 1. Recherche des emplacements potentiels
      const potentialLocations = await this.findPotentialStorageLocations();
      
      // 2. Validation des emplacements trouvés
      for (const location of potentialLocations) {
        try {
          const validatedLocation = await this.validateStorageLocation(location);
          if (validatedLocation.exists) {
            result.locations.push(validatedLocation);
            result.found = true;
          }
        } catch (error) {
          result.errors.push(`Erreur lors de la validation de ${location}: ${error instanceof Error ? error.message : String(error)}`);
        }
      }

      // 3. Scan des conversations dans les emplacements valides
      for (const location of result.locations) {
        try {
          const conversations = await this.scanConversations(location.tasksPath);
          result.conversations.push(...conversations);
        } catch (error) {
          result.errors.push(`Erreur lors du scan de ${location.tasksPath}: ${error instanceof Error ? error.message : String(error)}`);
        }
      }

      // 4. Calcul des statistiques
      result.totalConversations = result.conversations.length;
      result.totalSize = result.conversations.reduce((sum, conv) => sum + conv.size, 0);

    } catch (error) {
      result.errors.push(`Erreur générale de détection: ${error instanceof Error ? error.message : String(error)}`);
    }

    return result;
  }

  /**
   * Recherche les emplacements potentiels de stockage Roo
   */
  private static async findPotentialStorageLocations(): Promise<string[]> {
    const locations: string[] = [];

    // Recherche dans les chemins communs
    for (const basePath of this.COMMON_ROO_PATHS) {
      try {
        await fs.access(basePath);
        
        // Recherche des extensions Roo/Claude
        for (const pattern of this.ROO_EXTENSION_PATTERNS) {
          try {
            const matches = await glob(pattern, {
              cwd: basePath,
              absolute: true
            });
            
            // Filtrer pour ne garder que les répertoires
            for (const match of matches) {
              try {
                const stats = await fs.stat(match);
                if (stats.isDirectory()) {
                  locations.push(match);
                }
              } catch (error) {
                // Ignore les erreurs d'accès aux fichiers
              }
            }
          } catch (error) {
            // Ignore les erreurs de glob pour des patterns spécifiques
          }
        }
      } catch (error) {
        // Le chemin n'existe pas, on continue
      }
    }

    // Recherche dans le répertoire courant et ses parents
    let currentDir = process.cwd();
    for (let i = 0; i < 5; i++) { // Limite à 5 niveaux
      const potentialPath = path.join(currentDir, '.vscode', 'extensions');
      try {
        await fs.access(potentialPath);
        locations.push(potentialPath);
      } catch (error) {
        // Pas trouvé à ce niveau
      }
      
      const parentDir = path.dirname(currentDir);
      if (parentDir === currentDir) break; // Racine atteinte
      currentDir = parentDir;
    }

    return [...new Set(locations)]; // Supprime les doublons
  }

  /**
   * Valide un emplacement de stockage potentiel
   */
  private static async validateStorageLocation(extensionPath: string): Promise<RooStorageLocation> {
    const location: RooStorageLocation = {
      globalStoragePath: extensionPath,
      tasksPath: path.join(extensionPath, 'tasks'),
      settingsPath: path.join(extensionPath, 'settings'),
      exists: false
    };

    try {
      // Vérification de l'existence du répertoire tasks
      const tasksStats = await fs.stat(location.tasksPath);
      if (tasksStats.isDirectory()) {
        location.exists = true;
      }
    } catch (error) {
      // Le répertoire tasks n'existe pas
    }

    return location;
  }

  /**
   * Scanne les conversations dans un répertoire de tâches
   */
  private static async scanConversations(tasksPath: string): Promise<ConversationSummary[]> {
    const conversations: ConversationSummary[] = [];

    try {
      const taskDirs = await fs.readdir(tasksPath);
      
      for (const taskId of taskDirs) {
        const taskPath = path.join(tasksPath, taskId);
        
        try {
          const stats = await fs.stat(taskPath);
          if (!stats.isDirectory()) continue;

          const conversation = await this.analyzeConversation(taskId, taskPath);
          if (conversation) {
            conversations.push(conversation);
          }
        } catch (error) {
          // Ignore les erreurs pour des tâches individuelles
        }
      }
    } catch (error) {
      throw new RooStorageError(`Impossible de lire le répertoire des tâches: ${error instanceof Error ? error.message : String(error)}`, 'TASKS_READ_ERROR');
    }

    return conversations;
  }

  /**
   * Analyse une conversation individuelle
   */
  private static async analyzeConversation(taskId: string, taskPath: string): Promise<ConversationSummary | null> {
    const apiHistoryPath = path.join(taskPath, 'api_conversation_history.json');
    const uiMessagesPath = path.join(taskPath, 'ui_messages.json');
    const metadataPath = path.join(taskPath, 'task_metadata.json');

    let metadata: TaskMetadata | null = null;
    let messageCount = 0;
    let lastActivity = '';
    let hasApiHistory = false;
    let hasUiMessages = false;
    let totalSize = 0;

    try {
      // Lecture des métadonnées
      try {
        const metadataContent = await fs.readFile(metadataPath, 'utf-8');
        metadata = JSON.parse(metadataContent);
      } catch (error) {
        // Pas de métadonnées, on continue
      }

      // Vérification de l'historique API
      try {
        const apiStats = await fs.stat(apiHistoryPath);
        hasApiHistory = true;
        totalSize += apiStats.size;
        lastActivity = apiStats.mtime.toISOString();

        const apiContent = await fs.readFile(apiHistoryPath, 'utf-8');
        const apiHistory = JSON.parse(apiContent);
        if (apiHistory.messages) {
          messageCount += apiHistory.messages.length;
        }
      } catch (error) {
        // Pas d'historique API
      }

      // Vérification des messages UI
      try {
        const uiStats = await fs.stat(uiMessagesPath);
        hasUiMessages = true;
        totalSize += uiStats.size;
        
        if (!lastActivity || uiStats.mtime > new Date(lastActivity)) {
          lastActivity = uiStats.mtime.toISOString();
        }

        const uiContent = await fs.readFile(uiMessagesPath, 'utf-8');
        const uiMessages = JSON.parse(uiContent);
        if (uiMessages.messages) {
          messageCount += uiMessages.messages.length;
        }
      } catch (error) {
        // Pas de messages UI
      }

      // Si aucun fichier de conversation n'existe, on ignore cette tâche
      if (!hasApiHistory && !hasUiMessages) {
        return null;
      }

      return {
        taskId,
        path: taskPath,
        metadata,
        messageCount,
        lastActivity: lastActivity || new Date().toISOString(),
        hasApiHistory,
        hasUiMessages,
        size: totalSize
      };

    } catch (error) {
      throw new RooStorageError(`Erreur lors de l'analyse de la conversation ${taskId}: ${error instanceof Error ? error.message : String(error)}`, 'CONVERSATION_ANALYSIS_ERROR');
    }
  }

  /**
   * Recherche une conversation spécifique par ID
   */
  public static async findConversation(taskId: string): Promise<ConversationSummary | null> {
    const detection = await this.detectRooStorage();
    return detection.conversations.find(conv => conv.taskId === taskId) || null;
  }

  /**
   * Obtient les statistiques de stockage Roo
   */
  public static async getStorageStats(): Promise<{
    totalLocations: number;
    totalConversations: number;
    totalSize: number;
    oldestConversation: string | null;
    newestConversation: string | null;
  }> {
    const detection = await this.detectRooStorage();
    
    let oldestDate: Date | null = null;
    let newestDate: Date | null = null;
    let oldestId: string | null = null;
    let newestId: string | null = null;

    for (const conv of detection.conversations) {
      const date = new Date(conv.lastActivity);
      
      if (!oldestDate || date < oldestDate) {
        oldestDate = date;
        oldestId = conv.taskId;
      }
      
      if (!newestDate || date > newestDate) {
        newestDate = date;
        newestId = conv.taskId;
      }
    }

    return {
      totalLocations: detection.locations.length,
      totalConversations: detection.totalConversations,
      totalSize: detection.totalSize,
      oldestConversation: oldestId,
      newestConversation: newestId
    };
  }

  /**
   * Valide un chemin de stockage personnalisé
   */
  public static async validateCustomPath(customPath: string): Promise<boolean> {
    try {
      const normalizedPath = path.resolve(customPath);
      const tasksPath = path.join(normalizedPath, 'tasks');
      
      const stats = await fs.stat(tasksPath);
      return stats.isDirectory();
    } catch (error) {
      return false;
    }
  }
}