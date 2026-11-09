# Archive — consolidation #2877, vague 2 (2026-11-09)

Quatre documents archivés par la vague 2 de l'issue **#2877** (« doublons de documentation »),
sur l'arbitrage `c.6728993741` (ai-01) et le dispatch `ai01-queue-20261109a-web1`.

**Aucune décision n'est prise ici** : chaque fichier est un `git mv` pur (rename 100 %, zéro octet
modifié). Les empreintes ci-dessous ont été relevées **avant** et **après** le déplacement — elles
sont identiques, ce qui est la preuve de préservation.

| Document archivé | Octets | Lignes | SHA-256 | Motif |
|---|---:|---:|---|---|
| `FEEDBACK_PROCESS.md` | 1 390 | 43 | `0d767baaba3487622f2170e13718c6f1270dfdf381465d86a1297afd4674b3cb` | Doublon **byte-identique** de `feedback-process.md` (même empreinte) |
| `feedback-process.md` | 1 390 | 43 | `0d767baaba3487622f2170e13718c6f1270dfdf381465d86a1297afd4674b3cb` | Idem — les lignes uniques ont été fusionnées dans `docs/harness/reference/friction-protocol-detailed.md` |
| `PR_REVIEW_POLICY.md` | 9 413 | 304 | `3efc79c535103b3bb3d9b4f910ca2b451fb60da83db94b32b79de254d72c348e` | Copie du 2026-03-05 ; la cible `docs/harness/coordinator-specific/pr-review-policy.md` est un **sur-ensemble** (cf. tableau de la PR) |
| `SKEPTICISM_PROTOCOL.md` | 5 840 | 125 | `c8cf5702dde0bd81c9952991bd3b85ffae019814a46381339ae90dd998fd34c6` | Copie du 2026-03-04 ; la règle `.claude/rules/skepticism-protocol.md` reste **seule autorité**, l'élaboration encore vraie vit dans `docs/harness/reference/skepticism-protocol-detailed.md` |

## Où le contenu vit maintenant

| Sujet | Autorité (slim, auto-chargée) | Élaboration |
|---|---|---|
| Feedback / friction | `.claude/rules/friction-protocol.md` | `docs/harness/reference/friction-protocol-detailed.md` (§ « Proposition d'Amelioration ») |
| Review PR multi-agents | — | `docs/harness/coordinator-specific/pr-review-policy.md` |
| Scepticisme | `.claude/rules/skepticism-protocol.md` | `docs/harness/reference/skepticism-protocol-detailed.md` |

## Ce qui n'a pas été conservé

Chaque suppression est justifiée dans le tableau « section source → cible » du body de la PR
correspondante : pointeurs morts (`CLAUDE.md` § « GPU Fleet », `.claude/rules/myia-web1-constraints.md`),
lignes contredites par une règle plus récente (push direct sur `main` pour les tâches `-simple`),
mécanismes jamais outillés (hook pre-push non installé, workflow de labellisation absent).
