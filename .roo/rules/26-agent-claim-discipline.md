# Agent Claim Discipline — Pas de Succes Non Verifie

**Version:** 1.0.0 (Roo, adaptee de .claude/rules/ v1.2.0)
**Issues :** #1605, #1613, #1666, #1697

---

## Regle Absolue

**Tu ne peux PAS declarer un travail termine en citant un artefact git sans que cet artefact soit verifiable a l'instant du rapport.**

Incidents concrets sans cette regle :
- **#1605** : Worker a rapporte `[DONE]` avec SHA inexistant. Travail perdu.
- **#1613** : 2 detached HEAD silencieux en 24h. Commits orphelins perdus apres cleanup.

---

## Verification OBLIGATOIRE avant `[DONE]`

### 1. Commit — Confirmer que le SHA existe

**Avant** de citer un SHA dans un rapport :

```
git cat-file -e <SHA> && git branch --contains <SHA>
```

- `-simple` : via `execute_command` (win-cli MCP)
- `-complex` : via terminal natif

Si le SHA n'existe pas : **NE PAS le citer.** Le commit est perdu.

### 2. Push — Confirmer que la branche est sur origin

```
git ls-remote origin <BRANCH>
```

Doit retourner exactement une ligne. Si 0 lignes : le push a echoue ou n'a pas ete fait.

### 3. PR — Confirmer l'etat de la Pull Request

```
gh pr view <N> --json state,url
```

- `state` doit etre `OPEN` ou `MERGED`
- Si la commande echoue ou retourne `CLOSED` : la PR n'est pas valide

### 4. Tests — Evidence visible

Le output `npx vitest run` doit etre visible dans les logs du rapport.
Pas de "tests passent" sans output concret.

---

## Garde-fous Detached HEAD (CRITIQUE pour workers)

**Incident #1613 :** Les workers dans worktrees peuvent se retrouver en detached HEAD sans warning. Les commits en detached HEAD sont perdus quand le worktree est nettoyé.

### Pre-commit Guard

**Avant chaque commit**, verifier que HEAD est attache :

```
git symbolic-ref HEAD
```

- Si retourne `refs/heads/<branch>` : OK, HEAD est attache
- Si erreur `fatal: ref HEAD is not a symbolic ref` : **STOP. Detached HEAD.**

### Si detached HEAD detecte

1. **NE PAS commiter.**
2. Creer une branche de recuperation immediatement :

```
git checkout -b recovery/<description>
```

3. **Taguer le rapport** : `[RECOVERY_BRANCH]` obligatoire dans le dashboard
4. Signaler au coordinateur via dashboard

### Post-commit Guard

Apres un commit, verifier :

```
git log -1 --format="%H %D"
```

Si `%D` (decoration) est vide ou ne contient pas `HEAD ->` : le commit est orphelin.

---

## Pour les orchestrateurs (delegation via new_task)

Les orchestrateurs ne committent pas directement mais **DOIVENT verifier** les artefacts rapportes par les sous-taches avant de poster `[DONE]` :

1. Le sous-agent rapporte un SHA → l'orchestrateur verifie `git cat-file -e <SHA>`
2. Le sous-agent rapporte une PR → l'orchestrateur verifie `gh pr view`

**Ne JAMAIS relayer un artefact non verifie.**

---

## Par type de mode

| Mode | Acces git | Verification |
|------|-----------|-------------|
| **-simple** | `execute_command` (win-cli) | Commands via win-cli MCP |
| **-complex** | Terminal natif | Commands directes |
| **Orchestrateurs** | Aucun (delegation) | Verifier artefacts sous-taches |

---

## Principe condense

*"Pas de SHA sans `git cat-file -e`. Pas de PR sans URL 200. Pas de `[DONE]` sur une promesse. Detached HEAD = STOP immediat."*

---

**Reference Claude :** `.claude/rules/agent-claim-discipline.md` v1.2.0
**Details harness :** `docs/harness/reference/agent-claim-discipline-detailed.md`
