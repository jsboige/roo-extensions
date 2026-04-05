# Global Claude Code Instructions (Machine-Level)

**Applies to:** ALL projects on this machine.
**Source:** `.claude/configs/user-global-claude.md` in roo-extensions repo
**Deploy:** `~/.claude/CLAUDE.md` (local, not in git, all workspaces)
**Update:** Edit source in roo-extensions, commit+push, each machine pulls+copies

---

## Terminology — "Consolider" != "Archiver"

**Consolidation = 3 steps:**
1. **ANALYZE** every function in the old script
2. **MERGE** each feature into target (cite exact line numbers as proof)
3. **ARCHIVE** only after verification — header: date, superseded-by, merged features

**NOT consolidation:** Moving to `_archives/` without proof of preservation. Established after Session 101 (8+ scripts lost, pipeline broken).

---

## Conventions

- **Language:** User = French. Code/commits/docs = English OK. INTERCOM = French when relevant.
- **Workspace scope:** Stay in YOUR workspace. Ignore dispatches from other workspaces. `roosync_dashboard(type: "workspace")` for YOUR workspace only.
- **Safety:** Never delete without proof of preservation. No secrets in commits. Prefer reversible actions.

---

## Git

- **Conventional commits:** `type(scope): description`. Include `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>` when AI-assisted
- **Conflicts:** NEVER auto-resolve blindly. Read markers, understand both sides, decide deliberately
- **Submodules:** Commit inside FIRST, push, then update pointer in parent
- **Force push:** Forbidden on shared branches. Rejected → fetch, merge, retry

---

## Tool Discipline

- **Read before Edit** — Edit fails without prior Read. Always.
- **Test commands:** `npx vitest run` / `npx jest --ci` (never `npm test` — watch mode blocks)
- **Build + test** after code changes. Never commit broken code.

---

## Windows / PowerShell Gotchas

- **UTF-8 BOM:** `Set-Content`/`Out-File` add BOM → breaks parsers. Use `[System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))` or PS7+ `-Encoding utf8NoBOM`
- **Join-Path PS 5.1:** Only 2 args. Use `"$a/b/c/d"` instead of `Join-Path $a "b" "c" "d"`
- **Line endings:** `core.autocrlf = true` or `.gitattributes`. CRLF-sensitive: Bash, Docker

---

## MCP Tools (Global)

### roo-state-manager (34 tools)

Coordination Roo Code — taches, conversations, dashboards.

| Outil | Usage |
|-------|-------|
| `conversation_browser(action: "list")` | Lister taches (**TOUJOURS commencer par la**) |
| `conversation_browser(action: "view", smart_truncation: true)` | Voir conversation |
| `roosync_search(action: "text")` | Chercher dans l'historique |
| `roosync_dashboard(action: "read", type: "workspace")` | Dashboard coordination |

**Bug connu:** `summarize_type: "synthesis"` peut echouer. Preferer `"trace"`.
**Dashboard redirect (#984):** Si reponse contient "written to file:", lire ce fichier avec `Read`.

### playwright (22 outils) / markitdown (1 outil)

- **playwright:** Automatisation web, screenshots, navigation
- **markitdown:** PDF/DOCX/XLSX → Markdown

---

## SDDD — Investigation Methodology

**Triple grounding (obligatoire pour travail significatif):**
1. **Technique** — Code source = verite (Read, Grep, Glob)
2. **Conversationnel** — `conversation_browser` pour historique Roo
3. **Semantique** — `codebase_search` + `roosync_search(semantic)` pour recherche par concept

**Regle:** Ne jamais se contenter d'une seule source. Croiser les 3 groundings.
**Pattern Bookend:** `codebase_search` en DEBUT et FIN de chaque tache significative.

---

## Knowledge Preservation

- **No memory between sessions.** Always write learnings to files before session ends.
- **Memory hierarchy:**
  - `~/.claude/CLAUDE.md` — Global (THIS FILE)
  - `CLAUDE.md` (repo root) — Project instructions
  - `~/.claude/projects/<hash>/memory/MEMORY.md` — Per-machine session learnings
  - `.claude/memory/PROJECT_MEMORY.md` — Cross-machine shared (via git)
  - `.claude/rules/*.md` — Auto-loaded project rules

**After each significant task:** Update project CLAUDE.md + MEMORY.md. Record rejected approaches.

---

## Self-Maintenance

**After each significant task:**
1. Update project CLAUDE.md if technical sections changed
2. Update MEMORY.md with current state + lessons learned
3. Record tested-and-rejected approaches (avoid repeating experiments)
4. Verify coherence before ending session
