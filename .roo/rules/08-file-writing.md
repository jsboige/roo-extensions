# Regle d'ecriture de fichiers - Limitation Qwen 3.5

**Version:** 2.0.0 (condensed from 1.0.0, aligned with .claude/rules/file-writing.md)
**MAJ:** 2026-04-08

## Regle

**NE JAMAIS utiliser `write_to_file` pour un fichier de plus de 200 lignes.**

Qwen 3.5 (mode -simple) tronque sa sortie avant d'avoir genere le contenu complet.

## Alternatives

| Situation | Outil |
| --------- | ----- |
| Ajouter en fin de fichier | `apply_diff` ou win-cli `Add-Content` |
| Modifier une section | `apply_diff` ou `replace_in_file` |
| Recrire fichier volumineux | `replace_in_file` par sections |
| Nouveau fichier <200 lignes | `write_to_file` OK |

## Condensation fichiers volumineux (>800 lignes)

1. Lire le fichier, identifier zone ancienne vs recente
2. `replace_in_file` pour remplacer zone ancienne par resume condense
3. **NE JAMAIS** recrire tout le fichier

## Fallback win-cli

```powershell
Add-Content -Path 'fichier.md' -Value 'contenu'
[System.IO.File]::WriteAllText('fichier.md', $content, [System.Text.UTF8Encoding]::new($false))
```

## Applicabilite

Tous modes -simple (Qwen 3.5). Bonne pratique pour -complex (GLM-5) aussi.

---
**Historique versions completes :** Git history avant 2026-04-08
