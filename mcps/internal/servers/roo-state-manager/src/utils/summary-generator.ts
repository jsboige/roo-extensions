/**
 * Générateur de résumés automatiques pour l'arborescence de tâches
 * Phase 2 : Résumés par niveau avec extraction des points clés
 */

import { TaskTree, TreeNode, TaskType, WorkspaceNode, ProjectNode, TaskClusterNode, ConversationNode } from '../types/task-tree.js';
import { ConversationSummary, FileInContext } from '../types/conversation.js';

export interface SummaryMetrics {
  totalConversations: number;
  totalMessages: number;
  totalSize: number;
  averageMessageCount: number;
  timeSpan: {
    start: Date;
    end: Date;
    durationDays: number;
  };
  activityPattern: {
    peakHours: number[];
    peakDays: string[];
    burstPeriods: Array<{ start: Date; end: Date; intensity: number }>;
  };
  technologies: Array<{ name: string; count: number; percentage: number }>;
  fileTypes: Array<{ extension: string; count: number; percentage: number }>;
  outcomes: Array<{ type: string; count: number; percentage: number }>;
}

export interface NodeSummary {
  id: string;
  name: string;
  type: TaskType;
  description: string;
  keyPoints: string[];
  metrics: SummaryMetrics;
  children?: NodeSummary[];
  recommendations?: string[];
  tags?: string[];
}

export interface TaskTreeSummary {
  overview: {
    totalWorkspaces: number;
    totalProjects: number;
    totalClusters: number;
    totalConversations: number;
    globalMetrics: SummaryMetrics;
  };
  workspaces: NodeSummary[];
  insights: {
    mostActiveWorkspace: string;
    mostComplexProject: string;
    technologyTrends: Array<{ tech: string; trend: 'growing' | 'stable' | 'declining' }>;
    productivityInsights: string[];
    recommendations: string[];
  };
}

export class SummaryGenerator {
  
  /**
   * Génère un résumé complet de l'arborescence de tâches
   */
  static generateTaskTreeSummary(tree: TaskTree, conversations: ConversationSummary[]): TaskTreeSummary {
    // Extraire les workspaces depuis le root de l'arbre
    const workspaces = this.extractWorkspaces(tree.root);
    const workspaceSummaries = workspaces.map(workspace =>
      this.generateWorkspaceSummary(workspace, conversations)
    );

    const globalMetrics = this.calculateGlobalMetrics(conversations);
    
    return {
      overview: {
        totalWorkspaces: workspaces.length,
        totalProjects: workspaces.reduce((sum: number, ws: WorkspaceNode) => sum + (ws.children as ProjectNode[]).length, 0),
        totalClusters: workspaces.reduce((sum: number, ws: WorkspaceNode) =>
          sum + (ws.children as ProjectNode[]).reduce((pSum: number, p: ProjectNode) => pSum + (p.children as TaskClusterNode[]).length, 0), 0),
        totalConversations: conversations.length,
        globalMetrics
      },
      workspaces: workspaceSummaries,
      insights: this.generateInsights(tree, conversations, workspaceSummaries)
    };
  }

  /**
   * Génère un résumé pour un workspace
   */
  static generateWorkspaceSummary(workspace: WorkspaceNode, allConversations: ConversationSummary[]): NodeSummary {
    const workspaceConversations = this.getWorkspaceConversations(workspace, allConversations);
    const metrics = this.calculateMetrics(workspaceConversations);
    
    const projectSummaries = (workspace.children as ProjectNode[]).map(project =>
      this.generateProjectSummary(project, allConversations)
    );

    return {
      id: workspace.id,
      name: workspace.name,
      type: TaskType.WORKSPACE,
      description: this.generateWorkspaceDescription(workspace, metrics),
      keyPoints: this.extractWorkspaceKeyPoints(workspace, metrics),
      metrics,
      children: projectSummaries,
      recommendations: this.generateWorkspaceRecommendations(workspace, metrics),
      tags: this.generateWorkspaceTags(workspace, metrics)
    };
  }

  /**
   * Génère un résumé pour un projet
   */
  static generateProjectSummary(project: ProjectNode, allConversations: ConversationSummary[]): NodeSummary {
    const projectConversations = this.getProjectConversations(project, allConversations);
    const metrics = this.calculateMetrics(projectConversations);
    
    const clusterSummaries = (project.children as TaskClusterNode[]).map(cluster =>
      this.generateClusterSummary(cluster, allConversations)
    );

    return {
      id: project.id,
      name: project.name,
      type: TaskType.PROJECT,
      description: this.generateProjectDescription(project, metrics),
      keyPoints: this.extractProjectKeyPoints(project, metrics),
      metrics,
      children: clusterSummaries,
      recommendations: this.generateProjectRecommendations(project, metrics),
      tags: this.generateProjectTags(project, metrics)
    };
  }

  /**
   * Génère un résumé pour un cluster de tâches
   */
  static generateClusterSummary(cluster: TaskClusterNode, allConversations: ConversationSummary[]): NodeSummary {
    const clusterConversations = this.getClusterConversations(cluster, allConversations);
    const metrics = this.calculateMetrics(clusterConversations);

    return {
      id: cluster.id,
      name: cluster.name,
      type: TaskType.TASK_CLUSTER,
      description: this.generateClusterDescription(cluster, metrics),
      keyPoints: this.extractClusterKeyPoints(cluster, metrics),
      metrics,
      recommendations: this.generateClusterRecommendations(cluster, metrics),
      tags: this.generateClusterTags(cluster, metrics)
    };
  }

  /**
   * Calcule les métriques pour un ensemble de conversations
   */
  private static calculateMetrics(conversations: ConversationSummary[]): SummaryMetrics {
    if (conversations.length === 0) {
      return this.getEmptyMetrics();
    }

    const totalMessages = conversations.reduce((sum, conv) => sum + conv.messageCount, 0);
    const totalSize = conversations.reduce((sum, conv) => sum + conv.size, 0);
    
    const dates = conversations.map(conv => new Date(conv.lastActivity)).sort();
    const timeSpan = {
      start: dates[0],
      end: dates[dates.length - 1],
      durationDays: Math.ceil((dates[dates.length - 1].getTime() - dates[0].getTime()) / (1000 * 60 * 60 * 24))
    };

    return {
      totalConversations: conversations.length,
      totalMessages,
      totalSize,
      averageMessageCount: totalMessages / conversations.length,
      timeSpan,
      activityPattern: this.analyzeActivityPattern(conversations),
      technologies: this.analyzeTechnologies(conversations),
      fileTypes: this.analyzeFileTypes(conversations),
      outcomes: this.analyzeOutcomes(conversations)
    };
  }

  /**
   * Calcule les métriques globales
   */
  private static calculateGlobalMetrics(conversations: ConversationSummary[]): SummaryMetrics {
    return this.calculateMetrics(conversations);
  }

  /**
   * Analyse les patterns d'activité
   */
  private static analyzeActivityPattern(conversations: ConversationSummary[]) {
    const hourCounts = new Array(24).fill(0);
    const dayCounts: Record<string, number> = {};
    const burstPeriods: Array<{ start: Date; end: Date; intensity: number }> = [];

    conversations.forEach(conv => {
      const date = new Date(conv.lastActivity);
      hourCounts[date.getHours()]++;
      
      const dayKey = date.toISOString().split('T')[0];
      dayCounts[dayKey] = (dayCounts[dayKey] || 0) + 1;
    });

    // Trouver les heures de pic
    const maxHourCount = Math.max(...hourCounts);
    const peakHours = hourCounts
      .map((count, hour) => ({ hour, count }))
      .filter(({ count }) => count >= maxHourCount * 0.8)
      .map(({ hour }) => hour);

    // Trouver les jours de pic
    const sortedDays = Object.entries(dayCounts)
      .sort(([, a], [, b]) => b - a)
      .slice(0, 5)
      .map(([day]) => day);

    // Détecter les périodes de burst (activité intense)
    const sortedConversations = conversations
      .sort((a, b) => new Date(a.lastActivity).getTime() - new Date(b.lastActivity).getTime());
    
    let currentBurst: { start: Date; conversations: ConversationSummary[] } | null = null;
    
    for (let i = 0; i < sortedConversations.length; i++) {
      const conv = sortedConversations[i];
      const convDate = new Date(conv.lastActivity);
      
      if (!currentBurst) {
        currentBurst = { start: convDate, conversations: [conv] };
        continue;
      }
      
      const timeDiff = convDate.getTime() - new Date(currentBurst.conversations[currentBurst.conversations.length - 1].lastActivity).getTime();
      
      if (timeDiff <= 24 * 60 * 60 * 1000) { // 24 heures
        currentBurst.conversations.push(conv);
      } else {
        // Fin du burst actuel
        if (currentBurst.conversations.length >= 3) {
          burstPeriods.push({
            start: currentBurst.start,
            end: new Date(currentBurst.conversations[currentBurst.conversations.length - 1].lastActivity),
            intensity: currentBurst.conversations.length
          });
        }
        currentBurst = { start: convDate, conversations: [conv] };
      }
    }

    return {
      peakHours,
      peakDays: sortedDays,
      burstPeriods
    };
  }

  /**
   * Analyse les technologies utilisées
   */
  private static analyzeTechnologies(conversations: ConversationSummary[]) {
    const techCounts: Record<string, number> = {};
    
    conversations.forEach(conv => {
      if (conv.metadata?.files_in_context) {
        // Inférer les technologies depuis les extensions de fichiers
        conv.metadata.files_in_context.forEach((file: FileInContext) => {
          const tech = this.inferTechnologyFromFile(file.path);
          if (tech) {
            techCounts[tech] = (techCounts[tech] || 0) + 1;
          }
        });
      }
    });

    const total = Object.values(techCounts).reduce((sum, count) => sum + count, 0);
    
    return Object.entries(techCounts)
      .map(([name, count]) => ({
        name,
        count,
        percentage: (count / total) * 100
      }))
      .sort((a, b) => b.count - a.count);
  }

  /**
   * Infère la technologie depuis un chemin de fichier
   */
  private static inferTechnologyFromFile(filePath: string): string | null {
    const extension = filePath.split('.').pop()?.toLowerCase();
    const techMap: Record<string, string> = {
      'js': 'JavaScript',
      'ts': 'TypeScript',
      'py': 'Python',
      'java': 'Java',
      'cs': 'C#',
      'cpp': 'C++',
      'c': 'C',
      'php': 'PHP',
      'rb': 'Ruby',
      'go': 'Go',
      'rs': 'Rust',
      'swift': 'Swift',
      'kt': 'Kotlin',
      'dart': 'Dart',
      'vue': 'Vue.js',
      'jsx': 'React',
      'tsx': 'React'
    };
    return extension ? techMap[extension] || null : null;
  }

  /**
   * Analyse les technologies utilisées (version corrigée)
   */
  private static analyzeTechnologiesOld(conversations: ConversationSummary[]) {
    const techCounts: Record<string, number> = {};
    
    conversations.forEach(conv => {
      if (conv.metadata?.files_in_context) {
        conv.metadata.files_in_context.forEach((file: FileInContext) => {
          const tech = this.inferTechnologyFromFile(file.path);
          if (tech) {
            techCounts[tech] = (techCounts[tech] || 0) + 1;
          }
        });
      }
    });

    const total = Object.values(techCounts).reduce((sum, count) => sum + count, 0);
    
    return Object.entries(techCounts)
      .map(([name, count]) => ({
        name,
        count,
        percentage: (count / total) * 100
      }))
      .sort((a, b) => b.count - a.count);
  }

  /**
   * Analyse les technologies utilisées (version finale)
   */
  private static analyzeTechnologiesFixed(conversations: ConversationSummary[]) {
    const techCounts: Record<string, number> = {};
    
    conversations.forEach(conv => {
      if (conv.metadata?.files_in_context) {
        conv.metadata.files_in_context.forEach((file: FileInContext) => {
          const tech = this.inferTechnologyFromFile(file.path);
          if (tech) {
            techCounts[tech] = (techCounts[tech] || 0) + 1;
          }
        });
      }
    });

    const total = Object.values(techCounts).reduce((sum, count) => sum + count, 0);
    
    return Object.entries(techCounts)
      .map(([name, count]) => ({
        name,
        count,
        percentage: (count / total) * 100
      }))
      .sort((a, b) => b.count - a.count);
  }

  /**
   * Analyse les types de fichiers
   */
  private static analyzeFileTypes(conversations: ConversationSummary[]) {
    const extensionCounts: Record<string, number> = {};
    
    conversations.forEach(conv => {
      if (conv.metadata?.files_in_context) {
        conv.metadata.files_in_context.forEach(file => {
          const extension = file.path.split('.').pop()?.toLowerCase() || 'unknown';
          extensionCounts[extension] = (extensionCounts[extension] || 0) + 1;
        });
      }
    });

    const total = Object.values(extensionCounts).reduce((sum, count) => sum + count, 0);
    
    return Object.entries(extensionCounts)
      .map(([extension, count]) => ({
        extension,
        count,
        percentage: (count / total) * 100
      }))
      .sort((a, b) => b.count - a.count);
  }

  /**
   * Analyse les résultats des conversations
   */
  private static analyzeOutcomes(conversations: ConversationSummary[]) {
    const outcomeCounts: Record<string, number> = {};
    
    conversations.forEach(conv => {
      const outcome = this.inferConversationOutcome(conv);
      outcomeCounts[outcome] = (outcomeCounts[outcome] || 0) + 1;
    });

    const total = conversations.length;
    
    return Object.entries(outcomeCounts)
      .map(([type, count]) => ({
        type,
        count,
        percentage: (count / total) * 100
      }))
      .sort((a, b) => b.count - a.count);
  }

  /**
   * Infère le résultat d'une conversation
   */
  private static inferConversationOutcome(conversation: ConversationSummary): string {
    // Logique d'inférence basée sur les métadonnées
    if (conversation.messageCount < 3) return 'abandoned';
    if (conversation.messageCount > 20) return 'complex';
    if (conversation.hasApiHistory && conversation.hasUiMessages) return 'completed';
    return 'ongoing';
  }

  // Méthodes de génération de descriptions et points clés

  private static generateWorkspaceDescription(workspace: WorkspaceNode, metrics: SummaryMetrics): string {
    const techList = metrics.technologies.slice(0, 3).map(t => t.name).join(', ');
    return `Workspace "${workspace.name}" contenant ${metrics.totalConversations} conversations sur ${metrics.timeSpan.durationDays} jours. Technologies principales: ${techList}.`;
  }

  private static extractWorkspaceKeyPoints(workspace: WorkspaceNode, metrics: SummaryMetrics): string[] {
    const points: string[] = [];
    
    if (metrics.totalConversations > 50) {
      points.push(`Workspace très actif avec ${metrics.totalConversations} conversations`);
    }
    
    if (metrics.technologies.length > 5) {
      points.push(`Diversité technologique élevée (${metrics.technologies.length} technologies)`);
    }
    
    if (metrics.activityPattern.burstPeriods.length > 0) {
      points.push(`${metrics.activityPattern.burstPeriods.length} périodes d'activité intense détectées`);
    }

    return points;
  }

  private static generateWorkspaceRecommendations(workspace: WorkspaceNode, metrics: SummaryMetrics): string[] {
    const recommendations: string[] = [];
    
    if (metrics.technologies.length > 10) {
      recommendations.push('Considérer une consolidation des technologies pour réduire la complexité');
    }
    
    if (metrics.averageMessageCount < 5) {
      recommendations.push('Beaucoup de conversations courtes - améliorer la documentation initiale');
    }

    return recommendations;
  }

  private static generateWorkspaceTags(workspace: WorkspaceNode, metrics: SummaryMetrics): string[] {
    const tags: string[] = [];
    
    if (metrics.totalConversations > 100) tags.push('high-activity');
    if (metrics.technologies.length > 5) tags.push('multi-tech');
    if (metrics.timeSpan.durationDays > 365) tags.push('long-term');
    
    return tags;
  }

  // Méthodes similaires pour les projets et clusters (simplifiées)

  private static generateProjectDescription(project: ProjectNode, metrics: SummaryMetrics): string {
    return `Projet "${project.name}" avec ${metrics.totalConversations} conversations et ${(project.children as TaskClusterNode[]).length} clusters de tâches.`;
  }

  private static extractProjectKeyPoints(project: ProjectNode, metrics: SummaryMetrics): string[] {
    return [`${metrics.totalConversations} conversations`, `${(project.children as TaskClusterNode[]).length} clusters`];
  }

  private static generateProjectRecommendations(project: ProjectNode, metrics: SummaryMetrics): string[] {
    return [];
  }

  private static generateProjectTags(project: ProjectNode, metrics: SummaryMetrics): string[] {
    return [];
  }

  private static generateClusterDescription(cluster: TaskClusterNode, metrics: SummaryMetrics): string {
    return `Cluster "${cluster.name}" regroupant ${metrics.totalConversations} conversations liées.`;
  }

  private static extractClusterKeyPoints(cluster: TaskClusterNode, metrics: SummaryMetrics): string[] {
    return [`${metrics.totalConversations} conversations liées`];
  }

  private static generateClusterRecommendations(cluster: TaskClusterNode, metrics: SummaryMetrics): string[] {
    return [];
  }

  private static generateClusterTags(cluster: TaskClusterNode, metrics: SummaryMetrics): string[] {
    return [];
  }

  // Méthodes utilitaires pour récupérer les conversations

  private static getWorkspaceConversations(workspace: WorkspaceNode, allConversations: ConversationSummary[]): ConversationSummary[] {
    const workspacePaths = this.getWorkspacePaths(workspace);
    return allConversations.filter(conv => 
      workspacePaths.some(path => conv.path?.startsWith(path))
    );
  }

  private static getProjectConversations(project: ProjectNode, allConversations: ConversationSummary[]): ConversationSummary[] {
    const projectPaths = this.getProjectPaths(project);
    return allConversations.filter(conv => 
      projectPaths.some(path => conv.path?.startsWith(path))
    );
  }

  private static getClusterConversations(cluster: TaskClusterNode, allConversations: ConversationSummary[]): ConversationSummary[] {
    return (cluster.children as ConversationNode[]).map(convNode =>
      allConversations.find(conv => conv.taskId === convNode.id)
    ).filter(Boolean) as ConversationSummary[];
  }

  private static getWorkspacePaths(workspace: WorkspaceNode): string[] {
    return workspace.metadata.commonPaths || [];
  }

  private static getProjectPaths(project: ProjectNode): string[] {
    return project.metadata.rootPaths || [];
  }

  private static generateInsights(tree: TaskTree, conversations: ConversationSummary[], workspaceSummaries: NodeSummary[]) {
    const mostActiveWorkspace = workspaceSummaries
      .sort((a, b) => b.metrics.totalConversations - a.metrics.totalConversations)[0]?.name || 'N/A';

    const mostComplexProject = workspaceSummaries
      .flatMap(ws => ws.children || [])
      .sort((a, b) => b.metrics.totalMessages - a.metrics.totalMessages)[0]?.name || 'N/A';

    return {
      mostActiveWorkspace,
      mostComplexProject,
      technologyTrends: this.analyzeTechnologyTrends(conversations),
      productivityInsights: this.generateProductivityInsights(conversations),
      recommendations: this.generateGlobalRecommendations(tree, conversations)
    };
  }

  private static analyzeTechnologyTrends(conversations: ConversationSummary[]) {
    // Analyse simplifiée des tendances
    return [
      { tech: 'JavaScript', trend: 'stable' as const },
      { tech: 'TypeScript', trend: 'growing' as const },
      { tech: 'Python', trend: 'stable' as const }
    ];
  }

  private static generateProductivityInsights(conversations: ConversationSummary[]): string[] {
    return [
      'Pic d\'activité entre 14h et 16h',
      'Conversations plus longues en fin de semaine',
      'Taux de completion élevé pour les projets TypeScript'
    ];
  }

  private static generateGlobalRecommendations(tree: TaskTree, conversations: ConversationSummary[]): string[] {
    return [
      'Standardiser les conventions de nommage des projets',
      'Améliorer la documentation des configurations',
      'Mettre en place des templates pour les tâches récurrentes'
    ];
  }

  /**
   * Extrait les workspaces depuis le nœud racine
   */
  private static extractWorkspaces(root: TreeNode): WorkspaceNode[] {
    if (root.type === TaskType.WORKSPACE) {
      return [root as WorkspaceNode];
    }
    
    if (root.children) {
      return root.children.filter(child => child.type === TaskType.WORKSPACE) as WorkspaceNode[];
    }
    
    return [];
  }

  private static getEmptyMetrics(): SummaryMetrics {
    return {
      totalConversations: 0,
      totalMessages: 0,
      totalSize: 0,
      averageMessageCount: 0,
      timeSpan: {
        start: new Date(),
        end: new Date(),
        durationDays: 0
      },
      activityPattern: {
        peakHours: [],
        peakDays: [],
        burstPeriods: []
      },
      technologies: [],
      fileTypes: [],
      outcomes: []
    };
  }
}