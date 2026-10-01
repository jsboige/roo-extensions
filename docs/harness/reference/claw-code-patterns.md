# Patterns claw-code adoptés (#1320) — state machine, recovery, mock parity

**Origine :** issue #1320 — extraire les meilleurs patterns de harnais
d'`ultraworkers/claw-code` (harnais « clawable » : state machine first, events
over scraped prose, recovery before escalation, branch freshness before blame,
partial success first-class, terminal is transport not truth, policy is
executable).
**Analyses préalables :** c. 2026-04-11 (agent crashé, doc orpheline) et
2026-05-11 (po-2023 R26 — priorisation P1/P2). Cette page documente l'état
**livré** et ce qui reste volontairement non adopté.

## Statut par pattern

| # | Pattern claw-code | Statut | Où |
|---|-------------------|--------|-----|
| 1 | Worker state machine | **ADOPTÉ** | `HeartbeatService.ts` (`AgentLifecycleState`) + action `roosync_diagnose lifecycle` |
| 2 | Events over scraped prose | **ADOPTÉ (partiel)** | transitions typées `LifecycleTransitionEvent` + callback `onLifecycleChange` ; le heartbeat dérivé reste pour la présence process |
| 3 | Recovery-before-escalation | **ADOPTÉ** | `HeartbeatService.attemptRecovery()` + action `roosync_diagnose recovery` |
| 4 | Branch freshness before blame | **NON ADOPTÉ** — voir « Suivis » | cible : `scripts/scheduling/start-claude-worker.ps1` avant la passe de tests |
| 5 | Partial MCP success | **NON ADOPTÉ** (priorité basse à l'origine) | la dégradation PG→GDrive du dashboard offre déjà un mode dégradé équivalent côté lecture |
| 6 | Mock parity harness | **ADOPTÉ** | `tests/mock-parity/` + `tests/unit/tools/mock-parity.test.ts` (submodule RSM) |

## 1. State machine — `AgentLifecycleState`

`MachineStatus` (online/idle/unknown) dit si le **process** vit ;
`AgentLifecycleState` dit ce que l'**agent fait** :

```
BOOTSTRAPPING → READY → CLAIMED → WORKING → REPORTING → IDLE
                (n'importe quel état) → ERROR → RECOVERING → READY
```

- Transitions validées par table (`VALID_TRANSITIONS`) ; transition invalide →
  `HeartbeatServiceError` bruyante, jamais silencieuse.
- Historique borné (100 événements), requêtable (`getLifecycleHistory`).
- Câblage MCP : `roosync_diagnose(action:"lifecycle", state:"WORKING", reason:"…")`
  — re-câblé depuis l'outil standalone via l'arbitrage #512 (PR submod #527,
  tests de routage #528).

**Contrat d'usage worker :** signaler `CLAIMED` en prenant une tâche,
`REPORTING` avant de poster `[DONE]`, `ERROR` dès l'échec détecté — le
coordinateur peut alors dispatcher sur les seules machines `READY`.

## 2. Recovery-before-escalation

Classification d'erreur → action d'auto-guérison à tenter **une fois** avant
d'escalader (`DEFAULT_RECOVERY_ACTIONS`) :

| Signature d'erreur | Action |
|---|---|
| `ENOENT…roo-state-manager` | `rebuild_mcp` |
| `upload-pack: not our ref` | `reset_submodule` |
| `CONFLICT…Merge conflict` | `rebase_git` |
| `EBUSY…\.node`, `429/rate limit`, `ECONNREFUSED/RESET/TIMEDOUT` | `retry_once` |

**Point de décision MCP (la nouveauté 2026-10 — submod PR #1273, `6505faea` ;
servi par un hôte RSM seulement après le bump du pointeur `mcps/internal` et le
respawn de l'hôte) :**

```
roosync_diagnose(action:"recovery", errorMessage:"<erreur brute>")
  → mode:"matched", matchedAction:"rebuild_mcp"   # exécuter, puis recordRecoveryOutcome
  → mode:"no_match"                                # escalader immédiatement
roosync_diagnose(action:"recovery", outcomeAction:"rebuild_mcp", success:true)  # trace
roosync_diagnose(action:"recovery")                # historique (borné 50)
```

L'outil rend la **décision**, pas l'exécution — le worker/scripts exécutent la
remédiation (source de vérité unique des patterns : `HeartbeatService`, pas de
réplication PowerShell).

**Limites du contrat (à lire avant d'exécuter une action) :**

- **« Une fois » est un contrat appelant, pas une garde.** `attemptRecovery`
  ne consulte pas l'historique : la même erreur re-matche la même action à
  chaque appel. De plus, l'historique vit **en mémoire** du process (pas
  persisté, ADR 008) et repart de zéro au redémarrage de l'hôte. Une erreur
  persistante peut donc relancer la même remédiation à chaque cycle : c'est au
  worker de compter ses tentatives et d'escalader au deuxième échec.
- **`rebase_git` et `reset_submodule` modifient l'arborescence.** Avant de les
  exécuter, appliquer la garde de préservation prouvée de
  [`clean-cycle-exit.md`](clean-cycle-exit.md) (#3776) : contenu non livré
  committé et poussé, ou sauvegardé hors dépôt avec manifeste. Jamais de
  `reset_submodule` sur un gitlink sans
  [`submod-pointer-safety`](../../../.claude/rules/submod-pointer-safety.md).

## 3. Mock parity harness

Objectif claw-code : CI déterministe sans dépendance externe (eux : service
Anthropic-compatible mocké ; nous : **GDrive**). Livré dans le submodule
roo-state-manager :

- `tests/mock-parity/in-memory-fs.ts` — fs en mémoire implémentant la surface
  exacte utilisée par les chemins de stockage (y compris le piège
  `import { promises as fs } from 'fs'` qui contourne un mock `fs/promises` nu).
- `tests/mock-parity/scenarios.ts` — scénarios scriptés : write/read dashboard,
  append visible, append idempotent (#3276), send→inbox messages.
- `tests/unit/tools/mock-parity.test.ts` — le **runner de diff comportemental** :
  chaque scénario tourne sur fs réel (temp dir) PUIS sur fs mémoire ; arbres de
  fichiers + résultats normalisés doivent être identiques. Un diff = le mock a
  dérivé du comportement fs réel.

Détail (règles d'isolation, gaps délibérés, contrat de normalisation) :
`tests/mock-parity/README.md` dans le submodule.

## Suivis (non adoptés, volontairement)

- **Branch freshness (pattern 4)** : la garde « branche en retard de >N commits
  de main → rebase avant de croire un test rouge » n'est pas câblée. Cible
  naturelle : `scripts/scheduling/start-claude-worker.ps1` (pré-passe de tests),
  avec tests Pester — chantier séparé, le script fait 5 300+ lignes et porte
  la flotte.
- **Partial MCP success (pattern 5)** : reporté ; la lecture dashboard
  PG→GDrive couvre déjà le cas d'usage dégradé dominant.

## Historique de livraison

| Livraison | Contenu |
|---|---|
| submod `cfed2cdc`/`b9874a67` | `AgentLifecycleState` + outil lifecycle standalone |
| submod `13d1f197`/`dba8b54a` | Recovery-Before-Escalation dans HeartbeatService |
| submod `7a69788f` (PR #527, arbitrage #512) | lifecycle re-câblé en action `roosync_diagnose` |
| submod `6bbda09a` (PR #528, #2307 Phase 5) | tests de routage lifecycle |
| submod `6505faea` (PR #1273, 2026-10-01) | action `roosync_diagnose recovery` + mock parity harness |
