# Orchestrateurs : Delegation OBLIGATOIRE

**Version:** 2.0.0 (condensed from 1.0.0)
**MAJ:** 2026-04-08

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

---
**Historique versions completes :** Git history avant 2026-04-08
