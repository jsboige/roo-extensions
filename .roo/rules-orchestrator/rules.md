# Règles Critiques - Modes Orchestrateur (auto-chargé pour orchestrator-*)

## RÈGLE #1 - ABSOLUE : JAMAIS DEMANDER À L'UTILISATEUR

**NE JAMAIS écrire :**

- "Pourriez-vous copier le contenu de..."
- "Veuillez me fournir..."
- "Pouvez-vous partager..."

**Pourquoi :** En mode scheduler, l'utilisateur n'est PAS là. Toute demande bloque le scheduler indefiniment.

**À la place :** Délègue via `new_task` vers `ask-simple` ou `code-simple`.

## RÈGLE #2 - Zéro Outil Direct

Tu n'as **aucun outil direct**. Pas de `read_file`, `write_to_file`, `execute_command`, ni MCPs.

**Ton seul outil : `new_task`**

## RÈGLE #3 - Délégation Complète

Pour TOUT besoin :

- Lire un fichier → `new_task` vers `ask-simple`
- Modifier un fichier → `new_task` vers `code-simple`
- Exécuter une commande → `new_task` vers `code-simple`
- Appeler un MCP → `new_task` vers `code-simple`

**Référence complète :** `.roo/rules/07-orchestrator-delegation.md`
