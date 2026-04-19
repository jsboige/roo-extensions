# Fermeture d'Issues — Regles Strictes

**Version:** 2.1.0 (synced with .claude/rules/issue-closure.md v1.1.0)
**MAJ:** 2026-04-19

## Regle

**Une issue ne peut etre fermee que si le travail est REELLEMENT TERMINE.**

## Avant de fermer

1. Le travail est TERMINE (pas "en cours", pas "partiel")
2. Criteres d'acceptation / checklist remplis
3. Si "superseded" : issue de remplacement couvre TOUT le scope
4. Si "resolved by PR" : le PR est MERGE

## Interdictions

- **JAMAIS** fermer "not planned" pour contourner le bot checklist
- **JAMAIS** fermer sur la base d'un CLAIM sans RESULT verifie
- **JAMAIS** fermer en batch sans lire chaque issue
- **JAMAIS** utiliser un commentaire generique pour fermer. Chaque commentaire doit refleter le contenu de l'issue concernee. Si le meme commentaire peut etre copie-colle sur 3+ issues sans modification, c'est un batch-close sans lecture individuelle (incident #1428).
- **"won't fix" / "not planned"** : reserve au coordinateur interactif avec accord utilisateur

## Si le bot rouvre une issue

C'est normal — la checklist n'est pas complete. Options :
1. Completer le travail
2. Mettre a jour la checklist (retirer items hors scope avec justification)
3. Laisser ouverte

---
**Historique versions completes :** Git history avant 2026-04-08
