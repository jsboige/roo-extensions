# .claude/rules/ Footprint Snapshot

**Generated:** 2026-11-04 (lot 1 campagne d'amincissement #2368)
**Script:** `scripts/audit-rules-footprint.ps1` (octets bruts, lecture seule)
**Plafonds gardés par test :** `scripts/testing/unit/rules-footprint-budget.Tests.ps1` (octets LF-normalisés — c'est le test, pas ce snapshot, qui fait foi en CI)
**Issues:** #1606 (baseline), #2368 (campagne d'amincissement, décision ai-01 04/11 12:50Z — porteur po-2025, vérificateur po-2028)

## Totals (2026-11-04)

| Metric | Value |
|---|---|
| Files | 22 |
| Bytes (LF-normalisés) | 61879 (~15 470 tokens estimés) |
| Source harnais global `.claude/configs/user-global-claude.md` | 25915 (~6 480 tokens estimés) — **27174 avant le lot 1** |

Le harnais global est déployé vers `~/.claude/CLAUDE.md` (`Deploy-GlobalConfig.ps1 -Target claude-md`) : ces octets sont payés à **chaque** conversation de chaque machine. Le détail déporté vit dans `docs/harness/` (on-demand, non auto-chargé).

## Per-file breakdown (2026-11-04, largest first)

| File | Bytes | 
|------|------:|
| agent-claim-discipline.md | 6860 |
| worktree-lifecycle.md | 4270 |
| pr-mandatory.md | 4159 |
| submod-pointer-safety.md | 3726 |
| intercom-protocol.md | 3697 |
| ci-guardrails.md | 3560 |
| no-deletion-without-proof.md | 3541 |
| tool-availability.md | 3527 |
| context-window.md | 3342 |
| sddd-grounding.md | 2922 |
| mcp-diagnosis.md | 2885 |
| issue-closure.md | 2844 |
| plans-progress-usage.md | 2739 |
| wake-claude-routing.md | 2435 |
| harnais-tightening.md | 1836 |
| degraded-escalation.md | 1754 |
| security.md | 1705 |
| skepticism-protocol.md | 1540 |
| shell-fallback.md | 1494 |
| validation.md | 1320 |
| issue-creation.md | 935 |
| friction-protocol.md | 788 |

## Notes

- Token estimate assumes ~4 chars/token (rough English/French mix). Real counts vary by tokenizer (GPT ≠ Claude ≠ GLM).
- Rules are auto-loaded on every Claude Code conversation start — every KB here is paid as context on every agent spawn.
- Octets LF-normalisés (CRLF→LF) : la mesure ne dépend pas de la configuration line-ending du checkout.

## Campagne #2368 — journal des lots

| Lot | Date | Surface | Avant | Après | PR |
|---|---|---|---:|---:|---|
| 1 | 2026-11-04 | `user-global-claude.md` §Délégation tier mini | 27174 | 25915 | (cette PR) |

Méthode (#445) : déport du détail vers `docs/harness/` + ligne de renvoi, un lot = une PR, mesure avant/après dans le corps, plafond abaissé dans le test en même temps.

## Historique

### Cleanup 2026-05-19 — Ventilation vers docs/harness/

Réduction nette : **23 fichiers / ~57 KB → 18 fichiers / 36.17 KB (-36 %)**.

5 fichiers déplacés (descriptif/référence, pas règles de comportement) :
- `meta-analyst.md` → `docs/harness/coordinator-specific/meta-analyst-rule.md` (loaded par `start-meta-audit.ps1`, contenu déjà inliné dans le prompt)
- `agents-architecture.md` → `docs/harness/reference/agents-inventory.md` (inventaire pur)
- `bots-directory.md` → `docs/harness/reference/bots-directory.md` (annuaire Hermes/NanoClaw)
- `scheduler-model-defaults.md` → `docs/harness/reference/scheduler-model-defaults.md` (doc opérationnelle script)
- `conversation-browser-guide.md` → mergé dans `docs/harness/reference/conversation-browser-detailed.md` (était déjà un pointer "version slim")

1 fichier splitté (mixed: 2 règles + 1 procédure technique) :
- `mcp-diagnosis.md` : règles absolues conservées (4.3 KB → 2.82 KB), procédure healthcheck/chain déportée vers `docs/harness/reference/mcp-diagnosis-procedure.md`

Cross-refs mises à jour : `CLAUDE.md` (Agents detail + Rules Auto-chargees + Ressources), `README.md` (Architecture Agents), `delegation.md`, `scripts/scheduling/start-meta-audit.ps1`, `docs/harness/coordinator-specific/meta-analyst-detailed.md`.
