# Shell Fallback Strategy — Windows

**Version:** 1.1.0
**Issue :** #1885 (approved scope (b): doc-only, NO MCP win-cli changes) ; #2368 (pwsh absent)
**MAJ:** 2026-09-04

---

## Regle

**Si une commande echoue avec une erreur de quoting PowerShell, retenter avec gitbash.**

## pwsh absent → powershell.exe (#2368)

**`pwsh` (PowerShell 7) n'est pas present sur toutes les machines** (absent p.ex. de po-2027). Les instructions de skills/docs qui posent `pwsh -File …` y echouent net (« le terme pwsh n'est pas reconnu »).

Invoquer systematiquement via Windows PowerShell 5.1, present partout :

```powershell
powershell -ExecutionPolicy Bypass -File <script>.ps1
```

Les scripts du depot sont compatibles 5.1 depuis #3338/#3339 (BOM UTF-8 sur les ps1). Incident fondateur : pre-flight executor 04/09 sur po-2027 — `ensure-build-fresh.ps1` et `harmonize-win-cli-timeouts.ps1` documentes en `pwsh` ont echoue, reussis en `powershell`.

## Claude Code

Claude Code utilise `Bash` tool qui route vers gitbash sur Windows. **Pas de fallback necessaire.**

Si `Bash` echoue sur une commande complexe (quoting, regex), utiliser le tool `PowerShell` comme alternative.

## Roo Scheduler (win-cli)

1. **PowerShell** (defaut) → si erreur quoting → **gitbash**
2. Si les 2 echouent → fichier `.ps1`/`.sh` dans `$TEMP` + exec

## Patterns a risque

`jq` + regex, `|` multiples, backticks, `grep -E`/`sed` complexe.

## Reference

Regles detaillees : `.roo/rules/21-shell-fallback.md`
