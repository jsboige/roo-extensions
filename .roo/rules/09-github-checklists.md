# Checklists GitHub - Roo Code

**Version:** 1.0.0
**MAJ:** 2026-04-08

## Regle

**REGLE ABSOLUE : NE JAMAIS fermer une issue avec un tableau vide ou incomplet.**

Les tableaux de validation dans les issues GitHub sont la **source de verite** pour l'etat des taches multi-machines.

## Checklist OBLIGATOIRE

### AVANT de commencer une tache issue GitHub

1. **Lire le tableau** dans le corps de l'issue
2. **Identifier** les cases a cocher pour ta machine
3. **Comprendre** les criteres de validation

### PENDANT l'execution

1. **Cocher AU FUR ET A MESURE** chaque case validee via `gh issue edit`
2. **Commenter** l'issue pour documenter l'avancement
3. **NE JAMAIS attendre la fin** pour tout mettre a jour

### AVANT de fermer une issue

1. **Verifier** que 100% des cases sont cochees
2. **LIRE** le tableau pour confirmer qu'aucune case n'est vide (`⬜`)
3. Si des cases sont vides : **NE PAS FERMER** → relancer les machines concernees

## Format Tableau

Remplacer `⬜` par `✅` AU FUR ET A MESURE :

```markdown
| Machine | Build | Tests | Validation |
|---------|-------|-------|------------|
| myia-ai-01 | ⬜ | ⬜ | ⬜ |
```

## Communication avec Claude

Si tu termines ta partie d'un tableau, informe Claude via INTERCOM :

```markdown
## [DATE] roo -> claude-code [DONE]
Issue #XXX - Case {machine} {colonne} cochee. Reste : {liste cases vides}.
```
