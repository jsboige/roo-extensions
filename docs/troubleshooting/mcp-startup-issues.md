# Troubleshooting MCP Startup Issues

This document provides solutions to common issues encountered during the startup of MCP servers.

## Issue: `ReferenceError: __dirname is not defined in ES module scope`

**Context:**

This error occurs when an MCP server, configured to use ES Modules (ESM), attempts to use the `__dirname` global variable. `__dirname` is a CommonJS feature and is not available by default in ESM.

**Affected MCPs:**

*   `github-projects-mcp` (confirmed on 2025-09-24)
*   Any other MCP server running as an ES Module.

**Solution:**

The standard solution is to derive the directory path from `import.meta.url`. This requires the `url` and `path` core Node.js modules.

**Implementation Example (`index.ts`):**

```typescript
import { fileURLToPath } from 'url';
import path from 'path';

// ESM-compatible way to get __dirname
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Now you can use __dirname as you would in CommonJS
// For example, to load a .env file from the parent directory:
import dotenv from 'dotenv';
dotenv.config({ path: path.resolve(__dirname, '../.env') });
```

**Resolution Steps:**

1.  **Identify the problematic file:** Locate the entry point of the MCP server (e.g., `src/index.ts`).
2.  **Import necessary modules:** Add `import { fileURLToPath } from 'url';` and `import path from 'path';`.
3.  **Implement the polyfill:** Add the code snippet above to define `__filename` and `__dirname`.
4.  **Verify path resolutions:** Ensure all uses of `__dirname` (e.g., `path.resolve(__dirname, ...)`) now function correctly.
5.  **Recompile the MCP:** Run the build command (e.g., `pnpm build`) for the specific MCP.
6.  **Restart and validate:** Reload the VS Code extension and check the logs to confirm the error has disappeared and the MCP starts successfully.
