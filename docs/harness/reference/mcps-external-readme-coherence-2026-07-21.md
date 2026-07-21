# External MCP README Coherence Audit — 2026-07-21

**Issue:** #2882 (W5 of #2877; source audit #2876)
**Repository baseline:** `6e56ce8f7151e58b22d75f19a06f8b7742ebcdff`
**Baseline tree:** `c39db7a4395ebc22a7785977548d8e8e493b8b22`
**Scope:** the 45 `mcps/external/` Markdown files classified as `other` by `doc-audit-raw-2026-07-21.json`
**Result:** 45/45 read; 36 `UPDATE-NEEDED`; 9 `REMOVE`; 0 `OK`

## Method

1. Extracted the exact 45-file scope from `docs/harness/reference/doc-audit-raw-2026-07-21.json`; vendored upstream docs and Markdown test fixtures outside that list were not silently added.
2. Read every scoped file, grouped by canonical MCP/package.
3. Compared claims with adjacent manifests and code, `roo-config/settings/servers.json`, current tool policy, deployment scripts, and git history.
4. Checked package identity, versions, runtime paths, configuration schemas, tool names, examples, and redundant files.
5. For every proposed removal, recorded configuration-absence or replacement evidence and a git tree/blob SHA.

SDDD was attempted at both ends. `conversation_browser(list)` succeeded on retry and found no prior #2882 conversation. `roosync_search(semantic)` degraded to text with no result. `codebase_search` could not run because this machine has no Qdrant workspace collection; the audit therefore relies on the complete technical inventory and exact searches, and this indexing failure was reported as friction on the workspace dashboard.

## Package summary

`README age` and `code/config age` are days since the last relevant git change on 2026-07-21. A range covers multiple scoped files.

| MCP/package | Files | README age | Code/config age | versions_match | paths_match | Status | Action proposed |
|---|---:|---:|---:|---|---|---|---|
| external index | 1 | 425 | 113 | N/A | Partial | UPDATE-NEEDED | Rebuild directory index; remove phantom `filesystem/`, add five omitted packages |
| desktop-commander | 1 | 152 | 39 (retirement policy) | N/A | No | REMOVE | Remove retired MCP subtree in a dedicated PR after preserving tree SHA |
| docker | 6 | 419–425 | 54 | Partial | Partial | UPDATE-NEEDED | Correct image tag/mount and Node minimum |
| git | 7 | 425 | 113 (canonical config) | No | No | UPDATE-NEEDED | Choose one canonical implementation and rewrite the mixed-package docs |
| github | 8 | 425 | 113 (canonical config) | Partial | No | UPDATE-NEEDED | Correct Node/stdio/config claims; remove unrelated Go license-only subtree |
| jupyter | 3 | 425 | 20 | No | No | REMOVE | Remove obsolete Node-server docs; canonical MCP is Python/Papermill |
| markitdown | 2 | 315–364 | 113 | Partial | No | UPDATE-NEEDED | Require Python ≥3.10 and document canonical command without a user-specific path |
| playwright | 3 | 280–364 | 109 | No | No | UPDATE-NEEDED | Document canonical `npx` deployment; remove the stale one-shot installation report |
| searxng | 6 | 315–425 | 113 | No | No | UPDATE-NEEDED | Replace old package/config schema with the canonical command and `SEARXNG_URL` |
| win-cli | 8 | 130–425 | 57 | Partial | No | UPDATE-NEEDED | Rewrite against fork 0.2.0 schema; remove redundant French security duplicate |

## Findings by package

### external index — UPDATE-NEEDED

`mcps/external/README.md:7-15` lists seven directories. The tree contains eleven package directories: five are omitted (`Office-PowerPoint-MCP-Server`, `desktop-commander`, `markitdown`, `mcp-server-ftp`, `playwright`) and `filesystem/` is listed but absent. The canonical configuration link at `mcps/external/README.md:23` is valid.

**Action:** update only the index after package-level decisions land; describe `filesystem` as package-only if it remains listed.

### desktop-commander — REMOVE

The README still claims migration phase 3 completed and all six machines deployed it (`mcps/external/desktop-commander/README.md:4-5,184-192`). Current policy explicitly retires it (`.claude/rules/tool-availability.md:43-45`), canonical `roo-config/settings/servers.json` has no entry, and both drift validators reject it (`scripts/validation/validate-mcp-drift.ps1:126`; `scripts/validation/validate-mcp-config-cross-machine.ps1:37-41`). The supported replacement is the win-cli fork.

**Preservation:** directory tree `b90c7a242987ed00f0b38b514cbfe79db25fd478`; README blob `44e25772f386228ebd0abf4d1f252597eb118965`; source commit `2d4dca22a82012085b54a2693cc8089480bc978f`.

**Action:** dedicated desktop-commander removal PR must analyze and remove the subtree's deployment/config scripts and the obsolete always-allow source entry, not merely delete this README.

### docker — UPDATE-NEEDED

The active command is Docker image `mcp-server:local` with the Docker socket mount (`roo-config/settings/servers.json:121-135`). Most docs agree, but `mcps/external/docker/BUILD-LOCAL.md:52-54` uses `${workspaceFolder}:/workspace` and `mcp-server-docker:latest`. `mcps/external/docker/INSTALLATION.md:10` still permits Node 14.

**Action:** targeted update to those exact claims; keep all six files.

### git — UPDATE-NEEDED

Three incompatible identities coexist:

- canonical config: Python `mcp_server_git` (`roo-config/settings/servers.json:38-44`);
- wrapper docs: npm `@modelcontextprotocol/server-git` (`mcps/external/git/README.md:58-72`);
- adjacent source: `@cyanheads/git-mcp-server` 2.0.6 (`mcps/external/git/server/package.json:2-17`).

The wrapper docs also claim Node 14 and unsupported CLI/env controls (`mcps/external/git/INSTALLATION.md:9,30`; `CONFIGURATION.md:160-224`). The adjacent README still says 2.0.2 while the manifest says 2.0.6 (`server/README.md:185,193`), and its changelog stops at 2.0.5 (`server/CHANGELOG.md:8`).

**Action:** do not perform search-and-replace across the current prose. First decide whether docs target configured Python or vendored Cyanheads; then rewrite the five wrapper docs and label or remove the unused source package in one bounded Git MCP decision.

### github — UPDATE-NEEDED

The five wrapper docs correctly name the configured npm package (`roo-config/settings/servers.json:46-55`) but contain unsupported HTTP/CLI examples: Node 14 (`INSTALLATION.md:8`), localhost HTTP verification (`INSTALLATION.md:158`), and fabricated `--port`, `--host`, retry/rate-limit flags and `MCP_GITHUB_*` variables (`CONFIGURATION.md:127-159,208-217`; `TROUBLESHOOTING.md:290-409`).

The three files under `github/server/` are license notices for the different Go project `github/github-mcp-server` (`third-party-licenses.*.md:3,11`). No Go source or binary exists in that subtree and the canonical config uses the Node package.

**Preservation:** `github/server` tree `bf2ea20e952db8a2f24b4956d245ed3a9d012aa2`; Darwin/Linux blob `cdb19b55500b2a2c197e62e5158d2e7320695789`; Windows blob `b34d7e6ac23313fb045787866061bdcdb9f7a365`.

**Action:** one GitHub MCP coherence PR may rewrite the active wrapper docs and remove the unrelated license-only subtree, with the package-identity decision stated explicitly.

### jupyter — REMOVE

All three docs describe a Node server and paths under `mcps/mcp-servers/servers/jupyter-mcp-server` (`configurations-jupyter-mcp.md:193,214-218`; `troubleshooting.md:284-309`). Those paths do not exist. The active MCP is Python/Papermill at `mcps/internal/servers/jupyter-papermill-mcp-server` (`roo-config/settings/servers.json:21-27`), updated 20 days ago. A prior consolidation report already calls `mcps/external/jupyter/` obsolete and records its intended deletion (`mcps/JUPYTER-CONFLICT-RESOLUTION-REPORT.md:7-24,56-77`).

**Preservation:** directory tree `6ce7cc4e3bca0a1cda6f00414281ddf01fb07e6e`; README `56125c6ff0338c0f845c523859f34512a7434354`; configuration `a63a3a504a1ddf20498836b7a3e0cc6fb3641fbc`; troubleshooting `4a2c84aaafbc607b2e1179e3414630024e46da57`.

**Action:** dedicated Jupyter removal/consolidation PR must also assess the sibling startup batch file and preserve any still-valid operator guidance in the Papermill documentation before deletion.

### markitdown — UPDATE-NEEDED

The package requires Python ≥3.10 (`markitdown/source/packages/markitdown-mcp/pyproject.toml:5-10`), while `CONFIGURATION.md:27` creates Python 3.9. Its command hardcodes `C:/Users/jsboi/...` (`CONFIGURATION.md:40`) instead of the canonical `python -m markitdown_mcp` (`roo-config/settings/servers.json:80-85`). The README describes manipulating Markdown rather than converting resources to Markdown (`README.md:3`).

**Action:** small two-file update; keep the vendored source untouched.

### playwright — UPDATE-NEEDED

The active configuration is `npx -y @playwright/mcp --browser firefox` (`roo-config/settings/servers.json:88-93`). The package is 0.0.70 and its binary is `cli.js` (`source/packages/playwright-mcp/package.json:2-11,39-40`). Wrapper docs instead point to nonexistent `lib/index.js` and `lib/cli.js` paths (`README.md:46-61`; `CONFIGURATION.md:54`). `INSTALLATION_REPORT.md` is a one-machine snapshot pinned to 0.0.41 and the retired tool name `browser_get_page_snapshot` (`INSTALLATION_REPORT.md:5,114,194`).

**Preservation for report removal:** blob `554ed2515776b99e87c076b67f68f4e6f69c4d55`.

**Action:** one Playwright MCP PR should correct the two live docs and remove the historical installation report, retaining its contents through git history.

### searxng — UPDATE-NEEDED

The active config uses `@modelcontextprotocol/server-searxng` (`roo-config/settings/servers.json:5-11`), but all six docs describe `mcp-searxng` and a large JSON schema. Examples include `mcp-searxng` install paths (`installation.md:37-89,144-185`) and `searxng.instance=https://searx.be` (`configuration.md:17-67`). The repository's own config example uses `SEARXNG_URL=https://search.myia.io/` (`mcp-config-example.json:17`).

**Action:** rewrite configuration and installation around the canonical package/env contract; preserve only tool-call examples verified against the current two-tool surface.

### win-cli — UPDATE-NEEDED

The fork version is correctly 0.2.0 and requires Node ≥18 (`server/package.json:2-7,31-33`). Seven docs contain stale or invented configuration fields such as `.win-cli-server`, `allowedCommands`, `commandSeparators`, and `allowCommandChaining` (`configuration.md:16-59,202-267`; `SECURITY.md:57-89`; `TROUBLESHOOTING.md:104-223`). Actual code uses `.win-cli-mcp/config.json`, `enableInjectionProtection`, and per-shell `blockedOperators` (`server/src/utils/config.ts:56-57`; `server/src/types/config.ts:10-19`). `installation.md:14,60,112-115` also claims Node 16 and the wrong binary name `win-cli-server`.

`securite.md` is an unreferenced, smaller duplicate of `SECURITY.md` with the same invalid schema; inbound links point to `SECURITY.md` instead.

**Preservation for duplicate removal:** win-cli tree `ea96a08ce979983724474c8e2ddaf08880f02ef2`; the baseline tree above preserves both security variants.

**Action:** one bounded win-cli documentation rewrite against fork 0.2.0; remove `securite.md` only after all unique useful content is merged into corrected `SECURITY.md`.

## Complete 45-file disposition

| Path | Age | SHA8 | Status | Reason |
|---|---:|---|---|---|
| `mcps/external/README.md` | 425 | `e2386f3f` | UPDATE-NEEDED | Directory index is incomplete and contains phantom `filesystem/` |
| `mcps/external/desktop-commander/README.md` | 152 | `2d942f3b` | REMOVE | MCP is explicitly retired and absent from canonical config |
| `mcps/external/docker/BUILD-LOCAL.md` | 419 | `44698fa5` | UPDATE-NEEDED | Wrong image/tag and mount in manual config |
| `mcps/external/docker/CONFIGURATION.md` | 425 | `3074ff61` | UPDATE-NEEDED | Retain, verify canonical command during package update |
| `mcps/external/docker/INSTALLATION.md` | 425 | `fab4a37a` | UPDATE-NEEDED | Node 14 prerequisite is obsolete |
| `mcps/external/docker/README.md` | 419 | `e7b50aa2` | UPDATE-NEEDED | Retain, align cross-file installation claims |
| `mcps/external/docker/TROUBLESHOOTING.md` | 425 | `0abffc14` | UPDATE-NEEDED | Retain, align prerequisite references |
| `mcps/external/docker/USAGE.md` | 425 | `599308fd` | UPDATE-NEEDED | Retain, align package-level references |
| `mcps/external/git/CONFIGURATION.md` | 425 | `33bfe55e` | UPDATE-NEEDED | Wrong package identity and unsupported options/env vars |
| `mcps/external/git/INSTALLATION.md` | 425 | `c2c643b5` | UPDATE-NEEDED | npm package conflicts with configured Python server |
| `mcps/external/git/README.md` | 425 | `8231b42c` | UPDATE-NEEDED | Tool/package description conflicts with config and adjacent source |
| `mcps/external/git/TROUBLESHOOTING.md` | 425 | `4d763c88` | UPDATE-NEEDED | Troubleshoots the wrong package and variables |
| `mcps/external/git/USAGE.md` | 425 | `a6809347` | UPDATE-NEEDED | Tool surface does not match configured server |
| `mcps/external/git/server/CHANGELOG.md` | 425 | `7e82f70f` | UPDATE-NEEDED | Stops at 2.0.5 while manifest is 2.0.6 |
| `mcps/external/git/server/README.md` | 425 | `c7bc5d9e` | UPDATE-NEEDED | Says 2.0.2 while manifest is 2.0.6; package unused by config |
| `mcps/external/github/CONFIGURATION.md` | 425 | `a3e058a8` | UPDATE-NEEDED | Unsupported CLI/env/HTTP claims |
| `mcps/external/github/INSTALLATION.md` | 425 | `33004a3b` | UPDATE-NEEDED | Node 14 and nonexistent HTTP verification |
| `mcps/external/github/README.md` | 425 | `55cb938f` | UPDATE-NEEDED | Must distinguish active Node package from unrelated Go notices |
| `mcps/external/github/TROUBLESHOOTING.md` | 425 | `b350dcc5` | UPDATE-NEEDED | Unsupported retry/debug flags and env vars |
| `mcps/external/github/USAGE.md` | 425 | `ad778622` | UPDATE-NEEDED | Tool list needs current upstream verification |
| `mcps/external/github/server/third-party-licenses.darwin.md` | 425 | `745df2a2` | REMOVE | Notice belongs to absent Go server, not configured Node package |
| `mcps/external/github/server/third-party-licenses.linux.md` | 425 | `745df2a2` | REMOVE | Duplicate notice for absent Go server |
| `mcps/external/github/server/third-party-licenses.windows.md` | 425 | `97a72e17` | REMOVE | Notice belongs to absent Go server |
| `mcps/external/jupyter/README.md` | 425 | `9d65e6d0` | REMOVE | Obsolete Node server; active MCP is Papermill |
| `mcps/external/jupyter/configurations-jupyter-mcp.md` | 425 | `ba5c6c2f` | REMOVE | Nonexistent paths and unused schema |
| `mcps/external/jupyter/troubleshooting.md` | 425 | `d6457945` | REMOVE | Nonexistent paths/scripts for retired implementation |
| `mcps/external/markitdown/CONFIGURATION.md` | 315 | `3c817bef` | UPDATE-NEEDED | Python 3.9 and hardcoded user path conflict with manifest/config |
| `mcps/external/markitdown/README.md` | 364 | `478d7d89` | UPDATE-NEEDED | Describes manipulation rather than conversion to Markdown |
| `mcps/external/playwright/CONFIGURATION.md` | 315 | `6c0c544e` | UPDATE-NEEDED | Wrong local binary path and inverted deployment recommendation |
| `mcps/external/playwright/INSTALLATION_REPORT.md` | 280 | `0f2a4a68` | REMOVE | Stale one-machine snapshot, version 0.0.41 vs 0.0.70 |
| `mcps/external/playwright/README.md` | 364 | `370b190a` | UPDATE-NEEDED | Nonexistent `lib/index.js` path; canonical deployment is npx |
| `mcps/external/searxng/README.md` | 315 | `ef3528c0` | UPDATE-NEEDED | Wrong npm package and config pattern |
| `mcps/external/searxng/TROUBLESHOOTING.md` | 315 | `df28ee8a` | UPDATE-NEEDED | Troubleshoots deprecated package/path/schema |
| `mcps/external/searxng/USAGE.md` | 425 | `5a3d9c38` | UPDATE-NEEDED | Must align examples with current two-tool server |
| `mcps/external/searxng/configuration.md` | 425 | `55db8388` | UPDATE-NEEDED | Fabricated JSON schema vs `SEARXNG_URL` contract |
| `mcps/external/searxng/exemples.md` | 425 | `a3c0d73b` | UPDATE-NEEDED | Remove multi-instance assumptions; verify tool arguments |
| `mcps/external/searxng/installation.md` | 425 | `bf68b175` | UPDATE-NEEDED | Wrong package, binary paths, and Node minimum |
| `mcps/external/win-cli/README.md` | 130 | `4bbfba39` | UPDATE-NEEDED | Dual-harness guidance conflicts with current policy |
| `mcps/external/win-cli/SECURITY.md` | 425 | `a24612bd` | UPDATE-NEEDED | Security examples use fields absent from fork schema |
| `mcps/external/win-cli/TROUBLESHOOTING.md` | 425 | `a192e401` | UPDATE-NEEDED | Wrong Node minimum, config path, and fields |
| `mcps/external/win-cli/USAGE.md` | 425 | `d6d00e08` | UPDATE-NEEDED | Command-chaining explanation uses obsolete schema |
| `mcps/external/win-cli/configuration.md` | 425 | `9d46ecfc` | UPDATE-NEEDED | Major rewrite needed against actual fork schema |
| `mcps/external/win-cli/exemples.md` | 425 | `602724d2` | UPDATE-NEEDED | Operator defaults conflict with fork configuration |
| `mcps/external/win-cli/installation.md` | 419 | `caa9adc0` | UPDATE-NEEDED | Node 16 and binary/config instructions are wrong |
| `mcps/external/win-cli/securite.md` | 425 | `f72ebddb` | REMOVE | Unreferenced duplicate of `SECURITY.md`; merge useful content first |

## Recommended PR sequence

The issue caps work at five PRs per cycle and requires one MCP decision per PR. Recommended order:

1. Audit report + JSON companion (this deliverable).
2. desktop-commander removal/consolidation (retired and misleading deployment claim).
3. jupyter removal/consolidation (explicitly obsolete, canonical server changed).
4. win-cli documentation rewrite (active critical MCP, highest schema drift).
5. searxng documentation rewrite (active standard MCP, wrong package/config throughout).

Subsequent cycle: git, github, playwright, markitdown, docker, then the external index after package decisions settle.
