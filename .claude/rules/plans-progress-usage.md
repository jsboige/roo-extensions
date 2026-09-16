# Plans / Progress — usage

**Version :** 1.0.0 (initial, #3674 / ADR 015)

## Règle courte

Un chantier long crée optionnellement deux artefacts versionnés :

| Fichier | Rôle |
|---|---|
| `.claude/plans/<id>.md` | Plan lisible humainement — phases, checklists, journal de sessions append-only |
| `.claude/progress/<id>.json` | État machine-readable — items, status, checkpoints, statistics ; reprise après redémarrage |

**Optionnel**, pas obligatoire. Les trois critères qui le justifient (au moins un) :

1. **Durée inter-sessions** — le chantier survit à un redémarrage de session.
2. **Reprise automatique** — un script/agent doit pouvoir reprendre là où il s'est arrêté.
3. **Multi-agents coordonnés** — plusieurs agents partagent un état structuré au-delà du dashboard.

**Hors de ces trois cas, ne crée pas de plan/progress.** Project #67 + issue + branche
suffisent. Le défaut est l'**absence**.

## Garde-fous

- **Pas de duplication avec Project #67.** Le plan documente l'**exécution**, pas l'inventaire.
- **`status: "completed"` exige `completed_at` et `metric_after`** (si chantier à métrique).
  Un `completed` sans `completed_at` est un mensonge.
- **Écritures atomiques** (`.tmp` + `os.replace()`).
- **Pas d'écriture automatique par hook.** L'agent qui accomplit un jalon écrit, personne d'autre.
- **Cross-link avec le registre open-questions #3656** : le plan référence les questions
  ouvertes via un champ, ne les **porte pas** (deux registres, deux rôles).

## Schéma, structure, anti-patterns, protocole de reprise

→ [`docs/harness/reference/plans-progress-schema.md`](../../docs/harness/reference/plans-progress-schema.md)

## ADR

→ [`docs/harness/adr/015-plans-progress-convergence-coursia.md`](../../docs/harness/adr/015-plans-progress-convergence-coursia.md)

## Pourquoi

L'observation user n°1 (« le coordinateur CoursIA maîtrise mieux l'avancement de ses
chantiers longs ») a une cause structurelle : CoursIA opère `.claude/plans/` et
`.claude/progress/`, roo-extensions non. ADR 015 acte la convergence — la **convention**,
pas les fichiers gelés (CoursIA les a retirés de git le 2026-09-02 comme artifacts
régénérables). Le pilote Epic #3111 dogfood la convention ; son sort est tranché à la
fermeture de l'Epic.

**How to apply :** Quand un Epic ou un chantier long démarre (coordinateur, ou worker
sur une tâche >1 session), considère les trois critères. Si l'un d'eux est rempli,
propose la création d'un plan/progress en début de chantier ; sinon, ne fais rien.
Quand tu accomplis un jalon macroscopique (phase terminée, item completed d'un
chantier structuré), **mets à jour** le progress.json existant, ne le réécris pas.
