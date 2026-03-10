# Règle d'écriture de fichiers - Limitation Qwen 3.5

**Version:** 1.0.0
**Créé:** 2026-03-10
**Contexte:** Le modèle Qwen 3.5 (utilisé en mode -simple) ne peut pas générer le paramètre `content` de `write_to_file` pour les fichiers volumineux (>200 lignes). Erreur typique : "write_to_file without value for required parameter 'content'".

---

## Règle Principale

**NE JAMAIS utiliser `write_to_file` pour un fichier de plus de 200 lignes.**

Le modèle tronque sa sortie avant d'avoir généré le contenu complet, ce qui produit un appel sans paramètre `content`.

---

## Alternatives par cas d'usage

| Situation | Outil à utiliser | Exemple |
|-----------|-----------------|---------|
| **Ajouter du contenu en fin de fichier** | `apply_diff` ou win-cli `Add-Content` | Ajouter un message INTERCOM |
| **Modifier une section existante** | `apply_diff` ou `replace_in_file` | Corriger un bloc de code |
| **Réécrire un fichier volumineux** (condensation) | Découper en étapes : `replace_in_file` par sections | Condensation INTERCOM |
| **Créer un nouveau petit fichier** (<200 lignes) | `write_to_file` OK | Rapport, script court |

---

## Stratégie pour la condensation INTERCOM

La condensation d'un fichier INTERCOM >800 lignes nécessite une approche par étapes :

1. **Lire le fichier** avec `read_file` (noter le nombre de lignes)
2. **Identifier la zone à condenser** (messages anciens) et la zone à garder (messages récents)
3. **Utiliser `replace_in_file`** pour remplacer la zone ancienne par un résumé condensé
   - Chercher un marqueur unique (ex: le premier `## [date]` ancien)
   - Remplacer par le résumé + marqueur de fin
4. **NE JAMAIS tenter de réécrire tout le fichier** avec `write_to_file`

### Exemple concret

```
# MAUVAIS — va échouer avec Qwen 3.5 :
write_to_file(path=".claude/local/INTERCOM-myia-ai-01.md", content="...1500 lignes...")

# BON — modification ciblée :
replace_in_file(
  path=".claude/local/INTERCOM-myia-ai-01.md",
  old_str="## [2026-03-01 ...ancien contenu...]## [2026-03-09",
  new_str="## Résumé condensé (2026-03-01 à 2026-03-08)\n...résumé...\n\n## [2026-03-09"
)
```

---

## Fallback win-cli

Si `apply_diff` et `replace_in_file` échouent tous les deux, utiliser win-cli :

```powershell
# Ajouter du contenu à la fin d'un fichier
execute_command(shell="powershell", command="Add-Content -Path '.claude/local/INTERCOM-myia-ai-01.md' -Value 'contenu'")

# Écrire un fichier complet (avec PowerShell)
execute_command(shell="powershell", command="[System.IO.File]::WriteAllText('.claude/local/INTERCOM-myia-ai-01.md', $content, [System.Text.UTF8Encoding]::new($false))")
```

---

## Applicabilité

Cette règle s'applique à :
- **Tous les modes `-simple`** (Qwen 3.5 local)
- **Les modes `-complex`** (GLM-5) : moins critique mais bonne pratique
- **Tout fichier >200 lignes** : INTERCOM, JOURNAL, rapports, documentation

---

**Dernière mise à jour:** 2026-03-10
