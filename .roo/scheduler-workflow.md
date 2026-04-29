# Workflow Scheduler Roo - Instructions pour l'orchestrateur planifie

> Ce fichier est lu par l'orchestrateur-simple lors de chaque execution planifiee.
> Pour mettre a jour les instructions : modifier ce fichier puis `git push`.
> Les machines recevront les nouvelles instructions au prochain `git pull`.

**MIGRATION 2026-04-29 (#1818) :** Canal principal = **dashboard workspace** (`roosync_dashboard`).
INTERCOM local (`.claude/local/INTERCOM-{MACHINE}.md`) = **DEPRECATED**, fallback UNIQUEMENT si MCP indisponible.

## WORKFLOW EN 6 ETAPES

### Etape 1 : Lire le dashboard workspace

- Utiliser `roosync_dashboard(action: "read", type: "workspace", section: "intercom", intercomLimit: 5)`
- Identifier les messages recents avec tags `[TASK]`, `[URGENT]`, `[CLAIMED]`, `[DONE]`
- Si message `[URGENT]` : escalader vers orchestrator-complex immediatement
- Evaluer la difficulte de chaque tache :
  - **SIMPLE** : 1 action isolee
  - **MOYEN** : 2-4 actions liees
  - **COMPLEXE** : 5+ actions ou dependances entre elles

### Etape 2 : Verifier l'etat du workspace

- Deleguer a code-simple via `new_task` : "Executer `git status` et rapporter l'etat du workspace"
- Si dirty : NE PAS commiter. Signaler dans le rapport.

### Etape 3 : Executer les taches par delegation

**REGLE ABSOLUE : NE JAMAIS faire le travail toi-meme. TOUJOURS deleguer via `new_task`.**

Pour chaque tache `[TASK]` trouvee sur le dashboard :

| Difficulte | Action |
|-----------|--------|
| **SIMPLE** (1 action) | Deleguer a `code-simple` ou `debug-simple` via `new_task` |
| **MOYEN** (2-4 actions) | Deleguer chaque action separement a `code-simple` |
| **COMPLEXE** (5+ actions, dependances) | Escalader vers `orchestrator-complex` via `new_task` avec le contexte complet |
| **URGENT** | Escalader vers `orchestrator-complex` immediatement |

**Gestion des echecs (seuil standardise #1233) :**

1. Si une sous-tache echoue : analyser le resume d'erreur retourne
2. **Escalader IMMEDIATEMENT vers le mode -complex correspondant** (1 echec = escalade immediate)
3. Apres 1 echec en -complex : arreter et rapporter dans le bilan

### Etape 4 : Rapporter sur le dashboard workspace

Utiliser `roosync_dashboard` pour poster le bilan :

```
roosync_dashboard(action: "append", type: "workspace", tags: ["DONE", "roo-scheduler"],
  content: "## [DONE] Tache planifiee - Resultat\n- Taches executees : ...\n- Erreurs : ...\n- Git status : propre/dirty\n- Difficulte : SIMPLE/MOYEN/COMPLEXE\n- Escalades effectuees : aucune / vers {mode}")
```

**REGLE CRITIQUE :** Toujours inclure le tag `roo-scheduler` pour tracer l'origine du rapport.

**Fallback si MCP dashboard indisponible :** Ecrire dans `.claude/local/INTERCOM-{MACHINE}.md` via `apply_diff` (voir `.roo/rules/02-dashboard.md` section fallback). INTERCOM = **dernier recours uniquement**.

### Etape 5 : Ne PAS commiter

- Claude Code validera le travail lors de son prochain tour
- Ne JAMAIS `git commit` ou `git push` en mode planifie
- Les commits sont la responsabilite de Claude Code

### Etape 6 : Verification fin de session

Verifier que le rapport a bien ete poste sur le dashboard :
- `roosync_dashboard(action: "read", type: "workspace", section: "intercom", intercomLimit: 1)` doit montrer le message [DONE]
- Si echoue : retenter une fois, puis fallback INTERCOM

---

## REGLES DE SECURITE

1. Ne JAMAIS commit sans validation Claude Code
2. Ne JAMAIS push directement
3. Verifier `git status` AVANT toute modification
4. Lire le dashboard EN PREMIER (urgences possibles)
5. Deleguer uniquement aux modes `-simple` ou `-complex` (jamais les natifs)
6. Ne JAMAIS faire `git checkout` ou `git pull` dans le submodule `mcps/internal/`

---

## CRITERES D'ESCALADE VERS ORCHESTRATOR-COMPLEX

- Plus de 5 sous-taches a coordonner
- Dependances entre sous-taches (une depend du resultat d'une autre)
- Parallelisation requise (taches independantes a lancer simultanement)
- Message `[URGENT]` sur le dashboard
- 1 echec sur une sous-tache simple (escalade immediate, standardise #1233)
- Modification de plus de 3 fichiers interconnectes

---

## SI RIEN A FAIRE

Poster sur le dashboard :

```
roosync_dashboard(action: "append", type: "workspace", tags: ["IDLE", "roo-scheduler"],
  content: "Aucune tache planifiee. Workspace propre. En attente.")
```
