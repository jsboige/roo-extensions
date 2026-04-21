# Audit des règles auto-chargées

**Date:** 2026-04-21 08:07
**Audit par:** audit-rules-footprint.ps1

## Metrics actuelles

| Métrique | Valeur |
|---|---|
| Fichiers auto-chargés | 16 |
| Taille totale | 45640 bytes (~44.6 KB) |
| Lignes totales | 1229 |
| Tokens estimés (boot) | ~11410 |

## Files distribution

| Taille | Nombre | |
|---|---|---|
| >80KB | 0 | |
| 30-80KB | 0 | |
| <30KB | 16 | 44.6KB total |

## Top files par taille

- meta-analyst.md: 10.73KB (237 lignes)
- pr-mandatory.md: 5.83KB (117 lignes)
- intercom-protocol.md: 4.28KB (133 lignes)
- issue-closure.md: 3.3KB (70 lignes)
- sddd-grounding.md: 3.17KB (95 lignes)

## Phase 2 - Proposed consolidations

1. **skepticism-protocol.md** (1.5KB, 42L) + **agent-claim-discipline.md** (PR #1605) → **verification-discipline.md** (~80L)
2. **no-deletion-without-proof.md** (1.3KB, 38L) + **validation.md** (0.9KB, 35L) → **change-safety.md** (~50L)
3. **intercom-protocol.md** (4.28KB, 133L) + **friction-protocol.md** (1.64KB, 68L) → **dashboard-protocol.md** (~180L)

**Gains estimés:** -143 lignes (~6.5KB)
**Nouveau total:** ~38KB

---

## Notes
- agent-claim-discipline.md n'a pas été trouvé dans ce commit (doit provenir de PR #1605)
- La consolidation prévue réduira significativement la footprint des règles