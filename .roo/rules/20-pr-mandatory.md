# PR Obligatoire — Zero Push Direct sur Main

**Version:** 2.0.0 (harmonized Claude + Roo, #1053)
**MAJ:** 2026-04-08
**Contexte:** Destruction de code fonctionnel par push directs non-reviewes. Harmonise avec .claude/rules/pr-mandatory.md.

---

## REGLE ABSOLUE

**AUCUN push direct sur `main`.** Tout changement de code passe par :

```
Worktree branch → PR → Review coordinateur → Merge
```

**Pas d'exception.** Ni pour les "petits fix", ni pour les "docs only", ni pour le coordinateur lui-meme.

---

## Pourquoi

La moitie du "code mort" detecte et supprime est en realite du **code fonctionnel detruit** par des agents qui refactorent sans comprendre. Les push directs empechent toute verification AVANT que le dommage soit fait.

**Incidents :**
- Session 101 : 8 scripts archives sans verification → pipeline casse
- Stubs #767-786 : 20 methodes implementees remplacees par `return null`
- Console.log : 767 instances dans 72 fichiers (debug jamais nettoye)
- Config drift sk-agent : agents manquants sur 4 machines

## Workflow PR

### Pour Claude Code (interactif ou scheduler)

1. **Creer une branche worktree** : `git worktree add .claude/worktrees/wt-{desc} -b wt/{desc}`
2. **Travailler dans le worktree** : commits atomiques, tests passent
3. **Creer la PR** : `gh pr create --title "type(#issue): description" --body "..."`
4. **Attendre la review** : Le coordinateur ou l'utilisateur approuve
5. **Merge** : Squash merge apres approbation
6. **CLEANUP OBLIGATOIRE** : Supprimer le worktree et la branche locale apres merge/close
   ```bash
   # Supprimer le worktree
   git worktree remove .claude/worktrees/wt-{desc}
   # Supprimer la branche locale
   git branch -D wt/{desc}
   ```

### Pour Roo Scheduler

Les modes `-simple` et `-complex` doivent :
1. Travailler dans leur worktree (deja le cas)
2. Committer sur la branche worktree
3. **NE PAS merger dans main** — `git push origin main` INTERDIT
4. **Creer la PR :**
   - **-complex** (terminal natif) : `git push -u origin <branch>` + `gh pr create`
   - **-simple** (pas de terminal) : Committer. Le Claude Worker (`start-claude-worker.ps1`) cree la PR automatiquement.
5. Rapporter dans le bilan : branche worktree + PR URL (ou "PR pending via Claude Worker")

**Un worktree sans PR >24h sera ferme par le coordinateur.** Ne pas laisser de travail orphelin.

### Pour le Coordinateur (ai-01)

**Le coordinateur N'EST PAS exempte.** Ses propres changements passent aussi par PR. La seule exception est la mise a jour de fichiers de coordination (INTERCOM, dashboards, MEMORY.md) qui ne sont pas du code.

## Interdit

- `git push origin main` — INTERDIT
- `git checkout main && git merge wt/...` — INTERDIT
- Toute operation qui modifie `main` directement — INTERDIT

---

## Repertoires PROTEGES — Suppression INTERDITE sans approbation utilisateur

**Les repertoires suivants contiennent du code strategique en cours de developpement.**
Un agent ne peut PAS supprimer, "retirer", "nettoyer" ou "consolider" du code dans ces repertoires.

| Repertoire | Raison | Incidents |
|-----------|--------|-----------|
| `src/services/synthesis/` | Pipeline LLM synthese (investissement strategique) | 3 suppressions erronees, 3 reverts |
| `src/services/narrative/` | NarrativeContextBuilder (Phase 3 en attente) | Stubs #775-780 = cibles d'IMPLEMENTATION |

**Les stubs (#775-780) sont des CIBLES D'IMPLEMENTATION, PAS du code mort.**
Un plan d'agent qui recommande "RETIRER" ces stubs est FAUX. Seul l'utilisateur decide de supprimer un sous-systeme.

---

## Review Obligatoire — Checklist Anti-Destruction

Avant d'approuver une PR, verifier :

- [ ] **Pas de suppression de code sans justification** : Chaque fichier/fonction supprime a un remplacement PROUVE
- [ ] **Pas de suppression dans les repertoires PROTEGES** : synthesis/, narrative/ = approbation utilisateur requise
- [ ] **Tests preserves** : Si du code est supprime, les tests qui le couvraient sont aussi supprimes OU le remplacement est teste
- [ ] **Pas de nouveaux stubs** : Aucun `return null`, `throw new Error('Not Implemented')`, `// TODO` dans du code expose
- [ ] **Pas de console.log** dans du code nouveau
- [ ] **Diff proportionnel** : Une PR de "nettoyage" ne devrait pas supprimer plus de code qu'elle n'en ajoute sans justification
- [ ] **Build + tests passent** : CI vert obligatoire
- [ ] **Un plan d'agent n'est PAS une autorisation** : Si un plan recommande "supprimer/retirer", verifier avec l'utilisateur AVANT

---

## Ce qui NE necessite PAS de PR

- Mise a jour MEMORY.md, INTERCOM, dashboards (fichiers de coordination non-code)
- Mise a jour `.claude/rules/`, `.roo/rules/` (harnais — tracke par git mais pas du code applicatif)
- Fichiers gitignored (configs locales, .env)

---

## Cleanup Post-Merge/Close (CRITIQUE)

**BUG #895 : Le workflow incomplet PERD DU TRAVAIL.**

### Pourquoi c'est critique

Sans cleanup automatique post-merge :
- Les worktrees s'accumulent (33 branches wt/ orphelines identifiees)
- Les branches locales ne sont jamais supprimees
- Le travail valide peut etre perdu si PR fermee sans merge
- Surcharge git branch et VS Code (2k+ notifications)

### Procedure de cleanup obligatoire

**Apres chaque PR merge ou close :**

```bash
# 1. Retourner au repo principal
cd C:\dev\roo-extensions

# 2. Supprimer le worktree
git worktree remove .claude/worktrees/wt-{desc}

# 3. Supprimer la branche locale
git branch -D wt/{desc}

# 4. Verifier
git worktree list
git branch --list "wt/*"
```

### Cleanup automatique (Recommande)

**Script de cleanup existe :** `scripts/claude/worktree-cleanup.ps1` (Issue #856)

**Tache planifiee recommande (Windows) :**
```powershell
# Creer une tache quotidienne pour nettoyer les worktrees orphelins
schtasks /Create /TN "Roo-Worktree-Cleanup" /TR "powershell -ExecutionPolicy Bypass -File C:\dev\roo-extensions\scripts\claude\worktree-cleanup.ps1" /SC DAILY /ST 02:00
```

**Ou execution manuelle periodique :**
```powershell
# Dry-run pour voir ce qui serait nettoye
powershell -ExecutionPolicy Bypass -File scripts\claude\worktree-cleanup.ps1 -WhatIf

# Execution reelle
powershell -ExecutionPolicy Bypass -File scripts\claude\worktree-cleanup.ps1
```

### Audit PRs CLOSED (Session 35)

**PRs CLOSED avec travail recuperable identifie :**

| PR | Commits | Lignes | Branche | Statut |
|----|---------|--------|---------|--------|
| #870 | 2 | 1576 | wt/worker-myia-po-2025-20260326-042234 | **Recupere** dans #893 |
| #846 | 11 | 1554 | wt/worker-myia-po-2026-20260324-175849 | A verifier |
| #592 | 1 | 299 | wt/worker-myia-po-2025-20260307-071553 | A verifier |
| #585 | 1 | 371 | wt/worker-myia-po-2025-20260306-231457 | A verifier |

---

## Enforcement

- **GitHub Branch Protection** : A activer par l'utilisateur (Settings → Branches → main → Require PR)
- **En attendant** : Les agents DOIVENT creer des PRs. Le coordinateur verifie a chaque tour de sync qu'aucun push direct n'a eu lieu.
- **Cleanup obligatoire** : Apres chaque PR merge/close, le worktree et la branche DOIVENT etre supprimes.
- **Violation** : Un push direct sur main est un incident a documenter dans INTERCOM.
