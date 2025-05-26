/**
 * Gestionnaire de cache pour l'arborescence de tâches
 * Phase 2 : Cache intelligent avec invalidation sélective
 */

import { promises as fs } from 'fs';
import { join } from 'path';
import { TaskTree, TreeNode, TaskType } from '../types/task-tree.js';
import { ConversationSummary } from '../types/conversation.js';

export interface CacheEntry<T = any> {
  data: T;
  timestamp: number;
  version: string;
  dependencies: string[];
  size: number;
}

export interface CacheStats {
  totalEntries: number;
  totalSize: number;
  hitRate: number;
  missRate: number;
  lastCleanup: number;
}

export interface CacheConfig {
  maxSize: number; // Taille max en bytes
  maxAge: number; // Age max en ms
  persistToDisk: boolean;
  cacheDir?: string;
  cleanupInterval: number; // Intervalle de nettoyage en ms
}

export class CacheManager {
  private cache = new Map<string, CacheEntry>();
  private stats = {
    hits: 0,
    misses: 0,
    totalRequests: 0,
    lastCleanup: Date.now()
  };
  
  private config: CacheConfig;
  private cleanupTimer?: NodeJS.Timeout;

  constructor(config: Partial<CacheConfig> = {}) {
    this.config = {
      maxSize: 100 * 1024 * 1024, // 100MB par défaut
      maxAge: 30 * 60 * 1000, // 30 minutes par défaut
      persistToDisk: true,
      cacheDir: join(process.cwd(), '.cache', 'roo-state-manager'),
      cleanupInterval: 5 * 60 * 1000, // 5 minutes
      ...config
    };

    this.startCleanupTimer();
    this.loadFromDisk();
  }

  /**
   * Récupère une entrée du cache
   */
  async get<T>(key: string): Promise<T | null> {
    this.stats.totalRequests++;
    
    const entry = this.cache.get(key);
    if (!entry) {
      this.stats.misses++;
      return null;
    }

    // Vérifier l'expiration
    if (Date.now() - entry.timestamp > this.config.maxAge) {
      this.cache.delete(key);
      this.stats.misses++;
      return null;
    }

    this.stats.hits++;
    return entry.data as T;
  }

  /**
   * Stocke une entrée dans le cache
   */
  async set<T>(
    key: string, 
    data: T, 
    dependencies: string[] = [],
    version: string = '1.0.0'
  ): Promise<void> {
    const size = this.calculateSize(data);
    
    const entry: CacheEntry<T> = {
      data,
      timestamp: Date.now(),
      version,
      dependencies,
      size
    };

    this.cache.set(key, entry);

    // Vérifier la taille totale et nettoyer si nécessaire
    await this.enforceMaxSize();

    // Persister sur disque si configuré
    if (this.config.persistToDisk) {
      await this.persistEntry(key, entry);
    }
  }

  /**
   * Invalide les entrées basées sur les dépendances
   */
  async invalidate(dependency: string): Promise<number> {
    let invalidatedCount = 0;
    
    for (const [key, entry] of this.cache.entries()) {
      if (entry.dependencies.includes(dependency)) {
        this.cache.delete(key);
        invalidatedCount++;
        
        // Supprimer du disque
        if (this.config.persistToDisk) {
          await this.removeFromDisk(key);
        }
      }
    }

    return invalidatedCount;
  }

  /**
   * Invalide les entrées par pattern
   */
  async invalidatePattern(pattern: RegExp): Promise<number> {
    let invalidatedCount = 0;
    
    for (const [key, entry] of this.cache.entries()) {
      if (pattern.test(key)) {
        this.cache.delete(key);
        invalidatedCount++;
        
        if (this.config.persistToDisk) {
          await this.removeFromDisk(key);
        }
      }
    }

    return invalidatedCount;
  }

  /**
   * Cache spécialisé pour l'arborescence de tâches
   */
  async cacheTaskTree(tree: TaskTree, conversations: ConversationSummary[]): Promise<void> {
    const treeKey = 'task-tree:main';
    const conversationsKey = 'conversations:all';
    
    // Créer les dépendances basées sur les chemins des conversations
    const dependencies = conversations.map(conv => `conversation:${conv.taskId}`);
    
    await this.set(treeKey, tree, dependencies, tree.metadata.version);
    await this.set(conversationsKey, conversations, dependencies);
  }

  /**
   * Récupère l'arborescence mise en cache
   */
  async getCachedTaskTree(): Promise<TaskTree | null> {
    return await this.get<TaskTree>('task-tree:main');
  }

  /**
   * Cache les résultats de recherche
   */
  async cacheSearchResults(
    query: string, 
    filters: Record<string, any>, 
    results: any[]
  ): Promise<void> {
    const searchKey = `search:${this.hashQuery(query, filters)}`;
    const dependencies = ['task-tree:main', 'conversations:all'];
    
    await this.set(searchKey, results, dependencies);
  }

  /**
   * Récupère les résultats de recherche mis en cache
   */
  async getCachedSearchResults(
    query: string, 
    filters: Record<string, any>
  ): Promise<any[] | null> {
    const searchKey = `search:${this.hashQuery(query, filters)}`;
    return await this.get<any[]>(searchKey);
  }

  /**
   * Obtient les statistiques du cache
   */
  getStats(): CacheStats {
    const totalSize = Array.from(this.cache.values())
      .reduce((sum, entry) => sum + entry.size, 0);

    return {
      totalEntries: this.cache.size,
      totalSize,
      hitRate: this.stats.totalRequests > 0 ? this.stats.hits / this.stats.totalRequests : 0,
      missRate: this.stats.totalRequests > 0 ? this.stats.misses / this.stats.totalRequests : 0,
      lastCleanup: this.stats.lastCleanup
    };
  }

  /**
   * Nettoie le cache (supprime les entrées expirées)
   */
  async cleanup(): Promise<number> {
    let cleanedCount = 0;
    const now = Date.now();
    
    for (const [key, entry] of this.cache.entries()) {
      if (now - entry.timestamp > this.config.maxAge) {
        this.cache.delete(key);
        cleanedCount++;
        
        if (this.config.persistToDisk) {
          await this.removeFromDisk(key);
        }
      }
    }

    this.stats.lastCleanup = now;
    return cleanedCount;
  }

  /**
   * Vide complètement le cache
   */
  async clear(): Promise<void> {
    this.cache.clear();
    this.stats = {
      hits: 0,
      misses: 0,
      totalRequests: 0,
      lastCleanup: Date.now()
    };

    if (this.config.persistToDisk && this.config.cacheDir) {
      try {
        await fs.rmdir(this.config.cacheDir, { recursive: true });
      } catch (error) {
        // Ignore si le répertoire n'existe pas
      }
    }
  }

  /**
   * Ferme le gestionnaire de cache
   */
  async close(): Promise<void> {
    if (this.cleanupTimer) {
      clearInterval(this.cleanupTimer);
    }
    
    if (this.config.persistToDisk) {
      await this.saveToDisk();
    }
  }

  // Méthodes privées

  private calculateSize(data: any): number {
    return JSON.stringify(data).length * 2; // Approximation UTF-16
  }

  private hashQuery(query: string, filters: Record<string, any>): string {
    const combined = JSON.stringify({ query, filters });
    let hash = 0;
    for (let i = 0; i < combined.length; i++) {
      const char = combined.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // Convert to 32-bit integer
    }
    return Math.abs(hash).toString(36);
  }

  private async enforceMaxSize(): Promise<void> {
    const totalSize = Array.from(this.cache.values())
      .reduce((sum, entry) => sum + entry.size, 0);

    if (totalSize <= this.config.maxSize) {
      return;
    }

    // Trier par timestamp (LRU)
    const entries = Array.from(this.cache.entries())
      .sort(([, a], [, b]) => a.timestamp - b.timestamp);

    let currentSize = totalSize;
    for (const [key, entry] of entries) {
      if (currentSize <= this.config.maxSize * 0.8) { // Garder 20% de marge
        break;
      }
      
      this.cache.delete(key);
      currentSize -= entry.size;
      
      if (this.config.persistToDisk) {
        await this.removeFromDisk(key);
      }
    }
  }

  private startCleanupTimer(): void {
    this.cleanupTimer = setInterval(async () => {
      await this.cleanup();
    }, this.config.cleanupInterval);
  }

  private async loadFromDisk(): Promise<void> {
    if (!this.config.persistToDisk || !this.config.cacheDir) {
      return;
    }

    try {
      const metaPath = join(this.config.cacheDir, 'cache-meta.json');
      const metaData = await fs.readFile(metaPath, 'utf-8');
      const meta = JSON.parse(metaData);
      
      for (const [key, entryMeta] of Object.entries(meta)) {
        try {
          const entryPath = join(this.config.cacheDir, `${key}.json`);
          const entryData = await fs.readFile(entryPath, 'utf-8');
          const entry = JSON.parse(entryData);
          
          // Vérifier l'expiration
          if (Date.now() - entry.timestamp <= this.config.maxAge) {
            this.cache.set(key, entry);
          }
        } catch (error) {
          // Ignorer les entrées corrompues
        }
      }
    } catch (error) {
      // Pas de cache existant, c'est normal
    }
  }

  private async saveToDisk(): Promise<void> {
    if (!this.config.persistToDisk || !this.config.cacheDir) {
      return;
    }

    try {
      await fs.mkdir(this.config.cacheDir, { recursive: true });
      
      const meta: Record<string, any> = {};
      
      for (const [key, entry] of this.cache.entries()) {
        await this.persistEntry(key, entry);
        meta[key] = {
          timestamp: entry.timestamp,
          version: entry.version,
          size: entry.size
        };
      }
      
      const metaPath = join(this.config.cacheDir, 'cache-meta.json');
      await fs.writeFile(metaPath, JSON.stringify(meta, null, 2));
    } catch (error) {
      console.error('Erreur lors de la sauvegarde du cache:', error);
    }
  }

  private async persistEntry(key: string, entry: CacheEntry): Promise<void> {
    if (!this.config.cacheDir) return;
    
    try {
      await fs.mkdir(this.config.cacheDir, { recursive: true });
      const entryPath = join(this.config.cacheDir, `${key.replace(/[^a-zA-Z0-9-_]/g, '_')}.json`);
      await fs.writeFile(entryPath, JSON.stringify(entry, null, 2));
    } catch (error) {
      console.error(`Erreur lors de la persistance de l'entrée ${key}:`, error);
    }
  }

  private async removeFromDisk(key: string): Promise<void> {
    if (!this.config.cacheDir) return;
    
    try {
      const entryPath = join(this.config.cacheDir, `${key.replace(/[^a-zA-Z0-9-_]/g, '_')}.json`);
      await fs.unlink(entryPath);
    } catch (error) {
      // Ignorer si le fichier n'existe pas
    }
  }
}

// Instance singleton pour l'utilisation globale
export const globalCacheManager = new CacheManager();