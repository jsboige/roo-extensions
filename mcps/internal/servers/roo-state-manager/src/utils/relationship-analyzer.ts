/**
 * Analyseur de relations pour la détection des relations entre tâches
 * Phase 1 : Fondations et analyse de l'arborescence de tâches
 */

import * as path from 'path';
import {
  TaskRelationship,
  RelationshipType,
  RelationshipMetadata,
  ConversationNode,
  SimilarityMatrix,
  TemporalCluster,
  TaskTreeError
} from '../types/task-tree.js';
import { ConversationSummary, FileInContext } from '../types/conversation.js';

export class RelationshipAnalyzer {
  private static readonly TEMPORAL_WINDOW_HOURS = 24;
  private static readonly SEMANTIC_SIMILARITY_THRESHOLD = 0.7;
  private static readonly FILE_DEPENDENCY_THRESHOLD = 0.5;
  private static readonly MIN_RELATIONSHIP_CONFIDENCE = 0.6;

  /**
   * Analyse toutes les relations entre conversations
   */
  public static async analyzeRelationships(conversations: ConversationSummary[]): Promise<TaskRelationship[]> {
    const relationships: TaskRelationship[] = [];
    
    try {
      // 1. Relations de dépendance de fichiers
      const fileDependencies = this.analyzeFileDependencies(conversations);
      relationships.push(...fileDependencies);
      
      // 2. Relations temporelles
      const temporalRelations = this.analyzeTemporalPatterns(conversations);
      relationships.push(...temporalRelations);
      
      // 3. Relations sémantiques (basées sur les chemins et noms)
      const semanticRelations = this.analyzeSemanticSimilarity(conversations);
      relationships.push(...semanticRelations);
      
      // 4. Relations technologiques
      const technologyRelations = this.analyzeTechnologyRelations(conversations);
      relationships.push(...technologyRelations);
      
      // 5. Filtrage et déduplication
      return this.filterAndDeduplicateRelationships(relationships);
      
    } catch (error) {
      throw new TaskTreeError(
        `Erreur lors de l'analyse des relations: ${error instanceof Error ? error.message : String(error)}`,
        'RELATIONSHIP_ANALYSIS_ERROR'
      );
    }
  }

  /**
   * Analyse les dépendances de fichiers entre conversations
   */
  private static analyzeFileDependencies(conversations: ConversationSummary[]): TaskRelationship[] {
    const relationships: TaskRelationship[] = [];
    const fileToConversations = new Map<string, ConversationSummary[]>();
    
    // Index des fichiers par conversation
    for (const conversation of conversations) {
      if (conversation.metadata?.files_in_context) {
        for (const file of conversation.metadata.files_in_context) {
          const normalizedPath = path.normalize(file.path);
          if (!fileToConversations.has(normalizedPath)) {
            fileToConversations.set(normalizedPath, []);
          }
          fileToConversations.get(normalizedPath)!.push(conversation);
        }
      }
    }
    
    // Détecte les relations basées sur les fichiers partagés
    for (const [filePath, relatedConversations] of fileToConversations) {
      if (relatedConversations.length < 2) continue;
      
      // Trie par date d'activité
      const sortedConversations = relatedConversations.sort(
        (a, b) => new Date(a.lastActivity).getTime() - new Date(b.lastActivity).getTime()
      );
      
      // Crée des relations entre conversations consécutives
      for (let i = 0; i < sortedConversations.length - 1; i++) {
        const source = sortedConversations[i];
        const target = sortedConversations[i + 1];
        
        const sharedFiles = this.getSharedFiles(source, target);
        const weight = this.calculateFileDependencyWeight(sharedFiles, filePath);
        
        if (weight >= this.FILE_DEPENDENCY_THRESHOLD) {
          relationships.push({
            id: `file_dep_${source.taskId}_${target.taskId}`,
            type: RelationshipType.FILE_DEPENDENCY,
            source: source.taskId,
            target: target.taskId,
            weight,
            metadata: {
              description: `Dépendance via le fichier: ${filePath}`,
              confidence: weight,
              evidence: [`Fichier partagé: ${filePath}`, `Nombre de fichiers partagés: ${sharedFiles.length}`]
            },
            createdAt: new Date().toISOString()
          });
        }
      }
    }
    
    return relationships;
  }

  /**
   * Analyse les patterns temporels entre conversations
   */
  private static analyzeTemporalPatterns(conversations: ConversationSummary[]): TaskRelationship[] {
    const relationships: TaskRelationship[] = [];
    
    // Trie les conversations par date
    const sortedConversations = conversations.sort(
      (a, b) => new Date(a.lastActivity).getTime() - new Date(b.lastActivity).getTime()
    );
    
    // Détecte les clusters temporels
    const temporalClusters = this.createTemporalClusters(sortedConversations);
    
    for (const cluster of temporalClusters) {
      const clusterConversations = cluster.conversations.map(id => 
        conversations.find(c => c.taskId === id)!
      );
      
      // Crée des relations temporelles dans le cluster
      for (let i = 0; i < clusterConversations.length - 1; i++) {
        const source = clusterConversations[i];
        const target = clusterConversations[i + 1];
        
        const timeDiff = new Date(target.lastActivity).getTime() - new Date(source.lastActivity).getTime();
        const weight = this.calculateTemporalWeight(timeDiff, cluster.intensity);
        
        if (weight >= this.MIN_RELATIONSHIP_CONFIDENCE) {
          relationships.push({
            id: `temporal_${source.taskId}_${target.taskId}`,
            type: RelationshipType.TEMPORAL,
            source: source.taskId,
            target: target.taskId,
            weight,
            metadata: {
              description: `Relation temporelle (${Math.round(timeDiff / (1000 * 60 * 60))}h d'écart)`,
              confidence: weight,
              evidence: [
                `Écart temporel: ${Math.round(timeDiff / (1000 * 60 * 60))} heures`,
                `Intensité du cluster: ${cluster.intensity.toFixed(2)}`
              ]
            },
            createdAt: new Date().toISOString()
          });
        }
      }
    }
    
    return relationships;
  }

  /**
   * Analyse la similarité sémantique entre conversations
   */
  private static analyzeSemanticSimilarity(conversations: ConversationSummary[]): TaskRelationship[] {
    const relationships: TaskRelationship[] = [];
    
    // Calcule la matrice de similarité
    const similarityMatrix = this.calculateSimilarityMatrix(conversations);
    
    for (let i = 0; i < conversations.length; i++) {
      for (let j = i + 1; j < conversations.length; j++) {
        const similarity = similarityMatrix.matrix[i][j];
        
        if (similarity >= this.SEMANTIC_SIMILARITY_THRESHOLD) {
          const source = conversations[i];
          const target = conversations[j];
          
          relationships.push({
            id: `semantic_${source.taskId}_${target.taskId}`,
            type: RelationshipType.SEMANTIC,
            source: source.taskId,
            target: target.taskId,
            weight: similarity,
            metadata: {
              description: `Similarité sémantique élevée (${(similarity * 100).toFixed(1)}%)`,
              confidence: similarity,
              evidence: this.getSemanticEvidence(source, target)
            },
            createdAt: new Date().toISOString()
          });
        }
      }
    }
    
    return relationships;
  }

  /**
   * Analyse les relations basées sur la technologie
   */
  private static analyzeTechnologyRelations(conversations: ConversationSummary[]): TaskRelationship[] {
    const relationships: TaskRelationship[] = [];
    const techGroups = new Map<string, ConversationSummary[]>();
    
    // Groupe les conversations par technologie
    for (const conversation of conversations) {
      const technologies = this.extractTechnologies(conversation);
      
      for (const tech of technologies) {
        if (!techGroups.has(tech)) {
          techGroups.set(tech, []);
        }
        techGroups.get(tech)!.push(conversation);
      }
    }
    
    // Crée des relations technologiques
    for (const [technology, techConversations] of techGroups) {
      if (techConversations.length < 2) continue;
      
      // Crée des relations entre toutes les conversations de la même technologie
      for (let i = 0; i < techConversations.length; i++) {
        for (let j = i + 1; j < techConversations.length; j++) {
          const source = techConversations[i];
          const target = techConversations[j];
          
          const weight = this.calculateTechnologyWeight(source, target, technology);
          
          if (weight >= this.MIN_RELATIONSHIP_CONFIDENCE) {
            relationships.push({
              id: `tech_${source.taskId}_${target.taskId}`,
              type: RelationshipType.TECHNOLOGY,
              source: source.taskId,
              target: target.taskId,
              weight,
              metadata: {
                description: `Relation technologique: ${technology}`,
                confidence: weight,
                evidence: [`Technologie commune: ${technology}`]
              },
              createdAt: new Date().toISOString()
            });
          }
        }
      }
    }
    
    return relationships;
  }

  /**
   * Obtient les fichiers partagés entre deux conversations
   */
  private static getSharedFiles(conv1: ConversationSummary, conv2: ConversationSummary): string[] {
    const files1 = new Set(
      conv1.metadata?.files_in_context?.map(f => path.normalize(f.path)) || []
    );
    const files2 = conv2.metadata?.files_in_context?.map(f => path.normalize(f.path)) || [];
    
    return files2.filter(file => files1.has(file));
  }

  /**
   * Calcule le poids d'une dépendance de fichier
   */
  private static calculateFileDependencyWeight(sharedFiles: string[], primaryFile: string): number {
    let weight = 0;
    
    // Poids de base pour le fichier principal
    weight += 0.5;
    
    // Bonus pour les fichiers partagés supplémentaires
    weight += Math.min(sharedFiles.length * 0.1, 0.3);
    
    // Bonus pour les fichiers importants (config, package.json, etc.)
    const importantFiles = ['package.json', 'requirements.txt', 'pom.xml', 'Cargo.toml'];
    if (importantFiles.some(important => primaryFile.includes(important))) {
      weight += 0.2;
    }
    
    return Math.min(weight, 1);
  }

  /**
   * Crée des clusters temporels
   */
  private static createTemporalClusters(sortedConversations: ConversationSummary[]): TemporalCluster[] {
    const clusters: TemporalCluster[] = [];
    let currentCluster: string[] = [];
    let clusterStart: string = '';
    
    for (let i = 0; i < sortedConversations.length; i++) {
      const conversation = sortedConversations[i];
      const currentTime = new Date(conversation.lastActivity);
      
      if (currentCluster.length === 0) {
        // Début d'un nouveau cluster
        currentCluster = [conversation.taskId];
        clusterStart = conversation.lastActivity;
      } else {
        // Vérifie si la conversation appartient au cluster actuel
        const clusterStartTime = new Date(clusterStart);
        const timeDiff = currentTime.getTime() - clusterStartTime.getTime();
        const hoursDiff = timeDiff / (1000 * 60 * 60);
        
        if (hoursDiff <= this.TEMPORAL_WINDOW_HOURS) {
          currentCluster.push(conversation.taskId);
        } else {
          // Finalise le cluster actuel
          if (currentCluster.length >= 2) {
            clusters.push({
              timeRange: { start: clusterStart, end: sortedConversations[i - 1].lastActivity },
              conversations: [...currentCluster],
              intensity: currentCluster.length / hoursDiff,
              pattern: this.determineTemporalPattern(currentCluster.length, hoursDiff)
            });
          }
          
          // Commence un nouveau cluster
          currentCluster = [conversation.taskId];
          clusterStart = conversation.lastActivity;
        }
      }
    }
    
    // Finalise le dernier cluster
    if (currentCluster.length >= 2) {
      clusters.push({
        timeRange: { start: clusterStart, end: sortedConversations[sortedConversations.length - 1].lastActivity },
        conversations: currentCluster,
        intensity: currentCluster.length / this.TEMPORAL_WINDOW_HOURS,
        pattern: this.determineTemporalPattern(currentCluster.length, this.TEMPORAL_WINDOW_HOURS)
      });
    }
    
    return clusters;
  }

  /**
   * Détermine le pattern temporel
   */
  private static determineTemporalPattern(conversationCount: number, timeSpanHours: number): 'burst' | 'steady' | 'declining' | 'irregular' {
    const intensity = conversationCount / timeSpanHours;
    
    if (intensity > 2) return 'burst';
    if (intensity > 0.5) return 'steady';
    if (intensity > 0.1) return 'declining';
    return 'irregular';
  }

  /**
   * Calcule le poids temporel
   */
  private static calculateTemporalWeight(timeDiffMs: number, clusterIntensity: number): number {
    const hours = timeDiffMs / (1000 * 60 * 60);
    
    // Plus l'écart est petit, plus le poids est élevé
    let weight = Math.max(0, 1 - (hours / this.TEMPORAL_WINDOW_HOURS));
    
    // Bonus pour l'intensité du cluster
    weight += Math.min(clusterIntensity * 0.1, 0.2);
    
    return Math.min(weight, 1);
  }

  /**
   * Calcule la matrice de similarité sémantique
   */
  private static calculateSimilarityMatrix(conversations: ConversationSummary[]): SimilarityMatrix {
    const matrix: number[][] = [];
    
    for (let i = 0; i < conversations.length; i++) {
      matrix[i] = [];
      for (let j = 0; j < conversations.length; j++) {
        if (i === j) {
          matrix[i][j] = 1;
        } else {
          matrix[i][j] = this.calculateSemanticSimilarity(conversations[i], conversations[j]);
        }
      }
    }
    
    return {
      conversations: conversations.map(c => c.taskId),
      matrix,
      algorithm: 'path_and_metadata_similarity',
      threshold: this.SEMANTIC_SIMILARITY_THRESHOLD
    };
  }

  /**
   * Calcule la similarité sémantique entre deux conversations
   */
  private static calculateSemanticSimilarity(conv1: ConversationSummary, conv2: ConversationSummary): number {
    let similarity = 0;
    
    // Similarité des chemins de fichiers
    const pathSimilarity = this.calculatePathSimilarity(conv1, conv2);
    similarity += pathSimilarity * 0.4;
    
    // Similarité des métadonnées
    const metadataSimilarity = this.calculateMetadataSimilarity(conv1, conv2);
    similarity += metadataSimilarity * 0.3;
    
    // Similarité temporelle
    const temporalSimilarity = this.calculateTemporalSimilarity(conv1, conv2);
    similarity += temporalSimilarity * 0.3;
    
    return Math.min(similarity, 1);
  }

  /**
   * Calcule la similarité des chemins
   */
  private static calculatePathSimilarity(conv1: ConversationSummary, conv2: ConversationSummary): number {
    const paths1 = conv1.metadata?.files_in_context?.map(f => f.path) || [];
    const paths2 = conv2.metadata?.files_in_context?.map(f => f.path) || [];
    
    if (paths1.length === 0 && paths2.length === 0) return 0;
    if (paths1.length === 0 || paths2.length === 0) return 0;
    
    const commonPaths = paths1.filter(p1 => paths2.some(p2 => p1 === p2));
    const totalPaths = new Set([...paths1, ...paths2]).size;
    
    return commonPaths.length / totalPaths;
  }

  /**
   * Calcule la similarité des métadonnées
   */
  private static calculateMetadataSimilarity(conv1: ConversationSummary, conv2: ConversationSummary): number {
    let similarity = 0;
    let factors = 0;
    
    // Mode similaire
    if (conv1.metadata?.mode && conv2.metadata?.mode) {
      factors++;
      if (conv1.metadata.mode === conv2.metadata.mode) {
        similarity += 1;
      }
    }
    
    // Taille similaire
    factors++;
    const sizeDiff = Math.abs(conv1.size - conv2.size);
    const maxSize = Math.max(conv1.size, conv2.size);
    similarity += maxSize > 0 ? 1 - (sizeDiff / maxSize) : 1;
    
    return factors > 0 ? similarity / factors : 0;
  }

  /**
   * Calcule la similarité temporelle
   */
  private static calculateTemporalSimilarity(conv1: ConversationSummary, conv2: ConversationSummary): number {
    const time1 = new Date(conv1.lastActivity).getTime();
    const time2 = new Date(conv2.lastActivity).getTime();
    const timeDiff = Math.abs(time1 - time2);
    const hoursDiff = timeDiff / (1000 * 60 * 60);
    
    // Plus proche temporellement = plus similaire
    return Math.max(0, 1 - (hoursDiff / (this.TEMPORAL_WINDOW_HOURS * 7))); // 7 jours max
  }

  /**
   * Extrait les technologies d'une conversation
   */
  private static extractTechnologies(conversation: ConversationSummary): string[] {
    const technologies = new Set<string>();
    
    if (conversation.metadata?.files_in_context) {
      for (const file of conversation.metadata.files_in_context) {
        const ext = path.extname(file.path).toLowerCase();
        const tech = this.extensionToTechnology(ext);
        if (tech) {
          technologies.add(tech);
        }
      }
    }
    
    return Array.from(technologies);
  }

  /**
   * Mappe une extension à une technologie
   */
  private static extensionToTechnology(extension: string): string | null {
    const mapping: Record<string, string> = {
      '.js': 'javascript',
      '.jsx': 'javascript',
      '.ts': 'typescript',
      '.tsx': 'typescript',
      '.py': 'python',
      '.java': 'java',
      '.cs': 'csharp',
      '.cpp': 'cpp',
      '.c': 'cpp',
      '.rs': 'rust',
      '.go': 'go',
      '.php': 'php',
      '.rb': 'ruby',
      '.swift': 'swift',
      '.kt': 'kotlin',
      '.dart': 'dart'
    };
    
    return mapping[extension] || null;
  }

  /**
   * Calcule le poids d'une relation technologique
   */
  private static calculateTechnologyWeight(conv1: ConversationSummary, conv2: ConversationSummary, technology: string): number {
    const tech1 = this.extractTechnologies(conv1);
    const tech2 = this.extractTechnologies(conv2);
    
    const commonTechs = tech1.filter(t => tech2.includes(t));
    const totalTechs = new Set([...tech1, ...tech2]).size;
    
    let weight = commonTechs.length / Math.max(totalTechs, 1);
    
    // Bonus si la technologie spécifique est dominante
    const tech1Count = tech1.filter(t => t === technology).length;
    const tech2Count = tech2.filter(t => t === technology).length;
    
    if (tech1Count > 0 && tech2Count > 0) {
      weight += 0.2;
    }
    
    return Math.min(weight, 1);
  }

  /**
   * Obtient les preuves sémantiques
   */
  private static getSemanticEvidence(conv1: ConversationSummary, conv2: ConversationSummary): string[] {
    const evidence: string[] = [];
    
    const sharedFiles = this.getSharedFiles(conv1, conv2);
    if (sharedFiles.length > 0) {
      evidence.push(`Fichiers partagés: ${sharedFiles.length}`);
    }
    
    if (conv1.metadata?.mode === conv2.metadata?.mode && conv1.metadata?.mode) {
      evidence.push(`Mode commun: ${conv1.metadata.mode}`);
    }
    
    const timeDiff = Math.abs(
      new Date(conv1.lastActivity).getTime() - new Date(conv2.lastActivity).getTime()
    );
    const hoursDiff = timeDiff / (1000 * 60 * 60);
    
    if (hoursDiff < this.TEMPORAL_WINDOW_HOURS) {
      evidence.push(`Proximité temporelle: ${Math.round(hoursDiff)}h`);
    }
    
    return evidence;
  }

  /**
   * Filtre et déduplique les relations
   */
  private static filterAndDeduplicateRelationships(relationships: TaskRelationship[]): TaskRelationship[] {
    const filtered = relationships.filter(rel => rel.weight >= this.MIN_RELATIONSHIP_CONFIDENCE);
    
    // Déduplique par paire source-target
    const deduped = new Map<string, TaskRelationship>();
    
    for (const relationship of filtered) {
      const key = `${relationship.source}-${relationship.target}`;
      const reverseKey = `${relationship.target}-${relationship.source}`;
      
      if (!deduped.has(key) && !deduped.has(reverseKey)) {
        deduped.set(key, relationship);
      } else {
        // Garde la relation avec le poids le plus élevé
        const existing = deduped.get(key) || deduped.get(reverseKey);
        if (existing && relationship.weight > existing.weight) {
          deduped.delete(key);
          deduped.delete(reverseKey);
          deduped.set(key, relationship);
        }
      }
    }
    
    return Array.from(deduped.values()).sort((a, b) => b.weight - a.weight);
  }
}