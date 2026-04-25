# Fermeture d'Issues — Regles Strictes

**Version:** 3.0.0 (synced with .claude/rules/issue-closure.md v1.3.0)
**MAJ:** 2026-04-25
**Origine:** Incident fermeture prematuree (#829, #850, #855, #1428) + lacune detectee par meta-analyse cycle 2026-04-25 (#1696)

## Regle Absolue

**Une issue ne peut etre fermee que si le travail est REELLEMENT TERMINE.**

"Superseded", "duplicate", "addressed by PR" ne sont PAS des raisons suffisantes sans verification.

## Checklist OBLIGATOIRE avant fermeture

- [ ] Le travail est TERMINE (pas "en cours", pas "partiel")
- [ ] Criteres d'acceptation / checklist remplis
- [ ] Si "superseded" : issue de remplacement couvre TOUT le scope
- [ ] Si "resolved by PR" : le PR est MERGE (pas juste cree)
- [ ] **Bloc Evidence present** dans le commentaire de fermeture (voir section dediee)
- [ ] **Issue user-originated** : appliquer la grille de marqueurs (voir section "Identifier l'origine")

## Hard Cap : Max 3 Fermetures par Cycle

**Maximum 3 fermetures d'issues par cycle scheduler/orchestrator/executor sans approbation utilisateur explicite.**

Au-dela de 3, l'agent DOIT :
1. S'arreter
2. Poster sur dashboard workspace : `[ASK] Je souhaite fermer N issues supplementaires ce cycle. Liste : #X, #Y, #Z avec justifications. Approbation ?`
3. Attendre `APPROVE_BATCH_CLOSE` explicite (ou fermeture individuelle par l'utilisateur)

**Application** : Cumulatif par **cycle scheduler complet** (orchestrator-simple/complex), pas par heure. Un agent ne peut pas enchainer 3 cycles de 3 fermetures = 9 sans approbation.

## Identifier l'Origine d'une Issue (CRITIQUE)

**L'identite GitHub `jsboige` est partagee** entre l'utilisateur humain ET tous les agents (orchestrateurs, code-simple/complex, schedulers, win-cli MCP). Le champ `author.login=jsboige` ne distingue rien.

**La distinction se fait sur les marqueurs explicites dans le titre, le body, et les commentaires :**

| Signal dans titre/body/comment | Indique |
|---|---|
| Titre commence par `[META-ANALYSIS]`, `[Worker]`, `[AUDIT]`, `[CLAUDE-MACHINE]`, `[BOT]`, `[DISPATCH]`, `[REMEDIATION-*]`, `[EPIC-*]` | **Agent-originated** |
| Body contient `🤖 Generated with` ou `Co-Authored-By: Claude` ou `Co-Authored-By: Roo` | **Agent-originated** |
| Body contient `[ai-01]`, `[po-2023]`, `[po-2024]`, `[po-2025]`, `[po-2026]`, `[web1]`, `[myia-ai-01]`, `[myia-po-*]`, `[myia-web*]` | **Agent-originated** |
| Body contient `[CLAIMED]`, `[RESULT]`, `[DISPATCH]`, `[DONE]`, `[ASK]`, `[REPLY]`, `[ACK]`, `[PROPOSAL]` | **Agent-originated** |
| Body contient `## Validation ai-01`, `## Evidence`, `## Cross-machine status`, `## Donnees brutes` | **Agent-originated** |
| Body contient `msg-YYYYMMDDThhmmss-xxxxxx` (format RooSync message-id) | **Agent-originated** |
| Body contient `gh api`, `gh pr view`, `npx vitest`, `execute_command` ou autres outputs CLI bruts | Probable **agent-originated** |
| Aucun marqueur ci-dessus + style narratif francais conversationnel | Probable **user-originated** |
| Aucun marqueur ci-dessus + scope ouvert / question floue / "il faudrait que..." | Probable **user-originated** |

**Regle de defaut** : en l'absence d'AUCUN marqueur agent identifiable -> **presumer user-originated** (presomption protectrice).

## Quand un Agent Roo Peut Fermer

| Cas | Action requise |
|---|---|
| Issue **agent-originated** (porte un marqueur ci-dessus) + work done + bloc Evidence | OK, fermer |
| Issue **user-originated** + PR merge couvrant 100% scope + user a comment post-merge **sans signature agent** | OK, fermer avec ref PR + quote du comment user |
| Issue **user-originated** + PR merge mais user n'a PAS commente depuis | **STOP** — poster un comment invitant l'user a valider, attendre 72h, escalader dashboard `[ASK]` |
| User a ecrit `wontfix` / `not planned` / `ferme-moi ca` **sans signature agent** | OK, fermer avec quote |
| Agent juge que "c'est resolu" mais aucune confirmation user verifiable | **INTERDIT** — escalader dashboard `[ASK]` |
| Doublon d'une autre issue user-originated | Verifier que les 2 threads sont lies, commenter les deux, attendre user |

## Bloc Evidence OBLIGATOIRE dans le Commentaire de Fermeture

Tout commentaire de fermeture (via win-cli MCP `gh issue close N --comment "..."`) DOIT contenir un bloc `## Evidence` avec au moins une ligne parmi :

```markdown
## Evidence

- **PR merge** : https://github.com/OWNER/REPO/pull/NNN (merged YYYY-MM-DD)
- **Commit** : SHA40chars (reachable from origin/main)
- **Test passing** : `npx vitest run src/path/test.ts` -> 15/15 (output dans PR #NNN)
- **User approval** : dashboard message msg-YYYYMMDDThhmmss-xxxxxx OR issue comment by jsboige on YYYY-MM-DD
- **Obsolete** : fonctionnalite supprimee dans commit SHA + grep `<term>` -> 0 hits
- **Duplicate** : #MMM (ouverte, scope identique section X)
```

**Interdits :**
- "Resolved by recent improvements"
- "Addressed in multiple PRs"
- "Superseded" (sans ref precise)
- "Obsolete" (sans preuve de suppression)
- `[CLAIMED]` / `Executed by...` d'un autre agent (claim != result)

## Interdictions (Rappel)

- **JAMAIS** fermer "not planned" pour contourner le bot checklist
- **JAMAIS** fermer sur la base d'un CLAIM sans RESULT verifie
- **JAMAIS** fermer en batch sans lire chaque issue
- **JAMAIS** utiliser un commentaire generique pour fermer (test : si copie-collable sur 3+ issues sans modif, c'est un batch-close interdit, incident #1428)
- **"won't fix" / "not planned"** : reserve au coordinateur interactif Claude avec accord utilisateur OU a l'utilisateur directement

## Si le Bot Checklist Rouvre une Issue

C'est normal — la checklist n'est pas complete. Options :
1. Completer le travail
2. Mettre a jour la checklist (retirer items hors scope avec justification)
3. Laisser ouverte

**JAMAIS** contourner le bot avec `--reason "not planned"` quand le travail est partiellement fait. C'est une falsification (incident #1428).

## Specificites Roo (vs Claude)

- **Modes orchestrator-simple/complex** ne ferment QUE des issues qu'ils ont creees eux-memes (marqueur `[Worker]`, `[CLAIMED]`, `[META-ANALYSIS]`, `[AUDIT]`)
- **Modes code-simple/complex** ne ferment AUCUNE issue (laisser au orchestrator/coordinator)
- **Schedulers** : appliquer le hard cap 3/cycle de maniere stricte. Tout depassement = `[ASK]` sur dashboard workspace, attendre cycle suivant
- **Win-cli MCP** : utiliser `gh issue view N --json` pour verifier l'auteur ET les marqueurs avant tout `gh issue close`

---
**Historique :**
- v2.1.0 (2026-04-19) : Sync Claude v1.1.0 (commentaire generique anti-pattern)
- v3.0.0 (2026-04-25) : Sync Claude v1.3.0 — Hard cap 3/cycle + marqueurs explicites user-originated + bloc Evidence + lacune comblee (#1696)
