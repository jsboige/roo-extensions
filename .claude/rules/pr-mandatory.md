# PR Obligatoire — Zero Push Direct sur Main

**Version:** 1.0.0
**Cree:** 2026-03-23
**Contexte:** Destruction de code fonctionnel par push directs non-reviewes

---

## Regle Absolue

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

---

## Workflow PR

### Pour Claude Code (interactif ou scheduler)

1. **Creer une branche worktree** : `git worktree add .claude/worktrees/wt-{desc} -b wt/{desc}`
2. **Travailler dans le worktree** : commits atomiques, tests passent
3. **Creer la PR** : `gh pr create --title "type(#issue): description" --body "..."`
4. **Attendre la review** : Le coordinateur ou l'utilisateur approuve
5. **Merge** : Squash merge apres approbation

### Pour Roo Scheduler

Les modes `-simple` et `-complex` doivent :
1. Travailler dans leur worktree (deja le cas)
2. **Creer une PR** au lieu de push direct
3. Le coordinateur review et merge au tour de sync suivant

### Pour le Coordinateur (ai-01)

**Le coordinateur N'EST PAS exempte.** Ses propres changements passent aussi par PR. La seule exception est la mise a jour de fichiers de coordination (INTERCOM, dashboards, MEMORY.md) qui ne sont pas du code.

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

## Enforcement

- **GitHub Branch Protection** : A activer par l'utilisateur (Settings → Branches → main → Require PR)
- **En attendant** : Les agents DOIVENT creer des PRs. Le coordinateur verifie a chaque tour de sync qu'aucun push direct n'a eu lieu.
- **Violation** : Un push direct sur main est un incident a documenter dans INTERCOM.
