# Environnement dégradé — escalade immédiate, échéance à 2 cycles

**Version :** 1.0.0 (copie projet — corps canonique dans
[`.claude/configs/rules/degraded-escalation.md`](../../.claude/configs/rules/degraded-escalation.md),
déployé flotte par `Deploy-GlobalConfig.ps1 -Target rules`)
**Issue :** #4517 · **MAJ :** 2026-11-03

Cette copie sert les sièges où la règle globale n'est pas déployée : la source
ci-dessus fait foi à l'identique.

Les cinq règles, en une ligne chacune :

1. **Escalade immédiate** — MCP absent/muet, kernel manquant, service
   indisponible : on escalade **avant** toute tentative de contournement.
2. **Échéance dérivée** — un post `[DEGRADED]` sur le dashboard `workspace`
   suffit ; l'échéance est `posté + 2 cycles`, calculée par le mécanisme.
3. **Les autres agents sont instruits** — une échéance dépassée fait alerter le
   user par la lane qui exécute l'organe, pas par la mémoire de la lane tombée.
4. **Aucun workaround ne se consacre** — sortie dégradée rapportée comme
   dégradée, jamais commitée comme résultat normal.
5. **Seul `[REPAIRED]` ferme**, et depuis la même lane. Un `[DONE]` ne ferme rien.

`[DEGRADED]` ≠ `[BLOCKED]` : bloqué = j'attends quelqu'un d'autre ; dégradé =
**mon** environnement est cassé.

**Organe :** `scripts/diagnostic/check-degraded-escalations.py` — exit `0`
(aucune escalade) / `3` (ouverte, dans les délais) / `2` (échéance dépassée →
sonner) / `1` (instrument incomplet ou sonnerie non partie). `--ring` poste
`[ASK-USER][DEGRADED-ESCALATION]` sur le dashboard `global`.

**Détail, mesures, incident :** [`docs/harness/reference/degraded-escalation.md`](../../docs/harness/reference/degraded-escalation.md).
