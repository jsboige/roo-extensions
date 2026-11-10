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

---

# Vague 4 (2026-11-09) — 4 documents `docs/roosync/` archivés

Renames purs (`git mv`, R100), même méthode que la vague 3. Seul pointeur vivant corrigé :
`docs/INDEX.md` (4 lignes retirées, en-tête recompté 18→14, 2 fichiers non listés ajoutés).
Empreintes relevées après déplacement — identiques à l'original par construction du rename git.

| Document archivé | Octets | Lignes | SHA-256 | Motif |
|---|---:|---:|---|---|
| `worktree-best-practices.md` | 14 635 | 437 | `ac8d62a45d8f4c67474c9ec85642fabd1c6ce1bcf731d7d73555ea39a97ca0e0` | Synthèse #627 (2026-03-10) : décrivait des worktrees **dans** le projet et une adoption « selon complexité » — superseded par `.claude/rules/worktree-lifecycle.md` (worktree HORS arbre parent #2123, cycle de vie, jonctions) + `pr-mandatory.md` (PR obligatoire, décision tranchée) |
| `BASELINE_GHOST_MCPS.md` | 6 349 | 220 | `a73479030ff23d0508abc793c539e64f41514324200957c219ce3e887f74928a` | Investigation #460 (2026-02-12) close : baseline régénérée depuis ; le canon des MCP retirés vit dans `.claude/rules/tool-availability.md` § Retires + la garde `RETIRED_MCP_NAMES` du RSM. NB : `docs/cleanup/CONSOLIDATION-MCP-DEPRECATED-PROOF.md` l.87 la citait comme migration-record volontairement conservée — le rename R100 **préserve** ce record (byte-identique), il ne le supprime pas |
| `DASHBOARD_AUTO_REFRESH.md` | 8 964 | 286 | `3842f70c9b5180109afb493997ecc0de51939f7dc12811ad23f2e1cf659aa060` | Analyse d'options #460 (2026-02-12) pour un refresh horaire d'un dashboard alors manuel — superseded par l'architecture v3 réelle (écritures MCP directes + auto-condensation 92 % #4527, passe détachée) |
| `HEARTBEAT_REGISTRATION_PROCEDURE.md` | 5 476 | 201 | `b1381ffc5803e69238a0338afef95b8b69ce0c6bea837bf16fadc9cb4f2c3f38` | Procédure #460 (2026-02-12) pour un enregistrement heartbeat **manuel** via l'outil `roosync_heartbeat_service` — l'outil n'existe plus, l'enregistrement est automatique (`roosync_inventory` type `heartbeat`, RSM v4.2+) |

## Où le contenu vit maintenant (vague 4)

| Sujet | Autorité | Élaboration |
|---|---|---|
| Worktrees / cycle de vie | `.claude/rules/worktree-lifecycle.md` | `docs/harness/reference/worktree-lifecycle-detailed.md` |
| Workflow PR (worktree → PR → merge) | `.claude/rules/pr-mandatory.md` | `docs/harness/reference/pr-workflow-guards.md` |
| MCP retirés / baseline | `.claude/rules/tool-availability.md` § Retires | garde `RETIRED_MCP_NAMES` (RSM) + `docs/cleanup/CONSOLIDATION-MCP-DEPRECATED-PROOF.md` |
| Dashboard v3 (écriture/condensation) | `.claude/rules/intercom-protocol.md` | `docs/harness/reference/intercom-append-timeout.md` + `GUIDE-TECHNIQUE-v2.3.md` |
| Heartbeat flotte | `roosync_inventory(type: "heartbeat")` | `docs/harness/reference/roosync-tools-guide.md` |

---

# Vague 5 (2026-11-10) — 4 documents archivés (2 `docs/roosync/` + 2 `docs/roosync/guides/`)

Dispatch `file-10a-web1-ai01` item 2 (« les 4 documents remplacés suivants », même forme
que la vague 4 : renames purs R100, correspondance section→cible et SHA-256 dans le body).
Identification mesurée sur `main` (`884c4acd`) : les candidats sont les documents dont le
**domaine est absorbé ailleurs** et dont **aucun point d'entrée vivant** (`CLAUDE.md`,
`.claude/commands/`, `.claude/skills/`, `.claude/agents/`) ne dépend — seuls INDEX et des
guides d'époque (janvier) les citent encore.

Empreintes relevées **avant** déplacement, identiques après par construction du rename git.

| Document archivé | Octets | Lignes | SHA-256 | Motif |
|---|---:|---:|---|---|
| `ERROR_CODES_REFERENCE.md` | 12 104 | 395 | `921ca20e8f4bd22917a98a6919fc5dba5742e104f35c3387e46604a80bd2223e` | Référence v1.0.0 du **2026-01-15, jamais mise à jour** — codes d'erreur de la stack Roo/win-cli d'époque ; le diagnostic courant vit dans `docs/harness/reference/mcp-diagnosis-procedure.md` + `.claude/rules/mcp-diagnosis.md` ; seuls INDEX + guides de janvier la citaient |
| `AGENTS_ARCHITECTURE.md` | 3 166 | 87 | `6d7f55a0a9f78d8cf5a43bb66f1ad162b3aebf3941ceb31a1f36a1990019b375` | Inventaire figé au **2026-03-04** (audit #556, CLOSED) — liste des subagents/skills/commands de l'époque (dont des agents n'existant plus : `intercom-compactor`, `sddd-router`) ; le canon vivant est `CLAUDE.md` § Agents, Skills & Commands avec recompte firsthand (#3321) ; 0 entrypoint vivant |
| `guides/README.md` | 1 284 | 31 | `322410ccdd09a2f922f9a0d2ab06a2dc0f474072ddfea05e8f7d16cc71f21a82` | Index des guides opérationnels RooSync de janvier — **aucun document vivant ne pointe dans `guides/`** (mesuré : README/QUICKSTART/GUIDE-TECHNIQUE/CLAUDE.md/docs/knowledge, 0 hit) ; la table y renvoyait vers les docs archivés vagues 3-5 |
| `guides/CHECKLISTS.md` | 8 436 | 301 | `9029807e22038774f9931e51293014238b6beda1df66e3c724b780ac1471fbd9` | Checklists opérationnelles **2026-01-15**, stack Roo scheduler d'époque ; les checklists vivantes sont `.claude/rules/validation.md` (comptage avant/après) et les gardes CI (`ci-guardrails.md`) ; 0 consommateur vivant |

Pointeurs corrigés : `docs/INDEX.md` (recomptes **14→10** et guides **5→3**, 4 lignes retirées),
`guides/GLOSSAIRE.md` (2 liens), `guides/ONBOARDING_AGENT.md` (1), `guides/TROUBLESHOOTING.md` (1),
`docs/suivi/RooSync/INDEX.md` (1) — tous redirigés vers l'archive avec mention « archivé ».

## Où le contenu vit maintenant (vague 5)

| Sujet | Autorité | Élaboration |
|---|---|---|
| Diagnostic outils/MCP | `.claude/rules/mcp-diagnosis.md` + `tool-availability.md` | `docs/harness/reference/mcp-diagnosis-procedure.md` |
| Inventaire agents/skills/commands | `CLAUDE.md` § Agents, Skills & Commands | `.claude/agents/`, `.claude/skills/`, `.claude/commands/` (recompte firsthand #3321) |
| Checklists opérationnelles | `.claude/rules/validation.md` | `.claude/rules/ci-guardrails.md` |
| Onboarding nouvel agent | `CLAUDE.md` + `.claude/rules/` (auto-chargées) | `docs/harness/reference/INDEX.md` |

---

# Vague 6 (2026-11-10) — 3 derniers guides `docs/roosync/guides/` archivés (le répertoire se vide)

Dispatch `file-10c-web1-ai01` item 2 (« la vague 6 de consolidation de la doc, prise dans
la file du body »). Les 3 candidats sont exactement ceux que le body de la PR vague 5
(#4629, section « Non touché ») nommait « leur sort propre (janvier, 0 entrypoint vivant)
est un grain ultérieur éventuel ». Même méthode : renames purs R100 + pointeurs + SHA-256.
Aucun point d'entrée vivant (`CLAUDE.md`, `.claude/commands/`, `.claude/skills/`,
`.claude/agents/`) ne cite ces fichiers — seuls `docs/INDEX.md`, `SUBMODULE_WORKFLOW.md`
(Références) et `docs/suivi/RooSync/INDEX.md`.

Empreintes relevées **avant** déplacement, identiques après par construction du rename git.

| Document archivé | Octets | Lignes | SHA-256 | Motif |
|---|---:|---:|---|---|
| `guides/GLOSSAIRE.md` | 7 845 | 274 | `6c38ae9fbd7b4d48cc0b072df062813bf75b0191d3b5045a5c4ec6607ebf83be` | Glossaire **v1.1.0 du 2026-01-24, jamais mis à jour** — termes RooSync de janvier ; la référence courante est le guide technique `docs/roosync/GUIDE-TECHNIQUE-v2.3.md` + les règles auto-chargées |
| `guides/ONBOARDING_AGENT.md` | 7 182 | 328 | `4f79c6f44ccb477e9e82d6a0b32d6edf5c2175acd8049e704f0f600d48fe9ee9` | Onboarding **v1.0.0 du 2026-01-15**, stack Roo scheduler d'époque ; l'onboarding vivant est `CLAUDE.md` § Démarrage (4 étapes) + `.claude/rules/` auto-chargées + `docs/harness/reference/INDEX.md` |
| `guides/TROUBLESHOOTING.md` | 8 894 | 401 | `29ac289ad3fc43c2d111cc0ae2cfa733fca25303581ac87ae16e8ed5a353234c` | Dépannage **v1.0.0 du 2026-01-15**, stack Roo/win-cli d'époque ; le diagnostic courant est `.claude/rules/mcp-diagnosis.md` (2 règles absolues) + `docs/harness/reference/mcp-diagnosis-procedure.md` |

Pointeurs corrigés : `docs/INDEX.md` (section guides **3→0**, note vague 6),
`docs/roosync/SUBMODULE_WORKFLOW.md` (2 liens Références redirigés),
`docs/suivi/RooSync/INDEX.md` (3 lignes redirigées) — tous vers l'archive avec mention « archivé ».
Faux positifs écartés (noms homonymes ailleurs) : `docs/framework-multi-agent/TEMPLATE_WORKSPACE.md`
(cite `.claude/TROUBLESHOOTING.md` upstream), `docs/guides/*` (TROUBLESHOOTING-GUIDE propre),
`docs/knowledge/WORKSPACE_KNOWLEDGE.md` (cite `docs/archive/mcps-pre-submodule/`).

## Où le contenu vit maintenant (vague 6)

| Sujet | Autorité | Élaboration |
|---|---|---|
| Glossaire RooSync | `docs/roosync/GUIDE-TECHNIQUE-v2.3.md` | règles `.claude/rules/` (vocabulaire courant) |
| Onboarding nouvel agent | `CLAUDE.md` § Démarrage + `.claude/rules/` (auto-chargées) | `docs/harness/reference/INDEX.md` |
| Diagnostic / dépannage | `.claude/rules/mcp-diagnosis.md` | `docs/harness/reference/mcp-diagnosis-procedure.md` |

