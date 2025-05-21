declare module '@modelcontextprotocol/sdk' {
  export interface ServerOptions {
    name: string;
    description: string;
    version: string;
  }

  export interface ToolSchema {
    type: string;
    properties?: Record<string, any>;
    required?: string[];
  }

  export interface Tool {
    name: string;
    description: string;
    schema: ToolSchema;
    handler: (args: any) => Promise<any>;
  }

  export interface Server {
    registerTool: (tool: Tool) => void;
    start: () => Promise<void>;
  }

  export function createServer(options: ServerOptions): Server;
}