# .claude/rules/ Footprint Snapshot

**Generated:** 2026-05-19T00:00Z (post-ventilation cleanup)
**Script:** `scripts/audit-rules-footprint.ps1`
**Issues:** #1606 (baseline), 2026-05-19 ventilation (this snapshot)

## Totals

| Metric | Value |
|---|---|
| Files | 18 |
| Bytes | 37043 (36.17 KB) |
| Estimated tokens | ~9261 |

## Per-file breakdown (largest first)

| File | KB | Lines |
|------|---:|------:|
| sddd-grounding.md | 4.66 | 85 |
| submod-pointer-safety.md | 4.34 | 53 |
| pr-mandatory.md | 3.32 | 51 |
| mcp-diagnosis.md | 2.82 | 23 |
| issue-creation.md | 2.52 | 60 |
| agent-claim-discipline.md | 2.09 | 27 |
| no-deletion-without-proof.md | 1.83 | 27 |
| context-window.md | 1.77 | 30 |
| issue-closure.md | 1.67 | 35 |
| tool-availability.md | 1.60 | 27 |
| skepticism-protocol.md | 1.50 | 25 |
| security.md | 1.47 | 27 |
| ci-guardrails.md | 1.42 | 37 |
| validation.md | 1.29 | 24 |
| intercom-protocol.md | 1.23 | 28 |
| file-writing.md | 1.11 | 21 |
| shell-fallback.md | 0.78 | 17 |
| friction-protocol.md | 0.76 | 17 |

## Notes

- Token estimate assumes ~4 chars/token (rough English/French mix). Real counts vary by tokenizer (GPT ≠ Claude ≠ GLM).
- Rules are auto-loaded on every Claude Code conversation start — every KB here is paid as context on every agent spawn.

## Cleanup 2026-05-19 — Ventilation vers docs/harness/

Reduction nette : **23 fichiers / ~57 KB → 18 fichiers / 36.17 KB (-36 %)**.

5 fichiers déplacés (descriptif/référence, pas règles de comportement) :
- `meta-analyst.md` → `docs/harness/coordinator-specific/meta-analyst-rule.md` (loaded par `start-meta-audit.ps1`, contenu déjà inliné dans le prompt)
- `agents-architecture.md` → `docs/harness/reference/agents-inventory.md` (inventaire pur)
- `bots-directory.md` → `docs/harness/reference/bots-directory.md` (annuaire Hermes/NanoClaw)
- `scheduler-model-defaults.md` → `docs/harness/reference/scheduler-model-defaults.md` (doc opérationnelle script)
- `conversation-browser-guide.md` → mergé dans `docs/harness/reference/conversation-browser-detailed.md` (était déjà un pointer "version slim")

1 fichier splitté (mixed: 2 règles + 1 procédure technique) :
- `mcp-diagnosis.md` : règles absolues conservées (4.3 KB → 2.82 KB), procédure healthcheck/chain déportée vers `docs/harness/reference/mcp-diagnosis-procedure.md`

Cross-refs mises à jour : `CLAUDE.md` (Agents detail + Rules Auto-chargees + Ressources), `README.md` (Architecture Agents), `delegation.md`, `scripts/scheduling/start-meta-audit.ps1`, `docs/harness/coordinator-specific/meta-analyst-detailed.md`.
