# Fermeture d'Issues — Regles Strictes

**Version:** 1.0.0
**MAJ:** 2026-04-06
**Origine:** Incident fermeture prematuree de 3 issues (#829, #850, #855) par un agent

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

Le triage en batch est autorise pour LISTER les candidats a la fermeture. La fermeture elle-meme doit etre **individuelle et justifiee**.

## Raisons de fermeture legitimes

| Raison | Preuve requise |
|--------|---------------|
| **Resolved** | PR merge + criteres remplis |
| **Duplicate** | Autre issue OUVERTE + meme scope exact |
| **Won't fix** | Decision UTILISATEUR explicite (pas agent) |
| **Not planned** | Decision UTILISATEUR explicite (pas agent) |
| **Obsolete** | La fonctionnalite/bug n'existe plus (verifiable) |

## Qui peut fermer en "won't fix" / "not planned" ?

**Uniquement le coordinateur interactif avec approbation utilisateur**, ou l'utilisateur directement. Les agents schedulers et executeurs ne peuvent fermer qu'en "resolved" avec preuve.

---

**Historique :** Cree apres incident 2026-04-06 ou un agent a ferme 3 issues (#829, #850, #855) avec "not planned" pour contourner le bot checklist, masquant du travail non termine.
