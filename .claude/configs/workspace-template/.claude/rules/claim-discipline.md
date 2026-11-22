# Claim — le verrou vit sur l'issue, pas sur le dashboard

**Identité de lane : `machine:{{WORKSPACE}}`.** Le verrou d'exclusivité sur un travail vit
**sur l'issue GitHub** (locus canon, ADR 017 roo-extensions), indépendamment du canal de
narration : un `[CLAIMED]` posté sur un dashboard ou en DM n'est que de la narration, il ne
vaut pas verrou.

- **Avant d'écrire** sur une issue : vérifier l'absence de claim actif d'une autre lane,
  puis poser le sien en commentaire de l'issue — `[CLAIMED] by claude on <machine>:{{WORKSPACE}}`.
- **La levée porte la même identité que la pose** (`[RELEASED]` / `[DONE] <lane>` quand la
  PR atterrit).
- Claim étranger actif ou conflit : STOP et arbitrage — on n'écrit pas dessus.

L'instrument complet vit côté roo-extensions (`scripts/github/check_issue_claim.py`) ; ce
fichier n'est que le rappel local du principe.
