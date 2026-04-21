# Orchestrateurs : Delegation OBLIGATOIRE

**Version:** 3.0.0 (context explosion fix #1608)
**MAJ:** 2026-04-21

## Regle absolue

**En mode orchestrator-simple/complex : AUCUN outil direct.** Ton SEUL outil est `new_task`.

**NE DEMANDE JAMAIS RIEN A L'UTILISATEUR.** Toute question = ECHEC IMMEDIAT du scheduler.

## Delegation

```
new_task({
  mode: "code-simple",
  message: "Instructions COMPLETES : contexte, fichiers, resultat attendu.
  IMPORTANT : utilise win-cli MCP (pas le terminal natif)."
})
```

**Parametres OBLIGATOIRES (#803) :** `mode` (string) + `message` (string). Si absent → echec silencieux.

Inclure dans chaque prompt : contexte, chemins exacts, format resultat, instruction win-cli.

### Economie de delegation (#1326, #1608)

**TRONCATURE OBLIGATOIRE (#1608 - CRITICAL) :**
- Toute lecture de fichier DOIT utiliser : `offset/limit` (Read) ou `Select-Object -Last 50` (PowerShell)
- JAMAIS retourner plus de 50 lignes dans le resultat d'une delegation
- Pour l'exploration : utiliser `codebase_search` au lieu de `read_file` (resultats naturellement bornes)

**Prompt concis :** Maximum 150 mots par delegation. Pas de contenu de fichier, seulement les chemins.
**Resultat enfant :** Resumer en 1-2 lignes. Ne JAMAIS re-ecrire le resultat complet de new_task.
**Max delegations :** 3 par cycle (reduit de 5, #1608). Apres 3, arreter et rapporter.

## Routage

| Besoin | Mode cible |
| ------ | ---------- |
| Lire un fichier | `ask-simple` |
| Modifier un fichier | `code-simple` |
| Executer une commande | `code-simple` (win-cli) |
| Lire/ecrire dashboard | `code-simple` |
| Appeler un MCP | `code-simple` |

## Anti-patterns (INTERDIT)

- Demander contenu, confirmation, permission, preference
- Utiliser directement read_file, write_to_file, execute_command
- Reessayer un outil >2 fois (circuit breaker #737)
- `gh api graphql` en -simple via win-cli (quoting instable → escalader -complex)
- Re-ecrire le contenu integral d'un resultat enfant (explosion contexte #1326)
- Deleguer plus de 3 sous-taches dans un seul cycle (#1608 - CRITICAL)
- Retourner plus de 50 lignes dans une delegation (explosion contexte #1608 - CRITICAL)
- Lire un fichier sans offset/limit ou Select-Object -Last 50 (#1608 - CRITICAL)

---
**Historique versions completes :** Git history avant 2026-04-08
