/**
 * Tests E2E pour export_data (CONS-10 Phase 4.1)
 *
 * Teste toutes les combinaisons action+format supportées:
 * - action: task, format: xml
 * - action: task, format: json
 * - action: task, format: csv
 * - action: conversation, format: xml
 * - action: conversation, format: json (light/full)
 * - action: conversation, format: csv (conversations/messages/tools)
 * - action: project, format: xml
 *
 * Framework: Vitest
 * Coverage cible: >80%
 *
 * @module e2e/tools/export.test
 * @version 1.0.0 (CONS-10 Phase 4.1)
 */

import { describe, test, expect, vi, beforeEach, afterEach } from 'vitest';
import { existsSync, rmSync, mkdirSync, readFileSync } from 'fs';
import { join } from 'path';
import { handleExportData, ExportDataArgs } from '../../../mcps/internal/servers/roo-state-manager/src/tools/export/export-data.js';
import { ConversationSkeleton } from '../../../mcps/internal/servers/roo-state-manager/src/types/conversation.js';
import { XmlExporterService } from '../../../mcps/internal/servers/roo-state-manager/src/services/XmlExporterService.js';

// Mock XmlExporterService
const mockXmlExporterService = {
    generateTaskXml: vi.fn((skeleton: any, options: any) => {
        const content = options.includeContent ? `<task id="${skeleton.taskId}">${skeleton.metadata?.title || 'Task'}</task>` : `<task id="${skeleton.taskId}"/>`;
        return options.prettyPrint ? content : content.replace(/\s+/g, '');
    }),
    generateConversationXml: vi.fn((tasks: any[], options: any) => {
        const content = options.includeContent 
            ? `<conversation>${tasks.map((t: any) => `<task id="${t.taskId}">${t.metadata?.title || 'Task'}</task>`).join('')}</conversation>`
            : `<conversation>${tasks.map((t: any) => `<task id="${t.taskId}"/>`).join('')}</conversation>`;
        return options.prettyPrint ? content : content.replace(/\s+/g, '');
    }),
    generateProjectXml: vi.fn((tasks: any[], options: any) => {
        const content = `<project>${tasks.map((t: any) => `<task id="${t.taskId}"/>`).join('')}</project>`;
        return options.prettyPrint ? content : content.replace(/\s+/g, '');
    }),
    saveXmlToFile: vi.fn()
};

// Mock TraceSummaryService
vi.mock('../../../../mcps/internal/servers/roo-state-manager/src/services/TraceSummaryService.js', () => {
    const mockGenerateSummary = vi.fn();
    
    // Définir le comportement par défaut pour CSV
    mockGenerateSummary.mockImplementation(async (conversation: any, options: any) => {
        const { outputFormat, jsonVariant, csvVariant } = options;
        const taskId = conversation?.taskId || 'task-123';
        
        if (outputFormat === 'json') {
            const baseJson = {
                format: `roo-conversation-${jsonVariant}`,
                version: '1.0',
                exportTime: new Date().toISOString(),
                summary: {
                    totalConversations: 1,
                    totalMessages: 10,
                    totalSize: 1024,
                    dateRange: {
                        earliest: new Date().toISOString(),
                        latest: new Date().toISOString()
                    }
                },
                conversations: [
                    {
                        taskId: taskId,
                        firstUserMessage: '',
                        isCompleted: false,
                        workspace: '/test/workspace',
                        createdAt: new Date().toISOString(),
                        lastActivity: new Date().toISOString(),
                        messageCount: 10,
                        actionCount: 5,
                        totalSize: 1024,
                        children: []
                    }
                ],
                drillDown: {
                    available: true,
                    endpoint: 'view_task_details',
                    fullDataEndpoint: 'get_raw_conversation'
                }
            };
            
            const content = JSON.stringify(baseJson, null, 2);
            return { success: true, content, statistics: { totalSections: 1 } };
        }
        
        if (outputFormat === 'csv') {
            let content = '';
            if (csvVariant === 'conversations') {
                content = 'taskId,workspace,isCompleted,createdAt,lastActivity,messageCount,actionCount,totalSize,firstUserMessage\n' +
                         `${taskId},/test/workspace,,${new Date().toISOString()},${new Date().toISOString()},10,5,1024,\n` +
                         `task-456,/test/workspace,true,${new Date().toISOString()},${new Date().toISOString()},20,10,2048,`;
            } else if (csvVariant === 'messages') {
                content = 'taskId,messageIndex,role,timestamp,contentLength,isTruncated,toolCount,workspace\n' +
                         `${taskId},0,user,${new Date().toISOString()},100,false,0,/test/workspace\n` +
                         `${taskId},1,assistant,${new Date().toISOString()},200,false,1,/test/workspace\n` +
                         `${taskId},2,user,${new Date().toISOString()},150,false,0,/test/workspace`;
            } else if (csvVariant === 'tools') {
                content = 'taskId,messageIndex,toolName,serverName,executionTime,success,argsCount,resultLength,workspace\n' +
                         `${taskId},0,read_file,quickfiles,100,true,1,500,/test/workspace\n` +
                         `${taskId},1,write_to_file,quickfiles,150,true,2,800,/test/workspace\n` +
                         `${taskId},2,execute_command,quickfiles,200,true,1,300,/test/workspace`;
            }
            return { success: true, content, statistics: { totalSections: 1 } };
        }
        
        return { success: false, error: 'Unknown format' };
    });
    
    return {
        TraceSummaryService: class {
            constructor(config: any) {
                // Accepter le paramètre de constructeur
            }
            generateSummary = mockGenerateSummary;
        }
    };
});

// Mock ExportConfigManager
vi.mock('../../../../mcps/internal/servers/roo-state-manager/src/services/ExportConfigManager.js', () => ({
    ExportConfigManager: vi.fn().mockImplementation(() => ({
        getConfig: vi.fn().mockResolvedValue({}),
        updateConfig: vi.fn(),
        resetConfig: vi.fn()
    }))
}));

// Mock fs/promises
vi.mock('fs/promises', () => ({
    mkdir: vi.fn(),
    writeFile: vi.fn()
}));

describe('export_data E2E Tests - CONS-10 Phase 4.1', () => {
    let mockCache: Map<string, ConversationSkeleton>;
    let mockEnsureCache: (options?: { workspace?: string }) => Promise<void>;
    let mockGetSkeleton: (taskId: string) => Promise<ConversationSkeleton | null>;
    const testOutputDir = join(__dirname, '__test-output__');

    const createMockSkeleton = (taskId: string, parentId?: string, workspace?: string): ConversationSkeleton => ({
        taskId,
        parentTaskId: parentId,
        metadata: {
            title: `Test Task ${taskId}`,
            lastActivity: new Date().toISOString(),
            createdAt: new Date().toISOString(),
            messageCount: 10,
            actionCount: 5,
            totalSize: 1024,
            workspace: workspace || '/test/workspace'
        },
        sequence: []
    });

    beforeEach(() => {
        // Créer le cache de test
        mockCache = new Map();
        mockCache.set('task-123', createMockSkeleton('task-123'));
        mockCache.set('conv-456', createMockSkeleton('conv-456'));
        mockCache.set('child-789', createMockSkeleton('child-789', 'conv-456'));
        mockCache.set('project-task-1', createMockSkeleton('project-task-1', undefined, '/test/project'));
        mockCache.set('project-task-2', createMockSkeleton('project-task-2', undefined, '/test/project'));

        // Mock functions
        mockEnsureCache = vi.fn(async () => {});
        mockGetSkeleton = vi.fn(async (taskId: string) => mockCache.get(taskId) || null);

        // Créer le répertoire de sortie
        if (!existsSync(testOutputDir)) {
            mkdirSync(testOutputDir, { recursive: true });
        }

        vi.clearAllMocks();
    });

    afterEach(() => {
        // Nettoyer le répertoire de sortie
        if (existsSync(testOutputDir)) {
            rmSync(testOutputDir, { recursive: true, force: true });
        }
    });

    // ============================================================
    // Tests pour target=task format=xml
    // ============================================================

    describe('target: task, format: xml', () => {
        test('should export task as XML', async () => {
            const args: ExportDataArgs = {
                target: 'task',
                format: 'xml',
                taskId: 'task-123'
            };

            const result = await handleExportData(
                args,
                mockCache,
                mockXmlExporterService as any,
                mockEnsureCache,
                mockGetSkeleton
            );

            expect(result.isError).toBeFalsy();
            expect(result.content[0].type).toBe('text');
            expect(result.content[0].text).toContain('<task');
            expect(result.content[0].text).toContain('task-123');
            expect(mockEnsureCache).toHaveBeenCalled();
        });

        test('should export task as XML with content', async () => {
            const args: ExportDataArgs = {
                target: 'task',
                format: 'xml',
                taskId: 'task-123',
                includeContent: true
            };

            const result = await handleExportData(
                args,
                mockCache,
                mockXmlExporterService as any,
                mockEnsureCache,
                mockGetSkeleton
            );

            expect(result.isError).toBeFalsy();
            expect(result.content[0].text).toContain('Test Task task-123');
        });

        test('should export task as XML without pretty print', async () => {
            const args: ExportDataArgs = {
                target: 'task',
                format: 'xml',
                taskId: 'task-123',
                prettyPrint: false
            };

            const result = await handleExportData(
                args,
                mockCache,
                mockXmlExporterService as any,
                mockEnsureCache,
                mockGetSkeleton
            );

            expect(result.isError).toBeFalsy();
            // Sans pretty print, pas d'espaces
            expect(result.content[0].text).not.toContain('\n');
        });
    });

    // ============================================================
    // Tests pour target=task format=json (non supporté)
    // ============================================================

    describe('target: task, format: json', () => {
        test('should reject task with json format', async () => {
            const args: ExportDataArgs = {
                target: 'task',
                format: 'json',
                taskId: 'task-123'
            };

            const result = await handleExportData(
                args,
                mockCache,
                mockXmlExporterService as any,
                mockEnsureCache,
                mockGetSkeleton
            );

            expect(result.isError).toBe(true);
            expect(result.content[0].text).toContain('non supportée');
        });
    });

    // ============================================================
    // Tests pour target=task format=csv (non supporté)
    // ============================================================

    describe('target: task, format: csv', () => {
        test('should reject task with csv format', async () => {
            const args: ExportDataArgs = {
                target: 'task',
                format: 'csv',
                taskId: 'task-123'
            };

            const result = await handleExportData(
                args,
                mockCache,
                mockXmlExporterService as any,
                mockEnsureCache,
                mockGetSkeleton
            );

            expect(result.isError).toBe(true);
            expect(result.content[0].text).toContain('non supportée');
        });
    });

    // ============================================================
    // Tests pour target=conversation format=xml
    // ============================================================

    describe('target: conversation, format: xml', () => {
        test('should export conversation as XML', async () => {
            const args: ExportDataArgs = {
                target: 'conversation',
                format: 'xml',
                conversationId: 'conv-456'
            };

            const result = await handleExportData(
                args,
                mockCache,
                mockXmlExporterService as any,
                mockEnsureCache,
                mockGetSkeleton
            );

            expect(result.isError).toBeFalsy();
            expect(result.content[0].text).toContain('<conversation>');
            expect(result.content[0].text).toContain('conv-456');
            expect(mockEnsureCache).toHaveBeenCalled();
        });

        test('should export conversation as XML with maxDepth', async () => {
            const args: ExportDataArgs = {
                target: 'conversation',
                format: 'xml',
                conversationId: 'conv-456',
                maxDepth: 1
            };

            const result = await handleExportData(
                args,
                mockCache,
                mockXmlExporterService as any,
                mockEnsureCache,
                mockGetSkeleton
            );

            expect(result.isError).toBeFalsy();
            // Avec maxDepth=1, seulement la racine
            expect(result.content[0].text).toContain('conv-456');
        });

        test('should export conversation as XML with content', async () => {
            const args: ExportDataArgs = {
                target: 'conversation',
                format: 'xml',
                conversationId: 'conv-456',
                includeContent: true
            };

            const result = await handleExportData(
                args,
                mockCache,
                mockXmlExporterService as any,
                mockEnsureCache,
                mockGetSkeleton
            );

            expect(result.isError).toBeFalsy();
            expect(result.content[0].text).toContain('Test Task conv-456');
        });
    });

    // ============================================================
    // Tests pour target=conversation format=json
    // ============================================================

    describe('target: conversation, format: json', () => {
        test('should export conversation as JSON (light variant)', async () => {
            const args: ExportDataArgs = {
                target: 'conversation',
                format: 'json',
                taskId: 'task-123',
                jsonVariant: 'light'
            };

            const result = await handleExportData(
                args,
                mockCache,
                mockXmlExporterService as any,
                mockEnsureCache,
                mockGetSkeleton
            );

            expect(result.isError).toBeFalsy();
            expect(result.content[0].text).toContain('task-123');
            expect(result.content[0].text).toContain('roo-conversation-light');
        });

        test('should export conversation as JSON (full variant)', async () => {
            const args: ExportDataArgs = {
                target: 'conversation',
                format: 'json',
                taskId: 'task-123',
                jsonVariant: 'full'
            };

            const result = await handleExportData(
                args,
                mockCache,
                mockXmlExporterService as any,
                mockEnsureCache,
                mockGetSkeleton
            );

            expect(result.isError).toBeFalsy();
            expect(result.content[0].text).toContain('task-123');
            expect(result.content[0].text).toContain('roo-conversation-full');
        });

        test('should export conversation as JSON with truncation', async () => {
            const args: ExportDataArgs = {
                target: 'conversation',
                format: 'json',
                taskId: 'task-123',
                truncationChars: 100
            };

            const result = await handleExportData(
                args,
                mockCache,
                mockXmlExporterService as any,
                mockEnsureCache,
                mockGetSkeleton
            );

            expect(result.isError).toBeFalsy();
            expect(result.content[0].text).toContain('task-123');
            expect(result.content[0].text).toContain('roo-conversation-light');
        });

        test('should export conversation as JSON with range', async () => {
            const args: ExportDataArgs = {
                target: 'conversation',
                format: 'json',
                taskId: 'task-123',
                startIndex: 1,
                endIndex: 10
            };

            const result = await handleExportData(
                args,
                mockCache,
                mockXmlExporterService as any,
                mockEnsureCache,
                mockGetSkeleton
            );

            expect(result.isError).toBeFalsy();
            expect(result.content[0].text).toContain('task-123');
        });
    });

    // ============================================================
    // Tests pour target=conversation format=csv
    // ============================================================

    describe('target: conversation, format: csv', () => {
        test('should export conversation as CSV (conversations variant)', async () => {
            const args: ExportDataArgs = {
                target: 'conversation',
                format: 'csv',
                taskId: 'task-123',
                csvVariant: 'conversations'
            };

            const result = await handleExportData(
                args,
                mockCache,
                mockXmlExporterService as any,
                mockEnsureCache,
                mockGetSkeleton
            );

            expect(result.isError).toBeFalsy();
            expect(result.content[0].text).toContain('taskId,workspace,isCompleted');
            expect(result.content[0].text).toContain('task-123');
        });

        test('should export conversation as CSV (messages variant)', async () => {
            const args: ExportDataArgs = {
                target: 'conversation',
                format: 'csv',
                taskId: 'task-123',
                csvVariant: 'messages'
            };

            const result = await handleExportData(
                args,
                mockCache,
                mockXmlExporterService as any,
                mockEnsureCache,
                mockGetSkeleton
            );

            expect(result.isError).toBeFalsy();
            // Vérifier que le format CSV est correct (en-tête)
            expect(result.content[0].text).toContain('taskId,messageIndex,role,timestamp');
            // Vérifier que le format CSV est correct (colonnes attendues)
            expect(result.content[0].text).toContain('contentLength,isTruncated,toolCount,workspace');
        });

        test('should export conversation as CSV (tools variant)', async () => {
            const args: ExportDataArgs = {
                target: 'conversation',
                format: 'csv',
                taskId: 'task-123',
                csvVariant: 'tools'
            };

            const result = await handleExportData(
                args,
                mockCache,
                mockXmlExporterService as any,
                mockEnsureCache,
                mockGetSkeleton
            );

            expect(result.isError).toBeFalsy();
            // Vérifier que le format CSV est correct (en-tête)
            expect(result.content[0].text).toContain('taskId,messageIndex,toolName,serverName');
            // Vérifier que le format CSV est correct (colonnes attendues)
            expect(result.content[0].text).toContain('executionTime,success,argsCount,resultLength,workspace');
        });

        test('should export conversation as CSV with truncation', async () => {
            const args: ExportDataArgs = {
                target: 'conversation',
                format: 'csv',
                taskId: 'task-123',
                csvVariant: 'conversations',
                truncationChars: 100
            };

            const result = await handleExportData(
                args,
                mockCache,
                mockXmlExporterService as any,
                mockEnsureCache,
                mockGetSkeleton
            );

            expect(result.isError).toBeFalsy();
        });

        test('should export conversation as CSV with range', async () => {
            const args: ExportDataArgs = {
                target: 'conversation',
                format: 'csv',
                taskId: 'task-123',
                csvVariant: 'conversations',
                startIndex: 1,
                endIndex: 10
            };

            const result = await handleExportData(
                args,
                mockCache,
                mockXmlExporterService as any,
                mockEnsureCache,
                mockGetSkeleton
            );

            expect(result.isError).toBeFalsy();
        });
    });

    // ============================================================
    // Tests pour target=project format=xml
    // ============================================================

    describe('target: project, format: xml', () => {
        test('should export project as XML', async () => {
            const args: ExportDataArgs = {
                target: 'project',
                format: 'xml',
                projectPath: '/test/project'
            };

            const result = await handleExportData(
                args,
                mockCache,
                mockXmlExporterService as any,
                mockEnsureCache,
                mockGetSkeleton
            );

            expect(result.isError).toBeFalsy();
            expect(result.content[0].text).toContain('<project>');
            expect(result.content[0].text).toContain('project-task-1');
            expect(result.content[0].text).toContain('project-task-2');
            expect(mockEnsureCache).toHaveBeenCalledWith({ workspace: '/test/project' });
        });

        test('should export project as XML with date filters', async () => {
            const args: ExportDataArgs = {
                target: 'project',
                format: 'xml',
                projectPath: '/test/project',
                startDate: '2026-01-01T00:00:00Z',
                endDate: '2026-12-31T23:59:59Z'
            };

            const result = await handleExportData(
                args,
                mockCache,
                mockXmlExporterService as any,
                mockEnsureCache,
                mockGetSkeleton
            );

            expect(result.isError).toBeFalsy();
            expect(mockEnsureCache).toHaveBeenCalledWith({ workspace: '/test/project' });
        });

        test('should export project as XML without pretty print', async () => {
            const args: ExportDataArgs = {
                target: 'project',
                format: 'xml',
                projectPath: '/test/project',
                prettyPrint: false
            };

            const result = await handleExportData(
                args,
                mockCache,
                mockXmlExporterService as any,
                mockEnsureCache,
                mockGetSkeleton
            );

            expect(result.isError).toBeFalsy();
            // Sans pretty print, pas d'espaces
            expect(result.content[0].text).not.toContain('\n');
        });
    });

    // ============================================================
    // Tests pour target=project format=json (non supporté)
    // ============================================================

    describe('target: project, format: json', () => {
        test('should reject project with json format', async () => {
            const args: ExportDataArgs = {
                target: 'project',
                format: 'json',
                projectPath: '/test/project'
            };

            const result = await handleExportData(
                args,
                mockCache,
                mockXmlExporterService as any,
                mockEnsureCache,
                mockGetSkeleton
            );

            expect(result.isError).toBe(true);
            expect(result.content[0].text).toContain('non supportée');
        });
    });

    // ============================================================
    // Tests de gestion d'erreurs
    // ============================================================

    describe('error handling', () => {
        test('should return error when target is missing', async () => {
            const args = { format: 'xml' } as ExportDataArgs;

            const result = await handleExportData(
                args,
                mockCache,
                mockXmlExporterService as any,
                mockEnsureCache,
                mockGetSkeleton
            );

            expect(result.isError).toBe(true);
            expect(result.content[0].text).toContain('target');
        });

        test('should return error when format is missing', async () => {
            const args = { target: 'task' } as ExportDataArgs;

            const result = await handleExportData(
                args,
                mockCache,
                mockXmlExporterService as any,
                mockEnsureCache,
                mockGetSkeleton
            );

            expect(result.isError).toBe(true);
            expect(result.content[0].text).toContain('format');
        });

        test('should return error when taskId is missing for target=task', async () => {
            const args: ExportDataArgs = {
                target: 'task',
                format: 'xml'
            };

            const result = await handleExportData(
                args,
                mockCache,
                mockXmlExporterService as any,
                mockEnsureCache,
                mockGetSkeleton
            );

            expect(result.isError).toBe(true);
            expect(result.content[0].text).toContain('taskId');
        });

        test('should return error when conversationId is missing for target=conversation format=xml', async () => {
            const args: ExportDataArgs = {
                target: 'conversation',
                format: 'xml'
            };

            const result = await handleExportData(
                args,
                mockCache,
                mockXmlExporterService as any,
                mockEnsureCache,
                mockGetSkeleton
            );

            expect(result.isError).toBe(true);
            expect(result.content[0].text).toContain('conversationId');
        });

        test('should return error when taskId is missing for target=conversation format=json', async () => {
            const args: ExportDataArgs = {
                target: 'conversation',
                format: 'json'
            };

            const result = await handleExportData(
                args,
                mockCache,
                mockXmlExporterService as any,
                mockEnsureCache,
                mockGetSkeleton
            );

            expect(result.isError).toBe(true);
            expect(result.content[0].text).toContain('taskId');
        });

        test('should return error when taskId is missing for target=conversation format=csv', async () => {
            const args: ExportDataArgs = {
                target: 'conversation',
                format: 'csv'
            };

            const result = await handleExportData(
                args,
                mockCache,
                mockXmlExporterService as any,
                mockEnsureCache,
                mockGetSkeleton
            );

            expect(result.isError).toBe(true);
            expect(result.content[0].text).toContain('taskId');
        });

        test('should return error when projectPath is missing for target=project', async () => {
            const args: ExportDataArgs = {
                target: 'project',
                format: 'xml'
            };

            const result = await handleExportData(
                args,
                mockCache,
                mockXmlExporterService as any,
                mockEnsureCache,
                mockGetSkeleton
            );

            expect(result.isError).toBe(true);
            expect(result.content[0].text).toContain('projectPath');
        });

        test('should return error when task not found', async () => {
            const args: ExportDataArgs = {
                target: 'task',
                format: 'xml',
                taskId: 'non-existent-task'
            };

            const result = await handleExportData(
                args,
                mockCache,
                mockXmlExporterService as any,
                mockEnsureCache,
                mockGetSkeleton
            );

            expect(result.isError).toBe(true);
            expect(result.content[0].text).toContain('non trouvée');
        });

        test('should return error when conversation not found', async () => {
            const args: ExportDataArgs = {
                target: 'conversation',
                format: 'xml',
                conversationId: 'non-existent-conv'
            };

            const result = await handleExportData(
                args,
                mockCache,
                mockXmlExporterService as any,
                mockEnsureCache,
                mockGetSkeleton
            );

            expect(result.isError).toBe(true);
            expect(result.content[0].text).toContain('non trouvée');
        });

        test('should return error when conversation not found for json', async () => {
            const args: ExportDataArgs = {
                target: 'conversation',
                format: 'json',
                taskId: 'non-existent-task'
            };

            const result = await handleExportData(
                args,
                mockCache,
                mockXmlExporterService as any,
                mockEnsureCache,
                mockGetSkeleton
            );

            expect(result.isError).toBe(true);
            expect(result.content[0].text).toContain('introuvable');
        });

        test('should return error when conversation not found for csv', async () => {
            const args: ExportDataArgs = {
                target: 'conversation',
                format: 'csv',
                taskId: 'non-existent-task'
            };

            const result = await handleExportData(
                args,
                mockCache,
                mockXmlExporterService as any,
                mockEnsureCache,
                mockGetSkeleton
            );

            expect(result.isError).toBe(true);
            expect(result.content[0].text).toContain('introuvable');
        });
    });
});
