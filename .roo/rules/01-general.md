# Roo Extensions - Guide pour Agents Roo Code

**Version:** 2.0.0 (condensed from 1.0.0, aligned with .claude/rules/)
**MAJ:** 2026-04-08

## Hierarchie

- **Claude Code** (Opus 4.6) : Cerveau principal, technique ET coordination
- **Roo Code** (toi) : Assistant polyvalent (Qwen 3.5/-simple, GLM-5/-complex)

**Machines :** `myia-ai-01`, `myia-po-2023/24/25/26`, `myia-web1`

## Structure depot

- `mcps/internal/` — Submodule Git (MCPs internes). Build : `npm run build`. Tests : `npx vitest run`
- `roo-config/` — Configuration Roo (modes, scripts, settings)
- `.roo/rules/` — Regles Roo specifiques au workspace
- `.claude/` — Configuration Claude Code

## Environnement partage

Meme workspace que Claude Code. Etat git partage. Coordonner via dashboard si conflit de fichiers.

**Modes pour `new_task` :** `code-simple/complex`, `debug-simple/complex`, `architect-simple/complex`, `ask-simple/complex`, `orchestrator-simple/complex`. JAMAIS les modes natifs.

## Ton role

- Code simple/moyen, fixes, tests, build, scripts, investigation
- **Contacter Claude** : avant issue GitHub, decision architecturale, bloque >30 min, fin de consolidation

## Commits

```
type(scope): description
Co-Authored-By: Roo Code <noreply@roocode.com>
```

## Workflow

1. **Debut** : `git pull`, lire dashboard, identifier tache
2. **Pendant** : Commits frequents, tests reguliers, dashboard si blocage
3. **Fin** : Tests passent, validation checklist, commit, dashboard `[DONE]`, push

---
**Historique versions completes :** Git history avant 2026-04-08
