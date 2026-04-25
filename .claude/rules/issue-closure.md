# Fermeture d'Issues — Regles Strictes

**Version:** 1.3.0
**MAJ:** 2026-04-25
**Origine:** Incident fermeture prematuree de 3 issues (#829, #850, #855) par un agent
**Update 1:** Incident batch-close web1 (#737, #760) — commentaire generique detecte (#1428)
**Update 2:** Incident issues utilisateur "meurent sans bruit" (#1666 Phase A1) — hard cap + user-originated protection + Evidence bloc obligatoire
**Update 3 (v1.3.0, 2026-04-25):** Correction du critere user-originated : l'identite GitHub `jsboige` est partagee entre l'humain ET tous les agents (cycle 12 user feedback). La distinction repose desormais sur les **marqueurs explicites** (signatures dans titre/body/comments), pas sur l'identite GitHub `author`.

---

## Regle Absolue

**Une issue ne peut etre fermee que si le travail decrit est REELLEMENT TERMINE.**

"Superseded", "duplicate", "addressed by PR" ne sont PAS des raisons suffisantes sans verification.

## Checklist OBLIGATOIRE avant fermeture

- [ ] **Le travail est-il termine ?** Pas "en cours", pas "partiellement fait" — TERMINE.
- [ ] **Les criteres d'acceptation sont-ils remplis ?** Si l'issue a une checklist, les items sont-ils coches ?
- [ ] **Si "superseded" :** L'issue de remplacement couvre-t-elle TOUT le scope ? Les items non faits sont-ils explicitement repris ?
- [ ] **Si "duplicate" :** L'autre issue est-elle OUVERTE et couvre le meme scope exact ?
- [ ] **Si "resolved by PR" :** Le PR est-il MERGE (pas juste cree) et couvre-t-il tout le scope ?
- [ ] **Bloc Evidence present** (voir section plus bas) : PR URL, commit SHA, ou user approval message-id
- [ ] **Issue user-originated** : appliquer la grille de marqueurs (voir section "Identifier l'origine d'une issue" plus bas). Si aucun marqueur agent identifiable -> presumer user-originated, exiger confirmation humaine reelle

## Hard Cap de Fermetures par Session Agent

**Maximum 3 fermetures d'issues par session coordinateur/executor sans approbation utilisateur explicite.**

Au-dela de 3, l'agent DOIT :
1. S'arreter
2. Poster sur dashboard workspace : `[ASK] Je souhaite fermer N issues supplementaires ce cycle. Liste : #X, #Y, #Z avec justifications. Approbation ?`
3. Attendre `APPROVE_BATCH_CLOSE` explicite (ou fermeture individuelle par l'utilisateur)

**Application :** Ce cap est cumulatif par **cycle `/coordinate` ou `/executor`**, pas par heure. Un agent ne peut pas enchainer 3 cycles de 3 fermetures = 9 sans approbation.

## Protection Issues User-Originated

**Une issue ne peut PAS etre fermee par un agent sauf si l'agent peut prouver l'origine agent OU obtient une confirmation humaine reelle.**

### Identifier l'origine d'une issue (marqueurs explicites)

L'identite GitHub `jsboige` est **partagee** entre l'utilisateur humain ET tous les agents (coordinateurs, schedulers, workers). Le champ `author.login=jsboige` ne distingue rien.

**La distinction se fait sur les marqueurs explicites dans le titre, le body, et les commentaires :**

| Signal dans titre/body/comment | Indique |
|---|---|
| Titre commence par `[META-ANALYSIS]`, `[Worker]`, `[AUDIT]`, `[CLAUDE-MACHINE]`, `[BOT]`, `[DISPATCH]`, `[REMEDIATION-*]`, `[EPIC-*]` | **Agent-originated** |
| Body contient `🤖 Generated with` ou `Co-Authored-By: Claude` ou `Co-Authored-By: Roo` | **Agent-originated** |
| Body contient `[ai-01]`, `[po-2023]`, `[po-2024]`, `[po-2025]`, `[po-2026]`, `[web1]`, `[myia-ai-01]`, `[myia-po-*]`, `[myia-web*]` | **Agent-originated** |
| Body contient `[CLAIMED]`, `[RESULT]`, `[DISPATCH]`, `[DONE]`, `[ASK]`, `[REPLY]`, `[ACK]`, `[PROPOSAL]` | **Agent-originated** |
| Body contient `## Validation ai-01`, `## Evidence`, `## Cross-machine status`, `## Donnees brutes` | **Agent-originated** |
| Body contient `msg-YYYYMMDDThhmmss-xxxxxx` (format RooSync message-id) | **Agent-originated** |
| Body contient `gh api`, `gh pr view`, `npx vitest` ou autres outputs CLI bruts | Probable **agent-originated** |
| Aucun marqueur ci-dessus + style narratif francais conversationnel | Probable **user-originated** |
| Aucun marqueur ci-dessus + scope ouvert / question floue / "il faudrait que..." | Probable **user-originated** |

**Regle de defaut** : en l'absence d'AUCUN marqueur agent identifiable -> **presumer user-originated** (presomption protectrice).

### Quand un agent peut fermer

| Cas | Action requise |
|---|---|
| Issue **agent-originated** (porte un marqueur ci-dessus) + work done + bloc Evidence | OK, fermer |
| Issue **user-originated** + PR merge couvrant 100% scope + user a comment post-merge **sans signature agent** | OK, fermer avec ref PR + quote du comment user |
| Issue **user-originated** + PR merge mais user n'a PAS commente depuis | **STOP** — poster un comment invitant l'user a valider, attendre 72h, escalader dashboard `[ASK]` |
| User a ecrit `wontfix` / `not planned` / `ferme-moi ca` **sans signature agent** | OK, fermer avec quote |
| Agent juge que "c'est resolu" mais aucune confirmation user verifiable | **INTERDIT** — escalader dashboard `[ASK]` |
| Doublon d'une autre issue user-originated | Verifier que les 2 threads sont lies, commenter les deux, attendre user |

### Comment identifier une "confirmation humaine reelle"

Un commentaire de `jsboige` qui ne porte AUCUN des marqueurs agent ci-dessus. Style narratif (francais conversationnel, sans output CLI brut, sans tableau formel, sans `## Evidence`).

**Test bash :**
```bash
# Recupere les 5 derniers commentaires + verifie absence de marqueurs agent
gh issue view N --repo jsboige/roo-extensions --json comments \
  --jq '.comments | map(select(.author.login=="jsboige")) | reverse | .[0:5] | .[] | {date:.createdAt[:10], body:.body[:200]}' | \
  grep -vE '🤖|Co-Authored-By|\[ai-01\]|\[po-|\[web|\[CLAIMED\]|\[RESULT\]|\[DONE\]|\[ASK\]|\[REPLY\]|## Evidence|msg-2026'
```

Si 0 ligne ressort -> aucune confirmation humaine, **NE PAS fermer**, escalader.

Si 72h sans reponse humaine reelle apres notification : escalader dashboard `[ASK]`, **NE PAS fermer**.

## Bloc Evidence OBLIGATOIRE dans le Comment de Fermeture

Tout comment de fermeture (`gh issue close N --comment "..."`) DOIT contenir un bloc `## Evidence` avec au moins une ligne parmi :

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

## Interdictions

### JAMAIS fermer "not planned" pour contourner le bot checklist

Le bot checklist existe pour une raison : il detecte les fermetures prematurees. Contourner le bot avec `--reason "not planned"` quand le travail est en fait partiellement fait est une **falsification**. C'est le pattern exact qui a cause la perte de suivi sur 3 issues.

**Si le bot rouvre une issue :** C'est que la checklist n'est pas complete. Soit :
1. Completer la checklist (faire le travail)
2. Mettre a jour la checklist (retirer les items hors scope avec justification)
3. Laisser l'issue ouverte (le travail n'est pas fini)

### JAMAIS fermer sur la base d'un CLAIM sans RESULT

Un commentaire `[CLAIMED]` ou `Executed by...` ne prouve PAS que le travail est fait. Verifier :
- Le PR existe ET est merge
- Ou le commentaire `[RESULT]` decrit le travail accompli avec preuves

### JAMAIS fermer en batch sans lire chaque issue

Le triage en batch est autorise pour LISTER les candidats a la fermeture. La fermeture elle-meme doit etre **individuelle et justifiee**. Voir "Hard Cap" ci-dessus.

### JAMAIS utiliser un commentaire generique pour fermer

Chaque commentaire de fermeture doit **refleter le contenu** de l'issue concernee. Un commentaire comme "dépassé par améliorations récentes" appliqué a plusieurs issues sans rapport est un signal de batch-close sans lecture individuelle (incident #1428).

**Test :** Si le meme commentaire peut etre copie-colle sur 3+ issues sans modification, c'est un batch-close.

## Audit /coordinate Obligatoire

A chaque cycle `/coordinate`, le coordinateur DOIT en phase initiale :

1. Lister les fermetures des dernieres 24h :
   ```bash
   gh issue list --repo jsboige/roo-extensions --state closed \
     --search "closed:>$(date -d '24 hours ago' +%Y-%m-%d)" \
     --limit 40 --json number,title,stateReason,author,closedAt
   ```
2. Pour chaque fermeture, verifier qu'elle respecte les 3 nouvelles clauses (hard cap, user-originated, evidence bloc).
3. Si violation detectee : rouvrir avec comment `[AUDIT-ROLLBACK]` explicitant la clause violee, escalader a l'utilisateur via dashboard `[ASK]`.
4. Au moins 1 violation 3 cycles de suite -> poster issue `[META]` needs-approval.

## Raisons de fermeture legitimes

| Raison | Preuve requise (bloc Evidence) |
|--------|---------------|
| **Resolved** | PR merge URL + criteres remplis cites |
| **Duplicate** | Autre issue OUVERTE + meme scope exact + link croise pose sur les deux |
| **Won't fix** | Decision UTILISATEUR explicite (pas agent), quote du message user |
| **Not planned** | Decision UTILISATEUR explicite (pas agent), quote du message user |
| **Obsolete** | La fonctionnalite/bug n'existe plus (commit SHA + grep demonstrant absence) |

## Qui peut fermer en "won't fix" / "not planned" ?

**Uniquement le coordinateur interactif avec approbation utilisateur**, ou l'utilisateur directement. Les agents schedulers et executeurs ne peuvent fermer qu'en "resolved" avec preuve et uniquement sur leurs propres issues (pas user-originated).

---

**Historique :**
- 2026-04-06 : v1.0.0 — Cree apres incident fermeture prematuree de 3 issues (#829, #850, #855)
- 2026-04-17 : v1.1.0 — Ajout anti-pattern commentaire generique (incident #1428, batch-close web1 #737/#760)
- 2026-04-24 : v1.2.0 — Hard cap 3/cycle + protection user-originated + bloc Evidence + audit /coordinate (#1666 Phase A1)
- 2026-04-25 : v1.3.0 — Correction critere user-originated : grille de marqueurs explicites au lieu de l'identite GitHub `author=jsboige` (cycle 12 user feedback : "la plupart des agents travaillent sous mon identite")
