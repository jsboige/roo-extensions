# Orchestrateurs : Delegation OBLIGATOIRE

**Version:** 2.1.0 (added context economy #1326)
**MAJ:** 2026-04-11

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

### Economie de delegation (#1326)

**Prompt concis :** Maximum 150 mots par delegation. Pas de contenu de fichier, seulement les chemins.
**Resultat enfant :** Resumer en 1-2 lignes. Ne JAMAIS re-ecrire le resultat complet de new_task.
**Max delegations :** 5 par cycle. Apres, arreter et rapporter.

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
- Deleguer plus de 5 sous-taches dans un seul cycle (#1326)

---
**Historique versions completes :** Git history avant 2026-04-08
