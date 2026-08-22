/**
 * RooSync MCP Client Wrapper for NanoClaw
 *
 * This module provides a TypeScript wrapper for communicating with the
 * roo-state-manager MCP server from within a NanoClaw container.
 *
 * Architecture:
 * NanoClaw Container -> MCP Client (stdio) -> roo-state-manager -> RooSync
 *
 * Usage:
 * import { RooSyncClient } from './index.js';
 * const client = new RooSyncClient();
 * await client.dashboard.append({ tags: ['NANOCLAW', 'INFO'], content: '...' });
 */

import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import path from 'path';
import fs from 'fs';

// ============================================================
// Types
// ============================================================

export type DashboardType = 'global' | 'machine' | 'workspace';
export type DashboardAction = 'read' | 'write' | 'append' | 'list' | 'delete' | 'read_archive' | 'read_overview' | 'refresh' | 'update';
export type DashboardSection = 'status' | 'intercom' | 'all';
export type Priority = 'LOW' | 'MEDIUM' | 'HIGH' | 'URGENT';

export interface DashboardAuthor {
  machineId: string;
  workspace: string;
  worktree?: string;
}

export interface DashboardAppendOptions {
  type: DashboardType;
  tags: string[];
  content: string;
  machineId?: string;
  workspace?: string;
  author?: DashboardAuthor;
  createIfNotExists?: boolean;
}

export interface DashboardReadOptions {
  type: DashboardType;
  section?: DashboardSection;
  machineId?: string;
  workspace?: string;
  intercomLimit?: number;
}

export interface SendMessageOptions {
  to: string;
  subject: string;
  body: string;
  priority?: Priority;
  tags?: string[];
  threadId?: string;
  replyTo?: string;
}

export interface ReadInboxOptions {
  status?: 'unread' | 'read' | 'all';
  limit?: number;
  page?: number;
  perPage?: number;
}

export interface HeartbeatStatusOptions {
  machineId?: string;
  includeHeartbeats?: boolean;
}

export interface RooSyncClientConfig {
  serverPath?: string;
  machineId?: string;
  workspace?: string;
  env?: Record<string, string>;
}

// ============================================================
// RooSyncClient
// ============================================================

export class RooSyncClient {
  private client: Client | null = null;
  private transport: StdioClientTransport | null = null;
  private config: Required<RooSyncClientConfig>;

  constructor(config: RooSyncClientConfig = {}) {
    this.config = {
      serverPath: config.serverPath || process.env.ROOSYNC_MCP_PATH || '/workspace/mcps/internal/servers/roo-state-manager/dist/index.js',
      machineId: config.machineId || process.env.ROOSYNC_MACHINE_ID || 'nanoclaw-ai-01',
      workspace: config.workspace || process.env.ROOSYNC_WORKSPACE || 'nanoclaw-default',
      env: config.env || process.env,
    };
  }

  /**
   * Connect to the roo-state-manager MCP server
   */
  async connect(): Promise<void> {
    if (this.client) {
      return; // Already connected
    }

    // Verify MCP server exists
    if (!fs.existsSync(this.config.serverPath)) {
      throw new Error(`MCP server not found at: ${this.config.serverPath}`);
    }

    // Create stdio transport
    this.transport = new StdioClientTransport({
      command: 'node',
      args: [this.config.serverPath],
      env: {
        ...this.config.env,
        ROOSYNC_MACHINE_ID: this.config.machineId,
        ROOSYNC_WORKSPACE: this.config.workspace,
      },
    });

    // Create and connect client
    this.client = new Client({
      name: `nanoclaw-${this.config.machineId}`,
      version: '1.0.0',
    }, {
      capabilities: {},
    });

    await this.client.connect(this.transport);

    // List available tools to verify connection
    const tools = await this.client.listTools();
    if (!tools.tools.find(t => t.name === 'roosync_dashboard')) {
      throw new Error('roo-state-manager MCP server does not provide expected tools');
    }
  }

  /**
   * Disconnect from the MCP server
   */
  async disconnect(): Promise<void> {
    if (this.client) {
      await this.client.close();
      this.client = null;
    }
    if (this.transport) {
      // @ts-ignore - close() exists but not in types
      await this.transport.close();
      this.transport = null;
    }
  }

  /**
   * Ensure client is connected
   */
  private async ensureConnected(): Promise<void> {
    if (!this.client) {
      await this.connect();
    }
  }

  /**
   * Call an MCP tool
   */
  private async callTool(name: string, args: Record<string, unknown>): Promise<unknown> {
    await this.ensureConnected();

    const result = await this.client!.callTool({
      name,
      arguments: args,
    });

    // Parse result content
    for (const content of result.content) {
      if (content.type === 'text') {
        // Try to parse JSON if possible
        try {
          return JSON.parse(content.text);
        } catch {
          return content.text;
        }
      }
    }

    return result;
  }

  // ============================================================
  // Dashboard Operations
  // ============================================================

  readonly dashboard = {
    /**
     * Read dashboard content
     */
    read: async (options: DashboardReadOptions): Promise<unknown> => {
      return this.callTool('roosync_dashboard', {
        action: 'read',
        type: options.type,
        section: options.section || 'all',
        machineId: options.machineId || this.config.machineId,
        workspace: options.workspace || this.config.workspace,
        intercomLimit: options.intercomLimit,
      });
    },

    /**
     * Append a message to the dashboard
     */
    append: async (options: DashboardAppendOptions): Promise<unknown> => {
      return this.callTool('roosync_dashboard', {
        action: 'append',
        type: options.type,
        tags: options.tags,
        content: options.content,
        machineId: options.machineId || this.config.machineId,
        workspace: options.workspace || this.config.workspace,
        author: options.author || {
          machineId: this.config.machineId,
          workspace: this.config.workspace,
        },
        createIfNotExists: options.createIfNotExists !== undefined ? options.createIfNotExists : true,
      });
    },

    /**
     * Write/replace the status section
     */
    write: async (options: Omit<DashboardAppendOptions, 'tags'>): Promise<unknown> => {
      return this.callTool('roosync_dashboard', {
        action: 'write',
        type: options.type,
        content: options.content,
        machineId: options.machineId || this.config.machineId,
        workspace: options.workspace || this.config.workspace,
      });
    },

    /**
     * List all dashboards
     */
    list: async (): Promise<unknown> => {
      return this.callTool('roosync_dashboard', {
        action: 'list',
      });
    },
  };

  // ============================================================
  // Messaging Operations
  // ============================================================

  readonly messaging = {
    /**
     * Send a RooSync message to another machine
     */
    send: async (options: SendMessageOptions): Promise<unknown> => {
      return this.callTool('roosync_messages', {
        action: 'send',
        to: options.to,
        subject: options.subject,
        body: options.body,
        priority: options.priority || 'MEDIUM',
        tags: options.tags,
        thread_id: options.threadId,
        reply_to: options.replyTo,
      });
    },

    /**
     * Read the inbox
     */
    readInbox: async (options: ReadInboxOptions = {}): Promise<unknown> => {
      return this.callTool('roosync_messages', {
        action: 'inbox',
        status: options.status || 'all',
        limit: options.limit || 10,
        page: options.page,
        per_page: options.perPage,
      });
    },

    /**
     * Get a specific message
     */
    getMessage: async (messageId: string, markAsRead = false): Promise<unknown> => {
      return this.callTool('roosync_messages', {
        action: 'message',
        message_id: messageId,
        mark_as_read: markAsRead,
      });
    },

    /**
     * List attachments for a message
     */
    listAttachments: async (messageId: string): Promise<unknown> => {
      return this.callTool('roosync_messages', {
        action: 'attachments_list',
        message_id: messageId,
      });
    },
  };

  // ============================================================
  // Heartbeat Operations
  // ============================================================

  readonly inventory = {
    /**
     * Get heartbeat / cluster status of all machines.
     *
     * Note: registering a heartbeat is NOT an MCP operation — it is managed by the host
     * RooSync listener. This is a read-only view of the cluster liveness.
     */
    status: async (options: HeartbeatStatusOptions = {}): Promise<unknown> => {
      return this.callTool('roosync_inventory', {
        type: 'machines',
        machineId: options.machineId,
        includeHeartbeats: options.includeHeartbeats !== undefined ? options.includeHeartbeats : true,
      });
    },
  };

  // ============================================================
  // Utility Operations
  // ============================================================

  /**
   * Get full RooSync cluster status
   */
  async getStatus(machineId?: string): Promise<unknown> {
    return this.callTool('roosync_inventory', {
      type: 'machines',
      machineId,
      includeHeartbeats: true,
    });
  }

  /**
   * Compare configurations between machines
   */
  async compareConfigs(source?: string, target?: string): Promise<unknown> {
    return this.callTool('roosync_compare_config', {
      source: source || this.config.machineId,
      target: target || 'myia-ai-01',
    });
  }
}

// ============================================================
// Singleton Instance
// ============================================================

let globalClient: RooSyncClient | null = null;

/**
 * Get the global RooSync client instance
 */
export function getRooSyncClient(config?: RooSyncClientConfig): RooSyncClient {
  if (!globalClient) {
    globalClient = new RooSyncClient(config);
  }
  return globalClient;
}

/**
 * Close the global client connection
 */
export async function closeRooSyncClient(): Promise<void> {
  if (globalClient) {
    await globalClient.disconnect();
    globalClient = null;
  }
}

// Export for ESM
export default RooSyncClient;
