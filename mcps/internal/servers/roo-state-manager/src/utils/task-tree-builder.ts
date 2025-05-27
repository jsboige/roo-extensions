/**
 * Constructeur d'arbre de tâches pour l'assemblage de la hiérarchie complète
 * Phase 1 : Fondations et analyse de l'arborescence de tâches
 */

import {
  TaskTree,
  TreeNode,
  WorkspaceNode,
  ProjectNode,
  TaskClusterNode,
  ConversationNode,
  TaskType,
  TreeMetadata,
  TreeIndex,
  WorkspaceCandidate,
  ProjectCandidate,
  ClusterCandidate,
  TaskRelationship,
  ComplexityLevel,
  ProjectStatus,
  ConversationOutcome,
  TreeBuildError
} from '../types/task-tree.js';
import { ConversationSummary } from '../types/conversation.js';
import { WorkspaceAnalyzer } from './workspace-analyzer.js';
import { RelationshipAnalyzer } from './relationship-analyzer.js';

export class TaskTreeBuilder {
  private static readonly MAX_TREE_DEPTH = 10;
  private static readonly PERFORMANCE_TARGET_MS = 30000; // 30 secondes
  private static readonly CACHE_ENABLED = true;

  private cache: Map<string, any> = new Map();
  private buildStartTime: number = 0;

  /**
   * Construit l'arbre complet à partir des conversations
   */
  public async buildCompleteTree(conversations: ConversationSummary[]): Promise<TaskTree> {
    this.buildStartTime = Date.now();
    
    try {
      console.error(`[TaskTreeBuilder] Début de construction pour ${conversations.length} conversations`);
      
      // 1. Analyse des workspaces
      const workspaceAnalysis = await this.analyzeWorkspaces(conversations);
      console.error(`[TaskTreeBuilder] ${workspaceAnalysis.workspaces.length} workspaces détectés`);
      
      // 2. Construction des nœuds workspace
      const workspaceNodes = await this.buildWorkspaceNodes(workspaceAnalysis.workspaces);
      console.error(`[TaskTreeBuilder] ${workspaceNodes.length} nœuds workspace créés`);
      
      // 3. Classification et construction des projets
      const projectNodes = await this.buildProjectNodes(workspaceNodes, conversations);
      console.error(`[TaskTreeBuilder] ${projectNodes.length} nœuds projet créés`);
      
      // 4. Clustering et construction des tâches
      const clusterNodes = await this.buildClusterNodes(projectNodes, conversations);
      console.error(`[TaskTreeBuilder] ${clusterNodes.length} nœuds cluster créés`);
      
      // 5. Construction des nœuds conversation
      const conversationNodes = await this.buildConversationNodes(clusterNodes, conversations);
      console.error(`[TaskTreeBuilder] ${conversationNodes.length} nœuds conversation créés`);
      
      // 6. Analyse des relations
      const relationships = await this.analyzeRelationships(conversations);
      console.error(`[TaskTreeBuilder] ${relationships.length} relations détectées`);
      
      // 7. Assemblage de l'arbre final
      const rootNode = this.assembleTree(workspaceNodes);
      
      // 8. Construction de l'index
      const index = this.buildTreeIndex(rootNode);
      
      // 9. Génération des métadonnées
      const metadata = this.generateTreeMetadata(rootNode, relationships);
      
      const buildTime = Date.now() - this.buildStartTime;
      console.error(`[TaskTreeBuilder] Construction terminée en ${buildTime}ms`);
      
      return {
        root: rootNode,
        metadata: {
          ...metadata,
          buildTime
        },
        relationships,
        index
      };
      
    } catch (error) {
      throw new TreeBuildError(
        `Erreur lors de la construction de l'arbre: ${error instanceof Error ? error.message : String(error)}`
      );
    }
  }

  /**
   * Analyse les workspaces avec cache
   */
  private async analyzeWorkspaces(conversations: ConversationSummary[]) {
    const cacheKey = `workspaces_${this.hashConversations(conversations)}`;
    
    if (TaskTreeBuilder.CACHE_ENABLED && this.cache.has(cacheKey)) {
      return this.cache.get(cacheKey);
    }
    
    const analysis = await WorkspaceAnalyzer.analyzeWorkspaces(conversations);
    
    if (TaskTreeBuilder.CACHE_ENABLED) {
      this.cache.set(cacheKey, analysis);
    }
    
    return analysis;
  }

  /**
   * Construit les nœuds workspace
   */
  private async buildWorkspaceNodes(workspaceCandidates: WorkspaceCandidate[]): Promise<WorkspaceNode[]> {
    const workspaceNodes: WorkspaceNode[] = [];
    
    for (const candidate of workspaceCandidates) {
      const workspaceNode: WorkspaceNode = {
        id: `workspace_${this.generateId(candidate.path)}`,
        name: candidate.name,
        type: TaskType.WORKSPACE,
        path: candidate.path,
        children: [], // Sera rempli plus tard
        metadata: {
          description: `Workspace détecté: ${candidate.path}`,
          tags: candidate.detectedTechnologies,
          lastActivity: this.getLatestActivity(candidate.conversations),
          size: candidate.conversations.reduce((sum, conv) => sum + conv.size, 0),
          totalConversations: candidate.conversations.length,
          totalSize: candidate.conversations.reduce((sum, conv) => sum + conv.size, 0),
          detectedFrom: candidate.commonPrefixes,
          technologies: candidate.detectedTechnologies,
          projectCount: 0, // Sera calculé plus tard
          clusterCount: 0  // Sera calculé plus tard
        },
        createdAt: this.getEarliestActivity(candidate.conversations),
        updatedAt: this.getLatestActivity(candidate.conversations)
      };
      
      workspaceNodes.push(workspaceNode);
    }
    
    return workspaceNodes;
  }

  /**
   * Construit les nœuds projet
   */
  private async buildProjectNodes(workspaceNodes: WorkspaceNode[], conversations: ConversationSummary[]): Promise<ProjectNode[]> {
    const projectNodes: ProjectNode[] = [];
    
    for (const workspace of workspaceNodes) {
      const workspaceConversations = conversations.filter(conv =>
        this.belongsToWorkspace(conv, workspace)
      );
      
      // Groupe les conversations par projet (basé sur les patterns de fichiers)
      const projectCandidates = this.detectProjects(workspaceConversations, workspace);
      
      for (const candidate of projectCandidates) {
        const projectNode: ProjectNode = {
          id: `project_${this.generateId(candidate.path)}`,
          name: candidate.name,
          type: TaskType.PROJECT,
          path: candidate.path,
          parent: workspace,
          children: [], // Sera rempli plus tard
          metadata: {
            description: `Projet: ${candidate.name}`,
            tags: candidate.technology.primary,
            lastActivity: this.getLatestActivity(candidate.conversations),
            size: candidate.conversations.reduce((sum, conv) => sum + conv.size, 0),
            conversationCount: candidate.conversations.length,
            filePatterns: this.extractFilePatterns(candidate.conversations),
            technologies: candidate.technology.primary,
            complexity: this.calculateComplexity(candidate.conversations),
            status: this.determineProjectStatus(candidate.conversations),
            clusterCount: 0, // Sera calculé plus tard
            averageClusterSize: 0 // Sera calculé plus tard
          },
          createdAt: this.getEarliestActivity(candidate.conversations),
          updatedAt: this.getLatestActivity(candidate.conversations)
        };
        
        workspace.children.push(projectNode);
        projectNodes.push(projectNode);
      }
      
      // Met à jour le compteur de projets du workspace
      workspace.metadata.projectCount = workspace.children.length;
    }
    
    return projectNodes;
  }

  /**
   * Construit les nœuds cluster
   */
  private async buildClusterNodes(projectNodes: ProjectNode[], conversations: ConversationSummary[]): Promise<TaskClusterNode[]> {
    const clusterNodes: TaskClusterNode[] = [];
    
    for (const project of projectNodes) {
      const projectConversations = conversations.filter(conv =>
        this.belongsToProject(conv, project)
      );
      
      // Clustering des conversations
      const clusterCandidates = this.clusterConversations(projectConversations);
      
      for (const candidate of clusterCandidates) {
        const clusterNode: TaskClusterNode = {
          id: `cluster_${this.generateId(candidate.id)}`,
          name: candidate.theme,
          type: TaskType.TASK_CLUSTER,
          parent: project,
          children: [], // Sera rempli plus tard
          metadata: {
            description: `Cluster: ${candidate.theme}`,
            tags: this.extractClusterTags(candidate),
            lastActivity: candidate.timespan.end,
            size: candidate.conversations.reduce((sum, conv) => sum + conv.originalData.size, 0),
            theme: candidate.theme,
            timespan: candidate.timespan,
            relatedFiles: this.extractRelatedFiles(candidate.conversations),
            conversationCount: candidate.conversations.length,
            averageSize: candidate.conversations.reduce((sum, conv) => sum + conv.originalData.size, 0) / candidate.conversations.length,
            dominantTechnology: this.findDominantTechnology(candidate.conversations),
            semanticKeywords: this.extractSemanticKeywords(candidate)
          },
          createdAt: candidate.timespan.start,
          updatedAt: candidate.timespan.end
        };
        
        project.children.push(clusterNode);
        clusterNodes.push(clusterNode);
      }
      
      // Met à jour les compteurs du projet
      project.metadata.clusterCount = project.children.length;
      project.metadata.averageClusterSize = project.children.length > 0 ?
        project.children.reduce((sum, cluster) => sum + (cluster as TaskClusterNode).metadata.conversationCount, 0) / project.children.length : 0;
      
      // Met à jour le compteur de clusters du workspace
      if (project.parent) {
        project.parent.metadata.clusterCount += project.children.length;
      }
    }
    
    return clusterNodes;
  }

  /**
   * Construit les nœuds conversation
   */
  private async buildConversationNodes(clusterNodes: TaskClusterNode[], conversations: ConversationSummary[]): Promise<ConversationNode[]> {
    const conversationNodes: ConversationNode[] = [];
    
    for (const cluster of clusterNodes) {
      const clusterConversations = conversations.filter(conv =>
        this.belongsToCluster(conv, cluster)
      );
      
      for (const conversation of clusterConversations) {
        const conversationNode: ConversationNode = {
          id: conversation.taskId,
          name: this.generateConversationName(conversation),
          type: TaskType.CONVERSATION,
          parent: cluster,
          originalData: conversation,
          metadata: {
            description: `Conversation: ${conversation.taskId}`,
            tags: this.extractConversationTags(conversation),
            lastActivity: conversation.lastActivity,
            size: conversation.size,
            title: this.extractTitle(conversation),
            summary: this.generateSummary(conversation),
            dependencies: [], // Sera rempli par l'analyse des relations
            outcome: this.determineOutcome(conversation),
            fileReferences: this.convertFileReferences(conversation),
            messageCount: conversation.messageCount,
            hasApiHistory: conversation.hasApiHistory,
            hasUiMessages: conversation.hasUiMessages,
            dominantMode: conversation.metadata?.mode,
            estimatedDuration: this.estimateDuration(conversation)
          },
          createdAt: conversation.metadata?.createdAt || conversation.lastActivity,
          updatedAt: conversation.lastActivity
        };
        
        cluster.children.push(conversationNode);
        conversationNodes.push(conversationNode);
      }
    }
    
    return conversationNodes;
  }

  /**
   * Analyse les relations avec cache
   */
  private async analyzeRelationships(conversations: ConversationSummary[]): Promise<TaskRelationship[]> {
    const cacheKey = `relationships_${this.hashConversations(conversations)}`;
    
    if (TaskTreeBuilder.CACHE_ENABLED && this.cache.has(cacheKey)) {
      return this.cache.get(cacheKey);
    }
    
    const relationships = await RelationshipAnalyzer.analyzeRelationships(conversations);
    
    if (TaskTreeBuilder.CACHE_ENABLED) {
      this.cache.set(cacheKey, relationships);
    }
    
    return relationships;
  }

  /**
   * Assemble l'arbre final
   */
  private assembleTree(workspaceNodes: WorkspaceNode[]): TreeNode {
    if (workspaceNodes.length === 1) {
      return workspaceNodes[0];
    }
    
    // Crée un nœud racine si plusieurs workspaces
    const rootNode: TreeNode = {
      id: 'root',
      name: 'Roo State Manager',
      type: TaskType.WORKSPACE,
      children: workspaceNodes,
      metadata: {
        description: 'Nœud racine de l\'arborescence Roo',
        tags: [],
        lastActivity: this.getLatestActivityFromNodes(workspaceNodes),
        size: workspaceNodes.reduce((sum, ws) => sum + ws.metadata.size, 0),
        totalConversations: workspaceNodes.reduce((sum, ws) => sum + ws.metadata.totalConversations, 0),
        totalSize: workspaceNodes.reduce((sum, ws) => sum + ws.metadata.totalSize, 0),
        detectedFrom: [],
        technologies: [...new Set(workspaceNodes.flatMap(ws => ws.metadata.technologies))],
        projectCount: workspaceNodes.reduce((sum, ws) => sum + ws.metadata.projectCount, 0),
        clusterCount: workspaceNodes.reduce((sum, ws) => sum + ws.metadata.clusterCount, 0)
      },
      createdAt: this.getEarliestActivityFromNodes(workspaceNodes),
      updatedAt: this.getLatestActivityFromNodes(workspaceNodes)
    };
    
    // Met à jour les parents
    for (const workspace of workspaceNodes) {
      workspace.parent = rootNode;
    }
    
    return rootNode;
  }

  /**
   * Construit l'index de l'arbre
   */
  private buildTreeIndex(rootNode: TreeNode): TreeIndex {
    const byId = new Map<string, TreeNode>();
    const byType = new Map<TaskType, TreeNode[]>();
    const byPath = new Map<string, TreeNode>();
    const byTechnology = new Map<string, TreeNode[]>();
    const byTimeRange = new Map<string, TreeNode[]>();
    
    const traverse = (node: TreeNode) => {
      // Index par ID
      byId.set(node.id, node);
      
      // Index par type
      if (!byType.has(node.type)) {
        byType.set(node.type, []);
      }
      byType.get(node.type)!.push(node);
      
      // Index par chemin
      if (node.path) {
        byPath.set(node.path, node);
      }
      
      // Index par technologie
      if ('technologies' in node.metadata) {
        for (const tech of node.metadata.technologies as string[]) {
          if (!byTechnology.has(tech)) {
            byTechnology.set(tech, []);
          }
          byTechnology.get(tech)!.push(node);
        }
      }
      
      // Index par période (année-mois)
      const timeKey = new Date(node.metadata.lastActivity).toISOString().substring(0, 7);
      if (!byTimeRange.has(timeKey)) {
        byTimeRange.set(timeKey, []);
      }
      byTimeRange.get(timeKey)!.push(node);
      
      // Traverse les enfants
      if (node.children) {
        for (const child of node.children) {
          traverse(child);
        }
      }
    };
    
    traverse(rootNode);
    
    return { byId, byType, byPath, byTechnology, byTimeRange };
  }

  /**
   * Génère les métadonnées de l'arbre
   */
  private generateTreeMetadata(rootNode: TreeNode, relationships: TaskRelationship[]): TreeMetadata {
    const nodeCount = this.countNodes(rootNode);
    const maxDepth = this.calculateMaxDepth(rootNode);
    const qualityScore = this.calculateQualityScore(rootNode, relationships);
    
    return {
      version: '1.0.0',
      builtAt: new Date().toISOString(),
      buildTime: 0, // Sera rempli par l'appelant
      totalNodes: nodeCount,
      maxDepth,
      qualityScore
    };
  }

  // Méthodes utilitaires privées

  private hashConversations(conversations: ConversationSummary[]): string {
    const ids = conversations.map(c => c.taskId).sort().join(',');
    return Buffer.from(ids).toString('base64').substring(0, 16);
  }

  private generateId(input: string): string {
    return Buffer.from(input).toString('base64').replace(/[^a-zA-Z0-9]/g, '').substring(0, 8);
  }

  private getLatestActivity(conversations: ConversationSummary[]): string {
    return conversations.reduce((latest, conv) => 
      conv.lastActivity > latest ? conv.lastActivity : latest, 
      conversations[0]?.lastActivity || new Date().toISOString()
    );
  }

  private getEarliestActivity(conversations: ConversationSummary[]): string {
    return conversations.reduce((earliest, conv) => 
      conv.lastActivity < earliest ? conv.lastActivity : earliest, 
      conversations[0]?.lastActivity || new Date().toISOString()
    );
  }

  private getLatestActivityFromNodes(nodes: TreeNode[]): string {
    return nodes.reduce((latest, node) => 
      node.metadata.lastActivity > latest ? node.metadata.lastActivity : latest, 
      nodes[0]?.metadata.lastActivity || new Date().toISOString()
    );
  }

  private getEarliestActivityFromNodes(nodes: TreeNode[]): string {
    return nodes.reduce((earliest, node) => 
      node.metadata.lastActivity < earliest ? node.metadata.lastActivity : earliest, 
      nodes[0]?.metadata.lastActivity || new Date().toISOString()
    );
  }

  private belongsToWorkspace(conversation: ConversationSummary, workspace: WorkspaceNode): boolean {
    return conversation.metadata?.files_in_context?.some(file => 
      file.path.startsWith(workspace.path || '')
    ) || false;
  }

  private belongsToProject(conversation: ConversationSummary, project: ProjectNode): boolean {
    return conversation.metadata?.files_in_context?.some(file => 
      file.path.startsWith(project.path || '')
    ) || false;
  }

  private belongsToCluster(conversation: ConversationSummary, cluster: TaskClusterNode): boolean {
    // Logique simplifiée - sera améliorée avec le clustering réel
    return true;
  }

  private detectProjects(conversations: ConversationSummary[], workspace: WorkspaceNode): ProjectCandidate[] {
    // Implémentation simplifiée - sera améliorée
    return [{
      name: `${workspace.name} Project`,
      path: workspace.path || '',
      conversations,
      technology: { primary: workspace.metadata.technologies, secondary: [], confidence: 0.8, evidence: [] },
      structure: { type: 'unknown', directories: [], confidence: 0.5, evidence: [] },
      confidence: 0.8
    }];
  }

  private clusterConversations(conversations: ConversationSummary[]): ClusterCandidate[] {
    // Implémentation simplifiée - sera améliorée
    return [{
      id: 'default_cluster',
      conversations: conversations.map(c => ({ 
        id: c.taskId, 
        type: TaskType.CONVERSATION, 
        originalData: c 
      } as ConversationNode)),
      theme: 'Tâches générales',
      confidence: 0.7,
      evidence: [],
      timespan: {
        start: this.getEarliestActivity(conversations),
        end: this.getLatestActivity(conversations)
      }
    }];
  }

  private extractFilePatterns(conversations: ConversationSummary[]): string[] {
    const patterns = new Set<string>();
    for (const conv of conversations) {
      if (conv.metadata?.files_in_context) {
        for (const file of conv.metadata.files_in_context) {
          const ext = file.path.split('.').pop();
          if (ext) patterns.add(`.${ext}`);
        }
      }
    }
    return Array.from(patterns);
  }

  private calculateComplexity(conversations: ConversationSummary[]): ComplexityLevel {
    const avgSize = conversations.reduce((sum, c) => sum + c.size, 0) / conversations.length;
    const avgMessages = conversations.reduce((sum, c) => sum + c.messageCount, 0) / conversations.length;
    
    if (avgSize > 100000 || avgMessages > 50) return ComplexityLevel.COMPLEX;
    if (avgSize > 50000 || avgMessages > 20) return ComplexityLevel.MEDIUM;
    return ComplexityLevel.SIMPLE;
  }

  private determineProjectStatus(conversations: ConversationSummary[]): ProjectStatus {
    const latestActivity = new Date(this.getLatestActivity(conversations));
    const daysSinceActivity = (Date.now() - latestActivity.getTime()) / (1000 * 60 * 60 * 24);
    
    if (daysSinceActivity < 7) return ProjectStatus.ACTIVE;
    if (daysSinceActivity < 30) return ProjectStatus.UNKNOWN;
    return ProjectStatus.ARCHIVED;
  }

  private extractClusterTags(candidate: ClusterCandidate): string[] {
    return candidate.evidence.map(e => e.type);
  }

  private extractRelatedFiles(conversations: ConversationNode[]): string[] {
    const files = new Set<string>();
    for (const conv of conversations) {
      if (conv.originalData.metadata?.files_in_context) {
        for (const file of conv.originalData.metadata.files_in_context) {
          files.add(file.path);
        }
      }
    }
    return Array.from(files).slice(0, 10); // Limite à 10 fichiers
  }

  private findDominantTechnology(conversations: ConversationNode[]): string | undefined {
    const techCount = new Map<string, number>();
    
    for (const conv of conversations) {
      if (conv.originalData.metadata?.files_in_context) {
        for (const file of conv.originalData.metadata.files_in_context) {
          const ext = file.path.split('.').pop();
          if (ext) {
            techCount.set(ext, (techCount.get(ext) || 0) + 1);
          }
        }
      }
    }
    
    let maxCount = 0;
    let dominantTech: string | undefined;
    
    for (const [tech, count] of techCount) {
      if (count > maxCount) {
        maxCount = count;
        dominantTech = tech;
      }
    }
    
    return dominantTech;
  }

  private extractSemanticKeywords(candidate: ClusterCandidate): string[] {
    return candidate.evidence
      .filter(e => e.type === 'semantic')
      .map(e => e.description)
      .slice(0, 5);
  }

  private generateConversationName(conversation: ConversationSummary): string {
    if (conversation.metadata?.title) {
      return conversation.metadata.title;
    }
    
    // Génère un nom basé sur les fichiers
    const files = conversation.metadata?.files_in_context;
    if (files && files.length > 0) {
      const mainFile = files[0].path.split('/').pop() || 'unknown';
      return `Travail sur ${mainFile}`;
    }
    
    return `Conversation ${conversation.taskId.substring(0, 8)}`;
  }

  private extractTitle(conversation: ConversationSummary): string {
    return conversation.metadata?.title || this.generateConversationName(conversation);
  }

  private generateSummary(conversation: ConversationSummary): string {
    const fileCount = conversation.metadata?.files_in_context?.length || 0;
    const sizeKB = Math.round(conversation.size / 1024);
    
    return `Conversation avec ${conversation.messageCount} messages, ${fileCount} fichiers (${sizeKB} KB)`;
  }

  private determineOutcome(conversation: ConversationSummary): ConversationOutcome {
    // Logique simplifiée basée sur l'activité récente
    const daysSinceActivity = (Date.now() - new Date(conversation.lastActivity).getTime()) / (1000 * 60 * 60 * 24);
    
    if (daysSinceActivity < 1) return ConversationOutcome.ONGOING;
    if (daysSinceActivity < 7) return ConversationOutcome.COMPLETED;
    return ConversationOutcome.ABANDONED;
  }

  private convertFileReferences(conversation: ConversationSummary) {
    return conversation.metadata?.files_in_context?.map(file => ({
      path: file.path,
      recordState: file.record_state,
      recordSource: file.record_source,
      lastRead: file.lastRead,
      lastModified: file.lastModified,
      size: file.size
    })) || [];
  }

  private extractConversationTags(conversation: ConversationSummary): string[] {
    const tags: string[] = [];
    
    if (conversation.metadata?.mode) {
      tags.push(conversation.metadata.mode);
    }
    
    if (conversation.hasApiHistory) tags.push('api');
    if (conversation.hasUiMessages) tags.push('ui');
    
    return tags;
  }

  private estimateDuration(conversation: ConversationSummary): number {
    // Estimation basée sur le nombre de messages (5 minutes par message en moyenne)
    return conversation.messageCount * 5;
  }

  private countNodes(node: TreeNode): number {
    let count = 1;
    if (node.children) {
      for (const child of node.children) {
        count += this.countNodes(child);
      }
    }
    return count;
  }

  private calculateMaxDepth(node: TreeNode, currentDepth: number = 0): number {
    let maxDepth = currentDepth;
    if (node.children) {
      for (const child of node.children) {
        const childDepth = this.calculateMaxDepth(child, currentDepth + 1);
        maxDepth = Math.max(maxDepth, childDepth);
      }
    }
    return maxDepth;
  }

  private calculateQualityScore(rootNode: TreeNode, relationships: TaskRelationship[]): number {
    // Score basé sur la distribution des nœuds et la qualité des relations
    const nodeCount = this.countNodes(rootNode);
    const relationshipCount = relationships.length;
    const avgRelationshipWeight = relationships.length > 0 ? 
      relationships.reduce((sum, rel) => sum + rel.weight, 0) / relationships.length : 0;
    
    // Score normalisé entre 0 et 1
    let score = 0;
    
    // Bonus pour un nombre raisonnable de nœuds
    score += Math.min(nodeCount / 1000, 0.3);
    
    // Bonus pour les relations
    score += Math.min(relationshipCount / 100, 0.3);
    
    // Bonus pour la qualité des relations
    score += avgRelationshipWeight * 0.4;
    
    return Math.min(score, 1);
  }
}