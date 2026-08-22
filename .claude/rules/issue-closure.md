# Fermeture d'Issues — Regles Strictes

**Version:** 1.4.0 (slim)
**MAJ:** 2026-08-22

---

## Regle Absolue

**Une issue ne peut etre fermee que si le travail est REELLEMENT TERMINE.**

## Checklist avant fermeture

- Travail termine (pas "en cours" ni "partiel")
- Criteres d'acceptation remplis
- Si "superseded" : remplacement couvre TOUT
- Si "duplicate" : autre issue OUVERTE, meme scope exact
- Si "resolved by PR" : PR MERGE (pas juste cree), couvre tout le scope
- **Bloc Evidence** avec PR URL, commit SHA, ou user approval
- **Issue user-originated** : grille de marqueurs → si aucun marqueur agent, presumer user-originated → exiger confirmation humaine

## Hard Cap

**Max 3 fermetures/session** sans approbation utilisateur. Au-dela : poster `[ASK]` sur dashboard.

## Bloc Evidence (OBLIGATOIRE)

```markdown
## Evidence
- **PR merge** : URL (merged DATE)
- **Commit** : SHA (reachable from origin/main)
- **User approval** : comment by jsboige on DATE
- **Obsolete** : commit SHA + grep → 0 hits
- **Duplicate** : #MMM (ouverte, scope identique)
```

**Interdits :** "Resolved by recent improvements", "Superseded" sans ref, `[CLAIMED]` d'un agent.

## Fermer n'est pas fermé (#3033, #3225)

Le bot de checklist **rouvre** l'issue ~4 min plus tard si des cases restent décochées. Une session
qui rapporte « fermée » sur le retour immédiat de son action rapporte donc régulièrement du faux.

**Ça vaut pour les deux chemins de fermeture — et le second est celui qu'on oublie :**

| Chemin | Ce qui rend « succès » tout de suite | Le bot statue |
|---|---|---|
| `gh issue close N` | le code de retour de la commande | ~4 min après |
| **un merge portant `Closes #NNN`** | **le merge de la PR** | ~4 min après, pareil |

Le second n'a longtemps été couvert par aucune règle. Constaté le 2026-08-22 sur **#3216** : fermée
à 14:48Z par le merge de #3218, **rouverte à 14:52Z** par le bot. Personne n'avait fait de
`gh issue close` — et personne n'avait coché la checklist non plus.

1. **Cocher les cases AVANT** — avant le `gh issue close`, et avant le **merge** de la PR qui porte
   `Closes #NNN`. Pas après, pas « je cocherai ensuite » : après le merge, le compte à rebours du bot
   a déjà commencé.
2. **Relire l'état ≥ 5 min APRÈS** : `gh issue view N --json state,closedAt`.
3. Ne citer la fermeture dans un `[DONE]`, un bilan ou un décompte **qu'après** cette relecture.

**Pourquoi ce n'est pas cosmétique.** Après trois réouvertures, la boucle du bot s'arrête (#1487).
Une issue peut donc finir durablement `CLOSED` avec une **checklist vide** — l'état exact que la
règle existe pour empêcher, atteint sans que personne n'ait rien contourné.

Vaut aussi pour le décompte du hard cap : une issue rouverte par le bot n'a jamais été fermée.

## Interdictions

- JAMAIS "not planned" pour contourner le bot checklist
- JAMAIS fermer sur un CLAIM sans RESULT
- JAMAIS batch-close sans lire chaque issue
- JAMAIS commentaire generique copie-colle

## Qui peut fermer "won't fix" / "not planned" ?

**Uniquement** le coordinateur interactif avec approbation utilisateur, ou l'utilisateur directement.

---

**Grille marqueurs detaillee, test bash, audit /coordinate, historique :** [`docs/harness/reference/issue-closure-detailed.md`](../../docs/harness/reference/issue-closure-detailed.md)
