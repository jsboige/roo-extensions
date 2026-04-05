# Roo Extensions - Guide Agent Claude Code

**Repo:** [jsboige/roo-extensions](https://github.com/jsboige/roo-extensions)
**Systeme:** RooSync v2.3 — 6 machines
**MAJ:** 2026-04-05

---

## Vue d'ensemble

Multi-agent coordonnant **Roo Code** (technique, scheduler) et **Claude Code** (implementation, coordination, docs) sur 6 machines : `myia-ai-01` (coordinateur), `myia-po-2023/24/25/26`, `myia-web1`.

**Claude DIRIGE, Roo ASSISTE.** Claude = code critique + architecture + decisions. Roo = tests, build, taches repetitives (validees par Claude). Ne JAMAIS deleguer du code critique a Roo.

---

## Demarrage

1. `git pull`
2. **Verifier MCPs** (system-reminders). roo-state-manager absent → [STOP & REPAIR](.claude/rules/tool-availability.md)
3. **Lire inbox RooSync** (`roosync_read(mode: "inbox")`) — OBLIGATOIRE
4. Annoncer via dashboard/RooSync avant de travailler

---

## Canaux Communication

| Canal | Portee | Outil |
|-------|--------|-------|
| **RooSync** | **Inter-machines** | `roosync_send/read/manage` via MCP |
| **Dashboard workspace** | **Cross-machine (PRINCIPAL)** | `roosync_dashboard(type: "workspace")` |
| **INTERCOM local** | Intra-workspace (fallback) | `.claude/local/INTERCOM-{MACHINE}.md` |

**RooSync = inter-machine. INTERCOM = local. Ne jamais confondre.**
Les deux agents (Roo ET Claude) utilisent RooSync pour communiquer entre machines.

**Detail :** [.claude/rules/intercom-protocol.md](.claude/rules/intercom-protocol.md)

---

## MCPs

| Critique pour | MCP | Outils |
|---------------|-----|--------|
| **Claude Code** | roo-state-manager | 34 |
| **Roo Scheduler** | win-cli (fork local 0.2.0) | 9 |

**Config Claude Code :** `C:\Users\{user}\.claude.json` section `mcpServers`
**Config Roo (GLOBAL, pas projet) :** `%APPDATA%\...\mcp_settings.json`
**MCPs retires (ne doivent pas exister) :** desktop-commander, quickfiles, github-projects-mcp

**Inventaire complet :** [.claude/rules/tool-availability.md](.claude/rules/tool-availability.md)

---

## Config Hierarchy

| Niveau | Fichier | Portee |
|--------|---------|--------|
| Global | `~/.claude/CLAUDE.md` | Tous projets |
| Projet | `CLAUDE.md` (racine) | Ce projet |
| Local | `CLAUDE.local.md` | Machine (gitignored) |
| Permissions | `.claude/settings.json` | Auto-approve (git-tracked) |
| Rules | `.claude/rules/*.md` | Auto-chargees chaque conversation |
| Auto-memoire | `~/.claude/projects/<hash>/memory/` | Prive, local |
| Memoire partagee | `.claude/memory/PROJECT_MEMORY.md` | Via git |

---

## Agents, Skills & Commands

**18 subagents** (5 communs + 2 coordinateur + 11 workers) + 6 globaux.
**6 skills :** sync-tour, validate, git-sync, github-status, redistribute-memory, debrief.
**4 commands :** /coordinate, /executor, /switch-provider, /debrief.

**Detail :** [.claude/rules/agents-architecture.md](.claude/rules/agents-architecture.md)

---

## Structure

```
.claude/rules/     # 10 regles auto-chargees (operationnelles)
.claude/docs/      # Docs on-demand (voir INDEX.md)
.claude/agents/    # Subagents (coordinator/, executor/, workers/)
.claude/skills/    # Skills auto-invoques
.claude/commands/  # Slash commands
mcps/internal/     # roo-state-manager (TS) + sk-agent (Python)
roo-code/          # Submodule git (REFERENCE SEULEMENT)
roo-config/        # Modes Roo (modes-config.json + scripts)
```

**Submodule `roo-code/` :** Reference pour lire le code source Roo. PAS un env de build, PAS de `npm install`, PAS de `node_modules` utilisables. Pipeline modes : `modes-config.json` → `generate-modes.js` → `.roomodes`.

---

## Modes Roo

| Type | Groupes | Terminal | Exemples |
|------|---------|----------|----------|
| Orchestrateurs | `[]` | NON | orchestrator-simple/complex |
| -simple | read,edit,browser,mcp | **NON** (win-cli MCP) | code-simple, debug-simple |
| -complex | +command | OUI (natif) | code-complex, debug-complex |

**Orchestrateurs = delegation pure** (aucun outil, `new_task` uniquement).
**-simple = win-cli comme terminal** (pas le groupe `command` natif).

---

## GitHub

**Project #67 :** [GitHub Projects](https://github.com/users/jsboige/projects/67)
**Format issues :** `[CLAUDE-MACHINE] Titre` + labels.
**Labels :** Verifier avec `gh label list`. **N'EXISTENT PAS :** maintenance, scheduler, memory.
**Obligatoires :** bug/enhancement/documentation + attribution (claude-only ou roo-schedulable).
**Detail :** [.claude/docs/github-cli.md](.claude/docs/github-cli.md)

---

## Rules Auto-chargees

**Critiques :** [Tool Availability](.claude/rules/tool-availability.md) | [Validation](.claude/rules/validation.md) | [No Deletion](.claude/rules/no-deletion-without-proof.md) | [PR Mandatory](.claude/rules/pr-mandatory.md) | [CI Guardrails](.claude/rules/ci-guardrails.md)
**Ops :** [File Writing](.claude/rules/file-writing.md)
**Communication :** [INTERCOM](.claude/rules/intercom-protocol.md) | [Skepticism](.claude/rules/skepticism-protocol.md)
**Contexte :** [Context Window](.claude/rules/context-window.md) | [Agents](.claude/rules/agents-architecture.md)

**Index docs on-demand :** [.claude/docs/INDEX.md](.claude/docs/INDEX.md)

---

## Regles Absolues

1. RooSync = GDrive UNIQUEMENT (jamais dans git)
2. INTERCOM = local, RooSync = inter-machine
3. JAMAIS modifier `.roomodes`/`.roo/schedules.json` directement (sources + regenerer)
4. Validation checklist OBLIGATOIRE pour consolidation/refactoring
5. Annoncer avant de travailler
6. STOP & REPAIR si MCP critique absent
7. Verification cross-machine apres changement config
8. Scepticisme : ne JAMAIS propager affirmation non verifiee
9. VS Code restart requis apres modification schedules
10. Worktree cleanup apres PR merge/close
11. JAMAIS de cles API dans GitHub (RooSync pour partage)
12. `.claude/` = PROTEGE (harnais uniquement, pas de temporaires)

---

**Derniere MAJ :** 2026-04-05
