# Workflow Scheduler Roo - COORDINATEUR (myia-ai-01)

> Lu par orchestrateur-simple. MAJ : modifier ce fichier + `git push`.

## PRINCIPES

1. **Roo n'utilise JAMAIS RooSync** (reserve a Claude Code)
2. **TOUJOURS deleguer via `new_task`** (jamais faire le travail soi-meme)
3. Communication via INTERCOM uniquement (`.claude/local/INTERCOM-myia-ai-01.md`)
4. Ne JAMAIS commit ou push
5. Deleguer uniquement aux modes `-simple` ou `-complex`

---

## WORKFLOW EN 3 ETAPES

### Etape 1 : Git pull + Lecture INTERCOM

Deleguer a `code-simple` via `new_task` :

```
Executer ces commandes et rapporter le resultat :
1. git pull --no-rebase origin main
2. git status
Puis lire les 5 derniers messages de .claude/local/INTERCOM-myia-ai-01.md
Chercher les messages [TASK], [SCHEDULED], [URGENT] de claude-code -> roo.
Rapporter : etat git + liste des taches trouvees.
```

**Decision :**
- Si `[URGENT]` : escalader vers `orchestrator-complex`
- Si `[TASK]` trouve : aller a **Etape 2a**
- Si `[FEEDBACK]` recent de Claude : noter les ajustements
- Si rien : aller a **Etape 2b**

### Etape 2a : Executer les taches INTERCOM

Pour chaque `[TASK]` trouve, deleguer selon la difficulte :

| Difficulte | Action |
|-----------|--------|
| 1 action isolee | `code-simple` via `new_task` |
| 2-4 actions liees | Deleguer chaque action separement a `code-simple` |
| 5+ actions ou dependances | Escalader vers `orchestrator-complex` |

**Gestion des echecs :**
- 1er echec : relancer avec instructions corrigees
- 2e echec sur meme tache : arreter et rapporter dans le bilan
- Erreur complexe : escalader vers `-complex`

Apres execution → **Etape 3**

### Etape 2b : Taches par defaut (si pas de [TASK])

Deleguer dans cet ordre a `code-simple` via `new_task` :

**1. Build + Tests (validation sante workspace)**

```
Executer dans le repertoire mcps/internal/servers/roo-state-manager :
1. npm run build
2. npx vitest run
Rapporter : build OK/FAIL + nombre tests pass/fail.
```

**2. Verifier inbox RooSync (detecter messages pour Claude)**

```
Executer cette commande PowerShell et rapporter le resultat COMPLET :
$files = Get-ChildItem "G:/Mon Drive/Synchronisation/RooSync/.shared-state/messages/inbox/*.json" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 5 Name,LastWriteTime
Write-Output "Nombre total: $($files.Count)"
$files | Format-Table -AutoSize
```

**3. Si messages RooSync recents (< 6h) → signaler dans INTERCOM avec `[WAKE-CLAUDE]`**

**4. Chercher une tache sur GitHub (si du temps reste)**

```
gh issue list --repo jsboige/roo-extensions --state open --limit 10 --json number,title,labels --jq '.[] | select(.labels[]?.name == "roo-schedulable") | "\(.number)\t\(.title)"'
```

Si une issue est trouvee : la lire, commenter pour claim, et executer si faisable en `-simple`.

Apres tout → **Etape 3**

### Etape 3 : Rapporter dans INTERCOM (OBLIGATOIRE)

> **CRITIQUE :** L'ecriture INTERCOM est la seule trace du passage du scheduler. Sans elle, Claude Code ne sait pas que Roo a tourne. **Ne JAMAIS quitter sans avoir ecrit dans INTERCOM.**

**Methode principale :** Deleguer a `code-simple` via `new_task` :

```
1. Lis .claude/local/INTERCOM-myia-ai-01.md en ENTIER avec read_file
2. Ajoute le nouveau message A LA FIN (ne supprime RIEN de l'ancien contenu)
3. Reecris le fichier COMPLET avec write_to_file
4. Relis le fichier et confirme que le dernier message est celui qu'on vient d'ajouter
```

**FALLBACK :** Si la delegation echoue (subtask error, timeout, pas de confirmation), ecrire INTERCOM directement soi-meme avec read_file + write_to_file. Cette exception a la regle "toujours deleguer" est justifiee car la tracabilite est prioritaire.

**Format du message :**

```markdown
## [{DATE}] roo -> claude-code [{DONE|MAINTENANCE|IDLE}]
### Bilan scheduler coordinateur

- Git pull : OK/erreur
- Git status : propre/dirty
- Build : OK/FAIL
- Tests : {X} pass / {Y} fail
- Taches executees : {N} (source: INTERCOM/GitHub)
- Erreurs : {liste ou "aucune"}
- Messages RooSync detectes : {N}
- Wake Claude : oui/non

---
```

**Maintenance INTERCOM :** Si le fichier depasse 1000 lignes, condenser les 600 premieres en ~100 lignes de synthese, garder les 400 dernieres intactes.

---

## REGLES DE SECURITE

1. Ne JAMAIS commit sans validation Claude Code
2. Ne JAMAIS push directement
3. Ne JAMAIS faire `git checkout` dans le submodule `mcps/internal/`
4. **NE JAMAIS utiliser les outils RooSync** (roosync_send, roosync_read, etc.)
5. Apres 2 echecs sur meme tache : arreter et rapporter

---

## CRITERES D'ESCALADE VERS ORCHESTRATOR-COMPLEX

- Message `[URGENT]` dans l'INTERCOM
- Plus de 5 sous-taches a coordonner
- Dependances entre sous-taches
- 2 echecs consecutifs en `-simple`
- Modification de plus de 3 fichiers interconnectes
