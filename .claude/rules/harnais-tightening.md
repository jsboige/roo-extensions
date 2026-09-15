# Harnais — règles du 15/09 (settings.json serré)

**Version:** 1.0.0
**Issue :** #3657 (mandat user 15/09)
**Source :** décision user appliquée à `settings.json` sur ai-01 dans la nuit du 15/09,
propagée flotte via l'ordre jsboige/claudish.

Trois règles opérationnelles découlent de cette passe. Elles sont **denses par session**
(auto-chargées dans chaque workspace via `.claude/rules/*.md`) — le détail et les incidents
fondateurs vivent dans [`docs/harness/global-rules-detail.md`](../../docs/harness/global-rules-detail.md)
pour ne pas gonfler le contexte utile.

---

## 1. Zéro question bloquante — registre persistant

`settings.json` deny `EnterPlanMode`, `ExitPlanMode`, `DesignSync`, `AskUserQuestion` ;
`mode: auto-approve`, `outputStyle: Proactive`.

**Conséquence opérationnelle.** Toute question ou askuser **non bloquante** vit dans un
**registre persistant de questions ouvertes** : un fichier dédié, plus un scratchpad à
présenter à l'user si la question a du matériel. Une entrée n'en sort **que sur réponse
user** — jamais auto-expirée, jamais silencieusement retirée.

- Le registre est **représenté à chaque fin de session de cron** (et à chaque fin de session
  interactive coord/worker). Une question ne disparaît pas entre deux tours.
- Une question non bloquante **n'arrête jamais l'exécution** : on continue, on tient la
  question ouverte, on attend la réponse quand l'user peut.
- Côté coordinateur claudish, le registre et le runbook sont armés (jsboige/claudish#111) :
  Phase 5 consigne, Phase 6 représente. Sur les autres workspaces, le réflexe est le même
  (append `[ASK]` sur le dashboard workspace + tenue d'un fichier `open-questions.md`
  dans le projet si la question concerne plusieurs sessions).
- **Ne pas contourner** les outils deny (plan-mode/AskUserQuestion). Si une décision a besoin
  d'un arbitrage user, elle va au registre et on avance ; si elle peut se trancher seul, on
  tranche et on consigne.

## 2. Notebooks — `jupyter-papermill` MCP maison uniquement

`NotebookEdit` est deny dans `settings.json`. Toute édition de notebook passe par
**`jupyter-papermill`** (MCP maison), **activé au besoin** :

- Pas de chargement par défaut nécessaire : le tool search de Claude Code charge le MCP en
  différé quand un agent en a l'usage.
- Si l'agent doit éditer ou exécuter un `.ipynb` et que le MCP n'est pas actif, l'activer
  (cf. procédure standard `~/.claude.json`) avant de manipuler le notebook.
- **Pas de fallback** sur `NotebookEdit` ou sur une édition manuelle du JSON du notebook
  (la structure est piégeuse : outputs base64, cell IDs, kernelspecs). Si le MCP ne peut
  pas être activé sur la machine, **poser la question au registre** et ne pas éditer.

## 3. Harnais maigre — `ENABLE_TOOL_SEARCH` + drapeaux de réduction

`settings.json` pose les drapeaux suivants, tous orientés **coût de contexte par requête** :

| Drapeau | Effet |
|---|---|
| `ENABLE_TOOL_SEARCH: "true"` | Outils MCP chargés **en différé** : les schémas ne sont pas payés inline à chaque requête. Débloque ce qui était impossible avec un `ANTHROPIC_BASE_URL` custom (les définitions inline étaient figées au démarrage). |
| `disableBundledSkills` | Désactive les skills bundled par défaut (non présents dans ce projet) ; évite qu'ils soient proposés en doublon des skills projet. |
| `disableClaudeAiConnectors` | Coupe les connecteurs Claude.ai distants injectés automatiquement (voir aussi `~/.claude.json` → `claudeAiMcpEverConnected`). |
| `disableRemoteControl` | Bloque l'ouverture automatique du navigateur à chaque nouvel artefact. |

**Mesure de référence (#99 du 13/09)** : ~105 k tokens/requête dont ~64 % de **définitions
MCP inline pour 0,4 % d'appels**. Le différé `ENABLE_TOOL_SEARCH` est ce qui rend les
définitions **non payées** tant qu'elles ne sont pas effectivement appelées.

**À mesurer par lane.** ai-01 a observé **~70 outils passés en différé**. Chaque lane
doit mesurer son propre delta (taille de harnais avant/après l'activation du drapeau) et
le consigner — pas de chiffre canon flotte, le gain dépend des MCPs effectivement chargés.

---

**Convention d'écriture** : la règle succincte vit ici, la matrice complète et les
incidents fondateurs vivent dans le détail déporté. Tout ajout suit le format établi
(`Security.md`, `CI-Guardrails.md`).
