# Agent Claim Discipline — No Unverified Success

**Version:** 2.0.0 (slim) — locus du claim : **issue GitHub** (ADR 017, #3676)
**Issues :** #1605, #1666 Phase A2, #1798, #3407 (pré-claim deux dépôts), word-boundary (T#80, 05/09), #3676 (locus issue)

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
   — si une PR existe deja dans l'un des deux, STOP. **Frontiere de mot OBLIGATOIRE** (`([^0-9]|$)`, pas de `\b` — fragilise par les couches de quoting bash→gh) : le filtre `--search "#NNN"` de GitHub est flou (mesure 05/09 : `#34` ramene des PRs sans rapport, meme quoté) et `#109` matche `#1091` — sans frontiere, une issue est skippee a tort.
2. **Verifier et poser le verrou SUR L'ISSUE** (locus canon depuis v2.0, ADR 017) :
   ```bash
   python scripts/github/check_issue_claim.py NNN                 # exit 1 = une AUTRE machine tient un claim actif
   python scripts/github/check_issue_claim.py NNN --claim "intention en une ligne"
   ```
   Le check precede l'**edition**, pas le push. Pas de timestamp dans le corps du claim : le `createdAt` serveur fait foi (défaut local-time-en-Z impossible par construction). Claim sans machine identifiable = fail-closed (bloque). Péremption `--stale-threshold` (défaut 24 h) : un claim étranger périmé avertit sans bloquer, mais le nouveau claimant pose quand même son `[CLAIMED]`.
   **Depot (#3768) :** `--repo` n'a plus de defaut fige. Absent, le guard classe le numero dans les **deux** depots (cle `pull_request` de l'API REST) : un seul le porte comme issue -> resolu ; les deux -> **`AMBIGUOUS`, exit 3**, desambiguisation exigee. Il ne devine jamais, parce qu'un mauvais choix ne rate pas en silence : il **pose le verrou sur l'autre depot** et laisse le vrai grain libre. Mesure du 21/09 : `check_issue_claim.py 980` rendait `BLOCKED: MERGED` en lisant la **PR parent** #980 quand l'issue submod #980 etait OPEN.
3. **Narration dashboard (bienvenue, non autoritaire)** : `roosync_dashboard(action: "append", tags: ["CLAIMED"], content: "#NNN — myia-poXXXX commencing work")` — le récit de cycle reste sur le dashboard ; le **registre de verrous** est le commentaire d'issue.
4. **Tie-break (HARD)** : un claim-issue **prime sur un claim-dashboard, même antérieur** — un seul locus fait foi (incident CoursIA #10169 : 12 min d'avance perdues sur deux locus concurrents).
5. **Si conflit** : STOP, demander coordinateur arbitrage. Le premier `[CLAIMED]` **sur l'issue** (createdAt serveur) prime.
6. **Levier du verrou** : `--release` ou commentaire `[DONE] <machine>` quand la PR atterrit.

**Cout cycle 22ter** : 3 implementations paralleles de #1786 garbage_scan (PRs #233/#237/#238) = ~12h travail duplique. Cette section evite la recidive.

**Pourquoi le locus a demenage (v2.0, #3676)** : le claim-dashboard est silo par lane, condense a 92 % par auto-condensation, et melange heure locale/UTC ; pendant l'outage GDrive du 16/08 (PR #3155) tout l'organe claim est tombe avec le dashboard (SPOF) tandis que CoursIA (claims sur issue) conservait verrous, pool et merges. Detail : [ADR 017](../../docs/harness/adr/017-issue-claim-locus.md).

## Pre-Delivery Discipline (#3224) — le claim garde le DEPART, pas la LIVRAISON

La section ci-dessus verifie l'etat du monde **avant de commencer**. Rien ne le reverifie **avant de
livrer** — or c'est entre les deux que l'etat change.

**Avant `gh pr create`, relire le dashboard workspace FRAIS** (`action: "read"`, `section: "intercom"`) **et re-checker l'issue** (`python scripts/github/check_issue_claim.py NNN`) :

1. Un `[STOP]`, un `[BLOCKED]` ou un arbitrage contraire a-t-il ete poste **depuis ton claim** ?
2. Une PR concurrente est-elle apparue depuis ? Un claim-issue concurrent a-t-il ete pose depuis ? (meme commande word-boundary que pre-claim #1 — **les deux depots**)
3. Si oui a l'un des deux : **STOP**, poster `[ASK]` et attendre — ne pas livrer « puisque c'est deja
   ecrit ». Du travail jete coute moins cher qu'une collision a demeler.

**Incident fondateur (2026-08-22, #1025/#1026)** : web1 a livre #1026 a 15:15Z alors qu'un `[REPLY]`
STOP avait ete poste a 15:00Z — quinze minutes plus tot, sur le canal qu'elle avait lu au depart et
plus jamais depuis. En parallele, le claim concurrent de po-2025 citait un etat web1 vieux de 2h30.

**La lecture au depart n'est pas une lecture a la livraison.** Un dashboard lu il y a deux heures est
une photographie, pas un etat.

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

**Garde-fous harness (worker scripts, spawn/poll, sanctions) :** [`docs/harness/reference/agent-claim-discipline-detailed.md`](../../docs/harness/reference/agent-claim-discipline-detailed.md)

**Principe condense** : *"Pas de SHA sans `git cat-file -e`. Pas de PR sans URL 200. Pas de `[DONE]` sur une promesse."*
