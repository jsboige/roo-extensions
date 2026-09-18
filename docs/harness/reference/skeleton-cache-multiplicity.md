# Multiplicité du cache squelette — N clients MCP par hôte

**Statut :** référence pérenne. Le détail daté et mesuré vit dans
[`docs/harness/investigations/2026-09-issue-3661-skeleton-cache-multiplicity.md`](../investigations/2026-09-issue-3661-skeleton-cache-multiplicity.md).

## Pourquoi cette page existe

Chaque processus client MCP (`roo-state-manager`) porte **son propre** cache squelette et,
par défaut, l'hydrate de façon **eager** (`background-services.ts`, `enablePrewarm`). Sur une
machine qui héberge N clients (multiplicité courante : 27+ hôtes), chaque client inactif
coûte ~3,2 Go de mémoire privée — soit ~93 Go cumulés sur 29 hôtes au pic mesuré.

## Trois axes, trois gestes

| Axe | Phénomène | Geste |
|---|---|---|
| 1 — hydratation eager | cache dupliqué N× (Tier 2 + Tier 3) | **A** : `ROO_AUTO_DISABLE_PREWARM=1` (opt-in par machine, décision opérationnelle) |
| 2 — scans de démarrage + Worker A | chaque hôte ré-indexe le disque local | **B** : élection machine-locale de Worker A + scans (lock dédié `roosync-worker-a-leader-${machineId}.lock`, fail-closed) |
| 3 — accès lazy du client | le cold-load est payé à la première requête | **C** (à l'étude) : clients secondaires légers vs daemon de cache partagé |

## Lire une mesure de boot (acceptance)

L'instrumentation boot (`ROO_INSTRUMENT_BOOT=1`, issue #3661) émet une ligne JSON
`event: "boot"` par processus au démarrage. **L'acceptance d'un geste A/B se lit sur les
lignes `event=boot`** (prewarmReason, workerALeader, tiers) — jamais sur un total brut de
mémoire qui confond les habitudes de browse de chaque hôte. Un hôte qui ne browse jamais
reste bas ; un hôte qui appelle `list` remonte : c'est la ligne boot qui attribue le coût
par machine.

## Rappels mesurés

- `SKELETON_PREWARM=false` (legacy) désactive l'hydratation eager ; le geste A moderne est `ROO_AUTO_DISABLE_PREWARM=1`.
- Le kill-switch n'est **pas** appliqué par défaut : la bascule est une décision par machine.
- Une fausse réfutation classique : mesurer un build dont `build/` est antérieur au fix, ou
  sans le flag opt-in posé — la fenêtre de redémarrage est consommée à vide. Vérifier
  `build/build-info.json` et les deux drapeaux avant de conclure.