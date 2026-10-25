# Harnais — règles du 15/09 (settings.json serré)

**Issue :** #3657 (mandat user 15/09) — appliqué à `settings.json` sur ai-01, propagé
flotte. Les trois conséquences opérationnelles ci-dessous sont auto-chargées dans
chaque workspace ; tableau de drapeaux, mesures de référence et incidents fondateurs :
[`docs/harness/global-rules-detail.md`](../../docs/harness/global-rules-detail.md) §« Harnais serré ».

## 1. Zéro question bloquante — registre persistant

Toute question **non bloquante** vit dans un **registre persistant** : une entrée
n'en sort **que sur réponse user** — jamais auto-expirée, jamais silencieusement
retirée. Une question non bloquante n'arrête jamais l'exécution : on continue, on
tient la question ouverte, on attend la réponse quand l'user peut. Le registre est
**représenté à chaque fin de session** (cron, interactive coord/worker).
**Ne pas contourner** les outils deny (`AskUserQuestion`, plan-mode) : une décision
qui exige l'user va au registre, une décision tranchable se tranche et se consigne.

## 2. Notebooks — `jupyter-papermill` MCP maison uniquement

`NotebookEdit` est deny. Toute édition de notebook passe par **`jupyter-papermill`**
(chargé en différé par le tool search, activé au besoin via `~/.claude.json`).
**Pas de fallback** sur `NotebookEdit` ni sur édition manuelle du JSON (outputs
base64, cell IDs, kernelspecs — piégeux). Si le MCP ne peut pas être activé sur la
machine : question au registre, pas d'édition.

**Le prérequis de provisioning se vérifie, il ne se présume pas (#4340)** : incident
po-2027 24/10 — repli jamais provisionné, rien détecté pendant des semaines, fallback
interdit normalisé (bytesplice JSON). Au démarrage d'une session d'un siège où
`NotebookEdit` est deny : `python <roo-extensions>/scripts/diagnostic/check-deny-fallback.py --workspace <ws>`
— sonde **handshake** (jamais les drapeaux : `disabled: true` est inert sur un siège
Claude Code). Échec = capacité notebook **BLOQUÉE** (jamais de workaround) + entrée
registre ; le provisioning est une décision par workspace. Câblage canonique UNIQUE :
`.mcp.json` local du workspace (gitignoré) + install editable dans le venv + entrée
`{"type":"stdio","command":"<venv-python>","args":["-m","papermill_mcp.main"]}` sans
drapeau. Détail : [`deny-fallback-probe.md`](../../docs/harness/reference/deny-fallback-probe.md).

## 3. Harnais maigre — `ENABLE_TOOL_SEARCH` + drapeaux de réduction

Les drapeaux (`ENABLE_TOOL_SEARCH`, `disableBundledSkills`,
`disableClaudeAiConnectors`, `disableRemoteControl`) réduisent le contexte payé par
requête ; tableau d'effets et mesure de référence (#99 : ~105 k tokens/requête dont
~64 % de définitions MCP inline) dans le détail déporté. **À mesurer par lane** —
pas de chiffre canon flotte, le gain dépend des MCPs effectivement chargés.
