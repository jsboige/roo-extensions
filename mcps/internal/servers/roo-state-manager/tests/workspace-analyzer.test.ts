/**
 * Tests unitaires pour WorkspaceAnalyzer
 * Phase 1 : Fondations et analyse de l'arborescence de tâches
 */

import { WorkspaceAnalyzer } from '../src/utils/workspace-analyzer.js';
import { ConversationSummary, TaskMetadata, FileInContext } from '../src/types/conversation.js';

describe('WorkspaceAnalyzer', () => {
  // Données de test mockées
  const createMockConversation = (
    taskId: string,
    files: FileInContext[],
    lastActivity: string = new Date().toISOString(),
    size: number = 1000
  ): ConversationSummary => ({
    taskId,
    path: `/mock/path/${taskId}`,
    metadata: {
      taskId,
      createdAt: lastActivity,
      updatedAt: lastActivity,
      status: 'completed',
      totalMessages: 10,
      files_in_context: files
    } as TaskMetadata,
    messageCount: 10,
    lastActivity,
    hasApiHistory: true,
    hasUiMessages: true,
    size
  });

  const createMockFile = (path: string): FileInContext => ({
    path,
    record_state: 'active',
    record_source: 'read_tool'
  });

  describe('analyzeWorkspaces', () => {
    it('should detect JavaScript workspace from package.json files', async () => {
      const conversations = [
        createMockConversation('conv1', [
          createMockFile('project1/package.json'),
          createMockFile('project1/src/index.js'),
          createMockFile('project1/src/utils.js')
        ]),
        createMockConversation('conv2', [
          createMockFile('project1/src/components/App.jsx'),
          createMockFile('project1/tests/app.test.js')
        ]),
        createMockConversation('conv3', [
          createMockFile('project1/README.md'),
          createMockFile('project1/src/api.ts')
        ])
      ];

      const analysis = await WorkspaceAnalyzer.analyzeWorkspaces(conversations);

      expect(analysis.workspaces).toHaveLength(1);
      expect(analysis.workspaces[0].name).toContain('Project1');
      expect(analysis.workspaces[0].detectedTechnologies).toContain('javascript');
      expect(analysis.workspaces[0].conversations).toHaveLength(3);
      expect(analysis.workspaces[0].confidence).toBeGreaterThan(0.6);
    });

    it('should detect Python workspace from requirements.txt', async () => {
      const conversations = [
        createMockConversation('conv1', [
          createMockFile('python-app/requirements.txt'),
          createMockFile('python-app/main.py'),
          createMockFile('python-app/utils.py')
        ]),
        createMockConversation('conv2', [
          createMockFile('python-app/tests/test_main.py'),
          createMockFile('python-app/src/models.py')
        ])
      ];

      const analysis = await WorkspaceAnalyzer.analyzeWorkspaces(conversations);

      expect(analysis.workspaces).toHaveLength(1);
      expect(analysis.workspaces[0].detectedTechnologies).toContain('python');
      expect(analysis.workspaces[0].conversations).toHaveLength(2);
    });

    it('should detect multiple workspaces', async () => {
      const conversations = [
        createMockConversation('conv1', [
          createMockFile('frontend/package.json'),
          createMockFile('frontend/src/App.js')
        ]),
        createMockConversation('conv2', [
          createMockFile('backend/requirements.txt'),
          createMockFile('backend/app.py')
        ]),
        createMockConversation('conv3', [
          createMockFile('mobile/pubspec.yaml'),
          createMockFile('mobile/lib/main.dart')
        ])
      ];

      const analysis = await WorkspaceAnalyzer.analyzeWorkspaces(conversations);

      expect(analysis.workspaces.length).toBeGreaterThanOrEqual(2);
      
      const technologies = analysis.workspaces.flatMap(ws => ws.detectedTechnologies);
      expect(technologies).toContain('javascript');
      expect(technologies).toContain('python');
    });

    it('should handle conversations without file context', async () => {
      const conversations = [
        createMockConversation('conv1', []),
        createMockConversation('conv2', [])
      ];

      const analysis = await WorkspaceAnalyzer.analyzeWorkspaces(conversations);

      expect(analysis.workspaces).toHaveLength(0);
      expect(analysis.totalConversations).toBe(2);
      expect(analysis.errors).toHaveLength(0);
    });

    it('should filter out low-confidence workspaces', async () => {
      const conversations = [
        createMockConversation('conv1', [
          createMockFile('temp/file1.txt')
        ])
      ];

      const analysis = await WorkspaceAnalyzer.analyzeWorkspaces(conversations);

      // Les workspaces avec une seule conversation et peu d'indicateurs
      // devraient être filtrés
      expect(analysis.workspaces.length).toBeLessThanOrEqual(1);
      if (analysis.workspaces.length > 0) {
        expect(analysis.workspaces[0].confidence).toBeGreaterThan(0.6);
      }
    });

    it('should calculate quality metrics', async () => {
      const conversations = [
        createMockConversation('conv1', [
          createMockFile('project/package.json'),
          createMockFile('project/src/index.js')
        ]),
        createMockConversation('conv2', [
          createMockFile('project/src/utils.js')
        ])
      ];

      const analysis = await WorkspaceAnalyzer.analyzeWorkspaces(conversations);

      expect(analysis.analysisMetadata.qualityMetrics).toBeDefined();
      expect(analysis.analysisMetadata.qualityMetrics.workspaceDetectionAccuracy).toBeGreaterThanOrEqual(0);
      expect(analysis.analysisMetadata.qualityMetrics.workspaceDetectionAccuracy).toBeLessThanOrEqual(1);
    });

    it('should detect technology stacks correctly', async () => {
      const conversations = [
        createMockConversation('conv1', [
          createMockFile('fullstack/frontend/package.json'),
          createMockFile('fullstack/frontend/src/App.tsx'),
          createMockFile('fullstack/backend/requirements.txt'),
          createMockFile('fullstack/backend/main.py'),
          createMockFile('fullstack/docker-compose.yml')
        ])
      ];

      const analysis = await WorkspaceAnalyzer.analyzeWorkspaces(conversations);

      if (analysis.workspaces.length > 0) {
        const workspace = analysis.workspaces[0];
        expect(workspace.detectedTechnologies).toContain('javascript');
        expect(workspace.detectedTechnologies).toContain('python');
      }
    });

    it('should handle edge cases gracefully', async () => {
      // Test avec des conversations vides
      let analysis = await WorkspaceAnalyzer.analyzeWorkspaces([]);
      expect(analysis.workspaces).toHaveLength(0);
      expect(analysis.totalConversations).toBe(0);

      // Test avec des chemins invalides
      const invalidConversations = [
        createMockConversation('conv1', [
          createMockFile(''),
          createMockFile('/'),
          createMockFile('....')
        ])
      ];

      analysis = await WorkspaceAnalyzer.analyzeWorkspaces(invalidConversations);
      expect(analysis.errors).toHaveLength(0); // Ne devrait pas générer d'erreurs
    });

    it('should measure performance within acceptable limits', async () => {
      // Génère un grand nombre de conversations pour tester les performances
      const conversations: ConversationSummary[] = [];
      
      for (let i = 0; i < 100; i++) {
        conversations.push(
          createMockConversation(`conv${i}`, [
            createMockFile(`project${i % 10}/src/file${i}.js`),
            createMockFile(`project${i % 10}/package.json`)
          ])
        );
      }

      const startTime = Date.now();
      const analysis = await WorkspaceAnalyzer.analyzeWorkspaces(conversations);
      const duration = Date.now() - startTime;

      expect(duration).toBeLessThan(5000); // Moins de 5 secondes pour 100 conversations
      expect(analysis.analysisMetadata.analysisTime).toBeLessThan(5000);
      expect(analysis.totalConversations).toBe(100);
    });
  });

  describe('extractFilePatterns', () => {
    it('should extract common file patterns', async () => {
      const conversations = [
        createMockConversation('conv1', [
          createMockFile('src/index.js'),
          createMockFile('src/utils.js'),
          createMockFile('tests/app.test.js')
        ]),
        createMockConversation('conv2', [
          createMockFile('src/components.js'),
          createMockFile('tests/utils.test.js')
        ])
      ];

      const analysis = await WorkspaceAnalyzer.analyzeWorkspaces(conversations);

      if (analysis.workspaces.length > 0) {
        const patterns = analysis.workspaces[0].filePatterns;
        expect(patterns).toContain('.js');
        expect(patterns.some(p => p.includes('src'))).toBe(true);
        expect(patterns.some(p => p.includes('test'))).toBe(true);
      }
    });
  });

  describe('detectTechnologies', () => {
    it('should detect multiple technologies in mixed projects', async () => {
      const conversations = [
        createMockConversation('conv1', [
          createMockFile('project/frontend/package.json'),
          createMockFile('project/frontend/src/App.tsx'),
          createMockFile('project/backend/requirements.txt'),
          createMockFile('project/backend/app.py'),
          createMockFile('project/mobile/pubspec.yaml'),
          createMockFile('project/mobile/lib/main.dart'),
          createMockFile('project/Dockerfile'),
          createMockFile('project/docker-compose.yml')
        ])
      ];

      const analysis = await WorkspaceAnalyzer.analyzeWorkspaces(conversations);

      if (analysis.workspaces.length > 0) {
        const technologies = analysis.workspaces[0].detectedTechnologies;
        expect(technologies.length).toBeGreaterThan(1);
        expect(technologies).toContain('javascript');
        expect(technologies).toContain('python');
      }
    });
  });

  describe('error handling', () => {
    it('should handle malformed conversation data', async () => {
      const malformedConversations = [
        {
          taskId: 'conv1',
          path: '/mock/path/conv1',
          metadata: null, // Métadonnées nulles
          messageCount: 10,
          lastActivity: new Date().toISOString(),
          hasApiHistory: true,
          hasUiMessages: true,
          size: 1000
        } as ConversationSummary
      ];

      const analysis = await WorkspaceAnalyzer.analyzeWorkspaces(malformedConversations);

      expect(analysis.workspaces).toHaveLength(0);
      expect(analysis.errors).toHaveLength(0); // Devrait gérer gracieusement
    });

    it('should continue processing after individual conversation errors', async () => {
      const conversations = [
        createMockConversation('conv1', [
          createMockFile('project/package.json')
        ]),
        // Conversation avec des données invalides
        {
          taskId: 'invalid',
          path: null as any,
          metadata: undefined as any,
          messageCount: -1,
          lastActivity: 'invalid-date',
          hasApiHistory: true,
          hasUiMessages: true,
          size: -100
        } as ConversationSummary,
        createMockConversation('conv3', [
          createMockFile('project/src/index.js')
        ])
      ];

      const analysis = await WorkspaceAnalyzer.analyzeWorkspaces(conversations);

      // Devrait traiter les conversations valides malgré les erreurs
      expect(analysis.totalConversations).toBe(3);
    });
  });
});