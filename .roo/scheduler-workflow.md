# Workflow Scheduler Roo - Instructions pour l'orchestrateur planifie

> Ce fichier est lu par l'orchestrateur-simple lors de chaque execution planifiee.
> Pour mettre a jour les instructions : modifier ce fichier puis `git push`.
> Les machines recevront les nouvelles instructions au prochain `git pull`.

## WORKFLOW EN 6 ETAPES

### Etape 1 : Lire l'INTERCOM

- Ouvre `.claude/local/INTERCOM-{MACHINE}.md` (remplace {MACHINE} par le hostname de cette machine)
- Lis les 5 derniers messages
- Cherche les messages de type `[SCHEDULED]`, `[TASK]` ou `[URGENT]` de Claude Code
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

Pour chaque tache `[TASK]` trouvee dans l'INTERCOM :

| Difficulte | Action |
|-----------|--------|
| **SIMPLE** (1 action) | Deleguer a `code-simple` ou `debug-simple` via `new_task` |
| **MOYEN** (2-4 actions) | Deleguer chaque action separement a `code-simple` |
| **COMPLEXE** (5+ actions, dependances) | Escalader vers `orchestrator-complex` via `new_task` avec le contexte complet |
| **URGENT** | Escalader vers `orchestrator-complex` immediatement |

**Gestion des echecs :**

1. Si une sous-tache echoue : analyser le resume d'erreur retourne
2. Si erreur simple (fichier introuvable, syntaxe) : relancer avec instructions corrigees
3. Si erreur complexe (logique, architecture) : escalader vers le mode -complex correspondant
4. Apres 2 echecs sur la meme sous-tache : arreter et rapporter dans le bilan

### Etape 4 : Rapporter dans l'INTERCOM LOCAL

**PROTECTION DU CONTENU** - Pour ecrire dans l'INTERCOM, deleguer a `code-simple` avec ces instructions EXACTES :

```
1. Lis le fichier .claude/local/INTERCOM-{MACHINE}.md en ENTIER avec read_file.
2. Prepare le nouveau message (format ci-dessous).
3. Reecris le fichier avec write_to_file en mettant le nouveau message AU DEBUT
   suivi d'une ligne vide puis de TOUT l'ancien contenu INTEGRAL.
   Ne supprime RIEN de l'ancien contenu.
```

- NE PAS utiliser `roosync_send` (c'est pour inter-machines, pas local)

**Format du nouveau message :**

```markdown
## [{DATE}] roo -> claude-code [DONE]
### Tache planifiee - Resultat
- Taches executees : ...
- Erreurs : ...
- Git status : propre/dirty
- Difficulte : SIMPLE/MOYEN/COMPLEXE
- Escalades effectuees : aucune / vers {mode}

---
```

### Etape 5 : Ne PAS commiter

- Claude Code validera le travail lors de son prochain tour
- Ne JAMAIS `git commit` ou `git push` en mode planifie
- Les commits sont la responsabilite de Claude Code

### Etape 6 : Maintenance INTERCOM (si >1000 lignes)

Deleguer a `code-simple` :

```
Lis .claude/local/INTERCOM-{MACHINE}.md.
Si plus de 1000 lignes :
  - Condenser les 600 premieres en ~100 lignes (synthese des taches, decisions, metriques)
  - Garder les 400 dernieres lignes intactes
  - Reecrire le fichier (~500 lignes)
```

---

## REGLES DE SECURITE

1. Ne JAMAIS commit sans validation Claude Code
2. Ne JAMAIS push directement
3. Verifier `git status` AVANT toute modification
4. Lire INTERCOM EN PREMIER (urgences possibles)
5. Deleguer uniquement aux modes `-simple` ou `-complex` (jamais les natifs)
6. Ne JAMAIS faire `git checkout` ou `git pull` dans le submodule `mcps/internal/`

---

## CRITERES D'ESCALADE VERS ORCHESTRATOR-COMPLEX

- Plus de 5 sous-taches a coordonner
- Dependances entre sous-taches (une depend du resultat d'une autre)
- Parallelisation requise (taches independantes a lancer simultanement)
- Message `[URGENT]` dans l'INTERCOM
- 2 echecs consecutifs sur des sous-taches simples
- Modification de plus de 3 fichiers interconnectes

---

## SI RIEN A FAIRE

Deleguer l'ecriture INTERCOM avec le message :

```markdown
## [{DATE}] roo -> claude-code [IDLE]
Aucune tache planifiee. Workspace propre. En attente.

---
```
