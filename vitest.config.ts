/**
 * Root vitest guard (#3009).
 *
 * Running `npx vitest run` from the repo root without this config picks up
 * 762 files (including mcps/internal submodule tests, jest files, and plain
 * Node scripts), producing ~200 false failures. The submodule has its own
 * vitest config at mcps/internal/servers/roo-state-manager/vitest.config.ts.
 *
 * This config ensures vitest from root only discovers legitimate root-level
 * vitest tests (currently tests/e2e/tools/export.test.ts), excluding:
 *   - mcps/**        (submodule — own vitest config)
 *   - roo-code/**     (submodule — reference only)
 *   - modules/**      (EncodingManager uses jest, not vitest)
 *   - roo-code-customization/** (plain Node scripts, not vitest)
 *
 * To run the MCP server test suite:
 *   npm run test:mcp
 *   # or: cd mcps/internal/servers/roo-state-manager && npx vitest run
 */
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    include: ['tests/**/*.test.ts'],
    exclude: [
      'node_modules/**',
      'mcps/**',
      'roo-code/**',
      '.claude/**',
      'modules/**',
      'roo-code-customization/**',
    ],
  },
});
