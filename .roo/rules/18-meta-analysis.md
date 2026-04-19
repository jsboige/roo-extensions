# Protocole Meta-Analyse - Architecture 3x2 Scheduler (Roo)

**Version:** 3.1.0 (HARD REJECT block promu depuis workflow vers regle auto-chargee)
**MAJ:** 2026-04-19

## Architecture 3 Tiers

| Tier | Frequence | Machines | Role |
|------|-----------|----------|------|
| **Meta-Analyste** | 72h | TOUTES | Observer, analyser, PROPOSER |
| Coordinateur | 6-12h | ai-01 only | Trier, dispatcher, suivre |
| Executeur | 6h | TOUTES | Executer les taches assignees |

## Ce que Roo analyse

1. **Traces Roo (auto-analyse)** : Taux succes/echec par mode, escalades, usages outils. Outils MCP OBLIGATOIRES (`conversation_browser`, `roosync_search`).
2. **Traces Claude (croisee)** : Commits, worktrees, logs worker. **LIMITATION #874** : sessions Claude non indexees dans Qdrant.
3. **Qualite des taches** : PRs recentes (scope, completion), dispatches (suivi, resultats), travail stale/abandonne.
4. **Metriques operationnelles** : Issues creees/fermees, taux utilisation, violations.
5. **Frictions semantiques (#637)** : `roosync_search(has_errors: true)` pour patterns recurrents.

## Ce que Roo produit (#1081)

- **Issues GitHub DETAILLEES** avec contexte, donnees, metriques, recommandation
- **Dashboard COMPACT** : max 10 lignes (index vers issues, pas rapport)
- **Issues `needs-approval`** (propositions) / **`needs-approval` + `harness-change`** (modifications bloquantes)

## INTERDICTION ABSOLUE — Pas de fichiers rapport (#1179)

Les meta-analystes NE DOIVENT PAS creer de fichiers dans le depot pour leurs rapports.
Canaux de sortie : 1. Dashboard workspace 2. Issues GitHub 3. GDrive `.shared-state/meta-analysis/`

## HARD REJECT — Rapports INTERDITS (rejet immediat a la creation d'issue)

**Ces sujets sont interdits meme si l'analyse les detecte.** Incidents historiques : #1455 (asymetrie INTERCOM v3.0.0/v3.2.0, 2026-04-17, rejete par utilisateur), #1527 (drift 7/14 paires Claude/Roo, 2026-04-19, rejete : "j'en ai marre de hard reject a chaque passe... on continue de s'enfoncer dans Kafka"). Ces rapports encombrent le coordinateur sans aucun gain fonctionnel.

| Categorie | Exemple | Pourquoi interdit |
|-----------|---------|-------------------|
| Asymetrie de version doc | `.roo/rules/X v3.0.0` vs `.claude/rules/X v3.2.0` | Les deux agents evoluent a rythme different. L'asymetrie n'est PAS un bug. |
| "Harmoniser", "synchroniser", "aligner" | "Synchroniser SDDD vers v3.0.0" sans incident | Harmonisation theorique = entropie coordinateur. |
| Refactoring architectural sans incident | "Extraire un service", "centraliser un helper" | Si ca n'a pas casse, ne pas le reecrire. |
| Naming convention drift | `field to vs target`, `machineId vs machine_id` | Pure cosmetique. |
| Doublons apparents sans incident | "Fonction X definie dans Y et Z" | Peut etre volontaire (isolation, perf #1145). |
| Metrique sans seuil depasse | "Taux de succes 92%" sans constat de regression | Juste un chiffre. |
| Drift comparatif Claude/Roo sans bug | "50% des paires divergentes" | Pas de fonctionnalite cassee = pas un probleme. |

## Test de validation AVANT creation d'issue (OBLIGATOIRE, 3 questions)

Avant de creer toute issue `[META-ANALYSIS]`, repondre :

1. **Y a-t-il un incident concret avec timestamp et trace ?** (ex : "task #N echouee 2026-04-XX", "agent Y bloque 5h")
2. **Le probleme est-il REPRODUIT par les donnees ?** (>=2 occurrences avec dates)
3. **Si je ne cree PAS cette issue, qu'est-ce qui casse concretement ?** Si la reponse est "rien, c'est juste moins propre" → **NE PAS CREER.**

Si une reponse est floue : pas d'issue. Constat dans le dashboard compact (Etape 3 du workflow).

## Exemples de rapports LEGITIMES (a garder)

- "Task #N a boucle 10x sur win-cli blocked operators entre HHMM et HH'MM'" (avec traces)
- "MCP roo-state-manager crash sur po-2024 le DATE, erreur X, 3 recurrences cette semaine"
- "Explosion contexte detectee sur tache #M (>50K chars en 1 tour)"
- "Worker po-2025 produit PRs vides depuis 3 cycles consecutifs"

Ces exemples ont tous : **timestamp**, **reproduction**, **impact concret**.

## Chaine de Decision

| Type | Action | Autorite |
|------|--------|----------|
| Informatif | Dashboard | Autonome |
| Suggestion | Dashboard + coordinateur | Autonome |
| Environnement (MCP HS) | Dashboard + flag coordinateur | Autonome |
| Nouvelle issue (bug, friction) | Creer `needs-approval` (apres validation 3 questions) | Semi-autonome |
| Changement harnais | Creer `needs-approval` + `harness-change` | **BLOQUE** |

## Checks obligatoires (chaque cycle)

- **Sante outillage** : Outils inactifs >14j, bugs ouverts >14j, workarounds non resolus, secrets exposes
- **Interventions utilisateur (#981)** : BLOCAGE/CORRECTION/STOP=CRITICAL. Chacune = issue potentielle
- **Explosions contexte (#855)** : Taches >50 messages ou >100K chars. Causes : vitest sans troncature, lectures entieres, boucles
- **Performance -simple vs -complex (#981)** : Comparer taux succes, escalades, interventions user

## Garde-Fous (CRITIQUE)

**NE DOIT PAS :** Modifier `.roo/rules/`, `.claude/rules/`, `CLAUDE.md`, `.roomodes`, `modes-config.json`. Fermer/archiver/dispatcher issues. Git push --force/rebase. Creer issues SANS `needs-approval`. **Creer issues HARD REJECT (voir tableau ci-dessus).**

**PEUT :** Lire toutes traces/fichiers. Creer issues avec `needs-approval` (apres validation 3 questions). Ecrire dashboard/GDrive. Commenter issues.

## Contraintes contexte

- Seuil condensation GLM : 75% (#1152). Pas de coverage tests. Limiter git log/diff `| head -30`.
- Si contexte sature → arreter, ecrire conclusions partielles sur dashboard.

## Workflow scheduler

`ask-complex` lit workflow → `code-complex` analyse traces → `code-complex` analyse qualite taches/PRs/dispatches → `code-simple` ecrit dashboard → `ask-simple` lit reponse Claude → `code-simple` reconciliation → `code-simple` cree issues.

**Ref complete :** `.roo/scheduler-workflow-meta-analyst.md` (workflow runtime, contient deja le HARD REJECT en Etape 2) | `docs/harness/reference/meta-analysis.md` (Claude)

---
**Historique versions completes :** Git history avant 2026-04-08
**v3.1.0 (2026-04-19) :** Promotion du HARD REJECT block + 3 questions de validation depuis le workflow scheduler vers la regle auto-chargee. Cause : #1527 (recurrence du pattern #1455 malgre HARD REJECT present uniquement dans le workflow runtime). En auto-load, le bloc devient visible des le demarrage de toute conversation Roo (pas seulement quand le scheduler meta-analyste tourne).
