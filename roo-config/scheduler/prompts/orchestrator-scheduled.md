# Prompt Tache Planifiee Roo - Mode orchestrator-simple

Ce prompt est utilise par le scheduler pour lancer Roo en mode orchestrator-simple.
Il est lu par l'utilisateur ou par un script qui le passe a Roo via l'INTERCOM.

---

## Instructions pour Roo (orchestrator-simple)

Tu es lance par le planificateur automatique. Suis ce workflow strictement.

### WORKFLOW EN 5 ETAPES

**Etape 1 : Lire l'INTERCOM**
- Ouvre `.claude/local/INTERCOM-{MACHINE}.md`
- Lis les 5 derniers messages
- Cherche les messages de type [SCHEDULED] ou [TASK] de Claude Code
- Si message [URGENT] : traiter en priorite absolue

**Etape 2 : Verifier l'etat du workspace**
- `git status` : changements non commites ?
- Si dirty : NE PAS commiter. Signaler dans le rapport.
- Verifier que le build fonctionne si des fichiers TypeScript ont change

**Etape 3 : Executer les taches**
- Si message [SCHEDULED] ou [TASK] : deleguer aux modes -simple
- Si tache complexe detectee : escalader vers orchestrator-complex
- Si rien a faire : passer a l'etape 4 directement

**Etape 4 : Rapporter le resultat**
- Ecrire un message dans l'INTERCOM avec le type [DONE] ou [ERROR]
- Format :
  ```
  ## [{DATE}] roo -> claude-code [DONE]
  ### Tache planifiee - Resultat
  - Taches executees : ...
  - Erreurs : ...
  - Git status : propre/dirty
  ```

**Etape 5 : Ne PAS commiter**
- Claude Code validera le travail lors de son prochain tour
- Ne JAMAIS `git commit` ou `git push` en mode planifie
- Les commits sont la responsabilite de Claude Code

### REGLES DE SECURITE

1. Ne JAMAIS commit sans validation Claude
2. Ne JAMAIS push directement
3. Verifier `git status` AVANT toute modification
4. Lire INTERCOM EN PREMIER (urgences possibles)
5. Deleguer uniquement aux modes `-simple` ou `-complex` (jamais les natifs)
6. Ne JAMAIS faire `git checkout` ou `git pull` dans le submodule `mcps/internal/`

### CRITERES D'ESCALADE

Si l'une de ces conditions est vraie, escalader vers `orchestrator-complex` :
- Plus de 5 sous-taches a coordonner
- Dependances complexes entre sous-taches
- Parallelisation requise
- Message [URGENT] dans l'INTERCOM

### SI RIEN A FAIRE

Ecrire dans l'INTERCOM :
```
## [{DATE}] roo -> claude-code [IDLE]
Aucune tache planifiee. Workspace propre. En attente.
```
