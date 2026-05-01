# Shell Fallback Strategy — Windows

**Version:** 1.0.0
**Issue :** #1885 (approved scope (b): doc-only, NO MCP win-cli changes)
**MAJ:** 2026-05-01

---

## Regle

**Si une commande echoue avec une erreur de quoting PowerShell, retenter automatiquement avec gitbash.**

## Contexte

PowerShell (5.1/7) traite differemment les caracteres speciaux par rapport a bash :
- `\\` dans les strings → `unexpected token`
- `|` multiples → interprete comme pipeline PowerShell
- Backticks `` ` `` → caractere d'echappement PowerShell (pas bash)
- `jq` avec regex → conflits d'echappement

**Evidence :** Dispatch #1848 (2026-04-30) — 3 echecs PowerShell consecutifs pour `jq` avec `\\[DISPATCH\\]`, resolu en switchant vers gitbash.

## Patterns a risque

Declencher le fallback si la commande contient :

| Pattern | Risque |
|---------|--------|
| `jq` + regex avec `\\` | Echappement PowerShell |
| Plus de 2 `\|` | Pipeline interprete |
| Backticks dans arguments | Escape PowerShell |
| `grep -E` ou `sed` complexe | Syntaxe incompatible |

## Procedure

### Claude Code (Bash tool)

Claude Code utilise deja gitbash nativement via le tool `Bash`. **Pas de fallback necessaire** — gitbash est le shell par defaut.

### Roo Scheduler (win-cli MCP)

1. **Tentative PowerShell** (shell par defaut win-cli) : `execute_command(shell="powershell", command="...")`
2. **Si exit code != 0 ET** erreur contient `"unexpected token"` OU `"pipe"` OU `"parsing"` :
   - Retenter avec gitbash : `execute_command(shell="gitbash", command="...")`
3. **Logger** le fallback pour tracabilite

### Manual Fallback (intervention humaine)

Si les 2 shells echouent :
1. Ecrire la commande dans un fichier `.ps1` ou `.sh` dans `$TEMP`
2. Executer le fichier au lieu de la commande inline
3. Cette approche evite tous lesproblemes de quoting

## Anti-patterns

- **NE PAS** modifier le MCP win-cli (scope approuve = doc-only)
- **NE PAS** ajouter de detection automatique dans le code MCP
- **NE PAS** default to gitbash pour tout — PowerShell reste le shell principal (compatibilite cmdlets Windows)

## Quand signaler

Si le fallback gitbash echoue aussi → signaler friction via dashboard `[FRICTION]` avec commande exacte + erreurs des 2 shells.
