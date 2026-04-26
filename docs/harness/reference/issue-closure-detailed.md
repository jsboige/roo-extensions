# Fermeture d'Issues — Reference Detaillee

**Version:** 1.3.0
**Source :** `.claude/rules/issue-closure.md` (version slim)
**Origine :** Incident fermeture prematuree de 3 issues (#829, #850, #855)

---

## Grille de Marqueurs — Identifier l'Origine d'une Issue

L'identite GitHub `jsboige` est **partagee** entre l'utilisateur humain ET tous les agents. La distinction se fait sur les marqueurs explicites :

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

---

## Quand un Agent Peut Fermer

| Cas | Action requise |
|---|---|
| Issue **agent-originated** (porte un marqueur ci-dessus) + work done + bloc Evidence | OK, fermer |
| Issue **user-originated** + PR merge couvrant 100% scope + user a comment post-merge **sans signature agent** | OK, fermer avec ref PR + quote du comment user |
| Issue **user-originated** + PR merge mais user n'a PAS commente depuis | **STOP** — poster un comment invitant l'user a valider, attendre 72h, escalader dashboard `[ASK]` |
| User a ecrit `wontfix` / `not planned` / `ferme-moi ca` **sans signature agent** | OK, fermer avec quote |
| Agent juge que "c'est resolu" mais aucune confirmation user verifiable | **INTERDIT** — escalader dashboard `[ASK]` |
| Doublon d'une autre issue user-originated | Verifier que les 2 threads sont lies, commenter les deux, attendre user |

---

## Identifier une "Confirmation Humaine Reelle"

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

---

## Raisons de Fermeture Legitimes

| Raison | Preuve requise (bloc Evidence) |
|--------|---------------|
| **Resolved** | PR merge URL + criteres remplis cites |
| **Duplicate** | Autre issue OUVERTE + meme scope exact + link croise pose sur les deux |
| **Won't fix** | Decision UTILISATEUR explicite (pas agent), quote du message user |
| **Not planned** | Decision UTILISATEUR explicite (pas agent), quote du message user |
| **Obsolete** | La fonctionnalite/bug n'existe plus (commit SHA + grep demonstrant absence) |

---

## Audit /coordinate Obligatoire

A chaque cycle `/coordinate`, le coordinateur DOIT en phase initiale :

1. Lister les fermetures des dernieres 24h :
   ```bash
   gh issue list --repo jsboige/roo-extensions --state closed \
     --search "closed:>$(date -d '24 hours ago' +%Y-%m-%d)" \
     --limit 40 --json number,title,stateReason,author,closedAt
   ```
2. Pour chaque fermeture, verifier qu'elle respecte les 3 clauses (hard cap, user-originated, evidence bloc).
3. Si violation detectee : rouvrir avec comment `[AUDIT-ROLLBACK]`, escalader a l'utilisateur via dashboard `[ASK]`.
4. Au moins 1 violation 3 cycles de suite -> poster issue `[META]` needs-approval.

---

## Qui Peut Fermer en "won't fix" / "not planned" ?

**Uniquement le coordinateur interactif avec approbation utilisateur**, ou l'utilisateur directement. Les agents schedulers et executeurs ne peuvent fermer qu'en "resolved" avec preuve et uniquement sur leurs propres issues (pas user-originated).

---

## Historique

- 2026-04-06 : v1.0.0 — Cree apres incident fermeture prematuree de 3 issues (#829, #850, #855)
- 2026-04-17 : v1.1.0 — Ajout anti-pattern commentaire generique (incident #1428)
- 2026-04-24 : v1.2.0 — Hard cap 3/cycle + protection user-originated + bloc Evidence (#1666 Phase A1)
- 2026-04-25 : v1.3.0 — Grille de marqueurs explicites au lieu de l'identite GitHub `author=jsboige`
