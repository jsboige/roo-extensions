# Agent Claim Discipline — Pas de Succes Non Verifie

**Version:** 2.0.0 (Roo, synchronisee avec .claude/rules/ v2.0.0 — locus du claim : issue GitHub, ADR 017 / #3676)
**Issues :** #1605, #1613, #1666, #1697, #1786, #1798, #3224, #3407 (pre-claim deux depots), #3676 (locus issue)

---

## Regle Absolue

**Tu ne peux PAS declarer un travail termine en citant un artefact git sans que cet artefact soit verifiable a l'instant du rapport.**

## Pre-Claim Discipline (anti-overlap, ajoutee v1.3.0 post collision #1786)

**Avant de coder** sur un issue referencee dans un dispatch :

1. **Verifier PR concurrente — dans les DEUX depots** (une PR submodule vit dans `jsboige/jsboige-mcp-servers`, invisible au check single-repo — trou #3407) :
   ```bash
   for R in jsboige/roo-extensions jsboige/jsboige-mcp-servers; do
     gh pr list --repo "$R" --state open --json number,title \
       --jq '.[] | select(.title | test("#NNN([^0-9]|$)"))'
   done
   ```
   — si une PR existe deja dans l'un des deux, STOP. **Frontiere de mot OBLIGATOIRE** (`([^0-9]|$)`, pas `\b`) : le filtre `--search "#NNN"` de GitHub est flou et `#109` matche `#1091` — sans frontiere, une issue est skippee a tort.
2. **Verifier et poser le verrou SUR L'ISSUE** (locus canon depuis v2.0, ADR 017) :
   ```bash
   python scripts/github/check_issue_claim.py NNN                 # exit 1 = une AUTRE machine tient un claim actif
   python scripts/github/check_issue_claim.py NNN --claim "intention en une ligne"
   ```
   Le check precede l'**edition**, pas le push. Pas de timestamp dans le corps du claim : le `createdAt` serveur fait foi. Claim sans machine identifiable = fail-closed (bloque). Péremption `--stale-threshold` (défaut 24 h) : un claim étranger périmé avertit sans bloquer, mais le nouveau claimant pose quand même son `[CLAIMED]`.
   **Depot (#3768) :** `--repo` n'a plus de defaut fige. Absent, le guard classe le numero dans les **deux** depots (cle `pull_request` de l'API REST) : un seul le porte comme issue -> resolu ; les deux -> **`AMBIGUOUS`, exit 3**, desambiguisation exigee ; **un seul depot injoignable -> exit 2**, il refuse au lieu de resoudre vers celui qui a repondu. Il ne devine jamais, **y compris quand la mesure echoue**, parce qu'un mauvais choix ne rate pas en silence : il **pose le verrou sur l'autre depot** et laisse le vrai grain libre. Un 403 de limite secondaire n'est pas un 404 — « l'instrument n'a rien rendu » n'est jamais « il n'y a rien », et la flotte rencontre cette limite aux heures actives. Mesure du 21/09 : `check_issue_claim.py 980` rendait `BLOCKED: MERGED` en lisant la **PR parent** #980 quand l'issue submod #980 etait OPEN.
3. **Narration dashboard (bienvenue, non autoritaire)** : le `[CLAIMED]` dashboard reste le récit de cycle ; le **registre de verrous** est le commentaire d'issue. Un claim-issue **prime sur un claim-dashboard, même antérieur** (tie-break HARD, un seul locus fait foi).
4. **Si conflit** : STOP, demander coordinateur arbitrage. Le premier `[CLAIMED]` **sur l'issue** (createdAt serveur) prime.
5. **Levier du verrou** : `--release` ou commentaire `[DONE]`/`[RESULT]` `<machine>` quand la PR atterrit.

**Cout cycle 22ter** : 3 implementations paralleles de #1786 garbage_scan (PRs #233/#237/#238) = ~12h travail duplique. Cette section evite la recidive.

**Pourquoi le locus a demenage (v2.0, #3676)** : le claim-dashboard est silo par lane, condense a 92 % par auto-condensation, et tombe entier pendant les outages GDrive (SPOF, #3155). Detail : `docs/harness/adr/017-issue-claim-locus.md`.

## Pre-Delivery Discipline (#3224) — le claim garde le DEPART, pas la LIVRAISON

La section ci-dessus verifie l'etat du monde **avant de commencer**. Rien ne le reverifie **avant de
livrer** — or c'est entre les deux que l'etat change.

**Avant `gh pr create`, relire le dashboard workspace FRAIS** (`action: "read"`, `section: "intercom"`) **et re-checker l'issue** (`python scripts/github/check_issue_claim.py NNN`) :

1. Un `[STOP]`, un `[BLOCKED]` ou un arbitrage contraire a-t-il ete poste **depuis ton claim** ?
2. Une PR concurrente est-elle apparue depuis ? Un claim-issue concurrent a-t-il ete pose depuis ? (meme commande word-boundary que pre-claim #1 — **les deux depots**)
3. Si oui a l'un des deux : **STOP**, poster `[ASK]` et attendre — ne pas livrer « puisque c'est
   deja ecrit ». Du travail jete coute moins cher qu'une collision a demeler.

**Incident fondateur (2026-08-22, #1025/#1026)** : web1 a livre #1026 a 15:15Z alors qu'un `[REPLY]`
STOP avait ete poste a 15:00Z — quinze minutes plus tot, sur le canal qu'elle avait lu au depart et
plus jamais depuis. En parallele, le claim concurrent de po-2025 citait un etat web1 vieux de 2h30.

**La lecture au depart n'est pas une lecture a la livraison.** Un dashboard lu il y a deux heures
est une photographie, pas un etat.

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

**Principe condense** : *"Pas de SHA sans `git cat-file -e`. Pas de PR sans URL 200. Pas de `[DONE]` sur une promesse. Detached HEAD = STOP immediat. Pre-claim AVANT de coder, sur l'issue."*

**Reference Claude :** `.claude/rules/agent-claim-discipline.md` v2.0.0
**Details harness :** `docs/harness/reference/agent-claim-discipline-detailed.md` · `docs/harness/adr/017-issue-claim-locus.md`
