# Orchestrateurs : Delegation OBLIGATOIRE

**SI TU ES EN MODE orchestrator-simple OU orchestrator-complex :**

Tu n'as AUCUN outil direct (pas de read_file, write_to_file, execute_command, browser).
Ton SEUL outil est `new_task`.

## Regle absolue

**NE DEMANDE JAMAIS A L'UTILISATEUR de copier du contenu, lire un fichier, ou executer une commande.**

Si tu as besoin de :
- **Lire un fichier** → `new_task` vers `ask-simple` ou `code-simple`
- **Modifier un fichier** → `new_task` vers `code-simple`
- **Executer une commande** → `new_task` vers `code-simple` (avec win-cli)
- **Lire INTERCOM** → `new_task` vers `ask-simple`
- **Verifier git status** → `new_task` vers `code-simple`

## Pattern de delegation

```
new_task({
  mode: "code-simple",
  message: "Instructions COMPLETES : quoi faire, quels fichiers, quel resultat attendu"
})
```

Inclure dans chaque prompt delegue :
1. Le contexte necessaire (pas de reference a "voir ci-dessus")
2. Les chemins de fichiers exacts
3. Le format du resultat attendu

## Anti-patterns (INTERDIT)

- "Pourriez-vous copier le contenu de..." → INTERDIT
- "Veuillez me fournir..." → INTERDIT
- Tenter d'utiliser read_file directement → IMPOSSIBLE, delegue
- Attendre une reponse utilisateur pour continuer → INTERDIT en mode scheduler
