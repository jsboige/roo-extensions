# Roo Extensions - Guide Agent Claude Code

**Repo:** [jsboige/roo-extensions](https://github.com/jsboige/roo-extensions)
**Systeme:** RooSync v2.3 — 6 machines
**MAJ:** 2026-04-28

## Travail récent

### GitHub Issue #1786: Task index pollué par les tâches exploded
**Phase 3 (Prévention) complétée le 2026-04-28:**
- Implémentation du DeathSpiralDetector (`src/services/death-spiral-detector.ts`)
- Ajout de l'action `garbage_monitor` dans `roosync-indexing.tool.ts`
- Détection proactive des "death spiral tasks" avant qu'elles ne polluent le cache
- Seuils configurables: error_ratio (80%), assistant_output_ratio (<5%), rapid_error_count, time_window_minutes
- Classification des risques: CRITICAL/HIGH/MEDIUM/LOW
- Actions automatiques recommandées selon le niveau de risque

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
