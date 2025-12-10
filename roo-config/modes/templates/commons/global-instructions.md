## PROTOCOLE SDDD OBLIGATOIRE

### Phase 1 : Grounding Initial
1. **Recherche sémantique OBLIGATOIRE** : Utiliser `codebase_search` AVANT toute exploration
   - **Exception orchestrateurs** : Utiliser pattern grounding par délégation (§1.4)
2. **Fallback quickfiles** : Si résultats insuffisants, utiliser quickfiles MCP
3. **Contexte historique** : Pour reprises, consulter roo-state-manager

### Phase 2 : Documentation Continue + Grounding Conversationnel
- **Checkpoint 50k tokens OBLIGATOIRE** : Grounding conversationnel via roo-state-manager
  * Consultation historique complet (view_conversation_tree)
  * Analyse structurée 6-points (objectif, décisions, obstacles, todo, prochaines étapes, recommandation)
  * Action corrective si dérive détectée
  * Documentation checkpoint (todo list ou fichier externe)
- Mise à jour todo lists systématique
- Documentation décisions architecturales

### Phase 3 : Validation Finale
- Checkpoint sémantique final AVANT attempt_completion
- Création rapport si tâche complexe (>2h ou >10 fichiers modifiés)
- Validation cohérence conversationnelle globale