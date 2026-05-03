# Agent Claim Discipline — Pas de Succes Non Verifie

**Version:** 1.3.0 (Roo, synchronisee avec .claude/rules/ v1.3.0)
**Issues :** #1605, #1613, #1666, #1697, #1786, #1798

---

## Regle Absolue

**Tu ne peux PAS declarer un travail termine en citant un artefact git sans que cet artefact soit verifiable a l'instant du rapport.**

## Pre-Claim Discipline (anti-overlap, ajoutee v1.3.0 post collision #1786)

**Avant de coder** sur un issue referencee dans un dispatch :

1. **Verifier PR concurrente** : `gh pr list --search "#NNN" --state open` — si une PR existe deja, STOP
2. **Lire dashboard workspace** : un autre agent a-t-il `[CLAIMED]` cet issue (< 2h) ?
3. **Annoncer claim AVANT modification** : poster `[CLAIMED]` sur le dashboard avec numero issue et machine
4. **Si conflit** : STOP, demander coordinateur arbitrage. Le premier `[CLAIMED]` horodate prime.

**Cout cycle 22ter** : 3 implementations paralleles de #1786 garbage_scan (PRs #233/#237/#238) = ~12h travail duplique. Cette section evite la recidive.

## Verification OBLIGATOIRE avant `[DONE]`

### 1. Commit — Confirmer que le SHA existe

```
git cat-file -e <SHA> && git branch --contains <SHA>
```

- `-simple` : via `execute_command` (win-cli MCP)
- `-complex` : via terminal natif

### 2. Push — Confirmer que la branche est sur origin

```
git ls-remote origin <BRANCH>
```

Doit retourner exactement une ligne.

### 3. PR — Confirmer l'etat de la Pull Request

```
gh pr view <N> --json state,url
```

`state` doit etre `OPEN` ou `MERGED`.

### 4. Tests — Evidence visible

Le output `npx vitest run` doit etre visible dans les logs du rapport.

## Garde-fous Detached HEAD (CRITIQUE pour workers)

**Avant chaque commit**, verifier : `git symbolic-ref HEAD`

- Si `refs/heads/<branch>` : OK
- Si erreur : **STOP. Detached HEAD.** Creer branche `recovery/<desc>` immediatement.

## Pour l'agent qui recoit/relaie

**Ne JAMAIS** traiter un artefact cite comme acquis sans verification :
- Orchestrateur : verifier artefacts rapportes par sous-taches avant de poster `[DONE]`
- Trieur : verifier PR est MERGED (pas OPEN)
- Ne JAMAIS relayer un artefact non verifie

## Par type de mode

| Mode | Acces git | Verification |
|------|-----------|-------------|
| **-simple** | `execute_command` (win-cli) | Commands via win-cli MCP |
| **-complex** | Terminal natif | Commands directes |
| **Orchestrateurs** | Aucun (delegation) | Verifier artefacts sous-taches |

---

**Principe condense** : *"Pas de SHA sans `git cat-file -e`. Pas de PR sans URL 200. Pas de `[DONE]` sur une promesse. Detached HEAD = STOP immediat. Pre-claim AVANT de coder."*

**Reference Claude :** `.claude/rules/agent-claim-discipline.md` v1.3.0
**Details harness :** `docs/harness/reference/agent-claim-discipline-detailed.md`
