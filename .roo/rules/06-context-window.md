# Condensation Context Window

**Version:** 4.0.0 (aligne sur .claude/rules/context-window.md v6.0.0 — le clamp universel 200k est un bug, decision user 2026-08-22)
**MAJ:** 2026-08-22

## Regle : settings.json de la machine fait foi

**La fenetre de compaction se decide dans `~/.claude/settings.json`.** Aucun script ne la
surcharge a l'execution. Il n'y a pas de valeur universelle : chaque machine configure ce que
ses modeles tiennent reellement.

Le mandat « fenetre 200 000 pour tous » (decision user 2026-05-25) est **supersede**. Les trois
scripts qui l'appliquaient (`spawn-claude.ps1`, `start-claude-worker.ps1`,
`start-claude-executor.ps1`) ne posent plus aucune variable de compaction.

## Le seul invariant : JAMAIS un pourcentage bas

`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` >= 90.

| Seuil | Resultat |
| ----- | -------- |
| 50% (defaut) | Boucle infinie (#502) |
| 70% | Boucle avec harnais lourd (#736) |
| 75% | Standard historique (#1152) |
| **>= 90%** | **Sain** — compact tardif, maximise le contexte utile |

Une **grande fenetre** n'est jamais dangereuse ; seul un **pourcentage bas** l'est. Le garde-fou
vit dans `deploy-claude-mcp-settings.ps1` (condition `< 90`), pas dans les scripts de spawn.

## Contexte reel par famille (inchange)

GLM-5 / 4.7 / 4.5 Air (z.ai) et Qwen3.6-35B (vLLM) annoncent 200k mais n'ont que **~131k en
entree** (les 200k incluent la sortie). Une machine dont le modele par defaut est GLM/Qwen a donc
de bonnes raisons de garder une fenetre de 200 000 — c'est une decision **de machine**, pas une
regle de flotte.

## Contexte Scheduler Roo

Orchestrateur-simple deleguant 4+ sous-taches -> souvent saturation. Si la tache s'arrete avant
rapport -> saturation contexte (#1032).

---
**Reference canonique :** `.claude/rules/context-window.md` v6.0.0. **Historique complet :** Git history.
