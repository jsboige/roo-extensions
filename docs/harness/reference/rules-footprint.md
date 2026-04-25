# .claude/rules/ Footprint Snapshot

**Generated:** 2026-04-24T22:26Z
**Script:** `scripts/audit-rules-footprint.ps1`
**Issue:** #1606

## Totals

| Metric | Value |
|---|---|
| Files | 17 |
| Bytes | 51109 (49.91 KB) |
| Lines | 1330 |
| Estimated tokens | ~12778 |

## Per-file breakdown (largest first)

| File | KB | Lines | Est. tokens |
|------|---:|------:|------------:|
| meta-analyst.md | 10.8 | 220 | 2761 |
| pr-mandatory.md | 5.83 | 117 | 1485 |
| agent-claim-discipline.md | 4.78 | 111 | 1196 |
| intercom-protocol.md | 4.28 | 133 | 1090 |
| issue-closure.md | 3.3 | 70 | 841 |
| sddd-grounding.md | 3.17 | 95 | 809 |
| tool-availability.md | 3.15 | 95 | 803 |
| conversation-browser-guide.md | 2.55 | 80 | 651 |
| friction-protocol.md | 1.64 | 68 | 413 |
| agents-architecture.md | 1.59 | 57 | 408 |
| skepticism-protocol.md | 1.5 | 42 | 385 |
| security.md | 1.47 | 42 | 375 |
| ci-guardrails.md | 1.42 | 56 | 363 |
| no-deletion-without-proof.md | 1.3 | 38 | 331 |
| file-writing.md | 1.11 | 33 | 282 |
| context-window.md | 1.1 | 38 | 281 |
| validation.md | 0.9 | 35 | 228 |

## Notes

- Token estimate assumes ~4 chars/token (rough English/French mix). Real counts vary by tokenizer (GPT ≠ Claude ≠ GLM).
- This snapshot is a baseline for #1606 consolidation work. Re-run after every rule addition/merge to keep the footprint log current.
- Rules are auto-loaded on every Claude Code conversation start — every KB here is paid as context on every agent spawn.