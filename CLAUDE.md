# Roo Extensions - Guide Agent Claude Code

**Repo:** [jsboige/roo-extensions](https://github.com/jsboige/roo-extensions)
**Systeme:** RooSync v2.3 — 6 machines
**MAJ:** 2026-04-25

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
| **Dashboard workspace** | **Cross-machine (PRINCIPAL)** | `roosync_dashboard(type: "workspace")` |
| **RooSync** | **Inter-machines** | `roosync_send/read/manage` via MCP |
| **INTERCOM local** | Intra-workspace (fallback) | `.claude/local/INTERCOM-{MACHINE}.md` |

**RooSync = inter-machine. INTERCOM = local. Ne jamais confondre.**

---

## MCPs

| Critique pour | MCP | Outils |
|---------------|-----|--------|
| **Claude Code** | roo-state-manager | 34 |
| **Roo Scheduler** | win-cli (fork local 0.2.0) | 9 |

**Config Claude Code :** `C:\Users\{user}\.claude.json` | **Config Roo :** `%APPDATA%\...\mcp_settings.json`
**MCPs retires :** desktop-commander, quickfiles, github-projects-mcp
**Inventaire complet :** [.claude/rules/tool-availability.md](.claude/rules/tool-availability.md)

---

## Config Hierarchy

| Niveau | Fichier | Portee |
|--------|---------|--------|
| Global | `~/.claude/CLAUDE.md` | Tous projets |
| Projet | `CLAUDE.md` (racine) | Ce projet |
| Local | `CLAUDE.local.md` | Machine (gitignored) |
| Harness | `~/.claude/settings.json` | Provider tuning + permissions (JAMAIS dans le repo) |
| Rules | `.claude/rules/*.md` | Auto-chargees chaque conversation |

**ai-01 (Opus)** : `AUTO_COMPACT_WINDOW=1000000`, `COMPACT_PCT=20` | **Autres (GLM)** : `200000`, `75`. **`.claude/settings.json` projet : INTERDIT.** `settings.local.json` : tolere pour permissions uniquement.

---

## Agents, Skills & Commands

**18 subagents** + **6 skills** + **4 commands** (`/coordinate`, `/executor`, `/switch-provider`, `/debrief`).
**Detail :** [.claude/rules/agents-architecture.md](.claude/rules/agents-architecture.md)

---

## Structure

```
.claude/rules/     # Regles auto-chargees
.claude/agents/    # Subagents
.claude/skills/    # Skills auto-invoques
.claude/commands/  # Slash commands
docs/harness/      # Docs on-demand
mcps/internal/     # roo-state-manager (TS) + sk-agent (Python)
roo-code/          # Submodule git (REFERENCE SEULEMENT)
roo-config/        # Modes Roo (modes-config.json + scripts)
```

**Submodule `roo-code/` :** Reference pour lire le code source Roo. PAS un env de build. Pipeline modes : `modes-config.json` → `generate-modes.js` → `.roomodes`.

---

## Modes Roo

| Type | Groupes | Terminal | Exemples |
|------|---------|----------|----------|
| Orchestrateurs | `[]` | NON | orchestrator-simple/complex |
| -simple | read,edit,browser,mcp | **NON** (win-cli MCP) | code-simple, debug-simple |
| -complex | read,edit,browser,mcp | **NON** (win-cli MCP) | code-complex, debug-complex |

**Orchestrateurs = delegation pure. AUCUN mode n'a le groupe `command` natif** (#1482).

---

## Team Pipeline — Structured Task Execution (#1853)

**Inspired by:** oh-my-claudecode Team mode evaluation (#1802)

### Overview

For complex tasks (>3 files or >50 LOC), agents MUST follow the Team pipeline stages to ensure structured, verifiable execution.

### Stages

| Stage | Purpose | Trigger | Output |
|-------|---------|---------|--------|
| **team-plan** | Break down task into subtasks | All complex tasks | Task list with dependencies |
| **team-prd** | Clarify requirements and constraints | Ambiguous specifications | Requirements document |
| **team-exec** | Execute the implementation | After plan/PRD | Code changes |
| **team-verify** | Verify the solution (build + tests) | After exec | Build/test results |
| **team-fix** | Fix any issues found in verification | Failed verify | Fixes, loops until verify passes |

### Stage Ordering Rules

**For complex tasks (>3 files or >50 LOC):**
- **team-plan** required before **team-exec**
- **team-prd** required for ambiguous requirements
- **team-verify** (build + tests) required before marking [DONE]
- **team-fix** loops until verification passes

**For simple tasks (≤3 files and ≤50 LOC):**
- May skip to **team-exec** → **team-verify** directly
- Use `teamStage: "none"` or omit the parameter

### Dashboard Reporting

Agents MUST report their current Team stage in dashboard messages:

```
roosync_dashboard(
  action: "append",
  type: "workspace",
  tags: ["PROGRESS", "team-plan"],
  teamStage: "team-plan",
  content: "Task broken down into 5 subtasks..."
)
```

### Stage Transitions

```
[START] → team-plan → team-prd → team-exec → team-verify → [DONE]
                                         ↓
                                      team-fix (loop until verify passes)
```

### Related Issues

- #1853 — Team pipeline implementation (this issue)
- #1802 — oh-my-claudecode evaluation (source)
- #1869 — Team pipeline ADR + Hermes bootstrap

---

## GitHub

**Project #67 :** [GitHub Projects](https://github.com/users/jsboige/projects/67)
**Format issues :** `[CLAUDE-MACHINE] Titre` + labels. **Obligatoires :** bug/enhancement/documentation + attribution (claude-only ou roo-schedulable).
**Detail :** [docs/harness/reference/github-cli.md](docs/harness/reference/github-cli.md)

---

## Rules Auto-chargees

**Critiques :** [Tool Availability](.claude/rules/tool-availability.md) | [Validation](.claude/rules/validation.md) | [No Deletion](.claude/rules/no-deletion-without-proof.md) | [PR Mandatory](.claude/rules/pr-mandatory.md) | [CI Guardrails](.claude/rules/ci-guardrails.md) | [Issue Closure](.claude/rules/issue-closure.md) | [Agent Claim](.claude/rules/agent-claim-discipline.md)
**Ops :** [File Writing](.claude/rules/file-writing.md) | [Meta-Analyste](.claude/rules/meta-analyst.md) | [SDDD](.claude/rules/sddd-grounding.md) | [conversation_browser](.claude/rules/conversation-browser-guide.md)
**Com :** [INTERCOM](.claude/rules/intercom-protocol.md) | [Skepticism](.claude/rules/skepticism-protocol.md) | [Friction](.claude/rules/friction-protocol.md) | [MCP Diagnosis](.claude/rules/mcp-diagnosis.md)
**Contexte :** [Context Window](.claude/rules/context-window.md) | [Agents](.claude/rules/agents-architecture.md) | [Security](.claude/rules/security.md)

---

## Ressources

- **Docs on-demand :** [docs/harness/reference/INDEX.md](docs/harness/reference/INDEX.md) — index complet de toute la documentation
- **Coordinateur :** [scheduled-coordinator.md](docs/harness/coordinator-specific/scheduled-coordinator.md) | [pr-review-policy.md](docs/harness/coordinator-specific/pr-review-policy.md) | [skeptical-posture.md](docs/harness/coordinator-specific/skeptical-posture.md)
- **Guide RooSync :** [GUIDE-TECHNIQUE-v2.3.md](docs/roosync/GUIDE-TECHNIQUE-v2.3.md)
- **Scripts :** [scripts/README.md](scripts/README.md) | [scripts/claude/](scripts/claude/)
- **GitHub :** https://github.com/users/jsboige/projects/67

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
12. `.claude/` = SANCTUAIRE — jamais de fichiers temporaires. Body-files → `$TEMP`
13. Dashboard = canal de COMMANDEMENT : repondre a chaque rapport [DONE]
14. Dashboard = canal de RAPPORT : tout agent rapporte en fin de session
15. Agents proactifs : poster l'action envisagee AVANT de l'entreprendre (anti-double-claim)
16. Reviews exigeantes : PR >50 LOC = integration tracing template ([pr-review-policy.md](docs/harness/coordinator-specific/pr-review-policy.md) section 2)
17. Presomption de regression : "ne marche plus" apres >7j prod → chercher le commit rogue d'abord (#1463)
18. Coordinateur = gardien de la raison : exiger preuve de panne avant d'agir. [Posture detaillee](docs/harness/coordinator-specific/skeptical-posture.md)

---

**Derniere MAJ :** 2026-04-25
