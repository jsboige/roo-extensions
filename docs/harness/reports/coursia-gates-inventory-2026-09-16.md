# Inventaire des gates CI CoursIA → verdicts porter / adapter / ignorer

**Date :** 2026-09-16
**Auteur :** myia-po-2023 (claude-interactive)
**Issue :** [#3673](https://github.com/jsboige/roo-extensions/issues/3673) — livrable 3 (inventaire) ; les livrables 4 (pre-commit) et 5 (drift-scan) sont réalisés dans la même PR
**Prédécesseurs :** audit convergence 2026-08-17 ([harness-convergence-audit-2026-08-17.md](harness-convergence-audit-2026-08-17.md), passes 1-4, PR #3155)

---

## Méthode

Clone sparse `blob:none` de `jsboige/CoursIA` à `origin/main` (HEAD 2026-09-16),
extraction mécanique (nom, déclencheurs) des **162** fichiers `.github/workflows/*.yml`,
classification par famille. Chaque verdict « porter/adapter » est appuyé sur la
lecture du YAML source (cité dans le texte), pas sur le seul nom de fichier.

**Réconciliation des comptes :** passe 1 (web1, 15/08) = 91 · passe 2 (po-2026, 17/08) =
93 · ce jour = **162**. Le delta 93→162 en 30 jours (~2,3/jour) est le rythme de
production CoursIA lui-même — c'est une donnée pour l'arbitrage, pas une erreur de
mesure : la table ci-dessous donne les décomptes par famille au jour cité.

## Vue d'ensemble par famille

| Famille | n | Nature | Verdict |
|---|---|---|---|
| Domaine CoursIA (pédagogie, contenu, process lanes) | 55 | advisories de prose/rendu, sweeps de lanes, gates pédagogiques | **IGNORER** |
| `lean-*` (CI par cours Lean) | 34 | générés par cours — volume légitime, pas de la profondeur | **IGNORER** |
| Génériques transférables | 28 | secret-scan, doc-links, sweeps d'orphelins, guards de parité | **mélange — cœur du rapport (§2)** |
| `notebook-*` | 14 | ratchets d'exécution/rendu de notebooks | **IGNORER** (pas de notebooks versionnés ici) |
| `dotnet-*` | 5 | projets .NET des cours | **IGNORER** |
| `translation-*` | 5 | dérive i18n fr/en | **IGNORER** |
| Infra PR-gate (agrégation, rerun, sweeps de verdicts) | 4 | required-checks maison | **IGNORER** (GitHub branch protection couvre) |
| `svg-*` | 4 | géométrie des figures | **IGNORER** |
| `twin-parity*` | 4 | parité des deux lanes (clones jumeaux) | **IGNORER** — couvert ici par `roosync compare_config` + harmonization |
| `slides-*` | 3 | composition des slides | **IGNORER** |
| Lane-claim, runner-infra, machine-dep | 6 | process/scheduling propre à CoursIA | **IGNORER** |

Les familles IGNORER se jugent en un critère : **le contenu qu'elles garantissent
n'existe pas dans ce dépôt** (notebooks, Lean, SVG, slides, i18n, .NET, lanes
jumelles, runners self-hostés). Le non-but de #3673 s'applique : pas d'unification
forcée, 3→4 workflows racine est un volume légitime pour ce dépôt.

## §2 — Les 28 génériques : verdict un par un

### Réalisés dans cette PR

| Gate CoursIA | Verdict | Réalisation ici |
|---|---|---|
| `secret-scan.yml` (gitleaks, PR+push, binaire épinglé côté nous) | **PORTER** | `.github/workflows/secret-scan.yml` + `.gitleaks.toml` (allowlist des 23 faux positifs triés ce jour : docs vendues `mcps/external/github/`, fixtures de test, placeholder explicite). Mesure locale : 4419 commits scannés en ~1 min 30, **0 finding** avec allowlist |
| `hooks-parity.yml` (+ `check_hooks_parity.py` : l'épingle pre-commit `rev` doit égaler la version CI) | **ADAPTER (v1 mécanique)** | check `gitleaks-parity` de `scan-doc-tree-drift.ps1` — assert à chaque PR via la suite Pester. Leçon CoursIA #10139 : un pre-commit vert qui ne prédit pas la CI est un garde inerte |
| `docs-link-check.yml` (liens inter-docs, comparé à la base) | **ADAPTER** | livrable 5 : `scripts/docs/scan-doc-tree-drift.ps1` couvre CLAUDE.md (decomptes #3321, liens markdown, chemins backtick) ; `scan-broken-links.ps1` existant couvre déjà l'arbre .md entier — les deux sont complémentaires, aucun n'est câblé en CI avant cette PR |
| `stale-guard-red-sweep.yml` + `pr-gate-stale-sweep.yml` (rouges périmés : dater le rouge par la base figée, jamais `gh run rerun`) | **ADAPTER (forme minimale)** | `schedule:` quotidien sur `ci.yml` — une fixture qui pourrit **sur main** sans push (le time-bomb #3673 du 15/09) rencontre enfin un CI au jour le jour au lieu d'attendre la prochaine PR de la flotte |

### Candidats différés (classés par valeur, à arbitrer en issues séparées)

| Gate CoursIA | Verdict | Pourquoi c'est pertinent ici |
|---|---|---|
| `orphan-branch-scan.yml` (hebdo, advisory, verdict sur **l'identité de contenu** pas l'ancestralité — toujours exit 0, rapport sur issue-registre) | **PORTER (prochaine vague)** | La classe squash-merge de [worktree-lifecycle.md] : « aucune propriété du graphe git ne dit livré ». Historique : ~300 worktrees purgés à la main en 4 vagues, 151 `wt/worker-*` (#2638). Leur discrimination contenu≠ancestralité est exactement le piège documenté |
| `workflow-path-filter-audit.yml` (le filtre `paths:` couvre-t-il toujours les porteurs des gardes qu'il déclenche) | **ADAPTER (prochaine vague)** | Le filtre `paths:` de `ci.yml` porte **six instances documentées du même gap** (f6580da6 mcp-chain-watchdog, #3216, #3647, #3656, #3639 « Sixth instance »…) — chaque gap a été trouvé à la main après coup. C'est une panne récurrente mesurée chez nous, avec un organe CI qui existe déjà de l'autre côté |
| `pr-path-collision-advisory.yml` (deux PRs ouvertes aux chemins qui se chevauchent) | **ADAPTER (prochaine vague)** | Mécaniserait [agent-claim-discipline] : l'anti-double-claim actuel est un `gh pr list --jq 'test(...)'` manuel ; le sweep CoursIA signale les collisions de façon récurrente. Coût du statu quo : 3 implémentations parallèles de #1786 = ~12 h |
| `md-content-loss-gate.yml` (perte de contenu dans les .md — suppression non justifiée) | **ADAPTER (à étudier)** | Renforcerait [no-deletion-without-proof] : « code mort » est un label dangereux, 3 destructions du pipeline synthesis. À étudier : diff sémantique par PR vs heuristique de volume |
| `repo-size-advisory.yml` (poids du dépôt en advisory) | **IGNORER (pour l'instant)** | Le dépôt reste raisonnable ; le problème de volume connu (33,5 Go `swap.vhdx`) est machine, pas repo |
| `bash-syntax-advisory.yml` | **ADAPTER (faible priorité)** | Peu de bash ici (`scripts/hooks/*.js`, ps1 majoritairement) ; `bash -n` trivial si un jour le volume le justifie |
| `catalog-drift.yml` / `catalog-cron.yml` (régénérer un index + détecter la dérive) | **ADAPTER (à étudier)** | `docs/harness/reference/INDEX.md` est maintenu à la main — même classe doc↔arbre que le livrable 5, mais sur un index entier. Naturellement la vague 2 du drift-scan |
| `scan-md-hierarchy-drift.yml` | **IGNORER** | La hiérarchie des titres n'a pas été une source de panne ici |
| `always-on-guards.yml` (fusion de 14 organes en 1 workflow, 1 slot de runner) | **IGNORER (pour l'instant)** | La fusion répond à une famine de slots self-hosted (319 runs en file chez eux). Nous sommes sur runners GitHub-hosted — le problème n'existe pas encore ; à reconsidérer si la racine dépasse ~10 workflows |
| `base-not-main-advisory`, `stale-base-warning`, `banner-guard`, `harness-coauthor-guard`, `unique-check-run-names-guard`, `label-paths-guard`, `pip-leak-guard`, `concurrency-conj-guard`, `testpaths-coverage-guard`, `regression-guard`, `validation-matrix` | **IGNORER** | Soit couverts par GitHub (branch protection, required checks), soit par nos règles (conventional commits), soit sans objet à 4 workflows racine |

## §3 — Décision pre-commit (livrable 4)

**Décision : ADAPTER — le hook gitleaks oui, les 9 hooks locaux non.**

- **`gitleaks` épinglé `v8.24.3`** : porte le vide le plus net — `security.md` exige un
  contrôle manuel (`git diff --cached` sans pattern secret) qui ne s'exécute que si
  l'agent y pense ; GitHub secret scanning ne couvre que les motifs connus. La version
  est **la même que l'épingle CI** (parité assertée mécaniquement, cf. §2).
- **Les 9 hooks locaux CoursIA** sont du domaine notebook (strip probeAddresses, cache
  NuGet, chemins papermill, null-exec, cell-source-parses…) : ce dépôt n'a pas de
  notebooks versionnés. **Aucun n'est porté.**
- **Candidats propres à ce dépôt** (vague suivante, à arbitrer) : garde BOM (les `.ps1`
  **avec** BOM depuis #3338/#3339, le reste **sans** — l'invariant est écrit dans les
  règles globales, jamais asserté au commit) ; garde pointeur submodule au commit
  (les 4 pièges de [submod-pointer-safety.md], dont 2 incidents datés).
- **Adoption : opt-in par machine** (pre-commit exige Python ; les machines ont
  Python 3.13 mais pas pre-commit installé). Le fichier documente l'installation —
  pas de changement imposé aux 7 machines dans cette PR.

## §4 — Mesures de référence (ce jour, VERIFIÉ)

- gitleaks v8.24.3 sur l'arbre : **23 findings, 100 % bénins** (15 docs vendues
  `mcps/external/github/` avec exemples `Bearer ghp_…` en prose ; 7 fixtures de test à
  littéraux fake-key ; 1 placeholder explicite `vllm-placeholder-key-2024`).
  Constat au passage : `tests/servers/jupyter-mcp-server/config.json` porte un token
  hexadécimal 48 car. — fixture **localhost/offline**, sans valeur externe, trié
  bénin ; à remplacer par un littéral évidemment-fake si on veut le sortir de
  l'allowlist un jour.
- gitleaks v8.24.3 sur l'historique complet (4419 commits) avec allowlist : **0 finding**.
- Drift-scan doc↔tree sur `main` avant livraison : comptes 20/11/5 exacts, 26 liens
  markdown tous résolus, 3 chemins backtick dont 2 intentionnellement non-repo
  (`.claude/settings.json` « INTERDIT », `.roo/schedules.json` « JAMAIS modifier ») —
  propre, la gate peut être bloquante dès le premier jour.

## §5 — Non-buts respectés

Pas d'unification forcée : 162 vs 4 workflows racine reste majoritairement légitime
(volumes différents — 2,4 Go de contenu pédagogique vs un dépôt de harnais). Ce qui a
été porté répond à des **pannes datées de ce côté** : time-bomb du 15/09 (schedule CI),
secret-scanning manuel (gitleaks), liens CLAUDE.md non vérifiés (drift-scan). Les
candidats différés (§2) sont étayés par des incidents locaux cités, pas par l'attrait
de la symétrie.

[worktree-lifecycle.md]: ../../../.claude/rules/worktree-lifecycle.md
[agent-claim-discipline]: ../../../.claude/rules/agent-claim-discipline.md
[no-deletion-without-proof]: ../../../.claude/rules/no-deletion-without-proof.md
[submod-pointer-safety.md]: ../../../.claude/rules/submod-pointer-safety.md
