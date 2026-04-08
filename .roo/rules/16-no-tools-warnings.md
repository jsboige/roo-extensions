# Warnings NoTools - conversation_browser

**Version:** 2.0.0 (condensed from 1.1.0, aligned with .claude/rules/conversation-browser-guide.md)
**MAJ:** 2026-04-08

## Fix #881 applique

`detailLevel: "NoTools"` est maintenant un **alias vers Compact** (resume outils : nom + statut, pas contenu). Le probleme d'explosion est RESOLU.

## Regle d'or

**TOUJOURS definir `truncationChars`** quand `summarize_type != "trace"`.

## Niveaux detailLevel

| Niveau | Recommandation |
| ------ | -------------- |
| `Summary` | Recommande |
| `Compact` / `NoTools` | Recommande (NoTools = alias Compact) |
| `Messages` / `UserOnly` | Compact |
| `Full` | **JAMAIS** (explosion) |

## Usage

`summarize_type: "trace"` = stats lisibles (messages par type, taille, breakdown). Utiliser pour rapports metriques.

---
**Historique versions completes :** Git history avant 2026-04-08
