# Agent Claim Discipline — No Unverified Success

**Version:** 3.0.0 (lot 2 campagne #2368 — déduplication : identité/dépôt déjà relocalisés verbatim en claudish#445, la règle ne porte plus que les lignes dures ; 2.4.0 #4221)
**Issues :** #1605, #1666 Phase A2, #1798, #3407 (pré-claim deux dépôts), #3676 (locus issue), #4114 (identité lane), #4221 (worktree) — mesure word-boundary T#80 05/09

---

## Regle Absolue

**Un agent ne peut PAS declarer un travail termine en citant un artefact git sans que cet artefact soit verifiable a l'instant du rapport.**

## Pre-Claim Discipline (anti-overlap, ajoutee v1.3.0 post collision #1786)

**Avant de coder** sur un issue référencé dans un dispatch :

1. **Verifier PR concurrente — dans les DEUX depots** (une PR submodule vit dans `jsboige/jsboige-mcp-servers`, invisible au check single-repo — trou #3407 : #1091 ouverte 26 h, non vue) :
   ```bash
   for R in jsboige/roo-extensions jsboige/jsboige-mcp-servers; do
     gh pr list --repo "$R" --state open --json number,author,title \
       --jq '.[] | select(.title | test("#NNN([^0-9]|$)"))'
   done
   ```
   — une PR dans l'un des deux = **STOP**. **Frontiere de mot OBLIGATOIRE** (`([^0-9]|$)`, jamais `\b`) : `--search` est flou et `#109` matche `#1091` (mesures : doc détaillée §Frontière de mot).
2. **Verifier et poser le verrou SUR L'ISSUE** (locus canon depuis v2.0, ADR 017) :
   ```bash
   python scripts/github/check_issue_claim.py NNN                 # exit 1 = une AUTRE lane tient un claim actif
   python scripts/github/check_issue_claim.py NNN --claim "intention en une ligne"
   ```
   Le check precede l'**edition**, pas le push. Pas de timestamp dans le corps : le `createdAt` serveur fait foi. Claim sans machine identifiable = fail-closed (bloque). Péremption `--stale-threshold` (défaut 24 h) : un claim étranger périmé avertit sans bloquer, mais le nouveau claimant pose quand même son `[CLAIMED]`.
   **Identité de claim = lane `machine:workspace` (#4114)** : worktree lié → toplevel du checkout principal (#4122) ; `--workspace` surcharge le suffixe, `--agent` remplace l'id entier. Même machine + workspace différent = claim **étranger** ; claim legacy machine-seul vu de sa machine = **étranger fail-closed** (`LEGACY_CLAIM`) ; **la levée porte la MÊME identité que la pose** (verrou legacy : `--agent <machine>`, ou péremption 24 h). Texte intégral et motifs : doc détaillée §Gardes identité.
   **Depot (#3768) :** sans `--repo`, le guard classe le numero dans les **deux** depots — un seul le porte → resolu ; les deux → **`AMBIGUOUS`, exit 3** ; **un depot injoignable → exit 2**, jamais de resolution vers celui qui a repondu (un 403 de limite ≠ 404). Texte intégral : doc détaillée §Dépôt.
3. **Narration dashboard (bienvenue, non autoritaire)** : `roosync_dashboard(action: "append", tags: ["CLAIMED"], content: "#NNN — myia-poXXXX commencing work")` — le récit de cycle reste sur le dashboard ; le **registre de verrous** est le commentaire d'issue.
4. **Tie-break (HARD)** : un claim-issue **prime sur un claim-dashboard, même antérieur** — un seul locus fait foi (incident CoursIA #10169).
5. **Si conflit** : STOP, demander coordinateur arbitrage. Le premier `[CLAIMED]` **sur l'issue** (createdAt serveur) prime.
6. **Levier du verrou** : `--release` ou commentaire `[DONE] <lane>` quand la PR atterrit — sous la MÊME identité que la pose (#4114).

## Pre-Delivery Discipline (#3224) — le claim garde le DEPART, pas la LIVRAISON

La section ci-dessus verifie l'etat du monde **avant de commencer**. Rien ne le reverifie **avant de livrer** — or c'est entre les deux que l'etat change.

**Avant `gh pr create`, relire le dashboard workspace FRAIS** (`action: "read"`, `section: "intercom"`) **et re-checker l'issue** (`python scripts/github/check_issue_claim.py NNN`) :

1. Un `[STOP]`, un `[BLOCKED]` ou un arbitrage contraire a-t-il ete poste **depuis ton claim** ?
2. Une PR concurrente est-elle apparue depuis ? Un claim-issue concurrent a-t-il ete pose depuis ? (meme commande word-boundary que pre-claim #1 — **les deux depots**)
3. Si oui a l'un des deux : **STOP**, poster `[ASK]` et attendre — ne pas livrer « puisque c'est deja ecrit ». Du travail jete coute moins cher qu'une collision a demeler. **La lecture au depart n'est pas une lecture a la livraison** (incident fondateur #1025/#1026 : doc détaillée).
4. **Ecrire dans un worktree existant (#4221) : relire d'abord le claim de l'issue qu'il porte** — le claim protege l'issue, pas l'arbre de travail. Avant tout Edit/Write/commit dans un worktree que tu n'as pas cree dans ce tour (reprise, compaction, `wt-*`/`mcpint-*` trouve sur disque) : `check_issue_claim.py NNN` sur l'issue que son nom porte ; claim d'une autre lane = ne pas ecrire, `[ASK]` ; claim de ta lane absent de ton contexte (tour courant ou resume de compaction) = celui d'une session jumelle, meme traitement (3 collisions en 24 h : doc détaillée #4221).

## Discipline requise — Pour l'agent qui rapporte

**Avant** de poster `[DONE]`/`[RESULT]` avec un artefact :

1. **Commit** : `git cat-file -e <SHA> && git branch --contains <SHA>` — sinon NE PAS le citer
2. **Push** : `git ls-remote origin <BRANCH>` — doit retourner une ligne
3. **PR** : `gh pr view <N> --json state,url` — doit retourner state + url valide
4. **Tests** : Le output vitest doit etre visible dans les logs

## Pour l'agent qui recoit/relaie

**Ne JAMAIS** traiter un artefact cite comme acquis sans verification :
- Coordinateur : verifier avant d'archiver
- Trieur : verifier PR est MERGED (pas OPEN)
- Meta-analyste : "reussites rapportees" = donnees brutes a qualifier

---

**Garde-fous harness (worker scripts, spawn/poll, sanctions), récits fondateurs (coût cycle 22ter, locus v2.0/#3676, incident #1025/#1026, mesure #980 du 21/09), détail des gardes identité (#4114, worktree lié #4122) et dépôt (#3768, exit 2/3, 403≠404), ADR 017 :** [`agent-claim-discipline-detailed.md`](../../docs/harness/reference/agent-claim-discipline-detailed.md) · [`ADR 017`](../../docs/harness/adr/017-issue-claim-locus.md)

**Principe condense** : *"Pas de SHA sans `git cat-file -e`. Pas de PR sans URL 200. Pas de `[DONE]` sur une promesse."*
