# Claim — le verrou vit sur l'issue

**Origine :** ADR 017 (roo-extensions `docs/harness/adr/017-issue-claim-locus.md`).

- Avant de travailler une issue, vérifier qu'aucune PR ouverte ne la couvre déjà
  (dans TOUS les dépôts liés au chantier — une PR de sous-module est invisible à un
  check single-repo), frontière de mot sur le numéro.
- Poser/lever le verrou **sur l'issue** (commentaire `[CLAIMED]` / `[RELEASED]`),
  indépendamment du canal de narration (dashboard, message).
- L'identité de lane est **`machine:workspace`** ; un claim d'une autre lane bloque
  (péremption par l'organe de garde du dépôt de coordination).
- En cas de conflit : STOP, arbitrage coordinateur. Le premier `[CLAIMED]` sur
  l'issue prime.
