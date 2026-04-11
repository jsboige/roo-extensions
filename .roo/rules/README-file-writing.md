# File Writing Patterns - Guide des Fichiers

## Structure des fichiers d'écriture

### .claude/rules/file-writing.md
Pour **Claude Code** (agent principal)
- Patterns généraux d'écriture de fichiers
- Sélection des outils (Edit vs Write)
- Contraintes générales
- Encodage UTF-8 no-BOM

### .roo/rules/file-writing-qwen.md
Pour **Roo Code** (modes -simple avec Qwen 3.5)
- Limitation spécifique à Qwen 3.5
- Règle des 200 lignes maximum
- Alternatives spécifiques
- Fallback win-cli

## Pourquoi deux fichiers ?

Les deux agents ont des contraintes différentes:
- **Claude Code**: Utilise Opus 4.6, pas de limitation de taille
- **Roo -simple**: Utilise Qwen 3.5, limitation stricte de 200 lignes

## Bonnes pratiques

1. **Pour Claude Code**: Utiliser `Write` pour les nouveaux fichiers, `Edit` pour les modifications
2. **Pour Roo -simple**: Toujours vérifier la longueur, utiliser `replace_in_file` pour les gros fichiers
3. **Pour les deux**: Toujours utiliser UTF-8 no-BOM

---
**Créé:** 2026-04-11
**Objectif:** Clarifier la séparation des préoccupations entre les deux agents