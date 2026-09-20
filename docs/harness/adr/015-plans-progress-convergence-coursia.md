# ADR 015 — Convergence plans/progress depuis CoursIA

**Numéro :** 015 (le n° 014 est en collision entre PR #3680 et PR #3681, Epic #3111 phase 2 —
les deux passeront avant tout n° 015+).
**Issue :** [#3674](https://github.com/jsboige/roo-extensions/issues/3674)
**Statut :** Accepted (GO user 2026-09-15, Epic #3111 phase 2 candidat #1)
**Auteur :** myia-web1, claude-interactive
**Date :** 2026-09-16

---

## Contexte

L'audit de convergence des harnais (Epic #3111, passes 1-4, voir
[`docs/harness/reports/harness-convergence-audit-2026-08-17.md`](../reports/harness-convergence-audit-2026-08-17.md)
§7) a confirmé que CoursIA opère une machinerie **`plans/` + `progress/`** que roo-extensions
n'a pas :

- `.claude/plans/*.md` — un fichier par chantier long (phases + checklists + journal de sessions
  append-only). L'observé : `genai-comprehensive-validation.md` (649 lignes, 4 phases, 7 entrées
  de journal sur 5 semaines, légende de statuts ⬜/✅/⚠️/❌/⏭️).
- `.claude/progress/*.json` — un fichier par chantier (per-item status, checkpoints,
  statistics, conçu pour la **reprise après redémarrage**). L'observé :
  `genai-image-enrich.json` (16 notebooks, status `pending|in_progress|completed|failed`,
  `resume: true` par défaut, écritures atomiques via `.tmp` + `replace()`).
- La convention est portée par un agent (`series-improver.md`, 532 lignes) qui définit le
  protocole resume et un CLI (`scripts/series_progress_manager.py`, 225 lignes : `list`,
  `status`, `cancel`, `resume`, `report`).

**Statut côté CoursIA au 2026-09-02 (commit `8971a15e12`)** : les deux répertoires sont passés
en **`.gitignore`** comme « artifacts régénérables ». La convention reste vivante (agent doc +
manager script sur `main`), seuls les fichiers de travail sont locaux.

C'est la confirmation structurelle de l'observation user n°1 : « le coordinateur CoursIA
maîtrise mieux l'avancement de ses chantiers longs ». roo-extensions suit l'exécution via
Project #67 + issues + MEMORY/cycles, sans artefact **machine-readable** de reprise.

## Décision

**On porte la convention sans copier les fichiers.** Les chantiers longs de roo-extensions
gagneront un double artefact optionnel :

| Fichier | Rôle | Format |
|---|---|---|
| `.claude/plans/<chantier-id>.md` | Plan lisible humainement — phases, checklists, journal de sessions append-only | Markdown, sections imposées |
| `.claude/progress/<chantier-id>.json` | État machine-readable — items, status, checkpoints, statistics ; reprise après redémarrage | JSON, schéma imposé |

**Convention de nommage `<chantier-id>`** : kebab-case, **préférer** un identifiant d'Epic
(`3111`) ou d'issue majeure (`3674-plans-progress`). Plusieurs chantiers par Epic sont permis
si l'Epic a des phases distinctes ; un seul par chantier autonome.

**Périmètre d'usage — optionnel, pas obligatoire.** Le défaut reste Project #67 + issue +
branche : ces trois surfaces couvrent la majorité des tâches. Les deux artefacts sont créés
**quand** l'un des trois critères suivants est rempli :

1. **Durée inter-sessions** — le chantier survit à un redémarrage de session (cron qui
   reprend à l'identique, worker redémarré, machine ré-arée).
2. **Reprise automatique** — un script ou un agent doit pouvoir **reprendre là où il s'est
   arrêté**, sans intervention humaine.
3. **Multi-agents coordonnés** — plusieurs agents (coordinateur + workers, ou plusieurs
   workers) doivent partager un état structuré au-delà de ce que portent les messages
   dashboard.

Hors de ces trois cas, plans/progress sont **du bruit** : le projet n'en a pas besoin.

**Traçabilité dans Project #67 — pas de duplication.** L'Epic reste l'inventaire
(GitHub Project). Le plan markdown et le progress JSON documentent **l'exécution**. Un
chantier ne crée pas une nouvelle issue pour chaque mise à jour du progress : il **met à
jour** le fichier, et un événement `[PROGRESS]` sur le dashboard workspace marque les
jalons.

**Versionnement des fichiers : à arbitrer chantier par chantier.** CoursIA a tranché
« gitignored » (régénérable). Pour roo-extensions, deux cas :

- **Chantier archivé (Epic fermé, sans suite)** → gitignored ou supprimé. Pas de valeur
  historique.
- **Chantier actif avec valeur de coordination inter-machines** → versionné. Le progress
  est lu par les workers ; sa divergence entre machines est un signal.

Le défaut à retenir pour le pilote Epic #3111 est **versionné** (la phase 2 a plusieurs
sous-issues sur plusieurs machines — l'état partagé a de la valeur), mais chaque Epic
arbitre à la création.

## Non-buts

- **Pas de duplication avec Project #67.** plans/progress documentent l'exécution, pas
  l'inventaire. Une case cochée dans un plan **n'est pas** une issue fermée.
- **Pas de modification du harnais hors PR.** Le skill `executor`, les commandes
  `/coordinate` et `/executor`, les agents existants ne sont pas modifiés dans cette
  livraison. Une intégration se fera **après** stabilisation, sur des cas d'usage
  suffisants.
- **Pas d'import de cadence CoursIA.** La cadence 30 min vs 4 h est un double mandat user
  légitime (cf. ADR 016, sibling #3675) — le pilote respecte 4 h côté roo-extensions.
- **Pas d'automatisation de l'écriture.** Aucune écriture de progress.json pilotée par un
  hook ou un cron. C'est à l'agent (ou à l'outil qu'il lance, ex. jupyter-papermill) de
  mettre à jour le fichier à chaque jalon. L'écriture automatique silencieuse est la source
  n°1 de divergence entre ce que le fichier dit et ce que le chantier a réellement fait.

## Conséquences

**Positives.** Le coordinateur qui reprend une session trouve l'état du chantier en lisant
un fichier, pas en re-deroulant les [DONE] du dashboard. Les workers peuvent reprendre un
chantier interrompu (restart machine, cron expiré) sans intervention humaine. La
divergence entre plusieurs agents coordonnés est détectable par diff git du progress.

**Coût.** Chaque chantier long gagne deux fichiers à maintenir. L'agent doit se souvenir de
mettre à jour le progress à chaque jalon (sinon le fichier devient un mensonge). C'est
exactement le défaut que #3656 cherche à éteindre côté open-questions — une entrée non
mise à jour est pire qu'une entrée absente.

**Risque.** Le progress.json peut mentir si l'agent écrit un `completed` sans avoir
effectivement terminé. Le garde est dans le **schéma** (un item `completed` doit porter
`completed_at` et une métrique vérifiable) et dans la **discipline de revue** (un
`[DONE]` qui ne met pas à jour le progress.json qu'il cite est suspect).

## Alternatives considérées

**a) Ne pas converger — laisser Project #67 + dashboard comme seul support.** Rejeté par
GO user 2026-09-15. Le constat est posé : l'avancement d'un chantier long est
significativement plus lisible côté CoursIA.

**b) Importer les fichiers CoursIA tels quels** (sans la convention de nommage, le
schéma JSON, l'agent doc, le manager CLI). Rejeté — c'est le contenu, pas la convention,
qui a été retiré de git par CoursIA. Importer des fichiers gelés d'août 2025 sans le
protocole de reprise qui va avec, c'est importer un dictionnaire sans la grammaire.

**c) Tout versionner, comme un artefact de premier ordre.** Rejeté pour le cas général.
La plupart des chantiers roo-extensions sont des PRs isolées (Epic #3111 candidat #2 =
une PR = un chantier de 3 jours, ne justifie pas un plan + un progress). Le versionnement
forcé gonfle le repo sans valeur ; le défaut reste l'optionnel.

**d) Tout gitignorer.** Rejeté pour le cas général, accepté pour les chantiers archivés.
Le coordinateur inter-machines perdrait le diff d'état — qui est précisément la valeur
ajoutée du progress.json par rapport au dashboard (le dashboard est append-only, le diff
git du progress est sémantiquement riche).

## Plan de mise en œuvre

Livré dans le PR de cette ADR :

1. **Schéma `progress.json`** — `docs/harness/reference/plans-progress-schema.md` (format
   imposé, exemple annoté, garde-fous « ne pas mentir »).
2. **Structure `plans/*.md`** — même doc, sections imposées + facultatives, légende de
   statuts alignée sur la convention CoursIA (⬜/✅/⚠️/❌/⏭️).
3. **Règle courte d'usage** — `.claude/rules/plans-progress-usage.md` (3 critères, scope
   « optionnel », lien vers Project #67).
4. **Pilote** — `.claude/plans/3111.md` (plan de l'Epic #3111 phase 2) et
   `.claude/progress/3111.json` (état machine-readable du pilote, mis à jour au
   rythme des merges). Le pilote est un **dogfooding** : il expire quand l'Epic ferme,
   et son sort (archivage ou conservation comme exemple) est tranché à la fermeture.
5. **Cross-link** avec le registre open-questions #3656 — la règle courte d'usage renvoie
   vers `harnais-tightening.md` §1 pour la discipline « registre re-parcouru, jamais
   silent-dead ».

## Références

- Issue : [#3674](https://github.com/jsboige/roo-extensions/issues/3674) (Epic #3111 phase 2 candidat #1)
- Audit : [`docs/harness/reports/harness-convergence-audit-2026-08-17.md`](../reports/harness-convergence-audit-2026-08-17.md)
  §7 table ligne 1 (candidat #1 inchangé après passes 2-3)
- CoursIA — référence supprimée de git le 2026-09-02 (commit `8971a15e12`), convention
  toujours vivante via `.claude/agents/series-improver.md` +
  `scripts/series_progress_manager.py`
- Sibling : ADR 016 (anti-tarissement, PR #3681 — le n° 014 initialement revendiqué a été cédé à la collision)
- Sibling : #3656 (registre open-questions, même cible = continuité inter-sessions)
- Observation fondatrice : user n°1, « le coordinateur CoursIA maîtrise mieux l'avancement
  de ses chantiers longs », 2026-08-15
