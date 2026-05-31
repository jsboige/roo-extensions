# Regle d'ecriture de fichiers - Limitation Qwen 3.5

**Version:** 2.1.1 (divergence intentionnelle vs `~/.claude/rules/file-writing.md` — sync #1285 ; chemin mis à jour #2368 dedup)
**MAJ:** 2026-05-31

> **Note divergence intentionnelle** : Ce fichier (.roo) traite des limitations Qwen 3.5 (`write_to_file` >200 lignes troncature). Le pendant Claude Code, désormais déporté en global `~/.claude/rules/file-writing.md` (source `.claude/configs/rules/file-writing.md`), traite de la sélection Edit/Write/Read générique pour Claude Code. **Les contenus diffèrent par design** car les contraintes des deux agents diffèrent. Ne PAS proposer harmonisation — voir `.claude/rules/meta-analyst.md` HARD REJECT.

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
