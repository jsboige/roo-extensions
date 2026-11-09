# Archive — consolidation #2877, vagues 2-3 (2026-11-09)

Quatre documents archivés par la vague 2 de l'issue **#2877** (« doublons de documentation »),
sur l'arbitrage `c.6728993741` (ai-01) et le dispatch `ai01-queue-20261109a-web1` — puis quatre
autres par la vague 3 (dispatch file 09c item 1, même méthode : renames purs + pointeurs).

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

---

# Vague 3 (2026-11-09) — 4 documents `docs/roosync/` archivés

Renames purs (`git mv`, R100), pointeurs vivants mis à jour (INDEX, issue template
`harness-change.yml`, `WORKSPACE_KNOWLEDGE.md`, `sddd-conversational-grounding.md`,
`sddd-grounding-detailed.md`). Empreintes relevées après déplacement — identiques à l'original
par construction du rename git.

| Document archivé | Octets | Lignes | SHA-256 | Motif |
|---|---:|---:|---|---|
| `INTERCOM_PROTOCOL.md` | 9 345 | 382 | `eeefac8062f153e6dcffa9f28e722191ef2bf5c4bcce9a9ad76a41ae083b354e` | Le canal fichier INTERCOM est **déprécié** par la règle `.claude/rules/intercom-protocol.md` v3.6.0 (dernier recours si MCP dashboard échoue) ; la règle porte les essentiels survivants, le dashboard workspace est le canal principal |
| `PROTOCOLE_SDDD.md` | 26 775 | 739 | `2eff8257dd84d63c2e5e1ea3d83c0dcd2de0986450b25d3ec42e39cc9e808d4f` | v2.7.0 (janvier) superseded par la règle `.claude/rules/sddd-grounding.md` v5.1.0 + `docs/harness/reference/sddd-grounding-detailed.md` + `sddd-conversational-grounding.md` ; volet issues → `.claude/rules/issue-creation.md` |
| `GESTION_MULTI_AGENT.md` | 18 058 | 613 | `0cbb759d5a37cdb6c884900b9c7c3a839bfa14588d7fafb03553f03d50cdd1e1` | Topologie flotte **obsolète** (janvier : « Coordinateur Technique myia-po-2024 », « Testeur myia-web-01 ») — remplacée par `CLAUDE.md` § Vue d'ensemble (ai-01 coordonnateur, exécuteurs z.ai) |
| `QUALITY-PIPELINE.md` | 10 524 | 398 | `ddb791cd00fbc1aa576596a7bc09f4d069ac52a2f67d62baca7ac8eda362480b` | Point-in-time de l'implémentation #544 (**COMPLETE**, 2026-03-01) ; les scripts (`scripts/review/auto-review.ps1`, `start-auto-review.ps1`) existent toujours et l'issue #544 porte l'historique |

## Où le contenu vit maintenant (vague 3)

| Sujet | Autorité | Élaboration |
|---|---|---|
| Communication inter-agents | `.claude/rules/intercom-protocol.md` (dashboard = canal principal) | `docs/harness/reference/intercom-v3-mentions.md` |
| SDDD | `.claude/rules/sddd-grounding.md` | `sddd-grounding-detailed.md` + `sddd-conversational-grounding.md` |
| Topologie flotte / rôles | `CLAUDE.md` § Vue d'ensemble | `docs/harness/GUIDE-TECHNIQUE` (roosync) |
| Auto-review pipeline | scripts `scripts/review/*.ps1` | issue #544 |

## Ce qui n'a pas été conservé (vague 3)

Le détail par section vit dans le body de la PR vague 3 : gabarits de messages du canal fichier
INTERCOM (mécanisme déprécié — la règle garde l'usage fallback minimal), sections gh CLI de
janvier (superseded par les règles actuelles), tables de répartition de rôles obsolètes,
détails d'implémentation #544 (lignes de code citées = l'archive même).

## Ce qui n'a pas été conservé

Chaque suppression est justifiée dans le tableau « section source → cible » du body de la PR
correspondante : pointeurs morts (`CLAUDE.md` § « GPU Fleet », `.claude/rules/myia-web1-constraints.md`),
lignes contredites par une règle plus récente (push direct sur `main` pour les tâches `-simple`),
mécanismes jamais outillés (hook pre-push non installé, workflow de labellisation absent).
