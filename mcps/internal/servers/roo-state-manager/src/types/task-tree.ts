/**
 * Types pour l'arborescence de tâches Roo State Manager
 * Phase 1 : Fondations et analyse de l'arborescence de tâches
 */

import { ConversationSummary } from './conversation.js';

// Enums pour les types de nœuds et relations
export enum TaskType {
  WORKSPACE = 'workspace',
  PROJECT = 'project',
  TASK_CLUSTER = 'task_cluster',
  CONVERSATION = 'conversation'
}

export enum RelationshipType {
  PARENT_CHILD = 'parent_child',
  FILE_DEPENDENCY = 'file_dependency',
  TEMPORAL = 'temporal',
  SEMANTIC = 'semantic',
  TECHNOLOGY = 'technology'
}

export enum ComplexityLevel {
  SIMPLE = 'simple',
  MEDIUM = 'medium',
  COMPLEX = 'complex'
}

export enum ProjectStatus {
  ACTIVE = 'active',
  ARCHIVED = 'archived',
  UNKNOWN = 'unknown'
}

export enum ConversationOutcome {
  COMPLETED = 'completed',
  ABANDONED = 'abandoned',
  ONGOING = 'ongoing'
}

// Types de base pour l'arborescence
export interface TreeNode {
  id: string;
  name: string;
  type: TaskType;
  path?: string;
  parent?: TreeNode;
  children?: TreeNode[];
  metadata: NodeMetadata;
  createdAt: string;
  updatedAt: string;
}

export interface NodeMetadata {
  description?: string;
  tags: string[];
  lastActivity: string;
  size: number;
  [key: string]: any;
}

// Types spécialisés pour chaque niveau de l'arborescence
export interface WorkspaceNode extends TreeNode {
  type: TaskType.WORKSPACE;
  children: ProjectNode[];
  metadata: WorkspaceMetadata;
}

export interface ProjectNode extends TreeNode {
  type: TaskType.PROJECT;
  parent: WorkspaceNode;
  children: TaskClusterNode[];
  metadata: ProjectMetadata;
}

export interface TaskClusterNode extends TreeNode {
  type: TaskType.TASK_CLUSTER;
  parent: ProjectNode;
  children: ConversationNode[];
  metadata: ClusterMetadata;
}

export interface ConversationNode extends TreeNode {
  type: TaskType.CONVERSATION;
  parent: TaskClusterNode;
  originalData: ConversationSummary;
  metadata: ConversationMetadata;
}

// Métadonnées spécialisées
export interface WorkspaceMetadata extends NodeMetadata {
  totalConversations: number;
  totalSize: number;
  detectedFrom: string[];
  technologies: string[];
  projectCount: number;
  clusterCount: number;
}

export interface ProjectMetadata extends NodeMetadata {
  conversationCount: number;
  filePatterns: string[];
  technologies: string[];
  complexity: ComplexityLevel;
  status: ProjectStatus;
  clusterCount: number;
  averageClusterSize: number;
}

export interface ClusterMetadata extends NodeMetadata {
  theme: string;
  timespan: { start: string; end: string };
  relatedFiles: string[];
  conversationCount: number;
  averageSize: number;
  dominantTechnology?: string;
  semanticKeywords: string[];
}

export interface ConversationMetadata extends NodeMetadata {
  title: string;
  summary: string;
  dependencies: string[];
  outcome: ConversationOutcome;
  fileReferences: FileReference[];
  messageCount: number;
  hasApiHistory: boolean;
  hasUiMessages: boolean;
  dominantMode?: string;
  estimatedDuration?: number;
}

// Types pour les références de fichiers
export interface FileReference {
  path: string;
  recordState: 'active' | 'stale';
  recordSource: 'read_tool' | 'roo_edited' | 'user_edited';
  lastRead?: string;
  lastModified?: string;
  size?: number;
}

// Types pour les relations entre tâches
export interface TaskRelationship {
  id: string;
  type: RelationshipType;
  source: string; // ID du nœud source
  target: string; // ID du nœud cible
  weight: number; // Force de la relation (0-1)
  metadata: RelationshipMetadata;
  createdAt: string;
}

export interface RelationshipMetadata {
  description?: string;
  confidence: number; // Confiance dans la relation (0-1)
  evidence: string[]; // Preuves de la relation
  [key: string]: any;
}

// Types pour l'analyse de workspace
export interface WorkspaceAnalysis {
  workspaces: WorkspaceCandidate[];
  totalConversations: number;
  analysisMetadata: AnalysisMetadata;
  relationships: TaskRelationship[];
  errors: string[];
}

export interface WorkspaceCandidate {
  path: string;
  name: string;
  confidence: number;
  conversations: ConversationSummary[];
  detectedTechnologies: string[];
  filePatterns: string[];
  commonPrefixes: string[];
}

export interface AnalysisMetadata {
  version: string;
  analyzedAt: string;
  analysisTime: number; // en millisecondes
  algorithmsUsed: string[];
  qualityMetrics: QualityMetrics;
}

export interface QualityMetrics {
  workspaceDetectionAccuracy: number;
  projectClassificationAccuracy: number;
  clusterCoherence: number;
  relationshipConfidence: number;
}

// Types pour les patterns de fichiers et technologies
export interface FilePattern {
  pattern: string;
  count: number;
  examples: string[];
  associatedTechnology?: string;
}

export interface TechStack {
  primary: string[];
  secondary: string[];
  confidence: number;
  evidence: TechStackEvidence[];
}

export interface TechStackEvidence {
  type: 'file_extension' | 'package_file' | 'config_file' | 'directory_structure';
  value: string;
  confidence: number;
}

// Types pour la construction de l'arbre
export interface TaskTree {
  root: TreeNode;
  metadata: TreeMetadata;
  relationships: TaskRelationship[];
  index: TreeIndex;
}

export interface TreeMetadata {
  version: string;
  builtAt: string;
  buildTime: number;
  totalNodes: number;
  maxDepth: number;
  qualityScore: number;
}

export interface TreeIndex {
  byId: Map<string, TreeNode>;
  byType: Map<TaskType, TreeNode[]>;
  byPath: Map<string, TreeNode>;
  byTechnology: Map<string, TreeNode[]>;
  byTimeRange: Map<string, TreeNode[]>;
}

// Types pour les candidats de clustering
export interface ClusterCandidate {
  id: string;
  conversations: ConversationNode[];
  theme: string;
  confidence: number;
  evidence: ClusterEvidence[];
  timespan: { start: string; end: string };
}

export interface ClusterEvidence {
  type: 'semantic' | 'temporal' | 'file_dependency' | 'technology';
  description: string;
  weight: number;
  data: any;
}

// Types pour les patterns de chemin
export interface PathCluster {
  commonPrefix: string;
  paths: string[];
  depth: number;
  confidence: number;
}

export interface CommonPrefix {
  prefix: string;
  count: number;
  paths: string[];
  isWorkspaceCandidate: boolean;
}

// Types pour la structure de projet
export interface ProjectStructure {
  type: 'monorepo' | 'single_project' | 'mixed' | 'unknown';
  directories: DirectoryInfo[];
  confidence: number;
  evidence: string[];
}

export interface DirectoryInfo {
  path: string;
  type: 'source' | 'test' | 'config' | 'docs' | 'build' | 'unknown';
  fileCount: number;
  technologies: string[];
}

// Types pour l'analyse sémantique
export interface SimilarityMatrix {
  conversations: string[];
  matrix: number[][];
  algorithm: string;
  threshold: number;
}

export interface TemporalCluster {
  timeRange: { start: string; end: string };
  conversations: string[];
  intensity: number; // Nombre de conversations par unité de temps
  pattern: 'burst' | 'steady' | 'declining' | 'irregular';
}

// Types pour les groupes de projets
export interface ProjectGroup {
  name: string;
  projects: ProjectCandidate[];
  commonTechnology: string;
  confidence: number;
}

export interface ProjectCandidate {
  name: string;
  path: string;
  conversations: ConversationSummary[];
  technology: TechStack;
  structure: ProjectStructure;
  confidence: number;
}

// Types d'erreur spécifiques à l'arborescence
export class TaskTreeError extends Error {
  constructor(message: string, public code: string) {
    super(message);
    this.name = 'TaskTreeError';
  }
}

export class WorkspaceDetectionError extends TaskTreeError {
  constructor(message: string) {
    super(message, 'WORKSPACE_DETECTION_ERROR');
  }
}

export class ProjectClassificationError extends TaskTreeError {
  constructor(message: string) {
    super(message, 'PROJECT_CLASSIFICATION_ERROR');
  }
}

export class TaskClusteringError extends TaskTreeError {
  constructor(message: string) {
    super(message, 'TASK_CLUSTERING_ERROR');
  }
}

export class TreeBuildError extends TaskTreeError {
  constructor(message: string) {
    super(message, 'TREE_BUILD_ERROR');
  }
}