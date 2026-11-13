# Roo Extensions — le harnais d'une flotte d'agents de développement

**État décrit :** 13 novembre 2026 · **Suivi du travail :** [Project #67](https://github.com/users/jsboige/projects/67) · **Licence :** MIT

Ce dépôt est le harnais de travail d'une flotte réelle : des agents Claude Code répartis sur
plusieurs machines, qui se coordonnent sans serveur d'orchestration, par des tableaux de bord et
une messagerie partagés. Il contient les règles que ces agents chargent, les commandes et skills
qu'ils exécutent, les scripts qui les planifient et les contrôlent, et le serveur MCP qui porte
leur coordination.

Ce n'est pas un produit clé en main. C'est un système en service, documenté pour ceux qui y
travaillent — humains, agents de la flotte, et sessions d'assistance qui n'en font pas partie.

---

## Par où commencer

| Vous êtes | Lisez d'abord |
|---|---|
| Un humain qui découvre le système | [`docs/harness/HARNESS-OVERVIEW.md`](docs/harness/HARNESS-OVERVIEW.md) — ce que le harnais fait, avec quoi, et pourquoi |
| Un agent Claude Code sur une machine de la flotte | [`CLAUDE.md`](CLAUDE.md), puis les règles de [`.claude/rules/`](.claude/rules/) (chargées automatiquement) |
| Une session cloud ou hors flotte, sans MCP ni mémoire locale | [`docs/harness/reference/off-fleet-cloud-sessions.md`](docs/harness/reference/off-fleet-cloud-sessions.md) |
| À la recherche d'un document précis | [`docs/harness/reference/INDEX.md`](docs/harness/reference/INDEX.md) — l'index de toute la documentation |
| Sur le point de conclure d'une mesure, d'approuver une PR ou d'écrire un script pour la flotte | La section « Leçons de terrain » du même index |

---

## Ce que fait le système

- **Une flotte, un coordinateur.** Une machine coordonne : elle relit et merge les PR, arbitre
  les collisions, distribue le travail. Les autres exécutent : elles prennent une issue,
  produisent une PR, rapportent. Personne n'approuve sa propre PR.
- **Pas de serveur central.** La coordination passe par des tableaux de bord partagés
  (`global`, `machine`, `workspace`) et une messagerie entre machines — l'ensemble s'appelle
  RooSync. Le serveur MCP `roo-state-manager`, lancé localement par chaque agent, lit et écrit ce
  magasin partagé.
- **Le travail vit sur GitHub.** Les issues portent les tâches et leur verrou (le claim), les PR
  portent le résultat, le Project #67 donne la vue d'ensemble.
- **Des cycles, pas un service.** Chaque agent est réveillé par un cron de session ou une tâche
  planifiée Windows, exécute un cycle, écrit son bilan, et s'arrête.

**La flotte au 13/11/2026 : 9 machines** — un coordinateur (`myia-ai-01`), six exécutants
(`myia-po-2023` à `myia-po-2028`, dont `myia-po-2027` en Claude seul) et deux sièges web
(`myia-web1`, `myia-web2`). La liste qui fait foi, avec le rôle de chaque machine et la date de
sa dernière vérification, est [`.claude/configs/fleet-manifest.json`](.claude/configs/fleet-manifest.json).

**Zoo Code** a succédé à Roo Code, dont le dépôt garde le nom. Cette extension VS Code servait
d'agent compagnon planifié, avec ses modes (`roo-config/`). Son scheduler est désactivé sur toute
la flotte depuis le 8 novembre 2026 ; les modes et leur générateur restent dans le dépôt.

---

## Ce que contient le dépôt

```
.claude/
  rules/            règles chargées à chaque conversation
  commands/         commandes (/coordinate, /executor, ...)
  skills/           skills (sync-tour, validate, pr-review, ...)
  agents/           sous-agents du projet
  configs/          configuration globale à déployer sur chaque machine, manifeste de flotte
docs/harness/
  HARNESS-OVERVIEW.md      la vue d'ensemble
  reference/               documentation à la demande (INDEX.md en est l'entrée)
  coordinator-specific/    politique de review, cycle du coordinateur
  adr/                     décisions d'architecture
mcps/
  internal/         sous-module : roo-state-manager (TypeScript), sk-agent (Python)
  external/         serveurs MCP tiers et forks
roo-config/         modes de l'extension compagnon et leur générateur
scripts/
  scheduling/       tâches planifiées, workers, gardes
  github/           claim d'issue, review et merge
  diagnostic/       sondes : MCP du siège, escalades, manifeste
  mcp/              validation avant push
  testing/          suites Pester et Python des scripts
roo-code/, zoo-code/   sous-modules : sources des deux extensions (roo-code : référence de lecture, pas un environnement de build)
```

Les comptes (règles, agents, skills, outils) ne sont pas recopiés ici : ils dérivent. Ceux que
le dépôt garde sous contrôle sont dans [`CLAUDE.md`](CLAUDE.md), et un test les recompte à
chaque push.

---

## Les serveurs MCP

`roo-state-manager` est le seul serveur requis sur chaque siège. Il expose 18 outils : tableaux
de bord et messagerie, inventaire et comparaison de configuration, navigation dans l'historique
des conversations, recherche sémantique dans le code et les tâches, diagnostic. La section 2 de
[`HARNESS-OVERVIEW.md`](docs/harness/HARNESS-OVERVIEW.md) les décrit un par un.

Les autres serveurs (automatisation web, recherche web, agents locaux, notebooks) sont
autorisés, pas requis. L'inventaire, ce qui est critique pour qui, et la conduite à tenir quand
un outil manque sont dans [`.claude/rules/tool-availability.md`](.claude/rules/tool-availability.md).

---

## Installer un siège

Ces étapes décrivent une machine de la flotte. Hors flotte, le magasin partagé n'est pas
accessible : suivre plutôt le [protocole des sessions hors flotte](docs/harness/reference/off-fleet-cloud-sessions.md).

**Prérequis :** Windows avec Windows PowerShell 5.1 (les scripts du dépôt y tournent ;
PowerShell 7 n'est pas présent sur toutes les machines), Node.js 20 ou 22 (les deux versions
testées en CI), Python 3, Git, GitHub CLI (`gh`), Claude Code.

1. **Cloner avec les sous-modules.**
   ```bash
   git clone https://github.com/jsboige/roo-extensions.git
   cd roo-extensions
   git submodule update --init --recursive
   ```

2. **Construire le serveur MCP.**
   ```bash
   cd mcps/internal/servers/roo-state-manager
   npm install
   npm run build
   ```

3. **Le déclarer dans `~/.claude.json`**, section `mcpServers` :
   ```json
   {
     "mcpServers": {
       "roo-state-manager": {
         "command": "node",
         "args": ["<dépôt>/mcps/internal/servers/roo-state-manager/mcp-wrapper.cjs"],
         "env": { "ROOSYNC_SHARED_PATH": "<chemin du magasin partagé>" }
       }
     }
   }
   ```

4. **Déployer la configuration globale** depuis la racine du dépôt, à blanc d'abord :
   ```powershell
   powershell -ExecutionPolicy Bypass -File .claude\configs\scripts\Deploy-GlobalConfig.ps1 -DryRun
   ```
   La sortie liste ce qui serait copié vers `~/.claude/` et ce qui serait changé dans
   `settings.json`. Relancer sans `-DryRun`, avec `-Target` pour limiter le déploiement à une
   partie (`claude-md`, `rules`, `agents`, `skills`, `commands`, `settings`).

5. **Vérifier le siège.**
   ```bash
   python scripts/diagnostic/verify-fleet-manifest.py
   ```

Quand un serveur MCP ne se charge pas, la procédure est dans
[`.claude/rules/mcp-diagnosis.md`](.claude/rules/mcp-diagnosis.md) et son
[détail](docs/harness/reference/mcp-diagnosis-procedure.md). « Redémarrer et voir » n'en fait pas partie.

---

## Travailler dans le dépôt

- **Aucune écriture directe sur `main`.** Worktree, branche, PR, review, squash-merge :
  [`.claude/rules/pr-mandatory.md`](.claude/rules/pr-mandatory.md). GitHub exige une review
  approbatrice d'un autre compte que l'auteur.
- **Poser le verrou sur l'issue avant de coder.**
  ```bash
  python scripts/github/check_issue_claim.py <N>                     # exit 1 : une autre lane tient l'issue
  python scripts/github/check_issue_claim.py <N> --claim "intention en une ligne"
  ```
  Détail : [`.claude/rules/agent-claim-discipline.md`](.claude/rules/agent-claim-discipline.md).
- **Tester avant de pousser.** Depuis la racine : `npm run test:mcp`. Avant un push dans le
  sous-module : `scripts\mcp\validate-before-push.ps1`. Ne pas lancer `npx vitest run` à la
  racine ni `npm test` (mode watch). Détail : [`.claude/rules/ci-guardrails.md`](.claude/rules/ci-guardrails.md).
- **Sous-module d'abord.** Un changement dans `mcps/internal` se commite et se pousse dans le
  sous-module, sa PR se merge, puis le pointeur du dépôt parent avance :
  [`.claude/rules/submod-pointer-safety.md`](.claude/rules/submod-pointer-safety.md).
- **Pas de secret dans un commit.** Un scan tourne sur chaque push :
  [`.claude/rules/security.md`](.claude/rules/security.md).
- **Un agent n'ouvre pas d'issue sans l'accord du mainteneur**
  ([`issue-creation.md`](.claude/rules/issue-creation.md)), et ne ferme une issue qu'avec sa
  preuve ([`issue-closure.md`](.claude/rules/issue-closure.md)).

---

## Licence

MIT — voir [`LICENSE`](LICENSE).
