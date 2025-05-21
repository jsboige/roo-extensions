declare module '@modelcontextprotocol/sdk' {
  export interface MCPToolInput {
    [key: string]: any;
  }

  export interface MCPToolOutput {
    result?: any;
    error?: {
      message: string;
      details?: any;
    };
  }

  export interface MCPTool {
    name: string;
    description: string;
    inputSchema: any;
    execute: (input: MCPToolInput) => Promise<MCPToolOutput>;
  }

  export interface MCPServerOptions {
    name: string;
    description?: string;
  }

  export class MCPServer {
    constructor(options: MCPServerOptions);
    registerTool(tool: MCPTool): void;
    start(): Promise<void>;
  }
}