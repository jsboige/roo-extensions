# Orchestrateurs : Delegation OBLIGATOIRE

**SI TU ES EN MODE orchestrator-simple OU orchestrator-complex :**

Tu n'as AUCUN outil direct. Pas de read_file, write_to_file, apply_diff, execute_command, browser_action, ni aucun MCP (#563).
Ton SEUL outil est `new_task`.

## Regle absolue

**TOUTE action doit passer par `new_task`.** Tu ne fais RIEN toi-meme.

**NE DEMANDE JAMAIS RIEN A L'UTILISATEUR.** Ceci inclut :
- Copier du contenu, lire un fichier, executer une commande
- Confirmer une action ("Veux-tu que...", "Dois-je...", "Voulez-vous...")
- Poser une question de quelque nature que ce soit
- Demander une preference ou un choix

**Toute question = ECHEC IMMEDIAT qui bloque le scheduler.** Tu es 100% AUTONOME.

Si tu as besoin de :
- **Lire un fichier** → `new_task` vers `ask-simple` ou `code-simple`
- **Modifier un fichier** → `new_task` vers `code-simple`
- **Executer une commande** → `new_task` vers `code-simple` (avec win-cli)
- **Lire INTERCOM** → `new_task` vers `code-simple` (roosync_dashboard action: "read", type: "workspace+machine". Fallback: lire fichier .claude/local/INTERCOM-{MACHINE}.md)
- **Verifier git status** → `new_task` vers `code-simple`
- **Ecrire dans INTERCOM** → `new_task` vers `code-simple` (roosync_dashboard action: "append", type: "workspace+machine". Fallback: apply_diff ou win-cli Add-Content sur fichier)
- **Appeler un outil MCP** (roosync, heartbeat, etc.) → `new_task` vers `code-simple`

## Pattern de delegation

```
new_task({
  mode: "code-simple",
  message: "Instructions COMPLETES : quoi faire, quels fichiers, quel resultat attendu.
  IMPORTANT : utilise win-cli MCP (pas le terminal natif).
  execute_command(shell='powershell', command='...')
  Rapporter le resultat."
})
```

Inclure dans chaque prompt delegue :
1. Le contexte necessaire (pas de reference a "voir ci-dessus")
2. Les chemins de fichiers exacts
3. Le format du resultat attendu
4. L'instruction d'utiliser win-cli MCP

## Anti-patterns (INTERDIT)

- "Pourriez-vous copier le contenu de..." → INTERDIT (demande de contenu)
- "Veuillez me fournir..." → INTERDIT (demande de contenu)
- "Veux-tu que je continue ?" → INTERDIT (demande de confirmation)
- "Dois-je proceder ?" → INTERDIT (demande de permission)
- "Voulez-vous que je fasse X ?" → INTERDIT (demande de validation)
- "Souhaitez-vous..." → INTERDIT (demande de preference)
- "Que preferez-vous ?" → INTERDIT (demande de choix)
- Tenter d'utiliser read_file, write_to_file, apply_diff directement → IMPOSSIBLE
- Tenter d'utiliser execute_command directement → IMPOSSIBLE (meme via win-cli MCP)
- Tenter d'appeler roosync_heartbeat, roosync_config directement → IMPOSSIBLE
- Attendre une reponse utilisateur pour continuer → INTERDIT en mode scheduler
- Lire un fichier toi-meme au lieu de deleguer → INTERDIT
- Réessayer un outil qui échoue >2 fois → INTERDIT (circuit breaker #737)
- Utiliser `gh api graphql` en `-simple` via win-cli → ÉVITER (quoting instable, escalader vers `-complex`)
