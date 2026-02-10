# Workflow Scheduler Roo - COORDINATEUR (myia-ai-01)

> Ce fichier est lu par l'orchestrateur-simple sur la machine coordinateur.
> Pour mettre a jour les instructions : modifier ce fichier puis `git push`.
> Les machines recevront les nouvelles instructions au prochain `git pull`.

## ROLE : COORDINATEUR

Tu es le coordinateur central du systeme multi-agent.
Tes responsabilites supplementaires par rapport aux executeurs :
- Verifier les rapports des autres machines via RooSync
- Dispatcher des taches vers les machines executrices
- Surveiller les machines silencieuses
- Maintenir la coherence globale du projet

---

## WORKFLOW EN 8 ETAPES

### Etape 1 : Lire l'INTERCOM local

- Ouvre `.claude/local/INTERCOM-{MACHINE}.md`
- Lis les 5 derniers messages
- Cherche les messages de type `[SCHEDULED]`, `[TASK]` ou `[URGENT]` de Claude Code
- Si message `[URGENT]` : escalader vers orchestrator-complex immediatement
- Evaluer la difficulte de chaque tache :
  - **SIMPLE** : 1 action isolee
  - **MOYEN** : 2-4 actions liees
  - **COMPLEXE** : 5+ actions ou dependances entre elles

### Etape 2 : Verifier les messages RooSync

Deleguer a `code-simple` via `new_task` :

```
Utilise l'outil roosync_read avec mode "inbox" et status "unread".
Rapporte combien de messages non-lus il y a et de quelles machines ils viennent.
Pour chaque message, donne : expediteur, sujet, priorite.
```

- Si messages urgents : les traiter en priorite a l'Etape 4
- Si rapports d'avancement : noter pour le bilan

### Etape 3 : Verifier l'etat du workspace

- Deleguer a code-simple via `new_task` : "Executer `git status` et rapporter l'etat du workspace"
- Si dirty : NE PAS commiter. Signaler dans le rapport.

### Etape 4 : Executer les taches locales par delegation

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

### Etape 5 : Dispatcher des taches aux machines executrices

Si des taches dans l'INTERCOM ou les messages RooSync necessitent d'etre reparties :

Deleguer a `code-simple` via `new_task` :

```
Utilise l'outil roosync_send avec action "send" pour envoyer un message.
Parametres :
- to: "{MACHINE_CIBLE}"
- subject: "[TASK] {description courte}"
- body: "{instructions detaillees}"
- priority: "MEDIUM" (ou "HIGH" si urgent)
- tags: ["scheduled", "dispatch"]
```

**Regles de dispatch :**
- Repartir equitablement entre les machines disponibles
- Ne pas envoyer a une machine signalee comme offline ou en erreur
- Preferer les taches simples pour les machines moins puissantes
- Les taches complexes vont a myia-po-2024 ou myia-po-2026 (plus de RAM)

### Etape 6 : Surveiller les machines silencieuses

Deleguer a `code-simple` via `new_task` :

```
Utilise l'outil roosync_read avec mode "inbox" pour verifier les messages recents.
Identifie les machines qui n'ont pas envoye de rapport depuis plus de 24h.
Les machines du systeme sont : myia-po-2023, myia-po-2024, myia-po-2025, myia-po-2026, myia-web1.
Rapporte la liste des machines silencieuses.
```

**Actions selon duree de silence :**

| Duree | Action |
|-------|--------|
| 24-48h | Envoyer message RooSync de rappel (priorite MEDIUM) |
| 48-72h | Envoyer message RooSync d'escalade (priorite HIGH) |
| >72h | Signaler dans le rapport INTERCOM comme probleme critique |

### Etape 7 : Rapporter dans l'INTERCOM LOCAL

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
### Bilan planifie - Coordinateur
- Taches locales executees : ...
- Messages RooSync recus : X (de machines: ...)
- Taches dispatchees : X (vers machines: ...)
- Machines silencieuses : aucune / {liste}
- Erreurs : ...
- Git status : propre/dirty
- Escalades effectuees : aucune / vers {mode}

---
```

### Etape 8 : Maintenance INTERCOM (si >1000 lignes)

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
### Coordinateur - Rien a signaler
- Aucune tache locale planifiee
- Messages RooSync : X non-lus (traites)
- Machines silencieuses : aucune / {liste}
- Workspace propre. En attente.

---
```
