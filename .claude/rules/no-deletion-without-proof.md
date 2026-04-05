# No Deletion Without Proof

**Version:** 2.0.0 (condensed from 1.0.0)
**MAJ:** 2026-04-05

## Regle

**Aucun fichier ou fonction exporte ne peut etre supprime sans PREUVE de preservation.**

"Code mort" est un label dangereux. Le code peut etre : temporairement debranche, appele dynamiquement, ou un stub d'implementation cible.

## Preuve requise

### Suppression de fichier
1. Equivalent fonctionnel (fichier/lignes de remplacement)
2. Migration des imports
3. Tests preserves
4. `git grep "old-name"` = zero resultats

### Suppression de fonction
1. `git grep "functionName"` = zero appelants
2. `git log -S "functionName" --since="30 days ago"` — si recent, probablement en cours
3. Verifier registres, dispatch tables, invocations dynamiques

## Prevention chaines circulaires (#815)

A importe B → B supprime ("consolide dans C") → A n'a plus d'importateurs → A supprime.
**Prevention :** Verifier si les importateurs ont ete supprimes recemment (30 jours). Si oui, le code N'EST PAS mort — il a ete debranche.

## Repertoires PROTEGES (approbation utilisateur obligatoire)

- `src/services/synthesis/` — Pipeline LLM (3 destructions)
- `src/services/narrative/` — Stubs = cibles d'IMPLEMENTATION

## Deletion legitime

Fichier cree par erreur, feature abandonnee (documentee), migration avec forwarding 30 jours.
