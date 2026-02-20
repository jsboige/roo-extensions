# Global Claude Code Instructions (Machine-Level)

These instructions apply to ALL projects on this machine.
Deploy to `~/.claude/CLAUDE.md` on each machine.

**Source of truth:** `.claude/configs/user-global-claude.md` in the **roo-extensions** repository (workspace d'harmonisation inter-machines)
**Deployed to:** `~/.claude/CLAUDE.md` (local, not in git, applies to ALL workspaces on this machine)
**Update workflow:** Edit the source in roo-extensions, commit+push, then each machine pulls and copies to `~/.claude/CLAUDE.md`

---

## Terminology & User Preferences

### "Consolider" (Consolidate) != "Archiver" (Archive)

When the user asks to **consolidate** scripts/files, this is a 3-step process:

1. **ANALYZE**: Read the script to consolidate. Understand every function and feature it provides.
2. **MERGE**: For each feature, either:
   - Verify it already exists in the target script (cite the exact line), OR
   - Merge the feature into the target script
3. **ARCHIVE**: Only THEN move the old script to `_archives/` with a header comment:
   ```
   # Archived: [date] - Superseded by [target_script]
   # Features merged: [list of features]
   ```

**What consolidation is NOT:**
- Simply moving a file to `_archives/` without verifying feature coverage
- Deleting code without ensuring its functionality lives elsewhere
- Assuming two scripts with similar names do the same thing

**Verification checklist before archiving:**
- [ ] Every function/feature in the old script has been identified
- [ ] Each feature exists in the replacement (with line numbers as proof)
- [ ] Any missing features have been merged into the replacement
- [ ] Scripts that CALL the old script have been updated to call the replacement
- [ ] The replacement has been tested (or at minimum, syntax-checked)

This rule was established after a Session 101 incident where 8+ scripts were archived without verifying their features were preserved, breaking the deployment pipeline.

---

## General Conventions

### Language
- The user communicates in French
- Code, commits, and technical docs can be in English
- User-facing messages and INTERCOM should be in French when relevant

### Safety
- Never delete files without verifying their content is preserved elsewhere
- Always backup before destructive operations
- Prefer reversible actions over irreversible ones
- Never commit secrets (.env, API keys, credentials, tokens) - use .gitignore

---

## Git Best Practices

### Conflict Resolution (CRITICAL)
- **NEVER auto-resolve conflicts blindly** - always review each conflict manually
- **NEVER pick "ours" or "theirs" globally** without understanding what each side contains
- Before pull: `git fetch origin` to inspect incoming changes
- When conflicts arise: read the markers (`<<<<<<<`, `=======`, `>>>>>>>`), understand both sides, decide deliberately
- The choice between rebase and merge depends on the project (rebase is cleaner for linear history, merge preserves parallel history)

### Commit Discipline
- **Conventional commits**: `type(scope): description` (fix, feat, docs, refactor, test, chore)
- Always include `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>` when AI-assisted
- Atomic commits: one intention per commit, not batch dumps
- Reference issue numbers when applicable: `fix(auth): Fix #123 - token refresh loop`

### Submodule Workflow
- Commit inside submodule FIRST, push
- Then `git add submodule-path` in parent repo, commit, push
- Both repos push to their respective remotes
- Never modify submodule pointer without committing the inner change first

### Never Force Push
- `git push --force` is forbidden on shared branches (main, develop)
- Use `--force-with-lease` only in exceptional cases with explicit user approval
- If push is rejected: fetch, merge, retry

---

## Claude Code Tool Discipline

### Read Before Edit (CRITICAL)
- **ALWAYS read a file before editing it** - the Edit tool will fail otherwise
- Even for `replace_all` operations, read the file first
- This prevents blind edits and ensures you understand the current state

### Test Commands
- Many projects use `npm test` in watch mode (Vitest, Jest) which blocks forever
- **Always verify** if `npm test` blocks. If so, use `npx vitest run` or `npx jest --ci`
- General rule: prefer explicit non-interactive test commands

### Build Verification
- Always build + test after code changes before committing
- Never assume a change is safe without running the test suite
- If tests fail: fix BEFORE committing, never commit broken code

---

## Investigation Methodology

### Code Source > Documentation
- Documentation may be outdated, especially in active projects
- When investigating a feature or bug, **start from the code source** as truth
- Use Grep + Read for systematic exploration, then cross-reference docs
- If docs contradict code, trust the code and update the docs

### Announce Work Before Starting
- Before starting significant work, announce what files/areas you'll modify
- This prevents conflicts when multiple agents (Roo, Claude, other machines) work in parallel
- Use INTERCOM, RooSync, or issue comments depending on context

---

## Knowledge Preservation

### Session Continuity
- Claude Code has no memory between sessions beyond what's written to files
- **ALWAYS consolidate learnings before session ends**: update MEMORY.md, PROJECT_MEMORY.md
- Key patterns, bug fixes, and architectural decisions MUST be written down
- If context is running low: prioritize knowledge consolidation over finishing the current task

### Memory Hierarchy (roo-extensions specific, but pattern applies to all projects)
- **Global user** (`~/.claude/CLAUDE.md`): Cross-project rules (THIS FILE)
- **Project instructions** (`CLAUDE.md` at repo root): Project-specific architecture, workflows
- **Auto-memory** (`~/.claude/projects/<hash>/memory/MEMORY.md`): Per-machine state, session learnings
- **Shared memory** (`.claude/memory/PROJECT_MEMORY.md`): Cross-machine shared knowledge (via git)
- **Rules** (`.claude/rules/*.md`): Enforceable project-specific rules

---

## Windows / PowerShell Gotchas

### UTF-8 BOM
- PowerShell's `Set-Content` and `Out-File` add BOM by default, which breaks many parsers (JSON, YAML)
- **Always use** `[System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))`
- Or in PowerShell 7+: `-Encoding utf8NoBOM`

### Join-Path (PowerShell 5.1)
- `Join-Path` only accepts 2 arguments on PS 5.1 (Windows default)
- `Join-Path $a "b" "c" "d"` FAILS - use string interpolation: `"$a/b/c/d"`
- Always test scripts with `powershell -ExecutionPolicy Bypass -File script.ps1`

### Line Endings
- Git on Windows: ensure `core.autocrlf = true` or use `.gitattributes`
- Some tools are sensitive to CRLF vs LF (Bash scripts, Docker, etc.)

---

## MCP Tools Available (Global)

These MCPs are deployed on all machines and available in any workspace.

### roo-state-manager (36 tools)

Expose les taches, conversations, et outils de coordination de Roo Code. Utilise-les pour comprendre ce que Roo a fait et pour coordonner.

**Outils essentiels a connaitre :**

| Outil | Usage | Quand l'utiliser |
|-------|-------|-----------------|
| `task_browse` | Arbre des taches Roo (hierarchie parent/enfant) | Comprendre ce que Roo fait ou a fait |
| `view_conversation_tree` | Squelette d'une conversation Roo | Analyser le deroulement d'un travail Roo |
| `roosync_summarize` | Resume structure d'une conversation | Documenter, rapport, comprendre |
| `roosync_search` | Recherche dans les taches (texte + semantique) | Trouver une tache passee par sujet |
| `read_vscode_logs` | Logs VS Code et Roo recents | Debugger un MCP, une extension |
| `get_mcp_best_practices` | Guide bonnes pratiques MCP | Configurer ou debugger un MCP |
| `manage_mcp_settings` | Lire/modifier config MCP de Roo | Deploiement, harmonisation |

**Bonnes pratiques :**
- `task_browse(action: "current")` pour savoir ce que Roo fait en ce moment
- `view_conversation_tree` avec `smart_truncation: true` pour les longues conversations (evite overflow)
- `roosync_search(action: "text", search_query: "...")` pour chercher dans l'historique Roo
- Ne pas utiliser `roosync_summarize` mode `synthesis` (bug connu)

### playwright (browser automation)
- Automatisation web, screenshots, navigation
- Utile pour tester des UI, scraper, valider des deployements

### markitdown (document conversion)
- Convertir PDF, DOCX, XLSX etc. en Markdown
- Utile pour lire des documents non-texte

---

## Infrastructure Machine (myia-ai-01)

Cette machine heberge de nombreux services accessibles via reverse proxies IIS (`*.myia.io`) et en Docker local. Ces services sont disponibles pour TOUS les workspaces.

### Services exposes via HTTPS (reverse proxies IIS)

| Domaine HTTPS | Port local | Service | Usage |
|---------------|-----------|---------|-------|
| `open-webui.myia.io` | 2090 | Open WebUI (tenant myia) | Interface chat LLM |
| `qdrant.myia.io:443` | 6333 | Qdrant Vector DB | Recherche semantique |
| `search.myia.io` | 8181 | SearXNG | Recherche web (self-hosted, gratuit) |
| `tika.myia.io` | 9917 | Apache Tika | Extraction texte PDF/DOCX/etc. |
| `embeddings.myia.io` | (po-2026) | Embedding API | OpenAI-compatible, modele qwen3-4b-awq |
| `whisper-webui.myia.io` | (po-2023) | Whisper STT | Transcription audio |
| `turbo.sd-forge.myia.io` | (po-2023) | SD WebUI Forge | Generation images (Flux) |

**Gotchas :**
- **Qdrant** : Le client Python ajoute `:6333` auto. Toujours ecrire `https://qdrant.myia.io:443`.
- **Tika API** : `PUT https://tika.myia.io/tika` avec fichier en body, `Accept: text/plain`. Retourne le texte extrait.
- **SearXNG API** : `GET https://search.myia.io/search?q=...&format=json`. Retourne `{results: [...]}`.

### Services Docker locaux (pas de reverse proxy)

| Port | Service | GPU |
|------|---------|-----|
| 5001 | vLLM mini — ZwZ-8B-AWQ | GPU 2 |
| 5002 | vLLM medium — GLM-4.7-Flash-AWQ | GPU 0+1 |
| 8880 | Kokoro TTS (67 voix, fr=ff_siwis) | GPU 2 |
| 8787 | Whisper STT adapter | CPU |
| 9099 | Open WebUI Pipelines (4 filtres) | CPU |

### GPU Fleet

| Machine | GPU(s) | VRAM | Role |
|---------|--------|------|------|
| myia-ai-01 | 3x RTX 4090 | 72 GB | OWUI, vLLM, Qdrant, Tika, TTS |
| myia-po-2023 | RTX 3090 + RTX 3080 | 40 GB | Whisper STT, SD Forge |
| myia-po-2026 | RTX 3080 | 16 GB | Embeddings |

---

## Subagents Recommandes (Cross-Workspace)

Certains agents definis dans roo-extensions sont utiles dans n'importe quel workspace. Les recreer (ou copier depuis `roo-extensions/.claude/agents/`) dans les nouveaux projets.

### Agents universels

| Agent | Fichier source | Usage universel |
|-------|---------------|-----------------|
| `code-fixer` | `.claude/agents/workers/code-fixer.md` | Investiguer et corriger un bug autonomement |
| `test-investigator` | `.claude/agents/workers/test-investigator.md` | Analyser des tests qui echouent |
| `test-runner` | `.claude/agents/test-runner.md` | Lancer build + tests, rapport structure |
| `code-explorer` | `.claude/agents/code-explorer.md` | Explorer un codebase inconnu |
| `git-sync` | `.claude/agents/git-sync.md` | Pull conservatif avec resolution conflits |
| `doc-updater` | `.claude/agents/workers/doc-updater.md` | MAJ docs apres changements |

### Agents specifiques roo-extensions (NE PAS copier)
- `roosync-hub`, `roosync-reporter`, `dispatch-manager` : coordination multi-machines
- `intercom-handler`, `intercom-compactor` : communication locale Roo
- `consolidation-worker` : specifique aux consolidations CONS-X

---

## SDDD - Investigation Methodology

Le protocole **SDDD (Semantic Documentation Driven Development)** structure les investigations techniques en 3 types de grounding. Applicable a tout projet.

### 1. Grounding Technique (toujours disponible)
- **Outils** : Read, Grep, Glob, Bash
- **Methode** : Partir du code source comme verite, explorer systematiquement
- Lire les fichiers cles, tracer les imports, comprendre l'architecture
- Les docs peuvent etre obsoletes, le code ne ment pas

### 2. Grounding Conversationnel (si roo-state-manager disponible)
- **Outils** : `task_browse`, `view_conversation_tree`, `roosync_summarize`
- **Methode** : Analyser ce que Roo a fait sur le sujet
  1. `task_browse(action: "tree")` pour voir l'arbre des taches
  2. `view_conversation_tree(smart_truncation: true)` pour le squelette
  3. `roosync_summarize(type: "trace")` pour les statistiques
- Permet de ne pas refaire un travail deja fait par Roo

### 3. Grounding Semantique (si index Qdrant disponible)
- **Outils** : `roosync_search(action: "semantic")` pour les conversations
- **Status** : La recherche dans les fichiers du workspace (codebase) n'est pas encore exposee a Claude (#452 - en cours). Utiliser Grep en attendant.
- **Methode** : Chercher par concept plutot que par mot-cle exact
- Utile pour retrouver des discussions passees sur un sujet

### Workflow SDDD recommande

```
1. TECHNIQUE  : Grep/Read le code source (verite)
2. CONVERSATIONNEL : task_browse + view_conversation_tree (contexte Roo)
3. SEMANTIQUE : roosync_search si pertinent (historique)
4. SYNTHESE : Croiser les 3 sources, documenter les conclusions
```

**Regle** : Ne jamais se contenter d'une seule source. Le croisement des 3 groundings evite les erreurs.

---

## Self-Maintenance (Auto-Entretien de la Documentation)

**OBLIGATION apres chaque tache significative :**

1. **Mettre a jour CLAUDE.md** (du projet) si les sections techniques changent
2. **Mettre a jour MEMORY.md** (auto-memoire) avec l'etat courant et les lecons apprises
3. **Enregistrer ce qui a ete teste et rejete** (avec les raisons) pour eviter de refaire des experiences echouees
4. **Verifier la coherence** des deux fichiers avant de terminer une session

Ce pattern vient de l'experience multi-projets : sans auto-entretien, les sessions suivantes perdent du temps a redecouvrir des informations deja connues.

---

## Configuration Globale Deployee

### Agents, Skills et Commands globaux

Des templates generiques sont deployes dans `~/.claude/` pour etre disponibles dans tous les workspaces.

**Source de verite :** `roo-extensions/.claude/configs/` (git-tracked, synchronise entre machines)

**Deploiement :**
```powershell
# Depuis le repertoire roo-extensions
powershell -ExecutionPolicy Bypass -File .claude/configs/scripts/Deploy-GlobalConfig.ps1
```

**Contenu deploye :**

| Type | Nom | Description |
|------|-----|-------------|
| Agent | `code-fixer` | Investigation et correction de bugs |
| Agent | `test-investigator` | Investigation tests qui echouent |
| Agent | `test-runner` | Build + tests, rapport structure |
| Agent | `code-explorer` | Exploration read-only du codebase |
| Agent | `git-sync` | Pull, submodules, resolution conflits |
| Agent | `doc-updater` | MAJ docs apres changements |
| Skill | `validate` | CI local : build + tests |
| Skill | `git-sync` | Synchronisation Git intelligente |
| Skill | `debrief` | Analyse de session + capture connaissances |
| Command | `switch-provider` | Basculer entre providers LLM |
| Command | `debrief` | Lancer une analyse de session |

**Override projet :** Si un projet a ses propres versions dans `.claude/agents/`, `.claude/skills/`, etc., elles surchargent les globales. C'est le mecanisme standard de Claude Code.
