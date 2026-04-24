# Fermeture d'Issues — Regles Strictes

**Version:** 1.2.0
**MAJ:** 2026-04-24
**Origine:** Incident fermeture prematuree de 3 issues (#829, #850, #855) par un agent
**Update 1:** Incident batch-close web1 (#737, #760) — commentaire generique detecte (#1428)
**Update 2:** Incident issues utilisateur "meurent sans bruit" (#1666 Phase A1) — hard cap + user-originated protection + Evidence bloc obligatoire

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
- [ ] **Issue user-originated** : si `gh issue view N --json author` → `jsboige`, user a repondu dans le thread depuis la derniere action agent

## Hard Cap de Fermetures par Session Agent

**Maximum 3 fermetures d'issues par session coordinateur/executor sans approbation utilisateur explicite.**

Au-dela de 3, l'agent DOIT :
1. S'arreter
2. Poster sur dashboard workspace : `[ASK] Je souhaite fermer N issues supplementaires ce cycle. Liste : #X, #Y, #Z avec justifications. Approbation ?`
3. Attendre `APPROVE_BATCH_CLOSE` explicite (ou fermeture individuelle par l'utilisateur)

**Application :** Ce cap est cumulatif par **cycle `/coordinate` ou `/executor`**, pas par heure. Un agent ne peut pas enchainer 3 cycles de 3 fermetures = 9 sans approbation.

## Protection Issues User-Originated

**Une issue creee par `jsboige` (utilisateur) ne peut PAS etre fermee par un agent sans :**

| Cas | Action requise |
|---|---|
| PR merge couvrant 100% scope + user a comment post-merge | OK, fermer avec ref PR |
| PR merge mais user n'a PAS commente depuis | **STOP** — poster un comment invitant l'user a valider, attendre |
| User a ecrit `wontfix` / `not planned` / `ferme-moi ca` dans le thread | OK, fermer avec quote |
| Agent juge que "c'est resolu" mais user n'a pas confirme | **INTERDIT** — escalader dashboard |
| Doublon d'une autre issue user-originated | Verifier que les 2 threads sont lies, commenter les deux, attendre user |

**Test rapide avant close :**
```bash
gh issue view N --repo jsboige/roo-extensions --json author,comments --jq '{author:.author.login, last_user_comment:(.comments | map(select(.author.login=="jsboige")) | last | {date:.createdAt[:10], body:.body[:100]})}'
```

**CAVEAT CRITIQUE : les agents s'authentifient AUSSI en `jsboige`.** Un comment "author login: jsboige" peut etre :
- Un message humain (jsboige reel)
- Un comment d'agent coordinateur ai-01 (qui utilise `gh` avec le token jsboige)
- Un comment de worker Roo scheduler (qui utilise le meme token)

**Heuristique pour distinguer** : le body contient une de ces signatures ⇒ c'est un agent, PAS un humain :
- `🤖 Generated with` / `Co-Authored-By: Claude`
- `[ai-01]`, `[po-2023]`, `[po-2024]`, `[po-2025]`, `[po-2026]`, `[web1]`, `[myia-ai-01]` ...
- `[CLAIMED]`, `[RESULT]`, `[DISPATCH]`, `[DONE]`
- `## Validation ai-01`, `## Evidence`, `## Cross-machine status`
- `msg-YYYYMMDDThhmmss-xxxxxx` (format RooSync message-id)

Si le dernier `jsboige` comment contient une de ces signatures, le traiter comme **agent-authored** et continuer d'attendre une confirmation HUMAINE reelle (un comment sans signatures agent). Si 72h sans reponse humaine : escalader dashboard `[ASK]`, **NE PAS fermer**.

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
