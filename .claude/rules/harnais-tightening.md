# Harnais — règles du 15/09 (settings.json serré)

**Version:** 1.2.0 (doublon résolu — le corps canonique vit dans la source globale, claudish#445)
**Issue :** #3657 (mandat user 15/09)

**Corps canonique :** [`.claude/configs/rules/harnais-tightening.md`](../../.claude/configs/rules/harnais-tightening.md) — déployé en règle **globale** (`~/.claude/rules/`, chargée dans tous les workspaces) par `.claude/configs/scripts/Deploy-GlobalConfig.ps1`. Détail, mesures et incidents : [`docs/harness/global-rules-detail.md`](../../docs/harness/global-rules-detail.md).

Les trois règles, en une ligne chacune (corps complet dans la source ci-dessus) :

1. **Zéro question bloquante** — `EnterPlanMode` / `ExitPlanMode` / `DesignSync` / `AskUserQuestion` deny ; toute question non bloquante vit dans un **registre persistant**, représenté à chaque fin de session ; elle n'arrête jamais l'exécution, et les outils deny ne se contournent pas.
2. **Notebooks** — `NotebookEdit` deny ; édition/exécution via le MCP **`jupyter-papermill`** uniquement, activé au besoin ; **pas de fallback** manuel — MCP indisponible → question au registre, pas d'édition. **Le provisioning se vérifie par sonde handshake au démarrage (#4340)** : `scripts/diagnostic/check-deny-fallback.py` — échec = capacité BLOQUÉE (jamais de workaround), câblage canonique et détail : [`deny-fallback-probe.md`](../../docs/harness/reference/deny-fallback-probe.md).
3. **Harnais maigre** — `ENABLE_TOOL_SEARCH: "true"` (schémas MCP payés en différé) + `disableBundledSkills` + `disableClaudeAiConnectors` + `disableRemoteControl` ; chaque lane mesure son propre delta.

Cette copie projet sert les sièges où la règle globale n'est **pas déployée** : la source ci-dessus fait foi à l'identique — la lire en cas de doute.
