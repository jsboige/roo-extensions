# Shell Fallback Strategy — Windows

**Version:** 1.0.0
**Issue :** #1885 (approved scope (b): doc-only, NO MCP win-cli changes)
**MAJ:** 2026-05-01

---

## Regle

**Si une commande echoue avec une erreur de quoting PowerShell, retenter avec gitbash.**

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
