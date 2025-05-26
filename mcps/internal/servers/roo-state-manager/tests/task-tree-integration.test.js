/**
 * Tests d'intégration pour la Phase 1 de l'arborescence de tâches
 * Test simple en JavaScript pour validation rapide
 */

import { TaskTreeBuilder } from '../src/utils/task-tree-builder.js';
import { WorkspaceAnalyzer } from '../src/utils/workspace-analyzer.js';
import { RelationshipAnalyzer } from '../src/utils/relationship-analyzer.js';

// Données de test mockées
const createMockConversation = (taskId, files = [], lastActivity = new Date().toISOString()) => ({
  taskId,
  path: `/mock/path/${taskId}`,
  metadata: {
    taskId,
    createdAt: lastActivity,
    updatedAt: lastActivity,
    status: 'completed',
    totalMessages: 10,
    files_in_context: files.map(path => ({
      path,
      record_state: 'active',
      record_source: 'read_tool'
    }))
  },
  messageCount: 10,
  lastActivity,
  hasApiHistory: true,
  hasUiMessages: true,
  size: 1000
});

describe('Task Tree Integration Tests', () => {
  test('should analyze workspaces from conversations', async () => {
    const conversations = [
      createMockConversation('conv1', [
        'project1/package.json',
        'project1/src/index.js',
        'project1/src/utils.js'
      ]),
      createMockConversation('conv2', [
        'project1/src/components/App.jsx',
        'project1/tests/app.test.js'
      ]),
      createMockConversation('conv3', [
        'project2/requirements.txt',
        'project2/main.py'
      ])
    ];

    const analysis = await WorkspaceAnalyzer.analyzeWorkspaces(conversations);

    expect(analysis).toBeDefined();
    expect(analysis.totalConversations).toBe(3);
    expect(analysis.workspaces).toBeDefined();
    expect(Array.isArray(analysis.workspaces)).toBe(true);
    expect(analysis.analysisMetadata).toBeDefined();
    expect(analysis.analysisMetadata.analysisTime).toBeGreaterThan(0);
  });

  test('should analyze relationships between conversations', async () => {
    const conversations = [
      createMockConversation('conv1', [
        'shared/utils.js',
        'project/src/index.js'
      ], '2025-01-01T10:00:00Z'),
      createMockConversation('conv2', [
        'shared/utils.js',
        'project/src/app.js'
      ], '2025-01-01T11:00:00Z'),
      createMockConversation('conv3', [
        'other/file.py'
      ], '2025-01-02T10:00:00Z')
    ];

    const relationships = await RelationshipAnalyzer.analyzeRelationships(conversations);

    expect(relationships).toBeDefined();
    expect(Array.isArray(relationships)).toBe(true);
    
    // Devrait détecter des relations de dépendance de fichiers
    const fileDependencies = relationships.filter(rel => rel.type === 'file_dependency');
    expect(fileDependencies.length).toBeGreaterThan(0);
    
    // Devrait détecter des relations temporelles
    const temporalRelations = relationships.filter(rel => rel.type === 'temporal');
    expect(temporalRelations.length).toBeGreaterThan(0);
  });

  test('should build complete task tree', async () => {
    const conversations = [
      createMockConversation('conv1', [
        'frontend/package.json',
        'frontend/src/App.js',
        'frontend/src/components/Header.js'
      ]),
      createMockConversation('conv2', [
        'frontend/src/utils.js',
        'frontend/tests/App.test.js'
      ]),
      createMockConversation('conv3', [
        'backend/requirements.txt',
        'backend/app.py',
        'backend/models.py'
      ])
    ];

    const builder = new TaskTreeBuilder();
    const tree = await builder.buildCompleteTree(conversations);

    expect(tree).toBeDefined();
    expect(tree.root).toBeDefined();
    expect(tree.metadata).toBeDefined();
    expect(tree.relationships).toBeDefined();
    expect(tree.index).toBeDefined();

    // Vérifications de la structure
    expect(tree.metadata.totalNodes).toBeGreaterThan(0);
    expect(tree.metadata.buildTime).toBeGreaterThan(0);
    expect(tree.metadata.version).toBe('1.0.0');

    // Vérifications de l'index
    expect(tree.index.byId).toBeDefined();
    expect(tree.index.byType).toBeDefined();
    expect(tree.index.byPath).toBeDefined();
    expect(tree.index.byTechnology).toBeDefined();
    expect(tree.index.byTimeRange).toBeDefined();

    console.log('Tree built successfully:');
    console.log(`- Total nodes: ${tree.metadata.totalNodes}`);
    console.log(`- Max depth: ${tree.metadata.maxDepth}`);
    console.log(`- Build time: ${tree.metadata.buildTime}ms`);
    console.log(`- Quality score: ${tree.metadata.qualityScore}`);
    console.log(`- Relationships: ${tree.relationships.length}`);
  });

  test('should handle performance requirements', async () => {
    // Génère un dataset plus large pour tester les performances
    const conversations = [];
    
    for (let i = 0; i < 50; i++) {
      conversations.push(
        createMockConversation(`conv${i}`, [
          `project${i % 5}/src/file${i}.js`,
          `project${i % 5}/package.json`,
          `shared/utils${i % 3}.js`
        ])
      );
    }

    const startTime = Date.now();
    
    const builder = new TaskTreeBuilder();
    const tree = await builder.buildCompleteTree(conversations);
    
    const totalTime = Date.now() - startTime;

    expect(tree).toBeDefined();
    expect(totalTime).toBeLessThan(10000); // Moins de 10 secondes pour 50 conversations
    expect(tree.metadata.buildTime).toBeLessThan(10000);

    console.log(`Performance test completed in ${totalTime}ms for ${conversations.length} conversations`);
  });

  test('should handle edge cases gracefully', async () => {
    // Test avec des conversations vides
    let builder = new TaskTreeBuilder();
    let tree = await builder.buildCompleteTree([]);
    
    expect(tree).toBeDefined();
    expect(tree.metadata.totalNodes).toBeGreaterThanOrEqual(1); // Au moins le nœud racine

    // Test avec des conversations sans fichiers
    const emptyConversations = [
      createMockConversation('conv1', []),
      createMockConversation('conv2', [])
    ];

    tree = await builder.buildCompleteTree(emptyConversations);
    expect(tree).toBeDefined();
    expect(tree.metadata.totalNodes).toBeGreaterThanOrEqual(1);
  });

  test('should maintain data integrity', async () => {
    const conversations = [
      createMockConversation('conv1', ['project/src/index.js']),
      createMockConversation('conv2', ['project/src/utils.js'])
    ];

    const builder = new TaskTreeBuilder();
    const tree = await builder.buildCompleteTree(conversations);

    // Vérifications d'intégrité
    expect(tree.root.id).toBeDefined();
    expect(tree.root.name).toBeDefined();
    expect(tree.root.type).toBeDefined();
    expect(tree.root.metadata).toBeDefined();
    expect(tree.root.createdAt).toBeDefined();
    expect(tree.root.updatedAt).toBeDefined();

    // Vérifications de cohérence des relations parent-enfant
    const traverseAndCheck = (node, parent = null) => {
      if (parent) {
        expect(node.parent).toBe(parent);
      }
      
      if (node.children) {
        for (const child of node.children) {
          traverseAndCheck(child, node);
        }
      }
    };

    traverseAndCheck(tree.root);

    // Vérifications de l'index
    const allNodes = [];
    const collectNodes = (node) => {
      allNodes.push(node);
      if (node.children) {
        node.children.forEach(collectNodes);
      }
    };
    collectNodes(tree.root);

    expect(tree.index.byId.size).toBe(allNodes.length);
    
    for (const node of allNodes) {
      expect(tree.index.byId.get(node.id)).toBe(node);
    }
  });
});