# Harnais — règles du 15/09 (settings.json serré)

**Version:** 1.1.0 (slim — compléments relocalisés, #2368)
**Issue :** #3657 (mandat user 15/09)
**Source :** décision user appliquée à `settings.json` sur ai-01 dans la nuit du 15/09, propagée flotte via l'ordre jsboige/claudish.

Trois règles opérationnelles découlent de cette passe, **denses par session** (auto-chargées) — le détail, les mesures et les incidents fondateurs vivent dans [`docs/harness/global-rules-detail.md`](../../docs/harness/global-rules-detail.md).

---

## 1. Zéro question bloquante — registre persistant

`settings.json` deny `EnterPlanMode`, `ExitPlanMode`, `DesignSync`, `AskUserQuestion` ; `mode: auto-approve`, `outputStyle: Proactive`.

**Conséquence opérationnelle.** Toute question ou askuser **non bloquante** vit dans un **registre persistant de questions ouvertes** : un fichier dédié, plus un scratchpad à présenter à l'user si la question a du matériel. Une entrée n'en sort **que sur réponse user** — jamais auto-expirée, jamais silencieusement retirée.

- Le registre est **représenté à chaque fin de session** (cron et interactive coord/worker). Une question ne disparaît pas entre deux tours.
- Une question non bloquante **n'arrête jamais l'exécution** : on continue, on tient la question ouverte, on attend la réponse quand l'user peut.
- Réflexe sur tout workspace : append `[ASK]` sur le dashboard + tenue d'un fichier `open-questions.md` dans le projet si la question concerne plusieurs sessions. (Armement claudish Phase 5/6 : doc détaillé.)
- **Ne pas contourner** les outils deny (plan-mode/AskUserQuestion). Si une décision a besoin d'un arbitrage user, elle va au registre et on avance ; si elle peut se trancher seul, on tranche et on consigne.

## 2. Notebooks — `jupyter-papermill` MCP maison uniquement

`NotebookEdit` est deny dans `settings.json`. Toute édition de notebook passe par **`jupyter-papermill`** (MCP maison), **activé au besoin** (le tool search le charge en différé à l'usage) :

- Si l'agent doit éditer ou exécuter un `.ipynb` et que le MCP n'est pas actif, l'activer (cf. procédure standard `~/.claude.json`) avant de manipuler le notebook.
- **Pas de fallback** sur `NotebookEdit` ou sur une édition manuelle du JSON du notebook (structure piégeuse : outputs base64, cell IDs, kernelspecs). Si le MCP ne peut pas être activé sur la machine, **poser la question au registre** et ne pas éditer.

## 3. Harnais maigre — `ENABLE_TOOL_SEARCH` + drapeaux de réduction

`settings.json` pose les drapeaux suivants, tous orientés **coût de contexte par requête** :

| Drapeau | Effet |
|---|---|
| `ENABLE_TOOL_SEARCH: "true"` | Outils MCP chargés **en différé** : les schémas ne sont pas payés inline à chaque requête. |
| `disableBundledSkills` | Désactive les skills bundled par défaut ; évite les doublons des skills projet. |
| `disableClaudeAiConnectors` | Coupe les connecteurs Claude.ai distants injectés automatiquement. |
| `disableRemoteControl` | Bloque l'ouverture automatique du navigateur à chaque nouvel artefact. |

**À mesurer par lane** : chaque lane mesure son propre delta (taille de harnais avant/après activation du drapeau) et le consigne — pas de chiffre canon flotte, le gain dépend des MCPs chargés. (Mesure de référence #99 et observation ai-01 : doc détaillé.)

---

**Convention d'écriture** : la règle succincte vit ici, la matrice complète, les mesures et les incidents fondateurs vivent dans le détail déporté. Tout ajout suit le format établi (`Security.md`, `CI-Guardrails.md`).
