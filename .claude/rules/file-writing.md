# File Writing Patterns - Claude Code

**Version:** 2.0.0 (condensed from 1.0.0)
**MAJ:** 2026-04-05

## Tool Selection

| Situation | Tool | Note |
|-----------|------|------|
| Modifier fichier existant | `Edit` | `Read` d'abord. Prefere. |
| Creer nouveau fichier | `Write` | `Read` d'abord si existe. |
| Ajouter contenu | `Edit` (remplacer dernier bloc par bloc+nouveau) | Jamais `Write` (ecrase). |

## Contraintes

- **Edit necessite Read prealable** — echoue sinon, meme pour `replace_all`
- **Edit old_string doit etre unique** — contexte suffisant. `replace_all` pour renommages
- **Write ecrase tout** — jamais sur fichier existant sans Read + preservation

## Encodage

`Edit`/`Write` : UTF-8 no-BOM automatique. Si PowerShell : `[System.IO.File]::WriteAllText()` avec UTF8Encoding(`$false`).

## INTERCOM (append-only)

1. **Read** le fichier
2. **Edit** le dernier separateur `---` → remplacer par `---` + nouveau message + `---`
3. **Jamais** inserer en haut. **Jamais** ecraser avec Write.

## Backup

Si remplacement >50% du contenu : considerer `Write` (plus sur que `Edit` partiel). Verifier apres ecriture.
