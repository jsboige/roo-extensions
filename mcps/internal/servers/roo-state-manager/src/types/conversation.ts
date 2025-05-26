/**
 * Types pour la gestion des conversations et du stockage Roo
 * Basés sur les découvertes du stockage Roo existant
 */

// Types pour les messages API (format Anthropic)
export interface ApiMessage {
  role: 'user' | 'assistant';
  content: string | Array<{
    type: 'text' | 'image';
    text?: string;
    source?: {
      type: 'base64';
      media_type: string;
      data: string;
    };
  }>;
  timestamp?: string;
}

export interface ApiConversationHistory {
  messages: ApiMessage[];
  model?: string;
  max_tokens?: number;
  temperature?: number;
}

// Types pour les messages UI (ClineMessage)
export interface ClineMessage {
  id: string;
  type: 'ask' | 'say' | 'completion_result' | 'tool_use' | 'tool_result';
  text?: string;
  tool?: string;
  toolInput?: any;
  toolResult?: any;
  timestamp: string;
  isError?: boolean;
}

export interface UiMessages {
  messages: ClineMessage[];
}

// Types pour les métadonnées de tâche
export interface TaskMetadata {
  taskId: string;
  createdAt: string;
  updatedAt: string;
  title?: string;
  description?: string;
  mode?: string;
  status: 'active' | 'completed' | 'archived';
  totalMessages: number;
  totalTokens?: number;
  cost?: number;
  files_in_context?: FileInContext[];
}

// Type pour les fichiers dans le contexte
export interface FileInContext {
  path: string;
  record_state: 'active' | 'stale';
  record_source: 'read_tool' | 'roo_edited' | 'user_edited';
  lastRead?: string;
  lastModified?: string;
  size?: number;
}

// Types pour l'historique global des tâches
export interface TaskHistoryEntry {
  id: string;
  name: string;
  createdAt: string;
  isRunning: boolean;
  totalCost: number;
}

export interface GlobalTaskHistory {
  tasks: TaskHistoryEntry[];
}

// Types pour la détection du stockage Roo
export interface RooStorageLocation {
  globalStoragePath: string;
  tasksPath: string;
  settingsPath: string;
  exists: boolean;
}

export interface ConversationSummary {
  taskId: string;
  path: string;
  metadata: TaskMetadata | null;
  messageCount: number;
  lastActivity: string;
  hasApiHistory: boolean;
  hasUiMessages: boolean;
  size: number; // taille en octets
}

export interface RooStorageDetectionResult {
  found: boolean;
  locations: RooStorageLocation[];
  conversations: ConversationSummary[];
  totalConversations: number;
  totalSize: number;
  errors: string[];
}

// Types pour les configurations Roo
export interface RooSettings {
  apiKey?: string;
  model?: string;
  maxTokens?: number;
  temperature?: number;
  customInstructions?: string;
  [key: string]: any;
}

export interface RooConfiguration {
  settings: RooSettings;
  modes?: any[];
  servers?: any[];
}

// Types pour les opérations de sauvegarde/restauration
export interface BackupMetadata {
  version: string;
  createdAt: string;
  source: string;
  conversationCount: number;
  totalSize: number;
}

export interface ConversationBackup {
  metadata: BackupMetadata;
  conversations: ConversationSummary[];
  configurations: RooConfiguration;
}

// Types d'erreur spécifiques
export class RooStorageError extends Error {
  constructor(message: string, public code: string) {
    super(message);
    this.name = 'RooStorageError';
  }
}

export class ConversationNotFoundError extends RooStorageError {
  constructor(taskId: string) {
    super(`Conversation with taskId ${taskId} not found`, 'CONVERSATION_NOT_FOUND');
  }
}

export class InvalidStoragePathError extends RooStorageError {
  constructor(path: string) {
    super(`Invalid storage path: ${path}`, 'INVALID_STORAGE_PATH');
  }
}