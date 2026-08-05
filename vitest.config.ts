/**
 * Root vitest guard (#3009). This is a GUARD, not a runnable test suite.
 *
 * Running `npx vitest run` from the repo root without this config picks up
 * 762 files (including mcps/internal submodule tests, jest files, and plain
 * Node scripts), producing ~200 false failures. The submodule has its own
 * vitest config at mcps/internal/servers/roo-state-manager/vitest.config.ts.
 *
 * There is NO root-level test suite today. The lone test that used to live
 * here (tests/e2e/tools/export.test.ts) was a duplicate of the submodule's
 * export-data coverage and imported the submodule's source via fragile
 * relative paths — it could never run from root (no root node_modules, and
 * @xmldom/xmldom lives in the submodule). It was removed; handleExportData
 * is covered by src/tools/export/__tests__/export-data.{test,coverage,
 * integration}.test.ts in the submodule (~1100 lines, run in CI).
 *
 * The `include` below stays so a future legitimate root-level vitest test
 * would be discovered; the `exclude` belt is what actually prevents the
 * 762-file pickup. Running `npx vitest run` from root fails fast with a
 * MODULE_NOT_FOUND (no root node_modules) — that IS the guard working, not
 * a broken config. To run the real test suite:
 *   npm run test:mcp
 *   # or: cd mcps/internal/servers/roo-state-manager && npx vitest run
 *
 * No CI job runs vitest from the repo root; ci.yml runs the submodule's
 * `--config vitest.config.ci.ts` directly.
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
