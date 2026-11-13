# Cadence du coordinateur ai-01 — historique des décisions

**Ce document est un historique.** L'expression cron courante n'est écrite qu'à un seul endroit :
la ligne `CronCreate` canonique de
[`.claude/commands/coordinate.md`](../../../.claude/commands/coordinate.md), section « Wakeup Cycle
Cadence ». Aucun autre fichier ne la recopie ; ce document donne les cadences en heures, dernière
ligne du tableau comprise, jamais sous forme d'expression cron.

## Pourquoi une source unique

Le job `CronCreate` du coordinateur ne vit que dans sa session. À chaque continuation de contexte,
la règle #2832 le ré-arme à partir de ce que le fichier de commande prescrit. Tant qu'un fichier
cite une ancienne valeur, la cadence décidée par le user est donc restaurée à l'ancienne, sans
signal.

Jusqu'au 13/11/2026 l'expression cron était recopiée à sept endroits dans quatre fichiers
(`coordinate.md` ×3, `skills/executor/SKILL.md` ×2, `commands-skills-pairs.md`,
`per-machine-harness-reliability-checklist.md`), et la valeur en heures à plusieurs autres. Mesure
du coût : la décision du 07/11 (6 h) a été appliquée au job vivant mais jamais aux fichiers, qui
ont prescrit 12 h pendant six jours.

Depuis, un changement de cadence est une modification d'une ligne, et la garde
`scripts/testing/unit/coordinator-cadence-single-source.Tests.ps1` (job CI `unit-pester`) échoue si
une seconde ligne `CronCreate … "/coordinate"` ou une expression cron du coordinateur de valeur
différente réapparaît dans `.claude/` (commandes, skills, règles, agents, configs) ou dans `docs/`.

**Ce que la garde ne voit pas :** une cadence écrite en prose (« 12 h », « toutes les douze
heures ») ou un pas seul (`*/12`) sans la minute. Une phrase qui donne la cadence du coordinateur
en clair ailleurs que dans ce tableau reste donc à la charge de la relecture : y mettre un renvoi
vers la ligne canonique, pas une valeur.

## Invariants qui ne changent pas avec la cadence

- **Minute `:23`.** Les exécuteurs tirent à `:41`. Aux heures communes, les 18 minutes d'écart
  évitent un tir groupé sur l'API. On ne « corrige » pas `:23` vers `:41`.
- **Le coordinateur seul.** Les exécuteurs sont à 4 h depuis les mandats user des 15-17/08/2026 ;
  l'asymétrie est voulue.
- **Cron, pas `ScheduleWakeup`.** `ScheduleWakeup` est borné à une heure : il ne peut pas porter un
  cycle de plusieurs heures.
- **Pas de timer adaptatif.** L'urgence passe par `[WAKE-CLAUDE]`, pas par un intervalle qui varie
  selon la charge perçue.

## Chaîne des décisions

| Date | Cadence | Origine |
|---|---|---|
| 2026-09-03 | 8 h | #3396 |
| 2026-09-06 | 4 h | #3485 |
| 2026-09-07 | 3 h | #3505 |
| 2026-09-08 (15:40Z) | 2 h | #3539 |
| 2026-09-09 | 3 h | #3547 |
| 2026-09-11 | 4 h | mandat user direct |
| 2026-09-12 | 6 h | #3610, mandat user |
| 2026-09-13 | 4 h | #3629, directive user |
| 2026-09-15 | 5 h | #3660, directive user |
| 2026-09-17 | 6 h | directive user |
| 2026-09-22 | 3 h | directive user |
| 2026-09-24 | 5 h | directive user (« retour au rythme nominal ») ; même jour : une cadence plus espacée se compense par des files multi-grains, pas par moins de travail dispatché |
| 2026-10-04 | 6 h | directive user : « Réarme ton cron de session de 6h stp » |
| 2026-10-05 | 12 h | directive user : « Est-ce que tu pourrais ralentir de moitié ton cron tout en dispatchant des deep queues aux workers ? » |
| 2026-11-07 | 6 h | directive user : « Bonjour, réarme un cron de coordination de 6h stp ». Entrée dans le dépôt le 13/11 seulement |

Avant le 03/09/2026 : 3 h uniforme pour toute la flotte (14/07), puis séparation par fournisseur
le 20/07 (coordinateur ralenti, exécuteurs accélérés). La valeur du coordinateur entre le 20/07 et
le 03/09 n'est pas consignée dans les fichiers dont ce tableau est repris. La suite côté
exécuteurs est dans `.claude/skills/executor/SKILL.md`, section cadence.

## Quand le user change la cadence

1. Modifier la ligne canonique de `coordinate.md` (valeur, date, verbatim).
2. Ajouter une ligne au tableau ci-dessus.
3. Ré-armer le job vivant (`CronDelete` de l'ancien, `CronCreate` de la ligne canonique).
4. PR. Le job vivant seul ne survit pas à la prochaine continuation de contexte.
