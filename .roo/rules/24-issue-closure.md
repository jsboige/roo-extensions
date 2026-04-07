# Fermeture d'Issues — Regles Strictes

**Version:** 1.0.0
**MAJ:** 2026-04-06

## Regle

**Une issue ne peut etre fermee que si le travail est REELLEMENT TERMINE.**

## Avant de fermer

1. Le travail decrit est TERMINE (pas "en cours", pas "partiel")
2. Les criteres d'acceptation / checklist sont remplis
3. Si "superseded" : l'issue de remplacement couvre TOUT le scope
4. Si "resolved by PR" : le PR est MERGE

## Interdictions

- **JAMAIS** fermer "not planned" pour contourner le bot checklist
- **JAMAIS** fermer sur la base d'un CLAIM sans RESULT verifie
- **JAMAIS** fermer en batch sans lire chaque issue individuellement
- **"won't fix" / "not planned"** : reserve au coordinateur interactif avec accord utilisateur

## Si le bot rouvre une issue

C'est normal — la checklist n'est pas complete. Options :
1. Completer le travail
2. Mettre a jour la checklist (retirer items hors scope avec justification)
3. Laisser ouverte
