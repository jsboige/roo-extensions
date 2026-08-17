# Meta-Analysis Protocol — Continuous Improvement Tier

**Version:** 3.0.0
**Created:** 2026-03-04
**Updated:** 2026-08-16
**Issues:** #551, #981, #982, #855, #3110 (v3 evidence-based rewrite)

---

## Overview

The meta-analysis tier is part of the **3-tier scheduling architecture** (3 types x 2 agents = 6 schedulers):

| Tier | Frequency | Machines | Role |
|------|-----------|----------|------|
| **Meta-Analyst** | 72h | ALL | Observe, analyze, PROPOSE |
| Coordinator | 6-12h | ai-01 only | Triage, dispatch, track |
| Executor | 4h | ALL | Execute assigned tasks |

Each tier has 2 agents: one Roo scheduler + one Claude scheduler (schtask `Claude-MetaAudit`, launcher `scripts/scheduling/start-meta-audit.ps1`).

### What changed in v3 (#3110)

v3 is an **evidence-based rewrite** (audit web1 2026-08-14, étape 1 de #3110 + prototype de minage des archives po-2026 2026-08-15, étape 3), not a refonte sur papier. The three big changes:

1. **The data offer changed.** The old tier mined local trace files. Today the richest, most structured and most current source is the **dashboard archives** (`archive/workspace-*.md`) : **5 489 fichiers flotte, 66 421 messages, 99 % de résumés LLM structurés** (Thèmes principaux / Actions et résultats / Décisions et métriques). The synthesis work is already done by the condensation — only extraction and mise en perspective remain.
2. **The roo-centric checklists remain but are no longer the whole picture.** The verified wins of the last cycles were on the Claude/harness side (#3032 gh identity, #3033 issue close, #3068 launcher). The analysis must rebalance toward **fleet activity + archives + GitHub**.
3. **Anti-fragile-premise guard** : a measure that returns "nothing" from a self-condensing store must first suspect itself (#3097). And the **dead GDrive channel** `docs/meta-analysis/` is removed — verified empty, the archives replaced it de facto.

### Topology (arbitration pending — ai-01/user)

**Current state :** 2 méta-analystes × 6 machines (Roo scheduler + Claude schtask).

**Mesure du terrain (web1 2026-08-14) :**
- Le scheduler Roo est **coupé sur web1** (décision user 08-07) et `active:false` sur ai-01 → le méta-analyste Roo de ces machines analyse des **traces vides**.
- Le méta-analyste Claude de web1 a produit **0 issue GitHub en 6 cycles** ; ses 2 findings ont été jugés « déjà trackés » / « à confirmer ».

**Direction recommandée :** un **analyste flotte-side unique** (ou 1 pour 2-3 machines) qui lit archives + GitHub centralement. Le prototype po-2026 a démontré le minage flotte entier **depuis une seule machine en une seule session** — l'analyste unique flotte-side est techniquement démontré.

**Statut :** décision en attente d'arbitrage. Les procédures de ce document sont **topology-agnostic** — elles s'appliquent que l'analyste soit local ou flotte-side.

---

## Meta-Analyst Role

**Mission:** Observer, analyser, PROPOSER. Ne dispatche pas, ne trie pas, ne modifie rien. Propositions = issues GitHub `needs-approval`.

### What Meta-Analysts Analyze

1. **Fleet activity via dashboard archives** (v3 — source primaire, voir section Archive Mining ci-dessous)
2. **GitHub processing truth** (`gh`) : issues fermées réellement traitées, PRs mergées, review states
3. **Local traces** (Roo scheduler tasks + Claude sessions) : profondeur au cas par cas, via `conversation_browser` (jamais de lecture brute de fichiers traces, #1670)
4. **Task outcomes & quality** : PRs récentes (scope, review, issue liée fermée), travail stale (>7j sans activité, worktrees orphelins, dispatches sans claim/result), fermetures prématurées, travail dupliqué
5. **Operational metrics** : issues créées vs fermées, utilisation machines, violations garde-fous

### What Meta-Analysts Produce (#1081)

- **GitHub issues avec DÉTAIL COMPLET** — chaque finding actionnable = 1 issue (contexte, données, recommandation). Les issues sont le lieu du détail.
- **Résumés dashboard compacts** — max 10 lignes sur `roosync_dashboard(type: "workspace")`. Dashboard = index vers les issues, pas un rapport.
- **Labels** : `needs-approval` (propositions) · `needs-approval` + `harness-change` (modifications harnais, BLOQUÉ jusqu'à approbation user)

### ABSOLUTE PROHIBITION — No Report Files (#1179)

> **Meta-analysts MUST NOT create any files in the repository for their reports or analysis.**

- Interdit : tout fichier rapport dans l'arbre git-tracked (docs/, .claude/, .roo/…)
- Canaux requis (ordre de préférence) : **dashboard workspace** (résumé) → **GitHub issues** (détail)
- **CHANNEL SUPPRIMÉ en v3 : `docs/meta-analysis/` sur GDrive** — vérifié vide (web1 2026-08-14), jamais relu, remplacé de facto par les archives dashboard.

---

## Archive Mining (v3 — source primaire)

Le minage des archives dashboard est la **source primaire** d'analyse d'activité. Démontré par le prototype po-2026 (2026-08-15) : le format est machine-friendly par construction, aucun passage par fichier n'est requis pour la vue d'ensemble.

### Emplacement et format

```
$ROOSYNC_SHARED_PATH/dashboards/archive/workspace-<ws>-<horodatage>.md
```

- **Frontmatter** : `messageCount`, `archivedAt`, `llmGenerated` → stats de volume/densité en un grep
- **Bloc `CONDENSATION-SUMMARY`** : résumé LLM structuré (Thèmes principaux / Actions et résultats / Décisions et métriques), ~3-4 KB par archive
- **Taxonomie labellisée** : les résumés préfixent leurs bullets de catégories en gras (décisions, tests, hygiène, git, qdrant, build…) — un comptage par catégorie = vue thématique en une commande

**Gisement (mesuré 2026-08-15) :** 5 489 archives flotte (66 421 messages, 99 % LLM) · roo-extensions : 1 335 archives, 18 736 messages · ~52 archives/jour flotte (~156 par cycle de 72h).

**Verrou connu :** `roosync_search` (text ET semantic) **ne couvre pas le contenu des archives** (0 résultat vérifié). Le minage passe par **accès fichier direct** (faisable, démontré). Une indexation des résumés (digest `CONDENSATION-SUMMARY` → Qdrant) est proposée comme évolution RSM — à arbitrer séparément, pas un prérequis.

### Scan différentiel standardisé (chaque cycle)

**Étape A — Comptages par thème (delta vs cycle précédent).**

```bash
# Volume de la période (grep frontmatter)
grep -h '^messageCount:' "$ROOSYNC_SHARED_PATH/dashboards/archive/workspace-roo-extensions-2026-08-*.md" | awk -F': ' '{s+=$2} END {print s}'

# Fréquences par thème
grep -hoiE 'drift|submod|429|GDrive|docker|bande passante' "$ROOSYNC_SHARED_PATH/dashboards/archive/workspace-roo-extensions-2026-08-*.md" | sort | uniq -c | sort -rn

# Taxonomie labellisée (bullets en gras)
grep -hoE '^[-*] \*\*[^*]+\*\*' "$ROOSYNC_SHARED_PATH/dashboards/archive/workspace-roo-extensions-2026-08-*.md" | sort | uniq -c | sort -rn

# Thèmes émergents (occurrences ~0 → ≥X vs cycle précédent)
```

**Étape B — Lecture ciblée des deltas.** Lire intégralement les résumés des archives nouvelles depuis le dernier cycle (~156/cycle, 3-4 KB chacune ≈ une session outillée). Lecture full-text des 1 300+ archives : irréaliste, non nécessaire.

**Étape C — Détection de signaux.** Trois familles (démontrées par le prototype) :
- **Tendances de fond** : le pic `drift` de juin (4,7/archive) a précédé de semaines l'incident pointeurs submod — le signal était massif avant la règle.
- **Thèmes émergents détectables à la naissance** : `429` (usage limits) double en août vs mai ; `GDrive` ×2 ; `bande passante` ~0→30 en août. Un minage mensuel aurait signalé chacun à la première dérive.
- **L'effacement du tier lui-même** : les mentions `méta-analyste` dans l'activité enregistrée s'effondrent (103→205→38→37→13). **Le tier doit redevenir visible dans les archives** — métrique d'auto-vérification de la production (baseline honnête de la v3).

### Revues thématiques mensuelles

Un cycle dédié par mois aux **tendances** (§ C1) : tableau top-N thèmes + deltas vs mois précédent + émergents. Les 3 signaux d'août (429, GDrive, bande passante) auraient été détectés ainsi.

---

## Anti-Fragile-Premise Guard (v3 — obligatoire)

**AVANT de publier un constat « X silencieux / inactif / cassé » reposant sur une lecture instantanée d'un store auto-condensé (dashboard, index, snapshot), croiser 3 sources :**

1. **Archives** — `CONDENSATION-SUMMARY` de la période couvrent-elles l'activité ?
2. **GitHub** — `gh pr list --state merged`, `gh issue list`, `git log` sur la fenêtre ?
3. **Mesure directe** — état de service, unité ET fraîcheur de la source.

**Cas d'école (web1 2026-08-14) :**
- **#3097** « coordinateur silencieux >200h, 0 dispatch » : **prémisse falsifiée** — 263 messages dashboard dans 101 archives, 23 PRs mergées, 53 commits sur la fenêtre exacte. Le dashboard auto-condense à 92 % et archive : à un instant T il ne montre que la fenêtre récente. *Une mesure qui rend « rien » doit d'abord se suspecter elle-même.*
- **#3098** « disque 90 % » : chiffre bon, mais la donnée qui le porte était fausse (16 GB = RAM, pas de stockage). Vérifier l'unité et la fraîcheur de la source.

**Leçon transversale :** un constat basé sur une lecture instantanée d'un store auto-condensé ou d'un état de service DOIT être croisé (archives + `gh` + mesure directe) avant publication.

---

## Analyses productives (ordre de priorité)

Cherche dans cet ordre, dans les TRACES de taches et les ARCHIVES (pas dans les fichiers de règles) :

1. **Interventions utilisateur** (TOP PRIORITY) : `BLOCAGE`/`CORRECTION`/`STOP`/`NON`/`arrête`/`tu hallucines` dans les sessions Claude/Roo récentes. Chacune = friction réelle.
2. **Incidents reproduits** (≥2 occurrences) : erreurs MCP récurrentes, crashes, freezes, scheduler 0 %.
3. **Explosions de contexte** : tâches >100K chars/tour, vitest sans troncature, boucles outils.
4. **Dispatches stale** : items sans `[CLAIMED]`/`[DONE]` après 24h.
5. **Escalations -simple → -complex échouées** : boucles sans escalade.
6. **Bugs production** : mpengine crashes, vmmem freezes, Docker cascade, MCP disconnects.
7. **Frictions agents** : `[FRICTION]` dashboard + `has_errors: true` via `roosync_search`.

**Si aucune des 7 catégories ne donne de matière :** rapporter « rien à signaler » sur le dashboard. NE PAS se rabattre sur les patterns HARD REJECT.

## HARD REJECT — Patterns interdits (rejet immédiat)

| Pattern interdit | Pourquoi |
|---|---|
| Asymétrie de version doc Claude/Roo | Les deux agents évoluent à rythme différent. Asymétrie ≠ bug. |
| « Harmoniser », « synchroniser », « aligner », « standardiser », « unifier » | Harmonisation théorique sans incident concret = entropie coordinateur. |
| Refactoring sans incident | Si ça n'a pas cassé, ne pas le réécrire. |
| Naming drift cosmétique | Pure cosmétique. |
| Doublons apparents sans incident | Peut être volontaire (isolation, perf). |
| Métrique sans seuil dépassé | « Taux 92 % » sans régression observée = juste un chiffre. |
| Comparaison Roo vs Claude sans bug | Pas de fonctionnalité cassée = pas un problème. |

**Si une issue tombe sous HARD REJECT, le bon fix est dans le harnais méta-analyste lui-même**, pas dans une nouvelle règle ou une nouvelle issue.

**Incidents de récidive :** #1455 (asymétrie INTERCOM, rejeté), #1527 (drift 7/14 paires, rejeté), #2079/#2080/#2081 (asymétries context limits / failure thresholds / veille active, rejetés), #1285 (harmonisation 10 incohérences, rejeté — « il faut surtout modifier le meta-analyste pour qu'il se consacre à autre chose »).

## Test 3 Questions (OBLIGATOIRE avant issue)

1. Incident concret avec timestamp et trace ?
2. Reproduit par les données ?
3. Que casse-t-on si on ne crée PAS l'issue ? « Rien » → NE PAS CRÉER.

---

## Cadence (v3 — découplée)

Le cycle de 72h est conservé pour la production d'issues, mais la condensation produit ~52 archives/jour : il faut **découpler** le minage léger de la synthèse lourde.

| Activité | Cadence |
|---|---|
| Scan différentiel archives (comptages, ~1 commande) + lecture des deltas | chaque cycle 72h |
| Production d'issues `needs-approval` (max 3) | chaque cycle 72h |
| Revue thématique mensuelle (tendances § C1) | mensuelle |

---

## Deliverables et boucle de fermeture

### Deliverables

- **Issues `needs-approval`** avec DÉTAIL (données chiffrées, tableaux, exemples). Max 3/cycle.
- **Rapports dashboard compacts** (max 10 lignes), tag `META-ANALYSIS`.
- **Format delta entre cycles** (recommandé v3) : tableau top-N thèmes + deltas vs cycle précédent + thèmes émergents (seuil : apparaissent ≥X fois après ~0). Les 3 signaux d'août (429, GDrive, bande passante) auraient été détectés ainsi.

### Boucle de fermeture (v3 — « où la leçon a atterri »)

**Problème mesuré :** 8/13 issues méta fermées COMPLETED = bon taux de traitement (web1), mais **aucun mécanisme ne vérifie que la leçon atterrit** (règle modifiée, harnais renforcé). Contre-exemple : le signal `drift` était massif en juin (4,7/archive), la règle `submod-pointer-safety` n'a été durcie qu'en août (incident #3056).

**Mécanisme :** pour chaque thème au-dessus du seuil pendant N cycles consécutifs, l'analyste DOIT citer **où la leçon a atterri** (règle, harnais, PR mergée) OU ouvrir une issue `needs-approval`. Sinon le thème est rappelé au cycle suivant avec **compteur de récurrence** visible dans le rapport dashboard.

---

## Check-lists obligatoires

Les check-lists historiques restent valides, mais leur périmètre est **roo-centré** : elles servent là où le scheduler Roo tourne (po-2023/25/26 ; coupé web1, inactif ai-01). Le méta-analyste flotte-side ajoute les dimensions archives + GitHub du v3.

### Santé Outillage (#761)

Détecter les outils sous-utilisés, dégradés ou cassés AVANT abandon silencieux. Checks par cycle :
1. **Outils jamais appelés (>14 jours)** — croiser les outils déclarés avec les traces récentes (`roosync_search` par outil). Distinguer intentionnel / suspect / cassé.
2. **Outils avec bugs ouverts >14 jours** — `gh issue list --label bug --state open`, cross-référencer les noms d'outils.
3. **Workarounds non résolus** — scanner MEMORY.md pour « workaround », « bug connu », « contournement » ; >14 jours sans issue corrective → `needs-approval`.
4. **Secrets exposés** — `.env` commité, clés API dans issues/commentaires, alertes GitHub secret scanning.

### User Interventions (MANDATORY — #981)

Roo est 100 % schedulé → toute intervention utilisateur = SIGNAL DE DYSFONCTIONNEMENT.

| Type | Description | Séverité | Action |
|---|---|---|---|
| BLOCKAGE | Tâche bloquée/boucle, user débloque | CRITICAL | Issue `needs-approval` |
| CORRECTION | User corrige une erreur agent | HIGH | Issue si pattern répété (≥2) |
| REDIRECTION | User change la direction | MEDIUM | Rapport, pas d'issue |
| STOP/RESTART | User arrête/redémarre la tâche | CRITICAL | Issue `needs-approval` |

Détection : `roosync_search(action: "semantic", search_query: "...", role: "user", source: "roo", start_date: "{72h ago}")`.

### Context Explosion (MANDATORY — #855)

| Métrique | WARNING | CRITICAL |
|---|---|---|
| Messages/tâche | >30 | >50 |
| Taille conversation | >50K chars | >100K chars |
| Appels répétés même outil | >10 | >20 |

Causes fréquentes : vitest sans troncature, lectures fichiers entiers sans offset/limit, boucles outils, recherche extensive.

### Simple vs Complex (MANDATORY — #981)

Comparer les performances -simple vs -complex : taux de succès, escalades, interventions user, explosions contexte. **Ne s'applique que là où le scheduler Roo tourne.** Patterns spécifiques : `execute_command` bloqué (terminal natif au lieu de win-cli MCP), outils indisponibles, escalade échouée.

---

## Decision Chain

| Finding type | Action | Authority |
|---|---|---|
| Informational (stats, rates) | Rapport dashboard | Autonome |
| Operational suggestion | Dashboard, coordinateur prend | Autonome |
| Environment issue (.env manquant, MCP down, service) | Dashboard + flag coordinateur | Autonome (coordinateur agit) |
| New issue (bug, friction) | Issue `needs-approval` | Semi-autonome |
| Harness change | Issue `needs-approval` + `harness-change` | **BLOQUÉ jusqu'à approbation user** |

---

## Guard Rails (CRITICAL)

### Meta-analysts MUST NOT:
- Modifier tout fichier de harnais (`.roo/rules/`, `.claude/rules/`, `.claude/commands/`, `.claude/skills/`, `CLAUDE.md`, `.roomodes`, `modes-config.json`, `scheduler-workflow-*.md`)
- Fermer, archiver ou dispatcher des issues GitHub (rôle du coordinateur)
- Force-push, rebase, opérations git destructives
- Créer une issue SANS label `needs-approval`
- Créer des fichiers rapport dans le dépôt (#1179)
- Archiver/supprimer/compresser des sessions (sanctuarisées, #1621)

### Meta-analysts CAN:
- Lire les traces locales (Roo tasks, Claude sessions) via `conversation_browser`/MCP — jamais de Read brut sur fichiers de traces >256KB (#1670)
- Lire les archives dashboard (accès fichier direct)
- Lire tous les fichiers harnais (les deux systèmes)
- Créer des issues `needs-approval` (propositions, pas décisions)
- Écrire sur le dashboard workspace

## Budget Contexte OBLIGATOIRE (#1608)

| Outil | Paramètres OBLIGATOIRES |
|---|---|
| `conversation_browser(view)` | `smart_truncation: true`, `max_output_length: 50000` |
| `conversation_browser(summarize)` | `truncate_instruction: 120`, `compactStats: true` |
| `conversation_browser(list)` | `limit: 20` max |
| `roosync_search` | `max_results: 10` |
| PowerShell/Bash sur archives | `Select-Object -Last/-First 50` ou head/tail |

**JAMAIS** `view`/`summarize` sans smart_truncation sur une session inconnue. **Max 3 lectures de sessions** par cycle.

---

## Canal de communication

**Dashboard workspace (`roosync_dashboard`) = canal officiel et unique.** INTERCOM local (`.claude/local/META-INTERCOM-{MACHINE}.md`) = **DEPRECATED**, fallback UNIQUEMENT si MCP indisponible.

```
roosync_dashboard(action: "append", type: "workspace", tags: ["META-ANALYSIS"], content: "...")
```

---

## Alignement harnais (follow-ups recommandés — hors scope v3)

- **`meta-analyst-rule.md` (v1.7.0)** et le prompt inliné de `start-meta-audit.ps1` : à ré-aligner sur les sections Archive Mining + Anti-Fragile-Premise de ce document (changement du mécanisme schedulé → décision séparée, hors non-buts de #3110).
- **Topologie flotte-side** : à arbitrer (ai-01/user).
- **Indexation des résumés d'archives** (digest → Qdrant) : évolution RSM, à arbitrer séparément.
- **Chantier Zoo→claudish** : lane po-203 — sans lui, les traces zoo échappent à la vue centrale (dépendance frontale de la vue complète).

---

## References

- #551: Meta-Analyst tier (this protocol)
- #3110: v3 evidence-based rewrite (audit web1 + prototype po-2026)
- #540: Coordinator tier — `docs/harness/coordinator-specific/scheduled-coordinator.md`
- `docs/harness/coordinator-specific/meta-analyst-rule.md`: rule slim (7 analyses productives, HARD REJECT)
- `docs/harness/coordinator-specific/meta-analyst-detailed.md`: workflow étapes 0-5, MCP snippets
- `.roo/scheduler-workflow-meta-analyst.md`: workflow scheduler Roo
- `.claude/rules/intercom-protocol.md`: protocole INTERCOM opérationnel

---

**Last updated:** 2026-08-16 (v3.0.0 — #3110)
