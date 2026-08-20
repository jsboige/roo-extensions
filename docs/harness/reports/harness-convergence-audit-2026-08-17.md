# Audit de convergence des harnais roo-extensions ↔ CoursIA — passe 2 (vérification locale)

**Date :** 2026-08-17
**Auteur :** myia-po-2026 (claude-interactive, executor machine CoursIA)
**Issue :** [#3111](https://github.com/jsboige/roo-extensions/issues/3111) — Epic, phase 1 (audit croisé)
**Passe 1 :** audit web1 du 2026-08-15 (commentaire issue #3111) — matrice 7 axes, méthode git-only côté CoursIA

---

## Objet de cette passe

La passe 1 (web1) avait une limite explicite : **pas d'accès au filesystem local CoursIA** — les faits non
servis par git restaient qualifiés `(*)`, CoursIA-2 n'était pas audité, et la localisation du scheduler
CoursIA restait ouverte (« à localiser : ai-01 ? vscdb par machine ? »).

po-2026 est une machine de **production CoursIA** (2 lanes : CoursIA + CoursIA-2). Cette passe vérifie
les faits `(*)` sur checkout local, audite CoursIA-2, résout la question du scheduler, et quantifie la
flotte worktrees. Qualification : **VERIFIE** = lu/mesuré sur cette machine ce jour.

---

## 1. Vérifications de la passe 1 — statuts mis à jour

| Fait passe 1 | Statut passe 1 | Statut passe 2 (po-2026, VERIFIE) |
|---|---|---|
| `.claude/plans/` CoursIA (2 plans) | VERIFIE (git) | **Confirmé local** — `genai-comprehensive-validation.md`, `session-etudiants-avances-genai.md` |
| `.claude/progress/` CoursIA (6 fichiers JSON/MD) | VERIFIE (git) | **Confirmé local** — 6 fichiers identiques à l'arbre git |
| `agent-memory/` CoursIA (4 agents cités) | VERIFIE (git) | **Corrigé : 10 répertoires locaux** — infer-notebook-enricher, notebook-designer, notebook-enricher, notebook-iterative-builder, notebook-validator, prover-forensic, qc-research-notebook, qc-strategy-analyzer, qc-strategy-improver, slide-analyzer. La mémoire par agent est partiellement **non-versionnée** (locale au rôle) |
| Deep-queue + fallback perenne (R4 coordinator-discipline) | `(*)` RAPPORTE | **VERIFIE** — `coordinator-discipline.md:34-43` (HARD) + `proactive-coordination.md:6-14` : « le tarissement est structurellement interdit (HARD, mandat user 2026-07-06) : ce n'est pas juste que les lanes se tarissent, c'est le principe même qu'elles PUISSENT se tarir » |
| Claim cross-lane sur issue (`scripts/check_lane_claim.py`) | VERIFIE (git) | **Confirmé sur origin/main** (⚠️ `git cat-file -e` a rendu un faux négatif sur `.claude/rules/lane-claim-protocol.md` ; `git ls-tree origin/main` est autoritaire — les 27 règles sont là) |
| Workflows CI CoursIA = 91 | VERIFIE (git) | **93 au 17/08** (dérive +2 depuis la passe 1) |
| Règles CoursIA = 27 | VERIFIE (git) | **Confirmé sur origin/main** (le checkout local main n'en voit que 23 — voir §5, staleness) |

**Aucune invalidation** : les lectures de la passe 1 tiennent. Deux précisions numériques (agent-memory
10 vs 4 ; workflows 93 vs 91) et une leçon d'instrument (faux négatif `cat-file -e` → préférer `ls-tree`).

---

## 2. Question ouverte résolue — où vit le scheduling CoursIA

**Réponse : sur la machine worker elle-même, en crons Claude Code session-scoped, portés par une
session VS Code persistante.** Ni ai-01, ni vscdb, ni schtasks.

Preuves (po-2026, VERIFIE) :
- `C:\dev\CoursIA\.claude\scheduled_tasks.lock` — `{"sessionId":"0fb5c547-…","pid":31336,…}`
- Le pid 31336 est un `claude.exe` **vivant** (démarré 17/08 11:41) lancé par l'extension VS Code
  avec `--resume=0fb5c547-…` : la session qui porte les crons est **résumée**, pas recréée.
- `schtasks` local : **aucune tâche CoursIA**. Les schtasks agents (`Claude-Worker` PT6H,
  `Claude-Executor-Cron` PT4H, watchdogs) ciblent toutes `C:\dev\roo-extensions`.
- Cadence po-2026 CoursIA : `CronCreate("13,43 * * * *", "/continue")` (job `822fea5f`), cf. memory
  `cadence-fleet-30min-mandate` — **30 min fleet-wide CoursIA** (mandat user 2026-08-11, supersede
  le 2h économie-tokens).

### Conséquence — la divergence de durabilité est documentée des deux côtés

Le mécanisme CoursIA (**cron session-only, auto-expire 7 j**) a exactement la panne que roo-extensions
vient d'éliminer par la migration schtasks (#3141 → PRs #3152/#3153, déployée sur po-2026 ce 17/08) :

> Memory CoursIA `cron-session-only-autoexpire-silent-lane-death` (incident 2026-07-28) : po-2026
> muet **~60 h sur deux lanes** (CoursIA + CoursIA-2) — cron expiré, aucune panne machine. Le
> coordinateur avait escaladé au user comme « machine possiblement down ». Remède actuel côté
> CoursIA : comportemental uniquement (« `CronList` en premier à chaque réveil »).

Côté CoursIA, aucun organe équivalent à `start-claude-executor.ps1` + schtask n'existe. **C'est le
candidat de convergence n° 1 dans le sens CoursIA ← roo-extensions**, étayé par un incident daté.

### Cadences comparées (les deux user-mandated)

| Flotte | Cadence | Porteur | Durabilité |
|---|---|---|---|
| roo-extensions | 4 h (mandats user 2026-08-15/17) | schtask `Claude-Executor-Cron` (PT4H) depuis #3152 | Survit aux restarts de session |
| CoursIA | 30 min (mandat 2026-08-11) | CronCreate session-only (`/continue`) | Meurt avec la session / expire à 7 j |

L'écart 8× n'est **pas** une incohérence à corriger (deux mandats user distincts, deux contraintes
différentes : économie de tokens méta vs débit de production). Ce qui mérite convergence est la
**couche porteur**, pas la cadence.

---

## 3. CoursIA-2 — audit (absent de la passe 1)

- **Même dépôt** (`github.com/jsboige/CoursIA.git`), second clone à `C:\dev\CoursIA-2`, branche main.
- **Rôle : second hôte de lanes.** 38 worktrees rattachés à `CoursIA-2/.git/worktrees/` vs 73 à
  CoursIA main — la machine po-2026 porte **deux lanes du même repo**, chacune avec sa flotte.
- `.claude/` **miroir** de CoursIA (mêmes plans, mêmes progress, 21 agents) — cohérent avec le gate
  CI `twin-parity` cité en passe 1. La parité n'est pas une impression : les fichiers sont identiques
  au byte près sur les artefacts audités.
- Fraîcheur : CoursIA-2 est **13 commits derrière** origin/main (tiré récemment) ; CoursIA main est
  **3 934 commits derrière** (voir §5).

**Lecture** : la « machine à deux lanes » est un pattern CoursIA absent du vocabulaire roo-extensions,
où une machine = un workspace roo-extensions (+ rôles annexes). À arbitrer si les workspaces futurs
(2026-ECE, Embeddings) montent en volume.

---

## 4. Flotte worktrees — quantification réelle (axe 7)

Mesures po-2026 (VERIFIE) :

| Mesure | Valeur |
|---|---|
| Répertoires `C:\dev\CoursIA-*` | **136** |
| Worktrees liés au clone CoursIA main | **73** (+ le checkout main) |
| Worktrees liés au clone CoursIA-2 | **38** (+ le checkout main) |
| Répertoires **sans** fichier `.git` (résidus/corps de lanes) | **24** |
| Clones autonomes | 1 |

La passe 1 citait « 868 worktrees flotte » (ai-01 c.224) — po-2026 à lui seul en porte ~111 liés,
soit ~13 % de la flotte sur une machine. Les 24 répertoires sans `.git` sont la **matière première
du scan `orphan-branch-scan`/`stale-tree-drift-scan`** côté CoursIA : la détection anti-orphelin
n'est pas théorique, elle a un objet réel de cette taille par machine de production.

roo-extensions, en comparaison, opère à 0-3 worktrees actifs par machine avec cleanup manuel
post-merge (règle pr-mandatory). Les mécanismes divergent par **nécessité de volume**, pas par
maturité — mais le jour où un workspace roo-extensions monte en lanes parallèles, les guards CI
CoursIA deviennent directement transposables.

---

## 5. Découverte incidentelle — staleness du checkout main

Le checkout `C:\dev\CoursIA` (main) est **3 934 commits derrière** origin/main, alors que CoursIA-2
(main) n'est que 13 derrière. Le checkout main sert d'**hôte de worktrees** (les lanes sont coupées
depuis les refs origin, pas depuis le pointer local main) — personne ne tire le pointer local.

Conséquence pour tout audit futur : **vérifier la fraîcheur du checkout avant de conclure d'un
« absent »** (cf. §1 : les règles `lane-claim-protocol.md`, `variation-protocol.md` n'existaient pas
dans le checkout local stalé — les compter depuis l'arbre local aurait donné 23 règles au lieu de 27).
Même famille que la leçon ai-01 du 17/08 (« vérifier que l'instrument a mordu ») : ici l'instrument
était un arbre périmé.

---

## 6. Mémoire par machine — profondeur mesurée

`~/.claude/projects/c--dev-CoursIA/memory/` sur po-2026 : **298 fichiers**. La comparaison
*like-for-like* est **71 fichiers** dans le `memory/` équivalent de web1 côté roo-extensions, soit un
rapport de **4,2×** — et non 7× : ce chiffre-là venait d'opposer un répertoire entier (298) à son
seul sous-ensemble `feedback_*.md` (~40) de l'autre côté. Les deux répertoires sont bien du **même
scope** (auto-memory par machine). Correction apportée par web1 en cross-review.

Deux lectures non exclusives :
1. La production à 30 min de cadence **génère** plus de leçons (plus de cycles, plus d'incidents).
2. La règle CoursIA `harness-hygiene` (3 tiers, anti-gonflement) ne s'applique pas au répertoire
   `memory/` local — même prolifération que côté roo-extensions, à échelle 4,2×.

**Candidat de convergence renforcé** : la passe 1 proposait « adopter `harness-hygiene` 3-tiers »
dans un sens ; la mesure locale montre que **les deux workspaces partagent le même défaut de
non-bornage de la mémoire par machine** — le patron à abstraire est commun, pas unilatéral.

---

## 7. Synthèse — candidats de convergence mis à jour

Reprise de la liste passe 1 (§8), amendée par les preuves locales :

| # | Sens | Candidat | Changement après passe 2 |
|---|---|---|---|
| 1 | roo-ext ← CoursIA | `.claude/plans/` + `.claude/progress/` (tracking machine-readable des chantiers longs) | Inchangé — confirmé local |
| 2 | roo-ext ← CoursIA | Deep-queue / fallback perenne / R4 anti-tarissement | **Renforcé** — `(*)` → VERIFIE avec le verbatim du mandat user |
| 3 | roo-ext ← CoursIA | Claim cross-lane sur issue | Inchangé — confirmé sur origin/main |
| 4 | roo-ext ← CoursIA | Pre-commit + gates CI sur `mcps/internal` | Inchangé |
| 5 | CoursIA ← roo-ext | Format « En attente d'arbitrage user » re-parcouru | Inchangé |
| **6 (nouveau)** | **CoursIA ← roo-ext** | **Couche porteur schtask pour les crons workers** (`setup-scheduler.ps1 -TaskType executor-cron` transposé, cadence 30 min préservée) | **Ajouté** — incident 2026-07-28 (60 h muette ×2 lanes) + migration #3141/#3152/#3153 fraîchement déployée. Le remède actuel CoursIA est comportemental (`CronList` au réveil) ; le remède roo-ext est mécanique |
| 7 | roo-ext ← CoursIA | Méta-doc + `harness-hygiene` 3-tiers | **Requalifié** — le défaut de gonflement mémoire est **bilatéral** (298 fichiers CoursIA local vs 71 roo-ext, like-for-like) : abstraire un patron commun plutôt qu'importer unilatéralement |
| 8 | Abstraction | Workspace blueprint (plans/progress + deep-queue + claim cross-lane + 3-tiers + gates + **porteur schtask**) | **Étendu** — ajouter le porteur schtask au blueprint |

**Divergences légitimes confirmées** (ne pas converger) : cadence 4 h vs 30 min (mandats user
distincts), topologie agents méta vs domaine, volume worktrees (3 vs 111+ par machine),
machine bi-lane (pattern CoursIA-2).

---

## 8. Suivi

- **Phase 2 de l'Epic** (décisions de convergence) : chaque candidat du §7 devient une sous-issue à
  arbitrer — aucun changement de harnais avant validation user (non-but de l'Epic).
- Le présent document rend la matrice **durable** (la passe 1 ne vivait que dans un commentaire
  d'issue). Toute itération future cite passe 1 (web1, 15/08) et passe 2 (po-2026, 17/08).
- Point d'attention pour la passe 3 éventuelle : web1 n'avait pas d'accès local CoursIA ; po-2026
  n'a pas d'accès au workspace CoursIA d'**ai-01** (dashboards archivés seulement) — la vision du
  coordinateur CoursIA reste vue de l'extérieur.

---

## 9. Passe 3 (2026-08-20, po-2023) — vision coordinateur CoursIA + candidat n°5 VERIFIE

**Limite comblée :** le §8 ci-dessus notait que la vision du coordinateur CoursIA (ai-01) restait
extérieure, et le candidat n°5 (« format arbitrages roo-ext → CoursIA ») demeurait RAPPORTE (web1).
Cette passe lit les dashboards CoursIA/CoursIA-2 **live + archives** (`$ROOSYNC_SHARED_PATH/dashboards/`,
GDrive) depuis po-2023, machine exécutante des deux workspaces. Qualification : VERIFIE = lu ce jour
dans les fichiers dashboard cités.

### 9.1 Candidat n°5 — VERIFIE, avec raffinement

Le contraste (observation user n°3) se vérifie, mais il est plus fin que « formel vs informel » :

| Surface | roo-extensions (VERIFIE, archives 15-18/08) | CoursIA (VERIFIE, live 20/08 + archives 13-14/08) |
|---|---|---|
| Décisions USER en attente | Section récurrente par cycle : « **En attente d'arbitrage user** (aucune action prise) : #3121 approbation · sauvegarde Qdrant · catch fail-open · 198 assertions Pester · 868 worktrees · #3097 » (ai-01 c.224, archive 15/08 18:45) ; ré-apparaît 16/08 et 18/08 (« ### En attente d'arbitrage user »). ~31 % des archives roo-extensions (429/1387) portent une mention d'arbitrage en attente | Intégrée au fil des messages : demandes de sign-off en fin de [INFO]-leçon (« une règle ne s'auto-promeut pas, elle passe par un sign-off user », 20/08 04:46Z) ; HOLD user tracés dans les bodies d'issues (« décision 2026-08-12 », #10038) |
| Qui arbitre | Le user — la liste explicite dit « aucune action prise » | **Le coordinateur d'abord** : arbitrages tranchés en DM/commentaires (« arbitrage SALE worktrees TRANCHÉ (réponse DM…) », archives 14/08) ; [ASK coordinator] des workers tranchés au cycle suivant |
| Traçabilité des oublis | La liste re-parcourue chaque cycle → un item ne peut pas disparaître silencieusement | Dette personnelle en texte libre : « Ce que je prends moi : les 4 arbitrages restés en l'air (#7257, #7266, #7298, #6711) — un [ASK USER] jamais arrivé pré-merge […] c'est ma dette, pas celle des lanes » (ai-01, archive `workspace-CoursIA-2026-08-15T16-48-41.md`, messages 13-14/08). Un [ASK USER] « jamais arrivé » est précisément la panne que le format roo-ext prévient |

**Raffinement du candidat n°5** : ce n'est pas un formalisme qui manque à CoursIA, c'est un
**registre re-parcouru** des décisions user en attente. CoursIA escalade moins au user (le
coordinateur arbitre plus lui-même — plus rapide en production), mais ses demandes user en attente
ne survivent pas au cycle. La convergence pertinente = le format liste re-parcourue, pas la
fréquence d'escalade.

### 9.2 Vision coordinateur CoursIA — premiers faits internes

- **Déroulé de tour** : mandat user cité **verbatim** en tête (« pour les blocages, fais en sorte de
  mobiliser les agents pour qu'ils réparent les PRs… », 20/08 04:29Z), puis dispatch tabulaire par
  lane (PR / créée / rouge), puis ordres nominatifs. Pas de bilan-type — chaque message est un objet
  différent ([DISPATCH], [INFO]-leçon, [DONE]).
- **Volume** : 24 merges/jour par ai-01 (condensation CoursIA 20/08) ; les queues merge sont portées
  par les workers eux-mêmes dans leurs [DONE] (« Queue review/merge ai-01 : #11839, #11854… »).
- **Nouveau régime user (nuit du 19-20/08)** : « le tirage devient le premier geste de chaque cycle,
  pour fermer des issues et des Epics qui méritent d'être conduites à leur terme et sont souvent
  délaissées devant les sujets du moment » — le user impose mécaniquement ce que le candidat n°2
  (anti-tarissement) encode : les chantiers délaissés doivent remonter d'eux-mêmes. Donnée pour
  l'arbitrage : le problème visé par cet Epic est toujours actif côté user.
- **Réflexe EPIC-stale** (ai-01, 20/08 04:46Z) : « plus une EPIC est ancienne, plus son body a de
  chances d'être faux » — réparation par bloc « > Etat mesuré au <date> » préfixé au body, historique
  conservé. Applicable à #3111 lui-même au cadrage phase 2.

### 9.3 État de l'Epic après passe 3

- **Phase 1 : complète.** 4 passes (web1 15/08, po-2023 16/08, po-2026 17/08, po-2023 20/08) ;
  dernière qualification RAPPORTE résolue (n°5). Aucune invalidation entre passes.
- **Phase 2 : 8 candidats prêts à arbitrer** (synthèse po-2025 18/08, reprise dans le commentaire
  #3111 du 20/08) — user-gated, aucun changement de harnais sur les 4 passes (non-but respecté).
- **Numérotation** : le §7 ci-dessus (rédigé 17/08) et la synthèse po-2025 (18/08) divergent sur les
  n°7/8 — le §7 compte « méta-doc + 3-tiers » comme n°7 et n'intègre pas « résilience canal »
  (ajouté par la passe 2 en commentaire, 16/08) ; la synthèse po-2025 replie le 3-tiers dans le
  blueprint (n°7) et met « résilience canal » en n°8. **La table du commentaire #3111 du 20/08 fait
  foi pour la phase 2.**
